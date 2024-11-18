// This connector provides a SingleStore Direct Query enabled connector for use with the PowerBI Desktop Application
[Version = "1.0.9"]
section SingleStoreODBC;

// When set to true, additional trace information will be written out to the User log. 
// This should be set to false before release. Tracing is done through a call to 
// Diagnostics.LogValue(). When EnableTraceOutput is set to false, the call becomes a 
// no-op and simply returns the original value.
EnableTraceOutput = false;

/****************************
 * ODBC Driver Configuration
 ****************************/

// This was the only working ODBC driver.  We also tested against MariaDB 3.1 ODBC and MySQL 8.0 ODBC
Config_DriverName = Extension.LoadString("DriverName");
// If your driver under-reports its SQL conformance level because it does not
// support the full range of CRUD operations, but does support the ANSI SQL required
// to support the SELECT operations performed by Power Query, you can override 
// this value to report a higher conformance level. Please use one of the numeric 
// values below (i.e. 8 for SQL_SC_SQL92_FULL).
// 
// SQL_SC = 
// [
//     SQL_SC_SQL92_ENTRY            = 1,
//     SQL_SC_FIPS127_2_TRANSITIONAL = 2,
//     SQL_SC_SQL92_INTERMEDIATE     = 4,
//     SQL_SC_SQL92_FULL             = 8
// ]
//
// Set to null to determine the value from the driver.
// 
Config_SqlConformance = ODBC[SQL_SC][SQL_SC_SQL92_FULL];  // null, 1, 2, 4, 8

// Set this option to true if your ODBC supports the standard username/password 
// handling through the UN and PWD connection string parameters. If the user 
// selects UsernamePassword auth, the supplied values will be automatically
// added to the CredentialConnectionString. 
//
// If you wish to set these values yourself, or your driver requires additional
// parameters to be set, please set this option to 'false'
//
Config_DefaultUsernamePasswordHandling = true;  // true, false

// Some drivers have problems will parameter bindings and certain data types. 
// If the driver supports parameter bindings, then set this to true. 
// When set to false, parameter values will be inlined as literals into the generated SQL.
// To enable inlining for a limited number of data types, set this value
// to null and set individual flags through the SqlCapabilities record.
// 
// Set to null to determine the value from the driver. 
//
Config_UseParameterBindings = true;  // true, false, null
 
// Override this setting to force the character escape value. 
// This is typically done when you have set UseParameterBindings to false.
//
// Set to null to determine the value from the driver. 
//
Config_StringLiterateEscapeCharacters  = null; // ex. { "\" }

// Override this if the driver expects the use of CAST instead of CONVERT.
// By default, the query will be generated using ANSI SQL CONVERT syntax.
//
// Set to false or null to leave default behavior. 
//
Config_UseCastInsteadOfConvert = false; // true, false, null

// If the driver supports the TOP clause in select statements, set this to true. 
// If set to false, you MUST implement the AstVisitor for the LimitClause in the 
// main body of the code below. 
//
Config_SupportsTop = false; // true, false

// Set this to true to enable Direct Query in addition to Import mode.
//
Config_EnableDirectQuery = true;    // true, false

SingleStoreConnectorMeta = type function (
    ServerAddr as ( type text meta [
        Documentation.FieldCaption = Extension.LoadString("ServerFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("ServerFieldDescription"),
        Documentation.SampleValues = {Extension.LoadString("ServerFieldSample")}
    ]),
    Database as ( type text meta [
        Documentation.FieldCaption = Extension.LoadString("DBFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("DBFieldsDescription"),
        Documentation.SampleValues = {Extension.LoadString("DBFieldSample")}
    ]),
    optional UseSSL as (type logical meta [
        Documentation.FieldCaption = Extension.LoadString("UseSSLFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("UseSSLFieldDescription"),
        Documentation.AllowedValues = {true, false}
    ])
    ) as table meta [
        Documentation.Name = Extension.LoadString("SSObjectName"),
        Documentation.LongDescription = Extension.LoadString("SSObjectLongDescription")
    ];

SingleStoreConnectorMetaCustomSQL = type function (
    ServerAddr as ( type text meta [
        Documentation.FieldCaption = Extension.LoadString("ServerFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("ServerFieldDescription"),
        Documentation.SampleValues = {Extension.LoadString("ServerFieldSample")}
    ]),
    Database as ( type text meta [
        Documentation.FieldCaption = Extension.LoadString("DBFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("DBFieldsDescription"),
        Documentation.SampleValues = {Extension.LoadString("DBFieldSample")}
    ]),
    optional Query as (type text meta [
          Documentation.FieldCaption = Extension.LoadString("OptionsQueryFieldCaption"),
          Documentation.DefaultValue = "",
          Documentation.SampleValues = { Extension.LoadString("OptionsQueryFieldSample") },
          Documentation.FieldDescription = "",
          Formatting.IsMultiLine = true,
          Formatting.IsCode = true
    ])
    ) as table meta [
        Documentation.Name = Extension.LoadString("SSObjectName"),
        Documentation.LongDescription = Extension.LoadString("SSObjectLongDescription")
    ];

GetODBCDataSource = (Database as text, ConnectionString as record) => 
    let
        //
        // Handle credentials
        // Credentials are not persisted with the query and are set through a separate 
        // record field - CredentialConnectionString. The base Odbc.DataSource function
        // will handle UsernamePassword authentication automatically, but it is explictly
        // handled here as an example. 
        //
        Credential = Extension.CurrentCredential(),
		CredentialConnectionString =
            if Credential[AuthenticationKind]? = "UsernamePassword" then
                // set connection string parameters used for basic authentication
                [ UID = Credential[Username], PWD = Credential[Password] ]
            else if (Credential[AuthenticationKind]? = "Windows") then
                // set connection string parameters used for windows/kerberos authentication
                [ Trusted_Connection="Yes" ]
            else
                error Error.Record("Error", "Unhandled authentication kind: " & Credential[AuthenticationKind]?),

        //
        // Configuration options for the call to Odbc.DataSource
        //
        defaultConfig = BuildOdbcConfig(),

        SqlCapabilities = defaultConfig[SqlCapabilities] & [
            // place custom overrides here
            SupportsNumericLiterals = true,
            PrepareStatements = false,
            FractionalSecondsScale = 6
        ],

        // Please refer to the ODBC specification for SQLGetInfo properties and values.
        // https://github.com/Microsoft/ODBC-Specification/blob/master/Windows/inc/sqlext.h
        SQLGetInfo = defaultConfig[SQLGetInfo] & [
            // place custom overrides here
            SQL_SQL92_PREDICATES = ODBC[SQL_SP][All],
            SQL_AGGREGATE_FUNCTIONS = ODBC[SQL_AF][All]
        ],

        // SQLGetTypeInfo can be specified in two ways:
        // 1. A #table() value that returns the same type information as an ODBC
        //    call to SQLGetTypeInfo.
        // 2. A function that accepts a table argument, and returns a table. The 
        //    argument will contain the original results of the ODBC call to SQLGetTypeInfo.
        //    Your function implementation can modify/add to this table.
        //
        // For details of the format of the types table parameter and expected return value,
        // please see: https://docs.microsoft.com/en-us/sql/odbc/reference/syntax/sqlgettypeinfo-function
        //
        // The sample implementation provided here will simply output the original table
        // to the user trace log, without any modification. 
        SQLGetTypeInfo = (types) => 
            let
                original =
                    if (EnableTraceOutput <> true) then
                        types 
                    else
                        let 
                            // Outputting the entire table might be too large, and result in the value being truncated.
                            // We can output a row at a time instead with Table.TransformRows()
                            rows = Table.TransformRows(types, each Diagnostics.LogValue("SQLGetTypeInfo " & _[TYPE_NAME], _)),
                            toTable = Table.FromRecords(rows)
                        in
                            toTable
            in
                original,


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
        let
            MaxCharLength = 65535,
            CharOctetLength = 3,
            typeNeedsFix = (t) =>
                if (t = "json" or t = "geographypoint" or t = "geography") then
                    true
                else false,
            getRenamedType = (t) => 
                let 
                    unsigned = Text.Contains(t, "unsigned"),
                    typeShortened = List.First(Text.SplitAny(t, "( ")),
                    resultType = if unsigned then Text.Combine({typeShortened, "unsigned"}, " ") else typeShortened
                in 
                    resultType,

            transformRow = (row) => 
               let
                   rowFixedTypeName = Record.TransformFields(row, {{"TYPE_NAME", (value) as text => getRenamedType(value)}}),
                   rowFixedSizes = if(typeNeedsFix(rowFixedTypeName[TYPE_NAME])) then 
                       Record.TransformFields(rowFixedTypeName, {
                           {"COLUMN_SIZE", (value) => MaxCharLength},
                           {"BUFFER_LENGTH", (value) => MaxCharLength * CharOctetLength + 1}, // Terminal symbol
                           {"CHAR_OCTET_LENGTH", (value) => CharOctetLength}
                       }) else rowFixedTypeName
                in 
                    rowFixedSizes,
            Transform = Value.ReplaceType(Table.FromRecords(Table.TransformRows(source, (row) as record => transformRow(row))), Value.Type(source))
        in
            if (EnableTraceOutput <> true) then Transform else
            // the if statement conditions will force the values to evaluated/written to diagnostics
            if (Diagnostics.LogValue("SQLColumns.TableName", tableName) <> "***" and Diagnostics.LogValue("SQLColumns.ColumnName", columnName) <> "***") then
                let
                    // Outputting the entire table might be too large, and result in the value being truncated.
                    // We can output a row at a time instead with Table.TransformRows()
                    rows = Table.TransformRows(Transform, each Diagnostics.LogValue("SQLColumns", _)),
                    toTable = Table.FromRecords(rows)
                in
                    Value.ReplaceType(toTable, Value.Type(Transform))
            else    
                Transform,

        // This record allows you to customize the generated SQL for certain
        // operations. The most common usage is to define syntax for LIMIT/OFFSET operators 
        // when TOP is not supported. 
        // 
        // Although this implements LIMIT, OFFSET, PowerBI does not support folding for non TOP clauses
        AstVisitor = [
            LimitClause = (skip, take) =>
                let
                    offset = if (skip <> null and skip > 0) then Text.Format("OFFSET #{0}", {skip}) else "",
                    limit = if (take <> null) then Text.Format("LIMIT #{0}", {take}) else ""
                in
                    [
                        Text = Text.Format("#{0} #{1}", {limit, offset}),
                        Location = "AfterQuerySpecification"
                    ]
        ],

        OdbcDatasource = Odbc.DataSource(ConnectionString, [
            // A logical (true/false) that sets whether to view the tables grouped by their schema names
            HierarchicalNavigation = true, 
            // Prevents execution of native SQL statements. Extensions should set this to true.
            HideNativeQuery = false,
            // Allows upconversion of numeric types
            SoftNumbers = true,
            // Allow upconversion / resizing of numeric and string types
            TolerateConcatOverflow = true,
            // Enables connection pooling via the system ODBC manager
            ClientConnectionPooling = true,
            // Allows the engine to attempt a call of the ODBC Driver's SQLCancel function
            CancelQueryExplicitly = true,

            //ImplicitTypeConversions = ImplicitTypeConversions,

            // These values should be set by previous steps
            CredentialConnectionString = CredentialConnectionString,
            AstVisitor = AstVisitor,
            SqlCapabilities = SqlCapabilities,
            SQLColumns = SQLColumns,
            SQLGetInfo = SQLGetInfo,
            SQLGetTypeInfo = SQLGetTypeInfo
        ]){[Name=Database]}[Data]
    in
        OdbcDatasource;


SingleStoreConnectorImpl = (ServerAddr as text, Database as nullable text, optional UseSSL as logical) =>
    let
        //
        // Connection string settings
        //
        BaseConnectionString =
                [
                    Driver = Config_DriverName,
                    Database = Database,
                    ApplicationIntent = "readonly",
                    APP = "SingleStore Power BI Direct Query Connector",
                    no_ssps=1,
                    NO_CACHE=1
                ],
        ConnectionString = AddServerAndPort(BaseConnectionString, ServerAddr),
        UseSSL = if UseSSL = null then false else UseSSL,
        ConnectionStringWithSSL = 
            if UseSSL then 
                Record.AddField(ConnectionString, "SslVerify", 1) 
            else 
                ConnectionString,
        OdbcDataSource = GetODBCDataSource(Database, ConnectionStringWithSSL)
    in
        OdbcDataSource;
        

SingleStoreConnectorImplCustomSQL = (ServerAddr as text, Database as nullable text, optional Query as text) =>
    let
        //
        // Connection string settings
        //
        BaseConnectionString =
                [
                    Driver = Config_DriverName,
                    Database = Database,
                    ApplicationIntent = "readonly",
                    APP = "SingleStore Power BI Custom SQL Query Connector",
                    no_ssps=1,
                    NO_CACHE=1
                ],

        ConnectionString = AddServerAndPort(BaseConnectionString, ServerAddr),
        OdbcDataSource =  if Query <> null  then Odbc.Query(ConnectionString, Query) else GetODBCDataSource(Database, ConnectionString)
    in
        OdbcDataSource;


[DataSource.Kind="SingleStoreODBC", Publish="SingleStoreODBC.Publish"]
shared SingleStoreODBC.DataSource = Value.ReplaceType(SingleStoreConnectorImpl, SingleStoreConnectorMeta);
// Export SingleStoreODBC.Database to ensure compatibility for reports created via older versions of connector
[DataSource.Kind="SingleStoreODBC"]
shared SingleStoreODBC.Database = Value.ReplaceType(SingleStoreConnectorImpl, SingleStoreConnectorMeta);

[DataSource.Kind="SingleStoreODBC"]
shared SingleStoreODBC.Query = Value.ReplaceType(SingleStoreConnectorImplCustomSQL, SingleStoreConnectorMetaCustomSQL);

AddServerAndPort = (baseString as record, serverAddr as text) as record =>
    let
        Address = Splitter.SplitTextByDelimiter(":")(serverAddr),
        Host = Address{0},
        PortRaw = if List.Count(Address) > 1 then Address{1} else ""
    in
        if List.Count(Address) > 2 or Host = ""
        then 
            error "Invalid server address provided"
        else 
            let
                connStringHost = Record.AddField(baseString, "Server", Host)
            in
                if PortRaw = ""
                then 
                    Record.AddField(connStringHost, "Port", 3306)
                else
                    let
                        Port = Int32.From(PortRaw)
                    in
                        if Port = null
                        then 
                            error "Invalid port value provided"
                        else
                            Record.AddField(connStringHost, "Port", Port);  
            
// Data Source Kind description
SingleStoreODBC = [
    // Set the TestConnection handler to enable gateway support.
    // The TestConnection handler will invoke your data source function to 
    // validate the credentials the user has provider. Ideally, this is not 
    // an expensive operation to perform. By default, the dataSourcePath value 
    // will be a json string containing the required parameters of your data  
    // source function. These should be parsed and parsed as individual parameters
    // to the specified data source function.
    TestConnection = (dataSourcePath) => 
        let
            json = Json.Document(dataSourcePath),
            server = json[ServerAddr],
            db = json[Database]
        in
            { "SingleStoreODBC.Database", server, db },
    // Set supported types of authentication
    Authentication = [
        Windows = [],
        UsernamePassword = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
SingleStoreODBC.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://docs.singlestore.com/db/v7.8/en/query-data/connect-with-analytics-and-bi-tools/connect-with-power-bi.html",

    SupportsDirectQuery = Config_EnableDirectQuery,

    SourceImage = SingleStoreODBC.Icons,
    SourceTypeImage = SingleStoreODBC.Icons
];

SingleStoreODBC.Icons = [
    Icon16 = { Extension.Contents("SingleStore16.png"), Extension.Contents("SingleStore20.png"), Extension.Contents("SingleStore24.png"), Extension.Contents("SingleStore32.png") },
    Icon32 = { Extension.Contents("SingleStore32.png"), Extension.Contents("SingleStore40.png"), Extension.Contents("SingleStore48.png"), Extension.Contents("SingleStore64.png") }
];

// build settings based on configuration variables
BuildOdbcConfig = () as record =>
    let        
        defaultConfig = [
            SqlCapabilities = [],
            SQLGetFunctions = [],
            SQLGetInfo = []
        ],

        withParams =
            if (Config_UseParameterBindings = false) then
                let 
                    caps = defaultConfig[SqlCapabilities] & [ 
                        SqlCapabilities = [
                            SupportsNumericLiterals = true,
                            SupportsStringLiterals = true,                
                            SupportsOdbcDateLiterals = true,
                            SupportsOdbcTimeLiterals = true,
                            SupportsOdbcTimestampLiterals = true
                        ]
                    ],
                    funcs = defaultConfig[SQLGetFunctions] & [
                        SQLGetFunctions = [
                            SQL_API_SQLBINDPARAMETER = false
                        ]
                    ]
                in
                    defaultConfig & caps & funcs
            else
                defaultConfig,
                
        withEscape = 
            if (Config_StringLiterateEscapeCharacters <> null) then 
                let
                    caps = withParams[SqlCapabilities] & [ 
                        SqlCapabilities = [
                            StringLiteralEscapeCharacters = Config_StringLiterateEscapeCharacters
                        ]
                    ]
                in
                    withParams & caps
            else
                withParams,

        withTop =
            let
                caps = withEscape[SqlCapabilities] & [ 
                    SqlCapabilities = [
                        SupportsTop = Config_SupportsTop
                    ]
                ]
            in
                withEscape & caps,

        withCastOrConvert = withTop,

        withSqlConformance =
            if (Config_SqlConformance <> null) then
                let
                    caps = withCastOrConvert[SQLGetInfo] & [
                        SQLGetInfo = [
                            SQL_SQL_CONFORMANCE = Config_SqlConformance
                        ]
                    ]
                in
                    withCastOrConvert & caps
            else
                withCastOrConvert
    in
        withSqlConformance;

// 
// Load common library functions
// 
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = if (EnableTraceOutput) then Diagnostics[LogValue] else (prefix, value) => value;

// OdbcConstants contains numeric constants from the ODBC header files, and a 
// helper function to create bitfield values.
ODBC = Extension.LoadFunction("OdbcConstants.pqm");
Odbc.Flags = ODBC[Flags];


