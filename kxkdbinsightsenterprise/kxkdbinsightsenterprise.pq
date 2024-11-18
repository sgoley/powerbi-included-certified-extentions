[Version = "1.0.0"]
section kxkdbinsightsenterprise;

// -----------------------------------------------------
// | kxkdbinsightsenterprise.Contents() Navigation Table
// -----------------------------------------------------
//  |- Assemly1
//      |- Trade(startTS as datetime, endTS as datetime, filter as text, agg as text, groupBy as text)
//      |- Close(startTS as datetime, endTS as datetime, filter as text, agg as text, groupBy as text)
//  |- Assemly2
//      |- Deal(startTS as datetime, endTS as datetime, filter as text,agg as text, groupBy as text)
//      |- Invest(startTS as datetime, endTS as datetime, filter as text,agg as text, groupBy as text)
//
// -----------------------------------------------------
MAX_RETRIES = 4;
HANDLE_MANUALLY_CODES = {500, 502};
REQUIRED_DATE_TIME_FORMAT = "yyyy-MM-ddTHH:mm:ss.ffffff";

// Endpoints
SERVICE_GATEWAY_ROUTE = "/servicegateway/kxi/";
GET_DATA_ENDPOINT = "getData";
GET_META_ENDPOINT = "getMeta";

// When set to true, additional trace information will be written out to the User log.
// This should be set to false before release to prod/submission. Tracing is done through a call to
// Diagnostics.LogValue() & Diagnostics.LogError(). When EnableTraceOutput is set to false, the call becomes a
// no-op and simply returns the original value.
ENABLE_TRACING = false;


// -----------------------------------------------------
// Main data source connection
// -----------------------------------------------------
[DataSource.Kind = "kxkdbinsightsenterprise", Publish = "kxkdbinsightsenterprise.Publish"]
shared kxkdbinsightsenterprise.Contents = Value.ReplaceType(GetRootNavTable, kxkdbinsightsenterpriseType);

// -----------------------------------------------------
// Types
// -----------------------------------------------------

kxkdbinsightsenterpriseType =
    let
        HostUrlType = Uri.Type meta [
            Documentation.FieldCaption = Extension.LoadString("UserInput_URLCaption"),
            Documentation.FieldDescription = Extension.LoadString("UserInput_URLDesc"),
            Documentation.SampleValues = {"https://kxi.crhkgebrdygac3f5.swedencentral.sysgen.cloudapp.azure.com"}
        ]
    in
        type function (HostUrl as HostUrlType) as table meta [
            Documentation.Name = Extension.LoadString("kxkdbinsightsenterprise_Name"),
            Documentation.Caption = null,
            Documentation.Description = Extension.LoadString("kxkdbinsightsenterprise_Desc"),
            Documentation.LongDescription = Extension.LoadString("kxkdbinsightsenterprise_Desc")
        ];

kxkdbinsightsenterprise.View.Type = type function (
    optional startTS as (
        type datetime meta [
            DataSource.Path = false,
            Documentation.FieldCaption = Extension.LoadString("param_startTS_caption"),
            Documentation.FieldDescription = Extension.LoadString("param_startTS_desc"),
            Documentation.SampleValues = {Extension.LoadString("param_startTS_example")}
        ]
    ),
    optional endTS as (
        type datetime meta [
            DataSource.Path = false,
            Documentation.FieldCaption = Extension.LoadString("param_endTS_caption"),
            Documentation.FieldDescription = Extension.LoadString("param_endTS_desc"),
            Documentation.SampleValues = {Extension.LoadString("param_endTS_example")}
        ]
    ),
    optional filter as (
        type text meta [
            DataSource.Path = false,
            Formatting.IsMultiLine = true,
            Documentation.FieldCaption = Extension.LoadString("param_filter_caption"),
            Documentation.FieldDescription = Extension.LoadString("param_filter_desc"),
            Documentation.SampleValues = {Extension.LoadString("param_filter_example")}
        ]
    ),
    optional agg as (
        type text meta [
            DataSource.Path = false,
            Formatting.IsMultiLine = true,
            Documentation.FieldCaption = Extension.LoadString("param_agg_caption"),
            Documentation.FieldDescription = Extension.LoadString("param_agg_desc"),
            Documentation.SampleValues = {Extension.LoadString("param_agg_example")}
        ]
    ),
    optional groupBy as (
        type text meta [
            DataSource.Path = false,
            Formatting.IsMultiLine = true,
            Documentation.FieldCaption = Extension.LoadString("param_groupBy_caption"),
            Documentation.FieldDescription = Extension.LoadString("param_groupBy_desc"),
            Documentation.SampleValues = {Extension.LoadString("param_groupBy_example")}
        ]
    )
) as table meta [
    Documentation.Name = Extension.LoadString("function_getData_name")
];

// -----------------------------------------------------
// Navigation functions
// -----------------------------------------------------
GetRootNavTable = (resourceUrl as text) as table =>
    let
        objects = GetAssembliesNavTable(resourceUrl),
        navTable = CommonHelpers.ToNavigationTable(
            objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf"
        )
    in
        navTable;

GetAssembliesNavTable = (resourceUrl as text) as table =>
    let
        response = Web.Contents.KX(resourceUrl, GET_META_ENDPOINT),
        payload = response[payload],
        assembly = payload[assembly],
        schema = payload[schema],
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            List.Transform(
                assembly,
                each
                    {
                        _[assembly],
                        _[kxname],
                        GetDatabaseTable(resourceUrl, _[tbls], schema),
                        "Database",
                        "Database",
                        false
                    }
            )
        )
    in
        objects;

GetDatabaseTable = (baseURL as text, tables as list, schema as list) as table =>
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            List.Transform(
                tables,
                each
                    {
                        _,
                        _,
                        Value.ReplaceType(
                            (
                                optional startTS as datetime,
                                optional endTS as datetime,
                                optional filter as text,
                                optional agg as text,
                                optional groupBy as text
                            ) =>
                                kxkdbinsightsenterprise.View(
                                    baseURL,
                                    _,
                                    schema,
                                    [
                                        startTS = startTS,
                                        endTS = endTS,
                                        filter = filter,
                                        agg = agg,
                                        groupBy = groupBy
                                    ]
                                    ),
                            kxkdbinsightsenterprise.View.Type
                        ),
                        "Table",
                        "Table",
                        true
                    }
            )
        ),
        navTable = CommonHelpers.ForceToNavigationTable(
            objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf"
        )
    in
        navTable;


// -----------------------------------------------------
// Table.View
// -----------------------------------------------------
kxkdbinsightsenterprise.View = (baseUrl as text, entity as text, schema, options as record ) as table =>
    let
        // Every time these parameters above change, the view function is called.
        View = (state as record) => Table.View(null, Diagnostics.WrapHandlers([
                GetType = () => Value.Type(GetRows(true)),
                // isUsedForGetType is a flag to indicate if this call is being used for GetType() or not.
                // isUsedForGetType is always set to true for GetType to try to optimise for plain preview performance.
                // If a user passes options, this flag is ignored.
                GetRows = (optional isUsedForGetType as nullable logical) =>
                    let

                        // Validate the options passed in from the UI if they exist.
                        validatedOptions = ValidateOptions(options),

                        // Resolve the limit (if needed).
                        limit = // 1. Check if state[Top] exists and if so, use that as the limit
                                if Record.HasFields(state, "Top") then Text.From(state[Top]) else
                                // 2. If state[Top] doesnt exist, check if this is being called for GetType() if so, assign "1"
                                if isUsedForGetType <> null then "1" else
                                // 4. Otherwise assign null
                                null,

                        // Call the API
                        data = Web.Contents.KX(
                            baseUrl, GET_DATA_ENDPOINT, BuildPayload(entity, validatedOptions, limit)
                        ),

                        // Get the payload and rows.
                        payload = data[payload],
                        rows = Table.FromRecords(payload),

                        // Create the schema table
                        schemaTable = CreateSchema(entity, schema, validatedOptions),

                        // Enforce types using schema on the rows.
                        convertedRows = CommonHelpers.SchemaTransformTable(rows, schemaTable, 3)
                    in
                        convertedRows,
                OnTake = (count as number) => let newState = state & [Top = count] in @View(newState)
            ]
            ))
    in
        View([Url = baseUrl, Entity = entity, options = options]);



// -----------------------------------------------------
// API functions
// -----------------------------------------------------
CreateSchema = (tableName as text, schema as list, validatedOptions as record) as table =>
    let
        tableSchema = List.First(List.Select(schema, each _[table] = tableName)),
        columns = tableSchema[columns],

        // Handle new columns created using aggreate functions.
        aggOptions = Json.Document(validatedOptions[agg]),
        aggParam = try List.Count(aggOptions{0}) otherwise 0,

        // Build schema table.
        schemaTable =
            if (validatedOptions[agg]? <> null and aggParam = 3) then
                #table(
                    {"Name", "Type"},
                    List.Transform(
                        aggOptions,
                        each
                            let
                                newColumnName = _{0},
                                oldColumnName = _{2},
                                // Get the type of the column from the known datatypes.
                                columnType = CommonHelpers.DataTypes{
                                    Number.Abs(List.First(List.Select(columns, each _[column] = oldColumnName))[typ]) - 1
                                }
                            in
                                {newColumnName, columnType}
                    )
                )
            else
                #table(
                    {"Name", "Type"},
                    List.Transform(columns, each {_[column], CommonHelpers.DataTypes{Number.Abs(_[typ]) - 1}})
                )
    in
        schemaTable;

Web.Contents.KX = (baseURL as text, apiEndpoint as text, optional body as binary) as record =>
    let
        result = Web.Contents.KX.Base(baseURL, apiEndpoint, body),

        // Get status code
        responseMetadata = Value.Metadata(result),
        responseCode = responseMetadata[Response.Status],

        // Convert result to JSON.
        resultAsJson = Json.Document(Text.FromBinary(result)),

        // Try to resolve the ac code in expected header - if we dont have one just set to 0.
        apiACCode = resultAsJson[header]?[ac]? ?? 0,

        // Construct response.
        response =
            if responseCode <> 200 then
                if (responseCode = 400) then
                    // If its a 400 with 10 this is valid for a retry
                    if (apiACCode = 10) then
                        Web.Contents.KX.CustomRetry(baseURL, apiEndpoint, MAX_RETRIES, body)
                    else
                        Web.ErrorResponse(resultAsJson, responseCode)
                else if (List.Contains(HANDLE_MANUALLY_CODES, responseCode)) then
                    Web.Contents.KX.CustomRetry(baseURL, apiEndpoint, MAX_RETRIES, body)
                else
                    Web.ErrorResponse(resultAsJson, responseCode)
            else
                resultAsJson
    in
        response;

Web.ErrorResponse = (result, statusCode as number) =>
    let
        // Try to resolve the raw header & ai code, if not - set to pre-defined default text
        messageReason = result[header]?[ai]? ?? Extension.LoadString("error_servererror"),
        detail = result[header]? ?? Extension.LoadString("error_nodetails"),
        errorResponse = error
            [
                Reason = Extension.LoadString("error_reason_status") & Number.ToText(statusCode),
                Message = Text.Format(Extension.LoadString("error_message_status"), {messageReason}),
                Detail = detail
            ]
    in
        errorResponse;

Web.Contents.KX.CustomRetry = (baseURL as text, apiEndpoint as text, count as number, optional body as binary) as record =>
    let
        waitForResult = CommonHelpers.Value.WaitFor(
            (iteration) =>
                let
                    rawResponse = Web.Contents.KX.Base(baseURL, apiEndpoint, body, true),
                    responseStatus = Value.Metadata(rawResponse)[Response.Status],
                    evaluatedStatus = if (rawResponse = null or responseStatus <> 200) then responseStatus else 200,
                    returnRecord = [response = rawResponse, status = evaluatedStatus]
                in
                    returnRecord,
            (iteration) => #duration(0, 0, 0, iteration * 0.25),
            count
        )
    in
        let
            jsonResp = Json.Document(Text.FromBinary(waitForResult)),
            finalResp =
            // If the result is still not 200, then we need to return an error
            if (Value.Metadata(jsonResp)[Response.Status] <> 200) then
                Web.ErrorResponse(jsonResp, Value.Metadata(jsonResp)[Response.Status])
            else
                jsonResp
        in
            finalResp;

Web.Contents.KX.Base = (baseURL as text, apiEndpoint as text, optional body as binary, optional isRetry as logical) as binary =>
    let
        result = Web.Contents(
            baseURL,
            [
                RelativePath = SERVICE_GATEWAY_ROUTE & apiEndpoint,
                Headers = CommonHelpers.JsonHeaders,
                Content = body,
                ManualStatusHandling = HANDLE_MANUALLY_CODES,
                IsRetry = isRetry ?? false
            ]
        )
    in
        result;

// -----------------------------------------------------
// Format/Utility functions
// -----------------------------------------------------

FormatTextForJson = (fieldName as text, value as text, isStart as logical) =>
    if (isStart) then
        "{""" & fieldName & """: """ & value & """"
    else
        ", """ & fieldName & """: """ & value & """";

FormatObjectForJson = (fieldName as text, value as any) => ", """ & fieldName & """:" & value;
ValidateOptions = (options as record) as record =>
    let
        validationTSOptionsResult = validateTSOptions(options[startTS]?, options[endTS]?),
        agg =
            if options[agg]? = null then
                null
            else if Value.Is(options[agg], Text.Type) then
                if not isValidJsonStructure(options[agg]) then
                        error
                        [
                            Reason = Extension.LoadString("error_userinput_reason"),
                            Message = Extension.LoadString("error_userinput_message"),
                            Detail = Extension.LoadString("error_userinput_detail") & Text.From(options[agg])
                        ]                
                 else if not validationTSOptionsResult[isSet] then
                        error  
                        [
                            Reason = Extension.LoadString("error_missingrequiredparams"),
                            Message = Extension.LoadString("error_provideTS"),
                            Detail = validationTSOptionsResult[missingParamsError] 
                        ]
                else
                    options[agg]
            else
                error Error.Record(Extension.LoadString("error_param_agg")),
        filter =
            if options[filter]? = null then
                null
            else if Value.Is(options[filter], Text.Type) then
                if not (isValidJsonStructure(options[filter])) then
                     error  
                        [
                            Reason = Extension.LoadString("error_userinput_reason"),
                            Message = Extension.LoadString("error_userinput_message"),
                            Detail = Extension.LoadString("error_userinput_detail") & Text.From(options[filter])
                        ]
                 else if not validationTSOptionsResult[isSet] then
                        error  
                        [
                            Reason = Extension.LoadString("error_missingrequiredparams"),
                            Message = Extension.LoadString("error_provideTS"),
                            Detail = validationTSOptionsResult[missingParamsError] 
                        ]
                else
                    options[filter]
            else
                error Error.Record(Extension.LoadString("error_param_filter")),
        groupBy =
            if options[groupBy]? = null then
                null
            else if Value.Is(options[groupBy], Text.Type) then
                if (options[agg]? = null) then
                error
                    [
                        Reason = Extension.LoadString("error_userinput_reason"),
                        Message = Extension.LoadString("error_aggWithGroupby"),
                        Detail = null
                    ]
                 else if not validationTSOptionsResult[isSet] then
                        error  
                        [
                            Reason = Extension.LoadString("error_missingrequiredparams"),
                            Message = Extension.LoadString("error_provideTS"),
                            Detail = validationTSOptionsResult[missingParamsError] 
                        ]
                else if (not isValidJsonStructure(options[groupBy])) then
                    error
                        [
                            Reason = Extension.LoadString("error_userinput_reason"),
                            Message = Extension.LoadString("error_userinput_message"),
                            Detail = Extension.LoadString("error_userinput_detail") & Text.From(options[groupBy])
                        ]
                else
                    options[groupBy]
            else
                error Error.Record(Extension.LoadString("error_param_groupBy")),
        startTS =
            if options[startTS]? = null then
                null
            else if options[endTS]? = null then
                        error  
                        [
                            Reason = Extension.LoadString("error_missingrequiredparams"),
                            Message = Extension.LoadString("error_provideTS"),
                            Detail = validationTSOptionsResult[missingParamsError] 
                        ]
            else if Value.Is(options[startTS]?, DateTime.Type) then
                DateTime.ToText(options[startTS], [Format = REQUIRED_DATE_TIME_FORMAT])
            else if Value.Is(options[startTS], Date.Type) then
                let
                    toZone = DateTime.AddZone(
                        DateTime.From(options[startTS]), DateTimeZone.ZoneHours(DateTimeZone.LocalNow())
                    )
                in
                    DateTime.ToText(toZone, [Format = REQUIRED_DATE_TIME_FORMAT])
            else
                error Error.Record(Extension.LoadString("error_param_startTS")),
        endTS =
            if options[endTS]? = null then
                null
            else if options[startTS]? = null then
                        error  
                        [
                            Reason = Extension.LoadString("error_missingrequiredparams"),
                            Message = Extension.LoadString("error_provideTS"),
                            Detail = validationTSOptionsResult[missingParamsError] 
                        ]
            else if Value.Is(options[endTS]?, DateTime.Type) then
                DateTime.ToText(options[endTS], [Format = REQUIRED_DATE_TIME_FORMAT])
            else if Value.Is(options[endTS], Date.Type) then
                let
                    toZone = DateTime.AddZone(
                        DateTime.From(options[startTS]), DateTimeZone.ZoneHours(DateTimeZone.LocalNow())
                    )
                in
                    DateTime.ToText(toZone, [Format = REQUIRED_DATE_TIME_FORMAT])
            else
            error Error.Record(Extension.LoadString("error_param_endTS")),
        hasOptionsSet = if(startTS <> null or endTS <> null or filter <> null or agg <> null or groupBy <> null) then true else false
    in
        [startTS = startTS, endTS = endTS, filter = filter, agg = agg, groupBy = groupBy, hasOptionsSet = hasOptionsSet];

isValidJsonStructure = (input) =>
    let
        firstChar = Text.Start(input, 1),
        lastChar = Text.End(input, 1),
        numOpeningBrackets = Text.Length(Text.Replace(input, "[", "")) - Text.Length(input),
        numClosingBrackets = Text.Length(Text.Replace(input, "]", "")) - Text.Length(input),
        isValid = (numOpeningBrackets = numClosingBrackets)
    in
        isValid;

validateTSOptions = (startTS as nullable datetime, endTS as nullable datetime) =>
    let
        missingParamsList = List.RemoveNulls({if (startTS = null) then "startTS" else null, if (endTS = null) then "endTS" else null}),
        res = [
            isSet = if (startTS <> null and endTS <> null) then true else false,
            missingParamsError = Extension.LoadString("error_missingparams") & Text.Combine(missingParamsList, ", ")
        ]
    in res;

BuildPayload = (tableName as text, options as record, limit as nullable text) =>
    let
        // Check for limit, if its there append it.
        limit = if limit = null then "" else FormatObjectForJson("limit", limit),

        // Check for options, if they are there append them.
        agg = if options[agg]? = null then "" else FormatObjectForJson("agg", options[agg]),
        filter = if options[filter]? = null then "" else FormatObjectForJson("filter", options[filter]),
        groupBy = if options[groupBy]? = null then "" else FormatObjectForJson("groupBy", options[groupBy]),
        startTS = if options[startTS]? = null then "" else FormatTextForJson("startTS", options[startTS]?, false),
        endTS = if options[endTS]? = null then "" else FormatTextForJson("endTS", options[endTS]?, false),
        
        // Construct the final body.
        body = Text.ToBinary(FormatTextForJson("table", tableName, true) & startTS & endTS & filter & agg & groupBy & limit & "}")
    in
        body;

// -----------------------------------------------------
// Data Source UI publishing description
// -----------------------------------------------------
kxkdbinsightsenterprise.Publish = [
    Beta = true,
    Category = "Database",
    ButtonText = {
        Extension.LoadString("kxkdbinsightsenterprise_Name"),
        Extension.LoadString("kxkdbinsightsenterprise_Help")
    },
    LearnMoreUrl = "https://code.kx.com/insights/1.6/enterprise/azure-marketplace/azure-powerBi.html",
    SourceImage = kxkdbinsightsenterprise.Icons,
    SupportsDirectQuery = false,
    SourceTypeImage = kxkdbinsightsenterprise.Icons
];

kxkdbinsightsenterprise.Icons = [
    Icon16 = {
        Extension.Contents("kx-16.png"),
        Extension.Contents("kx-20.png"),
        Extension.Contents("kx-24.png"),
        Extension.Contents("kx-32.png")
    },
    Icon32 = {
        Extension.Contents("kx-32.png"),
        Extension.Contents("kx-40.png"),
        Extension.Contents("kx-48.png"),
        Extension.Contents("kx-64.png")
    }
];

// -----------------------------------------------------
// Authentication
// -----------------------------------------------------
kxkdbinsightsenterprise =
    [
        TestConnection = (dataSourcePath) => {"kxkdbinsightsenterprise.Contents", dataSourcePath},
        Authentication = [
            OAuth = [
                StartLogin = AuthHelpers.StartLogin,
                FinishLogin = AuthHelpers.FinishLogin,
                Refresh = AuthHelpers.Refresh,
                Logout = AuthHelpers.Logout
            ]
        ],
        Label = Extension.LoadString("kxkdbinsightsenterprise_Name")
    ];

// -----------------------------------------------------
// Load common library functions
// -----------------------------------------------------
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name), asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
AuthHelpers = Extension.LoadFunction("AuthHelpers.pqm");
CommonHelpers = Extension.LoadFunction("CommonHelpers.pqm");

Diagnostics.LogValue = if (ENABLE_TRACING) then Diagnostics[LogValue] else (prefix, value) => value;
Diagnostics.LogFailure = if (ENABLE_TRACING) then Diagnostics[LogError] else (prefix, value) => value;
Diagnostics.WrapHandlers = if (ENABLE_TRACING) then Diagnostics[WrapHandlers] else (handlers) => handlers;

AuthHelpers.StartLogin = AuthHelpers[StartLogin];
AuthHelpers.FinishLogin = AuthHelpers[FinishLogin];
AuthHelpers.Refresh = AuthHelpers[Refresh];
AuthHelpers.Logout = AuthHelpers[Logout];

CommonHelpers.DataTypes = CommonHelpers[DataTypes];
CommonHelpers.ForceToNavigationTable = CommonHelpers[ForceToNavigationTable];
CommonHelpers.ToNavigationTable = CommonHelpers[ToNavigationTable];
CommonHelpers.JsonHeaders = CommonHelpers[JsonHeaders];
CommonHelpers.Schema.ToTableType = CommonHelpers[Schema.ToTableType];
CommonHelpers.Value.WaitFor = CommonHelpers[Value.WaitFor];
CommonHelpers.SchemaTransformTable = CommonHelpers[SchemaTransformTable];
