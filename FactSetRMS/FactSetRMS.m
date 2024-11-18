// This file contains your Data Connector logic
[Version = "1.1.0"]
section FactSetRMS;
API_HOST = "https://api.factset.com/research/irn/v1/";
headers = [#"X-IRN-Source" = "powerbi"];

// Data Source Kind description
FactSetRMS = [
    TestConnection = (dataSourcePath) as list => { "FactSetRMS.Functions", [TestConnection = true]},
    Authentication = [
        UsernamePassword = [
            UserNameLabel = "UserName-Serial",
            PasswordLabel = "API Key",
            Label = Extension.LoadString("APIKeyAuthenticationLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
FactSetRMS.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://developer.factset.com/api-catalog/irn-notes-api",
    SourceImage = PowerBI.DataConnector.Icons,
    SourceTypeImage = PowerBI.DataConnector.Icons
];

PowerBI.DataConnector.Icons = [
    Icon16 = { Extension.Contents("Factset16.png"), Extension.Contents("Factset20.png"), Extension.Contents("Factset24.png"), Extension.Contents("Factset32.png") },
    Icon32 = { Extension.Contents("Factset32.png"), Extension.Contents("Factset40.png"), Extension.Contents("Factset48.png"), Extension.Contents("Factset64.png") }
];

[DataSource.Kind="FactSetRMS", Publish="FactSetRMS.Publish"]
shared FactSetRMS.Functions = (optional options as record) as table =>
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"Notes", "Notes", GetNotesTable(), "Table", "Table", true},
                {"Subjects", "Subjects", GetSubjects(), "Table", "Table", true},
                {"Recommendations", "Recommendations", GetRecommendations(), "Table", "Table", true},
                {"Authors", "Authors", GetAuthors(), "Table", "Table", true},
                {"Sentiments", "Sentiments", GetSentiments(), "Table", "Table", true},
                {"CustomFields", "CustomFields", GetCustomFields(), "Table", "Table", true},
                {"Meetings", "Meetings", GetAllMeetings(), "Table", "Table", true},
                {"CustomSymbols", "CustomSymbols", GetCustomSymbols(), "Table", "Table", true},
                {"CustomSymbolsTypes", "CustomSymbolsTypes", GetCustomSymbolsTypes(), "Table", "Table", true},
                {"Contacts", "Contacts", GetContactsTable(), "Table", "Table", true},
                {"GetContact", "GetContact", FactSetRMS.GetContact, "Function", "Function", true},
                {"GetContacts", "GetContacts", FactSetRMS.GetContactsFiltered, "Function", "Function", true},
                {"GetNotes", "GetNotes", FactSetRMS.GetNotes, "Function", "Function", true},
                {"GetNote", "GetNote", FactSetRMS.GetNote, "Function", "Function", true},
                {"GetMeeting", "GetMeeting", FactSetRMS.GetMeeting, "Function", "Function", true},
                {"GetMeetings","GetMeetings",FactSetRMS.GetMeetings,"Function","Function",true},
                {"CustomSymbolsCustomFields","CustomSymbolsCustomFields",GetCustomSymbolsCustomFields(),"Table","Table",true},
                {"SymbolsRelationships","SymbolsRelationships",GetSymbolsRelationships(),"Table","Table",true},
                {"GetCustomSymbol", "GetCustomSymbol",FactSetRMS.GetCustomSymbol, "Function", "Function", true},
                {"GetCustomSymbols", "GetCustomSymbols", FactSetRMS.GetCustomSymbolsFiltered, "Function", "Function", true}
            }
        ),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        if (options <> null and options[TestConnection]? = true) then
           Record.ToTable(Json.Document(Text.FromBinary(Web.Contents(API_HOST & "group", [Headers = headers]))))
        else
            NavTable;

GetNotesTable = () => 
    let 
        response = Web.Contents(API_HOST & "notes", [Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        JsonToTable = Table.FromList(responseJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expand NotesTable" = Table.ExpandRecordColumn(JsonToTable, "Column1", {"id", "date", "createdAt", "authorId", "contributorId", 
        "title", "identifier", "subjectId", "isPersonal", "state", "approvalStatus","recommendationId", 
        "sentimentId","relatedSymbols","customFields"}),
        #"Extracted RelatedSymbols" = Table.TransformColumns(#"Expand NotesTable", {"relatedSymbols", each Text.Combine(List.Transform(_, Text.From), ","), type text}),
        #"Replaced EmptyRelatedSymbolsAsNull" = Table.ReplaceValue(#"Extracted RelatedSymbols","",null,Replacer.ReplaceValue,{"relatedSymbols"}),
        #"Expand customField list" = Table.ExpandListColumn(#"Replaced EmptyRelatedSymbolsAsNull", "customFields"),
        #"Expand customField record" = Table.ExpandRecordColumn(#"Expand customField list" , "customFields",{"code","value","options"}),
        #"Replaced null" = Table.ReplaceValue( #"Expand customField record",null,"emptyCustomField",Replacer.ReplaceValue,{"code"}),
        #"Extracted optionList" = Table.TransformColumns(#"Replaced null", {"options", each Text.Combine(List.Transform(_, Text.From), ","), type text}),
        #"Replaced Errors" = Table.ReplaceErrorValues( #"Extracted optionList", {{"options", null}}),
        #"Replaced Empty" = Table.ReplaceValue(#"Replaced Errors","",null,Replacer.ReplaceValue,{"options"}),
        #"Merged optionsValue" = Table.CombineColumns(#"Replaced Empty",{"value", "options"},Combiner.CombineTextByDelimiter("", QuoteStyle.None),"customField.value"),
        #"Pivoted codeValue" = Table.Pivot(#"Merged optionsValue", List.Distinct(#"Merged optionsValue"[code]), "code", "customField.value"),
        NotesTable = if Table.HasColumns( #"Pivoted codeValue","emptyCustomField") then  Table.RemoveColumns( #"Pivoted codeValue",{"emptyCustomField"}) else  #"Pivoted codeValue" 
     

    in
        NotesTable;

GetSubjects = () => 
    let 
        response = Web.Contents(API_HOST & "subjects", [Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        JsonToTable = Table.FromList(responseJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        SubjectsTable = Table.ExpandRecordColumn(JsonToTable, "Column1", {"id", "name"})
    in
        SubjectsTable;

GetRecommendations = () => 
    let 
        response = Web.Contents(API_HOST & "recommendations", [Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        JsonToTable = Table.FromList(responseJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        RecommendationsTable = Table.ExpandRecordColumn(JsonToTable, "Column1", {"id", "name"})
    in
        RecommendationsTable;

GetAuthors = () => 
    let 
        response = Web.Contents(API_HOST & "authors", [Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        JsonToTable = Table.FromList(responseJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        Table = Table.ExpandRecordColumn(JsonToTable, "Column1", {"id", "userName","serialNumber","firstName","lastName"}),
        AuthorsTable=Table.CombineColumns(Table,{"firstName", "lastName"},Combiner.CombineTextByDelimiter(" ", QuoteStyle.None),"Author name")
    in
        AuthorsTable;

GetSentiments = () => 
    let 
        response = Web.Contents(API_HOST & "sentiments", [Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        JsonToTable = Table.FromList(responseJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        SentimentsTable = Table.ExpandRecordColumn(JsonToTable, "Column1", {"id", "name"})
    in
        SentimentsTable;

GetCustomFields = () => 
    let 
        response = Web.Contents(API_HOST & "custom-fields", [Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        JsonToTable = Table.FromList(responseJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        customFieldsTable = Table.ExpandRecordColumn(JsonToTable, "Column1", {"id", "code","name"})
    in
        customFieldsTable;

GetAllMeetings = () => 
    let 
        response = Web.Contents(API_HOST & "meetings", [Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        JsonToTable = Table.FromList(responseJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        meetingsTable = Table.ExpandRecordColumn(JsonToTable, "Column1", {"id", "start","end","createdAt","authorId","title",
                            "identifier","organizer","organizerId","relatedSymbols","locations","attendees","customFieldValues"})
    in
        meetingsTable;


GetCustomSymbolsCustomFields= () =>
    let 
        response = Web.Contents(API_HOST & "custom-symbol-custom-fields",[Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        JsonToTable = Table.FromList(responseJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        SymbolTable = Table.ExpandRecordColumn(JsonToTable, "Column1", {"id","code","type"})
    in
        SymbolTable;


GetSymbolsRelationships= () =>
    let
        response = Web.Contents(API_HOST & "symbols-relationships",[Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        JsonToTable = Table.FromList(responseJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        SymbolTableRelation = Table.ExpandRecordColumn(JsonToTable, "Column1", {"id","relationshipCode","parentToChildName","childToParentName","peerName","hideDates","hideComment"})
    in
        SymbolTableRelation;


GetCustomSymbolsTypes = () =>
    let 
        response = Web.Contents(API_HOST & "custom-symbol-types",[Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        JsonToTable = Table.FromList(responseJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        CustomSymbolsTypeTable = Table.ExpandRecordColumn(JsonToTable, "Column1", {"id", "name","hideAddressField","hideSymbolSubType","isDefault"})
    in
        CustomSymbolsTypeTable;
GetCustomSymbols = () =>
    let 
        response = Web.Contents(API_HOST & "custom-symbols?includeCustomFieldValues=true",[Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        JsonToTable = Table.FromList(responseJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
     
        #"Expanded CustomSymbolsTable" = Table.ExpandRecordColumn(JsonToTable, "Column1", {"id","code", "name","type","description","createdDate","createdBy", "standardSymbol",
                                                                                        "isAddressAutoFilled","isDescriptionAutoFilled","customFields"}),        
        #"Expanded CustomSymbolsType" = Table.ExpandRecordColumn(#"Expanded CustomSymbolsTable", "type", {"id","name"}, {"type.id","type.name"}),
        #"Expanded customFields" = Table.ExpandListColumn( #"Expanded CustomSymbolsType", "customFields"),
        #"Expanded customFieldsValues"= Table.ExpandRecordColumn(#"Expanded customFields", "customFields", {"code", "value", "optionValues"}, {"customFields.code", "customFields.value", "customFields.optionValues"}),
        #"Extracted Values" = Table.TransformColumns(#"Expanded customFieldsValues", {"customFields.optionValues", each Text.Combine(List.Transform(_, Text.From), ","), type text}),
        #"Replaced Errors" = Table.ReplaceErrorValues(#"Extracted Values", {{"customFields.optionValues", ""}}),
        #"Replaced Value" = Table.ReplaceValue(#"Replaced Errors","",null,Replacer.ReplaceValue,{"customFields.optionValues"}),
        #"Merged Columns" = Table.CombineColumns(#"Replaced Value",{"customFields.value", "customFields.optionValues"},Combiner.CombineTextByDelimiter("", QuoteStyle.None),"customFields.values"),
        #"Replaced nullValue" = Table.ReplaceValue(#"Merged Columns",null,"emptyCustomField",Replacer.ReplaceValue,{"customFields.code"}),
        #"Pivoted Column" = Table.Pivot(#"Replaced nullValue", List.Distinct(#"Replaced nullValue"[customFields.code]), "customFields.code", "customFields.values"), 
       
        CustomSymbolTable= if Table.HasColumns(#"Pivoted Column","emptyCustomField") then  Table.RemoveColumns(#"Pivoted Column",{"emptyCustomField"}) else #"Pivoted Column"
    in
        CustomSymbolTable;

GetContactsTable = () => 
    let 
        response = Web.Contents(API_HOST & "contacts?customFieldValues=true&includeLastMeetingDate=true", [Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        JsonToTable = Table.FromList(responseJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn( JsonToTable, "Column1", {"id", "primaryEmailAddress", "identifier", "fullName", "employerName", 
                                                                                   "employerIdentifier", "city", "stateProvince", "postalCode", "country", "role", "type", "isDeleted", 
                                                                                   "lastMeeting", "alternativeEmailAddresses", "customFieldValues"}, {"id", "primaryEmailAddress", "identifier", "fullName", "employerName",
                                                                                   "employerIdentifier", "city", "stateProvince", "postalCode", "country", "role", "type", "isDeleted", "lastMeeting", "alternativeEmailAddresses", "customFieldValues"}),
        #"Expanded type" = Table.ExpandRecordColumn(#"Expanded Column1", "type", {"id", "name"}, {"type.id", "type.name"}),
        #"Expanded role" = Table.ExpandRecordColumn(#"Expanded type", "role", {"id", "name"}, {"role.id", "role.name"}),
        #"Expanded alternativeEmailAddresses" = Table.ExpandListColumn(#"Expanded role", "alternativeEmailAddresses"),
        #"Expanded alternativeEmailAddresses1" = Table.ExpandRecordColumn(#"Expanded alternativeEmailAddresses", "alternativeEmailAddresses", {"id", "emailAddress"}, {"alternativeEmailAddresses.id", "alternativeEmailAddresses.emailAddress"}),
        #"Grouped Rows" = Table.Group(#"Expanded alternativeEmailAddresses1", {"id", "primaryEmailAddress", "identifier", "fullName", "employerName", "employerIdentifier", "city", "stateProvince", "postalCode", "country", "role.id", "role.name", "type.id", "type.name", "isDeleted", "lastMeeting", "customFieldValues"}, {{"alternativeEmailAddresses.id", each Text.Combine([alternativeEmailAddresses.id],","), type text}, {"alternativeEmailAddresses.emailAddress", each Text.Combine([alternativeEmailAddresses.emailAddress],","), type text}}),
        #"Expanded customFieldValues" = Table.ExpandListColumn(#"Grouped Rows", "customFieldValues"),
        #"Expanded customFieldValues1" = Table.ExpandRecordColumn(#"Expanded customFieldValues", "customFieldValues", {"fieldCode", "value"}, {"customFieldValues.fieldCode", "customFieldValues.value"}),
        #"Replaced Value" = Table.ReplaceValue(#"Expanded customFieldValues1",null,"emptyCustomField",Replacer.ReplaceValue,{"customFieldValues.fieldCode"}),
        #"Pivoted Column" = Table.Pivot(#"Replaced Value", List.Distinct(#"Replaced Value"[customFieldValues.fieldCode]), "customFieldValues.fieldCode", "customFieldValues.value"),
        ContactsTable = if Table.HasColumns(  #"Pivoted Column" ,"emptyCustomField") then  Table.RemoveColumns(  #"Pivoted Column" ,{"emptyCustomField"}) else   #"Pivoted Column"
        in
            ContactsTable;

//Flter by Subject
FactSetRMS.GetNotes = Value.ReplaceType(GetNotesImpl, GetNotesType);

GetNotesType = type function (
    optional subjectId as (type text meta [
        Documentation.SampleValues = { "c77b269c-840a-47b7-84e9-1e875e1d582b" }
    ]),
    optional authorId as (type text meta [
        Documentation.SampleValues = { "c77b269c-840a-47b7-84e9-1e875e1d582b" }
    ]),
    optional recommendationIds as (type text meta [
        Documentation.SampleValues = { "c77b269c-840a-47b7-84e9-1e875e1d582b" }
    ]),
    optional sentimentIds as (type text meta [
        Documentation.SampleValues = { "c77b269c-840a-47b7-84e9-1e875e1d582b" }
    ]),
    optional startDate as (type text meta [
        Documentation.SampleValues = { "2022-01-27" }
    ]),
    optional endDate as (type text meta [
        Documentation.SampleValues = { "2022-01-27" }
    ]),
    optional modifiedSince as (type text meta [
        Documentation.SampleValues = { "2022-01-27" }
    ]))
    as text meta [
        Documentation.Name = "",
        Documentation.LongDescription = "This function returns the Notes with Subject, Authors, Recommendations, Sentiments and Dates"
    ];
   
GetNotesImpl = (
    optional subjectId as text,
    optional authorId as text,
    optional recommendationIds as text,
    optional sentimentIds as text,
    optional startDate as text,
    optional endDate as text,
    optional modifiedSince as text
    ) as table =>
    let
        authorsTable = GetAuthors(),
        sentimentsTable = GetSentiments(),
        recommendationsTable = GetRecommendations(),
        subjectsTable = GetSubjects(),
        apiUrl = API_HOST & "notes?",
        subjects = if subjectId is null then "" else getCommaSeparted(subjectId, "subjects"),
        authors = if authorId is null then "" else getCommaSeparted(authorId, "authors"),
        recommendations = if recommendationIds is null then "" else getCommaSeparted(recommendationIds, "recommendations"),
        sentiments = if sentimentIds is null then "" else getCommaSeparted(sentimentIds, "sentiments"),
        startdate = if startDate is null then "" else getCommaSeparted(startDate, "start"), 
        enddate = if endDate is null then "" else getCommaSeparted(endDate, "end"),
        modifiedSince = if modifiedSince is null then "" else getCommaSeparted(Text.Combine({modifiedSince,"T00:00:00Z"}), "modifiedSince"),
        response = Web.Contents(apiUrl & subjects & authors & recommendations & sentiments & startdate & enddate & modifiedSince, [Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        jsonToTable = Table.FromList(responseJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        notesTableFromJson = Table.ExpandRecordColumn(jsonToTable, "Column1", {"id", "date", "createdAt", "authorId", "contributorId", 
        "title", "identifier", "subjectId", "isPersonal", "state", "approvalStatus","recommendationId", 
        "sentimentId","relatedSymbols","customFields"}),
        #"Merged Queries" = Table.NestedJoin(Table.NestedJoin(Table.NestedJoin(Table.NestedJoin(notesTableFromJson, 
                            {"authorId"}, authorsTable, {"id"}, "Authors", JoinKind.LeftOuter),
                            {"subjectId"}, subjectsTable, {"id"}, "Subjects", JoinKind.LeftOuter),
                            {"sentimentId"}, sentimentsTable, {"id"}, "Sentiments", JoinKind.LeftOuter),
                            {"recommendationId"}, recommendationsTable, {"id"}, "Recommendations", JoinKind.LeftOuter),
        #"Expanded Authors"  = Table.ExpandTableColumn(#"Merged Queries", "Authors", {"Author name"}, {"author"}),
        #"Expanded Subjects" = Table.ExpandTableColumn(#"Expanded Authors", "Subjects", {"name"}, {"subject"}),
        #"Expanded Sentiments" = Table.ExpandTableColumn(#"Expanded Subjects", "Sentiments", {"name"}, {"sentiment"}),
        #"Expanded Recommendations" = Table.ExpandTableColumn(#"Expanded Sentiments", "Recommendations", {"name"}, {"recommendation"}),
        #"Extracted RelatedSymbols" = Table.TransformColumns(#"Expanded Recommendations", {"relatedSymbols", each Text.Combine(List.Transform(_, Text.From), ","), type text}),
        #"Replaced EmptyRelatedSymbolsAsNull" = Table.ReplaceValue(#"Extracted RelatedSymbols","",null,Replacer.ReplaceValue,{"relatedSymbols"}),
        #"Expand customField list" = Table.ExpandListColumn(#"Replaced EmptyRelatedSymbolsAsNull", "customFields"),
        #"Expand customField record" = Table.ExpandRecordColumn(#"Expand customField list" , "customFields",{"code","value","options"}),
        #"Replaced null" = Table.ReplaceValue( #"Expand customField record",null,"emptyCustomField",Replacer.ReplaceValue,{"code"}),
        #"Extracted optionList" = Table.TransformColumns(#"Replaced null", {"options", each Text.Combine(List.Transform(_, Text.From), ","), type text}),
        #"Replaced Errors" = Table.ReplaceErrorValues( #"Extracted optionList", {{"options", null}}),
        #"Replaced Empty" = Table.ReplaceValue(#"Replaced Errors","",null,Replacer.ReplaceValue,{"options"}),
        #"Merged optionsValue" = Table.CombineColumns(#"Replaced Empty",{"value", "options"},Combiner.CombineTextByDelimiter("", QuoteStyle.None),"customField.value"),
        #"Pivoted codeValue" = Table.Pivot(#"Merged optionsValue", List.Distinct(#"Merged optionsValue"[code]), "code", "customField.value"),
        notesTable = Table.RemoveColumns(#"Pivoted codeValue",{"subjectId", "recommendationId", "sentimentId", "authorId"}),
        NotesTable = if Table.HasColumns(notesTable ,"emptyCustomField") then  Table.RemoveColumns( notesTable ,{"emptyCustomField"}) else  notesTable 
    in
        NotesTable;

//Get Single note with id
FactSetRMS.GetNote = Value.ReplaceType(getNoteImpl, getNoteType);

getNoteType = type function (
    noteId as (type text meta [
        Documentation.SampleValues = { "c77b269c-840a-47b7-84e9-1e875e1d582b" }
    ]))
    as text meta [
        Documentation.Name = "",
        Documentation.LongDescription = "This function returns Note"
    ];
   
getNoteImpl = (
    noteId as text
    ) as table =>
    let
        apiUrl = API_HOST & "notes/",
        response = Web.Contents(apiUrl & noteId, [Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        #"Converted to Table" = Record.ToTable(responseJson),
        #"Transposed Table" = Table.Transpose(#"Converted to Table"),
        #"Promoted Headers" = Table.PromoteHeaders(#"Transposed Table", [PromoteAllScalars=true]),
        #"Transformed Table" = Table.TransformColumnTypes(#"Promoted Headers",{{"id", type text}, {"date", type date}, {"createdAt", type datetime}, 
                            {"authorId", type text}, {"contributorId", type text}, {"title", type text}, {"identifier", type text}, 
                            {"relatedSymbols", type any}, {"subjectId", type text}, {"recommendationId", type text}, {"sentimentId", type text}, 
                            {"source", type any}, {"link", type any}, {"body", type text}, {"isPersonal", type logical}, {"state", type text}, 
                            {"approvalStatus", type any}, {"averageRating", type any}, {"relatedRecords", type any}, {"relatedContacts", type any}, 
                            {"customFields", type any}}),
        #"Expanded CustomField" = Table.ExpandListColumn( #"Transformed Table", "customFields"),
        #"Expanded CustomFieldRecord"= Table.ExpandRecordColumn( #"Expanded CustomField", "customFields", {"code", "value","options"}),
        #"Replaced null" = Table.ReplaceValue( #"Expanded CustomFieldRecord",null,"emptyCustomField",Replacer.ReplaceValue,{"code"}),
        #"Extracted optionList" = Table.TransformColumns(#"Replaced null", {"options", each Text.Combine(List.Transform(_, Text.From), ","), type text}),
        #"Replaced Errors" = Table.ReplaceErrorValues( #"Extracted optionList", {{"options", null}}),
        #"Replaced Empty" = Table.ReplaceValue(#"Replaced Errors","",null,Replacer.ReplaceValue,{"options"}),
        #"Merged optionsValue" = Table.CombineColumns(#"Replaced Empty",{"value", "options"},Combiner.CombineTextByDelimiter("", QuoteStyle.None),"customField.value"),
        #"Expanded relatedRecords" = Table.ExpandRecordColumn( #"Merged optionsValue", "relatedRecords", {"noteIds", "meetingIds"}, {"relatedRecords.noteIds", "relatedRecords.meetingIds"}),
        #"Expanded relatedRecords.noteIds" = Table.ExpandListColumn(#"Expanded relatedRecords", "relatedRecords.noteIds"),
        #"Expanded relatedRecords.meetingIds" = Table.ExpandListColumn(#"Expanded relatedRecords.noteIds", "relatedRecords.meetingIds"),
        #"Expanded relatedContacts" = Table.ExpandListColumn(#"Expanded relatedRecords.meetingIds", "relatedContacts"),
        #"Extracted RelatedSymbols" = Table.TransformColumns(#"Expanded relatedContacts", {"relatedSymbols", each Text.Combine(List.Transform(_, Text.From), ","), type text}),
        #"Replaced EmptyRelatedSymbolsAsNull" = Table.ReplaceValue(#"Extracted RelatedSymbols","",null,Replacer.ReplaceValue,{"relatedSymbols"}),
        #"Pivoted Column" = Table.Pivot( #"Replaced EmptyRelatedSymbolsAsNull", List.Distinct( #"Replaced EmptyRelatedSymbolsAsNull"[code]), "code", "customField.value"),
        NotesTable = if Table.HasColumns(#"Pivoted Column" ,"emptyCustomField") then  Table.RemoveColumns( #"Pivoted Column" ,{"emptyCustomField"}) else  #"Pivoted Column"   
 in
        NotesTable;

//Get Single meeting with id
FactSetRMS.GetMeeting = Value.ReplaceType(getMeetingImpl, getMeetingType);

getMeetingType = type function (
    meetingId as (type text meta [
        Documentation.SampleValues = { "c77b269c-840a-47b7-84e9-1e875e1d582b" }
    ])
    )
    as text meta [
        Documentation.Name = "",
        Documentation.LongDescription = "This function returns a meeting"
    ];

getMeetingImpl = (
    meetingId as text
    ) as table =>
    let
        apiUrl = API_HOST & "meetings/",
        response = Web.Contents(apiUrl & meetingId, [Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        #"Converted to Table" = Record.ToTable(responseJson),
        #"Transposed Table" = Table.Transpose(#"Converted to Table"),
        #"Promoted Headers" = Table.PromoteHeaders(#"Transposed Table", [PromoteAllScalars=true]),
        #"Changed Type" = Table.TransformColumnTypes(#"Promoted Headers",{{"id", type text}})

    in
        #"Changed Type";

//Get meeting with date
FactSetRMS.GetMeetings = Value.ReplaceType(getMeetingsImpl, getMeetingsType);

getMeetingsType = type function (
    optional startDate as (type text meta [
        Documentation.SampleValues = { "2022-01-01" }
    ]),
    optional EndDate as (type text meta [
        Documentation.SampleValues = { "2022-01-01" }
    ]),
    optional modifiedSince as (type text meta [
        Documentation.SampleValues = { "2022-01-01" }
    ])
    )
    as text meta [
        Documentation.Name = "",
        Documentation.LongDescription = "This function returns a meeting"
    ];

getMeetingsImpl = (
    optional startDate as text,
    optional endDate as text,
    optional modifiedSince as text
) as table =>
let
    authorsTable = GetAuthors(),
    apiUrl = API_HOST & "meetings?",
    startDate = if startDate is null then "" else getCommaSeparted(Text.Combine({startDate,"T00:00:00Z"}), "start"), 
    endDate = if endDate is null then "" else getCommaSeparted(Text.Combine({endDate,"T12:12:00Z"}), "end"), 
    modifiedSince = if modifiedSince is null then "" else getCommaSeparted(Text.Combine({modifiedSince,"T00:00:00Z"}), "end"), 
    response = Web.Contents(apiUrl & startDate & endDate, [Headers = headers]),
    responseJson = Json.Document(Text.FromBinary(response)),
    jsonToTable = Table.FromList(responseJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    meetingsTable= Table.ExpandRecordColumn(jsonToTable, "Column1", {"id", "start", "end", "createdAt", "authorId",
    "title", "identifier", "organizer", "organizerId", "attachmentIds", "relatedSymbols", "locations", "attendees", "customFieldValues"}),
    #"Merged Queries" = Table.NestedJoin(meetingsTable, {"authorId"}, authorsTable, {"id"}, "Authors", JoinKind.LeftOuter),
    #"Expanded Authors"  = Table.ExpandTableColumn(#"Merged Queries", "Authors", {"Author name"}, {"author"}),
    meetings = Table.RemoveColumns(#"Expanded Authors",{"authorId"})
 in
      meetings;

//Get customsymbol with id
FactSetRMS.GetCustomSymbol = Value.ReplaceType(GetCustomSymbolImpl, GetCustomSymbolType);
GetCustomSymbolType = type function  ( 
        CustomSymbolId as (type text meta [
        Documentation.SampleValues = { "3af1a3a1-8213-40e7-a0cb-a696f5163dac" }
    ]))
    as text meta [
        Documentation.Name = "",
        Documentation.LongDescription = "This function returns Custom Symbol"
    ];

GetCustomSymbolImpl = (
        CustomSymbolId as text
        ) as table =>
    let
        apiUrl = API_HOST & "custom-symbols/",
        response = Web.Contents(apiUrl & CustomSymbolId, [Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        #"Converted to Table" = Record.ToTable(responseJson),
        #"Transposed Table" = Table.Transpose(#"Converted to Table"),
        #"Promoted Headers" = Table.PromoteHeaders(#"Transposed Table", [PromoteAllScalars=true]),
        #"Expanded type" = Table.TransformColumnTypes(#"Promoted Headers",{{"id", type text},{"code", type text}, {"createdDate", type date}, {"type", type any},
                            {"createdBy", type text}, {"standardSymbol", type text}, 
                            {"address", type any}, {"customFields", type any},  {"isAddressAutoFilled", type logical}, {"isDescriptionAutoFilled", type logical}}),
        #"Expanded CustomSymbolsType" = Table.ExpandRecordColumn( #"Expanded type", "type", {"id","name"}, {"type.id","type.name"}),
        #"Expanded customFields" = Table.ExpandListColumn( #"Expanded CustomSymbolsType", "customFields"),
        #"Expanded customFields1" = Table.ExpandRecordColumn(#"Expanded customFields", "customFields", {"code", "value", "optionValues"}, {"customFields.code", "customFields.value", "customFields.optionValues"}),
        #"Extracted Values" = Table.TransformColumns(#"Expanded customFields1", {"customFields.optionValues", each Text.Combine(List.Transform(_, Text.From), ","), type text}),
        #"Replaced Value" = Table.ReplaceValue(#"Extracted Values","",null,Replacer.ReplaceValue,{"customFields.optionValues"}),
        #"Merged Columns" = Table.CombineColumns(#"Replaced Value",{"customFields.value", "customFields.optionValues"},Combiner.CombineTextByDelimiter("", QuoteStyle.None),"customFields.value.1"),
        #"Replaced Value1" = Table.ReplaceValue(#"Merged Columns",null,"emptyCustomField",Replacer.ReplaceValue,{"customFields.code"}),
        #"Replaced Errors" = Table.ReplaceErrorValues(#"Replaced Value1", {{"customFields.value.1", null}}),
        #"Reordered Columns" = Table.ReorderColumns(#"Replaced Errors",{"id", "code", "name", "description", "type.id", "type.name", "subType", "customFields.code", "customFields.value.1", "createdDate", "createdBy", "address", "standardSymbol", "standardSymbolInstrumentData", "isAddressAutoFilled", "isDescriptionAutoFilled"}),
        #"Expanded address" = Table.ExpandRecordColumn(#"Reordered Columns", "address", {"googleMapsPlaceId", "formattedAddress", "city", "stateProvince", "postalCode", "country"}, {"address.googleMapsPlaceId", "address.formattedAddress", "address.city", "address.stateProvince", "address.postalCode", "address.country"}),
        #"standardSymbol List" = Table.Column(#"Expanded address","standardSymbol"),    
        #"Expanded standardSymbolInstrumentData" = if List.Contains(#"standardSymbol List",null) then #"Expanded address" 
                                                   else Table.ExpandRecordColumn(#"Expanded address", "standardSymbolInstrumentData", {"symbol", "tickerRegion", "tickerExchange", "sedol", "cusip", "isin", "instrumentName", "identifiers"}, 
                                                        {"standardSymbolInstrumentData.symbol", "standardSymbolInstrumentData.tickerRegion", "standardSymbolInstrumentData.tickerExchange", "standardSymbolInstrumentData.sedol", "standardSymbolInstrumentData.cusip", "standardSymbolInstrumentData.isin", "standardSymbolInstrumentData.instrumentName", "standardSymbolInstrumentData.identifiers"}),
        #"Extracted Values1" = if List.Contains(#"standardSymbol List",null) then #"Expanded standardSymbolInstrumentData" else Table.TransformColumns(#"Expanded standardSymbolInstrumentData" , {"standardSymbolInstrumentData.identifiers", each Text.Combine(List.Transform(_, Text.From), ","), type text}),
        #"subType List" = Table.Column(#"Extracted Values1","subType"),
        #"Expanded subType" = if List.Contains(#"subType List",null) then #"Extracted Values1" else  Table.ExpandRecordColumn(#"Extracted Values1", "subType", {"id", "name"}, {"subType.id", "subType.name"}),
        #"Pivoted Column" = Table.Pivot(#"Expanded subType", List.Distinct(#"Expanded subType"[customFields.code]), "customFields.code", "customFields.value.1"),
        CustomSymbolTable = if Table.HasColumns(#"Pivoted Column","emptyCustomField") then  Table.RemoveColumns(#"Pivoted Column",{"emptyCustomField"}) else #"Pivoted Column" 
    in
        CustomSymbolTable;

 //Custom symbols Filter by custom type
FactSetRMS.GetCustomSymbolsFiltered = Value.ReplaceType( GetCustomSymbolsFilteredImpl, GetCustomSymbolsFilteredType);

GetCustomSymbolsFilteredType = type function (
    optional CustomSymbolTypeName as (type text meta [
        Documentation.SampleValues = { "Custom" }
    ]))
    as text meta [
        Documentation.Name = "",
        Documentation.LongDescription = "This function returns the Custom Symbol with Type"
    ];
   
GetCustomSymbolsFilteredImpl= (
    optional CustomSymbolTypeName as text
    ) as table =>
    let
       
        apiUrl = API_HOST & "custom-symbols?includeCustomFieldValues=true",
        typename = if CustomSymbolTypeName is null then "" else getCommaSeparted(CustomSymbolTypeName, "typeName"),
        response = Web.Contents(apiUrl & typename, [Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        JsonToTable = Table.FromList(responseJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
     
        #"Expanded CustomSymbolsFilteredTable" = Table.ExpandRecordColumn(JsonToTable, "Column1", {"id","code", "name","type","description","createdDate","createdBy", "standardSymbol",
                                                                                        "isAddressAutoFilled","isDescriptionAutoFilled","customFields"}),
        #"Expanded CustomSymbolsType" = Table.ExpandRecordColumn(#"Expanded CustomSymbolsFilteredTable", "type", {"id","name"}, {"type.id","type.name"}),
        #"Expanded customFields" = Table.ExpandListColumn( #"Expanded CustomSymbolsType", "customFields"),
        #"Expanded customFieldsValues"= Table.ExpandRecordColumn(#"Expanded customFields", "customFields", {"code", "value", "optionValues"}, {"customFields.code", "customFields.value", "customFields.optionValues"}),
        #"Extracted Values" = Table.TransformColumns(#"Expanded customFieldsValues", {"customFields.optionValues", each Text.Combine(List.Transform(_, Text.From), ","), type text}),
        #"Replaced Errors" = Table.ReplaceErrorValues(#"Extracted Values", {{"customFields.optionValues", ""}}),
        #"Replaced Value" = Table.ReplaceValue(#"Replaced Errors","",null,Replacer.ReplaceValue,{"customFields.optionValues"}),
        #"Merged Columns" = Table.CombineColumns(#"Replaced Value",{"customFields.value", "customFields.optionValues"},Combiner.CombineTextByDelimiter("", QuoteStyle.None),"customFields.values"),
        #"Replaced nullValue" = Table.ReplaceValue(#"Merged Columns",null,"emptyCustomField",Replacer.ReplaceValue,{"customFields.code"}),
        #"Pivoted Column" = Table.Pivot(#"Replaced nullValue", List.Distinct(#"Replaced nullValue"[customFields.code]), "customFields.code", "customFields.values"), 
       
         CustomSymbolsFilteredTable= if Table.HasColumns(#"Pivoted Column","emptyCustomField") then  Table.RemoveColumns(#"Pivoted Column",{"emptyCustomField"}) else #"Pivoted Column" 
    in
        CustomSymbolsFilteredTable; 

//Get Contacts Filtered by Full name

FactSetRMS.GetContactsFiltered = Value.ReplaceType(getContactsFilteredImpl, getContactsFilteredType);

getContactsFilteredType = type function (
    optional contactName as (type text meta [
        Documentation.SampleValues = { "Contact Full Name" }
    ]))
    as text meta [
        Documentation.Name = "",
        Documentation.LongDescription = "This function returns Contacts"
    ];
   
getContactsFilteredImpl = (
    optional contactName as text
    ) as table =>
    let
        apiUrl = API_HOST & "contacts?",
        fullname = if contactName is null then "" else getCommaSeparted(contactName, "fullName"),
        response = Web.Contents(apiUrl & fullname & "&&customFieldValues=true&includeLastMeetingDate=true", [Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        JsonToTable = Table.FromList(responseJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn( JsonToTable, "Column1", {"id", "primaryEmailAddress", "identifier", "fullName", "employerName", 
                                                                                       "employerIdentifier", "city", "stateProvince", "postalCode", "country", "role", "type", "isDeleted", 
                                                                                       "lastMeeting", "alternativeEmailAddresses", "customFieldValues"}, {"id", "primaryEmailAddress", "identifier", "fullName", "employerName",
                                                                                       "employerIdentifier", "city", "stateProvince", "postalCode", "country", "role", "type", "isDeleted", "lastMeeting", "alternativeEmailAddresses", "customFieldValues"}),
        #"Expanded type" = Table.ExpandRecordColumn(#"Expanded Column1", "type", {"id", "name"}, {"type.id", "type.name"}),
        #"Expanded role" = Table.ExpandRecordColumn(#"Expanded type", "role", {"id", "name"}, {"role.id", "role.name"}),
        #"Expanded alternativeEmailAddresses" = Table.ExpandListColumn(#"Expanded role", "alternativeEmailAddresses"),
        #"Expanded alternativeEmailAddresses1" = Table.ExpandRecordColumn(#"Expanded alternativeEmailAddresses", "alternativeEmailAddresses", {"id", "emailAddress"}, {"alternativeEmailAddresses.id", "alternativeEmailAddresses.emailAddress"}),
        #"Grouped Rows" = Table.Group(#"Expanded alternativeEmailAddresses1", {"id", "primaryEmailAddress", "identifier", "fullName", "employerName", "employerIdentifier", "city", "stateProvince", "postalCode", "country", 
                                      "role.id", "role.name", "type.id", "type.name", "isDeleted", "lastMeeting", "customFieldValues"}, {{"alternativeEmailAddresses.id", each Text.Combine([alternativeEmailAddresses.id],","), type text},
                                      {"alternativeEmailAddresses.emailAddress", each Text.Combine([alternativeEmailAddresses.emailAddress],","), type text}}),
        #"Expanded customFieldValues" = Table.ExpandListColumn(#"Grouped Rows", "customFieldValues"),
        #"Expanded customFieldValues1" = Table.ExpandRecordColumn(#"Expanded customFieldValues", "customFieldValues", {"fieldCode", "value"}, {"customFieldValues.fieldCode", "customFieldValues.value"}),
        #"Replaced Value" = Table.ReplaceValue(#"Expanded customFieldValues1",null,"emptyCustomField",Replacer.ReplaceValue,{"customFieldValues.fieldCode"}),
        #"Pivoted Column" = Table.Pivot(#"Replaced Value", List.Distinct(#"Replaced Value"[customFieldValues.fieldCode]), "customFieldValues.fieldCode", "customFieldValues.value"),
        ContactsTable = if Table.HasColumns(  #"Pivoted Column" ,"emptyCustomField") then  Table.RemoveColumns(  #"Pivoted Column" ,{"emptyCustomField"}) else   #"Pivoted Column"
    in
        ContactsTable;

//Get Contact with Id

FactSetRMS.GetContact = Value.ReplaceType(getContactImpl, getContactType);

getContactType = type function (
    contactId as (type text meta [
        Documentation.SampleValues = { "c77b269c-840a-47b7-84e9-1e875e1d582b" }
    ]))
    as text meta [
        Documentation.Name = "",
        Documentation.LongDescription = "This function returns Contact"
    ];
   
getContactImpl = (
    contactId as text
    ) as table =>
    let
        apiUrl = API_HOST & "contacts/",
        response = Web.Contents(apiUrl & contactId, [Headers = headers]),
        responseJson = Json.Document(Text.FromBinary(response)),
        #"Converted to Table" = Record.ToTable(responseJson),
        #"Transposed Table" = Table.Transpose(#"Converted to Table"),
        #"Promoted Headers" = Table.PromoteHeaders(#"Transposed Table", [PromoteAllScalars=true]),
        #"Expanded address" = Table.ExpandRecordColumn(#"Promoted Headers", "address", {"googleMapsPlaceId", "formattedAddress", "city", "stateProvince", "postalCode", "country"},
                                                                                        {"address.googleMapsPlaceId", "address.formattedAddress", "address.city", "address.stateProvince", "address.postalCode", "address.country"}),
        #"Expanded employer" = Table.ExpandRecordColumn(#"Expanded address", "employer", {"id", "name", "factsetIdentifier"}, {"employer.id", "employer.name", "employer.factsetIdentifier"}),
        #"Expanded role" = Table.ExpandRecordColumn(#"Expanded employer", "role", {"id", "name"}, {"role.id", "role.name"}),
        #"Expanded type" = Table.ExpandRecordColumn(#"Expanded role", "type", {"id", "name"}, {"type.id", "type.name"}),
        #"Expanded customFields" = Table.ExpandListColumn(#"Expanded type", "customFields"),
        #"Expanded customFields1" = Table.ExpandRecordColumn(#"Expanded customFields", "customFields", {"fieldCode", "value"}, {"customFields.fieldCode", "customFields.value"}),
        #"Replaced null" = Table.ReplaceValue( #"Expanded customFields1",null,"emptyCustomField",Replacer.ReplaceValue,{"customFields.fieldCode"}),
        #"Expanded alternativeEmailAddresses" = Table.ExpandListColumn(#"Replaced null", "alternativeEmailAddresses"),
        #"Expanded alternativeEmailAddresses1" = Table.ExpandRecordColumn(#"Expanded alternativeEmailAddresses", "alternativeEmailAddresses", {"id", "emailAddress"}, {"alternativeEmailAddresses.id", "alternativeEmailAddresses.emailAddress"}),
        #"Grouped Rows" = Table.Group(#"Expanded alternativeEmailAddresses1", {"id", "primaryEmailAddress", "identifier", "fullName", "address.googleMapsPlaceId",
                                                                                "address.formattedAddress", "address.city", "address.stateProvince", "address.postalCode", "address.country", 
                                                                                "linkedInProfile", "isDeleted", "employer.id", "employer.name", "employer.factsetIdentifier", "role.id", "role.name", 
                                                                                "type.id", "type.name", "phoneNumbers", "customFields.fieldCode", "customFields.value"}, {{"alternativeEmailAddresses.id", each Text.Combine([alternativeEmailAddresses.id],","), type text},
                                                                                {"alternativeEmailAddresses.emailAddress", each Text.Combine([alternativeEmailAddresses.emailAddress],","), type text}}),
        #"Expanded phoneNumbers" = Table.ExpandListColumn(#"Grouped Rows", "phoneNumbers"),  
        #"Expanded phoneNumbers1" = Table.ExpandRecordColumn(#"Expanded phoneNumbers", "phoneNumbers", {"id", "number", "type", "isPrimary"}, {"phoneNumbers.id", "phoneNumbers.number", "phoneNumbers.type", "phoneNumbers.isPrimary"}),
        #"Expanded phoneNumbers.type" = Table.ExpandRecordColumn(#"Expanded phoneNumbers1", "phoneNumbers.type", {"id", "name", "isStandard"}, {"phoneNumbers.type.id", "phoneNumbers.type.name", "phoneNumbers.type.isStandard"}),
        #"Pivoted Column" = Table.Pivot(#"Expanded phoneNumbers.type", List.Distinct(#"Expanded phoneNumbers.type"[customFields.fieldCode]), "customFields.fieldCode", "customFields.value"),
        ContactsTable = if Table.HasColumns( #"Pivoted Column" ,"emptyCustomField") then  Table.RemoveColumns( #"Pivoted Column" ,{"emptyCustomField"}) else  #"Pivoted Column"  
 in
       ContactsTable;

getCommaSeparted = (params as text, entity as text) =>
    let
        myList = Text.Split(params,","),
        queryString ="&" & entity & "=" & Text.Combine(myList, "&" & entity & "=")
    in 
        queryString;

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