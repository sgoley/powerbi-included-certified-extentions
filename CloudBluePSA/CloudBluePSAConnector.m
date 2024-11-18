[Version = "1.0.1"]
section CloudBluePSA;

[DataSource.Kind="CloudBluePSA", Publish="CloudBluePSA.Publish"]
shared CloudBluePSA.Feed = Value.ReplaceType(CloudBluePSAImpl, CloudBluePSAType);

CloudBluePSAType = type function(
    url as (Text.Type meta[
        Documentation.FieldCaption = Extension.LoadString("URLTextboxLabel"),
        Documentation.FieldDescription = Extension.LoadString("URLTextboxDescription"),
        Documentation.SampleValues = {Extension.LoadString("URLSampleValues")}
    ]),
    filter as (Text.Type meta[
        Documentation.FieldCaption = Extension.LoadString("FilterTextboxLabel"),
        Documentation.FieldDescription = Extension.LoadString("FilterTextboxDescription"),
        Documentation.SampleValues = {Extension.LoadString("FilterSampleValues")}
    ])
) as table meta[
    Documentation.Name = "CloudBluePSA",
    Documentation.LongDescription = Extension.LoadString("FunctionDescription")
];

CloudBluePSAImpl = (url as text, filter as text) =>
let
    filterJson = Json.Document(filter),
    filterGridColumns = filterJson[gridcolumns],
    gridColsWithTotalRows = Text.Combine({filterGridColumns, ",TotalRows"}),
    removeGridCols = Record.RemoveFields(filterJson, "gridcolumns"),
    removePageSize = Record.RemoveFields(removeGridCols, "pagesize"),
    addGridCols = Record.AddField(removePageSize, "gridcolumns", gridColsWithTotalRows),
    addPageSize = Record.AddField(addGridCols, "pagesize", "1000"),
    modifiedFilter = Text.FromBinary(Json.FromValue(addPageSize)),
    apiKey = Extension.CurrentCredential()[Key],
    modifiedURL = Text.Combine({Uri.Parts(url)[Scheme], "://", Uri.Parts(url)[Host], Uri.Parts(url)[Path], "?api_key=", apiKey, "&filter=", modifiedFilter}),
    source = Json.Document(Web.Contents(modifiedURL, [ManualCredentials = true])),
    pageSizeTable = Table.FromList(source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(pageSizeTable, "Column1", {"TotalRows"}, {"TotalRows"}),
    recordCount = #"Expanded Column1"{0}[TotalRows],
    totalCount = Number.IntegerDivide(recordCount, 1000),
    remainder = Number.Mod(recordCount, 1000),
    pageCount = if remainder > 0 then totalCount + 1 else totalCount,
    pageList = {1..pageCount},
    #"Converted to Table" = Table.FromList(pageList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Changed Type" = Table.TransformColumnTypes(#"Converted to Table",{{"Column1", type text}}),
    #"Invoked Custom Function" = Table.AddColumn(#"Changed Type", "Data", each Function.InvokeAfter(() => getPage(modifiedURL, [Column1]),#duration(0,0,0,3)))
in
    #"Invoked Custom Function";

getPage = (url as text, page as text) =>
let
    urlQuery = Uri.Parts(url)[Query],
    filterQueryString = urlQuery[filter],
    filterJson = Json.Document(filterQueryString),
    removePageNo = Record.RemoveFields(filterJson, "pageno"),
    addPageNo = Record.AddField(removePageNo, "pageno", page),
    modifiedFilter = Text.FromBinary(Json.FromValue(addPageNo)),
    modifiedURLQueryFilter = Record.RemoveFields(urlQuery, "filter"),
    modifiedQuery = Record.AddField(modifiedURLQueryFilter, "filter", modifiedFilter),
    modifiedQueryString = Uri.BuildQueryString(modifiedQuery),
    modifiedURL = Text.Combine({Uri.Parts(url)[Scheme],"://",Uri.Parts(url)[Host],Uri.Parts(url)[Path],"?",modifiedQueryString}),
    Source1 = Json.Document(Web.Contents(modifiedURL, [ManualCredentials = true])),
    #"Converted to Table" = Table.FromList(Source1, Splitter.SplitByNothing(), null, null, ExtraValues.Error)
in
    #"Converted to Table";

// Data Source Kind description
CloudBluePSA = [
    TestConnection = (dataSourcePath) => 
        let
            json = Json.Document(dataSourcePath),
            url = json[url],
            filter = json[filter]
        in
            { "CloudBluePSA.Feed", url, filter },
    Authentication = [
        Key = [
            KeyLabel = Extension.LoadString("APIKeyLabel")
        ]
    ],
    Label = "CloudBluePSA"
];

// Data Source UI publishing description
CloudBluePSA.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { "CloudBluePSA", "CloudBluePSA" },
    LearnMoreUrl = Extension.LoadString("LearnMoreUrl")
];

CloudBluePSA.Icons = [
    Icon16 = { Extension.Contents("CloudBluePSA16.png"), Extension.Contents("CloudBluePSA20.png"), Extension.Contents("CloudBluePSA24.png"), Extension.Contents("CloudBluePSA32.png") },
    Icon32 = { Extension.Contents("CloudBluePSA32.png"), Extension.Contents("CloudBluePSA40.png"), Extension.Contents("CloudBluePSA48.png"), Extension.Contents("CloudBluePSA64.png") }
];
