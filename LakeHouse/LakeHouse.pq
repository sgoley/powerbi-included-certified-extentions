[
    Version = "1.0.136",
    Requires = [
        Core = "[0.0,)",
        DataSource = "[0.0,)",
        Environment = "[0.0,)",
        Extensibility = "[0.0,)",
        DeltaLake="[0.0,)",
        Web="[0.0,)",
        AzureDataLakeStorage="[0.0,)",
        Sql="[0.0,)",
        Action="[0.0,)"
    ]
]
section Lakehouse;

// -----------------------------------------------------
// | 1. Lakehouse.Contents() Navigation Table
// -----------------------------------------------------
//  |- Lakehouse
//      |- Workspace
//      |- Workspace
//          |- Lakehouse Artifact
//                  |- Tables
//          |- Lakehouse Artifact
//                  |- Tables
//
// -----------------------------------------------------


PBIBaseUrl = Environment.FeatureSwitch("PowerBiUri", "https://api.powerbi.com");
AadWorkspaceApiOAuthResource = Environment.FeatureSwitch("PowerBiAadResource", "https://analysis.windows.net/powerbi/api");
AadAuthorizationUri =  Uri.Combine(Environment.FeatureSwitch("AzureActiveDirectoryUri", "https://login.microsoftonline.com"), "/common/oauth2/authorize");
AadAdlsStorageResource = "https://storage.azure.com";
AadSqlResource = "https://database.windows.net/";
AadRedirectUrl = "https://oauth.powerbi.com/views/oauthredirect.html";

DeltaLake.DefaultOptions = [Compression=Compression.Snappy];

UseDmsTableApi = Value.ConvertToLogical(Environment.FeatureSwitch("MashupFlight_EnableDMSTableApi", true));
ValidateStagingArtifacts = Value.ConvertToLogical(Environment.FeatureSwitch("MashupFlight_ValidateStagingArtifacts", false));
FixedSchemaFix = Value.ConvertToLogical(Environment.FeatureSwitch("MashupFlight_FixedSchemaFix", false));
UseSqlEndPointInTestConnection = Value.ConvertToLogical(Environment.FeatureSwitch("MashupFlight_UseSqlEndPointInLHTestConnection", true));
DisableDmsDelayedBackgroudProcessing = Value.ConvertToLogical(Environment.FeatureSwitch("MashupFlight_DisableDmsDelayedBackgroudProcessing", false));
LogSqlErrorCodesFromDMSResponse = Value.ConvertToLogical(Environment.FeatureSwitch("MashupFlight_LogSqlErrorCodesFromDMSResponse", false));
IgnoreTableNameValidation = Value.ConvertToLogical(Environment.FeatureSwitch("MashupFlight_IgnoreTableNameValidation", false));
UseNewClusterAPI = Value.ConvertToLogical(Environment.FeatureSwitch("MashupFlight_UseNewClusterAPI", false));

//TODO use FailIfPollingExpiresFlag once TableAPI is propertly tested
// TODO revisit the MaxIterationCount and PollingCount once we have more data from telemetry.
// With the polling multiplier of 1.22, with 20 retries we will wait for a max of around 5 mins per batch
MetadataSyncConfig = if UseDmsTableApi then [MaxIterationCount = 55, PollingCount = 20, NothingInProgressIterationCount = 55, PollingDelayMultiplier=1.22]
    else [MaxIterationCount = 1, PollingCount = 55, NothingInProgressIterationCount = 25, PollingDelayMultiplier = 1.1];

// This folder will hold all the version folders which are created in the connector as a part of Replace and Append Data scenarios
TemporaryParentVersionFolder = "_mashup_temporary";
CreatedMarker = ".created";
DeletedMarker = ".deleted";

NonPii = (x) => x meta [Is.Pii = false];
IsNonPii = (x) => Value.Metadata(x)[Is.Pii]? = false;

OneLakeUriFormat = "https://#{0}/v1.0/workspaces/#{1}/artifacts/#{2}/sasuri?expiryTimeInMinutes=#{3}&subFolderPath=#{4}";

[DataSource.Kind="Lakehouse", Publish="Lakehouse.Publish"]
shared Lakehouse.Contents = Value.ReplaceType(LakehouseView, LakehouseType);

LakehouseType =
    let
        functionType = type function (optional options as record)
            as table meta [
                Documentation.Name = Extension.LoadString("DataSourceLabel"),
                Documentation.Caption = Extension.LoadString("lakehouse.caption"),
                Documentation.Description = Extension.LoadString("lakehouse.description"),
                Documentation.LongDescription = Extension.LoadString("lakehouse.longDescription")
            ]
    in
        functionType;

LakehouseView = (optional options as record) as table =>
    let
        invoke = LakehouseImpl(options),
        view = (x) => Table.View(null, Handlers((op, transform) =>
            if List.Contains({"GetRows", "GetType", "GetRowCount", "GetExpression", "OnTestConnection"}, op) then transform(x(invoke))
            else @view((y) => transform(x(y)))))
    in
        view((t) => t);

LakehouseImpl = (optional options as record) => Lakehouses(options);

Lakehouses = (options) =>
     let
        result = GetNavTableForLakehouses(options)
    in
        result;


GetNavTableForLakehouses = (options as nullable record) as nullable table =>
    let
        baseUrl = PBI.WebContents(PBIBaseUrl)
    in
        GetWorkspaces2(baseUrl, options ?? []);

GetWorkspaces2 = (baseUrl as text, options as record) =>
    let
        workspaces = GetWorkspaces(baseUrl, options),
        // build nav table
        navTable = Table.NavigationTableView(
            () => workspaces,
            {"workspaceId"},
            (workspaceId) => GetNavTableForWorkspace(baseUrl, workspaceId, options),
            [
                Name = {"workspaceName", each [workspaceName]},
                ItemKind = each "Folder",
                ItemName = each "Folder",
                IsLeaf = each false
            ],
            [
                OnTestConnection = () => 
                let
                    firstLakehouse = GetFirstLakehouse(workspaces, baseUrl),
                    lakehouseDbId = firstLakehouse[lakehouseDbId]?,
                    workspaceId = firstLakehouse[workspaceId]?,
                    database = GetLakehouseDatabase(baseUrl, lakehouseDbId)
                in
                    if (UseSqlEndPointInTestConnection) then 
                        Sql.TestConnection(database, lakehouseDbId)
                    else true
            ])
    in
        navTable;

GetFirstLakehouse = (allWorkspaces as table, baseUrl as text) as record =>
    let
        allLakehouses = Table.AddColumn(allWorkspaces, "lakehouseDbId", each GetFirstLakehouseDbId([workspaceId], baseUrl)),
        firstLakehouse = Table.First(Table.SelectRows(allLakehouses, each [lakehouseDbId] <> null))
    in
        firstLakehouse;

GetFirstLakehouseDbId = (workspaceId as text, baseUrl as text) as any =>
    let
        maxRetryCount = 5, // Max retry count for 503 error which is transient and should be retried according to end point owner (Mid Tier team)
        url = Uri.Combine(baseUrl, Text.Format("/metadata/workspaces/#{0}/artifacts", {workspaceId})),
        response = Web.JsonContents(url, [Origin = NonPii("GetFirstLakehouseDbId")], [503 = RetryHandler(maxRetryCount)]),
        responseAsRecord = Table.FromList(response, Splitter.SplitByNothing(), {"ArtifactRecord"}),
        artifacts = Table.ExpandRecordColumn(responseAsRecord, "ArtifactRecord", {"extendedProperties", "artifactType"}),
        lakehouseArtifacts = Table.SelectRows(artifacts, each [artifactType] = "Lakehouse"),
        withDatabaseId = Table.AddColumn(lakehouseArtifacts, "databaseId", each try GetDwProperties([extendedProperties])[id]? otherwise null),
        withDatabaseIdOnly = Table.SelectRows(withDatabaseId, each [databaseId] <> null)
    in
        Table.First(withDatabaseIdOnly)[databaseId]?;

LakehouseNavTableType = type table [
    lakehouseId=text,
    lakehouseName=text,
    description=nullable text,
    capacityObjectId=nullable text,
    extendedProperties=any,
    Data=table,
    databaseId=nullable text
];

LakehouseTableDetailType = type table [
    Name = text,
    Id = text,
    Data = table,
    Schema = nullable text,
    ItemKind = text,
    ItemName = text,
    IsLeaf = logical
];

GetNavTableForWorkspace = (baseUrl as text, workspaceId as text, options as record) as nullable table =>
    let
        lakehouses = GetLakehouses(baseUrl, workspaceId, options),
        warehouses = GetWarehouses(baseUrl, workspaceId, options),
        includeWarehouses = options[IncludeWarehouses]? ?? false,
        all = if includeWarehouses then Table.Combine({lakehouses, warehouses}) else lakehouses,
        emptyTable = AddLakehouseTrivia(#table(LakehouseNavTableType, {})),

        navTable = Table.View(null, [
            GetType = () => Value.Type(emptyTable),
            GetRows = () => AddLakehouseTrivia(all),

            OnSelectRows = (selector) =>
                let
                    index = try GetIndex(selector, {"databaseId", "ItemName"}) otherwise ...,
                    isWarehouse = includeWarehouses and index[ItemName] = "Warehouse",
                    default = Table.SelectRows(GetRows(), selector), // TODO: optimize to skip LH
                    triedData = GetWarehouseDatabase(baseUrl, index[databaseId], options),
                    lazyRecord = (recordCtor, keys, baseRecord) =>
                        let record = recordCtor() in List.Accumulate(keys, [], (r, f) => Record.AddField(r, f, () => (Record.FieldOrDefault(baseRecord, f, null) ?? Record.Field(record, f)), true))
                in
                    if isWarehouse then
                        if triedData = null then emptyTable
                        else Table.FromRecords({
                            lazyRecord(
                                () => Table.First(default),
                                Table.ColumnNames(emptyTable),
                                index & [Data = triedData])
                            },
                            Value.Type(emptyTable))
                    else
                        Table.SelectRows(GetRows(), selector),
            OnTestConnection = () =>
                let
                    lakehouseWithDb = Table.SelectRows(lakehouses, each [databaseId] <> null),
                    firstLakehouse = Table.First(lakehouseWithDb)[databaseId]?,
                    database = if (firstLakehouse <> null) then GetLakehouseDatabase(baseUrl, firstLakehouse) else null
                in
                    Sql.TestConnection(database, firstLakehouse)
        ])
    in
        navTable;

AddLakehouseTrivia = (table) =>
    let
        withItemKind = Table.AddColumn(table, "ItemKind", each "Database"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each if [databaseId] = [lakehouseId] then "Warehouse" else "Database"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false),

        nav = Table.ToNavigationTable(withIsLeaf, {"lakehouseId"}, "lakehouseName", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        nav;

GetWorkspaces = (baseUrl as text, options as record) as table =>
    let
        url = Uri.Combine(baseUrl, "/metadata/workspaces"),
        response = Web.JsonContents(url, [Origin = NonPii("GetWorkspaces")]),
        workspaces = Table.FromRecords(response[folders], {"objectId", "displayName", "capacityObjectId"}, MissingField.UseNull),
        justPremiumWorkspaces = Table.SelectRows(workspaces, each [capacityObjectId] <> null),
        removedCapacityObjectColumns = Table.RemoveColumns(justPremiumWorkspaces,"capacityObjectId"),
        rename = Table.RenameColumns(removedCapacityObjectColumns, {{"objectId", "workspaceId"}, {"displayName", "workspaceName"}})
    in
        rename;

GetLakehouses = (baseUrl as text, workspaceId as text, options as record) as nullable table =>
    let
        maxRetryCount = 5, // Max retry count for 503 error which is transient and should be retried according to end point owner (Mid Tier team)
        url = Uri.Combine(baseUrl, Text.Format("/metadata/workspaces/#{0}/artifacts", {workspaceId})),
        response = Web.JsonContents(url, [Origin = NonPii("GetLakehouses")], [503 = RetryHandler(maxRetryCount)]),
        responseAsRecord = Table.FromList(response, Splitter.SplitByNothing(), {"ArtifactRecord"}),
        artifacts = Table.ExpandRecordColumn(responseAsRecord, "ArtifactRecord", {"objectId", "displayName", "description", "capacityObjectId", "extendedProperties", "artifactType", "createdDate"}, {"objectId", "displayName", "description", "capacityObjectId", "extendedProperties", "artifactType", "createdDate"}),
        lakehouseArtifacts = Table.SelectRows(artifacts, each [artifactType] = "Lakehouse"),
        lakehouseArtifactsWithData = Table.AddColumn(lakehouseArtifacts, "Data", each GenerateLakeHouseTablesView(baseUrl, workspaceId, [objectId], [extendedProperties], options), type table),
        rename = Table.RenameColumns(lakehouseArtifactsWithData, {{"objectId", "lakehouseId"}, {"displayName", "lakehouseName"}}),
        removedColumns = Table.RemoveColumns(rename, {"artifactType","createdDate"}),
        withDatabaseId = Table.AddColumn(removedColumns, "databaseId", each try GetDwProperties([extendedProperties])[id]? otherwise null)
    in
        if (response = null) then #table(LakehouseNavTableType, {}) else withDatabaseId;

GetWarehouses = (baseUrl as text, workspaceId as text, options as record) as table =>
    let
        url = Uri.Combine(baseUrl, Text.Format("/v1.0/myorg/groups/#{0}/datawarehouses", {workspaceId})),
        response = Web.JsonContents(url, [Origin = NonPii("GetWarehouses")], [401 = null]), // 401 is returned when trying to access datawarehouse in "My Workspace"
        responseStatusCode = Record.FieldOrDefault(Value.Metadata(response), "Response.Status", 0),
        finalResponse = if responseStatusCode = 401
            then Web.JsonContents(Uri.Combine(baseUrl, "/v1.0/myorg/datawarehouses"), [Origin = NonPii("GetMyWarehouses")])
            else response,
        responseAsRecord = Table.FromList(finalResponse[value], Splitter.SplitByNothing(), {"Warehouses"}),
        dataWarehouses = Table.ExpandRecordColumn(responseAsRecord, "Warehouses", {"name", "datamartType", "objectId"}),
        warehouses = Table.SelectRows(dataWarehouses, each [datamartType] = "Datawarehouse"),
        withData = Table.AddColumn(warehouses, "Data", each GetWarehouseDatabase(baseUrl, [objectId], options), type table),
        rename = Table.RenameColumns(withData, {{"objectId", "lakehouseId"}, {"name", "lakehouseName"}}),
        removedColumns = Table.RemoveColumns(rename, {"datamartType"}),
        withDatabaseId = Table.AddColumn(removedColumns, "databaseId", each [lakehouseId])
    in
        if (response = null) then #table(LakehouseNavTableType, {}) else withDatabaseId;

/**
    Get the staging lakehouse extended properties record from lakehouse artifacts api.
    This will be used to store the version table information.
**/
GetStagingLakehouseExtendedProperties = (baseUrl as text, stagingLakehouseDetails as record) as nullable record =>
let
    url = Uri.Combine(baseUrl, Text.Format("/metadata/artifacts/#{0}", {stagingLakehouseDetails[StagingLakehouseId]})),
    response = try Web.JsonContents(url, [Origin = NonPii("GetStagingLakehouseExtendedProperties")]) catch (e) =>
                    let
                        // log warning if the call for staging lakehouse artifact fails
                        result = Diagnostics.Trace(TraceLevel.Warning, [Name = "GetStagingLakehouseExtendedProperties", Data = [Reason=e[Reason]?, Message=e[Message]?]], null)
                    in
                        result
in
if response <> null then response[extendedProperties] else null;

// presently DwProperties element in extendedProperties is coming back as a string, but ifin the future this format changes to a proper json element, then we will get back a record.
GetDwProperties = (extendedProperties) => let dwProperties = extendedProperties[DwProperties]? in
    if dwProperties = null then null
    else if dwProperties is text then Json.Document(dwProperties)
    else dwProperties;

GenerateLakeHouseTablesView = (baseUrl as text, workspaceId as text, lakehouseId as text, extendedProperties as record, options as record) as nullable table =>
    let
        // if staging lakehouse id and workspace id are passed in use that lakehouse for storing versions.
        stagingLakehouseDetails = if options[StagingWorkspaceId]? <> null and options[StagingLakehouseId]? <> null then GetStagingLakehouseExtendedProperties(baseUrl, options)
                                  else null,
        lakehouseDefaultSchemaName = extendedProperties[DefaultSchema]?,
        oneLakeTableUrl = if lakehouseDefaultSchemaName <> null then extendedProperties[OneLakeTablesPath] & "/" & lakehouseDefaultSchemaName else extendedProperties[OneLakeTablesPath],
        dwProperties = GetDwProperties(extendedProperties),
        lakehouseId = dwProperties[id]?,
        database = GetLakehouseDatabase(baseUrl, lakehouseId),
        refreshActionDetails = [BaseUrl = baseUrl, DwProperties=dwProperties, Options = options],
        refreshAction = Action.DoNothing, // Can be changed back to actual refresh action if we decide to sync a customer's output lakehouse sql endpoint.
        onelakeTables = GenerateOneLakeTable(baseUrl, oneLakeTableUrl, dwProperties, false, options, refreshActionDetails),
        onelakeFilesTable = GenerateFilesViewForLakeHouse(extendedProperties[OneLakeFilesPath]),
        tableWithContent = #table(
                        LakehouseTableDetailType,
                         { {Extension.LoadString("Files"), "Files", onelakeFilesTable, null, "Folder", "Folder", false}}),
        combinedFilesAndTables = onelakeTables & tableWithContent,
        nav = Table.ToNavigationTable(combinedFilesAndTables, {"Id", "ItemKind"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf"),
        view = Table.View(nav, [
            OnInvoke = (function, args, index) =>
                if (function = Value.Versions)
                    then GetLakehouseTableVersions(oneLakeTableUrl,
                        extendedProperties[OneLakeFilesPath],
                        GenerateOneLakeTable(baseUrl, oneLakeTableUrl, dwProperties, true, options, refreshActionDetails),
                        refreshAction,
                        stagingLakehouseDetails)
                // TODO pass in the table name to refresh action once the support for it is enabled.
                else if (Value.Metadata(Value.Type(function))[Documentation.Name]? = "Lakehouse.RefreshSqlMetadata")
                    then Diagnostics.Trace(TraceLevel.Information, [Name = "RefreshSqlMetadata", Data= [TableName = Value.ToText(List.Last(args))]], RefreshAction(baseUrl, dwProperties, options, Value.ToText(List.Last(args))))
                else ...,

            OnSelectRows = (selector) =>
                // If getting the "Files" node, short-circuit the listing of the tables
                let
                    index = try GetIndex(selector, {"Name", "ItemKind"}) otherwise [],
                    isFiles = index = [Name="Files", ItemKind="Folder"]
                in
                    if isFiles then tableWithContent
                    else Table.View(Table.SelectRows(nav, selector), [OnDeleteRows = () => DeleteRows(selector)]),

            OnInsertRows = (rowsToInsert as table) =>
                let
                    result =  Diagnostics.Trace(TraceLevel.Information, [Name = "LakehouseNonVersionedInsert", Data=[]], try
                    let
                        // TODO add support for list of tables
                        singleRow = try Table.SingleRow(rowsToInsert) otherwise error Extension.LoadString("MultiTableInsertNotSupported"),
                        tableName = singleRow[Id],
                        tableData = AnnotateDecimalTypes(singleRow[Data]),
                        onelakeContents = () => OneLake.Contents(oneLakeTableUrl),
                        tableFolder = if ValidateStagingArtifacts then if IsStagingLakehouseProvisioned(dwProperties) then onelakeContents
                            else error Error.Record(
                                 NonPii("DataSource.Error"),
                                 NonPii(Extension.LoadString("StagingLakehouseInInvalidState")),
                                 [
                                    #"StagingLakehouseProperties" = Value.ToText(dwProperties)
                                 ],
                                 {NonPii(lakehouseId)}
                            )
                        else
                            onelakeContents
                    in
                        Action.Sequence({
                            TableAction.InsertRows(tableFolder(), #table({"Name", "Content"}, {{ tableName, #table({},{}) }})),
                            () => ValueAction.Replace(
                                DeltaLake.Table(tableFolder(){[Name = tableName]}[Content], DeltaLake.DefaultOptions),
                                tableData),
                            RefreshAction(baseUrl, dwProperties, options, tableName)
                        })
                    )
                in
                    Connector.EvaluateQueryAndActionsForErrors(result, "LakehouseNonVersionedInsertError", "LakehouseNonVersionedInsertError", "GenerateLakeHouseTablesView"),

            OnDeleteRows = (selector as function) => DeleteRows(selector),

            DeleteRows = (selector as function) =>
                let
                    //we need the table based on delta format and not the table from tds endpoint.
                    result = Table.SelectRows(GenerateOneLakeTable(baseUrl, oneLakeTableUrl, dwProperties, true, options, refreshActionDetails),selector),
                    dataLakeFolders = OneLake.Contents(oneLakeTableUrl),
                    addDeleteActionColumn = Table.AddColumn(result, "DeleteActions", (r) => let actions = TableAction.DeleteRows(Table.SelectRows(dataLakeFolders, each [Name] = r[Id])) in actions ),
                    deleteActions = Action.Sequence({
                        Diagnostics.Trace(TraceLevel.Information, [Name = "LakehouseNonVersionedDelete", Data = []], Action.DoNothing),
                        Action.Sequence(addDeleteActionColumn[DeleteActions]),
                        Action.DoNothing
                    }),
                    deleteResults =  Diagnostics.Trace(TraceLevel.Information, [Name = "LakehouseNonVersionedDelete", Data=[]], try deleteActions)
                 in
                    Connector.EvaluateQueryAndActionsForErrors(deleteResults, "LakehouseNonVersionedDeleteError", "LakehouseNonVersionedDeleteError", "GenerateLakeHouseTablesView"),
            OnTestConnection = () => Sql.TestConnection(database, lakehouseId)
        ])
    in
       view;

GetWarehouseDatabase = (baseUrl, objectId, options) =>
    let
        url = Uri.Combine(baseUrl, Text.Format("/v1.0/myorg/datawarehouses/#{0}/information", {objectId})),
        response = Web.JsonContents(url, [Origin = NonPii("GetWarehouseDatabase")], [404 = null]), // 404 = Not Found
        tdsEndpointDetails =  CheckIfTdsEndpointInValidState(response, objectId, "Warehouse", "InvalidWarehouseState", false),
        result = if response = null or  tdsEndpointDetails = null then null
                else GenerateViewForWarehouseSqlTableData(
                    Sql.Contents(tdsEndpointDetails[tdsEndpoint], tdsEndpointDetails[name], options & [CreateNavigationProperties = false]))

    in
        result;

IsStagingLakehouseProvisioned = (dwProperties) =>
    dwProperties <> null  and Text.IsNotNullOrEmpty(dwProperties[tdsEndpoint]?)
    and Text.IsNotNullOrEmpty(dwProperties[id]?)
    and Text.IsNotNullOrEmpty(dwProperties[provisioningStatus]?)
    and dwProperties[provisioningStatus]? = "Success";

GenerateViewForWarehouseSqlTableData = (content as table) as table =>
let
    view = (content2) => Table.View(
        content2,
        [
            GetExpression = () => Value.Expression(Value.Optimize(content2)),
            OnInvoke = (function, args, index) =>
                if (Value.Metadata(Value.Type(function))[Documentation.Name]? = "Lakehouse.SqlTable") then content2
                else Function.Invoke(function, List.ReplaceRange(args, index, 1, {content2})),
            TableDefault = (newTable) => @view(newTable)
        ]),
    withView = Table.TransformColumns(content, {{"Data", view}})
in
    Table.View(withView, [
        GetExpression = () => Value.Expression(Value.Optimize(content)),
        OnInsertRows = (rows) => Diagnostics.Trace(TraceLevel.Information, [Name = "StagingWarehouseInsert", Data = []] , TableAction.InsertRows(content, rows)),
        OnUpdateRows = (updates, selector) => Diagnostics.Trace(TraceLevel.Information, [Name = "StagingWarehouseUpdate", Data = [] ], TableAction.UpdateRows(Table.SelectRows(content, selector), updates)),
        OnDeleteRows = (selector) => Diagnostics.Trace(TraceLevel.Information, [Name = "StagingWarehouseDelete", Data = []], TableAction.DeleteRows(Table.SelectRows(content, selector)))
    ]);

GenerateLakehouseDetailFormatTable = (input as table) =>
    let
        withId = Table.AddColumn(input, "Id", each [Name]),
        withIsLeaf = Table.AddColumn(withId, "IsLeaf", each true),
        withItemKind = Table.AddColumn(withIsLeaf, "ItemName", each "Table"),
        removeColumns = Table.RemoveColumns(withItemKind, {"Item"}),
        renamedColumns = Table.RenameColumns(removeColumns,{{"Kind", "ItemKind"}}),
        reorderColumns = Table.ReorderColumns(renamedColumns,Table.ColumnNames(#table(LakehouseTableDetailType, {})))
    in
        reorderColumns;

GetLakehouseDatabase = (baseUrl, lakewarehouseId) =>
    let
        url = Uri.Combine(baseUrl, Text.Format("/v1.0/myorg/lhdatamarts/#{0}/information", {lakewarehouseId})),
        response = Web.JsonContents(url, [Origin = NonPii("GetLakehouseDatabase")]),
        result = CheckIfTdsEndpointInValidState(response, lakewarehouseId, "Lakehouse", "InvalidLakehouseSqlStateAndStatus", true)
    in
        result;

CheckIfTdsEndpointInValidState = (response, artifactId as text, artifactType as text, errorCode as text, reportError as logical) =>
let
    state = response[state]?,
    status = response[status]?,
    name = response[name]?,
    safeData = [ ArtifactId = artifactId, State = state, Status = status ],
    data = [DwName = name],
    invalidSqlEndpointStateAndStatus = Error.Record(
        NonPii("DataSource.Error"),
        NonPii(Extension.LoadString("ArtifactInInvalidState")),
        [
            ArtifactId = artifactId,
            ArtifactType = artifactType
        ],
        {artifactType, name, NonPii(artifactId), NonPii(state), NonPii(status)}
    )
in
    if state = 1 and status = 1 then response[[tdsEndpoint],[name]]
    else if reportError then error Diagnostics.Trace(TraceLevel.Error,
        [Name = errorCode,
        Data = data, SafeData = safeData], invalidSqlEndpointStateAndStatus)
    else Diagnostics.Trace(TraceLevel.Warning,
        [Name = errorCode, Data = data, SafeData = safeData],
        null);

// Create a Versioned View for a Lakehouse
/*
The algorithm used by the connector to do a table insert in Lakehouse using DFE is as follows
1. Insert a new version in Lakehouse Version view. This step entails creating a folder with the version name in the staging lakehouse's file path or destination lakehouse files path.
2. DFE will then try to insert a new table in the version, this will trigger the OnInsertRows handler from CreateVersionableView method.
    This handler, will create the table's folder in lakehouse, create a subversion for the table using DeltaLake conector and insert an empty table with the table schema in it, publish this subversion (version + ".1")
    (required to trigger the view), create the actual version in the delta lake connector for that table.
3. DFE will then try to insert the actual data into the table, this will trigger the OnInsertRows Handler from GenerateViewForVersionedTable method and this will do the actual content insert on the delta table version.
4. Publish the version, new DFE will trigger the OnUpdateRows handler in GetLakehouseTableVersions, old DFE will trigger the OnUpdateRows handler in GetVersionTableForInnerNode (this doesn't work due to folding issue with old DFE)
    This step will publish the version on the delta table and delete the version from the ADLS as this version is marked as published.

## Use case for Fixed Schema Table Replace ##
1. During Fixed Schema Table replace, the DFE doesn't trigger a delete of a table in Lakehouse's version table.
2. Instead, there is a delete call to delete table's data. This will trigger Lakehouse connector's GenerateViewForVersionedTable delete rows handler.
3. During this delete operation, lakehouse connector will insert a version on the underlying Delta Table's version table. Then it will trigger a delete rows operation to delete the table's data in that version.
4. Next DFE will trigger an Insert Rows which will call GenerateViewForVersionedTable's InsertRows handler. In this handler as the table is already present, it will fall to AppendTable method
   in the else if block. This is happening because the table is already present and there is no .created marker and as the table was not deleted as per lakehouse's version table, there is no .deleted marker.
5. In this method, we will check if the version is already present on Delta Table and then trigger an insert rows operation on the Delta Table.
6. DFE will then trigger a commit operation to commit the version.

*/
GetLakehouseTableVersions = (onelakeTableUrl as text, onelakeFilesUrl as text, onelakeTables as table, refreshAction as action, stagingLakehouseDetails as nullable record) =>
let
    finalFilePathUrl = if stagingLakehouseDetails <> null then stagingLakehouseDetails[OneLakeFilesPath] else onelakeFilesUrl,
    versionsTableFromADLS = GenerateADLSVersionTable(finalFilePathUrl, refreshAction),
    source = onelakeTables,

    staging2 = versionsTableFromADLS,
    versions = Table.SelectRows(staging2, each [Data] is table),
    nullVersionRows = {{null, true, source, null}},
    versionsRows = Table.TransformRows(versions,
    (version) => let
        versionName = version[Name],
        // the version name which the connector returns in the version table will be without '_mashup_temporary_' marker
        splitVersionName = Text.Split(versionName, "_"){3}
    in
        {
            splitVersionName,
            false,
            CreateVersionableView( onelakeTables, versionName, onelakeTableUrl, finalFilePathUrl, refreshAction),
            version[Date modified]?
        }),
    versionsTable = #table(
        type table [Version = nullable text, Published = logical, Data = any, Modified = nullable datetime],
        nullVersionRows & versionsRows)
in
    Table.View(versionsTable,
    [
        // Insert a new version row in the version table.
        OnInsertRows = (rows) => if (Table.ColumnNames(rows) = {"Version"} and Table.RowCount(rows) = 1 ) then
            let
                transformedRows = Table.TransformColumns(rows,{{"Version", each TemporaryParentVersionFolder & "_" & _}}),
                renamedCols = Table.RenameColumns(transformedRows, {{"Version", "Name"}})

            in Action.Sequence(
            {
                TableAction.InsertRows(staging2, renamedCols),
                () => let
                        regenTable = @GetLakehouseTableVersions(onelakeTableUrl, onelakeFilesUrl, onelakeTables, refreshAction, stagingLakehouseDetails),
                        bufferedListOfVersionToInsert = List.Buffer(rows[Version]),
                        versionTable = Table.SelectRows(regenTable, each List.Contains(bufferedListOfVersionToInsert,[Version]))
                      in
                        Action.Return(versionTable)
            })
        else ...,

        // commit the version to lakehouse.
        OnUpdateRows = (updates, selector) =>
        let
            result = Diagnostics.Trace(TraceLevel.Information, [Name = "LakehouseVersionCommit", Data = []], try
                        CommitVersionToLakehouse(onelakeTableUrl,finalFilePathUrl,selector,refreshAction,staging2))
        in
            Connector.EvaluateQueryAndActionsForErrors(result, "LakehouseVersionCommitError", "LakehouseVersionCommitError", "GetLakehouseTableVersions"),
        //delete rows from version table.
        OnDeleteRows = (selector) =>
        let
            result = Diagnostics.Trace(TraceLevel.Information, [Name = "LakehouseVersionDelete", Data = []], try
                let
                 adlsVersionSource = OneLake.Contents(finalFilePathUrl),
                 versionsToDelete = Table.TransformColumns(Table.SelectRows(versionsTable, selector), {{"Version", each TemporaryParentVersionFolder & "_" & _}}),
                 tableWithActionColumns = Table.AddColumn(versionsToDelete, "DeleteActions", (r) =>
                    let
                        selectedVersions = Table.SelectRows(adlsVersionSource, each [Name] = r[Version]),
                        deleteAction = Action.Sequence({TableAction.DeleteRows(selectedVersions), Action.DoNothing})
                    in
                        deleteAction
                    )
                in
                    if (versionsToDelete{0}[Version] = null) then error Extension.LoadString("CannotDeletePublishedVersion")
                    else Action.Sequence(
                    {
                        Action.Sequence(tableWithActionColumns[DeleteActions])
                    })
            )
        in
            Connector.EvaluateQueryAndActionsForErrors(result, "LakehouseVersionDeleteError", "LakehouseVersionDeleteError", "GetLakehouseTableVersions")
    ]);

/**
    This method will be used to commit a version to the lakehouse. This step has three parts
    1. Go to files path to get the versions for the lakehouse. Update names to remove the _mashup_temporary_ marker.
    2. Select the version to commit using the selector function.
    3. Update the names in the table from step 2 to add back the _mashup_temporary_ marker.
    4. Get the table name which is being created, this table is in the version folder and will have a .created marker.
    5. Get the actual delta table for it and commit the version on the delta table.
    6. Commit the version on the lakehouse. This is deleting the version folder from files path.
*/
CommitVersionToLakehouse = (onelakeTableUrl as text, finalFilePathUrl as text, selector as function, refreshAction as action, lakehouseVersionTable as table) =>
let
    adlsSource =  OneLake.Contents(onelakeTableUrl),
    adlsVersionSource = OneLake.Contents(finalFilePathUrl),
    renamedColForVersionFolder = Table.RenameColumns(adlsVersionSource, {{"Name", "Version"}}),
    // remove the '_mashup_temporary_' marker from the version name
    modifledNameColumn = Table.TransformColumns(renamedColForVersionFolder, {{"Version", each if Text.StartsWith(_,TemporaryParentVersionFolder & "_")then Text.Split(_,"_"){3} else _}}),
    subVersions = Table.SelectRows(modifledNameColumn, selector),
    // add  back the '_mashup_temporary_' marker from the version name
    modifiedSubVersions = Table.TransformColumns(subVersions, {{"Version", each TemporaryParentVersionFolder & "_" & _}}),
    // get table name and the version to search for:
    createdTableName = Text.Split(Table.SelectRows(modifiedSubVersions{0}[Content], each Text.Contains([Name], CreatedMarker)){0}[Name],CreatedMarker){0},
    versionForDeltaTable = modifiedSubVersions{0}[Version],
    versionTable = Value.Versions(DeltaLake.Table(adlsSource{[Name = createdTableName]}[Content], DeltaLake.DefaultOptions))
in
    if Table.RowCount(modifiedSubVersions) <> 1 then error Text.Format(Extension.LoadString("MultipleVersionsWithSameGuid"), { Text.FromBinary(Json.FromValue(modifiedSubVersions))})
    else Action.Sequence({
        TableAction.UpdateRows(Table.SelectRows(versionTable,  each [Version] = versionForDeltaTable), {{"Published", each true}}),
        Action.Sequence({TableAction.DeleteRows(Table.SelectRows(adlsVersionSource, each [Name] = versionForDeltaTable)), Action.DoNothing}),
        refreshAction,
        Action.Return(lakehouseVersionTable)
    });

/* Acts like a staging location for a lakehouse version
            */
GenerateADLSVersionTable = (oneLakeFileUrl as text, refreshAction as action) =>
let
emptyTable = #table(
            type table [Name = nullable text, Extension = nullable text, #"Date accessed" = nullable datetime,#"Date modified" = nullable datetime,#"Date created" = nullable datetime, Data = any, Modified = nullable datetime],
                {{null, null,null,null, null,null,null}}),
adlsContents = OneLake.Contents(oneLakeFileUrl),
versionFolder = Table.SelectRows(adlsContents, each Text.StartsWith([Name], TemporaryParentVersionFolder)),
renameColumns = Table.RenameColumns(versionFolder, {{"Content", "Data"}}),
finalTable = if Table.RowCount(versionFolder) = 0 then emptyTable else renameColumns

in
Table.View(finalTable, [
    OnInsertRows = (rows) => if (Table.ColumnNames(rows) = {"Name"}) then
            let
                adlsSource = OneLake.Contents(oneLakeFileUrl),
                rowsToInsert = Table.AddColumn(rows,"Content", each #table({}, {})),
                versionInsertActions = Action.Sequence(
                    {
                        () =>
                        let
                                createVersionFolderAction = Action.Sequence({
                                    () => let
                                            adlsSourceNew = adlsSource ?? OneLake.Contents(oneLakeFileUrl),
                                            action = TableAction.InsertRows(adlsSourceNew,rowsToInsert)
                                            in action,
                                            Action.DoNothing
                                    })
                        in
                            createVersionFolderAction,
                        () => Action.Return(adlsSource)
                    }),
                result = Diagnostics.Trace(TraceLevel.Information, [Name = "LakehouseVersionInsert", Data = []], try versionInsertActions)

            in
                Connector.EvaluateQueryAndActionsForErrors(result, "LakehouseVersionInsertError", "LakehouseVersionInsertError", "GenerateADLSVersionTable")
        else ...,


    OnUpdateRows = (updates, selector) =>
    let
        result = Diagnostics.Trace(TraceLevel.Information, [Name = "LakehouseVersionCommit", Data = []], try
            let
                adlsSource =  OneLake.Contents(oneLakeFileUrl),
                deltaLakeTable = DeltaLake.Table(adlsSource, DeltaLake.DefaultOptions),
                getVersions = Value.Versions(deltaLakeTable)
            in
                Action.Sequence({
                    TableAction.UpdateRows(Table.SelectRows(getVersions, selector), {{"Published", each true}}),
                    refreshAction
                }))
        in
            Connector.EvaluateQueryAndActionsForErrors(result, "LakehouseVersionCommitError", "LakehouseVersionCommitError", "GenerateADLSVersionTable"),

    OnDeleteRows = (selector) =>
    let
        adlsSource = OneLake.Contents(oneLakeFileUrl),
        deleteActions = Action.Sequence
                    ({
                        () => Diagnostics.Trace(TraceLevel.Information, [Name = "LakehouseVersionDelete", Data = []], Action.DoNothing),
                        TableAction.DeleteRows(Table.SelectRows(adlsSource, selector)),
                        Action.DoNothing
                    }),
        result = Diagnostics.Trace(TraceLevel.Information, [Name = "LakehouseVersionDelete", Data = []], try deleteActions)
    in
        Connector.EvaluateQueryAndActionsForErrors(result, "LakehouseVersionDeleteError", "LakehouseVersionDeleteError", "GenerateADLSVersionTable")
]);

GenerateFilesViewForLakeHouse = (onelakeFileUrl as text) as nullable table =>
    let
        oneLakeTables = OneLake.Contents(onelakeFileUrl),
        withItemKind = Table.AddColumn(oneLakeTables, "ItemKind", each if [Content] is binary then "File" else "Folder"),
        withIsLeaf = Table.AddColumn(withItemKind, "IsLeaf", each [Content] is binary),
        nav = Table.ToNavigationTable(withIsLeaf, {"Name"}, "Name", "Content", "ItemKind", "ItemKind", "IsLeaf"),
        asUpdateable = Table.View(nav, [
            // TODO: revisit or fixup so these align with the projected table instead of the base table
            OnInsertRows = (rowsToInsert) => TableAction.InsertRows(oneLakeTables, rowsToInsert),
            OnUpdateRows = (updates, selector) => TableAction.UpdateRows(Table.SelectRows(oneLakeTables, selector), List.Transform(updates, each {[Name], [Function]})),
            OnDeleteRows = (selector) => TableAction.DeleteRows(Table.SelectRows(oneLakeTables, selector))
        ])
    in
         if (onelakeFileUrl = null) or (oneLakeTables = null) then null else asUpdateable;

//  If the dwProperties element is not null then get tables from tds endpoint or fall back to delta tables from the lakehouse.
// fetchDeltaTables flag indicates this we want to fetch the Delta Table View this way during versioned writes or deletes we will always return the Delta Tables and not the tables from the SQL Endpoint.
GenerateOneLakeTable = (baseUrl as text, onelakeTableUrl as text, dwProperties as nullable record, fetchDeltaTables as logical, options as record, refreshActionDetails as record) as table =>
    let
        useSql = dwProperties <> null and dwProperties[tdsEndpoint]? <> null and options[EnableFolding]? <> false and not fetchDeltaTables,
        deltaNav = GenerateNavTableUsingDeltaTable(onelakeTableUrl, refreshActionDetails),
        nav = if useSql then GenerateSqlTableView(baseUrl, dwProperties, deltaNav, options) else deltaNav
    in
        if (onelakeTableUrl = null) then null else nav;

// Go to the one lake path and fetch all tables and convert them to delta format.
GenerateNavTableUsingDeltaTable = (onelakeTableUrl as text, refreshActionDetails as record) =>
    let
        oneLakeTables = OneLake.Contents(onelakeTableUrl),
        renamedCols = Table.RenameColumns(oneLakeTables, {{"Content", "Data"}}),
        removedRows = Table.SelectRows(renamedCols, each not Text.StartsWith([Name], TemporaryParentVersionFolder)),
        removedRowsWithVersionIndicator = Table.SelectRows(removedRows, each not Text.StartsWith([Name], "Versions-")),
        tableWithTransformedNameWithData = Table.AddColumn(removedRowsWithVersionIndicator, "DataWithName" , each WithAfterAction(DeltaLake.Table([Data], DeltaLake.DefaultOptions),
            RefreshAction(refreshActionDetails[BaseUrl], refreshActionDetails[DwProperties], refreshActionDetails[Options], [Name])), type table ),
        removedDataColumn = Table.RemoveColumns(tableWithTransformedNameWithData, {"Data"}),
        renamedDataColumn = Table.RenameColumns(removedDataColumn, {{"DataWithName", "Data"}}),
        withItemKind = Table.AddColumn(renamedDataColumn, "ItemKind", each "Table"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true),
        withId = Table.AddColumn(withIsLeaf, "Id", each [Name]),
        withSchema = Table.AddColumn(withId, "Schema", each null),
        removeOtherColumns = Table.SelectColumns(withSchema, Table.ColumnNames(#table(LakehouseTableDetailType, {}))),
        navDeltaTable = Table.ToNavigationTable(removeOtherColumns, {"Id", "ItemKind"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navDeltaTable;

GenerateSqlTableView = (baseUrl as text, dwProperties as record, deltaTableContent as table, options as record) as table =>
    let
        lakehouseId = dwProperties[id]?,
        database = GetLakehouseDatabase(baseUrl, lakehouseId),
        sqlContents = Sql.Contents(database[tdsEndpoint], database[name], options),
        getNav = (sqlTableView) => let
            formattedTable = GenerateLakehouseDetailFormatTable(sqlTableView),
            filteredRecords = Table.SelectRows(formattedTable, each [ItemKind] = "Table"), // only show tables

            // Get table ids from SQL table view and delta table view.
            idsFromSQL = filteredRecords[Id],
            idsFromDelta = deltaTableContent[Id],

            // Rather than transforming the column, add a new Data column which will have a reference to underlying delta table of the lakehouse table for easier version support integration.
            addedDataColumns = Table.AddColumn(formattedTable, "SqlTableView", each GenerateViewForSqlTableData([Data], deltaTableContent, [Id])),
            removeDataColumn = Table.RemoveColumns(addedDataColumns,  {"Data"}),
            renamedSqlTableViewColumn = Table.RenameColumns(removeDataColumn, {{"SqlTableView", "Data"}}),
            reorderedColumns = Table.ReorderColumns(renamedSqlTableViewColumn, Table.ColumnNames(#table(LakehouseTableDetailType, {}))),
            nav = Table.ToNavigationTable(reorderedColumns, {"Id","ItemKind"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
        in
            Table.View(nav,
            [
                OnSelectRows = (selector) => let
                    // id and itemkind is pattern from UI, Name is pattern from LMS
                    index =  try GetIndex(selector, {"Id", "ItemKind"}) otherwise try GetIndex(selector, {"Name"}) otherwise [],
                    filterValue = index[Name]? ?? index[Id]?
                in
                    if (index <> []) then @getNav(Table.SelectRows(sqlTableView, each [Name] = filterValue)) // TODO add schema once schemas for lakehouse is enabled.
                    else Table.SelectRows(nav, selector),
                OnTestConnection = () => Sql.TestConnection(database, lakehouseId)
            ])
    in
        getNav(sqlContents);

// Select the rows from the Delta table which are present in the SQL table ids list. Return this table and combine the results with the SQL table.
GetMissingTable = (missingIds as list, inputTable as table) as table =>
    let
        loggedInputTable = Diagnostics.Trace(TraceLevel.Information, [Name = "GetMissingTable/SqlDeltaMismatch", Data = [TableNames = Text.Combine(missingIds, ",")]], inputTable),
        selectedRows = Table.SelectRows(loggedInputTable, each List.Contains(missingIds,[Id]))
    in
        selectedRows;

// Create a simple view for the SQL table, this view will provide an implementation for the Value.Versions which will return the Version table of the Delta table representation of the lakehouse table.
GenerateViewForSqlTableData = (content as table, deltaTableContent as table, tableId as text) as table => let
    view = (content2, deltaTableContent2) => Table.View(
        content2,
        [
            GetExpression = () => Value.Expression(Value.Optimize(content2)),
            OnInvoke = (function, args, index) =>
                if (function = Value.Versions) then Value.Versions(deltaTableContent2{[Id = tableId]}[Data])
                else if (Value.Metadata(Value.Type(function))[Documentation.Name]? = "Lakehouse.SqlTable") then content2 // TODO (Output): review; used to fold output to DW
                else Function.Invoke(function, List.ReplaceRange(args, index, 1, {content2})),
            TableDefault = (newTable) => @view(newTable, null)
        ])
in
    view(content, deltaTableContent);

GenerateViewForVersionedTable = (content as table, version as text,onelakeFileUrl as text, tableName as text, refreshAction as action)  =>
let
    // the delta table will either have the version or subversion.
    nullVersionData = content{[Version = null]},
    selectedVersionOrDefault =  if content{[Version = version & ".1"]}? <> null then content{[Version = version & ".1"]}
                                else if content{[Version = version]}? <> null then content{[Version = version]}
                                else nullVersionData,
    tableContent = selectedVersionOrDefault[Data]
in
    Table.View(tableContent,[
        OnInsertRows = (rowsToInsert as table) =>
                    let
                        result = Diagnostics.Trace(TraceLevel.Information, [Name = "VersionedLakehouseTableInsert", Data = [TableName = tableName], SafeData = [Version = version ]], try
                            let
                                dataLakeFolders = OneLake.Contents(onelakeFileUrl),
                                //TODO what if a version has multiple tables marked as .deleted
                                versionFolder = dataLakeFolders{[Name = version]}[Content],
                                createdMarker = versionFolder{[Name = tableName & CreatedMarker]}?,
                                deletedTable = versionFolder{[Name = tableName & DeletedMarker]}?,
                                deleteOrCreateAction = if deletedTable <> null then
                                                        Action.Sequence({
                                                            // From DFE when an existing table's contents are replced, this OnInsertRows handler is invoked and we need to ensure right steps are executed to ensure Publish step is successful.
                                                            // Existing Table replace
                                                           () => let actions = Action.Sequence({
                                                                 () => Diagnostics.Trace(TraceLevel.Information, [Name = "VersionedLakehouseTableInsertTableReplaceWithTableContent", Data = []], Action.DoNothing),
                                                                 ()=> TableAction.DeleteRows(Table.SelectRows(dataLakeFolders{[Name = version]}[Content], each [Name] = tableName & DeletedMarker)),
                                                                 ()=> TableAction.InsertRows(dataLakeFolders{[Name = version]}[Content], #table({"Name"}, {{tableName & CreatedMarker}})),
                                                                 () => ValueAction.Replace(tableContent, AnnotateDecimalTypes(rowsToInsert))
                                                           })
                                                           in actions
                                                        })
                                                        // Table Append
                                                        else if createdMarker is null then Action.Sequence({
                                                            () => let actions = Action.Sequence({
                                                                 () => Diagnostics.Trace(TraceLevel.Information, [Name = "VersionedLakehouseTableInsertTableAppendWithContent", Data = [], SafeData = [FixedSchemaFlag = Text.From(FixedSchemaFix)]], Action.DoNothing),
                                                                 ()=> if FixedSchemaFix then 
                                                                 // if Table.IsEmpty means there is no underlying version yet and we can safely insert a version.
                                                                        if Table.IsEmpty(Table.SelectRows(content, each [Version] = version)) then TableAction.InsertRows(content, #table({"Version"},{{version}})) 
                                                                        else Action.DoNothing
                                                                    else TableAction.InsertRows(content, #table({"Version"},{{version}})),
                                                                 ()=> TableAction.InsertRows(dataLakeFolders{[Name = version]}[Content], #table({"Name"}, {{tableName & CreatedMarker}})),
                                                                 ()=> TableAction.InsertRows(tableContent, AnnotateDecimalTypes(rowsToInsert))
                                                           })
                                                           in actions
                                                        })
                                                        // New table insert or existing table replacement with current DFE.
                                                        else TableAction.InsertRows(tableContent, AnnotateDecimalTypes(rowsToInsert)),

                                actions = Action.Sequence({
                                    deleteOrCreateAction,
                                    refreshAction,
                                    Action.DoNothing})
                            in
                                actions
                        )
                    in
                        Connector.EvaluateQueryAndActionsForErrors(result, "VersionedLakehouseTableInsertError", "VersionedLakehouseTableReplaceError", "GenerateViewForVersionedTable"),

        OnDeleteRows = (selector) =>
                    let
                        actions =
                                Action.Sequence({
                                    () => Diagnostics.Trace(TraceLevel.Information, [Name = "VersionedLakehouseDeleteDeltaTableData", Data = [], SafeData = [Version = version, FixedSchemaFlag = Text.From(FixedSchemaFix)]], Action.DoNothing),
                                    () => TableAction.InsertRows(content,  #table({"Version"}, {{version}})),
                                    (result) => if FixedSchemaFix then TableAction.DeleteRows(result{[Version = version]}[Data]) else Action.DoNothing,
                                    Action.DoNothing
                                }),
                        deleteActionResult = Diagnostics.Trace(TraceLevel.Information, [Name = "VersionedLakehouseTableDelete", Data = [TableName = tableName], SafeData = [Version = version ]], try actions)
                    in
                        Connector.EvaluateQueryAndActionsForErrors(deleteActionResult, "VersionedLakehouseTableDeleteError", "VersionedLakehouseTableDeleteError", "GenerateViewForVersionedTable")
    ]);

// Generate a list of tables which have been deleted in a version.
// These tables should be skipped in the list of tables for a version returned from lakehouse's version table.
GetDeletedTablesListForAVersion = (oneLakeFilesUrl as text, version as text) =>
let
    versionSourceFromAdls =  OneLake.Contents(oneLakeFilesUrl & "/" & version),
    justDeletedTables = Table.SelectRows(versionSourceFromAdls, each Text.Contains([Name], DeletedMarker)),
    justDeletedTableNames = List.Buffer(List.Transform(justDeletedTables[Name], each Text.Split(_, "."){0}))
in
    Diagnostics.Trace(TraceLevel.Information, [Name = "DeletedLakehouseTablesListInVersion", Data = [], SafeData = [Version = version, DeletedTableCount = List.Count(justDeletedTableNames)]], justDeletedTableNames);

// Represents each Table column for a Version. This piece does the heavy lifting of creating a empty table, adding data to a table etc.
CreateVersionableView = ( content as table, version as text, onelakeTableUrl as text, onelakeFilesUrl as text, refreshAction as action) =>
let
    // Adding a new column which has a table with records of Table Id and Table Data, this makes handing cases for Table Deletes and Tables Appends easier.
    addedColumn = Table.AddColumn(content, "DataWithName", each #table({"IdWithData"}, {{[Id = [Id], Data = [Data]]}})),
    removeColumn = Table.RemoveColumns(addedColumn, {"Data"}),
    renameColumn = Table.RenameColumns(removeColumn, {"DataWithName" , "Data"}),
    justDeletedTableNames = GetDeletedTablesListForAVersion(onelakeFilesUrl, version),
    transformedDeltaLakeTable = Table.TransformColumns(renameColumn, {{"Data", (val) => GenerateViewForVersionedTable(Value.Versions(val[IdWithData]{0}[Data]), version, onelakeFilesUrl, val[IdWithData]{0}[Id], refreshAction), type table}}),
    removedDeletedTables = if List.Count(justDeletedTableNames) > 0 then Table.SelectRows(transformedDeltaLakeTable, each not List.Contains(justDeletedTableNames, [Name])) else transformedDeltaLakeTable
in
Table.View(removedDeletedTables,[
     OnInvoke = (function, args, index) =>
                if (function = Value.VersionIdentity) then GetVersionIdentity()
                else if (function = Value.Versions) then GetVersionTableForInnerNode()
                else ...,

    // Required by Old DFE. It executes Value.Verions on  Value.Versions(lk){[Version = <some version>]}[Data]
    // TODO clean up as it's potentiall no longer required.
    GetVersionTableForInnerNode = () =>
        let
            versionTable =  GetLakehouseTableVersions(onelakeTableUrl,onelakeFilesUrl, content, refreshAction)
        in
        Table.View(versionTable,[

            OnInvoke = (function, args, index) =>
                if (function = Value.VersionIdentity) then version
                else ...,

            OnUpdateRows = (updates, optional selector) =>
            let
                commitResult = CommitVersionToLakehouse(onelakeTableUrl, onelakeFilesUrl, selector, refreshAction, content),
                result = Diagnostics.Trace(TraceLevel.Information, [Name = "OldDfeCommitVersion" , Data = []], try commitResult)
            in
                Connector.EvaluateQueryAndActionsForErrors(result, "LakehouseOldDfeVersionCommitError","LakehouseOldDfeVersionCommitError", "CreateVersionableView")
        ]),

    GetVersionIdentity = () =>
        let
            loggedVersion = Diagnostics.Trace(TraceLevel.Information, [Name = "GetVersionIdentity", Data = [], SafeData = [Version = version]], version)
        in
            loggedVersion,
     OnInsertRows = (rowsToInsert as table) =>
                let
                    result = Diagnostics.Trace(TraceLevel.Information, [Name = "CreateVersionableView/VersionedLakehouseTableInsert", Data = [], SafeData = [Version = version]], try
                        let
                        renamedColsInRowsToInsert = Table.RenameColumns(rowsToInsert, {{"Id", "Name"}}),
                        tableNameToInsert = renamedColsInRowsToInsert[Name]{0} as text,
                        tableContentToInsert = renamedColsInRowsToInsert[Data]{0},
                        dataLakeFolders = OneLake.Contents(onelakeTableUrl),
                        dataLakeVersionParentFolder = OneLake.Contents(onelakeFilesUrl),
                        isItemKindCorrect = renamedColsInRowsToInsert{0}[ItemKind] = "Table" and  renamedColsInRowsToInsert{0}[Data] is table,
                        actions = if isItemKindCorrect then Action.Sequence({

                            () =>
                                let
                                    // table is present so if the table was marked as deleted in replace table scenario remove the .deleted entry from versions folder
                                    isTablePresent = dataLakeFolders{[Name = tableNameToInsert]}?,
                                    tablePresentActions =
                                        let
                                            // Table is being recreated in the version, delete the .deleted entry
                                            actions =  Action.Sequence({
                                                    Diagnostics.Trace(TraceLevel.Information, [Name = "VersionedLakehouseTableInsertTableAlreadyExists", Data = []], Action.DoNothing),
                                                    TableAction.DeleteRows(Table.SelectRows(dataLakeVersionParentFolder{[Name = version]}[Content], each [Name] = tableNameToInsert & DeletedMarker)),
                                                    Action.DoNothing
                                                })

                                        in
                                            actions,
                                    // TODO make this logic a little better to ensure if the new table creation fails, the table folder is cleared from OneLake.
                                    newTableInsertActions =
                                        let
                                            actions = Action.Sequence({
                                                () => Diagnostics.Trace(TraceLevel.Information, [Name = "VersionedLakehouseTableInsertNewTableFolderLakehouse", Data = []], Action.DoNothing),
                                                () => TableAction.InsertRows(dataLakeFolders, Table.SelectColumns(Table.RenameColumns(renamedColsInRowsToInsert, {{"Data","Content"}}),{"Name", "Content"}))
                                            })
                                        in
                                            actions,
                                    actions = if isTablePresent <> null then  tablePresentActions else newTableInsertActions
                                in
                                actions,

                            // Create a file with .created marker to indicate the table which was created, this helps in publishing later.
                            () => TableAction.InsertRows(dataLakeVersionParentFolder{[Name = version]}[Content], #table({"Name"}, {{tableNameToInsert & CreatedMarker}})),

                            ()=>
                            let
                                dataLakeFolders = OneLake.Contents(onelakeTableUrl),
                                deltaLakeTable = DeltaLake.Table(dataLakeFolders{[Name = tableNameToInsert]}[Content], DeltaLake.DefaultOptions),
                                getVersions = Value.Versions(deltaLakeTable),
                                selectedVersion = getVersions{[Version = version]}?,
                                // Create a sub-version in DeltaLake connector for the table and insert the empty table with the schema information.
                                actions = Action.Sequence({
                                    // if this is a case of table replacement, we will return the existing version.
                                    () => if selectedVersion <> null then Action.Return([Table=Table.SelectRows(getVersions, each [Version] = version), alreadyPresent = true])
                                        else  Action.Sequence({TableAction.InsertRows(getVersions, #table({"Version"}, {{version & ".1"}})), (result) => Action.Return([Table  = result, alreadyPresent = false])}),
                                    (result) => Action.Sequence({
                                                Diagnostics.Trace(TraceLevel.Information, [Name = "VersionedLakehouseTableInsertCreateEmptyDeltaTable", Data = [], SafeData = [TableAlreadyPresent = Text.From(result[alreadyPresent]), FixedSchemaFlag = Text.From(FixedSchemaFix)]], Action.DoNothing),
                                                // if table is already present it is a delta table and we need to do an insert row call.
                                                if result[alreadyPresent] and FixedSchemaFix then TableAction.InsertRows(result[Table]{0}[Data], tableContentToInsert)
                                                // DeltaLake connector reports an error if InsertRows handler is used because the table currently is not an actual delta table.
                                                // TODO : Once current architectural limitation is addressed change to TableAction.InsertRows
                                                else ValueAction.Replace(result[Table]{0}[Data], tableContentToInsert),
                                                Action.Return(result)}),
                                    (result) =>
                                    let
                                        deltaLakeTable = DeltaLake.Table(dataLakeFolders{[Name = tableNameToInsert]}[Content], DeltaLake.DefaultOptions),
                                        getVersions = Value.Versions(deltaLakeTable),
                                        selectedVersion = Table.SelectRows(getVersions, each [Version] = result[Table]{0}[Version])
                                    in
                                        // Publish this version in delta lake to ensure the delta log with the schema is created, this allows us to have a view on this table.
                                        // For an existing table return the result from previous step, we don't want to publish the version yet.
                                        Action.Sequence({
                                            () => Diagnostics.Trace(TraceLevel.Information, [Name = "VersionedLakehouseTableInsertSubVersionPublish", Data = [], SafeData = [Version = result[Table]{0}[Version]]], Action.DoNothing),
                                            () =>  if result[alreadyPresent] then Action.Return(result) else Action.Sequence({
                                                TableAction.UpdateRows(selectedVersion, {{"Published", each true}}),
                                                (result) => Action.Return([Table=result, alreadyPresent = false])
                                                }),
                                            (result) => Action.Return(result)
                                            }),
                                    (result) =>
                                    let
                                        deltaLakeTable = DeltaLake.Table(dataLakeFolders{[Name = tableNameToInsert]}[Content], DeltaLake.DefaultOptions),
                                        getVersions = Value.Versions(deltaLakeTable),
                                        insertAction =   if result[alreadyPresent] then Action.DoNothing else TableAction.InsertRows(getVersions, #table({"Version"}, {{version}}))
                                    in
                                        // Create the actual version in DeltaLake for this table or in case of table replacement don't do anything.
                                        insertAction
                                })
                            in
                                actions
                            }) else ...
                    in
                        if Table.RowCount(renamedColsInRowsToInsert) > 1 then error Extension.LoadString("MultiTableInsertInVersionNotSupported")
                        else if not NameIsValid(tableNameToInsert) then error Extension.LoadString("InvalidTableName")
                        else actions )
                    in
                        Connector.EvaluateQueryAndActionsForErrors(result, "VersionedLakehouseTableInsertError","VersionedLakehouseTableCreateError", "CreateVersionableView"),
    // Versioned lakehouse view, delete an existing table.
    OnDeleteRows = (selector) =>
         let
            result = Diagnostics.Trace(TraceLevel.Information, [Name = "CreateVersionableView/VersionedLakehouseTableDelete", Data= [], SafeData = [VersionName = version]], try
            let
                selectedTable = Table.SelectRows(content,selector),
                selectedTableIds = selectedTable[Id],
                // TODO add multi table support in a version
                tableNameToDelete = selectedTableIds{0} & DeletedMarker,
                adlsSource =  OneLake.Contents(onelakeFilesUrl & "/" & version),
                tableListFileToCreate =  #table({"Name","Content"}, {{ tableNameToDelete ,#table({},{})}}),
                // Create a tracker file which has a list of tables for a given version.
                actions =  Action.Sequence({
                    TableAction.InsertRows(adlsSource,tableListFileToCreate), Action.DoNothing})
            in
                if Table.RowCount(selectedTable) > 1 then error Extension.LoadString("MultiTableDeleteInVersionNotSupported") else actions
            )
            in
                Connector.EvaluateQueryAndActionsForErrors(result, "VersionedLakehouseTableDeleteError","VersionedLakehouseDeleteExistingTableError", "CreateVersionableView")

    // no op for now, this code might be needed in the next iteration.
    // Versioned lakehouse view, update table.not being invoke might be needed later.
    /*
    OnUpdateRows = (updates, selector) =>
                let
                    result = Diagnostics.Trace(TraceLevel.Information, "Commit the version block from CreateVersionableView", try
                    let
                        adlsSource =  DataLake.Contents(onelakeUriRecord[AdlsUrl], onelakeUriRecord[Sas]),
                        deltaLakeTable = DeltaLake.Table(adlsSource),
                        getVersions = Value.Versions(deltaLakeTable)
                    in
                        Action.Sequence({
                            Action.Return(getVersions)
                        }))
                in
                    if (result[HasError]) then error Table.ViewError(result[Error]) else result[Value] */
]);

// We need to look at decimal types and ensure they are SQL compatible while writing.
// By default the M Parquet writer will output DECIMAL(57, 28) for Decimal.Type. This exceeds SQL Server's maximum precision of 38 digits,
// so we use facets to truncate the precision to allow us to read the file via SQL Server later.
AnnotateDecimalTypes = (table) =>
  let
    fields = Record.ToTable(Type.RecordFields(Type.TableRow(Value.Type(table)))),
    transformed = Table.TransformColumns(fields, {{"Value", (t) => if Type.NonNullable(t[Type]) <> Decimal.Type then t else [
        Type = Type.ReplaceFacets(t[Type], [NumericPrecisionBase = 10, NumericPrecision = 34, NumericScale = 6]),
        Optional = false]}}),
    newType = type table Type.ForRecord(Record.FromTable(transformed), false)
  in
    Value.ReplaceType(table, newType);

RefreshAction = (baseUrl, dwProperties, options, tableName as text) =>
if dwProperties <> null and options[MetadataRefresh]? = true then
    Action.Sequence({
        () => Action.Return(
            let
                tryRefresh = Diagnostics.Trace(TraceLevel.Information,
                    [Name = "RefreshMetadata", Data = [TableName = tableName], SafeData = []],
                    () => try RefreshMetadata(baseUrl, dwProperties, options[MetadataRefresh]?, tableName),
                    true),
                refreshFailed = tryRefresh[HasError],
                finalStatus = if refreshFailed then "error" else tryRefresh[Value],
                level = if refreshFailed
                    then TraceLevel.Error
                else if finalStatus = "success" or finalStatus = "N/A"
                    then TraceLevel.Information
                else TraceLevel.Warning,
                statusTraceData = [
                    Name = "RefreshMetadata/Status",
                    Data = if refreshFailed then [ErrorMessage=tryRefresh[Error][Message]] else [],
                    SafeData = [FinalStatus=finalStatus]
                ]
            in
                if Diagnostics.Trace(level, statusTraceData, refreshFailed)
                    then error tryRefresh[Error]
                    else null),
        Action.DoNothing
    })
else Action.DoNothing;

Connector.EvaluateQueryAndActionsForErrors = (result as any, marker as text, errorMessageKey as text, callerName as text) =>
if result[HasError] then
    error Table.ViewError(Connector.GenerateErrorRecord(marker, Extension.LoadString(errorMessageKey), callerName, result[Error]))
else
    Connector.LogActionErrorsIfPresent(result[Value], marker, callerName, Extension.LoadString(errorMessageKey));

// Generate error records if an error occurs
Connector.LogActionErrorsIfPresent = (actions as any, marker as text, callerName as text, piiFreeLogMessage as text) =>
Action.Sequence
    ({
        () => Action.Try(actions),
        (r) => if (r[HasError]) then
                    error Connector.GenerateErrorRecord(marker, piiFreeLogMessage, callerName, r[Error])
                else Action.Return(r[Value])
    });


Connector.GenerateErrorRecord = (marker as text, piiFreeLogMessage as text, callerName as text, errorRecord as any) =>
let
    message = errorRecord[Message]?,
    messageFormat = errorRecord[Message.Format]?,
    errorMessage = if IsNonPii(message) then message else (if IsNonPii(messageFormat) then messageFormat else null),
    finalErrorMessage = if errorMessage <> null
                then Text.Format(Extension.LoadString("TraceMessageWithDetails"), {piiFreeLogMessage, errorMessage})
                else piiFreeLogMessage,
    tracedMessage = Diagnostics.Trace(TraceLevel.Error, [Name = callerName,
                Data = [ErrorDetailMessage = errorRecord[Message], ErrorDetail = Value.ToText(errorRecord)],
                SafeData = [ErrorCode = marker, ErrorMessage = finalErrorMessage]], errorRecord[Message]),
    reason = if IsNonPii(errorRecord[Reason]?) then errorRecord[Reason]? else NonPii("DataSource.Error")
in
    Error.Record(reason,
        NonPii(Extension.LoadString("FinalErrorMessageWithDetails")),
        errorRecord,
        {NonPii(finalErrorMessage), tracedMessage});


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

// Uncomment for testing
// [DataSource.Kind="Lakehouse"]
// shared Lakehouse.RefreshMetadata = (databaseId) => RefreshMetadata(PBI.WebContents(PBIBaseUrl), [id = databaseId], true);

// TODO: Consider rewriting to use WebAction.Request instead of Web.Contents
RefreshMetadata = (baseUrl, dwProperties, delayBackgroundProcessing, targetTableName as text) =>
let
    dwId = dwProperties[id]?,
    rootUrl = Uri.Combine(baseUrl, Text.Format("/v1.0/myorg/lhdatamarts/#{0}", {dwId})),
    prefix = "MetadataRefresh/",
    startState = [Iteration = 1], // force IsRetry on all requests by claiming we start at a higher iteration

    submitCommand = (iteration) =>
    let
        handlers = MetadataRefreshResponseHandlers(false),
        delayCommand = [datamartVersion = null, commands = {[#"$type" = "DelayBackgroundProcessingCommand"]}],
        delayContext = [Origin = NonPii("RefreshMetadata/DelayBackgroundProcessing"), Iteration = NonPii(iteration)],
        delayResponse = Web.JsonContents(rootUrl, delayContext, handlers, delayCommand, startState),
        refreshCommandDetails = [#"$type" = "MetadataRefreshExternalCommand", isDatasetRefreshRequired = false],
        tableNameIsNotNullOrBlank = targetTableName <> null and Text.Length(targetTableName) > 0,
        refreshCommandWithTableName = if UseDmsTableApi and tableNameIsNotNullOrBlank
            then refreshCommandDetails & [tableNames = {targetTableName}]
            else if UseDmsTableApi then Diagnostics.Trace(TraceLevel.Warning, [Name = prefix & "SubmitCommand/FullMetadataSync/TableNameMissing", Data = [TableName = targetTableName],
                SafeData = [UseDmsTableApiFeatureSwitch = Text.From(UseDmsTableApi), TableNameIsNotNullOrBlank = Text.From(tableNameIsNotNullOrBlank)] ],
                refreshCommandDetails)
            else refreshCommandDetails,
        refreshCommand = [datamartVersion = null, commands = {refreshCommandWithTableName}],
        refreshContext = [Origin = NonPii("RefreshMetadata/MetadataRefreshSubmit"), Iteration = NonPii(iteration)],
        response = Web.JsonContents(rootUrl, refreshContext, handlers, refreshCommand, startState),
        responseStatusCode =
            if DisableDmsDelayedBackgroudProcessing = false and delayBackgroundProcessing = true and delayResponse = "unreachable" 
            then 0 else Record.FieldOrDefault(Value.Metadata(response), "Response.Status", 0),
        errorDetails = response[error]?[pbi.error]?[details]?,
        lockConflictBatchId = if errorDetails <> null then try SelectKeysFromListOfRecordsForDMS(errorDetails, {"LockingBatchId"}, false)[LockingBatchId]? otherwise null else null,
        result = [StatusCode = responseStatusCode, ErrorCode = response[error]?[code]?, BatchId = response[batchId]?, LockingBatchId = lockConflictBatchId]
    in
        Diagnostics.Trace(if responseStatusCode <> 200 then TraceLevel.Warning else TraceLevel.Information,
            [Name = prefix & "SubmitCommand", Data = [TableName = targetTableName], SafeData = result &
            [Iteration = iteration, TableNameIsNotNullOrBlank = Text.From(tableNameIsNotNullOrBlank), UseDmsTableApiFeatureSwitch = Text.From(UseDmsTableApi),
            MetadataSyncConfigurtion = Value.ToText(MetadataSyncConfig)]],
            result),

    getInProgressBatch = (iteration) =>
    let
        getBatchContext = [Origin = NonPii("RefreshMetadata/GetInProgressBatch"), Iteration = NonPii(iteration)],
        response = Web.JsonContents(rootUrl & "/batches", getBatchContext, [], null, startState),
        asTable = Table.FromRecords(response[value], {"batchId", "progressState", "startTimeStamp"}, MissingField.Error),
        changedTypeForStartTimestamp = Table.TransformColumnTypes(asTable, {{"startTimeStamp", type datetime}}), // represent as datetime
        utcTimeWithoutZone = DateTimeZone.RemoveZone(DateTimeZone.UtcNow()), // remove zone from UTC time for comparison.
        batchesInPastOneDay = Table.SelectRows(changedTypeForStartTimestamp, each [startTimeStamp] > (utcTimeWithoutZone - #duration(1,0,0,0)) and [progressState] = "inProgress"), // get inprogress batches from past 24 hours
        inProgress = Table.Sort(batchesInPastOneDay, {{"startTimeStamp", Order.Descending}})
    in
        try inProgress{0}?[batchId]? catch (e) => Diagnostics.Trace(
            TraceLevel.Error,
            [Name=prefix & "GetInProgress", Data = [], SafeData = [Exception = Value.ToText(e)]],
            null),

    getResultStatus = (result, optional originatedFromLockConflict) =>
    let
        batchStatus = result[progressState]? ?? "(null)",
        batchId = result[batchId]?,
        status = Table.FromList(
            List.Combine(List.Transform(result[operationInformation], (oi) => oi[progressDetail][tablesSyncStatus])),
            Splitter.SplitByNothing()),
        progressDetail =  if batchStatus = "success" then try Table.ExpandRecordColumn(status, "Column1", {"tableName", "error", "tableSyncState", "sqlSyncState", "lastSuccessfulUpdate", "correctiveAction"})
            catch (e) => ThrowMetadataSyncErrors(prefix & "ProgressDetail", Extension.LoadString("MetadataRefreshParseResponseError"),
                [ResponseForBatch = Value.ToText(result)], [BatchId = batchId], e,
                {NonPii(dwId), NonPii(batchId), e[Message]})
            else
                let
                    errorResult = GenerateErrorCodeAndMessageForDMSBatch(result)
                in
                    ThrowMetadataSyncErrors(prefix & "BatchStatusError", Extension.LoadString("MetadataRefreshBatchError"),
                        [ResponseForBatch = Value.ToText(result)], [BatchId = batchId, ErrorCode = errorResult[ErrorCode]], errorResult[ExceptionData] ?? result,
                        {NonPii(dwId), NonPii(batchId), NonPii(errorResult[ErrorCode]), Value.ToText(errorResult[ErrorMessage])}),

        tableDetail = Table.SelectRows(progressDetail, each [tableName] = targetTableName),
        withoutTableName = Table.RemoveColumns(tableDetail, {"tableName"}),
        failureRows = Table.SelectRows(tableDetail, each ([tableSyncState] = "Failure" or [sqlSyncState] = "Failure")),
        missingTable = targetTableName <> null and Table.IsEmpty(tableDetail),
        hasFailure = missingTable or Table.RowCount(failureRows) > 0,
        failureDetails = Table.First(failureRows)[error]?,
        correctiveAction = Table.First(failureRows)[correctiveAction]?,
        sqlFailureDetails = if LogSqlErrorCodesFromDMSResponse and failureDetails[details]? <> null then SelectKeysFromListOfRecordsForDMS(failureDetails[details]?, {"RootActivityId", "SqlErrorNumber", "SqlErrorClass", "SqlErrorState"}, true) else [],
        errorCode = if missingTable then "TableMissingInBatchFailure"
            else if correctiveAction <> null and targetTableName <> null and Text.Length(targetTableName) > 128 then "TableNameTooLongFailure"
            else "TableSyncFailure",

        dmsReportedErrorCode = Text.Format("#{0}|#{1}", {failureDetails[code]?, failureDetails[httpStatusCode]?}),
        failureStatus = if Value.Is(failureDetails, Record.Type) then [DMSReportedErrorCode = dmsReportedErrorCode] else [],
        failureDetailAsText = Value.ToText(failureDetails),
        errorMessageWithoutStackTrace = if missingTable  then errorCode else Text.BeforeDelimiter(failureDetailAsText, "callStack"), // remove stack trace so we can log and raise this to end user.

        tracedFailure = Diagnostics.Trace(TraceLevel.Error,
            [
                Name= prefix & "TableSyncFailure",
                Data =  [TableName = targetTableName, ErrorDetail = failureDetailAsText, CorrectiveAction = Value.ToText(correctiveAction)],
                SafeData = [BatchId = result[batchId]?, ErrorCode = errorCode, LakehouseId = dwId, CorrectiveActionPresent = correctiveAction <> null] & failureStatus & sqlFailureDetails
            ],  Text.Format(Extension.LoadString("TableCreationFailureError"),{errorMessageWithoutStackTrace})),
        finalResult = if (not originatedFromLockConflict and hasFailure)
                      then error Error.Record(NonPii("DataSource.Error"), NonPii(Extension.LoadString("MetadataRefreshErrorWithDetail")), failureDetails, {NonPii(dwId), NonPii(result[batchId]?), (tracedFailure)})
                      else try Text.FromBinary(Json.FromValue(withoutTableName)) otherwise "<unable to get status>"
    in
        finalResult,

    pollBatch = (batchId, optional originatedFromLockConflict) =>
    let
        pollUrl = Diagnostics.Trace(TraceLevel.Information, [Name = prefix & "PollBatch", Data = [], SafeData = [BatchId = batchId]], rootUrl & "/batches/" & batchId),
        pollCount = MetadataSyncConfig[PollingCount],
        exponentialBackoffMultiplier = MetadataSyncConfig[PollingDelayMultiplier],
        waitForResult = Value.WaitFor(
            (iteration) =>
                let
                    jsonResponse = Web.JsonContents(pollUrl, [Origin = NonPii("RefreshMetadata/PollBatch")], MetadataRefreshResponseHandlers(true), null, startState),
                    responseStatus = Value.Metadata(jsonResponse)[Response.Status]?,
                    newState = jsonResponse[progressState]? ?? "(null)",
                    finalStatus = try getResultStatus(jsonResponse, originatedFromLockConflict),
                    unableToSyncError = ThrowMetadataSyncErrors(prefix & "PollBatch/UnableToSyncTable", Extension.LoadString("MetadataRefreshUnableToSyncTable"), [TableName = targetTableName],
                        [PollingIterationCount = iteration, PolledBatchId = batchId], [BatchId = batchId, LakehouseId = dwId], {NonPii(dwId), NonPii(batchId)})
                in
                    if iteration >= pollCount then
                        if UseDmsTableApi and originatedFromLockConflict = false
                                then unableToSyncError
                            else Diagnostics.Trace(TraceLevel.Warning,
                            [
                                Name = prefix & "PollBatch/MaxRetriesExceeded",
                                Data = [TableName = targetTableName],
                                SafeData = [PollingIterationCount = iteration, PolledBatchId = batchId, LakehouseId = dwId]
                            ],
                            null)
                    else if responseStatus = 500 or newState = "inProgress"
                        then null
                    else if finalStatus[HasError]
                        then error finalStatus[Error]
                    else Diagnostics.Trace(TraceLevel.Information,
                        [
                            Name=prefix & "Poll",
                            Data=[
                                TableName = targetTableName
                            ],
                            SafeData=[
                                BatchState = newState,
                                BatchStatus = finalStatus[Value],
                                IterationCount = iteration,
                                BatchId = batchId
                            ]
                        ],
                        newState),
            (iteration) => #duration(0, 0, 0, Number.Power(exponentialBackoffMultiplier, iteration + 1)-1),
            pollCount)
    in
        waitForResult,

    // When we submit a request to refresh metadata, there may already be a metadata refresh
    // underway. If so, we get a LockConflict error. We then get the batchId for the in-progress refresh
    // and we poll for that refresh to finish. Once it's done, we try to submit another metadata
    // refresh request. If this, too, fails with a LockConflict then we again wait for the in-progress
    // refresh to be finished. Once that's done, we stop because our change should have been picked up
    // by the second refresh cycle.

    // Based on evidence in telemetry, if there's no "in-progress" operation, we'll try the metadata
    // refresh again without increasing the iteration.

    // The comparison of newState to "expected not to match" is to force evaluation of newState before
    // we try to submit a second refresh request.

    // DMS has published a new TableLevel API this means when doing metadata sync in case of lock conflicts we
    // need to try harder to get a lock so we can ensure the table is synced. For this reason we need to increase
    // the max number of tries to a larger value, currently set at 5
    // We will also poll a lower number of times as this is expected to be a faster operation.

    Submit = (iteration, optional originatedFromLockConflict) => let result = submitCommand(iteration) in
        if result[BatchId]? <> null then pollBatch(result[BatchId], originatedFromLockConflict)
        else if result[ErrorCode]? = "LockConflictException" or result[ErrorCode]? = "LockConflict" then LockConflict(iteration, result[LockingBatchId]?)
        else error Error.Record(NonPii("DataSource.Error"), NonPii(Text.Format(Extension.LoadString("MetadataRefreshError"), {result[ErrorCode], result[StatusCode]})), ""),

    // 1. Since we encountered a lock conflict, check for any ongoing batch and poll it to completion
    //    As this batch might not be the one associated with the current request, the 'originatedFromLockConflict' flag
    //    true suggests that if the specific table isn't found, no error is thrown in getResultStatus.

    // 2. After this completes, we attempt to submit our request again, expecting to get our
    //    own batch this time, set originatedFromLockConflict = false indicating that the request
    //    isn't being made as a result of resolving a lock conflict.

    // 3. If no ongoing batches are found after a lock conflict, a brief wait is introduced before trying
    //    to submit the request again, with 'originatedFromLockConflict' set to false as we expect this
    //    attempt to be our own batch.

    LockConflict = (iteration, lockConflictBatchId) =>
        let
            maxIterationsForLockConflict = MetadataSyncConfig[MaxIterationCount] - 1,
            maxIterationsForNothingInProgress = MetadataSyncConfig[NothingInProgressIterationCount] - 1,
            inProgressBatchId = if lockConflictBatchId = null then getInProgressBatch(iteration) else lockConflictBatchId,
            newState = pollBatch(inProgressBatchId, true),
            nextIteration = Submit(iteration + 1, false),
            // Retry recursive and cross fingers.
            // We increment iteration to avoid infinite recursion and stack overflow.
            //
            nothingInProgress =
                Function.InvokeAfter(() => Submit(iteration + 1, false), Diagnostics.Trace(TraceLevel.Information, [Name = prefix & "LockConflict/NothingInProgress/Retry",
                Data = [], SafeData = [Iteration = iteration, NothingInProgressIterationCount = maxIterationsForNothingInProgress]], #duration(0, 0, 0, 5))),

            nothingInProgressError = ThrowMetadataSyncErrors(prefix & "LockConflict/NothingInProgress", Extension.LoadString("MetadataRefreshNothingInProgress"), [TableName = targetTableName],
                [IterationCount = iteration, lakhouseId = dwId], [TableName = targetTableName, LakehouseId = dwId], {NonPii(dwId), targetTableName}),

            unableToSyncError = ThrowMetadataSyncErrors(prefix & "LockConflict/UnableToSyncTable", Extension.LoadString("MetadataRefreshUnableToSyncTable"), [TableName = targetTableName],
                [IterationCount = iteration, PolledBatchId = inProgressBatchId], [BatchId = inProgressBatchId, LakehouseId = dwId], {NonPii(dwId), NonPii(inProgressBatchId)})
        in
            // Guard against infinite recursion.
            if inProgressBatchId = null then if iteration > maxIterationsForNothingInProgress then nothingInProgressError else nothingInProgress
            else let newState = pollBatch(inProgressBatchId, true) in
                if newState = "expected not to match" or iteration > maxIterationsForLockConflict then
                    if UseDmsTableApi then unableToSyncError else newState
                else nextIteration

in
    if dwId = null then "N/A" else Submit(0, false);

SelectKeysFromListOfRecordsForDMS = (details, keys, isTableSyncFailure as logical) =>
    Record.SelectFields(Record.Combine(List.Transform(details, (val) => Record.AddField([],val[code],if isTableSyncFailure then val[message] else val[detail]?[value]))), keys, MissingField.Ignore);

GenerateErrorCodeAndMessageForDMSBatch = (result) =>
let
    hasExceptionData = Record.HasFields(result, "exceptionData"),
    hasErrorData = Record.HasFields(result, "errorData"),
    exceptionData = result[exceptionData]? ?? result[errorData]?,
    errorMessage = if exceptionData <> null then Value.ToText(exceptionData) else Value.ToText(result),
    errorCode = if hasExceptionData then exceptionData[code]? else if hasErrorData then exceptionData[error]?[code]? else "UnkownError"
in
    [ErrorCode = errorCode, ErrorMessage = errorMessage, ExceptionData = exceptionData];

ThrowMetadataSyncErrors = (logName, errorMessage, data, safedata, errorRecord, variableListForError) =>
error Diagnostics.Trace(TraceLevel.Error, [Name = logName, Data = data, SafeData = safedata],
    Error.Record(
    NonPii("DataSource.Error"),
    NonPii(errorMessage),
    errorRecord,
    variableListForError));

UniqueRequestHeader = "x-ms-client-request-id";
PrivateLinkCapacityHeader = "x-ms-src-capacity-id";

PBICommonHeaderNames = {
    UniqueRequestHeader,
    "x-ms-client-session-id",
    "RequestId",
    "ActivityId"
};

PBICommonHeaders = () =>
    let
        activityId = Diagnostics.ActivityId(),
        requestId = Text.NewGuid()
    in
        Record.FromList({requestId, activityId, requestId, activityId}, PBICommonHeaderNames);

PBI.WebContents = (baseUrl as text) as text =>
    let
        // Cluster avaliability issue may affect the globalservice call resulting is sporadic 500 response returned to the caller
        // It is not possible to change the status code which is returned to 504 as it will be a breaking change
        // therefore all the clients were instructed to retry this call on 500
        maxRetryCount = 5,
        props = (Extension.CurrentCredential()[Properties]? ?? []) & Extension.CurrentApplication(),
        serviceEndpoint = Value.IfNull(props[PBIEndpointUrl]?, baseUrl),
        uriEnd = if UseNewClusterAPI then "/metadata/cluster" else "/powerbi/globalservice/v201606/clusterdetails",
        disco = Uri.Combine(serviceEndpoint, uriEnd),
        response = Web.JsonContents(disco, [Origin = NonPii("PBI.WebContents")], [500 = RetryHandler(maxRetryCount)]),
        clusterUrlViaRequest = if UseNewClusterAPI then response[backendUrl] else response[clusterUrl],
        _clusterUrl = props[PBI_ClusterUrl]? ?? clusterUrlViaRequest,
        clusterUrl = Diagnostics.Trace(TraceLevel.Information, [
                Name = "PBI.WebContents",
                Data = [],
                SafeData = [ ServiceEndpoint = serviceEndpoint, PBI_ClusterUrl = props[PBI_ClusterUrl]? ]
            ],
            _clusterUrl)
    in
        clusterUrl;

PBIRequestHeaders = () as record =>
    let
        capacityId = Extension.CurrentApplication()[PBI_CapacityObjectId]?,
        serviceAccessToken = Extension.CurrentCredential()[Properties]?[ServiceAccessToken]?,
        capacityHeaders = if capacityId <> null then [#"x-ms-caller-capacity-id" = capacityId, #"x-ms-src-capacity-id" = capacityId] else [],
        s2sTokenHeaders = if serviceAccessToken <> null then [#"x-ms-s2s-actor-authorization" = serviceAccessToken] else []
    in
        PBICommonHeaders() & capacityHeaders & s2sTokenHeaders;

// -----------------------------------------------------
// | 2. OneLake Storage (which is adls storage)
// -----------------------------------------------------

GetServiceToken = (resource) =>
    let
        currentCredentials = Extension.CurrentCredential(),
        trimmedResource = Text.TrimEnd(resource, "/"),
        prop = "ServiceAccessToken:" & trimmedResource,
        propWithSlash = "ServiceAccessToken:" & trimmedResource & "/",
        tokenValue = Record.FieldOrDefault(currentCredentials[Properties], prop, Record.FieldOrDefault(currentCredentials[Properties], propWithSlash, null))
    in
        tokenValue;

OneLake.Contents = (entityUrl as text) =>
    Extension.InvokeWithCredentials(
        (datasource) =>
            let
                baseCredential = GetCredential(AadAdlsStorageResource),
                capacityId = Extension.CurrentApplication()[PBI_CapacityObjectId]?,
                s2sToken = GetServiceToken(AadAdlsStorageResource),
                plCredential = if capacityId <> null and s2sToken <> null
                    then [CapacityId = capacityId, ServiceAccessToken = s2sToken]
                    else []
            in
                baseCredential & plCredential,
        () => AzureStorage.DataLake(entityUrl, [HierarchicalNavigation=true]));

// -----------------------------------------------------
// | 3. TDS Endpoint using SQL Connector
// -----------------------------------------------------

Sql.Contents = (serverInstance as text, dbname as text, options as record) =>
    Extension.InvokeWithCredentials(
        (datasource) => GetCredential(AadSqlResource),
        () =>
            let
                curatedOptions = Record.SelectFields(options, {"CommandTimeout", "CreateNavigationProperties"}, MissingField.Ignore)
            in
                Sql.Database(serverInstance, dbname, [EnableCrossDatabaseFolding = true] & curatedOptions)
    );

Sql.TestConnection = (database as nullable record, lakehouseId as nullable text) =>
    Extension.InvokeWithCredentials(
        (datasource) => GetCredential(AadSqlResource),
        () =>
            let
                serverInstance = database[tdsEndpoint]?,
                dbname = database[name]?,
                ErrorMessageFormat = Extension.LoadString("NoSqlEndPoint"),
                result = if (serverInstance <> null) then DataSource.TestConnection(Sql.Database(serverInstance, dbname)) else
                    error Error.Record(NonPii("DataSource.Error"), NonPii(ErrorMessageFormat), [])
            in
                try result catch (e) => error Diagnostics.Trace(TraceLevel.Error, [
                        Name = "SqlTestConnectionFailure",
                        Data = [ Exception = Value.ToText(e) ],
                        SafeData = [ LakehouseId = lakehouseId ]
                    ], e)
    );

// -----------------------------------------------------
// | 4. Utility
// -----------------------------------------------------

GetCredential = (resource) =>
    let
        currentCredentials = Extension.CurrentCredential(),
        trimmedResource = Text.TrimEnd(resource, "/"),
        prop = "AccessToken:" & trimmedResource,
        propWithSlash = "AccessToken:" & trimmedResource & "/",
        tokenValue = Record.FieldOrDefault(currentCredentials[Properties], prop, Record.FieldOrDefault(currentCredentials[Properties], propWithSlash, "")),
        finalTokenValue = if tokenValue = "" then Diagnostics.Trace(TraceLevel.Error, [Name = "GetCredential/CredentialPropertyNotFound", Data = [], SafeData = [CredentialProperty = Text.Combine({prop, propWithSlash}, ",")]], currentCredentials[access_token]) else tokenValue,
        credentialToReturn = currentCredentials & [access_token = finalTokenValue]
    in
        credentialToReturn;

Utility.CreateScope = () as text =>
    let
        appendix = "user_impersonation",
        scopeForStorage = Text.Format("#{1}/#{0}", {appendix, AadAdlsStorageResource}),
        scopeForSql = Text.Format("#{1}/#{0}", {appendix, AadSqlResource}),
        scopeForWorkspaces = Text.Format("#{1}/#{0}", {appendix, AadWorkspaceApiOAuthResource}),
        result = Text.Combine({scopeForWorkspaces, scopeForSql, scopeForStorage}, " ")
    in
        result;

Value.IfNull = (a, b) =>
    if a <> null then a
        else b;

Text.IsNotNullOrEmpty = (a) =>
    a <> null and Text.Trim(a) <> "";

Value.ConvertToLogical = (a) =>
    a <> null and a <> "" and Logical.From(a);

// TODO: Figure out a way to make this work with bindings, probably leveraging Action.View
WithAfterAction = (table, afterAction) => Table.View(table, [
    OnInvoke = (function, args, index) =>
        if (function = Value.Versions) then PostPublishAction(Value.Versions(table))
        else ...,
    OnSelectRows = (condition) => @WithAfterAction(Table.SelectRows(table, condition), afterAction),
    OnInsertRows = (rowsToInsert) => Action.Sequence({TableAction.InsertRows(table, rowsToInsert), afterAction}),
    OnUpdateRows = (updates, selector) => Action.Sequence({
        TableAction.UpdateRows(Table.SelectRows(table, selector), List.Transform(updates, each {[Name], [Function]})),
        afterAction
    }),
    OnDeleteRows = (selector) => Action.Sequence({TableAction.DeleteRows(Table.SelectRows(table, selector)), afterAction}),

    PostPublishAction = (versions) => Table.View(versions, [
        // TODO: look specifically for a Publish action
        OnUpdateRows = (updates, selector) => Action.Sequence({
            TableAction.UpdateRows(Table.SelectRows(versions, selector), List.Transform(updates, each {[Name], [Function]})),
            afterAction
        })
    ])
]);

Value.WaitFor = (producer as function, delay as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, null},
            (state) => state{0} <> null and (count = null or state{0} <= (count + 1)), //first row is {0, null} and doesn't invoke the producer.
            (state) => if state{1} <> null
                then {null, state{1}}
                else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), delay(state{0}))},
            (state) => state{1}),
        result = List.Last(list)
    in
        result;

Web.JsonContents = (url as text, context as record, optional additionalHandlers as record, optional jsonBody as any, optional startState as record) =>
    let
        moreHeaders = if jsonBody = null then [] else [#"Content-Type" = "application/json;charset=UTF-8"],
        content = if jsonBody = null then null else Json.FromValue(jsonBody)
    in
        Http.Request(
            url,
            [
                Headers = PBIRequestHeaders() & moreHeaders,
                ExcludedFromCacheKey = PBICommonHeaderNames,
                Content=content,
                SafeRequestHeaders = PBICommonHeaderNames & {PrivateLinkCapacityHeader},
                SafeResponseHeaders = {"RequestId"}, // OLS RAID returned in RequestId
                TraceData = context & [RequestUrl = NonPii(url)]
            ],
            DefaultHandlers & [200 = JsonHandler] & (additionalHandlers ?? []),
            startState);

Web.ErrorResponse = (state as record) =>
    let
        url = state[Url],
        status = state[Status],
        result = try
        let
            jsonResponse = Json.Document(state[Response]) meta Value.Metadata(state[Response]),
            responseStatusCode = Record.FieldOrDefault(Value.Metadata(jsonResponse), "Response.Status", 0),
            requestId = Record.FieldOrDefault(Value.Metadata(jsonResponse)[Headers], "RequestId", ""),
            errorCode = jsonResponse[error][code],
            errorMessage = jsonResponse[error][message]? ?? jsonResponse[error][pbi.error][parameters][ErrorMessage]? ?? errorCode,
            errorDetails = try if List.IsEmpty(jsonResponse[error][pbi.error][details]) then errorMessage
                else Text.Combine(jsonResponse[error][pbi.error][details], " ") otherwise Value.ToText(jsonResponse[error]),
            errorRecord =
                Error.Record(
                    NonPii("DataSource.Error"),
                    NonPii(Extension.LoadString("DownstreamServiceCallFailureWithErrorCode")),
                    [
                        Error = errorDetails,
                        ErrorCode = errorCode,
                        #"RequestId" = requestId,
                        #"RequestUrl" = url,
                        ErrorMessage = errorMessage
                    ],
                    {NonPii(url), NonPii(status), NonPii(errorCode)}
                )
        in
            errorRecord,
        jsonResponseText = try Text.FromBinary(state[Response]) otherwise "<encoding error>",
        errorMessageToLog = if result[HasError] then Text.Format(Extension.LoadString("ErrorParsingJsonInHttpResponse"), {jsonResponseText})
            else result[Value][Message],
        finalResult = Diagnostics.Trace(TraceLevel.Warning, [
                Name = "LakehouseWebError",
                Data = [ Error = errorMessageToLog ],
                SafeData = [ Url = url, StatusCode = status ]
            ],
            if result[HasError] then Error.Record(
                NonPii("DataSource.Error"),
                NonPii(Extension.LoadString("DownstreamServiceCallFailure")),
                [
                    #"RequestUrl" = url,
                    ErrorMessage = jsonResponseText
                ],
                {NonPii(url), NonPii(status)})
            else result[Value])
    in
        error finalResult;

DefaultHandlers = [
    302 = DefaultErrorHandler,
    400 = DefaultErrorHandler,
    403 = AuthHandler,
    404 = DefaultErrorHandler,
    500 = DefaultErrorHandler,
    503 = DefaultErrorHandler,
    Error = RequestFailureHandler
];

MetadataRefreshResponseHandlers = (retryOn400 as logical) as record =>
    let
        metadataDelayFn = (iteration) => iteration * 5
    in [
        400 = if retryOn400 then RetryHandler(4, metadataDelayFn) else JsonHandler,
        403 = ErrorOrRefreshTokenHandler,
        500 = RetryHandler(4, metadataDelayFn),
        503 = RetryHandler(4, metadataDelayFn)
    ];

ErrorOrRefreshTokenHandler = (state) =>
    let
        result = try DefaultErrorHandler(state),
        errorCode = result[Error]?[Detail]?[ErrorCode]? ?? ""
    in
        if errorCode = "TokenExpired" then AuthHandler(state) else error result[Error];

DefaultErrorHandler = (state) => Web.ErrorResponse(state);

AuthHandler = (state) =>
    if state[Refreshed]? = true or not Web.TryRefreshToken() then DefaultErrorHandler(state)
    else state & [Refreshed = true];

RetryHandler = (count, optional delayFunction) =>
    let delay = delayFunction ?? ((i) => i * 0.2) in
    (state) =>
        if state[Iteration] < count then Function.InvokeAfter(() => state, #duration(0, 0, 0, delay(state[Iteration])))
        else DefaultErrorHandler(state);

JsonHandler = (state) => state & [
    Response = Json.Document(state[Response]) meta Value.Metadata(state[Response]),
    Complete = true
];

RequestFailureHandler = (exception, url, headers) =>
error Error.Record(NonPii("DataSource.Error"),
    NonPii(Extension.LoadString("DownstreamServiceCallError")),
    [
        ActualError = exception,
        RequestHeaders = Record.SelectFields(headers[Headers]?, PBICommonHeaderNames)
    ],
    {NonPii(url), exception[Reason]?, exception[Message]?});

Http.Request = (url as text, options as record, handlers as record, optional startState as record) =>
    let
        errorHandler = handlers[Error]?,
        handledStatuses = List.Buffer(List.Transform(Record.FieldNames(Record.RemoveFields(handlers, "Error")), Number.From)),
        moreOptions = options & [ManualStatusHandling = handledStatuses],
        list = List.Generate(
            () => [Iteration = 0, Url = url, Response = null, Complete = false, Return = false] & (startState ?? []),
            (state) => not state[Return],
            (state) => if state[Complete] then state & [Return = true] else
                let
                    response = Web.Contents(url, moreOptions & [IsRetry = state[Iteration] > 0]),
                    responseStatus = Value.Metadata(response)[Response.Status]? ?? 200,
                    status = if errorHandler = null then responseStatus
                             else try responseStatus catch(e) => errorHandler(e, url, options),
                    handler = Record.FieldOrDefault(handlers, Text.From(status, "")),
                    partial = state & [Iteration = state[Iteration] + 1, Response = response, Complete = false, Status = status],
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

Lakehouse = [
    Type = "Custom",
    MakeResourcePath = (optional options) => if (options[IsModelStorage]? = true) then "LakehouseModelStorage" else "Lakehouse",
    ParseResourcePath = (resource) => { },
    Authentication = [
        Aad = [
            AuthorizationUri = AadAuthorizationUri,
            Resource = "",
            Scope = Utility.CreateScope(),
            DefaultClientApplication = [
                ClientId = "a672d62c-fc7b-4e81-a576-e60dc46e951d",
                ClientSecret = "",
                CallbackUrl = AadRedirectUrl
            ]
        ]
    ],
    ApplicationProperties = [
        PBIEndpointUrl = [PropertyType = Text.Type, IsRequired = false],
        PBI_CapacityObjectId = [PropertyType = Text.Type, IsRequired = false],
        PBI_ClusterUrl = [PropertyType = Text.Type, IsRequired = false]
    ],
    Label = Extension.LoadString("DataSourceLabel"),

     // valid DSRs
/*
{"protocol":"lakehouse","address":{"workspace":null,"lakehouse":null}}
{"protocol":"lakehouse","address":{"workspace":"685d9cf0-e359-48b3-983b-3c4babc37af6","lakehouse":null}}
{"protocol":"lakehouse","address":{"workspace":"685d9cf0-e359-48b3-983b-3c4babc37af6","lakehouse":"12345678-e359-48b3-983b-3c4babc37af5"}}
{"protocol":"lakehouse","address":{"workspace":"685d9cf0-e359-48b3-983b-3c4babc37af6","lakehouse":"12345678-e359-48b3-983b-3c4babc37af5", "table" : "NewTable"}}
*/
    DSRHandlers = [
        #"lakehouse" = [
            GetDSR = (optional options, optional navigation) =>
                let
                    workspace = navigation{0}?[workspaceId]?,
                    lakehouse = navigation{2}?[lakehouseId]?,
                    id = navigation{4}?[Id]?,
                    itemKind = navigation{4}?[ItemKind]?,
                    count = List.Count(navigation),
                    matchLakehouseWithId = List.FirstN({[workspaceId=workspace], "Data", [lakehouseId=lakehouse], "Data", [Id=id, ItemKind = itemKind], "Data"}, count),
                    isMatchValidLakehouseNavigation = List.FirstN(matchLakehouseWithId, count) = navigation,
                    isTableOrFileOrNull = itemKind = null or (itemKind <> null and (itemKind = "Table")),
                    isValid = Number.IsEven(count) and isMatchValidLakehouseNavigation and isTableOrFileOrNull,
                    address = if navigation = null then []
                        else if not isValid then ...
                        else Record.RenameFields(Record.Combine(List.RemoveItems(matchLakehouseWithId, {"Data"})), {{"workspaceId", "workspace"}, {"lakehouseId", "lakehouse"}, {"Id", "table"}}, MissingField.UseNull),
                    addressWithoutItemKind = if itemKind <> null then Record.RemoveFields(address, {"ItemKind"}) else address
                in
                    if (options[IsModelStorage]? = true) then ... else [ protocol = "lakehouse", address = addressWithoutItemKind],
            GetFormula = (dsr, optional options) =>
                let
                    address = ValidateAddressRecord(dsr[address]),
                    workspace = Record.FieldOrDefault(address, "workspace", null),
                    lakehouse = Record.FieldOrDefault(address, "lakehouse", null),
                    tableId = Record.FieldOrDefault(address, "table", null)
                in
                        if (workspace <> null) then
                            if (lakehouse <> null) then
                                if(tableId <> null) then
                                    () => Lakehouse.Contents(options){[workspaceId=workspace]}[Data]{[lakehouseId=lakehouse]}[Data]{[Id=tableId]}[Data]
                                else
                                    () => Lakehouse.Contents(options){[workspaceId=workspace]}[Data]{[lakehouseId=lakehouse]}[Data]
                            else
                                () => Lakehouse.Contents(options){[workspaceId=workspace]}[Data]
                        else
                            () => Lakehouse.Contents(options),

            GetFriendlyName = (dsr) => "Lakehouse"
        ]
    ]
];

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
            workspace = Guid.Type,
            lakehouse = Guid.Type,
            table = Text.Type
        ])
    in
        validated;

NameIsValid = (inputText as text) as logical =>
    let
        // foreach char in inputText, if char not in validCharacters then invalid else valid
        validCharacters = {"A".."Z","a".."z","0".."9","_"},
        invalidList = List.Difference(List.Distinct(Text.ToList(inputText)), validCharacters),
        isValid = List.IsEmpty(invalidList)
    in
        if IgnoreTableNameValidation then true else isValid;

AllValueEqualsToNull = (equalityComparers) =>
    if (List.IsEmpty(List.Select(equalityComparers, each _ <> Value.Equals))) then null
    else equalityComparers;

ReduceAnd = (ast) => if ast[Kind] = "Binary" and ast[Operator] = "And" then List.Combine({@ReduceAnd(ast[Left]), @ReduceAnd(ast[Right])}) else {ast};
MatchFieldAccess = (ast) => if ast[Kind] = "FieldAccess" and ast[Expression] = RowExpression.Row then ast[MemberName] else ...;
MatchConstant = (ast) => if ast[Kind] = "Constant" then ast[Value] else ...;
MatchIndex = (ast) => if ast[Kind] = "Binary" and ast[Operator] = "Equals"
    then
        if ast[Left][Kind] = "FieldAccess"
            then Record.AddField([], MatchFieldAccess(ast[Left]), MatchConstant(ast[Right]))
            else Record.AddField([], MatchFieldAccess(ast[Right]), MatchConstant(ast[Left]))
    else ...;
GetIndex = (selector, keys) => Record.SelectFields(Record.Combine(List.Transform(ReduceAnd(RowExpression.From(selector)), MatchIndex)), keys);


Handlers = (fn) => [
    GetExpression = () => fn("GetExpression", (table) => Value.Expression(Value.Optimize(table))),
    GetRows = () => fn("GetRows", (table) => table),
    GetRowCount = () => fn("GetRowCount", (table) => 5),
    GetType = () => fn("GetType", (table) => Value.Type(table)),

    OnAddColumns = (constructors) => fn("OnAddColumns", (table) => List.Accumulate(
        constructors,
        table,
        (state, item) => Table.AddColumn(state, item[Name], item[Function], item[Type]))),
    OnCombine = (tables, index) => fn("OnCombine", (table) => Table.Combine(List.ReplaceRange(tables, index, 1, {table}))),
    OnDistinct = (columns) => fn("OnDistinct", (table) => Table.Distinct(table, columns)),
    OnGroup = (keys, aggregates) => fn("OnGroup", (table) => Table.Group(table, keys, List.Transform(aggregates, each {[Name], [Function], [Type]}))),
    OnInvoke = (function, arguments, index) => fn("OnInvoke", (table) => Function.Invoke(function, List.ReplaceRange(arguments, index, 1, {table}))),
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
    OnTestConnection = () => fn("OnTestConnection", (table) => DataSource.TestConnection(table))
];

// Data Source UI publishing description
Lakehouse.Publish = [
    Name = "Lakehouse",
    SupportsDirectQuery = true,
    Category = "Fabric",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    SourceImage = Lakehouse.Icons,
    SourceTypeImage = Lakehouse.Icons
];

Lakehouse.Icons = [
    Icon16 = { Extension.Contents("Lakehouse16.png"), Extension.Contents("Lakehouse20.png"), Extension.Contents("Lakehouse24.png"), Extension.Contents("Lakehouse32.png") },
    Icon32 = { Extension.Contents("Lakehouse32.png"), Extension.Contents("Lakehouse40.png"), Extension.Contents("Lakehouse48.png"), Extension.Contents("Lakehouse64.png") }
];

// Extension library functions
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Table.ToNavigationTable = try Extension.LoadFunction("Table.ToNavigationTable.pqm") otherwise error "Emodule not loaded";
Table.NavigationTableView = try Extension.LoadFunction("Table.NavigationTableView.pqm") otherwise error "Emodule not loaded";
DeltaLake.Table =  try #shared[DeltaLake.Table] otherwise (binary, optional options) => error Error.Record("DataSource.Error", Extension.LoadString("DeltaModuleNotSupported"));
Web.Contents = try #shared[Web.Contents] otherwise (url, optional options) => error Error.Record("DataSource.Error", "system error");
AzureStorage.DataLake = try #shared[AzureStorage.DataLake] otherwise (url, optional options) => error Error.Record("DataSource.Error", "system error");
Sql.Database = try #shared[Sql.Database] otherwise (server, database, optional options) => error Error.Record("DataSource.Error", "system error");
