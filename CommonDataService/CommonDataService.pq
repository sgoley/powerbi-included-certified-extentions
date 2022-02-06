[Version = "1.1.0"]
section CommonDataService;

BapBaseUris = [
    global      = "https://api.bap.microsoft.com",
    usnat       = "https://api.bap.appsplatform.us",
    gcc         = "https://gov.api.bap.microsoft.us",
    gcc_high    = "https://high.api.bap.microsoft.us",
    gcc_dod     = "https://api.bap.appsplatform.us",
    chinacloud  = "https://api.bap.partner.microsoftonline.cn",
    tip1        = "https://tip1.api.bap.microsoft.com"
];

AadPowerAppsResources = [
    global      = "https://service.powerapps.com/",
    usnat       = "https://service.apps.appsplatform.us/",
    gcc         = "https://gov.service.powerapps.us/",
    gcc_high    = "https://high.service.powerapps.us/",
    gcc_dod     = "https://service.apps.appsplatform.us/",
    chinacloud  = "https://service.powerapps.cn/",
    tip1        = "https://tip1.service.microsoft.com"
];

DefaultCloud = "global";
Cloud = Environment.FeatureSwitch("Cloud", DefaultCloud);

BapBaseUri = Record.FieldOrDefault(BapBaseUris, Cloud, Record.Field(BapBaseUris, DefaultCloud));
BapEndpoint = Uri.Combine(BapBaseUri, "/providers/Microsoft.BusinessAppPlatform/environments?api-version=2016-11-01");

AadPowerAppsResource = Record.FieldOrDefault(AadPowerAppsResources, Cloud, Record.Field(AadPowerAppsResources, DefaultCloud));
AadAuthorizationUri =  Uri.Combine(Environment.FeatureSwitch("AzureActiveDirectoryUri", "https://login.microsoftonline.com"), "/common/oauth2/authorize");

// Empty resource path is treated as null which is invalid
RootResourcePath = ".";

[DataSource.Kind="CommonDataService", Publish="CommonDataService.UI"]
shared CommonDataService.Database = Value.ReplaceType(
    (optional server as text) as table =>
        let
            ValidateServer = ValidateServer(server),
            database = Text.Lower(Text.Split(ValidateServer, "."){0}, ""),
            navTable = Sql.Database(ValidateServer, database, [LegacyExtension=true]),
            result = if server = null then EnvironmentListTable() else navTable
        in
            result,
    FunctionType);

FunctionType = type function (
    optional server as (type nullable text meta [
        Documentation.FieldCaption = Extension.LoadString("ServerCaption"),
        Documentation.FieldDescription = Extension.LoadString("ServerDescription"),
        Documentation.SampleValues = {"orgname.crm.dynamics.com"}
    ]))
    as table meta [
        Documentation.Name = Extension.LoadString("ButtonTitle"),
        Documentation.Caption = Extension.LoadString("ButtonTitle"),
        Documentation.LongDescription = Extension.LoadString("LongDescription")
    ];

EnvironmentListType = Type.AddTableKey(
    type table [
        DisplayName = text,
        Name = text,
        Location = text,
        IsDefault = logical,
        Data = (type table meta [
            NavigationTable.ItemKind = "Database",
            Preview.Delay = "Table"
        ])
    ] meta [
        NavigationTable.NameColumn = "DisplayName",
        NavigationTable.DataColumn = "Data",
        NavigationTable.SupportsIndirection = true
    ],
    {"Name"},
    true);

EnvironmentListTable = () =>
    let
        response = Json.Document(Web.Contents(BapEndpoint)),
        locations = List.Transform(
            List.Select(
                response[value],
                each [properties]?[linkedEnvironmentMetadata]?[type]? = "Dynamics365Instance"),
            each [
                DisplayName = MakeDisplayName(_, Name, Endpoint),
                Name = [name],
                Location = [location],
                IsDefault = [properties]?[isDefault]? ?? false,
                Endpoint = MakeEndpoint(_),
                Data = MakeIndirectTable(Endpoint)
            ]),
        result = Table.Sort(
                Table.FromRecords(locations, EnvironmentListType),
                "DisplayName"
            )
    in
        result;

// Valid instance Url must exist for an environment 
MakeEndpoint = (row) => Uri.Parts(row[properties][linkedEnvironmentMetadata][instanceUrl])[Host];

// Display name is FriendlyName (instance endpoint)
MakeDisplayName = (row, name, endpoint) =>
    let
        friendlyName = row[properties]?[linkedEnvironmentMetadata]?[friendlyName]? ?? "",
        displayName = row[properties]?[displayName]? ?? name,
        result = Text.Combine({
            if friendlyName <> "" then friendlyName else displayName,
            " (",
            endpoint,
            ")"})
    in
        result;

MakeIndirectTable = (endpoint) => Table.View(null, [
    GetExpression = () => [
        Kind = "Invocation",
        Function = [Kind="Constant", Value=CommonDataService.Database],
        Arguments = {[Kind = "Constant", Value = endpoint]}
    ],
    GetType = () => type table [],
    GetRows = () => error Error.Record("DataSource.Error", Extension.LoadString("LoadDataError"), null)
]);

GetAuthUri = (resourceUri) =>
    let
        validateUri = ValidateServer(resourceUri),
        options = [Headers=[Authorization="Bearer"], ManualStatusHandling={401}],
        headerKey = "WWW-Authenticate",
        response = Web.Contents(validateUri & "api/data", options),
        authHeader = Record.FieldOrDefault(Value.Metadata(response)[Headers], headerKey),
        authUri = Text.BetweenDelimiters(authHeader, "authorization_uri=", ","),
        authUri2 = Text.AfterDelimiter(authHeader, "authorization_uri=")
    in
        if authUri <> "" then authUri else authUri2;

ValidDomains = {
    ".dynamics.com",
    ".dynamics.cn",
    ".microsoftdynamics.us",
    ".appsplatform.us",
    ".microsoftdynamics.de",
    ".dynamics.eaglex.ic.gov",
    ".crmlivetie.com"
};

ValidateHostname = (hostname, value) =>
    if List.MatchesAny(ValidDomains, (domain) => Text.EndsWith(hostname, domain)) then value
    else error Error.Record("DataSource.Error", Text.Format(Extension.LoadString("ErrorInvalidHost"), {hostname}));

ValidateServer = (server) => ValidateHostname(HostnameFromServer(server), server);

ServerFromPath = (path) => if path = RootResourcePath then null else path;

HostnameFromServer = (server) => (Uri.Parts(Text.Replace(Text.Replace(server, ",", ":"), " ", ""))[Host]);

ServerUriFromPath = (path) =>
    let
        server = ServerFromPath(path),
        hostname = HostnameFromServer(server)
    in
        "https://" & ValidateHostname(hostname, hostname) & "/";

CommonDataService = [
    Type = "Custom",
    MakeResourcePath = (server) => server ?? RootResourcePath,
    ParseResourcePath = (resource) => { if resource = RootResourcePath then null else resource },
    TestConnection = (path) => { "CommonDataService.Database", ServerFromPath(path) }, 
    Authentication = [
        Aad = [
            AuthorizationUri = (resource) => if resource = RootResourcePath then AadAuthorizationUri else GetAuthUri(ServerUriFromPath(resource)),
            Resource = (resource) => if resource = RootResourcePath then AadPowerAppsResource else ServerUriFromPath(resource),
            DefaultClientApplication = [
                ClientId = "a672d62c-fc7b-4e81-a576-e60dc46e951d",
                ClientSecret = "",
                CallbackUrl = "https://preview.powerbi.com/views/oauthredirect.html"
            ]
        ]
    ],

    SupportsEncryption = true,

    /*
     * valid DSRs
     *
     * {"protocol":"common-data-service","address":{"server":"corp.dynamics.com"}}
     * {"protocol":"common-data-service","address":{"server":"corp.dynamics.com","entity":"account"}}
     */

    DSRHandlers = [
        #"common-data-service" = [
            GetDSR = (server, optional navigation) =>
                let
                    entity = navigation{0}?[Name]?,
                    count = List.Count(navigation),
                    match = List.FirstN({[Name=entity,Kind="Table"], "Data"}, count),
                    isValid = Number.IsEven(count) and List.FirstN(match, count) = navigation,
                    address = if navigation = null then [server=server]
                        else if not isValid then ...
                        else [server=server, entity=entity]
                in
                    [ protocol = "common-data-service", address = address ],
            GetFormula = (dsr, optional options) =>
                let
                    address = dsr[address],
                    server = address[server],
                    entity = address[entity]?
                in
                    if (entity <> null) then
                        () => CommonDataService.Database(server){[Name=entity,Kind="Table"]}[Data]
                    else
                    () => CommonDataService.Database(server),
            GetFriendlyName = (dsr) => "Common Data Service"
        ]
    ]
];

CommonDataService.UI = [
    SupportsDirectQuery = true,
    Category = "Power Platform",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    SourceImage = CommonDataService.Icons,
    SourceTypeImage = CommonDataService.Icons
];

CommonDataService.Icons = [
    Icon16 = { Extension.Contents("Dataverse16.png"), Extension.Contents("Dataverse20.png"), Extension.Contents("Dataverse24.png"), Extension.Contents("Dataverse32.png") },
    Icon32 = { Extension.Contents("Dataverse32.png"), Extension.Contents("Dataverse40.png"), Extension.Contents("Dataverse48.png"), Extension.Contents("Dataverse64.png") }
];