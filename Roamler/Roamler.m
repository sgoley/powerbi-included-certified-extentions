[Version = "1.0.0"]
section Roamler;

// Variables
DefaultImageBase64 = "data:image/jpeg;base64, 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";
CustomerApiUrl = "https://rmlr.azure-api.net/powerbi";
DefaultRequestHeaders = [
    #"X-Roamler-Api-Key" = Extension.CurrentCredential()[Key],
    #"X-Roamler-Connector" = "PowerBi 0.7.0.0"
];

// Data Source Kind description
Roamler = [
    TestConnection = (dataSourcePath) => { "Roamler.Contents" },
    Authentication = [
		Key = []
	],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
Roamler.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://www.roamler.com",
    SourceImage = Roamler.Icons,
    SourceTypeImage = Roamler.Icons
];

// Icons
Roamler.Icons = [
    Icon16 = { 
		Extension.Contents("roamler_icon_16x16.png"), 
		Extension.Contents("roamler_icon_20x20.png"), 
		Extension.Contents("roamler_icon_24x24.png"), 
		Extension.Contents("roamler_icon_32x32.png") 
	},
    Icon32 = { 
		Extension.Contents("roamler_icon_32x32.png"), 
		Extension.Contents("roamler_icon_40x40.png"), 
		Extension.Contents("roamler_icon_48x48.png"), 
		Extension.Contents("roamler_icon_64x64.png") 
	}
];

// Implementation
[DataSource.Kind="Roamler", Publish="Roamler.Publish"]
shared Roamler.Contents =  Value.ReplaceType(RoamlerNavTable, type function () as any);

GetJson = (path as text) =>
    let
        source  = Web.Contents(CustomerApiUrl & path, [ Headers = DefaultRequestHeaders, ManualCredentials = true ]),
        json    = Json.Document(source)
    in
        json;

// Navigation table used in the getData wizard
RoamlerNavTable = () as table =>
    let
        source = #table({"Name", "Data", "ItemKind", "ItemName", "IsLeaf"}, {
            // tables
            { "Metadata", GetMetadataTable(), "Table", "Table", true },
            { "Jobs", GetJobsTable(), "Table", "Table", true },
            // api functions
            { "GetJobsLocationsTable", GetJobsLocationsTable, "Function", "Function", true },
            { "GetJobsSubmissionsTable", GetJobsSubmissionsTable, "Function", "Function", true },           
            { "GetSubmissionDetails", GetSubmissionDetails, "Function", "Function", true },
            { "GetAnswerImage", GetAnswerImage, "Function", "Function", true },
            // image functions
            { "UrlToPbiImage", UrlToPbiImage, "Function", "Function", true },
            { "BinaryToPbiImage", BinaryToPbiImage, "Function", "Function", true }
        }),
        navTable = Table.ToNavigationTable(source, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

// Metadata
// {

GetMetadataTableType = type function () as table meta [
        Documentation.Name = "GetMetadataTable",
        Documentation.LongDescription = "Get Customer information like Name, Logo and API-details"
    ];

GetMetadataTableImpl = () as table =>
    let
        source                      = GetJson("/metadata"),
        #"Converted to Table"       = Record.ToTable(source),
        #"Transposed Table"         = Table.Transpose(#"Converted to Table"),
        #"Promoted Headers"         = Table.PromoteHeaders(#"Transposed Table", [PromoteAllScalars=true]),
        #"Changed Type"             = Table.TransformColumnTypes(#"Promoted Headers",{{"name", type text}, {"logoHRef", type any}, {"expirationDate", type datetime}}),
        #"Transformed null values"  = Table.TransformColumns(#"Changed Type", {"logoHRef", each if _ is null then "" else _}),
        #"Added Image Url"          = Table.AddColumn(#"Transformed null values", "ImageUrl", each GetCustomerImageBase64([logoHRef])),
        #"Removed Columns"          = Table.RemoveColumns(#"Added Image Url",{"logoHRef"})
in
    #"Removed Columns";

GetMetadataTable = Value.ReplaceType(GetMetadataTableImpl, GetMetadataTableType);

// }

// Jobs
// {

GetJobsTableType = type function () as table meta [
        Documentation.Name = "GetJobsTable",
        Documentation.LongDescription = "Get the list of Projects (Jobs)"
    ];

GetJobsTableImpl = () as table =>
    let
        GetPage = (Index) =>
            let 
                Url   = "/jobs?page=" & Number.ToText(Index),
                Json  = GetJson(Url)
            in  Json,
        PageIndices = { 0 .. 10 },
        Pages       = List.Transform(PageIndices, each GetPage(_)),
        Entities    = List.Union(Pages),
        Table       = Table.FromList(Entities, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        Expand      = Table.ExpandRecordColumn(Table, "Column1", {"id", "title", "liveDate", "closeDate", "isActive"}, {"id", "title", "liveDate", "closeDate", "isActive"})
    in
        Expand;

GetJobsTable = Value.ReplaceType(GetJobsTableImpl, GetJobsTableType);

// }

// Jobs submissions
// {

GetJobsSubmissionsTableType = type function (
    jobId as (type number meta [
        Documentation.FieldCaption = "JobId",
        Documentation.FieldDescription = "The id of the job"
    ]),
    beginDate as (type date meta [
        Documentation.FieldCaption = "BeginDate",
        Documentation.FieldDescription = "The begin date of the period you want to load submissions for the given job"
    ]),
    endDate as (type date meta [
        Documentation.FieldCaption = "EndDate",
        Documentation.FieldDescription = "The end date of the period you want to load submissions for the given job"
    ]),
    optional testingMode as (type logical meta [
        Documentation.FieldCaption = "TestingMode",
        Documentation.FieldDescription = "Switch on to only load the first 50 submissions. Recommended for testing.",
        Documentation.AllowedValues = { true, false }
    ])) as table meta [
        Documentation.Name = "Get Job submissions",
        Documentation.LongDescription = "Get the submissions for a specific Job"
    ];

GetJobsSubmissionsTableImpl = (
        jobId as number, 
        beginDate as date, 
        endDate as date, 
        optional testingMode as logical
    ) as table =>
    let
        Take = if testingMode = true then 5 else 1000,
        GetPage = (Index) =>
            let 
                Url   = "/jobs/" & Number.ToText(jobId) & "/submissions?fromDate=" & Date.ToText(beginDate, "yyyy-MM-dd") & "&toDate=" & Date.ToText(endDate, "yyyy-MM-dd") & "&take="&Number.ToText(Take)&"&page=" & Number.ToText(Index),
                Json  = GetJson(Url)
            in  Json,
        PageIndices = if testingMode = true then { 1 } else { 1 .. 10 },
        Pages       = List.Transform(PageIndices, each GetPage(_)),
        Entities    = List.Union(Pages),
        Table       = Table.FromList(Entities, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        Expand      = Table.ExpandRecordColumn(Table, "Column1", {"hRef", "submitDate"}, {"hRef", "submitDate"}),
        Table1      = Table.FromRecords({[Column1 = ""]}),
        result      = 
            if List.IsEmpty(Entities) 
            then Table1 
            else Expand
    in
        result;

GetJobsSubmissionsTable = Value.ReplaceType(GetJobsSubmissionsTableImpl, GetJobsSubmissionsTableType);

// }

// Jobs locations
// {

GetJobsLocationTableType = type function (
    jobId as (type number meta [
        Documentation.FieldCaption = "JobId",
        Documentation.FieldDescription = "The Id of the Job"
    ]),
    optional testingMode as (type logical meta [
        Documentation.FieldCaption = "TestingMode",
        Documentation.FieldDescription = "Switch on to only load the first 100 locations for the Job. Recommended for testing. ",
        Documentation.AllowedValues = { true, false }
    ])) as table meta [
        Documentation.Name = "Get job locations",
        Documentation.LongDescription = "Get the locations for a Job"
    ];

GetJobsLocationsTableImpl = (
    jobId as number, 
    optional testingMode as logical
    ) as table =>
    let
        Take        = if testingMode = true then 5 else 1000,
        GetPage     = (Index) =>
            let 
                Url     = "/jobs/" & Number.ToText(jobId) & "/pagelocations?take="&Number.ToText(Take)&"&page=" & Number.ToText(Index),
                Json    = GetJson(Url)
            in Json,
        PageIndices = if testingMode = true then { 1 } else { 1 .. 20 },
        Pages       = List.Transform(PageIndices, each GetPage(_)),
        Entities    = List.Union(Pages),
        Table       = Table.FromList(Entities, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        Expand      = Table.ExpandRecordColumn(Table, "Column1", {"id", "address", "latitude", "longitude", "attributes"}, {"id", "address", "latitude", "longitude", "attributes"}),
        Table1      = Table.FromRecords({[Column1 = ""]}),
        result = 
            if List.IsEmpty(Entities) 
            then Table1 
            else Expand
    in
        result;

GetJobsLocationsTable = Value.ReplaceType(GetJobsLocationsTableImpl, GetJobsLocationTableType);

// }

// Submission details
// {

GetSubmissionDetailsType = type function (
    submissionHRef as (type text meta [
        Documentation.FieldCaption = "SubmissionHRef",
        Documentation.FieldDescription = "The submission href"
    ])) as table meta [
        Documentation.Name = "Get Submission details",
        Documentation.LongDescription = "Get the locations for a Job"
    ];

GetSubmissionDetailsImpl = (submissionHRef as text) =>
    let
        submission = GetJson(submissionHRef & "?includeQuestions=true")
    in
        submission;

GetSubmissionDetails = Value.ReplaceType(GetSubmissionDetailsImpl, GetSubmissionDetailsType);

// }

// Customer image
// {

GetCustomerImageBase64Type = type function (
    imageUrl as (type text meta [
        Documentation.FieldCaption = "ImageUrl",
        Documentation.FieldDescription = "The image url"
    ])) as table meta [
        Documentation.Name = "Get customer image",
        Documentation.LongDescription = "Get the logo of the Customer/Project"
    ];

GetCustomerImageBase64Impl = (imageUrl as text) =>
    let
        customerImageBinary =  Web.Contents(CustomerApiUrl & "/" & imageUrl, [ Headers = DefaultRequestHeaders, ManualCredentials = true ]),
        customerPbiImage    = BinaryToPbiImage(customerImageBinary),
        defaultPbiImage     = DefaultImageBase64,
        result              =  if imageUrl = "" or imageUrl = null
                                then defaultPbiImage
                                else customerPbiImage
    in
        result;

GetCustomerImageBase64 = Value.ReplaceType(GetCustomerImageBase64Impl, GetCustomerImageBase64Type);

// }

// Answer image
// {

GetAnswerImageType = type function (
    imageUrl as (type text meta [
        Documentation.FieldCaption = "ImageUrl",
        Documentation.FieldDescription = "The image URL"
    ])) as table meta [
        Documentation.Name = "Get answer image",
        Documentation.LongDescription = "Get the Image for a specific Answer"
    ];

GetAnswerImageImpl = (imageUrl as text) =>
    let
        imageBinary         =  Web.Contents(CustomerApiUrl & imageUrl, [ Headers = DefaultRequestHeaders, ManualCredentials = true ]),
        customerPbiImage    = BinaryToPbiImage(imageBinary)
    in
        customerPbiImage;

GetAnswerImage = Value.ReplaceType(GetAnswerImageImpl, GetAnswerImageType);

// }

// Helper functions exposed in the report
// {

BinaryToPbiImageType = type function (
    binaryContent as (type binary meta [
        Documentation.FieldCaption = "BinaryContent",
        Documentation.FieldDescription = "The content as binary type"
    ])) as table meta [
        Documentation.Name = "BinaryToPbiImage",
        Documentation.LongDescription = "Convert to a PowerBI friendly dataformat"
    ];

BinaryToPbiImageImpl = (binaryContent as binary) as text=>
    let
        Base64 = "data:image/jpeg;base64, " & Binary.ToText(binaryContent, BinaryEncoding.Base64)
    in
        Base64;

BinaryToPbiImage = Value.ReplaceType(BinaryToPbiImageImpl, BinaryToPbiImageType);

UrlToPbiImageType = type function (
    imageUrl as (type text meta [
        Documentation.FieldCaption = "ImageUrl",
        Documentation.FieldDescription = "The image URL"
    ])) as table meta [
        Documentation.Name = "UrlToPbiImage",
        Documentation.LongDescription = "Download the Image and use as a PowerBI friendly dataformat"
    ];

UrlToPbiImageImpl = (imageUrl as text) as text =>
    let
        BinaryContent   = Web.Contents(imageUrl),
        Base64          = BinaryToPbiImage(BinaryContent, BinaryEncoding.Base64)
    in
        Base64;

UrlToPbiImage = Value.ReplaceType(UrlToPbiImageImpl, UrlToPbiImageType);

// }

// Common functions
// {
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
//}