// Power BI Data Connector logic for Azure Time Series Insights.
[Version = "1.0.11"]
section TimeSeriesInsights;

dev = "crystal-dev.windows-int.net";
publicProd = "timeseries.azure.com";
mooncakeProd = "timeseries.azure.cn";
warmStoreType = "WarmStore";
coldStoreType = "ColdStore";
versionGen2Preview = "2018-11-01-preview";
versionGen2GA = "2020-07-31";
supportedPreviewVersion = "RDX_20181120_Q";
supportedGAVersion = "RDX_20200713_Q";

authorizationUriLegacy = "https://login.windows.net/common/oauth2/authorize";
// Fixed web service endpoint for Azure Time Series Insights.
resource_uri = "120d688d-1518-4cf7-bd38-182f158850b6";

// 1st party app settings.
client_id = "a672d62c-fc7b-4e81-a576-e60dc46e951d";
// Standard redirect URI for PBI extensions, paired with the above client ID in AAD.
redirect_uri = "https://preview.powerbi.com/views/oauthredirect.html";
DefaultRequestHeadersLegacy = [
                            #"Content-Type" = "application/json; charset=utf-8", 
                            #"Accept" = "application/json", 
                            #"x-ms-app" = Extension.LoadString("TsiConnector"),
                            #"x-ms-client-version" = connectorVersion,
                            #"x-ms-client-request-id" = GetClientActivityId(),
                            #"x-ms-client-application-name" = Extension.LoadString("TsiConnector")
                        ];

DefaultRequestHeaders = [
                            #"Content-Type" = "application/json; charset=utf-8", 
                            #"Accept" = "application/json", 
                            #"x-ms-app" = Extension.LoadString("AzureTsiConnector"),
                            #"x-ms-client-version" = connectorVersion,
                            #"x-ms-client-request-id" = GetClientActivityId(),
                            #"x-ms-client-application-name" = Extension.LoadString("AzureTsiConnector")
                        ];

windowWidth = 1200;
windowHeight = 1000;
connectorVersion = "1.0.9";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Legacy connector code for back compatibility. TODO: Remove support for legacy connector at some point depending on the usage.
// The exported method.
[DataSource.Kind="TimeSeriesInsights"]
shared TimeSeriesInsights.Contents = Value.ReplaceType(TimeSeriesInsights.ContentsInternal, TimeSeriesInsights.ContentsType);

// Data source kind description for legacy connector.
TimeSeriesInsights = [
    Type = "Singleton",
    MakeResourcePath = () => "TimeSeriesInsights",
    ParseResourcePath = (resource) => { },
    TestConnection = (resource) => { "TimeSeriesInsights.Contents",  [ TestConnection = true ] },
    Authentication = [
       Aad = [
			AuthorizationUri = authorizationUriLegacy,
			Resource = resource_uri,
			DefaultClientApplication = [
				ClientId = client_id,
				ClientSecret = "",
				CallbackUrl =  redirect_uri
			]
		]
    ],
    Label = Extension.LoadString("TimeSeriesInsights.ResourceLabel")
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
        navTable = if (query <> null) then ExecuteCustomQueries(query, DefaultRequestHeadersLegacy, true)
                    else error "Query cannot be empty or null."
    in
        if (query[TestConnection]? = true) then 
             Web.Contents("https://api.timeseries.azure.com/environments?api-version=2016-12-12")
        else
             navTable;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Current connector code. This code has Azure B2B / Guest account support. Ref- https://docs.microsoft.com/en-us/azure/active-directory/external-identities/what-is-b2b
// The exported method.
[DataSource.Kind="AzureTimeSeriesInsights"]
shared AzureTimeSeriesInsights.Contents = Value.ReplaceType(AzureTimeSeriesInsights.ContentsInternal, AzureTimeSeriesInsightsImplementation[AzureTimeSeriesInsights.ContentsType]);

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// The Resource record defines a specific data source extension. This record is where you'll define your exports (i.e. which functions will be exposed to end users), 
// branding information, supported authentication types, and how to uniquely identify a credential (known as a "Resource Path").
// Each Resource has a unique name (Description) used to identify and distinguish it from other data sources. After defining your Resource, it is registered using the Extension.Module function.
AzureTimeSeriesInsights = [
    // The type of the resource specifies how its credentials should be uniquely identified. must be one of the following values:
    //  - Singleton
    //  - Url
    //  - Custom
    Type = "Custom",

    // This function accepts the same set of arguments as your data source function, and returns a text value that will uniquely identify an instance of your data source.
    MakeResourcePath = (query) => GetEnvironmentFqdn(query),

    // This function is able to convert a text value into the arguments of your data source function. It will receive the output of the MakeResourcePath function. 
    // It returns a list of values, in the same order as your data source function arguments.
    ParseResourcePath = (resource) => { resource },

    // (optional) This function is used to validate whether the credentials entered for your data source are valid. 
    // It returns a list containing the name of your exported data source function and its arguments. Providing a TestConnection function is optional, but recommended.
    TestConnection = (resource) => { "AzureTimeSeriesInsights.Contents",  [ TestConnection = resource ] },

    // AAD Authtentication.
    Authentication = [
       Aad = [
			AuthorizationUri = (resource) => AzureTimeSeriesInsightsImplementation[AzureTimeSeriesInsights.GetAuthorizationUrlFromWwwAuthenticate](resource),
			Resource = resource_uri,
			DefaultClientApplication = [
				ClientId = client_id,
				ClientSecret = "",
				CallbackUrl =  redirect_uri
			]
		]
    ],

    // Contains the function(s) you are exporting, and their definition. The record key becomes the exported function name, and the value is the function itself.
    Label = Extension.LoadString("AzureTimeSeriesInsights.ResourceLabel")
];

AzureTimeSeriesInsightsImplementation =
    let
        GetAuthorizationUrlFromWwwAuthenticate = (environmentFqdn) =>
        let
            // Sending an unauthenticated request with an empty bearer token will result in a 401 status with WWW-Authenticate header in the response.
            // The value will contain the correct authorization_uri.
            //
            // Currently, Azure Time Series Insights is supported only on Public and Mooncake cloud. 
            // In future, once the other private clouds are supported, the changes should be made in Backend service to return correct auth URL.
            // Example:
            // For Public clouds - Bearer authorization_uri="https://login.microsoftonline.com/{tenant_guid}/oauth2/authorize", resource_id="120d688d-1518-4cf7-bd38-182f158850b6"
            // For Mooncake - Bearer authorization_uri="https://login.chinacloudapi.cn/{tenant_guid}/oauth2/authorize", resource_id="120d688d-1518-4cf7-bd38-182f158850b6"
            //
            url = "https://" & environmentFqdn & "/availability?api-version=" & versionGen2GA,
            uri = ValidateUrl(url),
            options = [
                Headers= DefaultRequestHeaders & [ Authorization = "Bearer" ],
                ManualStatusHandling = {401}
            ],
            response = Web.Contents(uri, options),
            headers = Record.FieldOrDefault(Value.Metadata(response), "Headers", []),
            wwwAuthenticate = Record.FieldOrDefault(headers, "WWW-Authenticate", ""),
            errorResponse = if (wwwAuthenticate = "") then error Error.Record("DataSource.Error", Extension.LoadString("Errors.WwwAuthenticateNotFound")) else null,
            authorizationUri = Text.BetweenDelimiters(wwwAuthenticate, "authorization_uri=""", """")
        in
            if (errorResponse <> null) then errorResponse else authorizationUri,

        AzureTimeSeriesInsights.ContentsType = 
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

                functionType = type function (query as jsonRecord) as table
            in
                functionType meta [
                    Documentation.Name = Extension.LoadString("DataSourceLabel")
                ]
    in
        [
            AzureTimeSeriesInsights.GetAuthorizationUrlFromWwwAuthenticate = GetAuthorizationUrlFromWwwAuthenticate,
            AzureTimeSeriesInsights.ContentsType = AzureTimeSeriesInsights.ContentsType
        ];

AzureTimeSeriesInsights.ContentsInternal = (query as record) =>
    let
        navTable = if (query <> null) then ExecuteCustomQueries(query, DefaultRequestHeaders, false)
                    else error "Query cannot be empty or null."
    in
        if (Record.HasFields(query, "TestConnection")) then // Checks if the input is environmentFqdn.
             WebRequestForTestConnection(query[TestConnection])
        else
             navTable;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Common code between both the connectors. We have isBackCompatRequired to distinguish between legacy and new connector.
// Custom query.
ExecuteCustomQueries = (query as record, headers as record, isBackCompatRequired as logical) => 
    let
        jsonPayload = GetJsonPayloadFromText(query[JsonPayload]),
        apiVersion = ValidateAndGetVersion(jsonPayload[clientDataType]),
        storeType = if isBackCompatRequired then warmStoreType else ValidateStoreType(jsonPayload[storeType]),
        useRelativeSearchspan = if Record.HasFields(jsonPayload, "isSearchSpanRelative") then jsonPayload[isSearchSpanRelative] else false,
        urlParameters = [ EnvironmentFqdn = jsonPayload[environmentFqdn], ApiVersion = apiVersion, StoreType = storeType ],
        result = ExecuteQueries(urlParameters, jsonPayload[queries], headers, useRelativeSearchspan, isBackCompatRequired)
    in
        result;

// Multiple custom query.
ExecuteQueries = (urlParameters as record, queries as list, headers as record, useRelativeSearchspan as logical, isBackCompatRequired as logical) =>
    let
        columnNames = GetTimestampAndTsidPropertiesColumnNames(urlParameters, headers, isBackCompatRequired),
        result = 
            if List.Count(queries) > 1 then
                Table.Combine(List.Generate(() => [i = 0, t = GetQueryResult(urlParameters, queries{0}, 0, headers, columnNames, useRelativeSearchspan, isBackCompatRequired)], 
                                                  each [i] < List.Count(queries), 
                                                  each [t = GetQueryResult(urlParameters, queries{i}, i, headers, columnNames, useRelativeSearchspan, isBackCompatRequired), i = [i] + 1], 
                                                  each [t]))
            else
                GetQueryResult(urlParameters, queries{0}, 0, headers, columnNames, useRelativeSearchspan, isBackCompatRequired)
    in
        result;

GetTimestampAndTsidPropertiesColumnNames = (urlParameters as record, headers as record, isBackCompatRequired as logical) =>
    let
        result = if isBackCompatRequired then 
                    [ Timestamp = "_Timestamp", TimeSeriesIdProperties = { "_TimeSeriesId_0", "_TimeSeriesId_1", "_TimeSeriesId_2" } ] 
                else
                    [ Timestamp = "Timestamp", TimeSeriesIdProperties = GetTimeSeriesIdProperties(urlParameters, headers) ]              
    in
        result;

// Gets the time series ID properties of the environment from Model Settings API. Reference - https://docs.microsoft.com/en-us/rest/api/time-series-insights/dataaccessgen2/modelsettings/get
GetTimeSeriesIdProperties = (urlParameters as record, headers as record) =>
    let
        url = "https://" & urlParameters[EnvironmentFqdn] & "/timeseries/modelSettings?api-version=" & urlParameters[ApiVersion],
        content = WebRequestForTimeSeriesModelQuery(url, headers),
        timeSeriesIdProperties = content[modelSettings][timeSeriesIdProperties],
        tsid0 = { timeSeriesIdProperties{0}[name] & "_" & timeSeriesIdProperties{0}[type] },
        tsid1 = if List.Count(timeSeriesIdProperties) >= 2 then List.Combine({ tsid0, { timeSeriesIdProperties{1}[name] & "_" & timeSeriesIdProperties{1}[type] }}) else tsid0,
        result = if List.Count(timeSeriesIdProperties) >= 3 then List.Combine({ tsid1, { timeSeriesIdProperties{2}[name] & "_" & timeSeriesIdProperties{2}[type] }}) else tsid1
    in
        result;

GetQueryResult = (urlParameters as record, query as record, queryIdx as number, headers as record, columnNames as record, useRelativeSearchspan as logical, isBackCompatRequired as logical) =>
    let
        result = if isBackCompatRequired then
                    ExecuteQuery(urlParameters, query, headers, columnNames, useRelativeSearchspan, queryIdx)
                 else
                    ExecuteQuery(urlParameters, query, headers, columnNames, useRelativeSearchspan)
    in
        result;

ExecuteQuery = (urlParameters as record, query as record, headers as record, columnNames as record, useRelativeSearchspan as logical, optional queryIdx as number) =>
    let 
        revisedQuery = if (useRelativeSearchspan = true) then GetRevisedQuery(query) else query,
        postContents = Text.FromBinary(Json.FromValue(revisedQuery)),
        url = "https://" & urlParameters[EnvironmentFqdn] & "/timeseries/query?api-version=" & urlParameters[ApiVersion] & "&storeType=" & urlParameters[StoreType],
        timeSeriesId = if Record.HasFields(revisedQuery, "getEvents") then revisedQuery[getEvents][timeSeriesId]
                       else if Record.HasFields(revisedQuery, "getSeries") then revisedQuery[getSeries][timeSeriesId]
                       else if Record.HasFields(revisedQuery, "aggregateSeries") then revisedQuery[aggregateSeries][timeSeriesId]
                       else error Extension.LoadString("IncorrectApiErrorMessage"),
        content = WebRequestForTimeSeriesQuery(url, postContents, headers, timeSeriesId, GetEmptyTable(), revisedQuery, columnNames, queryIdx)                               
    in
        content;

GetRevisedQuery = (query as record) =>
    let
        timeNow = DateTimeZone.UtcNow(),
        duration = CalculateDuration(query),
        fromRevised = ToDateTimeText(timeNow - duration),
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

// Returns the time series value (result).
GetTimeSeriesValue = (content as binary, timeSeriesId as list, query as record, columnNames as record, optional queryIdx as number) =>
    let 
        timeSeriesValue = Json.Document(content),
        timestamps = timeSeriesValue[timestamps],
        result = if List.Count(timestamps) = 0 then GetEmptyTable() 
                 else GetTimeSeriesValueHelper(timeSeriesValue, timeSeriesId, query, columnNames, queryIdx)
    in
        result;

GetTimeSeriesValueHelper = (timeSeriesValue as record, timeSeriesId as list, query as record, columnNames as record, optional queryId as number) =>
    let 
        timestamps = timeSeriesValue[timestamps],
        timestampTable = Table.FromList(timestamps, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        renamedTable = Table.RenameColumns(timestampTable, {{ "Column1", columnNames[Timestamp] }}),
        transformedTimestamps = Table.TransformColumnTypes(renamedTable, {{ columnNames[Timestamp], type datetime }}),
        indexedTimestamps = Table.AddIndexColumn(transformedTimestamps, "Index"),
        timeSeriesIdColumn_0 = Table.AddColumn(indexedTimestamps, columnNames[TimeSeriesIdProperties]{0}, each timeSeriesId{0},  type text),
        timeSeriesIdColumn_1 = if List.Count(timeSeriesId) >= 2 then Table.AddColumn(timeSeriesIdColumn_0, columnNames[TimeSeriesIdProperties]{1}, each timeSeriesId{1},  type text) else timeSeriesIdColumn_0,
        timeSeriesIdColumn_2 = if (Record.HasFields(query, "getEvents") and queryId = null) then // We don't add time series Id properties columns for new(prefix column name) connector since Get Events already returns it from backend API.
                                    indexedTimestamps         
                               else if List.Count(timeSeriesId) >= 3 then 
                                    Table.AddColumn(timeSeriesIdColumn_1, columnNames[TimeSeriesIdProperties]{2}, each timeSeriesId{2},  type text) 
                               else timeSeriesIdColumn_1,
        properties = timeSeriesValue[properties],
        column0 = GetColumnValues(properties{0}),
        name0 = GetColumnName(properties{0}, query, columnNames, timeSeriesId, queryId),
        result = Table.FromColumns(
                    List.Generate(
                        () => [i = 0, t = column0], 
                        each [i] < List.Count(properties), 
                        each [t = GetColumnValues(properties{i}), i = [i] + 1], 
                        each [t]),
                    List.Generate(
                        () => [i = 0, t = name0], 
                        each [i] < List.Count(properties), 
                        each [t = GetColumnName(properties{i}, query, columnNames, timeSeriesId, queryId), i = [i] + 1], 
                        each [t])),
        adjustedTypeTable = List.Accumulate(
                        properties,
                        result,
                        (state, currentProperty) => AdjustColumnType(currentProperty, state, query, columnNames, timeSeriesId, queryId)),
        indexedTable = Table.AddIndexColumn(adjustedTypeTable, "Index"),
        finalTable = Table.Join(timeSeriesIdColumn_2, "Index", indexedTable, "Index"),
        final = Table.RemoveColumns(finalTable, "Index")
    in
        final;

// Converts three key to string.
GetTsidString = (timeSeriesId as list) =>
    let
        quotedTsid = QuotedTsid(timeSeriesId),
        result = Text.Combine(quotedTsid, ", ")
    in
        result;

// Converts tsid from list to text.
QuotedTsid = (timeSeriesId as list) =>
    let
        result = List.Transform(timeSeriesId, QuoteFunc)
    in
        result;

// Checks tsid values.
QuoteFunc = (timeSeriesIdKey as any) =>
    let
        result = if timeSeriesIdKey = null then "null" else """"& timeSeriesIdKey &""""
    in
        result;

// Returns empty table.
GetEmptyTable = () => 
    let
        Source = #table({}, {})
    in 
        Source;

// Returns adjusted column type.
AdjustColumnType = (propertyI as record, t as table, query as record, columnNames as record, timeSeriesId as list, optional queryId as number) =>
    let
        nameI = propertyI[name],
        typeI = propertyI[type],
        columnName = GetColumnName(propertyI, query, columnNames, timeSeriesId, queryId),
        valueType = if typeI = "Bool" then type nullable Logical.Type
                    else if typeI = "DateTime" then type nullable DateTime.Type
                    else if typeI = "Double" then type nullable Double.Type
                    else if typeI = "Dynamic" then type nullable Any.Type
                    else if typeI = "Long" then type nullable Int64.Type
                    else if typeI = "String" then type nullable Text.Type
                    else error "Unsupported data type",
        result = Table.TransformColumnTypes(t, {columnName, valueType})
    in
        result;

// Returns column values.
GetColumnValues = (propertyI as record) =>
    let
        valuesI = propertyI[values]
    in
        valuesI;

// For Aggregate Series and Get Series API, if the variable column name collides with the time series ID properties column name, we add "_" at the end of the variable column name.
GetColumnName = (propertyI as record, query as record, columnNames as record, timeSeriesId as list, optional queryId as number) =>
    let
        nameI = propertyI[name],
        typeI = propertyI[type],
        columnName = nameI & "_" & typeI,
        tsidProperties = columnNames[TimeSeriesIdProperties],
        finalName = if queryId <> null then
                        Text.From(queryId) & "_" & columnName
                    else if Record.HasFields(query, "getEvents") then 
                        columnName
                    else if ((tsidProperties{0} = columnName) or (List.Count(timeSeriesId) >= 2 and tsidProperties{1} = columnName) or (List.Count(timeSeriesId) >= 3 and tsidProperties{2} = columnName)) then 
                        columnName & "_"
                    else 
                        columnName                    
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
        duration = (DateTimeZone.FromText(to) - DateTimeZone.FromText(from))
    in
        duration;

ToDateTimeText = (dt as datetimezone) => 
    let
        result = DateTimeZone.ToText(dt, "yyyy-MM-ddTHH:mm:ssZ")
    in
        result;

GetEnvironmentFqdn = (query as record) =>
    let
        jsonPayload = GetJsonPayloadFromText(query[JsonPayload]),
        environmentFqdn = jsonPayload[environmentFqdn],
        errorResponse = if(environmentFqdn = null or Text.Length(Text.Trim(environmentFqdn)) = 0) then error Error.Record("DataSource.Error", Extension.LoadString("Errors.InvalidEnvironmentFqdn")) else null,        
        result = if (errorResponse <> null) 
                    then errorResponse
                 else 
                    environmentFqdn
    in
        if (Record.HasFields(query, "TestConnection")) then 
             query[TestConnection]
        else
             result;

GetJsonPayloadFromText = (jsonPayloadText as text) =>
    let
        errorResponse = if(jsonPayloadText = null or Text.Length(Text.Trim(jsonPayloadText)) = 0) then error Error.Record("DataSource.Error", Extension.LoadString("Errors.InvalidJsonPayload")) else null,
        jsonPayload = Json.Document(Text.ToBinary(jsonPayloadText)),
        result = if (errorResponse <> null) 
                    then errorResponse
                 else 
                    jsonPayload
    in
        result;

// This is a Test Connection call. This calls Model Settings API and expects successful query to validate the resource.
WebRequestForTestConnection = (environmentFqdn as text) =>
    let
        url = "https://" & environmentFqdn & "/timeseries/modelSettings?api-version=" & versionGen2GA,
        _url = ValidateUrl(url),
        options = [ Headers = DefaultRequestHeaders ],
        content = Web.Contents(_url, options)
    in
        content;

WebRequestForTimeSeriesModelQuery = (url as text, headers as record) =>
    let
        _url = ValidateUrl(url),
        options = [
                Headers = headers,
                ManualStatusHandling = {400}
        ],
        content = Web.Contents(_url, options),
        bufferedResponse = Binary.Buffer(content),
        jsonPayload = Json.Document(bufferedResponse),
        errorResponse = ValidateResult(content, jsonPayload, bufferedResponse),
        result = if (errorResponse <> null) 
                    then errorResponse 
                 else 
                    jsonPayload
    in
        result;

WebRequestForTimeSeriesQuery = (url as text, postContents as text, headers as record, timeSeriesId as list, inputResult as table, query as record, columnNames as record, optional queryIdx as number) =>
    let
        _url = ValidateUrl(url),
        options = [
                Content = Text.ToBinary(postContents),
                Headers = headers,
                ManualStatusHandling = {400, 401, 403, 404, 500}
        ],
        content = Web.Contents(_url, options),
        bufferedResponse = Binary.Buffer(content),
        jsonPayload = Json.Document(bufferedResponse),
        errorResponse = ValidateResult(content, jsonPayload, bufferedResponse),
        result = if (errorResponse <> null) then errorResponse 
                 else 
                    if(Record.HasFields(jsonPayload, "continuationToken")) then CheckForContinuationToken(_url, content, jsonPayload[continuationToken], postContents, headers, timeSeriesId, inputResult, query, columnNames, queryIdx) 
                 else 
                    Table.Combine({inputResult, GetTimeSeriesValue(content, timeSeriesId, query, columnNames, queryIdx)})
    in
        result;

ValidateResult = (content as binary, jsonPayload as any, bufferedResponse as binary) =>
    let
        // We force evaluation of content before checking metadata values to avoid the request being issued a second time.
        httpStatus = Value.Metadata(content)[Response.Status],
        errorResponse = if (bufferedResponse <> null and httpStatus = 400) then
                            error Error.Record(
                                "Bad request",
                                jsonPayload[error][message],
                                [
                                    Code = jsonPayload[error][code],
                                    Error = jsonPayload[error][message],
                                    #"x-ms-activity-id" = Record.FieldOrDefault(Value.Metadata(content)[Headers], "x-ms-activity-id"),
                                    #"x-ms-client-request-id" = Record.FieldOrDefault(Value.Metadata(content)[Headers], "x-ms-client-request-id")
                                ]
                            )
                        else if (bufferedResponse <> null and (httpStatus = 401 or httpStatus = 403)) then
                            error Extension.CredentialError(
                                if (httpStatus = 401) then Credential.AccessDenied else Credential.AccessForbidden,
                                jsonPayload[error][message],
                                [
                                    Code = jsonPayload[error][code],
                                    Error = jsonPayload[error][message],
                                    #"x-ms-activity-id" = Record.FieldOrDefault(Value.Metadata(content)[Headers], "x-ms-activity-id"),
                                    #"x-ms-client-request-id" = Record.FieldOrDefault(Value.Metadata(content)[Headers], "x-ms-client-request-id")
                                ]
                            )
                        else if (bufferedResponse <> null and httpStatus = 404) then
                            error Error.Record(
                                "DataSource.NotFound",
                                jsonPayload[error][message],
                                [
                                    Code = jsonPayload[error][code],
                                    Error = jsonPayload[error][message],
                                    #"x-ms-activity-id" = Record.FieldOrDefault(Value.Metadata(content)[Headers], "x-ms-activity-id"),
                                    #"x-ms-client-request-id" = Record.FieldOrDefault(Value.Metadata(content)[Headers], "x-ms-client-request-id")
                                ]
                            )
                        else if (bufferedResponse <> null and httpStatus >= 400) then
                            error Error.Record(
                                "DataSource.Error",
                                jsonPayload[error][message],
                                [
                                    Code = jsonPayload[error][code],
                                    Error = jsonPayload[error][message],
                                    #"x-ms-activity-id" = Record.FieldOrDefault(Value.Metadata(content)[Headers], "x-ms-activity-id"),
                                    #"x-ms-client-request-id" = Record.FieldOrDefault(Value.Metadata(content)[Headers], "x-ms-client-request-id")
                                ]
                            )
                        else
                            null
    in
        errorResponse;

CheckForContinuationToken = (url as text, content as binary, continuationToken as text, postContents as text, headers as record, timeSeriesId as list, inputResult as table, query as record, columnNames as record, optional queryIdx as number) =>
    let
        headers = headers & [ #"x-ms-continuation" = continuationToken ],
        result = Table.Combine({inputResult, GetTimeSeriesValue(content, timeSeriesId, query, columnNames, queryIdx)}),

        checkedContent = WebRequestForTimeSeriesQuery(url, postContents, headers, timeSeriesId, result, query, columnNames, queryIdx)
    in
        checkedContent;

ValidateUrl = (url as text) as text =>
    let
        host = Uri.Parts(url)[Host],
        scheme = Uri.Parts(url)[Scheme],
        validUrl = if (scheme <> Text.StartsWith(scheme, "https") = false) or (Text.EndsWith(host, publicProd) = false and Text.EndsWith(host, mooncakeProd) = false) then
                       error Error.Record("Error", Extension.LoadString("InvalidUrl")) 
                   else
                       url
    in
        validUrl;

ValidateAndGetVersion = (version as text) =>
    let
        result = if (version = supportedGAVersion) then 
                    versionGen2GA 
                 else if (version = supportedPreviewVersion) then
                    versionGen2Preview
                 else
                    error Error.Record("Error", Extension.LoadString("InvalidQueryPayloadVersion"))
    in
        result;

ValidateStoreType = (storeType as text) =>
    let
        result = if (storeType <> warmStoreType) and (storeType <> coldStoreType) then 
                    error Error.Record("Error", Extension.LoadString("InvalidStoreType"))
                 else 
                    storeType
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