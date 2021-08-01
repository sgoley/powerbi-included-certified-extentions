// This file contains your Data Connector logic
[Version = "1.0.2"]
section BI360;

EnableTraceOutput = false;

[DataSource.Kind="BI360", Publish="BI360.Publish"]
shared BI360.Contents = Value.ReplaceType(BI360Impl,BI360Type);

DefaultRequestHeaders = [
        #"Token" = Extension.CurrentCredential()[Key],          
        #"Content-Type" = "application/json",
        #"Solver-Externalapi-Consumer" ="powerbi .1" 
];

BI360 = [
//https://github.com/Microsoft/DataConnectors/blob/master/docs/m-extensions.md#example-connector-with-required-parameters
   TestConnection = (dataSourcePath) =>
       let
          //dataSourcePath is of type "BI360Type" 
          json =Json.Document(dataSourcePath),  
          url = json[Url]
       in
        { "BI360.Contents",url },
    Authentication =[
        Key=[
        KeyLabel = "Paste the Access token from Solver",
        Label ="Solver Access Token"
        ]       
    ] ,
     Label ="Authenticate to Solver"
];

//Creates a navigation table for a given token 
BI360Impl = (url as text) as table =>
    let      
        //base route lists all the tables 
        _url = ValidateUrlScheme(url),
        source = Web.Contents(_url,[Headers = DefaultRequestHeaders]),
        RootEntities = Diagnostics.LogValue("Tables avaliable",Json.Document(source)),  
        //now I have a table with "Column1" record, record, record 
        entitiesAsTable = Table.FromList(RootEntities, Splitter.SplitByNothing()),
        //now I have a table with columns "label" and "shortLabel"       
        rename= Table.ExpandRecordColumn(entitiesAsTable,"Column1",{"label", "shortLabel"}),       
        //add new column called "Data",which has a Table with the data, data is hydrated via the BI360.View funcion
         //Text.Format("#[label]",_) returns the value in the row "label" 
        withData = Table.AddColumn(rename, "Data", each BI360.View(url,Text.Format("#[label]",_),Text.Format("#[shortLabel]",_)),type table),     
        //withItemKind = Table.AddColumn(withData, "ItemKind",each ShortLabel2ItemKind(Text.Format("#[shortLabel]",_)), type text),
        //hardcoded to "Table" until we figure out the dimension UX 
        withItemKind = Table.AddColumn(withData, "ItemKind",each "Table", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table", type text),
        // Indicate that the node should not be expandable - could change depending if you want to implement a star schema but PowerBI's auto relations seem to be good enough 
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true, type logical),
        // Generate the nav table
        navTable = Table.ToNavigationTable(withIsLeaf, {"label"}, "label", "Data", "ItemKind", "ItemName", "IsLeaf")  
    in
        navTable;

BI360.Feed= (baseUrl as text) as table => 
    let
    output =GetAllPagesByNextLink(baseUrl),
     // Lowercase the column names to match the column names from the schema call 
    asTable = Table.TransformColumnNames(output,Text.Lower)
    in
        asTable;

// Read all pages of data.
// After every page, we check the "NextLink" record on the metadata of the previous request.
// Table.GenerateByPage will keep asking for more pages until we return null.
GetAllPagesByNextLink = (url as text) as table =>
    Table.GenerateByPage((previous) => 
        let
            // if previous is null, then this is our first page of data
            nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
            // if NextLink was set to null by the previous call, we know we have no more data
            page = if (nextLink <> null) then GetPage(nextLink) else null           
        in
            page
    );
GetPage = (url as text) as table =>
    let
        response = Web.Contents(url, [Headers = DefaultRequestHeaders]),      
        body = Json.Document(response),
        nextLink =Diagnostics.LogValue("nextlink",GetNextLink(body)),
        data = Table.FromRecords(body[data])     
      
    in
        data meta [NextLink = nextLink];        
  

// In this implementation, 'response' will be the parsed body of the response after the call to Json.Document.
// We look for the 'nextUrl' field and simply return null if it doesn't exist.
GetNextLink = (response) as nullable text => Record.FieldOrDefault(response, "nextUrl");  

BI360.View = (baseUrl as text,label as text, shortLabel as text) as table =>
    let
        // Implementation of Table.View handlers.
        //
        // We wrap the record with Diagnostics.WrapHandlers() to get some automatic
        // tracing if a handler returns an error.
        //
        View = (state as record) => Table.View(null, Diagnostics.WrapHandlers([
            //Given a table, return its type               
            GetType = () => CalculateSchema(state,baseUrl,label,shortLabel),

            // Called last - retrieves the data from the calculated URL
            GetRows = () => 
                let
                    finalSchema = CalculateSchema(state,baseUrl,label,shortLabel),
                    finalUrl = Diagnostics.LogValue("Generated URL",CalculateUrl(state, baseUrl,label,shortLabel)),
                    result =  BI360.Feed(finalUrl),
                    data =  if (finalSchema <> null) then            
                     Table.ChangeType(result, finalSchema) 
                   else 
                        null 
                in
                    data,
            //
            // Helper functions
            //
            
               CalculateSchema = (state,baseUrl as text ,label as text ,shortLabel as text ) as type =>
                if (state[Schema]? = null) then
                    GetSchemaForEntity(baseUrl,label,shortLabel)
                else
                    state[Schema],


           // Calculates the final URL based on the current state.
            CalculateUrl = (state, baseUrl,label,shortLabel) as text => 
                let
                    urlWithEntity =Uri.Combine(baseUrl,Text.Format("foreignobjects?label=#[label]&shortlabel=#[shortLabel]",[label= label,shortLabel=shortLabel])),             

                    // Check for $count. If all we want is a row count,
                    // then we add /$count to the path value (following the entity name).
                    /*
                    urlWithRowCount =
                        if (state[RowCountOnly]? = true) then
                            urlWithEntity & "/$count"
                        else
                            urlWithEntity,*/

                    // Uri.BuildQueryString requires that all field values
                    // are text literals.
                    defaultQueryString = [],

                    // Check for Top defined in our state
                    qsWithTop =
                        if (state[Top]? <> null) then
                            defaultQueryString & [ #"$top" = Number.ToText(state[Top]) ]
                        else
                            defaultQueryString,
                    /*
                    // Check for Skip defined in our state
                    qsWithSkip = 
                        if (state[Skip]? <> null) then
                            qsWithTop & [ #"$skip" = Number.ToText(state[Skip]) ]
                        else
                            qsWithTop,
                    /*
                    // Check for explicitly selected columns
                    qsWithSelect =
                        if (state[SelectColumns]? <> null) then
                            qsWithSkip & [ #"$select" = Text.Combine(state[SelectColumns], ",") ]
                        else
                            qsWithSkip,

                    qsWithOrderBy = 
                        if (state[OrderBy]? <> null) then
                            qsWithSelect & [ #"$orderby" = state[OrderBy] ]
                        else
                            qsWithSelect, 

                    encodedQueryString = Uri.BuildQueryString(qsWithOrderBy), */
                    encodedQueryString = Uri.BuildQueryString(qsWithTop),
                    finalUrl =  urlWithEntity & encodedQueryString
                in
                    finalUrl
        ]))
    in
        View([Url = baseUrl, Label = label, ShortLabel =shortLabel]);

 //Turns the schema of an object into a M Table type 
 GetSchemaForEntity = (baseUrl as text,label as text, shortLabel as text) as type =>
     let        
         schema = BI360.GetSchema(baseUrl,label,shortLabel),
         //copy pasted from SchemaTransformTable https://github.com/Microsoft/DataConnectors/blob/master/samples/TripPin/6-Schema/TripPin.pq
         toList = List.Transform(schema[Type], (t) => [Type=t, Optional=false]),
         toRecord = Record.FromList(toList, schema[Name]),
         toType = Type.ForRecord(toRecord, false),
         out= type table (toType)
     in
          out;

// Data Source UI publishing description
BI360.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://solverglobal.com/",
    SourceImage = Solver.Icons,
    SourceTypeImage = Solver.Icons
];

Solver.Icons = [
    Icon16 = { Extension.Contents("Solver16.png"), Extension.Contents("Solver20.png"), Extension.Contents("Solver24.png"), Extension.Contents("Solver32.png") },
    Icon32 = { Extension.Contents("Solver32.png"), Extension.Contents("Solver40.png"), Extension.Contents("Solver48.png"), Extension.Contents("Solver64.png") }
];

BI360.SqlType2MType=(sqltype as text) as type =>
    let 
        values = {
    {"varbinary",type nullable Binary.Type},
    {"binary",  type nullable Binary.Type},
    {"image",  type nullable Binary.Type},
    {"bigint", type nullable Number.Type},
    {"bit",  type nullable Logical.Type},
    {"decimal",type nullable  Number.Type},
    {"int", type nullable  Number.Type},
    {"money", type nullable  Number.Type},
    {"numeric",type nullable  Number.Type},
    {"smallint",type nullable  Number.Type},
    {"smallmoney",type nullable  Number.Type},
    {"tinyint", type nullable  Number.Type},
    {"float", type nullable  Number.Type},
    {"real", type nullable  Number.Type},
    {"datetime2",type nullable DateTime.Type},
    {"datetime", type nullable DateTime.Type},
    {"smalldatetime", type nullable DateTime.Type},
    {"datetimeoffset",  type nullable DateTime.Type},
    {sqltype,type nullable Text.Type}
    },
    Result = List.First(List.Select(values, each Text.Contains(_{0},sqltype))){1}
    in
        Result;
/* Use once we figure out how dimensions work 
ShortLabel2ItemKind = (shortLabel as text) as text=>
    let 
        dimensions = {"account", "asset", "category","currency","customer","employee","entity","entityCorr",
        "IntercoParent","Item","MinorityParent","Product","Project","SalesPerson","Scenario","TimePeriod","Vendor"},
        ItemKind = if Text.Contains(shortLabel,"dim",Comparer.OrdinalIgnoreCase) then "Dimension"
        //hardcoded dimensions 
        else if List.First(List.Select(dimensions, each Text.Contains(shortLabel,_,Comparer.OrdinalIgnoreCase))) <> null then "Dimension" else "Table"      
        in
            ItemKind;*/


BI360.GetSchema=(baseUrl as text,label as text, shortLabel as text) as table => 
    let
        url= Uri.Combine(baseUrl,Text.Format("Tables/schema?label=#[label]&shortlabel=#[shortLabel]",[label= label,shortLabel=shortLabel])),    
        json = Json.Document(Web.Contents(url,[Headers =DefaultRequestHeaders])),
        asTable = Table.FromList(json, Splitter.SplitByNothing()),
         //Dunno why names are funky       
        rename= Table.ExpandRecordColumn(asTable ,"Column1",{"columN_NAME", "datA_TYPE"}),
        //convert from tsql type to m type    
        //lowercase the column names to match the colunm names in the data 
        schema = Table.RenameColumns(Table.TransformColumns(rename, {{"datA_TYPE",each BI360.SqlType2MType(_)},{"columN_NAME",each Text.Lower(_)}}),{{"columN_NAME","Name"},{"datA_TYPE","Type"}})
        in
            schema;
//https://docs.microsoft.com/en-us/power-query/handlingdocumentation
//URL isn't a URL type because we don't want users to select anything but the external API URL 
BI360Type = type function(
    Url as (type text meta [
        Documentation.FieldCaption = "Paste the API URL from the Solver Portal", //this is the title for the text box 
        Documentation.FieldDescription = "Solver API URL", 
        Documentation.SampleValues = {"https://demo.app.solverglobal.com/api/dw/externalApi/"}
    ]))
     as table meta [
        Documentation.Name = "Solver", //this is what shows up on the URL screen as a title 
        Documentation.FieldDescription = "Navigation table",
        Documentation.LongDescription = "Retrieves a Navigation Table populated with the enabled tables for a given token"      
    ];
//
// Common functions
//

ValidateUrlScheme = (url as text) as text => if (Uri.Parts(url)[Scheme] <> "https") then error "Url scheme must be HTTPS" else url;

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

        Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Table.ChangeType = Extension.LoadFunction("Table.ChangeType.pqm");
Table.GenerateByPage = Extension.LoadFunction("Table.GenerateByPage.pqm");

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = if (EnableTraceOutput) then Diagnostics[LogValue] else (prefix, value) => value;
Diagnostics.LogFailure = Diagnostics[LogFailure];
Diagnostics.WrapHandlers = Diagnostics[WrapHandlers];
   