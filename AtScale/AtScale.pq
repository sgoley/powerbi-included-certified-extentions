[Version = "3.0.4"]
section AtScale;

// =============================================================================
// = AtScale
// =============================================================================
[DataSource.Kind="AtScale", Publish="AtScale.Publish"]
shared AtScale.Cubes = Value.ReplaceType(AtScaleImpl, AtScaleType);

AtScale = [
    TestConnection = (resourcePath as text) => { "AtScale.Cubes", resourcePath },
    Authentication = [
        UsernamePassword = [
            Name = "AtScale",
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ]
];

AtScaleImpl = (server as text, optional options as record) => AtScaleImpl2(server, options);

AtScaleImpl2 = (server as text, optional options as record) =>
    Extension.InvokeWithCredentials(
         (datasource) => Extension.CurrentCredential(),        
         () => 
            let
                CubeDataSource = AnalysisServices.Databases(server, ValidateOptions(options) & [Implementation = "2.0"])
            in
                CubeDataSource
    );

AtScaleType = type function (
    server as (Uri.Type meta [
        Documentation.FieldCaption = Extension.LoadString("ServerParameterCaption"),
        Documentation.FieldDescription = Extension.LoadString("ServerParameterDescription"),
        Documentation.SampleValues = {"https://contoso.atscale.com:10502/xmla/..."}
    ]),
    optional options as (type [optional ConnectionTimeout = nullable duration, optional CommandTimeout = nullable duration] meta [
        Documentation.FieldCaption = Extension.LoadString("OptionsParameterCaption"),
        Documentation.FieldDescription = Extension.LoadString("OptionsParameterDescription")
    ]))
    as table meta [
        Documentation.Name = Extension.LoadString("Label"),
        Documentation.Caption = Extension.LoadString("FormulaTitle"),
        Documentation.Description = Extension.LoadString("AtScaleCubes_Description"),
        Documentation.LongDescription = Extension.LoadString("AtScaleCubes_LongDescription"),
        Documentation.Examples = [
            Description = Extension.LoadString("AtScaleCubes_ExampleDescription"),
            Code = "AtScale.Cubes(""https://contoso.atscale.com:10502/xmla/..."")"
        ]
    ];

AtScale.Publish = [
    Name = "AtScale",
    Category = "Database",
    ButtonText = {
        Extension.LoadString("ButtonTitle"),
        Extension.LoadString("ButtonHelp")
    },
    LearnMoreUrl = "https://www.atscale.com/",
    SourceImage = AtScale.Icons,
    SourceTypeImage = AtScale.Icons,
    MultiDimensionalStyle = "SingleFlatTable",
    SupportsDirectQuery = true
];

AtScale.Icons = [
    Icon16 = {
        Extension.Contents("AtScale16.png"),
        Extension.Contents("AtScale20.png"),
        Extension.Contents("AtScale24.png"),
        Extension.Contents("AtScale32.png")
    },
    Icon32 = {
        Extension.Contents("AtScale32.png"),
        Extension.Contents("AtScale40.png"),
        Extension.Contents("AtScale48.png"),
        Extension.Contents("AtScale64.png")
    }
];

ValidateOptions = (options) as record =>
    let
        ValidOptionsMap = #table({"Name","Type","Default","Validate"},
                                {{"ConnectionTimeout", type nullable duration, null, each _ = null or _ >= Duration.From(0.0)},
                                 {"CommandTimeout", type nullable duration, null, each _ = null or _ >= Duration.From(0.0)},
                                 {"TypedMeasureColumns", type nullable logical, false, each _ = null or _ = true or _ = false}}),
        ValidKeys = Table.Column(ValidOptionsMap, "Name"),
        InvalidKey = List.First(List.Difference(Record.FieldNames(options), ValidKeys)),
        InvalidKeyText = Text.Format(Extension.LoadString("InvalidOptionsKey"), {InvalidKey, Text.Combine(ValidKeys, ",")}),
        ValidateValue = (name, optionType, default, validate, value) =>
                if (value is null and (Type.IsNullable(optionType) or default <> null))
                    or (Type.Is(Value.Type(value), optionType) and validate(value)) then null
                else Text.Format(Extension.LoadString("InvalidOptionsValue"), {name, value}),
        InvalidValues = List.RemoveNulls(Table.TransformRows(ValidOptionsMap, 
                each ValidateValue([Name],[Type],[Default],[Validate], Record.FieldOrDefault(options, [Name], [Default])))),
        DefaultOptions = Record.FromTable(Table.RenameColumns(Table.SelectColumns(ValidOptionsMap,{"Name","Default"}),{"Default","Value"})),
        NullNotAllowedFields = List.RemoveNulls(Table.TransformRows(ValidOptionsMap,
                each if not Type.IsNullable([Type]) and null = Record.FieldOrDefault(options, [Name], [Default]) then [Name] else null)),
        NormalizedOptions = DefaultOptions & Record.RemoveFields(options, NullNotAllowedFields, MissingField.Ignore),
        Result = if null = options then DefaultOptions
                 else if null <> InvalidKey then
                     error Error.Record("Expression.Error", InvalidKeyText)
                 else if not List.IsEmpty(InvalidValues) then
                     error Error.Record("Expression.Error", List.First(InvalidValues))
                 else NormalizedOptions
    in
        Result;

// =============================================================================
// = Constants for magic numbers / strings.
// =============================================================================
