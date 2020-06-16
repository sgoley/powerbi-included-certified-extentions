// This file contains your Data Connector logic
[Version = "1.0.0"]
section EntersoftBusinessSuite;

redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
windowWidth = 1200;
windowHeight = 1000;
ES_PQ_PAGESIZE = 1000;

eswebapiURL = "https://api.entersoft.gr/api/";


[DataSource.Kind="EntersoftBusinessSuite", Publish="EntersoftBusinessSuite.Publish"]

shared EntersoftBusinessSuite.Contents = () =>
    let
/*    
    x = "{
      ""AA"": 190000,
      ""ID"": ""PQ_190000"",
      ""GroupID"": ""SalesContent"",
      ""Title"": ""Top customers (Last year)"",
      ""esDef"": {
        ""GroupID"": ""ESPowerBI_Sales"",
        ""FilterID"": ""TopCustomers"",
        ""xParams"": {
            ""Period"": ""ESDateRange(Year, -1)""
        }
      }
    }",
    jdoc =  Json.Document(x)[esDef],
    xDoc = if Record.HasFields(jdoc, "Params") then jdoc[Params] else Record.FromList({}, {}),
        tst = ExecutePQ("ESPowerBI_Sales", "TopCustomers", xDoc, false),
 */  
        //k = Extension.CurrentCredential()[Properties],
        dsMenu = ESWebAPI_GetTopLevelMenu(),
        sVer = if Record.HasFields(dsMenu, "Version") then dsMenu[Version] else "",
        objects = #table(
            {"Name",       "Key",  "Data",                "ItemKind", "ItemName", "IsLeaf"},{
            {"Lookups",             "n1",   CreateLevelMenu("01", dsMenu), "Folder",    "Folder",    false},
            {"Published BI Content " & " (" & sVer & ")",   "n2",   CreateLevelMenu("02", dsMenu), "Folder",    "Folder",    false}
        }),
    
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
        in 
            NavTable;
    
CreateLevelMenu = (menuID as text, dsMenu) as table =>
    let
        objects = HlpCreateMenuTable(),

        ret = if (menuID = "01") then
                GetDimensionAnalysis()
        else if (menuID = "02") then
                GetDataSets(dsMenu)
        else if (menuID = "03") then   
                objects
        else
                objects
        in 
            ret;

GetDataSets = (dsMenu) as table =>
    let
        menuItems = dsMenu[MainMenu],
        jsGroups = dsMenu[Groups],
        objects = HlpCreateMenuTable(),
        menugroups = List.Accumulate(jsGroups, objects, (state, current) => Table.InsertRows(state, 0, {[Name = current[Title], Key = current[ID], Data = GetNavigationItems(menuItems, current[ID]), ItemKind = "Folder", ItemName = "Folder", IsLeaf = false]})),
        a = Table.ToNavigationTable(menugroups, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        a;

ESIsNumberColumn = (colInfo) as logical =>
    let
        dtName = colInfo[DataTypeName],
        r1 = if List.Contains({"Int32", "Int64"}, dtName) then true
             else if dtName = "Byte" and colInfo[EditType] <> "8" then true
             else false
    in 
        r1;

GetDimensionAnalysis = () as table =>
    let
        zooms = ESWebAPI_GetAllZooms(),
        modules = List.Distinct(zooms, { each[ModuleID], Comparer.FromCulture("en", true)}),
        objects = HlpCreateMenuTable(),
        menugroups = List.Accumulate(modules, objects, (state, current) => Table.InsertRows(state, 0, {[Name = current[ModuleName], Key = current[ModuleID], Data = GetModuleItems(zooms, current[ModuleID]), ItemKind = "Folder", ItemName = "Folder", IsLeaf = false]})),
        NavTable = Table.ToNavigationTable(menugroups, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

GetModuleItems = (zooms as list, moduleid as text) as table =>
    let
       setofzooms = List.Select(zooms, (x) => x[ModuleID] = moduleid),
       objects = HlpCreateMenuTable(),
       menugroups = List.Accumulate(setofzooms, objects, (state, current) => Table.InsertRows(state, 0, {[Name = current[ID], Key = current[ID], Data = ESWebAPI_ExecuteZoom(current), ItemKind = "Table", ItemName = "Table", IsLeaf = true]})),
       NavTable = Table.ToNavigationTable(menugroups, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

GetNavigationItems = (menuitems as list, groupid as text) as table =>
    let
        itms = List.Select(menuitems, (x) => x[GroupID] = groupid),
        sortitms = List.Sort(itms, (x, y) => Value.Compare(x[AA], y[AA])),
        objects = HlpCreateMenuTable(),
        groups = List.Accumulate(sortitms, objects, (state, current) => Table.InsertRows(state, 0, 
            {
                [Name = current[Title], 
                Key = current[ID], 
                Data = ExecutePQ(current[esDef][GroupID], 
                                current[esDef][FilterID], 
                                if Record.HasFields(current[esDef], "Params") then current[esDef][Params] else Record.FromList({}, {}), 
                                if Record.HasFields(current[esDef], "NoPaged") then current[esDef][NoPaged] else false), 
                ItemKind = "Table", ItemName = "Table", IsLeaf = true] })),

        a = Table.ToNavigationTable(groups, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in 
        a;

HlpCreateMenuTable = () as table =>
    let
        objects = #table({"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, {})
    in
        objects;

ESWebAPI_GetTopLevelMenu = ()  =>
    let 
        ebsCommand = "asset",
        params = Uri.BuildQueryString([routeId = "PowerBI/ESPowerBIDS.json"]),
        skey = Extension.CurrentCredential()[access_token],
        url = Uri.Combine(eswebapiURL, ebsCommand) & "?" & params,
        wb = Web.Contents(url, [Headers = [#"Authorization" = "Bearer " & skey]]),
        tb = Text.FromBinary(wb),
		js = Json.Document(tb)
    in
        js;

ESWebAPI_ExecuteZoom = (zoomDef) as table =>
    let
        zoomid = zoomDef[ID],
        skey = Extension.CurrentCredential()[access_token],
		url = Uri.Combine(Uri.Combine(eswebapiURL, "rpc/FetchStdZoom/"), zoomid),
		js = Json.Document(Web.Contents(url, [Headers = [#"Authorization" = "Bearer " & skey]])),
        Source = Table.FromList(js[Rows], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        raw = if Table.IsEmpty(Source) then Source else Table.ExpandRecordColumn(Source, "Column1",  Record.FieldNames(Table.Column(Source, "Column1"){0})),
        tabx = ChangeZoomType(raw, zoomid)
    in 
        tabx;

CreateZoomSchema = (pqInfo) as table => 
    let
        colList = List.Transform(pqInfo, (x) => x[ID]),
        tab = Table.FromRows({}, colList)
    in
        tab;

ChangeZoomType = (argTable as table, zoomid as text) as table =>
    let
        tInfo = ESWebAPI_GetODSInfo(zoomid),
        pqInfo = tInfo[Columns],
        zoomTable = if Table.IsEmpty(argTable) then CreateZoomSchema(pqInfo) else argTable,
        intColumns = List.Transform(List.Select(pqInfo, (x) => if Record.HasFields(x, "NetType") then List.ContainsAny({x[NetType]}, {"System.Int32", "System.Byte", "System.Int64", "System.Long"}) else false), (x) => { x[ID], Int64.From}),
        boolColumns = List.Transform(List.Select(pqInfo, (x) => if Record.HasFields(x, "NetType") then x[NetType] = "System.Boolean" else false), (x) => { x[ID], Logical.From}),
        decimalColumns = List.Transform(List.Select(pqInfo, (x) => if Record.HasFields(x, "NetType") then x[NetType] = "System.Decimal" else false), (x) => { x[ID], Number.From}),
        dateTimeColumns = List.Transform(List.Select(pqInfo, (x) => x[ODSType] = "ESDATETIME"), (x) => { x[ID], DateTime.From}),
        tColumns = List.Combine({intColumns, boolColumns, dateTimeColumns, decimalColumns}),
        x1 = Table.TransformColumns(zoomTable, tColumns),
        dateColumns = List.Transform(List.Select(pqInfo, (x) => x[ODSType] = "ESDATE"), (x) => { x[ID], Date.From}),
        x = Table.TransformColumns(x1, dateColumns)
    in 
        x;

ESWebAPI_GetAllZooms = () =>
    let
        skey = Extension.CurrentCredential()[access_token],
		url = Uri.Combine(eswebapiURL, "rpc/FetchOdsAllZooms"),
		js = Json.Document(Web.Contents(url, [Headers = [#"Authorization" = "Bearer " & skey]]))
    in 
        js;

ESWebAPI_GetODSInfo = (tableID as text) =>
    let
        skey = Extension.CurrentCredential()[access_token],
		url = Uri.Combine(eswebapiURL, "rpc/FetchOdsTableInfo/") & tableID,
		js = Json.Document(Web.Contents(url, [Headers = [#"Authorization" = "Bearer " & skey]]))
    in 
        js;

ESWebAPI_PQInfo = (groupid as text, filterid as text) =>
	let
		skey = Extension.CurrentCredential()[access_token],
		url = Uri.Combine(eswebapiURL, "rpc/PublicQueryInfo") & "/" & groupid & "/" & filterid,
		js = Json.Document(Web.Contents(url, [Headers = [#"Authorization" = "Bearer " & skey]]))[LayoutColumn]
	in 
		js;


ESWebAPI_GetPQData = (groupid as text, filterid as text, pageNo as number, pqParams as record) =>
    let 
        skey = Extension.CurrentCredential()[access_token],
		url = Uri.Combine(eswebapiURL, "rpc/PublicQuery") & "/" & groupid & "/" & filterid,
        pqoptions = Json.FromValue([#"WithCount" = "false", #"Page" = pageNo, #"PageSize" = ES_PQ_PAGESIZE]),
        payload = if List.IsEmpty(Record.FieldValues(pqParams)) then null else Text.FromBinary( Json.FromValue(pqParams)),
		js = Json.Document(Web.Contents(url, [Headers = [#"Content-Type" = "application/json", #"Authorization" = "Bearer " & skey, #"X-ESPQOptions" = Text.FromBinary(pqoptions)], Content=Text.ToBinary(payload)]))
    in 
        js;

ExecutePQ = (groupid as text, filterid as text, pqParams as record, fetchAll as logical) as table =>
	let
        lst = if not fetchAll 
                then 
                    List.Combine(List.Generate( () =>	
                    [Result =  ESWebAPI_GetPQData(groupid, filterid, 1, pqParams), Page = 1],
                    each not List.IsEmpty([Result][Rows]),
                    each [Result = ESWebAPI_GetPQData(groupid, filterid, [Page] + 1, pqParams), Page = [Page] + 1],
                    each [Result][Rows]))
                else 
                    ESWebAPI_GetPQData(groupid, filterid, -1, pqParams)[Rows],

        Source = Table.FromList(lst, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        tabx = if Table.IsEmpty(Source) then Source else Table.ExpandRecordColumn(Source, "Column1",  Record.FieldNames(Table.Column(Source, "Column1"){0})),
        ret = ESChangeType(groupid as text, filterid as text, tabx)
	in 
		ret;

CreateSchemaTable = (pqInfo) as table =>
    let
        colList = List.Transform(pqInfo, (x) => x[ColName]),
        tab = Table.FromRows({}, colList)
    in
        tab;

ESChangeType = (groupid as text, filterid as text, argTable as table) as table =>
    let
        pqInfo = ESWebAPI_PQInfo(groupid, filterid),
        inTable = if Table.IsEmpty(argTable) then CreateSchemaTable(pqInfo) else argTable,
        intColumns = List.Transform(List.Select(pqInfo, (x) => ESIsNumberColumn(x)), (x) => { x[ColName], Int64.From}),
        boolColumns = List.Transform(List.Select(pqInfo, (x) => x[DataTypeName] = "Byte" and x[EditType] = "8"), (x) => { x[ColName], Logical.From}),
        decimalColumns = List.Transform(List.Select(pqInfo, (x) => x[DataTypeName] = "Decimal"), (x) => { x[ColName], Number.From}),
        dateTimeColumns = List.Transform(List.Select(pqInfo, (x) => x[DataTypeName] = "DateTime"), (x) => { x[ColName], DateTime.From}),
        tColumns = List.Combine({intColumns, decimalColumns, boolColumns, dateTimeColumns}),

        x1 = Table.TransformColumns(inTable, tColumns),

        dateColumns = List.Transform(List.Select(pqInfo, (x) => x[DataTypeName] = "DateTime" and x[FormatString] = "d"), (x) => { x[ColName], Date.From}),
        x = Table.TransformColumns(x1, dateColumns)
    in
        x;

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

// Data Source Kind description
EntersoftBusinessSuite = [
     TestConnection = (dataSourcePath) => { "EntersoftBusinessSuite.Contents" },
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Logout = Logout,
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel"),
    SupportsEncryption = false
];

StartLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl = "https://api.entersoft.gr/auth/auth?" & Uri.BuildQueryString([
			client_id = "cl1234",
			app_id = "esmspowerbi",
            scope = "data",
            state = state,
			response_type = "token",
            redirect_uri = redirect_uri])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = null
        ];

Logout = (token) =>
     let 
		url = Uri.Combine(eswebapiURL, "login/exitauth/") & "Bearer " & token
    in 
        url; 

FinishLogin = (context, callbackUri, state) =>
    let

        Parts = Uri.Parts(callbackUri)[Query],
		MyTok = TokenMethod(Parts[code])
    in
        MyTok;

TokenMethod = (code) =>
    let
        Parts = Json.Document("{""access_token"":""" & code & """, ""scope"":""data"", ""token_type"":""bearer""}")
    in
        Parts;

// Data Source UI publishing description
EntersoftBusinessSuite.Publish = [
    Beta = true,
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = EntersoftBusinessSuite.Icons,
    SourceTypeImage = EntersoftBusinessSuite.Icons
];

EntersoftBusinessSuite.Icons = [
    Icon16 = { Extension.Contents("Entersoft_Business_Suite16.png"), Extension.Contents("Entersoft_Business_Suite20.png"), Extension.Contents("Entersoft_Business_Suite24.png"), Extension.Contents("Entersoft_Business_Suite32.png") },
    Icon32 = { Extension.Contents("Entersoft_Business_Suite32.png"), Extension.Contents("Entersoft_Business_Suite40.png"), Extension.Contents("Entersoft_Business_Suite48.png"), Extension.Contents("Entersoft_Business_Suite64.png") }
];

