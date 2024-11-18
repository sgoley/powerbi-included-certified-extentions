[Version = "3.0.0"]
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
    Beta = false, 
    ButtonText = {Extension.LoadString("FormulaTitle"), Extension.LoadString("FormulaHelp")}, 
    LearnMoreUrl = "https://success.planview.com/Projectplace/Reporting/Visualize_Your_Projectplace_Data_Using_Power_BI",
    SourceImage = PlanviewProjectplace.Icons, 
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

TokenMethod = (code, oauthUrl) =>
    let
        Response = Web.Contents(
            oauthUrl & "/oauth2/access_token", 
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
        oauthHost = GetOAuthHost(ValidateUrlScheme(resourceUrl)),
        AuthorizeUrl =  oauthHost & "/oauth2/authorize?" & Uri.BuildQueryString([client_id = client_id, state = state, redirect_uri = redirect_uri])    
    in
        [
            LoginUri = AuthorizeUrl, 
            CallbackUri = redirect_uri, 
            WindowHeight = windowHeight, 
            WindowWidth = windowWidth,
            Context = oauthHost
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query]
    in
        TokenMethod(Parts[code], context);

Refresh = (resourceUrl, refresh_token) =>
    let
        Response = Web.Contents(
            GetOAuthHost(resourceUrl) & "/oauth2/access_token", 
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

GetOAuthHost = (resourceUrl) =>
	let
		odataHostUrl = GetHost(resourceUrl),
		url1 = Text.Replace(odataHostUrl, "odata.", "service."),
		url2 = Text.Replace(url1, "odata3.", "service."),
		url3 = Text.Replace(url2, "odata3-dev.", "service."),
		url4 = Text.Replace(url3, "odata3-", ""),
        oauthUrl = if Text.Contains(url4, "http://local.rnd") then "https://local.rnd.projectplace.com" else url4
	in
		oauthUrl;

GetHost = (url) =>
    let
        parts = Uri.Parts(url),
        port = if (parts[Scheme] = "https" and parts[Port] = 443) or (parts[Scheme] = "http" and parts[Port] = 80) then "" else ":" & Text.From(parts[Port])
    in
        parts[Scheme] & "://" & parts[Host] & port;

ValidateUrlScheme = (url as text) as text => 
    if (Uri.Parts(url)[Scheme] <> "https") 
    then error "Url scheme must be HTTPS" 
    else url;

PlanviewProjectplace.ContentsInternal = (ODataURL as text) =>
    let
        content = OData.Feed(ValidateUrlScheme(ODataURL))
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
