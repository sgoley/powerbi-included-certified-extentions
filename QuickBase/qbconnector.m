/*
    Quick Base Connector Version 1.1.0 (Beta)
    Date created: 1 Sep 2018
    Last Updated: 27 Feb 2019

**/
[Version = "1.1.1"]
section QuickBase;

[DataSource.Kind="QuickBase", Publish="QuickBase.Publish"]
shared QuickBase.Contents = Value.ReplaceType(qbconnectorImpl, qbconnectorType);
qbconnector.UserAgent = Extension.LoadString("UserAgent");
qbconnector.ContentType = Extension.LoadString("ContentType");

qbconnectorType = type function (
 // code for fields meta data
 // here defining fields type , caption , discription and sample values
    url as (Uri.Type meta [// create text field 
        Documentation.FieldCaption = Extension.LoadString("UrlFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("UrlFieldDescription"),
        Documentation.SampleValues = {Extension.LoadString("UrlFieldSampleValues")}
    ]))as table meta [
        Documentation.Name = Extension.LoadString("TableName"),
        Documentation.LongDescription = Extension.LoadString("TableLongDescription")
    ];


qbconnectorImpl = (url as text) =>
    let
        // getting data from Credentials
        _url  = ValidateUrlScheme(url),
        Credential = Extension.CurrentCredential(),
        key = Credential[Key],
        // target to fetch schema from Quickbase for DB
        body = Text.ToBinary("<qdbapi><usertoken>"&key&"</usertoken></qdbapi>"),
        //content used to make call , Return binary 
        dbSchema = Xml.Tables(Text.FromBinary(Web.Contents(_url,[Headers=[#"Content-Type"= qbconnector.ContentType, #"QUICKBASE-ACTION"="API_GetSchema", #"USER-AGENT"= qbconnector.UserAgent ], Content=body]))),
        // checking for error if any from response
        errorCode = dbSchema{0}[errcode], 
        result = if(errorCode = "0") then 
                // drill down to Table ids getiing table nd pass to function
                qbconnector.CreateNavTableFirst(dbSchema{0}[table]{0}[chdbids]{0}[chdbid], _url, key) 
             else 
                (error Error.Record("Error", "Authentication Fail with error: " & dbSchema{0}[errdetail]))
                
    in
        result;

qbconnector.CreateNavTableFirst = (dbTablesInfo, url, token) =>
    let
        splitUrl = Text.Split(url as text, "db" as text) as list,
        realm = splitUrl{0} & "db/",
       // load use to check we need to fetch limited code or full
        tablesSchema = List.Buffer(Table.TransformRows(dbTablesInfo, each qbconnector.CreateNavTableWithFunction(realm, _[#"Element:Text"], token))),
       //creating Nav table
        tableTableStructure = #table({"Name",       "Key",        "Data",  "ItemKind", "ItemName", "IsLeaf"}, tablesSchema),
        navTable = Table.ToNavigationTable(tableTableStructure, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;
       

qbconnector.CreateNavTableWithFunction = (realm, dbId, token) =>
    let
        url = realm & dbId,
        body = Text.ToBinary("<qdbapi><usertoken>"&token&"</usertoken></qdbapi>"),
        response = qbconnector.PostXmlRequest(url, "API_GetSchema", body),
        //getting table from xml
        table = response[xml][table],
        //getting name from table
        name = table{0}[name]
    in
        {name, dbId, qbconnector.CreateNavTableSecond(response, realm, dbId, token), "ItemKind", "ItemName", false};
       

qbconnector.CreateNavTableSecond = (response, realm, dbId, token) =>
    let
        //getting table from xml
       table = response[xml][table],
       //getting queries from table
       queries = table{0}[queries]{0}[query],
       // filter reports where type = table and Ignore reports where any of the "qycrit" contains "_ask1_" 
       queriesOnlyTable = Table.SelectRows(queries, each
                                                        let
                                                            // some time clist and querys are blank so adding custom to handle ask query
                                                            tableExist = ([qytype] = "table"),
                                                            // checking qyclst qycrit fields in repord or not if not creating nodes
                                                            isqyclst = Record.HasFields(_,{"qyclst"}),
                                                            isqycrit = Record.HasFields(_,{"qycrit"}),
                                                            qyclst = if((isqyclst = false) or ( isqyclst and (_[qyclst] = null))) then "" else _[qyclst] ,                                                       
                                                            qycrit = if((isqycrit = false) or ( isqycrit and (_[qycrit] = null))) then "({3.XEX.0})" else _[qycrit] ,
                                                            // checking for ask word in crit
                                                            containAsk = Text.Contains(qycrit, "_ask1_"),
                                                            qycritask = if((containAsk = false)) then true else false,
                                                            lastResult = if(tableExist and qycritask) then true else false
                                                        in
                                                            lastResult
                                                            ),

                                                        
                                                            
       name = table{0}[name],
       tablesSchema = Table.TransformRows(queriesOnlyTable, each qbconnector.CreateQueryNavTable(_, name, realm, dbId, token)),
       //creating Nav table
       tableTableStructure = #table({"Name",       "Key",        "Data",  "ItemKind", "ItemName", "IsLeaf"}, tablesSchema),
       navTable = Table.ToNavigationTable(tableTableStructure, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;
qbconnector.CreateQueryNavTable = (query, name, realm, dbId, token) =>
    let
        //just concatination of reports names
        qName = name & "_" & query[qyname],
        qid = query[#"Attribute:id"]

    in
        {qName, qid, qbconnector.CreateTableSecond(qName, qid, query, realm, dbId, token), "ItemKind", "ItemName", true};


qbconnector.CreateTableSecond = (qName, qid, query, realm, dbId, token) =>
    let
        url = realm & dbId,
        body = "<qdbapi><usertoken>"&token&"</usertoken><qid>"&qid&"</qid>",
        data = qbconnector.CreateTable(url, body)
        
    in
        data;


qbconnector.CreateTable = (url, body) => 
    let
        // building url for call
        // Using PostXmlRequest function, whose work to make call to Quicbase services and provide response and error code,
        fullbody = Text.ToBinary(body&"<fmt>structured</fmt></qdbapi>"),
        response = qbconnector.PostXmlRequest(url, "API_DoQuery", fullbody),
        //getting error code
        errorCode = response[code],
        /*/
            1. Cheking for error code if 0 work normally if 75 make 1 call to get count of data, 
            2  Call to check tables fields and name, and many calls to get data in division of 1500. 
            3. Getting table from response
            4. Calling getTableNameandFieldlist function to fetch table name and fields list
            5. Calling tableData function to get data of table from response
            6. Calling dataManupulation function to change table types and date manupulation.
            7. Using PostXmlRequest function, whose work to make call to Quicbase services and provide response and error code,
       **/
        result = if(errorCode = "0") then
                    let
                        table = response[xml][table],
                        tableData = qbconnector.TableData(table),
                        //checking table is empty or not
                        data = if(Table.IsEmpty(tableData) = false) then
                                let
                                    // getting list of fields
                                    tableNameandFields = qbconnector.GetTableNameandFieldlist(response, table),
                                     // getting manupuralted data after change in dates
                                    data = qbconnector.DataManupulation(tableNameandFields, tableData)
                                in
                                    data{2}
                                else
                                    tableData
                    in
                        data
                       
                 else if(errorCode = "75") then 
                    let
                        // Code to concate string and making url
                        // getting response for Count query and giving count.
                        fullbody = Text.ToBinary(body&"<fmt>structured</fmt></qdbapi>"),
                        countResponse = qbconnector.PostXmlRequest(url, "API_DoQueryCount", fullbody),
                        // Code to concate string and making url
                        // CalltoCheckLimit function used to check call for 50000, 25000, 12500, 5000, then 1000, 500, 250 etc
                        res50000 = qbconnector.CalltoCheckLimit(url,"50000", body),
                        lastResponseWithCount = if res50000{0} then
                                        let
                                            res25000 = qbconnector.CalltoCheckLimit(url,"25000", body),
                                            lastCount = if res25000{0} then
                                                        let
                                                            res12500 = qbconnector.CalltoCheckLimit(url,"12500", body),
                                                            lastCount = if res12500{0} then 
                                                                            let
                                                                                res5000 = qbconnector.CalltoCheckLimit(url,"5000", body),
                                                                                lastCount = if res5000{0} then
                                                                                                let
                                                                                                    res1000 = qbconnector.CalltoCheckLimit(url,"1000", body),
                                                                                                    lastCount = if res1000{0} then
                                                                                                     let
                                                                                                         res500 = qbconnector.CalltoCheckLimit(url,"500", body),
                                                                                                         lastCount = if res500{0} then
                                                                                                            let
                                                                                                                lastCount =  qbconnector.CalltoCheckLimit(url,"500", body)
                                                                                                            in
                                                                                                                lastCount
                                                                                                         else
                                                                                                            {"500",res500{1}}
                                                                                                         
                                                                                                     in 
                                                                                                         lastCount
                                                                                                    else
                                                                                                        {"1000",res1000{1}}
                                                                                                     
                                                                                                in
                                                                                                   lastCount
                                                                                            else 
                                                                                                {"5000", res5000{1}}
                                                                            in
                                                                                lastCount
                                                                        else
                                                                          {"12500", res12500{1}}
                                                        in
                                                            lastCount
                                                    else
                                                        {"25000", res25000{1}}
                                        in
                                            lastCount
                                    else
                                        {"50000", res50000{1}},
                                        
                        // making call for just 1 record and getting table name and fields
                        tableInfoResponse = lastResponseWithCount{1},
                         // giving table node,
                        table = tableInfoResponse[xml][table],
                        tableNameandFields = qbconnector.GetTableNameandFieldlist(tableInfoResponse, table),
                        // getting count field
                        count = countResponse[xml][numMatches],
                        // getting pages number that need to fetch
                        pageCount = Number.RoundUp(Number.FromText(count) / Number.FromText(lastResponseWithCount{0})),
                        // listing 
                        pageIndices = { 0 .. pageCount - 1 },
                        // making call to getPage function to handle call to qb for multipages,
                        Pages = List.Transform(pageIndices, each qbconnector.GetPage(_,url, lastResponseWithCount{0}, body)),
                        data = qbconnector.DataManupulation(tableNameandFields, Table.Combine(Pages))
                    in
                         data{2}
                    
                 else
                    response[xml]
        
        
    in     
       result;      
 
qbconnector.UpdateRecord = (record, count) =>
    let
        updatedMain = record&count
    in
        updatedMain;
// function to check which count works for table
qbconnector.CalltoCheckLimit = (url,count, body) =>
    let
        tableUrl = url,
        fullbody = Text.ToBinary(body&"<options>num-"&count&"</options><fmt>structured</fmt></qdbapi>"),
        response = qbconnector.PostXmlRequest(tableUrl, "API_DoQuery", fullbody),
        iserror = qbconnector.IsError(response)
    in
        {iserror, response};
// code to check giving 75 error
qbconnector.IsError = (response)=>
    let
        
        errorCode = response[code],
        iserror = if errorCode = "75" then true else false 
    in
        iserror;
// code to make call and provide table with record limits
qbconnector.GetPage = (index, baseUrl, count, body) =>
    // calculating number to skip records from fetching
        let skip  = "skp-" & Text.From(index * Number.FromText(count)),
            fullbody = Text.ToBinary(body&"<options>num-"&count&"."&skip&"</options><fmt>structured</fmt></qdbapi>"),
            response  = qbconnector.PostXmlRequest(baseUrl, "API_DoQuery", fullbody),
            table = response[xml][table],
            tableData = qbconnector.TableData(table)
        in  tableData;
        
 qbconnector.GetTableNameandFieldlist = (response, table) => 
      let
        //getting table name
        tableName = table{0}[name], 
        // getting fields
        filedsTable = table{0}[fields]{0}[field],
        // from fields table creating list to define types
        listFields = Table.TransformRows(filedsTable, each qbconnector.DefineType(_[#"Attribute:field_type"], _[label]) ),
        // code to covert miliseconds to date
        ToDate = (value) => if value = null then null else (#datetime(1970, 1, 1, 0, 0, 0) + #duration(0, 0, 0, Number.FromText(value)/1000)),
       // creating list to change 
        listDateFields = Table.TransformRows(filedsTable, each qbconnector.ChangeType(_[#"Attribute:field_type"], _[label], ToDate) ),
        // getting labels
        fieldsList = filedsTable[label]
      in
        Record.FromList({tableName, fieldsList, listDateFields, listFields} as list, {"name", "fieldsList", "listDateFields", "listFields"} as any) as record ;

  qbconnector.TableData = (table) =>   
        let
            result = if(Table.IsEmpty(table{0}[records])) then 
                        table{0}[records] 
                     else 
                        let
                            isRecord = Record.HasFields(table{0}[records]{0},{"record"}),
                            data = if(isRecord) then
                                        table{0}[records]{0}[record] 
                                   else
                                       table{0}[records] 
                        in
                            data
        in  
        result;
  qbconnector.DataManupulation = (tableNameandFields, tableData) => 
      let
        newTableData = #table(tableNameandFields[fieldsList],Table.TransformRows(tableData, each _[f][#"Element:Text"] )),
        // changing date fields
        dateAfterDateChange = Table.TransformColumns(newTableData, tableNameandFields[listDateFields]),
        // changing types
        changeTablesType = Table.TransformColumnTypes(dateAfterDateChange,tableNameandFields[listFields])
      in
          {newTableData, tableNameandFields[listFields],changeTablesType, tableNameandFields[listDateFields], dateAfterDateChange};
 
 // code to check and define datatypes, code for setting data type for columns
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
                        		{label, type duration}
                        	else
                        		{label, type text}
    in
        dataValue;
        // define code to change miliseconds to dates, this function used to maupulates data as per fields type like millisec to date, integer to bool etc
qbconnector.ChangeType = (dataType, label, ToDate) =>
    let
        ToOnlyDate = 
            try
                (value) => if value = null then null else (#datetime(1970, 1, 1, 0, 0, 0) + #duration(0, 0, 0, Number.FromText(value)/1000))
            otherwise
                (value) => if value = null then null else (#datetime(1970, 1, 1, 0, 0, 0) + #duration(0, 0, 0, Number.FromText(value)/(60*60*24*1000))),
        skipElse = (value) => if value = null then null else value,
        ToDuration = (value) => if value = null then null else (Number.FromText(value)/(86400000)),
        ToInt = (value) => if value = null then 0 else Number.FromText(value),
        changablelist = if dataType  = "timestamp" then
                            {label, ToDate}
                        else if dataType  = "date" then
                        	{label, ToOnlyDate}
                        else if dataType  = "duration" then
                        	{label, ToDuration}
                        else if dataType  = "checkbox" then
                        	{label, ToInt}
                        else
                            {label, skipElse}
                       

    in
        changablelist;

qbconnector.PostXmlRequest = (url, action, body)=>
     let
         textFromBinary = Text.Replace(Text.FromBinary(Web.Contents(url,[Headers=[#"Content-Type"=qbconnector.ContentType, #"QUICKBASE-ACTION"=action, #"USER-AGENT"= qbconnector.UserAgent ], Content=body])), "<BR/>", "#(cr)"),
         response =  Xml.Tables(textFromBinary){0},
         errorCode = response[errcode]
     in
        Record.FromList({response, errorCode} as list, {"xml", "code"} as any) as record ;

ValidateUrlScheme = (url as text) as text => if (Uri.Parts(url)[Scheme] <> "https") then error "Url scheme must be HTTPS" else url;

// Data Source Kind description
QuickBase = [
    TestConnection = (dataSourcePath) =>{ "QuickBase.Contents", dataSourcePath },
    Authentication = [
           Key = [
            KeyLabel = "User Token",
            Label = "Usertoken"
           ]
    ],
    Label = "Quick Base"
];

// Data Source UI publishing description
QuickBase.Publish = [
    Beta = false,
    Category = "Online Services",
    ButtonText = { "Quick Base", "Helps to connect with Quick Base and get data, you just need to pass url of target Quick Base account and User Token."  },
    LearnMoreUrl = "https://quickbase.com",
    SourceImage = qbconnector.Icons,
    SourceTypeImage = qbconnector.Icons
];

qbconnector.Icons = [
    Icon16 = { Extension.Contents("qbconnector16.png"), Extension.Contents("qbconnector20.png"), Extension.Contents("qbconnector24.png"), Extension.Contents("qbconnector32.png") },
    Icon32 = { Extension.Contents("qbconnector32.png"), Extension.Contents("qbconnector40.png"), Extension.Contents("qbconnector48.png"), Extension.Contents("qbconnector64.png") }
];

// Common library code

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