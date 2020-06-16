// This file contains your Data Connector logic
[Version = "1.0.0"]
section MicroStrategyDataset;

VERSION = Extension.LoadString("VERSION");
DEFAULT_LIMIT = 25000;
DEFAULT_TIMEOUT = 100;
APPLICATION_TYPE = 46;
LOCALE = Extension.LoadString("Locale");
TEST_CONNECTION_TIMEOUT = 10;

[DataSource.Kind="MicroStrategyDataset", Publish="MicroStrategyDataset.Publish"]
shared MicroStrategyDataset.Contents = Value.ReplaceType(MicroStrategyDataset.Contents.Impl, MicroStrategyDataset.Contents.Type);

// Shared version with unambigous name for TestConnection
[DataSource.Kind="MicroStrategyDataset"]
shared MicroStrategyDataset.TestConnection = Value.ReplaceType(
	(apiUrl as text) => Server.GetStatus(FixApiUrl(apiUrl), TEST_CONNECTION_TIMEOUT),
	type function (apiServer as Uri.Type) as any
);

// Data Source Kind record; the name is (unfixably atm) displayed in the login window, hence it being so generic.
MicroStrategyDataset = [
	TestConnection = (apiServer as text) => {"MicroStrategyDataset.TestConnection", apiServer},
	Authentication = [
		//Key = [],
		UsernamePassword = [
			Label = "Authentication"
		]
		//Windows = [],
		//Implicit = []
	]//,
	//Label = Extension.LoadString("DataSourceName")
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

MicroStrategyDataset.Contents.Type = let
		apiServerType = Uri.Type meta [
			Documentation.FieldCaption = Extension.LoadString("ApiUrl"),
			Documentation.FieldDescription = Extension.LoadString("ApiUrlDesc"),
			Documentation.SampleValues = {"https://mstr.mycompany.com/MicroStrategyLibrary/api"}
		],
		authModeType = type text meta [
			Documentation.FieldCaption = Extension.LoadString("AuthMode"),
			Documentation.FieldDescription = Extension.LoadString("AuthModeDesc") & " " & Extension.LoadString("DefaultIs") & Extension.LoadString("StandardAuth"),
			Documentation.AllowedValues = {Extension.LoadString("StandardAuth"), Extension.LoadString("LDAPAuth")}
		],
		optionsType = let
				limitType = type nullable number meta [
					Documentation.FieldCaption = Extension.LoadString("LimitDesc"),
					Documentation.FieldDescription = Extension.LoadString("LimitDescLong") & " " & Extension.LoadString("DefaultIs") & Number.ToText(DEFAULT_LIMIT),
					Documentation.SampleValues = {Text.From(DEFAULT_LIMIT) & " " & Extension.LoadString("DefaultMark")}
				],
				timeoutType = type nullable number meta [
					Documentation.FieldCaption = Extension.LoadString("TimeoutDesc"),
					Documentation.FieldDescription = Extension.LoadString("TimeoutDescLong") & " " & Extension.LoadString("DefaultIs") & Number.ToText(DEFAULT_TIMEOUT),
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
			apiServer as apiServerType,
			optional authMode as authModeType,
			optional options as optionsType
		) as table meta [
			Documentation.Name = Extension.LoadString("DataSourceName") & " ver. " & VERSION
		];

// Implemtation of the function to fetch data from MicroStrategy Dataset
MicroStrategyDataset.Contents.Impl = (apiServer as text, optional authMode as text, optional options as record) as table =>
	let
		_authMode = if authMode = Extension.LoadString("LDAPAuth") then authMode else Extension.LoadString("StandardAuth"),
		_options = if options <> null then options else [ limit = null, timeout = null],
		timeout = if (_options[timeout] <> null) then _options[timeout] else DEFAULT_TIMEOUT,
		limit = if (_options[limit] <> null) then _options[limit] else DEFAULT_LIMIT,

		api = FixApiUrl(apiServer),

		// Authenticate user, get the token and cookie
		auth = Authenticate(api, _authMode, timeout),

		NavTable = FindProjects(auth, api, limit, timeout)
	in
		NavTable;

FixApiUrl = (apiUrl as text) =>
	let
		ensureApi = (x) => if Text.EndsWith(x, "api/") then x else x & "api/"
	in
		ensureApi(if Text.EndsWith(apiUrl, "/") then apiUrl else apiUrl & "/");

FindProjects = (auth as record, api as text, _limit as number, _timeout as number) =>
	let
		projectUrl = api & "projects",
		result = Web.Contents(
			projectUrl,
			[
				Headers = [
					Accept = "application/json",
					#"X-MSTR-AuthToken" = auth[xtoken],
					Cookie = auth[xcookie]
				],
				IsRetry = false,
				ManualCredentials = true,
				ManualStatusHandling = {400, 401, 403, 404, 500},
				Timeout = #duration(0, 0, 0, _timeout)
			]
		),
		md = Value.Metadata(result),
		jResult = try Json.Document(result),

		NavTable = if jResult <> null and md[Response.Status] <> 200
			then (
				if jResult[HasError]
				then
					error (Extension.LoadString("ErrorContents") & " " & projectUrl & "#(lf)" & Extension.LoadString("StatusCode") & " " & Number.ToText(md[Response.Status]))
				else
					error (jResult[Value])[message]
			) else
				let
					jResult = jResult[Value],
					objects = List.Transform(jResult, (project) => {project[name], project[id], FindRootFolders(auth, api, project[id], _limit, _timeout), "Folder", "Folder", false}),
					ot = Table.FromRows(objects, {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}),
					nt = Table.ToNavigationTable(ot, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
				in
					nt
	in
		NavTable;

FindRootFolders = (auth as record, api as text, projectId as text, _limit as number, _timeout as number) =>
	let
		rootFolderUrl = api & "folders",
		result = Web.Contents(
			rootFolderUrl,
			[
				Query = [
					offset = "0",
					limit = "-1"
				],
				Headers = [
					Accept="application/json",
					#"X-MSTR-AuthToken"=auth[xtoken],
					#"X-MSTR-ProjectID"=projectId,
					Cookie=auth[xcookie]
				],
				IsRetry=false,
				ManualCredentials = true,
				ManualStatusHandling={400, 401, 404, 500},
				Timeout=#duration(0, 0, 0, _timeout)
			]
		),
		md = Value.Metadata(result),
		jResult = try Json.Document(result),

		NavTable = if jResult <> null and md[Response.Status] <> 200
			then (
				if jResult[HasError]
				then
					error (Extension.LoadString("ErrorContents") & " " & rootFolderUrl & "#(lf)" & Extension.LoadString("StatusCode") & " " & Number.ToText(md[Response.Status]))
				else
					error (jResult[Value])[message]
			) else
				let
					jResult = jResult[Value],
					visFolders = List.Select(jResult, (project) => Record.HasFields(project, "hidden") <> true),
					objects = List.Transform(visFolders, (folder) => {folder[name], folder[id], FindFolderContent(auth, api, projectId, folder[id], _limit, _timeout), "Folder", "Folder", false}),
					rootFolders = List.InsertRange(objects, List.Count(objects) - 1, {{Extension.LoadString("PersonalObjects"), "1", FindFolderContent(auth, api, projectId, "1", _limit, _timeout), "Folder", "Folder", false}}),
					ot = Table.FromRows(rootFolders, {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}),
					nt = Table.ToNavigationTable(ot, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
				in
					nt
	in
		NavTable;

FindFolderContent = (auth as record, api as text, projectId as text, folderId as text, _limit as number, _timeout as number) =>
	let
		folderUrl = if folderId = "1" then api & "folders/myPersonalObjects" else api & "folders/" & folderId,
		result = Web.Contents(
			folderUrl,
			[
				Query = [
					offset = "0",
					limit = "-1"
				],
				Headers=[
					Accept="application/json",
					#"X-MSTR-AuthToken"=auth[xtoken],
					#"X-MSTR-ProjectID"=projectId,
					Cookie=auth[xcookie]
				],
				IsRetry=false,
				ManualCredentials = true,
				ManualStatusHandling={400, 401, 404, 500},
				Timeout=#duration(0, 0, 0, _timeout)
			]
		),
		md = Value.Metadata(result),
		jResult = try Json.Document(result),

		NavTable = if jResult <> null and md[Response.Status] <> 200
			then (
				if jResult[HasError]
				then
					error (Extension.LoadString("ErrorContents") & " " & folderUrl & "#(lf)" & Extension.LoadString("StatusCode") & " " & Number.ToText(md[Response.Status]))
				else
					error (jResult[Value])[message]
			) else
				let
					jResult = jResult[Value],
					validObjects = List.Select(jResult, (result) => (result[type] = 8 or result[type] = 3 and result[subtype] <> 781 ) and Record.HasFields(result, "hidden") <> true),
					objects = List.Transform(validObjects, (obj) =>
						let
							kind = if obj[type] = 8 then "Folder" else if obj[type] = 3 and (obj[subtype] = 776 or obj[subtype] = 779) then "CubeView" else "Table",
							isLeaf = if obj[type] = 8 then false else true,
							isCube = if obj[subtype] = 779 or obj[subtype] = 776 then true else false,
							data = if obj[type] = 8 then FindFolderContent(auth, api, projectId, obj[id], _limit, _timeout) else MicroStrategyDataset.View(auth, api, projectId, obj[id], isCube, _limit, _timeout),
							row = {obj[name], obj[id], data, kind, kind, isLeaf}
						in
							row
						),
					ot = Table.FromRows(objects, {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}),
					nt = Table.ToNavigationTable(ot, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
				in
					nt
	in
		NavTable;

// JSON parsing utils
getName = each _[name];
V1.getMetricHeader = (met) =>
	let
		basicType = if Value.Is(met[min], Number.Type) then Number.Type else Text.Type,
		derivedType = deriveMetricType(met[numberFormatting], basicType)
	in
		{met[name], derivedType};
V1.getAttributeHeaderLists = (attr) => List.Transform(attr[forms], (form) => {attr[name] & " " & form[name], mapType(form[dataType], V1.TYPEMAP)});
V1.getAttributeHeaders = (attributes) => List.Combine(List.Transform(attributes, V1.getAttributeHeaderLists));
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
	// doubleDouble - "accurate double datatype, has at most 34 significant digits, only for internal use"
];
mapType = (mstrTypename as text, typemap as record) => if Record.HasFields(typemap, mstrTypename) then Record.Field(typemap, mstrTypename) else Text.Type;
V2.getMetricHeader = (met as record) =>
	let
		basicType = mapType(met[dataType], V2.TYPEMAP),
		// All number types have number as their supertype, making Type.Is return true. We want to further analyse them to determine if they should be displayed as percentages etc.
		derivedType = deriveMetricType(met[numberFormatting], basicType)
	in
		{met[name], derivedType};
V2.getAttributeHeaderLists = (attr) => List.Transform(attr[forms], (form) => {attr[name] & " " & form[name], mapType(form[dataType], V2.TYPEMAP)});
V2.getAttributeHeaders = (attributes) => List.Combine(List.Transform(attributes, V2.getAttributeHeaderLists));

deriveMetricType = (formatting as record, inputType as type) =>
	if Type.Is(inputType, Number.Type)
	then
		if Text.Contains(formatting[formatString], "%")
		then
			Percentage.Type
		else
			if Text.Contains(formatting[formatString], "$")
			then
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
			if Record.HasFields(root, "children") <> true
			then
				let
					hasElement = if Record.HasFields(root, "element") then List.Transform(Record.FieldNames(root[element][formValues]), (keyName) => Record.Field(root[element][formValues], keyName)) else null,
					hasMetrics = if Record.HasFields(root, "metrics") then List.Transform(Record.FieldNames(root[metrics]), (item) => Record.Field(root[metrics], item)[rv]) else null,
					hasElementMetrics = if hasElement = null
						then
							hasMetrics
						else
							if hasMetrics = null then hasElement else hasElement & hasMetrics
				in
					{hasElementMetrics}
			else
				let
					rn = if Record.HasFields(root, "element")
						then
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
		// hasSubtotals receives a pair, {attributeRow, metricRow}
		hasSubtotals = (row) => List.MatchesAny(List.Zip({List.Positions(row{0}), row{0}}), (x) => lookupAttributeSubtotal(x)),
		metricRows = jResult[data][metricValues][raw],
		rawAttributeRows = jResult[data][headers][rows],
		rowPairs = List.Zip({rawAttributeRows, metricRows}),
		selectedRows = List.Select(rowPairs, (x) => not hasSubtotals(x))
	in
		// There might be a case that only metrics have been pulled, resulting in a single row of just metric data. Such a case bypasses most of the above.
		if hasAttributes
		then
			List.Transform(selectedRows, (x) => List.Combine({List.Combine(lookupAttributeRow(x{0})), x{1}}))
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
		metrics = grid[columns]{0},
		attributeHeaders = V2.getAttributeHeaders(attributes),
		metricHeaders = List.Transform(metrics[elements], V2.getMetricHeader)
	in
		List.Combine({attributeHeaders, metricHeaders});

// Get a table type from headers
ColumnHeaders.ToTableType = (headers as list) => let
		// We have list of `{name, type}` pairs we want to convert to a single record, which has `name = [Type = type, Optional = false]` entries
		headerRecord = List.Accumulate(headers, [], (state, current) => Record.Combine({state, Record.FromList({[Type = current{1}, Optional = false]}, {current{0}})})),
		recordType = Type.ForRecord(headerRecord, false)
	in
		type table (recordType);

ColumnHeaders.ToNames = (headers as list) => List.Transform(headers, (x) => x{0});

// Table View wrapping a dataset and implementing query folding for simple data manipulation like Table.FirstN.
MicroStrategyDataset.View = (auth as record, apiServer as text, projectId as text, datasetId as text, isCube as logical, limit as number, timeout as number) =>
	let
		isV2 = Server.IsV2Compatible(apiServer, timeout),
		toTableRows = if isV2 then MicroStrategyDataset.FromV2 else MicroStrategyDataset.FromV1,
		getColumnHeaders = if isV2 then MicroStrategyDataset.ColumnHeadersFromV2 else MicroStrategyDataset.ColumnHeadersFromV1,
		datasetType = if isCube then "cubes" else "reports",
		datasetPath = datasetType & "/" & datasetId,
		datasetUrl = (if isV2 then apiServer & "v2/" else apiServer) & datasetPath,
		promptsUrl = apiServer & datasetPath & "/prompts",
		instancesUrl = datasetUrl & "/instances",
		instanceData =
			let
				requestBody = if isCube or not isV2
					then
						Json.FromValue([])
					else
						let
							// If the report has an object prompt, the definition thing will cause an error. Check for prompts before doing it.
							isNotPrompted = List.IsEmpty(GetPrompts(auth, promptsUrl, projectId, timeout)),
							definition = if isNotPrompted then GetDefinition(auth, datasetUrl, projectId, timeout)[definition] else error Extension.LoadString("ErrorPrompted"),
							joinedList = definition[grid][rows] & definition[grid][columns]
						in
							Json.FromValue([
								requestedObjects = [
									attributes = List.Transform(List.Select(joinedList, each _[type] = "attribute"), each [id = _[id], forms = List.Transform(_[forms], each [id = _[id]])]),
									metrics = List.Transform(List.Select(joinedList, each _[type] = "templateMetrics"){0}[elements], each [id = _[id]])
								],
								viewFilter = null
							])
			in
				PostInstance(auth, instancesUrl, projectId, requestBody, 1, timeout)
	in
		let
			// Instance data for use with View
			Instance = [
				Data = instanceData,
				Id = Data[instanceId],
				Url = instancesUrl & "/" & Id,
				rowCount = (if isV2 then Data else Data[result])[data][paging][total],
				headers = getColumnHeaders(Data),
				tableType = ColumnHeaders.ToTableType(headers)
			],
			// Function to construct a Table View from state parameters
			View = (state as record) => Table.View(null, [
				// Stateless handler returning table type with all column types
				GetType = () => Instance[tableType],
				// The main handler to pull final dataset, depends on the view state (that we implement with the `View` wrapper)
				GetRows = () => Table.TransformColumnTypes(#table(ColumnHeaders.ToNames(Instance[headers]), GetRows(auth, Instance[Url], projectId, state, toTableRows, timeout)), Instance[headers], "en-US"),
				// Return the final number of rows that will be pulled
				GetRowCount = () as number => state[rowCount] - state[offset],
				// Return a modified view that returns only `count` top rows.
				OnTake = (count as number) => if count < state[rowCount] then @View(state & [rowCount = count]) else @View(state),
				// Return a modified view that skips `count` top rows.
				OnSkip = (count as number) => @View(state & [offset = state[offset] + count])
			])
		in
			View([offset = 0, limit = limit, rowCount = Instance[rowCount]]);

/*
 * @param paging A record with `offset`, `limit` and `rowCount` fields.
 */
GetRows = (auth as record, instanceUrl as text, projectId as text, paging as record, toTableRows as function, timeout as number) =>
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
		fetchPage = (pair) => GetInstance(auth, instanceUrl, projectId, pair{0}, pair{1}, timeout),
		fetchedPages = List.Transform(pagesToFetch, fetchPage)
	in
		// Create a list of the first page and all other fetched pages, combine the resulting list of pages into one gigantic page. (still in list of lists form)
		List.Combine(List.Transform(fetchedPages, toTableRows));

// GET /<cubes|reports>/{id}
GetDefinition = (auth as record, datasetUrl as text, projectId as text, timeout as number) =>
	let
		postResult = Web.Contents(
			datasetUrl,
			[
				Headers = [
					Accept="application/json",
					#"Content-Type"="application/json",
					#"X-MSTR-AuthToken" = auth[xtoken],
					#"X-MSTR-ProjectID" = projectId,
					Cookie=auth[xcookie]
				],
				IsRetry = false,
				ManualCredentials = true,
				ManualStatusHandling={400, 401, 404, 500, 501},
				Timeout=#duration(0, 0, 0, timeout)
			]
		)
	in
		HandleResponse(postResult, datasetUrl);

// GET /<cubes|reports>/{id}/prompts
GetPrompts = (auth as record, promptsUrl as text, projectId as text, timeout as number) =>
	let
		postResult = Web.Contents(
			promptsUrl,
			[
				Headers = [
					Accept="application/json",
					#"Content-Type"="application/json",
					#"X-MSTR-AuthToken" = auth[xtoken],
					#"X-MSTR-ProjectID" = projectId,
					Cookie=auth[xcookie]
				],
				IsRetry = false,
				ManualCredentials = true,
				ManualStatusHandling={400, 401, 404, 500, 501},
				Timeout=#duration(0, 0, 0, timeout)
			]
		)
	in
		HandleResponse(postResult, promptsUrl);

// POST /<cubes|reports>/{id}/instances
PostInstance = (auth as record, instancesUrl as text, projectId as text, requestBody as binary, limit as number, timeout as number) =>
	let
		postResult = Web.Contents(
			instancesUrl,
			[
				Query = [
					offset = "0",
					limit = Text.From(limit)
				],
				Headers = [
					Accept="application/json",
					#"Content-Type"="application/json",
					#"X-MSTR-AuthToken" = auth[xtoken],
					#"X-MSTR-ProjectID" = projectId,
					Cookie=auth[xcookie]
				],
				Content = requestBody,
				IsRetry = false,
				ManualCredentials = true,
				ManualStatusHandling={400, 401, 404, 500, 501},
				Timeout=#duration(0, 0, 0, timeout)
			]
		)
	in
		HandleResponse(postResult, instancesUrl);

// GET /<cubes|reports>/{id}/instances/{instanceId}
GetInstance = (auth as record, instanceUrl as text, projectId as text, offset as number, limit as number, timeout as number) =>
	let
		postResult = Web.Contents(
			instanceUrl,
			[
				Query = [
					offset = Text.From(offset),
					limit = Text.From(limit)
				],
				Headers = [
					Accept="application/json",
					#"Content-Type"="application/json",
					#"X-MSTR-AuthToken"=auth[xtoken],
					#"X-MSTR-ProjectID"=projectId,
					Cookie=auth[xcookie]
				],
				IsRetry = false,
				ManualCredentials = true,
				ManualStatusHandling={400, 401, 404, 500, 501},
				Timeout=#duration(0, 0, 0, timeout)
			]
		)
	in
		HandleResponse(postResult, instanceUrl);

//Function to authenticate user and return the token and cookie
Authenticate = (apiServer as text, authMode as text, _timeout as number) =>
	let
		loginMode = if authMode = Extension.LoadString("StandardAuth") then "1" else "16",
		credentials = Extension.CurrentCredential(),
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
		url = apiServer & "auth/login",
		result = Web.Contents(
			url,
			[
				Headers = [
					Accept = "application/json",
					#"Content-Type" = "application/json"
				],
				Content = content,
				IsRetry = false,
				ManualCredentials = true,
				Timeout=#duration(0, 0, 0, _timeout)
			]
		),
		md = Value.Metadata(result),
		jResult = try Json.Document(result),
		output = if jResult <> null and md[Response.Status] <> 204
			then (
				if jResult[HasError]
				then
					error (Extension.LoadString("ErrorContents") & " " & url & "#(lf)" & Extension.LoadString("StatusCode") & " " & Number.ToText(md[Response.Status]))
				else
					error (jResult[Value])[message]
			) else
				[
					xtoken=md[Headers][#"X-MSTR-AuthToken"],
					xcookie=Text.Combine(List.Combine(List.Transform(Text.Split(md[Headers][#"Set-Cookie"], ","), (str) => Text.Split(str, ";"))), "; ")
				]
	 in
		output;

Server.IsV2Compatible = (apiServer as text, timeout as number) =>
	let
		V2_SINCE = MicroStrategyDataset.VersionFromText("11.1.0300"),
		status = Server.GetStatus(apiServer, timeout),
		iVer = MicroStrategyDataset.VersionFromText(status[iServerVersion]),
		webVer = MicroStrategyDataset.VersionFromText(status[webVersion])
	in
		MicroStrategyDataset.VersionIsCompatible(iVer, V2_SINCE) and MicroStrategyDataset.VersionIsCompatible(webVer, V2_SINCE);

// Request server status
Server.GetStatus = (apiServer as text, timeout as number) =>
	let
		url = apiServer & "status",
		result = Web.Contents(
			url,
			[
				Headers = [
					Accept = "application/json"
				],
				IsRetry = false,
				Timeout=#duration(0, 0, 0, timeout)
			]
		)
	in
		HandleResponse(result, url);

MicroStrategyDataset.VersionFromText = (verstring as text) =>
	let
		split = Text.Split(verstring, ".")
	in
		List.Transform(split, Number.FromText);

// Check if version "tocheck" is same or newer than version "checkref", meaning it should be backwards-compatible.
MicroStrategyDataset.VersionIsCompatible = (tocheck as list, checkref as list) =>
	// If we ran out of version parts to check without resolving, either both versions are exactly equal or we ran out of precision we care about, so the answer is yes.
	if List.IsEmpty(tocheck) or List.IsEmpty(checkref)
	then
		true
	else
		// if the considered version part is higher, the answer is yes, if lower then no, if equal then continue to further parts.
		if tocheck{0} > checkref{0}
		then
			true
		else
			if tocheck{0} < checkref{0}
			then
				false
			else
				@MicroStrategyDataset.VersionIsCompatible(List.Skip(tocheck), List.Skip(checkref));

// Takes a possibly erroneous response, if it has error, handles it and returns a meaningful error, if not returms the parsed response.
HandleResponse = (response, targetUrl) =>
	let
		md = Value.Metadata(response),
		jResult = Json.Document(response)
	in
		if jResult <> null and md[Response.Status] = 200
		then
			jResult
		else
			let
				triedResult = try jResult
			in
				if triedResult[HasError]
				then
					error (Extension.LoadString("ErrorContents") & " " & targetUrl & "#(lf)" & Extension.LoadString("StatusCode") & " " & Number.ToText(md[Response.Status]))
				else
					let
						errorData = triedResult[Value]
					in
						error [Message = errorData[message], Detail = Record.RemoveFields(errorData, "message")];

// Utilities, copy-pasted from docs which say they should be implemented in the STL eventually.
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
