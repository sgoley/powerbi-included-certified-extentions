/*
 * =============================================================================
 *
 *   This software is part of the DenodoConnect component collection.
 *
 *   Copyright (c) 2018, denodo technologies (http://www.denodo.com)
 *
 *   Licensed under the Apache License, Version 2.0 (the "License");
 *   you may not use this file except in compliance with the License.
 *   You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 *   Unless required by applicable law or agreed to in writing, software
 *   distributed under the License is distributed on an "AS IS" BASIS,
 *   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *   See the License for the specific language governing permissions and
 *   limitations under the License.
 *
 * =============================================================================
 */
 [Version = "1.0.2"]
section DenodoForPowerBI;

[DataSource.Kind="DenodoForPowerBI", Publish="DenodoForPowerBI.Publish"]

shared Denodo.Contents = Value.ReplaceType(DenodoForPowerBIImpl, DenodoForPowerBIType);

DenodoForPowerBIType = type function (
    DSN as (type text meta [
        Documentation.FieldCaption = "DSN",
        Documentation.SampleValues = {"Power BI - Denodo"},
        Documentation.FieldDescription = "Name of the ODBC data source"
    ]),
    optional debug as (type nullable logical meta [
        Documentation.FieldCaption = "Enable debug mode (default: false)",
        Documentation.FieldDescription = "Logical value: true or false",
        Documentation.AllowedValues = {"false","true"}
    ]))
    as table meta [
        Documentation.Name = "Denodo Connector",
        Documentation.LongDescription = "The Denodo Connector allows you to connect to Denodo's VDP server from PowerBI"
        
    ];

DenodoForPowerBIImpl = (DSN as text, optional debug as nullable logical) =>
    let
        
        // When set to true, additional trace information will be written out to the User log. 
        // Tracing is done through a call to Diagnostics.LogValue(). When debug is set to false, 
        // the call becomes a no-op and simply returns the original value.
        debug = if debug = null then false else debug,

        _DSN = if (debug) then Diagnostics.LogValue("DSN: ", DSN) else DSN,

        ConnectionString = [
            DSN = _DSN
        ],

        SqlCapabilities = [
            SupportsNumericLiterals = true,
            SupportsStringLiterals = true,
            SupportsOdbcDateLiterals = true,
            SupportsOdbcTimeLiterals = true,
            SupportsOdbcTimestampLiterals = true,
            StringLiteralEscapeCharacters = { "\" },
            SupportsTop = false                      // No support for TOP, should use LIMIT instead (see AstVisitor)
        ],

        SQLGetFunctions = [
            SQL_API_SQLBINDPARAMETER = false,        // Disable using parameters in the queries that get generated
            SQL_CONVERT_FUNCTIONS = 0x2              // Use CAST insteaad of CONVERT
        ],

        SQLGetInfo = [
            // You can see the values of the constants in this link: https://github.com/Microsoft/ODBC-Specification/blob/master/Windows/inc/sqlext.h

            SQL_SQL_CONFORMANCE = 8,              // SQL_SC_SQL92_FULL
            SQL_SQL92_PREDICATES = 0x00003E87 ,   // SQL_SP_EXISTS | SQL_SP_ISNOTNULL | SQL_SP_ISNULL | SQL_SP_OVERLAPS | SQL_SP_LIKE | SQL_SP_IN | SQL_SP_BETWEEN |
										          // SQL_SP_COMPARISON | SQL_SP_QUANTIFIED_COMPARISON
            SQL_AGGREGATE_FUNCTIONS = 0xFF,       // Integer bitmask. Defines which standard SQL aggregation forms are supported. Sum functions does
                                                  // not work without this property so numbers are not shown
            SQL_GROUP_BY = 2,                     // SQL_GB_GROUP_BY_CONTAINS_SELECT - it seems Power BI does not like EQUALS (which is our default)
            SQL_ORDER_BY_COLUMNS_IN_SELECT = "Y", // Denodo requires all columns in ORDER BY to appear in the SELECT clause


            // -----------------------------------------------------------------------------------------------------------------------------------------------------------------
            // Conversions adjusted according to https://community.denodo.com/docs/html/browse/6.0/vdp/vql/appendix/syntax_of_condition_functions/type_conversion_functions
            // -----------------------------------------------------------------------------------------------------------------------------------------------------------------
            // boolean - technically, conversions from long and decimal numbers to boolean are supported but only in explicit casts. Also, if we allow BIGINT -> BIT PowerBI will try to represent "false" as "0.0000000E+00" and an implicit cast will fail.
            SQL_CONVERT_BIT            = Flags({BIT,  TINYINT,SMALLINT,INTEGER,/*BIGINT,  FLOAT,  DOUBLE,REAL,  DECIMAL,NUMERIC,*/CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR                                                                                                      }),
            // int
            SQL_CONVERT_TINYINT        = Flags({BIT,  TINYINT,SMALLINT,INTEGER,  BIGINT,  FLOAT,  DOUBLE,REAL,  DECIMAL,NUMERIC,  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                        INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                        }),
            SQL_CONVERT_SMALLINT       = Flags({BIT,  TINYINT,SMALLINT,INTEGER,  BIGINT,  FLOAT,  DOUBLE,REAL,  DECIMAL,NUMERIC,  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                        INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                        }),
            SQL_CONVERT_INTEGER        = Flags({BIT,  TINYINT,SMALLINT,INTEGER,  BIGINT,  FLOAT,  DOUBLE,REAL,  DECIMAL,NUMERIC,  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                        INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                        }),
            // long
            SQL_CONVERT_BIGINT         = Flags({      TINYINT,SMALLINT,INTEGER,  BIGINT,  FLOAT,  DOUBLE,REAL,  DECIMAL,NUMERIC,  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,            TIMESTAMP,  INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                        }),
            // float
            SQL_CONVERT_FLOAT          = Flags({      TINYINT,SMALLINT,INTEGER,  BIGINT,  FLOAT,  DOUBLE,REAL,  DECIMAL,NUMERIC,  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                        INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                        }),
            // double
            SQL_CONVERT_DOUBLE         = Flags({      TINYINT,SMALLINT,INTEGER,  BIGINT,  FLOAT,  DOUBLE,REAL,  DECIMAL,NUMERIC,  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                        INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                        }),
            SQL_CONVERT_REAL           = Flags({      TINYINT,SMALLINT,INTEGER,  BIGINT,  FLOAT,  DOUBLE,REAL,  DECIMAL,NUMERIC,  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                        INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                        }),
            // decimal
            SQL_CONVERT_DECIMAL        = Flags({      TINYINT,SMALLINT,INTEGER,  BIGINT,  FLOAT,  DOUBLE,REAL,  DECIMAL,NUMERIC,  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                        INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                        }),
            SQL_CONVERT_NUMERIC        = Flags({      TINYINT,SMALLINT,INTEGER,  BIGINT,  FLOAT,  DOUBLE,REAL,  DECIMAL,NUMERIC,  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                        INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                        }),
            // text
            SQL_CONVERT_CHAR           = Flags({BIT,  TINYINT,SMALLINT,INTEGER,  BIGINT,  FLOAT,  DOUBLE,REAL,  DECIMAL,NUMERIC,  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,  DATE,TIME,TIMESTAMP,  INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH,  BINARY,VARBINARY,LONGVARBINARY,  GUID}),
            SQL_CONVERT_WCHAR          = Flags({BIT,  TINYINT,SMALLINT,INTEGER,  BIGINT,  FLOAT,  DOUBLE,REAL,  DECIMAL,NUMERIC,  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,  DATE,TIME,TIMESTAMP,  INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH,  BINARY,VARBINARY,LONGVARBINARY,  GUID}),
            SQL_CONVERT_VARCHAR        = Flags({BIT,  TINYINT,SMALLINT,INTEGER,  BIGINT,  FLOAT,  DOUBLE,REAL,  DECIMAL,NUMERIC,  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,  DATE,TIME,TIMESTAMP,  INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH,  BINARY,VARBINARY,LONGVARBINARY,  GUID}),
            SQL_CONVERT_WVARCHAR       = Flags({BIT,  TINYINT,SMALLINT,INTEGER,  BIGINT,  FLOAT,  DOUBLE,REAL,  DECIMAL,NUMERIC,  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,  DATE,TIME,TIMESTAMP,  INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH,  BINARY,VARBINARY,LONGVARBINARY,  GUID}),
            SQL_CONVERT_LONGVARCHAR    = Flags({BIT,  TINYINT,SMALLINT,INTEGER,  BIGINT,  FLOAT,  DOUBLE,REAL,  DECIMAL,NUMERIC,  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,  DATE,TIME,TIMESTAMP,  INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH,  BINARY,VARBINARY,LONGVARBINARY,  GUID}),
            SQL_CONVERT_WLONGVARCHAR   = Flags({BIT,  TINYINT,SMALLINT,INTEGER,  BIGINT,  FLOAT,  DOUBLE,REAL,  DECIMAL,NUMERIC,  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,  DATE,TIME,TIMESTAMP,  INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH,  BINARY,VARBINARY,LONGVARBINARY,  GUID}),
            // date
            SQL_CONVERT_DATE           = Flags({                                                                                  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,  DATE,     TIMESTAMP                                                                                }),
            SQL_CONVERT_TIME           = Flags({                                                                                  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,       TIME,TIMESTAMP                                                                                }),
            SQL_CONVERT_TIMESTAMP      = Flags({                                                                                  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,  DATE,TIME,TIMESTAMP                                                                                }),
            // blob
            SQL_CONVERT_BINARY         = Flags({                                                                                  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                                                                BINARY,VARBINARY,LONGVARBINARY       }),
            SQL_CONVERT_VARBINARY      = Flags({                                                                                  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                                                                BINARY,VARBINARY,LONGVARBINARY       }),
            SQL_CONVERT_LONGVARBINARY  = Flags({                                                                                  CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,                                                                BINARY,VARBINARY,LONGVARBINARY       }),

            SQL_CONVERT_GUID           = Flags({                                                                                                                                                                                                                                        GUID})

        ],

        // This record allows you to customize the generated SQL for certain
        // operations. The most common usage is to define syntax for LIMIT/OFFSET operators 
        // when TOP is not supported (in such case, a "LimitClause" section is required).
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


        // Configure the ODBC DataSource with all the data computed before (and some additional parameters)
        OdbcDatasource = Odbc.DataSource(ConnectionString, [

            HierarchicalNavigation = true,                     // A logical (true/false) that sets whether to view the tables grouped by their schema names
            HideNativeQuery = true,                            // This property seems to avoid launching two queries in some filters
            SoftNumbers = true,                                // Allows our numbers to be properly visualized in PowerBI. 
                                                               // SoftNumbers: allows the M engine to select a compatible data type when conversion between 
                                                               // two specific numeric types is not declared as supported in the SQL_CONVERT_* capabilities.
            ClientConnectionPooling = true,
            
            ImplicitTypeConversions = ImplicitTypeConversions, // Needed to work around driver behavior

            SqlCapabilities = SqlCapabilities,

            SQLGetInfo = SQLGetInfo,
            SQLGetFunctions = SQLGetFunctions,
            SQLGetTypeInfo = SQLGetTypeInfo(debug), 
            SQLColumns = SQLColumns(debug),

            AstVisitor = AstVisitor

        ])
    in
        OdbcDatasource;  


// Verify if this is needed in Denodo
// This is a work around for the lack of available convertion functions in the driver.
ImplicitTypeConversions = #table(
    { "Type1",        "Type2",         "ResultType" }, {
    // 'bpchar' char is added here to allow it to be converted to 'char' when compared against constants.
    { "bpchar",       "char",          "char" },
    { "bpchar",       "varchar",       "varchar" },
    { "bpchar",       "text",          "text" }
});


SQLGetTypeInfo = (debug as logical) =>
    let 
        // This table below is required to work around columns with type name 'bpchar' not listed by SQLGetTypeInfo.
        // It is a copy of what is returned by the Denodo ODBC driver with some modifications:
        //    - Added an entry for 'bpchar'
        //    - Added the 'timestamp' type (returned in VDP 7.0). Note that implicit cast between time and timestamp is not working in Denodo 7.0 (#38783 - Implicit cast between time and timestamp is not working)
        //    - Changed 'text' type to 'varchar' type because VDP returns the types with codes -9, -10, 12 and -1 as 'varchar'. (#38764 - Error loading some strings due to the definition of their size) 
        //      Once a string type matches (DATA_TYPE and TYPE_NAME) with one of the types defined in this SQLGetTypeInfo table, it can has a value with a bigger column size without causing a problem for Power BI Desktop. 
        //      It is able to load the whole value.
        // The values in this table 
        SQLGetTypeInfoTable = #table(
            { "TYPE_NAME", "DATA_TYPE", "PRECISION", "LITERAL_PREFIX", "LITERAL_SUFFIX", "CREATE_PARAMS", "NULLABLE", "CASE_SENSITIVE", "SEARCHABLE", "UNSIGNED_ATTRIBUTE", "MONEY", "AUTO_INCREMENT", "LOCAL_TYPE_NAME", "MINIMUM_SCALE", "MAXIMUM_SCALE", "SQL_DATA_TYPE", "SQL_DATETIME_SUB", "NUM_PREC_RADIX", "INTERVAL_PRECISION" }, {

            // Already returned by driver:
            {"int8", -5, 19, null, null, null, 1, 0, 2, 0, 0, 0, null, 0, 0, -5, null, 10, 0 },
            {"bool", -7, 1, "'", "'", null, 1, 0, 2, null, 0, 0, null, 0, 0, -7, null, null, 0 },
            {"char", 1, 255, "'", "'", "max. length", 1, 1, 3, null, 0, null, null, null, null, -8, null, null, 0 },
            {"date", 91, 10, "'", "'", null, 1, 0, 2, null, 0, 0, null, null, null, 9, 1, null, 0 },
            {"date", 9, 10, "'", "'", null, 1, 0, 2, null, 0, 0, null, null, null, 9, 1, null, 0 },
            {"numeric", 3, 28, null, null, "precision, scale", 1, 0, 2, 0, 0, 0, null, 0, 6, 2, null, 10, 0 },
            {"float8", 8, 17, null, null, null, 1, 0, 2, 0, 0, 0, null, 0, 0, 6, null, 10, 0 }, //double
            {"float8", 6, 17, null, null, null, 1, 0, 2, 0, 0, 0, null, 0, 0, 6, null, 10, 0 },
            {"int4", 4, 10, null, null, null, 1, 0, 2, 0, 0, 0, null, 0, 0, 4, null, 10, 0 },
            {"lo", -4, -4, "'", "'", null, 1, 0, 0, null, 0, null, null, null, null, -4, null, null, 0 },
            {"varchar", -1, 8190, "'", "'", null, 1, 1, 3, null, 0, null, null, null, null, -10, null, null, 0 },
            {"text", -1, 8190, "'", "'", null, 1, 1, 3, null, 0, null, null, null, null, -10, null, null, 0 },
            {"numeric", 2, 28, null, null, "precision, scale", 1, 0, 2, 0, 0, 0, null, 0, 6, 2, null, 10, 0 },
            {"float4", 7, 9, null, null, null, 1, 0, 2, 0, 0, 0, null, 0, 0, 7, null, 10, 0 },
            {"int2", 5, 5, null, null, null, 1, 0, 2, 0, 0, 0, null, 0, 0, 5, null, 10, 0 },
            {"time", 92, 8, "'", "'", null, 1, 0, 2, null, 0, 0, null, null, null, 9, 2, null, 0 },
            {"timestamptz", 93, 26, "'", "'", null, 1, 0, 2, null, 0, 0, null, 0, 38, 9, 3, null, 0 },
            {"timestamp", 93, 26, "'", "'", null, 1, 0, 2, null, 0, 0, null, 0, 38, 9, 3, null, 0 },
            {"time", 10, 8, "'", "'", null, 1, 0, 2, null, 0, 0, null, null, null, 9, 2, null, 0 },
            {"timestamptz", 11, 26, "'", "'", null, 1, 0, 2, null, 0, 0, null, 0, 38, 9, 3, null, 0 },
            {"timestamp", 11, 26, "'", "'", null, 1, 0, 2, null, 0, 0, null, 0, 38, 9, 3, null, 0 },
            {"int2", -6, 5, null, null, null, 1, 0, 2, 0, 0, 0, null, 0, 0, 5, null, 10, 0 },
            {"bytea", -3, 255, "'", "'", null, 1, 0, 2, null, 0, null, null, null, null, -3, null, null, 0 },
            {"varchar", 12, 255, "'", "'", "max. length", 1, 1, 3, null, 0, null, null, null, null, -9, null, null, 0 },
            {"char", -8, 255, "'", "'", "max. length", 1, 1, 3, null, 0, null, null, null, null, -8, null, null, 0 },
            {"varchar", -9, 255, "'", "'", "max. length", 1, 1, 3, null, 0, null, null, null, null, -9, null, null, 0 },
            {"varchar", -10, 8190, "'", "'", null, 1, 1, 3, null, 0, null, null, null, null, -10, null, null, 0 },
            {"text", -10, 8190, "'", "'", null, 1, 1, 3, null, 0, null, null, null, null, -10, null, null, 0 },
            {"uuid", -11, 37, "'", "'", null, 1, 0, 2, null, 0, null, null, null, null, -11, null, null, 0 },

            // Added:
            { "bpchar", -8, 65535, "'", "'", "max. length", 1, 1, 3, null, 0, null, null, null, null, -8, null, null, 0 },
            { "bpchar", -10, 8190, "'", "'", null, 1, 1, 3, null, 0, null, null, null, null, -10, null, null, 0 } })
    in 
        if (debug <> true) then SQLGetTypeInfoTable else
            let
                // Outputting the entire table might be too large, and result in the value being truncated.
                // We can output a row at a time instead with Table.TransformRows()
                rows = Table.TransformRows(SQLGetTypeInfoTable, each Diagnostics.LogValue("SQLGetTypeInfo: " & _[TYPE_NAME], _)),
                toTable = Table.FromRecords(rows)
            in
                Value.ReplaceType(toTable, Value.Type(SQLGetTypeInfoTable))
;


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
SQLColumns = (debug) =>
    let 
        SQLColumnsTable = (catalogName, schemaName, tableName, columnName, source) =>
            if (debug <> true) then source else
                // the if statement conditions will force the values to evaluated/written to diagnostics
                if (Diagnostics.LogValue("SQLColumns.TableName", tableName) <> "***" and Diagnostics.LogValue("SQLColumns.ColumnName", columnName) <> "***") then
                    let
                        // Outputting the entire table might be too large, and result in the value being truncated.
                        // We can output a row at a time instead with Table.TransformRows()
                        rows = Table.TransformRows(source, each Diagnostics.LogValue("SQLColumns: ", _)),
                        toTable = Table.FromRecords(rows)
                in
                    Value.ReplaceType(toTable, Value.Type(source))
            else
                source
    in
        SQLColumnsTable
;

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



// Data Source Kind description. 
DenodoForPowerBI = [
    // TestConnection is required to enable the connector through the Gateway. The function is called when the user is configuring credentials for your source, and used to ensure they are valid. 
    // Note that, according to Microsoft documentation (https://github.com/Microsoft/DataConnectors/blob/master/docs/m-extensions.md#implementing-testconnection-for-gateway-support), 
    // the method for implementing TestConnection functionality is likely to change prior while the Power BI Custom Data Connector functionality is in preview.
    TestConnection = (dataSourcePath) => 
        // As our data source function has a parameter (non-URL parameter) then the dataSourcePath value will be a json string containing it.
        let
            json = Json.Document(dataSourcePath),
            DSN = json[DSN]
        in
            { "Denodo.Contents", DSN },
    Authentication = [
        UsernamePassword = [],
        Windows = []
    ],
    Label = Extension.LoadString("DataSourceLabel")      // Loaded from resources.resx
];

// Data Source UI publishing description. It provides the Power Query UI the information it needs to expose this extension in the Get Data dialog.
DenodoForPowerBI.Publish = [

    Beta = false,
    Category = "Database",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") }, // From resources.resx
    LearnMoreUrl = "https://www.denodo.com/",

    SupportsDirectQuery = true,                                                               // Enable DirectQuery support

    SourceImage = DenodoForPowerBI.Icons,
    SourceTypeImage = DenodoForPowerBI.Icons
];


DenodoForPowerBI.Icons = [
    Icon16 = { Extension.Contents("DenodoForPowerBI16.png"), Extension.Contents("DenodoForPowerBI20.png"), Extension.Contents("DenodoForPowerBI24.png"), Extension.Contents("DenodoForPowerBI32.png") },
    Icon32 = { Extension.Contents("DenodoForPowerBI32.png"), Extension.Contents("DenodoForPowerBI40.png"), Extension.Contents("DenodoForPowerBI48.png"), Extension.Contents("DenodoForPowerBI64.png") }
];


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
Diagnostics.LogValue = Diagnostics[LogValue];