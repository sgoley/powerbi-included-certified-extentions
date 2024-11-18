// This file contains your Data Connector logic
[Version = "1.3.0"]
section FactSetAnalytics;

API_HOST = Extension.LoadString("ApiHost");
LOOKUPS_URL = API_HOST & "analytics/lookups/v2/";
LOOKUPS_V3_URL = API_HOST & "analytics/lookups/v3";
ENGINES_URL = API_HOST & "analytics/engines/v2/";
ENGINES_V3_URL = API_HOST & "analytics/engines/";

ConnectorHeaderName = "X-Connector-Version";
ConnectorHeaderValue = Text.Combine({"powerbi/analytics/", Extension.LoadString("Version")});

// OAuth Authentication configurations
clientId = Extension.LoadString("OAuthClientId");
redirectUri = Extension.LoadString("OAuthRedirectUri");
oauthConfig = GetOAuthConfigurations(Extension.LoadString("OAuthConfigurationUrl"));
authorizationEndpoint = oauthConfig[authorization_endpoint];
tokenEndpoint =  oauthConfig[token_endpoint];
revocationEndpoint = oauthConfig[revocation_endpoint];
scope = if Extension.LoadString("OAuthScopes") = null then "" else Extension.LoadString("OAuthScopes");
windowWidth = 1200;
windowHeight = 1000;

calcUnitId = "1";

// Data Source Kind description
FactSetAnalytics = [
    TestConnection = (dataSourcePath) as list => { "FactSetAnalytics.AuthenticationCheck" },
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh= Refresh,
            Label = Extension.LoadString("OAuthAuthenticationLabel")
        ],
        UsernamePassword = [
            UsernameLabel = "Username-Serial",
            PasswordLabel = "API Key",
            Label = Extension.LoadString("APIKeyAuthenticationLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
FactSetAnalytics.Publish = [
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://developer.factset.com/",
    SourceImage = Factset.Icons,
    SourceTypeImage = Factset.Icons
];

Factset.Icons = [
    Icon16 = { Extension.Contents("Factset16.png"), Extension.Contents("Factset20.png"), Extension.Contents("Factset24.png"), Extension.Contents("Factset32.png") },
    Icon32 = { Extension.Contents("Factset32.png"), Extension.Contents("Factset40.png"), Extension.Contents("Factset48.png"), Extension.Contents("Factset64.png") }
];

// Authentication Check
[DataSource.Kind="FactSetAnalytics"]
shared FactSetAnalytics.AuthenticationCheck = () =>
    let
        response = Web.Contents(LOOKUPS_URL & "engines/pa/frequencies", [Headers = Record.AddField([#"Accept" = "application/json"], ConnectorHeaderName, ConnectorHeaderValue )])
    in
        response;

// Build the Navigation Table 
[DataSource.Kind="FactSetAnalytics", Publish="FactSetAnalytics.Publish"]
shared FactSetAnalytics.Functions = () as table =>
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"Datastore v1", "v1Datastore", DataStoreV1NavTable(), "Folder", "Folder", false},
                {"Engines v2", "v2", EnginesV2NavTable(), "Folder", "Folder", false},
                {"Engines v3", "v3", EnginesV3NavTable(), "Folder", "Folder", false}                
            }
        ),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

EnginesV2NavTable = () as table =>
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"PA", "PA", PANavTable(), "Folder", "Folder", false},
                {"SPAR", "SPAR", SPARNavTable(), "Folder", "Folder", false},
                {"Vault", "Vault", VaultNavTable(), "Folder", "Folder", false},
                {"GetAccounts", "FactSetAnalytics.v2.GetAccounts", FactSetAnalytics.v2.GetAccounts, "Function", "Function", true}
            }
        ),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

PANavTable = () as table =>
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"RunPACalculation", "FactSetAnalytics.v2.RunPACalculation", FactSetAnalytics.v2.RunPACalculation, "Function", "Function", true},
                {"RunPAMultiPortCalculation", "FactSetAnalytics.v2.RunPAMultiPortCalculation", FactSetAnalytics.v2.RunPAMultiPortCalculation, "Function", "Function", true},
                {"GetPAColumns", "FactSetAnalytics.v2.GetPAColumns", FactSetAnalytics.v2.GetPAColumns, "Function", "Function", true},
                {"GetPAColumnById", "FactSetAnalytics.v2.GetPAColumnById", FactSetAnalytics.v2.GetPAColumnById, "Function", "Function", true},
                {"GetPAColumnStatistics", "FactSetAnalytics.v2.GetPAColumnStatistics", FactSetAnalytics.v2.GetPAColumnStatistics, "Function", "Function", true},
                {"GetPAComponents", "FactSetAnalytics.v2.GetPAComponents", FactSetAnalytics.v2.GetPAComponents, "Function", "Function", true},
                {"GetPAComponentById", "FactSetAnalytics.v2.GetPAComponentById", FactSetAnalytics.v2.GetPAComponentById, "Function", "Function", true},
                {"ConvertPADatesToAbsoluteFormat", "FactSetAnalytics.v2.ConvertPADatesToAbsoluteFormat", FactSetAnalytics.v2.ConvertPADatesToAbsoluteFormat, "Function", "Function", true},
                {"GetPADocuments", "FactSetAnalytics.v2.GetPADocuments", FactSetAnalytics.v2.GetPADocuments, "Function", "Function", true},
                {"PACurrencies", "FactSetAnalytics.v2.PACurrencies", FactSetAnalytics.v2.PACurrencies(), "Table", "Table", true},
                {"PAFrequencies", "FactSetAnalytics.v2.PAFrequencies", FactSetAnalytics.v2.PAFrequencies(), "Table", "Table", true},
                {"PAGroups", "FactSetAnalytics.v2.PAGroups", FactSetAnalytics.v2.PAGroups(), "Table", "Table", true}
            }
        ),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

SPARNavTable = () as table => 
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"RunSPARCalculation", "FactSetAnalytics.v2.RunSPARCalculation", FactSetAnalytics.v2.RunSPARCalculation, "Function", "Function", true},
                {"RunSPARMultiPortCalculation", "FactSetAnalytics.v2.RunSPARMultiPortCalculation", FactSetAnalytics.v2.RunSPARMultiPortCalculation, "Function", "Function", true},
                {"GetSPARComponents", "FactSetAnalytics.v2.GetSPARComponents", FactSetAnalytics.v2.GetSPARComponents, "Function", "Function", true},
                {"GetSPARDocuments", "FactSetAnalytics.v2.GetSPARDocuments", FactSetAnalytics.v2.GetSPARDocuments, "Function", "Function", true},
                {"SPARFrequencies", "FactSetAnalytics.v2.SPARFrequencies", FactSetAnalytics.v2.SPARFrequencies(), "Table", "Table", true}
            }
        ),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

VaultNavTable = () as table => 
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"RunVaultCalculation", "FactSetAnalytics.v2.RunVaultCalculation", FactSetAnalytics.v2.RunVaultCalculation, "Function", "Function", true},
                {"GetVaultComponents", "FactSetAnalytics.v2.GetVaultComponents", FactSetAnalytics.v2.GetVaultComponents, "Function", "Function", true},
                {"GetVaultComponentById", "FactSetAnalytics.v2.GetVaultComponentById", FactSetAnalytics.v2.GetVaultComponentById, "Function", "Function", true},
                {"GetVaultConfigurations", "FactSetAnalytics.v2.GetVaultConfigurations", FactSetAnalytics.v2.GetVaultConfigurations, "Function", "Function", true},
                {"GetVaultConfigurationById", "FactSetAnalytics.v2.GetVaultConfigurationById", FactSetAnalytics.v2.GetVaultConfigurationById, "Function", "Function", true},
                {"ConvertVaultDatesToAbsoluteFormat", "FactSetAnalytics.v2.ConvertVaultDatesToAbsoluteFormat", FactSetAnalytics.v2.ConvertVaultDatesToAbsoluteFormat, "Function", "Function", true},
                {"GetVaultDocuments", "FactSetAnalytics.v2.GetVaultDocuments", FactSetAnalytics.v2.GetVaultDocuments, "Function", "Function", true},
                {"VaultFrequencies", "FactSetAnalytics.v2.VaultFrequencies", FactSetAnalytics.v2.VaultFrequencies(), "Table", "Table", true}
            }
        ),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

// Run PA Calculation
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.RunPACalculation = Value.ReplaceType(runPACalculationImpl, runPACalculationType);

runPACalculationType = type function (
    optional componentid as (type text meta [
        Documentation.FieldCaption = "Component Identifier",
        Documentation.SampleValues = { "D1CDCCD48DF1B9B8FCFC227844DAF825114728C0BE17E48295D76C0E8B265F01" }
    ]),
    optional accountid as (type text meta [
        Documentation.FieldCaption = "Account Identifier",
        Documentation.SampleValues = { "BENCH:SP50" }
    ]),
    optional accountholdingsmode as (type text meta [
        Documentation.FieldCaption = "Account Holdings Mode",
        Documentation.SampleValues = { "B&H" }
    ]),
    optional benchmarkid as (type text meta [
        Documentation.FieldCaption = "Benchmark Identifier",
        Documentation.SampleValues = { "BENCH:R.1000" }
    ]),
    optional benchmarkholdingsmode as (type text meta [
        Documentation.FieldCaption = "Benchmark Holdings Mode",
        Documentation.SampleValues = { "B&H" }
    ]),
    optional startdate as (type text meta [ 
        Documentation.FieldCaption = "Start Date",
        Documentation.SampleValues = { "-2M" }
    ]),
    optional enddate as (type text meta [ 
        Documentation.FieldCaption = "End Date",
        Documentation.SampleValues = { "0" }
    ]),
    optional frequency as (type text meta [
        Documentation.FieldCaption = "Frequency",
        Documentation.SampleValues = { "Monthly" }
    ]),
    optional currencyisocode as (type text meta [
        Documentation.FieldCaption = "Currency ISO Code",
        Documentation.SampleValues = { "USD" }
    ]),
    optional componentdetail as (type text meta [
        Documentation.FieldCaption = "Component Detail",
        Documentation.AllowedValues = { "Securities", "Groups", "Totals", "" }
    ]))
    as table meta [ 
        Documentation.Name = "Run PA Calculation",
        Documentation.LongDescription = "This function runs the PA calculation for the specified parameters.",
        Documentation.Examples = {[
            Description = "Runs the PA calculation for the specified parameters.",
            Code = "= RunPACalculation(""D1CDCCD48DF1B9B8FCFC227844DAF825114728C0BE17E48295D76C0E8B265F01"",""BENCH:SP50"",""B&H"",""BENCH:DJII"",""B&H"",""-2M"",""0"",""Monthly"",""USD"")",
            Result = "#table(...)"
        ]}
    ];

runPACalculationImpl = (
    optional componentid as text, 
    optional accountid as text, 
    optional accountholdingsmode as text,
    optional benchmarkid as text, 
    optional benchmarkholdingsmode as text,
    optional startdate as text, 
    optional enddate as text, 
    optional frequency as text, 
    optional currencyisocode as text,
    optional componentdetail as text
) as table =>
    let
        accounts = if accountid is null and accountholdingsmode is null then null else {[
            id = accountid,
            holdingsmode = accountholdingsmode
        ]},
        benchmarks = if benchmarkid is null and benchmarkholdingsmode is null then null else {[
            id = benchmarkid,
            holdingsmode = benchmarkholdingsmode
        ]},
        table = FactSetAnalytics.v2.RunPAMultiPortCalculation(componentid, accounts, benchmarks, startdate, enddate, frequency, currencyisocode, componentdetail)
    in
        table;

[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.RunPAMultiPortCalculation = Value.ReplaceType(runPAMultiPortCalculationImpl, runPAMultiPortCalculationType);

runPAMultiPortCalculationType = type function (
    optional componentid as (type text meta [
        Documentation.FieldCaption = "Component Identifier",
        Documentation.SampleValues = { "D1CDCCD48DF1B9B8FCFC227844DAF825114728C0BE17E48295D76C0E8B265F01" }
    ]),
    optional accounts as (type list meta [
        Documentation.FieldCaption = "Accounts"
    ]),
    optional benchmarks as (type list meta [
        Documentation.FieldCaption = "Benchmarks"
    ]),
    optional startdate as (type text meta [ 
        Documentation.FieldCaption = "Start Date",
        Documentation.SampleValues = { "-2M" }
    ]),
    optional enddate as (type text meta [ 
        Documentation.FieldCaption = "End Date",
        Documentation.SampleValues = { "0" }
    ]),
    optional frequency as (type text meta [
        Documentation.FieldCaption = "Frequency",
        Documentation.SampleValues = { "Monthly" }
    ]),
    optional currencyisocode as (type text meta [
        Documentation.FieldCaption = "Currency ISO Code",
        Documentation.SampleValues = { "USD" }
    ]),
    optional componentdetail as (type text meta [
        Documentation.FieldCaption = "Component Detail",
        Documentation.AllowedValues = { "Securities", "Groups", "Totals", "" }
    ]))
    as table meta [ 
        Documentation.Name = "Run PA Multi-Port Calculation",
        Documentation.LongDescription = "This function runs the PA calculation for the specified parameters.",
        Documentation.Examples = {[
            Description = "Runs the PA calculation for the specified parameters.",
            Code = "= RunPAMultiPortCalculation(""D1CDCCD48DF1B9B8FCFC227844DAF825114728C0BE17E48295D76C0E8B265F01"",{ [ id = ""BENCH:SP50"", holdingsmode = ""B&H"" ] },{ [ id = ""BENCH:DJII"", holdingsmode = ""B&H"" ] },""-2M"",""0"",""Monthly"",""USD"")",
            Result = "#table(...)"
        ]}
    ];

runPAMultiPortCalculationImpl = (
    optional componentid as text, 
    optional accounts as list, 
    optional benchmarks as list, 
    optional startdate as text, 
    optional enddate as text, 
    optional frequency as text, 
    optional currencyisocode as text,
    optional componentdetail as text
) as table =>
    let
        dates = if startdate is null and enddate is null and frequency is null then null else  [
            startdate = startdate,
            enddate = enddate,
            frequency = frequency
        ],
        calculation = [ 
            componentid = componentid, 
            accounts = accounts,
            benchmarks = benchmarks,
            dates = dates,
            currencyisocode = currencyisocode,
            componentdetail = componentdetail
        ],
        table = RunCalculation(calculation, "pa")
    in
        table;

// Run SPAR Calculation
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.RunSPARCalculation = Value.ReplaceType(runSPARCalculationImpl, runSPARCalculationType);

runSPARCalculationType = type function (
    optional componentid as (type text meta [
        Documentation.FieldCaption = "Component Identifier",
        Documentation.SampleValues = { "8DB4D9629C65705DEC03B0796FCC39DB1ADBBE0BD1F00D3BD46CC7E6BEEF2872" }
    ]),
    optional accountid as (type text meta [
        Documentation.FieldCaption = "Account Identifier",
        Documentation.SampleValues = { "00000117" }
    ]),
    optional accountreturntype as (type text meta [
        Documentation.FieldCaption = "Account Return Type",
        Documentation.SampleValues = { "GTR" }
    ]),
    optional accountprefix as (type text meta [
        Documentation.FieldCaption = "Account Prefix",
        Documentation.SampleValues = { "SPUS_GR" }
    ]),
    optional benchmarkid as (type text meta [
        Documentation.FieldCaption = "Benchmark Identifier",
        Documentation.SampleValues = { "R.1000" }
    ]),
    optional benchmarkreturntype as (type text meta [
        Documentation.FieldCaption = "Benchmark Return Type",
        Documentation.SampleValues = { "GTR" }
    ]),
    optional benchmarkprefix as (type text meta [
        Documentation.FieldCaption = "Benchmark Prefix",
        Documentation.SampleValues = { "RUSSELL" }
    ]),
    optional startdate as (type text meta [ 
        Documentation.FieldCaption = "Start Date",
        Documentation.SampleValues = { "-2M" }
    ]),
    optional enddate as (type text meta [ 
        Documentation.FieldCaption = "End Date",
        Documentation.SampleValues = { "0" }
    ]),
    optional frequency as (type text meta [
        Documentation.FieldCaption = "Frequency",
        Documentation.SampleValues = { "Monthly" }
    ]),
    optional currencyisocode as (type text meta [
        Documentation.FieldCaption = "Currency ISO Code",
        Documentation.SampleValues = { "USD" }
    ]))
    as table meta [ 
        Documentation.Name = "Run SPAR Calculation",
        Documentation.LongDescription = "This function runs the SPAR calculation for the specified parameters.",
        Documentation.Examples = {[
            Description = "Runs the SPAR calculation for the specified parameters.",
            Code = "= RunSPARCalculation(""8DB4D9629C65705DEC03B0796FCC39DB1ADBBE0BD1F00D3BD46CC7E6BEEF2872"",""R.1000"",""GTR"",""RUSSELL"",""R.2000"",""GTR"",""RUSSELL"",""-2M"",""0"",""Monthly"", ""USD"")",
            Result = "#table(...)"
        ]}
    ];

runSPARCalculationImpl = (
    optional componentid as text, 
    optional accountid as text,
    optional accountreturntype as text,
    optional accountprefix as text,
    optional benchmarkid as text,
    optional benchmarkreturntype as text,
    optional benchmarkprefix as text,
    optional startdate as text, 
    optional enddate as text, 
    optional frequency as text,
    optional currencyisocode as text
) as table =>
    let
        accounts = if accountid is null and accountreturntype is null and accountprefix is null then null else {[
            id = accountid,
            returntype = accountreturntype,
            prefix = accountprefix
        ]},
        table = FactSetAnalytics.v2.RunSPARMultiPortCalculation(componentid, accounts, benchmarkid, benchmarkreturntype, benchmarkprefix, startdate, enddate, frequency, currencyisocode)
    in
        table;

[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.RunSPARMultiPortCalculation = Value.ReplaceType(runSPARMultiPortCalculationImpl, runSPARMultiPortCalculationType);

runSPARMultiPortCalculationType = type function (
    optional componentid as (type text meta [
        Documentation.FieldCaption = "Component Identifier",
        Documentation.SampleValues = { "8DB4D9629C65705DEC03B0796FCC39DB1ADBBE0BD1F00D3BD46CC7E6BEEF2872" }
    ]),
    optional accounts as (type list meta [
        Documentation.FieldCaption = "Accounts"
    ]),
    optional benchmarkid as (type text meta [
        Documentation.FieldCaption = "Benchmark Identifier",
        Documentation.SampleValues = { "R.1000" }
    ]),
    optional benchmarkreturntype as (type text meta [
        Documentation.FieldCaption = "Benchmark Return Type",
        Documentation.SampleValues = { "GTR" }
    ]),
    optional benchmarkprefix as (type text meta [
        Documentation.FieldCaption = "Benchmark Prefix",
        Documentation.SampleValues = { "RUSSELL" }
    ]),
    optional startdate as (type text meta [ 
        Documentation.FieldCaption = "Start Date",
        Documentation.SampleValues = { "-2M" }
    ]),
    optional enddate as (type text meta [ 
        Documentation.FieldCaption = "End Date",
        Documentation.SampleValues = { "0" }
    ]),
    optional frequency as (type text meta [
        Documentation.FieldCaption = "Frequency",
        Documentation.SampleValues = { "Monthly" }
    ]),
    optional currencyisocode as (type text meta [
        Documentation.FieldCaption = "Currency ISO Code",
        Documentation.SampleValues = { "USD" }
    ]))
    as table meta [ 
        Documentation.Name = "Run SPAR Multi-Port Calculation",
        Documentation.LongDescription = "This function runs the SPAR calculation for the specified parameters.",
        Documentation.Examples = {[
            Description = "Runs the SPAR calculation for the specified parameters.",
            Code = "= RunSPARMultiPortCalculation(""8DB4D9629C65705DEC03B0796FCC39DB1ADBBE0BD1F00D3BD46CC7E6BEEF2872"",{ [ id = ""R.1000"", returntype = ""GTR"", prefix = ""RUSSELL"" ] },""R.2000"",""GTR"",""RUSSELL"",""-2M"",""0"",""Monthly"", ""USD"")",
            Result = "#table(...)"
        ]}
    ];

runSPARMultiPortCalculationImpl = (
    optional componentid as text, 
    optional accounts as list, 
    optional benchmarkid as text,
    optional benchmarkreturntype as text,
    optional benchmarkprefix as text, 
    optional startdate as text, 
    optional enddate as text, 
    optional frequency as text,
    optional currencyisocode as text
) as table =>
    let
        benchmark = if benchmarkid is null and benchmarkreturntype is null and benchmarkprefix is null then null else  [
            id = benchmarkid,
            returntype = benchmarkreturntype,
            prefix = benchmarkprefix
        ],
        dates = if startdate is null and enddate is null and frequency is null then null else  [
            startdate = startdate,
            enddate = enddate,
            frequency = frequency
        ],
        calculation = [ 
            componentid = componentid, 
            accounts = accounts,
            benchmark = benchmark,
            dates = dates,
            currencyisocode = currencyisocode
        ],
        table = RunCalculation(calculation, "spar")
    in
        table;

// Run Vault Calculation
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.RunVaultCalculation = Value.ReplaceType(runVaultCalculationImpl, runVaultCalculationType);

runVaultCalculationType = type function (
    optional componentid as (type text meta [
        Documentation.FieldCaption = "Component Identifier",
        Documentation.SampleValues = { "E1E54AC0CEA63CC229F0E5A2FBD8BED510E1C0687A34E827804BC7C7D3945FF0" }
    ]),
    optional accountid as (type text meta [
        Documentation.FieldCaption = "Account Identifier",
        Documentation.SampleValues = { "CLIENT:/ANALYTICS/DATA/US_MID_CAP_CORE.ACTM" }
    ]),
    optional startdate as (type text meta [ 
        Documentation.FieldCaption = "Start Date",
        Documentation.SampleValues = { "-2M" }
    ]),
    optional enddate as (type text meta [ 
        Documentation.FieldCaption = "End Date",
        Documentation.SampleValues = { "0" }
    ]),
    optional frequency as (type text meta [
        Documentation.FieldCaption = "Frequency",
        Documentation.SampleValues = { "Monthly" }
    ]),
    optional configid as (type text meta [
        Documentation.FieldCaption = "Configuration identifier",
        Documentation.SampleValues = { "c6574f19-77d3-487d-96b1-955dc1a4da28" }
    ]),
    optional componentdetail as (type text meta [
        Documentation.FieldCaption = "Component Detail",
        Documentation.AllowedValues = { "Securities", "Groups", "Totals", "" }
    ]))
    as table meta [ 
        Documentation.Name = "Run Vault Calculation",
        Documentation.LongDescription = "This function runs the Vault calculation for the specified parameters.",
        Documentation.Examples = {[
            Description = "Runs the Vault calculation for the specified parameters.",
            Code = "= RunVaultCalculation(""E1E54AC0CEA63CC229F0E5A2FBD8BED510E1C0687A34E827804BC7C7D3945FF0"",""CLIENT:/ANALYTICS/DATA/US_MID_CAP_CORE.ACTM"",""-2M"",""0"",""Monthly"",""c6574f19-77d3-487d-96b1-955dc1a4da28"")",
            Result = "#table(...)"
        ]}
    ];

runVaultCalculationImpl = (
    optional componentid as text, 
    optional accountid as text, 
    optional startdate as text, 
    optional enddate as text, 
    optional frequency as text, 
    optional configid as text,
    optional componentdetail as text
) as table =>
    let
        account = if accountid is null then null else  [
            id = accountid
        ],
        dates = if startdate is null and enddate is null and frequency is null then null else  [
            startdate = startdate,
            enddate = enddate,
            frequency = frequency
        ],
        calculation = [ 
            componentid = componentid, 
            account = account,
            dates = dates,
            configid = configid,
            componentdetail = componentdetail
        ],
        table = RunCalculation(calculation, "vault")
    in
        table;

RunCalculation = (Calculation as record, EngineType as text) =>
    let 
        body = Json.FromValue(Record.AddField([], EngineType, Record.AddField([], calcUnitId, Calculation))),
        response = Web.Contents(ENGINES_URL & "calculations", [Headers = Record.AddField([ #"Content-Type" = "application/json"], ConnectorHeaderName, ConnectorHeaderValue), Content = body, ManualStatusHandling = {202,400,404,500}, IsRetry=true]),
        responseHeaders = Value.Metadata(response)[Headers],
        status = Value.Metadata(response)[Response.Status],
        table = if status = 202 then GetCalculationStatus(response, EngineType)  
               else if status = 400 then error Error.Record("Error", "Invalid input parameters", Text.Combine(List.Combine(Record.FieldValues(Json.Document(response))), " "))
               else if status = 404 then error Error.Record("Error", "Input parameter not found", Text.FromBinary(response))
               else if status = 500 then error Error.Record("Error", "Server Error", "Please report this error to FactSet Support. X-DataDirect-Request-Key " & Record.Field(responseHeaders, "X-DataDirect-Request-Key") & ".")
               else error Error.Record("Error", "Unknown Error", Text.FromBinary(response))
    in
        table;

GetCalculationStatus = (Response as binary, EngineType as text) => 
    let
        responseHeaders = Value.Metadata(Response)[Headers],
        locationUrl = responseHeaders[Location],
        status =  Value.WaitFor(
            (iteration) =>
                let 
                    statusResponse = Web.Contents(locationUrl, [Headers = Record.AddField([#"Accept" = "application/json"], ConnectorHeaderName, ConnectorHeaderValue), ManualStatusHandling = {200}, IsRetry = true]),
                    buffered = Binary.Buffer(statusResponse),
                    json = Json.Document(statusResponse),
                    calculationStatus = json[status],
                    unitStatuses = Record.Field(json, EngineType),
                    table = if calculationStatus = "Queued" or calculationStatus = "Executing" then null
                           else if calculationStatus = "Completed" then GetCalculationResult(unitStatuses[1])
                           else error Error.Record("Error", "Calculation cancelled")
                in 
                    table,
            (iteration) => #duration(0, 0, 0, 5))
    in
        status;

GetCalculationResult = (UnitStatus as record) =>
    let
        url = if UnitStatus[status] = "Success" then UnitStatus[result] else error Error.Record("Error", "Calculation Failed", UnitStatus[error]),
        result = Web.Contents(url, [Headers = Record.AddField([#"Accept" = "application/json"], ConnectorHeaderName, ConnectorHeaderValue), Query = [format = "bison"], IsRetry = true]),
        json = Json.Document(result),
        #"Returned" = json[tables][0][datarows],
        #"Columns" = json[tables][0][definition][columns],
        #"ColumnTable" = Table.FromList(#"Columns", Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"ColumnRows" = Table.ExpandRecordColumn(#"ColumnTable", "Column1", {"name"}),
        #"Headers" = Table.ToList(#"ColumnRows"),
        #"Table" = Table.FromRecords(#"Returned"),
        #"OldNames" = Table.ColumnNames(#"Table"),
        #"FormattedTable" = Table.RenameColumns(#"Table", List.Zip({#"OldNames", #"Headers"}), MissingField.UseNull)
    in
        #"FormattedTable";

Value.WaitFor = (Producer as function, Interval as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, null},
            (state) => state{0} <> null and (count = null or state{0} < count),
            (state) => if state{1} <> null then {null, state{1}} else {1 + state{0}, Function.InvokeAfter(() => Producer(state{0}), Interval(state{0}))},
            (state) => state{1})
    in
        List.Last(list);

// Accounts Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.GetAccounts = Value.ReplaceType(getAccountsImpl, getAccountsType);

getAccountsType = type function (
    optional path as (type text meta [
        Documentation.SampleValues = { "Client:Foo/Bar" }
    ]))
    as text meta [
        Documentation.Name = "Get accounts and sub-directories in a directory",
        Documentation.LongDescription = "This function returns list of ACCT and ACTM files and sub-directories in a given directory."
    ];
   
getAccountsImpl = (optional path as text) as record =>
    let
        Source = lookup("accounts/" & path, [])
    in
        Source;

// PA Columns Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.GetPAColumns = Value.ReplaceType(getPAColumnsImpl, getPAColumnsType);

getPAColumnsType = type function (
    optional name as (type text meta [
        Documentation.SampleValues = { "optional" }
    ]),
    optional category as (type text meta [
        Documentation.SampleValues = { "optional" }
    ]),
    optional directory as (type text meta [
        Documentation.SampleValues = { "optional" }
    ]))
    as text meta [
        Documentation.Name = "Get PA columns",
        Documentation.LongDescription = "This function returns list of PA columns that can be applied to a calculation."
    ];
   
getPAColumnsImpl = (optional nameInput as text, optional categoryInput as text, optional directoryInput as text) as table =>
    let
        directory = if directoryInput is null then "" else directoryInput,
        category = if categoryInput is null then "" else categoryInput,
        name = if nameInput is null then "" else nameInput,
        Source = lookup("engines/pa/columns", [ name = name, category = category, directory = directory ]),
        #"Converted to Table" = Record.ToTable(Source),
        #"Renamed" = Table.RenameColumns(#"Converted to Table",{{"Name", "Column Id"}}),
        #"Expanded Value" = Table.ExpandRecordColumn(#"Renamed", "Value", {"name", "directory", "category"}, {"Column Name", "Directory", "Category"})
    in
        #"Expanded Value";

// PA Column By Id Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.GetPAColumnById = Value.ReplaceType(getPAColumnByIdImpl, getPAColumnByIdType);

getPAColumnByIdType = type function (
    optional id as (type text meta [
        Documentation.SampleValues = { "2B729FA4EQAEA58B330055A5D064FC4FA32491DAF9D169C3DAD9793880F5" }
    ]))
    as text meta [
        Documentation.Name = "Get PA column settings",
        Documentation.LongDescription = "This function returns the default settings of a PA column."
    ];
   
getPAColumnByIdImpl = (optional id as text) as record =>
    let
        Source = lookup("engines/pa/columns/" & id, [])
    in
        Source;

// PA Column Statistics Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.GetPAColumnStatistics = Value.ReplaceType(getPAColumnStatisticsImpl, getPAColumnStatisticsType);

getPAColumnStatisticsType = type function ()
    as text meta [
        Documentation.Name = "Get PA column statistics",
        Documentation.LongDescription = "This function returns the column statistics that can be applied to a PA column."
    ];
   
getPAColumnStatisticsImpl = () as record =>
    let
        Source = lookup("engines/pa/columnstatistics", [])
    in
        Source;

// PA Components Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.GetPAComponents = Value.ReplaceType(getPAComponentsImpl, getPAComponentsType);

getPAComponentsType = type function (
    optional document as (type text meta [
        Documentation.SampleValues = { "PA_DOCUMENTS:DEFAULT" }
    ]))
    as text meta [
        Documentation.Name = "Get PA Components",
        Documentation.LongDescription = "This function returns the list of PA components in a given PA document."
    ];

getPAComponentsImpl = (optional documentInput as text) as table =>
    let
        document = if documentInput is null then "" else documentInput,
        Source = lookup("engines/pa/components", [ document = document ]),
        Response = formatGetComponentsResponse(Source)
    in
        Response;

// PA Component By Id Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.GetPAComponentById = Value.ReplaceType(getPAComponentByIdImpl, getPAComponentByIdType);

getPAComponentByIdType = type function (
    optional id as (type text meta [
        Documentation.SampleValues = {"918EE8207D259B54E2FDE2AAA4D3BEA9248164123A904F298B8438B76F9292EB"}
    ]))
    as text meta [
        Documentation.Name = "Get PA component by id",
        Documentation.LongDescription = "This function returns the default settings of a PA component."
    ];

getPAComponentByIdImpl = (optional componentId as text) as record =>
    let
        Source = lookup("engines/pa/components/" & componentId, [])
    in
        Source;

// SPAR Components Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.GetSPARComponents = Value.ReplaceType(getSPARComponentsImpl, getSPARComponentsType);

getSPARComponentsType = type function (
    optional document as (type text meta [
        Documentation.SampleValues = { "SPAR_DOCUMENTS:FactSet Default Document" }
    ]))
    as text meta [
        Documentation.Name = "Get SPAR Components",
        Documentation.LongDescription = "This function returns the list of SPAR components in a given SPAR document."
    ];

getSPARComponentsImpl = (optional documentInput as text) as table =>
    let
        document = if documentInput is null then "" else documentInput,
        Source = lookup("engines/spar/components", [ document = document ]),
        Response = formatGetComponentsResponse(Source)
    in
        Response;

// Vault Components Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.GetVaultComponents = Value.ReplaceType(getVaultComponentsImpl, getVaultComponentsType);

getVaultComponentsType = type function (
    optional document as (type text meta [
        Documentation.SampleValues = { "PA_DOCUMENTS:DEFAULT" }
    ]))
    as text meta [
        Documentation.Name = "Get Vault Components",
        Documentation.LongDescription = "This function returns the list of Vault components in a given Vault document."
    ];

getVaultComponentsImpl = (optional documentInput as text) as table =>
    let
        document = if documentInput is null then "" else documentInput,
        Source = lookup("engines/vault/components", [document=document]),
        Response = formatGetComponentsResponse(Source)
    in
        Response;

// Vault Component By Id Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.GetVaultComponentById = Value.ReplaceType(getVaultComponentByIdImpl, getVaultComponentByIdType);

getVaultComponentByIdType = type function (
    optional id as (type text meta [
        Documentation.SampleValues = {"918EE8207D259B54E2FDE2AAA4D3BEA9248164123A904F298B8438B76F9292EB"}
    ]))
    as text meta [
        Documentation.Name = "Get Vault component by id",
        Documentation.LongDescription = "This function returns the default settings of a Vault component."
    ];

getVaultComponentByIdImpl = (optional componentId as text) as record =>
    let
        Source = lookup("engines/vault/components/" & componentId, [])
    in
        Source;

formatGetComponentsResponse = (Source as record) as table =>
    let
        #"Converted to Table" = Record.ToTable(Source),
        #"Expanded Value" = Table.ExpandRecordColumn(#"Converted to Table", "Value", {"name", "category"}, {"Component Name", "Category"}),
        #"Renamed Value" = Table.RenameColumns(#"Expanded Value", {"Name", "Component Id"})
    in
        #"Renamed Value";
    
// Vault Configurations Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.GetVaultConfigurations = Value.ReplaceType(getVaultConfigurationsImpl, getVaultConfigurationsType);

getVaultConfigurationsType = type function (
    optional account as (type text meta [
        Documentation.SampleValues = {"Client:Foo/Bar/myaccount.acct"}
    ]))
    as text meta [
        Documentation.Name = "Get Vault configurations",
        Documentation.LongDescription = "This function returns all the Vault configurations saved in the provided account."
    ];

getVaultConfigurationsImpl = (optional accountInput as text) as table =>
    let
        account = if accountInput is null then "" else accountInput,
        Source = lookup("engines/vault/configurations", [account = account]),
        #"Converted to Table" = Record.ToTable(Source),
        #"Expanded Value" = Table.ExpandRecordColumn(#"Converted to Table", "Value", {"name"}, {"Configuration Name"}),
        #"Renamed Value" = Table.RenameColumns(#"Expanded Value", {"Name", "Configuration Id"})
    in
        #"Renamed Value";

// Vault Configuration By Id Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.GetVaultConfigurationById = Value.ReplaceType(getVaultConfigurationByIdImpl, getVaultConfigurationByIdType);

getVaultConfigurationByIdType = type function (
    optional id as (type text meta [
        Documentation.SampleValues = {"c6574f19-77d3-487d-96b1-955dc1a4da28"}
    ]))
    as text meta [
        Documentation.Name = "Get Vault configuration by id",
        Documentation.LongDescription = "This function returns details for a Vault configuration as well as a list of accounts it is used in."
    ];

getVaultConfigurationByIdImpl = (optional id as text) as record =>
    let
        Source = lookup("engines/vault/configurations/" & id, [])
    in
        Source;

// PA Currencies Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.PACurrencies = Value.ReplaceType(getPACurrenciesImpl, getPACurrenciesType);

getPACurrenciesType = type function ()
    as text meta [
        Documentation.Name = "Get all PA currencies",
        Documentation.LongDescription = "This function returns a list of PA currencies that can be applied to a calculation."
    ];

getPACurrenciesImpl = () as table =>
    let
        Source = lookup("engines/pa/currencies", []),
        #"Converted to Table" = Record.ToTable(Source),
        #"Expanded Value" = Table.ExpandRecordColumn(#"Converted to Table", "Value", {"name"}, {"Currency Name"}),
        #"Renamed Value" = Table.RenameColumns(#"Expanded Value", {"Name", "ISO Code"})
    in
        #"Renamed Value";

// Convert PA Dates To Absolute Format Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.ConvertPADatesToAbsoluteFormat = Value.ReplaceType(convertPADatesImpl, convertPADatesType);

convertPADatesType = type function (
    optional startDate as (type text meta [
        Documentation.SampleValues = { "-3AY" }
    ]),
    optional endDate as (type text meta [
        Documentation.SampleValues = { "-1AY" }
    ]),
    optional componentId as (type text meta [
        Documentation.SampleValues = { "7CF4BCEB46020A5D3C78344108905FF73A4937F5E37CFF6BD97EC29545341935" }
    ]),
    optional account as (type text meta [
        Documentation.SampleValues = { "Client:Foo/Bar/myaccount.acct" }
    ]))
    as text meta [
        Documentation.Name = "Convert PA dates to absolute format",
        Documentation.LongDescription = "This function converts the given start and end dates to yyyymmdd format for a PA calculation."
    ];

convertPADatesImpl = (optional startDateInput as text, optional endDateInput as text, optional componentIdInput as text, optional accountInput as text) as record =>
    let
        startDate = if startDateInput is null then "" else startDateInput,
        endDate = if endDateInput is null then "" else endDateInput,
        componentId = if componentIdInput is null then "" else componentIdInput,
        account = if accountInput is null then "" else accountInput,
        Source = lookup("engines/pa/dates", [startdate = startDate, enddate = endDate, componentid = componentId, account = account])
    in
        Source;

// Convert Vault Dates To Absolute Format Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.ConvertVaultDatesToAbsoluteFormat = Value.ReplaceType(convertVaultDatesImpl, convertVaultDatesType);

convertVaultDatesType = type function (
    optional startDate as (type text meta [
        Documentation.SampleValues = { "-3AY" }
    ]),
    optional endDate as (type text meta [
        Documentation.SampleValues = { "-1AY" }
    ]),
    optional componentId as (type text meta [
        Documentation.SampleValues = { "7CF4BCEB46020A5D3C78344108905FF73A4937F5E37CFF6BD97EC29545341935" }
    ]),
    optional account as (type text meta [
        Documentation.SampleValues = { "Client:Foo/Bar/myaccount.acct" }
    ]))
    as text meta [
        Documentation.Name = "Convert Vault dates to absolute format",
        Documentation.LongDescription = "This function converts the given start and end dates to yyyymmdd format for a Vault calculation."
    ];

convertVaultDatesImpl = (optional startDateInput as text, optional endDateInput as text, optional componentIdInput as text, optional accountInput as text) as record =>
    let
        startDate = if startDateInput is null then "" else startDateInput,
        endDate = if endDateInput is null then "" else endDateInput,
        componentId = if componentIdInput is null then "" else componentIdInput,
        account = if accountInput is null then "" else accountInput,
        Source = lookup("engines/vault/dates", [startdate = startDate, enddate = endDate, componentid = componentId, account = account])
    in
        Source;

// PA Documents Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.GetPADocuments = Value.ReplaceType(getPADocumentsImpl, getPADocumentsType);

getPADocumentsType = type function (
    optional path as (type text meta [
        Documentation.SampleValues = { "Client:folder1/folder2" }
    ]))
    as text meta [
        Documentation.Name = "Get PA3 documents and sub-directories in a directory",
        Documentation.LongDescription = "This function returns all PA3 documents and sub-directories in a given directory."
    ];

getPADocumentsImpl = (optional path as text) as record =>
    let
        Source = lookup("engines/pa/documents/" & path, [])
    in
        Source;

// SPAR Documents Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.GetSPARDocuments = Value.ReplaceType(getSPARDocumentsImpl, getSPARDocumentsType);

getSPARDocumentsType = type function (
    optional path as (type text meta [
        Documentation.SampleValues = { "Client:folder1/folder2" }
    ]))
    as text meta [
        Documentation.Name = "Gets SPAR3 documents and sub-directories in a directory",
        Documentation.LongDescription = "This function looks up all SPAR3 documents and sub-directories in a given directory."
    ];

getSPARDocumentsImpl = (optional path as text) as record =>
    let
        Source = lookup("engines/spar/documents/" & path, [])
    in
        Source;

// Vault Documents Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.GetVaultDocuments = Value.ReplaceType(getVaultDocumentsImpl, getVaultDocumentsType);

getVaultDocumentsType = type function (
    optional path as (type text meta [
        Documentation.SampleValues = { "Client:folder1/folder2" }
    ]))
    as text meta [
        Documentation.Name = "Get Vault documents and sub-directories in a directory",
        Documentation.LongDescription = "This function looks up all Vault documents and sub-directories in a given directory."
    ];

getVaultDocumentsImpl = (optional path as text) as record =>
    let
        Source = lookup("engines/vault/documents/" & path, [])
    in
        Source;

// PA Frequencies
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.PAFrequencies = Value.ReplaceType(getPAFrequenciesImpl, getPAFrequenciesType);

getPAFrequenciesType = type function ()
    as text meta [
        Documentation.Name = "Get PA frequencies",
        Documentation.LongDescription = "This function returns a list of frequencies that can be applied to a PA calculation."
    ];

getPAFrequenciesImpl = () as table =>
    let
        source = lookup("engines/pa/frequencies", []),
        table = formatGetFrequenciesResponse(source)
    in
        table;

// SPAR Frequencies
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.SPARFrequencies = Value.ReplaceType(getSPARFrequenciesImpl, getSPARFrequenciesType);

getSPARFrequenciesType = type function ()
    as text meta [
        Documentation.Name = "Get SPAR frequencies",
        Documentation.LongDescription = "This function returns a list of frequencies that can be applied to a SPAR calculation."
    ];

getSPARFrequenciesImpl = () as table =>
    let
        source = lookup("engines/spar/frequencies", []),
        table = formatGetFrequenciesResponse(source)
    in
        table;

// Vault Frequencies
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.VaultFrequencies = Value.ReplaceType(getVaultFrequenciesImpl, getVaultFrequenciesType);

getVaultFrequenciesType = type function ()
    as text meta [
        Documentation.Name = "Get Vault frequencies",
        Documentation.LongDescription = "This function returns a list of frequencies that can be applied to a Vault calculation."
    ];

getVaultFrequenciesImpl = () as table =>
    let
        source = lookup("engines/vault/frequencies", []),
        table = formatGetFrequenciesResponse(source)
    in
        table;

formatGetFrequenciesResponse = (Source as record) as table =>
    let
        #"Converted to Table" = Record.ToTable(Source),
        #"Expanded Value" = Table.ExpandRecordColumn(#"Converted to Table", "Value", {"name"}, {"Frequency Name"}),
        #"Renamed Value" = Table.RenameColumns(#"Expanded Value", {"Name", "Frequency Id"})
    in
        #"Renamed Value";

// PA Groups Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v2.PAGroups = Value.ReplaceType(getPAGroupsImpl, getPAGroupsType);

getPAGroupsType = type function ()
    as text meta [
        Documentation.Name = "Get PA groups",
        Documentation.LongDescription = "This function returns list of PA groups that can be applied to a PA calculation."
    ];

getPAGroupsImpl = () as table =>
    let
        Source = lookup("engines/pa/groups", []),
        #"Table" = Record.ToTable(Source),
        #"Renamed" = Table.RenameColumns(#"Table", {"Name", "Group Id"}),
        #"Expanded" = Table.ExpandRecordColumn(#"Renamed", "Value", {"name", "directory", "category"}, {"Group Name", "Directory", "Category"})
    in
        #"Expanded";

lookup = (Url as text, Query as record) as any =>
    let
        response = Web.Contents(LOOKUPS_URL & Url, [Headers = Record.AddField([#"Accept" = "application/json"], ConnectorHeaderName, ConnectorHeaderValue), ManualStatusHandling = {200,400,404,500}, Query = Query]),
        responseHeaders = Value.Metadata(response)[Headers],
        status = Value.Metadata(response)[Response.Status],
        record = if status = 200 then Json.Document(response)
                  else if status = 400 then error Error.Record("Error", "Invalid input parameters", Text.FromBinary(response))
                  else if status = 404 then error Error.Record("Error", "Input parameter not found", Text.FromBinary(response))
                  else if status = 500 then error Error.Record("Error", "Server Error", "Please report this error to FactSet Support. X-DataDirect-Request-Key " & Record.Field(responseHeaders, "X-DataDirect-Request-Key") & ".")
                  else error Error.Record("Error", "Unknown Error", Text.FromBinary(response))
    in
        record;

// v3 code
EnginesV3NavTable = () as table => 
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"PA", "PA", PAV3NavTable(), "Folder", "Folder", false},
                {"SPAR", "SPAR", SPARV3NavTable(), "Folder", "Folder", false},
                {"Vault", "Vault", VaultV3NavTable(), "Folder", "Folder", false},
                {"Lookups", "Lookups", LookupsV3NavTable(), "Folder", "Folder", false}
            }
        ),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

PAV3NavTable = () as table => 
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"v3RunPACalculation", "FactSetAnalytics.v3.RunPACalculation", FactSetAnalytics.v3.RunPACalculation, "Function", "Function", true},
                {"v3RunPAMultiPortCalculation", "FactSetAnalytics.v3.RunPAMultiPortCalculation", FactSetAnalytics.v3.RunPAMultiPortCalculation, "Function", "Function", true},
                {"v3GetAllPACalculations", "FactSetAnalytics.v3.GetAllPACalculations", FactSetAnalytics.v3.GetAllPACalculations, "Function", "Function", true},
                {"v3GetPAColumnStatistics", "FactSetAnalytics.v3.GetPAColumnStatistics", FactSetAnalytics.v3.GetPAColumnStatistics, "Function", "Function", true},
                {"v3GetPAColumns", "FactSetAnalytics.v3.GetPAColumns", FactSetAnalytics.v3.GetPAColumns, "Function", "Function", true},
                {"v3GetPAColumnById", "FactSetAnalytics.v3.GetPAColumnById", FactSetAnalytics.v3.GetPAColumnById, "Function", "FUnction", true},
                {"v3GetPAComponents", "FactSetAnalytics.v3.GetPAComponents", FactSetAnalytics.v3.GetPAComponents, "Function", "Function", true},
                {"v3GetPAComponentById", "FactSetAnalytics.v3.GetPAComponentById", FactSetAnalytics.v3.GetPAComponentById, "Function", "Function", true},
                {"v3ConvertPADatesToAbsoluteFormat", "FactSetAnalytics.v3.ConvertPADatesToAbsoluteFormat", FactSetAnalytics.v3.ConvertPADatesToAbsoluteFormat, "Function", "Function", true},
                {"v3PAFrequencies", "FactSetAnalytics.v3.PAFrequencies", FactSetAnalytics.v3.PAFrequencies(), "Table", "Table", true},
                {"v3PAGroups", "FactSetAnalytics.v3.PAGroups", FactSetAnalytics.v3.PAGroups(), "Table", "Table", true},
                {"v3GetPADocuments", "FactSetAnalytics.v3.GetPADocuments", FactSetAnalytics.v3.GetPADocuments, "Function", "Function", true},
                {"v3GetPAGroupingFrequencies", "FactSetAnalytics.v3.GetPAGroupingFrequencies", FactSetAnalytics.v3.GetPAGroupingFrequencies, "Function", "Function", true},
                {"v3GetPAPricingSources", "FactSetAnalytics.v3.GetPAPricingSources", FactSetAnalytics.v3.GetPAPricingSources, "Function", "Function", true }
            }
        ),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

SPARV3NavTable = () as table => 
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"v3RunSPARCalculation", "FactSetAnalytics.v3.RunSPARCalculation", FactSetAnalytics.v3.RunSPARCalculation, "Function", "Function", true},
                {"v3RunSPARMultiPortCalculation", "FactSetAnalytics.v3.RunSPARMultiPortCalculation", FactSetAnalytics.v3.RunSPARMultiPortCalculation, "Function", "Function", true},
                {"v3GetAllSPARCalculations","FactSetAnalytics.v3.GetAllSPARCalculations", FactSetAnalytics.v3.GetAllSPARCalculations, "Function", "Function", true},
                {"v3GetSPARBenchmarkById", "FactSetAnalytics.v3.GetSPARBenchmarkById", FactSetAnalytics.v3.GetSPARBenchmarkById, "Function", "Function", true},
                {"v3GetSPARComponents", "FactSetAnalytics.v3.GetSPARComponents", FactSetAnalytics.v3.GetSPARComponents, "Function", "Function", true},
                {"v3GetSPARComponentById", "FactSetAnalytics.v3.GetSPARComponentById", FactSetAnalytics.v3.GetSPARComponentById, "Function", "Function", true},
                {"v3SPARFrequencies", "FactSetAnalytics.v3.SPARFrequencies", FactSetAnalytics.v3.SPARFrequencies(), "Table", "Table", true},
                {"v3GetSPARDocuments", "FactSetAnalytics.v3.GetSPARDocuments", FactSetAnalytics.v3.GetSPARDocuments, "Function", "Function", true},
                {"v3GetSPARAccountsReturnType", "FactSetAnalytics.v3.GetSPARAccountsReturnType", FactSetAnalytics.v3.GetSPARAccountsReturnType, "Function", "Function", true}
            }
        ),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

VaultV3NavTable = () as table => 
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"v3RunVaultCalculation", "FactSetAnalytics.v3.RunVaultCalculation", FactSetAnalytics.v3.RunVaultCalculation, "Function", "Function", true},
                {"v3GetVaultComponents", "FactSetAnalytics.v3.GetVaultComponents", FactSetAnalytics.v3.GetVaultComponents, "Function", "Function", true},
                {"v3GetVaultComponentById", "FactSetAnalytics.v3.GetVaultComponentById", FactSetAnalytics.v3.GetVaultComponentById, "Function", "Function", true},
                {"v3GetVaultConfigurations", "FactSetAnalytics.v3.GetVaultConfigurations", FactSetAnalytics.v3.GetVaultConfigurations, "Function", "Function", true},
                {"v3GetVaultConfigurationById", "FactSetAnalytics.v3.GetVaultConfigurationById", FactSetAnalytics.v3.GetVaultConfigurationById, "Function", "Function", true},
                {"v3ConvertVaultDatesToAbsoluteFormat", "FactSetAnalytics.v3.ConvertVaultDatesToAbsoluteFormat", FactSetAnalytics.v3.ConvertVaultDatesToAbsoluteFormat, "Function", "Function", true},
                {"v3VaultFrequencies", "FactSetAnalytics.v3.VaultFrequencies", FactSetAnalytics.v3.VaultFrequencies(), "Table", "Table", true},
                {"v3GetVaultDocuments", "FactSetAnalytics.v3.GetVaultDocuments", FactSetAnalytics.v3.GetVaultDocuments, "Function", "Function", true},
                {"v3GetAllVaultCalculations", "FactSetAnalytics.v3.GetAllVaultCalculations", FactSetAnalytics.v3.GetAllVaultCalculations, "Function", "Function", true}
            }
        ),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

LookupsV3NavTable = () as table =>
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"v3GetAccounts", "FactSetAnalytics.v3.GetAccounts", FactSetAnalytics.v3.GetAccounts, "Function", "Function", true},
                {"v3GetCurrencies", "FactSetAnalytics.v3.GetCurrencies", FactSetAnalytics.v3.GetCurrencies(), "Table", "Table", true}
            }
        ),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

// Run PA Calculation
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.RunPACalculation = Value.ReplaceType(runPAV3CalculationImpl, runPAV3CalculationType);

runPAV3CalculationType = type function (
    optional componentid as (type text meta [
        Documentation.FieldCaption = "Component Identifier",
        Documentation.SampleValues = { "D1CDCCD48DF1B9B8FCFC227844DAF825114728C0BE17E48295D76C0E8B265F01" }
    ]),
    optional accountid as (type text meta [
        Documentation.FieldCaption = "Account Identifier",
        Documentation.SampleValues = { "BENCH:SP50" }
    ]),
    optional accountholdingsmode as (type text meta [
        Documentation.FieldCaption = "Account Holdings Mode",
        Documentation.SampleValues = { "B&H" }
    ]),
    optional benchmarkid as (type text meta [
        Documentation.FieldCaption = "Benchmark Identifier",
        Documentation.SampleValues = { "BENCH:R.1000" }
    ]),
    optional benchmarkholdingsmode as (type text meta [
        Documentation.FieldCaption = "Benchmark Holdings Mode",
        Documentation.SampleValues = { "B&H" }
    ]),
    optional startdate as (type text meta [ 
        Documentation.FieldCaption = "Start Date",
        Documentation.SampleValues = { "-2M" }
    ]),
    optional enddate as (type text meta [ 
        Documentation.FieldCaption = "End Date",
        Documentation.SampleValues = { "0" }
    ]),
    optional frequency as (type text meta [
        Documentation.FieldCaption = "Frequency",
        Documentation.SampleValues = { "Monthly" }
    ]),
    optional currencyisocode as (type text meta [
        Documentation.FieldCaption = "Currency ISO Code",
        Documentation.SampleValues = { "USD" }
    ]),
    optional componentdetail as (type text meta [
        Documentation.FieldCaption = "Component Detail",
        Documentation.AllowedValues = { "Securities", "Groups", "Totals", "" }
    ]),
    optional cachedoutputage as (type number meta [
        Documentation.FieldCaption = "Cached Output Age in minutes",
        Documentation.SampleValues = { "720 (Default Value)" }
    ]))
    as table meta [ 
        Documentation.Name = "Run PA V3 Calculation",
        Documentation.LongDescription = "This function runs the PA calculation for the specified parameters.",
        Documentation.Examples = {[
            Description = "Runs the PA calculation for the specified parameters.",
            Code = "= v3RunPACalculation(""D1CDCCD48DF1B9B8FCFC227844DAF825114728C0BE17E48295D76C0E8B265F01"",""BENCH:SP50"",""B&H"",""BENCH:DJII"",""B&H"",""-2M"",""0"",""Monthly"",""USD"", ""Securities"", 720)",
            Result = "#table(...)"
        ]}
    ];

runPAV3CalculationImpl = (
    optional componentid as text, 
    optional accountid as text, 
    optional accountholdingsmode as text,
    optional benchmarkid as text, 
    optional benchmarkholdingsmode as text,
    optional startdate as text, 
    optional enddate as text, 
    optional frequency as text, 
    optional currencyisocode as text,
    optional componentdetail as text,
    optional cachedoutputage as number
) as table =>
    let
        accounts = if accountid is null and accountholdingsmode is null then null else {[
            id = accountid,
            holdingsmode = accountholdingsmode
        ]},
        benchmarks = if benchmarkid is null and benchmarkholdingsmode is null then null else {[
            id = benchmarkid,
            holdingsmode = benchmarkholdingsmode
        ]},
        table = FactSetAnalytics.v3.RunPAMultiPortCalculation(componentid, accounts, benchmarks, startdate, enddate, frequency, currencyisocode, componentdetail, cachedoutputage)
    in
        table;

[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.RunPAMultiPortCalculation = Value.ReplaceType(runPAV3MultiPortCalculationImpl, runPAV3MultiPortCalculationType);

runPAV3MultiPortCalculationType = type function (
    optional componentid as (type text meta [
        Documentation.FieldCaption = "Component Identifier",
        Documentation.SampleValues = { "D1CDCCD48DF1B9B8FCFC227844DAF825114728C0BE17E48295D76C0E8B265F01" }
    ]),
    optional accounts as (type list meta [
        Documentation.FieldCaption = "Accounts"
    ]),
    optional benchmarks as (type list meta [
        Documentation.FieldCaption = "Benchmarks"
    ]),
    optional startdate as (type text meta [ 
        Documentation.FieldCaption = "Start Date",
        Documentation.SampleValues = { "-2M" }
    ]),
    optional enddate as (type text meta [ 
        Documentation.FieldCaption = "End Date",
        Documentation.SampleValues = { "0" }
    ]),
    optional frequency as (type text meta [
        Documentation.FieldCaption = "Frequency",
        Documentation.SampleValues = { "Monthly" }
    ]),
    optional currencyisocode as (type text meta [
        Documentation.FieldCaption = "Currency ISO Code",
        Documentation.SampleValues = { "USD" }
    ]),
    optional componentdetail as (type text meta [
        Documentation.FieldCaption = "Component Detail",
        Documentation.AllowedValues = { "Securities", "Groups", "Totals", "" }
    ]),
    optional cachedoutputage as (type number meta [
        Documentation.FieldCaption = "Cached Output Age in minutes",
        Documentation.SampleValues = { "720 (Default Value)" }
    ]))
    as table meta [ 
        Documentation.Name = "Run PA V3 Multi-Port Calculation",
        Documentation.LongDescription = "This function runs the PA calculation for the specified parameters.",
        Documentation.Examples = {[
            Description = "Runs the PA calculation for the specified parameters.",
            Code = "= v3RunPAMultiPortCalculation(""D1CDCCD48DF1B9B8FCFC227844DAF825114728C0BE17E48295D76C0E8B265F01"",{ [ id = ""BENCH:SP50"", holdingsmode = ""B&H"" ] },{ [ id = ""BENCH:DJII"", holdingsmode = ""B&H"" ] },""-2M"",""0"",""Monthly"",""USD"", ""Securities"", 720)",
            Result = "#table(...)"
        ]}
    ];

runPAV3MultiPortCalculationImpl = (
    optional componentid as text, 
    optional accounts as list, 
    optional benchmarks as list, 
    optional startdate as text, 
    optional enddate as text, 
    optional frequency as text, 
    optional currencyisocode as text,
    optional componentdetail as text,
    optional cachedoutputage as number
) as table =>
    let
        dates = if startdate is null and enddate is null and frequency is null then null else  [
            startdate = startdate,
            enddate = enddate,
            frequency = frequency
        ],
        calculation = [ 
            componentid = componentid, 
            accounts = accounts,
            benchmarks = benchmarks,
            dates = dates,
            currencyisocode = currencyisocode,
            componentdetail = componentdetail
        ],
        table = RunV3Calculation(calculation, "pa", cachedoutputage)
    in
        table;

// Run SPAR V3 Calculation
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.RunSPARCalculation = Value.ReplaceType(runSPARV3CalculationImpl, runSPARV3CalculationType);

runSPARV3CalculationType = type function (
    optional componentid as (type text meta [
        Documentation.FieldCaption = "Component Identifier",
        Documentation.SampleValues = { "8DB4D9629C65705DEC03B0796FCC39DB1ADBBE0BD1F00D3BD46CC7E6BEEF2872" }
    ]),
    optional accountid as (type text meta [
        Documentation.FieldCaption = "Account Identifier",
        Documentation.SampleValues = { "00000117" }
    ]),
    optional accountreturntype as (type text meta [
        Documentation.FieldCaption = "Account Return Type",
        Documentation.SampleValues = { "GTR" }
    ]),
    optional accountprefix as (type text meta [
        Documentation.FieldCaption = "Account Prefix",
        Documentation.SampleValues = { "SPUS_GR" }
    ]),
    optional benchmarkid as (type text meta [
        Documentation.FieldCaption = "Benchmark Identifier",
        Documentation.SampleValues = { "R.1000" }
    ]),
    optional benchmarkreturntype as (type text meta [
        Documentation.FieldCaption = "Benchmark Return Type",
        Documentation.SampleValues = { "GTR" }
    ]),
    optional benchmarkprefix as (type text meta [
        Documentation.FieldCaption = "Benchmark Prefix",
        Documentation.SampleValues = { "RUSSELL" }
    ]),
    optional startdate as (type text meta [ 
        Documentation.FieldCaption = "Start Date",
        Documentation.SampleValues = { "-2M" }
    ]),
    optional enddate as (type text meta [ 
        Documentation.FieldCaption = "End Date",
        Documentation.SampleValues = { "0" }
    ]),
    optional frequency as (type text meta [
        Documentation.FieldCaption = "Frequency",
        Documentation.SampleValues = { "Monthly" }
    ]),
    optional currencyisocode as (type text meta [
        Documentation.FieldCaption = "Currency ISO Code",
        Documentation.SampleValues = { "USD" }
    ]),
    optional cachedoutputage as (type number meta [
        Documentation.FieldCaption = "Cached Output Age in minutes",
        Documentation.SampleValues = { "720 (Default Value)" }
    ]))
    as table meta [ 
        Documentation.Name = "Run SPAR V3 Calculation",
        Documentation.LongDescription = "This function runs the SPAR calculation for the specified parameters.",
        Documentation.Examples = {[
            Description = "Runs the SPAR calculation for the specified parameters.",
            Code = "= v3RunSPARCalculation(""8DB4D9629C65705DEC03B0796FCC39DB1ADBBE0BD1F00D3BD46CC7E6BEEF2872"",""R.1000"",""GTR"",""RUSSELL"",""R.2000"",""GTR"",""RUSSELL"",""-2M"",""0"",""Monthly"", ""USD"", 720)",
            Result = "#table(...)"
        ]}
    ];

runSPARV3CalculationImpl = (
    optional componentid as text, 
    optional accountid as text,
    optional accountreturntype as text,
    optional accountprefix as text,
    optional benchmarkid as text,
    optional benchmarkreturntype as text,
    optional benchmarkprefix as text,
    optional startdate as text, 
    optional enddate as text, 
    optional frequency as text,
    optional currencyisocode as text,
    optional cachedoutputage as number
) as table =>
    let
        accounts = if accountid is null and accountreturntype is null and accountprefix is null then null else {[
            id = accountid,
            returntype = accountreturntype,
            prefix = accountprefix
        ]},
        table = FactSetAnalytics.v3.RunSPARMultiPortCalculation(componentid, accounts, benchmarkid, benchmarkreturntype, benchmarkprefix, startdate, enddate, frequency, currencyisocode, cachedoutputage)
    in
        table;

[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.RunSPARMultiPortCalculation = Value.ReplaceType(runSPARV3MultiPortCalculationImpl, runSPARV3MultiPortCalculationType);

runSPARV3MultiPortCalculationType = type function (
    optional componentid as (type text meta [
        Documentation.FieldCaption = "Component Identifier",
        Documentation.SampleValues = { "8DB4D9629C65705DEC03B0796FCC39DB1ADBBE0BD1F00D3BD46CC7E6BEEF2872" }
    ]),
    optional accounts as (type list meta [
        Documentation.FieldCaption = "Accounts"
    ]),
    optional benchmarkid as (type text meta [
        Documentation.FieldCaption = "Benchmark Identifier",
        Documentation.SampleValues = { "R.1000" }
    ]),
    optional benchmarkreturntype as (type text meta [
        Documentation.FieldCaption = "Benchmark Return Type",
        Documentation.SampleValues = { "GTR" }
    ]),
    optional benchmarkprefix as (type text meta [
        Documentation.FieldCaption = "Benchmark Prefix",
        Documentation.SampleValues = { "RUSSELL" }
    ]),
    optional startdate as (type text meta [ 
        Documentation.FieldCaption = "Start Date",
        Documentation.SampleValues = { "-2M" }
    ]),
    optional enddate as (type text meta [ 
        Documentation.FieldCaption = "End Date",
        Documentation.SampleValues = { "0" }
    ]),
    optional frequency as (type text meta [
        Documentation.FieldCaption = "Frequency",
        Documentation.SampleValues = { "Monthly" }
    ]),
    optional currencyisocode as (type text meta [
        Documentation.FieldCaption = "Currency ISO Code",
        Documentation.SampleValues = { "USD" }
    ]),
    optional cachedoutputage as (type number meta [
        Documentation.FieldCaption = "Cached Output Age in minutes",
        Documentation.SampleValues = { "720 (Default Value)" }
    ]))
    as table meta [ 
        Documentation.Name = "Run SPAR V3 Multi-Port Calculation",
        Documentation.LongDescription = "This function runs the SPAR calculation for the specified parameters.",
        Documentation.Examples = {[
            Description = "Runs the SPAR calculation for the specified parameters.",
            Code = "= v3RunSPARMultiPortCalculation(""8DB4D9629C65705DEC03B0796FCC39DB1ADBBE0BD1F00D3BD46CC7E6BEEF2872"",{ [ id = ""R.1000"", returntype = ""GTR"", prefix = ""RUSSELL"" ] },""R.2000"",""GTR"",""RUSSELL"",""-2M"",""0"",""Monthly"", ""USD"", 720)",
            Result = "#table(...)"
        ]}
    ];

runSPARV3MultiPortCalculationImpl = (
    optional componentid as text, 
    optional accounts as list, 
    optional benchmarkid as text,
    optional benchmarkreturntype as text,
    optional benchmarkprefix as text, 
    optional startdate as text, 
    optional enddate as text, 
    optional frequency as text,
    optional currencyisocode as text,
    optional cachedoutputage as number
) as table =>
    let
        benchmark = if benchmarkid is null and benchmarkreturntype is null and benchmarkprefix is null then null else  [
            id = benchmarkid,
            returntype = benchmarkreturntype,
            prefix = benchmarkprefix
        ],
        dates = if startdate is null and enddate is null and frequency is null then null else  [
            startdate = startdate,
            enddate = enddate,
            frequency = frequency
        ],
        calculation = [ 
            componentid = componentid, 
            accounts = accounts,
            benchmark = benchmark,
            currencyisocode = currencyisocode,
            dates = dates
        ],
        table = RunV3Calculation(calculation, "spar", cachedoutputage)
    in
        table;

// Run Vault Calculation
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.RunVaultCalculation = Value.ReplaceType(runVaultV3CalculationImpl, runVaultV3CalculationType);

runVaultV3CalculationType = type function (
    optional componentid as (type text meta [
        Documentation.FieldCaption = "Component Identifier",
        Documentation.SampleValues = { "E1E54AC0CEA63CC229F0E5A2FBD8BED510E1C0687A34E827804BC7C7D3945FF0" }
    ]),
    optional accountid as (type text meta [
        Documentation.FieldCaption = "Account Identifier",
        Documentation.SampleValues = { "CLIENT:/ANALYTICS/DATA/US_MID_CAP_CORE.ACTM" }
    ]),
    optional startdate as (type text meta [ 
        Documentation.FieldCaption = "Start Date",
        Documentation.SampleValues = { "-2M" }
    ]),
    optional enddate as (type text meta [ 
        Documentation.FieldCaption = "End Date",
        Documentation.SampleValues = { "0" }
    ]),
    optional frequency as (type text meta [
        Documentation.FieldCaption = "Frequency",
        Documentation.SampleValues = { "Monthly" }
    ]),
    optional configid as (type text meta [
        Documentation.FieldCaption = "Configuration identifier",
        Documentation.SampleValues = { "c6574f19-77d3-487d-96b1-955dc1a4da28" }
    ]),
    optional componentdetail as (type text meta [
        Documentation.FieldCaption = "Component Detail",
        Documentation.AllowedValues = { "Securities", "Groups", "Totals", "" }
    ]),
    optional cachedoutputage as (type number meta [
        Documentation.FieldCaption = "Cached Output Age in minutes",
        Documentation.SampleValues = { "720 (Default Value)" }
    ]))
    as table meta [ 
        Documentation.Name = "Run Vault V3 Calculation",
        Documentation.LongDescription = "This function runs the Vault calculation for the specified parameters.",
        Documentation.Examples = {[
            Description = "Runs the Vault calculation for the specified parameters.",
            Code = "= v3RunVaultCalculation(""E1E54AC0CEA63CC229F0E5A2FBD8BED510E1C0687A34E827804BC7C7D3945FF0"",""CLIENT:/ANALYTICS/DATA/US_MID_CAP_CORE.ACTM"",""-2M"",""0"",""Monthly"",""c6574f19-77d3-487d-96b1-955dc1a4da28"", ""Securities"", 720)",
            Result = "#table(...)"
        ]}
    ];

runVaultV3CalculationImpl = (
    optional componentid as text, 
    optional accountid as text, 
    optional startdate as text, 
    optional enddate as text, 
    optional frequency as text, 
    optional configid as text,
    optional componentdetail as text,
    optional cachedoutputage as number
) as table =>
    let
        account = if accountid is null then null else  [
            id = accountid
        ],
        dates = if startdate is null and enddate is null and frequency is null then null else  [
            startdate = startdate,
            enddate = enddate,
            frequency = frequency
        ],
        calculation = [ 
            componentid = componentid, 
            account = account,
            dates = dates,
            configid = configid,
            componentdetail = componentdetail
        ],
        table = RunV3Calculation(calculation, "vault", cachedoutputage)
    in
        table;

RunV3Calculation = (Calculation as record, EngineType as text, CachedOutputAge as nullable number) =>
    let 
        post = [],
        format = Record.AddField([], "contentorganization", "SimplifiedRow" ), 
        metaValue = Record.AddField(format, "contenttype", "Json"),
        data = Record.AddField(post, "data", Record.AddField([], calcUnitId, Calculation)),
        val = Record.AddField(data, "meta", metaValue),
        body = Json.FromValue(val), 
        maxstaleValue = let
                            value = if CachedOutputAge = null then 12 * 60 * 60 else CachedOutputAge * 60
                        in
                            value,
        response =  Web.Contents(ENGINES_V3_URL & EngineType & "/v3/calculations", [Headers = Record.AddField([ #"Content-Type" = "application/json", #"X-FactSet-Api-Long-Running-Deadline" = "0", #"Cache-control" = "max-stale=" & Text.From(maxstaleValue)], ConnectorHeaderName, ConnectorHeaderValue), Content = body, ManualStatusHandling = {201,202,400,404,500}, IsRetry=true]),
        responseHeaders = Value.Metadata(response)[Headers],
        status = Value.Metadata(response)[Response.Status],
        table = if status = 201 then HandleCalculationV3PBIResult(Json.Document(response))
               else if status = 200 then GetErrorResponseForV3(Json.Document(response))
               else if status = 202 then PollCalculationV3Status(response, EngineType)  
               else if status = 400 then error Error.Record("Error", "Invalid input parameters", Text.FromBinary(response))
               else if status = 404 then error Error.Record("Error", "Input parameter not found", Text.FromBinary(response))
               else if status = 500 then error Error.Record("Error", "Server Error", "Please report this error to FactSet Support. X-DataDirect-Request-Key " & Record.Field(responseHeaders, "X-DataDirect-Request-Key") & ".")
               else error Error.Record("Error", "Unknown Error", Text.FromBinary(response))
    in
        table;

HandleCalculationV3PBIResult = (Response as record) =>
    let
        tableId = Record.FieldNames(Response[data][tables]),
        update = Record.Field(Response[data][tables], tableId{0}),
        #"Columns" = update[definition][columns],
        #"ColumnTable" = Table.FromList(#"Columns", Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"ColumnRows" = Table.ExpandRecordColumn(#"ColumnTable", "Column1", {"description"}),
        #"Headers" = Table.ToList(#"ColumnRows"),
        #"IdColumn" = Table.ExpandRecordColumn(#"ColumnTable", "Column1", {"id"}),
        #"IdList" = Table.ToList(#"IdColumn"),
        #"Returned" = List.Transform(update[data][rows], each Record.ReorderFields( _[values], #"IdList")),
        #"Table" = Table.FromRecords(#"Returned"),
        #"OldNames" = Table.ColumnNames(#"Table"),
        #"FormattedTable" = Table.RenameColumns(#"Table", List.Zip({#"OldNames", #"Headers"}), MissingField.UseNull)
    in
        #"FormattedTable";

GetErrorResponseForV3 = (Response as record) =>
    let
        unitResponse = Record.Field(Response[data][units],calcUnitId),
        status = unitResponse[status],
        json = Json.FromValue(unitResponse),
        text = Text.FromBinary(json),
        message = if status = "Success" then HandleCalculationV3PBIResult(Response)
                  else if status = "Failed" then error Error.Record("Error", "Calculation Failed", text)
                  else error Error.Record("Error", "Unknown Error", "Neither Success nor Failure case")
    in
        message;

PollCalculationV3Status = (Response as binary, EngineType as text) =>
    let
        responseHeaders = Value.Metadata(Response)[Headers],
        #"locationUrl" = responseHeaders[Location],
        #"status" = GetCalculationV3Status(#"locationUrl", EngineType)
    in
        #"status";

GetCalculationV3Status = (locationUrl as text, EngineType as text) => 
    let
        status =  Value.WaitFor(
            (iteration) =>
                let 
                    statusResponse = Web.Contents(locationUrl, [Headers = Record.AddField([#"Accept" = "application/json"], ConnectorHeaderName, ConnectorHeaderValue), ManualStatusHandling = {200, 202, 400, 404, 500}, IsRetry = true]),
                    buffered = Binary.Buffer(statusResponse),
                    json = Json.Document(statusResponse),
                    status = Value.Metadata(statusResponse)[Response.Status],
                    responseHeaders = Value.Metadata(statusResponse)[Headers],
                    table = if status = 200 then GetCalculationV3Result(json)
                            else if status = 202 then null
                            else if status = 400 then error Error.Record("Error", "Invalid input parameters", Text.FromBinary(statusResponse))
                            else if status = 404 then error Error.Record("Error", "Input parameter not found", Text.FromBinary(statusResponse))
                            else if status = 500 then error Error.Record("Error", "Server Error", "Please report this error to FactSet Support. X-DataDirect-Request-Key " & Record.Field(responseHeaders, "X-DataDirect-Request-Key") & ".")
                            else error Error.Record("Error", "Calculation cancelled", Text.FromBinary(statusResponse))
                in 
                    table,
                (iteration) => #duration(0, 0, 0, 5))
            in
            status;

GetCalculationV3Result = (CalcStatus as record) =>
    let
        unitStatus = Record.Field(CalcStatus[data][units], calcUnitId),
        unitStatusToJson = Json.FromValue(unitStatus),
        unitStatusInText = Text.FromBinary(unitStatusToJson),
        url = if unitStatus[status] = "Success" then unitStatus[result] else error Error.Record("Error", "Calculation Failed", unitStatusInText),
        result = Web.Contents(url, [Headers = Record.AddField([#"Accept" = "application/json"], ConnectorHeaderName, ConnectorHeaderValue), ManualStatusHandling = {200}, IsRetry = true]),
        json = Json.Document(result),
        #"FormattedTable" = HandleCalculationV3PBIResult(json)
    in
        #"FormattedTable";


// Get PA V3 Grouping Frequencies
FactSetAnalytics.v3.GetPAGroupingFrequencies = Value.ReplaceType(getPAV3GroupingFrequenciesImpl, getPAV3GroupingFrequenciesType);

getPAV3GroupingFrequenciesType = type function()
    as text meta [
        Documentation.Name = "Get PA grouping frequencies",
        Documentation.LongDescription = "This endpoint lists all the PA grouping frequencies that can be applied to a PA calculation."
    ];

getPAV3GroupingFrequenciesImpl = () as table =>
    let
        Source = common("pa/v3/grouping-frequencies", []),
        table = formatGetFrequenciesResponse(Source)
    in
        table;

// Get PA V3 Pricing Sources
FactSetAnalytics.v3.GetPAPricingSources = Value.ReplaceType(getPAV3PricingSourcesImpl, getPAV3PricingSourcesType);

getPAV3PricingSourcesType = type function(
    optional name as (type text meta [
        Documentation.SampleValues = { "optional" }
    ]),
    optional category as (type text meta [
        Documentation.SampleValues = { "optional" }
    ]),
    optional directory as (type text meta [
        Documentation.SampleValues = { "optional" }
    ]))
    as text meta [
        Documentation.Name = "Get PA pricing sources",
        Documentation.LongDescription = "This endpoint lists all the PA pricing sources that can be applied to a PA calculation."
    ];

getPAV3PricingSourcesImpl = (optional nameInput as text, optional categoryInput as text, optional directoryInput as text) as table =>
    let
        directory = if directoryInput is null then "" else directoryInput,
        category = if categoryInput is null then "" else categoryInput,
        name = if nameInput is null then "" else nameInput,
        Source = common("pa/v3/pricing-sources", [ name = name, category = category, directory = directory ]),
        result = formatGetPAV3PricingSourcesGetPAV3Columns(Source)
    in
        result;

// Get PA V3 Column Statistics
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.GetPAColumnStatistics = Value.ReplaceType(getPAV3ColumnStatisticsImpl, getPAV3ColumnStatisticsType);

getPAV3ColumnStatisticsType = type function ()
    as text meta [
        Documentation.Name = "Get PA V3 column statistics",
        Documentation.LongDescription = "This function returns the column statistics that can be applied to a PA column."
    ];
   
getPAV3ColumnStatisticsImpl = () as record =>
    let
        Source = common("pa/v3/columnstatistics", [])
    in
        Source;
 
 // Get PA V3 Columns
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.GetPAColumns = Value.ReplaceType(getPAV3ColumnsImpl, getPAV3ColumnsType);

getPAV3ColumnsType = type function (
    optional name as (type text meta [
        Documentation.SampleValues = { "optional" }
    ]),
    optional category as (type text meta [
        Documentation.SampleValues = { "optional" }
    ]),
    optional directory as (type text meta [
        Documentation.SampleValues = { "optional" }
    ]))
    as text meta [
        Documentation.Name = "Get PA V3 columns",
        Documentation.LongDescription = "This function returns list of PA columns that can be applied to a calculation."
    ];
   
getPAV3ColumnsImpl = (optional nameInput as text, optional categoryInput as text, optional directoryInput as text) as table =>
    let
        directory = if directoryInput is null then "" else directoryInput,
        category = if categoryInput is null then "" else categoryInput,
        name = if nameInput is null then "" else nameInput,
        Source = common("pa/v3/columns", [ name = name, category = category, directory = directory ]),
        result = formatGetPAV3PricingSourcesGetPAV3Columns(Source)
    in
        result;

formatGetPAV3PricingSourcesGetPAV3Columns = (Source as record) as table =>
    let
        #"Converted to Table" = Record.ToTable(Source),
        #"Renamed" = Table.RenameColumns(#"Converted to Table",{{"Name", "Column Id"}}),
        #"Expanded Value" = Table.ExpandRecordColumn(#"Renamed", "Value", {"name", "directory", "category"}, {"Name", "Directory", "Category"})
    in
        #"Expanded Value";

// Get PA V3 Column By Id 
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.GetPAColumnById = Value.ReplaceType(getPAV3ColumnByIdImpl, getPAV3ColumnByIdType);

getPAV3ColumnByIdType = type function (
    optional id as (type text meta [
        Documentation.SampleValues = { "2B729FA4EQAEA58B330055A5D064FC4FA32491DAF9D169C3DAD9793880F5" }
    ]))
    as text meta [
        Documentation.Name = "Get PA V3 column settings",
        Documentation.LongDescription = "This function returns the default settings of a PA column."
    ];
   
getPAV3ColumnByIdImpl = (optional id as text) as record =>
    let
        Source = common("pa/v3/columns/" & id, [])
    in
        Source;

// PA V3 Components Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.GetPAComponents = Value.ReplaceType(getPAV3ComponentsImpl, getPAV3ComponentsType);

getPAV3ComponentsType = type function (
    optional document as (type text meta [
        Documentation.SampleValues = { "PA_DOCUMENTS:DEFAULT" }
    ]))
    as text meta [
        Documentation.Name = "Get PA V3 Components",
        Documentation.LongDescription = "This function returns the list of PA components in a given PA document."
    ];

getPAV3ComponentsImpl = (optional documentInput as text) as table =>
    let
        document = if documentInput is null then "" else documentInput,
        Source = common("pa/v3/components", [ document = document ]),
        Response = formatGetComponentsResponse(Source)
    in
        Response;

// PA V3 Component By Id Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.GetPAComponentById = Value.ReplaceType(getPAV3ComponentByIdImpl, getPAV3ComponentByIdType);

getPAV3ComponentByIdType = type function (
    optional id as (type text meta [
        Documentation.SampleValues = {"918EE8207D259B54E2FDE2AAA4D3BEA9248164123A904F298B8438B76F9292EB"}
    ]))
    as text meta [
        Documentation.Name = "Get PA V3 component by id",
        Documentation.LongDescription = "This function returns the default settings of a PA component."
    ];

getPAV3ComponentByIdImpl = (optional componentId as text) as record =>
    let
        Source = common("pa/v3/components/" & componentId, [])
    in
        Source;

// SPAR V3 Components Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.GetSPARComponents = Value.ReplaceType(getSPARV3ComponentsImpl, getSPARV3ComponentsType);

getSPARV3ComponentsType = type function (
    optional document as (type text meta [
        Documentation.SampleValues = { "SPAR_DOCUMENTS:FactSet Default Document" }
    ]))
    as text meta [
        Documentation.Name = "Get SPAR V3 Components",
        Documentation.LongDescription = "This function returns the list of SPAR components in a given SPAR document."
    ];

getSPARV3ComponentsImpl = (optional documentInput as text) as table =>
    let
        document = if documentInput is null then "" else documentInput,
        Source = common("spar/v3/components", [ document = document ]),
        Response = formatGetComponentsResponse(Source)
    in
        Response;

// SPAR V3 Get Accounts Return Type
FactSetAnalytics.v3.GetSPARAccountsReturnType = Value.ReplaceType(getSPARAccountsReturnTypeImpl, getSPARAccountsReturnTypeType);

getSPARAccountsReturnTypeType = type function (
    optional accountPath as (type text meta [
        Documentation.SampleValues = { "path/to/account.acct" }
    ]))
    as text meta [
        Documentation.Name = "Get SPAR account returns type details",
        Documentation.LongDescription = "This endpoint returns the returns type of account associated with SPAR",
        Documentation.Examples = {[
            Description = "Gets the SPAR Accounts Return Type for the specified account.",
            Code = "= v3GetSPARAccountsReturnType(""path/to/account.acct"")",
            Result = "#table(...)"
        ]}
    ];

getSPARAccountsReturnTypeImpl = (optional accountPath as text) as table =>
    let
        accountPath = if accountPath is null then "" else Uri.EscapeDataString(accountPath),
        Source = common("spar/v3/accounts/" & accountPath & "/returns-type", []),
        Response = formatGetAccountsReturnType(Source)
    in
        Response;

formatGetAccountsReturnType = (Source as record) as table => 
    let 
        #"List Of Records" = Source[returnsType],
        #"Expanded Table" = Table.FromRecords(#"List Of Records")
    in
        #"Expanded Table";

// SPAR V3 Component By Id Lookup
FactSetAnalytics.v3.GetSPARComponentById = Value.ReplaceType(getSPARV3ComponentByIdImpl, getSPARV3ComponentByIdType);

getSPARV3ComponentByIdType = type function (
    optional id as (type text meta [
        Documentation.SampleValues = {"918EE8207D259B54E2FDE2AAA4D3BEA9248164123A904F298B8438B76F9292EB"}
    ]))
    as text meta [
        Documentation.Name = "Get SPAR component by id",
        Documentation.LongDescription = "This function returns the default settings of a SPAR component."
    ];

getSPARV3ComponentByIdImpl = (optional componentId as text) as record =>
    let
        Source = common("spar/v3/components/" & componentId, [])
    in
        Source;

// Vault V3 Components Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.GetVaultComponents = Value.ReplaceType(getVaultV3ComponentsImpl, getVaultV3ComponentsType);

getVaultV3ComponentsType = type function (
    optional document as (type text meta [
        Documentation.SampleValues = { "PA_DOCUMENTS:DEFAULT" }
    ]))
    as text meta [
        Documentation.Name = "Get Vault V3 Components",
        Documentation.LongDescription = "This function returns the list of Vault components in a given Vault document."
    ];

getVaultV3ComponentsImpl = (optional documentInput as text) as table =>
    let
        document = if documentInput is null then "" else documentInput,
        Source = common("vault/v3/components", [document=document]),
        Response = formatGetComponentsResponse(Source)
    in
        Response;

// Vault V3 Component By Id Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.GetVaultComponentById = Value.ReplaceType(getVaultV3ComponentByIdImpl, getVaultV3ComponentByIdType);

getVaultV3ComponentByIdType = type function (
    optional id as (type text meta [
        Documentation.SampleValues = {"918EE8207D259B54E2FDE2AAA4D3BEA9248164123A904F298B8438B76F9292EB"}
    ]))
    as text meta [
        Documentation.Name = "Get Vault V3 component by id",
        Documentation.LongDescription = "This function returns the default settings of a Vault component."
    ];

getVaultV3ComponentByIdImpl = (optional componentId as text) as record =>
    let
        Source = common("vault/v3/components/" & componentId, [])
    in
        Source;

// Vault V3 Get All calculations
FactSetAnalytics.v3.GetAllVaultCalculations = Value.ReplaceType(getAllVaultV3CalculationsImpl, getAllVaultV3CalculationsType);

getAllVaultV3CalculationsType = type function (
    optional pageNumber as (type number meta [
        Documentation.SampleValues = {"1"}
    ]))
    as text meta [
        Documentation.Name = "Get all calculations",
        Documentation.LongDescription = "This function returns all the Vault calculation requests"
    ];

getAllVaultV3CalculationsImpl = (optional pageNumber as number) as table =>
    let
        page = if pageNumber is null then "1" else Text.From(pageNumber),
        response = Web.Contents(ENGINES_V3_URL & "vault/v3/calculations", [Headers = Record.AddField([#"Accept" = "application/json"], ConnectorHeaderName, ConnectorHeaderValue), ManualStatusHandling = {200,400,404,500}, Query = [pageNumber = page]]),
        result = formatV3GetAllCalculations(response)
    in
        result;

// PA V3 Get All calculations
FactSetAnalytics.v3.GetAllPACalculations = Value.ReplaceType(getAllPAV3CalculationsImpl, getAllPAV3CalculationsType);

getAllPAV3CalculationsType = type function (
    optional pageNumber as (type number meta [
        Documentation.SampleValues = {"1"}
    ]))
    as text meta [
        Documentation.Name = "Get all calculations",
        Documentation.LongDescription = "This function returns all the PA calculation requests"
    ];

getAllPAV3CalculationsImpl = (optional pageNumber as number) as any =>
    let
        page = if pageNumber is null then "1" else Text.From(pageNumber),
        response = Web.Contents(ENGINES_V3_URL & "pa/v3/calculations", [Headers = Record.AddField([#"Accept" = "application/json"], ConnectorHeaderName, ConnectorHeaderValue), ManualStatusHandling = {200,400,404,500}, Query = [pageNumber = page]]),
        result = formatV3GetAllCalculations(response)
    in
        result;

// SPAR V3 Get All calculations
FactSetAnalytics.v3.GetAllSPARCalculations = Value.ReplaceType(getAllSPARV3CalculationsImpl, getAllSPARV3CalculationsType);

getAllSPARV3CalculationsType = type function (
    optional pageNumber as (type number meta [
        Documentation.SampleValues = {"1"}
    ]))
    as text meta [
        Documentation.Name = "Get all calculations",
        Documentation.LongDescription = "This function returns all the SPAR calculation requests"
    ];

getAllSPARV3CalculationsImpl = (optional pageNumber as number) as table =>
    let
        page = if pageNumber is null then "1" else Text.From(pageNumber),
        response = Web.Contents(ENGINES_V3_URL & "spar/v3/calculations", [Headers = Record.AddField([#"Accept" = "application/json"], ConnectorHeaderName, ConnectorHeaderValue), ManualStatusHandling = {200,400,404,500}, Query = [pageNumber = page]]),
        result = formatV3GetAllCalculations(response)
    in
        result;

formatV3GetAllCalculations = (response as any) as table =>
    let
        responseHeaders = Value.Metadata(response)[Headers],
        status = Value.Metadata(response)[Response.Status],
        record = if status = 200 then 
                                    let
                                        Source = Json.Document(response),
                                        data = Source[data],
                                        pages = Source[meta][pagination][totalPages],
                                        calcs = Source[meta][pagination][totalCalculations],
                                        #"Converted to Table" = Record.ToTable(data),
                                        a = Table.ExpandRecordColumn(#"Converted to Table", "Value", {"status", "units", "requestTime", "lastPollTime"}, {"Status", "Units", "Request Time", "Last Poll Time"}),
                                        b = Table.AddColumn(a, "Total Pages", each pages),
                                        c = Table.AddColumn(b, "Total Calculations", each calcs)
                                    in
                                        c
                 else if status = 400 then error Error.Record("Error", "Invalid input parameters", Text.FromBinary(response))
                 else if status = 404 then error Error.Record("Error", "Input parameter not found", Text.FromBinary(response))
                 else if status = 500 then error Error.Record("Error", "Server Error", "Please report this error to FactSet Support. X-DataDirect-Request-Key " & Record.Field(responseHeaders, "X-DataDirect-Request-Key") & ".")
                 else error Error.Record("Error", "Unknown Error", Text.FromBinary(response))
    in
        record;

// Vault V3 Configurations
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.GetVaultConfigurations = Value.ReplaceType(getVaultV3ConfigurationsImpl, getVaultV3ConfigurationsType);

getVaultV3ConfigurationsType = type function (
    optional account as (type text meta [
        Documentation.SampleValues = {"Client:Foo/Bar/myaccount.acct"}
    ]))
    as text meta [
        Documentation.Name = "Get Vault V3 configurations",
        Documentation.LongDescription = "This function returns all the Vault configurations saved in the provided account."
    ];

getVaultV3ConfigurationsImpl = (optional accountInput as text) as table =>
    let
        account = if accountInput is null then "" else accountInput,
        Source = common("vault/v3/configurations", [account = account]),
        #"Converted to Table" = Record.ToTable(Source),
        #"Expanded Value" = Table.ExpandRecordColumn(#"Converted to Table", "Value", {"name"}, {"Configuration Name"}),
        #"Renamed Value" = Table.RenameColumns(#"Expanded Value", {"Name", "Configuration Id"})
    in
        #"Renamed Value";

// Vault V3 Configuration By Id
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.GetVaultConfigurationById = Value.ReplaceType(getVaultV3ConfigurationByIdImpl, getVaultV3ConfigurationByIdType);

getVaultV3ConfigurationByIdType = type function (
    optional id as (type text meta [
        Documentation.SampleValues = {"c6574f19-77d3-487d-96b1-955dc1a4da28"}
    ]))
    as text meta [
        Documentation.Name = "Get Vault V3 configuration by id",
        Documentation.LongDescription = "This function returns details for a Vault configuration as well as a list of accounts it is used in."
    ];

getVaultV3ConfigurationByIdImpl = (optional id as text) as record =>
    let
        Source = common("vault/v3/configurations/" & id, [])
    in
        Source;

// Convert PA V3 Dates To Absolute Format Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.ConvertPADatesToAbsoluteFormat = Value.ReplaceType(convertPAV3DatesImpl, convertPAV3DatesType);

convertPAV3DatesType = type function (
    optional startDate as (type text meta [
        Documentation.SampleValues = { "-3AY" }
    ]),
    optional endDate as (type text meta [
        Documentation.SampleValues = { "-1AY" }
    ]),
    optional componentId as (type text meta [
        Documentation.SampleValues = { "7CF4BCEB46020A5D3C78344108905FF73A4937F5E37CFF6BD97EC29545341935" }
    ]),
    optional account as (type text meta [
        Documentation.SampleValues = { "Client:Foo/Bar/myaccount.acct" }
    ]))
    as text meta [
        Documentation.Name = "Convert PA V3 dates to absolute format",
        Documentation.LongDescription = "This function converts the given start and end dates to yyyymmdd format for a PA calculation."
    ];

convertPAV3DatesImpl = (optional startDateInput as text, optional endDateInput as text, optional componentIdInput as text, optional accountInput as text) as record =>
    let
        startDate = if startDateInput is null then "" else startDateInput,
        endDate = if endDateInput is null then "" else endDateInput,
        componentId = if componentIdInput is null then "" else componentIdInput,
        account = if accountInput is null then "" else accountInput,
        Source = common("pa/v3/dates", [startdate = startDate, enddate = endDate, componentid = componentId, account = account])
    in
        Source;

// Convert Vault V3 Dates To Absolute Format Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.ConvertVaultDatesToAbsoluteFormat = Value.ReplaceType(convertVaultV3DatesImpl, convertVaultV3DatesType);

convertVaultV3DatesType = type function (
    optional startDate as (type text meta [
        Documentation.SampleValues = { "-3AY" }
    ]),
    optional endDate as (type text meta [
        Documentation.SampleValues = { "-1AY" }
    ]),
    optional componentId as (type text meta [
        Documentation.SampleValues = { "7CF4BCEB46020A5D3C78344108905FF73A4937F5E37CFF6BD97EC29545341935" }
    ]),
    optional account as (type text meta [
        Documentation.SampleValues = { "Client:Foo/Bar/myaccount.acct" }
    ]))
    as text meta [
        Documentation.Name = "Convert Vault V3 dates to absolute format",
        Documentation.LongDescription = "This function converts the given start and end dates to yyyymmdd format for a Vault calculation."
    ];

convertVaultV3DatesImpl = (optional startDateInput as text, optional endDateInput as text, optional componentIdInput as text, optional accountInput as text) as record =>
    let
        startDate = if startDateInput is null then "" else startDateInput,
        endDate = if endDateInput is null then "" else endDateInput,
        componentId = if componentIdInput is null then "" else componentIdInput,
        account = if accountInput is null then "" else accountInput,
        Source = common("vault/v3/dates", [startdate = startDate, enddate = endDate, componentid = componentId, account = account])
    in
        Source;

// PA V3 Frequencies
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.PAFrequencies = Value.ReplaceType(getPAV3FrequenciesImpl, getPAV3FrequenciesType);

getPAV3FrequenciesType = type function ()
    as text meta [
        Documentation.Name = "Get PA V3 frequencies",
        Documentation.LongDescription = "This function returns a list of frequencies that can be applied to a PA calculation."
    ];

getPAV3FrequenciesImpl = () as table =>
    let
        source = common("pa/v3/frequencies", []),
        table = formatGetFrequenciesResponse(source)
    in
        table;

// SPAR V3 Frequencies
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.SPARFrequencies = Value.ReplaceType(getSPARV3FrequenciesImpl, getSPARV3FrequenciesType);

getSPARV3FrequenciesType = type function ()
    as text meta [
        Documentation.Name = "Get SPAR V3 frequencies",
        Documentation.LongDescription = "This function returns a list of frequencies that can be applied to a SPAR calculation."
    ];

getSPARV3FrequenciesImpl = () as table =>
    let
        source = common("spar/v3/frequencies", []),
        table = formatGetFrequenciesResponse(source)
    in
        table;

// Vault V3 Frequencies
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.VaultFrequencies = Value.ReplaceType(getVaultV3FrequenciesImpl, getVaultV3FrequenciesType);

getVaultV3FrequenciesType = type function ()
    as text meta [
        Documentation.Name = "Get Vault V3 frequencies",
        Documentation.LongDescription = "This function returns a list of frequencies that can be applied to a Vault calculation."
    ];

getVaultV3FrequenciesImpl = () as table =>
    let
        source = common("vault/v3/frequencies", []),
        table = formatGetFrequenciesResponse(source)
    in
        table;

// PA V3 Groups Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.PAGroups = Value.ReplaceType(getPAV3GroupsImpl, getPAV3GroupsType);

getPAV3GroupsType = type function ()
    as text meta [
        Documentation.Name = "Get PA V3 groups",
        Documentation.LongDescription = "This function returns list of PA groups that can be applied to a PA calculation."
    ];

getPAV3GroupsImpl = () as table =>
    let
        Source = common("pa/v3/groups", []),
        #"Table" = Record.ToTable(Source),
        #"Renamed" = Table.RenameColumns(#"Table", {"Name", "Group Id"}),
        #"Expanded" = Table.ExpandRecordColumn(#"Renamed", "Value", {"name", "directory", "category"}, {"Group Name", "Directory", "Category"})
    in
        #"Expanded";

//SPAR V3 Benchmark By id
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.GetSPARBenchmarkById = Value.ReplaceType(getSPARV3BenchmarkByIdImpl, getSPARV3BenchmarkById);

getSPARV3BenchmarkById = type function (
    optional id as (type text meta [
        Documentation.SampleValues = {"R.1000"}
    ]))
    as text meta [
        Documentation.Name = "Get SPAR V3 Benchmark by id",
        Documentation.LongDescription = "This function returns the details of a given SPAR benchmark identifier"
    ];

getSPARV3BenchmarkByIdImpl = (optional id as text) as record =>
    let
        Source = common("spar/v3/benchmarks", [id = id])
    in
        Source;

// PA V3 Documents Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.GetPADocuments = Value.ReplaceType(getPAV3DocumentsImpl, getPAV3DocumentsType);

getPAV3DocumentsType = type function (
    optional path as (type text meta [
        Documentation.SampleValues = { "Client:folder1/folder2" }
    ]))
    as text meta [
        Documentation.Name = "Get PA3 documents and sub-directories in a directory",
        Documentation.LongDescription = "This function returns all PA3 documents and sub-directories in a given directory."
    ];

getPAV3DocumentsImpl = (optional path as text) as record =>
    let
        Source = common("pa/v3/documents/" & path, [])
    in
        Source;

// SPAR V3 Documents Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.GetSPARDocuments = Value.ReplaceType(getSPARV3DocumentsImpl, getSPARV3DocumentsType);

getSPARV3DocumentsType = type function (
    optional path as (type text meta [
        Documentation.SampleValues = { "Client:folder1/folder2" }
    ]))
    as text meta [
        Documentation.Name = "Gets SPAR3 documents and sub-directories in a directory",
        Documentation.LongDescription = "This function looks up all SPAR3 documents and sub-directories in a given directory."
    ];

getSPARV3DocumentsImpl = (optional path as text) as record =>
    let
        Source = common("spar/v3/documents/" & path, [])
    in
        Source;

// Vault Documents Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.GetVaultDocuments = Value.ReplaceType(getVaultV3DocumentsImpl, getVaultV3DocumentsType);

getVaultV3DocumentsType = type function (
    optional path as (type text meta [
        Documentation.SampleValues = { "Client:folder1/folder2" }
    ]))
    as text meta [
        Documentation.Name = "Get Vault documents and sub-directories in a directory",
        Documentation.LongDescription = "This function looks up all Vault documents and sub-directories in a given directory."
    ];

getVaultV3DocumentsImpl = (optional path as text) as record =>
    let
        Source = common("vault/v3/documents/" & path, [])
    in
        Source;

// Accounts V3 Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.GetAccounts = Value.ReplaceType(getAccountsV3Impl, getAccountsV3Type);

getAccountsV3Type = type function (
    optional path as (type text meta [
        Documentation.SampleValues = { "Client:Foo/Bar" }
    ]))
    as text meta [
        Documentation.Name = "Get accounts and sub-directories in a directory",
        Documentation.LongDescription = "This function returns list of ACCT and ACTM files and sub-directories in a given directory."
    ];
   
getAccountsV3Impl = (optional path as text) as record =>
    let
        Source = lookupV3("/accounts/" & path, [])
    in
        Source;

// Currencies Lookup
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v3.GetCurrencies = Value.ReplaceType(getCurrenciesV3Impl, getCurrenciesV3Type);

getCurrenciesV3Type = type function ()
    as text meta [
        Documentation.Name = "Get all currencies",
        Documentation.LongDescription = "This function returns a list of currencies that can be applied to a calculation."
    ];

getCurrenciesV3Impl = () as table =>
    let
        Source = lookupV3("/currencies", []),
        #"Converted to Table" = Record.ToTable(Source),
        #"Expanded Value" = Table.ExpandRecordColumn(#"Converted to Table", "Value", {"name"}, {"Currency Name"}),
        #"Renamed Value" = Table.RenameColumns(#"Expanded Value", {"Name", "ISO Code"})
    in
        #"Renamed Value";

common = (Url as text, Query as record) as any =>
    let
        response = Web.Contents(ENGINES_V3_URL & Url, [Headers = Record.AddField([#"Accept" = "application/json"], ConnectorHeaderName, ConnectorHeaderValue), ManualStatusHandling = {200,400,404,500}, Query = Query]),
        responseHeaders = Value.Metadata(response)[Headers],
        status = Value.Metadata(response)[Response.Status],
        record = if status = 200 then Json.Document(response)[data]
                 else if status = 400 then error Error.Record("Error", "Invalid input parameters", Text.FromBinary(response))
                 else if status = 404 then error Error.Record("Error", "Input parameter not found", Text.FromBinary(response))
                 else if status = 500 then error Error.Record("Error", "Server Error", "Please report this error to FactSet Support. X-DataDirect-Request-Key " & Record.Field(responseHeaders, "X-DataDirect-Request-Key") & ".")
                 else error Error.Record("Error", "Unknown Error", Text.FromBinary(response))
    in
        record;

lookupV3 = (Url as text, Query as record) as any =>
    let
        response = Web.Contents(LOOKUPS_V3_URL & Url, [Headers = Record.AddField([#"Accept" = "application/json"], ConnectorHeaderName, ConnectorHeaderValue), ManualStatusHandling = {200,400,404,500}, Query = Query]),
        responseHeaders = Value.Metadata(response)[Headers],
        status = Value.Metadata(response)[Response.Status],
        record = if status = 200 then Json.Document(response)[data]
                 else if status = 400 then error Error.Record("Error", "Invalid input parameters", Text.FromBinary(response))
                 else if status = 404 then error Error.Record("Error", "Input parameter not found", Text.FromBinary(response))
                 else if status = 500 then error Error.Record("Error", "Server Error", "Please report this error to FactSet Support. X-DataDirect-Request-Key " & Record.Field(responseHeaders, "X-DataDirect-Request-Key") & ".")
                 else error Error.Record("Error", "Unknown Error", Text.FromBinary(response))
    in
        record;

datastore = (Url as text, Query as record) as any =>
    let
        response = Web.Contents(Url, [Headers = Record.AddField([#"Accept" = "application/json"], ConnectorHeaderName, ConnectorHeaderValue), ManualStatusHandling = {200,400,404,500}, Query = Query]),
        responseHeaders = Value.Metadata(response)[Headers],
        status = Value.Metadata(response)[Response.Status],
        json = Json.Document(response),
        result = if status = 200 then HandleCalculationV3ADSResult(json)
                 else if status = 400 then error Error.Record("Error", "Invalid input parameters", Text.FromBinary(response))
                 else if status = 404 then error Error.Record("Error", "Input parameter not found", Text.FromBinary(response))
                 else if status = 500 then error Error.Record("Error", "Server Error", "Please report this error to FactSet Support. X-DataDirect-Request-Key " & Record.Field(responseHeaders, "X-DataDirect-Request-Key") & ".")
                 else error Error.Record("Error", "Unknown Error", Text.FromBinary(response))
    in
        result;

HandleCalculationV3ADSResult = (Response as record) =>
    let
        tableId = Record.FieldNames(Response[tables]),
        tableData = Record.Field(Response[tables], tableId{0}),
        #"Returned" = List.Transform(tableData[data][rows], each _[values]),
        #"Columns" = tableData[definition][columns],
        #"ColumnTable" = Table.FromList(#"Columns", Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"ColumnRows" = Table.ExpandRecordColumn(#"ColumnTable", "Column1", {"description"}),
        #"Headers" = Table.ToList(#"ColumnRows"),
        #"Table" = Table.FromRecords(#"Returned"),
        #"OldNames" = Table.ColumnNames(#"Table"),
        #"FormattedTable" = Table.RenameColumns(#"Table", List.Zip({#"OldNames", #"Headers"}), MissingField.UseNull)
    in
        #"FormattedTable";

DataStoreV1NavTable = () as table =>
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"v1GetSwivel", "FactSetAnalytics.v1Datastore.GetSwivel", FactSetAnalytics.v1Datastore.GetSwivel, "Function", "Function", true},
                {"v1GetSwivelAsOfDate", "FactSetAnalytics.v1Datastore.GetSwivelAsOfDate", FactSetAnalytics.v1Datastore.GetSwivelAsOfDate, "Function", "Function", true}
            }
        ),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

// Get pre-calculated Portfolio Analytics data
FactSetAnalytics.v1Datastore.GetSwivelAsOfDate = Value.ReplaceType(GetSwivelAsOfDateImpl, GetSwivelAsOfDateType);

GetSwivelAsOfDateType = type function (
    optional pubdoc as (type text meta [
        Documentation.FieldCaption = "Publisher Document",
        Documentation.SampleValues = { "Analytics_Datastore" }
    ]),
    optional assetname as (type text meta [
        Documentation.FieldCaption = "Asset Name",
        Documentation.SampleValues = { "ADS_Demo.PA3" }
    ]),
    optional reportid as (type text meta [
        Documentation.FieldCaption = "Report Identifier",
        Documentation.SampleValues = { "report0" }
    ]),
    optional tileid as (type text meta [
        Documentation.FieldCaption = "Tile Identifier",
        Documentation.SampleValues = { "tile0" }
    ]),
    optional accountid as (type text meta [
        Documentation.FieldCaption = "Account Identifier",
        Documentation.SampleValues = { "INTL_EQUITY" }
    ]),
    optional date as (type text meta [
        Documentation.FieldCaption = "Date",
        Documentation.SampleValues = { "2023-09-25" }
    ]),
    optional url as (type text meta [
        Documentation.FieldCaption = "URL",
        Documentation.SampleValues = { "https://api.factset.com/analytics/pub-datastore/swivel/v1/Analytics_Datastore/ADS_Demo.PA3/report0/tile0/ACI_BLEND/2023-09-01" }
    ]))
    as text meta [
        Documentation.Name = "Get Swivel as of date",
        Documentation.LongDescription = "This function returns the tabular data stored in ADS. <b>URL </b>takes <b>higher priority</b> over individual parameters",
        Documentation.Examples = {[
            Description = "Calls the ADS endpoint with individual parameters.",
            Code = "= v1GetSwivel(""Analytics_Datastore"",""ADS_Demo.PA3"",""report0"",""tile0"",""INTL_EQUITY"", ""2023-09-01"")",
            Result = "#table(...)"
        ],
        [
            Description = "Calls the ADS endpoint with just url.",
            Code = "= v1GetSwivel( null, null, null, null, null, null, ""https://api.factset.com/analytics/pub-datastore/swivel/v1/Analytics_Datastore/ADS_Demo.PA3/report0/tile0/INTL_EQUITY/2023-09-01"")",
            Result = "#table(...)"
        ]}
    ];

GetSwivelAsOfDateImpl = (optional pubDocInput as text, optional assetNameInput as text, optional reportIdInput as text, optional tileIdInput as text, optional accountIdInput as text, optional dateInput as text, optional urlInput as text) as table =>
    let
        pubdoc = if pubDocInput is null then "" else pubDocInput,
        assetname = if assetNameInput is null then "" else assetNameInput,
        reportid = if reportIdInput is null then "" else reportIdInput,
        tileid = if tileIdInput is null then "" else tileIdInput,
        accountid = if accountIdInput is null then "" else accountIdInput,
        url = if urlInput is null then null else urlInput,
        date = if dateInput is null then "" else dateInput,
        Source = if url is null then
                     datastore(LOOKUPS_V3_URL & "/ads/swivel" , [date = date, pubDoc = pubdoc, assetName = assetname, reportId = reportid, tileId = tileid, accountId = accountid])
                 else
                     datastore(LOOKUPS_V3_URL & "/ads/swivel", [url = url])
    in
        Source;

// Get pre-calculated Portfolio Analytics data
[DataSource.Kind="FactSetAnalytics"]
FactSetAnalytics.v1Datastore.GetSwivel = Value.ReplaceType(GetSwivelImpl, GetSwivelType);

GetSwivelType = type function (
    optional pubdoc as (type text meta [
        Documentation.FieldCaption = "Publisher Document",
        Documentation.SampleValues = { "Analytics_Datastore" }
    ]),
    optional assetname as (type text meta [
        Documentation.FieldCaption = "Asset Name",
        Documentation.SampleValues = { "ADS_Demo.PA3" }
    ]),
    optional reportid as (type text meta [
        Documentation.FieldCaption = "Report Identifier",
        Documentation.SampleValues = { "report0" }
    ]),
    optional tileid as (type text meta [
        Documentation.FieldCaption = "Tile Identifier",
        Documentation.SampleValues = { "tile0" }
    ]),
    optional accountid as (type text meta [
        Documentation.FieldCaption = "Account Identifier",
        Documentation.SampleValues = { "INTL_EQUITY" }
    ]),
    optional url as (type text meta [
        Documentation.FieldCaption = "URL",
        Documentation.SampleValues = { "https://api.factset.com/analytics/pub-datastore/swivel/v1/Analytics_Datastore/ADS_Demo.PA3/report0/tile0/ACI_BLEND" }
    ]))
    as text meta [
        Documentation.Name = "Get Swivel",
        Documentation.LongDescription = "This function returns the tabular data stored in ADS. <b>URL </b>takes <b>higher priority</b> over individual parameters",
        Documentation.Examples = {[
            Description = "Calls the ADS endpoint with individual parameters.",
            Code = "= v1GetSwivel(""Analytics_Datastore"",""ADS_Demo.PA3"",""report0"",""tile0"",""INTL_EQUITY"", null)",
            Result = "#table(...)"
        ],
        [
            Description = "Calls the ADS endpoint with just url.",
            Code = "= v1GetSwivel( null, null, null, null, null, ""https://api.factset.com/analytics/pub-datastore/swivel/v1/Analytics_Datastore/ADS_Demo.PA3/report0/tile0/INTL_EQUITY"")",
            Result = "#table(...)"
        ]}
    ];

GetSwivelImpl = (optional pubDocInput as text, optional assetNameInput as text, optional reportIdInput as text, optional tileIdInput as text, optional accountIdInput as text, optional urlInput as text) as table =>
    let
        pubdoc = if pubDocInput is null then "" else pubDocInput,
        assetname = if assetNameInput is null then "" else assetNameInput,
        reportid = if reportIdInput is null then "" else reportIdInput,
        tileid = if tileIdInput is null then "" else tileIdInput,
        accountid = if accountIdInput is null then "" else accountIdInput,
        url = if urlInput is null then null else urlInput,
        Source = if url is null then
                     datastore(LOOKUPS_V3_URL & "/ads/swivel", [pubDoc = pubdoc, assetName = assetname, reportId = reportid, tileId = tileid, accountId = accountid])
                 else
                     datastore(LOOKUPS_V3_URL & "/ads/swivel", [url = url])
    in
        Source;

//
// OAuth2 flow with PKCE
//
CreateCodeVerifier = () =>
    let 
        StringLength = 50,
        ValidCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
        fnRandomCharacter = (text) => Text.Range(ValidCharacters,Int32.From(Number.RandomBetween(0, Text.Length(ValidCharacters)-1)),1),
        GenerateList = List.Generate(()=> [Counter=0, Character=fnRandomCharacter(ValidCharacters)],
                       each [Counter] < StringLength,
                       each [Counter=[Counter]+1, Character=fnRandomCharacter(ValidCharacters)],
                       each [Character]),
        RandomString = List.Accumulate(GenerateList, "", (a,b) => a & b)
    in
        RandomString;

CreateCodeChallenge = (codeVerifier as text) =>
    let
        Hash = Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(codeVerifier)),
        Base64 = Binary.ToText(Hash, BinaryEncoding.Base64),
        CodeChallenge = Text.Replace(Text.Replace(Text.Replace(Base64, "+", "-"), "/", "_"), "=", "")
    in
        CodeChallenge;

StartLogin = (resourceUrl, state, display) =>
    let
        codeVerifier = CreateCodeVerifier(),

        AuthorizeUrl = authorizationEndpoint & "?" & Uri.BuildQueryString([
            client_id = clientId,
            scope = scope,
            state = state,
            redirect_uri = redirectUri,
            response_type="code",
            response_mode="query",
            code_challenge=CreateCodeChallenge(codeVerifier),
            code_challenge_method="S256"      
        ])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirectUri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = codeVerifier
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query],
        Result = if (Record.HasFields(Parts, {"error", "error_description"})) then 
                    error Error.Record(Parts[error], Parts[error_description], Parts)
                 else
                    TokenMethod(Parts[code], "authorization_code", context)
    in
        Result;

Refresh = (resourceUrl, refreshToken) => TokenMethod(refreshToken, "refresh_token");

TokenMethod = (code, grantType, optional verifier) =>
    let
        codeVerifier = if (verifier <> null) then [code_verifier = verifier] else [],
        codeParameter = if (grantType = "authorization_code") then [ code = code ] else [ refresh_token = code ],
        query = codeVerifier & codeParameter & [
            client_id = clientId,
            grant_type = grantType,
            redirect_uri = redirectUri
        ],

        Response = Web.Contents(tokenEndpoint, [
            Content = Text.ToBinary(Uri.BuildQueryString(query)),
            Headers= Record.AddField([
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ], ConnectorHeaderName, ConnectorHeaderValue),
            ManualStatusHandling = {400}
        ]),
        Body = Json.Document(Response)
    in
        if (Body[error]? <> null) then 
            error Error.Record(Body[error], Body[error_description]?)
        else
            Body;


GetOAuthConfigurations = (Url as text) as any =>
    let
        response = Web.Contents(Url, [Headers = Record.AddField([#"Accept" = "application/json"], ConnectorHeaderName, ConnectorHeaderValue), ManualStatusHandling = {200}]),
        responseHeaders = Value.Metadata(response)[Headers],
        status = Value.Metadata(response)[Response.Status],
        record = if status = 200 then Json.Document(response)
                  else error Error.Record("Error", "Server Error", "Please report this error to FactSet Support. X-DataDirect-Request-Key " & Record.Field(responseHeaders, "X-DataDirect-Request-Key") & ".")
    in
        record;