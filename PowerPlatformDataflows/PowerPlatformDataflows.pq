[
    Version = "1.0.25",
    Requires = [
        Legacy = "[0.0,)",
        DataSource = "[0.0,)",
        Environment = "[0.0,)",
        Extensibility = "[0.0,)",
        ParallelEvaluation = "[0.0,)",
        SqlDatabase = "[0.0,)"
    ]
]
section PowerPlatformDataflows;

// -----------------------------------------------------
// | PowerPlatform.Dataflows() Navigation Table
// -----------------------------------------------------
//  |- Environments
//      |- Environment
//      |- Environment
//          |- Dataflow
//              |- Entity
//              |- Entity
//          |- Dataflow
//              |- Entity
//              |- Entity
//  |- Workspaces
//      |- Workspace
//      |- Workspace
//          |- Dataflow
//              |- Entity
//              |- Entity
//          |- Dataflow
//              |- Entity
//              |- Entity
//
// -----------------------------------------------------

environments = [
    global = "global", tip1 = "tip1", local = "local", usnat = "usnat",
    gcc = "gcc", gcc_high = "gcc_high", gcc_dod = "gcc_dod",
    ppe = "ppe", chinacloud = "chinacloud", PpeCloud = "PpeCloud"];
env = Environment.FeatureSwitch("Cloud", environments[global]);

// These settings only required by this connector.
// We'll not add environment settings explicitly for the settings used by a single connector.
AadGroupApiOAuthResourceEnv = [
    global      = "https://powerquery.microsoft.com",
    usnat       = "https://usnat.powerquery.eaglex.ic.gov",
    gcc         = "https://gov.powerquery.microsoft.us",
    gcc_high    = "https://high.powerquery.microsoft.us",
    gcc_dod     = "https://mil.powerquery.microsoft.us",
    chinacloud  = "https://powerquery.azure.cn",
    tip1        = "https://powerquery.microsoft.com",
    local       = "https://pq-df.microsoft.com"
];
AadPowerAppsResourceEnv = [
    global      = "https://service.powerapps.com",
    usnat       = "https://service.apps.appsplatform.us",
    gcc         = "https://gov.service.powerapps.us",
    gcc_high    = "https://high.service.powerapps.us",
    gcc_dod     = "https://service.apps.appsplatform.us",
    chinacloud  = "https://service.powerapps.cn"
];
BapBaseUrlEnv = [
    global      = "https://api.bap.microsoft.com",
    usnat       = "https://api.bap.appsplatform.us",
    gcc         = "https://gov.api.bap.microsoft.us",
    gcc_high    = "https://high.api.bap.microsoft.us",
    gcc_dod     = "https://api.bap.appsplatform.us",
    chinacloud  = "https://api.bap.partner.microsoftonline.cn",
    tip1        = "https://tip1.api.bap.microsoft.com"
];

AadGroupApiOAuthResource = Utility.GetUrlWithEnv(AadGroupApiOAuthResourceEnv, env, AadGroupApiOAuthResourceEnv[global]);
AadPowerAppsServiceResource = Utility.GetUrlWithEnv(AadPowerAppsResourceEnv, env, AadPowerAppsResourceEnv[global]);
BapBaseUri = Utility.GetUrlWithEnv(BapBaseUrlEnv, env, BapBaseUrlEnv[global]);

PBIBaseUrl = Environment.FeatureSwitch("PowerBiUri", "https://api.powerbi.com");
AadWorkspaceApiOAuthResource = Environment.FeatureSwitch("PowerBiAadResource", "https://analysis.windows.net/powerbi/api");
AadAuthorizationUri =  Uri.Combine(Environment.FeatureSwitch("AzureActiveDirectoryUri", "https://login.microsoftonline.com"), "/common/oauth2/authorize");
AadAdlsStorageResource = Environment.FeatureSwitch("AzureStorageAadResource", "https://storage.azure.com");

PowerQueryWebRootLocal = "https://onebox.pq-df.microsoft.com:9443";
AadRedirectUrl = "https://preview.powerbi.com/views/oauthredirect.html";

ApiErrorStatusCodes = { 400, 403, 404, 500, 503 };
Concurrency = 16;

// CDM / CDS-A types.
// The list of the data types get supported:
// https://powerbi.visualstudio.com/MWC/_git/workload-cdsa?path=%2FObjectModel%2FMicrosoft.Dataflows.ObjectModel%2FModel%2FDataType.cs
TypeMap =
    #table(type table [T = text, M = type, S = text], {
        {"boolean", type nullable Logical.Type, "bit"},
        {"date", type nullable Date.Type, "date"},
        {"datetime", type nullable DateTime.Type, "datetime2"},
        {"datetimeoffset", type nullable DateTimeZone.Type, "datetimeoffset"},
        {"decimal", type nullable Decimal.Type, "decimal"},
        {"double", type nullable Double.Type, "float"},
        {"guid", type nullable Text.Type, "uniqueidentifier"},
        {"int64", type nullable Int64.Type, "bigint"},
        {"json", type nullable Text.Type, "nvarchar(4000)"},
        {"string", type nullable Text.Type, "nvarchar(4000)"},
        {"time", type nullable Time.Type, "time"},
        {"unclassified", type any, "error"}
    });

// Initially we support only a minimal subset (UTF-8 & ISO-8859-1) suggested by RFC 5987(https://datatracker.ietf.org/doc/html/rfc5987)
// which is consistent with the IANA standard (https://www.iana.org/assignments/character-sets/character-sets.xhtml)
CodepageIdEncodingMap = [
    #"UTF-8" = 65001,
    #"ISO-8859-1" = 28591,
    #"WINDOWS-1252" = 1252
];

[DataSource.Kind="PowerPlatformDataflows", Publish="PowerPlatformDataflows.Publish"]
shared PowerPlatform.Dataflows = Value.ReplaceType(DataflowsView, DataflowsType);

DataflowsType =
    let
        functionType = type function (optional options as record)
            as table meta [
                Documentation.Name = "PowerPlatform.Dataflows",
                Documentation.Caption = Extension.LoadString("dataflows.caption"),
                Documentation.Description = Extension.LoadString("dataflows.description"),
                Documentation.LongDescription = Extension.LoadString("dataflows.longDescription")
            ]
    in
        functionType;

PpdfOptionsMap = #table(
    {"Name","Type","Default","Validate"}, {
    {"EnableFolding", type nullable logical, true, each _ = null or _ = true or _ = false}
});

DataflowsView = (optional options as record) as table =>
    let
        invoke = DataflowsImpl(options),
        view = (x) => Table.View(null, Handlers((op, transform) =>
            if List.Contains({"GetRows", "GetType", "GetRowCount", "GetExpression", "OnTestConnection"}, op) then transform(x(invoke))
            else @view((y) => transform(x(y)))))
    in
        view((t) => t);

DataflowsImpl = (optional options as record) =>
    let
        validatedOptions = ValidateOptions(options, PpdfOptionsMap),

        environmentsRow = if env <> environments[ppe] and env <> environments[PpeCloud]
            then {{Extension.LoadString("Environments"), "Environments", Environments(validatedOptions)}}
            else {},
        workspacesRow = if env <> environments[local]
            then {{Extension.LoadString("Workspaces"), "Workspaces", Workspaces(validatedOptions)}}
            else {},
        table = #table({"Name", "Id", "Data"}, List.Combine({environmentsRow, workspacesRow})),

        // build nav table
        withItemKind = Table.AddColumn(table, "ItemKind", each "Folder"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Folder"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false),
        nav = Table.ToNavigationTable(withIsLeaf, {"Id"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        nav;

Environments = (options) =>
    Extension.InvokeWithCredentials(
         (datasource) =>
            [ AuthenticationKind = "Anonymous" ],
         () =>
            let
                result = Group.GetNavTableForGroups(env, options)
            in
                result
    );

Workspaces = (options) =>
    Extension.InvokeWithCredentials(
         (datasource) =>
            if (datasource[DataSource.Kind] = "AzureBlobs") then [ AuthenticationKind = "Anonymous" ]
            else if datasource[DataSource.Kind] = "AzureDataLakeStorage" then DataLake.GetAzureDataLakeStorageCredentials()
            else Extension.CurrentCredential(),
         () =>
            let
                result = Workspace.GetNavTableForWorkspaces(options)
            in
                result
    );

// -----------------------------------------------------
// | 1. Group (Environment)
// -----------------------------------------------------
Group.GetNavTableForGroups = (env as text, options as nullable record) as nullable table =>
    let
        credential = Group.AuthCredential(AadGroupApiOAuthResource),
        isLocal = env = environments[local],
        allEnvironments = if isLocal then null else Group.GetEnvironments(env),
        groups = if isLocal
            then Group.GetGroups(credential, PowerQueryWebRootLocal)
            else Group.GetGroupsAllCluster(allEnvironments, credential),
        withData = Table.AddColumn(groups, "Data", each
            if ([errorCode] <> null) then
                error Error.Record(
                        "DataSource.Error",
                        Extension.LoadString("EnvironmentError"),
                        [
                            Error = [errorCode]
                        ])
            else
                Group.GetNavTableForGroup(credential, [baseUrl], [groupId], options)),

        // build nav table
        nav = Table.NavigationTableView(
            () => withData,
            {"groupId"},
            (groupId) =>
                try
                    let row = Table.FromRecords(allEnvironments){[name = groupId]}
                    in Group.GetNavTableForGroup(credential, row[endpoint], groupId, options)
                otherwise null,
            [
                Name = {"groupName", each [groupName]},
                baseUrl = each [baseUrl],
                Data = each [Data],
                ItemKind = each "Folder",
                ItemName = each "Folder",
                IsLeaf = each false
            ])
    in
        nav;

Group.GetNavTableForGroup = (credential as record, baseUrl as text, groupId as text, options as nullable record) as nullable table =>
    let
        dataflows = Group.GetDataflows(credential, baseUrl, groupId),
        withData = Table.AddColumn(dataflows, "Data", each Group.GetNavTableForDataflow(credential, baseUrl, groupId, [dataflowId], options)),

        // build nav table
        nav = Table.NavigationTableView(
            () => withData,
            {"dataflowId"},
            (dataflowId) => Group.GetNavTableForDataflow(credential, baseUrl, groupId, dataflowId, options),
            [
                Name = {"dataflowName", each [dataflowName]},
                description = each [description],
                Data = each [Data],
                ItemKind = each "Database",
                ItemName = each "Database",
                IsLeaf = each false
            ])
    in
        nav;

Group.GetNavTableForDataflow = (credential as record, baseUrl as text, groupId as text, dataflowId as text, options as nullable record) as nullable table =>
    let
        dataflow = Group.GetDataflow(credential, baseUrl, groupId, dataflowId, options),

        // build nav table
        withItemKind = Table.AddColumn(dataflow, "ItemKind", each "Table"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true),
        nav = Table.ToNavigationTable(withIsLeaf, {"entity"}, "entity", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        nav;

Group.GetGroupsAllCluster = (environments as list, credential as record) as table =>
    let
        endpoints = List.Distinct(List.Transform(environments, each [endpoint])),
        getGroups = List.Transform(endpoints, (endpoint) => () =>
            let
                // The failure of one region shouldn't block the connector. 
                // Ignore the regions when the PQO instance does not respond at all or return any error response.
                result = try Group.GetGroups(credential, endpoint) otherwise #table(null,{})
            in
                result),
        batches = List.ParallelInvoke(getGroups, Concurrency),
        combined = Table.ExpandTableColumn(Table.FromColumns({batches}), "Column1", {"groupId", "groupName", "baseUrl", "errorCode"}),
        pruned = Table.SelectRows(combined, each [baseUrl] <> null)
    in
        pruned;

Group.GetGroups = (credential as record, baseUrl as text) as table =>
    let
        url = Uri.Combine(baseUrl, "/api/dataflowConnector/groups"),
        response = Web.JsonContents(url, Group.AuthHeader(credential)),
        groups = Table.FromRecords(response, {"groupId", "name", "errorCode"}, MissingField.UseNull),
        rename = Table.RenameColumns(groups, {{"name", "groupName"}}),
        result = Table.AddColumn(rename, "baseUrl", each baseUrl)
    in
        result;

Group.GetDataflows = (credential as record, baseUrl as text, groupId as text) as nullable table =>
    let
        url = Uri.Combine(baseUrl, Text.Format("/api/dataflowConnector/group/#{0}/dataflowsInfo", {groupId})),
        response = Web.JsonContents(url, Group.AuthHeader(credential)),
        dataflows = Table.FromRecords(response, {"dataflowId", "name", "description"}),
        rename = Table.RenameColumns(dataflows, {{"name", "dataflowName"}})
    in
        Table.View(null, [
            GetType = () => type table [dataflowId=text, dataflowName=text, description=nullable text],
            GetRows = () => if response = null then #table(GetType(), {}) else rename
        ]);

Group.GetDataflow = (credential as record, baseUrl as text, groupId as text, dataflowId as text, options as nullable record) as nullable table =>
    let
        url = Uri.Combine(baseUrl, Text.Format("/api/dataflowConnector/dataflow/#{0}", {dataflowId})),
        response = Web.JsonContents(url, Group.AuthHeader(credential)),
        json = if response[model] <> null then response[model] else [],

        dataflow = Record.SelectFields(json, {"culture", "entities", "relationships"}, MissingField.UseNull),
        renameFields = Record.RenameFields(dataflow, {{"culture", "dataflowCulture"}}),
        transformFields = Record.TransformFields(renameFields, {
            {"dataflowCulture", each if (_ = null) then "" else _}
        }),
        toTable = Table.FromRecords({transformFields}),
        entities = Table.AddColumn(toTable, "Entities", each if ([entities] <> null) then FormatEntitiesForDataflow(baseUrl, "", "", dataflowId, [entities], "", false, credential, options) else null, type nullable table),
        noNulls = Table.SelectRows(entities, each [Entities] <> null),
        expandEntities = Table.ExpandTableColumn(noNulls, "Entities", {"name", "Data"}, {"entity", "Data"}),

        withRelationships = ProcessRelationships(expandEntities, groupId, dataflowId, dataflow[relationships]?),
        selectColumns = Table.SelectColumns(withRelationships, {"entity", "Data"})
    in
        Table.View(null, [
            GetType = () => type table [entity=text, Data=nullable table],
            GetRows = () => if response = null then #table(GetType(), {}) else selectColumns
        ]);

Group.GetStorageAccess = (credential as record, baseUrl as text, dataflowId as text, partitionName as text, entityName as text) as record =>
    let
        url = Uri.Combine(baseUrl, Text.Format("/api/dataflowConnector/dataflow/#{0}/storageAccess", {dataflowId})),
        body = [
            partitionName = partitionName,
            entityName = entityName
        ],
        headers = Group.AuthHeader(credential)[Headers],
        withContentTypes = headers & [
            #"Content-type" = "application/json",
            #"Accept" = "application/json"
        ],
        response = Web.JsonContents(url, [
            Headers = withContentTypes,
            Content = Json.FromValue(body)
        ]),
        uri = response[uri],
        queryString = response[sasKey]
    in
        [URL = uri, AccessType = "Adls2Sas", Sas = queryString];

Group.AuthCredential = (resource as text) as record =>
    let
        currentCredentials = Extension.CurrentCredential(),
        prop = "AccessToken:" & resource
    in
        currentCredentials & [access_token = Record.FieldOrDefault(currentCredentials[Properties], prop, currentCredentials[access_token])];

Group.AuthHeader = (credential as record) as record =>
    let
        result = [Headers = [Authorization = "Bearer " & credential[access_token]]]
    in
        result;

// Note: The mapping needs to be kept in sync with endpointMappingService.ts in the Maker Portal.
//       Link to the resource file: https://msazure.visualstudio.com/OneAgile/_git/power-platform-ux?path=%2Fpackages%2Fpowerapps-portal-angularjs%2Fsrc%2Fapp%2Fpowerquery%2Fservices%2FmashupEndpointMappingService.ts&version=GBmaster
Group.GetEnvironments = (env as text) as list =>
    let
        credential = Group.AuthCredential(AadPowerAppsServiceResource),
        endpoint = Uri.Combine(BapBaseUri, "/providers/Microsoft.BusinessAppPlatform/environments?api-version=2016-11-01"),
        response = Web.JsonContents(endpoint, Group.AuthHeader(credential)),
        map_global = [
            asia = "asia",
            australia = "australia",
            canada = "canada",
            europe = "europe",
            france = "france",
            germany = "germany",
            india = "india",
            japan = "japan",
            southafrica = "southafrica",
            southamerica = "brazil",
            switzerland = "switzerland",
            unitedarabemirates = "uae",
            unitedkingdom = "uk",
            unitedstates = "us",
            unitedstatesfirstrelease = "usfr"
        ],
        map_tip1 = [
            unitedstates = "us",
            europe = "westeurope"
        ],
        map = if (env = environments[tip1]) then map_tip1 else map_global,
        location = if (env = environments[tip1]) then "tip1" else "prod",
        locations = List.Select(
            List.Transform(response[value], each [
                name = [name],
                endpoint = try Text.Format("https://#{0}.#{1}.powerquery.microsoft.com", {Record.Field(map, Text.Lower([location])), location}) otherwise null,
                isDefault = [properties]?[isDefault]? ?? false
            ]),
            each [endpoint] <> null)
    in
        locations;

// -----------------------------------------------------
// | 2. Workspace
// -----------------------------------------------------
Workspace.GetNavTableForWorkspaces = (options as nullable record) as nullable table =>
    let
        baseUrl = Workspace.CDSAEndpoint(PBIBaseUrl),
        groups = Workspace.GetWorkspaces(baseUrl),
        // get models with certification tags
        modelsWithTags = Workspace.GetCertification(baseUrl),
        withTags = Table.AddColumn(groups, "Tags", each ""),
        withData = Table.AddColumn(withTags, "Data", each Workspace.GetNavTableForWorkspace(baseUrl, [workspaceId], [workspaceType], modelsWithTags, options)),

        // build nav table
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Folder"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Folder"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false),
        nav = Table.ToNavigationTable(withIsLeaf, {"workspaceId"}, "workspaceName", "Data", "ItemKind", "ItemName", "IsLeaf", "Tags")
    in
        if (groups = null) then null else nav;

Workspace.GetNavTableForWorkspace = (baseUrl as text, workspaceId as text, workspaceType as text, modelsWithTags as table, options as nullable record) as nullable table =>
    let
        dataflows = Workspace.GetDataflows(baseUrl, workspaceId, workspaceType),
        dataflowsWithCertification = Table.Join(dataflows, "dataflowId", modelsWithTags, "modelObjectId", JoinKind.LeftOuter),

        withData = Table.AddColumn(dataflowsWithCertification, "Data", each Workspace.GetNavTableForDataflow(baseUrl, workspaceId, workspaceType, [dataflowId], options)),

        // build nav table
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Database"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Database"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false),
        cleanedUpEntries = Table.RemoveColumns(withIsLeaf, {"modelObjectId"}),

        nav = Table.ToNavigationTable(cleanedUpEntries, {"dataflowId"}, "dataflowName", "Data", "ItemKind", "ItemName", "IsLeaf", "Tags")
    in
        if (dataflows = null) then null else nav;

Workspace.GetNavTableForDataflow = (baseUrl as text, workspaceId as text, workspaceType as text, dataflowId as text, options as nullable record) as nullable table =>
    let
        dataflow = Workspace.GetDataflow(baseUrl, workspaceId, workspaceType, dataflowId, options),

        // build nav table
        withTags = Table.AddColumn(dataflow, "Tags", each ""),
        withItemName = Table.AddColumn(withTags, "ItemName", each "Table"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true),
        reordered = Table.ReorderColumns(withIsLeaf, {"entity", "dataCategory", "Data", "Tags", "ItemKind", "ItemName", "IsLeaf"}),

        nav = Table.ToNavigationTable(reordered, {"entity", "version"}, "entityName", "Data", "ItemKind", "ItemName", "IsLeaf", "Tags")
    in
        nav;

Workspace.GetWorkspaces = (baseUrl as text) as table =>
    let
        url = Uri.Combine(baseUrl, "/metadata/v201606/cdsa/workspaces"),
        response = Web.JsonContents(url),
        workspaces = Table.FromRecords(response, {"id", "name", "type"}),
        rename = Table.RenameColumns(workspaces, {{"id", "workspaceId"}, {"name", "workspaceName"}, {"type", "workspaceType"}}),
        withoutUserWorkspace = Table.SelectRows(rename, each [workspaceType] <> "User")
    in
        withoutUserWorkspace;

Workspace.GetDataflows = (baseUrl as text, workspaceId as text, workspaceType as text) as nullable table =>
    let
        url = Uri.Combine(baseUrl, Text.Format("/metadata/v201606/cdsa/dataflows/#{0}", {workspaceId})),
        headers = Workspace.PBIRequestHeaders(workspaceId, workspaceType),
        response = Web.JsonContents(url, [Headers = headers]),
        dataflows = Table.FromRecords(response, {"dataflowId", "name", "description"}),
        rename = Table.RenameColumns(dataflows, {{"name", "dataflowName"}})
    in
        if (response = null) then null else rename;

Workspace.GetCertification = (baseUrl as text) as table =>
    let
        // default return value on errors
        emptyResult = Table.FromRecords({[modelObjectId="00000000-0000-0000-0000-000000000000",Tags=""]}),

        // Returns the list of dataflows with gallery information.
        url = Uri.Combine(baseUrl, "/metadata/v201901/gallery/dataflows"),

        // ignore errors for now until gallery API will be available in all environments
        response = try Web.JsonContents(url) otherwise null,

        toTable = Table.FromList(response, Splitter.SplitByNothing(), {"Column1"}),
        expandResponse = Table.ExpandRecordColumn(toTable, "Column1", {"cdsaModel", "galleryItem"}),
        expandModelsWithId = Table.AddColumn(expandResponse, "modelObjectId", each Text.Lower([cdsaModel][objectId]?)),

        // function to convert certification stage to string used by PQ/desktop
        CertificationStringFromFlag = (flag as nullable number) as text => 
                if flag = null then ""
                else if flag = 1 then "PowerBI.Promoted"
                else if flag = 2 then "PowerBI.Certified"
                else if flag = 3 then "PowerBI.Master"
                else if flag = 4 then "PowerBI.Recommended"
                else "",

        expandModelsWithCertification = Table.AddColumn(expandModelsWithId, "Tags", each if [galleryItem] <> null then (if [galleryItem][status] = 0 then CertificationStringFromFlag([galleryItem][stage]) else "") else ""),

        // remove columns used for computations
        cleanedUpEntries = Table.RemoveColumns(expandModelsWithCertification, {"cdsaModel", "galleryItem"})
    in
        if (response = null or List.IsEmpty(response)) then emptyResult else cleanedUpEntries;

Workspace.GetDataflow = (baseUrl as text, workspaceId as text, workspaceType as text, dataflowId as text, options as nullable record) as nullable table =>
    let
        operationUserAccessToken = DataLake.GetAdlsOperationUserCredentials()[access_token],
        operationUserPuid = if Record.HasFields(Extension.CurrentCredential()[Properties], {"OperationUserToken"})
                            then DataLake.GetUserPuidFromToken(operationUserAccessToken)
                            else null,

        url = Uri.Combine(baseUrl, Text.Format("/metadata/v201606/cdsa/dataflows/#{0}/contentandcache", {dataflowId})),
        headers = Workspace.PBIRequestHeaders(workspaceId, workspaceType, operationUserPuid),
        response = Web.JsonContents(url, [Headers = headers]),
        content = Value.IfNull(response[content]?, []),
        dataflow = Record.SelectFields(content, {"culture", "entities", "relationships"}, MissingField.UseNull),
        renameFields = Record.RenameFields(dataflow, {{"culture", "dataflowCulture"}}),
        transformFields = Record.TransformFields(renameFields, {
            {"dataflowCulture", each if (_ = null) then "" else _}
        }),
        toTable = Table.FromRecords({transformFields}),
        entities = Table.AddColumn(toTable, "Entities", each if ([entities] <> null) then FormatEntitiesForDataflow(baseUrl, workspaceId, workspaceType, dataflowId, [entities], [dataflowCulture], true) else null, type nullable table),
        noNulls = Table.SelectRows(entities, each [Entities] <> null),
        expandEntities = Table.ExpandTableColumn(noNulls, "Entities", {"name", "pbi:dataCategory", "Data", "isStreaming"}, {"entity", "dataCategory", "uncachedData", "isStreaming"}),
        withHotName = Table.AddColumn(expandEntities, "entityName", each [entity] & (if [isStreaming] then Extension.LoadString("StreamingEntityHotDataSuffix") else "")),
        withHotVersion = Table.AddColumn(withHotName, "version", each ""),

        streamingEntities = Table.SelectRows(expandEntities, each [isStreaming]),
        withColdName = Table.AddColumn(streamingEntities, "entityName", each [entity] & Extension.LoadString("StreamingEntityArchivedDataSuffix")),
        withColdVersion = Table.AddColumn(withColdName, "version", each "cold"),

        allEntities = Table.Combine({withHotVersion, withColdVersion}),

        cachedEntities = try Workspace.GetCachedEntities(PBIBaseUrl, workspaceId, dataflowId, response) otherwise null,
        joinedEntities = if cachedEntities = null
            then Table.AddColumn(allEntities, "cachedData", each null)
            else Table.Join(allEntities, "entity", cachedEntities, "cachedEntity", JoinKind.LeftOuter),
        addedItemKind = Table.AddColumn(joinedEntities, "ItemKind", each if [cachedData] <> null and [version] = "" then "View" else "Table"),
        addedData = Table.AddColumn(addedItemKind, "Data", each MakeSqlTable(options, [cachedData], [uncachedData], [isStreaming], [version])),

        // withRelationships = FixExpression(ProcessRelationships(addedData, workspaceId, dataflowId, dataflow[relationships]?)),
        withRelationships = addedData,

        // get rid of any extra columns used for calculation
        selectColumns = Table.SelectColumns(withRelationships, {"entity", "dataCategory", "Data", "ItemKind", "entityName", "version"})
    in
        if (response = null) then null else selectColumns;

MakeSqlTable = (options, cachedData, uncachedData, isStreaming, version) =>
    if isStreaming
        then if version = "" then cachedData else uncachedData
        else if cachedData = null or options[EnableFolding]? = false
            then uncachedData
            else Table.View(cachedData, [
                GetExpression = () => GetAst(cachedData),
                GetRows = () => uncachedData
            ]);

GetAst = (table) =>
    let
        // Workaround a problem with QueryToExpressionVisitor
        ReplaceValuesInRecord = (x) => Record.TransformFields(x, List.Zip({Record.FieldNames(x), List.Repeat({ReplaceOneValue}, Record.FieldCount(x))})),
        ReplaceValuesInList = (x) => List.Transform(x, ReplaceOneValue),
        ReplaceOneValue = (x) =>
            if x is record and (x[Kind]? = "Identifier" or x[Kind]? = "ImplicitIdentifier") and x[Name]? = "PowerPlatform.Dataflows"
                then [Kind="Constant", Value=PowerPlatform.Dataflows]
            else if x is record then ReplaceValuesInRecord(x)
            else if x is list then ReplaceValuesInList(x)
            else x
    in
        ReplaceOneValue(Value.Expression(Value.Optimize(table)));

Workspace.GetCachedEntities = (endpoint, workspaceId, dataflowId, jsonCatalog) =>
    let
        entities = jsonCatalog[content][entities],
        entities2 = List.Transform(entities, each [TABLE_NAME=[name], Columns=Table.FromRecords([attributes])]),
        entities3 = Table.FromRecords(entities2),
        sqlCachedEntities = Table.Join(
            Table.SelectRows(
                Table.SelectColumns(Table.FromRecords(jsonCatalog[cachedEntities]), {"entityName", "nameQualifier", "cacheType", "cacheMoniker"}, MissingField.UseNull),
                each [cacheType] = "Sql"),
            "entityName",
            entities3,
            "TABLE_NAME",
            JoinKind.Inner),
        transformSqlType = (t) => try TypeMap{[T = Text.Lower(t)]}[S] otherwise "error",
        getColumnTypeTransforms = (tableType, columnTypes) =>
            let table = #table(tableType, {})
            in List.Accumulate(
                columnTypes,
                {},
                (list, columnType) => list & List.Transform(
                    Table.ColumnsOfType(table, {columnType, type nullable columnType}),
                    (col) => {col, columnType})),

        // Query the server version on this dataflow so we can do version-appropriate folding.
        // As a side benefit, if the ADO.NET provider isn't present then this will fail and we'll fall back to reading from blob.
        versionCommand = "select @@version + 'EngineEdition:' + cast(SERVERPROPERTY('EngineEdition') as varchar(4)) as Version",
        cacheKey = Text.Combine({endpoint, workspaceId, dataflowId}, "|"),
        computedVersion = DataflowsProvider(endpoint, workspaceId, dataflowId, versionCommand){0}[Version],
        serializedVersion = Extension.Cache()[Metadata][Serialized](cacheKey, () => try Text.ToBinary(computedVersion) otherwise #binary({})),
        serverVersion = if Binary.Length(serializedVersion) > 0 then Text.FromBinary(serializedVersion)
            else error Error.Record("Expression.Error", "Cached dataflow not supported", null), // will be caught in GetDataflow
        
        sqlCatalog = SqlDatabase.View([
            Dialect = "T-SQL",
            GeneratorVersion = 1,
            DataSourceName="Dataflows",
            ServerVersion=serverVersion,
            Server=workspaceId,
            Database=dataflowId,
            GetTables = () => Table.AddColumn(Table.RenameColumns(sqlCachedEntities, {{"nameQualifier", "TABLE_SCHEMA"}}), "TABLE_TYPE", each "View"),
            GetColumns = (schema, table) => Table.TransformColumns(
                Table.AddColumn(
                    Table.RenameColumns(
                        Table.AddIndexColumn(
                            Table.First(Table.SelectRows(sqlCachedEntities, each [TABLE_NAME] = table))[Columns],
                            "ORDINAL_POSITION",
                            0),
                        {{"name", "COLUMN_NAME"}, {"dataType", "DATA_TYPE"}}),
                    "IS_NULLABLE",
                    each true),
                {{"DATA_TYPE", transformSqlType}}),
            GetRows = (tableType, command) => Table.TransformColumnTypes(
                DataflowsProvider(endpoint, workspaceId, dataflowId, command),
                getColumnTypeTransforms(tableType, {type date, type time}))
        ])
    in
        Table.RenameColumns(Table.SelectColumns(sqlCatalog, {"Item", "Data"}), {{"Item", "cachedEntity"}, {"Data", "cachedData"}});

Workspace.GetStorageAccess = (baseUrl as text, workspaceId as text, workspaceType as text, dataflowId as text, location as text, name as text, permissions as text) as record =>
    let
        url = Uri.Combine(baseUrl, Text.Format("/metadata/v201606/cdsa/dataflows/#{0}/storageAccess", {dataflowId})),
        body = [
            TokenLifetimeInMinutes = 60,
            Permissions = permissions,
            EntityName = name,
            PartitionUri = location
        ],
        headers = Workspace.PBIRequestHeaders(workspaceId, workspaceType),
        withContentTypes = headers & [
            #"Content-type" = "application/json",
            #"Accept" = "application/json"
        ],
        response = Web.JsonContents(url, [
            Headers = withContentTypes,
            Content = Json.FromValue(body)
        ]),

        // accessDetails is a list, but we currently only care about the first item.
        // When we add partition support, we will need to identify the which container to access.
        access = List.First(response[accessDetails]),
        //TODO (igcelik 01.13.18) remove "BlobContainerSas" value on sync with BE code and replace by "SAS" in contract
        sas = if access[sas]? <> null then access[sas] else access[blobContainerSas]?,
        useAdlsSas = access[accessType] = "Adls2" and sas <> null,
        accessType = if useAdlsSas then "Adls2Sas" else access[accessType],
        queryString = if (accessType = "BlobContainerSas" or accessType = "BlobSas" or accessType = "Adls2Sas") then sas else ""
    in
        [URL = location, AccessType = accessType, Sas = queryString];

Workspace.CDSAEndpoint = (baseUrl as text) as text =>
    let
        // Cluster avaliability issue may affect the globalservice call resulting is sporadic 500 response returned to the caller
        // It is not possible to change the status code which is returned to 504 as it will be a breaking change
        // therefore all the clients were instructed to retry this call on 500
        retryCountCodes = {500},
        maxRetryCount = 5,
        props = Extension.CurrentApplication(),
        serviceEndpoint = Value.IfNull(props[PBIEndpointUrl]?, baseUrl),
        disco = Uri.Combine(serviceEndpoint, "/powerbi/globalservice/v201606/clusterdetails"),
        response = Web.JsonContents(disco, [], retryCountCodes, maxRetryCount),
        clusterUrl = response[clusterUrl]
    in
        clusterUrl;

Workspace.PBIRequestHeaders = (workspaceId as text, workspaceType as text, optional userId as text) as record =>
    let
        workspaceHeader = if (workspaceType <> "User" and workspaceType <> "Folder") then [ #"X-PowerBI-User-GroupId" = workspaceId ] else [],
        headerWithUserId = if userId <> null then workspaceHeader & [#"X-AS-AuthorizedUserID" = userId] else workspaceHeader
    in
        headerWithUserId;

// -----------------------------------------------------
// | 3. Shared by both Group and Workspace.
// -----------------------------------------------------
FormatEntitiesForDataflow = (
    baseUrl as text,
    workspaceId as text,
    workspaceType as text,
    dataflowId as text,
    entities as list,
    defaultCulture as text,
    isWorkspace as logical,
    optional credential as record,
    optional options as nullable record
) as nullable table =>
    let
        // get the attributes and partitions
        toTable = Table.FromList(entities, Splitter.SplitByNothing(), {"entities"}),
        expandEntity = Table.ExpandRecordColumn(toTable, "entities", {"name", "description", "culture", "pbi:dataCategory", "attributes", "partitions", "pbi:refreshPolicy"},
                                                                     {"name", "description", "culture", "dataCategory", "attributes", "partitions", "isStreaming"}),
        transformed = Table.TransformColumns(expandEntity, {
            {"attributes", TableTypeFromAttributes},
            // if culture is null we inherit from the model
            {"culture", each if (_ = null) then defaultCulture else _},
            {"isStreaming", (x) => x[#"$type"]? = "StreamingRefreshPolicy"}
        }),

        // current design is to remove all entities with errors
        noErrors = Table.RemoveRowsWithErrors(transformed),
        renameAttributes = Table.RenameColumns(noErrors, {{"attributes", "tableType"}}),

        withData =
                Table.AddColumn(renameAttributes, "Data",
                    each if (AllPartitionsDefinedAndHaveLocations([partitions])) then
                            GetEntity(baseUrl, workspaceId, workspaceType, dataflowId, [partitions], [tableType], [name], isWorkspace, [culture], credential, options)
                         else
                            #table([tableType], {}),
                type table),

        cleanup = Table.RemoveColumns(withData, {"partitions"})
    in
        if (Table.IsEmpty(noErrors)) then null else cleanup;

TableTypeFromAttributes = (attributes as list) as type =>
    let
        toTable = Table.FromList(attributes, Splitter.SplitByNothing(), {"Column1"}),
        expandRecord = Table.ExpandRecordColumn(toTable, "Column1", {"name", "description", "pbi:dataCategory", "dataType"},
                                                                    {"name", "description", "dataCategory", "dataType"}),
        rename = Table.RenameColumns(expandRecord, {{"name", "Name"}}),
        // TODO: remove Text.Lower() - values should always be lowercase in the model.json
        setType = Table.AddColumn(rename, "Type", each TypeMap{[T= if(_[dataType]) <> null then Text.Lower(_[dataType]) else "unclassified"]}[M] meta [Documentation.Description = _[description]]),

        // build the table type
        schema = Table.SelectColumns(setType, {"Name", "Type"}),
        toList = List.Transform(schema[Type], (t) => [Type=t, Optional=false]),
        toRecord = Record.FromList(toList, schema[Name]),
        toType = Type.ForRecord(toRecord, false)
    in
        type table (toType);

AllPartitionsDefinedAndHaveLocations = (optional partitions as list) =>
    if (partitions = null or List.IsEmpty(partitions)
        or List.MatchesAll(partitions, each not Record.HasFields(_, "location"))
        or List.MatchesAll(partitions, each Record.Field(_, "location") = null)) then false
        else true;

GetEntity = (
    baseUrl as text,
    workspaceId as text,
    workspaceType as text,
    dataflowId as text,
    partitions as list,
    tableType as type,
    entityName as text,
    isWorkspace as logical,
    optional culture as text,
    optional credential as record,
    optional options as nullable record
) as table =>
    let
        // Try to get and use the entity accessor from the service
        entityFromServer = if not isWorkspace and options[EnableFolding]? <> false
            then try GetEntityFromServer(credential, baseUrl, dataflowId, entityName) otherwise null
            else null,

        // convert the list of partitions to a table
        // TODO: if we want to support partition keys, we would include the relevant columns here,
        // and then filter down to only the relevant partitions.
        asTable = Table.FromList(partitions, Splitter.SplitByNothing()),
        expandPartitions = Table.ExpandRecordColumn(asTable, "Column1", {"location", "fileFormatSettings", "name", "cdm:traits"}),
        partitionsWithExistingLocation = Table.SelectRows(expandPartitions, each [location] <> null),
        fetchPartition = Table.AddColumn(partitionsWithExistingLocation, "data", each GetEntityPartition(baseUrl, workspaceId, workspaceType, dataflowId, [location], tableType, entityName, isWorkspace, [name], [fileFormatSettings], culture, credential, [#"cdm:traits"]), tableType),
        dataPartitions = Table.SelectRows(fetchPartition, each not Table.IsEmpty([data])),
        dataOnly = Table.SelectColumns(dataPartitions, "data"),
        expandEntity = Table.ExpandTableColumn(dataOnly, "data", Type.TableSchema(tableType)[Name]),
        entity = entityFromServer ?? expandEntity
    in
        Table.View(null, [GetType = () => tableType, GetRows = () => entity]);

GetEntityFromServer = (credential, baseUrl, dataflowId, entityName) =>
    let
        url = Uri.Combine(baseUrl, Text.Format("/api/dataflowConnector/dataflow/#{0}/storageAccess/#{1}", {dataflowId, entityName})),
        headers = Group.AuthHeader(credential)[Headers] & [Accept = "application/json"],
        response = Web.JsonContents(url, [Headers = headers]),
        accessor = response[accessor],
        dataSourceSetting = response[dataSourceSetting]
    in
        GetEntityFromAccessor(accessor, dataSourceSetting);

GetEntityFromAccessor = (accessor, dataSourceSetting) => Extension.InvokeWithCredentials(
    (dataSource) => Expression.Evaluate(dataSourceSetting),
    () => WithNativeQueryPermission(accessor));

WithNativeQueryPermission = (accessor) =>
    Extension.InvokeWithPermissions(
        (permission) => permission[PermissionKind] = "NativeQuery",
        () => Expression.Evaluate(accessor, #shared));

GetEntityPartition = (
    baseUrl as text,
    workspaceId as text,
    workspaceType as text,
    dataflowId as text,
    location as text,
    tableType as type,
    entityName as text,
    isWorkspace as logical,
    partitionName as text,
    format as nullable record,
    culture as nullable text,
    credential as nullable record,
    traits as nullable list
) as table =>
    let
        isPartitionFolder = List.Contains(traits ?? {}, "is.partition.folder"),
        contentTable =
            if isPartitionFolder then
                let 
                    partitions = GetQualifiedPartitions(baseUrl, workspaceId, workspaceType, dataflowId, entityName, location),
                    storageAccess = Workspace.GetStorageAccess(baseUrl, workspaceId, workspaceType, dataflowId, "" /* location */, entityName, "Read"),
                    contentsTable = Table.AddColumn(partitions, "content", each GetEntityFile([qualifiedUri], tableType, storageAccess[AccessType], storageAccess[Sas], [columnHeaders = true], culture, traits)),
                    dataPartitions = Table.SelectRows(contentsTable, each not Table.IsEmpty([content])),
                    dataOnly = Table.SelectColumns(dataPartitions, "content"), 
                    contents = Table.ExpandTableColumn(dataOnly, "content", Type.TableSchema(tableType)[Name])
                in 
                    contents
            else 
                let
                    // Get the blob with SAS / adls storage url with storage type and connect
                    storageAccess =
                        if (isWorkspace) then
                            Workspace.GetStorageAccess(baseUrl, workspaceId, workspaceType, dataflowId, location, entityName, "Read")
                        else
                            Group.GetStorageAccess(credential, baseUrl, dataflowId, partitionName, entityName),

                    contents = GetEntityFile(storageAccess[URL], tableType, storageAccess[AccessType], storageAccess[Sas], format, culture, traits)
                in 
                    contents
    in
        contentTable;

//
// format is defined in the DLX spec and contains the CSV document settings.
// expected fields:
// - fileExtension 
// - formatSettings
// ---- columnHeaders (bool)
// ---- delimiter (string)
// ---- quoteStyle (QuoteStyle enum, text values)
//
GetEntityFile = (
    entityUrl as text,
    tableType as type,
    accessType as text,
    sas as text,
    optional format as record,
    optional culture as text,
    optional traits as nullable list
) as table =>
    let
        DefaultFormatSettings = [
            columnHeaders = false,
            delimiter = ",",
            quoteStyle = "QuoteStyle.Csv",
            csvStyle = "CsvStyle.QuoteAlways",
            encoding = 65001 // UTF-8
        ],

        formatSettings =
            if (format <> null) then
                DefaultFormatSettings & format
            else
                DefaultFormatSettings,

        // check if the access type is blob or ADLSgV2
        contents = if (accessType = "BlobContainerSas" or accessType = "BlobSas")
                   then Blob.Contents(entityUrl, Blob.GetBlobOptions(), sas)
                   else DataLake.Contents(entityUrl, accessType, sas),

        // Build the csv arguments
        csvArgs =
            let
                delimiter = formatSettings[delimiter],
                quoteStyle =
                         if (formatSettings[quoteStyle] = "QuoteStyle.None") then QuoteStyle.None
                    else if (formatSettings[quoteStyle] = "QuoteStyle.Csv") then QuoteStyle.Csv
                    else null,
                csvStyle =
                         if (formatSettings[csvStyle] = "CsvStyle.QuoteAfterDelimiter") then CsvStyle.QuoteAfterDelimiter
                    else if (formatSettings[csvStyle] = "CsvStyle.QuoteAlways") then CsvStyle.QuoteAlways
                    else null,
                encoding = formatSettings[encoding],
                codePageId = Encoding.ToCodePageId(encoding)
            in
                [
                    Delimiter = delimiter,
                    //Columns = tableType,   // setting table type here causes the navigator to hang on preview
                    Columns = Record.FieldNames(Type.RecordFields(Type.TableRow(tableType))),
                    Encoding = codePageId,
                    CsvStyle = csvStyle,
                    QuoteStyle = quoteStyle
                ],

        csv = Csv.Document(contents, csvArgs),
        // Since we already have our headers from the attribute metadata, if the DLX indicates that
        // the dataset also has a header row, we'll just skip it (rather than calling Table.PromoteHeaders).
        skipHeaders =
            if (formatSettings[columnHeaders] = true) then
                Table.Skip(csv, 1)
            else
                csv,

        document = if traits is list and List.Contains(traits, "is.partition.format.parquet")
            then Parquet.Document(contents)
            else skipHeaders,

        // This will enforce data types
        withType = Table.ChangeType(document, tableType, culture)
    in
        withType;

GetQualifiedPartitions = (baseUrl as text, workspaceId as text, workspaceType as text, dataflowId as text, entityName as text, location as text) as table =>
    let 
        // Location example: "https://<<account>>.blob.core.windows.net:443/<<container>>/<<entityName>>/<<snapshot>>/"
        locationWithoutSnapshot = Text.BeforeDelimiter(location, "@"), // removing @snapshot format, ?snapshot should be taken care of by Uri.Parts
        uri = Uri.Parts(locationWithoutSnapshot),
        pathParams = Text.Split(uri[Path], "/"),
        pathParamsCount = List.Count(pathParams),
        baseUri = Text.Combine({uri[Scheme], uri[Host]}, "://"), // https://<<account>>.blob.core.windows.net:443
        containerUri = Text.Combine({baseUri, pathParams{1}}, "/"), // https://<<account>>.blob.core.windows.net:443/<<container>>
        entityPrefix = Text.Combine(List.Range(pathParams, 2, pathParamsCount), "/"), // <<entityName>>/<<snapshot>>
        // listing blobs under a directory
        storageAccess = Workspace.GetStorageAccess(baseUrl, workspaceId, workspaceType, dataflowId, "" /* location */, entityName, "List"),
        queryParams = Uri.BuildQueryString([restype = "container", comp = "list", prefix = entityPrefix]),
        convertSas = (sas as text) as record => Uri.Parts("https://temp/?" & Text.Trim(Text.Trim(sas, "?"), "&"))[Query],
        blobTableWithName = GetPages(containerUri & "?" & queryParams, convertSas(storageAccess[Sas])),
        fquTable = Table.AddColumn(blobTableWithName, "qualifiedUri", each Text.Combine({containerUri, [Name]}, "/"))
    in
        Table.SelectColumns(fquTable, "qualifiedUri");

GetPages = (uri as text, sas as record) as table =>
    let
        getPage = (uri as text) => [
            response = Xml.Tables(Web.Contents(uri, [ManualCredentials = true, CredentialQuery = sas])),
            blobs = if Record.HasFields(response{0}?[Blobs]{0}, "Blob") then Table.ToList(Table.SelectColumns(Record.Field(response{0}?[Blobs]{0}, "Blob"), "Name")) else {},
            nextMarker = if not Type.Is(Value.Type(response{0}[NextMarker]), type text) then null else response{0}[NextMarker]
        ],
        blobList = List.Combine(List.Generate(
            () => getPage(uri), 
            each _ <> null,
            each if [nextMarker] = null then null else getPage(Text.Combine({uri, [nextMarker] }, "&marker=")),
            each [blobs]
        )),
        blobTableWithName = Table.FromList(blobList, null, {"Name"})
    in 
        blobTableWithName;

ProcessRelationships = (entities as table, identity as text, dataflowId as text, relationships as nullable list) as table =>
    let
        // format the relationships table
        relationshipTable = FormatRelationships(relationships),

        // set relationship identity for each entity - this value needs to be globally unique.
        withIdentity = Table.AddColumn(entities, "DataWithId",
                           each Table.ReplaceRelationshipIdentity([Data], Text.Format("#{0}/#{1}/#{2}", {identity, dataflowId, [entity]})),
                           type table),

        entitiesWithRelationships =
            Table.AddColumn(withIdentity, "DataWithRelationships", (row) => ApplyRelationships(row, withIdentity, relationshipTable)),

        // rename the [DataWithRelationships] column to [Data]
        replaceDataTable = Table.RenameColumns(Table.RemoveColumns(entitiesWithRelationships, {"Data"}), {{"DataWithRelationships", "Data"}})
    in
        if (relationships = null or List.IsEmpty(relationships)) then
            entities
        else
            replaceDataTable;

FormatRelationships = (relationships as list) as table =>
    let
        emptyRelationshipsTable = #table(type [fromEntity = text, fromAttributes = { text }, toEntity = text, toAttributes = { text }], {}),
        selectedFields = List.Transform(relationships, each Record.SelectFields(_, {"fromAttribute", "toAttribute", "$type"})),
        relationshipsTable = Table.FromRecords(selectedFields),
        expandFromAttribute = Table.ExpandRecordColumn(relationshipsTable, "fromAttribute", {"entityName", "attributeName"}, {"fromEntity", "fromAttributeName"}),
        expandToAttribute = Table.ExpandRecordColumn(expandFromAttribute, "toAttribute", {"entityName", "attributeName"}, {"toEntity", "toAttributeName"}),
        rename = Table.RenameColumns(expandToAttribute,{{"$type", "relationshipType"}}),
        calcFrom = Table.AddColumn(rename, "fromAttributes", each
            if ([relationshipType] = "SingleKeyRelationship") then
                {[fromAttributeName]}
            else null,
            type { text }),
        calcTo = Table.AddColumn(calcFrom, "toAttributes", each
            if ([relationshipType] = "SingleKeyRelationship") then
                {[toAttributeName]}
            else null,
            type { text }),
        finalTable = Table.SelectColumns(calcTo, {"fromEntity", "fromAttributes", "toEntity", "toAttributes"})
    in
        finalTable;

ApplyRelationships = (entity as record, entites as table, relationshipTable as table) as table =>
    let
        // filter down to the relationships for the current entity
        relationships = Table.ToRecords(Table.SelectRows(relationshipTable, each _[fromEntity] = entity[entity])),
        entityDataWithID = entity[DataWithId],
        dataWithKeys = [Data = entityDataWithID, Keys = {}],

        // For every row in the relationship table, add and then remove a nested join column.
            // The result of List.Accumulate() will be a table with all relationships defined.
       DataWithRelationshipsKeys = List.Accumulate(
                relationships,
                dataWithKeys,
                // "state" is our accumulated entity table with relationships
                // "current" is the current relationship record to process
                (state, current) => AddRelationshipMetadata(state, current, entites, relationships)),

        keysList = DataWithRelationshipsKeys[Keys],
        distinctKeys = List.Distinct(keysList),
        DataWithRelationships = DataWithRelationshipsKeys[Data],

        //Check that the table has no primary key
        //The primary key should set to the tables after adding all the relationships metadata
        entityWithKeys = if (List.Count(Table.Keys(DataWithRelationships)) = 0) then
                            Table.AddKey(DataWithRelationships, distinctKeys, true)
                        else
                            DataWithRelationships

    in
        // "relationships" will be empty if there are no relationships defined for this entity
        if (List.IsEmpty(relationships)) then
            entity[DataWithId]
        else
            entityWithKeys;

AddRelationshipMetadata = (fromEntity as record, currentRelationship as record, entities as table, relevantRelationships as list) as record =>
    let
        fromEntityData = fromEntity[Data],
        toEntityRow = entities{[entity=currentRelationship[toEntity]]}?,
        joinedTable = Utility.JoinTables(fromEntityData, toEntityRow[DataWithId], currentRelationship[fromAttributes], currentRelationship[toAttributes]),

        keysList = fromEntity[Keys],
        addFromAttributes = List.InsertRange(keysList, List.Count(keysList), currentRelationship[fromAttributes]),

        calculateRelationships = [Data = joinedTable, Keys = addFromAttributes]
    in
        // Additional check that that the "to" entity and "from / to" attributes actually exists.
        // If it does not, the relationship will be ignored, and we
        // return the original table (state).
        if (toEntityRow <> null and
            List.ContainsAll(Table.ColumnNames(fromEntityData), (currentRelationship[fromAttributes])) and
            List.ContainsAll(Table.ColumnNames(toEntityRow[DataWithId]),(currentRelationship[toAttributes])))
        then calculateRelationships
        else fromEntity;

// -----------------------------------------------------
// | 4. Storage (DataLake, Blob)
// -----------------------------------------------------
DataLake.Contents = (entityUrl as text, accessType, sas) =>
    Extension.InvokeWithCredentials(
        (datasource) =>
            if (accessType = "Adls2Sas")
            then [ AuthenticationKind = "SAS", Token = sas]
            else if (accessType = "Adls2AsUser")
            then DataLake.GetAdlsOperationUserCredentials()
            else DataLake.GetAzureDataLakeStorageCredentials(),
        () => AzureStorage.DataLakeContents(entityUrl));

Blob.Contents = (entityUrl as text, blobOptions, sas) =>
    Extension.InvokeWithCredentials(
        (datasource) => [ AuthenticationKind = "SAS", Token = sas],
        () => AzureStorage.BlobContents(entityUrl, blobOptions));

DataLake.GetAdlsOperationUserCredentials = () =>
    let
        currentCredentials = Extension.CurrentCredential()
    in
        currentCredentials & [access_token = Record.FieldOrDefault(currentCredentials[Properties], "OperationUserToken", DataLake.GetAzureDataLakeStorageCredentials()[access_token])];

DataLake.GetUserPuidFromToken = (token as text) =>
    let
        tokenParts = Text.Split(token, "."),
        base64Payload = tokenParts{1},
        claims = Json.Document(Uri.Base64UrlDecode(base64Payload))
    in
        claims[puid]?;

DataLake.GetAzureDataLakeStorageCredentials = () =>
    let
        currentCredentials = Extension.CurrentCredential(),
        prop = "AccessToken:" & AadAdlsStorageResource
    in
        currentCredentials & [access_token = Record.FieldOrDefault(currentCredentials[Properties], prop, currentCredentials[access_token])];

// Blob storage configuration can be controlled by the host
// - BlockSize: passthrough option for AzureStorage.BlobContents
// - RequestSize: passthrough option for AzureStorage.BlobContents
// - ConcurrentRequests: passthrough option for AzureStorage.BlobContents
Blob.GetBlobOptions = () =>
    let
        props = Extension.CurrentApplication(),
        block =
            if (props[BlockSize]? <> null) then
                [BlockSize = props[BlockSize]]
            else
                [],
        request =
            if (props[RequestSize]? <> null) then
                block & [RequestSize = props[RequestSize]]
            else
                block,
        concurrent =
            if (props[ConcurrentRequests]? <> null) then
                request & [ConcurrentRequests = props[ConcurrentRequests]]
            else
                request
    in
        concurrent;

// -----------------------------------------------------
// | 5. Utility
// -----------------------------------------------------
Utility.JoinTables = (fromEntity as table, toEntity as table, fromAttribute, toAttribute) as table =>
    let
        joinColumn = "tempJoin_" & Text.NewGuid(),
        joinedTable = Table.NestedJoin(
            fromEntity,
            fromAttribute,
            toEntity,
            toAttribute,
            joinColumn,
            JoinKind.LeftOuter),
        removedJoinColumn = Table.RemoveColumns(joinedTable, {joinColumn})
    in
        removedJoinColumn;

Utility.CreateScope = (env as text) as text =>
    let
        appendix = "user_impersonation",
        scopeForStorage = Text.Format("#{1}/#{0}", {appendix, AadAdlsStorageResource}),
        scopeForEnvironments = if env <> environments[ppe] and env <> environments[PpeCloud]
            then Text.Format("#{1}/#{0} #{2}//#{0}", {appendix, AadGroupApiOAuthResource, AadPowerAppsServiceResource})
            else null,
        scopeForWorkspaces = if env <> environments[local]
            then Text.Format("#{1}/#{0}", {appendix, AadWorkspaceApiOAuthResource})
            else null,
        result = Text.Combine({scopeForWorkspaces, scopeForEnvironments, scopeForStorage}, " ")
    in
        result;

Utility.GetUrlWithEnv = (baseUrlList as record, env as text, default as text) as text =>
    Record.FieldOrDefault(baseUrlList, env, default);

Encoding.ToCodePageId = (encoding) =>
    let
        codepageResult = try Number.IsNumber(encoding) otherwise null,
        encodingNameToUpper = Text.Upper(encoding),
        codepageId = Record.FieldOrDefault(CodepageIdEncodingMap, encodingNameToUpper, null)
    in
        if codepageResult <> null then Int32.From(encoding)
        else if codepageId <> null then codepageId
        else error "Unsupported encoding '" & encoding & "' received from settings";

Value.IfNull = (a, b) =>
    if a <> null then a
        else b;

Value.WaitFor = (producer as function, delay as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, null},
            (state) => state{0} <> null and (count = null or state{0} < (count + 1)), //first row is {0, null} and doesn't invoke the producer.
            (state) => if state{1} <> null
                then {null, state{1}}
                else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), delay(state{0}))}, 
            (state) => state{1}),
        result = List.Last(list)
    in
        result;

Number.IsNumber = (value as number) as logical => not Number.IsNaN(value) and value <> Number.PositiveInfinity and value <> Number.NegativeInfinity;

// Replacing back the non url friendly characters which were switched on Encode
Uri.Base64UrlDecode = (s) => Binary.FromText(Text.Replace(Text.Replace(s, "-", "+"), "_", "/") & {"", "", "==", "="}{Number.Mod(Text.Length(s), 4)}, BinaryEncoding.Base64);

Uri.FromParts = (parts) =>
    let
        port = if (parts[Scheme] = "https" and parts[Port] = 443) or (parts[Scheme] = "http" and parts[Port] = 80) then "" else ":" & Text.From(parts[Port]),
        div1 = if Record.FieldCount(parts[Query]) > 0 then "?" else "",
        div2 = if Text.Length(parts[Fragment]) > 0 then "#" else "",
        uri = Text.Combine({parts[Scheme], "://", parts[Host], port, parts[Path], div1, Uri.BuildQueryString(parts[Query]), div2, parts[Fragment]})
    in
        uri;

Web.JsonContents = (url as text, optional options as record, optional retryableErrorCodes as list, optional retryCount as number) =>
    let
        shouldRetry = retryableErrorCodes <> null and not List.IsEmpty(retryableErrorCodes),
        nonEmptyOptions = Value.IfNull(options, []),
        baseUrl = url,
        response = if shouldRetry then Web.ContentsCustomRetry(baseUrl, retryableErrorCodes, options, retryCount)
                                  else Web.Contents(baseUrl, nonEmptyOptions & [ManualStatusHandling = ApiErrorStatusCodes]),
        jsonResponse = Json.Document(response) meta Value.Metadata(response),
        responseStatusCode = Record.FieldOrDefault(Value.Metadata(jsonResponse), "Response.Status", 0)
    in
        if List.Contains(ApiErrorStatusCodes, responseStatusCode) then Web.ErrorResponse(url, jsonResponse) else jsonResponse;

Web.ErrorResponse = (url as text, jsonResponse as record) => 
    let 
        responseStatusCode = Record.FieldOrDefault(Value.Metadata(jsonResponse), "Response.Status", 0),
        requestId = Record.FieldOrDefault(Value.Metadata(jsonResponse)[Headers], "RequestId", ""),

        errorCode = jsonResponse[error][code],
        errorMessage = jsonResponse[error][message]? ?? jsonResponse[error][pbi.error][parameters][ErrorMessage]? ?? errorCode,
        errorDetails = if List.IsEmpty(jsonResponse[error][pbi.error][details]) then errorMessage 
                                           else Text.Combine(jsonResponse[error][pbi.error][details], " "),
        ppdfErrorResponse =
                    error Error.Record(
                        "DataSource.Error",
                        jsonResponse[errorCode]? ?? "Unspecified error",
                        jsonResponse[errorDetails]?),
        pbiErrorResponse = 
                    error Error.Record(
                        errorCode,
                        errorMessage,
                        [
                            Error = errorDetails,
                            #"RequestId" = requestId,
                            #"RequestUrl" = url
                        ]
                    )

    in
        if jsonResponse[error]? = null then ppdfErrorResponse else pbiErrorResponse;

// Convergence: Identical
Web.ContentsCustomRetry = (url as text, retryableErrorCodes as list, optional options as record, optional count as number) =>
    let
        waitForResult = Value.WaitFor(
            (iteration) =>
                let
                    options2 = if options = null then [] else options,
                    options3 = if iteration=0 then options2 else options2 & [IsRetry=true],

                    result = Web.Contents(url, options3 & [ManualStatusHandling = retryableErrorCodes]),

                    // make sure buffered is executed before Value.Metadata to ensure we don't make double request.
                    buffered = Binary.Buffer(result),
                    status = if (buffered = null or Value.Metadata(result)[Response.Status] <> 200)
                        then Value.Metadata(result)[Response.Status]
                        else 200,
                    actualResult = if List.MatchesAny(retryableErrorCodes, each _ = status) then null else buffered
                in
                    actualResult,
            (iteration) => #duration(0, 0, 0, iteration*0.2 ),
            count)
    in
        waitForResult;

PowerPlatformDataflows = [
     Authentication = [
        Aad = [
            AuthorizationUri = AadAuthorizationUri,
            Resource = "",
            Scope = Utility.CreateScope(env),
            DefaultClientApplication = [
                ClientId = "a672d62c-fc7b-4e81-a576-e60dc46e951d",
                ClientSecret = "",
                CallbackUrl = AadRedirectUrl
            ]
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel"),

     // valid DSRs
/*
{"protocol":"powerplatform-dataflows","address":{}}
{"protocol":"powerplatform-dataflows","address":{"workspace":null}}
{"protocol":"powerplatform-dataflows","address":{"workspace":"685d9cf0-e359-48b3-983b-3c4babc37af6"}}
{"protocol":"powerplatform-dataflows","address":{"workspace":"685d9cf0-e359-48b3-983b-3c4babc37af6","dataflow":"12345678-e359-48b3-983b-3c4babc37af5"}}
{"protocol":"powerplatform-dataflows","address":{"workspace":"685d9cf0-e359-48b3-983b-3c4babc37af6","dataflow":"12345678-e359-48b3-983b-3c4babc37af5","entity":"Account"}}
{"protocol":"powerplatform-dataflows","address":{"group":null}}
{"protocol":"powerplatform-dataflows","address":{"group":"685d9cf0-e359-48b3-983b-3c4babc37af6"}}
{"protocol":"powerplatform-dataflows","address":{"group":"685d9cf0-e359-48b3-983b-3c4babc37af6","dataflow":"12345678-e359-48b3-983b-3c4babc37af5"}}
{"protocol":"powerplatform-dataflows","address":{"group":"685d9cf0-e359-48b3-983b-3c4babc37af6","dataflow":"12345678-e359-48b3-983b-3c4babc37af5","entity":"Account"}}
*/
    DSRHandlers = [
        #"powerplatform-dataflows" = [
            GetDSR = (optional options, optional navigation) =>
                let
                    workspace = navigation{0}?[workspaceId]?,
                    group = navigation{0}?[groupId]?,
                    dataflow = navigation{2}?[dataflowId]?,
                    entity = navigation{4}?[entity]?,
                    count = List.Count(navigation),
                    matchWorkspace = List.FirstN({[workspaceId=workspace], "Data", [dataflowId=dataflow], "Data", [entity=entity], "Data"}, count),
                    matchGroup = List.FirstN({[groupId=group], "Data", [dataflowId=dataflow], "Data", [entity=entity], "Data"}, count),
                    isMatchWorkspace = List.FirstN(matchWorkspace, count) = navigation,
                    isMatchGroup = List.FirstN(matchGroup, count) = navigation,
                    match = if isMatchWorkspace then matchWorkspace else matchGroup,
                    isValid = Number.IsEven(count) and (isMatchWorkspace or isMatchGroup),
                    address = if navigation = null then []
                        else if not isValid then ...
                        else Record.RenameFields(Record.Combine(List.RemoveItems(match, {"Data"})), {{"workspaceId", "workspace"}, {"dataflowId", "dataflow"}, {"groupId", "group"}}, MissingField.Ignore)
                in
                    [ protocol = "powerplatform-dataflows", address = address ],
            GetFormula = (dsr, optional options) =>
                let
                    address = ValidateAddressRecord(dsr[address]),
                    isWorkspace = Record.HasFields(address, "workspace"),
                    isGroup = Record.HasFields(address, "group"),
                    workspace = Record.FieldOrDefault(address, "workspace", null),
                    group = Record.FieldOrDefault(address, "group", null),
                    dataflow = Record.FieldOrDefault(address, "dataflow", null),
                    entity = Record.FieldOrDefault(address, "entity", null)
                in
                    if (isWorkspace and isGroup) then ...
                    else if (isWorkspace) then
                        if (workspace <> null) then
                            if (dataflow <> null and entity <> null) then
                                () => PowerPlatform.Dataflows(options){[Id="Workspaces"]}[Data]{[workspaceId=workspace]}[Data]{[dataflowId=dataflow]}[Data]{[entity=entity]}[Data]
                            else if (dataflow <> null) then
                                () => PowerPlatform.Dataflows(options){[Id="Workspaces"]}[Data]{[workspaceId=workspace]}[Data]{[dataflowId=dataflow]}[Data]
                            else
                                () => PowerPlatform.Dataflows(options){[Id="Workspaces"]}[Data]{[workspaceId=workspace]}[Data]
                        else
                            () => PowerPlatform.Dataflows(options){[Id="Workspaces"]}[Data]
                    else if (isGroup) then
                        if (group <> null) then
                            if (dataflow <> null and entity <> null) then
                                () => PowerPlatform.Dataflows(options){[Id="Environments"]}[Data]{[groupId=group]}[Data]{[dataflowId=dataflow]}[Data]{[entity=entity]}[Data]
                            else if (dataflow <> null) then
                                () => PowerPlatform.Dataflows(options){[Id="Environments"]}[Data]{[groupId=group]}[Data]{[dataflowId=dataflow]}[Data]
                            else
                                () => PowerPlatform.Dataflows(options){[Id="Environments"]}[Data]{[groupId=group]}[Data]
                        else
                            () => PowerPlatform.Dataflows(options){[Id="Environments"]}[Data]
                    else
                        () => PowerPlatform.Dataflows(options),

            GetFriendlyName = (dsr) => "Power Platform Dataflows"
        ]
    ]
];

ValidateOptions = (options, validOptionsMap) as record =>
    let
        ValidKeys = Table.Column(validOptionsMap, "Name"),
        InvalidKey = List.First(List.Difference(Record.FieldNames(options), ValidKeys)),
        InvalidKeyText = Text.Format(Extension.LoadString("InvalidOptionsKey"), {InvalidKey, Text.Combine(ValidKeys, ",")}),
        ValidateValue = (name, optionType, default, validate, value) =>
                if (value is null and (Type.IsNullable(optionType) or default <> null))
                    or (Type.Is(Value.Type(value), optionType) and validate(value)) then null
                else Text.Format(Extension.LoadString("InvalidOptionsValue"), {name, value}),
        InvalidValues = List.RemoveNulls(Table.TransformRows(validOptionsMap, 
                each ValidateValue([Name],[Type],[Default],[Validate], Record.FieldOrDefault(options, [Name], [Default])))),
        DefaultOptions = Record.FromTable(Table.RenameColumns(Table.SelectColumns(validOptionsMap,{"Name","Default"}),{"Default","Value"})),
        NullNotAllowedFields = List.RemoveNulls(Table.TransformRows(validOptionsMap,
                each if not Type.IsNullable([Type]) and null = Record.FieldOrDefault(options, [Name], [Default]) then [Name] else null)),
        NormalizedOptions = DefaultOptions & Record.RemoveFields(options, NullNotAllowedFields, MissingField.Ignore),
        Result = if null = options then DefaultOptions
                 else if null <> InvalidKey then
                     error Error.Record("Expression.Error", InvalidKeyText)
                 else if not List.IsEmpty(InvalidValues) then
                     error Error.Record("Expression.Error", List.First(InvalidValues))
                 else NormalizedOptions
    in
        Result;

ValidateOptions2 = (options, optionsType) =>
    let
        available = Type.RecordFields(optionsType),
        found = Record.FieldNames(options),
        unknown = Text.Combine(List.FirstN(found, each not Record.HasFields(available, _)), ","),
        result = if (unknown <> null and unknown <> "") then error "Unknown field: " & unknown else options
    in
        result;

ValidateAddressRecord = (address as record) =>
    let
        validated = ValidateOptions2(address, type [
            group = Guid.Type,
            workspace = Guid.Type,
            dataflow = Guid.Type,
            entity = Text.Type
        ])
    in
        validated;

WorkspaceAccessToken = () =>
    let
        credential = Extension.CurrentCredential()
    in
        // The configuration for this connector in ApiHub doesn't properly return the Power BI access token in the property
        // bag, but it will reliably be the primary access token on the credential. So if the property bag doesn't have the
        // expected value, use the primary token.
        Record.FieldOrDefault(credential[Properties], "AccessToken:" & AadWorkspaceApiOAuthResource, credential[access_token]);

DataflowsProvider = (endpoint, workspaceId, dataflowId, query) =>
    let
        connectionString = [
            WorkspaceId = workspaceId,
            DataflowId = dataflowId,
            PowerBiEndpoint = endpoint
        ],
        commandText = Text.FromBinary(Json.FromValue(connectionString & [Query = query]))
    in
        InvokeDataflowsProvider(connectionString, commandText);

InvokeDataflowsProvider = (connectionString, commandText) =>
    Extension.InvokeWithCredentials(
        (dataSource) => [AuthenticationKind="Anonymous", ConnectionString="AccessToken=" & WorkspaceAccessToken()],
        () =>
            Value.NativeQuery(
                AdoDotNet.DataSource(
                    "Microsoft.PowerBI.Dataflows",
                    connectionString,
                    [CommandTimeout = #duration(1, 0, 0, 0)]),
                commandText));

AllValueEqualsToNull = (equalityComparers) =>
    if (List.IsEmpty(List.Select(equalityComparers, each _ <> Value.Equals))) then null
    else equalityComparers;

Handlers = (fn) => [
    GetExpression = () => fn("GetExpression", (table) => Value.Expression(Value.Optimize(table))),
    GetRows = () => fn("GetRows", (table) => table),
    GetRowCount = () => fn("GetRowCount", (table) => Table.RowCount(table)),
    GetType = () => fn("GetType", (table) => Value.Type(table)),

    OnAddColumns = (constructors) => fn("OnAddColumns", (table) => List.Accumulate(
        constructors,
        table,
        (state, item) => Table.AddColumn(state, item[Name], item[Function], item[Type]))),
    OnCombine = (tables, index) => fn("OnCombine", (table) => Table.Combine(List.ReplaceRange(tables, index, 1, {table}))),
    OnDistinct = (columns) => fn("OnDistinct", (table) => Table.Distinct(table, columns)),
    OnGroup = (keys, aggregates) => fn("OnGroup", (table) => Table.Group(table, keys, List.Transform(aggregates, each {[Name], [Function], [Type]}))),
    OnInvoke = (function, arguments, index) => fn("OnInvoke", (table) => Function.Invoke(function, List.ReplaceRange(arguments, index, 1, {table}))),
    OnJoin = (joinSide, leftTable, rightTable, joinKeys, joinKind) =>
        if (joinSide = JoinSide.Left) then fn("OnJoin", (table) => Table.Join(table, joinKeys[Left], rightTable, joinKeys[Right], joinKind, null, AllValueEqualsToNull(joinKeys[EqualityComparer])))
        else if (joinSide = JoinSide.Right) then fn("OnJoin", (table) => Table.Join(leftTable, joinKeys[Left], table, joinKeys[Right], joinKind, null, AllValueEqualsToNull(joinKeys[EqualityComparer])))
        else error
        [
            Reason = "Expression.Error",
            Message = "Invalid join side",
            Detail = joinSide
        ],
    OnPivot = (pivotValues, attributeColumn, valueColumn, aggregateFunction) => fn("OnPivot", (table) =>
        Table.Pivot(table, pivotValues, attributeColumn, valueColumn, aggregateFunction)),
    OnRenameColumns = (renames) => fn("OnRenameColumns", (table) => Table.RenameColumns(table, List.Transform(renames, each {[OldName], [NewName]}))),
    OnSelectColumns = (columns) => fn("OnSelectColumns", (table) => Table.SelectColumns(table, columns)),
    OnSelectRows = (selector) => fn("OnSelectRows", (table) => Table.SelectRows(table, selector)),
    OnSkip = (count) => fn("OnSkip", (table) => Table.Skip(table, count)),
    OnSort = (order) => fn("OnSort", (table) => Table.Sort(table, List.Transform(order, each {[Name], [Order]}))),
    OnTake = (count) => fn("OnTake", (table) => Table.FirstN(table, count)),
    OnUnpivot = (pivotColumns, attributeColumn, valueColumn) => fn("OnUnpivot", (table) =>
        Table.Unpivot(table, pivotColumns, attributeColumn, valueColumn)),

    OnNativeQuery = (query, optional parameters, optional options) => fn("OnNativeQuery", (table) =>
        Value.NativeQuery(table, query, parameters, options)),
    OnTestConnection = () => fn("OnTestConnection", (table) => DataSource.TestConnection(table))
];

// Data Source UI publishing description
PowerPlatformDataflows.Publish = [
    Name = "PowerPlatformDataflows",
    SupportsDirectQuery = true,
    Category = "Power Platform",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    SourceImage = PowerPlatformDataflows.Icons,
    SourceTypeImage = PowerPlatformDataflows.Icons
];

PowerPlatformDataflows.Icons = [
    Icon16 = { Extension.Contents("PowerPlatformDataflows16.png"), Extension.Contents("PowerPlatformDataflows20.png"), Extension.Contents("PowerPlatformDataflows24.png"), Extension.Contents("PowerPlatformDataflows32.png") },
    Icon32 = { Extension.Contents("PowerPlatformDataflows32.png"), Extension.Contents("PowerPlatformDataflows40.png"), Extension.Contents("PowerPlatformDataflows48.png"), Extension.Contents("PowerPlatformDataflows64.png") }
];

// Extension library functions
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Table.ChangeType = Extension.LoadFunction("Table.ChangeType.pqm");
Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");
Table.NavigationTableView = Extension.LoadFunction("Table.NavigationTableView.pqm");

Extension.LoadString = try #shared[Extension.LoadString] otherwise error "Extensibility module not loaded";
Extension.InvokeWithCredentials = try #shared[Extension.InvokeWithCredentials] otherwise error "Extensibility module not loaded";
Extension.CurrentCredential = try #shared[Extension.CurrentCredential] otherwise error "Extensibility module not loaded";
Extension.CurrentApplication = try #shared[Extension.CurrentApplication] otherwise error "Extensibility module not loaded";
SqlDatabase.View = try #shared[SqlDatabase.View] otherwise error "SqlDatabase module not loaded";
Environment.FeatureSwitch = try #shared[Environment.FeatureSwitch] otherwise "Environment module not loaded";
List.ParallelInvoke = try #shared[List.ParallelInvoke] otherwise "ParallelEvaluation module not loaded";
