[Version = "1.0.1"]
section StarburstPresto;

//Indicates the level of SQL-92 supported by the driver.
Config_SqlConformance = 8;

[DataSource.Kind="StarburstPresto", Publish="StarburstPresto.Publish"]
shared StarburstPresto.Contents = Value.ReplaceType(StarburstPrestoImpl, StarburstPrestoType);

// Wrapper function to provide additional UI customization.
StarburstPrestoType = type function (
        Host as (type text meta [
            Documentation.FieldCaption = "Host",
            Documentation.FieldDescription = "The hostname of the Starburst Enterprise server.",
            Documentation.SampleValues = { "starburst.example.com" }
        ]),
        Port as (type number meta [
            Documentation.FieldCaption = "Port",
            Documentation.FieldDescription = "The port the server is running on.",
            Documentation.SampleValues = { 8080 }
        ])
    )
    as table meta [
        Documentation.Name = "Starburst Enterprise"
    ];

StarburstPrestoImpl = (Host as text, Port as number) as table =>
    let
        Credential = Extension.CurrentCredential(),
        AuthenticationMode = Credential[AuthenticationKind],

        // Sets connection string properties for authentication.
        CredentialConnectionString =
            if AuthenticationMode = "UsernamePassword" then
                [
                    AuthenticationType = "LDAP Authentication",
                    UID = Credential[Username],
                    PWD = Credential[Password]
                ]
            else if AuthenticationMode = "Windows" then
                [
                    AuthenticationType = "Kerberos Authentication",
                    UseGSSAPI = 0,
                    UseOnlySSPI = 1
                ]
            else // "else" required; AuthenticationMode will always be "Implicit" at this point.
                [
                    AuthenticationType = "No Authentication"
                ],

        // Sets connection string properties for encrypted connections.
        EncryptedConnectionString =
            if Credential[EncryptConnection] = null or Credential[EncryptConnection] = true then
                [
                    SSL = 1,
                    UseSystemTrustStore = 1
                ]
            else
                [
                    SSL = 0
                ],

        ConnectionString = [
            Driver = "Starburst Presto ODBC Driver",
            Host = Host,
            Port = Port,
            MultiSubnetFailover = "Yes",
            ApplicationIntent = "ReadOnly",
            AllowHostNameCNMismatch = 1,
            AllowSelfSignedServerCert = 1,
            APP = "PowerBICustomConnector"
        ],

        DefaultConfig = BuildOdbcConfig(),

        SqlCapabilities = DefaultConfig[SqlCapabilities] & [
            FractionalSecondsScale = 3
        ],

        SQLGetInfo = DefaultConfig[SQLGetInfo] & [
            SQL_SQL92_PREDICATES = ODBC[SQL_SP][All],
            SQL_AGGREGATE_FUNCTIONS = ODBC[SQL_AF][All]
        ],

       // Fix for data type mismatch.
       SQLColumns = (catalogName, schemaName, tableName, columnName, source) =>
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

        // Transforms TOP queries into LIMIT queries.
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

        OdbcDatasource = Odbc.DataSource(ConnectionString & CredentialConnectionString, [
            // View the tables grouped by their schema names.
            HierarchicalNavigation = true,

            // Controls whether your connector allows native SQL statements.
            HideNativeQuery = true,

            // Allows the M engine to select a compatible data type.
            SoftNumbers = true,

            // Allows conversion of numeric and text types to larger types.
            TolerateConcatOverflow = true,

            // Enables client-side connection pooling for the ODBC driver.
            ClientConnectionPooling = true,

            // Handlers for ODBC driver capabilities.
            SqlCapabilities = SqlCapabilities,
            AstVisitor = AstVisitor,
            SQLColumns = SQLColumns,
            SQLGetInfo = SQLGetInfo,
            OnError = OnOdbcError,

            // Connection string properties used for encrypted connections.
            CredentialConnectionString = EncryptedConnectionString
        ])
    in
        OdbcDatasource;

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
            error Error.Record("DataSource.Error", "The Starburst Enterprise ODBC driver is not installed on the host. Please install the appropriate driver. " & ConnectionHostPort)
        else if IsEncryptionError then
            // Report error to trigger option to fallback to unencrypted connection.
            error Extension.CredentialError(Credential.EncryptionNotSupported)
        else if IsODBCUnreachable then
            error Error.Record("DataSource.Error", "Could not connect to server. Please double check your ODBC configuration. " & ConnectionHostPort)
        else
            error errorRecord;

// Data Source Kind description.
StarburstPresto = [
    Label = Extension.LoadString("DataSourceLabel"),

    SupportsEncryption = true,
    Authentication = [
        Implicit = [],
        UsernamePassword = [
            Label = "LDAP"
        ],
        Windows = [
            Label = "Kerberos"
        ]
    ],

    // Needed for use with Power BI Service.
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            Host = json[Host],
            Port = json[Port]
        in
            { "StarburstPresto.Contents", Host, Port }
];

// Data Source UI publishing description.
StarburstPresto.Publish = [
    Beta = false,
    Category = "Other",
    SupportsDirectQuery = true,

    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://www.starburst.io/",

    SourceImage = StarburstPresto.Icons,
    SourceTypeImage = StarburstPresto.Icons
];

StarburstPresto.Icons = [
    Icon16 = { Extension.Contents("StarburstEnterprise16.png"), Extension.Contents("StarburstEnterprise20.png"), Extension.Contents("StarburstEnterprise24.png"), Extension.Contents("StarburstEnterprise32.png") },
    Icon32 = { Extension.Contents("StarburstEnterprise32.png"), Extension.Contents("StarburstEnterprise40.png"), Extension.Contents("StarburstEnterprise48.png"), Extension.Contents("StarburstEnterprise64.png") }
];

BuildOdbcConfig = () as record =>
    let
        defaultConfig = [
            SqlCapabilities = [],
            SQLGetInfo = []
        ],

        withSqlConformance =
            if (Config_SqlConformance <> null) then
                let
                    caps = defaultConfig[SQLGetInfo] & [
                        SQLGetInfo = [
                            SQL_SQL_CONFORMANCE = Config_SqlConformance
                        ]
                    ]
                in
                    defaultConfig & caps
            else
                defaultConfig
    in
        withSqlConformance;

// Loads functions from another project file.
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

ODBC = Extension.LoadFunction("OdbcConstants.pqm");
Odbc.Flags = ODBC[Flags];
