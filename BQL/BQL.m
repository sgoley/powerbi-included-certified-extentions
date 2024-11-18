// This file contains your Data Connector logic
[Version = "1.1.3"]
section BQL;

// shared marks something as a thing that should be exported
[DataSource.Kind="BQL", Publish="BQL.Publish"]
shared BQL.Query = Value.ReplaceType(EntryPointImpl, EntryPointType);

ConnectorVersion = "1.1.3";

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

JWT = Extension.LoadFunction("JWT.pqm");
JWT.DecodeJWT = JWT[DecodeJWT];

// Legacy module
Legacy = Extension.LoadFunction("BQL-legacy.pqm");
Legacy.test_function = Legacy[test_function];
Legacy.LoadLegacyData = Legacy[LoadLegacyData];

// paginated module
Paginated = Extension.LoadFunction("BQL-paginated.pqm");
Paginated.RequestBqlDataPaginated = Paginated[RequestBqlDataPaginated];
Paginated.LoadPaginatedData = Paginated[LoadPaginatedData];

// Utils
Utils = Extension.LoadFunction("BQL-utils.pqm");

Diagnostics.LogTrace = Utils[LogTrace];
Diagnostics.LogValue = Utils[LogValue];
CheckGraphQLErrors = Utils[CheckGraphQLErrors];

// Configuration module
Configuration = Extension.LoadFunction("Configuration.pqm");
Configuration.OAuthBaseUrl = Configuration[OAuthBaseUrl];
Configuration.RedirectUri = Configuration[RedirectUri];
Configuration.ClientId = Configuration[ClientId];
Configuration.BqlUrl = Configuration[BqlUrl];
Configuration.IsBeta = Configuration[IsBeta];
Configuration.EnableTraceOutput = Configuration[EnableTraceOutput];
Configuration.CcrtSubjectHeader =  Record.FieldOrDefault(Configuration, "CcrtSubjectHeader", null);

TestExports = [
    Main = [
        GetData = GetDataPaginated,
        TokenMethod = TokenMethod
    ],
    Utils = [
        LoadFunction = Extension.LoadFunction,
        LoadFile = (name as text) => Extension.Contents(name)
    ]
];

EntryPointType = type function (
    BQLQuery as (type text meta [
        DataSource.Path = false,
        Documentation.FieldCaption = Extension.LoadString("Bql.Query.Dialog.Argument.Caption"),
        Documentation.SampleValues = { "get(PORT_INFO) for(PortUniv(type=PREP))" },
        Formatting.IsMultiLine = true,
        Formatting.IsCode = true
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
        table = if bqlQuery2 = null
            then error Error.Record("Invalid argument", "BQL Query argument cannot be null")
            else if Text.Clean(bqlQuery2) = ""
                then error Error.Record("Invalid argument", "BQL Query argument cannot be empty")
            else GetDataPaginated(bqlQuery2, SendPostQuery)
        in
            table;

LoadQueryType = (parsedResult as record) =>
    let
        responseType = if parsedResult[data][bqlPaginated][paginatedResponse] = null
            then  "legacy"
            else  "paginated"
    in
        responseType;


GetDataPaginated = (query as text, sendPostRequestFn as function) =>
    let
        offset = 0,
        firstPage = Paginated.RequestBqlDataPaginated(query, offset, sendPostRequestFn),
        validatedFirstPage = CheckGraphQLErrors(firstPage),
        responseType = LoadQueryType(validatedFirstPage),
        responseType_ = Diagnostics.LogValue("responseType", responseType),
        table =
            if
                responseType_="legacy"
            then
                Legacy.LoadLegacyData(query, firstPage, sendPostRequestFn)
            else
                Paginated.LoadPaginatedData(firstPage, offset, sendPostRequestFn)
    in
        table;

SendPostQuery = (body as text, requestNumber as number) =>
    let
        headers = [
            #"Accept" = "text/json",
            #"Accept-Encoding" = "gzip",
            #"Content-type" = "application/json"
        ],
        headersWithCcrtSubject =
            if Configuration.CcrtSubjectHeader <> null
            then Record.AddField(headers, "CCRT-Subject", Configuration.CcrtSubjectHeader)
            else headers,
        rawResult = Web.Contents(Configuration.BqlUrl,
        [
             Headers = headersWithCcrtSubject,
             Content = Text.ToBinary(body),
             IsRetry = true,
             Timeout = #duration(0, 0, 1, 0)
        ])
    in
        rawResult;

SendTokenRequest = (query as record) =>
    Web.Contents(Configuration.OAuthBaseUrl & "/as/token.oauth2", [
        Content = Text.ToBinary(Uri.BuildQueryString(query)),
        Headers = [
            #"Content-type" = "application/x-www-form-urlencoded",
            #"Accept" = "application/json"
        ],
        IsRetry = true
    ]);

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
            redirect_uri = Configuration.RedirectUri,
            scope = "bloomberg:bi:bql-query"
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
            else error Error.Record("AuthenticationError", err),
        clientCreds = [ clientId = Configuration.ClientId ]
    in
        TokenMethod(code, "authorization_code", SendTokenRequest, clientCreds, context);

TokenMethod = (code, grantType, sendTokenRequestFn as function, clientCreds as record, optional verifier) =>
    let
        codeVerifier = if (verifier <> null) then [code_verifier = verifier] else [],
        codeParameter = if (grantType = "authorization_code") then [ code = code ] else [ refresh_token = code ],
        query = codeVerifier & codeParameter & [
            client_id = clientCreds[clientId],
            grant_type = grantType,
            redirect_uri = Configuration.RedirectUri
        ],
        response = sendTokenRequestFn(query),
        // The outer JSON that contains access_token
        credential = Json.Document(response),
        // check for error in response
        validatedCredential = if (credential[error]? <> null) then
            error Error.Record("TokenResponseError", credential[error], credential[message]?)
        else
            credential,
        // access_token itself decoded and parsed
        decodedAccessToken = try JWT.DecodeJWT(validatedCredential[access_token])
            otherwise error Error.Record("Authentication Error","Could not decode access token."),

        ParseAdminCredential = (adminTokenString) => try Json.Document(adminTokenString)
            otherwise error Error.Record("Admin Authentication Error", "Could not parse admin token."),
        // If the decoded access_token has an inner adminToken attribute, use that as the access token.
        adminCredential = if (Record.HasFields(decodedAccessToken, "adminToken") and decodedAccessToken[adminToken] <> "")
            then ParseAdminCredential(decodedAccessToken[adminToken])
            else null,
        validatedAdminCredential = if (adminCredential <> null and Record.HasFields(adminCredential, "error_msg"))
            then error Error.Record("Admin Authentication Error", adminCredential[error_msg])
            else adminCredential,
        finalCredential = if (validatedAdminCredential <> null)
            then validatedAdminCredential
            else validatedCredential
    in
        finalCredential;

Refresh = (clientApplication, dataSourcePath, oldCredential) =>
    let
        refreshToken = oldCredential[refresh_token],
        decodedAccessToken = try JWT.DecodeJWT(oldCredential[access_token])
            otherwise error Error.Record("Authentication Error","Could not decode access token."),
        // Could be the admin token client ID if an admin token is being used instead of the regular client ID
        clientId = decodedAccessToken[client_id],
        newCredential = TokenMethod(refreshToken, "refresh_token", SendTokenRequest, [clientId = clientId])
     in
        newCredential;

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
