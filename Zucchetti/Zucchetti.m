// Maffina Damiano 21/10/2019

//Tracing/log/diagnostics? https://github.com/Microsoft/DataConnectors/blob/master/samples/ODBC/SqlODBC/SqlODBC.pq
[Version = "1.0.1"]
section Zucchetti;

[DataSource.Kind="Zucchetti", Publish="Zucchetti.Publish"]

shared Zucchetti.Contents =  Value.ReplaceType(ZucchettiImpl, ZucchettiType);
ZucchettiImpl = (Url as text, Environment as text) as table =>
let
    _url = ValidateUrlScheme(Url),
    Origine = Csv.Document(Web.Contents(_url, [Headers=[Accept="text/html"], RelativePath="servlet/PBIConnector?queryToEx=ConnectorList&template=ConnectorList&env="& Environment &""]),[Delimiter=",", Columns=5, Encoding=TextEncoding.Utf8, QuoteStyle=QuoteStyle.None]),
    ConnectorList = Table.PromoteHeaders(Origine, [PromoteAllScalars=true]),
    SelectDistinct = Table.Distinct(Table.RemoveColumns(ConnectorList,{"Description", "url","id"}),{"idproced"}),
    RemovePrimaryKey = Table.FromRows(Table.ToRows(SelectDistinct) ,{"idproced", "dsproced"} ) ,
    //create NavTable
	addItemKind = Table.AddColumn(RemovePrimaryKey, "ItemKind", each "Folder"),
    addDataTables = Table.AddColumn(addItemKind, "Data", each CallForList([idproced],ConnectorList )),
    addLeaf = Table.AddColumn(addDataTables, "IsLeaf", each false),
    NavTable = Table.ToNavigationTable(addLeaf,  {"idproced"}, "dsproced", "Data", "ItemKind", "ItemKind", "IsLeaf") 
in 
	NavTable;

CallForList = (idproced as text , ConnectorList as table) as table => 
let 
    GetIdproced = Table.SelectRows(ConnectorList, each [idproced] = idproced ),
    //create NavTable
    addItemKind = Table.AddColumn(GetIdproced,"ItemKind", each "Table"),
    addDataTables = Table.AddColumn(addItemKind, "Data", each  CallForData([id],ConnectorList)),
    addLeaf = Table.AddColumn(addDataTables, "IsLeaf", each true ),
    NavTable2 = Table.ToNavigationTable(addLeaf,  {"id"}, "Description", "Data", "ItemKind", "ItemKind", "IsLeaf") 
in
    NavTable2;

CallForData = (id as text, ConnectorList as table) as table =>
let  
    getUrl= List.Single(Table.Column(Table.SelectRows(ConnectorList, each [id] = id),"url")),
	//data request
    origin = Web.Contents(Text.From(getUrl), [Headers=[Accept="text/html"],Timeout=#duration(0, 0, 5, 0)]),
	gzip = Binary.FromText(Text.FromBinary(origin,1252),BinaryEncoding.Base64), 
	getCSV = Text.FromBinary(Binary.Decompress(gzip,Compression.GZip),1252), 
	makeRowsColumns = Table.FromList(Text.Split(getCSV , "#(lf)"), Splitter.SplitTextByDelimiter("§§",QuoteStyle.None), null, null, ExtraValues.Error),
	setHeaders = Table.PromoteHeaders(makeRowsColumns ,[PromoteAllScalars=true]) 
in 
    setHeaders;

Zucchetti = [
    // TestConnection is required to enable the connector through the Gateway 
    TestConnection = (dataSourcePath) =>
        let 
            json = Json.Document(dataSourcePath),
            Url = json[Url],
            Environment = json[Environment]
        in
            { "Zucchetti.Contents", Url, Environment },
    Authentication = [
    UsernamePassword = []
    ],
    Label = Extension.LoadString("Title")
];

Zucchetti.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("Title"), Extension.LoadString("TitleHelp") },
    LearnMoreUrl = "https://www.hrzucchetti.it",
    SourceImage = Zucchetti.Icons,
    SourceTypeImage = Zucchetti.Icons

];

Zucchetti.Icons = [
    Icon16 = { Extension.Contents("Zucchetti16.png"), Extension.Contents("Zucchetti20.png"), Extension.Contents("Zucchetti24.png"), Extension.Contents("Zucchetti32.png") },
    Icon32 = { Extension.Contents("Zucchetti32.png"), Extension.Contents("Zucchetti40.png"), Extension.Contents("Zucchetti48.png"), Extension.Contents("Zucchetti64.png") }
];

//This function checks if the user entered an HTTPS url and raises an error if they don't.
ValidateUrlScheme = (url as text) as text => if (Uri.Parts(url)[Scheme] <> "https") then error Extension.LoadString("ErrorHttps") else url;

ZucchettiType = type function (
    Url as (type text meta [
        Documentation.FieldCaption = "URL",
        Documentation.FieldDescription = Extension.LoadString("UrlFieldDesc"),
        Documentation.SampleValues = {"https://myurl/HRPortal/"}
    ]),
    Environment as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("EnvCode"),
        Documentation.FieldDescription = Extension.LoadString("EnvCode"),
        Documentation.SampleValues = { "001", "000001" }
    ]))
    as table meta [
        Documentation.Name = Extension.LoadString("Title"),
        Documentation.LongDescription = Extension.LoadString("LongDesc"),
        Documentation.Examples = {[
            Description = Extension.LoadString("RespDesc"),
            Code = "    Zucchetti.Contents(""https://myurl/HRPortal/"", ""001""),
    ERM = Origine{[idproced=""ERM""]}[Data],
    ERM_query_pbi_employee = ERM{[id=""ERM_query_pbi_employee""]}[Data]",
            Result = "    Table containing employee list"
        ]}
    ];

//Per consultarla dalle shared
/*shared Zucchetti.Version = () as text => let ver = "1.0.0" in  ver; */

// Common library code
Table.ToNavigationTable = (table as table, keyColumns as list, nameColumn as text, dataColumn as text, itemKindColumn as text, itemNameColumn as text, isLeafColumn as text) as table =>
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