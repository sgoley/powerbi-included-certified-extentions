// This file contains the Data Connector logic
[Version = "2.4.5"]
section MicroStrategyDataset;

VERSION = "2.4.5";
DEFAULT_LIMIT = 25000;
DEFAULT_TIMEOUT = 100;
APPLICATION_TYPE = 46;
LOCALE = Extension.LoadString("Locale");
TEST_CONNECTION_TIMEOUT = 10;
OIDC_LOGIN_MODE = "4194304";

[DataSource.Kind="MicroStrategyDataset", Publish="MicroStrategyDataset.Publish"]
shared MicroStrategyDataset.Contents = Value.ReplaceType(MicroStrategyDataset.Contents.Impl, MicroStrategyDataset.Contents.Type);

// Shared version with unambigous name for TestConnection
[DataSource.Kind="MicroStrategyDataset"]
shared MicroStrategyDataset.TestConnection = Value.ReplaceType(
	(libraryUrl as text) => Rest.GetStatus([restApiUrl = FixApiUrl(libraryUrl), timeout = TEST_CONNECTION_TIMEOUT]),
	type function (libraryUrl as Uri.Type) as any
);

// Data Source Kind record; the name is (unfixably atm) displayed in the login window, hence it being so generic.
MicroStrategyDataset = [
	TestConnection = (libraryUrl as text) => {"MicroStrategyDataset.TestConnection", libraryUrl},
	Authentication = [
		UsernamePassword = [
			Label = Extension.LoadString("AuthBasicName")
		],
		OAuth = [
			Label = Extension.LoadString("AuthOAuthName"),
			StartLogin = OAuth.StartLogin,
			FinishLogin = OAuth.FinishLogin,
			Refresh = OAuth.Refresh
		]
	]
];

// Data Source UI publishing description
MicroStrategyDataset.Publish = [
	//Beta = true,
	Category = "Other",
	ButtonText = { Extension.LoadString("DataSourceName"), Extension.LoadString("ButtonHelp") },
	LearnMoreUrl = "https://lw.microstrategy.com/msdz/MSDL/GARelease_Current/docs/projects/RESTSDK/Content/topics/REST_API/REST_API.htm",
	SourceImage = MicroStrategyDataset.Icons,
	SourceTypeImage = MicroStrategyDataset.Icons
];

MicroStrategyDataset.Icons = [
	Icon16 = { Extension.Contents("MicroStrategyDataset16.png"), Extension.Contents("MicroStrategyDataset20.png"), Extension.Contents("MicroStrategyDataset24.png"), Extension.Contents("MicroStrategyDataset32.png") },
	Icon32 = { Extension.Contents("MicroStrategyDataset32.png"), Extension.Contents("MicroStrategyDataset40.png"), Extension.Contents("MicroStrategyDataset48.png"), Extension.Contents("MicroStrategyDataset64.png") }
];

MicroStrategyDataset.Contents.Type =
	let
		defaultIsStringSpaced = " " & Extension.LoadString("DefaultIs") & " ",
		libraryUrlType = Uri.Type meta [
			Documentation.FieldCaption = Extension.LoadString("ApiUrl"),
			Documentation.FieldDescription = Extension.LoadString("ApiUrlDesc"),
			Documentation.SampleValues = {Extension.LoadString("ApiUrlSample")}
		],
		authModeType = type text meta [
			Documentation.FieldCaption = Extension.LoadString("AuthMode"),
			Documentation.FieldDescription = Extension.LoadString("AuthModeDesc") & defaultIsStringSpaced & Extension.LoadString("StandardAuth"),
			Documentation.AllowedValues = {Extension.LoadString("StandardAuth"), Extension.LoadString("LDAPAuth")}
		],
		optionsType = let
				limitType = type nullable number meta [
					Documentation.FieldCaption = Extension.LoadString("LimitDesc"),
					Documentation.FieldDescription = Extension.LoadString("LimitDescLong") & defaultIsStringSpaced & Number.ToText(DEFAULT_LIMIT),
					Documentation.SampleValues = {Text.From(DEFAULT_LIMIT) & " " & Extension.LoadString("DefaultMark")}
				],
				timeoutType = type nullable number meta [
					Documentation.FieldCaption = Extension.LoadString("TimeoutDesc"),
					Documentation.FieldDescription = Extension.LoadString("TimeoutDescLong") & defaultIsStringSpaced & Number.ToText(DEFAULT_TIMEOUT),
					Documentation.SampleValues = {Text.From(DEFAULT_TIMEOUT) & " " & Extension.LoadString("DefaultMark")}
				]
			in
				Type.ForRecord([
					limit = [Type = limitType, Optional = true],
					timeout = [Type = timeoutType, Optional = true]
				], true) meta [
					Documentation.FieldCaption = Extension.LoadString("AdvancedOptions")
					// Documentation.FieldDescription = "?"
				]
	in
		type function (
			libraryUrl as libraryUrlType,
			optional authMode as authModeType,
			optional options as optionsType
		) as table meta [
			Documentation.Name = Extension.LoadString("DataSourceName") & " ver. " & VERSION
		];

// Implementation of the function to fetch data from MicroStrategy Dataset
MicroStrategyDataset.Contents.Impl = (libraryUrl as text, optional authMode as text, optional options as record) as table =>
	let
		credentials = Extension.CurrentCredential(),
		_authMode = if credentials[AuthenticationKind] = "OAuth" then
				credentials[Properties][authMode]
			else if authMode = Extension.LoadString("LDAPAuth")	then
				authMode
			else
				Extension.LoadString("StandardAuth"),
		_options = if options <> null then options else [ limit = null, timeout = null],
		timeout =
			if (_options[timeout] <> null) then
				if (_options[timeout] < 0) then
					error Extension.LoadString("ErrorWrongTimeoutInput")
				else
					_options[timeout]
			else DEFAULT_TIMEOUT,
		limit = if (_options[limit] <> null) then _options[limit] else DEFAULT_LIMIT,
		restApiUrl = FixApiUrl(libraryUrl),

		// Authenticate user, get the token and cookie
		auth = Authenticate(restApiUrl, _authMode, timeout, credentials),

		connection = [
			auth = auth,
			authMode = _authMode,
			restApiUrl = restApiUrl,
			libraryUrl = libraryUrl,
			limit = limit,
			timeout = timeout,
			status = Rest.GetStatus(@connection),
			supportsNestedFields = Status.IsNestedFieldSelectionCompatible(status)
		],

		NavTable = FindProjects(connection)
	in
		NavTable;

// Function to authenticate user and return the token and cookie
Authenticate = (restApiUrl as text, authMode as text, timeout as number, credentials as record) =>
		if authMode = "OIDC" then
			null
		else if authMode = "Library" then
			Rest.Delegate(restApiUrl, credentials[access_token], timeout)
		else
			Rest.Login(restApiUrl, authMode, credentials, timeout);

// OAuth methods
OAuth.StartLogin = (dataSourcePath as text, state as text, display) =>
	if Text.EndsWith(dataSourcePath, "#OIDCMode") then
		OAuth.LoginOptionsForOIDC(dataSourcePath, state)
	else
		OAuth.LoginOptionsForLibrary(dataSourcePath, state);

OAuth.LoginOptionsForLibrary =  (dataSourcePath as text, state as text) =>
	let
		redirectUri = "https://oauth.powerbi.com/views/oauthredirect.html",
		commonOIDCProperties = OAuth.GetCommonOIDCProperties(dataSourcePath),
		authorizationUrl = EnsureUrlEndsWithSlash(dataSourcePath) & "auth/oauth.jsp?" & Uri.BuildQueryString([
				source = "powerbi-connector",
				state = state,
				redirect_uri = redirectUri
			])
	in
		[
			LoginUri = authorizationUrl,
			CallbackUri = redirectUri,
			WindowHeight = 720,
			WindowWidth = 1024,
			Context = [
				resourceUrl = FixApiUrl(dataSourcePath),
				workflow = "Library"
			]
		];

OAuth.LoginOptionsForOIDC = (dataSourcePath as text, state as text) =>
	let
		commonOIDCProperties = OAuth.GetCommonOIDCProperties(dataSourcePath),
		redirectUri = "https://oauth.powerbi.com/views/oauthredirect.html",
		authorizationUrl = commonOIDCProperties[OIDCConfigData][authorization_endpoint] & "?" & Uri.BuildQueryString([
				response_type = "code",
				client_id = commonOIDCProperties[clientId],
				scope = commonOIDCProperties[scope],
				state = state,
				redirect_uri = redirectUri,
				code_challenge = commonOIDCProperties[codeChallenge],
				code_challenge_method = "S256"
			])
	in
		[
			LoginUri = authorizationUrl,
			CallbackUri = redirectUri,
			WindowHeight = 720,
			WindowWidth = 1024,
			Context = [
				clientId = commonOIDCProperties[clientId],
				redirectUri = redirectUri,
				tokenUrl = commonOIDCProperties[OIDCConfigData][token_endpoint],
				dataSourcePath = commonOIDCProperties[trimmedDataSourcePath],
				workflow = "OIDC",
				scope = commonOIDCProperties[scope],
				codeVerifier = commonOIDCProperties[codeVerifier]
			]
		];

OAuth.FinishLogin = (context as record, callbackUri as text, state) =>
	let
		uriParts = Uri.Parts(callbackUri)[Query],
		stateFromProvider = uriParts[state]
	in
		if state <> stateFromProvider then
			error Extension.LoadString("ErrorContents")
		else 
			if context[workflow] = "Library" then
				[
					access_token = uriParts[iToken],
					authMode = context[workflow]
				]
			else
				OAuth.TokenMethod(uriParts[code], "authorization_code", "code", context[dataSourcePath], context[tokenUrl], context[clientId], context[scope], context[redirectUri], context[codeVerifier]);

OAuth.Refresh = (dataSourcePath as text, refreshToken as text) =>
	let
		commonOIDCProperties = OAuth.GetCommonOIDCProperties(dataSourcePath)
	in
		OAuth.TokenMethod(
			refreshToken,
			"refresh_token",
			"refresh_token",
			commonOIDCProperties[trimmedDataSourcePath],
			commonOIDCProperties[tokenEndpoint],
			commonOIDCProperties[clientId],
			commonOIDCProperties[scope],
			"",
			commonOIDCProperties[codeVerifier]
		);

OAuth.TokenMethod = (code as text, grantType as text, tokenField as text, resourceUrl as text, tokenUrl as text, clientId as text, scope as text, redirectUri as text, codeVerifier as text) =>
    let
		query = [
			grant_type = grantType,
			client_id = clientId,
			scope = scope,
			redirect_uri = redirectUri,
			code_verifier = codeVerifier
		],
		queryWithCode = Record.AddField(query, tokenField, code),
		tokenResponse = Web.Contents(
			tokenUrl,
			[
				Headers = [
					#"Content-Type" = "application/x-www-form-urlencoded"
				],
				Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode))
			]
		),
		parts = Json.Document(tokenResponse),
		tokens = [
			access_token = parts[access_token],
			id_token = parts[id_token],
			expires = parts[expires_in]
		],
		mstrTokens = Rest.ExchangeOIDCTokenForMstrTokens(resourceUrl, tokens),
		finalTokens = Record.Combine({
			[
				access_token = "None",
				refresh_token = parts[refresh_token],
				authMode = "OIDC"
			],
			mstrTokens
		})
	in
	    finalTokens;

OAuth.RefreshCredentialsAndRepeatRequest = (requestData as record, libraryUrl as text) =>
	let
		credentials = Extension.CurrentCredential(true),
		headers = Record.Combine({
			requestData[requestHeadersWithoutCreds],
			[
				#"X-MSTR-AuthToken"=credentials[Properties][xtoken],
				Cookie=credentials[Properties][xcookie]
			]
		}),
		optionsWithHeaders = Record.AddField( requestData[requestOptions], "Headers", headers)
	in
		Web.Contents(
			requestData[requestUrl],
			optionsWithHeaders
		);

OAuth.GetCommonOIDCProperties = (dataSourcePath as text) =>
	let
		fixedDataSourcePath = FixApiUrl(dataSourcePath),
		OIDCConfigDataFull = Rest.GetOIDCConfigData(fixedDataSourcePath)
	in
		[
			trimmedDataSourcePath = TrimOIDCParameterFromUrl(dataSourcePath),
			OIDCConfigData = OIDCConfigDataFull[iams]{0},
			scope = Text.Combine(OIDCConfigData[scopes], " "),
			clientId = OIDCConfigData[nativeClientId],
			tokenEndpoint = OIDCConfigData[token_endpoint],
			codeVerifier = Text.NewGuid() & Text.NewGuid(), // generates globally unique, random string
			codeChallenge = OAuth.GenerateCodeChallenge(codeVerifier)
		];

OAuth.GenerateCodeChallenge = (codeVerifier as text) =>
	let
		hash = Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(codeVerifier)),
		hashToText = (Binary.ToText(hash, 0)) // converts binary to string using Base64
	in
		Text.Remove(Text.Replace(Text.Replace(hashToText, "+", "-"), "/", "_"), "="); // ensures that the final code challenge is encoded as Base64Url

// Navigation workflow functions

FindProjects = (connection as record) =>
	let
		projectResponse = Rest.GetProjects(connection),
		NavTable =
			let
				objects = List.Transform(projectResponse, (project) => {project[name], project[id], FindRootFolders(connection, project[id]), "Folder", "Folder", false}),
				ot = Table.FromRows(objects, {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}),
				nt = Table.ToNavigationTable(ot, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
			in
				nt
	in
		NavTable;

FindRootFolders = (connection as record, projectId as text) =>
	let
		shouldCheckPrivilege = Status.IsLicenseCompatible(connection[status]),
		jResult =
			if not shouldCheckPrivilege or User.HasPrivilege(connection, projectId) then
				Rest.GetFolders(connection, projectId)
			else
				error Extension.LoadString("ErrorPrivilege"),

		NavTable =
			let
				visFolders = List.Select(jResult, (project) => Record.HasFields(project, "hidden") <> true),
				objects = List.Transform(visFolders, (folder) => {folder[name], folder[id], FindFolderContent(connection, projectId, folder[id]), "Folder", "Folder", false}),
				rootFolders = List.InsertRange(objects, List.Count(objects) - 1, {{Extension.LoadString("PersonalObjects"), "1", FindFolderContent(connection, projectId, "1"), "Folder", "Folder", false}}),
				ot = Table.FromRows(rootFolders, {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}),
				nt = Table.ToNavigationTable(ot, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
			in
				nt
	in
		NavTable;

FindFolderContent = (connection as record, projectId as text, folderId as text) =>
	let
		jResult = Rest.GetFolderContent(connection, projectId, folderId),

		NavTable =
			let
				validObjects = List.Select(jResult, (result) => (Record.HasFields(result, "hidden") <> true and (result[type] = ObjectTypes[Folder] or result[type] = ObjectTypes[ReportDefinition] and result[subtype] <> ObjectSubTypes[ReportHyperCard]))),
				objects = List.Transform(validObjects, (obj) => HandleNavigation(connection, projectId, obj)),
				ot = Table.FromRows(objects, {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}),
				nt = Table.ToNavigationTable(ot, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
			in
					nt
	in
		NavTable;

// Takes an object listed in navigation, processes it to return the navigation table row that corresponds to the workflow. (Further nav table, Table.View...)
HandleNavigation = (connection as record, projectId as text, obj as record) =>
	let
		objType = obj[type],
		objSubType = obj[subtype],
		objId = obj[id],
		kind = if objType = ObjectTypes[Folder] then "Folder" else if objSubType = ObjectSubTypes[ReportCube] or objSubType = ObjectSubTypes[ReportEmmaCube] then "CubeView" else "Table",
		isCube = objSubType = ObjectSubTypes[ReportCube] or objSubType = ObjectSubTypes[ReportEmmaCube],
		isLeaf = isCube,
		objName = obj[name],
		data =
			if objType = ObjectTypes[Folder] then
				FindFolderContent(connection, projectId, objId)
			else
				HandleDataset(connection, projectId, objId, isCube, objName)
	in
		{objName, objId, data, kind, kind, isLeaf};

HandleDataset = (connection as record, projectId as text, datasetId as text, isCube as logical, datasetName as text) =>
	let
		isV2 = Status.IsV2Compatible(connection[status]),
		toTableRows = if isV2 then MicroStrategyDataset.FromV2 else MicroStrategyDataset.FromV1,
		getColumnHeaders = if isV2 then MicroStrategyDataset.ColumnHeadersFromV2 else MicroStrategyDataset.ColumnHeadersFromV1,
		prompts = Rest.GetPrompts(connection, projectId, datasetId),
		hasPrompts = not isCube and not List.IsEmpty(prompts),
		// If the report has an object prompt, the generation of requestedObjects from the definition will cause an error. Check for prompts before doing it.
		IsPromptUnsupported = (prompt) => prompt[type] = "OBJECT",
		hasUnsupportedPrompts = hasPrompts and List.MatchesAny(prompts, IsPromptUnsupported),
		instanceData = if not hasUnsupportedPrompts then InitInstance(connection, projectId, datasetId, isCube, isV2) else error Extension.LoadString("ErrorPrompted"),
		instanceId = instanceData[instanceId]
	in
		// If the dataset doesn't have prompts, just make a view out of it and return it. If it does, return a navtable which can be subsequently used to answer prompts and get a view afterwards.
		if not hasPrompts then
			let
				view = MicroStrategyDataset.View(connection, projectId, datasetId, instanceData, isCube, isV2)
			in
				if isCube then
					view
				else
					NavigationTable.FromRows({
						{datasetName, "Import", view, "Table", "Table", true}
					})
		else
			if Status.IsPromptCompatible(connection[status]) then
				CreatePromptNavTable(connection, prompts, projectId, datasetId, instanceId, isCube, isV2, datasetName)
			else
				error Extension.LoadString("ErrorPromptedOldEnv");

// Creates a de-crosstabbed instance and returns its response body with only one row of data.
InitInstance = (connection as record, projectId as text, datasetId as text, isCube as logical, isV2 as logical) =>
	let
		requestBody = if isCube or not isV2 then
				Json.FromValue([])
			else
				let
					definition = Rest.GetDefinition(connection, projectId, datasetId, isCube, isV2)[definition],
					hasMetrics = not List.IsEmpty(definition[grid][columns]),
					bodyWithAttributes = [
						attributes = List.Transform(List.Select(definition[grid][rows], each (_[type] = "attribute" or _[type] = "consolidation")), each [id = _[id]])
					],
					objects =
					if hasMetrics then
						Record.AddField(
							bodyWithAttributes,
							"metrics",
							List.Transform(List.Select(definition[grid][columns], each _[type] = "templateMetrics"){0}[elements], each [id = _[id]])
						)
					else
						bodyWithAttributes
				in
					Json.FromValue([
						requestedObjects = objects,
						viewFilter = null,
						subtotals = [
							visible = false
						]
					]),
		limitedConnection = connection & [limit = 1]
	in
		Rest.PostInstance(limitedConnection, projectId, datasetId, isCube, isV2, requestBody);

// Pulls a single row of data to provide all instance schema including row count.
GetSchema = (connection as record, projectId as text, datasetId as text, instanceId as text, isCube as logical, isV2 as logical) =>
	let
		limitedConnection = connection & [limit = 1]
	in
		Rest.GetInstance(limitedConnection, projectId, datasetId, instanceId, isCube, isV2, 0);

// Table View wrapping a dataset and implementing query folding for simple data manipulation like Table.FirstN.
MicroStrategyDataset.View = (connection as record, projectId as text, datasetId as text, instanceData as record, isCube as logical, isV2 as logical) =>
	let
		getColumnHeaders = if isV2 then MicroStrategyDataset.ColumnHeadersFromV2 else MicroStrategyDataset.ColumnHeadersFromV1,
		toTableRows = if isV2 then MicroStrategyDataset.FromV2 else MicroStrategyDataset.FromV1,
		// Instance data for use with View
		Instance = [
			Data = instanceData,
			ID = instanceData[instanceId],
			rowCount = (if isV2 then Data else Data[result])[data][paging][total],
			headers = getColumnHeaders(Data),
			deDuplicatedHeaders = ColumnHeaders.DeDuplicate(headers),
			tableType = ColumnHeaders.ToTableType(deDuplicatedHeaders)
		],
		// Function to construct a Table View from state parameters
		View = (state as record) => Table.View(null, [
			// Stateless handler returning table type with all column types
			GetType = () => Instance[tableType],
			// The main handler to pull final dataset, depends on the view state (that we implement with the `View` wrapper)
			/*
			 * Normally, we would just call the `#table` function with the final table type provided as first argument. Sadly, this throws type errors whenever the values are of different type than the desired column type (for example, date string for Date column)... before parsing everything perfectly anyway.
			 * The result is that the user gets a scary error message of rows containing errors and then a perfectly fine imported table with 0 errors. Even when "show errors" is chosen, the resulting table of errors is empty.
			 * Nevertheless, to avoid scaring our users and hindering their workflows we have to create a temporary typeless table with just column names and feed it to Table.TransformColumnTypes.
			 */
			GetRows = () => Table.TransformColumnTypes(
				#table(
					ColumnHeaders.ToNames(Instance[deDuplicatedHeaders]),
					GetRows(connection, projectId, datasetId, Instance[ID], isCube, isV2, state, toTableRows)
				),
				Instance[deDuplicatedHeaders]
			),
			// Return the final number of rows that will be pulled
			GetRowCount = () as number => state[rowCount] - state[offset],
			// Return a modified view that returns only `count` top rows.
			OnTake = (count as number) => if count < state[rowCount] then @View(state & [rowCount = count]) else @View(state),
			// Return a modified view that skips `count` top rows.
			OnSkip = (count as number) => @View(state & [offset = state[offset] + count])
		])
	in
		View([offset = 0, limit = connection[limit], rowCount = Instance[rowCount]]);

CreatePromptNavTable = (connection as record, prompts as list, projectId as text, reportId as text, instanceId as text, isCube as logical, isV2 as logical, reportName as text) =>
	let
		instanceMeta = connection & [
			projectId = projectId,
			reportId = reportId,
			instanceId = instanceId,
			prompts = prompts
		],
		defaultOptions = {
			// Close all prompts on the report, even nested.
			{Extension.LoadString("PromptsCloseAll") & " - " & reportName, "PromptsClosed", CloseAllPrompts(CreateAnswerPrompts(instanceMeta, isV2)), "View", "View", true}
		},
		rows = defaultOptions
	in
		let
			ot = Table.FromRows(rows, {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}),
			nt = Table.ToNavigationTable(ot, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
		in
			nt;

CreateAnswerPrompts = (instanceMeta as record, isV2 as logical) =>
	let
		auth = instanceMeta[auth],
		restApiUrl = instanceMeta[restApiUrl],
		projectId = instanceMeta[projectId],
		reportId = instanceMeta[reportId],
		instanceId = instanceMeta[instanceId],
		prompts = instanceMeta[prompts],
		limit = instanceMeta[limit],
		timeout = instanceMeta[timeout],
		AnswerPrompts.Type =
			let
				answersType = type {[key = text, optional useDefault = logical, optional values = {text}]} meta [
					Documentation.FieldCaption = "Answers list",
					Documentation.FieldDescription = "A list of prompt answers, which are records containing the prompt key and either useDefault field set to true or values field set to a list of string answer values."
				]
				// TODO: document messageName
			in
				type function (optional answers as answersType, optional messageName as text) as any meta [
					Documentation.Name = "AnswerPrompts",
					Documentation.Description = "Use without arguments to get a list of unanswerd prompts, provide a list of prompt answers to answer prompts.",
					Documentation.LongDescription = "Use without arguments to get a list of unanswerd prompts, provide a list of prompt answers to answer prompts. A prompt answer is a record with ""key"" field corresponding to the prompt key and either useDefault field set to true or values field set to a list of string answer values. Returns a table if all prompts were answered, or another function if there is another page of prompts."
				],
		/* Function to answer prompts. If all are answered, returns the View, when called with no arguments returns the list of prompts, otherwise answers prompts and returns itself with new state.
		 * The POST promptsAnswers request takes a JSON object body with "messageName" and "answers" properties, where "answers" is an array of answers
		 * and each answer is an object with required "key" property and either "useDefault" property set to true or "values" property containing a list of string prompt answers.
		 */
		AnswerPrompts.Impl = (optional answers as list, optional messageName as text) =>
			if answers = null then
				prompts
			else
				let
					answerBodyRecord = if messageName <> null then [answers = answers, messageName = messageName] else [answers = answers],
					answerBody = Json.FromValue(answerBodyRecord),
					answerResult = Rest.PostInstancePromptsAnswers(instanceMeta, projectId, reportId, instanceId, answerBody),
					// IIFE to force answer request to be sent by forcing answerResult to be evaluated
					unansweredPrompts = ((_) => Rest.GetInstancePrompts(instanceMeta, projectId, reportId, instanceId))(answerResult)
				in
					if List.IsEmpty(unansweredPrompts) then
						let
							instanceData = GetSchema(instanceMeta, projectId, reportId, instanceId, false, isV2)
						in
							MicroStrategyDataset.View(instanceMeta, projectId, reportId, instanceData, false, isV2)
					else
						CreateAnswerPrompts(instanceMeta & [ prompts = unansweredPrompts ], isV2)
	in
		Value.ReplaceType(AnswerPrompts.Impl, AnswerPrompts.Type);

CloseAllPrompts = (answeringFunc as function) =>
	let
		// Answer with empty prompt answers list to close this page of prompts.
		result = answeringFunc({})
	in
		// If nested, recurse.
		if result is function then
			@CloseAllPrompts(result)
		else
			result;

/*
 * @param paging A record with `offset`, `limit` and `rowCount` fields.
 */
GetRows = (connection as record, projectId as text, datasetId as text, instanceId as text, isCube as logical, isV2 as logical, paging as record, toTableRows as function) =>
	let
		/* Create a list of {offset, limit} pairs.
		 * The limit is so that the last page will only request the remaining number of rows, not the full limit.
		 * Normally, there would be no difference, since the server would only send the remaining anyway, but now we may request only a part of a dataset, and pulling the full page when we only want a fraction of it is inefficient.
		 */
		derivePage = (prev as list) => let
				offset = prev{0} + prev{1},
				remaining = paging[rowCount] - offset,
				limit = if remaining < paging[limit] then remaining else paging[limit]
			in
				{offset, limit},
		deriveFirstPage = () => derivePage({paging[offset], 0}),
		pagesToFetch = List.Generate(deriveFirstPage, each _{0} < paging[rowCount], each derivePage(_)),
		fetchPage = (pair) =>
			let
				limitedConnection = connection & [limit = pair{1}]
			in
				Rest.GetInstance(limitedConnection, projectId, datasetId, instanceId, isCube, isV2, pair{0}),
		fetchedPages = List.Transform(pagesToFetch, fetchPage)
	in
		// Create a list of the first page and all other fetched pages, combine the resulting list of pages into one gigantic page. (still in list of lists form)
		List.Combine(List.Transform(fetchedPages, toTableRows));

// Constant maps

// EnumDSSXMLObjectTypes
ObjectTypes = [
	ReportDefinition = 3,
	Folder = 8
];
// EnumDSSXMLObjectSubTypes
ObjectSubTypes = [
	ReportGrid = 768,
	ReportGraph = 769,
	ReportGridAndGraph = 774,
	ReportDatamart = 772,
	ReportCube = 776,
	ReportEmmaCube = 779,
	ReportHyperCard = 781
];

V1.TYPEMAP = [
	Date = Date.Type,
	Real = Number.Type
];
/* Types in v2 are converted directly from iServer's supported datatypes, found in its DSSDataType_Type.h file.
 * Text values are skipped, since text is the fallback type.
 */
V2.TYPEMAP = [
	integer = Int32.Type, // "Signed integer datatype" - undocumented size, assuming C's `int` which is 32-bit
	unsigned = Int64.Type, // "Unsigned integer datatype" undocumented size so assigning it Power BI's Whole Number, which Int32.Type probably also gets cast to. Had to use it, since uint32 may contain an order of magnitude higher numbers than int32.
	numeric = Decimal.Type, // "Numeric datatype with exact precision and scale"
	decimal = Decimal.Type, // "Numeric datatype with precision and scale, but actual precision may be larger"
	real = Number.Type, // "Single precision real number, 4 bytes"
	double = Double.Type, // "Double precision real number, 8 bytes"
	float = Number.Type, // "Floating point datatype with precision" making it a generic for all floats (real and double). Looks like "real" and "float" simply have switched places.
	binary = Binary.Type, // "Fixed length binary datatype"
	varBin = Binary.Type, // "Variable length binary datatype"
	longVarBin = Binary.Type, // "Large variable length binary datatype"
	date = Date.Type, // "Date datatype: year, month and day"
	time = Time.Type, // "Time datatype: hour, minute, second and fraction of second"
	timeStamp = DateTime.Type, // "TimeStamp datatype: both date and time"
	short = Int16.Type, // "ODBC type: short integer"
	long = Int64.Type, // "ODBC type: long integer"
	bool = Logical.Type, // "ODBC type: boolean type"
	bigDecimal = Decimal.Type, // "Msi Big Decimal Type"
	missing = MissingField.Type, // Missing
	Int64 = Int64.Type, // "Int64"
	guid = Guid.Type // "GUID datatype"
];

// Utilities

getCurrentCredentials = (connection as record) =>
	if connection[authMode] <> "OIDC" then
		connection[auth]
	else
		let
			currentCredentials = Extension.CurrentCredential()
		in
			[
				xtoken = currentCredentials[Properties][xtoken],
				xcookie = currentCredentials[Properties][xcookie]
			];

// JSON parsing utils
getName = each _[name];
V1.getMetricHeader = (met) =>
	let
		// All number types have number as their supertype, making Type.Is return true. We want to further analyse them to determine if they should be displayed as percentages etc.
		basicType = if Value.Is(met[min], Number.Type) then Number.Type else Text.Type,
		derivedType = deriveMetricType(met[numberFormatting], basicType)
	in
		{met[name], derivedType};
V1.getAttributeHeaderLists = (attr) => List.Transform(attr[forms], (form) => {attr[name] & " " & form[name], mapType(form[dataType], V1.TYPEMAP)});
V1.getAttributeHeaders = (attributes) => List.Combine(List.Transform(attributes, V1.getAttributeHeaderLists));
mapType = (mstrTypename as text, typemap as record) => if Record.HasFields(typemap, mstrTypename) then Record.Field(typemap, mstrTypename) else Text.Type;
V2.getMetricHeader = (met as record) =>
	let
		basicType = mapType(met[dataType], V2.TYPEMAP),
		derivedType = deriveMetricType(met[numberFormatting], basicType)
	in
		{met[name], derivedType};
V2.getAttributeHeaderLists = (attr) =>
	if attr[type] = "attribute" then
		List.Transform(attr[forms], (form) => {attr[name] & " " & form[name], mapType(form[dataType], V2.TYPEMAP)})
	else
		if attr[type] = "consolidation" then
			{{attr[name], Text.Type}}
		else
			error Extension.LoadString("ErrorUnsupportedAttribute") & attr[type];

V2.getAttributeHeaders = (attributes) => List.Combine(List.Transform(attributes, V2.getAttributeHeaderLists));

deriveMetricType = (formatting as record, inputType as type) =>
	if Type.Is(inputType, Number.Type) then
		if Text.Contains(formatting[formatString], "%") then
			Percentage.Type
		else
			if Text.Contains(formatting[formatString], "$") then
				Currency.Type
			else
				inputType
	else
		inputType;

MicroStrategyDataset.FromV1 = (jResult as record) =>
	let
		result = jResult[result],
		root = result[data][root],
		search = (root as record) =>
			if Record.HasFields(root, "children") <> true then
				let
					hasElement = if Record.HasFields(root, "element") then List.Transform(Record.FieldNames(root[element][formValues]), (keyName) => Record.Field(root[element][formValues], keyName)) else null,
					hasMetrics = if Record.HasFields(root, "metrics") then List.Transform(Record.FieldNames(root[metrics]), (item) => Record.Field(root[metrics], item)[rv]) else null,
					hasElementMetrics = if hasElement = null then
							hasMetrics
						else
							if hasMetrics = null then hasElement else hasElement & hasMetrics
				in
					{hasElementMetrics}
			else
				let
					rn = if Record.HasFields(root, "element") then
							List.Transform(Record.FieldNames(root[element][formValues]), (keyName) => Record.Field(root[element][formValues], keyName))
						else
							null,
					ca = List.Combine(List.Transform(root[children], (child) =>
							let
								childresult = @search(child),
								appendname = if rn = null then childresult else List.Transform(childresult, (c) => List.InsertRange(c, 0, rn))
							in
								appendname
						)
					)
				in
					ca
	in
		search(root);

MicroStrategyDataset.FromV2 = (jResult as record) =>
	let
		attributes = jResult[definition][grid][rows],
		hasAttributes = not List.IsEmpty(attributes),
		// x is an {index, value} pair
		lookupAttribute = (x) => attributes{x{0}}[elements]{x{1}},
		lookupAttributeValue = (x) => lookupAttribute(x)[formValues],
		lookupAttributeSubtotal = (x) => Record.HasFields(lookupAttribute(x), "subtotal"),
		lookupAttributeRow = (row) => List.Transform(List.Zip({List.Positions(row), row}), lookupAttributeValue),
		// isSubtotalRow receives a pair, {attributeRow, metricRow}
		isSubtotalRow = (row) => List.MatchesAny(List.Zip({List.Positions(row{0}), row{0}}), (x) => lookupAttributeSubtotal(x)),
		metricRows = jResult[data][metricValues][raw],
		hasMetrics = not List.IsEmpty(metricRows),
		rawAttributeRows = jResult[data][headers][rows],
		rowPairs = List.Zip({rawAttributeRows, metricRows}),
		hasSubtotals = not Record.HasFields(jResult[definition][grid], "subtotals"),
		selectedRows = if hasSubtotals then List.Select(rowPairs, (x) => not isSubtotalRow(x)) else rowPairs	
	in
		// There might be a case that only metrics have been pulled, resulting in a single row of just metric data. Such a case bypasses most of the above.
		if hasAttributes then
			if hasMetrics then
				List.Transform(selectedRows, (x) => List.Combine({List.Combine(lookupAttributeRow(x{0})), x{1}}))
			else
				List.Transform(selectedRows, (x) => List.Combine(lookupAttributeRow(x{0})))
		else
			metricRows;

MicroStrategyDataset.ColumnHeadersFromV1 = (jResult as record) =>
	let
		result = jResult[result],
		metricHeaders = List.Transform(result[definition][metrics], V1.getMetricHeader),
		attributeHeaders = V1.getAttributeHeaders(result[definition][attributes])
	in
		List.Combine({attributeHeaders, metricHeaders});

MicroStrategyDataset.ColumnHeadersFromV2 = (jResult as record) =>
	let
		grid = jResult[definition][grid],
		attributes = grid[rows],
		hasMetrics = not List.IsEmpty(grid[columns]),
		metrics = grid[columns]{0},
		attributeHeaders = V2.getAttributeHeaders(attributes),
		metricHeaders = List.Transform(metrics[elements], V2.getMetricHeader)
	in
		if hasMetrics then
			List.Combine({attributeHeaders, metricHeaders})
		else
			attributeHeaders;

// Accepts a column name to be used and a record of already used names, returns a tuple of the name (with duplicate suffix if needed) and an updated record.
ColumnHeaders.UseName = (name as text, usedNames as record) =>
	if not Record.HasFields(usedNames, name) then
		{name, Record.AddField(usedNames, name, 1)}
	else
		/*
		 * Sometimes, it may be the case that by atttaching the duplicate suffix to the name we create a name that already exists.
		 * There are two such scenarios (using Revenue as example):
		 * 1. We already have "Revenue (1)" in the list when we encounter the second "Revenue".
		 * 2. We have created "Revenue (1)" for the second "Revenue", but then we encounter "Revenue (1)".
		 * The previous approach was to simply recurse the function, but then the duplicate duplicates would look like "Revenue (1) (1)", which is pretty bad.
		 * To correctly solve the first case all we need is to increase the duplicate number if the generated name already exists.
		 * To correctly solve the second case we have to record each generated name with the value of the original name, and then upon encountering a duplicate go with that name (and its assigned duplicate number) instead.
		 */
		let
			duplicateNumberOrName = Record.Field(usedNames, name),
			duplicateName = if Value.Is(duplicateNumberOrName, Text.Type) then duplicateNumberOrName else name,
			duplicateNumber = if Value.Is(duplicateNumberOrName, Number.Type) then duplicateNumberOrName else Record.Field(usedNames, duplicateName),
			createDeDuplicatedName = (usedNames as record, duplicateNumber as number) =>
				let
					nameCandidate = duplicateName & " (" & Number.ToText(duplicateNumber) & ")",
					newDuplicateNumber = duplicateNumber + 1,
					newUsedNames = usedNames & Record.AddField(Record.AddField([], duplicateName, newDuplicateNumber), nameCandidate, duplicateName)
				in
					if not Record.HasFields(usedNames, nameCandidate) then
						{nameCandidate, newUsedNames}
					else
						@createDeDuplicatedName(newUsedNames, newDuplicateNumber)
		in
			createDeDuplicatedName(usedNames, duplicateNumber);

// Accepts a header list, returns it with duplicate names changed.
ColumnHeaders.DeDuplicate = (headers as list) =>
	let
		headersWithMeta = List.Accumulate(headers, {} meta [usedNames = []], (state as list, current as list) =>
			let
				stateUsedNames = Value.Metadata(state)[usedNames],
				currentName = current{0},
				currentType = current{1},
				useNameTuple = ColumnHeaders.UseName(currentName, stateUsedNames),
				newName = useNameTuple{0},
				newUsedNames = useNameTuple{1}
			in
				(state & {{newName, currentType}}) meta [usedNames = newUsedNames]
		)
	in
		Value.RemoveMetadata(headersWithMeta);

// Get a table type from headers
ColumnHeaders.ToTableType = (headers as list) =>
	let
		// We have list of `{name, type}` pairs we want to convert to a single record, which has `name = [Type = type, Optional = false]` entries
		headerRecord = List.Accumulate(headers, [], (state, current) => state & Record.FromList({[Type = current{1}, Optional = false]}, {current{0}})),
		recordType = Type.ForRecord(headerRecord, false)
	in
		type table (recordType);

ColumnHeaders.ToNames = (headers as list) => List.Transform(headers, (x) => x{0});

FixApiUrl = (libraryUrl as text) =>
	let
		ensureApi = (x) => if Text.EndsWith(x, "api/") then x else x & "api/",
		libraryUrlTrimmed = TrimOIDCParameterFromUrl(libraryUrl)
	in
		ensureApi(EnsureUrlEndsWithSlash(libraryUrlTrimmed));

TrimOIDCParameterFromUrl = (libraryUrl as text) => EnsureUrlEndsWithSlash(Text.Replace(libraryUrl, "#OIDCMode", ""));

EnsureUrlEndsWithSlash = (url) => if Text.EndsWith(url, "/") then url else url & "/";

CredsFromHeaders = (headers as record) => [
	xtoken = headers[#"X-MSTR-AuthToken"],
	xcookie = Text.Combine(List.Combine(List.Transform(Text.Split(headers[#"Set-Cookie"], ","), (str) => Text.Split(str, ";"))), "; ")
];

User.HasPrivilege = (connection as record, projectId as text) as logical =>
	let
		privilegeResponse = Rest.GetPrivilege(connection, projectId)
	in
		// Check if the user has the privilege for all projects, or if not, if it has it for the specific project. The order is such because checking a boolean is much cheaper than comparing medium-size strings.
		privilegeResponse[isUserLevelAllowed] or List.MatchesAny(privilegeResponse[projects], each _[isAllowed] and _[id] = projectId);

MicroStrategyDataset.VersionFromText = (verstring as text) =>
	let
		split = Text.Split(verstring, ".")
	in
		List.Transform(split, Number.FromText);

Status.IsVersionCompatible = (status as record, version as text) =>
	let
		versionParsed = MicroStrategyDataset.VersionFromText(version),
		iVer = MicroStrategyDataset.VersionFromText(status[iServerVersion]),
		webVer = MicroStrategyDataset.VersionFromText(status[webVersion])
	in
		MicroStrategyDataset.VersionIsCompatible(iVer, versionParsed) and MicroStrategyDataset.VersionIsCompatible(webVer, versionParsed);

Status.IsLicenseCompatible = (status as record) => Status.IsVersionCompatible(status, "11.1.0200");

Status.IsV2Compatible = (status as record) => Status.IsVersionCompatible(status, "11.1.0300");

Status.IsPromptCompatible = (status as record) => Status.IsVersionCompatible(status, "11.1.0300");

Status.IsNestedFieldSelectionCompatible = (status as record) => Status.IsVersionCompatible(status, "11.2.0200");

// Check if version "tocheck" is same or newer than version "checkref", meaning it should be backwards-compatible.
MicroStrategyDataset.VersionIsCompatible = (tocheck as list, checkref as list) =>
	// If we ran out of version parts to check without resolving, either both versions are exactly equal or we ran out of precision we care about, so the answer is yes.
	if List.IsEmpty(tocheck) or List.IsEmpty(checkref) then
		true
	else
		// if the considered version part is higher, the answer is yes, if lower then no, if equal then continue to further parts.
		if tocheck{0} > checkref{0} then
			true
		else
			if tocheck{0} < checkref{0} then
				false
			else
				@MicroStrategyDataset.VersionIsCompatible(List.Skip(tocheck), List.Skip(checkref));

// Takes a possibly erroneous response, if it has error, handles it and returns a meaningful error, if not returns the response.
CheckResponse = (response, targetUrl as text, optional retry as logical, optional requestData as record, optional libraryUrl) =>
	let
		bufferedResponse = Binary.Buffer(response),
		responseMeta = Value.Metadata(response),
		status = responseMeta[Response.Status]
	in
		/*
		 * Due to a Power BI bug, the response has to be null-checked to force it to be evaluated before its meta, otherwise two requests will be sent.
		 * Due to another Power BI bug, the response status can sometimes be null (reproduced on 401 responses), causing a type error if we don't ensure it exists before comparing.
		 * Due to yet another Power BI bug, a null-check is no longer enough to prevent the first bug and the response has to be fully buffered.
		 */
		if bufferedResponse <> null and status <> null and status < 300 and status >= 200 then
			bufferedResponse meta responseMeta
		else
			// Retry functionality is currently implemented only for OIDC authentication
			if retry and status = 401 then
				@CheckResponse(OAuth.RefreshCredentialsAndRepeatRequest(requestData, libraryUrl), targetUrl, false)
			else
				let
					triedResult = try Json.Document(bufferedResponse)
				in
					if triedResult[HasError] then
						error (Extension.LoadString("ErrorContents") & " " & targetUrl & "#(lf)" & Extension.LoadString("StatusCode") & " " & Text.From(status))
					else
						let
							errorData = triedResult[Value]
						in
							error Error.Record("MstrApi.Error", errorData[message], Record.RemoveFields(errorData, "message"));

// Like CheckResponse, but also JSON-parses the response.
HandleResponse = (response, targetUrl as text,  optional retry as logical, optional requestData as record, optional libraryUrl) =>
	Json.Document(CheckResponse(response, targetUrl, retry, requestData, libraryUrl));

// Thin wrappers for REST endpoints

// GET /status
Rest.GetStatus = (connection as record) =>
	let
		requestUrl = connection[restApiUrl] & "status",
		response = Web.Contents(
			requestUrl,
			[
				Headers = [
					Accept = "application/json"
				],
				IsRetry = false,
				Timeout=#duration(0, 0, 0, connection[timeout])
			]
		)
	in
		HandleResponse(response, requestUrl);

// POST /auth/login
Rest.Login = (restApiUrl as text, authMode as text, credentials as record, _timeout as number) =>
	let
		loginMode = if authMode = Extension.LoadString("StandardAuth") then "1" else "16",
		content = Json.FromValue([
			username = credentials[Username],
			password = credentials[Password],
			loginMode = loginMode,
			applicationType = Text.From(APPLICATION_TYPE),
			metadataLocale = LOCALE,
			warehouseDataLocale = LOCALE,
			displayLocale = LOCALE,
			messagesLocale = LOCALE,
			numberLocale = LOCALE
		]),
		requestUrl = restApiUrl & "auth/login",
		response = Web.Contents(
			requestUrl,
			[
				Headers = [
					Accept = "application/json",
					#"Content-Type" = "application/json"
				],
				Content = content,
				IsRetry = false,
				Timeout=#duration(0, 0, 0, _timeout)
			]
		)
	in
		CredsFromHeaders(Value.Metadata(CheckResponse(response, requestUrl))[Headers]);

// POST /auth/delegate
Rest.Delegate = (restApiUrl as text, iToken as text, timeout as number) =>
	let
		requestUrl = restApiUrl & "auth/delegate",
		response = Web.Contents(
			requestUrl,
			[
				Headers = [
					Accept = "application/json",
					#"Content-Type" = "application/json",
					#"X-MSTR-IdentityToken" = Extension.CurrentCredential()[access_token]
				],
				Content = Json.FromValue([
					loginMode = -1,
					identityToken = Extension.CurrentCredential()[access_token]
				]),
				IsRetry = true,
				Timeout=#duration(0, 0, 0, timeout),
				ManualCredentials = true
			]
		)
	in
		CredsFromHeaders(Value.Metadata(CheckResponse(response, requestUrl))[Headers]);

// GET /sessions/privileges/{id}
Rest.GetPrivilege = (connection as record, projectId as text) as record =>
	let
		auth = getCurrentCredentials(connection),
		// 271 is the stable ID of the UsePowerBI privilege
		requestUrl = connection[restApiUrl] & "sessions/privileges/271",
		requestData = [
			requestUrl = requestUrl,
			requestHeadersWithoutCreds = [ Accept = "application/json"],
			requestOptions = [
				IsRetry = false,
				ManualCredentials = true,
				ManualStatusHandling = {400, 401, 500},
				Timeout=#duration(0, 0, 0, connection[timeout])
			]
		],
		requestHeaders = Record.Combine({
			requestData[requestHeadersWithoutCreds],
			[
				#"X-MSTR-AuthToken"=auth[xtoken],
				Cookie=auth[xcookie]
			]
		}),
		requestOptionsWithHeaders = Record.AddField(requestData[requestOptions], "Headers", requestHeaders),
		response = Web.Contents(
			requestUrl,
			requestOptionsWithHeaders
		)
	in
		HandleResponse(response, requestUrl, true, requestData, connection[libraryUrl]);

// GET /projects
Rest.GetProjects = (connection as record) =>
	let
		auth = getCurrentCredentials(connection),
		restApiUrl = connection[restApiUrl],
		timeout = connection[timeout],
		requestUrl = restApiUrl & "projects",
		requestData = [
			requestUrl = requestUrl,
			requestHeadersWithoutCreds = [ Accept = "application/json"],
			requestOptions = [
				IsRetry = false,
				ManualCredentials = true,
				ManualStatusHandling = {400, 401, 500},
				Timeout=#duration(0, 0, 0, connection[timeout])
			]
		],
		requestHeaders = Record.Combine({
			requestData[requestHeadersWithoutCreds],
			[
				#"X-MSTR-AuthToken"=auth[xtoken],
				Cookie=auth[xcookie]
			]
		}),
		requestOptionsWithHeaders = Record.AddField(requestData[requestOptions], "Headers", requestHeaders),
		response = Web.Contents(
			requestUrl,
			requestOptionsWithHeaders
		)
	in
		HandleResponse(response, requestUrl, true, requestData, connection[libraryUrl]);

// GET /folders
Rest.GetFolders = (connection as record, projectId as text) =>
	let
		auth = getCurrentCredentials(connection),
		requestUrl = connection[restApiUrl] & "folders",
		requestData = [
			requestUrl = requestUrl,
			requestHeadersWithoutCreds = [
				Accept = "application/json",
				#"X-MSTR-ProjectID"=projectId
			],
			requestOptions = [
				Query = [
					offset = "0",
					limit = "-1"
				],
				IsRetry = false,
				ManualCredentials = true,
				ManualStatusHandling = {400, 401, 500},
				Timeout=#duration(0, 0, 0, connection[timeout])
			]
		],
		requestHeaders = Record.Combine({
			requestData[requestHeadersWithoutCreds],
			[
				#"X-MSTR-AuthToken"=auth[xtoken],
				Cookie=auth[xcookie]
			]
		}),
		requestOptionsWithHeaders = Record.AddField(requestData[requestOptions], "Headers", requestHeaders),
		response = Web.Contents(
			requestUrl,
			requestOptionsWithHeaders
		)
	in
		HandleResponse(response, requestUrl, true, requestData, connection[libraryUrl]);

// GET /folders/{id}
Rest.GetFolderContent = (connection as record, projectId as text, folderId as text) =>
	let
		auth = getCurrentCredentials(connection),
		requestUrl = connection[restApiUrl] & (if folderId = "1" then "folders/myPersonalObjects" else "folders/" & folderId),
		requestData = [
			requestUrl = requestUrl,
			requestHeadersWithoutCreds = [
				Accept = "application/json",
				#"X-MSTR-ProjectID"=projectId
			],
			requestOptions = [
				Query = [
					offset = "0",
					limit = "-1"
				],
				IsRetry = false,
				ManualCredentials = true,
				ManualStatusHandling = {400, 401, 500},
				Timeout=#duration(0, 0, 0, connection[timeout])
			]
		],
		requestHeaders = Record.Combine({
			requestData[requestHeadersWithoutCreds],
			[
				#"X-MSTR-AuthToken"=auth[xtoken],
				Cookie=auth[xcookie]
			]
		}),
		requestOptionsWithHeaders = Record.AddField(requestData[requestOptions], "Headers", requestHeaders),
		response = Web.Contents(
			requestUrl,
			requestOptionsWithHeaders
		)
	in
		HandleResponse(response, requestUrl, true, requestData, connection[libraryUrl]);

// GET /<cubes|reports>/{id}
Rest.GetDefinition = (connection as record, projectId as text, datasetId as text, isCube as logical, isV2 as logical) =>
	let
		auth = getCurrentCredentials(connection),
		restApiUrl = connection[restApiUrl],
		requestUrl = (if isV2 then restApiUrl & "v2/" else restApiUrl) & (if isCube then "cubes/" else "reports/") & datasetId,
		requestData = [
			requestUrl = requestUrl,
			requestHeadersWithoutCreds = [
				Accept = "application/json",
				#"X-MSTR-ProjectID"=projectId
			],
			requestOptions = [
				Query = [
					offset = "0",
					limit = "-1"
				],
				IsRetry = false,
				ManualCredentials = true,
				ManualStatusHandling = {400, 401, 500},
				Timeout=#duration(0, 0, 0, connection[timeout])
			]
		],
		requestHeaders = Record.Combine({
			requestData[requestHeadersWithoutCreds],
			[
				#"X-MSTR-AuthToken"=auth[xtoken],
				Cookie=auth[xcookie]
			]
		}),
		requestOptionsWithHeaders = Record.AddField(requestData[requestOptions], "Headers", requestHeaders),
		response = Web.Contents(
			requestUrl,
			requestOptionsWithHeaders
		)
	in
		HandleResponse(response, requestUrl, true, requestData, connection[libraryUrl]);

// GET /reports/{id}/prompts
Rest.GetPrompts = (connection as record, projectId as text, reportId as text) =>
	let
		auth = getCurrentCredentials(connection),
		requestUrl = connection[restApiUrl] & "reports/" & reportId & "/prompts",
		requestData = [
			requestUrl = requestUrl,
			requestHeadersWithoutCreds = [
				Accept = "application/json",
				#"X-MSTR-ProjectID"=projectId
			],
			requestOptions = [
				Query = [
					offset = "0",
					limit = "-1"
				],
				IsRetry = true,
				ManualCredentials = true,
				ManualStatusHandling = {400, 401, 500},
				Timeout=#duration(0, 0, 0, connection[timeout])
			]
		],
		requestHeaders = Record.Combine({
			requestData[requestHeadersWithoutCreds],
			[
				#"X-MSTR-AuthToken"=auth[xtoken],
				Cookie=auth[xcookie]
			]
		}),
		requestOptionsWithHeaders = Record.AddField(requestData[requestOptions], "Headers", requestHeaders),
		response = Web.Contents(
			requestUrl,
			requestOptionsWithHeaders
		)
	in
		HandleResponse(response, requestUrl, true, requestData, connection[libraryUrl]);

RawMetricValuesOnlyFields = "-data.metricValues.formatted,-data.metricValues.extras";

// POST /<cubes|reports>/{id}/instances
Rest.PostInstance = (connection as record, projectId as text, datasetId as text, isCube as logical, isV2 as logical, requestBody as binary) =>
	let
		auth = getCurrentCredentials(connection),
		restApiUrl = connection[restApiUrl],
		requestUrl = (if isV2 then restApiUrl & "v2/" else restApiUrl) & (if isCube then "cubes/" else "reports/") & datasetId & "/instances",
		requestData = [
			requestUrl = requestUrl,
			requestHeadersWithoutCreds = [
				Accept = "application/json",
				#"Content-Type"="application/json",
				#"X-MSTR-ProjectID"=projectId
			],
			requestOptions = [
				Query =
					let
						defaultQuery = [
							offset = "0",
							limit = Text.From(connection[limit]),
							standardDateFormat = "true",
							standardRawDateFormat = "true"
						]
					in
						if connection[supportsNestedFields] then defaultQuery & [fields = RawMetricValuesOnlyFields] else defaultQuery,
				IsRetry = true,
				Content = requestBody,
				ManualCredentials = true,
				ManualStatusHandling = {400, 401, 500},
				Timeout=#duration(0, 0, 0, connection[timeout])
			]
		],
		requestHeaders = Record.Combine({
			requestData[requestHeadersWithoutCreds],
			[
				#"X-MSTR-AuthToken"=auth[xtoken],
				Cookie=auth[xcookie]
			]
		}),
		requestOptionsWithHeaders = Record.AddField(requestData[requestOptions], "Headers", requestHeaders),
		response = Web.Contents(
			requestUrl,
			requestOptionsWithHeaders
		)
	in
		HandleResponse(response, requestUrl, true, requestData, connection[libraryUrl]);

// GET /<cubes|reports>/{id}/instances/{instanceId}
Rest.GetInstance = (connection as record, projectId as text, datasetId as text, instanceId as text, isCube as logical, isV2 as logical, offset as number) =>
	let
		auth = getCurrentCredentials(connection),
		restApiUrl = connection[restApiUrl],
		requestUrl = (if isV2 then restApiUrl & "v2/" else restApiUrl) & (if isCube then "cubes/" else "reports/") & datasetId & "/instances/" & instanceId,
		requestData = [
			requestUrl = requestUrl,
			requestHeadersWithoutCreds = [
				Accept = "application/json",
				#"X-MSTR-ProjectID"=projectId
			],
			requestOptions = [
				Query =
					let
						defaultQuery = [
							offset = Text.From(offset),
							limit = Text.From(connection[limit]),
							standardDateFormat = "true",
							standardRawDateFormat = "true"
						]
					in
						if connection[supportsNestedFields] then defaultQuery & [fields = RawMetricValuesOnlyFields] else defaultQuery,
				IsRetry = true,
				ManualCredentials = true,
				ManualStatusHandling = {400, 401, 500},
				Timeout=#duration(0, 0, 0, connection[timeout])
			]
		],
		requestHeaders = Record.Combine({
			requestData[requestHeadersWithoutCreds],
			[
				#"X-MSTR-AuthToken"=auth[xtoken],
				Cookie=auth[xcookie]
			]
		}),
		requestOptionsWithHeaders = Record.AddField(requestData[requestOptions], "Headers", requestHeaders),
		response = Web.Contents(
			requestUrl,
			requestOptionsWithHeaders
		)
	in
		HandleResponse(response, requestUrl, true, requestData, connection[libraryUrl]);

// GET /reports/{id}/instances/{instanceId}/prompts
Rest.GetInstancePrompts = (connection as record, projectId as text, reportId as text, instanceId as text) =>
	let
		auth = getCurrentCredentials(connection),
		restApiUrl = connection[restApiUrl],
		requestUrl = connection[restApiUrl]  & "reports/" & reportId & "/instances/" & instanceId & "/prompts",
		requestData = [
			requestUrl = requestUrl,
			requestHeadersWithoutCreds = [
				Accept = "application/json",
				#"X-MSTR-ProjectID"=projectId
			],
			requestOptions = [
				IsRetry = true,
				ManualCredentials = true,
				ManualStatusHandling = {400, 401, 500},
				Timeout=#duration(0, 0, 0, connection[timeout])
			]
		],
		requestHeaders = Record.Combine({
			requestData[requestHeadersWithoutCreds],
			[
				#"X-MSTR-AuthToken"=auth[xtoken],
				Cookie=auth[xcookie]
			]
		}),
		requestOptionsWithHeaders = Record.AddField(requestData[requestOptions], "Headers", requestHeaders),
		response = Web.Contents(
			requestUrl,
			requestOptionsWithHeaders
		)
	in
		HandleResponse(response, requestUrl, true, requestData, connection[libraryUrl]);

// POST /reports/{id}/instances/{instanceId}/promptsAnswers
Rest.PostInstancePromptsAnswers = (connection as record, projectId as text, reportId as text, instanceId as text, requestBody as binary) =>
	let
		auth = getCurrentCredentials(connection),
		restApiUrl = connection[restApiUrl],
		requestUrl = connection[restApiUrl]  & "reports/" & reportId & "/instances/" & instanceId & "/promptsAnswers",
		requestData = [
			requestUrl = requestUrl,
			requestHeadersWithoutCreds = [
				Accept = "application/json",
				#"Content-Type"="application/json",
				#"X-MSTR-ProjectID"=projectId
			],
			requestOptions = [
				IsRetry = true,
				Content = requestBody,
				ManualCredentials = true,
				ManualStatusHandling = {400, 401, 500},
				Timeout=#duration(0, 0, 0, connection[timeout])
			]
		],
		requestHeaders = Record.Combine({
			requestData[requestHeadersWithoutCreds],
			[
				#"X-MSTR-AuthToken"=auth[xtoken],
				Cookie=auth[xcookie]
			]
		}),
		requestOptionsWithHeaders = Record.AddField(requestData[requestOptions], "Headers", requestHeaders),
		response = Web.Contents(
			requestUrl,
			requestOptionsWithHeaders
		)
	in
		CheckResponse(response, requestUrl, true, requestData, connection[libraryUrl]);

// GET /config/oidc/native
Rest.GetOIDCConfigData = (restApiUrl as text) =>
	let
		OIDCConfigDataUrl = restApiUrl & "config/oidc/native",
		getResult = Web.Contents(
			OIDCConfigDataUrl
		)
	in
		HandleResponse(getResult, OIDCConfigDataUrl);

// POST /auth/oidc/token - this endpoint is used WITHOUT "api" part
Rest.ExchangeOIDCTokenForMstrTokens = (libraryUrl as text, credentials) =>
	let
		requestUrl = libraryUrl & "auth/oidc/token",
		requestData = [
			requestUrlWithParams = requestUrl & "?" & Uri.BuildQueryString([
				loginMode = OIDC_LOGIN_MODE,
				applicationType = Number.ToText(APPLICATION_TYPE)
			]),
			requestOptions = [
				Headers = [
					Accept = "application/json, application/x-x509-user-cert",
					#"X-Requested-With" = "XMLHttpRequest",
					#"Content-Type" = "application/json; charset=utf-8"
				],
				Content = Json.FromValue([
					access_token = credentials[access_token],
					id_token = credentials[id_token],
					token_type = "Bearer",
					expires_in = 0
				]),
				ManualStatusHandling = {401}
			]
		],
		response = Web.Contents(
			requestData[requestUrlWithParams],
			requestData[requestOptions]
		)
	in
		CredsFromHeaders(Value.Metadata(CheckResponse(response, requestUrl))[Headers]);

// Utilities, copy-pasted from docs which say they should be implemented in the STL eventually.

NavigationTable.FromRows = (rows as list) =>
	let
		table = Table.FromRows(rows, {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"})
	in
		Table.ToNavigationTable(table, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

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
