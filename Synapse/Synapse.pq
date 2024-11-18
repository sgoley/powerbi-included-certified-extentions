[Version = "1.0.4"]
section Synapse;

AzureResourceManagerUri = "https://management.azure.com";
AzureResourceManagerResource = "https://management.azure.com";
SynapseGatewayResource = "https://dev.azuresynapse.net";
SynapseSQLDatabaseResource = "https://sql.azuresynapse.net";

[DataSource.Kind="Synapse", Publish="Synapse.Publish"]
shared Synapse.Contents = Value.ReplaceType((optional options as record) as table =>
    CreateNavForWorkspaces(), 
    SynapseType);

SynapseType = type function (
    optional option as record)
    as table meta [
        Documentation.Name = Extension.LoadString("ButtonTitle"),
        Documentation.Caption = Extension.LoadString("ButtonTitle"),
        Documentation.LongDescription = Extension.LoadString("LongDescription"),
        Documentation.Examples = {}
    ];


// UI builders
Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    displayNameColumn as text,
    descriptionColumn as text,
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
            NavigationTable.DisplayNameColumn = displayNameColumn,
            NavigationTable.DescriptionColumn = descriptionColumn,
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

CreateNavForWorkspaces = () as table =>
    let
        workspaces = GetWorkspaces(),
        toTable = Table.FromValue(workspaces),
        addName = Table.AddColumn(toTable, "Name", each [Value][name], type text),
        addData = Table.AddColumn(addName, "Data", each CreateNavForDatabases([Value]), type table),
        removeValue = Table.RemoveColumns(addData, {"Value"}),
        withItemKind = Table.AddColumn(removeValue, "ItemKind", each "Folder", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Folder", type text),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false, type logical),
        navTable = Table.ToNavigationTable(withIsLeaf, {"Name"}, "Name", "Name", "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

CreateNavForWorkspace = (workspaceName as text) as table =>
    let
        workspace = GetWorkspaceByName(workspaceName)
    in
        CreateNavForDatabases(workspace);

CreateNavForDatabases = (workspace as record) as table =>
    let
        databases = GetDatabases(workspace),
        toTable = Table.FromValue(databases),
        addName = Table.AddColumn(toTable, "Name", each [Value][name], type text),
        addData = Table.AddColumn(addName, "Data", each CreateNavForTables([Value]), type table),
        addDisplayName = Table.AddColumn(addData, "DisplayName", each GetEntityDisplayName([Value]), type text),
        addDescription = Table.AddColumn(addDisplayName, "Description", each GetEntityDescription([Value]), type text),
        removeValue = Table.RemoveColumns(addDescription, {"Value"}),
        withItemKind = Table.AddColumn(removeValue, "ItemKind", each "Database", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Database", type text),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false, type logical),
        navTable = Table.ToNavigationTable(withIsLeaf, {"Name"}, "Name", "DisplayName", "Description", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

CreateNavForTables = (database as record) as table =>
    let
        splittedIdParts = Text.Split(database[id], "/"),
        workspaceName = splittedIdParts{8},
        server = if (database[type] = "DATABASE") then workspaceName & "-ondemand.sql.azuresynapse.net"
                 else workspaceName & ".sql.azuresynapse.net",
        databaseName = database[name],

        tables = GetSynapseDatabase(server, databaseName),

        // combine metadata with SyMS tables
        tableMetadata = GetSyMSDatabaseTables(workspaceName, databaseName),
        combinedTables = CombineTableMetadata(tables, tableMetadata),

        // add relationships to SyMS tables
        relationships = GetSyMSDatabaseRelationships(workspaceName, databaseName),
        entities = Table.AddColumn(combinedTables, "Entity", each [Name], type text),
        withRelationships = ProcessRelationships(entities, workspaceName, databaseName, relationships),
        selectColumns = Table.SelectColumns(withRelationships, {"Name", "Data", "DisplayName", "Description", "Schema", "Item"}),
        withItemKind = Table.AddColumn(selectColumns, "ItemKind", each "Table", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table", type text),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true, type logical),
        navTable = Table.ToNavigationTable(withIsLeaf, {"Schema", "Item"}, "Name", "Name", "Description", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        if (database[type] = "DATABASE" and database[properties][Origin][Type] = "SPARK") then
            navTable
        else
            tables;

GetEntityDisplayName = (entity as record) =>
    let
        displayName = entity[properties]?[DisplayName]?
    in
        if (displayName <> null and displayName <> "") then displayName else entity[name];

GetEntityDescription = (entity as record) =>
    let
        _description = entity[properties]?[Description]?,
        description = if (_description <> null and _description <> "") then _description else entity[name],
        _type = if (entity[type] = "Microsoft.Synapse/workspaces/sqlPools") then "Dedicated SQL"
                else if (entity[type] = "DATABASE") then
                    if (entity[properties][Origin][Type] = "SPARK") then "Spark"
                    else if (entity[properties][Origin][Type] = "SQLOD") then "Serverless SQL"
                    else entity[properties][Origin][Type]
                else "Unknown",
        withType = Text.Format("#{0} (#{1})", {description, _type})
    in
        withType;

CombineTableMetadata = (tables as table, tableMetadata as list) as table =>
    let
        toTable = Table.FromRecords(tableMetadata, {"name", "properties"}),
        addDisplayName = Table.AddColumn(toTable, "DisplayName", each [properties][Properties]?[DisplayName]?, type text),
        addDescription = Table.AddColumn(addDisplayName, "Description", each [properties][Properties]?[Description]?, type text),
        replaceNulls = Table.ReplaceValue(addDescription, null, each [name], Replacer.ReplaceValue, {"DisplayName", "Description"}),
        joinedTable = Table.Join(tables, "Name", replaceNulls, "name", JoinKind.LeftOuter),
        // update each table with column metadata
        updateWithMeta = Table.AddColumn(joinedTable, "DataUpdated", each CombineColumnMetadata([Data], [properties][StorageDescriptor][Columns])),
        replaceDataTable = Table.RenameColumns(Table.RemoveColumns(updateWithMeta, {"Data"}), {{"DataUpdated", "Data"}})
    in
        replaceDataTable;

CombineColumnMetadata = (columns as table, columnMetadata as list) as table =>
    let
        updateType = List.Accumulate(
            columnMetadata,
            columns,
            // if original datatype is boolean, force the column datatype to logical.
            // currently spark databases with *CSV storage* return boolean columns as text type.
            (state, current) =>
                if (current[OriginDataTypeName][TypeName] = "boolean")
                then Table.TransformColumnTypes(state, {current[Name], type logical}) else state)

    in
        updateType;

// Relationship handlers
ProcessRelationships = (entities as table, identity as text, databaseName as text, relationships as nullable list) as table =>
    let
        // format the relationships table
        relationshipTable = FormatRelationships(relationships),

        // set relationship identity for each entity - this value needs to be globally unique.
        withIdentity = Table.AddColumn(entities, "DataWithId",
                           each Table.ReplaceRelationshipIdentity([Data], Text.Format("#{0}/#{1}/#{2}", {identity, databaseName, [Entity]})),
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
        selectedFields = List.Transform(relationships, each Record.SelectFields(_, {"properties"})),
        relationshipsTable = Table.FromRecords(selectedFields),
        expandEntity = Table.ExpandRecordColumn(relationshipsTable, "properties", {"FromTableName", "ToTableName", "ColumnRelationshipInformations"}, {"fromEntity", "toEntity", "ColumnInfos"}),
        expandAttribute = Table.ExpandRecordColumn(
            Table.ExpandListColumn(expandEntity, "ColumnInfos"),
            "ColumnInfos", {"FromColumnName", "ToColumnName"}, {"fromAttributeName", "toAttributeName"}),
        calcFrom = Table.AddColumn(expandAttribute, "fromAttributes", each {[fromAttributeName]}, type { text }),
        calcTo = Table.AddColumn(calcFrom, "toAttributes", each {[toAttributeName]}, type { text }),
        finalTable = Table.SelectColumns(calcTo, {"fromEntity", "fromAttributes", "toEntity", "toAttributes"})
    in
        finalTable;

ApplyRelationships = (entity as record, entites as table, relationshipTable as table) as table =>
    let
        // filter down to the relationships for the current entity
        relationships = Table.ToRecords(Table.SelectRows(relationshipTable, each _[fromEntity] = entity[Entity])),
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
        toEntityName = currentRelationship[toEntity],
        toEntityRow = entities{[Entity=toEntityName]}?,
        joinedTable = Utility.JoinTables(fromEntityData, toEntityRow[DataWithId], currentRelationship[fromAttributes], currentRelationship[toAttributes], toEntityName),

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


// API helpers
GetWorkspaces = () as list =>
    let
        content = "{""query"": ""resources |where type =~ 'microsoft.synapse/workspaces'| project id, name""}",
        url = AzureResourceManagerUri & "/providers/Microsoft.ResourceGraph/resources?api-version=2020-04-01-preview",
        workspaces = GetARMContents(url, [Headers = [#"Content-Type"="application/json"], Content=Text.ToBinary(content)])[data][rows],
        toRecords = List.Transform(workspaces, each [id=_{0}, name=_{1}])
    in
        toRecords;

GetWorkspaceByName = (workspaceName as text) as record =>
    let
        url = GetSynapseGatewayUri(workspaceName) & "/workspace/?api-version=2019-06-01-preview",
        result = GetSynapseContents(url)
    in
        result;

GetDatabases = (workspace as record) as list => GetSqlDatabases(workspace) & GetSyMSDatabases(workspace);

GetSqlDatabases = (workspace as record) as list =>
    let
        url = GetSynapseGatewayUri(workspace[name]) & "/sqlPools?api-version=2019-06-01-preview",
        sqlPools = GetSynapseContents(url)[value]
    in
        sqlPools;

GetSyMSDatabases = (workspace as record) as list =>
    let
        url = GetSynapseGatewayUri(workspace[name]) & "/databases?api-version=2021-04-01",
        result = GetSynapseContents(url)[items]
    in
        result;

GetSyMSDatabaseRelationships = (workspaceName as text, databaseName as text) as list =>
    let
        url = GetSynapseGatewayUri(workspaceName) & "/databases/" & databaseName & "/relationships?api-version=2021-04-01",
        result = GetSynapseContents(url)[items]
    in
        result;

GetSyMSDatabaseTables = (workspaceName as text, databaseName as text) as list =>
    let
        url = GetSynapseGatewayUri(workspaceName) & "/databases/" & databaseName & "/tables?api-version=2021-04-01",
        result = GetSynapseContents(url)[items]
    in
        result;

GetSynapseGatewayUri = (workspaceName as text) as text => "https://" & workspaceName & ".dev.azuresynapse.net";

GetARMContents = (url as text, optional options as record) =>
    Extension.InvokeWithCredentials(
        (datasource) => GetResourceCredential(AzureResourceManagerResource),
        () => GetWebContents(url, options)
    );

GetSynapseContents = (url as text, optional options as record) =>
    Extension.InvokeWithCredentials(
        (datasource) => GetResourceCredential(SynapseGatewayResource),
        () => GetWebContents(url, options)
    );

GetWebContents = (url as text, optional options as record) =>
    let
        content = Web.Contents(url, options ?? [] & [ManualStatusHandling = {400, 404, 408, 500, 504}]),
        json = Json.Document(content),
        httpStatus = Value.Metadata(content)[Response.Status],
        errorResponse = if (json = null) then null else
            let
                requestId = Record.FieldOrDefault(Value.Metadata(content)[Headers], "x-ms-request-id"),
                detail = [
                    status = httpStatus,
                    code = json[error]?[code]?,
                    message = json[error]?[message]?,
                    #"x-ms-request-id" = requestId
                ]
            in
                if (httpStatus = 400) then
                    error Error.Record(
                        "Bad Request",
                        json[error]?[message]?,
                        detail
                    )
                else if (httpStatus = 404) then
                    error Error.Record(
                        "DataSource.NotFound",
                        json[error]?[message]?,
                        detail
                    )
                else if (httpStatus = 408 or httpStatus = 504) then
                    error Error.Record(
                        "DataSource.Timeout",
                        json[error]?[message]?,
                        detail
                    )
                else if (httpStatus >= 500) then
                    error Error.Record(
                        "DataSource.Error",
                        json[error]?[message]?,
                        detail
                    )
                else
                    null
    in
        if (errorResponse <> null) then errorResponse else json;

GetSynapseDatabase = (server as text, databaseName as text) =>
    Extension.InvokeWithCredentials(
        (datasource) => GetResourceCredential(SynapseSQLDatabaseResource),
        () => Sql.Database(server, databaseName)
    );

GetResourceCredential = (resource as text) as record =>
    let
        currentCredentials = Extension.CurrentCredential(),
        prop = "AccessToken:" & resource
    in
        currentCredentials & [access_token = Record.FieldOrDefault(currentCredentials[Properties], prop, currentCredentials[access_token])];

Utility.JoinTables = (fromEntity as table, toEntity as table, fromAttribute, toAttribute, nestedColumnName as text) as table =>
    let
        joinedTable = Table.NestedJoin(
            fromEntity,
            fromAttribute,
            toEntity,
            toAttribute,
            nestedColumnName,
            JoinKind.LeftOuter)
    in
        joinedTable;


// Data Source Kind description
Synapse = [
    Type = "Singleton",
    MakeResourcePath = () => "Synapse",
    ParseResourcePath = (resource) => { },
    TestConnection = (resource) => {"Synapse.Contents"},
    Authentication = [
        Aad = [
            AuthorizationUri = "https://login.microsoftonline.com/common/oauth2/authorize",
            Resource = "",
            Scope = "https://management.azure.com/user_impersonation https://sql.azuresynapse.net/user_impersonation https://dev.azuresynapse.net/user_impersonation",
            DefaultClientApplication = [
                ClientId = "a672d62c-fc7b-4e81-a576-e60dc46e951d",
                ClientSecret = "",
                CallbackUrl = "https://preview.powerbi.com/views/oauthredirect.html"
            ]
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
Synapse.Publish = [
    Beta = true,
    Category = "Azure",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = Synapse.Icons,
    SourceTypeImage = Synapse.Icons
];

Synapse.Icons = [
    Icon16 = { Extension.Contents("Synapse16.png"), Extension.Contents("Synapse20.png"), Extension.Contents("Synapse24.png"), Extension.Contents("Synapse32.png") },
    Icon32 = { Extension.Contents("Synapse32.png"), Extension.Contents("Synapse40.png"), Extension.Contents("Synapse48.png"), Extension.Contents("Synapse64.png") }
];
