// This file contains your Data Connector logic
[Version = "1.0.0"]
section ExactOnlinePremium;

oauth_client_id = "04ea1ba3-216e-46f3-9d7e-3c5c107c8e00";
oauth_client_secret = "AzwhRzTw5JWd";

jsonFileName = "ExactOnlinePremium.config.json";
configJson = Json.Document(Text.FromBinary(Extension.Contents(jsonFileName)));
enableDebugLogging = false;

[DataSource.Kind="ExactOnlinePremium", Publish="ExactOnlinePremium.Publish"]
shared ExactOnlinePremium.Contents = Value.ReplaceType(ExactOnlinePremiumImpl, ExactOnlinePremiumType);

ExactOnlinePremiumType = type function (
  )
  as table meta [
    Documentation.Name = Extension.LoadString("TitleText"),
    Documentation.LongDescription = Extension.LoadString("DescriptionText")
  ];

ExactOnlinePremiumImpl = () =>
    let
        // From configJson, combine api_url and userinfo_rel_path to obtain user info
        userInfoText = LogValue("UserInfo", Text.FromBinary(Web.Contents(configJson[api_url], [
            RelativePath = LogValue("UserRelativePath", configJson[userinfo_rel_path]),
            Query = [
                #"$select" = "CurrentDivision"
            ],
            Headers = [
                Accept = "application/json"
            ]
        ]))),
        userInfoJson = Json.Document(userInfoText),
        userInfo = List.First(userInfoJson[d][results]),

        // We only require the Division field from the current user
        division = LogValue("CurrentDivision", userInfo[CurrentDivision]),
        divisionText = Text.From(division),

        // Combine api_url and connection_rel_path to get the Division's database connection info
        rel_path = Replacer.ReplaceText(configJson[connection_rel_path], "{Division}", divisionText),
        dbInfoText = Text.FromBinary(Web.Contents(configJson[api_url], [
            RelativePath = LogValue("DbQueryUrl", rel_path),
            Headers = [
                Accept = "application/json"
            ]
        ])),

        dbInfoJson = Json.Document(dbInfoText),
        dbInfo = List.First(dbInfoJson[d][results]),
        server = dbInfo[Server],
        database = dbInfo[Database],

        // Create the ODBC Connection String.
        // For the ODBC.DataSource function, it can be passed in as a record, or an actual text value.
        // When using a record, M will take care of the formatting.
        ConnectionString = LogValue("ConnectionString", [
            Driver = "ODBC Driver 18 for SQL Server",
            Server = server,
            Database = database,
            ApplicationIntent = dbInfo[ApplicationIntent]
        ]),

        // Credentials are passed to the ODBC driver using the CredentialConnectionString field.
        CredentialConnectionString = [
              UID = dbInfo[UserName],
              PWD = dbInfo[Password],
              Authentication = "SqlPassword"
        ],

        // The options record allows us to set the credential connection string properties,
        // and override default behaviors.
        ConnectionOptions = [
            // Credential-specific part of the connection string
            CredentialConnectionString = CredentialConnectionString,

            // Connection Pooling: Most drivers will want to set this value to true.
            ClientConnectionPooling = true,

            // HierarchialNavigation:
            //   When true, show navigation tree as Database -> Schema -> Table.
            //   When false, show tables as flat list using fully qualified names.
            HierarchicalNavigation = true,

            // Use the SqlCapabilities record to specify driver capabilities that are not
            // discoverable through ODBC 3.8, and to override capabilities reported by
            // the driver. 
            SqlCapabilities = [
                SupportsTop = true,
                Sql92Conformance = 8 /* SQL_SC_SQL92_FULL */,
                GroupByCapabilities = 4 /* SQL_GB_NO_RELATION */,
                FractionalSecondsScale = 3
            ],

            SoftNumbers = true,

            HideNativeQuery = true,

            // Use the SQLGetInfo record to override values returned by the driver.
            SQLGetInfo = [
                SQL_SQL92_PREDICATES = 0x0000FFFF,
                SQL_AGGREGATE_FUNCTIONS = 0xFF
            ]
        ],

        // Connect to the ODBC data source.
        OdbcDataSource = Odbc.DataSource(ConnectionString, ConnectionOptions),

        // The first level of the navigation table will be the name of the database the user
        // passed in. Rather than repeating it again, we'll select it ({[Name = database]}) 
        // and access the next level of the navigation table.
        Database = OdbcDataSource{[Name = database]}[Data]
    in
        Database;

// Data Source Kind description
ExactOnlinePremium = [
    TestConnection = (dataSourcePath) => { "ExactOnlinePremium.Contents" }, 
    Authentication = [       
        OAuth = [
            StartLogin  = OAuth.StartLogin,
            FinishLogin = OAuth.FinishLogin,
            Refresh     = OAuth.Refresh,
            Label       = Extension.LoadString("LoginText")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
ExactOnlinePremium.Publish = [
    Beta = true,
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    Category = "Database",
    LearnMoreUrl = "https://support.exactonline.com/community/s/knowledge-base#All-All-HNO-Task-premium-powerbi-powerbi-install-connectort",
    SourceImage = ExactOnlinePremium.Icons,
    SourceTypeImage = ExactOnlinePremium.Icons,
    SupportsDirectQuery = true
];

ExactOnlinePremium.Icons = [
    Icon16 = { Extension.Contents("ExactOnlinePremium16.png"), Extension.Contents("ExactOnlinePremium20.png"), Extension.Contents("ExactOnlinePremium24.png"), Extension.Contents("ExactOnlinePremium32.png") },
    Icon32 = { Extension.Contents("ExactOnlinePremium32.png"), Extension.Contents("ExactOnlinePremium40.png"), Extension.Contents("ExactOnlinePremium48.png"), Extension.Contents("ExactOnlinePremium64.png") }
];

LogValue = (prefix, value, optional delayed) =>
    if (enableDebugLogging)
    then Diagnostics.LogValue(prefix, value, delayed)
    else value;

FillPlaceholder = (input as text, optional placeholder as text, optional value as text) =>
    if ((placeholder = null and value = null) or (Text.Length(placeholder) = 0 and Text.Length(value) = 0))
    then input
    else Text.Replace(input, placeholder, value);

FillPlaceholders = (input as text, optional placeholders as list) =>
    if (List.Count(placeholders) > 1)
    then @FillPlaceholders(FillPlaceholder(input, List.First(placeholders), List.First(List.Skip(placeholders,1))), List.Skip(placeholders, 2))
    else input;

// Include pqm files, with optional replace of client ID/secret placeholders
Extension.LoadFunction = (name as text, optional placeholders as list) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary),
        replaced = if (placeholders = null) then asText else FillPlaceholders(asText, placeholders)
    in
        Expression.Evaluate(replaced, #shared);

Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue   = Diagnostics[LogValue];
Diagnostics.LogFailure = Diagnostics[LogFailure];

OAuth = Extension.LoadFunction("OAuth.pqm", {"{{CLIENTID}}", oauth_client_id, "{{CLIENTSECRET}}", oauth_client_secret});
OAuth.StartLogin  = OAuth[StartLogin];
OAuth.FinishLogin = OAuth[FinishLogin];
OAuth.Refresh     = OAuth[Refresh];
