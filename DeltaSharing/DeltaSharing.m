[Version="1.0.4"]
section DeltaSharing;


[DataSource.Kind="DeltaSharing", Publish="DeltaSharing.Publish"]
shared DeltaSharing.Contents =  Value.ReplaceType(GetShares, SharingServerType);

// We support readerVersion 3 for delta format
ConnectorReaderVersion = 3;
// NOTE: version string needs to be updated both at the top and in the version variable
version = "1.0.4";
user_agent = "Delta-Sharing-PowerBI/" & version;

// Data Source Kind description
DeltaSharing = [
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            Host = json[host]
        in
            { "DeltaSharing.Contents", Host},

    Authentication = [
        /* use this for bearer token auth */
        Key = [
            KeyLabel = "Bearer Token",
            Label = "Authentication"
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
DeltaSharing.Publish = [
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    SourceImage = DeltaSharing.Icons,
    SourceTypeImage = DeltaSharing.Icons
];

DeltaSharing.Icons = [
    Icon16 = { Extension.Contents("DeltaSharing16.png"), Extension.Contents("DeltaSharing20.png"), Extension.Contents("DeltaSharing24.png"), Extension.Contents("DeltaSharing32.png") },
    Icon32 = { Extension.Contents("DeltaSharing32.png"), Extension.Contents("DeltaSharing40.png"), Extension.Contents("DeltaSharing48.png"), Extension.Contents("DeltaSharing64.png") }
];


SharingServerType = 
    type function ( 
        host as (type text meta [
            Documentation.FieldCaption = Extension.LoadString("ServerURLLabel"),
            Documentation.FieldDescription = Extension.LoadString("ServerURLHelpLabel"),
            Documentation.SampleValues = { "https://example.databricks.com/api/2.0/delta-sharing/metastores/19a85dee-54bc-43a2-87ab-023d0ec16013" }
        ]),
        optional options as (type nullable [
            optional rowLimitHint = (type number meta [
                Documentation.FieldCaption = Extension.LoadString("RowLimitHintLabel"),
                Documentation.FieldDescription = Extension.LoadString("RowLimitHintHelpLabel"),
                Documentation.SampleValues = { 1000000 }
            ])
         ] meta [
            Documentation.FieldCaption = Extension.LoadString("AdvancedOptionsLabel")
        ])
    ) as table meta [
        Documentation.Name = Extension.LoadString("DataSourceName")
    ];



GetShares = (server_host as text, optional options as record) as table =>
    let
        // https://github.com/delta-io/delta-sharing/blob/main/PROTOCOL.md#list-shares
        defaultOptions = [
            rowLimitHint = 1000000
        ],
        optionsRecord = if options = null then [] else options,
        rowLimitHint = Int64.From(
            if optionsRecord[rowLimitHint]? = null or optionsRecord[rowLimitHint] < 0 then defaultOptions[rowLimitHint]
            else optionsRecord[rowLimitHint]
        ),

        url = server_host & "/shares",
        shares = GetItems(url, {"name"}),
        withData = Table.AddColumn(shares, "Data", each GetSchemas(url, [name], rowLimitHint)),
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Folder"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Folder"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false),
        renamed = Table.RenameColumns(withIsLeaf, {{"name", "Name"}}), 
        navTable = Table.ToNavigationTable(renamed, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

GetSchemas = (url as text, share_name as text, rowLimitHint as number) as table =>
    let
        // https://github.com/delta-io/delta-sharing/blob/main/PROTOCOL.md#list-schemas-in-a-share
        schemas_url = url & "/" & share_name & "/schemas",
        schemas = GetItems(schemas_url, {"name"}),
        withData = Table.AddColumn(schemas, "Data", each GetTables(schemas_url, [name], rowLimitHint)),
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Database"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Database"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false),
        renamed = Table.RenameColumns(withIsLeaf, {{"name", "Name"}}), 
        navTable = Table.ToNavigationTable(renamed, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
     
    in
        navTable;

GetTables = (schemas_url as text, schema as text, rowLimitHint as number) as table =>
    let
        // https://github.com/delta-io/delta-sharing/blob/main/PROTOCOL.md#list-tables-in-a-schema
        tables_url = schemas_url & "/" & schema & "/tables",
        tables = GetItems(tables_url),
        withData = Table.AddColumn(tables, "Data", each GetData(tables_url, [name], rowLimitHint)),
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Table"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true),
        renamed = Table.RenameColumns(withIsLeaf, {{"name", "Name"}}), 
        navTable = Table.ToNavigationTable(renamed, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;


Value.WaitFor = (producer as function, interval as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, null},
            (state) => state{0} <> null and (count = null or state{0} < count),
            (state) => if state{1} <> null then {null, state{1}} else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), interval(state{0}))},
            (state) => state{1})
    in
        List.Last(list);

RetryWithBackoff = (
    operation as function, 
    optional retries as number, 
    optional initialDelay as number
) as any =>
    let
        // Set default values if not provided
        maxRetries = if retries <> null then retries else 5,         // Default to 5 retries
        delay = if initialDelay <> null then initialDelay else 1,     // Default to 1-second delay

        // Use Value.WaitFor with exponential backoff
        waitForResult = Value.WaitFor(
            (iteration) =>
                let
                    result = try operation(iteration > 0) otherwise null,
                    status = if result <> null then Value.Metadata(result)[Response.Status] else -1,
                    // Only retry when the return status is 429 or 503
                    actualResult = if status = 429 or status = 503 then null else result
                in
                    actualResult,
            (iteration) => #duration(0, 0, 0, delay * Number.Power(2, iteration)),  // Exponential backoff delay
            maxRetries
        )
    in
        // If result is still null after retries, raise an error
        if waitForResult = null then
            error "Value.WaitFor() Failed after multiple retry attempts"
        else
            waitForResult;


GetData = (tables_url as text, table_name as text, rowLimitHint as number) as table =>
    let
        /*
        The current flow for auto-resolve the format for a table:
        1. Call the /metadata endpoint with responseformat = parquet,delta
        2. Check the protocol section for the output to determine what is the suggested format from server
        3. Call the /query endpoint with auto-resolve format header from previous step
        4. Process data according to the auto-resolve format
        */
        // Base headers
        baseHeaders = [#"Content-Type"="application/json", #"User-Agent" = user_agent],
        
        // Send the request to metadata endpoint
        metadata = Lines.FromBinary(SendRequest(tables_url & "/" & table_name & "/metadata", [
            Headers = baseHeaders & [#"delta-sharing-capabilities"="responseformat=parquet,delta;readerfeatures=deletionvectors,columnmapping"]
        ]), null, null, null),

        isDeltaFormat = TableProtocolIsDelta(Json.Document(metadata{0})[protocol]),

        // https://github.com/delta-io/delta-sharing/blob/main/PROTOCOL.md#read-data-from-a-table
        // Response Format:
        //   line 1: protocol
        //   line 2: schema
        //   line 3...: file info

        // Conditionally add the delta-sharing-capabilities header
        headers = if isDeltaFormat then baseHeaders & [#"delta-sharing-capabilities"="responseformat=delta;readerfeatures=deletionvectors,columnmapping"]
                    else baseHeaders,

        // Send the request to query endpoint
        resp = Lines.FromBinary(SendRequest(tables_url & "/" & table_name & "/query", [
            Headers = headers,
            Content = Json.FromValue([limitHint = rowLimitHint])
        ]), null, null, null),


        tableMeta = Json.Document(resp{1})[metaData],
   
        fileInfos = List.Range(resp, 2),
        fileUrls = List.Transform(fileInfos, each Json.Document(_)[file])
    in
        // Checking whether it's indeed delta format should rely on the response not the responseFormat header
        // since there may be old servers that did not implement the delta format and do not recognize the header
        if isDeltaFormat then 
            FetchFileContentsDelta(resp{0}, tableMeta, fileInfos, rowLimitHint)
         else
            let
                tableSchema = Json.Document(tableMeta[schemaString])[fields],
                partitionColumns = tableMeta[partitionColumns]
            in
                FetchFileContents(fileUrls, tableSchema, partitionColumns, rowLimitHint);
            
      
        
FetchFileContents = (fileUrls as list, tableSchema as list, partitionColumns as list, rowLimitHint as number) as table =>
    let
        numFiles = List.Count(fileUrls),
        columnNames = List.Transform(tableSchema, each [name]),

        toTable = Table.FromList(fileUrls, Splitter.SplitByNothing(), {"FileInfo"}),
        expandFileInfo = Table.ExpandRecordColumn(toTable, "FileInfo", {"url", "partitionValues"}, {"##url##", "partitionValues"}),
        addPartitionColumns = Table.ExpandRecordColumn(expandFileInfo, "partitionValues", partitionColumns), 

        processFile = Table.AddColumn(addPartitionColumns, "##data##", each Parquet.Document(Binary.Buffer(ProtectSensitiveQueryParameters([#"##url##"], [ManualCredentials = true])))),
        // This line is needed for tests since Parquet.Document is not directly built-into Power M
        // processFile = Table.AddColumn(addPartitionColumns, "##data##", each ParquetDelayed([#"##url##"], columnNames)),

        partitionColumnsWithSchema = List.Select(tableSchema, each List.Contains(partitionColumns, [name])),
        partitionColumnsWithType = List.Transform(partitionColumnsWithSchema, each {[name], ConvertDeltaTypeToTypeRecord(_)[Type]}),
        updatePartitionColumnTypes = Table.TransformColumnTypes(processFile, partitionColumnsWithType),

        expanded = Table.ExpandTableColumn(updatePartitionColumnTypes, "##data##", List.RemoveItems(columnNames, partitionColumns)),
        removedColumns = Table.SelectColumns(expanded, columnNames),

        // create an empty table from schema so that we atleast show table schema when no data is present
        withLimit =  if numFiles = 0 then #table(columnNames, {}) else Table.FirstN(removedColumns, rowLimitHint)

    in
        Value.ReplaceType(withLimit, ConvertToTableType(tableSchema));

TableProtocolIsDelta = (protocol as record) =>
    let
        isDelta = if  Record.HasFields(protocol, "deltaProtocol") then true else false,
        updateProtocol = if isDelta then protocol[deltaProtocol] else protocol,
        // if version is not returned, we consider it's V1
        readerVersionRequired = if updateProtocol[minReaderVersion]? = null then 1 else updateProtocol[minReaderVersion]
          
    in
        if readerVersionRequired > ConnectorReaderVersion 
            then error Error.Record("DataSource.Error",
                Text.Format(Extension.LoadString("ErrorOldProtocolVersion"), {readerVersionRequired}))
        else isDelta;

SendRequest = (url as text, options as record) as binary =>
    let
        credential = Extension.CurrentCredential(),
        token = credential[Key],
        headers = [#"Authorization" = "Bearer " & token] & (if options[Headers]? = null then [] else options[Headers]),
        resp = RetryWithBackoff(
            (isRetry as logical) => Web.Contents(url, options & [Headers=headers] & [ManualStatusHandling={400, 403, 404, 429, 503}] & [IsRetry = isRetry])
        ), 
        respMetadata = Value.Metadata(resp)
    in
        HandleError(Binary.Buffer(resp), respMetadata);

HandleError = (resp, respMetadata) =>
    let
        respCode = respMetadata[Response.Status],
        finalResp = 
            if respCode = 400 then error Error.Record("DataSource.Error", Text.Format(Extension.LoadString("ErrorInvalidConnectionString"), {Text.FromBinary(resp)}))
            else if respCode = 403 then error Extension.CredentialError(Credential.AccessForbidden, Text.Format(Extension.LoadString("ErrorInvalidCredentials"), {Text.FromBinary(resp)}))
            else if respCode = 404 then error Error.Record("DataSource.Error", Text.Format(Extension.LoadString("ErrorResourceNotFound", {Text.FromBinary(resp)})))
            else resp
    in
        finalResp;

GetItems = (url as text, optional cols as list) as table =>
  let
    source = Json.Document(SendRequest(url, [])),  
    items = source[items]?,
    itemsTable = if items = null then #table(cols, {}) else Table.FromRecords(items)
  in
    itemsTable;


// Schema Enforcement
ConvertDeltaTypeToTypeRecord = (schema as record) as record =>
    let
        name = schema[name],
        isNullable = schema[nullable],
        deltaType = schema[#"type"],
        mType = if (deltaType = "string") then Text.Type
        else if (deltaType = "long") then Int64.Type
        else if (deltaType = "integer") then Int32.Type
        else if (deltaType = "short") then Int16.Type
        else if (deltaType = "byte") then Int8.Type
        else if (deltaType = "float") then Decimal.Type
        else if (deltaType = "double") then Decimal.Type
        else if (deltaType = "boolean") then Logical.Type
        else if (deltaType = "binary") then Binary.Type
        else if (deltaType = "date") then Date.Type
        else if (deltaType = "timestamp") then DateTime.Type
        else if (deltaType = "array") then List.Type
        else if (deltaType = "map") then Record.Type
        else if (Text.Contains(deltaType, "decimal", Comparer.OrdinalIgnoreCase)) then Decimal.Type
        else Any.Type
    in
        [ Type = mType, Optional = false];

ConvertToTableType = (schema as list) as type =>
    let
        mschema = List.Transform(schema, (column) => ConvertDeltaTypeToTypeRecord(column)),
        toRecord = Record.FromList(mschema, List.Transform(schema, each [name])),
        toType = Type.ForRecord(toRecord, false)
    in
        type table (toType);

// Library functions
ProtectSensitiveQueryParameters = (url as text, options as record) as binary =>

    let
        uriParts = Uri.Parts(url),
        uriWithoutQuery = Uri.FromParts(uriParts & [Query = []]),
        modifiedOptions = options & [
            CredentialQuery = uriParts[Query]
        ]
    in
        Web.Contents(uriWithoutQuery, modifiedOptions);

Uri.FromParts = (parts) =>
    let
        port = if (parts[Scheme] = "https" and parts[Port] = 443) or (parts[Scheme] = "http" and parts[Port] = 80) then "" else ":" & Text.From(parts[Port]),
        div1 = if Record.FieldCount(parts[Query]) > 0 then "?" else "",
        div2 = if Text.Length(parts[Fragment]) > 0 then "#" else "",
        uri = Text.Combine({parts[Scheme], "://", parts[Host], port, parts[Path], div1, Uri.BuildQueryString(parts[Query]), div2, parts[Fragment]})
    in
        uri;

// Load common library functions
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");


// Delta Format Related
Z85Encode = (uuid as text) as text =>
    let
        cleanedHexString = Text.Remove(uuid, "-"),
    
    // Convert the cleaned hex string to binary
     binaryData = Binary.FromText(cleanedHexString, BinaryEncoding.Hex),
        // Define the Z85 character set
        z85Chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-:+=^!/*?&<>()[]{}@%$#",
        
        // Convert binary data to a list of bytes
        byteList = Binary.ToList(binaryData),
        
        // Ensure the list length is a multiple of 4
        validLength = if Number.Mod(List.Count(byteList), 4) = 0 then List.Count(byteList) else error "Input length must be a multiple of 4",
        
        // Function to convert a 4-byte chunk to a 32-bit integer
        ConvertChunkToInt = (chunk as list) as number =>
            let
                byte1 = chunk{0},
                byte2 = chunk{1},
                byte3 = chunk{2},
                byte4 = chunk{3},
                intValue = byte1 * Number.Power(256, 3) + byte2 * Number.Power(256, 2) + byte3 * Number.Power(256, 1) + byte4 * Number.Power(256, 0)
            in
                intValue,
        
        // Function to encode a 32-bit integer to a 5-character Z85 string
        EncodeIntToZ85 = (intVal as number) as text =>
            let
                base85Chars = List.Generate(
                    () => [val = intVal, i = 0],
                    each [i] < 5,
                    each [val = Number.IntegerDivide([val], 85), i = [i] + 1],
                    each Text.At(z85Chars, Number.Mod([val], 85))
                ),
                z85String = Text.Combine(List.Reverse(base85Chars))
            in
                z85String,
        
        // Split the byte list into 4-byte chunks
        chunkIndices = List.Transform({0..(Number.IntegerDivide(validLength, 4) - 1)}, each _ * 4),
        chunks = List.Transform(chunkIndices, each List.FirstN(List.Skip(byteList, _), 4)),
        
        // Convert chunks to 32-bit integers
        intValues = List.Transform(chunks, each ConvertChunkToInt(_)),
        
        // Encode integers to Z85 strings
        encodedStrings = List.Transform(intValues, each EncodeIntToZ85(_)),
        
        // Combine all encoded strings into the final Z85 encoded text
        encodedText = Text.Combine(encodedStrings)
    in
        encodedText;

ExtractDeltaMetadata = (metadata as record) as record =>
    let
        fieldNames = Record.FieldNames(metadata),
        deltaMetadata = metadata[deltaMetadata],
        // Create new metaData structure by merging metadata with deltaMetadata fields
        newMetaData = Record.RemoveFields(Record.Combine({metadata, deltaMetadata}), "deltaMetadata"),
        result = [metaData = newMetaData]
    in
        result;

    // Function to create a directory structure
MakeDirectory = (files) => Table.AddColumn(
        Table.ReorderColumns(Table.RenameColumns(Record.ToTable(files), {"Value", "Content"}), {"Content", "Name"}),
        "Date modified",
        each DateTime.LocalNow()
    );

ExtractDeletionVectorUuid = (url as text) as text =>
    let
        // Parse the URL into its components
        urlParts = Uri.Parts(url),

        // Extract the path part
        path = urlParts[Path],

        // Extract the last segment of the path
        pathSegments = Text.Split(path, "/"),
        lastSegment = List.Last(pathSegments),

        // Extract the UUID part after 'deletion_vector_'
        uuidPart = Text.AfterDelimiter(lastSegment, "deletion_vector_"),

        // Remove the file extension to get only the UUID
        uuid = Text.BeforeDelimiter(uuidPart, ".")
    in
        uuid;
    

ExtractFileName = (url) => Text.AfterDelimiter(Uri.Parts(url)[Path], "/", {0, RelativePosition.FromEnd});
ExtractFileInfo = (url) => [
    Name = ExtractFileName(url),
    Content = Binary.Buffer(ProtectSensitiveQueryParameters(url, [ManualCredentials = true]))
];

        
 ProcessDeltaActions = (filejson as list) as record =>
    let
        ProcessedData = List.Transform(filejson, each
            let
                doc = Json.Document(_),
                file = doc[file],
                deltaSingleAction = file[deltaSingleAction],

                // Extract URLs from all possible actions within deltaSingleAction
                deletionVectorUrls = List.Transform(Record.FieldNames(deltaSingleAction), (action) => 
                    let
                        actionRecord = Record.Field(deltaSingleAction, action),
                        deletionVector = if Record.HasFields(actionRecord, "deletionVector") then actionRecord[deletionVector] else null,
                        deletionVectorUrl =  if deletionVector <> null then deletionVector[pathOrInlineDv] else null
                    in
                        deletionVectorUrl
                ),

                fileUrls = List.Transform(Record.FieldNames(deltaSingleAction), (action) => 
                    let
                        actionRecord = Record.Field(deltaSingleAction, action),
                        fileUrl = if Record.HasFields(actionRecord, "path") then actionRecord[path] else null
                    in
                        fileUrl
                ),

                // Update fields in deltaSingleAction
                updatedActions = Record.TransformFields(deltaSingleAction, List.Transform(Record.FieldNames(deltaSingleAction), (action) =>
                {action, (actionRecord) =>
                    let
                        deletionVector =  if Record.HasFields(actionRecord, "deletionVector") then actionRecord[deletionVector] else null,
                        uuid =  if deletionVector <> null then Z85Encode(ExtractDeletionVectorUuid(deletionVector[pathOrInlineDv])) else null,
                        updatedDeletionVector = if uuid <> null then Record.TransformFields(deletionVector, {{"pathOrInlineDv", each uuid}, {"storageType", each "u"}}) else null, 
                        updatedActionRecord = if uuid <> null then Record.TransformFields(actionRecord, {{"deletionVector", each updatedDeletionVector}}) else actionRecord
                    in
                        Record.TransformFields(updatedActionRecord, {{"path", each ExtractFileName(_)}})
                })
                )
            in
                [deletionVectorUrls = List.RemoveNulls(deletionVectorUrls), fileUrls = List.RemoveNulls(fileUrls), updatedActions = updatedActions]
        ),

        // Flatten the list of URLs
        flattenedUrls = List.Combine(List.Transform(ProcessedData, each _[deletionVectorUrls])),

        fileUrls = List.Combine(List.Transform(ProcessedData, each _[fileUrls])),
        // Extract updated actions
        deltaActions = List.Transform(ProcessedData, each _[updatedActions])
    in
        [deltaActions = deltaActions, pathOrInlineDvUrls = flattenedUrls, fileUrls = fileUrls];


    FetchFileContentsDelta = (protocolString as text, deltaMetadata as record, filejson as list, rowLimitHint as number) as table =>
        let 
            numFiles = List.Count(fileUrls),

            result = ProcessDeltaActions(filejson),
            pathOrInlineDvUrls = result[pathOrInlineDvUrls],
            deltaActions = result[deltaActions],
            fileUrls = result[fileUrls],

            processedFiles = List.Transform(fileUrls, each ExtractFileInfo(_)),

            processedDeletionVector = List.Transform(pathOrInlineDvUrls, each ExtractFileInfo(_)),

            deltaMetadata = ExtractDeltaMetadata(deltaMetadata),
            metadataString = Text.FromBinary(Json.FromValue(deltaMetadata)),
            deltaActionString = Text.Combine(List.Transform(deltaActions, each Text.FromBinary(Json.FromValue(_))), "#(lf)"),
            
            // Combine protocol + metadata + action to format the delta log
            deltaLogBinary = Text.ToBinary(Text.Combine({protocolString,metadataString,deltaActionString}, "#(lf)")),
            deltaLog = MakeDirectory([#"00000000000000000000.json" = deltaLogBinary]),
            // Combine the DeltaLog and processed files into a single record
            combinedFiles = Record.Combine({
                [_delta_log = deltaLog],
                Record.FromList(List.Transform(processedFiles, each [Content]), List.Transform(processedFiles, each [Name])),
                Record.FromList(List.Transform(processedDeletionVector, each [Content]), List.Transform(processedDeletionVector, each [Name]))
            }),
            root = MakeDirectory(combinedFiles),
            deltaTable = DeltaLake.Table(root),

     // apply the rowLimit hint to the table
        withLimit =  Table.FirstN(deltaTable, rowLimitHint)
    in
        withLimit;


// ------------------------------- TEST ONLY ------------------------------- //
EmptyTable = (fileurl as text, cols) as table =>
    let
        contents = Binary.Buffer(Web.Contents(fileurl, [ManualCredentials = true]))
    in
        #table(cols, {});

ParquetDelayed = (fileurl as text, cols as any) as table =>
    Function.InvokeAfter(
        //() => Table.LastN(Parquet.Document(Binary.Buffer(Web.Contents(fileurl, [ManualCredentials = true]))), 100),
        () => ParquetFake(Binary.Buffer(ProtectSensitiveQueryParameters(fileurl, [ManualCredentials = true])), cols),
        #duration(0, 0, 0, 0)
    );

ParquetFake = (data as binary, cols as any) as table =>
    let
        t = #table({"id"}, {}),
        tt = Table.InsertRows(t, 0, {[id=Text.FromBinary(data)]})
    in
        tt;

// -------- TEST ONLY END -------- //
