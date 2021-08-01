[Version = "1.0.0"]
section Witivio;

//
// Definition
//

client_id = "a672d62c-fc7b-4e81-a576-e60dc46e951d"; // Power Query for Excel
redirect_uri = "https://preview.powerbi.com/views/oauthredirect.html";
authorize_uri = "https://login.microsoftonline.com/common/oauth2/authorize";


resource = "https://witivio.com/15f501b1-2ede-4c82-b6ef-9d057a5df422";

//scope_prefix = "https://graph.microsoft.com/";
//scopes = {
//    "openid",
//   "email"
//};

// Data Source Kind description
Witivio = [
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            botId = json[botId]
        in
            { "Witivio.Contents", botId },
    Authentication = [
        Aad = [
            AuthorizationUri = authorize_uri,
            Resource = resource,
            DefaultClientApplication = [
                ClientId = client_id,
                ClientSecret = "",
                CallbackUrl = redirect_uri 
            ]
        ]
    ],
    Label = "Witivio 365"
];

// Data Source UI publishing description
Witivio.Publish = [
    Beta = true,
    Category = "Online Services",
    ButtonText = { "Witivio", "Witivio" },
    LearnMoreUrl = "https://docs.witivio.com",
    SourceImage = Witivio.Icons,
    SourceTypeImage = Witivio.Icons
];


Witivio.Icons = [
    Icon16 = { Extension.Contents("PQExtension116.png"), Extension.Contents("PQExtension120.png"), Extension.Contents("PQExtension124.png"), Extension.Contents("PQExtension132.png") },
    Icon32 = { Extension.Contents("PQExtension132.png"), Extension.Contents("PQExtension140.png"), Extension.Contents("PQExtension148.png"), Extension.Contents("PQExtension164.png") }
];

//
// Implementation
// 

DefaultRequestHeaders = [
    #"Accept" = "application/json;odata.metadata=minimal",  // column name and values only
    #"OData-MaxVersion" = "4.0"                             // we only support v4
];

BaseUrl = "https://app.witivio.com/api/statistics/powerbi/bot/";

RootEntities = {
    "Usage",
    "Performance",
    "Feedback",
    "History",
    "Rooms"
};

SchemaTable = #table({"Entity", "SchemaTable"}, {
    {"Usage", #table({"Name", "Type"}, {
        {"Date", DateTime.Type},
        {"Users", Int32.Type},
        {"Conversations", Int32.Type},
        {"MessagesFromBot", Int32.Type},
        {"MessagesFromUsers", Int32.Type},
        {"Channel", type text},
        {"Profile", type text}
    })},    
    
    {"Performance", #table({"Name", "Type"}, {
        {"Date", DateTime.Type},
        {"Channel", type text},
        {"Profile", type text},
        {"OK", Int32.Type},
        {"LowScore", Int32.Type},
        {"NoAnswer", Int32.Type}
    })},

     {"History", #table({"Name", "Type"}, {
        {"ConversationId", type text},
        {"UniqueMessageId", type text},
        {"ActivityId", type text},
        {"UserId", type text},
        {"DateTime", DateTime.Type},
        {"MessageFromUser", type text},
        {"MessageFromBot", type text},
        {"MessageType", type text},
        {"Status", type text},
        {"QuestionFromKb1", type text},
        {"ScoreQuestion1", Double.Type},
        {"CategoryQuestion1", type text},
        
        {"QuestionFromKb2", type text},
        {"ScoreQuestion2", Double.Type},
        {"CategoryQuestion2", type text},
        
        {"QuestionFromKb3", type text},
        {"ScoreQuestion3", Double.Type},
        {"CategoryQuestion3", type text}
    })},

     {"Rooms", #table({"Name", "Type"}, {
         {"Date", DateTime.Type},
         {"Channel", type text},
         {"Profile", type text},
         {"NumberOfRoomsBooked", Int32.Type},
         {"Zone", type text},
         {"Country", type text},
         {"Site", type text},
         {"Building", type text},
         {"Wing", type text}
    })},

    {"Feedback", #table({"Name", "Type"}, {
         {"Date", DateTime.Type},
         {"Channel", type text},
         {"Profile", type text},
         {"Positive", Int32.Type},
         {"NegativeBadQuality", Int32.Type},
         {"NegativeIncomplete", Int32.Type},
         {"NegativeOther", Int32.Type},
         {"NegativeUnusable", Int32.Type},
         {"Ignored", Int32.Type}
    })}

});
        
GetSchemaForEntity = (entity as text) as table => try SchemaTable{[Entity=entity]}[SchemaTable] otherwise error "Couldn't find entity: '" & entity &"'";

[DataSource.Kind="Witivio", Publish="Witivio.Publish"]
shared Witivio.Contents = Value.ReplaceType(WitivioNavTable, WitivioType);

WitivioType = type function (
    botId as (type text meta [
        Documentation.FieldCaption = "Chatbot ID",
        Documentation.FieldDescription = "Enter the chatbot ID",
         Documentation.SampleValues = {"00000000-0000-0000-0000-000000000000"}
    ]))
    as table meta [
        Documentation.Name = "Witivio 365 - Configuration",
        Documentation.LongDescription = "Witivio 365 - Configuration"
    ];

WitivioNavTable = (botId as text) as table =>
    let
        entitiesAsTable = Table.FromList(RootEntities, Splitter.SplitByNothing()),
        rename = Table.RenameColumns(entitiesAsTable, {{"Column1", "Name"}}),
        // Add Data as a calculated column
        withData = Table.AddColumn(rename, "Data", each GetEntity(botId, [Name]), type table),
        // Add ItemKind and ItemName as fixed text values
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Table", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table", type text),
        // Indicate that the node should not be expandable
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true, type logical),
        // Generate the nav table
        navTable = Table.ToNavigationTable(withIsLeaf, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

Witivio.Feed = (url as text, optional schema as table) as table => GetAllPagesByNextLink(url, schema);

GetEntity = (botId as text, entity as text) as table => 
    let
        fullUrl = BaseUrl & botId & "/" & entity,//Uri.Combine(BaseUrl & botId, entity),
        schemaTable = GetSchemaForEntity(entity),
        result = Witivio.Feed(fullUrl, schemaTable)
    in
        result;

GetPage = (url as text, optional schema as table) as table =>
    let
        response = Web.Contents(url, [ Headers = DefaultRequestHeaders ]),        
        body = Json.Document(response),
        nextLink = GetNextLink(body),
        data = Table.FromRecords(body[value]),
        // enforce the schema
        withSchema = if (schema <> null) then SchemaTransformTable(data, schema) else data
    in
        withSchema meta [NextLink = nextLink];

// Read all pages of data.
// After every page, we check the "NextLink" record on the metadata of the previous request.
// Table.GenerateByPage will keep asking for more pages until we return null.
GetAllPagesByNextLink = (url as text, optional schema as table) as table =>
    Table.GenerateByPage((previous) => 
        let
            // if previous is null, then this is our first page of data
            nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
            // if NextLink was set to null by the previous call, we know we have no more data
            page = if (nextLink <> null) then GetPage(nextLink, schema) else null
        in
            page
    );

// In this implementation, 'response' will be the parsed body of the response after the call to Json.Document.
// We look for the '@odata.nextLink' field and simply return null if it doesn't exist.
GetNextLink = (response) as nullable text => Record.FieldOrDefault(response, "nextLink");

//
// Common functions
//
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

// The getNextPage function takes a single argument and is expected to return a nullable table
Table.GenerateByPage = (getNextPage as function) as table =>
    let        
        listOfPages = List.Generate(
            () => getNextPage(null),            // get the first page of data
            (lastPage) => lastPage <> null,     // stop when the function returns null
            (lastPage) => getNextPage(lastPage) // pass the previous page to the next function call
        ),
        // concatenate the pages together
        tableOfPages = Table.FromList(listOfPages, Splitter.SplitByNothing(), {"Column1"}),
        firstRow = tableOfPages{0}?
    in
        // if we didn't get back any pages of data, return an empty table
        // otherwise set the table type based on the columns of the first page
        if (firstRow = null) then
            Table.FromRows({})
        else        
            Value.ReplaceType(
                Table.ExpandTableColumn(tableOfPages, "Column1", Table.ColumnNames(firstRow[Column1])),
                Value.Type(firstRow[Column1])
            );

//
// Schema functions
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

//
// Helper Functions
//
Value.IfNull = (a, b) => if a <> null then a else b;

GetScopeString = (scopes as list, optional scopePrefix as text) as text =>
    let
        prefix = Value.IfNull(scopePrefix, ""),
        addPrefix = List.Transform(scopes, each prefix & _),
        asText = Text.Combine(addPrefix, " ")
    in
        asText;