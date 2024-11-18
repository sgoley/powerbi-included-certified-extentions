// This file contains your Data Connector logic
[Version = "1.0.3"]
section WorkforceDimensions;

DAYS_REQUEST_LIMIT = 100;
EMPLOYEE_REQUEST_LIMIT = 250;
GET_DATA_DATE_PATTERN = "yyyy-MM-ddThh:mm:ss.fff";

SYMBOLIC_PERIODS = [#"Date Range (start and end dates are required)" = null, 
                    #"Previous Pay Period" = "Previous_Payperiod", 
                    #"Current Pay Period" = "Current_Payperiod", 
                    #"Next Pay Period" = "Next_Payperiod", 
                    #"Today" = "Today", 
                    #"Yesterday" = "Yesterday", 
                    #"Yesterday, Today, Tomorrow" = "Yesterday_Today_Tomorrow", 
                    #"Yesterday Plus 6 Days" = "Yesterday_Plus_Six_Days",
                    #"Last 30 Days" = "Last_Thirty_Days", 
                    #"Last 90 Days" = "Last_Ninety_Days", 
                    #"Last Week" = "Last_Week", 
                    #"Current Week" = "Current_Week"];

//person related metadata (Column Display name, type, order)
PERSON_DATA_FIELDS = {{"Employee ID", type text, 0}, {"Employee Name", type text, 1}, {"Primary Job", type text, 250}, {"Location", type text, 260 }, 
            {"Active Badge Number", Int64.Type, 270}, {"Email Address", type text, 280}, {"Weekly Hours", type number, 290},
            {"Daily Hours", type number, 300}, {"Payrule", type text, 310}, {"Payrule Effective Date", type date, 320}, {"HireDate", type date, 330}, {"EmployeeTerm", type text, 340}, {"EmpStatus", type text, 350}, {"Manager Name", type text, 360},
            {"Worker Type", type text, 370}, {"Time Zone", type text, 380}, {"User Account", type text, 390}, {"Phone Number", type text, 400}, {"Manager - Job Transfer Set", type text, 410}, {"Employee - Job Transfer Set", type text, 420},
            {"Organization Group Set", type text, 430}, {"Manager - Labor Category List Profile", type text, 440}, {"Employee - Labor Category List Profile", type text, 450}, {"Home State", type text, 460},
            {"Zip Code", type text, 470}, {"Attendance Profile", type text, 480}, {"Accrual Profile", type text, 490}, {"Seniority Date", type date, 500}, {"Device Group Name", type text, 510}, {"Schedule Group Assignment Name", type text, 520},
            {"Workflow Manager Profile", type text, 530}, {"Workflow Employee Profile", type text, 540} , {"Custom Data", type text, 550}};

//time related metadata (Column Display name, type, order)
TIME_DATA_FIELDS = {{"Shift Total Wages", type number, 81}, {"Amount", type number, 50}, {"Paycode Is Combined", type logical, 60}, 
            {"Shift Apply Date", type date, 70}, {"Shift Duration in Hours", type number, 80}, {"Shift Total Days", type number, 90}, {"Daily Total Days", type number, 100}, 
            {"Daily Apply Date", type date, 110}, {"Daily Duration in Hours", type number, 120}, {"Apply Date", type date, 20}, {"Labor Transfer", type logical, 130}, {"Pay Period Week", Int64.Type, 140}, 
            {"Sign Off", type logical, 150}, {"Wage Add", type number, 160}, {"Pay Period Number", Int64.Type, 170}, {"Job Transfer", type logical, 180}, {"Wage Multiplier", type number, 190},
            {"Actual Through Selected Day Hours", type text, 200}, {"Actual Through Selected Day Hours Minus Avg Target Hours", type text, 210}, {"Avg Target Hours Minus Actual Through Selected Day Hours", type text, 220},
            {"Var Actual Hours Minus Target Through Selected Day Hours", type text, 230}, {"Var Target Hours Minus Actual Through Selected Day Hours", type text, 240}, 
             {"Paycode Name", type text, 30}, {"Paycode Type", type text, 40}};


[DataSource.Kind="WorkforceDimensions"]
shared WorkforceDimensions.Contents = Value.ReplaceType(WorkforceDimensionsImpl, WorkforceDimensionsType);


WorkforceDimensionsType = type function (
     configurationServer as (type text meta [
            Documentation.FieldCaption = Extension.LoadString("ConfigurationServerUrlCaption"),
            Documentation.FieldDescription = Extension.LoadString("ConfigurationServerUrlDescription"),
            Documentation.SampleValues = {Extension.LoadString("ConfigirationServerUrlSample")}
     ]),
     workForceDimensionsServer as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("WFServerUrlCaption"),
        Documentation.FieldDescription = Extension.LoadString("WFServerUrlDescription"),
        Documentation.SampleValues = {Extension.LoadString("WFServerUrlSample")}
    ]),
  
     symbolicPeriod as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("SymbolicPeriodCaption"),
        Documentation.FieldDescription = Extension.LoadString("SymbolicPeriodDescription"),
        Documentation.SampleValues = {"Current Pay Period"},
        Documentation.AllowedValues = Record.FieldNames(SYMBOLIC_PERIODS),
        DataSource.Path = false
    ]),
     optional startDate as (type date meta [
        Documentation.FieldCaption = Extension.LoadString("StartDateCaption"),
        Documentation.FieldDescription = Extension.LoadString("StartDateDescription"),
        Documentation.SampleValues = {"01/01/2018"}
    ]),
     optional endDate as (type date meta [
        Documentation.FieldCaption = Extension.LoadString("EndDateCaption"),
        Documentation.FieldDescription = Extension.LoadString("EndDateDescription"),
        Documentation.SampleValues = {"12/12/2018"}
    ]))
    as text meta [
        Documentation.Name = Extension.LoadString("WFFormName"),
        Documentation.LongDescription = Extension.LoadString("WFFormDescription")
    ];

WorkforceDimensionsImpl = (configurationServer as text, workForceDimensionsServer as text, symbolicPeriod as text, optional startDate as date, optional endDate as date) => 
  let
        validationError = validateDate(symbolicPeriod, startDate, endDate),
        _configurationServer = ValidateUrlScheme(configurationServer),
        _workForceDimensionsServer = ValidateUrlScheme(workForceDimensionsServer),

        result = if validationError = null
                          then 
                              let                                   
                                    dateRangeDetails = [
                                        startDate = startDate,
                                        endDate = endDate,
                                        symbolicPeriod = if symbolicPeriod <> null 
                                                                   then Record.Field(SYMBOLIC_PERIODS, symbolicPeriod)
                                                                   else null
                                    ],
                                    
                                    credentials = Extension.CurrentCredential(),
                                    connectionDetails = [
                                                    workForceDimensionsServer = _workForceDimensionsServer, 
                                                    configurationServer = _configurationServer,
                                                    credentials = credentials],
                                    settings = getTenantSettings(connectionDetails)
                                   
                              in                                 
                                 loadTimePersonData(settings, dateRangeDetails)

                        else validationError
  in result;

ValidateUrlScheme = (url as text) as text => if (Uri.Parts(url)[Scheme] <> "https") then error "URL scheme must be HTTPS" else url;

loadTimePersonData = (connectionDetails, dateRangeDetails) =>
    let
        //get authentication token
        authTokenResponse = try getAuthToken(connectionDetails),
        result = if authTokenResponse[HasError]
                       then error Extension.LoadString("Error.AuthToken")
                 else 
                    let
                        result = try
                           let
                                timeData = loadTimeData(connectionDetails, dateRangeDetails, authTokenResponse[Value]),
                                personData =  loadPersonData(connectionDetails, dateRangeDetails, authTokenResponse[Value]),
                                data = if Table.IsEmpty(timeData[result]) or Table.IsEmpty(personData[result])
                                           then Extension.LoadString("NoDataFound")
                                        else
                                           let
                                                //merge and transform data
                                                columnsMetadata = List.Combine({personData[columnsToTransform], timeData[columnsToTransform]}),
                                                sorted = List.Sort(columnsMetadata, {each _{2},  Order.Ascending}),
                                                sortedNames = List.Transform(sorted, each _{0}),

                                                Source = Table.NestedJoin(timeData[result], {"Employee ID.TK"}, personData[result], {"Employee ID"},"Person Data", JoinKind.LeftOuter),
                                                timePersonData = Table.ExpandTableColumn(Source, "Person Data", personData[columnsToShow]),
                                                #"Removed Columns" = Table.RemoveColumns(timePersonData, {"Employee ID.TK"}),
                                                result = Table.ReorderColumns(#"Removed Columns", sortedNames)
                                           in
                                                result
                           in
                              data
                                        
                    in
                        if result[HasError]
                             then error result[Error][Message]//Extension.LoadString("Error.GetData")
                             else result[Value]
                                    
    in
        result;

// check if date range or timeframe is specified and correct 
validateDate = (symbolicPeriod, startDate, endDate) => 
    let
        validationError = if Record.Field(SYMBOLIC_PERIODS, symbolicPeriod) = null
                    then 
                         if startDate = null and endDate = null 
                              then error Extension.LoadString("Error.StartAndEndDateRequired")
                         else if startDate = null 
                              then error Extension.LoadString("Error.StartDateRequired")
                         else if endDate = null
                              then error Extension.LoadString("Error.EndDateRequired") 
                         else if startDate > endDate
                              then error Extension.LoadString("Error.StartDateAfterEndDate")
                         else null
                    else null
    in 
        validationError;

//exclude fields that are not in response
filterColumns = (rawGetDataResponse, initialFieldSet) => 
    let
        attributes = List.Combine(List.Transform(rawGetDataResponse[data][children], each _[attributes])),
        fieldNamesToShow = List.Distinct(List.Transform(attributes, each _[alias])),
        fieldsToTransform = List.Select(initialFieldSet, each List.Contains(fieldNamesToShow, List.First(_)) = true)
    in 
        [columnsToShow = fieldNamesToShow, columnsToTransform = fieldsToTransform];

loadPersonData = (connectionDetails, dateRangeDetails, authTokenResponse) =>
    let
        rawData = loadDataByDateRecursively(connectionDetails, dateRangeDetails, authTokenResponse, "PersonDataRequest.json", true),
        filteredColumns = filterColumns(rawData, PERSON_DATA_FIELDS),
        #"Converted to Table" = Record.ToTable(rawData),
        #"Removed Top Rows" = Table.Skip(#"Converted to Table",1),
        #"Expanded Value" = Table.ExpandRecordColumn(#"Removed Top Rows", "Value", {"children"}, {"Value.children"}),
        #"Expanded Value.children" = Table.ExpandListColumn(#"Expanded Value", "Value.children"),
        #"Expanded Value.children1" = Table.ExpandRecordColumn(#"Expanded Value.children", "Value.children", {"key", "attributes"}, {"Value.children.key", "Value.children.attributes"}),
        #"Expanded Value.children.attributes" = Table.ExpandListColumn(#"Expanded Value.children1", "Value.children.attributes"),
        #"Expanded Value.children.attributes1" = Table.ExpandRecordColumn(#"Expanded Value.children.attributes", "Value.children.attributes", {"alias", "rawValue"}, {"Value.children.attributes.alias", "Value.children.attributes.rawValue"}),
        #"Removed Columns" = Table.RemoveColumns(#"Expanded Value.children.attributes1",{"Value.children.key", "Name"}),
        #"Added Index" = Table.AddIndexColumn(#"Removed Columns", "Index", 0, 1),
        #"Inserted Integer-Division" = Table.AddColumn(#"Added Index", "Integer-Division", each Number.IntegerDivide([Index], List.Count(filteredColumns[columnsToShow])), Int64.Type),
        #"Removed Columns1" = Table.RemoveColumns(#"Inserted Integer-Division",{"Index"}),
        #"Pivoted Column" = Table.Pivot(#"Removed Columns1", List.Distinct(#"Removed Columns1"[Value.children.attributes.alias]), "Value.children.attributes.alias", "Value.children.attributes.rawValue"),
        #"Removed Columns2" = Table.RemoveColumns(#"Pivoted Column",{"Integer-Division"}),
        result = Table.TransformColumnTypes(#"Removed Columns2", filteredColumns[columnsToTransform])
    in
        [result = result, columnsToShow = filteredColumns[columnsToShow], columnsToTransform = filteredColumns[columnsToTransform]];

loadTimeData = (connectionDetails, dateRangeDetails, authTokenResponse) =>
    let
        rawData = loadDataByDateRecursively(connectionDetails, dateRangeDetails, authTokenResponse, "TimeDataRequest.json", false),
        filteredColumns = filterColumns(rawData, TIME_DATA_FIELDS),
        #"Converted to Table" = Record.ToTable(rawData),
        #"Removed Top Rows" = Table.Skip(#"Converted to Table",1),
        #"Expanded Value" = Table.ExpandRecordColumn(#"Removed Top Rows", "Value", {"children"}, {"Value.children"}),
        #"Expanded Value.children" = Table.ExpandListColumn(#"Expanded Value", "Value.children"),
        #"Removed Columns" = Table.RemoveColumns(#"Expanded Value.children", {"Name"}),
        #"Expanded Value.children1" = Table.ExpandRecordColumn(#"Removed Columns", "Value.children", {"key", "coreEntityKey", "attributes"}, {"Value.children.key", "Value.children.coreEntityKey", "Value.children.attributes"}),
        #"Expanded Value.children.key" = Table.ExpandRecordColumn(#"Expanded Value.children1", "Value.children.key", {"TKPAYCODE_ACTUAL_TOTALS", "TKDAILY_ACTUAL_TOTAL_SUMMARY", "TKSHIFT_ACTUAL_TOTAL_SUMMARY"}, {"TKPAYCODE_ACTUAL_TOTALS", "TKDAILY_ACTUAL_TOTAL_SUMMARY", "TKSHIFT_ACTUAL_TOTAL_SUMMARY"}),
        #"Unpivoted Columns" = Table.UnpivotOtherColumns(#"Expanded Value.children.key", {"Value.children.coreEntityKey", "Value.children.attributes"}, "Attribute", "Value"),
        #"Merged Columns" = Table.CombineColumns(#"Unpivoted Columns",{"Attribute", "Value"},Combiner.CombineTextByDelimiter(" ", QuoteStyle.None),"Index"),
        #"Expanded Value.children.coreEntityKey" = Table.ExpandRecordColumn(#"Merged Columns", "Value.children.coreEntityKey", {"EMP"}, {"EMP"}),
        #"Expanded EMP" = Table.ExpandRecordColumn(#"Expanded Value.children.coreEntityKey", "EMP", {"id"}, {"Employee ID.TK"}),
        #"Sorted Rows" = Table.Sort(#"Expanded EMP", {{"Employee ID.TK", Order.Ascending}}),
        #"Expanded Value.children.attributes" = Table.ExpandListColumn(#"Sorted Rows", "Value.children.attributes"),
        #"Expanded Value.children.attributes1" = Table.ExpandRecordColumn(#"Expanded Value.children.attributes", "Value.children.attributes", {"alias", "rawValue"}, {"Value.children.attributes.alias", "Value.children.attributes.rawValue"}),
        #"Pivoted Column" = Table.Pivot(#"Expanded Value.children.attributes1", List.Distinct(#"Expanded Value.children.attributes1"[Value.children.attributes.alias]), "Value.children.attributes.alias", "Value.children.attributes.rawValue"),
        #"Removed Columns 1" = Table.RemoveColumns(#"Pivoted Column",{"Index"}),
        result = Table.TransformColumnTypes(#"Removed Columns 1", filteredColumns[columnsToTransform])
    in  
        [result = result, columns = filteredColumns[columnsToShow], columnsToTransform = filteredColumns[columnsToTransform]];

//merge get data response into single document
mergeGetDataResponse = (combinedResponse, delta, isUniqueKeysOnly) => 
     let
          newResponse = [
                        metadata = [
                            lastRefreshed = delta[metadata][lastRefreshed],
                            metadataKey = delta[metadata][metadataKey],
                            numNodes = if Record.HasFields(combinedResponse[metadata], "numNodes") and Record.HasFields(delta[metadata], "numNodes")
                                           then Number.ToText(Number.FromText(combinedResponse[metadata][numNodes]) + Number.FromText(delta[metadata][numNodes]))
                                           else if Record.HasFields(delta[metadata], "numNodes") 
                                                then delta[metadata][numNodes]
                                                else if Record.HasFields(combinedResponse[metadata], "numNodes")
                                                then combinedResponse[metadata][numNodes]  
                                                else null,
                            cacheKey = delta[metadata][cacheKey],
                            errors = if Record.HasFields(combinedResponse[metadata], "errors") and Record.HasFields(delta[metadata], "errors")
                                           then List.Combine({combinedResponse[metadata][errors], delta[metadata][errors]})
                                           else if Record.HasFields(delta[metadata], "errors") 
                                                then delta[metadata][errors]
                                                else if Record.HasFields(combinedResponse[metadata], "errors")
                                                then combinedResponse[metadata][errors]  
                                                else {}                                         
                    
                        ],
                        data = [
                              key = combinedResponse[data][key],
                              coreEntityKey = combinedResponse[data][coreEntityKey],
                              attributes = combinedResponse[data][attributes],
                              summaryListDisplay = combinedResponse[data][summaryListDisplay],
                              rootEntity = combinedResponse[data][rootEntity],
                              customProperties = combinedResponse[data][customProperties],
                              //for employee data we don't want to have the same persons in response
                              children = if isUniqueKeysOnly = true
                                            then
                                              let 
                                                  findEmployeeId = (attributes) => 
                                                      let
                                                           employeeNameAttributes = List.Select(attributes, each _[key] = "EMP_COMMON_ID")
                                                      in
                                                           List.First(employeeNameAttributes, [rawValue = null]),

                                                  childrenWithDuplicates = List.Combine({combinedResponse[data][children], delta[data][children]}),
                                                  distinctChildren = List.Distinct(childrenWithDuplicates, each findEmployeeId(_[attributes]))
                                              in distinctChildren 
                                            else
                                               List.Combine({combinedResponse[data][children], delta[data][children]})
                         ]
                       ]
     in 
       newResponse;

formatDate = (date, pattern) => 
    let
        dateTime = DateTime.ToText(#datetime(Date.Year(date), Date.Month(date), Date.Day(date), 0, 0, 0), pattern)
    in 
        dateTime;

//due to service limits we are restricted of 365 days in request only. If date range is greater we need to split
//it into several requests and merge them aftrewards.
loadDataByDateRecursively = (connectionDetails, dateRangeDetails, authTokenResponse, jsonFile, isUniqueKeysOnly) =>
   let      
        startDateTime = dateRangeDetails[startDate],
        endDateTime = dateRangeDetails[endDate],
        symbolicPeriod = dateRangeDetails[symbolicPeriod],
    
        //check date range to see if it exceeds limit value, if yes - break down request into parts
        makeReqursiveCall = (mergedData, startDateTime, endDateTime) =>
            let
               dayDuration = Duration.TotalDays(endDateTime - startDateTime),
               newEndDateTime = if dayDuration <= DAYS_REQUEST_LIMIT
                                    then  endDateTime
                                    else Date.AddDays(startDateTime, DAYS_REQUEST_LIMIT),
               
               data = loadData(connectionDetails, authTokenResponse, jsonFile, 
                                            formatDate(startDateTime, GET_DATA_DATE_PATTERN), formatDate(newEndDateTime, GET_DATA_DATE_PATTERN), null),
               result = if mergedData = null                                      
                                    then data
                                    else mergeGetDataResponse(mergedData, data, isUniqueKeysOnly),            
               response = if dayDuration <= DAYS_REQUEST_LIMIT
                                    then result                                         
                                    else @makeReqursiveCall(result, Date.AddDays(newEndDateTime, 1), endDateTime)
            in 
               response,
         //if symbolic period  - no need to split date range
         result = if symbolicPeriod <> null
                        then
                            loadData(connectionDetails, authTokenResponse, jsonFile, null, null, symbolicPeriod)
                        else 
                            makeReqursiveCall(null, startDateTime, endDateTime)
                      
    in
        result;

findEmployeeBatches = (connectionDetails, authTokenResponse) =>
    let
        //call hyperfind service to find subordinates
        json =  Text.FromBinary(Extension.Contents("HyperfindRequest.json")),
        url = connectionDetails[workForceDimensionsServer] & "/api/v1/commons/hyperfind/execute",
         response = Web.Contents(url,
            [  
               Content = Text.ToBinary(json),
               Headers=[#"Content-type" = "application/json",#"Accept" = "application/json", #"Authorization" = authTokenResponse[access_token], #"appkey" = connectionDetails[appkey]]
            ]),
       parts = Json.Document(response),
       employeeIds = List.Transform(parts[result][refs], each _ [id]),
       employeeIdBatches = List.Split(employeeIds, EMPLOYEE_REQUEST_LIMIT) as list
    in
       employeeIdBatches;


loadData = (connectionDetails, authTokenResponse, file, startDate, endDate, symbolicPeriod) => 
    let

        employeeIdBatches = findEmployeeBatches(connectionDetails, authTokenResponse),
        result = List.Accumulate(employeeIdBatches, null, (combinedData, employeeSublist) => 
            let
                 request =  Text.FromBinary(Extension.Contents(file)),
                 dataRequest = Json.Document(request),
                 newGateDataRequest = [
                                select = dataRequest[select],
                                 options = dataRequest[options],
                                 from = [
                                    view = dataRequest[from][view],
                                    employeeSet = [
                                            employees = [
                                                ids = employeeSublist
                                        ],
                                        dateRange = if symbolicPeriod <> null 
                                                then [symbolicPeriod = [qualifier = symbolicPeriod]]
                                                else [startDate = startDate, endDate = endDate]
                                ]
                               ]
                           ],        
       
                getDataResponse = postRequest(newGateDataRequest, "/api/v1/commons/data/multi_read", connectionDetails, authTokenResponse), 
                result = if combinedData = null                                      
                                    then getDataResponse
                                    else mergeGetDataResponse(combinedData, getDataResponse, false)
            in
                result
          )

    in
        result;

//make a POST http call
postRequest = (payload, url, connectionDetails, authTokenResponse) => 
    let
        url = connectionDetails[workForceDimensionsServer] & url,
         response = Web.Contents(url,
            [  
               Content = Json.FromValue(payload),
               Headers=[#"Content-type" = "application/json",#"Accept" = "application/json", #"Authorization" = authTokenResponse[access_token], #"appkey" = connectionDetails[appkey]]
            ]),
       result = Json.Document(response)
    in 
        result;

getTenantSettings = (connectionDetails) => 
    let
          configurationServerUrl = connectionDetails[configurationServer] & "/powerbi/settings",
          response = Web.Contents(configurationServerUrl,
            [  
               Content = Json.FromValue([
                                            userName = connectionDetails[credentials][Username],
                                            password = connectionDetails[credentials][Password],
                                            vanityUrl = connectionDetails[workForceDimensionsServer]]),
               Headers=[#"Content-type" = "application/json",#"Accept" = "application/json", #"Authorization" = "", #"X-STATE" = DateTime.ToText(DateTime.LocalNow())]
            ]),
       tenantSettings = Json.Document(response)
    in 
       [
        workForceDimensionsServer = connectionDetails[workForceDimensionsServer],
        appkey = tenantSettings[appKey],
        tenant = tenantSettings[tenant],
        clientId = tenantSettings[oauthClientId],
        clientSecret = tenantSettings[oauthClientSecret],
        credentials = connectionDetails[credentials],
        accessTokenRequestUrl = tenantSettings[oauthServerUrl] & "/authn/oauth2/" & tenant & "/access_token"
      ];
//retrieve OAuth2 token to be used to call REST API
getAuthToken = (connectionDetails)=> 
    let
        response = Web.Contents(connectionDetails[accessTokenRequestUrl],
            [  
               Content = Text.ToBinary(Uri.BuildQueryString([
               client_id = connectionDetails[clientId],
               client_secret = connectionDetails[clientSecret],
               username = connectionDetails[credentials][Username],
               password = connectionDetails[credentials][Password],
               auth_chain = "OAuthLdapService",
               grant_type = "password"])),
               Headers=[#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json", #"Authorization" = "", #"X-STATE" = DateTime.ToText(DateTime.LocalNow())]
            ]),
       parts = Json.Document(response)
    in
       parts;

// Data Source Kind description
WorkforceDimensions = [
    Authentication = [
       UsernamePassword = []
    ],
    TestConnection = (dataSourcePath) =>
	        let
	            json = Json.Document(dataSourcePath),
	            configurationServer = json[configurationServer],
	            workForceDimensionsServer = json[workForceDimensionsServer]
	        in
	            { "WorkforceDimensions.Contents", configurationServer, workForceDimensionsServer, "Today" },
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
WorkforceDimensions.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = WorkforceDimensions.Icons,
    SourceTypeImage = WorkforceDimensions.Icons
];

WorkforceDimensions.Icons = [
    Icon16 = { Extension.Contents("WorkforceDimensions16.png"), Extension.Contents("WorkforceDimensions20.png"), Extension.Contents("WorkforceDimensions24.png"), Extension.Contents("WorkforceDimensions32.png") },
    Icon32 = { Extension.Contents("WorkforceDimensions32.png"), Extension.Contents("WorkforceDimensions40.png"), Extension.Contents("WorkforceDimensions48.png"), Extension.Contents("WorkforceDimensions64.png") }
];
