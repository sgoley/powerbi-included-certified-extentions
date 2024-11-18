[Version = "1.0.5"]
section AzureResourceGraph;

[DataSource.Kind="AzureResourceGraph", Publish="AzureResourceGraph.Publish"]
shared AzureResourceGraph.Query = Value.ReplaceType(ARGImpl, AzureResourceGraphType);

AzureResourceGraphType = type function(
    query as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("QueryFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("QueryDescription"),
        Documentation.SampleValues = {
            Extension.LoadString("SampleQuery")
        },
        Formatting.IsMultiLine = true,
        Formatting.IsCode = true
    ]),
    optional scope as (type nullable text meta [
        Documentation.FieldCaption = Extension.LoadString("ScopeFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("ScopeDescription"),
        Documentation.AllowedValues = { "Tenant", "Subscription", "Management group"}
    ]),
    optional subscription as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("SubscriptionFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("SubscriptionDescription"),
        Documentation.SampleValues = {Extension.LoadString("SubscriptionInputSample")}
    ]),
    optional managementGroup as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("ManagementGroupFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("ManagementGroupsDescription"),
        Documentation.SampleValues = {Extension.LoadString("ManagementGroupInputSample")}
    ]),
    optional options as (type nullable [
        optional resultTruncated = (type logical meta [
            Documentation.FieldCaption = Extension.LoadString("resultTruncatedFieldCaption"),
            Documentation.FieldDescription = Extension.LoadString("resultTruncated"),
            Documentation.AllowedValues = {true, false},
            Documentation.SampleValues = {true}
        ])
        ] meta [
    Documentation.FieldCaption = Extension.LoadString("AdvancedOptionsLabel")
])
) as table meta [
        Documentation.Name = "Azure Resource Graph",
        Documentation.LongDescription = Extension.LoadString("LongerDescription"),
        Documentation.Examples = {[
            Description = Extension.LoadString("docExampleDescription"),
            Code = "AzureResourceGraph.Query(""resources"")",
            processedResult = Extension.LoadString("docExampleProcessedResult")
        ]}
    ];

ARGImpl = (query as text, optional scope as nullable text, optional subscription as text, optional managementGroup as text, optional options as record) as table =>
    Table.GenerateByPage((previous) => 
        let
            // if previous is null, then this is our first page of data
            nextToken = if (previous = null) then "" else Value.Metadata(previous)[SkipToken]?,
            // if NextToken was set to null by the previous call, we know we have no more 
            delay = Number.RandomBetween(1, 3),
            page = if (nextToken <> null) then Function.InvokeAfter(() => GetPage(query, nextToken, scope, subscription, managementGroup, options), #duration(0,0,0,delay)) else null
        in
            page
    );

GetPage = (query as text, skipToken as text, optional scope as nullable text, optional subscription as text, optional managementGroup as text, optional options as record) as table =>
    let
        scopeValue = if scope = null then "Tenant" else scope,
        subscription =  if subscription = null then "" else subscription,
        managementGroup =  if managementGroup = null then "" else managementGroup,
        scopeCheck = if scopeValue = "Tenant" and ((subscription <> "") or (managementGroup <> "")) then error Extension.LoadString("scopeCheckErrorMessage") else null,
        emptyScopeCheck = if scopeValue <> "Tenant" and ((subscription = "") and (managementGroup = "")) then error Extension.LoadString("expectedScopeParameters") else null,
        subscriptionValueCheck = if scopeValue = "Subscription" and managementGroup <> "" then error Extension.LoadString("ScopeSubscriptionMismatch") else null,
        managementgroupValueCheck = if scopeValue = "Management group" and subscription <> "" then error Extension.LoadString("ScopeManagementGroupMismatch") else null,
        resultTruncated = if options[resultTruncated]? = null then true else false,
        postData = BuildPostContent(query, skipToken, scopeValue, subscription, managementGroup, resultTruncated),
        response = WaitForResult(postData),
        body = if response[IsError] = false then response[Content] else null, 
        errorCheck = if response[IsError] then error response[Content] else null,
        nextSkipToken = if resultTruncated = true then null else GetSkipToken(body),
        resultTable = if errorCheck = null then Table.FromList(body[data]?, Splitter.SplitByNothing(), null, null, ExtraValues.Error) else null,
        processedResult = if errorCheck = null and not Table.IsEmpty(resultTable) then Table.ExpandRecordColumn(resultTable, "Column1", Record.FieldNames(Table.Column(resultTable, "Column1"){0})) else null,
        output = if processedResult = null then #table({"Results"}, {{"No results"}}) else processedResult
    in
        if scopeCheck <> null then scopeCheck else if emptyScopeCheck <> null then emptyScopeCheck else if subscriptionValueCheck <> null then subscriptionValueCheck else if managementgroupValueCheck <> null then managementgroupValueCheck else if errorCheck <> null then errorCheck else output meta [SkipToken = nextSkipToken];

WaitForResult = (postData as binary) => 
    let
        apiUrl = Uri.Combine(GetEndpointConfig()[AzureResourceManager], "/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01"),
        waitForResult = Value.WaitFor(
            (iteration) =>
                let
                    result = Web.Contents(apiUrl, 
                        [Headers = [#"Content-Type" = "application/json", #"X-Ms-Command-Name" = "ARGPBI"],
                        Content = postData,
                        ManualStatusHandling = {500, 400},
                        IsRetry = iteration > 0]),
                    status = Value.Metadata(result)[Response.Status],
                    body = Json.Document(result),
                    statusCode = Value.Metadata(result)[Response.Status],
                    errorMessage = if statusCode <> 200 then body[error][message] else "",
                    details = if statusCode <> 200 then Record.Field(body[error], "details") else {},
                    detailedErrorMessage = if statusCode <> 200 and List.IsEmpty(details) then "" else if List.IsEmpty(details) <> true then List.Accumulate(details, "", (state, current) => state & " " & current[message]) else "",
                    errorCheck = if statusCode <> 200 then errorMessage & " Details:" & detailedErrorMessage else null,
                    actualResult = if status = 500 then if iteration < 3 then null else [IsError = true, Content = errorCheck] else if status = 400 then [IsError = true, Content = errorCheck] else [IsError = false, Content = body]
                in
                    actualResult,
            (iteration) => #duration(0, 0, 0, Number.Power(2, iteration)), 3)
    in
        waitForResult;

Value.WaitFor = (producer as function, interval as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, null},
            (state) => state{0} <> null and (count = null or state{0} < count),
            (state) => if state{1} <> null then {null, state{1}} else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), interval(state{0}))},
            (state) => state{1})
    in
        List.Last(list);

BuildPostContent = (query as text, skipToken as text, scope as text, optional subscription as text, optional managementGroup as text, optional resultTruncated as logical) =>
    let
        AddFieldOrNull = (rec, field, value) =>
        if (value <> null) then
            Record.AddField(rec, field, value)
        else
            rec,
        processedParam = if scope = "Subscription" then ProcessParam(subscription) else if scope = "Management group" then ProcessParam(managementGroup) else null,
        scopeForQuery = if scope = "Subscription" then "subscriptions" else if scope = "Management group" then "managementGroups" else null,
        skip = null,
        top = null,
        resultTruncated = if resultTruncated = true then skip = 0 and top = 1000 else null,
        processedQuery = Text.Replace(query, "#(lf)", ""),
        base = [query = processedQuery],
        baseOptions = [],
        optionsWithSkip = AddFieldOrNull(baseOptions, "$skip", skip),
        optionsWithTop = AddFieldOrNull(optionsWithSkip, "$top", top),
        optionsWithSkipToken = AddFieldOrNull(optionsWithTop, "$skipToken", skipToken),
        requestBodyWithOptions = if Record.FieldCount(optionsWithSkipToken) > 0 then Record.AddField(base, "options", optionsWithSkipToken) else base,
        requestBodyWithScope = AddFieldOrNull(requestBodyWithOptions, scopeForQuery, processedParam),
        jsonBody = Json.FromValue(requestBodyWithScope)
    in
        jsonBody;

ProcessParam = (param as text) =>
    let
        paramList = Text.Split(param, ","),
        trimmedList = List.Transform(paramList, each Text.Trim(_))
    in
        trimmedList;

// In this implementation, 'response' will be the parsed body of the response after the call to Json.Document.
// Look for the '$skipToken' field and simply return null if it doesn't exist.
GetSkipToken = (response) as nullable text => Record.FieldOrDefault(response, "$skipToken");

EnvironmentConfiguration = [
    AzureActiveDirectory = Environment.FeatureSwitch("AzureActiveDirectoryUri", GlobalCloudConfiguration[AzureActiveDirectory]),
    AzureResourceManager = Environment.FeatureSwitch("AzureResourceManagerUri", GlobalCloudConfiguration[AzureResourceManager]),
    AzureResourceManagerResource = Environment.FeatureSwitch("AzureResourceManagerAadResource", GlobalCloudConfiguration[AzureResourceManagerResource])
];

GlobalCloudConfiguration = [
    AzureActiveDirectory = "https://login.microsoftonline.com",
    AzureResourceManager = "https://management.azure.com/",
    AzureResourceManagerResource = "https://management.core.windows.net"
];

// The Power BI service configuration for GCC (L2) has AAD configured for Azure Commercial but ARM configured for Azure Government.
// PBI doesn't support cross cloud connections, so we'll override the config settings to use global cloud endpoints for ARM when
// the current environment is using global cloud AAD.
GetEndpointConfig = () as record =>
    if (Text.StartsWith(EnvironmentConfiguration[AzureActiveDirectory], GlobalCloudConfiguration[AzureActiveDirectory])) then
        GlobalCloudConfiguration
    else
        EnvironmentConfiguration;

AzureResourceGraph = [
    Type = "Singleton",
    MakeResourcePath = () => "AzureResourceGraph",
    ParseResourcePath = (dataSourcePath) => { },
    TestConnection = (dataSourcePath) => {"AzureResourceGraph.Query", "resources | limit 1"},
    Authentication = [
        Aad = [
            AuthorizationUri = Uri.Combine(GetEndpointConfig()[AzureActiveDirectory], "/common/oauth2/authorize"),
            Resource = GetEndpointConfig()[AzureResourceManagerResource]
        ]
    ],
    Label = "Azure Resource Graph"
];

// Data Source UI publishing description
AzureResourceGraph.Publish = [
    Beta = false,
    Category = "Azure",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    SourceImage = AzureResourceGraph.Icons,
    SourceTypeImage = AzureResourceGraph.Icons
];

AzureResourceGraph.Icons = [
    Icon16 = { Extension.Contents("AzureResourceGraph16.png"), Extension.Contents("AzureResourceGraph20.png"), Extension.Contents("AzureResourceGraph24.png"), Extension.Contents("AzureResourceGraph32.png") },
    Icon32 = { Extension.Contents("AzureResourceGraph32.png"), Extension.Contents("AzureResourceGraph40.png"), Extension.Contents("AzureResourceGraph48.png"), Extension.Contents("AzureResourceGraph64.png") }
];

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