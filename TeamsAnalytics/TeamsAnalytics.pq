[Version = "1.0.6"]
section TeamsAnalytics;

// List of environments supported and FeatureSwitch that defaults to the global cloud
environments = [
    global = "global",
    gcc = "gcc"];
env = Environment.FeatureSwitch("Cloud", environments[global]);

// Azure Active Directory resource Urls for the different environments
AadResourceEnv = [
    global      = "https://tas.teams.microsoft.com",
    gcc         = "https://tas.gcc.teams.microsoft.com"
];

// Base Uri for the REST API in each environment
APIBaseUri = [
    global      = "https://teams.microsoft.com/tas/prod/",
    gcc         = "https://teams.microsoft.com/tas/gcc/"
];

// Helper function to get the resource of a specific environment
Utility.GetUrlWithEnv = (baseUrlList as record, env as text, default as text) as text =>
    let
        baseUrl = Record.FieldOrDefault(baseUrlList, env, default)
    in
        baseUrl;

AadServiceResource = Utility.GetUrlWithEnv(AadResourceEnv, env, AadResourceEnv[global]);
AadAuthorizationUri =  Uri.Combine(Environment.FeatureSwitch("AzureActiveDirectoryUri", "https://login.microsoftonline.com"), "/common/oauth2/authorize");
AadRedirectUrl = "https://preview.powerbi.com/views/oauthredirect.html";
BaseUrl = Utility.GetUrlWithEnv(APIBaseUri, env, APIBaseUri[global]);

[DataSource.Kind="TeamsAnalytics", Publish="TeamsAnalytics.Publish"]
shared TeamsAnalytics.Contents = Value.ReplaceType(Navigation, NavigationType);

Navigation = ()=> 
   let
       source = #table({"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, {
         { Extension.LoadString("UserActivityLabel"), "Teams user activity", UserAnalytics(), "Table", "Table", true },
        {Extension.LoadString("TeamsActivityLabel"), "Teams usage", CrossTeamAnalyticsPagination("") , "Table", "Table",true},
        {Extension.LoadString("TeamsSummaryActivityLabel"), "Teams usage summary", CrossTeamAnalyticsSummaryPagination(""), "Table", "Table",true}
        }),
        navTable = Table.ToNavigationTable(source, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

NavigationType = type function () as table meta [                  
        Documentation.Name = Extension.LoadString("DataSourceLabel"),
        Documentation.LongDescription = Extension.LoadString("LongDescription")
    ];
 
UserAnalytics = () =>
    let
        TableSchema= Table.TransformColumnTypes(    #table(
        UserAnalyticsSchema[FriendlyName],
        {} ),  List.Zip( {UserAnalyticsSchema[FriendlyName], UserAnalyticsSchema[DataType]} )), 
        MetricsToQuery= Text.Combine(Table.SelectRows(UserAnalyticsSchema, each [MetricFlag] = true)[OriginalFieldName], ",") ,       
        Endpoint= Uri.Combine(BaseUrl,"v2/me/summary-timeseries"),
        Request= Web.Contents( Endpoint, 
        [Query= 
            [metrics= MetricsToQuery,
            includeTimeSeries=MetricsToQuery,
            timeperiod="last-ninety-days"]
            ]
            ),
        Interpret = Json.Document(Request),
        users = Interpret[users],
        Custom1 = Table.FromRecords( { users}),
        Custom2 = Table.TransformColumns( Custom1, {"metrics", fxTARecordToTable}),
        #"Expanded metrics" = Table.ExpandTableColumn(Custom2, "metrics", {"Name", "date", "value"}, {"Name", "date", "value"}),
        #"Pivoted Column" = Table.Pivot(#"Expanded metrics", List.Distinct(#"Expanded metrics"[Name]), "Name", "value"),
        ChangeColumnTypes = Table.TransformColumnTypes(  #"Pivoted Column", List.Zip( { UserAnalyticsSchema[OriginalFieldName], UserAnalyticsSchema[DataType]} ) ), 
        #"Renamed Columns" =  Table.RenameColumns(ChangeColumnTypes, List.Zip( {UserAnalyticsSchema[OriginalFieldName], UserAnalyticsSchema[FriendlyName]} ) ),
        ReorderMyTable = Table.SelectColumns( #"Renamed Columns", UserAnalyticsSchema[FriendlyName])
    in
        try ReorderMyTable  otherwise TableSchema;

 //////// Start of queries related to CrossTeamAnalyticsSummary
 CrossTeamAnalyticsSummarySinglePage= (cursor as text) =>
    let
        Endpoint= Uri.Combine(BaseUrl, "v2/me/teams/summary-timeseries"),
        metricsRequested= Text.Combine(Table.SelectRows(CrossTeamAnalyticsSummarySchema, each [MetricFlag] = true)[OriginalFieldName], ","),
        Request= Web.Contents( Endpoint,  
                [Query= 
                    [metrics=  metricsRequested,
                    timeperiod="last-ninety-days",
                    includeTimeSeries=metricsRequested,
                    pagesize="60",
                    nextCursor=cursor] 
                    ]),
        Interpret = Json.Document(Request),
        nextPage= Interpret[paging]?[nextCursor]?,
        StartDate = Date.From( DateTime.From( Interpret[startDate] )),
        EndDate = Date.From( DateTime.From( Interpret[endDate] )),
        teams = Table.FromRecords( Interpret[teams] ),            
        RecordsToTable = Table.TransformColumns( teams, {"metrics", Record.ToTable}),
        #"Expanded metrics" = Table.ExpandTableColumn( RecordsToTable, "metrics", {"Name", "Value"}, {"Name", "Value"}),
        #"Expanded Value" = Table.ExpandRecordColumn(#"Expanded metrics", "Value", {"value"}, {"value.1"}),
        #"Pivoted Column" = Table.Pivot( #"Expanded Value", List.Distinct( #"Expanded Value"[Name]), "Name", "value.1"),
        AddStartDate = Table.AddColumn( #"Pivoted Column", "Start Date", each StartDate, Date.Type),
        AddEndDate = Table.AddColumn( AddStartDate, "End Date", each EndDate, Date.Type),
        ChangeColumnTypes = Table.TransformColumnTypes(  AddEndDate, List.Zip( { CrossTeamAnalyticsSummarySchema[OriginalFieldName], CrossTeamAnalyticsSummarySchema[DataType]} ) ), 
        #"Renamed Columns" = Table.RenameColumns(ChangeColumnTypes, List.Zip( {CrossTeamAnalyticsSummarySchema[OriginalFieldName], CrossTeamAnalyticsSummarySchema[FriendlyName]} ) ),
        ReorderMyTable = Table.SelectColumns( #"Renamed Columns", CrossTeamAnalyticsSummarySchema[FriendlyName])
    in 
        ReorderMyTable meta [ NextLink= nextPage];

CrossTeamAnalyticsSummaryPagination = (url as text) as table =>
    Table.GenerateByPageCrossTeamAnalyticsSummary((previous) => 
        let
            nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
            page = if (nextLink <> null) then CrossTeamAnalyticsSummarySinglePage(nextLink) else null
        in
            page
    );

Table.GenerateByPageCrossTeamAnalyticsSummary = (getNextPage as function) as table =>
    let        
        listOfPages = List.Generate(
            () => try getNextPage(null) otherwise null,           
            (lastPage) => lastPage <> null,     
            (lastPage) => getNextPage(lastPage) 
        ),
        tableOfPages = Table.FromList(listOfPages, Splitter.SplitByNothing(), {"Column1"}),
        firstRow = tableOfPages{0}? 
    in
        if (firstRow = null) then
           Table.TransformColumnTypes(    #table(
       CrossTeamAnalyticsSummarySchema[FriendlyName],
        {} ),  List.Zip( {CrossTeamAnalyticsSummarySchema[FriendlyName], CrossTeamAnalyticsSummarySchema[DataType]} ))
        else        
            Value.ReplaceType(
                Table.ExpandTableColumn(tableOfPages, "Column1", Table.ColumnNames(firstRow[Column1])),
                Value.Type(firstRow[Column1])
            );

//////// End of queries related to CrossTeamAnalyticsSummary

//////// Start of queries related to CrossTeamAnalytics

 CrossTeamAnalyticsSinglePage= (cursor as text) as table =>
    let
        Endpoint= Uri.Combine(BaseUrl, "v2/me/teams/summary-timeseries"),
        metricsRequested= Text.Combine(Table.SelectRows(CrossTeamAnalyticsSchema, each [MetricFlag] = true)[OriginalFieldName], ","),
        Request= Web.Contents( Endpoint,  
            [Query= 
                [metrics=  metricsRequested,
                timeperiod="last-ninety-days",
                includeTimeSeries=metricsRequested,
                pagesize="60",
                nextCursor=cursor]
                ]),
        Interpret = Json.Document(Request),
        nextPage= Interpret[paging]?[nextCursor]?,
        teams = Table.FromRecords( Interpret[teams] ),
        Custom1 = Table.TransformColumns( teams, {"metrics", fxTARecordToTable}),
        #"Expanded metrics" = Table.ExpandTableColumn(Custom1, "metrics", {"Name", "date", "value"}, {"Name", "date", "value"}),
        #"Pivoted Column" = Table.Pivot(#"Expanded metrics", List.Distinct(#"Expanded metrics"[Name]), "Name", "value"),
        ChangeColumnTypes = Table.TransformColumnTypes(  #"Pivoted Column", List.Zip( { CrossTeamAnalyticsSchema[OriginalFieldName], CrossTeamAnalyticsSchema[DataType]} ) ), 
        #"Renamed Columns" = Table.RenameColumns(ChangeColumnTypes, List.Zip( {CrossTeamAnalyticsSchema[OriginalFieldName], CrossTeamAnalyticsSchema[FriendlyName]} ) ),
        ReorderMyTable = Table.SelectColumns( #"Renamed Columns", CrossTeamAnalyticsSchema[FriendlyName])
    in 
        ReorderMyTable meta [NextLink= nextPage];

CrossTeamAnalyticsPagination = (url as text) as table =>
    Table.GenerateByPageCrossTeamAnalytics((previous) => 
        let
            nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
            page = if (nextLink <> null) then CrossTeamAnalyticsSinglePage(nextLink) else null
        in
            page
    );

Table.GenerateByPageCrossTeamAnalytics = (getNextPage as function) as table =>
    let        
        listOfPages = List.Generate(
            () => try getNextPage(null) otherwise null,           
            (lastPage) => lastPage <> null,     
            (lastPage) => getNextPage(lastPage) 
        ),
        tableOfPages = Table.FromList(listOfPages, Splitter.SplitByNothing(), {"Column1"}),
        firstRow = tableOfPages{0}? 
    in
        if (firstRow = null) then
           Table.TransformColumnTypes(    #table(
       CrossTeamAnalyticsSchema[FriendlyName],
        {} ),  List.Zip( {CrossTeamAnalyticsSchema[FriendlyName], CrossTeamAnalyticsSchema[DataType]} ))
        else        
            Value.ReplaceType(
                Table.ExpandTableColumn(tableOfPages, "Column1", Table.ColumnNames(firstRow[Column1])),
                Value.Type(firstRow[Column1])
            );

//////// End of queries related to CrossTeamAnalytics

fxTARecordToTable= (data as record) =>
    let 
        #"Converted to Table" = Record.ToTable(data),
        #"Expanded Value" = Table.ExpandRecordColumn(#"Converted to Table", "Value", {"timeSeries"}, {"timeSeries"}),
        #"Expanded timeSeries" = Table.ExpandListColumn(#"Expanded Value", "timeSeries"),
        #"Expanded timeSeries1" = Table.ExpandRecordColumn(#"Expanded timeSeries", "timeSeries", {"date", "value"}, {"date", "value"}),
        #"Changed Type" = Table.TransformColumnTypes(#"Expanded timeSeries1",{{"date", type datetime}}),
        #"Changed Type1" = Table.TransformColumnTypes(#"Changed Type",{{"date", type date}, {"value", type number}})
    in
        #"Changed Type1";


// Data Source Kind description
TeamsAnalytics = [
TestConnection = (dataSourcePath) =>  { "TeamsAnalytics.Contents"},
    Authentication = [
        Aad =  [AuthorizationUri = AadAuthorizationUri,
            Resource = AadServiceResource]            
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
TeamsAnalytics.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = TeamsAnalytics.Icons,
    SourceTypeImage = TeamsAnalytics.Icons
];

TeamsAnalytics.Icons = [
    Icon16 = { Extension.Contents("TeamsAnalytics16.png"), Extension.Contents("TeamsAnalytics20.png"), Extension.Contents("TeamsAnalytics24.png"), Extension.Contents("TeamsAnalytics32.png") },
    Icon32 = { Extension.Contents("TeamsAnalytics32.png"), Extension.Contents("TeamsAnalytics40.png"), Extension.Contents("TeamsAnalytics48.png"), Extension.Contents("TeamsAnalytics64.png") }
];

 
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



/// The following are a set of schemas for the tables that will be created through this connector

CrossTeamAnalyticsSchema =#table( {"OriginalFieldName", "FriendlyName", "DataType", "MetricFlag"},
{ {"id", "TeamId", Text.Type, false}, 
{"displayName", "Team name",Text.Type, false}, 
{"privacy", "Privacy", Text.Type, false}, 
{"date", "Date",Date.Type,false},
{"activeUsers", "Active users",Int64.Type, true}, 
{"activeChannels", "Active channels",Int64.Type, true}, 
{"postMessages", "Post Messages",Int64.Type, true}, 
{"replyMessages", "Reply messages", Int64.Type, true}, 
{"meetingsOrganized", "Meetings organized",Int64.Type, true}, 
{"urgentMessages", "Urgent messages",Int64.Type, true}, 
{"reactions", "Reactions",Int64.Type, true}, 
{"mentions", "Mentions",Int64.Type, true}, 
{"channelMessages", "Channel messages",Int64.Type, true}, 
{"guests", "Guests",Int64.Type, true}});

UserAnalyticsSchema =#table( {"OriginalFieldName", "FriendlyName", "DataType", "MetricFlag"},  
{ {"date", "Date", Date.Type, false}, 
{"id","UserId", Text.Type, false}, 
{"channelMessages", "Channel messages", Int64.Type, true}, 
{"replyMessages", "Reply messages", Int64.Type, true}, 
{"postMessages", "Post messages", Int64.Type, true}, 
{"chatMessages", "Chat messages", Int64.Type, true}, 
{"urgentMessages", "Urgent messages", Int64.Type, true}, 
{"meetingsOrganizedAdhoc", "Meetings organized adhoc", Int64.Type, true}, 
{"mOrgSchOneTime", "Meetings organized scheduled one time", Int64.Type, true}, 
{"mOrgSchRecurring", "Meetings organized scheduled recurring", Int64.Type, true}, 
{"meetingsParticipatedAdhoc", "Meetings participated adhoc",Int64.Type, true}, 
{"mPartSchOneTime", "Meetings participated scheduled one time", Int64.Type, true}, 
{"mPartSchRecurring", "Meetings participated scheduled recurring", Int64.Type, true}, 
{"oneOnOneCalls", "1:1 calls",Int64.Type, true}, 
{"audioTime", "Audio time",Int64.Type, true}, 
{"videoTime", "Video time",Int64.Type, true}, 
{"screenShareTime", "Screen sharing time", Int64.Type, true}, 
{"otherActivity", "Other activity",Int64.Type , true}} );

CrossTeamAnalyticsSummarySchema =#table( {"OriginalFieldName", "FriendlyName", "DataType", "MetricFlag"},
{ {"id", "TeamId", Text.Type, false}, 
{"displayName", "Team name",Text.Type, false}, 
{"privacy", "Privacy", Text.Type, false}, 
{"Start Date", "Start Date", Date.Type, false},
{"End Date", "End Date", Date.Type, false},
{"activeUsers", "Active users",Int64.Type, true}, 
{"activeChannels", "Active channels",Int64.Type, true}, 
{"postMessages", "Post Messages",Int64.Type, true}, 
{"replyMessages", "Reply messages", Int64.Type, true}, 
{"meetingsOrganized", "Meetings organized",Int64.Type, true}, 
{"urgentMessages", "Urgent messages",Int64.Type, true}, 
{"reactions", "Reactions",Int64.Type, true}, 
{"mentions", "Mentions",Int64.Type, true}, 
{"channelMessages", "Channel messages",Int64.Type, true}, 
{"guests", "Guests",Int64.Type, true}});
