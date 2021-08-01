[Version = "1.0.0"]
section Cherwell;

[DataSource.Kind="Cherwell", Publish="Cherwell.Publish"]
shared Cherwell.SavedSearches = Value.ReplaceType(SavedSearches, SavedSearchesType);

Cherwell = [
    TestConnection = (dataSourcePath) =>
        let
            data = Json.Document(dataSourcePath)
        in
            {"Cherwell.SavedSearches", data[API URL], data[Client ID]},
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh
        ]
    ]
];

Cherwell.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = {
        Extension.LoadString("ButtonTitle"),
        Extension.LoadString("ButtonHelp")
    },
    LearnMoreUrl = "http://help.cherwell.com",
    SourceImage = Cherwell.Icons,
    SourceTypeImage = Cherwell.Icons
];

Cherwell.Icons = [
    Icon16 = {
        Extension.Contents("CherwellIcon16.png"),
        Extension.Contents("CherwellIcon20.png"),
        Extension.Contents("CherwellIcon24.png"),
        Extension.Contents("CherwellIcon32.png")
    },
    Icon32 = {
        Extension.Contents("CherwellIcon32.png"),
        Extension.Contents("CherwellIcon40.png"),
        Extension.Contents("CherwellIcon48.png"),
        Extension.Contents("CherwellIcon64.png")
    }
];



/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// API REQUEST FUNCTIONS
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

SavedSearchesType = type function (
    #"API URL" as (type text meta [
        Documentation.FieldDescription = Extension.LoadString("ApiUrlFieldDescription"),
        Documentation.SampleValues = {"https://myserver/CherwellAPI/api/"}
    ]),
    #"Client ID" as (type text meta [
        Documentation.FieldDescription = Extension.LoadString("ClientIdFieldDescription"),
        Documentation.SampleValues = null
    ]),
    optional Locale as (type text meta [
        Documentation.FieldDescription = Extension.LoadString("LocaleFieldDescription"),
        Documentation.SampleValues = {"de-DE"}
    ]),
    optional #"Saved Search URL" as (type text meta [
        Documentation.FieldDescription = Extension.LoadString("SavedSearchUrlFieldDescription"),
        Documentation.SampleValues = null
    ]))
    as table meta [
        Documentation.Name = Extension.LoadString("DataSourceDialogTitle"),
        Documentation.LongDescription = Extension.LoadString("DataSourceFunctionDescription")
    ];

SavedSearches = (
    apiUrl as text,
    clientId as text,
    optional locale as text,
    optional savedSearchUrl as text
) as any => GetData(apiUrl, clientId, locale, savedSearchUrl);

// Retrieves data from the Cherwell API
// This is "shared" for testing purposes and dataSource provides mechanism for mocking server responses
//
// Returns either a (navigation) table or a raw list or record, depending on data source parameters
/*shared*/GetData = (
    apiUrl as text,
    clientId as text,
    optional locale as text,
    optional savedSearchUrl as text,
    optional dataSource as function
) as any =>
    let
        context = BuildContext(ValidateUrl(apiUrl), locale, dataSource)
    in
        if savedSearchUrl = null or Text.Trim(savedSearchUrl) = "" then
            GetSupportedAssocationsNavTable(context)
        else
            GetSavedSearch(context, ValidateUrl(savedSearchUrl));

// Builds a contextual object that provides configuration values and encapsulation for sending API requests
// and parsing API responses
// dataSource provides mechanism for mocking server responses
//
// Returns contextual object for all API requests
BuildContext = (apiUrl as text, optional locale as text, optional dataSource as function) as record =>
    [
        ApiUrl = Text.TrimEnd(apiUrl, "/") & "/",
        Locale = locale,
        GetQueryParams = () =>
            if locale <> null then
                "?" & Uri.BuildQueryString([locale = locale])
            else
                "",
        RequestJsonContent = (endpoint as text, optional options as nullable record) =>
            let
                json = Web.Contents(endpoint, options)
            in
                Json.Document(json), // returns either list or record
        RequestDataAbsolute = (url as text, optional options as nullable record) =>
            let
                dataFunc =
                    if dataSource <> null then
                        dataSource
                    else
                        RequestJsonContent
            in
                dataFunc(url, options),
        RequestData = (relUrl as text, optional options as nullable record) =>
            let
                url = Uri.Combine(ApiUrl, relUrl) & GetQueryParams()
            in
                RequestDataAbsolute(url, options)
    ];
        
// Retrieves data for an explicit API (GET) request
// Provides backwards-compatibility for Saved Search URLs copied from CSM Admin
//
// Returns unformatted list or record
GetSavedSearch = (context as record, url as text) =>
    context[RequestDataAbsolute](url);

// Queries API for all available Business Object associations for the top-level navigation table
GetSupportedAssocationsNavTable = (context as record) as table =>
    let
        data = context[RequestData]("V2/getsearchitems"),
        #"Converted to Table" = Table.FromRecords(data[supportedAssociations], SupportedAssociation),
        #"Renamed Columns" = Table.RenameColumns(#"Converted to Table", {"valueObject", "busObId"}),
        defaultAssociation = data[root][association],
        #"Applied nav-table columns" = ApplyNavTableColumns(#"Renamed Columns", "Cube", each false,
            each
                // the previous request contains a search item tree for the default business object
                // so this can be used for one business object without needing another API request
                if [busObId] = defaultAssociation then
                    FormatItemsByAssociationNavTable(context, [busObId], data[root][childFolders])
                        meta [isDefaultBusOb = true]
                else
                    GetItemsByAssociationNavTable(context, [busObId])
            ),
        navTable = Table.ToNavigationTable(#"Applied nav-table columns", {"busObId"},
            "name", "data", "itemKind", "itemName", "isLeaf")
    in
        navTable meta Value.Metadata(data);

// Queries API for all Saved Searches for a particular Business Object and formats the response as nested
// navigation tables
GetItemsByAssociationNavTable = (context as record, associationId as text) as table =>
    let
        data = context[RequestData]("V2/getsearchitems/association/" & associationId),
        folderTree = data[root][childFolders],
        navTable = FormatItemsByAssociationNavTable(context, associationId, folderTree)
    in
        navTable meta Value.Metadata(data);

// Processes Saved Searches for a particular Business Object into nested navigation tables, starting with
// scope folders
FormatItemsByAssociationNavTable = (context as record, associationId as text, folderTree as list) as table =>
    let
        #"Converted to Table" = Table.FromRecords(folderTree, ScopeFolder),
        #"Removed empty folders" = RemoveEmptyFolders(#"Converted to Table"),
        #"Applied nav-table columns" = ApplyNavTableColumns(#"Removed empty folders", "Folder", each false,
            each FormatItemsByFolderNavTable(context, associationId, [childFolders], [childItems])),
        #"Renamed Columns" = Table.RenameColumns(#"Applied nav-table columns", {"name", "scopeName"}),
        #"Removed child columns" = Table.RemoveColumns(#"Renamed Columns", {"childFolders", "childItems"}),
        navTable = Table.ToNavigationTable(#"Removed child columns", {"scopeName"}, "scopeName", "data", "itemKind",
            "itemName", "isLeaf")
    in
        navTable;

// Processes Saved Searches and folders, recursively, into nested navigation tables
FormatItemsByFolderNavTable = (context as record, associationId as text, folders as list, items as list) as table =>
    let
        #"Converted folders to Table" = Table.FromRecords(folders, SearchFolder),
        #"Removed empty folders" = RemoveEmptyFolders(#"Converted folders to Table"),
        #"Applied nav-table columns to folders" = ApplyNavTableColumns(#"Removed empty folders", "Folder", each false,
            each @FormatItemsByFolderNavTable(context, associationId, [childFolders], [childItems])),
        #"Removed child columns from folders" = Table.RemoveColumns(#"Applied nav-table columns to folders",
            {"childFolders", "childItems"}),
        #"Converted items to Table" = Table.FromRecords(items, SearchItem),
        #"Applied nav-table columns to items" = ApplyNavTableColumns(#"Converted items to Table", "View", each false,
            each GetGridsForBusOb(context, associationId, [scope], [id], [displayName])),
        #"Renamed displayName Column" = Table.RenameColumns(#"Applied nav-table columns to items",
            {"displayName", "name"}),
        #"Removed scope column from items" = Table.RemoveColumns(#"Renamed displayName Column", {"scope"}),
        navTable = Table.ToNavigationTable(#"Removed child columns from folders" & #"Removed scope column from items",
            {"id"}, "name", "data", "itemKind", "itemName", "isLeaf")
    in
        navTable;

// Queries API for all grids available for a particular Business Object and formats these as leaf nodes for
// a navigation table
GetGridsForBusOb = (context as record, associationId as text, scope as text, searchId as text, searchName as text) as table =>
    let
        data = context[RequestData]("V1/getbusinessobjectschema/busobid/" & associationId),
        #"Converted to Table" = Table.FromRecords(data[gridDefinitions], GridDefinition),
        #"Added formatted name column" = Table.AddColumn(#"Converted to Table", "name",
            each searchName & " (" & [displayName] & ")", type text),
        #"Added default grid row" = #table(type table [name = text, gridId = text], {{searchName, null}})
            & #"Added formatted name column",
        #"Applied nav-table columns to items" = ApplyNavTableColumns(#"Added default grid row", "Table", each true,
            each GetSearchResultsTable(context & [GridId = [gridId]], associationId, searchId, scope)),
        #"Removed displayName column" = Table.RemoveColumns(#"Applied nav-table columns to items", "displayName"),
        navTable = Table.ToNavigationTable(#"Removed displayName column", {"gridId"}, "name", "data", "itemKind",
            "itemName", "isLeaf")
    in
        navTable meta Value.Metadata(data);

// Formats a table to be usable as a navigation table by adding necessary columns
ApplyNavTableColumns = (table as table, itemKind as text, getIsLeaf as function, getData as function) as table =>
   let
        #"Added itemKind column" = Table.AddColumn(table, "itemKind", each itemKind, Text.Type),
        #"Added itemName column" = Table.AddColumn(#"Added itemKind column", "itemName", each [itemKind], Text.Type),
        #"Added isLeaf column" = Table.AddColumn(#"Added itemName column", "isLeaf", each getIsLeaf(_), Logical.Type),
        #"Added data column" = Table.AddColumn(#"Added isLeaf column", "data", each getData(_), Table.Type),
        filledTable = #"Added data column"
    in
        filledTable;

// Queries API for a particular Saved Search (and optional grid) and formats the response based on the
// received schema
GetSearchResultsTable = (context as record, associationId as text, searchId as text, scope as text) as table =>
    let
        body = [
            associationId = associationId,
            searchId = searchId,
            scope = scope,
            includeSchema = true
        ],
        customGridBody = 
           if context[GridId]? <> null then
                [gridId = context[GridId]]
           else
                [],
        options = [
            Headers = [#"Content-Type"="application/json"],
            Content = Json.FromValue(body & customGridBody)
        ],
        data = context[RequestData]("V2/storedsearches", options),
        columns = Table.FromRecords(data[columns], ColumnSchema),
        rows = data[rows],
        fieldNames = Table.Column(columns, "name"),
        fieldNamesTypes = Table.TransformRows(columns, each {[name], GetSourceTypeFromFieldInfo([type])}),
        GetFilteredTransformation = each
            let
                transform = GetColumnTransformation([type], context[Locale])
            in
                if transform <> null then {[name], transform} else null,
        columnTransformations = List.RemoveNulls(List.Transform(Table.ToRecords(columns), GetFilteredTransformation)),
        #"Converted to Table" = Table.FromRows(rows, fieldNames),
        #"Applied column typing" = Table.TransformColumnTypes(#"Converted to Table", fieldNamesTypes, context[Locale]),
        #"Applied column formatting" = Table.TransformColumns(#"Applied column typing", columnTransformations)
    in
        #"Applied column formatting" meta Value.Metadata(data);

// Filters rows from a table when neither a row nor its descendants contain childItem records
RemoveEmptyFolders = (table as table) as table => Table.SelectRows(table, DoesFolderContainItems);

// Determines whether a folder record or its descendant childFolders contain childItem records
DoesFolderContainItems = (folder as record) as logical =>
    List.Count(folder[childItems]) > 0 or List.AnyTrue(List.Transform(folder[childFolders], @DoesFolderContainItems));

// Maps a CSM column type to a Power Query data type
GetSourceTypeFromFieldInfo = (fieldType as text) as type =>
    if (fieldType = "logical") then type logical
    else if (fieldType = "number") then type number
    else if (fieldType = "currency") then Currency.Type
    else if (fieldType = "integer") then Int64.Type
    else if (fieldType = "datetime") then type datetime
    else if (fieldType = "date") then type datetime
    else if (fieldType = "time") then type datetime
    else type text;
    
// Provides a transformation function (or null) for converting values based on ascribed CSM column type
// to values compatible with equivalent Power Query data types
// (Date and time values are returned from the Cherwell API as full date/time values)
GetColumnTransformation = (fieldType as text, locale as nullable text) as nullable function =>
    if (fieldType = "date") then
        (value as datetime) as date => Date.From(value, locale)
    else if (fieldType = "time") then
        (value as datetime) as time => Time.From(value, locale)
    else
        null;



/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// CUSTOM TYPES
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

SupportedAssociation = type table [
    name = text,
    valueObject = text
];

ScopeFolder = type table [
    name = text,
    childFolders = {SearchFolder},
    childItems = {SearchItem}
];

SearchFolder = type table [
    name = text,
    id = text,
    childFolders = {SearchFolder},
    childItems = {SearchItem}
];

SearchItem = type table [
    displayName = text,
    id = text,
    scope = text
];

GridDefinition = type table [
    gridId = text,
    displayName = text
];

ColumnSchema = type table [
    name = text,
    type = text
];

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// OAUTH LIFE CYCLE HOOKS
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

redirectUri = "https://oauth.powerbi.com/views/oauthredirect.html";

// This is "shared" for testing purposes
/*shared*/StartLogin = (dataSourcePath, state, display) =>
    let
        context = GetRequestContext(dataSourcePath),
        authorizeUrl = context[authEndpointUrl] & "?" & Uri.BuildQueryString([
            client_id = context[clientId],
            scope = "user",
            state = state,
            redirect_uri = redirectUri,
            response_type = "code"
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirectUri,
            WindowHeight = 700,
            WindowWidth = 680,
            Context = context
        ];

FinishLogin = (context, callbackUri, state) =>
    let 
        callbackUri = Text.Replace(callbackUri, "#", "?"),
        queryParts = Uri.Parts(callbackUri)[Query],
        tokenField = "code",
        tokenValue = queryParts[code],
        clientId = context[clientId],
        result = Auth.RequestToken("authorization_code", tokenField, tokenValue, context[tokenEndpointUrl], clientId)
    in
        [
            access_token = result[access_token],
            refresh_token = result[refresh_token],
            token_type = result[token_type],
            expires_in = result[expires_in],
            state = queryParts[state]
        ];

Refresh = (dataSourcePath, refreshToken) =>
    let
        context = GetRequestContext(dataSourcePath),
        tokenField = "refresh_token"
    in
        Auth.RequestToken("refresh_token", tokenField, refreshToken, context[tokenEndpointUrl], context[clientId]);

// Simplifies the passing of essential information derived from the given resourceUrl which 
// is configurated during the set up of the connector
//
// dataSourcePath: Derived from the oauth lifecycle events as a record defining a field 
//                 for each of the arguments passed into the connector at runtime.  Each of which
//                 originate from the set up of the data connector configuration.
//
// Returns a record defining the following fields related to the context related to the 
// resource being queried:
//
// clientId:            The Cherwell API clientId.
// authEndpointUrl:     Convenience fully qualified url constructed from the resource url to the CherwellAPI 
//                      auth endpoint.
// tokenEndpointUrl:    Convenience fully qualified url constructed from the resource url to the CherwellAPI
//                      token endpoint.
// locale:              Culture code if provided in configuration.
GetRequestContext = (dataSourcePath as text) as record =>
    let
        jsonInput = Json.Document(dataSourcePath),
        apiUrl = Text.TrimEnd(jsonInput[API URL], "/"),
        clientId = jsonInput[Client ID],
        baseUrl =
            if Text.EndsWith(apiUrl, "/api", Comparer.OrdinalIgnoreCase) then
                Text.RemoveRange(apiUrl, Text.Length(apiUrl) - 4, 4)
            else
                apiUrl,
        authEndpointUrl = baseUrl & "/auth/authorize",
        tokenEndpointUrl = baseUrl & "/token"
    in
        [
            clientId = clientId,
            authEndpointUrl = authEndpointUrl,
            tokenEndpointUrl = tokenEndpointUrl
        ];

ValidateUrl = (url as text) as text =>
    let
        checkUrl = try Uri.ValidateUrlScheme(url),
        validUrl =
            if checkUrl[HasError] then
                error "URL " & url & " is invalid: " & checkUrl[Error][Message]
            else
                checkUrl[Value]
    in
        validUrl;



/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// EXTERNAL FUNCTIONS
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared & [redirectUri = redirectUri]);

Auth.RequestToken = Extension.LoadFunction("Auth.RequestToken.pqm");
Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");
Uri.ValidateUrlScheme = Extension.LoadFunction("Uri.ValidateUrlScheme.pqm");
