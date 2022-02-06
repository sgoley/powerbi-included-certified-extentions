[Version = "1.1.3"]
section AutomyDataAnalytics;

BaseUrl = "https://api.automy.global/powerbiConnector";

[DataSource.Kind="AutomyDataAnalytics", Publish="AutomyDataAnalytics.UI"]
shared AutomyDataAnalytics.Contents = () as table =>
    let       
       credential = Extension.CurrentCredential(),
       token = credential[Key],    

       objects = #table(
            {"Name",       "Key",  "Data",                "ItemKind", "ItemName", "IsLeaf"},{
            {Extension.LoadString("generic"),   "generic",   CreateGenericTable(), "Database",    "Database",    false},
            {Extension.LoadString("process"),   "process",   CreateProcessTable(), "Function",    "Function",    false}            
        }),     

        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

CreateGenericTable = () as table => 
    let
        tables = #table(            
            {"Name",       "Key",        "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            {Extension.LoadString("environments"),      "environments",      GenericTableNavigator("generic","environments"), "Table",    "Table",    true},
            {Extension.LoadString("processes"),      "processes",      GenericTableNavigator("generic","processes"), "Table",    "Table",    true},
            {Extension.LoadString("process-groups"),      "process-groups",      GenericTableNavigator("generic","process-groups"), "Table",    "Table",    true},
            {Extension.LoadString("users"),      "users",      GenericTableNavigator("generic","users"), "Table",    "Table",    true},
            {Extension.LoadString("user-groups"),      "user-groups",      GenericTableNavigator("generic","user-groups"), "Table",    "Table",    true},
            {Extension.LoadString("positions"),      "positions",      GenericTableNavigator("generic","positions"), "Table",    "Table",    true},
            {Extension.LoadString("entities"),      "entities",      GenericTableNavigator("generic","entities"), "Table",    "Table",    true},
            {Extension.LoadString("requests"),      "requests",      GenericTableNavigator("generic","requests"), "Table",    "Table",    true},            
            {Extension.LoadString("action-instances"),      "action-instances",      GenericTableNavigator("generic","action-instances"), "Table",    "Table",    true},
            {Extension.LoadString("user-instances"),      "user-instances",      GenericTableNavigator("generic","user-instances"), "Table",    "Table",    true},
            {Extension.LoadString("form-instances"),      "form-instances",      GenericTableNavigator("generic","form-instances"), "Table",    "Table",    true},
            {Extension.LoadString("form-instance-fields"),      "form-instance-fields",      GenericTableNavigator("generic","form-instance-fields"), "Table",    "Table",    true},
            {Extension.LoadString("forms"),      "forms",            GenericTableNavigator("generic","forms"), "Table",    "Table",    true},
            {Extension.LoadString("field-groups"),      "field-groups",      GenericTableNavigator("generic","field-groups"), "Table",    "Table",    true},
            {Extension.LoadString("fields"),      "fields",      GenericTableNavigator("generic","fields"), "Table",    "Table",    true}
            
        }),
        NavTable = Table.ToNavigationTable(tables, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

CreateProcessTable = () as table => 
    let
        functions = #table(                        
            {"Name",       "Key",        "Data",                           "ItemKind", "ItemName", "IsLeaf"},{            
            {Extension.LoadString("form-data"), "form-data", FormDataFunction.Contents,       "Function", "Function", true},
            {Extension.LoadString("form-table-data"), "form-table-data", FormTableDataFunction.Contents,       "Function", "Function", true},
            {Extension.LoadString("entity-data"), "entity-data", EntityDataFunction.Contents,       "Function", "Function", true},
            {Extension.LoadString("execution-steps"), "execution-steps", ExecutionStepFunction.Contents,       "Function", "Function", true},
            {Extension.LoadString("instance-approvers"), "instance-approvers", InstanceApproversFunction.Contents,       "Function", "Function", true},
            {Extension.LoadString("requests"), "requests", RequestsFunction.Contents,       "Function", "Function", true},
            {Extension.LoadString("action-instances"),      "action-instances",      ActionInstancesFunction.Contents, "Function",    "Function",    true},            
            {Extension.LoadString("form-instances"),      "form-instances",      FormInstancesFunction.Contents, "Function",    "Function",    true},
            {Extension.LoadString("form-instance-fields"),      "form-instance-fields",      FormInstanceFieldsFunction.Contents, "Function",    "Function",    true},
            {Extension.LoadString("forms"),      "forms",            FormsFunction.Contents, "Function",    "Function",    true},
            {Extension.LoadString("field-groups"),      "field-groups",      FieldGroupsFunction.Contents, "Function",    "Function",    true},
            {Extension.LoadString("fields"),      "fields",      FieldsFunction.Contents, "Function",    "Function",    true}

        }),
        NavTable = Table.ToNavigationTable(functions, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

GenericTableNavigator = (ReportType as text, DataType as text) as table => 
    let 
        credential = Extension.CurrentCredential(),
        token = credential[Key],  
        header = 
            [Headers=
                [
                    Authorization="Bearer "&token, 
                    #"Accept-Language"="en-us"], 
                    ManualStatusHandling = {400,404}
                ],
        content = Web.Contents(BaseUrl&"?reportType="&ReportType&"&dataType="&DataType, header),
        responseCode = Value.Metadata(content)[Response.Status],        
        contentJson = if responseCode <> 200 then error Json.Document(content)[message] else Json.Document(content),        
        table = Table.FromList(contentJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),                
        expand = Table.ExpandRecordColumn(table, "Column1", Record.FieldNames(table[Column1]{0}), Record.FieldNames(table[Column1]{0}))
    in
        expand;

FormDataFunction.Contents = (FormId as text) =>
    let
        credential = Extension.CurrentCredential(),
        token = credential[Key],  
        ReportType = "process",
        DataType = "form-data",
        header = 
            [Headers=
                [
                    Authorization="Bearer "&token, 
                    #"Accept-Language"="en-us"], 
                    ManualStatusHandling = {400,404}                    
                ],
        content = Web.Contents(BaseUrl&"?reportType="&ReportType&"&dataType="&DataType&"&formId="&FormId, header),
        responseCode = Value.Metadata(content)[Response.Status],        
        contentJson = if responseCode <> 200 then error Json.Document(content)[message] else Json.Document(content),
        table = Table.FromList(contentJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),                
        expand = Table.ExpandRecordColumn(table, "Column1", Record.FieldNames(table[Column1]{0}), Record.FieldNames(table[Column1]{0}))
    in
        expand;

FormTableDataFunction.Contents = (TableId as text) =>
    let
        credential = Extension.CurrentCredential(),
        token = credential[Key],  
        ReportType = "process",
        DataType = "form-table-data",
        header = 
            [Headers=
                [
                    Authorization="Bearer "&token, 
                    #"Accept-Language"="en-us"], 
                    ManualStatusHandling = {400,404}
                    
                ],
        content = Web.Contents(BaseUrl&"?reportType="&ReportType&"&dataType="&DataType&"&tableId="&TableId, header),
        responseCode = Value.Metadata(content)[Response.Status],        
        contentJson = if responseCode <> 200 then error Json.Document(content)[message] else Json.Document(content),
        table = Table.FromList(contentJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),                
        expand = Table.ExpandRecordColumn(table, "Column1", Record.FieldNames(table[Column1]{0}), Record.FieldNames(table[Column1]{0}))
    in
        expand;

EntityDataFunction.Contents = (EntityId as text) =>
    let
        credential = Extension.CurrentCredential(),
        token = credential[Key],  
        ReportType = "generic",
        DataType = "entity-data",
        header = 
            [Headers=
                [
                    Authorization="Bearer "&token, 
                    #"Accept-Language"="en-us"], 
                    ManualStatusHandling = {400,404}                    
                ],
        content = Web.Contents(BaseUrl&"?reportType="&ReportType&"&dataType="&DataType&"&entityId="&EntityId, header),
        responseCode = Value.Metadata(content)[Response.Status],        
        contentJson = if responseCode <> 200 then error Json.Document(content)[message] else Json.Document(content),
        table = Table.FromList(contentJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),                
        expand = Table.ExpandRecordColumn(table, "Column1", Record.FieldNames(table[Column1]{0}), Record.FieldNames(table[Column1]{0}))
    in
        expand;

ExecutionStepFunction.Contents = (ProcessId as text) =>
    let
        credential = Extension.CurrentCredential(),
        token = credential[Key],  
        ReportType = "process",
        DataType = "execution-steps",
        header = 
            [Headers=
                [
                    Authorization="Bearer "&token, 
                    #"Accept-Language"="en-us"], 
                    ManualStatusHandling = {400,404}                    
                ],
        content = Web.Contents(BaseUrl&"?reportType="&ReportType&"&dataType="&DataType&"&processId="&ProcessId, header),
        responseCode = Value.Metadata(content)[Response.Status],        
        contentJson = if responseCode <> 200 then error Json.Document(content)[message] else Json.Document(content),
        table = Table.FromList(contentJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),                
        expand = Table.ExpandRecordColumn(table, "Column1", Record.FieldNames(table[Column1]{0}), Record.FieldNames(table[Column1]{0}))
    in
        expand;

InstanceApproversFunction.Contents = (ProcessId as text) =>
    let
        credential = Extension.CurrentCredential(),
        token = credential[Key],  
        ReportType = "process",
        DataType = "instance-approvers",
        header = 
            [Headers=
                [
                    Authorization="Bearer "&token, 
                    #"Accept-Language"="en-us"], 
                    ManualStatusHandling = {400,404}                    
                ],
        content = Web.Contents(BaseUrl&"?reportType="&ReportType&"&dataType="&DataType&"&processId="&ProcessId, header),
        responseCode = Value.Metadata(content)[Response.Status],        
        contentJson = if responseCode <> 200 then error Json.Document(content)[message] else Json.Document(content),
        table = Table.FromList(contentJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),                
        expand = Table.ExpandRecordColumn(table, "Column1", Record.FieldNames(table[Column1]{0}), Record.FieldNames(table[Column1]{0}))
    in
        expand;

RequestsFunction.Contents = (ProcessId as text) =>
    let
        credential = Extension.CurrentCredential(),
        token = credential[Key],  
        ReportType = "process",
        DataType = "requests",
        header = 
            [Headers=
                [
                    Authorization="Bearer "&token, 
                    #"Accept-Language"="en-us"], 
                    ManualStatusHandling = {400,404}                    
                ],
        content = Web.Contents(BaseUrl&"?reportType="&ReportType&"&dataType="&DataType&"&processId="&ProcessId, header),
        responseCode = Value.Metadata(content)[Response.Status],        
        contentJson = if responseCode <> 200 then error Json.Document(content)[message] else Json.Document(content),
        table = Table.FromList(contentJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),                
        expand = Table.ExpandRecordColumn(table, "Column1", Record.FieldNames(table[Column1]{0}), Record.FieldNames(table[Column1]{0}))
    in
        expand;

ActionInstancesFunction.Contents = (ProcessId as text) =>
    let
        credential = Extension.CurrentCredential(),
        token = credential[Key],  
        ReportType = "process",
        DataType = "action-instances",
        header = 
            [Headers=
                [
                    Authorization="Bearer "&token, 
                    #"Accept-Language"="en-us"], 
                    ManualStatusHandling = {400,404}                    
                ],
        content = Web.Contents(BaseUrl&"?reportType="&ReportType&"&dataType="&DataType&"&processId="&ProcessId, header),
        responseCode = Value.Metadata(content)[Response.Status],        
        contentJson = if responseCode <> 200 then error Json.Document(content)[message] else Json.Document(content),
        table = Table.FromList(contentJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),                
        expand = Table.ExpandRecordColumn(table, "Column1", Record.FieldNames(table[Column1]{0}), Record.FieldNames(table[Column1]{0}))
    in
        expand;

FormInstancesFunction.Contents = (ProcessId as text) =>
    let
        credential = Extension.CurrentCredential(),
        token = credential[Key],  
        ReportType = "process",
        DataType = "form-instances",
        header = 
            [Headers=
                [
                    Authorization="Bearer "&token, 
                    #"Accept-Language"="en-us"], 
                    ManualStatusHandling = {400,404}                    
                ],
        content = Web.Contents(BaseUrl&"?reportType="&ReportType&"&dataType="&DataType&"&processId="&ProcessId, header),
        responseCode = Value.Metadata(content)[Response.Status],        
        contentJson = if responseCode <> 200 then error Json.Document(content)[message] else Json.Document(content),
        table = Table.FromList(contentJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),                
        expand = Table.ExpandRecordColumn(table, "Column1", Record.FieldNames(table[Column1]{0}), Record.FieldNames(table[Column1]{0}))
    in
        expand;

FormInstanceFieldsFunction.Contents = (ProcessId as text) =>
    let
        credential = Extension.CurrentCredential(),
        token = credential[Key],  
        ReportType = "process",
        DataType = "form-instance-fields",
        header = 
            [Headers=
                [
                    Authorization="Bearer "&token, 
                    #"Accept-Language"="en-us"], 
                    ManualStatusHandling = {400,404}                    
                ],
        content = Web.Contents(BaseUrl&"?reportType="&ReportType&"&dataType="&DataType&"&processId="&ProcessId, header),
        responseCode = Value.Metadata(content)[Response.Status],        
        contentJson = if responseCode <> 200 then error Json.Document(content)[message] else Json.Document(content),
        table = Table.FromList(contentJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),                
        expand = Table.ExpandRecordColumn(table, "Column1", Record.FieldNames(table[Column1]{0}), Record.FieldNames(table[Column1]{0}))
    in
        expand;

FormsFunction.Contents = (ProcessId as text) =>
    let
        credential = Extension.CurrentCredential(),
        token = credential[Key],  
        ReportType = "process",
        DataType = "forms",
        header = 
            [Headers=
                [
                    Authorization="Bearer "&token, 
                    #"Accept-Language"="en-us"], 
                    ManualStatusHandling = {400,404}                    
                ],
        content = Web.Contents(BaseUrl&"?reportType="&ReportType&"&dataType="&DataType&"&processId="&ProcessId, header),
        responseCode = Value.Metadata(content)[Response.Status],        
        contentJson = if responseCode <> 200 then error Json.Document(content)[message] else Json.Document(content),
        table = Table.FromList(contentJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),                
        expand = Table.ExpandRecordColumn(table, "Column1", Record.FieldNames(table[Column1]{0}), Record.FieldNames(table[Column1]{0}))
    in
        expand;

FieldGroupsFunction.Contents = (ProcessId as text) =>
    let
        credential = Extension.CurrentCredential(),
        token = credential[Key],  
        ReportType = "process",
        DataType = "field-groups",
        header = 
            [Headers=
                [
                    Authorization="Bearer "&token, 
                    #"Accept-Language"="en-us"], 
                    ManualStatusHandling = {400,404}                    
                ],
        content = Web.Contents(BaseUrl&"?reportType="&ReportType&"&dataType="&DataType&"&processId="&ProcessId, header),
        responseCode = Value.Metadata(content)[Response.Status],        
        contentJson = if responseCode <> 200 then error Json.Document(content)[message] else Json.Document(content),
        table = Table.FromList(contentJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),                
        expand = Table.ExpandRecordColumn(table, "Column1", Record.FieldNames(table[Column1]{0}), Record.FieldNames(table[Column1]{0}))
    in
        expand;

FieldsFunction.Contents = (ProcessId as text) =>
    let
        credential = Extension.CurrentCredential(),
        token = credential[Key],  
        ReportType = "process",
        DataType = "fields",
        header = 
            [Headers=
                [
                    Authorization="Bearer "&token, 
                    #"Accept-Language"="en-us"], 
                    ManualStatusHandling = {400,404}                    
                ],
        content = Web.Contents(BaseUrl&"?reportType="&ReportType&"&dataType="&DataType&"&processId="&ProcessId, header),
        responseCode = Value.Metadata(content)[Response.Status],        
        contentJson = if responseCode <> 200 then error Json.Document(content)[message] else Json.Document(content),
        table = Table.FromList(contentJson, Splitter.SplitByNothing(), null, null, ExtraValues.Error),                
        expand = Table.ExpandRecordColumn(table, "Column1", Record.FieldNames(table[Column1]{0}), Record.FieldNames(table[Column1]{0}))
    in
        expand;

// Data Source definition
AutomyDataAnalytics = [
    TestConnection = (dataSourcePath) => { "AutomyDataAnalytics.Contents" },
    Authentication = [        
        Key = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// UI Export definition
AutomyDataAnalytics.UI = [       
    Category = "Online Services",
    Beta = true,
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = Extension.LoadString("Website"),
    SourceImage = AutomyDataAnalytics.Icons,
    SourceTypeImage = AutomyDataAnalytics.Icons
];

AutomyDataAnalytics.Icons = [
    Icon16 = { Extension.Contents("AutomyDataAnalytics16.png"), Extension.Contents("AutomyDataAnalytics20.png"), Extension.Contents("AutomyDataAnalytics24.png"), Extension.Contents("AutomyDataAnalytics32.png") },
    Icon32 = { Extension.Contents("AutomyDataAnalytics32.png"), Extension.Contents("AutomyDataAnalytics40.png"), Extension.Contents("AutomyDataAnalytics48.png"), Extension.Contents("AutomyDataAnalytics64.png") }
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