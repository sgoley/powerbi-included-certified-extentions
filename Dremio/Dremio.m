[Version = "1.0.2"]
section Dremio;

[DataSource.Kind = "Dremio", Publish = "Dremio.Publish"]
shared Dremio.Databases = DremioDatabaseExport;

Dremio = [ 
    Type = "Custom", 
    MakeResourcePath = (server) => server, 
    ParseResourcePath = (resourcePath as text) => {resourcePath}, 
    TestConnection = (resourcePath as text) => {"Dremio.Databases"} & ParseResourcePath(resourcePath), 
    Authentication = [UsernamePassword = [Name = "Dremio", Label = Extension.LoadString("AuthenticationLabel")], Implicit = []], 
    SupportsEncryption = true,
    Icons = Dremio.Icons
];

Dremio.Publish = [
    ButtonText = {Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp")}, 
    SourceImage = Dremio.Icons, 
    SourceTypeImage = Dremio.Icons,
    Category = "Database", 
    SupportsDirectQuery = true
];

Dremio.Icons = [
        //Label = Extension.LoadString("Label"), // Dremio
    Icon16 = {
        Extension.Contents("dremio16.png"), 
        Extension.Contents("dremio20.png"), 
        Extension.Contents("dremio24.png"), 
        Extension.Contents("dremio32.png")
    }, 
    Icon32 = {
        Extension.Contents("dremio32.png"), 
        Extension.Contents("dremio40.png"), 
        Extension.Contents("dremio48.png"), 
        Extension.Contents("dremio64.png")
    }
];

DremioDatabase = (server as text) as table =>
    let
			// Create the connection string with constants, host and port
        Address = GetAddress(server),
        HostAddress = Address[Host],
        HostPort = Address[Port],
        ConnectionString = [
            Driver = "Dremio Connector", 
            ConnectionType = "Direct", 
            Host = HostAddress, 
            Port = HostPort, 
            UseUnicodeSqlCharacterTypes = 1, 
            AdvancedProperties = "CastAnyToVarchar=true;ConvertToCast=true;StringColumnLength=65536;"
        ],
        Credential = Extension.CurrentCredential(),
        RequireEncryption = if Credential[EncryptConnection]? = null
            then 1
            else if Credential[EncryptConnection] = true
                then 1 
                else 0,        
        ExtraEncryptionProperties = if RequireEncryption = 1
            then [SSL = 1, UseSystemTrustStore = 1, Min_TLS = "1.2"]
            else [SSL = 0],        
        CredentialConnectionString = if Credential[AuthenticationKind]? = "UsernamePassword" then [UID = Credential[Username], PWD = Credential[Password], AuthenticationType = "Plain"]
             else [AuthenticationType = "No Authentication"],
        Options = [
            CredentialConnectionString = CredentialConnectionString & ExtraEncryptionProperties, 
            ClientConnectionPooling = true, 
            UseEmbeddedDriver = false,  // TODO: Change this to true once driver is embedded
            HierarchicalNavigation = true, 
            HideNativeQuery = true, 
            OnError = ErrorHandler,
            SqlCapabilities = [
                    //SupportsTop = true,
                Sql92Conformance = 8,  // SQL_SC_SQL92_FULL
                GroupByCapabilities = 4,  // SQL_GB_NO_RELATION

                    // Make sure literals are enabled so that it doesn't use bind parameters (question marks) which Dremio doesn't support
                SupportsNumericLiterals = true, 
                SupportsStringLiterals = true, 
                StringLiteralEscapeCharacters = {"'"}, 
                SupportsOdbcDateLiterals = true, 
                SupportsOdbcTimeLiterals = true, 
                SupportsOdbcTimestampLiterals = true
            ], 
            SQLGetInfo = [], 
                    // SQL_CATALOG_NAME required to be "Y" by PowerBI
                    // SQL_CATALOG_NAME = "Y",
                    // Disabling all uses of catalog name in SQL statements
                    //SQL_CATALOG_USAGE = 0
            SQLGetFunctions = [SQL_API_SQLBINDPARAMETER = false, SQL_CONVERT_FUNCTIONS = 0x2], 
                    // Disable parameters because they produce errors when used in certain parts of the AST.
            AstVisitor = [
                LimitClause = (skip, take) =>
                    if skip = 0 and take = null then error "no-op skip take."
                         else let
                                // OFFSET is not supported without LIMIT. Emit a large number instead.
                            take = if take = null then 4611686018427387903
                                 else take
                        in
                            [Text = Text.Format("OFFSET #{0} ROWS FETCH FIRST #{1} ROWS ONLY", {skip, take}), Location = "AfterQuerySpecification"]
            ]
        ],
        OdbcDataSource = Odbc.DataSource(ConnectionString, Options),
        Database = OdbcDataSource{0}[Data] // Or replace {0} with {[Name = "DREMIO"]}
    in
        Database;

GetAddress = (server as text) as record =>
    let
        Address = Uri.Parts("http://" & server),
        BadServer = Address[Host] = "" or Address[Scheme] <> "http" or Address[Path] <> "/" or Address[Query] <> [] or Address[Fragment] <> "" or Address[UserName] <> "" or Address[Password] <> "",
        Port = if Address[Port] = 80 and (not Text.EndsWith(server, ":80")) then DefaultPort
             else Address[Port],
        Host = Address[Host],
        Result = [Host = Host, Port = Port]
    in
        if BadServer then error Extension.LoadString("InvalidServerNameError")
             else Result;

ErrorHandler = (errorRecord as record) =>
    let
        OdbcError = errorRecord[Detail][OdbcErrors]{0},
        OdbcErrorMessage = OdbcError[Message],
        OdbcErrorCode = OdbcError[NativeError],
        // Error code 40 is the auth error DRClientAuthenticationFailure in DRMessages.xml
        HasCredentialError = OdbcErrorCode = 40,
        // All error codes containing SSL in DSMessages.xml and DRMessages.xml
        SSLErrorCodes = {1040, 1050, 1080, 1090, 1100, 1110, 1120, 1130, 1140, 1150, 2070},
        IsSSLError = List.Contains(SSLErrorCodes, OdbcErrorCode)
    in
        if HasCredentialError then
            error Extension.CredentialError(Credential.AccessDenied, OdbcErrorMessage)
        else 
            if IsSSLError then 
                error Extension.CredentialError(Credential.EncryptionNotSupported, OdbcErrorMessage)
            else 
                error errorRecord;

DefaultPort = 31010;

DremioDatabaseExport = 
    let
        Function = (server as text) as table => DremioDatabase(server),
        FunctionType = Type.ForFunction(
            [
                Parameters = [
                    server = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("ServerParameterCaption"), 
                        Documentation.SampleValues = {"hostname:port"}
                    ]
                ], 
                ReturnType = type table
            ], 
            1),
        WithDocumentation = Value.ReplaceMetadata(
            FunctionType, 
            [
                Documentation.Name = "Dremio", 
                Documentation.Caption = Extension.LoadString("FormulaTitle"), 
                Documentation.Description = Extension.LoadString("DremioDatabase_Description"), 
                Documentation.LongDescription = Text.Format(Extension.LoadString("DremioDatabase_LongDescription"), {"server"}), 
                Documentation.Examples = [Description = Extension.LoadString("ExampleDremioDescription"), Code = "Dremio.Databases(""localhost:31010"")"]
            ])
    in
        Value.ReplaceType(Function, WithDocumentation);

