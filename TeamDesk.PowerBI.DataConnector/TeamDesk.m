// Copyright (c) 2017-2018 ForeSoft Corporation

[Version = "1.0.1"]
section TeamDesk;

// Max numbers of records API can return
QueryPageSize = 500;

// Data Source Kind description
TeamDesk = [
    Label = Extension.LoadString("DataSourceName"),
	TestConnection = (dataSourcePath) => {"TeamDesk.Database", dataSourcePath},
    Authentication = [
        UsernamePassword = [
			UsernameLabel = Extension.LoadString("AuthUserNameLabel") // "e-mail" instead of user
		],
		Key = [
			Label = Extension.LoadString("AuthKeyName"),
			KeyLabel = Extension.LoadString("AuthKeyLabel")
		]
    ]
];

// Data Source UI publishing description
TeamDesk.Publish = [
    Beta = true,
    Category = "Online Services",
    ButtonText = { Extension.LoadString("DataSourceName"), Extension.LoadString("DataSourceHelp") },
    LearnMoreUrl = "https://teamdesk.crmdesk.com/answer.aspx?aid=25065",
    SourceImage = TeamDesk.Icons,
    SourceTypeImage = TeamDesk.Icons
];

TeamDesk.Icons = [
    Icon16 = { Extension.Contents("teamdesk16.png"), Extension.Contents("teamdesk20.png"), Extension.Contents("teamdesk24.png"), Extension.Contents("teamdesk32.png") },
    Icon32 = { Extension.Contents("teamdesk32.png"), Extension.Contents("teamdesk40.png"), Extension.Contents("teamdesk48.png"), Extension.Contents("teamdesk64.png") }
];

[DataSource.Kind = "TeamDesk", Publish = "TeamDesk.Publish"]
shared TeamDesk.Database = Value.ReplaceType(DatabaseImpl, type function (
	url as (Uri.Type meta [
		Documentation.FieldCaption = Extension.LoadString("ParamUrlCaption"),
		Documentation.FieldDescription = Extension.LoadString("ParamUrlDescription"),
		Documentation.SampleValues = { Extension.LoadString("ParamUrlExample") }
	])) as table meta [
		Documentation.Name = Extension.LoadString("FnDatabaseName"),
		Documentation.LongDescription = Extension.LoadString("FnDatabaseDescription"),
		Documentation.Examples = {[
			Description = Extension.LoadString("FnDatabaseExample1"),
			Code = Text.Format("TeamDesk.Database(""#{0}"")", { Extension.LoadString("ParamUrlExample") }),
			Result = "Navigation table"
		]}
	]);

[DataSource.Kind = "TeamDesk"]
shared TeamDesk.SelectView = Value.ReplaceType(SelectViewImpl, type function (
	url as (Uri.Type meta [
		Documentation.FieldCaption = Extension.LoadString("ParamUrlCaption"),
		Documentation.FieldDescription = Extension.LoadString("ParamUrlDescription"),
		Documentation.SampleValues = { Extension.LoadString("ParamUrlExample") }
	]),
	optional table as (type text meta [
		Documentation.FieldCaption = Extension.LoadString("ParamTableCaption"),
		Documentation.FieldDescription = Extension.LoadString("ParamTableDescription"),
		Documentation.SampleValues = { Extension.LoadString("ParamTableExample") }
	]), 
	optional view as (type text meta [
		Documentation.FieldCaption = Extension.LoadString("ParamViewCaption"),
		Documentation.FieldDescription = Extension.LoadString("ParamViewDescription"),
		Documentation.SampleValues = { Extension.LoadString("ParamViewExample") }
	]),
	optional filter as (type text meta [
		Documentation.FieldCaption = Extension.LoadString("ParamFilterCaption"),
		Documentation.FieldDescription = Extension.LoadString("ParamFilterDescription"),
		Documentation.SampleValues = { Extension.LoadString("ParamFilterExample") }
	])) as table meta [
		Documentation.Name = Extension.LoadString("FnSelectViewName"),
		Documentation.LongDescription = Extension.LoadString("FnSelectViewDescription"),
		Documentation.Examples = {[
			Description = Extension.LoadString("FnSelectViewExample1"),
			Code = Text.Format("TeamDesk.SelectView(""#{0}"", ""#{1}"", ""#{2}"")", {
				Extension.LoadString("ParamUrlExample"),
				Extension.LoadString("ParamTableExample"),
				Extension.LoadString("ParamViewExample")
				}),
			Result = Extension.LoadString("FnSelectExample1Result")
		], [
			Description = Extension.LoadString("FnSelectViewExample2"),
			Code = Text.Format("TeamDesk.SelectView(""#{0}"", ""#{1}"", ""#{2}"", ""#{3}"")", {
				Extension.LoadString("ParamUrlExample"),
				Extension.LoadString("ParamTableExample"),
				Extension.LoadString("ParamViewExample"),
				Extension.LoadString("ParamFilterExample")
				}),
			Result = Extension.LoadString("FnSelectExample1Result")
		]}
	]);

[DataSource.Kind = "TeamDesk"]
shared TeamDesk.Select = Value.ReplaceType(SelectImpl, type function (
	url as (Uri.Type meta [
		Documentation.FieldCaption = Extension.LoadString("ParamUrlCaption"),
		Documentation.FieldDescription = Extension.LoadString("ParamUrlDescription"),
		Documentation.SampleValues = { Extension.LoadString("ParamUrlExample") }
	]),
	optional table as (type text meta [
		Documentation.FieldCaption = Extension.LoadString("ParamTableCaption"),
		Documentation.FieldDescription = Extension.LoadString("ParamTableDescription"),
		Documentation.SampleValues = { Extension.LoadString("ParamTableExample") }
	]), 
	optional columns as (type any meta [
		Documentation.FieldCaption = Extension.LoadString("ParamColumnsCaption"),
		Documentation.FieldDescription = Extension.LoadString("ParamColumnsDescription"),
		Documentation.SampleValues = { Extension.LoadString("ParamColumnsExample") }
	]), 
	optional filter as (type text meta [
		Documentation.FieldCaption = Extension.LoadString("ParamFilterCaption"),
		Documentation.FieldDescription = Extension.LoadString("ParamFilterDescription"),
		Documentation.SampleValues = { Extension.LoadString("ParamFilterExample") }
	]), 
	optional orderBy as (type any meta [
		Documentation.FieldCaption = Extension.LoadString("ParamOrderByCaption"),
		Documentation.FieldDescription = Extension.LoadString("ParamOrderByDescription"),
		Documentation.SampleValues = { Extension.LoadString("ParamOrderByExample") }
	])) as table meta [
		Documentation.Name = Extension.LoadString("FnSelectName"),
		Documentation.LongDescription = Extension.LoadString("FnSelectDescription"),
		Documentation.Examples = {[
			Description = Extension.LoadString("FnSelectExample1"),
			Code = Text.Format("TeamDesk.Select(""#{0}"", ""#{1}"", { #{2} })", {
				Extension.LoadString("ParamUrlExample"),
				Extension.LoadString("ParamTableExample"),
				Text.Combine(List.Transform(Text.Split(Extension.LoadString("ParamColumnsExample"), ";"), each """" & Text.Trim(_) & """"), ", ")
				}),
			Result = Extension.LoadString("FnSelectExample1Result")
		]}
	]);

// implementation for TeamDesk.Database
DatabaseImpl = (url as text) as table =>
	let
		apiBaseURL = GetBaseApiURL(url)
	,	tables = GetApiJson(apiBaseURL, "describe")[tables]
	,	objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
			List.Transform(tables, (tentry) => { 
				tentry[recordsName], 
				tentry[recordName], 
				((tableName as text) => 
					let tdesc = GetApiJson(apiBaseURL, "describe", tableName)
					,	objects = #table(
							{"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
							List.Transform(
								List.Select(tdesc[views], IsViewSupported), 
								(vdesc) => { vdesc[name], vdesc[name], SelectViewData(apiBaseURL, tdesc, vdesc), "View", "View", true }))
					in
						Table.ToNavigationTable(objects, { "Key" }, "Name", "Data", "ItemKind", "ItemName", "IsLeaf"))(tentry[recordName]), 
				"Table",
				"Table",
				false 
			}))
    in
        Table.ToNavigationTable(objects, { "Key" }, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

// implementation for TeamDesk.SelectView
SelectViewImpl = (url as text, optional table as text, optional view as text, optional filter as text) =>
	let	
		apiBaseURL = GetBaseApiURL(url)
	,	tableChecked = if table = null then error GetError("ErrNoTableName") else table
	,	viewChecked = if view = null then error GetError("ErrNoViewName") else view
	,	tableDesc = GetApiJson(apiBaseURL, "describe", tableChecked)
	,	viewDescs = List.Select(tableDesc[views], each Comparer.OrdinalIgnoreCase([name], viewChecked) = 0)
	,	viewDesc = if List.Count(viewDescs) <> 1 then error GetError("ErrNoView") else viewDescs{0}
	,	viewDescChecked = if IsViewSupported(viewDesc) then viewDesc else error GetError("ErrBadViewType", { viewDesc[type] })
	in 
		SelectViewData(apiBaseURL, tableDesc, viewDescChecked, filter);

// implementation for TeamDesk.Select
SelectImpl = (url as text, optional table as text, optional columns as any, optional filter as text, optional orderBy as any) as any =>
	let	
		apiBaseURL = GetBaseApiURL(url)
	,	query = []
	,	tableChecked = if table = null then error GetError("ErrNoTableName") else table
	,	columnList = if columns is list then columns else if columns is text then List.Transform(Text.Split(columns, ";"), Text.Trim) else error GetError("ErrBadColumns")
	,	columnListChecked = if List.Count(columnList) = 0 then error GetError("ErrNoColumns") else columnList
	,	columnListCheckedStar = if List.Contains(columnListChecked, "*") then error GetError("ErrNoStarColumn") else columnListChecked
	,	withColumns = Record.AddField(query, "column", columnList)
	,	withFilter = if filter <> null then Record.AddField(withColumns, "filter", filter) else withColumns
	,	withSort = if orderBy <> null then 
			Record.AddField(withFilter, "sort", 
				if orderBy is list then orderBy 
				else if orderBy is text then List.Transform(Text.Split(orderBy, ";"), Text.Trim) 
				else error GetError("ErrBadOrder"))
			else withFilter
	,	tableDesc = GetApiJson(apiBaseURL, "describe", tableChecked)
	,	columnDefTransform = CreateColumnTransforms(tableDesc, columnListCheckedStar)
	,   resultList = GenerateByPage((skip) => SelectGetPage(apiBaseURL, tableChecked, null, withSort, skip, QueryPageSize))
	in
		CreateResult(resultList, columnDefTransform);

// helper shared between .Database and .SelectView
SelectViewData = (apiBaseURL as text, tableDesc as record, vdesc as record, optional filter as text) as table =>
	let query = []
	,	withFilter = if filter <> null then Record.AddField(query, "filter", filter) else query
	,	columnList = if vdesc[columns]? <> null then vdesc[columns] else List.Transform(List.Select(tableDesc[columns], each Text.Contains([displayOptions]?,"ShowInViews")), each [name])
	,	columnListWithGroups = if vdesc[groups]? <> null then vdesc[groups] & columnList else columnList
	,	columnDefTransform = CreateColumnTransforms(tableDesc, columnListWithGroups)
	,   resultList = GenerateByPage((skip) => SelectGetPage(apiBaseURL, tableDesc[recordName], vdesc[name], withFilter, skip, QueryPageSize))
	in
		CreateResult(resultList, columnDefTransform);

// pagination helper
GenerateByPage = (getPage as function) as list =>
	List.Combine(
		List.Generate(
		() => getPage(0), 
		each _ <> null, 
		each if not [stop] then getPage([skip]) else null, 
		each [data]));

// select.json API helper
SelectGetPage = (apiBaseURL as text, table as text, view as nullable text, query as record, skip as number, pageSize as number) as record =>
	let withTop = if pageSize <> 500 then Record.AddField(query, "top", Text.From(pageSize)) else query
	,	withSkip = if skip <> 0 then Record.AddField(withTop, "skip", Text.From(skip)) else withTop
	,	rawData = GetApiJson(apiBaseURL, "select", table, view, withSkip)
	,	stop = List.Count(rawData) < pageSize
	,	data = List.Select(rawData, each [#"@row.type"]? = null)
	in
		[ data = data, stop = stop, skip = skip + pageSize ];

GroupFuncs = { "EQ", "FW", "FL", "SS", "MI", "HH", "DD", "MM", "WK", "QQ", "YY", "DM", "MY", ".001", ".01", ".1", "1", "10", "100", "1K", "10K", "100K", "1M" };
AggregateFuncs = { "COUNT", "STDEV", "STDEVP", "VAR", "VARP", "SUM", "AVG", "MIN", "MAX" };
AllSuffixes = List.Combine({ GroupFuncs, AggregateFuncs });

// remove known grouping/aggregation suffixes
StripSuffix = (value as text, suffixes as list) as text =>
	let nameParts = Text.Split(value, "//")
	, partCount = List.Count(nameParts)
	, suffix = if partCount > 1 then List.Last(nameParts) else ""
	in
		if suffix <> "" and List.Contains(suffixes, suffix) 
		then Text.Start(value, Text.Length(value) - 2 - Text.Length(suffix))
		else value;

// translate column//SUM into Sum of column
TransformAggName = (value as text) as text =>
	let noSuffix = StripSuffix(value, AggregateFuncs)
	in
		if value <> noSuffix 
		then Text.Proper(Text.End(value, Text.Length(value) - Text.Length(noSuffix) - 2)) & " of " & noSuffix
		else value;

// create error record from resourceId
GetError = (resourceId as text, optional args) as record => 
	if args <> null then 
		Error.Record(resourceId, Text.Format(Extension.LoadString(resourceId), args))
	else
		Error.Record(resourceId, Extension.LoadString(resourceId));

// wrapper around API calls
GetApiJson = (apiBaseURL as text, method as text, optional table as text, optional view as text, optional query as record) => 
	let apiURL = apiBaseURL & 
		(if table <> null then "/" & EncodeUriPath(table) else "") & 
		(if view <> null then "/" & EncodeUriPath(view) else "") & 
		"/" & method & ".json"
	,	credentials = Extension.CurrentCredential()
	,	headers = if credentials[AuthenticationKind] = "Key" then [ Authorization = "Bearer " & credentials[Key] ] else null
	,	webResponse = Web.Contents(apiURL, [ Query = query, Headers = headers, ManualStatusHandling = {400,403,404,405,409,500,503} ])
	,	jsonResponse = try Json.Document(webResponse, 65001) otherwise null
	in
		if jsonResponse <> null then // response is JSON
			if Value.Metadata(webResponse)[Response.Status] >= 400 then // HTTP Error
				if jsonResponse is record and Record.HasFields(jsonResponse, { "error", "code", "message" }) then // our error descriptor
					if jsonResponse[code] >= 1000 and jsonResponse[code] < 2000 then // auth error
						error Extension.CredentialError(
							Text.Format("API_#[error]_#[code]", jsonResponse), 
							jsonResponse[message])
					else
						error Error.Record(
							Text.Format("API_#[error]_#[code]", jsonResponse),
							jsonResponse[message] & (if jsonResponse[source]? <> null then " (" & jsonResponse[source] & ")" else ""))
				else
					error GetError("ErrUnexpectedResult")
			else 
				jsonResponse
		else
			error GetError("ErrUnexpectedResult");

// convert Database URL into API URL
// https://<any-host>/secure/(db|api/v2)/dbID
GetBaseApiURL = (url as text) =>
	let 
		eq = (x as text, y as text) => Comparer.OrdinalIgnoreCase(x, y) = 0
	,	urlParts = Text.Split(Text.Replace(url, "/db/", "/api/v2/"), "/")
	in
		if List.Count(urlParts) >= 7 and 
			eq(urlParts{0}, "https:") and
			eq(urlParts{1}, "") and
			eq(urlParts{3}, "secure") and
			eq(urlParts{4}, "api") and 
			eq(urlParts{5}, "v2")
		then
			Text.Format("https://#{2}/secure/api/v2/#{6}", urlParts)
		else
			error GetError("ErrInvalidURL");

// double escape %, /, \ and ? in URL path
EncodeUriPath = (value as text) =>
	Uri.EscapeDataString(Text.Replace(Text.Replace(Text.Replace(Text.Replace(value, "%", "%25"), "/", "%2F"), "\", "%5C"), "?", "%3F"));

// creates list of transforms { "jsonField", type, convertor-fn, "displayName" }
CreateColumnTransforms = (tableDesc as record, columnList as list) as list =>
	let	columnListDistinct = List.Distinct(columnList)
	in
		List.Transform(columnListDistinct, (name) =>
			( let	noGroupSuffix = StripSuffix(name, GroupFuncs)
				,	retainSuffix = name <> noGroupSuffix and List.Contains(columnList, noGroupSuffix)
				,	properName = if retainSuffix then name else TransformAggName(noGroupSuffix)
				,	noSuffixName = StripSuffix(name, AllSuffixes)
				,	colDef = List.First(List.Select(tableDesc[columns], each Comparer.OrdinalIgnoreCase([name], noSuffixName) = 0), null)
			  in 
				if colDef = null then error GetError("ErrNoColumnName", {name})
				// certain grouping and aggregate change type to numeric
				else if Text.EndsWith(name, "//DM") or Text.EndsWith(name, "//MY") or Text.EndsWith(name, "//COUNT") or 
				   colDef[type] = "Checkbox" and (Text.EndsWith(name, "//SUM") or Text.EndsWith(name, "//AVG"))
				   then { name, type number, (value) => value, properName }
				// group by Y/M/D/Q/W change timestamp to date
				else if colDef[type] = "Timestamp" and (Text.EndsWith(name, "//YY") or Text.EndsWith(name, "//MM") or Text.EndsWith(name, "//DD") or Text.EndsWith(name, "//WK") or Text.EndsWith(name, "//QQ"))
				   then { name, type date, (value) => Date.FromText(Text.Start(value, 10)), properName }
				else if colDef[type] = "Timestamp" then { name, type datetimezone, DateTimeZone.FromText, properName }
				else if colDef[type] = "Numeric" then { name, type number, (value) => value, properName }
				else if colDef[type] = "Checkbox" then { name, type logical, (value) => value, properName }
				else if colDef[type] = "Date" then { name, type date, (value) => Date.FromText(Text.Start(value, 10)), properName }
				else if colDef[type] = "Time" then { name, type time, (value) => Time.FromText(Text.Middle(value, 11, 8)), properName  }
				else if colDef[type] = "Duration" then { name, type duration, (value) => if value <> null then #duration(0, 0, 0, value) else null, properName }
				else { name, type text, (value) => value, properName }));

// creates typed table and fills it with data
CreateResult = (records as list, transforms as list) as table =>
	let	
		typedEmptyTable = Table.TransformColumnTypes(
			#table(List.Transform(transforms, each _{3}), {}), 
			List.Transform(transforms, each { _{3}, _{1} }))
	,	typedTableType = Value.Type(typedEmptyTable)
	,	recordTransform = List.Transform(transforms, each { _{0}, _{2} })
	,	renameRecordFields = List.Transform(transforms, each { _{0}, _{3} })
	,	typedListOfRecords = List.Transform(records, each Record.RenameFields(Record.TransformFields(_, recordTransform), renameRecordFields))
	in
		Table.FromRecords(typedListOfRecords, typedTableType);

// check whether view type is supported
IsViewSupported = (view as record) => not List.Contains({ "SearchView", "DashboardFilter", "RecordPicker" }, view[type]);

// navigation table helper
Table.ToNavigationTable = (table as table, keyColumns as list, nameColumn as text, dataColumn as text, itemKindColumn as text, itemNameColumn as text, isLeafColumn as text) as table =>
    let
		tableType = Value.Type(table)
    ,	newTableType = Type.AddTableKey(tableType, keyColumns, true) meta [
			NavigationTable.NameColumn = nameColumn, 
			NavigationTable.DataColumn = dataColumn,
			NavigationTable.ItemKindColumn = itemKindColumn, 
			Preview.DelayColumn = itemNameColumn, 
			NavigationTable.IsLeafColumn = isLeafColumn
		]
    ,	navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;