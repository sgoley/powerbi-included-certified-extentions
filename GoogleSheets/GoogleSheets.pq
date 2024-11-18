[Version = "1.0.6"]
section GoogleSheets;

ClientId = "836582736780-j225jgqf50956ed5qjm6ratl3up80bk1.apps.googleusercontent.com";
ClientSecret = "c0fwt1FXY0JxNprsL8awxoSb";
CallbackUrl = "https://oauth.powerbi.com/views/oauthredirect.html";
ApiErrorStatusCodes = { 400, 403, 404, 500, 503 };

StartLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl = "https://accounts.google.com/o/oauth2/v2/auth?" & Uri.BuildQueryString([
            client_id = ClientId,
            scope = "https://www.googleapis.com/auth/spreadsheets.readonly",
            response_type = "code",
            access_type = "offline",
            prompt = "consent",
            state = state,
             redirect_uri = CallbackUrl])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = CallbackUrl,
            WindowHeight = 780,
            WindowWidth = 480,
            Context = null
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query],
        Response = if (Parts[error]? <> null) then
                      error Error.Record("DataSource.Error", Parts[error])
                   else
                         Web.Contents("https://oauth2.googleapis.com/token", [
                             Content = Text.ToBinary(Uri.BuildQueryString([
                             client_id = ClientId,
                             client_secret = ClientSecret,
                             grant_type = "authorization_code",
                             code = Parts[code],
                             redirect_uri = CallbackUrl])),
        Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"]]),
        token = Json.Document(Response)
    in
        token;

Refresh = (resourceUrl, refresh_token) =>
    let
        Response = Web.Contents("https://oauth2.googleapis.com/token", [
            Content = Text.ToBinary(Uri.BuildQueryString([
                grant_type = "refresh_token",
                client_id = ClientId,
                client_secret = ClientSecret,
                refresh_token = refresh_token
                ])),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"]]),
        Parts = Json.Document(Response)
    in
        Parts;

GoogleSheets = [
    Type = "Custom",
    MakeResourcePath = (url) => url,
    ParseResourcePath = (resourcePath) => {resourcePath},
    TestConnection = (resourcePath) => {"GoogleSheets.Contents"} & ParseResourcePath(resourcePath),
    Authentication=[
                    OAuth=[
                            StartLogin=StartLogin, 
                            FinishLogin=FinishLogin, 
                            Refresh=Refresh, 
                            Label = Extension.LoadString("AuthenticationLabel")]
                            ]
];


[DataSource.Kind = "GoogleSheets" , Publish="GoogleSheets.Publish"]
shared GoogleSheets.Contents = Value.ReplaceType(GoogleSheetsImpl,GoogleSheetsType);

GoogleSheetsImpl = (url as text) => 
    let 
        urlSplitBySlash = Text.Split(url,"/"),
        spreadsheetid = if Text.StartsWith(url,"https://docs.google.com/spreadsheets/d/") then 
                          urlSplitBySlash{5}
                       else 
                          error Error.Record("Expression.Error",Extension.LoadString("Url_Not_Found")),
        result = GetResults(spreadsheetid)
    in
        result;

GoogleSheetsType = type function (  
        url as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("url_Caption"),
        Documentation.FieldDescription = Extension.LoadString("url_Description"),
        Documentation.SampleValues = {"https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms"}
    ]))
    as table meta [
        Documentation.Name = Extension.LoadString("GoogleSheets_Title"),
        Documentation.Caption = Extension.LoadString("GoogleSheets_Title"),
        Documentation.Description = Extension.LoadString("GoogleSheets_Description"),
        Documentation.LongDescription = Extension.LoadString("GoogleSheets_LongDescription")
    ];

GetResults = (spreadsheetid as text)  =>
    let
        apiurl = Uri.Combine("https://sheets.googleapis.com/v4/spreadsheets/",Text.Format("#{0}?fields=sheets/properties,namedRanges",{spreadsheetid})),
        jsonResponse = Web.JsonContents(apiurl),
        listofsheets = jsonResponse[sheets]?,
        listofnamedRanges = jsonResponse[namedRanges]? ?? {},
        toTable = Table.FromRecords(listofsheets),
        withexpandedpropertiesColumns = Table.ExpandRecordColumn(toTable,"properties",{"sheetId","title","sheetType","gridProperties"}),
        allsheets = GetSpreadSheets(withexpandedpropertiesColumns,spreadsheetid),
        ranges = GetNamedRanges(spreadsheetid,allsheets,listofnamedRanges),
        selectrangesColumns = if ranges = null then #table(type table [name=text, SheetorRangeId=text, Data=table], {}) else Table.SelectColumns(ranges,{"name","SheetorRangeId","Data"}),
        selectallsheetsColumns = Table.SelectColumns(allsheets,{"title","sheetId","Data"}),
        withrename = Table.RenameColumns(selectallsheetsColumns,{{"title","name"},{"sheetId","SheetorRangeId"}}),
        addItemKind = Table.AddColumn(withrename,"ItemKind",each "Table"),
        addItemKindtoRanges = Table.AddColumn(selectrangesColumns,"ItemKind",each "DefinedName"),
        combinedTable = Table.Combine({addItemKind,addItemKindtoRanges}),
        withItemName = Table.AddColumn(combinedTable,"ItemName",each "Table"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true),       
        nav = Table.ToNavigationTable(withIsLeaf, {"name","ItemKind"}, "name", "Data", "ItemKind", "ItemName", "IsLeaf") 
    in       
        nav;
                 
GetSpreadSheets = (allsheets as table,spreadsheetid as text)  => 
   let
        withDataColumn = Table.AddColumn(allsheets,"Data",each GetSheetData(spreadsheetid, [gridProperties],[title]),type table)
   in
        withDataColumn;

GetNamedRanges = (spreadsheetid as text,allsheets as table,namedRanges as list) =>
    let
       Ranges = if (namedRanges = {}) then null else GetRanges(namedRanges,spreadsheetid,allsheets)
    in
       Ranges;

GetSheetData = (spreadsheetid as text,gridProperties as record, title as text) as nullable table =>
    let
        rowCount = Record.Field(gridProperties,"rowCount"),
        columnIndex = Record.Field(gridProperties,"columnCount"),
        columnCount = CalculateColumn(columnIndex),
        url = Uri.Combine("https://sheets.googleapis.com/v4/spreadsheets/",Text.Format("#{0}?ranges=#{1}!A1:#{2}#{3}&fields=sheets/data/rowData/values/effectiveFormat/numberFormat,sheets/data/rowData/values/effectiveValue",{spreadsheetid,Uri.EscapeDataString(title),columnCount,rowCount})),
        rows = GetData(url),
        result = if(rows = null) then null else AttachTypestoData(rows)        

    in 
        result;

AttachTypestoData = (rows as list) =>
    let 
        paddedRowsData = GetPaddedRowsData(rows),     
        typeconvertedvalues =  List.Transform(paddedRowsData, (onesingleitem) => AddTypeToValue(onesingleitem)),
        result = Table.FromRows(typeconvertedvalues) 
     in
        result;

AddTypeToValue = (allCellsInRow as list) =>
                 let 
                     result = List.Transform(allCellsInRow, (cell) =>
                            let                            
                               format = cell[effectiveFormat]?,
                               effectiveType = if format = "" or format = null then "" else  format[numberFormat][type],
                               effectiveValue = cell[effectiveValue]?,
                               result1 = if  effectiveValue = "" or effectiveValue = null  then ""
                                         else if(Record.HasFields(effectiveValue,"numberValue")) then CheckNumberValue(effectiveType,effectiveValue[numberValue])
                                         else if(Record.HasFields(effectiveValue,"stringValue")) then effectiveValue[stringValue]
                                         else if(Record.HasFields(effectiveValue,"boolValue")) then effectiveValue[boolValue]
                                         else if(Record.HasFields(effectiveValue,"errorValue")) then error Error.Record("DataFormat.Error",effectiveValue[errorValue][type],effectiveValue[errorValue][message])
                                         else error Error.Record("Expression.Error", Extension.LoadString("Invalid_EffectiveValue"), Extension.LoadString("Invalid_EffectiveValue"))
                            in result1)
                  in
                    result;

CheckNumberValue = (effectiveType as text,numberValue as any) =>
    let
        result = if(effectiveType = "NUMBER_FORMAT_TYPE_UNSPECIFIED") then numberValue
                 else if(effectiveType = "TEXT") then numberValue
                 else if(effectiveType = "NUMBER") then numberValue 
                 else if(effectiveType = "PERCENT") then numberValue
                 else if(effectiveType = "CURRENCY") then numberValue
                 else if(effectiveType = "DATE") then Date.From(numberValue)
                 else if(effectiveType = "TIME") then Time.From(numberValue)
                 else if(effectiveType = "DATE_TIME") then DateTime.From(numberValue)
                 else if(effectiveType = "SCIENTIFIC") then numberValue
                 else numberValue
     in
       result;

GetRanges = (namedRanges as list,spreadsheetid as text,allsheets as table) =>
    let
       listOfranges = List.Transform(namedRanges,(namedRange) => 
                          let 
                              range = namedRange[range], 
                              withName = Record.AddField(range,"name",namedRange[name]),
                              withId = Record.AddField(withName,"SheetorRangeId",namedRange[namedRangeId]),
                              rangedetails = AddMissingFields(withId)
                           in 
                              rangedetails), 
       ranges = Table.FromRecords(listOfranges),
       rangeswithData = Table.AddColumn(ranges,"Data",each GetRangeData(spreadsheetid,[sheetId],[startRowIndex],[endRowIndex],[startColumnIndex],[endColumnIndex],allsheets),type table)
    in
       rangeswithData;

AddMissingFields = (withId as record) as record  =>
    let
       sheetIdValidated = if(Record.HasFields(withId,"sheetId")) then withId else Record.AddField(withId,"sheetId",0),                             
       startColumnValidated = if(Record.HasFields(sheetIdValidated,"startColumnIndex")) then sheetIdValidated else Record.AddField(sheetIdValidated,"startColumnIndex",0),
       endColumnValidated = if(Record.HasFields(startColumnValidated,"endColumnIndex")) then startColumnValidated else Record.AddField(startColumnValidated,"endColumnIndex",18278),
       startRowValidated = if(Record.HasFields(endColumnValidated,"startRowIndex")) then endColumnValidated else Record.AddField(endColumnValidated ,"startRowIndex",0),
       endRowValidated = if(Record.HasFields(startRowValidated,"endRowIndex")) then startRowValidated  else Record.AddField(startRowValidated ,"endRowIndex",5000000)
    in 
       endRowValidated;                     
             
GetRangeData = (spreadsheetid,sheetId,startRowIndex,endRow,startcolumnIndex,endcolumnIndex,allsheets as table) =>
    let
         startColumn = CalculateColumn(startcolumnIndex+1),
         startRow = Text.From(startRowIndex + 1),
         endColumn = CalculateColumn(endcolumnIndex),
         selectRow = Table.SelectRows(allsheets,each [sheetId] = Value.FromText(sheetId)),
         title = selectRow[title]{0},
         url = Uri.Combine("https://sheets.googleapis.com/v4/spreadsheets/",Text.Format("#{0}?ranges=#{1}!#{2}#{3}:#{4}#{5}&fields=sheets/data/rowData/values/effectiveFormat/numberFormat,sheets/data/rowData/values/effectiveValue",{spreadsheetid,Uri.EscapeDataString(title),startColumn,startRow,endColumn,endRow})),
         rows = GetData(url),
         result = if(rows = null) then null else AttachTypestoData(rows)     
    in
         result;

GetData = (url as text) as nullable list =>
    let
        jsonResponse = Web.JsonContents(url),
        toTable = Table.FromRecords({jsonResponse}),
        sheetcolumn = Table.ExpandListColumn(toTable,"sheets"),
        datacolumn = Table.ExpandRecordColumn(sheetcolumn,"sheets",{"data"}),
        expandlistdatacolumn = Table.ExpandListColumn(datacolumn,"data"),
        rowDataColumn = Table.ExpandRecordColumn(expandlistdatacolumn,"data",{"rowData"}),
        rowData = rowDataColumn{0}[rowData]
    in 
        rowData;

GetPaddedRowsData = (rows as list) =>
     let
        maxColumns = List.Max(List.Transform(rows, (row) => List.Count(row[values]? ?? {}))),
        paddedRowData = List.Transform(rows, (row) => 
                                        let 
                                             pad = maxColumns - List.Count(row[values]? ?? {}) 
                                         in 
                                            if pad = 0 then row[values]? else (row[values]? ?? {}) & List.Repeat({[]}, pad))
      in 
        paddedRowData;

Web.JsonContents = (url)  =>
    let
        response = Web.Contents(url, [ManualStatusHandling = ApiErrorStatusCodes]),
        jsonResponse = Json.Document(response) meta Value.Metadata(response),
        responseStatusCode = Record.FieldOrDefault(Value.Metadata(jsonResponse), "Response.Status", 0)
     in
        if List.Contains(ApiErrorStatusCodes, responseStatusCode) then Web.ErrorResponse(responseStatusCode,jsonResponse) else jsonResponse;

Web.ErrorResponse = (responseCode as number, jsonResponse as record) => 
    let 
        detail = [
        errorstatus = jsonResponse[error][status],
        errormessage = jsonResponse[error][message],
        errorcode = jsonResponse[error][code]
        ],        
        errorResponse = error Error.Record("DataSource.Error", jsonResponse[error][message], detail)
    in
        errorResponse;

CalculateColumn = (index) =>
    let
        ToChar = (idx, col) => [
            Tmp = Number.Mod(idx - 1, 26),
            Next = (idx - Tmp-1)/26,
            Done = idx=0,
            Column = Character.FromNumber(65 + Tmp) & col],
        List = List.Generate(
            () => ToChar(index, ""),
            (state) => not state[Done],
            (state) => ToChar(state[Next], state[Column]))
    in
        List.Last(List)[Column];


formatValue = (value) => 
    let
        val = if value = null then "" else value
    in
        val;

GoogleSheets.Publish = [
    Name = "Google Sheets",
    Category = "Other",
    ButtonText = {
            Extension.LoadString("GoogleSheets_Name"),Extension.LoadString("GoogleSheets_Description")
        },
    LearnMoreUrl = "https://aka.ms/GoogleSheetsConnector",
    Beta = false
];

Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;