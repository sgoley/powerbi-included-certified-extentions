// Data Connector logic for Cognite Data Fusion.
[Version = "1.0.6"]
section Cognite;

CogniteDefaults = [
    Environment = "https://api.cognitedata.com",
    ApiVersion = "v1",
    MaxUriSize = 900,      // To avoid Power BI giving Invalid URI: The Uri scheme is too long.
    Version = "1.0.6"      // Is it possible to read this value from the section above?
];

isUrl = (input as text) => Text.StartsWith(input, "http://") or Text.StartsWith(input, "https://");

// Construct service Url from the environment (cluster) and project.
createUrls = (project as text, optional environment as text) =>
    let
        environment =
            if isUrl(project) // If project is an URL, then we will use the URL for calculating the apiUrl (service URL will still be URL override i.e project)
            then project
            else if environment <> null // If environment is set then we use the environment
            then environment
            else CogniteDefaults[Environment], // If no environment is set and no URL override, then use the default api cluster URL.
        parts = Uri.Parts(environment),
        hasScheme = isUrl(environment),
        port = if (parts[Scheme] = "https" and parts[Port] = 443) or (parts[Scheme] = "http" and parts[Port] = 80) then "" else ":" & Text.From(parts[Port]),
        version = if Text.Length(parts[Path]) > 1 then Text.Replace(parts[Path], "/", "") else CogniteDefaults[ApiVersion],
        path = Text.Combine({"/odata", version, "projects", project}, "/"),
        host = if hasScheme then parts[Host] else parts[Host] & ".cognitedata.com",
        scheme = if hasScheme then parts[Scheme] else "https",
        apiUrl = Text.Combine({scheme, "://", host, port}),
        serviceUrl = if isUrl(project) then project else Text.Combine({ apiUrl, path}) // For service URL we use the full URL override if supplied.
    in
        [ ApiUrl=apiUrl, ServiceUrl=serviceUrl ];

[DataSource.Kind="Cognite", Publish="Cognite.UI"]
shared Cognite.Contents = Value.ReplaceType(CogniteImpl, CogniteType);

CogniteType = type function (
    project as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("ProjectName"),
        Documentation.FieldDescription = Extension.LoadString("ProjectDescription"),
        Documentation.SampleValues = {"publicdata"}
    ]),
    optional environment as (type text meta [
        Documentation.FieldCaption = "CDF Environment" as text,
        Documentation.FieldDescription = Extension.LoadString("Environment"),
        Documentation.SampleValues = {CogniteDefaults[Environment]}
    ]))
    as table meta [
        Documentation.Name = Extension.LoadString("CogniteDataFusion"),
        Documentation.LongDescription = Extension.LoadString("CogniteDataFusion")
    ];

// Data Source Kind description.
Cognite = [
    // Override default resource path handling to support backwards compatibility of credentials.
    // When environment is null, the data source path will be:
    // {"project":"projectname"}
    // When environment is provided, the data source path will be:
    // {"environment":"environmentname","project":"projectname"}
    Type = "Custom",

    MakeResourcePath = (project, optional environment) =>
        let
            path =
                if (environment <> null) then
                    [environment=environment, project=project]
                else
                    [project=project]
        in
            Text.FromBinary(Json.FromValue(path)),

    ParseResourcePath = (resourcePath as text) => {resourcePath},

    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath)
        in
            { "Cognite.Contents", json[project], json[environment]? },

    Authentication = [
        Aad = [
            AuthorizationUri = (dataSourcePath) =>
                let
                    json = Json.Document(dataSourcePath),
                    environment = Record.FieldOrDefault(json, "environment", CogniteDefaults[Environment]),
                    urls = createUrls(json[project], environment)
                in
                    GetAuthorizationUrlFromWwwAuthenticate(urls[ServiceUrl]),
            Resource = (dataSourcePath) =>
                let
                    json = Json.Document(dataSourcePath),
                    environment = Record.FieldOrDefault(json, "environment", CogniteDefaults[Environment]),
                    urls = createUrls(json[project], environment)
                in
                    urls[ApiUrl]
        ],
        Key = [
            KeyLabel = Extension.LoadString("ApiKey"),
            Label = Extension.LoadString("ApiKey")
        ]
    ]
];

// Data Source UI publishing description
Cognite.UI = [
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://docs.cognite.com/",
    SourceImage = Cognite.Icons,
    SourceTypeImage = Cognite.Icons
];

Cognite.Icons = [
    Icon16 = { Extension.Contents("CDF16.png"), Extension.Contents("CDF20.png"), Extension.Contents("CDF24.png"), Extension.Contents("CDF32.png") },
    Icon32 = { Extension.Contents("CDF32.png"), Extension.Contents("CDF40.png"), Extension.Contents("CDF48.png"), Extension.Contents("CDF64.png") }
];

CogniteImpl = (project as text, optional environment as text) =>
    let
        current = Extension.CurrentCredential()[AuthenticationKind],

        defaultHeaders = [ #"x-cdp-app"="CognitePowerBIConnector:" & CogniteDefaults[Version]],
        authHeaders =
            if current = "Key" then
                let
                    key = Extension.CurrentCredential()[Key]
                in
                    [ #"api-key"=key, Authorization="" ]
            else
                [],

        // We also allow for the project argument to set the full service URL (since Power BI Service does
        // not support optional parameters). Thus for the service you may supply the full URL with
        // environment, version and project e.g: https://api.cognitedata.com/odata/v1/projects/<project>/
        serviceUrl = createUrls(project, environment)[ServiceUrl],
        //set expected headers for API
        headers = Record.Combine({ defaultHeaders, authHeaders }),
        source = OData.Feed(serviceUrl, null, [ Concurrent=true, Implementation="2.0", MaxUriLength=32768, Headers=headers ]),

        // Append customized version of Timeseries Aggregate function. We do this to adapt the function to take a
        // list of tags instead of a comma separated string of tags.

        rowsToReplace = Table.SelectRows(source, each [Name]="TimeseriesAggregate"),
        navTable =
            if Table.RowCount(rowsToReplace) = 1 then
                let
                    rowToReplace = rowsToReplace{0},
                    timeseriesAggregate = TimeseriesAggregate(rowToReplace[Data]),
                    offset = Table.PositionOf(source, rowToReplace, 0, "Name"),

                    source2 = Table.RemoveMatchingRows(source, {[Name="TimeseriesAggregate"]}, "Name"),
                    source3 = Table.InsertRows(source2, offset, {[Name="TimeseriesAggregate", Data=timeseriesAggregate, Signature = Value.ToText(timeseriesAggregate)]})
                in
                    Value.ReplaceType(source3, Value.Type(source))
            else
                source
    in
        navTable;

TimeseriesAggregateType = type function (
    Tags as (type list meta [
        Documentation.FieldDescription = Extension.LoadString("TimeseriesAggregateTagsDescription"),
        Documentation.SampleValues = {"tag1"}
    ]),
    Granularity as (type text meta [
        Documentation.FieldDescription = Extension.LoadString("TimeseriesAggregateGranularityDescription"),
        Documentation.SampleValues = {"1d"}
    ]),
    Start as (type datetimezone meta [
        Documentation.FieldDescription = Extension.LoadString("TimeseriesAggregateStartDescription"),
        Documentation.SampleValues = {"1-Jan-2018"}
    ]),
    optional End as (type datetimezone meta [
        Documentation.FieldDescription = Extension.LoadString("TimeseriesAggregateEndDescription"),
        Documentation.SampleValues = {"1-Jan-2020"}
    ]))
    as table meta [
        Documentation.Name = Extension.LoadString("TimeseriesAggregate"),
        Documentation.LongDescription = Extension.LoadString("TimeseriesAggregateDescription")
    ];

TimeseriesAggregate = (TimeSeriesAggregatesFunction as function) as function =>
    let
        ReplacementFunction = (Tags as list, Granularity as text, Start as datetimezone, optional End as datetimezone) as table =>
            let
                //Partition the list of tags
                partitions = PartitionTags(Tags),
                Tags = List.Transform(Tags, (x) => Uri.EscapeDataString(x)),

                // The query returns a record with a table that we can expand later.
                query = (Tags as text) => [Expandable=TimeSeriesAggregatesFunction(Tags, Granularity, Start, End)],
                // Apply query to list of partitions
                aggregates = List.Transform(partitions, query),
                // Combine the result. We use Table.Expand* instead of Table.Combine in order to handle a high number of tables and avoid duplicate queries.
                recordsTable = Table.FromRecords(aggregates),
                firstTable = List.First(aggregates)[Expandable],
                columnNames = Table.ColumnNames(firstTable),
                result = Table.ExpandTableColumn(recordsTable, "Expandable", columnNames),
                // Result has lost its type, so use type of first table in aggregates
                typedResult = Value.ReplaceType(result, Value.Type(firstTable))
            in
                typedResult
    in
        Value.ReplaceType(ReplacementFunction, TimeseriesAggregateType);

// Accepts a list of tags of Text type. Yields a list with comma separated tags
// Example: input={"1","2","3","4","5"}, output={"1,2,3,4","5"}
// Splits this list into multiple partitions (lists) and concatenates the text elements in each partition with ',' delimiters.
// The maximum size of a partition is defined in CogniteDefaults, and is used to restrict the size of each request to CDF.
PartitionTags = (InputTagList as list) as list =>
    let
        maxTagSize = List.Max(List.Transform(InputTagList, Text.Length)),
        partitions = Number.IntegerDivide(CogniteDefaults[MaxUriSize], maxTagSize),
        nTags = List.Count(InputTagList),
        partitionSize = List.Min({nTags, partitions}),
        partitioned = List.Split(InputTagList, partitionSize),

        joinPartitionTextWithComma = (tagList as list) as text => Text.Combine(tagList, ","),
        stringsJoinedPerPartition = List.Transform(partitioned, joinPartitionTextWithComma)
    in
        stringsJoinedPerPartition;

GetAuthorizationUrlFromWwwAuthenticate = (url as text) as text =>
    let
        // Sending an unauthenticated request to the service returns
        // a 302 status with WWW-Authenticate header in the response. The value will
        // contain the correct authorization_uri.
        //
        // Example:
        // Bearer authorization_uri="https://login.microsoftonline.com/{tenant_guid}/oauth2/authorize"
        responseCodes = {302, 401},
        endpointResponse = Web.Contents(url, [
            ManualCredentials = true,
            ManualStatusHandling = responseCodes,
            Headers=[ Authorization="Bearer" ]
        ])
    in
        if (List.Contains(responseCodes, Value.Metadata(endpointResponse)[Response.Status]?)) then
            let
                headers = Record.FieldOrDefault(Value.Metadata(endpointResponse), "Headers", []),
                wwwAuthenticate = Record.FieldOrDefault(headers, "WWW-Authenticate", ""),
                split = Text.Split(Text.Trim(wwwAuthenticate), " "),
                authorizationUri = List.First(List.Select(split, each Text.Contains(_, "authorization_uri=")), null)
            in
                if (authorizationUri <> null) then
                    // Trim and replace the double quotes inserted before the url
                    Text.Replace(Text.Trim(Text.Trim(Text.AfterDelimiter(authorizationUri, "=")), ","), """", "")
                else
                    error Error.Record("DataSource.Error", "Unexpected WWW-Authenticate header format or value during authentication.", [
                        #"WWW-Authenticate" = wwwAuthenticate
                    ])
        else
            error Error.Unexpected("Unexpected response from server during authentication.");

//
// Load common library functions
//
// TEMPORARY WORKAROUND until we're able to reference other M modules
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Value.ToText = Extension.LoadFunction("Value.ToText.pqm");