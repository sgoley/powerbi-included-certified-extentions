[Version = "1.0.0"]
section Wrike;

//
// Constants used for Authentication
// Client ID and Secret is obtained from Wrike App Registration process
// For more details: https://developers.wrike.com/oauth-20-authorization/ 
//
client_id =  "aRsUEVFT";//Extension.LoadString("client_id");
client_secret = "iGmE1044EoHT34Luqkm6rB46PZbuetTjtzvhYFmxyTNvTljkhNDDrerbLg42NY4d";//Extension.LoadString("client_secret");
//delay_task_apicalls = Extension.LoadString("delay_taskcalls"); ---- To be used in case we include the delay in task api calls
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
base_oauth_uri = "https://login.wrike.com/oauth2";
learn_more_uri = "https://developers.wrike.com/overview/";
hostPath_uri = base_oauth_uri & "/host";
auth_uri = base_oauth_uri & "/authorize/v4?";
token_uri = base_oauth_uri & "/token";


windowWidth = 800;
windowHeight = 600;

//
// Shared function and first entry point to Connector. 
// This function will provide 'Formatted' table of Wrike APIs 
//
[DataSource.Kind="Wrike", Publish="Wrike.Publish"]
shared Wrike.Contents = Value.ReplaceType(Contents, ContentsType);
ContentsType = type function ()
    as table meta [
        Documentation.Name = "Wrike",
        Documentation.LongDescription = " Shared function and first entry point to Connector. Display initial Navigation hierarchy.",
        Documentation.Examples = {}
    ];
Contents = () =>
    let
        objects = #table(
            {"Name", "Data", "ItemKind", "ItemName", "IsLeaf"},{
            {"Account", GetGlobalData(), "Folder", "Folder", false },
            {"Spaces", GetSpaceData(true), "Folder", "Folder", false },
            {"Shared with me", GetSpaceData(false), "Folder", "Folder", false }
            }),
        NavTable = Table.ToNavigationTable(objects, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

//
// Shared function is generic function to fetch data. 
// This function will provide 'Raw' table of Wrike APIs 
//
[DataSource.Kind="Wrike"]
Wrike.GetRawContent = Value.ReplaceType(GetRawContent, GetRawContentType);
GetRawContentType = type function (
    optional url as (type text meta [
        Documentation.FieldCaption = "Url",
        Documentation.FieldDescription = "Wrike API V4 GET Url",
        Documentation.SampleValues = {"https://www.wrike.com/api/v4/folders"}
    ]))
    as table meta [
        Documentation.Name = "Result",
        Documentation.LongDescription = "Perform direct REST Api call to Wrike instance and present current account data in tabular form. Refer https://developers.wrike.com/ for more information.",
        Documentation.Examples = {}
    ];

[DataSource.Kind="Wrike"]
Wrike.GetFolderDetails = Value.ReplaceType(GetFolderDetails, GetFolderDetailsType); 
GetFolderDetailsType = type function (
    optional folderid as (type text meta [
        Documentation.FieldCaption = "Folder ID",
        Documentation.FieldDescription = "Provide Project or Folder ID from current account's Wrike Instance to pull folder details.",
        Documentation.SampleValues = {"IEAEWPKBI4XZXOXQ"}
    ]))
    as table meta [
        Documentation.Name = "Folder Details",
        Documentation.LongDescription = "Perform REST Api call (/folders/[id]) to get expanded Project/folder Details. Refer https://developers.wrike.com/ for more information.",
        Documentation.Examples = {}
    ];
GetFolderDetails = (optional folderid as text  ) => GetAPIData("folderdetails", folderid);

[DataSource.Kind="Wrike"]
Wrike.GetFolderFinanceData = Value.ReplaceType(GetFolderFinanceData, GetFolderFinanceDetailsType); 
GetFolderFinanceDetailsType = type function (
    optional folderid as (type text meta [
        Documentation.FieldCaption = "Folder ID",
        Documentation.FieldDescription = "Provide Project or Folder ID from current account's Wrike Instance to pull folder finance information.",
        Documentation.SampleValues = {"IEAEWPKBI4XZXOXQ"}
    ]))
    as table meta [
        Documentation.Name = "Folder Details",
        Documentation.LongDescription = "Perform REST Api call (/folders/[id]?fields=[finance]) to get expanded Project/folder finace data. Refer https://developers.wrike.com/ for more information.",
        Documentation.Examples = {}
    ];
GetFolderFinanceData = (optional folderid as text  ) => GetAPIData("folderdetailswithfinance", folderid);

[DataSource.Kind="Wrike"]
Wrike.GetTaskDetails = Value.ReplaceType(GetTaskDetails, GetTaskDetailsType); 
GetTaskDetailsType = type function (
    optional taskId as (type text meta [
        Documentation.FieldCaption = "Task ID",
        Documentation.FieldDescription = "Provide Task ID from current account's Wrike Instance to pull task details.",
        Documentation.SampleValues = {"IEAEWPKBKQXZXOZK"}
    ]))
    as table meta [
        Documentation.Name = "Task Details",
        Documentation.LongDescription = "Perform REST Api call (/tasks/[id]) to get expanded task Details. Refer https://developers.wrike.com/ for more information.",
        Documentation.Examples = {}
    ];
GetTaskDetails = (optional taskId as text ) => Function.InvokeAfter(() => GetAPIData("taskdetails", taskId),#duration(0,0,0,0));


[DataSource.Kind="Wrike"]
Wrike.GetTaskDependencies = Value.ReplaceType(GetTaskDependencies, GetTaskDependenciesType); 
GetTaskDependenciesType = type function (
    optional taskId as (type text meta [
        Documentation.FieldCaption = "Task ID",
        Documentation.FieldDescription = "Provide Task ID from current account's Wrike Instance to pull task Dependencies.",
        Documentation.SampleValues = {"IEAEWPKBKQXZXOZK"}
    ]))
    as table meta [
        Documentation.Name = "Task Dependencies",
        Documentation.LongDescription = "Perform REST Api call (/tasks/[id]/dependencies) to get expanded task dependencies. Refer https://developers.wrike.com/ for more information.",
        Documentation.Examples = {}
    ];
GetTaskDependencies = (optional taskId as text ) => GetAPIData("taskdependencies", taskId);

[DataSource.Kind="Wrike"]
Wrike.GetSpaceDetailsById = Value.ReplaceType(GetSpaceDetailsById, GetSpaceDetailsByIdType); 
GetSpaceDetailsByIdType = type function (
    optional spaceId as (type text meta [
        Documentation.FieldCaption = "Space ID",
        Documentation.FieldDescription = "Provide Space ID from current account's Wrike Instance to pull Space details.",
        Documentation.SampleValues = {"IEAEWPKBKQXZXOZK"}
    ]))
    as table meta [
        Documentation.Name = "Space Details",
        Documentation.LongDescription = "Perform REST Api call (/spaces/[id]) to get expanded space details. Refer https://developers.wrike.com/ for more information.",
        Documentation.Examples = {}
    ];
GetSpaceDetailsById = (optional spaceId as text ) => GetAPIData("spacesbyid", spaceId);

//
// Function to get Raw content from API
//
GetRawContent = (optional url as text) => 
    let
        content = Web.Contents(url),
        json = Json.Document(content),
        toTable = Table.FromList(json[data], Splitter.SplitByNothing(), null, null, ExtraValues.List)
    in
        toTable;

//
// Function to retrieve Wrike `Spaces` in Navigator
//
GetSpaceData = (loadWithSpaceTrue as logical) => 
    let
       data = GetAPIData("spaces"),
       #"Filtered Rows" = Table.SelectRows(data, each ([space] = loadWithSpaceTrue)),
       nav = CreateNavTable(#"Filtered Rows")
    in
        nav;
       
//
// Function to retrieve Wrike `Global` APIs data in Navigator
//
GetGlobalData = () => 
     let
     customFieldsExpanded = GetAPIData("customfieldsexpand"),
     customFields = GetAPIData("customfields"),
     selectedCaseAtllTasks = GetSelectedAPICall("alltasks"),

    // globalCustomFields = Table.SelectRows(customFields, each ([spaceId] = null)),
    // globalCustomFieldsExpanded = Table.SelectRows(customFieldsExpanded, each ([spaceId] = null)),

     objects = #table(
            { "Name", "Data", "ItemKind", "ItemName", "IsLeaf" },{
            { "Account Detail", GetAPIData("account"), "Table", "Table", true },
            { "Groups", GetAPIData("groups"), "Table", "Table", true },
            { "Spaces", GetAPIData("spacesexpand"), "Table", "Table", true },
            { "Timelogs", GetAPIData("timelogs"), "Table", "Table", true },
            { "Timelog categories", GetAPIData("timelogcategories"), "Table", "Table", true },
            { "Workflows", GetAPIData("workflows"), "Table", "Table", true },
            { "Contacts", GetAPIData("contacts"), "Table", "Table", true },
            { "Access Roles", GetAPIData("accessroles"), "Table", "Table", true },
            { "Invitations", GetAPIData("invitations"), "Table", "Table", true },
            { "Custom Item Types", GetAPIData("customitemtypes"), "Table", "Table", true },
            { "Contacts with Finance data", GetAPIData("contactswithfinance"), "Table", "Table", true },
            { "Job Roles", GetAPIData("jobroles"), "Table", "Table", true },
            { "Place Holders", GetAPIData("placeholders"), "Table", "Table", true },
            { "Bookings", GetAPIData("bookings"), "Table", "Table", true },
            { "All Folders/Projects", GetAPIData("allfolders"), "Table", "Table", true },
            { "All Folders/Projects Custom Field Values", GetAllFoldersWithCustomFields(), "Table", "Table", true },
            { "All Folders/Projects  Finance Data", GetAllFoldersWithFinanceData(), "Table", "Table", true },
            { "Custom Fields",customFields, "Table", "Table", true },
            { "Custom Fields Expanded",customFieldsExpanded, "Table", "Table", true },
            { "All Tasks", Wrike.GetAllPagesByNextLink("alltasks", selectedCaseAtllTasks{0}), "Table", "Table", true },
            { "Attachments",GetAPIData("allattachments"), "Table", "Table", true },
            { "Work Schedules",GetAPIData("workschedules"), "Table", "Table", true },
            { "Approvals",Wrike.GetAllPagesByNextLink("allapprovals", GetSelectedAPICall("allapprovals"){0}), "Table", "Table", true }
        }),
     tb = Table.ToNavigationTable(objects, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
   in
    tb;

//
// Create First Level Navigator folder structure - Global, Spaces
//
CreateNavTable = (base as table) as table =>
    let
          objects = #table(
            { "Name", "Data", "ItemKind", "ItemName", "IsLeaf" }),
        baseTable =  AddBaseColumns(base,"Folder",false),
        withData = Table.AddColumn(baseTable, "Data", each CreateMultiLvlFolder([title], [id], [childIds], true), type table),  
        NavTable = Table.ToNavigationTable(withData, {"title"}, "title", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

CreateMultiLvlFolder = (folderTitle as text, folderId as text,ids as list, isSpace as logical) as table => 
    let

       // customFields = GetAPIData("customfields"),
       // customFieldsExpanded = GetAPIData("customfieldsexpand"),
       // customFieldsInSpace = Table.SelectRows(customFields, each ([spaceId] = null or [spaceId] = folderId)),
       // customFieldsExpandedInSpace = Table.SelectRows(customFieldsExpanded, each ([spaceId] = null or [spaceId] = folderId)),
        tbl = Table.FromList(ids, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
     
        addCustom = if(Table.IsEmpty(tbl)) then tbl else Table.AddColumn(tbl, "Custom", each Wrike.GetFolderDetails([Column1])),
        expandCustom =if(Table.IsEmpty(tbl)) then tbl else Table.ExpandTableColumn(addCustom, "Custom", {"id", "accountId", "title", "createdDate", "updatedDate", "description", "sharedIds", "parentIds", "childIds", "superParentIds", "scope", "hasAttachments", "permalink", "workflowId", "metadata", "customFields","inheritedCustomColumnIds"}, {"Custom.id", "Custom.accountId", "Custom.title", "Custom.createdDate", "Custom.updatedDate", "Custom.description", "Custom.sharedIds", "Custom.parentIds", "Custom.childIds", "Custom.superParentIds", "Custom.scope", "Custom.hasAttachments", "Custom.permalink", "Custom.workflowId", "Custom.metadata", "Custom.customFields","Custom.inheritedCustomColumnIds"}),
        rmvColumn =if(Table.IsEmpty(tbl)) then tbl else Table.RemoveColumns(expandCustom,{"Custom.id", "Custom.accountId", "Custom.createdDate", "Custom.updatedDate", "Custom.description", "Custom.sharedIds", "Custom.parentIds", "Custom.superParentIds", "Custom.scope", "Custom.hasAttachments", "Custom.permalink", "Custom.workflowId", "Custom.metadata", "Custom.customFields","Custom.inheritedCustomColumnIds"}),
        renameColumn =if(Table.IsEmpty(tbl)) then tbl else Table.RenameColumns(rmvColumn,{{"Column1", "id"}, {"Custom.title", "title"}, {"Custom.childIds", "childIds"}}),
        newCol =if(Table.IsEmpty(tbl)) then tbl else Table.AddColumn(renameColumn , "Count",each List.Count([childIds]), type table),

        withItemKind = if(Table.IsEmpty(tbl)) then tbl else Table.AddColumn(newCol, "ItemKind", each "Folder" , type text),
        withItemName = if(Table.IsEmpty(tbl)) then tbl else  Table.AddColumn(withItemKind, "ItemName",  each  "Folder", type text),
        withIsLeaf = if(Table.IsEmpty(tbl)) then tbl else Table.AddColumn(withItemName, "IsLeaf",  each false, type logical),
        withData = if(Table.IsEmpty(tbl)) then tbl else Table.AddColumn(withIsLeaf, "Data",each CreateMultiLvlFolder([title],[id],[childIds],false) , type table),  

        objects = #table(
            { "id","title","childIds","Count","Data", "ItemKind", "ItemName", "IsLeaf" },{
            { "1","All Projects / Folders-'"&folderTitle&"'",null, 0, GetAPIData("foldersunderfolder",folderId), "Table",  "Table", true },
            { "2","All Projects / Folders-'"&folderTitle&"' Custom Field Values",null, 0, GetFolderUnderFoldersWithCustomFields(folderId), "Table",  "Table", true },
            { "3","All Tasks-'"&folderTitle&"'",null, 0, GetAllTasksInFolder(folderId,false,false), "Table",  "Table", true },
            { "4","All Tasks Finance Data-'"&folderTitle&"'",null, 0, GetAllTasksInFolder(folderId,false,true), "Table",  "Table", true },
            { "5","All Tasks & Dependencies-'"&folderTitle&"'",null, 0, GetAllTasksInFolder(folderId,true,false), "Table",  "Table", true }
         //   { "4","Custom Fields",null,0, customFieldsInSpace, "Table", "Table", true },
         //   { "5", "Custom Fields Expand",null,0, customFieldsExpandedInSpace, "Table", "Table", true }
         }),

          object2 = if(isSpace = false) then #table(
          { "id","title","childIds","Count","Data", "ItemKind", "ItemName", "IsLeaf" },
          { { "5","Timelogs with finance-'"&folderTitle&"'",null, 0, GetAPIData("foldertimelogwithfinance",folderId), "Table",  "Table", true } }) else Table.EmptyTable(),

        v = Table.Combine({withData,objects,object2}),
        NavTable = Table.ToNavigationTable(v, {"title"}, "title", "Data", "ItemKind", "ItemName", "IsLeaf")
      in NavTable;

//
// Get ALL Folders at account level call with Custom Fields.
//
GetFolderUnderFoldersWithCustomFields = (folderId as text) as table => 
    let 
      v = GetAPIData("foldersunderfolder",folderId),
      #"Added Custom" = Table.AddColumn(v, "Custom", each Wrike.GetFolderDetails([id])),
      #"Removed Other Columns" = Table.SelectColumns(#"Added Custom",{"Custom"}),
      #"Removed Errors" = Table.RemoveRowsWithErrors(#"Removed Other Columns", {"Custom"}),
      #"Expanded Custom" = Table.ExpandTableColumn(#"Removed Errors", "Custom", {"id", "title", "briefDescription", "updatedDate","hasAttachments","attachmentCount", "permalink", "parentIds", "childIds","workflowId","superParentIds", "metadata", "customFields","customItemTypeId"}, {"id", "title", "briefDescription", "updatedDate","hasAttachments","attachmentCount", "permalink","parentIds", "childIds", "workflowId","superParentIds", "metadata", "customFields","customItemTypeId"}),
      #"Changed Type" = Table.TransformColumnTypes(#"Expanded Custom",{{"id", type text}, {"title", type text}, {"hasAttachments", type logical},{"updatedDate", type datetime}, {"permalink", type text},{"briefDescription", type text}, {"workflowId", type text},{"attachmentCount", Int64.Type}, {"customItemTypeId", type text}})
in
    #"Changed Type" ;

//
// Get ALL Folders at account level call with Custom Fields.
//
GetAllFoldersWithCustomFields = () as table => 
    let 
      v = GetAPIData("allfolders"),
      #"Added Custom" = Table.AddColumn(v, "Custom", each Wrike.GetFolderDetails([id])),
      #"Removed Other Columns" = Table.SelectColumns(#"Added Custom",{"Custom"}),
      #"Removed Errors" = Table.RemoveRowsWithErrors(#"Removed Other Columns", {"Custom"}),
      #"Expanded Custom" = Table.ExpandTableColumn(#"Removed Errors", "Custom", {"id", "title", "briefDescription", "updatedDate","hasAttachments","attachmentCount", "permalink", "parentIds", "childIds","workflowId","superParentIds", "metadata", "customFields","customItemTypeId"}, {"id", "title", "briefDescription", "updatedDate","hasAttachments","attachmentCount", "permalink","parentIds", "childIds", "workflowId","superParentIds", "metadata", "customFields","customItemTypeId"}),
      #"Changed Type" = Table.TransformColumnTypes(#"Expanded Custom",{{"id", type text}, {"title", type text}, {"hasAttachments", type logical},{"updatedDate", type datetime}, {"permalink", type text},{"briefDescription", type text}, {"workflowId", type text},{"attachmentCount", Int64.Type}, {"customItemTypeId", type text}})
in
    #"Changed Type" ;

//
// Get ALL Folders at account level call with Finance Data.
//
GetAllFoldersWithFinanceData = () as table => 
    let 
      v = GetAPIData("allfolders"),
      #"Removed Other Columns" = Table.SelectColumns(v,{"id", "title"}),
      #"Added Custom" = Table.AddColumn(#"Removed Other Columns", "custom", each Wrike.GetFolderFinanceData([id])),
      #"Removed Errors" = Table.RemoveRowsWithErrors(#"Added Custom", {"custom"}),
      #"Expanded custom" = Table.ExpandTableColumn(#"Removed Errors", "custom", {"Column1"}, {"custom.Column1"}),
      #"Expanded custom.Column1" = Table.ExpandRecordColumn(#"Expanded custom", "custom.Column1", {"hasAttachments", "permalink", "workflowId", "customFields", "project"}, {"hasAttachments", "permalink", "workflowId", "customFields", "project"}),
      #"Changed Type" = Table.TransformColumnTypes(#"Expanded custom.Column1",{{"hasAttachments", type logical}, {"permalink", type text}, {"workflowId", type text}})
in
     #"Changed Type";

//
// Get all tasks in the folder and load dependencies based of variable.
//
GetAllTasksInFolder = (folderId as text, loadDependencies as logical, loadFinances as logical) as table => 
let
    selectedCase = if(loadFinances = true) then GetSelectedAPICall("taskswithfinance",folderId) else GetSelectedAPICall("tasks",folderId),
    alltasks = if(loadFinances = true) then Wrike.GetAllPagesByNextLink("taskswithfinance",selectedCase{0}) else Wrike.GetAllPagesByNextLink("tasks",selectedCase{0}),
    alltasksWithOrWithoutDependencies = if(loadDependencies = true) then Table.AddColumn(alltasks, "dependencies", each Wrike.GetTaskDependencies([id]))  else alltasks
in 
    alltasksWithOrWithoutDependencies;

//
// Generic base Columns in Navigator data structure  
//
AddBaseColumns = (navTable as table, itemKind as text, isLeaf as logical) => 
    let 
       withItemKind = Table.AddColumn(navTable, "ItemKind", each itemKind, type text),
       withItemName = Table.AddColumn(withItemKind, "ItemName", each itemKind, type text),
       withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each isLeaf, type logical)
    in
        withIsLeaf;
      

// Data Source for `Wrike`
Wrike = [
    TestConnection = (dataSourcePath) => {"Wrike.Contents"},
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh=Refresh,
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];


// Get Content call of Wrike
Wrike.GetContent = (contentType as text, relativepath as any, queryPerms as any) =>
    let
        json = Wrike.GetWebContentData(relativepath,queryPerms),
        toTable = Table.FromList(json[data], Splitter.SplitByNothing(), null, null, ExtraValues.List),
        toFormattedTable = GetFormattedTable(contentType)((toTable))
    in
        toFormattedTable;

Wrike.GetAllPagesByNextLink = (tableType as text,url as text, optional schema as type) as table =>

    Table.GenerateByPage((previous) => 
        let
            // if previous is null, then this is our first page of data
            nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
            // if NextLink was set to null by the previous call, we know we have no more data
            page = if (nextLink <> null) then Wrike.GetPage(tableType,url, nextLink) else null
        in
            page
    );

//
// Get Page data using next page token provided in response body as 'nextPageToken'
//
Wrike.GetPage = (tableType as text,initialurl as text, url as text) as table =>
    let       
        body = Wrike.GetWebContentData(url,"[]"),
        pageToken = Wrike.GetNextLink(body),
        nextLink = if(pageToken = "") then null else initialurl&"&nextPageToken="&pageToken,

        data = Table.FromList(body[data], Splitter.SplitByNothing(), null, null, ExtraValues.List),
        expand = GetFormattedTable(tableType)((data))

    in
        expand meta [NextLink = nextLink];

Wrike.GetNextLink = (response) as nullable text => Record.FieldOrDefault(response, "nextPageToken");

//
// Wrike has 2 host 'https://www.wrike.com' and 'https://app-eu.wrike.com'
// Wrike stores customer data in several data centers located in USA and European Union and you need to use a specific base URL to access user's data, based on where it is located.
// Initial call of authentication provides 'hostname' which should be used for all subsequent requests.
//
Wrike.GetWebContentData = (url as text, queryString as text) => 
     let 
        Response =  Web.Contents(hostPath_uri),
        jsonDomainPath = Json.Document(Response),
        hostPath = jsonDomainPath[host],
        response =  Web.Contents("https://" & hostPath & "/api/v4",
                [
                  RelativePath= url,
                  Query = queryString
        ]),
        body = Json.Document(response)
    in
        body;
//
// Start login function 
//
StartLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl =  auth_uri & Uri.BuildQueryString([
            client_id = client_id,
            state = state,
            response_type = "code",
            scope="wsReadOnly,amReadOnlyGroup,amReadOnlyUser,amReadOnlyAccessRole,amReadOnlyWorkSchedule,amReadOnlyAuditLog,amReadOnlyInvitation,amReadOnlyAccessRole",
            redirect_uri = redirect_uri])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = null
        ];

//
// Finish login function 
//
FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query],
        result = if (Record.HasFields(Parts, {"error", "error_description"})) then 
                    error Error.Record(Parts[error], Parts[error_description], Parts)
                 else
                     TokenMethod("authorization_code", "code", Parts[code])
    in
        result;

//
// Refresh token function 
//
Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", "refresh_token", refresh_token);

//
// Token retrival function during Authentication 
//
TokenMethod = (grantType, tokenField, code) =>
    let
        queryString = 
         [
            client_id = client_id,
            client_secret = client_secret,
            grant_type = grantType,
            redirect_uri = redirect_uri
         ],
        queryWithCode = Record.AddField(queryString, tokenField, code),

        Response = Web.Contents(token_uri, 
                [
                    Content =Text.ToBinary(Uri.BuildQueryString(queryWithCode)),
                    Headers=[
                                #"Content-type" = "application/x-www-form-urlencoded",
                                #"Accept" = "application/json"
                            ],
                     ManualStatusHandling = {400} 
                ]),
       
        body = Json.Document(Response),
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body)
                 else
                    body
    in
        result;


// Data Source UI publishing description
Wrike.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = learn_more_uri,
    SourceImage = Wrike.Icons,
    SourceTypeImage = Wrike.Icons
];

Wrike.Icons = [
    Icon16 = { Extension.Contents("wrike16.png"), Extension.Contents("wrike20.png"), Extension.Contents("wrike24.png"), Extension.Contents("wrike32.png") },
    Icon32 = { Extension.Contents("wrike32.png"), Extension.Contents("wrike40.png"), Extension.Contents("wrike48.png"), Extension.Contents("wrike64.png") }
];

// 
// Load common library functions
// 
// TEMPORARY WORKAROUND until we're able to reference other M modules 
// Function from MS Power BI examples 
  Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// 
// Trasformations of different Wrike APIs 
// 
Table.ToFolderTable = Extension.LoadFunction("Table.ToFolderTable.pqm");
Table.ToFolderDetailTable = Extension.LoadFunction("Table.ToFolderDetailTable.pqm");
Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");
Table.ToSpaceTable = Extension.LoadFunction("Table.ToSpaceTable.pqm");
Table.ToSpaceByIdTable = Extension.LoadFunction("Table.ToSpaceByIdTable.pqm");
Table.ToSpaceExpandTable = Extension.LoadFunction("Table.ToSpaceExpandTable.pqm");
Table.ToTasksTable = Extension.LoadFunction("Table.ToTasksTable.pqm");
Table.ToTaskDetailTable = Extension.LoadFunction("Table.ToTaskDetailTable.pqm"); 
Table.ToContactTable = Extension.LoadFunction("Table.ToContactTable.pqm");
Table.ToContactWithFinanceTable = Extension.LoadFunction("Table.ToContactWithFinanceTable.pqm");
Table.ToAccountable = Extension.LoadFunction("Table.ToAccountTable.pqm");
Table.ToCustomFieldsTable = Extension.LoadFunction("Table.ToCustomFieldsTable.pqm");
Table.ToCustomFieldsExpandTable = Extension.LoadFunction("Table.ToCustomFieldsExpandTable.pqm");
Table.ToAllTasksTable = Extension.LoadFunction("Table.ToAllTasksTable.pqm");
Table.ToWorkflowsTable = Extension.LoadFunction("Table.ToWorkflowsTable.pqm");
Table.ToGroupTable = Extension.LoadFunction("Table.ToGroupTable.pqm");
Table.EmptyTable = Extension.LoadFunction("Table.EmptyTable.pqm");
Table.GenerateByPage = Extension.LoadFunction("Table.GenerateByPage.pqm");
Table.ToFoldersUnderFolderTable = Extension.LoadFunction("Table.ToFoldersUnderFolderTable.pqm");
Table.ToTaskDependencies = Extension.LoadFunction("Table.ToTaskDependencies.pqm");
Table.ToTimelogsTable = Extension.LoadFunction("Table.ToTimelogsTable.pqm");
Table.ToTimelogCategoriesTable = Extension.LoadFunction("Table.ToTimelogCategoriesTable.pqm");
Table.ToTasksWithFinanceTable = Extension.LoadFunction("Table.ToTasksWithFinanceTable.pqm");
Table.ToAllAttachementsTable = Extension.LoadFunction("Table.ToAllAttachementsTable.pqm");
Table.ToAllApprovalsTable = Extension.LoadFunction("Table.ToAllApprovalsTable.pqm");
Table.ToFolderFinanceDetailTable = Extension.LoadFunction("Table.ToFolderFinanceDetailTable.pqm");
Table.ToFolderTimelogFinanceTable = Extension.LoadFunction("Table.ToFolderTimelogFinanceTable.pqm");
Table.ToJobRolesTable = Extension.LoadFunction("Table.ToJobRolesTable.pqm");
Table.ToPlaceholderTable = Extension.LoadFunction("Table.ToPlaceholderTable.pqm");
Table.ToBookingTable = Extension.LoadFunction("Table.ToBookingTable.pqm");
Table.ToWorkSchedulesTable = Extension.LoadFunction("Table.ToWorkSchedulesTable.pqm");
Table.ToCustomItemTypesTable = Extension.LoadFunction("Table.ToCustomItemTypesTable.pqm");
Table.ToAccessRolesTable = Extension.LoadFunction("Table.ToAccessRolesTable.pqm");
Table.ToInvitationsTable = Extension.LoadFunction("Table.ToInvitationsTable.pqm");
Table.ToAllFoldersTable = Extension.LoadFunction("Table.ToAllFoldersTable.pqm");



// 
// Helper function to get APIs URL based on type  
// 
GetAPIData = (tableType as text,optional id as text) => 
    let 
        selectedCase = GetSelectedAPICall(tableType,id),
        data = Wrike.GetContent(tableType,selectedCase{0}, selectedCase{1})
    in 
        data;

GetSelectedAPICall = (tableType as text,optional id as text) => 
    let 
        CaseValues = {
            {"spaces" , {"/folders?descendants=false&fields=[space]","[]"} },
            {"spacesbyid" , {"/spaces/" & id & "?fields=[members]","[]"} },
            {"spacesexpand" , {"/spaces?fields=[members]","[]"} },
            {"folders" , {"/spaces/" & id & "/folders?[contractTypes=[Billable,NonBillable],descendants=true,fields=[customFields,space,contractType,metadata,inheritedCustomColumnIds,customItemTypeId]]","[]"} },
            {"foldersunderfolder" , {"/folders/" & id & "/folders?fields=[metadata,hasAttachments,description,attachmentCount,briefDescription,customFields,superParentIds,customColumnIds,space,contractType,customItemTypeId]","[]"} },
            {"folderdetails" , {"/folders/" & id & "?fields=[briefDescription,customColumnIds,contractType,inheritedCustomColumnIds,attachmentCount,customItemTypeId]","[]"} },
            {"folderdetailswithfinance" , {"/folders/" & id & "?fields=[briefDescription,customColumnIds,contractType,inheritedCustomColumnIds,finance]","[]"} },
            {"tasks" , {"/folders/" & id & "/tasks?pageSize=1000&fields=[superTaskIds,parentIds,recurrent,dependencyIds,metadata,sharedIds,customFields,inheritedCustomColumnIds,authorIds,superParentIds,hasAttachments,subTaskIds,responsibleIds,briefDescription,effortAllocation,billingType,customItemTypeId]&sortField=CreatedDate&descendants=true&subTasks=true","[]"} },
            {"taskswithfinance" , {"/folders/" & id & "/tasks?pageSize=1000&fields=[superTaskIds,parentIds,recurrent,dependencyIds,metadata,sharedIds,customFields,inheritedCustomColumnIds,authorIds,superParentIds,hasAttachments,subTaskIds,responsibleIds,briefDescription,effortAllocation,billingType,finance]&sortField=CreatedDate&descendants=true&subTasks=true","[]"} },
            {"taskdetails" , {"/tasks/" & id & "?fields=[inheritedCustomColumnIds]","[]"} },
            {"taskdependencies" , {"/tasks/" & id & "/dependencies","[]"} },
            {"contactswithfinance" , {"/contacts?deleted=false&fields=[metadata,workScheduleId,currentBillRate,currentCostRate,jobRoleId]","[]"} },
            {"contacts" , {"/contacts?deleted=false&fields=[metadata,workScheduleId,jobRoleId]","[]"} },
            {"customitemtypes" , {"/custom_item_types","[]"} },
            {"accessroles" , {"/access_roles","[]"} },
            {"invitations" , {"/invitations","[]"} },
            {"account" , {"/account?fields=[subscription,metadata]","[]"} },
            {"customfields" , {"/customfields","[]"} },
            {"jobroles" , {"/jobroles","[]"} },
            {"workschedules" , {"/workschedules?fields=[userIds]","[]"} },
            {"bookings" , {"/bookings?showDescendants=True","[]"} },
            {"placeholders" , {"/placeholders","[]"} },
            {"customfields" , {"/customfields","[]"} },
            {"customfieldsexpand" , {"/customfields","[]"} },
            {"alltasks" , {"/tasks?pageSize=1000&fields=[superTaskIds,parentIds,recurrent,dependencyIds,metadata,sharedIds,customFields,authorIds,superParentIds,hasAttachments,subTaskIds,responsibleIds,briefDescription,effortAllocation,billingType,customItemTypeId]&sortField=CreatedDate&descendants=true&subTasks=true","[]"} },
            {"allspacetasks" , {"/spaces/" & id & "/tasks","[fields=[superTaskIds,parentIds,recurrent,dependencyIds,metadata,sharedIds,customFields,inheritedCustomColumnIds,authorIds,superParentIds,hasAttachments,subTaskIds,responsibleIds,customItemTypeId ],sortField=CreatedDate,descendants=true]"} },
            {"workflows" , {"/workflows","[]"} },
            {"groups" , {"/groups","[]"} },
            {"timelogs" , {"/timelogs?fields=[billingType]","[]"} },
            {"timelogcategories" , {"/timelog_categories","[]"} },
            {"allfolders" , {"/folders?descendants=true&fields=[metadata,hasAttachments,description,attachmentCount,briefDescription,customFields,superParentIds,customColumnIds,space,contractType,attachmentCount,customItemTypeId]","[]"} },
            {"allattachments" , {"/attachments","[]"} },
            {"allapprovals" , {"/approvals?pageSize=1000","[]"} },
            {"foldertimelogwithfinance" , {"/folders/" & id & "/timelogs?fields=[billingType,finance]","[]"} }
        },
        selectedCase = List.First(List.Select(CaseValues,each _{0} = tableType)){1}
    in 
        selectedCase;

// 
// Helper function to get Table transformation based on type  
// 
GetFormattedTable = (tableType as text) => 
    let 
        CaseValues = {
            { "spaces" , Table.ToSpaceTable },
            { "spacesexpand" , Table.ToSpaceExpandTable },
            { "folders" , Table.ToFolderTable },
            { "folderdetails" , Table.ToFolderDetailTable },
            { "folderdetailswithfinance" , Table.ToFolderFinanceDetailTable },
            { "tasks" , Table.ToTasksTable },
            { "taskswithfinance" , Table.ToTasksWithFinanceTable },
            { "taskdetails" , Table.ToTaskDetailTable },
            { "taskdependencies" , Table.ToTaskDependencies },
            { "contacts" , Table.ToContactTable },
            { "customitemtypes" , Table.ToCustomItemTypesTable },
            { "accessroles" , Table.ToAccessRolesTable },
            { "contactswithfinance" , Table.ToContactWithFinanceTable },
            { "invitations" , Table.ToInvitationsTable },
            { "jobroles" , Table.ToJobRolesTable },
            {"workschedules" , Table.ToWorkSchedulesTable },
            { "bookings" , Table.ToBookingTable },
            { "placeholders" , Table.ToPlaceholderTable },
            { "account" , Table.ToAccountable },
            { "customfields" , Table.ToCustomFieldsTable },
            { "customfieldsexpand" , Table.ToCustomFieldsExpandTable },
            { "alltasks" , Table.ToAllTasksTable },
            { "allspacetasks" , Table.ToAllTasksTable },
            { "groups" , Table.ToGroupTable },
            { "workflows" , Table.ToWorkflowsTable },
            {"spacesbyid" , Table.ToSpaceByIdTable },
            {"foldersunderfolder" , Table.ToFoldersUnderFolderTable },
            {"timelogs" , Table.ToTimelogsTable },
            {"timelogcategories" , Table.ToTimelogCategoriesTable },
            {"allfolders" , Table.ToAllFoldersTable },
            {"allattachments" , Table.ToAllAttachementsTable },
            {"allapprovals" , Table.ToAllApprovalsTable },
            {"foldertimelogwithfinance" , Table.ToFolderTimelogFinanceTable }
        },
        selectedCase = List.First(List.Select(CaseValues,each _{0} = tableType)){1}
    in 
        selectedCase;


