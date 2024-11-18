[Version = "2.0.0"]
section Profisee;

[DataSource.Kind="Profisee", Publish="Profisee.Publish"]
shared Profisee.Tables = Value.ReplaceType(ProfiseeFeedImpl, ProfiseeImplType); 

ProfiseeImplType  = type function (url as (Uri.Type meta [
        Documentation.FieldCaption = Extension.LoadString("ProfiseeInstanceURLFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("ProfiseeInstanceURLFieldDescription"),
        Documentation.SampleValues = {Extension.LoadString("ProfiseeInstanceURLFieldExample")}
    ]))
    as table meta [
        Documentation.Name = Extension.LoadString("TableName"),
        Documentation.LongDescription = Extension.LoadString("TableDescription"),
        Documentation.Examples = {[
            Description = Extension.LoadString("Table_Example_Description"),
            Code = "Profisee.Tables(""https://12345.com/profisee"")",
            Result = "#table({""Name"", ""Data"", ""ItemKind"", ""ItemName""}, {{""ABCCode"", ""Table"", ""Table"", ""Table""}})"
        ]}
    ];

ProfiseeFeedImpl = (url as text) as table =>
    let
       baseURL = GetBaseURL(url),
       entityNames = GetEntitiesTable(baseURL)
    in
      entityNames;

GetBaseURL = (url as text) => 
    let      
       validUrl = ValidateUrlScheme(url),
       baseURL =  if Text.EndsWith(validUrl, "/") then validUrl else validUrl & "/",
       restURL = baseURL & "rest/v1/"
    in
       restURL;

GetRawResponse = (url as text) => 
    let   
       raw = Json.Document(Web.Contents(url,  [ManualStatusHandling={400}])),     
       output = if Record.HasFields(raw, "errors") and raw[errors]<>null and List.Count(Record.FieldValues(raw[errors])) > 0 then error Error.Record(raw[title], "", List.First(List.First(Record.FieldValues(raw[errors])))) else raw
    in
        output;

GetRawDQResponse = (url as text) =>
    let
        errors.resourceNotFound = Record.AddField(Error.Record("Profisee 2024.R1 or later is required to use this data set.", ""), "Status", 404),
        errors.table = Table.FromRecords({errors.resourceNotFound}),
        webContent = Web.Contents(url, [ManualStatusHandling={400, 401, 404}]),
        responseMetadata = Value.Metadata(webContent),
        responseCode = responseMetadata[Response.Status],
        responseHeaders = responseMetadata[Headers],
        raw = Json.Document(webContent),
        output = if responseCode = 404 then error errors.table{List.PositionOf(errors.table[Status], responseCode)} else if Record.HasFields(raw, "errors") and raw[errors]<>null and List.Count(Record.FieldValues(raw[errors])) > 0 then error Error.Record(raw[title], "", List.First(List.First(Record.FieldValues(raw[errors])))) else raw
    in output;

GetEntitiesTable = (baseURL) =>
    let 
       entityURL = baseURL & "entities",
       raw = GetRawResponse(baseURL & "entities"),
       entityNames = List.Transform(raw[data], each [identifier][name]),       
       entitiesSchema = GetEntitiesSchemaTable(baseURL & "attributes", entityNames),
       entityNameRecords = List.Transform(entityNames,  each [Name = _, Data = GetAllPagesByNextLink(baseURL & "records/" & _ & "?pageSize=1000", entitiesSchema{[Entity = _]}[SchemaTable]), ItemKind = "Table", ItemName = "Table", IsLeaf = true ]),
       entityNamesTable = Table.FromList(entityNameRecords, Record.FieldValues, {"Name", "Data", "ItemKind", "ItemName", "IsLeaf"}),
       navigationTable = Table.ToNavigationTable(entityNamesTable & GetEntitiesDQTable(baseURL, entityNames) & GetDataQualitiesTable(baseURL), {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navigationTable;

GetEntitiesDQTable = (baseURL, entityNames as list) => 
    let 
       columnNames = {"issueId", "recordUid", "ruleClauseId", "recordCode", "fieldId", "issueDescription", "ruleId", "isConstraint"},
       renamedEntityNames = List.Transform(entityNames, each {_ , Text.Proper(_)}), 
       renamedColumns = List.Transform(columnNames, each {_, Text.Proper(_)}),
       entityDqEntity = List.Transform(entityNames, each [Entity = _ , Name = (_ & " Validation Issues")]),
       entityNameDQRecords = List.Transform(entityDqEntity,  each [Name = _[Name], Data = GetAllDQPagesByNextLink((baseURL & "DataQualityIssues/" & _[Entity] & "?pageSize=1000")), ItemKind = "Table", ItemName = "Table", IsLeaf = true ]),
       entityNameDQTable = Table.FromList(entityNameDQRecords, Record.FieldValues, {"Name", "Data", "ItemKind", "ItemName", "IsLeaf"}),
       navigationTable = Table.ToNavigationTable(entityNameDQTable, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navigationTable;

GetDataQualitiesTable = (baseURL) => 
    let 
       entityURL = baseURL & "dataQualityRules",
       response = GetRawResponse(baseURL & "dataQualityRules"),
       dataList = response[data],
       notClauseIds = List.Select(Record.FieldNames((dataList){0}), each _ <> "clauses"),
       clauseInternalIds = List.Select(Record.FieldNames((dataList){0}), each _ = "clauses"), 
       dataTable = Table.FromRecords(dataList,  clauseInternalIds & notClauseIds), 
       renamedColumns = List.Transform(clauseInternalIds & notClauseIds , each {_ , Text.Proper(_)}), 
       dataTableWithTitleCaseColumnNames = Table.RenameColumns(dataTable, renamedColumns),    
       dataQualityRecords = List.Transform({"Profisee_DataQualityRules"},  each [Name = "Profisee_DataQualityRules", Data = dataTableWithTitleCaseColumnNames, ItemKind = "Table", ItemName = "Table", IsLeaf = true ]),
       dataQualityTable = Table.FromList(dataQualityRecords, Record.FieldValues, {"Name", "Data", "ItemKind", "ItemName", "IsLeaf"}),
       navigationTable = Table.ToNavigationTable(dataQualityTable, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navigationTable;

GetEntitiesSchemaTable = (attributesURL, entityNames) => 
    let
        raw = GetRawResponse(attributesURL),
        attributeList = raw[data],
        entitiesSchema = List.Transform(entityNames, each [Entity = _, SchemaTable = GetEntitySchema(_ , attributeList)]),
        entitiesSchemaTable = Table.FromList(entitiesSchema, Record.FieldValues, {"Entity","SchemaTable"})
    in
        entitiesSchemaTable;

GetEntitySchema = (entityName as text, allAttributes as list) => 
    let
        entityAttributes = List.Transform(List.Select(allAttributes, each _[identifier][entityId][name] = entityName), each [Name = Text.Proper([identifier][name]) ,Type =  GetPowerBIDataTypeFromProfisee([dataType], [dataTypeInformation], [isCode])]),
        additionalAttributes = { [Name = "Validationissueclauseids", Type = Record.Type], [Name = "Validationstatusid", Type = Int64.Type], [Name = "Enterdtm", Type = DateTime.Type], [Name = "Enterusername", Type = type text], [Name = "Lastchgdtm", Type = DateTime.Type], [Name = "Lastchgusername", Type =  type text]},
        entityAttributesWithAdditionalColumns = List.Combine({entityAttributes, additionalAttributes}),
        entityAttributesSchemaTable = Table.FromList(entityAttributesWithAdditionalColumns,  Record.FieldValues, {"Name", "Type"})
    in
        entityAttributesSchemaTable;

GetPowerBIDataTypeFromProfisee = (profiseeDataType as number, dataTypeInformation as nullable number, isCode as nullable logical) => 
    let 
        dataTypeInformation = if dataTypeInformation = null then 0 else dataTypeInformation,
        powerBIDataType = if profiseeDataType = 1 then type nullable Text.Type
                          else if profiseeDataType = 2 then if dataTypeInformation = 0 then type nullable Int64.Type else type nullable Decimal.Type 
                          else if profiseeDataType = 3 then type nullable DateTime.Type 
                          else if profiseeDataType = 4 then type nullable Date.Type 
                          else type nullable Text.Type,
        output = if isCode then Type.NonNullable(powerBIDataType) else powerBIDataType
    in
        output;

// Read all pages of data.
// After every page, we check the "NextLink" record on the metadata of the previous request.
// Table.GenerateByPage will keep asking for more pages until we return null.
GetAllPagesByNextLink = (url as text, entitySchemaTable) as table =>
    Table.GenerateByPage((previous) => 
        let
            // if previous is null, then this is our first page of data
            nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
            // if NextLink was set to null by the previous call, we know we have no more data
            page = if (nextLink <> null) then GetPage(nextLink, entitySchemaTable) else null
        in
            page
    );
    
 GetAllDQPagesByNextLink = (url as text) as table =>
    Table.GenerateByPage((previous) =>
        let
            nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
            page = if (nextLink <> null) then GetDQPage(nextLink) else null
        in
            page
    );

GetPage = (url as text, entitySchemaTable) as table => 
    let
        response = GetRawResponse(url),        
        nextLink = GetNextLink(response),        
        dataList = response[data],
        newDataList = List.Transform(dataList, (item) => if Record.HasFields(item, "validationIssueClauseIds") then item else Record.AddField(item, "validationIssueClauseIds", null)),
        columnNames = List.Select(Record.FieldNames((newDataList){0}), each _ <> "validationIssueClauseIds"),
        dataQualityColumnName = List.Select(Record.FieldNames((newDataList){0}), each _ = "validationIssueClauseIds"),
        dataTable = Table.FromRecords(newDataList,  columnNames & dataQualityColumnName), 
        renamedColumns = List.Transform(columnNames & dataQualityColumnName, each {_ , Text.Proper(_)}), 
        dataTableWithTitleCaseColumnNames = Table.RenameColumns(dataTable, renamedColumns),
        transformedDataTableWithColumnTypes =  SchemaTransformTable(dataTableWithTitleCaseColumnNames , entitySchemaTable),
        resultTable = transformedDataTableWithColumnTypes    
    in
        resultTable meta[NextLink = nextLink];

 GetDQPage = (url as text) as table =>
    let
        response = GetRawDQResponse(url),
        nextLink = GetNextLink(response),
        dataListDQ = response[data],
        columnNamesDQ = {"issueId", "recordUid", "ruleClauseId", "recordCode", "fieldId", "issueDescription", "ruleId", "isConstraint"},
        dataTableDQ = Table.FromRecords(dataListDQ, columnNamesDQ),
        renamedColumnsDQ = List.Transform(columnNamesDQ, each {_ , Text.Proper(_)}),
        dataTableDQWithTitleCaseColumnNames = Table.RenameColumns(dataTableDQ, renamedColumnsDQ),
        resultTableDQ =  dataTableDQWithTitleCaseColumnNames 
    in
        resultTableDQ meta[NextLink = nextLink]; 

// In this implementation, 'response' will be the parsed body of the response after the call to Json.Document.
// Look for the '@odata.nextLink' field and simply return null if it doesn't exist.
GetNextLink = (response) as nullable text => Record.FieldOrDefault(response, "nextPage");

StartLogin = (resourceUrl, state, display) =>
        let 
           validUrl = ValidateUrlScheme(resourceUrl),
            AuthorizeUrl = Text.Format("#{0}/auth/connect/authorize?",{validUrl}) & Uri.BuildQueryString([
                client_id = "PowerBI.Hybrid",
                scope = "ProfiseeAPI offline_access",
                redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html",
                response_type = "code",                
                state = state,
                showProviderSelector = "true"
               ])

        in
            [
                LoginUri = AuthorizeUrl,
                CallbackUri = "https://oauth.powerbi.com/views/oauthredirect.html",
                WindowHeight = 1000,
                WindowWidth = 1200,
                Context = null
            ];

FinishLogin = (clientApplication, dataSourcePath, context, callbackUri, state) =>
    let
        response = Uri.Parts(callbackUri)[Query]
    in
       GetTokenFromCode(dataSourcePath, response[code]);

Refresh = (dataSourcePath, refreshToken) => 
       let
        Response = Web.Contents(Text.Format("#{0}/auth/connect/token?",{dataSourcePath}), [
            Content = Text.ToBinary(Uri.BuildQueryString([
                client_id = "PowerBI.Hybrid",
                refresh_token = refreshToken,
                scope = "ProfiseeAPI",
                grant_type = "refresh_token",
                redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html"])),
            Headers=[#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json"]]),
        Parts = Json.Document(Response)
    in
        Parts;

GetTokenFromCode = (dataSourcePath, code) =>
     let
        Response = Web.Contents(Text.Format("#{0}/auth/connect/token?",{dataSourcePath}), [
            Content = Text.ToBinary(Uri.BuildQueryString([
                client_id = "PowerBI.Hybrid",
                code = code,
                scope = "ProfiseeAPI",
                grant_type = "authorization_code",
                redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html"])),
            Headers=[#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json"]]),
        Parts = Json.Document(Response)
    in
        Parts;

Logout = (clientApplication, dataSourcePath, accessToken) => Text.Format("#{0}/auth/connect/endsession",{dataSourcePath});
         
// Data Source Kind description
Profisee = [
    TestConnection = (dataSourcePath) => {"Profisee.Tables", dataSourcePath},
    Authentication = [
        OAuth = [
        StartLogin = StartLogin,
        FinishLogin = FinishLogin,
        Refresh = Refresh,
        Logout = Logout
    ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
Profisee.Publish = [
    Beta = false,
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://profisee.com/blog/profisee-power-bi-better-together/",
    SourceImage = Profisee.Icons,
    SourceTypeImage = Profisee.Icons
];

Profisee.Icons = [
    Icon16 = { Extension.Contents("Profisee16.png"), Extension.Contents("Profisee20.png"), Extension.Contents("Profisee24.png"), Extension.Contents("Profisee32.png") },
    Icon32 = { Extension.Contents("Profisee32.png"), Extension.Contents("Profisee40.png"), Extension.Contents("Profisee48.png"), Extension.Contents("Profisee64.png") }
];

ValidateUrlScheme = (url as text) as text => if (Uri.Parts(url)[Scheme] <> "https") then error "Url scheme must be HTTPS" else url;

Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");
Table.GenerateByPage =  Extension.LoadFunction("Table.GenerateByPage.pqm");
SchemaTransformTable = Extension.LoadFunction("SchemaTransformTable.pqm");
