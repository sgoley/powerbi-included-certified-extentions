// This file contains your Data Connector logic
[Version = "1.0.14"]
section CustomerInsights;
CustomerInsights.resource_uri =  "https://api.ci.ai.microsoft.com";
CustomerInsights.BaseUri =  "https://global.api.ci.ai.dynamics.com/api/instances";  // Global Api for instances

// Get default options from user settings
// User can also pass options using query like CustomerInsights.Contents([ConcurrentRequests = 12])   
DefaultCIOptions = [
    ConcurrentRequests = 16
];

CustomerInsights.ApiRootQuery = "?$select=*"; 
CustomerInsights.ProxyApiRootQuery = CustomerInsights.ApiRootQuery & "&proxy=true";
CustomerInsights.UserAgentString = "Microsoft.Data.Mashup;CustomerInsightsConnector;v=1.0.13";
CustomerInsights.OriginString = "https://powerbi.microsoft.com";

CustomerInsights.SimpleHeaders = [#"User-Agent" = CustomerInsights.UserAgentString];
CustomerInsights.DefaultRequestHeaders = [#"Accept" = "application/json;odata.metadata=minimal", #"OData-MaxVersion" = "4.0", #"User-Agent" = CustomerInsights.UserAgentString, #"Origin" = CustomerInsights.OriginString];  //Required to fetch metadata and instances
CustomerInsights.CsvRequestHeaders = [#"User-Agent" = CustomerInsights.UserAgentString];  //Required to enable the downloading of data in raw csv format

//Record of all the replace types
CustomerInsights.ReplaceDataTypes = [
            Edm.Int64 = type number,
            Edm.Binary = type binary,
            Edm.Boolean = type logical,
            Edm.String = type text,
            Edm.Date = type date,
            Edm.Decimal = type number,
            Edm.Double = type number,
            Edm.Int32 = type number,
            Edm.Single = type number,
            Edm.Int16 = type number,
            Edm.TimeOfDay = type time,
            Edm.DateTimeOffset = type datetimezone,
            Edm.Byte = type number,
            Edm.SByte = type number,
            Edm.Guid = type text
        ];

[DataSource.Kind="CustomerInsights", Publish="CustomerInsights.Publish"]
shared CustomerInsights.Contents = Value.ReplaceType(CustomerInsights.ContentsInternal, CustomerInsights.Type);
CustomerInsights.ContentsInternal = (optional options as record) => CustomerInsights.EnvNavTable(CustomerInsights.BaseUri, options) as table;

CustomerInsights = [
    TestConnection = (dataSourcePath) => {"CustomerInsights.Contents"},
    Authentication = [
        Aad = [
            AuthorizationUri = "https://login.microsoftonline.com/common/oauth2/authorize",
            Resource = CustomerInsights.resource_uri,
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
CustomerInsights.Publish = [
    Beta = true,
    Category = "Online Services",
    ButtonText = {Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp")},
    LearnMoreUrl = "https://aka.ms/Dynamics365CustomerInsights",
    SourceImage = CustomerInsights.Icons,
    SourceTypeImage = CustomerInsights.Icons
];

CustomerInsights.Icons = [
    Icon16 = { Extension.Contents("CustomerInsights16.png"), Extension.Contents("CustomerInsights20.png"), Extension.Contents("CustomerInsights24.png"), Extension.Contents("CustomerInsights32.png") },
    Icon32 = { Extension.Contents("CustomerInsights32.png"), Extension.Contents("CustomerInsights40.png"), Extension.Contents("CustomerInsights48.png"), Extension.Contents("CustomerInsights64.png") }
];

CustomerInsights.Type = type function (optional options as record)
    as table meta [
        Documentation.Name = Extension.LoadString("ButtonTitle")
    ];

//Root Navigation Table
CustomerInsights.EnvNavTable = (url as text, optional options as record) as table =>
    let
        // get default options provided by user - 
        cIOptions = MergeOptions(DefaultCIOptions, options),

        JsonResponse = Json.Document(Web.Contents(Text.TrimEnd(url, {"/"}), [Headers = CustomerInsights.SimpleHeaders])),

        asTable = Table.FromList(JsonResponse, Splitter.SplitByNothing(), {"Column1"}),
        expanded = Table.ExpandRecordColumn(asTable, "Column1", {"instanceId", "tenantId", "tenantName", "scaleUnitUri", "name", "instanceType", "region"}),

        EnvironmentsNoErrors = Table.RemoveRowsWithErrors(expanded), // this filters out instances that return 500 for some reason
        FilteredEnvironments = Table.SelectRows(EnvironmentsNoErrors, each [name] <> null),  //  Eliminate instances with null as name
 
        //Core of the expansion.  scaleUnitUri + core path + Id + data. Also this url is the previous versions url
        EnvWithData = Table.AddColumn(FilteredEnvironments, "Data", each CustomerInsights.EntityNameNav( [scaleUnitUri] & "/api/instances/"& [instanceId], cIOptions)), 
        EnvWithHealth = Table.AddColumn(EnvWithData, "Health", each Json.Document(Web.Contents([scaleUnitUri] & "/api/instances/"& [instanceId], [Headers = CustomerInsights.SimpleHeaders]))),
        dataWithoutErrors = Table.RemoveRowsWithErrors(EnvWithHealth,{"Data","Health"}),   //Remove broken instances  doesn't work
        removeCols = Table.RemoveColumns(dataWithoutErrors, {"instanceType","region", "tenantId", "tenantName"}, MissingField.Ignore),   // Removing unneeded data
        withItemKind = Table.AddColumn(removeCols, "ItemKind", each "Folder", type text),   //required for  nav tables
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Folder", type text),   //required for  nav tables
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false, type logical),    //required for  nav tables.  Setting to false =  marks it as a node that can be expanded
        navTable = Table.ToNavigationTable(withIsLeaf, {"instanceId"}, "name", "Data", "ItemKind", "ItemName", "IsLeaf") // Uses nav function to create the table
    in
        navTable;

MergeOptions = (defaultOptions as record, options as nullable record) =>
    if (options = null) then defaultOptions else
    let
        toTable = Record.ToTable(options),
        removeNullFields = Table.SelectRows(toTable, each [Value] <> null),
        modifiedRecord = Record.FromTable(removeNullFields)
    in
        defaultOptions & modifiedRecord;

//Secondary Nav Table for enumerating Entities and Segments
CustomerInsights.EntityNameNav = (url as text, optional cIOptions as record) as any =>
    let
        NavColumns = {"EntityName", "Data", "ItemKind", "ItemName", "IsLeaf"},  //Actual columns of the nav table for creating table records the same
        AllEntities = CustomerInsights.GetAllEntities(url),

        //Keeping only the Customer schema and passing it to fetch all segments
        Segments =  Table.SelectRows(AllEntities, each [EntityType] = "Segment" ),
        EntitiesOnly = Table.SelectRows(AllEntities, each [EntityType] <> "Enrichment" and [EntityType] <> "AggregateKpi" and [EntityType] <> "UnifiedActivity" and [EntityType] <> "Segment"),
        Measures  = Table.SelectRows(AllEntities, each [EntityType] = "AggregateKpi"),
        Activities = Table.SelectRows(AllEntities, each [EntityType] = "UnifiedActivity"),
        Enrichments = Table.SelectRows(AllEntities, each [EntityType] = "Enrichment"),

        UserDefinedRelationships = CustomerInsights.GetAllRelationships(url),
        BuiltinMeasuresRelationships = CustomerInsights.AppendBuiltinRelationships(Measures, UserDefinedRelationships),
        BuiltinActivityRelationships = CustomerInsights.AppendBuiltinRelationships(Activities, BuiltinMeasuresRelationships),

        //creating empty Nav table to fill with Entities and Segements should they exist
        SourceWithEntities =  if Table.IsEmpty(EntitiesOnly) or Value.Is(AllEntities{0}[EntityType], Null.Type) then #table(NavColumns, {})
                                else  Table.InsertRows(#table(NavColumns, {}),  0, {
                                Record.FromList({ Extension.LoadString("Entities"), CustomerInsights.EntityNavTable(EntitiesOnly, url & "/data/", cIOptions, "Entity", BuiltinActivityRelationships), "Folder", "Folder", false }, NavColumns)
                                }),
        SourceWithMeasures =  if Table.IsEmpty(Measures) then #table(NavColumns, {})
                                else Table.InsertRows(#table(NavColumns, {}), 0 , {
                                Record.FromList({ Extension.LoadString("Measures"), CustomerInsights.EntityNavTable(Measures, url & "/data/", cIOptions, "Entity", BuiltinActivityRelationships), "Folder", "Folder", false }, NavColumns)
                                }),
        SourceWithSegments = if Table.IsEmpty(Segments) then #table(NavColumns, {})
                                else Table.InsertRows(#table(NavColumns, {}),  0 , {
                                Record.FromList({Extension.LoadString("Segments"), CustomerInsights.EntityNavTable(Segments, url & "/data/", cIOptions, "Segment", BuiltinActivityRelationships), "Folder", "Folder", false }, NavColumns)
                                }),
        SourceWithUnifiedActivity = if Table.IsEmpty(Activities) then #table(NavColumns, {})
                                else Table.InsertRows(#table(NavColumns, {}),  0 , {
                                Record.FromList({Extension.LoadString("UnifiedActivity"), CustomerInsights.EntityNavTable(Activities, url & "/data/", cIOptions, "Entity", BuiltinActivityRelationships), "Folder", "Folder", false }, NavColumns)
                                }),
        SourceWithEnrichments = if Table.IsEmpty(Enrichments) then #table(NavColumns, {})
                                else Table.InsertRows(#table(NavColumns, {}),  0 , {
                                Record.FromList({Extension.LoadString("Enrichments"), CustomerInsights.EntityNavTable(Enrichments, url & "/data/", cIOptions, "Entity", BuiltinActivityRelationships), "Folder", "Folder", false }, NavColumns)
                                }),

        MergeTables = Table.Combine({Table.RemoveRowsWithErrors(SourceWithEntities), Table.RemoveRowsWithErrors(SourceWithEnrichments), Table.RemoveRowsWithErrors(SourceWithMeasures), Table.RemoveRowsWithErrors(SourceWithSegments), Table.RemoveRowsWithErrors(SourceWithUnifiedActivity)}, NavColumns),
        EntityNameNav = Table.ToNavigationTable(MergeTables, {"EntityName"}, "EntityName", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        EntityNameNav;

CustomerInsights.AppendBuiltinRelationships = (entities as table, relationships as table) as table =>
    let
        withFromEntity = Table.AddColumn(entities, "fromEntity", each [EntityName], type text), 
        withFromAttribute = Table.AddColumn(withFromEntity, "fromAttributes", each { "CustomerId" }, type list),
        withToEntity = Table.AddColumn(withFromAttribute, "toEntity", each "Customer", type text), 
        withToAttribute = Table.AddColumn(withToEntity, "toAttributes", each { "CustomerId" }, type list),
        selectedAttributes = Table.SelectColumns(withToAttribute, {"fromEntity", "fromAttributes", "toEntity", "toAttributes"}),
        relationshipsAsRecordList = Table.ToRecords(withToAttribute),
        insertedRelationships = Table.InsertRows(relationships, 0, relationshipsAsRecordList)
    in
        insertedRelationships;

CustomerInsights.GetAllRelationships = (uri as text) as table => 
    let
        Response = Json.Document(Web.Contents(uri & "/manage/relationships", [Headers=CustomerInsights.DefaultRequestHeaders])),
        EmptyRelationships = #table(type table [ fromEntityName = Text.Type, toEntityName = Text.Type, fromAttributeName = Text.Type, toAttributeName = Text.Type], {}),
        Relationships = Table.InsertRows(EmptyRelationships, 0, Response),
        RelationshipNames = Table.RenameColumns(Relationships, {{"fromEntityName", "fromEntity"}, {"toEntityName", "toEntity"}, {"fromAttributeName", "fromAttributes"}, {"toAttributeName", "toAttributes"}}),
        RelationshipsWithAttributeLists = Table.TransformColumns(RelationshipNames, {{"fromAttributes", (val) => {val}}, {"toAttributes", (val) => {val}}}),
        RelationshipsFormatted = Table.SelectColumns(RelationshipsWithAttributeLists, {"fromEntity", "toEntity", "fromAttributes", "toAttributes"})
    in
        RelationshipsFormatted;

//Fetches all items in metadata and ignores D365 metadata entities
CustomerInsights.GetAllEntities = (uri as text) as table =>
    let
        MetadataRawResponse = Web.Contents(uri & "/manage/entities?includeSelfConflatedEntity=true&includeQuarantined=true", [Headers=CustomerInsights.DefaultRequestHeaders,  ManualStatusHandling={403}]),
        responseCode = Value.Metadata(MetadataRawResponse)[Response.Status]
    in
        if responseCode = 403 then {}
        else
            let
                Response = Record.ToTable(Json.Document(MetadataRawResponse)),

            // Keep just the entities row
            Entities =  Table.SelectRows(Response, each [Name] = "entities"),
            Records = Entities{0}[Value],
            EntitiesAsTable = Table.FromList(Records, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
            ExpandedEntities = Table.RenameColumns(Table.ExpandRecordColumn(EntitiesAsTable, "Column1", {"qualifiedEntityName", "entityType", "attributes"}), {{"entityType", "EntityType"}, {"qualifiedEntityName", "EntityName"}}),

            // Convert attributes lists to table
            AttributesListToTable = Table.AddColumn(ExpandedEntities, "Schema", each Table.RenameColumns(Table.FromRecords([attributes], {"name", "dataType"}), { {"name", "Attribute:Name"}, {"dataType", "Attribute:Type"}})),
            FormattedTable = Table.RemoveColumns(AttributesListToTable, "attributes"),

            //Conflations as they are not required
            SelectSourceEntities = Table.SelectRows(FormattedTable, 
                each [EntityType] <> "ConflationMap")
    in
        SelectSourceEntities;

//Final Nav table where entities and segments both live with their respective scaleunituri and query strings
CustomerInsights.EntityNavTable = (allEntities as table, uri as text, cIOptions as record, dataType as text, relationshipTable as table) as any =>
    let
         
         //Segments has to use Customer Entity and has a specific query param
        EntitiesWithData = if dataType = "Segment" 
                            then Table.AddColumn(allEntities, "Data", each CustomerInsights.View(uri  & [EntityName] &  CustomerInsights.ProxyApiRootQuery, [Schema], cIOptions, "Segment"))
                           else Table.AddColumn(allEntities, "Data", each CustomerInsights.View(uri  & [EntityName] & CustomerInsights.ProxyApiRootQuery, [Schema], cIOptions, "Entity")),        
        EntitiesWithName = Table.AddColumn(EntitiesWithData, "entity", each [EntityName]),
        withIdentity = Table.AddColumn(EntitiesWithName, "DataWithId",
            each Table.ReplaceRelationshipIdentity([Data], Text.Format("#{0}", { [entity] })), type table),
        EntitiesWithRelationships = 
            Table.AddColumn(withIdentity, "DataWithRelationships", (row) => CustomerInsights.ApplyRelationships(row, withIdentity, relationshipTable)),
        replaceDataTable = Table.RenameColumns(Table.RemoveColumns(EntitiesWithRelationships, {"Data"}), {{"DataWithRelationships", "Data"}}),
        withItemKind = Table.AddColumn(replaceDataTable, "ItemKind", each "Table", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table", type text),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true, type logical),
        formatted = Table.RemoveColumns(withIsLeaf, {"entity", "DataWithId"}),

        //Nav Table with Data being the true leaf node.
        EntityNav = Table.ToNavigationTable(formatted, {"EntityName"}, "EntityName", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        EntityNav;

//The view powers the data retrieval
CustomerInsights.View = (baseUrl as text, schema as table, cIOptions as record, dataType as text) as table =>
    let
        View = (state as record) => Table.View( null, [
        GetRows = () => CustomerInsights.GetData(state[Url], schema, cIOptions, dataType),  //Fetches tables
        GetType = () => Value.Type(CustomerInsights.FormatSchema(state[Schema]))  //Creates the type table with the appropriate columns and type values in their respective order
        ])
    in
        View([Url = baseUrl, Schema = schema]);

//Core Data collection
CustomerInsights.GetData = (url as text, schema as table, cIOptions as record, dataType as text) as nullable table =>
    let
        //Rename and retransform the formats in the data
        RenamedSchema = Table.RenameColumns(schema, {{"Attribute:Name", "Name"}, {"Attribute:Type", "Type"}}, MissingField.Ignore),
        TransformToTypes = Table.TransformColumns(RenamedSchema,{"Type",each Record.FieldOrDefault(CustomerInsights.ReplaceDataTypes,_,type text)}),
        TypeList = List.Zip({Table.Column(TransformToTypes, "Name"), Table.Column(TransformToTypes, "Type")}),
        RemoveNullableAndType = Table.SelectColumns(RenamedSchema,{"Name"}, MissingField.Ignore),
        Header = Table.FirstN(Table.DemoteHeaders(Table.Pivot(RemoveNullableAndType, List.Distinct(RemoveNullableAndType[Name]), "Name", "Name")), 1),
        
        //Fetches the httpRequests which contains the list of csvs and auth headers
        jsonResp = Json.Document(Web.Contents(url, [Headers = CustomerInsights.CsvRequestHeaders]))[httpRequests],
        RequestList = Table.FromList(jsonResp, Splitter.SplitByNothing(), {"Column1"}),
        ExpandList = Table.ExpandRecordColumn(RequestList, "Column1", {"uri", "headers"}, {"uri", "headers"}),

        // Here we take each csv and auth header provided and fetch the csvs
        // Segements keeps header, data Entities does not have header
        // Create a column list based on all data first row header and rejoin with original header row data
        CsvRequests = Table.TransformRows(ExpandList,
                      (row) => () =>
                        let 
                           result = Csv.Document(CustomerInsights.FetchCsv(row[uri], row[headers])),
                           //get the first row from result and transpose it to column to check if it contains headers
                           firstRowFromData = Table.Transpose(Table.FirstN(result, 1)),
                           //check if header has CustomerId as attribute
                           hasHeader = Table.Contains(firstRowFromData, [Column1="CustomerId"]),
                           filteredResult = if hasHeader = true and dataType = "Segment"
                                               then Table.RemoveFirstN(result, 1)
                                            else result
                        in 
                            filteredResult),

        BatchResult = List.ParallelInvoke(CsvRequests, cIOptions[ConcurrentRequests]),
        AddAllData = Table.FromList(BatchResult, Splitter.SplitByNothing(), {"Column1"}),
        SelectDataOnly = Table.SelectColumns(AddAllData, {"Column1"}),
        CustomColumnNames = Table.ColumnNames(SelectDataOnly{0}[Column1]),
        JoinedTables = Table.ExpandTableColumn(SelectDataOnly, "Column1", CustomColumnNames, CustomColumnNames),
        responseWithHeader = Table.PromoteHeaders(Table.Combine({Header, JoinedTables})),
        TransformedTable = (Table.TransformColumnTypes(responseWithHeader, TypeList))
     in
        if Table.IsEmpty(RequestList) then
            Table.PromoteHeaders(Header)
        else 
            TransformedTable;

CustomerInsights.FetchCsv = (uri as text, headers as record) => 
    let
        uriParts = Uri.Parts(uri),
        uriWithoutQuery = Uri.FromParts(uriParts & [Query = []])
    in
        Web.Contents(uriWithoutQuery, [
            Headers = headers,
            CredentialQuery = uriParts[Query],
            ManualCredentials = true,
            Timeout=#duration(0, 0, 20, 0)
        ]);

Uri.FromParts = (parts) =>
    let
        port = if (parts[Scheme] = "https" and parts[Port] = 443) or (parts[Scheme] = "http" and parts[Port] = 80) then ""
             else ":" & Text.From(parts[Port]),
        div1 = if Record.FieldCount(parts[Query]) > 0 then "?"
             else "",
        div2 = if Text.Length(parts[Fragment]) > 0 then "#"
             else "",
        uri = Text.Combine(
            {parts[Scheme], "://", parts[Host], port, parts[Path], div1, Uri.BuildQueryString(parts[Query]), div2, parts[Fragment]})
    in
        uri;

//Formating the schema to a type table with order
CustomerInsights.FormatSchema = (rawSchema as table) as table  =>
    let
        /*
        Rename schema columns
        Convert the types to actual primary Power Query types
        Join the two lists of names/types as a single list of lists
        */
        RenamedSchema = Table.RenameColumns(rawSchema, {{"Attribute:Name", "Name"}, {"Attribute:Type", "Type"}}),
        TransformToTypes = Table.TransformColumns(RenamedSchema,{"Type",each Record.FieldOrDefault(CustomerInsights.ReplaceDataTypes,_,type text)}),
        Transpose = Table.Transpose(TransformToTypes),
        Promote = Table.PromoteHeaders(Transpose),
        TransformHeaderAsTable = (Table.TransformColumnTypes(Promote, List.Zip({Table.Column(TransformToTypes, "Name"), Table.Column(TransformToTypes, "Type")})))
    in
        TransformHeaderAsTable;

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

//This function is useful when making an asynchronous HTTP request, and you need to poll the server until the request is complete.
Value.WaitFor = (producer as function, interval as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, null},
            (state) => state{0} <> null and (count = null or state{0} < count),
            (state) => if state{1} <> null then {null, state{1}} else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), interval(state{0}))},
            (state) => state{1})
    in
        List.Last(list);

//Relationship rewiring utility functions. Taken from the CDS PBI connector.

CustomerInsights.ApplyRelationships = (entity as record, entities as table, relationshipTable as table) as table =>
    let
        relationships = Table.ToRecords(Table.SelectRows(relationshipTable, each _[fromEntity] = entity[entity])),
        entityDataWithID = entity[DataWithId],
        dataWithKeys = [Data = entityDataWithID, Keys = {}],

        DataWithRelationshipsKeys = List.Accumulate(
            relationships,
            dataWithKeys,
            (state, current) => CustomerInsights.AddRelationshipMetadata(state, current, entities, relationships)),

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

CustomerInsights.AddRelationshipMetadata = (fromEntity as record, currentRelationship as record, entities as table, relevantRelationships as list) as record =>
    let
        fromEntityData = fromEntity[Data],
        toEntityRow = entities{[entity=currentRelationship[toEntity]]}?,
        joinedTable = CustomerInsights.JoinTables(fromEntityData, toEntityRow[DataWithId], currentRelationship[fromAttributes], currentRelationship[toAttributes]),
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
         then
            calculateRelationships
        else 
            fromEntity;

CustomerInsights.JoinTables = (fromEntity as table, toEntity as table, fromAttribute, toAttribute) as table =>
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