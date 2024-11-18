[Version = "1.0.5"]
section Fhir;

GetAuthorizationUriForCommonTenant = () as text => 
    let
        // We want the connector to use production instances of the data source.
        // If we're running in a PPE host environment, override the AAD endpoint to use global.
        defaultAadUri = "https://login.microsoftonline.com/",
        isPpeCloud = Environment.FeatureSwitch("Cloud", "global") = "ppe",
        aadUriEnvConfig = Environment.FeatureSwitch("AzureActiveDirectoryUri", defaultAadUri),
        aadUri =
            if (isPpeCloud) then
                defaultAadUri
            else
                aadUriEnvConfig
    in
        Uri.Combine(aadUri, "/common/oauth2/authorize");

// Data Source Kind description
Fhir = [
    // TestConnection for Gateway support: https://docs.microsoft.com/en-us/power-query/handlinggatewaysupport
    TestConnection = (dataSourcePath) => { "Fhir.Contents", dataSourcePath },
    Authentication = [
        Aad = [
            AuthorizationUri = (resource) => GetAuthorizationUriForCommonTenant()
        ],
        Anonymous = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
Fhir.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    SourceImage = Fhir.Icons,
    SourceTypeImage = Fhir.Icons
];

Fhir.Icons = [
    Icon16 = { Extension.Contents("icon-fhir-16.png"), Extension.Contents("icon-fhir-20.png"), Extension.Contents("icon-fhir-24.png"), Extension.Contents("icon-fhir-32.png")},
    Icon32 = { Extension.Contents("icon-fhir-32.png"), Extension.Contents("icon-fhir-40.png"), Extension.Contents("icon-fhir-48.png"), Extension.Contents("icon-fhir-64.png") }
];

Fhir.Contents.Type = type function (
    url as (Uri.Type meta [
        Documentation.FieldCaption = Extension.LoadString("UrlFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("UrlFieldDescription")
    ]),
    optional searchQuery as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("SearchQueryFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("SearchQueryFieldDescription"),
        Documentation.SampleValues = { "Patient?address-postalcode=98052" }
    ])
)
as table;

[DataSource.Kind="Fhir", Publish="Fhir.Publish"]
shared Fhir.Contents = Value.ReplaceType(FhirNavTable, Fhir.Contents.Type);

FhirNavTable = (url as text, optional searchQuery as text) as table =>
    let
        // Find the intersection between the resources listed in schema table, capabilities, and query
        Metadata =
            let
                uriParts = Uri.Parts(url),
                metadataUri = Uri.Combine(url, Text.TrimEnd(uriParts[Path], "/") & "/metadata"),
                response = Web.Contents(metadataUri, [ Headers = [ Accept = "application/json" ] ]),
                body = Json.Document(response),
                resource = List.First(body[rest])[resource],
                resourceList = List.Transform(resource, each [type]),
                fhirVersionString = body[fhirVersion],
                _fhirVersion =
                    if Text.StartsWith(fhirVersionString, "1.") then "DSTU2" else
                    if Text.StartsWith(fhirVersionString, "3.") then "STU3" else
                    if Text.StartsWith(fhirVersionString, "4.") then "R4" else error(Text.Format(Extension.LoadString("UnknownFhirVersionError"), fhirVersionString)),
                fhirVersion = Diagnostics.Trace(TraceLevel.Information, "fhirVersion: " & _fhirVersion, _fhirVersion)
            in
                [
                    ResourceList = resourceList,
                    FhirVersion = fhirVersion
                ],
        GetResourceListFromQueryString = (q as text) => { Text.TrimStart(List.First(Text.Split(q, "?")), "/") },
        GetResourceList = (url as text, optional queryString as text) =>
            let
                metadataResources = Metadata[ResourceList],
                intersectWithQuery =
                    // if queryString is null, Text.Split() in GetResourceListFromQueryString() function will throw an exception:
                    // "We cannot convert the value null to type Text."
                    //
                    // if queryString is "", the result of GetResourceListFromQueryString is {""}, 
                    // and the result of List.Intersect is {},
                    // no resouces will be returned to the users in this case,
                    // so if queryString is "", just ignore it, and return all metadataResources to the users
                    if queryString <> null and queryString <> "" then
                        List.Intersect({ GetResourceListFromQueryString(queryString), metadataResources })
                    else
                        metadataResources,
                intersectWithSchemaTable = List.Intersect({intersectWithQuery, resourceTypeNames})
            in
                intersectWithSchemaTable,
        fhirVersion = Metadata[FhirVersion],
        // Use our schema table as the source of top level items in the navigation tree
        versionSchemaTable = Record.Field(SchemaTable, fhirVersion),
        resourceTypeNames = Table.ToList(Table.SelectColumns(versionSchemaTable, { "ResourceTypeName" })),
        //Find intersection
        resourceIntersection = GetResourceList(url, searchQuery),
        renamed = Table.FromList(resourceIntersection, null, { "Name" }),
        // Add Data as a calculated column
        withData = Table.AddColumn(renamed, "Data", each Fhir.View(url, [Name], fhirVersion, searchQuery), type table),
        // Add ItemKind and ItemName as fixed text values
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Table", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table", type text),
        // Indicate that the node should not be expandable
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true, type logical),
        // Generate the nav table
        navTable = Table.ToNavigationTable(withIsLeaf, { "Name" }, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

Fhir.View = (baseUrl as text, resourceTypeName as text, fhirVersion as text, optional searchQuery as text) as table =>
    let
        View = (state as record) => Table.View(null, Diagnostics.WrapHandlers([

            // Returns the table type returned by GetRows()
            GetType = () =>
                let
                    versionedSchemaTable = Record.Field(SchemaTable, fhirVersion)
                in
                    try
                        versionedSchemaTable{[ ResourceTypeName = resourceTypeName ]}[Type]
                    otherwise
                        error Text.Format(Extension.LoadString("UnknownResourceTypeNameError"), {resourceTypeName}),

            // Called last - retrieves the data from the calculated URL
            GetRows = () =>
                let
                    tableType = GetType(),

                    // Fold SelectRows expression into a FHIR search query
                    expressionToFold = state[SelectRowsExpression]?,
                    versionedFoldPatterns = Record.Field(FoldPatterns, fhirVersion),
                    foldedQuery = if expressionToFold = null then "" else Fold(tableType, expressionToFold, versionedFoldPatterns{[ResourceTypeName = resourceTypeName]}[Patterns]),

                    // Calculate the URL with and without folding.
                    // We fall back to the URL without folding if the folded query fails.
                    // This can happen for instance when a FHIR server does not support a search parameter modifier.
                    urlWithFolding = CalculateUrl(foldedQuery),
                    urlWithoutFolding = CalculateUrl(""),

                    rows = GetAllResourcesWithoutSchema(urlWithFolding, urlWithoutFolding),

                    table = Table.FromRecords(ReshapeRows(rows), tableType),

                    // perform in-memory filtering on the result
                    selector = state[SelectRowsSelector]?,
                    filtered = if selector = null then table else Table.SelectRows(table, selector)
                in
                    filtered,

            OnSelectRows = (selector) =>
                let
                    selectorExpression = RowExpression.From(selector),
                    existingExpression = state[SelectRowsExpression]?,
                    combinedExpression = if existingExpression = null then selectorExpression else [ Kind = "Binary", Operator = "And", Left = existingExpression, Right = selectorExpression ],
                    existingSelector = state[RowExpressionSelector]?,
                    combinedSelector = if existingSelector = null then selector else each selector(_) and existingSelector(_)
                 in @View(state & [ SelectRowsExpression = combinedExpression, SelectRowsSelector = selector ]),

            // Calculates the final URL based on the current state.
            CalculateUrl = (foldedQuery as text) as text =>
                let
                    searchQueryWithoutPath = Text.TrimEnd(Text.AfterDelimiter(searchQuery,"?"), "&"),
                    constantQuery = "_count=100",
                    queryParameterList = {searchQueryWithoutPath, foldedQuery, constantQuery},
                    queryParameterText = Text.Combine(List.Select(queryParameterList, each _ <> ""), "&")
                in
                    Text.TrimEnd(baseUrl, "/") & "/" & resourceTypeName & "?" & queryParameterText,

            // Reshapes and applies the schema to the a list of resources as records
            ReshapeRows = (rows as list) as list =>
                let
                    versionedSchemaTable = Record.Field(SchemaTable, fhirVersion),
                    versionedChoiceReshapers = Record.Field(ChoiceReshapers, fhirVersion),

                    // build a series of functions to apply to each row
                    reshapers = {
                        Record.Field(ContainedReshapers, fhirVersion), // extract contained resources to a record field grouped by resource type
                        versionedChoiceReshapers{[ ResourceTypeName = resourceTypeName ]}[Reshaper], // move choice fields to their own field
                        each Record.AddField(_, "<referenceId>", if [id] = null then null else resourceTypeName & "/" & [id]), // add a <referenceId> field
                        versionedSchemaTable{[ ResourceTypeName = resourceTypeName ]}[SchemaApplyFunction] // apply the final schema to the record
                    },

                    // compose the reshapers into one function
                    combinedReshaper = List.Accumulate(reshapers, null, (acc, f) => if acc = null then f else each f(acc(_)))
                in
                    List.Transform(rows, combinedReshaper)
        ]))
    in
        View([]);

// Gets a list of resources as records, following next links between pages.
// The resources will not have the final schema applied.
GetAllResourcesWithoutSchema = (firstPageUrl as text, fallbackFirstPageUrl as text) =>
    let
        GetPage = (url as text, optional fallbackUrl as text) =>
            let
                defaultRequestOptions = [ Headers = [ Accept = "application/json" ] ],
                response =
                    if fallbackUrl = null then Web.Contents(url, defaultRequestOptions) else
                    let
                        defaultResponse = Web.Contents(url, defaultRequestOptions & [ ManualStatusHandling = { 400, 403, 500 } ]),
                        defaultResponseBuffered = Binary.Buffer(defaultResponse),
                        fallbackResponse = Web.Contents(fallbackUrl, defaultRequestOptions)
                    in
                        // force defaultResponseBuffered to be evaluated. If we do not buffer (and do this check), accessing metadata and then reading result will cause two web requests.
                        if defaultResponseBuffered = null then ... else
                        if Value.Metadata(defaultResponse)[Response.Status] = 200 then defaultResponseBuffered else fallbackResponse,
                body = Json.Document(response),
                resources = List.Transform(Record.FieldOrDefault(body, "entry", {}), each [resource]),
                nextLink = List.SingleOrDefault(List.Select(Record.FieldOrDefault(body, "link", {}), each [relation]? = "next"), [])[url]?
            in
                [ Resources = resources, NextLink = nextLink ],
        pages =
            List.Generate(
                () => GetPage(firstPageUrl, fallbackFirstPageUrl),
                each _ <> null,
                each if [NextLink] = null then null else GetPage([NextLink]),
                each [Resources])
    in
        // Turn the list of lists of rows (pages) into a list of rows
        List.Combine(pages);

// Load common library functions
Extension.LoadFunction = (name as text, optional environment) =>
    let
        // Connector package files do not support sub folders, so we create a flat package
        flatFileName = Text.Replace(name, "/", "-"),
        binary = Extension.Contents(flatFileName),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, if environment = null then #shared else #shared & environment);

Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = Diagnostics[LogValue];
Diagnostics.LogFailure = Diagnostics[LogFailure];
Diagnostics.WrapHandlers = Diagnostics[WrapHandlers];
Fold = Extension.LoadFunction("Folding.pqm", [ Diagnostics.ValueToText = Diagnostics[ValueToText] ])[Fold];

FoldPatterns = [
    DSTU2 = Extension.LoadFunction("DSTU2/SearchParameterFoldingPatterns.pqm"),
    STU3 = Extension.LoadFunction("STU3/SearchParameterFoldingPatterns.pqm"),
    R4 = Extension.LoadFunction("R4/SearchParameterFoldingPatterns.pqm")
];

SchemaTable = [
    DSTU2 = Extension.LoadFunction("DSTU2/FhirTypes.pqm"),
    STU3 = Extension.LoadFunction("STU3/FhirTypes.pqm"),
    R4 = Extension.LoadFunction("R4/FhirTypes.pqm")
];

ChoiceReshapers = [
    DSTU2 = Extension.LoadFunction("DSTU2/ChoiceReshapers.pqm"),
    STU3 = Extension.LoadFunction("STU3/ChoiceReshapers.pqm"),
    R4 = Extension.LoadFunction("R4/ChoiceReshapers.pqm")
];

ContainedReshapers = [
    DSTU2 = Extension.LoadFunction("DSTU2/ContainedReshapers.pqm"),
    STU3 = Extension.LoadFunction("STU3/ContainedReshapers.pqm"),
    R4 = Extension.LoadFunction("R4/ContainedReshapers.pqm")
];
