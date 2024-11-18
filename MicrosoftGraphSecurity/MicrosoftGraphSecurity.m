[Version="1.0.2"]
section MicrosoftGraphSecurity;

client_id = Text.FromBinary(Extension.Contents("client_id"));

// TODO: this will work in desktop, but not in the Power BI service / gateway
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
token_uri = "https://login.microsoftonline.com/organizations/oauth2/v2.0/token";
authorize_uri = "https://login.microsoftonline.com/organizations/oauth2/v2.0/authorize";
logout_uri = "https://login.microsoftonline.com/logout.srf";

windowWidth = 720;
windowHeight = 1024;

scope_prefix = "https://graph.microsoft.com/";
scopes = {
	"SecurityEvents.Read.All"
};

ODataOptions = [
    Implementation="2.0",
    ODataVersion = 4,
    MoreColumns = true
];

// List of supported versions
SupportedVersions = {
    "beta",
    "v1.0"
};

NavTable = #table(
    type table [
        Version = Text.Type,
        DisplayName = Text.Type,
        Entity = Text.Type,
        ItemKind = Text.Type,
        ItemName = Text.Type,
        IsLeaf = Logical.Type
    ], {
        // v1.0 entities
        { "v1.0", "Alerts", "alerts", "Table", "Table", true },
        // beta entities
        { "beta", "Alerts", "alerts", "Table", "Table", true },
        { "beta", "Secure scores", "secureScores", "Table", "Table", true },
        { "beta", "Secure score control profiles", "secureScoreControlProfiles", "Table", "Table", true }
    });

[DataSource.Kind="MicrosoftGraphSecurity"]
shared MicrosoftGraphSecurity.Contents = Value.ReplaceType(MicrosoftGraphSecurityImpl, MicrosoftGraphSecurityType);

MicrosoftGraphSecurityImpl = (version as text, optional options as record) as table =>
    if (options <> null and options[Test]? = true) then
        // minimal request to test that the current credential is valid
        GraphSecurity.Feed(version, "alerts", [#"$select" = "id", #"$top" = "5"])
    else
    let
        // filter the nav table to only contain the entities for this version
        entitiesForVersion = Table.SelectRows(NavTable, each [Version] = version),
        // the [Data] column will be the entity feed
        withData = Table.AddColumn(
            entitiesForVersion,
            "Data",
            each GraphSecurity.Feed([Version], [Entity]),
            Table.Type
        ),
		withFunction = Table.InsertRows(     // add Odata feed as an fuction to the Nav Table
            withData,
			Table.RowCount(withData),
            {[Version = version , DisplayName = "Specify custom Microsoft Graph Security URL to filter results", Entity = "Function", ItemKind = "Function", ItemName = "Function", IsLeaf = true,  Data = OData.Feed]}
        ),
        // format as nav table
        asNav = Table.ToNavigationTable(withFunction, {"Entity"}, "DisplayName", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        asNav;


MicrosoftGraphSecurityType = type function (
    version as (Text.Type meta [        
        Documentation.FieldCaption = " Select Mirosoft Graph Security API Version",
        Documentation.FieldDescription = "Select Mirosoft Graph Security API version",
        Documentation.AllowedValues = SupportedVersions,
        DataSource.Path = false
    ]),
    optional options as Record.Type
    ) as table meta [
        Documentation.Name = "Microsoft Graph Security",
		Documentation.Description = "Connector for the Microsoft Graph Security API",
        Documentation.LongDescription = "The Microsoft Graph Security connector helps to connect different Microsoft 
		and partner security products and services, to streamline security operations, and 
		improve threat protection, detection, and response capabilities. Learn more about integrating with the Microsoft 
		Graph Security API at ""https://aka.ms/graphsecuritydocs"". This connector will return the recent most 6000 rows 
		of the result set. This constraint and the workaround to overcome this constraint is documented at 
		""https://aka.ms/graphsecurityapiconstraints"". You can either use the power query function ‘Specify custom Microsoft Graph Security URL to filter results’ or use the Power 
		Query Editor to provide the $filter query per the constraint workarounds to get data beyond the initial 6000 rows.",
        Documentation.Examples = {[
            Description = "Returns a table from the Microsoft Graph Security API.",
            Code = "MicrosoftGraphSecurity.Contents(""v1.0"")"
        ],[
            Description = "Returns a table from the Microsoft Graph Security API.",
            Code = "MicrosoftGraphSecurity.Contents(""beta"")"
        ]}
    ];


GraphSecurity.Feed = (version as text, entity as text, optional queryString as record) =>
    let
        url = GetBaseUrl(version),
        urlWithEntity = Uri.Combine(url, entity), // Adds the  Entity to the URL
		urlWithFilter = if (queryString = null) then urlWithEntity else urlWithEntity & "?" & Uri.BuildQueryString(queryString),  //Adds the ?$filter and other queries to the URL
        options = if (queryString <> null and Record.HasFields(queryString, "$select")) then Record.RemoveFields(ODataOptions, "MoreColumns") else ODataOptions, // Removes MoreColumns from the ODataOptions when a $select is used, this causes an error if not removed, but needed if $select is not used  
        root = OData.Feed(urlWithFilter, null, options)
    in
        root;

GetBaseUrl = (version as text) as text => Text.Format("https://graph.microsoft.com/#{0}/security/", {ValidateVersion(version)});
ValidateVersion = (version as text) as text =>
    if (not List.Contains(SupportedVersions, version)) then
        error "Unsupported version: " & version & ". Expected: " & Text.Combine(SupportedVersions, ",")
    else
        version;

//
// Data Source definition
//
MicrosoftGraphSecurity = [
    TestConnection = (dataSourcePath) => { "MicrosoftGraphSecurity.Contents", SupportedVersions{0}, [Test = true] },
    Authentication = [
        OAuth = [
            StartLogin=StartLogin,
            FinishLogin=FinishLogin,
            Refresh=Refresh,
            Logout=Logout
        ]
    ],
    Label = Extension.LoadString("ConnectorName")
];

//
// UI Export definition
//
MicrosoftGraphSecurity.UI = [
    Beta = true,
	Category = "online services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    SourceImage = MicrosoftGraphSecurity.Icons,
    SourceTypeImage = MicrosoftGraphSecurity.Icons,
	LearnMoreUrl = Extension.LoadString("LearnMoreURL")
];

MicrosoftGraphSecurity.Icons = [
    Icon16 = { Extension.Contents("MicrosoftGraphSecurity16.png"), Extension.Contents("MicrosoftGraphSecurity20.png"), Extension.Contents("MicrosoftGraphSecurity24.png"), Extension.Contents("MicrosoftGraphSecurity32.png") },
    Icon32 = { Extension.Contents("MicrosoftGraphSecurity32.png"), Extension.Contents("MicrosoftGraphSecurity40.png"), Extension.Contents("MicrosoftGraphSecurity48.png"), Extension.Contents("MicrosoftGraphSecurity64.png") }
];

//
// OAuth implementation
//
// See the following links for more details on AAD/Graph OAuth:
// * https://docs.microsoft.com/en-us/azure/active-directory/active-directory-protocols-oauth-code 
// * https://graph.microsoft.io/en-us/docs/authorization/app_authorization
//
// StartLogin builds a record containing the information needed for the client
// to initiate an OAuth flow. Note for the AAD flow, the display parameter is
// not used.
//
// resourceUrl: Derived from the required arguments to the data source function
//              and is used when the OAuth flow requires a specific resource to 
//              be passed in, or the authorization URL is calculated (i.e. when
//              the tenant name/ID is included in the URL). In this example, we
//              are hardcoding the use of the "common" tenant, as specified by
//              the 'authorize_uri' variable.
// state:       Client state value we pass through to the service.
// display:     Used by certain OAuth services to display information to the
//              user.
//
// Returns a record containing the following fields:
// LoginUri:     The full URI to use to initiate the OAuth flow dialog.
// CallbackUri:  The return_uri value. The client will consider the OAuth
//               flow complete when it receives a redirect to this URI. This
//               generally needs to match the return_uri value that was
//               registered for your application/client. 
// WindowHeight: Suggested OAuth window height (in pixels).
// WindowWidth:  Suggested OAuth window width (in pixels).
// Context:      Optional context value that will be passed in to the FinishLogin
//               function once the redirect_uri is reached. 
//
StartLogin = (resourceUrl, state, display) =>
    let
        authorizeUrl = authorize_uri & "?" & Uri.BuildQueryString([
            client_id = client_id,  
            redirect_uri = redirect_uri,
            state = state,
            scope = GetScopeString(scopes, scope_prefix),
            response_type = "code",
            response_mode = "query",
            prompt = "login"
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = 720,
            WindowWidth = 1024,
            Context = null
        ];

// FinishLogin is called when the OAuth flow reaches the specified redirect_uri. 
// Note for the AAD flow, the context and state parameters are not used. 
//
// context:     The value of the Context field returned by StartLogin. Use this to 
//              pass along information derived during the StartLogin call (such as
//              tenant ID)
// callbackUri: The callbackUri containing the authorization_code from the service.
// state:       State information that was specified during the call to StartLogin. 
FinishLogin = (context, callbackUri, state) =>
    let
        // parse the full callbackUri, and extract the Query string
        parts = Uri.Parts(callbackUri)[Query],
        // if the query string contains an "error" field, raise an error
        // otherwise call TokenMethod to exchange our code for an access_token
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    TokenMethod("authorization_code", "code", parts[code])
    in
        result;

// Called when the access_token has expired, and a refresh_token is available.
// 
Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", "refresh_token", refresh_token);

Logout = (token) => logout_uri;

// grantType:  Maps to the "grant_type" query parameter.
// tokenField: The name of the query parameter to pass in the code.
// code:       Is the actual code (authorization_code or refresh_token) to send to the service.
TokenMethod = (grantType, tokenField, code) =>
    let
        queryString = [
            client_id = client_id,
            scope = GetScopeString(scopes, scope_prefix),
            grant_type = grantType,
            redirect_uri = redirect_uri
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),

        tokenResponse = Web.Contents(token_uri, [
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

//
// Helper Functions
//
Value.IfNull = (a, b) => if a <> null then a else b;

GetScopeString = (scopes as list, optional scopePrefix as text) as text =>
    let
        prefix = Value.IfNull(scopePrefix, ""),
        addPrefix = List.Transform(scopes, each prefix & _),
        asText = Text.Combine(addPrefix, " ") & " offline_access" //add offline_access to get refresh token
    in
        asText;

Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");
