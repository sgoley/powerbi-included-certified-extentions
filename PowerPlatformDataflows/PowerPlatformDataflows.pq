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

environments = [prod = "prod", tip1 = "tip1", onebox = "onebox"];
env = environments[prod];

BapBaseUrlEnv = [
    prod = "https://api.bap.microsoft.com",
    tip1 = "https://tip1.api.bap.microsoft.com"
];
PBIBaseUrlEnv = [
    prod = "https://api.powerbi.com",
    tip1 = "https://powerbistagingapi.analysis.windows.net",
    onebox = "https://onebox-redirect.analysis.windows-int.net"
];
AadGroupApiOAuthResourceEnv = [
    prod = "https://powerquery.microsoft.com",
    tip1 = "https://powerquery.microsoft.com",
    onebox = "https://pq-df.microsoft.com"
];
PowerQueryBaseUrlEnv = [
    onebox = "https://onebox.pq-df.microsoft.com:9443"
];

BapBaseUrl = Utility.GetUrlWithEnv(BapBaseUrlEnv, env);
PBIBaseUrl = Utility.GetUrlWithEnv(PBIBaseUrlEnv, env);
AadGroupApiOAuthResource = Utility.GetUrlWithEnv(AadGroupApiOAuthResourceEnv, env);
AadWorkspaceApiOAuthResource = "https://analysis.windows.net/powerbi/api";
AadAuthorizationUri = "https://login.windows.net/common/oauth2/authorize";
AadAdlsStorageResource = "https://storage.azure.com";
AadPowerAppsServiceResource = "https://service.powerapps.com";
AadRedirectUrl = "https://preview.powerbi.com/views/oauthredirect.html";

ApiErrorStatusCodes = { 400, 403, 404, 500, 503 };
Concurrency = 16;

// CDM / CDS-A types.
TypeMap =
    #table(type table [T = Text.Type, M = Type.Type], {
        {"boolean", type nullable Logical.Type},
        {"datetime", type nullable DateTime.Type},
        {"decimal", type nullable Decimal.Type},
        {"double", type nullable Double.Type},
        {"int64", type nullable Int64.Type},
        {"unclassified", type any},
        {"string", type nullable Text.Type},
        {"json", type nullable Text.Type},
        {"guid", type nullable Text.Type},
        {"datetimeoffset", type nullable DateTimeZone.Type}
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

DataflowsView = (optional options as record) as table =>
    let
        invoke = DataflowsImpl(options)
    in
        Table.View(null,
            [
                GetRows = () => invoke,
                GetType = () => Value.Type(invoke)
            ]
        );

DataflowsImpl = (optional options as record) =>
    let
        //TODO: validate options
        originalTable = #table({"Name", "Id", "Data"}, {
            {Extension.LoadString("Environments"), "Environments", Environments()}
        }),
        table = if(env <> environments[onebox])
                then Table.Combine({originalTable, #table({"Name", "Id", "Data"}, {
                        {Extension.LoadString("Workspaces"), "Workspaces", Workspaces()}
                     })})
                else originalTable,

        // build nav table
        withItemKind = Table.AddColumn(table, "ItemKind", each "Folder"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Folder"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false),
        nav = Table.ToNavigationTable(withIsLeaf, {"Id"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        nav;

Environments = () =>
    Extension.InvokeWithCredentials(
         (datasource) =>
            [ AuthenticationKind = "Anonymous" ],
         () =>
            let
                result =  Group.GetNavTableForGroups(env)
            in
                result
    );

Workspaces = () =>
    Extension.InvokeWithCredentials(
         (datasource) =>
            if (datasource[DataSource.Kind] = "AzureBlobs") then [ AuthenticationKind = "Anonymous" ]
            else if datasource[DataSource.Kind] = "AzureDataLakeStorage" then DataLake.GetAzureDataLakeStorageCredentials()
            else Extension.CurrentCredential(),
         () =>
            let
                result = Workspace.GetNavTableForWorkspaces()
            in
                result
    );

// -----------------------------------------------------
// | 1. Group (Environment)
// -----------------------------------------------------
Group.GetNavTableForGroups = (env as text) as nullable table =>
    let
        credential = Group.AuthCredential(AadGroupApiOAuthResource),
        groups = if (env = environments[onebox]) then Group.GetGroups(credential, PowerQueryBaseUrlEnv[onebox]) else Group.GetGroupsAllCluster(credential, env),
        withData = Table.AddColumn(groups, "Data", each Group.GetNavTableForGroup(credential, [baseUrl], [groupId])),

        // build nav table
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Folder"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Folder"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false),
        nav = Table.ToNavigationTable(withIsLeaf, {"groupId"}, "groupName", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        if (groups = null) then null else nav;

Group.GetNavTableForGroup = (credential as record, baseUrl as text, groupId as text) as nullable table =>
    let
        dataflows = Group.GetDataflows(credential, baseUrl, groupId),
        withData = Table.AddColumn(dataflows, "Data", each Group.GetNavTableForDataflow(credential, baseUrl, groupId, [dataflowId])),

        // build nav table
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Database"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Database"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false),
        nav = Table.ToNavigationTable(withIsLeaf, {"dataflowId"}, "dataflowName", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        if (dataflows = null) then null else nav;

Group.GetNavTableForDataflow = (credential as record, baseUrl as text, groupId as text, dataflowId as text) as nullable table =>
    let
        dataflow = Group.GetDataflow(credential, baseUrl, groupId,  dataflowId),

        // build nav table
        withItemKind = Table.AddColumn(dataflow, "ItemKind", each "Table"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true),
        nav = Table.ToNavigationTable(withIsLeaf, {"entity"}, "entity", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        nav;

Group.GetGroupsAllCluster = (credential as record, env as text) as table =>
    let
        endpoints = Group.ClusterEndpoints(env),
        getGroups = List.Transform(endpoints, (endpoint) => () =>
            let
                result = Group.GetGroups(credential, endpoint)
            in
                result),
        batches = List.ParallelInvoke(getGroups, Concurrency),
        combined = Table.ExpandTableColumn(Table.FromColumns({batches}), "Column1", {"groupId", "groupName", "baseUrl"}),
        pruned = Table.SelectRows(combined, each [baseUrl] <> null)
    in
        pruned;

Group.GetGroups = (credential as record, baseUrl as text) as table =>
    let
        url = Uri.Combine(baseUrl, "/api/dataflowConnector/groups"),
        response = Web.JsonContents(url, Group.AuthHeader(credential)),
        groups = Table.FromRecords(response, {"groupId", "name"}),
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
        if (response = null) then null else rename;

Group.GetDataflow = (credential as record, baseUrl as text, groupId as text, dataflowId as text) as nullable table =>
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
        entities = Table.AddColumn(toTable, "Entities", each if ([entities] <> null) then FormatEntitiesForDataflow(baseUrl, "", "", dataflowId, [entities], "", false, credential) else null, type nullable table),
        noNulls = Table.SelectRows(entities, each [Entities] <> null),
        expandEntities = Table.ExpandTableColumn(noNulls, "Entities", {"name", "Data"}, {"entity", "Data"}),

        withRelationships = ProcessRelationships(expandEntities, groupId, dataflowId, dataflow[relationships]?),
        selectColumns = Table.SelectColumns(withRelationships, {"entity", "Data"})
    in
        if (response = null) then null else selectColumns;

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
        queryString = response[sasKey],
        entityUrl = Uri.CombineUrlWithQueryString(uri, queryString)
    in
        [URL = entityUrl, AccessType = "Adls2Sas"];

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
Group.ClusterEndpoints = (env as text) as list =>
    let
        credential = Group.AuthCredential(AadPowerAppsServiceResource),
        endpoint = Uri.Combine(BapBaseUrl, "/providers/Microsoft.BusinessAppPlatform/environments?api-version=2016-11-01"),
        response = Web.JsonContents(endpoint, Group.AuthHeader(credential)),
        locations = List.Distinct(List.Transform(response[value], each Text.Lower(_[location]))),
        map_prod = [
            unitedstates = "us",
            unitedstatesfirstrelease = "usfr",
            europe = "europe",
            asia = "asia",
            australia = "australia",
            japan = "japan",
            canada = "canada",
            india = "india",
            unitedkingdom = "uk",
            southamerica = "brazil",
            france = "france"
        ],
        map_tip1 = [
            unitedstates = "us",
            europe = "westeurope"
        ],
        map = if (env = environments[tip1]) then map_tip1 else map_prod,
        result = List.RemoveNulls(List.Transform(locations, each try Text.Format("https://#{0}.#{1}.powerquery.microsoft.com", {Record.Field(map, _), env}) otherwise null))
    in
        result;

// -----------------------------------------------------
// | 2. Workspace
// -----------------------------------------------------
Workspace.GetNavTableForWorkspaces = () as nullable table =>
    let
        baseUrl = Workspace.CDSAEndpoint(PBIBaseUrl),
        groups = Workspace.GetWorkspaces(baseUrl),
        withData = Table.AddColumn(groups, "Data", each Workspace.GetNavTableForWorkspace(baseUrl, [workspaceId], [workspaceType])),

        // build nav table
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Folder"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Folder"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false),
        nav = Table.ToNavigationTable(withIsLeaf, {"workspaceId"}, "workspaceName", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        if (groups = null) then null else nav;

Workspace.GetNavTableForWorkspace = (baseUrl as text, workspaceId as text, workspaceType as text) as nullable table =>
    let
        dataflows = Workspace.GetDataflows(baseUrl, workspaceId, workspaceType),
        withData = Table.AddColumn(dataflows, "Data", each Workspace.GetNavTableForDataflow(baseUrl, workspaceId, workspaceType, [dataflowId])),

        // build nav table
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Database"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Database"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false),
        nav = Table.ToNavigationTable(withIsLeaf, {"dataflowId"}, "dataflowName", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        if (dataflows = null) then null else nav;

Workspace.GetNavTableForDataflow = (baseUrl as text, workspaceId as text, workspaceType as text, dataflowId as text) as nullable table =>
    let
        dataflow = Workspace.GetDataflow(baseUrl, workspaceId, workspaceType, dataflowId),

        // build nav table
        withItemKind = Table.AddColumn(dataflow, "ItemKind", each "Table"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true),
        nav = Table.ToNavigationTable(withIsLeaf, {"entity"}, "entity", "Data", "ItemKind", "ItemName", "IsLeaf")
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

Workspace.GetDataflow = (baseUrl as text, workspaceId as text, workspaceType as text, dataflowId as text) as nullable table =>
    let
        operationUserAccessToken = DataLake.GetAdlsOperationUserCredentials()[access_token],
        operationUserPuid = if Record.HasFields(Extension.CurrentCredential()[Properties], {"OperationUserToken"})
                            then DataLake.GetUserPuidFromToken(operationUserAccessToken)
                            else null,

        url = Uri.Combine(baseUrl, Text.Format("/metadata/v201606/cdsa/dataflows/#{0}/content", {dataflowId})),
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
        expandEntities = Table.ExpandTableColumn(noNulls, "Entities", {"name", "pbi:dataCategory", "Data"}, {"entity", "dataCategory", "Data"}),

        withRelationships = ProcessRelationships(expandEntities, workspaceId, dataflowId, dataflow[relationships]?),

        // get rid of any extra columns used for calculation
        selectColumns = Table.SelectColumns(withRelationships, {"entity", "dataCategory", "Data"})
    in
        if (response = null) then null else selectColumns;

Workspace.GetStorageAccess = (baseUrl as text, workspaceId as text, workspaceType as text, dataflowId as text, location as text, name as text) as record =>
    let
        url = Uri.Combine(baseUrl, Text.Format("/metadata/v201606/cdsa/dataflows/#{0}/storageAccess", {dataflowId})),
        body = [
            TokenLifetimeInMinutes = 60,
            Permissions = "Read",
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
        queryString = if (accessType = "BlobContainerSas" or accessType = "BlobSas" or accessType = "Adls2Sas") then sas else "",
        entityUrl = Uri.CombineUrlWithQueryString(location, queryString)
    in
        [URL = entityUrl, AccessType = accessType];

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
FormatEntitiesForDataflow = (baseUrl as text, workspaceId as text, workspaceType as text, dataflowId as text, entities as list, defaultCulture as text, isWorkspace as logical, optional credential as record) as nullable table =>
    let
        // get the attributes and partitions
        toTable = Table.FromList(entities, Splitter.SplitByNothing(), {"entities"}),
        expandEntity = Table.ExpandRecordColumn(toTable, "entities", {"name", "description", "culture", "pbi:dataCategory", "attributes", "partitions"},
                                                                     {"name", "description", "culture", "dataCategory", "attributes", "partitions"}),
        transformed = Table.TransformColumns(expandEntity, {
            {"attributes", TableTypeFromAttributes},
            // if culture is null we inherit from the model
            {"culture", each if (_ = null) then defaultCulture else _}
        }),

        // current design is to remove all entities with errors
        noErrors = Table.RemoveRowsWithErrors(transformed),
        renameAttributes = Table.RenameColumns(noErrors, {{"attributes", "tableType"}}),

        withData =
                Table.AddColumn(renameAttributes, "Data",
                    each if (AllPartitionsDefinedAndHaveLocations([partitions])) then
                            GetEntity(baseUrl, workspaceId, workspaceType, dataflowId, [partitions], [tableType], [name], isWorkspace, [culture], credential)
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

GetEntity = (baseUrl as text, workspaceId as text, workspaceType as text, dataflowId as text, partitions as list, tableType as type, entityName as text, isWorkspace as logical, optional culture as text, optional credential as record) as table =>
    let
        // convert the list of partitions to a table
        // TODO: if we want to support partition keys, we would include the relevant columns here,
        // and then filter down to only the relevant partitions.
        asTable = Table.FromList(partitions, Splitter.SplitByNothing()),
        expandPartitions = Table.ExpandRecordColumn(asTable, "Column1", {"location", "fileFormatSettings", "name"}),
        partitionsWithExistingLocation = Table.SelectRows(expandPartitions, each [location] <> null),
        fetchPartition = Table.AddColumn(partitionsWithExistingLocation, "data", each GetEntityPartition(baseUrl, workspaceId, workspaceType, dataflowId, [location], tableType, entityName, isWorkspace, [name], [fileFormatSettings], culture, credential), tableType),
        dataPartitions = Table.SelectRows(fetchPartition, each not Table.IsEmpty([data])),
        dataOnly = Table.SelectColumns(dataPartitions, "data"),
        expandEntity = Table.ExpandTableColumn(dataOnly, "data", Type.TableSchema(tableType)[Name])
    in
        expandEntity;

//
// format is defined in the DLX spec and contains the CSV document settings.
// expected fields:
// - fileExtension 
// - formatSettings
// ---- columnHeaders (bool)
// ---- delimiter (string)
// ---- quoteStyle (QuoteStyle enum, text values)
//
GetEntityPartition = (baseUrl as text, workspaceId as text, workspaceType as text, dataflowId as text, location as text, tableType as type, entityName as text, isWorkspace as logical, optional partitionName as text, optional format as record, optional culture as text, optional credential as record) as table =>
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

        // Get the blob with SAS / adls storage url with storage type and connect
        storageAccess =
            if (isWorkspace) then
                Workspace.GetStorageAccess(baseUrl, workspaceId, workspaceType, dataflowId, location, entityName)
            else
                Group.GetStorageAccess(credential, baseUrl, dataflowId, partitionName, entityName),

        entityUrl = storageAccess[URL],
        accessType = storageAccess[AccessType],

        // check if the access type is blob or ADLSgV2
        contents = if (accessType = "BlobContainerSas" or accessType = "BlobSas")
                   then AzureStorage.BlobContents(entityUrl, Blob.GetBlobOptions()) 
                   else DataLake.Contents(entityUrl, accessType),

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

        // This will enforce data types
        withType = Table.ChangeType(skipHeaders, tableType, culture)
    in
        withType;

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
            List.ContainsAll(Table.ColumnNames(toEntityRow[DataWithId]),(currentRelationship[toAttributes])) and
            not Table.IsEmpty(toEntityRow[DataWithId]))
        then calculateRelationships
        else fromEntity;

// -----------------------------------------------------
// | 4. Storage (DataLake, Blob)
// -----------------------------------------------------
DataLake.Contents = (entityUrl as text, accessType) =>
    Extension.InvokeWithCredentials(
        (datasource) =>
            if (accessType = "Adls2Sas")
            then [ AuthenticationKind = "Anonymous"]
            else if (accessType = "Adls2AsUser")
            then DataLake.GetAdlsOperationUserCredentials()
            else DataLake.GetAzureDataLakeStorageCredentials(),
        () => AzureStorage.DataLakeContents(entityUrl));

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

Utility.GetUrlWithEnv = (baseUrlList as record, env as text) as text =>
    let
        baseUrl = Record.FieldOrDefault(baseUrlList, env, baseUrlList[prod])
    in
        baseUrl;

Utility.CreateScope = (env as text) as text =>
    let
        appendix = "user_impersonation",
        scopeForOnebox = Text.Format("#{1}/#{0} #{2}/#{0}", {appendix, AadGroupApiOAuthResource, AadAdlsStorageResource}),
        result = if (env <> environments[onebox]) then Text.Format("#{2}/#{0} #{3}//#{0} #{1}", {appendix, scopeForOnebox, AadWorkspaceApiOAuthResource, AadPowerAppsServiceResource}) else scopeForOnebox
    in
        result;

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

// Helper function to combine a URL with a query string, accounting for
// the original URL conditionally having its own query string, and various
// formats for the query string. Returns the resulting URL.
Uri.CombineUrlWithQueryString = (url as text, queryString as text) as text =>
    let
        parts = Uri.Parts(url),

        // remove any leading ?, & and whitespace from the queryString
        trim = Text.Trim(Text.Trim(Text.Trim(queryString, "?"), "&")),
        tempUrl = "http://temp/?" & trim,
        qsParts = Uri.Parts(tempUrl),

        // combine query strings
        combinedQuery = Record.Combine({parts[Query], qsParts[Query]}),
        updatedParts = Record.Combine({parts, [ Query = combinedQuery ]})
    in
        Uri.FromParts(updatedParts);

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
        e = jsonResponse[error],
        errorCode = if Value.Type(e) = Record.Type and Record.HasFields(e, {"code"}) then e[code] else e,
        errorDetails = if Value.Type(e) = Record.Type and Record.HasFields(e, {"message"}) then e[message] else url,

        errorResponse =
                    error Error.Record(
                        errorCode,
                        errorDetails,
                        [
                            Error = errorDetails,
                            #"RequestId" = requestId,
                            #"RequestUrl" = url
                        ]
                    )

    in errorResponse;

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
                                () => PowerPlatform.Dataflows(null){[Id="Workspaces"]}[Data]{[workspaceId=workspace]}[Data]{[dataflowId=dataflow]}[Data]{[entity=entity]}[Data]
                            else if (dataflow <> null) then
                                () => PowerPlatform.Dataflows(null){[Id="Workspaces"]}[Data]{[workspaceId=workspace]}[Data]{[dataflowId=dataflow]}[Data]
                            else
                                () => PowerPlatform.Dataflows(null){[Id="Workspaces"]}[Data]{[workspaceId=workspace]}[Data]
                        else
                            () => PowerPlatform.Dataflows(null){[Id="Workspaces"]}[Data]
                    else if (isGroup) then
                        if (group <> null) then
                            if (dataflow <> null and entity <> null) then
                                () => PowerPlatform.Dataflows(null){[Id="Environments"]}[Data]{[groupId=group]}[Data]{[dataflowId=dataflow]}[Data]{[entity=entity]}[Data]
                            else if (dataflow <> null) then
                                () => PowerPlatform.Dataflows(null){[Id="Environments"]}[Data]{[groupId=group]}[Data]{[dataflowId=dataflow]}[Data]
                            else
                                () => PowerPlatform.Dataflows(null){[Id="Environments"]}[Data]{[groupId=group]}[Data]
                        else
                            () => PowerPlatform.Dataflows(null){[Id="Environments"]}[Data]
                    else
                        () => PowerPlatform.Dataflows(null),

            GetFriendlyName = (dsr) => "Power Platform Dataflows"
        ]
    ]
];

ValidateOptions = (options, optionsType) =>
    let
        available = Type.RecordFields(optionsType),
        found = Record.FieldNames(options),
        unknown = Text.Combine(List.FirstN(found, each not Record.HasFields(available, _)), ","),
        result = if (unknown <> null and unknown <> "") then error "Unknown field: " & unknown else options
    in
        result;

ValidateAddressRecord = (address as record) =>
    let
        validated = ValidateOptions(address, type [
            group = Guid.Type,
            workspace = Guid.Type,
            dataflow = Guid.Type,
            entity = Text.Type
        ])
    in
        validated;

// Data Source UI publishing description
PowerPlatformDataflows.Publish = [
    Name = "PowerPlatformDataflows",
    Beta = false,
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
