// This file contains your Data Connector logic
[Version = "1.0.3"]
section Tenforce;

// DEFINITION
EnableTraceOutput = false;

[DataSource.Kind="Tenforce", Publish="Tenforce.Publish"]
shared Tenforce.Contents = Value.ReplaceType(TenforceConnector.NavTable, SelectionData.Parameters);

// Data Source Kind description
Tenforce = [
    // TestConnection is required to enable the connector through the Gateway
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            ApplicationUrl = json[ApplicationUrl],
            ListId = json[ListId],
            DataType = json[DataType]
        in
            { "Tenforce.Contents", ApplicationUrl, ListId, DataType },
    Authentication = [
        UsernamePassword = [], Windows = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

Text.ReplaceAll =
    (str as text, Replacements as list) as text => List.Accumulate(Replacements, str, (s, x) => Text.Replace(s, x{0}, x{1})) ;
  
// Data Source UI publishing description
Tenforce.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = Extension.LoadString("TenforceUrl"),
    SourceImage = TenforceConnector.Icons,
    SourceTypeImage = TenforceConnector.Icons
];

// References to icons that will be used when displaying connector
TenforceConnector.Icons = [
    Icon16 = { Extension.Contents("TenforceConnector16.png"), Extension.Contents("TenforceConnector20.png"), Extension.Contents("TenforceConnector24.png"), Extension.Contents("TenforceConnector32.png") },
    Icon32 = { Extension.Contents("TenforceConnector32.png"), Extension.Contents("TenforceConnector40.png"), Extension.Contents("TenforceConnector48.png"), Extension.Contents("TenforceConnector64.png") }
];

// IMPLEMENTATION

// Headers required when making a request to Tenforce application
DefaultRequestHeaders = [
    #"Accept" = "application/json" // needed when requesting json
];

// Input parameters to determine data-set to select
SelectionData.Parameters = type function (
    ApplicationUrl as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("ApplicationUrl"),
        Documentation.FieldDescription = Extension.LoadString("ApplicationUrlDescription"),
        Documentation.SampleValues = {Extension.LoadString("ApplicationUrlSample")}
    ]),
    ListId as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("ListId"),
        Documentation.FieldDescription = Extension.LoadString("ListIdDescription"),
        Documentation.SampleValues = {Extension.LoadString("ListIdDescription")}
    ]),
     DataType as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("DataType"),
        Documentation.FieldDescription = Extension.LoadString("DataTypeDescription"),
        Documentation.AllowedValues = {Extension.LoadString("DataTypeExclude"), Extension.LoadString("DataTypeInclude")}
    ]))

    as table meta [
        Documentation.Name = Extension.LoadString("TableName"),
        Documentation.LongDescription = Extension.LoadString("TableDescription")
    ];


TenforceConnector.NavTable = (ApplicationUrl as text, ListId as text, DataType as text) as table =>
    let
        Items = Table.Buffer(TenforceConnector.ItemsTable(ApplicationUrl, ListId, DataType)),

        source = #table(
            {"Name"         , "Data"                                    , "ItemKind", "ItemName", "IsLeaf"}, {
            {Extension.LoadString("Items")       , TenforceConnector.ItemsNavTable(Items)    , "Folder"  , "Table"   , false   },
            {Extension.LoadString("Relationships"), TenforceConnector.RelationsNavTable(Items), "Folder"  , "Table"   , false   }
        }),
        navTable = Table.ToNavigationTable(source, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

TenforceConnector.ItemsNavTable = (Items as table) =>
    let
        items = Table.RemoveColumns(Items, {"ParentId", "ItemRelations"}), // The fields "ParentId" and "ItemRelations" are only used to create the different kind of relation tables
        ExtractedItems = TenforceConnector.ItemsTableExtracted(items),     // Multi-value fields are comma-separated extracted
        multiValueFields = TenforceConnector.MultiValueFields(Items),      // Multi-value fields are expanded

        source = #table(
            {"Name"            , "Data"          , "ItemKind", "ItemName", "IsLeaf"}, {
            {Extension.LoadString("Items")           , ExtractedItems  , "Table"   , "Table"   , true    },
            {Extension.LoadString("MultiValueFields") , multiValueFields, "Table"   , "Table"   , true    }
        }),
        navTable = Table.ToNavigationTable(source, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

TenforceConnector.RelationsNavTable = (Items as table) =>
    let
        Hierarchy = TenforceConnector.HierarchyTable(Items),
        ItemRelations = TenforceConnector.ItemRelationsTable(Items),

        source = #table(
            {"Name"         , "Data"              , "ItemKind", "ItemName", "IsLeaf"}, {
            {Extension.LoadString("Hierarchy")    , Hierarchy           , "Table"   , "Table"   , true    },
            {Extension.LoadString("ItemRelations") , ItemRelations       , "Table"   , "Table"   , true    }
        }),
        navTable = Table.ToNavigationTable(source, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

// Table with all data received from request (items, schema, ..)
TenforceConnector.Data = (ApplicationUrl as text, ListId as text, DataType as text) => 
    let
        _url = Diagnostics.LogValue("Accessing url:", SelectionData.GetUrlData(ApplicationUrl, ListId, DataType)),
        source = Web.Contents(_url, [Headers = DefaultRequestHeaders, Timeout=#duration(0,0,30,0)]),
        json = Json.Document(source)
    in
        json;

// Data set: All Items transformed in a flat table
TenforceConnector.ItemsTable = (ApplicationUrl as text, ListId as text, DataType as text) as table => 
    let
        #"Raw data" = TenforceConnector.Data(ApplicationUrl, ListId, DataType),
        #"List of item records" = #"Raw data"[Items],
        #"Table of item records" = Table.FromList(#"List of item records", Splitter.SplitByNothing(), {"Records"}, null, ExtraValues.Error),

        SchemaAsTable = TenforceConnector.SchemaAsTable(#"Raw data"),
        
        Items =
            if (SchemaAsTable = null) then
                #"Table of item records"
            else
                let
                    SchemaAsTableType = Schema.SchemaToTableType(SchemaAsTable),
                    fields = Diagnostics.LogValue("Got schema fields:", Record.FieldNames(Type.RecordFields(Type.TableRow(SchemaAsTableType)))),

                    expanded = Table.ExpandRecordColumn(#"Table of item records", "Records", fields),
                    appliedSchema = Table.ChangeType(expanded, SchemaAsTableType)
                in
                    appliedSchema,
        #"Rename columns Items" = Table.RenameColumns(Items, {{"Id","ItemId"},{"Parent","ParentId"},{"Item relation","ItemRelations"}})
    in
        #"Rename columns Items";

TenforceConnector.SchemaAsTable = (jsonData as any) as table =>
    let
        #"Selected Schema" = jsonData[Schema],
        #"Converted to Table1" = Record.ToTable(#"Selected Schema"),
        #"Renamed Columns" = Table.RenameColumns(#"Converted to Table1",{{"Name", "Column name"}, {"Value", "Column type"}}),
        #"Changed Type" = Table.TransformColumnTypes(#"Renamed Columns",{{"Column type", type text}}),
        #"map Power BI types onto Tenforce types" = Table.Join(#"Changed Type", "Column type",TypeMappingTable, "Tenforce field type" ,JoinKind.LeftOuter),
        Schema = Table.SelectColumns(#"map Power BI types onto Tenforce types",{"Column name", "Power Bi column type"})
    in
        Schema;

// Table with all the possible hierarchical relations between an item and its descendants and ancestors
TenforceConnector.HierarchyTable = (Items as table) as table =>
    let
        InitialParentChild = Table.Buffer(
                                Table.RenameColumns(
                                    Table.SelectColumns(Items,{"ItemId", "ParentId"}),
                                    {{"ItemId","ChildId"}}
                                )
                             ),

        Relationlevels = List.Generate(
                            () => Table.RemoveMatchingRows(
                                     Table.RenameColumns(InitialParentChild, {{"ChildId","DescendantId"} , {"ParentId","AncestorId"}}),
                                     {[AncestorId= null]},
                                     "AncestorId"
                                  ),
                            each not Table.IsEmpty(_),
                            each let
                                     join = Table.Join(
                                               Table.RenameColumns(
                                                  Table.SelectColumns(_, {"DescendantId","AncestorId"}), 
                                                  {{"AncestorId","key1"}}
                                                ),
                                                "key1",
                                                Table.RenameColumns(
                                                   Table.SelectColumns(InitialParentChild, {"ChildId","ParentId"}),
                                                   {{"ChildId","key2"} , {"ParentId","AncestorId"}}
                                                ),
                                                "key2",
                                                JoinKind.LeftOuter
                                            ),
                                     result = Table.RemoveMatchingRows(
                                                 Table.SelectColumns(join, {"DescendantId","AncestorId"}),
                                                 {[AncestorId= null]},
                                                 "AncestorId"
                                              )
                                 in
                                     result
                         ),
        Relations = Table.Combine(Relationlevels)
    in
        Relations;

// Table with all the possible item relations between items 
TenforceConnector.ItemRelationsTable = (Items as table) as table =>
    let
        data = Table.SelectColumns(Items,{"ItemId", "ItemRelations"}),
        #"Expanded Item relations0" = Table.ExpandListColumn(data, "ItemRelations"),
        #"Remove items without item relations" = Table.RemoveMatchingRows(
                                                    #"Expanded Item relations0",
                                                    {[ItemRelations= null]},
                                                 "ItemRelations"
                                              ),
        #"Expanded Item relations1" = Table.ExpandRecordColumn(#"Remove items without item relations", "ItemRelations", {"Key", "Value"}, {"ItemRelationType", "Value"}),
        #"Expanded Value0" = Table.ExpandListColumn(#"Expanded Item relations1", "Value"),
        #"Expanded Value1" = Table.ExpandRecordColumn(#"Expanded Value0", "Value", {"RelatedItemId", "ItemRelationDirection"}, {"RelatedItemId", "ItemRelationDirection"}),
        #"Changed Type" = Table.TransformColumnTypes(#"Expanded Value1",{{"ItemRelationType", type text}, {"RelatedItemId", Int64.Type}, {"ItemRelationDirection", type text}})
    in
        #"Changed Type";

// Table with expanded values of multi-value fields
TenforceConnector.MultiValueFields = (Items as table) as table =>
    let
        TableSchema = Table.Schema(Items),
        #"Multi-value fields" = Table.Column(
                                   Table.SelectRows(TableSchema, each [Kind] = "list"),
                                   "Name"
                                ),
        #"items with only fields of type list" = Table.SelectColumns(Items, List.InsertRange(#"Multi-value fields", 0, {"ItemId"})),
        #"Multi-value fields expanded" = List.Accumulate(#"Multi-value fields", #"items with only fields of type list", (Table, Field) => Table.ExpandListColumn(Table, Field))
    in
        #"Multi-value fields expanded";

// Data set: All Items transformed in a flat table AND their multi-value fields extracted (comma separated)
TenforceConnector.ItemsTableExtracted = (Items as table) as table => 
    let
        Schema = Table.Schema(Items),
        #"Multi-value fields" = Table.Column(
                                   Table.SelectRows(Schema, each [Kind] = "list"),
                                   "Name"
                                ),
        result = List.Accumulate(#"Multi-value fields", Items, (Table, Field) => Table.TransformColumns(Table, {Field, each Text.Combine(List.Transform(_, Text.From), ","), type text}))
    in
        result;

// LIBRARY FUNCTIONS

// Url to make a request to
SelectionData.GetUrlData = (ApplicationUrl as text, ListId as text, loadType as text) as text =>
    let
        url = ApplicationUrl & 
        "connectapi/powerbi/serializewithschema?" &
        "selection=" & ListId & 
        "&full=" & SelectionData.SetLoadtype(loadType)
    in 
        url;

// Translate loadtype of selection to logical value (text)
SelectionData.SetLoadtype = (loadType as text) as text =>
    let
        url = if(loadType = "Include") 
              then "true" 
              else "false"
    in 
        url;

// Returns the table type for a given schema
Schema.SchemaToTableType = (schema as table) as type =>
    let
        toList = List.Transform(schema[#"Power Bi column type"], (t) => [Type=t, Optional=false]),
        toRecord = Record.FromList(toList, schema[Column name]),
        toType = Type.ForRecord(toRecord, false)
    in
        type table (toType);

// LOAD COMMON LIBRARY FUNCTIONS
// TEMPORARY WORKAROUND until it's able to reference other M modules

Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = if (EnableTraceOutput) then Diagnostics[LogValue] else (prefix, value) => value;
Diagnostics.LogFailure = Diagnostics[LogFailure];
Table.ChangeType = Extension.LoadFunction("Table.ChangeType.pqm");
Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");

TypeMappingTable = Extension.LoadFunction("TypeMappingTable.pqm");