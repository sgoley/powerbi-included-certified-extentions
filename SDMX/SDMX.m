[Version = "1.0.5"]
section SDMX;

[DataSource.Kind="SDMX", Publish="SDMX.Publish"]
shared SDMX.Contents =  Value.ReplaceType( GetData, GetDataType);

DisplayFormatList =  { 
{"Show codes and labels", "application/vnd.sdmx.data+csv;file=true;labels=both"},
{"Show codes only", "application/vnd.sdmx.data+csv;labels=id"},
{"Show labels only","application/vnd.sdmx.data+csv;file=true;labels=both"}
};

DisplayFormatLabels= List.Transform( DisplayFormatList, each _{0});

GetDataType = type function (
    url as (Uri.Type meta [
    Documentation.FieldCaption = Extension.LoadString("FunctionParameterURL"),
    Documentation.SampleValues = {"https://<SDMX RESTful data query>"}] ),
    Option as (type text meta [
    Documentation.FieldCaption = Extension.LoadString("FunctionParameterOption"),
    DataSource.Path=false,
    Documentation.AllowedValues = DisplayFormatLabels]),
    optional Language as (type text meta [
    Documentation.FieldCaption = Extension.LoadString("FunctionParameterLanguage"),
    Documentation.SampleValues = {"fr-CH, fr, en"},
    DataSource.Path=false]))
    as table meta [
    Documentation.Name = Extension.LoadString("FunctionName"),
        Documentation.LongDescription = Extension.LoadString("FunctionLongDescription"),
        Documentation.Examples = {[
            Description = Extension.LoadString("FunctionExampleLongDescription"),
            Code = "SDMX.Contents(url,""Show codes and labels"",""en"")",
            Result = Extension.LoadString("FunctionExampleResult")
        ]}
    ];


GetData= (url as text, Option as text, optional Language as text) => let
    Source = List.Select(DisplayFormatList, each _{0} = Option){0}{1},
    myHeaders = if Language = null then [Accept=Source] else [Accept=Source] & [#"Accept-Language"= Language],
    Custom1 = Web.Contents(url, [Headers=myHeaders]),
    myDelimiter = Text.At( Lines.FromBinary( Custom1){0},8),
    Custom2 = Csv.Document( Custom1, null, myDelimiter ),
    x = Table.PromoteHeaders(Custom2, [PromoteAllScalars=true]),
    
    Custom3 = if Option = "Show labels only" then TransformToLabelsOnly( x ) else x
in
    Custom3;



TransformToLabelsOnly = (x as table) as table =>
let
   OriginalHeaders = List.RemoveItems(  Table.ColumnNames( x ),{"DATAFLOW","OBS_VALUE"}),
  NewHeaderNames = List.Buffer( List.Transform( OriginalHeaders, each if try Number.From(Text.AfterDelimiter(_, ":")) = null otherwise false  then _ else Text.TrimStart( Text.AfterDelimiter(_, ":" )))),
  DuplicateHeaders = List.Select( List.Distinct(NewHeaderNames), each List.Count( List.Select(NewHeaderNames, (r)=> r = _) ) > 1),
  FinalHeaders = List.Transform( List.Zip({OriginalHeaders,NewHeaderNames } ), each if List.Contains(DuplicateHeaders, _{1}) then {_{0},_{0}} else _),
  RenamedHeaders = Table.RenameColumns( x, FinalHeaders),
  IterationForColumns = List.Accumulate( List.Transform(FinalHeaders, each _{1} ),  
  RenamedHeaders ,
(state, column) => Table.TransformColumns(state, {column, each if Text.Contains(_,":") then Text.TrimStart(Text.AfterDelimiter(_, ":")  ) else _} )
)
in
    IterationForColumns;


// Data Source Kind description
SDMX = [
TestConnection = (dataSourcePath) as list =>
            {"SDMX.Contents", dataSourcePath, "Show labels only","en"},
    Authentication = [
        Implicit = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
SDMX.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = " https://sdmx.org/",
    SourceImage = SDMX.Icons,
    SourceTypeImage = SDMX.Icons
];

SDMX.Icons = [
    Icon16 = { Extension.Contents("SDMX16.png"), Extension.Contents("SDMX20.png"), Extension.Contents("SDMX24.png"), Extension.Contents("SDMX32.png") },
    Icon32 = { Extension.Contents("SDMX32.png"), Extension.Contents("SDMX40.png"), Extension.Contents("SDMX48.png"), Extension.Contents("SDMX64.png") }
];
