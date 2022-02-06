[Version = "1.0.0"]    
section Usercube;

[DataSource.Kind="Usercube", Publish="Usercube.Publish"]
shared Usercube.Universes = Value.ReplaceType(UniversesNavTable, UniversesNavTableType);

UniversesNavTableType = type function (
    //serverUrl as Uri.Type)
    serverUrl as (type text meta [
        DataSource.Path = true,
        Documentation.FieldCaption = "Server URL",
        Documentation.FieldDescription = "Usercube server instance URL.",
        Documentation.SampleValues = {"https://mycompany.usercube.com"}
    ]))
    as table meta [
        Documentation.Name = "Usercube",
        Documentation.LongDescription = "Provides data from a Usercube instance",
        Documentation.Examples = {[
            Description = "Returns the universe data defined in the Usercube database.",
            Code = "Usercube.Universes(""https://mycompany.usercube.com"")",
            Result = "Navigation table containing Usercube's universes"
        ]}
    ];


// Data Source Kind description
Usercube = [
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            serverUrl = json[serverUrl]
        in
            { "Usercube.Universes", serverUrl },
    Authentication = [
        // Use the Basic authentication option the store client_id and client_secret
        UsernamePassword = [
            UsernameLabel = "Client Id",
            PasswordLabel = "Client Secret",
            Label = "Client credentials"
        ]
    ]
    // Because the parameter is of type Uri.Type the URL is used as label
    // see note in https://docs.microsoft.com/en-us/power-query/handlingresourcepath#data-source-settings-ui
    // Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
Usercube.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://www.usercube.com/",
    SourceImage = Usercube.Icons,
    SourceTypeImage = Usercube.Icons
];

Usercube.Icons = [
    Icon16 = { Extension.Contents("Usercube16.png"), Extension.Contents("Usercube20.png"), Extension.Contents("Usercube24.png"), Extension.Contents("Usercube32.png") },
    Icon32 = { Extension.Contents("Usercube32.png"), Extension.Contents("Usercube40.png"), Extension.Contents("Usercube48.png"), Extension.Contents("Usercube64.png") }
];

//
// Universes and EntityInstances tree as navigation table
//
UniversesNavTable = (serverUrl as text) =>
    let
        json = UsercubeServerRequest(
            serverUrl,
            "api/Universes/PowerBI/Model",
            [
                #"api-version" = "1.0"
            ]),
        navigationTable = BuildUniversesNavigationTable(json, serverUrl)
    in
      navigationTable;

BuildUniversesNavigationTable = (json as record, serverUrl as text) =>
    let
        table = Table.ExpandRecordColumn(Record.ToTable(json), "Value", {"DisplayName", "TablesByIdentifier"}),
        tableWithTables = Table.RemoveColumns(Table.AddColumn(table, "Items", (row) => BuildTablesNavigationTable(row, serverUrl)), "TablesByIdentifier"),
        navTable = AddNavigationTableColumns(tableWithTables, "Folder", false),
        navTableWithMeta = Table.ToNavigationTable(navTable, {"Name"}, "DisplayName", "Items", "ItemKind", "ItemName", "IsLeaf")
    in
        navTableWithMeta;

BuildTablesNavigationTable = (universeRow as record, serverUrl as text) =>
    let
        table = Table.ExpandRecordColumn(Record.ToTable(universeRow[TablesByIdentifier]), "Value", {"DisplayName", "Columns"}),
        tableWithData = Table.RemoveColumns(Table.AddColumn(table, "Data", (row) => View(row, universeRow[Name], serverUrl)), "Columns"),
        navTable = AddNavigationTableColumns(tableWithData, "Table", true),
        navTableWithMeta = Table.ToNavigationTable(navTable, {"Name"}, "DisplayName", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTableWithMeta;

ColumnTypes = #table(
    {"EnumValue", "Type"}, {
    {1, type text},
    {2, type binary},
    {3, type number},
    {4, Int64.Type},
    {5, type datetime},
    {6, type logical},
    {7, type text},
    {8, type number},
    {9, type number},
    {10, type number}
});

View = (tableDescription as record, universeIdentifier as text, serverUrl as text) as table =>
    let
        View = (state as record) => Table.View(null, [
            GetType = () => GetDataTableType(tableDescription),
            GetRows = () => GetDataAllPages(tableDescription, universeIdentifier, serverUrl, if (Record.HasFields(state, "Top")) then state[Top] else null),
            // OnTake - handles the Table.FirstN transform, limiting
            // the maximum number of rows returned in the result set.
            // The count value should be >= 0.
            OnTake = (count as number) =>
                let
                    newState = state & [ Top = count ]
                in
                    @View(newState)
        ])
    in
        View([]);

GetDataTableType = (tableDescription as record) as type => 
    let
        columns = Table.FromRecords(tableDescription[Columns], {"DisplayName", "Type", "IsPrimaryKey", "IsForeignKey"}, MissingField.UseNull),
        dataColumns = Table.TransformColumns(
            columns,
            {"Type", (t as number) => ColumnTypes{[EnumValue = t]}[Type]}),
        dataColumnsNames = dataColumns[DisplayName],
        dataColumnsTypes = List.Transform(Table.ToRecords(dataColumns), (c) => [Type=c[Type], Optional=false]),
        dataColumnsAsRecord = Record.FromList(dataColumnsTypes, dataColumnsNames),
        dataTableType = type table Type.ForRecord(
            dataColumnsAsRecord,
            false)
    in
        dataTableType;

// Read all pages of data.
// After every page, we check the "ContinuationToken" record on the metadata of the previous request.
// Table.GenerateByPage will keep asking for more pages until we return null.
GetDataAllPages = (tableDescription as record, universeIdentifier as text, serverUrl as text, top as nullable number) as table =>
    let
        columns = Table.FromRecords(tableDescription[Columns], {"DisplayName", "Type", "IsPrimaryKey", "IsForeignKey"}, MissingField.UseNull),
        dataColumns = Table.TransformColumns(
            columns,
            {"Type", (t as number) => ColumnTypes{[EnumValue = t]}[Type]}),
        dataColumnsNames = dataColumns[DisplayName],
        dataColumnsTypes = List.Transform(Table.ToRecords(dataColumns), (c) => [Type=c[Type], Optional=false]),
        dataColumnsAsRecord = Record.FromList(dataColumnsTypes, dataColumnsNames),
        dataTableType = type table Type.ForRecord(
            dataColumnsAsRecord,
            false),
        primaryKeyColumns = Table.SelectRows(dataColumns, each [IsPrimaryKey] = true)[DisplayName],
        foreignKeyColumns = Table.SelectRows(dataColumns, each [IsForeignKey] = true)[DisplayName],
        queryString = (if (top <> null)
            then [PageSize = Text.From(top)]
            else []) & [#"api-version" = "1.0"],
        getPage = (nextPageToken as nullable text) =>
            let
                json = UsercubeServerRequest(
                    serverUrl,
                    "api/Universes/PowerBI/Data/" & universeIdentifier & "/" & tableDescription[Name],
                    if (nextPageToken <> null)
                        then Record.AddField(queryString, "ContinuationToken", nextPageToken)
                        else queryString
                    ),
                list = List.Transform(json[Result], (dataRow) => Record.FromList(dataRow, dataColumnsNames)),
                table = if List.Count(list) = 0
                    then
                        #table(dataColumnsNames, {})
                    else
                        Table.FromRecords(list),
                continuationToken = json[ContinuationToken]?
            in
                table meta [ContinuationToken = continuationToken],
        getNextPage = (previous) => 
            let
                continuationToken = if (previous = null or top <> null) then null else Value.Metadata(previous)[ContinuationToken]?,
                page = if (previous = null or continuationToken <> null) then getPage(continuationToken) else null
            in
                page,
        allData = Table.GenerateByPage(getNextPage),
        typedTable = Table.ChangeType(allData, dataTableType),
        tableWithPrimaryKey = Table.AddKey(typedTable, primaryKeyColumns, true),
        tableWithForeignKeys = List.Accumulate(foreignKeyColumns, tableWithPrimaryKey, (t,c) => Table.AddKey(t, {c}, false))
    in
        tableWithForeignKeys;

//
// Query the Usercube server API
//
UsercubeServerRequest = (serverUrl as text, relativePath as text, query as record, optional token as record) as record =>
    let
        tokenRecord = if token = null then UsercubeServerTokenRequest(serverUrl, false) else token,
        response = Web.Contents(serverUrl, [
            RelativePath = relativePath,
            Query = query,
            // use cache
            IsRetry = false,
            Headers = [
                #"Authorization" = tokenRecord[token_type] & " " & tokenRecord[access_token],
                #"Accept" = "application/json",
                // simulate ajax request so no redirection but 401
                // (https://stackoverflow.com/questions/54556388/identity-server-4-intercept-302-and-replace-it-with-401)
                #"X-Requested-With" = "XMLHttpRequest"
            ],
            // don't use the Basic authentication
            ManualCredentials = true,
            // handle 401 error
            ManualStatusHandling = {401}
        ]),
        json = try Json.Document(response),
        result = if json[HasError] then
                let
                    responseMetadata = Value.Metadata(response),
                    responseStatus = responseMetadata[Response.Status],
                    retryResult = if responseStatus = 401 then
                        let
                            // get a new token
                            newToken = UsercubeServerTokenRequest(serverUrl, true)
                        in
                            UsercubeServerRequest(serverUrl, relativePath, query, newToken)
                    else
                        error "HTTP request " & responseMetadata[Content.Uri]() & " return " & Text.From(responseStatus)
                in
                    retryResult
            else
                json[Value]
    in
        result;

//
// Get an access_token using the client credentials flow
//
// Don't use the cache if force is true
UsercubeServerTokenRequest = (serverUrl as text, force as logical) =>
    let
        client_id = Extension.CurrentCredential()[Username],
        client_secret = Extension.CurrentCredential()[Password],
        Response = Web.Contents(serverUrl, [
            RelativePath = "connect/token",
            Content = Text.ToBinary(Uri.BuildQueryString([
                client_id = client_id,
                client_secret = client_secret,
                grant_type = "client_credentials"
            ])),
            // Specify IsRetry to ignore cache (PowerBI ignore the Cache-Control header returned by the server)
            IsRetry = force,
            // don't use the Basic authentication
            ManualCredentials = true,
            Headers=[#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json"]]),
        responseRecord = Json.Document(Response)
    in
        responseRecord;

//
// Add columns ItemKind, ItemName, IsLeaf to a table
//
AddNavigationTableColumns = (table as table, itemKind as text, isLeaf as logical) =>
    Table.AddColumn(
        Table.AddColumn(
            Table.AddColumn(table, "ItemKind", (row) => itemKind),
            "ItemName",
            (row) => itemKind),
        "IsLeaf",
        (row) => isLeaf);

// 
// Load common library functions
// 
// TEMPORARY WORKAROUND until we're able to reference other M modules
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Table.ChangeType = Extension.LoadFunction("Table.ChangeType.pqm");
Table.GenerateByPage = Extension.LoadFunction("Table.GenerateByPage.pqm");
Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");