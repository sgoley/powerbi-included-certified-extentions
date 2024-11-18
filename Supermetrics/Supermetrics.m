[Version = "3.0.4"]
section Supermetrics;

ConnectorVersion = "3.0.4";

Extension.LoadFunction = (filename as text) =>
    Expression.Evaluate(Text.FromBinary(Extension.Contents(filename)), #shared);

Icons = Extension.LoadFunction("Icons.pqm");
Supermetrics = [
    TestConnection = (datasourcePath) as list => {"Supermetrics.Test"},
    Authentication = [
        OAuth = Auth
    ],
    Label = Extension.LoadString("AuthTitle")
];

Supermetrics.Publish = [
    Beta = true,
    Category = "Online Services",
    ButtonText = {Extension.LoadString("GetDataLabel"), Extension.LoadString("GetDataTooltip")},
    LearnMoreUrl = "https://supermetrics.com/powerbi",
    SourceImage = Icons,
    SourceTypeImage = Icons
];

[
    DataSource.Kind = "Supermetrics"
]
shared Supermetrics.Test = () as any => HttpClient[Get](Urls[Profile], [], []);

[
    DataSource.Kind = "Supermetrics",
    Publish = "Supermetrics.Publish"
]
 shared Supermetrics.Render = () as table =>
    let
        _myQueriesTable = Navigation[GetMyQueries](),
        _gettingStartedTable = GettingStarted[Table],
        _navigationToolsTable = Tools[GetNavigationToolsTable](),
        _tables = {_gettingStartedTable, _myQueriesTable, _navigationToolsTable},
        _filteredTables = List.Select(_tables, each not Table.IsEmpty(_)),
        _resultWithEvent = (eventResponse) => Table.ToNavigationTable(
            Table.Combine(_filteredTables),
            {"id"},
            "label",
            "items",
            "icon",
            "type",
            "leaf"
        ),
        _eventResponse = Tracking[NavigatorStart](),
        _result = _resultWithEvent(_eventResponse)
            
    in
        _result;

Debug = let
    this.ValueToText = (value as any) =>
    let
        //From Microsoft TripPin 8-Diagnostics tutorial
        //Source: https://github.com/microsoft/DataConnectors/blob/master/samples/TripPin/8-Diagnostics/Diagnostics.pqm
        _valueToText = (value) =>
            let
            _canBeIdentifier = (x) =>
                                            let
                                                keywords = {"and", "as", "each", "else", "error", "false", "if", "in", "is", "let", "meta", "not", "otherwise", "or", "section", "shared", "then", "true", "try", "type" },
                                                charAlpha = (c as number) => (c>= 65 and c <= 90) or (c>= 97 and c <= 122) or c=95,
                                                charDigit = (c as number) => c>= 48 and c <= 57
                                            in
                                                try
                                                    charAlpha(Character.ToNumber(Text.At(x,0)))
                                                    and
                                                        List.MatchesAll(
                                                            Text.ToList(x),
                                                            (c)=> let num = Character.ToNumber(c) in charAlpha(num) or charDigit(num)
                                                        )
                                                    and not
                                                        List.MatchesAny( keywords, (li)=> li=x )
                                                otherwise
                                                    false,

            Serialize.Binary =      (x) => "#binary(" & Serialize(Binary.ToList(x)) & ") ",

            Serialize.Date =        (x) => "#date(" &
                                           Text.From(Date.Year(x))  & ", " &
                                           Text.From(Date.Month(x)) & ", " &
                                           Text.From(Date.Day(x))   & ") ",

            Serialize.Datetime =    (x) => "#datetime(" &
                                           Text.From(Date.Year(DateTime.Date(x)))    & ", " &
                                           Text.From(Date.Month(DateTime.Date(x)))   & ", " &
                                           Text.From(Date.Day(DateTime.Date(x)))     & ", " &
                                           Text.From(Time.Hour(DateTime.Time(x)))    & ", " &
                                           Text.From(Time.Minute(DateTime.Time(x)))  & ", " &
                                           Text.From(Time.Second(DateTime.Time(x)))  & ") ",

            Serialize.Datetimezone =(x) => let
                                              dtz = DateTimeZone.ToRecord(x)
                                           in
                                              "#datetimezone(" &
                                              Text.From(dtz[Year])        & ", " &
                                              Text.From(dtz[Month])       & ", " &
                                              Text.From(dtz[Day])         & ", " &
                                              Text.From(dtz[Hour])        & ", " &
                                              Text.From(dtz[Minute])      & ", " &
                                              Text.From(dtz[Second])      & ", " &
                                              Text.From(dtz[ZoneHours])   & ", " &
                                              Text.From(dtz[ZoneMinutes]) & ") ",

            Serialize.Duration =    (x) => let
                                              dur = Duration.ToRecord(x)
                                           in
                                              "#duration(" &
                                              Text.From(dur[Days])    & ", " &
                                              Text.From(dur[Hours])   & ", " &
                                              Text.From(dur[Minutes]) & ", " &
                                              Text.From(dur[Seconds]) & ") ",

            Serialize.Function =    (x) => _serialize_function_param_type(
                                              Type.FunctionParameters(Value.Type(x)),
                                              Type.FunctionRequiredParameters(Value.Type(x)) ) &
                                           " as " &
                                           _serialize_function_return_type(Value.Type(x)) &
                                           " => (...) ",

            Serialize.List =        (x) => "{" &
                                           List.Accumulate(x, "", (seed,item) => if seed="" then Serialize(item) else seed & ", " & Serialize(item)) &
                                           "} ",

            Serialize.Logical =     (x) => Text.From(x),

            Serialize.Null =        (x) => "null",

            Serialize.Number =      (x) =>
                                        let Text.From = (i as number) as text =>
                                            if Number.IsNaN(i) then "#nan" else
                                            if i=Number.PositiveInfinity then "#infinity" else
                                            if i=Number.NegativeInfinity then "-#infinity" else
                                            Text.From(i)
                                        in
                                            Text.From(x),

            Serialize.Record =      (x) => "[ " &
                                           List.Accumulate(
                                                Record.FieldNames(x),
                                                "",
                                                (seed,item) =>
                                                    (if seed="" then Serialize.Identifier(item) else seed & ", " & Serialize.Identifier(item)) & " = " & Serialize(Record.Field(x, item))
                                           ) &
                                           " ] ",

            Serialize.Table =       (x) => "#table( type " &
                                            _serialize_table_type(Value.Type(x)) &
                                            ", " &
                                            Serialize(Table.ToRows(x)) &
                                            ") ",

            Serialize.Text =        (x) => """" &
                                           _serialize_text_content(x) &
                                           """",

            _serialize_text_content =  (x) => let
                                                escapeText = (n as number) as text => "#(#)(" & Text.PadStart(Number.ToText(n, "X", "en-US"), 4, "0") & ")"
                                            in
                                            List.Accumulate(
                                               List.Transform(
                                                   Text.ToList(x),
                                                   (c) => let n=Character.ToNumber(c) in
                                                            if n = 9   then "#(#)(tab)" else
                                                            if n = 10  then "#(#)(lf)"  else
                                                            if n = 13  then "#(#)(cr)"  else
                                                            if n = 34  then """"""      else
                                                            if n = 35  then "#(#)(#)"   else
                                                            if n < 32  then escapeText(n) else
                                                            if n < 127 then Character.FromNumber(n) else
                                                            escapeText(n)
                                                ),
                                                "",
                                                (s,i)=>s&i
                                            ),

            Serialize.Identifier =   (x) =>
                                            if _canBeIdentifier(x) then
                                                x
                                            else
                                                "#""" &
                                                _serialize_text_content(x) &
                                                """",

            Serialize.Time =        (x) => "#time(" &
                                           Text.From(Time.Hour(x))   & ", " &
                                           Text.From(Time.Minute(x)) & ", " &
                                           Text.From(Time.Second(x)) & ") ",

            Serialize.Type =        (x) => "type " & _serialize_typename(x),


            _serialize_typename =    (x, optional funtype as logical) =>
                                        let
                                            isFunctionType = (x as type) => try if Type.FunctionReturn(x) is type then true else false otherwise false,
                                            isTableType = (x as type) =>  try if Type.TableSchema(x) is table then true else false otherwise false,
                                            isRecordType = (x as type) => try if Type.ClosedRecord(x) is type then true else false otherwise false,
                                            isListType = (x as type) => try if Type.ListItem(x) is type then true else false otherwise false
                                        in

                                            if funtype=null and isTableType(x) then _serialize_table_type(x) else
                                            if funtype=null and isListType(x) then "{ " & @_serialize_typename( Type.ListItem(x) ) & " }" else
                                            if funtype=null and isFunctionType(x) then "function " & _serialize_function_type(x) else
                                            if funtype=null and isRecordType(x) then _serialize_record_type(x) else

                                            if x = type any then "any" else
                                            let base = Type.NonNullable(x) in
                                              (if Type.IsNullable(x) then "nullable " else "") &
                                              (if base = type anynonnull then "anynonnull" else
                                              if base = type binary then "binary" else
                                              if base = type date   then "date"   else
                                              if base = type datetime then "datetime" else
                                              if base = type datetimezone then "datetimezone" else
                                              if base = type duration then "duration" else
                                              if base = type logical then "logical" else
                                              if base = type none then "none" else
                                              if base = type null then "null" else
                                              if base = type number then "number" else
                                              if base = type text then "text" else
                                              if base = type time then "time" else
                                              if base = type type then "type" else

                                              /* Abstract types: */
                                              if base = type function then "function" else
                                              if base = type table then "table" else
                                              if base = type record then "record" else
                                              if base = type list then "list" else

                                              "any /*Actually unknown type*/"),

            _serialize_table_type =     (x) =>
                                               let
                                                 schema = Type.TableSchema(x)
                                               in
                                                 "table " &
                                                 (if Table.IsEmpty(schema) then "" else
                                                     "[" & List.Accumulate(
                                                        List.Transform(
                                                            Table.ToRecords(Table.Sort(schema,"Position")),
                                                            each Serialize.Identifier(_[Name]) & " = " & _[Kind]),
                                                        "",
                                                        (seed,item) => (if seed="" then item else seed & ", " & item )
                                                    ) & "] " ),

            _serialize_record_type =    (x) =>
                                                let flds = Type.RecordFields(x)
                                                in
                                                    if Record.FieldCount(flds)=0 then "record" else
                                                        "[" & List.Accumulate(
                                                            Record.FieldNames(flds),
                                                            "",
                                                            (seed,item) =>
                                                                seed &
                                                                (if seed<>"" then ", " else "") &
                                                                (Serialize.Identifier(item) & "=" & _serialize_typename(Record.Field(flds,item)[Type]) )
                                                        ) &
                                                        (if Type.IsOpenRecord(x) then ",..." else "") &
                                                        "]",

            _serialize_function_type =  (x) => _serialize_function_param_type(
                                                  Type.FunctionParameters(x),
                                                  Type.FunctionRequiredParameters(x) ) &
                                                " as " &
                                                _serialize_function_return_type(x),

            _serialize_function_param_type = (t,n) =>
                                    let
                                        funsig = Table.ToRecords(
                                            Table.TransformColumns(
                                                Table.AddIndexColumn( Record.ToTable( t ), "isOptional", 1 ),
                                                { "isOptional", (x)=> x>n } ) )
                                    in
                                        "(" &
                                        List.Accumulate(
                                            funsig,
                                            "",
                                            (seed,item)=>
                                                (if seed="" then "" else seed & ", ") &
                                                (if item[isOptional] then "optional " else "") &
                                                Serialize.Identifier(item[Name]) & " as " & _serialize_typename(item[Value], true) )
                                         & ")",

            _serialize_function_return_type = (x) => _serialize_typename(Type.FunctionReturn(x), true),

            Serialize = (x) as text =>
                               if x is binary       then try Serialize.Binary(x) otherwise "null /*serialize failed*/"        else
                               if x is date         then try Serialize.Date(x) otherwise "null /*serialize failed*/"          else
                               if x is datetime     then try Serialize.Datetime(x) otherwise "null /*serialize failed*/"      else
                               if x is datetimezone then try Serialize.Datetimezone(x) otherwise "null /*serialize failed*/"  else
                               if x is duration     then try Serialize.Duration(x) otherwise "null /*serialize failed*/"      else
                               if x is function     then try Serialize.Function(x) otherwise "null /*serialize failed*/"      else
                               if x is list         then try Serialize.List(x) otherwise "null /*serialize failed*/"          else
                               if x is logical      then try Serialize.Logical(x) otherwise "null /*serialize failed*/"       else
                               if x is null         then try Serialize.Null(x) otherwise "null /*serialize failed*/"          else
                               if x is number       then try Serialize.Number(x) otherwise "null /*serialize failed*/"        else
                               if x is record       then try Serialize.Record(x) otherwise "null /*serialize failed*/"        else
                               if x is table        then try Serialize.Table(x) otherwise "null /*serialize failed*/"         else
                               if x is text         then try Serialize.Text(x) otherwise "null /*serialize failed*/"          else
                               if x is time         then try Serialize.Time(x) otherwise "null /*serialize failed*/"          else
                               if x is type         then try Serialize.Type(x) otherwise "null /*serialize failed*/"          else
                               "[#_unable_to_serialize_#]"
            in
                try Serialize(value) otherwise "<serialization failed>"
    in
        try _valueToText(value) otherwise "<error getting value>",

    this.LogValue = (logLevel as number, prefix as text, value as any, optional delayed) =>
        let
            _valueToText = this.ValueToText(value)
        in
            Diagnostics.Trace(
                logLevel, prefix & ": " & _valueToText, value, delayed
            )
in
    [
        LogValue = this.LogValue,
        ValueToText = this.ValueToText
    ]        ;


Debug.LogValue = Debug[LogValue];
Debug.ValueToText = Debug[ValueToText];

TableFn = let
    this.toNavigationTable = (
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
            newTableType = Type.AddTableKey(tableType, keyColumns, true) meta [
                NavigationTable.NameColumn = nameColumn,
                NavigationTable.DataColumn = dataColumn,
                NavigationTable.ItemKindColumn = itemKindColumn,
                Preview.DelayColumn = itemNameColumn,
                NavigationTable.IsLeafColumn = isLeafColumn
            ],
            navigationTable = Value.ReplaceType(table, newTableType)
        in
            navigationTable,
    this.getDataTypeAsNative = (dataType as text) as type =>
        if dataType = "bool" then
            Logical.Type
        else if dataType = "string.time.date" then
            Date.Type
        else if dataType = "string.time.datetime" then
            DateTime.Type
        else if dataType = "string.time.hm" then
            Time.Type
        else if dataType = "string.time.hms" then
            Time.Type
        else if dataType = "int.duration.seconds" then
            Duration.Type
        else if Text.StartsWith(dataType, "int.") then
            Int64.Type
            // Docs: precision = 28, scale = 4
        else if Text.StartsWith(dataType, "float.") then
            Decimal.Type
            // Docs: up to 4000 characters per string value
        else
            Text.Type,
    this.getTableSchema = (headers as list) as list =>
        List.Transform(
            headers, (fieldInfo) => {fieldInfo[name], this.getDataTypeAsNative(fieldInfo[data_type])}
        )
in
    [
        ToNav = this.toNavigationTable,
        GetTableSchema = this.getTableSchema
    ]
;



Table.ToNavigationTable = TableFn[ToNav];
Table.GetTableSchema = TableFn[GetTableSchema];

Auth = let
    this.clientId = "5b4fd1d6-0065-4141-8775-2b9d99d30773",
    this.createHash = (codeVerifier as text) as text =>
        let
            _result = Binary.ToText(
                Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(codeVerifier, TextEncoding.Ascii)),
                BinaryEncoding.Base64
            )
        in
            _result,
    this.tokenMethod = (code, grant_type, optional verifier) as record =>
        let
            _codeVerifier =
                if (verifier <> null) then
                    [
                        code_verifier = verifier
                    ]
                else
                    [
                        code_verifier = Text.NewGuid() & Text.NewGuid()
                    ],
            _codeParameter = if (grant_type = "authorization_code") then [
                code = code
            ] else [
                refresh_token = code
            ],
            _query = _codeVerifier
                & _codeParameter
                & [
                    client_id = this.clientId,
                    grant_type = grant_type,
                    redirect_uri = Urls[AuthRedirect]
                ],
            // Set this if your API returns a non-2xx status for login failures
            // ManualHandlingStatusCodes = {400, 403}
            ManualHandlingStatusCodes = {},
            Response = Web.Contents(
                Urls[AuthToken],
                [
                    Content = Text.ToBinary(Uri.BuildQueryString(_query)),
                    Headers = [
                        #"Content-type" = "application/x-www-form-urlencoded",
                        #"Accept" = "application/json",
                        #"X-Pbi-Connector-Version" = ConnectorVersion
                    ],
                    ManualStatusHandling = ManualHandlingStatusCodes
                ]
            ),
            _response = Json.Document(Response),
            _result =
                if (_response[error]? <> null) then
                    error Error.Record(_response[error], _response[message]?)
                else
                    _response
        in
            _result,
    this.startLogin = (resourceUrl, state, display) =>
        let
            // We'll generate our code verifier using Guids
            _codeVerifier = Text.NewGuid() & Text.NewGuid(),
            AuthorizeUrl = Urls[AuthLogin]
                & "?"
                & Uri.BuildQueryString(
                    [
                        client_id = this.clientId,
                        response_type = "code",
                        code_challenge_method = "S256",
                        code_challenge = this.createHash(_codeVerifier),
                        state = state,
                        product_id = "powerbi",
                        redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html"
                    ]
                )
        in
            [
                LoginUri = AuthorizeUrl,
                CallbackUri = "https://oauth.powerbi.com/views/oauthredirect.html",
                WindowHeight = 800,
                WindowWidth = 800,
                // Need to roundtrip this value to FinishLogin
                Context = _codeVerifier
            ],
    this.finishLogin = (context, callbackUri, state) =>
        let
            _parts = Uri.Parts(callbackUri)[Query],
            _result = this.tokenMethod(_parts[code], "authorization_code", context)
        in
            _result,
    this.refreshToken = (resourceUrl, refresh_token) => this.tokenMethod(refresh_token, "refresh_token")
in
    [
        Label = "OAuth Credentials",
        StartLogin = this.startLogin,
        FinishLogin = this.finishLogin,
        Refresh = this.refreshToken
    ]
;


Urls = let
    environment = "supermetrics",
    //environment = "ismtip",
    envBase = "https://api." & environment & ".com",
    enterprise = "enterprise",
    //enterprise = "",
    apiBase = envBase & "/" & enterprise,
    authBase = envBase & "/oauth",
    authLogin = authBase & "/authorize",
    authToken = authBase & "/token",
    trackingAdd = envBase & "/powerbi/tracking/add",
    cluster = envBase & "/server/cluster",
    redirect = "https://addon." & environment & ".com/powerbi/redirect.html",
    navigator = apiBase & "/integration/powerbi/navigator",
    profile = envBase & "/profile",
    teams = envBase & "/teams",
    dsLogins = apiBase & "/ds/logins",
    queries = apiBase & "/queries",
    dsLoginAccounts = apiBase & "/ds/login/",
    teamAccountsRefresh = envBase & "/team/accounts/refresh",
    dataSource = apiBase & "/powerbi/datasource",
    standardSchemasQueries = apiBase & "/integration/powerbi/standardschemas",
    gettingstarted = apiBase & "/integration/powerbi/getting_started"
in
    [
        ApiBase = apiBase,
        AuthLogin = authLogin,
        AuthToken = authToken,
        Cluster = cluster,
        TrackingAdd = trackingAdd,
        AuthRedirect = redirect,
        Navigator = navigator,
        Profile = profile,
        DsLogins = dsLogins,
        Queries = queries,
        Teams = teams,
        DsLoginAccounts = dsLoginAccounts,
        Enterprise = enterprise,
        TeamAccountsRefresh = teamAccountsRefresh,
        DataSource = dataSource,
        StandardSchemasQueries = standardSchemasQueries,
        GettingStarted = gettingstarted
    ]
;


HttpClient = let
    this.ApiBase = Urls[ApiBase],
    this.manualStatusCodesHandling = {400, 403, 404, 429, 500},
    // Function invoker
    this.execFunc = (callable as nullable function, response as record) as record =>
        Record.Combine({try callable() otherwise [], response}),
    // Verified URL
    this.validateUrlScheme = (url as text) as text =>
        if (Uri.Parts(url)[Scheme] <> "https") then
            error "Url scheme must be HTTPS"
        else
            url,
    // https://docs.microsoft.com/en-us/power-query/helperfunctions#valuewaitfor
    this.pollForResults = (producer as function, interval as function, optional count as number) as any =>
        let
            _list = List.Generate(
                () => {0, null},
                (state) => state{0} <> null and (count = null or state{0} <= count),
                (state) =>
                    if state{1} <> null then
                        {null, state{1}}
                    else
                        {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), interval(state{0}))},
                (state) => state{1}
            )
        in
            List.Last(_list),
    // Returns default headers
    this.getHeaders = (additional as record) as record =>
        Record.Combine(
            {
                [
                    #"Content-Type" = "application/json",
                    #"Authorization" = "Bearer " & Extension.CurrentCredential()[access_token],
                    #"X-Pbi-Connector-Version" = ConnectorVersion
                ],
                additional
            }
        ),
    // Returns HTTP request options
    this.getOptions = (iteration as number, queryParams as record, body as nullable text) as record =>
        let
            _options = [
                Headers = this.getHeaders(
                    Record.Combine(
                        {[#"X-Pbi-Iteration" = Number.ToText(iteration)], try Value.Metadata(body)[headers] otherwise []}
                    )
                ),
                Query = queryParams,
                ManualStatusHandling = this.manualStatusCodesHandling,
                IsRetry = iteration > 0
            ],
            _optionsWithPostBody =
                if body <> null then
                    Record.AddField(_options, "Content", Text.ToBinary(body))
                else
                    _options,
            _result = _optionsWithPostBody
        in
            _result,
    // Returns binary response from the endpoint
    this.getResponse = (endpoint as text, queryParams as record, body as nullable text) as any =>
        let
            _endpointMetadata = Value.Metadata(endpoint),
            _retryFn = Record.FieldOrDefault(_endpointMetadata, "RetryFn", null) as nullable function,
            _retryDelay = Record.FieldOrDefault(_endpointMetadata, "RetryDelay", 5) as number,
            _retryCount = Record.FieldOrDefault(_endpointMetadata, "RetryCount", 6) as number,
            _url = this.validateUrlScheme(endpoint),
            _result = this.pollForResults(
                (iteration as number) as nullable binary =>
                    let
                        _options = this.getOptions(iteration, queryParams, body),
                        _httpResponse = Web.Contents(_url, _options),
                        // Use Binary.Buffer to prevent multiple HTTP calls
                        _response = Binary.Buffer(_httpResponse) meta Value.Metadata(_httpResponse),
                        _responseMetadata = Value.Metadata(_response),
                        _shouldRetry = try Function.Invoke(_retryFn, {_response, _responseMetadata}) otherwise false,
                        _retryResult = if _shouldRetry = true then null else _response
                    in
                        _retryResult,
                (retryNum as number) as duration =>
                    if retryNum > 1 then
                        #duration(0, 0, 0, _retryDelay)
                    else
                        #duration(0, 0, 0, 0),
                _retryCount / 2
                // Divide the retries count by 2 because PowerBI will restart the whole polling flow once again after it gets the "Query Timeout" error (see _getResponseFn)
            )
        in
            _result,
    this.validateResponse = (response as binary, optional onFailure as nullable function) as record =>
        let
            _metaData = Value.Metadata(response),
            _json = Json.Document(response),
            _result =
                if List.Contains(this.manualStatusCodesHandling, _metaData[Response.Status]) then
                    error this.getError(this.execFunc(onFailure, _json))
                else
                    _json
        in
            _result,
    // Returns error record based on the response from API
    this.getError = (response as record) as record =>
        let
            _message = try response[error][message] otherwise "Unknown Error",
            _description = try response[error][description] otherwise null,
            _startError = Error.Record(_message, _description),
            _errorWithTracking = (eventTracking) => _startError,
            _eventTracking = Tracking[ServerError](_message),
            _result = _errorWithTracking(_eventTracking)
        in
            _result,
    // Main function
    this.call = (
        endpoint as text, queryParams as record, body as nullable text, optional handlers as nullable record
    ) as record =>
        let
            _onStartResult = this.execFunc(try handlers[OnStart] otherwise null, []),
            _getResponseFn =
            // A workaround to make an external API call without actually referencing it's result
            (onStartResult) =>
                let
                    _responseAfterRetries = this.getResponse(endpoint, queryParams, body),
                    _fnResult =
                        if _responseAfterRetries = null then
                            (
                                (onFailureEvent) =>
                                    error
                                        Error.Record(
                                            "Query timeout",
                                            "Unable to get the query data within the allowed time. Please try again later."
                                        )
                            )(Tracking[QueryGetDataTimeout]())
                        else
                            _responseAfterRetries
                in
                    _fnResult,
            _json = this.validateResponse(_getResponseFn(_onStartResult), try handlers[OnFailure] otherwise null),
            _result = this.execFunc(try handlers[OnSuccess] otherwise null, _json)
        in
            _result
in
    [
        Get = (endpoint as text, queryParams as record, optional handlers as nullable record) as record =>
            this.call(endpoint, queryParams, null, handlers),
        Post = (endpoint as text, body as nullable text, queryParams as record, optional handlers as nullable record) as record =>
            this.call(endpoint, queryParams, if body <> null then body else "", handlers)
    ]
;


Tracking = let
    this.validateUrlScheme = (url as text) as text =>
        if (Uri.Parts(url)[Scheme] <> "https") then
            error "Url scheme must be HTTPS"
        else
            url,
    this.addTrackingEvent = (eventCategory as text, eventAction as text) as any =>
        let
            _event = [
                eventCategory = eventCategory,
                eventAction = eventAction
            ],
            _body = Text.FromBinary(Json.FromValue([
                events = {_event}
            ])),
            _response = Web.Contents(
                this.validateUrlScheme(Urls[TrackingAdd]),
                [
                    Content = Text.ToBinary(_body),
                    Headers = [
                        #"Content-Type" = "application/json",
                        #"Authorization" = "Bearer " & Extension.CurrentCredential()[access_token],
                        #"X-Pbi-Connector-Version" = ConnectorVersion
                    ],
                    ManualStatusHandling = {400, 401, 403, 404, 500}
                ]
            ),
            _result = Json.Document(_response)
        in
            _result,
    this.navigatorStart = () => this.addTrackingEvent("navigator", "navigator_start"),
    this.navigatorLoaded = () => this.addTrackingEvent("navigator", "navigator_loaded"),
    this.navigatorRendered = () => this.addTrackingEvent("navigator", "navigator_rendered"),
    this.navigatorError = () => this.addTrackingEvent("navigator", "navigator_error"),
    this.navigatorLoadedWithoutConnections = () => this.addTrackingEvent("navigator", "navigator_loaded_without_connections"),
    this.queryGetDataStart = (queryPath as text) =>
        this.addTrackingEvent("query", "query_get_data_start " & queryPath),
    this.queryGetDataLoaded = () => this.addTrackingEvent("query", "query_get_data_loaded"),
    this.queryGetDataError = () => this.addTrackingEvent("query", "query_get_data_error"),
    this.queryGetDataTimeout = () => this.addTrackingEvent("query", "query_get_data_timeout"),
    this.serverError = (optional message as text) => this.addTrackingEvent("powerbi_error", message)
in
    [
        NavigatorStart = this.navigatorStart,
        NavigatorLoaded = this.navigatorLoaded,
        NavigatorRendered = this.navigatorRendered,
        NavigatorError = this.navigatorError,
        NavigatorLoadedWithoutConnections = this.navigatorLoadedWithoutConnections,
        QueryGetDataStart = this.queryGetDataStart,
        QueryGetDataLoaded = this.queryGetDataLoaded,
        QueryGetDataError = this.queryGetDataError,
        QueryGetDataTimeout = this.queryGetDataTimeout,
        ServerError = this.serverError
    ]
;


Types = let
    this.textTypeBuilder = (title as text, sampleValues as list, description as text) as type =>
        Text.Type meta [
            Documentation.FieldCaption = title,
            Documentation.SampleValues = sampleValues,
            Documentation.FieldDescription = description
        ],
    this.dateTypeBuilder = (title as text, sampleValue as text) as type =>
        Date.Type meta [
            Documentation.FieldDescription = "Date in format yyyy-MM-dd",
            Documentation.SampleValues = {sampleValue},
            Documentation.FieldCaption = title
        ],
    this.allowedValuesBuilderSingle = (allowedValues as list, title as text, description as text) as type =>
        Text.Type meta [
            Documentation.FieldCaption = title,
            Documentation.FieldDescription = description,
            Documentation.AllowedValues = allowedValues
        ],
    this.allowedValuesBuilderMultiple = (allowedValues as list, title as text, description as text) as type =>
        List.Type meta [
            Documentation.FieldCaption = title,
            Documentation.FieldDescription = description,
            Documentation.AllowedValues = allowedValues
        ],
    this.dateRangeTypeBuilder = () as type =>
        this.allowedValuesBuilderSingle(
            Dates[DateRangeTypes],
            "Date range type",
            "Date range for the query. See https://supermetrics.com/docs/product-api-enum-date-range-type/"
        ),
    this.startDateBuilder = (storedQueryParams as record) as type =>
        this.dateTypeBuilder("Start date. Default: " & storedQueryParams[start_date], "2022-01-01"),
    this.endDateBuilder = (storedQueryParams as record) as type =>
        this.dateTypeBuilder("End date. Default: " & storedQueryParams[end_date], "2022-01-02"),
    this.connectionAccountsDropdownBuilder = (connectionAccounts as list) as type =>
        this.allowedValuesBuilderMultiple(
            List.Transform(
                connectionAccounts, (connectionAccount as record) as text => connectionAccount[account_name]
            ),
            "Connection - Account",
            "Account description"
        ),
    this.metricsDropdownBuilder = (metrics as list) as type =>
        this.allowedValuesBuilderMultiple(
                List.Transform(
                    metrics, (metric as record) as text => metric[display_name]
                ),
                "Metrics",
                "Metric description"
            )
    ,
    this.dimensionsDropdownBuilder = (dimensions as list) as type =>
        this.allowedValuesBuilderMultiple(
                List.Transform(
                    dimensions, (dimension as record) as text => dimension[display_name]
                ),
                "Split by",
                "Split by description"
            )
    ,
    this.profileTextInputBuilder = (accountsLabel as text) as type =>
        this.textTypeBuilder(accountsLabel, {"Supermetrics"}, "Profile ID to use in the query"),

    this.queryTableTypeWithAccounts = (
            connectionAccounts as list, 
            metrics as list,
            dimensions as list
        ) as type =>
            type function (
                optional selectedConnectionAccounts as this.connectionAccountsDropdownBuilder(connectionAccounts),
                optional dateRangeType as this.dateRangeTypeBuilder(),
                optional metrics as this.metricsDropdownBuilder(metrics),
                optional dimensions as this.dimensionsDropdownBuilder(dimensions)
                // optional startDate as this.startDateBuilder(storedQueryParams),
                // optional endDate as this.endDateBuilder(storedQueryParams)
            ) as table,
    this.queryTableTypeWithAccountsNoOptions = (connectionAccounts as list) as type =>
            type function (
                optional selectedConnectionAccounts as this.connectionAccountsDropdownBuilder(connectionAccounts),
                optional dateRangeType as this.dateRangeTypeBuilder()
            ) as table,
    this.queryTableTypeWithProfile = (accountsLabel as text) as type =>
        type function (
            optional userProfileId as this.profileTextInputBuilder(accountsLabel),
            optional dateRangeType as this.dateRangeTypeBuilder()
            // optional startDate as this.startDateBuilder(storedQueryParams),
            // optional endDate as this.endDateBuilder(storedQueryParams)
        ) as table,
    this.queryTableTypeWithMetricsAndDimensions = (
            metrics as list,
            dimensions as list
        ) as type =>
            type function (
                optional dateRangeType as this.dateRangeTypeBuilder(),
                optional metrics as this.metricsDropdownBuilder(metrics),
                optional dimensions as this.dimensionsDropdownBuilder(dimensions)
                // optional startDate as this.startDateBuilder(storedQueryParams),
                // optional endDate as this.endDateBuilder(storedQueryParams)
            ) as table
in
    [
        QueryTableWithAccounts = this.queryTableTypeWithAccounts,
        QueryTableWithProfile = this.queryTableTypeWithProfile,
        QueryTableWithAccountsNoOptions = this.queryTableTypeWithAccountsNoOptions,
        QueryTableWithMetricsAndDimensions = this.queryTableTypeWithMetricsAndDimensions
    ]
;


SupermetricsClient = let
    this.scheduleQuery = (queryParams as record) as record =>
        let
            _clusterUrl = this.getClusterUrl(),
            _url = Text.Combine({"https:/", _clusterUrl, Urls[Enterprise], "query/data/pbijson"}, "/"),
            _queryParamsWithSync0 = Record.AddField(queryParams, "sync", 0),
            // TODO: Add offset_start and offset_end
            _result = HttpClient[Post](_url, Text.FromBinary(Json.FromValue(_queryParamsWithSync0)), [], [])[meta]
        in
            _result,
    this.getQueryStatus = (scheduleId as text) as text =>
        let
            _clusterUrl = this.getClusterUrl(),
            _url = Text.Combine({"https:/", _clusterUrl, Urls[Enterprise], "query/status"}, "/"),
            _queryParams = [
                #"schedule_id" = scheduleId
            ],
            _result = HttpClient[Get](_url, _queryParams, [])[meta][status_code]
        in
            _result,
    this.getQueryResults = (scheduleId as text) as record =>
        let
            _clusterUrl = this.getClusterUrl(),
            _url = Text.Combine({"https:/", _clusterUrl, Urls[Enterprise], "query/results"}, "/"),
            _result = HttpClient[Get](_url, [#"schedule_id" = scheduleId], [])
        in
            _result,
    this.getQueryResults2 = (queryParams as record, optional newSchedule as logical) as record =>
        let
            _scheduleResponse = if (newSchedule = null or newSchedule = true) then this.scheduleQuery(queryParams) else
                [],
            _statusBuilder = (scheduleResponse as record) as text => this.getQueryStatus(queryParams[schedule_id]),
            _status = _statusBuilder(_scheduleResponse),
            _needWaitForResults = List.Contains({"SCHEDULED", "QUEUED", "RUNNING"}, _status),
            _queryIsReady = Value.Equals(_status, "SUCCESS"),
            _queryFailure = Value.Equals(_status, "FAILURE"),
            _queryStopped = Value.Equals(_status, "STOPPED")
        in
            if (_needWaitForResults = true) then
                Function.InvokeAfter(() => @this.getQueryResults2(queryParams, false), #duration(0, 0, 0, 5))
            else if (_queryIsReady = true) then
                this.getQueryResults(queryParams[schedule_id])
            else if (_queryFailure = true) then
                Error.Record("Query failure")
            else if (_queryStopped = true) then
                Error.Record("Query stopped")
            else
                Error.Record("Unknown error"),
    // Will always return false but we have to request that endpoint without token to raise the authorization dialog
    this.raiseAuthorizationDialog = () as logical =>
        Record.HasFields(
            Json.Document(
                Web.Contents(Urls[Profile], [
                    Headers = [
                        #"Authorization" = "Bearer 0"
                    ],
                    ManualCredentials = true
                ])
            ),
            "meta"
        ),
    this.getClusterUrl = () as text =>
        let
            _teamId = this.getProfile()[team_id],
            _response = HttpClient[Get](
                Urls[Cluster], [
                    #"product_id" = "PBI",
                    #"team_id" = Number.ToText(_teamId)
                ], []
            )
        in
            _response[data][api_url],
    this.getProfile = () as record => HttpClient[Get](Urls[Profile], [], [])[data][team_info],
    this.getTeams = () as list => HttpClient[Get](Urls[Teams], [], [])[data][teams],
    this.getLogins = () as list => HttpClient[Get](Urls[DsLogins], [], [])[data],
    this.getQueries = () as list => HttpClient[Get](Urls[Queries], [], [])[data],
    this.getQueryDetails = (query_id as text) as record =>
        let
            _clusterUrl = this.getClusterUrl(),
            _url = Text.Combine({"https:/", _clusterUrl, Urls[Enterprise], "query", query_id}, "/"),
            _result = HttpClient[Get](_url, [], [])[data]
        in
            _result,
    this.getStandardSchemasQueries = () as list => HttpClient[Get](Urls[StandardSchemasQueries], [], [])[data],
    this.getStandardSchemasQueryDetails = (query_id as text) as record =>
        let
            _clusterUrl = this.getClusterUrl(),
            _url = Text.Combine({"https:/", _clusterUrl, Urls[Enterprise], "integration/powerbi/standardschemas", query_id}, "/"),
            _result = HttpClient[Get](_url, [], [])[data]
        in
            _result,
    this.getAccounts = (login_id as text) as list =>
        let
            _url = Text.Combine({Urls[DsLoginAccounts], login_id, "accounts"}, "/"),
            _result = HttpClient[Get](_url, [], [])[data]
        in
            _result,
    this.getAccountsWithAliases = (
        login_id as text, 
        displayName as text
    ) as list =>
        List.Transform(
            this.getAccounts(login_id),
            (accountInfo as record) as record =>
                [
                    account_id = accountInfo[account_id],
                    account_name = displayName & " - " & accountInfo[name]
                ]
        ),
    this.refreshDataSourceAccounts = (dataSourceId as text) as logical =>
        let
            _postBody = Uri.BuildQueryString([
                #"data_source_id" = dataSourceId
            ]) meta [
                headers = [
                    #"Content-Type" = "application/x-www-form-urlencoded"
                ]
            ],
            _result = HttpClient[Post](Urls[TeamAccountsRefresh], _postBody, [], [])[data][result]
        in
            _result,

    this.prepareAccounts = (dsAccounts as text) as text => 
        let
            splitList = Text.Split(dsAccounts, ","),
            transformedList = List.Transform(splitList, each "ds_accounts[]=" & _),
            resultString = Text.Combine(transformedList, "&")
        in
            resultString
    ,
    this.prepareUsers = (dsUsers as text) as text => 
        let
            splitList = Text.Split(dsUsers, ","),
            transformedList = List.Transform(splitList, each "ds_users[]=" & _),
            resultString = Text.Combine(transformedList, "&")
        in
            resultString
    ,
    this.getDataSourceConfig = (queryInfo as record) as record =>
        let
            _dsAccounts = try queryInfo[query_params][ds_accounts] otherwise "",
            _dsUsers = try queryInfo[query_params][ds_user] otherwise "",
            _url = Text.Combine({Urls[DataSource], queryInfo[ds_info][ds_id], "config?"}, "/"),
            
            _parameters = let
                _accountsParameter = if _dsAccounts <> "" then
                        this.prepareAccounts(_dsAccounts)
                    else
                        "",
                _usersParameters = if _dsUsers <> "" then
                        this.prepareUsers(_dsUsers)
                    else
                        "",
                _result = if _accountsParameter <> "" and _usersParameters <> "" then
                        _accountsParameter & "&" & _usersParameters
                    else if _accountsParameter <> "" then
                        _accountsParameter
                    else if _usersParameters <> "" then
                        _usersParameters
                    else 
                        ""
            in
                _result,

            _urlWithParameters = _url & _parameters,
            _result = HttpClient[Get](_urlWithParameters, [], [])[data]
        in
            _result
in
    [
        GetQueryResults = this.getQueryResults2,
        RaiseAuthorizationDialog = this.raiseAuthorizationDialog,
        GetClusterUrl = this.getClusterUrl,
        GetProfile = this.getProfile,
        GetTeams = this.getTeams,
        GetQueries = this.getQueries,
        GetLogins = this.getLogins,
        GetQueryDetails = this.getQueryDetails,
        GetAccounts = this.getAccountsWithAliases,
        RefreshDataSourceAccounts = this.refreshDataSourceAccounts,
        GetDataSourceConfig = this.getDataSourceConfig,
        GetStandardSchemasQueries = this.getStandardSchemasQueries,
        GetStandardSchemasQueryDetails = this.getStandardSchemasQueryDetails
    ]
;


GettingStarted = let
     this.getGettingStartedInstructions = () as list => 
        let
            local_suffix =
            if  (Text.Contains(Urls[ApiBase], "ismtip")) then
                " (DEV)"
            else
                "",
            _remoteData = HttpClient[Get](Urls[GettingStarted], [], [])[data],
            _versionInfo = [
                #"step" = "",
                #"description" = "Version number: " & ConnectorVersion & local_suffix
            ],
            _result = List.Combine({_remoteData, {_versionInfo}})
        in
            _result,
    this.getRenameHeaders = (Source) as table => 
        let
            _result = Table.RenameColumns(
                Source, 
                {
                    {"step", ""},
                    {"description", "Get started with Supermetrics by following the instructions below"}
                },
                MissingField.Ignore
            )
        in
            _result,
    _instructions = 
    [
                #"id" = "getting-started",
                #"label" = "- Instructions",
                #"items" = this.getRenameHeaders(
                    Table.FromRecords(
                        this.getGettingStartedInstructions(), 
                        type table [
                            #"step" = text, 
                            #"description" = text
                        ]
                    )
                ),
                #"type" = "Table",
                #"icon" = "Subcube",
                #"leaf" = true
    ],
    _campaignLast30Days = [
        #"id" = "campaign-performance-last-30-days",
        #"label" = "Demo: Campaign performance",
        #"items" = Table.FromRows(
            {
                {"Boost Branding", 23715, 600, 8236},
                {"Elevate Marketing", 31587, 774, 5204},
                {"Transform Business", 28840, 738, 5961},
                {"Unleash Potential", 18029, 432, 12251}
            },
            type table [
                #"Campaign name" = text,
                #"Impressions" = number,
                #"Clicks" = number,
                #"Cost" = number
            ]
        ),
        #"type" = "Table",
        #"icon" = "Subcube",
        #"leaf" = true
    ],
    _campaignPerformanceLastYearMonth = [
        #"id" = "campaign-performance-last-year-by-month",
        #"label" = "Demo:  Campaign by month",
        #"items" = Table.FromRows(
            {
                {"Boost Branding", "January", 8007, 481, 1248},
                {"Boost Branding", "March", 14598, 730, 685},
                {"Boost Branding", "March", 7382, 296, 1352},
                {"Boost Branding", "April", 4186, 126, 2381},
                {"Boost Branding", "May", 3739, 75, 2667},
                {"Boost Branding", "June", 2056, 21, 4762},
                {"Boost Branding", "July", 4225, 423, 2365},
                {"Boost Branding", "August", 2605, 27, 3704},
                {"Boost Branding", "September", 9783, 196, 1021},
                {"Boost Branding", "October", 9579, 288, 1042},
                {"Boost Branding", "November", 10301, 413, 969},
                {"Boost Branding", "December", 10906, 546, 916},
                {"Elevate Marketing", "January", 28209, 2539, 355},
                {"Elevate Marketing", "March", 4276, 343, 2333},
                {"Elevate Marketing", "March", 7896, 553, 1266},
                {"Elevate Marketing", "April", 29462, 1768, 340},
                {"Elevate Marketing", "May", 23369, 1169, 428},
                {"Elevate Marketing", "June", 13158, 527, 760},
                {"Elevate Marketing", "July", 12154, 365, 822},
                {"Elevate Marketing", "August", 19602, 785, 510},
                {"Elevate Marketing", "September", 22135, 1107, 452},
                {"Elevate Marketing", "October", 16719, 1004, 598},
                {"Elevate Marketing", "November", 32452, 2272, 309},
                {"Elevate Marketing", "December", 36941, 2956, 271},
                {"Transform Business", "January", 10404, 1249, 961},
                {"Transform Business", "March", 10065, 1108, 993},
                {"Transform Business", "March", 13664, 1367, 732},
                {"Transform Business", "April", 17241, 1552, 580},
                {"Transform Business", "May", 23054, 1845, 434},
                {"Transform Business", "June", 31496, 2205, 318},
                {"Transform Business", "July", 3791, 228, 2632},
                {"Transform Business", "August", 28204, 1975, 355},
                {"Transform Business", "September", 29532, 2363, 339},
                {"Transform Business", "October", 38744, 3487, 259},
                {"Transform Business", "November", 31690, 3169, 316},
                {"Transform Business", "December", 3772, 415, 2651},
                {"Unleash Potential", "January", 1653, 248, 6049},
                {"Unleash Potential", "March", 41905, 5867, 239},
                {"Unleash Potential", "March", 63069, 8199, 159},
                {"Unleash Potential", "April", 40428, 4852, 248},
                {"Unleash Potential", "May", 26087, 2870, 384},
                {"Unleash Potential", "June", 43094, 4310, 233},
                {"Unleash Potential", "July", 42117, 3791, 238},
                {"Unleash Potential", "August", 33409, 3341, 300},
                {"Unleash Potential", "September", 10434, 1148, 959},
                {"Unleash Potential", "October", 19379, 2326, 516},
                {"Unleash Potential", "November", 16300, 2119, 614},
                {"Unleash Potential", "December", 22105, 3095, 453}
            },
            type table [
                #"Campaign name" = text,
                #"Month name" = text,
                #"Impressions" = number,
                #"Clicks" = number,
                #"Cost" = number
            ]
        ),
        #"type" = "Table",
        #"icon" = "Subcube",
        #"leaf" = true
    ],
    _campaignPerformanceLast30Days = [
        #"id" = "campaign-performance-last-30-days-by-country",
        #"label" = "Demo:  Campaign by country",
        #"items" = Table.FromRows(
            {
                {"Boost Branding", "United States", 4843, 146, 2055},
                {"Boost Branding", "Germany", 7436, 224, 1340},
                {"Boost Branding", "United Kingdom", 8769, 176, 1137},
                {"Boost Branding", "Spain", 2667, 54, 3704},
                {"Elevate Marketing", "United States", 8032, 241, 1245},
                {"Elevate Marketing", "Germany", 5974, 180, 1667},
                {"Elevate Marketing", "United Kingdom", 9713, 195, 1026},
                {"Elevate Marketing", "Spain", 7868, 158, 1266},
                {"Transform Business", "United States", 5634, 170, 1765},
                {"Transform Business", "Germany", 10290, 309, 971},
                {"Transform Business", "United Kingdom", 5143, 103, 1942},
                {"Transform Business", "Spain", 7773, 156, 1283},
                {"Unleash Potential", "United States", 1755, 53, 5661},
                {"Unleash Potential", "Germany", 5163, 155, 1936},
                {"Unleash Potential", "United Kingdom", 2858, 58, 3449},
                {"Unleash Potential", "Spain", 8253, 166, 1205}
            },
            type table [
                #"Campaign name" = text,
                #"Country" = text,
                #"Impressions" = number,
                #"Clicks" = number,
                #"Cost" = number
            ]
        ),
        #"type" = "Table",
        #"icon" = "Subcube",
        #"leaf" = true
    ],
    _records = Table.FromRecords({
            _instructions,
            /*_campaignLast30Days,
            _campaignPerformanceLastYearMonth,*/
            _campaignPerformanceLast30Days
        },
        {
            "id", 
            "label", 
            "items", 
            "icon",
            "type",
            "leaf"
        }
    ),
    _navigationTable = Table.ToNavigationTable(
        _records,
        {"id"},
        "label",
        "items",
        "icon",
        "",
        "leaf"
    ), 
    this.gettingStarted = Table.FromRecords(
        {
            [
                #"id" = "getting-started",
                #"label" = "Getting Started",
                #"items" = _navigationTable,
                #"type" = "Function",
                #"icon" = "Sheet",
                #"leaf" = false
            ]
        },
        {
            "id", 
            "label", 
            "items", 
            "icon", 
            "type", 
            "leaf"
        }
    )
in
    [
        Table = this.gettingStarted
    ]
;


Instructions = let
this.createNavigationTable = (instructions as table) as table =>
    let
        _navigationTable = Table.ToNavigationTable(
                instructions
                ,
                {"id"},
                "label",
                "items",
                "icon",
                "",
                "leaf"
            ),
        _result = Table.FromRecords(
                {
                    [
                        #"id" = "my-empty-connections",
                        #"label" = "My Queries",
                        #"items" = _navigationTable,
                        #"type" = "Function",
                        #"icon" = "Dimension",
                        #"leaf" = false
                    ]
                },
                {
                    "id", 
                    "label", 
                    "items", 
                    "icon", 
                    "type", 
                    "leaf"
                }
            )
    in
        _result
    ,
    this.noConnectionInstructions = () as table => 
        let 
            _instructions = Table.FromRecords({
                [
                    #"id" = "no-connections-found",
                    #"label" = "Please connect your data sources",
                    #"items" = Table.FromRows(
                        {
                            {"Please go to https://hub.supermetrics.com/power-bi"},
                            {"to connect your data sources and add queries."}
                        },
                        type table [
                            #"Please connect your data sources" = text
                        ]
                    ),
                    #"type" = "Table",
                    #"icon" = "Sheet",
                    #"leaf" = true
                ]},
                {
                    "id", 
                    "label", 
                    "items", 
                    "icon",
                    "type",
                    "leaf"
                }
            ),
            _result = this.createNavigationTable(_instructions)
                
        in
            _result,
    this.noConnectionsForQueries = () as table => 
        let 
            _instructions = Table.FromRecords({
                [
                    #"id" = "no-queries-found",
                    #"label" = "Please save at least one query",
                    #"items" = Table.FromRows(
                        {
                            {"Please go to https://hub.supermetrics.com/power-bi."},
                            {"and save at least one query to load the data to Power BI"}
                        },
                        type table [
                            #"Please save at least one query" = text
                        ]
                    ),
                    #"type" = "Table",
                    #"icon" = "Sheet",
                    #"leaf" = true
                ]},
                {
                    "id", 
                    "label", 
                    "items", 
                    "icon",
                    "type",
                    "leaf"
                }
            ),
            _result = this.createNavigationTable(_instructions)
        in
            _result
in
    [
        NoConnections = this.noConnectionInstructions,
        NoConnectionsForQueries = this.noConnectionsForQueries
    ];


Tools = let
    this.switchTeamFnType = (teams as list) as type =>
        type function (
            selectedAction as (
                Text.Type meta [
                    Documentation.FieldCaption = "Switch team",
                    Documentation.FieldDescription = "Select a value",
                    Documentation.AllowedValues = teams
                ]
            )
        ) as table,
    this.switchTeamHandler = (selectedTeamName as any) as table =>
        let
            _currentProfile = SupermetricsClient[GetProfile](),
            _instructionsTableGenerator = (auth as any) as table =>
                Table.FromRecords({[Result = "You've switched the team. Please reload the navigator"]}),
            // On the Apply - check if the selected team equals to the current one and raise the auth dialog
            _auth =
                if (Value.Equals(selectedTeamName, _currentProfile[name]) <> true) then
                    SupermetricsClient[RaiseAuthorizationDialog]()
                else
                    null
        in
            _instructionsTableGenerator(_auth),
    this.refreshAccountsFnType = (dataSources as list) as type =>
        type function (
            selectedValue as (
                Text.Type meta [
                    Documentation.FieldCaption = "Refresh accounts",
                    Documentation.FieldDescription = "Select a value",
                    Documentation.AllowedValues = dataSources
                ]
            )
        ) as table,
    this.refreshAccountsHandler = (selectedDataSource as text, datasources as list) as table =>
        let
            _selected = List.First(
                List.Select(
                    datasources,
                    (datasource as record) as logical =>
                        Value.Equals(datasource[ds_name], selectedDataSource)
                )
            ),
            _response = SupermetricsClient[RefreshDataSourceAccounts](_selected[ds_id]),
            _resultBuilder = (refreshResult as logical) as table =>
                if (refreshResult = true) then
                    Table.FromRecords({[Result = "Accounts have been refreshed. Please reload the connector"]})
                else
                    Table.FromRecords({[Result = "Failed to refresh accounts"]})
        in
            _resultBuilder(_response),
    this.getNavigationToolsTable = () =>
        let
            _currentProfile = SupermetricsClient[GetProfile](),
            _queries = SupermetricsClient[GetQueries](),
            _dataSources = List.Transform(
                _queries,
                (queryInfo as record) as record =>
                    [
                        #"ds_id" = queryInfo[ds_info][ds_id],
                        #"ds_name" = queryInfo[ds_info][name]
                    ]
            ),
            _dataSourcesLabel = List.Transform(
                _queries,
                (queryInfo as record) as text =>
                    queryInfo[ds_info][name] meta [
                        Documentation.Name = queryInfo[ds_info][name]
                    ]
            ),
            _teams = SupermetricsClient[GetTeams](),
            _teamsList =  List.Transform(_teams, each _[name]),
            _tableRecords = Table.FromRecords(
                {
                    [
                        #"id" = "tools",
                        #"label" = "Tools",
                        #"items" = Table.ToNavigationTable(
                            Table.FromRecords(
                                {
                                    /*[
                                        #"id" = "switch-team",
                                        #"label" = "Switch team",
                                        #"items" = Value.ReplaceType(
                                            (selectedTeamName as text) as table =>
                                                this.switchTeamHandler(selectedTeamName),
                                            this.switchTeamFnType(_teamsList)
                                        ),
                                        #"icon" = "CubeViewFolder",
                                        #"type" = "Function",
                                        #"leaf" = true
                                    ],*/
                                    [
                                        #"id" = "refresh-accounts",
                                        #"label" = "Refresh accounts",
                                        #"items" = Value.ReplaceType(
                                            (selectedValue as text) as table =>
                                                this.refreshAccountsHandler(selectedValue, _dataSources),
                                            this.refreshAccountsFnType(_dataSourcesLabel)
                                        ),
                                        #"icon" = "CubeViewFolder",
                                        #"type" = "Function",
                                        #"leaf" = true
                                    ]
                                },
                                {"id", "label", "items", "icon", "type", "leaf"}
                            ),
                            {"id"},
                            "label",
                            "items",
                            "icon",
                            "",
                            "leaf"
                        ),
                        #"icon" = "Function",
                        #"type" = "Table",
                        #"leaf" = false
                    ]
                },
                {"id", "label", "items", "icon", "type", "leaf"}
            )
        in
            _tableRecords
in
    [
        GetNavigationToolsTable = this.getNavigationToolsTable
    ]
;


Dates = let
    this.dateRangeTypes = {
        // "custom" meta [
        //     Documentation.Name = "Relative or fixed date range that is provided via parameters start_date and end_date."
        // ],
        "Today" meta [
            Documentation.Name = "Today",
            Value = "today"
        ],
        "Yesterday" meta [
            Documentation.Name = "Yesterday",
            Value = "yesterday"
        ],
        "Last week (Sun-Sat)" meta [
            Documentation.Name = "Last full week from Sunday to Saturday",
            Value = "last_week_sun_sat"
        ],
        "Last week (Mon-Sun)" meta [
            Documentation.Name = "Last full week from Monday to Sunday",
            Value = "last_week_mon_sun"
        ],
        "This month to date" meta [
            Documentation.Name = "Current month including today",
            Value = "this_month_inc"
        ],
        "This month" meta [
            Documentation.Name = "Current month until yesterday, or last month for 1st of month",
            Value = "this_month"
        ],
        "Last month" meta [
            Documentation.Name = "Last full month",
            Value = "last_month"
        ],
        "Last 3 months" meta [
            Documentation.Name = "Last Three months",
            Value = "last_3_months"
        ],
        "Last 6 months" meta [
            Documentation.Name = "Last Six months",
            Value = "last_6_months"
        ],
        "Year to date" meta [
            Documentation.Name = "Current year until today",
            Value = "this_year_inc"
        ],
        "Last year" meta [
            Documentation.Name = "Last full year",
            Value = "last_year"
        ],
        "Last year & this year to date" meta [
            Documentation.Name = "Last year until today, including current year",
            Value = "last_year_inc"
        ]
    },
    this.findDateRangeTypesFromText = (selectedDateRangeType as text) =>
        List.Select(
            this.dateRangeTypes,
            (dateRangeType as text) as logical => Value.Equals(dateRangeType, selectedDateRangeType)
        ),
    this.getDateRangeTypeFromText = (selectedDateRangeType as text, optional defaultDateRangeType as text) as text =>
        let
            _dateRangeTypes = this.findDateRangeTypesFromText(selectedDateRangeType),
            _dateRangeType = if (List.Count(_dateRangeTypes) = 0) then null else _dateRangeTypes{0},
            _result = if (_dateRangeType = null) then defaultDateRangeType else Value.Metadata(_dateRangeType)[
                Value
            ]
        in
            _result
in
    [
        DateRangeTypes = this.dateRangeTypes,
        GetDateRangeTypeFromText = this.getDateRangeTypeFromText
    ]
;




Navigation = let
    this.getQueryResultsAsTable = (queryParams as record) as table =>
        let
            _responseStart = SupermetricsClient[GetQueryResults](queryParams),
            _responseWithEvent = (eventResponse) => _responseStart,
            _responseStartEvent =
                try 
                    Tracking[QueryGetDataStart](queryParams[schedule_id])
                otherwise
                    Tracking[QueryGetDataError]()
                ,
            _response = _responseWithEvent(_responseStartEvent),

            _result = try
                    let 
                        _columnsDefs = Table.GetTableSchema(_response[meta][headers]),
                        _table = Table.FromRows(_response[data], List.Transform(_columnsDefs, (columnDef) => columnDef{0})),
                        _resultWithoutEvent = Table.TransformColumnTypes(_table, _columnsDefs),
                        _resultWithEvent = (eventResponse) => _resultWithoutEvent,
                        _getDataLoadedEventResponse = Tracking[QueryGetDataLoaded](),
                        _dataResult = _resultWithEvent(_getDataLoadedEventResponse)
                    in 
                        _dataResult
                otherwise
                    if (_response[error]? <> null) then
                        error Error.Record(_response[error], _response[description]?)
                    else
                        error "Empty response"
        in
            _result,
    this.getDateRangeType = (queryDetails as record, selectedDateRangeType as nullable text) =>
        let
            _startDate = try queryDetails[query_params][start_date] otherwise null,
            _endDate   = try queryDetails[query_params][end_date] otherwise null,
            _result = if (selectedDateRangeType = null and _startDate <> null and _endDate <> null ) then
                [
                    #"start_date" = _startDate,
                    #"end_date"   = _endDate
                ]
            else if (selectedDateRangeType <> null) then
                let 
                    _oldDateRange = try queryDetails[query_params][date_range_type] otherwise null,     
                    _dateRangeType = Dates[GetDateRangeTypeFromText](selectedDateRangeType, _oldDateRange),
                    _result = [
                        #"date_range_type" = _dateRangeType
                    ]
                in
                    _result
            else
                []
        in
            _result,
    this.getQueryDetails = (queryInfo as record) as record =>
        let
            _queryDetailsRemote = SupermetricsClient[GetQueryDetails](queryInfo[query_id]),
            _queryDetailsStandard = SupermetricsClient[GetStandardSchemasQueryDetails](queryInfo[query_id]),
            _result = if (queryInfo[group_info][name] = "STANDARD") then 
                _queryDetailsStandard 
            else 
                _queryDetailsRemote
        in
            _result,
    this.getFirstConnectionAccountFromQuery = (accounts as list) as text =>
        List.First(accounts)[account_id]
    ,
    this.dataTableWithOptionsBuilder = (
            queryInfo as record, 
            datasourceConfig as record, 
            accounts as list
        ) => 
        Value.ReplaceType(
            (
                optional selectedConnectionAccounts as list, 
                optional selectedDateRangeType as text,
                optional selectedMetrics as list,
                optional selectedDimensions as list
            ) as table =>
                let
                    _queryDetails = this.getQueryDetails(queryInfo),
                    _queryParams = _queryDetails[query_params],
                    _allowedMetrics = datasourceConfig[metrics],
                    _allowedDimensions = datasourceConfig[dimensions],
                    _initialFields = _queryParams[fields],
                    _userAccounts =
                        if (selectedConnectionAccounts <> null) then
                            [
                                #"ds_accounts" = List.Transform(
                                    List.Select(
                                        accounts,
                                        (connectionAccount as record) =>
                                            List.Contains(
                                                selectedConnectionAccounts, 
                                                connectionAccount[account_name],
                                                Comparer.OrdinalIgnoreCase
                                            ) = true
                                    ),
                                    (selectedConnectionAccount as record) as text =>
                                        selectedConnectionAccount[account_id]
                                )
                            ]
                        else if (queryInfo[group_info][name] = "STANDARD" and selectedConnectionAccounts = null) then
                            [
                                #"ds_accounts" = this.getFirstConnectionAccountFromQuery(accounts)
                            ]
                        else 
                            [],
                    _metrics = if (selectedMetrics <> null) then
                            List.Transform(
                                List.Select(
                                    _allowedMetrics,
                                    (metric as record) =>
                                        List.Contains(
                                            selectedMetrics, 
                                            metric[display_name],
                                            Comparer.OrdinalIgnoreCase
                                        ) = true
                                ),
                                (metric as record) as text =>
                                    metric[name]
                            )
                        else
                            {},
                    _dimensions = if (selectedDimensions <> null) then
                            List.Transform(
                                List.Select(
                                    _allowedDimensions,
                                    (dimension as record) =>
                                        List.Contains(
                                            selectedDimensions, 
                                            dimension[display_name],
                                            Comparer.OrdinalIgnoreCase
                                        ) = true
                                ),
                                (dimension as record) as text =>
                                    dimension[name]
                            )
                        else
                            {},
                    _dateRangeType = this.getDateRangeType(_queryDetails, selectedDateRangeType),
                    // convert metrics and dimensions into fields
                    _combinedFields = List.Combine({_metrics, _dimensions}),
                    // when using "Split by" in QM, "fields" are multidimensional array instead of array of strings
                    _fields = if (List.Count(_combinedFields) > 0) then 
                            [
                                #"fields" = _combinedFields
                            ]
                        else 
                                if (Value.Is(_initialFields, type text)) then
                                [
                                    #"fields" = Text.Split(_initialFields, ",")
                                ]
                                else
                                [
                                    #"fields" = _initialFields
                                ],
                    _params = Record.Combine({@_queryParams, _dateRangeType, _userAccounts, _fields}),
                    _result = this.getQueryResultsAsTable(_params)
                in
                    _result,
            Types[QueryTableWithAccounts](accounts, datasourceConfig[metrics], datasourceConfig[dimensions])
        ),
     this.dataTableWithMetricsAndDimensions = (
            queryInfo as record, 
            datasourceConfig as record
        ) => 
        Value.ReplaceType(
            (
                optional selectedDateRangeType as text,
                optional selectedMetrics as list,
                optional selectedDimensions as list
            ) as table =>
                let
                    _queryDetails = this.getQueryDetails(queryInfo),
                    _queryParams = _queryDetails[query_params],
                    _allowedMetrics = datasourceConfig[metrics],
                    _allowedDimensions = datasourceConfig[dimensions],
                    _initialFields = _queryParams[fields],
                    _metrics = if (selectedMetrics <> null) then
                            List.Transform(
                                List.Select(
                                    _allowedMetrics,
                                    (metric as record) =>
                                        List.Contains(
                                            selectedMetrics, 
                                            metric[display_name],
                                            Comparer.OrdinalIgnoreCase
                                        ) = true
                                ),
                                (metric as record) as text =>
                                    metric[name]
                            )
                        else
                            {},
                    _dimensions = if (selectedDimensions <> null) then
                            List.Transform(
                                List.Select(
                                    _allowedDimensions,
                                    (dimension as record) =>
                                        List.Contains(
                                            selectedDimensions, 
                                            dimension[display_name],
                                            Comparer.OrdinalIgnoreCase
                                        ) = true
                                ),
                                (dimension as record) as text =>
                                    dimension[name]
                            )
                        else
                            {},
                    _dateRangeType = this.getDateRangeType(_queryDetails, selectedDateRangeType),
                    // convert metrics and dimensions into fields
                    _combinedFields = List.Combine({_metrics, _dimensions}),
                    // when using "Split by" in QM, "fields" are multidimensional array instead of array of strings
                    _fields = if (List.Count(_combinedFields) > 0) then 
                            [
                                #"fields" = _combinedFields
                            ]
                        else 
                                if (Value.Is(_initialFields, type text)) then
                                [
                                    #"fields" = Text.Split(_initialFields, ",")
                                ]
                                else
                                [
                                    #"fields" = _initialFields
                                ],
                    _params = Record.Combine({@_queryParams, _dateRangeType, _fields}),
                    _result = this.getQueryResultsAsTable(_params)
                in
                    _result,
            Types[QueryTableWithMetricsAndDimensions](datasourceConfig[metrics], datasourceConfig[dimensions])
        ),
    this.dataTableWithProfileBuilder = (queryInfo as record, profileLabel as text) =>
        Value.ReplaceType(
            (optional inputProfile as text, optional selectedDateRangeType as text) as table =>
                let
                    _queryDetails = this.getQueryDetails(queryInfo),
                    _userProfile =
                        if (inputProfile <> null and inputProfile <> "") then
                            [
                                #"ds_accounts" = inputProfile
                            ]
                        else
                            [],
                    _dateRangeType = this.getDateRangeType(_queryDetails, selectedDateRangeType),
                    _queryParams = Record.Combine({_queryDetails[query_params], _dateRangeType, _userProfile}),
                    _result = this.getQueryResultsAsTable(_queryParams)
                in
                    _result,
            Types[QueryTableWithProfile](profileLabel)
        ),
    this.dataTableWithAccountsAndDateFieldBuilder = (queryInfo as record, accounts as list) =>
        Value.ReplaceType(
            (optional selectedConnectionAccounts as list, optional selectedDateRangeType as text) as table =>
                let
                    _queryDetails = this.getQueryDetails(queryInfo),
                    _queryParams = _queryDetails[query_params],
                    _userAccounts =
                        if (selectedConnectionAccounts <> null) then
                            [
                                #"ds_accounts" = List.Transform(
                                    List.Select(
                                        accounts,
                                        (connectionAccount as record) =>
                                            List.Contains(
                                                selectedConnectionAccounts, 
                                                connectionAccount[account_name],
                                                Comparer.OrdinalIgnoreCase
                                            ) = true
                                    ),
                                    (selectedConnectionAccount as record) as text =>
                                        selectedConnectionAccount[account_id]
                                )
                            ]
                        else
                            if (queryInfo[group_info][name] = "STANDARD") then 
                                [
                                    #"ds_accounts" = this.getFirstConnectionAccountFromQuery(accounts)
                                ]
                            else 
                                [],
                    _dateRangeType = this.getDateRangeType(_queryDetails, selectedDateRangeType),
                    _params = Record.Combine({_queryDetails[query_params], _dateRangeType, _userAccounts}),
                    _result = this.getQueryResultsAsTable(_params)
                in
                    _result,
            Types[QueryTableWithAccountsNoOptions](accounts)
        ),
        
    this.getLogins = () as list =>
        List.Transform(
            SupermetricsClient[GetLogins](),
            (loginInfo as record) as record =>
                [
                    #"id" = loginInfo[login_id],
                    #"label" = loginInfo[display_name] & " (" & loginInfo[auth_user_info][email] & ")",
                    #"icon" = "Function",
                    #"items" = {},
                    #"type" = "Function",
                    #"leaf" = true,
                    #"ds_id" = loginInfo[ds_info][ds_id],
                    #"ds_name" = loginInfo[ds_info][name],
                    #"display_name" = loginInfo[display_name]
                ]
    ),
    this.getConnectionsTableWithAccountSelection = (queryInfo as record, datasourceConfig as record, withOptions as text) =>
        let
            _allLogins = this.getLogins(),
            _filteredLogins = List.Select(
                _allLogins,
                (loginsTableRow as record) => 
                    Value.Equals(loginsTableRow[ds_id], queryInfo[ds_info][ds_id])
            ),            
            _list = List.Transform(
                _filteredLogins,
                (login as record) => SupermetricsClient[GetAccounts](
                    login[id],
                    login[display_name]
                )
            ),
            _result = 
                if (withOptions = "options") then
                    this.dataTableWithOptionsBuilder(
                        queryInfo,
                        datasourceConfig,
                        List.Union(_list)
                    )
                else
                    this.dataTableWithAccountsAndDateFieldBuilder(
                        queryInfo,
                        List.Union(_list)
                    )
        in 
            _result
        ,
    this.getConnectionsTableWithInputFieldAsProfile = (queryInfo as record, profileLabel as text) =>
       this.dataTableWithProfileBuilder(queryInfo, profileLabel),
    this.getQueriesAndConnectionsBasedOnReportType = (queryInfo as record) =>
        let
            _queryDetails = this.getQueryDetails(queryInfo),
            _dataSourceConfig = SupermetricsClient[GetDataSourceConfig](_queryDetails),
            _isReportTypeBased = Value.Equals(_dataSourceConfig[client_config][show_report_types], true),
            _queryReportType = try 
                List.First(
                    List.Select(
                        _dataSourceConfig[report_types],
                        (reportTypeInfo as record) as logical =>
                            Value.Equals(reportTypeInfo[id], _queryDetails[query_params][settings][report_type])
                    ),
                    [
                        #"account_label" = "Profile"
                    ]
                )
                otherwise
                    false
                ,
    
            _hasAccountList = Value.Equals(_dataSourceConfig[client_config][has_account_list], true),

            _profileLabel = if (_isReportTypeBased = true) then _queryReportType[account_label] else "Accounts",
            _isReportTypeBasedWithoutAccountAndProfile = if ( _queryReportType  = false ) then true else false,

            _result =
                if (_isReportTypeBased = true) then
                    if (_hasAccountList = true) then 
                        this.getConnectionsTableWithAccountSelection(queryInfo, _dataSourceConfig, "")
                    else if (_isReportTypeBasedWithoutAccountAndProfile = true ) then
                        this.dataTableWithMetricsAndDimensions(queryInfo, _dataSourceConfig)
                    else
                        this.getConnectionsTableWithInputFieldAsProfile(queryInfo, _profileLabel)
                else
                    this.getConnectionsTableWithAccountSelection(queryInfo, _dataSourceConfig, "options")
        in
            _result,


    this.getDistinctTableFromRecords = (
        records as list, optional uniqueColumn as text, optional additionalColumns as list
    ) as table =>
        let
            _uniqueColumn = if (uniqueColumn <> null) then uniqueColumn else "id",
            _additionalColumns = if (additionalColumns <> null) then additionalColumns else {},
            _result = Table.ReplaceKeys(
                Table.Distinct(
                    Table.FromRecords(
                        records, List.Combine({{"id", "label", "items", "icon", "type", "leaf"}, _additionalColumns})
                    ),
                    _uniqueColumn
                ),
                {[Columns = {"id"}, Primary = false]}
            )
        in
            _result,
    this.toNavigationTable = (t as table, usePreviewColumn as logical) as table =>
        let
            _previewColumn = if (usePreviewColumn = true) then "type" else ""
        in
            Table.ToNavigationTable(t, {"id"}, "label", "items", "icon", _previewColumn, "leaf"),
    this.getDataSourceReportTypesTable = (reportTypes as list) as table =>
        this.getDistinctTableFromRecords(
            List.Transform(
                reportTypes,
                (reportTypeInfo as record) as record =>
                    [
                        #"id" = reportTypeInfo[id],
                        #"label" = reportTypeInfo[label],
                        #"icon" = "Function",
                        #"items" = {},
                        #"type" = "Function",
                        #"leaf" = true
                    ]
            )
        ),    
    this.getQueriesTable = (queries as list) as table =>
        this.getDistinctTableFromRecords(
                List.Transform(
                    queries,
                    (queryInfo as record) as record =>
                    let
                        _result =
                            [
                                #"id" = queryInfo[query_id],
                                #"label" = queryInfo[name],
                                #"items" = this.getQueriesAndConnectionsBasedOnReportType(queryInfo),
                                #"icon" = "Cube",
                                #"type" = "Table",
                                #"leaf" = true,
                                #"group_id" = queryInfo[group_info][group_id]
                            ]
                    in
                        _result
                ),
                "id",
                {"group_id"}
            ),
    this.getGroupsTable = (queries as list, queriesTable as table) as table =>
        this.getDistinctTableFromRecords(
            List.Transform(
                queries,
                (queryInfo as record) as record =>
                    [
                        #"id" = queryInfo[group_info][group_id],
                        #"label" = queryInfo[group_info][name],
                        #"items" = this.toNavigationTable(
                            Table.SelectRows(
                                queriesTable,
                                (queriesTableRow as record) as logical =>
                                    Value.Equals(queriesTableRow[group_id], queryInfo[group_info][group_id])
                            ),
                            false
                        ),
                        #"icon" = "CubeDatabase",
                        #"type" = "Table",
                        #"leaf" = false,
                        #"ds_id" = queryInfo[ds_info][ds_id]
                    ]
            ),
            "id",
            {"ds_id"}
        ),

    /**
     * Filtering data sources by user's connections
     * Also check if the connection have queries
     */
    this.getDataSourcesTable = (allConnections as list, queries as list, groupsTable as table) as table =>
        let  
            _list =  List.Transform(
                allConnections,
                (connection as record) as record =>
                    [
                        #"id" = connection[ds_id],
                        #"label" = connection[ds_name],
                        #"items" = this.toNavigationTable(
                            Table.SelectRows(
                                groupsTable,
                                (groupsTableRow as record) as logical =>
                                    Value.Equals(groupsTableRow[ds_id], connection[ds_id])
                            ),
                            true
                        ),
                        #"icon" = "DatabaseServer",
                        #"type" = "Table",
                        #"leaf" = false
                    ]
            ),

            // display only data sources that have connections
            _datasources = List.Select(
                _list, 
                each List.Contains(
                    List.Transform(
                        queries, 
                        each _[ds_info][ds_id]
                    ), 
                    _[id]
                )
            ),

            _result = this.getDistinctTableFromRecords(
                _datasources
            )
        in
            _result,
    this.getMyQueriesTable = (dataSourcesTable as table) as table =>
        this.getDistinctTableFromRecords(
            {
                [
                    #"id" = "my-queries",
                    #"label" = "My queries",
                    #"items" = this.toNavigationTable(dataSourcesTable, true),
                    #"icon" = "Dimension",
                    #"type" = "Table",
                    #"leaf" = false
                ]
            }
        ),

    this.doesntHaveConnectionsForDataSources = (connections as list, queries as list) as logical => 
        List.Count(
            List.Select(
                connections, 
                each List.Contains(
                    List.Transform(
                        queries, 
                        each _[ds_info][ds_id]
                    ), 
                    _[ds_id] // connection
                )
            )) = 0   
    ,
    this.getMyQueries = () as table =>
        let
            _storedQueries = SupermetricsClient[GetQueries](),
            _standardSchemas = SupermetricsClient[GetStandardSchemasQueries](),
            _allConnections = this.getLogins(),
            _queries = List.Combine({_storedQueries, _standardSchemas}),
            _result = if (List.Count(_allConnections) = 0) then 
                let
                    _noConnectionsFound = Instructions[NoConnections](),
                    _resultWithEvent  = (eventResponse) => _noConnectionsFound,
                    _eventResponse = Tracking[NavigatorLoadedWithoutConnections](),
                    _result = _resultWithEvent(_eventResponse)
                in
                    _result
            else if (this.doesntHaveConnectionsForDataSources(_allConnections, _queries) = true) then
                Instructions[NoConnectionsForQueries]()
            else 
                let
                    _queriesTable = this.getQueriesTable(_queries),
                    _groupsTable = this.getGroupsTable(_queries, _queriesTable),
                    _dataSourcesTable = this.getDataSourcesTable(_allConnections, _queries, _groupsTable),
                    _teamsTable = this.getMyQueriesTable(_dataSourcesTable),
                    _resultWithEvent = (eventResponse) => _teamsTable,
                    _eventResponse = Tracking[NavigatorRendered](),
                    _result = try _resultWithEvent(_eventResponse) otherwise Tracking[NavigatorError]()
                in
                    _result
        in
            _result
in
    [
        GetMyQueries = this.getMyQueries
    ]
;


