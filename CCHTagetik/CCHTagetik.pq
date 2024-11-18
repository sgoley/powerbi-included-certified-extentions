// This file contains CCH Tagetik Connector logic
[Version = "1.1.0"] //Version
section CCHTagetik;

// Data Source Kind description
CCHTagetik = [
    // TestConnection is required to enable the connector through the Gateway
    TestConnection = (dataSourcePath) => 
        let
            json = Json.Document(dataSourcePath),
            URL = json[URL],
            Database = json[Database]
        in
        { "CCHTagetik.Contents",URL, Database},
   
  Authentication =  [ 
        //Basic Authentication
        UsernamePassword = []
        ],
    Label = Extension.LoadString("DataSourceLabel")
    
];

// Data Source UI publishing description
CCHTagetik.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { Extension.LoadString("DataSourceLabel"),Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    
    LearnMoreUrl = "https://www.wolterskluwer.com/en/solutions/cch-tagetik",
    SourceImage = CCHTagetik.Icons,
    SourceTypeImage = CCHTagetik.Icons
];

CCHTagetik.Icons = [
    Icon16 = { Extension.Contents("CCHTagetik16.png"), Extension.Contents("CCHTagetik20.png"), Extension.Contents("CCHTagetik24.png"), Extension.Contents("CCHTagetik32.png") },
    Icon32 = { Extension.Contents("CCHTagetik32.png"), Extension.Contents("CCHTagetik40.png"), Extension.Contents("CCHTagetik48.png"), Extension.Contents("CCHTagetik64.png") }
];


//
// Implementation
// 
//1) Main Function
[DataSource.Kind="CCHTagetik", Publish="CCHTagetik.Publish"]
shared CCHTagetik.Contents = Value.ReplaceType(CCHTagetikNavTable, CCHTagetikType);

CCHTagetikType =  type function (
    URL as (type text meta [
        Documentation.FieldCaption = "URL",
        Documentation.FieldDescription = "Wolters Kluwer CCH Tagetik URL environment",
        Documentation.SampleValues = {"https:// tcpmabc.api.tagetik.com/ basic"}
    ]
    ),
    Database as (type text meta [
        Documentation.FieldCaption = "Database",
        Documentation.FieldDescription = "Wolters Kluwer CCH Tagetik Database environment",
        Documentation.SampleValues = {"TCPM_ABC_001"}
        //Documentation.AllowedValues = { 1, 2, 3 }
    ]),
    optional AW as (type text meta [
        Documentation.FieldCaption = "Analytical Workspace",
        Documentation.FieldDescription = "Analytical Workspace Code"//,
        //Documentation.SampleValues = {"TCPM_ABC_001"}
        //Documentation.AllowedValues = { 1, 2, 3 }
    ]),
    optional Dataset as (type text meta [
        Documentation.FieldCaption = "Analytical Workspace Dataset or Financial Model",
        Documentation.FieldDescription = "Analytical Workspace Dataset Code or Financial Model Code (1 or 2)"//,
        //Documentation.SampleValues = {""}
        //Documentation.AllowedValues = { 1, 2, 3 }
    ])
    )
    as table meta [
        Documentation.Name = "Wolters Kluwer CCH Tagetik",
        Documentation.LongDescription = "Wolters Kluwer CCH Tagetik"
    ];

  
//2) Create Nav Table: 2 options (Financial, AW)
CCHTagetikNavTable = (URL as text, Database as text,optional AW as text,optional Dataset as text) as table=> 
    let
        Model = if (AW ="" or AW is null) and Dataset <> null 
                            then Dataset else "1",
        output = if AW is null then CCHTagetikNavTableFinancial(URL,Database,Model) else CCHTagetikNavTableAIH(URL,Database,AW,Dataset)   
    in
        output;

//3) Create Financial Nav Table


CCHTagetikNavTableFinancial = (URL as text, Database as text, optional Model as text) as table=>   
    let
    //Create API URL
        CCHTagetik_AuthenticationType = if Text.EndsWith(URL,"/basic") or Text.EndsWith(URL,"/basic/") then "BASIC_API_GATEWAY" else "BASIC",
        outputURL = if CCHTagetik_AuthenticationType  =  "BASIC_API_GATEWAY" 
                        then URL & "/aih/data/v1/" & Database &"/PBI/"
                    else URL & "/api/aih/data/v1/" & Database &"/PBI/",
    //Get Version
       Output_Source_PBIConnectorVersion = 
        Table.View(null,
            [
                GetType = () =>
                    type table [
                        V = Text.Type
                    ],
                GetRows = () =>
                    let 
                        // Attempt to get data from the web source
                        Source_PBIConnectorVersion = try Json.Document(Web.Contents(outputURL & "Datasource_AWT009()", [Timeout=#duration(0,0,30,0)]))
                    in
                        // Handle potential errors from Web.Contents
                        if Source_PBIConnectorVersion[HasError] then 
                            #table(type table [V = Text.Type], {})
                        else 
                            let
                                // Convert to table and expand record column
                                #"PBIConnectorVersion Converted to Table" = Table.FromList(Source_PBIConnectorVersion[Value][value], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                                Output_Source_PBIConnectorVersion = Table.ExpandRecordColumn(#"PBIConnectorVersion Converted to Table", "Column1", {"V"})
                            in
                                Output_Source_PBIConnectorVersion
            ]
        ),
        Version = if Table.RowCount(Output_Source_PBIConnectorVersion) > 0 then Output_Source_PBIConnectorVersion{0}[V] else "1.0.0"
        ,
    //Get Financial Dimensions
        ListFinancialDimensions = CreateFinancialDimensionsFW(outputURL,Version,Model),
        IndexOfAccount = List.PositionOf(ListFinancialDimensions[DimensionName], "Account"),
        Account = ListFinancialDimensions{IndexOfAccount}[DimensionTable],
        IndexOfAccount_H = List.PositionOf(ListFinancialDimensions[DimensionName], "Account Hierarchy"),
        Account_H = ListFinancialDimensions{IndexOfAccount_H}[DimensionTable],
        IndexOfCategory = List.PositionOf(ListFinancialDimensions[DimensionName], "Category"),
        Category = ListFinancialDimensions{IndexOfCategory}[DimensionTable],
        IndexOfCategory_G = List.PositionOf(ListFinancialDimensions[DimensionName], "Category Grouping"),
        Category_G = ListFinancialDimensions{IndexOfCategory_G}[DimensionTable],
        IndexOfCalendar = List.PositionOf(ListFinancialDimensions[DimensionName], "Calendar"),
        Calendar = ListFinancialDimensions{IndexOfCalendar}[DimensionTable],
        IndexOfChangeSign = List.PositionOf(ListFinancialDimensions[DimensionName], "Change Sign"),
        ChangeSign = ListFinancialDimensions{IndexOfChangeSign}[DimensionTable],
        IndexOfCustomDimension1 = List.PositionOf(ListFinancialDimensions[DimensionName], "Custom Dimension 1"),
        CustomDimension1 = ListFinancialDimensions{IndexOfCustomDimension1}[DimensionTable],
        IndexOfCustomDimension2_CTP = List.PositionOf(ListFinancialDimensions[DimensionName], "Custom Dimension 2 CTP"),
        CustomDimension2_CTP = ListFinancialDimensions{IndexOfCustomDimension2_CTP}[DimensionTable],
        IndexOfCustomDimension2_CTP_H = List.PositionOf(ListFinancialDimensions[DimensionName], "Custom Dimension 2 CTP Hierarchy"),
        CustomDimension2_CTP_H = ListFinancialDimensions{IndexOfCustomDimension2_CTP_H}[DimensionTable],
        IndexOfCustomDimension2_Segment = List.PositionOf(ListFinancialDimensions[DimensionName], "Custom Dimension 2 Segment"),
        CustomDimension2_Segment = ListFinancialDimensions{IndexOfCustomDimension2_Segment}[DimensionTable],
        IndexOfCustomDimension2_Segment_H = List.PositionOf(ListFinancialDimensions[DimensionName], "Custom Dimension 2 Segment Hierarchy"),
        CustomDimension2_Segment_H = ListFinancialDimensions{IndexOfCustomDimension2_Segment_H}[DimensionTable],
        IndexOfCustomDimension2 = List.PositionOf(ListFinancialDimensions[DimensionName], "Custom Dimension 2"),
        CustomDimension2 = ListFinancialDimensions{IndexOfCustomDimension2}[DimensionTable],
        IndexOfCustomDimension3 = List.PositionOf(ListFinancialDimensions[DimensionName], "Custom Dimension 3"),
        CustomDimension3 = ListFinancialDimensions{IndexOfCustomDimension3}[DimensionTable],
        IndexOfCustomDimension4 = List.PositionOf(ListFinancialDimensions[DimensionName], "Custom Dimension 4"),
        CustomDimension4 = ListFinancialDimensions{IndexOfCustomDimension4}[DimensionTable],
        IndexOfCustomDimension5 = List.PositionOf(ListFinancialDimensions[DimensionName], "Custom Dimension 5"),
        CustomDimension5 = ListFinancialDimensions{IndexOfCustomDimension5}[DimensionTable],
        IndexOfCustomDimension1_H = List.PositionOf(ListFinancialDimensions[DimensionName], "Custom Dimension 1 Hierarchy"),
        CustomDimension1_H = ListFinancialDimensions{IndexOfCustomDimension1_H}[DimensionTable],
        IndexOfCustomDimension2_H = List.PositionOf(ListFinancialDimensions[DimensionName], "Custom Dimension 2 Hierarchy"),
        CustomDimension2_H = ListFinancialDimensions{IndexOfCustomDimension2_H}[DimensionTable],
        IndexOfCustomDimension3_H = List.PositionOf(ListFinancialDimensions[DimensionName], "Custom Dimension 3 Hierarchy"),
        CustomDimension3_H = ListFinancialDimensions{IndexOfCustomDimension3_H}[DimensionTable],
        IndexOfCustomDimension4_H = List.PositionOf(ListFinancialDimensions[DimensionName], "Custom Dimension 4 Hierarchy"),
        CustomDimension4_H = ListFinancialDimensions{IndexOfCustomDimension4_H}[DimensionTable],
        IndexOfCustomDimension5_H = List.PositionOf(ListFinancialDimensions[DimensionName], "Custom Dimension 5 Hierarchy"),
        CustomDimension5_H = ListFinancialDimensions{IndexOfCustomDimension5_H}[DimensionTable],
        IndexOfEntity = List.PositionOf(ListFinancialDimensions[DimensionName], "Entity"),
        Entity = ListFinancialDimensions{IndexOfEntity}[DimensionTable],
        IndexOfEntity_H = List.PositionOf(ListFinancialDimensions[DimensionName], "Entity Hierarchy"),
        Entity_H = ListFinancialDimensions{IndexOfEntity_H}[DimensionTable],
        IndexOfEntity_CTP = List.PositionOf(ListFinancialDimensions[DimensionName], "Entity CTP"),
        Entity_CTP = ListFinancialDimensions{IndexOfEntity_CTP}[DimensionTable],
        IndexOfEntity_CTP_H = List.PositionOf(ListFinancialDimensions[DimensionName], "Entity CTP Hierarchy"),
        Entity_CTP_H = ListFinancialDimensions{IndexOfEntity_CTP_H}[DimensionTable],
        IndexOfEntity_Segment = List.PositionOf(ListFinancialDimensions[DimensionName], "Entity Segment"),
        Entity_Segment = ListFinancialDimensions{IndexOfEntity_Segment}[DimensionTable],
        IndexOfEntity_Segment_H = List.PositionOf(ListFinancialDimensions[DimensionName], "Entity Segment Hierarchy"),
        Entity_Segment_H = ListFinancialDimensions{IndexOfEntity_Segment_H}[DimensionTable],
        IndexOfExchangeRate = List.PositionOf(ListFinancialDimensions[DimensionName], "Exchange Rate"),
        ExchangeRate = ListFinancialDimensions{IndexOfExchangeRate}[DimensionTable],
        IndexOfFST = List.PositionOf(ListFinancialDimensions[DimensionName], "FST"),
        FST = ListFinancialDimensions{IndexOfFST}[DimensionTable],
        IndexOfNotes = List.PositionOf(ListFinancialDimensions[DimensionName], "Notes"),
        Notes = ListFinancialDimensions{IndexOfNotes}[DimensionTable],
        IndexOfPeriod = List.PositionOf(ListFinancialDimensions[DimensionName], "Period"),
        Period = ListFinancialDimensions{IndexOfPeriod}[DimensionTable],
        IndexOfPeriodLength = List.PositionOf(ListFinancialDimensions[DimensionName], "Period Length"),
        PeriodLength = ListFinancialDimensions{IndexOfPeriodLength}[DimensionTable],
        IndexOfPeriodicValueCalculation = List.PositionOf(ListFinancialDimensions[DimensionName], "Periodic Value Calculation"),
        PeriodicValueCalculation = ListFinancialDimensions{IndexOfPeriodicValueCalculation}[DimensionTable],
        IndexOfScenario = List.PositionOf(ListFinancialDimensions[DimensionName], "Scenario"),
        Scenario = ListFinancialDimensions{IndexOfScenario}[DimensionTable],
        IndexOfScenario_G = List.PositionOf(ListFinancialDimensions[DimensionName], "Scenario Grouping"),
        Scenario_G = ListFinancialDimensions{IndexOfScenario_G}[DimensionTable],
        IndexOfScenarioPeriod = List.PositionOf(ListFinancialDimensions[DimensionName], "Scenario Period"),
        ScenarioPeriod = ListFinancialDimensions{IndexOfScenarioPeriod}[DimensionTable],
        IndexOfTargetCurrency = List.PositionOf(ListFinancialDimensions[DimensionName], "Target Currency"),
        TargetCurrency = ListFinancialDimensions{IndexOfTargetCurrency}[DimensionTable],
        IndexOfTransactionCurrency = List.PositionOf(ListFinancialDimensions[DimensionName], "Transaction Currency"),
        TransactionCurrency = ListFinancialDimensions{IndexOfTransactionCurrency}[DimensionTable],
        IndexOfUserRightsAccount = List.PositionOf(ListFinancialDimensions[DimensionName], "User Rights Account"),
        UserRightsAccount = ListFinancialDimensions{IndexOfUserRightsAccount}[DimensionTable],
        IndexOfUserRightsCategory = List.PositionOf(ListFinancialDimensions[DimensionName], "User Rights Category"),
        UserRightsCategory = ListFinancialDimensions{IndexOfUserRightsCategory}[DimensionTable],
        IndexOfUserRightsDest1 = List.PositionOf(ListFinancialDimensions[DimensionName], "User Rights Custom Dimension 1"),
        UserRightsDest1 = ListFinancialDimensions{IndexOfUserRightsDest1}[DimensionTable],
        IndexOfUserRightsDest2 = List.PositionOf(ListFinancialDimensions[DimensionName], "User Rights Custom Dimension 2"),
        UserRightsDest2 = ListFinancialDimensions{IndexOfUserRightsDest2}[DimensionTable],
        IndexOfUserRightsDest3 = List.PositionOf(ListFinancialDimensions[DimensionName], "User Rights Custom Dimension 3"),
        UserRightsDest3 = ListFinancialDimensions{IndexOfUserRightsDest3}[DimensionTable],
        IndexOfUserRightsDest4 = List.PositionOf(ListFinancialDimensions[DimensionName], "User Rights Custom Dimension 4"),
        UserRightsDest4 = ListFinancialDimensions{IndexOfUserRightsDest4}[DimensionTable],
        IndexOfUserRightsDest5 = List.PositionOf(ListFinancialDimensions[DimensionName], "User Rights Custom Dimension 5"),
        UserRightsDest5 = ListFinancialDimensions{IndexOfUserRightsDest5}[DimensionTable],
        IndexOfUserRightsEntity = List.PositionOf(ListFinancialDimensions[DimensionName], "User Rights Entity"),
        UserRightsEntity = ListFinancialDimensions{IndexOfUserRightsEntity}[DimensionTable],
        IndexOfUserRightsScenario = List.PositionOf(ListFinancialDimensions[DimensionName], "User Rights Scenario"),
        UserRightsScenario = ListFinancialDimensions{IndexOfUserRightsScenario}[DimensionTable],

    //Get Fact Table pages
        
        Output_Source_FactTableNrPages =
        Table.View(null,
                [
                    GetType = () =>
                           type table [N_PAGINATION= Text.Type],
                    GetRows = () =>
                        let 
                            Source_FactTableNrPages = Json.Document(Web.Contents(outputURL & "Dataset_AWT018()?$select=N_PAGINATION&$filter=DATASET eq 'FACT_TABLE_" & Model &"'")),
                            #"FactTableNrPages Converted to Table" = Table.FromRecords({Source_FactTableNrPages}),
                            #"FactTableNrPages Removed Columns" = Table.RemoveColumns(#"FactTableNrPages Converted to Table",{"@odata.context"}),
                            #"FactTableNrPages Expanded value" = Table.ExpandListColumn(#"FactTableNrPages Removed Columns", "value"),
                            Output_Source_FactTableNrPages = Table.ExpandRecordColumn(#"FactTableNrPages Expanded value", "value", {"N_PAGINATION"})
                        in 
                            Output_Source_FactTableNrPages
                ]
            ),

        #"FactTableNrPages Changed Type" = Table.TransformColumnTypes(Output_Source_FactTableNrPages,{{"N_PAGINATION", Int64.Type}}),
        FactTableNrPages = if Version="1.1.0" then #"FactTableNrPages Changed Type"{0}[N_PAGINATION] else 0
        ,
    //Get Fact Table
        FactTable_ModelSwitch = 
                {   //Model, FactTable
                    {"1",  "000014()"},
                    {"2",  "000040()"}
                    //,{"3",  "000041()"}
                }
                ,
            FactTableDSCode = List.Accumulate(FactTable_ModelSwitch, "000014()", (state, current) =>
                if current{0} = Model then current{1} else state
                ),

    //Version 1.0.0 
        Output_Source_FactTable_0 = 
        Table.View(null,
            [
                GetType = () =>
                    type table [K= Text.Type],
                GetRows = () =>
                    let 
                        Source_FactTable = Json.Document(Web.Contents(outputURL & "Datasource_" & FactTableDSCode ,[Timeout=#duration(0,0,30,0)])),
                        #"Converted to Table FactTable" = Table.FromRecords({Source_FactTable}),
                        #"Removed Columns FactTable" = Table.RemoveColumns(#"Converted to Table FactTable",{"@odata.context"}),
                        #"Expanded value FactTable" = Table.ExpandListColumn(#"Removed Columns FactTable", "value"),
                        Output_Source_FactTable = Table.ExpandRecordColumn(#"Expanded value FactTable", "value", {"K"})
                    in 
                        Output_Source_FactTable
            ]
        ), 

 
    //Output Source Fact Table 1 
        GetFactTablePage = (Index) =>
            let 
                Source_FactTable_V1 = Table.View(null,
                [
                    GetType = () =>
                           type table [K= Text.Type],
                    GetRows = () =>
                        let 
                            Source_FactTable = Json.Document(Web.Contents(outputURL, [RelativePath="Datasource_" & FactTableDSCode & "?$select=K&$filter=P eq '" & Text.From(Index) &"'",Timeout=#duration(0,0,30,0)])),
                            #"Converted to Table FactTable" = Table.FromRecords({Source_FactTable}),
                            #"Removed Columns FactTable" = Table.RemoveColumns(#"Converted to Table FactTable",{"@odata.context"}),
                            #"Expanded value FactTable" = Table.ExpandListColumn(#"Removed Columns FactTable", "value"),
                            //#"Filtered Rows FactTable" = Table.SelectRows(#"Expanded value FactTable", each [value] <> null and [value] <> ""),
                            FactTable_1 = Table.ExpandRecordColumn( #"Expanded value FactTable", "value", {"K"})
                        in 
                            FactTable_1
                ]
            )
            in
                Source_FactTable_V1,

        FactTablePageIndices = { 1 .. FactTableNrPages},
        FactTablePages = List.Transform(FactTablePageIndices, each GetFactTablePage(_)),


        Output_Source_FactTable_1 =  if FactTableNrPages = 1 then 
                                //N Pages = 1
                                let 
                                    Source_FactTable_V1 = Table.View(null,
                                    [
                                        GetType = () =>
                                               type table [K= Text.Type],
                                        GetRows = () =>
                                            let 
                                                Source_FactTable = Json.Document(Web.Contents(outputURL, [RelativePath="Datasource_" & FactTableDSCode & "?$select=K",Timeout=#duration(0,0,30,0)])),
                                                #"Converted to Table FactTable" = Table.FromRecords({Source_FactTable}),
                                                #"Removed Columns FactTable" = Table.RemoveColumns(#"Converted to Table FactTable",{"@odata.context"}),
                                                #"Expanded value FactTable" = Table.ExpandListColumn(#"Removed Columns FactTable", "value"),
                                                FactTable_1 = Table.ExpandRecordColumn(#"Expanded value FactTable", "value", {"K"})
                                            in 
                                                FactTable_1
                                    ]
                                )
                                in
                                    Source_FactTable_V1
                                //N Pages > 1
                            else
                                Table.Combine(FactTablePages),
    //Version 1.1.0
        Output_Source_FactTable_Splitted_1 =  Table.SplitColumn(Output_Source_FactTable_1, "K", Splitter.SplitTextByDelimiter("|", QuoteStyle.None), {"TGK_SCENARIO_F_KEY", "TGK_PERIOD_F_KEY", "TGK_ENTITY_F_KEY", "TGK_ACCOUNT_F_KEY",
         "TGK_DEST1_F_KEY", "TGK_DEST2_F_KEY", "TGK_DEST3_F_KEY", "TGK_DEST4_F_KEY", "TGK_DEST5_F_KEY", "TGK_CATEGORY_F_KEY", "TGK_TRANSACTION_CURRENCY_F_KEY","TGK_ENTITY_CTP_F_KEY","TGK_DEST2_CTP_F_KEY","TGK_ENTITY_SEGMENT_F_KEY","TGK_DEST2_SEGMENT_F_KEY", "AMOUNT_TYPE", "AMOUNT"}),
        //#"1 FactTable Changed Type" = Table.TransformColumnTypes(Output_Source_FactTable_Splitted_1,{ {"TGK_SCENARIO_F_KEY", type text}, {"TGK_PERIOD_F_KEY", type text}, {"TGK_ENTITY_F_KEY", type text}, {"TGK_ACCOUNT_F_KEY", type text}, {"TGK_DEST1_F_KEY", type text}, {"TGK_DEST2_F_KEY", type text}, {"TGK_DEST3_F_KEY", type text}, {"TGK_DEST4_F_KEY", type text}, {"TGK_DEST5_F_KEY", type text}, {"TGK_CATEGORY_F_KEY", type text}, {"TGK_TRANSACTION_CURRENCY_F_KEY", type text}, {"AMOUNT_TYPE", type text}, {"TGK_ENTITY_CTP_F_KEY", type text}, {"TGK_DEST2_CTP_F_KEY", type text}}),
        Output_FactTable_1 = Table.TransformColumnTypes(Output_Source_FactTable_Splitted_1,{{"AMOUNT", type number}}, "en-US"),
        
    //Version 1.0.0
        Output_Source_FactTable_Splitted_0 =  Table.SplitColumn(Output_Source_FactTable_0, "K", Splitter.SplitTextByDelimiter("|", QuoteStyle.None), {"TGK_CALENDAR_KEY", "TGK_SCENARIO_F_KEY", "TGK_PERIOD_F_KEY", "TGK_ENTITY_F_KEY", "TGK_ACCOUNT_F_KEY",
         "TGK_DEST1_F_KEY", "TGK_DEST2_F_KEY", "TGK_DEST3_F_KEY", "TGK_DEST4_F_KEY", "TGK_DEST5_F_KEY", "TGK_CATEGORY_F_KEY", "TGK_TRANSACTION_CURRENCY_F_KEY","TGK_ENTITY_CTP_F_KEY","TGK_DEST2_CTP_F_KEY","TGK_ENTITY_SEGMENT_F_KEY","TGK_DEST2_SEGMENT_F_KEY", "AMOUNT_TYPE", "AMOUNT"}),
        #"0 FactTable Changed Type" = Table.TransformColumnTypes(Output_Source_FactTable_Splitted_0,{{"TGK_CALENDAR_KEY", type date}, {"TGK_SCENARIO_F_KEY", type text}, {"TGK_PERIOD_F_KEY", type text}, {"TGK_ENTITY_F_KEY", type text}, {"TGK_ACCOUNT_F_KEY", type text}, {"TGK_DEST1_F_KEY", type text}, {"TGK_DEST2_F_KEY", type text}, {"TGK_DEST3_F_KEY", type text}, {"TGK_DEST4_F_KEY", type text}, {"TGK_DEST5_F_KEY", type text}, {"TGK_CATEGORY_F_KEY", type text}, {"TGK_TRANSACTION_CURRENCY_F_KEY", type text}, {"AMOUNT_TYPE", type text}, {"TGK_ENTITY_CTP_F_KEY", type text}, {"TGK_DEST2_CTP_F_KEY", type text}}),
        Output_FactTable_0 = Table.TransformColumnTypes(#"0 FactTable Changed Type", {{"AMOUNT", type number}}, "en-US"),

    //Choosing Version
        Output_Source_FactTable = if Version="1.1.0" then Output_FactTable_1 else Output_FactTable_0,

        #"FactTable Added Custom" = Table.AddColumn(Output_Source_FactTable, "TGK_SCENARIO_PERIOD_F_KEY", each [TGK_SCENARIO_F_KEY]&"|"&[TGK_PERIOD_F_KEY],type text),
        #"FactTable Merged Entity" = Table.NestedJoin(#"FactTable Added Custom", {"TGK_ENTITY_F_KEY"}, Entity, {"TGK_ENTITY_KEY"}, "Entity", JoinKind.LeftOuter),
        #"FactTable Expanded Entity" = Table.ExpandTableColumn(#"FactTable Merged Entity", "Entity", {"TGK_ENTITY_ID"}, {"TGK_ENTITY_ID"}),
        #"FactTable Merged Account" = Table.NestedJoin(#"FactTable Expanded Entity", {"TGK_ACCOUNT_F_KEY"}, Account, {"TGK_ACCOUNT_KEY"}, "Account", JoinKind.LeftOuter),
        #"FactTable Expanded Account" = Table.ExpandTableColumn(#"FactTable Merged Account", "Account", {"TGK_ACCOUNT_ID"}, {"TGK_ACCOUNT_ID"}),
        #"FactTable Merged Category" = Table.NestedJoin( #"FactTable Expanded Account", {"TGK_CATEGORY_F_KEY"}, Category, {"TGK_CATEGORY_KEY"}, "Category", JoinKind.LeftOuter),
        #"FactTable Expanded Category" = Table.ExpandTableColumn(#"FactTable Merged Category", "Category", {"TGK_CATEGORY_ID"}, {"TGK_CATEGORY_ID"}),
        #"FactTable Merged Custom Dim 1" = Table.NestedJoin(#"FactTable Expanded Category", {"TGK_DEST1_F_KEY"}, CustomDimension1, {"TGK_DEST1_KEY"}, "Custom Dim 1", JoinKind.LeftOuter),
        #"FactTable Expanded Custom Dim 1" = Table.ExpandTableColumn(#"FactTable Merged Custom Dim 1", "Custom Dim 1", {"TGK_DEST1_ID"}, {"TGK_DEST1_ID"}),
        #"FactTable Merged Custom Dim 2" = Table.NestedJoin(#"FactTable Expanded Custom Dim 1", {"TGK_DEST2_F_KEY"}, CustomDimension2, {"TGK_DEST2_KEY"}, "Custom Dim 2", JoinKind.LeftOuter),
        #"FactTable Expanded Custom Dim 2" = Table.ExpandTableColumn(#"FactTable Merged Custom Dim 2", "Custom Dim 2", {"TGK_DEST2_ID"}, {"TGK_DEST2_ID"}),
        #"FactTable Merged Custom Dim 3" = Table.NestedJoin(#"FactTable Expanded Custom Dim 2", {"TGK_DEST3_F_KEY"}, CustomDimension3, {"TGK_DEST3_KEY"}, "Custom Dim 3", JoinKind.LeftOuter),
        #"FactTable Expanded Custom Dim 3" = Table.ExpandTableColumn(#"FactTable Merged Custom Dim 3", "Custom Dim 3", {"TGK_DEST3_ID"}, {"TGK_DEST3_ID"}),
        #"FactTable Merged Custom Dim 4" = Table.NestedJoin(#"FactTable Expanded Custom Dim 3", {"TGK_DEST4_F_KEY"}, CustomDimension4, {"TGK_DEST4_KEY"}, "Custom Dim 4", JoinKind.LeftOuter),
        #"FactTable Expanded Custom Dim 4" = Table.ExpandTableColumn(#"FactTable Merged Custom Dim 4", "Custom Dim 4", {"TGK_DEST4_ID"}, {"TGK_DEST4_ID"}),
        #"FactTable Merged Custom Dim 5" = Table.NestedJoin(#"FactTable Expanded Custom Dim 4", {"TGK_DEST5_F_KEY"},CustomDimension5, {"TGK_DEST5_KEY"}, "Custom Dim 5", JoinKind.LeftOuter),
        #"FactTable Expanded Custom Dim 5" = Table.ExpandTableColumn(#"FactTable Merged Custom Dim 5", "Custom Dim 5", {"TGK_DEST5_ID"}, {"TGK_DEST5_ID"}),
        #"FactTable Merged Scenario" = Table.NestedJoin(#"FactTable Expanded Custom Dim 5", {"TGK_SCENARIO_F_KEY"}, Scenario, {"TGK_SCENARIO_KEY"}, "Scenario", JoinKind.LeftOuter),
        #"FactTable Expanded Scenario" = Table.ExpandTableColumn(#"FactTable Merged Scenario", "Scenario", {"TGK_SCENARIO_ID"}, {"TGK_SCENARIO_ID"}),
        #"FactTable Merged Transaction Currency" = Table.NestedJoin(#"FactTable Expanded Scenario", {"TGK_TRANSACTION_CURRENCY_F_KEY"}, TransactionCurrency, {"TGK_TRANSACTION_CURRENCY_KEY"}, "Transaction Currency", JoinKind.LeftOuter),
        #"FactTable Expanded Transaction Currency" = Table.ExpandTableColumn(#"FactTable Merged Transaction Currency", "Transaction Currency", {"TGK_TRANSACTION_CURRENCY_ID"}, {"TGK_TRANSACTION_CURRENCY_ID"}),
        #"FactTable Merged Scenario Period" = Table.NestedJoin(#"FactTable Expanded Transaction Currency", {"TGK_SCENARIO_PERIOD_F_KEY"}, ScenarioPeriod, {"TGK_SCENARIO_PERIOD_KEY"}, "Scenario Period", JoinKind.LeftOuter),
        #"FactTable Expanded Scenario Period" = Table.ExpandTableColumn(#"FactTable Merged Scenario Period", "Scenario Period", {"TGK_SCENARIO_PERIOD_ID"}, {"TGK_SCENARIO_PERIOD_ID"}),
        #"FactTable Merged Entity CTP" = Table.NestedJoin(#"FactTable Expanded Scenario Period", {"TGK_ENTITY_CTP_F_KEY"}, Entity_CTP, {"TGK_ENTITY_CTP_KEY"}, "Entity CTP", JoinKind.LeftOuter),
        #"FactTable Expanded Entity CTP" = Table.ExpandTableColumn(#"FactTable Merged Entity CTP", "Entity CTP", {"TGK_ENTITY_CTP_ID"}, {"TGK_ENTITY_CTP_ID"}),
        #"FactTable Merged Custom Dimension 2 CTP" = Table.NestedJoin(#"FactTable Expanded Entity CTP", {"TGK_DEST2_CTP_F_KEY"}, CustomDimension2_CTP, {"TGK_DEST2_CTP_KEY"}, "Custom Dimension 2 CTP", JoinKind.LeftOuter),
        #"FactTable Expanded Custom Dimension 2 CTP" = Table.ExpandTableColumn(#"FactTable Merged Custom Dimension 2 CTP", "Custom Dimension 2 CTP", {"TGK_DEST2_CTP_ID"}, {"TGK_DEST2_CTP_ID"}),
        #"FactTable Merged Entity Segment" = Table.NestedJoin(#"FactTable Expanded Custom Dimension 2 CTP", {"TGK_ENTITY_SEGMENT_F_KEY"}, Entity_Segment, {"TGK_ENTITY_SEGMENT_KEY"}, "Entity Segment", JoinKind.LeftOuter),
        #"FactTable Expanded Entity Segment" = Table.ExpandTableColumn(#"FactTable Merged Entity Segment", "Entity Segment", {"TGK_ENTITY_SEGMENT_ID"}, {"TGK_ENTITY_SEGMENT_ID"}),
        #"FactTable Merged Custom Dimension 2 Segment" = Table.NestedJoin(#"FactTable Expanded Entity Segment", {"TGK_DEST2_SEGMENT_F_KEY"}, CustomDimension2_Segment, {"TGK_DEST2_SEGMENT_KEY"}, "Custom Dimension 2 Segment", JoinKind.LeftOuter),
        #"FactTable Expanded Custom Dimension 2 Segment" = Table.ExpandTableColumn(#"FactTable Merged Custom Dimension 2 Segment", "Custom Dimension 2 Segment", {"TGK_DEST2_SEGMENT_ID"}, {"TGK_DEST2_SEGMENT_ID"}),

        FactTable = #"FactTable Expanded Custom Dimension 2 Segment"
    ,
    //Create base table for Nav Table
        base = #table( {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
        {                 
                     { "Account","Account",Account,"Table", "Table", true},
                     { "Account Hierarchy","Account Hierarchy",Account_H,"Table", "Table", true},
                     { "Category","Category",Category,"Table", "Table", true},
                     { "Category Grouping","Category Grouping",Category_G,"Table", "Table", true},              
                     { "Calendar","Calendar",Calendar,"Table", "Table", true},
                     { "Change Sign","Change Sign",ChangeSign,"Table", "Table", true},
                     { "Custom Dimension 1","Custom Dimension 1",CustomDimension1,"Table", "Table", true},
                     { "Custom Dimension 2 CTP","Custom Dimension 2 CTP",CustomDimension2_CTP,"Table", "Table", true},
                     { "Custom Dimension 2 CTP Hierarchy","Custom Dimension 2 CTP Hierarchy",CustomDimension2_CTP_H,"Table", "Table", true},
                     { "Custom Dimension 2 Segment","Custom Dimension 2 Segment",CustomDimension2_Segment,"Table", "Table", true},
                     { "Custom Dimension 2 Segment Hierarchy","Custom Dimension 2 Segment Hierarchy",CustomDimension2_Segment_H,"Table", "Table", true},
                     { "Custom Dimension 2","Custom Dimension 2",CustomDimension2,"Table", "Table", true},
                     { "Custom Dimension 3","Custom Dimension 3",CustomDimension3,"Table", "Table", true},
                     { "Custom Dimension 4","Custom Dimension 4",CustomDimension4,"Table", "Table", true},
                     { "Custom Dimension 5","Custom Dimension 5",CustomDimension5,"Table", "Table", true},
                     { "Custom Dimension 1 Hierarchy","Custom Dimension 1 Hierarchy",CustomDimension1_H,"Table", "Table", true},
                     { "Custom Dimension 2 Hierarchy","Custom Dimension 2 Hierarchy",CustomDimension2_H,"Table", "Table", true},
                     { "Custom Dimension 3 Hierarchy","Custom Dimension 3 Hierarchy",CustomDimension3_H,"Table", "Table", true},
                     { "Custom Dimension 4 Hierarchy","Custom Dimension 4 Hierarchy",CustomDimension4_H,"Table", "Table", true},
                     { "Custom Dimension 5 Hierarchy","Custom Dimension 5 Hierarchy",CustomDimension5_H,"Table", "Table", true},
                     { "Entity", "Entity", Entity,"Table","Table",true},
                     { "Entity Hierarchy", "Entity Hierarchy",Entity_H, "Table", "Table", true},
                     { "Entity CTP", "Entity CTP", Entity_CTP,"Table","Table",true},
                     { "Entity CTP Hierarchy", "Entity CTP Hierarchy",Entity_CTP_H, "Table", "Table", true},
                     { "Entity Segment", "Entity Segment", Entity_Segment,"Table","Table",true},
                     { "Entity Segment Hierarchy", "Entity Segment Hierarchy", Entity_Segment_H,"Table","Table",true},
                     { "Exchange Rate","Exchange Rate",ExchangeRate,"Table", "Table", true},        
                     { "FST","FST",FST,"Table", "Table", true},
                     { "Notes","Notes",Notes,"Table", "Table", true},
                     { "Period","Period",Period,"Table", "Table", true},
                     { "Period Length","Period Length",PeriodLength,"Table", "Table", true},
                     { "Periodic Value Calculation","Periodic Value Calculation",PeriodicValueCalculation,"Table", "Table", true},
                     { "Scenario","Scenario",Scenario,"Table", "Table", true},
                     { "Scenario Grouping","Scenario Grouping",Scenario_G,"Table", "Table", true},
                     { "Scenario Period","Scenario Period",ScenarioPeriod,"Table", "Table", true},
                     { "Target Currency","Target Currency",TargetCurrency,"Table", "Table", true},
                     { "Transaction Currency","Currency",TransactionCurrency,"Table", "Table", true},
                     { "User Rights Account","User Rights Account",UserRightsAccount,"Table", "Table", true},
                     { "User Rights Category","User Rights Category",UserRightsCategory,"Table", "Table", true},
                     { "User Rights Custom Dimension 1","User Rights Custom Dimension 1",UserRightsDest1,"Table", "Table", true},
                     { "User Rights Custom Dimension 2","User Rights Custom Dimension 2",UserRightsDest2,"Table", "Table", true},
                     { "User Rights Custom Dimension 3","User Rights Custom Dimension 3",UserRightsDest3,"Table", "Table", true},
                     { "User Rights Custom Dimension 4","User Rights Custom Dimension 4",UserRightsDest4,"Table", "Table", true},
                     { "User Rights Custom Dimension 5","User Rights Custom Dimension 5",UserRightsDest5,"Table", "Table", true},
                     { "User Rights Entity","User Rights Entity",UserRightsEntity,"Table", "Table", true},
                     { "User Rights Scenario","User Rights Scenario",UserRightsScenario,"Table", "Table", true},
                     { "FactTable", "FactTable", FactTable ,"Table", "Table", true}
        }),

    //Create Nav Table
        navTable = Table.ToNavigationTable(base, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf"),

    //Error Handling
        accessURL =  Table.FromRecords({Json.Document(Web.Contents(outputURL))}), //TODO
        output = if //Try Authentication API 
                    List.IsEmpty(accessURL{0}[value]) 
                    then Diagnostics.Trace(TraceLevel.Error, "Environment not found. Please verify the input parameters provided.", () => error "Environment not found. Please verify the input parameters provided.", true)  
                else 
                    if Model <>"1" and Model <>"2" then Diagnostics.Trace(TraceLevel.Error, "Financial Model should be 1 or 2. Please verify the input parameters provided.", () => error "Financial Model should be 1 or 2. Please verify the input parameters provided.", true)  
                    else
                        //Output Nav Tablee
                        navTable
    in
       navTable;//TODO

//4) Create AW Nav Table
CCHTagetikNavTableAIH = (URL as text, Database as text,optional AW as text,optional Dataset as text) as table=> 
    let
    //Create API URL
        CCHTagetik_AuthenticationType = if Text.EndsWith(URL,"/basic") or Text.EndsWith(URL,"/basic/") then "BASIC_API_GATEWAY" else "BASIC",
        outputURL = if CCHTagetik_AuthenticationType  =  "BASIC_API_GATEWAY" 
                    then URL & "/aih/data/v1/" & Database &"/PBI/"
                else URL & "/api/aih/data/v1/" & Database &"/PBI/",
       
    //Get Version
        Output_Source_PBIConnectorVersion = 
            Table.View(null,
                [
                    GetType = () =>
                        type table [
                            V = Text.Type
                        ],
                    GetRows = () =>
                        let 
                            // Attempt to get data from the web source
                            Source_PBIConnectorVersion = try Json.Document(Web.Contents(outputURL & "Datasource_AWT009()", [Timeout=#duration(0,0,30,0)]))
                        in
                            // Handle potential errors from Web.Contents
                            if Source_PBIConnectorVersion[HasError] then 
                                #table(type table [V = Text.Type], {})
                            else 
                                let
                                    // Convert to table and expand record column
                                    #"PBIConnectorVersion Converted to Table" = Table.FromList(Source_PBIConnectorVersion[Value][value], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                                    Output_Source_PBIConnectorVersion = Table.ExpandRecordColumn(#"PBIConnectorVersion Converted to Table", "Column1", {"V"})
                                in
                                    Output_Source_PBIConnectorVersion
                ]
            ),
        Version = if Table.RowCount(Output_Source_PBIConnectorVersion) > 0 then Output_Source_PBIConnectorVersion{0}[V] else "1.0.0"
        ,

    
    //1) Get List DATASET Fields 
        Output_Source_ListFields =
         Table.View(null,
            [
                GetType = () =>
                  type table [
                    AW = Text.Type,
                    DATASET = Text.Type,
                    DATASET_NAME = Text.Type,
                    FIELD = Text.Type,
                    FIELD_NAME = Text.Type,
                    FIELD_TYPE = Text.Type,
                    FIELD_ORDER = Int64.Type,
                    DIMENSION = Text.Type,
                    DIMENSION_NAME = Text.Type,
                    DIMENSION_TYPE = Text.Type,
                    DIMENSION_HIERARCHY_GROUPING = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_ListFields = if Dataset is null then Json.Document(Web.Contents(outputURL &"Dataset_AWT001()?$filter=AW eq '"& AW &"'")) else 
                        Json.Document(Web.Contents(outputURL &"Dataset_AWT001()?$filter=AW eq '"& AW &"' and DATASET eq '"&Dataset &"'")),
                        #"ListFields Converted to Table" = Table.FromRecords({Source_ListFields}),
                        #"ListFields Removed Columns" = Table.RemoveColumns(#"ListFields Converted to Table",{"@odata.context"}),
                        #"ListFields Expanded value" = Table.ExpandListColumn(#"ListFields Removed Columns", "value"),
                        Output_Source_ListFields = Table.ExpandRecordColumn(#"ListFields Expanded value", "value", {"AW", "DATASET", "DATASET_NAME", "FIELD", "FIELD_NAME", "FIELD_TYPE", "FIELD_ORDER", "DIMENSION", "DIMENSION_NAME", "DIMENSION_TYPE","DIMENSION_HIERARCHY_GROUPING"}, {"AW", "DATASET", "DATASET_NAME", "FIELD", "FIELD_NAME", "FIELD_TYPE", "FIELD_ORDER", "DIMENSION", "DIMENSION_NAME", "DIMENSION_TYPE","DIMENSION_HIERARCHY_GROUPING"})
                    in 
                        Output_Source_ListFields
            ]
        ),
        FieldTypeMapping = #table({"FIELD_TYPE", "TARGET_TYPE"}, {
                    {"type logical" , type logical},
                    {"type number" , type number},
                    {"type time" , type time},
                    {"type date" , type date},
                    {"type datetime" , type datetime},
                    {"type datetimezone" , type datetimezone},
                    {"type duration" , type duration},
                    {"type text" , type text},
                    {"type binary" , type binary},
                    {"type anynonnull" , type anynonnull}
                    }
        ),
        #"ListFields Mapping Type Column"= Table.Join(Output_Source_ListFields, "FIELD_TYPE", FieldTypeMapping, "FIELD_TYPE"),
        #"ListFields Changed Type" = Table.TransformColumnTypes(#"ListFields Mapping Type Column",{{"FIELD_ORDER", Int64.Type}}),
        ListFieldsDataset = Table.Sort(#"ListFields Changed Type",{{"FIELD_ORDER", Order.Ascending}}),

    //2) Get List Dimensions linked to the dataset
        Source_ListLinkedDimensions = Table.SelectRows(ListFieldsDataset, each ([DIMENSION_TYPE] <> null)),
        #"ListLinkedDimensions Added Custom" = Table.AddColumn(Source_ListLinkedDimensions, "HAS_DIMENSION_NAME", each if [FIELD] = [DIMENSION] then 1 else 0),
        #"ListLinkedDimensions Changed Type" = Table.TransformColumnTypes(#"ListLinkedDimensions Added Custom",{{"HAS_DIMENSION_NAME", Int64.Type}}),
        ListLinkedDimensions = Table.Sort(#"ListLinkedDimensions Changed Type",{{"DIMENSION", Order.Ascending}, {"HAS_DIMENSION_NAME", Order.Descending}}),
        ListDistinctLinkedDimensions = Table.Distinct(ListLinkedDimensions, {"DIMENSION"}),

    //3) Get List Hierarchies and Groupings Data
        ListHierarchyGrouping_Source = Table.SelectRows(ListDistinctLinkedDimensions, each ([DIMENSION_HIERARCHY_GROUPING] <> null)),
        ListHierarchyGrouping_AddDimension_H = Table.AddColumn(ListHierarchyGrouping_Source, "DIMENSION_H", each [DIMENSION] & "_" & [DIMENSION_HIERARCHY_GROUPING]),
        ListHierarchyGrouping_AddDimension_H_Name = Table.AddColumn(ListHierarchyGrouping_AddDimension_H, "DIMENSION_H_NAME", each if [DIMENSION_HIERARCHY_GROUPING] = "H" then [DIMENSION_NAME] & " Hierarchy" else [DIMENSION_NAME] & " Grouping"),
        ListHierarchyGrouping = Table.TransformColumnTypes(ListHierarchyGrouping_AddDimension_H_Name,{{"DIMENSION_H", type text}, {"DIMENSION_H_NAME", type text}}),
        
    //4) FW: Get Hierarchies and Groupings  
        ListFinancialHierarchies = CreateFinancialDimensionsAIH(outputURL,Table.SelectRows(ListHierarchyGrouping, each [DIMENSION_TYPE]="F")[DIMENSION_H_NAME],APIFilterListDatasets),
        ListFinancialHierarchyGrouping =Table.SelectRows(ListHierarchyGrouping, each [DIMENSION_TYPE]="F"),
        FW_withDataDimensionJoinH = Table.NestedJoin(ListFinancialHierarchyGrouping,{"DIMENSION_H_NAME"},ListFinancialHierarchies,{"DimensionName"},"ListFinancialDimensionsH",JoinKind.LeftOuter),
        FW_withDataDimensionH = Table.ExpandTableColumn(FW_withDataDimensionJoinH, "ListFinancialDimensionsH", {"DimensionTable"}, {"Data"}),
        //FW_withDataDimensionHNotEmpty = Table.SelectRows(FW_withDataDimensionH, each [Data] <> null),
        // Add ItemKind and ItemName as fixed text values
        FW_withItemKindDimensionH = Table.AddColumn(FW_withDataDimensionH, "ItemKind", each "Table", type text),
        FW_withItemNameDimensionH = Table.AddColumn(FW_withItemKindDimensionH, "ItemName", each "Table", type text),
        // Indicate that the node should not be expandable
        FW_withIsLeafDimensionH = Table.AddColumn(FW_withItemNameDimensionH, "IsLeaf", each true, type logical),
        FW_output_dimensions_h = Table.RenameColumns(FW_withIsLeafDimensionH,{{"DIMENSION_H_NAME", "Name"}})
        ,

    //5) AW: Get Hierarchies 
        ListAnalyticalHierarchies = Table.SelectRows(ListHierarchyGrouping, each [DIMENSION_TYPE] = "A"),
        AW_withDataDimensionH = Table.AddColumn(ListAnalyticalHierarchies, "Data", each CreateAnalyticalDimensionHierarchy(outputURL, [DIMENSION_H],[DIMENSION_H_NAME]), Uri.Type),
        //AW_withDataDimensionHNotEmpty = Table.SelectRows(AW_withDataDimensionH, each [Data] <> null),
        // Add ItemKind and ItemName as fixed text values
        AW_withItemKindDimensionH = Table.AddColumn(AW_withDataDimensionH, "ItemKind", each "Table", type text),
        AW_withItemNameDimensionH = Table.AddColumn(AW_withItemKindDimensionH, "ItemName", each "Table", type text),
        // Indicate that the node should not be expandable
        AW_withIsLeafDimensionH = Table.AddColumn(AW_withItemNameDimensionH, "IsLeaf", each true, type logical),
        AW_output_dimensions_h = Table.RenameColumns(AW_withIsLeafDimensionH,{{"DIMENSION_H_NAME", "Name"}}),

    //6) Union Hierarchies FW & AW
        output_dimensions_h = Table.Combine({AW_output_dimensions_h, FW_output_dimensions_h}),

    //7) FW: Get Dimensions
        ListDistinctLinkedDimensionsFinancial = Table.SelectRows(Table.Distinct(ListLinkedDimensions, {"DIMENSION"}), each ([DIMENSION_TYPE] = "F")),
        ListFinancialDimensions = CreateFinancialDimensionsAIH(outputURL,ListDistinctLinkedDimensionsFinancial[DIMENSION_NAME],APIFilterListDatasets),
        //withDataDimension = Table.AddColumn(#"Filtered Rows", "Data", each CreateDimension(OutputURL,[DIMENSION],[DIMENSION_NAME],[DIMENSION_TYPE]), Uri.Type),
        FW_withDataDimensionJoin = Table.NestedJoin(ListDistinctLinkedDimensionsFinancial,{"DIMENSION_NAME"},ListFinancialDimensions,{"DimensionName"},"ListFinancialDimensions",JoinKind.LeftOuter),
        FW_withDataDimension = Table.ExpandTableColumn(FW_withDataDimensionJoin, "ListFinancialDimensions", {"DimensionTable"}, {"Data"}),
        // Add ItemKind and ItemName as fixed text values
        FW_withItemKindDimension = Table.AddColumn(FW_withDataDimension, "ItemKind", each "Table", type text),
        FW_withItemNameDimension = Table.AddColumn(FW_withItemKindDimension, "ItemName", each "Table", type text),
        // Indicate that the node should not be expandable
        FW_withIsLeafDimension = Table.AddColumn(FW_withItemNameDimension, "IsLeaf", each true, type logical),
        FW_output_dimensions = Table.RenameColumns(FW_withIsLeafDimension,{{"DIMENSION_NAME", "Name"}}),

    //8) AW: Get Dimensions
        ListAnalyticalDimensions = Table.SelectRows(ListDistinctLinkedDimensions, each ([DIMENSION_TYPE] = "A")),
        AW_withDataDimension = Table.AddColumn(ListAnalyticalDimensions, "Data", each CreateAnalyticalDimension(outputURL,[DIMENSION],[DIMENSION_NAME]), Uri.Type),
        // Add ItemKind and ItemName as fixed text values
        AW_withItemKindDimension = Table.AddColumn(AW_withDataDimension, "ItemKind", each "Table", type text),
        AW_withItemNameDimension = Table.AddColumn(AW_withItemKindDimension, "ItemName", each "Table", type text),
        // Indicate that the node should not be expandable
        AW_withIsLeafDimension = Table.AddColumn(AW_withItemNameDimension, "IsLeaf", each true, type logical),
        AW_output_dimensions = Table.RenameColumns(AW_withIsLeafDimension,{{"DIMENSION_NAME", "Name"}}),

    //6) Union Dimensions FW & AW
        output_dimensions = Table.Combine({AW_output_dimensions, FW_output_dimensions}),

    //10) Get Dataset List
    //Version 1.0.0
        Output_Source_ListDataset_0 =
        Table.View(null,
                [
                    GetType = () =>
                      type table [
                            AW = Text.Type,
                            DATASET = Text.Type,
                            DATASET_NAME = Text.Type,
                            DATASET_COD = Text.Type,
                            DATASOURCE_COD = Text.Type
                        ],
                    GetRows = () =>
                        let 
                            Source_ListDataset = if Dataset is null then Json.Document(Web.Contents( outputURL &"Dataset_AWT002()?$filter=AW eq '"& AW &"'")) else Json.Document(Web.Contents( outputURL &"Dataset_AWT002()?$filter=DATASET_COD eq '"&AW & "_" & Dataset & "'")),
                            #"ListDataset Converted to Table" = Table.FromRecords({Source_ListDataset}),
                            #"ListDataset Removed Columns" = Table.RemoveColumns(#"ListDataset Converted to Table",{"@odata.context"}),
                            #"ListDataset Expanded value" = Table.ExpandListColumn(#"ListDataset Removed Columns", "value"),
                            #"ListDataset Filtered Rows" = Table.SelectRows(#"ListDataset Expanded value", each [value] <> null and [value] <> ""),
                            Output_Source_ListDataset = Table.ExpandRecordColumn(#"ListDataset Filtered Rows", "value", {"AW","DATASET","DATASET_NAME","DATASET_COD", "DATASOURCE_COD"}, {"AW","DATASET","DATASET_NAME","DATASET_COD", "DATASOURCE_COD"})
                        in 
                            Output_Source_ListDataset
                ]
            ),

    //Version 1.1.0
        Output_Source_ListDataset_1 =
        Table.View(null,
                [
                    GetType = () =>
                      type table [
                            AW = Text.Type,
                            DATASET = Text.Type,
                            DATASET_NAME = Text.Type,
                            DATASET_COD = Text.Type,
                            DATASOURCE_COD = Text.Type,
                            N_PAGINATION= Int64.Type
                        ],
                    GetRows = () =>
                        let 
                            Source_ListDataset = if Dataset is null then Json.Document(Web.Contents( outputURL &"Dataset_AWT002()?$filter=AW eq '"& AW &"'")) else Json.Document(Web.Contents( outputURL &"Dataset_AWT002()?$filter=DATASET_COD eq '"&AW & "_" & Dataset & "'")),
                            #"ListDataset Converted to Table" = Table.FromRecords({Source_ListDataset}),
                            #"ListDataset Removed Columns" = Table.RemoveColumns(#"ListDataset Converted to Table",{"@odata.context"}),
                            #"ListDataset Expanded value" = Table.ExpandListColumn(#"ListDataset Removed Columns", "value"),
                            #"ListDataset Filtered Rows" = Table.SelectRows(#"ListDataset Expanded value", each [value] <> null and [value] <> ""),
                            Source_ListDataset_1 = Table.ExpandRecordColumn(#"ListDataset Filtered Rows", "value", {"AW","DATASET","DATASET_NAME","DATASET_COD", "DATASOURCE_COD", "N_PAGINATION"}, {"AW","DATASET","DATASET_NAME","DATASET_COD", "DATASOURCE_COD", "N_PAGINATION"})
                        in 
                           Source_ListDataset_1
                ]
            ),

        Output_Source_ListDataset = if Version="1.1.0" then Output_Source_ListDataset_1 else Output_Source_ListDataset_0,
        #"ListDataset Added Custom" = Table.AddColumn(Output_Source_ListDataset, "DATASET_API_URL", each outputURL & "Datasource_"& [DATASOURCE_COD] &"()"),
        ListDatasets = Table.TransformColumnTypes(#"ListDataset Added Custom",{{"DATASET_API_URL", type text}}),
        ListDistinctDatasets = Table.Distinct(ListDatasets, {"DATASET_COD"}),
    //11) Get Dataset Data

        //Get separator
        Output_Source_TechnicalSeparator =
            Table.View(null,
            [
                GetType = () =>
                    type table [
                        SEPARATOR = Record.Type
                    ],
                GetRows = () =>
                    let 
                        Source_TechnicalSeparator = Json.Document(Web.Contents(outputURL & "Datasource_AWT003()")),
                        #"TechnicalSeparator Converted to Table" = Table.FromRecords({Source_TechnicalSeparator}),
                        #"TechnicalSeparator Expanded value" = Table.ExpandListColumn(#"TechnicalSeparator Converted to Table", "value"),
                        #"TechnicalSeparator Expanded Record"  = Table.ExpandRecordColumn(#"TechnicalSeparator Expanded value", "value", {"SEPARATOR"}),
                        Output_Source_TechnicalSeparator = Table.RemoveColumns( #"TechnicalSeparator Expanded Record",{"@odata.context"})                            
                    in 
                        Output_Source_TechnicalSeparator
            ]
        ),
        TechnicalSeparator = Output_Source_TechnicalSeparator{0}[SEPARATOR]
        ,
        //Get Filter Dataaset list
        APIFilterListDatasets_Source = ListDistinctDatasets[DATASET_COD],
        APIFilterListDatasets = "(" & Text.Combine(List.Transform(APIFilterListDatasets_Source, each "'" & _ & "'"), ",") & ")",
        //OutputDataset
        withDataDataset_0 = Table.AddColumn(ListDistinctDatasets, "Data", each CreateDataset([AW],[DATASET],[DATASET_API_URL],ListFieldsDataset,ListLinkedDimensions,TechnicalSeparator, "1", Version), Uri.Type),
        withDataDataset_1 = Table.AddColumn(ListDistinctDatasets, "Data", each CreateDataset([AW],[DATASET],[DATASET_API_URL],ListFieldsDataset,ListLinkedDimensions,TechnicalSeparator, [N_PAGINATION], Version), Uri.Type),
        withDataDataset = if Version="1.1.0" then withDataDataset_1 else withDataDataset_0,
        // Add ItemKind and ItemName as fixed text values
        withItemKindDataset = Table.AddColumn(withDataDataset, "ItemKind", each "Table", type text),
        withItemNameDataset = Table.AddColumn(withItemKindDataset, "ItemName", each "Table", type text),
        // Indicate that the node should not be expandable
        withIsLeafDataset = Table.AddColumn(withItemNameDataset, "IsLeaf", each true, type logical),
        output_datasets = Table.RenameColumns(withIsLeafDataset,{{"DATASET_NAME", "Name"}}),


    //12) Get List User Rights

        ListUserRights_Source = Table.AddColumn(ListDistinctLinkedDimensions, "DIMENSION_UR_NAME", each "User Rights " & Text.Replace([DIMENSION_NAME], " CTP", ""),type text),
        ListUserRights = Table.Distinct(ListUserRights_Source, {"DIMENSION_UR_NAME"}),
    //13) AW: Get User Rights AW 

        ListAnalyticalUserRights = Table.SelectRows(ListUserRights, each ([DIMENSION_TYPE] = "A")),
        AWUR_withDataDimension = Table.AddColumn(ListAnalyticalUserRights, "Data", each CreateUserRightsAnalyticalDimension(outputURL,[DIMENSION],Version), Uri.Type),
        // Add ItemKind and ItemName as fixed text values
        AWUR_withItemKindDimension = Table.AddColumn(AWUR_withDataDimension, "ItemKind", each "Table", type text),
        AWUR_withItemNameDimension = Table.AddColumn(AWUR_withItemKindDimension, "ItemName", each "Table", type text),
        // Indicate that the node should not be expandable
        AWUR_withIsLeafDimension = Table.AddColumn(AWUR_withItemNameDimension, "IsLeaf", each true, type logical),
        AW_output_dimensions_ur = Table.RenameColumns(AWUR_withIsLeafDimension,{{"DIMENSION_UR_NAME", "Name"}}),

    //14) AW: Get User Rights FW 
        ListFinancialUserRights = Table.SelectRows(Table.Distinct(ListUserRights, {"DIMENSION"}), each ([DIMENSION_TYPE] = "F")),
        FWUR_Dimensions = CreateUserRightsFinancialDimensionsAIH(outputURL,Version,ListFinancialUserRights[DIMENSION_UR_NAME]),
        FWUR_withDataDimensionJoin = Table.NestedJoin(ListFinancialUserRights,{"DIMENSION_UR_NAME"},FWUR_Dimensions,{"DimensionName"},"FWUR_Dimensions",JoinKind.Inner),
        FWUR_withDataDimension = Table.ExpandTableColumn(FWUR_withDataDimensionJoin, "FWUR_Dimensions", {"DimensionTable"}, {"Data"}),
        // Add ItemKind and ItemName as fixed text values
        FWUR_withItemKindDimension = Table.AddColumn(FWUR_withDataDimension, "ItemKind", each "Table", type text),
        FWUR_withItemNameDimension = Table.AddColumn(FWUR_withItemKindDimension, "ItemName", each "Table", type text),
        // Indicate that the node should not be expandable
        FWUR_withIsLeafDimension = Table.AddColumn(FWUR_withItemNameDimension, "IsLeaf", each true, type logical),
        FW_output_dimensions_ur = Table.RenameColumns(FWUR_withIsLeafDimension,{{"DIMENSION_UR_NAME", "Name"}}),

    //15) Union List User Rights

        output_dimensions_ur = Table.Combine({AW_output_dimensions_ur, FW_output_dimensions_ur}),
        
        objects = #table({"Name",  "Data", "ItemKind", "ItemName", "IsLeaf"},{
        {"Dimensions", CreateNavTable(output_dimensions), "Folder","Folder",false},
        {"Hierarchies", CreateNavTable(output_dimensions_h), "Folder","Folder",false}, 
        {"Datasets", CreateNavTable(output_datasets), "Folder","Folder",false}, 
        {"User Rights", CreateNavTable(output_dimensions_ur), "Folder","Folder",false}   
        }),

        navTable = Table.ToNavigationTable(objects,  {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf"),
        
        checkConfigurationAW = try Json.Document(Web.Contents(outputURL & "Dataset_AW0000()?$filter=AW_COD eq '" & AW & "'  and INCLUDE_DATASET eq 'Y'"))[value]{0} otherwise null,
        checkConfigurationDataset = try Json.Document(Web.Contents(outputURL & "Dataset_AW0000()?$filter=AW_COD eq '" & AW & "' and AW_DATASET eq '" &Dataset & "'  and INCLUDE_DATASET eq 'Y'"))[value]{0} otherwise null,
        checkConfigurationAWMapping = try Json.Document(Web.Contents(outputURL & "Dataset_AWT002()?$filter=AW eq '" & AW & "'"))[value]{0} otherwise null,
        checkConfigurationDatasetMapping = try Json.Document(Web.Contents(outputURL & "Dataset_AWT002()?$filter=AW eq '" & AW & "' and DATASET eq '" &Dataset & "'"))[value]{0} otherwise null,
       
   
        errorTable = 
        if (Dataset is null and (checkConfigurationAW is null or checkConfigurationAWMapping is null)) then
            let 
                errorTable = #table(
                    type table [
                        Parameters = text, 
                        Message = text
                    ], 
                    {
                        {"AW: " & AW , "Please configure at least one dataset in the system."}
                    }
                )
            in 
                errorTable
        else if (Dataset <> null and (checkConfigurationDataset is null or checkConfigurationDatasetMapping is null)) then
              let 
                errorTable = #table(
                    type table [
                        Parameters = text, 
                        Message = text
                    ], 
                    {
                        {"AW: " & AW & " ,Dataset: " & Dataset, "The dataset entered is not configured."}
                    }
                )
            in 
                errorTable
        else null,
        
        objects2 = 
        #table({"Name",  "Data", "ItemKind", "ItemName", "IsLeaf"},{
        {"Errors", errorTable, "Table","Table",true}
        }),
        navTable2 = Table.ToNavigationTable(objects2,  {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf"),
        
        //Try Authentication API to PBI analytical workspace
        accessPBIURL = Table.FromRecords({Json.Document(Web.Contents(outputURL))}),

        //Version 1.0.0 
        //Endpoint to AW 
        
        AWURL_0 = if CCHTagetik_AuthenticationType  =  "BASIC_API_GATEWAY" 
                    then URL & "/aih/data/v1/" & Database &"/" & AW &"/"
                else URL & "/api/aih/data/v1/" & Database &"/" & AW &"/",

        
        accessAWURL = if Version = "1.1.0" then 
                            Table.FromRecords({Json.Document(Web.Contents(outputURL & "Datasource_AWT008()?$top=1&$filter=A eq '"& AW &"'"))})
                        else 
                            Table.FromRecords({Json.Document(Web.Contents(AWURL_0))})
                    ,

        //Endpoint to AW Dataset
        AWDatasetURL_0 = if CCHTagetik_AuthenticationType  =  "BASIC_API_GATEWAY" 
                    then URL & "/aih/metadata/v1/" & Database &"/" & AW &"/Datasets"
                else URL & "/api/aih/metadata/v1/" & Database &"/" & AW &"/Datasets",
        
        #"0 AWDatasetURL Converted to Table" = try Table.FromRecords({Json.Document(Web.Contents(AWDatasetURL_0))}) otherwise null,
        #"0 AWDatasetURL Removed Columns" = Table.RemoveColumns(#"0 AWDatasetURL Converted to Table", {"@odata.context"}),
        #"0 AWDatasetURL Expanded value" = Table.ExpandListColumn(#"0 AWDatasetURL Removed Columns", "value"),
        #"0 AWDatasetURL Expanded value1" = Table.ExpandRecordColumn(#"0 AWDatasetURL Expanded value", "value", {"ID"}, {"ID"}),
        #"0 AWDatasetURL Filter value" = Table.SelectRows(#"0 AWDatasetURL Expanded value1", each [ID] = "000001"),
        #"0 AWDatasetURL create list" = Table.Column(#"0 AWDatasetURL Filter value" , "ID"),
        accessAWDatasetURL_0 = if #"0 AWDatasetURL Converted to Table" is null then #table({"value"}, {})  else Table.FromRecords({[value =  #"0 AWDatasetURL create list"]}) 
        ,
        accessAWDatasetURL = if Version = "1.1.0" then 
                                Table.FromRecords({Json.Document(Web.Contents(outputURL & "Datasource_AWT008()?$top=1&$filter=A eq '"& AW &"' and D eq '"&Dataset &"'"))})
                            else
                                accessAWDatasetURL_0
                                ,

        output = if  List.IsEmpty(accessPBIURL{0}[value])  //Try PBI endpoint
                    then Diagnostics.Trace(TraceLevel.Error, "Environment not found. Please verify the input parameters provided.", () => error "Environment not found. Please verify the input parameters provided.", true)  
                 else 
                    if List.IsEmpty(accessAWURL{0}[value]) //Try AW endpoint
                        then Diagnostics.Trace(TraceLevel.Error, "Analytical Workspace not found. Please verify the input parameters provided.", () => error "Analytical Workspace not found. Please verify the input parameters provided.", true)  
                    else 
                        if Dataset <> null and List.IsEmpty(accessAWDatasetURL{0}[value]) //Try Dataset endpoint
                            then Diagnostics.Trace(TraceLevel.Error, "Dataset not found. Please verify the input parameters provided.", () => error "Dataset not found. Please verify the input parameters provided.", true)  
                        else 
                            //Check Configuration AW and Datataset 
                            if ((Dataset is null and (checkConfigurationAW is null or checkConfigurationAWMapping is null)) or (Dataset <> null and (checkConfigurationDataset is null or checkConfigurationDatasetMapping is null))) then navTable2
                    else navTable 
    in
        output;

    


CreateDataset=(AW as text,DATASET as text, Dataset_URL as text,ListFieldsDataset as table,ListLinkedDimensions as table,TechnicalSeparator as text, DatasetNrPages as text, Version as text)=>
let     
    ListFieldsCurrentDataset = Table.SelectRows(ListFieldsDataset, each ([DATASET] = DATASET)),
    //ListDataTypes = Table.SelectRows(ListFieldsCurrentDataset, each [DATASET] = DATASET),
    ListLinkedDimensionsCurrentDataset = Table.SelectRows(ListLinkedDimensions, each [DATASET] = DATASET),
    
//Source Dataset
//Version 1.0.0
    Output_Source_Dataset_0 =
    Table.View(null,
        [
            GetType = () =>
                type table [
                    D = Text.Type
                ],
            GetRows = () =>
                let 
                    Source_Dataset = Json.Document(Web.Contents(Dataset_URL,[Timeout=#duration(0,0,30,0)])),
                    #"Dataset Converted to Table" = Table.FromRecords({Source_Dataset}),
                    #"Dataset Removed Columns" = Table.RemoveColumns(#"Dataset Converted to Table",{"@odata.context"}),
                    #"Dataset Expanded value" = Table.ExpandListColumn(#"Dataset Removed Columns", "value"),
                    Output_Source_Dataset = Table.ExpandRecordColumn(#"Dataset Expanded value", "value",{"D"})
                in 
                    Output_Source_Dataset
        ]
    ),
    GetDatasetPages =(Index) =>
        let    
            Output_Source_Dataset_1=  Table.View(null,
            [
                GetType = () =>
                
                        type table [D =Text.Type],
                GetRows = () =>
                    let 
                        Source_Dataset = Json.Document(Web.Contents(Dataset_URL& "?$select=D&$filter=P eq '" & Text.From(Index) &"'",[Timeout=#duration(0,0,30,0)])),
                        #"Dataset Converted to Table" = Table.FromRecords({Source_Dataset}),
                        #"Dataset Removed Columns" = Table.RemoveColumns(#"Dataset Converted to Table",{"@odata.context"}),
                        #"Dataset Expanded value" = Table.ExpandListColumn(#"Dataset Removed Columns", "value"),
                        Source_Dataset_1 = Table.ExpandRecordColumn(#"Dataset Expanded value", "value",{"D"})
                        
                    in 
                        Source_Dataset_1
            ]
        ) 
        in Output_Source_Dataset_1,

//Number of Pages when Version 1.1.0
    DatasetPageIndices= { 1 .. Number.From(DatasetNrPages)},
    DatasetPages = List.Transform(DatasetPageIndices, each GetDatasetPages(_)),
    Output_Source_Dataset_1 = Table.Combine(DatasetPages)
                                    ,
    Output_Source_Dataset = if Version="1.1.0" then Output_Source_Dataset_1 else Output_Source_Dataset_0,

//Split the column "D" without specifying the list of column names
    #"Dataset Split Columns" = Table.SplitColumn(
            Output_Source_Dataset, 
            "D", 
            Splitter.SplitTextByDelimiter(TechnicalSeparator, QuoteStyle.None),100
        ),
    
// Renaming mapping dynamically
    FieldNames = ListFieldsCurrentDataset[FIELD_NAME],
    ColumnCount = List.Count(FieldNames),  // Count the number of field names
    DefaultColumnNames = List.Transform({1..ColumnCount}, each "D." & Text.From(_)),  // Create default column names like "D.1", "D.2", etc.
    RenameMapping = List.Zip({DefaultColumnNames, FieldNames}),
    #"Dataset Split Rename Columns" = Table.RenameColumns( #"Dataset Split Columns", RenameMapping),
    #"Dataset Split Select Columns" = Table.SelectColumns(#"Dataset Split Rename Columns" ,FieldNames),
//Change Data Type   
    DatasetListNumberColumns =Table.SelectRows(ListFieldsCurrentDataset, each ([FIELD_TYPE] = "type number")),
    #"Dataset TransformedTable" = Table.TransformColumnTypes(#"Dataset Split Select Columns" , List.Transform(Table.ToRecords( DatasetListNumberColumns) , each {_[FIELD_NAME], _[TARGET_TYPE]}),"en-US"),
    DatasetListDateColumns =Table.SelectRows(ListFieldsCurrentDataset, each ([FIELD_TYPE] = "type datetime")),
    Dataset_Table = Table.TransformColumnTypes(#"Dataset TransformedTable", List.Transform(Table.ToRecords( DatasetListDateColumns ) , each {_[FIELD_NAME], type date})),

//Create Dimensions Keys and Replace blank with null values
    DatasetKeyColumns = Table.ToColumns(Table.Transpose(Table.SelectColumns(ListLinkedDimensionsCurrentDataset,{"FIELD_NAME","DIMENSION","FIELD"}))),
    
    DatasetTableWithNulls = List.Accumulate(DatasetKeyColumns, Dataset_Table, (table, columns) => DatasetReplaceNullColumnKeys(table, columns{0})),
    DatasetOutput = List.Accumulate(DatasetKeyColumns, DatasetTableWithNulls, (table, columns) => DatasetRenameColumnKeys(table, columns{0}, columns{1},columns{2}))

in
    DatasetOutput
;

CreateAnalyticalDimension=(outputURL as text, Dimension as text,DimensionName as text) =>
let
    Output_SourceDimension=
    Table.View(null,
        [
            GetType = () =>
                type table [
                    C = Text.Type,
                    D0 = Text.Type,
                    D1 = Text.Type,
                    D2 = Text.Type,
                    D3 = Text.Type
                ],
            GetRows = () =>
                let 
                    SourceDimension = Json.Document(Web.Contents(outputURL &"Datasource_AW9999()?$filter=K eq '"& Dimension &"'")),
                    #"AWDim Converted to Table" = Table.FromRecords({SourceDimension}),
                    #"AWDim Removed Columns" = Table.RemoveColumns(#"AWDim Converted to Table",{"@odata.context"}),
                    #"AWDim Expanded value" = Table.ExpandListColumn(#"AWDim Removed Columns", "value"),
                    Output_SourceDimension = Table.ExpandRecordColumn(#"AWDim Expanded value" , "value", {"C","D0","D1","D2","D3"})
                in 
                    Output_SourceDimension
        ]
    ),
    #"AWDim Duplicated Column" = Table.DuplicateColumn(Output_SourceDimension, "C", "TGK_"& Dimension & "_KEY"),    
    #"AWDim Duplicated ColumnH" = Table.DuplicateColumn(#"AWDim Duplicated Column", "C", "TGK_"& Dimension & "_H_KEY"),       
    AWDim = Table.RenameColumns(#"AWDim Duplicated ColumnH",{{"C", DimensionName & " Code"}, {"D0", DimensionName & " Description"},{"D1", DimensionName & " Description 1"},{"D2", DimensionName & " Description 2"},{"D3", DimensionName & " Description 3"}})
in
    AWDim
	;
  
CreateFinancialDimensionsFW =(outputURL as text,Version as text,optional Model as text) as table => 

let
    //Dimension Output based on PBI Connector Version
   VersionCases = 
    {
        //Version, 
        {"1.0.0",ExchangeRate_0,Calendar_0,Category_0,Category_G_0,Dest2_Segment_0,Entity_Segment_0,Dest2_Segment_H_0,Entity_Segment_H_0, Scenario_0,Scenario_G_0,ScenarioPeriod_0,UserRightsAccount_0,UserRightsCategory_0,UserRightsDest1_0,UserRightsDest2_0,UserRightsDest3_0,UserRightsDest4_0,UserRightsDest5_0,UserRightsEntity_0,UserRightsScenario_0,Notes_0},
        {"1.1.0",ExchangeRate_1,Calendar_1,Category_1,Category_G_1,Dest2_Segment_1,Entity_Segment_1,Dest2_Segment_H_1,Entity_Segment_H_1,Scenario_1,Scenario_G_1,ScenarioPeriod_1,UserRightsAccount_1,UserRightsCategory_1,UserRightsDest1_1,UserRightsDest2_1,UserRightsDest3_1,UserRightsDest4_1,UserRightsDest5_1,UserRightsEntity_1,UserRightsScenario_1,Notes_1}
    }
    ,
    Dimensions_ModelSwitch = 
        {   //Model, ExchRate,  Dest2 Segment,  Entity Segment, Dest2 SegmentH, Entity Segment H
            {"1",   "000027()",   "000028()",    "000026()",     "000038()",    "000004()"},
            {"2",   "000049()",   "000055()",    "000051()",     "000057()",    "000053()"}
        }
    ,
    //Account
    Output_Source_Account = 
    Table.View(null,
        [
            GetType = () =>
                   type table [
                    COD_CONTO = Text.Type,
                    DESC_CONTO0 = Text.Type, 
                    DESC_CONTO1 = Text.Type, 
                    DESC_CONTO2 = Text.Type, 
                    DESC_CONTO3 = Text.Type, 
                    DESC2_CONTO0 = Text.Type, 
                    DESC2_CONTO1 = Text.Type, 
                    DESC2_CONTO2 = Text.Type, 
                    DESC2_CONTO3 = Text.Type, 
                    NATURA_CONTO = Text.Type, 
                    TIPO_CONTO = Text.Type, 
                    TIPO_CONVERSIONE = Text.Type, 
                    SEGNO_STANDARD = Text.Type,
                    ATTRIBUTO1 = Text.Type, 
                    ATTRIBUTO2 = Text.Type, 
                    ATTRIBUTO3 = Text.Type, 
                    ATTRIBUTO4 = Text.Type, 
                    ATTRIBUTO5 = Text.Type, 
                    FORMATO_SEGNO = Int64.Type,
                    TIPO_AGGREGAZIONE_CONTO = Text.Type,
                    FLAG_CONVERSIONE = Int64.Type

                ],
            GetRows = () =>
                let 
                    Source_Account = Json.Document(Web.Contents(outputURL & "Datasource_000003()" ,[Timeout=#duration(0,0,30,0)])),
                    #"Account Converted to Table" = Table.FromRecords({Source_Account}),
                    #"Account Removed Columns" = Table.RemoveColumns(#"Account Converted to Table",{"@odata.context"}),
                    #"Account Expanded value" = Table.ExpandListColumn(#"Account Removed Columns", "value"),
                    Output_Source_Account = Table.ExpandRecordColumn(#"Account Expanded value", "value",{"COD_CONTO", "DESC_CONTO0", "DESC_CONTO1", "DESC_CONTO2", "DESC_CONTO3", "DESC2_CONTO0", "DESC2_CONTO1", "DESC2_CONTO2", "DESC2_CONTO3", "NATURA_CONTO", "TIPO_CONTO", "TIPO_CONVERSIONE", "SEGNO_STANDARD", "ATTRIBUTO1", "ATTRIBUTO2", "ATTRIBUTO3", "ATTRIBUTO4", "ATTRIBUTO5", "FORMATO_SEGNO","TIPO_AGGREGAZIONE_CONTO","FLAG_CONVERSIONE"})
                in 
                    Output_Source_Account
        ]
    ),
    #"Account Duplicated Column" = Table.DuplicateColumn(Output_Source_Account, "COD_CONTO", "COD_CONTO_KEY"),
    #"Account Added Index" = Table.AddIndexColumn(#"Account Duplicated Column", "ID_CONTO", 0, 1, Int64.Type),
    #"Account Duplicated Column2" = Table.DuplicateColumn(#"Account Added Index", "ID_CONTO", "ID_H_CONTO"),
    #"Account Duplicated Column3" = Table.DuplicateColumn(#"Account Duplicated Column2", "ID_CONTO", "ID_FST_CONTO"),
    Account = Table.RenameColumns(#"Account Duplicated Column3",{{"COD_CONTO", "Account Code"}, {"DESC_CONTO0", "Account Description"}, {"DESC_CONTO1", "Account Description 1"}, {"DESC_CONTO2", "Account Description 2"}, {"DESC_CONTO3", "Account Description 3"}, {"DESC2_CONTO0", "Account Alternative Description"}, {"DESC2_CONTO1", "Account Alternative Description 1"}, {"DESC2_CONTO2", "Account Alternative Description 2"}, {"DESC2_CONTO3", "Account Alternative Description 3"}, {"NATURA_CONTO", "Account Nature"}, {"TIPO_CONTO", "Account Type"}, {"TIPO_CONVERSIONE", "Account Conversion Type"}, {"SEGNO_STANDARD", "Account Standard Sign"}, {"ATTRIBUTO1", "Account Attribute 1"}, {"ATTRIBUTO2", "Account Attribute 2"}, {"ATTRIBUTO3", "Account Attribute 3"}, {"ATTRIBUTO4", "Account Attribute 4"}, {"ATTRIBUTO5", "Account Attribute 5"}, {"FORMATO_SEGNO", "Account Format Sign"}, {"TIPO_AGGREGAZIONE_CONTO", "Account Aggregation Type"}, {"FLAG_CONVERSIONE", "Account Conversion Flag"},{"COD_CONTO_KEY", "TGK_ACCOUNT_KEY"}, {"ID_CONTO", "TGK_ACCOUNT_ID"},  {"ID_H_CONTO", "TGK_ACCOUNT_H_ID"}, {"ID_FST_CONTO", "TGK_ACCOUNT_FST_ID"}})
    ,
    
    //Account Hierarchy
    Output_Source_Account_H = 
    Table.View(null,
        [
            GetType = () =>
            type table [
                COD_CONTO_GERARCHIA = Text.Type,
                DESC_CONTO_GERARCHIA = Text.Type,
                COD_CONTO_ELEGER1 = Text.Type,
                DESC_CONTO_ELEGER1 = Text.Type,
                COD_CONTO_ELEGER2 = Text.Type,
                DESC_CONTO_ELEGER2 = Text.Type,
                COD_CONTO_ELEGER3 = Text.Type,
                DESC_CONTO_ELEGER3 = Text.Type,
                COD_CONTO_ELEGER4 = Text.Type,
                DESC_CONTO_ELEGER4 = Text.Type,
                COD_CONTO_ELEGER5 = Text.Type,
                DESC_CONTO_ELEGER5 = Text.Type,
                COD_CONTO_ELEGER6 = Text.Type,
                DESC_CONTO_ELEGER6 = Text.Type,
                COD_CONTO_ELEGER7 = Text.Type,
                DESC_CONTO_ELEGER7 = Text.Type,
                COD_CONTO_ELEGER8 = Text.Type,
                DESC_CONTO_ELEGER8 = Text.Type,
                COD_CONTO_KEY = Text.Type
            ],
            GetRows = () =>
                let 
                    Source_Account_H = Json.Document(Web.Contents(outputURL & "Datasource_000005()" ,[Timeout=#duration(0,0,30,0)])),
                    #"Account_H Converted to Table" = Table.FromRecords({Source_Account_H}),
                    #"Account_H Removed Columns" = Table.RemoveColumns(#"Account_H Converted to Table",{"@odata.context"}),
                    #"Account_H Expanded value" = Table.ExpandListColumn(#"Account_H Removed Columns", "value"),
                    Output_Source_Account_H = Table.ExpandRecordColumn(#"Account_H Expanded value", "value",{ "COD_CONTO_GERARCHIA","DESC_CONTO_GERARCHIA", "COD_CONTO_ELEGER1", "DESC_CONTO_ELEGER1", "COD_CONTO_ELEGER2", "DESC_CONTO_ELEGER2", "COD_CONTO_ELEGER3", "DESC_CONTO_ELEGER3", "COD_CONTO_ELEGER4", "DESC_CONTO_ELEGER4", "COD_CONTO_ELEGER5", "DESC_CONTO_ELEGER5", "COD_CONTO_ELEGER6", "DESC_CONTO_ELEGER6", "COD_CONTO_ELEGER7", "DESC_CONTO_ELEGER7", "COD_CONTO_ELEGER8", "DESC_CONTO_ELEGER8","COD_CONTO_KEY"})
                in 
                    Output_Source_Account_H
        ]
    ),
    #"Account_H Changed Type" = Table.TransformColumnTypes(Output_Source_Account_H,{ {"COD_CONTO_KEY", type text}, {"COD_CONTO_GERARCHIA", type text},{"DESC_CONTO_GERARCHIA", type text}, {"COD_CONTO_ELEGER1", type text}, {"DESC_CONTO_ELEGER1", type text}, {"COD_CONTO_ELEGER2", type text}, {"DESC_CONTO_ELEGER2", type text}, {"COD_CONTO_ELEGER3", type text}, {"DESC_CONTO_ELEGER3", type text}, {"COD_CONTO_ELEGER4", type text}, {"DESC_CONTO_ELEGER4", type text}, {"COD_CONTO_ELEGER5", type text}, {"DESC_CONTO_ELEGER5", type text}, {"COD_CONTO_ELEGER6", type text}, {"DESC_CONTO_ELEGER6", type text}, {"COD_CONTO_ELEGER7", type text}, {"DESC_CONTO_ELEGER7", type text}, {"COD_CONTO_ELEGER8", type text}, {"DESC_CONTO_ELEGER8", type text}}),
    #"Account_H Merged Queries" = Table.NestedJoin( #"Account_H Changed Type", {"COD_CONTO_KEY"}, Account, {"TGK_ACCOUNT_KEY"}, "Account", JoinKind.LeftOuter),
    #"Account_H Expanded Account" = Table.ExpandTableColumn(#"Account_H Merged Queries", "Account", {"TGK_ACCOUNT_ID"}, {"TGK_ACCOUNT_H_ID"}),
    Account_H = Table.RenameColumns(#"Account_H Expanded Account",{{"COD_CONTO_GERARCHIA", "Account Hierarchy Code"}, {"DESC_CONTO_GERARCHIA", "Account Hierarchy Description"}, {"COD_CONTO_ELEGER1", "Account Hierarchy Code Level 1"}, {"COD_CONTO_ELEGER2", "Account Hierarchy Code Level 2"}, {"COD_CONTO_ELEGER3", "Account Hierarchy Code Level 3"}, {"COD_CONTO_ELEGER4", "Account Hierarchy Code Level 4"}, {"COD_CONTO_ELEGER5", "Account Hierarchy Code Level 5"}, {"COD_CONTO_ELEGER6", "Account Hierarchy Code Level 6"}, {"COD_CONTO_ELEGER7", "Account Hierarchy Code Level 7"}, {"COD_CONTO_ELEGER8", "Account Hierarchy Code Level 8"}, {"DESC_CONTO_ELEGER1", "Account Hierarchy Description Level 1"}, {"DESC_CONTO_ELEGER2", "Account Hierarchy Description Level 2"}, {"DESC_CONTO_ELEGER3", "Account Hierarchy Description Level 3"}, {"DESC_CONTO_ELEGER4", "Account Hierarchy Description Level 4"}, {"DESC_CONTO_ELEGER5", "Account Hierarchy Description Level 5"}, {"DESC_CONTO_ELEGER6", "Account Hierarchy Description Level 6"}, {"DESC_CONTO_ELEGER7", "Account Hierarchy Description Level 7"}, {"DESC_CONTO_ELEGER8", "Account Hierarchy Description Level 8"}, {"COD_CONTO_KEY", "TGK_ACCOUNT_H_KEY"}})  
    ,
    //Category
    //Version 1.1.0 
    Output_Source_Category_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_CATEGORIA = Text.Type,
                        DESC_CATEGORIA0 = Text.Type,
                        DESC_CATEGORIA1 = Text.Type,
                        DESC_CATEGORIA2 = Text.Type,
                        DESC_CATEGORIA3 = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Category = Json.Document(Web.Contents(outputURL &"Datasource_000008()?$filter=FM eq '" & Model & "'&$select=COD_CATEGORIA,DESC_CATEGORIA0,DESC_CATEGORIA1,DESC_CATEGORIA2,DESC_CATEGORIA3" ,[Timeout=#duration(0,0,30,0)])),
                        #"Category Converted to Table" = Table.FromRecords({Source_Category}),
                        #"Category Removed Columns" = Table.RemoveColumns(#"Category Converted to Table",{"@odata.context"}),
                        #"Category Expanded value" = Table.ExpandListColumn(#"Category Removed Columns", "value"),
                        Output_Source_Category = Table.ExpandRecordColumn(#"Category Expanded value", "value",{"COD_CATEGORIA","DESC_CATEGORIA0","DESC_CATEGORIA1","DESC_CATEGORIA2","DESC_CATEGORIA3"})                       
                    in 
                        Output_Source_Category
            ]
        ),
    #"1 Category Added Index" = Table.AddIndexColumn(Output_Source_Category_1, "ID_CATEGORIA", 0, 1, Int64.Type),
    #"1 Category Duplicated Column" = Table.DuplicateColumn(#"1 Category Added Index", "COD_CATEGORIA", "COD_CATEGORIA_KEY"),
    #"1 Category Duplicated Column 1" = Table.DuplicateColumn(#"1 Category Duplicated Column", "ID_CATEGORIA", "ID_H_CATEGORIA"),
    #"1 Category Changed Type" = Table.TransformColumnTypes(#"1 Category Duplicated Column 1",{{"COD_CATEGORIA", type text}, {"DESC_CATEGORIA0", type text}, {"DESC_CATEGORIA1", type text}, {"DESC_CATEGORIA2", type text}, {"DESC_CATEGORIA3", type text},{"COD_CATEGORIA_KEY", type text}}),
    Category_1 = Table.RenameColumns(#"1 Category Changed Type",{{"COD_CATEGORIA", "Category Code"}, {"DESC_CATEGORIA0", "Category Description"}, {"DESC_CATEGORIA1", "Category Description 1"}, {"DESC_CATEGORIA2", "Category Description 2"}, {"DESC_CATEGORIA3", "Category Description 3"}, {"COD_CATEGORIA_KEY", "TGK_CATEGORY_KEY"}, {"ID_CATEGORIA", "TGK_CATEGORY_ID"}, {"ID_H_CATEGORIA", "TGK_CATEGORY_H_ID"}})
    ,
    //Version 1.0.0
    Output_Source_Category_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_CATEGORIA = Text.Type,
                        DESC_CATEGORIA0 = Text.Type,
                        DESC_CATEGORIA1 = Text.Type,
                        DESC_CATEGORIA2 = Text.Type,
                        DESC_CATEGORIA3 = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Category = Json.Document(Web.Contents(outputURL &"Datasource_000008()" ,[Timeout=#duration(0,0,30,0)])),
                        #"Category Converted to Table" = Table.FromRecords({Source_Category}),
                        #"Category Removed Columns" = Table.RemoveColumns(#"Category Converted to Table",{"@odata.context"}),
                        #"Category Expanded value" = Table.ExpandListColumn(#"Category Removed Columns", "value"),
                        Output_Source_Category = Table.ExpandRecordColumn(#"Category Expanded value", "value",{"COD_CATEGORIA","DESC_CATEGORIA0","DESC_CATEGORIA1","DESC_CATEGORIA2","DESC_CATEGORIA3"})                       
                    in 
                        Output_Source_Category
            ]
        ),
    #"0 Category Added Index" = Table.AddIndexColumn(Output_Source_Category_0, "ID_CATEGORIA", 0, 1, Int64.Type),
    #"0 Category Duplicated Column" = Table.DuplicateColumn(#"0 Category Added Index", "COD_CATEGORIA", "COD_CATEGORIA_KEY"),
    #"0 Category Duplicated Column 1" = Table.DuplicateColumn(#"0 Category Duplicated Column", "ID_CATEGORIA", "ID_H_CATEGORIA"),
    #"0 Category Changed Type" = Table.TransformColumnTypes(#"0 Category Duplicated Column 1",{{"COD_CATEGORIA", type text}, {"DESC_CATEGORIA0", type text}, {"DESC_CATEGORIA1", type text}, {"DESC_CATEGORIA2", type text}, {"DESC_CATEGORIA3", type text},{"COD_CATEGORIA_KEY", type text}}),
    Category_0 = Table.RenameColumns(#"0 Category Changed Type",{{"COD_CATEGORIA", "Category Code"}, {"DESC_CATEGORIA0", "Category Description"}, {"DESC_CATEGORIA1", "Category Description 1"}, {"DESC_CATEGORIA2", "Category Description 2"}, {"DESC_CATEGORIA3", "Category Description 3"}, {"COD_CATEGORIA_KEY", "TGK_CATEGORY_KEY"}, {"ID_CATEGORIA", "TGK_CATEGORY_ID"}, {"ID_H_CATEGORIA", "TGK_CATEGORY_H_ID"}})
    ,
    Category = List.First(List.Select(VersionCases, each _{0} = Version), null){3}
    ,
    //Category Grouping
    //Version 1.1.0 
    Output_Source_Category_G_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_CATEGORIA_GERARCHIA = Text.Type,                       
                        DESC_CATEGORIA_GERARCHIA = Text.Type,                       
                        COD_CATEGORIA_ELEGER1 = Text.Type,
                        DESC_CATEGORIA_ELEGER1 = Text.Type,
                        COD_CATEGORIA_ELEGER2 = Text.Type,
                        DESC_CATEGORIA_ELEGER2 = Text.Type,
                        COD_CATEGORIA_ELEGER3 = Text.Type,
                        DESC_CATEGORIA_ELEGER3 = Text.Type,
                        COD_CATEGORIA_ELEGER4 = Text.Type,
                        DESC_CATEGORIA_ELEGER4 = Text.Type,
                        COD_CATEGORIA_ELEGER5 = Text.Type,
                        DESC_CATEGORIA_ELEGER5 = Text.Type,
                        COD_CATEGORIA_ELEGER6 = Text.Type,
                        DESC_CATEGORIA_ELEGER6 = Text.Type,
                        COD_CATEGORIA_ELEGER7 = Text.Type,
                        DESC_CATEGORIA_ELEGER7 = Text.Type,
                        COD_CATEGORIA_ELEGER8 = Text.Type,
                        DESC_CATEGORIA_ELEGER8 = Text.Type,
                        COD_CATEGORIA_KEY = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Category_G = Json.Document(Web.Contents(outputURL &"Datasource_000023()?$filter=FM eq '" & Model & "'&$select=COD_CATEGORIA_ELEGER8,DESC_CATEGORIA_GERARCHIA,DESC_CATEGORIA_ELEGER8,COD_CATEGORIA_GERARCHIA,COD_CATEGORIA_ELEGER1,DESC_CATEGORIA_ELEGER1,COD_CATEGORIA_ELEGER2,DESC_CATEGORIA_ELEGER2,COD_CATEGORIA_ELEGER3,DESC_CATEGORIA_ELEGER3,COD_CATEGORIA_ELEGER4,DESC_CATEGORIA_ELEGER4,COD_CATEGORIA_ELEGER5,DESC_CATEGORIA_ELEGER5,COD_CATEGORIA_ELEGER6,DESC_CATEGORIA_ELEGER6,COD_CATEGORIA_ELEGER7,DESC_CATEGORIA_ELEGER7,COD_CATEGORIA_KEY" ,[Timeout=#duration(0,0,30,0)])),
                        #"Category_G Converted to Table" = Table.FromRecords({Source_Category_G}),
                        #"Category_G Removed Columns" = Table.RemoveColumns(#"Category_G Converted to Table",{"@odata.context"}),
                        #"Category_G Expanded value" = Table.ExpandListColumn(#"Category_G Removed Columns", "value"),
                        Output_Source_Category_G = Table.ExpandRecordColumn(#"Category_G Expanded value", "value",{"COD_CATEGORIA_GERARCHIA", "DESC_CATEGORIA_GERARCHIA","COD_CATEGORIA_ELEGER1","DESC_CATEGORIA_ELEGER1","COD_CATEGORIA_ELEGER2","DESC_CATEGORIA_ELEGER2","COD_CATEGORIA_ELEGER3","DESC_CATEGORIA_ELEGER3","COD_CATEGORIA_ELEGER4","DESC_CATEGORIA_ELEGER4","COD_CATEGORIA_ELEGER5","DESC_CATEGORIA_ELEGER5","COD_CATEGORIA_ELEGER6","DESC_CATEGORIA_ELEGER6","COD_CATEGORIA_ELEGER7","DESC_CATEGORIA_ELEGER7","COD_CATEGORIA_ELEGER8","DESC_CATEGORIA_ELEGER8","COD_CATEGORIA_KEY"})                       
                    in 
                        Output_Source_Category_G
            ]
        ),
    #"1 Category_G_Transform" = Table.TransformColumnTypes( Output_Source_Category_G_1,{{"COD_CATEGORIA_ELEGER8", type text},{"DESC_CATEGORIA_GERARCHIA", type text}, {"DESC_CATEGORIA_ELEGER8", type text}, {"COD_CATEGORIA_KEY", type text}, {"COD_CATEGORIA_GERARCHIA", type text}, {"COD_CATEGORIA_ELEGER1", type text}, {"DESC_CATEGORIA_ELEGER1", type text}, {"COD_CATEGORIA_ELEGER2", type text}, {"DESC_CATEGORIA_ELEGER2", type text}, {"COD_CATEGORIA_ELEGER3", type text}, {"DESC_CATEGORIA_ELEGER3", type text}, {"COD_CATEGORIA_ELEGER4", type text}, {"DESC_CATEGORIA_ELEGER4", type text}, {"COD_CATEGORIA_ELEGER5", type text}, {"DESC_CATEGORIA_ELEGER5", type text}, {"COD_CATEGORIA_ELEGER6", type text}, {"DESC_CATEGORIA_ELEGER6", type text}, {"COD_CATEGORIA_ELEGER7", type text}, {"DESC_CATEGORIA_ELEGER7", type text}}),
    #"1 Category_G_Merged_Queries" = Table.NestedJoin(#"1 Category_G_Transform", {"COD_CATEGORIA_KEY"}, Category, {"TGK_CATEGORY_KEY"}, "Category", JoinKind.LeftOuter),
    #"1 Category_G_Expanded" = Table.ExpandTableColumn(#"1 Category_G_Merged_Queries", "Category", {"TGK_CATEGORY_H_ID"}, {"TGK_CATEGORY_H_ID"}),
    Category_G_1  = Table.RenameColumns(#"1 Category_G_Expanded",{{"COD_CATEGORIA_GERARCHIA", "Category Grouping Code"}, {"DESC_CATEGORIA_GERARCHIA", "Category Grouping Description"}, {"COD_CATEGORIA_ELEGER1", "Category Grouping Code Level 1"}, {"COD_CATEGORIA_ELEGER2", "Category Grouping Code Level 2"}, {"COD_CATEGORIA_ELEGER3", "Category Grouping Code Level 3"}, {"COD_CATEGORIA_ELEGER4", "Category Grouping Code Level 4"}, {"COD_CATEGORIA_ELEGER5", "Category Grouping Code Level 5"}, {"COD_CATEGORIA_ELEGER6", "Category Grouping Code Level 6"}, {"COD_CATEGORIA_ELEGER7", "Category Grouping Code Level 7"}, {"COD_CATEGORIA_ELEGER8", "Category Grouping Code Level 8"}, {"DESC_CATEGORIA_ELEGER1", "Category Grouping Description Level 1"}, {"DESC_CATEGORIA_ELEGER2", "Category Grouping Description Level 2"}, {"DESC_CATEGORIA_ELEGER3", "Category Grouping Description Level 3"}, {"DESC_CATEGORIA_ELEGER4", "Category Grouping Description Level 4"}, {"DESC_CATEGORIA_ELEGER5", "Category Grouping Description Level 5"}, {"DESC_CATEGORIA_ELEGER6", "Category Grouping Description Level 6"}, {"DESC_CATEGORIA_ELEGER7", "Category Grouping Description Level 7"}, {"DESC_CATEGORIA_ELEGER8", "Category Grouping Description Level 8"}, {"COD_CATEGORIA_KEY", "TGK_CATEGORY_H_KEY"}})
    ,
    //Version 1.0.0
    Output_Source_Category_G_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_CATEGORIA_GERARCHIA = Text.Type,                       
                        DESC_CATEGORIA_GERARCHIA = Text.Type,                       
                        COD_CATEGORIA_ELEGER1 = Text.Type,
                        DESC_CATEGORIA_ELEGER1 = Text.Type,
                        COD_CATEGORIA_ELEGER2 = Text.Type,
                        DESC_CATEGORIA_ELEGER2 = Text.Type,
                        COD_CATEGORIA_ELEGER3 = Text.Type,
                        DESC_CATEGORIA_ELEGER3 = Text.Type,
                        COD_CATEGORIA_ELEGER4 = Text.Type,
                        DESC_CATEGORIA_ELEGER4 = Text.Type,
                        COD_CATEGORIA_ELEGER5 = Text.Type,
                        DESC_CATEGORIA_ELEGER5 = Text.Type,
                        COD_CATEGORIA_ELEGER6 = Text.Type,
                        DESC_CATEGORIA_ELEGER6 = Text.Type,
                        COD_CATEGORIA_ELEGER7 = Text.Type,
                        DESC_CATEGORIA_ELEGER7 = Text.Type,
                        COD_CATEGORIA_ELEGER8 = Text.Type,
                        DESC_CATEGORIA_ELEGER8 = Text.Type,
                        COD_CATEGORIA_KEY = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Category_G = Json.Document(Web.Contents(outputURL &"Datasource_000023()" ,[Timeout=#duration(0,0,30,0)])),
                        #"Category_G Converted to Table" = Table.FromRecords({Source_Category_G}),
                        #"Category_G Removed Columns" = Table.RemoveColumns(#"Category_G Converted to Table",{"@odata.context"}),
                        #"Category_G Expanded value" = Table.ExpandListColumn(#"Category_G Removed Columns", "value"),
                        Output_Source_Category_G = Table.ExpandRecordColumn(#"Category_G Expanded value", "value",{"COD_CATEGORIA_GERARCHIA", "DESC_CATEGORIA_GERARCHIA","COD_CATEGORIA_ELEGER1","DESC_CATEGORIA_ELEGER1","COD_CATEGORIA_ELEGER2","DESC_CATEGORIA_ELEGER2","COD_CATEGORIA_ELEGER3","DESC_CATEGORIA_ELEGER3","COD_CATEGORIA_ELEGER4","DESC_CATEGORIA_ELEGER4","COD_CATEGORIA_ELEGER5","DESC_CATEGORIA_ELEGER5","COD_CATEGORIA_ELEGER6","DESC_CATEGORIA_ELEGER6","COD_CATEGORIA_ELEGER7","DESC_CATEGORIA_ELEGER7","COD_CATEGORIA_ELEGER8","DESC_CATEGORIA_ELEGER8","COD_CATEGORIA_KEY"})   
                    in 
                        Output_Source_Category_G
            ]
        ),
    #"0 Category_G_Transform" = Table.TransformColumnTypes( Output_Source_Category_G_0,{{"COD_CATEGORIA_ELEGER8", type text},{"DESC_CATEGORIA_GERARCHIA", type text}, {"DESC_CATEGORIA_ELEGER8", type text}, {"COD_CATEGORIA_KEY", type text}, {"COD_CATEGORIA_GERARCHIA", type text}, {"COD_CATEGORIA_ELEGER1", type text}, {"DESC_CATEGORIA_ELEGER1", type text}, {"COD_CATEGORIA_ELEGER2", type text}, {"DESC_CATEGORIA_ELEGER2", type text}, {"COD_CATEGORIA_ELEGER3", type text}, {"DESC_CATEGORIA_ELEGER3", type text}, {"COD_CATEGORIA_ELEGER4", type text}, {"DESC_CATEGORIA_ELEGER4", type text}, {"COD_CATEGORIA_ELEGER5", type text}, {"DESC_CATEGORIA_ELEGER5", type text}, {"COD_CATEGORIA_ELEGER6", type text}, {"DESC_CATEGORIA_ELEGER6", type text}, {"COD_CATEGORIA_ELEGER7", type text}, {"DESC_CATEGORIA_ELEGER7", type text}}),
    #"0 Category_G_Merged_Queries" = Table.NestedJoin(#"0 Category_G_Transform", {"COD_CATEGORIA_KEY"}, Category, {"TGK_CATEGORY_KEY"}, "Category", JoinKind.LeftOuter),
    #"0 Category_G_Expanded" = Table.ExpandTableColumn(#"0 Category_G_Merged_Queries", "Category", {"TGK_CATEGORY_H_ID"}, {"TGK_CATEGORY_H_ID"}),
    Category_G_0  = Table.RenameColumns(#"0 Category_G_Expanded",{{"COD_CATEGORIA_GERARCHIA", "Category Grouping Code"}, {"DESC_CATEGORIA_GERARCHIA", "Category Grouping Description"}, {"COD_CATEGORIA_ELEGER1", "Category Grouping Code Level 1"}, {"COD_CATEGORIA_ELEGER2", "Category Grouping Code Level 2"}, {"COD_CATEGORIA_ELEGER3", "Category Grouping Code Level 3"}, {"COD_CATEGORIA_ELEGER4", "Category Grouping Code Level 4"}, {"COD_CATEGORIA_ELEGER5", "Category Grouping Code Level 5"}, {"COD_CATEGORIA_ELEGER6", "Category Grouping Code Level 6"}, {"COD_CATEGORIA_ELEGER7", "Category Grouping Code Level 7"}, {"COD_CATEGORIA_ELEGER8", "Category Grouping Code Level 8"}, {"DESC_CATEGORIA_ELEGER1", "Category Grouping Description Level 1"}, {"DESC_CATEGORIA_ELEGER2", "Category Grouping Description Level 2"}, {"DESC_CATEGORIA_ELEGER3", "Category Grouping Description Level 3"}, {"DESC_CATEGORIA_ELEGER4", "Category Grouping Description Level 4"}, {"DESC_CATEGORIA_ELEGER5", "Category Grouping Description Level 5"}, {"DESC_CATEGORIA_ELEGER6", "Category Grouping Description Level 6"}, {"DESC_CATEGORIA_ELEGER7", "Category Grouping Description Level 7"}, {"DESC_CATEGORIA_ELEGER8", "Category Grouping Description Level 8"}, {"COD_CATEGORIA_KEY", "TGK_CATEGORY_H_KEY"}})
    ,
    Category_G = List.First(List.Select(VersionCases, each _{0} = Version), null){4}
    ,
    //Change Sign
    Source_ChangeSign = Table.FromRecords({
        [Change Sign Description = "No"],
        [Change Sign Description = "Yes"],
        [Change Sign Description = "Yes By Account"]
    }),
    ChangeSign = Table.TransformColumnTypes(Source_ChangeSign,{{"Change Sign Description", type text}})
    ,
    //Custom Dimension 1
    Output_Source_CustomDimension1 = 
    Table.View(null,
        [
            GetType = () =>
                   type table [
                    COD_DEST1 = text,
                    DESC_DEST10 = text,
                    DESC_DEST11 = text,
                    DESC_DEST12 = text,
                    DESC_DEST13 = text,
                    ATTRIBUTO1 = text,
                    ATTRIBUTO2 = text,
                    ATTRIBUTO3 = text,
                    ATTRIBUTO4 = text,
                    ATTRIBUTO5 = text
                ]
                ,
            GetRows = () =>
                let 
                    Source_CustomDimension1 = Json.Document(Web.Contents(outputURL &"Datasource_000009()" ,[Timeout=#duration(0,0,30,0)])),
                    #"CustomDimension1 Converted to Table" = Table.FromRecords({Source_CustomDimension1}),
                    #"CustomDimension1 Removed Columns" = Table.RemoveColumns(#"CustomDimension1 Converted to Table",{"@odata.context"}),
                    #"CustomDimension1 Expanded value" = Table.ExpandListColumn(#"CustomDimension1 Removed Columns", "value"),
                    Output_Source_CustomDimension1 = Table.ExpandRecordColumn(#"CustomDimension1 Expanded value", "value",{"COD_DEST1","DESC_DEST10","DESC_DEST11","DESC_DEST12","DESC_DEST13","ATTRIBUTO1","ATTRIBUTO2","ATTRIBUTO3","ATTRIBUTO4","ATTRIBUTO5"})
                in 
                    Output_Source_CustomDimension1
        ]
    ),

    #"CustomDimension1 Added Index" = Table.AddIndexColumn(Output_Source_CustomDimension1, "ID_DEST1", 0, 1, Int64.Type),
    #"CustomDimension1 Duplicated Column" = Table.DuplicateColumn(#"CustomDimension1 Added Index", "COD_DEST1", "COD_DEST1_KEY"),
    #"CustomDimension1 Duplicated Column 1" = Table.DuplicateColumn(#"CustomDimension1 Duplicated Column", "ID_DEST1", "ID_H_DEST1"),
    CustomDimension1 = Table.RenameColumns(#"CustomDimension1 Duplicated Column 1",{{"COD_DEST1", "Custom Dimension 1 Code"}, {"DESC_DEST10", "Custom Dimension 1 Description"}, {"DESC_DEST11", "Custom Dimension 1 Description 1"}, {"DESC_DEST12", "Custom Dimension 1 Description 2"}, {"DESC_DEST13", "Custom Dimension 1 Description 3"}, {"ATTRIBUTO1", "Custom Dimension 1 Attribute 1"}, {"ATTRIBUTO2", "Custom Dimension 1 Attribute 2"}, {"ATTRIBUTO3", "Custom Dimension 1 Attribute 3"}, {"ATTRIBUTO4", "Custom Dimension 1 Attribute 4"}, {"ATTRIBUTO5", "Custom Dimension 1 Attribute 5"}, {"ID_DEST1", "TGK_DEST1_ID"}, {"COD_DEST1_KEY", "TGK_DEST1_KEY"}, {"ID_H_DEST1", "TGK_DEST1_H_ID"}})
    ,
    //Custom Dimension 1 Hierarchy
    Output_Source_CustomDimension1_H = 
    Table.View(null,
        [
            GetType = () =>
            type table [
                COD_DEST1_GERARCHIA = Text.Type,
                DESC_DEST1_GERARCHIA = Text.Type,
                COD_DEST1_ELEGER1 = Text.Type,
                DESC_DEST1_ELEGER1 = Text.Type,
                COD_DEST1_ELEGER2 = Text.Type,
                DESC_DEST1_ELEGER2 = Text.Type,
                COD_DEST1_ELEGER3 = Text.Type,
                DESC_DEST1_ELEGER3 = Text.Type,
                COD_DEST1_ELEGER4 = Text.Type,
                DESC_DEST1_ELEGER4 = Text.Type,
                COD_DEST1_ELEGER5 = Text.Type,
                DESC_DEST1_ELEGER5 = Text.Type,
                COD_DEST1_ELEGER6 = Text.Type,
                DESC_DEST1_ELEGER6 = Text.Type,
                COD_DEST1_ELEGER7 = Text.Type,
                DESC_DEST1_ELEGER7 = Text.Type,
                COD_DEST1_ELEGER8 = Text.Type,
                DESC_DEST1_ELEGER8 = Text.Type,
                COD_DEST1_KEY = Text.Type
            ],
            GetRows = () =>
                let 
                    Source_CustomDimension1_H = Json.Document(Web.Contents(outputURL & "Datasource_000015()" ,[Timeout=#duration(0,0,30,0)])),
                    #"CustomDimension1_H Converted to Table" = Table.FromRecords({Source_CustomDimension1_H}),
                    #"CustomDimension1_H Removed Columns" = Table.RemoveColumns(#"CustomDimension1_H Converted to Table",{"@odata.context"}),
                    #"CustomDimension1_H Expanded value" = Table.ExpandListColumn(#"CustomDimension1_H Removed Columns", "value"),
                    Output_Source_CustomDimension1_H = Table.ExpandRecordColumn(#"CustomDimension1_H Expanded value", "value",{ "COD_DEST1_GERARCHIA","DESC_DEST1_GERARCHIA", "COD_DEST1_ELEGER1", "DESC_DEST1_ELEGER1", "COD_DEST1_ELEGER2", "DESC_DEST1_ELEGER2", "COD_DEST1_ELEGER3", "DESC_DEST1_ELEGER3", "COD_DEST1_ELEGER4", "DESC_DEST1_ELEGER4", "COD_DEST1_ELEGER5", "DESC_DEST1_ELEGER5", "COD_DEST1_ELEGER6", "DESC_DEST1_ELEGER6", "COD_DEST1_ELEGER7", "DESC_DEST1_ELEGER7", "COD_DEST1_ELEGER8", "DESC_DEST1_ELEGER8","COD_DEST1_KEY"})
                in 
                    Output_Source_CustomDimension1_H
        ]
    ),
    #"CustomDimension1_H Merged Queries" = Table.NestedJoin(Output_Source_CustomDimension1_H, {"COD_DEST1_KEY"}, CustomDimension1, {"TGK_DEST1_KEY"}, "Custom Dimension 1", JoinKind.LeftOuter),
    #"CustomDimension1_H Expanded Custom Dimension 1" = Table.ExpandTableColumn(#"CustomDimension1_H Merged Queries", "Custom Dimension 1", {"TGK_DEST1_H_ID"}, {"TGK_DEST1_H_ID"}),
    #"CustomDimension1_H Changed Type" = Table.TransformColumnTypes(#"CustomDimension1_H Expanded Custom Dimension 1",{{"COD_DEST1_KEY", type text}, {"COD_DEST1_GERARCHIA", type text}, {"DESC_DEST1_GERARCHIA", type text}, {"COD_DEST1_ELEGER1", type text}, {"DESC_DEST1_ELEGER1", type text}, {"COD_DEST1_ELEGER2", type text}, {"DESC_DEST1_ELEGER2", type text}, {"COD_DEST1_ELEGER3", type text}, {"DESC_DEST1_ELEGER3", type text}, {"COD_DEST1_ELEGER4", type text}, {"DESC_DEST1_ELEGER4", type text}, {"COD_DEST1_ELEGER5", type text}, {"DESC_DEST1_ELEGER5", type text}, {"COD_DEST1_ELEGER6", type text}, {"DESC_DEST1_ELEGER6", type text}, {"COD_DEST1_ELEGER7", type text}, {"DESC_DEST1_ELEGER7", type text}, {"COD_DEST1_ELEGER8", type text}, {"DESC_DEST1_ELEGER8", type text}}),
    CustomDimension1_H = Table.RenameColumns(#"CustomDimension1_H Changed Type",{{"COD_DEST1_GERARCHIA", "Custom Dimension 1 Hierarchy Code"}, {"DESC_DEST1_GERARCHIA", "Custom Dimension 1 Hierarchy Description"}, {"COD_DEST1_ELEGER1", "Custom Dimension 1 Hierarchy Code Level 1"}, {"COD_DEST1_ELEGER2", "Custom Dimension 1 Hierarchy Code Level 2"}, {"COD_DEST1_ELEGER3", "Custom Dimension 1 Hierarchy Code Level 3"}, {"COD_DEST1_ELEGER4", "Custom Dimension 1 Hierarchy Code Level 4"}, {"COD_DEST1_ELEGER5", "Custom Dimension 1 Hierarchy Code Level 5"}, {"COD_DEST1_ELEGER6", "Custom Dimension 1 Hierarchy Code Level 6"}, {"COD_DEST1_ELEGER7", "Custom Dimension 1 Hierarchy Code Level 7"}, {"COD_DEST1_ELEGER8", "Custom Dimension 1 Hierarchy Code Level 8"}, {"DESC_DEST1_ELEGER1", "Custom Dimension 1 Hierarchy Description Level 1"}, {"DESC_DEST1_ELEGER2", "Custom Dimension 1 Hierarchy Description Level 2"}, {"DESC_DEST1_ELEGER3", "Custom Dimension 1 Hierarchy Description Level 3"}, {"DESC_DEST1_ELEGER4", "Custom Dimension 1 Hierarchy Description Level 4"}, {"DESC_DEST1_ELEGER5", "Custom Dimension 1 Hierarchy Description Level 5"}, {"DESC_DEST1_ELEGER6", "Custom Dimension 1 Hierarchy Description Level 6"}, {"DESC_DEST1_ELEGER7", "Custom Dimension 1 Hierarchy Description Level 7"}, {"DESC_DEST1_ELEGER8", "Custom Dimension 1 Hierarchy Description Level 8"}, {"COD_DEST1_KEY", "TGK_DEST1_H_KEY"}})

    ,
    //Custom Dimension 2
    Output_Source_CustomDimension2 =
        Table.View(null,
            [
                GetType = () =>
                    type table [
                        COD_DEST2 = text,
                        DESC_DEST20 = text,
                        DESC_DEST21 = text,
                        DESC_DEST22 = text,
                        DESC_DEST23 = text,
                        ATTRIBUTO1 = text,
                        ATTRIBUTO2 = text,
                        ATTRIBUTO3 = text,
                        ATTRIBUTO4 = text,
                        ATTRIBUTO5 = text
                    ],
                GetRows = () =>
                    let 
                        Source_CustomDimension2 = Json.Document(Web.Contents(outputURL & "Datasource_000010()", [Timeout=#duration(0,0,30,0)])),
                        #"CustomDimension2 Converted to Table" = Table.FromRecords({Source_CustomDimension2}),
                        #"CustomDimension2 Removed Columns" = Table.RemoveColumns(#"CustomDimension2 Converted to Table", {"@odata.context"}),
                        #"CustomDimension2 Expanded value" = Table.ExpandListColumn(#"CustomDimension2 Removed Columns", "value"),
                        Output_Source_CustomDimension2 = Table.ExpandRecordColumn(#"CustomDimension2 Expanded value", "value", {"COD_DEST2", "DESC_DEST20", "DESC_DEST21", "DESC_DEST22", "DESC_DEST23", "ATTRIBUTO1", "ATTRIBUTO2", "ATTRIBUTO3", "ATTRIBUTO4", "ATTRIBUTO5"})
                    in 
                        Output_Source_CustomDimension2
            ]
        ),
    #"CustomDimension2 Added Index" = Table.AddIndexColumn(Output_Source_CustomDimension2, "ID_DEST2", 0, 1, Int64.Type),
    #"CustomDimension2 Duplicated Column" = Table.DuplicateColumn(#"CustomDimension2 Added Index", "COD_DEST2", "COD_DEST2_KEY"),
    #"CustomDimension2 Duplicated Column 1" = Table.DuplicateColumn(#"CustomDimension2 Duplicated Column", "ID_DEST2", "ID_H_DEST2"),
    CustomDimension2 = Table.RenameColumns(#"CustomDimension2 Duplicated Column 1",{{"COD_DEST2", "Custom Dimension 2 Code"}, {"DESC_DEST20", "Custom Dimension 2 Description"}, {"DESC_DEST21", "Custom Dimension 2 Description 1"}, {"DESC_DEST22", "Custom Dimension 2 Description 2"}, {"DESC_DEST23", "Custom Dimension 2 Description 3"}, {"ATTRIBUTO1", "Custom Dimension 2 Attribute 1"}, {"ATTRIBUTO2", "Custom Dimension 2 Attribute 2"}, {"ATTRIBUTO3", "Custom Dimension 2 Attribute 3"}, {"ATTRIBUTO4", "Custom Dimension 2 Attribute 4"}, {"ATTRIBUTO5", "Custom Dimension 2 Attribute 5"}, {"ID_DEST2", "TGK_DEST2_ID"}, {"COD_DEST2_KEY", "TGK_DEST2_KEY"}, {"ID_H_DEST2", "TGK_DEST2_H_ID"}})
    ,
    //Custom Dimension 2 Hierarchy
    Output_Source_CustomDimension2_H = 
    Table.View(null,
        [
            GetType = () =>
            type table [
                COD_DEST2_GERARCHIA = Text.Type,
                DESC_DEST2_GERARCHIA = Text.Type,
                COD_DEST2_ELEGER1 = Text.Type,
                DESC_DEST2_ELEGER1 = Text.Type,
                COD_DEST2_ELEGER2 = Text.Type,
                DESC_DEST2_ELEGER2 = Text.Type,
                COD_DEST2_ELEGER3 = Text.Type,
                DESC_DEST2_ELEGER3 = Text.Type,
                COD_DEST2_ELEGER4 = Text.Type,
                DESC_DEST2_ELEGER4 = Text.Type,
                COD_DEST2_ELEGER5 = Text.Type,
                DESC_DEST2_ELEGER5 = Text.Type,
                COD_DEST2_ELEGER6 = Text.Type,
                DESC_DEST2_ELEGER6 = Text.Type,
                COD_DEST2_ELEGER7 = Text.Type,
                DESC_DEST2_ELEGER7 = Text.Type,
                COD_DEST2_ELEGER8 = Text.Type,
                DESC_DEST2_ELEGER8 = Text.Type,
                COD_DEST2_KEY = Text.Type
            ],
            GetRows = () =>
                let 
                    Source_CustomDimension2_H = Json.Document(Web.Contents(outputURL & "Datasource_000016()" ,[Timeout=#duration(0,0,30,0)])),
                    #"CustomDimension2_H Converted to Table" = Table.FromRecords({Source_CustomDimension2_H}),
                    #"CustomDimension2_H Removed Columns" = Table.RemoveColumns(#"CustomDimension2_H Converted to Table",{"@odata.context"}),
                    #"CustomDimension2_H Expanded value" = Table.ExpandListColumn(#"CustomDimension2_H Removed Columns", "value"),
                    Output_Source_CustomDimension2_H = Table.ExpandRecordColumn(#"CustomDimension2_H Expanded value", "value",{ "COD_DEST2_GERARCHIA","DESC_DEST2_GERARCHIA", "COD_DEST2_ELEGER1", "DESC_DEST2_ELEGER1", "COD_DEST2_ELEGER2", "DESC_DEST2_ELEGER2", "COD_DEST2_ELEGER3", "DESC_DEST2_ELEGER3", "COD_DEST2_ELEGER4", "DESC_DEST2_ELEGER4", "COD_DEST2_ELEGER5", "DESC_DEST2_ELEGER5", "COD_DEST2_ELEGER6", "DESC_DEST2_ELEGER6", "COD_DEST2_ELEGER7", "DESC_DEST2_ELEGER7", "COD_DEST2_ELEGER8", "DESC_DEST2_ELEGER8","COD_DEST2_KEY"})
                in 
                    Output_Source_CustomDimension2_H
        ]
    ),
    #"CustomDimension2_H Merged Queries" = Table.NestedJoin(Output_Source_CustomDimension2_H, {"COD_DEST2_KEY"}, CustomDimension2, {"TGK_DEST2_KEY"}, "Custom Dimension 2", JoinKind.LeftOuter),
    #"CustomDimension2_H Expanded Custom Dimension 2" = Table.ExpandTableColumn(#"CustomDimension2_H Merged Queries", "Custom Dimension 2", {"TGK_DEST2_H_ID"}, {"TGK_DEST2_H_ID"}),
    #"CustomDimension2_H Changed Type" = Table.TransformColumnTypes(#"CustomDimension2_H Expanded Custom Dimension 2",{{"COD_DEST2_KEY", type text}, {"COD_DEST2_GERARCHIA", type text}, {"DESC_DEST2_GERARCHIA", type text}, {"COD_DEST2_ELEGER1", type text}, {"DESC_DEST2_ELEGER1", type text}, {"COD_DEST2_ELEGER2", type text}, {"DESC_DEST2_ELEGER2", type text}, {"COD_DEST2_ELEGER3", type text}, {"DESC_DEST2_ELEGER3", type text}, {"COD_DEST2_ELEGER4", type text}, {"DESC_DEST2_ELEGER4", type text}, {"COD_DEST2_ELEGER5", type text}, {"DESC_DEST2_ELEGER5", type text}, {"COD_DEST2_ELEGER6", type text}, {"DESC_DEST2_ELEGER6", type text}, {"COD_DEST2_ELEGER7", type text}, {"DESC_DEST2_ELEGER7", type text}, {"COD_DEST2_ELEGER8", type text}, {"DESC_DEST2_ELEGER8", type text}}),
    CustomDimension2_H = Table.RenameColumns(#"CustomDimension2_H Changed Type",{{"COD_DEST2_GERARCHIA", "Custom Dimension 2 Hierarchy Code"}, {"DESC_DEST2_GERARCHIA", "Custom Dimension 2 Hierarchy Description"}, {"COD_DEST2_ELEGER1", "Custom Dimension 2 Hierarchy Code Level 1"}, {"COD_DEST2_ELEGER2", "Custom Dimension 2 Hierarchy Code Level 2"}, {"COD_DEST2_ELEGER3", "Custom Dimension 2 Hierarchy Code Level 3"}, {"COD_DEST2_ELEGER4", "Custom Dimension 2 Hierarchy Code Level 4"}, {"COD_DEST2_ELEGER5", "Custom Dimension 2 Hierarchy Code Level 5"}, {"COD_DEST2_ELEGER6", "Custom Dimension 2 Hierarchy Code Level 6"}, {"COD_DEST2_ELEGER7", "Custom Dimension 2 Hierarchy Code Level 7"}, {"COD_DEST2_ELEGER8", "Custom Dimension 2 Hierarchy Code Level 8"}, {"DESC_DEST2_ELEGER1", "Custom Dimension 2 Hierarchy Description Level 1"}, {"DESC_DEST2_ELEGER2", "Custom Dimension 2 Hierarchy Description Level 2"}, {"DESC_DEST2_ELEGER3", "Custom Dimension 2 Hierarchy Description Level 3"}, {"DESC_DEST2_ELEGER4", "Custom Dimension 2 Hierarchy Description Level 4"}, {"DESC_DEST2_ELEGER5", "Custom Dimension 2 Hierarchy Description Level 5"}, {"DESC_DEST2_ELEGER6", "Custom Dimension 2 Hierarchy Description Level 6"}, {"DESC_DEST2_ELEGER7", "Custom Dimension 2 Hierarchy Description Level 7"}, {"DESC_DEST2_ELEGER8", "Custom Dimension 2 Hierarchy Description Level 8"}, {"COD_DEST2_KEY", "TGK_DEST2_H_KEY"}})
    ,
    //Custom Dimension 3
   Output_Source_CustomDimension3 =
        Table.View(null,
            [
                GetType = () =>
                    type table [
                        COD_DEST3 = text,
                        DESC_DEST30 = text,
                        DESC_DEST31 = text,
                        DESC_DEST32 = text,
                        DESC_DEST33 = text,
                        ATTRIBUTO1 = text,
                        ATTRIBUTO2 = text,
                        ATTRIBUTO3 = text,
                        ATTRIBUTO4 = text,
                        ATTRIBUTO5 = text
                    ],
                GetRows = () =>
                    let 
                        Source_CustomDimension3 = Json.Document(Web.Contents(outputURL & "Datasource_000011()", [Timeout=#duration(0,0,30,0)])),
                        #"CustomDimension3 Converted to Table" = Table.FromRecords({Source_CustomDimension3}),
                        #"CustomDimension3 Removed Columns" = Table.RemoveColumns(#"CustomDimension3 Converted to Table", {"@odata.context"}),
                        #"CustomDimension3 Expanded value" = Table.ExpandListColumn(#"CustomDimension3 Removed Columns", "value"),
                        Output_Source_CustomDimension3 = Table.ExpandRecordColumn(#"CustomDimension3 Expanded value", "value", {"COD_DEST3", "DESC_DEST30", "DESC_DEST31", "DESC_DEST32", "DESC_DEST33", "ATTRIBUTO1", "ATTRIBUTO2", "ATTRIBUTO3", "ATTRIBUTO4", "ATTRIBUTO5"})
                    in 
                        Output_Source_CustomDimension3
            ]
        ),
    #"CustomDimension3 Added Index" = Table.AddIndexColumn(Output_Source_CustomDimension3, "ID_DEST3", 0, 1, Int64.Type),
    #"CustomDimension3 Duplicated Column" = Table.DuplicateColumn(#"CustomDimension3 Added Index", "COD_DEST3", "COD_DEST3_KEY"),
    #"CustomDimension3 Duplicated Column 1" = Table.DuplicateColumn(#"CustomDimension3 Duplicated Column", "ID_DEST3", "ID_H_DEST3"),
    CustomDimension3 = Table.RenameColumns(#"CustomDimension3 Duplicated Column 1",{{"COD_DEST3", "Custom Dimension 3 Code"}, {"DESC_DEST30", "Custom Dimension 3 Description"}, {"DESC_DEST31", "Custom Dimension 3 Description 1"}, {"DESC_DEST32", "Custom Dimension 3 Description 2"}, {"DESC_DEST33", "Custom Dimension 3 Description 3"}, {"ATTRIBUTO1", "Custom Dimension 3 Attribute 1"}, {"ATTRIBUTO2", "Custom Dimension 3 Attribute 2"}, {"ATTRIBUTO3", "Custom Dimension 3 Attribute 3"}, {"ATTRIBUTO4", "Custom Dimension 3 Attribute 4"}, {"ATTRIBUTO5", "Custom Dimension 3 Attribute 5"}, {"ID_DEST3", "TGK_DEST3_ID"}, {"COD_DEST3_KEY", "TGK_DEST3_KEY"}, {"ID_H_DEST3", "TGK_DEST3_H_ID"}})
    ,
    //Custom Dimension 3 Hierarchy
    Output_Source_CustomDimension3_H = 
    Table.View(null,
        [
            GetType = () =>
            type table [
                COD_DEST3_GERARCHIA = Text.Type,
                DESC_DEST3_GERARCHIA = Text.Type,
                COD_DEST3_ELEGER1 = Text.Type,
                DESC_DEST3_ELEGER1 = Text.Type,
                COD_DEST3_ELEGER2 = Text.Type,
                DESC_DEST3_ELEGER2 = Text.Type,
                COD_DEST3_ELEGER3 = Text.Type,
                DESC_DEST3_ELEGER3 = Text.Type,
                COD_DEST3_ELEGER4 = Text.Type,
                DESC_DEST3_ELEGER4 = Text.Type,
                COD_DEST3_ELEGER5 = Text.Type,
                DESC_DEST3_ELEGER5 = Text.Type,
                COD_DEST3_ELEGER6 = Text.Type,
                DESC_DEST3_ELEGER6 = Text.Type,
                COD_DEST3_ELEGER7 = Text.Type,
                DESC_DEST3_ELEGER7 = Text.Type,
                COD_DEST3_ELEGER8 = Text.Type,
                DESC_DEST3_ELEGER8 = Text.Type,
                COD_DEST3_KEY = Text.Type
            ],
            GetRows = () =>
                let 
                    Source_CustomDimension3_H = Json.Document(Web.Contents(outputURL & "Datasource_000017()" ,[Timeout=#duration(0,0,30,0)])),
                    #"CustomDimension3_H Converted to Table" = Table.FromRecords({Source_CustomDimension3_H}),
                    #"CustomDimension3_H Removed Columns" = Table.RemoveColumns(#"CustomDimension3_H Converted to Table",{"@odata.context"}),
                    #"CustomDimension3_H Expanded value" = Table.ExpandListColumn(#"CustomDimension3_H Removed Columns", "value"),
                    Output_Source_CustomDimension3_H = Table.ExpandRecordColumn(#"CustomDimension3_H Expanded value", "value",{ "COD_DEST3_GERARCHIA","DESC_DEST3_GERARCHIA", "COD_DEST3_ELEGER1", "DESC_DEST3_ELEGER1", "COD_DEST3_ELEGER2", "DESC_DEST3_ELEGER2", "COD_DEST3_ELEGER3", "DESC_DEST3_ELEGER3", "COD_DEST3_ELEGER4", "DESC_DEST3_ELEGER4", "COD_DEST3_ELEGER5", "DESC_DEST3_ELEGER5", "COD_DEST3_ELEGER6", "DESC_DEST3_ELEGER6", "COD_DEST3_ELEGER7", "DESC_DEST3_ELEGER7", "COD_DEST3_ELEGER8", "DESC_DEST3_ELEGER8","COD_DEST3_KEY"})
                in 
                    Output_Source_CustomDimension3_H
        ]
    ),
    #"CustomDimension3_H Merged Queries" = Table.NestedJoin(Output_Source_CustomDimension3_H, {"COD_DEST3_KEY"}, CustomDimension3, {"TGK_DEST3_KEY"}, "Custom Dimension 3", JoinKind.LeftOuter),
    #"CustomDimension3_H Expanded Custom Dimension 3" = Table.ExpandTableColumn(#"CustomDimension3_H Merged Queries", "Custom Dimension 3", {"TGK_DEST3_H_ID"}, {"TGK_DEST3_H_ID"}),
    #"CustomDimension3_H Changed Type" = Table.TransformColumnTypes(#"CustomDimension3_H Expanded Custom Dimension 3",{{"COD_DEST3_KEY", type text}, {"COD_DEST3_GERARCHIA", type text}, {"DESC_DEST3_GERARCHIA", type text}, {"COD_DEST3_ELEGER1", type text}, {"DESC_DEST3_ELEGER1", type text}, {"COD_DEST3_ELEGER2", type text}, {"DESC_DEST3_ELEGER2", type text}, {"COD_DEST3_ELEGER3", type text}, {"DESC_DEST3_ELEGER3", type text}, {"COD_DEST3_ELEGER4", type text}, {"DESC_DEST3_ELEGER4", type text}, {"COD_DEST3_ELEGER5", type text}, {"DESC_DEST3_ELEGER5", type text}, {"COD_DEST3_ELEGER6", type text}, {"DESC_DEST3_ELEGER6", type text}, {"COD_DEST3_ELEGER7", type text}, {"DESC_DEST3_ELEGER7", type text}, {"COD_DEST3_ELEGER8", type text}, {"DESC_DEST3_ELEGER8", type text}}),
    CustomDimension3_H = Table.RenameColumns(#"CustomDimension3_H Changed Type",{{"COD_DEST3_GERARCHIA", "Custom Dimension 3 Hierarchy Code"}, {"DESC_DEST3_GERARCHIA", "Custom Dimension 3 Hierarchy Description"}, {"COD_DEST3_ELEGER1", "Custom Dimension 3 Hierarchy Code Level 1"}, {"COD_DEST3_ELEGER2", "Custom Dimension 3 Hierarchy Code Level 2"}, {"COD_DEST3_ELEGER3", "Custom Dimension 3 Hierarchy Code Level 3"}, {"COD_DEST3_ELEGER4", "Custom Dimension 3 Hierarchy Code Level 4"}, {"COD_DEST3_ELEGER5", "Custom Dimension 3 Hierarchy Code Level 5"}, {"COD_DEST3_ELEGER6", "Custom Dimension 3 Hierarchy Code Level 6"}, {"COD_DEST3_ELEGER7", "Custom Dimension 3 Hierarchy Code Level 7"}, {"COD_DEST3_ELEGER8", "Custom Dimension 3 Hierarchy Code Level 8"}, {"DESC_DEST3_ELEGER1", "Custom Dimension 3 Hierarchy Description Level 1"}, {"DESC_DEST3_ELEGER2", "Custom Dimension 3 Hierarchy Description Level 2"}, {"DESC_DEST3_ELEGER3", "Custom Dimension 3 Hierarchy Description Level 3"}, {"DESC_DEST3_ELEGER4", "Custom Dimension 3 Hierarchy Description Level 4"}, {"DESC_DEST3_ELEGER5", "Custom Dimension 3 Hierarchy Description Level 5"}, {"DESC_DEST3_ELEGER6", "Custom Dimension 3 Hierarchy Description Level 6"}, {"DESC_DEST3_ELEGER7", "Custom Dimension 3 Hierarchy Description Level 7"}, {"DESC_DEST3_ELEGER8", "Custom Dimension 3 Hierarchy Description Level 8"}, {"COD_DEST3_KEY", "TGK_DEST3_H_KEY"}})
    ,
    //Custom Dimension 4
    Output_Source_CustomDimension4 =
        Table.View(null,
            [
                GetType = () =>
                    type table [
                        COD_DEST4 = text,
                        DESC_DEST40 = text,
                        DESC_DEST41 = text,
                        DESC_DEST42 = text,
                        DESC_DEST43 = text,
                        ATTRIBUTO1 = text,
                        ATTRIBUTO2 = text,
                        ATTRIBUTO3 = text,
                        ATTRIBUTO4 = text,
                        ATTRIBUTO5 = text
                    ],
                GetRows = () =>
                    let 
                        Source_CustomDimension4 = Json.Document(Web.Contents(outputURL & "Datasource_000012()", [Timeout=#duration(0,0,30,0)])),
                        #"CustomDimension4 Converted to Table" = Table.FromRecords({Source_CustomDimension4}),
                        #"CustomDimension4 Removed Columns" = Table.RemoveColumns(#"CustomDimension4 Converted to Table", {"@odata.context"}),
                        #"CustomDimension4 Expanded value" = Table.ExpandListColumn(#"CustomDimension4 Removed Columns", "value"),
                        Output_Source_CustomDimension4 = Table.ExpandRecordColumn(#"CustomDimension4 Expanded value", "value", {"COD_DEST4", "DESC_DEST40", "DESC_DEST41", "DESC_DEST42", "DESC_DEST43", "ATTRIBUTO1", "ATTRIBUTO2", "ATTRIBUTO3", "ATTRIBUTO4", "ATTRIBUTO5"})
                    in 
                        Output_Source_CustomDimension4
            ]
        ),
    
    #"CustomDimension4 Added Index" = Table.AddIndexColumn(Output_Source_CustomDimension4, "ID_DEST4", 0, 1, Int64.Type),
    #"CustomDimension4 Duplicated Column" = Table.DuplicateColumn(#"CustomDimension4 Added Index", "COD_DEST4", "COD_DEST4_KEY"),
    #"CustomDimension4 Duplicated Column 1" = Table.DuplicateColumn(#"CustomDimension4 Duplicated Column", "ID_DEST4", "ID_H_DEST4"),
    CustomDimension4 = Table.RenameColumns(#"CustomDimension4 Duplicated Column 1",{{"COD_DEST4", "Custom Dimension 4 Code"}, {"DESC_DEST40", "Custom Dimension 4 Description"}, {"DESC_DEST41", "Custom Dimension 4 Description 1"}, {"DESC_DEST42", "Custom Dimension 4 Description 2"}, {"DESC_DEST43", "Custom Dimension 4 Description 3"}, {"ATTRIBUTO1", "Custom Dimension 4 Attribute 1"}, {"ATTRIBUTO2", "Custom Dimension 4 Attribute 2"}, {"ATTRIBUTO3", "Custom Dimension 4 Attribute 3"}, {"ATTRIBUTO4", "Custom Dimension 4 Attribute 4"}, {"ATTRIBUTO5", "Custom Dimension 4 Attribute 5"}, {"ID_DEST4", "TGK_DEST4_ID"}, {"COD_DEST4_KEY", "TGK_DEST4_KEY"},  {"ID_H_DEST4", "TGK_DEST4_H_ID"}})
    ,
    //Custom Dimension 4 Hierarchy
    Output_Source_CustomDimension4_H = 
    Table.View(null,
        [
            GetType = () =>
            type table [
                COD_DEST4_GERARCHIA = Text.Type,
                DESC_DEST4_GERARCHIA = Text.Type,
                COD_DEST4_ELEGER1 = Text.Type,
                DESC_DEST4_ELEGER1 = Text.Type,
                COD_DEST4_ELEGER2 = Text.Type,
                DESC_DEST4_ELEGER2 = Text.Type,
                COD_DEST4_ELEGER3 = Text.Type,
                DESC_DEST4_ELEGER3 = Text.Type,
                COD_DEST4_ELEGER4 = Text.Type,
                DESC_DEST4_ELEGER4 = Text.Type,
                COD_DEST4_ELEGER5 = Text.Type,
                DESC_DEST4_ELEGER5 = Text.Type,
                COD_DEST4_ELEGER6 = Text.Type,
                DESC_DEST4_ELEGER6 = Text.Type,
                COD_DEST4_ELEGER7 = Text.Type,
                DESC_DEST4_ELEGER7 = Text.Type,
                COD_DEST4_ELEGER8 = Text.Type,
                DESC_DEST4_ELEGER8 = Text.Type,
                COD_DEST4_KEY = Text.Type
            ],
            GetRows = () =>
                let 
                    Source_CustomDimension4_H = Json.Document(Web.Contents(outputURL & "Datasource_000018()" ,[Timeout=#duration(0,0,30,0)])),
                    #"CustomDimension4_H Converted to Table" = Table.FromRecords({Source_CustomDimension4_H}),
                    #"CustomDimension4_H Removed Columns" = Table.RemoveColumns(#"CustomDimension4_H Converted to Table",{"@odata.context"}),
                    #"CustomDimension4_H Expanded value" = Table.ExpandListColumn(#"CustomDimension4_H Removed Columns", "value"),
                    Output_Source_CustomDimension4_H = Table.ExpandRecordColumn(#"CustomDimension4_H Expanded value", "value",{ "COD_DEST4_GERARCHIA","DESC_DEST4_GERARCHIA", "COD_DEST4_ELEGER1", "DESC_DEST4_ELEGER1", "COD_DEST4_ELEGER2", "DESC_DEST4_ELEGER2", "COD_DEST4_ELEGER3", "DESC_DEST4_ELEGER3", "COD_DEST4_ELEGER4", "DESC_DEST4_ELEGER4", "COD_DEST4_ELEGER5", "DESC_DEST4_ELEGER5", "COD_DEST4_ELEGER6", "DESC_DEST4_ELEGER6", "COD_DEST4_ELEGER7", "DESC_DEST4_ELEGER7", "COD_DEST4_ELEGER8", "DESC_DEST4_ELEGER8","COD_DEST4_KEY"})
                in 
                    Output_Source_CustomDimension4_H
        ]
    ),
    #"CustomDimension4_H Merged Queries" = Table.NestedJoin(Output_Source_CustomDimension4_H, {"COD_DEST4_KEY"}, CustomDimension4, {"TGK_DEST4_KEY"}, "Custom Dimension 4", JoinKind.LeftOuter),
    #"CustomDimension4_H Expanded Custom Dimension 4" = Table.ExpandTableColumn(#"CustomDimension4_H Merged Queries", "Custom Dimension 4", {"TGK_DEST4_H_ID"}, {"TGK_DEST4_H_ID"}),
    #"CustomDimension4_H Changed Type" = Table.TransformColumnTypes(#"CustomDimension4_H Expanded Custom Dimension 4",{{"COD_DEST4_KEY", type text}, {"COD_DEST4_GERARCHIA", type text}, {"DESC_DEST4_GERARCHIA", type text}, {"COD_DEST4_ELEGER1", type text}, {"DESC_DEST4_ELEGER1", type text}, {"COD_DEST4_ELEGER2", type text}, {"DESC_DEST4_ELEGER2", type text}, {"COD_DEST4_ELEGER3", type text}, {"DESC_DEST4_ELEGER3", type text}, {"COD_DEST4_ELEGER4", type text}, {"DESC_DEST4_ELEGER4", type text}, {"COD_DEST4_ELEGER5", type text}, {"DESC_DEST4_ELEGER5", type text}, {"COD_DEST4_ELEGER6", type text}, {"DESC_DEST4_ELEGER6", type text}, {"COD_DEST4_ELEGER7", type text}, {"DESC_DEST4_ELEGER7", type text}, {"COD_DEST4_ELEGER8", type text}, {"DESC_DEST4_ELEGER8", type text}}),
    CustomDimension4_H = Table.RenameColumns(#"CustomDimension4_H Changed Type",{{"COD_DEST4_GERARCHIA", "Custom Dimension 4 Hierarchy Code"}, {"DESC_DEST4_GERARCHIA", "Custom Dimension 4 Hierarchy Description"}, {"COD_DEST4_ELEGER1", "Custom Dimension 4 Hierarchy Code Level 1"}, {"COD_DEST4_ELEGER2", "Custom Dimension 4 Hierarchy Code Level 2"}, {"COD_DEST4_ELEGER3", "Custom Dimension 4 Hierarchy Code Level 3"}, {"COD_DEST4_ELEGER4", "Custom Dimension 4 Hierarchy Code Level 4"}, {"COD_DEST4_ELEGER5", "Custom Dimension 4 Hierarchy Code Level 5"}, {"COD_DEST4_ELEGER6", "Custom Dimension 4 Hierarchy Code Level 6"}, {"COD_DEST4_ELEGER7", "Custom Dimension 4 Hierarchy Code Level 7"}, {"COD_DEST4_ELEGER8", "Custom Dimension 4 Hierarchy Code Level 8"}, {"DESC_DEST4_ELEGER1", "Custom Dimension 4 Hierarchy Description Level 1"}, {"DESC_DEST4_ELEGER2", "Custom Dimension 4 Hierarchy Description Level 2"}, {"DESC_DEST4_ELEGER3", "Custom Dimension 4 Hierarchy Description Level 3"}, {"DESC_DEST4_ELEGER4", "Custom Dimension 4 Hierarchy Description Level 4"}, {"DESC_DEST4_ELEGER5", "Custom Dimension 4 Hierarchy Description Level 5"}, {"DESC_DEST4_ELEGER6", "Custom Dimension 4 Hierarchy Description Level 6"}, {"DESC_DEST4_ELEGER7", "Custom Dimension 4 Hierarchy Description Level 7"}, {"DESC_DEST4_ELEGER8", "Custom Dimension 4 Hierarchy Description Level 8"}, {"COD_DEST4_KEY", "TGK_DEST4_H_KEY"}})
    ,
    //Custom Dimension 5
    Output_Source_CustomDimension5 =
    Table.View(null,
            [
                GetType = () =>
                    type table [
                        COD_DEST5 = text,
                        DESC_DEST50 = text,
                        DESC_DEST51 = text,
                        DESC_DEST52 = text,
                        DESC_DEST53 = text,
                        ATTRIBUTO1 = text,
                        ATTRIBUTO2 = text,
                        ATTRIBUTO3 = text,
                        ATTRIBUTO4 = text,
                        ATTRIBUTO5 = text
                    ],
                GetRows = () =>
                    let 
                        Source_CustomDimension5 = Json.Document(Web.Contents(outputURL & "Datasource_000013()", [Timeout=#duration(0,0,30,0)])),
                        #"CustomDimension5 Converted to Table" = Table.FromRecords({Source_CustomDimension5}),
                        #"CustomDimension5 Removed Columns" = Table.RemoveColumns(#"CustomDimension5 Converted to Table", {"@odata.context"}),
                        #"CustomDimension5 Expanded value" = Table.ExpandListColumn(#"CustomDimension5 Removed Columns", "value"),
                        Output_Source_CustomDimension5 = Table.ExpandRecordColumn(#"CustomDimension5 Expanded value", "value", {"COD_DEST5", "DESC_DEST50", "DESC_DEST51", "DESC_DEST52", "DESC_DEST53", "ATTRIBUTO1", "ATTRIBUTO2", "ATTRIBUTO3", "ATTRIBUTO4", "ATTRIBUTO5"})
                    in 
                        Output_Source_CustomDimension5
            ]
        ),
    
    #"CustomDimension5 Added Index" = Table.AddIndexColumn(Output_Source_CustomDimension5, "ID_DEST5", 0, 1, Int64.Type),
    #"CustomDimension5 Duplicated Column" = Table.DuplicateColumn(#"CustomDimension5 Added Index", "COD_DEST5", "COD_DEST5_KEY"),
    #"CustomDimension5 Duplicated Column 1" = Table.DuplicateColumn(#"CustomDimension5 Duplicated Column", "ID_DEST5", "ID_H_DEST5"),
    CustomDimension5 = Table.RenameColumns(#"CustomDimension5 Duplicated Column 1",{{"COD_DEST5", "Custom Dimension 5 Code"}, {"DESC_DEST50", "Custom Dimension 5 Description"}, {"DESC_DEST51", "Custom Dimension 5 Description 1"}, {"DESC_DEST52", "Custom Dimension 5 Description 2"}, {"DESC_DEST53", "Custom Dimension 5 Description 3"}, {"ATTRIBUTO1", "Custom Dimension 5 Attribute 1"}, {"ATTRIBUTO2", "Custom Dimension 5 Attribute 2"}, {"ATTRIBUTO3", "Custom Dimension 5 Attribute 3"}, {"ATTRIBUTO4", "Custom Dimension 5 Attribute 4"}, {"ATTRIBUTO5", "Custom Dimension 5 Attribute 5"}, {"ID_DEST5", "TGK_DEST5_ID"}, {"COD_DEST5_KEY", "TGK_DEST5_KEY"}, {"ID_H_DEST5", "TGK_DEST5_H_ID"}})
    ,
    //Custom Dimension 5 Hierarchy
    Output_Source_CustomDimension5_H = 
    Table.View(null,
        [
            GetType = () =>
            type table [
                COD_DEST5_GERARCHIA = Text.Type,
                DESC_DEST5_GERARCHIA = Text.Type,
                COD_DEST5_ELEGER1 = Text.Type,
                DESC_DEST5_ELEGER1 = Text.Type,
                COD_DEST5_ELEGER2 = Text.Type,
                DESC_DEST5_ELEGER2 = Text.Type,
                COD_DEST5_ELEGER3 = Text.Type,
                DESC_DEST5_ELEGER3 = Text.Type,
                COD_DEST5_ELEGER4 = Text.Type,
                DESC_DEST5_ELEGER4 = Text.Type,
                COD_DEST5_ELEGER5 = Text.Type,
                DESC_DEST5_ELEGER5 = Text.Type,
                COD_DEST5_ELEGER6 = Text.Type,
                DESC_DEST5_ELEGER6 = Text.Type,
                COD_DEST5_ELEGER7 = Text.Type,
                DESC_DEST5_ELEGER7 = Text.Type,
                COD_DEST5_ELEGER8 = Text.Type,
                DESC_DEST5_ELEGER8 = Text.Type,
                COD_DEST5_KEY = Text.Type
            ],
            GetRows = () =>
                let 
                    Source_CustomDimension5_H = Json.Document(Web.Contents(outputURL & "Datasource_000019()" ,[Timeout=#duration(0,0,30,0)])),
                    #"CustomDimension5_H Converted to Table" = Table.FromRecords({Source_CustomDimension5_H}),
                    #"CustomDimension5_H Removed Columns" = Table.RemoveColumns(#"CustomDimension5_H Converted to Table",{"@odata.context"}),
                    #"CustomDimension5_H Expanded value" = Table.ExpandListColumn(#"CustomDimension5_H Removed Columns", "value"),
                    Output_Source_CustomDimension5_H = Table.ExpandRecordColumn(#"CustomDimension5_H Expanded value", "value",{ "COD_DEST5_GERARCHIA","DESC_DEST5_GERARCHIA", "COD_DEST5_ELEGER1", "DESC_DEST5_ELEGER1", "COD_DEST5_ELEGER2", "DESC_DEST5_ELEGER2", "COD_DEST5_ELEGER3", "DESC_DEST5_ELEGER3", "COD_DEST5_ELEGER4", "DESC_DEST5_ELEGER4", "COD_DEST5_ELEGER5", "DESC_DEST5_ELEGER5", "COD_DEST5_ELEGER6", "DESC_DEST5_ELEGER6", "COD_DEST5_ELEGER7", "DESC_DEST5_ELEGER7", "COD_DEST5_ELEGER8", "DESC_DEST5_ELEGER8","COD_DEST5_KEY"})
                in 
                    Output_Source_CustomDimension5_H
        ]
    ),
    #"CustomDimension5_H Merged Queries" = Table.NestedJoin(Output_Source_CustomDimension5_H, {"COD_DEST5_KEY"},CustomDimension5, {"TGK_DEST5_KEY"}, "Custom Dimension 5", JoinKind.LeftOuter),
    #"CustomDimension5_H Expanded Custom Dimension 5" = Table.ExpandTableColumn(#"CustomDimension5_H Merged Queries", "Custom Dimension 5", {"TGK_DEST5_H_ID"}, {"TGK_DEST5_H_ID"}),
    #"CustomDimension5_H Changed Type" = Table.TransformColumnTypes(#"CustomDimension5_H Expanded Custom Dimension 5",{{"COD_DEST5_KEY", type text}, {"COD_DEST5_GERARCHIA", type text}, {"DESC_DEST5_GERARCHIA", type text}, {"COD_DEST5_ELEGER1", type text}, {"DESC_DEST5_ELEGER1", type text}, {"COD_DEST5_ELEGER2", type text}, {"DESC_DEST5_ELEGER2", type text}, {"COD_DEST5_ELEGER3", type text}, {"DESC_DEST5_ELEGER3", type text}, {"COD_DEST5_ELEGER4", type text}, {"DESC_DEST5_ELEGER4", type text}, {"COD_DEST5_ELEGER5", type text}, {"DESC_DEST5_ELEGER5", type text}, {"COD_DEST5_ELEGER6", type text}, {"DESC_DEST5_ELEGER6", type text}, {"COD_DEST5_ELEGER7", type text}, {"DESC_DEST5_ELEGER7", type text}, {"COD_DEST5_ELEGER8", type text}, {"DESC_DEST5_ELEGER8", type text}}),
    CustomDimension5_H = Table.RenameColumns(#"CustomDimension5_H Changed Type",{{"COD_DEST5_GERARCHIA", "Custom Dimension 5 Hierarchy Code"}, {"DESC_DEST5_GERARCHIA", "Custom Dimension 5 Hierarchy Description"}, {"COD_DEST5_ELEGER1", "Custom Dimension 5 Hierarchy Code Level 1"}, {"COD_DEST5_ELEGER2", "Custom Dimension 5 Hierarchy Code Level 2"}, {"COD_DEST5_ELEGER3", "Custom Dimension 5 Hierarchy Code Level 3"}, {"COD_DEST5_ELEGER4", "Custom Dimension 5 Hierarchy Code Level 4"}, {"COD_DEST5_ELEGER5", "Custom Dimension 5 Hierarchy Code Level 5"}, {"COD_DEST5_ELEGER6", "Custom Dimension 5 Hierarchy Code Level 6"}, {"COD_DEST5_ELEGER7", "Custom Dimension 5 Hierarchy Code Level 7"}, {"COD_DEST5_ELEGER8", "Custom Dimension 5 Hierarchy Code Level 8"}, {"DESC_DEST5_ELEGER1", "Custom Dimension 5 Hierarchy Description Level 1"}, {"DESC_DEST5_ELEGER2", "Custom Dimension 5 Hierarchy Description Level 2"}, {"DESC_DEST5_ELEGER3", "Custom Dimension 5 Hierarchy Description Level 3"}, {"DESC_DEST5_ELEGER4", "Custom Dimension 5 Hierarchy Description Level 4"}, {"DESC_DEST5_ELEGER5", "Custom Dimension 5 Hierarchy Description Level 5"}, {"DESC_DEST5_ELEGER6", "Custom Dimension 5 Hierarchy Description Level 6"}, {"DESC_DEST5_ELEGER7", "Custom Dimension 5 Hierarchy Description Level 7"}, {"DESC_DEST5_ELEGER8", "Custom Dimension 5 Hierarchy Description Level 8"}, {"COD_DEST5_KEY", "TGK_DEST5_H_KEY"}})
    ,
    //Custom Dimension 2 CTP
    Source_Dest2_CTP = Table.SelectColumns(CustomDimension2,{ "Custom Dimension 2 Code","Custom Dimension 2 Description", "Custom Dimension 2 Description 1", "Custom Dimension 2 Description 2", "Custom Dimension 2 Description 3", "Custom Dimension 2 Attribute 1","Custom Dimension 2 Attribute 2", "Custom Dimension 2 Attribute 3", "Custom Dimension 2 Attribute 4", "Custom Dimension 2 Attribute 5","TGK_DEST2_KEY"}),
    #"Custom Dimension 2 CTP Insert Row" = Table.InsertRows(Source_Dest2_CTP,0,{[Custom Dimension 2 Code="$NET",Custom Dimension 2 Description="3rd party",Custom Dimension 2 Description 1=null,Custom Dimension 2 Description 2=null,Custom Dimension 2 Description 3=null,Custom Dimension 2 Attribute 1=null,Custom Dimension 2 Attribute 2=null,Custom Dimension 2 Attribute 3=null,Custom Dimension 2 Attribute 4=null,Custom Dimension 2 Attribute 5=null, TGK_DEST2_KEY="$NET"]}),
    #"Custom Dimension 2 CTP Added Index" = Table.AddIndexColumn(#"Custom Dimension 2 CTP Insert Row", "TGK_DEST2_CTP_ID", 0, 1, Int64.Type),
    #"Custom Dimension 2 CTP Renamed Columns" = Table.RenameColumns( #"Custom Dimension 2 CTP Added Index",{{"Custom Dimension 2 Code", "Custom Dimension 2 CTP Code"},{"Custom Dimension 2 Description","Custom Dimension 2 CTP Description"},{ "Custom Dimension 2 Description 1", "Custom Dimension 2 CTP Description 1"},{ "Custom Dimension 2 Description 2", "Custom Dimension 2 CTP Description 2"},{ "Custom Dimension 2 Description 3", "Custom Dimension 2 CTP Description 3"},{ "Custom Dimension 2 Attribute 1", "Custom Dimension 2 CTP Attribute 1"},{"Custom Dimension 2 Attribute 2","Custom Dimension 2 CTP Attribute 2"},{ "Custom Dimension 2 Attribute 3", "Custom Dimension 2 CTP Attribute 3"},{ "Custom Dimension 2 Attribute 4", "Custom Dimension 2 CTP Attribute 4"},{ "Custom Dimension 2 Attribute 5", "Custom Dimension 2 CTP Attribute 5"},{ "TGK_DEST2_KEY", "TGK_DEST2_CTP_KEY"}}),
    CustomDimension_2_CTP = Table.DuplicateColumn(#"Custom Dimension 2 CTP Renamed Columns", "TGK_DEST2_CTP_ID", "TGK_DEST2_CTP_H_ID")
    ,
    //Custom Dimension 2 CTP Hierarchy
    Source_CustomDimension2_CTP_H = Table.SelectColumns(CustomDimension2_H,{
        "Custom Dimension 2 Hierarchy Code",
        "Custom Dimension 2 Hierarchy Description",
        "Custom Dimension 2 Hierarchy Code Level 1",
        "Custom Dimension 2 Hierarchy Description Level 1",
        "Custom Dimension 2 Hierarchy Code Level 2",
        "Custom Dimension 2 Hierarchy Description Level 2",
        "Custom Dimension 2 Hierarchy Code Level 3",
        "Custom Dimension 2 Hierarchy Description Level 3",
        "Custom Dimension 2 Hierarchy Code Level 4",
        "Custom Dimension 2 Hierarchy Description Level 4",
        "Custom Dimension 2 Hierarchy Code Level 5",
        "Custom Dimension 2 Hierarchy Description Level 5",
        "Custom Dimension 2 Hierarchy Code Level 6",
        "Custom Dimension 2 Hierarchy Description Level 6",
        "Custom Dimension 2 Hierarchy Code Level 7",
        "Custom Dimension 2 Hierarchy Description Level 7",
        "Custom Dimension 2 Hierarchy Code Level 8",
        "Custom Dimension 2 Hierarchy Description Level 8",
        "TGK_DEST2_H_KEY"
    }
    ),
    #"Custom Dimension 2 CTP H Transform Description" = Table.TransformColumns(Source_CustomDimension2_CTP_H, {{"Custom Dimension 2 Hierarchy Description",each Text.Combine({(_), " Counterparty"})},{"Custom Dimension 2 Hierarchy Description Level 8",each Text.Combine({(_), " Counterparty"})}}),
    #"Custom Dimension 2 CTP H Hierarchy List" = Table.Distinct(Table.SelectColumns(#"Custom Dimension 2 CTP H Transform Description",{"Custom Dimension 2 Hierarchy Code","Custom Dimension 2 Hierarchy Description","Custom Dimension 2 Hierarchy Code Level 8","Custom Dimension 2 Hierarchy Description Level 8"})),
    #"Custom Dimension 2 CTP H Added 3rd party" = Table.AddColumn( #"Custom Dimension 2 CTP H Hierarchy List", "Custom Dimension 2 Hierarchy Code Level 7", each "[$NET]"),
    #"Custom Dimension 2 CTP H Added 3rd party key" = Table.AddColumn( #"Custom Dimension 2 CTP H Added 3rd party" , "TGK_DEST2_H_KEY", each "$NET"),
    #"Custom Dimension 2 CTP H Added 3rd party Description" = Table.AddColumn(  #"Custom Dimension 2 CTP H Added 3rd party key", "Custom Dimension 2 Hierarchy Description Level 7", each "[$NET - 3rd party]"),
    #"Custom Dimension 2 CTP H Appended Query" = Table.Combine({#"Custom Dimension 2 CTP H Transform Description",  #"Custom Dimension 2 CTP H Added 3rd party Description"}),  
    #"Custom Dimension 2 CTP H Check Null" = if Record.Field(Table.First(CustomDimension2_H), "Custom Dimension 2 Hierarchy Code")= null then Source_CustomDimension2_CTP_H else #"Custom Dimension 2 CTP H Appended Query",
    #"Custom Dimension 2 CTP H Merged Queries" = Table.NestedJoin(#"Custom Dimension 2 CTP H Check Null", {"TGK_DEST2_H_KEY"}, CustomDimension_2_CTP, {"TGK_DEST2_CTP_KEY"}, "Custom Dimension 2 CTP", JoinKind.LeftOuter),
    #"Custom Dimension 2 CTP H Expanded" = Table.ExpandTableColumn(#"Custom Dimension 2 CTP H Merged Queries", "Custom Dimension 2 CTP", {"TGK_DEST2_CTP_ID"}, {"TGK_DEST2_CTP_H_ID"}),
    #"Custom Dimension 2 CTP H RenameColumns"  = Table.RenameColumns(#"Custom Dimension 2 CTP H Expanded",{{"Custom Dimension 2 Hierarchy Code", "Custom Dimension 2 CTP Hierarchy Code"}, {"Custom Dimension 2 Hierarchy Description", "Custom Dimension 2 CTP Hierarchy Description"}, {"Custom Dimension 2 Hierarchy Code Level 1", "Custom Dimension 2 CTP Hierarchy Code Level 1"}, {"Custom Dimension 2 Hierarchy Code Level 2", "Custom Dimension 2 CTP Hierarchy Code Level 2"}, {"Custom Dimension 2 Hierarchy Code Level 3", "Custom Dimension 2 CTP Hierarchy Code Level 3"}, {"Custom Dimension 2 Hierarchy Code Level 4", "Custom Dimension 2 CTP Hierarchy Code Level 4"}, {"Custom Dimension 2 Hierarchy Code Level 5", "Custom Dimension 2 CTP Hierarchy Code Level 5"}, {"Custom Dimension 2 Hierarchy Code Level 6", "Custom Dimension 2 CTP Hierarchy Code Level 6"}, {"Custom Dimension 2 Hierarchy Code Level 7", "Custom Dimension 2 CTP Hierarchy Code Level 7"}, {"Custom Dimension 2 Hierarchy Code Level 8", "Custom Dimension 2 CTP Hierarchy Code Level 8"}, {"Custom Dimension 2 Hierarchy Description Level 1", "Custom Dimension 2 CTP Hierarchy Description Level 1"}, {"Custom Dimension 2 Hierarchy Description Level 2", "Custom Dimension 2 CTP Hierarchy Description Level 2"}, {"Custom Dimension 2 Hierarchy Description Level 3", "Custom Dimension 2 CTP Hierarchy Description Level 3"}, {"Custom Dimension 2 Hierarchy Description Level 4", "Custom Dimension 2 CTP Hierarchy Description Level 4"}, {"Custom Dimension 2 Hierarchy Description Level 5", "Custom Dimension 2 CTP Hierarchy Description Level 5"}, {"Custom Dimension 2 Hierarchy Description Level 6", "Custom Dimension 2 CTP Hierarchy Description Level 6"}, {"Custom Dimension 2 Hierarchy Description Level 7", "Custom Dimension 2 CTP Hierarchy Description Level 7"}, {"Custom Dimension 2 Hierarchy Description Level 8", "Custom Dimension 2 CTP Hierarchy Description Level 8"}, {"TGK_DEST2_H_KEY", "TGK_DEST2_CTP_H_KEY"}}),
    CustomDimension2_CTP_H = Table.TransformColumnTypes(  #"Custom Dimension 2 CTP H RenameColumns"  ,{{"TGK_DEST2_CTP_H_KEY", type text}, {"Custom Dimension 2 CTP Hierarchy Description Level 8", type text}, {"Custom Dimension 2 CTP Hierarchy Description Level 7", type text}, {"Custom Dimension 2 CTP Hierarchy Code Level 7", type text}, {"Custom Dimension 2 CTP Hierarchy Description", type text}})
    ,
    //Custom Dimension 2 Segment
    Dest2SegmentDSCode = List.Accumulate(Dimensions_ModelSwitch, "000028()", (state, current) =>
            if current{0} = Model then current{2} else state
        ),
    //Version 1.1.0 
    Output_Source_Dest2Segment_1 = 
        Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_DEST2_SEGMENT_KEY = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Dest2Segment = Json.Document(Web.Contents(outputURL & "Datasource_" & Dest2SegmentDSCode,[Timeout=#duration(0,0,30,0)])),
                        #"Dest2Segment Converted to Table" = Table.FromRecords({Source_Dest2Segment}),
                        #"Dest2Segment Removed Columns" = Table.RemoveColumns(#"Dest2Segment Converted to Table",{"@odata.context"}),
                        #"Dest2Segment Expanded value" = Table.ExpandListColumn(#"Dest2Segment Removed Columns", "value"),
                        Output_Source_Dest2Segment = Table.ExpandRecordColumn(#"Dest2Segment Expanded value", "value",{"COD_DEST2_SEGMENT_KEY"})
                    in 
                        Output_Source_Dest2Segment
            ]
        ),
    #"1 DEST2_SEGMENT Changed Type" = Table.TransformColumnTypes(Output_Source_Dest2Segment_1,{{"COD_DEST2_SEGMENT_KEY", type text}}),
    #"1 DEST2_SEGMENT Added Index" = Table.AddIndexColumn(#"1 DEST2_SEGMENT Changed Type", "TGK_DEST2_SEGMENT_ID", 0, 1, Int64.Type),
    #"1 DEST2_SEGMENT Duplicated Column" = Table.DuplicateColumn(#"1 DEST2_SEGMENT Added Index", "TGK_DEST2_SEGMENT_ID", "TGK_DEST2_SEGMENT_H_ID"),
    Dest2_Segment_1 = Table.RenameColumns(#"1 DEST2_SEGMENT Duplicated Column",{{"COD_DEST2_SEGMENT_KEY", "TGK_DEST2_SEGMENT_KEY"}})
    ,

    //Version 1.0.0 
    Output_Source_Dest2Segment_0 = 
        Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_DEST2_SEGMENT_KEY = Text.Type
                        
                    ],
                GetRows = () =>
                    let 
                        Source_Dest2Segment = Json.Document(Web.Contents(outputURL & "Datasource_000028()" ,[Timeout=#duration(0,0,30,0)])),
                        #"Dest2Segment Converted to Table" = Table.FromRecords({Source_Dest2Segment}),
                        #"Dest2Segment Removed Columns" = Table.RemoveColumns(#"Dest2Segment Converted to Table",{"@odata.context"}),
                        #"Dest2Segment Expanded value" = Table.ExpandListColumn(#"Dest2Segment Removed Columns", "value"),
                        Output_Source_Dest2Segment = Table.ExpandRecordColumn(#"Dest2Segment Expanded value", "value",{"COD_DEST2_SEGMENT_KEY"})
                    in 
                        Output_Source_Dest2Segment
            ]
        ),
    #"0 DEST2_SEGMENT Changed Type" = Table.TransformColumnTypes(Output_Source_Dest2Segment_0,{{"COD_DEST2_SEGMENT_KEY", type text}}),
    #"0 DEST2_SEGMENT Added Index" = Table.AddIndexColumn(#"0 DEST2_SEGMENT Changed Type", "TGK_DEST2_SEGMENT_ID", 0, 1, Int64.Type),
    #"0 DEST2_SEGMENT Duplicated Column" = Table.DuplicateColumn(#"0 DEST2_SEGMENT Added Index", "TGK_DEST2_SEGMENT_ID", "TGK_DEST2_SEGMENT_H_ID"),
    Dest2_Segment_0 = Table.RenameColumns(#"0 DEST2_SEGMENT Duplicated Column",{{"COD_DEST2_SEGMENT_KEY", "TGK_DEST2_SEGMENT_KEY"}})
    ,
    CustomDimension2_Segment = List.First(List.Select(VersionCases, each _{0} = Version), null){5}
    ,
    //Custom Dimension 2 Segment Hierarchy
    Dest2Segment_HDSCode = List.Accumulate(Dimensions_ModelSwitch, "000038()", (state, current) =>
            if current{0} = Model then current{4} else state
    ),

    //Version 1.1.0 
    Output_Source_Dest2Segment_H_1 = 
        Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_DEST2_SEGMENT_GERARCHIA = Text.Type,
                        DESC_DEST2_SEGMENT_GERARCHIA = Text.Type,
                        COD_DEST2_SEGMENT_ELEGER1 = Text.Type,
                        DESC_DEST2_SEGMENT_ELEGER1 = Text.Type,
                        COD_DEST2_SEGMENT_ELEGER2 = Text.Type,
                        DESC_DEST2_SEGMENT_ELEGER2 = Text.Type,
                        COD_DEST2_SEGMENT_ELEGER3 = Text.Type,
                        DESC_DEST2_SEGMENT_ELEGER3 = Text.Type,
                        COD_DEST2_SEGMENT_ELEGER4 = Text.Type,
                        DESC_DEST2_SEGMENT_ELEGER4 = Text.Type,
                        COD_DEST2_SEGMENT_ELEGER5 = Text.Type,
                        DESC_DEST2_SEGMENT_ELEGER5 = Text.Type,
                        COD_DEST2_SEGMENT_ELEGER6 = Text.Type,
                        DESC_DEST2_SEGMENT_ELEGER6 = Text.Type,
                        COD_DEST2_SEGMENT_ELEGER7 = Text.Type,
                        DESC_DEST2_SEGMENT_ELEGER7 = Text.Type,
                        COD_DEST2_SEGMENT_ELEGER8 = Text.Type,
                        DESC_DEST2_SEGMENT_ELEGER8 = Text.Type,
                        COD_DEST2_SEGMENT_ELEGER9 = Text.Type,
                        DESC_DEST2_SEGMENT_ELEGER9 = Text.Type,
                        COD_DEST2_SEGMENT_KEY = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Dest2Segment_H = Json.Document(Web.Contents(outputURL & "Datasource_" & Dest2Segment_HDSCode,[Timeout=#duration(0,0,30,0)])),
                        #"Dest2Segment_H Converted to Table" = Table.FromRecords({Source_Dest2Segment_H}),
                        #"Dest2Segment_H Removed Columns" = Table.RemoveColumns(#"Dest2Segment_H Converted to Table",{"@odata.context"}),
                        #"Dest2Segment_H Expanded value" = Table.ExpandListColumn(#"Dest2Segment_H Removed Columns", "value"),
                        Output_Source_Dest2Segment_H = Table.ExpandRecordColumn(#"Dest2Segment_H Expanded value", "value",{"COD_DEST2_SEGMENT_GERARCHIA","DESC_DEST2_SEGMENT_GERARCHIA","COD_DEST2_SEGMENT_ELEGER1","DESC_DEST2_SEGMENT_ELEGER1","COD_DEST2_SEGMENT_ELEGER2","DESC_DEST2_SEGMENT_ELEGER2","COD_DEST2_SEGMENT_ELEGER3","DESC_DEST2_SEGMENT_ELEGER3","COD_DEST2_SEGMENT_ELEGER4","DESC_DEST2_SEGMENT_ELEGER4","COD_DEST2_SEGMENT_ELEGER5","DESC_DEST2_SEGMENT_ELEGER5","COD_DEST2_SEGMENT_ELEGER6","DESC_DEST2_SEGMENT_ELEGER6","COD_DEST2_SEGMENT_ELEGER7","DESC_DEST2_SEGMENT_ELEGER7","COD_DEST2_SEGMENT_ELEGER8","DESC_DEST2_SEGMENT_ELEGER8","COD_DEST2_SEGMENT_ELEGER9","DESC_DEST2_SEGMENT_ELEGER9","COD_DEST2_SEGMENT_KEY"})
                    in 
                        Output_Source_Dest2Segment_H
            ]
        ),
    #"1 Dest2_Segment_H Changed Type" = Table.TransformColumnTypes(Output_Source_Dest2Segment_H_1,{{"COD_DEST2_SEGMENT_ELEGER8", type text}, {"DESC_DEST2_SEGMENT_GERARCHIA", type text}, {"DESC_DEST2_SEGMENT_ELEGER8", type text}, {"COD_DEST2_SEGMENT_KEY", type text}, {"COD_DEST2_SEGMENT_GERARCHIA", type text}, {"COD_DEST2_SEGMENT_ELEGER1", type text}, {"DESC_DEST2_SEGMENT_ELEGER1", type text}, {"COD_DEST2_SEGMENT_ELEGER2", type text}, {"DESC_DEST2_SEGMENT_ELEGER2", type text}, {"COD_DEST2_SEGMENT_ELEGER3", type text}, {"DESC_DEST2_SEGMENT_ELEGER3", type text}, {"COD_DEST2_SEGMENT_ELEGER4", type text}, {"DESC_DEST2_SEGMENT_ELEGER4", type text}, {"COD_DEST2_SEGMENT_ELEGER5", type text}, {"DESC_DEST2_SEGMENT_ELEGER5", type text}, {"COD_DEST2_SEGMENT_ELEGER6", type text}, {"DESC_DEST2_SEGMENT_ELEGER6", type text}, {"COD_DEST2_SEGMENT_ELEGER7", type text}, {"DESC_DEST2_SEGMENT_ELEGER7", type text}, {"COD_DEST2_SEGMENT_ELEGER9", type text}, {"DESC_DEST2_SEGMENT_ELEGER9", type text}}),
    #"1 Dest2_Segment_H Merged Queries" = Table.NestedJoin(#"1 Dest2_Segment_H Changed Type", {"COD_DEST2_SEGMENT_KEY"}, CustomDimension2_Segment, {"TGK_DEST2_SEGMENT_KEY"}, "Custom Dimension 2 Segment", JoinKind.LeftOuter),
    #"1 Dest2_Segment_H Expanded Custom Dimension 2" = Table.ExpandTableColumn(#"1 Dest2_Segment_H Merged Queries", "Custom Dimension 2 Segment", {"TGK_DEST2_SEGMENT_H_ID"}, {"TGK_DEST2_SEGMENT_H_ID"}),
    Dest2_Segment_H_1 = Table.RenameColumns(#"1 Dest2_Segment_H Expanded Custom Dimension 2",{{"COD_DEST2_SEGMENT_GERARCHIA", "Custom Dimension 2 Segment Hierarchy Code"}, {"DESC_DEST2_SEGMENT_GERARCHIA", "Custom Dimension 2 Segment Hierarchy Description"}, {"COD_DEST2_SEGMENT_ELEGER1", "Custom Dimension 2 Segment Hierarchy Code Level 1"}, {"COD_DEST2_SEGMENT_ELEGER2", "Custom Dimension 2 Segment Hierarchy Code Level 2"}, {"COD_DEST2_SEGMENT_ELEGER3", "Custom Dimension 2 Segment Hierarchy Code Level 3"}, {"COD_DEST2_SEGMENT_ELEGER4", "Custom Dimension 2 Segment Hierarchy Code Level 4"}, {"COD_DEST2_SEGMENT_ELEGER5", "Custom Dimension 2 Segment Hierarchy Code Level 5"}, {"COD_DEST2_SEGMENT_ELEGER6", "Custom Dimension 2 Segment Hierarchy Code Level 6"}, {"COD_DEST2_SEGMENT_ELEGER7", "Custom Dimension 2 Segment Hierarchy Code Level 7"}, {"COD_DEST2_SEGMENT_ELEGER8", "Custom Dimension 2 Segment Hierarchy Code Level 8"}, {"DESC_DEST2_SEGMENT_ELEGER1", "Custom Dimension 2 Segment Hierarchy Description Level 1"}, {"DESC_DEST2_SEGMENT_ELEGER2", "Custom Dimension 2 Segment Hierarchy Description Level 2"}, {"DESC_DEST2_SEGMENT_ELEGER3", "Custom Dimension 2 Segment Hierarchy Description Level 3"}, {"DESC_DEST2_SEGMENT_ELEGER4", "Custom Dimension 2 Segment Hierarchy Description Level 4"}, {"DESC_DEST2_SEGMENT_ELEGER5", "Custom Dimension 2 Segment Hierarchy Description Level 5"}, {"DESC_DEST2_SEGMENT_ELEGER6", "Custom Dimension 2 Segment Hierarchy Description Level 6"}, {"DESC_DEST2_SEGMENT_ELEGER7", "Custom Dimension 2 Segment Hierarchy Description Level 7"}, {"DESC_DEST2_SEGMENT_ELEGER8", "Custom Dimension 2 Segment Hierarchy Description Level 8"}, {"COD_DEST2_SEGMENT_KEY", "TGK_DEST2_SEGMENT_H_KEY"}, {"COD_DEST2_SEGMENT_ELEGER9", "Custom Dimension 2 Segment Hierarchy Code Level 9"}, {"DESC_DEST2_SEGMENT_ELEGER9", "Custom Dimension 2 Segment Hierarchy Description Level 9"}})
    ,

    //Version 1.0.0 
    Output_Source_Dest2Segment_H_0 = 
        Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_DEST2_SEGMENT_GERARCHIA = Text.Type,
                        DESC_DEST2_SEGMENT_GERARCHIA = Text.Type,
                        COD_DEST2_SEGMENT_ELEGER1 = Text.Type,
                        DESC_DEST2_SEGMENT_ELEGER1 = Text.Type,
                        COD_DEST2_SEGMENT_ELEGER2 = Text.Type,
                        DESC_DEST2_SEGMENT_ELEGER2 = Text.Type,
                        COD_DEST2_SEGMENT_ELEGER3 = Text.Type,
                        DESC_DEST2_SEGMENT_ELEGER3 = Text.Type,
                        COD_DEST2_SEGMENT_ELEGER4 = Text.Type,
                        DESC_DEST2_SEGMENT_ELEGER4 = Text.Type,
                        COD_DEST2_SEGMENT_ELEGER5 = Text.Type,
                        DESC_DEST2_SEGMENT_ELEGER5 = Text.Type,
                        COD_DEST2_SEGMENT_ELEGER6 = Text.Type,
                        DESC_DEST2_SEGMENT_ELEGER6 = Text.Type,
                        COD_DEST2_SEGMENT_ELEGER7 = Text.Type,
                        DESC_DEST2_SEGMENT_ELEGER7 = Text.Type,
                        COD_DEST2_SEGMENT_ELEGER8 = Text.Type,
                        DESC_DEST2_SEGMENT_ELEGER8 = Text.Type,
                        COD_DEST2_SEGMENT_ELEGER9 = Text.Type,
                        DESC_DEST2_SEGMENT_ELEGER9 = Text.Type,
                        COD_DEST2_SEGMENT_KEY = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Dest2Segment_H = Json.Document(Web.Contents(outputURL & "Datasource_000038()",[Timeout=#duration(0,0,30,0)])),
                        #"Dest2Segment_H Converted to Table" = Table.FromRecords({Source_Dest2Segment_H}),
                        #"Dest2Segment_H Removed Columns" = Table.RemoveColumns(#"Dest2Segment_H Converted to Table",{"@odata.context"}),
                        #"Dest2Segment_H Expanded value" = Table.ExpandListColumn(#"Dest2Segment_H Removed Columns", "value"),
                        Output_Source_Dest2Segment_H = Table.ExpandRecordColumn(#"Dest2Segment_H Expanded value", "value",{"COD_DEST2_SEGMENT_GERARCHIA","DESC_DEST2_SEGMENT_GERARCHIA","COD_DEST2_SEGMENT_ELEGER1","DESC_DEST2_SEGMENT_ELEGER1","COD_DEST2_SEGMENT_ELEGER2","DESC_DEST2_SEGMENT_ELEGER2","COD_DEST2_SEGMENT_ELEGER3","DESC_DEST2_SEGMENT_ELEGER3","COD_DEST2_SEGMENT_ELEGER4","DESC_DEST2_SEGMENT_ELEGER4","COD_DEST2_SEGMENT_ELEGER5","DESC_DEST2_SEGMENT_ELEGER5","COD_DEST2_SEGMENT_ELEGER6","DESC_DEST2_SEGMENT_ELEGER6","COD_DEST2_SEGMENT_ELEGER7","DESC_DEST2_SEGMENT_ELEGER7","COD_DEST2_SEGMENT_ELEGER8","DESC_DEST2_SEGMENT_ELEGER8","COD_DEST2_SEGMENT_ELEGER9","DESC_DEST2_SEGMENT_ELEGER9","COD_DEST2_SEGMENT_KEY"})
                    in 
                        Output_Source_Dest2Segment_H
            ]
        ),
    #"0 Dest2_Segment_H Changed Type" = Table.TransformColumnTypes(Output_Source_Dest2Segment_H_0,{{"COD_DEST2_SEGMENT_ELEGER8", type text}, {"DESC_DEST2_SEGMENT_GERARCHIA", type text}, {"DESC_DEST2_SEGMENT_ELEGER8", type text}, {"COD_DEST2_SEGMENT_KEY", type text}, {"COD_DEST2_SEGMENT_GERARCHIA", type text}, {"COD_DEST2_SEGMENT_ELEGER1", type text}, {"DESC_DEST2_SEGMENT_ELEGER1", type text}, {"COD_DEST2_SEGMENT_ELEGER2", type text}, {"DESC_DEST2_SEGMENT_ELEGER2", type text}, {"COD_DEST2_SEGMENT_ELEGER3", type text}, {"DESC_DEST2_SEGMENT_ELEGER3", type text}, {"COD_DEST2_SEGMENT_ELEGER4", type text}, {"DESC_DEST2_SEGMENT_ELEGER4", type text}, {"COD_DEST2_SEGMENT_ELEGER5", type text}, {"DESC_DEST2_SEGMENT_ELEGER5", type text}, {"COD_DEST2_SEGMENT_ELEGER6", type text}, {"DESC_DEST2_SEGMENT_ELEGER6", type text}, {"COD_DEST2_SEGMENT_ELEGER7", type text}, {"DESC_DEST2_SEGMENT_ELEGER7", type text}, {"COD_DEST2_SEGMENT_ELEGER9", type text}, {"DESC_DEST2_SEGMENT_ELEGER9", type text}}),
    #"0 Dest2_Segment_H Merged Queries" = Table.NestedJoin(#"0 Dest2_Segment_H Changed Type", {"COD_DEST2_SEGMENT_KEY"}, CustomDimension2_Segment, {"TGK_DEST2_SEGMENT_KEY"}, "Custom Dimension 2 Segment", JoinKind.LeftOuter),
    #"0 Dest2_Segment_H Expanded Custom Dimension 2" = Table.ExpandTableColumn(#"0 Dest2_Segment_H Merged Queries", "Custom Dimension 2 Segment", {"TGK_DEST2_SEGMENT_H_ID"}, {"TGK_DEST2_SEGMENT_H_ID"}),
    Dest2_Segment_H_0 = Table.RenameColumns(#"0 Dest2_Segment_H Expanded Custom Dimension 2",{{"COD_DEST2_SEGMENT_GERARCHIA", "Custom Dimension 2 Segment Hierarchy Code"}, {"DESC_DEST2_SEGMENT_GERARCHIA", "Custom Dimension 2 Segment Hierarchy Description"}, {"COD_DEST2_SEGMENT_ELEGER1", "Custom Dimension 2 Segment Hierarchy Code Level 1"}, {"COD_DEST2_SEGMENT_ELEGER2", "Custom Dimension 2 Segment Hierarchy Code Level 2"}, {"COD_DEST2_SEGMENT_ELEGER3", "Custom Dimension 2 Segment Hierarchy Code Level 3"}, {"COD_DEST2_SEGMENT_ELEGER4", "Custom Dimension 2 Segment Hierarchy Code Level 4"}, {"COD_DEST2_SEGMENT_ELEGER5", "Custom Dimension 2 Segment Hierarchy Code Level 5"}, {"COD_DEST2_SEGMENT_ELEGER6", "Custom Dimension 2 Segment Hierarchy Code Level 6"}, {"COD_DEST2_SEGMENT_ELEGER7", "Custom Dimension 2 Segment Hierarchy Code Level 7"}, {"COD_DEST2_SEGMENT_ELEGER8", "Custom Dimension 2 Segment Hierarchy Code Level 8"}, {"DESC_DEST2_SEGMENT_ELEGER1", "Custom Dimension 2 Segment Hierarchy Description Level 1"}, {"DESC_DEST2_SEGMENT_ELEGER2", "Custom Dimension 2 Segment Hierarchy Description Level 2"}, {"DESC_DEST2_SEGMENT_ELEGER3", "Custom Dimension 2 Segment Hierarchy Description Level 3"}, {"DESC_DEST2_SEGMENT_ELEGER4", "Custom Dimension 2 Segment Hierarchy Description Level 4"}, {"DESC_DEST2_SEGMENT_ELEGER5", "Custom Dimension 2 Segment Hierarchy Description Level 5"}, {"DESC_DEST2_SEGMENT_ELEGER6", "Custom Dimension 2 Segment Hierarchy Description Level 6"}, {"DESC_DEST2_SEGMENT_ELEGER7", "Custom Dimension 2 Segment Hierarchy Description Level 7"}, {"DESC_DEST2_SEGMENT_ELEGER8", "Custom Dimension 2 Segment Hierarchy Description Level 8"}, {"COD_DEST2_SEGMENT_KEY", "TGK_DEST2_SEGMENT_H_KEY"}, {"COD_DEST2_SEGMENT_ELEGER9", "Custom Dimension 2 Segment Hierarchy Code Level 9"}, {"DESC_DEST2_SEGMENT_ELEGER9", "Custom Dimension 2 Segment Hierarchy Description Level 9"}})
    ,
    CustomDimension2_Segment_H = List.First(List.Select(VersionCases, each _{0} = Version), null){7}
    ,
    //Entity
    Output_Source_Entity = 
        Table.View(null,
            [
                GetType = () =>
                       type table [
						COD_AZIENDA = Text.Type,
						RAGIONE_SOCIALE = Text.Type,
						SEDE_LEGALE = Text.Type,
						SEDE_AMMINISTRATIVA = Text.Type,
						COD_VALUTA = Text.Type,
						ATTRIBUTO1 = Text.Type,
						ATTRIBUTO2 = Text.Type,
						ATTRIBUTO3 = Text.Type,
						ATTRIBUTO4 = Text.Type,
						ATTRIBUTO5 = Text.Type,
						DESC_AZIENDA0 = Text.Type,
						DESC_AZIENDA1 = Text.Type,
						DESC_AZIENDA2 = Text.Type,
						DESC_AZIENDA3 = Text.Type,
						SEDE_PRINCIPALE = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Entity = Json.Document(Web.Contents(outputURL & "Datasource_000001()",[Timeout=#duration(0,0,30,0)])),
                        #"Entity Converted to Table" = Table.FromRecords({Source_Entity}),
                        #"Entity Removed Columns" = Table.RemoveColumns(#"Entity Converted to Table",{"@odata.context"}),
                        #"Entity Expanded value" = Table.ExpandListColumn(#"Entity Removed Columns", "value"),
                        Output_Source_Entity = Table.ExpandRecordColumn(#"Entity Expanded value", "value",{"COD_AZIENDA","RAGIONE_SOCIALE","SEDE_LEGALE","SEDE_AMMINISTRATIVA","COD_VALUTA","ATTRIBUTO1","ATTRIBUTO2","ATTRIBUTO3","ATTRIBUTO4","ATTRIBUTO5","DESC_AZIENDA0","DESC_AZIENDA1","DESC_AZIENDA2","DESC_AZIENDA3","SEDE_PRINCIPALE"})
                    in 
                        Output_Source_Entity
            ]
        ),
    #"Entity Added Index" = Table.AddIndexColumn(Output_Source_Entity, "TGK_ENTITY_ID", 0, 1, Int64.Type),
    #"Entity Duplicated Column" = Table.DuplicateColumn(#"Entity Added Index", "TGK_ENTITY_ID", "TGK_ENTITY_H_ID"),
    #"Entity Duplicated Column 1" = Table.DuplicateColumn(#"Entity Duplicated Column", "COD_AZIENDA", "COD_AZIENDA_KEY"),
    #"Entity Changed Type" = Table.TransformColumnTypes(#"Entity Duplicated Column 1",{{"COD_AZIENDA", type text}, {"RAGIONE_SOCIALE", type text}, {"SEDE_LEGALE", type text}, {"SEDE_AMMINISTRATIVA", type text}, {"COD_VALUTA", type text}, {"ATTRIBUTO1", type text}, {"ATTRIBUTO2", type text}, {"ATTRIBUTO3", type text}, {"ATTRIBUTO4", type text}, {"ATTRIBUTO5", type text}, {"DESC_AZIENDA0", type text}, {"DESC_AZIENDA1", type text}, {"DESC_AZIENDA2", type text}, {"DESC_AZIENDA3", type text}, {"SEDE_PRINCIPALE", type text}, {"COD_AZIENDA_KEY", type text}}),
    Entity = Table.RenameColumns(#"Entity Changed Type",{{"COD_AZIENDA", "Entity Code"}, {"RAGIONE_SOCIALE", "Entity Business Name"}, {"SEDE_LEGALE", "Entity Legal Site"}, {"SEDE_AMMINISTRATIVA", "Entity Administrative Headquarters"}, {"COD_VALUTA", "Entity Currency Code"}, {"ATTRIBUTO1", "Entity Attribute 1"}, {"ATTRIBUTO2", "Entity Attribute 2"}, {"ATTRIBUTO3", "Entity Attribute 3"}, {"ATTRIBUTO4", "Entity Attribute 4"}, {"ATTRIBUTO5", "Entity Attribute 5"}, {"DESC_AZIENDA0", "Entity Description"}, {"DESC_AZIENDA1", "Entity Description 1"}, {"DESC_AZIENDA2", "Entity Description 2"}, {"DESC_AZIENDA3", "Entity Description 3"}, {"SEDE_PRINCIPALE", "Entity Headquarter"},{"COD_AZIENDA_KEY", "TGK_ENTITY_KEY"}})
    ,
    //Entity Hierarchy
    Output_Source_Entity_H = 
    Table.View(null,
        [
            GetType = () =>
            type table [
                COD_AZIENDA_GERARCHIA = Text.Type,
                DESC_AZIENDA_GERARCHIA = Text.Type,
                COD_AZIENDA_ELEGER1 = Text.Type,
                DESC_AZIENDA_ELEGER1 = Text.Type,
                COD_AZIENDA_ELEGER2 = Text.Type,
                DESC_AZIENDA_ELEGER2 = Text.Type,
                COD_AZIENDA_ELEGER3 = Text.Type,
                DESC_AZIENDA_ELEGER3 = Text.Type,
                COD_AZIENDA_ELEGER4 = Text.Type,
                DESC_AZIENDA_ELEGER4 = Text.Type,
                COD_AZIENDA_ELEGER5 = Text.Type,
                DESC_AZIENDA_ELEGER5 = Text.Type,
                COD_AZIENDA_ELEGER6 = Text.Type,
                DESC_AZIENDA_ELEGER6 = Text.Type,
                COD_AZIENDA_ELEGER7 = Text.Type,
                DESC_AZIENDA_ELEGER7 = Text.Type,
                COD_AZIENDA_ELEGER8 = Text.Type,
                DESC_AZIENDA_ELEGER8 = Text.Type,
                COD_AZIENDA_KEY = Text.Type
            ],
            GetRows = () =>
                let 
                    Source_Entity_H = Json.Document(Web.Contents(outputURL & "Datasource_000002()" ,[Timeout=#duration(0,0,30,0)])),
                    #"Entity_H Converted to Table" = Table.FromRecords({Source_Entity_H}),
                    #"Entity_H Removed Columns" = Table.RemoveColumns(#"Entity_H Converted to Table",{"@odata.context"}),
                    #"Entity_H Expanded value" = Table.ExpandListColumn(#"Entity_H Removed Columns", "value"),
                    Output_Source_Entity_H = Table.ExpandRecordColumn(#"Entity_H Expanded value", "value",{ "COD_AZIENDA_GERARCHIA","DESC_AZIENDA_GERARCHIA", "COD_AZIENDA_ELEGER1", "DESC_AZIENDA_ELEGER1", "COD_AZIENDA_ELEGER2", "DESC_AZIENDA_ELEGER2", "COD_AZIENDA_ELEGER3", "DESC_AZIENDA_ELEGER3", "COD_AZIENDA_ELEGER4", "DESC_AZIENDA_ELEGER4", "COD_AZIENDA_ELEGER5", "DESC_AZIENDA_ELEGER5", "COD_AZIENDA_ELEGER6", "DESC_AZIENDA_ELEGER6", "COD_AZIENDA_ELEGER7", "DESC_AZIENDA_ELEGER7", "COD_AZIENDA_ELEGER8", "DESC_AZIENDA_ELEGER8","COD_AZIENDA_KEY"})
                in 
                    Output_Source_Entity_H
        ]
    ),
    #"Entity_H Changed Type" = Table.TransformColumnTypes(Output_Source_Entity_H,{ {"COD_AZIENDA_KEY", type text}, {"COD_AZIENDA_GERARCHIA", type text},{"DESC_AZIENDA_GERARCHIA", type text}, {"COD_AZIENDA_ELEGER1", type text}, {"DESC_AZIENDA_ELEGER1", type text}, {"COD_AZIENDA_ELEGER2", type text}, {"DESC_AZIENDA_ELEGER2", type text}, {"COD_AZIENDA_ELEGER3", type text}, {"DESC_AZIENDA_ELEGER3", type text}, {"COD_AZIENDA_ELEGER4", type text}, {"DESC_AZIENDA_ELEGER4", type text}, {"COD_AZIENDA_ELEGER5", type text}, {"DESC_AZIENDA_ELEGER5", type text}, {"COD_AZIENDA_ELEGER6", type text}, {"DESC_AZIENDA_ELEGER6", type text}, {"COD_AZIENDA_ELEGER7", type text}, {"DESC_AZIENDA_ELEGER7", type text}, {"COD_AZIENDA_ELEGER8", type text}, {"DESC_AZIENDA_ELEGER8", type text}}),
    #"Entity_H Merged Queries" = Table.NestedJoin( #"Entity_H Changed Type", {"COD_AZIENDA_KEY"}, Entity, {"TGK_ENTITY_KEY"}, "Entity", JoinKind.LeftOuter),
    #"Entity_H Expanded Entity" = Table.ExpandTableColumn(#"Entity_H Merged Queries", "Entity", {"TGK_ENTITY_ID"}, {"TGK_ENTITY_H_ID"}),
    Entity_H = Table.RenameColumns(#"Entity_H Expanded Entity",{{"COD_AZIENDA_GERARCHIA", "Entity Hierarchy Code"}, {"DESC_AZIENDA_GERARCHIA", "Entity Hierarchy Description"}, {"COD_AZIENDA_ELEGER1", "Entity Hierarchy Code Level 1"}, {"COD_AZIENDA_ELEGER2", "Entity Hierarchy Code Level 2"}, {"COD_AZIENDA_ELEGER3", "Entity Hierarchy Code Level 3"}, {"COD_AZIENDA_ELEGER4", "Entity Hierarchy Code Level 4"}, {"COD_AZIENDA_ELEGER5", "Entity Hierarchy Code Level 5"}, {"COD_AZIENDA_ELEGER6", "Entity Hierarchy Code Level 6"}, {"COD_AZIENDA_ELEGER7", "Entity Hierarchy Code Level 7"}, {"COD_AZIENDA_ELEGER8", "Entity Hierarchy Code Level 8"}, {"DESC_AZIENDA_ELEGER1", "Entity Hierarchy Description Level 1"}, {"DESC_AZIENDA_ELEGER2", "Entity Hierarchy Description Level 2"}, {"DESC_AZIENDA_ELEGER3", "Entity Hierarchy Description Level 3"}, {"DESC_AZIENDA_ELEGER4", "Entity Hierarchy Description Level 4"}, {"DESC_AZIENDA_ELEGER5", "Entity Hierarchy Description Level 5"}, {"DESC_AZIENDA_ELEGER6", "Entity Hierarchy Description Level 6"}, {"DESC_AZIENDA_ELEGER7", "Entity Hierarchy Description Level 7"}, {"DESC_AZIENDA_ELEGER8", "Entity Hierarchy Description Level 8"}, {"COD_AZIENDA_KEY", "TGK_ENTITY_H_KEY"}})  
    ,
    //Entity CTP
    Source_Entity_CTP = Table.SelectColumns(Entity,{"Entity Code","Entity Business Name", "Entity Legal Site", "Entity Administrative Headquarters","Entity Currency Code", "Entity Attribute 1", "Entity Attribute 2", "Entity Attribute 3", "Entity Attribute 4", "Entity Attribute 5", "Entity Description","Entity Description 1", "Entity Description 2", "Entity Description 3", "Entity Headquarter", "TGK_ENTITY_KEY"}),
    #"Entity CTP Insert Row" = Table.InsertRows(Source_Entity_CTP,0,{[Entity Code="$NET",Entity Business Name =null, Entity Legal Site=null, Entity Administrative Headquarters=null,Entity Currency Code=null, Entity Attribute 1=null, Entity Attribute 2=null, Entity Attribute 3=null, Entity Attribute 4=null, Entity Attribute 5=null, Entity Description="3rd party",Entity Description 1=null, Entity Description 2=null, Entity Description 3=null, Entity Headquarter=null, TGK_ENTITY_KEY="$NET"]}),
    #"Entity CTP Added Index" = Table.AddIndexColumn(#"Entity CTP Insert Row", "TGK_ENTITY_CTP_ID", 0, 1, Int64.Type),
    #"Entity CTP Renamed Columns" = Table.RenameColumns( #"Entity CTP Added Index",{{"Entity Code", "Entity CTP Code"}, {"Entity Business Name", "Entity CTP Business Name"}, {"Entity Legal Site", "Entity CTP Legal Site"}, {"Entity Administrative Headquarters", "Entity CTP Administrative Headquarters"}, {"Entity Currency Code", "Entity CTP Currency Code"}, {"Entity Attribute 1", "Entity CTP Attribute 1"}, {"Entity Attribute 2", "Entity CTP Attribute 2"}, {"Entity Attribute 3", "Entity CTP Attribute 3"}, {"Entity Attribute 4", "Entity CTP Attribute 4"}, {"Entity Attribute 5", "Entity CTP Attribute 5"}, {"Entity Description", "Entity CTP Description"}, {"Entity Description 1", "Entity CTP Description 1"}, {"Entity Description 2", "Entity CTP Description 2"}, {"Entity Description 3", "Entity CTP Description 3"}, {"Entity Headquarter", "Entity CTP Headquarter"}, {"TGK_ENTITY_KEY", "TGK_ENTITY_CTP_KEY"}}),
    Entity_CTP = Table.DuplicateColumn(#"Entity CTP Renamed Columns", "TGK_ENTITY_CTP_ID", "TGK_ENTITY_CTP_H_ID")
    ,
    //Entity CTP Hierarchy
     Source_Entity_CTP_H = Table.SelectColumns(Entity_H,{
            "Entity Hierarchy Code",
            "Entity Hierarchy Description",
            "Entity Hierarchy Code Level 1",
            "Entity Hierarchy Description Level 1",
            "Entity Hierarchy Code Level 2",
            "Entity Hierarchy Description Level 2",
            "Entity Hierarchy Code Level 3",
            "Entity Hierarchy Description Level 3",
            "Entity Hierarchy Code Level 4",
            "Entity Hierarchy Description Level 4",
            "Entity Hierarchy Code Level 5",
            "Entity Hierarchy Description Level 5",
            "Entity Hierarchy Code Level 6",
            "Entity Hierarchy Description Level 6",
            "Entity Hierarchy Code Level 7",
            "Entity Hierarchy Description Level 7",
            "Entity Hierarchy Code Level 8",
            "Entity Hierarchy Description Level 8",
            "TGK_ENTITY_H_KEY"
        }
    ),
    #"Entity CTP H Transform Description" = Table.TransformColumns(Source_Entity_CTP_H, {{"Entity Hierarchy Description",each Text.Combine({(_), " Counterparty"})},{"Entity Hierarchy Description Level 8",each Text.Combine({(_), " Counterparty"})}}),
    #"Entity CTP H Hierarchy List" = Table.Distinct(Table.SelectColumns(#"Entity CTP H Transform Description",{"Entity Hierarchy Code","Entity Hierarchy Description","Entity Hierarchy Code Level 8","Entity Hierarchy Description Level 8"})),
    #"Entity CTP H Added 3rd party" = Table.AddColumn( #"Entity CTP H Hierarchy List", "Entity Hierarchy Code Level 7", each "[$NET]"),
    #"Entity CTP H Added 3rd party key" = Table.AddColumn( #"Entity CTP H Added 3rd party" , "TGK_ENTITY_H_KEY", each "$NET"),
    #"Entity CTP H Added 3rd party Description" = Table.AddColumn(  #"Entity CTP H Added 3rd party key", "Entity Hierarchy Description Level 7", each "[$NET - 3rd party]"),
    #"Entity CTP H Appended Query" = Table.Combine({#"Entity CTP H Transform Description",  #"Entity CTP H Added 3rd party Description"}),  
    #"Entity CTP H Check Null" = if Record.Field(Table.First(Entity_H), "Entity Hierarchy Code")= null then Source_Entity_CTP_H else #"Entity CTP H Appended Query",
    #"Entity CTP H Merged Queries" = Table.NestedJoin(#"Entity CTP H Check Null", {"TGK_ENTITY_H_KEY"}, Entity_CTP, {"TGK_ENTITY_CTP_KEY"}, "Entity CTP", JoinKind.LeftOuter),
    #"Entity CTP H Expanded" = Table.ExpandTableColumn(#"Entity CTP H Merged Queries", "Entity CTP", {"TGK_ENTITY_CTP_ID"}, {"TGK_ENTITY_CTP_H_ID"}),
    #"Entity CTP H RenameColumns"  = Table.RenameColumns(#"Entity CTP H Expanded",{{"Entity Hierarchy Code", "Entity CTP Hierarchy Code"}, {"Entity Hierarchy Description", "Entity CTP Hierarchy Description"}, {"Entity Hierarchy Code Level 1", "Entity CTP Hierarchy Code Level 1"}, {"Entity Hierarchy Code Level 2", "Entity CTP Hierarchy Code Level 2"}, {"Entity Hierarchy Code Level 3", "Entity CTP Hierarchy Code Level 3"}, {"Entity Hierarchy Code Level 4", "Entity CTP Hierarchy Code Level 4"}, {"Entity Hierarchy Code Level 5", "Entity CTP Hierarchy Code Level 5"}, {"Entity Hierarchy Code Level 6", "Entity CTP Hierarchy Code Level 6"}, {"Entity Hierarchy Code Level 7", "Entity CTP Hierarchy Code Level 7"}, {"Entity Hierarchy Code Level 8", "Entity CTP Hierarchy Code Level 8"}, {"Entity Hierarchy Description Level 1", "Entity CTP Hierarchy Description Level 1"}, {"Entity Hierarchy Description Level 2", "Entity CTP Hierarchy Description Level 2"}, {"Entity Hierarchy Description Level 3", "Entity CTP Hierarchy Description Level 3"}, {"Entity Hierarchy Description Level 4", "Entity CTP Hierarchy Description Level 4"}, {"Entity Hierarchy Description Level 5", "Entity CTP Hierarchy Description Level 5"}, {"Entity Hierarchy Description Level 6", "Entity CTP Hierarchy Description Level 6"}, {"Entity Hierarchy Description Level 7", "Entity CTP Hierarchy Description Level 7"}, {"Entity Hierarchy Description Level 8", "Entity CTP Hierarchy Description Level 8"},  {"TGK_ENTITY_H_KEY", "TGK_ENTITY_CTP_H_KEY"}}),
    Entity_CTP_H = Table.TransformColumnTypes(  #"Entity CTP H RenameColumns"  ,{{"TGK_ENTITY_CTP_H_KEY", type text},  {"Entity CTP Hierarchy Description Level 8", type text}, {"Entity CTP Hierarchy Description Level 7", type text}, {"Entity CTP Hierarchy Code Level 7", type text}, {"Entity CTP Hierarchy Description", type text}})
    ,
    //Entity Segment
    Entity_SegmentDSCode = List.Accumulate(Dimensions_ModelSwitch, "000026()", (state, current) =>
        if current{0} = Model then current{3} else state
    ),
    //Version 1.1.0 
    Output_Source_Entity_Segment_1 = 
    Table.View(null,
        [
            GetType = () =>
                   type table [
                    COD_AZIENDA_SEGMENT_KEY = Text.Type
                ],
            GetRows = () =>
                let 
                    Source_Entity_Segment = Json.Document(Web.Contents(outputURL & "Datasource_" & Entity_SegmentDSCode,[Timeout=#duration(0,0,30,0)])),
                    #"Entity_Segment Converted to Table" = Table.FromRecords({Source_Entity_Segment}),
                    #"Entity_Segment Removed Columns" = Table.RemoveColumns(#"Entity_Segment Converted to Table",{"@odata.context"}),
                    #"Entity_Segment Expanded value" = Table.ExpandListColumn(#"Entity_Segment Removed Columns", "value"),
                    Output_Source_Entity_Segment = Table.ExpandRecordColumn(#"Entity_Segment Expanded value", "value",{"COD_AZIENDA_SEGMENT_KEY"})
                in 
                    Output_Source_Entity_Segment
        ]
    ),
    #"1 Entity_Segment Changed Type" = Table.TransformColumnTypes(Output_Source_Entity_Segment_1,{{"COD_AZIENDA_SEGMENT_KEY", type text}}),
    #"1 Entity_Segment Added Index" = Table.AddIndexColumn(#"1 Entity_Segment Changed Type", "TGK_ENTITY_SEGMENT_ID", 0, 1, Int64.Type),
    #"1 Entity_Segment Duplicated Column" = Table.DuplicateColumn(#"1 Entity_Segment Added Index", "TGK_ENTITY_SEGMENT_ID", "TGK_ENTITY_SEGMENT_H_ID"),
    Entity_Segment_1 = Table.RenameColumns(#"1 Entity_Segment Duplicated Column",{{"COD_AZIENDA_SEGMENT_KEY", "TGK_ENTITY_SEGMENT_KEY"}})
    ,
    //Version 1.0.0 
    Output_Source_Entity_Segment_0 = 
    Table.View(null,
        [
            GetType = () =>
                   type table [
                    COD_AZIENDA_SEGMENT_KEY = Text.Type
                ],
            GetRows = () =>
                let 
                    Source_Entity_Segment = Json.Document(Web.Contents(outputURL & "Datasource_000026()",[Timeout=#duration(0,0,30,0)])),
                    #"Entity_Segment Converted to Table" = Table.FromRecords({Source_Entity_Segment}),
                    #"Entity_Segment Removed Columns" = Table.RemoveColumns(#"Entity_Segment Converted to Table",{"@odata.context"}),
                    #"Entity_Segment Expanded value" = Table.ExpandListColumn(#"Entity_Segment Removed Columns", "value"),
                    Output_Source_Entity_Segment = Table.ExpandRecordColumn(#"Entity_Segment Expanded value", "value",{"COD_AZIENDA_SEGMENT_KEY"})
                in 
                    Output_Source_Entity_Segment
        ]
    ),
    #"0 Entity_Segment Changed Type" = Table.TransformColumnTypes(Output_Source_Entity_Segment_1,{{"COD_AZIENDA_SEGMENT_KEY", type text}}),
    #"0 Entity_Segment Added Index" = Table.AddIndexColumn(#"0 Entity_Segment Changed Type", "TGK_ENTITY_SEGMENT_ID", 0, 1, Int64.Type),
    #"0 Entity_Segment Duplicated Column" = Table.DuplicateColumn(#"0 Entity_Segment Added Index", "TGK_ENTITY_SEGMENT_ID", "TGK_ENTITY_SEGMENT_H_ID"),
    Entity_Segment_0 = Table.RenameColumns(#"0 Entity_Segment Duplicated Column",{{"COD_AZIENDA_SEGMENT_KEY", "TGK_ENTITY_SEGMENT_KEY"}})
    ,
    Entity_Segment = List.First(List.Select(VersionCases, each _{0} = Version), null){6}
    ,
    //Entity Segment Hierarchy
    Entity_Segment_HDSCode = List.Accumulate(Dimensions_ModelSwitch, "000004()", (state, current) =>
            if current{0} = Model then current{5} else state
    ),

    //Version 1.1.0 
    Output_Source_Entity_Segment_H_1 = 
        Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_AZIENDA_SEGMENT_GERARCHIA = Text.Type,
                        DESC_AZIENDA_SEGMENT_GERARCHIA = Text.Type,
                        COD_AZIENDA_SEGMENT_ELEGER1 = Text.Type,
                        DESC_AZIENDA_SEGMENT_ELEGER1 = Text.Type,
                        COD_AZIENDA_SEGMENT_ELEGER2 = Text.Type,
                        DESC_AZIENDA_SEGMENT_ELEGER2 = Text.Type,
                        COD_AZIENDA_SEGMENT_ELEGER3 = Text.Type,
                        DESC_AZIENDA_SEGMENT_ELEGER3 = Text.Type,
                        COD_AZIENDA_SEGMENT_ELEGER4 = Text.Type,
                        DESC_AZIENDA_SEGMENT_ELEGER4 = Text.Type,
                        COD_AZIENDA_SEGMENT_ELEGER5 = Text.Type,
                        DESC_AZIENDA_SEGMENT_ELEGER5 = Text.Type,
                        COD_AZIENDA_SEGMENT_ELEGER6 = Text.Type,
                        DESC_AZIENDA_SEGMENT_ELEGER6 = Text.Type,
                        COD_AZIENDA_SEGMENT_ELEGER7 = Text.Type,
                        DESC_AZIENDA_SEGMENT_ELEGER7 = Text.Type,
                        COD_AZIENDA_SEGMENT_ELEGER8 = Text.Type,
                        DESC_AZIENDA_SEGMENT_ELEGER8 = Text.Type,
                        COD_AZIENDA_SEGMENT_ELEGER9 = Text.Type,
                        DESC_AZIENDA_SEGMENT_ELEGER9 = Text.Type,
                        COD_AZIENDA_SEGMENT_KEY = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Entity_Segment_H = Json.Document(Web.Contents(outputURL & "Datasource_" & Entity_Segment_HDSCode,[Timeout=#duration(0,0,30,0)])),
                         #"Entity_Segment_H Converted to Table" = Table.FromRecords({Source_Entity_Segment_H}),
                        #"Entity_Segment_H Removed Columns" = Table.RemoveColumns(#"Entity_Segment_H Converted to Table",{"@odata.context"}),
                        #"Entity_Segment_H Expanded value" = Table.ExpandListColumn(#"Entity_Segment_H Removed Columns", "value"),
                        Output_Source_Entity_Segment_H = Table.ExpandRecordColumn(#"Entity_Segment_H Expanded value", "value",{"COD_AZIENDA_SEGMENT_GERARCHIA","DESC_AZIENDA_SEGMENT_GERARCHIA","COD_AZIENDA_SEGMENT_ELEGER1","DESC_AZIENDA_SEGMENT_ELEGER1","COD_AZIENDA_SEGMENT_ELEGER2","DESC_AZIENDA_SEGMENT_ELEGER2","COD_AZIENDA_SEGMENT_ELEGER3","DESC_AZIENDA_SEGMENT_ELEGER3","COD_AZIENDA_SEGMENT_ELEGER4","DESC_AZIENDA_SEGMENT_ELEGER4","COD_AZIENDA_SEGMENT_ELEGER5","DESC_AZIENDA_SEGMENT_ELEGER5","COD_AZIENDA_SEGMENT_ELEGER6","DESC_AZIENDA_SEGMENT_ELEGER6","COD_AZIENDA_SEGMENT_ELEGER7","DESC_AZIENDA_SEGMENT_ELEGER7","COD_AZIENDA_SEGMENT_ELEGER8","DESC_AZIENDA_SEGMENT_ELEGER8","COD_AZIENDA_SEGMENT_ELEGER9","DESC_AZIENDA_SEGMENT_ELEGER9","COD_AZIENDA_SEGMENT_KEY"})
                    in 
                        Output_Source_Entity_Segment_H
            ]
        ),
    #"1 Entity_Segment_H Changed Type" = Table.TransformColumnTypes(Output_Source_Entity_Segment_H_1,{{"COD_AZIENDA_SEGMENT_ELEGER8", type text}, {"DESC_AZIENDA_SEGMENT_GERARCHIA", type text}, {"DESC_AZIENDA_SEGMENT_ELEGER8", type text}, {"COD_AZIENDA_SEGMENT_KEY", type text}, {"COD_AZIENDA_SEGMENT_GERARCHIA", type text}, {"COD_AZIENDA_SEGMENT_ELEGER1", type text}, {"DESC_AZIENDA_SEGMENT_ELEGER1", type text}, {"COD_AZIENDA_SEGMENT_ELEGER2", type text}, {"DESC_AZIENDA_SEGMENT_ELEGER2", type text}, {"COD_AZIENDA_SEGMENT_ELEGER3", type text}, {"DESC_AZIENDA_SEGMENT_ELEGER3", type text}, {"COD_AZIENDA_SEGMENT_ELEGER4", type text}, {"DESC_AZIENDA_SEGMENT_ELEGER4", type text}, {"COD_AZIENDA_SEGMENT_ELEGER5", type text}, {"DESC_AZIENDA_SEGMENT_ELEGER5", type text}, {"COD_AZIENDA_SEGMENT_ELEGER6", type text}, {"DESC_AZIENDA_SEGMENT_ELEGER6", type text}, {"COD_AZIENDA_SEGMENT_ELEGER7", type text}, {"DESC_AZIENDA_SEGMENT_ELEGER7", type text}, {"COD_AZIENDA_SEGMENT_ELEGER9", type text}, {"DESC_AZIENDA_SEGMENT_ELEGER9", type text}}),
    #"1 Entity_Segment_H Merged Queries" = Table.NestedJoin(#"1 Entity_Segment_H Changed Type", {"COD_AZIENDA_SEGMENT_KEY"}, Entity_Segment, {"TGK_ENTITY_SEGMENT_KEY"}, "Entity Segment", JoinKind.LeftOuter),
    #"1 Entity_Segment_H Expanded Entity Segment" = Table.ExpandTableColumn(#"1 Entity_Segment_H Merged Queries", "Entity Segment", {"TGK_ENTITY_SEGMENT_H_ID"}, {"TGK_ENTITY_SEGMENT_H_ID"}),
    Entity_Segment_H_1  = Table.RenameColumns(#"1 Entity_Segment_H Expanded Entity Segment",{{"COD_AZIENDA_SEGMENT_GERARCHIA", "Entity Segment Hierarchy Code"}, {"DESC_AZIENDA_SEGMENT_GERARCHIA", "Entity Segment Hierarchy Description"}, {"COD_AZIENDA_SEGMENT_ELEGER1", "Entity Segment Hierarchy Code Level 1"}, {"COD_AZIENDA_SEGMENT_ELEGER2", "Entity Segment Hierarchy Code Level 2"}, {"COD_AZIENDA_SEGMENT_ELEGER3", "Entity Segment Hierarchy Code Level 3"}, {"COD_AZIENDA_SEGMENT_ELEGER4", "Entity Segment Hierarchy Code Level 4"}, {"COD_AZIENDA_SEGMENT_ELEGER5", "Entity Segment Hierarchy Code Level 5"}, {"COD_AZIENDA_SEGMENT_ELEGER6", "Entity Segment Hierarchy Code Level 6"}, {"COD_AZIENDA_SEGMENT_ELEGER7", "Entity Segment Hierarchy Code Level 7"}, {"COD_AZIENDA_SEGMENT_ELEGER8", "Entity Segment Hierarchy Code Level 8"}, {"DESC_AZIENDA_SEGMENT_ELEGER1", "Entity Segment Hierarchy Description Level 1"}, {"DESC_AZIENDA_SEGMENT_ELEGER2", "Entity Segment Hierarchy Description Level 2"}, {"DESC_AZIENDA_SEGMENT_ELEGER3", "Entity Segment Hierarchy Description Level 3"}, {"DESC_AZIENDA_SEGMENT_ELEGER4", "Entity Segment Hierarchy Description Level 4"}, {"DESC_AZIENDA_SEGMENT_ELEGER5", "Entity Segment Hierarchy Description Level 5"}, {"DESC_AZIENDA_SEGMENT_ELEGER6", "Entity Segment Hierarchy Description Level 6"}, {"DESC_AZIENDA_SEGMENT_ELEGER7", "Entity Segment Hierarchy Description Level 7"}, {"DESC_AZIENDA_SEGMENT_ELEGER8", "Entity Segment Hierarchy Description Level 8"}, {"COD_AZIENDA_SEGMENT_KEY", "TGK_ENTITY_SEGMENT_H_KEY"}, {"COD_AZIENDA_SEGMENT_ELEGER9", "Entity Segment Hierarchy Code Level 9"}, {"DESC_AZIENDA_SEGMENT_ELEGER9", "Entity Segment Hierarchy Description Level 9"}})
    ,
    //Version 1.0.0 
    Output_Source_Entity_Segment_H_0 = 
        Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_AZIENDA_SEGMENT_GERARCHIA = Text.Type,
                        DESC_AZIENDA_SEGMENT_GERARCHIA = Text.Type,
                        COD_AZIENDA_SEGMENT_ELEGER0 = Text.Type,
                        DESC_AZIENDA_SEGMENT_ELEGER0 = Text.Type,
                        COD_AZIENDA_SEGMENT_ELEGER2 = Text.Type,
                        DESC_AZIENDA_SEGMENT_ELEGER2 = Text.Type,
                        COD_AZIENDA_SEGMENT_ELEGER3 = Text.Type,
                        DESC_AZIENDA_SEGMENT_ELEGER3 = Text.Type,
                        COD_AZIENDA_SEGMENT_ELEGER4 = Text.Type,
                        DESC_AZIENDA_SEGMENT_ELEGER4 = Text.Type,
                        COD_AZIENDA_SEGMENT_ELEGER5 = Text.Type,
                        DESC_AZIENDA_SEGMENT_ELEGER5 = Text.Type,
                        COD_AZIENDA_SEGMENT_ELEGER6 = Text.Type,
                        DESC_AZIENDA_SEGMENT_ELEGER6 = Text.Type,
                        COD_AZIENDA_SEGMENT_ELEGER7 = Text.Type,
                        DESC_AZIENDA_SEGMENT_ELEGER7 = Text.Type,
                        COD_AZIENDA_SEGMENT_ELEGER8 = Text.Type,
                        DESC_AZIENDA_SEGMENT_ELEGER8 = Text.Type,
                        COD_AZIENDA_SEGMENT_ELEGER9 = Text.Type,
                        DESC_AZIENDA_SEGMENT_ELEGER9 = Text.Type,
                        COD_AZIENDA_SEGMENT_KEY = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Entity_Segment_H = Json.Document(Web.Contents(outputURL & "Datasource_000004()" ,[Timeout=#duration(0,0,30,0)])),
                         #"Entity_Segment_H Converted to Table" = Table.FromRecords({Source_Entity_Segment_H}),
                        #"Entity_Segment_H Removed Columns" = Table.RemoveColumns(#"Entity_Segment_H Converted to Table",{"@odata.context"}),
                        #"Entity_Segment_H Expanded value" = Table.ExpandListColumn(#"Entity_Segment_H Removed Columns", "value"),
                        Output_Source_Entity_Segment_H = Table.ExpandRecordColumn(#"Entity_Segment_H Expanded value", "value",{"COD_AZIENDA_SEGMENT_GERARCHIA","DESC_AZIENDA_SEGMENT_GERARCHIA","COD_AZIENDA_SEGMENT_ELEGER1","DESC_AZIENDA_SEGMENT_ELEGER1","COD_AZIENDA_SEGMENT_ELEGER2","DESC_AZIENDA_SEGMENT_ELEGER2","COD_AZIENDA_SEGMENT_ELEGER3","DESC_AZIENDA_SEGMENT_ELEGER3","COD_AZIENDA_SEGMENT_ELEGER4","DESC_AZIENDA_SEGMENT_ELEGER4","COD_AZIENDA_SEGMENT_ELEGER5","DESC_AZIENDA_SEGMENT_ELEGER5","COD_AZIENDA_SEGMENT_ELEGER6","DESC_AZIENDA_SEGMENT_ELEGER6","COD_AZIENDA_SEGMENT_ELEGER7","DESC_AZIENDA_SEGMENT_ELEGER7","COD_AZIENDA_SEGMENT_ELEGER8","DESC_AZIENDA_SEGMENT_ELEGER8","COD_AZIENDA_SEGMENT_ELEGER9","DESC_AZIENDA_SEGMENT_ELEGER9","COD_AZIENDA_SEGMENT_KEY"})
                    in 
                        Output_Source_Entity_Segment_H
            ]
        ),
    #"0 Entity_Segment_H Changed Type" = Table.TransformColumnTypes(Output_Source_Entity_Segment_H_1,{{"COD_AZIENDA_SEGMENT_ELEGER8", type text}, {"DESC_AZIENDA_SEGMENT_GERARCHIA", type text}, {"DESC_AZIENDA_SEGMENT_ELEGER8", type text}, {"COD_AZIENDA_SEGMENT_KEY", type text}, {"COD_AZIENDA_SEGMENT_GERARCHIA", type text}, {"COD_AZIENDA_SEGMENT_ELEGER1", type text}, {"DESC_AZIENDA_SEGMENT_ELEGER1", type text}, {"COD_AZIENDA_SEGMENT_ELEGER2", type text}, {"DESC_AZIENDA_SEGMENT_ELEGER2", type text}, {"COD_AZIENDA_SEGMENT_ELEGER3", type text}, {"DESC_AZIENDA_SEGMENT_ELEGER3", type text}, {"COD_AZIENDA_SEGMENT_ELEGER4", type text}, {"DESC_AZIENDA_SEGMENT_ELEGER4", type text}, {"COD_AZIENDA_SEGMENT_ELEGER5", type text}, {"DESC_AZIENDA_SEGMENT_ELEGER5", type text}, {"COD_AZIENDA_SEGMENT_ELEGER6", type text}, {"DESC_AZIENDA_SEGMENT_ELEGER6", type text}, {"COD_AZIENDA_SEGMENT_ELEGER7", type text}, {"DESC_AZIENDA_SEGMENT_ELEGER7", type text}, {"COD_AZIENDA_SEGMENT_ELEGER9", type text}, {"DESC_AZIENDA_SEGMENT_ELEGER9", type text}}),
    #"0 Entity_Segment_H Merged Queries" = Table.NestedJoin(#"0 Entity_Segment_H Changed Type", {"COD_AZIENDA_SEGMENT_KEY"}, Entity_Segment, {"TGK_ENTITY_SEGMENT_KEY"}, "Entity Segment", JoinKind.LeftOuter),
    #"0 Entity_Segment_H Expanded Entity Segment" = Table.ExpandTableColumn(#"0 Entity_Segment_H Merged Queries", "Entity Segment", {"TGK_ENTITY_SEGMENT_H_ID"}, {"TGK_ENTITY_SEGMENT_H_ID"}),
    Entity_Segment_H_0  = Table.RenameColumns(#"0 Entity_Segment_H Expanded Entity Segment",{{"COD_AZIENDA_SEGMENT_GERARCHIA", "Entity Segment Hierarchy Code"}, {"DESC_AZIENDA_SEGMENT_GERARCHIA", "Entity Segment Hierarchy Description"}, {"COD_AZIENDA_SEGMENT_ELEGER1", "Entity Segment Hierarchy Code Level 1"}, {"COD_AZIENDA_SEGMENT_ELEGER2", "Entity Segment Hierarchy Code Level 2"}, {"COD_AZIENDA_SEGMENT_ELEGER3", "Entity Segment Hierarchy Code Level 3"}, {"COD_AZIENDA_SEGMENT_ELEGER4", "Entity Segment Hierarchy Code Level 4"}, {"COD_AZIENDA_SEGMENT_ELEGER5", "Entity Segment Hierarchy Code Level 5"}, {"COD_AZIENDA_SEGMENT_ELEGER6", "Entity Segment Hierarchy Code Level 6"}, {"COD_AZIENDA_SEGMENT_ELEGER7", "Entity Segment Hierarchy Code Level 7"}, {"COD_AZIENDA_SEGMENT_ELEGER8", "Entity Segment Hierarchy Code Level 8"}, {"DESC_AZIENDA_SEGMENT_ELEGER1", "Entity Segment Hierarchy Description Level 1"}, {"DESC_AZIENDA_SEGMENT_ELEGER2", "Entity Segment Hierarchy Description Level 2"}, {"DESC_AZIENDA_SEGMENT_ELEGER3", "Entity Segment Hierarchy Description Level 3"}, {"DESC_AZIENDA_SEGMENT_ELEGER4", "Entity Segment Hierarchy Description Level 4"}, {"DESC_AZIENDA_SEGMENT_ELEGER5", "Entity Segment Hierarchy Description Level 5"}, {"DESC_AZIENDA_SEGMENT_ELEGER6", "Entity Segment Hierarchy Description Level 6"}, {"DESC_AZIENDA_SEGMENT_ELEGER7", "Entity Segment Hierarchy Description Level 7"}, {"DESC_AZIENDA_SEGMENT_ELEGER8", "Entity Segment Hierarchy Description Level 8"}, {"COD_AZIENDA_SEGMENT_KEY", "TGK_ENTITY_SEGMENT_H_KEY"}, {"COD_AZIENDA_SEGMENT_ELEGER9", "Entity Segment Hierarchy Code Level 9"}, {"DESC_AZIENDA_SEGMENT_ELEGER9", "Entity Segment Hierarchy Description Level 9"}})
    ,
    Entity_Segment_H = List.First(List.Select(VersionCases, each _{0} = Version), null){8}
    ,
    //Exchange Rate
    ExchangeRateDSCode = List.Accumulate(Dimensions_ModelSwitch, "000027()", (state, current) =>
            if current{0} = Model then current{1} else state
        ),

    //Version 1.1.0 
    Output_Source_ExchangeRate_1 = 
        Table.View(null,
            [
                GetType = () =>
                       type table [
                        E = Text.Type
                        
                    ],
                GetRows = () =>
                    let 
                        Source_ExchangeRate = Json.Document(Web.Contents(outputURL & "Datasource_" & ExchangeRateDSCode,[Timeout=#duration(0,0,30,0)])),
                        #"ExchangeRate Converted to Table" = Table.FromRecords({Source_ExchangeRate}),
                        #"ExchangeRate Removed Columns" = Table.RemoveColumns(#"ExchangeRate Converted to Table",{"@odata.context"}),
                        #"ExchangeRate Expanded value" = Table.ExpandListColumn(#"ExchangeRate Removed Columns", "value"),
                        Output_Source_ExchangeRate = Table.ExpandRecordColumn(#"ExchangeRate Expanded value", "value",{"E"})
                    in 
                        Output_Source_ExchangeRate
            ]
        ),
    #"1 ExchangeRate Split Column by Delimiter" = Table.SplitColumn(Output_Source_ExchangeRate_1, "E", Splitter.SplitTextByDelimiter("|", QuoteStyle.None), {"COD_SCENARIO","COD_PERIODO","COD_VALUTA_SOURCE","COD_VALUTA_TARGET","CAMBIO_MEDIO","CAMBIO_PERIODO","CAMBIO_FINALE","CAMBIO_SI"}),
    #"1 ExchangeRate Added Scenario Period" = Table.AddColumn(#"1 ExchangeRate Split Column by Delimiter", "SCENARIO_PERIODO", each [COD_SCENARIO] & "|" & [COD_PERIODO],type text),
    #"1 ExchangeRate Merged Transaction Currency" = Table.NestedJoin(#"1 ExchangeRate Added Scenario Period", {"COD_VALUTA_SOURCE"}, TransactionCurrency, {"TGK_TRANSACTION_CURRENCY_KEY"}, "Transaction Currency", JoinKind.LeftOuter),
    #"1 ExchangeRate Expanded Transaction Currency" = Table.ExpandTableColumn(#"1 ExchangeRate Merged Transaction Currency",  "Transaction Currency",{"TGK_TRANSACTION_CURRENCY_KEY", "TGK_TRANSACTION_CURRENCY_ID"}, {"TGK_TRANSACTION_CURRENCY_ER_KEY", "TGK_TRANSACTION_CURRENCY_ER_ID"}),
    #"1 ExchangeRate Merged Target Currency" = Table.NestedJoin(#"1 ExchangeRate Expanded Transaction Currency", {"COD_VALUTA_TARGET"}, TargetCurrency, {"TGK_TARGET_CURRENCY_KEY"}, "Target Currency", JoinKind.LeftOuter),
    #"1 ExchangeRate Expanded Target Currency" = Table.ExpandTableColumn(#"1 ExchangeRate Merged Target Currency", "Target Currency", {"TGK_TARGET_CURRENCY_KEY", "TGK_TARGET_CURRENCY_ID"}, {"TGK_TARGET_CURRENCY_KEY", "TGK_TARGET_CURRENCY_ID"}),
    #"1 ExchangeRate Merged Scenario Period" = Table.NestedJoin(#"1 ExchangeRate Expanded Target Currency", {"SCENARIO_PERIODO"}, ScenarioPeriod, {"TGK_SCENARIO_PERIOD_KEY"}, "Scenario Period", JoinKind.LeftOuter),
    #"1 ExchangeRate Expanded Scenario Period" = Table.ExpandTableColumn(#"1 ExchangeRate Merged Scenario Period", "Scenario Period", {"TGK_SCENARIO_PERIOD_ER_ID"}, {"TGK_SCENARIO_PERIOD_ER_ID"}),
    #"1 ExchangeRate Renamed Columns" = Table.RenameColumns(#"1 ExchangeRate Expanded Scenario Period",{ {"TGK_TARGET_CURRENCY_KEY", "TGK_TARGET_CURRENCY_ER_KEY"}, {"COD_SCENARIO", "TGK_SCENARIO_ER_KEY"}, {"COD_PERIODO", "TGK_PERIOD_ER_KEY"}, {"SCENARIO_PERIODO", "TGK_SCENARIO_PERIOD_ER_KEY"}, {"COD_VALUTA_SOURCE", "ER Transaction Currency Code"}, {"COD_VALUTA_TARGET", "ER Target Currency Code"}, {"CAMBIO_MEDIO", "Average Exchange Rate"}, {"CAMBIO_PERIODO", "Period Exchange Rate"}, {"CAMBIO_FINALE", "Final Exchange Rate"}, {"CAMBIO_SI", "Initial Exchange Rate"}}),
    #"1 ExchangeRate Reordered Columns" = Table.ReorderColumns(#"1 ExchangeRate Renamed Columns",{"ER Transaction Currency Code", "ER Target Currency Code", "Average Exchange Rate", "Period Exchange Rate", "Final Exchange Rate", "Initial Exchange Rate", "TGK_SCENARIO_ER_KEY", "TGK_PERIOD_ER_KEY", "TGK_SCENARIO_PERIOD_ER_KEY", "TGK_TRANSACTION_CURRENCY_ER_KEY", "TGK_TRANSACTION_CURRENCY_ER_ID", "TGK_TARGET_CURRENCY_ER_KEY", "TGK_TARGET_CURRENCY_ID", "TGK_SCENARIO_PERIOD_ER_ID"}),
    ExchangeRate_1 = Table.TransformColumnTypes(#"1 ExchangeRate Reordered Columns",{{"Average Exchange Rate", type number}, {"Period Exchange Rate", type number}, {"Final Exchange Rate", type number}, {"Initial Exchange Rate", type number}},"en-US")


    ,
    //Version 1.0.0
    Output_Source_ExchangeRate_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_SCENARIO = Text.Type,
                        COD_PERIODO = Text.Type,
                        SCENARIO_PERIODO = Text.Type,
                        COD_VALUTA_SOURCE = Text.Type, 
                        COD_VALUTA_TARGET = Text.Type,
                        CAMBIO_MEDIO = Number.Type,
                        CAMBIO_PERIODO = Number.Type,
                        CAMBIO_FINALE = Number.Type,
                        CAMBIO_SI = Number.Type   
                    ],
                GetRows = () =>
                    let 
                        Source_ExchangeRate = Json.Document(Web.Contents(outputURL & "Datasource_000027()",[Timeout=#duration(0,0,30,0)])),
                        #"ExchangeRate Converted to Table" = Table.FromRecords({Source_ExchangeRate}),
                        #"ExchangeRate Removed Columns" = Table.RemoveColumns(#"ExchangeRate Converted to Table",{"@odata.context"}),
                        #"ExchangeRate Expanded value" = Table.ExpandListColumn(#"ExchangeRate Removed Columns", "value"),
                        Output_Source_ExchangeRate = Table.ExpandRecordColumn(#"ExchangeRate Expanded value", "value",{"COD_SCENARIO","COD_PERIODO","SCENARIO_PERIODO","COD_VALUTA_SOURCE","COD_VALUTA_TARGET","CAMBIO_MEDIO","CAMBIO_PERIODO","CAMBIO_FINALE","CAMBIO_SI"})                    
                    in 
                        Output_Source_ExchangeRate
            ]
        ),
    #"0 ExchangeRate Merged Transaction Currency" = Table.NestedJoin(Output_Source_ExchangeRate_0, {"COD_VALUTA_SOURCE"}, TransactionCurrency, {"TGK_TRANSACTION_CURRENCY_KEY"}, "Transaction Currency", JoinKind.LeftOuter),
    #"0 ExchangeRate Expanded Transaction Currency" = Table.ExpandTableColumn(#"0 ExchangeRate Merged Transaction Currency",  "Transaction Currency", {"TGK_TRANSACTION_CURRENCY_ID","TGK_TRANSACTION_CURRENCY_KEY"}, {"TGK_TRANSACTION_CURRENCY_ER_ID","TGK_TRANSACTION_CURRENCY_ER_KEY"}),
    #"0 ExchangeRate Merged Target Currency" = Table.NestedJoin(#"0 ExchangeRate Expanded Transaction Currency", {"COD_VALUTA_TARGET"}, TargetCurrency, {"TGK_TARGET_CURRENCY_KEY"}, "Target Currency", JoinKind.LeftOuter),
    #"0 ExchangeRate Expanded Target Currency" = Table.ExpandTableColumn(#"0 ExchangeRate Merged Target Currency", "Target Currency", {"TGK_TARGET_CURRENCY_KEY", "TGK_TARGET_CURRENCY_ID"}, {"TGK_TARGET_CURRENCY_KEY", "TGK_TARGET_CURRENCY_ID"}),
    #"0 ExchangeRate Merged Scenario Period" = Table.NestedJoin(#"0 ExchangeRate Expanded Target Currency", {"SCENARIO_PERIODO"}, ScenarioPeriod, {"TGK_SCENARIO_PERIOD_KEY"}, "Scenario Period", JoinKind.LeftOuter),
    #"0 ExchangeRate Expanded Scenario Period" = Table.ExpandTableColumn(#"0 ExchangeRate Merged Scenario Period", "Scenario Period", {"TGK_SCENARIO_PERIOD_ER_ID"}, {"TGK_SCENARIO_PERIOD_ER_ID"}),
    #"0 ExchangeRate Renamed Columns" = Table.RenameColumns(#"0 ExchangeRate Expanded Scenario Period",{ {"TGK_TARGET_CURRENCY_KEY", "TGK_TARGET_CURRENCY_ER_KEY"}, {"COD_SCENARIO", "TGK_SCENARIO_ER_KEY"}, {"COD_PERIODO", "TGK_PERIOD_ER_KEY"}, {"SCENARIO_PERIODO", "TGK_SCENARIO_PERIOD_ER_KEY"}, {"COD_VALUTA_SOURCE", "ER Transaction Currency Code"}, {"COD_VALUTA_TARGET", "ER Target Currency Code"}, {"CAMBIO_MEDIO", "Average Exchange Rate"}, {"CAMBIO_PERIODO", "Period Exchange Rate"}, {"CAMBIO_FINALE", "Final Exchange Rate"}, {"CAMBIO_SI", "Initial Exchange Rate"}}),
    #"0 ExchangeRate Reordered Columns" = Table.ReorderColumns(#"0 ExchangeRate Renamed Columns",{"ER Transaction Currency Code", "ER Target Currency Code", "Average Exchange Rate", "Period Exchange Rate", "Final Exchange Rate", "Initial Exchange Rate", "TGK_SCENARIO_ER_KEY", "TGK_PERIOD_ER_KEY", "TGK_SCENARIO_PERIOD_ER_KEY", "TGK_TRANSACTION_CURRENCY_ER_ID", "TGK_TRANSACTION_CURRENCY_ER_KEY", "TGK_TARGET_CURRENCY_ER_KEY", "TGK_TARGET_CURRENCY_ID", "TGK_SCENARIO_PERIOD_ER_ID"}),
    ExchangeRate_0 = Table.TransformColumnTypes(#"0 ExchangeRate Reordered Columns",{{"TGK_SCENARIO_PERIOD_ER_KEY", type text}, {"TGK_SCENARIO_ER_KEY", type text}, {"TGK_PERIOD_ER_KEY", type text},  {"ER Transaction Currency Code", type text}, {"ER Target Currency Code", type text}, {"Average Exchange Rate", type number}, {"Period Exchange Rate", type number}, {"Final Exchange Rate", type number}, {"Initial Exchange Rate", type number}})
    ,

    ExchangeRate = List.First(List.Select(VersionCases, each _{0} = Version), null){1}
    ,
    //FST
    Output_Source_FST = 
        Table.View(null,
            [
                GetType = () =>
                       type table [
                                COD_SCHEMA = Text.Type,
                                COD_CONTO = Text.Type,
                                COD_TIPO_CONTROLLO = Text.Type,
                                COD_VOCE = Text.Type,
                                COD_DEST1 = Text.Type,
                                COD_DEST2 = Text.Type,
                                COD_DEST3 = Text.Type,
                                COD_DEST4 = Text.Type,
                                COD_DEST5 = Text.Type,
                                DESC_VOCE0 = Text.Type,
                                FORMAT = Text.Type,
                                TIPO_VOCE = Text.Type,
                                FORMULA_VOCE = Text.Type,
                                ORDINAMENTO = Text.Type,
                                FLAG_NOREPORT = Number.Type,
                                NAME_XBRL = Text.Type,
                                TIPO_VOCE_XBRL = Text.Type,
                                CLASSE = Text.Type,
                                FLAG_CAMBIA_SEGNO = Number.Type,
                                DESC_SCHEMA0 = Text.Type,
                                DESC_SCHEMA1 = Text.Type,
                                DESC_SCHEMA2 = Text.Type,
                                DESC_SCHEMA3 = Text.Type,
                                ORDINAMENTO_SCHEMA_VOCE = Int64.Type
                    ],
                GetRows = () =>
                    let 
                        Source_FST = Json.Document(Web.Contents(outputURL &"Datasource_000021()" ,[Timeout=#duration(0,0,30,0)])),
                        #"FST Converted to Table" = Table.FromRecords({Source_FST}),
                        #"FST Removed Columns" = Table.RemoveColumns(#"FST Converted to Table",{"@odata.context"}),
                        #"FST Expanded value" = Table.ExpandListColumn(#"FST Removed Columns", "value"),
                        Output_Source_FST = Table.ExpandRecordColumn(#"FST Expanded value", "value",{"COD_SCHEMA", "COD_CONTO", "COD_TIPO_CONTROLLO", "COD_VOCE", "COD_DEST1", "COD_DEST2", "COD_DEST3", "COD_DEST4", "COD_DEST5", "DESC_VOCE0", "FORMAT", "TIPO_VOCE", "FORMULA_VOCE", "ORDINAMENTO", "FLAG_NOREPORT", "NAME_XBRL", "TIPO_VOCE_XBRL", "CLASSE", "FLAG_CAMBIA_SEGNO", "DESC_SCHEMA0", "DESC_SCHEMA1", "DESC_SCHEMA2", "DESC_SCHEMA3", "ORDINAMENTO_SCHEMA_VOCE"})
                    in 
                        Output_Source_FST
            ]
        ),
    #"FST Duplicated column" = Table.DuplicateColumn(Output_Source_FST, "COD_CONTO", "COD_CONTO_KEY"),
    #"FST Add column" = Table.AddColumn(#"FST Duplicated column", "FST Item Description", each [COD_VOCE] & " - " & [DESC_VOCE0]),
    #"FST Add column2" = Table.AddColumn(#"FST Add column", "FST Schema Description", each [COD_SCHEMA] & " - " & [DESC_SCHEMA0]),
    #"FST Reordered Columns" = Table.ReorderColumns(#"FST Add column2",{"COD_SCHEMA", "COD_CONTO", "COD_TIPO_CONTROLLO", "COD_VOCE", "COD_DEST1", "COD_DEST2", "COD_DEST3", "COD_DEST4", "COD_DEST5", "DESC_VOCE0", "FORMAT", "TIPO_VOCE", "FORMULA_VOCE", "ORDINAMENTO", "FLAG_NOREPORT", "NAME_XBRL", "TIPO_VOCE_XBRL", "CLASSE", "FLAG_CAMBIA_SEGNO","DESC_SCHEMA0", "DESC_SCHEMA1", "DESC_SCHEMA2", "DESC_SCHEMA3", "ORDINAMENTO_SCHEMA_VOCE", "FST Item Description", "FST Schema Description", "COD_CONTO_KEY"}),
    #"FST Merge" = Table.NestedJoin(#"FST Reordered Columns", {"COD_CONTO_KEY"}, Account, {"TGK_ACCOUNT_KEY"}, "Account", JoinKind.LeftOuter),
    #"FST Expand" = Table.ExpandTableColumn(#"FST Merge", "Account", {"TGK_ACCOUNT_FST_ID"}, {"TGK_ACCOUNT_FST_ID"}),
    #"FST Changed Type" = Table.TransformColumnTypes(#"FST Expand",{{"FST Item Description", type text}, {"FST Schema Description", type text}, {"FLAG_NOREPORT", type text}, {"FLAG_CAMBIA_SEGNO", type text}}),
    FST = Table.RenameColumns(#"FST Changed Type",{{"COD_SCHEMA", "FST Schema Code"}, {"COD_CONTO", "FST Account Code"}, {"COD_VOCE", "FST Item Code"}, {"COD_TIPO_CONTROLLO", "FST Control Type Code"}, {"DESC_VOCE0", "FST Item Short Description"}, {"FORMAT", "FST Format"}, {"TIPO_VOCE", "FST Item Type"}, {"ORDINAMENTO", "FST Sorting"}, {"FORMULA_VOCE", "FST Item Formula"}, {"FLAG_NOREPORT", "FST Exclude from Reporting"}, {"COD_DEST1", "FST Custom Dimension 1 Code"}, {"COD_DEST2", "FST Custom Dimension 2 Code"}, {"COD_DEST3", "FST Custom Dimension 3 Code"}, {"COD_DEST4", "FST Custom Dimension 4 Code"}, {"COD_DEST5", "FST Custom Dimension 5 Code"}, {"CLASSE", "FST Class"}, {"FLAG_CAMBIA_SEGNO", "FST Override Sign"}, {"DESC_SCHEMA0", "FST Schema Short Description"}, {"DESC_SCHEMA1", "FST Schema Description 1"}, {"DESC_SCHEMA2", "FST Schema Description 2"}, {"DESC_SCHEMA3", "FST Schema Description 3"}, {"ORDINAMENTO_SCHEMA_VOCE", "FST Sorting by Schema Item"}, {"TIPO_VOCE_XBRL", "FST XBRL Item Type"}, {"NAME_XBRL", "FST XBRL Name"}, {"COD_CONTO_KEY", "TGK_ACCOUNT_FST_KEY"}})
    ,
    //Notes
    //Version 1.1.0 
   Notes_ModelSwitch = 
        {   //Model Notes
            {"1",  "000039()"},
            {"2",  "000042()"}//,
            //{"3",  "000043()"}
        }
    ,
    NotesDSCode = List.Accumulate(Notes_ModelSwitch, "000039()", (state, current) =>
        if current{0} = Model then current{1} else state ),
    Output_Source_NoteTable =
        Table.View(null,
            [
                GetType = () => type table [L = Text.Type, N = Text.Type],
                GetRows = () =>
                    let
                        Source_NoteTable = Json.Document(Web.Contents(outputURL & "Datasource_" & NotesDSCode, [Timeout=#duration(0, 0, 30, 0)])),
                        #"Converted to Table NoteTable" = Table.FromRecords({Source_NoteTable}),
                        #"Removed Columns NoteTable" = Table.RemoveColumns(#"Converted to Table NoteTable", {"@odata.context"}),
                        #"Expanded value NoteTable" = Table.ExpandListColumn(#"Removed Columns NoteTable", "value"),
                        Output_Source_NoteTable = Table.ExpandRecordColumn(#"Expanded value NoteTable", "value", {"L", "N"})
                    in
                        Output_Source_NoteTable
            ]
        ),
    #"NoteTable Split Column by Delimiter" = Table.SplitColumn(Output_Source_NoteTable,"L",Splitter.SplitTextByDelimiter("|", QuoteStyle.None),
        {"TGK_SCENARIO_N_KEY", "TGK_PERIOD_N_KEY", "TGK_ENTITY_N_KEY", "TGK_ACCOUNT_N_KEY", "TGK_DEST1_N_KEY", "TGK_DEST2_N_KEY", "TGK_DEST3_N_KEY", "TGK_DEST4_N_KEY", "TGK_DEST5_N_KEY", "TGK_CATEGORY_N_KEY", "TGK_ENTITY_CTP_N_KEY", "TGK_DEST2_CTP_N_KEY", "Notes Date Update"}),
    #"NoteTable Renamed Columns" = Table.RenameColumns(#"NoteTable Split Column by Delimiter",{{"N", "Notes"}}),
    #"NoteTable Changed Type" = Table.TransformColumnTypes(#"NoteTable Renamed Columns",{{"TGK_SCENARIO_N_KEY", type text}, {"TGK_PERIOD_N_KEY", type text}, {"TGK_ENTITY_N_KEY", type text}, {"TGK_ACCOUNT_N_KEY", type text}, {"TGK_DEST1_N_KEY", type text}, {"TGK_DEST2_N_KEY", type text}, {"TGK_DEST3_N_KEY", type text}, {"TGK_DEST4_N_KEY", type text}, {"TGK_DEST5_N_KEY", type text}, {"TGK_CATEGORY_N_KEY", type text}, {"TGK_ENTITY_CTP_N_KEY", type text}, {"TGK_DEST2_CTP_N_KEY", type text}, {"Notes Date Update", type datetime},{"Notes", type text}}),
    #"NoteTable Replaced Value" = Table.ReplaceValue(#"NoteTable Changed Type","","$NET",Replacer.ReplaceValue,{"TGK_ENTITY_CTP_N_KEY", "TGK_DEST2_CTP_N_KEY"}),

    #"NoteTable Merged Scenario" = Table.NestedJoin(#"NoteTable Replaced Value", {"TGK_SCENARIO_N_KEY"}, Scenario, {"TGK_SCENARIO_KEY"}, "Scenario", JoinKind.LeftOuter),
    #"NoteTable Expanded Scenario" = Table.ExpandTableColumn(#"NoteTable Merged Scenario", "Scenario", {"TGK_SCENARIO_ID"}, {"TGK_SCENARIO_ID"}),

    #"NoteTable Merged Period" = Table.NestedJoin(#"NoteTable Expanded Scenario", {"TGK_PERIOD_N_KEY"}, Period, {"TGK_PERIOD_KEY"}, "Period", JoinKind.LeftOuter),
    #"NoteTable Expanded Period" = Table.ExpandTableColumn(#"NoteTable Merged Period", "Period", {"TGK_PERIOD_ID"}, {"TGK_PERIOD_ID"}),

    #"NoteTable Merged Entity" = Table.NestedJoin(#"NoteTable Expanded Period", {"TGK_ENTITY_N_KEY"}, Entity, {"TGK_ENTITY_KEY"}, "Entity", JoinKind.LeftOuter),
    #"NoteTable Expanded Entity" = Table.ExpandTableColumn(#"NoteTable Merged Entity", "Entity", {"TGK_ENTITY_ID"}, {"TGK_ENTITY_ID"}),

    #"NoteTable Merged Account" = Table.NestedJoin(#"NoteTable Expanded Entity", {"TGK_ACCOUNT_N_KEY"}, Account, {"TGK_ACCOUNT_KEY"}, "Account", JoinKind.LeftOuter),
    #"NoteTable Expanded Account" = Table.ExpandTableColumn(#"NoteTable Merged Account", "Account", {"TGK_ACCOUNT_ID"}, {"TGK_ACCOUNT_ID"}),

    #"NoteTable Merged Dest1" = Table.NestedJoin(#"NoteTable Expanded Account", {"TGK_DEST1_N_KEY"}, CustomDimension1, {"TGK_DEST1_KEY"}, "Dest1", JoinKind.LeftOuter),
    #"NoteTable Expanded Dest1" = Table.ExpandTableColumn(#"NoteTable Merged Dest1", "Dest1", {"TGK_DEST1_ID"}, {"TGK_DEST1_ID"}),

    #"NoteTable Merged Dest2" = Table.NestedJoin(#"NoteTable Expanded Dest1", {"TGK_DEST2_N_KEY"}, CustomDimension2, {"TGK_DEST2_KEY"}, "Dest2", JoinKind.LeftOuter),
    #"NoteTable Expanded Dest2" = Table.ExpandTableColumn(#"NoteTable Merged Dest2", "Dest2", {"TGK_DEST2_ID"}, {"TGK_DEST2_ID"}),

    #"NoteTable Merged Dest3" = Table.NestedJoin(#"NoteTable Expanded Dest2", {"TGK_DEST3_N_KEY"}, CustomDimension3, {"TGK_DEST3_KEY"}, "Dest3", JoinKind.LeftOuter),
    #"NoteTable Expanded Dest3" = Table.ExpandTableColumn(#"NoteTable Merged Dest3", "Dest3", {"TGK_DEST3_ID"}, {"TGK_DEST3_ID"}),

    #"NoteTable Merged Dest4" = Table.NestedJoin(#"NoteTable Expanded Dest3", {"TGK_DEST4_N_KEY"}, CustomDimension4, {"TGK_DEST4_KEY"}, "Dest4", JoinKind.LeftOuter),
    #"NoteTable Expanded Dest4" = Table.ExpandTableColumn(#"NoteTable Merged Dest4", "Dest4", {"TGK_DEST4_ID"}, {"TGK_DEST4_ID"}),

    #"NoteTable Merged Dest5" = Table.NestedJoin(#"NoteTable Expanded Dest4", {"TGK_DEST5_N_KEY"}, CustomDimension5, {"TGK_DEST5_KEY"}, "Dest5", JoinKind.LeftOuter),
    #"NoteTable Expanded Dest5" = Table.ExpandTableColumn(#"NoteTable Merged Dest5", "Dest5", {"TGK_DEST5_ID"}, {"TGK_DEST5_ID"}),

    #"NoteTable Merged Category" = Table.NestedJoin(#"NoteTable Expanded Dest5", {"TGK_CATEGORY_N_KEY"}, Category, {"TGK_CATEGORY_KEY"}, "Category", JoinKind.LeftOuter),
    #"NoteTable Expanded Category" = Table.ExpandTableColumn(#"NoteTable Merged Category", "Category", {"TGK_CATEGORY_ID"}, {"TGK_CATEGORY_ID"}),

    #"NoteTable Merged Entity_CTP" = Table.NestedJoin(#"NoteTable Expanded Category", {"TGK_ENTITY_CTP_N_KEY"}, Entity_CTP, {"TGK_ENTITY_CTP_KEY"}, "Entity_CTP", JoinKind.LeftOuter),
    #"NoteTable Expanded Entity_CTP" = Table.ExpandTableColumn(#"NoteTable Merged Entity_CTP", "Entity_CTP", {"TGK_ENTITY_CTP_ID"}, {"TGK_ENTITY_CTP_ID"}),

    #"NoteTable Merged Dest2_CTP" = Table.NestedJoin(#"NoteTable Expanded Entity_CTP", {"TGK_DEST2_CTP_N_KEY"}, CustomDimension_2_CTP, {"TGK_DEST2_CTP_KEY"}, "Dest2_CTP", JoinKind.LeftOuter),
    Notes_1 = Table.ExpandTableColumn(#"NoteTable Merged Dest2_CTP", "Dest2_CTP", {"TGK_DEST2_CTP_ID"}, {"TGK_DEST2_CTP_ID"})
    ,
    //Version 1.0.0
    Output_Source_Notes_0 = #table(
        type table [L = Text.Type, Notes = Text.Type], 
        {}
    ),
    
    #"0 NoteTable Split Column by Delimiter" = Table.SplitColumn(Output_Source_Notes_0, "L", Splitter.SplitTextByDelimiter("|", QuoteStyle.None), {"TGK_SCENARIO_N_KEY", "TGK_PERIOD_N_KEY", "TGK_ENTITY_N_KEY", "TGK_ACCOUNT_N_KEY", "TGK_DEST1_N_KEY", "TGK_DEST2_N_KEY", "TGK_DEST3_N_KEY", "TGK_DEST4_N_KEY", "TGK_DEST5_N_KEY", "TGK_CATEGORY_N_KEY", "TGK_ENTITY_CTP_N_KEY", "TGK_DEST2_CTP_N_KEY", "Notes Date Update","TGK_SCENARIO_ID", "TGK_PERIOD_ID", "TGK_ENTITY_ID", "TGK_ACCOUNT_ID", "TGK_DEST1_ID", "TGK_DEST2_ID", "TGK_DEST3_ID", "TGK_DEST4_ID", "TGK_DEST5_ID", "TGK_CATEGORY_ID", "TGK_ENTITY_CTP_ID", "TGK_DEST2_CTP_ID"}),
    Notes_0 = Table.TransformColumnTypes(#"0 NoteTable Split Column by Delimiter",{{"TGK_SCENARIO_N_KEY", type text}, {"TGK_PERIOD_N_KEY", type text}, {"TGK_ENTITY_N_KEY", type text}, {"TGK_ACCOUNT_N_KEY", type text}, {"TGK_DEST1_N_KEY", type text}, {"TGK_DEST2_N_KEY", type text}, {"TGK_DEST3_N_KEY", type text}, {"TGK_DEST4_N_KEY", type text}, {"TGK_DEST5_N_KEY", type text}, {"TGK_CATEGORY_N_KEY", type text}, {"TGK_ENTITY_CTP_N_KEY", type text}, {"TGK_DEST2_CTP_N_KEY", type text}, {"Notes Date Update", type datetime},{"Notes", type text}}),
    
    Notes = List.Accumulate(VersionCases, Notes_1, (state, current) =>
            if current{0} = Version then current{21} else Notes_0
        )
    ,
    //Period
    Output_Source_Period = 
        Table.View(null,
            [
                GetType = () =>
                       type table [
                                COD_PERIODO = Text.Type,
                                DESC_PERIODO0 = Text.Type,
                                DESC_PERIODO1 = Text.Type,
                                DESC_PERIODO2 = Text.Type,
                                DESC_PERIODO3 = Text.Type,
                                DESC_MESE0 = Text.Type,
                                DESC_MESE1 = Text.Type,
                                DESC_MESE2 = Text.Type,
                                DESC_MESE3 = Text.Type,
                                DESC_TRIMESTRE0 = Text.Type,
                                DESC_TRIMESTRE1 = Text.Type,
                                DESC_TRIMESTRE2 = Text.Type,
                                DESC_TRIMESTRE3 = Text.Type,
                                DESC_QUADRIMESTRE0 = Text.Type,
                                DESC_QUADRIMESTRE1 = Text.Type,
                                DESC_QUADRIMESTRE2 = Text.Type,
                                DESC_QUADRIMESTRE3 = Text.Type,
                                DESC_SEMESTRE0 = Text.Type,
                                DESC_SEMESTRE1 = Text.Type,
                                DESC_SEMESTRE2 = Text.Type,
                                DESC_SEMESTRE3 = Text.Type,
                                DESC_NUM_PERIODO = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Period = Json.Document(Web.Contents(outputURL &"Datasource_000020()" ,[Timeout=#duration(0,0,30,0)])),
                        #"Period Converted to Table" = Table.FromRecords({Source_Period}),
                        #"Period Removed Columns" = Table.RemoveColumns(#"Period Converted to Table",{"@odata.context"}),
                        #"Period Expanded value" = Table.ExpandListColumn(#"Period Removed Columns", "value"),
                        Output_Source_Period = Table.ExpandRecordColumn(#"Period Expanded value", "value",{"COD_PERIODO","DESC_PERIODO0","DESC_PERIODO1","DESC_PERIODO2","DESC_PERIODO3","DESC_MESE0","DESC_MESE1","DESC_MESE2","DESC_MESE3","DESC_TRIMESTRE0","DESC_TRIMESTRE1","DESC_TRIMESTRE2","DESC_TRIMESTRE3","DESC_QUADRIMESTRE0","DESC_QUADRIMESTRE1","DESC_QUADRIMESTRE2","DESC_QUADRIMESTRE3","DESC_SEMESTRE0","DESC_SEMESTRE1","DESC_SEMESTRE2","DESC_SEMESTRE3","DESC_NUM_PERIODO"})
                    in 
                        Output_Source_Period
            ]
        ),
    #"Period Added Index" = Table.AddIndexColumn(Output_Source_Period , "TGK_PERIOD_ID", 0, 1, Int64.Type),
    #"Period Duplicated Column" = Table.DuplicateColumn(#"Period Added Index", "COD_PERIODO", "COD_PERIODO_KEY"),
    #"Period Renamed Columns" = Table.RenameColumns(#"Period Duplicated Column",{{"COD_PERIODO", "Period Code"}, {"DESC_PERIODO0", "Period Description"}, {"DESC_PERIODO1", "Period Description 1"}, {"DESC_PERIODO2", "Period Description 2"}, {"DESC_PERIODO3", "Period Description 3"}, {"DESC_MESE0", "Month Description"}, {"DESC_MESE1", "Month Description 1"}, {"DESC_MESE2", "Month Description 2"}, {"DESC_MESE3", "Month Description 3"}, {"DESC_TRIMESTRE0", "Quarter Description"}, {"DESC_TRIMESTRE1", "Quarter Description 1"}, {"DESC_TRIMESTRE2", "Quarter Description 2"}, {"DESC_TRIMESTRE3", "Quarter Description 3"}, {"DESC_QUADRIMESTRE0", "Four months Description"}, {"DESC_QUADRIMESTRE1", "Four months Description 1"}, {"DESC_QUADRIMESTRE2", "Four months Description 2"}, {"DESC_QUADRIMESTRE3", "Four months Description 3"}, {"DESC_SEMESTRE0", "Half Year Description"}, {"DESC_SEMESTRE1", "Half Year Description 1"}, {"DESC_SEMESTRE2", "Half Year Description 2"}, {"DESC_SEMESTRE3", "Half Year Description 3"}, {"DESC_NUM_PERIODO", "Period Number"}, {"COD_PERIODO_KEY", "TGK_PERIOD_KEY"}}),
    #"Period Duplicated Column 2" = Table.DuplicateColumn(#"Period Renamed Columns", "Period Code", "Period Num"),
    Period = Table.TransformColumnTypes(#"Period Duplicated Column 2",{{"Period Num", Int64.Type}})
    ,
    //Period Length
    Source_PeriodLength = Table.FromRecords({ 
        [Period Length Code = "M", Period Length Description = "Monthly"],
        [Period Length Code = "YTD", Period Length Description = "Year to date"]
    }),
    PeriodLength = Table.TransformColumnTypes(Source_PeriodLength,{{"Period Length Code", type text}, {"Period Length Description", type text}})
    ,
    //Scenario
    //Version 1.1.0 
    Output_Source_Scenario_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_SCENARIO = Text.Type,
						TIPO_SCENARIO = Text.Type,
						COD_SCENARIO_ORIGINARIO = Text.Type,
						DESC_SCENARIO = Text.Type,
						COD_SCENARIO_PREC = Text.Type,
						COD_SCENARIO_SUCC = Text.Type,
						COD_SCENARIO_RIF1 = Text.Type,
						COD_SCENARIO_RIF2 = Text.Type,
						COD_SCENARIO_RIF3 = Text.Type,
						COD_SCENARIO_RIF4 = Text.Type,
						COD_SCENARIO_RIF5 = Text.Type,
						COD_VALUTA = Text.Type,
						COD_ESERCIZIO = Text.Type,
						DESC_VERSIONE = Text.Type,
						COD_SCENARIO_RIF_CAMBI = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Scenario = Json.Document(Web.Contents(outputURL &"Datasource_000006()?$filter=FM eq '" & Model & "'&$select=COD_SCENARIO,TIPO_SCENARIO,COD_SCENARIO_ORIGINARIO,DESC_SCENARIO,COD_SCENARIO_PREC,COD_SCENARIO_SUCC,COD_SCENARIO_RIF1,COD_SCENARIO_RIF2,COD_SCENARIO_RIF3,COD_SCENARIO_RIF4,COD_SCENARIO_RIF5,COD_VALUTA,COD_ESERCIZIO,DESC_VERSIONE,COD_SCENARIO_RIF_CAMBI" ,[Timeout=#duration(0,0,30,0)])),
                        #"Scenario Converted to Table" = Table.FromRecords({Source_Scenario}),
                        #"Scenario Removed Columns" = Table.RemoveColumns(#"Scenario Converted to Table",{"@odata.context"}),
                        #"Scenario Expanded value" = Table.ExpandListColumn(#"Scenario Removed Columns", "value"),
                        Output_Source_Scenario = Table.ExpandRecordColumn(#"Scenario Expanded value", "value",{"COD_SCENARIO", "TIPO_SCENARIO", "COD_SCENARIO_ORIGINARIO", "DESC_SCENARIO", "COD_SCENARIO_PREC", "COD_SCENARIO_SUCC", "COD_SCENARIO_RIF1", "COD_SCENARIO_RIF2", "COD_SCENARIO_RIF3", "COD_SCENARIO_RIF4", "COD_SCENARIO_RIF5", "COD_VALUTA","COD_ESERCIZIO","DESC_VERSIONE","COD_SCENARIO_RIF_CAMBI"})                       
                    in 
                        Output_Source_Scenario
            ]
        ),
    #"1 Scenario Added Index" = Table.AddIndexColumn(Output_Source_Scenario_1, "ID_SCENARIO", 0, 1, Int64.Type),
    #"1 Scenario Duplicated Column" = Table.DuplicateColumn(#"1 Scenario Added Index", "COD_SCENARIO", "COD_SCENARIO_KEY"),
    #"1 Scenario Duplicated Column1" = Table.DuplicateColumn(#"1 Scenario Duplicated Column", "ID_SCENARIO", "ID_H_SCENARIO"),
    Scenario_1 = Table.RenameColumns(#"1 Scenario Duplicated Column1",{{"COD_SCENARIO", "Scenario Code"}, {"TIPO_SCENARIO", "Scenario Type"}, {"COD_SCENARIO_ORIGINARIO", "Original Scenario"}, {"DESC_SCENARIO", "Scenario Description"}, {"COD_SCENARIO_PREC", "Previous Scenario"}, {"COD_SCENARIO_SUCC", "Following Scenario"}, {"COD_SCENARIO_RIF1", "Reference Scenario 1"}, {"COD_SCENARIO_RIF2", "Reference Scenario 2"}, {"COD_SCENARIO_RIF3", "Reference Scenario 3"}, {"COD_SCENARIO_RIF4", "Reference Scenario 4"}, {"COD_SCENARIO_RIF5", "Reference Scenario 5"}, {"COD_VALUTA", "Scenario Currency"}, {"COD_ESERCIZIO", "Scenario Year"}, {"DESC_VERSIONE", "Version Description"}, {"COD_SCENARIO_RIF_CAMBI", "Ref. FX Rate Scenario"}, {"COD_SCENARIO_KEY", "TGK_SCENARIO_KEY"}, {"ID_SCENARIO", "TGK_SCENARIO_ID"}, {"ID_H_SCENARIO", "TGK_SCENARIO_H_ID"}})
    ,
    //Version 1.0.0 
    Output_Source_Scenario_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_SCENARIO = Text.Type,
						TIPO_SCENARIO = Text.Type,
						COD_SCENARIO_ORIGINARIO = Text.Type,
						DESC_SCENARIO = Text.Type,
						COD_SCENARIO_PREC = Text.Type,
						COD_SCENARIO_SUCC = Text.Type,
						COD_SCENARIO_RIF1 = Text.Type,
						COD_SCENARIO_RIF2 = Text.Type,
						COD_SCENARIO_RIF3 = Text.Type,
						COD_SCENARIO_RIF4 = Text.Type,
						COD_SCENARIO_RIF5 = Text.Type,
						COD_VALUTA = Text.Type,
						COD_ESERCIZIO = Text.Type,
						DESC_VERSIONE = Text.Type,
						COD_SCENARIO_RIF_CAMBI = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Scenario = Json.Document(Web.Contents(outputURL &"Datasource_000006()" ,[Timeout=#duration(0,0,30,0)])),
                        #"Scenario Converted to Table" = Table.FromRecords({Source_Scenario}),
                        #"Scenario Removed Columns" = Table.RemoveColumns(#"Scenario Converted to Table",{"@odata.context"}),
                        #"Scenario Expanded value" = Table.ExpandListColumn(#"Scenario Removed Columns", "value"),
                        Output_Source_Scenario = Table.ExpandRecordColumn(#"Scenario Expanded value", "value",{"COD_SCENARIO", "TIPO_SCENARIO", "COD_SCENARIO_ORIGINARIO", "DESC_SCENARIO", "COD_SCENARIO_PREC", "COD_SCENARIO_SUCC", "COD_SCENARIO_RIF1", "COD_SCENARIO_RIF2", "COD_SCENARIO_RIF3", "COD_SCENARIO_RIF4", "COD_SCENARIO_RIF5", "COD_VALUTA", "COD_ESERCIZIO", "DESC_VERSIONE","COD_SCENARIO_RIF_CAMBI"})
                    in 
                        Output_Source_Scenario
            ]
        ),
    
    #"0 Scenario Added Index" = Table.AddIndexColumn(Output_Source_Scenario_0, "ID_SCENARIO", 0, 1, Int64.Type),
    #"0 Scenario Duplicated Column" = Table.DuplicateColumn(#"0 Scenario Added Index", "COD_SCENARIO", "COD_SCENARIO_KEY"),
    #"0 Scenario Duplicated Column1" = Table.DuplicateColumn(#"0 Scenario Duplicated Column", "ID_SCENARIO", "ID_H_SCENARIO"),
    Scenario_0 = Table.RenameColumns(#"0 Scenario Duplicated Column1",{{"COD_SCENARIO", "Scenario Code"}, {"TIPO_SCENARIO", "Scenario Type"}, {"COD_SCENARIO_ORIGINARIO", "Original Scenario"}, {"DESC_SCENARIO", "Scenario Description"}, {"COD_SCENARIO_PREC", "Previous Scenario"}, {"COD_SCENARIO_SUCC", "Following Scenario"}, {"COD_SCENARIO_RIF1", "Reference Scenario 1"}, {"COD_SCENARIO_RIF2", "Reference Scenario 2"}, {"COD_SCENARIO_RIF3", "Reference Scenario 3"}, {"COD_SCENARIO_RIF4", "Reference Scenario 4"}, {"COD_SCENARIO_RIF5", "Reference Scenario 5"}, {"COD_VALUTA", "Scenario Currency"}, {"COD_ESERCIZIO", "Scenario Year"}, {"DESC_VERSIONE", "Version Description"}, {"COD_SCENARIO_RIF_CAMBI", "Ref. FX Rate Scenario"}, {"COD_SCENARIO_KEY", "TGK_SCENARIO_KEY"}, {"ID_SCENARIO", "TGK_SCENARIO_ID"}, {"ID_H_SCENARIO", "TGK_SCENARIO_H_ID"}})
    ,
    Scenario = List.First(List.Select(VersionCases, each _{0} = Version), null){9}
    ,
    //Scenario Grouping
        //Version 1.1.0 
    Output_Source_Scenario_G_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_SCENARIO_GERARCHIA = Text.Type,
                        DESC_SCENARIO_GERARCHIA = Text.Type,
                        COD_SCENARIO_ELEGER1 = Text.Type,
                        DESC_SCENARIO_ELEGER1 = Text.Type,
                        COD_SCENARIO_ELEGER2 = Text.Type,
                        DESC_SCENARIO_ELEGER2 = Text.Type,
                        COD_SCENARIO_ELEGER3 = Text.Type,
                        DESC_SCENARIO_ELEGER3 = Text.Type,
                        COD_SCENARIO_ELEGER4 = Text.Type,
                        DESC_SCENARIO_ELEGER4 = Text.Type,
                        COD_SCENARIO_ELEGER5 = Text.Type,
                        DESC_SCENARIO_ELEGER5 = Text.Type,
                        COD_SCENARIO_ELEGER6 = Text.Type,
                        DESC_SCENARIO_ELEGER6 = Text.Type,
                        COD_SCENARIO_ELEGER7 = Text.Type,
                        DESC_SCENARIO_ELEGER7 = Text.Type,
                        COD_SCENARIO_ELEGER8 = Text.Type,
                        DESC_SCENARIO_ELEGER8 = Text.Type,
                        COD_SCENARIO_KEY = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Scenario_G = Json.Document(Web.Contents(outputURL &"Datasource_000024()?$filter=FM eq '" & Model & "'&$select=COD_SCENARIO_ELEGER8,DESC_SCENARIO_GERARCHIA,DESC_SCENARIO_ELEGER8,COD_SCENARIO_GERARCHIA,COD_SCENARIO_ELEGER1,DESC_SCENARIO_ELEGER1,COD_SCENARIO_ELEGER2,DESC_SCENARIO_ELEGER2,COD_SCENARIO_ELEGER3,DESC_SCENARIO_ELEGER3,COD_SCENARIO_ELEGER4,DESC_SCENARIO_ELEGER4,COD_SCENARIO_ELEGER5,DESC_SCENARIO_ELEGER5,COD_SCENARIO_ELEGER6,DESC_SCENARIO_ELEGER6,COD_SCENARIO_ELEGER7,DESC_SCENARIO_ELEGER7,COD_SCENARIO_KEY" ,[Timeout=#duration(0,0,30,0)])),
                        #"Scenario_G Converted to Table" = Table.FromRecords({Source_Scenario_G}),
                        #"Scenario_G Removed Columns" = Table.RemoveColumns(#"Scenario_G Converted to Table",{"@odata.context"}),
                        #"Scenario_G Expanded value" = Table.ExpandListColumn(#"Scenario_G Removed Columns", "value"),
                        Output_Source_Scenario_G = Table.ExpandRecordColumn(#"Scenario_G Expanded value", "value",{"COD_SCENARIO_GERARCHIA","DESC_SCENARIO_GERARCHIA","COD_SCENARIO_ELEGER1","DESC_SCENARIO_ELEGER1","COD_SCENARIO_ELEGER2","DESC_SCENARIO_ELEGER2","COD_SCENARIO_ELEGER3","DESC_SCENARIO_ELEGER3","COD_SCENARIO_ELEGER4","DESC_SCENARIO_ELEGER4","COD_SCENARIO_ELEGER5","DESC_SCENARIO_ELEGER5","COD_SCENARIO_ELEGER6","DESC_SCENARIO_ELEGER6","COD_SCENARIO_ELEGER7","DESC_SCENARIO_ELEGER7","COD_SCENARIO_ELEGER8","DESC_SCENARIO_ELEGER8","COD_SCENARIO_KEY"})
                    in 
                        Output_Source_Scenario_G
            ]
        ),
    #"1 Scenario_G Merged Queries" = Table.NestedJoin(Output_Source_Scenario_G_1, {"COD_SCENARIO_KEY"}, Scenario, {"TGK_SCENARIO_KEY"}, "Scenario", JoinKind.LeftOuter),
    #"1 Scenario_G Expanded Columns" = Table.ExpandTableColumn(#"1 Scenario_G Merged Queries", "Scenario", {"TGK_SCENARIO_H_ID"}, {"TGK_SCENARIO_H_ID"}),
    Scenario_G_1  = Table.RenameColumns(#"1 Scenario_G Expanded Columns",{{"COD_SCENARIO_GERARCHIA", "Scenario Grouping Code"}, {"DESC_SCENARIO_GERARCHIA", "Scenario Grouping Description"}, {"COD_SCENARIO_ELEGER1", "Scenario Grouping Code Level 1"}, {"COD_SCENARIO_ELEGER2", "Scenario Grouping Code Level 2"}, {"COD_SCENARIO_ELEGER3", "Scenario Grouping Code Level 3"}, {"COD_SCENARIO_ELEGER4", "Scenario Grouping Code Level 4"}, {"COD_SCENARIO_ELEGER5", "Scenario Grouping Code Level 5"}, {"COD_SCENARIO_ELEGER6", "Scenario Grouping Code Level 6"}, {"COD_SCENARIO_ELEGER7", "Scenario Grouping Code Level 7"}, {"COD_SCENARIO_ELEGER8", "Scenario Grouping Code Level 8"}, {"DESC_SCENARIO_ELEGER1", "Scenario Grouping Description Level 1"}, {"DESC_SCENARIO_ELEGER2", "Scenario Grouping Description Level 2"}, {"DESC_SCENARIO_ELEGER3", "Scenario Grouping Description Level 3"}, {"DESC_SCENARIO_ELEGER4", "Scenario Grouping Description Level 4"}, {"DESC_SCENARIO_ELEGER5", "Scenario Grouping Description Level 5"}, {"DESC_SCENARIO_ELEGER6", "Scenario Grouping Description Level 6"}, {"DESC_SCENARIO_ELEGER7", "Scenario Grouping Description Level 7"}, {"DESC_SCENARIO_ELEGER8", "Scenario Grouping Description Level 8"},{"COD_SCENARIO_KEY", "TGK_SCENARIO_H_KEY"}})
    ,
    //Version 1.0.0 
    Output_Source_Scenario_G_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_SCENARIO_GERARCHIA = Text.Type,
                        DESC_SCENARIO_GERARCHIA = Text.Type,
                        COD_SCENARIO_ELEGER1 = Text.Type,
                        DESC_SCENARIO_ELEGER1 = Text.Type,
                        COD_SCENARIO_ELEGER2 = Text.Type,
                        DESC_SCENARIO_ELEGER2 = Text.Type,
                        COD_SCENARIO_ELEGER3 = Text.Type,
                        DESC_SCENARIO_ELEGER3 = Text.Type,
                        COD_SCENARIO_ELEGER4 = Text.Type,
                        DESC_SCENARIO_ELEGER4 = Text.Type,
                        COD_SCENARIO_ELEGER5 = Text.Type,
                        DESC_SCENARIO_ELEGER5 = Text.Type,
                        COD_SCENARIO_ELEGER6 = Text.Type,
                        DESC_SCENARIO_ELEGER6 = Text.Type,
                        COD_SCENARIO_ELEGER7 = Text.Type,
                        DESC_SCENARIO_ELEGER7 = Text.Type,
                        COD_SCENARIO_ELEGER8 = Text.Type,
                        DESC_SCENARIO_ELEGER8 = Text.Type,
                        COD_SCENARIO_KEY = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Scenario_G = Json.Document(Web.Contents(outputURL &"Datasource_000024()" ,[Timeout=#duration(0,0,30,0)])),
                        #"Scenario_G Converted to Table" = Table.FromRecords({Source_Scenario_G}),
                        #"Scenario_G Removed Columns" = Table.RemoveColumns(#"Scenario_G Converted to Table",{"@odata.context"}),
                        #"Scenario_G Expanded value" = Table.ExpandListColumn(#"Scenario_G Removed Columns", "value"),
                        Output_Source_Scenario_G = Table.ExpandRecordColumn(#"Scenario_G Expanded value", "value",{"COD_SCENARIO_GERARCHIA","DESC_SCENARIO_GERARCHIA","COD_SCENARIO_ELEGER1","DESC_SCENARIO_ELEGER1","COD_SCENARIO_ELEGER2","DESC_SCENARIO_ELEGER2","COD_SCENARIO_ELEGER3","DESC_SCENARIO_ELEGER3","COD_SCENARIO_ELEGER4","DESC_SCENARIO_ELEGER4","COD_SCENARIO_ELEGER5","DESC_SCENARIO_ELEGER5","COD_SCENARIO_ELEGER6","DESC_SCENARIO_ELEGER6","COD_SCENARIO_ELEGER7","DESC_SCENARIO_ELEGER7","COD_SCENARIO_ELEGER8","DESC_SCENARIO_ELEGER8","COD_SCENARIO_KEY"})
                    in 
                        Output_Source_Scenario_G
            ]
        ),
    #"0 Scenario_G Merged Queries" = Table.NestedJoin(Output_Source_Scenario_G_0, {"COD_SCENARIO_KEY"}, Scenario, {"TGK_SCENARIO_KEY"}, "Scenario", JoinKind.LeftOuter),
    #"0 Scenario_G Expanded Columns" = Table.ExpandTableColumn(#"0 Scenario_G Merged Queries", "Scenario", {"TGK_SCENARIO_H_ID"}, {"TGK_SCENARIO_H_ID"}),
    Scenario_G_0  = Table.RenameColumns(#"0 Scenario_G Expanded Columns",{{"COD_SCENARIO_GERARCHIA", "Scenario Grouping Code"}, {"DESC_SCENARIO_GERARCHIA", "Scenario Grouping Description"}, {"COD_SCENARIO_ELEGER1", "Scenario Grouping Code Level 1"}, {"COD_SCENARIO_ELEGER2", "Scenario Grouping Code Level 2"}, {"COD_SCENARIO_ELEGER3", "Scenario Grouping Code Level 3"}, {"COD_SCENARIO_ELEGER4", "Scenario Grouping Code Level 4"}, {"COD_SCENARIO_ELEGER5", "Scenario Grouping Code Level 5"}, {"COD_SCENARIO_ELEGER6", "Scenario Grouping Code Level 6"}, {"COD_SCENARIO_ELEGER7", "Scenario Grouping Code Level 7"}, {"COD_SCENARIO_ELEGER8", "Scenario Grouping Code Level 8"}, {"DESC_SCENARIO_ELEGER1", "Scenario Grouping Description Level 1"}, {"DESC_SCENARIO_ELEGER2", "Scenario Grouping Description Level 2"}, {"DESC_SCENARIO_ELEGER3", "Scenario Grouping Description Level 3"}, {"DESC_SCENARIO_ELEGER4", "Scenario Grouping Description Level 4"}, {"DESC_SCENARIO_ELEGER5", "Scenario Grouping Description Level 5"}, {"DESC_SCENARIO_ELEGER6", "Scenario Grouping Description Level 6"}, {"DESC_SCENARIO_ELEGER7", "Scenario Grouping Description Level 7"}, {"DESC_SCENARIO_ELEGER8", "Scenario Grouping Description Level 8"},{"COD_SCENARIO_KEY", "TGK_SCENARIO_H_KEY"}})
    ,
    Scenario_G = List.First(List.Select(VersionCases, each _{0} = Version), null){10}
    ,
    //Scenario Period
    //Version 1.1.0 
    Output_Source_ScenarioPeriod_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        DATA_INIZIO_MENSILE = Text.Type,
                        DATA_FINE = Text.Type,
                        DATA_INIZIO = Text.Type,
                        LUNGHEZZA_PERIODO = Number.Type,
                        COD_SCENARIO_PERIODO_KEY = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_ScenarioPeriod = Json.Document(Web.Contents(outputURL &"Datasource_000007()?$filter=FM eq '" & Model & "'&$select=DATA_INIZIO_MENSILE,DATA_FINE,DATA_INIZIO,LUNGHEZZA_PERIODO,COD_SCENARIO_PERIODO_KEY" ,[Timeout=#duration(0,0,30,0)])),
                        #"ScenarioPeriod Converted to Table" = Table.FromRecords({Source_ScenarioPeriod}),
                        #"ScenarioPeriod Removed Columns" = Table.RemoveColumns(#"ScenarioPeriod Converted to Table",{"@odata.context"}),
                        #"ScenarioPeriod Expanded value" = Table.ExpandListColumn(#"ScenarioPeriod Removed Columns", "value"),
                        Output_Source_ScenarioPeriod = Table.ExpandRecordColumn(#"ScenarioPeriod Expanded value", "value",{"DATA_INIZIO_MENSILE","DATA_FINE","DATA_INIZIO","LUNGHEZZA_PERIODO","COD_SCENARIO_PERIODO_KEY"})
                    in 
                        Output_Source_ScenarioPeriod
            ]
        ),
    #"1 ScenarioPeriod Changed Type" = Table.TransformColumnTypes(Output_Source_ScenarioPeriod_1,{{"DATA_INIZIO_MENSILE", type date}, {"DATA_FINE", type date}, {"DATA_INIZIO", type date}}),
    #"1 ScenarioPeriod Added Year" = Table.AddColumn(#"1 ScenarioPeriod Changed Type", "Scenario Period Year", each Date.Year([DATA_INIZIO])),
    #"1 ScenarioPeriod Changed Type2" = Table.TransformColumnTypes(#"1 ScenarioPeriod Added Year",{{"Scenario Period Year", Int64.Type}, {"LUNGHEZZA_PERIODO", type text}}),
    #"1 ScenarioPeriod Added Index" = Table.AddIndexColumn(#"1 ScenarioPeriod Changed Type2", "TGK_SCENARIO_PERIOD_ID", 0, 1, Int64.Type),
    #"1 ScenarioPeriod Duplicated Column" = Table.DuplicateColumn(#"1 ScenarioPeriod Added Index", "TGK_SCENARIO_PERIOD_ID", "TGK_SCENARIO_PERIOD_ER_ID"),
    ScenarioPeriod_1 = Table.RenameColumns(#"1 ScenarioPeriod Duplicated Column",{{"COD_SCENARIO_PERIODO_KEY", "TGK_SCENARIO_PERIOD_KEY"}, {"DATA_INIZIO", "Scenario Start Date"}, {"DATA_INIZIO_MENSILE", "Scenario Period Start Date"}, {"DATA_FINE", "Scenario Period End Date"}, {"LUNGHEZZA_PERIODO", "Scenario Period Length"}})
    ,
    //Version 1.0.0 
    Output_Source_ScenarioPeriod_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        DATA_INIZIO_MENSILE = Text.Type,
                        DATA_FINE = Text.Type,
                        DATA_INIZIO = Text.Type,
                        LUNGHEZZA_PERIODO = Number.Type,
                        COD_SCENARIO_PERIODO_KEY = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_ScenarioPeriod = Json.Document(Web.Contents(outputURL &"Datasource_000007()" ,[Timeout=#duration(0,0,30,0)])),
                        #"ScenarioPeriod Converted to Table" = Table.FromRecords({Source_ScenarioPeriod}),
                        #"ScenarioPeriod Removed Columns" = Table.RemoveColumns(#"ScenarioPeriod Converted to Table",{"@odata.context"}),
                        #"ScenarioPeriod Expanded value" = Table.ExpandListColumn(#"ScenarioPeriod Removed Columns", "value"),
                        Output_Source_ScenarioPeriod = Table.ExpandRecordColumn(#"ScenarioPeriod Expanded value", "value",{"DATA_INIZIO_MENSILE","DATA_FINE","DATA_INIZIO","LUNGHEZZA_PERIODO","COD_SCENARIO_PERIODO_KEY"})
                    in 
                        Output_Source_ScenarioPeriod
            ]
        ),
    #"0 ScenarioPeriod Changed TypeDateTime" = Table.TransformColumnTypes(Output_Source_ScenarioPeriod_0,{{"DATA_INIZIO_MENSILE", type datetime}, {"DATA_FINE", type datetime}, {"DATA_INIZIO", type datetime}}),
    #"0 ScenarioPeriod Changed Type" = Table.TransformColumnTypes(#"0 ScenarioPeriod Changed TypeDateTime",{{"DATA_INIZIO_MENSILE", type date}, {"DATA_FINE", type date}, {"DATA_INIZIO", type date}}),
    #"0 ScenarioPeriod Added Year" = Table.AddColumn(#"0 ScenarioPeriod Changed Type", "Scenario Period Year", each Date.Year([DATA_INIZIO])),
    #"0 ScenarioPeriod Changed Type2" = Table.TransformColumnTypes(#"0 ScenarioPeriod Added Year",{{"Scenario Period Year", Int64.Type}, {"LUNGHEZZA_PERIODO", type text}}),
    #"0 ScenarioPeriod Added Index" = Table.AddIndexColumn(#"0 ScenarioPeriod Changed Type2", "TGK_SCENARIO_PERIOD_ID", 0, 1, Int64.Type),
    #"0 ScenarioPeriod Duplicated Column" = Table.DuplicateColumn(#"0 ScenarioPeriod Added Index", "TGK_SCENARIO_PERIOD_ID", "TGK_SCENARIO_PERIOD_ER_ID"),
    ScenarioPeriod_0 = Table.RenameColumns(#"0 ScenarioPeriod Duplicated Column",{{"COD_SCENARIO_PERIODO_KEY", "TGK_SCENARIO_PERIOD_KEY"}, {"DATA_INIZIO", "Scenario Start Date"}, {"DATA_INIZIO_MENSILE", "Scenario Period Start Date"}, {"DATA_FINE", "Scenario Period End Date"}, {"LUNGHEZZA_PERIODO", "Scenario Period Length"}})
    ,
    ScenarioPeriod = List.First(List.Select(VersionCases, each _{0} = Version), null){11}
    , 
    //Calendar
    //Version 1.1.0 
    Output_Source_CalendarDate_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_DATE = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_CalendarDate = Json.Document(Web.Contents(outputURL &"Datasource_000022()?$filter=FM eq '" & Model & "'&$select=COD_DATE" ,[Timeout=#duration(0,0,30,0)])),
                        #"CalendarDate Converted to Table" = Table.FromRecords({Source_CalendarDate}),
                        #"CalendarDate Removed Columns" = Table.RemoveColumns(#"CalendarDate Converted to Table",{"@odata.context"}),
                        #"CalendarDate Expanded value" = Table.ExpandListColumn(#"CalendarDate Removed Columns", "value"),
                        Output_Source_CalendarDate = Table.ExpandRecordColumn(#"CalendarDate Expanded value", "value",{"COD_DATE"})                       
                    in 
                        Output_Source_CalendarDate
                      ]
        ),
    
    #"1 CalendarDate Changed Type" = Table.TransformColumnTypes(Output_Source_CalendarDate_1,{{"COD_DATE", type datetime}}),
    #"1 CalendarDate Changed Type2" = Table.TransformColumnTypes(#"1 CalendarDate Changed Type",{{"COD_DATE", type date}}),
    #"1 MinPeriodDate" = Date.AddDays(List.Min(#"1 CalendarDate Changed Type2"[COD_DATE]),-60),
    #"1 MaxPeriodDate" = Date.AddDays(List.Max(#"1 CalendarDate Changed Type2"[COD_DATE]),30),
    Source_Calendar_1 = CreateCalendar(#"1 MinPeriodDate", #"1 MaxPeriodDate"),
    #"1 Calendar Changed Type" = Table.TransformColumnTypes(Source_Calendar_1,{{"Date", type date}, {"Year", Int64.Type}, {"Quarter", type text}, {"Month Number", Int64.Type}, {"Month", type text}}),
    #"1 Calendar Renamed Columns" = Table.RenameColumns(#"1 Calendar Changed Type",{{"Date", "TGK_CALENDAR_KEY"}}), 
    #"1 Calendar AddColumn Start" = Table.AddColumn(#"1 Calendar Renamed Columns", "Calendar Start Date", each #"1 MinPeriodDate"),
    #"1 Calendar AddColumn End" = Table.AddColumn( #"1 Calendar AddColumn Start"  , "Calendar End Date", each #"1 MaxPeriodDate"),
    #"1 Calendar Reordered Columns" = Table.ReorderColumns(#"1 Calendar AddColumn End",{"Year", "Quarter", "Month Number", "Month", "Calendar Start Date", "Calendar End Date", "TGK_CALENDAR_KEY"}),
    Output_Transformed_Calendar1 = Table.TransformColumnTypes(#"1 Calendar Reordered Columns",{{"Calendar Start Date", type date}, {"Calendar End Date", type date}})
    ,
    //Create Ordered Join Table
    #"Scenario Period Source JoinTable" = Table.SelectColumns(ScenarioPeriod,{"TGK_SCENARIO_PERIOD_KEY","TGK_SCENARIO_PERIOD_ID","Scenario Period End Date"}),
    #"ScenarioPeriod JoinTable Duplicated Column" = Table.DuplicateColumn(#"Scenario Period Source JoinTable", "TGK_SCENARIO_PERIOD_KEY", "TGK_SCENARIO_PERIOD_KEY_TO_SPLIT"),
    #"ScenarioPeriod JoinTable Split" = Table.SplitColumn(#"ScenarioPeriod JoinTable Duplicated Column", "TGK_SCENARIO_PERIOD_KEY_TO_SPLIT", Splitter.SplitTextByDelimiter("|", QuoteStyle.None), {"TGK_SCENARIO_KEY", "TGK_PERIOD_KEY"}),
    #"ScenarioPeriod JoinTable Sorted" = Table.Sort(#"ScenarioPeriod JoinTable Split", {{"Scenario Period End Date", Order.Ascending},{"TGK_PERIOD_KEY", Order.Descending}}),
    #"ScenarioPeriod JoinTable Grouped" = Table.Group(
        #"ScenarioPeriod JoinTable Sorted", 
        {"Scenario Period End Date"}, 
        {
            {"Join", each Table.AddIndexColumn(_, "ID", 0, 1, Int64.Type)}
        }
    ),
    #"ScenarioPeriod JoinTable Expanded" = Table.ExpandTableColumn(#"ScenarioPeriod JoinTable Grouped", "Join", {"TGK_SCENARIO_PERIOD_KEY","TGK_SCENARIO_PERIOD_ID","TGK_PERIOD_KEY", "ID"}),
    #"ScenarioPeriod JoinTable Add Adjusted Date" = Table.AddColumn(
        #"ScenarioPeriod JoinTable Expanded", 
        "AdjustedDate", 
        each Date.AddDays([Scenario Period End Date], -[ID]), 
        type date
    ),
    #"ScenarioPeriod Jointable"= Table.AddIndexColumn( #"ScenarioPeriod JoinTable Add Adjusted Date" , "OriginalIndex", 0, 1, Int64.Type),

    #"1 Calendar JoinScenarioPeriod" = Table.NestedJoin(Output_Transformed_Calendar1, {"TGK_CALENDAR_KEY"}, #"ScenarioPeriod Jointable", {"AdjustedDate"}, "JoinDate", JoinKind.LeftOuter),
    #"1 Calendar Expanded JoinDate" = Table.ExpandTableColumn(#"1 Calendar JoinScenarioPeriod", "JoinDate", {"AdjustedDate", "TGK_SCENARIO_PERIOD_KEY","TGK_SCENARIO_PERIOD_ID","TGK_PERIOD_KEY"},{"Calendar Adjusted Date", "TGK_SCENARIO_PERIOD_C_KEY","TGK_SCENARIO_PERIOD_ID","TGK_PERIOD_C_KEY"}),
    #"1 Calendar ReplacedNulls ScenarioPeriod" = Table.ReplaceValue(#"1 Calendar Expanded JoinDate",null,each [TGK_CALENDAR_KEY],Replacer.ReplaceValue,{"TGK_SCENARIO_PERIOD_ID"}),
    #"1 Calendar Merged Period" = Table.NestedJoin(#"1 Calendar ReplacedNulls ScenarioPeriod", {"TGK_PERIOD_C_KEY"}, Period, {"TGK_PERIOD_KEY"}, "Period", JoinKind.LeftOuter),
    #"1 Calendar Expanded Period" = Table.ExpandTableColumn(#"1 Calendar Merged Period", "Period", {"TGK_PERIOD_ID"}),
    #"1 Calendar ReplacedNulls Period" = Table.ReplaceValue(#"1 Calendar Expanded Period", null, each [Month Number], Replacer.ReplaceValue, {"TGK_PERIOD_ID"}),
    #"1 Calendar Join Changed Type" = Table.TransformColumnTypes(#"1 Calendar ReplacedNulls Period",{{"TGK_SCENARIO_PERIOD_C_KEY", type text}, {"TGK_PERIOD_C_KEY", type text}, {"TGK_SCENARIO_PERIOD_ID", Int64.Type}, {"TGK_PERIOD_ID", Int64.Type}}),
    Calendar_1=   #"1 Calendar Join Changed Type"
    ,
    //Version 1.0.0
    Output_Source_CalendarDate_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_DATE = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_CalendarDate = Json.Document(Web.Contents(outputURL &"Datasource_000022()" ,[Timeout=#duration(0,0,30,0)])),
                        #"CalendarDate Converted to Table" = Table.FromRecords({Source_CalendarDate}),
                        #"CalendarDate Removed Columns" = Table.RemoveColumns(#"CalendarDate Converted to Table",{"@odata.context"}),
                        #"CalendarDate Expanded value" = Table.ExpandListColumn(#"CalendarDate Removed Columns", "value"),
                        Output_Source_CalendarDate = Table.ExpandRecordColumn(#"CalendarDate Expanded value", "value",{"COD_DATE"})                       
                    in 
                        Output_Source_CalendarDate
            ]
        ),
    #"0 CalendarDate Changed Type" = Table.TransformColumnTypes(Output_Source_CalendarDate_0,{{"COD_DATE", type datetime}}),
    #"0 CalendarDate Changed Type2" = Table.TransformColumnTypes(#"0 CalendarDate Changed Type",{{"COD_DATE", type date}}),
    #"0 MinPeriodDate" = Date.AddDays(List.Min(#"0 CalendarDate Changed Type2"[COD_DATE]),-60),
    #"0 MaxPeriodDate" = Date.AddDays(List.Max(#"0 CalendarDate Changed Type2"[COD_DATE]),30),
    Source_Calendar_0 = CreateCalendar( #"0 MinPeriodDate", #"0 MaxPeriodDate"),
    #"0 Calendar Changed Type" = Table.TransformColumnTypes(Source_Calendar_0,{{"Date", type date}, {"Year", Int64.Type}, {"Quarter", type text}, {"Month Number", Int64.Type}, {"Month", type text}}),
    #"0 Calendar Renamed Columns" = Table.RenameColumns(#"0 Calendar Changed Type",{{"Date", "TGK_CALENDAR_KEY"}}),
    #"0 Calendar Merged Queries" = Table.NestedJoin(#"0 Calendar Renamed Columns", {"Month Number"}, Period, {"Period Num"}, "Period", JoinKind.LeftOuter),
    #"0 Calendar Expanded Period" = Table.ExpandTableColumn(#"0 Calendar Merged Queries", "Period", {"TGK_PERIOD_ID"}, {"TGK_PERIOD_ID"}) ,  
    #"0 Calendar AddColumn Start" = Table.AddColumn(#"0 Calendar Expanded Period" , "Calendar Start Date", each #"0 MinPeriodDate"),
    #"0 Calendar AddColumn End" = Table.AddColumn( #"0 Calendar AddColumn Start"  , "Calendar End Date", each #"0 MaxPeriodDate"),
    #"0 Calendar Reordered Columns" = Table.ReorderColumns(#"0 Calendar AddColumn End",{"Year", "Quarter", "Month Number", "Month", "Calendar Start Date", "Calendar End Date", "TGK_CALENDAR_KEY", "TGK_PERIOD_ID"}),
    Calendar_0 = Table.TransformColumnTypes(#"0 Calendar Reordered Columns",{{"Calendar Start Date", type date}, {"Calendar End Date", type date}})
    ,
    Calendar = List.First(List.Select(VersionCases, each _{0} = Version), null){2}
    ,
    //Period value calculation
    Source_PeriodicValueCalculation = Table.FromRecords({
        [Periodic Value Calculation Description = "Aggregation of periodic values"],
        [Periodic Value Calculation Description = "Net Year-to-date values"]
    }),
    PeriodicValueCalculation = Table.TransformColumnTypes(Source_PeriodicValueCalculation,{{"Periodic Value Calculation Description", type text}})
    ,
    //Transaction Currency
    Output_Source_TransactionCurrency =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_VALUTA = Text.Type,
                        DESC_VALUTA = Text.Type,
                        PERC_SCOSTAMENTO = Number.Type,
                        COD_VALUTA1 = Text.Type,
                        COD_VALUTA2 = Text.Type,
                        NUM_DECIMALI = Number.Type,
                        COD_VALUTA_RIF = Text.Type,
                        COEFFICIENTE_RIF = Number.Type,
                        MEASURE_XBRL = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_TransactionCurrency = Json.Document(Web.Contents(outputURL &"Datasource_000025()" ,[Timeout=#duration(0,0,30,0)])),
                        #"TransactionCurrency Converted to Table" = Table.FromRecords({Source_TransactionCurrency}),
                        #"TransactionCurrency Removed Columns" = Table.RemoveColumns(#"TransactionCurrency Converted to Table",{"@odata.context"}),
                        #"TransactionCurrency Expanded value" = Table.ExpandListColumn(#"TransactionCurrency Removed Columns", "value"),
                        Output_Source_TransactionCurrency = Table.ExpandRecordColumn(#"TransactionCurrency Expanded value", "value",{"COD_VALUTA","DESC_VALUTA","PERC_SCOSTAMENTO","COD_VALUTA1","COD_VALUTA2","NUM_DECIMALI","COD_VALUTA_RIF","COEFFICIENTE_RIF","MEASURE_XBRL"})
                    in 
                        Output_Source_TransactionCurrency
            ]
        ),
    #"Transaction Currency Added Index" = Table.AddIndexColumn(Output_Source_TransactionCurrency , "ID_VALUTA", 0, 1, Int64.Type),
    #"Transaction Currency Duplicated Column" = Table.DuplicateColumn(#"Transaction Currency Added Index", "COD_VALUTA", "COD_VALUTA_KEY"),
    #"Transaction Currency Duplicated Index" = Table.DuplicateColumn(#"Transaction Currency Duplicated Column", "ID_VALUTA", "TGK_SOURCE_CURRENCY_ER_ID"),
    TransactionCurrency = Table.RenameColumns(#"Transaction Currency Duplicated Index",{{"COD_VALUTA", "Transaction Currency Code"}, {"DESC_VALUTA", "Transaction Currency Description"}, {"PERC_SCOSTAMENTO", "Transaction Currency Variance Perc"}, {"COD_VALUTA1", "Transaction Currency Code 1"}, {"COD_VALUTA2", "Transaction Currency Code 2"}, {"NUM_DECIMALI", "Transaction Currency Decimal Numbers"}, {"COD_VALUTA_RIF", "Transaction Currency Ref Code"}, {"COEFFICIENTE_RIF", "Transaction Currency Ref Coefficient"}, {"MEASURE_XBRL", "Transaction Currency XBRL Measure"}, {"COD_VALUTA_KEY", "TGK_TRANSACTION_CURRENCY_KEY"}, {"ID_VALUTA", "TGK_TRANSACTION_CURRENCY_ID"}, {"TGK_SOURCE_CURRENCY_ER_ID", "TGK_TRANSACTION_CURRENCY_ER_ID"}})
    ,
    //Target Currency
    Source_TargetCurrency = Table.SelectColumns(TransactionCurrency, {"Transaction Currency Code", "TGK_TRANSACTION_CURRENCY_KEY", "TGK_TRANSACTION_CURRENCY_ID"}),
    TargetCurrency = Table.RenameColumns(Source_TargetCurrency,{{"TGK_TRANSACTION_CURRENCY_KEY", "TGK_TARGET_CURRENCY_KEY"}, {"TGK_TRANSACTION_CURRENCY_ID", "TGK_TARGET_CURRENCY_ID"}, {"Transaction Currency Code", "Target Currency Code"}})
    ,
    //User Rights

    //User Rights Account
    //Version 1.1.0 
    Output_Source_UserRightsAccount_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        U = Text.Type,
                        D = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsAccount = Json.Document(Web.Contents(outputURL &"Datasource_000037()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsAccount Converted to Table" = Table.FromRecords({Source_UserRightsAccount}),
                        #"UserRightsAccount Removed Columns" = Table.RemoveColumns(#"UserRightsAccount Converted to Table",{"@odata.context"}),
                        #"UserRightsAccount Expanded value" = Table.ExpandListColumn(#"UserRightsAccount Removed Columns", "value"),
                        Output_Source_UserRightsAccount = Table.ExpandRecordColumn(#"UserRightsAccount Expanded value", "value",{"U", "D"})
                    in 
                        Output_Source_UserRightsAccount
            ]
        ),
    
    #"1 UserRightsAccount Merged Queries" = Table.NestedJoin(Output_Source_UserRightsAccount_1, {"D"}, Account, {"TGK_ACCOUNT_KEY"}, "Account", JoinKind.LeftOuter),
    #"1 UserRightsAccount Expanded" = Table.ExpandTableColumn(#"1 UserRightsAccount Merged Queries", "Account", {"TGK_ACCOUNT_ID"}, {"TGK_ACCOUNT_UR_ID"}),
    UserRightsAccount_1  = Table.RenameColumns(#"1 UserRightsAccount Expanded" ,{{"D", "TGK_ACCOUNT_UR_KEY"}, {"U", "TGK_ACCOUNT_UR_USERID"}})
    ,
    //Version 1.0.0 
    Output_Source_UserRightsAccount_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_UTENTE = Text.Type,
                        COD_CONTO = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsAccount = Json.Document(Web.Contents(outputURL &"Datasource_000037()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsAccount Converted to Table" = Table.FromRecords({Source_UserRightsAccount}),
                        #"UserRightsAccount Removed Columns" = Table.RemoveColumns(#"UserRightsAccount Converted to Table",{"@odata.context"}),
                        #"UserRightsAccount Expanded value" = Table.ExpandListColumn(#"UserRightsAccount Removed Columns", "value"),
                        Output_Source_UserRightsAccount = Table.ExpandRecordColumn(#"UserRightsAccount Expanded value", "value",{"COD_UTENTE", "COD_CONTO"})
                    in 
                        Output_Source_UserRightsAccount
            ]
        ),
    
    #"0 UserRightsAccount Merged Queries" = Table.NestedJoin(Output_Source_UserRightsAccount_0, {"COD_CONTO"}, Account, {"TGK_ACCOUNT_KEY"}, "Account", JoinKind.LeftOuter),
    #"0 UserRightsAccount Expanded" = Table.ExpandTableColumn(#"0 UserRightsAccount Merged Queries", "Account", {"TGK_ACCOUNT_ID"}, {"TGK_ACCOUNT_UR_ID"}),
    UserRightsAccount_0  = Table.RenameColumns(#"0 UserRightsAccount Expanded" ,{{"COD_CONTO", "TGK_ACCOUNT_UR_KEY"}, {"COD_UTENTE", "TGK_ACCOUNT_UR_USERID"}})
    ,
    UserRightsAccount = List.First(List.Select(VersionCases, each _{0} = Version), null){12}
    ,
    //User Rights Category
    //Version 1.1.0 
    Output_Source_UserRightsCategory_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        U = Text.Type,
                        D = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsCategory = Json.Document(Web.Contents(outputURL &"Datasource_000031()?$filter=FM eq '" & Model & "'&$select=U,D" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsCategory Converted to Table" = Table.FromRecords({Source_UserRightsCategory}),
                        #"UserRightsCategory Removed Columns" = Table.RemoveColumns(#"UserRightsCategory Converted to Table",{"@odata.context"}),
                        #"UserRightsCategory Expanded value" = Table.ExpandListColumn(#"UserRightsCategory Removed Columns", "value"),
                        Output_Source_UserRightsCategory = Table.ExpandRecordColumn(#"UserRightsCategory Expanded value", "value",{"U", "D"})
                    in 
                        Output_Source_UserRightsCategory
            ]
        ),
    
    #"1 UserRightsCategory Merged Queries" = Table.NestedJoin(Output_Source_UserRightsCategory_1, {"D"}, Category, {"TGK_CATEGORY_KEY"}, "Category", JoinKind.LeftOuter),
    #"1 UserRightsCategory Expanded" = Table.ExpandTableColumn(#"1 UserRightsCategory Merged Queries", "Category", {"TGK_CATEGORY_ID"}, {"TGK_CATEGORY_UR_ID"}),
    UserRightsCategory_1  = Table.RenameColumns(#"1 UserRightsCategory Expanded" ,{{"D", "TGK_CATEGORY_UR_KEY"}, {"U", "TGK_CATEGORY_UR_USERID"}})
    ,
    //Version 1.0.0 
    Output_Source_UserRightsCategory_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_UTENTE = Text.Type,
                        COD_CATEGORIA = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsCategory = Json.Document(Web.Contents(outputURL &"Datasource_000031()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsCategory Converted to Table" = Table.FromRecords({Source_UserRightsCategory}),
                        #"UserRightsCategory Removed Columns" = Table.RemoveColumns(#"UserRightsCategory Converted to Table",{"@odata.context"}),
                        #"UserRightsCategory Expanded value" = Table.ExpandListColumn(#"UserRightsCategory Removed Columns", "value"),
                        Output_Source_UserRightsCategory = Table.ExpandRecordColumn(#"UserRightsCategory Expanded value", "value",{"COD_UTENTE", "COD_CATEGORIA"})
                    in 
                        Output_Source_UserRightsCategory
            ]
        ),
    
    #"0 UserRightsCategory Merged Queries" = Table.NestedJoin(Output_Source_UserRightsCategory_0, {"COD_CATEGORIA"}, Category, {"TGK_CATEGORY_KEY"}, "Category", JoinKind.LeftOuter),
    #"0 UserRightsCategory Expanded" = Table.ExpandTableColumn(#"0 UserRightsCategory Merged Queries", "Category", {"TGK_CATEGORY_ID"}, {"TGK_CATEGORY_UR_ID"}),
    UserRightsCategory_0  = Table.RenameColumns(#"0 UserRightsCategory Expanded" ,{{"COD_CATEGORIA", "TGK_CATEGORY_UR_KEY"}, {"COD_UTENTE", "TGK_CATEGORY_UR_USERID"}})
    ,
    UserRightsCategory = List.First(List.Select(VersionCases, each _{0} = Version), null){13}
    ,
    //User Rights Custom Dimension 1
    Output_Source_UserRightsDest1_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        U = Text.Type,
                        D = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest1 = Json.Document(Web.Contents(outputURL &"Datasource_000032()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest1 Converted to Table" = Table.FromRecords({Source_UserRightsDest1}),
                        #"UserRightsDest1 Removed Columns" = Table.RemoveColumns(#"UserRightsDest1 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest1 Expanded value" = Table.ExpandListColumn(#"UserRightsDest1 Removed Columns", "value"),
                        Output_Source_UserRightsDest1 = Table.ExpandRecordColumn(#"UserRightsDest1 Expanded value", "value",{"U", "D"})
                    in 
                        Output_Source_UserRightsDest1
            ]
        ),
    
    #"1 UserRightsDest1 Merged Queries" = Table.NestedJoin(Output_Source_UserRightsDest1_1, {"D"}, CustomDimension1, {"TGK_DEST1_KEY"}, "Dest1", JoinKind.LeftOuter),
    #"1 UserRightsDest1 Expanded" = Table.ExpandTableColumn(#"1 UserRightsDest1 Merged Queries", "Dest1", {"TGK_DEST1_ID"}, {"TGK_DEST1_UR_ID"}),
    UserRightsDest1_1  = Table.RenameColumns(#"1 UserRightsDest1 Expanded" ,{{"D", "TGK_DEST1_UR_KEY"}, {"U", "TGK_DEST1_UR_USERID"}})
    ,
    //Version 1.0.0 
    Output_Source_UserRightsDest1_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_UTENTE = Text.Type,
                        COD_DEST1= Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest1 = Json.Document(Web.Contents(outputURL &"Datasource_000032()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest1 Converted to Table" = Table.FromRecords({Source_UserRightsDest1}),
                        #"UserRightsDest1 Removed Columns" = Table.RemoveColumns(#"UserRightsDest1 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest1 Expanded value" = Table.ExpandListColumn(#"UserRightsDest1 Removed Columns", "value"),
                        Output_Source_UserRightsDest1 = Table.ExpandRecordColumn(#"UserRightsDest1 Expanded value", "value",{"COD_UTENTE", "COD_DEST1"})
                    in 
                        Output_Source_UserRightsDest1
            ]
        ),
    
    #"0 UserRightsDest1 Merged Queries" = Table.NestedJoin(Output_Source_UserRightsDest1_0, {"COD_DEST1"},CustomDimension1, {"TGK_DEST1_KEY"}, "Dest1", JoinKind.LeftOuter),
    #"0 UserRightsDest1 Expanded" = Table.ExpandTableColumn(#"0 UserRightsDest1 Merged Queries", "Dest1", {"TGK_DEST1_ID"}, {"TGK_DEST1_UR_ID"}),
    UserRightsDest1_0  = Table.RenameColumns(#"0 UserRightsDest1 Expanded" ,{{"COD_DEST1", "TGK_DEST1_UR_KEY"}, {"COD_UTENTE", "TGK_DEST1_UR_USERID"}})
    ,
    UserRightsDest1 =List.First(List.Select(VersionCases, each _{0} = Version), null){14}
    ,
    //User Rights Custom Dimension 2
    
    //Version 1.1.0 
    Output_Source_UserRightsDest2_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        U = Text.Type,
                        D = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest2 = Json.Document(Web.Contents(outputURL &"Datasource_000033()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest2 Converted to Table" = Table.FromRecords({Source_UserRightsDest2}),
                        #"UserRightsDest2 Removed Columns" = Table.RemoveColumns(#"UserRightsDest2 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest2 Expanded value" = Table.ExpandListColumn(#"UserRightsDest2 Removed Columns", "value"),
                        Output_Source_UserRightsDest2 = Table.ExpandRecordColumn(#"UserRightsDest2 Expanded value", "value",{"U", "D"})
                    in 
                        Output_Source_UserRightsDest2
            ]
        ),
    
    #"1 UserRightsDest2 Merged Queries" = Table.NestedJoin(Output_Source_UserRightsDest2_1, {"D"},CustomDimension2, {"TGK_DEST2_KEY"}, "Dest2", JoinKind.LeftOuter),
    #"1 UserRightsDest2 Expanded" = Table.ExpandTableColumn(#"1 UserRightsDest2 Merged Queries", "Dest2", {"TGK_DEST2_ID"}, {"TGK_DEST2_UR_ID"}),
    UserRightsDest2_1  = Table.RenameColumns(#"1 UserRightsDest2 Expanded" ,{{"D", "TGK_DEST2_UR_KEY"}, {"U", "TGK_DEST2_UR_USERID"}})
    ,
    //Version 1.0.0 
    Output_Source_UserRightsDest2_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_UTENTE = Text.Type,
                        COD_DEST2 = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest2 = Json.Document(Web.Contents(outputURL &"Datasource_000033()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest2 Converted to Table" = Table.FromRecords({Source_UserRightsDest2}),
                        #"UserRightsDest2 Removed Columns" = Table.RemoveColumns(#"UserRightsDest2 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest2 Expanded value" = Table.ExpandListColumn(#"UserRightsDest2 Removed Columns", "value"),
                        Output_Source_UserRightsDest2 = Table.ExpandRecordColumn(#"UserRightsDest2 Expanded value", "value",{"COD_UTENTE", "COD_DEST2"})
                    in 
                        Output_Source_UserRightsDest2
            ]
        ),
    
    #"0 UserRightsDest2 Merged Queries" = Table.NestedJoin(Output_Source_UserRightsDest2_0, {"COD_DEST2"}, CustomDimension2, {"TGK_DEST2_KEY"}, "Dest2", JoinKind.LeftOuter),
    #"0 UserRightsDest2 Expanded" = Table.ExpandTableColumn(#"0 UserRightsDest2 Merged Queries", "Dest2", {"TGK_DEST2_ID"}, {"TGK_DEST2_UR_ID"}),
    UserRightsDest2_0  = Table.RenameColumns(#"0 UserRightsDest2 Expanded" ,{{"COD_DEST2", "TGK_DEST2_UR_KEY"}, {"COD_UTENTE", "TGK_DEST2_UR_USERID"}})
    ,
    UserRightsDest2 =List.First(List.Select(VersionCases, each _{0} = Version), null){15}
    ,
    //User Rights Custom Dimension 3
   //Version 1.1.0 
    Output_Source_UserRightsDest3_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        U = Text.Type,
                        D = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest3 = Json.Document(Web.Contents(outputURL &"Datasource_000034()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest3 Converted to Table" = Table.FromRecords({Source_UserRightsDest3}),
                        #"UserRightsDest3 Removed Columns" = Table.RemoveColumns(#"UserRightsDest3 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest3 Expanded value" = Table.ExpandListColumn(#"UserRightsDest3 Removed Columns", "value"),
                        Output_Source_UserRightsDest3 = Table.ExpandRecordColumn(#"UserRightsDest3 Expanded value", "value",{"U", "D"})
                    in 
                        Output_Source_UserRightsDest3
            ]
        ),

    #"1 UserRightsDest3 Merged Queries" = Table.NestedJoin(Output_Source_UserRightsDest3_1, {"D"}, CustomDimension3, {"TGK_DEST3_KEY"}, "Dest3", JoinKind.LeftOuter),
    #"1 UserRightsDest3 Expanded" = Table.ExpandTableColumn(#"1 UserRightsDest3 Merged Queries", "Dest3", {"TGK_DEST3_ID"}, {"TGK_DEST3_UR_ID"}),
    UserRightsDest3_1  = Table.RenameColumns(#"1 UserRightsDest3 Expanded" ,{{"D", "TGK_DEST3_UR_KEY"}, {"U", "TGK_DEST3_UR_USERID"}})
    ,
    //Version 1.0.0 
    Output_Source_UserRightsDest3_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_UTENTE = Text.Type,
                        COD_DEST3 = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest3 = Json.Document(Web.Contents(outputURL &"Datasource_000034()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest3 Converted to Table" = Table.FromRecords({Source_UserRightsDest3}),
                        #"UserRightsDest3 Removed Columns" = Table.RemoveColumns(#"UserRightsDest3 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest3 Expanded value" = Table.ExpandListColumn(#"UserRightsDest3 Removed Columns", "value"),
                        Output_Source_UserRightsDest3 = Table.ExpandRecordColumn(#"UserRightsDest3 Expanded value", "value",{"COD_UTENTE", "COD_DEST3"})
                    in 
                        Output_Source_UserRightsDest3
            ]
        ),

    #"0 UserRightsDest3 Merged Queries" = Table.NestedJoin(Output_Source_UserRightsDest3_0, {"COD_DEST3"}, CustomDimension3, {"TGK_DEST3_KEY"}, "Dest3", JoinKind.LeftOuter),
    #"0 UserRightsDest3 Expanded" = Table.ExpandTableColumn(#"0 UserRightsDest3 Merged Queries", "Dest3", {"TGK_DEST3_ID"}, {"TGK_DEST3_UR_ID"}),
    UserRightsDest3_0  = Table.RenameColumns(#"0 UserRightsDest3 Expanded" ,{{"COD_DEST3", "TGK_DEST3_UR_KEY"}, {"COD_UTENTE", "TGK_DEST3_UR_USERID"}})
    ,
    UserRightsDest3 = List.First(List.Select(VersionCases, each _{0} = Version), null){16}
   ,
    //User Rights Custom Dimension 4
    //Version 1.1.0 
    Output_Source_UserRightsDest4_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        U = Text.Type,
                        D = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest4 = Json.Document(Web.Contents(outputURL &"Datasource_000035()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest4 Converted to Table" = Table.FromRecords({Source_UserRightsDest4}),
                        #"UserRightsDest4 Removed Columns" = Table.RemoveColumns(#"UserRightsDest4 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest4 Expanded value" = Table.ExpandListColumn(#"UserRightsDest4 Removed Columns", "value"),
                        Output_Source_UserRightsDest4 = Table.ExpandRecordColumn(#"UserRightsDest4 Expanded value", "value",{"U", "D"})
                    in 
                        Output_Source_UserRightsDest4
            ]
        ),

    #"1 UserRightsDest4 Merged Queries" = Table.NestedJoin(Output_Source_UserRightsDest4_1, {"D"}, CustomDimension4, {"TGK_DEST4_KEY"}, "Dest4", JoinKind.LeftOuter),
    #"1 UserRightsDest4 Expanded" = Table.ExpandTableColumn(#"1 UserRightsDest4 Merged Queries", "Dest4", {"TGK_DEST4_ID"}, {"TGK_DEST4_UR_ID"}),
    UserRightsDest4_1  = Table.RenameColumns(#"1 UserRightsDest4 Expanded" ,{{"D", "TGK_DEST4_UR_KEY"}, {"U", "TGK_DEST4_UR_USERID"}})
    ,
    //Version 1.0.0 
    Output_Source_UserRightsDest4_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_UTENTE = Text.Type,
                        COD_DEST4 = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest4 = Json.Document(Web.Contents(outputURL &"Datasource_000035()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest4 Converted to Table" = Table.FromRecords({Source_UserRightsDest4}),
                        #"UserRightsDest4 Removed Columns" = Table.RemoveColumns(#"UserRightsDest4 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest4 Expanded value" = Table.ExpandListColumn(#"UserRightsDest4 Removed Columns", "value"),
                        Output_Source_UserRightsDest4 = Table.ExpandRecordColumn(#"UserRightsDest4 Expanded value", "value",{"COD_UTENTE", "COD_DEST4"})
                    in 
                        Output_Source_UserRightsDest4
            ]
        ),

    #"0 UserRightsDest4 Merged Queries" = Table.NestedJoin(Output_Source_UserRightsDest4_0, {"COD_DEST4"}, CustomDimension4, {"TGK_DEST4_KEY"}, "Dest4", JoinKind.LeftOuter),
    #"0 UserRightsDest4 Expanded" = Table.ExpandTableColumn(#"0 UserRightsDest4 Merged Queries", "Dest4", {"TGK_DEST4_ID"}, {"TGK_DEST4_UR_ID"}),
    UserRightsDest4_0  = Table.RenameColumns(#"0 UserRightsDest4 Expanded" ,{{"COD_DEST4", "TGK_DEST4_UR_KEY"}, {"COD_UTENTE", "TGK_DEST4_UR_USERID"}})
    ,
    UserRightsDest4 = List.First(List.Select(VersionCases, each _{0} = Version), null){17}
    ,
    //User Rights Custom Dimension 5
   //Version 1.1.0 
    Output_Source_UserRightsDest5_1 =
    Table.View(null,
            [
                GetType = () =>
                    type table [
                        U = Text.Type,
                        D = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest5 = Json.Document(Web.Contents(outputURL &"Datasource_000036()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest5 Converted to Table" = Table.FromRecords({Source_UserRightsDest5}),
                        #"UserRightsDest5 Removed Columns" = Table.RemoveColumns(#"UserRightsDest5 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest5 Expanded value" = Table.ExpandListColumn(#"UserRightsDest5 Removed Columns", "value"),
                        Output_Source_UserRightsDest5 = Table.ExpandRecordColumn(#"UserRightsDest5 Expanded value", "value",{"U", "D"})
                    in 
                        Output_Source_UserRightsDest5
            ]
        ),

    #"1 UserRightsDest5 Merged Queries" = Table.NestedJoin(Output_Source_UserRightsDest5_1, {"D"}, CustomDimension5, {"TGK_DEST5_KEY"}, "Dest5", JoinKind.LeftOuter),
    #"1 UserRightsDest5 Expanded" = Table.ExpandTableColumn(#"1 UserRightsDest5 Merged Queries", "Dest5", {"TGK_DEST5_ID"}, {"TGK_DEST5_UR_ID"}),
    UserRightsDest5_1  = Table.RenameColumns(#"1 UserRightsDest5 Expanded" ,{{"D", "TGK_DEST5_UR_KEY"}, {"U", "TGK_DEST5_UR_USERID"}})
    ,
    //Version 1.0.0 
    Output_Source_UserRightsDest5_0 =
    Table.View(null,
            [
                GetType = () =>
                    type table [
                        COD_UTENTE = Text.Type,
                        COD_DEST5 = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest5 = Json.Document(Web.Contents(outputURL &"Datasource_000036()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest5 Converted to Table" = Table.FromRecords({Source_UserRightsDest5}),
                        #"UserRightsDest5 Removed Columns" = Table.RemoveColumns(#"UserRightsDest5 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest5 Expanded value" = Table.ExpandListColumn(#"UserRightsDest5 Removed Columns", "value"),
                        Output_Source_UserRightsDest5 = Table.ExpandRecordColumn(#"UserRightsDest5 Expanded value", "value",{"COD_UTENTE", "COD_DEST5"})
                    in 
                        Output_Source_UserRightsDest5
            ]
        ),

    #"0 UserRightsDest5 Merged Queries" = Table.NestedJoin(Output_Source_UserRightsDest5_0, {"COD_DEST5"}, CustomDimension5, {"TGK_DEST5_KEY"}, "Dest5", JoinKind.LeftOuter),
    #"0 UserRightsDest5 Expanded" = Table.ExpandTableColumn(#"0 UserRightsDest5 Merged Queries", "Dest5", {"TGK_DEST5_ID"}, {"TGK_DEST5_UR_ID"}),
    UserRightsDest5_0  = Table.RenameColumns(#"0 UserRightsDest5 Expanded" ,{{"COD_DEST5", "TGK_DEST5_UR_KEY"}, {"COD_UTENTE", "TGK_DEST5_UR_USERID"}})
    ,
    UserRightsDest5 = List.First(List.Select(VersionCases, each _{0} = Version), null){18}
    ,
    //User Rights Entity
    //Version 1.1.0 
    Output_Source_UserRightsEntity_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        U = Text.Type,
                        D = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsEntity = Json.Document(Web.Contents(outputURL &"Datasource_000029()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsEntity Converted to Table" = Table.FromRecords({Source_UserRightsEntity}),
                        #"UserRightsEntity Removed Columns" = Table.RemoveColumns(#"UserRightsEntity Converted to Table",{"@odata.context"}),
                        #"UserRightsEntity Expanded value" = Table.ExpandListColumn(#"UserRightsEntity Removed Columns", "value"),
                        Output_Source_UserRightsEntity = Table.ExpandRecordColumn(#"UserRightsEntity Expanded value", "value",{"U", "D"})
                    in 
                        Output_Source_UserRightsEntity
            ]
        ),
    
    #"1 UserRightsEntity Merged Queries" = Table.NestedJoin(Output_Source_UserRightsEntity_1, {"D"}, Entity, {"TGK_ENTITY_KEY"}, "Entity", JoinKind.LeftOuter),
    #"1 UserRightsEntity Expanded" = Table.ExpandTableColumn(#"1 UserRightsEntity Merged Queries", "Entity", {"TGK_ENTITY_ID"}, {"TGK_ENTITY_UR_ID"}),
    UserRightsEntity_1  = Table.RenameColumns(#"1 UserRightsEntity Expanded" ,{{"D", "TGK_ENTITY_UR_KEY"}, {"U", "TGK_ENTITY_UR_USERID"}})
    ,
    //Version 1.0.0 
    Output_Source_UserRightsEntity_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_UTENTE = Text.Type,
                        COD_AZIENDA = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsEntity = Json.Document(Web.Contents(outputURL &"Datasource_000029()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsEntity Converted to Table" = Table.FromRecords({Source_UserRightsEntity}),
                        #"UserRightsEntity Removed Columns" = Table.RemoveColumns(#"UserRightsEntity Converted to Table",{"@odata.context"}),
                        #"UserRightsEntity Expanded value" = Table.ExpandListColumn(#"UserRightsEntity Removed Columns", "value"),
                        Output_Source_UserRightsEntity = Table.ExpandRecordColumn(#"UserRightsEntity Expanded value", "value",{"COD_UTENTE", "COD_AZIENDA"})
                    in 
                        Output_Source_UserRightsEntity
            ]
        ),
    
    #"0 UserRightsEntity Merged Queries" = Table.NestedJoin(Output_Source_UserRightsEntity_0, {"COD_AZIENDA"}, Entity, {"TGK_ENTITY_KEY"}, "Entity", JoinKind.LeftOuter),
    #"0 UserRightsEntity Expanded" = Table.ExpandTableColumn(#"0 UserRightsEntity Merged Queries", "Entity", {"TGK_ENTITY_ID"}, {"TGK_ENTITY_UR_ID"}),
    UserRightsEntity_0  = Table.RenameColumns(#"0 UserRightsEntity Expanded" ,{{"COD_AZIENDA", "TGK_ENTITY_UR_KEY"}, {"COD_UTENTE", "TGK_ENTITY_UR_USERID"}})
    ,
    UserRightsEntity = List.First(List.Select(VersionCases, each _{0} = Version), null){19}
    ,
    //User Rights Scenario
    // Version 1.1.0 
    Output_Source_UserRightsScenario_1 =
    Table.View(null,
        [
            GetType = () =>
                type table [
                    U = Text.Type,
                    D = Text.Type
                ],
            GetRows = () =>
                let 
                    Source_UserRightsScenario = Json.Document(Web.Contents(outputURL & "Datasource_000030()?$filter=FM eq '" & Model & "'&$select=U,D", [Timeout=#duration(0,0,30,0)])),
                    #"UserRightsScenario Converted to Table" = Table.FromRecords({Source_UserRightsScenario}),
                    #"UserRightsScenario Removed Columns" = Table.RemoveColumns(#"UserRightsScenario Converted to Table",{"@odata.context"}),
                    #"UserRightsScenario Expanded value" = Table.ExpandListColumn(#"UserRightsScenario Removed Columns", "value"),
                    Output_Source_UserRightsScenario = Table.ExpandRecordColumn(#"UserRightsScenario Expanded value", "value",{"U", "D"})
                in 
                    Output_Source_UserRightsScenario
        ]
    ),
    
    #"1 UserRightsScenario Merged Queries" = Table.NestedJoin(Output_Source_UserRightsScenario_1, {"D"}, Scenario, {"TGK_SCENARIO_KEY"}, "Scenario", JoinKind.LeftOuter),
    #"1 UserRightsScenario Expanded" = Table.ExpandTableColumn(#"1 UserRightsScenario Merged Queries", "Scenario", {"TGK_SCENARIO_ID"}, {"TGK_SCENARIO_UR_ID"}),
    UserRightsScenario_1  = Table.RenameColumns(#"1 UserRightsScenario Expanded", {{"D", "TGK_SCENARIO_UR_KEY"}, {"U", "TGK_SCENARIO_UR_USERID"}}),
    
    // Version 1.0.0 
    Output_Source_UserRightsScenario_0 =
    Table.View(null,
        [
            GetType = () =>
                type table [
                    COD_UTENTE = Text.Type,
                    COD_SCENARIO = Text.Type
                ],
            GetRows = () =>
                let 
                    Source_UserRightsScenario = Json.Document(Web.Contents(outputURL & "Datasource_000030()", [Timeout=#duration(0,0,30,0)])),
                    #"UserRightsScenario Converted to Table" = Table.FromRecords({Source_UserRightsScenario}),
                    #"UserRightsScenario Removed Columns" = Table.RemoveColumns(#"UserRightsScenario Converted to Table",{"@odata.context"}),
                    #"UserRightsScenario Expanded value" = Table.ExpandListColumn(#"UserRightsScenario Removed Columns", "value"),
                    Output_Source_UserRightsScenario = Table.ExpandRecordColumn(#"UserRightsScenario Expanded value", "value",{"COD_UTENTE", "COD_SCENARIO"})
                in 
                    Output_Source_UserRightsScenario
        ]
    ),
    
    #"0 UserRightsScenario Merged Queries" = Table.NestedJoin(Output_Source_UserRightsScenario_0, {"COD_SCENARIO"}, Scenario, {"TGK_SCENARIO_KEY"}, "Scenario", JoinKind.LeftOuter),
    #"0 UserRightsScenario Expanded" = Table.ExpandTableColumn(#"0 UserRightsScenario Merged Queries", "Scenario", {"TGK_SCENARIO_ID"}, {"TGK_SCENARIO_UR_ID"}),
    UserRightsScenario_0  = Table.RenameColumns(#"0 UserRightsScenario Expanded", {{"COD_SCENARIO", "TGK_SCENARIO_UR_KEY"}, {"COD_UTENTE", "TGK_SCENARIO_UR_USERID"}}),
    
    UserRightsScenario = List.First(List.Select(VersionCases, each _{0} = Version), null){20}
    ,
    FW_ListDimFinancial = Table.FromRecords({
        [DimensionName = "Account", DimensionTable = Account],
        [DimensionName = "Account Hierarchy", DimensionTable = Account_H],
        [DimensionName = "Category", DimensionTable = Category],
        [DimensionName = "Category Grouping", DimensionTable = Category_G],
        [DimensionName = "Calendar", DimensionTable = Calendar],
        [DimensionName = "Change Sign", DimensionTable = ChangeSign],
        [DimensionName = "Custom Dimension 1", DimensionTable = CustomDimension1],
        [DimensionName = "Custom Dimension 2 CTP", DimensionTable = CustomDimension_2_CTP],
        [DimensionName = "Custom Dimension 2 CTP Hierarchy", DimensionTable = CustomDimension2_CTP_H],
        [DimensionName = "Custom Dimension 2 Segment", DimensionTable = CustomDimension2_Segment],
        [DimensionName = "Custom Dimension 2 Segment Hierarchy", DimensionTable = CustomDimension2_Segment_H],
        [DimensionName = "Custom Dimension 2", DimensionTable = CustomDimension2],
        [DimensionName = "Custom Dimension 3", DimensionTable = CustomDimension3],
        [DimensionName = "Custom Dimension 4", DimensionTable = CustomDimension4],
        [DimensionName = "Custom Dimension 5", DimensionTable = CustomDimension5],
        [DimensionName = "Custom Dimension 1 Hierarchy", DimensionTable = CustomDimension1_H],
        [DimensionName = "Custom Dimension 2 Hierarchy", DimensionTable = CustomDimension2_H],
        [DimensionName = "Custom Dimension 3 Hierarchy", DimensionTable = CustomDimension3_H],
        [DimensionName = "Custom Dimension 4 Hierarchy", DimensionTable = CustomDimension4_H],
        [DimensionName = "Custom Dimension 5 Hierarchy", DimensionTable = CustomDimension5_H],
        [DimensionName = "Entity", DimensionTable = Entity],
        [DimensionName = "Entity Hierarchy", DimensionTable = Entity_H],
        [DimensionName = "Entity CTP", DimensionTable = Entity_CTP],
        [DimensionName = "Entity CTP Hierarchy", DimensionTable = Entity_CTP_H],
        [DimensionName = "Entity Segment", DimensionTable = Entity_Segment],
        [DimensionName = "Entity Segment Hierarchy", DimensionTable = Entity_Segment_H],
        [DimensionName = "Exchange Rate", DimensionTable = ExchangeRate],
        [DimensionName = "FST", DimensionTable = FST],
        [DimensionName = "Notes", DimensionTable = Notes],
        [DimensionName = "Period", DimensionTable = Period],
        [DimensionName = "Period Length", DimensionTable = PeriodLength],
        [DimensionName = "Periodic Value Calculation", DimensionTable = PeriodicValueCalculation],
        [DimensionName = "Scenario", DimensionTable = Scenario],
        [DimensionName = "Scenario Grouping", DimensionTable =Scenario_G],
        [DimensionName = "Scenario Period", DimensionTable = ScenarioPeriod],
        [DimensionName = "Target Currency", DimensionTable = TargetCurrency],
        [DimensionName = "Transaction Currency", DimensionTable = TransactionCurrency],
        [DimensionName = "User Rights Account", DimensionTable = UserRightsAccount],
        [DimensionName = "User Rights Category", DimensionTable = UserRightsCategory],
        [DimensionName = "User Rights Custom Dimension 1", DimensionTable = UserRightsDest1],
        [DimensionName = "User Rights Custom Dimension 2", DimensionTable = UserRightsDest2],
        [DimensionName = "User Rights Custom Dimension 3", DimensionTable = UserRightsDest3],
        [DimensionName = "User Rights Custom Dimension 4", DimensionTable = UserRightsDest4],
        [DimensionName = "User Rights Custom Dimension 5", DimensionTable = UserRightsDest5],
        [DimensionName = "User Rights Entity", DimensionTable = UserRightsEntity],
        [DimensionName = "User Rights Scenario", DimensionTable = UserRightsScenario]
    }), 
    OutputFinancialDimensions =  FW_ListDimFinancial
in
    OutputFinancialDimensions;

CreateFinancialDimensionsAIH = (outputURL as text,optional dimensionList as list,optional filterDatasetList as text) as table => 
let
    //AIH Connector Financial Dimensions
    //AIH Account
    AW_Output_Source_Account =Table.View(null,
        [
            GetType = () =>
                   type table [
                    COD_CONTO = Text.Type,
                    DESC_CONTO0 = Text.Type, 
                    DESC_CONTO1 = Text.Type, 
                    DESC_CONTO2 = Text.Type, 
                    DESC_CONTO3 = Text.Type, 
                    DESC2_CONTO0 = Text.Type, 
                    DESC2_CONTO1 = Text.Type, 
                    DESC2_CONTO2 = Text.Type, 
                    DESC2_CONTO3 = Text.Type, 
                    NATURA_CONTO = Text.Type, 
                    TIPO_CONTO = Text.Type, 
                    TIPO_CONVERSIONE = Text.Type, 
                    SEGNO_STANDARD = Text.Type,
                    ATTRIBUTO1 = Text.Type, 
                    ATTRIBUTO2 = Text.Type, 
                    ATTRIBUTO3 = Text.Type, 
                    ATTRIBUTO4 = Text.Type, 
                    ATTRIBUTO5 = Text.Type, 
                    FORMATO_SEGNO = Int64.Type,
                    TIPO_AGGREGAZIONE_CONTO = Text.Type,
                    FLAG_CONVERSIONE = Int64.Type
                ],
            GetRows = () =>
                let 
                    Source_Account = Json.Document(Web.Contents(outputURL & "Datasource_000003()" ,[Timeout=#duration(0,0,30,0)])),
                    #"Account Converted to Table" = Table.FromRecords({Source_Account}),
                    #"Account Removed Columns" = Table.RemoveColumns(#"Account Converted to Table",{"@odata.context"}),
                    #"Account Expanded value" = Table.ExpandListColumn(#"Account Removed Columns", "value"),
                    Output_Source_Account = Table.ExpandRecordColumn(#"Account Expanded value", "value",{"COD_CONTO", "DESC_CONTO0", "DESC_CONTO1", "DESC_CONTO2", "DESC_CONTO3", "DESC2_CONTO0", "DESC2_CONTO1", "DESC2_CONTO2", "DESC2_CONTO3", "NATURA_CONTO", "TIPO_CONTO", "TIPO_CONVERSIONE", "SEGNO_STANDARD", "ATTRIBUTO1", "ATTRIBUTO2", "ATTRIBUTO3", "ATTRIBUTO4", "ATTRIBUTO5", "FORMATO_SEGNO","TIPO_AGGREGAZIONE_CONTO","FLAG_CONVERSIONE"})
                in 
                    Output_Source_Account
        ]
    ),

    #"AW_Account Duplicated Column" = Table.DuplicateColumn(AW_Output_Source_Account, "COD_CONTO", "TGK_ACCOUNT_KEY"),
    #"AW_Account Duplicated Column1" = Table.DuplicateColumn(#"AW_Account Duplicated Column", "COD_CONTO", "TGK_ACCOUNT_H_KEY"),
    AW_Account = Table.RenameColumns(#"AW_Account Duplicated Column1",{{"COD_CONTO", "Account Code"}, {"DESC_CONTO0", "Account Description"}, {"DESC_CONTO1", "Account Description 1"}, {"DESC_CONTO2", "Account Description 2"}, {"DESC_CONTO3", "Account Description 3"}, {"DESC2_CONTO0", "Account Alternative Description"}, {"DESC2_CONTO1", "Account Alternative Description 1"}, {"DESC2_CONTO2", "Account Alternative Description 2"}, {"DESC2_CONTO3", "Account Alternative Description 3"}, {"NATURA_CONTO", "Account Nature"}, {"TIPO_CONTO", "Account Type"}, {"TIPO_CONVERSIONE", "Account Conversion Type"}, {"SEGNO_STANDARD", "Account Standard Sign"}, {"ATTRIBUTO1", "Account Attribute 1"}, {"ATTRIBUTO2", "Account Attribute 2"}, {"ATTRIBUTO3", "Account Attribute 3"}, {"ATTRIBUTO4", "Account Attribute 4"}, {"ATTRIBUTO5", "Account Attribute 5"}, {"FORMATO_SEGNO", "Account Format Sign"}, {"TIPO_AGGREGAZIONE_CONTO", "Account Aggregation Type"}, {"FLAG_CONVERSIONE", "Account Conversion Flag"}})   
	,
   //AIH Account Hierarchy
	AW_Output_Source_Account_H = Table.View(null,
        [
            GetType = () =>
            type table [
                COD_CONTO_GERARCHIA = Text.Type,
                DESC_CONTO_GERARCHIA = Text.Type,
                COD_CONTO_ELEGER1 = Text.Type,
                DESC_CONTO_ELEGER1 = Text.Type,
                COD_CONTO_ELEGER2 = Text.Type,
                DESC_CONTO_ELEGER2 = Text.Type,
                COD_CONTO_ELEGER3 = Text.Type,
                DESC_CONTO_ELEGER3 = Text.Type,
                COD_CONTO_ELEGER4 = Text.Type,
                DESC_CONTO_ELEGER4 = Text.Type,
                COD_CONTO_ELEGER5 = Text.Type,
                DESC_CONTO_ELEGER5 = Text.Type,
                COD_CONTO_ELEGER6 = Text.Type,
                DESC_CONTO_ELEGER6 = Text.Type,
                COD_CONTO_ELEGER7 = Text.Type,
                DESC_CONTO_ELEGER7 = Text.Type,
                COD_CONTO_ELEGER8 = Text.Type,
                DESC_CONTO_ELEGER8 = Text.Type,
                COD_CONTO_KEY = Text.Type
            ],
            GetRows = () =>
                let 
                    Source_Account_H = Json.Document(Web.Contents(outputURL & "Datasource_000005()" ,[Timeout=#duration(0,0,30,0)])),
                    #"Account_H Converted to Table" = Table.FromRecords({Source_Account_H}),
                    #"Account_H Removed Columns" = Table.RemoveColumns(#"Account_H Converted to Table",{"@odata.context"}),
                    #"Account_H Expanded value" = Table.ExpandListColumn(#"Account_H Removed Columns", "value"),
                    Output_Source_Account_H = Table.ExpandRecordColumn(#"Account_H Expanded value", "value",{ "COD_CONTO_GERARCHIA","DESC_CONTO_GERARCHIA", "COD_CONTO_ELEGER1", "DESC_CONTO_ELEGER1", "COD_CONTO_ELEGER2", "DESC_CONTO_ELEGER2", "COD_CONTO_ELEGER3", "DESC_CONTO_ELEGER3", "COD_CONTO_ELEGER4", "DESC_CONTO_ELEGER4", "COD_CONTO_ELEGER5", "DESC_CONTO_ELEGER5", "COD_CONTO_ELEGER6", "DESC_CONTO_ELEGER6", "COD_CONTO_ELEGER7", "DESC_CONTO_ELEGER7", "COD_CONTO_ELEGER8", "DESC_CONTO_ELEGER8","COD_CONTO_KEY"})
                in 
                    Output_Source_Account_H
        ]
    ),
      
    AW_Account_H = Table.RenameColumns(AW_Output_Source_Account_H,{{"COD_CONTO_GERARCHIA", "Account Hierarchy Code"}, {"DESC_CONTO_GERARCHIA", "Account Hierarchy Description"}, {"COD_CONTO_ELEGER1", "Account Hierarchy Code Level 1"}, {"COD_CONTO_ELEGER2", "Account Hierarchy Code Level 2"}, {"COD_CONTO_ELEGER3", "Account Hierarchy Code Level 3"}, {"COD_CONTO_ELEGER4", "Account Hierarchy Code Level 4"}, {"COD_CONTO_ELEGER5", "Account Hierarchy Code Level 5"}, {"COD_CONTO_ELEGER6", "Account Hierarchy Code Level 6"}, {"COD_CONTO_ELEGER7", "Account Hierarchy Code Level 7"}, {"COD_CONTO_ELEGER8", "Account Hierarchy Code Level 8"}, {"DESC_CONTO_ELEGER1", "Account Hierarchy Description Level 1"}, {"DESC_CONTO_ELEGER2", "Account Hierarchy Description Level 2"}, {"DESC_CONTO_ELEGER3", "Account Hierarchy Description Level 3"}, {"DESC_CONTO_ELEGER4", "Account Hierarchy Description Level 4"}, {"DESC_CONTO_ELEGER5", "Account Hierarchy Description Level 5"}, {"DESC_CONTO_ELEGER6", "Account Hierarchy Description Level 6"}, {"DESC_CONTO_ELEGER7", "Account Hierarchy Description Level 7"}, {"DESC_CONTO_ELEGER8", "Account Hierarchy Description Level 8"}, {"COD_CONTO_KEY", "TGK_ACCOUNT_H_KEY"}})
	,
    //AIH Category
    AW_Source_Category = Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_CATEGORIA = Text.Type,
                        DESC_CATEGORIA0 = Text.Type,
                        DESC_CATEGORIA1 = Text.Type,
                        DESC_CATEGORIA2 = Text.Type,
                        DESC_CATEGORIA3 = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Category = Json.Document(Web.Contents(outputURL &"Datasource_AW9993()" ,[Timeout=#duration(0,0,30,0)])),
                        #"Category Converted to Table" = Table.FromRecords({Source_Category}),
                        #"Category Removed Columns" = Table.RemoveColumns(#"Category Converted to Table",{"@odata.context"}),
                        #"Category Expanded value" = Table.ExpandListColumn(#"Category Removed Columns", "value"),
                        Output_Source_Category = Table.ExpandRecordColumn(#"Category Expanded value", "value",{"COD_CATEGORIA","DESC_CATEGORIA0","DESC_CATEGORIA1","DESC_CATEGORIA2","DESC_CATEGORIA3"})                       
                    in 
                        Output_Source_Category
            ]
        ),
    #"AW_Category Duplicated Column" = Table.DuplicateColumn(AW_Source_Category, "COD_CATEGORIA", "TGK_CATEGORY_KEY"),
    #"AW_Category Duplicated Column1" = Table.DuplicateColumn(#"AW_Category Duplicated Column", "COD_CATEGORIA", "TGK_CATEGORY_H_KEY"),
    AW_Category = Table.RenameColumns(#"AW_Category Duplicated Column1",{{"COD_CATEGORIA", "Category Code"}, {"DESC_CATEGORIA0", "Category Description"}, {"DESC_CATEGORIA1", "Category Description 1"}, {"DESC_CATEGORIA2", "Category Description 2"}, {"DESC_CATEGORIA3", "Category Description 3"}})
	,
    //AIH Category Grouping
    AW_Output_Source_Category_G = Table.View(null,
            [
                GetType = () =>
                       type table [
						COD_CATEGORIA_GERARCHIA = Text.Type,                       
                        DESC_CATEGORIA_GERARCHIA = Text.Type,                       
                        COD_CATEGORIA_ELEGER1 = Text.Type,
                        DESC_CATEGORIA_ELEGER1 = Text.Type,
                        COD_CATEGORIA_ELEGER2 = Text.Type,
                        DESC_CATEGORIA_ELEGER2 = Text.Type,
                        COD_CATEGORIA_ELEGER3 = Text.Type,
                        DESC_CATEGORIA_ELEGER3 = Text.Type,
                        COD_CATEGORIA_ELEGER4 = Text.Type,
                        DESC_CATEGORIA_ELEGER4 = Text.Type,
                        COD_CATEGORIA_ELEGER5 = Text.Type,
                        DESC_CATEGORIA_ELEGER5 = Text.Type,
                        COD_CATEGORIA_ELEGER6 = Text.Type,
                        DESC_CATEGORIA_ELEGER6 = Text.Type,
                        COD_CATEGORIA_ELEGER7 = Text.Type,
                        DESC_CATEGORIA_ELEGER7 = Text.Type,
                        COD_CATEGORIA_ELEGER8 = Text.Type,
                        DESC_CATEGORIA_ELEGER8 = Text.Type,
                        COD_CATEGORIA_KEY = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Category_G = Json.Document(Web.Contents(outputURL &"Datasource_AW9992()" ,[Timeout=#duration(0,0,30,0)])),
                        #"Category_G Converted to Table" = Table.FromRecords({Source_Category_G}),
                        #"Category_G Removed Columns" = Table.RemoveColumns(#"Category_G Converted to Table",{"@odata.context"}),
                        #"Category_G Expanded value" = Table.ExpandListColumn(#"Category_G Removed Columns", "value"),
                        Output_Source_Category_G = Table.ExpandRecordColumn(#"Category_G Expanded value", "value",{"COD_CATEGORIA_GERARCHIA", "DESC_CATEGORIA_GERARCHIA","COD_CATEGORIA_ELEGER1","DESC_CATEGORIA_ELEGER1","COD_CATEGORIA_ELEGER2","DESC_CATEGORIA_ELEGER2","COD_CATEGORIA_ELEGER3","DESC_CATEGORIA_ELEGER3","COD_CATEGORIA_ELEGER4","DESC_CATEGORIA_ELEGER4","COD_CATEGORIA_ELEGER5","DESC_CATEGORIA_ELEGER5","COD_CATEGORIA_ELEGER6","DESC_CATEGORIA_ELEGER6","COD_CATEGORIA_ELEGER7","DESC_CATEGORIA_ELEGER7","COD_CATEGORIA_ELEGER8","DESC_CATEGORIA_ELEGER8","COD_CATEGORIA_KEY"})                       
                    in 
                        Output_Source_Category_G
            ]
        ),
    AW_Category_G  = Table.RenameColumns(AW_Output_Source_Category_G,{{"COD_CATEGORIA_GERARCHIA", "Category Grouping Code"}, {"DESC_CATEGORIA_GERARCHIA", "Category Grouping Description"}, {"COD_CATEGORIA_ELEGER1", "Category Grouping Code Level 1"}, {"COD_CATEGORIA_ELEGER2", "Category Grouping Code Level 2"}, {"COD_CATEGORIA_ELEGER3", "Category Grouping Code Level 3"}, {"COD_CATEGORIA_ELEGER4", "Category Grouping Code Level 4"}, {"COD_CATEGORIA_ELEGER5", "Category Grouping Code Level 5"}, {"COD_CATEGORIA_ELEGER6", "Category Grouping Code Level 6"}, {"COD_CATEGORIA_ELEGER7", "Category Grouping Code Level 7"}, {"COD_CATEGORIA_ELEGER8", "Category Grouping Code Level 8"}, {"DESC_CATEGORIA_ELEGER1", "Category Grouping Description Level 1"}, {"DESC_CATEGORIA_ELEGER2", "Category Grouping Description Level 2"}, {"DESC_CATEGORIA_ELEGER3", "Category Grouping Description Level 3"}, {"DESC_CATEGORIA_ELEGER4", "Category Grouping Description Level 4"}, {"DESC_CATEGORIA_ELEGER5", "Category Grouping Description Level 5"}, {"DESC_CATEGORIA_ELEGER6", "Category Grouping Description Level 6"}, {"DESC_CATEGORIA_ELEGER7", "Category Grouping Description Level 7"}, {"DESC_CATEGORIA_ELEGER8", "Category Grouping Description Level 8"}, {"COD_CATEGORIA_KEY", "TGK_CATEGORY_H_KEY"}})
	,
    //AIH Custom Dimension 1
    AW_Output_Source_CustomDimension1 =
    Table.View(null,
        [
            GetType = () =>
                   type table [
                    COD_DEST1 = text,
                    DESC_DEST10 = text,
                    DESC_DEST11 = text,
                    DESC_DEST12 = text,
                    DESC_DEST13 = text,
                    ATTRIBUTO1 = text,
                    ATTRIBUTO2 = text,
                    ATTRIBUTO3 = text,
                    ATTRIBUTO4 = text,
                    ATTRIBUTO5 = text
                ]
                ,
            GetRows = () =>
                let 
                    Source_CustomDimension1 = Json.Document(Web.Contents(outputURL &"Datasource_000009()" ,[Timeout=#duration(0,0,30,0)])),
                    #"CustomDimension1 Converted to Table" = Table.FromRecords({Source_CustomDimension1}),
                    #"CustomDimension1 Removed Columns" = Table.RemoveColumns(#"CustomDimension1 Converted to Table",{"@odata.context"}),
                    #"CustomDimension1 Expanded value" = Table.ExpandListColumn(#"CustomDimension1 Removed Columns", "value"),
                    Output_Source_CustomDimension1 = Table.ExpandRecordColumn(#"CustomDimension1 Expanded value", "value",{"COD_DEST1","DESC_DEST10","DESC_DEST11","DESC_DEST12","DESC_DEST13","ATTRIBUTO1","ATTRIBUTO2","ATTRIBUTO3","ATTRIBUTO4","ATTRIBUTO5"})
                in 
                    Output_Source_CustomDimension1
        ]
    ),
    #"AW_CustomDimension1 Duplicated Column" = Table.DuplicateColumn(AW_Output_Source_CustomDimension1, "COD_DEST1", "TGK_DEST1_KEY"),
    #"AW_CustomDimension1 Duplicated Column1" = Table.DuplicateColumn(#"AW_CustomDimension1 Duplicated Column", "COD_DEST1", "TGK_DEST1_H_KEY"),
    AW_CustomDimension1 = Table.RenameColumns(#"AW_CustomDimension1 Duplicated Column1",{{"COD_DEST1", "Custom Dimension 1 Code"}, {"DESC_DEST10", "Custom Dimension 1 Description"}, {"DESC_DEST11", "Custom Dimension 1 Description 1"}, {"DESC_DEST12", "Custom Dimension 1 Description 2"}, {"DESC_DEST13", "Custom Dimension 1 Description 3"}, {"ATTRIBUTO1", "Custom Dimension 1 Attribute 1"}, {"ATTRIBUTO2", "Custom Dimension 1 Attribute 2"}, {"ATTRIBUTO3", "Custom Dimension 1 Attribute 3"}, {"ATTRIBUTO4", "Custom Dimension 1 Attribute 4"}, {"ATTRIBUTO5", "Custom Dimension 1 Attribute 5"}})
	,
    //AIH Custom Dimension 2
	AW_Output_Source_CustomDimension2 =
    Table.View(null,
            [
                GetType = () =>
                    type table [
                        COD_DEST2 = text,
                        DESC_DEST20 = text,
                        DESC_DEST21 = text,
                        DESC_DEST22 = text,
                        DESC_DEST23 = text,
                        ATTRIBUTO1 = text,
                        ATTRIBUTO2 = text,
                        ATTRIBUTO3 = text,
                        ATTRIBUTO4 = text,
                        ATTRIBUTO5 = text
                    ],
                GetRows = () =>
                    let 
                        Source_CustomDimension2 = Json.Document(Web.Contents(outputURL & "Datasource_000010()", [Timeout=#duration(0,0,30,0)])),
                        #"CustomDimension2 Converted to Table" = Table.FromRecords({Source_CustomDimension2}),
                        #"CustomDimension2 Removed Columns" = Table.RemoveColumns(#"CustomDimension2 Converted to Table", {"@odata.context"}),
                        #"CustomDimension2 Expanded value" = Table.ExpandListColumn(#"CustomDimension2 Removed Columns", "value"),
                        Output_Source_CustomDimension2 = Table.ExpandRecordColumn(#"CustomDimension2 Expanded value", "value", {"COD_DEST2", "DESC_DEST20", "DESC_DEST21", "DESC_DEST22", "DESC_DEST23", "ATTRIBUTO1", "ATTRIBUTO2", "ATTRIBUTO3", "ATTRIBUTO4", "ATTRIBUTO5"})
                    in 
                        Output_Source_CustomDimension2
            ]
        ),
    #"AW_CustomDimension2 Duplicated Column" = Table.DuplicateColumn(AW_Output_Source_CustomDimension2, "COD_DEST2", "TGK_DEST2_KEY"),
    #"AW_CustomDimension2 Duplicated Column1" = Table.DuplicateColumn(#"AW_CustomDimension2 Duplicated Column", "COD_DEST2", "TGK_DEST2_H_KEY"),
    AW_CustomDimension2 = Table.RenameColumns(#"AW_CustomDimension2 Duplicated Column1",{{"COD_DEST2", "Custom Dimension 2 Code"}, {"DESC_DEST20", "Custom Dimension 2 Description"}, {"DESC_DEST21", "Custom Dimension 2 Description 1"}, {"DESC_DEST22", "Custom Dimension 2 Description 2"}, {"DESC_DEST23", "Custom Dimension 2 Description 3"}, {"ATTRIBUTO1", "Custom Dimension 2 Attribute 1"}, {"ATTRIBUTO2", "Custom Dimension 2 Attribute 2"}, {"ATTRIBUTO3", "Custom Dimension 2 Attribute 3"}, {"ATTRIBUTO4", "Custom Dimension 2 Attribute 4"}, {"ATTRIBUTO5", "Custom Dimension 2 Attribute 5"}})
	,
	//AIH Custom Dimension 2 CTP
    AW_Source_CustomDimension2_CTP = Table.SelectColumns(AW_CustomDimension2,{ "Custom Dimension 2 Code","Custom Dimension 2 Description", "Custom Dimension 2 Description 1", "Custom Dimension 2 Description 2", "Custom Dimension 2 Description 3", "Custom Dimension 2 Attribute 1","Custom Dimension 2 Attribute 2", "Custom Dimension 2 Attribute 3", "Custom Dimension 2 Attribute 4", "Custom Dimension 2 Attribute 5","TGK_DEST2_KEY"}),
    #"AW_Custom Dimension 2 CTP Insert Row" = Table.InsertRows(AW_Source_CustomDimension2_CTP,0,{[Custom Dimension 2 Code="$NET",Custom Dimension 2 Description="3rd party",Custom Dimension 2 Description 1=null,Custom Dimension 2 Description 2=null,Custom Dimension 2 Description 3=null,Custom Dimension 2 Attribute 1=null,Custom Dimension 2 Attribute 2=null,Custom Dimension 2 Attribute 3=null,Custom Dimension 2 Attribute 4=null,Custom Dimension 2 Attribute 5=null,TGK_DEST2_KEY="$NET"]}),
    #"AW_Custom Dimension 2 CTPDuplicated Column" = Table.DuplicateColumn(#"AW_Custom Dimension 2 CTP Insert Row", "TGK_DEST2_KEY", "TGK_DEST2_CTP_H_KEY"),
    AW_CustomDimension2_CTP = Table.RenameColumns( #"AW_Custom Dimension 2 CTPDuplicated Column",{{"Custom Dimension 2 Code", "Custom Dimension 2 CTP Code"},{"Custom Dimension 2 Description","Custom Dimension 2 CTP Description"},{ "Custom Dimension 2 Description 1", "Custom Dimension 2 CTP Description 1"},{ "Custom Dimension 2 Description 2", "Custom Dimension 2 CTP Description 2"},{ "Custom Dimension 2 Description 3", "Custom Dimension 2 CTP Description 3"},{ "Custom Dimension 2 Attribute 1", "Custom Dimension 2 CTP Attribute 1"},{"Custom Dimension 2 Attribute 2","Custom Dimension 2 CTP Attribute 2"},{ "Custom Dimension 2 Attribute 3", "Custom Dimension 2 CTP Attribute 3"},{ "Custom Dimension 2 Attribute 4", "Custom Dimension 2 CTP Attribute 4"},{ "Custom Dimension 2 Attribute 5", "Custom Dimension 2 CTP Attribute 5"},{ "TGK_DEST2_KEY", "TGK_DEST2_CTP_KEY"}})
    ,
    //AIH Custom Dimension 3
    AW_Output_Source_CustomDimension3 = 
    Table.View(null,
            [
                GetType = () =>
                    type table [
                        COD_DEST3 = text,
                        DESC_DEST30 = text,
                        DESC_DEST31 = text,
                        DESC_DEST32 = text,
                        DESC_DEST33 = text,
                        ATTRIBUTO1 = text,
                        ATTRIBUTO2 = text,
                        ATTRIBUTO3 = text,
                        ATTRIBUTO4 = text,
                        ATTRIBUTO5 = text
                    ],
                GetRows = () =>
                    let 
                        Source_CustomDimension3 = Json.Document(Web.Contents(outputURL & "Datasource_000011()", [Timeout=#duration(0,0,30,0)])),
                        #"CustomDimension3 Converted to Table" = Table.FromRecords({Source_CustomDimension3}),
                        #"CustomDimension3 Removed Columns" = Table.RemoveColumns(#"CustomDimension3 Converted to Table", {"@odata.context"}),
                        #"CustomDimension3 Expanded value" = Table.ExpandListColumn(#"CustomDimension3 Removed Columns", "value"),
                        Output_Source_CustomDimension3 = Table.ExpandRecordColumn(#"CustomDimension3 Expanded value", "value", {"COD_DEST3", "DESC_DEST30", "DESC_DEST31", "DESC_DEST32", "DESC_DEST33", "ATTRIBUTO1", "ATTRIBUTO2", "ATTRIBUTO3", "ATTRIBUTO4", "ATTRIBUTO5"})
                    in 
                        Output_Source_CustomDimension3
            ]
        ),
    #"AW_CustomDimension3 Duplicated Column" = Table.DuplicateColumn(AW_Output_Source_CustomDimension3, "COD_DEST3", "TGK_DEST3_KEY"),
    #"AW_CustomDimension3 Duplicated Column1" = Table.DuplicateColumn(#"AW_CustomDimension3 Duplicated Column", "COD_DEST3", "TGK_DEST3_H_KEY"),
    AW_CustomDimension3 = Table.RenameColumns(#"AW_CustomDimension3 Duplicated Column1",{{"COD_DEST3", "Custom Dimension 3 Code"}, {"DESC_DEST30", "Custom Dimension 3 Description"}, {"DESC_DEST31", "Custom Dimension 3 Description 1"}, {"DESC_DEST32", "Custom Dimension 3 Description 2"}, {"DESC_DEST33", "Custom Dimension 3 Description 3"}, {"ATTRIBUTO1", "Custom Dimension 3 Attribute 1"}, {"ATTRIBUTO2", "Custom Dimension 3 Attribute 2"}, {"ATTRIBUTO3", "Custom Dimension 3 Attribute 3"}, {"ATTRIBUTO4", "Custom Dimension 3 Attribute 4"}, {"ATTRIBUTO5", "Custom Dimension 3 Attribute 5"}})
    ,
    //AIH Custom Dimension 4
    AW_Output_Source_CustomDimension4 = 
    Table.View(null,
            [
                GetType = () =>
                    type table [
                        COD_DEST4 = text,
                        DESC_DEST40 = text,
                        DESC_DEST41 = text,
                        DESC_DEST42 = text,
                        DESC_DEST43 = text,
                        ATTRIBUTO1 = text,
                        ATTRIBUTO2 = text,
                        ATTRIBUTO3 = text,
                        ATTRIBUTO4 = text,
                        ATTRIBUTO5 = text
                    ],
                GetRows = () =>
                    let 
                        Source_CustomDimension4 = Json.Document(Web.Contents(outputURL & "Datasource_000012()", [Timeout=#duration(0,0,30,0)])),
                        #"CustomDimension4 Converted to Table" = Table.FromRecords({Source_CustomDimension4}),
                        #"CustomDimension4 Removed Columns" = Table.RemoveColumns(#"CustomDimension4 Converted to Table", {"@odata.context"}),
                        #"CustomDimension4 Expanded value" = Table.ExpandListColumn(#"CustomDimension4 Removed Columns", "value"),
                        Output_Source_CustomDimension4 = Table.ExpandRecordColumn(#"CustomDimension4 Expanded value", "value", {"COD_DEST4", "DESC_DEST40", "DESC_DEST41", "DESC_DEST42", "DESC_DEST43", "ATTRIBUTO1", "ATTRIBUTO2", "ATTRIBUTO3", "ATTRIBUTO4", "ATTRIBUTO5"})
                    in 
                        Output_Source_CustomDimension4
            ]
        ),
    
    #"AW_CustomDimension4 Duplicated Column" = Table.DuplicateColumn(AW_Output_Source_CustomDimension4, "COD_DEST4", "TGK_DEST4_KEY"),
    #"AW_CustomDimension4 Duplicated Column1" = Table.DuplicateColumn(#"AW_CustomDimension4 Duplicated Column", "COD_DEST4", "TGK_DEST4_H_KEY"),
    AW_CustomDimension4 = Table.RenameColumns(#"AW_CustomDimension4 Duplicated Column1",{{"COD_DEST4", "Custom Dimension 4 Code"}, {"DESC_DEST40", "Custom Dimension 4 Description"}, {"DESC_DEST41", "Custom Dimension 4 Description 1"}, {"DESC_DEST42", "Custom Dimension 4 Description 2"}, {"DESC_DEST43", "Custom Dimension 4 Description 3"}, {"ATTRIBUTO1", "Custom Dimension 4 Attribute 1"}, {"ATTRIBUTO2", "Custom Dimension 4 Attribute 2"}, {"ATTRIBUTO3", "Custom Dimension 4 Attribute 3"}, {"ATTRIBUTO4", "Custom Dimension 4 Attribute 4"}, {"ATTRIBUTO5", "Custom Dimension 4 Attribute 5"}})
    ,
    //AIH Custom Dimension 5
    AW_Output_Source_CustomDimension5 = 
    Table.View(null,
            [
                GetType = () =>
                    type table [
                        COD_DEST5 = text,
                        DESC_DEST50 = text,
                        DESC_DEST51 = text,
                        DESC_DEST52 = text,
                        DESC_DEST53 = text,
                        ATTRIBUTO1 = text,
                        ATTRIBUTO2 = text,
                        ATTRIBUTO3 = text,
                        ATTRIBUTO4 = text,
                        ATTRIBUTO5 = text
                    ],
                GetRows = () =>
                    let 
                        Source_CustomDimension5 = Json.Document(Web.Contents(outputURL & "Datasource_000013()", [Timeout=#duration(0,0,30,0)])),
                        #"CustomDimension5 Converted to Table" = Table.FromRecords({Source_CustomDimension5}),
                        #"CustomDimension5 Removed Columns" = Table.RemoveColumns(#"CustomDimension5 Converted to Table", {"@odata.context"}),
                        #"CustomDimension5 Expanded value" = Table.ExpandListColumn(#"CustomDimension5 Removed Columns", "value"),
                        Output_Source_CustomDimension5 = Table.ExpandRecordColumn(#"CustomDimension5 Expanded value", "value", {"COD_DEST5", "DESC_DEST50", "DESC_DEST51", "DESC_DEST52", "DESC_DEST53", "ATTRIBUTO1", "ATTRIBUTO2", "ATTRIBUTO3", "ATTRIBUTO4", "ATTRIBUTO5"})
                    in 
                        Output_Source_CustomDimension5
            ]
        ),
    
    #"AW_CustomDimension5 Duplicated Column" = Table.DuplicateColumn(AW_Output_Source_CustomDimension5, "COD_DEST5", "TGK_DEST5_KEY"),
    #"AW_CustomDimension5 Duplicated Column1" = Table.DuplicateColumn(#"AW_CustomDimension5 Duplicated Column", "COD_DEST5", "TGK_DEST5_H_KEY"),
    AW_CustomDimension5 = Table.RenameColumns(#"AW_CustomDimension5 Duplicated Column1",{{"COD_DEST5", "Custom Dimension 5 Code"}, {"DESC_DEST50", "Custom Dimension 5 Description"}, {"DESC_DEST51", "Custom Dimension 5 Description 1"}, {"DESC_DEST52", "Custom Dimension 5 Description 2"}, {"DESC_DEST53", "Custom Dimension 5 Description 3"}, {"ATTRIBUTO1", "Custom Dimension 5 Attribute 1"}, {"ATTRIBUTO2", "Custom Dimension 5 Attribute 2"}, {"ATTRIBUTO3", "Custom Dimension 5 Attribute 3"}, {"ATTRIBUTO4", "Custom Dimension 5 Attribute 4"}, {"ATTRIBUTO5", "Custom Dimension 5 Attribute 5"}})
	,
    //AIH Custom Dimension 1 Hierarchy
    AW_Output_Source_CustomDimension1_H =
    Table.View(null,
        [
            GetType = () =>
            type table [
                COD_DEST1_GERARCHIA = Text.Type,
                DESC_DEST1_GERARCHIA = Text.Type,
                COD_DEST1_ELEGER1 = Text.Type,
                DESC_DEST1_ELEGER1 = Text.Type,
                COD_DEST1_ELEGER2 = Text.Type,
                DESC_DEST1_ELEGER2 = Text.Type,
                COD_DEST1_ELEGER3 = Text.Type,
                DESC_DEST1_ELEGER3 = Text.Type,
                COD_DEST1_ELEGER4 = Text.Type,
                DESC_DEST1_ELEGER4 = Text.Type,
                COD_DEST1_ELEGER5 = Text.Type,
                DESC_DEST1_ELEGER5 = Text.Type,
                COD_DEST1_ELEGER6 = Text.Type,
                DESC_DEST1_ELEGER6 = Text.Type,
                COD_DEST1_ELEGER7 = Text.Type,
                DESC_DEST1_ELEGER7 = Text.Type,
                COD_DEST1_ELEGER8 = Text.Type,
                DESC_DEST1_ELEGER8 = Text.Type,
                COD_DEST1_KEY = Text.Type
            ],
            GetRows = () =>
                let 
                    Source_CustomDimension1_H = Json.Document(Web.Contents(outputURL & "Datasource_AW9990()" ,[Timeout=#duration(0,0,30,0)])),
                    #"CustomDimension1_H Converted to Table" = Table.FromRecords({Source_CustomDimension1_H}),
                    #"CustomDimension1_H Removed Columns" = Table.RemoveColumns(#"CustomDimension1_H Converted to Table",{"@odata.context"}),
                    #"CustomDimension1_H Expanded value" = Table.ExpandListColumn(#"CustomDimension1_H Removed Columns", "value"),
                    Output_Source_CustomDimension1_H = Table.ExpandRecordColumn(#"CustomDimension1_H Expanded value", "value",{ "COD_DEST1_GERARCHIA","DESC_DEST1_GERARCHIA", "COD_DEST1_ELEGER1", "DESC_DEST1_ELEGER1", "COD_DEST1_ELEGER2", "DESC_DEST1_ELEGER2", "COD_DEST1_ELEGER3", "DESC_DEST1_ELEGER3", "COD_DEST1_ELEGER4", "DESC_DEST1_ELEGER4", "COD_DEST1_ELEGER5", "DESC_DEST1_ELEGER5", "COD_DEST1_ELEGER6", "DESC_DEST1_ELEGER6", "COD_DEST1_ELEGER7", "DESC_DEST1_ELEGER7", "COD_DEST1_ELEGER8", "DESC_DEST1_ELEGER8","COD_DEST1_KEY"})
                in 
                    Output_Source_CustomDimension1_H
        ]
    ),
    AW_CustomDimension1_H = Table.RenameColumns(AW_Output_Source_CustomDimension1_H,{{"COD_DEST1_GERARCHIA", "Custom Dimension 1 Hierarchy Code"}, {"DESC_DEST1_GERARCHIA", "Custom Dimension 1 Hierarchy Description"}, {"COD_DEST1_ELEGER1", "Custom Dimension 1 Hierarchy Code Level 1"}, {"COD_DEST1_ELEGER2", "Custom Dimension 1 Hierarchy Code Level 2"}, {"COD_DEST1_ELEGER3", "Custom Dimension 1 Hierarchy Code Level 3"}, {"COD_DEST1_ELEGER4", "Custom Dimension 1 Hierarchy Code Level 4"}, {"COD_DEST1_ELEGER5", "Custom Dimension 1 Hierarchy Code Level 5"}, {"COD_DEST1_ELEGER6", "Custom Dimension 1 Hierarchy Code Level 6"}, {"COD_DEST1_ELEGER7", "Custom Dimension 1 Hierarchy Code Level 7"}, {"COD_DEST1_ELEGER8", "Custom Dimension 1 Hierarchy Code Level 8"}, {"DESC_DEST1_ELEGER1", "Custom Dimension 1 Hierarchy Description Level 1"}, {"DESC_DEST1_ELEGER2", "Custom Dimension 1 Hierarchy Description Level 2"}, {"DESC_DEST1_ELEGER3", "Custom Dimension 1 Hierarchy Description Level 3"}, {"DESC_DEST1_ELEGER4", "Custom Dimension 1 Hierarchy Description Level 4"}, {"DESC_DEST1_ELEGER5", "Custom Dimension 1 Hierarchy Description Level 5"}, {"DESC_DEST1_ELEGER6", "Custom Dimension 1 Hierarchy Description Level 6"}, {"DESC_DEST1_ELEGER7", "Custom Dimension 1 Hierarchy Description Level 7"}, {"DESC_DEST1_ELEGER8", "Custom Dimension 1 Hierarchy Description Level 8"}, {"COD_DEST1_KEY", "TGK_DEST1_H_KEY"}})
    ,	
    //AIH Custom Dimension 2 Hierarchy
	AW_Output_Source_CustomDimension2_H=
    Table.View(null,
        [
            GetType = () =>
            type table [
                COD_DEST2_GERARCHIA = Text.Type,
                DESC_DEST2_GERARCHIA = Text.Type,
                COD_DEST2_ELEGER1 = Text.Type,
                DESC_DEST2_ELEGER1 = Text.Type,
                COD_DEST2_ELEGER2 = Text.Type,
                DESC_DEST2_ELEGER2 = Text.Type,
                COD_DEST2_ELEGER3 = Text.Type,
                DESC_DEST2_ELEGER3 = Text.Type,
                COD_DEST2_ELEGER4 = Text.Type,
                DESC_DEST2_ELEGER4 = Text.Type,
                COD_DEST2_ELEGER5 = Text.Type,
                DESC_DEST2_ELEGER5 = Text.Type,
                COD_DEST2_ELEGER6 = Text.Type,
                DESC_DEST2_ELEGER6 = Text.Type,
                COD_DEST2_ELEGER7 = Text.Type,
                DESC_DEST2_ELEGER7 = Text.Type,
                COD_DEST2_ELEGER8 = Text.Type,
                DESC_DEST2_ELEGER8 = Text.Type,
                COD_DEST2_KEY = Text.Type
            ],
            GetRows = () =>
                let 
                    Source_CustomDimension2_H = Json.Document(Web.Contents(outputURL & "Datasource_AW9989()" ,[Timeout=#duration(0,0,30,0)])),
                    #"CustomDimension2_H Converted to Table" = Table.FromRecords({Source_CustomDimension2_H}),
                    #"CustomDimension2_H Removed Columns" = Table.RemoveColumns(#"CustomDimension2_H Converted to Table",{"@odata.context"}),
                    #"CustomDimension2_H Expanded value" = Table.ExpandListColumn(#"CustomDimension2_H Removed Columns", "value"),
                    Output_Source_CustomDimension2_H = Table.ExpandRecordColumn(#"CustomDimension2_H Expanded value", "value",{ "COD_DEST2_GERARCHIA","DESC_DEST2_GERARCHIA", "COD_DEST2_ELEGER1", "DESC_DEST2_ELEGER1", "COD_DEST2_ELEGER2", "DESC_DEST2_ELEGER2", "COD_DEST2_ELEGER3", "DESC_DEST2_ELEGER3", "COD_DEST2_ELEGER4", "DESC_DEST2_ELEGER4", "COD_DEST2_ELEGER5", "DESC_DEST2_ELEGER5", "COD_DEST2_ELEGER6", "DESC_DEST2_ELEGER6", "COD_DEST2_ELEGER7", "DESC_DEST2_ELEGER7", "COD_DEST2_ELEGER8", "DESC_DEST2_ELEGER8","COD_DEST2_KEY"})
                in 
                    Output_Source_CustomDimension2_H
        ]
    ),
    AW_CustomDimension2_H = Table.RenameColumns(AW_Output_Source_CustomDimension2_H,{{"COD_DEST2_GERARCHIA", "Custom Dimension 2 Hierarchy Code"}, {"DESC_DEST2_GERARCHIA", "Custom Dimension 2 Hierarchy Description"}, {"COD_DEST2_ELEGER1", "Custom Dimension 2 Hierarchy Code Level 1"}, {"COD_DEST2_ELEGER2", "Custom Dimension 2 Hierarchy Code Level 2"}, {"COD_DEST2_ELEGER3", "Custom Dimension 2 Hierarchy Code Level 3"}, {"COD_DEST2_ELEGER4", "Custom Dimension 2 Hierarchy Code Level 4"}, {"COD_DEST2_ELEGER5", "Custom Dimension 2 Hierarchy Code Level 5"}, {"COD_DEST2_ELEGER6", "Custom Dimension 2 Hierarchy Code Level 6"}, {"COD_DEST2_ELEGER7", "Custom Dimension 2 Hierarchy Code Level 7"}, {"COD_DEST2_ELEGER8", "Custom Dimension 2 Hierarchy Code Level 8"}, {"DESC_DEST2_ELEGER1", "Custom Dimension 2 Hierarchy Description Level 1"}, {"DESC_DEST2_ELEGER2", "Custom Dimension 2 Hierarchy Description Level 2"}, {"DESC_DEST2_ELEGER3", "Custom Dimension 2 Hierarchy Description Level 3"}, {"DESC_DEST2_ELEGER4", "Custom Dimension 2 Hierarchy Description Level 4"}, {"DESC_DEST2_ELEGER5", "Custom Dimension 2 Hierarchy Description Level 5"}, {"DESC_DEST2_ELEGER6", "Custom Dimension 2 Hierarchy Description Level 6"}, {"DESC_DEST2_ELEGER7", "Custom Dimension 2 Hierarchy Description Level 7"}, {"DESC_DEST2_ELEGER8", "Custom Dimension 2 Hierarchy Description Level 8"}, {"COD_DEST2_KEY", "TGK_DEST2_H_KEY"}})
    ,
    //AIH Custom Dimension 2 CTP Hierarchy
    AW_Source_CustomDimension2_CTP_H = Table.SelectColumns(AW_CustomDimension2_H,{"Custom Dimension 2 Hierarchy Code", "Custom Dimension 2 Hierarchy Description", "Custom Dimension 2 Hierarchy Code Level 1", "Custom Dimension 2 Hierarchy Code Level 2", "Custom Dimension 2 Hierarchy Code Level 3", "Custom Dimension 2 Hierarchy Code Level 4", "Custom Dimension 2 Hierarchy Code Level 5", "Custom Dimension 2 Hierarchy Code Level 6", "Custom Dimension 2 Hierarchy Code Level 7", "Custom Dimension 2 Hierarchy Code Level 8", "Custom Dimension 2 Hierarchy Description Level 1","Custom Dimension 2 Hierarchy Description Level 2", "Custom Dimension 2 Hierarchy Description Level 3", "Custom Dimension 2 Hierarchy Description Level 4", "Custom Dimension 2 Hierarchy Description Level 5", "Custom Dimension 2 Hierarchy Description Level 6", "Custom Dimension 2 Hierarchy Description Level 7", "Custom Dimension 2 Hierarchy Description Level 8", "TGK_DEST2_H_KEY"}),  
    #"AW_Custom Dimension 2 CTP H Transform Description" = Table.TransformColumns(AW_Source_CustomDimension2_CTP_H, {{"Custom Dimension 2 Hierarchy Description",each Text.Combine({(_), " Counterparty"})},{"Custom Dimension 2 Hierarchy Description Level 8",each Text.Combine({(_), " Counterparty"})}}),
    #"AW_Custom Dimension 2 CTP H Hierarchy List" = Table.Distinct(Table.SelectColumns(#"AW_Custom Dimension 2 CTP H Transform Description",{"Custom Dimension 2 Hierarchy Code","Custom Dimension 2 Hierarchy Description","Custom Dimension 2 Hierarchy Code Level 8","Custom Dimension 2 Hierarchy Description Level 8"})),
    #"AW_Custom Dimension 2 CTP H Added 3rd party" = Table.AddColumn( #"AW_Custom Dimension 2 CTP H Hierarchy List", "Custom Dimension 2 Hierarchy Code Level 7", each "[$NET]"),
    #"AW_Custom Dimension 2 CTP H Added 3rd party key" = Table.AddColumn( #"AW_Custom Dimension 2 CTP H Added 3rd party" , "TGK_DEST2_H_KEY", each "$NET"),
    #"AW_Custom Dimension 2 CTP H Added 3rd party Description" = Table.AddColumn(  #"AW_Custom Dimension 2 CTP H Added 3rd party key", "Custom Dimension 2 Hierarchy Description Level 7", each "[$NET - 3rd party]"),
    #"AW_Custom Dimension 2 CTP H Appended Query" = Table.Combine({#"AW_Custom Dimension 2 CTP H Transform Description",  #"AW_Custom Dimension 2 CTP H Added 3rd party Description"}), 
    #"AW_Custom Dimension 2 CTP H RenameColumns"  = Table.RenameColumns(if Record.Field(Table.First(AW_CustomDimension2_H), "Custom Dimension 2 Hierarchy Code")= null then AW_Source_CustomDimension2_CTP_H else #"AW_Custom Dimension 2 CTP H Appended Query",{{"Custom Dimension 2 Hierarchy Code", "Custom Dimension 2 CTP Hierarchy Code"}, {"Custom Dimension 2 Hierarchy Description", "Custom Dimension 2 CTP Hierarchy Description"}, {"Custom Dimension 2 Hierarchy Code Level 1", "Custom Dimension 2 CTP Hierarchy Code Level 1"}, {"Custom Dimension 2 Hierarchy Code Level 2", "Custom Dimension 2 CTP Hierarchy Code Level 2"}, {"Custom Dimension 2 Hierarchy Code Level 3", "Custom Dimension 2 CTP Hierarchy Code Level 3"}, {"Custom Dimension 2 Hierarchy Code Level 4", "Custom Dimension 2 CTP Hierarchy Code Level 4"}, {"Custom Dimension 2 Hierarchy Code Level 5", "Custom Dimension 2 CTP Hierarchy Code Level 5"}, {"Custom Dimension 2 Hierarchy Code Level 6", "Custom Dimension 2 CTP Hierarchy Code Level 6"}, {"Custom Dimension 2 Hierarchy Code Level 7", "Custom Dimension 2 CTP Hierarchy Code Level 7"}, {"Custom Dimension 2 Hierarchy Code Level 8", "Custom Dimension 2 CTP Hierarchy Code Level 8"}, {"Custom Dimension 2 Hierarchy Description Level 1", "Custom Dimension 2 CTP Hierarchy Description Level 1"}, {"Custom Dimension 2 Hierarchy Description Level 2", "Custom Dimension 2 CTP Hierarchy Description Level 2"}, {"Custom Dimension 2 Hierarchy Description Level 3", "Custom Dimension 2 CTP Hierarchy Description Level 3"}, {"Custom Dimension 2 Hierarchy Description Level 4", "Custom Dimension 2 CTP Hierarchy Description Level 4"}, {"Custom Dimension 2 Hierarchy Description Level 5", "Custom Dimension 2 CTP Hierarchy Description Level 5"}, {"Custom Dimension 2 Hierarchy Description Level 6", "Custom Dimension 2 CTP Hierarchy Description Level 6"}, {"Custom Dimension 2 Hierarchy Description Level 7", "Custom Dimension 2 CTP Hierarchy Description Level 7"}, {"Custom Dimension 2 Hierarchy Description Level 8", "Custom Dimension 2 CTP Hierarchy Description Level 8"},  {"TGK_DEST2_H_KEY", "TGK_DEST2_CTP_H_KEY"}}),
    AW_CustomDimension2_CTP_H =  Table.TransformColumnTypes(  #"AW_Custom Dimension 2 CTP H RenameColumns"  ,{{"TGK_DEST2_CTP_H_KEY", type text}, {"Custom Dimension 2 CTP Hierarchy Description Level 8", type text}, {"Custom Dimension 2 CTP Hierarchy Description Level 7", type text}, {"Custom Dimension 2 CTP Hierarchy Code Level 7", type text}, {"Custom Dimension 2 CTP Hierarchy Description", type text}})
    ,
    //AIH Custom Dimension 3 Hierarchy
    AW_Output_Source_CustomDimension3_H =
    Table.View(null,
        [
            GetType = () =>
            type table [
                COD_DEST3_GERARCHIA = Text.Type,
                DESC_DEST3_GERARCHIA = Text.Type,
                COD_DEST3_ELEGER1 = Text.Type,
                DESC_DEST3_ELEGER1 = Text.Type,
                COD_DEST3_ELEGER2 = Text.Type,
                DESC_DEST3_ELEGER2 = Text.Type,
                COD_DEST3_ELEGER3 = Text.Type,
                DESC_DEST3_ELEGER3 = Text.Type,
                COD_DEST3_ELEGER4 = Text.Type,
                DESC_DEST3_ELEGER4 = Text.Type,
                COD_DEST3_ELEGER5 = Text.Type,
                DESC_DEST3_ELEGER5 = Text.Type,
                COD_DEST3_ELEGER6 = Text.Type,
                DESC_DEST3_ELEGER6 = Text.Type,
                COD_DEST3_ELEGER7 = Text.Type,
                DESC_DEST3_ELEGER7 = Text.Type,
                COD_DEST3_ELEGER8 = Text.Type,
                DESC_DEST3_ELEGER8 = Text.Type,
                COD_DEST3_KEY = Text.Type
            ],
            GetRows = () =>
                let 
                    Source_CustomDimension3_H = Json.Document(Web.Contents(outputURL & "Datasource_AW9988()" ,[Timeout=#duration(0,0,30,0)])),
                    #"CustomDimension3_H Converted to Table" = Table.FromRecords({Source_CustomDimension3_H}),
                    #"CustomDimension3_H Removed Columns" = Table.RemoveColumns(#"CustomDimension3_H Converted to Table",{"@odata.context"}),
                    #"CustomDimension3_H Expanded value" = Table.ExpandListColumn(#"CustomDimension3_H Removed Columns", "value"),
                    Output_Source_CustomDimension3_H = Table.ExpandRecordColumn(#"CustomDimension3_H Expanded value", "value",{ "COD_DEST3_GERARCHIA","DESC_DEST3_GERARCHIA", "COD_DEST3_ELEGER1", "DESC_DEST3_ELEGER1", "COD_DEST3_ELEGER2", "DESC_DEST3_ELEGER2", "COD_DEST3_ELEGER3", "DESC_DEST3_ELEGER3", "COD_DEST3_ELEGER4", "DESC_DEST3_ELEGER4", "COD_DEST3_ELEGER5", "DESC_DEST3_ELEGER5", "COD_DEST3_ELEGER6", "DESC_DEST3_ELEGER6", "COD_DEST3_ELEGER7", "DESC_DEST3_ELEGER7", "COD_DEST3_ELEGER8", "DESC_DEST3_ELEGER8","COD_DEST3_KEY"})
                in 
                    Output_Source_CustomDimension3_H
        ]
    ),

    AW_CustomDimension3_H = Table.RenameColumns(AW_Output_Source_CustomDimension3_H,{{"COD_DEST3_GERARCHIA", "Custom Dimension 3 Hierarchy Code"}, {"DESC_DEST3_GERARCHIA", "Custom Dimension 3 Hierarchy Description"}, {"COD_DEST3_ELEGER1", "Custom Dimension 3 Hierarchy Code Level 1"}, {"COD_DEST3_ELEGER2", "Custom Dimension 3 Hierarchy Code Level 2"}, {"COD_DEST3_ELEGER3", "Custom Dimension 3 Hierarchy Code Level 3"}, {"COD_DEST3_ELEGER4", "Custom Dimension 3 Hierarchy Code Level 4"}, {"COD_DEST3_ELEGER5", "Custom Dimension 3 Hierarchy Code Level 5"}, {"COD_DEST3_ELEGER6", "Custom Dimension 3 Hierarchy Code Level 6"}, {"COD_DEST3_ELEGER7", "Custom Dimension 3 Hierarchy Code Level 7"}, {"COD_DEST3_ELEGER8", "Custom Dimension 3 Hierarchy Code Level 8"}, {"DESC_DEST3_ELEGER1", "Custom Dimension 3 Hierarchy Description Level 1"}, {"DESC_DEST3_ELEGER2", "Custom Dimension 3 Hierarchy Description Level 2"}, {"DESC_DEST3_ELEGER3", "Custom Dimension 3 Hierarchy Description Level 3"}, {"DESC_DEST3_ELEGER4", "Custom Dimension 3 Hierarchy Description Level 4"}, {"DESC_DEST3_ELEGER5", "Custom Dimension 3 Hierarchy Description Level 5"}, {"DESC_DEST3_ELEGER6", "Custom Dimension 3 Hierarchy Description Level 6"}, {"DESC_DEST3_ELEGER7", "Custom Dimension 3 Hierarchy Description Level 7"}, {"DESC_DEST3_ELEGER8", "Custom Dimension 3 Hierarchy Description Level 8"}, {"COD_DEST3_KEY", "TGK_DEST3_H_KEY"}})
    ,
    //AIH Custom Dimension 4 Hierarchy
    AW_Output_Source_CustomDimension4_H =
    Table.View(null,
        [
            GetType = () =>
            type table [
                COD_DEST4_GERARCHIA = Text.Type,
                DESC_DEST4_GERARCHIA = Text.Type,
                COD_DEST4_ELEGER1 = Text.Type,
                DESC_DEST4_ELEGER1 = Text.Type,
                COD_DEST4_ELEGER2 = Text.Type,
                DESC_DEST4_ELEGER2 = Text.Type,
                COD_DEST4_ELEGER3 = Text.Type,
                DESC_DEST4_ELEGER3 = Text.Type,
                COD_DEST4_ELEGER4 = Text.Type,
                DESC_DEST4_ELEGER4 = Text.Type,
                COD_DEST4_ELEGER5 = Text.Type,
                DESC_DEST4_ELEGER5 = Text.Type,
                COD_DEST4_ELEGER6 = Text.Type,
                DESC_DEST4_ELEGER6 = Text.Type,
                COD_DEST4_ELEGER7 = Text.Type,
                DESC_DEST4_ELEGER7 = Text.Type,
                COD_DEST4_ELEGER8 = Text.Type,
                DESC_DEST4_ELEGER8 = Text.Type,
                COD_DEST4_KEY = Text.Type
            ],
            GetRows = () =>
                let 
                    Source_CustomDimension4_H = Json.Document(Web.Contents(outputURL & "Datasource_AW9987()" ,[Timeout=#duration(0,0,30,0)])),
                    #"CustomDimension4_H Converted to Table" = Table.FromRecords({Source_CustomDimension4_H}),
                    #"CustomDimension4_H Removed Columns" = Table.RemoveColumns(#"CustomDimension4_H Converted to Table",{"@odata.context"}),
                    #"CustomDimension4_H Expanded value" = Table.ExpandListColumn(#"CustomDimension4_H Removed Columns", "value"),
                    Output_Source_CustomDimension4_H = Table.ExpandRecordColumn(#"CustomDimension4_H Expanded value", "value",{ "COD_DEST4_GERARCHIA","DESC_DEST4_GERARCHIA", "COD_DEST4_ELEGER1", "DESC_DEST4_ELEGER1", "COD_DEST4_ELEGER2", "DESC_DEST4_ELEGER2", "COD_DEST4_ELEGER3", "DESC_DEST4_ELEGER3", "COD_DEST4_ELEGER4", "DESC_DEST4_ELEGER4", "COD_DEST4_ELEGER5", "DESC_DEST4_ELEGER5", "COD_DEST4_ELEGER6", "DESC_DEST4_ELEGER6", "COD_DEST4_ELEGER7", "DESC_DEST4_ELEGER7", "COD_DEST4_ELEGER8", "DESC_DEST4_ELEGER8","COD_DEST4_KEY"})
                in 
                    Output_Source_CustomDimension4_H
        ]
    ),

    AW_CustomDimension4_H = Table.RenameColumns(AW_Output_Source_CustomDimension4_H,{{"COD_DEST4_GERARCHIA", "Custom Dimension 4 Hierarchy Code"}, {"DESC_DEST4_GERARCHIA", "Custom Dimension 4 Hierarchy Description"}, {"COD_DEST4_ELEGER1", "Custom Dimension 4 Hierarchy Code Level 1"}, {"COD_DEST4_ELEGER2", "Custom Dimension 4 Hierarchy Code Level 2"}, {"COD_DEST4_ELEGER3", "Custom Dimension 4 Hierarchy Code Level 3"}, {"COD_DEST4_ELEGER4", "Custom Dimension 4 Hierarchy Code Level 4"}, {"COD_DEST4_ELEGER5", "Custom Dimension 4 Hierarchy Code Level 5"}, {"COD_DEST4_ELEGER6", "Custom Dimension 4 Hierarchy Code Level 6"}, {"COD_DEST4_ELEGER7", "Custom Dimension 4 Hierarchy Code Level 7"}, {"COD_DEST4_ELEGER8", "Custom Dimension 4 Hierarchy Code Level 8"}, {"DESC_DEST4_ELEGER1", "Custom Dimension 4 Hierarchy Description Level 1"}, {"DESC_DEST4_ELEGER2", "Custom Dimension 4 Hierarchy Description Level 2"}, {"DESC_DEST4_ELEGER3", "Custom Dimension 4 Hierarchy Description Level 3"}, {"DESC_DEST4_ELEGER4", "Custom Dimension 4 Hierarchy Description Level 4"}, {"DESC_DEST4_ELEGER5", "Custom Dimension 4 Hierarchy Description Level 5"}, {"DESC_DEST4_ELEGER6", "Custom Dimension 4 Hierarchy Description Level 6"}, {"DESC_DEST4_ELEGER7", "Custom Dimension 4 Hierarchy Description Level 7"}, {"DESC_DEST4_ELEGER8", "Custom Dimension 4 Hierarchy Description Level 8"}, {"COD_DEST4_KEY", "TGK_DEST4_H_KEY"}})
    ,
    //AIH Custom Dimension 5 Hierarchy
    AW_Output_Source_CustomDimension5_H =
    Table.View(null,
        [
            GetType = () =>
            type table [
                COD_DEST5_GERARCHIA = Text.Type,
                DESC_DEST5_GERARCHIA = Text.Type,
                COD_DEST5_ELEGER1 = Text.Type,
                DESC_DEST5_ELEGER1 = Text.Type,
                COD_DEST5_ELEGER2 = Text.Type,
                DESC_DEST5_ELEGER2 = Text.Type,
                COD_DEST5_ELEGER3 = Text.Type,
                DESC_DEST5_ELEGER3 = Text.Type,
                COD_DEST5_ELEGER4 = Text.Type,
                DESC_DEST5_ELEGER4 = Text.Type,
                COD_DEST5_ELEGER5 = Text.Type,
                DESC_DEST5_ELEGER5 = Text.Type,
                COD_DEST5_ELEGER6 = Text.Type,
                DESC_DEST5_ELEGER6 = Text.Type,
                COD_DEST5_ELEGER7 = Text.Type,
                DESC_DEST5_ELEGER7 = Text.Type,
                COD_DEST5_ELEGER8 = Text.Type,
                DESC_DEST5_ELEGER8 = Text.Type,
                COD_DEST5_KEY = Text.Type
            ],
            GetRows = () =>
                let 
                    Source_CustomDimension5_H = Json.Document(Web.Contents(outputURL & "Datasource_AW9986()" ,[Timeout=#duration(0,0,30,0)])),
                    #"CustomDimension5_H Converted to Table" = Table.FromRecords({Source_CustomDimension5_H}),
                    #"CustomDimension5_H Removed Columns" = Table.RemoveColumns(#"CustomDimension5_H Converted to Table",{"@odata.context"}),
                    #"CustomDimension5_H Expanded value" = Table.ExpandListColumn(#"CustomDimension5_H Removed Columns", "value"),
                    Output_Source_CustomDimension5_H = Table.ExpandRecordColumn(#"CustomDimension5_H Expanded value", "value",{ "COD_DEST5_GERARCHIA","DESC_DEST5_GERARCHIA", "COD_DEST5_ELEGER1", "DESC_DEST5_ELEGER1", "COD_DEST5_ELEGER2", "DESC_DEST5_ELEGER2", "COD_DEST5_ELEGER3", "DESC_DEST5_ELEGER3", "COD_DEST5_ELEGER4", "DESC_DEST5_ELEGER4", "COD_DEST5_ELEGER5", "DESC_DEST5_ELEGER5", "COD_DEST5_ELEGER6", "DESC_DEST5_ELEGER6", "COD_DEST5_ELEGER7", "DESC_DEST5_ELEGER7", "COD_DEST5_ELEGER8", "DESC_DEST5_ELEGER8","COD_DEST5_KEY"})
                in 
                    Output_Source_CustomDimension5_H
        ]
    ),
    AW_CustomDimension5_H = Table.RenameColumns(AW_Output_Source_CustomDimension5_H,{{"COD_DEST5_GERARCHIA", "Custom Dimension 5 Hierarchy Code"}, {"DESC_DEST5_GERARCHIA", "Custom Dimension 5 Hierarchy Description"}, {"COD_DEST5_ELEGER1", "Custom Dimension 5 Hierarchy Code Level 1"}, {"COD_DEST5_ELEGER2", "Custom Dimension 5 Hierarchy Code Level 2"}, {"COD_DEST5_ELEGER3", "Custom Dimension 5 Hierarchy Code Level 3"}, {"COD_DEST5_ELEGER4", "Custom Dimension 5 Hierarchy Code Level 4"}, {"COD_DEST5_ELEGER5", "Custom Dimension 5 Hierarchy Code Level 5"}, {"COD_DEST5_ELEGER6", "Custom Dimension 5 Hierarchy Code Level 6"}, {"COD_DEST5_ELEGER7", "Custom Dimension 5 Hierarchy Code Level 7"}, {"COD_DEST5_ELEGER8", "Custom Dimension 5 Hierarchy Code Level 8"}, {"DESC_DEST5_ELEGER1", "Custom Dimension 5 Hierarchy Description Level 1"}, {"DESC_DEST5_ELEGER2", "Custom Dimension 5 Hierarchy Description Level 2"}, {"DESC_DEST5_ELEGER3", "Custom Dimension 5 Hierarchy Description Level 3"}, {"DESC_DEST5_ELEGER4", "Custom Dimension 5 Hierarchy Description Level 4"}, {"DESC_DEST5_ELEGER5", "Custom Dimension 5 Hierarchy Description Level 5"}, {"DESC_DEST5_ELEGER6", "Custom Dimension 5 Hierarchy Description Level 6"}, {"DESC_DEST5_ELEGER7", "Custom Dimension 5 Hierarchy Description Level 7"}, {"DESC_DEST5_ELEGER8", "Custom Dimension 5 Hierarchy Description Level 8"}, {"COD_DEST5_KEY", "TGK_DEST5_H_KEY"}})
	,
    //AIH Entity
    AW_Output_Source_Entity =
    Table.View(null,
            [
                GetType = () =>
                       type table [
						COD_AZIENDA = Text.Type,
						RAGIONE_SOCIALE = Text.Type,
						SEDE_LEGALE = Text.Type,
						SEDE_AMMINISTRATIVA = Text.Type,
						COD_VALUTA = Text.Type,
						ATTRIBUTO1 = Text.Type,
						ATTRIBUTO2 = Text.Type,
						ATTRIBUTO3 = Text.Type,
						ATTRIBUTO4 = Text.Type,
						ATTRIBUTO5 = Text.Type,
						DESC_AZIENDA0 = Text.Type,
						DESC_AZIENDA1 = Text.Type,
						DESC_AZIENDA2 = Text.Type,
						DESC_AZIENDA3 = Text.Type,
						SEDE_PRINCIPALE = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Entity = Json.Document(Web.Contents(outputURL &"Datasource_AW9995()?$filter=D in "& filterDatasetList,[Timeout=#duration(0,0,30,0)])),
                        #"Entity Converted to Table" = Table.FromRecords({Source_Entity}),
                        #"Entity Removed Columns" = Table.RemoveColumns(#"Entity Converted to Table",{"@odata.context"}),
                        #"Entity Expanded value" = Table.ExpandListColumn(#"Entity Removed Columns", "value"),
                        Output_Source_Entity = Table.ExpandRecordColumn(#"Entity Expanded value", "value",{"COD_AZIENDA","RAGIONE_SOCIALE","SEDE_LEGALE","SEDE_AMMINISTRATIVA","COD_VALUTA","ATTRIBUTO1","ATTRIBUTO2","ATTRIBUTO3","ATTRIBUTO4","ATTRIBUTO5","DESC_AZIENDA0","DESC_AZIENDA1","DESC_AZIENDA2","DESC_AZIENDA3","SEDE_PRINCIPALE"})
                    in 
                        Output_Source_Entity
            ]
        ),
    #"AW_Entity Duplicated Column" = Table.DuplicateColumn(AW_Output_Source_Entity, "COD_AZIENDA", "TGK_ENTITY_KEY"),
    #"AW_Entity Duplicated Column1" = Table.DuplicateColumn(#"AW_Entity Duplicated Column" , "COD_AZIENDA", "TGK_ENTITY_H_KEY"),
    #"AW_Entity Distinct" = Table.Distinct(#"AW_Entity Duplicated Column1","COD_AZIENDA"), 
    AW_Entity = Table.RenameColumns(#"AW_Entity Distinct",{{"COD_AZIENDA", "Entity Code"}, {"RAGIONE_SOCIALE", "Entity Business Name"}, {"SEDE_LEGALE", "Entity Legal Site"}, {"SEDE_AMMINISTRATIVA", "Entity Administrative Headquarters"}, {"COD_VALUTA", "Entity Currency Code"}, {"ATTRIBUTO1", "Entity Attribute 1"}, {"ATTRIBUTO2", "Entity Attribute 2"}, {"ATTRIBUTO3", "Entity Attribute 3"}, {"ATTRIBUTO4", "Entity Attribute 4"}, {"ATTRIBUTO5", "Entity Attribute 5"}, {"DESC_AZIENDA0", "Entity Description"}, {"DESC_AZIENDA1", "Entity Description 1"}, {"DESC_AZIENDA2", "Entity Description 2"}, {"DESC_AZIENDA3", "Entity Description 3"}, {"SEDE_PRINCIPALE", "Entity Headquarter"}})
    ,
    //AIH Entity Hierarchy
     AW_Output_Source_Entity_H =
    Table.View(null,
        [
            GetType = () =>
            type table [
                COD_AZIENDA_GERARCHIA = Text.Type,
                DESC_AZIENDA_GERARCHIA = Text.Type,
                COD_AZIENDA_ELEGER1 = Text.Type,
                DESC_AZIENDA_ELEGER1 = Text.Type,
                COD_AZIENDA_ELEGER2 = Text.Type,
                DESC_AZIENDA_ELEGER2 = Text.Type,
                COD_AZIENDA_ELEGER3 = Text.Type,
                DESC_AZIENDA_ELEGER3 = Text.Type,
                COD_AZIENDA_ELEGER4 = Text.Type,
                DESC_AZIENDA_ELEGER4 = Text.Type,
                COD_AZIENDA_ELEGER5 = Text.Type,
                DESC_AZIENDA_ELEGER5 = Text.Type,
                COD_AZIENDA_ELEGER6 = Text.Type,
                DESC_AZIENDA_ELEGER6 = Text.Type,
                COD_AZIENDA_ELEGER7 = Text.Type,
                DESC_AZIENDA_ELEGER7 = Text.Type,
                COD_AZIENDA_ELEGER8 = Text.Type,
                DESC_AZIENDA_ELEGER8 = Text.Type,
                COD_AZIENDA_KEY = Text.Type
            ],
            GetRows = () =>
                let 
                    Source_Entity_H = Json.Document(Web.Contents(outputURL &"Datasource_AW9994()?$filter=D in "& filterDatasetList,[Timeout=#duration(0,0,30,0)])),
                    #"Entity_H Converted to Table" = Table.FromRecords({Source_Entity_H}),
                    #"Entity_H Removed Columns" = Table.RemoveColumns(#"Entity_H Converted to Table",{"@odata.context"}),
                    #"Entity_H Expanded value" = Table.ExpandListColumn(#"Entity_H Removed Columns", "value"),
                    Output_Source_Entity_H = Table.ExpandRecordColumn(#"Entity_H Expanded value", "value",{ "COD_AZIENDA_GERARCHIA","DESC_AZIENDA_GERARCHIA", "COD_AZIENDA_ELEGER1", "DESC_AZIENDA_ELEGER1", "COD_AZIENDA_ELEGER2", "DESC_AZIENDA_ELEGER2", "COD_AZIENDA_ELEGER3", "DESC_AZIENDA_ELEGER3", "COD_AZIENDA_ELEGER4", "DESC_AZIENDA_ELEGER4", "COD_AZIENDA_ELEGER5", "DESC_AZIENDA_ELEGER5", "COD_AZIENDA_ELEGER6", "DESC_AZIENDA_ELEGER6", "COD_AZIENDA_ELEGER7", "DESC_AZIENDA_ELEGER7", "COD_AZIENDA_ELEGER8", "DESC_AZIENDA_ELEGER8","COD_AZIENDA_KEY"})
                in 
                    Output_Source_Entity_H
        ]
    ),
    #"AW_Entity_H Added Key" = Table.AddColumn(AW_Output_Source_Entity_H, "hierarchy_key", each [COD_AZIENDA_GERARCHIA] & [COD_AZIENDA_KEY]),
    #"AW_Entity_H Distinct" = Table.Distinct(#"AW_Entity_H Added Key", "hierarchy_key"),
    #"AW_Entity_H Rename Columns" = Table.RenameColumns(#"AW_Entity_H Distinct",{{"COD_AZIENDA_GERARCHIA", "Entity Hierarchy Code"}, {"DESC_AZIENDA_GERARCHIA", "Entity Hierarchy Description"}, {"COD_AZIENDA_ELEGER1", "Entity Hierarchy Code Level 1"}, {"COD_AZIENDA_ELEGER2", "Entity Hierarchy Code Level 2"}, {"COD_AZIENDA_ELEGER3", "Entity Hierarchy Code Level 3"}, {"COD_AZIENDA_ELEGER4", "Entity Hierarchy Code Level 4"}, {"COD_AZIENDA_ELEGER5", "Entity Hierarchy Code Level 5"}, {"COD_AZIENDA_ELEGER6", "Entity Hierarchy Code Level 6"}, {"COD_AZIENDA_ELEGER7", "Entity Hierarchy Code Level 7"}, {"COD_AZIENDA_ELEGER8", "Entity Hierarchy Code Level 8"}, {"DESC_AZIENDA_ELEGER1", "Entity Hierarchy Description Level 1"}, {"DESC_AZIENDA_ELEGER2", "Entity Hierarchy Description Level 2"}, {"DESC_AZIENDA_ELEGER3", "Entity Hierarchy Description Level 3"}, {"DESC_AZIENDA_ELEGER4", "Entity Hierarchy Description Level 4"}, {"DESC_AZIENDA_ELEGER5", "Entity Hierarchy Description Level 5"}, {"DESC_AZIENDA_ELEGER6", "Entity Hierarchy Description Level 6"}, {"DESC_AZIENDA_ELEGER7", "Entity Hierarchy Description Level 7"}, {"DESC_AZIENDA_ELEGER8", "Entity Hierarchy Description Level 8"},  {"COD_AZIENDA_KEY", "TGK_ENTITY_H_KEY"}}),
    AW_Entity_H = Table.RemoveColumns(#"AW_Entity_H Rename Columns",{"hierarchy_key"})
	,
    //AIH Entity CTP
    AW_Source_Entity_CTP = Table.SelectColumns(AW_Entity,{"Entity Code","Entity Business Name", "Entity Legal Site", "Entity Administrative Headquarters","Entity Currency Code", "Entity Attribute 1", "Entity Attribute 2", "Entity Attribute 3", "Entity Attribute 4", "Entity Attribute 5", "Entity Description","Entity Description 1", "Entity Description 2", "Entity Description 3", "Entity Headquarter", "TGK_ENTITY_KEY","TGK_ENTITY_H_KEY"}),
    #"AW_Entity CTP Insert Row" = Table.InsertRows(AW_Source_Entity_CTP,0,{[Entity Code="$NET",Entity Business Name =null, Entity Legal Site=null, Entity Administrative Headquarters=null,Entity Currency Code=null, Entity Attribute 1=null, Entity Attribute 2=null, Entity Attribute 3=null, Entity Attribute 4=null, Entity Attribute 5=null, Entity Description="3rd party",Entity Description 1=null, Entity Description 2=null, Entity Description 3=null, Entity Headquarter=null, TGK_ENTITY_KEY="$NET",TGK_ENTITY_H_KEY="$NET"]}),
    AW_Entity_CTP = Table.RenameColumns( #"AW_Entity CTP Insert Row",{{"Entity Code", "Entity CTP Code"}, {"Entity Business Name", "Entity CTP Business Name"}, {"Entity Legal Site", "Entity CTP Legal Site"}, {"Entity Administrative Headquarters", "Entity CTP Administrative Headquarters"}, {"Entity Currency Code", "Entity CTP Currency Code"}, {"Entity Attribute 1", "Entity CTP Attribute 1"}, {"Entity Attribute 2", "Entity CTP Attribute 2"}, {"Entity Attribute 3", "Entity CTP Attribute 3"}, {"Entity Attribute 4", "Entity CTP Attribute 4"}, {"Entity Attribute 5", "Entity CTP Attribute 5"}, {"Entity Description", "Entity CTP Description"}, {"Entity Description 1", "Entity CTP Description 1"}, {"Entity Description 2", "Entity CTP Description 2"}, {"Entity Description 3", "Entity CTP Description 3"}, {"Entity Headquarter", "Entity CTP Headquarter"}, {"TGK_ENTITY_KEY", "TGK_ENTITY_CTP_KEY"},{"TGK_ENTITY_H_KEY", "TGK_ENTITY_CTP_H_KEY"}})
    ,
   //AIH Entity CTP Hierarchy
	AW_Source_Entity_CTP_H = Table.SelectColumns(AW_Entity_H,{"Entity Hierarchy Code", "Entity Hierarchy Description", "Entity Hierarchy Code Level 1", "Entity Hierarchy Code Level 2", "Entity Hierarchy Code Level 3", "Entity Hierarchy Code Level 4", "Entity Hierarchy Code Level 5", "Entity Hierarchy Code Level 6", "Entity Hierarchy Code Level 7", "Entity Hierarchy Code Level 8", "Entity Hierarchy Description Level 1","Entity Hierarchy Description Level 2", "Entity Hierarchy Description Level 3", "Entity Hierarchy Description Level 4", "Entity Hierarchy Description Level 5", "Entity Hierarchy Description Level 6", "Entity Hierarchy Description Level 7", "Entity Hierarchy Description Level 8","TGK_ENTITY_H_KEY"}),  
    #"AW_Entity CTP H Transform Description" = Table.TransformColumns(AW_Source_Entity_CTP_H, {{"Entity Hierarchy Description",each Text.Combine({(_), " Counterparty"})},{"Entity Hierarchy Description Level 8",each Text.Combine({(_), " Counterparty"})}}),
    #"AW_Entity CTP H Hierarchy List" = Table.Distinct(Table.SelectColumns(#"AW_Entity CTP H Transform Description",{"Entity Hierarchy Code","Entity Hierarchy Description","Entity Hierarchy Code Level 8","Entity Hierarchy Description Level 8"})),
    #"AW_Entity CTP H Added 3rd party" = Table.AddColumn( #"AW_Entity CTP H Hierarchy List", "Entity Hierarchy Code Level 7", each "[$NET]"),
    #"AW_Entity CTP H Added 3rd party key" = Table.AddColumn( #"AW_Entity CTP H Added 3rd party" , "TGK_ENTITY_H_KEY", each "$NET"),
    #"AW_Entity CTP H Added 3rd party Description" = Table.AddColumn(  #"AW_Entity CTP H Added 3rd party key", "Entity Hierarchy Description Level 7", each "[$NET - 3rd party]"),
    #"AW_Entity CTP H Appended Query" = Table.Combine({#"AW_Entity CTP H Transform Description", #"AW_Entity CTP H Added 3rd party Description"}),  
    #"AW_Entity CTP H RenameColumns"  = Table.RenameColumns(if Record.Field(Table.First(AW_Entity_H), "Entity Hierarchy Code")= null then AW_Source_Entity_CTP_H else #"AW_Entity CTP H Appended Query",{{"Entity Hierarchy Code", "Entity CTP Hierarchy Code"}, {"Entity Hierarchy Description", "Entity CTP Hierarchy Description"}, {"Entity Hierarchy Code Level 1", "Entity CTP Hierarchy Code Level 1"}, {"Entity Hierarchy Code Level 2", "Entity CTP Hierarchy Code Level 2"}, {"Entity Hierarchy Code Level 3", "Entity CTP Hierarchy Code Level 3"}, {"Entity Hierarchy Code Level 4", "Entity CTP Hierarchy Code Level 4"}, {"Entity Hierarchy Code Level 5", "Entity CTP Hierarchy Code Level 5"}, {"Entity Hierarchy Code Level 6", "Entity CTP Hierarchy Code Level 6"}, {"Entity Hierarchy Code Level 7", "Entity CTP Hierarchy Code Level 7"}, {"Entity Hierarchy Code Level 8", "Entity CTP Hierarchy Code Level 8"}, {"Entity Hierarchy Description Level 1", "Entity CTP Hierarchy Description Level 1"}, {"Entity Hierarchy Description Level 2", "Entity CTP Hierarchy Description Level 2"}, {"Entity Hierarchy Description Level 3", "Entity CTP Hierarchy Description Level 3"}, {"Entity Hierarchy Description Level 4", "Entity CTP Hierarchy Description Level 4"}, {"Entity Hierarchy Description Level 5", "Entity CTP Hierarchy Description Level 5"}, {"Entity Hierarchy Description Level 6", "Entity CTP Hierarchy Description Level 6"}, {"Entity Hierarchy Description Level 7", "Entity CTP Hierarchy Description Level 7"}, {"Entity Hierarchy Description Level 8", "Entity CTP Hierarchy Description Level 8"}, {"TGK_ENTITY_H_KEY", "TGK_ENTITY_CTP_H_KEY"}}),
    AW_Entity_CTP_H = Table.TransformColumnTypes(  #"AW_Entity CTP H RenameColumns"  ,{{"TGK_ENTITY_CTP_H_KEY", type text},  {"Entity CTP Hierarchy Description Level 8", type text}, {"Entity CTP Hierarchy Description Level 7", type text}, {"Entity CTP Hierarchy Code Level 7", type text}, {"Entity CTP Hierarchy Description", type text}})
    ,
	//AIH Period
    AW_Output_Source_Period=
    Table.View(null,
            [
                GetType = () =>
                       type table [
                                COD_PERIODO = Text.Type,
                                DESC_PERIODO0 = Text.Type,
                                DESC_PERIODO1 = Text.Type,
                                DESC_PERIODO2 = Text.Type,
                                DESC_PERIODO3 = Text.Type,
                                DESC_MESE0 = Text.Type,
                                DESC_MESE1 = Text.Type,
                                DESC_MESE2 = Text.Type,
                                DESC_MESE3 = Text.Type,
                                DESC_TRIMESTRE0 = Text.Type,
                                DESC_TRIMESTRE1 = Text.Type,
                                DESC_TRIMESTRE2 = Text.Type,
                                DESC_TRIMESTRE3 = Text.Type,
                                DESC_QUADRIMESTRE0 = Text.Type,
                                DESC_QUADRIMESTRE1 = Text.Type,
                                DESC_QUADRIMESTRE2 = Text.Type,
                                DESC_QUADRIMESTRE3 = Text.Type,
                                DESC_SEMESTRE0 = Text.Type,
                                DESC_SEMESTRE1 = Text.Type,
                                DESC_SEMESTRE2 = Text.Type,
                                DESC_SEMESTRE3 = Text.Type,
                                DESC_NUM_PERIODO = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Period = Json.Document(Web.Contents(outputURL &"Datasource_000020()" ,[Timeout=#duration(0,0,30,0)])),
                        #"Period Converted to Table" = Table.FromRecords({Source_Period}),
                        #"Period Removed Columns" = Table.RemoveColumns(#"Period Converted to Table",{"@odata.context"}),
                        #"Period Expanded value" = Table.ExpandListColumn(#"Period Removed Columns", "value"),
                        Output_Source_Period = Table.ExpandRecordColumn(#"Period Expanded value", "value",{"COD_PERIODO","DESC_PERIODO0","DESC_PERIODO1","DESC_PERIODO2","DESC_PERIODO3","DESC_MESE0","DESC_MESE1","DESC_MESE2","DESC_MESE3","DESC_TRIMESTRE0","DESC_TRIMESTRE1","DESC_TRIMESTRE2","DESC_TRIMESTRE3","DESC_QUADRIMESTRE0","DESC_QUADRIMESTRE1","DESC_QUADRIMESTRE2","DESC_QUADRIMESTRE3","DESC_SEMESTRE0","DESC_SEMESTRE1","DESC_SEMESTRE2","DESC_SEMESTRE3","DESC_NUM_PERIODO"})
                    in 
                        Output_Source_Period
            ]
        ),
    #"AW_Period Duplicated Column" = Table.DuplicateColumn(AW_Output_Source_Period, "COD_PERIODO", "Period Num"),
    #"AW_Period ChangeType2" = Table.TransformColumnTypes(#"AW_Period Duplicated Column",{{"Period Num", Int64.Type}}),
    #"AW_Period Duplicated Column1" = Table.DuplicateColumn( #"AW_Period ChangeType2", "COD_PERIODO", "TGK_PERIOD_KEY"),
    AW_Period = Table.RenameColumns(#"AW_Period Duplicated Column1",{{"COD_PERIODO", "Period Code"}, {"DESC_PERIODO0", "Period Description"}, {"DESC_PERIODO1", "Period Description 1"}, {"DESC_PERIODO2", "Period Description 2"}, {"DESC_PERIODO3", "Period Description 3"}, {"DESC_MESE0", "Month Description"}, {"DESC_MESE1", "Month Description 1"}, {"DESC_MESE2", "Month Description 2"}, {"DESC_MESE3", "Month Description 3"}, {"DESC_TRIMESTRE0", "Quarter Description"}, {"DESC_TRIMESTRE1", "Quarter Description 1"}, {"DESC_TRIMESTRE2", "Quarter Description 2"}, {"DESC_TRIMESTRE3", "Quarter Description 3"}, {"DESC_QUADRIMESTRE0", "Four months Description"}, {"DESC_QUADRIMESTRE1", "Four months Description 1"}, {"DESC_QUADRIMESTRE2", "Four months Description 2"}, {"DESC_QUADRIMESTRE3", "Four months Description 3"}, {"DESC_SEMESTRE0", "Half Year Description"}, {"DESC_SEMESTRE1", "Half Year Description 1"}, {"DESC_SEMESTRE2", "Half Year Description 2"}, {"DESC_SEMESTRE3", "Half Year Description 3"}, {"DESC_NUM_PERIODO", "Period Number"}})
    ,
    //AIH Scenario
    AW_Output_Source_Scenario=
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_SCENARIO = Text.Type,
						TIPO_SCENARIO = Text.Type,
						COD_SCENARIO_ORIGINARIO = Text.Type,
						DESC_SCENARIO = Text.Type,
						COD_SCENARIO_PREC = Text.Type,
						COD_SCENARIO_SUCC = Text.Type,
						COD_SCENARIO_RIF1 = Text.Type,
						COD_SCENARIO_RIF2 = Text.Type,
						COD_SCENARIO_RIF3 = Text.Type,
						COD_SCENARIO_RIF4 = Text.Type,
						COD_SCENARIO_RIF5 = Text.Type,
						COD_VALUTA = Text.Type,
						COD_ESERCIZIO = Text.Type,
						DESC_VERSIONE = Text.Type,
						COD_SCENARIO_RIF_CAMBI = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Scenario = Json.Document(Web.Contents(outputURL &"Datasource_AW9997()?$filter=D in "& filterDatasetList,[Timeout=#duration(0,0,30,0)])),
                        #"Scenario Converted to Table" = Table.FromRecords({Source_Scenario}),
                        #"Scenario Removed Columns" = Table.RemoveColumns(#"Scenario Converted to Table",{"@odata.context"}),
                        #"Scenario Expanded value" = Table.ExpandListColumn(#"Scenario Removed Columns", "value"),
                        Output_Source_Scenario = Table.ExpandRecordColumn(#"Scenario Expanded value", "value",{"COD_SCENARIO", "TIPO_SCENARIO", "COD_SCENARIO_ORIGINARIO", "DESC_SCENARIO", "COD_SCENARIO_PREC", "COD_SCENARIO_SUCC", "COD_SCENARIO_RIF1", "COD_SCENARIO_RIF2", "COD_SCENARIO_RIF3", "COD_SCENARIO_RIF4", "COD_SCENARIO_RIF5", "COD_VALUTA", "COD_ESERCIZIO", "DESC_VERSIONE","COD_SCENARIO_RIF_CAMBI"})
                    in 
                        Output_Source_Scenario
            ]
        ),
    #"AW_Scenario Duplicated Column" = Table.DuplicateColumn(AW_Output_Source_Scenario, "COD_SCENARIO", "TGK_SCENARIO_KEY"),
    #"AW_Scenario Duplicated Column1" = Table.DuplicateColumn(#"AW_Scenario Duplicated Column", "COD_SCENARIO", "TGK_SCENARIO_H_KEY"),
    #"AW_Scenario Distinct" = Table.Distinct(#"AW_Scenario Duplicated Column1","COD_SCENARIO"), 
    AW_Scenario = Table.RenameColumns(#"AW_Scenario Distinct",{{"COD_SCENARIO", "Scenario Code"}, {"TIPO_SCENARIO", "Scenario Type"}, {"COD_SCENARIO_ORIGINARIO", "Original Scenario"}, {"DESC_SCENARIO", "Scenario Description"}, {"COD_SCENARIO_PREC", "Previous Scenario"}, {"COD_SCENARIO_SUCC", "Following Scenario"}, {"COD_SCENARIO_RIF1", "Reference Scenario 1"}, {"COD_SCENARIO_RIF2", "Reference Scenario 2"}, {"COD_SCENARIO_RIF3", "Reference Scenario 3"}, {"COD_SCENARIO_RIF4", "Reference Scenario 4"}, {"COD_SCENARIO_RIF5", "Reference Scenario 5"}, {"COD_VALUTA", "Scenario Currency"}, {"COD_ESERCIZIO", "Scenario Year"}, {"DESC_VERSIONE", "Version Description"}, {"COD_SCENARIO_RIF_CAMBI", "Ref. FX Rate Scenario"}})
    ,
    //AIH Scenario Grouping
    AW_Output_Source_Scenario_G =
    Table.View(null,
            [
                GetType = () =>
                       type table [
						COD_SCENARIO_GERARCHIA = Text.Type,
                        DESC_SCENARIO_GERARCHIA = Text.Type,
                        COD_SCENARIO_ELEGER1 = Text.Type,
                        DESC_SCENARIO_ELEGER1 = Text.Type,
                        COD_SCENARIO_ELEGER2 = Text.Type,
                        DESC_SCENARIO_ELEGER2 = Text.Type,
                        COD_SCENARIO_ELEGER3 = Text.Type,
                        DESC_SCENARIO_ELEGER3 = Text.Type,
                        COD_SCENARIO_ELEGER4 = Text.Type,
                        DESC_SCENARIO_ELEGER4 = Text.Type,
                        COD_SCENARIO_ELEGER5 = Text.Type,
                        DESC_SCENARIO_ELEGER5 = Text.Type,
                        COD_SCENARIO_ELEGER6 = Text.Type,
                        DESC_SCENARIO_ELEGER6 = Text.Type,
                        COD_SCENARIO_ELEGER7 = Text.Type,
                        DESC_SCENARIO_ELEGER7 = Text.Type,
                        COD_SCENARIO_ELEGER8 = Text.Type,
                        DESC_SCENARIO_ELEGER8 = Text.Type,
                        COD_SCENARIO_KEY = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_Scenario_G = Json.Document(Web.Contents(outputURL &"Datasource_AW9996()?$filter=D in "& filterDatasetList,[Timeout=#duration(0,0,30,0)])),
                        #"Scenario_G Converted to Table" = Table.FromRecords({Source_Scenario_G}),
                        #"Scenario_G Removed Columns" = Table.RemoveColumns(#"Scenario_G Converted to Table",{"@odata.context"}),
                        #"Scenario_G Expanded value" = Table.ExpandListColumn(#"Scenario_G Removed Columns", "value"),
                        #"Scenario_G Expanded record" = Table.ExpandRecordColumn(#"Scenario_G Expanded value", "value",{"COD_SCENARIO_GERARCHIA","DESC_SCENARIO_GERARCHIA","COD_SCENARIO_ELEGER1","DESC_SCENARIO_ELEGER1","COD_SCENARIO_ELEGER2","DESC_SCENARIO_ELEGER2","COD_SCENARIO_ELEGER3","DESC_SCENARIO_ELEGER3","COD_SCENARIO_ELEGER4","DESC_SCENARIO_ELEGER4","COD_SCENARIO_ELEGER5","DESC_SCENARIO_ELEGER5","COD_SCENARIO_ELEGER6","DESC_SCENARIO_ELEGER6","COD_SCENARIO_ELEGER7","DESC_SCENARIO_ELEGER7","COD_SCENARIO_ELEGER8","DESC_SCENARIO_ELEGER8","COD_SCENARIO_KEY"}),
                        Output_Source_Scenario_G = Table.TransformColumns(#"Scenario_G Expanded record", {
                            {"COD_SCENARIO_ELEGER8", each if _ = null then "" else _},
                            {"DESC_SCENARIO_GERARCHIA", each if _ = null then "" else _},
                            {"DESC_SCENARIO_ELEGER8", each if _ = null then "" else _},
                            {"COD_SCENARIO_GERARCHIA", each if _ = null then "" else _},
                            {"COD_SCENARIO_ELEGER1", each if _ = null then "" else _},
                            {"DESC_SCENARIO_ELEGER1", each if _ = null then "" else _},
                            {"COD_SCENARIO_ELEGER2", each if _ = null then "" else _},
                            {"DESC_SCENARIO_ELEGER2", each if _ = null then "" else _},
                            {"COD_SCENARIO_ELEGER3", each if _ = null then "" else _},
                            {"DESC_SCENARIO_ELEGER3", each if _ = null then "" else _},
                            {"COD_SCENARIO_ELEGER4", each if _ = null then "" else _},
                            {"DESC_SCENARIO_ELEGER4", each if _ = null then "" else _},
                            {"COD_SCENARIO_ELEGER5", each if _ = null then "" else _},
                            {"DESC_SCENARIO_ELEGER5", each if _ = null then "" else _},
                            {"COD_SCENARIO_ELEGER6", each if _ = null then "" else _},
                            {"DESC_SCENARIO_ELEGER6", each if _ = null then "" else _},
                            {"COD_SCENARIO_ELEGER7", each if _ = null then "" else _},
                            {"DESC_SCENARIO_ELEGER7", each if _ = null then "" else _},
                            {"COD_SCENARIO_KEY", each if _ = null then "" else _}
                        })
                    in 
                        Output_Source_Scenario_G
            ]
        ),
    #"AW_Scenario_G Added Key" = Table.AddColumn(AW_Output_Source_Scenario_G, "hierarchy_key", 
    each 
        [COD_SCENARIO_GERARCHIA] & 
        [COD_SCENARIO_ELEGER1] & 
        [COD_SCENARIO_ELEGER2] & 
        [COD_SCENARIO_ELEGER3] & 
        [COD_SCENARIO_ELEGER4] & 
        [COD_SCENARIO_ELEGER5] & 
        [COD_SCENARIO_ELEGER6] & 
        [COD_SCENARIO_ELEGER7] & 
        [COD_SCENARIO_ELEGER8] &
        [COD_SCENARIO_KEY]
),
    #"AW_Scenario_G Distinct" = Table.Distinct( #"AW_Scenario_G Added Key" ,"hierarchy_key"),
    #"AW_Scenario_G Removed Columns" = Table.RemoveColumns(#"AW_Scenario_G Distinct",{"hierarchy_key"}), 
    AW_Scenario_G  = Table.RenameColumns(#"AW_Scenario_G Removed Columns",{{"COD_SCENARIO_GERARCHIA", "Scenario Grouping Code"}, {"DESC_SCENARIO_GERARCHIA", "Scenario Grouping Description"}, {"COD_SCENARIO_ELEGER1", "Scenario Grouping Code Level 1"}, {"COD_SCENARIO_ELEGER2", "Scenario Grouping Code Level 2"}, {"COD_SCENARIO_ELEGER3", "Scenario Grouping Code Level 3"}, {"COD_SCENARIO_ELEGER4", "Scenario Grouping Code Level 4"}, {"COD_SCENARIO_ELEGER5", "Scenario Grouping Code Level 5"}, {"COD_SCENARIO_ELEGER6", "Scenario Grouping Code Level 6"}, {"COD_SCENARIO_ELEGER7", "Scenario Grouping Code Level 7"}, {"COD_SCENARIO_ELEGER8", "Scenario Grouping Code Level 8"}, {"DESC_SCENARIO_ELEGER1", "Scenario Grouping Description Level 1"}, {"DESC_SCENARIO_ELEGER2", "Scenario Grouping Description Level 2"}, {"DESC_SCENARIO_ELEGER3", "Scenario Grouping Description Level 3"}, {"DESC_SCENARIO_ELEGER4", "Scenario Grouping Description Level 4"}, {"DESC_SCENARIO_ELEGER5", "Scenario Grouping Description Level 5"}, {"DESC_SCENARIO_ELEGER6", "Scenario Grouping Description Level 6"}, {"DESC_SCENARIO_ELEGER7", "Scenario Grouping Description Level 7"}, {"DESC_SCENARIO_ELEGER8", "Scenario Grouping Description Level 8"}, {"COD_SCENARIO_KEY", "TGK_SCENARIO_H_KEY"}})
    ,
    
    //AIH Transaction Currency
     AW_Output_Source_TransactionCurrency =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_VALUTA = Text.Type,
                        DESC_VALUTA = Text.Type,
                        PERC_SCOSTAMENTO = Number.Type,
                        COD_VALUTA1 = Text.Type,
                        COD_VALUTA2 = Text.Type,
                        NUM_DECIMALI = Number.Type,
                        COD_VALUTA_RIF = Text.Type,
                        COEFFICIENTE_RIF = Number.Type,
                        MEASURE_XBRL = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_TransactionCurrency = Json.Document(Web.Contents(outputURL &"Datasource_000025()" ,[Timeout=#duration(0,0,30,0)])),
                        #"TransactionCurrency Converted to Table" = Table.FromRecords({Source_TransactionCurrency}),
                        #"TransactionCurrency Removed Columns" = Table.RemoveColumns(#"TransactionCurrency Converted to Table",{"@odata.context"}),
                        #"TransactionCurrency Expanded value" = Table.ExpandListColumn(#"TransactionCurrency Removed Columns", "value"),
                        Output_Source_TransactionCurrency = Table.ExpandRecordColumn(#"TransactionCurrency Expanded value", "value",{"COD_VALUTA","DESC_VALUTA","PERC_SCOSTAMENTO","COD_VALUTA1","COD_VALUTA2","NUM_DECIMALI","COD_VALUTA_RIF","COEFFICIENTE_RIF","MEASURE_XBRL"})
                    in 
                        Output_Source_TransactionCurrency
            ]
        ),
    #"AW_Transaction Currency Duplicated Column" = Table.DuplicateColumn(AW_Output_Source_TransactionCurrency, "COD_VALUTA", "TGK_TRANSACTION_CURRENCY_KEY"),
    AW_TransactionCurrency = Table.RenameColumns(#"AW_Transaction Currency Duplicated Column" ,{{"COD_VALUTA", "Transaction Currency Code"}, {"DESC_VALUTA", "Transaction Currency Description"}, {"PERC_SCOSTAMENTO", "Transaction Currency Variance Perc"}, {"COD_VALUTA1", "Transaction Currency Code 1"}, {"COD_VALUTA2", "Transaction Currency Code 2"}, {"NUM_DECIMALI", "Transaction Currency Decimal Numbers"}, {"COD_VALUTA_RIF", "Transaction Currency Ref Code"}, {"COEFFICIENTE_RIF", "Transaction Currency Ref Coefficient"}, {"MEASURE_XBRL", "Transaction Currency XBRL Measure"}})
    ,
    
    AW_ListDimFinancial = Table.FromRecords({
        [DimensionName = "Account", DimensionTable = AW_Account],
        [DimensionName = "Account Hierarchy", DimensionTable = AW_Account_H],
        [DimensionName = "Category", DimensionTable = AW_Category],
        [DimensionName = "Category Grouping", DimensionTable = AW_Category_G],
        [DimensionName = "Custom Dimension 1", DimensionTable = AW_CustomDimension1],
        [DimensionName = "Custom Dimension 2 CTP", DimensionTable = AW_CustomDimension2_CTP],
        [DimensionName = "Custom Dimension 2 CTP Hierarchy", DimensionTable = AW_CustomDimension2_CTP_H],
//         [DimensionName = "Custom Dimension 2 Segment", DimensionTable = CustomDimension2_Segment],
//         [DimensionName = "Custom Dimension 2 Segment Hierarchy", DimensionTable = CustomDimension2_Segment_H],
        [DimensionName = "Custom Dimension 2", DimensionTable = AW_CustomDimension2],
        [DimensionName = "Custom Dimension 3", DimensionTable = AW_CustomDimension3],
        [DimensionName = "Custom Dimension 4", DimensionTable = AW_CustomDimension4],
        [DimensionName = "Custom Dimension 5", DimensionTable = AW_CustomDimension5],
        [DimensionName = "Custom Dimension 1 Hierarchy", DimensionTable = AW_CustomDimension1_H],
        [DimensionName = "Custom Dimension 2 Hierarchy", DimensionTable = AW_CustomDimension2_H],
        [DimensionName = "Custom Dimension 3 Hierarchy", DimensionTable = AW_CustomDimension3_H],
        [DimensionName = "Custom Dimension 4 Hierarchy", DimensionTable = AW_CustomDimension4_H],
        [DimensionName = "Custom Dimension 5 Hierarchy", DimensionTable = AW_CustomDimension5_H],
        [DimensionName = "Entity", DimensionTable = AW_Entity],
        [DimensionName = "Entity Hierarchy", DimensionTable = AW_Entity_H],
        [DimensionName = "Entity CTP", DimensionTable = AW_Entity_CTP],
        [DimensionName = "Entity CTP Hierarchy", DimensionTable = AW_Entity_CTP_H],
        [DimensionName = "Period", DimensionTable = AW_Period],
//         [DimensionName = "Period Length", DimensionTable = PeriodLength],
//         [DimensionName = "Periodic Value Calculation", DimensionTable = PeriodicValueCalculation],
        [DimensionName = "Scenario", DimensionTable = AW_Scenario],
        [DimensionName = "Scenario Grouping", DimensionTable = AW_Scenario_G],
//         [DimensionName = "Scenario Period", DimensionTable = ScenarioPeriod],
//         [DimensionName = "Target Currency", DimensionTable = TargetCurrency],
        [DimensionName = "Transaction Currency", DimensionTable = AW_TransactionCurrency]
    }),

    OutputFinancialDimensions =  Table.SelectRows(AW_ListDimFinancial, each List.Contains(dimensionList, [DimensionName]))
in
    OutputFinancialDimensions;

CreateAnalyticalDimensionHierarchy=(outputURL as text, Dimension as text,DimensionName as text) =>
let
    Output_Dimension_H =
    Table.View(null,
        [
            GetType = () =>
                   type table [
                    CG = Text.Type,
                    DG = Text.Type,
                    C1 = Text.Type,
                    D1 = Text.Type,
                    C2 = Text.Type,
                    D2 = Text.Type,
                    C3 = Text.Type,
                    D3 = Text.Type,
                    C4 = Text.Type,
                    D4 = Text.Type,
                    C5 = Text.Type,
                    D5 = Text.Type,
                    C6 = Text.Type,
                    D6 = Text.Type,
                    C7 = Text.Type,
                    D7 = Text.Type,
                    C8 = Text.Type,
                    D8 = Text.Type,
                    CK = Text.Type
                ],
            GetRows = () =>
                let 
                    Source_Dimension_H = Json.Document(Web.Contents(outputURL &"Datasource_AW9998()?$filter=K eq '"& Dimension &"'")),
                    DimHColumnNames = {"CG","DG","C1","D1","C2","D2","C3","D3","C4","D4","C5","D5","C6","D6","C7","D7","C8","D8","CK"},
                    #"DimH Converted to Table" = Table.FromRecords({Source_Dimension_H}),
                    #"DimH Removed Columns" = Table.RemoveColumns(#"DimH Converted to Table",{"@odata.context"}),
                    #"DimH Expanded value" = Table.ExpandListColumn(#"DimH Removed Columns", "value"),
                    Output_Dimension_H = Table.ExpandRecordColumn(#"DimH Expanded value" , "value", DimHColumnNames)
                in 
                    Output_Dimension_H
        ]
    ),
    
    AWDimH = Table.RenameColumns(Output_Dimension_H,{{"CK", "TGK_" & Dimension & "_KEY"},{"CG", DimensionName & " Code"}, {"DG", DimensionName & " Description"},{"C1",DimensionName & " Code Level 1"},{"C2",DimensionName & " Code Level 2"},{"C3",DimensionName & " Code Level 3"},{"C4",DimensionName & " Code Level 4"},{"C5",DimensionName & " Code Level 5"},{"C6",DimensionName & " Code Level 6"},{"C7",DimensionName & " Code Level 7"},{"C8",DimensionName & " Code Level 8"},
    {"D1",DimensionName & " Description Level 1"},{"D2",DimensionName & " Description Level 2"},{"D3",DimensionName & " Description Level 3"},{"D4",DimensionName & " Description Level 4"},{"D5",DimensionName & " Description Level 5"},{"D6",DimensionName & " Description Level 6"},{"D7",DimensionName & " Description Level 7"},{"D8",DimensionName & " Description Level 8"} })
in
    AWDimH;

CreateUserRightsAnalyticalDimension = (outputURL as text, Dimension as text,Version) =>
let
    VersionCases = 
    {
        //Version, 
        {"1.0.0",AWUR_0},
        {"1.1.0",AWUR_1}
    },
        //Version 1.1.0   
    Output_SourceAWURDimension_1 =
    Table.View(null,
        [
            GetType = () =>
                   type table [
                    U = Text.Type,
                    D = Text.Type
                ],
            GetRows = () =>
                let 
                    Source_AWURDimension = Json.Document(Web.Contents(outputURL &"Datasource_AW9982()?$filter=N eq '"& Dimension &"'")),
                    #"AWUR Converted to Table" = Table.FromRecords({Source_AWURDimension}),
                    #"AWUR Removed Columns" = Table.RemoveColumns(#"AWUR Converted to Table",{"@odata.context"}),
                    #"AWUR Expanded value" = Table.ExpandListColumn(#"AWUR Removed Columns", "value"),
                    Output_SourceAWURDimension = Table.ExpandRecordColumn(#"AWUR Expanded value" , "value", {"U","D"})
                in 
                    Output_SourceAWURDimension
        ]
    ),
    AWUR_1 = Table.RenameColumns(Output_SourceAWURDimension_1, {{"D", "TGK_"& Dimension & "_UR_KEY"},{"U", "TGK_"& Dimension & "_UR_USERID"}})
    ,
//Version 1.0.0
    Output_SourceAWURDimension_0 =
    Table.View(null,
        [
            GetType = () =>
                   type table [
                    COD_UTENTE = Text.Type,
                    COD_DIM = Text.Type
                ],
            GetRows = () =>
                let 
                    Source_AWURDimension = Json.Document(Web.Contents(outputURL &"Datasource_AW9982()?$filter=NAME_DIM eq '"& Dimension &"'")),
                    #"AWUR Converted to Table" = Table.FromRecords({Source_AWURDimension}),
                    #"AWUR Removed Columns" = Table.RemoveColumns(#"AWUR Converted to Table",{"@odata.context"}),
                    #"AWUR Expanded value" = Table.ExpandListColumn(#"AWUR Removed Columns", "value"),
                    Output_SourceAWURDimension = Table.ExpandRecordColumn(#"AWUR Expanded value" , "value", {"COD_UTENTE","COD_DIM"})
                in 
                    Output_SourceAWURDimension
        ]
    ),
    AWUR_0 = Table.RenameColumns(Output_SourceAWURDimension_0, {{"COD_DIM", "TGK_"& Dimension & "_UR_KEY"},{"COD_UTENTE", "TGK_"& Dimension & "_UR_USERID"}})
    ,
    AWUR = List.First(List.Select(VersionCases, each _{0} = Version), null){1}
in
    AWUR
 ;

CreateUserRightsFinancialDimensionsAIH=(outputURL as text,Version as text, optional dimensionList as list) as table => 
let
    //AIH Financial User Rights

	VersionCases = 
    {
        //Version, 
        {"1.0.0",AW_UserRightsAccount_0,AW_UserRightsCategory_0,AW_UserRightsDest1_0,AW_UserRightsDest2_0,AW_UserRightsDest3_0,AW_UserRightsDest4_0,AW_UserRightsDest5_0,AW_UserRightsEntity_0,AW_UserRightsScenario_0},
        {"1.1.0",AW_UserRightsAccount_1,AW_UserRightsCategory_1,AW_UserRightsDest1_1,AW_UserRightsDest2_1,AW_UserRightsDest3_1,AW_UserRightsDest4_1,AW_UserRightsDest5_1,AW_UserRightsEntity_1,AW_UserRightsScenario_1}
    }
    ,
    //AIH User Rights Account
    //Version 1.1.0 
    AW_Output_Source_UserRightsAccount_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        U = Text.Type,
                        D = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsAccount = Json.Document(Web.Contents(outputURL &"Datasource_000037()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsAccount Converted to Table" = Table.FromRecords({Source_UserRightsAccount}),
                        #"UserRightsAccount Removed Columns" = Table.RemoveColumns(#"UserRightsAccount Converted to Table",{"@odata.context"}),
                        #"UserRightsAccount Expanded value" = Table.ExpandListColumn(#"UserRightsAccount Removed Columns", "value"),
                        Output_Source_UserRightsAccount = Table.ExpandRecordColumn(#"UserRightsAccount Expanded value", "value",{"U", "D"})
                    in 
                        Output_Source_UserRightsAccount
            ]
        ),
    AW_UserRightsAccount_1  = Table.RenameColumns(AW_Output_Source_UserRightsAccount_1,{{"D", "TGK_ACCOUNT_UR_KEY"}, {"U", "TGK_ACCOUNT_UR_USERID"}})
    ,
    //Version 1.0.0 
    AW_Output_Source_UserRightsAccount_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_UTENTE = Text.Type,
                        COD_CONTO = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsAccount = Json.Document(Web.Contents(outputURL &"Datasource_000037()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsAccount Converted to Table" = Table.FromRecords({Source_UserRightsAccount}),
                        #"UserRightsAccount Removed Columns" = Table.RemoveColumns(#"UserRightsAccount Converted to Table",{"@odata.context"}),
                        #"UserRightsAccount Expanded value" = Table.ExpandListColumn(#"UserRightsAccount Removed Columns", "value"),
                        Output_Source_UserRightsAccount = Table.ExpandRecordColumn(#"UserRightsAccount Expanded value", "value",{"COD_UTENTE", "COD_CONTO"})
                    in 
                        Output_Source_UserRightsAccount
            ]
        ),
    AW_UserRightsAccount_0  = Table.RenameColumns(AW_Output_Source_UserRightsAccount_0,{{"COD_CONTO", "TGK_ACCOUNT_UR_KEY"}, {"COD_UTENTE", "TGK_ACCOUNT_UR_USERID"}})
    ,
    AW_UserRightsAccount = List.First(List.Select(VersionCases, each _{0} = Version), null){1}
	,
    //AIH User Rights Category
        //Version 1.1.0 
    AW_Output_Source_UserRightsCategory_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        U = Text.Type,
                        D = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsCategory = Json.Document(Web.Contents(outputURL & "Datasource_AW9983()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsCategory Converted to Table" = Table.FromRecords({Source_UserRightsCategory}),
                        #"UserRightsCategory Removed Columns" = Table.RemoveColumns(#"UserRightsCategory Converted to Table",{"@odata.context"}),
                        #"UserRightsCategory Expanded value" = Table.ExpandListColumn(#"UserRightsCategory Removed Columns", "value"),
                        Output_Source_UserRightsCategory = Table.ExpandRecordColumn(#"UserRightsCategory Expanded value", "value",{"U", "D"})
                    in 
                        Output_Source_UserRightsCategory
            ]
        ),
    AW_UserRightsCategory_1  = Table.RenameColumns(AW_Output_Source_UserRightsCategory_1,{{"D", "TGK_CATEGORY_UR_KEY"}, {"U", "TGK_CATEGORY_UR_USERID"}})
    ,
    //Version 1.0.0 
    AW_Output_Source_UserRightsCategory_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_UTENTE = Text.Type,
                        COD_CATEGORIA = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsCategory = Json.Document(Web.Contents(outputURL & "Datasource_AW9983()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsCategory Converted to Table" = Table.FromRecords({Source_UserRightsCategory}),
                        #"UserRightsCategory Removed Columns" = Table.RemoveColumns(#"UserRightsCategory Converted to Table",{"@odata.context"}),
                        #"UserRightsCategory Expanded value" = Table.ExpandListColumn(#"UserRightsCategory Removed Columns", "value"),
                        Output_Source_UserRightsCategory = Table.ExpandRecordColumn(#"UserRightsCategory Expanded value", "value",{"COD_UTENTE", "COD_CATEGORIA"})
                    in 
                        Output_Source_UserRightsCategory
            ]
        ),
    AW_UserRightsCategory_0  = Table.RenameColumns(AW_Output_Source_UserRightsCategory_0,{{"COD_CATEGORIA", "TGK_CATEGORY_UR_KEY"}, {"COD_UTENTE", "TGK_CATEGORY_UR_USERID"}})
    ,
    AW_UserRightsCategory = List.First(List.Select(VersionCases, each _{0} = Version), null){2}
	,
	//AIH User Rights Custom Dimension 1
        //Version 1.1.0 
    AW_Output_Source_UserRightsDest1_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        U = Text.Type,
                        D = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest1 = Json.Document(Web.Contents(outputURL &"Datasource_000032()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest1 Converted to Table" = Table.FromRecords({Source_UserRightsDest1}),
                        #"UserRightsDest1 Removed Columns" = Table.RemoveColumns(#"UserRightsDest1 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest1 Expanded value" = Table.ExpandListColumn(#"UserRightsDest1 Removed Columns", "value"),
                        Output_Source_UserRightsDest1 = Table.ExpandRecordColumn(#"UserRightsDest1 Expanded value", "value",{"U", "D"})
                    in 
                        Output_Source_UserRightsDest1
            ]
        ),
    AW_UserRightsDest1_1  = Table.RenameColumns(AW_Output_Source_UserRightsDest1_1 ,{{"D", "TGK_DEST1_UR_KEY"}, {"U", "TGK_DEST1_UR_USERID"}})
    ,
    //Version 1.0.0 
    AW_Output_Source_UserRightsDest1_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_UTENTE = Text.Type,
                        COD_DEST1= Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest1 = Json.Document(Web.Contents(outputURL &"Datasource_000032()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest1 Converted to Table" = Table.FromRecords({Source_UserRightsDest1}),
                        #"UserRightsDest1 Removed Columns" = Table.RemoveColumns(#"UserRightsDest1 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest1 Expanded value" = Table.ExpandListColumn(#"UserRightsDest1 Removed Columns", "value"),
                        Output_Source_UserRightsDest1 = Table.ExpandRecordColumn(#"UserRightsDest1 Expanded value", "value",{"COD_UTENTE", "COD_DEST1"})
                    in 
                        Output_Source_UserRightsDest1
            ]
        ),
    AW_UserRightsDest1_0  = Table.RenameColumns(AW_Output_Source_UserRightsDest1_0,{{"COD_DEST1", "TGK_DEST1_UR_KEY"}, {"COD_UTENTE", "TGK_DEST1_UR_USERID"}})
    ,
    AW_UserRightsDest1 = List.First(List.Select(VersionCases, each _{0} = Version), null){3}
	,
    //AIH User Rights Custom Dimension 2
     //Version 1.1.0 
    AW_Output_Source_UserRightsDest2_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        U = Text.Type,
                        D = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest2 = Json.Document(Web.Contents(outputURL &"Datasource_000033()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest2 Converted to Table" = Table.FromRecords({Source_UserRightsDest2}),
                        #"UserRightsDest2 Removed Columns" = Table.RemoveColumns(#"UserRightsDest2 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest2 Expanded value" = Table.ExpandListColumn(#"UserRightsDest2 Removed Columns", "value"),
                        Output_Source_UserRightsDest2 = Table.ExpandRecordColumn(#"UserRightsDest2 Expanded value", "value",{"U", "D"})
                    in 
                        Output_Source_UserRightsDest2
            ]
        ),
    AW_UserRightsDest2_1  = Table.RenameColumns(AW_Output_Source_UserRightsDest2_1,{{"D", "TGK_DEST2_UR_KEY"}, {"U", "TGK_DEST2_UR_USERID"}})
    ,
    //Version 1.0.0 
    AW_Output_Source_UserRightsDest2_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_UTENTE = Text.Type,
                        COD_DEST2 = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest2 = Json.Document(Web.Contents(outputURL &"Datasource_000033()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest2 Converted to Table" = Table.FromRecords({Source_UserRightsDest2}),
                        #"UserRightsDest2 Removed Columns" = Table.RemoveColumns(#"UserRightsDest2 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest2 Expanded value" = Table.ExpandListColumn(#"UserRightsDest2 Removed Columns", "value"),
                        Output_Source_UserRightsDest2 = Table.ExpandRecordColumn(#"UserRightsDest2 Expanded value", "value",{"COD_UTENTE", "COD_DEST2"})
                    in 
                        Output_Source_UserRightsDest2
            ]
        ),
    AW_UserRightsDest2_0  = Table.RenameColumns(AW_Output_Source_UserRightsDest2_0,{{"COD_DEST2", "TGK_DEST2_UR_KEY"}, {"COD_UTENTE", "TGK_DEST2_UR_USERID"}})
    ,
    AW_UserRightsDest2 = List.First(List.Select(VersionCases, each _{0} = Version), null){4}
	,
    //AIH User Rights Custom Dimension 3
	//Version 1.1.0 
	AW_Output_Source_UserRightsDest3_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        U = Text.Type,
                        D = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest3 = Json.Document(Web.Contents(outputURL &"Datasource_000034()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest3 Converted to Table" = Table.FromRecords({Source_UserRightsDest3}),
                        #"UserRightsDest3 Removed Columns" = Table.RemoveColumns(#"UserRightsDest3 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest3 Expanded value" = Table.ExpandListColumn(#"UserRightsDest3 Removed Columns", "value"),
                        Output_Source_UserRightsDest3 = Table.ExpandRecordColumn(#"UserRightsDest3 Expanded value", "value",{"U", "D"})
                    in 
                        Output_Source_UserRightsDest3
            ]
        ),
    AW_UserRightsDest3_1  = Table.RenameColumns(AW_Output_Source_UserRightsDest3_1,{{"D", "TGK_DEST3_UR_KEY"}, {"U", "TGK_DEST3_UR_USERID"}})
    ,
    //Version 1.0.0 
    AW_Output_Source_UserRightsDest3_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_UTENTE = Text.Type,
                        COD_DEST3 = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest3 = Json.Document(Web.Contents(outputURL &"Datasource_000034()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest3 Converted to Table" = Table.FromRecords({Source_UserRightsDest3}),
                        #"UserRightsDest3 Removed Columns" = Table.RemoveColumns(#"UserRightsDest3 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest3 Expanded value" = Table.ExpandListColumn(#"UserRightsDest3 Removed Columns", "value"),
                        Output_Source_UserRightsDest3 = Table.ExpandRecordColumn(#"UserRightsDest3 Expanded value", "value",{"COD_UTENTE", "COD_DEST3"})
                    in 
                        Output_Source_UserRightsDest3
            ]
        ),
    AW_UserRightsDest3_0  = Table.RenameColumns(AW_Output_Source_UserRightsDest3_0,{{"COD_DEST3", "TGK_DEST3_UR_KEY"}, {"COD_UTENTE", "TGK_DEST3_UR_USERID"}})
    ,
    AW_UserRightsDest3 = List.First(List.Select(VersionCases, each _{0} = Version), null){5}
    ,
    //AIH User Rights Custom Dimension 4
    //Version 1.1.0 
    AW_Output_Source_UserRightsDest4_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        U = Text.Type,
                        D = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest4 = Json.Document(Web.Contents(outputURL &"Datasource_000035()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest4 Converted to Table" = Table.FromRecords({Source_UserRightsDest4}),
                        #"UserRightsDest4 Removed Columns" = Table.RemoveColumns(#"UserRightsDest4 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest4 Expanded value" = Table.ExpandListColumn(#"UserRightsDest4 Removed Columns", "value"),
                        Output_Source_UserRightsDest4 = Table.ExpandRecordColumn(#"UserRightsDest4 Expanded value", "value",{"U", "D"})
                    in 
                        Output_Source_UserRightsDest4
            ]
        ),
    AW_UserRightsDest4_1  = Table.RenameColumns(AW_Output_Source_UserRightsDest4_1,{{"D", "TGK_DEST4_UR_KEY"}, {"U", "TGK_DEST4_UR_USERID"}})
    ,
    //Version 1.0.0 
    AW_Output_Source_UserRightsDest4_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_UTENTE = Text.Type,
                        COD_DEST4 = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest4 = Json.Document(Web.Contents(outputURL &"Datasource_000035()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest4 Converted to Table" = Table.FromRecords({Source_UserRightsDest4}),
                        #"UserRightsDest4 Removed Columns" = Table.RemoveColumns(#"UserRightsDest4 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest4 Expanded value" = Table.ExpandListColumn(#"UserRightsDest4 Removed Columns", "value"),
                        Output_Source_UserRightsDest4 = Table.ExpandRecordColumn(#"UserRightsDest4 Expanded value", "value",{"COD_UTENTE", "COD_DEST4"})
                    in 
                        Output_Source_UserRightsDest4
            ]
        ),
    AW_UserRightsDest4_0  = Table.RenameColumns(AW_Output_Source_UserRightsDest4_0,{{"COD_DEST4", "TGK_DEST4_UR_KEY"}, {"COD_UTENTE", "TGK_DEST4_UR_USERID"}})
    ,
    AW_UserRightsDest4 = List.First(List.Select(VersionCases, each _{0} = Version), null){6}
	,
    //AIH User Rights Custom Dimension 5
        //Version 1.1.0 
    AW_Output_Source_UserRightsDest5_1 =
    Table.View(null,
            [
                GetType = () =>
                    type table [
                        U = Text.Type,
                        D = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest5 = Json.Document(Web.Contents(outputURL &"Datasource_000036()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest5 Converted to Table" = Table.FromRecords({Source_UserRightsDest5}),
                        #"UserRightsDest5 Removed Columns" = Table.RemoveColumns(#"UserRightsDest5 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest5 Expanded value" = Table.ExpandListColumn(#"UserRightsDest5 Removed Columns", "value"),
                        Output_Source_UserRightsDest5 = Table.ExpandRecordColumn(#"UserRightsDest5 Expanded value", "value",{"U", "D"})
                    in 
                        Output_Source_UserRightsDest5
            ]
        ),
    AW_UserRightsDest5_1  = Table.RenameColumns(AW_Output_Source_UserRightsDest5_1,{{"D", "TGK_DEST5_UR_KEY"}, {"U", "TGK_DEST5_UR_USERID"}})
    ,
    //Version 1.0.0 
    AW_Output_Source_UserRightsDest5_0 =
    Table.View(null,
            [
                GetType = () =>
                    type table [
                        COD_UTENTE = Text.Type,
                        COD_DEST5 = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsDest5 = Json.Document(Web.Contents(outputURL &"Datasource_000036()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsDest5 Converted to Table" = Table.FromRecords({Source_UserRightsDest5}),
                        #"UserRightsDest5 Removed Columns" = Table.RemoveColumns(#"UserRightsDest5 Converted to Table",{"@odata.context"}),
                        #"UserRightsDest5 Expanded value" = Table.ExpandListColumn(#"UserRightsDest5 Removed Columns", "value"),
                        Output_Source_UserRightsDest5 = Table.ExpandRecordColumn(#"UserRightsDest5 Expanded value", "value",{"COD_UTENTE", "COD_DEST5"})
                    in 
                        Output_Source_UserRightsDest5
            ]
        ),
    AW_UserRightsDest5_0  = Table.RenameColumns(AW_Output_Source_UserRightsDest5_0,{{"COD_DEST5", "TGK_DEST5_UR_KEY"}, {"COD_UTENTE", "TGK_DEST5_UR_USERID"}})
    ,
    AW_UserRightsDest5 = List.First(List.Select(VersionCases, each _{0} = Version), null){7}
	,
    //AIH User Rights Entity
     //Version 1.1.0 
    AW_Output_Source_UserRightsEntity_1 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        U = Text.Type,
                        D = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsEntity = Json.Document(Web.Contents(outputURL &"Datasource_AW9984()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsEntity Converted to Table" = Table.FromRecords({Source_UserRightsEntity}),
                        #"UserRightsEntity Removed Columns" = Table.RemoveColumns(#"UserRightsEntity Converted to Table",{"@odata.context"}),
                        #"UserRightsEntity Expanded value" = Table.ExpandListColumn(#"UserRightsEntity Removed Columns", "value"),
                        Output_Source_UserRightsEntity = Table.ExpandRecordColumn(#"UserRightsEntity Expanded value", "value",{"U", "D"})
                    in 
                        Output_Source_UserRightsEntity
            ]
        ),
    AW_UserRightsEntity_1  = Table.RenameColumns(AW_Output_Source_UserRightsEntity_1,{{"D", "TGK_ENTITY_UR_KEY"}, {"U", "TGK_ENTITY_UR_USERID"}})
    ,
    //Version 1.0.0 
    AW_Output_Source_UserRightsEntity_0 =
    Table.View(null,
            [
                GetType = () =>
                       type table [
                        COD_UTENTE = Text.Type,
                        COD_AZIENDA = Text.Type
                    ],
                GetRows = () =>
                    let 
                        Source_UserRightsEntity = Json.Document(Web.Contents(outputURL &"Datasource_AW9984()" ,[Timeout=#duration(0,0,30,0)])),
                        #"UserRightsEntity Converted to Table" = Table.FromRecords({Source_UserRightsEntity}),
                        #"UserRightsEntity Removed Columns" = Table.RemoveColumns(#"UserRightsEntity Converted to Table",{"@odata.context"}),
                        #"UserRightsEntity Expanded value" = Table.ExpandListColumn(#"UserRightsEntity Removed Columns", "value"),
                        Output_Source_UserRightsEntity = Table.ExpandRecordColumn(#"UserRightsEntity Expanded value", "value",{"COD_UTENTE", "COD_AZIENDA"})
                    in 
                        Output_Source_UserRightsEntity
            ]
        ),
    AW_UserRightsEntity_0  = Table.RenameColumns(AW_Output_Source_UserRightsEntity_0,{{"COD_AZIENDA", "TGK_ENTITY_UR_KEY"}, {"COD_UTENTE", "TGK_ENTITY_UR_USERID"}})
    ,
    AW_UserRightsEntity = List.First(List.Select(VersionCases, each _{0} = Version), null){8}
	,
    //AIH User Rights Scenario
        // Version 1.1.0 
    AW_Output_Source_UserRightsScenario_1 =
    Table.View(null,
        [
            GetType = () =>
                type table [
                    U = Text.Type,
                    D = Text.Type
                ],
            GetRows = () =>
                let 
                    Source_UserRightsScenario = Json.Document(Web.Contents(outputURL & "Datasource_AW9985()" ,[Timeout=#duration(0,0,30,0)])),
                    #"UserRightsScenario Converted to Table" = Table.FromRecords({Source_UserRightsScenario}),
                    #"UserRightsScenario Removed Columns" = Table.RemoveColumns(#"UserRightsScenario Converted to Table",{"@odata.context"}),
                    #"UserRightsScenario Expanded value" = Table.ExpandListColumn(#"UserRightsScenario Removed Columns", "value"),
                    Output_Source_UserRightsScenario = Table.ExpandRecordColumn(#"UserRightsScenario Expanded value", "value",{"U", "D"})
                in 
                    Output_Source_UserRightsScenario
        ]
    ),
    AW_UserRightsScenario_1  = Table.RenameColumns(AW_Output_Source_UserRightsScenario_1, {{"D", "TGK_SCENARIO_UR_KEY"}, {"U", "TGK_SCENARIO_UR_USERID"}}),
    
    // Version 1.0.0 
    AW_Output_Source_UserRightsScenario_0 =
    Table.View(null,
        [
            GetType = () =>
                type table [
                    COD_UTENTE = Text.Type,
                    COD_SCENARIO = Text.Type
                ],
            GetRows = () =>
                let 
                    Source_UserRightsScenario = Json.Document(Web.Contents(outputURL & "Datasource_AW9985()" ,[Timeout=#duration(0,0,30,0)])),
                    #"UserRightsScenario Converted to Table" = Table.FromRecords({Source_UserRightsScenario}),
                    #"UserRightsScenario Removed Columns" = Table.RemoveColumns(#"UserRightsScenario Converted to Table",{"@odata.context"}),
                    #"UserRightsScenario Expanded value" = Table.ExpandListColumn(#"UserRightsScenario Removed Columns", "value"),
                    Output_Source_UserRightsScenario = Table.ExpandRecordColumn(#"UserRightsScenario Expanded value", "value",{"COD_UTENTE", "COD_SCENARIO"})
                in 
                    Output_Source_UserRightsScenario
        ]
    ),
    AW_UserRightsScenario_0  = Table.RenameColumns(AW_Output_Source_UserRightsScenario_0, {{"COD_SCENARIO", "TGK_SCENARIO_UR_KEY"}, {"COD_UTENTE", "TGK_SCENARIO_UR_USERID"}}),
    
    AW_UserRightsScenario = List.First(List.Select(VersionCases, each _{0} = Version), null){9}
    , 
    AW_ListDimFinancial = Table.FromRecords({
    [DimensionName = "User Rights Account", DimensionTable = AW_UserRightsAccount],
    [DimensionName = "User Rights Category", DimensionTable = AW_UserRightsCategory],
    [DimensionName = "User Rights Custom Dimension 1", DimensionTable = AW_UserRightsDest1],
    [DimensionName = "User Rights Custom Dimension 2", DimensionTable = AW_UserRightsDest2],
    [DimensionName = "User Rights Custom Dimension 3", DimensionTable = AW_UserRightsDest3],
    [DimensionName = "User Rights Custom Dimension 4", DimensionTable = AW_UserRightsDest4],
    [DimensionName = "User Rights Custom Dimension 5", DimensionTable = AW_UserRightsDest5],
    [DimensionName = "User Rights Entity", DimensionTable = AW_UserRightsEntity],
    [DimensionName = "User Rights Scenario", DimensionTable = AW_UserRightsScenario]
    }),

    OutputFinancialDimensionsUR =  Table.SelectRows(AW_ListDimFinancial, each List.Contains(dimensionList, [DimensionName])) 
in
    OutputFinancialDimensionsUR
    ;

CreateNavTable = (base as table) as table =>
    let
        withItemKind = Table.AddColumn(base, "ItemKind", each "Table", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table", type text),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true, type logical),
        navTable = Table.ToNavigationTable(base,{"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

Table.ToNavigationTable=(
    table as table,
    keyColumn as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.ReplaceTableKeys(tableType, {[Columns = keyColumn,Primary = true]}) meta 
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

//Create Date Dimension
CreateCalendar=(StartDate as date, EndDate as date)=>
let
    //Capture the date range from the parameters
    StartDate = #date(Date.Year(StartDate), Date.Month(StartDate), 
    Date.Day(StartDate)),
    EndDate = #date(Date.Year(EndDate), Date.Month(EndDate), 
    Date.Day(EndDate)),

    //Get the number of dates that will be required for the table
    GetDateCount = Duration.Days(EndDate - StartDate),

    //Take the count of dates and turn it into a list of dates
    GetDateList = List.Dates(StartDate, GetDateCount, 
    #duration(1,0,0,0)),

    //Convert the list into a table
    DateListToTable = Table.FromList(GetDateList, 
    Splitter.SplitByNothing(), {"Date"}, null, ExtraValues.Error),

    //Create various date attributes from the date column
    //Add Year Column
    YearNumber = Table.AddColumn(DateListToTable, "Year", 
    each Date.Year([Date])),

    //Add Quarter Column
    QuarterNumber = Table.AddColumn(YearNumber , "Quarter", 
    each "Q" & Number.ToText(Date.QuarterOfYear([Date]))),

    //Add Month Number Column
    MonthNumber = Table.AddColumn(QuarterNumber, "Month Number", 
    each Date.Month([Date])),

    //Add Month Name Column
    DateTable = Table.AddColumn(MonthNumber , "Month", 
    each Date.ToText([Date],"MMMM"))

in
    DateTable;


DatasetRenameColumnKeys = (tableName as table, sourceColumnName as text,targetColumnName as text,targetAlternativeColumnName as text) as table =>
let
    renamedTable = if Table.HasColumns(tableName, "TGK_" & targetColumnName & "_KEY") = false then
                        Table.RenameColumns(tableName,{{sourceColumnName, "TGK_" & targetColumnName & "_KEY"}})
                    else
                        Table.RenameColumns(tableName,{{sourceColumnName, "TGK_" & targetAlternativeColumnName & "_KEY"}})
in
    renamedTable;


DatasetReplaceNullColumnKeys=(tableName as table, ColumnName as text) as table =>
let
    replaceNullValuesTable = Table.ReplaceValue(tableName,"",null,Replacer.ReplaceValue,{ColumnName})
in
    replaceNullValuesTable;
