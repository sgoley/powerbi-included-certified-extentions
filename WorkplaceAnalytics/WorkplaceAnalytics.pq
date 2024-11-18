//------------------------------------------------------------
// Copyright (c) Microsoft Corporation.  All rights reserved.
//------------------------------------------------------------
[Version = "2.0.22"]
section WorkplaceAnalytics;

// This is currently pointed at the PPE environment.
// to change this locally, substitute these values:
// Local: https://localhost:44300/
// PPE (WPA): https://wpappe.microsoft.com/
// PPE (Nova): https://novappe.microsoft.com/
// PROD (WPA): https://workplaceanalytics.office.com/
// PROD (Nova): https://api.orginsights.viva.office.com/
// GCC (Nova): https://api.gcc.orginsights.viva.office.com/
// When testing on PPE, make sure to add the tenantId header to the GetHeader definition as well. Also hardcode the Authentication Resource as specified in the code.
// Nova PPE requires an additional resource string to be added.
// If you're trying to capture traffic with Fiddler to look at the API results, it wont work with localhost addresses unless you change them to localhost.fiddler
// Also - at the bottom of this file, there is a resource URI token that must be changed when testing locally. This does not need to be changed for other environments.
// Resource strings: you only need to change this for Local. Change the return value from GetResourceFromDataSourcePath() with the following string.
// Local: "83649322-5ddc-469b-a1cb-09364798fba8"

// We define 3 "View" functions in this connector:
// 1. "WorkplaceAnalyticsDirectQueryView": responsible for all requests (Viva or WPA) to the Dashboards API.
// 2. "RowLevelDataView": responsible for requests to the Dataload API.
// 3. "WorkplaceAnalyticsNavigation": responsible for listing all FQ jobs when given a query name to search.
// When a specific query is selected in the navigation view, "WorkplaceAnalyticsDirectQueryView" is called.

WPA_BASE_URL = "https://workplaceanalytics.office.com/";

// Enables caching.
Extension.Cache = try #shared[Extension.Cache] otherwise () => [Metadata = [Serialized = (key, ctor) => ctor()]];

// List of environments supported
Environments = [
    global = "global",
    gcc = "gcc"
];

NovaAPIBaseUri = [
    global      = "https://api.orginsights.viva.office.com/",
    gcc         = "https://api.gcc.orginsights.viva.office.com/",
    ppe         = "https://novappe.microsoft.com/"
];

// DebugMode set to true enables diagnostics trace logs
DebugMode = false;

// Helper function to get the resource of a specific environment
Utility.GetUrlWithEnv = (baseUrlList as record, env as text, default as text) as text =>
    let
        baseUrl = Record.FieldOrDefault(baseUrlList, env, default)
    in
        baseUrl;

// FeatureSwitch that defaults to the global cloud
Env = Environment.FeatureSwitch("Cloud", Environments[global]);
NovaBaseUrl = Utility.GetUrlWithEnv(NovaAPIBaseUri, Env, NovaAPIBaseUri[global]);

// If the env we receive is null or empty we will resort to default environment. Environment override is only allowed if the current pbi environment is not set to GCC. (security purposes)
SetGetResultsEnvironment = (optional getResultsEnvironment as text) as text => 
    if (getResultsEnvironment = null or getResultsEnvironment = "") then Env else if Env = Environments[gcc] then Env else getResultsEnvironment;

// The getNextPage function takes a single argument and is expected to return a nullable table
// This function is from: https://docs.microsoft.com/en-us/power-query/helperfunctions#tablegeneratebypage
Table.GenerateByPage = (getNextPage as function) as table =>
    let        
        listOfPages = List.Generate(
            () => getNextPage(null),            // get the first page of data
            (lastPage) => lastPage <> null,     // stop when the function returns null
            (lastPage) => getNextPage(lastPage) // pass the previous page to the next function call
        ),
        // concatenate the pages together
        tableOfPages = Table.FromList(listOfPages, Splitter.SplitByNothing(), {"Column1"}),
        firstRow = tableOfPages{0}?
    in
        // if we didn't get back any pages of data, return an empty table
        // otherwise set the table type based on the columns of the first page
        if (firstRow = null) then
            Table.FromRows({})
        else        
            Value.ReplaceType(
                Table.ExpandTableColumn(tableOfPages, "Column1", Table.ColumnNames(firstRow[Column1])),
                Value.Type(firstRow[Column1])
            );

// --------------------------------------------------------------------
// Globals
// --------------------------------------------------------------------

Endpoints = [
    API_SIMPLE_QUERY_WPA = "api/Dashboard/GetQueryResults",
    API_SIMPLE_QUERY = (tenantId as text, scopeId as text) => "v1.0/tenants/" & tenantId & "/scopes/" & scopeId & "/databaseQuery",
    API_JOBS = "api/Jobs/GetJobList?api-Version=1.0&sortColumn=Job.JobExecutionStatus.SubmitTime&isAsc=false&pageSize=25&reportEntityType=undefined", // This should not need all the parameters
    API_FQ_READY_WPA = "api/Dashboard/IsQueryDatabaseReady?api-Version=1.0",
    API_FQ_READY = (tenantId as text, scopeId as text, databaseQueryId as text) => "v1.0/tenants/" & tenantId & "/scopes/" & scopeId & "/databaseQuery/" & databaseQueryId & "/ready",
    API_GET_JOB = "api/Jobs/GetById?api-version=1.0",
    API_SIGNED_IN_USER = "api/Users/SignedInUser",
    API_ROW_DATALOAD = (tenantId as text, scopeId as text, reportId as text) => "v1.0/tenants/" & tenantId & "/scopes/" & scopeId & "/reports/" & reportId & "/result",
    API_ROW_DATALOAD_AND_TABLE = (tenantId as text, scopeId as text, reportId as text, tableName as text) => "v1.0/tenants/" & tenantId & "/scopes/" & scopeId & "/reports/" & reportId & "/result/" & tableName 
];

CacheKeys = [
    SIGNED_IN_USER = () => "SignedInUser",
    FQ_READY = (reportId as text) => "FQReady" & reportId,
    DATALOAD_SCHEMA = (reportId as text, optional tableName as text) => if tableName <> null then "DataloadReportSchema" & reportId & "/tableName" & tableName else "DataloadReportSchema" & reportId
];

AcceptHeaders = [
    CSV = "text/csv",
    JSON = "application/json"
];

// --------------------------------------------------------------------
// Endpoint Selection Functions
// --------------------------------------------------------------------

GetEndpoint = (endpointUri as text, baseUrl as text) as text => baseUrl & endpointUri;

// Dynamically determines which base url to use based on provided scopeId.
ParseScopeId = (scopeId as text) as record => 
    let
        targetingNova = if Text.StartsWith(scopeId, "Viva", Comparer.OrdinalIgnoreCase) then true else false,
        targetUrl = if targetingNova then NovaBaseUrl else WPA_BASE_URL,
        parsedScopeId = if targetingNova then Text.AfterDelimiter(scopeId, ":") else scopeId

    in
        [
            isNova = targetingNova,
            Url = targetUrl,
            ScopeId = parsedScopeId
        ];

// Dynamically determines which base url to use based on provided scopeId (for VivaInsights.Data function)
// We also handle the case in which the user passes <scopeId>/<jobId> as the scopeId parameter.
// And to solve the refresh credential problem, we will also accept an alternativeScopeId parameter to be used when the scopeId is hardcoded to "VivaInsightsEmbedded"
// Examples of valid calls ParseScopeIdAndPopulateDatasourceViva("<scopeId", null), ParseScopeIdAndPopulateDatasourceViva("<scopeId>/<jobId>", null), ParseScopeIdAndPopulateDatasourceViva("VivaInsightsEmbedded", "<alternativeScopeId>")
ParseScopeIdAndPopulateDatasourceViva = (scopeId as text, optional alternativeScopeId as text, optional alternativeTenantId, optional alternativeScaleUnit) as record =>
    let 
        targetingNova = if Text.StartsWith(scopeId, "wpa", Comparer.OrdinalIgnoreCase) then false else true,
        targetUrl = if targetingNova then NovaBaseUrl else WPA_BASE_URL,
        actualScope = if scopeId = "VivaInsightsEmbedded" then alternativeScopeId else scopeId,
        auxiliaryScopeId = if targetingNova then actualScope else Text.AfterDelimiter(actualScope, ":"),
        hasDelimiter = Text.Contains(auxiliaryScopeId, "/"),
        parsedScopeId  = if hasDelimiter then List.First(Text.Split(auxiliaryScopeId, "/")) else auxiliaryScopeId,
        additionalJobId = if hasDelimiter then List.Last(Text.Split(auxiliaryScopeId, "/")) else null
    in
        [
            isNova = targetingNova,
            Url = targetUrl,
            ScopeId = parsedScopeId,
            AdditionalJobId = additionalJobId,
            AlternativeTenantId = alternativeTenantId,
            AlternativeScaleUnit = alternativeScaleUnit
        ];

// We receive the data source as a JSON string. 
// This function parses the JSON and returns the provided scopeId.
ExtractScopeIdFromDataSourcePath = (jsonString as text) as text =>
    let
        jsonDataSource = Json.Document(jsonString)
    in 
        jsonDataSource[scopeId];


ExtractEnvironmentFromDataSourcePath = (jsonString as text) as text =>
    let
        jsonDataSource = Json.Document(jsonString)
    in
        jsonDataSource[environment];

// --------------------------------------------------------------------
// Connector Implementation
// --------------------------------------------------------------------

WPAImplementation  = let
    // Increment version when changing code.
    CONNECTOR_VERSION = "2.0.22",

    // Value for server side enum
    Source.PowerBI = "PowerBI",

    // Helper function for deserializing
    ReadResponseDataType = (apiType as text) as type =>
        let 
            typeMap = #table(type table [ApiType = text, ResultingType = text], {
                { "System.Double", type nullable Double.Type },
                { "DoubleType", type nullable Double.Type },
                { "FloatType", type nullable Double.Type },
                { "System.Int64", type nullable Int64.Type },
                { "System.Int32", type nullable Int32.Type },
                { "IntegerType", type nullable Int32.Type },
                { "System.Int16", type nullable Int16.Type },
                { "ShortType", type nullable Int16.Type },
                { "System.UInt64", type nullable Number.Type },
                { "System.UInt32", type nullable Number.Type },
                { "System.UInt16", type nullable Number.Type },
                { "System.Byte", type nullable Byte.Type },
                { "System.Single", type nullable Single.Type },
                { "System.Decimal", type nullable Decimal.Type },
                { "System.Data.SqlDecimal", type nullable Decimal.Type },
                { "System.TimeSpan", type nullable Duration.Type },
                { "System.DateTime", type nullable DateTime.Type },
                { "TimestampType", type nullable DateTime.Type },
                { "System.String", type nullable Text.Type },
                { "System.Object", type nullable Text.Type },
                { "System.Guid", type nullable Text.Type },
                { "StringType", type nullable Text.Type },
                { "System.Boolean", type nullable Logical.Type },
                { "BooleanType", type nullable Logical.Type },
                { "System.SByte", type nullable Logical.Type }
            }),
            convertedType = typeMap{[ApiType = apiType]}?[ResultingType]?
        in
            convertedType ?? (
                error Error.Record(
                    "DataSource.Error",
                    Text.Format("Unsupported date type '#{0}'", {apiType}))
                ),

    // Convert the schema table into a record of column name -> [OriginalTable: val1, ColumnName: val2, DataType: val3]
    // then, if this column exists in the schema, return it's column def
    // if not return [OriginalTable: Source.PowerBI, ColumnName = columnName, DataType = any ]
    GetColumnDescriptor = (columnName as text, schema as record) =>
        let
            labels = schema[Columns],
            rows = schema[Rows],
            fieldNames = List.Accumulate(labels, {}, (prev, label) => prev & {label[ColumnName]}), 
            schemaRecords = List.Transform(rows, (row) => Record.FromList(row, fieldNames)),
            columnNames = List.Transform(schemaRecords, each [ColumnName]),
            rec = Record.FromList(schemaRecords, columnNames)
        in
            if Record.HasFields(rec, {columnName} ) then
                Record.Field(rec, columnName)
            else
                // TODO: determine these values intelligently (ordinal and datatype) https://o365exchange.visualstudio.com/Weve_DA/_workitems/edit/1167130
                [ColumnName = columnName, DataType = Any.Type, OriginalTable = "FlexibleQuery", Ordinal = -1, IsNullable = true],

    GetColumnDescriptorFromTable = (columnName as text, schema as table) =>
            [
                ColumnName = columnName, 
                DataType = if Table.HasColumns(schema, { columnName }) then 
                Type.TableColumn(Value.Type(schema), ColumnName)
                else Any.Type, 
                OriginalTable = Source.PowerBI, 
                Ordinal = -1, 
                IsNullable = true
            ],

    // Columns as { [ Name = x, Function = y, Type = z] }
    ProcessCreatedColumnDefinitions = (columns as list, schema as record) =>
        List.Transform(columns, (rec) =>
            let
                name = Record.Field(rec, "Name"),
                withoutName = Record.RemoveFields(rec, {"Name"})
            in
                Record.AddField(withoutName, "Column", GetColumnDescriptor(name, schema))
        ),

    // Serialize an objects into JSON given a valid schema.
    Serialize = (obj as any, schema) as binary =>
        let     
            // Before we check the type, we want to see if it is an object we don't want to break down further
            // We do this because some objects, like Row.Column, are sometimes considered functions or records, but either way,
            // we don't gain any information by breaking it down further, only reaching an uninterpretable, unserializable base function
            SerializableBaseCases = (value) =>
                if (value = RowExpression.Row) then [Kind = "Constant", Value = "RowExpression.Row", DataType = GetTypeDescriptor(Value.Type("RowExpression.Row"))]
                else if (value = RowExpression.Column) then [Kind = "Constant", Value = "RowExpression.Column", DataType = GetTypeDescriptor(Value.Type("RowExpression.Row"))]
                else null,

            // Recursively parses any object, converting any objects which Json.From() cannot serialize
            // such objects are primarily types and functions
            //
            // Returns the object as the same type, but with any children that would cause Json.From() to fail converted
            // into a friendly primitive type.
            PrepareForSerialization = (value as any) =>
                let
                    base = SerializableBaseCases(value),
                    result = if (base <> null) then base else
                        if value is null then null
                        else if value is function then
                            try @PrepareForSerialization(RowExpression.From(value))
                            otherwise GetFunctionDescriptor(value)

                        else if value is table then 
                            let
                                headers = Table.ColumnNames(value),
                                newHeaders = List.Transform(headers, (i) => @PrepareForSerialization(i)),

                                listOfRows = Table.ToRows(value),
                                newRows = List.Transform(listOfRows, (row) => List.Transform(row, (i) => @PrepareForSerialization(i)))
                            in
                                #table(newHeaders, newRows)

                        else if value is list then List.Transform(value, (i) => @PrepareForSerialization(i))
                        else if value is record then 
                            let
                                recordWithDescriptor = 
                                    if Record.HasFields(value, {"Kind"}) then
                                        if value[Kind] = "FieldAccess" then
                                            let  
                                                name = value[MemberName],
                                                withoutName = Record.RemoveFields(value, {"MemberName"}),
                                                newDescriptor = GetColumnDescriptor(name, schema)
                                            in
                                                Record.AddField(withoutName, "MemberName", newDescriptor)
                                        else if value[Kind] = "Constant" then // Add data type
                                            let
                                                dataType = GetTypeDescriptor(Value.Type(value[Value]))
                                            in 
                                                value & [DataType = dataType]
                                        else value
                                    else value,

                                newValues = List.Transform(Record.ToList(recordWithDescriptor), (i) => @PrepareForSerialization(i)),
                                reconstructedRecord = Record.FromList(newValues, Record.FieldNames(recordWithDescriptor))
                            in
                                reconstructedRecord

                        else if value is type then GetTypeDescriptor(value)
                        else if value is number then value
                        else if value is logical then value
                        // There is no json type for dates or anything like that, so just make them all strings
                        else Text.From(value)
                in
                    // TODO: Investigate what would cause this result from the user side https://o365exchange.visualstudio.com/Weve_DA/_workitems/edit/1130739
                    try result otherwise Diagnostics.Trace(TraceLevel.Information, "FailureWhenSerializing", () => "<error>", true),

            // Get a string which describes the type passed in
            GetTypeDescriptor = (t) as text => 
                // All primitives
                if (t = Null.Type) then "Null.Type"
                else if (t = Logical.Type) then "Logical.Type"
                else if (t = Number.Type) then "Number.Type"
                else if (t = Double.Type) then "Double.Type"
                else if (t = Time.Type) then "Time.Type"
                else if (t = DateTime.Type) then "DateTime.Type"
                else if (t = DateTimeZone.Type) then "DateTimeZone.Type"
                else if (t = Duration.Type) then "Duration.Type"
                else if (t = Text.Type) then "Text.Type"
                else if (t = Binary.Type) then "Binary.Type"
                else if (t = Type.Type) then "Type.Type"
                else if (t = List.Type) then "List.Type"
                else if (t = Record.Type) then "Record.Type"
                else if (t = Table.Type) then "Table.Type"
                else if (t = Function.Type) then "Function.Type"
                else if (t = Any.Type) then "Any.Type"
                else if (t = Table.Type) then "Table.Type"
                else "unknown type",

            // Get a string which desibes the function passed in
            GetFunctionDescriptor = (func) as text =>
                let
                    funcName = Value.Metadata(Value.Type(func))[Documentation.Name]?,

                    newName = if funcName is null then Value.Metadata(func)[Documentation.Name]? else funcName
                in
                    if (newName <> null) then newName
                    else ... // TODO: finalize these mappings https://o365exchange.visualstudio.com/Weve_DA/_workitems/edit/1122276
        in
            Json.FromValue(PrepareForSerialization(obj)),

    // --------------------------------------------------------------------
    // Shared Function Parameter Definitions
    // --------------------------------------------------------------------
    
    // Defines the parameters for the WorkplaceAnalytics.Data function.
    ScopeIdType = type function (
        scopeId as (type text meta [
            Documentation.FieldCaption = Extension.LoadString("ScopeIdCaption"),
            Documentation.FieldDescription = Extension.LoadString("ScopeIdDescription"),
            Documentation.SampleValues = {Extension.LoadString("SampleScopeId")}
        ]), 
        optional jobName as (type text meta [
            Documentation.FieldCaption =  Extension.LoadString("JobNameCaption"),
            Documentation.FieldDescription = Extension.LoadString("JobNameDescription"),
            Documentation.SampleValues = {Extension.LoadString("SampleJobName")}
        ]),
        optional jobId as (type text meta [
            Documentation.FieldCaption = Extension.LoadString("JobIdCaption"),
            Documentation.FieldDescription = Extension.LoadString("JobIdDescription"),
            Documentation.SampleValues = {Extension.LoadString("SampleJobId")},
            Formatting.IsMultiLine = true
        ]),
        optional schemaType as (type text meta [
            Documentation.FieldCaption = Extension.LoadString("SchemaTypeCaption"),
            Documentation.FieldDescription = Extension.LoadString("SchemaTypeDescription"),
            Documentation.AllowedValues = {Extension.LoadString("SchemaTypePivotedValue"), Extension.LoadString("SchemaTypeUnpivotedValue")}
        ])) as table meta [
            Documentation.Name = Extension.LoadString("DocumentationName"),
            Documentation.LongDescription = Extension.LoadString("LongDescription"),
            Documentation.Examples = {[
                Description = Extension.LoadString("ExampleDescription"),
                Code = Extension.LoadString("ExampleCode"),
                Result = Extension.LoadString("ExampleResult")
            ]}
         ],
    
    // Defines the parameters for the VivaInsights.Data function.
    VivaInsightsParameters = let
        scopeId = type text meta [
            Documentation.FieldCaption = Extension.LoadString("ScopeIdCaption"),
            Documentation.FieldDescription = Extension.LoadString("ScopeIdDescription"),
            Documentation.SampleValues = {Extension.LoadString("SampleScopeId")}
        ],
        jobName = type text meta [
            Documentation.FieldCaption =  Extension.LoadString("JobNameCaption"),
            Documentation.FieldDescription = Extension.LoadString("JobNameDescription"),
            Documentation.SampleValues = {Extension.LoadString("SampleJobName")}
        ],
        jobId = type text meta [
            Documentation.FieldCaption = Extension.LoadString("JobIdCaption"),
            Documentation.FieldDescription = Extension.LoadString("JobIdDescription"),
            Documentation.SampleValues = {Extension.LoadString("SampleJobId")},
            Formatting.IsMultiLine = true
        ],
        schemaType = type text meta [
            Documentation.FieldCaption = Extension.LoadString("SchemaTypeCaption"),
            Documentation.FieldDescription = Extension.LoadString("SchemaTypeDescription"),
            Documentation.AllowedValues = {Extension.LoadString("SchemaTypePivotedValue"), Extension.LoadString("SchemaTypeUnpivotedValue")}
        ],
        apiType = type text meta [
            Documentation.FieldCaption = Extension.LoadString("ApiTypeCaption"),
            Documentation.FieldDescription = Extension.LoadString("ApiTypeDescription"),
            Documentation.AllowedValues = {Extension.LoadString("ApiTypeAggregatedDataValue"), Extension.LoadString("ApiTypeRowLevelDataValue")}
        ],
        tableName = type text meta [
            Documentation.FieldCaption = Extension.LoadString("TableNameCaption"),
            Documentation.FieldDescription = Extension.LoadString("TableNameDescription"),
            Documentation.SampleValues = {Extension.LoadString("SampleTableName")}
        ],
        options = type [
            optional SchemaType = schemaType,
            optional APIType = apiType,
            optional TableName = tableName
        ] meta [
            Documentation.FieldCaption = Extension.LoadString("AdvancedParametersValue")
        ]
        in
            type function (scopeId as scopeId, optional jobName as jobName, optional jobId as jobId, optional options as options) as table meta [
                Documentation.Name = Extension.LoadString("DocumentationName"),
                Documentation.LongDescription = Extension.LoadString("LongDescription"),
                Documentation.Examples = {[
                    Description = Extension.LoadString("ExampleDescription"),
                    Code = Extension.LoadString("ExampleCode"),
                    Result = Extension.LoadString("ExampleResult")
            ]}],

    VivaInsightsGetResultsParameters = let
        options = type nullable record,
        env = type nullable text
    in
        type function (optional options as options, optional env as env) as any,

    // --------------------------------------------------------------------
    // Networking, Request Creation, & Response Parsing
    // --------------------------------------------------------------------

    // Executes a web request, forces evaluation and returns the result or the error message
    ExecuteRequest = (url as text, options as record, optional responseType as text) =>
        let
            content = Web.Contents(url, options & [ManualStatusHandling = {400}]),

            // We support both CSV and JSON responses, controlled via the "responseType" parameter.
            bufferedResponse = Binary.Buffer(content),
            parsedResponse = try
                                if responseType = "csv" then [Data = Csv.Document(bufferedResponse), Headers = Value.Metadata(content)[Headers]]
                                else Json.Document(bufferedResponse)
                            otherwise error "Invalid response",

            // We force evaluation of content before checking metadata values to avoid
            // the request being issued a second time.
            httpStatus = Value.Metadata(content)[Response.Status],
            
            // We specifically handle some errors here and return the error records to the caller.
            errorResponse =
                if (bufferedResponse <> null and httpStatus = 400) then
                    error Error.Record(
                        "Bad request",
                        parsedResponse[error][message],
                        [
                            Error = Record.Field(parsedResponse[error], "@message"),
                            Code = parsedResponse[error][code]
                        ]
                    )
                else
                    if (httpStatus = 400) then
                        error "Invalid response"
                    else null
        in
            if (errorResponse <> null) then errorResponse else parsedResponse,
    
    // Checks PBI cache for value before executing the fallback function. No response or error handling is performed here.
    ExecuteCacheRequest = (key as text, fallbackFunction as any) =>
        let
            cachedValue = Json.Document(Extension.Cache()[Metadata][Serialized](key, () => Json.FromValue(fallbackFunction())))
        in
            cachedValue,

    // Calls GetJobList twice, separates the response into two sets of MyJobs and AllJobs. Optionally, filter for a search string by job name. 
    // If no jobs are found with the desired name, return all jobs.
    FilterAndSeparateJobs = (dataSourceInfo as record, optional jobName as text) =>
        let
            baseQueryMyJobs = AddQueryUrl(GetEndpoint(Endpoints[API_JOBS], dataSourceInfo[Url]), "limitToMyJobs=true", "&"),
            baseQueryAllJobs = AddQueryUrl(GetEndpoint(Endpoints[API_JOBS], dataSourceInfo[Url]), "limitToMyJobs=false", "&"),
            searchName = Text.Combine({"searchString", jobName}, "="),
            queryMyJobs = if jobName = null then baseQueryMyJobs 
                          else AddQueryUrl(baseQueryMyJobs, searchName, "&"),
            queryAllJobs = if jobName = null then baseQueryAllJobs 
                           else AddQueryUrl(baseQueryAllJobs, searchName, "&"),
            myJobs = ExecuteRequest(queryMyJobs, [Headers = GetHeaders([scopeId = dataSourceInfo[ScopeId]], not dataSourceInfo[isNova], false), Content = Text.ToBinary("null")]),
            allJobs = ExecuteRequest(queryAllJobs, [Headers = GetHeaders([scopeId = dataSourceInfo[ScopeId]], not dataSourceInfo[isNova], false), Content = Text.ToBinary("null")]),
            myJobsRecord = if Value.Type(myJobs[Response]) = Record.Type then myJobs[Response]
                           else null,
            allJobsRecord = if Value.Type(allJobs[Response]) = Record.Type then allJobs[Response] 
                            else null,
            myJobsList = if myJobsRecord <> null then {myJobsRecord} 
                         else ExtractListFromJobsJSON(myJobs),
            allJobsList = if allJobsRecord <> null then {allJobsRecord} 
                          else ExtractListFromJobsJSON(allJobs),
            intersectionJobsList = List.RemoveMatchingItems(allJobsList, myJobsList),
            jobsResult = if List.Count(myJobsList) = 0 and List.Count(allJobsList) = 0 then @FilterAndSeparateJobs(dataSourceInfo) 
                         else [MyJobs = myJobsList, AllJobs = intersectionJobsList]
        in
           jobsResult,

    // Executes a request to the SignedInUser API if the value is not already cached.
    GetSignedInUserData = (baseUrl as text, scopeId as text, isWpa as logical) =>
        let
            // Defines the network request to get SignedInUser data. 
            // This function is nested inside "GetSignedInUserData" to force all calls to check the cache first.
            ExecuteSignedInUserQuery = (baseUrl as text, scopeId as text, isWpa as logical) =>
                let
                    opts = [Headers = GetHeaders([scopeId = scopeId], isWpa, false)],
                    url = GetEndpoint(Endpoints[API_SIGNED_IN_USER], baseUrl),
                    json = try ExecuteRequest(url, opts) otherwise null
                in
                    if (json = null) then null else json
        in
            ExecuteCacheRequest(CacheKeys[SIGNED_IN_USER](), () => ExecuteSignedInUserQuery(baseUrl, scopeId, isWpa)),

    // Gets the current scale unit from the SignedInUser API.
    GetScaleUnit = (baseUrl as text, scopeId as text, isWpa as logical) =>
        let
            signedInUserResponse = GetSignedInUserData(baseUrl, scopeId, isWpa)
        in
            if (signedInUserResponse = null or signedInUserResponse[ScaleUnit] = null) then null else signedInUserResponse[ScaleUnit],

    // Gets the current TenantId from the SignedInUserAPI.
    GetTenantId = (baseUrl as text, scopeId as text, isWpa as logical) =>
        let
            signedInUserResponse = GetSignedInUserData(baseUrl, scopeId, isWpa)
        in
            try
                List.First(signedInUserResponse[Scopes])[Scope][TenantId]
            otherwise
                null,
    
    // Get (or create) a correlation id to help with logging on the service side.
    GetActivityId = () =>
        let 
            activityId = if (Diagnostics.ActivityId <> null) then Text.From(Diagnostics.ActivityId()) else Text.NewGuid()
        in
            activityId,

    // Returns headers used on our API calls. Can receive optional extra headers as a separate record to be combined
    // For testing on PPE, add #"tenantId"=GetTestTenantId(isWpa) to the list of headers and copy the correct tenantId value into the placeholders in GetTestTenantId().
    GetHeaders = (extraHeaders as record, isWpa as logical, usingRowLevelApi as logical, optional scaleUnit as text) =>
    let
        GetTestTenantId = (isWpa as logical) => if isWpa then "[WPA TenantId]" else "[Nova TenantId]",

        baseHeaders = Record.Combine({[#"api-Version" = "1.0", #"correlationId" = GetActivityId(), #"x-ms-client-version" = CONNECTOR_VERSION], extraHeaders}),

        finalHeaders = if not usingRowLevelApi then Record.Combine({extraHeaders, [#"Content-Type" = "application/json"]}) else extraHeaders
    in
        if scaleUnit = null then finalHeaders else Record.AddField(finalHeaders, "X-Nova-Scaleunit", scaleUnit),
    
    // Adds a query to an URL. Specify either ? or & separator accordingly if its the first query or not
    AddQueryUrl = (url, parameter, separator) => Text.Combine({url, parameter}, separator),

    // Call producer after interval passes, repeat count times or untill producer returns non-null. Returns either null or the first instance of producer to give a result
    Value.WaitFor = (producer as function, interval as function, optional count as number) as any =>
        let
            list = List.Generate(
                () => {0, null},
                (state) => state{0} <> null and (count = null or state{0} < count),
                (state) => if state{1} <> null then {null, state{1}} else {1 + state{0}, Function.InvokeAfter(() => producer(), interval())},
                (state) => state{1})
        in
            List.Last(list),

    // Keeps retrying a web request every second for 10 minutes or until it returns the expected value
    WaitAndRetryRequest = (url as text, options as record, expectedValue) =>
        let
            waitForResult = Value.WaitFor(
                () =>
                    let
                        // IsRetry is needed, otherwise PowerBI will be stuck waiting without actually retrying the call
                        result = ExecuteRequest(url, options & [IsRetry = true]), 
                        actualResult = if result = expectedValue then true else null
                    in
                        actualResult,
                () => #duration(0, 0, 0, 5),
                600)
        in
            if waitForResult = true then true else false,

    // Read the response from the GetJobList API and return it in list of job records form
    ExtractListFromJobsJSON = (json) as list =>
        let
            outerList = json[Response],
            f = (_) =>
                let
                    name = _[JobDefinition][Name],
                    ReportId = _[JobDefinition][ReportId],
                    JobId = _[Id],
                    rec = if (_[JobResult][VisualizationsEnabled] = true) then [Name = name, ReportId = ReportId, JobId = JobId, ItemKind = type table] 
                          else null
                in
                    rec,
            innerList = List.RemoveMatchingItems(List.Transform(outerList, f), {null})
        in
            innerList,
           
    // --------------------------------------------------------------------
    // View Functions
    // --------------------------------------------------------------------
    
    // Main view for Row-Level Dataload API
    RowLevelDataView = (datasourceRecord as record, jobId as text, schemaType as text, optional tableName as text) =>
        let
            // For this function to be called, the request must be in Nova with a valid jobId
            scopeId = datasourceRecord[ScopeId],
            baseUrl = datasourceRecord[Url],
            isWpa = false,
            usingRowLevelApi = true,

            // Get Scale Unit information (unless it is already provided in the datasource record)
            currentScaleUnit = if datasourceRecord[AlternativeScaleUnit] <> null then datasourceRecord[AlternativeScaleUnit] else GetScaleUnit(baseUrl, scopeId, isWpa),
            tenantId = if datasourceRecord[AlternativeTenantId] <> null then datasourceRecord[AlternativeTenantId] else GetTenantId(baseUrl, scopeId, isWpa),

            // Steps:
            // 1. Get "cached schema" since it won't change.
            // 2. Use Query Folding function to load actual data from a CSV.
            endpoint = if tableName <> null then GetEndpoint(Endpoints[API_ROW_DATALOAD_AND_TABLE](tenantId, scopeId, jobId, tableName), baseUrl) else GetEndpoint(Endpoints[API_ROW_DATALOAD](tenantId, scopeId, jobId), baseUrl),
            schemaInfo = GetSchema(endpoint, currentScaleUnit, scopeId),
            reportSchema = schemaInfo[SchemaTable]?,
            reportSchemaTypes = schemaInfo[SchemaTypes]?,

            // Functions

            // Gets the table schema from the cache (if availabe), otherwise requests the schema from the API.
            GetSchema = (schemaUrl as text, scaleUnit as text, scopeId as text) =>
                let
                    // Parses schema from API response into a PowerQuery table object with 0 rows.
                    ParseRawDataloadSchemaResponse = (schemaJson) =>
                        let
                            columnNames = List.Transform(schemaJson, (element) => element[Name]),
                            columnDataTypes = List.Transform(schemaJson, (element) => ReadResponseDataType(Text.From(element[DataType]))),
                            zippedSchema = List.Zip({columnNames, columnDataTypes}),
                            schemaTable = #table(columnNames, {}),
                            typedSchemaTable = Table.TransformColumnTypes(schemaTable, zippedSchema, "")
                        in
                            [SchemaTypes = zippedSchema, SchemaTable = typedSchemaTable],
                    
                    // Send API request when the cache doesn't already contain the requested schema.
                    // Returns parsed schema.
                    ExecuteSchemaRequest = () =>
                        let
                            schemaHeaders = GetHeaders([#"Accept" = AcceptHeaders[JSON]], isWpa, usingRowLevelApi, scaleUnit),
                            rawSchema = ExecuteRequest(schemaUrl, [Headers = schemaHeaders])
                        in
                            rawSchema,
                    
                    // Check cache, otherwise send API request.
                    rawSchema = ExecuteCacheRequest(CacheKeys[DATALOAD_SCHEMA](jobId, tableName), ExecuteSchemaRequest),
                    parsedSchema = ParseRawDataloadSchemaResponse(rawSchema)
                in
                    parsedSchema,
            
            // Gets data table from API.
            GetData = (dataUrl as text, scaleUnit as text, scopeId as text, optional startDate as text, optional endDate as text) =>
                let
                    // If available, returns the continuation token in a Dataload API response.
                    CheckForNextPage = (optional headers as record) => if (headers <> null) then Record.FieldOrDefault(headers, "X-ContinuationToken") else null,

                    // Append queries to base Dataload API url.
                    BuildDataQueryUrl = (baseUrl as text, optional continuationToken as text) =>
                        let
                            continuationTokenQuery = if continuationToken <> null then "continuationToken=" & continuationToken else null,
                            startDateQuery = if startDate <> null then "startTime=" & startDate else null,
                            endDateQuery = if endDate <> null then "endTime=" & endDate else null,
                            availableQueries = Text.Combine({continuationTokenQuery, startDateQuery, endDateQuery}, "&")
                        in
                            if availableQueries = "" then baseUrl else baseUrl & "?" & availableQueries,
                    
                    // Executes a Web.Contents() GET request for a single page of the dataset.
                    ExecuteDataPageRequest = (optional continuationToken as text) =>
                        let
                            acceptHeader = [#"Accept" = AcceptHeaders[CSV]],

                            headers = GetHeaders(acceptHeader, isWpa, usingRowLevelApi, scaleUnit),
                            requestUrl = BuildDataQueryUrl(dataUrl, continuationToken),
                            response = ExecuteRequest(requestUrl, [Headers = headers], "csv")
                        in
                            response,

                    // We need to promote headers for each CSV page and assign proper data types based on the Schema API.
                    ParseRawData = (rawData) =>
                        let
                            promotedHeaders = Table.PromoteHeaders(rawData)
                        in
                            if reportSchemaTypes = null then promotedHeaders
                            else
                                let
                                    orderedColumns = List.Transform(reportSchemaTypes, (item) => item{0}),
                                    orderedDataTable = Table.ReorderColumns(promotedHeaders, orderedColumns, MissingField.Error),
                                    dataWithTypes = Table.TransformColumnTypes(orderedDataTable, reportSchemaTypes, "")
                                in
                                    dataWithTypes,
                    
                    // Calls the Dataload API as many times as necessary to fetch the full dataset associated with the provided jobId.
                    ExecuteDataRequest = () =>
                        Table.GenerateByPage((previous) =>
                            let
                                continuationToken = if previous <> null then Value.Metadata(previous)[ContinuationToken]? else null,
                                currentPage = if (continuationToken = null and previous <> null) then null else ExecuteDataPageRequest(continuationToken),
                                
                                parsedDataPage = if (currentPage <> null) then ParseRawData(currentPage[Data]) else null,
                                nextToken = CheckForNextPage(currentPage[Headers]?)
                            in
                                parsedDataPage meta [ContinuationToken = nextToken]
                        ),

                    dataTable = ExecuteDataRequest()
                in
                    dataTable,

            // Support for query folding.
            DataloadQueryFolding = (state as record) => Table.View(null, [
                        GetType = () => if reportSchema <> null then Value.Type(reportSchema) else Value.Type(GetRows()),
                        GetRows = () =>
                            let
                                // Build and send request to the Dataload API.
                                requestResults = GetData(endpoint, currentScaleUnit, scopeId, state[StartDate]?, state[EndDate]?),

                                // Further filter the returned data table if possible.
                                startDate = DateTime.FromText(state[StartDate]?),
                                endDate = DateTime.FromText(state[EndDate]?),
                                startDateOperatorText = state[StartDateOperator]?,
                                endDateOperatorText = state[EndDateOperator]?,
                                filteredResults = if startDate <> null and startDateOperatorText <> null and endDate <> null and endDateOperatorText <> null then
                                        if startDateOperatorText = "GreaterThan" and endDateOperatorText = "LessThan" then Table.SelectRows(requestResults, each [MetricDate] > startDate and [MetricDate] < endDate)
                                        else if startDateOperatorText = "GreaterThanOrEquals" and endDateOperatorText = "LessThan" then Table.SelectRows(requestResults, each [MetricDate] >= startDate and [MetricDate] < endDate)
                                        else if startDateOperatorText = "GreaterThan" and endDateOperatorText = "LessThanOrEquals" then Table.SelectRows(requestResults, each [MetricDate] > startDate and [MetricDate] <= endDate)
                                        else if startDateOperatorText = "GreaterThanOrEquals" and endDateOperatorText = "LessThanOrEquals" then Table.SelectRows(requestResults, each [MetricDate] >= startDate and [MetricDate] <= endDate)
                                        else requestResults
                                    else if startDate <> null and startDateOperatorText <> null then
                                        if startDateOperatorText = "GreaterThan" then Table.SelectRows(requestResults, each [MetricDate] > startDate)
                                        else if startDateOperatorText = "GreaterThanOrEquals" then Table.SelectRows(requestResults, each [MetricDate] >= startDate)
                                        else requestResults
                                    else if endDate <> null and endDateOperatorText <> null then
                                        if endDateOperatorText = "LessThan" then Table.SelectRows(requestResults, each [MetricDate] < endDate)
                                        else if endDateOperatorText = "LessThanOrEquals" then Table.SelectRows(requestResults, each [MetricDate] <= endDate)
                                        else requestResults
                                    else requestResults
                            in                             
                                filteredResults,

                        OnSelectRows = (selector) =>
                            let
                                // We need to convert DateTime data into a string compatible with the Dataload API.
                                ConvertDateToString = (invocationExpression) => 
                                    let
                                        // Put datetime from query into a standard format for query URL.
                                        year = Text.From(invocationExpression{0}[Value]),
                                        month = Text.From(invocationExpression{1}[Value]),
                                        day = Text.From(invocationExpression{2}[Value])
                                    in
                                        // Ex. 2022-06-07
                                        Text.Combine({year, month, day}, "-"),
                                
                                // Parse the rowExpression tree for a single date selector.
                                ParseSingleDateSelector = (rowExpression) =>
                                    let
                                        // Example PowerQuery captured here: Table.SelectRows(dataTable, each [MetricDate] > #datetime(2021, 12, 19))
                                        expressionKind = rowExpression[Kind]?,
                                        operator = rowExpression[Operator]?,
                                        leftName = rowExpression[Left]?[MemberName]?,
                                        leftKind = rowExpression[Left]?[Kind]?,
                                        rightKind = rowExpression[Right]?[Kind]?,

                                        dateString = if rightKind = "Invocation" then ConvertDateToString(rowExpression[Right][Arguments])
                                                    else if rightKind = "Constant" then DateTime.ToText(rowExpression[Right][Value], [Format="yyyy-MM-dd"]) else ...
                                    in
                                        // We only want to capture selectors with the [MetricDate] column.
                                        // If conditions aren't met, throw an error to fallback to the standard M Engine calculation.
                                        // More details: https://docs.microsoft.com/en-us/power-query/handlingqueryfolding
                                        if expressionKind = "Binary" and leftKind = "FieldAccess" and leftName = "MetricDate"
                                        then if (operator = "GreaterThan" or operator = "GreaterThanOrEquals") 
                                                then [StartDate = dateString, StartDateOperator = operator]
                                                else if (operator = "LessThan" or operator = "LessThanOrEquals") 
                                                    then [EndDate = dateString, EndDateOperator = operator]
                                                    else ...
                                        else ...,

                                // Parse the rowExpression tree for a compound date selector.
                                // Specifically, we support setting an upper and lower bound on the [MetricDate] column.
                                ParseCompoundDateSelector = (rowExpression) =>
                                    let
                                        // Incremental refresh can create an upper and lower bound on time. This handles the case where both are included in the rowExpression.
                                        // Split compound expression into two single operator rowExpressions.
                                        compoundOperator = rowExpression[Operator]?,
                                        leftKind = rowExpression[Left]?[Kind]?,
                                        leftOperator = rowExpression[Left]?[Operator]?,
                                        rightKind = rowExpression[Right]?[Kind]?,
                                        rightOperator = rowExpression[Right]?[Operator]?,

                                        // Parse the upper and lower time bounds separately. If anything goes wrong, throw error to fallback to the standard M Engine calculation.
                                        // rowExpressions that we don't want to handle in query folding are caught in ParseSingleDateSelector().
                                        leftState = try ParseSingleDateSelector(rowExpression[Left]?) otherwise ...,
                                        rightState = try ParseSingleDateSelector(rowExpression[Right]?) otherwise ...
                                    in
                                        // Combine each state since no updated keys should overlap (one updates StartDate, the other updates EndDate).
                                        leftState & rightState,

                                // Try parsing the rowExpression. If the selector isn't supported, we fall back to the standard M Engine implementation.
                                rowExpression = RowExpression.From(selector),
                                updatedState = try ParseSingleDateSelector(rowExpression) 
                                        otherwise try ParseCompoundDateSelector(rowExpression) 
                                            otherwise ...
                            in
                                @DataloadQueryFolding(state & updatedState)
            ])
        in
            DataloadQueryFolding([StartDate=null, EndDate=null, StartDateOperator=null, EndDateOperator=null]),

    // Main view that enables DirectQuery capabilities to the chosen DB
    WorkplaceAnalyticsDirectQueryView = (datasourceRecord as record, jobId as text, schemaType as text) =>  
        let
            scopeId = datasourceRecord[ScopeId],
            baseUrl = datasourceRecord[Url],
            isWpa = not datasourceRecord[isNova],

            // Using this variable to control the flow between GE and IFQ
            isGEQuery = if jobId = "4" then true else false,

            // Get Scale Unit information if making a request to Nova
            currentScaleUnit = if (not isWpa) then (if datasourceRecord[AlternativeScaleUnit] <> null then datasourceRecord[AlternativeScaleUnit] else GetScaleUnit(baseUrl, scopeId, isWpa)) else null,
            tenantId = if datasourceRecord[AlternativeTenantId] <> null then datasourceRecord[AlternativeTenantId] else GetTenantId(baseUrl, scopeId, isWpa),

            // Handle job ids for FQs
            jobIdList = Text.Split(Text.Remove(jobId, " "), ","),
            isMultiTableQuery = if List.Count(jobIdList) > 1 then true else false,
            jobIdText = Text.Combine(jobIdList, "_"),
           
            jobInfo = GetDetailsFromAllJobIds(scopeId, jobIdList),
            jobName = jobInfo[Name],
            reportId = if not isGEQuery then (if isWpa then Text.Combine(jobInfo[ReportId], "_") else jobIdText) else null,
          
            url = if isWpa then GetEndpoint(Endpoints[API_SIMPLE_QUERY_WPA], baseUrl)
                  else GetEndpoint(Endpoints[API_SIMPLE_QUERY](tenantId, scopeId), baseUrl),

            // A default max groups to return is required, so it is not potentially set to zero by a json serialize / deserialze
            defaultQuery = [MaxGroupsToReturn = 100], 
        
            // These are the actual schema values that are returned from the APIs
            // We hold onto these in order to send to the Query API 
            cachedRawSchema = SchemaRequest(url, defaultQuery, scopeId),
                          
            // Empty table with all typed columns, or what Power BI conisders a schema. This is used to type our
            // tables before we return them to Power BI
            cachedSchema = ExtractSchemaFromResponse(cachedRawSchema),

            // State is a record of [query = [], schema = #table()]
            WPAData = (state as record) => if (state[query] <> null) then Table.View(null, Diagnostics.WrapHandlers([
                        GetExpression = () => [
                            Kind = "Invocation",
                            Function =
                            [
                                Kind = "Constant",
                                Value = Value.NativeQuery
                            ],
                            Arguments =
                            {
                                [
                                    Kind = "Invocation",
                                    Function =
                                    [
                                        Kind = "Constant",
                                        Value = VivaInsights.Data
                                    ],
                                    Arguments =
                                    {
                                        [
                                            Kind = "Constant",
                                            Value = scopeId
                                        ],
                                        [
                                            Kind = "Constant",
                                            Value = jobIdText
                                        ]
                                    }
                                ],
                                [
                                    Kind = "NotImplemented"
                                ]
                            }
                        ],

                        // Read up on https://docs.microsoft.com/en-us/power-query/handlingqueryfolding 
                        // To understand what all these functions are - they're basically substituting normal table functions for this particular table
                        // You need to implement GetExpression and OnInvoke if you want your table to have directquery capability 
                        GetSchema = () =>
                            if (state[schema] <> null) then state[schema]
                            else cachedSchema,

                        GetType = () => Value.Type(GetSchema()),

                        GetRows = () =>   
                            let
                                _requestResults = DataRequest(url, state[query], state[InitialQuery], cachedRawSchema, scopeId),
                                schemaTable = GetSchema(),
                                requestResults = Table.ChangeType(_requestResults, Value.Type(schemaTable)),
                                dateTimeColumns = Table.ColumnsOfType(schemaTable, { type nullable datetime }),
                                //Convert AS's datetimezone values to PBI's date type
                                dateFixedResults = Table.TransformColumns(requestResults, List.Transform(dateTimeColumns, (c) => { c, (x) => DateTime.From(x) }))
                           in                             
                                if (state[InitialQuery]) then cachedSchema
                                else dateFixedResults,    
                           
                        GetRowCount = () => 
                            let
                                // TODO: Consider revisiting and improving https://o365exchange.visualstudio.com/Weve_DA/_workitems/edit/1127323
                                dataTable = DataRequest(url, state[query], state[InitialQuery], cachedRawSchema)
                            in
                                Table.RowCount(dataTable),

                        OnInvoke = (function, arguments, index) => 
                            // TODO: Once we add more function maps, and handle them on server side, we should expand this table to reflect our new capabilities. https://o365exchange.visualstudio.com/Weve_DA/_workitems/edit/1122276
                            #table({"Name", "Value"}, 
                            {
                                {"Core", null},
                                {"LiteralCount", 1000},
                    
                                {"Table.FirstN", null},
                                {"Table.Sort", null},
                                {"Table.RowCount", null},

                                {"List.Average", null},
                                {"List.Sum", null},
                                {"List.Min", null},
                                {"List.Max", null},
                                {"List.StandardDeviation", null}
                            }),
                        
                        CombineFilters = (new_filter as record, current_filter as record) as record => [Kind="Binary", Operator="And", Left = current_filter, Right = new_filter],

                        OnSelectRows = (__selector) => 
                            let
                                _selector = Diagnostics.LogValue("Called OnSelectRows", __selector),
                                boolean = Record.HasFields(state[query], "Aggregates"),
                                exists_outer_filter = if Record.HasFields(state, "query") then Record.HasFields(state[query], "OuterFilter") else false,
                                exists_inner_filter = if Record.HasFields(state, "query") then Record.HasFields(state[query], "InnerFilter") else false,

                                selector = if boolean then (if exists_outer_filter = true then CombineFilters(RowExpression.From(_selector), state[query][OuterFilter]) else RowExpression.From(_selector))
                                           else (if exists_inner_filter = true then CombineFilters(RowExpression.From(_selector), state[query][InnerFilter]) else RowExpression.From(_selector)),


                                updated_state_query = if boolean then (if exists_outer_filter then Record.TransformFields(state[query], {{"OuterFilter", each selector}}) else state[query] & [OuterFilter = selector])
                                                      else (if exists_inner_filter then Record.TransformFields(state[query], {{"InnerFilter", each selector}}) else state[query] & [InnerFilter = selector])                    
                            in 
                                @WPAData(state & [query = updated_state_query, InitialQuery = false]),

                        OnSelectColumns = (columns) => 
                            let
                                schema = GetSchema(),
                                newSchema = Table.SelectColumns(schema, columns),
                            
                                descriptors = List.Transform(columns, (columnName) => Diagnostics.Trace(TraceLevel.Information, columnName, GetColumnDescriptorFromTable(columnName, schema))),

                                params = state[query] & [ColumnsSelected = descriptors]
                            in
                                @WPAData(state & [query = params, schema = newSchema, InitialQuery = false]),

                        OnTake = (count as number) =>
                            let
                                // This is the only handler used in the initial query, so we leave the InitialQuery flag at true
                                params = state[query] & [MaxGroupsToReturn = count]
                            in
                                @WPAData(state & [query = params]),

                        OnGroup = (keys, aggregates) =>
                            let
                                // Pass the schema on recursively, typing the new columns we're creating at this step, instead of on server side
                                oldSchema = GetSchema(),
                                relevantSchema = Table.SelectColumns(oldSchema, keys),
                                newSchema = List.Accumulate(aggregates, relevantSchema, (t, agg) => Table.AddColumn(t, agg[Name], (row) => null, agg[Type])),
                               
                                descriptors = List.Transform(keys, (key) => GetColumnDescriptor(key, cachedRawSchema)),
                            
                                params = state[query] & [GroupByKeys = descriptors, Aggregates = ProcessCreatedColumnDefinitions(aggregates, cachedRawSchema)]
                            in
                                @WPAData([query = params, schema = newSchema, InitialQuery = false]),

                        OnDistinct = (columns) =>
                            let
                                // TODO: pass on new schema https://o365exchange.visualstudio.com/Weve_DA/_workitems/edit/1133079
                                params = state[query] & [OnDistinctColumns = columns]
                            in
                                @WPAData(state & [query = params, InitialQuery = false]),

                        OnAddColumns = (_constructors) =>
                            let
                                // In certain scenarios, add columns may be called multiple times with a dependency between them (ex. add column A, then add column B which depends on A).
                                // We have opted to add all the columns in the same "level" and handle the dependencies on our backend query parsing code.
                                constructors = Diagnostics.LogValue("OnAddColumns called", _constructors),
                                exists_add_columns = state[query]?[OnAddColumns]? <> null,
                                
                                oldSchema = if Record.HasFields(state, "query") and Record.HasFields(state[query], "schema") then state[query][schema] else GetSchema(),
                                _newSchema = List.Accumulate(constructors, oldSchema, (t, c) => Table.AddColumn(t, c[Name], each null, c[Type])),
                                newSchema = Diagnostics.LogValue("OnAddColumns newSchema" & Diagnostics.ValueToText(_newSchema), _newSchema),

                                // If we already have an addColumns object, we should append it to the current OnAddColumns list. Otherwise we'll create a new list with it.
                                newAddColumns = if exists_add_columns then List.Combine({state[query][OnAddColumns], ProcessCreatedColumnDefinitions(constructors, cachedRawSchema)}) else ProcessCreatedColumnDefinitions(constructors, cachedRawSchema),
                                params = state[query] & [OnAddColumns = newAddColumns]
                            in
                                @WPAData(state & [query = params, schema = newSchema, InitialQuery = false]),

                        OnSkip = (count as number) => 
                            let
                                params = state[query] & [OnSkipCount = count]
                            in
                                @WPAData(state & [query = params, InitialQuery = false]),

                        OnSort = (order as list) => 
                            let
                                withDescriptors = List.Transform(order, (sortDescriptor) =>
                                    let
                                        columnName = Record.Field(sortDescriptor, "Name"),
                                        withoutName = Record.RemoveFields(sortDescriptor, {"Name"})
                                    in
                                        Record.AddField(withoutName, "Column", GetColumnDescriptor(columnName, cachedRawSchema))
                                ),
                                params = state[query] & [OnSortOrder = withDescriptors]
                            in
                                @WPAData(state & [query = params, InitialQuery = false]),

                        OnInsertRows = (rowsToInsert) =>
                            let
                                params = state[query] & [OnInsertRows = rowsToInsert]
                            in
                                @WPAData(state & [query = params, InitialQuery = false]),
                                
                        OnDeleteRows = (selector) =>
                            let
                                params = state[query] & [OnDeleteRowsSelector = selector]
                            in
                                @WPAData(state & [query = params, InitialQuery = false]),
                            
                        // Renames is a list of lists of two strings == {{oldColName, newColName}}
                        OnRenameColumns = (renames) =>
                            let
                                params = state[query] & [OnRenameColumns = renames],
                                oldSchema = GetSchema(),
                                renamePairs = List.Transform(renames, each {[OldName], [NewName]}),
                                newSchema = Table.RenameColumns(oldSchema, renamePairs)
                            in
                                @WPAData(state & [query = params, schema = newSchema, InitialQuery = false])
                    ])) else error Error.Record("DataSource.Error", "Invalid view state", state),

            // Requests details for a jobId from API_GET_JOB and processes the resulting JSON
            GetDetailsFromJobId = (scopeId as text, currentJobId as text) =>
                let
                    myJob = ExecuteRequest(AddQueryUrl(GetEndpoint(Endpoints[API_GET_JOB], baseUrl), Text.Combine({"jobId", currentJobId}, "="), "&"), [Headers = GetHeaders([scopeId = scopeId], isWpa, false)])
                in
                    myJob[JobDefinition],
            
            // Recursively get details for each provided jobId
            GetDetailsFromAllJobIds = (scopeId as text, jobIdList as list, optional jobNames as list, optional reportIds as list) =>
                let
                    currentJobId = List.First(jobIdList),
                    remainingJobIds = List.RemoveFirstN(jobIdList),
                    currentJob = GetDetailsFromJobId(scopeId, currentJobId),
                    newJobNames = if jobNames <> null then jobNames & { currentJob[Name] } else { currentJob[Name] },
                    newReportIds = if reportIds <> null then reportIds & { currentJob[ReportId] } else { currentJob[ReportId] }
                in
                    if List.IsEmpty(remainingJobIds) then [ JobNames = newJobNames, ReportId = newReportIds ]
                    else @GetDetailsFromAllJobIds(scopeId, remainingJobIds, newJobNames, newReportIds),

            // Our response will contain multiple tables, and format the response the same
            // time regardless which piece of data was requested, though some tables may be null.
            // Thus, the next three functions are designed to extract the desired data out of the 
            // common response format.
            ExtractDataFromResponse = (json) as table =>
                let 
                    firstTable = json{0},
                    rows = firstTable[Rows],
                    headers = firstTable[Columns],
                    headerStrings = List.Transform(headers, (rec) => rec[ColumnName]),
                    headerTypes = List.Transform(headers, (rec) => ReadResponseDataType(rec[DataType])),
                    headersAndTypes = List.Zip({headerStrings, headerTypes}),
                    tableWithColumns = #table(headerStrings, rows),
                    tableWithTypedColumns = Table.TransformColumnTypes(tableWithColumns, headersAndTypes, "")
                in
                    tableWithTypedColumns,

            // Schema is received from the server as a table, with column headers ColumnName, OriginalTable, DataType, Ordinal
            // so each row in the table describes a column of the schema.
            // Note: when variable names here refer to column, they're referring to the column of the schema table (which
            // will become the column of the data table). Not the column of the json response table.
            ExtractSchemaFromResponse = (json) as table => 
                let
                    columnDescriptors = json[Rows],
                    columnNames = List.Transform(columnDescriptors, (rowList) => rowList{0}),
                    columnTypes = List.Transform(columnDescriptors, (rowList) => rowList{1}),
                    translatedColumnTypes = List.Transform(columnTypes, (stringType) => ReadResponseDataType(Text.From(stringType))),
                    keyValuePairs = List.Zip({columnNames, translatedColumnTypes}),
                    tableWithColumns = #table(columnNames, {}),
                    tableWithTypedColumns = Table.TransformColumnTypes(tableWithColumns, keyValuePairs, "")
                in 
                    tableWithTypedColumns,
                

            // Helper function to create table header for FQs
            ExtractTableHeaderFromResponse = (json) as list =>
                let
                    aggregatableMetrics = json[AggregatableMetrics],
                    attributes = json[Attributes],
                    
                    // For backwards compatibility, make sure FixedAttributes are not null before adding them.
                    headers = if (json[FixedAttributes] = null) then List.Combine({aggregatableMetrics, attributes})
                              else
                                let
                                    fixedAttributes = json[FixedAttributes]
                                in
                                    List.Combine({aggregatableMetrics, attributes, fixedAttributes})
                in 
                    headers,

            // Get the raw schema from the web api
            SchemaRequest = (url as text, query as record, scopeId) as record => 
                let 
                    finalQuery = GetFinalQuery(true, query),
                    opts = [Content = Serialize(finalQuery, null), Headers = GetHeaders([scopeId = scopeId], isWpa, false, currentScaleUnit)],

                    json = ExecuteRequest(url, opts)
                in
                    // delaying extraction until GetSchema()
                    json{1},

            // Checks if the DB is up, queries it and returns the result. This is done when the first query with InitialQuery parameter set to false is made.
            DataRequest = (url as text, query as record, InitialQuery as logical, cachedRawSchema, scopeId as text) =>
                let 
                    isQueryReadyUrl = if isWpa then AddQueryUrl(GetEndpoint(Endpoints[API_FQ_READY_WPA], baseUrl),Text.Combine({"reportIds",reportId},"="),"&")
                          else GetEndpoint(Endpoints[API_FQ_READY](tenantId, scopeId, jobId), baseUrl),

                    isQueryReady = if (isGEQuery) then true
                                   else ExecuteCacheRequest(CacheKeys[FQ_READY](reportId), () => WaitAndRetryRequest(isQueryReadyUrl, [Headers = GetHeaders([scopeId = scopeId], isWpa, false, currentScaleUnit)], true)),
                    finalQuery = GetFinalQuery(InitialQuery, query),
                    opts = [Content = Serialize(finalQuery, cachedRawSchema), Headers = GetHeaders([scopeId = scopeId], isWpa, false, currentScaleUnit)],
                    json =  if (isGEQuery or isQueryReady) then ExecuteRequest(url, opts)
                            else Error.Record("Query DB not ready")
                in
                    ExtractDataFromResponse(json),
        
            // Builds the query and the request body for it
            GetFinalQuery = (initialQuery as logical, query) => 
                let
                    requestedSchema = if (isGEQuery) then if (schemaType = Extension.LoadString("SchemaTypeUnpivotedValue")) then "GuidedExplorationUnpivoted"
                                                            else "GuidedExplorationPivoted"
                                      else if (schemaType = Extension.LoadString("SchemaTypeUnpivotedValue")) then "FlexibleQueryUnpivoted"
                                           else "FlexibleQueryPivoted",
                    baseQuery = [InitialQuery = initialQuery, QueryParameters = query, Source = Source.PowerBI, CultureDescriptor = Culture.Current, QuerySchemaType = requestedSchema],
                    finalQuery = if (isGEQuery) then baseQuery
                                 else baseQuery & [TargetMetadata = reportId]
                in
                    finalQuery
        in
            WPAData([query = defaultQuery, schema = null, InitialQuery = true]),                        
            
    WorkplaceAnalyticsNavigation = (datasourceInformation as record, optional jobs as record, optional schemaType as text) =>
        let
            jobsCache = if jobs <> null then jobs 
                        else FilterAndSeparateJobs(datasourceInformation),

            GetJobs = (scopeId as text, limitMyJobs as logical) => if limitMyJobs then jobsCache[MyJobs]
                                                                  else jobsCache[AllJobs],
                    
            // In order to have the dropdown where we separate the queries by category, we need to have our main navigation table have navtables
            // as elements (See https://github.com/microsoft/DataConnectors/blob/master/samples/NavigationTable/NavigationTable.pq). So we have 
            // separate functions to generate the elements, but they route their items to the same DirectQuery view. 

            // In order to reuse code, we have to assign an ID (like the reportId) to all elements of the table. This uses 1-2-3-4, assuming these cant be 
            // real job IDs

            GeneratePersonMetricsList = (scopeId as text) => {[Name = "Person Metrics", ItemKind = "Table", ReportId = "4", JobId = "4"]},
            GenerateMyIFQList = (scopeId as text) => GetJobs(scopeId, true),
            GenerateAllIFQList = (scopeId as text) => GetJobs(scopeId, false),
            
            // Generates the first level of items for the Navigation Table
            GenerateClasses = (scopeId as text) =>
                let
                    classes = {[Name =  "Standard Metrics", ItemKind = "Folder", ReportId = "1", JobId = "1"],
                               [Name = "My Custom Queries", ItemKind = "Folder", ReportId = "2", JobId = "2"],
                               [Name = "All Custom Queries", ItemKind = "Folder", ReportId = "3", JobId = "3"]}
                in
                    classes,

            // Fills the elements created by GenerateClasses
            PopulateClasses = (datasourceInformation as record, tableId as text, schemaType as text) =>
                let     
                    tableElements = if (tableId = "1") then GeneratePersonMetricsList 
                                else if (tableId = "2") then GenerateMyIFQList
                                else GenerateAllIFQList,
                    tableDataSource = WorkplaceAnalyticsDirectQueryView
                in
                    NavigationTableFromList(tableElements, tableDataSource, datasourceInformation),

            // Generic Helpers
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
                    navigationTable,

            // This came mostly from the Kusto powerbi connector 
            // For the navigation table capabilities, listFunction should generate the items of the table, and dataFunction should be the behaviour to
            // be called when the item is selected.
            NavigationTableFromList = (listFunction as function, dataFunction as function, datasourceInformation as record, optional isLeaf as logical) as table =>
                    let
                        _isLeaf = if (isLeaf = null) then true else isLeaf,
                        itemKind = if (_isLeaf) then "Table" else "Database",
                        View = (state) => Table.View(null, [
                        
                            GetType = () => 
                                let
                                    tableType = type table [ Name = text, JobId = text , ItemKind = text, Data = table, ItemName = text, IsLeaf = logical ],
                                    withKey = Type.AddTableKey(tableType, {"JobId"}, true)
                                in
                                    withKey meta
                                    [
                                        NavigationTable.NameColumn = "Name",
                                        NavigationTable.DataColumn = "Data",
                                        NavigationTable.ItemKindColumn = "ItemKind",
                                        Preview.DelayColumn = "ItemName",
                                        NavigationTable.IsLeafColumn = "IsLeaf"
                                    ],

                            GetRows = () =>                           
                                    let
                                        list = listFunction(datasourceInformation[ScopeId]),
                                        withName = Table.FromRecords(list, {"Name", "JobId", "ItemKind"}),
                                        withData = Table.AddColumn(withName, "Data", each dataFunction(datasourceInformation, [JobId], schemaType)),
                                        withItemName = Table.AddColumn(withData, "ItemName", each "Table"),
                                        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each isLeaf),
                                        navTable = Table.ToNavigationTable(withIsLeaf, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
                                    in
                                        navTable,
                            OnSelectRows = (selector) =>
                                let
                                    condition = RowExpression.From(selector),
                                    kind = condition[Kind],
                                    leftKind = condition[Left][Kind],
                                    member = condition[Left][MemberName],
                                    value = condition[Right][Value]
                                in
                                    if (kind = "Binary" and leftKind = "FieldAccess" and member = "JobId") then
                                        Table.FromRecords({[
                                            Name = value,
                                            Data = dataFunction(datasourceInformation, value, schemaType),
                                            ItemKind = "Table",
                                            ItemName = value,
                                            IsLeaf = true
                                        ]})
                                    else
                                        ...
                                    ])
                in
                    View(null),
                    
            navigationView = NavigationTableFromList(GenerateClasses, PopulateClasses, datasourceInformation, false)
        in
            navigationView,  
   
    //-------------------------------------------
    // Shared Function Parameter Handlers
    //-------------------------------------------
    
    
    /* Method for calling a generic API, with customizable options, optional responseType and optional environment (will default to prod).
    *  options: The options desired for the API call. 
    *     options.Query: Used to set the value of query parameters in the api call
    *     options.RelativePath: Used to set the value of the relative path that will be appended to the base url
    *     options.Content: Content for the request (request type will be set to POST by Web.Contents if this field is set)
    *  env: The environment to call (prod, ppe, dev, gcc, ...)
    */
    VivaInsightsGetResultsImpl = (optional options as record, optional env as text) =>
    let
        // Logic to get the complete base url
        novaUrl = Utility.GetUrlWithEnv(NovaAPIBaseUri, SetGetResultsEnvironment(env), NovaAPIBaseUri[global]),

        // Filtering elements that we allow the user to pass (based on https://learn.microsoft.com/en-us/powerquery-m/web-contents#about)
        filteredOptions = if options <> null then Record.SelectFields(options, {"Headers", "Query", "RelativePath", "Content"}, MissingField.Ignore) else [],

        // Get any headers from filtered options
        optionsHeaders = Record.FieldOrDefault(filteredOptions, "Headers", []),

        // For security reasons we restrict the headers that we allow the user to pass. In the future we might extend this list without breaking backward compatibility.
        filteredOptionHeaders = Record.SelectFields(optionsHeaders, {"scopeId", "tenantId", "x-nova-scaleunit"}, MissingField.Ignore),

        // Get the headers by calling GetHeaders with scopeId and any extra headers
        headers = GetHeaders(filteredOptionHeaders, false, true),

        // Function to combine the headers
        transformHeaders = (old_headers as record) => Record.Combine({old_headers, headers}), 

        // Update options with the headers
        updatedOptions = if Record.HasFields(options, "Headers") then Record.TransformFields(options, {{"Headers", transformHeaders}}) else Record.AddField(options, "Headers", Record.Combine({Record.FieldOrDefault(options, "Headers", []), headers})),

        // Execute the request received
        response = Web.Contents(novaUrl, updatedOptions)
    in
        Value.ReplaceMetadata(response, []),


    // Responsible for calling the correct "View" function based on the parameters provided by the user. 
    // It is necessary that ScopeId + null jobId + null jobName takes the user back to GE view, as to assure backwards compatibility with older reports.
    WorkplaceAnalyticsImpl = (dataSourcePath as text, optional jobName as text, optional jobId as text, optional schemaType as text) =>
        let
            dataSourceInformation = ParseScopeId(dataSourcePath),
            jobs = FilterAndSeparateJobs(dataSourceInformation, jobName),
            singleMyJob = if List.Count(jobs[MyJobs]) = 1 and List.Count(jobs[AllJobs]) = 0 then jobs[MyJobs]{0} else null,
            singleAllJob = if List.Count(jobs[AllJobs]) = 1 and List.Count(jobs[MyJobs]) = 0 then jobs[AllJobs]{0} else null,
            schemaType = if schemaType = null then Extension.LoadString("SchemaTypePivotedValue") else schemaType,
            finalView = if jobId = null and jobName = null then  WorkplaceAnalyticsDirectQueryView(dataSourceInformation, "4", schemaType)
            else if jobId <> null then WorkplaceAnalyticsDirectQueryView(dataSourceInformation, jobId, schemaType)
            else if singleMyJob <> null then WorkplaceAnalyticsDirectQueryView(dataSourceInformation, singleMyJob[JobId], schemaType)
            else if singleAllJob <> null then WorkplaceAnalyticsDirectQueryView(dataSourceInformation, singleAllJob[JobId], schemaType)
            else WorkplaceAnalyticsNavigation(dataSourceInformation, jobs, schemaType)
        in
            finalView,
    
    // Responsible for calling the correct "View" function based on the parameters provided by the user.
    // This function is intended to parse arguments for the "VivaInsights.Data" shared function.
    VivaInsightsImpl = (scopeId as text, optional jobName as text, optional jobId as text, optional options as record) =>
        let
            // Parse parameters.
            dataSourceInformation = ParseScopeIdAndPopulateDatasourceViva(scopeId, options[alternativeScopeId]?, options[alternativeTenantId]?, options[alternativeScaleUnit]?),
            jobs = FilterAndSeparateJobs(dataSourceInformation, jobName),
            singleMyJob = if List.Count(jobs[MyJobs]) = 1 and List.Count(jobs[AllJobs]) = 0 then jobs[MyJobs]{0} else null,
            singleAllJob = if List.Count(jobs[AllJobs]) = 1 and List.Count(jobs[MyJobs]) = 0 then jobs[AllJobs]{0} else null,
            schemaType = if options[SchemaType]? = null then Extension.LoadString("SchemaTypePivotedValue") else options[SchemaType],
            tableName = if options[TableName]? = null then null else options[TableName],
            useRowLevelApi = if options[APIType]? <> null then 
                                if options[APIType] = Extension.LoadString("ApiTypeAggregatedDataValue") then false 
                                else true 
                            else false,
            
            // In this case, if the user enters a scopeId with the format <scopeId>/<jobId>, we want to use the jobId provided by the user. Unless the jobId parameter has already been provided in the UI.
            jobId = if jobId <> null then jobId else dataSourceInformation[AdditionalJobId],

            // Select the correct "View" function depending on the provided parameters. Invalid parameter combinations should throw an error.
            finalView = 
                if useRowLevelApi and jobId = null then error Extension.LoadString("Error_RowLevelDataWithoutReport")
                else if useRowLevelApi and dataSourceInformation[isNova] = false then error Extension.LoadString("Error_WpaRowLevelData")
                else if useRowLevelApi and dataSourceInformation[isNova] then RowLevelDataView(dataSourceInformation, jobId, schemaType, tableName)
                else if jobId = null and jobName = null then WorkplaceAnalyticsDirectQueryView(dataSourceInformation, "4", schemaType)
                else if jobId <> null then WorkplaceAnalyticsDirectQueryView(dataSourceInformation, jobId, schemaType)
                else if singleMyJob <> null then WorkplaceAnalyticsDirectQueryView(dataSourceInformation, singleMyJob[JobId], schemaType)
                else if singleAllJob <> null then WorkplaceAnalyticsDirectQueryView(dataSourceInformation, singleAllJob[JobId], schemaType)
                else WorkplaceAnalyticsNavigation(dataSourceInformation, jobs, schemaType)
        in
            finalView
in
    [
        WorkplaceAnalyticsImpl = WorkplaceAnalyticsImpl,
        VivaInsightsImpl = VivaInsightsImpl,
        VivaInsightsGetResultsImpl = VivaInsightsGetResultsImpl,
        VivaInsightsGetResultsParameters = VivaInsightsGetResultsParameters,
        WorkplaceAnalyticsType = ScopeIdType,
        VivaInsightsType = VivaInsightsParameters
    ];

// Entry Point - Note that this cannot change, or older reports will stop working.
[DataSource.Kind = "VivaInsights", Publish = "VivaInsights.Publish"]
shared VivaInsights.Data = Value.ReplaceType(WPAImplementation[VivaInsightsImpl], WPAImplementation[VivaInsightsType]);

[DataSource.Kind = "VivaInsightsApi"]
shared VivaInsightsApi.GetResults = Value.ReplaceType(WPAImplementation[VivaInsightsGetResultsImpl], WPAImplementation[VivaInsightsGetResultsParameters]);

// Entry Point (for WorkplaceAnalytics.Data) - do NOT change this to preserve backwards compatibility with old Argo reports
// WorkplaceAnalytics.Data is only available when directly called in PBI. All calls from the UI Get Data screen go to VivaInsights.Data (defined above).
[DataSource.Kind = "WorkplaceAnalytics"]
shared WorkplaceAnalytics.Data =  Value.ReplaceType(WPAImplementation[WorkplaceAnalyticsImpl], WPAImplementation[WorkplaceAnalyticsType]);

GetAuthorizationUrlFromWwwAuthenticateGetResults = (baseUrl as text) as text => 
    let
        // Sending an unauthenticated request to workplace analytics service root returns
        // a 302 status with WWW-Authenticate header in the response. The value will
        // contain the correct authorization_uri. Handling 401 as well for future changes in service.
        // 
        // Example:
        // Bearer authorization_uri="https://login.microsoftonline.com/{tenant_guid}/oauth2/authorize"
        responseCodes = {302, 401},
        endpointResponse = Web.Contents(baseUrl, [
            ManualCredentials = true,
            ManualStatusHandling = responseCodes
        ])
    in
        if (List.Contains(responseCodes, Value.Metadata(endpointResponse)[Response.Status]?)) then
            let
                headers = Record.FieldOrDefault(Value.Metadata(endpointResponse), "Headers", []),

                wwwAuthenticate = Record.FieldOrDefault(headers, "WWW-Authenticate", ""),
                authorizationUri = if (wwwAuthenticate <> "") then
                let
                    split = Text.Split(Text.Trim(wwwAuthenticate), " ")
                in
                    List.First(List.Select(split, each Text.Contains(_, "authorization_uri=")), null)
                else
                    Record.FieldOrDefault(headers, "Location", null)
            in
                if (authorizationUri <> null) then
                    // Trim and replace the double quotes inserted before the url OWIN returns 
                    if (wwwAuthenticate <> "") then
                        Text.Replace(Text.Trim(Text.Trim(Text.AfterDelimiter(authorizationUri, "=")), ","), """", "")
                    else
                        let
                            authUriParts = Uri.Parts(authorizationUri)
                        in
                            "https://" & Text.Combine({authUriParts[Host], authUriParts[Path]})
                else
                    error Error.Record("Error", Extension.LoadString("Error_UnexpectedAuthenticateHeader"), [
                        #"WWW-Authenticate" = wwwAuthenticate
                    ])
        else
            error Error.Unexpected(Extension.LoadString("Error_UnexpectedAuthorizationUrlDiscovery"));


GetAuthorizationUrlFromWwwAuthenticate = (dataSource as text, isViva as logical) as text => 
    let
        // Sending an unauthenticated request to workplace analytics service root returns
        // a 302 status with WWW-Authenticate header in the response. The value will
        // contain the correct authorization_uri. Handling 401 as well for future changes in service.
        // 
        // Example:
        // Bearer authorization_uri="https://login.microsoftonline.com/{tenant_guid}/oauth2/authorize"
        url = if isViva then ParseScopeIdAndPopulateDatasourceViva(dataSource)[Url] else ParseScopeId(dataSource)[Url],

        responseCodes = {302, 401},
        endpointResponse = Web.Contents(url, [
            ManualCredentials = true,
            ManualStatusHandling = responseCodes
        ])
    in
        if (List.Contains(responseCodes, Value.Metadata(endpointResponse)[Response.Status]?)) then
            let
                headers = Record.FieldOrDefault(Value.Metadata(endpointResponse), "Headers", []),

                wwwAuthenticate = Record.FieldOrDefault(headers, "WWW-Authenticate", ""),
                authorizationUri = if (wwwAuthenticate <> "") then
                let
                    split = Text.Split(Text.Trim(wwwAuthenticate), " ")
                in
                    List.First(List.Select(split, each Text.Contains(_, "authorization_uri=")), null)
                else
                    Record.FieldOrDefault(headers, "Location", null)
            in
                if (authorizationUri <> null) then
                    // Trim and replace the double quotes inserted before the url OWIN returns 
                    if (wwwAuthenticate <> "") then
                        Text.Replace(Text.Trim(Text.Trim(Text.AfterDelimiter(authorizationUri, "=")), ","), """", "")
                    else
                        let
                            authUriParts = Uri.Parts(authorizationUri)
                        in
                            "https://" & Text.Combine({authUriParts[Host], authUriParts[Path]})
                else
                    error Error.Record("Error", Extension.LoadString("Error_UnexpectedAuthenticateHeader"), [
                        #"WWW-Authenticate" = wwwAuthenticate
                    ])
        else
            error Error.Unexpected(Extension.LoadString("Error_UnexpectedAuthorizationUrlDiscovery"));

GetResourceFromDataSourcePath = (dataSource as text, isViva as logical) as text => 
    let
        resourceUrl = if isViva then ParseScopeIdAndPopulateDatasourceViva(dataSource)[Url] else ParseScopeId(dataSource)[Url]
    in
        Text.TrimEnd(resourceUrl, "/"); 

GetResourceFromDataSourcePathGetResults = (baseUrl as text) as text =>
    let
        resourceUrl = baseUrl
    in
        Text.TrimEnd(resourceUrl, "/");

// Data Source Kind description for legacy WorkplaceAnalytics shared function.
WorkplaceAnalytics = [
    TestConnection = (dataSource) => {"WorkplaceAnalytics.Data", ExtractScopeIdFromDataSourcePath(dataSource)},
    Authentication = [
        Aad = [
            AuthorizationUri = (dataSource) => 
                let
                    parsedDataSource = ExtractScopeIdFromDataSourcePath(dataSource)
                in
                    GetAuthorizationUrlFromWwwAuthenticate(parsedDataSource, false),
            Resource = (dataSource) => 
                let
                    parsedDataSource = ExtractScopeIdFromDataSourcePath(dataSource)
                in
                    GetResourceFromDataSourcePath(parsedDataSource, false),
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source Kind description for VivaInsights shared function.
VivaInsights = [
    Type = "Custom",
    // MakeResoucePath allows us to use the alternativeScopeId parameter (that was previously not part of the datasource path).
    MakeResourcePath = (scopeId, optional options) =>
        let
            path =
                if scopeId = "VivaInsightsEmbedded" then
                    if (options <> null and options[alternativeScopeId]? <> null) then [scopeId = options[alternativeScopeId]]
                    else error Error.Record(
                        "DataSource.Error",
                        "AlternativeScopeId parameter was not provided."
                    )
                else
                    [scopeId = scopeId]
        in
            Text.FromBinary(Json.FromValue(path)),
    ParseResourcePath = (resourcePath) => {resourcePath},
    TestConnection = (dataSourcePath) => {"VivaInsights.Data", ExtractScopeIdFromDataSourcePath(dataSourcePath)},
    Authentication = [
        Aad = [
            AuthorizationUri = (dataSource) => 
                let
                    parsedDataSource = ExtractScopeIdFromDataSourcePath(dataSource)
                in
                    GetAuthorizationUrlFromWwwAuthenticate(parsedDataSource, true),
            Resource = (dataSource) => 
                // When testing PPE, hardcode the resource to be equal to "01f9d889-ee31-41cb-85fa-3ad7e0981fa1"
                let
                    parsedDataSource = ExtractScopeIdFromDataSourcePath(dataSource)
                in
                    GetResourceFromDataSourcePath(parsedDataSource, true),
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

VivaInsightsApi = [
    Type = "Custom",
    MakeResourcePath = (optional env as text) => SetGetResultsEnvironment(env),
    ParseResourcePath = (resourcePath) => {resourcePath},
    TestConnection = (dataSourcePath) => {"VivaInsightsApi.GetResults", [], dataSourcePath},
    Authentication = [  
        Aad = [
            AuthorizationUri = (dataSource) => 
                let
                    url = Utility.GetUrlWithEnv(NovaAPIBaseUri, SetGetResultsEnvironment(dataSource), NovaAPIBaseUri[global])
                in
                    GetAuthorizationUrlFromWwwAuthenticateGetResults(url),
            Resource = (dataSource) => 
                let
                    url = Utility.GetUrlWithEnv(NovaAPIBaseUri, SetGetResultsEnvironment(dataSource), NovaAPIBaseUri[global])
                in
                    GetResourceFromDataSourcePathGetResults(url),
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
VivaInsights.Publish = [
    Beta = false,
    Category = Extension.LoadString("Category"),
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    SupportsDirectQuery = true,
    SourceImage = VivaInsights.Icons,
    SourceTypeImage = VivaInsights.Icons
];

VivaInsights.Icons = [
    Icon16 = { Extension.Contents("VivaInsights_logo_16px.png"), Extension.Contents("VivaInsights_logo_20px.png"), Extension.Contents("VivaInsights_logo_24px.png"), Extension.Contents("VivaInsights_logo_32px.png") },
    Icon32 = { Extension.Contents("VivaInsights_logo_40px.png"), Extension.Contents("VivaInsights_logo_48px.png"), Extension.Contents("VivaInsights_logo_64px.png"), Extension.Contents("VivaInsights_logo_80px.png") }
];

/*
This code section is required for leveraging the Diagnostics.pqm functions for logging information to the Diagnostics.Trace.
Instructions for using Diagnostics.Trace
1 - Enable tracing in the Diagnostics tab in Power BI Desktop
2 - Make sure that your calls to Diagnostics.LogValue(...) are being evaluated, M language is lazy by default so if it's not evaluated no message will be written in the logs.
3 - After running the sideloaded version of the connector with the LogValue changes, go to Power BI Desktop settings -> Diagnostics -> There will be a hyperlink to open your traces folder, there you'll find the logged messages.
*/

Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// Diagnostics module contains multiple functions. We can take the ones we need.
Table.ChangeType = Extension.LoadFunction("Table.ChangeType.pqm");
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = 
    if DebugMode
    then Diagnostics[LogValue]
    else (prefix, value) => value;
Diagnostics.LogFailure = Diagnostics[LogFailure];
Diagnostics.WrapHandlers = Diagnostics[WrapHandlers];
Diagnostics.ValueToText = Diagnostics[ValueToText];
Diagnostics.ValueToText2 = Diagnostics[ValueToText2];
