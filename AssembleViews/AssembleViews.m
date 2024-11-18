[Version = "4.1.0"]
section AssembleViews;

[DataSource.Kind="AssembleViews", Publish="AssembleViews.Publish"]
shared AssembleViews.Feed = Value.ReplaceType(NavigationTable.Nested, AssembleViewsFeedType);

AssembleViewsFeedType = type function (
        resourceUrl as (Uri.Type meta [
            Documentation.FieldCaption = "Assemble Url",
            Documentation.FieldDescription = "Assemble Insight Url",
            Documentation.SampleValues = {"https://demo.tryassemble.com"}
        ])
    )
    as table meta [
        Documentation.Name = "Assemble Views",
        Documentation.LongDescription = "Access views created within Assemble Insight"
    ];


// Create Metadata Nav table
NavigationTable.Nested = (resourceUrl as text) as table =>
    let 
        objects = GetProjectsNavTable(resourceUrl),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;


GetProjectsNavTable = (resourceUrl as text) as table =>
    let 
        source = GetProjects(resourceUrl),
        projects = Table.SelectColumns(source, {"Project Name", "Id", "View Count"}),
        projectsRenameColumns = Table.RenameColumns(projects, {{"Project Name", "Name"}, {"Id", "Key"}}),       
        projectsAddData = Table.AddColumn(projectsRenameColumns, "Data", each try GetProjectFolders(resourceUrl, [Key], [Name]) otherwise null),
        projectsAddItemKind = Table.AddColumn(projectsAddData, "ItemKind", each "Folder"),
        projectsAddItemName = Table.AddColumn(projectsAddItemKind, "ItemName", each "Folder"),
        projectsAddIsLeaf = Table.AddColumn(projectsAddItemName, "IsLeaf", each false)
    in
        projectsAddIsLeaf;

GetProjectFolders = (resourceUrl as text, projectId as text, projectName as text) as table =>
    let
        ProjectFolder = #table({"Key","Name", "Data","ItemKind","ItemName","IsLeaf"},{}),

        AddMoldersFolder = Table.InsertRows(ProjectFolder, 0, 
            {[
                Name = "Models", 
                Key = projectId & "_models", 
                Data = ModelsQuery(resourceUrl, Number.FromText(projectId)), 
                ItemKind = "Folder", 
                ItemName = "Folder", 
                IsLeaf = false]}),

        AddViewsFolder = Table.InsertRows(AddMoldersFolder, 1, 
            {[
                Name = "Views", 
                Key = projectId & "_views", 
                Data = GetViewsNavTable(resourceUrl, projectId, projectName), 
                ItemKind = "Folder", 
                ItemName = "Folder", 
                IsLeaf = false]}),

        NavTable = Table.ToNavigationTable(AddViewsFolder, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

// Deprecared function for the order version of accessing view data
[DataSource.Kind="AssembleViews"]
shared AssembleViews.Contents = Value.ReplaceType(NavigationTableViews.Nested, AssembleViewsType);

AssembleViewsType = type function (
        resourceUrl as (Uri.Type meta [
            Documentation.FieldCaption = "Assemble Url",
            Documentation.FieldDescription = "Assemble Insight Url",
            Documentation.SampleValues = {"https://demo.tryassemble.com"}
        ]),        
        optional viewAtDate as (type any meta [
            Documentation.FieldCaption = "View Date",
            Documentation.FieldDescription = "Point in time to retrieve view data. When null or not provided the latest view data is retrieved. 
                If a date or datetime is provided then the timezone offset of the local machine is assumed.",
            Documentation.SampleValues = {#datetimezone(2021,05,01,0,0,0,-5,0)}
        ])
    )
    as table meta [
        Documentation.Name = "Assemble Views",
        Documentation.LongDescription = "Access views created within Assemble Insight"
    ];

NavigationTableViews.Nested = (resourceUrl as text, optional viewAtDate as nullable any) as table =>
    let 
        objects = GetProjectsViewsNavTable(resourceUrl, viewAtDate, false),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

GetProjectsViewsNavTable = (resourceUrl as text, viewAtDate as nullable any, fullSizeImages as nullable logical) as table =>
    let 
        source = GetProjects(resourceUrl),
        projects = Table.SelectColumns(source, {"Project Name", "Id", "View Count"}),
        projectsRenameColumns = Table.RenameColumns(projects, {{"Project Name", "Name"}, {"Id", "Key"}}),       
        projectsAddData = Table.AddColumn(projectsRenameColumns, "Data", each try GetViewsNavTable_deprecated(resourceUrl, [Key], [Name], viewAtDate, fullSizeImages) otherwise null),
        projectsAddItemKind = Table.AddColumn(projectsAddData, "ItemKind", each "Folder"),
        projectsAddItemName = Table.AddColumn(projectsAddItemKind, "ItemName", each "Folder"),
        projectsAddIsLeaf = Table.AddColumn(projectsAddItemName, "IsLeaf", each false)
    in
        projectsAddIsLeaf;


AssembleViews.ViewByName = Value.ReplaceType(GetViewDataByProjectAndViewName, AssembleViewByNameType);

AssembleViewByNameType = type function (
        resourceUrl as (Uri.Type meta [
            Documentation.FieldCaption = "Assemble Url",
            Documentation.FieldDescription = "Assemble Insight Url",
            Documentation.SampleValues = {"https://demo.tryassemble.com"}
        ]),
        projectName as (Text.Type meta [
            DataSource.Path = false,
            Documentation.FieldCaption = "Project Name",
            Documentation.FieldDescription = "Project name as seen in Assemble Insight"
        ]),
        viewName as (Text.Type meta [
            DataSource.Path = false,
            Documentation.FieldCaption = "View Name",
            Documentation.FieldDescription = "View name as seen in Assemble Insight"
        ]),   
        optional viewAtDate as (type any meta [
            DataSource.Path = false,
            Documentation.FieldCaption = "View Date",
            Documentation.FieldDescription = "Point in time to retrieve view data. When null or not provided the latest view data is retrieved. 
                If a date or datetime is provided then the timezone offset of the local machine is assumed.",
            Documentation.SampleValues = {#datetimezone(2021,05,01,0,0,0,-5,0)}
        ])
    )
    as table meta [
        Documentation.Name = "Assemble Views",
        Documentation.LongDescription = "Access views created within Assemble Insight by name."
    ];

AssembleViews_Impl = (resourceUrl as text, optional options) =>
    let
        resourceUrl = Uri.Rebuild(resourceUrl),
        source = Web.Contents(resourceUrl, options),
        json = Json.Document(source)
    in
        json;

GetViewDataByProjectAndViewName = (url as text, projectName as text, viewName as text, optional viewAtDate as nullable any) as table =>
    let
        projects = GetProjects(url),
        projectsFiltered = Table.First(Table.SelectRows(projects, each ([Project Name] = projectName))),
        views = GetProjectViews(url, projectsFiltered[Id]),
        viewsFiltered = Table.First(Table.SelectRows(views, each ([name] = viewName))),
        data = GetViewData(url, Number.ToText(viewsFiltered[id]), viewAtDate)
    in
        data;

GetProjects = (url as text) => 
    let
        ApiUrl = Uri.Combine(url, "/api/v1/powerbi/projects"),       
        source = Web.Request(ApiUrl,
                    [
                        Headers = GetWebRequestHeaders(url)
                    ]),
        #"Project List Converted to Table" = Table.FromList(source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Project List Expanded" = Table.ExpandRecordColumn(#"Project List Converted to Table", "Column1", 
            {"id", "name", "Description", "IsArchived", "ModelCount", "ViewCount", "LastActivityTime"}, 
            {"Id", "Project Name", "Description", "Is Archived", "Model Count", "View Count", "Last Activity Time"}),
        #"Project List Filtered Rows" = Table.SelectRows(#"Project List Expanded", each ([Is Archived] <> true)),
        #"Project List" = Table.TransformColumnTypes(#"Project List Filtered Rows",{{"Id", type text}})
    in
        #"Project List";


GetViewsNavTable = (resourceUrl as text, projectId as text, projectName as text) as table =>
    let 
        source = GetProjectViews(resourceUrl, projectId),
        views = Table.SelectColumns(source, {"name", "id"}),
        ViewsWithThumbnailId = Table.SelectColumns(source, {"name", "id", "thumbnailId"}, MissingField.Ignore),
        viewsWithThumbnails = Table.AddColumn(ViewsWithThumbnailId, "Image", each try GetViewThumbnail(resourceUrl, [thumbnailId], false) otherwise null),
        RenameColumns = Table.RenameColumns(views, {{"name", "Name"}, {"id", "Key"}}), 
        
        AddDataColumn = Table.AddColumn(RenameColumns, "Data", each 
            Value.ReplaceType((viewAtDate as nullable datetimezone) => GetViewData(resourceUrl, Number.ToText([Key]), viewAtDate), AssembleViewByDateType)),

        AddItemKindColumn = Table.AddColumn(AddDataColumn, "ItemKind", each "View"),
        AddItemNameColumn = Table.AddColumn(AddItemKindColumn, "ItemName", each "View"),
        AddIsLeafColumn = Table.AddColumn(AddItemNameColumn, "IsLeaf", each true),
        AddViewThumbnailsFolder = Table.InsertRows(AddIsLeafColumn, 1, {[Name = projectName & " View Thumbnails", Key = projectId & "_thumbnails", Data = viewsWithThumbnails, ItemKind = "Table", ItemName = "Table", IsLeaf = true]}),
        NavTable = Table.ToNavigationTableNoPreviewDelay(if AddViewThumbnailsFolder = null then AddIsLeafColumn else AddViewThumbnailsFolder, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

AssembleViewByDateType = type function (
        viewAtDate as (type nullable datetimezone meta [
            DataSource.Path = false,
            Documentation.FieldCaption = "View Date",
            Documentation.FieldDescription = "Point in time to retrieve view data. When null or not provided the latest view data is retrieved. 
                If a date or datetime is provided then the timezone offset of the local machine is assumed.",
            Documentation.SampleValues = {#datetimezone(2021,05,01,0,0,0,-5,0)}
        ])
    )
    as table meta [
        Documentation.Name = "Assemble Views",
        Documentation.LongDescription = "Access views created within Assemble Insight by name."
    ];

GetViewsNavTable_deprecated = (resourceUrl as text, projectId as text, projectName as text, viewAtDate as nullable any, fullSizeImages as nullable logical) as table =>
    let 
        source = GetProjectViews(resourceUrl, projectId),
        views = Table.SelectColumns(source, {"name", "id"}),
        ViewsWithThumbnailId = Table.SelectColumns(source, {"name", "id", "thumbnailId"}, MissingField.Ignore),
        viewsWithThumbnails = Table.AddColumn(ViewsWithThumbnailId, "Image", each try GetViewThumbnail(resourceUrl, [thumbnailId], fullSizeImages) otherwise null),
        RenameColumns = Table.RenameColumns(views, {{"name", "Name"}, {"id", "Key"}}),       
        AddDataColumn = Table.AddColumn(RenameColumns, "Data", each try GetViewData(resourceUrl, Number.ToText([Key]), viewAtDate) otherwise null),
        AddItemKindColumn = Table.AddColumn(AddDataColumn, "ItemKind", each "View"),
        AddItemNameColumn = Table.AddColumn(AddItemKindColumn, "ItemName", each "View"),
        AddIsLeafColumn = Table.AddColumn(AddItemNameColumn, "IsLeaf", each true),
        AddViewThumbnailsFolder = Table.InsertRows(AddIsLeafColumn, 1, {[Name = projectName & " View Thumbnails", Key = projectId & "_thumbnails", Data = viewsWithThumbnails, ItemKind = "Table", ItemName = "Table", IsLeaf = true]}),
        NavTable = Table.ToNavigationTable(if AddViewThumbnailsFolder = null then AddIsLeafColumn else AddViewThumbnailsFolder, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

GetProjectViews = (url as text, projectId as text) => 
    let
        ApiUrl = Uri.Combine(url, "/api/v1/projects/" & projectId & "/views?lightView=true"),
        source = Web.Request(ApiUrl,
                    [
                        Headers = GetWebRequestHeaders(url)
                    ]),
        ViewsList = Table.FromList(source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        ViewsListExpanded = Table.ExpandRecordColumn(ViewsList, "Column1", {"id", "disciplineId", "projectId", "projectName", "name", "description", "isVisible", "isReadOnly", "isLegacy", "takeoffGroupingId", "grouping", "additionalColumns", "additionalFilters", "selectedModels", "visibilityRules", "thumbnailId", "thumbnailData", "sharingPolicy", "sharingSettings", "embedded", "isProjectApproved", "serializedViewState", "serializedColorization", "serializedViewpoints", "serialized2dViewpoints"}, {"id", "disciplineId", "projectId", "projectName", "name", "description", "isVisible", "isReadOnly", "isLegacy", "takeoffGroupingId", "grouping", "additionalColumns", "additionalFilters", "selectedModels", "visibilityRules", "thumbnailId", "thumbnailData", "sharingPolicy", "sharingSettings", "embedded", "isProjectApproved", "serializedViewState", "serializedColorization", "serializedViewpoints", "serialized2dViewpoints"})
    in
        ViewsListExpanded;


GetViewData = (url as text, viewId as text, viewAtDate as nullable any) => 
    let
        viewDate = 
            if viewAtDate = null then null
            else if Value.Is(viewAtDate, DateTimeZone.Type) then viewAtDate
            else if Value.Is(viewAtDate, DateTime.Type) then DateTime.AddZone(viewAtDate, DateTimeZone.ZoneHours(DateTimeZone.LocalNow()))
            else if Value.Is(viewAtDate, Date.Type) then DateTime.AddZone(DateTime.From(viewAtDate), DateTimeZone.ZoneHours(DateTimeZone.LocalNow()))
            else error Error.Record("Parameter 'viewAtDate' must be a date, datetime, or datetimezone type."),
        viewDateParam = if viewDate = null then "" else "?viewAtDate=" & DateTimeZone.ToText(viewDate),
        ApiUrl = Uri.Combine(url, "/api/v1/views/" & viewId & "/instances" & viewDateParam),
        source = Web.Request(ApiUrl,
                    [
                        Headers = GetWebRequestHeaders(url)
                    ]),
        Instances = source[instances],
        InstanceRecords = Table.FromList(Instances, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        InstanceRows = Table.RenameColumns(InstanceRecords, {{"Column1", "Rows"}})
    in
        InstanceRows;


GetViewThumbnail = (url as text, thumbnailId as text, fullSizeImages as nullable logical) => 
    let          
        asFullSize = if fullSizeImages = null or fullSizeImages = false then false else true,
        fullSizeParam = "?fullsize=" & Logical.ToText(asFullSize),
        ApiUrl = Uri.Combine(url, "/api/v1/attachments/" & thumbnailId & fullSizeParam),
        source = Web.Contents(ApiUrl),
        binaryImg = if asFullSize = true then SplitLargeBinaryImage(source) else BinaryToPbiImage(source)
    in
        binaryImg;


BinaryToPbiImage = (BinaryContent as binary) as text =>
    let
        Base64 = "data:image/jpeg;base64, " & Binary.ToText(BinaryContent, BinaryEncoding.Base64)
    in
        Base64;

SplitLargeBinaryImage = (imageTable as table) as table =>
    let
        RemoveOtherColumns = Table.SelectColumns(imageTable,{"Image", "name"}),
        SplitTextFunction = Splitter.SplitTextByRepeatedLengths(30000),
        //Converts table of files to list
        ListInput = Table.ToRows(RemoveOtherColumns),
        //Function to convert binary of photo to multiple
        //text values
        ConvertOneFile = (InputRow as list) =>
            let
                BinaryIn = InputRow{0},
                FileName = InputRow{1},
                BinaryText = Binary.ToText(BinaryIn, BinaryEncoding.Base64),
                SplitUpText = SplitTextFunction(BinaryText),
                AddFileName = List.Transform(SplitUpText, each {FileName,_})
            in
                AddFileName,
        //Loops over all photos and calls the above function
        ConvertAllFiles = List.Transform(ListInput, each ConvertOneFile(_)),
        //Combines lists together
        CombineLists = List.Combine(ConvertAllFiles),
        //Converts results to table
        ToTable = #table(type table[name=text,Image=text],CombineLists),
        //Adds index column to output table
        AddIndexColumn = Table.AddIndexColumn(ToTable, "Index", 0, 1)
    in
        AddIndexColumn;


// #Section Load Model Data
ModelsQuery = (resourceUrl as text, ProjectId as number) as table => 
    let
        ModelData = GetProjectModels(resourceUrl, ProjectId),
        
        #"Model Expanded Column1" = 
            Table.ExpandRecordColumn(ModelData, "Column1", {"id", "name", "hasVersions", "versions", "activeVersion"}, {"id", "name", "hasVersions", "versions", "activeVersion"}),

        Models = Table.SelectRows(#"Model Expanded Column1", each ([hasVersions] = true)),
        RenameColumns = Table.RenameColumns(Models, {{"name", "Name"}, {"id", "Key"}}),
        
        AddData = Table.AddColumn(RenameColumns, "Data", 
            each let
                    VersionsTable = ExpandModelVersions([versions]),
                    ReplacedVersionMeta = Value.ReplaceMetadata(VersionNumbersMeta, Value.Metadata(VersionNumbersMeta) & [Documentation.AllowedValues = VersionsTable[NameAndNumber]]),

                    // Retrieve model properties for all model versions
                    AllProperties = Table.Sort(GetModelProperties(resourceUrl, [Key]), {each Text.Upper([ColumnDisplay])}),

                    // Power BI has a limit of 1,000 rows for parameter allowed values
                    // Here the properties are split into pages, each with 1,000 records
                    SplitToPropPages = Table.FromList(Table.Split(AllProperties, 1000), Splitter.SplitByNothing(), {"PropertyTables"}, null, ExtraValues.Error),
                    // Get the beginning char of the first and last properties for each page, this is used later as part the parameter name
                    PropPagesWithRange = Table.AddColumn(SplitToPropPages, "Range", each Text.Combine({Text.Upper(Text.At(Table.First([PropertyTables])[ColumnDisplay], 0)), " - ", Text.Upper(Text.At(Table.Last([PropertyTables])[ColumnDisplay], 0))})),
                    
                    // Set the allowed values for the properties parameter               
                    ReplacedPropertyMeta = Table.TransformRows(PropPagesWithRange, each Value.ReplaceMetadata(PropertiesMeta, Value.Metadata(PropertiesMeta) & [
                        Documentation.AllowedValues = List.RevertCharacterPlaceholders(Table.ToList(Table.SelectColumns(Record.Field(_, "PropertyTables"), {"ColumnDisplay"}, null))), 
                        Documentation.FieldCaption = "Properties (" & Record.Field(_, "Range") & ")"
                    ])),                 

                    // Dynamically build version data function type definition based on the number of property pages
                    BuildModelVersionDataFunctionTypeString = "type function(
                            LoadVersionsBy as ModelVersionLoadTypeMeta,
                            SelectedVersions as ReplacedVersionMeta,
                            Properties1 as ReplacedPropertyMeta{0}"
                            & (if List.Count(ReplacedPropertyMeta) >= 2 then ", Properties2 as ReplacedPropertyMeta{1}" else "")
                            & (if List.Count(ReplacedPropertyMeta) >= 3 then ", Properties3 as ReplacedPropertyMeta{2}" else "")
                            & (if List.Count(ReplacedPropertyMeta) >= 4 then ", Properties4 as ReplacedPropertyMeta{3}" else "")
                            & (if List.Count(ReplacedPropertyMeta) >= 5 then ", Properties5 as ReplacedPropertyMeta{4}" else "")
                        & ") as table",

                    ModelVersionDataFunctionType = Diagnostics.Trace(TraceLevel.Information, BuildModelVersionDataFunctionTypeString, 
                        () => Expression.Evaluate(BuildModelVersionDataFunctionTypeString,
                        // Pass in variables from the current context that are needed within Expression.Evaluate()
                        [ModelVersionLoadTypeMeta=ModelVersionLoadTypeMeta,ReplacedVersionMeta=ReplacedVersionMeta,ReplacedPropertyMeta=ReplacedPropertyMeta]), true),

                    DataFeedFunction = (LoadVersionsBy as text, SelectedVersions as nullable list, Properties as list) => ModelData.Feed(
                                        resourceUrl, 
                                        [id = [Key], name = [Name]],

                                        if LoadVersionsBy = "All versions"
                                            then true 
                                            else if LoadVersionsBy = "Specific versions" and SelectedVersions = null 
                                                    then error "You must select at least one version when using option: 'Specific versions'." 
                                                    else false,

                                        if List.Count(Properties) > 200
                                            then error "The maximum number of properties is limited to 200, there are currently " & Number.ToText(List.Count(Properties)) & " selected." 
                                            else Table.SelectRows(AllProperties, each List.Contains(List.SubstitueCharacterPlaceholders(Properties), Text.SubstitueCharacterPlaceholders([ColumnDisplay]))),

                                        if LoadVersionsBy = "All except active version" then 
                                                 let
                                                    activeVersionId = Record.FieldOrDefault([activeVersion], "id"),
                                                    result = Table.SelectRows(VersionsTable, each [id] <> activeVersionId)[id]
                                                 in 
                                                    result
                                            else if SelectedVersions = null then {}
                                            else Table.SelectRows(VersionsTable, each List.Contains(SelectedVersions, [NameAndNumber]))[id]
                                   ),

                    Data = Value.ReplaceType(BuildModelVersionDataFunction(ReplacedPropertyMeta, DataFeedFunction), ModelVersionDataFunctionType)  
                in
                    Data
        ),

        RemovedColumns = Table.RemoveColumns(AddData, {"versions","activeVersion"}),
        AddItemKind = Table.AddColumn(RemovedColumns, "ItemKind", each "Folder"),
        AddItemName = Table.AddColumn(AddItemKind, "ItemName", each "Folder"),
        AddIsLeaf = Table.AddColumn(AddItemName, "IsLeaf", each true),
        NavTable = Table.ToNavigationTableNoPreviewDelay(AddIsLeaf, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
in
    NavTable;


BuildModelVersionDataFunction = (propertyMetadatas as any, dataFeed as function) =>
let
    pageCount = Diagnostics.Trace(TraceLevel.Information, "Building function with " 
                    & Text.From(List.Count(propertyMetadatas)) & " property pages", 
                    () => List.Count(propertyMetadatas), true),

    VersionDataFunction = if pageCount = 1 
                    then (LoadVersionsBy as text, SelectedVersions as nullable list, Properties1 as list) => 
                        let
                            Properties = Properties1,
                            result = dataFeed(LoadVersionsBy, SelectedVersions, Properties)
                        in
                            result
                    else if pageCount = 2 
                        then (LoadVersionsBy as text, SelectedVersions as nullable list, Properties1 as list, Properties2 as list) => 
                        let
                            Properties = List.Combine({Properties1, Properties2}),
                            result = dataFeed(LoadVersionsBy, SelectedVersions, Properties)
                        in
                            result
                    else if pageCount = 3
                        then (LoadVersionsBy as text, SelectedVersions as nullable list, Properties1 as list, Properties2 as list, Properties3 as list) => 
                        let
                            Properties = List.Combine({Properties1, Properties2, Properties3}),
                            result = dataFeed(LoadVersionsBy, SelectedVersions, Properties)
                        in
                            result
                    else if pageCount = 4
                        then (LoadVersionsBy as text, SelectedVersions as nullable list, Properties1 as list, Properties2 as list, Properties3 as list, Properties4 as list) => 
                        let
                            Properties = List.Combine({Properties1, Properties2, Properties3, Properties4}),
                            result = dataFeed(LoadVersionsBy, SelectedVersions, Properties)
                        in
                            result
                    else (LoadVersionsBy as text, SelectedVersions as nullable list, optional Properties1 as nullable list, optional Properties2 as nullable list, optional Properties3 as nullable list, optional Properties4 as nullable list, optional Properties5 as nullable list) => 
                        let
                            Properties = List.Combine({Properties1, Properties2, Properties3, Properties4, Properties5}),
                            result = dataFeed(LoadVersionsBy, SelectedVersions, Properties)
                        in
                            result
in
    VersionDataFunction;


AssembleViews.GetProjectModels = Value.ReplaceType(GetProjectModels, GetProjectModelsType);

GetProjectModels = (resourceUrl as text, ProjectId as number) as table =>
let
    FormatModelAsJsonQuery = Web.Request(Uri.Combine(resourceUrl, "/api/v1/powerbi/projects/" & Number.ToText(ProjectId) & "/models"),
    [
        Headers = GetWebRequestHeaders(resourceUrl)
    ]),
    #"Model To Table" = Table.FromList(FormatModelAsJsonQuery, Splitter.SplitByNothing(), null, null, ExtraValues.Error)
in
    #"Model To Table";


GetProjectModelsType = type function (
        resourceUrl as (Uri.Type meta [
            Documentation.FieldCaption = "Assemble Url",
            Documentation.FieldDescription = "Assemble Insight Url",
            Documentation.SampleValues = {"https://demo.tryassemble.com"}
        ]),
        ProjectId as (type number meta [
            Documentation.FieldCaption = "Project ID",
            Documentation.FieldDescription = "The Assemble Project ID of the target project.",
            DataSource.Path = false
        ])
    )
    as table meta [
        Documentation.Name = "Load data by predefined selection"
    ];

ModelData.Feed = (resourceUrl as text, model as record, LoadAllModelVersions as logical, properties as table, optional SelectedVersionIds as nullable list) =>
let
    ModelId = Record.FieldOrDefault(model, "id"),
    ModelName = Record.FieldOrDefault(model, "name"),

    AddVersionInfoColumns = Table.InsertRows(properties, 0, 
        {
            [id = "ModelID_Assemble", name = "Model ID (Assemble)", unit = null, type = "numeric", source = "assembleStatic", dataType = "bigint", ColumnDisplay = "Model ID (Assemble)"],
            [id = "ModelName_Assemble", name = "Model Name (Assemble)", unit = null, type = "string", source = "assembleStatic", dataType = "string", ColumnDisplay = "Model Name (Assemble)"],
            [id = "VersionID_Assemble", name = "Version ID (Assemble)", unit = null, type = "numeric", source = "assembleStatic", dataType = "bigint", ColumnDisplay = "Version ID (Assemble)"],
            [id = "VersionName_Assemble", name = "Version Name (Assemble)", unit = null, type = "string", source = "assembleStatic", dataType = "string", ColumnDisplay = "Version Name (Assemble)"],
            [id = "VersionNumber_Assemble", name = "Version Number (Assemble)", unit = null, type = "numeric", source = "assembleStatic", dataType = "int", ColumnDisplay = "Version Number (Assemble)"]
        }),

    Properties = Table.Sort(AddVersionInfoColumns, {"ColumnDisplay"}),

    GetView = (state as record) => Table.View(
        null,
        [
            selectedProperties = Table.Sort(Table.SelectRows(Properties, each List.Contains(state[SelectedColumns], [ColumnDisplay])), {"ColumnDisplay"}),

            GetType = () => 
                GetTypes_func(resourceUrl, state, ModelId, selectedProperties),

            GetRows = () => 
                let
                    result = 
                        if List.Count(state[SelectedColumns]) > 205 then #table(state[SelectedColumns], {}) 
                        else
                            try 
                                GetRows_func(resourceUrl, state, ModelId, selectedProperties, LoadAllModelVersions)
                            otherwise 
                                let
                                    message = "Failed to retrieve rows from server."
                                in
                                    Diagnostics.Trace(TraceLevel.Error, message, () => error message, true)
                 in
                    result,

            OnSelectColumns = (columns as list) => 
                @GetView(state & [
                    SelectedColumns = List.Combine({columns, {"Model ID (Assemble)", "Model Name (Assemble)", "Version ID (Assemble)", "Version Name (Assemble)", "Version Number (Assemble)"}}), 
                    RefreshDate = DateTimeZone.FixedUtcNow()
                ])

        ]
    )

in
    GetView([SelectedColumns = Properties[ColumnDisplay], VersionIds = SelectedVersionIds, RefreshDate = DateTimeZone.FixedUtcNow()]);


GetTypes_func = (url as text, state as record, modelId as number, properties as table) =>
let
    AddPQTypeColumn = Table.AddColumn(properties, "PQType", 
        each if Comparer.Equals(Comparer.OrdinalIgnoreCase, [dataType], "quantity") or Comparer.Equals(Comparer.OrdinalIgnoreCase, [dataType], "float") then "number"
            else if Comparer.Equals(Comparer.OrdinalIgnoreCase, [dataType], "bigint") or Comparer.Equals(Comparer.OrdinalIgnoreCase, [dataType], "int") then "number"
            else if Comparer.Equals(Comparer.OrdinalIgnoreCase, [dataType], "bit") then "logical"
            else "text"),
    
    #"Added NameAndType Column" = Table.AddColumn(AddPQTypeColumn, "NameAndType", 
        each "#""" & Text.Replace(Text.RevertCharacterPlaceholders([ColumnDisplay]), """", """""") & """" & " = " & [PQType]),

    typeString = Diagnostics.Trace(TraceLevel.Information, "Build table type expression ", 
        () => "type table [" & Text.Combine(#"Added NameAndType Column"[NameAndType], ", ") & "]", true),
                
    typeDef =
        try 
            Diagnostics.Trace(TraceLevel.Information, "Evaluate table type expression " & typeString, () => Expression.Evaluate(typeString), true)
        otherwise 
            let
                message = "Failed to evaluate table type expression: " & typeString
            in
                Diagnostics.Trace(TraceLevel.Error, message, () => error message, true)
in
    typeDef;

GetRows_func = (resourceUrl as text, state as record, modelId as number, properties as table, AllModelVersions as logical) =>
    let
        headers = GetWebRequestHeaders(resourceUrl),
        dataFunc = (url) => GetData(url, state, properties, headers),
        //lastRefreshDataParam = if state[RefreshDate] = null then "" else "&lastRefreshDate=" & DateTimeZone.ToText(state[RefreshDate], "yyyy-MM-dd HH:mm:ss"),

        dataUrl = Uri.Combine(resourceUrl, "api/v1/datafeed/models/" & Text.From(modelId) 
            & "?page=1" 
            & "&pageSize=2000" 
            & "&allVersions=" & Text.From(AllModelVersions)),

        data = 
            try 
                Diagnostics.Trace(TraceLevel.Information, "Post request: retrieve version data for " 
                    & Text.From(Table.RowCount(properties)) & " properties", 
                    () => GetAllPagesByNextLink(dataUrl, dataFunc), true)

            otherwise 
                let
                    message = "Couldn't retrieve version data using url: " & 
                        dataUrl & " Selected properties: " &
                        Text.Combine(properties[ColumnDisplay], ", ")
                in
                    Diagnostics.Trace(TraceLevel.Error, message, () => error message, true)
    in 
        data;

AssembleViews.ReportQuery = Value.ReplaceType(AssembleViews.QueryFunction, AssembleByReportDeinition);

AssembleViews.QueryFunction = (resourceUrl as text, Versions as table, Properties as table) =>
    let
        Source = GetRowsByVersionTable(resourceUrl, Versions[id], Properties)
    in
        Source;

AssembleByReportDeinition = type function (
        resourceUrl as (Uri.Type meta [
            Documentation.FieldCaption = "Assemble Url",
            Documentation.FieldDescription = "Assemble Insight Url",
            Documentation.SampleValues = {"https://demo.tryassemble.com"}
        ]),
        Versions as (Table.Type
            meta [
                Documentation.FieldCaption = "Versions Table",
                DataSource.Path = false
        ]),
        Properties as (Table.Type
            meta [
                Documentation.FieldCaption = "Properties Table",
                DataSource.Path = false
        ])
    )
    as table meta [
        Documentation.Name = "Load data by predefined selection"
    ];

GetRowsByVersionTable = (resourceUrl as text, versionIds as list, properties as table) =>
    let
        headers = GetWebRequestHeaders(resourceUrl),
        dataFunc = (url) => GetData(url, [VersionIds = versionIds], properties, headers),

        dataUrl = Uri.Combine(resourceUrl, "api/v1/datafeed"
            & "?page=1" 
            & "&pageSize=2000"),

        data = GetAllPagesByNextLink(dataUrl, dataFunc)
    in 
        data;


GetData = (url as text, state as record, properties as table, headers as record) => 
let
    selectedVersionList = if state[VersionIds] = null then {} else state[VersionIds],
    response = 
        try 
            Web.Request(url,
            [
                Headers = headers,
                Content = Json.FromValue([properties = properties, selectedVersions = selectedVersionList])
            ])
        otherwise 
            let
                message = "Couldn't retrieve version data using url: " & Uri.Rebuild(url) 
                & " Headers: " & Text.FromBinary(Json.FromValue(headers))
                & " Content: " & Text.FromBinary(Json.FromValue([properties = properties, selectedVersions = selectedVersionList]))
            in
                Diagnostics.Trace(TraceLevel.Error, message, () => error message, true),

    nextLink = GetNextLink(response),
    RenameList = Table.ToRows(Table.SelectColumns(properties,{"id", "ColumnDisplay"})),
    RenamedColumns = Table.RenameColumns(Table.FromRecords(response[data]),RenameList),
    data = Table.ReorderColumns(RenamedColumns, List.Sort(properties[ColumnDisplay]))
in
    data meta [NextLink = nextLink];

GetAllPagesByNextLink = (url as text, dataFunc as function) as table =>
    Table.GenerateByPage((previous) => 
        let
            // if previous is null, then this is our first page of data
            nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
            // if NextLink was set to null by the previous call, we know we have no more data
            page = if (nextLink <> null) then dataFunc(nextLink) else null
        in
            page
    );

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

GetNextLink = (response) as nullable text => Record.FieldOrDefault(response, "nextLink");

ExpandModelVersions = (versions as list) => 
    let
        #"Converted to Table" = Table.FromList(versions, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"id", "name", "versionNumber"}, {"id", "name", "versionNumber"}),
        #"Added Combined Name and Version" = Table.AddColumn(#"Expanded Column1", "NameAndNumber", each Text.Combine({[name], " (v", Text.From([versionNumber]), ")"}))
    in
        #"Added Combined Name and Version";

GetModelProperties = (resourceUrl as text, modelId as number) =>
    let
        url = Uri.Combine(resourceUrl, "api/v1/datafeed/models/" & Text.From(modelId) & "/properties"),
        properties = GetModelPropertiesImpl(url)
    in
        properties;

GetModelPropertiesImpl = (PropertiesUrl as text) =>
let
    Source = 
    try 
        Web.Request(PropertiesUrl,
        [
            Headers = GetWebRequestHeaders(PropertiesUrl)
        ])
    otherwise 
        let
            message = "Couldn't retrieve version properties using url: " & PropertiesUrl
        in
            Diagnostics.Trace(TraceLevel.Error, message, () => error message, true),

    #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"id", "name", "unit", "dataType", "type", "source"}, {"id", "name", "unit", "dataType", "type", "source"}),
    #"Replaced Value2" = Table.ReplaceValue(#"Expanded Column1","",null,Replacer.ReplaceValue,{"unit"}),
    #"Added Column Display" = Table.AddColumn(#"Replaced Value2", "ColumnDisplay", 
        each [name] & (if [unit] <> null then " (" & [unit] & ")" else "") & (if [source] = "assembleCustom" then " (Assemble Property)" else "")),

    #"Substitute Character Placeholders" = Table.SubstitueCharacterPlaceholders(#"Added Column Display", "ColumnDisplay"),
    TakeTopN = Diagnostics.Trace(TraceLevel.Information, "Taking top 5000 properties " 
                    & Text.From(Table.RowCount(#"Substitute Character Placeholders")) & " properties", 
                    () => Table.FirstN(#"Substitute Character Placeholders", 5000), true)
in
    TakeTopN;

QUOTE_PLACEHOLDER = "_QUOTE_";
LEFT_PAREN_PLACEHOLDER = "_LP_PH";
RIGHT_PAREN_PLACEHOLDER = "_RP_PH_";
COMMA_PLACEHOLDER = "";

Table.SubstitueCharacterPlaceholders = (valueList as table, columnName as text) =>
let
    replaceQuoteEscape = Table.ReplaceValue(valueList, """", QUOTE_PLACEHOLDER, Replacer.ReplaceText, {columnName}),
    replaceLeftParenEscape = Table.ReplaceValue(replaceQuoteEscape, "(", LEFT_PAREN_PLACEHOLDER, Replacer.ReplaceText, {columnName}),
    replaceRightParenEscape = Table.ReplaceValue(replaceLeftParenEscape, ")", RIGHT_PAREN_PLACEHOLDER, Replacer.ReplaceText, {columnName}),
    replaceCommaEscape = Table.ReplaceValue(replaceRightParenEscape, ",", COMMA_PLACEHOLDER, Replacer.ReplaceText, {columnName})
in
    replaceCommaEscape;

Text.RevertCharacterPlaceholders = (value as text) =>
let
    replaceQuoteEscape = Text.Replace(value, QUOTE_PLACEHOLDER, """"),
    replaceLeftParenEscape = Text.Replace(replaceQuoteEscape, LEFT_PAREN_PLACEHOLDER, "("),
    replaceRightParenEscape = Text.Replace(replaceLeftParenEscape, RIGHT_PAREN_PLACEHOLDER, ")"),
    replaceCommaEscape = Text.Replace(replaceRightParenEscape, COMMA_PLACEHOLDER, ",")
in
    replaceCommaEscape;

Text.SubstitueCharacterPlaceholders = (value as text) =>
let
    replaceQuoteEscape = Text.Replace(value, """", QUOTE_PLACEHOLDER),
    replaceLeftParenEscape = Text.Replace(replaceQuoteEscape, "(", LEFT_PAREN_PLACEHOLDER),
    replaceRightParenEscape = Text.Replace(replaceLeftParenEscape, ")", RIGHT_PAREN_PLACEHOLDER),
    replaceCommaEscape = Text.Replace(replaceRightParenEscape, ",", COMMA_PLACEHOLDER)
in
    replaceCommaEscape;

List.RevertCharacterPlaceholders = (valueList as list) =>
let
    replaceQuoteEscape = List.ReplaceValue(valueList, QUOTE_PLACEHOLDER, """", Replacer.ReplaceText),
    replaceLeftParenEscape = List.ReplaceValue(replaceQuoteEscape, LEFT_PAREN_PLACEHOLDER, "(", Replacer.ReplaceText),
    replaceRightParenEscape = List.ReplaceValue(replaceLeftParenEscape, RIGHT_PAREN_PLACEHOLDER, ")", Replacer.ReplaceText),
    replaceCommaEscape = List.ReplaceValue(replaceRightParenEscape, COMMA_PLACEHOLDER, ",", Replacer.ReplaceText)
in
    replaceCommaEscape;

List.SubstitueCharacterPlaceholders = (valueList as list) =>
let
    replaceQuoteEscape = List.ReplaceValue(valueList, """", QUOTE_PLACEHOLDER, Replacer.ReplaceText),
    replaceLeftParenEscape = List.ReplaceValue(replaceQuoteEscape, "(", LEFT_PAREN_PLACEHOLDER, Replacer.ReplaceText),
    replaceRightParenEscape = List.ReplaceValue(replaceLeftParenEscape, ")", RIGHT_PAREN_PLACEHOLDER, Replacer.ReplaceText),
    replaceCommaEscape = List.ReplaceValue(replaceRightParenEscape, ",", COMMA_PLACEHOLDER, Replacer.ReplaceText)
in
    replaceCommaEscape;

// #Model data meta types
ModelVersionLoadTypeMeta = type text meta [
    Documentation.FieldCaption = "Load model data for:",
    Documentation.Description = "Specifies whether to always load the active version, all versions, or subset of versions.",
    Documentation.FieldDescription = "Specifies whether to always load the active version, all versions, or subset of versions.",
    Documentation.LongDescription = "Specifies whether to always load the active version, all versions, or subset of versions.",
    Documentation.AllowedValues = {"Active version only","All versions","All except active version","Specific versions"},
    Documentation.DefaultValue = {"Active version only"}
];

PropertiesMeta = type list meta [
    Documentation.FieldCaption = "Properties",
    Documentation.Description = "Properties to be retrieved for model.",
    Documentation.FieldDescription = "Properties to be retrieved for model.",
    Documentation.LongDescription = "Properties to be retrieved for model.",
    Documentation.DefaultValue = {"No properties selected"}
];

VersionNumbersMeta = type nullable list meta [
    Documentation.FieldCaption = "Version Name and Number",
    Documentation.Description = "List of version names with the version number in parenthesis prefixed with 'v'.",
    Documentation.FieldDescription = "List of version names with the version number in parenthesis prefixed with 'v'.",
    Documentation.LongDescription = "List of version names with the version number in parenthesis prefixed with 'v'."
];




// Data Source Kind description
AssembleViews = [
    TestConnection = (dataSourcePath) => {"AssembleViews.Contents", dataSourcePath},
    Authentication = [
        OAuth = [
            StartLogin=StartLogin,
            FinishLogin=FinishLogin,
            Refresh=Refresh
        ]
    ],
    Label = "Assemble Views"
];

redirect_uri = Extension.LoadString("redirect_uri");

// Helper functions for OAuth2: StartLogin, FinishLogin, Refresh, Logout
StartLogin = (resourceUrl, state, display) =>
    let       
        base_url = GetDiscoveryDocument(resourceUrl)[authorization_endpoint],
        tenant = Text.From(GetTenantParameter(resourceUrl)),
        authorizeUrl = base_url & "?" & Uri.BuildQueryString([
            response_type = "code",
            client_id = GetEnvironmentVariable(resourceUrl, "client_id"),  
            redirect_uri = redirect_uri,
            state = state,
            scope = "core_api.all tenant openid offline_access",
            acr_values = tenant, //"idp:forge" add this to the beginning of the string with a space to force oxygen only authorization
            is_remote = "true"
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = 520,
            WindowWidth = 724,
            Context = resourceUrl
        ];


FinishLogin = (context, callbackUri, state) =>
    let
        // parse the full callbackUri, and extract the Query string
        parts = Uri.Parts(callbackUri)[Query],
        // if the query string contains an "error" field, raise an error
        // otherwise call TokenMethod to exchange our code for an access_token
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)

                 else if (Record.HasFields(parts, {"error"})) then 
                    if (parts[error] = "access_denied") then
                        error Error.Record("Access Denied", "This account does not have access to " & context & ".")
                    else 
                        error Error.Record(parts[error], "Failed to login to " & context & ".")
                            
                 else if (Record.HasFields(parts, {"code"})) then
                    TokenMethod(context, "authorization_code", "code", parts[code])

                 else
                    error Error.Record(Text.Combine(Table.ToList(Record.ToTable(parts), Combiner.CombineTextByDelimiter(", "))))
    in
        result;

Refresh = (resourceUrl, refresh_token) => TokenMethod(resourceUrl, "refresh_token", "refresh_token", refresh_token);


TokenMethod = (resourceUrl, grantType, tokenField, code) =>
    let
        queryString = [
            grant_type = grantType,
            redirect_uri = redirect_uri,
            client_id = GetEnvironmentVariable(resourceUrl, "client_id"),
            client_secret = GetEnvironmentVariable(resourceUrl, "client_secret")
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),

        base_url = GetDiscoveryDocument(resourceUrl)[token_endpoint],
        tokenResponse = Web.Contents(base_url, [
            Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = {400} 
        ]),
        body = Json.Document(tokenResponse),
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body)

                 else if (Record.HasFields(body, {"error"})) then 
                    error Error.Record(body[error], "Failed to login.", body)
                 
                 else
                    body
    in
        result;


// Data Source UI publishing description
AssembleViews.Publish = [
    Beta = false,
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = Extension.LoadString("LearnMoreUrl"),
    SourceImage = AssembleViews.Icons,
    SourceTypeImage = AssembleViews.Icons
];

AssembleViews.Icons = [
    Icon16 = { Extension.Contents("AssembleViews16.png"), Extension.Contents("AssembleViews20.png"), Extension.Contents("AssembleViews24.png"), Extension.Contents("AssembleViews32.png") },
    Icon32 = { Extension.Contents("AssembleViews32.png"), Extension.Contents("AssembleViews40.png"), Extension.Contents("AssembleViews48.png"), Extension.Contents("AssembleViews64.png") }
];


GetEnvironmentVariable = (resourceUrl as text, resourceKey as text) =>
    let
        env = GetEnvironment(resourceUrl),
        env_variable_key = if env = "prod" then resourceKey else resourceKey & "_" & env,
        value = Extension.LoadString(env_variable_key)
    in
        value as text;

GetAuthUrl = (resourceUrl as text) =>
    let
        auth_uri = Web.Request(Uri.Combine(resourceUrl, "/api/v1/authority"),        
        [
            Headers = GetWebRequestHeaders(resourceUrl)
        ])
    in
        auth_uri as text;

GetDiscoveryDocument = (resourceUrl as text) =>
    let
        auth_url = GetAuthUrl(resourceUrl),
        disco_doc = Web.Request(Uri.Combine(auth_url, "/.well-known/openid-configuration"))
    in
        disco_doc;

GetEnvironment = (resourceUrl as text) =>
    let
        auth_url = GetAuthUrl(resourceUrl),
        env = if 
                Text.Contains(Text.Lower(auth_url), ".au.tryassemble") then "au" 
            else if 
                Text.Contains(Text.Lower(auth_url), "tryassemble") then "prod" 
            else if 
                (Text.Contains(Text.Lower(auth_url), "staging") and Text.Contains(Text.Lower(resourceUrl), "internalassemble")) 
                or (Text.Contains(Text.Lower(auth_url), "stg") and Text.Contains(Text.Lower(resourceUrl), "internalassemble")) 
                or Text.Contains(Text.Lower(resourceUrl), "staging.internalassemble.com") then "stg" 
            else 
                "dev"
    in
        env;

GetTenantParameter = (resourceUrl as text) =>  
    let
        TenantParameter = Text.Combine({"tenant", GetTenantFromHost(resourceUrl)}, ":") 
    in
        TenantParameter as text;

GetTenantFromHost = (resourceUrl as text) =>
    let
        host = GetHost(resourceUrl),
        parsedHost = Text.Split(host, "."){0}
    in
    parsedHost as text;

GetHost = (resourceUrl as text) =>
    let
        host = Uri.Parts(resourceUrl)[Host]
    in
        host as text;

Uri.Rebuild = (resourceUrl as text) =>
    let
        parts = Uri.Parts(resourceUrl),
        queryDiv = if Record.FieldCount(parts[Query]) > 0 then "?" else "",
        hostParts = Text.Split(parts[Host], "."),
        host = if Text.Contains(Text.From(parts[Host]), "localhost") 
            then 
                if List.Count(hostParts) > 1 then Text.Combine({hostParts{1}, ":", Text.From(parts[Port])})
                else Text.Combine({hostParts{0}, ":", Text.From(parts[Port])})
            else parts[Host],
        uri = Text.Combine({"https", "://", host, parts[Path], queryDiv, Uri.BuildQueryString(parts[Query])})
    in
        uri;

GetWebRequestHeaders = (resourceUrl as text) => 
    [
        #"x-tenant-id" = GetTenantFromHost(resourceUrl),
        #"Content-Type" = "application/json"
    ];
    
Web.Request = (resourceUrl as text, optional options) => AssembleViews_Impl(resourceUrl, options);

// Load modules

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

Table.ToNavigationTableNoPreviewDelay = (
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
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;