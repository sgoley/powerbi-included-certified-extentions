/* This file defines the Power Query Data Connector for EarthSoft's EQuIS. */
/* Copyright © All rights reserved, EarthSoft, Inc. 
   All images, text, logos, and content on this page are copyrighted by EarthSoft, Inc. 
   You may not photograph, copy, reproduce, duplicate, or in any fashion distribute any part of this information
   for any purpose whatsoever without the express written permission of EarthSoft, Inc. */

[Version = "7.23.10067"]
section EQuIS;

/***************************/
/***************************/
/******** Connector ********/
[DataSource.Kind="EQuIS", Publish="EQuIS.Publish"]
shared EQuIS.Contents = Value.ReplaceType(Navigator.GetMain, NavigatorInfo);

// "Publish" information for the connector
EQuIS.Publish = [
  Beta = false,
  Category = "Other",
  ButtonText = { "EQuIS", Extension.LoadString("ConnectorTooltip") },
  LearnMoreUrl = "https://help.earthsoft.com/index.htm?power-bi.htm",
  SourceImage = _Icons,
  SourceTypeImage = _Icons
];

_Icons = [
  Icon16 = { Extension.Contents("EQuIS16.png"), Extension.Contents("EQuIS20.png"), Extension.Contents("EQuIS24.png"), Extension.Contents("EQuIS32.png") },
  Icon32 = { Extension.Contents("EQuIS32.png"), Extension.Contents("EQuIS40.png"), Extension.Contents("EQuIS48.png"), Extension.Contents("EQuIS64.png") }
];

// "Kind" information for the connector
EQuIS = [

  TestConnection = (baseUri) => { "EQuIS.Contents", baseUri },

  Authentication = [
    Key = [
      KeyLabel = Extension.LoadString("Authentication.Key.KeyLabel"),
      Label = Extension.LoadString("Authentication.Key.Label")
    ],
    UsernamePassword = [
      Label = Extension.LoadString("Authentication.Basic.Label")
    ],
    Aad = [
        AuthorizationUri = (baseUri) => GetAuthorizationUrl(baseUri),
        Resource = "4d627659-bb7b-428b-aa0a-32d1b6e77e1a" // client id
    ]
  ],
  Label = Extension.LoadString("Authentication.Label")
];


Http.GetApi = (   // This function gets an API token for the user based on their selected authentication mode, then returns a record that can be used for later HTTP calls
  baseUri as text // The baseUri of the Enterprise site
) as record =>
  let
    
    // we are going to request a token that expires four hours from now
    iat = DateTimeZone.UtcNow(),
    exp = iat + #duration(0,4,0,0),
    json = "{""creationDt"":""" & DateTimeZone.ToText(iat, "yyyy-MM-ddTHH:mm:ss") & """,""expirationDt"":""" & DateTimeZone.ToText(exp, "yyyy-MM-ddTHH:mm:ss") & """}",

    // get the API token based on authentication type
    cred = Extension.CurrentCredential(),
    token = if cred[AuthenticationKind] = "UsernamePassword" then
              // for Basic authentication we need to get an API token using the default authentication
              Text.Trim(Text.FromBinary(Web.Contents(baseUri & "/api/tokens" & "?user-agent=equis-pqx", [ Headers = [ #"Content-Type" = "application/json" ], Content = Text.ToBinary(json) ])), """")
            else
              // use the existing token for Key and Aad authentication types
              if cred[AuthenticationKind] = "Key" then
                cred[Key]
              else
              // use the access_token for Aad authentication
                cred[access_token],
    
    // package up the options for further HTTP calls
    api = [
      baseUri = baseUri,
      options = [
        Timeout=#duration(0, 0, 15, 0),
        Headers = [
          Authorization = "Bearer " & token,
          UserAgent = "equis-pqx"
        ],
        ManualStatusHandling = {204},
        ManualCredentials = true
      ],
      userAgent = "user-agent=equis-pqx"
    ]
  in
    api;

GetAuthorizationUrl = (
  baseUri as text
) as text =>
  let
    apiResponse = Json.Document(Binary.Buffer(Web.Contents(baseUri & "/api/config/anon")))
  in
    // get the authority
    if (Record.HasFields(apiResponse, "azureActiveDirectory")) = true then
      apiResponse[azureActiveDirectory][authority] & "/oauth2/authorize"
    else
      error Error.Unexpected(Extension.LoadString("Authentication.Error"));



/***************************/
/***************************/
/******** Navigator ********/
NavigatorInfo = type function (
  baseUri as (Uri.Type meta [
    Documentation.FieldCaption = Extension.LoadString("Input.Url.Label"),
    Documentation.FieldDescription = Extension.LoadString("Input.Url.Tooltip"),
    Documentation.SampleValues = {"https://mysite.equisonline.com"}
  ]))
  as table meta [
    Documentation.Name = "EQuIS"
  ];


Navigator.GetMain = ( // Gets the main nagivation table for the given Enterprise site
  baseUri as text     // The baseUri of the Enterprise site
) as table =>
  let

    // enforce HTTPS
    _baseUri = if (Uri.Parts(baseUri)[Scheme] <> "https") then error Extension.LoadString("Protocol.Error") else baseUri,

    // get API token based on auth
    api = Http.GetApi(_baseUri),

    nodes = {
      { Extension.LoadString("FacilityGroups"), "_FacilityGroups", Navigator.GetFacilityGroups(api), "CubeViewFolder", "CubeViewFolder", false },
      { Extension.LoadString("Facilities"), "_Facilities", Navigator.GetFacilities(api), "Folder", "Folder", false },
      { Extension.LoadString("Reports"), "_Reports", Navigator.GetReports(api, -1, ""), "Folder", "Folder", false },
      { Extension.LoadString("EIAs"), "_EIA(s)", Navigator.GetReportsWithEIAs(api), "Folder", "Folder", false }
    },

    tbl = #table(
      {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, nodes),

    nav = Table.ToNavigationTable(tbl, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
  in
    nav;

Navigator.GetFacilityGroups = (  // Get a folder (navigation table) of report tables available to the current user at the given baseUri
  api as record                  // The Enterprise REST API info
) as table =>
  let
    // get all groups with their facilityId parameter set to a negative euid
    allFacilities = Json.Document(Binary.Buffer(Web.Contents(api[baseUri] & "/api/groups?q.returnTopLevelOnly=false&q.groupType=*|facility_id" & Text.Combine({"&", api[userAgent]}), api[options]))),

    facilityGroups = List.Accumulate(List.Select(allFacilities, (item) => item[facilityId] < -1), {}, (list, item) => List.Combine({list, {{ item[name], item[id], Navigator.GetFacilityGroup(api, item), "CubeViewFolder", "CubeViewFolder", false }}})),
    // convert to table
    tbl = #table({"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, facilityGroups),

    // convert to navigation table
    nav = Table.ToNavigationTable(tbl, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")

  in
    nav;


Navigator.GetFacilityGroup = (   // Get a folder (navigation table) for a group which contains a facility
  api as record,                 // The Enterprise REST API info
  facilityGroup as record        // The facility group (as a record) to be used for this folder
) as table =>
  let
    // convert the id to a postive integer for the group members endpoint
    apiResponse = Web.Contents(api[baseUri] & "/api/facilities/?query=" & Text.From(facilityGroup[facilityId]) & Text.Combine({"&", api[userAgent]}), api[options]),
    prefix = "[" & facilityGroup[name] & "] ",
    groupMembers = if Binary.Length(apiResponse) > 0 then Json.Document(apiResponse) else error Extension.LoadString("NoFacilities.Error"),

    // create the facility group and facility nodes
    facilitiesNodes = List.Accumulate(List.Select(groupMembers, (item) => item[type] <> "group_code"), {}, (list, item) => List.Combine({list, {{ item[name], item[id], Navigator.GetGroupMembers(api, item), "Folder", "Folder", false }}})),
    reportNode = {{ Text.From(facilityGroup[name]) & " " & Extension.LoadString("Reports"), Text.From(facilityGroup[facilityId]) & "_Reports", Navigator.GetReports(api, facilityGroup[facilityId], prefix), "Folder", "Folder", false }},
    nodes = List.Combine({reportNode, facilitiesNodes}),            
    
    // create the facility and facility groups folders or make an empty table stating 'No facilities found'
    tbl = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, nodes),

    nav = Table.ToNavigationTable(tbl, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
  in
    nav;

Navigator.GetGroupMembers = (   // Get a folder (navigation table) that for a specific facility
  api as record,            // The Enterprise REST API info
  facility as record        // The facility group (as a record) to be used for this folder
) as table =>
  let
    facId = facility[id],
    prefix = "[" & facility[name] & "] ",
    reportsTable = Navigator.GetReports(api, facId, prefix),
    locationsTable = Locations.GetTable(api, facId),

      reports = try if Table.RowCount(reportsTable) > 0 then
                      { Extension.LoadString("Reports"), Text.From(facId) & "_Reports", reportsTable, "Folder", "Folder", false }
                    else null
                otherwise {Extension.LoadString("NoReports.Error"), Text.From(facId) & "_Reports", reportsTable, "Table", "Table", true },

      locations = try if Table.RowCount(locationsTable) > 0 then 
                        { prefix & Extension.LoadString("Locations"), Text.From(facId) & "_Locations", locationsTable, "Table", "Table", true } 
                      else null
                  otherwise {Extension.LoadString("NoLocations.Error"), Text.From(facId) & "_Locations", locationsTable, "Table", "Table", true },

      nodes = List.RemoveNulls({reports, locations}),
            
    tbl = #table(
      {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, nodes),

    nav = Table.ToNavigationTable(tbl, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
  in
    nav;


Navigator.GetFacilities = ( // Get a folder (navigation table) that contains a dataset of all facilities and a folder for each facility
  api as record             // The Enterprise REST API info
) as table =>
  let

    // get all facilities as XLSX
    xlsx = Excel.Workbook(Binary.Buffer(Web.Contents(api[baseUri] & "/api/facilities/?f=xlsx" & Text.Combine({"&", api[userAgent]}), api[options])), true),

    // this gets the first (zero-indexed) worksheet in the workbook
    a = xlsx{0}[Data],
    
    // rename generic columns
    b = Table.RenameColumns(a, {{ "id", "facilityId" }, { "code", "facilityCode" }, { "name", "facilityName" }, { "type", "facilityType" }, { "x", "xCoord" }, { "y", "yCoord" }}),

    // add key fields
    c = Table.AddKey(b, { "facilityId" }, true),
    d = Table.AddKey(c, { "facilityCode" }, false),

    // only show the facilities with statusFlag set to 'A'
    e = Table.SelectRows(d, each [statusFlag] = "A"),

    // start with the "(Facilities)" table
    nodes = {
      { "(" & Extension.LoadString("Facilities") & ")", "__Facilities", e, "Table", "Table", true}
    },

    // now add a node for each facility
    nodes2 = List.Accumulate(Table.ToRecords(e), nodes, (list, item) => List.Combine({list, {{ item[facilityName], item[facilityId], Navigator.GetFacility(api, item), "Folder", "Folder", false }}})),

    // convert to table
    tbl = #table(
      {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, nodes2),

    // convert to navigation table
    nav = Table.ToNavigationTable(tbl, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
  in
    nav;


Navigator.GetFacility = (   // Get a folder (navigation table) that for a specific facility
  api as record,            // The Enterprise REST API info
  facility as record        // The facility (as a record) to be used for this folder
) as table =>
  let
    facId = facility[facilityId],
    prefix = "[" & facility[facilityName] & "] ",
    reportsTable = Navigator.GetReports(api, facId, prefix),
    locationsTable = Locations.GetTable(api, facId),

    //9486 - if not wrapped in "try otherwise" an error from either reportsTable or locationsTable will make them both return in error when combined into one list
      reports = try if Table.RowCount(reportsTable) > 0 then
                      { Extension.LoadString("Reports"), Text.From(facId) & "_Reports", reportsTable, "Folder", "Folder", false }
                    else null
                otherwise {Extension.LoadString("NoReports.Error"), Text.From(facId) & "_Reports", reportsTable, "Table", "Table", true },

      locations = try if Table.RowCount(locationsTable) > 0 then 
                        { prefix & Extension.LoadString("Locations"), Text.From(facId) & "_Locations", locationsTable, "Table", "Table", true } 
                      else null
                  otherwise {Extension.LoadString("NoLocations.Error"), Text.From(facId) & "_Locations", locationsTable, "Table", "Table", true },

      nodes = List.RemoveNulls({reports, locations}),
           
    tbl = #table(
      {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, nodes),

    nav = Table.ToNavigationTable(tbl, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
  in
    nav;

Navigator.GetReports = (  // Get a folder (navigation table) of report tables available to the current user at the given baseUri
  api as record,          // The Enterprise REST API info
  facId as number,        // The facilityId that will be used to run each report
  prefix as text          // The name prefix to use for each report (could be empty)
) as table =>
  let

    // an array of report objects as returned from /api/reports
    allReports = Json.Document(Binary.Buffer(Web.Contents(api[baseUri] & "/api/reports" & Text.Combine({"?", api[userAgent]}), api[options]))),

    // filter to only grid reports (check for metaData property on Report object. If metaData is populated and not equal to null, the report is an iGrid report)
    filteredReports = if facId = -1 then
                        List.Select(allReports, (item) => item[id] < 0 and not Value.Equals(item[metaData], null) and (Value.Equals(item[facilityId], null) or Value.Equals(item[facilityId], -1)))
                      else
                        List.Select(allReports, (item) => item[id] < 0 and not Value.Equals(item[metaData], null) and (Value.Equals(item[facilityId], facId) or Value.Equals(item[facilityId], null) or Value.Equals(item[facilityId], -1))),

    // create list of report tables
    reports = List.Accumulate(filteredReports, {}, (list, item) => if item[facilityId] = null then 
                                                                     List.Combine({list, {{item[name], item[id], Report.GetTable(api, item[id], facId), "Table", "Table", true }}})
                                                                   else
                                                                     List.Combine({list, {{ prefix & item[name], item[id], Report.GetTable(api, item[id], facId), "Table", "Table", true }}})),


    // convert to table
    tbl = #table({"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, reports),

    // convert to navigation table
    nav = Table.ToNavigationTable(tbl, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")

  in
    nav;

Navigator.GetReportsWithEIAs = (  // Get a folder (navigation table) of reports that contain EIAs
  api as record          // The Enterprise REST API info
) as table =>
  let

    // an array of report objects as returned from /api/reports
    reportsWithEIAs = Json.Document(Binary.Buffer(Web.Contents(api[baseUri] & "/api/reports?hasEIA=true" & Text.Combine({"&", api[userAgent]}), api[options]))),

    reports = List.Accumulate(List.Select(reportsWithEIAs, (item) => item[id] < -1), {}, (list, item) => List.Combine({list, {{ item[name], item[id], Navigator.GetEIAsForReport(api, item), "Folder", "Folder", false }}})),
    
    // convert to table
    tbl = #table({"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, reports),

    // convert to navigation table
    nav = Table.ToNavigationTable(tbl, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")

  in
    nav;

 Navigator.GetEIAsForReport = (  // Get a folder (navigation table) of the given report that will display its EIAs
  api as record,          // The Enterprise REST API info
  report as record        // The report that we will use to aqcuire the EIAs
) as table =>
  let

    // an array of eia objects as returned from /api/reports/{reportId}/eia
    eias = Json.Document(Binary.Buffer(Web.Contents(api[baseUri] & "/api/reports/" & Text.From(report[id]) & "/eia?file_type=cdt" & Text.Combine({"&", api[userAgent]}), api[options]))),
    
    eiaTables = List.Accumulate(List.Select(eias, (item) => Record.HasFields(item, "ReportEvent")), {}, (list, item) => List.Combine({list, {{ item[ReportEvent][notice_subject_ReadOnly], item[ReportEvent][id], EIA.GetTable(api, report[id], item[ReportEvent][id]), "Table", "Table", true }}})),

    // convert to table
    tbl = #table({"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, eiaTables),

    // convert to navigation table
    nav = Table.ToNavigationTable(tbl, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")

  in
    nav;

Locations.GetTable = (    // Gets the dataset/table containing locations for the given facilityId
  api as record,          // The Enterprise REST API info
  facilityId as number    // The facilityId to pass to the report (may be null
) as table =>
  let
    // get locations as XLSX
    locationsApiResponse = Web.Contents(api[baseUri] & "/api/facilities/" & Text.From(facilityId) & "/locations/?f=xlsx" & Text.Combine({"&", api[userAgent]}), api[options]),
    xlsx = if Binary.Length(locationsApiResponse) > 0 then Excel.Workbook(locationsApiResponse, true) else error Extension.LoadString("NoLocations.Error"),

    // this gets the first (zero-indexed) worksheet in the workbook
    a = xlsx{0}[Data],
    
    // rename generic columns
    b = Table.RenameColumns(a, {{ "id", "euid" }, { "code", "sysLocCode" }, { "name", "locName" }, { "type", "locType" }, { "x", "xCoord" }, { "y", "yCoord" }}),

    // add key fields
    c = Table.AddKey(b, { "facilityId", "sysLocCode" }, true),
    d = Table.AddKey(c, { "euid" }, false)

  in
    d;


Report.GetTable = (       // Gets the dataset/table for the given report from the given baseUri
  api as record,          // The Enterprise REST API info
  reportId as number,     // The reportId (aka userReportId) of the report
  facilityId as number    // The facilityId to pass to the report (may be null
) as table =>
  let
    
    // create custom api options to send the equis-filters headers if facilityId is a facility or facility group
    apiOptions = if facilityId > 0 or facilityId < -1 then
                    [Headers = Record.Combine({api[options][Headers], [ #"equis-filters" = "{facility_id:" & Text.From(facilityId) & "}"]}), Timeout=api[options][Timeout]]
                 else
                    api[options],

    // should we include the facilityId parameter?
    fac = if facilityId = -1 then "" else "&facilityId=" & Text.From(facilityId),

    // download the report output as *.csv
    csv = Csv.Document(Web.Contents(api[baseUri] & "/api/reports/" & Text.From(reportId) & "/data?oType=csv" & fac & Text.Combine({"&", api[userAgent]}), apiOptions)),

    a = Table.PromoteHeaders(csv),

    b = Table.MakeColumnsCamelCase(a)
  in
    b;

EIA.GetTable = (       // Gets the dataset/table for the given report from the given baseUri
  api as record,          // The Enterprise REST API info
  reportId as number,     // The reportId (aka userReportId) of the report
  reportEventId as number    // The facilityId to pass to the report (may be null
) as table =>
  let

    // download the report output as *.csv
    csv = Csv.Document(Web.Contents(api[baseUri] & "/api/reports/" & Text.From(reportId) & "/events/" & Text.From(reportEventId) & "/data?oType=csv" & Text.Combine({"&", api[userAgent]}), api[options])),
    
    a = Table.PromoteHeaders(csv),

    b = Table.MakeColumnsCamelCase(a)
  in
    b;


/***************************/
/***************************/
/******** Helpers **********/
Value.IfNull = (a, b) => if a <> null then a else b;


Table.MakeColumnsCamelCase = (  // Rename columns in the given table to camel case (e.g. "SYS_LOC_CODE" => "sysLocCode")
  table as table                // The input table (whose columns will be renamed)
) as table =>                   // Returns the input table with the columns renamed to camel case
  let
    columnNames = Table.ColumnNames(table),
    camelNames = List.Accumulate(columnNames, {}, (list, item) => List.Combine({ list, {{ item, Text.GetCamelCase(item) }}})),
    t = Table.RenameColumns(table, camelNames)
  in
    t;


Text.GetCamelCase = (   // Convert the given text (e.g. "SYS_LOC_CODE") to camel case (e.g. "sysLocCode")
  name as text          // The original column name to be converted to camel case
) as text =>            // The given name converted to camel case
  let
    lcase = Text.Lower(name),
    chars = Text.ToList(lcase),
    charsU = List.Accumulate(chars, {}, (list, item) => List.Combine({ list, { Text.UpperAfterUnderScore(list, item)}})),
    camel_ = Text.Combine(charsU),
    camel = Text.Replace(camel_, "_", "")
  in
    camel;


Text.UpperAfterUnderScore = ( // If the last character in the list is an underscore, return the given character as upper case; else just return the character.
  list as list,               // The input list of characters
  ch as text                  // The character to be returned
) as text =>
  let
    txt = if List.Count(list) = 0 then
            ch
          else if list{List.Count(list)-1} = "_" then
            Text.Upper(ch)
          else
            ch
  in
    txt;


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