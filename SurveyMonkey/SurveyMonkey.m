[Version = "1.0.3"]
section SurveyMonkey;

Utils.IsolateAttribute = (r as list, attribute as text) =>
    let
        ret = List.Accumulate(r, {}, (state, current) =>
            let
            in
                List.Combine({state, {Record.Field(current, attribute)}})
                
        )
    in
        ret;

Utils.ColumnRenamer = (renamer as list) =>
    let
        ret = List.Accumulate(renamer, {}, (state, current) =>
            let
                column_title = if List.Count(List.Select(renamer, each _[title] = current[title])) = 1 then current[title] else current[title] & " - " & current[id]
            in
                List.Combine({state, {{current[id], column_title}}})
            )
    in
        ret;

Util.CleanHTMLTags = (HTML as text) as text =>
    let
        Source = 
            if HTML = null then
                ""
            else
                Text.From(HTML),
        SplitAny = Text.SplitAny(Source,"<>"),
        ListAlternate = List.Alternate(SplitAny,1,1,1),
        ListSelect = List.Select(ListAlternate, each _<>""),
        TextCombine = Text.Combine(ListSelect, "")
    in
        TextCombine;


// combine two text with " - ", and limit their length within 250 each, since table title length cannot be over 512. 
// if over limit, truncate the longer one 
Util.CombineText = (text1 as text, text2 as text) as text =>
    let 
        lenText1 = Text.Length(text1),
        lenText2 = Text.Length(text2),
        part1 = 
            if lenText1 > 250 then
                Text.Range(text1, 0, 250) & "..."
            else
                text1,
        part2 = 
            if lenText2 > 250 then
                Text.Range(text2, 0, 250) & "..."
            else
                text2
    in 
        Text.Combine({part1, part2}, " - ");



SurveyMonkey.ParseSurvey = (surveyId as text, access_token as text) =>
    let
        source = Web.Contents(Text.Combine({api_url, "/v3/surveys", surveyId, "details"}, "/"),
        [Headers=[#"Authorization" = "bearer "& access_token]]),
        json = Json.Document(source),
        pages_meta = json[pages],
        pages = List.Accumulate(pages_meta, {}, (state, current) => 
                let
                    questions_meta = current[questions],
                    questions = List.Accumulate(questions_meta, {}, (state, current) => 
                            let
                                family = current[family],
                                subtype = current[subtype],
                                displayOptions = Record.FieldOrDefault(current, "displayOptions", []),
                                displayType = Record.FieldOrDefault(displayOptions, "displayType", false),
                                pass = family = "presentation" or displayType = "file_upload",
                                ret = if pass then state else List.Combine({state, {family}}),
                                origTitleText = current[headings]{0}[heading],
                                noTag = Util.CleanHTMLTags(origTitleText),
                                title =
                                    if Text.Length(noTag) > 512 then
                                        Text.Range(noTag, 0, 512-3) & "..."
                                    else
                                        noTag,

                                questionTitles = 
                                    if family = "multiple_choice" then
                                        List.Accumulate(current[answers][choices], {}, (qState, qCurrent) =>
                                            let
                                                mcTitle = Util.CombineText(title, Util.CleanHTMLTags(qCurrent[text]))
                                            in
                                                List.Combine({qState, {[title = mcTitle, id = qCurrent[id], family = family, subtype = subtype]}})
                                        )
                                    else if family = "matrix" and List.MatchesAny({"ranking", "rating", "single", "multi"}, each subtype = _) then
                                        List.Accumulate(current[answers][rows], {}, (qState, qCurrent) =>
                                            let
                                                mcTitle = Util.CombineText(title, Util.CleanHTMLTags(qCurrent[text]))
                                            in
                                                List.Combine({qState, {[title = mcTitle, id = qCurrent[id], family = family, subtype = subtype]}})
                                        )
                                    else if family = "matrix" and subtype = "menu" then
                                        List.Accumulate(current[answers][rows], {}, (rowState, rowCurrent) =>
                                            let
                                                rowTitle = Util.CleanHTMLTags(rowCurrent[text]),
                                                rowId = rowCurrent[id],
                                                cols = List.Accumulate(current[answers][cols], {}, (colState, colCurrent) =>
                                                    let
                                                        colTitle = Util.CombineText(title, Text.Combine({rowTitle, Util.CleanHTMLTags(colCurrent[text])}, " -")),
                                                        rowColId = Text.Combine({rowId, colCurrent[id]}, "menu")
                                                    in
                                                        List.Combine({colState, {[title = colTitle, id = rowColId, family = family, subtype = subtype]}})
                                                )

                                            in
                                                List.Combine({rowState, cols})
                                        )
                                    else if family = "demographic" then
                                        List.Accumulate(current[answers][rows], {}, (qState, qCurrent) =>
                                            let
                                                mcTitle = Util.CombineText(title, Util.CleanHTMLTags(qCurrent[text]))
                                            in
                                                if qCurrent[visible] then
                                                    List.Combine({qState, {[title = mcTitle, id = qCurrent[id], family = family, subtype = subtype]}})
                                                else
                                                    qState
                                        )
                                    else if subtype = "multi" or subtype = "numerical" or family = "datetime" then
                                        List.Accumulate(current[answers][rows], {}, (qState, qCurrent) =>
                                            let
                                                mcTitle = Util.CombineText(title, Util.CleanHTMLTags(qCurrent[text]))
                                            in
                                                List.Combine({qState, {[title = mcTitle, id = qCurrent[id], family = family, subtype = subtype]}})
                                        )
                                    else
                                        {[title = title, id = current[id], family = family, subtype = subtype]},
                                other =
                                    Record.FieldOrDefault(
                                            Record.FieldOrDefault(current, "answers", []),
                                            "other", []
                                           ),
                                otherTitle = Util.CombineText(title, Util.CleanHTMLTags(Record.FieldOrDefault(other, "text", ""))),
                                quizData = 
                                    Record.FieldOrDefault(
                                            Record.FieldOrDefault(current, "quiz_options", []),
                                            "scoring_enabled", []
                                    ),
                                quizTitle = Util.CombineText(title, "Score"),

                                withOther = if other = [] then
                                    questionTitles
                                else if family <> "single_choice" and Record.FieldOrDefault(other, "is_answer_choice", false) then
                                    questionTitles
                                else
                                    List.Combine({questionTitles, {[title = otherTitle, id= other[id], family = family, subtype = subtype, other_type=true]}}),

                                allHeaders = if quizData = [] then
                                    withOther
                                else
                                    List.Combine({withOther, {[title = quizTitle, id=Text.Combine({current[id], "_score"}), family="quiz_score", subtype="na", quiz_type=true]}})

                                
                                    
                            in
                                List.Combine({state, allHeaders})
                                
                        )
                in
                    List.Combine({state, questions})
            ),
        // Custom Variables
        customVariablesMeta = Record.FieldOrDefault(json, "custom_variables", []),
        customVariableFields = Record.FieldNames(customVariablesMeta),
        customVariables = List.Accumulate(customVariableFields, {}, (cvState, cvCurrent) =>
            let
                title = Text.Combine({"CV - ", cvCurrent})
            in
                List.Combine({cvState, {[title = title, id=cvCurrent, family="custom_variable", subtype="na"]}})
        ),

        // Custom Value 
        customValue = List.Combine({customVariables, {[title = "Custom Value", id="CustomValue", family="custom_value", subtype="na"]}}),

        // Response metadata
        metaDataFields = {"date_created", "date_modified", "ip_address", "total_time", "id", "response_status", "collector_id"},
        metaData = List.Accumulate(metaDataFields, {}, (mState, mCurrent) =>
            let
                title = Text.Combine({"Metadata - ", mCurrent})
            in
                List.Combine({mState, {[title = title, id=mCurrent, family="metadata", subtype="na"]}})
        ),

        // Contact metadata
        contactFields = {"email", "first_name", "last_name", "custom_value", "custom_value2", "custom_value3", "custom_value4","custom_value5", "custom_value6"},
        contactData = List.Accumulate(contactFields, {}, (mState, mCurrent) =>
            let
                title = 
                    if mCurrent = "custom_value" then
                        Text.Combine({"Recipient - ", "custom_value1"})
                    else
                        Text.Combine({"Recipient - ", mCurrent})
            in
                List.Combine({mState, {[title = title, id=mCurrent, family="contact", subtype="na"]}})
        ),
        
        // Quiz metadata
        quizMetaFields = {"incorrect", "partially_correct", "total_questions", "total_score", "score", "correct"},
        quizMetaData = List.Accumulate(quizMetaFields, {}, (qmState, qmCurrent) =>
            let
                title = Text.Combine({"Quiz - ", qmCurrent})
            in 
                List.Combine({qmState, {[title = title, id=qmCurrent, family="quizmetadata", subtype="na"]}})
        ),
        quizEnabled = Record.FieldOrDefault(
            Record.FieldOrDefault(json, "quiz_options", []),
            "is_quiz_mode",
            false),
        

        allMetaData = if quizEnabled = true then
            List.Combine({customValue, metaData, quizMetaData, contactData})
        else
            List.Combine({customValue, metaData, contactData}),
        flattenedSurvey = List.Combine({pages, allMetaData}),
        t1 = #table(Utils.IsolateAttribute(flattenedSurvey, "id"), {}),
        t2 = Table.RenameColumns(t1, Utils.ColumnRenamer(flattenedSurvey)),
        bulkResponses = SurveyMonkey.GetSurveyResponses(surveyId, access_token),
        formattedResponses = List.Accumulate(bulkResponses, {}, (bulkState, bulkCurrent) =>
            let
                y = List.Accumulate(flattenedSurvey, [], (responseState, responseCurrent) =>
                    let
                        r = SurveyMonkey.ResponseParse(responseCurrent[id], responseCurrent[family], responseCurrent[subtype], bulkCurrent),
                        rec = if (responseCurrent[family] = "matrix" or responseCurrent[family] = "single_choice") and not Record.FieldOrDefault(responseCurrent, "other_type", false) then SurveyMonkey.GetLabelText(r, pages_meta, responseCurrent[family]) else r,
                        noTag = 
                            if rec is text then
                                Util.CleanHTMLTags(rec)
                            else
                                rec
                    in
                        Record.AddField(responseState, responseCurrent[id], noTag)
                    )
            in
                List.Combine({bulkState, {y}})
            ),
        t = Table.InsertRows(t1, 0, formattedResponses),
        ttt = Table.RenameColumns(t, Utils.ColumnRenamer(flattenedSurvey))
    in
        ttt;


SurveyMonkey.GetLabelText = (targetId as text, pages_list as list, family as text) =>
    let
        pages = List.Accumulate(pages_list, "", (pState, pCurrent) => 
            let
                questions_list = pCurrent[questions],
                questions = List.Accumulate(questions_list, "", (qState, qCurrent) => 
                        let
                            choices_list = if not Record.HasFields(qCurrent, "answers") then
                                {}
                            else if Record.HasFields(qCurrent[answers], "choices") then
                                //all non-menu matrices
                                qCurrent[answers][choices]
                            else if Record.HasFields(qCurrent[answers], "cols") then
                                //menu
                                List.Accumulate(qCurrent[answers][cols], {}, (colState, colCurrent) =>
                                    let

                                    in
                                        List.Combine({colState, colCurrent[choices]})
                                )
                            else
                                {},
                            choices = List.Accumulate(choices_list, "", (cState, cCurrent) =>
                                let
                                    ret = 
                                        if targetId = cCurrent[id] then
                                            if cCurrent[text] = "" then
                                                Number.ToText(cCurrent[weight])
                                            else
                                                cCurrent[text] 
                                        else ""
                                in
                                    Text.Combine({cState, ret}))
                        in
                            Text.Combine({qState, choices}))
            in
                Text.Combine({pState, questions}))
    in
        pages;

SurveyMonkey.ResponseParse = (target as text, family as text, subtype as text, response as record) =>
    let
        json = response,
        pages_meta = Record.FieldOrDefault(json, "pages", {}),
        ret = [],
        targetId = if family <> "quiz_score" then
            target
        else
            Text.BeforeDelimiter(target, "_"),
        pages = List.Accumulate(pages_meta, [], (pageState, pageCurrent) => 
            let
                questions_meta = pageCurrent[questions],
                questions = List.Accumulate(questions_meta, [], (questionState, questionCurrent) => 
                        let
                            answers_meta = Record.FieldOrDefault(questionCurrent, "answers", {}),
                            answers = 
                                    List.Accumulate(answers_meta, [], (answerState, answerCurrent) =>
                                        let

                                            mc = Record.FieldOrDefault(answerCurrent, "choice_id", false),
                                            is_other = Record.FieldOrDefault(answerCurrent, "other_id", "") <> "",
                                            ret = 
                                                if targetId = Record.FieldOrDefault(questionCurrent, "id", "") 
                                                or targetId = Record.FieldOrDefault(answerCurrent, "row_id", "") 
                                                or targetId = Record.FieldOrDefault(answerCurrent, "choice_id", "")
                                                or targetId = Record.FieldOrDefault(answerCurrent, "other_id", "")
                                                or targetId = Text.Combine({Record.FieldOrDefault(answerCurrent, "row_id", ""), Record.FieldOrDefault(answerCurrent, "col_id", "")}, "menu")
                                                then
                                                    if is_other then
                                                        Record.AddField(answerState, Record.FieldOrDefault(answerCurrent, "other_id", ""), answerCurrent[text])
                                                    else if family = "multiple_choice" then
                                                        Record.AddField(answerState, answerCurrent[choice_id], true)
                                                    else if family = "matrix" and List.MatchesAny({"ranking", "rating", "single", "multi"}, each subtype = _) then
                                                        //TODO: Rating(Other)
                                                        Record.AddField(answerState, targetId, answerCurrent[choice_id])
                                                    else if family = "matrix" and subtype = "menu" then
                                                        Record.AddField(answerState, targetId,
                                                            Record.FieldOrDefault(answerCurrent, "choice_id", Record.FieldOrDefault(answerCurrent, "text")))
                                                    else if family = "single_choice" then
                                                        Record.AddField(answerState, targetId, answerCurrent[choice_id])
                                                    else if family = "open_ended" and List.MatchesAny({"single", "essay"}, each subtype = _) then
                                                        Record.AddField(answerState, targetId, answerCurrent[text])
                                                    else if family = "open_ended" and List.MatchesAny({"multi", "numerical"}, each subtype = _) then
                                                        Record.AddField(answerState, targetId, answerCurrent[text])
                                                    else if family = "datetime" then
                                                        Record.AddField(answerState, targetId, answerCurrent[text])
                                                    else if family = "demographic" then
                                                        Record.AddField(answerState, targetId, answerCurrent[text])
                                                    else if family = "quiz_score" then
                                                        if Record.HasFields(answerState, target) then
                                                            let
                                                                newScore = Record.Field(answerState, target) + answerCurrent[score],
                                                                nah = Record.RemoveFields(answerState, target),
                                                                new = Record.AddField(nah, target, newScore)
                                                            in 
                                                                new
                                                        else 
                                                            Record.AddField(answerState, target, answerCurrent[score])
                                                    else
                                                        Record.AddField(answerState, targetId, "ERROR - Unsupported Question Type")
                                                else
                                                    answerState
                                        in
                                           ret
                                    )
                        in
                            Record.Combine({questionState, answers})
                )
            in
                Record.Combine({pageState, questions})
       ),
       ans = 
       if family = "custom_variable" then
            Record.FieldOrDefault(Record.FieldOrDefault(json, "custom_variables", []), targetId, "")
       else if family = "custom_value" then
            Record.FieldOrDefault(json, "custom_value", "")
       else if family = "multiple_choice" then
            Record.FieldOrDefault(pages, targetId, false)
       else if family = "metadata" then
            Record.FieldOrDefault(json, targetId, "")
       else if family = "quizmetadata" then
            Record.FieldOrDefault(json[quiz_results], targetId, "")
       else if family = "contact" then 
            let 
               ret = 
                if Record.HasFields(json, "metadata") and Record.HasFields(Record.Field(json, "metadata"), "contact") then
                    let 
                        contactInfo = json[metadata][contact],
                        fieldInfo = Record.FieldOrDefault(contactInfo, targetId, ""),
                        fieldValue = 
                            if fieldInfo = "" then
                                ""
                            else 
                                Record.FieldOrDefault(fieldInfo, "value", "")
                    in
                        fieldValue
                else 
                    ""
            in 
                ret
       else
            Record.FieldOrDefault(pages, target, "")
    in
       ans;


SurveyMonkey.GetSurveys = (access_token) as table =>
    let
        #"Converted to Table" = GetAllPagesByNextLink(api_url & "/v3/surveys", access_token)
    in
        #"Converted to Table";

SurveyMonkey.GetSurveyResponses = (surveyId as text, access_token as text) =>
    let
        responses = GetAllPagesByNextLink(api_url & "/v3/surveys/" & surveyId & "/responses/bulk", access_token),
        responseList = Table.ToRecords(responses)
    in
        responseList;

[DataSource.Kind="SurveyMonkey", Publish="SurveyMonkey.Publish"]
shared SurveyMonkey.Contents = Value.ReplaceType(SurveyMonkeyNavTable, SurveyMonkeyNavTableType);
SurveyMonkeyNavTable = () as table =>
    let
        access_token = Extension.CurrentCredential()[Key],
        surveyTables = Table.ToRecords(SurveyMonkey.GetSurveys(access_token)),
        formattedTables = List.Accumulate(surveyTables, {}, (stState, stCurrent) =>
            let
                title = stCurrent[title],
                id = stCurrent[id],
                cols = SurveyMonkey.ParseSurvey(stCurrent[id], access_token)

            in
                List.Combine({stState, {{id, title, cols, "Table", "Table", true}}})
        ),
        source = #table({"ID", "Name", "Data", "ItemKind", "ItemName", "IsLeaf"}, formattedTables),
        navTable = Table.ToNavigationTable(source, {"ID"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;   

SurveyMonkeyNavTableType = type function ()
    as table meta [
        Documentation.Name = "SurveyMonkey",
        Documentation.LongDescription = "A Navigation table showing all the surveys in the account related to the input access token.",
        Documentation.Examples = {[
            Description = "Returns the navigation table.",
            Code = "SurveyMonkey.Contents()"
        ]}
    ];

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

GetNextLink = (response) as nullable text => Record.FieldOrDefault(Record.FieldOrDefault(response, "links"), "next");

GetPage = (url as text, access_token as text) as table =>
    let
        response = Web.Contents(url,
        [Headers=[#"Authorization" = "bearer "& access_token]]),  
        body = Json.Document(response),
        nextLink = GetNextLink(body),
        data = Table.FromRecords(body[data])
    in
        data meta [NextLink = nextLink];

GetAllPagesByNextLink = (url as text, access_token as text) as table =>
    Table.GenerateByPage((previous) => 
        let
            // if previous is null, then this is our first page of data
            nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
            // if NextLink was set to null by the previous call, we know we have no more data
            page = if (nextLink <> null) then GetPage(nextLink, access_token) else null
        in
            page
    );

// The getNextPage function takes a single argument and is expected to return a nullable table
Table.GenerateByPage = (getNextPage as function) as table =>
    let        
        listOfPages = List.Generate(
            () => getNextPage(null),            // get the first page of data
            (lastPage) => lastPage <> null,     // stop when the function returns null
            (lastPage) => getNextPage(lastPage) // pass the previous page to the next function call
        ),
        // concatenate the pages together
        tableOfPages = Table.FromList(listOfPages, Splitter.SplitByNothing(), {"Column1"}),
        firstRow = tableOfPages{0}?
    in
        // if we didn't get back any pages of data, return an empty table
        // otherwise set the table type based on the columns of the first page
        if (firstRow = null) then
            Table.FromRows({})
        else        
            Value.ReplaceType(
                Table.ExpandTableColumn(tableOfPages, "Column1", Table.ColumnNames(firstRow[Column1])),
                Value.Type(firstRow[Column1])
            );

// Data Source Kind description
SurveyMonkey = [
    TestConnection = (access_token) => { "SurveyMonkey.Contents"},
    Authentication = [
        Key = [
            Label = "Access Token",
            KeyLabel = "Get your access token at https://www.surveymonkey.com/apps/power_bi"
        ]
    ],
    Label = "SurveyMonkey"
];

// Prod Constants
api_url = "https://api.surveymonkey.com";


// MT3 Constants
// api_url = "https://api.monkeytest3.com";

windowWidth = 1200;
windowHeight = 1000;

redirect_uri = "https://preview.powerbi.com/views/oauthredirect.html";

// Data Source UI publishing description
SurveyMonkey.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = SurveyMonkey.Icons,
    SourceTypeImage = SurveyMonkey.Icons
];

SurveyMonkey.Icons = [
    Icon16 = { Extension.Contents("SurveyMonkey16.png"), Extension.Contents("SurveyMonkey20.png"), Extension.Contents("SurveyMonkey24.png"), Extension.Contents("SurveyMonkey32.png") },
    Icon32 = { Extension.Contents("SurveyMonkey32.png"), Extension.Contents("SurveyMonkey40.png"), Extension.Contents("SurveyMonkey48.png"), Extension.Contents("SurveyMonkey64.png") }
];
