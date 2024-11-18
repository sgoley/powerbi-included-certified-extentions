[
    Version = "3.0.64",
    Requires = [
        Legacy = "[0.0,)",
        DataSource = "[0.0,)",
        Environment = "[0.0,)",
        Extensibility = "[0.0,)",
        ParallelEvaluation = "[0.0,)",
        SqlDatabase = "[0.0,)",
        Lakehouse = "[0.0,)"
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
    china       = "china",
    gcc         = "gcc",
    gcc_dod     = "gcc_dod",
    gcc_high    = "gcc_high",
    global      = "global",
    local       = "local",
    ppe         = "ppe",
    PpeCloud    = "PpeCloud",
    tip1        = "tip1",
    usnat       = "usnat",
    ussec       = "ussec"
];
env = Environment.FeatureSwitch("Cloud", environments[global]);

// These settings only required by this connector.
// We'll not add environment settings explicitly for the settings used by a single connector.
AadGroupApiOAuthResourceEnv = [
    china       = "https://powerquery.azure.cn",
    gcc         = "https://gov.powerquery.microsoft.us",
    gcc_dod     = "https://mil.powerquery.microsoft.us",
    gcc_high    = "https://high.powerquery.microsoft.us",
    global      = "https://powerquery.microsoft.com",
    local       = "https://pq-df.microsoft.com",
    tip1        = "https://powerquery.microsoft.com",
    usnat       = "https://powerquery.eaglex.ic.gov",
    ussec       = "https://powerquery.microsoft.scloud"
];
AadPowerAppsResourceEnv = [
    china       = "https://service.powerapps.cn",
    gcc         = "https://gov.service.powerapps.us",
    gcc_dod     = "https://service.apps.appsplatform.us",
    gcc_high    = "https://high.service.powerapps.us",
    global      = "https://service.powerapps.com",
    usnat       = "https://service.powerapps.eaglex.ic.gov",
    ussec       = "https://service.powerapps.microsoft.scloud"
];
BapBaseUrlEnv = [
    china       = "https://api.bap.partner.microsoftonline.cn",
    gcc         = "https://gov.api.bap.microsoft.us",
    gcc_dod     = "https://api.bap.appsplatform.us",
    gcc_high    = "https://high.api.bap.microsoft.us",
    global      = "https://api.bap.microsoft.com",
    tip1        = "https://tip1.api.bap.microsoft.com",
    usnat       = "https://api.bap.eaglex.ic.gov",
    ussec       = "https://api.bap.microsoft.scloud"
];

AadGroupApiOAuthResource = Utility.GetUrlWithEnv(AadGroupApiOAuthResourceEnv, env, AadGroupApiOAuthResourceEnv[global]);
AadPowerAppsServiceResource = Utility.GetUrlWithEnv(AadPowerAppsResourceEnv, env, AadPowerAppsResourceEnv[global]);
BapBaseUri = Utility.GetUrlWithEnv(BapBaseUrlEnv, env, BapBaseUrlEnv[global]);

PBIBaseUrl = Environment.FeatureSwitch("PowerBiUri", "https://api.powerbi.com");
AadWorkspaceApiOAuthResource = Environment.FeatureSwitch("PowerBiAadResource", "https://analysis.windows.net/powerbi/api");
AadAuthorizationUri =  Uri.Combine(Environment.FeatureSwitch("AzureActiveDirectoryUri", "https://login.microsoftonline.com"), "/common/oauth2/authorize");
AadAdlsStorageResource = Environment.FeatureSwitch("AzureStorageAadResource", "https://storage.azure.com");
UseNewClusterAPI = Value.ConvertToLogical(Environment.FeatureSwitch("MashupFlight_UseNewClusterAPI", false));

PowerQueryWebRootLocal = "https://onebox.pq-df.microsoft.com:9543";
AadRedirectUrl = "https://preview.powerbi.com/views/oauthredirect.html";
PowerQuerySovCloudEndpoints = [
    china       = "https://powerquery.azure.cn",
    gcc         = "https://gov.powerquery.microsoft.us",
    gcc_dod     = "https://mil.powerquery.microsoft.us",
    gcc_high    = "https://high.powerquery.microsoft.us",
    usnat       = "https://usnat.powerquery.eaglex.ic.gov",
    ussec       = "https://ussec.powerquery.microsoft.scloud"
];

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

ClientRequestIdHeader = "x-ms-client-request-id";
ClientSessionIdHeader = "x-ms-client-session-id";

CommonHeaderNames = {
    ClientRequestIdHeader,
    ClientSessionIdHeader,
    "RequestId",
    "ActivityId"
};

CommonOptions = () =>
    let
        activityId = Diagnostics.ActivityId(),
        requestId = Text.NewGuid(),
        headers = Record.FromList({requestId, activityId, requestId, activityId}, CommonHeaderNames)
    in
        [Headers = headers, ExcludedFromCacheKey = CommonHeaderNames];

[DataSource.Kind="PowerPlatformDataflows", Publish="PowerPlatformDataflows.Publish"]
shared PowerPlatform.Dataflows = Value.ReplaceType(DataflowsView, DataflowsType);

DataflowsType =
    let
        functionType = type function (optional options as record)
            as table meta [
                Documentation.Name = Extension.LoadString("DataSourceLabel"),
                Documentation.Caption = Extension.LoadString("dataflows.caption"),
                Documentation.Description = Extension.LoadString("dataflows.description"),
                Documentation.LongDescription = Extension.LoadString("dataflows.longDescription")
            ]
    in
        functionType;

PpdfOptionsMap = #table(
    {"Name","Type","Default","Validate","Hidden"}, {
    {"EnableFolding", type nullable logical, true, each _ = null or _ = true or _ = false, false},
    // Not public-facing
    {"TenantId", type any, null, each true, true},
    {"DataflowId", type any, null, each true, true},
    {"WorkspaceId", type any, null, each true, true},
    {"TransactionId", type any, null, each true, true},
    {"IsInternalRewrite", type any, null, each true, true}
});

SasTokenCacheHours = 4;

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
        isSovCloud = Record.HasFields(PowerQuerySovCloudEndpoints, env),
        allEnvironments = if isLocal or isSovCloud then null else Group.GetEnvironments(env),
        groups = if isLocal
            then Group.GetGroups(credential, PowerQueryWebRootLocal)
            else
                if isSovCloud
                then
                    Group.GetSovGroups(credential, env)
                else
                    Group.GetGroupsAllCluster(allEnvironments, credential),
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
                result = try Group.GetGroups(credential, endpoint) otherwise #table(null, {})
            in
                result),
        batches = List.ParallelInvoke(getGroups, Concurrency),
        combined = Table.ExpandTableColumn(Table.FromColumns({batches}), "Column1", {"groupId", "groupName", "baseUrl", "errorCode"}),
        pruned = Table.SelectRows(combined, each [baseUrl] <> null)
    in
        pruned;

Group.GetSovGroups = (credential as record, env as text) as table =>
    let
        endpoint = Record.FieldOrDefault(PowerQuerySovCloudEndpoints, env)
    in
        if endpoint is null then #table(null, {}) else Group.GetGroups(credential, endpoint);

Group.GetGroups = (credential as record, baseUrl as text) as table =>
    let
        url = Uri.Combine(baseUrl, "/api/dataflowConnector/groups"),
        response = Group.GetJsonContents(url, credential, [Origin = NonPii("Group/GetGroups")]),
        groups = Table.FromRecords(response, {"groupId", "name", "errorCode"}, MissingField.UseNull),
        rename = Table.RenameColumns(groups, {{"name", "groupName"}}),
        result = Table.AddColumn(rename, "baseUrl", each baseUrl)
    in
        result;

Group.GetDataflows = (credential as record, baseUrl as text, groupId as text) as nullable table =>
    let
        url = Uri.Combine(baseUrl, Text.Format("/api/dataflowConnector/group/#{0}/dataflowsInfo?$filter=permissions eq read and type eq Adls", {groupId})),
        response = Group.GetJsonContents(url, credential, [Origin = NonPii("Group/GetDataflows"), GroupId = NonPii(groupId)], null, null, null, [#"x-ms-api-version" = "2.0"]),
        dataflows = Table.FromRecords(response, {"dataflowId", "name", "description"}, MissingField.UseNull),
        rename = Table.RenameColumns(dataflows, {{"name", "dataflowName"}})
    in
        Table.View(null, [
            GetType = () => type table [dataflowId=text, dataflowName=text, description=nullable text],
            GetRows = () => if response = null then #table(GetType(), {}) else rename
        ]);

Group.GetDataflow = (credential as record, baseUrl as text, groupId as text, dataflowId as text, options as nullable record) as nullable table =>
    let
        url = Uri.Combine(baseUrl, Text.Format("/api/dataflowConnector/dataflow/#{0}", {dataflowId})),
        partialContext = [GroupId = NonPii(groupId), DataflowId = NonPii(dataflowId)],
        response = Group.GetJsonContents(url, credential, [Origin = NonPii("Group/GetDataflow")] & partialContext),
        json = response[model] ?? [],

        dataflow = Record.SelectFields(json, {"culture", "entities", "relationships"}, MissingField.UseNull),
        renameFields = Record.RenameFields(dataflow, {{"culture", "dataflowCulture"}}),
        transformFields = Record.TransformFields(renameFields, {{"dataflowCulture", each _ ?? ""}}),
        toTable = Table.FromRecords({transformFields}),
        enableFolding = options[EnableFolding]? <> false,
        getEntityMashupJson = (entityName) => let
            accessorUrl = Uri.Combine(baseUrl, Text.Format("/api/dataflowConnector/dataflow/#{0}/storageAccess/#{1}", {dataflowId, entityName})),
            context = [Origin = NonPii("Group/GetDataflow/getEntityMashupJson")] & partialContext,
            storageJson = Group.GetJsonContents(accessorUrl, credential, context, null, url, SasTokenCacheHours)
        in
            if enableFolding then storageJson & [accessorSettings = []] else null,
        getEntityPartitionData = (partition, entityName, tableType, culture) => let
            location = partition[location],
            partitionName = partition[name],
            format = partition[fileFormatSettings],
            traits = partition[#"cdm:traits"],
            tenantId = options[TenantId]?,
            workspaceId = "",
            workspaceType = "",
            storageAccess = Group.GetStorageAccess(credential, baseUrl, groupId, dataflowId, partitionName, entityName)
        in
            GetEntityFile(storageAccess[URL], tableType, storageAccess[AccessType], storageAccess[Sas], format, culture, traits),
        entities = Table.AddColumn(toTable, "Entities",
            each if ([entities] <> null)
                then FormatEntitiesForDataflow(
                    "MashupExpressionReadContentOnFailure",
                    [entities],
                    [dataflowCulture],
                    getEntityMashupJson,
                    getEntityPartitionData,
                    options,
                    [GroupId = NonPii(groupId), DataflowId = NonPii(dataflowId)])
                else null,
            type nullable table),
        noNulls = Table.SelectRows(entities, each [Entities] <> null),
        expandEntities = Table.ExpandTableColumn(noNulls, "Entities", {"name", "Data"}, {"entity", "Data"}),

        withRelationships = Group.ProcessRelationships(expandEntities, groupId, dataflowId, dataflow[relationships]?),
        selectColumns = Table.SelectColumns(withRelationships, {"entity", "Data"})
    in
        Table.View(null, [
            GetType = () => type table [entity=text, Data=nullable table],
            GetRows = () => if response = null then #table(GetType(), {}) else selectColumns
        ]);

Group.ProcessRelationships = (entities as table, identity as text, dataflowId as text, relationships as nullable list) as table =>
    let
        // format the relationships table
        relationshipTable = Group.FormatRelationships(relationships),

        // set relationship identity for each entity - this value needs to be globally unique.
        withIdentity = Table.AddColumn(entities, "DataWithId",
                           each Table.ReplaceRelationshipIdentity([Data], Text.Format("#{0}/#{1}/#{2}", {identity, dataflowId, [entity]})),
                           type table),

        entitiesWithRelationships =
            Table.AddColumn(withIdentity, "DataWithRelationships", (row) => Group.ApplyRelationships(row, withIdentity, relationshipTable)),

        // rename the [DataWithRelationships] column to [Data]
        replaceDataTable = Table.RenameColumns(Table.RemoveColumns(entitiesWithRelationships, {"Data"}), {{"DataWithRelationships", "Data"}})
    in
        if (relationships = null or List.IsEmpty(relationships)) then
            entities
        else
            replaceDataTable;

Group.FormatRelationships = (relationships as list) as table =>
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

Group.ApplyRelationships = (entity as record, entites as table, relationshipTable as table) as table =>
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
                (state, current) => Group.AddRelationshipMetadata(state, current, entites, relationships)),

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

Group.AddRelationshipMetadata = (fromEntity as record, currentRelationship as record, entities as table, relevantRelationships as list) as record =>
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

Group.GetStorageAccess = (credential as record, baseUrl as text, groupId as text, dataflowId as text, _partitionName as text, _entityName as text) as record =>
    let
        url = Uri.Combine(baseUrl, Text.Format("/api/dataflowConnector/dataflow/#{0}/storageAccess", {dataflowId})),
        body = [
            partitionName = _partitionName,
            entityName = _entityName
        ],
        cacheKey = _partitionName & "|" & dataflowId & "|" & _entityName,
        context = [Origin = NonPii("Group/GetStorageAccess"), GroupId = NonPii(groupId), DataflowId = NonPii(dataflowId)],
        response = Group.GetJsonContents(url, credential, context, body, cacheKey, SasTokenCacheHours),
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

Group.DefaultErrorHandler = (state) => DefaultErrorHandler("Group", state);

Group.DefaultWebResponseHandlers = [
    302 = Group.DefaultErrorHandler,
    400 = Group.DefaultErrorHandler,
    403 = Group.DefaultErrorHandler,
    404 = Group.DefaultErrorHandler,
    500 = Group.DefaultErrorHandler,
    503 = Group.DefaultErrorHandler
];

Group.GetJsonContents = (url as text, credential as record, context as record, optional body, optional cacheKey as text, optional cacheHours as number, optional additionalHeaders as record) =>
    let
        headers = [
            // TODO Setting authorization explicitly may not be necessary
            // This seems to be added by web.contents
            Authorization = "Bearer " & credential[access_token],
            #"x-ms-host-context-type" = "PpdfConnector"
        ] & (additionalHeaders ?? []),
        result = if cacheKey <> null
            then Web.JsonContentsWithCaching(url, headers, body, Group.DefaultWebResponseHandlers, cacheKey, cacheHours, context)
            else Web.JsonContents(url, headers, body, Group.DefaultWebResponseHandlers, context)
    in
        result;

// Note: The mapping needs to be kept in sync with endpointMappingService.ts in the Maker Portal.
//       Link to the resource file: https://msazure.visualstudio.com/OneAgile/_git/power-platform-ux?path=/packages/powerapps-ui-common/src/shared/pqoMashupEndpointMapping.ts&_a=contents&version=GBmaster
Group.GetEnvironments = (env as text) as list =>
    let
        credential = Group.AuthCredential(AadPowerAppsServiceResource),
        endpoint = Uri.Combine(BapBaseUri, "/providers/Microsoft.BusinessAppPlatform/environments?api-version=2016-11-01"),
        response = Group.GetJsonContents(endpoint, credential, [Origin = NonPii("Group/GetEnvironments")]),
        map_global = [
            asia = "asia",
            australia = "australia",
            canada = "canada",
            europe = "europe",
            france = "france",
            germany = "germany",
            india = "india",
            japan = "japan",
            korea = "korea",
            norway = "norway",
            southafrica = "southafrica",
            singapore = "singapore",
            sweden = "sweden",
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
        baseUrl = Workspace.GetCdsaClusterUrl(PBIBaseUrl, options[TenantId]?),
        isMwcRefresh = options[DataflowId]? <> null
    in
        if isMwcRefresh then Workspace.GetWorkspacesMwcRefresh(baseUrl, options) else Workspace.GetWorkspaces2(baseUrl, options);

Workspace.GetWorkspaces2 = (_baseUrl as text, options as nullable record) =>
    let
        workspaces = Workspace.GetWorkspaces(_baseUrl, options),
        // get models with certification tags
        withTags = Table.AddColumn(workspaces, "Tags", each ""),
        withData = Table.AddColumn(withTags, "Data", each Workspace.GetNavTableForWorkspace(_baseUrl, [workspaceId], [workspaceType], options)),

        // build nav table
        nav = Table.NavigationTableView(
            () => withData,
            {"workspaceId"},
            (_workspaceId) =>
                Workspace.GetNavTableForWorkspace(_baseUrl, _workspaceId, withTags{[workspaceId=_workspaceId]}[workspaceType], options),
            [
                Name = {"workspaceName", each [workspaceName]},
                workspaceType = each "Folder",
                Tags = each [Tags] ?? "",
                Data = each [Data],
                ItemKind = each "Folder",
                ItemName = each "Folder",
                IsLeaf = each false
            ])
        in
            nav;

Workspace.GetNavTableForWorkspace = (_baseUrl as text, workspaceId as text, workspaceType as text, options as nullable record) as nullable table =>
    let
        modelsWithTags = Workspace.GetCertificationForWorkspace(_baseUrl, workspaceId),
        dataflows = Workspace.GetDataflows(_baseUrl, workspaceId, workspaceType, options[TenantId]?),
        dataflowsWithCertification = Table.Join(dataflows, "dataflowId", modelsWithTags, "modelObjectId", JoinKind.LeftOuter),

        withData = Table.AddColumn(dataflowsWithCertification, "Data",
            each Workspace.GetNavTableForDataflow(_baseUrl, workspaceId, workspaceType, [dataflowId], options)),

        // build nav table
        nav = Table.NavigationTableView(
            () => withData,
            {"dataflowId"},
            (_dataflowId) =>
                Workspace.GetNavTableForDataflow(_baseUrl, workspaceId, workspaceType, _dataflowId, options),
            [
                Name = {"dataflowName", each [dataflowName]},
                description = each [description] ?? "",
                Tags = each [Tags] ?? "",
                Data = each [Data],
                ItemKind = each "Database",
                ItemName = each "Database",
                IsLeaf = each false
            ])
    in
        nav;

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

Workspace.GetWorkspaces = (baseUrl as text, options as nullable record) as table =>
    let
        url = Uri.Combine(baseUrl, "/metadata/v201606/cdsa/workspaces"),
        response = Workspace.GetJsonContents(url, Workspace.GetRequestHeaders(null), [Origin = NonPii("Workspace/GetWorkspaces")]),
        workspaces = Table.FromRecords(response, {"id", "name", "type"}),
        rename = Table.RenameColumns(workspaces, {{"id", "workspaceId"}, {"name", "workspaceName"}, {"type", "workspaceType"}}),
        withoutUserWorkspace = Table.SelectRows(rename, each [workspaceType] <> "User")
    in
        withoutUserWorkspace;

Workspace.GetDataflows = (baseUrl as text, workspaceId as text, workspaceType as text, tenantId as nullable text) as nullable table =>
    let
        url = Uri.Combine(baseUrl, Text.Format("/metadata/v201606/cdsa/dataflows/#{0}", {workspaceId})),
        headers = Workspace.GetServiceRequestHeaders(workspaceId, workspaceType, tenantId),
        response = Workspace.GetJsonContents(url, headers, [Origin = NonPii("Workspace/GetDataflows"), WorkspaceId = NonPii(workspaceId)]),
        dataflows = Table.FromRecords(response, {"dataflowId", "name", "description"}),
        rename = Table.RenameColumns(dataflows, {{"name", "dataflowName"}})
    in
        if (response = null) then null else rename;

Workspace.GetWorkspacesMwcRefresh = (baseUrl as text, options as nullable record) =>
    let
        // MWC uses the connector to refresh and will refresh a specific dataflow entities, thus no need to enumerate all workspaces and all dataflows
        dataflowId = options[DataflowId],
        workspaceId = options[WorkspaceId],
        workspaces = Table.FromRecords({[workspaceId = workspaceId, name = "cdsa workload", workspaceType = "Folder"]}),
        result = Table.AddColumn(workspaces, "Data", each Workspace.GetWorkspaceMwcRefresh(baseUrl, workspaceId, [workspaceType], dataflowId, options))
    in
        result;

Workspace.GetWorkspaceMwcRefresh = (baseUrl as text, workspaceId as text, workspaceType as text, dataflowId as text, options as nullable record) =>
    let
        // creating record for the dataflows received from MWC
        d = dataflowId,
        dataflows = Table.FromRecords({[dataflowId = d, dataflowName = "mwcDataflow", dataflowDescription = "mwcDataflow"]}),

        withData = Table.AddColumn(dataflows, "Data", each Workspace.GetNavTableForDataflow(baseUrl, workspaceId, workspaceType, [dataflowId], options), type table),
        withTags = Table.AddColumn(withData, "Tags", each ""),
        withItemKind = Table.AddColumn(withTags, "ItemKind", each "Database"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Database"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false),

        // build navigation table for workspace
        nav = Table.ToNavigationTable(withIsLeaf, {"dataflowId"}, "dataflowName", "Data", "Tags", "ItemKind", "ItemName", "IsLeaf")
    in
        nav;

Workspace.CertificationStringFromFlag = (flag as nullable number) as text =>
    if flag = null then ""
    else if flag = 1 then "PowerBI.Promoted"
    else if flag = 2 then "PowerBI.Certified"
    else if flag = 3 then "PowerBI.Master"
    else if flag = 4 then "PowerBI.Recommended"
    else "";

Workspace.GetCertificationForWorkspace = (baseUrl as text, workspaceId as text) as table =>
    let
        // default return value on errors
        emptyResult = Table.FromRecords({[modelObjectId="00000000-0000-0000-0000-000000000000",Tags=""]}),

        // Returns the list of dataflows with gallery information.
        url = Uri.Combine(baseUrl, "/metadata/v201606/cdsa/endorsement/" & workspaceId),

        // ignore errors for now until gallery API will be available in all environments
        context = [Origin = NonPii("Workspace/GetCertificationForWorkspace")],
        response = try Workspace.GetJsonContents(url, Workspace.GetRequestHeaders(null), context)
            otherwise null,

        toTable = Table.FromList(response, Splitter.SplitByNothing(), {"Column1"}),
        expandResponse = Table.ExpandRecordColumn(toTable, "Column1", {"artifactObjectId", "status", "stage"}),
        expandModelsWithId = Table.AddColumn(expandResponse, "modelObjectId", each Text.Lower([artifactObjectId])),

        expandModelsWithCertification = Table.AddColumn(expandModelsWithId, "Tags",
            each if [status] = 0 then Workspace.CertificationStringFromFlag([stage]) else ""),

        // remove columns used for computations
        cleanedUpEntries = Table.RemoveColumns(expandModelsWithCertification, {"artifactObjectId", "status", "stage"})
    in
        if (response = null or List.IsEmpty(response)) then emptyResult else cleanedUpEntries;

// The contentandcache catalog is for a single dataflow has the following key fields:
// - content/entities: The dataflow entities, their schemas, and their data partition locations.
// - entityAccessorType: can be ReadContent, MashupExpression, MashupExpressionReadContentOnFailure
//     It is implemented here and is received as part of the contentandcache call.

//     https://dev.azure.com/powerbi/Power%20BI/_git/powerbi?path=%2FSql%2FCloudBI%2FAS%2Fsrc%2FPowerBI%2FPowerBIServiceContracts%2FVersion201606%2FCdsa%2FEntityAccessorType.cs&_a=contents&version=GBmaster

//     Note that all PowerPlatform dataflows correspond to MashupExpressionReadContentOnFailure
//     From the connector perspective, the three values are treated as follows:
//     ReadContent: Read from blob store. If cache is available and query can be folded, use the
//       cache instead.
//     MashupExpressionReadContentOnFailure: Backend API will provide a mashup expression that
//       will read data. If that mashup expression fails, fall back to reading from blob storage.
//     MashupExpression: Backend API will provide a mashup expression that will read data. There
//       is no fallback to reading from blob store.
// - cachedEntities: SQL accessors for the entities. May only be present if entityAccessorType is
//     ReadContent.
// - sources: Objects with two elements, name and source. Each name corresponds to an entity name.
//     source is a template with variables marked as <<n>> where n is a numeric index into
//     sharedStrings, below. Substituting the shared strings into the template gives a complete
//     mashup expression for accessing the data source.
// - sharedStrings: An array of strings to substitute into sources. See above.
Workspace.GetDataflow = (baseUrl as text, workspaceId as text, workspaceType as text, dataflowId as text, options as nullable record) as nullable table =>
    let
        tenantId = options[TenantId]?,
        context = [WorkspaceId = NonPii(workspaceId), DataflowId = NonPii(dataflowId)],
        contentCatalog = let
            operationUserAccessToken = DataLake.GetAdlsOperationUserCredentials()[access_token],
            operationUserPuid = if Record.HasFields(Extension.CurrentCredential()[Properties], {"OperationUserToken"})
                then DataLake.GetUserPuidFromToken(operationUserAccessToken)
                else null,
            contentType = if options[TransactionId]? = null then "contentandcache" else "content",
            contentUrl = Uri.Combine(baseUrl, Text.Format("/metadata/v201606/cdsa/dataflows/#{0}/#{1}", {dataflowId, contentType})),
            transactionUrl = if options[TransactionId]? <> null
                then Text.Combine({ contentUrl, "?", Uri.BuildQueryString([transactionId = options[TransactionId]?])})
                else contentUrl,
            headers = Workspace.GetServiceRequestHeaders(workspaceId, workspaceType, tenantId, operationUserPuid),
            originContext = [Origin = NonPii("Workspace/GetDataflow/contentCatalog")] & context
        in
            try Workspace.GetJsonContents(transactionUrl, headers, originContext, null, null, null, null, true)
                catch (e) =>
                    Diagnostics.Trace(TraceLevel.Information,
                        [
                            Name="Workspace/ContentCatalog/Error",
                            Data=[Error=try Text.FromBinary(Json.FromValue(e)) otherwise "Unknown error."],
                            SafeData=context
                        ],
                        []),

        entityAccessorType = contentCatalog[entityAccessorType]? ?? "ReadContent",
        pbiClusterUrl = if entityAccessorType = "MashupExpression" or entityAccessorType = "MashupExpressionReadContentOnFailure"
            then Workspace.GetCdsaClusterUrl(PBIBaseUrl, options[TenantId]?)
            else null,

        dataflowEntities = let
            dataflow = Record.SelectFields(contentCatalog[content]? ?? [], {"culture", "entities", "relationships"}, MissingField.UseNull),
            renameFields = Record.RenameFields(dataflow, {{"culture", "dataflowCulture"}}),
            dataflowEntities = Table.FromRecords({ Record.TransformFields(renameFields, {{"dataflowCulture", each _ ?? ""}}) }),
            getEntityMashupJson = (entityName) => let
                url = Uri.Combine(baseUrl, Text.Format("/metadata/v201606/cdsa/dataflows/#{0}/storageAccess/#{1}", {dataflowId, entityName})),
                headers = Workspace.GetServiceRequestHeaders(workspaceId, workspaceType, tenantId),
                originContext = [Origin = NonPii("Workspace/GetDataflow/dataflowEntities")] & context,
                storageJson = Workspace.GetJsonContents(url, headers, originContext, null, null, url, SasTokenCacheHours),
                accessorSettings = [ PBI_ClusterUrl = pbiClusterUrl ]
            in
                storageJson & [accessorSettings = accessorSettings],
            getEntityPartitionData = (partition, entityName, tableType, culture) => let
                location = partition[location],
                partitionName = partition[name],
                format = partition[fileFormatSettings],
                traits = partition[#"cdm:traits"],
                // is.partition.folder is used only with streaming dataflows in powerbi
                isPartitionFolder = List.Contains(traits ?? {}, "is.partition.folder"),
                partitionFolderContents = let
                    partitions = Workspace.GetQualifiedPartitions(baseUrl, workspaceId, workspaceType, dataflowId, entityName, location, tenantId),
                    storageAccess = Workspace.GetStorageAccess(baseUrl, workspaceId, workspaceType, dataflowId, "" /* location */, entityName, "Read", tenantId),
                    contentsTable = Table.AddColumn(partitions, "content", each GetEntityFile([qualifiedUri], tableType, storageAccess[AccessType], storageAccess[Sas], [columnHeaders = true], culture, traits)),
                    dataPartitions = Table.SelectRows(contentsTable, each not Table.IsEmpty([content])),
                    dataOnly = Table.SelectColumns(dataPartitions, "content"),
                    contents = Table.ExpandTableColumn(dataOnly, "content", Type.TableSchema(tableType)[Name])
                in
                    contents,
                partitionContents = let
                    storageAccess = Workspace.GetStorageAccess(baseUrl, workspaceId, workspaceType, dataflowId, location, entityName, "Read", tenantId)
                in
                    GetEntityFile(storageAccess[URL], tableType, storageAccess[AccessType], storageAccess[Sas], format, culture, traits)
            in
                if isPartitionFolder then partitionFolderContents else partitionContents,
            entities = Table.AddColumn(dataflowEntities, "Entities",
                each if [entities] <> null
                    then FormatEntitiesForDataflow(
                        entityAccessorType,
                        [entities],
                        [dataflowCulture],
                        getEntityMashupJson,
                        getEntityPartitionData,
                        options,
                        [WorkspaceId = NonPii(workspaceId), DataflowId = NonPii(dataflowId)])
                    else null,
                type nullable table),
            validatedEntities = Table.SelectRows(entities, each [Entities] <> null),
            expandEntities = Table.ExpandTableColumn(validatedEntities, "Entities",
                                                     {"name", "pbi:dataCategory", "Data", "isStreaming"},
                                                     {"entity", "dataCategory", "uncachedData", "isStreaming"})
        in
            expandEntities,

        // All entities are updated to indicate streaming. Streaming entities each have two rows: hot with recent
        // data only, and cold with all data.
        dataflowEntitiesWithStreaming = let
            withHotName = Table.AddColumn(dataflowEntities, "entityName",
                                          each [entity] & (if [isStreaming] then Extension.LoadString("StreamingEntityHotDataSuffix") else "")),
            withHotVersion = Table.AddColumn(withHotName, "version", each ""),

            streamingEntities = Table.SelectRows(dataflowEntities, each [isStreaming]),
            withColdName = Table.AddColumn(streamingEntities, "entityName",
                                           each [entity] & Extension.LoadString("StreamingEntityArchivedDataSuffix")),
            withColdVersion = Table.AddColumn(withColdName, "version", each "cold")
        in
            Table.Combine({withHotVersion, withColdVersion}),

        dataflowEntitiesWithCaching = let
            entityCachesPresent = not List.IsEmpty(contentCatalog[cachedEntities]? ?? {}),
            enableFolding = options[EnableFolding]? <> false,
            entityCaches = if entityCachesPresent and enableFolding
                then try Workspace.GetCachedEntitiesFromCatalog(PBIBaseUrl, workspaceId, dataflowId, contentCatalog) otherwise null
                else null,
            expressionsFromCatalog = let
                _entities = try Workspace.GetEntityExpressionFromCatalog(contentCatalog, enableFolding, tenantId, context),
                entities = if _entities[HasError]
                    then Diagnostics.Trace(TraceLevel.Warning,
                        [
                            Name="Workspace/GetEntityExpressionFromCatalog/Error",
                            Data=[Error=try Text.FromBinary(Json.FromValue(_entities[Error])) otherwise "Unknown error."],
                            SafeData=context
                        ],
                        null)
                    else _entities[Value]
            in
                if entityAccessorType = "MashupExpression" and Record.HasFields(contentCatalog, "sources") then entities else null,
            catalogEntityData = expressionsFromCatalog ?? entityCaches,
            entitiesWithCaches = if catalogEntityData <> null
                then Table.Join(dataflowEntitiesWithStreaming, "entity", catalogEntityData, "cachedEntity", JoinKind.LeftOuter)
                else Table.AddColumn(dataflowEntitiesWithStreaming, "cachedData",
                    each if entityAccessorType = "MashupExpression" or entityAccessorType = "MashupExpressionReadContentOnFailure" then [uncachedData] else null),
            addedItemKind = Table.AddColumn(entitiesWithCaches, "ItemKind", each if [cachedData] <> null and [version] = "" then "View" else "Table")
        in
            Table.AddColumn(addedItemKind, "Data", each GetEntityDataColumnValue(options, entityAccessorType, [cachedData], [uncachedData], [isStreaming], [version])),

        dataflowEntitiesFinalTable = Table.SelectColumns(dataflowEntitiesWithCaching, {"entity", "dataCategory", "Data", "ItemKind", "entityName", "version"})
    in
        if (contentCatalog = null) then null else dataflowEntitiesFinalTable;

GetEntityDataColumnValue = (options, entityAccessorType, cachedData, uncachedData, isStreaming, version) =>
    if isStreaming
        then if version = "" then cachedData else uncachedData
    else if entityAccessorType = "MashupExpression" or entityAccessorType = "MashupExpressionReadContentOnFailure"
        then cachedData
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

ExpandTemplate = (template, strings) =>
    let
        parts = Text.Split(template, "<<"),
        substituteString = (state, current) => let
            falseStart = Text.At(current, 0) = "<",
            stringIndexStart = if falseStart then 1 else 0,
            stringIndexEnd = Text.PositionOf(current, ">>"),
            substitute = try if stringIndexEnd <> -1
                then strings{Number.From(Text.Range(current, stringIndexStart, stringIndexEnd - stringIndexStart))}
                else null
                otherwise null
        in
            if substitute <> null
                then (state & (if falseStart then "<" else "") & substitute & Text.Range(current, stringIndexEnd + 2))
                else (state & "<<" & current),
        result = List.Accumulate(List.RemoveFirstN(parts, 1), parts{0}, substituteString)
    in
        result;

Workspace.GetEntityExpressionFromCatalog = (contentCatalog as record, enableFolding as logical, tenantId as nullable text, context as record) =>
    let
        namesAndSources = contentCatalog[sources],
        sharedStrings = contentCatalog[sharedStrings],
        replaceSharedStrings = (template) => ExpandTemplate(template, sharedStrings),
        pbiClusterUrl = Workspace.GetCdsaClusterUrl(PBIBaseUrl, tenantId),
        getNameAndCache = (nameAndSource) => let
            name = nameAndSource[name],
            expressionTemplate = nameAndSource[source][expression],
            credentialsTemplate = nameAndSource[source][credentials],
            sourceExpression = replaceSharedStrings(expressionTemplate),
            sourceCredentials = replaceSharedStrings(credentialsTemplate),
            withFolding = if enableFolding then sourceExpression else ("Table.StopFolding(" & sourceExpression & ")"),
            cachedData = GetEntityFromAccessor(withFolding, sourceCredentials, [ PBI_ClusterUrl = pbiClusterUrl ], context)
        in
            [ cachedEntity = name, cachedData = cachedData ],
        cacheRecords = List.Transform(namesAndSources, getNameAndCache)
    in
        Table.FromRecords(cacheRecords);

Workspace.GetCachedEntitiesFromCatalog = (endpoint, workspaceId, dataflowId, contentCatalog) =>
    let
        entities = Table.FromRecords(List.Transform(contentCatalog[content][entities], each [TABLE_NAME=[name], Columns=Table.FromRecords([attributes])])),
        sqlCachedEntities = Table.Join(
            Table.SelectRows(
                Table.SelectColumns(Table.FromRecords(contentCatalog[cachedEntities]), {"entityName", "nameQualifier", "cacheType", "cacheMoniker"}, MissingField.UseNull),
                each [cacheType] = "Sql"),
            "entityName",
            entities,
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
            Database=workspaceId,
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

Workspace.GetStorageAccess = (baseUrl as text, workspaceId as text, workspaceType as text, dataflowId as text, location as text, name as text, permissions as text, tenantId as nullable text) as record =>
    let
        url = Uri.Combine(baseUrl, Text.Format("/metadata/v201606/cdsa/dataflows/#{0}/storageAccess", {dataflowId})),
        body = [
            TokenLifetimeInMinutes = 60*24,
            Permissions = permissions,
            EntityName = name,
            PartitionUri = location
        ],
        headers = Workspace.GetServiceRequestHeaders(workspaceId, workspaceType, tenantId),
        cacheKey = if location <> "" then (name & "|" & location & "|" & dataflowId) else null,
        context = [Origin = NonPii("Workspace/GetStorageAccess"), WorkspaceId = NonPii(workspaceId), DataflowId = NonPii(dataflowId)],
        response = Workspace.GetJsonContents(url, headers, context, body, null, cacheKey, SasTokenCacheHours),
        // accessDetails is a list, but we currently only care about the first item.
        // When we add partition support, we will need to identify the which container to access.
        access = List.First(response[accessDetails]),
        //TODO (igcelik 01.13.18) remove "BlobContainerSas" value on sync with BE code and replace by "SAS" in contract
        sas = access[sas]? ?? access[blobContainerSas]?,
        useAdlsSas = access[accessType] = "Adls2" and sas <> null,
        accessType = if useAdlsSas then "Adls2Sas" else access[accessType],
        queryString = if (accessType = "BlobContainerSas" or accessType = "BlobSas" or accessType = "Adls2Sas") then sas else ""
    in
        [URL = location, AccessType = accessType, Sas = queryString];

Workspace.GetCdsaClusterUrl = (baseUrl as text, tenantId as nullable text) as text =>
    let
        // Cluster avaliability issue may affect the globalservice call resulting is sporadic 500 response returned to the caller
        // It is not possible to change the status code which is returned to 504 as it will be a breaking change
        // therefore all the clients were instructed to retry this call on 500
        // Power BI APIs return a 403 for token expiry, handling this manually to refresh the token.
        props = (Extension.CurrentCredential()[Properties]? ?? []) & Extension.CurrentApplication(),
        serviceEndpoint = props[PBIEndpointUrl]? ?? baseUrl,
        retryfn = Workspace.RetryHandler(5),
        uriEnd = if UseNewClusterAPI then "/metadata/cluster" else "/powerbi/globalservice/v201606/clusterdetails",
        response = Workspace.GetJsonContents(
            Uri.Combine(serviceEndpoint, uriEnd),
            Workspace.GetRequestHeaders(tenantId),
            [Origin = NonPii("Workspace/GetCdsaClusterUrl")],
            null,
            [500 = retryfn, 403 = retryfn]),
        clusterUrlViaRequest = if UseNewClusterAPI then response[backendUrl] else response[clusterUrl],
        _clusterUrl = props[PBI_ClusterUrl]? ?? clusterUrlViaRequest,
        clusterUrl = Diagnostics.Trace(TraceLevel.Information, [
                Name = "Workspace/GetCdsaClusterUrl",
                Data = [],
                SafeData = [ ServiceEndpoint = serviceEndpoint, PBI_ClusterUrl = props[PBI_ClusterUrl]? ]
            ],
            _clusterUrl)
    in
        clusterUrl;

Workspace.GetQualifiedPartitions = (baseUrl as text, workspaceId as text, workspaceType as text, dataflowId as text, entityName as text, location as text, tenantId as nullable text) as table =>
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
        storageAccess = Workspace.GetStorageAccess(baseUrl, workspaceId, workspaceType, dataflowId, "" /* location */, entityName, "List", tenantId),
        queryParams = Uri.BuildQueryString([restype = "container", comp = "list", prefix = entityPrefix]),
        convertSas = (sas as text) as record => Uri.Parts("https://temp/?" & Text.Trim(Text.Trim(sas, "?"), "&"))[Query],
        blobTableWithName = Workspace.GetPages(containerUri & "?" & queryParams, convertSas(storageAccess[Sas])),
        fquTable = Table.AddColumn(blobTableWithName, "qualifiedUri", each Text.Combine({containerUri, [Name]}, "/"))
    in
        Table.SelectColumns(fquTable, "qualifiedUri");

Workspace.GetPages = (uri as text, sas as record) as table =>
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

Workspace.GetRequestHeaders = (tenantId as nullable text) =>
    let
        tenantIdHeaders = if tenantId <> null then [#"x-ms-tid" = tenantId] else []
    in
        tenantIdHeaders;

Workspace.GetServiceRequestHeaders = (workspaceId as text, workspaceType as text, tenantId as nullable text, optional userId as text) as record =>
    let
        capacityId = Record.FieldOrDefault(Extension.CurrentApplication(), "PBI_CapacityObjectId", null),
        workspaceHeader = if (workspaceType <> "User" and workspaceType <> "Folder") then [ #"X-PowerBI-User-GroupId" = workspaceId ] else [],
        userIdHeader = if userId <> null then [#"X-AS-AuthorizedUserID" = userId] else [],
        capacityIdHeader = if capacityId <> null then [#"x-ms-caller-capacity-id" = capacityId] else []
    in
        Workspace.GetRequestHeaders(tenantId) & workspaceHeader & userIdHeader & capacityIdHeader;

Workspace.RetryHandler = (count, optional delayFunction as function) =>
    RetryHandler(count, Workspace.DefaultErrorHandler, delayFunction);

Workspace.DefaultErrorHandler = (state) => DefaultErrorHandler("Workspace", state);

Workspace.DefaultWebResponseHandlers = [
    302 = Workspace.DefaultErrorHandler,
    400 = Workspace.DefaultErrorHandler,
    403 = AuthHandler(Workspace.DefaultErrorHandler),
    404 = Workspace.DefaultErrorHandler,
    500 = Workspace.DefaultErrorHandler,
    503 = Workspace.DefaultErrorHandler
];

Workspace.GetJsonContents = (
    url as text,
    headers as record,
    context as record,
    optional body as any,
    optional additionalHandlers as record,
    optional cacheKey as text,
    optional cacheHours as number,
    optional disableCaching as logical
) =>
    let
        handlers = Workspace.DefaultWebResponseHandlers & (additionalHandlers ?? []),
        result = if cacheKey <> null and cacheHours <> null
            then Web.JsonContentsWithCaching(url, headers, body, handlers, cacheKey, cacheHours, context)
            else Web.JsonContents(url, headers, body, handlers, context, if disableCaching = true then [Iteration = 1] else null)
    in
        result;

// -----------------------------------------------------
// | 3. Shared by both Group and Workspace.
// -----------------------------------------------------

FormatEntitiesForDataflow = (
    entityAccessorType as text,
    entities as list,
    defaultCulture as text,
    getEntityMashupJson as function,
    getEntityPartitionData as function,
    options as nullable record,
    context as record
) as nullable table =>
    let
        // get the attributes and partitions
        toTable = Table.FromList(entities, Splitter.SplitByNothing(), {"entities"}),
        expandEntity = Table.ExpandRecordColumn(toTable, "entities", {"name", "description", "culture", "pbi:dataCategory", "attributes", "partitions", "pbi:refreshPolicy"},
                                                                     {"name", "description", "culture", "dataCategory", "attributes", "partitions", "isStreaming"}),
        transformed = Table.TransformColumns(expandEntity, {
            {"attributes", TableTypeFromAttributes},
            // if culture is null we inherit from the model
            {"culture", each _ ?? defaultCulture},
            {"isStreaming", (x) => x[#"$type"]? = "StreamingRefreshPolicy"}
        }),

        // current design is to remove all entities with errors
        noErrors = Table.RemoveRowsWithErrors(transformed),
        renameAttributes = Table.RenameColumns(noErrors, {{"attributes", "tableType"}}),

        _enableFolding = options[EnableFolding]? <> false,
        enableFolding = Diagnostics.Trace(TraceLevel.Information,
            [
                Name="FormatEntities/AccessorType",
                Data=[],
                SafeData=[EnableFolding=_enableFolding, EntityAccessorType=entityAccessorType] & context
            ],
            _enableFolding),

        entityData = (row) => [
            entityName = row[name],
            tableType = row[tableType],
            culture = row[culture],

            partitions = row[partitions],
            // convert the list of partitions to a table
            // TODO: if we want to support partition keys, we would include the relevant columns here,
            // and then filter down to only the relevant partitions.
            asTable = Table.FromList(partitions, Splitter.SplitByNothing()),
            expandPartitions = Table.ExpandRecordColumn(asTable, "Column1", {"location", "fileFormatSettings", "name", "cdm:traits"}),
            partitionsWithExistingLocation = Table.SelectRows(expandPartitions, each [location] <> null),
            fetchPartition = Table.AddColumn(
                partitionsWithExistingLocation,
                "data",
                each getEntityPartitionData(_, entityName, tableType, culture), tableType),
            dataPartitions = Table.SelectRows(fetchPartition, each not Table.IsEmpty([data])),
            dataOnly = Table.SelectColumns(dataPartitions, "data"),
            expandEntity = Table.ExpandTableColumn(dataOnly, "data", Type.TableSchema(tableType)[Name]),
            entityFromPartitions = Table.View(null, [GetType = () => tableType, GetRows = () => expandEntity]),

            _entityMashupExpression = try GetEntityMashupExpression(getEntityMashupJson, entityName, enableFolding, context),

            ReadContent = if AllPartitionsDefinedAndHaveLocations(row[partitions])
                then entityFromPartitions
                else #table(row[tableType], {}),

            MashupExpression = if _entityMashupExpression[HasError]
                then error Error.Record(
                    NonPii("DataSource.Error"),
                    NonPii("Failed to get entity mashup expression."),
                    [Error=try Text.FromBinary(Json.FromValue(_entityMashupExpression[Error])) otherwise "Unknown error.", AccessorType=NonPii("MashupExpression")])
                else _entityMashupExpression[Value],

            MashupExpressionReadContentOnFailure = let
                entityMashupExpression = if _entityMashupExpression[HasError]
                    then Diagnostics.Trace(TraceLevel.Information,
                        [
                            Name="FormatEntities/GetExpression",
                            Data=[Error=try Text.FromBinary(Json.FromValue(_entityMashupExpression[Error])) otherwise "Unknown error."],
                            SafeData=[AccessorType="MashupExpressionReadContentOnFailure"] & context
                        ],
                        null)
                    else _entityMashupExpression[Value],
                result = entityMashupExpression ??
                    (if AllPartitionsDefinedAndHaveLocations(row[partitions])
                        then entityFromPartitions
                        else #table(row[tableType], {}))
            in
                result
        ],

        withData = Table.AddColumn(renameAttributes, "Data", each Record.Field(entityData(_), entityAccessorType), type table),
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

GetEntityMashupExpression = (getEntityMashupJson as function, entityName as text, enableFolding as logical, context as record) =>
    let
        response = getEntityMashupJson(entityName),
        accessorFromResponse = response[accessor]? ?? response[Accessor],
        accessor = if enableFolding
            then accessorFromResponse
            else "Table.StopFolding(" & accessorFromResponse & ")",
        dataSourceSetting = response[dataSourceSetting]? ?? response[DataSourceSetting],
        accessorSettings = response[accessorSettings]
    in
        GetEntityFromAccessor(accessor, dataSourceSetting, accessorSettings, context);

GetEntityFromAccessor = (accessor as text, dataSourceSetting as text, accessorSettings as record, context as record) =>
    Extension.InvokeWithCredentials(
        (dataSource) => let
            evaluatedSettings = Expression.Evaluate(dataSourceSetting),
            extraTokenFields = List.Select(Record.FieldNames(evaluatedSettings), each Text.StartsWith(_, "AccessToken:")),
            properties = (evaluatedSettings[Properties]? ?? []) & Record.SelectFields(evaluatedSettings, extraTokenFields),
            withCorrectedProperties = Record.RemoveFields(evaluatedSettings, extraTokenFields) & [Properties = properties],
            withAccessorSettings = List.Accumulate(
                Record.FieldNames(accessorSettings),
                withCorrectedProperties,
                (settings, field) =>
                    Record.SetAtPath(settings, { "Properties", field }, Record.Field(accessorSettings, field)))
        in
            withAccessorSettings,
        () => WithNativeQueryPermission(accessor, context));

// TODO Remove these when DFE engine fixes the accessor expression
DfeFixups = [
    Function.Equals = "",
    Exemplar.GetExemplar = ""
];

WithNativeQueryPermission = (accessor as text, context as record) =>
    Extension.InvokeWithPermissions(
        (permission) => permission[PermissionKind] = "NativeQuery",
        () => try Expression.Evaluate(accessor, #shared & DfeFixups) catch (e) =>
                    Diagnostics.Trace(TraceLevel.Warning,
                        [
                            Name="MashupInvocation/Error",
                            Data=[Error=try Text.FromBinary(Json.FromValue(e)) otherwise "Unknown error."],
                            SafeData=context
                        ],
                        error e));

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

        blobOptions = Blob.GetBlobOptions(),

        // check if the access type is blob or ADLSgV2
        contents = if (accessType = "BlobContainerSas" or accessType = "BlobSas")
                   then Blob.Contents(entityUrl, blobOptions, sas)
                   else DataLake.Contents(entityUrl, accessType, blobOptions, sas),

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

// -----------------------------------------------------
// | 4. Storage (DataLake, Blob)
// -----------------------------------------------------
DataLake.Contents = (entityUrl as text, accessType, blobOptions, sas) =>
    Extension.InvokeWithCredentials(
        (datasource) =>
            if (accessType = "Adls2Sas")
            then [ AuthenticationKind = "SAS", Token = sas]
            else if (accessType = "Adls2AsUser")
            then DataLake.GetAdlsOperationUserCredentials()
            else DataLake.GetAzureDataLakeStorageCredentials(),
        () => AzureStorage.DataLakeContents(entityUrl, blobOptions));

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
        // Note: Trimmed the end slash because the credentials properties are set it up with the trailing shash trimmed at
        // https://powerbi.visualstudio.com/Power%20Query/_git/power-query?path=/private/Product/Mashup/OAuth/TokenCredential.cs&version=GBmaster&line=59&lineEnd=59&lineStartColumn=65&lineEndColumn=72&lineStyle=plain&_a=contents
        prop = "AccessToken:" & Text.TrimEnd(AadAdlsStorageResource, "/")
    in
        currentCredentials & [access_token = Record.FieldOrDefault(currentCredentials[Properties], prop, currentCredentials[access_token])];

// Blob storage configuration can be controlled by the host
// - BlockSize: passthrough option for AzureStorage.BlobContents
// - RequestSize: passthrough option for AzureStorage.BlobContents
// - ConcurrentRequests: passthrough option for AzureStorage.BlobContents
Blob.GetBlobOptions = () =>
    let
        props = Extension.CurrentApplication(),
        fields = {"BlockSize", "RequestSize", "ConcurrentRequests"}
    in
        if props = null then [] else Record.SelectFields(props, fields, MissingField.Ignore);

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
        codepageResult = try Number.IsFiniteNumber(encoding) otherwise null,
        encodingNameToUpper = Text.Upper(encoding),
        codepageId = Record.FieldOrDefault(CodepageIdEncodingMap, encodingNameToUpper, null)
    in
        if codepageResult <> null then Int32.From(encoding)
        else if codepageId <> null then codepageId
        else error "Unsupported encoding '" & encoding & "' received from settings";

// NOTE: Producer is expected to return [status=..., response=....]
Value.WaitFor = (producer as function, delay as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, [response = null, status = 200]},
            (state) => state{0} <> null and (count = null or state{0} < (count + 1)), //first row is {0, [null and status 200]} and doesn't invoke the producer.
            (state) => if state{0} > 0 and state{1}[status] = 200 // check if we want to retry based on status code or invoke the producer on first iteration
                then {null, state{1}}
                else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), delay(state{0}))},
            (state) => state{1}),
        result = List.Last(list)[response]
    in
        result;

Number.IsFiniteNumber = (value as number) as logical =>
    not Number.IsNaN(value) and value <> Number.PositiveInfinity and value <> Number.NegativeInfinity;

Value.ToText = (value, optional depth) =>
    let
        nextDepth = if depth = null then 3 else depth - 1,
        result = if depth = 0 then "..."
            else if value is null then "<null>"
            else if value is function then Record.FieldOrDefault(Value.Metadata(Value.Type(value)), "Documentation.Name", "<function>")
            else if value is table then "#table({" & Text.Combine(Table.ColumnNames(value), ",") & "},{" & Text.Combine(
                List.Transform(Table.ToRows(Table.FirstN(value, 2)), each @Value.ToText(_, nextDepth)), "},#(cr)#(lf){") & "})"
                //& "Row Count (" & Number.ToText(Table.RowCount(value)) & ")"
            else if value is list then "{" & Text.Combine(List.Transform(List.FirstN(value, 10), each @Value.ToText(_, nextDepth)), ",") & "}"
            else if value is record then "[" & Text.Combine(List.Transform(Record.FieldNames(value), each _ & "=" & @Value.ToText(Record.Field(value, _), nextDepth)), ",") & "]"
            else if value is type then List.First(Table.Schema(#table({"type"}, {{value}}))[TypeName], "<type>")
            else if value is action then "action"
            else Text.From(value)
    in
        try result otherwise "<error>";

Value.ConvertToLogical = (a) =>
    a <> null and a <> "" and Logical.From(a);

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

Record.SetAtPath = (r, fields, value) =>
    if fields = {}
        then value
        else let
            curr = if r is record then r else [],
            field0 = fields{0},
            fieldValue = if List.Count(fields) = 1
                then value
                else @Record.SetAtPath(
                    Record.FieldOrDefault(curr, field0, []),
                    List.Skip(fields, 1),
                    value)
        in
            curr & Record.AddField([], field0, fieldValue);

NonPii = (x) => x meta [Is.Pii = false];

// Web handler methods

AuthHandler = (errorHandler as function) =>
    (state) =>
        let
            alreadyRefreshed = state[Refreshed]? = true,
            refreshFailed = not Web.TryRefreshToken(),
            traceMessage = if alreadyRefreshed
                then "Attempting auth refresh after successful refresh"
                else "Auth refresh failed"
        in
            if alreadyRefreshed or refreshFailed
                then  errorHandler(Diagnostics.Trace(TraceLevel.Warning, traceMessage, state))
                else state & [Refreshed = true];

RetryHandler = (count, errorHandler as function, optional delayFunction as function) =>
    let
        delay = delayFunction ?? ((i) => i * 0.2)
    in
        (state) =>
            if state[Iteration] < count
                then Function.InvokeAfter(() => state, #duration(0, 0, 0, delay(state[Iteration])))
                else errorHandler(state);

JsonHandler = (state) => state & [
    Response = Json.Document(state[Response]) meta Value.Metadata(state[Response]),
    Complete = true
];

CompleteHandler = (state) => state & [Complete = true];

// Web functions

DefaultErrorHandler = (platform as text, state as record) =>
    let
        // Note: Error response not expected to be excessively large
        rawResponse = state[Response],
        bufferedResponse = try Binary.Buffer(rawResponse) otherwise rawResponse,
        responseMetadata = Value.Metadata(rawResponse) ?? [],
        status = responseMetadata[Response.Status]?,
        jsonResponseText = try Text.FromBinary(bufferedResponse) otherwise "<encoding error>",
        errorRecord = try
        let
            jsonResponse = Json.Document(bufferedResponse),
            requestId = Record.FieldOrDefault(responseMetadata[Headers], "RequestId", ""),
            errorCode = jsonResponse[error]?[code]?,
            errorMessage = jsonResponse[error]?[message]? ?? jsonResponse[error]?[pbi.error]?[parameters]?[ErrorMessage]? ?? jsonResponseText,
            errorDetails = if List.IsEmpty(jsonResponse[error]?[pbi.error]?[details]? ?? {})
                then errorMessage
                else Text.Combine(jsonResponse[error][pbi.error][details], " ")
        in
            Error.Record(
                NonPii("DataSource.Error"),
                NonPii(Extension.LoadString("DownstreamServiceCallFailure")),
                [
                    Error = errorDetails,
                    ErrorCode = errorCode,
                    #"RequestId" = requestId,
                    ErrorMessage = errorMessage
                ],
                { NonPii(status) }),
        tracedErrorRecord = Diagnostics.Trace(TraceLevel.Error, [
                Name = platform & "/Error",
                Data = if errorRecord[HasError]
                    then [ Error = Text.Format(Extension.LoadString("ErrorParsingJsonInHttpResponse"), { jsonResponseText }) ]
                    else [ Error = Value.ToText(errorRecord[Value]) ],
                SafeData = [ StatusCode = status ]
            ],
            if errorRecord[HasError]
                then Error.Record(
                    NonPii("DataSource.Error"),
                    NonPii(Extension.LoadString("DownstreamServiceCallFailure")),
                    [
                        ErrorMessage = jsonResponseText
                    ],
                    { NonPii(status) })
                else errorRecord[Value])
    in
        error tracedErrorRecord;

Web.BaseWebContentsOptions = (context as record) as record =>
    [ SafeRequestHeaders = {ClientRequestIdHeader, ClientSessionIdHeader}, SafeResponseHeaders = {}, TraceData = context ];

// Caching Design

// Connector has a two caches:
//   * Time based cache, implemented in Web.JsonContentsWithCaching
//   * Web response caching, implmented in Web.Contents.

// Web.JsonContentsWithCaching ultimately calls Web.Contents. Each
// request should follow the following constraints:
//   * Cache responses in at most one cache.
//   * Don't cache certain types of requests, such as those which
//     might hold authentication tokens.

// Web.JsonContentsWithCaching avoids using the cache in Web.Contents
// by passing Iteration=1 in its state. This sets Web.Contents option
// IsRefresh=true which causes the request to be made without using
// a previously cached response. The result of the request may still
// be cached!

// All calls to Web.JsonContents can similarly bypass the cache by
// setting Iteration=1.

Web.JsonContentsWithCaching = (
    url as text,
    headers as record,
    body as any,
    handlers as record,
    cacheKeyPrefix as text,
    cacheHours as number,
    context as record,
    optional startState as nullable record
) as any =>
    let
        now = DateTimeZone.RemoveZone(DateTimeZone.UtcNow()),
        hoursForSuffix = Number.RoundDown(Duration.TotalHours(now - #datetime(2023, 1, 1, 0, 0, 0))),
        cacheKeySuffix = Text.From(cacheHours * Number.IntegerDivide(hoursForSuffix, cacheHours)),
        // Note: cacheKeyPrefix is sufficiently unique so that URL isn't required as part of cacheKey
        cacheKey =  cacheKeyPrefix & cacheKeySuffix,
        // Note: Iteration > 0 forces no further caching on the web request
        jsonContents = Web.JsonContents(url, headers, body, handlers, context, (startState ?? []) & [Iteration = 1]),
        jsonBinary = Json.FromValue(jsonContents),
        serializedJson = Extension.Cache()[Metadata][Serialized](cacheKey, () => try jsonBinary otherwise #binary({})),
        contents = if serializedJson <> #binary({})
            then Json.Document(serializedJson)
            else jsonContents
    in
        contents;

Web.JsonContents = (
    url as text,
    extraHeaders as record,
    body as any,
    handlers as record,
    context as record,
    optional startState as nullable record
) as any =>
    let
        commonOptions = CommonOptions(),
        commonHeaders = commonOptions[Headers],
        bodyHeader = if body <> null then [#"Content-Type" = "application/json;charset=UTF-8"] else [],
        headerOptions = [Headers = commonHeaders & extraHeaders & bodyHeader],
        bodyOptions = if body <> null then [Content = Json.FromValue(body)] else [],
        requestOptions = Web.BaseWebContentsOptions(context) & commonOptions & headerOptions & bodyOptions
    in
        Http.Request(url, requestOptions, handlers & [200 = JsonHandler], (startState ?? []));

Http.Request = (url as text, options as record, handlers as record, optional startState as nullable record) =>
    let
        handledStatuses = List.Buffer(List.Transform(Record.FieldNames(handlers), Number.From)),
        withStatusHandling = options & [ManualStatusHandling = handledStatuses],
        list = List.Generate(
            () => [Iteration = 0, Url = url, Response = null, Complete = false, Return = false] & (startState ?? []),
            (state) => not state[Return],
            (state) => if state[Complete] then state & [Return = true] else
                let
                    response = Web.Contents(url, withStatusHandling & [IsRetry = state[Iteration] > 0]),
                    status = Value.Metadata(response)[Response.Status]? ?? 200,
                    handler = Record.FieldOrDefault(handlers, Text.From(status, "")),
                    partial = state & [Iteration = state[Iteration] + 1, Response = response, Complete = false],
                    nextState = if handler = null then partial & [Complete = true] else partial & handler(partial)
                in
                    nextState),
        result = List.Last(list)[Response]
    in
        result;

Web.TryRefreshToken = () as logical =>
    let
        forceRefreshOfTokens = true
    in
        Extension.CurrentCredential(forceRefreshOfTokens) <> null; // Force refresh of token.

PowerPlatformDataflows = [
    Type = "Custom",
    MakeResourcePath = (optional options) => if (options[IsInternalRewrite]? <> null) then "PowerPlatformDataflowsInternal" else "PowerPlatformDataflows",
    ParseResourcePath = (resource) => { },
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
    ApplicationProperties = [
        // TODO: Consider removing all code related to commented out properties
        // as they have never been active.
        // BlockSize = [PropertyType = Text.Type, IsRequired = false],
        // RequestSize = [PropertyType = Text.Type, IsRequired = false],
        // ConcurrentRequests = [PropertyType = Text.Type, IsRequired = false],
        PBIEndpointUrl = [PropertyType = Text.Type, IsRequired = false],
        PBI_CapacityObjectId = [PropertyType = Text.Type, IsRequired = false],
        PBI_ClusterUrl = [PropertyType = Text.Type, IsRequired = false]
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
                    workspace = navigation{2}?[workspaceId]?,
                    group = navigation{2}?[groupId]?,
                    dataflow = navigation{4}?[dataflowId]?,
                    entity = navigation{6}?[entity]?,
                    count = List.Count(navigation),
                    matchWorkspace = List.FirstN({[Id="Workspaces"], "Data", [workspaceId=workspace], "Data", [dataflowId=dataflow], "Data", [entity=entity], "Data"}, count),
                    matchGroup = List.FirstN({[Id="Environments"], "Data", [groupId=group], "Data", [dataflowId=dataflow], "Data", [entity=entity], "Data"}, count),
                    isMatchWorkspace = List.FirstN(matchWorkspace, count) = navigation,
                    isMatchGroup = List.FirstN(matchGroup, count) = navigation,
                    match = if isMatchWorkspace then matchWorkspace else matchGroup,
                    isValid = Number.IsEven(count) and (isMatchWorkspace or isMatchGroup),
                    address = if navigation = null then []
                        else if not isValid then ...
                        else Record.RenameFields(Record.Combine(List.RemoveItems(List.Skip(match, 1), {"Data"})), {{"workspaceId", "workspace"}, {"dataflowId", "dataflow"}, {"groupId", "group"}}, MissingField.Ignore)
                in
                    if (options[IsInternalRewrite]? <> null) then ... else [ protocol = "powerplatform-dataflows", address = address ],
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
        VisibleKeys = Table.SelectRows(validOptionsMap, each not [Hidden])[Name],
        ValidKeys = Table.Column(validOptionsMap, "Name"),
        InvalidKey = List.First(List.Difference(Record.FieldNames(options), ValidKeys)),
        InvalidKeyText = Text.Format(Extension.LoadString("InvalidOptionsKey"), {InvalidKey, Text.Combine(VisibleKeys, ",")}),
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
Environment.FeatureSwitch = try #shared[Environment.FeatureSwitch] otherwise error "Environment module not loaded";
List.ParallelInvoke = try #shared[List.ParallelInvoke] otherwise error "ParallelEvaluation module not loaded";
Parquet.Document =  try #shared[Parquet.Document] otherwise (binary, optional options) => error Error.Record("DataSource.Error", Extension.LoadString("ParquetModuleNotSupported"));
