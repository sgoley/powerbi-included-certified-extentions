[Version = "5.0.1"]
section Funnel;

[DataSource.Kind="Funnel", Publish="Funnel.Publish"]
shared Funnel.Contents = Value.ReplaceType(BuildNavigationTable, NavigationTableType); //Means: run FunnelAccounts as NavContentsType (metadata)

   
// Data Source Kind description
Funnel = [
    TestConnection = (dataSourcePath) => { "Funnel.Contents"},
    Authentication = [
        OAuth = [
            StartLogin = OAuth.StartLogin,
            FinishLogin = OAuth.FinishLogin,
            Refresh = OAuth.Refresh,
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
Funnel.Publish = [
    Beta = false,
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ConnectorName"), Extension.LoadString("ConnectorDescription") },
    LearnMoreUrl = "https://help.funnel.io/en/articles/6099182",
    SourceImage = Funnel.Icons,
    SourceTypeImage = Funnel.Icons
];

Funnel.Icons = [
    Icon16 = { Extension.Contents("Funnel16.png"), Extension.Contents("Funnel20.png"), Extension.Contents("Funnel24.png"), Extension.Contents("Funnel32.png") },
    Icon32 = { Extension.Contents("Funnel32.png"), Extension.Contents("Funnel40.png"), Extension.Contents("Funnel48.png"), Extension.Contents("Funnel64.png") }
];


Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

OAuth = Extension.LoadFunction("OAuth.pqm");
OAuth.StartLogin = OAuth[StartLogin];
OAuth.FinishLogin = OAuth[FinishLogin];
OAuth.Refresh = OAuth[Refresh];
NavigationTable = Extension.LoadFunction("NavigationTable.pqm");
NavigationTableType = NavigationTable[NavigationTableType];
BuildNavigationTable = NavigationTable[BuildNavigationTable];