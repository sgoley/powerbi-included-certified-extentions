[Version = "2.0.0"]
section ZendeskData;

//
// OAuth configuration settings
//

client_id = Text.FromBinary(Extension.Contents("client_id"));
client_secret = Text.FromBinary(Extension.Contents("client_secret"));


redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";

windowWidth = 800;
windowHeight = 800;


RootEntityNames = {"Tickets", "Groups", "Tags", "Users", "Activities", "Group Memberships",
"Organizations", "Requests", "Satisfaction Ratings", "Sessions", "Ticket Audits", "Ticket Fields", "Ticket Metrics", "Triggers", "Views", "Articles"};

EntityNameTable = #table(
            {"EntityName", "Entity"},
            {
                {"Activities", "activities"},
                {"Articles", "help_center/articles"},
                {"Group Memberships", "group_memberships"},
                {"Groups", "groups"},
                {"Organizations", "organizations"},
                {"Requests", "requests"},
                {"Satisfaction Ratings", "satisfaction_ratings"},
                {"Sessions", "sessions"},
                {"Tags", "tags"},
                {"Targets", "targets"},
                {"Ticket Audits", "ticket_audits"},
                {"Ticket Comments", "comments"},
                {"Ticket Fields", "ticket_fields"},
                {"Ticket Metrics", "ticket_metrics"},
                {"Tickets", "tickets"},
                {"Triggers", "triggers"},
                {"Users", "users"},
                {"Views", "views"}
            }
        );

GetEntityFromEntityName = (entityName as text) as text =>
    try EntityNameTable{[EntityName = entityName]}[Entity] otherwise  error "Couldn't find entity: '" & entityName & "'";

// This endpoints doesn't support CBP:
// targets

// Special cases:
// ticket comments: GET /api/v2/tickets/{ticket_id}/comments
// articles: GET /api/v2/help_center{/locale}/articles
// GET /api/v2/attachments/{attachment_id}

//
// Exported functions
//
// These functions are exported to the M Engine (making them visible to end users), and associates
// them with the specified Data Source Kind. The Data Source Kind is used when determining which
// credentials to use during evaluation. Credential matching is done based on the function's parameters.
// All data source functions associated to the same Data Source Kind must have a matching set of required
// function parameters, including type, name, and the order in which they appear.
[DataSource.Kind = "ZendeskData", Publish = "ZendeskData.UI"]
shared ZendeskData.Contents = Value.ReplaceType(ZendeskNavTable, ZendeskFunctionType);

ZendeskFunctionType = type function (
    url as ( Uri.Type meta [
        Documentation.FieldCaption = Extension.LoadString("ZendeskFunctionTypeCaption"),
        Documentation.FieldDescription = Extension.LoadString("ZendeskFunctionTypeDescription"),
        Documentation.SampleValues = {Extension.LoadString("ZendeskFunctionTypeSample")}
    ]),
    optional options as (type record meta [
        Documentation.FieldCaption = Extension.LoadString("ZendeskFunctionTypeOptionalName"),
        Documentation.FieldDescription = Extension.LoadString("ZendeskFunctionTypeOptionalDesc"),
        Documentation.SampleValues = {Extension.LoadString("ZendeskFunctionTypeOptionalSample")}
    ]))
    as table meta [
        Documentation.Name = Extension.LoadString("FormulaTitle"),
        Documentation.LongDescription =  Extension.LoadString("ZendeskFunctionTypeTableLongDesc")
    ];

TestImpl = (url as text) as any =>
    let
        fullURL = GenerateFullUrl(url),
        targets = GetTargetsEntity(fullURL)
    in
        targets;

GenerateFullUrl = (url as text) as text =>
    let
        parts = Uri.Parts(url),
        host = parts[Host]
    in
        "https://" & host & "/api/v2/";

GetTargetsEntity = (url as text) as table =>
    let
        entity = "targets",
        fullUrl = url & entity,
        schema = GetSchemaForEntity(entity),
        source = Web.Contents(
            fullUrl,
            [
                Headers = [#"X-Zendesk-Power-BI-Connector" = "v2"]
            ]
        ),
        body = Json.Document(source),
        entityName = List.First(Record.FieldNames(body)),
        data = TableFieldTypeTransform(body, entityName, schema),
        appliedSchema = Table.ChangeType(data, schema)
    in
        appliedSchema;

GetTicketsCommentsEntity = (url as text) as table =>
    let
        // Get all ticket ids
        tickets = GetEntity(url, "tickets"),
        ticketIds = Table.Column(tickets, "id"),
        // Call ticket comments for each ticket id
        comments = List.Transform(ticketIds, each GetTicketCommentsPerTicket(url, Number.ToText(_))),
        commentsAsTable = Table.Combine(comments)
    in
        commentsAsTable;

GetTicketCommentsPerTicket = (url as text, ticketId as text) as table =>
    let
        ticketCommentsURL = url & "tickets/" & ticketId & "/",
        comments = GetEntity(ticketCommentsURL, "comments"),
        commentsWithTicketId = Table.AddColumn(comments, "ticket_id", each Int64.From(ticketId), Int64.Type),
        reordered = Table.ReorderColumns(commentsWithTicketId,{"id", "ticket_id", "type", "author_id", "body", "html_body", "plain_body", "public", "audit_id", "attachments", "uploads", "via", "metadata", "created_at"})
    in
        reordered;

ZendeskNavTable = (url as text, optional options as record) as table =>
    if (options[TestConnection]?=true) then
        TestImpl(url)
    else
        let
            fullURL = GenerateFullUrl(url),
            entitiesAsTable = Table.FromList(RootEntityNames, Splitter.SplitByNothing()),
            rename = Table.RenameColumns(entitiesAsTable, {{"Column1", "Key"}}),
            // Add Data as a calculated column
            withData = Table.AddColumn(rename, "Data", each GetEntity(fullURL, GetEntityFromEntityName([Key])), type table),
            // Add ItemKind and ItemName as fixed text values
            withItemKind = Table.AddColumn(withData, "ItemKind", each "Table", type text),
            withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table", type text),
            // Indicate that the node should not be expandable
            withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true, type logical),

            // Add the "targets" entity
            withTargetsEntity = Table.InsertRows(withIsLeaf, 1, {[Key = "Targets", Data = GetTargetsEntity(fullURL), ItemKind = "Table", ItemName = "Table", IsLeaf = true]}),

            // Add the "ticket comments" entity
            withTicketCommentsEntity = Table.InsertRows(withTargetsEntity, 1,  {[Key = "Ticket Comments", Data = GetTicketsCommentsEntity(fullURL), ItemKind = "Table", ItemName = "Table", IsLeaf = true]}),
            // Generate the nav table
            navTable = Table.ToNavigationTable(withTicketCommentsEntity, {"Key"}, "Key", "Data", "ItemKind", "ItemName", "IsLeaf")
        in
            navTable;

ZendeskData.Feed = (url as text, optional schema as type) as table => GetAllPagesByNextLink(url, schema);

GetEntity = (url as text, entity as text) as table =>
    let
        fullUrl = url & entity & "?" & "page[size]=100", // CBP
        schema = GetSchemaForEntity(entity),
        result = ZendeskData.Feed(fullUrl, schema),
        appliedSchema = Table.ChangeType(result, schema)
    in
        appliedSchema;

GetPage = (url as text, optional schema as type) as table =>
    let
        response = Web.Contents(
            url,
            [
                Headers = [#"X-Zendesk-Power-BI-Connector" = "v2"]
            ]
        ),
        body = Json.Document(response),
        nextLink = GetNextLink(body),
        hasMore = GetHasMore(body),
        entityName = List.First(List.RemoveItems(Record.FieldNames(body), {"meta", "links"})), // remove meta and links, the last element is the entity
        // If we have no schema, use Table.FromRecords() instead
        // (and hope that our results all have the same fields).
        // If we have a schema, expand the record using its field names
        data = TableFieldTypeTransform(body, entityName, schema)
    in
        data meta [NextLink = nextLink, HasMore = hasMore];

TableFieldTypeTransform = (body as record, entityName as text, optional schema as type) as table =>
    let
        data = 
            if (schema = null) then
                Table.FromRecords(Record.Field(body, entityName))
            else
                let 
                    // convert the list of records into a table (single colunmn of records)
                    asTable = Table.FromList(Record.Field(body, entityName), Splitter.SplitByNothing(), {"Column1"}),
                    fields = Record.FieldNames(Type.RecordFields(Type.TableRow(schema))),
                    expanded = Table.ExpandRecordColumn(asTable, "Column1", fields)
                in
                    expanded
    in
        data;

// Read all pages of data.
// After every page, we check the "NextLink" record on the metadata of the previous request.
// Table.GenerateByPage will keep asking for more pages until we return null.
GetAllPagesByNextLink = (url as text, optional schema as type) as table =>
    Table.GenerateByPage(
        (previous) =>
            let
                // if previous is null, then this is our first page of data
                nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
                // if NextLink was set to null by the previous call, we know we have no more data
                hasMore = if (previous = null) // First call, always true
                    then true 
                else 
                    // Second call, should have metadata fields now
                    if (Value.Metadata(previous)[HasMore])
                        then true
                    else 
                        false,

                page = if (hasMore = true) then GetPage(nextLink, schema) else null
            in
                page
    );

// In this implementation, 'response' will be the parsed body of the response after the call to Json.Document.
// We look for the 'links.next' field and simply return null if it doesn't exist.
GetNextLink = (response) as nullable text => 
    Record.FieldOrDefault(Record.FieldOrDefault(response, "links"), "next");

// In this implementation, 'response' will be the parsed body of the response after the call to Json.Document.
// We look for the 'meta.has_more' field and simply return null if it doesn't exist.
GetHasMore = (response) as nullable logical =>
    Logical.From(Record.FieldOrDefault(Record.FieldOrDefault(response, "meta"), "has_more"));


//
// Data Source definition
//
ZendeskData = [
TestConnection = (dataSourcePath) => {"ZendeskData.Contents", dataSourcePath, [TestConnection = true]},
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ]
];

//
// UI Export definition
//
ZendeskData.UI = [
    Beta = true,
    ButtonText = {Extension.LoadString("FormulaTitle"), Extension.LoadString("FormulaHelp")},
    SourceImage = ZendeskData.Icons,
    SourceTypeImage = ZendeskData.Icons
];

ZendeskData.Icons = [
    Icon16 = {
        Extension.Contents("zendesk16.png"),
        Extension.Contents("zendesk20.png"),
        Extension.Contents("zendesk24.png"),
        Extension.Contents("zendesk32.png")
    },
    Icon32 = {
        Extension.Contents("zendesk32.png"),
        Extension.Contents("zendesk40.png"),
        Extension.Contents("zendesk48.png"),
        Extension.Contents("zendesk64.png")
    }
];


//
// OAuth2 flow definition
//
StartLogin = (resourceUrl, state, display) =>
    let
        OAuthBaseUrl = "https://" & Uri.Parts(resourceUrl)[Host],
        AuthorizeUrl = Uri.Combine(OAuthBaseUrl, "oauth/authorizations/new") & "?"
            & Uri.BuildQueryString(
                [
                    response_type = "code",
                    client_id = client_id,
                    scope = "read",
                    state = state,
                    redirect_uri = redirect_uri
                ]
            )
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = null
        ];

FinishLogin = (clientApplication, dataSourcePath, context, callbackUri, state) =>
    let 
        Parts = Uri.Parts(callbackUri)[Query],
        OAuthBaseUrl = "https://" & Uri.Parts(dataSourcePath)[Host],
        token_uri = Uri.Combine(OAuthBaseUrl, "oauth/tokens")
    in 
        TokenMethod(Parts[code], token_uri);

TokenMethod = (code, token_uri) =>
    let
        Response = Web.Contents(
            token_uri,
            [
                Content = Text.ToBinary(
                    Uri.BuildQueryString(
                        [
                            grant_type = "authorization_code",
                            client_id = client_id,
                            client_secret = client_secret,
                            code = code,
                            redirect_uri = redirect_uri,
                            scope = "read"
                        ]
                    )
                ),
                Headers = [#"Content-type" = "application/x-www-form-urlencoded", #"Accept" = "application/json", #"X-Zendesk-Power-BI-Connector" = "v2"]
            ]
        ),
        Parts = Json.Document(Response)
    in
        Parts;


//
// Load common library functions
//
// TEMPORARY WORKAROUND until we're able to reference other M modules
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name), asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Table.ChangeType = Extension.LoadFunction("Table.ChangeType.pqm");
Table.GenerateByPage = Extension.LoadFunction("Table.GenerateByPage.pqm");
Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");
GetSchemaForEntity = Extension.LoadFunction("GetSchemaForEntity.pqm");