[Version = "2.1.4"]
section Samsara;

// There doesn't appear to be a way to read the Version field from the literal attributes
// of this section, so we need to repeat it here.
Samsara.Client.Version = "2.1.4";

// Includes. Please keep alphabetized!
Samsara.Credentials = Extension.LoadFunction(Extension.ImportContext, "Samsara.Credentials.pqm");
Samsara.Icons = Extension.LoadFunction(Extension.ImportContext, "Samsara.Icons.pqm");
Samsara.Input.Parameters = Extension.LoadFunction(Extension.ImportContext, "Samsara.Input.Parameters.pqm"); 
Samsara.Input.Validation = Extension.LoadFunction(Extension.ImportContext, "Samsara.Input.Validation.pqm");
Samsara.Run.Start = Extension.LoadFunction(Extension.ImportContext, "Samsara.Run.Start.pqm");
Samsara.Table.Discover = Extension.LoadFunction(Extension.ImportContext, "Samsara.Table.Discover.pqm");
Samsara.Table.Navigate = Extension.LoadFunction(Extension.ImportContext, "Samsara.Table.Navigate.pqm");

// Samsara kind definition.
// Think of this like a combination export + cast expression.
[DataSource.Kind="Samsara", Publish="Samsara.Publish"]
shared Samsara.Records = Value.ReplaceType(Samsara.Main, Samsara.Input.Parameters);

// Lets us include other files. This gets put into the context so that other files can
// use it to import their dependencies. 
Extension.LoadFunction = (EvaluationEnvironment as record, Name as text) =>
    let
        Binary = Extension.Contents(Name),
        AsText = Text.FromBinary(Binary)
    in
        try
            Expression.Evaluate(AsText, EvaluationEnvironment)
        catch (e) =>
            error [
                Reason = "Extension.LoadFunction Failure",
                Message.Format = "Loading '#{0}' failed - '#{1}': '#{2}'",
                Message.Parameters = {Name, e[Reason], e[Message]},
                Detail = [File = Name, Error = e]
            ];
Extension.ImportContext = Record.Combine({ [ Extension.LoadFunction = Extension.LoadFunction ], #shared });

// Main connector entry point.
// Think of this as fn(UserInput) -> TableOfTables, where each row in the result
// describes a single table and how Power BI can load it if the customer selects it.
Samsara.Main = (Region as text, RangeStart as text, optional RangeEnd as text)  =>
    let
        AccessToken = Samsara.Credentials,
        RunState = Samsara.Run.Start(AccessToken, Region, Samsara.Client.Version, Extension.ImportContext),
        ValidatedInput = Samsara.Input.Validation(RunState, RangeStart, RangeEnd),
        Context = Record.Combine({ RunState, ValidatedInput }),
        AvailableTables = Samsara.Table.Discover(Context),
        NavTable = Samsara.Table.Navigate(Context, AvailableTables)
    in
        NavTable;
        
// Metadata for PowerBI's usage. We define:
// - A way for PowerBI to test its connection to our backend
// - How we expect to receive credentials and authenticate
// - A label for our data source, as we want to appear in PowerBI
Samsara = [
    TestConnection = (DataSourcePath) => 
        let
            Json = Json.Document(DataSourcePath),
            Region = Json[region],
            RangeStart = Date.ToText(Date.From(DateTime.LocalNow())),
            RangeEnd = null
        in
            { "Samsara.Records", Region, RangeStart, RangeEnd },
    Authentication = [
        Key = [
            KeyLabel = Extension.LoadString("KeyName"),
            Label = Extension.LoadString("ConnKey")
        ]
    ],
    Label = Extension.LoadString("ConnLabel")
];

// Publishing metadata.
Samsara.Publish = [
    Beta = true,
    Category = "Online Service",
    ButtonText = { 
        Extension.LoadString("ButtonTitle"), 
        Extension.LoadString("ButtonHelp") 
    },
    LearnMoreUrl = "https://kb.samsara.com/hc/en-us/articles/19262879010189-Integrate-with-Power-BI",
    SourceImage = Samsara.Icons,
    SourceTypeImage = Samsara.Icons
];

// ---------------- Testing Utilities ----------------
