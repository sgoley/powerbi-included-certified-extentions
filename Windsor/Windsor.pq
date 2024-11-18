[Version = "1.0.0"]
section Windsor;

Version = "1.0.0";

RedirectUri = "https://oauth.powerbi.com/views/oauthredirect.html";
client_id = "gds_A2Pv6njhRUbRGHa05mSCzfcje02ghN8KqoTm5gEo7TfR3";

// Expression.Evaluate used to load icons for connector
Icons = Expression.Evaluate(Text.FromBinary(Extension.Contents("Icons.pqm")), #shared);
LoadString = (string as text) => Extension.LoadString(string);

Windsor = [
    TestConnection = (dataSourcePath) as list => {"Windsor.Main"},
    Authentication = [
        OAuth = [
            StartLogin = Windsor.Auth[Start],
            FinishLogin = Windsor.Auth[Finish],
            Refresh = Windsor.Auth[Refresh],
            Logout = Windsor.Auth[Logout]
        ]
    ],
    Label = LoadString("AuthTitle")
];

Windsor.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = {LoadString("ButtonTitle"), LoadString("ButtonHelp")},
    SourceImage = Icons,
    SourceTypeImage = Icons
];

[DataSource.Kind="Windsor", Publish="Windsor.Publish"]
shared Windsor.Main = () as table => 
    let
        SavedQueriesTable = Windsor.Navigation[GetSavedQueries](),
        Result = Windsor.Utils[ToNav](SavedQueriesTable, {"id"}, "label", "items", "icon", "type", "leaf")
    in
        Result;

Windsor.Urls = let
        BaseOnboardUrl = "https://onboard.windsor.ai",
        BaseConnectorsUrl = "https://connectors.windsor.ai",
        BaseOnboardAuthUrl = BaseOnboardUrl & "/oauth",
        BaseOnboardApiUrl = BaseOnboardUrl & "/api"
    in
        [
            BaseOnboardUrl = BaseOnboardUrl,
            BaseConnectorsUrl = BaseConnectorsUrl,
            AuthAuthorize = BaseOnboardAuthUrl & "/authorize",
            AuthToken = BaseOnboardAuthUrl & "/token",
            AuthIntrospect = BaseOnboardAuthUrl & "/introspect",
            Logout = BaseOnboardUrl & "/logout",
            DataUrls = BaseOnboardApiUrl & "/data-urls",
            AccountsUrl = BaseOnboardApiUrl & "/common/ds-accounts",
            UserInfo = BaseOnboardUrl & "/user_info"
        ];

Windsor.Auth = 
    let
        self.createHash = (verifier as text) as text =>
            let
                Result = Binary.ToText(
                    Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(verifier, TextEncoding.Ascii)),
                    BinaryEncoding.Base64
                )
            in
                Result,
        self.StartLogin = (resourceUrl, state, display) =>
                let
                    PlainTextVerifier = Text.NewGuid() & Text.NewGuid(),
                    AuthorizeUrl = Windsor.Urls[AuthAuthorize] 
                    & "?" 
                    & Uri.BuildQueryString(
                        [
                            client_id = client_id,
                            state = state,
                            response_type = "code",
                            is_powerbi = "true",
                            redirect_uri = RedirectUri,
                            code_challenge_method = "S256",
                            code_challenge = self.createHash(PlainTextVerifier)
                        ]
                        )
                in
                    [
                        LoginUri = AuthorizeUrl,
                        CallbackUri = RedirectUri,
                        WindowHeight = 1200,
                        WindowWidth = 1000,
                        Context = PlainTextVerifier
                    ],

        self.FinishLogin = (context, callbackUri, state) =>
            let
                Parts = Uri.Parts(callbackUri)[Query],
                TokenData = self.TokenMethod(Parts[code], "authorization_code", context)
            in
                [   
                    // Introspected token (api_key is saved here)
                    access_token = TokenData[IntrospectedData][api_key],
                    refresh_token = TokenData[TokenData][refresh_token]?,
                    // those will be added in auth Properties record
                    token_type = TokenData[TokenData][token_type]?,
                    username = TokenData[IntrospectedData][username]?,
                    user_email = TokenData[IntrospectedData][user_email]?
                    
                ],
        self.RefreshLogin = (resourceUrl, refresh_token) => self.TokenMethod(refresh_token, "refresh_token"),
        self.Logout = (accessToken) => Windsor.HttpClient[Get](Windsor.Urls[Logout], [], null),
        self.IntrospectToken = (access_token_data as record) as record =>
            let
                ManualHandlingStatusCodes = {400,500},
                payload = [
                            client_id = client_id,
                            token = access_token_data[access_token]
                        ],
                resp = Web.Contents(
                    Windsor.Urls[AuthIntrospect], 
                    [
                        Content = Text.ToBinary(Uri.BuildQueryString(payload)),
                        Headers=[
                            #"Content-type" = "application/x-www-form-urlencoded",
                            #"Accept" = "application/json"
                        ],
                        ManualStatusHandling = ManualHandlingStatusCodes
                    ]
                ),
                res = Json.Document(resp)
            in  
                if (res[error]? <> null) then
                    error Error.Record(res[error], access_token_data[access_token])
                else
                    [
                        TokenData = access_token_data,
                        IntrospectedData = res
                    ],
        self.TokenMethod = (code, grant_type, optional verifier) as record =>
            let
                _verifier = if (verifier <> null) 
                    then [code_verifier = verifier] 
                    else [code_verifier = Text.NewGuid() & Text.NewGuid()],
                _codeparam = if (grant_type = "authorization_code") then [code = code] else [refresh_token = code],
                query = _verifier & _codeparam & [
                    client_id = client_id,
                    grant_type = grant_type,
                    redirect_uri = RedirectUri
                ],
                ManualHandlingStatusCodes = {400, 403, 500},
                Response = Web.Contents(
                    Windsor.Urls[AuthToken],
                    [
                        Content = Text.ToBinary(Uri.BuildQueryString(query)),
                        Headers = [
                            #"Content-type" = "application/x-www-form-urlencoded",
                            #"Accept" = "application/json"
                        ],
                        ManualStatusHandling = ManualHandlingStatusCodes
                    ]
                ),
                resp = Json.Document(Response)
            in
                if (resp[error]? <> null) then
                    error Error.Record(resp[error], resp[message]?)
                else
                    self.IntrospectToken(resp)
    in
        [
            Start = self.StartLogin,
            Finish = self.FinishLogin,
            Refresh = self.RefreshLogin,
            Logout = self.Logout
        ];

Windsor.HttpClient = let
    self.FailedStatusCodes = {400, 403, 404, 429, 500},
    self.Execute = (Callable as nullable function, Response as record) as record =>
        Record.Combine({try Callable() otherwise [], Response}),
    self.ValidateResponse = (Response as binary, optional OnFailed as nullable function) as record =>
        let
            MetaData = Value.Metadata(Response),
            JsonData = Json.Document(Response),
            Result = 
                if List.Contains(self.FailedStatusCodes, MetaData[Response.Status]) then
                    // Handle failed status codes
                    error try Response[error][message] otherwise "Error"
                else
                    if Type.Is(Value.Type(JsonData), type list) then 
                        [#"data" = JsonData] 
                    else 
                        JsonData
        in
            Result,
    self.GetHeaders = (extra as record) as record =>
        Record.Combine(
            {
                [
                    #"Content-Type" = "application/json"
                ],
                extra
            }
        ),
    self.GetOptions = (Query as record, Body as nullable text) as record =>
        let
            Options = [
                Headers = self.GetHeaders(
                    Record.Combine(
                        {try Value.Metadata(Body)[headers] otherwise []}
                    )
                ),
                CredentialQuery = Query,
                ManualStatusHandling = self.FailedStatusCodes
            ],
            OptionsHandlePost =
                if Body <> null then
                    Record.AddField(Options, "Content", Text.ToBinary(Body))
                else
                    Options,
            Result = OptionsHandlePost
        in
            Result,
    self.GetResponse = (url as text, Query as record, Body as nullable text) as any =>
        let
            RequestOptions = self.GetOptions(Query, Body),
            Result = Web.Contents(Windsor.Utils[ValidateUrlScheme](url), RequestOptions)
        in
            Result,
    self.Request = (url as text, Query as record, Body as nullable text, optional Handlers as nullable record) as record =>
        let
            Response = self.GetResponse(url, Query, Body),
            JsonData = self.ValidateResponse(Response),
            Result = self.Execute(try Handlers[OnSuccess] otherwise null, JsonData)
        in Result
    in
        [
            Get = (url as text, Query as record, Body as nullable text, optional Handlers as nullable record) as record =>
                self.Request(url, Query, null, Handlers),
            Post = (url as text, Query as record, Body as nullable text, optional Handlers as nullable record) as record =>
                self.Request(url, Query, if Body = null then "" else Body, Handlers),
            _GetResponse = self.GetResponse,
            ValidateResponse = self.ValidateResponse
        ];

Windsor.Data = let
    self.GetSavedQueries = () as list =>
        let
            Queries = Windsor.HttpClient[Get](
                    Windsor.Urls[DataUrls], 
                    [api_key = Windsor.Utils[GetApiKey]()], 
                    null
                )[data]
        in
            Queries,
    self.GetFieldsInfo = (Datasource as nullable text) as list => 
        let
            Ds = if Datasource = null then "all" else Datasource,
            Url = Windsor.Urls[BaseConnectorsUrl] & "/" & Ds & "/fields",
            Body = Uri.BuildQueryString(
                [#"api_key" = Windsor.Utils[GetApiKey]()]
            ) meta [
                headers = [
                    #"Content-Type" = "application/x-www-form-urlencoded"
                ]
            ],
            Result = Windsor.HttpClient[Post](Url, [], Body)[data]
        in
            Result,
    self.GetUserInfo = () as record => Windsor.HttpClient[Get](
        Windsor.Urls[UserInfo], 
        [api_key = Windsor.Utils[GetApiKey]()], null)
    in
        [
            GetSavedQueries = self.GetSavedQueries,
            GetFieldsInfo = self.GetFieldsInfo,
            GetUserInfo = self.GetUserInfo
        ];

Windsor.Navigation = let
    self.GetQueryDetails = (QueryUrl as text) as record =>
        let
            Result = Uri.Parts(QueryUrl),
            Datasource = Text.Remove(Result[Path], "/"),
            DataFieldsString = Result[Query][fields],
            DataRemovedApiKeyAndFields = Record.RemoveFields(Result[Query], {"api_key", "fields"}),
            Data = Record.Combine({
                    [
                        #"datasource" = Datasource, 
                        #"fields" = Text.Split(DataFieldsString, ",")
                    ], 
                    DataRemovedApiKeyAndFields
                })
        in
            Data,
    self.GetQueryResultTable = (Datasource as text, Params as record) as table =>
        let
            Url = Windsor.Urls[BaseConnectorsUrl] & "/" & Datasource,

            Body = Uri.BuildQueryString(
                Record.Combine({[#"api_key" = Windsor.Utils[GetApiKey]()], Params})
            ) meta [
                headers = [
                    #"Content-Type" = "application/x-www-form-urlencoded"
                ]
            ],
            Response = Windsor.HttpClient[Post](Url, [], Body),
            Result = try
                let
                    FieldsInfo = Windsor.Data[GetFieldsInfo](Datasource),
                    _table = Table.FromRecords(Response[data]),
                    UsedFields = List.Transform(
                                    List.Select(
                                        FieldsInfo,
                                        (Field as record) =>
                                            List.Contains(
                                                Text.Split(Params[fields], ","),
                                                Field[id],
                                                Comparer.OrdinalIgnoreCase
                                            ) = true
                                    ),
                                    (Field as record) as record => Field
                                ),
                    Schema = Windsor.Utils[GetSchema](UsedFields),
                    _resultWithColumnTypes = Table.TransformColumnTypes(_table, Schema)
                in 
                    _resultWithColumnTypes
                otherwise
                    if (Response[error]? <> null) then
                        error Error.Record(Response[error], Response[message]?)
                    else
                        error Text.Combine({
                            "Empty response, please check your query at onboard.windsor.ai/app/data-preview.",
                            " Url: ", Url,
                            " Parameters: ", Uri.BuildQueryString(Params)
                            })
        in
            Result,
    self.GetDateRange = (
        QueryDetails as record, 
        SelectedDatePreset as nullable text, 
        SelectedDateFrom as nullable text, 
        SelectedDateTo as nullable text) =>
        let
            DateFrom = try QueryDetails[date_from] otherwise null,
            DateTo = try QueryDetails[date_to] otherwise null,
            QueryDatePreset = try QueryDetails[date_preset] otherwise null,
            Result = if (
                            SelectedDatePreset = null 
                            and SelectedDateFrom <> null 
                            // SelectedDateTo can be null (today will be used)
                            // and SelectedDateTo <> null
                ) then
                    if (SelectedDateTo <> null)
                        then [#"date_from" = SelectedDateFrom, #"date_to" = SelectedDateTo]
                        else [#"date_from" = SelectedDateFrom]
                else if SelectedDatePreset <> null then
                    let
                        QueryDatePreset = try QueryDetails[date_preset] otherwise null,
                        DatePreset = Windsor.Dates[GetDateRangeTypeFromText](SelectedDatePreset, QueryDatePreset),
                        Result = [#"date_preset" = DatePreset]
                    in
                        Result
                else if (
                            QueryDatePreset <> null
                            and DateFrom = null
                            and DateTo = null
                ) then
                     [#"date_preset" = QueryDatePreset]
                else if (
                            QueryDatePreset = null
                            and DateFrom <> null
                            // DateTo can be null (today will be used)
                            // and DateTo <> null
                ) then
                    if (DateTo <> null)
                        then [#"date_from" = DateFrom, #"date_to" = DateTo]
                        else [#"date_from" = DateFrom]
                else 
                    // last 3 days will be used by default
                    []
        in
            Result,
    self.GetDistinctTableFromRecords = (
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
    self.ToNavTable = (t as table, UsePreviewColumn as logical) as table =>
        let
            PreviewCol = if (UsePreviewColumn = true) then "type" else ""
        in
            Windsor.Utils[ToNav](t, {"id"}, "label", "items", "icon", PreviewCol, "leaf"),
    
    self.GetTableWithControls = (
        QueryDetails as record,
        DSFields as list,
        UserAccounts as list,
        optional DSOptions as list
        ) => 
        let
            Result = if List.Count(UserAccounts) > 1
                then self.TableWithAccounts(QueryDetails, DSFields, UserAccounts)
                else self.TableWithoutAccounts(QueryDetails, DSFields)
        in
            Result,
    self.GetFilteredFields = (
        QueryDetails as record,
        DSFields as list,
        IsAddFields as logical,
        optional SelectedFields as list
        ) =>
        let
            Datasource = QueryDetails[datasource],
            QueryFields = QueryDetails[fields],
            Fields =
                if (SelectedFields <> null) then
                    List.Transform(
                        List.Select(
                            DSFields,
                            (field as record) =>
                                List.Contains(
                                    SelectedFields,
                                    Windsor.Utils[GetFieldRepr](field),
                                    Comparer.OrdinalIgnoreCase
                                ) = true
                        ),
                        (field as record) as text => field[id]
                    )
                else {},
            FieldsToShow = 
                if (List.Count(Fields) > 0) then
                    if IsAddFields = true
                    then
                        [
                            #"fields" = Text.Combine(
                                List.Distinct(
                                    List.Combine({
                                        Fields, 
                                        QueryFields
                                    })
                                ), 
                                ","
                            )
                        ]
                    else
                        [#"fields" = Text.Combine(Fields, ",")]
                else
                    [#"fields" = Text.Combine(QueryFields, ",")]
        in
            FieldsToShow,
    self.GetFilteredAccounts = (
        QueryDetails as record,
        UserAccounts as list,
        optional SelectedAccounts as list
        ) =>
        let
            QueryAccounts = 
                if QueryDetails[select_accounts]? <> null
                then QueryDetails[select_accounts]
                else "",
            Accounts = 
                if (SelectedAccounts <> null) then
                    List.Transform(
                            List.Select(
                                UserAccounts,
                                (UsedAccount as record) =>
                                    List.Contains(
                                        SelectedAccounts,
                                        Windsor.Utils[GetAccountRepr](UsedAccount),
                                        Comparer.OrdinalIgnoreCase
                                    ) = true
                            ),
                            (SelectedAccount as record) as text =>
                                SelectedAccount[account_id]
                        )
                else {},
            AccountsToShow =
                if (List.Count(Accounts) > 0) then
                    [#"select_accounts" = Text.Combine(Accounts, ",")]
                else
                    [#"select_accounts" = QueryAccounts]
        in
            AccountsToShow,
    self.TableWithAccounts = (
        QueryDetails as record,
        DSFields as list,
        UserAccounts as list,
        optional DSOptions as list
        ) => 
        Value.ReplaceType(
            (
                optional SelectedAccounts as list,
                optional SelectedFields as list,
                optional IsAddFields as logical,
                optional SelectedDateRange as text,
                optional SelectedDateFrom as text,
                optional SelectedDateTo as text
            ) as table =>
                let
                    Datasource = QueryDetails[datasource],
                    Accounts = self.GetFilteredAccounts(QueryDetails, UserAccounts, SelectedAccounts),
                    _AddFields = if IsAddFields <> null then IsAddFields else false,
                    Fields = self.GetFilteredFields(QueryDetails, DSFields, _AddFields, SelectedFields),
                    DateRange = self.GetDateRange(QueryDetails, SelectedDateRange, SelectedDateFrom, SelectedDateTo),
                    
                    Params = Record.Combine({DateRange, Accounts, Fields}),
                    Result = self.GetQueryResultTable(Datasource, Params)
                in
                    Result,
            Windsor.Types[QueryTableWithAccounts](UserAccounts, DSFields, QueryDetails)
        ),
    self.TableWithoutAccounts = (
        QueryDetails as record,
        DSFields as list,
        optional DSOptions as list
        ) => 
        Value.ReplaceType(
            (
                optional SelectedFields as list,
                optional IsAddFields as logical,
                optional SelectedDateRange as text,
                optional SelectedDateFrom as text,
                optional SelectedDateTo as text
            ) as table =>
                let
                    Datasource = QueryDetails[datasource],
                    _AddFields = if IsAddFields <> null then IsAddFields else false,
                    Fields = self.GetFilteredFields(QueryDetails, DSFields, _AddFields, SelectedFields),
                    DateRange = self.GetDateRange(QueryDetails, SelectedDateRange, SelectedDateFrom, SelectedDateTo),
                    
                    Params = Record.Combine({DateRange, Fields}),
                    Result = self.GetQueryResultTable(Datasource, Params)
                in
                    Result,
            Windsor.Types[QueryTableWithoutAccounts](DSFields, QueryDetails)
        ),
    // unused for now
    self.GetDsOptions = (Datasource as text) as list =>
        let
            Url = Windsor.Urls[BaseConnectorsUrl] & "/" & Datasource & "/options",
            Result = Windsor.HttpClient[Post](Url, [], null)[data]
        in
            Result,
    self.GetQueriesAndConnectionsBasedOnReportType = (QueryDetails as record) =>
        let
            Datasource = QueryDetails[datasource],
            UserAccounts = Windsor.HttpClient[Get](
                Windsor.Urls[AccountsUrl], 
                [
                    #"api_key" = Windsor.Utils[GetApiKey](), 
                    #"datasource" = Datasource
                ], null
            )[data],
            DsFields = Windsor.Data[GetFieldsInfo](Datasource),
            _result = self.GetTableWithControls(
                        QueryDetails,
                        DsFields,
                        UserAccounts
                    )
        in
            _result,
    
    self.GetQueriesTable = (queries as list) as table =>
        self.GetDistinctTableFromRecords(
                List.Transform(
                    queries,
                    (queryInfo as record) as record =>
                    let
                        QueryDetails = self.GetQueryDetails(queryInfo[url]),
                        _result =
                            [
                                #"id" = queryInfo[id],
                                #"label" = "[" & QueryDetails[datasource] & "] " & queryInfo[name],
                                #"items" = self.GetQueriesAndConnectionsBasedOnReportType(QueryDetails),
                                #"icon" = "Cube",
                                #"type" = "Table",
                                #"leaf" = false
                            ]
                    in
                        _result
                ),
                "id"
            ),
    self.GetSavedQueriesTable = (DsTable as table) as table =>
        let
        Result = self.GetDistinctTableFromRecords(
            {
                [
                    #"id" = "saved-queries",
                    #"label" = Windsor.Utils[SavedQueriesTitle](),
                    #"items" = self.ToNavTable(DsTable, true),
                    #"icon" = "Dimension",
                    #"type" = "Table",
                    #"leaf" = false
                ]
            }
        )
        in
            Result,
    self.GetSavedQueries = () as table =>
        let
            SavedQueriesList = Windsor.Data[GetSavedQueries](),
            Result = if (List.Count(SavedQueriesList) = 0) then
                Windsor.Help[NoSavedQueries]()
            else
                let
                    QueriesTable = self.GetQueriesTable(SavedQueriesList),
                    ResultTable = self.GetSavedQueriesTable(QueriesTable)
                in
                    ResultTable
        in
            Result
    in
        [
            GetSavedQueries = self.GetSavedQueries
        ];

Windsor.Types = let
    self.DateTypeBuilder = (title as text, sampleValue as text) as type =>
        Text.Type meta [
            Documentation.FieldDescription = "Date in format yyyy-MM-dd",
            Documentation.SampleValues = {sampleValue},
            Documentation.FieldCaption = title
        ],
    self.allowedValuesBuilderSingle = (allowedValues as list, title as text, description as text) as type =>
        Text.Type meta [
            Documentation.FieldCaption = title,
            Documentation.FieldDescription = description,
            Documentation.AllowedValues = allowedValues
        ],
    self.allowedValuesBuilderMultiple = (allowedValues as list, title as text, description as text) as type =>
        List.Type meta [
            Documentation.FieldCaption = title,
            Documentation.FieldDescription = description,
            Documentation.AllowedValues = allowedValues
        ],
    self.AppendFields = (CurrentFields as list) as type => 
        Logical.Type meta [
            Documentation.FieldCaption = "Append fields to existing. Default: FALSE",
            Documentation.FieldDescription = Text.Combine(
                {   
                    "If TRUE - will append selected Fields to existing ones.",
                    " If FALSE - will overwrite fields from query.",
                    " Current fields: ",
                    Text.Combine(CurrentFields, ",")
                }
                ),
            Documentation.SampleValues = {false},
            Documentation.AllowedValues = { true, false }
        ],
    self.DateRangeTypeBuilder = () as type =>
        self.allowedValuesBuilderSingle(
            Windsor.Dates[DateRangeTypes],
            "Date range type",
            "Date range for the query."
        ),
    self.DateFromBuilder = (QueryDateFrom as nullable text) as type =>
        self.DateTypeBuilder(
            if QueryDateFrom <> "" then Text.Combine({"Start date. Default: ", QueryDateFrom}) else "Start date", 
            "2024-01-01"),
    self.DateToBuilder = (QueryDateTo as nullable text) as type =>
        self.DateTypeBuilder(
            if QueryDateTo <> "" then Text.Combine({"End date. Default: ", QueryDateTo}) else "End date"
            , "2024-01-02"),
    self.AccountsDropdownBuilder = (Accounts as list) as type =>
        self.allowedValuesBuilderMultiple(
            List.Transform(
                Accounts, (Account as record) as text => Windsor.Utils[GetAccountRepr](Account)
            ),
            "Accounts",
            "Account description"
        ),
    self.FieldsDropdownBuilder = (Fields as list) as type =>
        self.allowedValuesBuilderMultiple(
                List.Transform(
                    Fields, 
                    (Field as record) as text => Windsor.Utils[GetFieldRepr](Field)
                ),
                "Fields",
                "Field description"
            ),
    self.QueryTableTypeWithAccounts = (
            UserAccounts as list, 
            Fields as list,
            QueryDetails as record
        ) as type =>
            type function (
                optional ConnectionAccounts as self.AccountsDropdownBuilder(UserAccounts),
                optional Fields as self.FieldsDropdownBuilder(Fields),
                optional IsAddFields as self.AppendFields(QueryDetails[fields]),
                optional dateRangeType as self.DateRangeTypeBuilder(),
                optional DateFrom as self.DateFromBuilder(try QueryDetails[date_from] otherwise ""),
                optional DateTo as self.DateToBuilder(try QueryDetails[date_to] otherwise "")
            ) as table meta [
                Documentation.Name = "Query Table With Accounts",
                Documentation.LongDescription = Windsor.Utils[GetTableParametersLongDescription](QueryDetails)
            ],
    self.QueryTableTypeWithoutAccounts = (
            Fields as list,
            QueryDetails as record
        ) as type =>
            type function (
                optional Fields as self.FieldsDropdownBuilder(Fields),
                optional IsAddFields as self.AppendFields(QueryDetails[fields]),
                optional dateRangeType as self.DateRangeTypeBuilder(),
                optional DateFrom as self.DateFromBuilder(try QueryDetails[date_from] otherwise ""),
                optional DateTo as self.DateToBuilder(try QueryDetails[date_to] otherwise "")
            ) as table meta [
                Documentation.Name = "Query Table Without Accounts",
                Documentation.LongDescription = Windsor.Utils[GetTableParametersLongDescription](QueryDetails)
            ]
    in
        [
            QueryTableWithAccounts = self.QueryTableTypeWithAccounts,
            QueryTableWithoutAccounts = self.QueryTableTypeWithoutAccounts
        ];

Windsor.Help = let
    self.CreateNavigationTable = (Instruction as table) as table =>
        let
            NavTable = Windsor.Utils[ToNav](
                    Instruction
                    ,
                    {"id"},
                    "label",
                    "items",
                    "icon",
                    "",
                    "leaf"
                ),
            Result = Table.FromRecords(
                    {
                        [
                            #"id" = "no-saved-queries",
                            #"label" = Windsor.Utils[SavedQueriesTitle](),
                            #"items" = NavTable,
                            #"icon" = "Dimension",
                            #"type" = "Table",
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
            Result,
    self.NoSavedQueries = () as table =>
        let
            Label = LoadString("NoQueriesTitle"),
            Instruction = Table.FromRecords({
                [
                    #"id" = "no-queries-found",
                    #"label" = Label,
                    #"items" = Table.FromRows(
                        {
                            {"Please go to https://onboard.windsor.ai/app/data-preview "},
                            {"and save at least one query to load the data to Power BI"}
                        },
                        {Label}
                    ),
                    #"icon" = "Dimension",
                    #"type" = "Table",
                    #"leaf" = true
                ]},
                {"id", "label", "items", "icon", "type", "leaf"}
            ),
            Result = self.CreateNavigationTable(Instruction)
        in
            Result
    in
        [
            NoSavedQueries = self.NoSavedQueries
        ];

Windsor.Dates = let
    self.DateRangeTypes = {
        "Today" meta [
            Documentation.Name = "Today",
            Value = "last_1dT"
        ],
        "Yesterday" meta [
            Documentation.Name = "Yesterday",
            Value = "last_1d"
        ],
        "Last 3 days" meta [
            Documentation.Name = "Last 3 days",
            Value = "last_3d"
        ],
        "Last 7 days" meta [
            Documentation.Name = "Last 7 days",
            Value = "last_7d"
        ],
        "Last 14 days" meta [
            Documentation.Name = "Last 14 days",
            Value = "last_14d"
        ],
        "Last 28 days" meta [
            Documentation.Name = "Last 28 days",
            Value = "last_28d"
        ],
        "Last 30 days" meta [
            Documentation.Name = "Last 30 days",
            Value = "last_30d"
        ],
        "Last week" meta [
            Documentation.Name = "Last full week",
            Value = "last_1w"
        ],
        "Last 2 weeks" meta [
            Documentation.Name = "Last two full weeks",
            Value = "last_2w"
        ],
        "Last 4 weeks" meta [
            Documentation.Name = "Last four full weeks",
            Value = "last_4w"
        ],
        "This month to date" meta [
            Documentation.Name = "Current month until today",
            Value = "this_monthT"
        ],
        "This month" meta [
            Documentation.Name = "Current month until yesterday",
            Value = "this_month"
        ],
        "Last month" meta [
            Documentation.Name = "Last full month",
            Value = "last_1m"
        ],
        "Last 3 months" meta [
            Documentation.Name = "Last 3 months",
            Value = "last_3m"
        ],
        "Last 6 months" meta [
            Documentation.Name = "Last 6 months",
            Value = "last_6m"
        ],
        "This year" meta [
            Documentation.Name = "Current year until yesterday",
            Value = "this_year"
        ],
        "This year to date" meta [
            Documentation.Name = "Current year until today",
            Value = "this_yearT"
        ],
        "Last year" meta [
            Documentation.Name = "Last 365 days up to yesterday",
            Value = "last_year"
        ],
        "Last year to date" meta [
            Documentation.Name = "Last 365 days up to today",
            Value = "last_year"
        ]
    },
    self.findDateRangeTypesFromText = (SelectedDateRangeType as text) =>
        List.Select(
            self.DateRangeTypes,
            (DateRangeType as text) as logical => Value.Equals(DateRangeType, SelectedDateRangeType)
        ),
    self.GetDateRangeTypeFromText = (SelectedDateRangeType as text, optional DefaultDateRangeType as text) as text =>
        let
            _dateRangeTypes = self.findDateRangeTypesFromText(SelectedDateRangeType),
            _dateRangeType = if (List.Count(_dateRangeTypes) = 0) then null else _dateRangeTypes{0},
            _result = if (_dateRangeType = null) then DefaultDateRangeType else Value.Metadata(_dateRangeType)[
                Value
            ]
        in
            _result
    in
        [
            DateRangeTypes = self.DateRangeTypes,
            GetDateRangeTypeFromText = self.GetDateRangeTypeFromText
        ];

Windsor.Utils = let
    self.GetSavedQueriesTitle = () as text => 
        let 
            UserInfo = Windsor.Data[GetUserInfo](),
            Result = Text.Combine({LoadString("SavedQueriesTitle"), " ", "[", UserInfo[email], " | ", UserInfo[team_name], "]"})
        in 
            Result,
    self.GetFieldRepr = (FieldInfo as record) as text => 
        let
            Result = Text.Combine({
                FieldInfo[name],
                " [",
                FieldInfo[id],
                "]"
            }),
            ResultWithTable = 
                if (FieldInfo[table]? <> null)
                then Text.Combine({
                    FieldInfo[table]?,
                    " - ",
                    Result
                })
                else Result
        in
            ResultWithTable,
    self.GetAccountRepr = (AccountInfo as record) as text => 
        let
            BaseInfo = {
                // always exist
                "[", AccountInfo[account_id], "]"
            },
            // not always exist
            WithName = 
                if AccountInfo[account_name]? <> null
                then List.Combine({{AccountInfo[account_name], " "}, BaseInfo})
                else BaseInfo,
            // "all" datasource
            WithDatasource = 
                if AccountInfo[datasource]? <> null
                then List.Combine({{AccountInfo[datasource], " "}, WithName})
                else WithName,

            Result = Text.Combine(WithDatasource)
        in
            Result,
    self.ToNavigationTable = (
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
                    NavigationTable.IsLeafColumn = isLeafColumn
                ],
                navigationTable = Value.ReplaceType(table, newTableType)
            in
                navigationTable,
    self.TransfromDataType = (Datatype as text) as type =>
        if Datatype = "BOOLEAN" then
            Logical.Type
        // those not always not correctly
        // else if Datatype = "DATE" then
        //     Date.Type
        // else if Datatype = "TIMESTAMP" then
        //     DateTime.Type
        else if Datatype = "NUMERIC" then
            Decimal.Type
        else
            Text.Type,
    self.GetSchema = (Fields as list) as list =>
        List.Transform(
            Fields, (FieldInfo) => {FieldInfo[id], self.TransfromDataType(FieldInfo[type])}
        ),
    self.ValidateUrlScheme = (url as text) as text => 
        if 
            (Uri.Parts(url)[Scheme] <> "https") 
        then 
            error "Url scheme must be HTTPS" 
        else 
            url,
    self.GetApiKey = () as text =>
        let
            // ApiKey is mostly used in POST requests (passed in payload)
            // When used in GET request, it is protected by CredentialQuery
            ApiKey = Extension.CurrentCredential()[access_token]
        in
            ApiKey,
    self.GetTableParametersLongDescription = (QueryDetails as record) as text =>
        let
            Result = Text.Combine(
                {
                    "Current query parameters: ",
                    Text.Combine({"Fields: ", Text.Combine(QueryDetails[fields], ","), "; "}),
                    if QueryDetails[select_accounts]? <> null and QueryDetails[select_accounts]? <> "" 
                        then "Accounts: " & QueryDetails[select_accounts] & "; " else "",
                    if QueryDetails[date_preset]? <> null 
                        then "Date: " & QueryDetails[date_preset] & "; " else "",
                    if QueryDetails[date_from]? <> null
                        then "Start Date: " & QueryDetails[date_from] & "; " else "",
                    if QueryDetails[date_to]? <> null
                        then "End Date: " & QueryDetails[date_to] & "; " else ""
                }
            )
        in Result
    in
        [
            SavedQueriesTitle = self.GetSavedQueriesTitle,
            GetFieldRepr = self.GetFieldRepr,
            GetAccountRepr = self.GetAccountRepr,
            ToNav = self.ToNavigationTable,
            GetSchema = self.GetSchema,
            ValidateUrlScheme = self.ValidateUrlScheme,
            GetApiKey = self.GetApiKey,
            GetTableParametersLongDescription = self.GetTableParametersLongDescription

        ];