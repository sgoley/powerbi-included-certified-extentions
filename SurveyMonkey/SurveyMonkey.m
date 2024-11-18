[Version = "1.1.0"]
section SurveyMonkey;

// Set to true for debug
EnableTraceOutput = false;
SLD = "surveymonkey";
// Prod Constants
us_api_url = Text.Combine({"https://api.", SLD, ".com"});
ca_api_url = Text.Combine({"https://api.", SLD, ".ca"});
eu_api_url = Text.Combine({"https://api.eu.", SLD, ".com"});

[DataSource.Kind="SurveyMonkey", Publish="SurveyMonkey.Publish"]
shared SurveyMonkey.Contents = Value.ReplaceType(SurveyMonkeyNavTable, SurveyMonkeyNavTableType);

SurveyMonkeyNavTableType = type function ()
    as table meta [
        Documentation.Name = "SurveyMonkey",
        Documentation.LongDescription = "A Navigation table showing all the surveys in the account related to the input access token.",
        Documentation.Examples = {[
            Description = "Returns the navigation table.",
            Code = "SurveyMonkey.Contents()"
        ]}
    ];

// reference: https://docs.microsoft.com/en-us/power-query/waitretry
SurveyMonkey.GetDomain = (access_token as text) => 
   let
        response = Web.Contents(
                    Text.Combine({us_api_url, "v3/surveys"}, "/"),
                    [Headers=[#"Authorization" = "bearer "& access_token], ManualStatusHandling={401,403,503}]
                  ),
        responseCode = Diagnostics.LogValue("code", Value.Metadata(response)[Response.Status]),
        responseBody = Json.Document(response),
        url = if responseCode = 403 and Text.Contains(responseBody[error][message], "surveymonkey.ca") then 
                ca_api_url
              else if responseCode = 401 then 
                let 
                    response = Web.Contents(
                        Text.Combine({eu_api_url, "v3/surveys"}, "/"),
                        [Headers=[#"Authorization" = "bearer "& access_token], ManualStatusHandling={503}]
                      ),
                    responseCode = Diagnostics.LogValue("codeEU", Value.Metadata(response)[Response.Status]),
                    euUrl = 
                        if responseCode = 200 then
                            eu_api_url
                        else if responseCode = 503 then
                            error "SurveyMonkey is under maintenance"
                        else
                            error "Unexpected error" 
                in 
                    euUrl
              else if responseCode = 200 then 
                us_api_url
              else if responseCode = 503 then 
                error "SurveyMonkey is under maintenance"
              else 
                error "Unexpected error"
    in 
        Diagnostics.LogValue("url", url);


// entry function  
SurveyMonkeyNavTable = ()  as table
=>
    let
        access_token = Extension.CurrentCredential()[Key],
        api_url = SurveyMonkey.GetDomain(access_token), 
        surveyTables = Table.ToRecords(SurveyMonkey.GetSurveys(api_url, access_token)),
        formattedTables = List.Accumulate(surveyTables, {}, (stState, stCurrent) =>
            let
                title = stCurrent[title],
                id = stCurrent[id],
                cols = Table.FromRecords(SurveyMonkey.GetSurveyResponses(api_url, stCurrent[id],access_token))
            in
                List.Combine({stState, {{id, title, cols, "Table", "Table", true}}})
        ),
        source = #table({"ID", "Name", "Data", "ItemKind", "ItemName", "IsLeaf"}, formattedTables),
        navTable = Table.ToNavigationTable(source, {"ID"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;



SurveyMonkey.ParseSurvey = (survey, acess_token, api_url) =>
    let
        responses = SurveyMonkey.GetSurveyResponses(api_url, survey[id],acess_token),
        formattedResponses = 
            if List.Count(responses) = 0 then {}
            else
                let
                    v = List.Accumulate(responses, {}, (state, current) => 
                        let
                            rec = current[response_record]
                        in
                            List.Combine({state, {rec}})
                        )
                in
                    v,
        table_questions = Table.FromRecords(responses)
    in
        table_questions;

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
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

// Data Source Kind description
SurveyMonkey = [
    TestConnection = (access_token) => { "SurveyMonkey.Contents"},
    Authentication = [
        Key = [
            Label = "Access Token",
            KeyLabel = Text.Combine({"Get your access token at https://www.", SLD, ".com/apps/power_bi"})
        ]
    ],
    Label = "SurveyMonkey"
];

// Data Source UI publishing description
SurveyMonkey.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = SurveyMonkey.Icons,
    SourceTypeImage = SurveyMonkey.Icons
];

SurveyMonkey.Icons = [
    Icon16 = { Extension.Contents("SurveyMonkey16.png"), Extension.Contents("SurveyMonke220.png"), Extension.Contents("SurveyMonkey24.png"), Extension.Contents("SurveyMonkey32.png") },
    Icon32 = { Extension.Contents("SurveyMonkey32.png"), Extension.Contents("SurveyMonke240.png"), Extension.Contents("SurveyMonkey48.png"), Extension.Contents("SurveyMonkey64.png") }
];

// https://github.com/microsoft/DataConnectors/blob/dbd99078501897e04e7a6b9305ad7857ae1b7a63/samples/Relationships/Relationships.pq
// TEMPORARY WORKAROUND until we're able to reference other M modules
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

FetchResource = Extension.LoadFunction("FetchResource.pqm");
SurveyMonkey.GetSurveys = FetchResource[GetSurveys];
SurveyMonkey.GetSurveyResponses = FetchResource[GetSurveyResponses];

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = if (EnableTraceOutput) then Diagnostics[LogValue] else (prefix, value) => value;
Diagnostics.LogFailure = Diagnostics[LogFailure];
