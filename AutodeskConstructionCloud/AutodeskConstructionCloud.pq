[Version = "1.6.3"]
section AutodeskConstructionCloud;

// Forge OAuth2 values
client_id_us = Extension.LoadString("CLIENT_ID_US");
client_id_emea = Extension.LoadString("CLIENT_ID_EMEA");
client_id_apac = Extension.LoadString("CLIENT_ID_APAC");

redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";

base_path = "https://developer.api.autodesk.com";
prefix = "/data-connector/v1/accounts/";
accounts_prefix = "/bim360/";
authorize_uri = base_path & "/authentication/v2/authorize";
scope = "data:read data:write data:create account:read";
code_challenge_method = "S256";
regions = #table(
    {"ShortName", "FullName","RegionHeader","ClientID"},
    {
        {"US", "United States", "US", client_id_us},
        {"EU", "Europe", "EMEA", client_id_emea},
        {"AUS", "Australia", "APAC", client_id_apac}
    }
);

getClientIdByRegion = (region as text) => 
    let
        plainRegion = Json.Document(region)[region],
        clientId = 
            if Table.Contains(regions, [ShortName = plainRegion]) then regions{[ShortName = plainRegion]}[ClientID]
            else if Table.Contains(regions, [FullName = plainRegion]) then regions{[FullName = plainRegion]}[ClientID]
            else error "Invalid region"
    in
        clientId;
// ======================= PKCE =========================================

StartLogin = (resourceUrl, state, display) =>
    let
        clientId = getClientIdByRegion(resourceUrl),
        // We'll generate our code verifier using Guids
        plainTextCodeVerifier = Text.NewGuid() & Text.NewGuid(),
        codeVerifier =
            if (code_challenge_method = "plain") then
                plainTextCodeVerifier
            else if (code_challenge_method = "S256") then
                Base64Url.Encode(Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(plainTextCodeVerifier)))
            else
                error "Unexpected code_challenge_method",

        AuthorizeUrl = authorize_uri & "?" & Uri.BuildQueryString([
            client_id = clientId,
            response_type = "code",
            code_challenge_method = code_challenge_method,
            scope="account:read data:create data:read data:write",
            code_challenge = codeVerifier,
            state = state,
            redirect_uri = redirect_uri])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = 720,
            WindowWidth = 1024,
            // Need to roundtrip this value to FinishLogin
            Context = plainTextCodeVerifier
        ];

// The code verifier will be passed in through the context parameter.
FinishLogin = (c, dataSourcePath, context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query]
    in
        TokenMethod(dataSourcePath, Parts[code], "authorization_code", context);

TokenMethod = (dataSourcePath, code, grant_type, optional verifier) =>
    let
        clientId = getClientIdByRegion(dataSourcePath),
        codeVerifier = if (verifier <> null) then [code_verifier = verifier] else [],
        codeParameter = if (grant_type = "authorization_code") then [ code = code ] else [ refresh_token = code ],
        query = codeVerifier 
            & codeParameter 
            & [
            client_id = clientId,
            grant_type = grant_type,
            redirect_uri = redirect_uri
        ],

        ManualHandlingStatusCodes= {},
        
        Response = Web.Contents(base_path & "/authentication/v2" & "/token", [
            Content = Text.ToBinary(Uri.BuildQueryString(query)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = ManualHandlingStatusCodes
        ]),
        Parts = Json.Document(Response)
    in
        // check for error in response
        if (Parts[error]? <> null) then 
            error Error.Record(Parts[error], Parts[message]?)
        else
            Parts;
 
Refresh = (resourceUrl, refresh_token) => TokenMethod(resourceUrl, refresh_token, "refresh_token");



// ===================================================================

// Data Source Kind description
AutodeskConstructionCloud = [
    TestConnection = (dataSourcePath) => 
        let 
            json = Json.Document(dataSourcePath),
            region = json[region]
        in
            { "AutodeskConstructionCloud.Feed", region },
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Function to allow selecting account vs project extracts
[DataSource.Kind="AutodeskConstructionCloud", Publish="AutodeskConstructionCloud.Publish"]
shared AutodeskConstructionCloud.Feed = Value.ReplaceType(NavigationTable.Nested, AutodeskConstructionCloudType);

// Create Metadata Nav table
NavigationTable.Nested = (region as text) as table =>
    let
        header = getHeader(region),
        objects = GetAccountsNavTable(header),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

GetAccountsNavTable = (header) as table =>
    let 
        source =  getAccounts(header),
        accountsFromList = Table.FromList(source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        accountsExpand = Table.ExpandRecordColumn(accountsFromList, "Column1", {"name", "id"}, {"Name", "Key"}),      
        accountsAddData = Table.AddColumn(accountsExpand, "Data", each try CreateAccountsFolders([Key], [Name], header) otherwise null),
        accountsAddItemKind = Table.AddColumn(accountsAddData, "ItemKind", each "Folder"),
        accountsAddItemName = Table.AddColumn(accountsAddItemKind, "ItemName", each "Folder"),
        accountsAddIsLeaf = Table.AddColumn(accountsAddItemName, "IsLeaf", each false)
    in
        accountsAddIsLeaf;

CreateAccountsFolders = (accountId as text, accountName as text, header) as table =>
    let
        AccountFolder = #table({"Name", "Key","Data","ItemKind","ItemName","IsLeaf"},{}),

        AddAccountExtractsFolder = Table.InsertRows(AccountFolder, 0, 
            {[
                Name = "Account Extract", 
                Key = accountId & "_accountExtract", 
                Data = CreateAccountExtractsTable(accountId, header), 
                ItemKind = "Folder", 
                ItemName = "Folder", 
                IsLeaf = false]}),

        AddProjectExtractsFolder = Table.InsertRows(AddAccountExtractsFolder, 1, 
            {[
                Name = "Project Extracts", 
                Key = accountId & "_projectExtracts", 
                Data = CreateProjectsFolder(accountId, header), 
                ItemKind = "Folder", 
                ItemName = "Folder", 
                IsLeaf = false]}),

        NavTable = Table.ToNavigationTable(AddProjectExtractsFolder, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

CreateAccountExtractsTable = (accountId, header) as table =>
    let
        values = getViewsAccountOnly(accountId, header),
        #"Added Data" = Table.AddColumn(
            values[data], "Data", each getCsv(values[account], values[job], [Name], header)
        ),
        #"Added ItemKind" = Table.AddColumn(#"Added Data", "ItemKind", each "Table", Text.Type),
        #"Added ItemName" = Table.AddColumn(#"Added ItemKind", "ItemName", each "Table", Text.Type),
        #"Added IsLeaf" = Table.AddColumn(#"Added ItemName", "IsLeaf", each true, Text.Type),
        asNav = Table.ToNavigationTable(#"Added IsLeaf", {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        asNav;

CreateProjectsFolder = (accountId, header) as table =>
    let
        source = GetAllProjects(header, accountId), 
        projectsTable = Table.RenameColumns(source,{{"name","Name"},{"id","Key"}}),
        projectsAddData = Table.AddColumn(projectsTable, "Data", each CreateProjectsExtractsTable(accountId, [Key], [Name], header)),
        projectsAddItemKind = Table.AddColumn(projectsAddData, "ItemKind", each "Folder"),
        projectsAddItemName = Table.AddColumn(projectsAddItemKind, "ItemName", each "Folder"),
        projectsAddIsLeaf = Table.AddColumn(projectsAddItemName, "IsLeaf", each false),
        asNav = Table.ToNavigationTable(projectsAddIsLeaf, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        asNav;

CreateProjectsExtractsTable = (accountId, projectId, projectName, header) as table =>
    let
        values = getViewsByProject(accountId, projectId, header),
        #"Added Data" = Table.AddColumn(
            values[data], "Data", each getCsv(values[account], values[job], [Name], header)
        ),
        #"Added ItemKind" = Table.AddColumn(#"Added Data", "ItemKind", each "Table", Text.Type),
        #"Added ItemName" = Table.AddColumn(#"Added ItemKind", "ItemName", each "Table", Text.Type),
        #"Added IsLeaf" = Table.AddColumn(#"Added ItemName", "IsLeaf", each true, Text.Type),
        asNav = Table.ToNavigationTable(#"Added IsLeaf", {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        asNav;

// Deprecated function for accessing data extracts without project/account context
[DataSource.Kind="AutodeskConstructionCloud"]
shared AutodeskConstructionCloud.Contents = Value.ReplaceType(AutodeskConstructionCloudImpl, AutodeskConstructionCloudType);

getHeader = (region as text) => 
    let 
        headerRegion = 
            if Table.Contains(regions, [ShortName = region]) then regions{[ShortName = region]}[RegionHeader]
            else if Table.Contains(regions, [FullName = region]) then regions{[FullName = region]}[RegionHeader]
            else error "Invalid region"
    in 
        [
            Origin = "PowerBI Desktop",
            #"x-ads-region" = headerRegion
        ];       


AutodeskConstructionCloudType = type function (
    region as (Text.Type meta [
        Documentation.FieldCaption = "Region",
        Documentation.AllowedValues = Table.Column(regions, "FullName")
    ])) 
    as table meta [
        Documentation.Name = "Autodesk Construction Cloud",
        Documentation.LongDescription = "Version: " & Extension.LoadString("Version")
     ];

AutodeskConstructionCloudImpl = (region as text) as table =>
    let
        header = getHeader(region),
        accounts =  getAccounts(header),
        accountsNavigation = generateAccountsNavigation(accounts, header)
    in
        accountsNavigation;

getAccounts = (header) =>
    let
        response = Json.Document(
            Web.Contents(base_path & accounts_prefix & "admin/v1/accounts",
                [
                    Query = [ limit="200", fields="name", sort="name"],
                    Headers = header
                ]
            )
        ),
        accounts = response[results]
    in
        accounts;

GetAllProjects = (header, accountId) as table =>
    let
        getFunction = (url) => getProjects(header, url),
        firstPage = base_path & "/construction/" & "admin/v1/accounts/" & accountId & "/projects?fields=name&filterTextMatch=contains&filter%5Bclassification%5D=production,sample&filter%5Btype%5D=-Template%20Project&limit=200&offset=0&sort=name",
        allPages = GetAllPagesByNextLink(firstPage, getFunction)
    in
        allPages;

getProjects = (header, url) as table =>
    let
        response = Json.Document(
            Web.Contents(url,[ Headers = header ])
        ),
        nextLink = GetNextLink(response[pagination]),
        projects = Table.FromRecords(response[results],{"name", "id"})
    in
        projects meta [NextLink = nextLink];

GetNextLink = (response) as nullable text => Record.FieldOrDefault(response, "nextUrl"); // Get the nextUrl if it exists

GetAllPagesByNextLink = (url as text, dataFunc as function) as table =>
    Table.GenerateByPage((previous) => 
        let
            // if previous is null, then this is our first page of data
            nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
            // if NextLink was set to null by the previous call, we know we have no more data
            page = if (nextLink <> null) then dataFunc(nextLink) else null
        in
            page
    );
/**
 * Generate a NavigationTable for the accounts (deprecated)
 */
 
generateAccountsNavigation = (accounts, header) =>
    let
        #"Converted to Table" = Table.FromList(accounts, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"name", "id"}, {"Name", "Key"}),
        #"Added Data" = Table.AddColumn(
            #"Expanded Column1", "Data", each generateFileTables([Key], header)
        ),
        #"Added ItemKind" = Table.AddColumn(#"Added Data", "ItemKind", each "Folder", Text.Type),
        #"Added ItemName" = Table.AddColumn(#"Added ItemKind", "ItemName", each "Folder", Text.Type),
        #"Added IsLeaf" = Table.AddColumn(#"Added ItemName", "IsLeaf", each false, Logical.Type),
        asNav = Table.ToNavigationTable(#"Added IsLeaf", {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        asNav;

generateFileTables = (id, header) =>
    let
        values = getViews(id, header),
        #"Added Data" = Table.AddColumn(
            values[data], "Data", each getCsv(values[account], values[job], [Name], header)
        ),
        #"Added ItemKind" = Table.AddColumn(#"Added Data", "ItemKind", each "Table", Text.Type),
        #"Added ItemName" = Table.AddColumn(#"Added ItemKind", "ItemName", each "Table", Text.Type),
        #"Added IsLeaf" = Table.AddColumn(#"Added ItemName", "IsLeaf", each true, Text.Type),
        asNav = Table.ToNavigationTable(#"Added IsLeaf", {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        asNav;


          
/**
 * Jobs
 */
 

fetchJobs = (accountId, header) => 
    let 
        waitForResult = Value.WaitFor(
            (iteration) =>
                let 
                    result =  Web.Contents(
                        base_path & prefix & accountId & "/jobs",
                            [
                                Query = [ sort="desc", limit="100", offset="0" ],
                                Headers = header,
                                ManualStatusHandling = {500,502},
                                IsRetry = iteration > 0
                            ]
                    ),
                    status = Value.Metadata(result)[Response.Status],
                    resultParse = Json.Document(result),
                    actualResult = if status = 500 or status = 502 then null else Json.Document(result)
                in
                    actualResult,
                (iteration) => #duration(0, 0, 0, Number.Power(2, iteration)),
        5)
    in
        waitForResult;


getLastJob = (jobs) =>
    try
        let

            jobResults = jobs[results],
            jobTable = Table.FromList(
                jobResults, Splitter.SplitByNothing(), null, null, ExtraValues.Error
            ),
            #"Expanded Job Column" = Table.ExpandRecordColumn(
                jobTable, "Column1", { "id", "completionStatus" }, { "id", "completionStatus" }
            ),
            #"Filtered Rows" = Table.SelectRows(#"Expanded Job Column", each ([completionStatus] = "success")),
            jobId = #"Filtered Rows"{0}
        in
            jobId
    otherwise
        error Error.Record("DataSource.Error", "No data requests for this account in the last 30 days. Users with executive overview access can request data from Autodesk Data Connector.");

getLastProjectJob = (jobs) =>
    try
        let

            jobResults = jobs[results],
            jobTable = Table.FromList(
                jobResults, Splitter.SplitByNothing(), null, null, ExtraValues.Error
            ),
            #"Expanded Job Column" = Table.ExpandRecordColumn(
                jobTable, "Column1", { "id", "completionStatus" }, { "id", "completionStatus" }
            ),
            #"Filtered Rows" = Table.SelectRows(#"Expanded Job Column", each ([completionStatus] = "success")),
            jobId = #"Filtered Rows"{0}
        in
            jobId
    otherwise
        error Error.Record("DataSource.Error", "No data requests for this project in the last 30 days. Users with project admin access can request data from Autodesk Data Connector.");


getLastAccountJob = (jobs) =>
    try
        let

            jobResults = jobs[results],
            jobTable = Table.FromList(
                jobResults, Splitter.SplitByNothing(), null, null, ExtraValues.Error
            ),
            #"Expanded Job Column" = Table.ExpandRecordColumn(
                jobTable, "Column1", { "id", "completionStatus", "projectId" }, { "id", "completionStatus", "projectId" }
            ),
            #"Filtered Rows" = Table.SelectRows(#"Expanded Job Column", each ([completionStatus] = "success") and ([projectId] = null)),
            jobId = #"Filtered Rows"{0}
        in
            jobId
    otherwise
        error Error.Record("DataSource.Error", "No data requests for this account in the last 30 days. Users with executive overview access can request data from Autodesk Data Connector.");

fetchJobsByProject = (accountId, projectId, header) => 
    let 
        waitForResult = Value.WaitFor(
            (iteration) =>
                let 
                    result =  Web.Contents(
                        base_path & prefix & accountId & "/jobs",
                            [
                                Query = [ sort="desc", limit="10", offset="0", projectId=projectId ],
                                Headers = header,
                                ManualStatusHandling = {500,502},
                                IsRetry = iteration > 0
                            ]
                    ),
                    status = Value.Metadata(result)[Response.Status],
                    resultParse = Json.Document(result),
                    actualResult = if status = 500 or status = 502 then null else Json.Document(result)
                in
                    actualResult,
                (iteration) => #duration(0, 0, 0, Number.Power(2, iteration)),
        5)
    in
        waitForResult;

fetchJobsAccountOnly = (accountId, header) => 
    let 
        waitForResult = Value.WaitFor(
            (iteration) =>
                let 
                    result =  Web.Contents(
                        base_path & prefix & accountId & "/jobs",
                            [
                                Query = [ sort="desc", limit="100", offset="0", #"filter[projectId]"="null" ],
                                Headers = header,
                                ManualStatusHandling = {500,502},
                                IsRetry = iteration > 0
                            ]
                    ),
                    status = Value.Metadata(result)[Response.Status],
                    resultParse = Json.Document(result),
                    actualResult = if status = 500 or status = 502 then null else Json.Document(result)
                in
                    actualResult,
                (iteration) => #duration(0, 0, 0, Number.Power(2, iteration)),
        5)
    in
        waitForResult;

/**
 * Data listing
 */

fetchDataListing = (accountId, jobId, header) => 
    try
        let 
            waitForResult = Value.WaitFor(
                (iteration) =>
                    let 
                        result =  Web.Contents(
                            base_path & prefix & accountId & "/jobs/" & jobId & "/data-listing",
                            [
                                Headers = header,
                                ManualStatusHandling = {500,502},
                                IsRetry = iteration > 0
                            ]
                        ),
                        status = Value.Metadata(result)[Response.Status],
                        resultParse = Json.Document(result),
                        actualResult = if status = 500 or status = 502 then null else Json.Document(result)
                    in
                        actualResult,
                    (iteration) => #duration(0, 0, 0, Number.Power(2, iteration)),
            5)
        in
            waitForResult
    otherwise
        error Error.Record("Error", "Unfortunately, your Data Connector job failed. Please re-submit a new Data Connector request to continue.");

   
AutodeskConstructionCloud.prepareDataListing = (dataListing) =>
    let
        dataListToTable = Table.FromList(dataListing, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Datalist Column" = Table.ExpandRecordColumn(
            dataListToTable, 
            "Column1", 
            {"name"},
            {"Name"}
        ),
        #"Filtered Rows" = Table.SelectRows(
            #"Expanded Datalist Column", 
            each Text.Contains([Name], ".csv")
        ),
        dataListTable = Table.ReplaceValue(
            #"Filtered Rows", ".csv", "", Replacer.ReplaceText, {"Name"}
        )
    in
        dataListTable;

/**
 * CSV
 */


fetchSignedUrl = (accountId, jobId, filename, header) => 
    let 
        waitForResult = Value.WaitFor(
            (iteration) =>
                let 
                    result =  Web.Contents(
                        base_path & prefix & accountId & "/jobs/" & jobId & "/data/" & filename & ".csv", [
                            Headers = header,
                            ManualStatusHandling = {500,502},
                            IsRetry = true
                        ]),
                    status = Value.Metadata(result)[Response.Status],
                    resultParse = Json.Document(result),
                    actualResult = if status = 500 or status = 502 then null else resultParse[signedUrl]
                in
                    actualResult,
            (iteration) => #duration(0, 0, 0, Number.Power(2, iteration)),
        5)
    in
        waitForResult;

fetchCsvFile = (accountId, jobId, filename, header) =>
    let
        waitForResult = Value.WaitFor(
            (iteration) =>
                let
                    signedUrl = fetchSignedUrl(accountId, jobId, filename, header),
                    result = Web.Contents(signedUrl, [ 
                        ManualCredentials = true,
                        ManualStatusHandling = {403},
                        IsRetry = iteration > 0
                    ]),
                    status = Value.Metadata(result)[Response.Status],
                    _status = Diagnostics.LogValue("StatuCode is",status),
                    actualResult = if 
                            _status = 403
                        then null else Csv.Document(result, [ Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.Csv])
                in
                    actualResult,
            (iteration) => #duration(0, 0, 0, Number.Power(2, iteration)),
        5)
    in
        if waitForResult = null then
            error "Value.WaitFor() Failed after multiple retry attempts"
        else
            waitForResult;

getCsv = (accountId, jobId, name, header) =>
    let
        csv = fetchCsvFile(accountId, jobId, name, header),
        withHeaders = Table.PromoteHeaders(csv)
    in
        withHeaders;

/**
 * Get Datalisting
 */
 
getViews = (accountId as text, header) =>
    try
        let
            jobs            = fetchJobs(accountId, header),
            jobId           = getLastJob(jobs)[id],
            dataListing     = fetchDataListing(accountId, jobId, header),
            values          = [
                data = AutodeskConstructionCloud.prepareDataListing(dataListing),
                account = accountId,
                job = jobId
            ]
        in
            values
    otherwise
        error Error.Record(
            "DataSource.Error", 
            "No data requests for this account in the last 30 days. Users with executive overview access can request data from Autodesk Data Connector."
        );

getViewsByProject = (accountId as text, projectId as text, header) =>
    try
        let
            jobs            = fetchJobsByProject(accountId, projectId, header),
            jobId           = getLastProjectJob(jobs)[id],
            dataListing     = fetchDataListing(accountId, jobId, header),
            values          = [
                data = AutodeskConstructionCloud.prepareDataListing(dataListing),
                account = accountId,
                job = jobId
            ]
        in
            values
    otherwise
        error Error.Record(
            "DataSource.Error", 
            "No data requests for this project in the last 30 days. Users with project admin access can request data from Autodesk Data Connector."
        );

getViewsAccountOnly = (accountId as text, header) =>
    try
        let
            jobs            = fetchJobsAccountOnly(accountId, header),
            jobId           = getLastAccountJob(jobs)[id],
            dataListing     = fetchDataListing(accountId, jobId, header),
            values          = [
                data = AutodeskConstructionCloud.prepareDataListing(dataListing),
                account = accountId,
                job = jobId
            ]
        in
            values
    otherwise
        error Error.Record(
            "DataSource.Error", 
            "No data requests for this account in the last 30 days. Users with executive overview access can request data from Autodesk Data Connector."
        );
/**
 * Helper functions for OAuth2: StartLogin, FinishLogin
 */


/**
 * Common functions
 */

Value.WaitFor = (producer as function, interval as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, null},
            (state) => state{0} <> null and (count = null or state{0} < count),
            (state) => if state{1} <> null then {null, state{1}} else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), interval(state{0}))},
            (state) => state{1})
    in
        List.Last(list);

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

Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

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
    // check for empty first table
        else if (Table.IsEmpty(firstRow[Column1])) then
            firstRow[Column1]
        else
            Value.ReplaceType(
                Table.ExpandTableColumn(tableOfPages, "Column1", Table.ColumnNames(firstRow[Column1])),
                Value.Type(firstRow[Column1])
            );

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = Diagnostics[LogValue];
Diagnostics.LogFailure = Diagnostics[LogFailure];

Base64Url.Encode = (s) => Text.Replace(Text.Replace(Text.BeforeDelimiter(Binary.ToText(s,BinaryEncoding.Base64),"="),"+","-"),"/","_");

/**
 * Data Source UI publishing description
 */
AutodeskConstructionCloud.Publish = [
    Beta = false,
    Category = "Online Services",
    ButtonText = { "Autodesk Construction Cloud", "Autodesk Construction Cloud" },
    LearnMoreUrl = "https://help.autodesk.com/view/BIM360D/ENU/?guid=BIM360D_Insight_data_extractor_html",
    SourceImage = AutodeskConstructionCloud.Icons,
    SourceTypeImage = AutodeskConstructionCloud.Icons
];

AutodeskConstructionCloud.Icons = [
    Icon16 = { Extension.Contents("AutodeskConstructionCloud16.png"), Extension.Contents("AutodeskConstructionCloud20.png"), Extension.Contents("AutodeskConstructionCloud24.png"), Extension.Contents("AutodeskConstructionCloud32.png") },
    Icon32 = { Extension.Contents("AutodeskConstructionCloud32.png"), Extension.Contents("AutodeskConstructionCloud40.png"), Extension.Contents("AutodeskConstructionCloud48.png"), Extension.Contents("AutodeskConstructionCloud64.png") }
];
