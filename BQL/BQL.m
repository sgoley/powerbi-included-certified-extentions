// This file contains your Data Connector logic
[Version = "1.0.15"]
section BQL;

// shared marks something as a thing that should be exported
[DataSource.Kind="BQL", Publish="BQL.Publish"]
shared BQL.Query = Value.ReplaceType(EntryPointImpl, EntryPointType);

ConnectorVersion = "1.0.15";

EntryPointType = type function (
    BQLQuery as (type text meta [
        DataSource.Path = false,
        Documentation.FieldCaption = Extension.LoadString("Bql.Query.Dialog.Argument.Caption"),
        Documentation.SampleValues = { "get(PORT_INFO) for(PortUniv(type=PREP))" }
    ])
    )
    as table meta [
        Documentation.Name = Extension.LoadString("Bql.Query.Dialog.Title") & "  v" & ConnectorVersion,
        Documentation.Description = Extension.LoadString("Bql.Function.Description")

    ];
        
EntryPointImpl = (bqlQuery as text) =>
    let
        bqlQuery1 =  Diagnostics.LogTrace(TraceLevel.Information, Text.Combine({"Connector version ", ConnectorVersion}), bqlQuery),
        bqlQuery2 = Diagnostics.LogValue("BQL query", bqlQuery1),
        table = if bqlQuery2 = null then error Error.Record("Invalid argument", "BQL Query argument cannot be null")
            else if Text.Clean(bqlQuery2) = "" then error Error.Record("Invalid argument", "BQL Query argument cannot be empty")
            else GetData(bqlQuery2, SendPostQuery)
        in
            table;

EscapeQuery = (query as text) => Text.Replace(Text.Replace(Text.Replace(query, """", "\\\"""), "#(lf)", ""), "#(cr)", "");

RequestBqlData = (query as text, sendPostRequestFn as function) => 
    let
        escapedQuery = EscapeQuery(query),
        body = "{""query"":""query {"
            & "bqlDirectAsync(request: { expression: \""" & escapedQuery & "\"" }) {"
            & "... on BqlDirectAsyncStartResponse { ticket }"
            & "... on BqlDirectDataResponse"
            & "  { results { id data { tableVal { headers "
            & "  columns {"
            & "  ... on BqlNumColumn { numColumn }"
            & "  ... on BqlStringColumn { strColumn }"
            & "  ... on BqlDateColumn { dateColumn }"
            & "  ... on BqlNumColumnRange { numVal length }"
            & "  ... on BqlDateColumnRange { dateVal length }"
            & "  ... on BqlStringColumnRange { strVal length }"
            & "  } } } } }"
            & "} }"",""variables"":{}}",
        body1 = Diagnostics.LogValue("Request body", body),
        rawResult = sendPostRequestFn(body1, 0),
        rawResultText =  Text.FromBinary(rawResult),
        trunctedRawResultText = Text.Start(rawResultText, 1000),
        rawResultText1 = Diagnostics.LogTrace(TraceLevel.Information, Text.Combine({"Raw response (truncated): ", trunctedRawResultText}), rawResultText),
        parsedResult = try Json.Document(rawResultText1)
            otherwise error Error.Record("Invalid Response", "Unable to read data due to invalid response format.", rawResultText1),
        parsedResultExtracted = if not Record.HasFields(parsedResult, "errors") and Record.HasFields(parsedResult, "data") and parsedResult[data] <> null and Record.HasFields(parsedResult[data], "bqlDirectAsync")
            then parsedResult[data][bqlDirectAsync]
            else parsedResult
    in
        parsedResultExtracted;

        
TryRequestWithTicket = (i as number, ticket as text, sendPostRequestFn as function) =>
    let
        attempt = Number.ToText(i + 1),
        body = "{""query"":""query {"
            & "bqlDirectCheckAsync(request: { ticket: \""" & ticket & "\"" })"
            & "  { results { id data { tableVal { headers "
            & "  columns {"
            & "  ... on BqlNumColumn { numColumn }"
            & "  ... on BqlStringColumn { strColumn }"
            & "  ... on BqlDateColumn { dateColumn }"
            & "  ... on BqlNumColumnRange { numVal length }"
            & "  ... on BqlDateColumnRange { dateVal length }"
            & "  ... on BqlStringColumnRange { strVal length }"
            & "  } } } }"
            & "} }"",""variables"":{}}",
        body1 = Diagnostics.LogValue("Ticket polling attempt: " & attempt, body),
        rawResult = sendPostRequestFn(body1, i + 1),
        rawResultText =  Text.FromBinary(rawResult),
        trunctedRawResultText = Text.Start(rawResultText, 1000),
        rawResultText1 = Diagnostics.LogTrace(TraceLevel.Information, Text.Combine({"Raw response from ticket polling attempt: " & attempt & " (truncated): ", trunctedRawResultText}), rawResultText),
        parsedResult = try Json.Document(rawResultText1)
            otherwise error Error.Record("Invalid Response", "Unable to read data due to invalid response format.", rawResultText1),
        parsedResultExtracted = if not Record.HasFields(parsedResult, "errors") and Record.HasFields(parsedResult, "data") and parsedResult[data] <> null and Record.HasFields(parsedResult[data], "bqlDirectCheckAsync")
            then (if parsedResult[data][bqlDirectCheckAsync] = null then null else parsedResult[data][bqlDirectCheckAsync])
            else parsedResult
    in
        parsedResultExtracted;

GetData = (query as text, sendPostRequestFn as function) =>
    let
        parsedResult = RequestBqlData(query, sendPostRequestFn),
        parsedResult1 = if Record.HasFields(parsedResult, "ticket")
            then Value.WaitFor(
                    (i) => TryRequestWithTicket(i, parsedResult[ticket], sendPostRequestFn),
                    (i) => #duration(0, 0, 0, Configuration.PollDelay),
                    Configuration.PollRetryAttempts
                )
            else parsedResult, 
        
        respError = if parsedResult1 <> null
            then GetError(parsedResult1)
            else error Error.Record("Request timeout", "Request has timed out"),
        table = if respError <> null then respError else ExtractData(parsedResult1, query)
    in
        table;

ExtractData = (parsedResult as record, bqlQuery as text) =>
    let
        resultList = try parsedResult[results]
            otherwise error Error.Record("Invalid Response", "Unable to get results from response", parsedResult),
        table = GetTableValue(resultList, bqlQuery)
    in
        table;


SendPostQuery = (body as text, requestNumber as number) => 
    let 
    
        rawResult = Web.Contents(Configuration.BqlUrl,
        [
             Headers = [
                #"Accept" = "text/json",
                #"Accept-Encoding" = "gzip",
                #"Content-type" = "application/json"
             ],
             Content = Text.ToBinary(body),
             IsRetry = true,
             Timeout = #duration(0, 0, 1, 0)
        ])
    in
        rawResult;

GetColumnType = (column as any) => 
    let
        typeName = if Record.HasFields(column, "strColumn") or Record.HasFields(column, "strVal") then type text
                   else if Record.HasFields(column, "numColumn") or Record.HasFields(column, "numVal") then type number
                   else if Record.HasFields(column, "dateColumn") or Record.HasFields(column, "dateVal") then type date
                   else error Error.Record("Get column type error", "Unknown input data type.")
    in
        typeName;

GetColumn = (columnJson as any) => 
    let
        column = if Record.HasFields(columnJson, "strColumn") then columnJson[strColumn]
                 else if Record.HasFields(columnJson, "strVal") then List.Generate(() => 0, each _ < columnJson[length], each _ + 1, (i) => columnJson[strVal])
                 else if Record.HasFields(columnJson, "numColumn") then columnJson[numColumn]
                 else if Record.HasFields(columnJson, "numVal") then List.Generate(() => 0, each _ < columnJson[length], each _ + 1, (i) => columnJson[numVal])
                 else if Record.HasFields(columnJson, "dateColumn") then List.Transform(columnJson[dateColumn], (isoDateTime) => ParseDate(isoDateTime))
                 else if Record.HasFields(columnJson, "dateVal") then List.Generate(() => 0, each _ < columnJson[length], each _ + 1, (i) => ParseDate(columnJson[dateVal]))
                 else error Error.Record("Get column error", "Unknown input data type.")
    in
        column;

ParseDate = (isoDateTime) =>
    let
        parsed = if isoDateTime <> null then Date.FromText(Text.Range(isoDateTime, 0, Text.Length(isoDateTime) - 10))
                 else null
    in
        parsed;

MapResults = (json as any) => 
    let
        inputTable = json[data][tableVal],
        indexes = List.Generate(() => 0, each _ < List.Count(inputTable[headers]), each _ + 1),
        headers = List.Transform(indexes, (i) => inputTable[headers]{i}),
        columns = List.Transform(indexes, (i) => GetColumn(inputTable[columns]{i})),
        
        table = Table.FromColumns(columns, headers),
        tableTypes = List.Accumulate(indexes, {}, (state, i) => List.Combine({state, {{inputTable[headers]{i}, GetColumnType(inputTable[columns]{i})}}})),
        typedTable = Table.TransformColumnTypes(table, tableTypes),
        tableEntry = [id = json[id], table = typedTable]
    in
        tableEntry;

GetTableValue = (resultList as list, bqlQuery as text) => 
    let
        tables = List.Transform(resultList, MapResults),        

        objects = #table(
            {"Name",  "Key",   "Data", "ItemKind", "ItemName", "IsLeaf"},
            List.Transform(tables, (t) => {t[id], t[id], t[table],  "Table",    "Table",    true})
        ),
        table = if List.Count(tables) = 1 
                then tables{0}[table]
                else Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        table;

GetError = (result) =>
    let
        hasError = Record.HasFields(result, "errors") and List.Count(result[errors]) > 0,
        hasCategory = hasError
            and Record.HasFields(result[errors]{0}, "extensions")
            and Record.HasFields(result[errors]{0}[extensions], "category"),
        reason = if hasCategory
            then result[errors]{0}[extensions][category]
            else "Data source error",
        respError = if hasError
            then error Error.Record(reason, result[errors]{0}[message])
            else null
    in
        respError;


StartLogin = (resourceUrl, state, display) =>
    let
        // we'll generate our code verifier using Guids
        codeVerifier = Text.NewGuid() & Text.NewGuid(),
        authorizeUrl = Configuration.OAuthBaseUrl & "/as/authorization.oauth2?" & Uri.BuildQueryString([
            client_id = Configuration.ClientId,
            response_type = "code",            
            code_challenge_method = "plain",
            code_challenge = codeVerifier,
            state = state,
            redirect_uri = Configuration.RedirectUri
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = Configuration.RedirectUri,
            WindowWidth = 1024,
            WindowHeight = 768,
            Context = codeVerifier  // need to roundtrip this
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        parts = Uri.Parts(callbackUri)[Query],
        err = if Record.HasFields(parts, "error") 
            then "Authentication failed with a status: """ & parts[error] & """"
            else "code query param was not provided",
        code = if Record.HasFields(parts, "code") 
            then parts[code] 
            else error Error.Record("AuthenticationError", err) 
    in
        TokenMethod(code, "authorization_code", context);

TokenMethod = (code, grantType, optional verifier) =>
    let
        codeVerifier = if (verifier <> null) then [code_verifier = verifier] else [],
        codeParameter = if (grantType = "authorization_code") then [ code = code ] else [ refresh_token = code ],
        query = codeVerifier & codeParameter & [
            client_id = Configuration.ClientId,
            client_secret = Configuration.ClientSecret,
            grant_type = grantType,
            redirect_uri = Configuration.RedirectUri
        ],

        Response = Web.Contents(Configuration.OAuthBaseUrl & "/as/token.oauth2", [
            Content = Text.ToBinary(Uri.BuildQueryString(query)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            IsRetry = true
        ]),
        Parts = Json.Document(Response)
    in
        // check for error in response
        if (Parts[error]? <> null) then 
            error Error.Record("TokenResponseError", Parts[error], Parts[message]?)
        else
            Parts;

Refresh = (resourceUrl, refresh_token) => TokenMethod(refresh_token, "refresh_token");

TestConnection = (dataSourcePath) => { "BQL.Query", "test_connection" };

// Data Source Kind description
BQL = [
    TestConnection = TestConnection,
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh,
            Label = Extension.LoadString("Bql.Auth.Dialog.AccountLabel")
        ]
    ],
    Icons = BQL.Icons,
    Label = Extension.LoadString("Bql.DataSource.Label")
];

// Data Source UI publishing description
BQL.Publish = [
    SupportsDirectQuery = false,
    Beta = Configuration.IsBeta,
    Category = "Other",
    ButtonText = { Extension.LoadString("Bql.Button.Title"), Extension.LoadString("Bql.Button.Help") },
    LearnMoreUrl = "https://officetools.bloomberg.com/bi/powerbiconnector",
    SourceImage = BQL.Icons,
    SourceTypeImage = BQL.Icons
];

BQL.Icons = [
    Icon16 = {
        Extension.Contents("Bloomberg16.png"),
        Extension.Contents("Bloomberg20.png"),
        Extension.Contents("Bloomberg24.png"),
        Extension.Contents("Bloomberg32.png")
    },
    Icon32 = {
        Extension.Contents("Bloomberg32.png"),
        Extension.Contents("Bloomberg40.png"),
        Extension.Contents("Bloomberg48.png"),
        Extension.Contents("Bloomberg64.png")
    }
];


// 
// Load common library functions
// 
// TEMPORARY WORKAROUND until we're able to reference other M modules
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogTrace = if Configuration.EnableTraceOutput then Diagnostics.Trace else (level, message, value) => value;
Diagnostics.LogValue = if Configuration.EnableTraceOutput then Diagnostics[LogValue] else (prefix, value) => value;

// Polling helper funciton
Value.WaitFor = (producer as function, interval as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, null},
            (state) => state{0} <> null and (count = null or state{0} <= count),
            (state) => if state{1} <> null then {null, state{1}} else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), interval(state{0}))},
            (state) => state{1})
    in
        List.Last(list);

// Configuration module
Configuration = Extension.LoadFunction("Configuration.pqm");
Configuration.OAuthBaseUrl = Configuration[OAuthBaseUrl];
Configuration.RedirectUri = Configuration[RedirectUri];
Configuration.ClientId = Configuration[ClientId];
Configuration.ClientSecret = Configuration[ClientSecret];
Configuration.BqlUrl = Configuration[BqlUrl];
Configuration.PollRetryAttempts = Configuration[PollRetryAttempts];
Configuration.PollDelay = Configuration[PollDelay];
Configuration.IsBeta = Configuration[IsBeta];
Configuration.EnableTraceOutput = Configuration[EnableTraceOutput];

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

/* Functions that are needed for unit testing.
 * Build will append a line to share this record for the Test configuration. */
TestExports = [
    Main = [
        GetData = GetData
    ],
    Utils = [
        LoadFunction = Extension.LoadFunction,
        LoadFile = (name as text) => Extension.Contents(name)
    ]
];
