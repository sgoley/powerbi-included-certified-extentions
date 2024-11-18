[Version = "1.0.1"]
section InformationGrid;

[DataSource.Kind = "InformationGrid", Publish = "InformationGrid.Publish"]
shared InformationGrid.Contents = Value.ReplaceType(InformationGridImpl, InformationGridType);

InformationGridType = type function (
    server as (
        type text meta [
            Documentation.FieldCaption = Extension.LoadString("ServerFieldCaption"),
            Documentation.FieldDescription = Extension.LoadString("ServerFieldDescription"),
            Documentation.SampleValues = {"igserver.somedomain.com", "192.168.1.123"}
        ]
    )
) as table meta [
    Documentation.Name = Extension.LoadString("FunctionName"),
    Documentation.LongDescription = Extension.LoadString("FunctionDescription"),
    Documentation.Examples = {
        [
            Description = Extension.LoadString("ExampleDescription1"),
            Code = Extension.LoadString("ExampleCode1"),
            Result = Extension.LoadString("ExampleResult1")
        ],
        [
            Description = Extension.LoadString("ExampleDescription2"),
            Code = Extension.LoadString("ExampleCode2"),
            Result = Extension.LoadString("ExampleResult2")
        ]
    }
];

InformationGridImpl = (server as text) as table =>
    let
        // Get the service list
        protocolServer = (if (Text.StartsWith(Text.Lower(server), "http://")) then server else "https://" & server),
        baseUrl = protocolServer & "/ig/rest/ig-bi-service/",
        serviceListUrl = baseUrl & "service-list",
        token = "Bearer " & Extension.CurrentCredential()[Key],
        options = [
            Headers = [#"Authorization" = token],
            ManualCredentials = true
        ],
        serviceListSource = Web.Contents(serviceListUrl, options),
        serviceListJson = Json.Document(serviceListSource, 65001),
        // 65001 = UTF-8
        serviceList = serviceListJson[services],
        // Create the navigation table on the basis of the service list
        servicesTable = Table.FromColumns({serviceList}, {"Service"}),
        servicesTable1 = Table.AddColumn(
            servicesTable,
            "Data",
            each () => GetServiceData(baseUrl & "retrieve/" & [Service] & "?biClient=powerbi", options),
            type function
        ),
        servicesTable2 = Table.AddColumn(servicesTable1, "ItemKind", each "Table", type text),
        //        servicesTable3 = Table.AddColumn(servicesTable2, "ItemName", each "Table", type text),
        servicesTable3 = servicesTable2,
        servicesTable4 = Table.AddColumn(servicesTable3, "IsLeaf", each true, type logical),
        // Using the Data column as the Preview.DelayColumn is a workaround to stop service data being loaded until selected
        // in the preview.  See https://github.com/Microsoft/DataConnectors/issues/30
        servicesNavTable = Table.ToNavigationTable(
            servicesTable4, {"Service"}, "Service", "Data", "ItemKind", "Data", "IsLeaf"
        )
    in
        servicesNavTable;

// Performs a service query and transforms results into a fully typed table
GetServiceData = (url as text, options as record) as table =>
    let
        // get the raw service data from the IF service, and transform from JSON into M data structures.
        rawData = Web.Contents(url, options),
        jsonData = Json.Document(rawData, 65001),
        // extract the schema information from the data, and construct the corresponding M table type from it
        schema = jsonData[schema],
        tableType = GetTypeFromSchema(schema),
        // extract the data, transform into a table.
        tableData = Table.FromRecords(jsonData[items], tableType, MissingField.UseNull),
        // Apply the type information to the data table
        typedData = Table.ChangeType(tableData, tableType)
    in
        typedData;

// Creates the M table type required by Table.ChangeType
// This takes the schema record as received from IG, with class names as field names and class schema records as values
GetTypeFromSchema = (schema as record) as type =>
    let
        // creates a [Name, Value] table with Name = class name and Value = class schema record
        classNameAndSchema = Record.ToTable(schema),
        // transforms Value column into corresponding record type.
        // Note that result table from this step is passed (partially constructed) into transform function.
        classNameAndType = Table.TransformColumns(
            classNameAndSchema, {"Value", (classSchema) => GetClassType(classSchema, @classNameAndType)}
        ),
        // get type from last row, which is always top level type
        topType = Table.Last(classNameAndType)[Value],
        // transform into a table type
        topTableType = type table topType
    in
        topTableType;

// Creates a record type describing one class
// Takes class schema record as received from IG, and (partially constructed) table of class names and types
GetClassType = (classSchema as record, classNameAndType as table) as type =>
    let
        // creates a [Name, Value] table with Name = property name and Value = property type text, e.g. "Text", "Int64", etc..
        classSchemaTable = Record.ToTable(classSchema),
        // transforms Value column to record required by Type.ForRecord, e.g. [Type = Text.Type, Optional = false]
        classTypeTable = Table.TransformColumns(
            classSchemaTable, {"Value", (typeName) => GetPropertyTypeRecord(typeName, classNameAndType)}
        ),
        // creates a record with property names as field names, records for Type.ForRecord as field values
        classTypeRecord = Record.FromTable(classTypeTable),
        // creates a type describing the class
        classType = Type.ForRecord(classTypeRecord, false)
        // false = closed record - can't add fields
    in
        classType;

// This creates a type record as required by Type.ForRecord from type name from IG and the class to type table constructed so far
GetPropertyTypeRecord = (typeName as text, classNameAndType as table) as record =>
    let
        itemType =
            if (typeName = "Text") then
                type nullable Text.Type
            else if (typeName = "Int32") then
                type nullable Int32.Type
            else if (typeName = "Int64") then
                type nullable Int64.Type
            else if (typeName = "Logical") then
                type nullable Logical.Type
            else if (typeName = "Single") then
                type nullable Single.Type
            else if (typeName = "Double") then
                type nullable Double.Type
            else if (typeName = "Currency") then
                type nullable Currency.Type
            else if (typeName = "Decimal") then
                type nullable Decimal.Type
            else if (typeName = "Date") then
                type nullable Date.Type
            else if (typeName = "DateTime") then
                type nullable DateTime.Type
            else if (typeName = "Any") then
                type nullable Any.Type
            else if (typeName = "Record") then
                type nullable Record.Type
            else if (typeName = "Int32") then
                type nullable Int32.Type
            else
                let
                    // it's an embedded type. Get class name and determine whether it's an array/list
                    isList = Text.StartsWith(typeName, "{"),
                    className = if (isList) then Text.Middle(typeName, 1) else typeName,
                    // Retrieve row for class from table, and extract the type.  Use Any if not found
                    classType = try classNameAndType{[Name = className]}[Value] otherwise type nullable Any.Type,
                    // Convert to a list type if required, making nullable also
                    finalType = if (isList) then type nullable {classType} else type nullable classType
                in
                    finalType,
        // Finally construct the record required by Type.ForRecord
        typeRecord = [Type = itemType, Optional = false]
        // All fields must be non optional to make a table out of it
    in
        typeRecord;

// Data Source Kind description
InformationGrid = [
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath), server = json[server]
        in
            {"InformationGrid.Contents", server},
    Authentication = [
        Key = [
            KeyLabel = Extension.LoadString("AuthKeyLabel"),
            Label = Extension.LoadString("AuthLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
InformationGrid.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = {Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp")},
    LearnMoreUrl = "https://www.luminis.eu/",
    SourceImage = InformationGrid.Icons,
    SourceTypeImage = InformationGrid.Icons
];

InformationGrid.Icons = [
    Icon16 = {
        Extension.Contents("InformationGrid16.png"),
        Extension.Contents("InformationGrid20.png"),
        Extension.Contents("InformationGrid24.png"),
        Extension.Contents("InformationGrid32.png")
    },
    Icon32 = {
        Extension.Contents("InformationGrid32.png"),
        Extension.Contents("InformationGrid40.png"),
        Extension.Contents("InformationGrid48.png"),
        Extension.Contents("InformationGrid64.png")
    }
];

//
// Load common library functions
//
// TEMPORARY WORKAROUND until we're able to reference other M modules
//
// This and the Diagnostics module were copied from following URL. Some modifications were made.
//    https://github.com/Microsoft/DataConnectors/tree/master/samples/TripPin/8-Diagnostics
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");

Diagnostics.LogValue = Diagnostics[LogValue];
Diagnostics.LogFailure = Diagnostics[LogFailure];

//
// This and the Table.* modules were copied from following URL. Some modifications were made.
//    https://github.com/Microsoft/DataConnectors/tree/master/samples/TripPin/7-AdvancedSchema
//
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name), asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Table.ChangeType = Extension.LoadFunction("Table.ChangeType.pqm");
Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");
