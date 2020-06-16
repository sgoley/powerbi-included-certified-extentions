[Version = "1.0.0"]
section PlanviewProjectplace;

[DataSource.Kind="PlanviewProjectplace", Publish="PlanviewProjectplace.Publish"]
shared PlanviewProjectplace.Contents = Value.ReplaceType(PlanviewProjectplace.ContentsInternal, PlanviewProjectplace.ContentsType);

PlanviewProjectplace = [
    Description = "PlanviewProjectplace", 
    Type = "Url", 
    MakeResourcePath = (ODataURL) => (ODataURL), 
    ParseResourcePath = (resource) => {resource}, 
    TestConnection = (resource) => {"PlanviewProjectplace.Contents", resource},  
    Authentication = [OAuth = [StartLogin = StartLogin, FinishLogin = FinishLogin, Refresh = Refresh]], 
    Label = Extension.LoadString("ResourceLabel"),
    Icons = PlanviewProjectplace.Icons
];

PlanviewProjectplace.Publish = [
    Beta = true, 
    ButtonText = {Extension.LoadString("FormulaTitle"), Extension.LoadString("FormulaHelp")}, 
    SourceImage = [
        Icon32 = {
          Extension.Contents("PlanviewProjectplaceSheet32.png"), 
          Extension.Contents("PlanviewProjectplaceSheet40.png"), 
          Extension.Contents("PlanviewProjectplaceSheet48.png"), 
          Extension.Contents("PlanviewProjectplaceSheet64.png")
        }
    ], 
    SourceTypeImage = PlanviewProjectplace.Icons
];

PlanviewProjectplace.Icons = [
    Icon16 = {
        Extension.Contents("PlanviewProjectplace16.png"), 
        Extension.Contents("PlanviewProjectplace20.png"), 
        Extension.Contents("PlanviewProjectplace24.png"), 
        Extension.Contents("PlanviewProjectplace32.png")
    }, 
    Icon32 = {
        Extension.Contents("PlanviewProjectplace32.png"), 
        Extension.Contents("PlanviewProjectplace40.png"), 
        Extension.Contents("PlanviewProjectplace48.png"), 
        Extension.Contents("PlanviewProjectplace64.png")
    }
];

client_id = "2cce06ccd6ae2e34c59f3c197549dfd1";

client_secret = "12dcdd8fa44e4a69adeaa3ca7bc38850429f02be";

redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";

windowWidth = 1200;

windowHeight = 1000;

TokenMethod = (code) =>
    let
        Response = Web.Contents(
            "https://service.projectplace.com/oauth2/access_token", 
            [
                Content = Text.ToBinary(
                    Uri.BuildQueryString(
                        [client_id = client_id, client_secret = client_secret, code = code, grant_type = "authorization_code"])), 
                Headers = [#"Content-type" = "application/x-www-form-urlencoded", Accept = "application/json"]
            ]),
        Parts = Json.Document(Response)
    in
        Parts;

StartLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl = "https://service.projectplace.com/oauth2/authorize?" & Uri.BuildQueryString([client_id = client_id, state = state, redirect_uri = redirect_uri])
    in
        [
            LoginUri = AuthorizeUrl, 
            CallbackUri = redirect_uri, 
            WindowHeight = windowHeight, 
            WindowWidth = windowWidth, 
            Context = null
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query]
    in
        TokenMethod(Parts[code]);

Refresh = (resourceUrl, refresh_token) =>
    let
        Response = Web.Contents(
            "https://service.projectplace.com/oauth2/access_token", 
            [
                Content = Text.ToBinary(
                    Uri.BuildQueryString(
                        [client_id = client_id, client_secret = client_secret, refresh_token = refresh_token, grant_type = "refresh_token"])), 
                Headers = [#"Content-type" = "application/x-www-form-urlencoded", Accept = "application/json"]
            ]),
        Parts = Json.Document(Response)
    in
        Parts;

GetNextLink = (link) =>
    let
        links = Text.Split(link, ","),
        splitLinks = List.Transform(links, each Text.Split(Text.Trim(_), ";")),
        next = List.Select(splitLinks, each Text.Trim(_{1}) = "rel=""next"""),
        first = List.First(next),
        removedBrackets = Text.Range(first{0}, 1, Text.Length(first{0}) - 2)
    in
        try removedBrackets otherwise null;

PlanviewProjectplace.ContentsInternal = (ODataURL as text) =>
    let
        content = OData.Feed(ODataURL)
    in
        content;

PlanviewProjectplace.ContentsType = 
    let
        ODataURL = (type text) meta [
            Documentation.FieldCaption = Extension.LoadString("PlanviewProjectplace.Contents.Parameter.url.FieldCaption"), 
            Documentation.SampleValues = {}
        ],
        t = type function (ODataURL as ODataURL) as table
    in
        t meta [
            Documentation.Description = Extension.LoadString("PlanviewProjectplace.Contents.Function.Description"), 
            Documentation.DisplayName = Extension.LoadString("PlanviewProjectplace.Contents.Function.DisplayName"), 
            Documentation.Caption = Extension.LoadString("PlanviewProjectplace.Contents.Function.Caption"), 
            Documentation.Name = Extension.LoadString("PlanviewProjectplace.Contents.Function.Name"), 
            Documentation.LongDescription = Extension.LoadString("PlanviewProjectplace.Contents.Function.LongDescription")
        ];
