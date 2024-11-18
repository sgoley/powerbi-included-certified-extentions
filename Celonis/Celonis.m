[Version="2.2.0"]
section Celonis;

// The app key is provided through the Power BI Credential Manager
APP_KEY = Extension.CurrentCredential()[Key];

// Api Endpoints
CELONIS_EMS_SERVICE_ENDPOINT = "/pbi-service";
API_VERSION = "/api/v1";
SPACES_ENDPOINT = CELONIS_EMS_SERVICE_ENDPOINT & API_VERSION & "/spaces";
KNOWLEDGE_MODEL_ENDPOINT = CELONIS_EMS_SERVICE_ENDPOINT & API_VERSION & "/knowledge-models";
PACKAGE_ENDPOINT = CELONIS_EMS_SERVICE_ENDPOINT & API_VERSION & "/packages";
PACKAGE_BY_PACKAGE_KEY = PACKAGE_ENDPOINT & "/by-package-key";
PACKAGE_BY_SPACE_ID = PACKAGE_ENDPOINT & "/by-space-id";
EXPORT_START_ENDPOINT = CELONIS_EMS_SERVICE_ENDPOINT & API_VERSION & "/export";
EXPORT_STATUS_ENDPOINT = EXPORT_START_ENDPOINT & "/status";
EXPORT_DOWNLOAD_ENDPOINT = EXPORT_START_ENDPOINT & "/download";

// Export Status
EXPORT_STATUS_RUNNING = "RUNNING";
EXPORT_STATUS_DONE = "DONE";

// Data Source Kind description
Celonis = [
    TestConnection = (dataSourcePath) => {"Celonis.Navigation", dataSourcePath},
    Authentication = [
        Key = [Label="Celonis", KeyLabel="Application Key or Personal API Key"]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
Celonis.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://docs.celonis.com/en/ems-connector-for-power-bi.html",
    SourceImage = Celonis.Icons,
    SourceTypeImage = Celonis.Icons
];

Celonis.Icons = [
    Icon16 = { Extension.Contents("Celonis16.png"), Extension.Contents("Celonis20.png"), Extension.Contents("Celonis24.png"), Extension.Contents("Celonis32.png") },
    Icon32 = { Extension.Contents("Celonis32.png"), Extension.Contents("Celonis40.png"), Extension.Contents("Celonis48.png"), Extension.Contents("Celonis64.png") }
];

// Helper function to identify the celonis cluster baseurl 
GetCelonisEMSUrl = (url as text) as text => 
    let
        // Enable for local development to use another port e.g. 9010
        //_url = if Uri.Parts(url)[Port] <> 80 then Uri.Parts(url)[Scheme] & "://" & Uri.Parts(url)[Host] & ":" & Number.ToText(Uri.Parts(url)[Port]) else Uri.Parts(url)[Scheme] & "://" & Uri.Parts(url)[Host] 
        _url = Uri.Parts(url)[Scheme] & "://" & Uri.Parts(url)[Host] & ":" & Number.ToText(Uri.Parts(url)[Port])
    in
        _url;

ValidateUrlScheme = (url as text) as text => if (Uri.Parts(url)[Scheme] <> "https") then error "Url scheme must be HTTPS" else url;

GetChunk = (url as text, keyType as text) =>
    let
        response = Web.Contents(url, [Headers = [
            #"Content-Type" = "application/json",
            Authorization = keyType & APP_KEY
        ]]),
        data = Parquet.Document(Binary.Buffer(response))
    in
        data;

DownloadChunkedParquet = (url as text, numChunks as number, keyType as text) =>
    let
        chunks = List.Transform(List.Numbers(0, numChunks), (i) => GetChunk(url & "/" & Number.ToText(i), keyType)),
        data = Table.Combine(chunks)
    in
        data;

DownloadParquet = (url as text, numChunks as number,  keyType as text) => 
    if numChunks > 1 
        then DownloadChunkedParquet(url, numChunks, keyType)
        else GetChunk(url, keyType);

// Helper which retries checking the export status, until it is done
WaitForExportDone = (baseUrl as text, datasetId as text, jobId as text, keyType as text) =>
    let
        url = baseUrl & EXPORT_STATUS_ENDPOINT & "/" & datasetId & "/" & jobId,
        response = Web.Contents(url, [Headers=[
            #"Content-Type" = "application/json",
            Authorization = keyType & APP_KEY
        ], ManualStatusHandling={404}, IsRetry=true,  Timeout=#duration(0, 0, 3, 0)]),
        responseMetadata = Value.Metadata(response),
        responseCode = responseMetadata[Response.Status],
        status =  Json.Document(response),
        // 404 will be returned when datamodel is not loaded
        result = 
        if responseCode = 404 
            then error Error.Record(status[reason], status[message], status[detail]) 
            else 
                if status[exportStatus] = EXPORT_STATUS_RUNNING 
                    then WaitForExportDone(baseUrl, datasetId, jobId, keyType) 
                    else status
    in
        result;

Record = (
    baseUrl as text, analysisKey as text, recordKey as text, datasetId as text, keyType as text,
    optional limit as number, optional offset as number
) =>
    let
        url = baseUrl & EXPORT_START_ENDPOINT & "/" & analysisKey & "/" & recordKey & "/" & datasetId,
        __params = [],
        _params = if limit <> null then __params & [queryLimit=Number.ToText(limit)] else __params,
        params = if offset <> null then _params & [queryOffset=Number.ToText(offset)] else _params,
        startExportResponse = Web.Contents(url, [Headers=[
            #"Content-Type" = "application/json",
            Authorization = keyType & APP_KEY
        ], Query=params, IsRetry=true, ManualStatusHandling={404}, Content=Json.FromValue([]),  Timeout=#duration(0, 0, 3, 0)]),
        startExportResponseMetadata = Value.Metadata(startExportResponse),
        startExportResponseCode = startExportResponseMetadata[Response.Status],
        status = Json.Document(startExportResponse),

        response =
        if startExportResponseCode = 404 
            then error Error.Record(status[reason], status[message], status[detail]) 
            else if status[exportStatus] = EXPORT_STATUS_RUNNING
                then WaitForExportDone(baseUrl, datasetId, status[id], keyType)
                else status,

        data = 
        if response[exportStatus] <> EXPORT_STATUS_RUNNING
            then DownloadParquet(baseUrl & EXPORT_DOWNLOAD_ENDPOINT & "/" & datasetId & "/" & response[id], response[exportChunks], keyType)
            else response
    in
        data;

Records = (baseUrl as text, analysisKey as text, keyType as text) as table => 
    let
        url = baseUrl & KNOWLEDGE_MODEL_ENDPOINT & "/" & analysisKey,
        response = Web.Contents(url, [Headers=[
            #"Content-Type" = "application/json",
            Authorization = keyType & APP_KEY
        ], ManualStatusHandling={404}]),

        responseMetadata = Value.Metadata(response),
        responseMetadataResponseCode = responseMetadata[Response.Status],
        data = Json.Document(response),

        records = 
        if responseMetadataResponseCode = 404 
            then error Error.Record(data[reason], data[message], data[detail]) 
            else data[layer][records],

        datasetId = data[layer][dataModelId],
        table = Table.FromList(records, Splitter.SplitByNothing(), null, {"Column1"}, ExtraValues.Error),
        expandedTable = Table.ExpandRecordColumn(table, "Column1", {"displayName", "id", "identifier", "attributes", "autoGenerated"}, {"Name", "Key", "identifier", "attributes", "autoGenerated"}),
        add1 = Table.AddColumn(expandedTable, "Data", each Celonis.Record(baseUrl, analysisKey, [Key], datasetId, keyType)),
        add2 = Table.AddColumn(add1, "ItemKind", each 
                                                        if [autoGenerated] = true then "Table"
                                                        else "Record"),
        add3 = Table.AddColumn(add2, "ItemName", each "Table"),
        add4 = Table.AddColumn(add3, "IsLeaf", each true),
        nodes = Table.ToNavigationTable(add4, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        nodes;

Tree = (baseUrl as text, assets as table, rootKey as text, keyType as text) as table =>
    let
        folderAssets = Table.SelectRows(assets, each [ParentNodeKey] = rootKey),
        add1 = Table.AddColumn(folderAssets, "Data", 
            each 
                if [NodeType] = "FOLDER" then Tree(baseUrl, assets, [Key], keyType)
                else if [AssetType] = "SEMANTIC_MODEL" then Records(baseUrl, [RootWithKey], keyType)
                else null
        ),
        add2 = Table.AddColumn(add1, "ItemKind", each if [NodeType] = "FOLDER" then "Folder" else "View"),
        add3 = Table.AddColumn(add2, "ItemName", each if [NodeType] = "FOLDER" then "Folder" else "Table"),
        add4 = Table.AddColumn(add3, "IsLeaf", each false),
        nodes = Table.ToNavigationTable(add4, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        nodes;

Nodes = (baseUrl as text, rootKey as text, keyType as text) as table => 
    let
        url = baseUrl & PACKAGE_BY_PACKAGE_KEY & "/" & rootKey,
        response = Web.Contents(url, [Headers=[
            #"Content-Type" = "application/json",
            Authorization = keyType & APP_KEY
        ]]),
        data = Json.Document(response),
        table = Table.FromList(data, Splitter.SplitByNothing(), {"Column1"}, null, ExtraValues.Error),
        _assets = Table.ExpandRecordColumn(table, "Column1", {"name", "key", "nodeType", "assetType", "rootWithKey", "parentNodeKey"}, {"Name", "Key", "NodeType", "AssetType", "RootWithKey", "ParentNodeKey"}),
        assets = Table.SelectRows(_assets, each [NodeType] = "FOLDER" or [AssetType] = "SEMANTIC_MODEL"),
        tree = Tree(baseUrl, assets, rootKey, keyType)
    in
        tree;

Spaces = (URL as text) as table => 
    let
        // Disable ValidateUrlScheme for local development
        URL = ValidateUrlScheme(URL),
        baseUrl = GetCelonisEMSUrl(URL),
        url = baseUrl & SPACES_ENDPOINT,
        keyType = GetKeyType(url),
        response = Web.Contents(url, [Headers=[
            #"Content-Type" = "application/json",
            Authorization = keyType & APP_KEY
        ]]),
        data = Json.Document(response),
        table = Table.FromList(data, Splitter.SplitByNothing(), {"Column1"}, null, ExtraValues.Error),
        expandedTable = Table.ExpandRecordColumn(table, "Column1", {"name", "id"}, {"Name", "Id"}),
        add1 = Table.AddColumn(expandedTable, "Data", each Space(baseUrl, [Id], keyType)),
        add2 = Table.AddColumn(add1, "ItemKind", each "Folder"),
        add3 = Table.AddColumn(add2, "ItemName", each "Package"),
        add4 = Table.AddColumn(add3, "IsLeaf", each false),
        nodes = Table.ToNavigationTable(add4, {"Id"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        nodes;

Space = (baseUrl as text, spaceId as text, keyType as text) as table =>
    let 
        url = baseUrl & PACKAGE_BY_SPACE_ID & "/" & spaceId,
        response = Web.Contents(url, [Headers=[
            #"Content-Type" = "application/json",
            Authorization = keyType & APP_KEY
        ]]),
        data = Json.Document(response),
        table = Table.FromList(data, Splitter.SplitByNothing(), {"Column1"}, null, ExtraValues.Error),
        expandedTable = Table.ExpandRecordColumn(table, "Column1", {"name", "key", "nodeType", "assetType", "rootWithKey", "parentNodeKey"}, {"Name", "Key", "NodeType", "AssetType", "RootWithKey", "ParentNodeKey"}),
        filteredTable = Table.SelectRows(expandedTable, each [NodeType] = "PACKAGE"),
        add1 = Table.AddColumn(filteredTable, "Data", each Nodes(baseUrl, [Key], keyType)),
        add2 = Table.AddColumn(add1, "ItemKind", each "Database"),
        add3 = Table.AddColumn(add2, "ItemName", each "Package"),
        add4 = Table.AddColumn(add3, "IsLeaf", each false),
        nodes = Table.ToNavigationTable(add4, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        nodes;

KnowledgeModels = (URL as text) => 
    let
        // Disable ValidateUrlScheme for local development
        URL = ValidateUrlScheme(URL),
        baseUrl = GetCelonisEMSUrl(URL),
        url = baseUrl & KNOWLEDGE_MODEL_ENDPOINT,
        keyType = GetKeyType(url),
        response = Web.Contents(url, [Headers=[
            #"Content-Type" = "application/json",
            Authorization = keyType & APP_KEY
        ]]),
        data = Json.Document(response),
        table = Table.FromList(data, Splitter.SplitByNothing(), null, {"Column1"}, ExtraValues.Error),
        assets = Table.ExpandRecordColumn(table, "Column1", {"name", "rootWithKey"}, {"Name", "Key"}),
        add1 = Table.AddColumn(assets, "Data", each Records(baseUrl, [Key]), keyType),
        add2 = Table.AddColumn(add1, "ItemKind", each "Dimension"),
        add3 = Table.AddColumn(add2, "ItemName", each "Knowledge Model"),
        add4 = Table.AddColumn(add3, "IsLeaf", each false),
        nodes = Table.ToNavigationTable(add4, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        nodes;

GetKeyType = (url as text) =>
    let
        response = Web.Contents(url, [Headers=[
            #"Content-Type" = "application/json",
            Authorization = "AppKey " & APP_KEY
        ], ManualStatusHandling = {401}, IsRetry = true]),
        responseMetadata = Value.Metadata(response),
        responseCode = responseMetadata[Response.Status],
        keyType = if responseCode = 401 then "Bearer " 
                                        else "AppKey "
    in
        keyType;

// Celonis specific implementation of `Table.View` to model a Knowledge Model Record.
Celonis.Record = (baseUrl as text, rootKey as text, recordKey as text, datasetId as text, keyType as text) as table =>
    let
        View = (state as record) => Table.View(null, [
            GetType = () => Value.Type(Record(baseUrl, rootKey, recordKey, datasetId, keyType, 1)),
        
            GetRows = () =>
                let
                    limit = if state[Top]? <> null then state[Top] else null,
                    offset = if state[Skip]? <> null then state[Skip] else null,
                    tab = Record(baseUrl, rootKey, recordKey, datasetId, keyType, limit, offset)
                in
                    tab,

            OnTake = (count as number) =>
                let
                    newState = state & [ Top = count ]
                in
                    @View(newState),

            OnSkip = (count as number) =>
                let
                    newState = state & [ Skip = count ]
                in
                    @View(newState)
        ])
    in
        View([]);

// The primary data source type for the Celonis connector. Will be used in calls to `Value.ReplaceType`.
CelonisType = type function (
    URL as (Uri.Type meta [
        Documentation.FieldCaption = "Celonis URL",
        Documentation.FieldDescription = "Enter your team's Celonis EMS URL.",
        Documentation.SampleValues = {"https://team.eu-1.celonis.cloud"}
    ])
    ) as table meta [Documentation.Name = "Celonis EMS"];

[DataSource.Kind="Celonis", Publish="Celonis.Publish"]
shared Celonis.Navigation = Value.ReplaceType(Spaces, CelonisType);

[DataSource.Kind="Celonis"]
shared Celonis.KnowledgeModels = Value.ReplaceType(KnowledgeModels, CelonisType);

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

Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");
