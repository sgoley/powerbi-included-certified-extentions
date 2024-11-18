//==================================================================================================
///  @file AmazonAthena.pq
///
///  Implementation of AmazonAthena.pq connector
///
///  Copyright (C) 2021 Simba Technologies Incorporated.
//==================================================================================================

[Version = "1.2.6"] 
section AmazonAthena;
Config_SqlConformance = SQL_SC[SQL_SC_SQL92_FULL];  // null, 1, 2, 4, 8

redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";

[DataSource.Kind="AmazonAthena", Publish="AmazonAthena.UI"]

shared AmazonAthena.Databases = Value.ReplaceType(AthenaImpl, AthenaType);

AthenaType = type function (
  
   DSN as (type text meta [
   Documentation.FieldCaption = "DSN",
   Documentation.FieldDescription = "It can be an user or system data source name",
   Documentation.SampleValues = {"Simba Athena"}
   ]),
   optional role as (type text meta [
   Documentation.FieldCaption = "Role",
   Documentation.FieldDescription = "The role value to be used while connecting through AAD."
   ]),

   optional options as (type [
    ] meta [
            Documentation.FieldCaption = "Advanced options"
        ])
   )
   as table meta [
   Documentation.Name = "Amazon Athena",
   Documentation.LongDescription = "This function sends basic authentication info"
   ];
   
AthenaImpl = (DSN as text, optional role as nullable text,optional options as record) =>
    let
        // For a complex data source configuration that requires a fully customizable configuration 
        // dialog, pre-configure a system DSN, and have the function take in the DSN name as a text 
        // field.
        //
        // Note: The UI for the built-in Odbc.DataSource function provides a dropdown that allows 
        // the user to select a DSN, this functionality is not available through extensibility.
        BaseConnectionString = [
            DSN = DSN
        ],
        Credential = Extension.CurrentCredential(),
        AuthKind = Credential[AuthenticationKind],
        roleValue = ValidateRole(AuthKind, role),
        ConnectionString = AddConnectionStringOption(BaseConnectionString, "preferred_role", roleValue),
		Options =
            if Credential[AuthenticationKind] = "OAuth" or Credential[AuthenticationKind] = "OAuth2"  then
                [ 
                    CredentialConnectionString  = [
                     AuthenticationType = "JWT",
                     web_identity_token = Credential[access_token]

                ]]
            else
                [],     
        AddConnectionStringOption = (options as record, name as text, value as any) as record =>
            if value = null then
                options
            else
                Record.AddField(options, name, value),

        ValidateRole = (authKind as text, optional roleValue as any) as any =>
            if authKind = "OAuth" or authKind = "OAuth2" then
                if roleValue = null then
                    error Extension.LoadString("MissingRoleError")
                else
                    roleValue
            else
                roleValue,
        SQLGetInfo = [
            //add additional non-configuration handled overrides here
            SQL_AGGREGATE_FUNCTIONS = 0xFF,
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
                        Odbc.Flags(driverDefault),
            SQL_SQL_CONFORMANCE = Config_SqlConformance
            ],
        SQLGetFunctions = [
                        SQL_CONVERT_FUNCTIONS = 0x2 /* SQL_FN_CVT_CAST */,
                        SQL_API_SQLBINDPARAMETER = false
                    ],

         Connect = 
            Odbc.DataSource(ConnectionString, [
            // A logical value that sets whether to view the tables grouped by their schema names. 
            // When set to false, tables will be displayed in a flat list under each database.
            HierarchicalNavigation = true,
            // A logical value that controls whether your connector allows native SQL statements to 
            // be passed in by a query using the Value.NativeQuery() function.
            HideNativeQuery = true,
            // Allows conversion of numeric and text types to larger types if an operation would 
            // cause the value to fall out of range of the original type.
            TolerateConcatOverflow = true,
            // A logical value that determines whether to produce a SQL Server compatible 
            // connection string when using Windows Authentication—Trusted_Connection=Yes.
            SqlCompatibleWindowsAuth = false,
            // A logical value that enables client-side connection pooling for the ODBC driver. 
            // Most drivers will want to set this value to true.
            ClientConnectionPooling= true,
            // Allows the M engine to select a compatible data type when conversion between two 
            // specific numeric types isn't declared as supported in the SQL_CONVERT_* capabilities.
            SoftNumbers = true,
            // These values should be set by previous steps
            SQLGetFunctions = SQLGetFunctions, 
            SQLColumns = (catalogName, schemaName, tableName, columnName, source) =>
                let
                    OdbcSqlType.FLOAT = 7,
                    OdbcSqlType.DOUBLE = 8,
                    FixDataType = (dataType) =>
                        if dataType = OdbcSqlType.FLOAT then
                            OdbcSqlType.DOUBLE 
                        else
                            dataType,
                            
                    FixTypeName = (typeName) =>
                        if typeName = "float" then
                            "double"
                        else
                            typeName,
                    Transform = Table.TransformColumns(source, { { "DATA_TYPE", FixDataType }, {"TYPE_NAME", FixTypeName} })
                     in 
                        Transform,
            SqlCapabilities = [
               // A logical value that indicates that statements should be prepared using 
                // SQLPrepare.
                PrepareStatements = true,
                // A logical value that indicates the driver supports the TOP clause to limit the 
                // number of returned rows.
                SupportsTop = false,
                
                //This SQL dialect supports a LIMIT specifier to limit the number of rows returned.
                LimitClauseKind = LimitClauseKind.Limit,

                // Conformance level is set to SQL_SC_SQL92_FULL 
                Sql92Conformance = 8,
                GroupByCapabilities = SQL_GB[SQL_GB_COLLATE],
                // A logical value that indicates whether the generated SQL should include numeric 
                // literals values. When set to false, numeric values will always be specified 
                // using Parameter Binding.
                SupportsNumericLiterals = true,
                // A logical value that indicates whether the generated SQL should include string 
                // literals values. When set to false, string values will always be specified using 
                // Parameter Binding.
                SupportsStringLiterals = true,
                // A logical value that indicates whether the generated SQL should include date 
                // literals values. When set to false, date values will always be specified using 
                // Parameter Binding.
                SupportsOdbcDateLiterals = true,
                // A logical value that indicates whether the generated SQL should include time 
                // literals values. When set to false, time values will always be specified using 
                // Parameter Binding.
                SupportsOdbcTimeLiterals = true,
                // A logical value that indicates whether the generated SQL should include 
                // timestamp literals values. When set to false, timestamp values will always be 
                // specified using Parameter Binding.
                SupportsOdbcTimestampLiterals = true,

                FractionalSecondsScale = 3,

                Sql92Translation = "PassThrough"
            
            ],
            SupportsIncrementalNavigation = true,
            SQLGetInfo = SQLGetInfo            
        ] & Options )
    in
        Connect;

ResourcePathSeparator = ";";
// Data Source Kind description
AmazonAthena = [

        Description = "AmazonAthena",
        Type = "Custom",
        MakeResourcePath = (DSN, optional role) => if role = null
            then DSN
            else DSN  & ResourcePathSeparator & role,
        ParseResourcePath = (resourcePath as text) => Text.Split(resourcePath, ResourcePathSeparator),
       ParseResourcePathTC = (resourcePath as text) => Text.Split(resourcePath, ResourcePathSeparator),
       TestConnection = (resourcePath as text) => {  "AmazonAthena.Databases" } & ParseResourcePathTC(resourcePath),

    // An extension can support one or more kinds of Authentication. Each authentication kind is a 
    // different type of credential. The authentication UI displayed to end users in Power Query is 
    // driven by the type of credential(s) that an extension supports.
    Authentication = [
        
        Aad = [
            AuthorizationUri = "https://login.microsoftonline.com/common/oauth2/authorize",
            Resource = "https://analysis.windows.net/powerbi/connector/AmazonAthena",
            Label ="AAD Authentication"
        ],

        // The Implicit (anonymous) authentication kind does not have any fields.
     Implicit = [
            Label ="Use Data Source Configuration"
        ]
    ]
];
// Data Source UI publishing description
AmazonAthena.UI = [
    // (optional) When set to true, the UI will display a Preview/Beta identifier next to your 
    // connector name and a warning dialog that the implementation of the connector is subject to 
    // breaking changes.
    Beta = false,
    // Where the extension should be displayed in the Get Data dialog. Currently the only category 
    // values with special handing are Azure and Database. All other values will end up under the Other category.
    Category = "Database",
    // List of text items that will be displayed next to the data source's icon in the Power BI Get 
    // Data dialog.
    ButtonText = { "Amazon Athena", "Connnect to Amazon Athena" },
    // (optional) Enables Direct Query for your extension. This is currently only supported for 
    // ODBC extensions.
    SupportsDirectQuery = true,
       SourceImage = AmazonAthena.Icons,
   SourceTypeImage = AmazonAthena.Icons,
    NativeQueryProperties = [
    navigationSteps = {
        [
            indices = {
                   [     
                        displayName = "Database",
                        indexName = "Kind"
                    ]
                    },
            access = "Data"
            
        ]        
    }
   ,
    nativeQueryOptions = [
            EnableFolding = true
        ]
]
];


AmazonAthena.Icons = [
   Icon16 = { Extension.Contents("Athena16.png"), Extension.Contents("Athena20.png"), Extension.Contents("Athena24.png"), Extension.Contents("Athena32.png")},
   Icon32 = { Extension.Contents("Athena32.png"), Extension.Contents("Athena40.png"), Extension.Contents("Athena48.png"), Extension.Contents("Athena64.png")}
];

// 
// Load common library functions
// 
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

ODBC = Extension.LoadFunction("OdbcConstants.pqm");

// Expose the constants and bitfield helpers
Odbc.Flags= ODBC[Flags];
SQL_SC = ODBC[SQL_SC];
SQL_GB = ODBC[SQL_GB];
SQL_TSI= ODBC[SQL_TSI];
