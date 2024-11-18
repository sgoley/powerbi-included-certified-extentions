[Version="1.1.0"]
section SmartsheetGlobal;

[DataSource.Kind = "SmartsheetGlobal"]
shared SmartsheetGlobal.Query = Value.ReplaceType(Smartsheet.QueryInternal, QueryFunctionType);

[DataSource.Kind = "SmartsheetGlobal", Publish = "SmartsheetGlobal.Publish"]
shared SmartsheetGlobal.Contents = Value.ReplaceType(ContentsInternal, ContentsFunctionType);

SmartsheetGlobal = [
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            region = json[region]
        in
            {"SmartsheetGlobal.Contents", region},
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh
        ]
    ]
];

Endpoints =
    #table({"RegionCode", "RegionLabel", "AuthorizeUrl", "TokenUrl", "ApiUrl", "ClientId", "ClientSecret"},
    {
        { "US", "US", "https://app.smartsheet.com/b/authorize", "https://api.smartsheet.com/2.0/token", "https://api.smartsheet.com/2.0/", "1n7yb2k0axkpfwanzio", "o53vt07cj52wzlhegpx"},
        { "EU", "EU", "https://app.smartsheet.eu/b/authorize",  "https://api.smartsheet.eu/2.0/token",  "https://api.smartsheet.eu/2.0/",  "qy1jc8hd6o7jjh5a8l1", "r3re6mk2xwdvoh2f6nv"}
    });

// Helper functions that use the Endpoints configuration.
GetEndpointRecord = (region as text) as record => try Endpoints{[RegionCode = region]} otherwise error Error.Record("Expression.Error", "Unexpected region value: " & region);
GetEndpointApiUrl = (region as text) as text => GetEndpointRecord(region)[ApiUrl];
GetEndpointOAuthConfig = (region as text) as record =>
    let
        endpoint = GetEndpointRecord(region)
    in
        [
            client_id = endpoint[ClientId],
            client_secret = endpoint[ClientSecret],
            authorize_url = endpoint[AuthorizeUrl],
            token_url = endpoint[TokenUrl],
            redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html"
        ];

SmartsheetGlobal.Publish = [
    Beta = true,
    LearnMoreUrl = "https://go.microsoft.com/fwlink/?LinkId=747872",
    ButtonText = {Extension.LoadString("FormulaTitle"), Extension.LoadString("FormulaHelp")},
    SourceImage = Smartsheet.Icons,
    SourceTypeImage = Smartsheet.Icons
];

Smartsheet.Icons = [
    Icon16 = {
        Extension.Contents("Smartsheet_16.png"),
        Extension.Contents("Smartsheet_20.png"),
        Extension.Contents("Smartsheet_24.png"),
        Extension.Contents("Smartsheet_32.png")
    },
    Icon32 = {
        Extension.Contents("Smartsheet_32.png"),
        Extension.Contents("Smartsheet_40.png"),
        Extension.Contents("Smartsheet_48.png"),
        Extension.Contents("Smartsheet_64.png")
    }
];

windowWidth = 1024;
windowHeight = 720;
DefaultReportPageSize = 500;
MinReportPageSize = 500;
MaxReportPageSize = 10000;


TokenMethod = (region, code) =>
    let
        config = GetEndpointOAuthConfig(region),
        Response = Web.Contents(
            config[token_url],
            [
                Content = Text.ToBinary(
                    Uri.BuildQueryString(
                        [
                            grant_type = "authorization_code",
                            client_id = config[client_id],
                            code = code,
                            redirect_uri = config[redirect_uri],
                            hash = Binary.ToText(Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(config[client_secret] & "|" & code)), BinaryEncoding.Hex)
                        ])),
                Headers = [#"Content-type" = "application/x-www-form-urlencoded", Accept = "application/json"]
            ]),
        Parts = Json.Document(Response)
    in
        Parts;

StartLogin = (dataSourcePath, state, display) =>
    let
        region = Json.Document(dataSourcePath)[region],
        config = GetEndpointOAuthConfig(region),
        AuthorizeUrl = config[authorize_url] & "?" & Uri.BuildQueryString(
            [
                response_type = "code",
                state = state,
                client_id = config[client_id],
                scope = "READ_SHEETS READ_USERS READ_CONTACTS",
                redirect_uri = config[redirect_uri]
            ])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = config[redirect_uri],
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = region
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query]
    in
        try TokenMethod(context, Parts[code]) otherwise error Error.Record(
            Extension.LoadString("SmartsheetGlobal.Error.AccessDenied.Reason"),
            Extension.LoadString("SmartsheetGlobal.Error.AccessDenied.Message"));

Refresh = (dataSourcePath, refresh_token) =>
    let
        region = Json.Document(dataSourcePath)[region],
        config = GetEndpointOAuthConfig(region),
        Response = Web.Contents(
            config[token_url],
            [
                Content = Text.ToBinary(
                    Uri.BuildQueryString(
                        [
                            grant_type = "refresh_token",
                            client_id = config[client_id],
                            refresh_token = refresh_token,
                            redirect_uri = config[redirect_uri],
                            hash = Binary.ToText(
                                Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(config[client_secret] & "|" & refresh_token)),
                                BinaryEncoding.Hex)
                        ])),
                Headers = [#"Content-type" = "application/x-www-form-urlencoded", Accept = "application/json"]
            ]),
        Parts = Json.Document(Response)
    in
        Parts;

// Constrains a value to a number between the minimum and maximum, if the value is not a number or not provided then the value returned is the default
SmartsheetGlobal.Clamp = (requestedValue as nullable any, default as number, min as number, max as number, valueName as text) as number =>
    let 
        // Ensure the value is a number. If a non-numeric value is provided this will cause failure and information about why will be in the diagnostic logs.
        value = 
            try 
                Value.As((requestedValue ?? default), Number.Type)
            otherwise
                default,
        output = 
            if value < min then 
                Diagnostics.Trace(TraceLevel.Warning, "'" & Text.From(value) & "' is below the minimum for " & valueName & ". Clamping value to " & Text.From(min), min)
            else if value > max then 
                Diagnostics.Trace(TraceLevel.Warning, "'" & Text.From(value) & "' is above the maximum for " & valueName & ". Clamping value to " & Text.From(max), max)
            else 
                value
    in
        output;

// Given the possibly requested # of retries, what value should be used?
// If null or not a number return the default, otherwise constrain to min/max
SmartsheetGlobal.GetMaxRetries = (requestedRetries as nullable any) as number =>
    let
        default = 1,
        min = 1,
        max = 2,
        valueName = "MaxRetries"
    in
        SmartsheetGlobal.Clamp(requestedRetries, default, min, max, valueName);

// This is a workaround for a bug in the engine where very long integers (in a certain range) fail to be converted 
// from scientific notation to a decimal representation during a Text.From() call.
SmartsheetGlobal.UnSciNot = (input as text) as nullable text =>
    let
        Source = input,
        SciNot = if Text.Contains(Source, "E") and Text.Contains(Source, ".") then Source
             else if Text.Contains(Source, ".") then Source & "E+0"
             else if Text.Contains(Source, "E") then Text.Insert(Source, Text.PositionOf(Source, "E"), ".")
             else Source & ".E+0",
        EPos = Text.PositionOf(SciNot, "E"),
        DecPos = Text.PositionOf(SciNot, "."),
        LeftOfDec = Text.Range(SciNot, 0, DecPos),
        RightOfDec = Text.Range(SciNot, DecPos + 1, EPos - DecPos - 1),
        Exponent = Number.From(Text.Range(SciNot, EPos + 1, Text.Length(SciNot) - EPos - 1)),
        RightWithPad = if Exponent > Text.Length(RightOfDec) then Text.PadEnd(RightOfDec, Exponent, "0")
             else RightOfDec,
        LeftWithPad = if Exponent * (- 1) > Text.Length(LeftOfDec) then Text.PadStart(LeftOfDec, Exponent * (- 1), "0")
             else LeftOfDec,
        RightWithDecimal = if Exponent >= 0 then Text.Insert(RightWithPad, Exponent, ".")
             else RightWithPad,
        LeftWithDecimal = if Exponent < 0 then Text.Insert(LeftWithPad, Text.Length(LeftWithPad) - (Exponent * (- 1)), ".")
             else LeftWithPad,
        Together = LeftWithDecimal & RightWithDecimal,
        Trimmed = Text.Trim(Together, "0"),
        PrependZero = if Text.At(Trimmed, 0) = "." then "0" & Trimmed
             else Trimmed,
        RemoveTrailingDec = if Text.At(PrependZero, Text.Length(PrependZero) - 1) = "." then Text.Range(PrependZero, 0, Text.Length(PrependZero) - 1)
             else PrependZero,
        output = RemoveTrailingDec
    in
        output;
 
// This is a helper function used to implement retries. It was taken from 
// the MS documentation here: https://learn.microsoft.com/en-us/power-query/helper-functions#valuewaitfor
Value.WaitFor = (producer as function, interval as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, null},
            (state) => state{0} <> null and (count = null or state{0} <= count),
            (state) => if state{1} <> null then {null, state{1}} else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), interval(state{0}))},
            (state) => state{1})
    in
        List.Last(list);

// This will retry failed requests with exponential backoff and jitter
// The pattern followed to implement retry is from https://learn.microsoft.com/en-us/power-query/wait-retry
// Status Code Handling
// - 408, 429, 500, 502, 503, 504, and 509 are retried
// NOTE: https://learn.microsoft.com/en-us/power-query/handling-status-codes
//  - 408, 429, 503, 504, and 509 would be automatically retried but we wouldn't 
//      get any of our diagnostic logs so we're handling the retry for all the status codes ourselves
//  - The built in retries will honor "Retry-after" headers which we do not do here, but Smartsheet does not supply these.
// options - Must be optional for backwards compatibility, because QueryInternal is a published function that users can call directly
//  - MaxRetries a number from 1 to 2 (requested value is bounded to 1 to 2)
Smartsheet.QueryInternal = (region as text, endpoint as text, args as text, headers as record, optional options as nullable record) =>
    let
        _options = options ?? [],  // If not provided, default to empty record
        // 1 + because the initial request counts too
        maxAttempts = 1 + SmartsheetGlobal.GetMaxRetries(options[MaxRetries]?),
        manuallyHandledStatusCodes = {408, 429, 500, 502, 503, 504, 509},
        baseUrl = GetEndpointApiUrl(region),
        url = baseUrl & endpoint & "?" & args,
        result = 
            let
                waitForResult = Value.WaitFor(
                    (iteration) =>
                        let
                            result = Web.Contents(url, [Headers = headers, ManualStatusHandling = manuallyHandledStatusCodes, IsRetry = iteration > 0]),
                            status = Value.Metadata(result)[Response.Status],
                            actualResult = 
                                if List.Contains(manuallyHandledStatusCodes, status) then
                                    // iteration hasn't been incremented yet, hence the +1
                                    if (iteration + 1) < maxAttempts then
                                        Diagnostics.Trace(
                                            TraceLevel.Information, 
                                            // iteration hasn't been incremented yet, hence the +1
                                            "Retrying failed request. Failure Status: " & Text.From(status) & ", Retry Attempt: " & Text.From(iteration + 1) & ", Url: " & url, 
                                            // null is returned as the result
                                            null)
                                    else 
                                        Diagnostics.Trace(
                                            TraceLevel.Information, 
                                            "All " & Text.From(maxAttempts) & " atttempts failed. Failure Status: " & Text.From(status) & ", Url: " & url,
                                            // null is returned as the result
                                            null)
                                else 
                                    result
                        in
                            actualResult, 
                    ExponentialBackoff, 
                    maxAttempts
                )
            in
                if waitForResult = null then
                    error "Failed after multiple retry attempts."
                else
                    Json.Document(waitForResult)
    in
        result;

// Returns the duration of seconds to wait before retrying a request
ExponentialBackoff = (iteration as number) as duration => 
    let 
        baseDelay = Number.Power(2, iteration),
        delay = 
            // No delay for first iteration
            if iteration = 0 then 0 
            else Number.RoundDown(baseDelay + 1 + Number.RandomBetween(-baseDelay/2, baseDelay/2))
    in
        #duration(0, 0, 0, delay);

// No need for paging for "sheets" endpoint, as all rows are returned by default when no "page" or "pageSize" parameters are specified
SheetExpand = (region as text, sheetId as text, options as record) =>
    let
        raw = Smartsheet.QueryInternal(region, "sheets/" & sheetId, "", [], options),
            //Column titles in a list
        columns = raw[columns],
        columnTitles = List.Transform(columns, each [title]),
        columnTitlesWithRowNumber = List.InsertRange(columnTitles, 0, {"RowNumber"}),

            //Build up rows
        RowAsList = (row) =>
            let
                listOfCells = row[cells],
                cellValuesList = List.Transform(listOfCells, each if Record.HasFields(_, "value") then [value]
                     else null),
                rowNumberFirst = List.InsertRange(cellValuesList, 0, {row[rowNumber]})
            in
                rowNumberFirst,
        listOfRows = List.Transform(raw[rows], each RowAsList(_)),
        result = Table.FromRows(listOfRows, columnTitlesWithRowNumber) meta [ShouldInferTableType = true]
    in
        result;

// Limits report page size. If null or not a number return the default, otherwise constrain to min/max
SmartsheetGlobal.GetReportPageSize = (requestedSize as nullable any) as number =>
    let
        default = 1000,
        min = 500,
        max = 10000,
        valueName = "ReportPageSize"
    in
        SmartsheetGlobal.Clamp(requestedSize, default, min, max, valueName);

// Paging is necessary to obtain all rows
ReportExpand = (region as text, reportId as text, options as record) =>
    let
        // Limit page size to the valid range
        pageSize = SmartsheetGlobal.GetReportPageSize(options[ReportPageSize]?),
        raw = Smartsheet.QueryInternal(region, "reports/" & reportId, "pageSize=" & Text.From(pageSize), [], options),
        //Column titles in a list
        columns = raw[columns],
        columnTitles = List.Transform(columns, each [title]),
        columnTitlesWithRowNumber = List.InsertRange(columnTitles, 0, {"RowNumber"}),

        //Build up rows
        //First we need to use paging to build a complete list of ALL rows
        rowList = List.Combine(
            List.Generate(
                () => [i = 0],  //start function (page number, 0-based in our implementation so loop iterates at least once)
                each [i] * pageSize < raw[totalRowCount], //continuation condition
                each [i = [i] + 1],  //next function
                each Smartsheet.QueryInternal(region, "reports/" & reportId, "pageSize=" & Text.From(pageSize) & "&page=" & Text.From([i] + 1), [], options)[rows])), //transformation function (page numbers start at 1 for Smartsheet)
        RowAsList = (row) =>
            let
                listOfCells = row[cells],
                cellValuesList = List.Transform(listOfCells, each if Record.HasFields(_, "value") then [value]
                     else null),
                rowNumberFirst = List.InsertRange(cellValuesList, 0, {row[rowNumber]})
            in
                rowNumberFirst,
        listOfRows = List.Transform(rowList, each RowAsList(_)),
        result = Table.FromRows(listOfRows, columnTitlesWithRowNumber) meta [ShouldInferTableType = true]
    in
        result;

Smartsheet.GetNodeSheets = (region, sheets, partialTable, options as record) =>
    let
        sheetsRows = List.Transform(sheets, each TransformSheets(region, _, options)),
        biggerTable = Table.InsertRows(partialTable, 0, sheetsRows)
    in
        biggerTable;

Smartsheet.GetNodeReports = (region, reports, partialTable, options as record) =>
    let
        reportsRows = List.Transform(reports, each TransformReports(region, _, options)),
        biggerTable = Table.InsertRows(partialTable, 0, reportsRows)
    in
        biggerTable;

Smartsheet.GetNodeFolders = (region, folders, partialTable, options as record) =>
    let
        foldersRows = List.Transform(folders, each TransformFolders(region, _, options)),
        biggerTable = Table.InsertRows(partialTable, 0, foldersRows)
    in
        biggerTable;

Smartsheet.GetNodeWorkspaces = (region, workspaces, partialTable, options as record) =>
    let
        workspacesRows = List.Transform(workspaces, each TransformWorkspaces(region, _, options)),
        biggerTable = Table.InsertRows(partialTable, 0, workspacesRows)
    in
        biggerTable;

TransformSheets = (region as text, sheet as record, options as record) =>
    let
        sheetId = SmartsheetGlobal.UnSciNot(Text.From(sheet[id])),
        result = [Name = sheet[name], Key = sheetId],
        withData = Record.AddField(result, "Data", () => SheetExpand(region, sheetId, options), true),
        withItemKind = Record.AddField(withData, "ItemKind", "Table"),
        withItemName = Record.AddField(withItemKind, "ItemName", "Table"),
        final = Record.AddField(withItemName, "IsLeaf", true)
    in
        final;

TransformReports = (region as text, report as record, options as record) =>
    let
        reportId = SmartsheetGlobal.UnSciNot(Text.From(report[id])),
        result = [Name = report[name], Key = reportId],
        withData = Record.AddField(result, "Data", () => ReportExpand(region, reportId, options), true),
        withItemKind = Record.AddField(withData, "ItemKind", "View"),
        withItemName = Record.AddField(withItemKind, "ItemName", "View"),
        final = Record.AddField(withItemName, "IsLeaf", true)
    in
        final;

// Retrieve the folder, create and return a navigation table for its contents
// This is called when a user expands a folder node in the navigation table
FolderNavTableBuilder = (region as text, folderId as text, options as record) =>
    let
        source = Smartsheet.QueryInternal(region, "folders/" & Text.From(folderId), "", [], options)
    in        
        Smartsheet.NavTableBuilder(region, source, options);

TransformFolders = (region as text, folder as record, options as record) =>
    let
        folderId = SmartsheetGlobal.UnSciNot(Text.From(folder[id])),
        result = [Name = folder[name], Key = folderId],
        // Lazily fetch the workspace and display its contents when the user expands it
        withData = Record.AddField(result, "Data", () => FolderNavTableBuilder(region, folderId, options), true),
        withItemKind = Record.AddField(withData, "ItemKind", "Folder"),
        withItemName = Record.AddField(withItemKind, "ItemName", "Folder"),
        final = Record.AddField(withItemName, "IsLeaf", false)
    in
        final;

// Retrieve the workspace, create and return a navigation table for its contents
// This is called when a user expands a workspace node in the navigation table
WorkspaceNavTableBuilder = (region as text, workspaceId as text, options as record) =>
    let
        source = Smartsheet.QueryInternal(region, "workspaces/" & workspaceId, "", [], options)
    in        
        Smartsheet.NavTableBuilder(region, source, options);

TransformWorkspaces = (region as text, workspace as record, options as record) =>
    let
        workspaceId = SmartsheetGlobal.UnSciNot(Text.From(workspace[id])),
        result = [Name = workspace[name], Key = workspaceId],
        // Lazily fetch the workspace and display its contents when the user expands it
        withData = Record.AddField(result, "Data", () => WorkspaceNavTableBuilder(region, workspaceId, options), true),
        withItemKind = Record.AddField(withData, "ItemKind", "Database"),
        withItemName = Record.AddField(withItemKind, "ItemName", "Database"),
        final = Record.AddField(withItemName, "IsLeaf", false)
    in
        final;

Smartsheet.NavTableBuilder = (region as text, someNode, options as record) =>
    let
        Source = someNode,
            //begin by creating an empty nav table
        objects = #table({"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, {}),

            //walk through all available sheets, and for each add a row to this nav table
        withSheets = if Record.HasFields(Source, "sheets") then Smartsheet.GetNodeSheets(region, Source[sheets], objects, options)
             else objects,
            //walk through all available reports, and for each add a row to this nav table
        withReports = if Record.HasFields(Source, "reports") then Smartsheet.GetNodeReports(region, Source[reports], withSheets, options)
             else withSheets,
            //walk through all available folders, and for each add a row to this nav table
        withFolders = if Record.HasFields(Source, "folders") then Smartsheet.GetNodeFolders(region, Source[folders], withReports, options)
             else withReports,
            //walk through all available workspaces, and for each add a row to this nav table
        withWorkspaces = if Record.HasFields(Source, "workspaces") then Smartsheet.GetNodeWorkspaces(region, Source[workspaces], withFolders, options)
             else withFolders,

            //Turn it into a nav table
        navTable = Table.ToNavigationTable(withWorkspaces, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable; //output is a fully-functioning nav table for node

Table.ToNavigationTable = (table as table, keyColumns as list, nameColumn as text, dataColumn as text, itemKindColumn as text, itemNameColumn as text, isLeafColumn as text) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta [
            NavigationTable.NameColumn = nameColumn,
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn,
            Preview.DelayColumn = itemNameColumn,
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

// Merges the responses from /folders/personal and /workspaces to build up the record for the root of the navigation table
SmartsheetGlobal.CreateRootNavigationTableRecord = (personalFolderResponse as record, workspacesResponse as record) as record =>
    let
        // Get list of root workspaces, empty list if none
        rootWorkspaces = if Record.HasFields(workspacesResponse, "data") then workspacesResponse[data] 
            else {}, // empty list
        // Get the list of personal workspaces, empty list if none
        personalWorkspaces = if Record.HasFields(personalFolderResponse, "workspaces") then personalFolderResponse[workspaces] 
            else {}, // empty list
        // Merge personal and root workspace lists
        allWorkspaces = List.Combine({personalWorkspaces, rootWorkspaces}),

        // Build up the object that will be used as the root of the navigation table
        objects = [],
        withSheets = if Record.HasFields(personalFolderResponse, "sheets") then Record.AddField(objects, "sheets", personalFolderResponse[sheets]) 
            else objects,
        withReports = if Record.HasFields(personalFolderResponse, "reports") then Record.AddField(withSheets, "reports", personalFolderResponse[reports]) 
            else withSheets,
        withFolders = if Record.HasFields(personalFolderResponse, "folders") then Record.AddField(withReports, "folders", personalFolderResponse[folders]) 
            else withReports,
        withWorkspaces = if List.IsEmpty(allWorkspaces) then withFolders
            else Record.AddField(withFolders, "workspaces", allWorkspaces)
    in
        withWorkspaces;

// The entrypoint to the connector
// Populates the navigation table
ContentsInternal = (region as text, optional options as nullable record) as table =>
    let
        _options = options ?? [], // If not provided, default to empty record
        // Previously for initial render, every item the user had access to was loaded via `/home` API endpoint. 
        // This endpoint is too slow, leads to timeouts and errors, puts strain on Core DB, and it's deprecated. 
        // The new behavior is to load only top-level assets (Sheets, Reports, Folders, and Workspaces) for initial render. 
        // These assets are loaded by merging the responses from `/folders/personal` and `/workspaces`. 
        // Then as the user expands nodes, child assets are retrieved via `/folders/{folderId}` and `/workspaces/{workspaceId}` endpoints.
        personalFolderResponse = Smartsheet.QueryInternal(region, "folders/personal", "", [], _options),
        workspacesResponse = Smartsheet.QueryInternal(region, "workspaces", "", [], _options),
        root = SmartsheetGlobal.CreateRootNavigationTableRecord(personalFolderResponse, workspacesResponse),
        nodesNavTable = Smartsheet.NavTableBuilder(region, root, _options), 
        fullTable = Table.InsertRows(
            nodesNavTable,
            0,
            {
                [
                    Name = "SmartsheetGlobal.Query",
                    Key = "function_query",
                    Data = Smartsheet.QueryInternal,
                    ItemKind = "Function",
                    ItemName = "Function",
                    IsLeaf = true
                ]
            }),
        asNav = Table.ToNavigationTable(fullTable, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        asNav;

// Reused between the SmartsheetGlobal.Contents and SmartsheetGlobal.Query functions.
RegionParameterType =
    let
        regionUS = GetEndpointRecord("US"),
        regionEU = GetEndpointRecord("EU"),

        // Declare the enum type values.
        // RegionCode will be the text included in the generated query.
        // RegionLabel will be displayed in the UI.
        // Using Documentation.AllowedValues turns the input control into a dropdown list.
        RegionType.US = regionUS[RegionCode] meta [
            Documentation.Name = "RegionType.US",
            Documentation.Caption = regionUS[RegionLabel]
        ],

        RegionType.EU = regionEU[RegionCode] meta [
            Documentation.Name = "RegionType.EU",
            Documentation.Caption = regionEU[RegionLabel]
        ],

        RegionType = (type text meta [
            Documentation.FieldCaption = "Region",
            Documentation.FieldDescription = "The Smartsheet region to connect to.",
            Documentation.AllowedValues = { RegionType.US, RegionType.EU }
        ])
    in
        RegionType;

ContentsFunctionType =
    let
        t = type function (region as RegionParameterType, optional options as nullable record) as table
    in
        t meta [
            Documentation.Description = Extension.LoadString("SmartsheetGlobal.Contents.Function.Description"),
            Documentation.DisplayName = Extension.LoadString("SmartsheetGlobal.Contents.Function.DisplayName"),
            Documentation.Caption = Extension.LoadString("SmartsheetGlobal.Contents.Function.Caption"),
            Documentation.Name = Extension.LoadString("SmartsheetGlobal.Contents.Function.Name"),
            Documentation.LongDescription = Extension.LoadString("SmartsheetGlobal.Contents.Function.LongDescription"),
            Documentation.Examples = {
                [
                    Description = Extension.LoadString("SmartsheetGlobal.Contents.Function.Example1.Description"),
                    Code = Extension.LoadString("SmartsheetGlobal.Contents.Function.Example1.Code"),
                    Result = Extension.LoadString("SmartsheetGlobal.Contents.Function.Example1.Result")
                ]
            }
        ];

// Required parameters are marked with DataSource.Path. We only want the Region value to be factored into the credential path.
QueryFunctionType =
    let
        endpoint = (type text) meta [
            Documentation.FieldCaption = Extension.LoadString("SmartsheetGlobal.Query.Parameters.endpoint.FieldCaption"),
            Documentation.SampleValues = {Extension.LoadString("SmartsheetGlobal.Query.Parameters.endpoint.SampleValues")},
            Documentation.FieldDescription = Extension.LoadString("SmartsheetGlobal.Query.Parameters.endpoint.FieldDescription"),
            DataSource.Path = false
        ],
        args = (type text) meta [
            Documentation.FieldCaption = Extension.LoadString("SmartsheetGlobal.Query.Parameters.args.FieldCaption"),
            Documentation.SampleValues = {Extension.LoadString("SmartsheetGlobal.Query.Parameters.args.SampleValues")},
            Documentation.FieldDescription = Extension.LoadString("SmartsheetGlobal.Query.Parameters.args.FieldDescription"),
            DataSource.Path = false
        ],
        headers = (type record) meta [
            Documentation.FieldCaption = Extension.LoadString("SmartsheetGlobal.Query.Parameters.headers.FieldCaption"),
                //No example shown.
            Documentation.FieldDescription = Extension.LoadString("SmartsheetGlobal.Query.Parameters.headers.FieldDescription"),
            DataSource.Path = false 
        ],
        options = (type record) meta [
            Documentation.FieldCaption = Extension.LoadString("SmartsheetGlobal.Query.Parameters.options.FieldCaption"),
                //No example shown.
            Documentation.FieldDescription = Extension.LoadString("SmartsheetGlobal.Query.Parameters.options.FieldDescription"),
            DataSource.Path = false 
        ],
        t = type function (region as RegionParameterType, endpoint as endpoint, args as args, headers as headers, optional options as nullable options) as any
    in
        t meta [
            Documentation.Description = Extension.LoadString("SmartsheetGlobal.Query.Function.Description"),
            Documentation.DisplayName = Extension.LoadString("SmartsheetGlobal.Query.Function.DisplayName"),
            Documentation.Caption = Extension.LoadString("SmartsheetGlobal.Query.Function.Caption"),
            Documentation.Name = Extension.LoadString("SmartsheetGlobal.Query.Function.Name"),
            Documentation.LongDescription = Extension.LoadString("SmartsheetGlobal.Query.Function.LongDescription"),
            Documentation.Examples = {
                [
                    Description = Extension.LoadString("SmartsheetGlobal.Query.Function.Example1.Description"),
                    Code = Extension.LoadString("SmartsheetGlobal.Query.Function.Example1.Code"),
                    Result = Extension.LoadString("SmartsheetGlobal.Query.Function.Example1.Result")
                ]
            }
        ];
 