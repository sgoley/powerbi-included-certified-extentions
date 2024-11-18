[
    Version = "1.1.17",
    Requires = [
        Legacy = "[0.0,)",
        DataSource = "[0.0,)",
        Environment = "[0.0,)",
        Extensibility = "[0.0,)",
        SqlDatabase = "[0.0,)"
    ]
]
section CommonDataService;

// -----------------------------------------------------
// |  CommonDataService.Database(server) Navigation Table
// -----------------------------------------------------
//  if server is null (loading from indirect table is not supported):
//  |- Environment
//  |- Environment
//  Note: Environment is same as server name.
//
//  if server is not null:
//  |- Entity
//  |- Entity
//  |- Entity
// -----------------------------------------------------

BapBaseUris = [
    global      = "https://api.bap.microsoft.com",
    ussec       = "https://api.bap.microsoft.scloud",
    usnat       = "https://api.bap.eaglex.ic.gov",
    gcc         = "https://gov.api.bap.microsoft.us",
    gcc_high    = "https://high.api.bap.microsoft.us",
    gcc_dod     = "https://api.bap.appsplatform.us",
    china       = "https://api.bap.partner.microsoftonline.cn",
    tip1        = "https://tip1.api.bap.microsoft.com"
];

AadPowerAppsResources = [
    global      = "https://service.powerapps.com/",
    ussec       = "https://service.powerapps.microsoft.scloud/",
    usnat       = "https://service.powerapps.eaglex.ic.gov/",
    gcc         = "https://gov.service.powerapps.us/",
    gcc_high    = "https://high.service.powerapps.us/",
    gcc_dod     = "https://service.apps.appsplatform.us/",
    china       = "https://service.powerapps.cn/",
    tip1        = "https://tip1.service.microsoft.com/"
];

DefaultCloud = "global";
Cloud = Environment.FeatureSwitch("Cloud", DefaultCloud);

BapBaseUri = Record.FieldOrDefault(BapBaseUris, Cloud, Record.Field(BapBaseUris, DefaultCloud));
BapEndpoint = Uri.Combine(BapBaseUri, "/providers/Microsoft.BusinessAppPlatform/environments?api-version=2016-11-01");

AadPowerAppsResource = Record.FieldOrDefault(AadPowerAppsResources, Cloud, Record.Field(AadPowerAppsResources, DefaultCloud));
AadAuthorizationUri =  Uri.Combine(Environment.FeatureSwitch("AzureActiveDirectoryUri", "https://login.microsoftonline.com"), "/common/oauth2/authorize");

// Empty resource path is treated as null which is invalid
RootResourcePath = "Dataverse";

[DataSource.Kind="CommonDataService", Publish="CommonDataService.UI"]
shared CommonDataService.Database = Value.ReplaceType(
    (optional server as text, optional options as nullable record) as table =>
        let
            validatedServer = ValidateServer(server),
            validatedOptions = ValidateOptions(options, OptionsMap),
            database = Text.Lower(Text.Split(validatedServer, "."){0}, ""),
            sqlOptions = [
                LegacyExtension = true,
                IncludeFieldCaptions = validatedOptions[EnableDisplayNames]? ?? true,
                CreateNavigationProperties = validatedOptions[CreateNavigationProperties]? ?? true
            ],
            navTable = Sql.Database(validatedServer, database, sqlOptions),
            nativeQueryOverride = Table.View(navTable, [
                OnNativeQuery = (query, optional parameters, optional options) =>
                    let
                        newOptions = Record.RemoveFields(options ?? [], {"DisplayNames"}, MissingField.Ignore),
                        displayNames = options[DisplayNames]?,
                        enableFolding = options[EnableFolding]? ?? false,
                        baseResult = Value.NativeQuery(navTable, query, parameters, newOptions),
                        baseResultWithCaptions = AdjustTypeForCaptions(baseResult, displayNames),
                        newNavTable = ApplyDisplayNamesOption(navTable, options),
                        newResult = try Value.NativeQuery(newNavTable, query, parameters, newOptions) otherwise baseResultWithCaptions,
                        result = TryCatch(
                            () => if displayNames = null then baseResult else if not enableFolding then baseResultWithCaptions else newResult,
                            (e) => error TableViewError(e))
                    in
                        result
            ]),
            result = if server = null then EnvironmentListTable() else nativeQueryOverride
        in
            result,
    CommonDataService.Type);

CommonDataService.Type = 
let 
    CreateNavigationPropertiesType = type nullable logical meta [
        Documentation.FieldCaption = Extension.LoadString("CreateNavigationPropertiesCaption"),
        Documentation.SampleValues = { true }
    ],
    FunctionType = Type.ForFunction([
        Parameters = [
            server = type nullable text meta [
                Documentation.FieldCaption = Extension.LoadString("ServerCaption"),
                Documentation.FieldDescription = Extension.LoadString("ServerDescription"),
                Documentation.SampleValues = {"orgname.crm.dynamics.com"}
            ],
            options = type [optional CreateNavigationProperties = CreateNavigationPropertiesType, ...] meta [
                Documentation.FieldCaption = Extension.LoadString("OptionsParameterCaption"),
                Documentation.FieldDescription = Extension.LoadString("OptionsParameterDescription")
            ]
        ],
        ReturnType = type table
    ], 0),
    AddMetadata = Value.ReplaceMetadata(
        FunctionType,
        [
            Documentation.Name = Extension.LoadString("ButtonTitle"),
            Documentation.Caption = Extension.LoadString("ButtonTitle"),
            Documentation.LongDescription = Extension.LoadString("LongDescription")
        ]
    )
in
    AddMetadata;

OptionsMap = #table(
    {"Name","Type","Default","Validate","Hidden"}, {
    {"CreateNavigationProperties", type nullable logical, true, each _ = null or _ = true or _ = false, false},
    // Not public-facing
    {"EnableDisplayNames", type nullable logical, true, each _ = null or _ = true or _ = false, true},
    {"UnsafeTypeConversions", type nullable logical, false, each _ = null or _ = true or _ = false, true}
});

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

TryCatch = (tryFn, catchFn) => let result = try tryFn() in
    if not result[HasError] then result[Value] else catchFn(result[Error]);

TableViewError = try #shared[Table.ViewError] otherwise (x) => x;

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
        validateUri = ValidateHostname(HostnameFromServer(resourceUri), resourceUri),
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
    ".dynamics.microsoft.scloud",
    ".crmlivetie.com"
};

CloudToEndPoint = [
    global      = ".dynamics.com",
    ussec       = ".dynamics.microsoft.scloud",
    usnat       = ".dynamics.eaglex.ic.gov",
    gcc         = ".microsoftdynamics.us",
    gcc_dod     = ".appsplatform.us",
    china       = ".dynamics.cn"
];

ValidateHostname = (hostname, value) =>
    if List.MatchesAny(ValidDomains, (domain) => Text.EndsWith(hostname, domain)) then value
    else error Error.Record("DataSource.Error", Text.Format(Extension.LoadString("ErrorInvalidHost"), {hostname}));

ValidateServer = (server) =>
    if Text.StartsWith(server, "https://", Comparer.OrdinalIgnoreCase) or 
        Text.StartsWith(server, "http://", Comparer.OrdinalIgnoreCase)
    then error Error.Record("DataSource.Error", Text.Format(Extension.LoadString("ServerFormatError"), {server}))
    else ValidateHostname(HostnameFromServer(server), server);

ServerFromPath = (path) => if path = RootResourcePath then null else path;

HostnameFromServer = (server) => (Uri.Parts(Text.Replace(Text.Replace(server, ",", ":"), " ", ""))[Host]);

ServerUriFromPath = (path) =>
    let
        server = ServerFromPath(path),
        hostname = HostnameFromServer(server)
    in
        "https://" & ValidateHostname(hostname, hostname) & "/";

ValidateOptions = (options, validOptionsMap) as record =>
    let
        VisibleKeys = Table.SelectRows(validOptionsMap, each not [Hidden])[Name],
        ValidKeys = Table.Column(validOptionsMap, "Name"),
        InvalidKey = List.First(List.Difference(Record.FieldNames(options), ValidKeys)),
        InvalidKeyText = Text.Format(Extension.LoadString("InvalidOptionsKey"), {InvalidKey, Text.Combine(VisibleKeys, ",")}),
        ValidateValue = (name, optionType, default, validate, value) =>
                if (value is null and (Type.IsNullable(optionType) or default <> null))
                    or (Type.Is(Value.Type(value), optionType) and validate(value)) then null
                else Text.Format(Extension.LoadString("InvalidOptionsValue"), {name, value}),
        InvalidValues = List.RemoveNulls(Table.TransformRows(validOptionsMap, 
                each ValidateValue([Name],[Type],[Default],[Validate], Record.FieldOrDefault(options, [Name], [Default])))),
        DefaultOptions = Record.FromTable(Table.RenameColumns(Table.SelectColumns(validOptionsMap,{"Name","Default"}),{"Default","Value"})),
        NullNotAllowedFields = List.RemoveNulls(Table.TransformRows(validOptionsMap,
                each if not Type.IsNullable([Type]) and null = Record.FieldOrDefault(options, [Name], [Default]) then [Name] else null)),
        NormalizedOptions = DefaultOptions & Record.RemoveFields(options, NullNotAllowedFields, MissingField.Ignore),
        Result = if null = options then DefaultOptions
                 else if null <> InvalidKey then
                     error Error.Record("Expression.Error", InvalidKeyText)
                 else if not List.IsEmpty(InvalidValues) then
                     error Error.Record("Expression.Error", List.First(InvalidValues))
                 else NormalizedOptions
    in
        Result;

AdjustTypeForCaptions = (table, displayNames as nullable list) =>
    if displayNames = null then table else
        let
            tableType = Value.Type(table),
            tt = Table.AddIndexColumn(Record.ToTable(Type.RecordFields(Type.TableRow(tableType))), "Index", 1),
            dt = #table({"Source", "Column", "Caption"}, displayNames),
            j = Table.Join(tt, "Name", dt, "Column", JoinKind.LeftOuter),
            js = Table.Sort(j, {"Index"}),
            w = Table.AddColumn(js, "NewValue", each if [Caption] = null then [Value] else [Type=[Value][Type] meta [Documentation.FieldCaption = [Caption]], Optional = [Value][Optional]]),
            w2 = Record.FromTable(Table.RenameColumns(Table.SelectColumns(w, {"Name", "NewValue"}), {{"NewValue", "Value"}})),
            newType = Type.ReplaceTableKeys(type table Type.ForRecord(w2, false), Type.TableKeys(tableType)) meta Value.Metadata(tableType),
            newTable = Value.ReplaceType(table, newType) meta Value.Metadata(table)
        in
            newTable;

ApplyDisplayNamesOption = (navTable, opt) =>
let
    displayNames = opt[DisplayNames]?,
    newOptions = Record.RemoveFields(opt ?? [], {"EnableFolding", "DisplayNames"}, MissingField.Ignore),
    newNavTable = SqlDatabase.View([
        Dialect = "T-SQL",
        GeneratorVersion = 1,
        DataSourceName="Dataverse",
        Server="Server",
        Database="Database",
        NativeQueryOptions = {"EnableFolding", "PreserveTypes"},
        GetTables = () => error "GetTables",
        GetColumns = (table) => error "GetColumns",
        GetRows = (tableType, command) => Value.NativeQuery(navTable, command, null, newOptions),
        GetNativeQuery = (command, parameters, options) =>
            AdjustTypeForCaptions(
                Value.NativeQuery(navTable, command, parameters, options),
                displayNames)
    ])
in
    if displayNames = null then navTable else newNavTable;


CommonDataService = [
    Type = "Custom",
    MakeResourcePath = (server) => server ?? RootResourcePath,
    ParseResourcePath = (resource) => { 
        if resource = RootResourcePath or resource = "." // Support "." for backward compatibility
        then null else resource },
    TestConnection = (path) => { "CommonDataService.Database", ServerFromPath(path) }, 
    IsKnownEndpoint = (resource) =>
    let
        Cloud = Environment.FeatureSwitch("Cloud", DefaultCloud),
        endPoint = Record.FieldOrDefault(CloudToEndPoint, Cloud, Record.Field(CloudToEndPoint, DefaultCloud)),
        server = ParseResourcePath(resource){0},
        hostName = if (server = null) then server else HostnameFromServer(server)
    in
        if (hostName = null or Text.EndsWith(hostName, endPoint)) then true else false,
    Authentication = [
        Aad = [
            AuthorizationUri = (resource) =>
                if resource = RootResourcePath or resource = "." // Support "." for backward compatibility
                then AadAuthorizationUri else GetAuthUri(ServerUriFromPath(resource)),
            Resource = (resource) =>
                if resource = RootResourcePath or resource = "." // Support "." for backward compatibility
                then AadPowerAppsResource else ServerUriFromPath(resource),
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
     * {"protocol":"common-data-service","address":{"server":null}
     * {"protocol":"common-data-service","address":{"server":"corp.dynamics.com"}}
     * {"protocol":"common-data-service","address":{"server":"corp.dynamics.com", "table":"account"}}
     */

    DSRHandlers = [
        #"common-data-service" = [
            GetDSR = (server, optional options, optional navigation) =>
                let
                    address = if server = null then GetAddress(navigation)
                        else GetAddressWithServerName(server, navigation),
                    options = if options = null then [] else options
                in
                    {[protocol = "common-data-service", address = address], options},
            GetFormula = (dsr, optional options) =>
                let
                    address = dsr[address],
                    server = address[server]
                in
                    if (server = null) then ParseAddress(address, options)
                        else ParseAddressWithServerName(address, options, server),
            GetFriendlyName = (dsr) => "Dataverse"
        ]
    ]
];

// if server name is null, we should not have navigation steps
GetAddress = (optional navigation) => if navigation = null then [server=null] else ...;

GetAddressWithServerName = (server, optional navigation) =>
    let
        count = List.Count(navigation),
        table = navigation{0}?[Item]?,
        match = List.FirstN({[Schema="dbo", Item=table], "Data"}, count),
        isValid = Number.IsEven(count) and List.FirstN(match, count) = navigation,
        address = if navigation = null or (table = null) then [server=server]
            else if not isValid then ...
            else [server=server, table=table]
    in
        address;

ParseAddress = (address, options) => () => CommonDataService.Database(null, options);

ParseAddressWithServerName = (address, options, server) =>
    let
        table = address[table]?
    in
        if (table <> null) then
            () => CommonDataService.Database(server, options){[Schema="dbo", Item=table]}[Data]
        else
            () => CommonDataService.Database(server);

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

SqlDatabase.View = try #shared[SqlDatabase.View] otherwise error "SqlDatabase module not loaded";
Environment.FeatureSwitch = try #shared[Environment.FeatureSwitch] otherwise error "Environment module not loaded";
