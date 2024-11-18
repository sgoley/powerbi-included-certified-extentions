// This file contains your Data Connector logic
[Version = "1.0.1"]
section AptixInsights;

windowWidth = 800;
windowHeight = 800;

[DataSource.Kind = "AptixInsights", Publish = "AptixInsights.Publish"]
shared AptixInsights.Feed = Value.ReplaceType(AptixInsightsImpl, AptixInsightsType);

ValidateUrlScheme = (url as text) as text =>
    if (Uri.Parts(url)[Scheme] <> "https") then
        error "Url scheme must be HTTPS"
    else
        url;

AptixInsightsType = type function (
    url as (
        type text meta [
            Documentation.FieldCaption = Extension.LoadString("UrlFieldCaption"),
            Documentation.FieldDescription = Extension.LoadString("UrlFieldDescription"),
            Documentation.SampleValues = {Extension.LoadString("UrlExample")}
        ]
    ),
    optional query as (
        type any meta [
            Documentation.FieldCaption = Extension.LoadString("QueryFieldCaption"),
            Documentation.FieldDescription = Extension.LoadString("QueryFieldDescription"),
            Documentation.SampleValues = {Extension.LoadString("QueryExample")}
        ]
    )
) as table meta [
    Documentation.Name = Extension.LoadString("ConnectorName"),
    Documentation.LongDescription = Extension.LoadString("ConnectorDescription")
];

AptixInsightsImpl = (url as text, optional query as any) =>
    let
        credential = Extension.CurrentCredential(),
        token = credential[Key],
        headers = [Authorization = "Bearer " & token],
        serviceOptions = [
            Implementation = "2.0",
            MoreColumns = true,
            ODataVersion = 4,
            Query = if query = null then [] else query
        ],
        //add the query string record option
        url = ValidateUrlScheme(url),
        source = OData.Feed(url, headers, serviceOptions)
    in
        source;

// Data Source Kind description
AptixInsights = [
    // enable JWT Key based auth
    TestConnection = (dataSourcePath) => {"AptixInsights.Feed", Json.Document(dataSourcePath)[url]},
    Authentication = [
        Key = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
AptixInsights.Publish = [
    Beta = true,
    Category = "Online Services",
    ButtonText = {Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp")},
    LearnMoreUrl = Extension.LoadString("LearnMoreUrl"),
    SourceImage = AptixInsights.Icons,
    SourceTypeImage = AptixInsights.Icons
];

AptixInsights.Icons = [
    Icon16 = {
        Extension.Contents("AptixInsights16.png"),
        Extension.Contents("AptixInsights20.png"),
        Extension.Contents("AptixInsights24.png"),
        Extension.Contents("AptixInsights32.png")
    },
    Icon32 = {
        Extension.Contents("AptixInsights32.png"),
        Extension.Contents("AptixInsights40.png"),
        Extension.Contents("AptixInsights48.png"),
        Extension.Contents("AptixInsights64.png")
    }
];
