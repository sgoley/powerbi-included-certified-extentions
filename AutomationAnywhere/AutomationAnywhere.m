// This file contains your Data Connector logic
[Version = "1.0.4"]
section AutomationAnywhere;

[DataSource.Kind="AutomationAnywhere", Publish="AutomationAnywhere.Publish"]
shared AutomationAnywhere.Feed  = Value.ReplaceType(AutomationAnywhereImpl, AutomationAnywhereType);

  //function to declare custom data types with metadata for parameters

  AutomationAnywhereType = type function (
    CRVersion as (type text meta [
        Documentation.FieldCaption = "Control Room Version",
        Documentation.FieldDescription = "Control room version, 10.x/11.x OR Automation 360.
        Automation 360 customers need not mention the BI host as Bot Insight is an integral part of Control Room",
        Documentation.AllowedValues = {Extension.LoadString("ElevenxVersion"), Extension.LoadString("A2019Version"), Extension.LoadString("ElevenThreeFiveOneVersion")}
    ]),
    CRHostName as (type text meta [
        Documentation.FieldCaption = "Control Room Host",
        Documentation.FieldDescription = "HostName/IpAddress of server where Control Room Service is running",
        Documentation.SampleValues = {"http://localhost", "https://www.example.com:80"}
    ]))

    as table meta [
        Documentation.Name = "Automation Anywhere - Login",
        Documentation.LongDescription = "Automation Anywhere - Login"
    ];


  // core function with connector logic
  AutomationAnywhereImpl = (CRVersion as text, CRHostName as text) =>
               let
                    // step1: Login to get the auth token

                    CRusername = Extension.CurrentCredential()[Username],

                    CRpassword = Extension.CurrentCredential()[Password],

                    body = Text.ToBinary("{""username"":"""& CRusername & """,""password"":"""& CRpassword & """}"),
                    options =   [
                                    Headers = [#"Content-type"="application/json"],
                                    Content = body
                                ],
                    // Build the authentication URL
                    AuthenticationUrl =
                                if CRVersion = Extension.LoadString("A2019Version")
                                    then CRHostName & "/v2/authentication"
                                else
                                    CRHostName & "/v1/authentication",
                    tokenResonse = Json.Document(Web.Contents(AuthenticationUrl, options)),

                    // step2: Set the access token as part of API request header with additional options

                    DefaultRequestHeader = [
                             #"X-Authorization" =  tokenResonse[token]  // assign the token value obtained from step1
                    ],
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
                                IncludeExtensions = true,

                                // set the header consisting of X-Auth token; which is generated from the login API
                                Headers = DefaultRequestHeader
                            ],

                    // step 3: Pull the latest swagger definition from the site

                    swagger =   if List.MatchesAny(tokenResonse[user][roles], each [name] = Extension.LoadString("SuperAdmin")) and CRVersion = Extension.LoadString("A2019Version")
                                    then Json.Document(Extension.Contents("swaggerA2019Admin.json"))
                                else if List.MatchesAny(tokenResonse[user][roles], each [name] = Extension.LoadString("SuperAdmin")) and CRVersion = Extension.LoadString("ElevenxVersion")
                                    then Json.Document(Extension.Contents(Extension.LoadString("SwaggerElevenAdmin")))
                                else if List.MatchesAny(tokenResonse[user][roles], each [name] = Extension.LoadString("SuperAdmin")) and CRVersion = Extension.LoadString("ElevenThreeFiveOneVersion")
                                    then Json.Document(Extension.Contents(Extension.LoadString("SwaggerElevenPatchAdmin")))
                                else if CRVersion = Extension.LoadString("A2019Version")
                                    then Json.Document(Extension.Contents(Extension.LoadString("A2019SwaggerFile")))
                                else if CRVersion = Extension.LoadString("ElevenThreeFiveOneVersion")
                                    then Json.Document(Extension.Contents(Extension.LoadString("ElevenPatchSwaggerFile")))
                                else
                                    Json.Document(Extension.Contents(Extension.LoadString("SwaggerFile"))),

                    biHostArray = Text.Split(CRHostName, Extension.LoadString("HostSplitterExpr")),

                    biScheme = List.First(biHostArray),
                    biHostName = List.Last(biHostArray),
                    swaggerRecord = Record.AddField(swagger, "host", biHostName),
                    schemes = {biScheme},
                    swaggerRecordWithScheme = Record.AddField(swaggerRecord, "schemes", schemes),

                    // OpenApi.Document will return a navigation table with list of API names and API functions
                    apiFunctionTable = OpenApi.Document
                                              (Binary.From
                                                     (Json.FromValue(swaggerRecordWithScheme)), DefaultOptions),

                    RoleBasedApiFunctionTable =
                                if List.MatchesAny(tokenResonse[user][roles], each [name] = Extension.LoadString("SuperAdmin"))
                                     then apiFunctionTable
                                else if List.MatchesAny(tokenResonse[user][roles], each [name] = Extension.LoadString("BotInsightCoeAdminRole"))
                                     then Record.ToTable(apiFunctionTable{1})   
                                else if List.MatchesAny(tokenResonse[user][roles], each [name] = Extension.LoadString("BotInsightAdminRole"))
                                     then Table.Skip(apiFunctionTable, 1)
                                else
                                     Extension.LoadString("AuthErrorMessage")
                in
                    RoleBasedApiFunctionTable;


// Data Source Kind description
AutomationAnywhere = [
    // Test Connection: Pass the User inputs of CR version and host name
    TestConnection = (dataSourcePath) => { 
        "AutomationAnywhere.Feed", 
        Json.Document(dataSourcePath)[CRVersion], 
        Json.Document(dataSourcePath)[CRHostName]
    },
    // Auth Type: BASIC -- Pass the username and password to generate auth token and validate the user
    Authentication = [
        // Key = [],
        UsernamePassword = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
AutomationAnywhere.Publish = [
    Beta = false,
    Category = "Online Services",
    ButtonText = { "Automation Anywhere", "Automation Anywhere" },
    LearnMoreUrl = "https://docs.automationanywhere.com/bundle/enterprise-v11.3/page/enterprise/topics/bot-insight/user/configuring-automation-anywhere-connector.html",
    SourceImage = AutomationAnywhere.Icons,
    SourceTypeImage = AutomationAnywhere.Icons
];

AutomationAnywhere.Icons = [
    Icon16 = { Extension.Contents("AutomationAnywhere16.png"), Extension.Contents("AutomationAnywhere20.png"), Extension.Contents("AutomationAnywhere24.png"), Extension.Contents("AutomationAnywhere32.png") },
    Icon32 = { Extension.Contents("AutomationAnywhere32.png"), Extension.Contents("AABotInsightV340.png"), Extension.Contents("AABotInsightV348.png"), Extension.Contents("AABotInsightV364.png") }
];

//
// Common functions - To Be utilized in the next version
//
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

