// This file contains your Data Connector logic
[Version = "1.0.3"]
section BuildingConnected;

// Forge OAuth2 values
client_id_us = Extension.LoadString("CLIENT_ID_US");

redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";

base_path = "https://developer.api.autodesk.com";
prefix_bc = "/construction/buildingconnected/v2/";
prefix_tt = "/construction/tradetapp/v2/";
authorize_uri = base_path & "/authentication/v2/authorize";
scope = "data:read";
code_challenge_method = "S256";

// ======================= PKCE =========================================
StartLogin = (resourceUrl, state, display) =>
    let
        clientId = client_id_us,
        // We'll generate our code verifier using Guids
        plainTextCodeVerifier = Text.NewGuid() & Text.NewGuid(),
        codeVerifier =
            if (code_challenge_method = "plain") then
                plainTextCodeVerifier
            else if (code_challenge_method = "S256") then
                Base64Url.Encode(Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(plainTextCodeVerifier)))
            else
                error "Unexpected code_challenge_method",

        AuthorizeUrl = authorize_uri
            & "?"
            & Uri.BuildQueryString(
                [
                    client_id = clientId,
                    response_type = "code",
                    code_challenge_method = code_challenge_method,
                    scope = scope,
                    code_challenge = codeVerifier,
                    state = state,
                    redirect_uri = redirect_uri
                ]
            )
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = 720,
            WindowWidth = 1024,
            // Need to roundtrip this value to FinishLogin
            Context = plainTextCodeVerifier // Pass the random string
        ];

// The code verifier will be passed in through the context parameter.
FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query]
    in
        TokenMethod(Parts[code], "authorization_code", context);

TokenMethod = (code, grant_type, optional verifier) =>
    let
        clientId = client_id_us,
        codeVerifier = if (verifier <> null) then [code_verifier = verifier] else [],
        codeParameter = if (grant_type = "authorization_code") then [code = code] else [refresh_token = code],
        query = codeVerifier
            & codeParameter
            & [
                client_id = clientId,
                grant_type = grant_type,
                redirect_uri = redirect_uri
            ],
        ManualHandlingStatusCodes = {},
        Response = Web.Contents(
            base_path & "/authentication/v2" & "/token",
            [
                Content = Text.ToBinary(Uri.BuildQueryString(query)),
                Headers = [
                    #"Content-type" = "application/x-www-form-urlencoded",
                    #"Accept" = "application/json"
                ],
                ManualStatusHandling = ManualHandlingStatusCodes
            ]
        ),
        Parts = Json.Document(Response)
    in
        // check for error in response
        if (Parts[error]? <> null) then
            error Error.Record(Parts[error], Parts[message]?)
        else
            Parts;

//Refresh = (resourceUrl, oldCredentials) => TokenMethod(oldCredentials[refresh_token], "refresh_token");
Refresh = (resourceUrl, refresh_token) => TokenMethod(refresh_token, "refresh_token");

// ===================================================================
// Data Source Kind description
BuildingConnected = [
    TestConnection = (dataSourcePath) => {"BuildingConnected.Contents", null},
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// The items to display in default navigation table
SchemaTable_bc = #table(
    {"Entity", "Type", "UrlPart", "HasUpdateAt"},
    {
        {"Projects", ProjectType, "projects", true} ,
        {"Bid Packages", BidPackageType, "bid-packages", true},
        {"Invites", InviteType, "invites", true},
        {"Bids", BidType, "bids", true},
        {"Project Bid Forms", ProjectBidFormType, "project-bid-forms", true},
        {"Scope-Specific Bid Forms", ScopeSpecificBidFormType, "scope-specific-bid-forms", true},
        {"Opportunities", OpportunityType, "opportunities", true},
        {"Contacts", ContactType, "contacts", true},
        {"Project Team Members", ProjectTeamMembersType, "project-team-members", true},
        {"Offices", OfficeType, "offices", true},
        {"Opportunity Project Pairs", OpportunityProjectPairsType, "opportunity-project-pairs", true},
        {"Certificate Types", CertificateType, "certificate-types", true},
        {"Certifying Agencies", CertificateAgenciesType, "certificate-agencies", true},
        {"Users", UserType, "users", false}
    }
);
SchemaTable_tt = #table(
    {"Entity", "Type", "UrlPart", "HasUpdateAt"},
    {
        {"TT-Financials", FinancialsType, "financials", false},
        {"TT-Qualifications", QualificationsType, "qualifications", true}
    }
);

GetSchemaForEntity = (entity as text, schemaTable as table) as type =>
    try
        schemaTable{[Entity = entity]}[Type]
    otherwise
        let
            message = Text.Format("Couldn't find entity: '#{0}'", {entity})
        in
            Diagnostics.Trace(TraceLevel.Error, message, () => error message, true);

GetUrlPart = (entity as text, schemaTable as table) as text =>
    try
        schemaTable{[Entity = entity]}[UrlPart]
    otherwise
        let
            message = Text.Format("Couldn't find urlPart: '#{0}'", {entity})
        in
            Diagnostics.Trace(TraceLevel.Error, message, () => error message, true);

GetUpdatedAtForEntity = (entity as text, schemaTable as table) as logical =>
    try
        schemaTable{[Entity = entity]}[HasUpdateAt]
    otherwise
        let
            message = Text.Format("Couldn't find HasUpdateAt: '#{0}'", {entity})
        in
            Diagnostics.Trace(TraceLevel.Error, message, () => error message, true);

// Data Source UI publishing description
[DataSource.Kind="BuildingConnected", Publish="BuildingConnected.Publish"]
shared BuildingConnected.Contents = Value.ReplaceType(BuildingConnectedNavTable, BuildingConnectedType);

// Data Source definitions
BuildingConnectedType = type function (
    optional rangeStart as (DateTimeZone.Type meta [
        Documentation.FieldCaption = "Range Start",
        Documentation.FieldDescription = "The start of the range to filter by."
    ]),
    optional rangeEnd as (DateTimeZone.Type meta [
        Documentation.FieldCaption = "Range End",
        Documentation.FieldDescription = "The end of the range to filter by."
    ]))
    as table meta [
        Documentation.Name = "BuildingConnected",
        Documentation.LongDescription = "Returns a table of entities for the given url and entity name.",
        Documentation.Examples = {
            [
                Description = "Get entities for a given url and entity name.",
                Code = "BuildingConnected.Contents(""https://developer.api.autodesk.com"")"
            ]
        }
    ];

// Create Metadata Nav table for base items
BuildingConnectedNavTable = (optional rangeStart as datetimezone, optional rangeEnd as datetimezone) as table =>
    let
        url_bc = Uri.Combine(base_path, prefix_bc),
        url_tt = Uri.Combine(base_path, prefix_tt),
        // Use our schema table as the source of top level items in the navigation tree
        entities_bc = Table.SelectColumns(SchemaTable_bc, {"Entity"}),
        rename_bc = Table.RenameColumns(entities_bc, {{"Entity", "Name"}}),
        entities_tt = Table.SelectColumns(SchemaTable_tt, {"Entity"}),
        rename_tt = Table.RenameColumns(entities_tt, {{"Entity", "Name"}}),
        // Add Data as a calculated column
        withData_bc = Table.AddColumn(rename_bc, "Data", each GetEntity(url_bc, [Name], SchemaTable_bc, rangeStart, rangeEnd), type table),
        withData_tt = Table.AddColumn(rename_tt, "Data", each GetEntity(url_tt, [Name], SchemaTable_tt, rangeStart, rangeEnd), type table),
        withData = Table.Combine({withData_bc, withData_tt}),
        // Add ItemKind and ItemName as fixed text values
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Table", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table", type text),
        // Indicate that the node should not be expandable
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true, type logical),
        // Generate the nav table
        navTable = Table.ToNavigationTable(withIsLeaf, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

/* BuildingConnected.View = (baseUrl as text, entity as text) as table =>
    let
        // Implementation of Table.View handlers.
        //
        // We wrap the record with Diagnostics.WrapHandlers() to get some automatic
        // tracing if a handler returns an error.
        //
        View = (state as record) =>
            Table.View(
                null,
                Diagnostics.WrapHandlers(
                    [
                        // Returns the table type returned by GetRows()
                        GetType = () => CalculateSchema(state),
                        // Called last - retrieves the data from the calculated URL
                        GetRows = () =>
                            let
                                finalSchema = CalculateSchema(state),
                                finalUrl = CalculateUrl(state),
                                result = BuildingConnected.Feed(finalUrl, finalSchema),
                                appliedType = Table.ChangeType(result, finalSchema)
                            in
                                appliedType,
                        // GetRowCount - called when all we want is the total row count.
                        // Most OData services support $count, but it only works if
                        // no other query parameters are sent (i.e. $top, or $filter).
                        // Our implementation will first check for other query state -
                        // if there are any state fields set by other handlers, we
                        // return "..." unimplemented, because we won't be able to fold
                        // the request to the server.
                        // GetRowCount = () as number =>
                        //     if (
                        //         Record.FieldCount(
                        //             Record.RemoveFields(state, {"Url", "Entity", "Schema"}, MissingField.Ignore)
                        //         ) > 0
                        //     ) then
                        //         ...
                        //     else
                        //         let
                        //             newState = state & [RowCountOnly = true],
                        //             finalUrl = CalculateUrl(newState),
                        //             value = BuildingConnected.Scalar(finalUrl),
                        //             converted = Number.FromText(value)
                        //         in
                        //             converted,
                        // OnTake - handles the Table.FirstN transform, limiting
                        // the maximum number of rows returned in the result set.
                        // The count value should be >= 0.
                        //OnTake = (count as number) => let newState = state & [Top = count] in @View(newState),
                        //
                        // Helper functions
                        //
                        // Retrieves the cached schema. If this is the first call
                        // to CalculateSchema, the table type is calculated based on
                        // entity name that was passed into the function.
                        CalculateSchema = (state) as type =>
                            if (state[Schema]? = null) then
                                GetSchemaForEntity(entity, SchemaTable_bc)
                            else
                                state[Schema],
                        // Calculates the final URL based on the current state.
                        CalculateUrl = (state) as text =>
                            let
                                entityUrl = Text.Replace(Text.Lower(entity), " ", "-"),
                                urlWithEntity = Uri.Combine(state[Url], entityUrl),
                                // Check for $count. If all we want is a row count,
                                // then we add /$count to the path value (following the entity name).
                                // urlWithRowCount =
                                //     if (state[RowCountOnly]? = true) then
                                //         urlWithEntity & "?limit=100"
                                //     else
                                //         urlWithEntity,
                                // Uri.BuildQueryString requires that all field values
                                // are text literals.
                                defaultQueryString = [],
                                // Check for Top defined in our state
                                qsWithTop =
                                    if (state[Top]? <> null) then
                                        defaultQueryString & [#"limit" = Number.ToText(state[Top])]
                                    else
                                        defaultQueryString,
                                encodedQueryString = Uri.BuildQueryString(qsWithTop),
                                finalUrl = urlWithEntity & "?" & encodedQueryString
                            in
                                finalUrl
                    ]
                )
            )
    in
        View([Url = baseUrl, Entity = entity]);

// Similar to BuildingConnected.Feed, but is expecting back a scalar value.
// This function returns the value from the service as plain text.
BuildingConnected.Scalar = (url as text) as text =>
    let
        _url = Diagnostics.LogValue("BuildingConnected.Scalar url", url),
        headers = DefaultRequestHeaders & [
            #"Accept" = "text/plain"
        ],
        response = Web.Contents(_url, [Headers = headers]),
        toText = Text.FromBinary(response)
    in
        toText; 
        */

BuildingConnected.Feed = (url as text, optional schema as type, optional rangeStart as datetimezone, optional rangeEnd as datetimezone) as table =>
    let
        _url = Diagnostics.LogValue("Accessing url", url),
        _schema = Diagnostics.LogValue("Schema type", schema),
        result = GetAllPagesByNextLink(_url, _schema, rangeStart, rangeEnd),
        appendPaginatedResults = PaginateNestedResults(result, _schema, rangeStart, rangeEnd)
    in
        appendPaginatedResults;

GetEntity = (url as text, entity as text, schemaTable as table, optional rangeStart as datetimezone, optional rangeEnd as datetimezone) as table =>
    let
        urlPart = GetUrlPart(entity, schemaTable),
        // If entity doesn't support updatedAt, we don't need to pass rangeStart and rangeEnd
        getHasUpdatedAt = GetUpdatedAtForEntity(entity, schemaTable),
        fullUrl = Uri.Combine(url, urlPart),
        schema = GetSchemaForEntity(entity, schemaTable),
        result = if getHasUpdatedAt then BuildingConnected.Feed(fullUrl, schema, rangeStart, rangeEnd) else BuildingConnected.Feed(fullUrl, schema),
        appliedSchema = Table.ChangeType(result, schema)
    in
        appliedSchema;
 
GetPage = (url as text, optional schema as type) as table =>
    let
        response = Web.Contents(url, [Headers = DefaultRequestHeaders, ManualStatusHandling = {401, 403}]),
        statusCode = Value.Metadata(response)[Response.Status],
        body = Json.Document(response),
        nextLink = GetNextLink(body[pagination]),
        // If we have no schema, use Table.FromRecords() instead
        // (and hope that our results all have the same fields).
        // If we have a schema, expand the record using its field names
        data =
            if (schema = null) then
                Table.FromRecords(body[results])
            else
                let
                    asTable = Table.FromList(body[results], Splitter.SplitByNothing(), {"Column1"}),
                    fields = Record.FieldNames(Type.RecordFields(Type.TableRow(schema))),
                    expanded = Table.ExpandRecordColumn(asTable, "Column1", fields)
                in
                    expanded
    in
        if statusCode = 401 or statusCode = 403 then
            if body[detail] = "NO_BC_ACCOUNT" then
                error Error.Record("DataSource.Error","No BC Account found. " & 
                                "If you have a BC account, check to make sure you have connected it to your AutodeskID. " & 
                                "More info here: https://support.buildingconnected.com/hc/en-us/articles/360047910993-How-to-connect-your-Autodesk-ID-to-BuildingConnected")
            else
                error Error.Record("DataSource.Error","The following error occured: " & body[detail])
        else
            data meta [NextLink = nextLink];

PaginateNestedResults = (feedResult as table,optional schema as type, optional rangeStart as datetimezone, optional rangeEnd as datetimezone) as table =>
    let
        // Iterate over each row in the feedResult
        paginatedResult = Table.TransformRows(feedResult, (row) =>
            let
                // Check if the row has 'lineItems' or 'plugs'
                hasLineItems = schema = BidType or schema = ProjectBidFormType or schema = ScopeSpecificBidFormType,
                hasPlugs = schema = BidType,
                isQualificationsType = schema = QualificationsType,

                // Check if the row has 'lineItems' or 'plugs' and they have a 'pagination' field with a non-null 'cursorState'
                lineItems = if hasLineItems and Record.FieldOrDefault(Record.FieldOrDefault(row, "lineItems"), "pagination")[cursorState] <> null then
                                let
                                    url = 
                                        if schema = BidType then
                                            base_path & prefix_bc & "bids/" & row[id] & "/line-items"
                                        else if schema = ProjectBidFormType then
                                            base_path & prefix_bc & "project-bid-forms/" & row[id] & "/line-items"
                                        else if schema = ScopeSpecificBidFormType then
                                            base_path & prefix_bc & "scope-specific-bid-forms/" & row[id] & "/line-items"
                                        else
                                            error "Unsupported schema",
                                    paginatedLineItems = GetAllPagesByNextLink(url, BidLineItemType, rangeStart, rangeEnd)
                                in
                                    paginatedLineItems
                            else
                                if hasLineItems then row[lineItems][results] else null,
                plugs = if hasPlugs and Record.FieldOrDefault(Record.FieldOrDefault(row, "plugs"), "pagination")[cursorState] <> null then
                                let
                                    url = base_path & prefix_bc & "bids/" & row[id] & "/plugs",
                                    paginatedPlugs = GetAllPagesByNextLink(url, BidPlugType, rangeStart, rangeEnd)
                                in
                                    paginatedPlugs
                            else
                                if hasPlugs then row[plugs][results] else null,
                companyOfficeAddresses = if isQualificationsType and Record.FieldOrDefault(Record.FieldOrDefault(row, "companyOfficeAddresses"), "pagination")[cursorState] <> null then
                                let
                                    url = base_path & prefix_tt & "qualifications/" & row[id] & "/company-office-addresses",
                                    paginatedCompanyOfficeAddresses = GetAllPagesByNextLink(url, QualificationsType, rangeStart, rangeEnd)
                                in
                                    paginatedCompanyOfficeAddresses
                            else
                                if isQualificationsType then row[companyOfficeAddresses][results] else null,
                customQuestions = if isQualificationsType and Record.FieldOrDefault(Record.FieldOrDefault(row, "customQuestions"), "pagination")[cursorState] <> null then
                                let
                                    url = base_path & prefix_tt & "qualifications/" & row[id] & "/custom-questions",
                                    paginatedCustomQuestions = GetAllPagesByNextLink(url, QualificationsType, rangeStart, rangeEnd)
                                in
                                    paginatedCustomQuestions
                            else
                                if isQualificationsType then row[customQuestions][results] else null
            in
                // Replace the 'lineItems' and 'plugs' in the row with the paginated results depending on the schema
                if schema = BidType then Record.TransformFields(row, {
                    {"lineItems", each Record.TransformFields(_, {"results", each lineItems})},
                    {"plugs", each Record.TransformFields(_, {"results", each plugs})}
                })
                else if schema = ProjectBidFormType or schema = ScopeSpecificBidFormType then Record.TransformFields(row, {"lineItems", each Record.TransformFields(_, {"results", each lineItems})})
                else if schema = QualificationsType then Record.TransformFields(row, {
                    {"companyOfficeAddresses", each Record.TransformFields(_, {"results", each companyOfficeAddresses})},
                    {"customQuestions", each Record.TransformFields(_, {"results", each customQuestions})}
                })
                else row
        ),
        // Convert the list of records back to a table
        paginatedTable = Table.FromRecords(paginatedResult)
    in
        paginatedTable;

// Read all pages of data.
// After every page, we check the "NextLink" record on the metadata of the previous request.
// Table.GenerateByPage will keep asking for more pages until we return null.
GetAllPagesByNextLink = (url as text, optional schema as type, optional rangeStart as datetimezone, optional rangeEnd as datetimezone) as table =>
    Table.GenerateByPage(
        (previous) =>
            let
                // if previous is null, then this is our first page of data
                //nextLink = if (previous = null) then url else Value.Metadata(previous)[cursorState]?,
                cursorState = Value.Metadata(previous)[NextLink]?,
                defaultQueryString = [],
                qsWithUpdatedAt = 
                    if (rangeStart <> null and rangeEnd <> null) then
                        [
                            #"filter[updatedAt]" = DateTimeZone.ToText(rangeStart, "yyyy-MM-ddThh:mm:ss.fffZ") & ".." & DateTimeZone.ToText(rangeEnd, "yyyy-MM-ddThh:mm:ss.fffZ")
                        ]
                    else if (rangeStart <> null and rangeEnd = null) then
                        [
                            #"filter[updatedAt]" = DateTimeZone.ToText(rangeStart, "yyyy-MM-ddThh:mm:ss.fffZ") & ".."
                        ]
                    else if (rangeStart = null and rangeEnd <> null) then
                        [
                            #"filter[updatedAt]" = ".." & DateTimeZone.ToText(rangeEnd, "yyyy-MM-ddThh:mm:ss.fffZ")
                        ]
                    else
                        defaultQueryString,
                qsWithCursorState = 
                    if (cursorState <> null) then
                        qsWithUpdatedAt & [cursorState = cursorState]
                    else
                        qsWithUpdatedAt,
                nextLink =
                    if (previous <> null and cursorState = null) then
                        null
                    else
                        url & "?" & Uri.BuildQueryString(qsWithCursorState),
                // if NextLink was set to null by the previous call, we know we have no more data
                page = if (nextLink <> null) then GetPage(nextLink, schema) else null
            in
                page
    );

// In this implementation, 'response' will be the parsed body of the response after the call to Json.Document.
// We look for the '@odata.nextLink' field and simply return null if it doesn't exist.
GetNextLink = (response) as nullable text => Record.FieldOrDefault(response, "cursorState");

DefaultRequestHeaders = [
    #"Accept" = "application/json"
];

Value.WaitFor = (producer as function, interval as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, null},
            (state) => state{0} <> null and (count = null or state{0} < count),
            (state) =>
                if state{1} <> null then
                    {null, state{1}}
                else
                    {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), interval(state{0}))},
            (state) => state{1}
        )
    in
        List.Last(list);

Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name), asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// Data Source UI publishing description
BuildingConnected.Publish = [
    Beta = true,
    Category = "Online",
    ButtonText = {Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp")},
    LearnMoreUrl = "https://www.autodesk.com/",
    SourceImage = BuildingConnected.Icons,
    SourceTypeImage = BuildingConnected.Icons
];

BuildingConnected.Icons = [
    Icon16 = {
        Extension.Contents("BuildingConnected16.png"),
        Extension.Contents("BuildingConnected20.png"),
        Extension.Contents("BuildingConnected24.png"),
        Extension.Contents("BuildingConnected32.png")
    },
    Icon32 = {
        Extension.Contents("BuildingConnected32.png"),
        Extension.Contents("BuildingConnected40.png"),
        Extension.Contents("BuildingConnected48.png"),
        Extension.Contents("BuildingConnected64.png")
    }
];

Schemas = Extension.LoadFunction("Schemas.pqm");
ProjectType = Schemas[ProjectType];
BidPackageType = Schemas[BidPackageType];
InviteType = Schemas[InviteType];
BidType = Schemas[BidType];
ProjectBidFormType = Schemas[ProjectBidFormType];
ScopeSpecificBidFormType = Schemas[ScopeSpecificBidFormType];
OpportunityType = Schemas[OpportunityType];
ContactType = Schemas[ContactType];
UserType = Schemas[UserType];
BidLineItemType = Schemas[BidLineItemType];
BidPlugType = Schemas[BidPlugType];
ProjectBidFormLineItemType = Schemas[ProjectBidFormLineItemType];
ScopeSpecificBidFormLineItemType = Schemas[ScopeSpecificBidFormLineItemType];
ProjectTeamMembersType = Schemas[ProjectTeamMembersType];
OfficeType = Schemas[OfficeType];
OpportunityProjectPairsType = Schemas[OpportunityProjectPairsType];
CertificateType = Schemas[CertificateType];
CertificateAgenciesType = Schemas[CertificateAgenciesType];
FinancialsType = Schemas[FinancialsType];
QualificationsType = Schemas[QualificationsType];

Table.ChangeType = Extension.LoadFunction("Table.ChangeType.pqm");
Table.GenerateByPage = Extension.LoadFunction("Table.GenerateByPage.pqm");
Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");

Diagnostics.LogValue = Diagnostics[LogValue];
Diagnostics.LogFailure = Diagnostics[LogFailure];
Diagnostics.WrapHandlers = Diagnostics[WrapHandlers];

Base64Url.Encode = (s) => Text.Replace(Text.Replace(Text.BeforeDelimiter(Binary.ToText(s,BinaryEncoding.Base64),"="),"+","-"),"/","_");