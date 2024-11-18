// This connector provides a sample Direct Query enabled connector 
// based on an ODBC driver. It is meant as a template for other 
// ODBC based connectors that require similar functionality.
// 
[Version = "1.0.4"]
section CosmosDB;

// When set to true, additional trace information will be written out to the User log. 
// This should be set to false before release. Tracing is done through a call to 
// Diagnostics.LogValue(). When EnableTraceOutput is set to false, the call becomes a 
// no-op and simply returns the original value.
EnableTraceOutput = false;

// TODO
// add and handle common options record properties
// add handling for LIMIT/OFFSET vs. TOP 
// add handling for SSL

/****************************
 * ODBC Driver Configuration
 ****************************/

// The name of your ODBC driver.
//
Config_DriverName = "Simba DocumentDB ODBC Driver";

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
Config_LimitClauseKind = LimitClauseKind.Top; // see above

// Set this option to true if your ODBC supports the standard username/password 
// handling through the UID and PWD connection string parameters. If the user 
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
Config_UseParameterBindings = null;  // true, false, null
 
// Override this setting to force the character escape value. 
// This is typically done when you have set UseParameterBindings to false.
//
// Set to null to determine the value from the driver. 
//
Config_StringLiterateEscapeCharacters = { "\" }; // ex. { "\" }

// Override this if the driver expects the use of CAST instead of CONVERT.
// By default, the query will be generated using ANSI SQL CONVERT syntax.
//
// Set to null to leave default behavior.
//
Config_UseCastInsteadOfConvert = null; // true, false, null

// Set this to true to enable Direct Query in addition to Import mode.
//
Config_EnableDirectQuery       = true; // true, false

DefaultCloud = "global";

[ DataSource.Kind = "CosmosDB",
  Publish         = "CosmosDB.Publish"
]

shared CosmosDB.Contents = Value.ReplaceType( CosmosDBImplementation, CosmosDBType );

CosmosDBType = type function
    (   host as ( type text meta [  Documentation.FieldCaption     = Extension.LoadString( "HostCaption" ),
                                    Documentation.FieldDescription = Extension.LoadString( "HostDescription" ),
                                    Documentation.SampleValues     = { Extension.LoadString( "HostSampleValues" ) }
                                 ]
                ),
                optional options as ( type nullable
                                      [ optional NUMBER_OF_RETRIES = 
                                        ( type text meta   [ Documentation.FieldCaption     = Extension.LoadString( "NumberOfRetriesCaption" ),
                                                             Documentation.FieldDescription = Extension.LoadString( "NumberOfRetriesDescription" ),
                                                             Documentation.SampleValues     = { Extension.LoadString( "NumberOfRetriesValues" ) }
                                                           ]
                                        ),
                                        optional ENABLE_AVERAGE_FUNCTION_PASSDOWN = 
                                        ( type text meta   [ Documentation.FieldCaption     = Extension.LoadString( "EnableAverageFunctionPassdownCaption" ),
                                                             Documentation.FieldDescription = Extension.LoadString( "EnableAverageFunctionPassdownDescription" ),
                                                             Documentation.SampleValues     = { Extension.LoadString( "EnableAverageFunctionPassdownValues" ) }
                                                           ]
                                        ),
                                        optional ENABLE_SORT_PASSDOWN_FOR_MULTIPLE_COLUMNS = 
                                        ( type text meta   [ Documentation.FieldCaption     = Extension.LoadString( "EnableSortPassdownForMultipleColumnsCaption" ),
                                                             Documentation.FieldDescription = Extension.LoadString( "EnableSortPassdownForMultipleColumnsDescription" ),
                                                             Documentation.SampleValues     = { Extension.LoadString( "EnableSortPassdownForMultipleColumnsValues" ) }
                                                           ]
                                        )
                                      ]
                                      meta [ Documentation.FieldCaption = "Advanced Options"
                                           ]
                                    )
    )
    as table meta
    [ Documentation.Name = Extension.LoadString( "ConnectorName" )
    ]
;

CosmosDBImplementation = (          host    as text,
                           optional options as record
                         ) as table =>
    let
        //
        // Connection string settings
        //

        NUMBER_OF_RETRIES                         = if ( options = null ) then
                                                        10
                                                    else if ( options[ NUMBER_OF_RETRIES ]? <> null ) then
                                                        options[ NUMBER_OF_RETRIES ]
                                                    else
                                                        10
        ,                                         
        ENABLE_AVERAGE_FUNCTION_PASSDOWN          = if ( options = null ) then
                                                        1
                                                    else if ( options[ ENABLE_AVERAGE_FUNCTION_PASSDOWN ]? <> null ) then
                                                        options[ ENABLE_AVERAGE_FUNCTION_PASSDOWN ]
                                                    else
                                                        1
        ,
        ENABLE_SORT_PASSDOWN_FOR_MULTIPLE_COLUMNS = if ( options = null ) then
                                                        0
                                                    else if ( options[ ENABLE_SORT_PASSDOWN_FOR_MULTIPLE_COLUMNS ]? <> null ) then
                                                        options[ ENABLE_SORT_PASSDOWN_FOR_MULTIPLE_COLUMNS ]
                                                    else
                                                        0
        ,
        ConnectionString = [ Driver                               = Config_DriverName,
                             // set all connection string properties
                             Host                                 = host,
                             NumberOfRetries                      = NUMBER_OF_RETRIES,
                             EnablePassdownOfAvgAggrFunction      = ENABLE_AVERAGE_FUNCTION_PASSDOWN,
                             EnableSortPassdownForMultipleColumns = ENABLE_SORT_PASSDOWN_FOR_MULTIPLE_COLUMNS,
                             RestApiVersion                       = "2018-12-31",
                             IgnoreSessionToken                   = "1"
                           ]
        ,
        //
        // Handle credentials
        // Credentials are not persisted with the query and are set through a separate 
        // record field - CredentialConnectionString. The base Odbc.DataSource function
        // will handle UsernamePassword authentication automatically, but it is explicitly
        // handled here as an example. 
        //
        Credential                 = Extension.CurrentCredential( ),
        AuthKind = Credential[AuthenticationKind],
        CredentialConnectionString = 
            if AuthKind = "OAuth" or AuthKind = "OAuth2" then
                [
                    AuthMech = 1,
                    Auth_AccessToken = Credential[access_token]
                ]
            else if AuthKind = "Key" then
                [
                    AuthenticationKey = Credential[ Key ]
                ]
            else
                [
                    // Ensure CredentialConnectionString is not empty; only affects testing, not PBI usage.
                    AuthMech = 1
                ]
        ,        
        //
        // Configuration options for the call to Odbc.DataSource
        //
        defaultConfig   = Diagnostics.LogValue( "BuildOdbcConfig",         BuildOdbcConfig( ) ),
        SqlCapabilities = Diagnostics.LogValue( "SqlCapabilities_Options", defaultConfig[ SqlCapabilities ]
                                                                           &
                                                                           [ // place custom overrides here
                                                                             // ######## SupportsTop = true
                                                                           ]
                                              )
        ,
        // Please refer to the ODBC specification for SQLGetInfo properties and values.
        // https://github.com/Microsoft/ODBC-Specification/blob/master/Windows/inc/sqlext.h
        SQLGetInfo = Diagnostics.LogValue( "SQLGetInfo_Options", defaultConfig[ SQLGetInfo ]
                                                                 &
                                                                 [ // place custom overrides here
                                                                 ]
                                         )
        ,

        SQLGetFunctions = Diagnostics.LogValue( "SQLGetFunctions_Options", defaultConfig[ SQLGetFunctions ]
                                                                 &
                                                                 [ SQL_API_SQLPRIMARYKEYS = false
                                                                 ]
                                         )
        ,

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
        SQLGetTypeInfo = ( _types ) => 
            let
                // Override incorrect metadata reported by the driver
                // Fix COLUMN_SIZE coming back as 1 for string/variable length types
                maxColumnSize       = 2097152,
                variableLengthTypes = { ODBC[ SQL_TYPE ][ VARCHAR       ],
                                        ODBC[ SQL_TYPE ][ WVARCHAR      ],
                                        ODBC[ SQL_TYPE ][ LONGVARCHAR   ],
                                        ODBC[ SQL_TYPE ][ WLONGVARCHAR  ],
                                        ODBC[ SQL_TYPE ][ VARBINARY     ],
                                        ODBC[ SQL_TYPE ][ LONGVARBINARY ]
                                      }
                ,
                withNewColumnSize = Table.AddColumn( _types,
                                                     "FixedColumnSize",
                                                     each if ( List.Contains( variableLengthTypes, [ DATA_TYPE ] ) ) then
                                                                maxColumnSize
                                                          else
                                                                [ COLUMN_SIZE ]
                                                     ,
                                                     Int32.Type
                                                   )
                ,
                // Swap columns
                renameColumns = Table.RenameColumns( Table.RemoveColumns( withNewColumnSize, { "COLUMN_SIZE" } ),
                                                     { { "FixedColumnSize",
                                                         "COLUMN_SIZE"
                                                       }
                                                     }
                                                   )
                ,
                // Reorder columns according to the original table parameter
                reorderedColumns = Table.SelectColumns( renameColumns,
                                                        Table.Schema( _types )[ Name ]
                                                      )
                ,
                tracedTable = 
                    if ( EnableTraceOutput <> true ) then
                        reorderedColumns 
                    else
                        let
                            // Outputting the entire table might be too large, and result in the value being truncated.
                            // We can output a row at a time instead with Table.TransformRows( )
                            rows    = Table.TransformRows( reorderedColumns, 
                                                           each Diagnostics.LogValue( "SQLGetTypeInfo " & _[ TYPE_NAME ],
                                                                                      _
                                                                                    )
                                                         )
                            ,
                            toTable = Table.FromRecords  ( rows )
                        in
                            toTable
            in
                // Ensure the type of our modified table matches the original
                Value.ReplaceType( tracedTable, 
                                   Value.Type( _types )
                                 )
        ,

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
        SQLColumns = ( catalogName, 
                       schemaName, 
                       tableName, 
                       columnName, 
                       source
                     ) =>
            if ( EnableTraceOutput <> true ) then 
                source 
            else
                // the if statement conditions will force the values to evaluated/written to diagnostics
                if ( Diagnostics.LogValue( "SQLColumns.TableName", tableName   ) <> "***" 
                     and
                     Diagnostics.LogValue( "SQLColumns.ColumnName", columnName ) <> "***"
                   ) then
                    let
                        // Outputting the entire table might be too large, and result in the value being truncated.
                        // We can output a row at a time instead with Table.TransformRows()
                        rows    = Table.TransformRows( source,
                                                       each Diagnostics.LogValue( "SQLColumns", _ )
                                                     )
                        ,
                        toTable = Table.FromRecords  ( rows )
                    in
                        Value.ReplaceType( toTable, 
                                           Value.Type( source )
                                         )
                else
                    source
        ,
        // This record allows you to customize the generated SQL for certain
        // operations. The most common usage is to define syntax for LIMIT/OFFSET operators.
        //
/*
        AstVisitor = [
            LimitClause = (skip, take) =>
                let
                    offset = if (skip <> null and skip > 0) then Text.Format("OFFSET #{0} ROWS", {skip}) else "",
                    limit = if (take <> null) then Text.Format("LIMIT #{0}", {take}) else ""
                in
                    [
                        Text = Text.Format("#{0} #{1}", {offset, limit}),
                        // Possible values for Location - BeforeQuerySpecification, AfterQuerySpecification, AfterSelect, AfterSelectBeforeModifiers
                        Location = "AfterQuerySpecification"
                    ]
        ],
*/

        OdbcDatasource = Odbc.DataSource( ConnectionString,
                                          [ // A logical (true/false) that sets whether to view the tables grouped by their schema names
                                            HierarchicalNavigation     = true, 
                                            // Prevents execution of native SQL statements. Extensions should set this to true.
                                            HideNativeQuery            = true,
                                            // Allows upconversion of numeric types
                                            SoftNumbers                = true,
                                            // Allow upconversion / resizing of numeric and string types
                                            TolerateConcatOverflow     = true,
                                            // Enables connection pooling via the system ODBC manager
                                            ClientConnectionPooling    = true,
                                            // These values should be set by previous steps
                                            CredentialConnectionString = CredentialConnectionString,
                                            UseEmbeddedDriver          = true, // true when using the ODBC Driver Packaged with PBI
                                            //AstVisitor = AstVisitor,
                                            SqlCapabilities            = SqlCapabilities,
                                            SQLColumns                 = SQLColumns,
                                            SQLGetInfo                 = SQLGetInfo,
                                            SQLGetTypeInfo             = SQLGetTypeInfo,
                                            SQLGetFunctions            = SQLGetFunctions,

                                            OnError                    = ( errorRecord as record ) =>
                                                                            error Error.Record( errorRecord[ Message ] )
                                          ]
                                        )
    in
        OdbcDatasource
;  

CloudToEndPoint = [
    global      = ".documents.azure.com",
    ussec       = ".documents.ussec.azure.com",
    usnat       = ".documents.usnat.azure.com",
    gcc         = ".documents.usgovcloudapi.net",
    gcc_dod     = ".documents.usgovcloudapi.mil",
    china       = ".documents.azure.cn",
    germany     = ".documents.microsoftazure.de"
];

CloudToResource = [
    global      = "https://cosmos.azure.com",
    ussec       = "https://cosmos.azure.us",
    usnat       = "https://cosmos.azure.us",
    gcc         = "https://cosmos.azure.us",
    gcc_dod     = "https://cosmos.azure.us",
    china       = "https://cosmos.azure.cn",
    germany     = "https://cosmos.microsoftazure.de"
];

// Data Source Kind description
CosmosDB = 
[
    // Set the TestConnection handler to enable gateway support.
    // The TestConnection handler will invoke your data source function to 
    // validate the credentials the user has provider. Ideally, this is not 
    // an expensive operation to perform. By default, the dataSourcePath value 
    // will be a json string containing the required parameters of your data  
    // source function. These should be parsed and parsed as individual parameters
    // to the specified data source function.
    TestConnection = ( dataSourcePath ) => 
        let
            json = Json.Document( dataSourcePath ),
            host = json[ host ]   // name of function parameter
        in
            { "CosmosDB.Contents", 
              host
            }
        ,
    IsKnownEndpoint = (resource) =>
    let
        Cloud = Environment.FeatureSwitch("Cloud", DefaultCloud),
        endPoint = Record.FieldOrDefault(CloudToEndPoint, Cloud, Record.Field(CloudToEndPoint, DefaultCloud)),
        resourceJson = Json.Document(resource),
        hostName = if (Record.HasFields(resourceJson, "host")) then resourceJson[host] else null
    in
        if (hostName = null or Text.Contains(hostName, endPoint)) then true else false
    ,        
    // Set supported types of authentication
    Cloud = Environment.FeatureSwitch("Cloud", DefaultCloud),
    Resource = Record.FieldOrDefault(CloudToResource, Cloud, Record.Field(CloudToResource, DefaultCloud)),
    Authentication = [ Key = [ ],
                        Aad = [
                            AuthorizationUri = Uri.Combine(Environment.FeatureSwitch("AzureActiveDirectoryUri", "https://login.microsoftonline.com"), "/common/oauth2/authorize"),
                            Resource = Resource,
                            Scope = ".default"
                        ]
                     ]
];

// Data Source UI publishing description
CosmosDB.Publish = 
[
    Category            = "Azure",
    ButtonText          = { Extension.LoadString( "ConnectorName" ),
                            Extension.LoadString( "ButtonHelp" )
                          },

    SupportsDirectQuery = Config_EnableDirectQuery,

    SourceImage         = CosmosDB.Icons,
    SourceTypeImage     = CosmosDB.Icons
];

CosmosDB.Icons = [ Icon16 = { Extension.Contents( "CosmosDB.16.png" ),
                              Extension.Contents( "CosmosDB.20.png" ),
                              Extension.Contents( "CosmosDB.24.png" ),
                              Extension.Contents( "CosmosDB.32.png" )
                            },
                   Icon32 = { Extension.Contents( "CosmosDB.32.png" ),
                              Extension.Contents( "CosmosDB.40.png" ),
                              Extension.Contents( "CosmosDB.48.png" ),
                              Extension.Contents( "CosmosDB.64.png" )
                            }
                 ]
;

// build settings based on configuration variables
BuildOdbcConfig = ( ) as record =>
    let
        Merge = (          previous as record, 
                  optional caps     as record,
                  optional funcs    as record, 
                  optional getInfo  as record
                ) as record => 
            let
                newCaps    = if ( caps    <> null ) then previous[ SqlCapabilities ] & caps    else previous[ SqlCapabilities ],
                newFuncs   = if ( funcs   <> null ) then previous[ SQLGetFunctions ] & funcs   else previous[ SQLGetFunctions ],
                newGetInfo = if ( getInfo <> null ) then previous[ SQLGetInfo      ] & getInfo else previous[ SQLGetInfo ]
            in
                [ SqlCapabilities   = newCaps,
                  SQLGetFunctions   = newFuncs,
                  SQLGetInfo        = newGetInfo,
                  CustomRandomTrace = previous[ CustomRandomTrace ]
                ]
        ,
        defaultConfig = [ SqlCapabilities  = [ ],
                          SQLGetFunctions  = [ ],
                          SQLGetInfo       = [ ]
                        ]
        ,
        withParams =
            if ( Config_UseParameterBindings = false ) then
                let 
                    caps = [ SupportsNumericLiterals       = true,
                             SupportsStringLiterals        = true,
                             SupportsOdbcDateLiterals      = true,
                             SupportsOdbcTimeLiterals      = true,
                             SupportsOdbcTimestampLiterals = true
                           ]
                    ,
                    funcs = [ SQL_API_SQLBINDPARAMETER = false
                            ]
                in
                    Merge( defaultConfig, caps, funcs )
            else
                defaultConfig
        ,                
        withEscape = 
            if ( Config_StringLiterateEscapeCharacters <> null ) then 
                let
                    caps = [ StringLiteralEscapeCharacters = Config_StringLiterateEscapeCharacters
                           ]
                in
                    Merge( withParams, caps )
            else
                withParams
        ,
        withLimitClauseKind = 
            let
                caps = [ LimitClauseKind = Config_LimitClauseKind
                       ]
            in
                Merge( withEscape, caps )
        ,
        withCastOrConvert = 
            if ( Config_UseCastInsteadOfConvert <> null ) then
                let
                    value =
                        if ( Config_UseCastInsteadOfConvert = true ) then 
                            ODBC[ SQL_FN_CVT ][ SQL_FN_CVT_CAST ]
                        else
                            ODBC[ SQL_FN_CVT ][ SQL_FN_CVT_CONVERT ]
                    ,
                    getInfo = [ SQL_CONVERT_FUNCTIONS = value
                              ]
                in
                    Merge( withLimitClauseKind, null, null, getInfo )
            else
                withLimitClauseKind
        ,
        withSqlConformance =
            if ( Config_SqlConformance <> null ) then
                let
                    getInfo = [ SQL_SQL_CONFORMANCE = Config_SqlConformance
                              ]
                in
                    Merge( withCastOrConvert, null, null, getInfo )
            else
                withCastOrConvert
    in
        withSqlConformance
;

// 
// Load common library functions
// 
Extension.LoadFunction = ( name as text ) =>
    let
        binary = Extension.Contents( name ),
        asText = Text.FromBinary   ( binary )
    in
        Expression.Evaluate( asText, #shared );

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics          = Extension.LoadFunction( "Diagnostics.pqm" );
Diagnostics.LogValue = if ( EnableTraceOutput ) then
                            Diagnostics[ LogValue ]
                       else
                            ( prefix, value ) => value
;

// OdbcConstants contains numeric constants from the ODBC header files, and a 
// helper function to create bitfield values.
ODBC = Extension.LoadFunction( "OdbcConstants.pqm" );
