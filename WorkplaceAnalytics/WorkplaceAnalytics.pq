//------------------------------------------------------------
// Copyright (c) Microsoft Corporation.  All rights reserved.
//------------------------------------------------------------
[Version = "1.1.0"]
section WorkplaceAnalytics;

// This is currently pointed at the PPE environment.
// to change this locally, substitute these values:
// Local: http://localhost:24301/
// PPE: https://workplaceanalytics-ppe.office.com/
// PROD: https://workplaceanalytics.office.com/
// Also - at the bottom of this file, there is a resource URI token that must be changed to match the environment as well.
// If you're trying to capture traffic with Fiddler to look at the API results, it wont work with localhost addresses unless you change them to localhost.fiddler
WPAImplementation  = let
    
    BASE_URL = "https://workplaceanalytics.office.com/",
    API_SIMPLE_QUERY = BASE_URL & "api/Dashboard/GetQueryResults",
    API_JOBS = BASE_URL & "api/Jobs/GetJobList?api-Version=1.0&sortColumn=Job.JobExecutionStatus.SubmitTime&isAsc=false&pageSize=25&reportEntityType=undefined", // This should not need all the parameters
    API_FQ_SCHEMA = BASE_URL & "api/InteractiveFlexibleQuery/GetReportSchema?api-Version=1.0",
    API_FQ_READY = BASE_URL & "api/InteractiveFlexibleQuery/IsQueryDatabaseReady?api-Version=1.0",
    API_GET_JOB = BASE_URL & "api/Jobs/GetById?api-version=1.0",

    // Increment version when changing code.
    CONNECTOR_VERSION = "1.1",

    // Value for server side enum
    Source.PowerBI = "PowerBI",

    // Helper function for deserializing
    ReadResponseDataType = (apiType as text) as type =>
        if apiType = "System.Double" then type nullable Double.Type
        else if apiType = "System.Int64" then type nullable Int64.Type
        else if apiType = "System.Int32" then type nullable Int32.Type
        else if apiType = "System.Int16" then type nullable Int16.Type
        else if apiType = "System.UInt64" then type nullable Number.Type
        else if apiType = "System.UInt32" then type nullable Number.Type
        else if apiType = "System.UInt16" then type nullable Number.Type
        else if apiType = "System.Byte" then type nullable Byte.Type
        else if apiType = "System.Single" then type nullable Single.Type
        else if apiType = "System.Decimal" then type nullable Decimal.Type
        else if apiType = "System.Data.SqlTypes.SqlDecimal" then type nullable Decimal.Type
        else if apiType = "System.TimeSpan" then type nullable Duration.Type
        else if apiType = "System.DateTime" then type nullable DateTime.Type
        else if apiType = "System.String" then type nullable Text.Type
        else if apiType = "System.Boolean" then type nullable Logical.Type
        else if apiType = "System.SByte" then type nullable Logical.Type
        else if apiType = "System.Object" then type nullable Text.Type
        else if apiType = "System.Guid" then type nullable Text.Type
        else Error.Record("Unknown Type from API"),

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

    // These are the fields the user will be prompted to fill when starting the connector
    // TODO: Check what these new fields should read
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
            Documentation.SampleValues = {Extension.LoadString("SampleJobId")}
        ])) as table meta [
            Documentation.Name = Extension.LoadString("DocumentationName"),
            Documentation.LongDescription = Extension.LoadString("LongDescription"),
            Documentation.Examples = {[
                Description = Extension.LoadString("ExampleDescription"),
                Code = Extension.LoadString("ExampleCode"),
                Result = Extension.LoadString("ExampleResult")
            ]}
         ],

    // Executes a web request, forces evaluation and returns the result or the error message
    ExecuteRequest = (url as text, options as record) =>
        let
            content = Web.Contents(url, options & [ManualStatusHandling = {400}]),
            bufferedResponse = Binary.Buffer(content),
            json = Json.Document(bufferedResponse),

            // We force evaluation of content before checking metadata values to avoid
            // the request being issued a second time.
            httpStatus = Value.Metadata(content)[Response.Status],
            errorResponse =
                if (bufferedResponse <> null and httpStatus = 400) then
                    error Error.Record(
                        "Bad request",
                        json[error][message],
                        [
                            Error = Record.Field(json[error], "@message"),
                            Code = json[error][code]
                        ]
                    )
                else
                    null
        in
            if (errorResponse <> null) then errorResponse else json,

    GetActivityId = () =>
        let 
            activityId = if (Diagnostics.ActivityId <> null) then Text.From(Diagnostics.ActivityId()) else Text.NewGuid()
        in
            activityId,

    // Returns headers used on our API calls. Can receive optional extra headers as a separate record to be combined
    GetHeaders = (extraHeaders as record) =>  Record.Combine({[#"api-Version" = "1.0", #"Content-Type" = "application/json", #"correlationId" = GetActivityId(), #"x-ms-client-version" = CONNECTOR_VERSION], extraHeaders}),
    
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
                () => #duration(0, 0, 0, 1),
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
            
    // Main view that enables DirectQuery capabilities to the chosen DB
    WorkplaceAnalyticsDirectQueryView = (scopeId as text, jobId as text) =>  
        let   
            // Using this variable to control the flow between GE and IFQ
            isGEQuery = if jobId = "4" then true else false,
           
            myJob = GetDetailsFromJobId(scopeId, jobId),
            jobName = if jobId <> "4" then myJob[Name] else "Person Metrics",
            reportId = if jobId <> "4" then myJob[ReportId] else null,
          
            url = API_SIMPLE_QUERY,

            // A default max groups to return is required, so it is not potentially set to zero by a json serialize / deserialze
            defaultQuery = [MaxGroupsToReturn = 100], 
        
            // These are the actual schema values that are returned from the APIs
            // We hold onto these in order to send to the Query API 
            rawFQSchema = if isGEQuery then null
                          else ExecuteRequest(AddQueryUrl(API_FQ_SCHEMA, Text.Combine({"jobId", jobId}, "="), "&"), [Headers = GetHeaders([scopeId = scopeId])]),
            cachedRawSchema = if isGEQuery then SchemaRequest(API_SIMPLE_QUERY, defaultQuery, scopeId)
                              else FQSchemaRequest(rawFQSchema),
                              
                          
            // Empty table with all typed columns, or what Power BI conisders a schema. This is used to type our
            // tables before we return them to Power BI
            cachedSchema = if isGEQuery then ExtractSchemaFromResponse(cachedRawSchema) 
                           else ExtractFQSchema(rawFQSchema),

            // State is a record of [query = [], schema = #table()]
            WPAData = (state as record) => if (state[query] <> null) then Table.View(null, [
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
                                        Value = WorkplaceAnalytics.Data
                                    ],
                                    Arguments =
                                    {
                                        [
                                            Kind = "Constant",
                                            Value = scopeId
                                        ],
                                        [
                                            Kind = "Constant",
                                            Value = jobId
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
                                 requestResults = DataRequest(url, state[query], state[InitialQuery], cachedRawSchema, scopeId),
                                 schemaTable = GetSchema(),
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

                        OnSelectRows = (selector) => 
                            let
                                boolean = Record.HasFields(state[query], "Aggregates"),
                                params = if boolean then state[query] & [OuterFilter = selector]
                                         else state[query] & [InnerFilter = selector]
                            in 
                                @WPAData(state & [query = params, InitialQuery = false]),

                        OnSelectColumns = (columns) => 
                            let 
                                schema = GetSchema(),
                                existingColumns = Table.ColumnNames(schema),
                                columnsToRemove = List.Difference(existingColumns, columns),
                                newSchema = Table.RemoveColumns(schema, columnsToRemove), 
                            
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

                        OnAddColumns = (constructors) =>
                            let
                                oldSchema = GetSchema(),
                                newSchema = List.Accumulate(constructors, oldSchema, (t, c) => Table.AddColumn(t, c[Name], each null, c[Type])),

                                params = state[query] & [OnAddColumns = ProcessCreatedColumnDefinitions(constructors, cachedRawSchema)]
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
                    ]) else error Error.Record("DataSource.Error", "Invalid view state", state),

            // Requests details for a jobId from API_GET_JOB and processes the resulting JSON
            GetDetailsFromJobId = (scopeId as text, jobId as text) =>
                let
                    myJob = ExecuteRequest(AddQueryUrl(API_GET_JOB, Text.Combine({"jobId", jobId}, "="), "&"), [Headers = GetHeaders([scopeId = scopeId])])
                in
                    myJob[JobDefinition],

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
                    tableWithTypedColumns = Table.TransformColumnTypes(tableWithColumns, headersAndTypes) 
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
                    tableWithTypedColumns = Table.TransformColumnTypes(tableWithColumns, keyValuePairs)
                in 
                    tableWithTypedColumns,
                
            // Generates an IFQs schema in the same shape as ExtractSchemaFromResponse
            ExtractFQSchema = (json) as table =>
                let
                    aggregatableMetrics = json[AggregatableMetrics],
                    attributes = json[Attributes],
                    headers = List.Combine({aggregatableMetrics, attributes}), 
                    headersName = List.Transform(headers, each [Name]),
                    headersType = List.Transform(headers, each ReadResponseDataType([Type])),
                    headersAndTypes = List.Zip({headersName, headersType}),
                    tableWithColumns = #table(headersName, {}),
                    tableWithTypedColumns = Table.TransformColumnTypes(tableWithColumns, headersAndTypes)
                in  
                    tableWithTypedColumns,

            // Get the raw schema from the web api
            SchemaRequest = (url as text, query as record, scopeId) as record => 
                let 
                    finalQuery = GetFinalQuery(true, query),
                    opts = [Content = Serialize(finalQuery, null), Headers = GetHeaders([scopeId = scopeId])],

                    json = ExecuteRequest(url, opts)
                in
                    // delaying extraction until GetSchema()
                    json{1},
            
            // Special Schema request for the IFQ case (Since the responses are different for GE and IFQ case)
            FQSchemaRequest = (json as record) as record =>
                let                    
                    aggregatableMetrics = json[AggregatableMetrics],
                    attributes = json[Attributes],
                    headers = List.Combine({aggregatableMetrics, attributes}), 
                    renamedHeaders = List.Transform(headers, (_) => [ColumnName = _[Name], DataType = _[Type], OriginalTable = "FlexibleQuery"])
                in 
                    [Columns = renamedHeaders, Rows = {}],

            // Checks if the DB is up, queries it and returns the result
            DataRequest = (url as text, query as record, InitialQuery as logical, cachedRawSchema, scopeId as text) =>
                let 
                    isQueryReady = if (isGEQuery) then true
                                   else WaitAndRetryRequest(AddQueryUrl(API_FQ_READY,Text.Combine({"jobId",jobId},"="),"&"), [Headers = GetHeaders([scopeId = scopeId])], true),
                    finalQuery = GetFinalQuery(InitialQuery, query),
                    opts = [Content = Serialize(finalQuery, cachedRawSchema), Headers = GetHeaders([scopeId = scopeId])],
                    json =  if (isGEQuery or isQueryReady) then ExecuteRequest(url, opts) 
                            else Error.Record("Query DB not ready")
                in
                    ExtractDataFromResponse(json),
        
            // Builds the query and the request body for it
            GetFinalQuery = (initialQuery as logical, query) => 
                let
                    baseQuery = [InitialQuery = initialQuery, QueryParameters = query, Source = Source.PowerBI, CultureDescriptor = Culture.Current],
                    finalQuery = if (isGEQuery) then baseQuery
                                 else baseQuery & [TargetMetadata = reportId]
                in
                    finalQuery
        in
            WPAData([query = defaultQuery, schema = null, InitialQuery = true]),                        
                
    // Calls GetJobList twice, separates the response into two sets of MyJobs and AllJobs. Optionally, filter for a search string by job name. 
    // If no jobs are found with the desired name, return all jobs.
    FilterAndSeparateJobs = (scopeId, optional jobName as text) =>
        let
            baseQueryMyJobs = AddQueryUrl(API_JOBS, "limitToMyJobs=true", "&"),
            baseQueryAllJobs = AddQueryUrl(API_JOBS, "limitToMyJobs=false", "&"),
            searchName = Text.Combine({"searchString", jobName}, "="),
            queryMyJobs = if jobName = null then baseQueryMyJobs 
                          else AddQueryUrl(baseQueryMyJobs, searchName, "&"),
            queryAllJobs = if jobName = null then baseQueryAllJobs 
                           else AddQueryUrl(baseQueryAllJobs, searchName, "&"),
            myJobs = ExecuteRequest(queryMyJobs, [Headers = GetHeaders([scopeId = scopeId]), Content = Text.ToBinary("null")]),
            allJobs = ExecuteRequest(queryAllJobs, [Headers = GetHeaders([scopeId = scopeId]), Content = Text.ToBinary("null")]),
            myJobsRecord = if Value.Type(myJobs[Response]) = Record.Type then myJobs[Response]
                           else null,
            allJobsRecord = if Value.Type(allJobs[Response]) = Record.Type then allJobs[Response] 
                            else null,
            myJobsList = if myJobsRecord <> null then {myJobsRecord} 
                         else ExtractListFromJobsJSON(myJobs),
            allJobsList = if allJobsRecord <> null then {allJobsRecord} 
                          else ExtractListFromJobsJSON(allJobs),
            intersectionJobsList = List.RemoveMatchingItems(allJobsList, myJobsList),
            jobsResult = if List.Count(myJobsList) = 0 and List.Count(allJobsList) = 0 then @FilterAndSeparateJobs(scopeId) 
                         else [MyJobs = myJobsList, AllJobs = intersectionJobsList]
        in
           jobsResult,
            
    WorkplaceAnalyticsNavigation = (scopeId as text, optional jobs as record) =>
        let       
           
            jobsCache = if jobs <> null then jobs 
                        else FilterAndSeparateJobs(scopeId),

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
            PopulateClasses = (scopeId as text, tableId as text) =>
                let     
                    tableElements = if (tableId = "1") then GeneratePersonMetricsList 
                                else if (tableId = "2") then GenerateMyIFQList
                                else GenerateAllIFQList,
                    tableDataSource = WorkplaceAnalyticsDirectQueryView
                in
                    NavigationTableFromList(tableElements, tableDataSource, scopeId),

            // This came mostly from the Kusto powerbi connector 
            // For the navigation table capabilities, listFunction should generate the items of the table, and dataFunction should be the behaviour to
            // be called when the item is selected.
            NavigationTableFromList = (listFunction as function, dataFunction as function, scopeId as text, optional isLeaf as logical) as table =>
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
                                        list = listFunction(scopeId),
                                        withName = Table.FromRecords(list, {"Name", "JobId", "ItemKind"}),
                                        withData = Table.AddColumn(withName, "Data", each dataFunction(scopeId, [JobId])),
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
                                            Data = dataFunction(scopeId, value),
                                            ItemKind = "Table",
                                            ItemName = value,
                                            IsLeaf = true
                                        ]})
                                    else
                                        ...
                                    ])
                in
                    View(null),
                    
            navigationView = NavigationTableFromList(GenerateClasses, PopulateClasses, scopeId, false)
        in
            navigationView,  
    
    // Decides where to take the user based on what he inputs. 
    // Its necessary that ScopeId + null jobId + null jobName takes the user back to GE view, as to assure backwards compatibility with older reports.
    WorkplaceAnalyticsImpl = (scopeId as text, optional jobName as text, optional jobId as text) =>
        let
            jobs = FilterAndSeparateJobs(scopeId, jobName),
            singleMyJob = if List.Count(jobs[MyJobs]) = 1 and List.Count(jobs[AllJobs]) = 0 then jobs[MyJobs]{0} else null,
            singleAllJob = if List.Count(jobs[AllJobs]) = 1 and List.Count(jobs[MyJobs]) = 0 then jobs[AllJobs]{0} else null,
            finalView = if jobId = null and jobName = null then  WorkplaceAnalyticsDirectQueryView(scopeId, "4")
            else if jobId <> null then WorkplaceAnalyticsDirectQueryView(scopeId, jobId)
            else if singleMyJob <> null then WorkplaceAnalyticsDirectQueryView(scopeId, singleMyJob[JobId])
            else if singleAllJob <> null then WorkplaceAnalyticsDirectQueryView(scopeId, singleAllJob[JobId])
            else WorkplaceAnalyticsNavigation(scopeId, jobs)
        in
            finalView,
  
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
            navigationTable
in
    [
        WorkplaceAnalyticsImpl = WorkplaceAnalyticsImpl,
        WorkplaceAnalyticsType = ScopeIdType
    ];

// Entry Point - Note that this cannot change, or older reports will stop working 
[DataSource.Kind = "WorkplaceAnalytics", Publish = "WorkplaceAnalytics.Publish"]
shared WorkplaceAnalytics.Data =  Value.ReplaceType(WPAImplementation[WorkplaceAnalyticsImpl], WPAImplementation[WorkplaceAnalyticsType]);

// Data Source Kind description
WorkplaceAnalytics = [
    TestConnection = (scopeId) => 
        let
            json = Json.Document(scopeId),
            scopeGuid = json[scopeId]
        in
            {"WorkplaceAnalytics.Data" , scopeGuid},    
    Authentication = [
        Aad = [
            AuthorizationUri = "https://login.windows.net/common/oauth2/authorize",
            Resource = "https://workplaceanalytics.office.com",
            DefaultClientApplication = [
                ClientId = "a672d62c-fc7b-4e81-a576-e60dc46e951d",
                ClientSecret = "",
                CallbackUrl = "https://preview.powerbi.com/views/oauthredirect.html"
            ],
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
WorkplaceAnalytics.Publish = [
    Beta = true,
    Category = Extension.LoadString("Category"),
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = Extension.LoadString("LearnMoreUrl"),
    SupportsDirectQuery = true,
    SourceImage = WorkplaceAnalytics.Icons,
    SourceTypeImage = WorkplaceAnalytics.Icons
];

WorkplaceAnalytics.Icons = [
    Icon16 = { Extension.Contents("WorkplaceAnalytics16.png"), Extension.Contents("WorkplaceAnalytics20.png"), Extension.Contents("WorkplaceAnalytics24.png"), Extension.Contents("WorkplaceAnalytics32.png") },
    Icon32 = { Extension.Contents("WorkplaceAnalytics40.png"), Extension.Contents("WorkplaceAnalytics48.png"), Extension.Contents("WorkplaceAnalytics64.png"), Extension.Contents("WorkplaceAnalytics80.png") }
];