// This file contains your Data Connector logic
[Version = "1.0.0"]
section Acterys;

[DataSource.Kind="Acterys", Publish="Acterys.Publish"]
shared Acterys.Contents = () =>
    let
        //apiKey = Extension.CurrentCredential()[access_token],
 

        ///// ********************** Get Database Name ******************************
        SourceDatabase = Json.Document(Web.Contents("https://app.acterys.com:9998/api/Subscription")),
        
        ActiveDatabases = SourceDatabase[ActiveDatabases],
        #"Converted to TableDB" = Table.FromList(ActiveDatabases, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        DBExpandedColumn = Table.ExpandRecordColumn(#"Converted to TableDB", "Column1",  Record.FieldNames(#"Converted to TableDB"{0}[Column1])),
        IsActiveCondition = SourceDatabase[IsActive], 
        UsedDatabaseName = ActiveDatabases{0}[ID],

        /////************************************************* Start  Dimension**************************************
 
        Source = Json.Document(Web.Contents("https://app.acterys.com:9998/api/Dimension?database="& UsedDatabaseName)),
        #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1",  Record.FieldNames(#"Converted to Table"{0}[Column1])),
        DimensionTables = Table.RemoveColumns(#"Expanded Column1",{"DataType" }), 
    
       //***************************************************************************************************

        ////************************************** Cube Start **************************************************************
        SourceCube = Json.Document(Web.Contents("https://app.acterys.com:9998/api/Cube?database="& UsedDatabaseName)), 
        #"Converted to TableCB" = Table.FromList(SourceCube, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1CB" = Table.ExpandRecordColumn(#"Converted to TableCB", "Column1", {"ID", "Name", "WriteBackTable", "WriteBackSP", "Dimensions", "Database"}, {"ID", "Name", "WriteBackTable", "WriteBackSP", "Dimensions", "Database"}),
     
         //////// Get Cube's Dimension Table list***************************************************************************

        #"Expanded Dimensions1" = Table.ExpandListColumn( #"Expanded Column1CB", "Dimensions"),
        #"Expanded Dimensions2" = Table.ExpandRecordColumn(#"Expanded Dimensions1", "Dimensions", {"ID", "Name", "DataType", "Fields"}, {"Dimensions.ID", "Dimensions.Name", "Dimensions.DataType", "Dimensions.Fields"}),
        #"Removed Columns" = Table.RemoveColumns(#"Expanded Dimensions2",{"Dimensions.DataType", "Dimensions.Fields", "Database"}),
        #"Grouped Rows" = Table.Group(#"Removed Columns", {"Name"}, {{"Count", each _, type table [ID=number, Name=text, WriteBackTable=text, WriteBackSP=text, Dimensions.ID=number, Dimensions.Name=text]}}),
        #"Added Custom" = Table.AddColumn(#"Grouped Rows", "Custom", each Table.Column([Count],"Dimensions.Name")),
        CubeNameList1 = Table.RemoveColumns(#"Added Custom",{"Count"}),
        CubeNameList=Table.RemoveMatchingRows( CubeNameList1,{[Name = ""]}, "Name"),
        CBDimensionTables = CubeNameList{[Name=CubeNameList{0}[Name]]}[Custom],//CubeNameList{[Name="Finance"]}[Custom],  
        TablesDim= Table.FromList(CBDimensionTables, Splitter.SplitByNothing(), null, null, ExtraValues.Error),

        //Get Service Account Table 
        SourceService = Json.Document(Web.Contents("https://app.acterys.com:9998/api/ServiceAccount?database="& UsedDatabaseName)),
        #"Converted to ServiceTable" = Table.FromList(SourceService, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        ServiceTable = Table.ExpandRecordColumn(#"Converted to ServiceTable", "Column1", {"Name", "Key"}, {"Name", "Key"}),

  objectsFinal = #table(
            {"Name", "Key",  "Data", "ItemKind", "ItemName", "IsLeaf"},{ 
            {"Dimensions",   "Dimensions",   GetDimension (DimensionTables, UsedDatabaseName) , "Dimension",    "Dimension",    false} ,
            {"Cubes",   "Cubes",  GetCube(CubeNameList,UsedDatabaseName,CBDimensionTables) , "CubeViewFolder",    "CubeViewFolder",    false},
            {"ServiceAccount", "ServiceAccount", ServiceTable, "Table", "Table", true}  
        }),
        NavTableFinal = Table.ToNavigationTable(objectsFinal, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf"),
  FinalResult =if IsActiveCondition=false then "User doesn't have any active subscription"  else  
  if Table.RowCount(#"Converted to Table")=0 then "User Dimention and Cube Data Not Found" else NavTableFinal
        
in
FinalResult;     
   
    GetDimension = (DimensionTables as table, UsedDatabaseName as text) =>
    let 
    Tablefinal =   let
                            Source = Function.InvokeAfter(() => Json.Document(Web.Contents("https://app.acterys.com:9998/api/DimensionData?dimension="& DimensionTables{0}[Name]&"&database="& UsedDatabaseName)),
                                            #duration(0,0,0,0.1)),
                                       Data0 = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error) ,
                                       #"Converted to Table2" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                                       toTable1= Table.ExpandRecordColumn(#"Converted to Table2", "Column1",Record.FieldNames(#"Converted to Table2"{0}[Column1]))  ,
                                       RenamedColumnsID = Table.RenameColumns(toTable1,{{"ID", DimensionTables{0}[Name] }}),
                                       DimTable = Table.AddKey(RenamedColumnsID, {DimensionTables{0}[Name]}, true)
                                    in
                                        DimTable  , 
      
        DimensionTablesObj =
                List.Generate(() => [ Tablefinal={""& DimensionTables{Counter}[Name]&"",      ""& DimensionTables{Counter}[Name]&"",     Tablefinal, "Table",    "Table",    true} ,Counter=0],
                        each [Counter] <Table.RowCount(DimensionTables),
                        each [  
                        Tablefinal =   let
                                        Source = Function.InvokeAfter(() => Json.Document(Web.Contents("https://app.acterys.com:9998/api/DimensionData?dimension="& DimensionTables{Counter}[Name]&"&database="& UsedDatabaseName)),
                                            #duration(0,0,0,0.1)),                                       
                                        
                                       Data0 = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error) ,
                                       #"Converted to Table2" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                                       toTable1= Table.ExpandRecordColumn(#"Converted to Table2", "Column1",Record.FieldNames(#"Converted to Table2"{0}[Column1])) ,
                                       RenamedColumnsID = Table.RenameColumns(toTable1,{{"ID", DimensionTables{Counter}[Name]}}),
                                       DimTable = Table.AddKey(RenamedColumnsID, {DimensionTables{Counter}[Name]}, true),
                                       listnav= {""& DimensionTables{Counter}[Name]&"", ""& DimensionTables{Counter}[Name]&"", DimTable, "Table",    "Table",    true} 
                                       
                                    in
                                        listnav    ,                         
                            Counter = [Counter] + 1] ,                       
                        each [Tablefinal] ),  
                DimensionResult=Table.FromRows(DimensionTablesObj),
                FnlDimensionResult = Table.RenameColumns(DimensionResult,{{"Column1", "Name"}, {"Column2", "Key"}, {"Column3", "Data"}, {"Column4", "ItemKind"}, {"Column5", "ItemName"}, {"Column6", "IsLeaf"}}),
             
                NavTableaa = Table.ToNavigationTable(FnlDimensionResult, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")     
    in
        NavTableaa ; 

    GetCube=(CubeNameList as table, UsedDatabaseName as text,CBDimensionTables as list) =>
        let  
          Cubeobject=  
                List.Generate(() => [Table = {""& CubeNameList{Counter}[Name]&"",      ""& CubeNameList{Counter}[Name]&"",      GetCubeWiseDetails(CBDimensionTables,CubeNameList{Counter}[Name],UsedDatabaseName) , "Cube",    "Cube",    true},Counter = 0],
                      each [Counter] < Table.RowCount(CubeNameList),
                      each [  
                       Table =  let 
                            CBDimensionTables = CubeNameList{[Name=CubeNameList{Counter}[Name]]}[Custom],
                            TablesDim= Table.FromList(CBDimensionTables, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                            listnav= {""& CubeNameList{Counter}[Name]&"",      ""& CubeNameList{Counter}[Name]&"",      GetCubeWiseDetails(CBDimensionTables,CubeNameList{Counter}[Name],UsedDatabaseName), "Cube",    "Cube",    true} 
                    in
                    listnav,                              
                            Counter = [Counter] + 1],                        
                       each [Table]), 
                    CubeName=Table.FromRows(Cubeobject),

            CubeNameFinal = Table.RenameColumns(CubeName,{{"Column1", "Name"}, {"Column2", "Key"}, {"Column3", "Data"}, {"Column4", "ItemKind"}, {"Column5", "ItemName"}, {"Column6", "IsLeaf"}}),
            NavTableCube = Table.ToNavigationTable(CubeNameFinal, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")        
        in
             NavTableCube ;

    GetCubeWiseDetails=(CBDimensionTables as list,CubeName as text, UsedDatabaseName as text )=>
        let   

        ErrorMsg = Json.Document("{
                         ""items"": [
                        {
                            ""TEXT_VAL"": "" Data Not Found"",
                            ""Amount"":  0, } ] }"),
                    items1 = ErrorMsg[items], 
                    ///// For TEXT Value
                         TableTEXTAmount =  let 
                                Source = Function.InvokeAfter(() => Json.Document(Web.Contents("https://app.acterys.com:9998/api/CubeData?cube="& CubeName &"&database="& UsedDatabaseName & "&showId=true")),
                                            #duration(0,0,0,0.1)),
                            #"Converted to Table" = Table.FromList(if  List.Count( Source) =0 then items1   else Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                           TableData= Table.ExpandRecordColumn(#"Converted to Table", "Column1",Record.FieldNames(#"Converted to Table"{0}[Column1])) ,
                            #"Changed Type" = Table.TransformColumnTypes(TableData,{{"Amount", type number}})
                      in
                         #"Changed Type" , 


        TableFist =   let
                        Source = Function.InvokeAfter(() => Json.Document(Web.Contents("https://app.acterys.com:9998/api/DimensionData?dimension="&  CBDimensionTables{0} &"&database="& UsedDatabaseName)),
                            #duration(0,0,0,0.1)),
                        Data0 = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error) ,
                        #"Converted to Table2" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                        toTable1= Table.ExpandRecordColumn(#"Converted to Table2", "Column1",Record.FieldNames(#"Converted to Table2"{0}[Column1])) ,
                        RenamedColumnsID = Table.RenameColumns(toTable1,{{"ID",  CBDimensionTables{0} }}),
                        DimTable = Table.AddKey(RenamedColumnsID, {CBDimensionTables{0}}, true)
                    in
                        DimTable ,
                                                 

        CubeWiseTablesObject= 
             List.Generate(() => [Table = {""& CBDimensionTables{Counter} &"",      ""& CBDimensionTables{Counter} &"",      TableFist,  "Table",    "Table",    true},Counter = 0],
                      each [Counter] < Table.RowCount(Table.FromList(CBDimensionTables, Splitter.SplitByNothing(), null, null, ExtraValues.Error)),
                      each [  
                        Table =   let
                                        Source = Function.InvokeAfter(() => Json.Document(Web.Contents("https://app.acterys.com:9998/api/DimensionData?dimension="&  CBDimensionTables{Counter} &"&database="& UsedDatabaseName)),
                                            #duration(0,0,0,0.1)),
                                       Data0 = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error) ,
                                       #"Converted to Table2" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                                       toTable1= Table.ExpandRecordColumn(#"Converted to Table2", "Column1",Record.FieldNames(#"Converted to Table2"{0}[Column1])) ,
                                       //  RenamedColumnsID = Table.RenameColumns(toTable1,{{"ID", CBDimensionTables{Counter}& "ID"  }}),
                                       RenamedColumnsID = Table.RenameColumns(toTable1,{{"ID", CBDimensionTables{Counter}}}),
                                       DimTable = Table.AddKey(RenamedColumnsID, {CBDimensionTables{Counter}}, true),
                                       listnav= { ""& CBDimensionTables{Counter}  &"",      "" & CBDimensionTables{Counter} &"",    DimTable, "Table",    "Table",    true} 
                                         
                                    in
                                        listnav    ,                         
                            Counter = [Counter] + 1] ,                       
                        each [Table] ),


            RowCount=Table.RowCount(Table.FromList(CBDimensionTables, Splitter.SplitByNothing(), null, null, ExtraValues.Error)),
            CubeWiseTablesData=Table.FromRows(CubeWiseTablesObject  ),
            CubeWiseTablesDataTEXT = Table.InsertRows(CubeWiseTablesData,RowCount, { [Column1 = CubeName,Column2 = CubeName, Column3 = TableTEXTAmount, Column4 ="Table",Column5= "Table",Column6="true"] }),
            CubeWiseTablesDataFinal = Table.RenameColumns(CubeWiseTablesDataTEXT,{{"Column1", "Name"}, {"Column2", "Key"}, {"Column3", "Data"}, {"Column4", "ItemKind"}, {"Column5", "ItemName"}, {"Column6", "IsLeaf"}}),
            NavTableDataCube = Table.ToNavigationTable(CubeWiseTablesDataFinal, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf") 
in 
    NavTableDataCube;
     
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
 


// Data Source Kind description
Acterys = [
     TestConnection = (dataSourcePath) => { "Acterys.Contents" },
     Authentication = [
        Aad = [
            AuthorizationUri = "https://login.microsoftonline.com/bdda14df-d12f-40e5-bbfd-6fa2774f3938/oauth2/authorize",
            Resource = "https://acterys.onmicrosoft.com/papi"
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];


// Data Source UI publishing description
Acterys.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = Acterys.Icons,
    SourceTypeImage = Acterys.Icons
];
Acterys.Icons = [
    Icon16 = { Extension.Contents("Acterys16.png"), Extension.Contents("Acterys20.png"), Extension.Contents("Acterys24.png"), Extension.Contents("Acterys32.png") },
    Icon32 = { Extension.Contents("Acterys32.png"), Extension.Contents("Acterys40.png"), Extension.Contents("Acterys48.png"), Extension.Contents("Acterys64.png") }
];