// This file contains your Data Connector logic
[Version = "2.0.6"]
section Bloomberg;

// shared marks something as a thing that should be exported; Publish makes it appear in the Get Data menu
[DataSource.Kind="Bloomberg", Publish="Bloomberg.Publish"]
shared Bloomberg.Query = Value.ReplaceType(BloombergQuery, EntryPointType);

// Deprecated but still available for backward compatibility of existing reports
[DataSource.Kind="BQL"]
shared BQL.Query = Value.ReplaceType(BQLQuery, EntryPointType);

ConnectorVersion = "2.0.6";

//
// Load common library functions
//
// TEMPORARY WORKAROUND until we're able to reference other M modules
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// Utils
Utils = Extension.LoadFunction("Utils.pqm");
GetQueryType = Utils[GetQueryType];
GenerateTraceParentId = Utils[GenerateTraceParentId];

//Diagnostics
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogTrace = Diagnostics[LogTrace];
Diagnostics.LogValue = Diagnostics[LogValue];

// Auth
Auth = Extension.LoadFunction("Auth.pqm");
Auth.StartLogin= Auth[StartLogin];
Auth.FinishLogin= Auth[FinishLogin];
Auth.Refresh= Auth[Refresh];
Auth.GetBloombergDataSource = Auth[GetBloombergDataSource];

// Folding module
Folding = Extension.LoadFunction("Folding.pqm");
Folding.GetDataWithFolding = Folding[GetDataWithFolding];

// Configuration module
Configuration = Extension.LoadFunction("Configuration.pqm");
Configuration.IsBeta = Configuration[IsBeta];

// Data Handler
DataHandler = Extension.LoadFunction("Data-Handler.pqm");
DataHandler.GetBqlData = DataHandler[GetBqlData];
DataHandler.GetSqlData = DataHandler[GetSqlData];

TestExports = [
    Utils = [
        LoadFunction = Extension.LoadFunction,
        LoadFile = (name as text) => Extension.Contents(name)
    ]
];

EntryPointType = type function (
    Bloomberg as (type text meta [
        DataSource.Path = false,
        Documentation.FieldCaption = Extension.LoadString("Bql.Query.Dialog.Argument.Caption"),
        Documentation.SampleValues = { Extension.LoadString("Bloomberg.Query.SampleValue") },
        Formatting.IsMultiLine = true,
        Formatting.IsCode = true
    ])
    )
    as table meta [
        Documentation.Name = Extension.LoadString("Bql.Query.Dialog.Title") & "  v" & ConnectorVersion,
        Documentation.Description = Extension.LoadString("Bql.Function.Description")
    ];


BloombergQuery = (query as text) => EntryPointImpl(
    query,
    // We want to track which entrypoint function name people are using
    // (the new "Bloomberg.Query" or "BQL.Query", which will be deprecated going forward).
    {
        [key="ConnectorVersion", value=ConnectorVersion],
        [key="EntryPoint", value="Bloomberg.Query"]
    }
);

BQLQuery = (query as text) => EntryPointImpl(
    query,
    {
        [key="ConnectorVersion", value=ConnectorVersion],
        [key="EntryPoint", value="BQL.Query"]
    }
);

EntryPointImpl = (bqlQuery as text, clientContext as list) =>
    let
        bqlQuery1 =  Diagnostics.LogTrace(TraceLevel.Information, Text.Combine({"Connector version ", ConnectorVersion}), bqlQuery),
        bqlQuery2 = Diagnostics.LogValue("Query Bi", bqlQuery1),

        table = if bqlQuery2 = null
            then error Error.Record("Invalid argument", "Query argument cannot be null.")
            else if Text.Clean(bqlQuery2) = ""
                then error Error.Record("Invalid argument", "Query argument cannot be empty.")
            else
                GetData(bqlQuery2, clientContext)
    in
        table;

GetData = (query as text, clientContext as list) =>
    let
        traceParentId = GenerateTraceParentId(),
        queryType =  Diagnostics.LogValue("Query Type is", GetQueryType(query)),
        finalTable  = if queryType = "BQL" then
            DataHandler.GetBqlData(query, clientContext, traceParentId)
        else  if  queryType = "SQL" then
            Folding.GetDataWithFolding(
                [sql=query, traceParentId=traceParentId, clientContext=clientContext]
            )
        else if queryType = "SQLDiscovery" then
            DataHandler.GetSqlData(
                [sql=query, traceParentId=traceParentId, clientContext=clientContext]
            )
        else
            error Error.Record("Invalid Query", "This query is not supported.")
    in
        finalTable;

DataSourceLabel = Extension.LoadString("Bql.DataSource.Label");

Authentication = [
    OAuth = [
        StartLogin = Auth.StartLogin,
        FinishLogin = Auth.FinishLogin,
        Refresh = Auth.Refresh,
        Label = Extension.LoadString("Bql.Auth.Dialog.AccountLabel")
    ]
];

Bloomberg = [
    TestConnection = (dataSourcePath) => { "Bloomberg.Query", "test_connection" },
    Authentication = Authentication,
    Icons = Bloomberg.Icons,
    Label = DataSourceLabel
];

Bloomberg.Icons = [
    Icon16 = {
        Extension.Contents("Bloomberg16.png"),
        Extension.Contents("Bloomberg20.png"),
        Extension.Contents("Bloomberg24.png"),
        Extension.Contents("Bloomberg32.png")
    },
    Icon32 = {
        Extension.Contents("Bloomberg32.png"),
        Extension.Contents("Bloomberg40.png"),
        Extension.Contents("Bloomberg48.png"),
        Extension.Contents("Bloomberg64.png")
    }
];

// Data Source UI publishing description
Bloomberg.Publish = [
    SupportsDirectQuery = false,
    Beta = Configuration.IsBeta,
    Category = "Other",
    ButtonText = {
        Extension.LoadString("Bql.Button.Title"),
        Extension.LoadString("Bql.Button.Help")
    },
    LearnMoreUrl = "https://officetools.bloomberg.com/bi/powerbiconnector",
    SourceImage = Bloomberg.Icons,
    SourceTypeImage = Bloomberg.Icons
];

// A legacy alias of Bloomberg DataSource for backwards compatibility
BQL = [
    TestConnection = (dataSourcePath) => { "BQL.Query", "test_connection" },
    Authentication = Authentication,
    Icons = Bloomberg.Icons,
    Label = DataSourceLabel
];
