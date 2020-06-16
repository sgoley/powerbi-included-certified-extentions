// Data Connector logic for Cognite Data Fusion.
[Version = "1.0.0"]
section Cognite;

WindowWidth = 1200;
WindowHeight = 1000;

BaseUrl = "https://api.cognitedata.com/odata/v1/projects/";

[DataSource.Kind="Cognite", Publish="Cognite.UI"]
shared Cognite.Contents = Value.ReplaceType(CogniteImpl, CogniteType);

CogniteType = type function (
    project as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("ProjectName"),
        Documentation.FieldDescription = Extension.LoadString("ProjectDescription"),
        Documentation.SampleValues = {"publicdata"}
    ]))
    as table meta [
        Documentation.Name = Extension.LoadString("CogniteDataFusion"),
        Documentation.LongDescription = Extension.LoadString("CogniteDataFusion")
    ];

// Data Source Kind description.
Cognite = [
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            project = json[project]
        in
            { "Cognite.Contents", project },
    Authentication = [
        Key = [
            KeyLabel = Extension.LoadString("ApiKey"),
            Label = Extension.LoadString("ApiKey")
        ]
    ]
];

// Data Source UI publishing description
Cognite.UI = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://docs.cognite.com/",
    SourceImage = Cognite.Icons,
    SourceTypeImage = Cognite.Icons
];

Cognite.Icons = [
    Icon16 = { Extension.Contents("CDF 16x16.png"), Extension.Contents("CDF 20x20.png"), Extension.Contents("CDF 24x24.png"), Extension.Contents("CDF 32x32.png") },
    Icon32 = { Extension.Contents("CDF 32x32.png"), Extension.Contents("CDF 40x40.png"), Extension.Contents("CDF 48x48.png"), Extension.Contents("CDF 64x64.png") }
];


CogniteImpl = (project as text) =>
    let
        current = Extension.CurrentCredential()[AuthenticationKind],

        AuthHeaders =
            if current = "Key" then
                let
                    key = Extension.CurrentCredential()[Key]
                in
                    [ #"api-key"=key, Authorization="" ]
            else
                [],

        //set expected headers for API
        source = OData.Feed(BaseUrl & project, null, [Concurrent=true, Implementation="2.0", MaxUriLength=8192, Headers=AuthHeaders])
    in
        source;
