[Version = "1.0.0"]
section VesselInsight;

// OAuth2 values
applicationId = "2907cb36-0073-4578-8e50-01ae917c1536";
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";

authorize_uri = "https://visales.kognif.ai/powerbi/";
intermediate_callback_uri = "https://visales.kognif.ai/powerbi/callback.html";
logout_uri = "https://login.microsoftonline.com/logout.srf";

galoreBaseUrl = "https://api.kognif.ai/Galore"; 
galoreApiQueryUrl = galoreBaseUrl & Extension.LoadString("GaloreApi"); 

[DataSource.Kind="VesselInsight", Publish="VesselInsight.Publish"]
// define the connector's datasource
shared VesselInsight.Contents = () =>
    let
        // get the asset tree roots from Galore, but limit the request to only few levels
        
        /* TODO: The current behavior is lazy but has an issue: when expanding a node on the 
           navigation tree, PowerBI would try to evaluate the children, and will invoke a subsequent
           request to expand their "edges" - resulting in multiple HTTP request sent when expanding nodes 
           (one for each child). 
           The end goal should be to send the HTTP request to load children only after the node is expanded, but
           so far we have not found a way to do this.
        */

        edgesRoot = galoreLoadEdges("~/", 2)[edges],

        // create the navigation table using data from the Galore tree structure
        // we will create two Level-1 items: Galore Data, and Advanced
        // Galore Data will show items from Galore's asset tree
        dataNodesRootTable = createNavTableObject(List.Transform(edgesRoot, each galoreEdgeToNavTableRow(_))),
        dataNodesRootRow = createNavTableDataRow(Extension.LoadString("TreeNodeGaloreDataLabel"), "Galore_Data_Root", dataNodesRootTable, "Folder", false),
        customTqlTable = createNavTableObject({
            createNavTableDataRow(Extension.LoadString("TreeNodeAdvancedTqlLabel"), "custom_tql_query", galoreCustomDataQuery(), "Function", true)
            }),
        advancedRootRow = createNavTableDataRow(Extension.LoadString("TreeNodeAdvancedLabel"), "advanced_node_root", customTqlTable, "Folder", false),

        navigationT = createNavTableObject({
            dataNodesRootRow,
            advancedRootRow
        })
    in
        navigationT;

// galoreLoadEdges: Used to load edges from the galore tree starting with the specified selector, with a certain depth
galoreLoadEdges = (selector as text, maxLevelsOfChildren as number) =>    
    let
        headers = [
            #"Content-type" = "application/json",
            #"Accept" = "application/json"
        ],
        galoreUrl = galoreBaseUrl 
            & "/v1/api/nodeselector?selector=" & Uri.EscapeDataString(selector)
            & "&maxLevelsOfChildren=" & Number.ToText(maxLevelsOfChildren),
        subtree = Json.Document(Web.Contents(galoreUrl, [ Headers = headers ])),
        firstNode = subtree{0}
    in
        firstNode;

getFullPathFromEventMetadata = (eventMetadata as any) =>
    let
        fullPath = if (eventMetadata[displayPath] <> null and eventMetadata[displayPath] <> "")
                   then eventMetadata[displayPath]
                   else if (eventMetadata[path] <> null and eventMetadata[path] <> "")
                        then eventMetadata[path]
                        else ""
    in
        fullPath;

// executeGaloreTqlQuery: Used to invoke a specific TQL query using the Galore Query API
executeGaloreTqlQuery = (galoreQueryText as text) =>
    let
        Headers = [
                #"Content-type" = "application/json",
                #"Accept" = "application/json"
            ],
        // Galore accepts JSON in the body
        parsedGaloreQueryJson = try Json.Document(galoreQueryText) otherwise null,
        // if the user did not supply a JSON, maybe it's just a simple TQL query - then we wrap it in a single-element json array
        galoreQuery = if (parsedGaloreQueryJson <> null) 
                then galoreQueryText
                else "[""" & galoreQueryText & """]",
        // invoke the query API
        queryResult = Json.Document(Web.Contents(galoreApiQueryUrl, [ Headers = Headers, Content = Text.ToBinary(galoreQuery)])),
		// convert metadata coming from Galore to columns in the results table
        metadataColumns = List.Transform(queryResult{0}[metadata][eventMetadata], each eventMetadataToColumnName(_)),
		// insert Timestamp and Vessel name columns as first columns
        columnsStep1 = List.InsertRange(metadataColumns, 0, { "Timestamp", "Vessel" }),
		// insert Full Path as the last column
		columns = List.InsertRange(columnsStep1, List.Count(columnsStep1), { "Full Path" }),
        // get the node path from either displayPath, or path (when displayPath is empty)
        fullPath = if (List.Count(queryResult{0}[metadata][eventMetadata]) > 0 ) 
            then getFullPathFromEventMetadata(queryResult{0}[metadata][eventMetadata]{0})
            else "",
		// find out the vessel name from the first metadata item - and do some safety checks in case we can't figure it out
		vesselName = if (fullPath <> "") 
			then splitAssetPathParts(fullPath){0}
			else "",
		// insert timestamp and vessel name in the first columns for each row, and enhance numeric values with metadata
        rowsStep1 = List.Transform(queryResult{0}[events],
            each List.InsertRange(enhanceEventValuesWithMetadata(_[values], queryResult{0}[metadata][eventMetadata]), 0, 
					{ 
						convertNumericTimestampToDateTime(_[time]),
						vesselName
					} )),
		// insert full path as the last column value for each row
		rows = List.Transform(rowsStep1, each List.InsertRange(_, List.Count(_), { fullPath } )),
        testForError = try rows,
        tableText = Table.FromRows(rows, columns),
        typeTransformations = List.Transform(columns, each ({_, 
			if _ = "Timestamp" then type datetime 
			else if _ = "Vessel" then type text
			else if _ = "Full Path" then type text
			else type number})),
        table = Table.TransformColumnTypes(tableText, typeTransformations),
        output = if testForError[HasError] then error Error.Record(Extension.LoadString("ErrorOccurred"), null, queryResult{0}[error]) else table
    in
        output;

// Referred by the Navigation Table (the "Advanced" node) for calling a TQL
galoreCustomDataQuery = () => 
    let
        functionReturn = executeGaloreTqlQuery,
        // wrap the documentation object around the function for the UI to show info and suggestions
        functionReturnExplained = Value.ReplaceType(functionReturn, galoreCustomDataQueryType)
    in
        functionReturnExplained;

// Referred by the Navigation Table in each of the Assets' tree timeseries node, for getting the data on a particular asset
galoreEdgeDataQuery = (nodeId as text) => 
    let 
        functionReturn = (optional interval as text, optional timeDimensionType as text, optional startDate as text, optional endDate as text, optional customPipe as text)=>
            let
                timeDimensionTypeValue = if (timeDimensionType = null or timeDimensionType = "") then "latest" else Text.Lower(timeDimensionType),
                inputValidationError = 
                    // validate time mode
                    if (timeDimensionTypeValue <> "latest" and timeDimensionTypeValue <> "period" and timeDimensionTypeValue <> "custom")
                    then error Error.Record(Extension.LoadString("InvalidParameters"), null, Extension.LoadString("InvalidParametersMesg")) 
                    // validate parameters for mode "Latest"
                    else if (timeDimensionTypeValue = "latest"
                        and ((startDate <> null and startDate <> "") 
                             or (endDate <> null and endDate <> "")
                             or (customPipe <> null and customPipe <> "")))
                    then error Error.Record(Extension.LoadString("InvalidParameters"), null, Extension.LoadString("InvalidParametersMesg2"))
                    // validate parameters for mode "Period"
                    else if (timeDimensionTypeValue = "period" 
                        and ((startDate = null or startDate = "") 
                             or (endDate = null or endDate = "")))
                    then error Error.Record(Extension.LoadString("InvalidParameters"), null, Extension.LoadString("InvalidParametersMesg3"))
                    else if (timeDimensionTypeValue = "period"
                        and (customPipe <> null and customPipe <> ""))
                    then error Error.Record(Extension.LoadString("InvalidParameters"), null, Extension.LoadString("InvalidParametersMesg4"))
                    // validate parameters for mode "Custom"
                    else if (timeDimensionTypeValue = "custom"
                        and ((startDate <> null and startDate <> "") 
                             or (endDate <> null and endDate <> "")))
                    then error Error.Record(Extension.LoadString("InvalidParameters"), null, Extension.LoadString("InvalidParametersMesg5"))
                    else if (timeDimensionTypeValue = "custom"
                        and (customPipe = null or customPipe = ""))
                    then error Error.Record(Extension.LoadString("InvalidParameters"), null, Extension.LoadString("InvalidParametersMesg6"))
                    else null,

                // generate the TQL query based on the parameters
                timeValue = if (timeDimensionTypeValue = "latest") then
                                "|> takebefore now 1"
                             else if (timeDimensionTypeValue = "period") then
                                "|> takefrom " & startDate & " |> taketo " & endDate
                            else
                                customPipe,
                intervalValue = if (interval = null or interval = "") then "" else interval,
                galoreQuery = "[""input #" & nodeId & " " & intervalValue & " " & timeValue & """]", 
                galoreQueryResult = if inputValidationError = null 
                    then executeGaloreTqlQuery(galoreQuery)
                    else inputValidationError
            in
                galoreQueryResult,
        // wrap the documentation object around the function for the UI to show info and suggestions
        functionReturnExplained = Value.ReplaceType(functionReturn, galoreEdgeDataQueryType)
    in
        functionReturnExplained;


// creates a row in the Navigation Table for information on a single vessel
createVesselInfoRow = (edgeTarget as any) => 
    let
        processedAttributes = Record.TransformFields(edgeTarget[attributes], {
                { Extension.LoadString("Particulars"), each try Json.Document(_) otherwise _}
            }),
        attributeNames = Record.FieldNames(processedAttributes),
        attributeValues = Record.FieldValues(processedAttributes),
        
        nodeName = "Vessel Info (" & edgeTarget[name] & ")",
        rowData = () => let rdata = Table.FromRows({ attributeValues }, attributeNames) in rdata,
        result = { createNavTableDataRow(nodeName, "Node_" & edgeTarget[nodeId] & "_Vessel_Info", rowData, "Function", true) }
    in
        result;

// creates a row in the Navigation Table for information on all vessels
createAllVesselsInfoRow = (vesselEdges as list) => 
    let
        processedEdges = List.Transform(vesselEdges, each [
            displayName = if Record.HasFields(_[target][attributes], "displayName") then _[target][attributes][displayName] else _[target][displayName],
            paths = if Record.HasFields(_[target][attributes], "paths") then _[target][attributes][paths] else "",
            imageURL = if Record.HasFields(_[target][attributes], "imageURL") then _[target][attributes][imageURL] else "",
            imo = if Record.HasFields(_[target][attributes], "imo") then _[target][attributes][imo] else "",
            particulars = if Record.HasFields(_[target][attributes], "particulars") 
                then try Json.Document(_[target][attributes][particulars]) 
                     otherwise _[target][attributes][particulars] 
                     else "",
            typeSizeID = if Record.HasFields(_[target][attributes], "typeSizeID") then _[target][attributes][typeSizeID] else "",
            connectionStatus = if Record.HasFields(_[target][attributes], "connectionStatus") then _[target][attributes][connectionStatus] else ""
        ]),
        
        columnNames = { "Display Name", "Paths", "Image URL", "IMO", "Particulars", "TypeSizeID", "Connection Status" },
        attributeValues = List.Transform(processedEdges, each Record.FieldValues(_)),
        
        nodeName = Extension.LoadString("VesselInfoAll"),
        rowData = () => let rdata = Table.FromRows(attributeValues, columnNames) in rdata,
        result = { createNavTableDataRow(nodeName, "Node_Vessel_Info_AllVessels", rowData, "Function", true) }
    in
        result;



// Creates a row in the Navigation table from a Galore asset (edge)
galoreEdgeToNavTableRow = (edge as any) =>
    let 
        edgeTarget = edge[target],
        isTimeSeriesNode = Text.Lower(edgeTarget[attributes][nodeType]) = "timeseries",
        isVessel = Record.HasFields(edgeTarget[attributes],"nodeDefinitionId") and edgeTarget[attributes][nodeDefinitionId] = Extension.LoadString("VIVessel"),
        isFleet = Text.Lower(edgeTarget[name]) = "fleet",   // the fleet node is called "Fleet"
        hasEdges = (not isTimeSeriesNode) and edgeTarget[hasEdges],     // limitation: cannot be timeseries node and have children at the same time
        isLeaf = not hasEdges, 
        isLoaded = List.Count(edgeTarget[edges]) > 0,   // if we have edges in the sub-edges list, this means that we've already loaded the child edges,

        // specify the data for this row: 
        //      if this is a leaf row, the data will be a function
        //      if this is a parent row, the data will be another navigation table 
        
        // the source of data is the [edges] field of the current edge
        childNavTableDataRowsSource = if (isLoaded)
            then edgeTarget[edges]   // already loaded
            else 
                galoreLoadEdges("#" & edgeTarget[nodeId], 1)[edges],     // not loaded yet, we need to load the next level

        // when this edge has sub-edges, we recursively call the function itself for each of the sub-edges, in order to create the subtree for this item
        childNavTableDataRows = List.Transform(childNavTableDataRowsSource,
            each 
                try @galoreEdgeToNavTableRow(_) 
                otherwise null),   // add a null row when there's an error
        
        // generate a vessel info row if this is a vessel or a fleet node
        vesselInfoRow = if ((not isVessel) and (not isFleet)) then { }     // if this is not a vessel or fleet, insert nothing
            else if (isVessel) then createVesselInfoRow(edgeTarget)     // if this is a vessel, insert a vessel info node
            else createAllVesselsInfoRow(edgeTarget[edges]), // if this is Fleet, insert all vessels info node
        
        // clean up null rows and add vessel info row
        childNavTableDataRowsFinal = List.RemoveNulls(  // filter out the null rows (rows with errors)
            List.InsertRange(childNavTableDataRows, 0, vesselInfoRow)),

        rowData = if (hasEdges) 
            then createNavTableObject(childNavTableDataRowsFinal)    // this is a parent, we create a child navigation table for it
            else galoreEdgeDataQuery(edgeTarget[nodeId]),  // this is a leaf node, we create a data query function row

        itemKind = if isLeaf then "Function" else "Folder",     // when preview delay is disabled, all folders show as tables for some reason 
        result = createNavTableDataRow(edgeTarget[displayName], "Node_" & edgeTarget[nodeId], rowData, itemKind, isLeaf)
    in 
        result;

// Creates a row object for the navigation table row's data, using a list of sub-rows (for nested navigation structure)
createNavTableObject = (dataRows as list) => 
    let
        enablePreviewDelay = false,         // required in order to enable functions preview,  reference https://github.com/Microsoft/DataConnectors/issues/30
        tobjects = Table.FromRows(dataRows, { "Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf" }),
        typedTable = Table.TransformColumnTypes(tobjects, { 
            { "Name", type text },
            { "Key", type text },
            { "ItemKind", type text },
            { "ItemName", type text },
            { "IsLeaf", type logical }
            }),
        navtableResult = Table.ToNavigationTable(typedTable, {"Key"}, "Name", "Data", "ItemKind", if enablePreviewDelay then "ItemName" else "", "IsLeaf")
    in
        navtableResult;

// --------------------------------------------------------------------------------------------
// Handling authentication for the connector
// --------------------------------------------------------------------------------------------

VesselInsight = [
    TestConnection = (dataSourcePath) => { "VesselInsight.Contents" },
    Label = Extension.LoadString("DataSourceLabel"),
    // Define the authentication mechanism
    Authentication = [
        // Describe OAuth authentication and hook up the necessary functions
		OAuth = [
		    StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh,
            Logout = Logout
		]
    ]
];

// The StartLogin method defines the starting point of the authentication process by specifying the login and callback URLs for the authentication window
StartLogin = (resourceUrl, state, display) =>
    let
        // we want to use OAuth authorization_code flow with PKCE (Proof Key for Code Exchange)
        // https://tools.ietf.org/html/rfc7636#page-8
        // https://docs.microsoft.com/en-us/azure/active-directory/develop/v1-protocols-oauth-code

        // to use the authorization_code flow with PKCE, we need to generate a code verifier (ref. https://tools.ietf.org/html/rfc7636#page-8)
        // it needs to be a random string which is impossible (or very difficult) to be generated on another client
        // so we use two concatenated GUIDs which should ensure the uniqueness of the verifier
	    codeChallenge = Text.NewGuid() & Text.NewGuid(), // min length: 43 
	
        authorizeUrl = authorize_uri & "?" & Uri.BuildQueryString([
            response_type = "code",             // we request the authorization code as a response
            resource = applicationId,           // the OIDC client id (Azure AD application id) that we use
            client_id = applicationId,  
            scope = "openid profile",           // we request the required OIDC scopes
            redirect_uri = redirect_uri,
            code_challenge_method = "plain",    // we send the code_challenge as plain text     // TODO
            code_challenge = codeChallenge,     // the code_challenge
	        state = state
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = 720,
            WindowWidth = 1024,
            Context = codeChallenge
        ];

// The FinishLogin method defines the final point of the authentication process - after the browser in the authentication window
// has been navigated to the final URL. In the authorization_code flow, we get an authorization code and exchange it with a token
FinishLogin = (context, callbackUri, state) =>
    let
        // we get the authorization code in the query string of the callback
        parts = Uri.Parts(callbackUri)[Query],

        // tenant ID should be available in the querystring as kognifaitenant
	    tenantId = parts[kognifaitenant],

        // we check for errors (query string contains "error" and "error_description" parameters)
        // and if there are no errors, we get the access token
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    TokenMethod("authorization_code", "code", parts[code], tenantId, context)
    in
        result;

// The TokenMethod exchanges an authorization code or a refresh token with an access token
TokenMethod = (grantType as text, tokenField as text, code as text, tenantIdParam as text, optional codeVerifier as text, optional oldCredential) =>
    let
        isRefreshRequest = grantType = "refresh_token",

        // if this is a refresh_token request, the tenantId can be found in the oldCredential record (we put it there)
        // otherwise we expect it to be passed as a parameter from the FinishLogin function
        tenantId = if (isRefreshRequest) then oldCredential[tenant_id] else tenantIdParam,
        
        // if this is a refresh_token request, we get the code from the oldCredential record, 
        // otherwise we expect it to be passed as a parameter from the FinishLogin function
        actualCode = if (isRefreshRequest) then oldCredential[refresh_token] else code,

        
        // construct the token endpoint URL using the tenant ID
        tokenEndpointUrl = Text.Format(Extension.LoadString("TokenUrlFormat"), { tenantId }),

        // we build the request that we will send to the token endpoint
        queryStringInitial = [
            grant_type = grantType, 
            redirect_uri = intermediate_callback_uri,
            client_id = applicationId
        ],

        // code_verifier is only needed when we exchange authorization code with a token
        queryStringWithCodeVerifier = if (isRefreshRequest) then queryStringInitial else Record.AddField(queryStringInitial, "code_verifier", codeVerifier),
        
        // add the authorization code to the request
        queryString = Record.AddField(queryStringWithCodeVerifier, tokenField, actualCode),

        // we send a POST request to the token endpoint
        tokenResponse = Web.Contents(tokenEndpointUrl, [
            ManualCredentials = true,   // we do not need to send the Authorization header to the token endpoint
            Content = Text.ToBinary(Uri.BuildQueryString(queryString)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = {400, 401} 
        ]),

        // if there are no errors, the response should contain the access_token
        body = Json.Document(tokenResponse),
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body)
                 else 
                    // on successfull login, we store the tenant_id in the result, so it will be available for refresh_token requests in oldCredential
                    Record.AddField(body, "tenant_id", tenantId)
        in
            result;

// The Refresh method handles refreshing of the access token when it is expired. It uses the TokenMethod to exchange the refresh token with a new access token
Refresh = (clientApplication, resourceUrl, oldCredential) => TokenMethod("refresh_token", "refresh_token", "", "", null, oldCredential);

// Navigates to the logout url
Logout = (token) => logout_uri;

// --------------------------------------------------------------------------------------------
// Publishing information to the Power BI UI

// Data Source UI publishing description
VesselInsight.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = VesselInsight.Icons,
    SourceTypeImage = VesselInsight.Icons
];

VesselInsight.Icons = [
    Icon16 = { Extension.Contents("Logo.png"), Extension.Contents("Logo.png"), Extension.Contents("Logo.png"), Extension.Contents("Logo.png") },
    Icon32 = { Extension.Contents("Logo.png"), Extension.Contents("Logo.png"), Extension.Contents("Logo.png"), Extension.Contents("Logo.png") }
];

// --------------------------------------------------------------------------------------------
// Local utility functions
// --------------------------------------------------------------------------------------------

splitAssetPathParts = (assetPath as text) => 
	let 
		// Full Path: /Fleet/Malabar/Engines/Main/1/Engine Power
		// Part 1: Vessel name -> Malabar
		// Part 2: Asset path -> Engines/Main/1/Engine Power
		parts = Text.Split(Text.TrimStart(assetPath, "/"), "/"),
		result = if (List.Count(parts) > 2) then {
				parts{1},
				Text.Combine(List.RemoveFirstN(parts, 2), "/")
			}
			else { assetPath }
	in
		result;

eventMetadataToColumnName = (eventMetadata as any) =>
    let
        path = getFullPathFromEventMetadata(eventMetadata),
        valueType = Text.TrimStart(Text.Replace(eventMetadata[displayName], "input1",""), "_"),
		pathParts = splitAssetPathParts(path),
		// we will only use the asset path part as the column name
		assetPath = if (List.Count(pathParts) > 1) then pathParts{1} else pathParts{0},
        columnName = assetPath & (if (valueType = null or valueType = "") then "" else (" (" & valueType & ")" ))
    in
        columnName;

enhanceEventValuesWithMetadata = (eventValues as list, eventMetadataList as list) =>
    let
        transformedEvents = List.Transform(eventValues, each _ meta [ 
            Name = eventMetadataList{List.PositionOf(eventValues,_)}[name],
            Unit = eventMetadataList{List.PositionOf(eventValues,_)}[unitSymbol],
            Path = eventMetadataList{List.PositionOf(eventValues,_)}[path]
            ])
    in
        transformedEvents;

// --------------------------------------------------------------------------------------------
// Utility functions loaded from other files
// --------------------------------------------------------------------------------------------

// TEMPORARY WORKAROUND until PowerQuery M is able to reference other M modules
// This function will just load a text file and evaluate it
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

galoreCustomDataQueryType = Extension.LoadFunction("Documentation.galoreCustomDataQueryType.pqm");
galoreEdgeDataQueryType = Extension.LoadFunction("Documentation.galoreEdgeDataQueryType.pqm");
Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");
createNavTableDataRow = Extension.LoadFunction("Table.createNavTableDataRow.pqm");
convertNumericTimestampToDateTime = Extension.LoadFunction("Util.convertNumericTimestampToDateTime.pqm");

