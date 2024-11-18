[Version = "2.0.0"]
section Spigit;

[DataSource.Kind="Spigit", Publish="Spigit.Publish"]
shared Spigit.Contents = Value.ReplaceType(Spigit.ContentsInternal, Spigit.ContentsType);

Spigit = [
    Description = "Spigit", 
    Type = "Url", 
    MakeResourcePath = (ODataURL) => ODataURL,
    ParseResourcePath = (resource) => {resource}, 
    TestConnection = (resource) => {"Spigit.Contents", resource},  
    Authentication = [OAuth = [StartLogin = StartLogin, FinishLogin = FinishLogin, Refresh = Refresh]], 
    Label = Extension.LoadString("ResourceLabel"),
    Icons = Spigit.Icons
];

Spigit.Publish = [
    Beta = false, 
    ButtonText = {Extension.LoadString("FormulaTitle"), Extension.LoadString("FormulaHelp")}, 
    SourceImage = Spigit.Icons,
    SourceTypeImage = Spigit.Icons
];

Spigit.Icons = [
    Icon16 = {
        Extension.Contents("Spigit16.png"), 
        Extension.Contents("Spigit20.png"), 
        Extension.Contents("Spigit24.png"), 
        Extension.Contents("Spigit32.png")
    }, 
    Icon32 = {
        Extension.Contents("Spigit32.png"), 
        Extension.Contents("Spigit40.png"), 
        Extension.Contents("Spigit48.png"), 
        Extension.Contents("Spigit64.png")
    }
];

redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";

client_id_us = "2jb80fen3mdff1mpbjtir5siah";

client_id_eu = "6k62t4rdfg75mci9ksoqofdb4m";

windowWidth = 1200;

windowHeight = 1000;

TokenMethod = (code, resourceUrl) =>
    let
        token_endpoint = GetHost(resourceUrl) & "/oauth2/token", 
        client_id = if IsUSRegion(resourceUrl) then client_id_us else client_id_eu,
        Response = Web.Contents(
            token_endpoint, 
            [
                Content = Text.ToBinary(
                    Uri.BuildQueryString(
                        [client_id = client_id, code = code, grant_type = "authorization_code", redirect_uri = redirect_uri, scope = "", token_endpoint = token_endpoint, sslValidate = "true" ])), 
                Headers = [#"Content-type" = "application/x-www-form-urlencoded", Accept = "application/json"]
            ]),
        Parts = Json.Document(Response)
    in
        Parts;
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
IsUSRegion = (url) =>
        let
            parts = Uri.Parts(url),
            port = if (parts[Scheme] = "https" and parts[Port] = 443) or (parts[Scheme] = "http" and parts[Port] = 80) then "" else ":" & Text.From(parts[Port]),
            containsUS = Text.Contains(parts[Host], "-us.", Comparer.OrdinalIgnoreCase)

        in
            containsUS;

StartLogin = (resourceUrl, state, display) =>
    let
        baseUrl = GetHost(ValidateUrlScheme(resourceUrl)),
        client_id = if IsUSRegion(resourceUrl) then client_id_us else client_id_eu,
        AuthorizeUrl = baseUrl & "/oauth2/authorize?" & Uri.BuildQueryString([client_id = client_id, nonce = Text.NewGuid(), redirect_uri = redirect_uri, response_type = "code", state = state])
    in
        [
            LoginUri = AuthorizeUrl, 
            CallbackUri = redirect_uri, 
            WindowHeight = windowHeight, 
            WindowWidth = windowWidth, 
            Context = resourceUrl
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query]
    in
        TokenMethod(Parts[code], context);

Refresh = (resourceUrl, refresh_token) =>
    let
        token_endpoint = GetHost(resourceUrl) & "/oauth2/token", 
        client_id = if IsUSRegion(resourceUrl) then client_id_us else client_id_eu,
        Response = Web.Contents(
            token_endpoint, 
            [
                Content = Text.ToBinary(
                    Uri.BuildQueryString(
                        [client_id = client_id, refresh_token = refresh_token, grant_type = "refresh_token"])), 
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

Spigit.ContentsInternal = (ODataURL as text) =>
    let
        content = OData.Feed(ValidateUrlScheme(ODataURL), null, [ODataVersion = 4, Implementation = "2.0"])
    in
        content;

Spigit.ContentsType = 
    let
        ODataURL = (type text) meta [
            Documentation.FieldCaption = Extension.LoadString("Spigit.Contents.Parameter.url.FieldCaption"), 
            Documentation.SampleValues = {}
        ],
        t = type function (ODataURL as ODataURL) as table
    in
        t meta [
            Documentation.Description = Extension.LoadString("Spigit.Contents.Function.Description"), 
            Documentation.DisplayName = Extension.LoadString("Spigit.Contents.Function.DisplayName"), 
            Documentation.Caption = Extension.LoadString("Spigit.Contents.Function.Caption"), 
            Documentation.Name = Extension.LoadString("Spigit.Contents.Function.Name"), 
            Documentation.LongDescription = Extension.LoadString("Spigit.Contents.Function.LongDescription")
        ];
