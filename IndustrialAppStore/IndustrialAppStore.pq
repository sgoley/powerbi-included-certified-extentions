[Version = "1.0.3"]
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

// gestalt url
gestalt_url = "https://appstore.intelligentplant.com/gestalt/";

// datasources path
gestalt_datasources_url = "api/data/datasources/";

// tags url
gestalt_tags_url = "api/data/tags/";

// DataCore API values endpoint path
gestalt_values_path = "api/data/v2/history/";  

// Client Id;
client_id = Text.FromBinary(Extension.Contents("client_id"));

// Client secret
client_secret = Text.FromBinary(Extension.Contents("client_secret"));

// Refresh token used in Authentication Refresh function
refresh_token = "";

// Access token URL
token_uri = "https://appstore.intelligentplant.com/AuthorizationServer/OAuth/Token";

// Auth UrL
authorize_uri = "https://appstore.intelligentplant.com/AuthorizationServer/OAuth/Authorize";

// log out uri
logout_uri = "https://appstore.intelligentplant.com/Account/SsoEndSession";

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

// Data Source Kind description
IndustrialAppStore = [
    //Test Connection Handler
    TestConnection = (dataSourcePath) => { "IndustrialAppStore.NavigationTable" },
    Authentication = [
        OAuth = [
             StartLogin = IndustrialAppStore.StartLogin,
             FinishLogin = IndustrialAppStore.FinishLogin,
             Refresh = IndustrialAppStore.Refresh,
             Logout = IndustrialAppStore.Logout
        ]
    ],
    Label = "Industrial App Store"
];

// Generates Navigation Table and fills with each datasource and a function to query each datasource
[DataSource.Kind="IndustrialAppStore", Publish="IndustrialAppStore.Publish"]
shared IndustrialAppStore.NavigationTable = () as table => 
    let 
        dataSources = IndustrialAppStore.GetDataSources(),

        withDataCol = Table.AddColumn(dataSources, "Data", (x) => IndustrialAppStore.DataSourceQueries(x[Name], x[UrlName]), type function),

        cleanedTable = Table.RemoveColumns(withDataCol, "UrlName"),

        withItemKind = Table.AddColumn(cleanedTable, "ItemKind", each "Function", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Function", type text),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false, type logical), 

        navtable = Table.ToNavigationTable(withIsLeaf, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navtable;

IndustrialAppStore.DataSourceQueries = (dsName as text, dsUrl as text) as table =>

     let
         ChildTablePerDataSource = #table(
            {"Name",  "Key",   "Data",  "ItemKind", "ItemName", "IsLeaf"},{
            {"Get Data", "Get Data", IndustrialAppStore.DataSearch(dsName, dsUrl), Table.Type,    Table.Type,    true},
            {"Tag Search", "Tag Search", IndustrialAppStore.TagSearch(dsName, dsUrl), Table.Type,    Table.Type,    true}
        }),
         NavTable = Table.ToNavigationTable(ChildTablePerDataSource, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
in
        NavTable;

//Get's a table of all the datasources that the user allowed power bi access to
//Returns a table with one column being the display name of each datasource, the other being the name needed for the url to query the datasource
IndustrialAppStore.GetDataSources = () as table => 
    let 
        url = gestalt_url & gestalt_datasources_url,
        sourcew = Web.Contents(url),
		source = Json.Document(sourcew),

        namedTable = 
        if (List.IsEmpty(source) = true) then 
            Table.FromRecords({[Name = "No datasources available", UrlName = ""]})
        else
            IndustrialAppStore.ParseDataSources(source)
    in 
        namedTable;

// Parse a list of datasource retrieved from AppStore in IndustrialAppStore.GetDataSources method
IndustrialAppStore.ParseDataSources = (source) =>
    let
        listOfSources = List.Transform(source, (x) => x[Name][DisplayName]),
        urlList = List.Transform(source, (x) => x[Name][QualifiedName]),
        zipped = List.Zip({listOfSources, urlList}),
        tableOfSources = Table.FromRows(zipped),
        namedTable = Table.RenameColumns(tableOfSources, {{Table.ColumnNames(tableOfSources){0}, "Name"}, {Table.ColumnNames(tableOfSources){1}, "UrlName"}})
    in
        namedTable;

// Function that returns the function that allows the user to enter their search parameters
shared IndustrialAppStore.DataSearch = (dsName as text, dsUrl as text) =>
    let 
        myfunction = (tags as text, startDate as text, endDate as text, function as text, interval as text) =>
	        let 
                urltags = tags,

		        url = IndustrialAppStore.GetValuesUrl(dsUrl, urltags, startDate, endDate, function, interval),
        
		        sourcew = Web.Contents(url),
		        source = Json.Document(sourcew),

		        outerTable = Record.ToTable(source), //turns outer record to table 

                final = if Table.IsEmpty(outerTable)
                            then 
                                Table.FromRows({{"There Were No Tags Found With The Specified Parameters"}})
                            else 
                                if Text.Contains(Text.Lower(tags), "/soe/") //decides whether to parse as an SOE tag or not
                                    then 
                                        IndustrialAppStore.ProcessSOE(outerTable) meta [Documentation.Name = tags] 
                                    else 
                                        IndustrialAppStore.ProcessNormal(outerTable) meta [Documentation.Name = tags]
            in
	            final,
        
        // Adding all the metadata to be displayed in the navigation table
        TagNameType = type text meta [Documentation.Name = "Tag Name", Documentation.FieldCaption = "Tag Name(s)", Documentation.SampleValues = {"Sinusoid, LIC044"}, Documentation.FieldDescription="Tag name(s) to get data for."],
        StartDateType = type text meta [Documentation.Name = "Start Date", Documentation.FieldCaption = "Start Date", Documentation.SampleValues = {"*-10d, 2018-01-01T00:00Z"}, Documentation.FieldDescription="The absolute or relative query start time."],
        EndDateType = type text meta [Documentation.Name = "End Date",Documentation.FieldCaption = "End Date", Documentation.SampleValues = {"*-1d, 2018-02-01T00:00Z"}, Documentation.FieldDescription="The absolute or relative query end time."],
        FunctionType = type text meta [Documentation.Name = "Function",Documentation.FieldCaption = "Function", Documentation.AllowedValues = {"Interp", "Max", "Min", "Avg", "Raw", "Plot"}, Documentation.FieldDescription="The data function to use."],
        IntervalType = type text meta [Documentation.Name = "Interval",Documentation.FieldCaption = "Interval", Documentation.SampleValues = {"20s, 3h, 1d"}],

        myFunctionsType = type function(tags as TagNameType, startDate as StartDateType, endDate as EndDateType, function as FunctionType, interval as IntervalType) as table meta [Documentation.Name = dsName, Documentation.LongDescription = "Searching " & dsName & " For Specified Tags"],
        myTypedFunction = Value.ReplaceType(myfunction, myFunctionsType) 

    in myTypedFunction;

// Turns normal tags into desired table
IndustrialAppStore.ProcessNormal = (outerTable as table) => 
    let 
        tagNames = outerTable[Name] as list, // List of all the tags returned from the query

        expandedTags = Table.ExpandRecordColumn(outerTable, "Value", {"TagName", "DisplayType", "Values"}, {"TagName", "DisplayType", "Values"}), //gets an row in table for each of the tags
        
        columns = Table.ToColumns(expandedTags),  //each col is a list 

        valuesList = List.Transform(columns{3}, (x) => if (x{0}[IsNumeric]) then List.Transform(x, (y as record) => y[NumericValue]) else List.Transform(x, (y as record) => y[TextValue])), //list of lists of all the numeric values for each tag   
        valuesTable = Table.FromColumns(valuesList), //creates table with all the tags values, without correct column names
        valuesTableNamed = Table.RenameColumns(valuesTable, List.Zip({Table.ColumnNames(valuesTable), tagNames})), //adds correct column names
        valuesTableTyped = Table.TransformColumnTypes(valuesTableNamed, List.Transform(Table.ColumnNames(valuesTableNamed), (x) => if ((columns{3}{List.PositionOf(Table.ColumnNames(valuesTableNamed), x)}){0}[IsNumeric]) then {x, type number} else {x, type text})), //sets the type of the column based on the IsNumeric field
        
        datesList = List.Transform(columns{3}{0}, (x) => (x[UtcSampleTime])), //list of all the timestamps of all the values
        datesTable = Table.RenameColumns(Table.SelectColumns(Table.FromList(datesList), {"Column1"}), {"Column1", "Sample Time"}), //Table of all the dates with the correct name
        
        datesTableTyped = Table.TransformColumnTypes(datesTable, {"Sample Time", type datetime}), //sets the type of the datetime column

        valuesWIndex = Table.AddIndexColumn(valuesTableTyped, "joiner"), //adding indexed column to join the tables using
        datesWIndex = Table.AddIndexColumn(datesTableTyped, "joiner"), //adding indexed column to join the tables using
        
        joint = Table.Join(datesWIndex, "joiner", valuesWIndex, "joiner"), //joining tables
        jointRem = Table.RemoveColumns(joint, "joiner") //removing joiner column
    in
        jointRem;

// Extracts and displays all data in an SOE tag (Will only work when parsing 1 SOE tag at a time)
IndustrialAppStore.ProcessSOE = (outerTable as table) =>
    let 
        expandedTag = Table.RemoveColumns(Table.ExpandRecordColumn(outerTable, "Value", {"Values"}, {"Values"}), "Name"), //Expands columns and gets rid of unnecessary ones
        expandedList = Table.ExpandListColumn(expandedTag, "Values"), //Have a column of all the records in the values list
        expandedTextValue = Table.ExpandRecordColumn(expandedList, "Values", {"TextValue"}, {"TextValue"}), //further expands table to get to level with target JSON doc

        listForm = Table.ToRows(expandedTextValue), //Puts it into a form that the JSON parser will be able to loop over and understand
        parsed = Table.FromRecords(List.Transform(listForm, (x) => Json.Document(x{0}))) //Parsing the json and putting it into a table
    in 
        parsed;

// Tag Search
shared IndustrialAppStore.TagSearch = (dsName as text, dsUrl as text) =>
    let 
        myfunction = (optional tagName as text, optional pageSize as text, optional pageNumber as text) =>
	        let 

                url = IndustrialAppStore.GetTagSearchUrl(dsName, 
                                                         dsUrl, 
                                                         if tagName = null then "*" else tagName, 
                                                         if pageSize = null then "25" else pageSize, 
                                                         if pageNumber = null then "1" else pageNumber), 
        
		        sourcew = Web.Contents(url),
		        source = Json.Document(sourcew),

		        outerTable = Table.FromRecords(source),

                final = if Table.IsEmpty(outerTable)
                            then 
                                Table.FromRows({{"There Were No Tags Found With The Specified Parameters"}})
                            else 
                                IndustrialAppStore.ProcessTagTable(outerTable) meta [Documentation.Name = tagName]
            in
	            final,
        
        // Adding all the metadata to be displayed in the navigation table
        TagNameType = type text meta [
            Documentation.Name = "Tag Name", 
            Documentation.FieldCaption = "Tag Name", 
            Documentation.SampleValues = {"*, Fl*w, Pump*", "Sinusoid", "LIC*"}, 
            Documentation.FieldDescription = "The tag name filter."],
        SizeType = type text meta [
            Documentation.Name = "PageSize",
            Documentation.FieldCaption = "PageSize",
            Documentation.SampleValues = {"1, 25, 50"},
            Documentation.FieldDescription = "Number of tags per page."],        
        PageType = type text meta [
            Documentation.Name = "Page Number", 
            Documentation.FieldCaption = "Page Numer", 
            Documentation.SampleValues = {"1, 2", "2"},
            Documentation.FieldDescription = "Resulting set page number."],
        

        myFunctionsType = type function(optional tagName as TagNameType, optional pageSize as SizeType, optional pageNumber as PageType) as table meta [Documentation.Name = dsName, Documentation.LongDescription = "Searching " & dsName & " For Specified Tags"],
        myTypedFunction = Value.ReplaceType(myfunction, myFunctionsType) 

    in myTypedFunction;

// Turns normal tags into desired table
IndustrialAppStore.ProcessTagTable = (outerTable as table) => 
    let 
        cleanedTable = Table.RemoveColumns(outerTable, {"UnitOfMeasure", "Properties", "IsMetaTag", "DigitalStates", "Id"}),
        NavTable = Table.ToNavigationTable(cleanedTable, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

// Data Source UI publishing description
IndustrialAppStore.Publish = [
    Beta = false,
    //SupportsDirectQuery = true,     // enables direct query ??
    Category = Extension.LoadString("PublishCategory"),
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

// Authentication LogIn procedure.
IndustrialAppStore.StartLogin = (resourceUrl, state, display) =>
    let
        authorizeUrl = authorize_uri & "?" & Uri.BuildQueryString([
            client_id = client_id,
            client_secret = client_secret,
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
            Context = null
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
                    TokenMethod("authorization_code", "code", parts[code])
    in
        result;

// AccessToken refresh handler
IndustrialAppStore.Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", "refresh_token", refresh_token);

// POwer BI log out prcedure (see if possible to destroy the token)
IndustrialAppStore.Logout = (token) => 
    let
        // access current credentials Extension.CurrentCredential()
        token = "",
        logOut_Ms = WebMethod.Post("https://login.microsoftonline.com/logout.srf"),
        logOut_Lin = Web.Contents("https://www.linkedin.com/sales/logout")
    in
        logout_uri;

//
// Helper Functions
//

//checks if a value is null, and if it is, uses alternative value
Value.IfNull = (a, b) => if a <> null then a else b;

//Get's scope string
IndustrialAppStore.GetScopeString = (scopes as list, optional scopePrefix as text) as text =>
    let
        prefix = Value.IfNull(scopePrefix, ""),
        addPrefix = List.Transform(scopes, each prefix & _),
        asText = Text.Combine(addPrefix, " "),
        final = Text.Combine(asText, "&prompt=consent")
    in
        asText;

// Get DataCore values end point
IndustrialAppStore.GetDataCoreValuesEndPoint = () =>
    let
        fullPath = gestalt_url & gestalt_values_path
    in 
        fullPath;

//If multuple tags are entered turns them into a format understood by the datacore api
IndustrialAppStore.ProcessTagNames = (tags as text) =>
    let         
        tagList = Text.Split(tags, ","),
        
        final = if (List.Count(tagList) > 1) then List.Accumulate(List.Transform(tagList, (x) => "&tag=" & Text.Trim(x, " ")), "", (state, current) => state & current) else "&tag=" & tags         
    in
        final;

//Gets the url to query to get the values back
IndustrialAppStore.GetValuesUrl = (dsn as text, tags as text, startDate as text, endDate as text, function as text, points as text) =>
    let
        dcValuesEndPoint = IndustrialAppStore.GetDataCoreValuesEndPoint(),
        url = dcValuesEndPoint & dsn & "?function=" & function
                & IndustrialAppStore.ProcessTagNames(tags)
                & "&start=" & startDate
                & "&end=" & endDate
                & "&step=" & points
    in url;

// Get datasources URL endpoint
IndustrialAppStore.GetDatasourcesUrl = ( ) =>
    let
        endPoint = gestalt_url & gestalt_datasources_url
    in
        endPoint;

// Gets the url to query to get the values back
IndustrialAppStore.GetTagSearchUrl = (dsn as text, dsUrl as text, tagName as text, pageSize as text, pageNumber as text) =>
    let
        url = gestalt_url & gestalt_tags_url & dsUrl & "?unit=*&pageSize=" & pageSize & "&name=" & tagName & "&page=" & pageNumber
    in
        url;

//Navigation Table
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
TokenMethod = (grantType, tokenField, code) =>
    let
        queryString = [
            grant_type = grantType,
            redirect_uri = redirect_uri,
            client_id = client_id,
            client_secret = client_secret
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),

        tokenResponse = Web.Contents(token_uri, [
            Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode)),
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






