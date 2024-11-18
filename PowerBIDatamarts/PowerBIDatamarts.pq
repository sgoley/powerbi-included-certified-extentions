[Version = "1.0.12"]
section PowerBIDatamarts;

ApiErrorStatusCodes = { 400, 403, 404, 500, 503 };
AadAuthorizationUri =  Uri.Combine(Environment.FeatureSwitch("AzureActiveDirectoryUri", "https://login.microsoftonline.com"), "common/oauth2/authorize");
AadWorkspaceApiOAuthResource = Environment.FeatureSwitch("PowerBiAadResource", "https://analysis.windows.net/powerbi/api");
PBIBaseUrl = Environment.FeatureSwitch("PowerBiUri", "https://api.powerbi.com");
apiurl = GetClusterUrl(PBIBaseUrl);
RootResourcePath = "PowerBIDatamarts";

PowerBIDatamarts = [
    Type = "Custom",
    MakeResourcePath = (server) => server ?? RootResourcePath,
    ParseResourcePath = (resourcePath) => {
        if resourcePath = RootResourcePath
        then null else resourcePath },
    TestConnection = (resourcePath) => {"PowerBI.Datamarts" , ServerFromPath(resourcePath) },
    Authentication = [
          Aad = [
                   AuthorizationUri = AadAuthorizationUri,
                   Resource = "",
                   Scope = Text.Format("#{1}/#{0}", {"user_impersonation", AadWorkspaceApiOAuthResource})
                ]
           ],

// valid DSRs
/*
{"protocol":"powerbi-datamarts","address":{}}
{"protocol":"powerbi-datamarts","address":{"workspace":"66402100-396f-41d4-8e88-19e8c6ae0834"}}
{"protocol":"powerbi-datamarts","address":{"workspace":"66402100-396f-41d4-8e88-19e8c6ae0834","datamart":"a83d87f0-70e7-497a-8ad2-757a63d499ef"}}
{"protocol":"powerbi-datamarts","address":{"workspace":"66402100-396f-41d4-8e88-19e8c6ae0834","datamart":"a83d87f0-70e7-497a-8ad2-757a63d499ef","item":"Product","schema":"model"}}
{"protocol":"powerbi-datamarts","address":{"server":"x6eps4xrq2xudenlfv6naeo3i4-kgvm5fhxn5revlmvfkhhe63xae.msit-datamart.pbidedicated.windows.net"}}
{"protocol":"powerbi-datamarts","address":{"server":"x6eps4xrq2xudenlfv6naeo3i4-kgvm5fhxn5revlmvfkhhe63xae.msit-datamart.pbidedicated.windows.net","item":"Product","schema":"model"}}
*/
   DSRHandlers = [
        #"powerbi-datamarts" = [
            GetDSR = (server, optional navigation) =>
                let
                    workspace = navigation{0}?[workspaceObjectId]?,
                    datamart = navigation{2}?[artifactObjectId]?,
                    Item =  if (server <> null and navigation{0}?[Item]? <> null) then navigation{0}?[Item]?
                              else if (server <> null) then null
                              else  navigation{4}?[Item]?,
                    Schema =  if (server <> null and navigation{0}?[Item]? <> null) then navigation{0}?[Schema]?
                              else if (server <> null) then null
                              else  navigation{4}?[Schema]?,
                    count = List.Count(navigation),
                    matchWorkspace =  if server = null then  List.FirstN({ [workspaceObjectId=workspace], "Data", [artifactObjectId=datamart], "Data",[Item = Item,Schema = Schema],"Data"}, count) else null,
                    matchServer = if (server <> null) then List.FirstN({[Item = Item,Schema = Schema],"Data"}, count) else null,
                    isMatchWorkspace = if (matchWorkspace <> null) then List.FirstN(matchWorkspace, count) = navigation else false,
                    isMatchServer = if (matchServer <> null) then List.FirstN(matchServer, count) = navigation else false,
                    isValid = isMatchServer or isMatchWorkspace,
                    address = if not isValid then ...
                              else if (server <> null and navigation{0}?[Item]? <> null) then [server = server,item = Item,schema = Schema]
                              else if server <> null then [server = server]
                              else if count = 0 then []
                              else Record.RenameFields(Record.Combine(List.RemoveItems(matchWorkspace, {"Data"})), {{"workspaceObjectId", "workspace"}, {"artifactObjectId", "datamart"},{"Item","item"},{"Schema","schema"}}, MissingField.Ignore)
                in
                   [ protocol = "powerbi-datamarts", address = address ],
            GetFormula = (dsr, optional options) =>
                let
                    isWorkspace = Record.HasFields(dsr[address], "workspace"),
                    isEndPoint = Record.HasFields(dsr[address], "server"),
                    workspace = Record.FieldOrDefault(dsr[address], "workspace", null),
                    server = Record.FieldOrDefault(dsr[address], "server", null),
                    datamart = Record.FieldOrDefault(dsr[address], "datamart", null),
                    item = Record.FieldOrDefault(dsr[address],"item",null),
                    schema = Record.FieldOrDefault(dsr[address],"schema",null)
                in
                    if (isWorkspace) then
                        if (workspace <> null) then
                             if (datamart <> null and item <> null ) then
                                () => PowerBI.Datamarts(null){[workspaceObjectId=workspace]}[Data]{[artifactObjectId=datamart]}[Data]{[Item=item,Schema = schema]}[Data]
                             else if (datamart <> null) then
                                () => PowerBI.Datamarts(null){[workspaceObjectId=workspace]}[Data]{[artifactObjectId=datamart]}[Data]
                             else
                                () => PowerBI.Datamarts(null){[workspaceObjectId=workspace]}[Data]
                        else
                             () => PowerBI.Datamarts(null)
                    else if (isEndPoint) then
                             if (item <> null ) then
                                  () => PowerBI.Datamarts(server){[Item=item,Schema = schema]}[Data]
                             else
                                  () => PowerBI.Datamarts(server)
                    else
                        () => PowerBI.Datamarts(null),

            GetFriendlyName = (dsr) => "Power BI Datamarts"
        ]
   ]
];

ServerFromPath = (path) => if path = RootResourcePath then null else path;

[DataSource.Kind = "PowerBIDatamarts" , Publish="PowerBIDatamarts.Publish"]
shared PowerBI.Datamarts = Value.ReplaceType(DatamartsImpl,Datamarts.Type);

DatamartsImpl = (optional server as text) =>
    let
        result = if(server = null) then GetNavforWorkspaces() else GetNavforSqlTable(server)
    in
        result;

GetNavforWorkspaces = () =>
    let
        clusterendpoint = Uri.Combine(apiurl,"/metadata/v202202/datahub/artifacts"),
        option =       [
                            Headers = [
                                       #"ActivityId" = Diagnostics.ActivityId(),
                                       #"RequestId" = Diagnostics.ActivityId(),
                                       #"x-ms-version" = "2020-12-06",
                                       #"Content-type" = "application/json"
                            ],
                            Content = Json.FromValue([supportedTypes = {11}])
                        ],
        jsonResponse = Web.JsonContents(clusterendpoint ,option),
        alldatamarts =  ConvertToTable(jsonResponse),
        navtable = CreateNavTable(alldatamarts)
     in
        navtable;

Datamarts.Type =
    let
       serverType = type nullable text meta [
                                            Documentation.FieldCaption = Extension.LoadString("ServerCaption"),
                                            Documentation.FieldDescription = Extension.LoadString("ServerDescription"),
                                            Documentation.SampleValues = {Extension.LoadString("ServerSampleValue")}
                                      ],
       DatamartsType = type function ( optional server as serverType )
                      as table meta [
                                Documentation.Name = Extension.LoadString("Datamarts_Title"),
                                Documentation.Caption = Extension.LoadString("Datamarts_Title"),
                                Documentation.Description = Extension.LoadString("Datamarts_Description"),
                                Documentation.LongDescription = Extension.LoadString("Datamarts_LongDescription")
                      ]
     in
       DatamartsType;

GetClusterUrl = (baseUrl as text) =>
    let
        retryCountCodes = {500},
        maxRetryCount = 5,
        props = Extension.CurrentApplication(),
        serviceEndpoint = baseUrl,
        disco = Uri.Combine(serviceEndpoint, "/powerbi/globalservice/v201606/clusterdetails"),
        response = Web.JsonContents(disco, [Headers = PBICommonHeaders(null,disco)], retryCountCodes, maxRetryCount),
        clusterUrl = response[clusterUrl]
    in
        clusterUrl;

Web.JsonContents = (url as text, optional options as record, optional retryableErrorCodes as list, optional retryCount as number) =>
    let
        nonEmptyOptions = options ?? [],
        baseUrl = url,
        response = Web.Contents(baseUrl, nonEmptyOptions & [ManualStatusHandling = ApiErrorStatusCodes]),
        jsonResponse = Json.Document(response) meta Value.Metadata(response),
        responseStatusCode = Record.FieldOrDefault(Value.Metadata(jsonResponse), "Response.Status", 0)
    in
        if List.Contains(ApiErrorStatusCodes, responseStatusCode) then Web.ErrorResponse(url, jsonResponse) else jsonResponse;

Web.ErrorResponse = (url as text, jsonResponse as record) =>
    let
        responseStatusCode = Record.FieldOrDefault(Value.Metadata(jsonResponse), "Response.Status", 0),
        requestId = Record.FieldOrDefault(Value.Metadata(jsonResponse)[Headers], "RequestId", ""),

        errorCode = jsonResponse[error][code]? ?? "DataSource.Error",
        errorMessage = jsonResponse[error][message]? ?? jsonResponse[error][pbi.error][parameters][ErrorMessage]? ??
            Text.Format(Extension.LoadString("ErrorResponseError"), responseStatusCode, url),
        errorDetails = if jsonResponse[error]? = null then jsonResponse[errorDetails]? else
            [
                Error = if List.IsEmpty(jsonResponse[error][pbi.error][details]) then errorMessage
                            else Text.Combine(jsonResponse[error][pbi.error][details], " "),
                #"RequestId" = requestId,
                #"RequestUrl" = url
            ],
        ErrorResponse =
                    error Error.Record(
                        errorCode,
                        errorMessage,
                        errorDetails)
    in
        ErrorResponse;

PBICommonHeaders = (tenantId as nullable text, url as text) =>
    let
        newActivityId = Text.NewGuid(),
        loggedActivityId = Diagnostics.Trace(TraceLevel.Information, [Name="Request", Data=[], SafeData=[RequestId=newActivityId, Uri=url]], newActivityId),
        headers = [
            #"x-ms-client-request-id" = loggedActivityId,
            #"x-ms-client-session-id" = Diagnostics.ActivityId(),
            #"RequestId" = Diagnostics.ActivityId(),
            #"ActivityId" = newActivityId
        ],
        tenantIdHeaders = if tenantId <> null then [#"x-ms-tid" = tenantId] else []
    in
        headers & tenantIdHeaders;

ConvertToTable = (jsonResponse as list) as table =>
    let
        #"Converted to Table" = Table.FromList(jsonResponse, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"artifactId", "artifactObjectId", "displayName", "artifactType", "artifact", "workspaceId", "workspaceObjectId", "workspaceName", "workspaceType"}),
        ExpandArtifact = Table.ExpandRecordColumn(#"Expanded Column1", "artifact", {"datamartType"}, {"artifact.datamartType"}),
        // Select only Datamarts (remove Lakehouses (datamartType=2) and Warehouses (datamartType=4))
        SelectDatamarts = Table.SelectRows(ExpandArtifact, each ([artifact.datamartType] = 1)),
        RemoveColumns = Table.RemoveColumns(SelectDatamarts,{"artifact.datamartType"})
     in
        RemoveColumns;

CreateNavTable = (datamarts as table) as table =>
    let
           Workspaces = List.Distinct(datamarts[workspaceObjectId]),
           WorkspacesTable = Table.FromList(Workspaces,Splitter.SplitByNothing(),{"workspaceObjectId"}),
           withWorkspaceName = Table.AddColumn(WorkspacesTable,"workspaceName",each GetWorkspaceName([workspaceObjectId],datamarts),type text),
           withData =  Table.AddColumn(withWorkspaceName ,"Data",each GetDataMarts([workspaceObjectId],datamarts),type table),
           addItemKind = Table.AddColumn(withData,"ItemKind",each "Folder"),
           withItemName = Table.AddColumn(addItemKind,"ItemName",each "Folder"),
           withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false),
           nav = Table.ToNavigationTable(withIsLeaf, {"workspaceObjectId"}, "workspaceName", "Data", "ItemKind", "ItemName", "IsLeaf")
     in
           nav;

GetWorkspaceName = (workspaceObjectId as text, datamarts as table) as text =>
    let
        datamartsInWorkspace = Table.SelectRows(datamarts,each [workspaceObjectId] = workspaceObjectId)
     in
        datamartsInWorkspace[workspaceName]{0};

GetDataMarts = (workspaceObjectId as text, datamarts as table) as table =>
    let
        datamartsInWorkspace = Table.SelectRows(datamarts,each [workspaceObjectId] = workspaceObjectId),
        withOnlyNameColumn = Table.SelectColumns(datamartsInWorkspace,{"displayName","artifactObjectId"}),
        withData =  Table.AddColumn(withOnlyNameColumn,"Data",each GetTables([artifactObjectId]),type table),
        addItemKind = Table.AddColumn(withData,"ItemKind",each "Database"),
        withItemName = Table.AddColumn(addItemKind,"ItemName",each "Database"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false),
        nav = Table.ToNavigationTable(withIsLeaf, {"artifactObjectId"}, "displayName", "Data", "ItemKind", "ItemName", "IsLeaf")
     in
        nav;

GetTables = (objectID as text) as table =>
    let
          jsonResponse = GetTDSEndPoint(objectID),
          tdsEndPoint = jsonResponse[tdsEndpoint],
          nav = GetNavforSqlTable(tdsEndPoint)
     in
          nav;

GetNavforSqlTable = (tdsEndPoint as text) =>
    let
          navtable = GetSQLTables(tdsEndPoint),
          onlyDataTables = Table.SelectRows(navtable,each [Schema] = "model" or [Schema] = "metadata"),
          withIsLeaf = Table.AddColumn(onlyDataTables, "IsLeaf", each true),
          keyRemoved = Table.ReplaceKeys(withIsLeaf, {}),
          nav = Table.ToNavigationTable(keyRemoved, {"Schema","Item"}, "Item", "Data", "Kind", "Item", "isLeaf")
     in
          nav;

GetSQLTables = (tdsEndPoint as text) =>
    Extension.InvokeWithCredentials(
         (datasource) => Extension.CurrentCredential(),
         () =>
            let
                database = Sql.Database(tdsEndPoint,"", [LegacyExtension=true])
            in
                database
    );

GetTDSEndPoint = (objectID as text) as record  =>
    let
        url = Uri.Combine(apiurl, Text.Format("/metadata/v202204/datamarts/#{0}", {objectID})),
        response = Web.Contents(url),
        jsonResponse = Json.Document(response) meta Value.Metadata(response),
        responseStatusCode = Record.FieldOrDefault(Value.Metadata(jsonResponse), "Response.Status", 0)
     in
        if List.Contains(ApiErrorStatusCodes, responseStatusCode) then Web.ErrorResponse(responseStatusCode,jsonResponse) else jsonResponse;

PowerBIDatamarts.Publish = [
    Name = "Datamarts",
    SupportsDirectQuery = true,
    Category = "Fabric",
    ButtonText = {
            Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp")
        },
    SourceImage = PowerBIDatamarts.Icons,
    SourceTypeImage = PowerBIDatamarts.Icons,
    Beta = true
];

PowerBIDatamarts.Icons = [
    Icon16 = { Extension.Contents("PowerBIDatamarts_16.png"), Extension.Contents("PowerBIDatamarts_20.png"), Extension.Contents("PowerBIDatamarts_24.png"), Extension.Contents("PowerBIDatamarts_32.png") },
    Icon32 = { Extension.Contents("PowerBIDatamarts_32.png"), Extension.Contents("PowerBIDatamarts_40.png"), Extension.Contents("PowerBIDatamarts_48.png"), Extension.Contents("PowerBIDatamarts_64.png") }
];

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
