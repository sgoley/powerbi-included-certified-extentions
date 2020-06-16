[Version = "1.0.0"]
section ZohoCreator;

properties = Json.Document ( Extension.Contents( "WebApp.json") );

tool_name = properties[tool_details][tool_name];
user_agent = properties[tool_details][user_agent];
version_name = properties[tool_details][version_name];
version_number = properties[tool_details][version_number];

domains = properties[api_specification][domains];
api_type =  properties[api_specification][api_type];
max_retry = properties[api_specification][max_retry];
throttle_limit = properties[api_specification][throttle_limit];

GetDomain = (creatordomain as text) as any =>
    let
         jsonToList = Table.FromList(domains, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
         param2 = Table.ExpandRecordColumn(jsonToList,"Column1",{"domain","host"}),
         finaldomain = try Table.SelectRows(param2, each [domain] = creatordomain){0}[host] otherwise Table.SelectRows(param2, each [domain] = "zoho.com"){0}[host]
    in
        finaldomain;


fallBack =  (ownername as text, appname as text, viewname as text,authtoken as text,creatordomain as text) =>
    let
        BaseUrl  = GetDomain(creatordomain)&"/api/v2/"&ownername&"/"&appname&"/view/"&viewname&"/viewrecords?authtoken="& authtoken,
        RawData = Web.Contents(BaseUrl,[Headers=[#"User-Agent"= user_agent, #"Agent-Version-Number"=version_number]])
    in  
        RawData;

GetData = (ownername as text, appname as text, viewname as text, authtoken as text, creatordomain as text) =>
    let
        waitforresult = Value.WaitFor(
        (iteration) =>
            let 
            BaseUrl         = GetDomain(creatordomain)&"/mobileapi/v2/"&ownername&"/"&appname&"/view/"&viewname&"/viewrecords",
            urii = BaseUrl &"?authtoken="&authtoken,
            EntitiesPerPage = throttle_limit,
 
            GetJson = (Url) =>
                let                   
                    RawData =  Web.Contents(Url,[ManualStatusHandling = {401,400,500},Headers=[#"User-Agent"= user_agent, #"Agent-Version-Number"=version_number]]),
                    exec = Binary.Buffer(RawData),
                    status = Value.Metadata(RawData)[Response.Status],
                    actualResult = if status = 200 then exec else fallBack(ownername, appname, viewname, urii),
                    Json    = Json.Document(actualResult)
                in  Json,
 
            GetEntityCount = () =>
                let Json  = GetJson(urii),
                    Count = Record.Field(Json[submeta],"recordcount")
                in  Count,
 
            GetPage = (Index) =>
                let Skip  = (if authtoken then "&" else "?") & "fromIDX=" & Text.From(Index * EntitiesPerPage) &"&toIDX="&Text.From(EntitiesPerPage),
                    Url   = urii&Skip,
                    Json  = GetJson(Url),
                    Value = Json[data]
                in  Value,
 
            EntityCount = List.Max({ EntitiesPerPage, GetEntityCount() }),
            PageCount   = Number.RoundUp(EntityCount / EntitiesPerPage),
            PageIndices = { 0 .. PageCount - 1 },
            Pages       = List.Transform(PageIndices, each Function.InvokeAfter(()=>GetPage(_),#duration(0,0,0,2))),
            Entities    = List.Union(Pages),
            Table       = Table.FromList(Entities, Splitter.SplitByNothing(), null, null, ExtraValues.Error)
        in
            Table,
            (iteration) => #duration(0, 0, 0, Number.Power(2, iteration)),max_retry)
    in
        waitforresult;

Value.WaitFor = (producer as function, interval as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, null},
            (state) => state{0} <> null and (count = null or state{0} < count),
            (state) => if state{1} <> null then {null, state{1}} else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), interval(state{0}))},
            (state) => state{1})
    in
        List.Last(list);

GetRec = (ownername as text, appname as text, viewname as text, authtoken as text, creatordomain as text) =>
    let
       result = {0 .. 0},
       Pages = List.Transform(result, each GetRecords(ownername,appname,viewname, authtoken,creatordomain)),
       res = Pages{0}
    in
       res;

GetRecords = (ownername as text, appname as text, viewname as text, authtoken as text, creatordomain as text) =>
    let
        waitForResult = Value.WaitFor(
        (iteration) =>
        let
            BaseUrl = GetDomain(creatordomain)&"/downloadExportDataApi.do?isFullDownload=true&fileType=csv&sharedBy="&ownername&"&viewLinkName="&viewname&"&appLinkName="&appname,
            urii = BaseUrl &"&authtoken="&authtoken,
           exec =  Binary.Buffer(Web.Contents(urii,[ManualCredentials = true,ManualStatusHandling = {401,400,500},Headers=[#"User-Agent"= user_agent, #"Agent-Version-Number"=version_number]])),
            RawData = exec,
            status = Value.Metadata(exec)[Response.Status],
            actualResult = if status = 200 then RawData else fallBack(ownername, appname, viewname,authtoken, creatordomain) ,
            Json = Csv.Document(exec,[Delimiter=","])
        in
        Json,
         (iteration) => #duration(0, 0, 0, Number.Power(2, iteration)),max_retry)
    in
        waitForResult;

fetchData = (ownerName as text ,appLinkName as text,reportLinkName as text, creatordomain as text) => 
    let
        token = Extension.CurrentCredential()[Key],
        data = Table.PromoteHeaders(if api_type="export-api"  then GetRec(ownerName,appLinkName,reportLinkName, token, creatordomain ) else GetData(ownerName, appLinkName, reportLinkName,token, creatordomain))
   in
        data;

ConnectorEntryPoint = (creatordomain as text,scopename as text, appLinkName as text,reportLinkName as text) as any =>
    let
        res = fetchData(scopename ,appLinkName, reportLinkName,creatordomain)
    in
      res;

[DataSource.Kind="ZohoCreator", Publish="ZohoCreator.Publish"]
shared ZohoCreator.Contents = Value.ReplaceType(ConnectorEntryPoint,DialogInput);

DialogInput = type function (
     creatordomain as (type text meta [
        Documentation.FieldCaption = "Domain",
        Documentation.FieldDescription = "Choose the domain of your Zoho account",
        Documentation.AllowedValues = {"zoho.com", "zoho.eu", "zoho.com.cn", "zoho.in"}
    ]),
    scopname as (type text meta [
        Documentation.FieldCaption = "Workspace name",
        Documentation.FieldDescription = "Enter the Zoho Creator workpace name",
        Documentation.SampleValues = {"jack"}
    ]),
     applinkname as (type text meta [
        Documentation.FieldCaption = "Application link name",
        Documentation.FieldDescription = "Enter the Zoho Creator application link name",
        Documentation.SampleValues = {"zylker-management"}
    ]),
    reportlinkname as (type text meta [
        Documentation.FieldCaption = "Report link name",
        Documentation.FieldDescription = "Enter the Zoho Creator report link name",
        Documentation.SampleValues = {"Employee_Details"}
    ]))
    as any meta [
        Documentation.Name = "Zoho Creator",
        Documentation.LongDescription = "This connector will fetch data only from Zoho Creator application reports",
        Documentation.Examples = {[
            Description = "To fetches data from US account, scope 'jack', application 'task-management', report 'Task_Details'",
            Code = "ZohoCreator.Contents(""zoho.com"", ""jack"", ""zylker-management"", ""Employee_Details"")",
            Result = "#table({""Column1""}, {{""Column2""}, {""Column3""}})"
        ]}
    ];

// Data Source Kind description
ZohoCreator = [

    TestConnection = (dataSourcePath) => 
        let 
              json = Json.Document(dataSourcePath),
              creatordomain = json[creatordomain],
              scopename = json[scopname],
              applicationlinkname = json[applinkname],
              listreportlinkname = json[reportlinkname]
        in
            {"ZohoCreator.Contents",creatordomain,scopename,applicationlinkname,listreportlinkname},
         
    Authentication = [
        Key = [KeyLabel="Authtoken from your Zoho Creator Account"]
    ],
    Label = "Zoho Creator"
];

Value.IfNull = (a, b) => if a <> null then a else b;

// Data Source UI publishing description
ZohoCreator.Publish = [
    Beta = true,
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://www.zoho.com/creator/newhelp",
    SourceImage = ZohoCreator.Icons,
    SourceTypeImage = ZohoCreator.Icons
];

ZohoCreator.Icons = [
    Icon16 = { Extension.Contents("ZohoCreator16.png"), Extension.Contents("ZohoCreator20.png"), Extension.Contents("ZohoCreator24.png"), Extension.Contents("ZohoCreator32.png") },
    Icon32 = { Extension.Contents("ZohoCreator32.png"), Extension.Contents("ZohoCreator40.png"), Extension.Contents("ZohoCreator48.png"), Extension.Contents("ZohoCreator64.png") }
];