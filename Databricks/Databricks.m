[Version="1.0.5"]
section Databricks;

TrustedAadDomains = {".azuredatabricks.net", ".databricks.azure.cn", ".databricks.azure.us"};

//Indicates the level of SQL-92 supported by the driver.
Config_SqlConformance = 8;

[DataSource.Kind="Databricks", Publish="Databricks.Publish"]
shared Databricks.Contents = Value.ReplaceType(DatabricksImpl, DatabricksType);

// Wrapper function to provide additional UI customization.
DatabricksType = type function (
        host as (type text meta [
            Documentation.FieldCaption = Extension.LoadString("ServerHostNameLabel"),
            Documentation.FieldDescription = Extension.LoadString("ServerHostNameHelp"),
            Documentation.SampleValues = { "example.azuredatabricks.net" }
        ]),
        httpPath as (type text meta [
            Documentation.FieldCaption = Extension.LoadString("HttpPathLabel"),
            Documentation.FieldDescription = Extension.LoadString("HttpPathHelp"),
            Documentation.SampleValues = { "sql/protocolv1/o/1814582234607533/7508-187377-agent704" }
        ]),
        optional options as (type nullable [
            optional Database = (type text meta [
                Documentation.FieldCaption = Extension.LoadString("DatabaseLabel"),
                Documentation.FieldDescription = Extension.LoadString("DatabaseHelp")
            ])
        ] meta [
            Documentation.FieldCaption = Extension.LoadString("AdvancedOptionsLabel")
        ])
    ) as table meta [
        Documentation.Name = Extension.LoadString("DataSourceName")
    ];

DatabricksImpl = (host as text, httpPath as text, optional options as record) as table =>
    let
        Credential = Extension.CurrentCredential(),
        AuthenticationMode = Credential[AuthenticationKind],

        ValidatedHost = if AuthenticationMode = "OAuth" then
            ValidateTrustedAadHost(host)
        else
            // Allow other domains for non-AAD auth
            ValidateAnyHost(host),

        AuthConnectionString =
            if AuthenticationMode = "UsernamePassword" then
                [
                    AuthMech = 3,
                    UID = Credential[Username],
                    PWD = Credential[Password]
                ]
            else if AuthenticationMode = "Key" then
                [
                    // Although AuthMech=11 happens to work, this is not intended behavior and
                    // any resulting error messages cannot be processed by the driver.
                    // Token authentication should be done via UID="token";PWD=<token> 
                    // for proper authentication failure handling.
                    AuthMech = 3,
                    UID = "token",
                    PWD = Credential[Key]
                ]
            else if AuthenticationMode = "OAuth" then
                [
                    AuthMech = 11,
                    Auth_Flow = 0,
                    Auth_AccessToken = Credential[access_token]
                ]
            else
                // Should not be reachable.
                error Extension.CredentialError("DataSource.UnsupportedAuthenticationKind", Text.Format("Unsupported authentication mode #{0}", AuthenticationMode)),

        ValidatedOptions = ValidateAdvancedOptions(options),

        OptionOdbcFields = OdbcFieldsFromOptions(ValidatedOptions),

        HasSchema = ValidatedOptions[Database]? <> null,

        ConnectionString = [
            Driver = "Simba Spark ODBC Driver",
            Host = ValidatedHost,
            HTTPPath = httpPath,
            Port = 443,
            ThriftTransport = 2,
            SparkServerType = 3,
            SSL = 1,
            UseNativeQuery = 0,
            UserAgentEntry = "PowerBI",
            UseSystemTrustStore = 1,
            RowsFetchedPerBlock = 200000,
            LCaseSspKeyName = 0,
            ApplySSPWithQueries = 0,
            UseUnicodeSqlCharacterTypes = 1,
            SSP_spark.sql.thriftserver.metadata.table.singleschema = Logical.ToText(HasSchema)
        ] & OptionOdbcFields,

        DefaultConfig = BuildOdbcConfig(),

        SqlCapabilities = DefaultConfig[SqlCapabilities] & [
            LimitClauseKind = LimitClauseKind.Limit,
            FractionalSecondsScale = 3,
            SupportsNumericLiterals = true,
            SupportsStringLiterals = true,
            SupportsOdbcDateLiterals = true,
            SupportsOdbcTimeLiterals = true,
            SupportsOdbcTimestampLiterals = true
        ],
        
        SQLGetFunctions = [
            // Disable using parameters in the queries that get generated.
            // We enable numeric and string literals which should enable
            // literals for all constants.
            SQL_API_SQLBINDPARAMETER = false,
            SQL_API_SQLBINDCOL = if ValidatedOptions[SQL_API_SQLBINDCOL]? <> null then ValidatedOptions[SQL_API_SQLBINDCOL] else false
        ],

        SQLGetInfo = DefaultConfig[SQLGetInfo] & [
            SQL_SQL92_PREDICATES = ODBC[SQL_SP][All],
            SQL_AGGREGATE_FUNCTIONS = ODBC[SQL_AF][All]
        ],

       // Fix for data type mismatch.
       SQLColumns = (catalogName, schemaName, tableName, columnName, source) =>
            let
                OdbcSqlTypeName.VARCHAR = "varchar",
                OdbcSqlTypeName.CHAR = "char",
                OdbcSqlTypeName.DECIMAL = "decimal",

                FixDataTypeName = (dataTypeName) =>
                    if Text.Contains(dataTypeName, "varchar") then
                        OdbcSqlTypeName.VARCHAR
                    else if Text.Contains(dataTypeName, "char") then
                        OdbcSqlTypeName.CHAR
                    else if Text.Contains(dataTypeName, "decimal") then
                        OdbcSqlTypeName.DECIMAL
                    else
                        dataTypeName,
                Transform = Table.TransformColumns(source, { { "TYPE_NAME", FixDataTypeName }})
            in
                Transform,

        Options = [
            // View the tables grouped by their schema names.
            HierarchicalNavigation = not HasSchema,

            // Controls whether your connector allows native SQL statements.
            HideNativeQuery = true,

            // Allows the M engine to select a compatible data type.
            SoftNumbers = true,

            // Allows conversion of numeric and text types to larger types.
            TolerateConcatOverflow = true,

            // Enables client-side connection pooling for the ODBC driver.
            ClientConnectionPooling = true,

            // The Databricks driver is shipped with Power BI
            UseEmbeddedDriver = true,

            // Handlers for ODBC driver capabilities.
            SqlCapabilities = SqlCapabilities,
            SQLColumns = SQLColumns,
            SQLGetFunctions = SQLGetFunctions,
            SQLGetInfo = SQLGetInfo,
            OnError = OnOdbcError
        ],

        // Connection string properties used for encrypted connections.
        CommonOptions = [
            CredentialConnectionString = AuthConnectionString
        ],

        Databases = Odbc.DataSource(ConnectionString, Options & CommonOptions),
        Metadata = Value.Metadata(Value.Type(Databases)),

        WithSchema = if HasSchema then
            Table.SelectRows(Databases, each [Schema] = OptionOdbcFields[Schema])
        else
            Databases

        // TODO: Convert complex data types. Our current implementation is broken, and
        // not in a shippable state due to poor deserialization of Hive-flavored json.
        // It would require a change in the Thrift server to unblock this.
in
    WithSchema;

AdvancedOptionsValidators = let
        EmptyTextToNull = (schema as text) => if schema = "" then
                null
            else
                schema,

        PositiveInteger = (number as number) => if number > 0 then
                Int32.From(number)
            else
                error Error.Record("Expression.Error"),

        IdentityFn = (x as any) => x,

        RenameField = (key as text) => (value) => Record.AddField([], key, value)

    in
        #table(
            {"Key", "Type", "Validator", "ToOdbcFields"},
            {
                {"BatchSize", type number, PositiveInteger, RenameField("RowsFetchedPerBlock")},
                {"Database", type text, EmptyTextToNull,  RenameField("Schema")},
                {"EnableArrow", type text, IdentityFn,  RenameField("EnableArrow")},
                {"EnableQueryResultDownload", type text, IdentityFn, RenameField("EnableQueryResultDownload") },
                {"EnableQueryResultLZ4Compression", type text, IdentityFn, RenameField("EnableQueryResultLZ4Compression")},
                {"MaxNumResultFileDownloadThreads", type text, IdentityFn, RenameField("MaxNumResultFileDownloadThreads")},
                {"MaxConsecutiveResultFileDownloadRetries", type text, IdentityFn, RenameField("MaxConsecutiveResultFileDownloadRetries")},
                {"RowsFetchedPerBlock", type text, IdentityFn, RenameField("RowsFetchedPerBlock")},
                {"UseNativeQuery", type text, IdentityFn, RenameField("UseNativeQuery")},
                {"SSP_spark.thriftserver.catalog.default", type text, IdentityFn, RenameField("SSP_spark.thriftserver.catalog.default")},
                {"SSP_spark.thriftserver.cloudfetch.enabled", type text, IdentityFn, RenameField("SSP_spark.thriftserver.cloudfetch.enabled")},
                {"SSP_spark.thriftserver.cloudStoreBasedRowSet.enabled", type text, IdentityFn, RenameField("SSP_spark.thriftserver.cloudStoreBasedRowSet.enabled")},

                // non-connectionstring fields
                {"SQL_API_SQLBINDCOL", type logical, IdentityFn, null}
            }
        );

ValidateAdvancedOptions = (optional options as record) as record =>
    let
        allKeys = Table.Column(AdvancedOptionsValidators, "Key"),

        // all advanced options are assumed to be nullable
        assertType = (field as record) => (v) =>
            try
                if v = null then
                    null
                else if Value.Is(v, field[Type]) then
                    field[Validator](v)
                else error Error.Record("Expression.Error")
            otherwise
                error Error.Record("Expression.Error", Text.Format(Extension.LoadString("ErrorAdvancedOptionValue"), {v, field[Key]})),

        fieldToValidatorMap = List.Transform(Table.ToRecords(AdvancedOptionsValidators), each {[Key], assertType(_)}),

        knownFields = Record.SelectFields(options, allKeys, MissingField.Ignore),

        validatedWithNulls = Record.TransformFields(knownFields, fieldToValidatorMap, MissingField.Ignore),

        nonNullKeys = List.Select(Record.FieldNames(validatedWithNulls), each Record.Field(validatedWithNulls, _) <> null),
        validatedOptions = Record.SelectFields(validatedWithNulls, nonNullKeys)
    in
        if options <> null then
            validatedOptions
        else
            [];

// map advanced option fields to ODBC fields
OdbcFieldsFromOptions = (options as record) as record =>
    let
        noOdbcField = Table.Column(Table.SelectRows(AdvancedOptionsValidators, each [ToOdbcFields] = null), "Key"),
        filteredOptions = Record.RemoveFields(options, noOdbcField, MissingField.Ignore),
        
        fieldToOdbcFieldsMap = Record.Combine(List.Transform(Table.ToRecords(AdvancedOptionsValidators), (v) => Record.AddField([], v[Key], v[ToOdbcFields]))),
        fieldLists = List.Transform(Record.FieldNames(filteredOptions), (v) => Record.Field(fieldToOdbcFieldsMap, v)(Record.Field(filteredOptions, v))),
        mappedFields = Record.Combine(fieldLists)
        
    in
        mappedFields;

// Handles ODBC errors.
OnOdbcError = (errorRecord as record) =>
    let
        ErrorMessage = errorRecord[Message],

        IsDriverNotInstalled = Text.Contains(ErrorMessage, "doesn't correspond to an installed ODBC driver"),

        OdbcError = errorRecord[Detail][OdbcErrors]{0},
        OdbcErrorMessage = OdbcError[Message],
        OdbcErrorCode = OdbcError[NativeError],
        OdbcErrorSqlState = OdbcError[SqlState],

        IsOdbcError = errorRecord[Detail]? <> null and errorRecord[Detail][OdbcErrors]? <> null,

        // ThriftExtension has its own set of error codes that overlap with ODBC errors.
        IsThriftError = Text.Contains(OdbcErrorMessage, "[ThriftExtension]"),

        // ODBC SSL errors
        IsEncryptionError = List.Contains({6, 1130, 1160}, OdbcErrorCode),

        // ODBC server can not be reached on the given host/port
        IsODBCUnreachable = OdbcErrorCode = 1020,

        TokenExpiredError = IsThriftError and OdbcErrorCode = 10 and Extension.CurrentCredential(true) <> null,

        // Workaround, requires fix from Simba's side. Error 14 is a generic Thrift error.
        InvalidTokenError = IsThriftError and OdbcErrorCode = 14 and Text.Contains(OdbcErrorMessage, "Unauthorized/Forbidden"),

        HasCredentialError = IsThriftError and OdbcErrorCode = 0 and OdbcErrorCode <> 7 and OdbcErrorCode <> 14,

        // Required credential settings missing
        MissingCredentialsError = OdbcErrorCode = 11570,

        DataSourceMissingClientLibrary = "DataSource.MissingClientLibrary",

        DataSourceError = "DataSource.Error"

    in
        if IsDriverNotInstalled then
            error Error.Record(DataSourceMissingClientLibrary, Extension.LoadString("ErrorMissingClientLibrary"))
        else if not IsOdbcError then
            error errorRecord
        else if IsEncryptionError then
            // Report error to trigger option to fallback to unencrypted connection.
            error Extension.CredentialError(Credential.EncryptionNotSupported)
        else if IsODBCUnreachable then
            error Error.Record(DataSourceError, Extension.LoadString("ErrorOdbcCouldNotConnect"))
        else if TokenExpiredError then
            true // refreshes access token
        else if HasCredentialError or InvalidTokenError then
            error Extension.CredentialError(Credential.AccessDenied, OdbcErrorMessage)
        else if MissingCredentialsError then
            error Extension.CredentialError(
                Credential.AccessDenied, Extension.LoadString("ErrorOdbcAccessDenied"))
        else
            error errorRecord;

// Returns the host if it is a valid host name for any domain. Throws an error otherwise.
ValidateAnyHost = (host as text) as text =>
    let
        parsedHost = try Uri.Parts("scheme://" & host)[Host] otherwise null
    in
        if parsedHost <> null and host = parsedHost then
            host
        else
            error Error.Record("Error", Text.Format(Extension.LoadString("ErrorInvalidHost"), {host}));

// Returns a validated host name for trusted AAD domains. Throws an error if the domain is not on the approved list.
ValidateTrustedAadHost = (host as text) as text =>
    let
        parsedHost = ValidateAnyHost(host),
        isTrusted = List.MatchesAny(TrustedAadDomains, (domain) => Text.EndsWith(parsedHost, domain))
    in
        if isTrusted then
            parsedHost
        else
            error Error.Record("Error", Text.Format(Extension.LoadString("ErrorAadInvalidDomain"), {host}));

GetAuthorizationUrlFromLocation = (url as text) as text =>
    let
        // Sending an unauthenticated request to /aad/auth returns
        // a 302 status with Location header in the response.
        // The value will contain the correct authorization_uri, plus a query string we
        // drop and substitute for our own.
        // Example:
        //   Location: https://login.microsoftonline.com/{tenant_guid}/oauth2/authorize?...
        responseCodes = {302},
        endpointResponse = Web.Contents(url, [
            ManualCredentials = true,
            ManualStatusHandling = responseCodes
        ])
    in
        if (List.Contains(responseCodes, Value.Metadata(endpointResponse)[Response.Status]?)) then
            let
                headers = Record.FieldOrDefault(Value.Metadata(endpointResponse), "Headers", []),
                location = Record.FieldOrDefault(headers, "Location", ""),
                splitQuery = Text.Split(Text.Trim(location), "?"),
                authorizationUri = List.First(splitQuery, null)
            in
                if (authorizationUri <> null) and Text.EndsWith(authorizationUri, "authorize") then
                    authorizationUri
                else
                    error Error.Record("Error", Extension.LoadString("ErrorAadInvalidLocation"), [
                        #"Location" = location
                    ])
        else
            error Error.Record("Error", Extension.LoadString("ErrorAadRedirectFailed"), [
                Response.Status = Value.Metadata(endpointResponse)[Response.Status]?
            ]);

// Data Source Kind description.
Databricks = [
    Label = Extension.LoadString("DataSourceLabel"),

    Authentication = [
        Aad = [
            AuthorizationUri = (dataSourcePath as text) =>
                let
                    json = Json.Document(dataSourcePath),
                    _host = json[host],
                    HTTPPath = json[httpPath],

                    ValidatedHost = ValidateTrustedAadHost(_host),

                    HTTPPathParts = Text.Split(HTTPPath, "/"),
                    OrgIdPos = List.PositionOf(HTTPPathParts, "o") + 1,
                    OrgId = HTTPPathParts{OrgIdPos},

                    PathHasOrgId = OrgIdPos > 0,

                    // Eagerly evaluate ValidatedHost: failure in Text.Format obfuscates the error
                    AssertHostValid = ValidatedHost <> null, // true or error

                    ClusterUri =
                        if AssertHostValid and PathHasOrgId then
                            Text.Format("https://#{0}/aad/auth?o=#{1}", {ValidatedHost, OrgId})
                        else
                            Text.Format("https://#{0}/aad/auth", {ValidatedHost})
                in
                    GetAuthorizationUrlFromLocation(ClusterUri),

            Resource = "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d",
            Label = Extension.LoadString("AzureActiveDirectoryLabel")
        ],
        UsernamePassword = [
            Label = Extension.LoadString("UsernamePasswordLabel")
        ],
        Key = [
            KeyLabel = Extension.LoadString("PersonalAccessTokenLabel"),
            Label = Extension.LoadString("PersonalAccessTokenLabel")
        ]
    ],

    // Needed for use with Power BI Service.
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            Host = json[host],
            HTTPPath = json[httpPath]
        in
            { "Databricks.Contents", Host, HTTPPath }
];

// Data Source UI publishing description.
Databricks.Publish = [
    Category = "Azure",
    SupportsDirectQuery = true,

    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },

    SourceImage = Databricks.Icons,
    SourceTypeImage = Databricks.Icons
];

Databricks.Icons = [
    Icon16 = { Extension.Contents("Databricks16.png"), Extension.Contents("Databricks20.png"), Extension.Contents("Databricks24.png"), Extension.Contents("Databricks32.png") },
    Icon32 = { Extension.Contents("Databricks32.png"), Extension.Contents("Databricks40.png"), Extension.Contents("Databricks48.png"), Extension.Contents("Databricks64.png") }
];

BuildOdbcConfig = () as record =>
    let
        defaultConfig = [
            SqlCapabilities = [],
            SQLGetInfo = []
        ],

        withSqlConformance =
            if (Config_SqlConformance <> null) then
                let
                    caps = defaultConfig[SQLGetInfo] & [
                        SQLGetInfo = [
                            SQL_SQL_CONFORMANCE = Config_SqlConformance
                        ]
                    ]
                in
                    defaultConfig & caps
            else
                defaultConfig
    in
        withSqlConformance;

// Loads functions from another project file.
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

ODBC = Extension.LoadFunction("OdbcConstants.pqm");
Odbc.Flags = ODBC[Flags];
