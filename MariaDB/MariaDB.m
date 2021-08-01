// This file contains your Data Connector logic
[Version = "1.0.4"] // https://docs.microsoft.com/en-us/power-query/handlingversioning
section MariaDB;

// When set to true, additional trace information will be written out to the User log. 
// This should be set to false before release. Tracing is done through a call to 
// Diagnostics.LogValue(). When EnableTraceOutput is set to false, the call becomes a 
// no-op and simply returns the original value.
EnableTraceOutput = false;
// When false enables the 'View Native Query' context menu item on a query step in Power BI Desktop Query Editor.
// By default viewing native queries is enabled when tracing is enabled.
// MS samples say: 'Extensions should set this to true.'
// https://github.com/microsoft/DataConnectors/blob/master/samples/ODBC/SqlODBC/SqlODBC.pq
Config_HideNativeQuery = not EnableTraceOutput;

DefaultPort = 3306;

[DataSource.Kind="MariaDB", Publish="MariaDB.Publish"]
shared MariaDB.Contents = Value.ReplaceType(MariaDBDatabaseImplOdbc, MariaDBDatabaseType);

// The server parameter has a full name to overcome the limitation of the Data Source Settings dialog in Power BI Desktop:
/*
Note: We currently recommend you do not include a Label for your data source if your function has required parameters, 
as users will not be able to distinguish between the different credentials they have entered. We are hoping to improve this 
in the future (i.e. allowing data connectors to display their own custom data source paths).
Source: https://github.com/Microsoft/DataConnectors/blob/master/docs/m-extensions.md#data-source-path-format
*/
MariaDBDatabaseType = type function (
    #"MariaDB Data Source" as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("GetData_Server_FieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("GetData_Server_FieldDescription"),        
        Documentation.SampleValues = {"servername:portnumber;databasename"}
    ]),
    optional database as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("GetData_Database_FieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("GetData_Database_FieldDescription"),
        Documentation.SampleValues = {"databasename"}
    ]))
    as table meta [
        Documentation.Name = Extension.LoadString("GetData_Title"),
        Documentation.LongDescription = "<p>Returns a navigation table.</p>
        <ul>
        <li>Without a <code>databasename</code>, returns a table of databases on the specified MariaDB server <code>servername</code>.
        <li>With a <code>databasename</code>, returns or a table of tables and views from the specified MariaDB database <code>databasename</code> on the server <code>servername</code>.
        </ul>
        
        <p><code>databasename</code> can be provided in either of the input parameters:</p>
        <ul>
        <li>In the <b>MariaDB Data Source</b> string after a semicolon. This approach allows using database-specific credentials. See details below.
        <li>As the optional <b>Database</b> parameter. This approach allows using same credentials for all databases on the specified server <code>servername</code>.
        </ul>
        <p>The <b>MariaDB Data Source</b> string uniquely identifies a data source in Power BI and allows using different credentials for each data source.
        Credentials for a data source are configured in Power BI <i>Data source settings</i> screen. 
        MariaDB Power BI connector supports Basic authentication per server or per database.
        E.g. it is possible to connect with different credentials to databases residing on the same MariaDB server.</p>",
        Documentation.Examples = {[
            Description = "Returns a table of MariaDB tables and views functions from the MariaDB database <code>databasename</code> on server <code>servername</code>.",
            Code = "MariaDB.Contents(""servername"", ""databasename"")",
            Result = "#table({""Name"", ""Description"", ""Data"", ""Kind""}, {
       {""airlines"", null, #table(...), ""Table""},
       {""airports"", null, #table(...), ""Table""},
       {""flights"", null, #table(...), ""Table""}
       })"
        ],[
            Description = Text.Format("Returns a table of databases on the specified MariaDB server using the default port #{0} to connect. Equivalent to <code>MariaDB.Contents(""servername:#{0}"")</code>.", {DefaultPort}),
            Code = "MariaDB.Contents(""servername"")",
            Result = "#table({""Name"", ""Description"", ""Data"", ""Kind""}, {
       {""mysql"", null, #table(...), ""Database""},
       {""flights"", null, #table(...), ""Database""}
       })"
        ],[
            Description = "Returns a table of databases on the specified MariaDB server <code>servername</code> using the provided port number <code>portnumber</code> to connect.",
            Code = "MariaDB.Contents(""servername:portnumber"")",
            Result = "#table({""Name"", ""Description"", ""Data"", ""Kind""}, {
       {""mysql"", null, #table(...), ""Database""},
       {""flights"", null, #table(...), ""Database""}
       })"
        ],[
            Description = "Returns a table of MariaDB tables and views from the MariaDB database <code>databasename</code> on server <code>servername</code>. 
            The result is similar to <code>MariaDB.Contents(""servername"", ""databasename"")</code>, but the string <code>servername;databasename</code> identifies a unique data source and allows using dedicated credentials for the database <code>databasename</code>.",
            Code = "MariaDB.Contents(""servername;databasename"")",
            Result = "#table({""Name"", ""Description"", ""Data"", ""Kind""}, {
       {""airlines"", null, #table(...), ""Table""},
       {""airports"", null, #table(...), ""Table""},
       {""flights"", null, #table(...), ""Table""}
       })"
        ]}
    ];

MariaDBDatabaseImplOdbc = (server as text, optional db as text) as table =>
    let
        Address = GetAddress(server),
        ServerHost = Address[Host],
        ServerPort = Address[Port],
        ServerDatabase = Address[Database],
        database = if db <> null and db <> "" then db else ServerDatabase,
        // Get the current credential, and check what type of authentication we're using
        Credential = Extension.CurrentCredential(),
        CredentialRecord = if (Credential[AuthenticationKind]?) = "UsernamePassword" then 
                [ UID = Credential[Username], PWD = Credential[Password] ]
            // unknown authentication kind - return an error
            else
                error Extension.LoadString("Error_CredentialsRequired"), 
        
        // This logic is for data sources that optional SSL/encrypted connections.
        // When SupportsEncryption is set to true on the data source kind record,
        // Power Query will try to connect using SSL. If that fails, the connector
        // should return Extension.CredentialError(Credential.EncryptionNotSupported)
        // to indicate that encryption isn't enabled for this source. If the user then
        // chooses to establish an unencrypted connection, Credential[EncryptConnection]
        // will be set to false on the subsequent connection attempt.
        EncryptConnection = Credential[EncryptConnection]?,
        SSLRecord =
            if EncryptConnection = true then
                [FORCETLS = 1]
            else
                [FORCETLS = 0],
        CredentialConnectionString = Record.Combine({CredentialRecord, SSLRecord}),

        ConnectionString = Record.Combine({
            [Driver = ODBCDriver,
            Server = ServerHost, 
            Port = ServerPort,
            ApplicationIntent = "readonly"],
            if database <> null then [Database = database] else []
        }),

        //
        // Configuration options for the call to Odbc.DataSource
        //
        implicitTypeConversions = Diagnostics.LogValue("ImplicitTypeConversions", ImplicitTypeConversions),

        defaultConfig = Diagnostics.LogValue("BuildOdbcConfig", BuildOdbcConfig()),

        SqlCapabilities = Diagnostics.LogValue("SqlCapabilities_Options", defaultConfig[SqlCapabilities] & [
            // place custom overrides here
            SupportsTop = false,
            // SQL_GB_NO_RELATION: See MariaDB ODBC Connector 3.1.7 ma_connection.c:1336
            GroupByCapabilities = ODBC[SQL_GB][SQL_GB_NO_RELATION] /* SQL_GB_NO_RELATION (3) */,
            FractionalSecondsScale = 3
        ]),

        // Please refer to the ODBC specification for SQLGetInfo properties and values.
        // https://github.com/Microsoft/ODBC-Specification/blob/master/Windows/inc/sqlext.h
        SQLGetInfo = Diagnostics.LogValue("SQLGetInfo_Options", defaultConfig[SQLGetInfo] & [
            // place custom overrides here
            // SQL_SQL92_PREDICATES: See MariaDB ODBC Connector 3.1.7 ma_connection.c:1610
            SQL_SQL92_PREDICATES = 
                Number.BitwiseOr(ODBC[SQL_SP][SQL_SP_BETWEEN],
                Number.BitwiseOr(ODBC[SQL_SP][SQL_SP_COMPARISON],
                Number.BitwiseOr(ODBC[SQL_SP][SQL_SP_EXISTS],
                Number.BitwiseOr(ODBC[SQL_SP][SQL_SP_IN],
                Number.BitwiseOr(ODBC[SQL_SP][SQL_SP_ISNOTNULL],
                Number.BitwiseOr(ODBC[SQL_SP][SQL_SP_ISNULL],
                Number.BitwiseOr(ODBC[SQL_SP][SQL_SP_LIKE], 
                ODBC[SQL_SP][SQL_SP_QUANTIFIED_COMPARISON]))))))),
            // SQL_AGGREGATE_FUNCTIONS: See MariaDB ODBC Connector 3.1.7 ma_connection.c:976
            SQL_AGGREGATE_FUNCTIONS = 
                Number.BitwiseOr(ODBC[SQL_AF][SQL_AF_ALL],
                Number.BitwiseOr(ODBC[SQL_AF][SQL_AF_AVG],
                Number.BitwiseOr(ODBC[SQL_AF][SQL_AF_COUNT],
                Number.BitwiseOr(ODBC[SQL_AF][SQL_AF_DISTINCT],
                Number.BitwiseOr(ODBC[SQL_AF][SQL_AF_MAX],
                Number.BitwiseOr(ODBC[SQL_AF][SQL_AF_MIN],
                ODBC[SQL_AF][SQL_AF_SUM]))))))
        ]),

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
            // Do not report BIGINT as a supported data type to Power BI to avoid the driver error:
            // ERROR 1064 (42000): You have an error in your SQL syntax; check the manual that corresponds to your MariaDB server version for the right syntax to use near 'bigint)' at line 1
            // Root cause: Power BI Mashup Engine translates M data type Int64 to SQL data type BIGINT, however CAST and CONVERT function implementations in MariaDB support a limited set of data types and BIGINT is not on this list.
            // Related MariaDB issue: https://jira.mariadb.org/browse/MDEV-17686
            // Connector issue: https://github.com/mariadb-corporation/mariadb-powerbi/issues/4
            let typesFiltered = Table.SelectRows(types, each not Text.Contains(_[TYPE_NAME], "BIGINT"))
            in
            if (EnableTraceOutput <> true) then typesFiltered else
            let
                // Outputting the entire table might be too large, and result in the value being truncated.
                // We can output a row at a time instead with Table.TransformRows()
                rows = Table.TransformRows(typesFiltered, each Diagnostics.LogValue("SQLGetTypeInfo " & _[TYPE_NAME], _)),
                toTable = Table.FromRecords(rows)
            in
                Value.ReplaceType(toTable, Value.Type(typesFiltered)),                

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
                OdbcSqlType.WVARCHAR = -9,
                OdbcSqlType.REAL = 7,
                OdbcSqlType.DOUBLE = 8,

                FixColumns = (row) as record =>
                    if row[TYPE_NAME] = "ENUM" then
                        Record.TransformFields(row, {
                            { "DATA_TYPE", (val) => OdbcSqlType.WVARCHAR },
                            { "TYPE_NAME", (val) => "VARCHAR" }
                            })
                    else if row[DATA_TYPE] = OdbcSqlType.REAL then
                        Record.TransformFields(row, {
                            { "DATA_TYPE", (val) => OdbcSqlType.DOUBLE },
                            { "TYPE_NAME", (val) => "DOUBLE" }
                            })
                    else
                        row,
                TransformedRows = Table.TransformRows(source, each FixColumns(_)), // column data types info is lost here
                EmptyTableWithColumnTypes = Table.FirstN(source, 0), // get an empty table with the original column data types
                Transform = Table.InsertRows(EmptyTableWithColumnTypes, 0, TransformedRows)
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

        OdbcDataSource = Odbc.DataSource(ConnectionString, [
            // A logical (true/false) that sets whether to view the tables grouped by their schema names
            HierarchicalNavigation = true, 
            // Prevents execution of native SQL statements. Extensions should set this to true.
            HideNativeQuery = Config_HideNativeQuery,
            // Allows upconversion of numeric types
            SoftNumbers = true,
            // Allow upconversion / resizing of numeric and string types
            TolerateConcatOverflow = true,
            // Enables connection pooling via the system ODBC manager
            ClientConnectionPooling = true,
            
            ImplicitTypeConversions = implicitTypeConversions,
            OnError = OnError,

            // These values should be set by previous steps
            CredentialConnectionString = CredentialConnectionString,
            SqlCapabilities = SqlCapabilities,
            SQLColumns = SQLColumns,
            SQLGetTypeInfo = SQLGetTypeInfo,
            SQLGetInfo = SQLGetInfo
        ]),
        Filtered = if database <> null then OdbcDataSource{[Name = database]}[Data] else OdbcDataSource
    in
        Filtered;

// Data Source Kind description
MariaDB = [
    SupportsEncryption = true,
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            server = json[#"MariaDB Data Source"]
        in
            { "MariaDB.Contents", server},
    Authentication = [
        UsernamePassword = []
    ]//,
    // Label not in use following Microsoft recommendation (also see the "MariaDBDatabaseImplOdbc" note above):
    // https://github.com/Microsoft/DataConnectors/blob/master/docs/m-extensions.md#data-source-path-format
    //Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
MariaDB.Publish = [
    Beta = false,
    SupportsDirectQuery = true,     // enables direct query
    Category = "Database",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = MariaDB.Icons,
    SourceTypeImage = MariaDB.Icons
];

MariaDB.Icons = [
    Icon16 = { Extension.Contents("MariaDB16.png"), Extension.Contents("MariaDB20.png"), Extension.Contents("MariaDB24.png"), Extension.Contents("MariaDB32.png") },
    Icon32 = { Extension.Contents("MariaDB32.png"), Extension.Contents("MariaDB40.png"), Extension.Contents("MariaDB48.png"), Extension.Contents("MariaDB64.png") }
];

GetAddress = (MariaDBServer as text) as record =>
    let
        list = Text.Split(MariaDBServer, ";"),
        server = List.First(list),
        database = if List.Count(list) > 1 then List.Last(List.FirstN(list, 2)) else null,
        Address = Uri.Parts("http://" & server),
        BadServer = Address[Host] = "" or Address[Scheme] <> "http" or Address[Path] <> "/" or Address[Query] <> [] or Address[Fragment] <> ""
            or Address[UserName] <> "" or Address[Password] <> "",
        Port = if Address[Port] = 80 and not Text.EndsWith(server, ":80") then 
                DefaultPort 
            else Address[Port],
        Host = Address[Host],
        Result = [Host=Host, Port=Port, Database=database]
    in
        if BadServer then 
            error Extension.LoadString("Error_BadServer")
        else Result;

OnError = (errorRecord as record) =>
    let
        OdbcError = errorRecord[Detail][OdbcErrors]{0},
        OdbcErrorMessage = OdbcError[Message],
        OdbcErrorCode = OdbcError[NativeError],
        HasCredentialError = errorRecord[Detail] <> null
            and errorRecord[Detail][OdbcErrors]? <> null
            //and Text.Contains(OdbcErrorMessage, "[ThriftExtension]")
            and OdbcErrorCode <> 0 and OdbcErrorCode <> 7,
        IsSSLError = OdbcErrorCode = 6
    in
        if HasCredentialError then
            if IsSSLError then 
                error Extension.CredentialError(Credential.EncryptionNotSupported)
            else 
                error Extension.CredentialError(Credential.AccessDenied, OdbcErrorMessage)
        else 
            error errorRecord;

// ODBC helpers
ODBCDriver = "MariaDB ODBC 3.1 Driver";

// OdbcConstants contains numeric constants from the ODBC header files, and a 
// helper function to create bitfield values.
ODBC = Extension.LoadFunction("OdbcConstants.pqm");

/****************************
 * ODBC Driver Configuration
 ****************************/

// If the driver under-reports its SQL conformance level because it does not
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
// SQL_SC_SQL92_INTERMEDIATE value was originially derived from MariaDB ODBC Connector 3.1.7 sources ma_connection.c:1584
// However, during Connecto Certification testing it was found that SQL_SC_SQL92_FULL conformance was required by the Mashup Engine to support joins (JOIN).
// The SQL92_FULL requirement comes from Microsoft.Mashup.Engine1.Library.Odbc.OdbcQuery.PushDownQuerySpecification(bool liftOrderBy) 
// where a FoldingFailureException is thrown if DataSource.Info.SupportsDerivedTable == false.
// Respectively, the property definition in the Mashup Engine was: public virtual bool SupportsDerivedTable => Supports(Odbc32.SQL_SC.SQL_SC_SQL92_FULL);
// Thus, here SQL92 conformance is reported higher (FULL) than the ODBC driver actually supports or at least reports (INTERMEDIATE).
Config_SqlConformance = ODBC[SQL_SC][SQL_SC_SQL92_FULL];  // null, 1, 2, 4, 8

// This setting controls row count limits and offsets. If not set correctly, query
// folding capabilities for this connector will be extremely limited. You can use
// the LimitClauseKind constants to match common LIMIT/OFFSET SQL formats. If none
// of the common formats match your desired SQL syntax, set LimitClauseKind to
// LimitClauseKind.None and use the AstVisitor code below (commented out) to
// generate a custom format.
//
// LimitClauseKind values and formats: 
//
// LimitClauseKind.Top (LIMIT only, OFFSET not supported)
// -------------------
// SELECT TOP 100 *
// FROM table
//
// LimitClauseKind.Limit (LIMIT only, OFFSET not supported)
// ---------------------
// SELECT * 
// FROM table
// LIMIT 100
//
// LimitClauseKind.LimitOffset
// ---------------------------
// SELECT *
// FROM table
// LIMIT 100 OFFSET 200
//
// LimitClauseKind.AnsiSql2008
// ---------------------------
// SELECT *
// FROM table
// OFFSET 200 ROWS
// FETCH FIRST 100 ROWS ONLY
//
// MariaDB: https://mariadb.com/kb/en/limit/
Config_LimitClauseKind = LimitClauseKind.LimitOffset;

// Set this option to true if your ODBC supports the standard username/password 
// handling through the UID and PWD connection string parameters. If the user 
// selects UsernamePassword auth, the supplied values will be automatically
// added to the CredentialConnectionString. 
//
// If you wish to set these values yourself, or your driver requires additional
// parameters to be set, please set this option to 'false'
//
// MariaDB: set to 'false', because if encryption is enabled for the connection 
// then CredentialConnectionString shall contain the additional parameter FORCETLS.
Config_DefaultUsernamePasswordHandling = false;  // true, false

// Some drivers have problems with parameter bindings and certain data types. 
// If the driver supports parameter bindings, then set this to true. 
// When set to false, parameter values will be inlined as literals into the generated SQL.
// To enable inlining for a limited number of data types, set this value
// to null and set individual flags through the SqlCapabilities record.
// 
// Set to null to determine the value from the driver. 
//
// See MariaDB ODBC Connector 3.1.7 ma_connection.c:91
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
// Set to null to leave default behavior.
//
// MariaDB ODBC Connector 3.1.7 ma_connection.c:1132 returns 0 for SQL_CONVERT_FUNCTIONS, which means neither function is supported.
// MariaDB supports both CONVERT (ANSI SQL92 and ODBC variants) and CAST.
// Here it forces to use CAST to avoid the runtime exception with CONVERT:
// check the manual that corresponds to your MariaDB server version for the right syntax to use near 'SQL_DOUBLE) } = ? and `day` is not null
// Source SQL: select * from flights where { fn convert(`day`, SQL_DOUBLE) } = ? and `day` is not null
// Related MariaDB ODBC Connector issue: https://jira.mariadb.org/browse/ODBC-186
// Result SQL statement with CAST works fine, e.g.: select * from flights where cast(`day` as DOUBLE) = ? and `day` is not null
Config_UseCastInsteadOfConvert = true; // true, false, null
// build settings based on configuration variables

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

        withParams =
            if (Config_UseParameterBindings = false) then
                let 
                    caps = [
                        SupportsNumericLiterals = true,
                        SupportsStringLiterals = true,
                        SupportsOdbcDateLiterals = true,
                        SupportsOdbcTimeLiterals = true,
                        SupportsOdbcTimestampLiterals = true
                    ],
                    funcs = [
                        SQL_API_SQLBINDPARAMETER = false
                    ]
                in
                    Merge(defaultConfig, caps, funcs)
            else
                defaultConfig,
                
        withEscape = 
            if (Config_StringLiterateEscapeCharacters <> null) then 
                let
                    caps = [
                        StringLiteralEscapeCharacters = Config_StringLiterateEscapeCharacters
                    ]
                in
                    Merge(withParams, caps)
            else
                withParams,

        withLimitClauseKind = 
            let
                caps = [ 
                    LimitClauseKind = Config_LimitClauseKind
                ]
            in
                Merge(withEscape, caps),

        withCastOrConvert = 
            if (Config_UseCastInsteadOfConvert <> null) then
                let
                    value =
                        if (Config_UseCastInsteadOfConvert = true) then 
                            ODBC[SQL_FN_CVT][SQL_FN_CVT_CAST]
                        else
                            ODBC[SQL_FN_CVT][SQL_FN_CVT_CONVERT],
                    getInfo = [ 
                        SQL_CONVERT_FUNCTIONS = value
                    ]
                in
                    Merge(withLimitClauseKind, null, null, getInfo)
            else
                withLimitClauseKind,

        withSqlConformance =
            if (Config_SqlConformance <> null) then
                let
                    getInfo = [
                        SQL_SQL_CONFORMANCE = Config_SqlConformance
                    ]
                in
                    Merge(withCastOrConvert, null, null, getInfo)
            else
                withCastOrConvert
    in
        withSqlConformance;

// This is a work around for the lack of available conversion functions in the driver.
ImplicitTypeConversions = #table(
    { "Type1",        "Type2",         "ResultType" }, {
    // 'enum' char is added here to allow it to be converted to 'varchar' when compared against constants.
    // See MariaDB ODBC Connector 3.1.7 ma_info.c:51
    { "enum",       "varchar",          "varchar" }
});

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
