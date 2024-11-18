[Version = "2.4.0"] section Kognitwin;

redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";

authPath = "/configuration/auth-settings?client=powerbi";
assetsPath = "/assets";
projectPath = "/projects/powerBIConnector";
defaultLimit = 1000;

CreateNavTable =
    (baseUrl as text, config as list) as table =>
        let
            addedNavTableRecords =
                List.Transform(
                    config,
                    each
                        if [kind] = "config" then
                            [
                                id = [id],
                                Name = [name],
                                Data = CreateNavTable(baseUrl, [children]),
                                ItemKind = "Folder",
                                ItemName = "Folder",
                                IsLeaf = false
                            ]
                        else if [kind] = "getTypes" then
                            [
                                id = [id],
                                Name = [name],
                                Data = CreateTypesNavTable(baseUrl, [id]),
                                ItemKind = "Folder",
                                ItemName = "Folder",
                                IsLeaf = false
                            ]
                        else if [kind] = "getQuery" then
                            [
                                id = [id],
                                Name = [name],
                                Data = CreateQueryNavTable(baseUrl, [name], [query]),
                                ItemKind = "Folder",
                                ItemName = "Folder",
                                IsLeaf = false
                            ]
                        else if [kind] = "getRealTimeSensorData" then
                            [
                                id = [id],
                                Name = [name],
                                Data = CreateRealTimeNavTable(baseUrl, [id]),
                                ItemKind = "Folder",
                                ItemName = "Folder",
                                IsLeaf = false
                            ]
                        else
                            [
                                id = [id],
                                Name = [name],
                                Data = "Invalid config",
                                ItemKind = "Folder",
                                ItemName = "Folder",
                                IsLeaf = false
                            ]
                ),
            createdTableFromRecords = Table.FromRecords(addedNavTableRecords),
            NavTable =
                Table.ToNavigationTable(
                    createdTableFromRecords,
                    {"id"},
                    "Name",
                    "Data",
                    "ItemKind",
                    "ItemName",
                    "IsLeaf"
                )
        in
            NavTable;

[
    DataSource.Kind = "Kognitwin",
    Publish = "Kognitwin.Publish"
]
// Starting point for the Power BI Connector
shared
Kognitwin.Contents =
    Value.ReplaceType(
        GetApiUrl,
        GetApiUrlType
    );
Kognitwin = [
    TestConnection =
        (dataSourcePath) =>
            {
                "Kognitwin.Contents",
                dataSourcePath
            },
    Authentication = [
        //The connector supports oauth2.0 authorization code flow with PKCE
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh,
            Logout = Logout
        ]
        // Implicit = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Helper functions for OAuth2: StartLogin, FinishLogin, Refresh, Logout
StartLogin =
    (resourceUrl, state, display) =>
        let
            authParams = GetAuthParams(resourceUrl),
            codeVerifier = Text.NewGuid() & Text.NewGuid(),
            authorizeUrl =
                authParams[authorize_uri]
                & "?"
                & Uri.BuildQueryString(
                    [
                        client_id = authParams[client_id],
                        response_type = "code",
                        code_challenge_method = "plain",
                        code_challenge = codeVerifier,
                        state = state,
                        scope = authParams[scopes],
                        redirect_uri = redirect_uri
                    ]
                )
        in
            [
                LoginUri = authorizeUrl,
                CallbackUri = redirect_uri,
                WindowHeight = 720,
                WindowWidth = 1024,
                Context =
                    resourceUrl
                    & "?"
                    & Uri.BuildQueryString([code_challenge = codeVerifier])
            ];

FinishLogin =
    (context, callbackUri, state) =>
        let
            code = Uri.Parts(callbackUri)[Query][code],
            host = Uri.Parts(context)[Host]
        in
            TokenMethod(
                host,
                code,
                "authorization_code",
                Uri.Parts(context)[Query][code_challenge]
            );

Refresh =
    (resourceUrl, refresh_token) =>
        TokenMethod(
            resourceUrl,
            refresh_token,
            "refresh_token"
        );

Logout =
    (clientApplication, resourceUrl, accessToken) =>
        let
            authParams = GetAuthParams(resourceUrl),
            logout_uri = authParams[logout_uri]
        in
            logout_uri;

TokenMethod =
    (resourceUrl, code, grant_type, optional verifier) =>
        let
            authParams = GetAuthParams(resourceUrl),
            codeVerifier =
                if (verifier <> null) then
                    [
                        code_verifier = verifier
                    ]
                else
                    [],
            codeParameter =
                if (grant_type = "authorization_code") then
                    [
                        code = code
                    ]
                else
                    [
                        refresh_token = code
                    ],
            query =
                codeVerifier
                & codeParameter
                & [
                    client_id = authParams[client_id],
                    grant_type = grant_type,
                    redirect_uri = redirect_uri
                ],
            Response =
                Web.Contents(
                    authParams[token_uri],
                    [
                        Content = Text.ToBinary(Uri.BuildQueryString(query)),
                        Headers = [
                            #"Content-type" = "application/x-www-form-urlencoded",
                            #"Accept" = "application/json"
                        ]
                    ]
                ),
            Parts = Json.Document(Response)
        in
            // check for error in response
            if (Parts[error]? <> null) then
                error
                    Error.Record(
                        Parts[error],
                        Parts[message]?
                    )
            else
                Parts;

// Getting auth configuration settings from the Kognitwin api
GetAuthParams =
    (url) =>
        let
            authParams = GetData(url & "/api" & authPath)
        in
            authParams;

Kognitwin.Publish = [
    Category = "Other",
    ButtonText = {
        Extension.LoadString("ButtonTitle"),
        Extension.LoadString("ButtonHelp")
    },
    LearnMoreUrl = "https://docs.kognitwin.com/",
    SourceImage = Kognitwin.Icons,
    SourceTypeImage = Kognitwin.Icons
];
Kognitwin.Icons = [
    Icon16 = {
        Extension.Contents("Kognitwin16.png"),
        Extension.Contents("Kognitwin20.png"),
        Extension.Contents("Kognitwin24.png"),
        Extension.Contents("Kognitwin32.png")
    },
    Icon32 = {
        Extension.Contents("Kognitwin32.png"),
        Extension.Contents("Kognitwin40.png"),
        Extension.Contents("Kognitwin48.png"),
        Extension.Contents("Kognitwin64.png")
    }
];

// Prompts the user for api-url to connect to
GetApiUrl =
    (baseUrl as text) =>
        let
            config = GetDataMiddleware(baseUrl, projectPath),
            navTable = try CreateNavTable(baseUrl, config[navigator]) otherwise error "Could not create navigator."
        in
            navTable;
GetApiUrlType =
    type function (url as
        (
            Uri.Type
            meta
            [
                Documentation.FieldCaption = "Kognitwin URL",
                Documentation.FieldDescription = "Enter Kognitwin URL Environment",
                Documentation.SampleValues = {
                    "https://example.kognitwin.com"
                }
            ]
        )) as table
    meta
    [
        Documentation.Name = "Kognitwin v1.1"
    ];

GetLimit =
    (baseUrl as text) as any =>
        let
            config = GetDataMiddleware(baseUrl, projectPath),

            limit =
                if config[limit] <> null then
                    config[limit]
                else
                    defaultLimit
        in
            limit;

SensorDataForm = (baseUrl as text, assetId as text) => 
    let
        SensorForm = type function (
            sensorId as ( type text meta [
                Documentation.FieldCaption = "Select sensor ID",
                Documentation.FieldDescription = "Sensor id for real time data"
                ]
            ),
            
            timeInterval as ( type text meta [
                Documentation.FieldCaption = "Select Timeinterval",
                Documentation.FieldDescription = "Select interval",
                Documentation.AllowedValues = {"Last 24 hours","Last 7 days", "Last 30 days", "Last 100 days"},
                Documentation.SampleValues = {"Last 24 hours"}
                ]
            ),
            
            aggregationType as ( type text meta [
                Documentation.FieldCaption = "Select aggregation type",
                Documentation.FieldDescription = "Select how the timeseries data will ",
                Documentation.AllowedValues = {"No Aggregation", "min", "max", "mean"}
                ]
            ),
            aggregationInterval as ( type text meta [
                Documentation.FieldCaption = "Select aggregation interval",
                Documentation.FieldDescription = "",
                Documentation.AllowedValues = {"No Aggregation","1h","2h","10h","12h","1d","2d"}
                ]
            ),

            datapointslimit as ( type text meta [
                Documentation.FieldCaption = "Select Datapoints Limit",
                Documentation.FieldDescription = "Etc 1000",
                Documentation.AllowedValues = {"100","1000","3000","10000","100000"}
                ]
            )
        ) as table,

        SensorDataPagination = (sensorId as text, timeInterval as text, aggregationType as text, aggregationInterval as text, datapointslimit as text) =>
            let 
                dateToTextFormat = "yyyy-MM-ddTHH:mm:ss.fffZ",

                daysBack = if timeInterval = "Last 24 hours" then
                  1
                  else if timeInterval = "Last 7 days" then
                    7
                  else if timeInterval = "Last 30 days" then
                    30
                  else if timeInterval = "Last 100 days" then
                    100
                  else
                    7,

                startDate = Date.AddDays(Date.From(DateTime.LocalNow()),-daysBack),
                dateEndText =  DateTime.ToText(DateTime.LocalNow(), dateToTextFormat),
                dateStartText = Date.ToText(startDate, dateToTextFormat),
                // dateEndText = Date.ToText(endDate, dateToTextFormat),

                aggregationTypeUrl = 
                  if aggregationType = "No Aggregation" then
                      ""
                  else
                      "&aggregate="& aggregationType,

                aggregationIntervalUrl =
                  if aggregationType = "No Aggregation" then
                      ""
                  else
                      "&interval="& aggregationInterval,

                orderByUrl =
                  if aggregationType = "No Aggregation" then
                        ""
                  else
                      "&orderBy=time asc&fill=none",

                urlPath = "/timeseries?id="& sensorId & "&source=" & assetId & "&from=" & dateStartText & "&to=" & dateEndText & aggregationTypeUrl & aggregationIntervalUrl & orderByUrl & "&limit="&datapointslimit,
                dataList = GetDataMiddleware(baseUrl, urlPath),
                datapoints = Table.FromRecords(dataList)
            in
                datapoints
    in
        Value.ReplaceType(SensorDataPagination, SensorForm);

SensorIDForm = (baseUrl as text, assetId as text) => 
    let
      //Get sensor types
      urlPath = assetsPath & "?source=" & assetId & "&distinct=type",
      dataList = GetDataMiddleware(baseUrl, urlPath),

        SensorForm = type function (
            sensorType as ( type text meta [
                Documentation.FieldCaption = "Select Sensor Category",
                Documentation.FieldDescription = "Sensor id for real time data",
                Documentation.AllowedValues = dataList
                ]
              )
        ) as table,

        SensorPagination = (sensorType as text) =>
            let
              urlPathSensors = assetsPath & "?source=" & assetId & "&type=" & sensorType,
              
              dataTable = PagedTable(baseUrl,urlPathSensors,defaultLimit),
              
              transformed = Table.TransformRows(
                    dataTable,
                    each [
                        Id = Record.FieldOrDefault([Column1], "id", null),
                        Source = Record.FieldOrDefault([Column1], "source", null),
                        Asset = [Column1]
                    ]
                ),
                tableTransformed = Table.FromRecords(transformed)
            in
              tableTransformed
    in
        Value.ReplaceType(SensorPagination, SensorForm);

    
CreateRealTimeNavTable = (baseUrl as text, assetId as text) => 
    let
        objects = #table(
                {"Name","Key","Data","ItemKind","ItemName","IsLeaf"},
                {
                    {"Sensor Data", "RealTimeData", SensorDataForm(baseUrl, assetId), "Function", "Function", true},
                    {"Available Sensors", "SensorList", SensorIDForm(baseUrl, assetId), "Function", "Function", true}
                }
            ),
	    NavTable = Table.ForceToNavigationTable(objects, {"Key"},"Name","Data","ItemKind","ItemName","IsLeaf")
    in
	    NavTable;

// Creates a navigation table for assets: locked to source
CreateTypesNavTable =
    (baseUrl as text, sourceId as text) =>
        let
            typesTable =
                GetDataTable(
                    baseUrl,
                    assetsPath
                    & "?source="
                    & sourceId
                    & "&distinct=type"
                ),
            addedNavTableRecords =
                try
                    Table.TransformRows(
                        typesTable,
                        each
                            [
                                Type = [Column1],
                                Name = [Column1],
                                Data =
                                    let
                                        limit = GetLimit(baseUrl),
                                        dataTable =
                                            PagedTable(
                                                baseUrl,
                                                assetsPath
                                                & "?source="
                                                & sourceId
                                                & "&type="
                                                & [Column1]  
                                                & "&externalData=1",
                                                limit
                                            ),

                                        transformed = Table.TransformRows(
                                            dataTable,
                                            each [
                                               Id = Record.FieldOrDefault([Column1], "id", null),
                                               Source = Record.FieldOrDefault([Column1], "source", null),
                                               Type = Record.FieldOrDefault([Column1], "type", null),
                                               Name = Record.FieldOrDefault([Column1], "name", null),
                                               Asset = [Column1]
                                            ]
                                        ),
                                        tableTransformed = Table.FromRecords(transformed)
                                    in
                                        tableTransformed,
                                ItemKind = "Function",
                                ItemName = "Function",
                                IsLeaf = true
                            ]
                    ),

            createdTableFromRecords =
                if addedNavTableRecords[HasError] then
                    error "No data found."
                else
                    Table.FromRecords(addedNavTableRecords[Value]),
            NavTable =
                Table.ToNavigationTable(
                    createdTableFromRecords,
                    {"Type"},
                    "Name",
                    "Data",
                    "ItemKind",
                    "ItemName",
                    "IsLeaf"
                )
        in
            NavTable;


ConvertRecordToQueryParams = (params as record) => 
    let
        recordTable = Record.ToTable(params),

        // list of records
        transformed =  Table.TransformRows(
                recordTable,
                each [
                    param = [Name] & "=" & [Value]
                ]
        ),

        queryString = List.Accumulate(transformed, "", (state, current) => state & List.First(Record.FieldValues(current)) & "&"),

        trimmed = Text.TrimEnd(queryString, "&")
    in
        trimmed;

CreateQueryNavTable = 
    (baseUrl as text, name as text, query as record) =>
        let
            params = Record.Field(query, "urlParams"),
            urlParamsCount = Record.FieldCount(params),

            useDistinctParam = Record.HasFields(params, "distinct"),
            distinctColumn = Record.Field(params, "distinct"),
            
            apiPath = Record.Field(query, "apiPath"),            
            paramsString = ConvertRecordToQueryParams(params),

            paramsWithoutDistinct = if useDistinctParam then
                    Record.RemoveFields(params, "distinct")
                else 
                    params,
            
            paramsStringWithoutDistinct = ConvertRecordToQueryParams(paramsWithoutDistinct),

            // if distinct: create leafnodes for each distinct variable. If not: have 1 leafnode equal to column name
            leafTable = if useDistinctParam then
                    GetDataTable(baseUrl, assetsPath & "?" & paramsString)
                  else
                      Table.FromRecords({[Column1 = name]}),

            addedNavTableRecords =
                try
                    Table.TransformRows(
                        leafTable,
                        each
                            [
                                Type = [Column1],
                                Name = [Column1],
                                Data =
                                    let
                                        limit = GetLimit(baseUrl),

                                        queryString = if useDistinctParam then
                                                paramsStringWithoutDistinct & "&" & distinctColumn & "=" & [Column1]
                                            else
                                                paramsStringWithoutDistinct,
                                        separator = if urlParamsCount = 0 then "" else "&",
                                        combinedQueryString = apiPath & "?" & queryString & separator & "externalData=1",
                                        
                                        dataTable =
                                            PagedTable(
                                                baseUrl,
                                                combinedQueryString,
                                                limit
                                            ),

                                        transformed = Table.TransformRows(
                                            dataTable,
                                            each [
                                               Id = Record.FieldOrDefault([Column1], "id", null),
                                               Source = Record.FieldOrDefault([Column1], "source", null),
                                               Type = Record.FieldOrDefault([Column1], "type", null),
                                               Name = Record.FieldOrDefault([Column1], "name", null),
                                               Asset = [Column1]
                                            ]
                                        ),
                                        tableTransformed = Table.FromRecords(transformed)
                                    in
                                        tableTransformed,
                                ItemKind = "Function",
                                ItemName = "Function",
                                IsLeaf = true
                            ]
                    ),

            createdTableFromRecords =
                if addedNavTableRecords[HasError] then
                    error "No data found."
                else
                    Table.FromRecords(addedNavTableRecords[Value]),
            NavTable =
                Table.ToNavigationTable(
                    createdTableFromRecords,
                    {"Type"},
                    "Name",
                    "Data",
                    "ItemKind",
                    "ItemName",
                    "IsLeaf"
                )
            
        in 
            NavTable;

// Sends a GET request to the specified URL and returns a table with the response
GetDataTable =
    (baseUrl as text, urlPath as text) =>
        let
            dataList = GetDataMiddleware(baseUrl, urlPath),
            dataTable =
                if (List.Count(dataList) = 0) then
                    null
                else
                    Table.FromList(
                        dataList,
                        Splitter.SplitByNothing(),
                        null,
                        null,
                        ExtraValues.Error
                    )
        in
            dataTable;

// Decide wheter GetData or GetDataWithIdp is used to fetch data
GetDataMiddleware = (baseurl as text, urlPath as text) => 
    let
        data = GetDataWithIdp(baseurl & "/api" & urlPath)
    in
        data;

// Sends a GET request to the specified URL and returns a list with the response
GetData =
    (url as text) =>
        let
            data =
                Json.Document(
                    Web.Contents(
                        url,
                        [Headers = [
                            Accept = "application/json"
                        ]]
                    )
                )
        in
            data;

// Same as GetData, but with required idp header
GetDataWithIdp =
    (url as text) =>
        let
            authParams = GetAuthParams(Uri.Parts(url)[Host]),
            idp = authParams[idp],
            dataList =
                Json.Document(
                    Web.Contents(
                        url,
                        [
                            Headers = [
                                Accept = "application/json",
                                idp = idp
                            ]
                        ]
                    )
                )
        in
            dataList;

//
// Common functions
//
// Expands the column given by columnName in table t and returns a table. Used for preview in Navigator.
expandRecordColumn =
    (t as table, columnName as text, optional prefix as text) as table =>
        let
            columns =
                Table.ColumnNames(
                    Table.FromRecords(
                        List.Select(
                            Table.Column(t, columnName),
                            each _ <> "" and _ <> null
                        )
                    )
                ),
            expandedTable =
                Table.ExpandRecordColumn(
                    t,
                    columnName,
                    columns,
                    if prefix <> null then
                        let
                            columnNames = AddColumnPrefix(prefix, columns)
                        in
                            columnNames
                    else
                        columns
                )
        in
            expandedTable;

AddColumnPrefix =
    (prefix as text, columns as list) as list =>
        let
            addedPrefix = List.Transform(columns, each prefix & _)
        in
            addedPrefix;

Table.ToNavigationTable =
    (table as table, keyColumns as list, nameColumn as text, dataColumn as text, itemKindColumn as text, itemNameColumn as text, isLeafColumn as text) as table =>
        let
            tableType = Value.Type(table),
            newTableType =
                Type.AddTableKey(
                    tableType,
                    keyColumns,
                    true
                )
                meta
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
Table.ForceToNavigationTable = (
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
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

    PagedTable = (baseUrl as text, urlPath as text, limit as number) =>
        Table.GenerateByPage(
        (previous) =>
            let
                next =
                    if (previous <> null) then
                        Value.Metadata(previous)[Next]
                    else
                        0,

                urlPathDone =
                    if (next <> 0) then
                        urlPath & "&offset=" & Number.ToText(next) & "&limit="& Number.ToText(limit)
                    else
                        urlPath & "&limit="& Number.ToText(limit),
                current =
                    if (previous <> null and next = null) then
                        null
                    else
                        GetDataTable(baseUrl, urlPathDone),
                link =
                    if  (current <> null) then
                        next + limit
                    else
                        null
            in
                current
                meta
                [
                    Next = link
                ]
    );


// The getNextPage function takes a single argument and is expected to return a nullable table

Table.GenerateByPage = (getNextPage as function) as table =>
    let        
        listOfPages = List.Generate(
            () => getNextPage(null),            // get the first page of data
            (lastPage) => lastPage <> null,     // stop when the function returns null
            (lastPage) => getNextPage(lastPage) // pass the previous page to the next function call
        ),
        // concatenate the pages together
        tableOfPages = Table.FromList(listOfPages, Splitter.SplitByNothing(), {"Column1"}),
        firstRow = tableOfPages{0}?
    in
        // if we didn't get back any pages of data, return an empty table
        // otherwise set the table type based on the columns of the first page
        if (firstRow = null) then
            Table.FromRows({})
        else        
            Value.ReplaceType(
                Table.ExpandTableColumn(tableOfPages, "Column1", Table.ColumnNames(firstRow[Column1])),
                Value.Type(firstRow[Column1])
            );


