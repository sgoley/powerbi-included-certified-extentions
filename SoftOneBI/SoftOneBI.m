[Version = "1.0.0"]
section SoftOneBI;

// 
// URIs
// 
client_id =  "326c214b-f0fd-4433-b78f-016b6d81c835"; 
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
token_uri = "https://softone.oncloud.gr/login/main.ashx?op=token"; 
authorize_uri = "https://softone.oncloud.gr/login/index_edge.html?name=flow&appId=736&";
logout_uri = "https://login.microsoftonline.com/logout.srf";
base_url = "https://s1datalakeprod01.dfs.core.windows.net";

windowWidth = 720;
windowHeight = 1024;

scope_prefix =  Extension.LoadString("scope_prefix");

scopes = {
    Extension.LoadString("scope")
};


[DataSource.Kind="SoftOneBI", Publish="SoftOneBI.Publish"]
shared SoftOneBI.Contents = Value.ReplaceType(CreateNavTable, NavTableType);

NavTableType = type function ()
    as table meta [
        Documentation.Name = Extension.LoadString("ButtonTitle"),
        Documentation.LongDescription = Extension.LoadString("LongDescription"),
        Documentation.Examples = {[
            Description = Extension.LoadString("ExamplesDescription"),
            Code = "SoftOneBI.Contents()",
            Result = "#table({""Name""}, {""ItemKind""}, {""ItemName""}, {""Data""}, {""IsLeaf""}, {{""Companies""}, {""Table""}, {""Table""}, {""Table""}, {""true""}})"
        ]}
    ];


CreateNavTable = () as table =>
    let
        no_data = Table.FromRecords({ [ #"No Data" = Extension.LoadString("no_data_msg") ] }),

        serial = Extension.CurrentCredential()[Properties][serial],
        result = LoadTables(serial),
        source = #table({"Name"},  result),
        sourceK=Table.AddColumn(source, "ItemKind", each  "Table"),
        sourceN=Table.AddColumn(sourceK, "ItemName", each  "Table"),
        sourceD=Table.AddColumn(sourceN, "Data", each  try GetTable(serial, [Name]) otherwise no_data),
        sourceL=Table.AddColumn(sourceD, "IsLeaf", each  "true"),
        navTable = Table.ToNavigationTable(sourceL, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;


ChangeType = (TableData,current) =>
    let  
        values = Text.Split(current, ","),
        name=values{0},
        valueType=values{1},  
            result =
        if (valueType = "datetime") then
            Table.TransformColumnTypes(TableData, {{name, type datetime}})
        else if (valueType = "string") then
            Table.TransformColumnTypes(TableData, {{name, type text}})
        else if (valueType = "integer") then
            Table.TransformColumnTypes(TableData, {{name, Int32.Type}}) 
        else if (valueType = "float") then
            Table.TransformColumnTypes(TableData, {{name, type number}})         
        else
            Table.TransformColumnTypes(TableData, {{name, type text}})
    in
       result;


// unzip the zipped csv files
unzip = (ZIPFile) => 
    let
        Header = BinaryFormat.Record([
            MiscHeader = BinaryFormat.Binary(14),
            BinarySize = BinaryFormat.ByteOrder(BinaryFormat.UnsignedInteger32, ByteOrder.LittleEndian),
            FileSize   = BinaryFormat.ByteOrder(BinaryFormat.UnsignedInteger32, ByteOrder.LittleEndian),
            FileNameLen= BinaryFormat.ByteOrder(BinaryFormat.UnsignedInteger16, ByteOrder.LittleEndian),
            ExtrasLen  = BinaryFormat.ByteOrder(BinaryFormat.UnsignedInteger16, ByteOrder.LittleEndian)    
        ]),

        HeaderChoice = BinaryFormat.Choice(
            BinaryFormat.ByteOrder(BinaryFormat.UnsignedInteger32, ByteOrder.LittleEndian),
            each if _ <> 67324752                     // not the IsValid number? then return a dummy formatter
                then BinaryFormat.Record([IsValid = false, Filename=null, Content=null])
                else BinaryFormat.Choice(
                        BinaryFormat.Binary(26),      // Header payload - 14+4+4+2+2
                        each BinaryFormat.Record([
                            IsValid = true,
                            Filename = BinaryFormat.Text(Header(_)[FileNameLen]), 
                            Extras = BinaryFormat.Text(Header(_)[ExtrasLen]), 
                            Content = BinaryFormat.Transform(
                                BinaryFormat.Binary(Header(_)[BinarySize]),
                                (x) => try Binary.Buffer(Binary.Decompress(x, Compression.Deflate)) otherwise null
                            )
                            ]),
                            type binary              // enable streaming
                    )
        ),

        ZipFormat = BinaryFormat.List(HeaderChoice, each _[IsValid] = true),

        Entries = List.Transform(
            List.RemoveLastN( ZipFormat(ZIPFile), 1),
            (e) => [FileName = e[Filename], Content = e[Content] ]
        )
    in
        Table.FromRecords(Entries);


// Parse JSON response for table
ParseTable = (serial as text, Source as any) as table =>
    let
        data = Source[paths],
        dataTbl = Table.FromRecords(data, {"name"}, MissingField.UseNull),
        zippedTbls = Table.SelectRows(dataTbl, each Text.EndsWith([name], ".zip")),
        unzippedContent=Table.AddColumn(zippedTbls, "CONTENT", each unzip(Web.Contents(base_url, [RelativePath=Text.Combine({serial, "/", [name]}) ]))),
        keepContent = Table.SelectColumns(unzippedContent, {"CONTENT"}),
        getBinary = Table.ExpandTableColumn(keepContent, "CONTENT", {"Content"}, {"BINARY"}),
        csvs = Table.AddColumn(getBinary, "CSVS", each Table.Skip(Table.PromoteHeaders(Csv.Document([BINARY], [Delimiter = ";", Encoding = 65001, QuoteStyle = QuoteStyle.None]), [PromoteAllScalars = true]), 1)),
        tblOnlyContent = Table.SelectColumns(csvs, {"CSVS"}),
        tblList = Table.Column(tblOnlyContent, "CSVS"),
        tblComb = Table.Combine(tblList),
        csvs2 = Table.PromoteHeaders(Csv.Document(getBinary{0}[BINARY], [Delimiter = ";", Encoding = 65001, QuoteStyle = QuoteStyle.None]), [PromoteAllScalars = true]), 
        colTypeList = csvs2{0},
        colTypeListToTable = Record.ToTable(colTypeList),
        typesList = Table.ToList(colTypeListToTable),
        afterTypeChange = List.Accumulate(typesList, tblComb, (state, current) => ChangeType(state,current))
    in
        afterTypeChange;


// Retrieve table files from datalake filesystem/folder
GetTable = (serial as text ,tablename as text) as table =>
    let
        response = Web.Contents(base_url, [RelativePath = serial, Query = [resource = "filesystem", recursive = "true", directory = tablename]]),
        jsonResult = ParseTable(serial, Json.Document(response))
    in
        jsonResult;  


loadTableErrors = 
    let
        errors.badRequest = Record.AddField(Error.Record(Extension.LoadString("lte_http_400"), Extension.LoadString("lte_http_400_msg")), "Status", 400),
        errors.resourceNotFound = Record.AddField(Error.Record(Extension.LoadString("lte_http_404"), Extension.LoadString("lte_http_404_msg")), "Status", 404),
        errors.backendError = Record.AddField(Error.Record(Extension.LoadString("lte_http_500"), Extension.LoadString("lte_http_500_msg")), "Status", 500),
        errors.serviceUnavailable = Record.AddField(Error.Record(Extension.LoadString("lte_http_503"), Extension.LoadString("lte_http_503_msg")), "Status", 503),
        errors.table = Table.FromRecords({errors.badRequest, 
                                          errors.resourceNotFound, 
                                          errors.backendError, 
                                          errors.serviceUnavailable})
    in 
        errors.table;


ParseNavTable = (source as binary) =>
    let
        jsonDoc = Json.Document(source),
        paths = jsonDoc[paths],
        tbls = Table.FromRecords(paths,{"name", "isDirectory"}, MissingField.UseNull),
        filteredRows = Table.SelectRows(tbls, each ([isDirectory] = "true")),
        xx = Table.Column(filteredRows, "name"),
        yy = Table.FromList(xx),
        selected = Table.SelectRows(yy, each Text.Contains([Column1], "/") = false),
        tblList = Table.ToRows(selected)
    in  
        tblList;


// Load all tables from the datalake
LoadTables = (serial as text) =>
    let
        response = Web.Contents(base_url, [RelativePath = serial , Query = [resource = "filesystem", recursive = "true"], ManualStatusHandling = {400, 404, 500, 503}]),
        responseMetadata = Value.Metadata(response),
        responseCode = responseMetadata[Response.Status],
        responseHeaders = responseMetadata[Headers],
        jsonResult = if (responseCode <> 200)
                     then error loadTableErrors{List.PositionOf(loadTableErrors[Status], responseCode)} 
                     else ParseNavTable(response)
    in
        jsonResult;    


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


//
// Data Source definition
//
SoftOneBI = [
    TestConnection = (dataSourcePath) as list => { "SoftOneBI.Contents" },
    Authentication = [
         OAuth = [
             StartLogin = StartLogin,
             FinishLogin = FinishLogin,
             Refresh = Refresh,
             Logout = Logout
         ]
    ],
    Label = Extension.LoadString("ButtonTitle")
];


//
// UI Export definition
//
SoftOneBI.Publish = [
    Beta = true,
    Category = Extension.LoadString("Category"),
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = Extension.LoadString("LearnMoreUrl"),
    SourceImage = SoftOneBI.Icons,
    SourceTypeImage = SoftOneBI.Icons
];


SoftOneBI.Icons = [
    Icon16 = { Extension.Contents("Softone16.png"), Extension.Contents("Softone20.png"), Extension.Contents("Softone24.png"), Extension.Contents("Softone32.png") },
    Icon32 = { Extension.Contents("Softone32.png"), Extension.Contents("Softone40.png"), Extension.Contents("Softone48.png"), Extension.Contents("Softone64.png") }
];


//
// OAuth implementation
//
// See the following links for more details on AAD/Graph OAuth:
// * https://docs.microsoft.com/en-us/azure/active-directory/active-directory-protocols-oauth-code 
// * https://graph.microsoft.io/en-us/docs/authorization/app_authorization
//
// StartLogin builds a record containing the information needed for the client
// to initiate an OAuth flow. Note for the AAD flow, the display parameter is
// not used.
//
// resourceUrl: Derived from the required arguments to the data source function
//              and is used when the OAuth flow requires a specific resource to 
//              be passed in, or the authorization URL is calculated (i.e. when
//              the tenant name/ID is included in the URL). In this example, we
//              are hardcoding the use of the "common" tenant, as specified by
//              the 'authorize_uri' variable.
// state:       Client state value we pass through to the service.
// display:     Used by certain OAuth services to display information to the
//              user.
//
// Returns a record containing the following fields:
// LoginUri:     The full URI to use to initiate the OAuth flow dialog.
// CallbackUri:  The return_uri value. The client will consider the OAuth
//               flow complete when it receives a redirect to this URI. This
//               generally needs to match the return_uri value that was
//               registered for your application/client. 
// WindowHeight: Suggested OAuth window height (in pixels).
// WindowWidth:  Suggested OAuth window width (in pixels).
// Context:      Optional context value that will be passed in to the FinishLogin
//               function once the redirect_uri is reached. 
//
StartLogin = (resourceUrl, state, display) =>
    let
        authorizeUrl = authorize_uri & Uri.BuildQueryString([
            client_id = client_id,  
            redirect_uri = redirect_uri,
            state = state,
            scope = "offline_access " & GetScopeString(scopes, scope_prefix),
            response_type = "code",
            response_mode = "query",
            login = "login"
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = 720,
            WindowWidth = 1024,
            Context = null
        ];


// FinishLogin is called when the OAuth flow reaches the specified redirect_uri. 
// Note for the AAD flow, the context and state parameters are not used. 
// //
// context:     The value of the Context field returned by StartLogin. Use this to 
//              pass along information derived during the StartLogin call (such as
//              tenant ID)
// callbackUri: The callbackUri containing the authorization_code from the service.
// state:       State information that was specified during the call to StartLogin. 
FinishLogin = (context, callbackUri, state) =>
    let
        // parse the full callbackUri, and extract the Query string
        parts = Uri.Parts(callbackUri)[Query],
        // if the query string contains an "error" field, raise an error
        // otherwise call TokenMethod to exchange our code for an access_token
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    TokenMethod("authorization_code", "code", parts[code])
    in
        result;


// Called when the access_token has expired, and a refresh_token is available.
Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", "refresh_token", refresh_token);


Logout = (token) => logout_uri;

 
// grantType:  Maps to the "grant_type" query parameter.
// tokenField: The name of the query parameter to pass in the code.
// code:       Is the actual code (authorization_code or refresh_token) to send to the service.
TokenMethod = (grantType, tokenField, code) =>
    let 
        tokenResponse = Web.Contents(token_uri & "&" & Uri.BuildQueryString([ code = code ])),
        body = Json.Document(tokenResponse),
        result =  
            if (Record.HasFields(body, {"error", "error_description"})) 
            then error Error.Record(body[error], body[error_description], body)
            else body
    in
        result;


//
// Helper Functions
//
Value.IfNull = (a, b) => if a <> null then a else b;


GetScopeString = (scopes as list, optional scopePrefix as text) as text =>
    let
        prefix = Value.IfNull(scopePrefix, ""),
        addPrefix = List.Transform(scopes, each prefix & _),
        asText = Text.Combine(addPrefix, " ")
    in
        asText;


