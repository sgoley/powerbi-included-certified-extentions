[ Version = "1.0.28" ]
section Warehouse;

AadSqlResource = "https://database.windows.net/";

UseSqlEndPointInTestConnection = Value.ConvertToLogical(Environment.FeatureSwitch("MashupFlight_UseSqlEndPointInWHTestConnection", true));
UseNewClusterAPI = Value.ConvertToLogical(Environment.FeatureSwitch("MashupFlight_UseNewClusterAPI", false));

PBICommonHeaderNames = {
    "x-ms-client-request-id",
    "x-ms-client-session-id",
    "RequestId",
    "ActivityId"
};

NonPii = (x) => x meta [Is.Pii = false];
IsNonPii = (x) => Value.Metadata(x)[Is.Pii]? = false;

Warehouse = [
    Type = "Custom",
    MakeResourcePath =  (optional options) => "Warehouse",
    ParseResourcePath = (options) => { },
    Authentication = [
          Aad = [
                   AuthorizationUri = Uri.Combine(Environment.FeatureSwitch("AzureActiveDirectoryUri", "https://login.microsoftonline.com"), "common/oauth2/authorize"),
                   Resource = "",
                   Scope = Utility.CreateScope()
                ]
           ],

    ApplicationProperties = [
        PBIEndpointUrl = [PropertyType = Text.Type, IsRequired = false]
    ],

// valid DSRs
/*
{"protocol":"fabric-warehouse", "address":{}}
{"protocol":"fabric-warehouse", "address":{"workspace":"66402100-396f-41d4-8e88-19e8c6ae0834"}}
{"protocol":"fabric-warehouse", "address":{"workspace":"66402100-396f-41d4-8e88-19e8c6ae0834", "warehouse":"a83d87f0-70e7-497a-8ad2-757a63d499ef"}}
{"protocol":"fabric-warehouse", "address":{"workspace":"66402100-396f-41d4-8e88-19e8c6ae0834", "warehouse":"a83d87f0-70e7-497a-8ad2-757a63d499ef", "item":"Product", "schema":"model"}}
*/
    DSRHandlers = [
        #"fabric-warehouse" = [
            GetDSR = (optional options, optional navigation) =>
                let
                    workspace = navigation{0}?[workspaceId]?,
                    warehouse = navigation{2}?[warehouseId]?,
                    Item =  navigation{4}?[Item]?,
                    Schema =  navigation{4}?[Schema]?,
                    count = List.Count(navigation),
                    matchWarehouseWithItem = List.FirstN({ [workspaceId=workspace], "Data", [warehouseId=warehouse], "Data", [Item = Item, Schema = Schema], "Data"}, count),
                    isValidWarehouse = List.FirstN(matchWarehouseWithItem, count) = navigation,
                    address = if navigation = null then []
                              else if not isValidWarehouse then ...
                              else Record.RenameFields(Record.Combine(List.RemoveItems(matchWarehouseWithItem, {"Data"})), {{"workspaceId", "workspace"}, {"warehouseId", "warehouse"}, {"Item", "item"},{"Schema", "schema"}}, MissingField.Ignore)
                in
                    [ protocol = "fabric-warehouse", address = address],
            GetFormula = (dsr, optional options) =>
                let
                    address = ValidateAddressRecord(dsr[address]),
                    workspace = Record.FieldOrDefault(address, "workspace", null),
                    warehouse = Record.FieldOrDefault(address, "warehouse", null),
                    item = Record.FieldOrDefault(address, "item", null),
                    schema = Record.FieldOrDefault(address, "schema", null)
                in
                    if (workspace <> null) then
                        if (warehouse <> null and item <> null ) then
                            () => Fabric.Warehouse(options){[workspaceId=workspace]}[Data]{[warehouseId=warehouse]}[Data]{[Item=item, Schema=schema]}[Data]
                        else if (warehouse <> null) then
                            () => Fabric.Warehouse(options){[workspaceId=workspace]}[Data]{[warehouseId=warehouse]}[Data]
                        else
                            () => Fabric.Warehouse(options){[workspaceId=workspace]}[Data]
                    else
                        () => Fabric.Warehouse(options),
            GetFriendlyName = (dsr) => "Fabric Warehouse"
        ]
   ]
];

ValidateOptions2 = (options, optionsType) =>
    let
        available = Type.RecordFields(optionsType),
        found = Record.FieldNames(options),
        unknown = Text.Combine(List.FirstN(found, each not Record.HasFields(available, _)), ","),
        result = if (unknown <> null and unknown <> "") then error "Unknown field: " & unknown else options
    in
        result;

ValidateAddressRecord = (address as record) =>
    let
        validated = ValidateOptions2(address, type [
            workspace = Guid.Type,
            warehouse = Guid.Type,
            item = Text.Type,
            schema = Text.Type
        ])
    in
        validated;

[DataSource.Kind = "Warehouse", Publish="Warehouse.Publish"]
shared Fabric.Warehouse = Value.ReplaceType(WarehouseImpl, Warehouse.Type);

WarehouseImpl = (optional options as record) =>
    let
        nonNullOptions = options ?? [],
        result = GetNavTableForWarehouses(nonNullOptions)
    in
        result;

apiurl = GetClusterUrl(Environment.FeatureSwitch("PowerBiUri", "https://api.powerbi.com"));

GetNavTableForWarehouses = (options as record) =>
    let
        clusterEndpoint = Uri.Combine(apiurl, "/v1/workspaces"),
        jsonResponse = Web.JsonContents(clusterEndpoint),
        allWorkspaces = GetWorkspaces(jsonResponse),
        navtable = Table.NavigationTableView(
            () => allWorkspaces,
            {"workspaceId"},
            (workspaceId) => GetWarehouses(workspaceId, options),
            [
                Name = {"workspaceName", each [workspaceName]},
                ItemKind = each "Folder",
                ItemName = each "Folder",
                IsLeaf = each false
            ],
            [
                OnTestConnection = () => let
                firstWarehouse = GetFirstWarehouse(allWorkspaces),
                warehouseId = firstWarehouse[warehouseId]?,
                workspaceId = firstWarehouse[workspaceId]?,
                result = GetTDSEndPoint(workspaceId, warehouseId),
                tdsEndPoint = result[tdsEndpoint]?,
                displayName = result[name]?
            in
                if (UseSqlEndPointInTestConnection) then 
                    Sql.TestConnection(tdsEndPoint, displayName, warehouseId)
                else true
            ])
     in
        navtable;

GetFirstWarehouse = (allWorkspaces as table) as record =>
    let
        allWarehouses = Table.AddColumn(allWorkspaces, "warehouseId", each GetFirstWarehouseId([workspaceId])),
        firstWarehouse = Table.First(Table.SelectRows(allWarehouses, each [warehouseId] <> null))
    in
        firstWarehouse;

GetFirstWarehouseId = (workspaceId as text) as nullable text =>
    let
        warehouseEndpoint = Uri.Combine(apiurl, Text.Format("v1/workspaces/#{0}/items?type=Warehouse", {workspaceId})),
        jsonResponse = Web.JsonContents(warehouseEndpoint),
        workspacesData = jsonResponse[value],
        warehouses = List.Select(workspacesData, each Record.HasFields(_, {"id", "displayName"}))
    in
        List.First(warehouses)[id]?;

Warehouse.Type =
    let
       WarehouseType = type function (optional options as record)
                      as table meta [
                        Documentation.Name = Extension.LoadString("Warehouse_Title"),
                        Documentation.Caption = Extension.LoadString("Warehouse_Title"),
                        Documentation.Description = Extension.LoadString("Warehouse_Description"),
                        Documentation.LongDescription = Extension.LoadString("Warehouse_LongDescription")
                      ]
     in
       WarehouseType;

GetClusterUrl = (baseUrl as text) =>
    let
        maxRetryCount = 5,
        props = (Extension.CurrentCredential()[Properties]? ?? []) & Extension.CurrentApplication(),
        serviceEndpoint = props[PBIEndpointUrl]? ?? baseUrl,
        uriEnd = if UseNewClusterAPI then "/metadata/cluster" else "/powerbi/globalservice/v201606/clusterdetails",
        discoveryUrl = Uri.Combine(serviceEndpoint, uriEnd),
        response = Web.JsonContents(discoveryUrl, [500 = RetryHandler(maxRetryCount)]),
        clusterUrlViaRequest = if UseNewClusterAPI then response[backendUrl] else response[clusterUrl],
        _clusterUrl = props[PBI_ClusterUrl]? ?? clusterUrlViaRequest,
        clusterUrl = Diagnostics.Trace(TraceLevel.Information, [
                Name = "GetClusterUrl",
                Data = [],
                SafeData = [ ServiceEndpoint = serviceEndpoint, PBI_ClusterUrl = props[PBI_ClusterUrl]? ]
            ],
            _clusterUrl)
    in
        clusterUrl;

GetWorkspaces = (jsonResponse as record) as table =>
    let
        // Ensure that each record has 'id' and 'displayName'
        validateFields = List.Transform(jsonResponse[value], each if Record.HasFields(_, {"id", "displayName"})
                then _  else error Connector.GenerateErrorRecord("GetWorkspacesFailure", Extension.LoadString("MissingFieldsError"), "GetWorkspaces")),

        // Filter to only include records with 'capacityId'
        premiumWorkspaces = List.Select(validateFields, each Record.HasFields(_, "capacityId")),
        premiumWorkspacesTable = Table.FromRecords(premiumWorkspaces, {"id", "displayName"}),
        rename = Table.RenameColumns(premiumWorkspacesTable, {{"id", "workspaceId"}, {"displayName", "workspaceName"}})
    in
        rename;

GetWarehouses = (workspaceId as text, options as record) as table =>
    let
        warehouseEndpoint = Uri.Combine(apiurl, Text.Format("v1/workspaces/#{0}/items?type=Warehouse", {workspaceId})),
        jsonResponse = Web.JsonContents(warehouseEndpoint),
        workspacesData = jsonResponse[value],
        validateFields = List.Transform(workspacesData, each if Record.HasFields(_, {"id", "displayName"})
            then _ else error Connector.GenerateErrorRecord("GetWarehousesFailure", Extension.LoadString("MissingFieldsError"), "GetWarehouses")),
        warehouses = Table.FromRecords(validateFields, {"id", "displayName"}),
        renameToWarehouseId = Table.RenameColumns(warehouses, {{"id", "warehouseId"}}),
        withData = Table.AddColumn(renameToWarehouseId, "Data", each GetTables(workspaceId, [warehouseId], [displayName], options), type table),
        nav = Table.NavigationTableView(
            () => withData,
            {"warehouseId"},
            (_warehouseId) => let
                                result = GetTDSEndPoint(workspaceId, _warehouseId),
                                tdsEndPoint = result[tdsEndpoint],
                                displayName = result[name]? ?? withData{[warehouseId = _warehouseId]}[displayName]
                              in
                                GetWarehouse(tdsEndPoint, displayName, options),
            [
                Name = {"displayName", each [displayName]},
                ItemKind = each "Database",
                ItemName = each "Database",
                IsLeaf = each false
            ],
            [ OnTestConnection = () => 
                let
                    warehouseId = Table.First(warehouses)[id]?,
                    result = GetTDSEndPoint(workspaceId, warehouseId),
                    tdsEndPoint = result[tdsEndpoint]?,
                    displayName = result[name]? ?? withData{[warehouseId = warehouseId]}[displayName]
                in
                    if (warehouseId <> null) then Sql.TestConnection(tdsEndPoint, displayName, warehouseId)
                        else Sql.TestConnection(null, null, "")
            ])
    in
        nav;

GetTables = (workspaceId as text, artifactObjectId as text, warehouseName as text, options as record) as table =>
    let
          jsonResponse = GetTDSEndPoint(workspaceId, artifactObjectId),
          tdsEndPoint = jsonResponse[tdsEndpoint],
          nav = GetWarehouse(tdsEndPoint, warehouseName, options),
          withoutSystemTables = Table.SelectRows(nav, each [Schema] <> "sys")
     in
         Table.View(withoutSystemTables,[
            OnInvoke = (function, args, index) =>
                if (function = Value.Versions) then Value.Versions(nav)
                else if (function = Value.VersionIdentity) then Value.VersionIdentity(nav)
                else ...,
            OnSelectRows = (selector) => Table.SelectRows(nav, selector), // Prevent the "sys" schema predicate from blocking folding
            GetExpression = () => Value.Expression(Value.Optimize(nav)),
            OnTestConnection = () => Sql.TestConnection(tdsEndPoint, warehouseName, artifactObjectId)
          ]);

GetTDSEndPoint = (workspaceId as text, artifactObjectId as text) as record  =>
    let
        url = Uri.Combine(apiurl, Text.Format("v1.0/myorg/datawarehouses/#{0}/information", {artifactObjectId})),
        jsonResponse = Web.JsonContents(url),
        state = jsonResponse[state]?,
        status = jsonResponse[status]?,
        name = jsonResponse[name]?,        
        invalidWarehouseStateAndStatusError = Error.Record(
            NonPii("DataSource.Error"),
            NonPii(Extension.LoadString("WarehouseInInvalidState")),
            [
                WorkspaceId = workspaceId,
                DatawarehouseId = artifactObjectId
            ],
            {name, NonPii(artifactObjectId), NonPii(state), NonPii(status)}
        )
     in
        if state = 1 and status = 1 then jsonResponse
        else error Diagnostics.Trace(TraceLevel.Error, 
            [Name = "GetTDSEndPoint",
            Data = [DwName = name], SafeData = [DwId = artifactObjectId, State = state, Status = status, WorkspaceId = workspaceId]], invalidWarehouseStateAndStatusError);

GetWarehouse = (tdsEndPoint as text, warehouseName as text, options as record) =>
    Extension.InvokeWithCredentials(
         (datasource) => GetCredential(AadSqlResource),
         () =>
            let
                curatedOptions = Record.SelectFields(options, {"CommandTimeout", "CreateNavigationProperties"}, MissingField.Ignore),
                warehouse = Sql.Database(tdsEndPoint, warehouseName, curatedOptions & [EnableCrossDatabaseFolding=true])
            in
                warehouse
    );

Sql.TestConnection = (serverInstance as nullable text, dbname as nullable text, warehouseId as nullable text) =>
    Extension.InvokeWithCredentials(
        (datasource) => GetCredential(AadSqlResource),
        () =>
            let
                ErrorMessageFormat = Extension.LoadString("TestConnectionFailure"),
                result = if (serverInstance <> null) then DataSource.TestConnection(Sql.Database(serverInstance, dbname)) else
                    error Error.Record(NonPii("DataSource.Error"), NonPii(ErrorMessageFormat), [], {NonPii(warehouseId), serverInstance, dbname})
            in
                try result catch (e) => error Diagnostics.Trace(TraceLevel.Error, [
                        Name = "SqlTestConnectionFailure",
                        Data = [ Exception = Value.ToText(e) ],
                        SafeData = [ WarehouseId = warehouseId ]
                    ], e)
    );

GetCredential = (resource) =>
    let
        currentCredentials = Extension.CurrentCredential(),
        trimmedResource = Text.TrimEnd(resource, "/"),
        prop = "AccessToken:" & trimmedResource,
        propWithSlash = "AccessToken:" & trimmedResource & "/",
        tokenValue = Record.FieldOrDefault(currentCredentials[Properties], prop, Record.FieldOrDefault(currentCredentials[Properties], propWithSlash, "")),
        finalTokenValue = if tokenValue = "" then Diagnostics.Trace(TraceLevel.Error, Text.Format("Credentials object do not have Property #{0} or #{1}", {prop, propWithSlash}), currentCredentials[access_token]) else tokenValue,
        credentialToReturn = currentCredentials & [access_token = finalTokenValue]
    in
        credentialToReturn;

Utility.CreateScope = () as text =>
    let
        appendix = "user_impersonation",
        scopeForSql = Text.Format("#{1}/#{0}", {appendix, AadSqlResource}),
        scopeForWorkspaces = Text.Format("#{1}/#{0}", {appendix, Environment.FeatureSwitch("PowerBiAadResource", "https://analysis.windows.net/powerbi/api")}),
        result = Text.Combine({scopeForWorkspaces, scopeForSql}, " ")
    in
        result;

Web.JsonContents = (url as text, optional additionalHandlers as record, optional jsonBody as any, optional startState as record) =>
    let
        moreHeaders = if jsonBody = null then [] else [#"Content-Type" = "application/json;charset=UTF-8"],
        content = if jsonBody = null then null else Json.FromValue(jsonBody)
    in
        Http.Request(
            url,
            [
                Headers = PBICommonHeaders() & moreHeaders,
                ExcludedFromCacheKey = PBICommonHeaderNames,
                Content=content,
                SafeRequestHeaders = {UniqueRequestHeader},
                SafeResponseHeaders = {"RequestId"} // Trident responses seem to return a new unique value here
            ],
            DefaultHandlers & [200 = JsonHandler] & (additionalHandlers ?? []),
            startState);

Web.ErrorResponse = (state as record) =>
    let
        url = state[Url],
        status = state[Status],
        result = try
        let
            jsonResponse = Json.Document(state[Response]) meta Value.Metadata(state[Response]),
            responseStatusCode = Record.FieldOrDefault(Value.Metadata(jsonResponse), "Response.Status", 0),
            requestId = Record.FieldOrDefault(Value.Metadata(jsonResponse)[Headers]?, "RequestId", ""),
            errorCode = jsonResponse[error]? ?? jsonResponse[errorCode]?,
            errorMessage = jsonResponse[error][message]? ?? jsonResponse[error][pbi.error][parameters][ErrorMessage]? ?? jsonResponse[message]? ?? errorCode,
            errorDetails = try if List.IsEmpty(jsonResponse[error][pbi.error][details]) then errorMessage
                else Text.Combine(jsonResponse[error][pbi.error][details], " ") otherwise Value.ToText(jsonResponse[error]? ?? jsonResponse),
            errorRecord =
                Error.Record(
                    NonPii("DataSource.Error"),
                    NonPii(Extension.LoadString("DownstreamServiceCallFailure")),
                    [
                        Error = errorDetails,
                        ErrorCode = errorCode,
                        RequestId = requestId,
                        RequestUrl = url,
                        ErrorMessage = errorMessage
                    ],
                    {NonPii(url), NonPii(status)}
                )
        in
            errorRecord,
        jsonResponseText = try Text.FromBinary(state[Response]) otherwise "<encoding error>",
        errorMessageToLog = if result[HasError] then Text.Format(Extension.LoadString("ErrorParsingJsonInHttpResponse"), {jsonResponseText})
            else result[Value][Message],
        finalResult = Diagnostics.Trace(TraceLevel.Warning, [
                Name = "WarehouseWebError",
                Data = [ Error = errorMessageToLog ],
                SafeData = [ Url = url, StatusCode = status ]
            ],
            if result[HasError] then Error.Record(
                NonPii("DataSource.Error"),
                NonPii(Extension.LoadString("DownstreamServiceCallFailure")),
                [
                    RequestUrl = url,
                    ErrorMessage = jsonResponseText
                ],
                {NonPii(url), NonPii(status)})
            else result[Value])
    in
        error finalResult;

UniqueRequestHeader = "x-ms-client-request-id";

PBICommonHeaders = () =>
    let
        activityId = Diagnostics.ActivityId(),
        requestId = Text.NewGuid()
    in
        Record.FromList({requestId, activityId, requestId, activityId}, PBICommonHeaderNames);
DefaultHandlers = [
    302 = DefaultErrorHandler,
    400 = DefaultErrorHandler,
    403 = AuthHandler,
    401 = AuthHandler,
    404 = DefaultErrorHandler,
    500 = DefaultErrorHandler,
    503 = DefaultErrorHandler,
    Error = RequestFailureHandler
];

DefaultErrorHandler = (state) => Web.ErrorResponse(state);

AuthHandler = (state) =>
    if state[Refreshed]? = true or not Web.TryRefreshToken() then DefaultErrorHandler(state)
    else state & [Refreshed = true];

RetryHandler = (count, optional delayFunction) =>
    let delay = delayFunction ?? ((i) => i * 0.2) in
    (state) =>
        if state[Iteration] < count then Function.InvokeAfter(() => state, #duration(0, 0, 0, delay(state[Iteration])))
        else DefaultErrorHandler(state);

JsonHandler = (state) => state & [
    Response = Json.Document(state[Response]) meta Value.Metadata(state[Response]),
    Complete = true
];

RequestFailureHandler = (exception, url) =>
    error Error.Record(NonPii("DataSource.Error"),
        NonPii(Extension.LoadString("DownstreamServiceCallError")),
        exception,
        {NonPii(url)});

CompleteHandler = (state) => state & [Complete = true];

Http.Request = (url as text, options as record, handlers as record, optional startState as record) =>
    let
        errorHandler = handlers[Error]?,
        handledStatuses = List.Buffer(List.Transform(Record.FieldNames(Record.RemoveFields(handlers, "Error")), Number.From)),
        moreOptions = options & [ManualStatusHandling = handledStatuses],
        list = List.Generate(
            () => [Iteration = 0, Url = url, Response = null, Complete = false, Return = false] & (startState ?? []),
            (state) => not state[Return],
            (state) => if state[Complete] then state & [Return = true] else
                let
                    // The urls from the connector don't have PII data, so it is safe to log them.
                    response = Web.Contents(url, moreOptions & [IsRetry = state[Iteration] > 0, TraceData = [RequestUrl = NonPii(url)]]),
                    responseStatus = Value.Metadata(response)[Response.Status]? ?? 200,
                    status = if errorHandler = null then responseStatus
                             else try responseStatus catch(e) => errorHandler(e, url),
                    handler = Record.FieldOrDefault(handlers, Text.From(status, "")),
                    partial = state & [Iteration = state[Iteration] + 1, Response = response, Complete = false, Status = status],
                    nextState = if handler = null then partial & [Complete = true] else partial & handler(partial)
                in
                    nextState),
        result = List.Last(list)[Response]
    in
        result;

Web.TryRefreshToken = () as logical =>
    let
        forceRefreshOfTokens = true
    in
        Extension.CurrentCredential(forceRefreshOfTokens) <> null; // Force refresh of token.

Value.ConvertToLogical = (a) =>
    a <> null and a <> "" and Logical.From(a);

Value.WaitFor = (producer as function, delay as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, null},
            (state) => state{0} <> null and (count = null or state{0} < (count + 1)), //first row is {0, null} and doesn't invoke the producer.
            (state) => if state{1} <> null
                then {null, state{1}}
                else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), delay(state{0}))},
            (state) => state{1}),
        result = List.Last(list)
    in
        result;

Web.RefreshToken = () as logical =>
    let
        result = Record.HasFields(Extension.CurrentCredential(true), {"Doesn't exist"}) // Force refresh of token.
    in
        result;


Value.ToText = (value, optional depth) =>
    let
        nextDepth = if depth = null then 3 else depth - 1,
        result = if depth = 0 then "..."
            else if value is null then "<null>"
            else if value is function then Record.FieldOrDefault(Value.Metadata(Value.Type(value)), "Documentation.Name", "<function>")
            else if value is table then "#table({" & Text.Combine(Table.ColumnNames(value), ",") & "},{" & Text.Combine(
                List.Transform(Table.ToRows(Table.FirstN(value, 2)), each @Value.ToText(_, nextDepth)), "},#(cr)#(lf){") & "})"
                //& "Row Count (" & Number.ToText(Table.RowCount(value)) & ")"
            else if value is list then "{" & Text.Combine(List.Transform(List.FirstN(value, 10), each @Value.ToText(_, nextDepth)), ",") & "}"
            else if value is record then "[" & Text.Combine(List.Transform(Record.FieldNames(value), each _ & "=" & @Value.ToText(Record.Field(value, _), nextDepth)), ",") & "]"
            else if value is type then List.First(Table.Schema(#table({"type"}, {{value}}))[TypeName], "<type>")
            else if value is action then "action"
            else Text.From(value)
    in
        try result otherwise "<error>";

Value.IfNull = (a, b) =>
    if a <> null then a
        else b;

Connector.GenerateErrorRecord = (marker as text, piiFreeLogMessage as text, callerName as text) =>
let
    tracedMessage = Diagnostics.Trace(TraceLevel.Error, [Name = callerName,
                Data = [],
                SafeData = [ErrorCode = marker, ErrorMessage = piiFreeLogMessage]], piiFreeLogMessage)
in
    Error.Record(NonPii("DataSource.Error"),
        NonPii(tracedMessage));

Warehouse.Publish = [
    Name = Extension.LoadString("DataSourceLabel"),
    SupportsDirectQuery = true,
    Category = "Fabric",
    ButtonText = {
            Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp")
        },
    SourceImage = Warehouse.Icons,
    SourceTypeImage = Warehouse.Icons
];

Warehouse.Icons = [
    Icon16 = { Extension.Contents("Warehouse_16.png"), Extension.Contents("Warehouse_20.png"), Extension.Contents("Warehouse_20.png"), Extension.Contents("Warehouse_24.png") },
    Icon32 = { Extension.Contents("Warehouse_32.png"), Extension.Contents("Warehouse_40.png"), Extension.Contents("Warehouse_48.png"), Extension.Contents("Warehouse_64.png") }
];

// Extension library functions
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Table.NavigationTableView = try Extension.LoadFunction("Table.NavigationTableView.pqm") otherwise error "Module not loaded";
