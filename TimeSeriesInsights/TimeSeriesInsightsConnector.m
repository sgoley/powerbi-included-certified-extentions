// Power BI Data Connector logic for Azure Time Series Insights.
[Version="1.0.1"]
section TimeSeriesInsights;

dev = "crystal-dev.windows-int.net";
prod = "timeseries.azure.com";
endpoint = prod;
storeType = "WarmStore";
versionGA = "2016-12-12";
versionPrivatePreview = "2018-11-01-preview";
supportedVersion = "RDX_20181120_Q";

authorization_uri = "https://login.windows.net/common/oauth2/authorize";
// Fixed web service endpoint for Azure Time Series Insights.
resource_uri = "120d688d-1518-4cf7-bd38-182f158850b6";

// 1st party app settings.
client_id = "a672d62c-fc7b-4e81-a576-e60dc46e951d";
// Standard redirect URI for PBI extensions, paired with the above client ID in AAD.
redirect_uri = "https://preview.powerbi.com/views/oauthredirect.html";
DefaultRequestHeaders = [
                            #"Content-Type" = "application/json; charset=utf-8", 
                            #"Accept" = "application/json", 
                            #"x-ms-app" = Extension.LoadString("TsiConnector"),
                            #"x-ms-client-version" = connectorVersion,
                            #"x-ms-client-request-id" = GetClientActivityId(),
                            #"x-ms-client-application-name" = Extension.LoadString("TsiConnector")
                        ];

windowWidth = 1200;
windowHeight = 1000;
connectorVersion = "1.0.1";

// The exported method.
[DataSource.Kind="TimeSeriesInsights", Publish="TimeSeriesInsights.Publish"]
shared TimeSeriesInsights.Contents = Value.ReplaceType(TimeSeriesInsights.ContentsInternal, TimeSeriesInsights.ContentsType);

// Data Source Kind description.
TimeSeriesInsights = [
    Type = "Singleton",
    MakeResourcePath = () => "TimeSeriesInsights",
    ParseResourcePath = (resource) => { },
    TestConnection = (resource) => { "TimeSeriesInsights.Contents",  [ TestConnection = true ] },
    Authentication = [
       Aad = [
			AuthorizationUri = authorization_uri,
			Resource = resource_uri,
			DefaultClientApplication = [
				ClientId = client_id,
				ClientSecret = "",
				CallbackUrl =  redirect_uri
			]
		]
    ],
    Label = Extension.LoadString("ResourceLabel")
];

// Data source UI publishing description.
TimeSeriesInsights.Publish = [
    Beta = true,
    Category = "Azure",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://aka.ms/tsipbi",
    SourceImage = TimeSeriesInsights.Icons,
    SourceTypeImage = TimeSeriesInsights.Icons
];

TimeSeriesInsights.Icons = [
    Icon16 = { Extension.Contents("TimeSeriesInsightsConnector16.png"), Extension.Contents("TimeSeriesInsightsConnector20.png"), Extension.Contents("TimeSeriesInsightsConnector24.png"), Extension.Contents("TimeSeriesInsightsConnector32.png") },
    Icon32 = { Extension.Contents("TimeSeriesInsightsConnector32.png"), Extension.Contents("TimeSeriesInsightsConnector40.png"), Extension.Contents("TimeSeriesInsightsConnector48.png"), Extension.Contents("TimeSeriesInsightsConnector64.png") }
];

TimeSeriesInsights.ContentsType = 
    let 
        jsonPayload = type text meta [
            Documentation.FieldCaption = Extension.LoadString("FuncType.JsonPayload.Caption"),
            Documentation.FieldDescription = Extension.LoadString("FuncType.JsonPayload.Description"),
            Documentation.SampleValues = { Extension.LoadString("FuncType.JsonPayload.Sample") }
        ],
        jsonRecord = type [
            JsonPayload = jsonPayload
        ] meta [
            Documentation.FieldCaption = Extension.LoadString("TimeSeriesInsightsConnector.QueryRecord.Caption")
        ],

        t = type function (query as jsonRecord) as table
    in
        t meta [
            Documentation.Name = Extension.LoadString("DataSourceLabel")
        ];

TimeSeriesInsights.ContentsInternal = (query as record) =>
    let
        navTable = if (query <> null) then ExecuteCustomQueries(query)
                    else error "Query cannot be empty or null."
    in
        if (query[TestConnection]? = true) then 
             Web.Contents("https://api.timeseries.azure.com/environments?api-version=2016-12-12")
        else
             navTable;

// Custom query.
ExecuteCustomQueries = (query as record) => 
    let
        jsonPayload = Json.Document(Text.ToBinary(query[JsonPayload])),
        useRelativeSearchspan = if Record.HasFields(jsonPayload, "isSearchSpanRelative") then jsonPayload[isSearchSpanRelative] else false,
        checkedVersion = ValidateVersion(jsonPayload[clientDataType]),
        result = ExecuteMultipleCustomQueries(jsonPayload[environmentFqdn], jsonPayload[queries], useRelativeSearchspan, checkedVersion)
    in
        result;

// Multiple custom query.
ExecuteMultipleCustomQueries = (environmentFqdn as text, queries as list, useRelativeSearchspan as logical, version as text) =>
    let
        table = ExecuteOneSeries(environmentFqdn, queries{0}, 0, useRelativeSearchspan),
        result = 
            if List.Count(queries) > 1 then
                Table.Combine(List.Generate(() => [i = -1, t = table], each [i] < List.Count(queries), each [t = ExecuteOneSeries(environmentFqdn, queries{i}, i, useRelativeSearchspan), i = [i] + 1], each [t]))
            else
                table
    in
        result;

ExecuteOneSeries = (environmentFqdn as text, query as record, queryIdx as number, useRelativeSearchspan as logical) =>
    let 
        revisedQuery = if (useRelativeSearchspan = true) then GetRevisedQuery(query) else query,
        postContents = Text.FromBinary(Json.FromValue(revisedQuery)),
        url = "https://" & environmentFqdn & "/timeseries/query?api-version=" & versionPrivatePreview & "&storeType=" & storeType,
        timeSeriesId = if Record.HasFields(revisedQuery, "getEvents") then revisedQuery[getEvents][timeSeriesId]
                       else if Record.HasFields(revisedQuery, "getSeries") then revisedQuery[getSeries][timeSeriesId]
                       else if Record.HasFields(revisedQuery, "aggregateSeries") then revisedQuery[aggregateSeries][timeSeriesId]
                       else error Extension.LoadString("IncorrectApiErrorMessage"),
        content = WebRequestForQueries(url, postContents, DefaultRequestHeaders, timeSeriesId, GetEmptyTable(), queryIdx)                               
    in
        content;

GetRevisedQuery = (query as record) =>
    let
        timeNow = DateTimeZone.UtcNow(),
        duration = CalculateDuration(query),
        fromRevised = ToDateTimeText(DateTimeZone.From(timeNow - duration)),
        toRevised = ToDateTimeText(timeNow),
        searchSpanRevised = [
            #"from" = fromRevised,
            #"to" = toRevised 
        ],
        removeSearchSpan = if Record.HasFields(query, "getEvents") then Record.RemoveFields(query[getEvents], {"searchSpan"})                            
                           else if Record.HasFields(query, "getSeries") then Record.RemoveFields(query[getSeries], {"searchSpan"})
                           else if Record.HasFields(query, "aggregateSeries") then Record.RemoveFields(query[aggregateSeries], {"searchSpan"})
                           else error Extension.LoadString("IncorrectApiErrorMessage"),

        addRevisedSearchSpan = Record.AddField(removeSearchSpan, "searchSpan", searchSpanRevised),

        removeQueryType = if Record.HasFields(query, "getEvents") then Record.RemoveFields(query, {"getEvents"})                        
                          else if Record.HasFields(query, "getSeries") then Record.RemoveFields(query, {"getSeries"})
                          else if Record.HasFields(query, "aggregateSeries") then Record.RemoveFields(query, {"aggregateSeries"})
                          else error Extension.LoadString("IncorrectApiErrorMessage"), 

        revisedQuery = if Record.HasFields(query, "getEvents") then Record.AddField(removeQueryType, "getEvents", addRevisedSearchSpan)
                       else if Record.HasFields(query, "getSeries") then Record.AddField(removeQueryType, "getSeries", addRevisedSearchSpan)
                       else if Record.HasFields(query, "aggregateSeries") then Record.AddField(removeQueryType, "aggregateSeries", addRevisedSearchSpan)
                       else error Extension.LoadString("IncorrectApiErrorMessage")
    in
        revisedQuery;

// Returns the time series variable(result).
GetTimeSeriesVariable = (content as binary, TimeSeriesId as list, optional queryId as number) =>
    let 
        timeSeries = Json.Document(content),
        timestamps = timeSeries[timestamps],
        result = if List.Count(timestamps) = 0 then GetEmptyTable() 
                 else GetTimeSeriesVariableHelper(timeSeries, TimeSeriesId, queryId)
    in
        result;

GetTimeSeriesVariableHelper = (TimeSeries as record, TimeSeriesId as list, optional queryId as number) =>
    let 
        timestamps = TimeSeries[timestamps],
        timestampTable = Table.FromList(timestamps, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        renamedTable = Table.RenameColumns(timestampTable, {{ "Column1", "_Timestamp" }}),
        transformedTimestamps = Table.TransformColumnTypes(renamedTable, {{ "_Timestamp", type datetime }}),
        indexedTimestamps = Table.AddIndexColumn(transformedTimestamps, "Index"),
        timeSeriesIdColumn_0 = Table.AddColumn(indexedTimestamps, "_TimeSeriesId_0", each TimeSeriesId{0},  type text),
        timeSeriesIdColumn_1 = if List.Count(TimeSeriesId) >= 2 then Table.AddColumn(timeSeriesIdColumn_0, "_TimeSeriesId_1", each TimeSeriesId{1},  type text) else timeSeriesIdColumn_0,
        timeSeriesIdColumn_2 = if List.Count(TimeSeriesId) >= 3 then Table.AddColumn(timeSeriesIdColumn_1, "_TimeSeriesId_2", each TimeSeriesId{2},  type text) else timeSeriesIdColumn_1,
        properties = TimeSeries[properties],
        column0 = GetColumnValues(properties{0}),
        name0 = GetColumnName(properties{0}, queryId),
        result = Table.FromColumns(
                    List.Generate(
                        () => [i = 0, t = column0], 
                        each [i] < List.Count(properties), 
                        each [t = GetColumnValues(properties{i}), i = [i] + 1], 
                        each [t]),
                    List.Generate(
                        () => [i = 0, t = name0], 
                        each [i] < List.Count(properties), 
                        each [t = GetColumnName(properties{i}, queryId), i = [i] + 1], 
                        each [t])),
        adjustedTypeTable = List.Accumulate(
                        properties,
                        result,
                        (state, currentProperty) => AdjustColumnType(currentProperty, queryId, state)),
        indexedTable = Table.AddIndexColumn(adjustedTypeTable, "Index"),
        finalTable = Table.Join(timeSeriesIdColumn_2, "Index", indexedTable, "Index"),
        final = Table.RemoveColumns(finalTable, "Index")
    in
        final;

// Converts three key to string.
GetTsidString = (TimeSeriesId as list) =>
    let
        quotedTsid = QuotedTsid(TimeSeriesId),
        result = Text.Combine(quotedTsid, ", ")
    in
        result;

// Converts tsid from list to text.
QuotedTsid = (TimeSeriesId as list) =>
    let
        result = List.Transform(TimeSeriesId, QuoteFunc)
    in
        result;

// Checks tsid values.
QuoteFunc = (TimeSeriesIdKey as any) =>
    let
        result = if TimeSeriesIdKey = null then "null" else """"& TimeSeriesIdKey &""""
    in
        result;

// Returns empty table.
GetEmptyTable = () => 
    let
        Source = #table({}, {})
    in 
        Source;

// Returns adjusted column type.
AdjustColumnType = (propertyI as record, queryId as number, t as table) =>
    let
        nameI = propertyI[name],
        typeI = propertyI[type],
        valueType = if typeI = "Double" then type number else type text,
        columnName = GetColumnName(propertyI, queryId),
        result = Table.TransformColumnTypes(t, {columnName, valueType})
    in
        result;

// Returns column values.
GetColumnValues = (propertyI as record) =>
    let
        valuesI = propertyI[values]
    in
        valuesI;

// Returns column name.
GetColumnName = (propertyI as record, queryId as number) =>
    let
        nameI = propertyI[name],
        typeI = propertyI[type],
        finalName = if queryId = null then nameI & "_" & typeI else Text.From(queryId) & "_" & nameI & "_" & typeI
    in
        finalName;

GetInterval = (query as record) =>
    let
        result = if Record.HasFields(query, "getEvents") then query[getEvents][interval]
                 else if Record.HasFields(query, "getSeries") then query[getSeries][interval]
                 else if Record.HasFields(query, "aggregateSeries") then query[aggregateSeries][interval]
                 else error Extension.LoadString("IncorrectApiErrorMessage")
    in
        result;

CalculateDuration = (query as record) =>
    let
        result = if Record.HasFields(query, "getEvents") then GetDuration(query[getEvents][searchSpan][from], query[getEvents][searchSpan][to])
                 else if Record.HasFields(query, "getSeries") then GetDuration(query[getSeries][searchSpan][from], query[getSeries][searchSpan][to])
                 else if Record.HasFields(query, "aggregateSeries") then GetDuration(query[aggregateSeries][searchSpan][from], query[aggregateSeries][searchSpan][to])
                 else error Extension.LoadString("IncorrectApiErrorMessage")
    in
        result;

GetDuration = (from as text, to as text) =>
    let
        duration = (DateTimeZone.From(to) - DateTimeZone.From(from))
    in
        duration;

ToDateTimeText = (dt as datetimezone) => 
    let
        result = DateTimeZone.ToText(dt, "yyyy-MM-ddThh:mm:ssZ")
    in
        result;

WebRequestForQueries = (url as text, postContents as text, headers as record, TimeSeriesId as list, inputResult as table, optional queryId as number) =>
    let
        _url = ValidateUrl(url),
        options = [
                Content= Text.ToBinary(postContents),
                Headers= headers,
                ManualStatusHandling = {400}
        ],
        content = Web.Contents(_url, options),
        bufferedResponse = Binary.Buffer(content),
        jsonPayload = Json.Document(bufferedResponse),

        // We force evaluation of content before checking metadata values to avoid the request being issued a second time.
        httpStatus = Value.Metadata(content)[Response.Status],
        errorResponse = if (bufferedResponse <> null and httpStatus = 400) then
                            error Error.Record(
                                "Bad request",
                                jsonPayload[error][message],
                                [
                                    Code = jsonPayload[error][code],
                                    Error = jsonPayload[error][message],
                                    #"x-ms-request-id" = Record.FieldOrDefault(Value.Metadata(content)[Headers], "x-ms-request-id")
                                ]
                            )
                        else
                            null,
        result = if (errorResponse <> null) then errorResponse 
                 else 
                    if(Record.HasFields(jsonPayload, "continuationToken")) then CheckForContinuationToken(_url, content, jsonPayload[continuationToken], postContents, TimeSeriesId, inputResult, queryId) 
                 else 
                    Table.Combine({inputResult, GetTimeSeriesVariable(content, TimeSeriesId, queryId)})
    in
        result;

CheckForContinuationToken = (url as text, content as binary, continuationToken as text, postContents as text, TimeSeriesId as list, inputResult as table, optional queryId as number) =>
    let
        headers = DefaultRequestHeaders & [ #"x-ms-continuation" = continuationToken ],
        result = Table.Combine({inputResult, GetTimeSeriesVariable(content, TimeSeriesId, queryId)}),

        checkedContent = WebRequestForQueries(url, postContents, headers, TimeSeriesId, result, queryId)
    in
        checkedContent;

ValidateUrl = (url as text) as text =>
    let
        host = Uri.Parts(url)[Host],
        scheme = Uri.Parts(url)[Scheme],
        validUrl = if (scheme <> Text.StartsWith(scheme, "https") = false) or (Text.EndsWith(host, endpoint) = false) then
                       error "Url scheme must be HTTPS or the host must be valid." 
                   else
                       url
    in
        validUrl;

ValidateVersion = (version as text) =>
    let
        result = if (version <> supportedVersion) then error "Invalid query payload version." & version else version
    in
        result;

GetClientActivityId = () => 
    let
        rootActivityId = if (Diagnostics.ActivityId <> null) then Text.From(Diagnostics.ActivityId()) else Text.NewGuid(),
        activityId = Text.NewGuid()
    in
        rootActivityId & ";" & activityId;

// 
// Common library functions.
// 
Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;