[Version = "2.3.0"]
section Anaplan;

// OAuth2 values
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
logout_uri = "https://login.microsoftonline.com/logout.srf";
scope_prefix = "";
scopes = {
    "openid"
};

//basic auth url values
prodApiHost = "https://api.anaplan.com";
prodAuthHost = "https://us1a.app.anaplan.com";

// Login window dimensions
windowWidth = 850;
windowHeight = 1200;
codeVerifier = Text.NewGuid() & Text.NewGuid();

ClientIds = [
	chimera = "hV0MX4pUs4AyFvjEe1TuQ2D4uCc1qKTn",
	r2p2 = "UqDxVaF80i2I0kDvREDQ8UqoOo7yeGz8",
	rke = "qDAbpAhINMHv3S1G7N8kIHas4OOJCZgG",
	ast = "ozy670BBq1j4dkSIJtKnA3jsmUL8etdp",
	gst = "ky6c2RtYrLSQO1BY9izCVhFcQzvVg3bP",
	aus_stg = "meUM999HWMA9R966XdMPNmyaJkP7j4lQ",
	aus_prod = "HhjwtBUkCnOw4c4U7s5YVlthhDTW0c27",
	ca_stg = "kVBkaQFH3PXDehVsvylxv3TZyPAhgT4C",
	ca_prod = "cThN0RZSzFmNqMUjOe8hiN6q25XWQox6",
	eu_prod = "l1mKhyPY4dCJEoxDOr6VZNomeQE9gMoT"
];

// Helper functions
Base64UrlEncodeWithoutPadding = (hash as binary) as text =>
    let
        base64Encoded = Binary.ToText(hash, BinaryEncoding.Base64),
        base64UrlEncoded = Text.Replace(Text.Replace(base64Encoded, "+", "-"), "/", "_"),
        withoutPadding = Text.TrimEnd(base64UrlEncoded, "=")
    in 
        withoutPadding;

// OAuth2 functions
StartLogin = (resourceUrl, state, display) =>
    let
        // we'll generate our code verifier using Guids
        codeVerifier = Text.NewGuid() & Text.NewGuid(),
        json = Json.Document(resourceUrl),
        oauthAuthUrl = json[authUrl],
        oauthHost = if oauthAuthUrl <> null and IsValidUrl(oauthAuthUrl) then Uri.Parts(oauthAuthUrl)[Host] else Uri.Parts(prodAuthHost)[Host],

        AuthorizeUrl = "https://" & oauthHost & "/auth/authorize?" & Uri.BuildQueryString([
            client_id = PickClientId(oauthHost),
            response_type = "code",            
            code_challenge_method = "plain",
            code_challenge = codeVerifier,
            state = state,
            redirect_uri = redirect_uri])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = [ codeVerifier = codeVerifier, tokenHost = oauthHost]
        ];

// access_token, refresh_token, expires all become available from the evaluation of TokenMethod
// to utilize the value of access_token anywhere: Extension.CurrentCredential()[access_token]
// onPowerBI forum: In FinishLogin, it's just all of the properties on the top-level record other than the three we define explicitly (access_token, refresh_token, expires). 
// So if you wanted to set an extra value "token", you'd return the record [access_token="None", token="token"].
// The inconsistency is that when you call Extension.CurrentCredential, the record you get back will look like [AuthenticationKind="OAuth", access_token="None", Properties=[token="token"]]
// and the values all have to be text
FinishLogin = (context, callbackUri, state) =>
    let
        parts = Uri.Parts(callbackUri)[Query]
    in
        TokenMethod(parts[code], "authorization_code", context[tokenHost]?, context);

Refresh = (clientApplication, dataSourcePath, oldCredential) =>
    let
		token_host = if (Record.HasFields(oldCredential, "tokenHost") and oldCredential[tokenHost] <> null) then oldCredential[tokenHost] else TokenHostNotFoundMessage,
        result =  TokenMethod(oldCredential[refresh_token], "refresh_token", token_host)
    in
        result;

TokenMethod = (fieldValue, grantType, optional tokenHost, optional context) =>
    let
        codeVerifier = if (context <> null) then [code_verifier = context[codeVerifier]?] else [],
		token_host = if (tokenHost <> null) then tokenHost else prodAuthHost,
        codeParameter = if (grantType = "authorization_code") then [ code = fieldValue ] else [ refresh_token = fieldValue ],
        query = codeVerifier & codeParameter & [
            client_id = PickClientId(tokenHost),
            grant_type = grantType,
            redirect_uri = redirect_uri
        ],
        full_token_uri = "https://" & token_host & "/oauth/token",
        Response = Web.Contents(full_token_uri, [
            Content = Text.ToBinary(Uri.BuildQueryString(query)),
            Headers=[
            #"Content-type" = "application/x-www-form-urlencoded",
            #"Accept" = "application/json",
            #"X-AUTH-TOKEN" = "true"]]),
        Parts = Json.Document(Response)
    in
        // check for error in response
        if (Parts[error]? <> null) then 
            error Error.Record(Parts[error], Parts[message]?)
        else
            Parts & [ tokenHost = tokenHost ];

PickClientId = (oauthHost as text) =>
    let
        clientId = if (Text.Contains(oauthHost, "chimera")) then ClientIds[chimera] 
					else if(Text.Contains(oauthHost, "r2p2")) then ClientIds[r2p2] 
					else if(Text.Contains(oauthHost, "amazon")) then ClientIds[ast] 
					else if(Text.Contains(oauthHost, "google")) then ClientIds[gst] 
					else if(Text.Contains(oauthHost, "au1a.app2-stg")) then ClientIds[aus_stg]
					else if(Text.Contains(oauthHost, "au1a.app2.anaplan")) then ClientIds[aus_prod]
					else if(Text.Contains(oauthHost, "ca1a.app-stg.anaplan")) then ClientIds[ca_stg]
					else if(Text.Contains(oauthHost, "ca1a.app.anaplan") or Text.Contains(oauthHost, "ca2a.app.anaplan") or Text.Contains(oauthHost, "ca.app.anaplan")) then ClientIds[ca_prod]
					else if(Text.Contains(oauthHost, "eu3.app.anaplan")) then ClientIds[eu_prod]
					else ClientIds[rke]
    in
        clientId;

/// Data Source Kind description
Anaplan = [
    TestConnection = (dataSourcePath) => 
        let
            json = Json.Document(dataSourcePath),
            apiUrl = json[apiUrl],
            authUrl = json[authUrl]
        in
            { "Anaplan.Contents", apiUrl, authUrl},
    Authentication = [
        OAuth = [
            StartLogin=StartLogin,
            FinishLogin=FinishLogin,
            Refresh=Refresh
        ],
        UsernamePassword = []
    ],
    Label = Extension.LoadString("Anaplan")
];

/// Data Source UI publishing description
Anaplan.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { "Anaplan", "Anaplan" }, 
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = AnaplanPowerBIConnector.Icons,
    SourceTypeImage = AnaplanPowerBIConnector.Icons
];

AnaplanPowerBIConnector.Icons = [
    Icon16 = { Extension.Contents("AnaplanConnector16.png"), Extension.Contents("AnaplanConnector20.png"), Extension.Contents("AnaplanConnector24.png"), Extension.Contents("AnaplanConnector32.png") },
    Icon32 = { Extension.Contents("AnaplanConnector32.png"), Extension.Contents("AnaplanConnector40.png"), Extension.Contents("AnaplanConnector48.png"), Extension.Contents("AnaplanConnector64.png") }
];

/// 
/// Defaults & Constants declarations
///
ExportsMinId = 115999999999;
MinExpirationTime = 5;
ExcelFormat = "application/vnd.ms-excel";

ErrorStatus = [
    ExportRun = 1,
    FileDownload = 2,
    LargeFile = 3,
    FileFormat = 4,
    ServiceError = 5
];

ConfigParamsIndex = [
    apiToken = 0,
    apiUrl = 1,
    authUrl = 2
];

TaskInProgressMessage = [
    Header = Extension.LoadString("TaskInProgress"),
    Message = Extension.LoadString("TaskInProgressMsg"),
    MessageTable = #table({Header},{{Message}})
];

TokenHostNotFoundMessage = [
    Header = Extension.LoadString("TokenHostNotFound"),
    Message = Extension.LoadString("TokenHostNotFoundMsg"),
    MessageTable = #table({Header},{{Message}})
];
 
[DataSource.Kind="Anaplan", Publish="Anaplan.Publish"]
shared Anaplan.Contents = Value.ReplaceType(Anaplan.Connect, AnaplanType);

///
/// Documentation & metadata definitions for connection configuration UI
///
AnaplanType = type function (
    apiUrl as (type text meta [
        Documentation.FieldCaption = "Anaplan API URL",
        Documentation.FieldDescription = "Ex: https://api.anaplan.com",
        Documentation.SampleValues = {"https://api.anaplan.com"}  
    ]),
    authUrl as (type text meta [
        Documentation.FieldCaption = "Anaplan Auth URL",
        Documentation.FieldDescription = "Ex: https://us1a.app.anaplan.com",
        Documentation.SampleValues = {"https://us1a.app.anaplan.com"}
    ])
    )
    as table meta [
        Documentation.Name = "Anaplan Connection Configuration"
    ];

///
/// Validates if user inputted URL is valid by checking first for "https" and that the user entered a host
///
IsValidUrl = (url as text) as logical => (Uri.Parts(url)[Scheme] = "https" and Uri.Parts(url)[Host] <> null and Text.Contains(Uri.Parts(url)[Host], "anaplan"));

///
/// Main entry point of connector that takes as arguments user input
///
Anaplan.Connect = (apiUrl as text, authUrl as text) as table =>
    let 
        credential = Extension.CurrentCredential() as record,
        configParams = if Record.HasFields(credential, "Username") then
          let
              apiUrl = if apiUrl <> null and IsValidUrl(apiUrl) then (apiUrl & Extension.LoadString("APIVersionPath")) else prodApiHost & Extension.LoadString("APIVersionPath"),
              authUrl = if authUrl <> null and IsValidUrl(authUrl) then authUrl else prodAuthHost,
              apiTokenTry = GetApiToken(authUrl, false),
              authUrlValidated = if apiTokenTry <> null then authUrl else if GetApiToken(prodAuthHost, false) <> null then prodAuthHost else Extension.CurrentCredential(true),
              apiToken = GetApiToken(authUrlValidated, false)
          in
              List.Buffer({apiToken[tokenValue], apiUrl, authUrl})
        else List.Buffer({Extension.CurrentCredential()[access_token], apiUrl & Extension.LoadString("APIVersionPath")}),
        source = GetWorkspacesTable(configParams)
    in 
        source as table;


///
/// Anaplan Workspaces - List of workspaces that user has access to
/// 
GetWorkspacesTable = (configParams as list) as table =>
    let
        workspacesUrl = configParams{ConfigParamsIndex[apiUrl]} & "workspaces",
        navTable = try TransformWorkspaceTable(GetWebContents) otherwise EmptyNavTable(),

        TransformWorkspaceTable = (call as function) =>
            let
                json = () => call(workspacesUrl, configParams)[workspaces],
                workspaces = Table.FromList(json(), Splitter.SplitByNothing(), null, null, ExtraValues.Ignore),
                workspacesExpanded = Table.ExpandRecordColumn(workspaces, "Column1", {"id", "name"}),
                reKey    = Table.RenameColumns(workspacesExpanded, ({"id", "key"})),
                reName   = Table.RenameColumns(reKey, ({"name","Name"})),
                withData = Table.AddColumn(reName, "Data", each GetModelsTable(configParams, [key]), Table.Type),
                withKind = Table.AddColumn(withData, "ItemKind", each "Folder", Text.Type),
                withName = Table.AddColumn(withKind, "ItemName", each "Table", Text.Type),
                withLeaf = Table.AddColumn(withName, "IsLeaf", each false, Logical.Type),
                asNav = Table.ToNavigationTable(withLeaf, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
            in
                asNav
    in
        navTable;

///
/// Anaplan Models - list of all models belonging to the parent workspace
///
GetModelsTable = (configParams as list, key as text) as table =>
    let
        workspaceModelsUrl = configParams{ConfigParamsIndex[apiUrl]} & "models",
        resp = GetWebContents(workspaceModelsUrl, configParams),
        navTable = if resp <> null and resp[models]? <> null then TransformModelTable(resp) else if HasClientError(resp) then EmptyNavTable() else ErrorTable(0, resp[err][status]),

        TransformModelTable = (json as any) =>
            let
                table = Table.FromList(List.Select(json[models], each _[activeState] <> Extension.LoadString("ModelStatusArchived")), Splitter.SplitByNothing(), null, null, ExtraValues.Ignore),        
                workspaceModelsExpanded = Table.ExpandRecordColumn(table, "Column1", {"id", "name", "currentWorkspaceId"}),
                reKey    = Table.RenameColumns(workspaceModelsExpanded, ({"id", "key"})),
                reName   = Table.RenameColumns(reKey, ({"name","Name"})),
                currentWorkspace = Table.SelectRows(reName, each [currentWorkspaceId] = key),
                resetWorkspaceModelsUrl = configParams{1} & "workspaces/",
                withData = Table.AddColumn(currentWorkspace, "Data", each GetLabelTable(resetWorkspaceModelsUrl & [currentWorkspaceId] & "/models/" & [key], configParams), Table.Type),
                withKind = Table.AddColumn(withData, "ItemKind", each "View" , Text.Type),
                withName = Table.AddColumn(withKind, "ItemName", each "Table", Text.Type),
                withLeaf = Table.AddColumn(withName, "IsLeaf", each false, Logical.Type),
                asNav = Table.ToNavigationTable(withLeaf, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
            in 
                asNav
    in
        navTable;

///
/// Exports & Files labelled folders
///
GetLabelTable = (url as text, configParams as list) as table =>
    let
        objects = #table(
            {"Name",       "Key",        "Data", "ItemKind", "ItemName", "IsLeaf"},{
            {"Exports",     "item1",     GetExportsTable(url, configParams), "Folder",    "Table",   false}
            }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;


///
/// Exports - list of all exports belonging to a model
///
GetExportsTable = (url as text, configParams as list) as table =>
    let
        exportsUrl = url & "/exports/",
        resp = GetWebContents(exportsUrl, configParams),
        navTable = if resp <> null and resp[exports]? <> null then TransformExportsTable(resp) else EmptyNavTable(),
        
        TransformExportsTable = (json as any) =>
            let
                workspaceModels = Table.FromList(json[exports], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                workspaceModelExportsExpanded = Table.ExpandRecordColumn(workspaceModels, "Column1", {"id", "name", "exportType", "exportFormat"}),
                filterExportType = Table.SelectRows(workspaceModelExportsExpanded, each [exportFormat]="text/csv" or [exportFormat]="text/plain"),
                reKey    = Table.RenameColumns(filterExportType, ({"id", "key"})),
                reName   = Table.RenameColumns(reKey, ({"name","Name"})),       
                withData = Table.AddColumn(reName, "Data", each ExportOptions(exportsUrl, [key], configParams), Table.Type),
                withKind = Table.AddColumn(withData, "ItemKind", each "Feed", Text.Type),
                withName = Table.AddColumn(withKind, "ItemName", each "Table", Text.Type),
                withLeaf = Table.AddColumn(withName, "IsLeaf", each false, Logical.Type),
                asNav = Table.ToNavigationTable(withLeaf, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
            in
                asNav
    in
        navTable;

HasClientError = (resp as any) => resp[err]? <> null and resp[err][status] >= 400 and resp[err][status] <= 499;  


///
/// Parent folder to display options for running the selected export action and showing Tasks folder
///
ExportOptions = (url as text, exportKey as text, configParams as list) as table =>
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {{"Run Export Action","item1", RunExportAction(url, exportKey, configParams),  "Function", "Table",   true}
            // {"Tasks","item3", GetExportTasks(url, exportKey, configParams),"Folder","Table", false}
            }),
        navTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

///
/// Runs the selected export action as a POST to /export/{exportId}/tasks
///
RunExportAction = (url as text, exportKey as text, configParams as list) as table =>
    let
        status = if HasInProgressTasks(url, exportKey, configParams) then TaskInProgressMessage else PostAction(),

        PostAction = () =>
            let
                body = "{""localeName"":""en_US""}", 
                exportTaskUrl = url & exportKey & "/tasks/",
                postResponse = Binary.Buffer(Web.Contents(exportTaskUrl, [Headers = [#"Authorization" = Extension.LoadString("AnaplanAuthTokenPrefix") & configParams{ConfigParamsIndex[apiToken]}, #"Content-Type"="application/json", #"x-aconnect-client"=Extension.LoadString("AConnectHeaderValue"), #"User-Agent"=Extension.LoadString("AConnectHeaderValue")], 
                    Content = Text.ToBinary(body), ManualStatusHandling = {500, 501, 502, 503}])),

                result = Record.ToTable(Record.AddField(Json.Document(postResponse)[task], Extension.LoadString("LocalTimeField"), Date.UtcToLocal(Date.ToDateTime(Json.Document(postResponse)[task][creationTime]))))
            in
                result,

            genericUrl = Text.Replace(url,"exports/",""),
            chunkCounts = GetChunkCount(genericUrl, exportKey, configParams) 
    in 
        chunkCounts;

///
/// Returns a boolean if the selected export action has an IN_PROGRESS task
///
HasInProgressTasks = (url as text, exportKey as text, configParams as list) as logical =>
    let
        exportTaskUrl = url & "/tasks/",
        source = GetWebContents(exportTaskUrl, configParams),
        hasTasksRunning = try IsExportRunning(source) otherwise false,

        IsExportRunning = (json as any) =>
            let
                hasTasksInProgress = List.MatchesAny(source[tasks], each _[taskState] = Extension.LoadString("TaskInProgress"))
            in 
                hasTasksInProgress
    in
        hasTasksRunning;

///
/// List of all tasks previously run for an export action
///
/*
GetExportTasks = (url as text, exportKey as text, configParams as list) as table =>
    let 
        exportTaskUrl = url & exportKey & "/tasks/",
        resp = GetWebContents(exportTaskUrl, configParams),
        navTable = if resp <> null and resp[tasks]? <> null then TransformTaskTable(resp) else if HasClientError(resp) then EmptyNavTable() else ErrorTable(5, 500),

        TransformTaskTable = (json as any) => 
            let 
                tasksUpdated = List.Transform(json[tasks], each Record.AddField(_, "name", _[taskId] & " - " & _[taskState])),
                tasksUpdatedTime = List.Transform(tasksUpdated, each Record.AddField(_, Extension.LoadString("LocalTimeField"), Date.UtcToLocal(Date.ToDateTime(_[creationTime])))),
                tasksTable = Table.FromList(tasksUpdatedTime, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                tasksTableExpanded = Table.ExpandRecordColumn(tasksTable, "Column1", {"taskId", "taskState", "name", Extension.LoadString("LocalTimeField")}),
                reKey    = Table.RenameColumns(tasksTableExpanded, ({"taskId", "key"})),
                reName   = Table.RenameColumns(reKey, ({"name","Name"})),       
                withData = Table.AddColumn(reName, "Data", each _, Table.Type),
                withKind = Table.AddColumn(withData, "ItemKind", each "Feed", Text.Type),
                withName = Table.AddColumn(withKind, "ItemName", each "Table", Text.Type),
                withLeaf = Table.AddColumn(withName, "IsLeaf", each true, Logical.Type),
                asNav = Table.ToNavigationTable(withLeaf, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
            in
                asNav
     in
        navTable;
*/

///
/// Tests Chunk counts and limit count to 499
///
GetChunkCount = (url as text, exportKey as text, configParams as list) as table =>
    let 
        filesUrl = url & "files",
        exportsUrl = url & "exports/" & exportKey,
        resp = GetWebContents(filesUrl, configParams),
        metaResp = GetWebContents(exportsUrl, configParams),
        metadataTest = try metaResp[status][code] otherwise 500,

        chunkTable = 
            (if resp <> null and resp[files]? <> null then TransformFilesTable(resp) else 
            (if HasClientError(resp) or resp[meta][paging][totalSize] = 0 then EmptyNavTable() else ErrorTable(5,500))),
        
        TransformFilesTable = (json as any) =>
            let 
                table1 = Table.FromList(json[files], Splitter.SplitByNothing(), null, null, ExtraValues.Ignore),        
                workspaceModelFilesExpanded = Table.ExpandRecordColumn(table1, "Column1", {"id", "chunkCount"}),        
                workspaceModelsFilesFiltered = Table.SelectRows(workspaceModelFilesExpanded, each [id] = exportKey)
            in
                workspaceModelsFilesFiltered,

        chunkCount = chunkTable{0}[chunkCount],
        numexportKey = Number.From(exportKey),
        
        downloadFile = if metadataTest > 200 then ErrorTable(5, metadataTest) else
            (if chunkCount=null then ErrorTable(2, numexportKey) else
            (if chunkCount>=500 then ErrorTable(3, numexportKey)
            else DownloadFileChunks(url, exportKey, configParams, chunkCount)))   
        
    in
        downloadFile;

///
/// Kicks off a file download by first retrieving metadata on selected file
///
DownloadFileChunks = (url as text, exportKey as text, configParams as list, optional chunkCount as number) as table =>
    let 
        workspaceModelExportMetaUrl = url & "exports/" & exportKey,
        workspaceModelExportFileUrl = url & "files/" & exportKey,
        metadata = GetWebContents(workspaceModelExportMetaUrl, configParams),
        metadataTest = try metadata[status][code] otherwise 500,
        exportMetadata = metadata[exportMetadata],
          
        exportRun = if metadataTest=200 then GetWebContentsExportRunSuccess(url, exportKey, configParams, exportMetadata, chunkCount) else ErrorTable(5,metadataTest),
        fileList = if exportRun <> null then DownloadFileListAccumulate(workspaceModelExportFileUrl, configParams, exportMetadata, chunkCount) else ErrorTable(2, Number.From(exportKey))
    in
        fileList;

///
/// Attempts to download file via the /chunks/{chunkNum} endpoint and combines into a binary list
///        
DownloadFileListAccumulate = (url as text, configParams as list, exportMetadata as record, chunkCount as number) as table =>
    let 
        delimiter = exportMetadata[separator]?,
        columnCount = exportMetadata[columnCount]?,
        format = exportMetadata[exportFormat]?,
        chunks = chunkCount - 1,
        fileChunkUrl = url & "/chunks/",
       
        maxChunkPerToken = 100,
        iterations =  [ i = Number.IntegerDivide(chunkCount, maxChunkPerToken), j = Number.Mod(chunkCount, maxChunkPerToken) ],
        binaryList = List.Generate(()=>0, each _ <= chunks, each _ +1, each GetWebContents(fileChunkUrl & Number.ToText(_), configParams, true)),
        binaryCombined = Binary.Combine(binaryList),

        resp = try ErrorTable(2, binaryList{0}[err][status]) otherwise result,
        
        result = try if format <> null and format = ExcelFormat then Excel.Workbook(binaryCombined, false, true) else Csv.Document(binaryCombined, [Delimiter = delimiter, Columns = columnCount])
            otherwise ErrorTable(4, 999)
    in
        resp;

///
/// Main GET request handler, will return JSON by default and raw binary if optional parameter is set
///
GetWebContents = (url as text, configParams as list, optional returnRaw as logical, optional useCache as logical) => 
    let
        apiTokenValue = configParams{ConfigParamsIndex[apiToken]},
        cacheControl = if useCache <> null and not useCache then Number.ToText(Number.Random()) else "",
        source = Web.Contents(url, [Headers = [#"Authorization" = Extension.LoadString("AnaplanAuthTokenPrefix") & apiTokenValue, 
                #"x-aconnect-client"=Extension.LoadString("AConnectHeaderValue"), #"User-Agent"=Extension.LoadString("AConnectHeaderValue")
               ], 
                ManualStatusHandling = {401, 404, 500, 501, 502, 503},
                Timeout = #duration(0, 0, Number.FromText(Extension.LoadString("RequestTimeoutMinutes")), 0)]), 

        buffered = Binary.Buffer(source),
        actualResult = if Value.Metadata(source)[Response.Status] = 200 then 
            (if returnRaw <> null and returnRaw then buffered else Json.Document(buffered))
            else [ err = [status =  Value.Metadata(source)[Response.Status]]]
    in
        actualResult;

///
/// Attempts to retry a GET request to the specified URL with configured number of retries & interval
/// interval will increase with each iteration (retryInterval * 1, .... retryInterval * n - 1)
///

GetWebContentsExportRunSuccess = (url as text, exportKey as text, configParams as list, exportMetadata as record, optional chunkCount as number) as table => 
    let
        apiTokenValue = configParams{ConfigParamsIndex[apiToken]},
        exportUrl = url & "exports/"  & exportKey & "/tasks",
        fileUrl = url & "files/" & exportKey,
        body = "{""localeName"":""en_US""}",
        
        exportRunResp = Json.Document(Binary.Buffer(Web.Contents(exportUrl, [Headers = [#"Authorization" = Extension.LoadString("AnaplanAuthTokenPrefix") & apiTokenValue, #"Content-Type"="application/json", #"x-aconnect-client"=Extension.LoadString("AConnectHeaderValue"), #"User-Agent"=Extension.LoadString("AConnectHeaderValue")], 
            Content = Text.ToBinary(body), ManualStatusHandling = {500, 501, 502, 503}]))),
        
        fileDownload = (taskId as text) =>
            let
                // noCache = #"NoCache"= Number.ToText(count + Number.Random())
                getTaskStatus = (count as number) => Binary.Buffer(Web.Contents(exportUrl & "/" & taskId, 
                    [Headers = [#"Authorization" = Extension.LoadString("AnaplanAuthTokenPrefix") & apiTokenValue, #"x-aconnect-client"=Extension.LoadString("AConnectHeaderValue"), #"User-Agent"=Extension.LoadString("AConnectHeaderValue"), #"NoCache"= Number.ToText(count + Number.Random()) ]])),
         
                getTaskStatusLoop = (MaxAttempts, DelayBetweenAttempts) =>
                    let
                        Numbers = List.Numbers(1, MaxAttempts),
                        WebServiceCalls = List.Transform(Numbers, each Function.InvokeAfter(() => getTaskStatus(_), if _ > 1 then DelayBetweenAttempts else #duration(0,0,0,0))),
                        OnlySuccessful = List.Select(WebServiceCalls, each _ <> null and Json.Document(_)[task][taskState] <> Extension.LoadString("TaskInProgress")),
                        Result = List.First(OnlySuccessful, null),
                        res = if Result <> null then DownloadFileListAccumulate(fileUrl, configParams, exportMetadata, chunkCount) else ErrorTable(2, Number.From(taskId))
                    in
                        res,

                // todo: evaluate proper duration & retries
                result = getTaskStatusLoop(200, #duration(0,0,0,10))            
            in 
                result
    in
        fileDownload(exportRunResp[task][taskId]);

///
/// Retrieves an auth token from /token/authenticate endpoint using basic authentication
/// Tokens expire every 35 minutes, if 401 (Unauthorized) is encountered it will re-prompt for user credentials
///
GetApiToken = (authUrl as text, isRefresh as logical, optional noCache as number) as record =>
    let
        body = "[]",
        headers = if isRefresh then [#"CacheRemoval" = Number.ToText(noCache), #"Cache-Control" = "no-cache, no-store, must-revalidate", #"x-aconnect-client"=Extension.LoadString("AConnectHeaderValue"), #"User-Agent"=Extension.LoadString("AConnectHeaderValue")] 
            else [#"x-aconnect-client"=Extension.LoadString("AConnectHeaderValue"), #"User-Agent"=Extension.LoadString("AConnectHeaderValue")],
        tokenResponse = try getToken() otherwise null,
        
        getToken = () =>
            let
                contents = Web.Contents(authUrl, 
                    [ Headers = headers, Content=Text.ToBinary(body), 
                    ManualStatusHandling = {401},
                    RelativePath = Extension.LoadString("AuthTokenPath"),
                    Query=[Authorization="Basic encoded_username:password"]]),
                status = Value.Metadata(contents)[Response.Status], 
                tokenResponseJson = if status <> null and status = 201 then Json.Document(contents)[tokenInfo] 
                    else if status = 401 then error Extension.CredentialError("reason", "Invalid credentials") 
                    else null
            in
                tokenResponseJson
    in
        tokenResponse;

///
/// Helper function to obtain the tokenValue property 
///
GetApiTokenValue = (authUrl as text, isRefresh as logical, optional chunk as number) =>
    let 
        tokenInfo = GetApiToken(authUrl, isRefresh, chunk)[tokenValue]
    in
        tokenInfo;


// RefreshTokenInfo = (authUrl as text, currentTokenValue as text) => 
//     let 
//         body = "[]",
//         postResponse = Web.Contents(authUrl & Extension.LoadString("AuthRefreshTokenPath"), 
//             [Headers = [#"Authorization" = "AnaplanAuthToken " & currentTokenValue, #"CacheRemoval" = Number.ToText(Number.Random()), #"x-aconnect-client"=Extension.LoadString("AConnectHeaderValue"), #"User-Agent"=Extension.LoadString("AConnectHeaderValue"), 
//             #"Content-Type"="application/json", #"Cache-Control" = "no-cache, no-store, must-revalidate"], 
//             Content = Text.ToBinary(body)]),
//         refreshTokenResponse = Json.Document(postResponse)[tokenInfo]
//     in
//         refreshTokenResponse;
// 
// GetRefreshTokenValue = (authUrl as text, currentTokenValue as text) =>
//     let
//         token = RefreshTokenInfo(authUrl, currentTokenValue)[tokenValue]
//     in
//         token;
// 
// GetRefreshTokenInfo = (authUrl as text, count as number) =>
//     let
//         refreshToken = Diagnostics.LogValue("RefreshToken(apiTokenValue)[tokenInfo]: ", RefreshToken(authUrl, count)[tokenInfo]),
//         tokenList = [ token = refreshToken]
//     in
//         tokenList;


// IsValidApiUrl = (apiUrl as text, apiTokenValue as text) as logical =>
//     let
//         source = Web.Contents(apiUrl & "users/me", [Headers = [#"Authorization" = Extension.LoadString("AnaplanAuthTokenPrefix") & apiTokenValue, #"x-aconnect-client"=Extension.LoadString("AConnectHeaderValue"), #"User-Agent"=Extension.LoadString("AConnectHeaderValue")], ManualStatusHandling = {401, 500, 501, 502, 503}]), 
//         status = Value.Metadata(source)[Response.Status],
//         output = status = 200
//     in
//         output;


///
/// Exception Handling
///
EmptyNavTable = () as table =>
    let
        objects = #table(
            {"Name",       "Key",        "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            {"No data",      "item1",      "No data is available for this selection", "Sheet",    "Table",    true}
            }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

ErrorTable = (status as number, errorstatus as number) =>
    let    
        errors.generic = Record.AddField(Error.Record("Error", Extension.LoadString("ErrorGeneric")), "Status", 0),
        errors.exportRun = Record.AddField(Error.Record("Export Run Error", Extension.LoadString("ErrorExportRun")), "Status", 1),
        errors.fileDownload = Record.AddField(Error.Record("File Download Error",Extension.LoadString("ErrorFileDownload")), "Status", 2),
        errors.largeDownload = Record.AddField(Error.Record("Large File Download Error",Extension.LoadString("ErrorLargeFile")), "Status", 3),
        errors.FileFormat = Record.AddField(Error.Record("File Format Error",Extension.LoadString("ErrorFileFormat")), "Status", 4),
        errors.serviceError = Record.AddField(Error.Record("Server Error", Extension.LoadString("ErrorBackend")), "Status", 5),
        
        errors.table = Table.FromRecords({errors.exportRun, errors.fileDownload, errors.largeDownload, errors.FileFormat, errors.serviceError}),
        errorStatus = if status >= 500 and status <= 599 then 500 else status,
        foundError = try errors.table{List.PositionOf(errors.table[Status], status)} otherwise errors.table{List.PositionOf(errors.table[Status], 0)},
        errorTable = #table({"Error Reason", "Error Message", "Error Code"},{{foundError[Reason], foundError[Message], errorstatus}})
    in
        errorTable;

///
/// Common/Helper functions
///
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

Value.WaitFor = (producer as function, interval as function, optional count as number) as any =>
let
	list = List.Generate(
		//start: first try, no result
		() => {0, null},
		//condition: stop if we have the result (try count null'd) or we've exceeded the max tries
		(state) => state{0} <> null and (count = null or state{0} <= count),
		//next: stop try tally if we have our result, otherwise check again and tally a try
		(state) => if state{1} <> null
			then {null, state{1}}
			else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), interval(state{0}))},
		//transformer: only return the result, not try tally
		(state) => state{1})
in
	List.Last(list);

///
/// Date Helper Functions
///
Date.ToDateTime = (epoch as number) as any => #datetime(1970,1,1,0,0,0) + #duration(0,0,0, epoch/1000);

Date.CurrentEpoch = () as number => Duration.TotalSeconds(DateTimeZone.UtcNow() - #datetimezone(1970, 1, 1, 0, 0, 0, 0, 0));

Date.UtcToLocal = (utc as datetime) => DateTimeZone.RemoveZone(DateTimeZone.ToLocal(DateTime.AddZone(utc,0)));

Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = Diagnostics[LogValue];
