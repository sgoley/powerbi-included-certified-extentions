//Copyright (c) 2019 Sagra Technology Sp. z o.o.
//technical contact: robert.golik@sagra.pl
//This connector provides a easy way to connect to Emigo data sources
//it gives a odata list selector
//and a function to choose a datasoyrce and add data restrictions to id
[Version = "1.0.6"] 
section EmigoDataSourceConnector; //production
//
// Definition
//

// Data Source Kind description
EmigoDataSourceConnector = [
    TestConnection = (dataSourcePath) => { "Emigo.Contents" },
    Authentication = [
        // Key = [],
        UsernamePassword = [
            UsernameLabel =Extension.LoadString("LoginUsernameLabel"), 
            PasswordLabel = Extension.LoadString("LoginPasswordLabel")
            ]
        // Windows = [],
        //Implicit = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];
// Data Source UI publishing description
EmigoDataSourceConnector.Publish = [
    Beta = false, //Beta = true,
    Category = "Online Services",   //Category = "Other",   ?? jak online
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://sagra.pl/platforma-emigo/biqsens/",
    SourceImage = EmigoDataSourceConnector.Icons,
    SourceTypeImage = EmigoDataSourceConnector.Icons
];

//
// Implementation
// 

BaseUrl = "https://odata.sagra.io/ConnectorList/data";
char_enter = Character.FromNumber(10);
char_tab = Character.FromNumber(9) ;
//shared -> Shared functions become visible to other queries/functions, and can be thought of as the exports for your extension (i.e. they become callable from Power Query).
[DataSource.Kind="EmigoDataSourceConnector", Publish="EmigoDataSourceConnector.Publish"]
//shared Emigo.Contents =Value.ReplaceType(EmigoDataSourceConnector.Navigation, EmigoDataSourceConnector.NavigationFunctionType); //EmigoDataSourceConnector.Navigation; //production
shared Emigo.Contents =Value.ReplaceType(EmigoDataSourceConnector.NavigationWithCustomError, EmigoDataSourceConnector.NavigationFunctionType); //EmigoDataSourceConnector.Navigation; //production
// shared Emigo.Contents =EmigoDataSourceConnector.Navigation; //production   
    
    
//https://docs.microsoft.com/en-us/power-query/handlingdocumentation
shared EmigoDataSourceConnector.NavigationFunctionType = type function (
		optional DataRestrictionType as (type text meta [
				Documentation.FieldCaption = Extension.LoadString("DataRestrictionType") , 
				Documentation.FieldDescription =Extension.LoadString("DataRestrictionTypeDescription") ,
				Documentation.AllowedValues = EmigoDataSourceConnector.EmigoFeed.AlowedExtractRestrictionList   
				]
			),
		optional DataRestrictionValue as (type text meta [
				Documentation.FieldCaption = Extension.LoadString("DataRestrictionValue") , 
				Documentation.FieldDescription = Extension.LoadString("DataRestrictionValueDescription") ,
				Documentation.SampleValues = {"3","4","5"}
				]
			),
		optional DataRestrictionMode as (type text meta [
				Documentation.FieldCaption = Extension.LoadString("DataRestrictionMode") ,
				Documentation.FieldDescription = Extension.LoadString("DataRestrictionModeDescription") , 
				Documentation.AllowedValues = EmigoDataSourceConnector.EmigoFeed.AlowedDataRestrictionMode
				]
			),
		optional AuthorizationMode as (type text meta [
				Documentation.FieldCaption = Extension.LoadString("AuthorizationMode") ,
				Documentation.FieldDescription = Extension.LoadString("AuthorizationModeDescription") , 
				Documentation.AllowedValues = EmigoDataSourceConnector.EmigoFeed.AlowedSecurityCallContext 
				]
			)	
	
	)
    as table meta [
            Documentation.Name = Extension.LoadString("Documentation2_Name") , 
            Documentation.LongDescription  =Extension.LoadString("Documentation2_LongDescription") ,
            Documentation.Examples = {[
                Description  = Extension.LoadString("Documentation2_Examples1_Description"),
                Code = Extension.LoadString("Documentation2_Examples1_Code"),
                Result = Extension.LoadString("Documentation2_Examples1_Result")
            ]}
        ];   
    
 EmigoDataSourceConnector.Navigation = 
     (
        optional DataRestrictionType as text, 
        optional DataRestrictionValue as text, 
        optional DataRestrictionMode as text, 
        optional AuthorizationMode as text
     ) =>
            let
            Source = Json.Document((Web.Contents(BaseUrl))),
            Tbl = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
            RespStart = Table.ExpandRecordColumn(Tbl, "Column1", {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}),

            Resp2 = Table.ReplaceValue(RespStart,each [Name], each if [Key]= "wyciag" then Extension.LoadString("SelectorNameExtract") else EmigoDataSourceConnector.EmigoFeed.GetFeedList([Name], DataRestrictionType, DataRestrictionValue, DataRestrictionMode, AuthorizationMode) ,Replacer.ReplaceValue , {"Name"}),
            Resp = Table.ReplaceValue(Resp2,each [Data], each if [Key]= "wyciag" then Value.ReplaceType(EmigoDataSourceConnector.InternalGetExtractFunction, EmigoDataSourceConnector.GetExtractFunctionType) else EmigoDataSourceConnector.EmigoFeed.GetFeedList([Data], DataRestrictionType, DataRestrictionValue, DataRestrictionMode, AuthorizationMode) ,Replacer.ReplaceValue , {"Data"}),
            
            NavTable = EmigoDataSourceConnector.Table.ToNavigationTable(Resp, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")

        in
            NavTable;


    
 EmigoDataSourceConnector.NavigationWithCustomError = 
     (
        optional DataRestrictionType as text, 
        optional DataRestrictionValue as text, 
        optional DataRestrictionMode as text, 
        optional AuthorizationMode as text
     ) =>
let          
        //pozbycue sie null-i!
        OgraniczenieTypTmp = EmigoDataSourceConnector.SetDataRestrictionType (DataRestrictionType), 
        OgraniczenieOkresTmp = EmigoDataSourceConnector.SetDataRestrictionValue(DataRestrictionValue),
        OgraniczenieExactTmp = EmigoDataSourceConnector.SetDataRestrictionMode(DataRestrictionMode),
        AuthorizationModeTmp = EmigoDataSourceConnector.SetAuthorizationMode(AuthorizationMode), 
        //kontrola na wejsciu
        isProperOgraniczenieTyp = EmigoDataSourceConnector.isProperOgraniczenieTyp(OgraniczenieTypTmp),
        isProperOgraniczenieTryb =  EmigoDataSourceConnector.isProperOgraniczenieTryb(OgraniczenieExactTmp),     
        isProperAuthorizationMode = EmigoDataSourceConnector.isProperAuthorizationMode(AuthorizationModeTmp) , 
        isProperOgraniczenieOkres = EmigoDataSourceConnector.isProperOgraniczenieOkres(OgraniczenieOkresTmp) , 
        DataRestrictionValueOutput = EmigoDataSourceConnector.SetDataRestrictionValueOutput(OgraniczenieOkresTmp , isProperOgraniczenieOkres) ,

        NavTable = if isProperAuthorizationMode=false or isProperOgraniczenieTyp=false or isProperOgraniczenieOkres= false or isProperOgraniczenieTryb = false
            then 
                error EmigoDataSourceConnector.EmigoFeed.ErrorOutPut( true, isProperOgraniczenieTyp ,isProperOgraniczenieOkres, isProperOgraniczenieTryb,isProperAuthorizationMode)    
            else
		let
		    Source = Json.Document((Web.Contents(BaseUrl))),
		    Tbl = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
		    RespStart = Table.ExpandRecordColumn(Tbl, "Column1", {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}),

		    Resp2 = Table.ReplaceValue(RespStart,each [Name], each if [Key]= "wyciag" then Extension.LoadString("SelectorNameExtract") else EmigoDataSourceConnector.EmigoFeed.GetFeedList([Name], DataRestrictionType, DataRestrictionValue, DataRestrictionMode, AuthorizationMode) ,Replacer.ReplaceValue , {"Name"}),
		    Resp = Table.ReplaceValue(Resp2,each [Data], each if [Key]= "wyciag" then Value.ReplaceType(EmigoDataSourceConnector.InternalGetExtractFunction, EmigoDataSourceConnector.GetExtractFunctionType) else EmigoDataSourceConnector.EmigoFeed.GetFeedList([Data], DataRestrictionType, DataRestrictionValue, DataRestrictionMode, AuthorizationMode) ,Replacer.ReplaceValue , {"Data"}),

		    NavTableTmp = EmigoDataSourceConnector.Table.ToNavigationTable(Resp, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")

		in
		    NavTableTmp
    in
        NavTable;



EmigoDataSourceConnector.GetExtractFunctionType = type function (
	ExtractName as (type text meta [
			Documentation.FieldCaption =Extension.LoadString("ChooseExtract") ,
			Documentation.FieldDescription = Extension.LoadString("ChooseExtractDescription"), 
			Documentation.AllowedValues = EmigoDataSourceConnector.EmigoFeed.AlowedExtractList
			]
		),
	optional DataRestrictionType as (type text meta [
			Documentation.FieldCaption =Extension.LoadString("RestrictionKind") , 
			Documentation.FieldDescription =Extension.LoadString("RestrictionKindDescription") , 
			Documentation.AllowedValues = EmigoDataSourceConnector.EmigoFeed.AlowedExtractRestrictionList   
			]
		),
	optional DataRestrictionValue as (type text meta [
			Documentation.FieldCaption = Extension.LoadString("RestrictionValue") ,
			Documentation.FieldDescription = Extension.LoadString("RestrictionValueDescription") , 
            Documentation.SampleValues = {"3","4","5"}
			]
		),
	optional DataRestrictionMode as (type text meta [
			Documentation.FieldCaption = Extension.LoadString("RestrictionMode") ,
			Documentation.FieldDescription = Extension.LoadString("RestrictionModeDescription") , 
			Documentation.AllowedValues = EmigoDataSourceConnector.EmigoFeed.AlowedDataRestrictionMode 
			]
		)
	)


as table meta [
        Documentation.Name =  Extension.LoadString("Documentation_Name") , 
        Documentation.LongDescription = Extension.LoadString("Documentation_LongDescription") ,
        Documentation.Examples = {[
            Description =  Extension.LoadString("Documentation_Examples1_Description"),
            Code =  Extension.LoadString("Documentation_Examples1_Code"),
            Result =  Extension.LoadString("Documentation_Examples1_Result")
        ]}
    ]
;



//emigo external function wrapper -> compatible with help
//idea is to let the user just copy definition from "help"
//and use it is mlanguage
shared Emigo.GetExtractFunction = (ExtractName as text, optional DataRestrictionType as text, optional DataRestrictionValue as text, optional DataRestrictionMode as text) => 
let
    Source = Emigo.Contents(), //production
    Wycior = Source{[Key="wyciag"]}[Data],
    InternalInvokedFunction = Wycior(ExtractName,DataRestrictionType, DataRestrictionValue, DataRestrictionMode)
in
    InternalInvokedFunction ;

//for backward compatylity
shared EmigoDataSourceConnector.GetExtractFunction = (ExtractName as text, optional DataRestrictionType as text, optional DataRestrictionValue as text, optional DataRestrictionMode as text) => 
let
    Source = Emigo.Contents(), //production
    Wycior = Source{[Key="wyciag"]}[Data],
    InternalInvokedFunction = Emigo.GetExtractFunction(ExtractName ,DataRestrictionType, DataRestrictionValue, DataRestrictionMode)
in
    InternalInvokedFunction ;


//internal emigo extract function
EmigoDataSourceConnector.InternalGetExtractFunction = (ExtractName as text, optional DataRestrictionType as text, optional DataRestrictionValue as text, optional DataRestrictionMode as text) => 
    let
        //pozbycue sie null-i!
        OgraniczenieTypTmp = EmigoDataSourceConnector.SetDataRestrictionType (DataRestrictionType), 
        OgraniczenieOkresTmp = EmigoDataSourceConnector.SetDataRestrictionValue(DataRestrictionValue),
        OgraniczenieExactTmp = EmigoDataSourceConnector.SetDataRestrictionMode(DataRestrictionMode),  
        //kontrola na wejsciu
        isProperWyciag = EmigoDataSourceConnector.isProperWyciag(ExtractName), 
        isProperOgraniczenieTyp = EmigoDataSourceConnector.isProperOgraniczenieTyp(OgraniczenieTypTmp),
        isProperOgraniczenieTryb =  EmigoDataSourceConnector.isProperOgraniczenieTryb(OgraniczenieExactTmp), 
        isProperOgraniczenieOkres = EmigoDataSourceConnector.isProperOgraniczenieOkres(OgraniczenieOkresTmp) , 
        DataRestrictionValueOutput = EmigoDataSourceConnector.SetDataRestrictionValueOutput(OgraniczenieOkresTmp , isProperOgraniczenieOkres) , 

        OutPut = if isProperWyciag=false or isProperOgraniczenieTyp=false or isProperOgraniczenieOkres= false or isProperOgraniczenieTryb = false
            then 
                error EmigoDataSourceConnector.EmigoFeed.ErrorOutPut(isProperWyciag, isProperOgraniczenieTyp ,isProperOgraniczenieOkres, isProperOgraniczenieTryb, true)    
            else
                let
                    _Url = EmigoDataSourceConnector.Url.GetExtractFromUrl() ,
                    _RestrictData = if (OgraniczenieTypTmp <> Text.Upper(Extension.LoadString("StringValueMissing")) and OgraniczenieOkresTmp <> Extension.LoadString("StringValueMissing")) then DataRestrictionValueOutput & Text.Upper(DataRestrictionType) else "",
                    feeeeed = OData.Feed(_Url, null, [Query = [RestrictData =  _RestrictData, RestrictType = OgraniczenieExactTmp]]),
                    Source =feeeeed{[Name=ExtractName,Signature="table"]}[Data]
                in 
                    Source
    in
        OutPut;


//Emigo feed list
EmigoDataSourceConnector.EmigoFeed.GetFeedList = (
        adress as text,         
        optional DataRestrictionType as text, 
        optional DataRestrictionValue as text, 
        optional DataRestrictionMode as text, 
        optional AuthorizationMode as text
    ) => 
    let
        RestrictionSettingsTmp =  if DataRestrictionType = null then "NotSet" else Text.Upper(DataRestrictionType),
        RestrictTypeTmp =  if DataRestrictionMode = null then "NotSet" else Text.Upper(DataRestrictionMode),
        SecurityCallContextTmp1 =  if AuthorizationMode = null then "Default" else AuthorizationMode,
        
        isProperOgraniczenieOkres = if Value.Is(Value.FromText(DataRestrictionValue), type number) then true else false,
        DataRestrictionValueOutput = if isProperOgraniczenieOkres = false then "NotSet" else Text.From(Number.Round(Number.FromText(DataRestrictionValue), 0)), 

        isSecurityCallContext = List.MatchesAny(EmigoDataSourceConnector.EmigoFeed.AlowedSecurityCallContextInternal,each _  =  SecurityCallContextTmp1),
        SecurityCallContextTmp = if isSecurityCallContext = false then "Default" else SecurityCallContextTmp1,

        RestrictDataTmp = DataRestrictionValueOutput & RestrictionSettingsTmp,

		Source = OData.Feed(adress,null, [Query = [RestrictData = RestrictDataTmp, RestrictType = RestrictTypeTmp , AuthorizationType = SecurityCallContextTmp]])
    in
        Source;


//Internal getRidOfNulles
EmigoDataSourceConnector.SetDataRestrictionType = (optional DataRestrictionType as text) as text=>
    let
        OgraniczenieTypTmp = if DataRestrictionType = null or Text.Trim(DataRestrictionType)="" then Text.Upper(Extension.LoadString("StringValueMissing")) else Text.Upper(DataRestrictionType)
    in
        OgraniczenieTypTmp;

EmigoDataSourceConnector.SetDataRestrictionValue = (optional DataRestrictionValue as text) as text=>
    let
        OgraniczenieOkresTmp = if DataRestrictionValue = null or Text.Trim(DataRestrictionValue)="" then "0" else DataRestrictionValue
    in
        OgraniczenieOkresTmp;

EmigoDataSourceConnector.SetDataRestrictionMode = (optional DataRestrictionMode as text) as text=>
    let
       OgraniczenieExactTmp = if DataRestrictionMode = null or Text.Trim(DataRestrictionMode)="" then Text.Upper(Extension.LoadString("StringValueDefault")) else Text.Upper(DataRestrictionMode)
    in
        OgraniczenieExactTmp;


EmigoDataSourceConnector.SetAuthorizationMode = (optional AuthorizationMode as text) as text=>
    let
       AuthorizationModeTmp = if AuthorizationMode = null or Text.Trim(AuthorizationMode)="" then Text.Upper(Extension.LoadString("StringValueDefault")) else Text.Upper(AuthorizationMode)
    in
        AuthorizationModeTmp;


//intetlan checks
EmigoDataSourceConnector.isProperWyciag= (ExtractName as text) as logical =>
    let
        isProperWyciag = List.MatchesAny(EmigoDataSourceConnector.EmigoFeed.AlowedExtractList,each _  =  ExtractName)
    in
        isProperWyciag;

EmigoDataSourceConnector.isProperOgraniczenieTyp= (OgraniczenieTypTmp as text) as logical =>
    let
        isProperOgraniczenieTyp = List.MatchesAny(EmigoDataSourceConnector.EmigoFeed.AlowedExtractRestrictionList,each Text.Upper(_)  =   OgraniczenieTypTmp)
    in
        isProperOgraniczenieTyp;

EmigoDataSourceConnector.isProperOgraniczenieTryb= (OgraniczenieExactTmp as text) as logical =>
    let
        isProperOgraniczenieTryb = List.MatchesAny(EmigoDataSourceConnector.EmigoFeed.AlowedDataRestrictionMode,each Text.Upper(_) =  OgraniczenieExactTmp)
    in
        isProperOgraniczenieTryb;

EmigoDataSourceConnector.isProperOgraniczenieOkres= (OgraniczenieOkresTmp as text) as logical =>
    let
        isProperOgraniczenieOkres = if Value.Is(Value.FromText(OgraniczenieOkresTmp), type number) then true else false
    in
        isProperOgraniczenieOkres;

EmigoDataSourceConnector.isProperAuthorizationMode= (AuthorizationModeTmp as text) as logical =>
    let
        isProperAuthorizationMode = List.MatchesAny(EmigoDataSourceConnector.EmigoFeed.AlowedSecurityCallContextInternal,each Text.Upper(_)  =  AuthorizationModeTmp)
    in
        isProperAuthorizationMode;

EmigoDataSourceConnector.SetDataRestrictionValueOutput= (OgraniczenieOkresTmp as text, isProperOgraniczenieOkres as logical) as text =>
    let
        DataRestrictionValueOutput = if isProperOgraniczenieOkres = false then Extension.LoadString("StringValueMissing") else Text.From(Number.Round(Number.FromText(OgraniczenieOkresTmp), 0)) 
    in
        DataRestrictionValueOutput;




//error inf0
EmigoDataSourceConnector.EmigoFeed.ErrorOutPut = (isProperWyciag as logical, isProperOgraniczenieTyp as logical,isProperOgraniczenieOkres as logical, isProperOgraniczenieTryb as logical, isProperAuthType as logical) => 
    let
        errorInfo =  char_enter & Extension.LoadString("Error_header") & char_enter,
        errorInfo1 = errorInfo &  Text.From(if isProperWyciag=false then  char_tab & Extension.LoadString("Error_isProperWyciag") &   char_enter else ""),
        errorInfo2 = errorInfo1 &  Text.From(if isProperOgraniczenieTyp=false then  char_tab & Extension.LoadString("Error_isProperOgraniczenieTyp")  &   char_enter else ""),
        errorInfo3 = errorInfo2 &  Text.From(if isProperOgraniczenieOkres=false then  char_tab & Extension.LoadString("Error_isProperOgraniczenieOkres")  &   char_enter else ""),
        errorInfo4 = errorInfo3 &  Text.From(if isProperOgraniczenieTryb=false then  char_tab & Extension.LoadString("Error_isProperOgraniczenieTryb")  &   char_enter else ""), 
        errorInfo5 = errorInfo4 &  Text.From(if isProperAuthType=false then  char_tab & Extension.LoadString("Error_isProperAuthType")  &   char_enter else ""), 
        
        
        errorInfoEnd1 = errorInfo5 &  char_enter &  Extension.LoadString("Error_footer") & char_enter,
        errorInfoEnd2 = errorInfoEnd1 & Text.From(if isProperOgraniczenieOkres=false then char_tab & Extension.LoadString("Error_footer_value")  &   char_enter else ""),
        errorInfoEnd = errorInfoEnd2 & Text.From(if isProperWyciag=false or isProperOgraniczenieTyp=false or isProperOgraniczenieTryb=false or isProperAuthType=false then char_tab & Extension.LoadString("Error_footer_lists")  &   char_enter else "")
   in
        errorInfoEnd;

//function -> allowed restriction list
EmigoDataSourceConnector.EmigoFeed.AlowedExtractRestrictionList =
let
    data = {Extension.LoadString("StringValueMissing"), "Days", "Weeks", "Months", "Quarters", "Years" }
    in
      data  ;

//function -> allowed securyti contextes values
EmigoDataSourceConnector.EmigoFeed.AlowedDataRestrictionMode =
let
    data =  { Extension.LoadString("StringValueDefault"), "Exact"} 
    in
      data ;

//function -> allowed securyti contextes values
EmigoDataSourceConnector.EmigoFeed.AlowedSecurityCallContext =
let
    data =  { Extension.LoadString("StringValueDefault"), "EmigoObszary" , "EmigoHierarchia" , "CustomRestrictions"}  // , "ISF"
    in
      data ;

//function -> allowed securyti contextes values to check (not obvious too)
EmigoDataSourceConnector.EmigoFeed.AlowedSecurityCallContextInternal =
let
    data =  { Extension.LoadString("StringValueDefault"), "EmigoObszary" , "EmigoHierarchia" , "ISF", "CustomRestrictions"} 
    in
      data ;

//function -> allowed extracts
EmigoDataSourceConnector.EmigoFeed.AlowedExtractList = 
let
    Url = EmigoDataSourceConnector.Url.GetExtractFromUrl() ,
    Source = Json.Document((Web.Contents(Url))),
    value = Source[value],
    tblFromList = Table.FromList(value, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    expandCols = Table.ExpandRecordColumn(tblFromList, "Column1", {"name", "kind", "url", "title"}, {"Column1.name", "Column1.kind", "Column1.url", "Column1.title"}),
    filterCols = Table.SelectRows(expandCols, each ([Column1.kind] = "EntitySet")),
    filteredTable = Table.RemoveColumns(filterCols,{"Column1.url", "Column1.title", "Column1.kind"}),
    orderTable = Table.Sort(filteredTable,{{"Column1.name", Order.Ascending}}),
    wynik = Table.ToList(orderTable)
in
    wynik
	;

//extract list from URL
EmigoDataSourceConnector.Url.GetExtractFromUrl = () as text =>
    let
        tmpUrl = BaseUrl,
        Source = Json.Document((Web.Contents(tmpUrl))),
        Tbl = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        tblExpand = Table.ExpandRecordColumn(Tbl, "Column1", {"Key", "Data"}, {"Key", "Data"}),
        tblFilter = Table.SelectRows(tblExpand, each ([Key] = "wyciag")),
        Url = tblFilter{0}[Data]
    in
        Url
    ;
//navigation table elements
EmigoDataSourceConnector.Table.ToNavigationTable = (
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
            Preview.DelayColumn = dataColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

EmigoDataSourceConnector.Icons = [
    Icon16 = { Extension.Contents("Emigo16.png"), Extension.Contents("Emigo20.png"), Extension.Contents("Emigo24.png"), Extension.Contents("Emigo32.png") },
    Icon32 = { Extension.Contents("Emigo32.png"), Extension.Contents("Emigo40.png"), Extension.Contents("Emigo48.png"), Extension.Contents("Emigo64.png") }
];

