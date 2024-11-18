// This connector provides a sample Direct Query enabled connector 
// based on an ODBC driver. It is meant as a template for other 
// ODBC based connectors that require similar functionality.
// 
[Version = "1.0.5"]
section MarkLogicODBC;

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
Config_DriverName = "MarkLogic SQL";

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
// ];
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
Config_DefaultUsernamePasswordHandling = false;  // true, false

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
Config_StringLiterateEscapeCharacters  = { "\" }; // ex. { "\" }

// Override this if the driver expects the use of CAST instead of CONVERT.
// By default, the query will be generated using ANSI SQL CONVERT syntax.
//
// Set to false or null to leave default behavior. 
//
Config_UseCastInsteadOfConvert = true; // true, false, null

// If the driver supports the TOP clause in select statements, set this to true. 
// If set to false, you MUST implement the AstVisitor for the LimitClause in the 
// main body of the code below. 
//
Config_SupportsTop = false; // true, false

// Set this to true to enable Direct Query in addition to Import mode.
//
Config_EnableDirectQuery = true;    // true, false

[DataSource.Kind="MarkLogicODBC", Publish="MarkLogicODBC.Publish"]
shared MarkLogicODBC.Contents = Value.ReplaceType(MarkLogicODBCImpl, MarkLogicODBCType);

MarkLogicODBCType = type function (
    server as (type text meta [
        Documentation.FieldCaption = "Hostname",
        Documentation.FieldDescription = "The name of the host that is running MarkLogic",
        Documentation.SampleValues = {"localhost"}
    ]), 
    port as (type number meta [
        Documentation.FieldCaption = "Port number",
        Documentation.FieldDescription = "The port that the MarkLogic ODBC Server is running on",
        Documentation.SampleValues = {5432, 7033, 6050}
    ]))
    as table meta [
        Documentation.Name = "MarkLogic ODBC (v3.0.2)",
        Documentation.LongDescription = "Returns the list of tables returned from the ODBC driver",
        Documentation.Examples = {}
    ];

MarkLogicODBCImpl = (server as text, port as number ) =>
    let
        //
        // Connection string settings
        //
        ConnectionString = [
            Driver = Config_DriverName,
            Server = server,
            Port = port,
            // set all connection string properties
            ApplicationIntent = "readonly",
            BoolsAsChar = "Yes",
            Debug = "No",
            CommLog ="No"
        ],

        //
        // Handle credentials
        // Credentials are not persisted with the query and are set through a separate 
        // record field - CredentialConnectionString. The base Odbc.DataSource function
        // will handle UsernamePassword authentication automatically, but it is explictly
        // handled here as an example. 
        //
        Credential = Extension.CurrentCredential(),
        useSSL = Credential[EncryptConnection]? = true,
		CredentialConnectionString =
            if Credential[AuthenticationKind]? = "UsernamePassword" then
                // set connection string parameters used for basic authentication
                [ UID = Credential[Username], PWD = Uri.EscapeDataString(Credential[Password]), SSLmode = if useSSL then "verify-full" else "prefer" ]
            else
                error Error.Record("Error", "Unhandled authentication kind: " & Credential[AuthenticationKind]?),

        //
        // Configuration options for the call to Odbc.DataSource
        //
        defaultConfig = BuildOdbcConfig(),

        SqlCapabilities = defaultConfig[SqlCapabilities] & [
            // place custom overrides here
            FractionalSecondsScale = 3
        ],

        // Please refer to the ODBC specification for SQLGetInfo properties and values.
        // https://github.com/Microsoft/ODBC-Specification/blob/master/Windows/inc/sqlext.h
        SQLGetInfo = defaultConfig[SQLGetInfo] & [
            // place custom overrides here
            
            // The following three lines can be removed if we add the unicode support types to value. See OdbcDriver/info.c:167
            SQL_CONVERT_WVARCHAR = Odbc.Flags({Odbc.SQL_TYPE[BIGINT], Odbc.SQL_TYPE[BINARY], Odbc.SQL_TYPE[BIT], Odbc.SQL_TYPE[CHAR], Odbc.SQL_TYPE[DECIMAL], Odbc.SQL_TYPE[DOUBLE], Odbc.SQL_TYPE[FLOAT], Odbc.SQL_TYPE[INTEGER], Odbc.SQL_TYPE[LONGVARBINARY], Odbc.SQL_TYPE[LONGVARCHAR],Odbc.SQL_TYPE[NUMERIC],Odbc.SQL_TYPE[REAL],Odbc.SQL_TYPE[SMALLINT], Odbc.SQL_TYPE[TINYINT],Odbc.SQL_TYPE[VARBINARY],Odbc.SQL_TYPE[VARCHAR],Odbc.SQL_TYPE[WCHAR], Odbc.SQL_TYPE[WLONGVARCHAR],Odbc.SQL_TYPE[WVARCHAR]}),
            SQL_CONVERT_WLONGVARCHAR = Odbc.Flags({Odbc.SQL_TYPE[BIGINT], Odbc.SQL_TYPE[BINARY], Odbc.SQL_TYPE[BIT], Odbc.SQL_TYPE[CHAR], Odbc.SQL_TYPE[DECIMAL], Odbc.SQL_TYPE[DOUBLE], Odbc.SQL_TYPE[FLOAT], Odbc.SQL_TYPE[INTEGER], Odbc.SQL_TYPE[LONGVARBINARY], Odbc.SQL_TYPE[LONGVARCHAR],Odbc.SQL_TYPE[NUMERIC],Odbc.SQL_TYPE[REAL],Odbc.SQL_TYPE[SMALLINT], Odbc.SQL_TYPE[TINYINT],Odbc.SQL_TYPE[VARBINARY],Odbc.SQL_TYPE[VARCHAR],Odbc.SQL_TYPE[WCHAR], Odbc.SQL_TYPE[WLONGVARCHAR],Odbc.SQL_TYPE[WVARCHAR]}),
            SQL_CONVERT_WCHAR = Odbc.Flags({Odbc.SQL_TYPE[BIGINT], Odbc.SQL_TYPE[BINARY], Odbc.SQL_TYPE[BIT], Odbc.SQL_TYPE[CHAR], Odbc.SQL_TYPE[DECIMAL], Odbc.SQL_TYPE[DOUBLE], Odbc.SQL_TYPE[FLOAT], Odbc.SQL_TYPE[INTEGER], Odbc.SQL_TYPE[LONGVARBINARY], Odbc.SQL_TYPE[LONGVARCHAR],Odbc.SQL_TYPE[NUMERIC],Odbc.SQL_TYPE[REAL],Odbc.SQL_TYPE[SMALLINT], Odbc.SQL_TYPE[TINYINT],Odbc.SQL_TYPE[VARBINARY],Odbc.SQL_TYPE[VARCHAR],Odbc.SQL_TYPE[WCHAR], Odbc.SQL_TYPE[WLONGVARCHAR],Odbc.SQL_TYPE[WVARCHAR]}),
            
            SQL_SQL92_PREDICATES = ODBC[SQL_SP][ML_SPECIFIC],                 // See OdbcConstants.pqm:792 for ML supported SQL92 predicates I defined
            SQL_AGGREGATE_FUNCTIONS = ODBC[SQL_AF][All],
            SQL_GROUP_BY = ODBC[SQL_GB][SQL_GB_NO_RELATION],
            SQL_DATETIME_LITERALS = ODBC[SQL_DL_SQL92][ML_SPECIFIC]           // See OdbcConstants.pqm:1082 for ML supported SQL92 datetime lits I defined
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

        SQLGetTypeInfo = #table(
            { "TYPE_NAME",      "DATA_TYPE", "COLUMN_SIZE", "LITERAL_PREF", "LITERAL_SUFFIX", "CREATE_PARAS",           "NULLABLE", "CASE_SENSITIVE", "SEARCHABLE", "UNSIGNED_ATTRIBUTE", "FIXED_PREC_SCALE", "AUTO_UNIQUE_VALUE", "LOCAL_TYPE_NAME", "MINIMUM_SCALE", "MAXIMUM_SCALE", "SQL_DATA_TYPE", "SQL_DATETIME_SUB", "NUM_PREC_RADIX", "INTERVAL_PRECISION", "USER_DATA_TYPE" }, {
            //{ "char",              1,          65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "char",            null,            null,            -8,              null,               null,             0,                    0                }, 
            { "int8",              -5,         19,             "'",            "'",              null,                     1,          0,                2,            0,                    10,                 0,                   "int8",            0,               0,               -5,              null,               2,                0,                    0                },
            //{ "bit",               -7,         1,              "'",            "'",              null,                     1,          1,                3,            null,                 0,                  null,                "bit",             null,            null,            -7,              null,               null,             0,                    0                },
            //{ "bool",              -7,         1,              "'",            "'",              null,                     1,          1,                3,            null,                 0,                  null,                "bit",             null,            null,            -7,              null,               null,             0,                    0                },
            { "date",              9,          10,             "'",            "'",              null,                     1,          0,                2,            null,                 0,                  null,                "date",            null,            null,            9,               1,                  null,             0,                    0                }, 
            { "numeric",           3,          28,             null,           null,             null,                     1,          0,                2,            0,                    0,                   0,                  "numeric",         0,               0,               2,               null,               10,               0,                    0                },
            //{ "uuid",              -11,        37,             null,           null,             null,                     1,          0,                2,            null,                 0,                  null,                "uuid",            null,            null,            -11,             null,               null,             0,                    0                },
            { "int4",              4,          10,             null,           null,             null,                     1,          0,                2,            0,                    0,                   0,                  "int4",            0,               0,               4,               null,               2,                0,                    0                },
            //{ "text",              -1,         65535,          "'",            "'",              null,                     1,          1,                3,            null,                 0,                  null,                "text",            null,            null,            -10,             null,               null,             0,                    0                },
            //{ "lo",                -4,         255,            "'",            "'",              null,                     1,          0,                2,            null,                 0,                  null,                "lo",              null,            null,            -4,              null,               null,             0,                    0                }, 
            { "numeric",           2,          28,             null,           null,             "precision, scale",       1,          0,                2,            0,                    10,                 0,                   "numeric",         0,               6,               2,               null,               10,               0,                    0                },
            //{ "float4",            7,          9,              null,           null,             null,                     1,          0,                2,            0,                    10,                 0,                   "float4",          null,            null,            7,               null,               2,                0,                    0                }, 
            //{ "int2",              5,          19,             null,           null,             null,                     1,          0,                2,            0,                    10,                 0,                   "int2",            0,               0,               5,               null,               2,                0,                    0                }, 
            //{ "int2",              -6,         5,              null,           null,             null,                     1,          0,                2,            0,                    10,                 0,                   "int2",            0,               0,               5,               null,               2,                0,                    0                }, 
            //{ "timestamp",         11,         26,             "'",            "'",              null,                     1,          0,                2,            null,                 0,                  null,                "timestamp",       0,               38,              9,               null,               null,             0,                    0                }, 
            { "date",              91,         10,             "'",            "'",              null,                     1,          0,                2,            null,                 0,                  null,                "date",            null,            null,            9,               1,                  null,             0,                    0                }, 
            //{ "timestamp",         93,         26,             "'",            "'",              null,                     1,          0,                2,            null,                 0,                  null,                "timestamp",       0,               38,              9,               null,               null,             0,                    0                }, 
            //{ "bytea",             -3,         255,            "'",            "'",              null,                     1,          0,                2,            null,                 0,                  null,                "bytea",           null,            null,            -3,              null,               null,             0,                    0                }, 
            //{ "varchar",           12,         65535,          "'",            "'",              "max. length",            1,          0,                2,            null,                 0,                  null,                "varchar",         null,            null,           -9,               null,               null,             0,                    0                }, 
            //{ "char",              -8,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "char",            null,            null,           -8,               null,               null,             0,                    0                }, 
            //{ "text",              -10,        65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "text",            null,            null,           -10,              null,               null,             0,                    0                }, 
            // changed... our engine doesn't support cast as varchar/string... maybe raise a bug about this
            { "char",              -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "varchar",         null,            null,           -9,               null,               null,             0,                    0                },
            // changed, our engine doesn't recognize float8/float4 in cast function
            { "numeric",           8,          15,             null,           null,             null,                     1,          0,                2,            0,                    0,                   0,                  "float",          null,            null,            6,               null,               2,                0,                    0                },
            { "float",             6,          17,             null,           null,             null,                     1,          0,                2,            0,                    0,                   0,                  "float",          null,            null,            6,               null,               2,                0,                    0                },

            // added
            { "string",            -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "string",            null,            null,           -9,               null,               null,             0,                    0                },
            { "anyURI",            -10,        65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "anyURI",            null,            null,           -10,              null,               null,             0,                    0                },             
            { "IRI",               -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "IRI",               null,            null,           -9,               null,               null,             0,                    0                },
            { "boolean",           -7,         1,              "'",            "'",              null,                     1,          1,                3,            null,                 0,                  null,                "boolean",           null,            null,            -7,              null,               null,             0,                    0                },
            { "int",               4,          10,             null,           null,             null,                     1,          0,                2,            0,                    0,                  0,                   "int",               0,               0,               4,               null,               2,                0,                    0                },
            //{ "unsignedInt",       2,          28,             null,           null,             "precision, scale",       1,          0,                2,            0,                    10,                 0,                   "unsignedInt",       0,               6,               2,               null,               10,               0,                    0                },
            //{ "unsignedInt",       -5,         19,             "'",            "'",              null,                     1,          0,                2,            0,                    10,                 0,                   "unsignedInt",       0,               0,               -5,              null,               2,                0,                    0                },
            { "unsignedInt",       4,          10,             null,           null,             null,                     1,          0,                2,            1,                    0,                  0,                   "unsignedInt",       0,               0,               4,               null,               2,                0,                    0                },
            { "nonNegativeInteger",-9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "nonNegativeInteger",null,            null,           -9,               null,               null,             0,                    0                },
            { "positiveInteger",   -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "positiveInteger",   null,            null,           -9,               null,               null,             0,                    0                },
            { "negativeInteger",   -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "negativeInteger",   null,            null,           -9,               null,               null,             0,                    0                },
            { "nonPositiveInteger",-9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "nonPositiveInteger",null,            null,           -9,               null,               null,             0,                    0                },
            // can't find anything to convert uByte to... leave as a string for now
            { "unsignedByte",      -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "unsignedByte",      null,            null,           -9,               null,               null,             0,                    0                },
            //{ "unsignedByte",      -6,         5,              null,           null,             null,                     1,          0,                2,            1,                    10,                 0,                   "unsignedByte",      0,               0,               5,               null,               2,                0,                    0                }, 
            //{ "unsignedByte",      5,          19,             null,           null,             null,                     1,          0,                2,            1,                    10,                 0,                   "unsignedByte",      0,               0,               5,               null,               2,                0,                    0                },           
            // can't find anything to convert uShort to... leave as a string for now
            { "unsignedShort",     -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "unsignedShort",      null,            null,           -9,               null,               null,             0,                    0                },
            //{ "unsignedShort",      -6,         5,              null,           null,             null,                     1,          0,                2,            1,                    10,                 0,                   "unsignedShort",      0,               0,               5,               null,               2,                0,                    0                }, 
            //{ "unsignedShort",      5,          19,             null,           null,             null,                     1,          0,                2,            1,                    10,                 0,                   "unsignedShort",      0,               0,               5,               null,               2,                0,                    0                },           
            //{ "unsignedShort",     4,          10,             null,           null,             null,                     1,          0,                2,            1,                    0,                  0,                   "unsignedShort",     0,               0,               4,               null,               2,                0,                    0                },
            // can't find anything to convert byte to... leave as a string for now
            { "byte",              -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "byte",               null,            null,           -9,               null,               null,             0,                    0                },
            //{ "byte",              5,          19,             null,           null,             null,                     1,          0,                2,            0,                    10,                 0,                   "byte",              0,               0,               5,               null,               2,                0,                    0                }, 
            //{ "byte",              -6,         5,              null,           null,             null,                     1,          0,                2,            0,                    10,                 0,                   "byte",              0,               0,               5,               null,               2,                0,                    0                }, 
            // can't find anything to convert short to... leave as a string for now
            { "short",             -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "short",              null,            null,           -9,               null,               null,             0,                    0                },
            //{ "short",           3,          28,             null,           null,             null,                     1,          0,                2,            0,                    0,                   0,                  "short",         0,               0,               2,               null,               10,               0,                    0                },
            //{ "short",           -5,         19,             "'",            "'",              null,                     1,          0,                2,            0,                    10,                 0,                   "short",            0,               0,               -5,              null,               2,                0,                    0                },
            //{ "short",           5,          19,             null,           null,             null,                     1,          0,                2,            0,                    1,                  0,                   "short",             0,               0,               5,               null,               2,                0,                    0                }, 
            //{ "short",           -6,         5,              null,           null,             null,                     1,          0,                2,            0,                    10,                 0,                   "short",             0,               0,               5,               null,               2,                0,                    0                }, 
            //{ "short",           4,          10,             null,           null,             null,                     1,          0,                2,            0,                    0,                  0,                   "short",             0,               0,               4,               null,               2,                0,                    0                },
            // can't find anything to convert integer to... leave as a string for now
            { "integer",           -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "integer",           null,            null,           -9,               null,               null,             0,                    0                },
            //{ "integer",           3,          28,             null,           null,             null,                     1,          0,                2,            0,                    0,                   0,                  "integer",         0,               0,               2,               null,               10,               0,                    0                },
            //{ "integer",           2,          28,             null,           null,             "precision, scale",       1,          0,                2,            0,                    10,                 0,                   "integer",         0,               6,               2,               null,               10,               0,                    0                },
            //{ "integer",         -5,         65535,          null,            null,              null,                     1,          0,                2,            0,                    0,                 0,                   "integer",           0,               0,               -5,              null,               2,                0,                    0                },
            { "float",             7,          9,              null,           null,             null,                     1,          0,                2,            0,                    10,                 0,                   "float",             null,            null,            7,               null,               2,                0,                    0                }, 
            { "decimal",           2,          28,             null,           null,             "precision, scale",       1,          0,                2,            0,                    10,                 0,                   "decimal",           0,               6,               2,               null,               10,               0,                    0                },            
            { "unsignedLong",      2,          28,             null,           null,             "precision, scale",       1,          0,                2,            1,                    10,                 0,                   "unsignedLong",      0,               16,              2,               null,               10,               0,                    0                },
            //{ "unsignedLong",      7,          9,              null,           null,             null,                     1,          0,                2,            0,                    10,                 0,                   "unsignedLong",      null,            null,            7,               null,               2,                0,                    0                }, 
            //{ "long",              3,          28,             null,           null,             null,                     1,          0,                2,            0,                    0,                  0,                   "long",              0,               0,               2,               null,               10,               0,                    0                },
            { "long",              2,          28,             null,           null,             "precision, scale",       1,          0,                2,            0,                    10,                 0,                   "unsignedLong",      0,               16,              2,               null,               10,               0,                    0                },           
            //{ "long",              -5,         19,             "'",            "'",              null,                     1,          0,                2,            0,                    10,                 0,                   "long",              0,               0,               -5,              null,               2,                0,                    0                },
            { "double",            6,          17,             null,           null,             null,                     1,          0,                2,            0,                    0,                  0,                   "double",            null,            null,            6,               null,               2,                0,                    0                },
            //{ "double",            8,          15,             null,           null,             null,                     1,          0,                2,            0,                    0,                   0,                  "double",            null,            null,            6,               null,               2,                0,                    0                },
            { "dateTime",          11,         26,             "'",            "'",              null,                     1,          0,                2,            null,                 0,                  null,                "dateTime",          0,               38,              9,               3,                  null,             0,                    0                },
            { "dateTime",          93,         26,             "'",            "'",              null,                     1,          0,                2,            null,                 0,                  null,                "dateTime",          0,               38,              9,               3,                  null,             0,                    0                }, 
            { "time",              10,         26,             "'",            "'",              null,                     1,          0,                2,            null,                 0,                  null,                "time",              null,            38,           10,               2,                  null,             0,                    0                },
            { "time",              92,         26,             "'",            "'",              null,                     1,          0,                2,            null,                 0,                  null,                "time",              null,            38,           92,               2,                  null,             0,                    0                }, 
            { "time",              -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "time",              null,            null,           -9,               null,               null,             0,                    0                },
            { "gYear",             -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "gYear",             null,            null,           -9,               null,               null,             0,                    0                },
            { "gDay",              -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "gDay",              null,            null,           -9,               null,               null,             0,                    0                },
            { "gYearMonth",        -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "gYearMonth",        null,            null,           -9,               null,               null,             0,                    0                },
            { "gMonthDay",         -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "gMonthDay",         null,            null,           -9,               null,               null,             0,                    0                },
            { "gMonth",            -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "gMonth",            null,            null,           -9,               null,               null,             0,                    0                },
            { "yearMonthDuration", -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "yearMonthDuration", null,            null,           -9,               null,               null,             0,                    0                },
            { "dayTimeDuration",   -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "dayTimeDuration",   null,            null,           -9,               null,               null,             0,                    0                },
            { "base64Binary",      -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "base64Binary",      null,            null,           -9,               null,               null,             0,                    0                },
            { "hexBinary",         -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "hexBinary",         null,            null,           -9,               null,               null,             0,                    0                },
            { "point",             -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "point",             null,            null,           -9,               null,               null,             0,                    0                },
            { "longLatPoint",      -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "latLongPoint",      null,            null,           -9,               null,               null,             0,                    0                },
            { "duration",          -9,         65535,          "'",            "'",              "max. length",            1,          1,                3,            null,                 0,                  null,                "duration",          null,            null,           -9,               null,               null,             0,                    0                }}
        ),

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
            if (EnableTraceOutput <> true) then source else
            // the if statement conditions will force the values to evaluated/written to diagnostics
            if (Diagnostics.LogValue("SQLColumns.TableName", tableName) <> "***" and Diagnostics.LogValue("SQLColumns.ColumnName", columnName) <> "***") then
                let
                    // Outputting the entire table might be too large, and result in the value being truncated.
                    // We can output a row at a time instead with Table.TransformRows()
                    rows = Table.TransformRows(source, each Diagnostics.LogValue("SQLColumns", _)),
                    toTable = Table.FromRecords(rows)
                in
                    Value.ReplaceType(toTable, Value.Type(source))
            else
                source,

        // This record allows you to customize the generated SQL for certain
        // operations. The most common usage is to define syntax for LIMIT/OFFSET operators 
        // when TOP is not supported. 

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
            HideNativeQuery = true,
            // Allows upconversion of numeric types
            SoftNumbers = true,
            // Allow upconversion / resizing of numeric and string types
            TolerateConcatOverflow = true,
            // Enables connection pooling via the system ODBC manager
            ClientConnectionPooling = true,

            // These values should be set by previous steps
            CredentialConnectionString = CredentialConnectionString,
            AstVisitor = AstVisitor,
            SqlCapabilities = SqlCapabilities,
            SQLColumns = SQLColumns,
            SQLGetInfo = SQLGetInfo,
            SQLGetTypeInfo = SQLGetTypeInfo
        ])
    in
        OdbcDatasource;  

// Data Source Kind description
MarkLogicODBC = [
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
            server = json[server],   // name of function parameter
            port = json[port]        // name of function parameter
        in
            { "MarkLogicODBC.Contents", server, port },
    // Set supported types of authentication
    Authentication = [
        UsernamePassword = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
MarkLogicODBC.Publish = [
    Beta = false,
    Category = "Database",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",

    SupportsDirectQuery = Config_EnableDirectQuery,

    SourceImage = MarkLogicODBC.Icons,
    SourceTypeImage = MarkLogicODBC.Icons
];

MarkLogicODBC.Icons = [
    Icon16 = { Extension.Contents("MarkLogicODBC16.png"), Extension.Contents("MarkLogicODBC20.png"), Extension.Contents("MarkLogicODBC24.png"), Extension.Contents("MarkLogicODBC32.png") },
    Icon32 = { Extension.Contents("MarkLogicODBC32.png"), Extension.Contents("MarkLogicODBC40.png"), Extension.Contents("MarkLogicODBC48.png"), Extension.Contents("MarkLogicODBC64.png") }
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

        withCastOrConvert = 
            if (Config_UseCastInsteadOfConvert = true) then
                let
                    caps = withTop[SQLGetFunctions] & [ 
                        SQLGetFunctions = [
                            SQL_CONVERT_FUNCTIONS = 0x2 /* SQL_FN_CVT_CAST */
                        ]
                    ]
                in
                    withTop & caps
            else
                withTop,

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
Odbc.SQL_TYPE = ODBC[SQL_TYPE];