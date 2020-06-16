// This file contains your Data Connector logic
[Version = "1.0.2"]
section JethroODBC;
 
 
DefaultPort = 21050;
AnonymousAuthMech = 0;
UsernamePasswordAuthMech = 3;
 
[DataSource.Kind="JethroODBC", Publish="JethroODBC.UI"]

shared JethroODBC.Database = (server as text, database as text, optional options as record) as table =>
	let
		Address = GetAddress(server),
		HostAddress = Address[Host],
		HostPort = Address[Port],
		ConnectionString = [
			Driver = "JethroODBCDriver",
			Host = HostAddress,
			Port = HostPort,
			// We need a database name that doesn't exist in the server, because if the user doesn't have access to
			// "default", it throws an exception. Specifying a DB that doesn't exist works fine, though.
			Database = database,
			UseUnicodeSqlCharacterTypes = 0
		],
 
		Credential = Extension.CurrentCredential(),
		CredentialConnectionString = if Credential[AuthenticationKind]? = "UsernamePassword" then [
				UID = Credential[Username], 
				PWD = Credential[Password], 
				AuthMech = UsernamePasswordAuthMech]
			else [AuthMech = AnonymousAuthMech],
		CommonOptions = [
			CredentialConnectionString = CredentialConnectionString,
			ClientConnectionPooling = true,
			OnError = OnError
		],
		OdbcDatasource = Odbc.DataSource(ConnectionString,
			[
			HierarchicalNavigation = true,
			TolerateConcatOverflow = true,
			SqlCapabilities = [
				SupportsTop = true,
				Sql92Conformance = 8,
				GroupByCapabilities = 2 /* SQL_GB_GROUP_BY_CONTAINS_SELECT  */,
				FractionalSecondsScale = 3,
				SupportsNumericLiterals = true,
				SupportsStringLiterals = true,
				SupportsOdbcDateLiterals = true,
				SupportsOdbcTimeLiterals = true,
				SupportsOdbcTimestampLiterals = true
			],
			SoftNumbers = true,
			HideNativeQuery = true,
			SQLGetInfo = [
				//SQL_SQL92_PREDICATES = 0x0000FFFF,
				//SQL_AGGREGATE_FUNCTIONS = 0xFF
				// SQL_CONVERT_FUNCTIONS = 0  ==> does not seem to work...

			],
             SQLGetFunctions = [
                // Disable using parameters in the queries that get generated.
                // We enable numeric and string literals which should enable literals for all constants.
                SQL_API_SQLBINDPARAMETER = false
            ]
		] & CommonOptions),
			
		ComplexColumnsRemoved = OdbcDatasource{[Name=database]}[Data]
	in
		ComplexColumnsRemoved;
 

			
 
OnError = (errorRecord as record) =>
	let
		OdbcError = errorRecord[Detail][OdbcErrors]{0},
		OdbcErrorMessage = OdbcError[Message],
		OdbcErrorCode = OdbcError[NativeError],
		HasCredentialError = errorRecord[Detail] <> null
			and errorRecord[Detail][OdbcErrors]? <> null
			and Text.Contains(OdbcErrorMessage, "[ThriftExtension]")
			and OdbcErrorCode <> 0 and OdbcErrorCode <> 7
	in
		if HasCredentialError then
			error Extension.CredentialError(Credential.AccessDenied, OdbcErrorMessage)
		else 
			error errorRecord;
 
GetAddress = (server as text) as record =>
	let
		Address = Uri.Parts("http://" & server),
		BadServer = Address[Host] = "" or Address[Scheme] <> "http" or Address[Path] <> "/" or Address[Query] <> [] or Address[Fragment] <> ""
			or Address[UserName] <> "" or Address[Password] <> "",
		Port = if Address[Port] = 80 and not Text.EndsWith(server, ":80") then 
				DefaultPort 
			else Address[Port],
		Host = Address[Host],
		Result = [Host=Host, Port=Port]
	in
		if BadServer then 
			error "Invalid server name"
		else Result;
 
JethroODBC = [
	Authentication = [
		UsernamePassword = []
	],
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            server = json[server],
            database = json[database]
        in
            { "JethroODBC.Database", server,database},
	SupportsEncryption = false
];
 
JethroODBC.UI = [
	Beta = true,
	Category = "Database",
	ButtonText = { Extension.LoadString("UIButtonText"), Extension.LoadString("UIButtonHover")},
	SupportsDirectQuery = true,
    LearnMoreUrl = "https://jethro.io/",
	SourceImage = JethroODBC.Icons,
	SourceTypeImage = JethroODBC.Icons
];


// next section is kept for reference 

// Data Source UI publishing description
// JethroODBC.Publish = [
// 	Beta = false,
// 	Category = "Other",
// 	ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
// 	LearnMoreUrl = "https://powerbi.microsoft.com/",
// 	SourceImage = JethroODBC.Icons,
// 	SourceTypeImage = JethroODBC.Icons
// ];
//  

JethroODBC.Icons = [
	Icon16 = { Extension.Contents("JethroDataConnector16.png"), Extension.Contents("JethroDataConnector20.png"), Extension.Contents("JethroDataConnector24.png"), Extension.Contents("JethroDataConnector32.png") },
	Icon32 = { Extension.Contents("JethroDataConnector32.png"), Extension.Contents("JethroDataConnector40.png"), Extension.Contents("JethroDataConnector48.png"), Extension.Contents("JethroDataConnector64.png") }
];