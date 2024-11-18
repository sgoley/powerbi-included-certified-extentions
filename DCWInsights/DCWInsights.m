// This file contains your Data Connector logic
[Version = "1.0.2"]
section DCWInsights;

windowWidth = 800;
windowHeight = 800;

[DataSource.Kind="DCWInsights", Publish="DCWInsights.Publish"]
shared DCWInsights.Feed = Value.ReplaceType(DCWInsightsImpl, DCWInsightsType);
 
 ValidateUrlScheme = (url as text) as text => if (Uri.Parts(url)[Scheme] <> "https") then error "Url scheme must be HTTPS" else url;

 DCWInsightsType = type function(url as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("UrlFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("UrlFieldDescription"),
        Documentation.SampleValues = {Extension.LoadString("UrlExample")}
    ]), optional query as (type any meta[
        Documentation.FieldCaption = Extension.LoadString("QueryFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("QueryFieldDescription"),
        Documentation.SampleValues = {Extension.LoadString("QueryExample")}
        ])) as table meta [ Documentation.Name = Extension.LoadString("ConnectorName"),
        Documentation.LongDescription = Extension.LoadString("ConnectorDescription")];

DCWInsightsImpl = (url as text, optional query as any) =>
    let
        credential = Extension.CurrentCredential(),
        token = credential[Key],        
        headers = [ Authorization = "Bearer " & token ],
        serviceOptions = [ Implementation = "2.0", MoreColumns = true, ODataVersion = 4, Query = if query = null then [] else query ],  //add the query string record option
        url = ValidateUrlScheme(url),
        source = OData.Feed(url, headers, serviceOptions)
    in
        source;

// Data Source Kind description
DCWInsights = [
   // enable JWT Key based auth
    TestConnection = (dataSourcePath) => {"DCWInsights.Feed", Json.Document(dataSourcePath)[url]},
    Authentication = [
        Key = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
DCWInsights.Publish = [
    Beta = false,
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = Extension.LoadString("LearnMoreUrl"),
    SourceImage = DCWInsights.Icons,
    SourceTypeImage = DCWInsights.Icons
];


DCWInsights.Icons = [
    Icon16 = { Extension.Contents("DCWInsights16.png"), Extension.Contents("DCWInsights20.png"), Extension.Contents("DCWInsights24.png"), Extension.Contents("DCWInsights32.png") },
    Icon32 = { Extension.Contents("DCWInsights32.png"), Extension.Contents("DCWInsights40.png"), Extension.Contents("DCWInsights48.png"), Extension.Contents("DCWInsights64.png") }
];
