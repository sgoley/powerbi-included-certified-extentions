[Version = "3.9.0"]
section BitSightSecurityRatings;


//
// Constants and Variables
// 

// Configuration
page_size = Number.ToText(250);
BaseUrl = "https://api.bitsighttech.com/";
rvhistory_period = "monthly";
rvlatest_period = "latest";
myInfrastructure_format = "csv";
myInfrastructure_type_IP = "ip";
myInfrastructure_type_domain = "domain";
helpURL = "https://overviewdocs.bitsighttech.com/BitSightForPowerBIAppTerms.pdf";
default_affects_rating_findings = "all";

// API Key Setup
apiKey = Binary.ToText(Text.ToBinary(Extension.CurrentCredential()[Key] & ":"), BinaryEncoding.Base64);

// URL Assemble
companyURL = BaseUrl & "ratings/v1/companies/";
findingsURL = BaseUrl & "ratings/v1/companies/company_guid/findings?expand=remediation_history,attributed_companies&limit=" & page_size;
rvhistoryURL = BaseUrl & "v1/portfolio/risk-vectors/grades?period=" & rvhistory_period & "&limit=" & page_size & "&company.guid=";
alertsURL = BaseUrl & "ratings/v2/alerts";
myinfrastructureURL_IP = BaseUrl & "ratings/v1/companies/company_guid/reports/infrastructure?format=" & myInfrastructure_format & "&type=" & myInfrastructure_type_IP;
myinfrastructureURL_domain = BaseUrl & "ratings/v1/companies/company_guid/reports/infrastructure?format=" & myInfrastructure_format & "&type=" & myInfrastructure_type_domain;
guidUrl = "https://api.bitsighttech.com/v1/users/current";
//addcontent
//group1
portfolioURL = BaseUrl & "ratings/v2/portfolio/";
portfolio2URL = BaseUrl & "ratings/v2/portfolio/";
portfolio3URL = BaseUrl & "ratings/v2/portfolio/";
rvlatestportURL=BaseUrl & "v1/portfolio/risk-vectors/grades?period=" & rvlatest_period & "&limit=" & page_size;
rvhistoryportURL=BaseUrl & "v1/portfolio/risk-vectors/grades?period=" & rvhistory_period & "&limit=" & page_size;
foldersURL=BaseUrl & "v1/folders";
tiersURL=BaseUrl & "v1/tiers";
ratingsURL=BaseUrl & "v1/portfolio/ratings?period=" & rvhistory_period;
//group2
breachesURL=BaseUrl & "v1/portfolio/breaches";
ratingchURL=BaseUrl & "v1/insights/rating_changes";
//group3
industryURL= BaseUrl & "ratings/v1/industries";
company_name = GetMyCompanyName();
//newImplementation
infrastructureURL= BaseUrl & "ratings/v1/companies/company_guid/infrastructure";
assetsURL= BaseUrl & "ratings/v1/companies/company_guid/assets?expand=tag_details";

// HTTP Headers
FirstRequestHeaders = [
    Authorization = "Basic " & apiKey,
    Accept = "application/json",
    #"Content-Type" = "application/json",
    #"X-BITSIGHT-CONNECTOR-NAME-VERSION" = "Power Query app v3.9.0",
    #"X-BITSIGHT-CALLING-PLATFORM-VERSION" = "PowerBI",
    #"X-BITSIGHT-CUSTOMER" = "GET Customer Name"
];

DefaultRequestHeaders = [
    Authorization = "Basic " & apiKey,
    Accept = "application/json",
    #"Content-Type" = "application/json",
    #"X-BITSIGHT-CONNECTOR-NAME-VERSION" = "Power Query app v3.9.0",
    #"X-BITSIGHT-CALLING-PLATFORM-VERSION" = "PowerBI",
    #"X-BITSIGHT-CUSTOMER" = company_name
];

// Entities List for the Navigation Table
RootEntities = #table({"entity_order","entity_name","endpoint","flag","url"}, {
    {0,"Details","company","d",companyURL},
    {1,"Ratings History","company","h",companyURL},
    {2,"Current Risk Vector Grades","company","g",companyURL},
    {3,"Findings","findings","a",findingsURL},
    {4,"Risk Vector History","rvhistory","a",rvhistoryURL},
    {5,"Alerts","alerts","a",alertsURL},
    {6,"IPs","myinfrastructure","i",myinfrastructureURL_IP},
    {7,"Domains","myinfrastructure","d",myinfrastructureURL_domain},
    {8,"Portfolio Companies","portfolio","a",portfolioURL},
    {9,"Portfolio Risk Vector History","rvhistoryport","a",rvhistoryportURL},
    {10,"Portfolio Risk Vector Latest","rvlatestport","a",rvlatestportURL},
    {11,"Folders","folders","a",foldersURL},
    {12,"Tiers", "tiers","a",tiersURL},
    {13,"Portfolio Ratings History", "ratings","a",ratingsURL},
    {11,"Breaches","breaches","a",breachesURL},
    {12,"Rating Changes", "ratingch","a",ratingchURL},
    {13,"Industries", "industry","a",industryURL},
    {14,"Infrastructure", "infrastructure","a",infrastructureURL},
    {15,"Assets", "assets","a",assetsURL}
  });

// TODO: implement advanced schemas in the deeply nested data sources
FindingsType = type table [
	affects_rating = logical,
	assets = list,
	details = FindingsDetailsType,
	evidence_key = text,
	first_seen = date,
	last_seen = date,
	risk_category = text,
	risk_vector = text,
	risk_vector_label = text,
	rolledup_observation_id = text,
	severity = number,
	severity_category = text,
	tags = list,
	remediation_history = RemediationHistoryType,
	comments = text,
	attributed_companies = list,
    message = text
];

FindingsDetailsType = type table [
    grade = text,
    infection = text,
    observed_ips = text,
    vulnerabilities = text,
    message = text
];

RemediationHistoryType = type table [
    last_requested_refresh_date = date,
    last_refresh_status_date = date,
    last_refresh_status_label = text,
    last_remediation_status_label = text,
    last_remediation_status_date = text,
    remediation_assignments = {text},
    last_remediation_status_updated_by = text
];

DetailsType = type table [
		guid = text,
		custom_id = text,
		name = text,
		description = text,
		ipv4_count = number,
		people_count = number,
		shortname = text,
		industry = text,
		industry_slug = text,
		sub_industry = text,
		sub_industry_slug = text,
		homepage = text,
		primary_domain = text,
		#"type" = text,
		display_url = text,
		search_count = number,
		subscription_type = text,
		sparkline = text,
		subscription_type_key = text,
		subscription_end_date = date,
		bulk_email_sender_status = text,
		service_provider = logical,
		customer_monitoring_count = number,
		available_upgrade_types = list,
		has_company_tree = logical,
		has_preferred_contact = logical,
		is_bundle = logical,
		rating_industry_median = text,
		primary_company = record,
		permissions = record,
		is_primary = logical,
		in_spm_portfolio = logical,
		is_mycomp_mysubs_bundle = logical,
		company_features = list
];

BitSightRatingsHistoryType = type table [
        guid = text,
		rating_date = date,
		rating = number,
		range = text,
		rating_color = text
];

CurrentRiskVectorGradesType = type table [
		category = text,
		rating = number,
		beta = logical,
		percentile = number,
		name = text,
		display_url = text,
		grade = text,
		category_order = number,
		order = number,
		grade_color = text
];

RiskVectorHistoryType = type table [
        date = date,
        risk_vectors = list
];

AlertsType = type table [
		guid = text,
		alert_type = text,
		alert_date = date,
		start_date = date,
		company_name = text,
		company_guid = text,
		company_url = text,
		folder_guid = text,
		folder_name = text,
		severity = text,
		trigger = text
];

IPsType = type table [
		#"CIDR Block" = text,
		Country = text,
		#"Start Date" = date,
		#"End Date" = text,
		#"Attributed To" = text,
		#"IP Count" = Int64.Type,
		Tags = text,
		Source = text,
		Link = text,
		#"AS Number" = text,
		Reasons = text,
		Notes = text,
		SSIDS = text
];

DomainsType = type table [
		#"Domain Name" = text,
		#"Start Date" = date,
		#"End Date" = text,
		#"Attributed To" = text,
		Tags = text
];

Infrastructure = type table [
		source = record
];

//END TODO

SchemaTable = #table({"Entity", "SchemaTable"}, {
    {"Details", #table({"Name", "Type"}, {
		{"guid", type text},
		{"custom_id", type text},
		{"name", type text},
		{"description", type text},
		{"ipv4_count", type number},
		{"people_count", type number},
		{"shortname", type text},
		{"industry", type text},
		{"industry_slug", type text},
		{"sub_industry", type text},
		{"sub_industry_slug", type text},
		{"homepage", type text},
		{"primary_domain", type text},
		{"type", type text},
		{"display_url", type text},
		{"search_count", type number},
		{"subscription_type", type text},
		{"sparkline", type text},
		{"subscription_type_key", type text},
		{"subscription_end_date", type date},
		{"bulk_email_sender_status", type text},
		{"service_provider", type logical},
		{"customer_monitoring_count", type number},
		{"available_upgrade_types", type list},
		{"has_company_tree", type logical},
		{"has_preferred_contact", type logical},
		{"is_bundle", type logical},
		{"rating_industry_median", type text},
		{"primary_company", type record},
		{"permissions", type record},
		{"is_primary", type logical},
		{"in_spm_portfolio", type logical},
		{"is_mycomp_mysubs_bundle", type logical},
		{"company_features", type list}
	})},

	{"Ratings History", #table({"Name", "Type"}, {
        {"guid", type text},
		{"rating_date", type date},
		{"rating", type number},
		{"range", type text},
		{"rating_color", type text}
	})},

    {"Current Risk Vector Grades", #table({"Name", "Type"}, {
		{"category", type text},
		{"rating", type number},
		{"beta", type logical},
		{"percentile", type number},
		{"name", type text},
		{"display_url", type text},
		{"grade", type text},
		{"category_order", type number},
		{"order", type number},
		{"grade_color", type text}
    })},

    {"Findings", #table({"Name", "Type"}, {
		{"affects_rating", type logical},
		{"assets", type list},
		{"details", type record},
		{"evidence_key", type text},
		{"first_seen", type date},
		{"last_seen", type date},
		{"risk_category", type text},
		{"risk_vector", type text},
		{"risk_vector_label", type text},
		{"rolledup_observation_id", type text},
		{"severity", type number},
		{"severity_category", type text},
		{"tags", type list},
		{"remediation_history", type any},
		{"comments", type text},
		{"attributed_companies", type list},
        {"message", type text}
    })},    

    {"Risk Vector History", #table({"Name", "Type"}, {
        {"date", type date},
        {"risk_vectors", type list}
    })},

    {"Alerts", #table({"Name", "Type"}, {
		{"guid", type text},
		{"alert_type", type text},
		{"alert_date", type date},
		{"start_date", type date},
		{"company_name", type text},
		{"company_guid", type text},
		{"company_url", type text},
		{"folder_guid", type text},
		{"folder_name", type text},
		{"severity", type text},
		{"trigger", type text}
    })},

    {"IPs", #table({"Name", "Type"}, {
		{"CIDR Block", type text},
		{"Country", type text},
		{"Start Date", type date},
		{"End Date", type text},
		{"Attributed To", type text},
		{"IP Count", Int64.Type},
		{"Tags", type text},
		{"Source", type text},
		{"Link", type text},
		{"AS Number", type text},
		{"Reasons", type text},
		{"Notes", type text},
		{"SSIDS", type text}
    })},

    {"Domains", #table({"Name", "Type"}, {
		{"Domain Name", type text},
		{"Start Date", type date},
		{"End Date", type text},
		{"Attributed To", type text},
		{"Tags", type text}
    })},

    {"Portfolio Companies", #table({"Name", "Type"}, {
        {"guid", type text},
        {"custom_id", type any}, 
        {"name", type text},  
        {"rating", type number},
        {"rating_date", type date}, 
        {"industry", type record},
        {"sub_industry", type record}, 
        {"type", type list},
        {"subscription_type", type record},
        {"primary_domain", type text},
        {"tier", type text}, 
        {"tier_name", type text}, 
        {"life_cycle", type any}, 
        {"relationship", type record}
    })}, 

    {"Portfolio Risk Vector Latest", #table({"Name", "Type"}, {
       {"company", type record},
       {"grades", type list}
       
    })},

    {"Portfolio Risk Vector History", #table({"Name", "Type"}, {
       {"company", type record},
       {"grades", type list}
    })},

    {"Folders", #table({"Name", "Type"}, {
       {"guid", type text},
       {"name", type text}, 
       {"description", type any},
       {"companies", type list}

    })},

     {"Tiers", #table({"Name", "Type"}, {
       {"rank", type number},
       {"guid", type text},
       {"name", type text},
       {"description", type text},
       {"companies", type list}

    })},

    {"Portfolio Ratings History", #table({"Name", "Type"}, {
       {"guid", type text},
       {"ratings", type list},
       {"name", type text},
       {"current_rating", type number}

    })},

    {"Breaches", #table({"Name", "Type"}, {
       {"date", type date},
       {"date_created", type date},
       {"severity", type number},
       {"text", type text}, 
       {"preview_url", type text},
       {"event_type", type text}, 
       {"event_type_description", type text},
       {"category_slug", type text}, 
       {"category_name", type text}, 
       {"breached_company", type record}, 
       {"affected_portfolio_company", type record}
    })},

    {"Rating Changes", #table({"Name", "Type"}, {
       {"date", type date}, 
       {"start_score", type number}, 
       {"end_score",  type number}, 
       {"reasons", type list},
       {"type", type text}, 
       {"company", type text}

    })},

    {"Industries", #table({"Name", "Type"}, {
       {"rating_date", type date},
       {"industries", type record}

    })},

    {"Infrastructure", #table({"Name", "Type"}, {
       {"value", type text},
       {"source", type record},
       {"tags", type list},
       {"country", type record},
       {"start_date", type date},
       {"end_date", type date},
       {"is_active", type logical},
       {"attributed_to", type record},
       {"asn", type record},
       {"ip_count", type number},
       {"is_suppressed", type logical}
    })},

    {"Assets", #table({"Name", "Type"}, {
       {"asset", type text}, 
       {"asset_type", type text}, 
       {"tag_details",  type text}, 
       {"combined_overrides", type text},
       {"app_grade", type text}, 
       {"country", type text},
       {"services", type text},
       {"products", type text},
       {"hosted_by", type text},
       {"findings.count_by_severity", type text},
       {"findings.total_count", type text},
       {"origin_subsidiary", type text}

    })}

});


GetSchemaForEntity = (entity as text) as table => try SchemaTable{[Entity=entity]}[SchemaTable] otherwise error "Couldn't find entity: '" & entity &"'";

//
// Implementation
// 
[DataSource.Kind="BitSightSecurityRatings", Publish="BitSightSecurityRatings.Publish"]
shared BitSightSecurityRatings.Contents = (optional company_guid as text, optional affects_rating_findings as logical) => BitSightSecurityRatings.Navigation(company_guid, affects_rating_findings) as table;

// Data Source Kind Description
BitSightSecurityRatings = [
    // TestConnection is required to enable the connector through the Gateway
    TestConnection = (dataSourcePath) =>  { "BitSightSecurityRatings.Contents"},
    Authentication = [
        Key = [
            KeyLabel = Extension.LoadString("TokenFormLabel"),
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI Publishing Description
BitSightSecurityRatings.Publish = [
    Beta = false,
    Category = "Other",
    LearnMoreUrl = helpURL,
    ButtonText = { Extension.LoadString("Title"), Extension.LoadString("FormulaHelp") },
    SourceImage = BitSightSecurityRatings.Icons,
    SourceTypeImage = BitSightSecurityRatings.Icons
];

// Build top level navitation bar
BitSightSecurityRatings.Navigation = (optional company_guid as text, optional affects_rating_findings as logical) as table =>
let
       
        company_guid = if (company_guid <> null) then company_guid else GetMyCompanyGUID(),
        far = if(affects_rating_findings <> null) then if affects_rating_findings then "true" else "false" else default_affects_rating_findings,
        objects = #table(
            {"Name","Key","Data","ItemKind","ItemName","IsLeaf"},{
            {"My Company","My Company",CompanyNavTable(company_guid, far),"Folder","My Company",false},
            {"Others","Others",OthersNavTable(company_guid, far),"Folder","Others",false},
            {"My Infrastructure","My Infrastructure",MyInfrastructureNavTable(company_guid, far),"Folder","My Infrastructure",false},
            {"Portfolio","Portfolio",PortfolioNavTable(company_guid, far),"Folder","Portfolio",false}
        }),
        NavTable = Table.ToNavigationTable(objects,{"Key"},"Name","Data","ItemKind","ItemName","IsLeaf")
in
        NavTable;

// Company Navigation Bar
CompanyNavTable = (company_guid as text, affects_rating_findings as text) as table =>
    let
        entitiesAsTable = Table.SelectRows(Table.SelectColumns(RootEntities,{"entity_name","endpoint","flag","url"}), each [endpoint] = "company" or [endpoint] = "rvhistory"),
        rename = Table.RenameColumns(entitiesAsTable, {{"entity_name", "Name"}}),
        withData =  Table.AddColumn(rename, "Data", each GetEntity([url], [endpoint], [flag], company_guid, [Name], affects_rating_findings), type table),
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Table", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table", type text),
        // Indicate that the node should not be expandable
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true, type logical),
        // Generate the nav table
        navTable = Table.ToNavigationTable(withIsLeaf, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

// Others Navigation Bar
OthersNavTable = (company_guid as text, affects_rating_findings as text) as table =>
    let
        entitiesAsTable = Table.SelectRows(Table.SelectColumns(RootEntities,{"entity_name","endpoint","flag","url"}), each [endpoint] <> "company" and [endpoint] <> "myinfrastructure" and [endpoint] <> "findings" and [endpoint] <> "rvhistory" and [endpoint] <> "portfolio" and [endpoint] <> "rvhistoryport" and [endpoint] <> "rvlatestport" and [endpoint] <> "ratingch" and [endpoint] <> "ratings" and [endpoint] <> "folders" and [endpoint] <> "tiers" and [endpoint] <> "breaches" and [endpoint] <> "industry" and [endpoint] <> "infrastructure" and [endpoint] <> "assets"),
        rename = Table.RenameColumns(entitiesAsTable, {{"entity_name", "Name"}}),
        withData =  Table.AddColumn(rename, "Data", each GetEntity([url], [endpoint], [flag], company_guid, [Name], affects_rating_findings), type table),
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Table", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table", type text),
        // Indicate that the node should not be expandable
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true, type logical),
        // Generate the nav table
        navTable = Table.ToNavigationTable(withIsLeaf, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

       

// My Infrastructure Navigation Bar
MyInfrastructureNavTable = (company_guid as text,  affects_rating_findings as text) as table =>
    let
        entitiesAsTable = Table.SelectRows(Table.SelectColumns(RootEntities,{"entity_name","endpoint","flag","url"}), each [endpoint] = "myinfrastructure" or [endpoint] = "findings" or [endpoint] = "infrastructure" or [endpoint] = "assets"),
        rename = Table.RenameColumns(entitiesAsTable, {{"entity_name", "Name"}}),
        guids = GetMyCompanyAllGUIDs(),
        withData =  Table.AddColumn(rename, "Data", each GetEntity([url], [endpoint], [flag], company_guid, [Name], affects_rating_findings), type table),
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Table", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table", type text),
        // Indicate that the node should not be expandable
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true, type logical),
        // Generate the nav table
        navTable = Table.ToNavigationTable(withIsLeaf, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

// Portfolio Navigation Bar
 PortfolioNavTable = (company_guid as text,  affects_rating_findings as text) as table =>
    let
        entitiesAsTable = Table.SelectRows(Table.SelectColumns(RootEntities,{"entity_name","endpoint","flag","url"}), each [endpoint] = "portfolio" or [endpoint] = "rvhistoryport" or [endpoint]= "rvlatestport" or [endpoint]= "ratingch" or [endpoint] = "ratings" or [endpoint]= "folders" or [endpoint] = "tiers" or [endpoint]= "breaches" or [endpoint]= "industry"),
        rename = Table.RenameColumns(entitiesAsTable, {{"entity_name", "Name"}}),
        withData =  Table.AddColumn(rename, "Data", each GetEntity([url], [endpoint], [flag], company_guid, [Name], affects_rating_findings), type table),
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Table", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table", type text),
        // Indicate that the node should not be expandable
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true, type logical),
        // Generate the nav table
        navTable = Table.ToNavigationTable(withIsLeaf, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

// Obtain an endpoint entity and apply schema
GetEntity = (url as text, endpoint as text, flag as text, company_guid as text, entity_name as text, optional affects_rating_findings as text) as table => 
    let
        schemaTable = GetSchemaForEntity(entity_name),
        result =    if endpoint = "company" and flag = "d" then
                        BitSightSecurityRatingsCompanyDetails.Feed(url, endpoint, flag, company_guid, schemaTable)
                    else if endpoint = "company" and flag = "h" then
                        BitSightSecurityRatingsCompanyRatings.Feed(url, endpoint, flag, company_guid, schemaTable)
                    else if endpoint = "company" and flag = "g" then
                        BitSightSecurityRatingsCompanyGrades.Feed(url, endpoint, flag, company_guid, schemaTable)
                    else if endpoint = "alerts" or endpoint = "rvhistory" or endpoint = "findings" or endpoint = "portfolio" or endpoint = "rvhistoryport" or endpoint= "rvlatestport" or endpoint= "ratingch" or endpoint = "findingsport" or endpoint = "summaries" or endpoint = "infrastructure" or endpoint = "assets" then 
                        PaginatedResult(url, company_guid, endpoint, affects_rating_findings, schemaTable)
                    else if endpoint = "myinfrastructure" then 
                        BitSightSecurityRatingsMyInfrastructure.Feed(url, flag, company_guid, schemaTable)
                    else if endpoint = "folders" then 
                        BitSightSecurityRatingsFolders.Feed(url, flag, company_guid, schemaTable)
                    else if endpoint = "tiers" then 
                        BitSightSecurityRatingsTiers.Feed(url, flag, company_guid, schemaTable)
                    else if endpoint = "ratings" then 
                        BitSightSecurityRatingsRating.Feed(url, flag, company_guid, schemaTable)
                    else if endpoint = "breaches" then 
                        BitSightSecurityRatingsBreaches.Feed(url, flag, company_guid, schemaTable)
                    else if endpoint = "industry" then 
                        BitSightSecurityRatingsIndustry.Feed(url, flag, company_guid, schemaTable)
                    else 
                        error Extension.LoadString("EndpointWithNoDataFunctionError")
    in
        result;

// Company - Obtain Data for Company Details
BitSightSecurityRatingsCompanyDetails.Feed = (url as text, endpoint as text, flag as text, company_guid as text, optional schema as table) =>
    let
        source = Web.Contents(url & company_guid, [ Headers = DefaultRequestHeaders ]),
        json = Json.Document(source),
        table = Record.ToTable(json),
        company_details = Table.Pivot(table, List.Distinct(table[Name]), "Name", "Value"),
        withSchema = if (schema <> null) then SchemaTransformTable(company_details, schema) else company_details,
        //Start: Code block not yet with dynamic schema treatment
        #"Expanded available_upgrade_types" = Table.ExpandListColumn(withSchema, "available_upgrade_types"),
        #"Expanded primary_company" = Table.ExpandRecordColumn(#"Expanded available_upgrade_types", "primary_company", {"guid", "name"}, {"primary_company.guid", "primary_company.name"}),
        #"Expanded permissions" = Table.ExpandRecordColumn(#"Expanded primary_company", "permissions", {"can_download_company_report", "can_view_forensics", "can_view_service_providers", "can_request_self_published_entity", "can_view_infrastructure", "can_annotate", "can_view_company_reports", "can_manage_primary_company", "has_control"}, {"permissions.can_download_company_report", "permissions.can_view_forensics", "permissions.can_view_service_providers", "permissions.can_request_self_published_entity", "permissions.can_view_infrastructure", "permissions.can_annotate", "permissions.can_view_company_reports", "permissions.can_manage_primary_company", "permissions.has_control"}),
        #"Expanded company_features" = Table.ExpandListColumn(#"Expanded permissions", "company_features"),
        #"Changed Type" = Table.TransformColumnTypes(#"Expanded company_features",{{"permissions.has_control", type logical}, {"permissions.can_manage_primary_company", type logical}, {"permissions.can_view_company_reports", type logical}, {"permissions.can_annotate", type logical}, {"permissions.can_view_infrastructure", type logical}, {"permissions.can_request_self_published_entity", type logical}, {"permissions.can_view_service_providers", type logical}, {"permissions.can_view_forensics", type logical}, {"permissions.can_download_company_report", type logical}}),
        //End: Code block not yet with dynamic schema treatment
        output = #"Changed Type"
    in
        output;

// Company - Obtain Data for Current Risk Vector Grades
BitSightSecurityRatingsCompanyGrades.Feed = (url as text, endpoint as text, flag as text, company_guid as text, optional schema as table) =>
    let
        source = Web.Contents(url & company_guid, [ Headers = DefaultRequestHeaders ]),
        json = Json.Document(source),
        company_actual_grades = json[rating_details],
        company_actual_grades_table = Table.RenameColumns(Record.ToTable(company_actual_grades),{{"Name", "risk_vector"}}),
        company_actual_grades_fields = Record.FieldNames(Table.FirstValue(Table.FromValue(company_actual_grades_table[Value]), [Empty = null])),
        company_actual_grades_expanded = Table.ExpandRecordColumn(company_actual_grades_table, "Value", company_actual_grades_fields),
        withSchema = if (schema <> null) then SchemaTransformTable(company_actual_grades_expanded, schema) else company_actual_grades_expanded,
        //Start: Code block not yet with dynamic schema treatment
        #"Replaced Errors" = Table.ReplaceErrorValues(withSchema, {{"rating", null}}),
        #"Replaced Errors1" = Table.ReplaceErrorValues(#"Replaced Errors", {{"percentile", null}}),
        //End: Code block not yet with dynamic schema treatment
        output = #"Replaced Errors1"
    in
        output;

// Company - Obtain Data for Company Ratings
BitSightSecurityRatingsCompanyRatings.Feed = (url as text, endpoint as text, flag as text, company_guid as text, optional schema as table) =>
    let
        source = Web.Contents(url & company_guid, [ Headers = DefaultRequestHeaders ]),
        json = Json.Document(source),
        company_hist_ratings = json[ratings],
        company_hist_ratings_table = Table.FromList(company_hist_ratings, Splitter.SplitByNothing()),
        company_hist_ratings_fields = Record.FieldNames(Table.FirstValue(company_hist_ratings_table, [Empty = null])),
        company_hist_ratings_expanded = Table.ExpandRecordColumn(company_hist_ratings_table, "Column1", company_hist_ratings_fields),
        added_guid = Table.AddColumn(company_hist_ratings_expanded, "guid", each company_guid),
        withSchema = if (schema <> null) then SchemaTransformTable(added_guid, schema) else added_guid,
        output = withSchema
    in
        output;

        //Folders DATA
BitSightSecurityRatingsFolders.Feed = (url as text, endpoint as text, flag as text, optional schema as table) =>
    let
        source = Web.Contents(url, [ Headers = DefaultRequestHeaders ]),
        json = Json.Document(source),
        folders_table = Table.FromList(json, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        table_fields = Record.FieldNames(Table.FirstValue(folders_table, [Empty = null])),
        expanded = Table.ExpandRecordColumn(folders_table, "Column1", table_fields),
        withSchema = if (schema <> null) then SchemaTransformTable(expanded, schema) else expanded,
        //Start: Code block not yet with dynamic schema treatment
       #"companies Expandida" = Table.ExpandListColumn(withSchema, "companies"),
       #"Renamed Columns1" = Table.RenameColumns(#"companies Expandida",{{"companies", "Company Guid"}}),
       //End: Code block not yet with dynamic schema treatment
        output = #"Renamed Columns1"
    in
        output;

//Tiers DATA
BitSightSecurityRatingsTiers.Feed = (url as text, endpoint as text, flag as text, optional schema as table) =>
    let
        source = Web.Contents(url, [ Headers = DefaultRequestHeaders ]),
        json = Json.Document(source),
        tiers_table = Table.FromList(json, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        table_fields = Record.FieldNames(Table.FirstValue(tiers_table, [Empty = null])),
        expanded = Table.ExpandRecordColumn(tiers_table, "Column1", table_fields),
        withSchema = if (schema <> null) then SchemaTransformTable(expanded, schema) else expanded,
        //Start: Code block not yet with dynamic schema treatment
        #"companies Expandida" = Table.ExpandListColumn(withSchema, "companies"),
        #"Renamed Columns1" = Table.RenameColumns(#"companies Expandida",{{"companies", "Company Guid"}}),
         //End: Code block not yet with dynamic schema treatment
        output =  #"Renamed Columns1"
    in
        output;

//Rating DATA
BitSightSecurityRatingsRating.Feed = (url as text, endpoint as text, flag as text, optional schema as table) =>
    let
        source = Web.Contents(url, [ Headers = DefaultRequestHeaders ]),
        json = Json.Document(source),
        tiers_table = Table.FromList(json, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        table_fields = Record.FieldNames(Table.FirstValue(tiers_table, [Empty = null])),
        expanded = Table.ExpandRecordColumn(tiers_table, "Column1", table_fields),
        withSchema = if (schema <> null) then SchemaTransformTable(expanded, schema) else expanded,
        //Start: Code block not yet with dynamic schema treatment
        #"ratings Expandida" = Table.ExpandListColumn(withSchema, "ratings"),
        #"ratings Expandida1" = Table.ExpandRecordColumn(#"ratings Expandida", "ratings", {"date", "rating"}, {"ratings.date", "ratings.rating"}),
        #"Renamed Columns1" = Table.RenameColumns(#"ratings Expandida1",{{"ratings.date", "Date"}, {"ratings.rating", "Rating"}, {"current_rating", "Current Rating"}}),  
        //End: Code block not yet with dynamic schema treatment
        output =  #"Renamed Columns1"
    in
        output;

        //Breaches DATA
BitSightSecurityRatingsBreaches.Feed = (url as text, endpoint as text, flag as text, optional schema as table) =>
   let
        source = Web.Contents(url, [ Headers = DefaultRequestHeaders ]),
        json = Json.Document(source),
        tiers_table = Table.FromList(json, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        table_fields = Record.FieldNames(Table.FirstValue(tiers_table, [Empty = null])),
        expanded = Table.ExpandRecordColumn(tiers_table, "Column1", table_fields),
        withSchema = if (schema <> null) then SchemaTransformTable(expanded, schema) else expanded,
        //Start: Code block not yet with dynamic schema treatment
        #"Expanded breached_company" = Table.ExpandRecordColumn(withSchema, "breached_company", {"guid", "name"}, {"breached_company.guid", "breached_company.name"}),
        #"Expanded affected_portfolio_company" = Table.ExpandRecordColumn(#"Expanded breached_company", "affected_portfolio_company", {"guid", "name"}, {"affected_portfolio_company.guid", "affected_portfolio_company.name"}),
        #"Renamed Columns1" = Table.RenameColumns(#"Expanded affected_portfolio_company",{{"affected_portfolio_company.guid", "Affected Company Guid"}, {"affected_portfolio_company.name", "Affected Company Name"}}),
      
        //End: Code block not yet with dynamic schema treatment
        output =  #"Renamed Columns1"
    in
        output;

        //Industry DATA
BitSightSecurityRatingsIndustry.Feed = (url as text, endpoint as text, flag as text, optional schema as table) =>
   let
        source = Web.Contents(url, [ Headers = DefaultRequestHeaders ]),
        json = Json.Document(source),
        table = Record.ToTable(json),
        company_details = Table.Pivot(table, List.Distinct(table[Name]), "Name", "Value"),
        withSchema = if (schema <> null) then SchemaTransformTable(company_details, schema) else company_details,
        //Start: Code block not yet with dynamic schema treatment
        #"Expanded industries" = Table.ExpandListColumn(withSchema, "industries"),
        #"Expanded industries1" = Table.ExpandRecordColumn(#"Expanded industries", "industries", {"name", "slug", "rating", "href", "id"}, {"industries.name", "industries.slug", "industries.rating", "industries.href", "industries.id"}),
        #"Removed Columns" = Table.RemoveColumns(#"Expanded industries1",{"industries.href", "industries.id"}),
        #"Renamed Columns" = Table.RenameColumns(#"Removed Columns",{{"industries.name", "Industries Name"}, {"industries.slug", "Industries Slug"}, {"industries.rating", "Industries Rating"}, {"rating_date", "Rating Date"}}),

        //End: Code block not yet with dynamic schema treatment
        output = #"Renamed Columns"
    in
        output;

       
// Findings - Obtain Findings - Paginated
// BitSightSecurityRatingsFindings.Feed = (url as text, company_guid as text, optional schema as table) as table => GetAllPagesByNextLink(url, company_guid, null, schema);

// Findings - Obtain Findings - Paginated
PaginatedResult = (url as text, company_guid as text, endpoint as text, affects_rating_findings as text, optional schema as table) as table => GetAllPagesByNextLink(url, company_guid, affects_rating_findings, endpoint, schema);

// Obtain Links - Pagination
GetAllPagesByNextLink = (url as text, company_guid as text, affects_rating_findings as text, optional endpoint as text, optional schema as table) as table =>
    Table.GenerateByPage((previous) => 
        let
            // if previous is null, then this is our first page of data
            nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
            // if NextLink was set to null by the previous call, we know we have no more data
            page = if (nextLink <> null) then 
                                                if endpoint = "findings" then 
                                                    GetPageFindings(nextLink, company_guid, affects_rating_findings, schema)
                                                else if endpoint = "alerts" then 
                                                    GetPageAlerts(nextLink, schema)
                                                else if endpoint = "rvhistory" then 
                                                    GetPageRVHistory(nextLink, company_guid, schema)
                                                else if endpoint = "portfolio" then
                                                    GetPagePortfolio(nextLink, schema)
                                                else if endpoint = "rvhistoryport" then
                                                    GetPageRVHistoryPort(nextLink,schema)
                                                else if endpoint = "rvlatestport" then
                                                    GetPageRVLatestPort(nextLink, schema)
                                                else if endpoint = "ratingch" then
                                                    GetPageRatingCH(nextLink, schema)
                                                else if endpoint = "infrastructure" then
                                                    GetPageInfrastructure(nextLink,  company_guid, schema)
                                                else if endpoint = "assets" then
                                                    GetPageAssets(nextLink,  company_guid, schema)
                                                else error Extension.LoadString("EndpointWithNoPaginationError")
                   else null
        in
            page
    );
    
// Findings - Obtain Data Page
GetPageFindings = (url as text, company_guid as text, affects_rating_findings as text, optional schema as table) as table =>
    let
        new_url = if affects_rating_findings <> "all" then url & "&affects_rating=" & affects_rating_findings else url,
        response = Web.Contents(Text.Replace(new_url, "company_guid", company_guid), [ Headers = DefaultRequestHeaders ]),
        json = Json.Document(response, TextEncoding.Utf8),
        nextLink = json[links][next],
        counts = json[count],
        results = json[results],
        table = Table.FromList(results, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        table_fields = Record.FieldNames(Table.FirstValue(table, [Empty = null])),
        expanded = Table.ExpandRecordColumn(table, "Column1", table_fields),
        expanded_column1 = Table.ExpandRecordColumn(table, "Column1", {"affects_rating", "assets", "details", "evidence_key", "first_seen", "last_seen", "risk_category", "risk_vector", "risk_vector_label", "rolledup_observation_id", "severity", "severity_category", "tags", "remediation_history", "comments", "attributed_companies", "duration", "remaining_decay"}, {"affects_rating", "assets", "details", "evidence_key", "first_seen", "last_seen", "risk_category", "risk_vector", "risk_vector_label", "rolledup_observation_id", "severity", "severity_category", "tags", "remediation_history", "comments", "attributed_companies", "duration", "remaining_decay"}),
        expanded_details = Table.ExpandRecordColumn(expanded_column1, "details", {"diligence_annotations", "grade", "infection", "observed_ips", "vulnerabilities", "remediations", "geo_ip_location","dest_port","country","port_list","operating_system_version","user_agent_family","user_agent_version"}, {"details.diligence_annotations", "details.grade", "details.infection", "details.observed_ips", "details.vulnerabilities", "details.remediations", "details.geo_ip_location", "details.dest_port", "details.country", "details.port_list","details.operating_system_version","details.user_agent_family","details.user_agent_version"}),
        expanded_remediation_history = Table.ExpandRecordColumn(expanded_details, "remediation_history", {"last_requested_refresh_date", "last_refresh_status_date", "last_refresh_status_label", "last_remediation_status_label", "last_remediation_status_date", "remediation_assignments", "last_remediation_status_updated_by"}, {"last_requested_refresh_date", "last_refresh_status_date", "last_refresh_status_label", "last_remediation_status_label", "last_remediation_status_date", "remediation_assignments", "last_remediation_status_updated_by"}),
        expanded_attributed_companies = Table.ExpandListColumn(expanded_remediation_history, "attributed_companies"),
        expanded_attributed_companies1 = Table.ExpandRecordColumn(expanded_attributed_companies, "attributed_companies", {"guid", "name"}, {"attributed_companies.guid", "attributed_companies.name"}),
        expanded_results.details.remediations = Table.ExpandListColumn(expanded_attributed_companies1, "details.remediations"),
        expanded_results.details.remediations1 = Table.ExpandRecordColumn(expanded_results.details.remediations, "details.remediations", {"remediation_tip"}, {"details.remediations.remediation_tip"}),
        expanded_infection = Table.ExpandRecordColumn(expanded_results.details.remediations1, "details.infection", {"family"}, {"infection.family"}),
        expanded_assets = Table.ExpandListColumn(expanded_infection, "assets"),
        expanded_assets1 = Table.ExpandRecordColumn(expanded_assets, "assets", {"asset", "category", "importance"}, {"asset", "category", "importance"}),
        expanded_vulnerabilities = Table.ExpandListColumn(expanded_assets1, "details.vulnerabilities"),
        expanded_vulnerabilities1 = Table.ExpandRecordColumn(expanded_vulnerabilities, "details.vulnerabilities", {"name", "severity"}, {"vulnerabilities.name", "vulnerabilities.severity"}),
        expand_diligence_annotations = Table.ExpandRecordColumn(expanded_vulnerabilities1, "details.diligence_annotations", {"certchain", "message", "modal_tags"}, {"certchain", "message", "modal_tags"}),
        expanded_remediation_assignments = Table.ExpandListColumn(expand_diligence_annotations, "remediation_assignments"),
        extracted_values = Table.TransformColumns(expanded_remediation_assignments, {"remediation_assignments", each 
            if _ <> null then Text.Combine(List.Transform(_, Text.From), ",") else null, type text}),
        extracted_values2 = Table.TransformColumns(extracted_values, {"tags", each
            if _ <> null then Text.Combine(List.Transform(_, Text.From), ",") else null, type text}),
        extracted_values3 = Table.TransformColumns(extracted_values2, {"details.port_list", each
            if _ <> null then Text.Combine(List.Transform(_, Text.From), ",") else null, type text}),
        extracted_values4 = Table.TransformColumns(extracted_values3, {"details.observed_ips", each
            if _ <> null then Text.Combine(List.Transform(_, Text.From), ",") else null, type text}),
        change_errors = Table.ReplaceErrorValues(Table.ReplaceErrorValues(Table.ReplaceErrorValues(extracted_values4,{{"certchain", null}}),{{"message", null}}),{{"modal_tags", null}}),
        certchain_expanded = Table.ExpandListColumn(change_errors, "certchain"),
        certchain_expanded2 = Table.ExpandRecordColumn(certchain_expanded, "certchain", {"dnsName", "endDate", "issuerName", "serialNumber", "startDate", "subjectName"}, {"dnsName", "endDate", "issuerName", "serialNumber", "startDate", "subjectName"}),
        dnsName_expanded = Table.TransformColumns(certchain_expanded2, {"dnsName", each 
            if _ <> null then Text.Combine(List.Transform(_, Text.From), ",") else null, type text}),
        #"Changed Type" = Table.TransformColumnTypes(dnsName_expanded,{{"affects_rating", type logical}, {"importance", type number}, {"first_seen", type date}, {"last_seen", type date}, {"severity", type number}, {"last_requested_refresh_date", type date}, {"last_refresh_status_date", type date}, {"last_remediation_status_date", type date}}),
        //End: Code block not yet with dynamic schema treatment 
        output = #"Changed Type"
    in
        output meta [NextLink = nextLink];


        
        
// Risk Vector History - Obtain Data Page
GetPageRVHistory = (url as text, company_guid as text, optional schema as table) =>
    let
        source = Web.Contents(url & company_guid, [ Headers = DefaultRequestHeaders]),
        json = Json.Document(source),
        nextLink = json[links][next],
        results = json[results],
        grades = results{0}[grades],
        table = Table.FromList(grades, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        fields = Record.FieldNames(Table.FirstValue(table, [Empty = null])),
        expanded = Table.ExpandRecordColumn(table, "Column1", fields),
        withSchema = if (schema <> null) then SchemaTransformTable(expanded, schema) else expanded,
        //Start: Code block not yet with dynamic schema treatment
        #"Expanded risk_vectors" = Table.ExpandListColumn(withSchema, "risk_vectors"),
        #"Expanded risk_vectors1" = Table.ExpandRecordColumn(#"Expanded risk_vectors", "risk_vectors", {"risk_vector", "grade", "percentile"}, {"risk_vector", "grade", "percentile"}),
        #"Expanded risk_vector" = Table.ExpandRecordColumn(#"Expanded risk_vectors1", "risk_vector", {"name", "slug"}, {"name", "slug"}),
        #"Changed Type" = Table.TransformColumnTypes(#"Expanded risk_vector",{{"percentile", type number}}),
        //End: Code block not yet with dynamic schema treatment
        output = #"Changed Type"
    in
        output meta [NextLink = nextLink];

        // Portfolio - Obtain Data Page
GetPagePortfolio = (url as text, optional schema as table) =>
    let
        source = Web.Contents(url, [ Headers = DefaultRequestHeaders]),
        json = Json.Document(source),
        nextLink = json[links][next],
        results = json[results],
        table = Table.FromList(results, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        fields = Record.FieldNames(Table.FirstValue(table, [Empty = null])),
        expanded = Table.ExpandRecordColumn(table, "Column1", fields),
        withSchema = if (schema <> null) then SchemaTransformTable(expanded, schema) else expanded,
          //Start: Code block not yet with dynamic schema treatment
         #"results.industry Expandida" = Table.ExpandRecordColumn(withSchema, "industry", {"name", "slug"}, {"industry.name", "industry.slug"}),
         #"results.sub_industry Expandida" = Table.ExpandRecordColumn(#"results.industry Expandida", "sub_industry", {"name", "slug"}, {"sub_industry.name", "sub_industry.slug"}),
         #"results.subscription_type Expandida" = Table.ExpandRecordColumn(#"results.sub_industry Expandida", "subscription_type", {"name"}, {"subscription_type.name"}),
         #"results.relationship Expandida" = Table.ExpandRecordColumn( #"results.subscription_type Expandida", "relationship", {"name"}, {"relationship.name"}),
         #"Expanded life_cycle" = Table.ExpandRecordColumn(#"results.relationship Expandida", "life_cycle", {"name"}, {"life_cycle.name"}),
         #"Removed Columns" = Table.RemoveColumns (#"Expanded life_cycle",{"type"}),
         #"Renamed Columns1" = Table.RenameColumns(#"Removed Columns",{{"guid", "Company Guid"}, {"industry.name", "Industry"}, {"industry.slug", "Industry Slug"}, {"sub_industry.name", "Sub Industry"}, {"sub_industry.slug", "Sub Industry Slug"}, {"subscription_type.name", "Subscription Type"}}),
         //End: Code block not yet with dynamic schema treatment
         output =  #"Renamed Columns1"
        
    in
        output meta [NextLink = nextLink];

// RVHISTORY

GetPageRVHistoryPort = (url as text, optional schema as table) =>
    let
        source = Web.Contents(url, [ Headers = DefaultRequestHeaders]),
        json = Json.Document(source),
        nextLink = json[links][next],
        results = json[results],
        table = Table.FromList(results, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        fields = Record.FieldNames(Table.FirstValue(table, [Empty = null])),
        expanded = Table.ExpandRecordColumn(table, "Column1", fields),
        withSchema = if (schema <> null) then SchemaTransformTable(expanded, schema) else expanded,
        
        //Start: Code block not yet with dynamic schema treatment
        #"results.company Expandida" = Table.ExpandRecordColumn( withSchema, "company", {"guid", "name"}, {"company.guid", "company.name"}),
       #"results.grades Expandida" = Table.ExpandListColumn(#"results.company Expandida", "grades"),
       #"results.grades Expandida1" = Table.ExpandRecordColumn(#"results.grades Expandida", "grades", {"date", "risk_vectors"}, {"grades.date", "grades.risk_vectors"}),
       #"Tipo Alterado" = Table.TransformColumnTypes(#"results.grades Expandida1",{{"company.guid", type text}, {"company.name", type text}, {"grades.date", type date}, {"grades.risk_vectors", type any}}),
       #"results.grades.risk_vectors Expandida" = Table.ExpandListColumn(#"Tipo Alterado", "grades.risk_vectors"),
       #"results.grades.risk_vectors Expandida1" = Table.ExpandRecordColumn(#"results.grades.risk_vectors Expandida", "grades.risk_vectors", {"risk_vector", "grade", "percentile"}, {"grades.risk_vectors.risk_vector", "grades.risk_vectors.grade", "grades.risk_vectors.percentile"}),
       #"results.grades.risk_vectors.risk_vector Expandida" = Table.ExpandRecordColumn(#"results.grades.risk_vectors Expandida1", "grades.risk_vectors.risk_vector", {"name", "risk_category"}, {"grades.risk_vectors.risk_vector.name", "grades.risk_vectors.risk_vector.risk_category"}), 
       #"Renamed Columns1" = Table.RenameColumns(#"results.grades.risk_vectors.risk_vector Expandida",{{"company.guid", "Company Guid"}, {"company.name", "Company Name"}, {"grades.date", "Risk Vector Grade Date"}, {"grades.risk_vectors.risk_vector.name", "Risk Vector Name"}, {"grades.risk_vectors.risk_vector.risk_category", "Risk Vector Category"}, {"grades.risk_vectors.grade", "Risk Vector Grade"}}),
       #"Removed Columns" = Table.RemoveColumns (#"Renamed Columns1",{"grades.risk_vectors.percentile"}),
       //End: Code block not yet with dynamic schema treatment
        output = #"Removed Columns"
    in
        output meta [NextLink = nextLink];

//RVLATEST

GetPageRVLatestPort = (url as text,  optional schema as table) =>
    let 
        source = Web.Contents(url, [ Headers = DefaultRequestHeaders]),
        json = Json.Document(source),
        nextLink = json[links][next],
        results = json[results],
        table = Table.FromList(results, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        fields = Record.FieldNames(Table.FirstValue(table, [Empty = null])),
        expanded = Table.ExpandRecordColumn(table, "Column1", fields),
        withSchema = if (schema <> null) then SchemaTransformTable(expanded, schema) else expanded,
       //Start: Code block not yet with dynamic schema treatment
       #"results.company Expandida" = Table.ExpandRecordColumn( withSchema, "company", {"guid", "name"}, {"company.guid", "company.name"}),
       #"results.grades Expandida" = Table.ExpandListColumn(#"results.company Expandida", "grades"),
       #"results.grades Expandida1" = Table.ExpandRecordColumn(#"results.grades Expandida", "grades", {"date", "risk_vectors"}, {"grades.date", "grades.risk_vectors"}),
       #"Tipo Alterado" = Table.TransformColumnTypes(#"results.grades Expandida1",{{"company.guid", type text}, {"company.name", type text}, {"grades.date", type date}, {"grades.risk_vectors", type any}}),
       #"results.grades.risk_vectors Expandida" = Table.ExpandListColumn(#"Tipo Alterado", "grades.risk_vectors"),
       #"results.grades.risk_vectors Expandida1" = Table.ExpandRecordColumn(#"results.grades.risk_vectors Expandida", "grades.risk_vectors", {"risk_vector", "grade", "percentile"}, {"grades.risk_vectors.risk_vector", "grades.risk_vectors.grade", "grades.risk_vectors.percentile"}),
       #"results.grades.risk_vectors.risk_vector Expandida" = Table.ExpandRecordColumn(#"results.grades.risk_vectors Expandida1", "grades.risk_vectors.risk_vector", {"name", "risk_category"}, {"grades.risk_vectors.risk_vector.name", "grades.risk_vectors.risk_vector.risk_category"}),
       #"Renamed Columns1" = Table.RenameColumns(#"results.grades.risk_vectors.risk_vector Expandida",{{"company.guid", "Company Guid"}, {"company.name", "Company Name"}, {"grades.date", "Risk Vector Grade Date"}, {"grades.risk_vectors.risk_vector.name", "Risk Vector Name"}, {"grades.risk_vectors.risk_vector.risk_category", "Risk Vector Category"}, {"grades.risk_vectors.grade", "Risk Vector Grade"}}),
       #"Removed Columns" = Table.RemoveColumns (#"Renamed Columns1",{"grades.risk_vectors.percentile"}),
       //End: Code block not yet with dynamic schema treatment
       output = #"Removed Columns"
        
    in
        output meta [NextLink = nextLink];

        //RatingCH
GetPageRatingCH = (url as text,  optional schema as table) =>
    let 
        source = Web.Contents(url, [ Headers = DefaultRequestHeaders]),
        json = Json.Document(source),
        nextLink = json[links][next],
        results = json[results],
        table = Table.FromList(results, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        fields = Record.FieldNames(Table.FirstValue(table, [Empty = null])),
        expanded = Table.ExpandRecordColumn(table, "Column1", fields),
        withSchema = if (schema <> null) then SchemaTransformTable(expanded, schema) else expanded,
       //Start: Code block not yet with dynamic schema treatment
       #"Expanded results.reasons" = Table.ExpandListColumn(withSchema, "reasons"),
       #"Expanded results.reasons1" = Table.ExpandRecordColumn(#"Expanded results.reasons", "reasons", {"start_percentile", "risk_vector", "end_percentile"}, {"reasons.start_percentile", "reasons.risk_vector", "reasons.end_percentile"}),
       #"Removed Columns" = Table.RemoveColumns(#"Expanded results.reasons1",{"reasons.start_percentile", "reasons.end_percentile"}),
       #"Renamed Columns" = Table.RenameColumns(#"Removed Columns",{{"start_score", "start_rating"}, {"end_score", "end_rating"}}),
       #"Renamed Columns1" = Table.RenameColumns(#"Renamed Columns",{{"company", "Company Guid"}, {"reasons.risk_vector", "Reason Risk Vector"}}),
       //End: Code block not yet with dynamic schema treatment
       output = #"Renamed Columns1"
        
    in
        output meta [NextLink = nextLink];
 
//Infrastruture
GetPageInfrastructure = (url as text, company_guid as text, optional schema as table) as table =>
    let
        source = Web.Contents(Text.Replace(url, "company_guid", company_guid), [ Headers = DefaultRequestHeaders]),
        json = Json.Document(source),
        nextLink = json[links][next],
        results = json[results],
        table = Table.FromList(results, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        fields = Record.FieldNames(Table.FirstValue(table, [Empty = null])),
        expanded = Table.ExpandRecordColumn(table, "Column1", fields),
        withSchema = if (schema <> null) then SchemaTransformTable(expanded, schema) else expanded,
        expanded_column1 = Table.ExpandRecordColumn(table, "Column1", {"value", "source", "country", "start_date", "end_date", "is_active", "attributed_to", "ip_count", "is_suppressed", "tags", "asn"}, {"results.value", "results.source", "results.country", "results.start_date", "results.end_date", "results.is_active", "results.attributed_to", "results.ip_count", "results.is_suppressed", "results.tags", "results.asn"}),
        expanded_source = Table.ExpandRecordColumn(expanded_column1, "results.source", {"slug", "name"}, {"results.source.slug", "results.source.name"}),
        expanded_country = Table.ExpandRecordColumn(expanded_source, "results.country", {"code", "name"}, {"results.country.code", "results.country.name"}),
        expanded_attributed_to = Table.ExpandRecordColumn(expanded_country, "results.attributed_to", {"guid", "name"}, {"results.attributed_to.guid", "results.attributed_to.name"}),
        expanded_tags = Table.ExpandListColumn(expanded_attributed_to, "results.tags"),
        expanded_tags_1 = Table.ExpandRecordColumn(expanded_tags, "results.tags", {"guid", "name", "is_public"}, {"results.tags.guid", "results.tags.name", "results.tags.is_public"}),
        changed_columns = Table.RenameColumns(expanded_tags_1,{{"results.value", "Value"}, {"results.source.slug", "Source.slug"}, {"results.source.name", "Source.name"}, {"results.country.code", "Country.code"}, {"results.country.name", "Country.name"}, {"results.start_date", "Start Date"}, {"results.end_date", "End Date"}, {"results.is_active", "Is Active"}, {"results.attributed_to.guid", "Attributed_to.guid"}, {"results.attributed_to.name", "Attributed_to.name"}, {"results.ip_count", "CIDR Size"}, {"results.is_suppressed", "Is Suppressed"}, {"results.tags.guid", "Tags.guid"}, {"results.tags.name", "Tags.name"}, {"results.tags.is_public", "Tags.is_public"}, {"results.asn", "AS Number"}}),
        //End: Code block not yet with dynamic schema treatment 
        output = changed_columns 
    in
        output meta [NextLink = nextLink];



//Assets
GetPageAssets = (url as text, company_guid as text, optional schema as table) as table =>
    let
        source = Web.Contents(Text.Replace(url, "company_guid", company_guid), [ Headers = DefaultRequestHeaders]),
        json = Json.Document(source),
        nextLink = json[links][next],
        results = json[results],
        table = Table.FromList(results, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        fields = Record.FieldNames(Table.FirstValue(table, [Empty = null])),
        expanded = Table.ExpandRecordColumn(table, "Column1", fields),
        withSchema = if (schema <> null) then SchemaTransformTable(expanded, schema) else expanded,
        expanded_column1 = Table.ExpandRecordColumn(table, "Column1", {"asset", "asset_type", "app_grade", "country", "services", "products", "hosted_by", "origin_subsidiary", "findings", "tag_details", "combined_overrides"}, {"results.asset", "results.asset_type", "results.app_grade", "results.country", "results.services", "results.products", "results.hosted_by", "results.origin_subsidiary", "results.findings", "results.tag_details", "results.combined_overrides"}),
        expanded_findings = Table.ExpandRecordColumn(expanded_column1, "results.findings", {"total_count", "counts_by_severity"}, {"results.findings.total_count", "results.findings.counts_by_severity"}),
        expanded_tag_details = Table.ExpandListColumn(expanded_findings, "results.tag_details"),
        expanded_tag_details1 = Table.ExpandRecordColumn(expanded_tag_details, "results.tag_details", {"guid", "name", "is_inherited", "is_public"}, {"results.tag_details.guid", "results.tag_details.name", "results.tag_details.is_inherited", "results.tag_details.is_public"}),
        expanded_combined_overrides =Table.ExpandRecordColumn(expanded_tag_details1, "results.combined_overrides", {"importance"}, {"results.combined_overrides.importance"}),
        expanded_products = Table.ExpandListColumn(expanded_combined_overrides, "results.products"),
        expanded_products1 = Table.ExpandRecordColumn(expanded_products, "results.products", {"type", "vendor", "product", "version", "support"}, {"results.products.type", "results.products.vendor", "results.products.product", "results.products.version", "results.products.support"}),
        expanded_services = Table.ExpandListColumn(expanded_products1, "results.services"),
        expanded_hosted_by = Table.ExpandRecordColumn(expanded_services, "results.hosted_by", {"guid", "name"}, {"results.hosted_by.guid", "results.hosted_by.name"}),
        expanded_origin_subsidiary = Table.ExpandRecordColumn(expanded_hosted_by, "results.origin_subsidiary", {"guid", "name"}, {"results.origin_subsidiary.guid", "results.origin_subsidiary.name"}),
        expanded_findings_counts_by_severity = Table.ExpandRecordColumn(expanded_origin_subsidiary, "results.findings.counts_by_severity", {"severe", "material", "moderate", "minor"}, {"results.findings.counts_by_severity.severe", "results.findings.counts_by_severity.material", "results.findings.counts_by_severity.moderate", "results.findings.counts_by_severity.minor"}),
        changed_columns = Table.RenameColumns(expanded_findings_counts_by_severity,{{"results.asset", "Asset"}, {"results.asset_type", "Asset_type"}, {"results.tag_details.guid", "Tags.guid"}, {"results.tag_details.name", "Tags.name"}, {"results.tag_details.is_inherited", "Tags.is_inherited"}, {"results.tag_details.is_public", "Tags.is_public"}, {"results.combined_overrides.importance", "Importance"}, {"results.app_grade", "App Grade"}, {"results.country", "Country"}, {"results.services", "Services"}, {"results.products.type", "Identified Products.type"}, {"results.products.vendor", "Identified Products.vendor"}, {"results.products.product", "Identified Products.product"}, {"results.products.version", "Identified Products.version"}, {"results.products.support", "Identified Products.support"}, {"results.hosted_by.name", "Hosting Provider.name"}, {"results.hosted_by.guid", "Hosting Provider.guid"}, {"results.findings.counts_by_severity.severe", "Severe Findings (Impacts RV Grade)"}, {"results.findings.counts_by_severity.material", "Material Findings (Impacts RV Grade)"}, {"results.findings.counts_by_severity.moderate", "Moderate Findings (Impacts RV Grade)"}, {"results.findings.counts_by_severity.minor", "Minor Findings (Impacts RV Grade)"}, {"results.findings.total_count", "Findings (Impacts RV Grade)"}, {"results.origin_subsidiary.guid", "Originating Subsidiary.guid"}, {"results.origin_subsidiary.name", "Originating Subsidiary.name"}}),
    
        //End: Code block not yet with dynamic schema treatment 
        output = changed_columns
    in
        output meta [NextLink = nextLink];


// Alerts- Obtain Data Page
GetPageAlerts = (url as text, optional schema as table) =>
    let
        source = Web.Contents(url, [ Headers = DefaultRequestHeaders]),
        json = Json.Document(source),
        nextLink = json[links][next],
        results = json[results],
        table = Table.FromList(results, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        fields = Record.FieldNames(Table.FirstValue(table, [Empty = null])),
        expanded = Table.ExpandRecordColumn(table, "Column1", fields),
        withSchema = if (schema <> null) then SchemaTransformTable(expanded, schema) else expanded,
        output = withSchema
    in
        output meta [NextLink = nextLink];

// My Infrastructure - Obtain Data 
BitSightSecurityRatingsMyInfrastructure.Feed = (url as text, flag as text, company_guid as text, optional schema as table) =>
    let
        source = Web.Contents(Text.Replace(url, "company_guid", company_guid), [ Headers = 
        [
            Authorization = "Basic " & apiKey,
            Accept = "*/*",
            #"Content-Type" = "text/csv"
        ] 
        ]),
        body = Csv.Document(source,[Delimiter=",", Columns=13, Encoding=1252, QuoteStyle=QuoteStyle.Csv]),
        promoted_headers = Table.PromoteHeaders(body, [PromoteAllScalars=true]),
        withSchema = if (schema <> null) then SchemaTransformTable(promoted_headers, schema) else promoted_headers,
        removed_bottom_rows = Table.RemoveLastN(withSchema,2),
        removed_top_rows = Table.Skip(removed_bottom_rows,3)
    in
        if flag = "i" then removed_top_rows else removed_bottom_rows;

// Obtain the company's GUID of the user logged in
GetMyCompanyGUID = () as text =>
    let
        source = Json.Document(Web.Contents(guidUrl, [ Headers = DefaultRequestHeaders ])),
        guid = source[customer][my_company_guid],
        output = if (guid = null) then "none" else guid 
    in
        output;


// Obtain the company's Name of the user logged in
GetMyCompanyName = () as text =>
    let
        source = Json.Document(Web.Contents(guidUrl, [ Headers = FirstRequestHeaders ])),
        name = source[customer][name],
        output = name
    in
        output;

// Obtain the main company's subsidiaries
GetMyCompanyAllGUIDs = () as table =>
    let
        source = Json.Document(Web.Contents(guidUrl, [ Headers = DefaultRequestHeaders ])),
        subsidiariesGUIDs = source[customer][my_company_subsidiaries],
        subsidiariesGUIDsTable = Table.FromList(subsidiariesGUIDs, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        renamedSubsidiariesGUIDsColumns = Table.RenameColumns(subsidiariesGUIDsTable,{{"Column1", "guid"}}),
        mainCompanyGUID = source[customer][my_company_guid],
        mainCompanyGUIDTable = #table(1, {{mainCompanyGUID}}),
        renamedMainCompanyGUIDColumns = Table.RenameColumns(mainCompanyGUIDTable,{{"Column1", "guid"}}),
        combineTables = Table.Combine({renamedMainCompanyGUIDColumns, renamedSubsidiariesGUIDsColumns}),
        output = combineTables
    in
        output;


//
// Common Functions
//

// Common - Obtain Next Link - Pagination
GetNextLink = (response) as nullable text => 
    let
        next_url = response[links][next]
    in
        next_url;

// The getNextPage function takes a single argument and is expected to return a nullable table
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

// Navigation Bar
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
//
// Schema functions
//

EnforceSchema.Strict = 1;               // Add any missing columns, remove extra columns, set table type
EnforceSchema.IgnoreExtraColumns = 2;   // Add missing columns, do not remove extra columns
EnforceSchema.IgnoreMissingColumns = 3; // Do not add or remove columns

SchemaTransformTable = (table as table, schema as table, optional enforceSchema as number) as table =>
    let
        // Default to EnforceSchema.Strict
        _enforceSchema = if (enforceSchema <> null) then enforceSchema else EnforceSchema.Strict,

        // Applies type transforms to a given table
        EnforceTypes = (table as table, schema as table) as table =>
            let
                map = (t) => if Type.Is(t, type list) or Type.Is(t, type record) or t = type any then null else t,
                mapped = Table.TransformColumns(schema, {"Type", map}),
                omitted = Table.SelectRows(mapped, each [Type] <> null),
                existingColumns = Table.ColumnNames(table),
                removeMissing = Table.SelectRows(omitted, each List.Contains(existingColumns, [Name])),
                primitiveTransforms = Table.ToRows(removeMissing),
                changedPrimitives = Table.TransformColumnTypes(table, primitiveTransforms)
            in
                changedPrimitives,

        // Returns the table type for a given schema
        SchemaToTableType = (schema as table) as type =>
            let
                toList = List.Transform(schema[Type], (t) => [Type=t, Optional=false]),
                toRecord = Record.FromList(toList, schema[Name]),
                toType = Type.ForRecord(toRecord, false)
            in
                type table (toType),

        // Determine if we have extra/missing columns.
        // The enforceSchema parameter determines what we do about them.
        schemaNames = schema[Name],
        foundNames = Table.ColumnNames(table),
        addNames = List.RemoveItems(schemaNames, foundNames),
        extraNames = List.RemoveItems(foundNames, schemaNames),
        tmp = Text.NewGuid(),
        added = Table.AddColumn(table, tmp, each []),
        expanded = Table.ExpandRecordColumn(added, tmp, addNames),
        result = if List.IsEmpty(addNames) then table else expanded,
        fullList =
            if (_enforceSchema = EnforceSchema.Strict) then
                schemaNames
            else if (_enforceSchema = EnforceSchema.IgnoreMissingColumns) then
                foundNames
            else
                schemaNames & extraNames,

        // Select the final list of columns.
        // These will be ordered according to the schema table.
        reordered = Table.SelectColumns(result, fullList, MissingField.Ignore),
        enforcedTypes = EnforceTypes(reordered, schema),
        withType = if (_enforceSchema = EnforceSchema.Strict) then Value.ReplaceType(enforcedTypes, SchemaToTableType(schema)) else enforcedTypes
    in
        withType;

//
// External Resources
//

BitSightSecurityRatings.Icons = [
    Icon16 = { Extension.Contents("BitSightSecurityRatings16.png"), Extension.Contents("BitSightSecurityRatings20.png"), Extension.Contents("BitSightSecurityRatings24.png"), Extension.Contents("BitSightSecurityRatings32.png") },
    Icon32 = { Extension.Contents("BitSightSecurityRatings32.png"), Extension.Contents("BitSightSecurityRatings40.png"), Extension.Contents("BitSightSecurityRatings48.png"), Extension.Contents("BitSightSecurityRatings64.png") }
];



//expanded_source = Table.ExpandRecordColumn(expanded_column1, "source", {"slug", "name"}, {"results.source.slug", "results.source.name"}),
//        expanded_tags = Table.ExpandListColumn(expanded_source, "results.tags"),
 //       expanded_tags_1 = Table.ExpandRecordColumn(expanded_tags, "results.tags", {"guid", "id", "name", "is_public"}, {"results.tags.guid", "results.tags.id", "results.tags.name", "results.tags.is_public"}),
   //     expanded_attributed_to = Table.ExpandRecordColumn(expanded_tags_1, "results.attributed_to", {"guid", "name"}, {"results.attributed_to.guid", "results.attributed_to.name"}),
     //   changed_type = Table.TransformColumnTypes(expanded_attributed_to, {{"results.value", type text},  {"results.source", type any}, {"results.country", type any}, {"results.start_date", type date}, {"results.end_date", type date}, {"results.is_active", type logical}, {"results.attributed_to.guid", type text}, {"results.attributed_to.name", type text}, {"results.ip_count", Int64.Type}, {"results.is_suppressed", type logical}, {"results.tags", type any}, {"results.asn", type any}}),
    
   