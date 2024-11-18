[Version = "2.0.2"]
section PlanviewOKR;

[DataSource.Kind="PlanviewOKR", Publish="PlanviewOKR.Publish"]
shared PlanviewOKR.Contents = Value.ReplaceType(PlanviewOKR.ContentsInternal, PlanviewOKR.ContentsType);

PlanviewOKR = [
    Description = "PlanviewOKR", 
    Type = "Custom", 
    MakeResourcePath = (ODataURL) => (ODataURL), 
    ParseResourcePath = (resource) => {resource}, 
    TestConnection = (resource) => {"PlanviewOKR.Contents", resource},  
    Authentication = [OAuth = [StartLogin = StartLogin, FinishLogin = FinishLogin, Refresh = Refresh]], 
    Label = Extension.LoadString("ResourceLabel"),
    Icons = PlanviewOKR.Icons
];

PlanviewOKR.Publish = [
    Beta = true, 
    ButtonText = {Extension.LoadString("FormulaTitle"), Extension.LoadString("FormulaHelp")}, 
    LearnMoreUrl = "https://success.planview.com/Projectplace/Reporting/Visualize_Your_Projectplace_Data_Using_Power_BI",
    SourceImage = PlanviewOKR.Icons, 
    SourceTypeImage = PlanviewOKR.Icons
];

PlanviewOKR.Icons = [
    Icon16 = {
        Extension.Contents("PlanviewOKR16.png"), 
        Extension.Contents("PlanviewOKR20.png"), 
        Extension.Contents("PlanviewOKR24.png"), 
        Extension.Contents("PlanviewOKR32.png")
    }, 
    Icon32 = {
        Extension.Contents("PlanviewOKR32.png"), 
        Extension.Contents("PlanviewOKR40.png"), 
        Extension.Contents("PlanviewOKR48.png"), 
        Extension.Contents("PlanviewOKR64.png")
    }
];

// ID for OKRs Reporting
client_id = "2efa26dea13d84714f9af8df5d62541a";
// PV Admin is issuing client IDs for it’s OAuth flow that apps will use.
// This ensures we aren’t embedding secrets into things like PowerBI desktop/connectors etc
// So we will not include client_secret in request
client_secret = "";

redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";

windowWidth = 1200;

windowHeight = 1000;


TokenMethod = (code, url, optional verifier) =>
    let
      FormatTextToBinary =  Text.ToBinary(client_id & ":" & client_secret),
      BinaryToHexadecimals = Binary.ToText(FormatTextToBinary, BinaryEncoding.Base64),

        Response = Web.Contents(
              url &"/io/v1/oauth2/token?", 
            [
                Content = Text.ToBinary(
                    Uri.BuildQueryString(
                        [code = code, grant_type = "authorization_code", code_verifier = verifier , client_id = client_id, redirect_uri = redirect_uri])), 
                Headers = [#"Authorization"= "Basic " & BinaryToHexadecimals, #"Content-type" = "application/x-www-form-urlencoded", Accept = "*/*"]
            ]),
        ResponseRecord = Json.Document(Response),
        Parts = Record.AddField(ResponseRecord, "access_token", ResponseRecord[id_token])
    in
        Parts;

Base64UrlEncodeWithoutPadding = (hash as binary) as text =>
    let
        base64Encoded = Binary.ToText(hash, BinaryEncoding.Base64),
        base64UrlEncoded = Text.Replace(Text.Replace(base64Encoded, "+", "-"), "/", "_"),
        withoutPadding = Text.TrimEnd(base64UrlEncoded, "=")
    in 
        withoutPadding;

StartLogin = (resourceUrl, state, display) =>
    let
        codeVerifier = Text.NewGuid() & Text.NewGuid(),
        oauthHost = GetOAuthHost(ValidateUrlScheme(resourceUrl)),
        code_challenge = Base64UrlEncodeWithoutPadding(Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(codeVerifier, TextEncoding.Ascii))),

        queryParams = Uri.Parts(resourceUrl)[Query],
        sandboxParam = try queryParams[sandbox] otherwise null,
        isSandbox = if sandboxParam = "true" then true else false,

        AuthorizeUrl = oauthHost & "/io/v1/oauth2/authorize?" & Uri.BuildQueryString([
            client_id = client_id,
            state = state,
            redirect_uri = redirect_uri,
            scope = "pts",
            code_challenge = code_challenge,
            sandbox = if isSandbox then "true" else "false"
        ])
    in
        [
            LoginUri = AuthorizeUrl, 
            CallbackUri = redirect_uri, 
            WindowHeight = windowHeight, 
            WindowWidth = windowWidth,
            Context = [oauthHost = oauthHost, verifier = codeVerifier],
            CodeVerifier = codeVerifier
        ];


FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query]
    in
        TokenMethod(Parts[code], context[oauthHost], context[verifier]);

Refresh = (resourceUrl, refresh_token) =>
    let
        FormatTextToBinary =  Text.ToBinary(client_id & ":" & client_secret),
        BinaryToHexadecimals = Binary.ToText(FormatTextToBinary, BinaryEncoding.Base64),

        Response = Web.Contents(
           GetOAuthHost(ValidateUrlScheme(resourceUrl)) &"/io/v1/oauth2/token?", 
            [
                Content = Text.ToBinary(
                    Uri.BuildQueryString(
                        [ refresh_token = refresh_token, grant_type = "refresh_token"])), 
                Headers = [#"Authorization"= "Basic " & BinaryToHexadecimals,#"Content-type" = "application/x-www-form-urlencoded", Accept = "*/*"]
            ]),
        ResponseRecord = Json.Document(Response),
        Parts = Record.AddField(ResponseRecord, "access_token", ResponseRecord[id_token])
    in
        Parts;


GetOAuthHost = (resourceUrl) =>
    let
        odataHostUrl = GetHost(resourceUrl),
        oauthUrl = 
            if odataHostUrl = "https://okrs-odata.platforma-dev.io" then "https://us.id.planviewlogindev.net" else
            if odataHostUrl = "https://okrs-odata.platforma-staging.io" then "https://us.id.stgplanviewid.com" else
            if odataHostUrl = "https://odata-us.okrs.planview.com" then "https://us.id.planview.com" else
            if odataHostUrl = "https://odata-eu.okrs.planview.com" then "https://eu.id.planview.com" else
            if odataHostUrl = "https://odata-ap.okrs.planview.com" then "https://ap.id.planview.com" else
            error resourceUrl
    in
        oauthUrl;


GetNextLink = (link) =>
    let
        links = Text.Split(link, ","),
        splitLinks = List.Transform(links, each Text.Split(Text.Trim(_), ";")),
        next = List.Select(splitLinks, each Text.Trim(_{1}) = "rel=""next"""),
        first = List.First(next),
        removedBrackets = Text.Range(first{0}, 1, Text.Length(first{0}) - 2)
    in
        try removedBrackets otherwise null;

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

PlanviewOKR.ContentsInternal = (OdataUrl as text) =>
    let
        content = OData.Feed(ValidateUrlScheme(OdataUrl))
    in
        content;

PlanviewOKR.ContentsType = 
    let
        ODataUrl = (type text) meta [
             Documentation.FieldCaption = Extension.LoadString("PlanviewOKR.Contents.Parameter.url.FieldCaption"), 
            Documentation.SampleValues = {}
        ],
        t = type function (ODataURL as ODataUrl) as table
    in
        t meta [
            Documentation.Description = Extension.LoadString("PlanviewOKR.Contents.Function.Description"), 
            Documentation.DisplayName = Extension.LoadString("PlanviewOKR.Contents.Function.DisplayName"), 
            Documentation.Caption = Extension.LoadString("PlanviewOKR.Contents.Function.Caption"), 
            Documentation.Name = Extension.LoadString("PlanviewOKR.Contents.Function.Name"), 
            Documentation.LongDescription = Extension.LoadString("PlanviewOKR.Contents.Function.LongDescription")
        ];
