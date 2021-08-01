[Version = "1.0.0"]
section Linkar;

/****************************
 * ADO.NET Driver Configuration
 ****************************/

[DataSource.Kind="Linkar", Publish="Linkar.Publish"]
shared Linkar.Contents = Value.ReplaceType(LinkarImpl, LinkarType);


// Data Source Kind description
Linkar = [
    TestConnection = (dataSourcePath) =>         
        let
            json = Json.Document(dataSourcePath),
            server = json[server],
            entrypoint = json[entrypoint],
            port = json[port]
            //server as text, entrypoint as text, port as number, optional language as text, optional freetext as text, optional customvars as text, optional FileName as text, optional SelectClause as text, optional DictClause as text, optional SortClause as text, optional sqlmode as logical
            //server = json[server],
            //database = json[database]
            //server = "10.0.0.9",
            //entrypoint = "DEMO.LINKAR",
            //port = 11350
        in
            { "Linkar.Contents", server, entrypoint, port },//database },
    // Set supported types of authentication
    Authentication = [
        UsernamePassword = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];


// Data Source UI publishing description
Linkar.Publish = [
    Beta = true,
    Category = "Database",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://www.kosday.com/",
    SourceImage = Linkar.Icons,
    SourceTypeImage = Linkar.Icons
    //SupportsDirectQuery = true
];


Linkar.Icons = [
    Icon16 = { Extension.Contents("LinkarConnector16.png"), Extension.Contents("LinkarConnector20.png"), Extension.Contents("LinkarConnector24.png"), Extension.Contents("LinkarConnector32.png") },
    Icon32 = { Extension.Contents("LinkarConnector32.png"), Extension.Contents("LinkarConnector40.png"), Extension.Contents("LinkarConnector48.png"), Extension.Contents("LinkarConnector64.png") }
];


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


LinkarType = type function (
    server as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("Server"),
        Documentation.FieldDescription = Extension.LoadString("ServerDesc"),
        Documentation.SampleValues = {"127.0.0.1", "localhost"}
    ]),
    entrypoint as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("EntryPoint"),
        Documentation.FieldDescription = Extension.LoadString("EntryPointDesc"),
        Documentation.SampleValues = {"DEMO"}
    ]),
    port as (type number meta [
        Documentation.FieldCaption = Extension.LoadString("Port"),
        Documentation.FieldDescription = Extension.LoadString("PortDesc"),
        Documentation.SampleValues = {11300}
    ]),
    optional language as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("Language"),
        Documentation.FieldDescription = Extension.LoadString("LanguageDesc"),
        Documentation.SampleValues = {"EN"}
    ]),
    optional freetext as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("FreeText"),
        Documentation.FieldDescription = Extension.LoadString("FreeTextDesc"),
        Documentation.SampleValues = {"From Power Bi"}
    ]),
    optional customvars as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("CustomVars"),
        Documentation.FieldDescription = Extension.LoadString("CustomVarsDesc"),
        Documentation.SampleValues = {"Your vars.."}
    ]),
    optional FileName as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("FileName"),
        Documentation.FieldDescription = Extension.LoadString("FileNameDesc"),
        Documentation.SampleValues = {"Orders"}
    ]),
    optional SelectClause as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("SelectClause"),
        Documentation.FieldDescription = Extension.LoadString("SelectClauseDesc"),
        Documentation.SampleValues = {"WITH Customer = ""84"""}
    ]),
    optional DictClause as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("DictClause"),
        Documentation.FieldDescription = Extension.LoadString("DictClauseDesc"),
        Documentation.SampleValues = {"Customer Date Item IItemDescription"}
    ]),
    optional SortClause as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("SortClause"),
        Documentation.FieldDescription = Extension.LoadString("SortClauseDesc"),
        Documentation.SampleValues = {"BY Customer"}
    ]),
    optional sqlmode as (type logical meta [
        Documentation.FieldCaption = Extension.LoadString("SQLMode"),
        Documentation.FieldDescription = Extension.LoadString("SQLModeDesc"),
         Documentation.SampleValues = {true},
        Documentation.AllowedValues = { true, false }
     ])
    )
    as table;


LinkarImpl = (server as text, entrypoint as text, port as number, optional language as text, optional freetext as text, optional customvars as text, optional FileName as text, optional SelectClause as text, optional DictClause as text, optional SortClause as text, optional sqlmode as logical) as table =>
    let
        lang = if (language = null) then "" else language,
        free = if (freetext = null) then "" else freetext,
        cus = if (customvars = null) then "" else customvars,

        ConnectionString =
        [
            Server = server,
            Database = entrypoint,
            Port = port,
            Language = lang,
            FreeText = free,
            CustomVars = cus
        ],

        Credential = Extension.CurrentCredential(),
        CredentialConnectionString = [ UID = Credential[Username], PWD = Credential[Password] ],


        sqlm = if (sqlmode <> null) then sqlmode else false,

        table = if (FileName <> null) then ExecuteQuery(ConnectionString,sqlm,FileName,SelectClause,DictClause,SortClause) else FullDatabase(ConnectionString,true)

    in
        table;


FullDatabase = (
    ConnectionString as record, sqlmode as logical) as table =>
    let
         AdoNetDataSource = AdoDotNet.DataSource("LinkarClientPowerBi",ConnectionString,null),
         TablesFunc = AdoNetDataSource{[CollectionName = "Tables"]}[Data] as function,
        Tables = TablesFunc("","","",""),

      aux0 = Table.SelectColumns(Tables,{"table_name", "table_fullname"}),
      aux00 = Table.RenameColumns(aux0,{"table_name","Base"}),
     aux1 = Table.RenameColumns(aux00,{"table_fullname","Name"}),
     aux2 = Table.DuplicateColumn(aux1, "Name", "Key"),
     char = Character.FromNumber(254),
     aux3 = Table.AddColumn(aux2,"Data", each AdoDotNet.Query("LinkarClientPowerBi",ConnectionString,"true|" & [Base] & char & "" & char & "" & char & "",null)),
     aux4 = Table.AddColumn(aux3,"ItemKind",each "Table"), 
     aux5 = Table.AddColumn(aux4,"ItemName",each "Table"), 
     aux = Table.AddColumn(aux5,"IsLeaf",each true), 
 
     objects = aux,
 
     NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;
        //if NavTable[HasError] then NavTable[Error] else NavTable[Value];



ExecuteQuery = (
    ConnectionString as record, sqlmode as logical, FileName as text, optional SelectClause as text,optional DictClause as text,optional SortClause as text) as table =>
    let
        char = Character.FromNumber(254),
        fn = if (FileName = null) then "" else FileName,
        selc = if (SelectClause = null) then "" else SelectClause,
        dc = if (DictClause = null) then "" else DictClause,
        sc = if (SortClause = null) then "" else SortClause,

        table = AdoDotNet.Query("LinkarClientPowerBi",ConnectionString,Logical.ToText(sqlmode) & "|" & fn  & char & selc & char & dc & char & sc,null)
    in
        table;
        //if table[HasError] then table[Error] else table[Value];
