[Version = "3.0.0"]
section AssembleViews;

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


[DataSource.Kind="AssembleViews", Publish="AssembleViews.Publish"]
shared AssembleViews.Contents = Value.ReplaceType(NavigationTable.Nested, AssembleViewsType);


AssembleViewsType = type function (
        resourceUrl as (Uri.Type meta [
            Documentation.FieldCaption = "Assemble Url",
            Documentation.FieldDescription = "Assemble Insight Url",
            Documentation.SampleValues = {"https://demo.tryassemble.com"}
        ]),        
        optional viewAtDate as (type date meta [
            Documentation.FieldCaption = "View Date",
            Documentation.FieldDescription = "Point in time to retrieve view data. When null or not provided the latest view data is retrieved.",
            Documentation.SampleValues = {#date(2021,05,01)}
        ])
    )
    as table meta [
        Documentation.Name = "Assemble Views",
        Documentation.LongDescription = "Access views created within Assemble Insight"
    ];

// Create Metadata Nav table
NavigationTable.Nested = (resourceUrl as text, optional viewAtDate as nullable date) as table =>
    let 
        objects = GetProjectsNavTable(resourceUrl, viewAtDate, false),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

AssembleViews_Impl = (resourceUrl as text) =>
    let
        resourceUrl = Uri.Rebuild(resourceUrl),
        source = Web.Contents(resourceUrl),
        json = Json.Document(source)
    in
        json;

Web.Request = (resourceUrl as text) => AssembleViews_Impl(resourceUrl);

Web.Feed = (resourceUrl as text) => AssembleViews_Impl(resourceUrl);



GetProjects = (url as text) => 
    let
        ApiUrl = Uri.Combine(url, "/api/v1/powerbi/projects"),       
        source = Web.Feed(ApiUrl),
        #"Project List Converted to Table" = Table.FromList(source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Project List Expanded" = Table.ExpandRecordColumn(#"Project List Converted to Table", "Column1", 
            {"id", "name", "Description", "IsArchived", "ModelCount", "ViewCount", "LastActivityTime"}, 
            {"Id", "Project Name", "Description", "Is Archived", "Model Count", "View Count", "Last Activity Time"}),
        #"Project List Filtered Rows" = Table.SelectRows(#"Project List Expanded", each ([Is Archived] <> true)),
        #"Project List" = Table.TransformColumnTypes(#"Project List Filtered Rows",{{"Id", type text}})
    in
        #"Project List";


GetProjectViews = (url as text, projectId as text) => 
    let
        ApiUrl = Uri.Combine(url, "/api/v1/projects/" & projectId & "/views"),
        source = Web.Feed(ApiUrl),
        ViewsList = Table.FromList(source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        ViewsListExpanded = Table.ExpandRecordColumn(ViewsList, "Column1", {"id", "disciplineId", "projectId", "projectName", "name", "description", "isVisible", "isReadOnly", "isLegacy", "takeoffGroupingId", "grouping", "additionalColumns", "additionalFilters", "selectedModels", "visibilityRules", "thumbnailId", "thumbnailData", "sharingPolicy", "sharingSettings", "embedded", "isProjectApproved", "serializedViewState", "serializedColorization", "serializedViewpoints", "serialized2dViewpoints"}, {"id", "disciplineId", "projectId", "projectName", "name", "description", "isVisible", "isReadOnly", "isLegacy", "takeoffGroupingId", "grouping", "additionalColumns", "additionalFilters", "selectedModels", "visibilityRules", "thumbnailId", "thumbnailData", "sharingPolicy", "sharingSettings", "embedded", "isProjectApproved", "serializedViewState", "serializedColorization", "serializedViewpoints", "serialized2dViewpoints"})
    in
        ViewsListExpanded;


GetViewData = (url as text, viewId as text, viewAtDate as nullable date) => 
    let
        viewDateParam = if viewAtDate = null then "" else "?viewAtDate=" & Date.ToText(viewAtDate, "yyyy-MM-dd"),
        ApiUrl = Uri.Combine(url, "/api/v1/views/" & viewId & "/instances" & viewDateParam),
        source = Web.Feed(ApiUrl),
        Instances = source[instances],
        InstanceRecords = Table.FromList(Instances, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        InstanceRows = Table.RenameColumns(InstanceRecords, {{"Column1", "Rows"}})
    in
        InstanceRows;



GetProjectsNavTable = (resourceUrl as text, viewAtDate as nullable date, fullSizeImages as nullable logical) as table =>
    let 
        source = GetProjects(resourceUrl),
        projects = Table.SelectColumns(source, {"Project Name", "Id", "View Count"}),
        projectsRenameColumns = Table.RenameColumns(projects, {{"Project Name", "Name"}, {"Id", "Key"}}),       
        projectsAddData = Table.AddColumn(projectsRenameColumns, "Data", each try GetViewsNavTable(resourceUrl, [Key], [Name], viewAtDate, fullSizeImages) otherwise null),
        projectsAddItemKind = Table.AddColumn(projectsAddData, "ItemKind", each "Folder"),
        projectsAddItemName = Table.AddColumn(projectsAddItemKind, "ItemName", each "Folder"),
        projectsAddIsLeaf = Table.AddColumn(projectsAddItemName, "IsLeaf", each false)
    in
        projectsAddIsLeaf;


GetViewsNavTable = (resourceUrl as text, projectId as text, projectName as text, viewAtDate as nullable date, fullSizeImages as nullable logical) as table =>
    let 
        source = GetProjectViews(resourceUrl, projectId),
        views = Table.SelectColumns(source, {"name", "id"}),
        ViewsWithThumbnailId = Table.SelectColumns(source, {"name", "id", "thumbnailId"}, MissingField.Ignore),
        viewsWithThumbnails = Table.AddColumn(ViewsWithThumbnailId, "Image", each try GetViewThumbnail(resourceUrl, [thumbnailId], fullSizeImages) otherwise null),
        RenameColumns = Table.RenameColumns(views, {{"name", "Name"}, {"id", "Key"}}),       
        AddDataColumn = Table.AddColumn(RenameColumns, "Data", each try GetViewData(resourceUrl, Number.ToText([Key]), viewAtDate) otherwise null),
        AddItemKindColumn = Table.AddColumn(AddDataColumn, "ItemKind", each "View"),
        AddItemNameColumn = Table.AddColumn(AddItemKindColumn, "ItemName", each "View"),
        AddIsLeafColumn = Table.AddColumn(AddItemNameColumn, "IsLeaf", each true),
        AddViewThumbnailsFolder = Table.InsertRows(AddIsLeafColumn, 1, {[Name = projectName & " View Thumbnails", Key = projectId & "_thumbnails", Data = viewsWithThumbnails, ItemKind = "Table", ItemName = "Table", IsLeaf = true]}),
        NavTable = Table.ToNavigationTable(if AddViewThumbnailsFolder = null then AddIsLeafColumn else AddViewThumbnailsFolder, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;


GetViewThumbnail = (url as text, thumbnailId as text, fullSizeImages as nullable logical) => 
    let          
        asFullSize = if fullSizeImages = null or fullSizeImages = false then false else true,
        fullSizeParam = "?fullsize=" & Logical.ToText(asFullSize),
        ApiUrl = Uri.Combine(url, "/api/v1/attachments/" & thumbnailId & fullSizeParam),
        source = Web.Contents(ApiUrl),
        binaryImg = if asFullSize = true then SplitLargeBinaryImage(source) else BinaryToPbiImage(source)
    in
        binaryImg;


BinaryToPbiImage = (BinaryContent as binary) as text =>
    let
        Base64 = "data:image/jpeg;base64, " & Binary.ToText(BinaryContent, BinaryEncoding.Base64)
    in
        Base64;

SplitLargeBinaryImage = (imageTable as table) as table =>
    let
        RemoveOtherColumns = Table.SelectColumns(imageTable,{"Image", "name"}),
        SplitTextFunction = Splitter.SplitTextByRepeatedLengths(30000),
        //Converts table of files to list
        ListInput = Table.ToRows(RemoveOtherColumns),
        //Function to convert binary of photo to multiple
        //text values
        ConvertOneFile = (InputRow as list) =>
            let
                BinaryIn = InputRow{0},
                FileName = InputRow{1},
                BinaryText = Binary.ToText(BinaryIn, BinaryEncoding.Base64),
                SplitUpText = SplitTextFunction(BinaryText),
                AddFileName = List.Transform(SplitUpText, each {FileName,_})
            in
                AddFileName,
        //Loops over all photos and calls the above function
        ConvertAllFiles = List.Transform(ListInput, each ConvertOneFile(_)),
        //Combines lists together
        CombineLists = List.Combine(ConvertAllFiles),
        //Converts results to table
        ToTable = #table(type table[name=text,Image=text],CombineLists),
        //Adds index column to output table
        AddIndexColumn = Table.AddIndexColumn(ToTable, "Index", 0, 1)
    in
        AddIndexColumn;


// Data Source Kind description
AssembleViews = [
    TestConnection = (dataSourcePath) => {"AssembleViews.Contents", dataSourcePath},
    Authentication = [
        OAuth = [
            StartLogin=StartLogin,
            FinishLogin=FinishLogin,
            Refresh=Refresh
        ]
    ],
    Label = "Assemble Views"
];

redirect_uri = Extension.LoadString("redirect_uri");

// Helper functions for OAuth2: StartLogin, FinishLogin, Refresh, Logout
StartLogin = (resourceUrl, state, display) =>
    let       
        base_url = GetDiscoveryDocument(resourceUrl)[authorization_endpoint],
        tenant = Text.From(GetTenantParameter(resourceUrl)),
        authorizeUrl = base_url & "?" & Uri.BuildQueryString([
            response_type = "code",
            client_id = GetEnvironmentVariable(resourceUrl, "client_id"),  
            redirect_uri = redirect_uri,
            state = state,
            scope = "core_api.all tenant openid offline_access",
            acr_values = tenant, //"idp:forge" add this to the beginning of the string with a space to force oxygen only authorization
            is_remote = "true"
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = 520,
            WindowWidth = 724,
            Context = resourceUrl
        ];


FinishLogin = (context, callbackUri, state) =>
    let
        // parse the full callbackUri, and extract the Query string
        parts = Uri.Parts(callbackUri)[Query],
        // if the query string contains an "error" field, raise an error
        // otherwise call TokenMethod to exchange our code for an access_token
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)

                 else if (Record.HasFields(parts, {"error"})) then 
                    if (parts[error] = "access_denied") then
                        error Error.Record("Access Denied", "This account does not have access to " & context & ".")
                    else 
                        error Error.Record(parts[error], "Failed to login to " & context & ".")
                            
                 else if (Record.HasFields(parts, {"code"})) then
                    TokenMethod(context, "authorization_code", "code", parts[code])

                 else
                    error Error.Record(Text.Combine(Table.ToList(Record.ToTable(parts), Combiner.CombineTextByDelimiter(", "))))
    in
        result;

Refresh = (resourceUrl, refresh_token) => TokenMethod(resourceUrl, "refresh_token", "refresh_token", refresh_token);


TokenMethod = (resourceUrl, grantType, tokenField, code) =>
    let
        queryString = [
            grant_type = grantType,
            redirect_uri = redirect_uri,
            client_id = GetEnvironmentVariable(resourceUrl, "client_id"),
            client_secret = GetEnvironmentVariable(resourceUrl, "client_secret")
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),

        base_url = GetDiscoveryDocument(resourceUrl)[token_endpoint],
        tokenResponse = Web.Contents(base_url, [
            Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = {400} 
        ]),
        body = Json.Document(tokenResponse),
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body)

                 else if (Record.HasFields(body, {"error"})) then 
                    error Error.Record(body[error], "Failed to login.", body)
                 
                 else
                    body
    in
        result;


// Data Source UI publishing description
AssembleViews.Publish = [
    Beta = true,
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = Extension.LoadString("LearnMoreUrl"),
    SourceImage = AssembleViews.Icons,
    SourceTypeImage = AssembleViews.Icons
];

AssembleViews.Icons = [
    Icon16 = { Extension.Contents("AssembleViews16.png"), Extension.Contents("AssembleViews20.png"), Extension.Contents("AssembleViews24.png"), Extension.Contents("AssembleViews32.png") },
    Icon32 = { Extension.Contents("AssembleViews32.png"), Extension.Contents("AssembleViews40.png"), Extension.Contents("AssembleViews48.png"), Extension.Contents("AssembleViews64.png") }
];


GetEnvironmentVariable = (resourceUrl as text, resourceKey as text) =>
    let
        env = GetEnvironment(resourceUrl),
        env_variable_key = if env = "prod" then resourceKey else resourceKey & "_" & env,
        value = Extension.LoadString(env_variable_key)
    in
        value as text;

GetAuthUrl = (resourceUrl as text) =>
    let
        auth_uri = Web.Request(Uri.Combine(resourceUrl, "/api/v1/authority"))
    in
        auth_uri as text;

GetDiscoveryDocument = (resourceUrl as text) =>
    let
        auth_url = GetAuthUrl(resourceUrl),
        disco_doc = Web.Request(Uri.Combine(auth_url, "/.well-known/openid-configuration"))
    in
        disco_doc;

GetEnvironment = (resourceUrl as text) =>
    let
        auth_url = GetAuthUrl(resourceUrl),
        env = if 
                Text.Contains(Text.Lower(auth_url), ".au.tryassemble") then "au" 
            else if 
                Text.Contains(Text.Lower(auth_url), "tryassemble") then "prod" 
            else if 
                (Text.Contains(Text.Lower(auth_url), "staging") and Text.Contains(Text.Lower(resourceUrl), "internalassemble")) 
                or (Text.Contains(Text.Lower(auth_url), "stg") and Text.Contains(Text.Lower(resourceUrl), "internalassemble")) 
                or Text.Contains(Text.Lower(resourceUrl), "staging.internalassemble.com") then "stg" 
            else 
                "dev"
    in
        env;

GetTenantParameter = (resourceUrl as text) =>  
    let
        TenantParameter = Text.Combine({"tenant", GetHost(resourceUrl)}, ":") 
    in
        TenantParameter as text;

GetHost = (resourceUrl as text) =>
    let
        host = Uri.Parts(resourceUrl)[Host]
    in
        host as text;

Uri.Rebuild = (resourceUrl as text) =>
    let
        parts = Uri.Parts(resourceUrl),
        queryDiv = if Record.FieldCount(parts[Query]) > 0 then "?" else "",
        uri = Text.Combine({"https", "://", parts[Host], parts[Path], queryDiv, Uri.BuildQueryString(parts[Query])})
    in
        uri;
