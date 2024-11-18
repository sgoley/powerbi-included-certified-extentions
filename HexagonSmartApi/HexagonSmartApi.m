//Smart API Connection 
//Aug 9 2018 changes:
//  Add TestConnection function to support PBI Gateway.   Set beta flag to false.
//May 24 2018 bugs fixed:   
//  Detect trailing slash on OpenId Configuration url
//  Detect Ping Identity STS ping_end_session_endpoint
//Jan 18 2019 changes:
//  Add support for auth_parameter file.  Contents are appended to the OAuth authorize
//    request.  Useful for specifying external IdP.  For example: 
//    To specify an external IdP using Smart API Manager, add this text to the auth_parameter file:  &acr_values=idp:F53ECC91-08DB-4B4A-8C40-99C6B4D010DD
//    To specify an external IdP using Okta, add this text to the auth_parameter file: &idp=idpid
//Feb 11 2019 changes:
//  Add support for Implementation 2.0 option true/false.   If true, use Implementation 2.0 else use prior version.
//    Leave SmartAPIOData.Feed() function untouched to preserve existing .pbix, .pbit files that use this function.
//    Create a new SmartAPIOData.FeedV2() function that is published to the UI and defaults to Implementation 2.0.
//July 8 2019 changes:
//  Major updates to support OData+ parametric filters.
//  Also, changed to trusted 3rd party connector with signed IntergraphSmartApiV(X).pqx file.
//November 18 2019 changes:
//  Fix data source definition to support Power BI Gateway
//  Major update to include select lists
//  Add logging and diagnostics support for auth and select lists
//December 16 2019 changes:
//  Allow empty client secret to be set as allowed in OAuth and OIDC specs.  
//  Now always read client ID and client secret from the client_id and client_secret files.  Set the standard values in these files.
//January 22 2019 changes:
//  Add support for OData typecast.
//April 3 2020 changes:
//  Add support for Units of Measure conversion.
//May 7 2020 changes:
//  Bug fixes for parametric filter JSON request.  Collections were not properly handled.
//May 27 2020 changes:
//  Rename to HexagonSmartApi for connector certification.  Rename DataSourceKind to prevent collision with on-prem version.  Remove old Feed function and rename FeedV2 to Feed.
//July 17 2020 changes:
//  Respond to Microsoft certification- Allow disabling of logging. Remove CurrentCredentials() calls.
//April 23 2022 changes:
//  Work around issue in Power BI Desktop when using Okta auth server. Okta logout returns a 400 and causes PBI to throw an exception.

[Version = "1.2.0"]
section HexagonSmartApi;



//
// Exported function
//
[DataSource.Kind="HexagonSmartApi", Publish="HexagonSmartApi.Publish"]
shared HexagonSmartApi.Feed = Value.ReplaceType(SmartApiFeedImpl, SmartApiFeedType);

uriType = Uri.Type meta [Documentation.FieldCaption = Extension.LoadString("HexagonSmartApi.Feed.Parameter.url.FieldCaption"),
                         Documentation.FieldDescription = "",  //pbi bug.  does not work
                         Documentation.SampleValues = {Extension.LoadString("HexagonSmartApi.Feed.Parameter.url.SampleValues")}];

headersType = type text meta [Documentation.FieldCaption = Extension.LoadString("HexagonSmartApi.Feed.Parameter.headers.FieldCaption"),
                              Documentation.FieldDescription = "",  //pbi bug.  does not work
                              Documentation.SampleValues = {Extension.LoadString("HexagonSmartApi.Feed.Parameter.headers.SampleValues")}];

odataFeedVersion = type text meta [Documentation.FieldCaption = Extension.LoadString("HexagonSmartApi.Feed.Parameter.odataFeedVersion.FieldCaption"),
                                   Documentation.FieldDescription = "",  //pbi bug.  does not work
                                   Documentation.AllowedValues = {"1.0", "2.0"},
                                   Documentation.SampleValues = {"2.0"}];

SmartApiFeedType = type function (url as uriType, optional headers as headersType, optional odataFeedVersion as odataFeedVersion) as table 
                            meta [Documentation.Name = Extension.LoadString("HexagonSmartApi.Feed.Function.DisplayName"),
                                  Documentation.LongDescription = Extension.LoadString("HexagonSmartApi.Feed.Function.LongDescription"),
                                  Documentation.Examples = {[Description = Extension.LoadString("HexagonSmartApi.Feed.Documentation.Examples"),
                                                             Code = "HexagonSmartApi.Feed(""https://example.com/SampleService/V1"")",
                                                             Result = "#table({""Name""}, {{""Data""}, {""Signature""}})"]}];

ParseHeaders = (headers as text) as record =>
    let
        //support "x=a,y=b[,...]"
        headersClean = Text.Clean(headers),
        headersNoWS = Text.Remove(headersClean, " "),
        headerList = Text.Split(headersNoWS, ","),
        headerTable = Table.FromList(headerList, Splitter.SplitTextByDelimiter("="), {"Name", "Value"}),
        headerRecord = Record.FromTable(headerTable)
    in
        headerRecord;

metadataAnnotations = "Org.OData.Capabilities.V1.*,Com.Ingr.Core.V1.*";
instanceAnnotations = "Org.OData.Capabilities.V1.*,Com.Ingr.Core.V1.*";

SmartApiFeedImpl = (url as text, optional headers as text, optional odataFeedVersion as text) as table =>
    let
        validUrl = ValidateUrlScheme(url),   
        headerRecord = if (headers = null) then null 
                       else 
                           try ParseHeaders(headers)
                           otherwise error Error.Record("Error",
                                                        Extension.LoadString("HexagonSmartApi.Feed.Error.Headers") &
                                                        Extension.LoadString("HexagonSmartApi.Feed.Parameter.headers.SampleValues")),
        oDataOptions = if (odataFeedVersion = "2.0" or odataFeedVersion = "" or odataFeedVersion = null)
                                    then [
                                              ODataVersion = 4.0, 
                                              MoreColumns = true, 
                                              Implementation = "2.0",
                                              IncludeMetadataAnnotations = metadataAnnotations,
                                              IncludeAnnotations = instanceAnnotations
                                         ]
                                    else [
                                              ODataVersion = 4.0, 
                                              MoreColumns = true
                                         ],
        //remember the data source url
        content = OData.Feed(validUrl, headerRecord, oDataOptions),
        uriParts = Uri.Parts(validUrl),
        host = uriParts[Host],

        contentwithpf = Table.InsertRows(content, Table.RowCount(content), {[Name = "Create Parametric Filter Function(" & host & ")", 
                                         Data = GenerateNavTableFilterFunction(validUrl), Signature = "function"]}),
        contentwithsl = Table.InsertRows(contentwithpf, Table.RowCount(contentwithpf), {[Name = "Apply Select List(" & host & ")", 
                                         Data = GenerateNavTableSelectListFunction(validUrl), Signature = "function"]}),
        contentwithuom = Table.InsertRows(contentwithsl, Table.RowCount(contentwithsl), {[Name = "Apply Units of Measure(" & host & ")", 
                                         Data = GenerateNavTableUoMFunction(validUrl), Signature = "function"]}),
        contentwithuomrefdata = Table.InsertRows(contentwithuom, Table.RowCount(contentwithuom), {[Name = "Units of Measure Reference Data", 
                                         Data = UnitsOfMeasureReferenceData, Signature = "table"]}),

        // Include all navigation table metadata from the OData.Feed table
        // This metadata is otherwise lost within Table.TransformColumns()
        tfTable = AppendMetadata(content, contentwithuomrefdata)
    in
        tfTable;

// Append metadata to the destination item from the source item.  This is not table specific
AppendMetadata = (source as table, destination as table) as table =>
    let
        // Retrieve all metadata from the source table type
        sourceTypeMetadata = Value.Metadata(Value.Type(source)),

        // Retrieve the type of the destination table and append the source table metadata to its own metadata
        newDestinationType = Value.Type(destination) meta sourceTypeMetadata,

        // Replace the type of the destination table with the new type containing metadata from both tables.
        newDestination = Value.ReplaceType(destination, newDestinationType)
    in
        newDestination;

// Data Source definition
HexagonSmartApi = [
    TestConnection = (dataSourcePath) => {"HexagonSmartApi.Feed", dataSourcePath},
    Authentication = [
        OAuth = [
            StartLogin = OAuth.StartLogin,
            FinishLogin = OAuth.FinishLogin,
            Refresh = OAuth.Refresh,
            Logout = OAuth.Logout,
            Label = Extension.LoadString("HexagonSmartApi.Feed.Function.DisplayName")
        ]
    ],
    Label = Extension.LoadString("HexagonSmartApi.Authentication.Label")
];

// Publish definition
HexagonSmartApi.Publish = [
    Beta = false,
    ButtonText = { Extension.LoadString("HexagonSmartApi.Feed.Function.DisplayName"), Extension.LoadString("HexagonSmartApi.Feed.Button.Description") },
    SourceImage = HexagonSmartApi.Icons,
    SourceTypeImage = HexagonSmartApi.Icons
];

HexagonSmartApi.Icons = [
    Icon16 = { Extension.Contents("HxGn-logo-full-color16.png"), Extension.Contents("HxGn-logo-full-color20.png"),Extension.Contents("HxGn-logo-full-color24.png"), Extension.Contents("HxGn-logo-full-color32.png") },
    Icon32 = { Extension.Contents("HxGn-logo-full-color32.png"), Extension.Contents("HxGn-logo-full-color40.png"),Extension.Contents("HxGn-logo-full-color48.png"), Extension.Contents("HxGn-logo-full-color64.png") }
];




//
//Helpers
//

ValidateUrlScheme = (url as text) as text => if (Uri.Parts(url)[Scheme] <> "https") then error "Url scheme must be HTTPS" else url;

//Get OData metadata
[DataSource.Kind="HexagonSmartApi"]
shared HexagonSmartApi.GetODataMetadata = Value.ReplaceType(SmartApiGetODataMetadataImp, type function(url as uriType, optional includeAnnotations as logical) as any);
SmartApiGetODataMetadataImp = (url as text, optional includeAnnotations as logical) => 
    let
        validUrl = ValidateUrlScheme(url),
        hr1 = [#"OData-MaxVersion"="4.0"],
        headerRecord =  if (includeAnnotations = true) then 
                            Record.AddField(hr1, "Prefer", "odata.include-annotations=""Org.OData.Capabilities.V1.*,Com.Ingr.Core.V1.*""")
                        else
                            hr1,
        result = Xml.Tables(Web.Contents(validUrl,
                [
                    Headers = headerRecord,
                    RelativePath = "$metadata"
                ]   
            ))
    in
        result;

//
// End Helpers
//

// 
// Load common library functions
// 
// TEMPORARY WORKAROUND until we're able to reference other M modules
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

OAuth = Extension.LoadFunction("OAuth.pqm");
OAuth.StartLogin = OAuth[StartLogin];
OAuth.FinishLogin = OAuth[FinishLogin];
OAuth.Refresh = OAuth[Refresh];
OAuth.Logout = OAuth[Logout];

ParametricFilter = Extension.LoadFunction("ParametricFilter.pqm");
GenerateNavTableFilterFunction = ParametricFilter[GenerateNavTableFilterFunction];
shared HexagonSmartApi.GenerateParametricFilterByFilterSourceType = ParametricFilter[GenerateParametricFilterByFilterSourceType];
shared HexagonSmartApi.ExecuteParametricFilterOnFilterRecord = ParametricFilter[ExecuteParametricFilterOnFilterRecord];
shared HexagonSmartApi.ExecuteParametricFilterOnFilterUrl = ParametricFilter[ExecuteParametricFilterOnFilterUrl];

//DEBUG - Remove before release
//shared HexagonSmartApi.GenerateParametricFilterFunctionDef = ParametricFilter[GenerateParametricFilterFunctionDef];
//shared HexagonSmartApi.ParametricFilterDefinition = ParametricFilter[ParametricFilterDefinition]; 
//shared HexagonSmartApi.GetFilterActions = ParametricFilter[GetFilterActions];
//shared HexagonSmartApi.GetFilterActionParameterNames = ParametricFilter[GetFilterActionParameterNames];
//END DEBUG

SelectList = Extension.LoadFunction("SelectList.pqm");
GenerateNavTableSelectListFunction = SelectList[GenerateNavTableSelectListFunction];
shared HexagonSmartApi.ApplySelectList = SelectList[ApplySelectList];

Typecast = Extension.LoadFunction("Typecast.pqm");
shared HexagonSmartApi.Typecast = Typecast[Typecast];

UnitsOfMeasure = Extension.LoadFunction("UoM.pqm");
GenerateNavTableUoMFunction = UnitsOfMeasure[GenerateNavTableUoMFunction];
shared HexagonSmartApi.ApplyUnitsOfMeasure = UnitsOfMeasure[ApplyUnitsOfMeasure];
UnitsOfMeasureReferenceData = UnitsOfMeasure[UoMReferenceData];
