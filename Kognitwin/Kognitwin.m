[Version = "1.0.0"] section Kognitwin;

redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";

authPath = "/api/configuration/auth-settings";

assetsPath = "/api/assets";

projectPath = "/api/projects/powerBIConnector";

port = "";

/* // Autpath, assetsPath, projectPath and port for testing with localhost
authPath = "configuration/auth-settings";

assetsPath = "/assets";

projectPath = "/projects/powerBIConnector";

port = "8080"; */
defaultLimit = 1000;

CreateNavTable =
    (url as text, config as list) as table =>
        let
            addedNavTableRecords =
                List.Transform(
                    config,
                    each
                        if [kind] = "config" then
                            [
                                id = [id],
                                Name = [name],
                                Data = CreateNavTable(url, [children]),
                                ItemKind = "Folder",
                                ItemName = "Folder",
                                IsLeaf = false
                            ]
                        else if [kind] = "getTypes" then
                            [
                                id = [id],
                                Name = [name],
                                Data = CreateTypesNavTable(url, [id]),
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
            authParams =
                if Uri.Parts(url)[Host] = "localhost" then
                    GetData(
                        Uri.Parts(url)[Host]
                        & ":"
                        & port
                        & "/"
                        & authPath
                    )
                else
                    GetData(url & authPath)
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
    (url as text) =>
        let
            config = GetDataWithIdp(url & projectPath),
            navTable = try CreateNavTable(url, config[navigator]) otherwise error "Could not create navigator."
        in
            navTable;

GetApiUrlType =
    type function (url as
        (
            Uri.Type
            meta
            [
                Documentation.FieldCaption = "Kognitwin URL",
                Documentation.FieldDescription = "Enter Kognitwin URL",
                Documentation.SampleValues = {
                    "https://example.kognitwin.com"
                }
            ]
        )) as table
    meta
    [
        Documentation.Name = "Kognitwin"
    ];

GetLimit =
    (baseUrl as text) as any =>
        let
            config =
                if Uri.Parts(baseUrl)[Host] = "localhost" then
                    GetDataWithIdp(
                        Uri.Parts(baseUrl)[Host]
                        & ":"
                        & port
                        & projectPath
                    )
                else
                    GetDataWithIdp(baseUrl & projectPath),
            limit =
                if config[limit] <> null then
                    config[limit]
                else
                    defaultLimit
        in
            limit;

// Creates a navigation table for selecting asset type
CreateTypesNavTable =
    (baseUrl as text, sourceId as text) =>
        let
            typesTable =
                GetDataTable(
                    baseUrl
                    & assetsPath
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
                                                baseUrl
                                                & assetsPath
                                                & "?source="
                                                & sourceId
                                                & "&type="
                                                & [Column1]
                                                & "&limit="
                                                & Number.ToText(limit),
                                                limit
                                            ),
                                        expandedCols = expandRecordColumn(dataTable, "Column1"),
                                        expandedDerived =
                                            if
                                                List.Contains(
                                                    Table.ColumnNames(expandedCols),
                                                    "derived"
                                                )
                                            then
                                                expandRecordColumn(
                                                    expandedCols,
                                                    "derived",
                                                    "derived."
                                                )
                                            else
                                                expandedCols
                                    in
                                        expandedDerived,
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

PagedTable =
    (url as text, limit as number) =>
        Table.GenerateByPage(
            (previous) =>
                let
                    next =
                        if (previous <> null) then
                            Value.Metadata(previous)[Next]
                        else
                            0,
                    urlToUse =
                        if (next <> 0) then
                            url & "&offset=" & Number.ToText(next)
                        else
                            url,
                    current =
                        if (previous <> null and next = null) then
                            null
                        else
                            GetDataTable(urlToUse),
                    link =
                        if (current <> null) then
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

// Sends a GET request to the specified URL and returns a table with the response
GetDataTable =
    (url as text) =>
        let
            dataList = GetDataWithIdp(url),
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
// The getNextPage function takes a single argument and is expected to return a nullable table
Table.GenerateByPage =
    (getNextPage as function) as table =>
        let
            listOfPages =
                List.Generate(
                    () => getNextPage(null),
                    // get the first page of data
                    (lastPage) => lastPage <> null,
                    // stop when the function returns null
                    (lastPage) => getNextPage(lastPage)
                // pass the previous page to the next function call
                ),
            // concatenate the pages together
            tableOfPages =
                Table.FromList(
                    listOfPages,
                    Splitter.SplitByNothing(),
                    {"Column1"}
                ),
            firstRow = tableOfPages{0}?
        in
            // if we didn't get back any pages of data, return an empty table
            // otherwise set the table type based on the columns of the first page
            if (firstRow = null) then
                Table.FromRows({})
            else
                Value.ReplaceType(
                    Table.ExpandTableColumn(
                        tableOfPages,
                        "Column1",
                        Table.ColumnNames(firstRow[Column1])
                    ),
                    Value.Type(firstRow[Column1])
                );