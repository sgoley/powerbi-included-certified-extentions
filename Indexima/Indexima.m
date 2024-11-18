// Indexima Power BI HiveServer 2 Connector
//
// v 1.0              Matt.Masson@microsoft.com Primary release
// v 1.1              Matt.Masson@microsoft.com Conflict on first class name (Hive) already usedby MicroSoft. Renamed to Indexima
// v 1.2   2018-02-21 Re-source the .mez provided by Microsoft
//                    Fix "cannot convert null to Table" error privided by George.Popell@microsoft.com
// v 1.3   2018-03-26 Rebranding interface with new logos
// v 1.4   2018-08-15 Add support for MS gateway (Add TestConnection handler to enable gateway support)
// 		              We maintain both DSN and DSN-less connection string to not loose Kerberos or Knox/Ranger authentication
// v 1.5   2018-10-15 Pre Release Gateway
//                    Notes:
//                      - Only the Hortonworks driver is capable to interface with Hive2 server
//                      - Version 2.01 12.1017 only
//                      - Gateway requires diagnostics to works
// v 1.5.2 2018-10-31 Add GUI selector
//                    The selector allows to select a driver when connecting in DSN-less mode
//                    One of the selection is DSN. it it possible also to select DSN mode by prefixing the server name with "DSN="
// v 1.5.3 2019-03-13 Troubleshoot Natixis issues on timestamp


// Indexima Data Connector logic
[Version = "1.7.5"]
section Indexima;

// ----------------------------------------------------------------------------------------------
// EnableTraceOutput = true / false
// True     Additional trace information will be written out to the User log. Tracing is done through a call to Diagnostics.LogValue().
// False    Diagnostics.LogValue() the call becomes a no-op and simply returns the original value.
//
EnableTraceOutput = false;
DefaultOptionConnection = Record.FromList({"ConnectionTimeout", "CommandTimeout"},{"15", "600"});

[DataSource.Kind="Indexima", Publish="Indexima.Publish"]
shared Indexima.Database = Value.ReplaceType(IndeximaCore, IndeximaType);

// ----------------------------------------------------------------------------------------------
IndeximaType = type function (
        server as (type text meta [
            Documentation.FieldCaption = Extension.LoadString("ParamServer_Caption"),
            Documentation.FieldDescription = Extension.LoadString("ParamServer_Description"),
            Documentation.SampleValues = {"master.indexima.com"},
            Documentation.DefaultValue = "master.indexima.comm"
            ]),
        port as (type number meta [                         // Render this variable mandatory to make sure the gateway do not miss this parameter
            Documentation.FieldCaption = Extension.LoadString("ParamPort_Caption"),
            Documentation.FieldDescription = Extension.LoadString("ParamPort_Description"),
            Documentation.SampleValues = {"10000"},
		    Documentation.DefaultValue = "10000"
            ]),
        optional ODBCdriver as (type text meta [            // This variable is optionnal, It means that this parameter will be proposed in desktop mode but will
                                                            // not show up in gateway mode. This is the reason why the prefix "DSN=" is kept
            Documentation.FieldCaption = Extension.LoadString("ParamDriver_Caption"),
            Documentation.FieldDescription = Extension.LoadString("ParamDriver_Description"),
            Documentation.DefaultValue = "DSN",
            Documentation.AllowedValues = { "DSN" }
            ]), 
       optional options as (type record meta [
            Documentation.FieldCaption = Extension.LoadString("ParamOptions_Caption")           // Data Connectivity Mode - Import or DirectQuery
            ])
        )
    as table meta [
        Documentation.Name = Extension.LoadString("Function_Name"),                             // Function_Name		Indexima 1.x
        Documentation.LongDescription = Extension.LoadString("Function_Description")            // Function_Description	        Connect to Indexima
        ];

// ----------------------------------------------------------------------------------------------
// ODBC Driver Configuration
// Prepare ODBC connection string to bridge JDBC queries to our INDEXIMA data hub engine

// ----------------------------------------------------------------------------------------------
// Building the JDBC connection
// JDBC_Driver can be null. In this case it is defaulted to "DSN"
BuildJDBCConnection = (JDBC_Address as text, JDBC_Port as number, JDBC_Driver as text, JDBC_Schema as text) as record =>
    let
        ConnectionString = [
// List of all HIVE->ODBC drivers names. We are going to use such drivers as a bridge to communicate with JDBC devices
// All the following drivers except SIMBA are SIMBA OEM
            Driver = "DSN",
                       
// Simple Authentication
// Driver="xxxx ODBC Driver"; Host=[Server]; Port=[PortNumber]; AuthMech=3; UID=[YourUserName]; PWD=[YourPassword];
            Host = JDBC_Address,
            Port = JDBC_Port,
            Schema = JDBC_Schema,				                        // default schema, must be blank for navigation into Hive2 structures
            SSL = 0,					                                // SSL Encryption (Binary connection)
            AuthMech = 3,                                               // Authentication Mechanism AuthMech = 0 for No Authentication.
                                                                        //                                     1 for Kerberos.
                                                                        //                                     2 for User Name.
                                                                        // Force full authentication           3 for User Name And Password.

            ThriftTransport = 1                                         // ThriftTransport 0 = BINARY  if connecting to Hive Server 1. 
                                                                        //                 1 = SASL    if connecting to Hive Server 2.
                                                                        //                 2 = HTTP
            ],
        Result = ConnectionString
    in
        Result;

// ----------------------------------------------------------------------------------------------
// Main entry point
// server and port are mandatory parameters even if port is useless in DSN mode.
// driver is mainly used in desktop mode and is defaulted to DSN when NULL
IndeximaCore = (server as text, port as number, optional driver as text, optional options as record) =>
    let
        Credential = Extension.CurrentCredential(),

        driver = "DSN",

        // WARNING PowerBI is very sensitive to DAX layers of different drivers. On REX, only the HortonWorks driver interprets correctly SQL structures
        ConnectionString = BuildJDBCConnection(server, port, driver, ""),   // schema left empty to force PowerBI to brownse into the Indexima Dataspaces

        Options = [
        // --------------------------------------------------------------------------------------
        // Credentials are not persisting with the query and are set through a separate record field - CredentialConnectionString.
        // The base Odbc.DataSource function will handle UsernamePassword authentication automatically
        // The very basic is: CredentialConnectionString = [ UID = Credential[Username], PWD = Credential[Password] ],
        CredentialConnectionString =                                        // set connection string parameters used for basic authentication
            if Credential[AuthenticationKind]? = "Username" then
                 [ UID = Credential[Username], PWD = "" ]
            else if Credential[AuthenticationKind]? = "UsernamePassword" then
                 [ UID = Credential[Username], PWD = Credential[Password] ]
            else
                error Error.Record("Error", "Unknown authentication mechanism: " & Credential[AuthenticationKind]?),

        // Common options from the options record
        // --------------------------------------------------------------------------------------
        // ConnectionTimeout: How long to wait before abandoning and attempt to make a connection to the server. 
        // Default: 15 seconds
        ConnectionTimeout = if (options[ConnectionTimeout]? <> null) then options[ConnectionTimeout] else Duration.From(0.0),

        // --------------------------------------------------------------------------------------
        // CommandTimeout: How long the server-side query is allowed to run before it is cancelled. 
        // Default: 10 minutes
        CommandTimeout = if (options[CommandTimeout]? <> null) then options[CommandTimeout] else Duration.From(0.0),

        // --------------------------------------------------------------------------------------
        // HierarchicalNavigation: Sets whether to view the tables grouped by their schema names.
        // When set to false, tables will be displayed in a flat list under each database.
        // Default: false
// --- Test Hive Issue
//        HierarchicalNavigation = not (options[HierarchicalNavigation]? = false),
        HierarchicalNavigation = true,

// --- Test Hive Issue
        // --------------------------------------------------------------------------------------
        // Allows conversion of numeric and text types to larger types if an operation would cause the value to
        // fall out of range of the original type.
	// For example, when adding Int32.Max + Int32.Max, the engine will cast the result to Int64 when this setting is set to true.
	// When adding a VARCHAR(4000) and a VARCHAR(4000) field on a system that supports a maximize VARCHAR size of 4000, the engine
	// will cast the result into a CLOB type.
        // Default: false
        TolerateConcatOverflow = true,

        // --------------------------------------------------------------------------------------
        // CreateNavigationProperties: Generate navigation properties on the returned tables. Navigation properties are based on foreign key relationships
        // reported by the driver, and show up as virtual columns that can be expanded in the query editor, creating the appropriate join. 
        // If calculating foreign key dependencies is an expensive operation for your driver, you may want to set this value to false. 
        // Default: true
        CreateNavigationProperties = not (options[CreateNavigationProperties]? = false),
            
        // --------------------------------------------------------------------------------------
        // HideNativeQuery: Allows native SQL statements to be passed in by a query using the Value.NativeQuery() function. 
        // Note: this functionality is currently not exposed in the Power Query user experience. 
        // Default: false
        HideNativeQuery = true,                                         // fix a bug shown in versions of PowerBI starting Jan 2018
                                                                        // "cannot convert null to Table" error if missing or false

        // --------------------------------------------------------------------------------------
        // ClientConnectionPooling: Enables client-side connection pooling for the ODBC driver. Most drivers will want to set this value to true.
        // Default: false
        ClientConnectionPooling = true,          
        
        // --------------------------------------------------------------------------------------
        // SqlCapabilities: Overrides of driver capabilities, and a way to specify capabilities that are not expressed through ODBC 3.8. 
        SqlCapabilities = [
            Sql92Conformance = SQL_SC[SQL_SC_SQL92_FULL],               // SQL_SC_SQL92_FULL = 0x00000008

// --- Test Hive Issue --- uses SQL_GB_NO_RELATION
//          GroupByCapabilities = SQL_GB[SQL_GB_COLLATE],               // SQL_GB_COLLATE = 0x0004
                                                                        // A constant specifying the relationship between the columns in the GROUP BY clause
                                                                        // and the nonaggregated columns in the select list, indicates a COLLATE clause can be
                                                                        // specified at the end of each grouping column.
            GroupByCapabilities = SQL_GB[SQL_GB_NO_RELATION],           // SQL_GB_NO_RELATION = 0x0003
                                                                        // A constant specifying the relationship between the columns in the GROUP BY clause and
                                                                        // the nonaggregated columns in the select list, indicates the columns in the GROUP BY clause
                                                                        // and the select list are not related.

            SupportsTop = false,                                         // Supports the TOP clause to limit the number of returned rows.
                                                                        // Default: false,  Set to false for Hive connector  
            FractionalSecondsScale = 3,                                 // Ranging from 1 to 7, Number of decimal places supported for millisecond values.
                                                                        // This value should be set by connectors that wish to enable query folding over datetime values.
                                                                        // Default: null, Not sure what to put for Indexima said Matt.Masson@microsoft.com

            SupportsNumericLiterals = true,                             // Includes numeric literals values.
                                                                        // When set to false, numeric values will always be specified using Parameter Binding.
                                                                        // Default: false

            SupportsStringLiterals = true,                              // Includes string literals values.
                                                                        // When set to false, string values will always be specified using Parameter Binding.
                                                                        // Default: false

            StringLiteralEscapeCharacters = { "\" },                    // A list of text values which specify the character(s) to use when escaping string literals and LIKE expressions.
                                                                        // Default: null
                
            SupportsOdbcDateLiterals = true,                            // Includes date literals values.
                                                                        // When set to false, date values will always be specified using Parameter Binding.
                                                                        // Default: false

            SupportsOdbcTimeLiterals = true,                            // Includes time literals values.
                                                                        // When set to false, time values will always be specified using Parameter Binding.
                                                                        // Default: false

            SupportsOdbcTimestampLiterals = true                        // Includes timestamp literals values.
                                                                        // When set to false, timestamp values will always be specified using Parameter Binding.
                                                                        // Default: false
            ],


            // ----------------------------------------------------------------------------------
            // SQLGetInfo: Override values returned by calls to SQLGetFunctions.
            // A common use of this field is to disable the use of parameter binding, or to specify that generated queries should use CAST rather than CONVERT
            SQLGetFunctions = [
                // We enable numeric and string literals which should enable literals for all constants.
                SQL_API_SQLBINDPARAMETER = false,
                // Use Cast Instead Of Convert                          // version ODBCVER >= 0x0300
                SQL_CONVERT_FUNCTIONS = SQL_FN_CVT[SQL_FN_CVT_CAST]     // 0x00000002L
                ],

            // ----------------------------------------------------------------------------------
            // AstVisitor: This record allows you to customize the generated SQL for certain operations.
            // The most common usage is to define syntax for LIMIT/OFFSET operators when TOP is not supported. 
            AstVisitor = [
                // format is "LIMIT [<skip>,]<take>" - ex. LIMIT 2,10 or LIMIT 10
                LimitClause = (skip, take) =>
                    if (take = null) then ...
                    else 
                        let
                            skip = if (skip = null or skip = 0) then "" else Number.ToText(skip) & ","
                        in
                            [
                                Text = Text.Format("LIMIT #{0}#{1}", { skip, take }),
                                Location = "AfterQuerySpecification"
                            ]
                ]
            ]
    in

// Genuine calls, new format handle DSN and DSN-less connection
//      Odbc.DataSource("DSN=" & server, Options){0}[Data]{[Name=db]}[Data];
        if (Text.StartsWith(server, "DSN=", Comparer.OrdinalIgnoreCase)) then Odbc.DataSource (server, Options)
        else if (driver = "DSN" or driver = Null.Type) then  Odbc.DataSource ("DSN=" & server, Options)
        else  Odbc.DataSource(ConnectionString, Options);

// ----------------------------------------------------------------------------------------------
// Data Source UI publishing description
Indexima.Publish = [
    Beta = false,                                                       
    Category = "Database",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://www.indexima.com/",
    SourceImage = Indexima.Icons,
    SourceTypeImage = Indexima.Icons,
    SupportsDirectQuery = true
    ];

Indexima.Icons = [
    Icon16 = { Extension.Contents("Indexima16.png"), Extension.Contents("Indexima20.png"), Extension.Contents("Indexima24.png"), Extension.Contents("Indexima32.png") },
    Icon32 = { Extension.Contents("Indexima32.png"), Extension.Contents("Indexima40.png"), Extension.Contents("Indexima48.png"), Extension.Contents("Indexima64.png") }
    ];

// ----------------------------------------------------------------------------------------------
// Data Source Kind description
// Desktop PowerBI support just requires simple authentication
// Indexima = [Authentication = [UsernamePassword = [] ] ];
Indexima = [
    // Set the TestConnection handler to enable gateway support.
    // The TestConnection handler will invoke your data source function to validate the credentials the user has provider. Ideally, this is not 
    // an expensive operation to perform. By default, the dataSourcePath value will be a json string containing the required parameters of your data  
    // source function. These should be parsed and parsed as individual parameters to the specified data source function.
    TestConnection = (dataSourcePath) => 
        let
            json = Json.Document(dataSourcePath),
            server = json[server],                      // name of function parameter server
            port = json[port],                          // JDBC PORT
            driver =  try json[driver] otherwise "DSN", // JDBC driver DSN if the value is null
            options = try json[options] otherwise DefaultOptionConnection
       in
          { "Indexima.Database", server, port, driver, options },

    // Set supported types of authentication
    Authentication = [ UsernamePassword = [] ],

    Label = Extension.LoadString("DataSourceLabel")
//  Label = Null.Type                                   // setting this value to null (or getting an error) and server from connection string will be used
];

// ----------------------------------------------------------------------------------------------
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

// Expose the constants and bitfield helpers
Flags = ODBC[Flags];
SQL_FN_STR = ODBC[SQL_FN_STR];
SQL_SC = ODBC[SQL_SC];
SQL_GB = ODBC[SQL_GB];
SQL_FN_NUM = ODBC[SQL_FN_NUM];
SQL_AF = ODBC[SQL_AF];
SQL_FN_CVT = ODBC[SQL_FN_CVT];
// ----------------------------------------------------------------------------------------------
