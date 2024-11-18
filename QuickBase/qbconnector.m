/*
    Quickbase Connector Version 1.3.1 (Beta)
    Date created: 1 Sep 2018
    Last Updated: 27 DEC 2022

**/
[Version = "1.4.0"]
section QuickBase;

[DataSource.Kind="QuickBase", Publish="QuickBase.Publish"]
shared QuickBase.Contents = Value.ReplaceType(qbconnectorImpl, qbconnectorType);
qbconnector.UserAgent = Extension.LoadString("UserAgent");
qbconnector.ContentType = Extension.LoadString("ContentType");
qbconnector.BaseUrl = Extension.LoadString("BaseUrl");

qbconnectorType = type function (
 /* code for fields meta data
  here defining fields type , caption , discription and sample values. **/
    url as (Uri.Type meta [// create text field 
        Documentation.FieldCaption = Extension.LoadString("UrlFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("UrlFieldDescription"),
        Documentation.SampleValues = {Extension.LoadString("UrlFieldSampleValues")}
    ]))as table meta [
        Documentation.Name = Extension.LoadString("TableName"),
        Documentation.LongDescription = Extension.LoadString("TableLongDescription")
    ];

/*Accept url , validate url and key, connect with quickase, fetch data and show table.*/
qbconnectorImpl = (url as text) =>
    let
        // getting data from Credentials
        _url  = ValidateUrlScheme(url),
        Credential = Extension.CurrentCredential(),
        //key = Credential[Key],
         key = if (Credential[AuthenticationKind] = "Key") then Credential[Key] else Credential[access_token], 
        // target to fetch schema from Quickbase for DB.
        splitUrl = Text.Split(_url as text, ".quickbase.com/db/" as text) as list,
        dbSchema = try Json.Document(Web.Contents(qbconnector.BaseUrl&"tables?appId="&splitUrl{1}, [Headers=[#"Content-Type"=qbconnector.ContentType, #"QB-Realm-Hostname"= Text.Replace(splitUrl{0}, "https://", ""), #"USER-AGENT"= qbconnector.UserAgent, Authorization="QB-USER-TOKEN "&key]])),
        // checking for error if any from response.
        errorCode = if (dbSchema[HasError] = false) and (Value.Type(dbSchema[Value]) = type list) then "0" else "1", 
        result = if(errorCode = "0") then 
                // drill down to Table ids getiing table nd pass to function.
                qbconnector.CreateNavTableFirst(dbSchema, _url, key, Text.Replace(splitUrl{0}, "https://", "")) 
             else 
                (error Error.Record("Error", "Authentication Fail with error: " & dbSchema[Error][Message]))
                
    in
        result;

Value.WaitFor = (producer as function, interval as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, null},
            (state) => state{0} <> null and (count = null or state{0} < count),
            (state) => if state{1} <> null
                then {null, state{1}}
                else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), interval(state{0}))},
            (state) => state{1})
    in
        List.Last(list);

retry = (url, options) =>
    let
        waitForResult = Value.WaitFor(
            (i) =>
                let
                    options2 = if options = null then [] else options,
                    options3 = if i=0 then options2 else options2 & [IsRetry= true],
                    result = Web.Contents(url, options3 & [ManualStatusHandling = {429, 500}]),
                    buffered = Binary.Buffer(result),
                    status =  Value.Metadata(result)[Response.Status],
                    actualResult = if status = 429 then null else {status, buffered}
                in
                    actualResult,
            (i) => #duration(0, 0, 0, .5))
            
    in
        if waitForResult = null then
                error "Value.WaitFor() Failed after multiple retry attempts"
            else
                waitForResult;

/*
Block setting data to create Navtable schema, and creating Nav table.
    dbTablesInfo  = Quickbase db schema.
    realm = Quickbase subdomain.
    token = Key for Authentication.
    returns navtable.
*/
qbconnector.CreateNavTableFirst = (dbTablesInfo, url, token, realm) =>
    let
        tablesSchemaList = List.Buffer(List.Transform(dbTablesInfo[Value], each qbconnector.CreateNavTableWithFunction(realm, _, token))),
        tablesSchema = List.Select(tablesSchemaList, each _{2} <> null ),
       //creating Nav table
        tableTableStructure = #table({"Name",       "Key",        "Data",  "ItemKind", "ItemName", "IsLeaf"}, tablesSchema),
        navTable = Table.ToNavigationTable(tableTableStructure, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;
       
/*
Block fetching data as per selected table from NavTable.
    realm = Quickbase subdomain.
    table = Quickbase table.
    token = Key for Authentication.
    returns schema for nav table.
*/
qbconnector.CreateNavTableWithFunction = (realm, table, token) =>
    let
        //responseObject = Web.Contents(qbconnector.BaseUrl&"reports?tableId="&table[id], [Headers=[#"Content-Type"=qbconnector.ContentType, #"QB-Realm-Hostname"= realm, #"USER-AGENT"= qbconnector.UserAgent, Authorization="QB-USER-TOKEN "&token]]),
        responseObject = retry(qbconnector.BaseUrl&"reports?tableId="&table[id], [Headers=[#"Content-Type"=qbconnector.ContentType, #"QB-Realm-Hostname"= realm, #"USER-AGENT"= qbconnector.UserAgent, Authorization="QB-USER-TOKEN "&token]]),
        //responseObject = fxRetry(qbconnector.BaseUrl&"reports?tableId="&table[id], [Headers=[#"Content-Type"=qbconnector.ContentType, #"QB-Realm-Hostname"= realm, #"USER-AGENT"= qbconnector.UserAgent, Authorization="QB-USER-TOKEN "&token]]),
        //getting name from table
        name = table[name],
        //result = if(responseObject[HasError] = false) then
           // let
                //response = responseObject[Value],
                response = responseObject,
               // responseMetadata = Value.Metadata(response),
                responseCode = response{0},
            //
                
                //errorCode = if (reports[HasError] = false) and (Value.Type(reports[Value]) = type list) then "0" else "1",
                result =  if (responseCode = 200) then 
                  let
                    reports = try Json.Document(response{1}),
                   // reportsList = {name, table[id], reports, "ItemKind", "ItemName", false}
                    reportsList = {name, table[id], qbconnector.CreateNavTableSecond(reports[Value], realm, table, token), "ItemKind", "ItemName", false}
                  in
                    reportsList
                 else 
                    {name, table[id], #table({"Name",       "Key",        "Data",  "ItemKind", "ItemName", "IsLeaf"}, {}), "ItemKind", "ItemName", false}
            //in
                //result
        //else
            //{name, table[id], null, "ItemKind", "ItemName", false}

    in
        result;
       
/*
Block to filter reports.
    reports = Quickbase reports for one Quickbase table.
    realm = Quickbase subdomain.
    table = Quickbase table.
    token = Key for Authentication.
    
*/
qbconnector.CreateNavTableSecond = (reports, realm, table, token) =>
    let
       // filter reports where type = table and Ignore reports where any of the "qycrit" contains "_ask1_." 
       queriesOnlyTable = List.Select(reports, each
                                                        let
                                                            // some time clist and querys are blank so adding custom to handle ask query
                                                            tableExist = ([type] = "table"),
                                                            // checking qyclst qycrit fields in repord or not if not creating nodes
                                                            isqyclst = Record.HasFields(_[query],{"fields"}),
                                                            isqycrit = Record.HasFields(_[query],{"filter"}),
                                                            qyclst = if((isqyclst = false) or ( isqyclst and (List.IsEmpty(_[query][fields]) = 0))) then "" else Text.Combine(_[query][fields], ".") ,                                                       
                                                            qycrit = if((isqycrit = false) or ( isqycrit and (_[query][filter] = null))) then "({3.XEX.0})" else _[query][filter] ,
                                                            // checking for ask word in crit
                                                            containAsk = Text.Contains(qycrit, "_ask1_"),
                                                            qycritask = if((containAsk = false)) then true else false,

                                                            lastResult = if(tableExist and qycritask and Number.FromText(_[id]) <= 1000000 ) then true else false
                                                        in
                                                            lastResult
                                                            ),

                                                        
                                                            
       name = table[name],
       tablesSchema = List.Transform(queriesOnlyTable, each qbconnector.CreateQueryNavTable(_, name, realm, table, token)),
       //creating Nav table
       tableTableStructure = #table({"Name",       "Key",        "Data",  "ItemKind", "ItemName", "IsLeaf"}, tablesSchema),
       navTable = Table.ToNavigationTable(tableTableStructure, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

/*
Block to create name for reports for left part of Nav table.
    query = query for single report.
    name = Quickbase table name.
    realm = Quickbase subdomain.
    table = Quickbase table.
    token = Key for Authentication.
*/
qbconnector.CreateQueryNavTable = (query, name, realm, table, token) =>
    let
        //just concatination of reports names
        qName = name & "_" & query[name],
        qid = query[id]

    in
        {qName, qid, qbconnector.CreateTable(qid, query, realm, table, token), "ItemKind", "ItemName", true};


/*/
    Block to handle reports, its fields values, to arrage so can use to create navtable.
    query = query for single report.
    qid = Quickbase report id.
    realm = Quickbase subdomain.
    table = Quickbase table.
    token = Key for Authentication.
**/
qbconnector.CreateTable = (qid, query, realm, table, token) => 
    let
        url = qbconnector.BaseUrl&"reports/"&qid&"/run?tableId="&table[id],
        reportsUrl = url&"&skip=0"&"&top=1",
        headers = [Headers=[#"Content-Type"=qbconnector.ContentType, #"QB-Realm-Hostname"= realm, #"USER-AGENT"= qbconnector.UserAgent, Authorization="QB-USER-TOKEN "&token],Content = Text.ToBinary("")],
        //responseObject = Web.Contents(reportsUrl, headers),
        responseObject = retry(reportsUrl, headers),
        //responseMetadata = Value.Metadata(responseObject),
        responseCode = responseObject{0},
        
       // result = if (response[HasError] = false and (Record.HasFields(response[Value], {"data"}))) then
       result = if (responseCode = 200) then
                            let
                              response =  Json.Document(responseObject{1}),
                             // response = response[Value],
                              records = response[data],
                              //
                              allowedFields = {"float","duration","currency","recordid", "user", "date", "checkbox", "phone", "email", "multiuser", "multitext", "address", "predecessor", "text", "text-multiple-choice", "text-multi-line", "timestamp", "numeric", "checkbox", "timeofday", "percent", "rich-text", "url"},
                              //Response fields that want to skip 
                              skipfields = List.Select(response[fields], each List.Contains(allowedFields, _[type]) = false ),
                              //Response String its for Fields
                              skipfieldsIds = List.Transform(skipfields, each Text.From(_[id]) ),
                              // Fields after rename fields
                              fields = RenameDublicateColumnName(response, skipfieldsIds),
                              defaultfieldIds = List.Transform(fields,each Text.From(_[id])),

                              metadata = response[metadata],
                              // getting list of fields
                              tableNameandFields = qbconnector.GetTableNameandFieldlist(table, fields),
                                    Pages = if List.IsEmpty(response[data])  then #table(defaultfieldIds, {}) else
                                                                                    let
                                                                                        PagesTable = GetAllPagesByNextLink(url, url&"&skip=0"&"&top=9999999999", headers ),
                                                                                        PagesafterSkip =Table.RemoveColumns(PagesTable, skipfieldsIds, MissingField.Ignore ),
                                                                                        Pages = Table.ReorderColumns(PagesafterSkip, defaultfieldIds )
                                                                                    in
                                                                                        Pages,
                                    data = qbconnector.DataManupulation(tableNameandFields, Pages, fields, defaultfieldIds)
                              
                            in
                                data{2}
                else
                    //(error Error.Record("Error", "Error during fetching reports: " & response[Error][Message])) 
                    null
    in     
       result;      
 
 
 /*Code to handle dublicate fields in reports*/
 RenameDublicateColumnName = (response, skipfieldsIds) as nullable list => 
     let
        fields = List.Select(response[fields], each List.Contains(skipfieldsIds, Text.From(_[id])) = false),
        fieldsWithDublicateColumn = List.Transform(fields, each Record.FromList({_[id], _[label], _[type]}, {"id", "label", "type"})),
        //fieldsWithDublicateColumn = response[fields],
        // Fields as table to rename dublicate column names
        fieldsTable = Table.FromList(fieldsWithDublicateColumn, Record.FieldValues, {"id", "label1", "type"}, null, ExtraValues.Error),
        #"Grouped Rows" = Table.Group(#"fieldsTable", {"label1"}, {{"Count", each Table.RowCount(_), type number}, {"Partition", each Table.AddIndexColumn(_, "CountMultiple",0,1), type table}}),
        #"Expanded Partition" = Table.ExpandTableColumn(#"Grouped Rows", "Partition", {"id", "type", "CountMultiple"}, {"id", "type", "CountMultiple"}),
        #"Expanded Partition Text Column" = Table.TransformColumnTypes(#"Expanded Partition",{{"CountMultiple", type text}}),
        #"Added Custom" = Table.AddColumn(#"Expanded Partition Text Column", "label", each if [CountMultiple] = "0" then [label1] else [label1] & "_dub_c_" & [CountMultiple]),
        // Code end to rename dublicate column names
        // Fields as string after rename dublicate column
        prefields = Table.ToRecords( #"Added Custom")
     in
        prefields;

 
 /*Block to generate next page for pagging*/
 GetNextLink = (url, response) as nullable text => 
        let
            metaData = Record.FieldOrDefault(response, "metadata"),
            lastSkip = Record.FieldOrDefault(metaData, "skip"),
            lastRecordsNum = Record.FieldOrDefault(metaData, "numRecords"),
            totalRecords = Record.FieldOrDefault(metaData, "totalRecords"),
            skip  =  Text.From(Number.From(lastSkip) + Number.From(lastRecordsNum)) ,
            leftRecords = Number.From(totalRecords) - Number.From(skip),
            url = if leftRecords = 0 then null else url&"&skip="&skip&"&top="&Text.From(leftRecords)
        in
         url;

GetAllPagesByNextLink = (baseUrl, url as text, headers) as table =>
    Table.GenerateByPage((previous) => 
        let
            // if previous is null, then this is our first page of data
            nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
            // if NextLink was set to null by the previous call, we know we have no more data
            page = if (nextLink <> null) then GetPages(baseUrl, nextLink, headers) else null
        in
            page
    );

/*Block to call pages*/
GetPages = (baseUrl, url as text, headers) as table =>
    let
        response = Web.Contents(url, headers),        
        body = Json.Document(response),
        nextLink = GetNextLink(baseUrl, body),
        data = Table.FromRecords(body[data])
    in
        data meta [NextLink = nextLink];

 /*Code to hangle table name, and data*/
 qbconnector.GetTableNameandFieldlist = (table, fields) => 
      let
        //getting table name
        tableName = table[name], 
        // getting fields
        filedsTable = fields,
        // from fields table creating list to define types
        listFields = List.Transform(filedsTable, each qbconnector.DefineType(_[type], _[label]) ),
        ToValue = (record) => 
            let
                recordvalue = record[value],
                value = if(recordvalue is record) then
                            getRecordValue(recordvalue)
                        else if(recordvalue is list) then
                            let
                                innerrecords = List.Transform(recordvalue, each getRecordValue(_)),
                                value = Lines.ToText(innerrecords, "
")      
                            in
                                value
                        else
                            recordvalue
            in
                value,
        extracted = List.Transform(filedsTable, each qbconnector.ExtractValue(_[type], _[label], ToValue) ),
        // code to covert miliseconds to date
        ToDate = (value) => if value = null then null else (#datetime(1970, 1, 1, 0, 0, 0) + #duration(0, 0, 0, Number.FromText(value)/1000)),
       // creating list to change 
        listDateFields = List.Transform(filedsTable, each qbconnector.ChangeType(_[type], _[label], ToDate) ),
        // getting labels
        fieldsList = List.Transform(filedsTable, each _[label])
      in
        Record.FromList({tableName, fieldsList, listDateFields, listFields, extracted} as list, {"name", "fieldsList", "listDateFields", "listFields", "extracted"} as any) as record ;
 
  
  /*Block used to manage data so we can use as per Power BI requirement*/
  qbconnector.DataManupulation = (tableNameandFields, tableData, fields, fieldIds) => 
      let
        fieldtable= Table.TransformColumnTypes(Table.FromList(fieldIds, Splitter.SplitByNothing(), null, null, ExtraValues.Error),{{"Column1", type text}}),
        fieldListIndex = Table.AddIndexColumn(fieldtable, "Index"),
        fieldListwithIndx = Table.AddColumn(fieldListIndex , "label", each tableNameandFields[fieldsList]{[Index]}),
        fieldListwithoutIndx = Table.RemoveColumns(fieldListwithIndx,{"Index"}),
        fieldList = Table.TransformRows(fieldListwithoutIndx , each {_[Column1], _[label]}),
        newTableData = Table.RenameColumns(tableData, fieldList),
        // changing date fields
        databeforeDateChange = Table.TransformColumns(newTableData, tableNameandFields[extracted]),
        dateAfterDateChange = Table.TransformColumns(databeforeDateChange, tableNameandFields[listDateFields]),
        // changing types
        changeTablesType = Table.TransformColumnTypes(dateAfterDateChange,tableNameandFields[listFields])
      in
          {newTableData, tableNameandFields[listFields],changeTablesType, tableNameandFields[listDateFields], dateAfterDateChange};
 

/*Data coming as record we checking record containg name, email or url and extracting accordingly*/
getRecordValue = (recordvalue) =>
     if(recordvalue is record) then
         if(Record.HasFields(recordvalue, "name")) then
            recordvalue[name]
         else if(Record.HasFields(recordvalue, "email")) then    
            recordvalue[email]
         else if(Record.HasFields(recordvalue, "url")) then    
            recordvalue[url]
         else
            ""
     else
       recordvalue;
 // code to check and define datatypes, code for setting data type for columns
 /* Block used to map data Type of Power BI with Quickbase*/
qbconnector.DefineType = (dataType, label) =>
    let
            dataValue =  	if dataType  = "text" then
                        	{label, type text}
                    	else if dataType  = "float" then
                        	{label, type number}
                        else if dataType  = "recordid" then
                        	{label, Int64.Type}
                        else if dataType  = "currency" then
                        	{label, Currency.Type}
                        else if dataType  = "checkbox" then
                        	{label, type logical}
                        else if dataType  = "timestamp" then
                        	{label, type datetime}
                        else if dataType  = "date" then
                        	{label, type date}
                        else if dataType  = "duration" then
                        	//{label, type duration}
                            {label, type number}
                        else if dataType  = "numeric" then
                        	//{label, type duration}
                            {label, type number}
                        else
                        	{label, type text}
    in
        dataValue;
        
/* define code to change miliseconds to dates, this function used to manipulates data as per fields type like millisec to date, integer to bool etc */
qbconnector.ChangeType = (dataType, label, ToDate) =>
    let
        skipElse = (value) => if value = null then null else value,
        ToDuration = (value) => if value = null then null else Number.Round(value/(3600000), 2),  
        ToFloat= (value) => if value = null then null else Number.Round(value, 2),
        changablelist = if dataType  = "duration" then
                        	{label, ToDuration}
                        else if dataType  = "float" then
                        	{label, ToFloat}
                        else
                            {label, skipElse}
    in
        changablelist;


/* Block to extract fields values from data that havig value as record type*/
qbconnector.ExtractValue = (dataType, label, ToValue) =>
    {label, ToValue};
        

/* Checking url entered with http or https , it should be https*/
ValidateUrlScheme = (url as text) as text => if (Uri.Parts(url)[Scheme] <> "https") then error "Url scheme must be HTTPS" else url;


// Data Source Kind description
/* Block to define Authentication type. */
QuickBase = [
    TestConnection = (dataSourcePath) =>{ "QuickBase.Contents", dataSourcePath },
    Authentication = [
           Key = [
            KeyLabel = "User Token",
            Label = "Usertoken"
           ]
    ],
    Label = "Quickbase"
];

// Data Source UI publishing description.
QuickBase.Publish = [
    Beta = false,
    Category = "Online Services",
    ButtonText = { "Quickbase", "The Quickbase Power BI Connector enables Power BI users to pull Quickbase data into their models, using the friendly, native Power BI table navigator experience! The connector was developed with the Quickbase no code/low code community in mind; allowing users to design reports in Quickbase. These reports can then be consumed directly in Power BI."  },
    LearnMoreUrl = "https://quickbase.com",
    SourceImage = qbconnector.Icons,
    SourceTypeImage = qbconnector.Icons
];

qbconnector.Icons = [
    Icon16 = { Extension.Contents("qbconnector16.png"), Extension.Contents("qbconnector20.png"), Extension.Contents("qbconnector24.png"), Extension.Contents("qbconnector32.png") },
    Icon32 = { Extension.Contents("qbconnector32.png"), Extension.Contents("qbconnector40.png"), Extension.Contents("qbconnector48.png"), Extension.Contents("qbconnector64.png") }
];


// Common library code.
/* InBuild power bi function to create navigation table. */
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


/* The getNextPage function takes a single argument and is expected to return a nullable table, inbuild function to handle pagging. */
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

