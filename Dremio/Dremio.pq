[Version = "3.7.2"]
section Dremio;

// When set to true, additional trace information will be written out to the User log. 
// This should be set to false before release. Tracing is done through a call to 
// Diagnostics.LogValue(). When EnableTraceOutput is set to false, the call becomes a 
// no-op and simply returns the original value.
EnableTraceOutput = false;

// Dremio Cloud only supports encryption enabled connections.
// Dremio Software supports encryption enabled connections by default. encryption can be disabled via a drop down box in the parameter screen. No autodetection of encryption is supported.
// Extension.CurrentCredential()[EncryptConnection] should not be used as it produces inconistent results between PBI Service and PBI Desktop/Gateway.
// See https://dremio.atlassian.net/browse/DX-47134

// Versions up to but excluding 3.0.0
[DataSource.Kind = "Dremio"]
shared Dremio.Databases = DremioDatabaseExport;

// Versions from 3.0.0 to 3.6.0
[DataSource.Kind = "Dremio"]
shared Dremio.DatabasesV300 = DremioDatabaseExportV300;

// Versions from 3.7.0 onwards
[DataSource.Kind = "Dremio", Publish = "Dremio.Publish"]
shared Dremio.DatabasesV370 = DremioDatabaseExportV370;

Dremio = [ 
    Type = "Custom", 
    // Supported formats:
    // server
    // server;encryption
    // encryption will be either "Enabled" or "Disabled"
    // encryption defaults to "Enabled" if not specified.
    MakeResourcePath = (server, optional encryption) =>
      let
        serverAndEncryption = server & ";" & encryption
      in
        if (encryption <> null) then
          serverAndEncryption
        else
          server,

    ParseResourcePath = (resourcePath as text) =>
      let
        values = Text.Split(resourcePath, ";"),
        encryption = values{1}? ?? "Enabled"
      in
        { values{0}, encryption },
    
    TestConnection = (resourcePath as text) => {"Dremio.DatabasesV300"} & ParseResourcePath(resourcePath), 
    Authentication = [
      UsernamePassword = [Name = "Dremio", Label = Extension.LoadString("AuthenticationLabel")],
      Aad = [
        AuthorizationUri = AADAuthorizationURI,
        Resource = AADSoftwareResource
      ]
    ], 
    DSRHandlers = [
      // Prior to version 3.0.0 the format is:
      // {"protocol":"dremio","address":{"server":"dremioServerAddress","schema":"dremioSchema","object":"dremioTable"}}
      // schema and object attributes are optional.

      // Version 3.0.0 onwards the format is:
      // {"protocol":"dremio","adddress":{"server":"dremioServerAddress","schema":"dremioSchema","object":"dremioTable","encryption":"Enabled/Disabled"}}
      // schema and object attributes are optional. encryption is optional and defaults to true.

      // This entry in DSRHandlers indicates that we handle the protocol named "dremio" in PBIDS files.
      #"dremio" = [
        // GetDSR takes in attributes based on the "address" attribute in the PBIDS file and holds a map that gets passed
        // into GetFormula and GetFriendlyName functions.
        GetDSR = (server, schema, object, encryption, optional options) => [ protocol = "dremio", address = [ server = server, schema = schema, object = object, encryption = encryption ] ],

        // GetFormula takes in the map (dsr) returned by GetDSR and returns an M formula that applies to the inputs of the DSR.
        // In this case, if we only supplied the server we return a formula to return the list of Databases and PBI opens the navigator there.
        // If we supplied the server and schema, we return a formula to get the list of tables at that schema and PBI opens the navigator there.
        // If we supplied the server, schema, and an object (table), we return the formula to access that table and PBI opens
        // a preview of the table.
        GetFormula = (dsr, optional options) => () => 
          let
            encrypted =
              if dsr[address][encryption]? = null then
                "Enabled"
              else
                dsr[address][encryption],
            // The order of parameters to Dremio.DatabasesV370 should match the parameter order specified in DremioDatabaseExportV370 Parameters.
            db = Dremio.DatabasesV370(dsr[address][server], encrypted),
            targetSchema = 
              if dsr[address][schema]? <> null then
                db{[Name=dsr[address][schema],Kind="Schema"]}[Data]
              else 
                null,

            targetTable = 
              if targetSchema <> null and dsr[address][object]? <> null then
                targetSchema{[Name=dsr[address][object],Kind="Table"]}[Data]
              else
                null,

            result = 
              if targetTable <> null then
                targetTable
              else if targetSchema <> null then
                targetSchema
              else 
                db
          in
            result,

        GetFriendlyName = (dsr) => "Dremio"
      ]
    ],
    // This disables built in support for encryption including the ability to update the encryption setting in the data source settings.
    // The user explicitly sets a separate required encryption parameter.
    SupportsEncryption = false,
    Icons = Dremio.Icons
];

Dremio.Publish = [
    ButtonText = {Extension.LoadString("DremioButtonTitle"), Extension.LoadString("ButtonHelp")}, 
    SourceImage = Dremio.Icons, 
    SourceTypeImage = Dremio.Icons, 
    Category = "Database", 
    SupportsDirectQuery = true,
    // Display Native Query navigating from the root of the DataSource
    NativeQueryProperties = [
      navigationSteps = {
        [
        ]
      },

      nativeQueryOptions = [
          EnableFolding = true
      ]
    ]
];

Dremio.Icons = [
    Icon16 = {
        Extension.Contents("Dremio16.png"),
        Extension.Contents("Dremio20.png"),
        Extension.Contents("Dremio24.png"),
        Extension.Contents("Dremio32.png")
    },
    Icon32 = {
        Extension.Contents("Dremio32.png"),
        Extension.Contents("Dremio40.png"),
        Extension.Contents("Dremio48.png"),
        Extension.Contents("Dremio64.png")
    }
];

DremioDatabaseExport = 
    let
        Function = (server as text, optional engine as text, optional routingTag as text, optional routingQueue as text) as table =>
          DremioDatabase(server, "Enabled", engine, routingTag, routingQueue),
        FunctionType = Type.ForFunction(
            [
                Parameters = [
                    server = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("SoftwareServerParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("SoftwareServerParameterSampleValues")}
                    ],
                    engine = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("EngineParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("EngineParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("EngineParameterSoftwareDescription")
                    ],
                    routingTag = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("RoutingTagParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("RoutingTagParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("RoutingTagParameterDescription")
                    ],
                    routingQueue = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("RoutingQueueParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("RoutingQueueParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("RoutingQueueParameterDescription")
                    ]
                ], 
                ReturnType = type table
            ], 
            1), // this value is the number of mandatory parameters defined in Function, ie not those marked as optional
        WithDocumentation = Value.ReplaceMetadata(
            FunctionType, 
            [
                Documentation.Name = "Dremio Software", 
                Documentation.LongDescription = Extension.LoadString("DremioDatabase_LongDescription"),
                Documentation.Examples = {[
                  Description = Extension.LoadString("ExampleDremioDescription"), 
                  Code = "Dremio.Databases(""localhost:31010"")",
                  Result = Extension.LoadString("ExampleDremioResult")
                ]}
            ])
    in
        Value.ReplaceType(Function, WithDocumentation);

DremioDatabaseExportV300 = 
    let
        Function = (server as text, encryption as text, optional engine as text, optional routingTag as text, optional routingQueue as text) as table =>
          DremioDatabase(server, encryption, engine, routingTag, routingQueue),
        FunctionType = Type.ForFunction(
            [
                Parameters = [
                    server = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("SoftwareServerParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("SoftwareServerParameterSampleValues")}
                    ],
                    encryption = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("SSLCaption"), 
                        Documentation.AllowedValues = {"Enabled", "Disabled", "Enabled-PEM"},
                        Documentation.FieldDescription = Extension.LoadString("SSLParameterDescription")
                    ],
                    engine = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("EngineParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("EngineParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("EngineParameterSoftwareDescription")
                    ],
                    routingTag = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("RoutingTagParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("RoutingTagParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("RoutingTagParameterDescription")
                    ],
                    routingQueue = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("RoutingQueueParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("RoutingQueueParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("RoutingQueueParameterDescription")
                    ]
                ], 
                ReturnType = type table
            ], 
            2), // this value is the number of mandatory parameters defined in Function, ie not those marked as optional
        WithDocumentation = Value.ReplaceMetadata(
            FunctionType, 
            [
                Documentation.Name = "Dremio Software", 
                Documentation.LongDescription = Extension.LoadString("DremioDatabase_LongDescription"),
                Documentation.Examples = {[
                  Description = Extension.LoadString("ExampleDremioDescriptionV300"), 
                  Code = "Dremio.DatabasesV300(""localhost:31010"",""Enabled"")",
                  Result = Extension.LoadString("ExampleDremioResult")
                ]}
            ])
    in
        Value.ReplaceType(Function, WithDocumentation);

DremioDatabaseExportV370 = 
    let
        Function = (server as text, encryption as text, optional engine as text, optional routingTag as text, optional routingQueue as text, optional options as record) as table =>
          DremioDatabase(server, encryption, engine, routingTag, routingQueue, options),
        FunctionType = Type.ForFunction(
            [
                Parameters = [
                    server = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("SoftwareServerParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("SoftwareServerParameterSampleValues")}
                    ],
                    encryption = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("SSLCaption"), 
                        Documentation.AllowedValues = {"Enabled", "Disabled", "Enabled-PEM"},
                        Documentation.FieldDescription = Extension.LoadString("SSLParameterDescription")
                    ],
                    engine = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("EngineParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("EngineParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("EngineParameterSoftwareDescription")
                    ],
                    routingTag = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("RoutingTagParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("RoutingTagParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("RoutingTagParameterDescription")
                    ],
                    routingQueue = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("RoutingQueueParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("RoutingQueueParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("RoutingQueueParameterDescription")
                    ],
                    options = (type record) meta []
                ], 
                ReturnType = type table
            ], 
            2), // this value is the number of mandatory parameters defined in Function, ie not those marked as optional
        WithDocumentation = Value.ReplaceMetadata(
            FunctionType, 
            [
                Documentation.Name = "Dremio Software", 
                Documentation.LongDescription = Extension.LoadString("DremioDatabase_LongDescription"),
                Documentation.Examples = {[
                  Description = Extension.LoadString("ExampleDremioDescriptionV300"), 
                  Code = "Dremio.DatabasesV370(""localhost:31010"",""Enabled"")",
                  Result = Extension.LoadString("ExampleDremioResult")
                ]}
            ])
    in
        Value.ReplaceType(Function, WithDocumentation);

DremioDatabase = (server as text, encryption as text, optional engine as text, optional routingTag as text, optional routingQueue as text, optional options as record) as table =>
    let
        Credential = Extension.CurrentCredential(),

		    // Create the connection string with host, port and optional properties.
        RoutingQueueOption =
          if routingQueue = null then
            ""
          else
            "routing_queue=" & routingQueue & ";",
        RoutingTagOption =
          if routingTag = null then
            ""
          else
            "routing_tag=" & routingTag & ";",
        EngineOption =
          if engine = null then
            ""
          else
            "engine=" & engine & ";",
        TokenOption = GetTokenOption(Credential[AuthenticationKind]?),

        optionalAdvancedProperties = RoutingQueueOption
              & RoutingTagOption
              & EngineOption
              & TokenOption,

        Database = DremioDatabaseCommon(server, optionalAdvancedProperties, DefaultSoftwarePort, encryption, options)
    in
        Database;

// For version 1.0.7
[DataSource.Kind = "DremioCloud"]
shared DremioCloud.Databases = DremioCloudDatabaseExport;

// For version 1.1.0 to 3.2.1
[DataSource.Kind = "DremioCloud"]
shared DremioCloud.DatabasesByServer = DremioCloudDatabaseByServerExport;

// For version 3.3.0 to 3.5.0
[DataSource.Kind = "DremioCloud"]
shared DremioCloud.DatabasesByServerV330 = DremioCloudDatabaseByServerExportV330;

// For version 3.6.0
[DataSource.Kind = "DremioCloud"]
shared DremioCloud.DatabasesByServerV360 = DremioCloudDatabaseByServerExportV360;

// For version 3.7.0 and later
[DataSource.Kind = "DremioCloud", Publish = "DremioCloud.Publish"]
shared DremioCloud.DatabasesByServerV370 = DremioCloudDatabaseByServerExportV370;

DremioCloud = [
    Type = "Custom", 
    // Supported formats
    // Dremio Cloud
    // Dremio Cloud: projectId
    // Dremio Cloud: projectId;server
    // Dremio Cloud: ;server
    MakeResourcePath = (projectId, optional server) => 
      let
        default = "Dremio Cloud",
        defaultWithSeparator = default & ": ",
        projectIdOnly = defaultWithSeparator & projectId,
        serverOnly = defaultWithSeparator & ";" & NormalizeServerName(server),
        projectIdAndServer = projectIdOnly & ";" & NormalizeServerName(server)
      in
        if (projectId <> null and server <> null) then
          projectIdAndServer
        else if (server <> null) then
          serverOnly
        else if (projectId <> null) then
          projectIdOnly
        else
          default,

    ParseResourcePath = (resourcePath as text) =>
      if (resourcePath = "Dremio Cloud") then
        { null, "sql.dremio.cloud" }
      else if (Text.StartsWith(resourcePath, "Dremio Cloud: " )) then
        let
          projectAndServer = Text.AfterDelimiter(resourcePath, "Dremio Cloud: "),
          values = Text.Split(projectAndServer, ";"),
          server = values{1}? ?? "sql.dremio.cloud",
          projectId = if (values{0} <> "") then values{0} else null
        in
          { projectId, server}
      else
        error "Unexpected resource path format",

    TestConnection = (resourcePath as text) => 
      let
        params = ParseResourcePath(resourcePath)
      in
        {"DremioCloud.DatabasesByServerV370", params{1}, params{0}},

    Authentication = [
      Aad = [
        AuthorizationUri = AADAuthorizationURI,
        Resource = AADCloudResource
      ],
      Key = [
        Label = Extension.LoadString("PATLabel"),
        KeyLabel = Extension.LoadString("PATKeyLabel")
      ]
    ], 
    DSRHandlers = [
      // Version 1.0.7
      // {"protocol":"dremiocloud","address":{"projectId":"project id","schema":"dremioSchema","object":"dremioTable"}}
      // schema and object attributes are optional.
      //
      // Version 1.1.0
      // {"protocol":"dremiocloud","address":{"server":"dremioServerAddress","projectId":"project id","schema":"dremioSchema","object":"dremioTable"}}
      // schema, object and projectId attributes are optional.

      // This entry in DSRHandlers indicates that we handle the protocol named "dremio" in PBIDS files.
      #"dremiocloud" = [
        // GetDSR takes in attributes based on the "address" attribute in the PBIDS file and holds a map that gets passed
        // into GetFormula and GetFriendlyName functions.
        GetDSR = (server, projectId, schema, object, optional options) => [ protocol = "dremio", address = [ server = server, projectId = projectId, schema = schema, object = object ] ],
        GetFormula = (dsr, optional options) => () => 
          let
            db =
              if dsr[address][server]? <> null then
                DremioCloud.DatabasesByServerV370(dsr[address][server], dsr[address][projectId])
              else
                DremioCloud.Databases(dsr[address][projectId]),

            targetSchema = 
              if dsr[address][schema]? <> null then
                db{[Name=dsr[address][schema],Kind="Schema"]}[Data]
              else 
                null,

            targetTable = 
              if targetSchema <> null and dsr[address][object]? <> null then
                targetSchema{[Name=dsr[address][object],Kind="Table"]}[Data]
              else
                null,

            result = 
              if targetTable <> null then
                targetTable
              else if targetSchema <> null then
                targetSchema
              else 
                db
          in
            result,

        GetFriendlyName = (dsr) => "DremioCloud"
      ]
    ],
    // This disables built in support for encryption. Encryption is always enabled.
    SupportsEncryption = false,
    Icons = Dremio.Icons
];

DremioCloud.Publish = [
    ButtonText = {Extension.LoadString("DremioCloudButtonTitle"), Extension.LoadString("ButtonHelp")}, 
    SourceImage = Dremio.Icons, 
    SourceTypeImage = Dremio.Icons, 
    Category = "Database", 
    SupportsDirectQuery = true,
    LearnMoreUrl = "https://docs.dremio.com/cloud/sonar/client-apps/microsoft-power-bi",
    // Display Native Query navigating from the root of the DataSource
    NativeQueryProperties = [
      navigationSteps = {
        [
        ]
      },

      nativeQueryOptions = [
          EnableFolding = true
      ]
    ]
];

DremioCloudDatabaseExport = 
    let
        Function = (projectId as text, optional engine as text) as table =>
          DremioCloudDatabase("sql.dremio.cloud:443", projectId, engine),
        FunctionType = Type.ForFunction(
            [
                Parameters = [
                    projectId = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("ProjectIdParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("ProjectIdParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("ProjectIdParameterDescription")
                    ],
                    engine = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("EngineParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("EngineParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("EngineParameterCloudDescription")
                    ]
                ], 
                ReturnType = type table
            ], 
            1), // this value is the number of mandatory parameters defined in Function, ie not those marked as optional
        WithDocumentation = Value.ReplaceMetadata(
            FunctionType, 
            [
                Documentation.Name = "Dremio Cloud", 
                Documentation.LongDescription = Extension.LoadString("DremioCloudDatabase_LongDescription"),
                Documentation.Examples = {[
                  Description = Extension.LoadString("ExampleDremioCloudDescription"), 
                  Code = "DremioCloud.Databases(""xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"")",
                  Result = Extension.LoadString("ExampleDremioCloudResult")
                ]}
            ])
    in
        Value.ReplaceType(Function, WithDocumentation);

NormalizeServerName = (server as text) as text => 
  if Text.PositionOf(server, " (") > 0 then
    Text.BeforeDelimiter(server, " ")
  else
    server;

// The order of parameters in Function should match the order in the Parameters list below.
DremioCloudDatabaseByServerExport = 
    let
        Function = (server as text, optional projectId as text, optional engine as text) as table =>
            DremioCloudDatabase(NormalizeServerName(server), projectId, engine),
        FunctionType = Type.ForFunction(
            [
                Parameters = [
                    server = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("CloudServerParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("CloudServerParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("CloudServerParameterDescription")
                    ],
                    projectId = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("ProjectIdParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("ProjectIdParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("ProjectIdParameterDescription")
                    ],
                    engine = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("EngineParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("EngineParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("EngineParameterCloudDescription")
                    ]
                ], 
                ReturnType = type table
            ], 
            1), // this value is the number of mandatory parameters defined in Function, ie not those marked as optional
        WithDocumentation = Value.ReplaceMetadata(
            FunctionType, 
            [
                Documentation.Name = "Dremio Cloud", 
                Documentation.LongDescription = Extension.LoadString("DremioCloudDatabaseByServer_LongDescription"),
                Documentation.Examples = {[
                  Description = Extension.LoadString("ExampleDremioCloudByServerDescription"), 
                  Code = "DremioCloud.DatabasesByServer(""sql.dremio.cloud:443"")",
                  Result = Extension.LoadString("ExampleDremioCloudByServerResult")
                ]}
            ])
    in
        Value.ReplaceType(Function, WithDocumentation);

// The order of parameters in Function should match the order in the Parameters list below.
DremioCloudDatabaseByServerExportV330 = 
    let
        Function = (server as text, optional projectId as text, optional engine as text, optional routingTag as text, optional routingQueue as text) as table =>
            DremioCloudDatabase(NormalizeServerName(server), projectId, engine, routingTag, routingQueue),
        FunctionType = Type.ForFunction(
            [
                Parameters = [
                    server = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("CloudServerParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("CloudServerParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("CloudServerParameterDescription")
                    ],
                    projectId = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("ProjectIdParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("ProjectIdParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("ProjectIdParameterDescription")
                    ],
                    engine = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("EngineParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("EngineParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("EngineParameterCloudDescription")
                    ],
                    routingTag = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("RoutingTagParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("RoutingTagParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("RoutingTagParameterCloudDescription")
                    ],
                    routingQueue = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("RoutingQueueParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("RoutingQueueParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("RoutingQueueParameterCloudDescription")
                    ]
                ], 
                ReturnType = type table
            ], 
            1), // this value is the number of mandatory parameters defined in Function, ie not those marked as optional
        WithDocumentation = Value.ReplaceMetadata(
            FunctionType, 
            [
                Documentation.Name = "Dremio Cloud", 
                Documentation.LongDescription = Extension.LoadString("DremioCloudDatabaseByServer_LongDescription"),
                Documentation.Examples = {[
                  Description = Extension.LoadString("ExampleDremioCloudByServerDescription"), 
                  Code = "DremioCloud.DatabasesByServerV330(""sql.dremio.cloud:443"")",
                  Result = Extension.LoadString("ExampleDremioCloudByServerResult")
                ]}
            ])
    in
        Value.ReplaceType(Function, WithDocumentation);

// The order of parameters in Function should match the order in the Parameters list below.
DremioCloudDatabaseByServerExportV360 = 
    let
        Function = (server as text, optional projectId as text, optional engine as text, optional routingTag as text, optional routingQueue as text, optional encryption as text) as table =>
            DremioCloudDatabase(NormalizeServerName(server), projectId, engine, routingTag, routingQueue, encryption),
        FunctionType = Type.ForFunction(
            [
                Parameters = [
                    server = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("CloudServerParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("CloudServerParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("CloudServerParameterDescription")
                    ],
                    projectId = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("ProjectIdParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("ProjectIdParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("ProjectIdParameterDescription")
                    ],
                    engine = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("EngineParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("EngineParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("EngineParameterCloudDescription")
                    ],
                    routingTag = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("RoutingTagParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("RoutingTagParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("RoutingTagParameterCloudDescription")
                    ],
                    routingQueue = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("RoutingQueueParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("RoutingQueueParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("RoutingQueueParameterCloudDescription")
                    ],
                    encryption = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("CloudSSLCaption"), 
                        Documentation.AllowedValues = {"Enabled-PEM"},
                        Documentation.FieldDescription = Extension.LoadString("CloudSSLParameterDescription")
                    ]
                ], 
                ReturnType = type table
            ], 
            1), // this value is the number of mandatory parameters defined in Function, ie not those marked as optional
        WithDocumentation = Value.ReplaceMetadata(
            FunctionType, 
            [
                Documentation.Name = "Dremio Cloud", 
                Documentation.LongDescription = Extension.LoadString("DremioCloudDatabaseByServer_LongDescription"),
                Documentation.Examples = {[
                  Description = Extension.LoadString("ExampleDremioCloudByServerDescription"), 
                  Code = "DremioCloud.DatabasesByServerV360(""sql.dremio.cloud:443"")",
                  Result = Extension.LoadString("ExampleDremioCloudByServerResult")
                ]}
            ])
    in
        Value.ReplaceType(Function, WithDocumentation);

// The order of parameters in Function should match the order in the Parameters list below.
DremioCloudDatabaseByServerExportV370 = 
    let
        Function = (server as text, optional projectId as text, optional engine as text, optional routingTag as text, optional routingQueue as text, optional encryption as text, optional options as record) as table =>
            DremioCloudDatabase(NormalizeServerName(server), projectId, engine, routingTag, routingQueue, encryption, options),
        FunctionType = Type.ForFunction(
            [
                Parameters = [
                    server = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("CloudServerParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("CloudServerParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("CloudServerParameterDescription")
                    ],
                    projectId = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("ProjectIdParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("ProjectIdParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("ProjectIdParameterDescription")
                    ],
                    engine = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("EngineParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("EngineParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("EngineParameterCloudDescription")
                    ],
                    routingTag = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("RoutingTagParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("RoutingTagParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("RoutingTagParameterCloudDescription")
                    ],
                    routingQueue = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("RoutingQueueParameterCaption"), 
                        Documentation.SampleValues = {Extension.LoadString("RoutingQueueParameterSampleValues")},
                        Documentation.FieldDescription = Extension.LoadString("RoutingQueueParameterCloudDescription")
                    ],
                    encryption = (type text) meta [
                        Documentation.FieldCaption = Extension.LoadString("CloudSSLCaption"), 
                        Documentation.AllowedValues = {"Enabled-PEM"},
                        Documentation.FieldDescription = Extension.LoadString("CloudSSLParameterDescription")
                    ],
                    options = (type record) meta []
                ], 
                ReturnType = type table
            ], 
            1), // this value is the number of mandatory parameters defined in Function, ie not those marked as optional
        WithDocumentation = Value.ReplaceMetadata(
            FunctionType, 
            [
                Documentation.Name = "Dremio Cloud", 
                Documentation.LongDescription = Extension.LoadString("DremioCloudDatabaseByServer_LongDescription"),
                Documentation.Examples = {[
                  Description = Extension.LoadString("ExampleDremioCloudByServerDescription"), 
                  Code = "DremioCloud.DatabasesByServerV370(""sql.dremio.cloud:443"")",
                  Result = Extension.LoadString("ExampleDremioCloudByServerResult")
                ]}
            ])
    in
        Value.ReplaceType(Function, WithDocumentation);

DremioCloudDatabase = (server as text, optional projectId as text, optional engine as text, optional routingTag as text, optional routingQueue as text, optional encryption as text, optional options as record) as table =>
    let
        Credential = Extension.CurrentCredential(),

		    // Create the connection string with host, port and optional properties.
        ProjectIdOption =
          if projectId = null then
            ""
          else
            "project_id=" & projectId & ";",
        EngineOption =
          if engine = null then
            ""
          else
            "engine=" & engine & ";",
        RoutingQueueOption =
          if routingQueue = null then
            ""
          else
            "routing_queue=" & routingQueue & ";",
        RoutingTagOption =
          if routingTag = null then
            ""
          else
            "routing_tag=" & routingTag & ";",
        TokenOption = GetTokenOption(Credential[AuthenticationKind]?),

        EncrytionOption =
          if encryption = null then
            "Enabled"
          else
            encryption,

        optionalAdvancedProperties = 
          ProjectIdOption
          & EngineOption
          & RoutingQueueOption
          & RoutingTagOption
          & TokenOption,

        Database = DremioDatabaseCommon(server, optionalAdvancedProperties, DefaultCloudPort, EncrytionOption, options)
    in
        Database;

DremioDatabaseCommon = (server as text, optionalAdvancedProperties as text, defaultPort as number, encryption as text, optional options as record) as table =>
    let

        // Advanced properties include quoting for Drill compatibility.
        AdvancedPropertiesText = 
            "CastAnyToVarchar=true;ConvertToCast=true;StringColumnLength=65536;"
              & optionalAdvancedProperties
              & "Quoting=DOUBLE_QUOTE",
        Address = GetAddress(server, defaultPort),
        HostAddress = Address[Host],
        HostPort = Address[Port],
        ConnectionString = [
            Driver = "Simba Drill ODBC Driver", 
            ConnectionType = "Direct", 
            Host = HostAddress, 
            Port = HostPort, 
            UseUnicodeSqlCharacterTypes = 1, 
            AdvancedProperties = AdvancedPropertiesText
        ],

        ExtraEncryptionProperties =
          if encryption = "Disabled" then
            [SSL = 0]
          else if (Text.PositionOf(server, "dremio.cloud") > 0) or (encryption = "Enabled-PEM") then
            [SSL = 1, Min_TLS = "1.2"]
          else
            [SSL = 1, UseSystemTrustStore = 1, Min_TLS = "1.2"],

        CredentialConnectionString = GetCredentialConnectionString,

        LocalOptions = [
            CredentialConnectionString = CredentialConnectionString & ExtraEncryptionProperties, 
            ClientConnectionPooling = true, 
            UseEmbeddedDriver = true,
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
                SupportsOdbcTimestampLiterals = true,
                Sql92Translation = "PassThrough"
            ],
            // Override the result of SQLGetInfo from the ODBC driver.
            // This is a list of type conversions required so that Power BI considers them valid
            // and can push down, for instance, group by, to Dremio rather than agregating data itself.
            // Left side of equation is Dremio type, right side is what it is converted to in PBI.
            SQLGetInfo = [
                SQL_CONVERT_DECIMAL = 0x80 // SQL_CVT_DOUBLE
            ],
                    // SQL_CATALOG_NAME required to be "Y" by PowerBI
                    // SQL_CATALOG_NAME = "Y",
                    // Disabling all uses of catalog name in SQL statements
                    //SQL_CATALOG_USAGE = 0
            SQLGetFunctions = [SQL_API_SQLBINDPARAMETER = false, SQL_CONVERT_FUNCTIONS = 0x2], 
                    // Disable parameters because they produce errors when used in certain parts of the AST.
            AstVisitor = [
                LimitClause = (skip, take) =>
                    if skip = 0 and take = null then
                      error Extension.LoadString("NoopSkipTakeError")
                    else
                      let
                        // OFFSET is not supported without LIMIT. Emit a large number instead.
                        take = 
                          if take = null then
                            4611686018427387903
                          else
                            take
                        in
                            [Text = Text.Format("OFFSET #{0} ROWS FETCH FIRST #{1} ROWS ONLY", {skip, take}), Location = "AfterQuerySpecification"]
            ],
            // Override the result of SQLGetTypeInfo from the ODBC driver.
            // The types argument is a table representing the driver's result.
            // This is to let us alter how unicode SQL type data is reported to fix
            // problems using non-ASCII data in report filters.
            // This code is tightly coupled to what the driver reports in SQLGetTypeInfo.
            SQLGetTypeInfo = (types) => 
                let
                    // Data type codes for wide types from ODBC sqlucode.h
                    SQL_WVARCHAR = -9,
                    SQL_WCHAR = -8,

                    // Filter out SQL_WVARCHAR and SQL_WCHAR rows from SQLGetTypeInfo
                    typesWithoutWideChars = Table.SelectRows(types, each [DATA_TYPE] <> -8 and [DATA_TYPE] <> -9),

                    // Use the entries for WVARCHAR and WCHAR types as a template.
                    wvarcharRow = types{[TYPE_NAME = "WVARCHAR"]},
                    wcharRow = types{[TYPE_NAME = "WCHAR"]},

                    // Rewrite the typenames for WVARCHAR and WCHAR types to VARCHAR and CHAR respectively.
                    modifiedWvarcharRow = wvarcharRow & [TYPE_NAME = "VARCHAR", LOCAL_TYPE_NAME = "VARCHAR"],
                    modifiedWcharRow = wcharRow & [TYPE_NAME = "CHAR", LOCAL_TYPE_NAME = "CHAR"],

                    // Add back the modified rows to the output.
                    finalTable = typesWithoutWideChars & Table.FromRecords({modifiedWvarcharRow, modifiedWcharRow})
                in
                    finalTable
        ],
        // Merge local options with any user defined options.
        Options =
          if options = null then
            LocalOptions
          else
            LocalOptions & options,
        Database = Odbc.DataSource(ConnectionString, Options){0}[Data]
    in
        Database;

GetCredentialConnectionString =
  let 
    Credential = Extension.CurrentCredential()
  in
    if Credential[AuthenticationKind]? = "UsernamePassword" then 
      [UID = Credential[Username], PWD = Credential[Password], AuthenticationType = "Plain"]
    else if Credential[AuthenticationKind]? = "OAuth" then
      [UID = "", PWD = Credential[access_token], AuthenticationType = "Plain"]
    else if Credential[AuthenticationKind]? = "Key" then
      [UID = "", PWD = Credential[Key], AuthenticationType = "Plain"]
    else 
      [AuthenticationType = "No Authentication"];

GetTokenOption = (authKind as text) as text =>
  if authKind = "Key" then
    "token_type=personal_access_token;"
  else if authKind = "OAuth" then
    "token_type=jwt;"
  else
    "";

GetAddress = (server as text, defaultPort as number) as record =>
    let
        Address = Uri.Parts(server),
        BadServer = Address[Host] = "" or Address[Path] <> "/" or Address[Query] <> [] or Address[Fragment] <> "" or Address[UserName] <> "" or Address[Password] <> "",
        Host = Address[Host],

        // Determine ODBC port
        Port = 
          if (Address[Port] = 80 and (not Text.EndsWith(server, ":80")))
             or (Address[Port] = 443 and (not Text.EndsWith(server, ":443")))
             or Address[Port]? = null or Address[Port] = ""  then
            defaultPort
          else
            Address[Port],

        Result = [Host = Host, Port = Port]
    in
        if BadServer then
          error Extension.LoadString("InvalidServerNameError")
        else
          Result;

ErrorHandler = (errorRecord as record) =>
    let
        OdbcError = errorRecord[Detail][OdbcErrors]{0},
        OdbcErrorMessage = OdbcError[Message],
        OdbcErrorCode = OdbcError[NativeError],
        // Error code 40 is the auth error DRClientAuthenticationFailure in DRMessages.xml
        HasCredentialError = OdbcErrorCode = 40,
        Credential = Extension.CurrentCredential()
    in
        if errorRecord[Reason] = DataSourceMissingClientLibrary then
                    error Error.Record(
                        DataSourceMissingClientLibrary,
                        Extension.LoadString("DriverNotInstalledError"))
        else if HasCredentialError then
            error Extension.CredentialError(Credential.AccessDenied, OdbcErrorMessage)
        else 
            error errorRecord;

// Default ODBC ports. This is used if the port is not entered by the user. 
DefaultSoftwarePort = 31010;
DefaultCloudPort = 443;
DataSourceMissingClientLibrary = "DataSource.MissingClientLibrary";
AADAuthorizationURI = "https://login.microsoftonline.com/common/oauth2/authorize";
AADSoftwareResource = "429333a8-1521-4502-9101-6d4f2c1de644";
AADCloudResource = "https://analysis.windows.net/powerbi/connector/Dremio";

// 
// Load common library functions
// 
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = if (EnableTraceOutput) then Diagnostics[LogValue] else (prefix, value) => value;
