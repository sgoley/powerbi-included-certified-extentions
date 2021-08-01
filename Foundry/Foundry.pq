[Version = "1.2.2"]
section Foundry;

DSN_NAME = "FoundrySql";
SQL_SERVER_API_PATH = "/foundry-sql-server/api";
USER_AGENT = "PowerBI";
USER_AGENT_VERSION = "1.2.2";
SQL_DIALECT = "ODBC";

// OAuth
clientId = Text.FromBinary(Extension.Contents("client_id"));
redirectUri = "https://oauth.powerbi.com/views/oauthredirect.html";
// offline_access allows us to use refresh tokens
tokenScope = "foundry-sql-server:query offline_access";

[DataSource.Kind="Foundry", Publish="Foundry.Publish"]
shared Foundry.Contents = Value.ReplaceType(Foundry.Impl, Foundry.Type);

Foundry.Type = type function (
    // Changing the name of this non-optional parameter will cause the existing credentials to be invalid.
    BaseUri as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("BaseUriFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("BaseUriFieldDescription"),
        Documentation.SampleValues = {"https://<color>.palantirfoundry.com/"}
    ]),
    optional datasetRid as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("DatasetFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("DatasetFieldDescription"),
        Documentation.SampleValues = {"ri.foundry.main.dataset.00000000-1111-2222-3333-444444444444"}
    ]),
    optional branch as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("BranchFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("BranchFieldDescription"),
        Documentation.SampleValues = {"master", "develop"}
    ]))
    as table meta [
        Documentation.Name = Extension.LoadString("OptionsTableName"),
        Documentation.LongDescription = Extension.LoadString("OptionsTableLongDescription"),
        Documentation.Examples = {}
    ];


Foundry.Impl = (BaseUri as text, optional datasetRid as text, optional branch as text) =>
    let
        // Force the check driver method to be evaluated
        uri = if Foundry.CheckDriverAvailable() then BaseUri else error "unreachable",
        validBaseUrl = Foundry.SanitizeUri(uri),
        servicePaths = Foundry.GetServicePaths(validBaseUrl),
        token = Foundry.ValidateCredentials(servicePaths[multipass][apiEndpoint]),
        sqlServerApiPath = validBaseUrl & SQL_SERVER_API_PATH,
        compassPath = servicePaths[compass][apiEndpoint],
        navTable = if (branch <> null and datasetRid = null)
            then (error Extension.LoadString("BranchWithMissingDatasetError"))
            else (if datasetRid <> null then Foundry.OdbcSingleDatasetTable(validBaseUrl, token, datasetRid, branch) 
                else Foundry.NestedNavTable(validBaseUrl, sqlServerApiPath, token))
    in
        navTable;

Foundry.CheckDriverAvailable = () =>
    let
        // The OnError handler will catch the driver not found error and rethrow an exception
        res = Odbc.Query([DSN=DSN_NAME,local="true"], "SELECT 1", [
            CredentialConnectionString = [ UID = "", PWD = "" ],
            OnError = Foundry.OnError])
    in
        Table.First(res) <> null;

Foundry.GetServicePaths = (baseUrl as text) =>
    let
        foundryInfo = Foundry.UnauthedWebRequest(baseUrl & SQL_SERVER_API_PATH & "/info"),
        servicePaths = foundryInfo[services]
    in
        servicePaths;

Foundry.ValidateCredentials = (multipassApiPath as text) =>
    let
        credentials = Extension.CurrentCredential(),
        // `Password` is available on both Key authentication and UsernamePassword (so back-compat with original connector)
        token = if Foundry.IsOauth() then credentials[access_token] else credentials[Password],
        ignored = Foundry.UncachedWebRequest(multipassApiPath & "/oauth2/check_token", token),
        // Force evaluation of web request, WebRequest already has appropriate error handling for bad auth vs other errors
        validToken = if ignored <> null then token else error Error.Record("Unreachable", "Authentication Error")
    in
        validToken;

Foundry.NestedNavTable = (baseUrl as text, sqlServerApiPath as text, token as text, optional sourceRid as text) =>
    let
        source = Foundry.CachedWebRequest(sqlServerApiPath & "/powerbi/navigation", token, if sourceRid = null then [] else [parent=sourceRid]),
        children = Table.FromRecords(source[resources]),
        // If no children are returned, there will be no columns, so make sure to add them
        withColumnsRenamed = Table.RenameColumns(children, {{"name", "Name"}, {"isLeaf", "IsLeaf"}}, MissingField.UseNull),

        withData = Table.AddColumn(withColumnsRenamed, "Data",  each if not [IsLeaf]
            then Foundry.NestedNavTable(baseUrl, sqlServerApiPath, token, [rid])
            else Foundry.OdbcSingleDatasetTable(baseUrl, token, [path]), type table),

        withItemKind = Table.AddColumn(withData, "ItemKind", each if [IsLeaf] then "Dataset" else "Folder", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each if [IsLeaf] then "Dataset" else "Folder", type text),
        navTable = Table.ToNavigationTable(withItemName, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
   in
        navTable;

Foundry.OdbcSingleDatasetTable = (baseUrl as text, token as text, datasetPathOrRid as text, optional branch as text) as table =>
    let
        ConnectionString = [
            DSN=DSN_NAME,
            BaseUrl=baseUrl,
            // Restrict the driver to listing a single dataset in metadata calls, to improve performance
            Dataset=datasetPathOrRid,
            Branch= if branch <> null then branch else "",
            UserAgent=USER_AGENT,
            UserAgentVersion=USER_AGENT_VERSION,
            Dialect=SQL_DIALECT
        ],
        odbcFlatNavTable = Foundry.OdbcFlatNavTable(ConnectionString, token),
        // Only a single table should be returned in the nav table, since we restricted to a dataset
        datasetData = Table.First(odbcFlatNavTable)[Data]

    in
        datasetData;

Foundry.OdbcFlatNavTable = (connectionString as record, token as text) =>
    let
        datasourceNavTable = Odbc.DataSource(connectionString, [
            // Driver only needs a token, not a username
		    CredentialConnectionString = [ UID = "", PWD = token ],
            CreateNavigationProperties = false,
            ClientConnectionPooling = true,
            // We don't fetch catalogs or schemas, so not hierarchical
            HierarchicalNavigation = false,
            // Allows upconversion of numeric types
            SoftNumbers = true,
            // Allow upconversion / resizing of numeric and string types
            TolerateConcatOverflow = true,
            // Handle driver not installed error ourselves
            OnError = Foundry.OnError,
            SqlCapabilities = [
                LimitClauseKind = LimitClauseKind.Limit,
                Sql92Conformance = 8,
                // Set in driver
                // GroupByCapabilities = 2 /* SQL_GB_GROUP_BY_CONTAINS_SELECT */,
                SupportsNumericLiterals = true,
                SupportsStringLiterals = true,
                SupportsOdbcDateLiterals = true,
                SupportsOdbcTimeLiterals = true,
                SupportsOdbcTimestampLiterals = true
            ],
            SQLGetFunctions = [
                // Disable using parameters in the queries that get generated.
                // We enable numeric and string literals which should enable literals for all constants.
                SQL_API_SQLBINDPARAMETER = false
            ],
            // Use the SQLGetInfo record to override values returned by the driver.
            SQLGetInfo = [
                // Disable catalog and schema loading, since we only request a single table
                SQL_CATALOG_USAGE = 0,
                SQL_SCHEMA_USAGE = 0
            ]
        ])
    in
        datasourceNavTable;

Foundry.OnError = (errorRecord as record) =>
    let
        OdbcError = errorRecord[Detail][OdbcErrors]{0},
        OdbcErrorMessage = OdbcError[Message],
        HasDriverNotFoundError = Text.Contains(errorRecord[Message], "IM002")
    in
        if HasDriverNotFoundError then
            error Extension.LoadString("DriverNotInstalledError")
        else
            error errorRecord;

Foundry.CachedWebRequest = (url as text, token as text, bodyParameters as record) =>
    let
        settings = [ Headers = [ #"Content-Type"="application/json" ], Content = Json.FromValue(bodyParameters) ],
        response = Foundry.AuthedWebRequest(url, token, settings)
    in
        response;

Foundry.UncachedWebRequest = (url as text, token as text) =>
    let
        // Add a random number header to prevent header-based caching
        settings = [Headers = [ RandomKey = Number.ToText(Number.Random()) ]],
        response = Foundry.AuthedWebRequest(url, token, settings)
    in
        response;

Foundry.AuthedWebRequest = (url as text, token as text, settings as record) =>
    let
        // If using an API token, we manually specify the auth header as we need to add "Bearer" to it
        // If using OAuth, we set ManualCredentials=false to let powerbi handle the auth header (in this case it adds the "Bearer"),
        // and to perform token refreshes
        manualCredentials = not Foundry.IsOauth(),
        headers = settings[Headers] & (if manualCredentials then [ Authorization = "Bearer " & token] else []),
        settingsWithAuth = settings & [ Headers = headers, ManualCredentials = manualCredentials], 
        response = Json.Document(Web.Contents(url, settingsWithAuth)) 
    in
        response;

Foundry.UnauthedWebRequest = (url as text) => Json.Document(Web.Contents(url, [ ManualCredentials = true ]));

// Note that calling this method when the credentials have not been set may throw an exception
Foundry.IsOauth = () => Record.HasFields(Extension.CurrentCredential(), "access_token");

Foundry.GetBaseUri = (resourceUrl) => Json.Document(resourceUrl)[BaseUri];

Foundry.SanitizeUri = (uri) => Text.TrimEnd(if Text.StartsWith(uri, "https://") then uri else "https://" & uri, {"/"});

Foundry.MultipassUri = (uri as text) =>
    let
        validBaseUrl = Foundry.SanitizeUri(uri),
        servicePaths = Foundry.GetServicePaths(validBaseUrl)
    in
        servicePaths[multipass][apiEndpoint] as text;

Foundry.DecrementTokenExpiry = (tokenInfo as record) => 
    let
        expiryTime = tokenInfo[expires_in],
        newExpiryTime = if expiryTime >= 600 then (expiryTime - 300) else expiryTime
    in
        tokenInfo & [expires_in = newExpiryTime];

Foundry.StartLogin = (resourceUrl, state, display) =>
    let
        baseUri = Foundry.GetBaseUri(resourceUrl),
        codeVerifier = Text.NewGuid() & Text.NewGuid(),
        codeChallenge = Text.Base64UrlEncodeWithoutPadding(Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(codeVerifier, TextEncoding.Ascii))),
        authorizeUrl = Foundry.MultipassUri(baseUri) & "/oauth2/authorize?" & Uri.BuildQueryString([
            client_id = clientId,
            scope = tokenScope,
            state = state,
            code_challenge_method = "S256",
            code_challenge = codeChallenge,
            redirect_uri = redirectUri,
            response_type = "code"])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirectUri,
            WindowHeight = 720,
            WindowWidth = 1024,
            Context = [BaseUri = baseUri, CodeVerifier = codeVerifier]
        ];

Foundry.Refresh = (resourceUrl, refreshToken) =>
    let
        baseUri = Foundry.GetBaseUri(resourceUrl),
        tokenQueryArgs = [
            client_id = clientId,
            grant_type="refresh_token", 
            refresh_token=refreshToken 
        ]
    in
        Foundry.TokenMethod(baseUri, tokenQueryArgs);

Foundry.FinishLogin = (context, callbackUri, state) =>
    let
        parts = Uri.Parts(callbackUri)[Query],
        tokenQueryArgs = [
            client_id = clientId,
            grant_type="authorization_code", 
            code_verifier=context[CodeVerifier], 
            code=parts[code], 
            redirect_uri = redirectUri
        ]
    in
        Foundry.TokenMethod(context[BaseUri], tokenQueryArgs);

Foundry.TokenMethod = (baseUri as text, queryArgs as record) =>
    let
        response = Web.Contents(Foundry.MultipassUri(baseUri) & "/oauth2/token", [
            Content = Text.ToBinary(Uri.BuildQueryString(queryArgs)),
            Headers=[ #"Content-type" = "application/x-www-form-urlencoded", Accept = "application/json" ]]),
        parts = Json.Document(response),
        // Reduce the token expiry slightly so we don't pass a token that is about to expire to the driver
        // as PowerBI will handle refreshing it earlier
        withReducedTokenExpiry = Foundry.DecrementTokenExpiry(parts)
    in
        withReducedTokenExpiry;

Foundry.Logout = (clientApplication, resourceUrl, accessToken) =>
    let
        baseUri = Foundry.GetBaseUri(resourceUrl),
        multipassUri = Foundry.MultipassUri(baseUri),
        response = try Json.Document(Web.Contents(multipassUri & "/oauth2/revoke_token", [
            Content = Text.ToBinary(Uri.BuildQueryString([token=accessToken])),
            Headers = [ #"Content-type" = "application/x-www-form-urlencoded", Accept = "application/json" ]])),
        // Force revoke request to be evaluated
        logoutUri = if response[HasError] then (multipassUri & "/logout") else (multipassUri & "/logout")
    in
        // Log out of the embedded browser session, Powerbi will make a request to this URL
        logoutUri;

Foundry = [
    Authentication = [
        OAuth = [
             StartLogin = Foundry.StartLogin,
             FinishLogin = Foundry.FinishLogin,
             Refresh = Foundry.Refresh,
             Logout = Foundry.Logout,
             Label = Extension.LoadString("OAuthAuthenticationName")
         ],
        Key = [
            Label=Extension.LoadString("KeyAuthenticationName"),
            KeyLabel=Extension.LoadString("KeyAuthenticationKeyLabel")
         ]
    ],
    TestConnection = (dataSourcePath) =>
        let
          baseUri = Foundry.GetBaseUri(dataSourcePath)
        in
          { "Foundry.Contents", baseUri },
    Label = Extension.LoadString("AuthenticationWindowTitle")
];

Foundry.Publish = [
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://www.palantir.com/palantir-foundry/",
    SourceImage = Foundry.Icons,
    SourceTypeImage = Foundry.Icons,
    SupportsDirectQuery = true
];

Foundry.Icons = [
    Icon16 = { Extension.Contents("Foundry16.png"), Extension.Contents("Foundry20.png"), Extension.Contents("Foundry24.png"), Extension.Contents("Foundry32.png") },
    Icon32 = { Extension.Contents("Foundry32.png"), Extension.Contents("Foundry40.png"), Extension.Contents("Foundry48.png"), Extension.Contents("Foundry64.png") }
];

Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text) as table =>
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

Text.Base64UrlEncodeWithoutPadding = (hash as binary) as text =>
    let
        base64Encoded = Binary.ToText(hash, BinaryEncoding.Base64),
        base64UrlEncoded = Text.Replace(Text.Replace(base64Encoded, "+", "-"), "/", "_"),
        withoutPadding = Text.TrimEnd(base64UrlEncoded, "=")
    in 
        withoutPadding;

Value.IfNull = (a, b) => if a <> null then a else b;
