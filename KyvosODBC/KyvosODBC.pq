// This connector provides a sample Direct Query enabled connector
// based on an ODBC driver. It is meant as a template for other
// ODBC based connectors that require similar functionality.
//
[Version = "1.0.0"]
section KyvosODBC;
 
// When set to true, additional trace information will be written out to the User log.
// This should be set to false before release. Tracing is done through a call to
// Diagnostics.LogValue(). When EnableTraceOutput is set to false, the call becomes a
// no-op and simply returns the original value.
EnableTraceOutput = false;
 
// TODO
// add handling for SSL
/****************************
 * ODBC Driver Configuration
 ****************************/
// The name of your ODBC driver.
//
Config_DriverName = "Kyvos ODBC Driver";
 
// If your driver under-reports its SQL conformance level because it does not
// support the full range of CRUD operations, but does support the ANSI SQL required
// to support the SELECT operations performed by Power Query, you can override
// this value to report a higher conformance level. Please use one of the numeric
// values below (i.e. 8 for SQL_SC_SQL92_FULL).
//
SQL_SC =
[
    SQL_SC_SQL92_ENTRY            = 1,
    SQL_SC_FIPS127_2_TRANSITIONAL = 2,
    SQL_SC_SQL92_INTERMEDIATE     = 4,
    SQL_SC_SQL92_FULL             = 8
];
//
// Set to null to determine the value from the driver.
//
Config_SqlConformance = ODBC[SQL_SC][SQL_SC_SQL92_FULL];
// null, 1, 2, 4, 8
// This setting controls row count limits and offsets. If not set correctly, query
// folding capabilities for this connector will be extremely limited. You can use
// the LimitClauseKind constants to match common LIMIT/OFFSET SQL formats. If none
// of the supported formats match your desired SQL syntax, consider filing a feature
// request to support your variation.
//
// Supporting OFFSET is considerably less important than supporting LIMIT.
//
// LimitClauseKind values and formats:
//
// LimitClauseKind.Top (LIMIT only, OFFSET not supported)
// -------------------
// SELECT TOP 100 *
// FROM table
//
// LimitClauseKind.Limit (LIMIT only, OFFSET not supported)
// ---------------------
// SELECT *
// FROM table
// LIMIT 100
//
// LimitClauseKind.LimitOffset
// ---------------------------
// SELECT *
// FROM table
// LIMIT 100 OFFSET 200
//
// This option requires that the SQL dialect support all three variations:
// "LIMIT x", "LIMIT x OFFSET y" and "OFFSET y". If your SQL dialect only supports
// OFFSET when LIMIT is also specified, use LimitClauseKind.Limit instead.
//
// LimitClauseKind.AnsiSql2008
// ---------------------------
// SELECT *
// FROM table
// OFFSET 200 ROWS
// FETCH FIRST 100 ROWS ONLY
//
//Config_LimitClauseKind = LimitClauseKind.Top;
Config_LimitClauseKind = LimitClauseKind.Limit;
// see above
// Set this option to true if your ODBC supports the standard username/password
// handling through the UID and PWD connection string parameters. If the user
// selects UsernamePassword auth, the supplied values will be automatically
// added to the CredentialConnectionString.
//
// If you wish to set these values yourself, or your driver requires additional
// parameters to be set, please set this option to 'false'
//
Config_DefaultUsernamePasswordHandling = true;
// true, false
// Some drivers have problems will parameter bindings and certain data types.
// If the driver supports parameter bindings, then set this to true.
// When set to false, parameter values will be inlined as literals into the generated SQL.
// To enable inlining for a limited number of data types, set this value
// to null and set individual flags through the SqlCapabilities record.
//
// Set to null to determine the value from the driver.
//
Config_UseParameterBindings = false;
// true, false, null
// Override this setting to force the character escape value.
// This is typically done when you have set UseParameterBindings to false.
//
// Set to null to determine the value from the driver.
//
// ex. { "\" }
Config_StringLiterateEscapeCharacters = {"\"};
// Override this if the driver expects the use of CAST instead of CONVERT.
// By default, the query will be generated using ANSI SQL CONVERT syntax.
//
// Set to null to leave default behavior.
//
Config_UseCastInsteadOfConvert = true;
// true, false, null
// Set this to true to enable Direct Query in addition to Import mode.
//
Config_EnableDirectQuery = true;
 
code_challenge_method = "S256"; 
windowWidth = 720;
windowHeight = 1024;
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
 
 
// OAuth functions
Base64UrlEncode = (binary) =>
    let
        base64 = Binary.ToText(binary, BinaryEncoding.Base64),
        urlEncoded = Text.Replace(base64, "/", "_", Occurrence.All),
        urlEncodedResult = Text.Replace(urlEncoded, "+", "-", Occurrence.All)
    in
        urlEncoded;
 
StartLogin = (resourceUrl, state, display) =>
    let
        baseUrl = GetBaseUrl(resourceUrl),
        inputData = Json.Document(resourceUrl),
        encryptionVal = inputData[encryption],
        normalizedURL = NormalizeUrl(baseUrl,encryptionVal),
        properties = Json.Document(Web.Contents(normalizedURL,
                [
                    Headers = [CacheControl="no-cache", ContentType="application/json"],
                    ManualStatusHandling={404}
                ]
        )),

        client_id_global = properties[RESPONSE][client_id],
        authUrl =  properties[RESPONSE][authorization_url],
        tokenURL =  properties[RESPONSE][token_url],


        plainTextCodeVerifier = Text.NewGuid() & Text.NewGuid(),
        codeVerifier =
            if (code_challenge_method = "plain") then
                plainTextCodeVerifier
            else if (code_challenge_method = "S256") then
                Base64Url.Encode(Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(plainTextCodeVerifier)))
            else
                error "Unexpected code_challenge_method",
 
        AuthorizeUrl = authUrl
            & "?"
            & Uri.BuildQueryString(
                [
                    client_id = client_id_global,
                    scope =  {
                                "email offline_access openid profile"
                            },
                    response_type = "code",
                    code_challenge_method = code_challenge_method,
                    code_challenge = codeVerifier,
                    state = state,
                    redirect_uri = redirect_uri
                ]
            )
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            // Need to roundtrip this value to FinishLogin
             Context = [client_id = client_id_global, plainTextCodeVerifier = plainTextCodeVerifier, TokenUrl = tokenURL]
        ];
 
// The code verifier will be passed in through the context parameter.
FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query]
    in
        TokenMethod(Parts[code], "authorization_code", context);
 
// Verifier is optional to support both the original FinishLogin call
// (which has a verifier) and the Refresh call (which does not).
TokenMethod = (code, grant_type, optional context) =>
    let
        codeVerifier = if (context[plainTextCodeVerifier] <> null) then [code_verifier = context[plainTextCodeVerifier]] else [],
        codeParameter = if (grant_type = "authorization_code") then [code = code] else [refresh_token = code],
        query = codeVerifier
            & codeParameter
            & [
                client_id = context[client_id],
                grant_type = grant_type,
                redirect_uri = redirect_uri
            ],
        // Set this if your API returns a non-2xx status for login failures
        // ManualHandlingStatusCodes = {400, 403}
        ManualHandlingStatusCodes = {},
        Response = Web.Contents(
            context[TokenUrl],
            [
                Content = Text.ToBinary(Uri.BuildQueryString(query)),
                Headers = [
                    #"Content-type" = "application/x-www-form-urlencoded",
                    #"Accept" = "application/json"
                ],

                ManualStatusHandling = ManualHandlingStatusCodes
            ]
        ),
        Parts = Json.Document(Response)
    in
        // check for error in response
        if (Parts[error]? <> null) then
            error Error.Record(Parts[error], Parts[message]?)
        else
            Parts;

GetBaseUrl = (resourceUrl) => Json.Document(resourceUrl)[server];

NormalizeUrl = (url as text, encryption as text) =>
    if Text.Contains(encryption, "Enabled")  then
        let
            urlWithHttpsAsSuffix = Text.Combine({"https://", url}),
            urlWithHttpsAndOAuthRestCall = Text.Insert(urlWithHttpsAsSuffix,Text.Length(urlWithHttpsAsSuffix), "/kyvos/rest/custom/OAuthConfig?appType=public")
        in
            urlWithHttpsAndOAuthRestCall
    else 
        let
            urlWithHttpAsSuffix = Text.Combine({"http://", url}),
            urlWithHttpAndOAuthRestCall = Text.Insert(urlWithHttpAsSuffix,Text.Length(urlWithHttpAsSuffix), "/kyvos/rest/custom/OAuthConfig?appType=public")
        in
            urlWithHttpAndOAuthRestCall;

SplitUrl = (url as text) => 
    if (Text.Contains(url, ":")) then
        let
            URLParts = Text.Split(url, ":")
        in
           URLParts
    else
       url;
 
 GetEncryptionValue = (encryption as text) => 
    if (Text.Contains(encryption, "Enabled")) then
          let
            encrypted =  1
          in 
            encrypted
    else
        let
            encrypted = 0
         in
            encrypted;
            

Base64Url.Encode = (s) => Text.Replace(Text.Replace(Text.BeforeDelimiter(Binary.ToText(s,BinaryEncoding.Base64),"="),"+","-"),"/","_");
 
[DataSource.Kind = "KyvosODBC", Publish = "KyvosODBC.Publish"]
shared KyvosODBC.Databases = KyvosODBCDatabaseExport;
 
// Data Source Kind description
KyvosODBC = [
    // Set the TestConnection handler to enable gateway support.
    // The TestConnection handler will invoke your data source function to
    // validate the credentials the user has provider. Ideally, this is not
    // an expensive operation to perform. By default, the dataSourcePath value
    // will be a json string containing the required parameters of your data
    // source function. These should be parsed and parsed as individual parameters
    // to the specified data source function.
 //   TestConnection = (dataSourcePath) => {"KyvosODBC.Databases"},

    TestConnection = (dataSourcePath) => 
	let
        params = Json.Document(dataSourcePath),
        server = params[server],
        httpPath =  params[httpPath],
        encryption = params[encryption]
	in
		{"KyvosODBC.Databases", server, httpPath,encryption},
    // Set supported types of authentication
    Authentication = [  
        UsernamePassword = [
            Label = "Username and Password"
            ],
         OAuth = [
            StartLogin=StartLogin,
            FinishLogin=FinishLogin,
            Label = "OAuth 2.0"
         ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];
 
// Data Source UI publishing description
KyvosODBC.Publish = [
    Beta = true,
    Category = "Database",
    ButtonText = {Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp")},
    LearnMoreUrl = "https://kyvosdocumentation.atlassian.net/wiki/spaces/KD20241/pages/148537371/Connecting+to+Microsoft+Power+BI+through+Kyvos+ODBC+Connector",
    SupportsDirectQuery = Config_EnableDirectQuery,
    SupportsEncryption = false,
    SourceImage = KyvosODBC.Icons,
    SourceTypeImage = KyvosODBC.Icons
];
 
KyvosODBC.Icons = [
    Icon16 = {
        Extension.Contents("KyvosODBC16.png"),
        Extension.Contents("KyvosODBC20.png"),
        Extension.Contents("KyvosODBC24.png"),
        Extension.Contents("KyvosODBC32.png")
    },
    Icon32 = {
        Extension.Contents("KyvosODBC32.png"),
        Extension.Contents("KyvosODBC40.png"),
        Extension.Contents("KyvosODBC48.png"),
        Extension.Contents("KyvosODBC64.png")
    }
];


KyvosODBCDatabaseExport = 
    let
        Function = (server as text, httpPath as text,encryption as text) as table =>
        KyvosODBCDatabase(server, httpPath,encryption),
        FunctionType = Type.ForFunction(
            [
                Parameters = [
                    server = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("ServerParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("ServerParameterSampleValues")}
                    ],
                    httpPath = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("HTTPPathParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("HTTPPathParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("HTTPPathParameterSoftwareDescription")
                    ],
                    encryption = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("SSLCaption"), 
                        Documentation.AllowedValues = {"Enabled", "Disabled"}
                    ]
                ], 
                ReturnType = type table
            ], 
            3), // this value is the number of mandatory parameters defined in Function, ie not those marked as optional
       
        WithDocumentation = Value.ReplaceMetadata(
            FunctionType, 
            [
                Documentation.Name = "Kyvos ODBC", 
                Documentation.LongDescription = Extension.LoadString("KyvosDatabase_LongDescription"),
                Documentation.Examples = {[
                  Description = Extension.LoadString("ExampleKyvosDescription"), 
                  Code = "Kyvos.Databases(""localhost:8081"")",
                  Result = Extension.LoadString("ExampleKyvosResult")
                ]}
            ])
    in
        Value.ReplaceType(Function, WithDocumentation);

KyvosODBCDatabase = (server as text, httpPath as text,encryption as text) as table =>
    let
        ServerValues = SplitUrl(server),
        actualServerName = List.First(ServerValues),
        port = List.Last(ServerValues),
        Database = KyvosODBCDatabaseCommon(actualServerName, httpPath, port, encryption)
    in
        Database;

KyvosODBCDatabaseCommon = (server as text, httpPath as text, port as text, encryption as text) as table =>
    let
        ConnectionString = [
            Driver = "Kyvos ODBC Driver", 
            Host = server,
            Port = port,
            AuthMech=3,
            HTTPPath=httpPath,
            SSL = GetEncryptionValue(encryption)
        ],

        Credential = Extension.CurrentCredential(),
        CredentialConnectionString =
            if Credential[AuthenticationKind]? = "UsernamePassword" then
                // set connection string parameters used for basic authentication
                [UserName  = Credential[Username], PWD  = Credential[Password]]
            else if Credential[AuthenticationKind]? = "OAuth" then
            let
                AccessToken = Credential[access_token],
                Props = Credential[Properties],
                IDToken = Props[id_token]
            in
                if AccessToken <> null then
                    [
                        ACCESSTOKEN = AccessToken,
                        IDTOKEN = IDToken,
                        ACCESSTOKENISSUETIME = "",
                        ACCESSTOKENEXPIREIN = "",
                        CLIENTID = "",
                        CLIENTSECRET = "",
                        OAuthClient = "desktop",
                        OAUTHUSERNAME = "",
                        Host = server,
                        HTTPPath = httpPath,
                        AuthMech = 2
                        // Add any additional OAuth parameters as needed
                    ]
                else
                    error "Access token not found in the Credential record"
            else
                error Error.Record("Error", "Unhandled authentication kind: " & Credential[AuthenticationKind]?),

         defaultConfig = Diagnostics.LogValue("BuildOdbcConfig", BuildOdbcConfig()),
         
        SqlCapabilities = Diagnostics.LogValue(
            "SqlCapabilities_Options", defaultConfig[SqlCapabilities] & [
                // Place custom overrides here
                // The values below are required for the SQL Native Client ODBC driver, but might
                // not be required for your data source.
                SupportsTop = false,
                SupportsDerivedTable = true,
                Sql92Conformance = 8 /* SQL_SC_SQL92_FULL */,
               // GroupByCapabilities = 4 /* SQL_GB_NO_RELATION */,
                // Sql92Translation = "PassThrough",
                FractionalSecondsScale = 3
            ]
        ),
        // Please refer to the ODBC specification for SQLGetInfo properties and values.
        // https://github.com/Microsoft/ODBC-Specification/blob/master/Windows/inc/sqlext.h
        SQLGetInfo = Diagnostics.LogValue(
            "SQLGetInfo_Options",
            defaultConfig[SQLGetInfo]
                & [
                    // Place custom overrides here
                    // The values below are required for the SQL Native Client ODBC driver, but might
                    // not be required for your data source.
                    SQL_SQL92_PREDICATES = ODBC[SQL_SP][All],
                    SQL_AGGREGATE_FUNCTIONS = ODBC[SQL_AF][All]
                ]
        ),
        // SQLGetTypeInfo can be specified in two ways:
        // 1. A #table() value that returns the same type information as an ODBC
        //    call to SQLGetTypeInfo.
        // 2. A function that accepts a table argument, and returns a table. The
        //    argument will contain the original results of the ODBC call to SQLGetTypeInfo.
        //    Your function implementation can modify/add to this table.
        //
        // For details of the format of the types table parameter and expected return value,
        // please see: https://docs.microsoft.com/en-us/sql/odbc/reference/syntax/sqlgettypeinfo-function
        //
        // The sample implementation provided here will simply output the original table
        // to the user trace log, without any modification.
        SQLGetTypeInfo = (types) =>
            if (EnableTraceOutput <> true) then
                types
            else
                let
                    // Outputting the entire table might be too large, and result in the value being truncated.
                    // We can output a row at a time instead with Table.TransformRows()
                    rows = Table.TransformRows(types, each Diagnostics.LogValue("SQLGetTypeInfo " & _[TYPE_NAME], _)),
                    toTable = Table.FromRecords(rows)
                in
                    Value.ReplaceType(toTable, Value.Type(types)),
        // SQLColumns is a function handler that receives the results of an ODBC call
        // to SQLColumns(). The source parameter contains a table with the data type
        // information. This override is typically used to fix up data type mismatches
        // between calls to SQLGetTypeInfo and SQLColumns.
        //
        // For details of the format of the source table parameter, please see:
        // https://docs.microsoft.com/en-us/sql/odbc/reference/syntax/sqlcolumns-function
        //
        // The sample implementation provided here will simply output the original table
        // to the user trace log, without any modification.
        SQLColumns = (catalogName, schemaName, tableName, columnName, source) =>
            if (EnableTraceOutput <> true) then
                source
            else
            // the if statement conditions will force the values to evaluated/written to diagnostics
            if (
                Diagnostics.LogValue("SQLColumns.TableName", tableName) <> "***"
                and Diagnostics.LogValue("SQLColumns.ColumnName", columnName) <> "***"
            ) then
                let
                    // Outputting the entire table might be too large, and result in the value being truncated.
                    // We can output a row at a time instead with Table.TransformRows()
                    rows = Table.TransformRows(source, each Diagnostics.LogValue("SQLColumns", _)),
                    toTable = Table.FromRecords(rows)
                in
                    Value.ReplaceType(toTable, Value.Type(source))
            else
                source,

          // Remove null fields from the ConnectionString
        ConnectionStringNoNulls = Record.SelectFields(
            ConnectionString, Table.SelectRows(Record.ToTable(ConnectionString), each [Value] <> null)[Name]
        ),

        OdbcDatasource = Odbc.DataSource(
            ConnectionStringNoNulls,
            [
                // A logical (true/false) that sets whether to view the tables grouped by their schema names
                HierarchicalNavigation = true,
                // Allows upconversion of numeric types
                SoftNumbers = true,
                // Allow upconversion / resizing of numeric and string types
                TolerateConcatOverflow = true,
                // Enables connection pooling via the system ODBC manager
                ClientConnectionPooling = true,
                // These values should be set by previous steps
                CredentialConnectionString = CredentialConnectionString,
                SqlCapabilities = SqlCapabilities,
                SQLColumns = SQLColumns,
                SQLGetInfo = SQLGetInfo,
                SQLGetTypeInfo = SQLGetTypeInfo,
                OnError = OnOdbcError
            ]
        )
    in
        OdbcDatasource;
 
// build settings based on configuration variables
BuildOdbcConfig = () as record =>
    let
        Merge = (previous as record, optional caps as record, optional funcs as record, optional getInfo as record) as record =>
            let
                newCaps = if (caps <> null) then previous[SqlCapabilities] & caps else previous[SqlCapabilities],
                newFuncs = if (funcs <> null) then previous[SQLGetFunctions] & funcs else previous[SQLGetFunctions],
                newGetInfo = if (getInfo <> null) then previous[SQLGetInfo] & getInfo else previous[SQLGetInfo]
            in
                [SqlCapabilities = newCaps, SQLGetFunctions = newFuncs, SQLGetInfo = newGetInfo],
        defaultConfig = [
            SqlCapabilities = [],
            SQLGetFunctions = [],
            SQLGetInfo = []
        ],
        withParams =
            if (Config_UseParameterBindings = false) then
                let
                    caps = [
                        SupportsNumericLiterals = true,
                        SupportsStringLiterals = true,
                        SupportsOdbcDateLiterals = true,
                        SupportsOdbcTimeLiterals = true,
                        SupportsOdbcTimestampLiterals = true
                    ],
                    funcs = [
                        SQL_API_SQLBINDPARAMETER = false
                    ]
                in
                    Merge(defaultConfig, caps, funcs)
            else
                defaultConfig,
        withEscape =
            if (Config_StringLiterateEscapeCharacters <> null) then
                let
                    caps = [
                        StringLiteralEscapeCharacters = Config_StringLiterateEscapeCharacters
                    ]
                in
                    Merge(withParams, caps)
            else
                withParams,
        withLimitClauseKind = let caps = [
            LimitClauseKind = Config_LimitClauseKind
        ] in Merge(withEscape, caps),
        withCastOrConvert =
            if (Config_UseCastInsteadOfConvert <> null) then
                let
                    value =
                        if (Config_UseCastInsteadOfConvert = true) then
                            ODBC[SQL_FN_CVT][SQL_FN_CVT_CAST]
                        else
                            ODBC[SQL_FN_CVT][SQL_FN_CVT_CONVERT],
                    getInfo = [
                        SQL_CONVERT_FUNCTIONS = value
                    ]
                in
                    Merge(withLimitClauseKind, null, null, getInfo)
            else
                withLimitClauseKind,
        withSqlConformance =
            if (Config_SqlConformance <> null) then
                let
                    getInfo = [
                        SQL_SQL_CONFORMANCE = Config_SqlConformance
                    ]
                in
                    Merge(withCastOrConvert, null, null, getInfo)
            else
                withCastOrConvert
    in
        withSqlConformance;
 
  // Handles ODBC errors.
OnOdbcError = (errorRecord as record) =>
    let
        ErrorMessage = errorRecord[Message],
        ConnectionHostPort = errorRecord[Detail][DataSourcePath], // Type Text. { Host, Port }

        IsDriverNotInstalled = Text.Contains(ErrorMessage, "doesn't correspond to an installed ODBC driver"),

        OdbcError = errorRecord[Detail][OdbcErrors]{0},
        OdbcErrorCode = OdbcError[NativeError],

        IsODBCUnreachable =
            OdbcErrorCode = 1020, // ODBC server can not be reached on the given host
        IsEncryptionError =
            OdbcErrorCode = 1130 or OdbcErrorCode = 1160 // Connecting using SSL/TLS to an non-SSL/TLS socket
    in
        if IsDriverNotInstalled then
            error Error.Record("DataSource.Error", "The Kyvos ODBC driver is not installed on the host. Please install the appropriate driver. " & ConnectionHostPort)
        else if IsODBCUnreachable then
            error Error.Record("DataSource.Error", "Could not connect to server. Please double check your ODBC configuration. " & ConnectionHostPort)
        else
            error errorRecord;

//
// Load common library functions
//
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name), asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);
 
// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
 
Diagnostics.LogValue = if (EnableTraceOutput) then Diagnostics[LogValue] else (prefix, value) => value;
 
// OdbcConstants contains numeric constants from the ODBC header files, and a
// helper function to create bitfield values.
ODBC = Extension.LoadFunction("OdbcConstants.pqm");