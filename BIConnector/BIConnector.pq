//Globals
[Version = "1.0.4"]
section BIConnector;

ModuleName = "BI Connector";
DriverName = "BI Connector Driver";
ResourcePathSeparator = ";";

EnableTraceOutput = false;

[DataSource.Kind = "BIConnector", Publish = "BIConnector.Publish"]
shared BIConnector.Contents = Value.ReplaceType(BIConnector.ContentsX, BIConnector.ContentsType);
BIConnector.ContentsX = (dsnname as text) as table =>
    let
        ConnectionString = [
            DSN = dsnname,
			Driver = DriverName
        ],
        Credential = Extension.CurrentCredential(),
        CommonOptions = [
            CredentialConnectionString = [
				UID = Credential[Username], 
				PWD = Credential[Password]
			], 
            ClientConnectionPooling = true, 
            OnError = OnError
        ],

        OnError = (errorRecord as record) =>
            let
                OdbcError = errorRecord[Detail][OdbcErrors]{0},
                OdbcErrorMessage = OdbcError[Message],
                OdbcErrorCode = OdbcError[NativeError],
                HasCredentialError = errorRecord[Detail] <> null and errorRecord[Detail][OdbcErrors]? <> null and OdbcErrorCode <> 0 and OdbcErrorCode <> 7
            in
                if HasCredentialError then error Extension.CredentialError(Credential.AccessDenied, OdbcErrorMessage)
                    else error errorRecord,
					 
        OdbcDataSource = Odbc.DataSource(ConnectionString, CommonOptions & [
                HierarchicalNavigation = true, 
                HideNativeQuery = true,
                //TolerateConcatOverflow = true,
                SqlCapabilities = [
                    SupportsTop = true, 
                    GroupByCapabilities = 4,  /* SQL_GB_NO_RELATION */
                    //FractionalSecondsScale = 3
                    SupportsNumericLiterals = true, 
                    SupportsStringLiterals = true, 
                    SupportsOdbcDateLiterals = true, 
                    SupportsOdbcTimeLiterals = true, 
                    SupportsOdbcTimestampLiterals = true, 
                    StringLiteralEscapeCharacters = {"\"}, 
                    Sql92Conformance = 8
                ], 
                SQLGetFunctions = [
					SQL_API_SQLBINDPARAMETER = false, 
					SQL_API_SQLBINDCOL = false
				]
            ])
	in
		OdbcDataSource;

BIConnector.ContentsType = 
	let
		type_dsnname = type text meta [
			Documentation.FieldCaption = "Enter the ODBC Data Source Name(DSN)*",
			Documentation.SampleValues = { "obiee-sales-reports" }
		],  
	
		CType = type function (dsnname as type_dsnname) as table
	in
		CType meta [
			Documentation.Description = "Enter connection information",
			Documentation.DisplayName = ModuleName,
			Documentation.Name = ModuleName,
			Documentation.Caption = ModuleName
		];
		
	
// Data Source Kind description
BIConnector = [
    Description = ModuleName, 
	TestConnection = (dataSourcePath) => 
        let
            json = Json.Document(dataSourcePath),
            dsnname = json[dsnname]   // name of function parameter
        in
            { "BIConnector.Contents", dsnname },    
	Authentication = [
		UsernamePassword = []
	], 
    Label = ModuleName
];

		
// Data Source UI publishing description
BIConnector.Publish = [
    ButtonText = {ModuleName, Extension.LoadString("ButtonHelp")}, 
    SourceImage = BIConnector.Icons, 
    SourceTypeImage = BIConnector.Icons, 
    Beta = false, 
    Category = "Database", 
    SupportsDirectQuery = true
];


BIConnector.Icons = [
    Icon16 = {
        Extension.Contents("BIConnector16.png"), 
        Extension.Contents("BIConnector20.png"), 
        Extension.Contents("BIConnector24.png"), 
        Extension.Contents("BIConnector32.png")
    }, 
    Icon32 = {
        Extension.Contents("BIConnector32.png"), 
        Extension.Contents("BIConnector40.png"), 
        Extension.Contents("BIConnector48.png"), 
        Extension.Contents("BIConnector64.png")
    }
];
