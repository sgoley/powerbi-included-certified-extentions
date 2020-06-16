// This file contains your Data Connector logic
[Version = "1.0.0"]
section FactSetAnalytics;

HOST = Json.Document(Extension.Contents( "configurations.json"))[ApiHost];
LOOKUPS_URL = HOST & "analytics/lookups/v2/";
ENGINES_URL = HOST & "analytics/engines/v2/";

// Data Source Kind description
FactSetAnalytics = [
    TestConnection = (dataSourcePath) as list => { "FactSetAnalytics.AuthenticationCheck" },
    Authentication = [
        UsernamePassword = [
            UsernameLabel = "Username-Serial",
            PasswordLabel = "API Key"
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
FactSetAnalytics.Publish = [
    Beta = true,
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
        response = Web.Contents(LOOKUPS_URL & "engines/pa/frequencies", [Headers = [#"Accept" = "application/json"]])
    in
        response;

// Build the Navigation Table 
[DataSource.Kind="FactSetAnalytics", Publish="FactSetAnalytics.Publish"]
shared FactSetAnalytics.Functions = () as table =>
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"v2", "v2", V2NavTable(), "Folder", "Folder", false}
            }
        ),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

V2NavTable = () as table => 
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
    ]))
    as table meta [ 
        Documentation.Name = "Run PA Calculation",
        Documentation.LongDescription = "This function runs the PA calculation for the specified parameters.",
        Documentation.Examples = {[
            Description = "Runs the PA calculation for the specified parameters.",
            Code = "= FactSetAnalytics.v2.RunPACalculation(""D1CDCCD48DF1B9B8FCFC227844DAF825114728C0BE17E48295D76C0E8B265F01"",""BENCH:SP50"",""B&H"",""BENCH:DJII"",""B&H"",""-2M"",""0"",""Monthly"",""USD"")",
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
    optional currencyisocode as text
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
        table = FactSetAnalytics.v2.RunPAMultiPortCalculation(componentid, accounts, benchmarks, startdate, enddate, frequency, currencyisocode)
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
    ]))
    as table meta [ 
        Documentation.Name = "Run PA Multi-Port Calculation",
        Documentation.LongDescription = "This function runs the PA calculation for the specified parameters.",
        Documentation.Examples = {[
            Description = "Runs the PA calculation for the specified parameters.",
            Code = "= FactSetAnalytics.v2.RunPAMultiPortCalculation(""D1CDCCD48DF1B9B8FCFC227844DAF825114728C0BE17E48295D76C0E8B265F01"",{ [ id = ""BENCH:SP50"", holdingsmode = ""B&H"" ] },{ [ id = ""BENCH:DJII"", holdingsmode = ""B&H"" ] },""-2M"",""0"",""Monthly"",""USD"")",
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
    optional currencyisocode as text
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
            currencyisocode = currencyisocode
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
    ]))
    as table meta [ 
        Documentation.Name = "Run SPAR Calculation",
        Documentation.LongDescription = "This function runs the SPAR calculation for the specified parameters.",
        Documentation.Examples = {[
            Description = "Runs the SPAR calculation for the specified parameters.",
            Code = "= FactSetAnalytics.v2.RunSPARCalculation(""8DB4D9629C65705DEC03B0796FCC39DB1ADBBE0BD1F00D3BD46CC7E6BEEF2872"",""R.1000"",""GTR"",""RUSSELL"",""R.2000"",""GTR"",""RUSSELL"",""-2M"",""0"",""Monthly"")",
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
    optional frequency as text 
) as table =>
    let
        accounts = if accountid is null and accountreturntype is null and accountprefix is null then null else {[
            id = accountid,
            returntype = accountreturntype,
            prefix = accountprefix
        ]},
        table = FactSetAnalytics.v2.RunSPARMultiPortCalculation(componentid, accounts, benchmarkid, benchmarkreturntype, benchmarkprefix, startdate, enddate, frequency)
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
    ]))
    as table meta [ 
        Documentation.Name = "Run SPAR Multi-Port Calculation",
        Documentation.LongDescription = "This function runs the SPAR calculation for the specified parameters.",
        Documentation.Examples = {[
            Description = "Runs the SPAR calculation for the specified parameters.",
            Code = "= FactSetAnalytics.v2.RunSPARMultiPortCalculation(""8DB4D9629C65705DEC03B0796FCC39DB1ADBBE0BD1F00D3BD46CC7E6BEEF2872"",{ [ id = ""R.1000"", returntype = ""GTR"", prefix = ""RUSSELL"" ] },""R.2000"",""GTR"",""RUSSELL"",""-2M"",""0"",""Monthly"")",
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
    optional frequency as text 
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
            dates = dates
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
    ]))
    as table meta [ 
        Documentation.Name = "Run Vault Calculation",
        Documentation.LongDescription = "This function runs the Vault calculation for the specified parameters.",
        Documentation.Examples = {[
            Description = "Runs the Vault calculation for the specified parameters.",
            Code = "= FactSetAnalytics.v2.RunVaultCalculation(""E1E54AC0CEA63CC229F0E5A2FBD8BED510E1C0687A34E827804BC7C7D3945FF0"",""CLIENT:/ANALYTICS/DATA/US_MID_CAP_CORE.ACTM"",""-2M"",""0"",""Monthly"",""c6574f19-77d3-487d-96b1-955dc1a4da28"")",
            Result = "#table(...)"
        ]}
    ];

runVaultCalculationImpl = (
    optional componentid as text, 
    optional accountid as text, 
    optional startdate as text, 
    optional enddate as text, 
    optional frequency as text, 
    optional configid as text
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
            configid = configid
        ],
        table = RunCalculation(calculation, "vault")
    in
        table;

RunCalculation = (Calculation as record, EngineType as text) =>
    let 
        body = Json.FromValue(Record.AddField([], EngineType, Record.AddField([], "1", Calculation))),
        response = Web.Contents(ENGINES_URL & "calculations", [Headers = [ #"Content-Type" = "application/json"], Content = body, ManualStatusHandling = {202,400,404,500}, IsRetry=true]),
        responseHeaders = Value.Metadata(response)[Headers],
        status = Value.Metadata(response)[Response.Status],
        table = if status = 202 then GetCalculationStatus(response, EngineType)  
               else if status = 400 then error Error.Record("Error", "Invalid input parameters", Text.Combine(List.Combine(Record.FieldValues(Json.Document(response))), " "))
               else if status = 404 then error Error.Record("Error", "Input parameter not found", Text.FromBinary(response))
               else if status = 500 then error Error.Record("Error", "Server Error", "Please report this error to FactSet Support. X-DataDirect-Request-Key " + Record.Field(responseHeaders, "X-DataDirect-RequestKey") + ".")
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
                    statusResponse = Web.Contents(locationUrl, [Headers = [#"Accept" = "application/json"], ManualStatusHandling = {200}, IsRetry = true]),
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
        result = Web.Contents(url, [Headers = [#"Accept" = "application/json"], Query =[format ="bison"], IsRetry = true]),
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
        response = Web.Contents(LOOKUPS_URL & Url, [Headers = [#"Accept" = "application/json"], ManualStatusHandling = {200,400,404,500}, Query = Query]),
        responseHeaders = Value.Metadata(response)[Headers],
        status = Value.Metadata(response)[Response.Status],
        record = if status = 200 then Json.Document(response)
                  else if status = 400 then error Error.Record("Error", "Invalid input parameters", Text.FromBinary(response))
                  else if status = 404 then error Error.Record("Error", "Input parameter not found", Text.FromBinary(response))
                  else if status = 500 then Error.Record("Error", "Server Error", "Please report this error to FactSet Support. X-DataDirect-Request-Key " + Record.Field(responseHeaders, "X-DataDirect-RequestKey") + ".")
                  else error Error.Record("Error", "Unknown Error", Text.FromBinary(response))
    in
        record;
