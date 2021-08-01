[Version = "2.0.0"]
section ZohoCreator;

//OAuth URIs
accounts_uri = "https://accounts.";
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
token_uri = "/oauth/v2/token";
authorize_uri = "/oauth/v2/auth";
token_revoke_uri = "/oauth/v2/token/revoke?token=";

// OAuth2 scope
scopes = {
    "ZohoCreator.meta.READ","ZohoCreator.data.READ","ZohoCreator.meta.CREATE","ZohoCreator.data.CREATE"
};
properties = Json.Document ( Extension.Contents( "WebApp.json") );

tool_name = properties[tool_details][tool_name];
user_agent = properties[tool_details][user_agent];
version_name = properties[tool_details][version_name];
version_number = properties[tool_details][version_number];

domains = properties[api_specification][domains];
api_type =  properties[api_specification][api_type];
max_retry = properties[api_specification][max_retry];
throttle_limit = properties[api_specification][throttle_limit];

client_id = Text.FromBinary(Binary.FromText(properties[client_credentials][client_id],BinaryEncoding.Base64),BinaryEncoding.Base64);
client_secret = Text.FromBinary(Binary.FromText(properties[client_credentials][client_secret],BinaryEncoding.Base64),BinaryEncoding.Base64);

GetDomain = (creatordomain as text) as any =>
    let
         jsonToList = Table.FromList(domains, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
         param2 = Table.ExpandRecordColumn(jsonToList,"Column1",{"domain","host"}),
         finaldomain = try Table.SelectRows(param2, each [domain] = creatordomain){0}[host] otherwise Table.SelectRows(param2, each [domain] = "zoho.com"){0}[host]
    in
        finaldomain;

Value.WaitFor = (producer as function, interval as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, null},
            (state) => state{0} <> null and (count = null or state{0} < count),
            (state) => if state{1} <> null then {null, state{1}} else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), interval(state{0}))},
            (state) => state{1})
    in
        List.Last(list);

GetRec = (ownername as text, appname as text, viewname as text, creatordomain as text) =>
    let
       result = {0 .. 0},
       Pages = List.Transform(result, each GetRecords(ownername,appname,viewname,creatordomain)),
       res = Pages{0}
    in
       res;

GetRecords = (ownername as text, appname as text, viewname as text, creatordomain as text) =>
    let
        waitForResult = Value.WaitFor(
        (iteration) =>
        let
            urii = GetDomain(creatordomain)&"/api/v2/"&ownername&"/"&appname&"/report/"&viewname&"/export?filetype=csv",
            exec =  Binary.Buffer(Web.Contents(urii,[ManualStatusHandling = {401,400,500},Headers=[#"User-Agent"= user_agent, #"Agent-Version-Number"=version_number]])),
            RawData = exec,
            status = Value.Metadata(exec)[Response.Status],
            actualResult = if status = 200 then RawData else "Something went wrong.",
            Json = Csv.Document(exec,[Delimiter=","])
        in
        Json,
         (iteration) => #duration(0, 0, 0, Number.Power(2, iteration)),max_retry)
    in
        waitForResult;

fetchData = (ownerName as text ,appLinkName as text,reportLinkName as text, creatordomain as text) => 
    let
        data = Table.PromoteHeaders(GetRec(ownerName,appLinkName,reportLinkName, creatordomain ))
   in
        data;

ConnectorEntryPoint = (creatordomain as text,scopename as text, appLinkName as text,reportLinkName as text) as any =>
    let
        res = fetchData(scopename ,appLinkName, reportLinkName,creatordomain)
    in
      res;

[DataSource.Kind="ZohoCreator", Publish="ZohoCreator.Publish"]
shared ZohoCreator.Contents = Value.ReplaceType(ConnectorEntryPoint,DialogInput);

DialogInput = type function (
     creatordomain as (type text meta [
        Documentation.FieldCaption = "Domain",
        Documentation.FieldDescription = "Choose the domain of your Zoho account",
        Documentation.AllowedValues = {"zoho.com", "zoho.eu", "zoho.com.cn", "zoho.in", "zoho.com.au"}
    ]),
    scopname as (type text meta [
        Documentation.FieldCaption = "Workspace name",
        Documentation.FieldDescription = "Enter the Zoho Creator workpace name",
        Documentation.SampleValues = {"jack"}
    ]),
     applinkname as (type text meta [
        Documentation.FieldCaption = "Application link name",
        Documentation.FieldDescription = "Enter the Zoho Creator application link name",
        Documentation.SampleValues = {"zylker-management"}
    ]),
    reportlinkname as (type text meta [
        Documentation.FieldCaption = "Report link name",
        Documentation.FieldDescription = "Enter the Zoho Creator report link name",
        Documentation.SampleValues = {"Employee_Details"}
    ]))
    as any meta [
        Documentation.Name = "Zoho Creator",
        Documentation.LongDescription = "This connector will fetch data only from Zoho Creator application reports",
        Documentation.Examples = {[
            Description = "To fetches data from US account, scope 'jack', application 'task-management', report 'Task_Details'",
            Code = "ZohoCreator.Contents(""zoho.com"", ""jack"", ""zylker-management"", ""Employee_Details"")",
            Result = "#table({""Column1""}, {{""Column2""}, {""Column3""}})"
        ]}
    ];

// Data Source Kind description
ZohoCreator = [

    TestConnection = (dataSourcePath) => 
        let 
              json = Json.Document(dataSourcePath),
              creatordomain = json[creatordomain],
              scopname = json[scopname],
              applicationlinkname = json[applinkname],
              listreportlinkname = json[reportlinkname]
        in
            {"ZohoCreator.Contents",creatordomain,scopname,applicationlinkname,listreportlinkname},
         
    Authentication = [
      OAuth = [
            StartLogin=StartLogin,
            FinishLogin=FinishLogin,
            Refresh=Refresh,
            Logout=Logout
        ]
    ],
    Label = "Zoho Creator"
];

StartLogin = (clientApplication, dataSourcePath, state, display) =>
    let
        creatordomain = Json.Document(dataSourcePath)[creatordomain],
        authorizeUrl = accounts_uri & creatordomain & authorize_uri & "?" & Uri.BuildQueryString([
            response_type = "code",
            client_id = client_id,  
            redirect_uri = redirect_uri,
            state = state,
            scope = GetScopeString(scopes),
            access_type = "offline",
            prompt = "consent"

        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = 720,
            WindowWidth = 1024,
            Context = null
        ];

FinishLogin = (clientApplication, dataSourcePath, context, callbackUri, state) =>
    let
        // parse the full callbackUri, and extract the Query string
        position = Text.Length(callbackUri)-1,
        newCallbackUri = if (Text.At(callbackUri,position) = "&") then Text.Start(callbackUri,position) else callbackUri,
        parts = Uri.Parts(newCallbackUri)[Query],
        // if the query string contains an "error" field, raise an error
        // otherwise call TokenMethod to exchange our code for an access_token
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    TokenMethod(dataSourcePath,"authorization_code", "code", parts[code])
    in
        result;

Refresh = (dataSourcePath, refresh_token) => TokenMethod(dataSourcePath,"refresh_token", "refresh_token", refresh_token);

Logout = (clientApplication, dataSourcePath, accessToken) => accounts_uri & Json.Document(dataSourcePath)[creatordomain] & token_revoke_uri & accessToken;

TokenMethod = (dataSourcePath,grantType, tokenField, code) =>
    let
        creatordomain = Json.Document(dataSourcePath)[creatordomain],
        queryString = [
            grant_type = grantType,
            redirect_uri = redirect_uri,
            client_id = client_id,
            client_secret = client_secret,
            scope = GetScopeString(scopes)
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),

        tokenResponse = Web.Contents(accounts_uri & creatordomain & token_uri, [
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

Value.IfNull = (a, b) => if a <> null then a else b;

GetScopeString = (scopes as list, optional scopePrefix as text) as text =>
    let
        scope_delimiter = ",",
        asText = Text.Combine(scopes, scope_delimiter)
    in
        asText;

// Data Source UI publishing description
ZohoCreator.Publish = [
    Beta = false,
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://www.zoho.com/creator/newhelp",
    SourceImage = ZohoCreator.Icons,
    SourceTypeImage = ZohoCreator.Icons
];

ZohoCreator.Icons = [
    Icon16 = { Extension.Contents("ZohoCreator16.png"), Extension.Contents("ZohoCreator20.png"), Extension.Contents("ZohoCreator24.png"), Extension.Contents("ZohoCreator32.png") },
    Icon32 = { Extension.Contents("ZohoCreator32.png"), Extension.Contents("ZohoCreator40.png"), Extension.Contents("ZohoCreator48.png"), Extension.Contents("ZohoCreator64.png") }
];