



[Version = "20.0.7805"]
section TibcoTdv;

[DataSource.Kind="TibcoTdv", Publish="TibcoTdv.Publish"]
shared TibcoTdv.DataSource = Value.ReplaceType(DatabaseImpl, DatabaseType);

EscapeValue = (val as text) as text =>
  let
    nonNullValue = if (val = null or Text.Length(val) = 0) then "" else val,
    escapedValue = Text.Replace(Text.Trim(nonNullValue), "}", "}}")
  in
    escapedValue;

MakeRecordPair = (key as text, value as text) as text =>
  let
    pair = if Text.Lower(key) = "dsn" or (value <> null and Text.Length(value) = 0) then
              key & "=" & value // we do not quote DSN value, as it breaks ODBC
           else
              key & "={" & EscapeValue(value) & "}"
  in
    pair;
    

RecordToString = (rec as record) as text => 
  let 
    keys = Record.FieldNames(rec),
    transformer = (k as text) => MakeRecordPair(k, Record.Field(rec, k)),        
    parts = List.Transform(keys, transformer),
    // rebuild query string
    cs = Combiner.CombineTextByDelimiter(";", QuoteStyle.None)(parts)
  in
    cs;

SupportsMultipleCatalogs = (connectionString as any) =>
  let
    sysInfo = Odbc.Query(connectionString, "SELECT VALUE FROM sys_sqlinfo WHERE NAME = 'SUPPORTS_MULTIPLE_CATALOGS'"),
    smc = Table.First(sysInfo, [VALUE = "YES"])[VALUE],
    result = if smc = "YES" then true else false
  in
    result;
    
HasQuery = (options as record) =>
  let
    query = if Record.HasFields(options, "Query") then options[Query] else null,
    hasQuery = if query <> null and Text.Length(query) > 0 then true else false
  in
    hasQuery;
    
DatabaseImpl = (
  // Required Properties
  dsn as text,
  // Optional Properties
  optional advancedOptions as text,
  optional options as record      // recommended by the documentation
  ) as table => 
    let
      // Calling Extension.CurrentCredential() triggers the Power BI credentials dialog, commented right now
      Credential = Extension.CurrentCredential(),

      // if the user provided credentials in the Power BI dialog, pick them up here
      // we'll append these to the connection string later
      CredentialConnectionString =
            if (Credential[AuthenticationKind]?) = "UsernamePassword" then 
                [
                  UID = Credential[Username],
                  PWD = Credential[Password]
                ]
            else if (Credential[AuthenticationKind]?) = "Windows" then
              [
              ]
            else
                [],

      InputOptions = if options <> null then options else [], 

      ConnectionStringPartial = [
        DSN = dsn
      ] & CredentialConnectionString & [EnablePowerBICriteriaModifier="True", MAP TO WVARCHAR="false", MAP TO LONG VARCHAR="2000", QueryPassthrough="False"],
      
      ConnectionString = RecordToString(ConnectionStringPartial) & ";" & (if advancedOptions <> null then advancedOptions else "" ),

                
      Options = [
        HideNativeQuery = true,
        CreateNavigationProperties = true,
        UseEmbeddedDriver = false,
        HierarchicalNavigation = true,
        SoftNumbers = true,
        SqlCapabilities = [
          SupportsTop = true,
          SupportedPredicates = 65535, /*SQL_SP.All*/
          SupportedAggregateFunctions = 63, /*SQL_AF.(AVG + COUNT + MAX + MIN + SUM + DISTINCT). doesn't support ALL*/
          Sql92Conformance = 8 /* SQL_SC_SQL92_FULL */,
          GroupByCapabilities = 4 /* SQL_GB_NO_RELATION */,
          FractionalSecondsScale = 3,
          StringLiteralEscapeCharacters = { "\" },
          SupportsNumericLiterals = true,
          SupportsStringLiterals = true,                       
          SupportsOdbcDateLiterals = true,
          SupportsOdbcTimeLiterals = true,
          SupportsOdbcTimestampLiterals = true
        ],
        
        SQLGetInfo = [
          SQL_ORDER_BY_COLUMNS_IN_SELECT = "N",
          SQL_CONVERT_FUNCTIONS = 2          
        ]
      ],

      ResultDatabase = if HasQuery(InputOptions) then
                          Odbc.Query(ConnectionString, InputOptions[Query])
                       else
                          let
                            odbcDataSource = Odbc.DataSource(ConnectionString, Options),
                            resultdb1 = if SupportsMultipleCatalogs(ConnectionString) then odbcDataSource else odbcDataSource{0}[Data]
                          in
                            resultdb1
    in
      ResultDatabase;


DatabaseType = type function(  
    dsn as (type text meta[
      Documentation.FieldCaption = Extension.LoadString("DSNFieldCaption"),
      Documentation.SampleValues = LoadDSNList()
    ]),
    optional advancedOptions as (type text meta[
      Documentation.FieldCaption = Extension.LoadString("AdvancedOptionsFieldCaption"),
      Documentation.SampleValues = {Extension.LoadString("AdvancedOptionsFieldSample")}
    ]),
    optional options as (type [
        optional Query = (type text meta [
          Documentation.FieldCaption = Extension.LoadString("OptionsQueryFieldCaption"),
          Documentation.DefaultValue = "",
          Documentation.SampleValues = { Extension.LoadString("OptionsQueryFieldSample") },
          Documentation.FieldDescription = ""
        ])
      ] meta [
          Documentation.FieldCaption = Extension.LoadString("OptionsFieldCaption")
      ])
    )
    as table meta [
      // set connection dialog title
      Documentation.DisplayName = Extension.LoadString("ConnectionDisplayName"),
      Documentation.Caption = Extension.LoadString("ConnectionCaption"),
      Documentation.Name = Extension.LoadString("ConnectionName")
    ];

LoadDSNList = () =>
  let
    Contents = Text.FromBinary(Extension.Contents("DSNList.txt")),
    DNSList = List.Select(List.Transform(List.Transform(Text.Split(Contents, "#(cr,lf)"), each Text.Clean(_)), each Text.Trim(_)), each Text.Length(_) <> 0)
  in 
    DNSList;

// Data Source Kind description
TibcoTdv = [
    TestConnection = (datasourcePath) => 
      let
        json = Json.Document(datasourcePath),
        DSN = json[dsn]
      in
        {"TibcoTdv.DataSource", DSN},
    Authentication = [
      // Provider supports username/password authentication
      UsernamePassword = [

      ],
      Windows = [ SupportsAlternateCredentials = true ],
      // Provider supports specifying authentication options in the ODBC DSN
      Implicit = []
    ]
    // We removed the label to avoid having all connections in the Data Source Settings dialog look the same
    // see https://github.com/Microsoft/DataConnectors/blob/master/docs/m-extensions.md#data-source-path-format for details
    // Removing the label makes the authentication dialog really ugly but we currently don't have much of a choice:
    // The docs say this: Note: We currently recommend you do not  include a Label for your data source if your function has required  parameters, as users will not be able to distinguish between the 
    // different credentials they have entered. We are hoping to improve this  in the future (i.e. allowing data connectors to display their own custom  data source paths).
    //Label = "Power BI Connector for TIBCO(R) Data Virtualization" // If you uncomment this, make sure you add a comma on the above parameter to make the syntax valid (no errors are thrown if invalid)
];


// Data Source UI publishing description
TibcoTdv.Publish = [
    Beta = false,
    Category = Extension.LoadString("Category"),
    
    ButtonText = {Extension.LoadString("FormulaTitleOEM"), Extension.LoadString("FormulaHelpOEM")},

    SourceImage = TibcoTdv.Icons,
    SourceTypeImage = TibcoTdv.Icons,
    
    LearnMoreUrl = Extension.LoadString("LearnMoreURL"),
    SupportsDirectQuery = true
];

TibcoTdv.Icons = [
  Icon16 = {
    Extension.Contents("TIBCO.ODBC.TDV48.png"),
    Extension.Contents("TIBCO.ODBC.TDV48.png"),
    Extension.Contents("TIBCO.ODBC.TDV48.png"),
    Extension.Contents("TIBCO.ODBC.TDV48.png")
  },
  Icon32 = {
    Extension.Contents("TIBCO.ODBC.TDV48.png"),
    Extension.Contents("TIBCO.ODBC.TDV48.png"),
    Extension.Contents("TIBCO.ODBC.TDV48.png"),
    Extension.Contents("TIBCO.ODBC.TDV48.png")
  }
];
