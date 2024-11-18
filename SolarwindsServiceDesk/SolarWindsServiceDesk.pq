[Version = "1.1.2"]
section SolarWindsServiceDesk;
AllColumns = Json.Document(Extension.Contents("Columns.json"));

[DataSource.Kind="SolarWindsServiceDesk"]
shared SolarWindsServiceDesk.Contents = SolarWindsServiceDesk.Navigation;

[DataSource.Kind="SolarWindsServiceDesk", Publish="SolarWindsServiceDesk.Publish"]
shared SolarWindsServiceDesk.ContentsV110 = SolarWindsServiceDesk.NavigationV110;

SolarWindsServiceDesk.Navigation = () =>
    let
        version = "1.0.0",
        today = DateTime.LocalNow(),
        getTwoYearsIncidents = SolarWindsServiceDeskImpl(version, "incidents", Date.AddYears(today, -2), today),
        source = #table({"Name", "Data", "ItemKind", "ItemName", "IsLeaf"}, {            
                { "Incidents", getTwoYearsIncidents, "Table", "Table", true }            
            }),
        navTable = Table.ToNavigationTable(source, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

SolarWindsServiceDesk.NavigationV110 = (optional RangeStart as datetime, optional RangeEnd as datetime) =>
    if (RangeStart <> null and RangeEnd <> null and RangeStart >= RangeEnd) then error Extension.LoadString("ErrorInvalidRange")
    else if (RangeStart <> null and RangeEnd <> null and Duration.Days(RangeEnd - RangeStart) > 365*2) then error Extension.LoadString("ErrorLimitRangeMessage") // 2 years limit
    else 
    let
        version = "1.1.2",
        objects =  #table({"Name", "Data", "ItemKind", "ItemName", "IsLeaf"}, {            
                { "Incidents", SolarWindsServiceDeskImpl(version, "incidents", RangeStart, RangeEnd), "Table", "Table", true }
        }),
        assets = #table({"Name", "Data", "ItemKind", "ItemName", "IsLeaf"}, {
            { "Hardwares", SolarWindsServiceDeskImpl(version, "hardwares", RangeStart, RangeEnd), "Table", "Table", true },
            { "Softwares", SolarWindsServiceDeskImpl(version, "softwares", RangeStart, RangeEnd), "Table", "Table", true },
            { "Mobiles", SolarWindsServiceDeskImpl(version, "mobiles", RangeStart, RangeEnd), "Table", "Table", true },
            { "Printers", SolarWindsServiceDeskImpl(version, "printers", RangeStart, RangeEnd), "Table", "Table", true },
            { "Network Devices", SolarWindsServiceDeskImpl(version, "discovery_hardwares", RangeStart, RangeEnd), "Table", "Table", true },
            { "Other Assets", SolarWindsServiceDeskImpl(version, "other_assets", RangeStart, RangeEnd), "Table", "Table", true }
        }),
        objectsFolder = Table.ToNavigationTable(objects, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf"),     
        assetsFolder = Table.ToNavigationTable(assets, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf"),
        source = #table({"Name", "Data", "ItemKind", "ItemName", "IsLeaf"}, {            
                { "All Objects", objectsFolder, "Folder", "Folder", false },
                { "Assets", assetsFolder, "Folder", "Folder", false }                            
            }),
        navTable = Table.ToNavigationTable(source, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

SolarWindsServiceDeskImpl = (version as text, dataType as text, optional RangeStart as datetime, optional RangeEnd as datetime) as table =>
    let
        today = DateTime.LocalNow(),
        startDate = if RangeStart = null then DateTime.ToText(Date.AddMonths(today, -1), Extension.LoadString("DateFormat")) else DateTime.ToText(RangeStart, Extension.LoadString("DateFormat")),
        endDate = if RangeEnd = null then DateTime.ToText(today, Extension.LoadString("DateFormat")) else DateTime.ToText(RangeEnd, Extension.LoadString("DateFormat")),
        tracedStartDate = Diagnostics.Trace(TraceLevel.Information, GetTraceData(version, dataType, startDate, endDate), () =>  startDate, true),
        rows = try GetAllPagesByNextLink(version, tracedStartDate, endDate, dataType),
        result = if rows[HasError] then error Extension.LoadString("ErrorMessage") else rows[Value]
    in
        result;

// extract the suffix of the token and decode to get the region and return the relvant domian of that region
GetDomain = (tokenValue as text) as nullable text =>
    let
        key = tokenValue,
        splittedToken = Text.Split(key, ":"),
        regionEncoded = List.Last(splittedToken),
        regionDecoded = try Lines.FromBinary(Binary.FromText(regionEncoded,BinaryEncoding.Base64), null, null, 1252){0}
    in
         // json web token must be build from 3 parts if there is below 3 must return error
        if List.Count(splittedToken) < 3 or regionDecoded[HasError] then
            error Extension.LoadString("InvalidTokenError")
        else
            (if (Value.Equals(regionDecoded[Value], "EU")) then
                Extension.LoadString("UrlEU")
            else if (Value.Equals(regionDecoded[Value], "AU")) then
                Extension.LoadString("UrlAU")
            else
                Extension.LoadString("UrlUS"));


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

// Read all pages of data.
// After every page, we check the "NextPageNumber" on the metadata of the previous request.
// Table.GenerateByPage will keep asking for more pages until we return null.
GetAllPagesByNextLink = (version as text, startDate as text, endDate as text, dataType as text) as table =>
    Table.GenerateByPage((previousPageNumber) =>
        let
            // if previous is null, then this is our first page of data
            nextPageNumber = if (previousPageNumber = null) then 1 else Value.Metadata(previousPageNumber)[NextPageNumber]?,

            // if NextLink was set to null by the previous call, we know we have no more data
            page = if (nextPageNumber <> null) then GetPage(version, nextPageNumber, startDate, endDate, dataType) else null
        in
            page
    );

GetQuery = (currentPage as number, startDate as text, endDate as text) =>
    let
        common = [page = Text.From(currentPage) ],
        query = [ updated = "Select Date Range", updated_custom_gte = startDate, updated_custom_lt = endDate ]
    in
       query & common;

GetTraceData = (version, dataType, startDate, endDate) as text => "Use Version: " & version & " Get from " & dataType & " created between dates - " & startDate & " - " & endDate ;

GetPage = (version as text, currentPage as number, startDate as text, endDate as text, dataType as text) as table =>
    let
        dataTypeColumns = Record.Field(AllColumns, dataType),
        key =  Extension.CurrentCredential()[Key],
        headers = [
            #"X-Samanage-Authorization" = "Bearer " & key,
            Accept = Extension.LoadString("Accept"),
            #"Content-Type" = Extension.LoadString("ContentType"),
            #"Client-Version" = version
        ],
        url = Diagnostics.Trace(TraceLevel.Information, GetTraceData(version, dataType, startDate, endDate) & " page number " & Text.From(currentPage), () => GetDomain(key), true),
        response = Web.Contents(url, [ Headers = headers, RelativePath = dataType & ".json", Query = GetQuery(currentPage, startDate, endDate) ]),
        body = Json.Document(response),
        result_under_one_column = Table.FromList(body, Splitter.SplitByNothing(), {"Column1"}, null, ExtraValues.Error),
        page = Table.ExpandRecordColumn(result_under_one_column, "Column1", dataTypeColumns, dataTypeColumns),
        page_with_nextPageNumber = page meta [NextPageNumber =  GetNextPageNumber(response)]
    in
        page_with_nextPageNumber;

// In this implementation, 'response' will be the parsed body of the response after the call to Json.Document.
// Look for pages fields to get the next page number
GetNextPageNumber = (response) as nullable number =>
    let
        response_headers = Value.Metadata(response)[Headers],
        current_page = Record.Field(response_headers, "X-Current-Page"),
        total_pages = Record.Field(response_headers, "X-Total-Pages"),
        current_page_number = Number.FromText(current_page),
        next_page_number = current_page_number + 1,
        total_pages_number = Number.FromText(total_pages),
        result = if (next_page_number <= total_pages_number) then next_page_number else null
    in
        if (result <> null) then result else null;


// format static table into something that Power Query will recognize as a Navigation Table
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
SolarWindsServiceDesk = [
    TestConnection = (dataSourcePath) => { "SolarWindsServiceDesk.Contents" },
    Authentication = [
       Key = [
            KeyLabel =  Extension.LoadString("TokenLabel"), Label = Extension.LoadString("TokenValue")
       ]
    ],
    Label = Extension.LoadString("ConnectorName")
];

// Data Source UI publishing description
SolarWindsServiceDesk.Publish = [
    Category = "Other",
    ButtonText = { Extension.LoadString("ConnectorName"), Extension.LoadString("ConnectorTooltip") },
    LearnMoreUrl = Extension.LoadString("LearnMoreUrl"),
    SourceImage = SolarWindsServiceDesk.Icons,
    SourceTypeImage = SolarWindsServiceDesk.Icons
];

SolarWindsServiceDesk.Icons = [
    Icon16 = { Extension.Contents("SWSD_16.png"), Extension.Contents("SWSD_20.png"), Extension.Contents("SWSD_24.png"), Extension.Contents("SWSD_32.png") },
    Icon32 = { Extension.Contents("SWSD_32.png"), Extension.Contents("SWSD_40.png"), Extension.Contents("SWSD_48.png"), Extension.Contents("SWSD_64.png") }
];
