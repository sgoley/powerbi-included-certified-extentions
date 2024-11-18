[Version = "5.3.0"]
section StarburstPresto;

//Indicates the level of SQL-92 supported by the driver.
Config_SqlConformance = 8;

// Set to null to leave default behavior.
Config_UsePositionInsteadOfLocate = true; // true, false, null

// OAuth constants
OAuthPath = "/oauth2${PUBLIC_REFERENCE}/public-client";
RedirectUri = "https://oauth.powerbi.com/views/oauthredirect.html";

// Data Source Kind description.
StarburstPresto = [
    SupportsEncryption = true,
    Authentication = [
        Implicit = [],
        UsernamePassword = [
            Label = "LDAP"
        ],
        Windows = [
            Label = "Kerberos"
        ],
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh,
            Logout = Logout,
            Label = "OAuth"
        ],
        Key = [
            Label = "Personal Access Token (JWT)",
            KeyLabel = "Personal Access Token (JWT)"
        ]
    ],

    // Needed for use with Power BI Service.
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            Host = json[Host],
            Port = json[Port]
        in
            { "StarburstPresto.Contents", Host, Port }
];

// Shared method that can be used in Power Query 
[DataSource.Kind="StarburstPresto", Publish="StarburstPresto.Publish"]
shared StarburstPresto.Contents = Value.ReplaceType(StarburstPrestoImpl, StarburstPrestoType);

// Data Source UI publishing description.
StarburstPresto.Publish = [
    Beta = false,
    Category = "Other",
    SupportsDirectQuery = true,

    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://www.starburst.io/",

    SourceImage = StarburstPresto.Icons,
    SourceTypeImage = StarburstPresto.Icons,

    // Native query support
    NativeQueryProperties =
    [
        navigationSteps = {
            [
                indices = {
                    [
                        value = "Catalog",
                        indexName = "Name"
                    ],
                    [
                        displayName = "Database",
                        indexName = "Kind"
                    ]
                },
                access = "NativeData"
            ]
        },
   
        nativeQueryOptions = [
            EnableFolding = true
        ]
    ]
];

StarburstPresto.Icons = [
    Icon16 = { Extension.Contents("StarburstEnterprise16.png"), Extension.Contents("StarburstEnterprise20.png"), Extension.Contents("StarburstEnterprise24.png"), Extension.Contents("StarburstEnterprise32.png") },
    Icon32 = { Extension.Contents("StarburstEnterprise32.png"), Extension.Contents("StarburstEnterprise40.png"), Extension.Contents("StarburstEnterprise48.png"), Extension.Contents("StarburstEnterprise64.png") }
];

// Wrapper function that provides additional UI customization.
StarburstPrestoType = type function (
        Host as (type text meta [
            Documentation.FieldCaption = "Host",
            Documentation.FieldDescription = "The hostname of the Starburst Enterprise server.",
            Documentation.SampleValues = { "starburst.example.com" }
        ]),
        Port as (type number meta [
            Documentation.FieldCaption = "Port",
            Documentation.FieldDescription = "The port the server is running on.",
            Documentation.SampleValues = { 8080 }
        ]),
        optional options as (type [
            optional Role = (type text meta [
                Documentation.FieldCaption = "Role",
                Documentation.FieldDescription = "Enter the system role.",
                Documentation.SampleValues = { "public" },
                Documentation.DefaultValue = ""
            ]),
            optional Catalog = (type text meta [
                Documentation.FieldCaption = "Catalog",
                Documentation.FieldDescription = "Enter the specific catalog name to load the catalog data, if not will load all catalogs.",
                Documentation.SampleValues = { "tpch" },
                Documentation.DefaultValue = ""
            ]),
            optional UseSystemProxy = (type text meta [
                Documentation.FieldCaption = "Use system proxy",
                Documentation.FieldDescription = "When enabled, system proxy settings (if defined) will be used.",
                Documentation.AllowedValues = { "No (default)", "Yes" }
            ]),
            optional ExtraConnectionString = (type text meta [
                Documentation.FieldCaption = "Connection string (non-credential properties)",
                Documentation.FieldDescription = "For non-credential properties only. Use the credential dialog box to provide security-related properties, such as Username and Password.",
                Documentation.SampleValues = { "AllowSelfSignedServerCert=1;Min_TLS=1.2" },
                Documentation.DefaultValue = ""
             ])
        ] meta [
            Documentation.FieldCaption = "Advanced options"
        ])
    )
    as table meta [
        Documentation.Name = "Starburst Enterprise"
    ];

// Implementation
StarburstPrestoImpl = (Host as text, Port as number, optional options as record) as table =>
    let
        Credential = Extension.CurrentCredential(),
        AuthenticationMode = Credential[AuthenticationKind],

        // Sets connection string properties for authentication.
        CredentialConnectionString = (
            if AuthenticationMode = "UsernamePassword" then
                [
                    AuthenticationType = "LDAP Authentication",
                    UID = Credential[Username],
                    PWD = Credential[Password]
                ]
            else if AuthenticationMode = "Windows" then
                [
                    AuthenticationType = "Kerberos Authentication",
                    UseGSSAPI = 0,
                    UseOnlySSPI = 1
                ]
            else if AuthenticationMode = "OAuth" then
                [
                    AuthenticationType = "JWT Authentication",
                    AccessToken = Credential[access_token]
                ]
            else if AuthenticationMode = "Key" then
                [
                    AuthenticationType = "JWT Authentication",
                    AccessToken = Credential[Key]
                ]
            else // "else" required; AuthenticationMode will always be "Implicit" at this point.
                [
                    AuthenticationType = "No Authentication"
                ]
        ) & (
            // encrypted connections
            if Credential[EncryptConnection] = null or Credential[EncryptConnection] = true then
                [
                    SSL = 1,
                    UseSystemTrustStore = 1
                ]
            else
                [
                    SSL = 0
                ]
        ),

        // User input options without extra connection string
        ValidatedOptions = if options <> null then options else [],

        // Catalog property
        // Specifying catalog will disable AllowMetadataFromMultipleCatalogs, or enable it otherwise
        CatalogProperty = 
            if Record.HasFields(ValidatedOptions, "Catalog") 
                    and ValidatedOptions[Catalog] <> null
                    and Text.Length(Text.Trim(ValidatedOptions[Catalog])) > 0 then
                [
                    Catalog = ValidatedOptions[Catalog],
                    AllowMetadataFromMultipleCatalogs = 0
                ]
            else
                [
                    // Catalog undefined
                ],

        // Use system proxy
        SystemProxyProperties = 
            if Record.HasFields(ValidatedOptions, "UseSystemProxy") 
                    and ValidatedOptions[UseSystemProxy] = "Yes" 
                    and Record.FieldCount(Web.DefaultProxy(Host)) > 0 then
                let
                    ProxyUri = Uri.Parts(Web.DefaultProxy(Host)[ProxyUri])
                in
                    [
                        UseProxy = 1,
                        ProxyHost = ProxyUri[Host],
                        ProxyPort = ProxyUri[Port]
                    ]
            else 
                [],

        // Extract name-value pairs from ExtraConnectionString
        ExtraConnectionStringProperties = 
            if Record.HasFields(ValidatedOptions, "ExtraConnectionString") 
                    and ValidatedOptions[ExtraConnectionString] <> null 
                    and Text.Length(Text.Trim(ValidatedOptions[ExtraConnectionString])) > 0 then
                ValidateConnectionStringProperties(ParseConnectionString(Text.Trim(ValidatedOptions[ExtraConnectionString])))
            else 
                [
                    // ExtraConnectionString undefined
                ],

        // Deep merge Roles property defined in Role and ExtraConnectionString inputs
        CatalogRolePairs = MergeConnectionProperties(
            if Record.HasFields(ExtraConnectionStringProperties, "Roles") then 
                ParseConnectionString(ExtraConnectionStringProperties[Roles]) 
            else 
                [
                    // Roles property is not defined in ExtraConnectionString input
                ],

            if Record.HasFields(ValidatedOptions, "Role") 
                    and ValidatedOptions[Role] <> null 
                    and Text.Length(Text.Trim(ValidatedOptions[Role])) > 0 then
                [
                    // System role is defined in Role intput
                    system = Text.Trim(ValidatedOptions[Role])
                ]
            else
                [
                    // Role input is empty
                ]
        ),

        RolesProperty = 
            if Record.FieldCount(CatalogRolePairs) > 0 then
                [
                    Roles = FormatConnectionString(CatalogRolePairs)
                ]
            else 
                [
                    // empty
                ],
            
        ConnectionString = 
            MergeConnectionProperties(
                MergeConnectionProperties(
                    // Defaults 
                    [
                        AllowHostNameCNMismatch = 1,
                        AllowSelfSignedServerCert = 1,
                        ApplicationName = "Power BI Extension 5.3.0",
                        RemoveTypeNameParameters = 1
                    ], 
                    // ExtraConnectionString
                    ExtraConnectionStringProperties
                ),
                // Explicit settings
                [
                    Driver = "Starburst ODBC Driver",
                    // For Galaxy, host is in host/public-reference format if Power BI OAuth client is defined
                    Host = Text.Split(Host, "/"){0},
                    Port = Port
                ] 
                & RolesProperty
                & CatalogProperty
                & SystemProxyProperties
            ),

        DefaultOptions = BuildOdbcOptions(),

        SqlCapabilities = DefaultOptions[SqlCapabilities] & [
            FractionalSecondsScale = 3,
            Sql92Translation = "PassThrough"
        ],

        SQLGetInfo = DefaultOptions[SQLGetInfo] & [
            SQL_SQL92_PREDICATES = ODBC[SQL_SP][All],
            SQL_AGGREGATE_FUNCTIONS = ODBC[SQL_AF][All]
        ],

        // SQLColumns should match SQLGetTypeInfo
        SQLColumns = (catalogName, schemaName, tableName, columnName, source) =>
            // Old Starburst ODBC (< 2.0.15) returns data type declaration instead of pure data type, 
            // e.g. varchar(20) vs. varchar - fix them here
            let
                FixTypeName  = (typeName) =>
                    if Text.StartsWith(typeName, "array") then
                        "array"
                    else if Text.StartsWith(typeName, "row") then
                        "row"
                    else if Text.StartsWith(typeName, "json") then
                        "json"
                    else if Text.StartsWith(typeName, "map") then
                        "map"
                    else if Text.StartsWith(typeName, "varchar") then
                        "varchar"
                    else if Text.StartsWith(typeName, "char") then
                        "char"
                    else if Text.StartsWith(typeName, "decimal") then
                        "decimal"
                    else if Text.StartsWith(typeName, "timestamp") and Text.Contains(typeName, "with time zone") then
                        "timestamp with time zone"
                    else if Text.StartsWith(typeName, "time") and Text.Contains(typeName, "with time zone") then
                        "time with time zone"
                    else if Text.StartsWith(typeName, "timestamp") then
                        "timestamp"
                    else if Text.StartsWith(typeName, "time") then
                        "time"
                    else 
                        typeName,

                #"FixedTypeNameTable" = Table.TransformColumns(source, { { "TYPE_NAME", FixTypeName } })

            in
                #"FixedTypeNameTable",

        // Transforms TOP queries into LIMIT queries.
        AstVisitor = [
            LimitClause = (skip, take) =>
                let
                    offset = if (skip <> null and skip > 0) then Text.Format("OFFSET #{0} ROWS", {skip}) else "",
                    limit = if (take <> null) then Text.Format("LIMIT #{0}", {take}) else ""
                in
                    [
                        Text = Text.Format("#{0} #{1}", {offset, limit}),
                        Location = "AfterQuerySpecification"
                    ]
        ],

        OdbcOptions = [
            // Enables client-side connection pooling for the ODBC driver.
            ClientConnectionPooling = true,

            // Handlers for ODBC driver capabilities.
            AstVisitor = AstVisitor,
            SQLColumns = SQLColumns,
            SQLGetInfo = SQLGetInfo,
            SqlCapabilities = SqlCapabilities,
            OnError = OnOdbcError,

            // Credential & SSL encryption options
            CredentialConnectionString = CredentialConnectionString,

            // View the tables grouped by their schema names.
            HierarchicalNavigation = true,

            // Controls whether your connector allows native SQL statements.
            HideNativeQuery = true,

            // Allows the M engine to select a compatible data type.
            SoftNumbers = true,

            // Allows conversion of numeric and text types to larger types.
            TolerateConcatOverflow = true,

            // Lets Power BI call SQLCancel and SQLFreeHandle instead of to abandon the connection
            CancelQueryExplicitly = true
        ],

        OdbcDataSource = Odbc.DataSource(ConnectionString, OdbcOptions), 
        CatalogNavigation = ToCatalogNavigation(OdbcDataSource, ConnectionString, [CredentialConnectionString = CredentialConnectionString])
    in
        CatalogNavigation;

// Build ODBC options based on ODBC driver 
BuildOdbcOptions = () as record =>
    let
        Merge = (previous as record, optional caps as record, optional funcs as record, optional getInfo as record) as record =>
            let
                newCaps = if (caps <> null) then previous[SqlCapabilities] & caps else previous[SqlCapabilities],
                newFuncs = if (funcs <> null) then previous[SQLGetFunctions] & funcs else previous[SQLGetFunctions],
                newGetInfo = if (getInfo <> null) then previous[SQLGetInfo] & getInfo else previous[SQLGetInfo]
            in
                [ SqlCapabilities = newCaps, SQLGetFunctions = newFuncs, SQLGetInfo = newGetInfo ],

        defaultConfig = [
            SqlCapabilities = [],
            SQLGetFunctions = [],
            SQLGetInfo = []
        ],

        withLocateOrPosition =
            if (Config_UsePositionInsteadOfLocate <> null) then
                let
                    value =
                        if (Config_UsePositionInsteadOfLocate = true) then
                            ODBC[SQL_FN_STR][SQL_FN_STR_POSITION]
                        else
                            ODBC[SQL_FN_STR][SQL_FN_STR_LOCATE],
                    getInfo = [
                        SQL_STRING_FUNCTIONS = value
                    ]
                in
                    Merge(defaultConfig, null, null, getInfo)
            else
                defaultConfig,

        withSqlConformance =
            if (Config_SqlConformance <> null) then
                let
                    getInfo = [
                        SQL_SQL_CONFORMANCE = Config_SqlConformance
                    ]
                in
                    Merge(withLocateOrPosition, null, null, getInfo)
            else
                withLocateOrPosition
    in
        withSqlConformance;

// Handles ODBC errors.
OnOdbcError = (errorRecord as record) =>
    let
        ErrorMessage = errorRecord[Message],
        ConnectionHostPort = errorRecord[Detail][DataSourcePath], // Type Text. { Host, Port }

        IsDriverNotInstalled = Text.Contains(ErrorMessage, "doesn't correspond to an installed ODBC driver"),

        OdbcError = errorRecord[Detail][OdbcErrors]{0},
        OdbcErrorCode = OdbcError[NativeError],

        IsODBCUnreachable =
            OdbcErrorCode = 1020, // ODBC server can not be reached on the given host
        IsEncryptionError =
            OdbcErrorCode = 1130 or OdbcErrorCode = 1160 // Connecting using SSL/TLS to an non-SSL/TLS socket
    in
        if IsDriverNotInstalled then
            error Error.Record("DataSource.Error", "The Starburst ODBC driver is not installed on the host. Please install the appropriate driver. " & ConnectionHostPort)
        else if IsEncryptionError then
            // Report error to trigger option to fallback to unencrypted connection.
            error Extension.CredentialError(Credential.EncryptionNotSupported)
        else if IsODBCUnreachable then
            error Error.Record("DataSource.Error", "Could not connect to server. Please double check your ODBC configuration. " & ConnectionHostPort)
        else
            error errorRecord;

//
// Helper functions for OAuth
//
// https://docs.microsoft.com/en-us/power-query/handlingauthentication
StartLogin = (resourceUrl, state, display) =>
    let
        oauthConfig = GetOAuthConfig(resourceUrl),
        codeVerifier = Text.NewGuid() & Text.NewGuid(),
        authorizeUrl =
            oauthConfig[authUrl]
            & "?"
            & Uri.BuildQueryString(
                [
                    client_id = oauthConfig[publicClientId],
                    state = state,
                    scope = GetScopeString(oauthConfig[scopes]),
                    response_type = "code",
                    code_challenge_method = "S256",
                    code_challenge = CreateSha256Hash(codeVerifier),
                    redirect_uri = RedirectUri
                ]
            )
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = RedirectUri,
            WindowWidth = 1024,
            WindowHeight = 720,
            Context = [ResourceUrl = resourceUrl, CodeVerifier = codeVerifier]
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        parts = Uri.Parts(callbackUri)[Query],
        result =
            if (Record.HasFields(parts, {"error", "error_description"})) then
                error Error.Record(parts[error], parts[error_description], parts)
            else
                TokenMethod(
                    context[ResourceUrl],
                    parts[code],
                    "authorization_code",
                    context[CodeVerifier]
                )
    in
        result;

Refresh = (resourceUrl, refresh_token) =>
    TokenMethod(
        resourceUrl,
        refresh_token,
        "refresh_token"
    );

Logout = (clientApplication, resourceUrl, accessToken) =>
    let
        oauthConfig = GetOAuthConfig(resourceUrl),
        logoutUrl = oauthConfig[logoutUrl]
    in
        logoutUrl;

CreateSha256Hash = (codeVerifier) =>
    let
        Hash = Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(codeVerifier)),
        Base64Text = Binary.ToText(Hash, BinaryEncoding.Base64),
        Base64TextTrimmed = Text.TrimEnd(Base64Text, "="),
        Base64Url = Text.Replace(Text.Replace(Base64TextTrimmed, "+", "-"), "/", "_")
    in
        Base64Url;

GetScopeString = (scopes as list) =>
    let
        addPrefix = List.Transform(scopes, each "" & _),
        scopeString = Text.Combine(addPrefix, " ")
    in
        scopeString;

TokenMethod = (resourceUrl, code, grant_type, optional verifier) =>
    let
        oauthConfig = GetOAuthConfig(resourceUrl),
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
                    client_id = oauthConfig[publicClientId],
                    grant_type = grant_type,
                    redirect_uri = RedirectUri
                ],
        ManualHandlingStatusCodes = {},
        Response =
                Web.Contents(
                    oauthConfig[tokenUrl],
                    [
                        Content = Text.ToBinary(Uri.BuildQueryString(query)),
                        Headers = [
                            #"Content-type" = "application/x-www-form-urlencoded",
                            #"Accept" = "application/json"
                        ],
                        ManualStatusHandling = ManualHandlingStatusCodes
                    ]
                ),
        Parts = Json.Document(Response)
    in
        // check for error in response
        if (Parts[error]? <> null) then
            error
                Error.Record(
                    Parts[error],
                    Parts[error_description],
                    Parts[message]?
                )
        else
            Parts;

// Gets OAuth parameters from Starburst
GetOAuthConfig = (resourceUrl as text) =>
    let
        // host may suffixed with /public-reference
        hostParts = Text.Split(Json.Document(resourceUrl)[Host], "/"),
        host = hostParts{0},
        publicReference = if (List.Count(hostParts) = 2) then "/" & hostParts{1} else "",
        port = Text.From(Json.Document(resourceUrl)[Port]),
        baseUrl = "https://" & host & ":" & port,
        oauthUrl = baseUrl & Text.Replace(OAuthPath, "${PUBLIC_REFERENCE}", publicReference),
        oauthConfig = GetData(oauthUrl)
    in
        oauthConfig;

// Sends a GET request
GetData = (url as text) =>
    let
        data =
            Json.Document(
                Web.Contents(
                    url,
                    [
                        Headers = [
                            Accept = "application/json"
                    ]
                ])
            )
    in
        data;

//
// Naviation table functions
//
ToCatalogNavigation = (odbcDataSoruce as table, connectionString as any, connectionOptions as record) as table =>
    let 
        catalogRecords = Table.TransformRows(odbcDataSoruce, 
            each [
                Name = _[Name], 
                Data = ToSchemaNavigation(odbcDataSoruce, connectionString, connectionOptions, _[Name]), 
                Kind = "Database",
                IsLeaf = false,
                NativeData = _[Data]
            ]
        ),
        catalogTable = Table.FromRecords(catalogRecords, {"Name", "Data", "Kind", "IsLeaf", "NativeData"}),
        navigationTable = ToNavigation(catalogTable)
    in 
        navigationTable;

ToSchemaNavigation = (sourceTable as table, connectionString as any, connectionOptions as record, catalogName as text) as table =>
    let 
        queryTable = Odbc.Query(
            connectionString,  
            "SELECT schema_name FROM """ & Text.Replace(catalogName, """", """""") 
                & """.""information_schema"".""schemata"" WHERE schema_name <> 'information_schema'",
            connectionOptions
        ),
        schemaRecords = Table.TransformRows(queryTable, 
            each [
                Name = _[schema_name], 
                Data = ToTableNavigation(sourceTable, connectionString, connectionOptions, catalogName, _[schema_name]), 
                Kind = "Schema",
                IsLeaf = false
            ]
        ),
        schemaTable = Table.FromRecords(schemaRecords, {"Name", "Data", "Kind", "IsLeaf"}),
        navigationTable = ToNavigation(schemaTable)
    in 
        navigationTable;

ToTableNavigation = (sourceTable as table, connectionString as any, connectionOptions as record, catalogName as text, schemaName as text) as table =>
    let 
        queryTable = Odbc.Query(
            connectionString, 
            "SELECT table_name FROM """ & Text.Replace(catalogName, """", """""")
                & """.""information_schema"".""tables"" WHERE table_schema = '" & Text.Replace(schemaName, "'", "''") & "'",
            connectionOptions
        ),
        tableRecords = Table.TransformRows(queryTable, 
            each [
                Name = _[table_name], 
                Data = sourceTable{[Name=catalogName,Kind="Database"]}[Data]{[Name=schemaName,Kind="Schema"]}[Data]{[Name=_[table_name],Kind="Table"]}[Data],
                Kind = "Table",
                IsLeaf = true
            ]
        ),
        tableTable = Table.FromRecords(tableRecords, {"Name", "Data", "Kind", "IsLeaf"}),
        navigationTable = ToNavigation(tableTable)
    in 
        navigationTable;

ToNavigation = (dataTable as table) as table =>
    let
        originalTableType = Value.Type(dataTable),
        newTableType = Type.AddTableKey(originalTableType, {"Name", "Kind"}, true) meta 
        [
            NavigationTable.NameColumn = "Name",
            NavigationTable.DataColumn = "Data",
            NavigationTable.ItemKindColumn = "Kind",
            Preview.DelayColumn = "Kind",
            NavigationTable.IsLeafColumn = "IsLeaf"
        ],
        navigationTable = Value.ReplaceType(dataTable, newTableType)
    in
        navigationTable;

//
// Util functions
//
// Parse connection string like "catalog=tpch;roles={system=public;postgres=admin};ssl=1",
ParseConnectionString = (connString as text) as record =>
    let
        // Split connection and trim off escape chars {}
        tokens = List.Generate(
            // initial
            // i: index of char, q: within {} or not, buf: buffer of a name-value pair, val: emitted name-value pair
            () => [i = 0, q = false, buf = Text.At(connString, 0), val = null],
            // condition
            each _[i] < Text.Length(connString),
            // next
            each
                let
                    i = _[i],
                    q = _[q],
                    buf = _[buf],
                    val = _[val],
                    // move to next char
                    i1 = i + 1,
                    c = Text.At(connString, i1),
                    // flip state flag q
                    q1 = if not q and c = "{" then true else if q and c = "}" then false else q,
                    // skip separator (;) and reset buffer, otherwise append to buffer
                    buf1 = if not q and c = ";" then "" else buf & c,
                    // a separator (;) or end of string, emit buffer to val, otherwise emit null
                    val1 = if not q and c = ";" then buf else if i1 = Text.Length(connString) - 1 then buf1 else null
                in
                    [i = i1, q = q1, buf = buf1, val = val1]
        ),

        // get emitted nv pair strings from tokens, and convert to list of nv pair records
        // remove {} from values as needed
        nvRecords = List.Transform(
            // split by =
            List.Transform(
                // remove nulls
                List.Select(
                // select val only
                List.Transform(tokens, each _[val]), each _ <> null and Text.Length(Text.Trim(_)) > 0),
                each 
                [
                    n = Text.Trim(Text.Middle(_, 0, Text.PositionOf(_, "="))),
                    v = Text.Trim(Text.Middle(_, Text.PositionOf(_, "=") + 1))
                ]
            ),
            each 
            [
                n = _[n],
                v = if Text.At(_[v], 0) = "{" then Text.Middle(_[v], 1, Text.Length(_[v]) - 2) else _[v]
            ]
        ),

        // convert records to a table with two columns, Name and Value
        nvTable = Table.RenameColumns(
            // convert to a table
            if List.Count(nvRecords) = 0 then
                // make an empty table
                Table.SelectRows(Table.FromRecords({[n = null, v = null]}), each _[n] <> null)
            else
                // transform list into a table
                Table.FromRecords(nvRecords),
            {{"n", "Name"}, {"v", "Value"}}
        )
    in
        // return a record
        Record.FromTable(nvTable);

// Concatenate properties in name=value;name2=value2 format 
FormatConnectionString = (rec as record) as text =>
    if Record.FieldCount(rec) > 0 then 
        let 
            str = List.Accumulate(
                Table.ToRecords(Record.ToTable(rec)), 
                "", 
                (str, current) => str & current[Name] & "=" & current[Value] & ";"
            )
        in
            Text.Middle(str, 0, Text.Length(str) - 1)
    else 
        "";

// Case-insensitive connection property merge
// M language merge: merge([a = 1, b = 2], [A = "a"]) => [a = 1, b = 2, A = "a"]
// MergeConnectionProperties([a = 1, b = 2], [A = "a"]) => [b = 2, A = "a"]
MergeConnectionProperties = (rec1 as record, rec2 as record) =>
    let 
        // get normalized name (lower case) to original name map
        getNameMap = (rec as record) as record => 
            Record.FromList(
                Record.FieldNames(rec), 
                List.Transform(
                    Record.FieldNames(rec),
                    each Text.Lower(_)
                )
            ),

        // normalize field name (lower case)
        normalizeFieldNames = (rec as record) =>
            Record.RenameFields(
                rec,
                List.Transform(
                    Record.FieldNames(rec),
                    each {_, Text.Lower(_)}
                )
            ),

        // rename field names using original names
        ret = Record.RenameFields(
            // normalize field names then merge
            normalizeFieldNames(rec1) & normalizeFieldNames(rec2),
            List.Transform(
                Table.ToRecords(
                    Record.ToTable(
                        getNameMap(rec1) & getNameMap(rec2)
                    )
                ),
                each {_[Name], _[Value]}
            )
        )
    in
        ret;

// Only white labled properties can be specified via 
ValidateConnectionStringProperties = (properties as record) as record =>
    let 
        BooleanValidator = (val) as logical => val = "0" or val = "1",
        ValidPropertyMap = Table.AddColumn(
            #table(
                {"Name", "Validator"},
                {
                    // Following connection properties are defined by ODBC driver, but we execlude some of them:
                    // 1. Passed from connect dialog or credential dialog
                    // 2. Explicitly used in connector code already
                    // 3. Security concerns
                    // 4. Don't want to give it to end users
                    
                    {"AllowHostNameCNMismatch",each BooleanValidator(_)},
                    {"AllowHTTPRedirect", each BooleanValidator(_)},
                    // AllowMetadataFromMultipleCatalogs - lazy navigator
                    {"AllowSelfSignedServerCert", each BooleanValidator(_)},
                    // ApplicationName - hard coded in this connector
                    // ApplicationNamePrefix - don't want to give it to end users
                    // AuthenticationType - defined in login credential
                    // AutoIPD - always use default 1
                    // cacheAccessToken - seems like an obsolete parameter, https://help.insightsoftware.com/s/case/5004U000017VSlpQAG/questions-regarding-cacheaccesstoken?language=en_US
                    // CallingAppName - don't want to give it to end users
                    // Catalog - users have to use UI input
                    // ClientCert - no path allowed
                    // ClientPrivateKey - no path allowed
                    // ClientPrivateKeyPassword - security concerns
                    {"ClientTags", null},
                    {"ConnectionTest", each BooleanValidator(_)},
                    {"DelegateKrbCreds", each BooleanValidator(_)},
                    {"DelegationUID", null},
                    // Driver - always Starburst ODBC Driver
                    {"EffectiveUserName", null},
                    // SSL - defined in credential dialog
                    {"ExtraCredentials", null},
                    // Host
                    // IgnoreBrokenCatalog - lazy navigator
                    // KerberosKeytab - no path allowed
                    // KerberosPassword - security concerns
                    {"KerberosUsername", null},
                    {"KinitType", each _ = "Kinit with Keytab" or _ = "Kinit with Password"},
                    {"KrbServiceName", null},
                    // LogFileCount - log settings are driver level only
                    // LogFileSize
                    // LogLevel
                    // LogPath
                    {"MaxCatalogNameLen", each Int32.From(_) >= 0 and Int32.From(_) <= 65535},
                    {"MaxColumnNameLen", each Int32.From(_) >= 0 and Int32.From(_) <= 65535},
                    {"MaxComplexTypeColumnLength", each Int32.From(_) >= 0 and Int32.From(_) <= 65535},
                    {"MaxSchemaNameLength", each Int32.From(_) >= 0 and Int32.From(_) <= 65535},
                    {"MaxSchemaNameLength", each Int32.From(_) >= 0 and Int32.From(_) <= 65535},
                    {"MaxDefaultVarCharLength", each Int32.From(_) >= 0 and Int32.From(_) <= 65535},
                    {"Min_TLS", each _ = "1.0" or _ = "1.1" or _ = "1.2"},
                    // PWD
                    // Port
                    {"ProxyHost", null},
                    {"ProxyPort", each Int32.From(_) >= 0 and Int32.From(_) <= 65535},
                    // ProxyPwd - security concerns
                    // ProxyUid - security concerns
                    // RemoveTypeNameParameters - always use 1
                    {"Roles", null},
                    {"Schema", null},
                    // ServerVersion - don't want to give it to end users
                    {"TimeZoneID", null},
                    {"TrustedCerts", null},
                    {"TwoWaySSL", each BooleanValidator(_)},
                    // UseDSNSchemaForMetadata - lazy navigator
                    // UseEqualInMetadataFilters - don't want to give it to end users
                    {"UseExistingKrbCreds", each BooleanValidator(_)},
                    {"UseGSSAPI", each BooleanValidator(_)},
                    {"UseProxy", each BooleanValidator(_)},
                    // UseSystemCatalogForMetadata - lazy navigator
                    {"UseSystemTrustStore", each BooleanValidator(_)},
                    {"UseUnicodeSqlCharacterTypes", each BooleanValidator(_)}
                }
            ),
            "ValidKey",
            each Text.Lower(_[Name])
        ),
        PropsTable = Table.RenameColumns(
            Table.AddColumn(
                Record.ToTable(properties),
                "InputKey",
                each Text.Lower(_[Name])
            ),
            {"Name", "InputName"}
        ),
        InvalidKeys = Table.Column(
            Table.Join(
                PropsTable,
                "InputKey",
                ValidPropertyMap,
                "ValidKey",
                JoinKind.LeftAnti
            ),
            "InputName"
        ),
        ValidateValue = (name, value, validator) =>
            if (validator is null or validator(value)) then
                null
            else
                Text.Format(
                    "Invalid value '#{0}' for '#{1}'",
                    {value, name}
                ),
        InvalidValues = List.RemoveNulls(
            Table.TransformRows(
                Table.Join(
                    PropsTable,
                    "InputKey",
                    ValidPropertyMap,
                    "ValidKey",
                    JoinKind.Inner
                ),
                each ValidateValue([InputName], [Value], [Validator])
            )
        )
    in 
        if not List.IsEmpty(InvalidKeys) then
            error Error.Record(
                "Expression.Error", 
                Text.Format(
                    "'#{0}' are not valid connection string properties. Valid properties are: '#{1}'",
                    {Text.Combine(InvalidKeys, ", "), Text.Combine(Table.Column(ValidPropertyMap, "Name"), ", ")}
                )
            )
        else if not List.IsEmpty(InvalidValues) then
            error Error.Record("Expression.Error", Text.Combine(InvalidValues, ", ") & ".")
        else
            properties;

// Loads functions from another project file.
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

ODBC = Extension.LoadFunction("OdbcConstants.pqm");
Odbc.Flags = ODBC[Flags];
