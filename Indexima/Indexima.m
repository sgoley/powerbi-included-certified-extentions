// Indexima Power BI HiveServer 2 Connector
//
// v 1.0            Matt.Masson@microsoft.com Primary release
// v 1.1            Matt.Masson@microsoft.com Conflict on first class name (Hive) already usedby MicroSoft. Renamed to Indexima
// v 1.2 2018-02-21 Re-source the .mez provided by Microsoft
//                  Fix "cannot convert null to Table" error privided by George.Popell@microsoft.com
// v 1.3 2018-03-26 Rebranding interface with new logos
// v 1.4 2018-08-15 Add support for MS gateway (Add TestConnection handler to enable gateway support)
// 		            We maintain both DSN and DSN-less connection string to not loose Kerberos or Knox/Ranger authentication
// v 1.5 2018-10-15 Pre Release Gateway
//                  Notes:
//                      - Only the Hortonworks driver is capable to interface with Hive2 server
//                      - Gateway requires IP addresses to works

// Indexima Data Connector logic
[Version = "1.0.0"]
section Indexima;

// ----------------------------------------------------------------------------------------------
// EnableTraceOutput = true / false
// True     Additional trace information will be written out to the User log. Tracing is done through a call to Diagnostics.LogValue().
// False    Diagnostics.LogValue() the call becomes a no-op and simply returns the original value.
//
EnableTraceOutput = false;

[DataSource.Kind="Indexima", Publish="Indexima.Publish"]
shared Indexima.Database = Value.ReplaceType(IndeximaCore, IndeximaType);

// ----------------------------------------------------------------------------------------------
IndeximaType = type function (
        server as (type text meta [
            Documentation.FieldCaption = Extension.LoadString("ParamServer_Caption"),           // in resources.resx - ParamServer_Caption	        DSN
            Documentation.FieldDescription = Extension.LoadString("ParamServer_Description"),   // in resources.resx - ParamServer_Description	    DSN name
            Documentation.SampleValues = {"Indexima Data Hub DSN"},                             // should be more generic
            Documentation.DefaultValue = "Indexima Hive DSN"
            ]),
        port as (type number meta [
            Documentation.FieldCaption = Extension.LoadString("ParamDatabase_Caption"),         // in resources.resx - ParamDatabase_Caption	    Database
            Documentation.FieldDescription = Extension.LoadString("ParamDatabase_Description"), // in resources.resx - ParamDatabase_Description	Database name
            Documentation.SampleValues = {"10000"},
		    Documentation.DefaultValue = "10000"
            ]),
        optional options as (type record meta [
            Documentation.FieldCaption = Extension.LoadString("ParamOptions_Caption")           // Data Connectivity Mode                           Import or DirectQuery
            ])
        )
    as table meta [
        Documentation.Name = Extension.LoadString("Function_Name"),                             // in resources.resx - Function_Name		        Indexima 1.x
        Documentation.LongDescription = Extension.LoadString("Function_Description")            // in resources.resx - Function_Description	        Connect to Indexima
        ];

// ----------------------------------------------------------------------------------------------
// ODBC Driver Configuration
// Prepare ODBC connection string to bridge JDBC queries to our INDEXIMA data hub engine

// ----------------------------------------------------------------------------------------------
GetAddress = (server as text, defaultPort as number) as record =>
    let
        Address = Uri.Parts("http://" & server),
        // Uri.Parts(absoluteUri as text) as [Scheme = text, Host = text, Port = number, Path = text, Query = record, Fragment = text, UserName = text, Password = text]  

        // pointing to Knox gateway
        Port = if Address[Port] = 8443 and not Text.EndsWith(server, ":8443") then [Port = defaultPort] else [Port = Address[Port]],
        Host = [Host= Address[Host]],
        ConnectionString = Host & Port,
        Result =
            if Address[Host] = "" 
                or Text.StartsWith(server, "http:/", Comparer.OrdinalIgnoreCase) then
                    error Extension.LoadString("InvalidServerNameError")
            else
                ConnectionString
    in
        Result;


// Building the JDBC connection
BuildJDBCConnection = (JDBC_Address as text, JDBC_Port as number, JDBC_Driver as number, JDBC_Schema as text) as record =>
    let
        ConnectionString = [
//          Dsn = server,                                               // clean way to add a DSN

// List of all HIVE->ODBC drivers names. We are going to use such drivers as a bridge to communicate with JDBC devices
// All the following drives except SIMBA are SIMBA OEM
            Driver =      if JDBC_Driver = 0 then "Microsoft Hive ODBC Driver"
                     else if JDBC_Driver = 1 then "Cloudera ODBC Driver for Apache Hive"
                     else if JDBC_Driver = 2 then "Hortonworks Hive ODBC Driver"
                     else if JDBC_Driver = 3 then "Simba Hive ODBC Driver"
                     // No valid driver,  POWER BI will be forced to display following message:
                     //  "The 'Driver' property with value '{No JDBC Driver}' doesn't correspond to an installed ODBC driver."
                     else "NO JDBC Driver",   
// Simple Authentication
// Driver="xxxx ODBC Driver"; Host=[Server]; Port=[PortNumber]; AuthMech=3; UID=[YourUserName]; PWD=[YourPassword];

// Kerberos Authentication
// Driver="xxxx ODBC Driver"; Host=[Server]; Port=[PortNumber]; AuthMech=1; KrbRealm=[Realm]; KrbHostFQDN=[DomainName]; KrbServiceName=[ServiceName];

// Knox/Ranger Authentication
// Driver="xxxx ODBC Driver"; Host=[Knox Server]; Port=[8443]; SSL= 1; AuthMech=3; UID=[YourUserName]; PWD=[YourPassword];
// Connecting to jdbc:hive2://ns3615.co.eu:8443/;ssl=true;sslTrustStore=/var/lib/knox/data-2.6.5.0-292/security/keystores/gateway.jks;
// trustStorePassword=password;transportMode=http;httpPath=gateway/default/indexima

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

            // Special setup when Ranger/Knox is enabled
//          ThriftTransport = 2                                         // HTTP transport through the Knox gateway
//          HTTPPath = "/cliservice"                                    // required if HTTP transport
            ],
        Result =
                ConnectionString
    in
        Result;

// ----------------------------------------------------------------------------------------------
IndeximaCore = (server as text, port as number, optional options as record) =>
    let
        Credential = Extension.CurrentCredential(),

        // WARNING only the HortonWorks driver interprets correctly structures returned by queries SHOW SCHEMA and SHOW TABLES
        ConnectionString = BuildJDBCConnection(server, port, 2, ""),

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
        HierarchicalNavigation = not (options[HierarchicalNavigation]? = false),

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

            GroupByCapabilities = SQL_GB[SQL_GB_COLLATE],               // SQL_GB_NO_RELATION = 0x0003 ????  SQL_GB_COLLATE = 0x0004

            SupportsTop = true,                                         // Supports the TOP clause to limit the number of returned rows.
                                                                        // Default: false,  Set to false for Hive connector  

//          FractionalSecondsScale = 3,                                 // Ranging from 1 to 7, Number of decimal places supported for millisecond values.
                                                                        // This value should be set by connectors that wish to enable query folding over datetime values.
                                                                        // Default: null, Not sure what to put for Indexima said Matt.Masson@microsoft.com
            // Matt.Masson@microsoft.com
            // Needed to work around a bug in the driver where selection of parameters only produces an error with an assertion message.
            // While this doesn't completely solve the issue, it addresses certain common queries that are produced by DirectQuery.

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
            // SQLGetInfo: A record that allows you to override values returned by calls to SQLGetInfo. 

//          SQLGetInfo = [
//              // TODO: is this the right approach for the Indexima driver? It removes errors but seems to impact performance. Matt.Masson@microsoft.com
//              // Turn on SQL_FN_STR_LOCATE_2      
//              SQL_STRING_FUNCTIONS = let driverDefault = 277753,
//                  locateOff = Number.BitwiseAnd(driverDefault, Number.BitwiseNot(/* SQL_FN_STR_LOCATE */ 0x20)),      // SQL_FN_STR_LOCATE = 0x00000020L
//                  locate2On = Number.BitwiseOr(locateOff, /* SQL_FN_STR_LOCATE_2 */ 0x10000)                          // SQL_FN_STR_LOCATE_2 = 0x00010000L
//               in
//                  locate2On
//                ],

            SQLGetInfo = [                                              // Place custom overrides here
                SQL_STRING_FUNCTIONS = let driverDefault =              // Value reported by the driver: 277 753 = 0x43CF9L
                    {
                    SQL_FN_STR[SQL_FN_STR_CONCAT],                      // 0x00000001L
                    SQL_FN_STR[SQL_FN_STR_LTRIM],                       // 0x00000008L
                    SQL_FN_STR[SQL_FN_STR_LENGTH],                      // 0x00000010L
                    SQL_FN_STR[SQL_FN_STR_LOCATE],                      // 0x00000020L
                    SQL_FN_STR[SQL_FN_STR_LCASE],                       // 0x00000040L
                    SQL_FN_STR[SQL_FN_STR_REPEAT],                      // 0x00000080L
                    SQL_FN_STR[SQL_FN_STR_RTRIM],                       // 0x00000400L
                    SQL_FN_STR[SQL_FN_STR_SUBSTRING],                   // 0x00000800L
                    SQL_FN_STR[SQL_FN_STR_UCASE],                       // 0x00001000L
                    SQL_FN_STR[SQL_FN_STR_ASCII],                       // 0x00002000L
                    SQL_FN_STR[SQL_FN_STR_SPACE]                        // 0x00040000L
                    },                                     // Total bitmap 0x00043CF9L = 277 753
                updated = driverDefault &                               // add missing string functions
                    {
                    SQL_FN_STR[SQL_FN_STR_LEFT],                        // 0x00000004L
                    SQL_FN_STR[SQL_FN_STR_RIGHT],                       // 0x00000200L
                                                    // Intermediate bitmap 0x00000204L
                    SQL_FN_STR[SQL_FN_STR_LOCATE_2]                     // 0x00010000L  // Add specific settings for Indexima
                    }
                in
                    Flags(updated),

                SQL_NUMERIC_FUNCTIONS = let driverDefault =             // this is the value reported by the driver: 8 386 415 = 0x7FF76F
                    {
                    SQL_FN_NUM[SQL_FN_NUM_ABS],                         // 0x00000001L
                    SQL_FN_NUM[SQL_FN_NUM_ASIN],                        // 0x00000004L
                    SQL_FN_NUM[SQL_FN_NUM_ATAN2],                       // 0x00000010L
                    SQL_FN_NUM[SQL_FN_NUM_LOG],                         // 0x00000400L
                    SQL_FN_NUM[SQL_FN_NUM_SIN],                         // 0x00002000L
                    SQL_FN_NUM[SQL_FN_NUM_SQRT],                        // 0x00004000L
                    SQL_FN_NUM[SQL_FN_NUM_LOG10],                       // 0x00080000L
                    SQL_FN_NUM[SQL_FN_NUM_POWER],                       // 0x00100000L
                    SQL_FN_NUM[SQL_FN_NUM_RADIANS]                      // 0x00200000L 
                    },                                     // Total bitmap 0x00386415L  // Missing 0x0 8 000 000L 
                updated = driverDefault &                               // add missing functions
                    {
                    SQL_FN_NUM[SQL_FN_NUM_MOD]                          // 0x00000800L
                    }
                in
                    Flags(updated)
		],

            // ----------------------------------------------------------------------------------
            // SQLGetInfo: Override values returned by calls to SQLGetFunctions.
            // A common use of this field is to disable the use of parameter binding, or to specify that generated queries should use CAST rather than CONVERT
            SQLGetFunctions = [
                SQL_API_SQLBINDPARAMETER = false
                // Use Cast Instead Of Convert                          // version ODBCVER >= 0x0300
                // SQL_CONVERT_FUNCTIONS = SQL_FN_CVT[SQL_FN_CVT_CAST]  // 0x00000002L
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
//      Odbc.DataSource("DSN=" & server, Options){0}[Data]{[Name=db]}[Data];
//      The prefixed server with "DNS=" is only for PowerBI desktop edition
        Odbc.DataSource(if Text.StartsWith(server, "DSN=", Comparer.OrdinalIgnoreCase) then server else ConnectionString, Options);

// ----------------------------------------------------------------------------------------------
// Data Source UI publishing description
Indexima.Publish = [
    Beta = true,            				   			// turn to false when released
    Category = "Database",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "http://indexima.com/",
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
            server = json[server],      // name of function parameter
            port = json[port]           // name of function parameter
        in
            { "Indexima.Database", server, port },

    // Set supported types of authentication
    Authentication = [ UsernamePassword = [] ],
    Label = Extension.LoadString("DataSourceLabel")
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
// ----------------------------------------------------------------------------------------------
