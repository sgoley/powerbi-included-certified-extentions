[Version = "1.0.1"]
section Asana;

config = Json.Document( Extension.Contents( "Config.json") );
client_id=  config[client_id];
redirect_uri = config[redirect_uri];
token_uri = config[token_uri];
authorize_uri = config [authorize_uri];
api_url = config [api_url];

[DataSource.Kind="Asana", Publish="Asana.Publish"]
shared Asana.Tables =  Value.ReplaceType(AsanaNavTable, Asana_Type);

Asana_Type = type function (
    link as (Uri.Type meta [
        Documentation.FieldCaption = Extension.LoadString("UrlParameterCaption"),
        Documentation.FieldDescription = Extension.LoadString("UrlParameterDescription"),
        Documentation.SampleValues = { Extension.LoadString("UrlParameterSampleValue") }
    ]))
    as table meta [
        Documentation.Name = Extension.LoadString("TableName"),
        Documentation.LongDescription = Extension.LoadString("TableDescription")
    ];


AsanaNavTable = (link as text) as table =>
    let
        source = #table(
            { "Name",      "Data",           "ItemKind", "ItemName", "IsLeaf"}, {
            { "Tasks",      Asana.View(link), "Table",    "Table",     true }            }
        ),
        navTable = Table.ToNavigationTable(source, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;


Asana.View = (link as text) as table =>
    let
        View = (state as record) => Table.View(null, [

            GetType = () => Value.Type(AsanaSchema()),

            // Called last - retrieves the data from the calculated URL
            GetRows = () => 
                let
                    qp = CalculateUrl(state),
                    result = GetTasks(qp)
                in
                    result,

            // OnTake - handles the Table.FirstN transform, limiting
            // the maximum number of rows returned in the result set.
            OnTake = (count as number) =>
                let
                    newState = state & [ Limit = count ]
                in
                    @View(newState),

            // Calculates the final URL based on the current state.
            CalculateUrl = (state) as record => 
                let
                    url = api_url & "/v1/data",

                    // Uri.BuildQueryString requires that all field values
                    // are text literals.
                    defaultQueryString = [ url = state[Link]],

                    // Check for Top defined in our state
                    qsWithLimit =
                        if (state[Limit]? <> null) then
                            defaultQueryString & [ limit = Number.ToText(state[Limit]) ]
                        else
                            defaultQueryString
                in
                    qsWithLimit
        ])
    in
        View([Link = link]);

// Data Source Kind description
Asana = [
    TestConnection = (dataSourcePath) => {"Asana.Tables", dataSourcePath},
    Authentication = [
        OAuth = [
            StartLogin=StartLogin,
            FinishLogin=FinishLogin,
            Label=Extension.LoadString("AuthenticationLabel")
        ]
    ]
];

// Data Source UI publishing description
Asana.Publish = [
    Beta = true,
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://app.asana.com",
    SourceImage = Asana.Icons,
    SourceTypeImage = Asana.Icons
];

Asana.Icons = [
    Icon16 = { Extension.Contents("Asana16.png"), Extension.Contents("Asana20.png"), Extension.Contents("Asana24.png"), Extension.Contents("Asana32.png") },
    Icon32 = { Extension.Contents("Asana32.png"), Extension.Contents("Asana40.png"), Extension.Contents("Asana48.png"), Extension.Contents("Asana64.png") }
];

// Helper functions for OAuth2: StartLogin, FinishLogin
StartLogin = (resourceUrl, state, display) =>
    let
        code_verifier = GenerateCodeVerifier(),
        authorizeUrl = authorize_uri & "?" & Uri.BuildQueryString([
            response_type = "code",
            client_id = client_id,  
            redirect_uri = redirect_uri,
            state = state,
            display_ui = "always",
            code_challenge = GenerateCodeChallenge(code_verifier),
            code_challenge_method = "S256"
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = 720,
            WindowWidth = 1024,
            Context = [code_verifier = code_verifier]
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        // parse the full callbackUri, and extract the Query string
        parts = Uri.Parts(callbackUri)[Query],
        // if the query string contains an "error" field, raise an error
        // otherwise call TokenMethod to exchange our code for an access_token
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    TokenMethod("authorization_code", "code", parts[code], context)
    in
        result;

TokenMethod = (grantType, tokenField, code, context) =>
    let
        queryString = [
            grant_type = grantType,
            redirect_uri = redirect_uri,
            client_id = client_id
        ],
        queryWithCodeVerifier = 
            if Record.HasFields(context, "code_verifier") then 
                Record.AddField(queryString, "code_verifier", context[code_verifier]) 
            else queryString,

        queryWithCode = Record.AddField(queryWithCodeVerifier, tokenField, code),


        tokenResponse = Web.Contents(api_url & "/powerbi/auth", [
            Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = {400} 
        ]),
        body = Json.Document(tokenResponse),
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body)
                 else
                    body
    in
        result;     

GetTasks = (qp as record) as table =>
    let
        access_token = RefreshToken(),
        Source = Web.Contents("https://reporting-api.integrations.asana.plus", [
            Headers=[Authorization = "Bearer " & access_token ], 
            Timeout=#duration(0, 1, 0, 0), 
            ManualStatusHandling={403}, 
            ManualCredentials = true,
            Query = qp,
            RelativePath = "/v1/data"
        ]),
        Json = Json.Document(Source),
        res =  if Value.Is(Json, type record) and (Record.HasFields(Json, {"error", "error_description"})) then 
                    error Error.Record(Json[error], Json[error_description], Json)
               else
                 ProcessResponse(Json)
    in
        res;

RefreshToken = () as text => 
    let 
        refresh_token = Extension.CurrentCredential()[refresh_token],
        body = TokenMethod("refresh_token", "refresh_token", refresh_token, []),
        token = body[access_token]
    in 
        token;

ProcessResponse = (Json as list) as table => 
    let 
        TempTable = Table.FromList(Json, Splitter.SplitByNothing(), {"Fields"}, null, ExtraValues.Error),
        Result = if Table.RowCount(TempTable) > 0
                    then Table.ExpandRecordColumn(TempTable, "Fields", Record.FieldNames(Table.Column(TempTable, "Fields"){0}))
                    else #table(Value.Type(AsanaSchema()), {})
    in Result;

AsanaSchema = () as table =>
   let
       Source = Web.Contents(api_url & "/v1/schema"),
       Json = Json.Document(Source),
       Fields = Json[fields],
       TempTable = #table(Fields, {})
   in
       TempTable;

GenerateCodeVerifier = () => 
    let
        ValidCharacters = Text.ToList("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456879"),
        StrLenght = 50,
        Result = Text.Combine(List.Transform( {1..StrLenght}, each ValidCharacters{Int32.From(Number.RandomBetween(0, List.Count(ValidCharacters)-1))}))
    in
        Result;

GenerateCodeChallenge = (code_verifier) => 
    let 
        hash = Replace(HashString(code_verifier))
    in
        hash;

HashString = (str as text) => 
    let
        result = Binary.ToText(Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(str, TextEncoding.Ascii)), BinaryEncoding.Base64)
    in
        result;

Replace = (str) => 
    let 
        result = Text.Replace(Text.Replace(Text.Replace(str, "+", "-"), "/", "_"), "=", "")
    in
        result;

Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");