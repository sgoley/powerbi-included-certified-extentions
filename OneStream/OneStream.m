[Version = "1.0.1"]
section OneStream;


//----------------------------------------------------------------------//
//------------------------------ Constants -----------------------------//
//----------------------------------------------------------------------//
ClientId        = "onestream.powerbi";
Scope           = "onestream.powerbi offline_access";
RedirectUri     = "https://oauth.powerbi.com/views/oauthredirect.html";
Base            = "OneStreamAPI/api/";
AuthorizeUri    = "OneStreamIS/connect/authorize";
TokenUri        = "OneStreamIS/connect/token";

// OneStream Endpoints
LogonUri                = Base & "Authentication/Logon";
OpenApplicationUri      = Base & "Application/OpenApplication";
GetCubeListUri          = Base & "Analytics/GetCubeList";
GetDataCellsFromCubeUri = Base & "Analytics/GetDataCellsFromCube";
GetDimensionDataUri     = Base & "Analytics/GetDimensionHierarchy";
GetMemberPropertiesUri  = Base & "Analytics/GetMemberPropertiesForDimension";
GetDataAdapterUri       = Base & "Analytics/GetDataAdapter";
GetDataRequest          = Base & "Analytics/GetDataRequest"; 

// Other constants
StatusCompleted = "Completed";
WindowHeight    = 800;
WindowWidth     = 500;
ApiVersion      = "7.2.0";

// Initial user display captions and placeholders
EnvironmentCaption      = "Environment URL. Must start with https://";
EnvironmentDescription  = "The address of your OneStream environment";
EnvironmentSampleValues = {"https://customer.onestreamcloud.com"};


//----------------------------------------------------------------//
//-------------------------- Navigation --------------------------//
//----------------------------------------------------------------//
[DataSource.Kind="OneStream", Publish="OneStream.Publish"]
shared OneStream.Navigation = Value.ReplaceType(OneStreamNavigationImpl, OneStreamNavigationType);
OneStreamNavigationType = type function (
    OneStreamURL as (Uri.Type meta [
        Documentation.FieldCaption = EnvironmentCaption,
        Documentation.FieldDescription = EnvironmentDescription,
        Documentation.SampleValues = EnvironmentSampleValues
    ])
    )
    as any meta [
        Documentation.Name = "OneStream Connector Configuration"
    ];
OneStreamNavigationImpl = (baseUrl as text) =>
   let
        params = [BaseWebServerUrl=baseUrl],
        sessionInfoBody = GetWebContentData(LogonUri, params, baseUrl, [#"api-version" = ApiVersion]),
        xfBytes = sessionInfoBody[Logon SessionInfo] ,
        message = sessionInfoBody[Message],
        authorizedApplications = List.Transform (sessionInfoBody[Authorized applications], each _),
        list = List.Transform(authorizedApplications, 
                each {_, _, 
                    CreateFirstLevelNav(_, OpenApplications(_ , xfBytes, baseUrl), baseUrl), 
                    "Database", "Database", false
                }
        ),

        objects = #table(
                {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
                list
        ),
        navTable = Table.ToNavigationTable(objects, {}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in 
        navTable;

OneStream.GetCubes = Value.ReplaceType(GetCubesImpl, GetCubesType);
GetCubesType = type function (
        SelectedApplication as (type text meta [
            Documentation.FieldCaption = "Selected Application",
            Documentation.FieldDescription = "Selected Application",
            Documentation.SampleValues = {"GolfStream"}
        ]),
        SessionInfoBody as (type text meta [
            Documentation.FieldCaption = "Session Info",
            Documentation.FieldDescription = "SessionInfo encoded (XFBytes)",
            Documentation.SampleValues = {""}
        ]),
        BaseUrl as (type text meta [
            Documentation.FieldCaption = EnvironmentCaption,
            Documentation.FieldDescription = EnvironmentDescription,
            Documentation.SampleValues = EnvironmentSampleValues
        ])
    )
    as list meta [
        Documentation.Name ="Get Cubes",
        Documentation.LongDescription = "This function gets the list of cubes in the selected application"
    ];
GetCubesImpl = (selectedApplication as text, sessionInfoBody as text,baseUrl as text) =>
    let
        params = [
            IsSystemLevel="False",
            SI = [XfBytes = sessionInfoBody]
        ]
    in
       GetWebContentData(GetCubeListUri, params, baseUrl, [#"api-version" = ApiVersion]);

OneStream.GetMetadataDetails = Value.ReplaceType(GetMetadataDetailsImpl, GetMetadataDetailsType);
GetMetadataDetailsType = type function (
        Url as (type text meta [
            Documentation.FieldCaption = EnvironmentCaption,
            Documentation.FieldDescription = EnvironmentDescription,
            Documentation.SampleValues = EnvironmentSampleValues
        ]),
        Application as (type text meta [
            Documentation.FieldCaption = "OneStream Application",
            Documentation.FieldDescription = "OneStream Application",
            Documentation.SampleValues = {"GolfStream"}
        ]),
        SessionInfoBody as (type text meta [
            Documentation.FieldCaption = "sessionInfoBody",
            Documentation.FieldDescription = "sessionInfoBody",
            Documentation.SampleValues = {""}
        ]),
        Cube as (type text meta [
            Documentation.FieldCaption = "OneStream Cube",
            Documentation.FieldDescription = "OneStream Cube",
            Documentation.SampleValues = {"GolfStream"}
        ]),
        BaseUrl as (type text meta [
            Documentation.FieldCaption = EnvironmentCaption,
            Documentation.FieldDescription = EnvironmentDescription,
            Documentation.SampleValues = EnvironmentSampleValues
        ]),
        DimensionType as (type text meta [
            Documentation.FieldCaption = "Dimension Type",
            Documentation.FieldDescription = "Dimension Type",
            Documentation.SampleValues = {"e.g. Entity"}
        ]),
        IncludeDescriptions as (type text meta [
            Documentation.FieldCaption = "Include Descriptions",
            Documentation.FieldDescription = "Include Descriptions",
            Documentation.SampleValues = {"e.g. True"}
        ]),
        ScenarioType as (type text meta [
            Documentation.FieldCaption = "Scenario Type",
            Documentation.FieldDescription = "Scenario Type",
            Documentation.SampleValues = {"e.g. All"}
        ]) 
    )
    as list meta [
            Documentation.Name ="Get Metadata",
            Documentation.LongDescription = "This function gets the Metadata for the selected scenario"
        ];
GetMetadataDetailsImpl = (url as text,application as text, sessionInfoBody as text, cube as text, baseUrl as text, DimensionType as text, IncludeDescriptions as text, ScenarioType as text) => 
     let
         params = [
             DimensionType = DimensionType,
             IncludeDescriptions = IncludeDescriptions,
             ScenarioType = ScenarioType,
             CubeName = cube,
             SI = [XfBytes = sessionInfoBody]
         ],
         data = GetRefinedData(url,sessionInfoBody,baseUrl,params)
     in 
         ExpandCells(data);

OneStream.GetCubeData = Value.ReplaceType(GetCubeDataImpl, GetCubeDataType);
GetCubeDataType = type function (
        Application as (type text meta [
            Documentation.FieldCaption = "OneStream Application",
            Documentation.FieldDescription = "OneStream Application",
            Documentation.SampleValues = {"OneStream Production"}
        ]),
        SessionInfoBody as (type text meta [
            Documentation.FieldCaption = "sessionInfoBody",
            Documentation.FieldDescription = "sessionInfoBody",
            Documentation.SampleValues = {""}
        ]),
        Cube as (type text meta [
            Documentation.FieldCaption = "OneStream Cube",
            Documentation.FieldDescription = "OneStream Cube",
            Documentation.SampleValues = {"GolfStream"}
        ]),
        BaseUrl as (type text meta [
            Documentation.FieldCaption = EnvironmentCaption,
            Documentation.FieldDescription = EnvironmentDescription,
            Documentation.SampleValues = EnvironmentSampleValues
        ]),
        Scenario as (type text meta [
            Documentation.FieldCaption = "Scenario",
            Documentation.FieldDescription = "Scenario",
            Documentation.SampleValues = {"e.g. Actual"}
        ]),
        Time as (type text meta [
            Documentation.FieldCaption = "Time",
            Documentation.FieldDescription = "Time",
            Documentation.SampleValues = {"e.g. 2023.base"}
        ]),
        Entity as (type text meta [
            Documentation.FieldCaption = "Entity",
            Documentation.FieldDescription = "Entity",
            Documentation.SampleValues = {"e.g. TotCorp.DescendantsInclusive"}
        ]),
        View as (type text meta [
            Documentation.FieldCaption = "View",
            Documentation.FieldDescription = "View",
            Documentation.SampleValues = {"e.g. Periodic"}
        ]),
        Currency as (type text meta [
            Documentation.FieldCaption = "Currency/Consolidation",
            Documentation.FieldDescription = "Currency/Consolidation",
            Documentation.SampleValues = {"Blank = Local"}
        ]),
        Account as (type text meta [
            Documentation.FieldCaption = "Account",
            Documentation.FieldDescription = "Account",
            Documentation.SampleValues = {"Blank = None"}
        ]),
        Flow as (type text meta [
            Documentation.FieldCaption = "Flow",
            Documentation.FieldDescription = "Flow",
            Documentation.SampleValues = {"Blank = None"}
        ]),
        Origin as (type text meta [
            Documentation.FieldCaption = "Origin",
            Documentation.FieldDescription = "Origin",
            Documentation.SampleValues = {"Blank = BeforeAdj"}
        ]),
        IC as (type text meta [
            Documentation.FieldCaption = "IC",
            Documentation.FieldDescription = "IC",
            Documentation.SampleValues = {"Blank = None"}
        ]),
        UD1 as (type text meta [
            Documentation.FieldCaption = "UD1",
            Documentation.FieldDescription = "UD1",
            Documentation.SampleValues = {"Blank = None"}
        ]),
        UD2 as (type text meta [
            Documentation.FieldCaption = "UD2",
            Documentation.FieldDescription = "UD2",
            Documentation.SampleValues = {"Blank = None"}
        ]),
        UD3 as (type text meta [
            Documentation.FieldCaption = "UD3",
            Documentation.FieldDescription = "UD3",
            Documentation.SampleValues = {"Blank = None"}
        ]),
        UD4 as (type text meta [
            Documentation.FieldCaption = "UD4",
            Documentation.FieldDescription = "UD4",
            Documentation.SampleValues = {"Blank = None"}
        ]),
        UD5 as (type text meta [
            Documentation.FieldCaption = "UD5",
            Documentation.FieldDescription = "UD5",
            Documentation.SampleValues = {"Blank = None"}
        ]),
        UD6 as (type text meta [
            Documentation.FieldCaption = "UD6",
            Documentation.FieldDescription = "UD6",
            Documentation.SampleValues = {"Blank = None"}
        ]),
        UD7 as (type text meta [
            Documentation.FieldCaption = "UD7",
            Documentation.FieldDescription = "UD7",
            Documentation.SampleValues = {"Blank = None"}
        ]),
        UD8 as (type text meta [
            Documentation.FieldCaption = "UD8",
            Documentation.FieldDescription = "UD8",
            Documentation.SampleValues = {"Blank = None"}
        ]),
        IncludeDescriptions as (type text meta [
            Documentation.FieldCaption = "Include Descriptions",
            Documentation.FieldDescription = "Include Descriptions of member.",
            Documentation.SampleValues = {"Blank = False"}
        ])
  ) as list meta[
            Documentation.Name ="Get Cube Data",
            Documentation.LongDescription = "This function lets you set query filters for selected application and selected cube"
        ];
GetCubeDataImpl = (application as text, sessionInfoBody as text,  cube as text,baseUrl as text, scenario as text,
                    timeFilter as text, entity as text, view as text, currency as text,  account as text, flow as text, 
                    origin as text, ic as text, ud1 as text, ud2 as text, ud3 as text, ud4 as text, ud5 as text, 
                    ud6 as text, ud7 as text, ud8 as text, includeDescriptions as text) =>
    let
        params = [
            IncludeDescriptions = includeDescriptions,
            CubeName = cube,
            SI = [XfBytes = sessionInfoBody],
            DataCellsFilter=[
                #"Scenario" = scenario,
                #"Currency" = currency,
                #"View" = view,
                #"TimeFilter" = timeFilter, 
                #"EntityFilter" = entity,
                #"OriginFilter" = origin,
                #"AccountFilter" = account,
                #"FlowFilter" = flow,
                #"ICFIlter" = ic,
                #"UD1Filter" = ud1,
                #"UD2Filter" = ud2,
                #"UD3Filter" = ud3,
                #"UD4Filter" = ud4,
                #"UD5Filter" = ud5,
                #"UD6Filter" = ud6,
                #"UD7Filter" = ud7,
                #"UD8Filter" = ud8
            ]
        ],
        data = GetRefinedData(GetDataCellsFromCubeUri,sessionInfoBody,baseUrl,params),
        // For GetCubeData we can apply a fixed transformation as the columns returned are fixed.
        #"Expanded Records" = 
            if Text.Lower(includeDescriptions) <> "true" // To cover for input mistakes anything that's not true will return without descriptions.
            then Table.ExpandRecordColumn(data, "Column1",
                {"Entity", "Consolidation", "Scenario", "Time","Time_StartDate", "Time_EndDate",
                "View", "Account", "Flow", "Origin", "IC", "UD1", "UD2", "UD3", "UD4", "UD5", "UD6", "UD7", "UD8", "CellValue"},
                {"Entity", "Consolidation", "Scenario", "Time","Time_StartDate", "Time_EndDate",
                "View", "Account", "Flow", "Origin", "IC", "UD1", "UD2", "UD3", "UD4", "UD5", "UD6", "UD7", "UD8", "CellValue"})
            else Table.ExpandRecordColumn(data, "Column1", 
                {"Entity", "Entity_Desc", "Consolidation", "Consolidation_Desc", "Scenario", "Scenario_Desc", "Time","Time_StartDate", "Time_EndDate", "Time_Desc",
                "View", "Account", "Account_Desc", "Flow", "Flow_Desc", "Origin", "IC", "IC_Desc", "UD1", "UD1_Desc","UD2", "UD2_Desc", "UD3", "UD3_Desc",
                "UD4", "UD4_Desc", "UD5", "UD5_Desc", "UD6", "UD6_Desc", "UD7", "UD7_Desc", "UD8", "UD8_Desc", "CellValue"},
                {"Entity", "Entity_Desc", "Consolidation", "Consolidation_Desc", "Scenario", "Scenario_Desc", "Time","Time_StartDate", "Time_EndDate", "Time_Desc",
                "View", "Account", "Account_Desc", "Flow", "Flow_Desc", "Origin", "IC", "IC_Desc", "UD1", "UD1_Desc","UD2", "UD2_Desc", "UD3", "UD3_Desc",
                "UD4", "UD4_Desc", "UD5", "UD5_Desc", "UD6", "UD6_Desc", "UD7", "UD7_Desc", "UD8", "UD8_Desc", "CellValue"}),
                
        #"Changed Type" = 
            if Text.Lower(includeDescriptions) <> "true"
            then Table.TransformColumnTypes(#"Expanded Records",
            {
                {"Entity", type text}, {"Consolidation", type text}, {"Scenario", type text}, {"Time", type text}, 
                {"Time_StartDate", type datetime}, {"Time_EndDate", type datetime}, {"View", type text}, {"Account", type text},
                {"Flow", type text}, {"Origin", type text}, {"IC", type text}, {"UD1", type text},
                {"UD2", type text}, {"UD3", type text}, {"UD4", type text}, {"UD5", type text},
                {"UD6", type text}, {"UD7", type text}, {"UD8", type text}, {"CellValue", type number}
            })
            else Table.TransformColumnTypes(#"Expanded Records",
            {
                {"Entity", type text}, {"Entity_Desc", type text}, {"Consolidation", type text}, {"Consolidation_Desc", type text}, {"Scenario", type text}, {"Scenario_Desc", type text},
                {"Time", type text}, {"Time_StartDate", type datetime}, {"Time_EndDate", type datetime}, {"Time_Desc", type text}, {"View", type text},
                {"Account", type text},  {"Account_Desc", type text}, {"Flow", type text}, {"Flow_Desc", type text}, {"Origin", type text}, {"IC", type text}, {"IC_Desc", type text},
                {"UD1", type text}, {"UD1_Desc", type text}, {"UD2", type text}, {"UD2_Desc", type text}, {"UD3", type text}, {"UD3_Desc", type text},
                {"UD4", type text}, {"UD4_Desc", type text}, {"UD5", type text}, {"UD5_Desc", type text}, {"UD6", type text}, {"UD6_Desc", type text}, 
                {"UD7", type text}, {"UD7_Desc", type text}, {"UD8", type text}, {"UD8_Desc", type text}, {"CellValue", type number}
            })
     in
       #"Changed Type";

OneStream.GetDataAdapterData = Value.ReplaceType(GetDataAdapterDataImpl, GetDataAdapterDataType);
GetDataAdapterDataType = type function (
    sessionInfoBody as (type text meta [
         Documentation.FieldCaption = "SessionInfoBody",
         Documentation.FieldDescription = "SessionInfoBody",
         Documentation.SampleValues = {""}
    ]),
    baseUrl as (type text meta [
        Documentation.FieldCaption = EnvironmentCaption,
        Documentation.FieldDescription = EnvironmentDescription,
        Documentation.SampleValues = EnvironmentSampleValues
    ]),
    AdapterName as (type text meta [
        Documentation.FieldCaption = "Adapter Name",
        Documentation.FieldDescription = "Adapter Name",
        Documentation.SampleValues = {"e.g. da_YourDataAdapter"}
    ]),
    WorkspaceName as (type text meta [
        Documentation.FieldCaption = "Workspace Name",
        Documentation.FieldDescription = "Workspace Name",
        Documentation.SampleValues = {"e.g. Default"}
    ]),
    ResultDataTableName as (type text meta [
        Documentation.FieldCaption = "Result Data Table Name",
        Documentation.FieldDescription = "Result Data Table Name",
        Documentation.SampleValues = {"e.g. Table"}
    ]),
    CustomSubstVarsAsCommaSeparatedPairs as (type text meta [
        Documentation.FieldCaption = "Custom Subst Vars As Comma Separated Pairs",
        Documentation.FieldDescription = "Custom Subst Vars As Comma Separated Pairs",
        Documentation.SampleValues = {"e.g. param_currency=EUR,param_entity=CORP"}
    ]) 
    ) as list meta[
        Documentation.Name ="Get Data Adapter",
        Documentation.LongDescription = "This function retrieves a Data Adapter from a Workspace. "
    ];
GetDataAdapterDataImpl = (sessionInfoBody as text, baseUrl as text, AdapterName as text, WorkspaceName as text, ResultDataTableName as text, CustomSubstVarsAsCommaSeparatedPairs as text) =>
    let
       params = [
            AdapterName= AdapterName,
            SI = [ XfBytes = sessionInfoBody ],
            IsSystemLevel="False", 
            WorkspaceName=WorkspaceName,
            ResultDataTableName=ResultDataTableName,
            CustomSubstVarsAsCommaSeparatedPairs=CustomSubstVarsAsCommaSeparatedPairs
           ],
     data = GetRefinedData(GetDataAdapterUri,sessionInfoBody,baseUrl,params)
    in
      ExpandCells(data);


//----------------------------------------------------------------------//
//----------------------------- Navigation -----------------------------//
//----------------------------------------------------------------------//

// First level of Navigation
CreateFirstLevelNav = (application as text, sessionInfoBody as text, baseUrl as text) as table =>
    let
        cubes = OneStream.GetCubes(application, sessionInfoBody, baseUrl),
        list = List.Transform (cubes, 
                              each {_, _, 
                              CreateSecondLevelNav(application, sessionInfoBody, _, baseUrl), 
                              "Folder", "Folder", false}),

        objects = #table(
                {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
                list
            ),
        navTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

// Second level of Navigation
CreateSecondLevelNav = (application as text, sessionInfoBody as text, cube as text, baseUrl as text) as table =>
    let
        objects = #table(
            {"Name",  "Key","Data", "ItemKind", "ItemName", "IsLeaf"},{
            {"Get Dimension", "Get Dimension",  SetMetadataFilters(GetDimensionDataUri, application, sessionInfoBody, cube, baseUrl),"Function", "Function", true},
            {"Get Member Properties", "Get Member Properties", SetMetadataFilters(GetMemberPropertiesUri, application, sessionInfoBody, cube, baseUrl) ,"Function", "Function", true},
            {"Get Cube Data", "Get Data", SetCubeDataFilters(application, sessionInfoBody, cube, baseUrl), "Function", "Function", true},
            {"Get Custom Adapter Data", "Get Custom Adapter", SetDataAdapterFilters(application, cube, sessionInfoBody,baseUrl),"Function", "Function", true}
        }),
        NavTable = Table.ToForceNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

// Open Application: retrieve the SessionInfo for the specified application to apply OneStream internal security.
OpenApplications = (applicationName as text, sessionInfoObject, baseUrl as text) =>
    let
        params = [
            ApplicationName = applicationName,
            // In previous version of 8.1 the property was lowercase. Check both.
            SI = try [XfBytes = sessionInfoObject[XfBytes]] otherwise [XfBytes = sessionInfoObject[xfBytes]]
             ],
        jsonContent = GetWebContentData(OpenApplicationUri, params, baseUrl, [#"api-version"=ApiVersion]),
        sessioInfoBytes = Record.Field( jsonContent[Application SessionInfo], "XfBytes")
    in
        sessioInfoBytes;

// Set Metadata Filters (For Dimension Hierarchy and Member Properties)
SetMetadataFilters = (url as text,application as text, sessionInfoBody as text, cube as text, baseUrl as text)  =>
       let
           getMetadataList = Value.ReplaceType(GetMetadataImpl, GetMetadataType),

           GetMetadataType = type function (
                DimensionType as (type text meta [
                    Documentation.FieldCaption = "Dimension Type",
                    Documentation.FieldDescription = "Dimension Type",
                    Documentation.SampleValues = {"e.g. Entity"}
                ]),
                IncludeDescriptions as (type text meta [
                    Documentation.FieldCaption = "Include Descriptions",
                    Documentation.FieldDescription = "Include Descriptions",
                    Documentation.SampleValues = {"e.g. True"}
                ]),
                ScenarioType as (type text meta [
                    Documentation.FieldCaption = "Scenario Type",
                    Documentation.FieldDescription = "Scenario Type",
                    Documentation.SampleValues = {"e.g. All"}
                ])  
                ) as list meta[
                    Documentation.Name ="Get Metadata or Member properties",
                    Documentation.LongDescription = "This function lets you set Medatata filters for selected application [" & application &"] and selected cube [" & cube &"]"
                ],


            GetMetadataImpl = (DimensionType as text, IncludeDescriptions as text, ScenarioType as text) => 
              Function.Invoke(OneStream.GetMetadataDetails, {url,application,sessionInfoBody,cube,baseUrl,DimensionType,IncludeDescriptions,ScenarioType})
in
    getMetadataList;

// Set Data Adapter Filters
SetDataAdapterFilters = (application as text, cube as text, sessionInfoBody as text, baseUrl as text)  =>
       let
           getDataAdapterList = Value.ReplaceType(GetDataAdapterImpl, GetDataAdapterType),

           GetDataAdapterType = type function (
                AdapterName as (type text meta [
                    Documentation.FieldCaption = "Adapter Name",
                    Documentation.FieldDescription = "Adapter Name",
                    Documentation.SampleValues = {"e.g. da_MyAdapter"}
                ]),
                WorkspaceName as (type text meta [
                    Documentation.FieldCaption = "Workspace Name",
                    Documentation.FieldDescription = "Workspace Name",
                    Documentation.SampleValues = {"e.g. Default"}
                ]),
                optional ResultDataTableName as (type text meta [
                    Documentation.FieldCaption = "Result Data Table Name",
                    Documentation.FieldDescription = "Result Data Table Name",
                    Documentation.SampleValues = {"e.g. Table"}
                ]),
                optional CustomSubstVarsAsCommaSeparatedPairs as (type text meta [
                    Documentation.FieldCaption = "Custom Subst Vars As Comma Separated Pairs",
                    Documentation.FieldDescription = "Custom Subst Vars As Comma Separated Pairs",
                    Documentation.SampleValues = {"e.g. param_currency=EUR,param_store_parent=Store"}
                ]) 
            ) as list meta [
                    Documentation.Name ="Get Data Adapter",
                    Documentation.LongDescription = "This function retrieves data from a Workspace Data Adapter in selected application [" & application &"] and selected cube [" & cube &"]"
                ],

            GetDataAdapterImpl = (AdapterName as text, WorkspaceName as text,optional ResultDataTableName as text,optional CustomSubstVarsAsCommaSeparatedPairs as text) => 
             let
                    _ResultDataTableName = if (ResultDataTableName <> null) then ResultDataTableName else "None",
                    _CustomSubstVarsAsCommaSeparatedPairs = if (CustomSubstVarsAsCommaSeparatedPairs <> null) then CustomSubstVarsAsCommaSeparatedPairs else "None"
             in
              Function.Invoke(OneStream.GetDataAdapterData, {sessionInfoBody, baseUrl, AdapterName, WorkspaceName, _ResultDataTableName, _CustomSubstVarsAsCommaSeparatedPairs})
in
    getDataAdapterList;

// Set Cube Data Filters
SetCubeDataFilters = (application as text, sessionInfoBody as text, cube as text, baseUrl as text) =>
    let
        cubeDataFiltersList = Value.ReplaceType(GetCubeDataFiltersImpl, GetCubeDataFiltersType),

        GetCubeDataFiltersType = type function (
            Scenario as (type text meta [
                Documentation.FieldCaption = "Scenario",
                Documentation.FieldDescription = "Scenario",
                Documentation.SampleValues = {"e.g. Actual"}
            ]),
            Time as (type text meta [
                Documentation.FieldCaption = "Time",
                Documentation.FieldDescription = "Time",
                Documentation.SampleValues = {"e.g. 2021.base"}
            ]),
            Entity as (type text meta [
                Documentation.FieldCaption = "Entity",
                Documentation.FieldDescription = "Entity",
                Documentation.SampleValues = {"e.g. TotCorp.DescendantsInclusive"}
            ]),
            View as (type text meta [
                Documentation.FieldCaption = "View",
                Documentation.FieldDescription = "View",
                Documentation.SampleValues = {"e.g. Periodic"}
            ]),
            Currency as (type text meta [
                Documentation.FieldCaption = "Currency/Consolidation",
                Documentation.FieldDescription = "Currency/Consolidation",
                Documentation.SampleValues = {"Blank = Local"}
            ]),
            Account as (type text meta [
                Documentation.FieldCaption = "Account",
                Documentation.FieldDescription = "Account",
                Documentation.SampleValues = {"Blank = None"}
            ]),
            Flow as (type text meta [
                Documentation.FieldCaption = "Flow",
                Documentation.FieldDescription = "Flow",
                Documentation.SampleValues = {"Blank = None"}
            ]),
            Origin as (type text meta [
                Documentation.FieldCaption = "Origin",
                Documentation.FieldDescription = "Origin",
                Documentation.SampleValues = {"Blank = BeforeAdj"}
            ]),
            IC as (type text meta [
                Documentation.FieldCaption = "IC",
                Documentation.FieldDescription = "IC",
                Documentation.SampleValues = {"Blank = None"}
            ]),
            UD1 as (type text meta [
                Documentation.FieldCaption = "UD1",
                Documentation.FieldDescription = "UD1",
                Documentation.SampleValues = {"Blank = None"}
            ]),
            UD2 as (type text meta [
                Documentation.FieldCaption = "UD2",
                Documentation.FieldDescription = "UD2",
                Documentation.SampleValues = {"Blank = None"}
            ]),
            UD3 as (type text meta [
                Documentation.FieldCaption = "UD3",
                Documentation.FieldDescription = "UD3",
                Documentation.SampleValues = {"Blank = None"}
            ]),
            UD4 as (type text meta [
                Documentation.FieldCaption = "UD4",
                Documentation.FieldDescription = "UD4",
                Documentation.SampleValues = {"Blank = None"}
            ]),
            UD5 as (type text meta [
                Documentation.FieldCaption = "UD5",
                Documentation.FieldDescription = "UD5",
                Documentation.SampleValues = {"Blank = None"}
            ]),
            UD6 as (type text meta [
                Documentation.FieldCaption = "UD6",
                Documentation.FieldDescription = "UD6",
                Documentation.SampleValues = {"Blank = None"}
            ]),
            UD7 as (type text meta [
                Documentation.FieldCaption = "UD7",
                Documentation.FieldDescription = "UD7",
                Documentation.SampleValues = {"Blank = None"}
            ]),
            UD8 as (type text meta [
                Documentation.FieldCaption = "UD8",
                Documentation.FieldDescription = "UD8",
                Documentation.SampleValues = {"Blank = None"}
            ]),
            optional IncludeDescriptions as (type text meta [
                    Documentation.FieldCaption = "Include Descriptions",
                    Documentation.FieldDescription = "Include Descriptions",
                    Documentation.SampleValues = {"Blank = False"}
            ])

        ) as list meta [
            Documentation.Name ="Set filters",
            Documentation.LongDescription = "This function lets you set query filters for GetCubeData function in selected application [" & application &"] and selected cube [" & cube &"]"
        ],

        GetCubeDataFiltersImpl =  (Scenario as text, Time as text, Entity as text, View as text, Currency as text, Account as text, Flow as text, Origin as text, IC as text, UD1 as text, UD2 as text, UD3 as text, UD4 as text, UD5 as text, UD6 as text, UD7 as text, UD8 as text, optional IncludeDescriptions as text) =>
            let
                    _Currency = if (Currency <> null) then Currency else "Local",
                    _View = if (View<> null) then View else "Periodic",
                    _Account = if (Account <> null) then Account else "None",
                    _Flow = if (Flow <> null) then Flow else "None",
                    _Origin = if (Origin <> null) then Origin else "Top",
                    _IC = if (IC <> null) then IC else "None",
                    _UD1 = if (UD1 <> null) then UD1 else "None",
                    _UD2 = if (UD2 <> null) then UD2 else "None",
                    _UD3 = if (UD3 <> null) then UD3 else "None",
                    _UD4 = if (UD4 <> null) then UD4 else "None",
                    _UD5 = if (UD5 <> null) then UD5 else "None",
                    _UD6 = if (UD6 <> null) then UD6 else "None",
                    _UD7 = if (UD7 <> null) then UD7 else "None",
                    _UD8 = if (UD8 <> null) then UD8 else "None",
                    _IncludeDescriptions = if (IncludeDescriptions <> null) then IncludeDescriptions else "False",
                    data = Function.Invoke(OneStream.GetCubeData, {application, sessionInfoBody, cube, baseUrl, Scenario, Time, Entity,_View,_Currency, _Account, _Flow, _Origin, _IC, _UD1, _UD2, _UD3, _UD4, _UD5, _UD6, _UD7, _UD8, _IncludeDescriptions})
            in data

in cubeDataFiltersList;

// Navigation Tables
Table.ToForceNavigationTable = (
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
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

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

//----------------------------------------------------------------------//
//--------------------------- Data Retrieval ---------------------------//
//----------------------------------------------------------------------//

// Function to check and perform paging operation if needed.
GetRefinedData = (url as text, sessionInfoBody as text, baseUrl as text, params) =>
    let 
        jsonContent = GetWebContentData(url, params, baseUrl, [#"api-version"=ApiVersion]),

        result = 
            if (jsonContent[Status] = StatusCompleted) 
            then jsonContent 
            else WaitAndCallDataRequest(sessionInfoBody, jsonContent[RequestId], baseUrl, false, 1),

        data = 
            if (result[TotalPages] = 1) 
            then GetTableFromFirstCallResults(result[DataResult]) 
            else LoopAndGetData(sessionInfoBody, result, baseUrl, result[TotalPages])
    in 
         data;

// Table conversion when no paging required
GetTableFromFirstCallResults = (result) => 
    let
       table =  Table.FromList(result, Splitter.SplitByNothing(), null, null, ExtraValues.Error)
    in
       table;

// Paging operation
LoopAndGetData = (sessionInfoBody, OSGetJson, baseUrl, count) => 
    let
        pageList = List.Numbers(1, count, 1), 
        toTableOfPages = Table.FromList(pageList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        changeName = Table.RenameColumns(toTableOfPages,{{"Column1", "rows"}}),
        addToPage = Table.AddColumn(changeName, "Column1", 
                        each 
                            if ([rows] = 1) 
                            then  OSGetJson[DataResult] 
                            else WaitAndCallDataRequest(sessionInfoBody, OSGetJson[RequestId], baseUrl,true,[rows])
                    ),

        #"Removed Columns" = 
            if(Table.HasColumns(addToPage,{"rows"}))
            then Table.RemoveColumns(addToPage,{"rows"}) 
            else addToPage,

        #"Expanded Table" = Table.ExpandListColumn(#"Removed Columns", "Column1")
    in 
       #"Expanded Table";

// Helper function for expension of Records
ExpandCells = (table) =>
    let
        Column1 = table{0}[Column1],
        colNames = Record.ToTable(Column1)[Name],
        Expanded = Table.ExpandRecordColumn(table, "Column1", colNames)

    in
        Expanded;

// Retry for data processing (7 times)
WaitAndCallDataRequest = (sessionInfoBody as text,  requestId as text, baseUrl as text, getDataResult as logical, optional pageNumber as number) => 
    let
        params = [
            IsSystemLevel = "False",
            RequestId = requestId,
            SI = [XfBytes = sessionInfoBody]
        ], 
        query = [#"api-version" = ApiVersion, #"page" = Text.From(pageNumber)],
        try1 = if getDataResult then GetWebContentData(GetDataRequest, params, baseUrl, query) else Function.InvokeAfter(() => GetWebContentData(GetDataRequest, params, baseUrl, query), #duration(0,0,0,5)),
        try2 = if (try1[Status] = StatusCompleted) then try1 else Function.InvokeAfter(() => GetWebContentData(GetDataRequest, params, baseUrl, query), #duration(0,0,0,5)),
        try3 = if (try2[Status] = StatusCompleted) then try2 else Function.InvokeAfter(() => GetWebContentData(GetDataRequest, params, baseUrl, query), #duration(0,0,0,10)),
        try4 = if (try3[Status] = StatusCompleted) then try3 else Function.InvokeAfter(() => GetWebContentData(GetDataRequest, params, baseUrl, query), #duration(0,0,0,10)),
        try5 = if (try4[Status] = StatusCompleted) then try4 else Function.InvokeAfter(() => GetWebContentData(GetDataRequest, params, baseUrl, query), #duration(0,0,0,30)),
        try6 = if (try5[Status] = StatusCompleted) then try5 else Function.InvokeAfter(() => GetWebContentData(GetDataRequest, params, baseUrl, query), #duration(0,0,0,30)),
        try7 = if (try6[Status] = StatusCompleted) then try6 else Function.InvokeAfter(() => GetWebContentData(GetDataRequest, params, baseUrl, query), #duration(0,0,0,30)),
        result = if (try7[Status] = StatusCompleted) then try7 else error Error.Record("Timeout", "Request: " & requestId & " has timed out. Please reduce the size of the request.")   
    in
        if getDataResult then result[DataResult] else result;

// Helper function for web call
GetWebContentData = (url as text, params, baseUrl as text, query) => 
     let
        errorCodes = {500,400},
        jsonContent = Json.FromValue(params),
        b64Content = Binary.ToText(jsonContent, BinaryEncoding.Base64),
        response = Web.Contents(baseUrl, [
            RelativePath = url,
            Query = query,
            IsRetry = true,
            ManualStatusHandling = errorCodes,
            Headers =
                [
                    #"Content-Type" = "application/json", 
                    #"Accept" = "application/json",
                    #"X-OS-PBI" = "true",           // Identification Header so we know this specific call comes from PowerBI.
                    #"Cache-Control" = "no-cache",
                    #"CacheGuid" = b64Content  // the B64-encoded request is used to prevent PowerBI from returning a cached error result for different request on same endpoint.
                ], 
            Content = jsonContent
        ]),
        responseCode = Value.Metadata(response)[Response.Status],
        body = Json.Document(response),

        bodyOrError500 = 
            if (responseCode = 500) 
            then error Error.Record("Invalid Request", body[Detail]) 
            else body,

        bodyOrError400 = 
            if (responseCode = 400) 
            then error Error.Record("Invalid Request", "Invalid or missing parameters, please check your Connector function")
            else bodyOrError500
    in
        bodyOrError400;


//----------------------------------------------------------------------//
//--------------------------- Authentication ---------------------------//
//----------------------------------------------------------------------//
OneStream = [
    TestConnection = (dataSourcePath) => {"OneStream.Navigation", dataSourcePath},
    Authentication = [
        OAuth = [
             StartLogin = StartLogin,
             FinishLogin = FinishLogin,
             Refresh = Refresh
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

Base64UrlEncodeWithoutPadding = (hash as binary) as text =>
    let
        base64Encoded = Binary.ToText(hash, BinaryEncoding.Base64),
        base64UrlEncoded = Text.Replace(Text.Replace(base64Encoded, "+", "-"), "/", "_"),
        withoutPadding = Text.TrimEnd(base64UrlEncoded, "=")
    in 
        withoutPadding;

StartLogin = (resourceUrl, state, display) =>
    let
        // PKCE - generate using guids
        codeVerifier = Text.NewGuid() & Text.NewGuid(),
        codeChallenge = Base64UrlEncodeWithoutPadding(Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(codeVerifier, TextEncoding.Ascii))),
        authorizeUrl = Uri.Combine(resourceUrl, AuthorizeUri) & "?" & Uri.BuildQueryString([
            client_id = ClientId,
            response_type = "code",
            code_challenge_method = "S256",
            code_challenge = codeChallenge,
            state = state,
            scope = Scope,
            redirect_uri = RedirectUri])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = RedirectUri,
            WindowHeight = WindowHeight,
            WindowWidth = WindowWidth,
            Context = codeVerifier
        ];

FinishLogin = (clientApplication, resourceUrl, context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query],
        result = if (Record.HasFields(Parts, {"error", "error_description"})) then 
                    error Error.Record(Parts[error], Parts[error_description], Parts)
                 else
                     TokenMethod(Parts[code],"authorization_code",resourceUrl, context )
    in
       result;

TokenMethod = (code, grant_type, resourceUrl, optional verifier) =>
    let
        codeVerifier = if (verifier <> null) then [code_verifier = verifier] else [],
        codeParameter = if (grant_type = "authorization_code") then [code = code] else [refresh_token = code],
        query = codeVerifier & codeParameter & [
            client_id = ClientId,
            grant_type = grant_type,
            redirect_uri = RedirectUri
        ],
        ManualHandlingStatusCodes = {401,403},
        Response = Web.Contents(resourceUrl, [
            RelativePath = TokenUri,
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

Refresh = (ca, resourceUrl, oldCredentials) => TokenMethod(oldCredentials[refresh_token], "refresh_token", resourceUrl);


//----------------------------------------------------------------------//
//----------------------------- Publishing -----------------------------//
//----------------------------------------------------------------------//

// Data Source UI publishing description
OneStream.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://documentation.onestream.com/", 
    SourceImage = OneStream.Icons,
    SourceTypeImage = OneStream.Icons
];

OneStream.Icons = [
    Icon16 = { Extension.Contents("OneStream16.png"), Extension.Contents("OneStream20.png"), Extension.Contents("OneStream24.png"), Extension.Contents("OneStream32.png") },
    Icon32 = { Extension.Contents("OneStream32.png"), Extension.Contents("OneStream40.png"), Extension.Contents("OneStream48.png"), Extension.Contents("OneStream64.png") }
];
