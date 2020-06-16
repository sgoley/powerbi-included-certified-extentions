// This file contains your Data Connector logic
[Version = "1.0.3"]
section Paxata;

// Data Source Kind description
Paxata = [
    TestConnection = (url) => {"Paxata.Contents", url},
    Authentication = [
        Key = [
            KeyLabel = "REST Access Token",
            Label = "REST Access Token"
        ]
    ]
];

// Data Source UI publishing description
Paxata.Publish = [
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://www.paxata.com/",
    SourceImage = Paxata.Icons,
    SourceTypeImage = Paxata.Icons
];

[DataSource.Kind="Paxata", Publish="Paxata.Publish"]
shared Paxata.Contents = Value.ReplaceType(PaxataDatasets, PaxataType);


PaxataType = type function (
    url as (Uri.Type meta [
        Documentation.FieldCaption = "Url",
        Documentation.FieldDescription = "Paxata base url to connect to. For example, https://paxatadeploymentname.apps.azurehdinsight.net",
        Documentation.SampleValues = { "https://paxatadeploymentname.apps.azurehdinsight.net" }
    ]))
    as table meta [
        Documentation.Name = "From Paxata"
    ];

PaxataDatasets = (url as text) as table =>
    let
        _url = ValidateUrlScheme(url),
        loggedInUserAndTenantId = FetchUserAndTenantId(_url),
        loggedInUserId = Table.FirstValue(Table.SelectColumns(loggedInUserAndTenantId, "userId")),
        loggedInTenantId = Table.FirstValue(Table.SelectColumns(loggedInUserAndTenantId, "tenantId")),
        // Get the datasets
        fullUrl = Uri.Combine(_url, Text.Combine({"/rest/library/data", "?state=DONE&tenantId=", loggedInTenantId})),
        Source = Json.Document(PaxataRequest(fullUrl)),
        ToTable = Table.FromList(Source, Splitter.SplitByNothing())
    in
        if (Table.IsEmpty(ToTable)) then
            Table.FromRows({{"No AnswerSets were found"}}, {"Message"})  
        else
            ListDataSets(url, ToTable, loggedInUserId);

ListDataSets = (url as text, source as table, loggedInUserId as text) as table =>
    let
        Expand = Table.ExpandRecordColumn(source, "Column1", {"dataFileId", "version", "tenantId", "tenantName", "userId", "userName", "createTime", "finishTime", "source", "size", "name", "description", "rowCount", "columnCount", "schema", "importLog", "state"}),
        AnswerSet = Table.ExpandRecordColumn(Expand, "source", {"type"}),
        // Filter the data set down to Script types with a state of DONE
        FilterOnSource = Table.SelectRows(AnswerSet, each [type] = "Script"),
        FilterOnState = Table.SelectRows(FilterOnSource, each [state] = "DONE"),
        // Ensure we only have one version
        UniqueDataFileId = Table.Distinct(FilterOnState, {"dataFileId"}),
        // remove any keys on the table, otherwise they'll conflict with the nav table function
        noKeys = Table.ReplaceKeys(UniqueDataFileId, {}),
        // process the schema column into something we can pass to the SchemaTransformTable function
        processSchema = Table.TransformColumns(noKeys, {"schema", each CreateSchemaTable(_)}),
        // Filter top 10 AnswerSets based on "createTime"
        Top10AnswerSets = FetchTop10AnswerSets(processSchema, url),
        // Create top 10 AnswerSets as a leaf node under "Most Recent" folder
        MoreRecentNavTable = CreateSubNavTable(Top10AnswerSets, "Data"),
        // Filter AnswerSets which is tagged as "Power BI output"
        PowerBITaggedAnswerSets = FetchPowerBITaggedAnswerSets(processSchema, url),
        // Create PowerBI tagged AnswerSets as a leaf node under "PowerBI" folder
        PowerBINavTable = CreateSubNavTable(PowerBITaggedAnswerSets, "PowerBIData"),
        // Filter user specific AnswerSets
        UserAnswerSets = FetchUserAnswerSets(processSchema, url, loggedInUserId),
        // Create loggedIn user specific AnswerSets as a leaf node under "My AnswerSets" folder
        UserNavTable = CreateSubNavTable(UserAnswerSets, "UserData"),
        // Filter AnswerSets excluding top 10 and PowerBI tagged
        OtherAnswerSets = FetchOtherAnswerSets(processSchema, Top10AnswerSets, PowerBITaggedAnswerSets, UserAnswerSets, url),
        // Create other AnswerSets as a leaf node under "Rest" folder
        OtherNavTable = CreateSubNavTable(OtherAnswerSets, "OtherData")
    in
        CreateNavTable(MoreRecentNavTable, PowerBINavTable, OtherNavTable, UserNavTable);

// Filter top 10 AnswerSets by "createTime"
FetchTop10AnswerSets = (source as table, url as text) as table =>
    let
        // Sort rows by createTime in descending order
        SortedRecords = Table.Sort(source, {{"createTime", Order.Descending}, "createTime"}),
        // Fetch only Top 10 records
        Top10Records = Table.FirstN(SortedRecords, 10),
        withTop10Data = Table.AddColumn(Top10Records, "Data", each PaxataDataSet(url, [dataFileId], [schema]), type table)
    in
        withTop10Data;

// Filter PowerBI tagged AnswerSets
FetchPowerBITaggedAnswerSets = (source as table, url as text) as table =>
    let
        // Collect all tags information
        DataSetTags = PaxataTags(url),
        // Filter powerBi specific tags
        withTags = Table.AddColumn(source, "IsPowerBITagged", each IsDataSetHasPowerBITag(DataSetTags, [dataFileId]), type text),
        PowerBIDataSets = Table.SelectRows(withTags, each ([IsPowerBITagged] = "true")),
        withPowerBIData = Table.AddColumn(PowerBIDataSets, "PowerBIData", each PaxataDataSet(url, [dataFileId], [schema]), type table)
    in
        withPowerBIData;

FetchOtherAnswerSets = (source as table, Top10AnswerSets as table, PowerBITaggedAnswerSets as table, UserAnswerSets as table, url as text) as table =>
    let
        // Select records which is not present in top10 
        skipTop10AnswerSets = Table.SelectRows(source, each (not List.Contains(Table.ToRecords(Table.SelectColumns(Top10AnswerSets, "dataFileId")), [dataFileId = [dataFileId]]))),
        // Select records which is not PowerBI tagged
        skipPowerBITaggedAnswerSets = Table.SelectRows(skipTop10AnswerSets, each (not List.Contains(Table.ToRecords(Table.SelectColumns(PowerBITaggedAnswerSets, "dataFileId")), [dataFileId = [dataFileId]]))),
        skipUserAnswerSets = Table.SelectRows(skipPowerBITaggedAnswerSets, each (not List.Contains(Table.ToRecords(Table.SelectColumns(UserAnswerSets, "dataFileId")), [dataFileId = [dataFileId]]))),
        withOtherData = Table.AddColumn(skipUserAnswerSets, "OtherData", each PaxataDataSet(url, [dataFileId], [schema]), type table)
    in
        withOtherData;

FetchUserAnswerSets = (source as table, url as text, loggedInUserId as text) as table =>
    let
        UserDataSets = Table.SelectRows(source, each ([userId] = loggedInUserId)),
        withUserData = Table.AddColumn(UserDataSets, "UserData", each PaxataDataSet(url, [dataFileId], [schema]), type table)
    in
        withUserData;

// Create root node in NavigationTable
CreateNavTable = (MoreRecentNavTable as table, PowerBINavTable as table, OtherNavTable as table, UserNavTable as table) as table =>
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"Most Recent", "Most Recent", MoreRecentNavTable, "Folder", "Folder", false},
                {"Tagged for Power BI", "Tagged for Power BI", PowerBINavTable, "Folder", "Folder", false},
                {"Other Answersets", "Other Answersets", OtherNavTable, "Folder", "Folder", false},
                {"Mine", "Mine", UserNavTable, "Folder", "Folder", false}
            }
        ),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

// Create leaf node in NavigationTable
CreateSubNavTable = (source as table, dataColumn as text) as table =>
    let
        // Add ItemKind and ItemName as fixed text values
        withItemKind = Table.AddColumn(source, "ItemKind", each "Table", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table", type text),
        // Indicate that the node should not be expandable
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true, type logical),
        // Generate the nav table
        NavTable = Table.ToNavigationTable(withIsLeaf, {"dataFileId"}, "name", dataColumn, "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

// Fetch all available tags from Paxata
PaxataTags = (url as text) =>
    let
        fullUrl = Uri.Combine(url, Text.Combine({"/rest/library/tags"})),
        Source = Json.Document(PaxataRequest(fullUrl)),
        ToTable = Table.FromList(Source, Splitter.SplitByNothing())
    in
        if (Table.IsEmpty(ToTable)) then
            Table.FromRows({})
        else
            Table.ExpandRecordColumn(ToTable, "Column1", {"dataFileId", "version", "name"});

// Filter tags by dataFileId
IsDataSetHasPowerBITag = (tags as table, id as text) as text =>
    let
        FilteredTags = Table.SelectRows(tags, each ([dataFileId] = id and (Text.Contains(Text.Lower([name]), "powerbi") or Text.Contains(Text.Lower([name]), "power bi"))))
    in
        if Table.IsEmpty(FilteredTags) then "false" else "true";

PaxataDataSet = (url as text, id as text, optional schema as table) =>
    let
        // body = [dataFileId = id, dataSourceId = "local", format="separator"],
        body = [format="separator"],
        fullUrl = Uri.Combine(url, Text.Combine({"/rest/datasource/exports/local/", id})),
        csv = PaxataRequest(fullUrl, body),
        doc = Csv.Document(csv),
        headers = Table.PromoteHeaders(doc)
    in
        if (schema <> null) then
            SchemaTransformTable(headers, schema)
        else
            headers;

CreateSchemaTable = (schema as nullable list) as table =>
    if (schema = null) then null else
    let
        toTable = Table.FromList(schema, Splitter.SplitByNothing()),
        expand = Table.ExpandRecordColumn(toTable, "Column1", {"name", "type", "maxSize"}, {"name", "type", "maxSize"}),
        setType = Table.AddColumn(expand, "Type", each if [type] = "String" then Text.Type else if [type] = "Number" then Number.Type else if [type] = "DateTime" then DateTime.Type else Any.Type, Type.Type ),
        rename = Table.RenameColumns(setType,{{"name", "Name"}}),
        select = Table.SelectColumns(rename,{"Name", "Type"})
    in
        select;

FetchUserAndTenantId = (url as text) as table =>
    let
        fullUrl = Uri.Combine(url, "/rest/sessions"),
        Source = Json.Document(PaxataRequest(fullUrl)),
        ToTable = Table.FromList(Source, Splitter.SplitByNothing()),
        Expand = Table.ExpandRecordColumn(ToTable, "Column1", {"userId", "userName", "tenantId", "requests"}),
        RequestsTable = Table.AddColumn(Expand, "requestsTable", each List.First([requests]), type table),
        ExpandRequests = Table.ExpandRecordColumn(RequestsTable, "requestsTable", {"description"}),
        FilterOnDescription = Table.SelectRows(ExpandRequests, each [description] = "/rest/sessions")
    in
        Table.SelectColumns(FilterOnDescription, {"userId", "tenantId"});

PaxataRequest = (url as text, optional body as record) =>
    let
        accessKey = Text.Combine({":", Extension.CurrentCredential()[Key]}),
        encodedAccessKey = Binary.ToText(Text.ToBinary(accessKey), BinaryEncoding.Base64),
        content = if (body <> null) then Uri.BuildQueryString(body) else null,
        headers = if (content <> null) then [ 
            #"Content-type" = "application/x-www-form-urlencoded",
            #"Authorization" = Text.Combine({"BASIC ", encodedAccessKey})
        ] else [ #"Authorization" = Text.Combine({"BASIC ", encodedAccessKey}) ],
        req = Web.Contents(url, [ Headers = headers, Content = Text.ToBinary(content), ManualCredentials = true, ManualStatusHandling={404} ]),

        // Checking the metadata on the value can cause the request to be evaluated twice. 
        // To avoid this problem, we buffer the result and force its evaluation with a null check before checking status. 
        buffered = Binary.Buffer(req),
        ResponseCode = Value.Metadata(req)[Response.Status],
        response = if (buffered = null and ResponseCode = 404) then error "No Matching library data" else buffered
    in
        response;

Paxata.Icons = [
    Icon16 = { Extension.Contents("Paxata16.png"), Extension.Contents("Paxata20.png"), Extension.Contents("Paxata24.png"), Extension.Contents("Paxata32.png") },
    Icon32 = { Extension.Contents("Paxata32.png"), Extension.Contents("Paxata40.png"), Extension.Contents("Paxata48.png"), Extension.Contents("Paxata64.png") }
];

//
// Common library code
//

ValidateUrlScheme = (url as text) as text => if (Uri.Parts(url)[Scheme] <> "https") then error "Url scheme must be HTTPS" else url;

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

//
// Schema functions
// schema table format is {[Name = Text, Type = Type]}
// see: https://github.com/Microsoft/DataConnectors/tree/master/samples/TripPin/6-Schema
//

EnforceSchema.Strict = 1;               // Add any missing columns, remove extra columns, set table type
EnforceSchema.IgnoreExtraColumns = 2;   // Add missing columns, do not remove extra columns
EnforceSchema.IgnoreMissingColumns = 3; // Do not add or remove columns

SchemaTransformTable = (table as table, schema as table, optional enforceSchema as number) as table =>
    let
        // Default to EnforceSchema.Strict
        _enforceSchema = if (enforceSchema <> null) then enforceSchema else EnforceSchema.Strict,

        // Applies type transforms to a given table
        EnforceTypes = (table as table, schema as table) as table =>
            let
                map = (t) => if Type.Is(t, type list) or Type.Is(t, type record) or t = type any then null else t,
                mapped = Table.TransformColumns(schema, {"Type", map}),
                omitted = Table.SelectRows(mapped, each [Type] <> null),
                existingColumns = Table.ColumnNames(table),
                removeMissing = Table.SelectRows(omitted, each List.Contains(existingColumns, [Name])),
                primativeTransforms = Table.ToRows(removeMissing),
                changedPrimatives = Table.TransformColumnTypes(table, primativeTransforms)
            in
                changedPrimatives,

        // Returns the table type for a given schema
        SchemaToTableType = (schema as table) as type =>
            let
                toList = List.Transform(schema[Type], (t) => [Type=t, Optional=false]),
                toRecord = Record.FromList(toList, schema[Name]),
                toType = Type.ForRecord(toRecord, false)
            in
                type table (toType),

        // Determine if we have extra/missing columns.
        // The enforceSchema parameter determines what we do about them.
        schemaNames = schema[Name],
        foundNames = Table.ColumnNames(table),
        addNames = List.RemoveItems(schemaNames, foundNames),
        extraNames = List.RemoveItems(foundNames, schemaNames),
        tmp = Text.NewGuid(),
        added = Table.AddColumn(table, tmp, each []),
        expanded = Table.ExpandRecordColumn(added, tmp, addNames),
        result = if List.IsEmpty(addNames) then table else expanded,
        fullList =
            if (_enforceSchema = EnforceSchema.Strict) then
                schemaNames
            else if (_enforceSchema = EnforceSchema.IgnoreMissingColumns) then
                foundNames
            else
                schemaNames & extraNames,

        // Select the final list of columns.
        // These will be ordered according to the schema table.
        reordered = Table.SelectColumns(result, fullList, MissingField.Ignore),
        enforcedTypes = EnforceTypes(reordered, schema),
        withType = if (_enforceSchema = EnforceSchema.Strict) then Value.ReplaceType(enforcedTypes, SchemaToTableType(schema)) else enforcedTypes
    in
        withType;
