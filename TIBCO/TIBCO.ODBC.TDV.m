[Version = "1.0.0"]
section TibcoTdv;


[DataSource.Kind="TibcoTdv", Publish="TibcoTdv.Publish"]
shared TibcoTdv.DataSource = Value.ReplaceType(DatabaseImpl, DatabaseType);



StringToRecord = (optional otherFields as text) as record => 
  if otherFields <> null and Text.Length(otherFields) > 0 then
    let
      // split by ;
      othersList = Splitter.SplitTextByDelimiter(";")(otherFields),
      // remove empty values
      othersNonEmpty = List.Select(othersList, each Text.Length(_) > 0),
      // split each one into text=text pairs
      transformer = (value as text) => 
        let pair = Splitter.SplitTextByDelimiter("=")(value)
        in List.Transform(pair, each Text.Trim(_)),
      optionPairs = List.Transform(othersNonEmpty, each transformer(_)),
      optionNames = List.Transform(optionPairs, each _{0}),
      optionValues = List.Transform(optionPairs, each _{1})
    in
      Record.FromList(optionValues, optionNames)
  else
    [];

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
    
GetOtherProperties = (optional properties as text) as text => 
  if properties <> null and Text.Length(properties) > 0 then
    let 
      withOutOthers = Text.AfterDelimiter(Text.Lower(properties), "other="),
      firstQuotoIndex = Text.PositionOf(withOutOthers, "'", Occurrence.First),
      startIndex = if firstQuotoIndex < 0 then 0 else (firstQuotoIndex + 1),
      lastQuotoIndex = Text.PositionOf(withOutOthers, "'", Occurrence.Last),
      firstSemicolonsIndex = Text.PositionOf(withOutOthers, ";", Occurrence.First),
      endOtherPropertiesIndex = if lastQuotoIndex < 0 then firstSemicolonsIndex else (lastQuotoIndex - 1),
      otherPropertiesLength = if endOtherPropertiesIndex < 0 then Text.Length(withOutOthers) else (endOtherPropertiesIndex),      
      otherProperties = Text.Middle(withOutOthers, startIndex, otherPropertiesLength)
    in
      otherProperties
  else
    "";
    
TrimOtherProperties = (optional properties as text) as text => 
  if properties <> null and Text.Length(properties) > 0 then
    let
      startIndex = Text.PositionOf(Text.Lower(properties), "other="),
      withOutOthers = Text.AfterDelimiter(Text.Lower(properties), "other="),
      lastQuotoIndex = Text.PositionOf(withOutOthers, "'", Occurrence.Last), 
      firstSemicolonsIndex = Text.PositionOf(withOutOthers, ";", Occurrence.First),
      endOtherPropertiesIndex = if lastQuotoIndex < 0 then firstSemicolonsIndex else (lastQuotoIndex + 1),
      otherPropertiesLength = if endOtherPropertiesIndex < 0 then Text.Length(withOutOthers) else (endOtherPropertiesIndex),  
      
      withOutOtherProperties = if startIndex < 0 then properties else Text.RemoveRange(properties, startIndex, otherPropertiesLength + Text.Length("other="))   
    in      
      withOutOtherProperties
  else 
    "";
    
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
            else
                [],

      InputOptions = if options <> null then options else [], 

      // concatenate the DSN with the options values and AdvancedOptions converted to a record
      advOptions = StringToRecord(TrimOtherProperties(advancedOptions)),    
      
      ConnectionStringPartial = [
        DSN = dsn
      ] & CredentialConnectionString & advOptions & [EnablePowerBICriteriaModifier="True", MAP TO WVARCHAR="false", MAP TO LONG VARCHAR="2000"],
      
      otherProperties = GetOtherProperties(advancedOptions),
      ConnectionString = 
        if Text.Length(otherProperties) > 0 then
          Record.AddField(ConnectionStringPartial, "Other", Text.Combine({"'", otherProperties, "'"}))
        else
          ConnectionStringPartial,

                
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
          SQL_CONVERT_FUNCTIONS = 2,

          // The bits in these values come from the SQL_CVT_* constants, see sqlext.h
          // All types
          SQL_CONVERT_CHAR = 33554431,
          SQL_CONVERT_VARCHAR = 33554431,
          SQL_CONVERT_LONGVARCHAR = 33554431,
          SQL_CONVERT_WCHAR = 33554431,
          SQL_CONVERT_WVARCHAR = 33554431,
          SQL_CONVERT_WLONGVARCHAR = 33554431,

          // All the integral types and chars
          SQL_CONVERT_BIT =  14709529,

          // All the numeric types and chars
          SQL_CONVERT_NUMERIC = 14705663,
          SQL_CONVERT_DECIMAL = 14705663,
          SQL_CONVERT_FLOAT = 14705663,          
          SQL_CONVERT_REAL = 14705663,          
          SQL_CONVERT_DOUBLE = 14705663,          
          SQL_CONVERT_SMALLINT = 14705663,
          SQL_CONVERT_TINYINT = 14705663,
          SQL_CONVERT_INTEGER = 14705663,
          SQL_CONVERT_BIGINT = 14705663,

          // All the binary types and chars
          SQL_CONVERT_BINARY = 14946049,
          SQL_CONVERT_VARBINARY = 14946049,
          SQL_CONVERT_LONGVARBINARY = 14946049,

          // All the char types as well as date and timestamp
          SQL_CONVERT_DATE = 14844673, 

          // All the char types as well as time and timestamp
          SQL_CONVERT_TIME = 14877441,

          // All the char types as well as timestamp
          SQL_CONVERT_TIMESTAMP = 14811905,

          // All the char types as well as GUID
          SQL_CONVERT_GUID = 31458049
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
    Beta = true,
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
