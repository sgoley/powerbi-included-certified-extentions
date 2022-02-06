[Version="1.1.1"]
section Databricks;

TrustedAadDomains = {".azuredatabricks.net", ".databricks.azure.cn", ".databricks.azure.us"};

//Indicates the level of SQL-92 supported by the driver.
Config_SqlConformance = 8;

[DataSource.Kind="Databricks", Publish="Databricks.Publish"]
shared Databricks.Catalogs = Value.ReplaceType(DatabricksCatalogsImpl, DatabricksType);

[DataSource.Kind="Databricks"]
shared Databricks.Contents = Value.ReplaceType(DatabricksLegacyImpl, DatabricksType);

// Wrapper function to provide additional UI customization.
DatabricksType = let
        ExperimentalFlags.Disabled = "disabled" meta [
            Documentation.Name = "ExperimentalFlags.Disabled",
            Documentation.Caption = Extension.LoadString("ExperimentalFlagsDisabledLabel")
        ],
        ExperimentalFlags.Enabled = null meta [
            Documentation.Name = "ExperimentalFlags.Enabled",
            Documentation.Caption = Extension.LoadString("ExperimentalFlagsEnabledLabel")
        ]
    in
        type function (
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
                ]),
                optional EnableExperimentalFlagsV1_1_0 = (type text meta [
                    Documentation.FieldCaption = Extension.LoadString("EnableExperimentalFlagsLabel"),
                    Documentation.FieldDescription = Extension.LoadString("EnableExperimentalFlagsHelp"),
                    Documentation.AllowedValues = { ExperimentalFlags.Enabled, ExperimentalFlags.Disabled }
                ])
            ] meta [
                Documentation.FieldCaption = Extension.LoadString("AdvancedOptionsLabel")
            ])
        ) as table meta [
            Documentation.Name = Extension.LoadString("DataSourceName")
        ];

DatabricksCatalogsImpl = (host as text, httpPath as text, optional options as record) as table =>
    let
        optionsRecord = if options = null then [] else options,
        defaultOptions = [
            UseNativeQuery = "2",
            EnableMultipleCatalogsSupport = "1"
        ],
        catalogs = DatabricksDataSource(host, httpPath, defaultOptions & optionsRecord),
        catalogsWithRenamedSpark = RenameSparkCatalog(catalogs)
    in
        catalogsWithRenamedSpark;

DatabricksLegacyImpl = (host as text, httpPath as text, optional options as record) as table =>
    let
        optionsRecord = if options = null then [] else options,
        defaultOptions = [
            EnableMultipleCatalogsSupport = "0"
        ]
    in
        DatabricksDataSource(host, httpPath, defaultOptions & optionsRecord);

DatabricksDataSource = (host as text, httpPath as text, options as record) as table =>
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
            DefaultStringColumnLength=65535,
            DecimalColumnScale = 10,
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

        SqlApiBindCol_Default = false,

        SQLGetFunctions = [
            // Disable using parameters in the queries that get generated.
            // We enable numeric and string literals which should enable
            // literals for all constants.
            SQL_API_SQLBINDPARAMETER = false,
            SQL_API_SQLBINDCOL = if ValidatedOptions[SQL_API_SQLBINDCOL]? <> null then 
                    ValidatedOptions[SQL_API_SQLBINDCOL] 
                else 
                    SqlApiBindCol_Default
        ],

        SQLStringFunctions = ODBC[Flags]({
            // These are currently disabled but supported by the backend. To be directly enabled in driver in future"
            // ODBC[SQL_FN_STR][SQL_FN_STR_BIT_LENGTH],
            // ODBC[SQL_FN_STR][SQL_FN_STR_CHAR_LENGTH],
            // ODBC[SQL_FN_STR][SQL_FN_STR_CHARACTER_LENGTH],
            // ODBC[SQL_FN_STR][SQL_FN_STR_OCTET_LENGTH],
            // ODBC[SQL_FN_STR][SQL_FN_STR_POSITION],
            // ODBC[SQL_FN_STR][SQL_FN_STR_REPLACE],
            // ODBC[SQL_FN_STR][SQL_FN_STR_SPACE],

            ODBC[SQL_FN_STR][SQL_FN_STR_ASCII],
            ODBC[SQL_FN_STR][SQL_FN_STR_CHAR],
            ODBC[SQL_FN_STR][SQL_FN_STR_CONCAT],
            // ODBC[SQL_FN_STR][SQL_FN_STR_DIFFERENCE],  Not supported
            // ODBC[SQL_FN_STR][SQL_FN_STR_INSERT], Not supported
            ODBC[SQL_FN_STR][SQL_FN_STR_LCASE],
            ODBC[SQL_FN_STR][SQL_FN_STR_LEFT],
            ODBC[SQL_FN_STR][SQL_FN_STR_LENGTH],
            ODBC[SQL_FN_STR][SQL_FN_STR_LOCATE],
            // ODBC[SQL_FN_STR][SQL_FN_STR_LOCATE_2], LOCATE is supported
            ODBC[SQL_FN_STR][SQL_FN_STR_LTRIM],
            ODBC[SQL_FN_STR][SQL_FN_STR_REPEAT],
            ODBC[SQL_FN_STR][SQL_FN_STR_RIGHT],
            ODBC[SQL_FN_STR][SQL_FN_STR_RTRIM],
            ODBC[SQL_FN_STR][SQL_FN_STR_SOUNDEX],
            ODBC[SQL_FN_STR][SQL_FN_STR_SUBSTRING],
            ODBC[SQL_FN_STR][SQL_FN_STR_UCASE]
        }),

        SQLNumericFunctions = ODBC[Flags]({
            // These are currently disabled but supported by the backend. To be directly enabled in driver in future"
            // ODBC[SQL_FN_NUM][SQL_FN_NUM_COT]
            ODBC[SQL_FN_NUM][SQL_FN_NUM_ABS],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_ACOS],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_ASIN],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_ATAN],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_ATAN2],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_CEILING],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_COS],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_DEGREES],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_EXP],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_FLOOR],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_LOG],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_LOG10],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_MOD],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_PI],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_POWER],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_RADIANS],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_RAND],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_ROUND],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_SIGN],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_SIN],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_SQRT],
            ODBC[SQL_FN_NUM][SQL_FN_NUM_TAN]
           // ODBC[SQL_FN_NUM][SQL_FN_NUM_TRUNCATE], not supported
        }),

        SQLGetInfo = DefaultConfig[SQLGetInfo] & [
            SQL_SQL92_PREDICATES = ODBC[SQL_SP][All],
            SQL_AGGREGATE_FUNCTIONS = ODBC[SQL_AF][All],
            SQL_NUMERIC_FUNCTIONS = SQLNumericFunctions,
            SQL_STRING_FUNCTIONS = SQLStringFunctions
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

            // Tells Power BI that it can't quietly drop the connection
            CancelQueryExplicitly = true,

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

RenameSparkCatalog = (catalogs as table) as table =>
    let
        // For DBR 8 and earlier clusters, the driver retains the legacy 'SPARK' catalog.
        // In DBR 9 and later, the name of the Hive Metastore catalog is 'hive_metastore'.
        // To provide forward compatibility, we rename 'SPARK' to 'hive_metastore'.
        defaultHiveMetastoreCatalog = "hive_metastore",
        isSparkCatalog = Table.RowCount(catalogs) = 1 and catalogs{[Name = "SPARK"]} <> null,
        renamedSparkCatalog = catalogs{[Name = "SPARK"]} & [Name = defaultHiveMetastoreCatalog],
        renamedSparkTable = Table.FromRecords({ renamedSparkCatalog }),
        navTableType = Value.Type(catalogs),
        renamedSparkNavTable = Value.ReplaceType(renamedSparkTable, navTableType),

        catalogsWithRenamedSpark = if isSparkCatalog then
                renamedSparkNavTable
            else
                catalogs
    in
        catalogsWithRenamedSpark;

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

                // ODBC connection string overrides
                {"BatchSize", type number, PositiveInteger, RenameField("RowsFetchedPerBlock")},
                {"Database", type text, EmptyTextToNull,  RenameField("Schema")},
                {"Catalog", type text, EmptyTextToNull,  RenameField("Catalog")},
                {"EnableArrow", type text, IdentityFn,  RenameField("EnableArrow")},
                {"EnableQueryResultDownload", type text, IdentityFn, RenameField("EnableQueryResultDownload") },
                {"EnableQueryResultLZ4Compression", type text, IdentityFn, RenameField("EnableQueryResultLZ4Compression")},
                {"EnableMultipleCatalogsSupport", type text, IdentityFn, RenameField("EnableMultipleCatalogsSupport") },
                {"MaxNumResultFileDownloadThreads", type text, IdentityFn, RenameField("MaxNumResultFileDownloadThreads")},
                {"MaxConsecutiveResultFileDownloadRetries", type text, IdentityFn, RenameField("MaxConsecutiveResultFileDownloadRetries")},
                {"MaxBytesPerFetchRequest", type text, IdentityFn, RenameField("MaxBytesPerFetchRequest")},
                {"EnableFetchHeartbeat", type text, IdentityFn, RenameField("EnableFetchHeartbeat")},
                {"FetchHeartbeatInterval", type text, IdentityFn, RenameField("FetchHeartbeatInterval")},
                {"RowsFetchedPerBlock", type text, IdentityFn, RenameField("RowsFetchedPerBlock")},
                {"DefaultStringColumnLength", type text, IdentityFn, RenameField("DefaultStringColumnLength")},
                {"DecimalColumnScale", type text, IdentityFn, RenameField("DecimalColumnScale")},
                {"UseNativeQuery", type text, IdentityFn, RenameField("UseNativeQuery")},
                {"SSP_spark.databricks.sql.initial.catalog.namespace", type text, IdentityFn, RenameField("SSP_spark.databricks.sql.initial.catalog.namespace")},
                {"SSP_databricks.catalog", type text, IdentityFn, RenameField("SSP_databricks.catalog")},
                {"SSP_spark.thriftserver.cloudfetch.enabled", type text, IdentityFn, RenameField("SSP_spark.thriftserver.cloudfetch.enabled")},

                // non-connectionstring fields
                {"SQL_API_SQLBINDCOL", type logical, IdentityFn, null},
                // Versioned for forward compatibility with new experimental features
                {"EnableExperimentalFlagsV1_1_0", type text, (val as text) => val = "disabled", null}

            }
        );

ExpandExperimentalFlags = (options as record) as record =>
    let
        flagDefinitions = #table(
            {"Key", "ExpandedFlags"},
            {
                {"EnableExperimentalFlagsV1_1_0", [UseNativeQuery = "0", SQL_API_SQLBINDCOL = false] }
            }
        ),

        enabledFlagsList = Table.TransformRows(flagDefinitions, each if Record.FieldOrDefault(options, [Key], false) then [ExpandedFlags] else []),
        enabledFlags = List.Accumulate(enabledFlagsList, [], (accum, flags) => accum & flags)
    in
        // flags should not override explicit settings
        enabledFlags & options;


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
        validatedOptions = Record.SelectFields(validatedWithNulls, nonNullKeys),

        validatedOptionsExpanded = ExpandExperimentalFlags(validatedOptions)
    in
        if options <> null then
            validatedOptionsExpanded
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
        OdbcErrorSqlState = OdbcError[SQLState],

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

        IsSQLStateInvalidCredential = OdbcErrorSqlState = "28000",

        HasCredentialError = IsSQLStateInvalidCredential or
            (IsThriftError and OdbcErrorCode <> 7 and OdbcErrorCode <> 14),

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

    DSRHandlers = [
        // {"protocol":"databricks-sql","address":{"host":"hostAddress","path":"sql/path"}}
        #"databricks-sql" = [
            GetDSR = (host, httpPath, optional options) =>
            {
                [protocol = "databricks-sql", address = [host = host, path = httpPath ]],
                if options = null then [] else options
            },

            GetFormula = (dsr, optional options) =>
            if options = null then
                () => Databricks.Catalogs(dsr[address][host], dsr[address][path])
            else
                () => Databricks.Catalogs(dsr[address][host], dsr[address][path], options),

            GetFriendlyName = (dsr) => "Databricks"
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
