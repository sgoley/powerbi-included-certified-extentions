[Version = "1.1.1"]
section IRIS;

Config_SqlConformance = ODBC[SQL_SC][SQL_SC_SQL92_FULL];
Config_UseParameterBindings = false; 
Config_StringLiterateEscapeCharacters  = { "\" };
Config_UseCastInsteadOfConvert = null;
Config_SupportsTop = true; 
EnableTraceOutput = false;

Config_DriverName = "InterSystems IRIS ODBC35";

[DataSource.Kind="IRIS"]
shared IRIS.Database = Value.ReplaceType(IRISImpl, IRISType);

IRIS = [
    Description = Extension.LoadString("DataSourceLabel"),
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            host = json[host],
            port = json[port],
            namespace = json[namespace]
        in
            { "IRIS.Database", host, port, namespace},
    Authentication = [
        UsernamePassword = []
        // Windows = []
        // Implicit = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

IRISType = type function (
        host as (type text meta [
            Documentation.FieldCaption = "Host (IP Address)",
            Documentation.FieldDescription = "InterSystems IRIS Host IP Address",
            Documentation.SampleValues = {"localhost"}
        ]),
        port as (type number meta [
            Documentation.FieldCaption = "Port",
            Documentation.FieldDescription = "InterSystems IRIS Port",
            Documentation.SampleValues = {"51773"}
        ]),
        namespace as (type text meta [
            Documentation.FieldCaption = "Namespace",
            Documentation.FieldDescription = "InterSystems IRIS Namespace",
            Documentation.SampleValues = {"USER"}
        ]),
        optional ssl as (type text meta [
            Documentation.FieldCaption = "Connect over SSL/TLS",
            Documentation.FieldDescription = "If set to Yes, connection will be over SSL/TLS",
            Documentation.AllowedValues = { "Yes", "No" },
            Documentation.DefaultValue = { "No" }
        ]),
        optional logs as (type text meta [
            Documentation.FieldCaption = "Enable ODBC Logs",
            Documentation.FieldDescription = "If set to Yes, ODBC logs will be recorded",
            Documentation.AllowedValues = { "Yes", "No" },
            Documentation.DefaultValue = { "No" }
        ])
    ) 
    as table meta [
        Documentation.Name = "InterSystems IRIS",
        Documentation.LongDescription = "InterSystems IRIS"
    ];

IRISImpl = (host as text, port as number, namespace as text, optional ssl as text, optional logs as text) as table =>
    let
        _ssl = if ssl = "Yes" then "Y" else "N",
        _logs = if logs = "Yes" then "Y" else "N",

        ConnectionString =
        [
            DRIVER = Config_DriverName,
            SERVER = host,
            PORT = port,
            DATABASE = namespace
        ],
        
        Credential = Extension.CurrentCredential(),

		CredentialConnectionString =
            if Credential[AuthenticationKind]? = "UsernamePassword" then
                // set connection string parameters used for basic authentication
                [ UID = Credential[Username], PWD = Credential[Password] ]
            else if (Credential[AuthenticationKind]? = "Windows") then
                // set connection string parameters used for windows/kerberos authentication
                [ Trusted_Connection = "Yes" ]
            else
                error Error.Record("Error", "Unhandled authentication kind: " & Credential[AuthenticationKind]?),
        
        // Configuration options for the call to Odbc.DataSource
        defaultConfig = BuildOdbcConfig(),

        SqlCapabilities = defaultConfig[SqlCapabilities] & [
            // place custom overrides here
            FractionalSecondsScale = 3
        ],

        SQLGetTypeInfo = (types) => 
            if (EnableTraceOutput <> true) then types else
            let
                // Outputting the entire table might be too large, and result in the value being truncated.
                // We can output a row at a time instead with Table.TransformRows()
                rows = Table.TransformRows(types, each Diagnostics.LogValue("SQLGetTypeInfo " & _[TYPE_NAME], _)),
                toTable = Table.FromRecords(rows)
            in
                Value.ReplaceType(toTable, Value.Type(types)), 

        SQLColumns = (catalogName, schemaName, tableName, columnName, source) =>
            if (EnableTraceOutput <> true) then source else
            // the if statement conditions will force the values to evaluated/written to diagnostics
            if (Diagnostics.LogValue("SQLColumns.TableName", tableName) <> "***" and Diagnostics.LogValue("SQLColumns.ColumnName", columnName) <> "***") then
                let
                    // Outputting the entire table might be too large, and result in the value being truncated.
                    // We can output a row at a time instead with Table.TransformRows()
                    rows = Table.TransformRows(source, each Diagnostics.LogValue("SQLColumns", _)),
                    toTable = Table.FromRecords(rows)
                in
                    Value.ReplaceType(toTable, Value.Type(source))
            else
                source,

        OdbcDataSource = Odbc.DataSource(ConnectionString, [
            CredentialConnectionString = CredentialConnectionString,
            CreateNavigationProperties = true,
            // A logical (true/false) that sets whether to view the tables grouped by their schema names
            HierarchicalNavigation = true, 
            // Prevents execution of native SQL statements. Extensions should set this to true.
            HideNativeQuery = true,
            // Allows upconversion of numeric types
            SoftNumbers = true,
            // Allow upconversion / resizing of numeric and string types
            TolerateConcatOverflow = true,
            // Enables connection pooling via the system ODBC manager
            ClientConnectionPooling = true,

            SqlCapabilities = [
                SupportsTop = true,
                Sql92Conformance = 8,
                SupportsNumericLiterals = true,
                SupportsStringLiterals = true,
                SupportsOdbcDateLiterals = true,
                SupportsOdbcTimeLiterals = true,
                SupportsOdbcTimestampLiterals = true
            ],
            SQLColumns = SQLColumns
        ]),

        // 1. hide system tables
        removeSystemSchemas = FilterSystemSchemas(OdbcDataSource),

        // 2. build list of BI cubes
        cubeList = GetCubeList(ConnectionString),
        cubeSchema = if Table.RowCount(cubeList) > 0 
                        then BuildCubeSchema(removeSystemSchemas, cubeList, ConnectionString) 
                        else #table({"Name","Key","IsLeaf"},{{"no cubes found","no data",true}}),

        // 3. build list of tables, excluding the ones in a cube package
        tableSchema = if Table.RowCount(cubeList) > 0  
                        then FilterNonCubeSchemas(removeSystemSchemas, cubeList)
                        else removeSystemSchemas,

        // 4. Return tables and cubes as separate list
        DatabaseItems = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                // hide full ODBC catalog
                // {"Database", "database", OdbcDataSource, "Database", "Database", false},
                {"Tables", "tables", tableSchema, "Folder", "Folder", false},
                {"Cubes", "cubes", cubeSchema, "CubeViewFolder", "CubeViewFolder", false}
            }
        ),
        Metadata = Value.Metadata(Value.Type(Database)),
        Database = Table.ToNavigationTable(DatabaseItems, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        Database;

// build settings based on configuration variables
BuildOdbcConfig = () as record =>
    let        
        defaultConfig = [
            SqlCapabilities = [],
            SQLGetFunctions = [],
            SQLGetInfo = []
        ],

        withParams =
            if (Config_UseParameterBindings = false) then
                let 
                    caps = defaultConfig[SqlCapabilities] & [ 
                        SqlCapabilities = [
                            SupportsNumericLiterals = true,
                            SupportsStringLiterals = true,                
                            SupportsOdbcDateLiterals = true,
                            SupportsOdbcTimeLiterals = true,
                            SupportsOdbcTimestampLiterals = true
                        ]
                    ],
                    funcs = defaultConfig[SQLGetFunctions] & [
                        SQLGetFunctions = [
                            SQL_API_SQLBINDPARAMETER = false
                        ]
                    ]
                in
                    defaultConfig & caps & funcs
            else
                defaultConfig,
                
        withEscape = 
            if (Config_StringLiterateEscapeCharacters <> null) then 
                let
                    caps = withParams[SqlCapabilities] & [ 
                        SqlCapabilities = [
                            StringLiteralEscapeCharacters = Config_StringLiterateEscapeCharacters
                        ]
                    ]
                in
                    withParams & caps
            else
                withParams,

        withTop =
            let
                caps = withEscape[SqlCapabilities] & [ 
                    SqlCapabilities = [
                        SupportsTop = Config_SupportsTop
                    ]
                ]
            in
                withEscape & caps,

        withCastOrConvert = 
            if (Config_UseCastInsteadOfConvert = true) then
                let
                    caps = withTop[SQLGetFunctions] & [ 
                        SQLGetFunctions = [
                            SQL_CONVERT_FUNCTIONS = 0x2 /* SQL_FN_CVT_CAST */
                        ]
                    ]
                in
                    withTop & caps
            else
                withTop,

        withSqlConformance =
            if (Config_SqlConformance <> null) then
                let
                    caps = withCastOrConvert[SQLGetInfo] & [
                        SQLGetInfo = [
                            SQL_SQL_CONFORMANCE = Config_SqlConformance
                        ]
                    ]
                in
                    withCastOrConvert & caps
            else
                withCastOrConvert
    in
        withSqlConformance;

// Load common library functions
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = if (EnableTraceOutput) then Diagnostics[LogValue] else (prefix, value) => value;

// OdbcConstants contains numeric constants from the ODBC header files, and a 
// helper function to create bitfield values.
ODBC = Extension.LoadFunction("OdbcConstants.pqm");
Odbc.Flags = ODBC[Flags];

/****Catalog Functions****/

// Hides system tables from the supplied schema nav table
FilterSystemSchemas = (schema as table) =>
    let
        // TODO: more aggressive filtering
    in 
        Table.SelectRows(schema, each not Text.StartsWith([Name], "Ens"));


// Hides cube packages from supplied schema nav table
FilterNonCubeSchemas = (schema as table, cubeList as table) =>
    let
        PackageList = Table.ToList(Table.SelectColumns(cubeList, "PackageName"))
    in 
        Table.SelectRows(schema, each not List.Contains(PackageList, [Name]));


// Builds the BI cube schema based on the full ODBC catalog supplied with <schema>
// and the BI cube metadata supplied with <cubeList>
BuildCubeSchema = (schema as table, cubeList as table, ConnectionString as record) =>
    let
        // filter to packages we're interested in
        PackageList = Table.ToList(Table.SelectColumns(cubeList, "PackageName")),
        FilteredSchema = Table.SelectRows(schema, each List.Contains(PackageList, [Name])),

        // apply cube-level metadata for each [Name] = package name
        NameColumnType = Type.TableColumn(Value.Type(FilteredSchema), "Name"),
        AddPrettyNameColumn = Table.AddColumn(FilteredSchema, "PrettyName", each GetCubeInfoFromList([Name], "DisplayName", cubeList), NameColumnType),
        AddCubeNameColumn = Table.AddColumn(AddPrettyNameColumn, "CubeName", each GetCubeInfoFromList([Name], "CubeName", cubeList), NameColumnType),
        AddKeyColumn = Table.AddColumn(AddCubeNameColumn, "Key", each [Name], NameColumnType),
        AddIsLeafColumn = Table.AddColumn(AddKeyColumn, "IsLeaf", each false),

        DataColumnType = Type.TableColumn(Value.Type(AddIsLeafColumn), "Data"),
        AddTempDataColumn = Table.AddColumn(AddIsLeafColumn, "TempData", each if [Name]="___warning" then Table.FromRecords({}) else BuildCubeItemSchema([Data], [CubeName], [Name], ConnectionString), DataColumnType),
        RemoveOldDataColumn = Table.RemoveColumns(AddTempDataColumn, { "Data" }),
        RenameCubeItems = Table.RenameColumns(RemoveOldDataColumn, { { "TempData", "Data" } }),
        
        // finish up package-level info
        RemoveOldNameColumn = Table.RemoveColumns(RenameCubeItems, { "Name", "CubeName" }),
        RenameColumn = Table.RenameColumns(RemoveOldNameColumn, { { "PrettyName", "Name" } }),

        // transform Kind
        CubeSchema = UpdateKind(RenameColumn,"Cube"),

        // append warning message if catalog queries unavailable
        FullCubeSchema = if Table.Contains(cubeList,[CubeName="___warning"])
                        then Table.InsertRows(CubeSchema, 0, {[Name = " "&Extension.LoadString("WarningNoCatalogQueries"), 
                                                                 Description = Extension.LoadString("WarningNoCatalogQueries"), 
                                                                 Key = "___warning", Data = Table.FromRecords({}), IsLeaf = true, Kind = "Folder"]})
                        else CubeSchema
    in
        FixNavigationTable(FullCubeSchema);

// translates a package name into the corresponding cubeList column ("DisplayName" or "CubeName")
GetCubeInfoFromList = (packageName as text, field as text, cubeList as table) =>
    let
        cubeRow = Table.First(Table.SelectRows(cubeList, each [PackageName] = packageName)),
        cubeName = Record.Field(cubeRow, field)
    in
        cubeName;

// Helper function to update the Kind column from whichever value it has to <kind>
UpdateKind = (schema as table, kind as text) =>
    let
        ColumnType = Type.TableColumn(Value.Type(schema), "Kind"),
        AddTempKindColumn = Table.AddColumn(schema, "TempKind", each kind, ColumnType),
        RemoveOldKindColumn = Table.RemoveColumns(AddTempKindColumn, { "Kind" }),
        RenameColumn = Table.RenameColumns(RemoveOldKindColumn, { { "TempKind", "Kind" } })
    in 
        RenameColumn;

UpdateDimensionColumns = (data as table, packageName as text, tableName as text, ConnectionString as record) =>
    let
        dimensionColumns = GetCubeItemColumnsList(Text.Combine({packageName,tableName},"."), ConnectionString),

        // filter to the list of columns returned by the catalog
        columnList = Table.TransformRows(dimensionColumns, each [ColumnName]),
        removedColumns = Table.SelectColumns(data, columnList),

        // rename based on catalog DisplayNames
        renameList = Table.TransformRows(dimensionColumns, each { [ColumnName], [DisplayName]}),
        transformedColumns = Table.RenameColumns(removedColumns, renameList, MissingField.UseNull)
    in
        transformedColumns;

// Build fact and dimension schema
BuildCubeItemSchema = (schema as table, cubeName as text, packageName as text, ConnectionString as record) => 
    let
        // exclude Listing table
        FilteredSchema = Table.SelectRows(schema, each [Name] <> "Listing"),

        // retrieve fact and dimension table display names
        resultCubeItemList = try GetCubeItemsList(cubeName, packageName, ConnectionString),
        cubeTables = if resultCubeItemList[HasError] then Table.FromRecords({}) else resultCubeItemList[Value],
        hasCubeItems = Table.RowCount(cubeTables) > 0,
        
        // populate column-level metadata fact and dimension table
        DataColumnType = Type.TableColumn(Value.Type(schema), "Data"),
        UpdateSchema = Table.AddColumn(FilteredSchema, "MetaData", each UpdateDimensionColumns([Data], packageName, [Name], ConnectionString), DataColumnType),
        RemoveOldDataColumn = Table.RemoveColumns(UpdateSchema, { "Data" }),
        RenameDataColumn = Table.RenameColumns(RemoveOldDataColumn, { { "MetaData", "Data" } }),
        
        // apply display names
        NameColumnType = Type.TableColumn(Value.Type(schema), "Name"),
        KindColumnType = Type.TableColumn(Value.Type(schema), "Kind"),
        AddPrettyNameColumn = if hasCubeItems 
            then Table.AddColumn(RenameDataColumn, "PrettyName", each GetDimInfoFromList([Name], cubeTables, "DisplayName"), NameColumnType)
            else Table.AddColumn(FilteredSchema, "PrettyName", each [Name], NameColumnType),
        AddKeyColumn = Table.AddColumn(AddPrettyNameColumn, "Key", each [Name], NameColumnType),
        AddIsLeafColumn = Table.AddColumn(AddKeyColumn, "IsLeaf", each true),
        //AddKindColumn = Table.AddColumn(AddIsLeafColumn, "NewKind", each GetDimInfoFromList([Name], cubeTables, "Type"), KindColumnType),
        RemoveOldColumns = Table.RemoveColumns(AddIsLeafColumn, { "Name" }),
        RenameCubeItems = Table.RenameColumns(RemoveOldColumns, { { "PrettyName", "Name" } })
        //RenameCubeItems2 = Table.RenameColumns(RenameCubeItems, { { "NewKind", "Kind" } })
    in
        FixNavigationTable(RenameCubeItems);


GetDimInfoFromList = (tableName as text, cubeItemList as table, field as text) =>
    let
        dimRow = Table.SingleRow(Table.SelectRows(cubeItemList, each List.Last(Text.Split([TableName], ".")) = tableName))
    in
        Record.Field(dimRow, field);


/****\Catalog Functions****/

/****Class Query Functions****/

// Retrieves column-level metadata for a given dimension or fact table
// Note: %DeepSee.SQL.CatalogQueries is only available from IRIS 2019.2. Tries DeepSee.SQL.CatalogQueries if absent
GetCubeItemColumnsList = (dimensionTable as text, ConnectionString as record) as table =>
    let
        // first try to fetch cube-level metadata from %DeepSee.SQL.CatalogQueries API (2019.2+)
        columnsAPI = try Table.Buffer(Odbc.Query(ConnectionString, "SELECT * FROM %DeepSee_SQL.GetDimensionColumns('" & dimensionTable & "')")),
        // if this fails, try to fetch from DeepSee.SQL.CatalogQueries API (imported patch)
        columnsPatch = if columnsAPI[HasError] 
            then try Table.Buffer(Odbc.Query(ConnectionString, "SELECT * FROM DeepSee_SQL.GetDimensionColumns('" & dimensionTable & "')"))
            else columnsAPI,
        // if that fails too (regular 2019.1-), fallback to pseudo prettiness
        columns = if columnsPatch[HasError] 
            then try Odbc.Query(ConnectionString, "SELECT COLUMN_NAME AS ColumnName, CASE WHEN SUBSTRING(COLUMN_NAME,1,2) IN ('Dx','Mx','Px') THEN SUBSTRING(COLUMN_NAME,3) ELSE COLUMN_NAME END DisplayName, 'unknown' AS Type, '' AS ""References"" FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = '"& Text.BeforeDelimiter(dimensionTable,".") &"' AND TABLE_NAME = '"& Text.AfterDelimiter(dimensionTable,".") &"' AND SUBSTRING(COLUMN_NAME,1,1) != '%' AND NOT (COLUMN_NAME %MATCHES 'Dx[0-9]*' OR COLUMN_NAME %MATCHES 'Mx[0-9]*' OR COLUMN_NAME %MATCHES 'Dx*Fx*')")
            else columnsPatch
    in
        if columns[HasError] then error columns[Error] else columns[Value];

// Retrieves table-level metadata (fact & dimension tables) for a given cube
// Note: %DeepSee.SQL.CatalogQueries is only available from IRIS 2019.2. Tries DeepSee.SQL.CatalogQueries if absent
GetCubeItemsList = ( cubeName as text, packageName as text, ConnectionString as record) as table =>
    let
        // first try to fetch cube-level metadata from %DeepSee.SQL.CatalogQueries API (2019.2+)
        cubeItemsAPI = try Table.Buffer(Odbc.Query(ConnectionString, "SELECT * FROM %DeepSee_SQL.GetDimensionTables('" & cubeName & "') ORDER BY TableName DESC")),
        // if this fails, try to fetch from DeepSee.SQL.CatalogQueries API (imported patch)
        cubeItemsPatch = if cubeItemsAPI[HasError] 
            then try Table.Buffer(Odbc.Query(ConnectionString, "SELECT * FROM DeepSee_SQL.GetDimensionTables('" & cubeName & "') ORDER BY TableName DESC"))
            else cubeItemsAPI,
        // if that fails too (regular 2019.1-), fallback to pseudo prettiness
        cubeItems = if cubeItemsPatch[HasError] 
            then try Odbc.Query(ConnectionString, "SELECT TABLE_SCHEMA||'.'||TABLE_NAME AS TableName, CASE WHEN SUBSTRING(TABLE_NAME,1,2)='Dx' THEN 'Dimension: '||$PIECE($PIECE(SUBSTRING(TABLE_NAME,3),'Via',1),'Rg',1) WHEN SUBSTRING(TABLE_NAME,1,4)='Star' THEN 'Dimension: '||$PIECE($PIECE(SUBSTRING(TABLE_NAME,5),'Via',1),'Rg',1) WHEN TABLE_NAME='Fact' THEN 'Fact: "& cubeName &"' ELSE TABLE_NAME END AS DisplayName, CASE WHEN TABLE_NAME='Fact' THEN 'Fact' ELSE 'Dimension' END AS Type FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '" & packageName & "' AND TABLE_NAME != 'Listing'") 
            else cubeItemsPatch
    in
        if cubeItems[HasError] then error cubeItems[Error] else cubeItems[Value];

// Retrieves base list of cubes for this namespace
// Note: %DeepSee.SQL.CatalogQueries is only available from IRIS 2019.2. 
//          Falls back to patch or %DeepSee.ClassQueries if absent (which includes possibly unsupported features)
GetCubeList = (ConnectionString as record) as table =>
    let
        // first try to fetch cube-level metadata from %DeepSee.SQL.CatalogQueries API (2019.2+)
        cubesAPI = try Table.Buffer(Odbc.Query(ConnectionString, "SELECT * FROM %DeepSee_SQL.GetCubes()")),
        // if this fails, try to fetch from DeepSee.SQL.CatalogQueries API (imported patch)
        cubesPatch = if cubesAPI[HasError] 
            then try Table.Buffer(Odbc.Query(ConnectionString, "SELECT * FROM DeepSee_SQL.GetCubes()"))
            else cubesAPI,
        // if that fails too (regular 2019.1-), fallback to %DeepSee.ClassQueries_EnumerateCubes()
        cubes = if cubesPatch[HasError] 
            then try Table.InsertRows(
                        Odbc.Query(ConnectionString, "SELECT Name As CubeName, ClassName, Name AS DisplayName, REPLACE(ClassName,'.','_') AS PackageName FROM %DeepSee.ClassQueries_EnumerateCubes()"),
                       0,{[DisplayName="___warning",PackageName="___warning",CubeName="___warning",ClassName="___warning"]})
            else cubesPatch
    in
        if cubes[HasError] then error cubes[Error] else cubes[Value];
        

/****\Class Query Functions****/

/****Common library code****/

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
            NavigationTable.IsLeafColumn = isLeafColumn, 
            NavigationTable.IsSelectedColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

FixNavigationTable = (table) =>
    let
        SelectColumns = Table.SelectColumns(table, { "Name", "Data", "Kind", "Key" }),
        OriginalType = Value.Type(SelectColumns),
        Type = type table [
            Name = Type.TableColumn(OriginalType, "Name"),
            Data = Type.TableColumn(OriginalType, "Data"),
            Kind = Type.TableColumn(OriginalType, "Kind"),
            Key = Type.TableColumn(OriginalType, "Key")
        ],
        AddKey = Type.AddTableKey(Type, { "Key" }, true),
        AddMetadata = AddKey meta [
            NavigationTable.NameColumn = "Name",
            NavigationTable.DataColumn = "Data",
            NavigationTable.KindColumn = "Kind",
            Preview.DelayColumn = "Data"
        ],
        ReplaceType = Value.ReplaceType(SelectColumns, AddMetadata)
    in
        ReplaceType;

/****\Common library code****/
