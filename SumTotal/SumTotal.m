// This file contains your Data Connector logic
[Version = "2.0.0"]
section SumTotal;

//Constants
client_id = "sumtotal_powerbi";
client_secret = "secret_oidc"; 

windowWidth = 800;
windowHeight = 500;
hardRedirect = "https://oauth.powerbi.com/views/oauthredirect.html";


DefaultRequestHeaders = [
  #"Accept" = "application/json;odata.metadata=minimal",  // column name and values only
  #"OData-MaxVersion" = "4.0"                             // we only support v4
];

//main invokation
[DataSource.Kind="SumTotal", Publish="SumTotal.Publish"]
shared SumTotal.ODataFeed = Value.ReplaceType(SumTotalNavTable, SumTotalType);

SumTotalType = type function (
    url as (Uri.Type meta [
        Documentation.FieldCaption = "Customer Environment Url",
        Documentation.FieldDescription = "Customer Environment Url that allows for rowVersionId filtering by appending the parameter and the rowVersionId as a query string at the end of the url",
        Documentation.SampleValues = {"https://host.sumtotalystems.com/", "https://host.sumtotalystems.com/?RowVersionId=810016899151691776"}
    ]))
    as table meta [
        Documentation.Name = "SumTotal BI Connector",
        Documentation.LongDescription = "SumTotal's Custom connector connects to SumTotal's external facing OData API service to pull data from data warehousing database . Filter expand, slice and create customer visuals and reports based on data returned from the OData feed",
        Documentation.Examples = {[
            Description = "Returns a table with specified entity data",
            Code = "SumTotal.ODataFeed('https://host.sumtotalystems.com/?rowVersionId=0')",
            Result = " Source{[Name='{OData Entity chosen}']}[Data]"
        ]}
    ];

SumTotalNavTable = (url as text) as table =>
    let
        urlParts = if Text.Contains(url, "?") then Text.Split(url,"?") else null,
        apiURL =  if Text.Contains(url, "?") then urlParts{0} else url,
        rowVersionPart =  if Text.Contains(url, "?") then urlParts{1}  else null,
        odataEntities = OData.Feed(Uri.Combine(apiURL,"/odata/api/"), null, [ Implementation = "2.0" ])
    in
        odataEntities;

SumTotal.Feed = (url as text) as table => GetAllPagesByNextLink(url);

GetPage = (url as text) as table =>
    let
        response = Web.Contents(url, [ Headers = DefaultRequestHeaders ]),        
        body = Json.Document(response),
        nextLink = GetNextLink(body),
        data = Table.FromRecords(body[value])
    in
        data meta [NextLink = nextLink];

// Read all pages of data.
// After every page, we check the "NextLink" record on the metadata of the previous request.
// Table.GenerateByPage will keep asking for more pages until we return null.
GetAllPagesByNextLink = (url as text) as table =>
    Table.GenerateByPage((previous) => 
        let
            // if previous is null, then this is our first page of data
            nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
            // if NextLink was set to null by the previous call, we know we have no more data
            page = if (nextLink <> null) then GetPage(nextLink) else null
        in
            page
    );

// In this implementation, 'response' will be the parsed body of the response after the call to Json.Document.
// We look for the '@odata.nextLink' field and simply return null if it doesn't exist.
GetNextLink = (response) as nullable text => Record.FieldOrDefault(response, "@odata.nextLink");


//
// Common functions
//

// The getNextPage function takes a single argument and is expected to return a nullable table
Table.GenerateByPage = (getNextPage as function) as table =>
    let        
        listOfPages = List.Generate(
            () => getNextPage(null),            // get the first page of data
            (lastPage) => lastPage <> null,     // stop when the function returns null
            (lastPage) => getNextPage(lastPage) // pass the previous page to the next function call
        ),
        // concatenate the pages together
        tableOfPages = Table.FromList(listOfPages, Splitter.SplitByNothing(), {"Column1"}),
        firstRow = tableOfPages{0}?
    in
        // if we didn't get back any pages of data, return an empty table
        // otherwise set the table type based on the columns of the first page
        if (firstRow = null) then
            Table.FromRows({})
        else        
            Value.ReplaceType(
                Table.ExpandTableColumn(tableOfPages, "Column1", Table.ColumnNames(firstRow[Column1])),
                Value.Type(firstRow[Column1])
            );

// Data Source Kind description
SumTotal = [
    TestConnection = (dataSourcePath) => {"SumTotal.ODataFeed", dataSourcePath},
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh,
            Label = "SumTotal"
        ]
    ],
    Label = "SumTotal"
];

StartLogin = (resourceUrl, state, display) =>
    let
        urlParts = Text.Split(resourceUrl,"?"),
        apiURL =  urlParts{0},
        rowVersionPart = Text.Combine(urlParts{1}, "?"),
        AuthorizeUrl = Uri.Combine(apiURL, "/apisecurity/connect/authorize") & "?" & Uri.BuildQueryString([
            client_id = client_id,
            state = state,
            response_type = "code",
            scope= "odataapis offline_access",
            redirect_uri = hardRedirect,
            broker_bypassfederation =  if (Text.Contains(Text.Lower(resourceUrl), "bypassfederation=1") or Text.Contains(Text.Lower(resourceUrl), "bypassfederation=true")) then "1" else "0"])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = hardRedirect,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = apiURL
        ];

FinishLogin = (context, callbackUri, state) =>
    let
            Parts = Uri.Parts(callbackUri)[Query],
            resourceURL =  context,
            result = if (Record.HasFields(Parts, {"error", "error_description"})) then
                        error Error.Record(Parts[error], Parts[error_description], Parts)
                    else
                        TokenMethod("authorization_code", Parts[code], resourceURL)
    in
       result;

TokenMethod = (grantType, code, resourceURL) =>
    let
        query = [
                    client_id = client_id,
                    //client_secret = client_secret,
                    code = code,
                    grant_type = grantType,
                    redirect_uri = hardRedirect
                ],

        queryWithCode = if (grantType = "refresh_token") then [ refresh_token = code ] else [code = code],
        Response = Web.Contents(resourceURL & "apisecurity/connect/token", [
        Content = Text.ToBinary(Uri.BuildQueryString(query & queryWithCode)),
        Headers = [#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json"], ManualStatusHandling = {400}]),
        Parts = Json.Document(Response),
        Result = if (Record.HasFields(Parts, {"error", "error_description"})) then
                    error Error.Record(Parts[error], Parts[error_description], Parts)
                else
                    Parts
    in
        Result;

Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", refresh_token, resourceUrl);

// Data Source UI publishing description
SumTotal.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { "SumTotal", "SumTotal Connector" },
    LearnMoreUrl = "https://marketplace.sumtotalsystems.com/Home/ODataAPI",
    SourceImage = SumTotal.Icons,
    SourceTypeImage = SumTotal.Icons
];

SumTotal.Icons = [
    Icon16 = { Extension.Contents("16.png"), Extension.Contents("20.png"), Extension.Contents("24.png"), Extension.Contents("32.png") },
    Icon32 = { Extension.Contents("32.png"), Extension.Contents("40.png"), Extension.Contents("48.png"), Extension.Contents("64.png") }
];
