[Version = "1.0.0"]
section WebtrendsAnalytics;

[DataSource.Kind = "WebtrendsAnalytics", Publish = "WebtrendsAnalytics.Publish"]
shared WebtrendsAnalytics.Tables = Value.ReplaceType(WebtrendsAnalytics.TablesInternal, WebtrendsAnalytics.TablesTypes);

// Data Source Kind description
WebtrendsAnalytics = [
    Description = "Webtrends Analytics", 
    Type = "Custom", 
    MakeResourcePath = (ProfileId as text) => ProfileId, 
    ParseResourcePath = (resource) => { resource }, 
    Authentication = [UsernamePassword = []],
    TestConnection = (ProfileId) => { "WebtrendsAnalytics.Tables", ProfileId, "Report Period", "Individual" },
    Label = "Webtrends Analytics"
];

// Data Source UI publishing description
WebtrendsAnalytics.Publish = [
    Beta = true,
    ButtonText = {Extension.LoadString("FormulaTitle"), Extension.LoadString("FormulaHelp")}, 
    SourceImage = [
        Icon32 = {
            Extension.Contents("sourceTypeWebtrends_32.png"), 
            Extension.Contents("WebtrendsFeeds_40.png"), 
            Extension.Contents("WebtrendsFeeds_48.png"), 
            Extension.Contents("WebtrendsFeeds_64.png")
        }
    ], 
    SourceTypeImage = WebtrendsAnalytics.Icons
];

WebtrendsAnalytics.Icons = [
    Icon16 = {
        Extension.Contents("sourceTypeWebtrends_16.png"), 
        Extension.Contents("sourceTypeWebtrends_20.png"), 
        Extension.Contents("sourceTypeWebtrends_24.png"), 
        Extension.Contents("sourceTypeWebtrends_32.png")
    }, 
    Icon32 = {
        Extension.Contents("sourceTypeWebtrends_32.png"), 
        Extension.Contents("sourceTypeWebtrends_40.png"), 
        Extension.Contents("sourceTypeWebtrends_48.png"), 
        Extension.Contents("sourceTypeWebtrends_64.png")
    }
];

baseurl = "https://ws.webtrends.com/v3/Reporting/";

DaysFromToday = - 30;

StartDate = Date.From(DateTime.LocalNow()) + #duration(DaysFromToday, 0, 0, 0);
EndDate = Date.From(DateTime.LocalNow());

StartPeriod = "current_month-1";
EndPeriod = "current_month";

Table.ToNavigationTable = (table as table, keyColumns as list, nameColumn as text, dataColumn as text, itemKindColumn as text, itemNameColumn as text, isLeafColumn as text) as table =>
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
        navigationTable;

Extension.LoadString = Record.FieldOrDefault(#shared, "Extension.LoadString", (s) => s);

Extension.Contents = Record.FieldOrDefault(#shared, "Extension.Contents", (s) => null);

WebtrendsAnalytics.KeyMetricsInternal = (ProfileId, Period as text, reportType as text, optional startDate, optional endDate, optional startPeriod, optional endPeriod) =>
    let 
            //call the report
        start = if startDate = null and Period = "Custom Date" then Text.From(Date.Year(StartDate)) & "m" & Text.From(Date.Month(StartDate)) & "d" & Text.From(Date.Day(StartDate))
             else if Period = "Custom Date" then Text.From(Date.Year(startDate)) & "m" & Text.From(Date.Month(startDate)) & "d" & Text.From(Date.Day(startDate))
             else if startPeriod = null and Period = "Report Period" then StartPeriod 
             else startPeriod,
        end = if endDate = null and Period = "Custom Date" then Text.From(Date.Year(EndDate)) & "m" & Text.From(Date.Month(EndDate)) & "d" & Text.From(Date.Day(EndDate))
             else if Period = "Custom Date" then Text.From(Date.Year(endDate)) & "m" & Text.From(Date.Month(endDate)) & "d" & Text.From(Date.Day(endDate))
             else if endPeriod = null and Period = "Report Period" then EndPeriod 
             else endPeriod,
        reporttype = if reportType = "Summary" then "agg"
             else if reportType = "Trend" then "trend"
             else "indv",
        Report = Csv.Document(
            Web.Contents(
                baseurl & "profiles/" & Text.From(ProfileId) & "/KeyMetrics/?start_period=" & start & "&end_period=" & end & "&period_type=" & reportType & "&format=csv")),
        PromoteHeaders = Table.PromoteHeaders(Report)
    in
        PromoteHeaders;

WebtrendsAnalytics.ReportContentsInternal = (ProfileId, Period as text, reportType as text, ReportId, optional startDate, optional endDate, optional startPeriod, optional endPeriod) =>
    let 
            //call the report
        start = if startDate = null and Period = "Custom Date" then Text.From(Date.Year(StartDate)) & "m" & Text.From(Date.Month(StartDate)) & "d" & Text.From(Date.Day(StartDate))
             else if Period = "Custom Date" then Text.From(Date.Year(startDate)) & "m" & Text.From(Date.Month(startDate)) & "d" & Text.From(Date.Day(startDate))
             else if startPeriod = null and Period = "Report Period" then StartPeriod 
             else startPeriod,
        end = if endDate = null and Period = "Custom Date" then Text.From(Date.Year(EndDate)) & "m" & Text.From(Date.Month(EndDate)) & "d" & Text.From(Date.Day(EndDate))
             else if Period = "Custom Date" then Text.From(Date.Year(endDate)) & "m" & Text.From(Date.Month(endDate)) & "d" & Text.From(Date.Day(endDate))
             else if endPeriod = null and Period = "Report Period" then EndPeriod 
             else endPeriod,
        reporttype = if reportType = "Summary" then "agg"
             else if reportType = "Trend" then "trend"
             else "indv",
        Report = Csv.Document(
            Web.Contents(
                baseurl & "profiles/" & Text.From(ProfileId) & "/reports/" & ReportId & "/?totals=none&start_period=" & start & "&end_period=" & end & "&period_type=" & reporttype & "&format=csv")),
        PromoteHeaders = Table.PromoteHeaders(Report)
    in
        PromoteHeaders;

WebtrendsAnalytics.TablesInternal = (ProfileId as text, Period as text, reportType as text, optional startDate as date, optional endDate as date, optional startPeriod, optional endPeriod) =>
    let
        startdate = if startDate = null then StartDate
             else startDate,
        enddate = if endDate = null then EndDate
             else endDate,
        startperiod = if startPeriod = null then StartPeriod
             else startPeriod,
        endperiod = if endPeriod = null then EndPeriod 
             else endPeriod,
        objects = Table.PromoteHeaders(Csv.Document(Web.Contents("https://ws.webtrends.com/v3/Reporting/profiles/" & Text.From(ProfileId) & "/reports/?format=csv"),[Delimiter=",", Columns=2])),
        //Fix for bug in PowerBi Query
        fixedTypes = Value.ReplaceType(objects, type table [ID=text, Name=text]),
        //
        renamedCols = Table.RenameColumns(fixedTypes, {{"ID", "Key"}, {"Name", "Name"}}),
        withData = Table.AddColumn(
            renamedCols, 
            "Data", 
            each Table.Skip(WebtrendsAnalytics.ReportContentsInternal(ProfileId, Period, reportType, [Key], startdate, enddate, startperiod, endperiod), 1)), //NOTE: First row in each result set is summary row--Table.Skip removes it.
            //Add KeyMetrics row (only bit of data not from a Reports endpoint)
        withKeyMetrics = Table.InsertRows(
            withData, 
            0, 
            {[Key = "KeyMetrics", Name = "Key Metrics", Data = WebtrendsAnalytics.KeyMetricsInternal(ProfileId, Period, reportType, startdate, enddate, startperiod, endperiod)]}),
            //Add extra columns necessary for Nav Table
        withItemKindCol = Table.AddColumn(withKeyMetrics, "ItemKind", each "Table"),
        withItemNameCol = Table.AddColumn(withItemKindCol, "ItemName", each "Table"),
        withIsLeafCol = Table.AddColumn(withItemNameCol, "IsLeaf", each true),
        navTable = Table.ToNavigationTable(withIsLeafCol, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

WebtrendsAnalytics.TablesTypes = 
    let
        ProfileId = (type text) meta [
            Documentation.FieldCaption = Extension.LoadString("Tables.Parameter.ProfileId.FieldCaption"), 
            Documentation.SampleValues = {Extension.LoadString("Tables.Parameter.ProfileId.SampleValues")}, 
            Documentation.FieldDescription = Extension.LoadString("Tables.Parameter.ProfileId.FieldDescription")
        ],
        Period = (type text) meta [
            Documentation.FieldCaption = Extension.LoadString("KeyMetrics.Parameter.Period.FieldCaption"), 
            Documentation.FieldDescription = Extension.LoadString("KeyMetrics.Parameter.Period.FieldDescription"),
            Documentation.AllowedValues = {"Custom Date","Report Period"}
        ],
        startDate = (type date) meta [
            Documentation.FieldCaption = Extension.LoadString("Tables.Parameter.startDate.FieldCaption"), 
            Documentation.SampleValues = {Extension.LoadString("Tables.Parameter.startDate.SampleValues")}, 
            Documentation.FieldDescription = Extension.LoadString("Tables.Parameter.startDate.FieldDescription")
        ],
        endDate = (type date) meta [
            Documentation.FieldCaption = Extension.LoadString("Tables.Parameter.endDate.FieldCaption"), 
            Documentation.SampleValues = {Extension.LoadString("Tables.Parameter.endDate.SampleValues")}, 
            Documentation.FieldDescription = Extension.LoadString("Tables.Parameter.endDate.FieldDescription")
        ],
        startPeriod = (type text) meta [
            Documentation.FieldCaption = Extension.LoadString("Tables.Parameter.startPeriod.FieldCaption"), 
            Documentation.SampleValues = {Extension.LoadString("Tables.Parameter.startPeriod.SampleValues")}, 
            Documentation.FieldDescription = Extension.LoadString("Tables.Parameter.startPeriod.FieldDescription")
        ],
        endPeriod = (type text) meta [
            Documentation.FieldCaption = Extension.LoadString("Tables.Parameter.endPeriod.FieldCaption"), 
            Documentation.SampleValues = {Extension.LoadString("Tables.Parameter.endPeriod.SampleValues")},
            Documentation.FieldDescription = Extension.LoadString("Tables.Parameter.endPeriod.FieldDescription")
        ],
        reportType = (type text) meta [
            Documentation.FieldCaption = Extension.LoadString("Tables.Parameter.reportType.FieldCaption"), 
            Documentation.FieldDescription = Extension.LoadString("Tables.Parameter.reportType.FieldDescription"),
            Documentation.AllowedValues = {"Summary","Trend","Individual"}
        ],
        t = type function (ProfileId as ProfileId, Period as Period, reportType as reportType, optional startDate as startDate, optional endDate as endDate, optional startPeriod as startPeriod, optional endPeriod as endPeriod) as table
    in
        t meta [
            Documentation.Description = Extension.LoadString("Tables.Function.Description"), 
            Documentation.DisplayName = Extension.LoadString("Tables.Function.DisplayName"), 
            Documentation.Caption = Extension.LoadString("Tables.Function.Caption"), 
            Documentation.Name = Extension.LoadString("Tables.Function.Name"), 
            Documentation.LongDescription = Extension.LoadString("Tables.Function.LongDescription")
        ];