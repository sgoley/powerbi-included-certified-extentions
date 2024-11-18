// This file contains your Data Connector logic.
[Version = "2.0.0"]
section EduFrame;

client_id = Text.FromBinary(Extension.Contents("client_id"));
client_secret = Text.FromBinary(Extension.Contents("client_secret"));
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
eduframe_api_url = "https://api.eduframe.nl/api/v1/";
windowWidth = 600;
windowHeight = 600;

[DataSource.Kind="EduFrame", Publish="EduFrame.Publish"]
shared EduFrame.Contents = Value.ReplaceType(NavTable, NavTableType);

// ############################################################################################################################################################
// ######### TABLE DEFINITIONS AND SCHEMAS ####################################################################################################################
// ############################################################################################################################################################

RELATIONS = {
    {"accounts", LoadTable("accounts")},
    {"affiliations", LoadTable("affiliations")},
    {"educators", educators},
    {"leads", LoadTable("leads")},
    {"users", LoadTable("users")},
    {"teachers", LoadTable("teachers")},
    {"teacher_roles", LoadTable("teacher_roles")}
};

CATALOGS = {
    {"catalog/variants", LoadTable("catalog/variants")},
    {"catalog/products", LoadTable("catalog/products")}
};

ORDERS = {
    {"invoices", LoadTable("invoices")},
    {"orders", LoadTable("orders")},
    {"payment_methods", LoadTable("payment_methods")},
    {"payment_options", LoadTable("payment_options")},
    {"referrals", LoadTable("referrals")}
};

ENROLLMENTS = {
    {"enrollments", LoadTable("enrollments")},
    {"program/enrollments", LoadTable("program/enrollments")},
    {"teacher_enrollments", LoadTable("teacher_enrollments")}
};

COURSES = {
    {"courses", courses},
    {"course_locations", LoadTable("course_locations")},
    {"course_variants", LoadTable("course_variants")},
    {"planned_courses", LoadTable("planned_courses")}
};

PROGRAMS = {
    {"program/personal_program_elements", LoadTable("program/personal_program_elements")},
    {"program/editions", LoadTable("program/editions")},
    {"program/elements", LoadTable("program/elements")},
    {"program/programs", LoadTable("program/programs")}
};

MEETINGS = {
    {"attendances", LoadTable("attendances")},
    {"meetings", LoadTable("meetings")},
    {"meeting_locations", LoadTable("meeting_locations")},
    {"planning/events", LoadTable("planning/events")}
};

MATERIALS = {
    {"materials", LoadTable("materials")},
    {"material_groups", LoadTable("material_groups")}
};

/*
*   This function loads the table configuration for a specific resource.
*/
LoadTable = (resource as text) => QueryRecords(resource);

/*
*   Loads the authentications of the given list of user id's.
*/
loadUserAuthentications = (userIds as list) as table =>
    Table.FromRecords(List.RemoveNulls(List.Combine(List.Transform(userIds, (userId as number) =>
        let url = Text.Combine({eduframe_api_url, "users/", Number.ToText(userId), "/authentications"}) in
        let query = [authentication = "eduframe"] in
        Requests.Fetch(url, query)
    ))));

educators = Table.RemoveColumns(Table.PromoteHeaders(Table.Transpose(Record.ToTable(Requests.Fetch(Text.Combine({eduframe_api_url, "educators/current"})))), [PromoteAllScalars=true]), {"signup_default_account_type", "signup_contact_info", "default_invoice_vat_multiplier"}, MissingField.Ignore);

courses = QueryRecords("courses", {"position", "slug_history","avatar_thumb_url", "avatar", "avatar_url"});

labels = Value.ReplaceType(
        (label_type as text) as table => QueryRecords("labels", {"model_type"}, [model_type = label_type]),
        type function (
            label_type as (type text meta [Documentation.AllowedValues = {"Catalog::Product", "User", "Teacher", "Program::Enrollment", "Lead", "Account", "Order"}])
        ) as table
    );

// ############################################################################################################################################################
// ######### NAV TABLE CREATION ###############################################################################################################################
// ############################################################################################################################################################

// Setup your connector at first load.
// We allow the option to include or exclude personal data of users.
NavTableType = type function (
        domainSlug as (type text meta [
            Documentation.FieldCaption = Extension.LoadString("DomainSlug"),
            Documentation.FieldDescription = Extension.LoadString("DomainSlugHighlight"),
            Documentation.SampleValues =  {Extension.LoadString("DomainSlugExample")}
        ]))
        as table meta [
            Documentation.Name = Extension.LoadString("ConnectorName")
        ];

NavTable = (domainSlug as text) as any =>
    let
        // This is the main table navigation. Each item has a sub table from which you can select actual data tables.
        objects = #table(
            {"Name",          "Key",          "ItemKind",     "ItemName",     "IsLeaf", "Data"                                   },{
            {"Relations",     "RELATIONS",    "Folder",       "Relations",    false,    SubTable(RELATIONS)},
            {"Orders",        "ORDERS",       "Folder",       "Orders",       false,    SubTable(ORDERS)},
            {"Enrollments",   "ENROLLMENTS",  "Folder",       "Enrollment",   false,    SubTable(ENROLLMENTS)},
            {"Education",     "EDUCATION",    "Folder",       "Education",    false,    SubTableEducation},
            {"Labels",        "LABELS",       "Table",        "Labels",       false,    labels},
            {"Functions",     "FUNCTIONS",    "Folder",       "Functions",    false,    FunctionsTable}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

FunctionsTable = 
    let objects = #table(
        {"Name", "Key", "ItemKind", "ItemName", "IsLeaf", "Data"}, {
        {"Authentications", "AUTHENTICATIONS", "Table", "Authentications", true, loadUserAuthentications}
    })
    in Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

// This is the sub folder named "Education".
SubTableEducation =
    Table.ToNavigationTable(#table(
            {"Name",        "Key",          "ItemKind",     "ItemName",     "IsLeaf",   "Data"},{
            {"Catalogs",    "CATALOGS",     "Folder",       "Catalogs",     false,      SubTable(CATALOGS)},
            {"categories",  "CATEGORIES",   "Table",        "Table",        true,       LoadTable("categories")},
            {"credits",     "CREDITS",      "Table",        "Table",        true,       LoadTable("credits")},
            {"Courses",     "COURSES",      "Folder",       "Courses",      false,      SubTable(COURSES)},
            {"Programs",    "PROGRAMS",     "Folder",       "Programs",     false,      SubTable(PROGRAMS)},
            {"Meetings",    "MEETINGS",     "Folder",       "Meetings",     false,      SubTable(MEETINGS)},
            {"Materials",   "MATERIALS",    "Folder",       "Materials",    false,      SubTable(MATERIALS)}
    }), {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

SubTable = (table as list) as table =>
    Table.ToNavigationTable(#table({"Name", "Data", "ItemKind", "ItemName", "IsLeaf"}, List.Transform(table, each {_{0}, _{1}, "Table", "Table", true})), {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

// ############################################################################################################################################################
// ######### DATA QUERY FUNCTIONS #############################################################################################################################
// ############################################################################################################################################################

/*
*   This function fetches all records from the Eduframe API and transforms them into a table.
*/
QueryRecords = (resource as text, optional removals as list, optional query as nullable record) as table =>
    let request_url = Text.Combine({eduframe_api_url, resource}) in
    let base_query_params = if query <> null then query else [] in
    let query_params = Record.AddField(base_query_params, "per_page", Number.ToText(100)) in
    let resource_table = Table.FromRecords(Requests.PagedList(request_url, query_params), null, MissingField.UseNull) in
    if removals <> null then Table.RemoveColumns(resource_table, removals, MissingField.Ignore) else resource_table;

// ############################################################################################################################################################
// ######### HELPER FUNCTIONS #################################################################################################################################
// ############################################################################################################################################################

//######################################## LOADING ADDITIONAL FILES ########################################
Extension.LoadFunction = (fileName as text) =>
  let
      binary = Extension.Contents(fileName),
      asText = Text.FromBinary(binary)
  in
      try
        Expression.Evaluate(asText, #shared)
      catch (e) =>
        error [
            Reason = "Extension.LoadFunction Failure",
            Message.Format = "Loading '#{0}' failed - '#{1}': '#{2}'",
            Message.Parameters = {fileName, e[Reason], e[Message]},
            Detail = [File = fileName, Error = e]
        ];

// Import our requests handlers
Requests = Extension.LoadFunction("Requests.pqm");
Requests.PagedList = Requests[PagedList];
Requests.Fetch = Requests[Fetch];

// ############################################################################################################################################################
// ######### COMMON FUNCTIONS #################################################################################################################################
// ############################################################################################################################################################

// Basic fuction that will convert a given table into a navigation table.
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

// ############################################################################################################################################################
// ######### CONNECTOR SETTINGS AND AUTHENTICATION ############################################################################################################
// ############################################################################################################################################################

// Data Source Kind description.
EduFrame = [
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            domainSlug = json[domainSlug]
        in
            { "EduFrame.Contents", domainSlug },
    Authentication = [
        OAuth = [
            Label = Extension.LoadString("OAuthName"),
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = RefreshLogin
        ],
        Key = [
            Label = Extension.LoadString("KeyName"),
            KeyLabel = Extension.LoadString("KeyName")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description.
EduFrame.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ConnectorName"), Extension.LoadString("ConnectorNameHighlight") },
    SourceImage = EduFrame.Icons,
    SourceTypeImage = EduFrame.Icons,
    LearnMoreUrl = "https://drieam.github.io/EduFramePowerBiConnector/"
];

// Load the Eduframe icons for this connector.
EduFrame.Icons = [
    Icon16 = { Extension.Contents("icon16.png"), Extension.Contents("icon20.png"), Extension.Contents("icon24.png"), Extension.Contents("icon32.png") },
    Icon32 = { Extension.Contents("icon32.png"), Extension.Contents("icon40.png"), Extension.Contents("icon48.png"), Extension.Contents("icon64.png") }
];

// Helper method for starting the OAuth flow.
StartLogin = (dataSourcePath, state, display) =>
        let
            AuthorizeUrl = "https://" & Json.Document(dataSourcePath)[domainSlug] & ".eduframe.nl/login/oauth2/auth?" & Uri.BuildQueryString([
                client_id = client_id,
                state = state,
                response_type = "code",
                redirect_uri = redirect_uri])
        in
            [
                LoginUri = AuthorizeUrl,
                CallbackUri = redirect_uri,
                WindowHeight = windowHeight,
                WindowWidth = windowWidth,
                Context = null
            ];

// Helper method for finishing the OAuth flow.
FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query]
    in
        TokenMethod(Parts[code], "authorization_code", context);

RefreshLogin = (resourceUrl, refreshToken) => TokenMethod(refreshToken, "refresh_token");

// Helper method for storing the token.
TokenMethod = (code, grant_type, optional verifier) =>
    let
        codeVerifier = if (verifier <> null) then [code_verifier = verifier] else [],
        codeParameter = if (grant_type = "authorization_code") then [ code = code ] else [ refresh_token = code ], // This way can can handle RefreshLogin automatically using the same method
        query = codeVerifier & codeParameter & [
            client_id = client_id,
            client_secret = client_secret,
            grant_type = grant_type,
            redirect_uri = redirect_uri
        ],

        Response = Web.Contents("https://api.eduframe.nl/login/oauth2/token", [
            Content = Json.FromValue(query),
            Headers = [
                #"Content-type" = "application/json",
                #"Accept" = "application/json"
            ]
        ]),
        Parts = Json.Document(Response)
    in
        Parts;
