[Version = "1.0.6"]
section AzureTrino;

// When set to true, additional trace information will be written out to the User log. 
// This should be set to false before release. Tracing is done through a call to 
// Diagnostics.LogValue(). When EnableTraceOutput is set to false, the call becomes a 
// no-op and simply returns the original value.
EnableTraceOutput = false;

// Indicates that Trino is fully conformant with SQL92
// 
// SQL_SC = 
// [
//     SQL_SC_SQL92_ENTRY            = 1,
//     SQL_SC_FIPS127_2_TRANSITIONAL = 2,
//     SQL_SC_SQL92_INTERMEDIATE     = 4,
//     SQL_SC_SQL92_FULL             = 8
// ]
Config_SqlConformance = 8;

// Auth Constants
// Note: The use of "common" in the authorization and token uri below can be replaced with a specific Tenant Guid
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
token_uri = "https://login.microsoftonline.com/common/oauth2/token";
authorize_uri = "https://login.microsoftonline.com/common/oauth2/authorize";
logout_uri = "https://login.microsoftonline.com/logout.srf";
resourceIdentifier = "https://clusteraccess.hdinsightaks.net";
resourceScope = "Cluster.ReadWrite";

TrustedDomains = {".projecthilo.net", ".hdinsightaks.net"};

[DataSource.Kind = "AzureTrino"]
shared AzureTrino.Contents = Value.ReplaceType(TrinoImplementation, TrinoType);

// Wrapper function to provide additional UI customization and documentation.
TrinoType = type function (
    host as (
        type text meta [
            Documentation.FieldCaption = Extension.LoadString("TrinoEndpointLabel"),
            Documentation.FieldDescription = Extension.LoadString("TrinoEndpointDescription"),
            Documentation.SampleValues = {Extension.LoadString("TrinoEndpointSampleValue")}
        ]
    ),
    optional options as (
        type nullable [
            optional Catalog = (
                type text meta [
                    Documentation.FieldCaption = Extension.LoadString("CatalogLabel"),
                    Documentation.FieldDescription = Extension.LoadString("CatalogHelp"),
                    Documentation.SampleValues = {Extension.LoadString("CatalogSampleValue")}
                ]
            ),
            optional Schema = (
                type text meta [
                    Documentation.FieldCaption = Extension.LoadString("SchemaLabel"),
                    Documentation.FieldDescription = Extension.LoadString("SchemaHelp"),
                    Documentation.SampleValues = {Extension.LoadString("SchemaSampleValue")}
                ]
            ),
            optional SessionProperties = (
                type text meta [
                    Documentation.FieldCaption = Extension.LoadString("SessionPropertiesLabel"),
                    Documentation.FieldDescription = Extension.LoadString("SessionPropertiesHelp"),
                    Documentation.SampleValues = {Extension.LoadString("SessionPropertiesSampleValue")}
                ]
            )
        ] meta [
            Documentation.FieldCaption = Extension.LoadString("AdvancedOptionsLabel")
        ]
    )
) as table meta [
    Documentation.Name = Extension.LoadString("TrinoConnectorLabel")
];

TrinoImplementation = (host as text, optional options as record) as table =>
    let
        ResolvedHost = if host <> null then ValidateTrustedHost(Text.Trim(host)) else error Error.Record("A Trino host must be specified"),
        Credential = Extension.CurrentCredential(),
        AuthenticationMode = Credential[AuthenticationKind],
        AuthConnectionString =
            if AuthenticationMode = "OAuth" then
                [
                    AuthenticationType = "JWT Authentication",
                    AccessToken = Credential[access_token],
                    // Require port 443
                    Port = "443",
                    // Turn on connection test because without this, PQ does not fail if the user entered the wrong URL.
                    ConnectionTest = "1",
                    // To enable ODBC driver logging add the LogPath parameter and change LogLevel to LOG_DEBUG.
                    LogLevel = "LOG_OFF"
                    //LogPath = "E:\temp"
                ]
            else
                // Should not be reachable.
                error Extension.CredentialError("DataSource.UnsupportedAuthenticationKind", "AuthConnectionString"),

        // Validate any options that have been passed (Database, BatchSize etc.)
        ValidatedOptions = ValidateAdvancedOptions(options),
        OptionOdbcFields = OdbcFieldsFromOptions(ValidatedOptions),
        HasSchema = ValidatedOptions[Database]? <> null,
        DefaultConfig = BuildOdbcConfig(),
        SqlCapabilities = DefaultConfig[SqlCapabilities]
            & [
                FractionalSecondsScale = 3,
                SupportsDerivedTable = true,
                Sql92Conformance = 8,
                GroupByCapabilities = 4,
                Sql92Translation = "PassThrough"
            ],
        
        // Functions to add missing timestamp types to the SQLGetTypeInfo table.
        CreateTimestampType = (x as number) as record => [
                    AUTO_UNIQUE_VALUE = null,
                    CASE_SENSITIVE = 0,
                    COLUMN_SIZE = 26,
                    CREATE_PARAMS = null,
                    DATA_TYPE = /* TYPE_TIMESTAMP */ 93,
                    FIXED_PREC_SCALE = 0,
                    INTERVAL_PRECISION = 0,
                    LITERAL_PREFIX = "'",
                    LITERAL_SUFFIX = "'",
                    LOCAL_TYPE_NAME = "timestamp",
                    MAXIMUM_SCALE = 38,
                    MINIMUM_SCALE = null,
                    NULLABLE = 1,
                    NUM_PREC_RADIX = null,
                    SEARCHABLE = /* SQL_SEARCHABLE */ 2,
                    SQL_DATA_TYPE = /* TIMESTAMP */ 9,
                    SQL_DATETIME_SUB = null,
                    TYPE_NAME = "timestamp(" & Number.ToText(x) & ")",
                    UNSIGNED_ATTRIBUTE = null,
                    USER_DATA_TYPE = 0
                ],
        AddMissingTimestampTypes = (base as table) as table => Table.InsertRows(
                base,
                0,
                List.Transform({0, 1, 2, 3, 4, 5, 6, 7, 8, 9}, (x) => CreateTimestampType(x))),

        // Add missing types that are not handled by the ODBC driver. 
        SQLGetTypeInfo = (types as table) as table => 
            if (EnableTraceOutput <> true) then AddMissingTimestampTypes(types) else
            let
                // Outputting the entire table might be too large, and result in the value being truncated.
                // We can output a row at a time instead with Table.TransformRows()
                rows = Table.TransformRows(types, each Diagnostics.LogValue("SQLGetTypeInfo " & _[TYPE_NAME], _)),
                toTable = Table.FromRecords(rows)
            in
                AddMissingTimestampTypes(Value.ReplaceType(toTable, Value.Type(types)))
            ,

        // Transforms TOP queries into LIMIT queries. This is required because the flag to enable limit and offset
        // in SqlCapabilities `LimitClauseKind = LimitClauseKind.LimitOffset` places offset after limit, which is
        // not supported by Trino.
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

        // Required because decimal, varchar, char can be variable length and the DATA_TYPE does not get
        // matched as it is an equality string match.
        UpdateSQLColumns = (catalogName, schemaName, tableName, columnName, source) =>
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

        // SQLColumns is a function handler that receives the results of an ODBC call
        // to SQLColumns(). The source parameter contains a table with the data type 
        // information. This override is typically used to fix up data type mismatches
        // between calls to SQLGetTypeInfo and SQLColumns. 
        //
        // For details of the format of the source table parameter, please see:
        // https://docs.microsoft.com/en-us/sql/odbc/reference/syntax/sqlcolumns-function
        //
        // The sample implementation provided here will simply output the original table
        // to the user trace log, without any modification. 
        SQLColumns = (catalogName, schemaName, tableName, columnName, source) =>
            if (EnableTraceOutput <> true) then
                UpdateSQLColumns(catalogName, schemaName, tableName, columnName, source)
            else
                // the if statement conditions will force the values to evaluated/written to diagnostics
                if (Diagnostics.LogValue("SQLColumns.TableName", tableName) <> "***" and Diagnostics.LogValue("SQLColumns.ColumnName", columnName) <> "***") then
                    let
                        // Outputting the entire table might be too large, and result in the value being truncated.
                        // We can output a row at a time instead with Table.TransformRows()
                        rows = Table.TransformRows(UpdateSQLColumns(catalogName, schemaName, tableName, columnName, source), each Diagnostics.LogValue("SQLColumns", _)),
                        toTable = Table.FromRecords(rows)
                    in
                        Value.ReplaceType(toTable, Value.Type(source))
                else UpdateSQLColumns(catalogName, schemaName, tableName, columnName, source),

        // Override the result of SQLGetInfo from the ODBC driver.
        SQLGetInfo = DefaultConfig[SQLGetInfo]
            & [
                SQL_SQL92_PREDICATES = ODBC[SQL_SP][All],
                SQL_AGGREGATE_FUNCTIONS = ODBC[SQL_AF][All],
                SQL_TIMEDATE_ADD_INTERVALS =
                    let
                        // add all functions to driver
                        driverDefault = {
                            SQL_TSI[SQL_TSI_FRAC_SECOND],
                            SQL_TSI[SQL_TSI_SECOND],
                            SQL_TSI[SQL_TSI_MINUTE],
                            SQL_TSI[SQL_TSI_HOUR],
                            SQL_TSI[SQL_TSI_DAY],
                            SQL_TSI[SQL_TSI_WEEK],
                            SQL_TSI[SQL_TSI_MONTH],
                            SQL_TSI[SQL_TSI_QUARTER],
                            SQL_TSI[SQL_TSI_YEAR]
                        }
                    in
                        Odbc.Flags(driverDefault),
            SQL_TIMEDATE_DIFF_INTERVALS = 
                   let
                        // add all functions to driver
                        driverDefault = {
                            SQL_TSI[SQL_TSI_FRAC_SECOND],
                            SQL_TSI[SQL_TSI_SECOND],
                            SQL_TSI[SQL_TSI_MINUTE],
                            SQL_TSI[SQL_TSI_HOUR],
                            SQL_TSI[SQL_TSI_DAY],
                            SQL_TSI[SQL_TSI_WEEK],
                            SQL_TSI[SQL_TSI_MONTH],
                            SQL_TSI[SQL_TSI_QUARTER],
                            SQL_TSI[SQL_TSI_YEAR]
                        }
                    in
                        Odbc.Flags(driverDefault)
            ],
        // Changes behavior of driver's SQLGetFunctions call.
        SQLGetFunctions = [
                        SQL_CONVERT_FUNCTIONS = 0x2 /* SQL_FN_CVT_CAST */,
                        SQL_API_SQLBINDPARAMETER = true
                    ],
        Options = [
            // Live queries navigation as user explores the catalogs, schemas, and tables
            // Prevents errors if catalogs are malfunctioning or number of tables is too large.
            SupportsIncrementalNavigation = false,
            HierarchicalNavigation = true,
            // Controls whether this connector allows native SQL statements to be visible in PQ UI.
            HideNativeQuery = false,
            // Allows the M engine to select a compatible data type.
            SoftNumbers = true,
            // Allows conversion of numeric and text types to larger types.
            TolerateConcatOverflow = true,
            // Enables client-side connection pooling for the ODBC driver.
            ClientConnectionPooling = true,
            // The Trino driver is shipped with Power BI Desktop, so we can use the embedded driver.
            UseEmbeddedDriver = true,
            // Handlers for ODBC driver capabilities.
            SqlCapabilities = SqlCapabilities,
            // Changes SQLGetInfo response provided by the ODBC driver.
            SQLGetInfo = SQLGetInfo,
            // Changes types provided by the ODBC driver.
            SQLGetTypeInfo = SQLGetTypeInfo,
            // Overrides columns returned by the ODBC driver (only used for logging).
            SQLColumns = SQLColumns,
            // Changes behavior of driver's SQLGetFunctions call.
            SQLGetFunctions = SQLGetFunctions,
            OnError = OnOdbcError,
            AstVisitor = AstVisitor
        ],
        // Connection string properties used for encrypted connections.
        CommonOptions = [
            CredentialConnectionString = AuthConnectionString,
            CancelQueryExplicitly = true
        ],
        
        ConnectionString = [
            // Change this DSN to the name of the local DSN amd set UseEmbeddedDriver = false to test a local driver.
            Driver = "Simba Trino ODBC Driver",
            Host = ResolvedHost,
            ConnectionTest = 1,
            APP = "AzureTrinoPowerBI",
            ApplicationName = "Azure Trino PowerBI",
            IgnoreBrokenCatalog = 1
        ] & OptionOdbcFields,
        Databases = Odbc.DataSource(ConnectionString, Options & CommonOptions),
        Metadata = Value.Metadata(Value.Type(Databases)),
        WithSchema =
            if HasSchema then
                Table.SelectRows(Databases, each [Schema] = OptionOdbcFields[Schema])
            else
                Databases
    in
        WithSchema;

// Data Source Kind description
AzureTrino = [
    Type = "Custom",
    MakeResourcePath = (host) => ValidateTrustedHost(Text.Trim(host)),
    ParseResourcePath = (resource) => {resource},
    TestConnection = (resource) => {"AzureTrino.Contents", resource},
    Authentication = [
        Aad = [
            AuthorizationUri = (a) => authorize_uri,
            Resource = resourceIdentifier,
            Scope = resourceScope
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
AzureTrino.Publish = [
    Beta = true,
    Category = "Azure",
    ButtonText = {Extension.LoadString("TrinoTableButtonTitle"), Extension.LoadString("ButtonHelp")},
    // LearnMoreUrl = Extension.LoadString("HelpUrl"),
    SourceImage = AzureTrino.Icons,
    SourceTypeImage = AzureTrino.Icons,
    SupportsDirectQuery = true,
    NativeQueryProperties = [
        navigationSteps = {
            [
                indices = {[
                    value = "Catalog",
                    indexName = "Name"
                ]},
                access = "Data"
            ]
        },
        nativeQueryOptions = [
            EnableFolding = true
        ]
    ]
];

AzureTrino.Icons = [
    Icon16 = {
        Extension.Contents("Trino16.png"),
        Extension.Contents("Trino20.png"),
        Extension.Contents("Trino24.png"),
        Extension.Contents("Trino32.png")
    },
    Icon32 = {
        Extension.Contents("Trino32.png"),
        Extension.Contents("Trino40.png"),
        Extension.Contents("Trino48.png"),
        Extension.Contents("Trino64.png")
    }
];

AdvancedOptionsValidators =
    let
        EmptyTextToNull = (text as text) => if text = "" then null else text,
        PositiveInteger = (number as number) =>
            if number > 0 then
                Int32.From(number)
            else
                error Error.Record("Expression.Error")
    in
        #table(
            {"Key", "OdbcField", "Type", "Validator"},
            {
                {"Host", "Host", type text, EmptyTextToNull},
                {"BatchSize", "RowsFetchedPerBlock", type number, PositiveInteger},
                {"Catalog", "Catalog", type text, EmptyTextToNull},
                {"Schema", "Schema", type text, EmptyTextToNull},
                {"SessionProperties", "SessionProperties", type text, EmptyTextToNull}
            }
        );

ValidateAdvancedOptions = (optional options as record) as record =>
    let
        allKeys = Table.Column(AdvancedOptionsValidators, "Key"),
        // all advanced options are assumed to be nullable
        assertType = (field as record) =>
            (v) =>
                try
                    if v = null then
                        null
                    else if Value.Is(v, field[Type]) then
                        field[Validator](v)
                    else
                        error Error.Record("Expression.Error")
                otherwise
                    error
                        Error.Record(
                            "Expression.Error",
                            Text.Format(Extension.LoadString("ErrorAdvancedOptionValue"), {v, field[Key]})
                        ),
        fieldToValidatorMap = List.Transform(Table.ToRecords(AdvancedOptionsValidators), each {[Key], assertType(_)}),
        knownFields = Record.SelectFields(options, allKeys, MissingField.Ignore),
        validatedWithNulls = Record.TransformFields(knownFields, fieldToValidatorMap, MissingField.Ignore),
        nonNullKeys = List.Select(
            Record.FieldNames(validatedWithNulls), each Record.Field(validatedWithNulls, _) <> null
        ),
        validatedOptions = Record.SelectFields(validatedWithNulls, nonNullKeys)
    in
        if options <> null then
            validatedOptions
        else
            [];

// map advanced option fields to ODBC fields
OdbcFieldsFromOptions = (options as record) as record =>
    let
        noOdbcField = Table.Column(Table.SelectRows(AdvancedOptionsValidators, each [OdbcField] = null), "Key"),
        filteredOptions = Record.RemoveFields(options, noOdbcField, MissingField.Ignore),
        fieldToOdbcMap = List.Transform(Table.ToRecords(AdvancedOptionsValidators), each {[Key], [OdbcField]}),
        withMappedFields = Record.RenameFields(filteredOptions, fieldToOdbcMap, MissingField.Ignore)
    in
        withMappedFields;

// Set to null to leave default behavior.
Config_UsePositionInsteadOfLocate = true; // true, false, null

BuildOdbcConfig = () as record =>
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
            error Error.Record("DataSource.Error", "The Trino ODBC driver is not installed on the host. Please install the appropriate driver. " & ConnectionHostPort)
        else if IsEncryptionError then
            // Report error to trigger option to fallback to unencrypted connection.
            error Extension.CredentialError(Credential.EncryptionNotSupported)
        else if IsODBCUnreachable then
            error Error.Record("DataSource.Error", "Could not connect to server. Please double check your Trino cluster host name: " & ConnectionHostPort)
        else
            error errorRecord;

// Returns a validated host name for trusted Trino domains. Throws an error if the domain is not on the approved list.
ValidateTrustedHost = (host as text) as text =>
    let
        parsedHost = ValidateAndNormalizeAnyHost(host),
        isTrusted = List.MatchesAny(TrustedDomains, (domain) => Text.EndsWith(parsedHost, domain))
    in
        if isTrusted then
            parsedHost
        else
            error Error.Record("Error", Text.Format(Extension.LoadString("ErrorInvalidDomain"), {parsedHost}));

// Returns a validated host name. Removes http prefix if provided. Throws an error if the host is not a valid URI.
ValidateAndNormalizeAnyHost = (host as text) as text =>
    if Text.StartsWith(host, "https") or Text.StartsWith(host, "http") then
        let
            parsedHost = try Uri.Parts(host)[Host] otherwise null
        in
            if parsedHost <> null then
                parsedHost
            else
                error Error.Record("Error", Text.Format(Extension.LoadString("ErrorInvalidHost"), {host}))
    else
        let
            parsedHost = try Uri.Parts("https://" & host)[Host] otherwise null
        in
            if parsedHost <> null then
                parsedHost
            else
                error Error.Record("Error", Text.Format(Extension.LoadString("ErrorInvalidHost"), {host}));

    

// Loads functions from another project file.
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name), asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// Constants
ODBC = Extension.LoadFunction("OdbcConstants.pqm");

Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = Diagnostics[LogValue];

// Expose the constants and bitfield helpers
Odbc.Flags= ODBC[Flags];
SQL_GB = ODBC[SQL_GB];
SQL_TSI= ODBC[SQL_TSI];