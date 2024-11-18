// This file contains the Data Virtuality Connector logic
[Version = "3.0.0"]
section DataVirtuality;

DefaultPort = "35433";

[DataSource.Kind="DataVirtuality", Publish="DataVirtuality.Publish"]
shared DataVirtuality.Database = Value.ReplaceType(DataVirtualityImpl, DataVirtualityType);


DataVirtualityType = type function (
    server as (type text meta [
        Documentation.FieldCaption = "Server",
        Documentation.FieldDescription = "Data Virtuality LDW server address. You can also enter a port number. If omitted, port 35433 will be used.",
        Documentation.SampleValues = { "servername:portnumber, myServer.com:35433" }
    ]),
    database as (type text meta [
        Documentation.FieldCaption = "Database",
        Documentation.FieldDescription = "The virtual database (vdb) to connect to.",
        Documentation.SampleValues = { "datavirtuality, myCustomVdb" }
    ]),
    optional options as (type record meta [])   
    ) 
    as table meta [
        Documentation.Name = Extension.LoadString("DataSourceLabel"),
        Documentation.LongDescription = Extension.LoadString("DataSourceLabel"),
        Documentation.Icon = Extension.Contents("DataVirtuality32.png")
    ];
    
DataVirtualityImpl = (server as text, database as text, optional options as record) as table =>
    let
        ConnectionString = GetAddress(server) & [
            Database = database,
            Driver = "DataVirtuality Unicode(x64)",
            ReadOnly = 1,
            MaxVarchar = 8000,
            LoAsVarchar = 1,
            BoolsAsChar = 0
            // the following are driver defaults. listed for awareness
            // ShowSystemTables = 0
        ],
        Credential = Extension.CurrentCredential(),
        encryptionEnabled = Credential[EncryptConnection]? = true,
        Options = [
            CredentialConnectionString = [
                SSLMode = if encryptionEnabled then "require" else "allow",
                UID = Credential[Username],
                PWD = Credential[Password]
            ],
            ClientConnectionPooling = true,
            OnError = OnError
        ],
        OdbcDataSource = Odbc.DataSource(ConnectionString, Options & [
            HierarchicalNavigation = true,
            SqlCapabilities = [
                FractionalSecondsScale = 3,
                PrepareStatements = false,
                SupportsTop = false,
                StringLiteralEscapeCharacters = { "\" },

                // This value is assumed to be true for drivers that set their conformance level to SQL_SC_SQL92_FULL (reported by the driver or overridden with the Sql92Conformance setting (see below)). For all other conformance levels, this value defaults to false.
                // If your driver does not report the SQL_SC_SQL92_FULL compliance level, but does support derived tables, set this value to true.
                // (driver reports SQL_SC_SQL92_ENTRY; thats overwritten via Sql92Conformance)
                // SupportsDerivedTable = true,

                SupportsNumericLiterals = true,
                SupportsStringLiterals = true,
                SupportsOdbcDateLiterals = true,
                SupportsOdbcTimeLiterals = true,
                SupportsOdbcTimestampLiterals = true,

                Sql92Conformance = 8 /* SQL_SC_SQL92_FULL */,
                GroupByCapabilities = 2 /* SQL_GB_GROUP_BY_EQUALS_SELECT */
            ],
            SQLGetFunctions = [ 
                SQL_API_SQLBINDPARAMETER = false
            ],

            HideNativeQuery = true,
            // Allows upconversion of numeric types
            SoftNumbers = true,
            // Allow upconversion / resizing of numeric and string types
            TolerateConcatOverflow = true,

            SQLGetTypeInfo = SQLGetTypeInfo,
 	        SQLGetInfo =  [
        	    // place custom overrides here
	            SQL_SQL92_PREDICATES = ODBC[SQL_SP][All],
	            SQL_AGGREGATE_FUNCTIONS = ODBC[SQL_AF][All],
                // no covert, we don't understand { fn convert(<col>, SQL_DOUBLE) } (etc)
   	    	    SQL_CONVERT_FUNCTIONS = 0x2,
                SQL_NUMERIC_FUNCTIONS = 0x7FFFD,
                SQL_STRING_FUNCTIONS = 0x7FFFF, 
                SQL_SYSTEM_FUNCTIONS =  0x7,
                SQL_TIMEDATE_FUNCTIONS = 0x1FFFFF, 
                SQL_SQL92_NUMERIC_VALUE_FUNCTIONS = 0x0,
                SQL_SQL92_STRING_FUNCTIONS = 0xAF,
                SQL_SQL92_DATETIME_FUNCTIONS = 0x7,

                SQL_CONVERT_BIT            = Flags({BIT,TINYINT,SMALLINT,INTEGER,                                         CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR                                                                                              }),
                SQL_CONVERT_TINYINT        = Flags({BIT,TINYINT,SMALLINT,INTEGER,BIGINT,FLOAT,DOUBLE,REAL,DECIMAL,NUMERIC,CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                    INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                    }),
                SQL_CONVERT_SMALLINT       = Flags({BIT,TINYINT,SMALLINT,INTEGER,BIGINT,FLOAT,DOUBLE,REAL,DECIMAL,NUMERIC,CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                    INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                    }),
                SQL_CONVERT_INTEGER        = Flags({BIT,TINYINT,SMALLINT,INTEGER,BIGINT,FLOAT,DOUBLE,REAL,DECIMAL,NUMERIC,CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                    INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                    }),
                SQL_CONVERT_BIGINT         = Flags({BIT,TINYINT,SMALLINT,INTEGER,BIGINT,FLOAT,DOUBLE,REAL,DECIMAL,NUMERIC,CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,          TIMESTAMP,INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                    }),
                SQL_CONVERT_FLOAT          = Flags({BIT,TINYINT,SMALLINT,INTEGER,BIGINT,FLOAT,DOUBLE,REAL,DECIMAL,NUMERIC,CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                    INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                    }),
                SQL_CONVERT_DOUBLE         = Flags({BIT,TINYINT,SMALLINT,INTEGER,BIGINT,FLOAT,DOUBLE,REAL,DECIMAL,NUMERIC,CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                    INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                    }),
                SQL_CONVERT_REAL           = Flags({BIT,TINYINT,SMALLINT,INTEGER,BIGINT,FLOAT,DOUBLE,REAL,DECIMAL,NUMERIC,CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                    INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                    }),
                SQL_CONVERT_DECIMAL        = Flags({BIT,TINYINT,SMALLINT,INTEGER,BIGINT,FLOAT,DOUBLE,REAL,DECIMAL,NUMERIC,CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                    INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                    }),
                SQL_CONVERT_NUMERIC        = Flags({BIT,TINYINT,SMALLINT,INTEGER,BIGINT,FLOAT,DOUBLE,REAL,DECIMAL,NUMERIC,CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                    INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                    }),
                SQL_CONVERT_CHAR           = Flags({BIT,TINYINT,SMALLINT,INTEGER,BIGINT,FLOAT,DOUBLE,REAL,DECIMAL,NUMERIC,CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,DATE,TIME,TIMESTAMP,INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH,BINARY,VARBINARY,LONGVARBINARY,GUID}),
                SQL_CONVERT_WCHAR          = Flags({BIT,TINYINT,SMALLINT,INTEGER,BIGINT,FLOAT,DOUBLE,REAL,DECIMAL,NUMERIC,CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,DATE,TIME,TIMESTAMP,INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH,BINARY,VARBINARY,LONGVARBINARY,GUID}),
                SQL_CONVERT_VARCHAR        = Flags({BIT,TINYINT,SMALLINT,INTEGER,BIGINT,FLOAT,DOUBLE,REAL,DECIMAL,NUMERIC,CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,DATE,TIME,TIMESTAMP,INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH,BINARY,VARBINARY,LONGVARBINARY,GUID}),
                SQL_CONVERT_WVARCHAR       = Flags({BIT,TINYINT,SMALLINT,INTEGER,BIGINT,FLOAT,DOUBLE,REAL,DECIMAL,NUMERIC,CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,DATE,TIME,TIMESTAMP,INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH,BINARY,VARBINARY,LONGVARBINARY,GUID}),
                SQL_CONVERT_LONGVARCHAR    = Flags({BIT,TINYINT,SMALLINT,INTEGER,BIGINT,FLOAT,DOUBLE,REAL,DECIMAL,NUMERIC,CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,DATE,TIME,TIMESTAMP,INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH,BINARY,VARBINARY,LONGVARBINARY,GUID}),
                SQL_CONVERT_WLONGVARCHAR   = Flags({BIT,TINYINT,SMALLINT,INTEGER,BIGINT,FLOAT,DOUBLE,REAL,DECIMAL,NUMERIC,CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,DATE,TIME,TIMESTAMP,INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH,BINARY,VARBINARY,LONGVARBINARY,GUID}),
                SQL_CONVERT_DATE           = Flags({                                                                      CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,DATE,     TIMESTAMP                                                                           }),
                SQL_CONVERT_TIME           = Flags({                                                                      CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,     TIME,TIMESTAMP                                                                           }),
                SQL_CONVERT_TIMESTAMP      = Flags({                                                                      CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,DATE,TIME,TIMESTAMP                                                                           }),
                SQL_CONVERT_BINARY         = Flags({                                                                      CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                                                           BINARY,VARBINARY,LONGVARBINARY     }),
                SQL_CONVERT_VARBINARY      = Flags({                                                                      CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                                                           BINARY,VARBINARY,LONGVARBINARY     }),
                SQL_CONVERT_LONGVARBINARY  = Flags({                                                                      CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                                                           BINARY,VARBINARY,LONGVARBINARY     }),
                SQL_CONVERT_GUID           = Flags({                                                                                                                                                                                                                     GUID})
	        ],
            AstVisitor = [
                LimitClause = (skip, take) =>
                    let
                        offset = if (skip <> null and skip > 0) then Text.Format("OFFSET #{0} ROWS", {skip}) else "",
                        limit = if (take <> null) then Text.Format("FETCH FIRST #{0} ROWS ONLY", {take}) else ""
                    in
                        [
                            Text = Text.Format("#{0} #{1}", {offset, limit}),
                            Location = "AfterQuerySpecification"
                        ]
            ]
        ]),

        Database = OdbcDataSource{[Name = database]}[Data],
        
        DataSourceMissingClientLibrary = "DataSource.MissingClientLibrary",
        DriverDownloadUrl = "http://datavirtuality.com/download/",

        OnError = (errorRecord as record) =>
                if Text.Contains(errorRecord[Message], "TEIID50072") then
                    error Extension.CredentialError(Credential.AccessDenied, errorRecord[Message])
                else if encryptionEnabled and Text.Contains(errorRecord[Message], "server does not support SSL, but SSL was required") then
                    error Extension.CredentialError(Credential.EncryptionNotSupported, errorRecord[Message])
               else if encryptionEnabled and Text.Contains(errorRecord[Message], "TEIID40124") then
                    error Extension.CredentialError(Credential.EncryptionNotSupported, errorRecord[Message])					
                else if errorRecord[Reason] = DataSourceMissingClientLibrary then
                    error Error.Record(DataSourceMissingClientLibrary, Text.Format("The Data Virtuality ODBC Driver is not installed. Please download the installer from #{0} and install the driver.", { DriverDownloadUrl }),DriverDownloadUrl)
                else 
                    error errorRecord
    in
        Database;

SQLGetTypeInfo =
    let 
        SQLGetTypeInfoTable = #table(
            {     "TYPE_NAME", "DATA_TYPE", "COLUMN_SIZE", "LITERAL_PREFIX", "LITERAL_SUFFIX", "CREATE_PARAMS", "NULLABLE", "CASE_SENSITIVE", "SEARCHABLE", "UNSIGNED_ATTRIBUTE", "FIXED_PREC_SCALE", "AUTO_UNIQUE_VALUE", "LOCAL_TYPE_NAME", "MINIMUM_SCALE", "MAXIMUM_SCALE", "SQL_DATA_TYPE" , "SQL_DATETIME_SUB", "NUM_PREC_RADIX", "INTERVAL_PRECISION" }, 
                {
                {"double", 6, 15, null, null, "precision, scale", 1, 0, 2, 0, 0, 0, null, 0, 0, 6, null, 10, 0 },
                {"double", 8, 20, null, null, null, 1, 0, 2, 0, 0, 0, null, 0, 0, 6, null, 10, 0 },
                {"decimal", 2, 20, null, null, null, null, 0, 2, 1, 1, 0, null, 4, 4, 2, null, 10, 0 },
                {"date", 91, 10, "'", "'", null, 1, 0, 2, null, 0, 0, null, null, null, 9, 1, null, 0 },
                {"timestamp", 93, 26, "'", "'", null, 1, 0, 2, null, 0, 0, null, 0, 38, 9, 3, null, 0 },
                {"datetime", 92, 6, "'", "'", null, 1, 0, 2, null, 0, 0, null, null, null, 9, 2, null, 0 },
                {"boolean", -7, 1, "'", "'", null, 1, 0, 2, null, 0, 0, null, 0, 0, -7, null, null, 0 },
                {"integer", 4, 10, null, null, null, 1, 0, 2, 0, 0, 0, null, 0, 0, 4, null, 10, 0 },
                {"long", -5, 19, null, null, null, 1, 0, 2, 0, 0, 0, null, 0, 0, -5, null, 10, 0 },
                {"short", 5, 5, null, null, null, 1, 0, 2, 0, 0, 0, null, 0, 0, 5, null, 10, 0 },
                {"short", -6, 5, null, null, null, 1, 0, 2, 0, 0, 0, null, 0, 0, 5, null, 10, 0 },
                {"clob", -10, 8190, "'", "'", null, 1, 1, 3, null, 0, null, null, null, null, -10, null, null, 0 },    
                {"string", 12, 255, "'", "'", null, 1, 1, 3, null, 0, null, null, null, null, -9, null, null, 0 },
                {"string", -9, 255, "'", "'", null, 1, 1, 3, null, 0, null, null, null, null, -9, null, null, 0 },
                {"string", -10, 255, "'", "'", null, 1, 1, 3, null, 0, null, null, null, null, -10, null, null, 0 },				
                { "lo", -9, -4, "'", "'", null, 1, 1, 3, null, 0, null, null, null, null, -9, null, null, 0 }
            }
        )
   in 
     SQLGetTypeInfoTable;

GetAddress = (server as text) as record =>
    let
        Address = Uri.Parts("http://" & server),
        Port = if Address[Port] = 80 and not Text.EndsWith(server, ":80") then [Port = DefaultPort]
            else [Port = Address[Port]],
        Server = [Server = Address[Host]],
        ConnectionString = Server & Port,
        Result =
            if Address[Host] = ""
                or Address[Scheme] <> "http"
                or Address[Path] <> "/"
                or Address[Query] <> []
                or Address[Fragment] <> ""
                or Address[UserName] <> ""
                or Address[Password] <> ""
                or Text.StartsWith(server, "http:/", Comparer.OrdinalIgnoreCase) then
                error "Invalid server name"
            else
                ConnectionString
    in
        Result;

// Data Source Kind description
DataVirtuality = [
   TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            server = json[server],
            database = json[database]
        in
            { "DataVirtuality.Database", server, database },
    Description = Extension.LoadString("DataSourceLabel"),
    Authentication = [
        UsernamePassword = [
        ]
    ],
    // Note: We currently recommend you do not include a Label for your data source if your function has required parameters, 
    // as users will not be able to distinguish between the different credentials they have entered. 
    // We are hoping to improve this in the future (i.e. allowing data connectors to display their own custom data source paths).
    // Label = Extension.LoadString("DataSourceLabel"),
    SupportsEncryption = true,
    // to have icons also in edit datasource picker/credential management
    Icons = DataVirtuality.Icons

];

// Data Source UI publishing description
DataVirtuality.Publish = [
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    Category = "Database",
    Beta = false,
    LearnMoreUrl = "http://datavirtuality.com/",
    SupportsDirectQuery = true,
    SourceImage = DataVirtuality.Icons,
    SourceTypeImage = DataVirtuality.Icons
];

DataVirtuality.Icons = [
    Icon16 = { Extension.Contents("DataVirtuality16.png"), Extension.Contents("DataVirtuality20.png"), Extension.Contents("DataVirtuality24.png"), Extension.Contents("DataVirtuality32.png") },
    Icon32 = { Extension.Contents("DataVirtuality32.png"), Extension.Contents("DataVirtuality40.png"), Extension.Contents("DataVirtuality48.png"), Extension.Contents("DataVirtuality64.png") }
];

Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// OdbcConstants contains numeric constants from the ODBC header files, and a 
// helper function to create bitfield values.
ODBC = Extension.LoadFunction("OdbcConstants.pqm");
Odbc.Flags = ODBC[Flags];

Flags = (flags as list) => 
    let
        Loop = List.Generate(()=> [i = 0, Combined = 0],
                                each [i] < List.Count(flags),
                                each [i = [i]+1, Combined = Number.BitwiseOr([Combined], flags{i})],
                                each [Combined]),
        Result = List.Last(Loop, 0)
    in
        Result;

CHAR = 0x00000001;
NUMERIC = 0x00000002;
DECIMAL = 0x00000004;
INTEGER = 0x00000008;
SMALLINT = 0x00000010;
FLOAT = 0x00000020;
REAL = 0x00000040;
DOUBLE = 0x00000080;
VARCHAR = 0x00000100;
LONGVARCHAR = 0x00000200;
BINARY = 0x00000400;
VARBINARY = 0x00000800;
BIT = 0x00001000;
TINYINT = 0x00002000;
BIGINT = 0x00004000;
DATE = 0x00008000;
TIME = 0x00010000;
TIMESTAMP = 0x00020000;
LONGVARBINARY = 0x00040000;
INTERVAL_YEAR_MONTH = 0x00080000;
INTERVAL_DAY_TIME = 0x00100000;
WCHAR = 0x00200000;
WLONGVARCHAR = 0x00400000;
WVARCHAR = 0x00800000;
GUID = 0x01000000;