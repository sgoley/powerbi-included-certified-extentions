[Version = "1.0.0"]
section inwink;

authSettings = [
    auth_uri = "https://auth.inwink.com",
    redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html",
    client_id = "inwink-powerbi-datasource",
    client_secret = "818f54a1-6518-4c47-8fa7-aef5514e52c9"
];

apiSettings = [
    backoffice = "https://api-backoffice.inwink.com/",
    event = "https://api-event.inwink.com/",
    community = "https://api-community.inwink.com/", 
    customer = "https://api-customer.inwink.com/"
];

AuthSetup = Extension.LoadFunction("auth.startlogin.pqm");

// Data Source Kind description
inwink = [
    TestConnection = (dataSourcePath) => 
        let
            json = Json.Document(dataSourcePath),
            customerId = json[customerId],
            scope = json[scope],
            scopeId = json[scopeId]
        in
            {"inwink.ScopeContents", customerId, scope, scopeId},
    Authentication = AuthSetup(authSettings),
    Label = "inwink"
];

// Data Source UI publishing description
inwink.Contents = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = inwink.Icons,
    SourceTypeImage = inwink.Icons
];

inwink.Icons = [
    Icon16 = { Extension.Contents("inwink16.png"), Extension.Contents("inwink20.png"), Extension.Contents("inwink24.png"), Extension.Contents("inwink32.png") },
    Icon32 = { Extension.Contents("inwink32.png"), Extension.Contents("inwink40.png"), Extension.Contents("inwink48.png"), Extension.Contents("inwink64.png") }
];

[DataSource.Kind="inwink", Publish="inwink.Contents"]
shared inwink.ScopeContents = Value.ReplaceType(GetScopeEntities, InwinkScopeType);

InwinkScopeType = type function (
    customerId as (type text meta [
        Documentation.FieldCaption = "inwink customer ID",
        Documentation.FieldDescription = "your inwink customer unique identifier",
        Documentation.SampleValues = {"662cc909-4695-4fc1-b3f3-b194c63256c4", "e63a2cea-3f80-46f5-9b02-7b934dfbbe8a"}
    ]),
    scope as (type text meta [
        Documentation.FieldCaption = "Scope",
        Documentation.FieldDescription = "Scope of the data",
        Documentation.AllowedValues = { "Audience", "Event", "Community" }
    ]),
    scopeId as (type text meta [
        Documentation.FieldCaption = "inwink scope Id",
        Documentation.FieldDescription = "inwink scope unique identifier (audience id or event id or community id)",
        Documentation.SampleValues = {"662cc909-4695-4fc1-b3f3-b194c63256c4", "e63a2cea-3f80-46f5-9b02-7b934dfbbe8a"}
    ])
) as table meta [
    Documentation.Name = "inwink source",
    Documentation.LongDescription = "inwink data"
];

/*
TestEntity = (eventId as text) as table =>
    let 
        data = GetEventPersons(eventId)
    in
        data;

shared inwink.TestApiConnection = (customerId as text, scope as text, scopeId as text)  =>
    let
            url = apiSettings[backoffice] & "/me",
            body = "{}",
            apiResponse = Json.Document(Web.Contents(url,[
                Headers = [
                    #"Content-Type"="application/json"
                ],
                Content = Text.ToBinary(body) 
                ]
            )),
            userInfos = apiResponse 
            //userInfos = Diagnostics.Trace(TraceLevel.Information, "Test connection for " & customerId & " " & scope & " " & scopeId, apiResponse)
    in
        userInfos;
*/

GetScopeEntities = (customerId as text, scope as text, scopeId as text) as table =>
    let
        tenantData = if (scope = "Audience") then GetTenantEntities(customerId, scopeId) else null,
        eventData = if (scope = "Event") then GetEventEntities(customerId, scopeId) else tenantData,
        communityData = if (scope = "Community") then GetCommunityEntities(customerId, scopeId) else eventData,
        result = communityData
        //result = GetEntityData(apiSettings[event] & scopeId, EventEntitiesConfig, EventEntitiesConfig[SessionPerson])
        //result = GetEventPersons(customerId, scopeId, EventEntitiesConfig, EventEntitiesConfig[Person]) 
    in
        result;

DefaultEntitySelect = Record.AddField([], "$all", true);
DefaultSort = [ desc = true, value = "id"];


/// ---------------------------------------------------
/// Event
/// ---------------------------------------------------

PersonKindConfig = [ 
    ApiEntityName = "personkind"
];

EventEntitiesConfig = [
    Event_Person = [ 
        ApiEntityName = "person",
        OrderBy = [ desc = true, value = "validFrom" ],
//         Select = DefaultEntitySelect,
        DataProvider = GetEventPersons,
        Relations = {
            //[Name = "Session", ForeignKey="sessionId", ParentKey="id", ToColumn="toSession"],
            [Name = "SessionPerson", ForeignKey="id", ParentKey="personId", ToColumn="toSessionPersons"]
        }
    ],
    Event_Session = [
        ApiEntityName = "session",
        DataProvider = GetGatheringEntity
    ],
    Event_SessionOnlineActivity = [ ApiEntityName = "sessiononlineactivity" ],
    Event_SessionPerson = [
        ApiEntityName = "sessionperson"
        // Relations = {
        //     [Name = "Session", ForeignKey="sessionId", ParentKey="id", ToColumn="toSession"],
        //     [Name = "Person", ForeignKey="personId", ParentKey="id", ToColumn="toPerson"]
        // }
    ],
    Event_Exhibitor = [ ApiEntityName = "exhibitor" ],
    Event_ExhibitorScan = [ ApiEntityName = "exhibitorscan" ],
    Event_ExhibitorAccount = [ ApiEntityName = "exhibitoraccount" ],
    Event_PersonFavoriteExhibitor = [ ApiEntityName = "personfavoriteexhibitor" ],
    Event_PersonFavoriteExhibitorOffering = [ ApiEntityName = "personfavoriteexhibitoroffering" ],
    Event_ExhibitorOffering = [ ApiEntityName = "exhibitoroffering" ],
    Event_UserActivityUserSession = [ ApiEntityName = "useractivityusersession" ],
    Event_Product = [ ApiEntityName = "product" ],
    Event_Order = [ ApiEntityName = "order" ],
    Event_OrderItem = [ ApiEntityName = "orderitem" ],
    Event_RoundTable = [ ApiEntityName = "roundtable" ],
    Event_RoundTableParticipant = [ ApiEntityName = "roundtableparticipant" ],
    Event_Meeting = [
        ApiEntityName = "meeting",
        DataProvider = GetGatheringEntity
    ],
    Event_MeetingPerson = [ ApiEntityName = "meetingperson" ],
    Event_MeetingFeedback = [ ApiEntityName = "meetingfeedback" ],
    Event_Survey = [ ApiEntityName = "survey" ],
    Event_SurveyAnswer = [ ApiEntityName = "surveyanswer" ],
    Event_Mail = [ ApiEntityName = "mailperson" ]
];

ApplyKinds = (person, kinds) => 
    let
        patch = Record.FromTable(
            Table.FromRecords(List.Transform(kinds, (kind) =>
                let
                    hasKind = if (Record.HasFields(person, "kinds") = false) then false else List.Contains(person[kinds], kind[code]),
                    kd = [Name = "inwink_kind_" & kind[code], Value=hasKind]
                in 
                    kd
            ))
        ),
        //updatedPerson = person //Record.AddField(patch, "id", person[id])
        updatedPerson = Record.Combine({person, patch})
    in 
        updatedPerson;

GetEventPersons = (customerId as text, eventId as text, scopeConfig, entityConf) as table =>
    let
        personKinds = GetEntityData(apiSettings[event] & eventId, scopeConfig, PersonKindConfig, null),
        kinds = Table.ToRecords(personKinds),
        persons = GetEntityData(apiSettings[event] & eventId, scopeConfig, entityConf, (srcRecords) => 
            let
                records = List.Transform(srcRecords, each ApplyKinds(_, kinds))
            in
                records
        )
    in
        persons;

FlatTimeslot = (gatherings) =>
    let
        altered = List.Transform(gatherings, (gathering) => 
            let 
                firstTimeslot = if (Record.HasFields(gathering, "timeslots") = true) then List.First(Record.Field(gathering, "timeslots")) else [],
                datepatch = Record.FromTable(
                    Table.FromRecords(List.Transform({"id", "roomId", "room.name", "startDate", "endDate"}, (fn) =>
                        let
                            splits = Text.Split(fn, "."),
                            entityName = List.First(splits),
                            fieldName = List.Last(splits),
                            record = if (firstTimeslot = null) then null else (if (Text.Contains(fn, ".")) then (if (Record.HasFields(firstTimeslot, entityName)) then Record.Field(firstTimeslot, entityName) else null) else firstTimeslot),
                            field = if (record = null) then null else if (Record.HasFields(record, fieldName)) then (if (Text.EndsWith(fieldName, "Date")) then DateTime.FromText(Record.Field(record, fieldName)) else Record.Field(record, fieldName)) else null,
                            kd = [Name = "inwink_timeslot_" & (if (List.Count(splits) > 1) then (entityName & Text.Proper(fieldName)) else fieldName), Value=field]
                        in 
                            kd
                    ))
                ), 
                removePrevious = if (Record.HasFields(gathering, "timeslots") = true) then Record.RemoveFields(gathering, "timeslots") else gathering,
                updatedRecord = Record.Combine({removePrevious, datepatch})
            in
                updatedRecord
        )
    in
        altered;

GetGatheringEntity = (customerId as text, eventId as text, scopeConfig, entityConf) as table =>
    let
        entityConf2 = Record.AddField(entityConf, "Select", Record.AddField(DefaultEntitySelect, "Timeslots", Record.AddField(Record.AddField([], "$all", true), "room", Record.AddField([], "$all", true)))),
        entities = GetEntityData(apiSettings[event] & eventId, scopeConfig, entityConf2, (srcRecords) => 
            let
                records = FlatTimeslot(srcRecords)
            in
                records
        )
    in
        entities;

GetEventEntities = (customerId as text, eventId as text) as table => GetEntitiesNavTable(customerId, eventId, apiSettings[event] & eventId, EventEntitiesConfig);



/// ---------------------------------------------------
/// Tenant 
/// ---------------------------------------------------

TenantEntitiesConfig = [
    Audience_Contact = [ ApiEntityName = "authtenantcontact" ],
    Audience_ContactEvent = [ ApiEntityName = "authtenantcontactevent" ],
    Audience_ContactCommunity = [ ApiEntityName = "authtenantcontactcommunity" ],
    Audience_Company = [ ApiEntityName = "authtenantcompany" ],
    Audience_CompanyEvent = [ ApiEntityName = "authtenantcompanyevent" ],
    Audience_CompanyCommunity = [ ApiEntityName = "authtenantcompanycommunity" ],
    Audience_Mail = [ ApiEntityName = "authtenantmailcontact" ]
];

GetTenantEntities = (customerId as text, tenantId as text) as table => GetEntitiesNavTable(customerId, tenantId, apiSettings[customer] & customerId & "/audience/" & tenantId, TenantEntitiesConfig);


/// ---------------------------------------------------
/// Community 
/// ---------------------------------------------------

CommunityEntitiesConfig = [
    Community_Member = [ ApiEntityName = "member" ],
    Community_MemberInfo = [ ApiEntityName = "memberInfo" ],
    Community_MembershipLevel = [ ApiEntityName = "membershiplevel" ],
     Community_Article = [ ApiEntityName = "article",
        Relations = {
            [Name = "Member", ForeignKey="memberId", ParentKey="id", ToColumn="toMember"]
        } ],
    Community_ArticleInfo = [ ApiEntityName = "articleInfo" ],
    Community_ArticleTopic = [ ApiEntityName = "articleTopic" ],
    Community_Document = [ ApiEntityName = "documentcommunity" ],
    Community_DocumentTopic = [ ApiEntityName = "documentTopic" ],
    Community_DocumentInfo = [ ApiEntityName = "documentInfo" ],
    Community_Company = [ ApiEntityName = "company" ],
    Community_CompanyAccount = [ ApiEntityName = "companyAccount" ],
    Community_CompanyInfo = [ ApiEntityName = "companyInfo" ],
    Community_CompanyOffering = [ ApiEntityName = "companyOffering" ],
    Community_Event = [ ApiEntityName = "iwevent" ],
    Community_EventTopic = [ ApiEntityName = "iweventTopic" ],
    Community_EventInfo = [ ApiEntityName = "iweventInfo" ],
    Community_Topic = [ ApiEntityName = "topic" ],
    Community_Vod = [ ApiEntityName = "vod" ],
    Community_VodTopic = [ ApiEntityName = "vodTopic" ],
    Community_VodInfo = [ ApiEntityName = "vodInfo" ],
    Community_Podcast = [ ApiEntityName = "podcast" ],
    Community_PodcastTopic = [ ApiEntityName = "podcastTopic" ],
    Community_PodcastInfo = [ ApiEntityName = "podcastInfo" ],
    Community_Mail = [ ApiEntityName = "mailmember" ],
    Community_Group = [ ApiEntityName = "group" ],
    Community_GroupInfo = [ ApiEntityName = "groupInfo" ],
    Community_Forum = [ ApiEntityName = "forum" ],
    Community_ForumInfo = [ ApiEntityName = "forumInfo" ],
    Community_ForumSubject = [ ApiEntityName = "forumSubject" ],
    Community_ForumSubjectInfo = [ ApiEntityName = "forumSubjectInfo" ],
    Community_ForumTag = [ ApiEntityName = "forumTag" ]
];

GetCommunityEntities = (customerId as text, communityId as text) as table => GetEntitiesNavTable(customerId, communityId, apiSettings[community] & communityId, CommunityEntitiesConfig);


/// ---------------------------------------------------
/// Helpers 
/// ---------------------------------------------------

// Génère une navigation table à partir d'un mapping d'entité
GetEntitiesNavTable = (customerId as text, eventId as text, baseUrl as text, scopeConfig) as table =>
    let
        entityNames = Record.FieldNames(scopeConfig),
        entityProviders = Record.FromList(List.Transform(entityNames, (entityName) => 
            let
                entityConfig = Record.Field(scopeConfig, entityName),
                entityData = if (Record.HasFields(entityConfig, "DataProvider")) then 
                        entityConfig[DataProvider](customerId, eventId, scopeConfig, entityConfig)
                    else
                        GetEntityData(baseUrl, scopeConfig, entityConfig, null)
            in
                entityData
        ), entityNames),
        entities = List.Transform(entityNames, (entityName) => 
            let
                result = {
                    entityName, Record.Field(entityProviders, entityName), "Table", "Table", true
                }
            in
                result
        ),
        source = #table({"Name", "Data", "ItemKind", "ItemName", "IsLeaf"}, entities),        
        navTable = Table.ToNavigationTable(source, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

// Récupération du schéma d'une entité
GetEntitySchema = (baseUrl as text, entityConf) =>
    let 
        url = baseUrl & "/" & entityConf[ApiEntityName] & "/worktemplate",
        entityTemplate = Json.Document(Web.Contents(url,[
            Headers = [ #"Content-Type"="application/json"]
        ])),
        fields = Record.FieldValues(entityTemplate[fields])
    in
        fields;

// Filtrage des champs selon leur type
FieldIsAllowed = (field) => 
    let
        isEntity = field[type] = "Entities" or field[type] = "Entity",
        allowed = not isEntity
    in 
        allowed;

// Récupération de la liste des codes des champs à utiliser sur l'entité
GetEntityFields = (schema, entitySample) => 
    let
        schemaFieldsToDisplay = List.Select(schema, FieldIsAllowed),
        schemaFields = List.Transform(schemaFieldsToDisplay, (fld) => fld[key]),
        entityFields = Record.FieldNames(entitySample),
        combined = List.Combine({ schemaFields, entityFields }),
        distinctFields = List.Distinct(combined)
    in
        distinctFields;

// Récupération des données d'une entité via un endpoint query, avec pagination
GetEntityData = (baseUrl as text, scopeConfig, entityConf, optional alterRecord) as table =>
    let
        url = baseUrl & "/" & entityConf[ApiEntityName] & "/query",
        schema = GetEntitySchema(baseUrl, entityConf),        
        entityData = Table.GenerateByPage((previous) => 
            let
                // if previous is null, then this is our first page of data
                nextPage = if (previous = null) then 0 else Value.Metadata(previous)[NextPage]?,
                // if NextLink was set to null by the previous call, we know we have no more data
                page = if (nextPage <> null) then GetDataPage(url, entityConf, nextPage, schema, alterRecord) else null
            in
                page
        ),
        //toTable = Table.FromList(Record, Splitter.SplitByNothing(), null, null, ExtraValues.Error),

        //Record.FieldNames(Table.Column(toTable, "Column1"){0}) => list des key dans le JSON, a remplacer par appel HTTP au template d'entité
        fieldNames = GetEntityFields(schema, Table.Column(entityData, "Column1"){0}),
        expandedEntityResult = if (Table.RowCount(entityData) = 0) then entityData else Table.ExpandRecordColumn(entityData, "Column1", fieldNames),
        entityResult = expandedEntityResult
    in
        entityResult;   

// Transformation des champs de l'entité, par exemple passage des champs date dans un type date
TransformSchemaFields = (schema, records) => 
    let
        altered = List.Transform(records, (record) => 
            let 
                dateFields = List.Select(schema, (field) => field[type] = "Date" and Record.HasFields(record, field[key])),
                dateFieldsNames = List.Transform(dateFields, (field) => field[key]),
                datepatch = Record.FromTable(
                    Table.FromRecords(List.Transform(dateFieldsNames, (fieldName) =>
                        let
                            convertedDateField = if (Record.HasFields(record, fieldName)) then DateTime.FromText(Record.Field(record, fieldName)) else null,
                            kd = [Name = fieldName, Value=convertedDateField]
                        in 
                            kd
                    ))
                ),
                removePrevious = Record.RemoveFields(record, dateFieldsNames),
                //updatedPerson = person //Record.AddField(patch, "id", person[id])
                updatedRecord = Record.Combine({removePrevious, datepatch})
            in
                updatedRecord
        )
    in
        altered;

// Appel paginé à l'api inwink et transformation des données
GetDataPage = (url as text, entityConf, pagenumber as number, schema, alterRecord) as table =>
    let
        pageSizeNumber = if (Record.HasFields(entityConf, "PageSize")) then entityConf[PageSize] else 200,
        pageSize = Number.ToText(pageSizeNumber),
        select = if (Record.HasFields(entityConf, "Select")) then entityConf[Select] else DefaultEntitySelect,
        //orderBy = if (Record.HasFields(entityConf, "OrderBy")) then """orders"":[" & entityConf[OrderBy] & "]," else "",
        currentPage = Number.ToText(pagenumber),
        bodyRecordBase = [ selects = select, page = [ index = currentPage, size = pageSize]],
        bodyRecord = if (Record.HasFields(entityConf, "OrderBy")) then Record.AddField(bodyRecordBase, "orders", {entityConf[OrderBy]}) else bodyRecordBase,
        //strbody = "{""selects"":" & select & "," & orderBy & """page"":{""index"":" & currentPage & ",""size"":" & pageSize & "}}",
        jsonBodyBase = Json.FromValue(bodyRecord),
        //jsonBody = Diagnostics.Trace(TraceLevel.Information, "Get " & entityConf[ApiEntityName] & " page " & currentPage & " " & Text.FromBinary(jsonBodyBase), jsonBodyBase),
        dataPageResult = Json.Document(Web.Contents(url,[
            Headers = [ #"Content-Type"="application/json"],
            Content = jsonBodyBase //Text.ToBinary(body) 
        ])),
        rawEntitiesRecords = dataPageResult[data],
        schemaConvertedRecords = TransformSchemaFields(schema, rawEntitiesRecords),
        entitiesRecords = if (alterRecord <> null) then alterRecord(schemaConvertedRecords) else schemaConvertedRecords,
        entitiesTable = if (List.Count(entitiesRecords) > 0) then Table.FromList(entitiesRecords, Splitter.SplitByNothing(), null, null, ExtraValues.Error) else EmptyTable,
        nextPageNumber = if (List.Count(entitiesRecords) = pageSizeNumber) then pagenumber + 1 else null

    in
        entitiesTable meta [NextPage = nextPageNumber];

Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

EmptyTable = #table({"Column1","Column2"}, {});

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
		// check for empty first table
		else if (Table.IsEmpty(firstRow[Column1])) then
			firstRow[Column1]
        else
            Value.ReplaceType(
                Table.ExpandTableColumn(tableOfPages, "Column1", Table.ColumnNames(firstRow[Column1])),
                Value.Type(firstRow[Column1])
            );

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




// [DataSource.Kind="inwink", Publish="inwink.Publish"]
// shared inwink.Contents = (optional eventId as text) as table =>
//     let
//             url = "https://api-event.inwink.com/" & eventId & "/person/query",
//             body = "{""selects"":{""$all"":true},""orders"":[{""desc"":true,""value"":{""validFrom"":{}}}],""page"":{""index"":0,""size"":60}}",
//             Source = Json.Document(Web.Contents(url,[
//                                    Headers = [
//                                 #"Content-Type"="application/json"],
//                      Content = Text.ToBinary(body) 
//                          ]
// 
//                     )),
//                     Record = Source[data],
//                    toTable = Table.FromList(Record, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
// 
//                    //Record.FieldNames(Table.Column(toTable, "Column1"){0}) => list des key dans le JSON, a remplacer par appel HTTP au template d'entité
//                    Result = Table.ExpandRecordColumn(toTable, "Column1", Record.FieldNames(Table.Column(toTable, "Column1"){0}))
// 
//     in
//         Result;