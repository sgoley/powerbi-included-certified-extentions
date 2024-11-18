[Version="1.1.18"]
section Databricks;

TrustedAadDomains = {".azuredatabricks.net", ".databricks.azure.cn", ".databricks.azure.us"};
TrustedAWSDomains = {".databricks.com", ".databricks.us"};
TrustedOAuthDomains = {".databricks.com", ".databricks.us", ".azuredatabricks.net", ".databricks.azure.cn", ".databricks.azure.us"};
TrustedAadIssuerDomains = {"login.microsoftonline.com", "sts.windows.net", "login.chinacloudapi.cn", "sts.chinacloudapi.cn", "login.microsoftonline.us", "login.microsoftonline.de"};

//Indicates the level of SQL-92 supported by the driver.
Config_SqlConformance = 8;

DriverName = if Logical.From(Environment.FeatureSwitch("MashupFlight_UseNewSparkDriver", false)) then 
                "Simba Spark ODBC Driver New" 
             else 
                "Simba Spark ODBC Driver";

[DataSource.Kind="Databricks", Publish="Databricks.Publish"]
shared Databricks.Catalogs = Value.ReplaceType(DatabricksCatalogsImpl, AzureDatabricksType);

[DataSource.Kind="Databricks"]
shared Databricks.Contents = Value.ReplaceType(DatabricksLegacyImpl, AzureDatabricksType);

[DataSource.Kind="Databricks"]
shared Databricks.Query = Value.ReplaceType(DatabricksQueryImpl, DatabricksQueryType);

// DatabricksMultiCloud
[DataSource.Kind="DatabricksMultiCloud", Publish="DatabricksMultiCloud.Publish"]
shared DatabricksMultiCloud.Catalogs = Value.ReplaceType(DatabricksCatalogsImpl, DatabricksMultiCloudType);

[DataSource.Kind="DatabricksMultiCloud"]
shared DatabricksMultiCloud.Query = Value.ReplaceType(DatabricksQueryImpl, DatabricksQueryType);

AzureDatabricksType = DatabricksType(false);

DatabricksMultiCloudType = DatabricksType(true);

// This assumes for label `MyLabel` there is a `MultiCloudMyLabel` in the resources.resx
// loads either `MyLabel` or `MultiCloudMyLabel` from resources.resx based on i
loadString = (stringName as text, isMultiCloud as logical) => if isMultiCloud then Extension.LoadString("MultiCloud" & stringName) else Extension.LoadString(stringName);

// Wrapper function to provide additional UI customization.
DatabricksType = (isMultiCloud as logical) =>
    let
        AutomaticProxyDiscoveryFlag.Disabled = "disabled" meta [
            Documentation.Name = "AutomaticProxyDiscoveryFlag.Disabled",
            Documentation.Caption = Extension.LoadString("AutomaticProxyDiscoveryFlagDisabledLabel")
        ],
        AutomaticProxyDiscoveryFlag.Enabled = "enabled" meta [
            Documentation.Name = "AutomaticProxyDiscoveryFlag.Enabled",
            Documentation.Caption = Extension.LoadString("AutomaticProxyDiscoveryFlagEnabledLabel")
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
                optional Catalog = (type text meta [
                    Documentation.FieldCaption = Extension.LoadString("CatalogLabel"),
                    Documentation.FieldDescription = Extension.LoadString("CatalogHelp")
                ]),
                optional Database = (type text meta [
                    Documentation.FieldCaption = Extension.LoadString("DatabaseLabel"),
                    Documentation.FieldDescription = Extension.LoadString("DatabaseHelp")

                ]),
                optional EnableAutomaticProxyDiscovery = (type text meta [
                    Documentation.FieldCaption = Extension.LoadString("EnableAutomaticProxyDiscoveryFlagsLabel"),
                    Documentation.FieldDescription = Extension.LoadString("EnableAutomaticProxyDiscoveryFlagsHelp"),
                    Documentation.AllowedValues = { AutomaticProxyDiscoveryFlag.Enabled, AutomaticProxyDiscoveryFlag.Disabled }
                ])
            ] meta [
                Documentation.FieldCaption = Extension.LoadString("AdvancedOptionsLabel")
            ])
        ) as table meta [
            Documentation.Name = loadString("DataSourceName", isMultiCloud)
        ];
        
DatabricksQueryType = 
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
        optional options as (type nullable record meta [
            Documentation.FieldCaption = Extension.LoadString("AdvancedOptionsLabel")
        ])
    ) as DatabricksQueryInstanceType meta [
        Documentation.Name = Extension.LoadString("QueryDataSourceName"),
        Documentation.LongDescription = Extension.LoadString("QueryDataSourceDescription")
    ];

DatabricksQueryInstanceType = type function (
        sqlQuery as (type text meta [
            Documentation.FieldCaption = Extension.LoadString("SqlQueryLabel"),
            Documentation.FieldDescription = Extension.LoadString("SqlQueryHelp"),
            Documentation.SampleValues = { "SELECT ... FROM ... " },
            Formatting.IsMultiLine = true,
            Formatting.IsCode = true
        ])
    ) as table meta [
        Documentation.Name = Extension.LoadString("QueryDataSourceInstanceName"),
        Documentation.LongDescription = Extension.LoadString("QueryDataSourceInstanceDescription")
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
            EnableMultipleCatalogsSupport = "0",
            EnablePKFK = 0
        ]
    in
        DatabricksDataSource(host, httpPath, defaultOptions & optionsRecord);

DatabricksQueryImpl = (host as text, httpPath as text, optional options as record) as function =>
    let
        optionsRecord = if options = null then [] else options,
        defaultOptions = [
            UseNativeQuery = "1",
            EnableMultipleCatalogsSupport = "1"
        ],


        queryFn = (sqlQuery as text) => let
            nonEmptyQuery = 
                if sqlQuery = null or sqlQuery = "" then 
                    error Error.Record("DataSource.Error", Extension.LoadString("ErrorExpectedSqlString"))
                else
                    sqlQuery
            in
                DatabricksDataSource(host, httpPath, defaultOptions & optionsRecord, sqlQuery),

        typedQueryFn = Value.ReplaceType(queryFn, DatabricksQueryInstanceType)
    in 
        typedQueryFn;

DatabricksDataSource = (host as text, httpPath as text, options as record, optional sqlQuery as text) as table =>
    let
        Credential = Extension.CurrentCredential(),
        AuthenticationMode = Credential[AuthenticationKind],
        ValidatedHost = ValidateAnyHost(host),

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

        ShowSystemSchemas = if ValidatedOptions[ShowSystemSchemas]? = true then 1 else 0,

        // Trace Databricks endpoint type
        EndpointType = 
            if Text.Contains(httpPath, "sql/1.0/warehouses") or Text.Contains(httpPath, "sql/1.0/endpoints") then "DatabricksSQL"
            else if Text.Contains(httpPath, "sql/protocolv1") then "DatabricksCluster"
            else "Other",

        ConnectionString = [
            Driver = DriverName,
            Host = ValidatedHost,
            HTTPPath = Diagnostics.Trace(TraceLevel.Information, [Name="ConnectionString", Data = [], SafeData = [EndpointType=EndpointType]], httpPath),
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
            SSP_spark.sql.thriftserver.metadata.table.singleschema = Logical.ToText(HasSchema),
            ShowLocalTempSchemasInSQLTablesSchemasOnly = ShowSystemSchemas,
            ShowGlobalTempSchemasInSQLTablesSchemasOnly = ShowSystemSchemas,
            // many proxies/vpns ssl certificate do not have CRL distribution points
            AllowMissingCRLDistributionPoints = 1,
            TokenRenewLimit = 10
        ] & OptionOdbcFields,

        DefaultConfig = BuildOdbcConfig(),

        SqlCapabilitiesNativeQuery = DefaultConfig[SqlCapabilities] & [
            LimitClauseKind = LimitClauseKind.Limit,
            FractionalSecondsScale = 3,
            SupportsNumericLiterals = true,
            SupportsStringLiterals = true,
            SupportsOdbcDateLiterals = true,
            SupportsOdbcTimeLiterals = true,
            SupportsOdbcTimestampLiterals = true,
            Sql92Translation = "PassThrough",
            // Allows Limit0 as schema inference query of native query
            SupportsLimitZero = true
        ],

        SqlCapabilities = if sqlQuery = null then
            SqlCapabilitiesNativeQuery & [
            StringLiteralEscapeCharacters = { { "\", "\\" }, { "'", "\'"} }
            ]
        else
            SqlCapabilitiesNativeQuery,

        // Enable SqlBindColumn by default. Based on the test it has about 
        // 2 to 3x imporovemnt on import mode for large tables.
        SqlApiBindCol_Default = true,

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
            SQL_STRING_FUNCTIONS = SQLStringFunctions,

            // Needed for SQL_SVE_COALESCE, SQL_SVE_CASE or SQL_SVE_NULLIF
            // Improves the DAX DATE query push down to utilized COALESCE function
            SQL_SQL92_VALUE_EXPRESSIONS = 6
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

        SupportsIncrementalNavigation = Record.FieldOrDefault(ValidatedOptions, "SupportsIncrementalNavigation", true),
        EnableAutomaticProxyDiscovery = Record.FieldOrDefault(ValidatedOptions, "EnableAutomaticProxyDiscovery", false),
        CancelQueryExplicitly = Record.FieldOrDefault(ValidatedOptions, "CancelQueryExplicitly", true),

        Options = [
            // View the tables grouped by their schema names.
            HierarchicalNavigation = not HasSchema,

            SupportsIncrementalNavigation = SupportsIncrementalNavigation,

            // Controls whether your connector allows native SQL statements.
            HideNativeQuery = true,

            // Allows the M engine to select a compatible data type.
            SoftNumbers = true,

            // Allows conversion of numeric and text types to larger types.
            TolerateConcatOverflow = true,

            // Enables client-side connection pooling for the ODBC driver.
            ClientConnectionPooling = true,

            // Tells Power BI that it can't quietly drop the connection
            CancelQueryExplicitly = CancelQueryExplicitly,

            // Improves DAX DAY, MONTH, YEAR filter push down
            TryRecoverDateDiff = true,
            TryRecoverCoalesce = true,

            // Handlers for ODBC driver capabilities.
            SqlCapabilities = SqlCapabilities,
            SQLColumns = SQLColumns,
            SQLGetFunctions = SQLGetFunctions,
            SQLGetInfo = SQLGetInfo,
            OnError = OnOdbcError
        ],

        // Connection string properties used for encrypted connections.
        CommonOptions = [
            // The Databricks driver is shipped with Power BI
            UseEmbeddedDriver = true,
            CredentialConnectionString = AuthConnectionString
        ],

        ProxyOptions = if EnableAutomaticProxyDiscovery then
            let
            ProxyUriRecord = Web.DefaultProxy(host),
            ops = if Record.FieldCount(ProxyUriRecord) > 0 then
                let
                    UriRecord = Uri.Parts(ProxyUriRecord[ProxyUri]),
                    proxyOptions = [
                        UseProxy = 1,
                        ProxyHost = UriRecord[Host],
                        ProxyPort = UriRecord[Port],
                        // This option helps in providing better ssl cert related errors.
                        // 
                        // simba odbc driver even if cert revocation info is missing in the cert will do cert revocation check.
                        // this causes cert validation failure.
                        //
                        // short term solution: for now end users may need to set `CheckCertRevocation=0` manually in the config file
                        // C:\Program Files\Microsoft Power BI Desktop\bin\ODBC Drivers\Simba Spark ODBC Driver\microsoft.sparkodbc.ini
                        // long-term solution: Simba needs to change the internal behaviour of ODBC driver to avoid cert revocation check
                        // if cert revocation cert info is missing in the cert
                        AllowDetailedSSLErrorMessages = 1
                    ]
                in 
                    proxyOptions
                else []
            in
               ops 
        // if automatic proxy discovery is not enabled return nothing.
        else [],

        GetInvocation = (ast, function, count) =>
            if ast[Kind] = "Invocation" and ast[Function][Kind] = "Constant" and ast[Function][Value] = function and List.Count(ast[Arguments]) = count
                then ast[Arguments]
                else ...,
        Function = (name) => [Kind = "Function", Name=name],
        Argument = (expr) => [Expression = expr, Type = null],
        ApproxDistinctCount = (expr) => [Kind = "Invocation", Function = Function("approx_count_distinct"), Arguments = {Argument(expr)}, Type = Int64.Type],
        Struct = (exprs) => [Kind = "Invocation", Function = Function("struct"), Arguments = exprs, Type = null],
        AstOptions = [
            AstVisitor = [
                Functions = { Table.ApproximateRowCount },
                Invocation = (visitor, rowType, groupKeys, invocation) =>
                    let
                        tarc = GetInvocation(invocation, Table.ApproximateRowCount, 1),
                        td = GetInvocation(tarc{0}, Table.Distinct, 1),
                        sc = GetInvocation(td{0}, Table.SelectColumns, 2)
                    in
                        if groupKeys <> null and sc{0} = RowExpression.Row and sc{1}[Value]? is list then
                            ApproxDistinctCount(Struct(List.Transform(sc{1}[Value], (c) => Argument(visitor(RowExpression.Column(c))))))
                        else ...
            ]
        ],
        Databases = Odbc.DataSource(ConnectionString & ProxyOptions, Options & CommonOptions & AstOptions),

        Metadata = Value.Metadata(Value.Type(Databases)),

        WithSchema = if HasSchema then
            Table.SelectRows(Databases, each [Schema] = OptionOdbcFields[Schema])
        else
            Databases,

        DataSourceOrQuery = if sqlQuery = null then
            WithSchema
        else
            DatabricksQuery(ConnectionString, CommonOptions, sqlQuery)


        // TODO: Convert complex data types. Our current implementation is broken, and
        // not in a shippable state due to poor deserialization of Hive-flavored json.
        // It would require a change in the Thrift server to unblock this.
in
    DataSourceOrQuery;


DatabricksQuery = (connectionString as record, options as record, sqlQuery as text) as table =>
    let
        wrappedSqlStatement = SafeWrapQuery(sqlQuery)
    in
        Odbc.Query(connectionString, wrappedSqlStatement, options);
        

// Ensures no valid DDL/DML can be executed
SafeWrapQuery = (query as text, optional limit as number) =>
    Text.Format(QueryBase, [Query = query]);

QueryBase = 
"SELECT * 
FROM (
#[Query]
)";

RenameSparkCatalog = (catalogs as table) as table =>
    let
        // For DBR 8 and earlier clusters, the driver retains the legacy 'SPARK' catalog.
        // In DBR 9 and later, the name of the Hive Metastore catalog is 'hive_metastore'.
        // To provide forward compatibility, we rename 'SPARK' to 'hive_metastore'.
        defaultHiveMetastoreCatalog = "hive_metastore",
        isSparkCatalog = Table.RowCount(catalogs) = 1 and catalogs{[Name = "SPARK"]}? <> null,
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
                {"EnablePKFK", type number, IdentityFn, RenameField("EnablePKFK")},

                // automatic proxy discovery optional field
                {"EnableAutomaticProxyDiscovery", type text, (val as text) => val = "enabled", null},

                // non-connectionstring fields
                {"SQL_API_SQLBINDCOL", type logical, IdentityFn, null},
                {"SupportsIncrementalNavigation", type logical, IdentityFn, null},
                // show system schemas, e.g. #temp, global_temp
                {"ShowSystemSchemas", type logical, IdentityFn, null},

                {"CancelQueryExplicitly", type logical, IdentityFn, null},

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

        // When an access token expires, the connector returns a "SQLState 08006" error.
        OAuthTokenExpired = IsOdbcError and (OdbcErrorSqlState = "08006"),

        TokenExpiredError = ((IsThriftError and OdbcErrorCode = 10) or OAuthTokenExpired) and Extension.CurrentCredential(true) <> null,

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
        isTrusted = List.MatchesAny(TrustedOAuthDomains, (domain) => Text.EndsWith(parsedHost, domain))
    in
        if isTrusted then
            parsedHost
        else
            error Error.Record("Error", Text.Format(Extension.LoadString("ErrorAadInvalidDomain"), {host}));

ValidateTrustedOAuthHost = (host as text) as text =>
    let
        parsedHost = ValidateAnyHost(host),
        isTrusted = List.MatchesAny(TrustedOAuthDomains, (domain) => Text.EndsWith(parsedHost, domain))
    in
        if isTrusted then
            parsedHost
        else
            error Error.Record("Error", Text.Format(Extension.LoadString("ErrorOAuthInvalidDomain"), {host}));

GetAuthorizationUrlFromWellKnown = (url as text) as text =>
    let
        // Expecting a 302 redirect to the well-known OAuth URL.
        responseCodes = {302},
        endpointResponse = Web.Contents(url, [
            ManualCredentials = true,
            ManualStatusHandling = responseCodes
        ])
    in
        if (List.Contains(responseCodes, Value.Metadata(endpointResponse)[Response.Status]?)) then
            let
                headers = Record.FieldOrDefault(Value.Metadata(endpointResponse), "Headers", []),
                wellKnownUrl = Record.FieldOrDefault(headers, "Location", ""),
                
                // Check if the host is one of the known AAD domains
                isAadIssuerDomain = List.Contains(TrustedAadIssuerDomains, Uri.Parts(wellKnownUrl)[Host]),

                // Fetch the JSON content from the well-known URL
                wellKnownContent = Web.Contents(wellKnownUrl),
                jsonContent = Json.Document(wellKnownContent),
                
                // Extract the authorization endpoint from the JSON content
                authorizationUri = jsonContent[authorization_endpoint]

            in
                if (authorizationUri <> null) and Text.EndsWith(authorizationUri, "authorize") and isAadIssuerDomain then
                    authorizationUri
                else
                    error Error.Record("Error", "Invalid authorization endpoint.", [
                        #"Location" = wellKnownUrl
                    ])
        else
            error Error.Record("Error", "Redirect to well-known URL failed.", [
                Response.Status = Value.Metadata(endpointResponse)[Response.Status]?
            ]);


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
        UsernamePassword = [
            Label = Extension.LoadString("UsernamePasswordLabel")
        ],
        Key = [
            KeyLabel = Extension.LoadString("PersonalAccessTokenLabel"),
            Label = Extension.LoadString("PersonalAccessTokenLabel")
        ],
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
                        if IsAWSEndpoint(ValidatedHost) then
                           Text.Format("https://#{0}/oidc/custom/.well-known/openid-configuration", {ValidatedHost})
                        else if AssertHostValid and PathHasOrgId then
                            Text.Format("https://#{0}/aad/auth?o=#{1}", {ValidatedHost, OrgId})
                        else
                            Text.Format("https://#{0}/aad/auth", {ValidatedHost}),
                    
                    AuthUriResult = 
                        if IsAWSEndpoint(ValidatedHost) then
                            GetAuthorizationUrlFromWellKnown(ClusterUri)
                        else 
                             GetAuthorizationUrlFromLocation(ClusterUri)
                in
                    AuthUriResult,

            Resource = "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d",
            Label = Extension.LoadString("AzureActiveDirectoryLabel")
        ]
    ],

        // Needed for use with Power BI Service.
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            Host = json[host],
            HTTPPath = json[httpPath]
        in
            { "Databricks.Contents", Host, HTTPPath },

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

            GetFriendlyName = (dsr) => "Azure Databricks"
        ]
    ]
];

DatabricksMultiCloud = [
    Label = Extension.LoadString("MultiCloudDataSourceLabel"),
    Authentication = [
        UsernamePassword = [
            Label = Extension.LoadString("UsernamePasswordLabel")
        ],
        Key = [
            KeyLabel = Extension.LoadString("PersonalAccessTokenLabel"),
            Label = Extension.LoadString("PersonalAccessTokenLabel")
        ],
        OAuth =  [
            StartLogin = OidcStartLogin,
            FinishLogin = OidcFinishLogin,
            Refresh = OidcRefresh,
            Label = Extension.LoadString("OIDCLabel")
        ]
    ],
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            Host = json[host],
            HTTPPath = json[httpPath]
        in
            { "DatabricksMultiCloud.Catalogs", Host, HTTPPath },
    DSRHandlers = [
        // {"protocol":"databricks-multicloud","address":{"host":"hostAddress","path":"sql/path"}}
        #"databricks-multicloud" = [
            GetDSR = (host, httpPath, optional options) =>
            {
                [protocol = "databricks-multicloud", address = [host = host, path = httpPath ]],
                if options = null then [] else options
            },

            GetFormula = (dsr, optional options) =>
                if options = null then
                    () => DatabricksMultiCloud.Catalogs(dsr[address][host], dsr[address][path])
                else
                    () => DatabricksMultiCloud.Catalogs(dsr[address][host], dsr[address][path], options),

            GetFriendlyName = (dsr) => "Databricks"
        ]
    ]
];

// Azure Data Source UI publishing description.
Databricks.Publish = [
    Category = "Azure",
    SupportsDirectQuery = true,

    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },

    SourceImage = Databricks.Icons,
    SourceTypeImage = Databricks.Icons,
    
    NativeQueryProperties = [
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
                access = "Data"
            ]
        },
        
        nativeQueryOptions = [
            EnableFolding = true
        ]
    ]
];

// Multi Cloud Data Source UI publishing description.
DatabricksMultiCloud.Publish = [
    Category = "Online Services",
    SupportsDirectQuery = true,

    ButtonText = { Extension.LoadString("MultiCloudButtonTitle"), Extension.LoadString("MultiCloudButtonHelp") },

    SourceImage = Databricks.Icons,
    SourceTypeImage = Databricks.Icons,
    
    NativeQueryProperties = [
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
                access = "Data"
            ]
        },
        nativeQueryOptions = [
            EnableFolding = true
        ]
    ]
];

Databricks.Icons = [
    Icon16 = { Extension.Contents("Databricks16.png"), Extension.Contents("Databricks20.png"), Extension.Contents("Databricks24.png"), Extension.Contents("Databricks32.png") },
    Icon32 = { Extension.Contents("Databricks32.png"), Extension.Contents("Databricks40.png"), Extension.Contents("Databricks48.png"), Extension.Contents("Databricks64.png") }
];

OIDCAWSClientId = "power-bi";
OIDCAWSRedirectUri = "https://oauth.powerbi.com/views/oauthredirect.html";
OIDCAWSScopesToRequest = "sql offline_access";

IsAzureEndpoint = (host) => 
    let
        parsedHost = ValidateAnyHost(host),
        isTrustedAzureEndpoint = List.MatchesAny(TrustedAadDomains, (domain) => Text.EndsWith(parsedHost, domain))
    in
        isTrustedAzureEndpoint;
        
IsAWSEndpoint = (host) => 
    let
        parsedHost = ValidateAnyHost(host),
        isTrustedAWSEndpoint = List.MatchesAny(TrustedAWSDomains, (domain) => Text.EndsWith(parsedHost, domain))
    in
        isTrustedAWSEndpoint;

GetOIDCAppInfo = (dataSourcePath) => 
    let

        dataSource = Json.Document(dataSourcePath),
        host = ValidateTrustedOAuthHost(dataSource[host]),

        clientAppInfo = if IsAWSEndpoint(host) then 
            [ClientId = OIDCAWSClientId, RedirectUri = OIDCAWSRedirectUri, Scope = OIDCAWSScopesToRequest]

        else if IsAzureEndpoint(host) then
            error Error.Record("Datasource.Error", Text.Format(Extension.LoadString("ErrorMultiCloudOAuthOnAzureNotSupported"), {host}))
        else
            error Error.Record("Datasource.Error", Text.Format(Extension.LoadString("ErrorInvalidHost"), {host}))
    in
        clientAppInfo;

OidcGetEndpoint = (dataSourcePath) => 
    let 
        dataSource = Json.Document(dataSourcePath),
        host = ValidateTrustedOAuthHost(dataSource[host]),

        auth_endpoint = if IsAWSEndpoint(host) then 
                Text.Format("https://#{0}/oidc/v1", {host})
            else if IsAzureEndpoint(host) then
                Text.Format("https://#{0}/oidc/oauth2", {host})
            else 
                error Error.Record("Error", Text.Format(Extension.LoadString("ErrorInvalidHost"), {host}))
    in
        auth_endpoint;

OidcParseRedirect = (callbackResponse) => 
    let
        validateParts = each _,
        parts = Uri.Parts(callbackResponse)[Query],
        validatedParts = validateParts(parts)
    in 
        validatedParts;

OidcTokenRequest = (dataSourcePath, params) => 
    let
        tokenUrl = OidcGetEndpoint(dataSourcePath) & "/token",

        response = Web.Contents(
            tokenUrl, 
            [
                Content = tokenQuery,
                Headers = [
                    #"Content-type" = "application/x-www-form-urlencoded",
                    #"Accept" = "application/json"
                ]
            ]
        ),

        tokenQuery = Text.ToBinary(Uri.BuildQueryString(params)),

        token = Json.Document(response)
    in
        token;

OidcStartLogin = (clientApplication, dataSourcePath, state, display) => 
    let
        authorizeUrl = OidcGetEndpoint(dataSourcePath) & "/authorize?",
        url = authorizeUrl & oidcQuery,
        
        Base64UrlEncode = (binaryData as binary) =>
            let
                unescapedStr = Binary.ToText(binaryData, BinaryEncoding.Base64),
                // https://www.oauth.com/oauth2-servers/pkce/authorization-request/
                base64EncodedAsTextEscaped = Text.Replace(Text.Replace(Text.Replace(unescapedStr, "+", "-"), "/", "_"), "=", "")
            in
                base64EncodedAsTextEscaped,

        // Note: Crypto and CryptoAlgorithm are not publicly documented on Microsoft M language documentation
        // these APIs can only be used inside Custom Data Connectors (verified with Microsoft)
        
        // Authorization PKCE verifier
        codeVerifier = Text.NewGuid() & Text.NewGuid(),
        // Authorization PKCE challenge
        codeChallenge = Base64UrlEncode(Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(codeVerifier, TextEncoding.Ascii))),

        clientApp = GetOIDCAppInfo(dataSourcePath),
        
        redirectUri = clientApp[RedirectUri],
        clientId = clientApp[ClientId],
        scope = clientApp[Scope],
        oidcQuery = Uri.BuildQueryString([
            client_id = clientId,
            scope = scope,
            response_type = "code",
            state = state,
            code_challenge = codeChallenge,
            code_challenge_method = "S256",
            redirect_uri = redirectUri
        ])
    in
        [
            LoginUri = url,
            CallbackUri = redirectUri,
            WindowHeight = 780,
            WindowWidth = 980,
            Context = [CodeVerifier = codeVerifier, ClientApp = clientApp]
        ];

OidcFinishLogin = (clientApplication, dataSourcePath, context, callbackUri, state) => 
    let    
        parts = OidcParseRedirect(callbackUri),
        codeVerifier = context[CodeVerifier],
        clientApp = context[ClientApp],
        clientId = clientApp[ClientId],
        redirectUri = clientApp[RedirectUri],
        token = OidcTokenRequest(dataSourcePath, [
            client_id = clientId,
            grant_type = "authorization_code",
            code = parts[code],
            code_verifier = codeVerifier,
            redirect_uri = redirectUri
        ])
    in
        token;

OidcRefresh = (clientApplication, dataSourcePath, oldCredentials) =>
    let
        refreshToken = oldCredentials[refresh_token],
        clientApp = GetOIDCAppInfo(dataSourcePath),
        token = OidcTokenRequest(dataSourcePath, [
            grant_type = "refresh_token",
            client_id = clientApp[ClientId],
            refresh_token = refreshToken
        ])
    in
        token;

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
