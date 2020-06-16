// This file contains your Data Connector logic
[Version = "1.0.0"]
section Vena;


[DataSource.Kind="Vena", Publish="Vena.Publish"]
shared Vena.Contents = Value.ReplaceType(VenaImpl, VenaInputs);

// Defines the inputs the connector expects 
VenaInputs = type function (
    source as (type text meta [
        Documentation.FieldCaption = "Source Region",
        Documentation.FieldDescription = "The Region Where Your Vena Data Is Hosted.",
        Documentation.AllowedValues = {
            //For drop down options
            "https://ca3.vena.io",
            "https://us3.vena.io",
            "https://us2.vena.io",
            "https://us1.vena.io",
            "https://eu1.vena.io"
        }
    ]),        
    optional modelQuery as (type text meta [
        Documentation.FieldCaption = "Model Query",
        Documentation.FieldDescription = "MQL Query For Your Hierarchies/Intersections.            " 
                                          & "Leaving This Field Blank Will Retrieve All Members And Intersections.",
        Documentation.SampleValues = { "dimension(..." }//Suggested input
    ])) 
    as table meta [
        Documentation.Name = "Vena",
        Documentation.LongDescription = "Vena"
    ];

VenaImpl = (source as text, optional modelQuery as text) as table =>
    let
        VenaBasic = 
        let
            Credentials = Extension.CurrentCredential(),
            apiUser = Credentials[Username],
            apiKey = Credentials[Password],
            b64 = Binary.ToText(Text.ToBinary(apiUser & ":" & apiKey), 0)
        in
            "VenaBasic " & b64,

        CodeDTO = CodeDTO.Fetch(),
        Main = Expression.Evaluate(CodeDTO[Main.pqm], #shared),
        Utils = Expression.Evaluate(CodeDTO[Utils.pqm], #shared),
        result = Main(source, VenaBasic, Utils, modelQuery)
    in
        result;


CodeDTO.Fetch = () => [
                        Main.pqm = Text.FromBinary(Extension.Contents("Main.pqm")),
                        Utils.pqm = Text.FromBinary(Extension.Contents("Utils.pqm"))
                      ];

// Data Source Kind description
Vena = [
    TestConnection = (dataSourcePath) =>
    let
        json = Json.Document(dataSourcePath),
        source = json[source],
        modelId = json[modelId]
    in
        {"Vena.Contents", source, modelId},

    Authentication = [
        UsernamePassword = [
            UsernameLabel = "apiUser",
            PasswordLabel = "apiKey",
            Label = "Application Token"
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
Vena.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = Vena.Icons,
    SourceTypeImage = Vena.Icons
];

Vena.Icons = [
    Icon16 = { Extension.Contents("Vena16.png"), Extension.Contents("Vena20.png"), Extension.Contents("Vena24.png"), Extension.Contents("Vena32.png") },
    Icon32 = { Extension.Contents("Vena32.png"), Extension.Contents("Vena40.png"), Extension.Contents("Vena48.png"), Extension.Contents("Vena64.png") }
];
