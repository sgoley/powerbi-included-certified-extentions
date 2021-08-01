[Version = "1.0.6"]
section CommonDataService;

[DataSource.Kind="CommonDataService", Publish="CommonDataService.UI"]
shared CommonDataService.Database = Value.ReplaceType(
    (server as text) as table =>
        let
            validatedServer = ValidatedServer(server),
            database = Text.Lower(Text.Split(validatedServer, "."){0}, ""),
            navTable = Sql.Database(validatedServer, database, [LegacyExtension=true])
        in
            navTable,
    FunctionType);

FunctionType = type function (
    server as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("ServerCaption"),
        Documentation.FieldDescription = Extension.LoadString("ServerDescription"),
        Documentation.SampleValues = {"orgname.crm.dynamics.com"}
    ]))
    as table meta [
        Documentation.Name = Extension.LoadString("ButtonTitle"),
        Documentation.Caption = Extension.LoadString("ButtonTitle"),
        Documentation.LongDescription = Extension.LoadString("LongDescription")
    ];

GetAuthUri = (resourceUri) =>
    let
        // TODO: Validate domain
        options = [Headers=[Authorization="Bearer"], ManualStatusHandling={401}],
        headerKey = "WWW-Authenticate",
        response = Web.Contents(resourceUri & "api/data", options),
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

ValidatedHostname = (hostname, value) =>
    if List.MatchesAny(ValidDomains, (domain) => Text.EndsWith(hostname, domain)) then value
    else error Error.Record("DataSource.Error", Text.Format(Extension.LoadString("ErrorInvalidHost"), {hostname}));

ValidatedServer = (server) => ValidatedHostname(HostnameFromServer(server), server);

ServerFromPath = (path) => path;

HostnameFromServer = (server) => (Uri.Parts(Text.Replace(Text.Replace(server, ",", ":"), " ", ""))[Host]);

ServerUriFromPath = (path) =>
    let
        server = ServerFromPath(path),
        hostname = HostnameFromServer(server)
    in
        "https://" & ValidatedHostname(hostname, hostname) & "/";

CommonDataService = [
    Type = "Custom",
    MakeResourcePath = (server) => server,
    ParseResourcePath = (resource) => { resource },
    TestConnection = (path) => { "CommonDataService.Database", ServerFromPath(path) }, 
    Authentication = [
        Aad = [
            AuthorizationUri = (resource) => GetAuthUri(ServerUriFromPath(resource)),
            Resource = (resource) => ServerUriFromPath(resource),
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
