
[Version = "2.1.1"] // https://docs.microsoft.com/en-us/power-query/handlingversioning
section IndustrialAppStore;

DefaultOptions = [
    // The built-in credential handling for OpenApi.Document only works
    // with Basic (UsernamePassword) auth. All other types should be handled
    // explicitly using the ManualCredentials option.
    //
    // In the this sample, all of the calls we'll make will work anonymously.
    // We can force anonymous access by setting ManualCredentials to true, and then
    // not setting any additional request headers/parameters.
    //
    ManualCredentials = true,
    // The returned data will match the schema defined in the swagger file. 
    // This means that additional fields and object types that don't have explicit
    // properties defined will be ignored. To see all results, we set the IncludeMoreColumns
    // option to true. Any fields found in the response that aren't found in the schema will
    // be grouped under this column in a record value.
    //
    IncludeMoreColumns = true,
    // When IncludeExtensions is set to true, vendor extensions in the swagger ("x-*" fields)
    // will be included as meta values on the function.
    //
    IncludeExtensions = true
];

ias_url = "https://appstore.intelligentplant.com";

// gestalt url
gestalt_url = ias_url & "/gestalt/";

// power platform api base url
pp_data_url = "https://powerbi.intelligentplant.com/";

// datasources path
gestalt_datasources_url = "api/data/datasources/";

// tags url
ias_tags = "api/data/tags/";

// IAS PP historical data endpoint
ias_data_historical = "api/data/history/";

// IAS historical processed data endpoint
ias_data_historical_processed = "api/data/processed/";

// IAS historical plot data endpoint
ias_data_historical_plot = "api/data/plot/";

// IAS historical raw data endpoint
ias_data_historical_raw = "api/data/raw/";

ias_data_snapshot = "api/data/snapshot/";

// Client Id;
client_id = Text.FromBinary(Extension.Contents("client_id"));

// Refresh token used in Authentication Refresh function
refresh_token = "";

// Access token URL
token_uri = ias_url & "/AuthorizationServer/OAuth/Token";

// Auth UrL
authorize_uri = ias_url & "/AuthorizationServer/OAuth/Authorize";

// log out uri
logout_uri = ias_url & "/Account/SsoEndSession";

// The URL in your app where users will be sent after authorization. See details below about redirect urls. 
// For M extensions, the redirect_uri must be "https://oauth.powerbi.com/views/oauthredirect.html".
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";

windowWidth = 720;
windowHeight = 1000;

scopes = {
    "UserInfo", // Request access to App Store user profile.
    "DataRead", // Request access to App Store Connect data; user can control which sources the application can access.
    "AccountDebit", // Request ability to bill for usage.
    "x"
};

default_no_data_found_response = "No data found, please check your parameters.";

default_no_licence_found_response = "No subscription available for this request.";

default_empty_table_header = "Industrial App Store";

default_value_display_type = "Numeric";


// start date input
default_start_date_type_input = type text meta [Documentation.Name = "Start Date", Documentation.FieldCaption = "Start Date", Documentation.SampleValues = {"*-10d, 2018-01-01T00:00Z"}, Documentation.FieldDescription="The absolute or relative query start time."];
        
// end date input
default_end_date_type_input = type text meta [Documentation.Name = "End Date",Documentation.FieldCaption = "End Date", Documentation.SampleValues = {"*-1d, 2018-02-01T00:00Z"}, Documentation.FieldDescription="The absolute or relative query end time."];
        

// Data Source Kind description
IndustrialAppStore = [
    // Test Connection Handler
    TestConnection = (dataSourcePath) => { "IndustrialAppStore.NavigationTable" },
    Authentication = [
        OAuth = [
             StartLogin = IndustrialAppStore.StartLogin,
             FinishLogin = IndustrialAppStore.FinishLogin,
             Refresh = IndustrialAppStore.Refresh
        ]
    ],
    Label = "Industrial App Store"
];

// Generates Navigation Table and fills with each datasource and a function to query each datasource
[DataSource.Kind="IndustrialAppStore", Publish="IndustrialAppStore.Publish"]
shared IndustrialAppStore.NavigationTable = () as table => 
    let 
        dataSources = IndustrialAppStore.GetDataSources(),

        // assign functions to each data source leaf
        withDataCol = Table.AddColumn(dataSources, "Data", (x) => IndustrialAppStore.DataSourceQueries(x[Name], x[UrlName], x[Type]), type function),

        cleanedTable = Table.RemoveColumns(withDataCol, "UrlName"),

        withItemKind = Table.AddColumn(cleanedTable, "ItemKind", each "Function", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Function", type text),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false, type logical), 

        navtable = Table.ToNavigationTable(withIsLeaf, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navtable;

// Data source actions/functions definitions
IndustrialAppStore.DataSourceQueries = (dsName as text, dsUrl as text, dsType as text) as table =>

     let
         BaseFunctions = #table(
            {"Name",  "Key",   "Data",  "ItemKind", "ItemName", "IsLeaf"},{
            {"Tag Search", "Tag Search", IndustrialAppStore.TagSearch(dsName, dsUrl), Table.Type, Table.Type, true},
            {"Get Snapshot", "ias_getdata_snapshot", IndustrialAppStore.GetSnapshot(dsName, dsUrl), Table.Type, Table.Type, true},
            {"Get Data", "ias_getdata_raw", IndustrialAppStore.DataSearch(dsName, dsUrl), Table.Type, Table.Type, true}
        }),

        // if data source is A&E - add additional reports
        DsFunctions = if (dsType = "aa") then
                Table.InsertRows(
                    BaseFunctions,
                    Table.RowCount(BaseFunctions), // offset parameter; insert new node at the bottom of the table
                    {
                        [Name = "Reports", Key = "AEreports", Data = AEReports(dsName, dsUrl), ItemKind = "Folder", ItemName = "Folder", IsLeaf = false]
                    }
                )
            else
                Table.InsertRows(
                    BaseFunctions,
                    Table.RowCount(BaseFunctions), // offset parameter; insert new node at the bottom of the table
                    {
                        [Name = "Get Processed", Key = "ias_getdata_processed", Data = IndustrialAppStore.GetProcessed(dsName, dsUrl), ItemKind = Table.Type, ItemName = Table.Type, IsLeaf = true],
                        [Name = "Get Plot", Key = "ias_getdata_plot", Data = IndustrialAppStore.GetPlot(dsName, dsUrl), ItemKind = Table.Type, ItemName = Table.Type, IsLeaf = true],
                        [Name = "Get Raw", Key = "ias_getdata_raw", Data = IndustrialAppStore.GetRaw(dsName, dsUrl), ItemKind = Table.Type, ItemName = Table.Type, IsLeaf = true]
                    }
                ),

        NavTable = Table.ToNavigationTable(DsFunctions, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
in
        NavTable;

// A&E data reports
AEReports = (dsName as text, dsUrl as text) as table =>

     let
         ChildTablePerDataSource = #table(
            { "Name",  "Key",   "Data",  "ItemKind", "ItemName", "IsLeaf" },{
            { "Bad Actors", "Bad Actors", IndustrialAppStore.AEbadactors(dsName, dsUrl), Table.Type, Table.Type, true },
            { "Sequence of Events", "SoE", IndustrialAppStore.SoE(dsName, dsUrl), Table.Type, Table.Type, true }
        }),
        NavTable = Table.ToNavigationTable(ChildTablePerDataSource, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
in
        NavTable;

// Get's a table of all the datasources that the user allowed power bi access to
// Returns a table with one column being the display name of each datasource, the other being the name needed for the url to query the datasource
IndustrialAppStore.GetDataSources = () as table => 
    let 
        url = gestalt_url & gestalt_datasources_url,
        sourcew = Web.Contents(url),
		source = Json.Document(sourcew),
        namedTable = if (List.IsEmpty(source) = true) then 
                        Table.FromRecords({[Name = "No datasources available.", UrlName = ""]})
                    else
                        ParseDataSources(source)
    in 
        namedTable;

// Parse a list of datasource retrieved from AppStore in IndustrialAppStore.GetDataSources method
ParseDataSources = (source) =>
    let
        listOfSources = List.Transform(source, (x) => x[Name][DisplayName]), // extract data source name
        urlList = List.Transform(source, (x) => x[Name][QualifiedName]), // extract fully qualified data source name

        dsnTypes = List.Transform(source, (x) => try x[Properties][Remote Type] otherwise x[TypeName]), // extract data source types 
        dsnTypes_parsed = List.Transform(dsnTypes, (x) => if x <> "DataCore.AlarmAnalysis.AlarmAnalysisDriver" then "process" else "aa"),

        zipped = List.Zip({listOfSources, urlList, dsnTypes_parsed}),
        tableOfSources = Table.FromRows(zipped),

        namedTable = Table.RenameColumns(tableOfSources,
            {
                { Table.ColumnNames(tableOfSources){0}, "Name" },
                { Table.ColumnNames(tableOfSources){1}, "UrlName" },
                { Table.ColumnNames(tableOfSources){2}, "Type" }
            })
    in
        namedTable;

// Bad Actore rpeort function
IndustrialAppStore.AEbadactors = (dsName as text, qDsn as text) =>
    let

        BA_GetBadActorsFunction = (asset as text,
                                    optional startDate as text, 
                                    optional endDate as text, 
                                    optional eventType as text, 
                                    optional numberOfBAs as number) =>
	        let 
                url = BA_CompileBadActorReportQuery(qDsn,
                                    asset,
                                    if startDate = null then "*-30d" else startDate,
                                    if endDate = null then "*" else endDate,
                                    if eventType = null then "ALM" else eventType,
                                    if numberOfBAs = null 
                                        then 5 
                                    else 
                                        if numberOfBAs > 99 // the query is limited at the IAS end as well but doesnt throw an error (TODO).
                                        then 99 
                                        else numberOfBAs),
                
                // make data request
                data_response = IndustrialAppStore.ProcessDataRequest(url),

                final = if data_response[IsValid]
                    then
                        IndustrialAppStore.ProcessBadActors(Record.ToTable(data_response[Content]), "Text", false) meta [Documentation.Name = "???"]
                    else
                        data_response[Content][detail] // display error
            in
	            final,
        
        // Adding all the metadata to be displayed in the navigation table

        // get available assets 
        assets = AE_GetAvailableAssets(qDsn),

        // Available assets dropdown
        Asset_control = type text meta 
        [
            Documentation.Name = "Asset",
            Documentation.FieldCaption = "Asset name",
            Documentation.FieldDescription = "Asset for which to calculate the bad actors for.",
            Documentation.AllowedValues = assets
        ],

        // Event type dropdown
        EventType_control = type text meta 
        [
            Documentation.Name = "Event type",
            Documentation.FieldCaption = "Report event type",
            Documentation.FieldDescription = "Event type for which to calculate the bad actors for.",
            Documentation.AllowedValues = { "ALM", "INT" }            
        ],

        // Page number input field
        NumberOfBadActors_control = type number meta 
        [
            Documentation.Name = "Report length", 
            Documentation.FieldCaption = "Number of bad actors", 
            Documentation.FieldDescription = "Number of bad actors in the report.",
            Documentation.SampleValues = {"5, 10, 25"}
        ],
             
        baReportFunction_type = type function(
                    asset as Asset_control,
                    optional sd as default_start_date_type_input, 
                    optional ed as default_end_date_type_input,
                    optional eventType as EventType_control, 
                    optional numberOfBAs as NumberOfBadActors_control)
                as table 
                    meta [Documentation.Name = dsName, Documentation.LongDescription = "Compiling bad actor report..."],
       
       baReportFunction_typed = Value.ReplaceType(BA_GetBadActorsFunction, baReportFunction_type) 

    in baReportFunction_typed;

// Sequence of Events report function
IndustrialAppStore.SoE = (dsName as text, qDsn as text) =>
    let

        SoE_GetSoEFunction = (asset as text,
                                    optional startDate as text, 
                                    optional endDate as text,
                                    optional filter as text,
                                    optional page as number,
                                    optional pageSize as number) =>
	        let
                pgSize = if pageSize = null then 30 else pageSize,

                // construct SoE meta tag
                soe_metaTag = Text.Format(
                                    "#[asset]/Soe/#[eventsToSkip]-#[eventsToGet].#[filter]",
                                    [
                                        asset = asset,
                                        // soe takes number of records to skip rather than page number, simple calc can remedy that
                                        eventsToSkip = if page = null then 0 else ((page - 1) * pgSize),
                                        eventsToGet = pgSize,
                                        filter = if filter = null then "" else filter
                                    ]),

                // construct url
		        url = GetHistoricalQueryUrl(qDsn, 
                                            soe_metaTag, 
                                            if startDate = null then "*-30d" else startDate,
                                            if endDate = null then "*" else endDate,
                                            "aa", "1d", null),
        
                // make data request
		        data_response = IndustrialAppStore.ProcessDataRequest(url),

                    final = if data_response[IsValid]
                        then
                            IndustrialAppStore.ProcessSOE(Record.ToTable(data_response[Content])) meta [Documentation.Name = soe_metaTag] 
                        else
                            data_response[Content][detail] // display error
                in
	                final,
        
        // Adding all the metadata to be displayed in the navigation table

        // get available assets 
        assets = AE_GetAvailableAssets(qDsn),

        // Available assets dropdown
        Asset_control = type text meta 
        [
            Documentation.Name = "Asset",
            Documentation.FieldCaption = "Asset name",
            Documentation.FieldDescription = "Asset for which to calculate the bad actors for.",
            Documentation.AllowedValues = assets
        ],

        // Tag filter input field
        Filter_control = type text meta 
        [
            Documentation.Name = "Filter", 
            Documentation.FieldCaption = "SoE filter string", 
            Documentation.SampleValues = { "tag=LI*40", "eventType=ALM", "tag=LI*&alarmIdentifier=HIHI" }, 
            Documentation.FieldDescription = "Sequence of events filter."
        ],

        // Page number input field
        PageNumber_control = type number meta 
        [
            Documentation.Name = "Page Number", 
            Documentation.FieldCaption = "Page Number", 
            Documentation.SampleValues = {"1, 2"},
            Documentation.FieldDescription = "Resulting set page number."
        ],

        // Page size input field
        PageSize_control = type number meta 
        [
            Documentation.Name = "Page Size",
            Documentation.FieldCaption = "Page Size",
            Documentation.SampleValues = {"1, 25, 50"},
            Documentation.FieldDescription = "Number of events per page.",
            Documentation.LongDescription = "Number of events to display per page."
        ],
             
        soeReportFunction_type = type function(
                    asset as Asset_control,
                    optional sd as default_start_date_type_input, 
                    optional ed as default_end_date_type_input,
                    optional filter as Filter_control,
                    optional page as PageNumber_control,
                    optional pageSize as PageSize_control)
                as table 
                    meta [Documentation.Name = dsName, Documentation.LongDescription = "Getting SoE report..."],
       
       baReportFunction_typed = Value.ReplaceType(SoE_GetSoEFunction, soeReportFunction_type) 

    in baReportFunction_typed;

// Tag Search function
IndustrialAppStore.TagSearch = (dsName as text, dsUrl as text) =>
    let 
        myfunction = (optional tagName as text, optional pageSize as text, optional pageNumber as text) =>
	        let 
                url = GetTagSearchUrl(dsName, 
                                        dsUrl,
                                        if tagName = null then "*" else tagName, 
                                        if pageSize = null then "25" else pageSize, 
                                        if pageNumber = null then "1" else pageNumber), 
        
		        sourcew = Web.Contents(url),
		        source = Json.Document(sourcew),

		        outerTable = Table.FromRecords(source),

                final = if Table.IsEmpty(outerTable)
                            then // message if no tags were found
                                Table.FromRows({{Text.Combine({"No tags found matching query filter '", tagName, "'"})}}, {"Industrial App Store"})
                            else 
                                IndustrialAppStore.ProcessTagTable(outerTable) meta [Documentation.Name = tagName]
            in
	            final,
        
        // Adding all the metadata to be displayed in the navigation table

        // Tag filter input field
        TagNameType = type text meta 
        [
            Documentation.Name = "Tag Name", 
            Documentation.FieldCaption = "Tag Name", 
            Documentation.SampleValues = {"*, Fl*w, Pump*", "Sinusoid", "LIC*"}, 
            Documentation.FieldDescription = "The tag name filter."
        ],

        // Page size input field
        SizeType = type text meta 
        [
            Documentation.Name = "Page Size",
            Documentation.FieldCaption = "Page Size",
            Documentation.SampleValues = {"1, 25, 50"},
            Documentation.FieldDescription = "Number of tags per page.",
            Documentation.LongDescription = "Number of tags to display per page."
        ],

        // Page number input field
        PageType = type text meta 
        [
            Documentation.Name = "Page Number", 
            Documentation.FieldCaption = "Page Number", 
            Documentation.SampleValues = {"1, 2"},
            Documentation.FieldDescription = "Resulting set page number."
        ],
        
        myFunctionsType = type function(optional tagName as TagNameType, optional pageSize as SizeType, optional pageNumber as PageType) as table meta [Documentation.Name = dsName, Documentation.LongDescription = "Searching " & dsName & " For Specified Tags"],
        myTypedFunction = Value.ReplaceType(myfunction, myFunctionsType) 

    in myTypedFunction;

// Snapshot query function
IndustrialAppStore.GetSnapshot = (dsName as text, dsUrl as text) =>
    let 
        myfunction = (tags as text, optional display as text) =>
	        let 
                _display = if (display <> null) then display else default_value_display_type,

                urltags = tags,

		        url = GetSnapshotValuesUrl(dsUrl, urltags),
        
		        sourcew = Web.Contents(url),

		        // make data request
                data_response = IndustrialAppStore.ProcessDataRequest(url),

                final = if data_response[IsValid]
                    then
                        IndustrialAppStore.ProcessSnapshotResponse(Record.ToTable(data_response[Content]), _display) meta [Documentation.Name = tags]
                    else
                        data_response[Content][detail] // display error
            in
	            final,
        
        // Adding all the metadata to be displayed in the navigation table
        TagNameType = type text meta [Documentation.Name = "Tag Name", Documentation.FieldCaption = "Tag Name(s)", Documentation.SampleValues = {"Sinusoid, LIC044"}, Documentation.FieldDescription="Tag name(s) to get data for."],
        DisplayType = type text meta [Documentation.Name = "Display",Documentation.FieldCaption = "Display", Documentation.AllowedValues = {"Numeric", "Text", "Both"}, Documentation.FieldDescription="The value type to be displayed."],

        myFunctionsType = type function(tags as TagNameType, optional display as DisplayType) as table meta [Documentation.Name = dsName, Documentation.LongDescription = "Searching " & dsName & " For Specified Tags"],
        myTypedFunction = Value.ReplaceType(myfunction, myFunctionsType) 

    in myTypedFunction;

// Historical query function (Get Historical)
IndustrialAppStore.DataSearch = (dsName as text, dsUrl as text) =>
    let 
        // Adding all the metadata to be displayed in the navigation table

        // Tag name input
        TagNameType = type text meta 
        [
            Documentation.Name = "Tag Name", 
            Documentation.FieldCaption = "Tag Name(s)", 
            Documentation.SampleValues = {"Sinusoid, LIC044"}, 
            Documentation.FieldDescription="Tag name(s) to get data for.",
            Formatting.IsMultiLine = true,
            Formatting.IsCode = true
        ],

        // function type dropdown
        FunctionType = type text meta 
        [
            Documentation.Name = "Function",
            Documentation.FieldCaption = "Function", 
            Documentation.AllowedValues = {"Interp", "Max", "Min", "Avg", "Raw", "Plot"}, 
            Documentation.FieldDescription = "The data function to use."
        ],

        // interval input field
        IntervalType = type text meta [Documentation.Name = "Interval",Documentation.FieldCaption = "Interval", Documentation.SampleValues = {"20s, 3h, 1d"}],
        
        // number of points input field
        NumberOfPointsType = type number meta [Documentation.Name = "Points",Documentation.FieldCaption = "Number of points", Documentation.SampleValues = {"10, 150"}],
        
        // display type dropdown
        DisplayType = type text meta 
        [
            Documentation.Name = "Display",
            Documentation.FieldCaption = "Display", 
            Documentation.AllowedValues = {"Numeric", "Text"}, 
            Documentation.FieldDescription = "The value type to be displayed.",
            Documentation.LongDescription = "The value type to be displayed."
        ],

        getData_type = type function(tags as TagNameType, 
            sd as default_start_date_type_input, 
            ed as default_end_date_type_input, 
            function as FunctionType, 
            interval as IntervalType, 
            optional numberOfPoints as NumberOfPointsType, 
            optional display as DisplayType) 
        as table meta [Documentation.Name = dsName, Documentation.LongDescription = "Getting historical data..."],
        
        getData_typed = Value.ReplaceType(PerformDataSearch_function(dsUrl), getData_type) 

    in getData_typed;

// Historical processed query function.
IndustrialAppStore.GetProcessed = (dsDisplayName as text, dsQualifiedName as text) =>
    let 
        processQueryFunction = (tags as text, startDate as text, endDate as text, function as text, interval as text, optional display as text) =>
	        let 
                _display = if (display <> null) then display else default_value_display_type,

                urltags = tags,

                // construct data query
		        url = GetHistoricalProcessedQueryUrl(dsQualifiedName, urltags, startDate, endDate, function, interval),
                
                // make data request
                data_response = IndustrialAppStore.ProcessDataRequest(url),

                final = if data_response[IsValid]
                    then
                        IndustrialAppStore.ProcessNormal(Record.ToTable(data_response[Content]), _display) meta [Documentation.Name = tags]
                    else
                        data_response[Content][detail] // display error
            in
	            final,
        
        // Adding all the metadata to be displayed in the navigation table

        // Tag name input
        TagNameType = type text meta 
        [
            Documentation.Name = "Tag Name", 
            Documentation.FieldCaption = "Tag Name(s)", 
            Documentation.SampleValues = {"Sinusoid, LIC044"}, 
            Documentation.FieldDescription="Tag name(s) to get data for.",
            Formatting.IsMultiLine = true,
            Formatting.IsCode = true
        ],

        // function type dropdown
        FunctionType = type text meta 
        [
            Documentation.Name = "Function",
            Documentation.FieldCaption = "Function", 
            Documentation.AllowedValues = {"Interp", "Max", "Min", "Avg"}, 
            Documentation.FieldDescription = "The data function to use."
        ],

        // interval input field
        IntervalType = type text meta [Documentation.Name = "Interval",Documentation.FieldCaption = "Interval", Documentation.SampleValues = {"20s, 3h, 1d"}],
        
        // display type dropdown
        DisplayType = type text meta 
        [
            Documentation.Name = "Display",
            Documentation.FieldCaption = "Display", 
            Documentation.AllowedValues = {"Numeric", "Text"}, 
            Documentation.FieldDescription = "The value type to be displayed.",
            Documentation.LongDescription = "The value type to be displayed."
        ],

        myFunctionsType = type function(tags as TagNameType, 
            sd as default_start_date_type_input, 
            ed as default_end_date_type_input, 
            function as FunctionType, 
            interval as IntervalType, 
            optional display as DisplayType) 
        as table meta [Documentation.Name = dsDisplayName, Documentation.LongDescription = "Getting processed data..."],
       
       
        myTypedFunction = Value.ReplaceType(processQueryFunction, myFunctionsType) 

    in myTypedFunction;

// Historical plot query function
IndustrialAppStore.GetPlot = (dsName as text, dsUrl as text) =>
    let 
        plotQueryFunction = (tags as text, startDate as text, endDate as text, intervals as number, optional display as text) =>
	        let 
                _display = if (display <> null) then display else default_value_display_type,

                urltags = tags,

		        url = GetHistoricalPlotQueryUrl(dsUrl, urltags, startDate, endDate, intervals),
        
                // make data request
                data_response = IndustrialAppStore.ProcessDataRequest(url),

                final = if data_response[IsValid]
                    then
                        IndustrialAppStore.ProcessNormal(Record.ToTable(data_response[Content]), _display) meta [Documentation.Name = tags]
                    else
                        data_response[Content][detail] // display error
            in
	            final,
        
        // Adding all the metadata to be displayed in the navigation table

        // Tag name input
        TagNameType = type text meta 
        [
            Documentation.Name = "Tag Name", 
            Documentation.FieldCaption = "Tag Name(s)", 
            Documentation.SampleValues = {"Sinusoid, LIC044"}, 
            Documentation.FieldDescription="Tag name(s) to get data for.",
            Formatting.IsMultiLine = true,
            Formatting.IsCode = true
        ],

        // interval input field
        IntervalsType = type number meta [Documentation.Name = "Intervals",Documentation.FieldCaption = "Intervals", Documentation.SampleValues = {"1, 10, 22"}, Documentation.FieldDescription= "The number of intervals to use for the PLOT request."],
        
        // display type dropdown
        DisplayType = type text meta 
        [
            Documentation.Name = "Display",
            Documentation.FieldCaption = "Display", 
            Documentation.AllowedValues = {"Numeric", "Text"}, 
            Documentation.FieldDescription = "The value type to be displayed.",
            Documentation.LongDescription = "The value type to be displayed."
        ],

        myFunctionsType = type function(tags as TagNameType, 
            sd as default_start_date_type_input, 
            ed as default_end_date_type_input, 
            intervals as IntervalsType, 
            optional display as DisplayType) 
        as table meta [Documentation.Name = dsName, Documentation.LongDescription = "Getting plot data..."],
        
        myTypedFunction = Value.ReplaceType(plotQueryFunction, myFunctionsType) 

    in myTypedFunction;

// Historical raw query function
IndustrialAppStore.GetRaw = (dsName as text, dsUrl as text) =>
    let 
        rawQueryFunction = (tags as text, startDate as text, endDate as text, points as number, optional display as text) =>
	        let 
                _display = if (display <> null) then display else default_value_display_type,

                urltags = tags,

		        url = GetHistoricalRawQueryUrl(dsUrl, urltags, startDate, endDate, points),
        
		        // make data request
                data_response = IndustrialAppStore.ProcessDataRequest(url),

                final = if data_response[IsValid]
                    then
                        IndustrialAppStore.ProcessNormal(Record.ToTable(data_response[Content]), _display) meta [Documentation.Name = tags]
                    else
                        data_response[Content][detail] // display error
            in
	            final,
        
        // Adding all the metadata to be displayed in the navigation table

        // Tag name input
        TagNameType = type text meta 
        [
            Documentation.Name = "Tag Name", 
            Documentation.FieldCaption = "Tag Name(s)", 
            Documentation.SampleValues = {"Sinusoid, LIC044"}, 
            Documentation.FieldDescription="Tag name(s) to get data for.",
            Formatting.IsMultiLine = true,
            Formatting.IsCode = true
        ],

        // points input field
        PointsType = type number meta [Documentation.Name = "Points",Documentation.FieldCaption = "Points", Documentation.SampleValues = {"1, 10, 22"}, Documentation.FieldDescription= "The number of points to use for the RAW data request."],
        
        // display type dropdown
        DisplayType = type text meta 
        [
            Documentation.Name = "Display",
            Documentation.FieldCaption = "Display", 
            Documentation.AllowedValues = {"Numeric", "Text"}, 
            Documentation.FieldDescription = "The value type to be displayed.",
            Documentation.LongDescription = "The value type to be displayed."
        ],

        myFunctionsType = type function(tags as TagNameType, 
            sd as default_start_date_type_input, 
            ed as default_end_date_type_input, 
            points as PointsType, 
            optional display as DisplayType) 
        as table meta [Documentation.Name = dsName, Documentation.LongDescription = "Getting raw data..."],
        
        myTypedFunction = Value.ReplaceType(rawQueryFunction, myFunctionsType) 

    in myTypedFunction;

// Process bad actor reports
IndustrialAppStore.ProcessBadActors = (outerTable as table, display as text, optional includeTtimestamp as logical) => 
    let
        expandedTags = Table.ExpandRecordColumn(outerTable, "Value", {"TagName", "DisplayType", "Values"}, {"TagName", "DisplayType", "Values"}), // gets a row in table for each of the tags
        columns = Table.ToColumns(expandedTags),  // each col is a list 

        // check if any bad actors returned for the period requested
        jointRem = if(List.IsEmpty(columns{3}{0}))
                then "No bad actors found matching specified filters." //EmptyDataResponseToTable([], "No bad actors found")
                else ProcessNormal_inner(outerTable, "Text", includeTtimestamp)
    in
        jointRem;

// Turns normal tags into desired table
IndustrialAppStore.ProcessNormal = (outerTable as table, display as text, optional includeTtimestamp as logical) => 
    let 
        processedTable = ProcessNormal_inner(outerTable, display, includeTtimestamp)
//         expandedTags = Table.ExpandRecordColumn(outerTable, "Value", {"TagName", "DisplayType", "Values"}, {"TagName", "DisplayType", "Values"}), // gets a row in table for each of the tags
//         
//         columns = Table.ToColumns(expandedTags),  // each col is a list 
// 
//         jointRem = if true 
//             then ProcessNormal_inner(outerTable, display, includeTtimestamp)
//             else Table.FromRows({{ "hello?" }}, { default_empty_table_header })
        //jointRem = Table.FromRows({{ "hello?" }}, { default_empty_table_header })
        // list of lists of all the numeric values for each tag
//         valuesList = List.Transform(columns{3}, 
//             (x) =>
//                 if (x{0}[IsNumeric] and display = "Numeric") then List.Transform(x, (y as record) => y[NumericValue]) // if its numeric and numeric value requested
//                 else List.Transform(x, (y as record) => y[TextValue])), // else use text value
// 
//         tagNames = outerTable[Name] as list, // List of all the tags returned from the query
// 
//         valuesTable = Table.FromColumns(valuesList), // creates table with all the tags values, without correct column names
//         valuesTableNamed = Table.RenameColumns(valuesTable, List.Zip({Table.ColumnNames(valuesTable), tagNames})), // adds correct column names       
// 
//         valuesTableTyped = Table.TransformColumnTypes(valuesTableNamed, 
//             List.Transform(Table.ColumnNames(valuesTableNamed), 
//                 (x) => 
//                     if (display = "Numeric" and (columns{3}{List.PositionOf(Table.ColumnNames(valuesTableNamed), x)}){0}[IsNumeric]) 
//                     then {x, type number} 
//                     else {x, type text} )), // sets the type of the column based on the IsNumeric field
// 
//         datesList = List.Transform(columns{3}{0}, (x) => (x[UtcSampleTime])), // list of all the timestamps of all the values
//         datesTable = Table.RenameColumns(Table.SelectColumns(Table.FromList(datesList), {"Column1"}), {"Column1", "Sample Time"}), // Table of all the dates with the correct name
//         datesTableTyped = Table.TransformColumnTypes(datesTable, {"Sample Time", type datetime}), // sets the type of the datetime column
//             
//         valuesWIndex = Table.AddIndexColumn(valuesTableTyped, "joiner"), // adding indexed column to join the tables using
//         datesWIndex = Table.AddIndexColumn(datesTableTyped, "joiner"), // adding indexed column to join the tables using        
// 
//         joint = if includeTtimestamp = null or includeTtimestamp = true then
//                     Table.Join(datesWIndex, "joiner", valuesWIndex, "joiner") // joining tables
//                else
//                     valuesWIndex,
// 
//         jointRem = Table.RemoveColumns(joint, "joiner") // removing joiner column
    in
        processedTable;

ProcessNormal_inner = (outerTable as table, display as text, optional includeTtimestamp as logical) => 
    let
        expandedTags = Table.ExpandRecordColumn(outerTable, "Value", {"TagName", "DisplayType", "Values"}, {"TagName", "DisplayType", "Values"}), // gets a row in table for each of the tags

        columns = Table.ToColumns(expandedTags),  // each col is a list 

        // list of lists of all the numeric values for each tag
        valuesList = List.Transform(columns{3}, 
            (x) =>
                if (x{0}[IsNumeric] and display = "Numeric") then List.Transform(x, (y as record) => y[NumericValue]) // if its numeric and numeric value requested
                else List.Transform(x, (y as record) => y[TextValue])), // else use text value

        tagNames = outerTable[Name] as list, // List of all the tags returned from the query

        valuesTable = Table.FromColumns(valuesList), // creates table with all the tags values, without correct column names
        valuesTableNamed = Table.RenameColumns(valuesTable, List.Zip({Table.ColumnNames(valuesTable), tagNames})), // adds correct column names       

        valuesTableTyped = Table.TransformColumnTypes(valuesTableNamed, 
            List.Transform(Table.ColumnNames(valuesTableNamed), 
                (x) => 
                    if (display = "Numeric" and (columns{3}{List.PositionOf(Table.ColumnNames(valuesTableNamed), x)}){0}[IsNumeric]) 
                    then {x, type number} 
                    else {x, type text} )), // sets the type of the column based on the IsNumeric field

        datesList = List.Transform(columns{3}{0}, (x) => (x[UtcSampleTime])), // list of all the timestamps of all the values
        datesTable = Table.RenameColumns(Table.SelectColumns(Table.FromList(datesList), {"Column1"}), {"Column1", "Sample Time"}), // Table of all the dates with the correct name
        datesTableTyped = Table.TransformColumnTypes(datesTable, {"Sample Time", type datetime}), // sets the type of the datetime column
            
        valuesWIndex = Table.AddIndexColumn(valuesTableTyped, "joiner"), // adding indexed column to join the tables using
        datesWIndex = Table.AddIndexColumn(datesTableTyped, "joiner"), // adding indexed column to join the tables using        

        joint = if includeTtimestamp = null or includeTtimestamp = true then
                    Table.Join(datesWIndex, "joiner", valuesWIndex, "joiner") // joining tables
               else
                    valuesWIndex,

        jointRem = Table.RemoveColumns(joint, "joiner") // removing joiner column
    in
        jointRem;

// Process snapshot query response into a table
IndustrialAppStore.ProcessSnapshotResponse = (outerTable as table, display as text) => 
    let 
		//Retrieve just the tag values
		Value = outerTable{0}[Value],

		//Conver to a table
		newTable = Record.ToTable(Value),

		//Expand each record to display the properties
		expanded = Table.ExpandRecordColumn(newTable, "Value", {"UtcSampleTime","TextValue", "NumericValue"}),

		//Rename the sample time column
		#"Renamed Columns" = Table.RenameColumns(expanded,{{"UtcSampleTime", "Sample Time"}}),

		//Set it to a date time
		#"Changed Type" = Table.TransformColumnTypes(#"Renamed Columns",{{"Sample Time", type datetime}}),
    
		//Rename the tag column
		#"Renamed Columns1" = Table.RenameColumns(#"Changed Type",{{"Name", "Tag"}}),

		//Set what to display based on user option
		checkText = if display <> "Text" and display <> "Both" then Table.RemoveColumns(#"Changed Type", "TextValue") else Table.RenameColumns(#"Changed Type", {{"TextValue", "Text Value"}}),
		checkNumeric = if display <> "Numeric" and display <> "Both" then Table.RemoveColumns(checkText, "NumericValue") else Table.RenameColumns(checkText, {{"NumericValue", "Numeric Value"}})

    in
        checkNumeric;

// Extracts and displays all data in an SOE tag (Will only work when parsing 1 SOE tag at a time)
IndustrialAppStore.ProcessSOE = (outerTable as table) =>
    let 
        expandedTag = Table.RemoveColumns(Table.ExpandRecordColumn(outerTable, "Value", {"Values"}, {"Values"}), "Name"), // Expands columns and gets rid of unnecessary ones
        expandedList = Table.ExpandListColumn(expandedTag, "Values"), // Have a column of all the records in the values list
        expandedTextValue = Table.ExpandRecordColumn(expandedList, "Values", {"TextValue"}, {"TextValue"}), // further expands table to get to level with target JSON doc

        // if there is only 1 report and the Unit is 0 - filters dont match any data 
        // (reason for extracting unit in the AND expression is an assumption that if the first expression fails it doesnt need to extract the unit value)
        parsed = if Table.RowCount(expandedTextValue) = 1 and Table.ExpandRecordColumn(expandedList, "Values", {"Unit"}, {"Unit"}){0}[Unit] = "0"
            then "No records matched the speficied filters."
        else
            Table.FromRecords(List.Transform(Table.ToRows(expandedTextValue), (x) => Json.Document(x{0}))) //Parsing the json and putting it into a table
    in 
        parsed;

// Turns normal tags into desired table
IndustrialAppStore.ProcessTagTable = (outerTable as table) => 
    let 
        cleanedTable = Table.RemoveColumns(outerTable, {"UnitOfMeasure", "Properties", "IsMetaTag", "DigitalStates", "Id"}),
        NavTable = Table.ToNavigationTable(cleanedTable, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

// Perform data search function
PerformDataSearch_function = (qDsn as text) as function =>
    let 
        getData_function = (tags as text, 
                            startDate as text, 
                            endDate as text, 
                            function as text, 
                            interval as text, 
                            optional numberOfPoints as number, 
                            optional display as text) =>
	        let 
                _display = if (display <> null) then display else default_value_display_type,

                // construct url
		        url = GetHistoricalQueryUrl(qDsn, 
                tags,
                startDate, 
                endDate, 
                function, 
                interval, 
                if numberOfPoints = null then 0 else numberOfPoints),
        
                // make data request
		        data_response = IndustrialAppStore.ProcessDataRequest(url),

                final = if data_response[IsValid]
                    then
                        if Text.Contains(Text.Lower(tags), "/soe/") //decides whether to parse as an SOE tag or not
                            then 
                                IndustrialAppStore.ProcessSOE(Record.ToTable(data_response[Content])) meta [Documentation.Name = tags] 
                            else 
                                IndustrialAppStore.ProcessNormal(Record.ToTable(data_response[Content]), _display) meta [Documentation.Name = tags]
                    else
                        data_response[Content][detail] // display error
            in
	            final
    in 
        getData_function;

// Data Source UI publishing description
IndustrialAppStore.Publish = [
    Beta = false,
    Category = "Online Services",
    ButtonText = { "Industrial App Store", "Industrial App Store" },
    LearnMoreUrl = "https://appstore.intelligentplant.com",
    SourceImage = IndustrialAppStore.Icons,
    SourceTypeImage = IndustrialAppStore.Icons
];

// List of Icons
IndustrialAppStore.Icons = [
    Icon16 = { Extension.Contents("IndustrialAppStore16.png"), Extension.Contents("IndustrialAppStore20.png"), Extension.Contents("IndustrialAppStore24.png"), Extension.Contents("IndustrialAppStore32.png") },
    Icon32 = { Extension.Contents("IndustrialAppStore32.png"), Extension.Contents("IndustrialAppStore40.png"), Extension.Contents("IndustrialAppStore48.png"), Extension.Contents("IndustrialAppStore64.png") }
];

//
// OAuth2 flow definition
//

// code challang emethod; using plane for now as there is no way to hash S256
codeChallangeMethod = "plain";

// Authentication LogIn procedure.
IndustrialAppStore.StartLogin = (resourceUrl, state, display) =>
    let        
        codeVerifier = CreateCodeVerifier(), // generate our code verifier
        authorizeUrl = authorize_uri & "?" & Uri.BuildQueryString([
            client_id = client_id,
            code_challenge = CreateCodeChallange(codeVerifier),
            code_challenge_method = codeChallangeMethod,
            redirect_uri = redirect_uri,
            state = state,
            scope = IndustrialAppStore.GetScopeString(scopes),
            access_type = "offline",
            response_type = "code"
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = codeVerifier
        ];

// Finishes login procedure. To use implicit flow, token is already fetched in StartLogin and just extracted from the url here.
IndustrialAppStore.FinishLogin = (context, callbackUri, state) =>
    let
        // parse the full callbackUri, and extract the Query string
        parts = Uri.Parts(callbackUri)[Query],
        // if the query string contains an "error" field, raise an error
        // otherwise call TokenMethod to exchange our code for an access_token
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    TokenMethod("authorization_code", parts[code], context)
    in
        result;
        
// AccessToken refresh handler
IndustrialAppStore.Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", refresh_token);

//
// Helper Functions
//

//checks if a value is null, and if it is, uses alternative value
Value.IfNull = (a, b) => if a <> null then a else b;

// Fire data request and return response JSON
IndustrialAppStore.ProcessDataRequest = (url as text) as record =>
    let
        // get response
        response = Web.Contents(
            url, 
            [
                ManualStatusHandling = { 400, 402 }
            ]
        ),
        response_code = Value.Metadata(response)[Response.Status], // get response code
        isValid = if response_code = 200 then true else false, // determine whether its valid
        data = [ Code = response_code, IsValid = isValid, Content = Json.Document(response) ]
//         responseCode = Value.Metadata(response)[Response.Status],
// 
//         // parse response into json
//         source_j = if responseCode = 402 // custom handling if no license
//                     then [] 
//                     else Json.Document(response)
    in
        data;

// Latest data API responses are indexed by dsn as well tag names
ParseHistoricalResponse_multidsn = (response as record, dsn as text) as table =>
    let
        outerTable = if Record.FieldCount(response) <> 0 // if null/empty is returned then its 402
                        then 
                            Record.ToTable(Table.Column(Table.FromRecords( { response } ), dsn){0})// this ugly statement is broken down below
                        else Table.FromRecords({})

//         interim_outerTable_dsn = Table.FromRecords( { response } ),
//         interim_outerTable_tag = Table.Column(interim_outerTable_dsn, dsn),
//         outerTable = Record.ToTable(interim_outerTable_tag{0}) // turns outer record to table 
    in
        outerTable;

// Original data API responses are indexed by tag only
ParseHistoricalResponse_singledsn = (response as record) as table =>
    let
        outerTable = if Record.FieldCount(response) <> 0 // if null/empty is returned then its 402
                        then Record.ToTable(response)
                        else Table.FromRecords({})
    in
        outerTable;

//Get's scope string
IndustrialAppStore.GetScopeString = (scopes as list, optional scopePrefix as text) as text =>
    let
        prefix = Value.IfNull(scopePrefix, ""),
        addPrefix = List.Transform(scopes, each prefix & _),
        asText = Text.Combine(addPrefix, " "),
        final = Text.Combine(asText, "&prompt=consent")
    in
        asText;

// Compiles empty table (with no data or no subscription message) for data response  
EmptyDataResponseToTable = (data_response as record, optional message as text) =>
    let 
        empty_table_response = if(message <> null)
            then Table.FromRows({{ message }}, { default_empty_table_header })
        else
            Table.FromRows({{ 
            (if Record.FieldCount(data_response) <> 0 
                then default_no_data_found_response 
                else default_no_licence_found_response) }}, 
            { default_empty_table_header })
    in
        empty_table_response;

//If multuple tags are entered turns them into a format understood by the datacore api
ProcessTagNames = (tags as text) =>
    let         
        tagList = Text.Split(tags, ","),
        
        final = if (List.Count(tagList) > 1) then List.Accumulate(List.Transform(tagList, (x) => "&tag=" & Text.Trim(x, " ")), "", (state, current) => state & current) else "&tag=" & tags         
    in
        final;

// Gets the url to query to get the values back
GetHistoricalQueryUrl = (dsn as text, tags as text, startDate as text, endDate as text, function as text, step as text, optional numberOfPoints as number) =>
    let
        dcValuesEndPoint = pp_data_url & ias_data_historical,
        url = dcValuesEndPoint & dsn & "?" & "function=" & function
                & ProcessTagNames(tags)
                & "&start=" & startDate
                & "&end=" & endDate,

        // number of points takes precedence over step if points are specified (remember step is a required parameter so we should always end up with one or the other)
        _url = if (numberOfPoints <> null and numberOfPoints > 0) then 
                    url & "&points=" & Number.ToText(numberOfPoints)
               else
                   url & "&step=" & step
     in 
        _url;

// Construct URL for historical processed data
GetHistoricalProcessedQueryUrl = (dsn as text, tags as text, startDate as text, endDate as text, function as text, step as text) =>
    let
        dcValuesEndPoint = pp_data_url & ias_data_historical_processed,
        url = dcValuesEndPoint & dsn & "?" & "function=" & function
                & ProcessTagNames(tags)
                & "&start=" & startDate
                & "&end=" & endDate
                & "&step=" & step
    in 
        url;

// Construct URL for historical plot data
GetHistoricalPlotQueryUrl = (dsn as text, tags as text, startDate as text, endDate as text, intervals as number) =>
    let
        dcValuesEndPoint = pp_data_url & ias_data_historical_plot,
        url = dcValuesEndPoint & dsn & "?" & "intervals=" & Number.ToText(intervals)
                & ProcessTagNames(tags)
                & "&start=" & startDate
                & "&end=" & endDate
    in 
        url;

// Construct URL for historical raw data
GetHistoricalRawQueryUrl = (dsn as text, tags as text, startDate as text, endDate as text, points as number) =>
    let
        dcValuesEndPoint = pp_data_url & ias_data_historical_raw,
        url = dcValuesEndPoint & dsn & "?" & "points=" & Number.ToText(points)
                & ProcessTagNames(tags)
                & "&start=" & startDate
                & "&end=" & endDate
    in 
        url;

//Gets the url to query to get the values back
GetSnapshotValuesUrl = (dsn as text, tags as text) =>
    let
        dcValuesEndPoint = pp_data_url & ias_data_snapshot,
        url = dcValuesEndPoint & dsn & "?nocache=false&includeProperties=false"
                & ProcessTagNames(tags)
    in url;

// Gets the url to query to get the values back
GetTagSearchUrl = (dsn as text, dsUrl as text, tagName as text, pageSize as text, pageNumber as text) =>
    let
        url = pp_data_url & ias_tags & dsUrl & "?description=*&unit=*&pageSize=" & pageSize & "&name=" & tagName & "&page=" & pageNumber
    in
        url;

// Compile bad actor report request
BA_CompileBadActorReportQuery = (qDsn as text, 
    asset as text, 
    startDate as text, 
    endDate as text,
    eventType as text, 
    numberOfBa as number) =>
    let
        // get meta tags string
        baMetaTags_string = BA_CompileMetaTags(asset, eventType, numberOfBa),
        url = GetHistoricalQueryUrl(qDsn, baMetaTags_string, startDate, endDate, "INTERP", "1d")
    in
        url;

// Create bada actor meta tag string
BA_CompileMetaTags = (asset as text, eventType as text, numberOfBa as number) =>
    let
        baAttributes = { "tag", "alarmIdentifier", "tagDescription", "count" }, // base meta tag attributes
        // create a list of meta tags, general format 'Oil Co/Osprey/ALM BA report/10.tag-a'
        baMetaTags = List.Transform(baAttributes, each Text.Format("#{0}/#{1} BA report/#{2}.#{3}-a", { asset, eventType, Number.ToText(numberOfBa), _ })),
        baMetaTags_string = Text.Combine(baMetaTags, ",")
    in
        baMetaTags_string;

AE_GetAvailableAssets = (qDsn as text) => 
    let
        assets_metaTag = "*/AA config/CompanyAssets.all",

        getData = PerformDataSearch_function(qDsn),
        asset_response = getData(assets_metaTag, "*-30d", "*", "aa", "1d", null, "Text"),
        assets = Table.Column(asset_response, assets_metaTag) // list of available assets
    in
        assets;

// Transform Core verifier value into code challange; S256 method is not fully implemented yet
// as Power Query doesnt have an out-of-the-box solution for 256 hashing.
// More info https://tools.ietf.org/html/rfc7636 (4)
CreateCodeChallange = (codeVerifier as text) =>
    let
        RandomStringInBytes = Text.ToBinary(codeVerifier, TextEncoding.Ascii), // convert text to bytes
        EncodedString = Binary.ToText(RandomStringInBytes, BinaryEncoding.Base64), // encode them to a string
        ReplaceString1 = Text.Replace(EncodedString, "+", "-"), // as per spec; replace + with -
        ReplaceString2 = Text.Replace(EncodedString, "/", "_"), // as per spec; replace / with _
        ReplaceString3 = Text.Remove(ReplaceString2,{"="}), // as per spec
        CodeChallange = if(codeChallangeMethod = "plain")
            then
                codeVerifier
            else
                ReplaceString3
    in
        CodeChallange;

// Create code verifier string.
// More info: https://tools.ietf.org/html/rfc7636#section-4
CreateCodeVerifier = () =>
    let 
        CodeVerifier = Text.NewGuid() & Text.NewGuid()
    in
        CodeVerifier;

// Navigation Table
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

// see "Exchange code for access token: POST /oauth/token" at https://cloud.ouraring.com/docs/authentication for details
// grantType:  Maps to the "grant_type" query parameter.
// tokenField: The name of the query parameter to pass in the code.
// code:       Is the actual code (authorization_code or refresh_token) to send to the service.
TokenMethod = (grantType, code, optional codeVerifier) =>
    let
        codeVerifier = if (codeVerifier <> null) then [code_verifier = codeVerifier] else [],
        codeParameter = if (grantType = "authorization_code") then [ code = code ] else [ refresh_token = code ],
        
        queryString = codeVerifier & codeParameter & [
            grant_type = grantType,
            redirect_uri = redirect_uri,
            client_id = client_id
        ],

        tokenResponse = Web.Contents(token_uri, [
            Content = Text.ToBinary(Uri.BuildQueryString(queryString)),
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






