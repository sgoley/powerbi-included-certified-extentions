[Version = "1.0.1"]
section ProductInsights;

client_id = Text.FromBinary(Extension.Contents("client_id"));
authorize_uri = "https://login.microsoftonline.com/common/oauth2/authorize";
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
token_uri = "https://login.microsoftonline.com/common/oauth2/token";
resource_uri = "cd34d57a-a3ef-48b1-b84b-9686f0f7c099";
logout_uri = "https://login.microsoftonline.com/logout.srf";

windowWidth = 1200;
windowHeight = 1000;

TestUri = "https://api.pi.dynamics.com/GraphQL";
GetProjectsQuery = [query =
  "query fetchProjects {
    tenant {
      __metadata {
        id
        type
        etag
        readonly
        creationEntry {
          timestamp
          identity {
            displayIdentifier
          }
        },
        lastModifiedEntry {
          timestamp
          identity {
            displayIdentifier
          }
        }
      }
      parent {
        __metadata {
          id
        }
      }
      name
      description
    }
  }"
  ];
GetProjectsQueryJson = Text.FromBinary(Json.FromValue(GetProjectsQuery));

commonGraphQL = 
"    __metadata {
      id
      etag
      creationEntry {
        timestamp,
        identity {
          identifier
        }
      }
      lastModifiedEntry {
        timestamp
        identity {
          identifier
        }
      }
      attributes {
        key
        value
      }
    }
    name
    description";

fetchTeams = [query = 
"query fetchGroups {
  groups: group {"
    & commonGraphQL &
  "}
}"];
fetchTeamsQueryJson = Text.FromBinary(Json.FromValue(fetchTeams));


fetchProjectsByTeamId = 
"query fetchProjectsByTeamId($teamId: String) {
  projects: tenant(where: { parent: { __metadata: { id: { eq: $teamId}}}}) {"
    & commonGraphQL &
  "}
}";

getDashboardsByProjectId = 
"query getdashboard3pList($project: String) {
  dashboard3p(tenant: $project) {"
    & commonGraphQL &  
	"}
}";

getPagesByDashboardId = 
"query listDashboardPages($dashboardId: String) {
  dashboard3p(__id: $dashboardId) {
    pageLinks {
      ...DashboardPageFields
    }
  }
}
fragment DashboardPageFields on dashboard3pPage {
  name
  __metadata {
    id
    creationEntry {
      timestamp
    }
  }
}";

getChartsByPageId = 
"query listChartsForPage($pageId: String) {
  dashboard3pPage(where: {__metadata: {id: {eq: $pageId}}}) {
    widgets{
        link {
          ... on chart {
            __metadata {
              id
            }
            name
          }
        }
      }
    }
  }";

GranularityToDurationMap = #table({"Granularity", "Duration"},
{{"PT1M", #duration(0, 0, 1, 0)},
 {"PT5M", #duration(0, 0, 5, 0)},
 {"PT1H", #duration(0, 2, 0, 0)},
 {"P1D", #duration(1, 0, 0, 0)},
 {"P1W", #duration(7, 0, 0, 0)}});


intApiUrl = "https://api.int.pi.dynamics.com";

prodApiUrl = "https://api.pi.dynamics.com";

api = prodApiUrl;

//
// Exported functions
//
// These functions are exported to the M Engine (making them visible to end users), and associates 
// them with the specified Data Source Kind. The Data Source Kind is used when determining which 
// credentials to use during evaluation. Credential matching is done based on the function's parameters. 
// All data source functions associated to the same Data Source Kind must have a matching set of required 
// function parameters, including type, name, and the order in which they appear. 

[DataSource.Kind="ProductInsights", Publish="ProductInsights.UI"]
shared ProductInsights.Contents = Value.ReplaceType(ProductInsights.NavTable, type function () as table);

[DataSource.Kind="ProductInsights"]
shared ProductInsights.QueryMetric = Value.ReplaceType(ProductInsights.QueryMetricData, type function (urlAndQuery as text) as any);

//
// Data Source definition
//
ProductInsights = [
    Description = "ProductInsights",
    Type = "Singleton",
    MakeResourcePath = () => "ProductInsights",
    ParseResourcePath = (resource) => {},
    TestConnection = (resource) => { "ProductInsights.Contents" },
    Authentication = [
         Aad = [
             AuthorizationUri = authorize_uri,
             Resource = resource_uri,
             DefaultClientApplication = [
                 ClientId = client_id,
                 ClientSecret = "",
                 CallbackUrl = "https://preview.powerbi.com/views/oauthredirect.html"
             ]     
         ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

//
// UI Export definition
//
ProductInsights.UI = [
    Beta = true,
    ButtonText = { Extension.LoadString("FormulaTitle"), Extension.LoadString("FormulaHelp") },
    SourceImage = ProductInsights.Icons,
    SourceTypeImage = ProductInsights.Icons
];

ProductInsights.Icons = [
    Icon16 = { Extension.Contents("ProductInsights16.png"), Extension.Contents("ProductInsights20.png"), Extension.Contents("ProductInsights24.png"), Extension.Contents("ProductInsights32.png") },
    Icon32 = { Extension.Contents("ProductInsights32.png"), Extension.Contents("ProductInsights40.png"), Extension.Contents("ProductInsights48.png"), Extension.Contents("ProductInsights64.png") }
];

ProductInsights.NavTable = () =>
    let
        teams = ProductInsights.MakeRequest(api & "/GraphQL", fetchTeamsQueryJson),
        teamsTable = Table.FromRecords(Record.Field(Record.Field(teams, "data"), "groups")),
        teamsIdTable = Table.AddColumn(teamsTable, "TeamId", each Record.Field([#"__metadata"], "id")),
        removeMetadata = Table.RemoveColumns(teamsIdTable, {"__metadata"}),
        projectTables = GetProjectsTablesByTeamIds(teamsIdTable[TeamId]),
        addData = Table.AddColumn(removeMetadata, "Data", each NestedProjectsTable(_[TeamId], projectTables)),
        itemKindCol = Table.AddColumn(addData, "ItemKind", each "Folder"),
        itemNameCol = Table.AddColumn(itemKindCol, "ItemName", each "Folder"),
        isLeafCol = Table.AddColumn(itemNameCol, "IsLeaf", each false),
        selectNavCols = Table.SelectColumns(isLeafCol, {"name", "Data", "ItemKind", "ItemName", "IsLeaf"}),
        keyCol = Table.AddIndexColumn(selectNavCols, "Key", 0),
        nav = Table.ToNavigationTable(keyCol, {"Key"}, "name", "Data", "ItemKind", "ItemName", "IsLeaf") 
    in
        nav;

ProductInsights.MakeRequest = (url as text, optional query as text) =>
    let 
        content = Web.Contents(ValidateUrlScheme(url),
        [
            Content = Text.ToBinary(query),
            Headers = [
                #"Content-type" = "application/json",
                #"Accept" = "application/json"
            ]
        ]),
        json = Json.Document(Text.FromBinary(content))
    in
        json;

ProductInsights.MakeGetRequest = (url as text) =>
    let 
        content = Web.Contents(ValidateUrlScheme(url),
        [
            Headers = [
                #"Content-type" = "application/json",
                #"Accept" = "application/json"
            ]
        ]),
        json = Json.Document(Text.FromBinary(content))
    in
        json;

ValidateUrlScheme = (url as text) as text => if (Uri.Parts(url)[Scheme] <> "https") then error "Url scheme must be HTTPS" else url;
     
ProductInsights.QueryMetricData = (urlAndQuery as text) =>
    let
        //TODO: will have csv support so can probably remove most of this parsing code, also a DataTable version of response which
        // may be easier to parse
        params = Json.Document(urlAndQuery),
        json = ProductInsights.MakeRequest(Record.Field(params, "url"), Text.FromBinary(Json.FromValue(Record.Field(params, "query")))),
        // if ALL granularity use the whole interval as duration - just one data point
        // default value of 5min granularity
        granularity = Record.Field(json, "granularity"),
        rows = Table.SelectRows(GranularityToDurationMap, each [Granularity] = granularity),
        StartTime = DateTime.From(List.First(Splitter.SplitTextByDelimiter("/")(json[interval]))),
        EndTime = DateTime.From(Splitter.SplitTextByDelimiter("/")(json[interval]){1}),
        wholeInterval = EndTime - StartTime,
        duration = if(Table.RowCount(rows) = 1)  then rows[#"Duration"]{0} else if(granularity = "ALL") then wholeInterval else #duration(0, 0, 5, 0),
        ListOfSeries = List.Transform(Record.Field(json, "series"), each Record.Field(_, "values")),
        SeriesDimensionTitles = List.Transform(Record.Field(json, "series"), each Text.Combine(Record.FieldValues(Record.Field(Record.Field(_, "seriesInfo"), "combination")))),
        Timestamps = try List.DateTimes(DateTime.From(StartTime), List.Count(List.First(ListOfSeries, {})), duration) otherwise error "Error reaching Metrics API",
        TimestampsList = List.Generate(() =>1, each _ > 0, each _ - 1, each Timestamps),
        TitlesList = List.InsertRange(SeriesDimensionTitles, 0, {"Time"}),
        ListOfSeriesCombined = List.InsertRange(ListOfSeries, 0, TimestampsList),
        TitlesListTypes = List.Combine({ {"Time", DateTime.Type }, List.Transform(List.Skip(TitlesList, 1), each {_, Double.Type } )}),
        SeriesWithTimestampTable = Table.FromColumns(ListOfSeriesCombined, TitlesList),
        SeriesWithTimestampTableType = Table.TransformColumnTypes(SeriesWithTimestampTable, TitlesListTypes),
        //unpivot the table
        ColNames = Table.ColumnNames(SeriesWithTimestampTableType),
        ColNamesWithoutTimeCol = List.LastN(ColNames, List.Count(ColNames) - 1),
        // get dimension name and operation name
        firstSeries = List.First(Record.Field(json, "series")),
        operationName = Record.Field(Record.Field(Record.Field(firstSeries, "seriesInfo"), "operation"), "name"),
        dimensionName = List.First(Record.FieldNames(Record.Field(Record.Field(firstSeries, "seriesInfo"), "combination"))),
        // don't unpivot if just a single series
        unpivoted = if (dimensionName = null) then SeriesWithTimestampTableType else Table.Unpivot(SeriesWithTimestampTableType, ColNamesWithoutTimeCol, dimensionName, operationName),
        //unpivoted = Table.Unpivot(SeriesWithTimestampTableType, ColNamesWithoutTimeCol, dimensionName, operationName),
        colNames = Table.ColumnNames(unpivoted),
        valColumnName = List.Last(colNames),
        typesEnforced = Table.TransformColumnTypes(unpivoted, {valColumnName, Number.Type})
    in
        typesEnforced;

NestedProjectsTable = (teamId as text, projectsTable as table) =>
    let
        projectsForThisTeam = Table.SelectRows(projectsTable, each teamId = [TeamId]),
        dataTable = Table.ExpandTableColumn(projectsForThisTeam, "Data", {"name", "description", "Data", "ProjectId"}),
        keyCol = Table.AddIndexColumn(dataTable, "Key", 0),
        itemKindCol = Table.AddColumn(keyCol, "ItemKind", each "Folder"),
        itemNameCol = Table.AddColumn(itemKindCol, "ItemName", each "Folder"),
        isLeafCol = Table.AddColumn(itemNameCol, "IsLeaf", each false),
        select = Table.SelectColumns(isLeafCol, {"ProjectId", "name", "description", "ItemKind", "ItemName", "IsLeaf", "Data", "Key"}),
        nav = Table.ToNavigationTable(select, {"Key"}, "name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        nav;

NestedDashboardsTable = (projectId as text, dashboardsTable as table) =>
    let
        dashboardsForThisProject = Table.SelectRows(dashboardsTable, each projectId = [ProjectId]),
        dataTable = Table.ExpandTableColumn(dashboardsForThisProject, "Data", {"name","description", "Data", "DashboardId"}),
        keyCol = Table.AddIndexColumn(dataTable, "Key", 0),
        itemKindCol = Table.AddColumn(keyCol, "ItemKind", each "Folder"),
        itemNameCol = Table.AddColumn(itemKindCol, "ItemName", each "Folder"),
        isLeafCol = Table.AddColumn(itemNameCol, "IsLeaf", each false),
        select = Table.SelectColumns(isLeafCol, {"DashboardId", "name", "description", "ItemKind", "ItemName", "IsLeaf", "Data", "Key"}),
        nav = Table.ToNavigationTable(select, {"Key"}, "name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        nav;

NestedPagesTable = (dashboardId as text, pagesTable as table) =>
    let
        pagesForThisDashboard = Table.SelectRows(pagesTable, each dashboardId = [DashboardId]),
        dataTable = Table.ExpandTableColumn(pagesForThisDashboard, "Data", {"name","description", "Data", "PageId"}),
        keyCol = Table.AddIndexColumn(dataTable, "Key", 0),
        itemKindCol = Table.AddColumn(keyCol, "ItemKind", each "Folder"),
        itemNameCol = Table.AddColumn(itemKindCol, "ItemName", each "Folder"),
        isLeafCol = Table.AddColumn(itemNameCol, "IsLeaf", each false),
        select = Table.SelectColumns(isLeafCol, {"PageId", "name", "description", "ItemKind", "ItemName", "IsLeaf", "Data", "Key"}),
        nav = Table.ToNavigationTable(select, {"Key"}, "name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        nav;

NestedChartsTable = (pageId as text, chartsTable as table) =>
    let
        chartsForThisPage = Table.SelectRows(chartsTable, each pageId = [PageId]),
        dataTable = Table.ExpandTableColumn(chartsForThisPage, "Data", {"ChartName","description", "Data", "ChartId"}),
        keyCol = Table.AddIndexColumn(dataTable, "Key", 0),
        itemKindCol = Table.AddColumn(keyCol, "ItemKind", each "Folder"),
        itemNameCol = Table.AddColumn(itemKindCol, "ItemName", each "Folder"),
        isLeafCol = Table.AddColumn(itemNameCol, "IsLeaf", each false),
        select = Table.SelectColumns(isLeafCol, {"ChartId", "ChartName", "description", "ItemKind", "ItemName", "IsLeaf", "Data", "Key"}),
        nav = Table.ToNavigationTable(select, {"Key"}, "ChartName", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        nav;

NestedMetricTable = (chartId as text, metricsTable as table) =>
    let
        metricForThisChart = Table.SelectRows(metricsTable, each chartId = [ChartId]),
        keyCol = Table.AddIndexColumn(metricForThisChart, "Key", 0),
        itemKindCol = Table.AddColumn(keyCol, "ItemKind", each "Table"),
        itemNameCol = Table.AddColumn(itemKindCol, "ItemName", each "Table"),
        isLeafCol = Table.AddColumn(itemNameCol, "IsLeaf", each true),
        select = Table.SelectColumns(isLeafCol, {"ChartId", "ChartName", "ItemKind", "ItemName", "IsLeaf", "Data", "Key"}),
        nav = Table.ToNavigationTable(select, {"Key"}, "ChartName", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        nav;

GetProjectsTablesByTeamIds = (teamIds as list) =>
    let
        teams = Table.FromList(teamIds, null, {"TeamId"}),
        teamsWithProjects = Table.AddColumn(teams, "Data", each GetProjectsTableByTeamId([TeamId]))
    in
        teamsWithProjects;

GetProjectsTableByTeamId = (teamId as text) as table =>
    let
        query = BuildFetchProjectsByTeamIdGraphQLQueryJson(teamId),
        json = ProductInsights.MakeRequest(api & "/GraphQL", query),
        projectList = Record.Field(Record.Field(json, "data"), "projects"),
        projectsTable = if (List.Count(projectList) = 0) then error("no projects in this team") else Table.FromRecords(projectList),
        projectIdsTable = Table.AddColumn(projectsTable, "ProjectId", each Record.Field([#"__metadata"], "id")),
        dashboardTables = GetDashboardsByProjectIds(projectIdsTable[ProjectId]),
        addData = Table.AddColumn(projectIdsTable, "Data", each NestedDashboardsTable(_[ProjectId], dashboardTables), type table)
    in
        addData;

GetDashboardsByProjectIds = (projectIds as list) =>
    let
        projects = Table.FromList(projectIds, null, {"ProjectId"}),
        projectsWithDashboards = Table.AddColumn(projects, "Data", each GetDashboardsTableByProjectId([ProjectId]))
    in
        projectsWithDashboards;

GetDashboardsTableByProjectId = (projectId as text) =>
    let
        query = BuildDashboardsByProjectIdGraphQLQueryJson(projectId),
        json = ProductInsights.MakeRequest(api & "/GraphQL", query),
        dashboardList = Record.Field(Record.Field(json, "data"), "dashboard3p"),
        dashboardsTable = if (List.Count(dashboardList) = 0) then error("no dashboards in this project") else Table.FromRecords(dashboardList),
        dashboardIdsTable = Table.AddColumn(dashboardsTable, "DashboardId", each Record.Field([#"__metadata"], "id")),
        pagesTables = GetPagesByDashboardIds(dashboardIdsTable[DashboardId]),
        addData = Table.AddColumn(dashboardIdsTable, "Data", each NestedPagesTable(_[DashboardId], pagesTables), type table)
    in
        addData;

GetPagesByDashboardIds = (dashboardIds as list) =>
    let
        dashboards = Table.FromList(dashboardIds, null, {"DashboardId"}),
        dashboardsWithPages = Table.AddColumn(dashboards, "Data", each GetPagesTableByDashboardId([DashboardId]))
    in
        dashboardsWithPages;

GetPagesTableByDashboardId = (dashboardId as text) =>
    let
        query = BuildPagesByDashboardIdGraphQLQueryJson(dashboardId),
        json = ProductInsights.MakeRequest(api & "/GraphQL", query),
        pagesList = Record.Field(Record.Field(Record.Field(json, "data"), "dashboard3p"){0}, "pageLinks"),
        // there should always be a default page if there's a dashboard - don't need no pages check here
        pagesTable = Table.FromRecords(pagesList),
        pageIdsTable = Table.AddColumn(pagesTable, "PageId", each Record.Field([#"__metadata"], "id")),
        chartsTable = GetChartsByPageIds(pageIdsTable[PageId]),
        addData = Table.AddColumn(pageIdsTable, "Data", each NestedChartsTable(_[PageId], chartsTable), type table)
    in
        addData;

GetChartsByPageIds = (pageIds as list) =>
    let
        pages = Table.FromList(pageIds, null, {"PageId"}),
        pagesWithCharts = Table.AddColumn(pages, "Data", each GetChartsTableByPageId([PageId]))
    in
        pagesWithCharts;

GetChartsTableByPageId = (pageId as text) =>
    let 
        query = BuildChartsByPageIdGraphQLQueryJson(pageId),
        json = ProductInsights.MakeRequest(api & "/GraphQL", query),
        chartsList = Record.Field(Record.Field(Record.Field(json, "data"), "dashboard3pPage"){0}, "widgets"),
        replacePossibleNulls = List.ReplaceValue(chartsList, null, [link = null], Replacer.ReplaceValue),
        chartsTable = if (List.Count(replacePossibleNulls) = 0) then error("No charts in this page") else Table.FromRecords(replacePossibleNulls),
        chartIdsTable = Table.AddColumn(chartsTable, "ChartId", each GetChartId(_)),
        chartNamesTable = Table.AddColumn(chartIdsTable, "ChartName", each GetChartName(_)),
        metricDataTable = GetMetricDataTablesByChartId(chartNamesTable),
        chartsWithData = Table.AddColumn(chartNamesTable, "Data", each NestedMetricTable(_[ChartId], metricDataTable), type table)
    in
        chartsWithData;

GetChartId = (rec as record) =>
    let
        id = if(Record.Field(rec, "link") <> null) then Record.Field(Record.Field(Record.Field(rec, "link"), "__metadata"), "id") else null
    in
        id;

GetChartName = (rec as record) =>
    let
        name = if(Record.Field(rec, "link") <> null) then Record.Field(Record.Field(rec, "link"), "name") else null
    in
        name;

GetMetricDataTablesByChartId = (chartTable as table) =>
    let
        chartsWithMetricData = Table.AddColumn(chartTable, "Data", each if (_[ChartId] <> null) then MetricDataTable(_[ChartId]) else "no chart found")
    in
        chartsWithMetricData;

MetricDataTable = (chartId as text) =>
    let
        // get metrics query from chart document - the structure is slightly different
        queryUrl = api & "/v1.0/document/" & chartId & "?includemetadata=true",
        json = ProductInsights.MakeGetRequest(queryUrl),
        dataModel = Record.Field(Record.Field(json, "configuration"), "dataModel"),
        query = [
            metric = Record.Field(Record.Field(dataModel, "series"){0}, "metric"),
            timeRange = Record.Field(Record.Field(dataModel, "timeConfiguration"), "timeRange"),
            granularity = Record.Field(Record.Field(dataModel, "timeConfiguration"), "granularity"),
            responseFormat = "jsonSeries",
            responseProtocol = "oneShot"
        ],
        tenantId = Record.Field(Record.Field(json, "tenant"), "targetDocumentId"),
        url = api & "/v1/tenants/" & tenantId & "/metric/inline/series",
        record = [
            url = url,
            query = query
        ],
        convertToText = Text.FromBinary(Json.FromValue(record)),
        seriesResult = ProductInsights.QueryMetricData(convertToText)
    in
        seriesResult;

BuildFetchProjectsByTeamIdGraphQLQueryJson = (teamId as text) =>
    let
        GetProjectsByTeamIdQuery = [
            query = fetchProjectsByTeamId,
            variables = [teamId = teamId]
        ],
        GetProjectsByTeamIdQueryJson = Text.FromBinary(Json.FromValue(GetProjectsByTeamIdQuery))
    in
        GetProjectsByTeamIdQueryJson;

BuildDashboardsByProjectIdGraphQLQueryJson = (projectId as text) =>
    let
        GetDashboardsByProjectIdQuery = [
            query = getDashboardsByProjectId,
            variables = [project = projectId]
        ],
        GetDashboardsByProjectIdQueryJson = Text.FromBinary(Json.FromValue(GetDashboardsByProjectIdQuery))
    in
        GetDashboardsByProjectIdQueryJson;

BuildPagesByDashboardIdGraphQLQueryJson = (dashboardId as text) =>
    let
        GetPagesByDashboardIdQuery = [
            query = getPagesByDashboardId,
            variables = [dashboardId = dashboardId]
        ],
        GetPagesByDashboardIdQueryJson = Text.FromBinary(Json.FromValue(GetPagesByDashboardIdQuery))
    in
        GetPagesByDashboardIdQueryJson;

BuildChartsByPageIdGraphQLQueryJson = (pageId as text) =>
    let
        GetChartsByPageIdQuery = [
            query = getChartsByPageId,
            variables = [pageId = pageId]
        ],
        GetChartsByPageIdQueryJson = Text.FromBinary(Json.FromValue(GetChartsByPageIdQuery))
    in
        GetChartsByPageIdQueryJson;

StartLogin = (resourceUrl, state, display) =>
    let
        authorizeUrl = authorize_uri & "?" & Uri.BuildQueryString([
            resource = resource_uri,
            client_id = client_id,  
            redirect_uri = redirect_uri,
            response_type = "code",
            prompt = "refresh_session",
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

FinishLogin = (context, callbackUri, state) =>
    let
        parts = Uri.Parts(callbackUri)[Query],
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    TokenMethod("authorization_code", parts[code])
    in
        result;

Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", refresh_token);

Logout = (token) => logout_uri;

TokenMethod = (grantType, code) =>
    let
        tokenResponse = Web.Contents(token_uri, [
            Content = Text.ToBinary(Uri.BuildQueryString([
                resource =  resource_uri,
                client_id = client_id,
                code = code,
                grant_type = grantType,
                redirect_uri = redirect_uri])),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = {400} 
        ]),
        body = Json.Document(tokenResponse),
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body)
                 else
                    body
    in
        result;

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

