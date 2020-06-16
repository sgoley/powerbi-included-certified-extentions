// This file contains your Data Connector logic
[Version = "1.0.4"]
section Kyligence;

EnableTraceOutput = true;

[DataSource.Kind="Kyligence", Publish="Kyligence.Publish"]

shared Kyligence.Database = Value.ReplaceType(KyligenceImpl, KyligenceType);

KyligenceType = type function (
    Server as (type text meta [
        Documentation.FieldCaption = "Server",
        Documentation.FieldDescription = "Your Kylingece service host address."
    ]),
    Port as (type text meta [
        Documentation.FieldCaption = "Port",
        Documentation.FieldDescription = "Your Kylingece service port."
    ]),
    Project as (type text meta [
        Documentation.FieldCaption = "Project",
        Documentation.FieldDescription = "Your Kylingece project."
    ]),
    optional options as (type record meta [
        Documentation.FieldCaption = "Options",
        Documentation.FieldDescription = "Options"
    ])) as table meta [
        Documentation.Name = "Kyligence",
        Documentation.LongDescription = "Connect your Kyligence"
    ];

KyligenceImpl = (Server as text, Port as text, Project as text, optional options as record) as table =>
       
    let
        ConnectionString =
        [
            Server = Diagnostics.LogValue("Accessing Server", Server),
			Port = Diagnostics.LogValue("Accessing Port", Port),
            Driver = "KyligenceODBCDriver",
            Project = Diagnostics.LogValue("Accessing Project", Project)
        ],

        // Odbc.DataSource will automatically inherit the Windows Auth credential from the extension
        OdbcDataSource = Odbc.DataSource(ConnectionString, [
            AstVisitor = [
                        LimitClause = (skip, take) =>
                            if skip = 0 and take = null then
                                ...
                            else
                                if skip = 0 then
                                    let

                                    in 

                                    [
                                        Text = Text.Format("LIMIT #{0}", { take }),
                                        Location = "AfterQuerySpecification"
                                    ]
                                else
                                    let
                                        
                                    in
                                        [
 
                                            Text = Text.Format("LIMIT #{0} OFFSET #{1}", { take, skip }),
                                            Location = "AfterQuerySpecification"
                                        ]
            ],
            HierarchicalNavigation = true,
            ClientConnectionPooling = true,
			HideNativeQuery = true,
            SqlCapabilities = [
                SupportsTop = false,
                Sql92Conformance = 8 /* SQL_SC_SQL92_FULL */,
                FractionalSecondsScale = 3,
                SupportsNumericLiterals = true,
                SupportsStringLiterals = true,
                SupportsOdbcDateLiterals = true,
                SupportsOdbcTimestampLiterals = true
            ],
            SQLGetFunctions = [
                SQL_API_SQLBINDPARAMETER = false
            ],
            SQLGetInfo = [
                SQL_SQL92_PREDICATES = 0x00001E07,
                SQL_AGGREGATE_FUNCTIONS = 0x7F,
                SQL_SQL92_RELATIONAL_JOIN_OPERATORS = 0x0000037E,
				SQL_CATALOG_USAGE = 0x00
            ]
        ]),
        Database = OdbcDataSource
    in
        Database;

// Data Source Kind description
Kyligence = [
    // Set the TestConnection handler to enable gateway support.
    TestConnection = (dataSourcePath) => 
        let
            json = Json.Document(dataSourcePath),
            server = json[Server],   // name of function parameter
            port = json[Port],
            project = json[Project]
        in
            { "Kyligence.Database", server,port,project },
    // Set supported types of authentication
    Authentication = [
        UsernamePassword = []
    ],
    Label = "Connect your Kyligence",
	Description = "Kyligence"
];

// Data Source UI publishing description
Kyligence.Publish = [
    Beta = false,
	SupportsDirectQuery = true,
    Category = "Database",
    ButtonText = { "Kyligence", "Connect your Kyligence" },
    LearnMoreUrl = "http://kyligence.io/",
    SourceImage = Kyligence.Icons,
    SourceTypeImage = Kyligence.Icons
];

Kyligence.Icons = [
    Icon16 = { Extension.Contents("Kyligence16.png"), Extension.Contents("Kyligence20.png"), Extension.Contents("Kyligence24.png"), Extension.Contents("Kyligence32.png") },
    Icon32 = { Extension.Contents("Kyligence32.png"), Extension.Contents("Kyligence40.png"), Extension.Contents("Kyligence48.png"), Extension.Contents("Kyligence64.png") }
];

Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = if (EnableTraceOutput) then Diagnostics[LogValue] else (prefix, value) => value;