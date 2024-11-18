// This file contains LEAP Connector logic
[Version = "1.3.0"]
section LEAP;

// **** Variables ****
token_uri = "https://auth.leap.services/oauth/token";
authorize_uri = "https://auth.leap.services/oauth/authorize";
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
scoped = "* offline_access";
logout_uri ="https://auth.leap.services/oauth/logout";
windowWidth = 1200;
windowHeight = 1000;

// ** Client Id ** //
client_id = "PCAJS3WMUUKEJBEZ";

// ** X-API-KEY ** //
au_api_key = "M02uJyCjGVH5E2XQdqVSaGKWzljehAD77rm1HPU8";
au_liveb_api_key = "M02uJyCjGVH5E2XQdqVSaGKWzljehAD77rm1HPU8";
uk_api_key = "c1gVAOo8a44RJ2lV0KGepag2M7mclnxu9pc8xkjo";
us_api_key = "GFO1dj4cw55IO9oRAHac26dzK5Rj1e8nFCyLfon5";
ca_api_key = "ItjSNwx5mg6f4YvTCEDm48tGumRcMzhg4UgbqBS5";
nz_api_key = "J7N5Kb4RBpaLUetQQ5moB9te7x7i0m4Z5hx8ROoQ";

// ** REPORT PARSER URLS ** //
au_report_parser_url = "https://reportparserservice.au.leapapp.io";
uk_report_parser_url = "https://reportparserservice.uk.leapapp.io";
us_report_parser_url = "https://reportparserservice.us.leapapp.io";
ca_report_parser_url = "https://reportparserservice.ca.leapapp.io";
nz_report_parser_url = "https://reportparserservice.au.leapapp.io";

// ** OPTIONS URLS ** //
au_options_url = "https://acc-options-api.leapaws.com.au";
au_liveb_options_url = "https://acc-options-api-liveb.leapaws.com.au";
uk_options_url = "https://acc-options-api.leapaws.co.uk";
us_options_url = "https://acc-options-api.leapaws.com";
ca_options_url = "https://acc-options-api.leapaws.ca";
nz_options_url = "https://acc-options-api.leapaws.com.au";

[DataSource.Kind="LEAP", Publish="LEAP.Publish"]
shared LEAP.Contents = Value.ReplaceType(LEAPNavTable, LEAPMetadataType);

// Metadata for LEAP.Contents data source function
LEAPMetadataType = type function ()
            as table meta [
                Documentation.Name = "LEAP.Contents",
                Documentation.Description = Extension.LoadString("LEAPContentDescription"),
                Documentation.Examples = 
                {
                    [
                        Description = Extension.LoadString("LEAPContentDescription"),
                        Code = "LEAP.Contents",
                        Result = Extension.LoadString("LEAPContentSampleTable")
                    ]
                }
            ];

[DataSource.Kind="LEAP"]
LEAP.Feed = (optional path as text, optional period as text,  optional start as date, optional end as date, optional accountId as text) =>
    let
        result = if path = "AgeingBalances" or path = "Balances" or path = "ArchivedBalances" or path = "InvoicedStaff" or path = "OfficeInvoices" or path = "AgedWIP" or path = "AgedDisbursements" or path = "AgedDebtors" or path = "StaffInvoicedFunds" or path = "StaffReceiptedFunds" 
        or path = "OfficeReceipts" or path = "StaffBudgets" or path = "TimeAndFees" or path = "CriticalDates" or path = "WeeklyTime" or path = "DisbursementListing" or path = "InvoiceAdjustments" or path = "TrustAudit" or path = "ControlledMoneyAccountList" 
        or path = "WIPByMatterFee"  or path = "WIPByMatter" or path = "FirmReportingGroups" or path = "FirmCustomFields" or path = "MattersDueSettlement"  or path = "MattersOpened" or path = "TrustBankRegister" or path = "TrustBankRegister" or path = "WeeklyTime"
        or path = "WeeklyHour" or path = "ControlledMoneyControl"  or path = "InactiveMatters" or path = "FeeContributionsRecovery"  then CallLEAPBalance(path, period, start, end, accountId) 
        else if path = "Matters" or path = "Cards" then CallRowVersion(path)
        else CallLEAP(path)
    in
        result;

// Data Source Kind description
LEAP = [
    TestConnection = (dataSourcePath) => {"LEAP.Contents"},
    Authentication = [
        OAuth = [
        StartLogin = StartLogin,
        FinishLogin = FinishLogin,
        Refresh = Refresh,
        Logout = Logout
        ]
    ]
];

// Data Source UI publishing description
LEAP.Publish = [
    Beta = true,
    Category = "Online Services",
    ButtonText = { "LEAP", "LEAP" },
    LearnMoreUrl = "https://www.leaplegalsoftware.com",
    SourceImage = LEAP.Icons,
    SourceTypeImage = LEAP.Icons
];

// Converts Custom Date Range functionality into function type for better rendering in Navigator
CustomDateRange.Contents = Value.ReplaceType(CustomDateRangeImpl, CustomDateRangeType);

// Route to Report Parser endpoint to assist in processing presignedurls.
CallPreSign = (url) =>
    let
        parts = Json.Document(Base64Url.Decode(Text.Split(Extension.CurrentCredential()[access_token], "."){1})),
        countryCode = parts[countryCode],
        baseUrl = Text.Combine({GetRegionReportParserBaseUrl(countryCode), "/report"}),
        result = Web.Contents(baseUrl, [
        Headers = [ #"Content-type" = "application/json"],
        Content = Json.FromValue([PreSignedURL = url]),
        ManualStatusHandling ={400}]),
        body = Json.Document(result)
    in
        body;

// Return x_api_key by token countryCode. CountryCode reference: [0 = au, 1 = uk, 2 = us, 3 = ca, 4 = ie, 5 = nz]
GetRegionKey = (countryCode, environment) =>
  let
    key = if countryCode = 2 then us_api_key
             else if countryCode = 0 then au_api_key
             else if countryCode = 0 and environment = "liveb" then au_liveb_api_key
             else if countryCode = 3 then ca_api_key
             else if countryCode = 5 then nz_api_key
             else if countryCode = 1 or countryCode = 4 then uk_api_key
             else ""
  in
    key;

// Return ReportParserService baseUrl by token countryCode
GetRegionReportParserBaseUrl = (countryCode) =>
  let
    key = if countryCode = 2 then us_report_parser_url
             else if countryCode = 0 then au_report_parser_url
             else if countryCode = 3 then ca_report_parser_url
             else if countryCode = 5 then nz_report_parser_url
             else if countryCode = 1 or countryCode = 4 then uk_report_parser_url
             else ""
  in
    key;

// Check adminstrator access and other permissions
CheckUserAccess = () =>
    let
        result = LEAP.Feed("UserType"),
        userType = result[UserType],
        flag = if userType <> null and userType = 1 then true else false
    in
        flag;

// Check user access according to firm options and Power BI enabled property. Refer to userType value until /api/staff-features/powerbi is live.
CheckPowerBiAccess = (userId) =>
    let
        result = LEAP.Feed("PowerBIOptions"),
        optionsEnabled = List.IsEmpty(result),
        powerBIEnabled = List.Count(List.Select(result, each [UserId] = userId and [PowerBIEnabled] = true)) > 0,
        access = if optionsEnabled then CheckUserAccess() else powerBIEnabled
    in
        access;

// Set LEAP icons
LEAP.Icons = [
    Icon16 = { Extension.Contents("LEAP16.png"), Extension.Contents("LEAP20.png"), Extension.Contents("LEAP24.png"), Extension.Contents("LEAP32.png") },
    Icon32 = { Extension.Contents("LEAP32.png"), Extension.Contents("LEAP40.png"), Extension.Contents("LEAP48.png"), Extension.Contents("LEAP64.png") }
];

//
// OAuth2 flow definition (with PKCE)
//

StartLogin = (resourceUrl, state, display) =>
    let
        // Generate Code Verifier from GUIDS
        plainTextCodeVerifier = Text.NewGuid() & Text.NewGuid(),
        codeVerifier = S256.Encode(plainTextCodeVerifier),
        AuthorizeUrl = "https://auth.leap.services/oauth/authorize?" & Uri.BuildQueryString(
            [
                client_id = client_id,
                scope = scoped,
                state = state,
                response_type = "code",
                code_challenge_method = "s256",
                code_challenge = codeVerifier,
                redirect_uri = redirect_uri
            ]
        )
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = codeVerifier
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query]
    in
        TokenMethod(Parts[code], "authorization_code", context);

TokenMethod = (code, grantType, verifier, optional access_token) =>
    let        
        codeVerifier =  [code_verifier = verifier],
        codeParameter = if (grantType = "authorization_code") then [code = code] else [refresh_token = code],
        url = if (grantType = "authorization_code") then "" else Text.Combine({GetRegionReportParserBaseUrl(GetRegionFromToken(access_token)), "/token"}),
        query = codeVerifier & 
            codeParameter
            & [
                client_id = client_id,
                grant_type = grantType,
                redirect_uri = redirect_uri
            ],
        ManualHandlingStatusCodes = {400, 401, 403},
        Response = Web.Contents(token_uri, [
            Content = Text.ToBinary(Uri.BuildQueryString(query)),
            Headers=[#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json"],
            ManualStatusHandling = ManualHandlingStatusCodes
            ]),
        Parts = Json.Document(Response),
        Final = Record.AddField(Parts, "code_verifier", verifier)
    in
        Final;

Refresh = (resourceUrl, refresh_token, oldCredential) => 
    let
        result = TokenMethod(oldCredential[refresh_token], "refresh_token", oldCredential[code_verifier], oldCredential[access_token])
    in
        result;

Logout = (token) => logout_uri;

// LEAP Navigation Table
LEAPNavTable = () as table =>
    let
        parts = Json.Document(Base64Url.Decode(Text.Split(Extension.CurrentCredential()[access_token], "."){1})),
        // Capture claims
        countryCode = parts[countryCode],
        userId = parts[userId],
        // Check access according to settings
        access = CheckPowerBiAccess(userId),
        // Check region and set localizations
        trustAlias = GetLocalTrustName(countryCode),
        controlledMoneyAlias = GetLocalControlledMoneyName(countryCode),
        trustSectionAlias = if countryCode = 1 or countryCode = 4 then Text.Combine({trustAlias, " Funds"}) else trustAlias, 
        officeSectionAlias = GetOfficeAlias(countryCode),
        source = #table({"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, {
            { "Matters & Clients", "MC" , CreateMatterClientsFolder(), "Folder", "Table", false },
            { "Firm","F" ,CreateFirmDetailsFolder(), "Folder", "Table", false },
            { "Additional Dimensions","AD" ,CreateDimensionFolder(), "Folder", "Table", false },
            { officeSectionAlias, "OF", CreateOfficeFolder(), "Folder", "Table", false},
            { "Management", "MGMT", CreateManagementFolder(), "Folder", "Table", false},
            { trustSectionAlias, "TR", CreateTrustFolder(trustAlias, controlledMoneyAlias), "Folder", "Table", false},
            { "Custom Function", "Q" , CreateCustomDateRangeTable(), "Folder", "Folder", false }
        }),
        invalid = #table({"Name", "Key" , "Data", "ItemKind", "ItemName", "IsLeaf"}, {
            { "You are unauthorized to use this connector.", "Invalid", {}, "Record", "Record", false }
        }),
        table = if access then source else invalid,
        navTable = Table.ToNavigationTable(table, {"Key"}, "Name" ,"Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

// Create Top Level Folder: Office
CreateOfficeFolder = () as table => 
    let
        parts = Json.Document(Base64Url.Decode(Text.Split(Extension.CurrentCredential()[access_token], "."){1})),
        countryCode = parts[countryCode],
        settlementAlias= GetLocalSettlementName(countryCode),
        debtorAlias = GetLocalDebtorsName(countryCode),
        disbursementsAlias = GetLocalDisbursementName(countryCode),
        wipAlias = "",
        objects = #table(
            {"Name",  "Key",   "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
                { Text.Combine({debtorAlias, " (v1)"}), "AD", GetDebtors(), "Table", "Table", true },
                { "Aged WIP (v1)", "AW", GetWIP(), "Table", "Table", true },
                { Text.Combine({"Aged ", disbursementsAlias, " (v1)"}), "ADi", GetDisbursements(), "Table", "Table", true },
                { "Matter Balances", "BM", CreateBalancesTable(), "Table", "Table", false },
                { "Invoices (v1)", "I", CreateNavTable("OfficeInvoices"), "Table", "Table", false },
                { "Receipts (v1)", "R", CreateNavTable("OfficeReceipts"), "Table", "Table", false },
                { "Invoice Adjustments (v1)", "IA", CreateNavTable("InvoiceAdjustments"), "Table", "Table", false },
                { Text.Combine({disbursementsAlias, " (v1)"}), "DL", CreateNavTable("DisbursementListing"), "Table", "Table", false }
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;


// Create Top Level Folder: Trust 
// trustAlias: Trust alias as per each region
// controlAccountAlias: Controlled Monies alias as per each region
CreateTrustFolder = (trustAlias, controlAccountAlias) as table => 
    let
        trustBankRegName = Text.Combine({trustAlias, " Bank Account Register"}),
        trustAuditName = Text.Combine({trustAlias, " Audit"}),
        controlAccountName = Text.Combine({controlAccountAlias, " Control Account"}),
        objects = #table(
            {"Name",  "Key",   "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
                { Text.Combine({trustAuditName, " (v1)"}), "TA", CreateCYNavTable("TrustAudit", trustAlias), "Table", "Table", false },
                { Text.Combine({trustBankRegName, " (v1)"}), "TBR", CreateTrustBankRegisterTable("TrustBankRegister", trustAlias), "Table", "Table", false },
                { Text.Combine({controlAccountName, " (v1)"}), "CMA", CreateControlledMoneyTable(), "Table", "Table", false }
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;
        
// Create Top Level Folder: Management 
CreateManagementFolder = () as table => 
    let
        parts = Json.Document(Base64Url.Decode(Text.Split(Extension.CurrentCredential()[access_token], "."){1})),
        countryCode = parts[countryCode],
        objects = #table(
            {"Name",  "Key",   "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
                { "Staff Invoiced Funds (v1)", "SIF",  CreateNavTable("StaffInvoicedFunds"), "Table", "Table", false },
                { "Staff Receipted Funds (v1)", "SIR",  CreateNavTable("StaffReceiptedFunds"), "Table", "Table", false },
                { "Staff Budgets (v1)", "SB", CreateCYNavTable("StaffBudgets"), "Table", "Table", false },
                { "Fee Contributions and Recovery (v1)","FCR", CreateNavTable("FeeContributionsRecovery"), "Table", "Table", false },
                { "Time and Fees by Staff (v1)", "WTF", CreateWeeklyTable(), "Table", "Folder", false },
                { "Time and Fees (v1)", "TFL", CreateNavTable("TimeAndFees"), "Table", "Table", false }
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

// Create Top Level Folder: Matter & Clients
CreateMatterClientsFolder = () as table => 
    let
        parts = Json.Document(Base64Url.Decode(Text.Split(Extension.CurrentCredential()[access_token], "."){1})),
        countryCode = parts[countryCode],
        settlementAlias= GetLocalSettlementName(countryCode),
        objects = #table(
            {"Name",  "Key",   "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            { "Matters (v1)", "ML" , GetMatters(), "Table", "Table", true },
            { "Matters with Staff Context (v1)", "MLS" , GetMattersEnriched(), "Table", "Table", true },
            { Text.Combine({"Matters Due for ", settlementAlias, " (v1)"}), "MD", CreateFutureNavTable("MattersDueSettlement", settlementAlias), "Table", "Table", false },
            { "Critical Dates (v1)", "CD" , CreateFutureNavTable("CriticalDates"), "Table", "Table", false },
            { "Inactive Matters (v1)", "IAM" , GetInactiveMatters(), "Table", "Table", true },
            { "Cards (v1)", "CL", GetCards(), "Table", "Table", true },
            { "Matters Opened (v1)", "MOP" , CreateMinorNavCYTable("MattersOpened"), "Table", "Table", false }

        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;
// Create Top Level Folder: Firm Details
CreateFirmDetailsFolder = () as table => 
    let
        parts = Json.Document(Base64Url.Decode(Text.Split(Extension.CurrentCredential()[access_token], "."){1})),
        countryCode = parts[countryCode],
        firm = GetFirm(),
        costRecoveryAlias = GetLocalCostRecoveryName(countryCode),
        objects = #table(
            {"Name",  "Key",   "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            { "Staff Members (v1)", "W", GetSubStaff(firm), "Table",    "Table",    true},
            { "Branch (v1)", "M", GetSubBranches(firm), "Table",    "Table",    true},
            { "Reporting Group (v1)", "FRG", GetFirmReportingGroup(), "Table",    "Table",    true},
            { Text.Combine({costRecoveryAlias," Task Codes (v1)" }), "CRTC", GetTaskCodesCostRecovery(), "Table",    "Table",    true},
            { "Time & Fees Task Codes (v1)", "FTC", GetTaskCodesFees(), "Table",    "Table",    true}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

// Create nested Controlled Monies navigation table
CreateControlledMoneyTable = () as table => 
    let
        parts = Json.Document(Base64Url.Decode(Text.Split(Extension.CurrentCredential()[access_token], "."){1})),
        countryCode = parts[countryCode],
        controlledMoneyAlias = GetLocalControlledMoneyName(countryCode),
        objects = #table(
            {"Name",  "Key",   "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            { Text.Combine({controlledMoneyAlias," Listing of Accounts"}), "M", GetControlledMoneyAccountList(), "Table",    "Table",    true},
            { Text.Combine({controlledMoneyAlias," Control Account"}), "Y", CreateNavTable("ControlledMoneyControl"), "Table",    "Table",    false}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

// Create Trust Bank Register dynamically from firm trust accounts
CreateTrustBankRegisterTable = (table as text, alias as text) as table => 
    let
        accounts = GetAccounts(),
        trustOnlyAccounts = Table.SelectRows(accounts, each ([AccountUsage] = 1) and ([Deleted] = false)),
        list = Table.ToRecords(trustOnlyAccounts),
        objects = #table(
            {"Name",  "Key",   "Data",  "ItemKind", "ItemName", "IsLeaf"}, 
            List.Transform(list, each {[AccountName], [BankAccountId], CreateCYNavTable(table, alias, [AccountName], [BankAccountId]) , "Table", "Table", false})
        ),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

// Create Matter Balances navigation table
CreateBalancesTable = () as table => 
    let
        objects = #table(
            {"Name",  "Key",   "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            { "Balances: Current Matters (v1)", "BCM", GetBalance(false), "Table", "Table", true },
            { "Balances: Archived Matters (v1)", "BAM",  GetBalance(true), "Table", "Table", true }
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

        
// Create navigation table for Custom Date Range function: 'Query LEAP with Functions'
CreateCustomDateRangeTable = () as table => 
    let
        objects = #table(
            {"Name",  "Key",   "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            {"Custom Date Range", "CDR", CustomDateRange.Contents, "Function",    "Function",    true}
        }),
        NavTable = Table.ToDelayedNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;


CreateWeeklyTable = () as table => 
    let
        objects = #table(
            {"Name",  "Key",   "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            {"Time by Staff", "T", CreateWeeklyTimeTable(), "Table",    "Table",    false},
            {"Hours by Staff", "H", CreateWeeklyHoursTable(), "Table",    "Table",    false}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;
        
CreateWeeklyTimeTable = () as table => 
    let
        weeklyTime = GetWeeklyTimeAndFeeByStaff(),
        objects = #table(
            {"Name",  "Key",   "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            {"Time (Billable) by Staff: Current Week", "B", GetBillableByStaff(weeklyTime[BillableByStaff]), "Table",    "Table",    true},
            {"Time (Non-Billable) by Staff: Current Week", "N", GetBillableByStaff(weeklyTime[NonBillableByStaff]), "Table",    "Table",    true},
            {"Time and Fee Financials by Staff", "TF", GetTimeAndFeeFinancialsByStaff(weeklyTime[TimeAndFeeFinancialsByStaff]), "Table",    "Table",    true}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

CreateWeeklyHoursTable = () as table => 
    let
        weeklyHours = GetWeeklyTimeAndFeeHoursByStaff(),
        objects = #table(
            {"Name",  "Key",   "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            {"Hours (Billable) by Staff: Current Week", "BTF", GetBillableHoursByStaff(weeklyHours[BillableHoursByStaff]), "Table",    "Table",    true},
            {"Hours (Non-Billable) by Staff: Current Week", "NTF", GetBillableHoursByStaff(weeklyHours[NonBillableHoursByStaff]), "Table",    "Table",    true},
            {"Time Recorded Summary by Staff ", "T", GetTimeAndFeeHoursByStaff(weeklyHours[TimeRecordedByStaffSummary]), "Table",    "Table",    true},
            {"Fee Recorded Summary by Staff ", "F", GetTimeAndFeeHoursByStaff(weeklyHours[FeeRecordedByStaffSummary]), "Table",    "Table",    true}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

// Dimensions Table
CreateDimensionFolder = () as table => 
    let
        objects = #table(
            {"Name",  "Key",   "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            {"Billing Mode", "BMD", GetBillingModeTable(), "Table",    "Table",    true},
            {"Invoice Status", "INVS", GetInvoiceStatusTable(), "Table",    "Table",    true}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;
        

//
// Navigation Table Builders: Following builders help to create tables that present particular fixed date ranges to the endpoints.
//

CreateNavTable = (table as text, optional accountName as text, optional accountId as text) as table => 
    let
        parts = Json.Document(Base64Url.Decode(Text.Split(Extension.CurrentCredential()[access_token], "."){1})),
        countryCode = parts[countryCode],
        description = ": Last 3 Months",
        disbursementsAlias = GetLocalDisbursementName(countryCode),
        controlledMoneyAlias = GetLocalControlledMoneyName(countryCode),
        prefix = if table = "DisbursementListing" then disbursementsAlias
                 else if table = "InvoiceAdjustments" then "Adjustments"
                 else if table = "TrustAudit" then "Trust Audit"
                 else if table = "FeeContributionsRecovery" then "Fee Contributions and Recovery"
                 else if table = "StaffInvoicedFunds" then "Staff Invoiced Funds"
                 else if table = "StaffReceiptedFunds" then "Staff Receipted Funds"
                 else if table = "OfficeInvoices" then "Invoices"
                 else if table = "OfficeReceipts" then "Receipts"
                 else if table = "TimeAndFees" then "Time and Fees"
                 else if table = "ControlledMoneyControl" then Text.Combine({controlledMoneyAlias, " Control"})
                 else if table = "TrustBankRegister" and accountName <> null then Text.Combine({accountName, " Register"})
                 else table,
        objects = #table(
            {"Name",  "Key",   "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            {Text.Combine({prefix, ": Current Month"}), "CM", ExecuteSubNav(table, "CM", null, null, accountId), "Table",    "Table",    true},
            {Text.Combine({prefix, ": Previous Month"}), "PM", ExecuteSubNav(table, "PM", null, null, accountId), "Table",    "Table",    true},
            {Text.Combine({prefix, ": Previous Year"}), "PY", ExecuteSubNav(table, "PY", null, null, accountId), "Table",    "Table",    true},
            {Text.Combine({prefix, ": Current Year"}), "CY", ExecuteSubNav(table, "CY", null, null, accountId), "Table",    "Table",    true}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

CreateCYNavTable = (table as text, optional alias, optional accountName as text, optional accountId as text) as table => 
    let
        parts = Json.Document(Base64Url.Decode(Text.Split(Extension.CurrentCredential()[access_token], "."){1})),
        countryCode = parts[countryCode],
        disbursementsAlias = GetLocalDisbursementName(countryCode),
        description = if table = "StaffBudgets" then ": Last 90 Days and Next 90 Days" else ": Last 3 Months",
        prefix = if table = "DisbursementListing" then disbursementsAlias 
                 else if table = "InvoiceAdjustments" then "Adjustments"
                 else if table = "StaffBudgets" then "Staff Budgets"
                 else if table = "TrustAudit" then Text.Combine({alias, " Audit"})
                 else if table = "TrustBankRegister" and accountName <> null then Text.Combine({accountName, " Register"})
                 else table,
        objects = #table(
            {"Name",  "Key",   "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            {Text.Combine({prefix, description}), "M", ExecuteSubNav(table, "M", null, null, accountId), "Table",    "Table",    true},
            {Text.Combine({prefix, ": Current Year"}), "CY", ExecuteSubNav(table, "CY", null, null, accountId), "Table",    "Table",    true}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

CreateMinorNavTable = (table as text) as table => 
    let
        prefix = if table = "MattersOpened" then "Matters Opened" else table,
        objects = #table(
            {"Name",  "Key",   "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            {Text.Combine({prefix, ": Last 1 Week"}), "W", ExecuteSubNav(table, "W"), "Table",    "Table",    true},
            {Text.Combine({prefix, ": Last 3 Months"}), "M", ExecuteSubNav(table, "M"), "Table",    "Table",    true}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

CreateMinorNavCYTable = (table as text) as table => 
    let
        prefix = if table = "MattersOpened" then "Matters Opened" else table,
        objects = #table(
            {"Name",  "Key",   "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            {Text.Combine({prefix, ": Current Month"}), "CM", ExecuteSubNav(table, "CM"), "Table",    "Table",    true},
            {Text.Combine({prefix, ": Current Year"}), "CY", ExecuteSubNav(table, "CY"), "Table",    "Table",    true}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

CreateFutureNavTable = (table as text, optional alias as text) as table => 
    let
        description = if table = "MattersDueSettlement" then Text.Combine({"Due for ", alias})
                      else if table = "CriticalDates" then "Critical Dates"
                      else table,
        objects = #table(
            {"Name",  "Key",   "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            {Text.Combine({description, ": Next 90 Days"}), "FM", ExecuteSubNav(table, "FM"), "Table",    "Table",    true}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

// Helper function to initiate the request to LEAP.Feed to retrieve data
ExecuteSubNav = (optional path as text, optional period as text, optional start as date, optional end as date, optional accountId as text) =>
    let
        result = if path = "OfficeReceipts" then GetReceipts(period, start, end) 
                else if path = "TimeAndFees" then GetTimeAndFees(period, start, end) 
                else if path = "StaffBudgets" then GetStaffBudgets(period, start, end) 
                else if path = "StaffInvoicedFunds" then GetStaffInvoicedFunds(period, start, end)
                else if path = "StaffReceiptedFunds" then GetStaffReceiptedFunds(period, start, end)
                else if path = "CriticalDates" then GetCriticalDates(period, start, end)
                else if path = "TrustBankRegister" then GetTrustBankRegister(period, start, end, accountId)
                else if path = "MattersOpened" then GetMattersOpened(period)
                else if path = "MattersDueSettlement" then GetMattersDueForSettlement()
                else if path = "OfficeInvoices" then GetInvoices(period, start, end)
                else if path = "InvoiceAdjustments" then GetInvoiceAdjustments(period, start, end)
                else if path = "TrustAudit" then GetTrustAudit(period, start, end)
                else if path = "DisbursementListing" then GetDisbursementListing(period, start, end)
                else if path = "WIPByMatterFee" then GetWIPByMatterFeeDetail()
                else if path = "ControlledMoneyAccountList" then GetControlledMoneyAccountList()
                else if path = "ControlledMoneyControl" then GetControlledMoneyControlAccount(period, start, end)
                else if path = "FeeContributionsRecovery" then GetFeeContributionsAndRecovery(period, start, end)
                else if path = "TaskCodesFees" then GetTaskCodesFees()
                else if path = "TaskCodesCostRecovery" then GetTaskCodesCostRecovery()
                else {}
    in
        result;

// Executes simple GET calls to LEAP
CallLEAP = (token as text) => 
    let
        parts = Json.Document(Base64Url.Decode(Text.Split(Extension.CurrentCredential()[access_token], "."){1})),
        firmId = parts[firmId],
        countryCode = parts[countryCode],
        environment = parts[environment],
        userId = parts[userId],
        bearerToken = Extension.CurrentCredential()[access_token],
        url = if token = "UserType" then Text.Combine({ReturnBaseUrl(countryCode, environment),ReturnUri(token), userId, "/usertype"}) 
                else if token = "Firm" then Text.Combine({ReturnBaseUrl(countryCode, environment),ReturnUri(token), firmId}, "")
                else if token = "PowerBIOptions" then Text.Combine({ReturnOptionsUrl(countryCode, environment),ReturnUri(token)})
                else Text.Combine({ReturnBaseUrl(countryCode, environment),ReturnUri(token)}),
        tokenResponse = Web.Contents(url, [
            Headers = [
                #"Authorization" = Text.Combine({"bearer", bearerToken}, " "),
                #"Content-type" = "application/json",
                #"Accept" = "application/json",
                #"x-api-key" = GetRegionKey(countryCode, environment)
            ],
            ManualStatusHandling = {400, 404} 
        ]),
        metadata = Value.Metadata(tokenResponse),
        responseCode = metadata[Response.Status],
        body = if responseCode = 404 then {} else Json.Document(tokenResponse),
        result = body
    in
        result;

// Calls to LEAP using the RowVersion Pattern
// This is used by the GET /cards and /matters endpoint, where the call rowVersion is used in subsequent calls until lastRowVersion = null is returned
// getListFx is the recurring function being used to achieve this where 'row' is indicative of the last object in the matter/card list
CallRowVersion = (token as text) => 
    let
        parts = Json.Document(Base64Url.Decode(Text.Split(Extension.CurrentCredential()[access_token], "."){1})),
        firmId = parts[firmId],
        countryCode = parts[countryCode],
        environment = parts[environment],
        bearerToken = Extension.CurrentCredential()[access_token],
        url = Text.Combine({ReturnBaseUrl(countryCode, environment),ReturnUri(token)}),
        listType = if token = "Matters" then "matterList" else "cardList",
        getListFx = (row as number, incomingList) =>
            let
                parts = Json.Document(Base64Url.Decode(Text.Split(Extension.CurrentCredential()[access_token], "."){1})),
                firmId = parts[firmId],
                countryCode = parts[countryCode],
                bearerToken = Extension.CurrentCredential()[access_token],
                url = Text.Combine({url, "?rowVersion=", Number.ToText(row)}),
                tokenResponse = Web.Contents(url, [
                    Headers = [
                        #"Authorization" = Text.Combine({"bearer", bearerToken}, " "),
                        #"Content-type" = "application/json",
                        #"Accept" = "application/json",
                        #"x-api-key" = GetRegionKey(countryCode, environment)
                    ],
                    ManualStatusHandling = {400} 
                ]),
                body = Json.Document(tokenResponse),
                list = Record.Field(body, listType),
                lastRowVersion = Record.Field(body, "lastRowVersion"),
                combinedList = if lastRowVersion <> null then List.Combine({incomingList, list}) else incomingList,
                result = if lastRowVersion <> null then @getListFx(lastRowVersion, combinedList)
                         else if token = "Matters" then Json.FromValue([matterList = combinedList, lastRowVersion = null])
                         else Json.FromValue([cardList = combinedList, lastRowVersion = null])
            in
                result,
        tokenResponse = Web.Contents(url, [
            Headers = [
                #"Authorization" = Text.Combine({"bearer", bearerToken}, " "),
                #"Content-type" = "application/json",
                #"Accept" = "application/json",
                #"x-api-key" = GetRegionKey(countryCode, environment)
            ],
            ManualStatusHandling = {400} 
        ]),
        body = Json.Document(tokenResponse),
        initialList = Record.Field(body, listType),
        lastRowVersion =  Record.Field(body, "lastRowVersion"),
        query = @getListFx(lastRowVersion, initialList),
        report =  if Binary.ToText(query) <> "" then Json.Document(query)
                  else {},
        finalResult = report
    in
        finalResult;

//Manage requests to LEAP where data parameters are passed to LEAP via the body.
CallLEAPBalance = (token as text, optional period as text, optional start as date, optional end as date, optional accountId as text) => 
    let
        parts = Json.Document(Base64Url.Decode(Text.Split(Extension.CurrentCredential()[access_token], "."){1})),
        firmId = parts[firmId],
        countryCode = parts[countryCode],
        environment = parts[environment],
        queryString = GetQueryString(token, period, start, end, accountId),
        bearerToken = Extension.CurrentCredential()[access_token],
        url = Text.Combine({ReturnBaseUrl(countryCode, environment),ReturnUri(token)}),
        tokenResponse = Web.Contents(url, [
            Content = queryString,
            Headers = [
                #"Authorization" = Text.Combine({"bearer", bearerToken}, " "),
                #"Content-type" = "application/json",
                #"Accept" = "application/json",
                #"x-api-key" = GetRegionKey(countryCode, environment)
            ],
            ManualStatusHandling = {400} 
        ]),
        body = Json.Document(tokenResponse),
        id = Record.Field(body, "id"),
        reportUrl = Text.Combine({ReturnBaseUrl(countryCode, environment),"/api/v1/reporting/getasyncrequest/",id}),
        query = GetReportAsync(reportUrl),
        report =  if Binary.ToText(query) <> "" then Json.Document(query)
                  else {},
        presigned = if Value.Type(report) = List.Type then "" else Record.FieldOrDefault(report, "PreSignedURL", ""),
        result = if presigned <> "" then CallPreSign(presigned) else report,
        finalResult = result
    in
        finalResult;
         
// Manage requests to LEAP where date parameters are passed to LEAP within the path. 
// An asyncrequestid in the result, indicates to us that we need to poll the same endpoint with the value being parsed in as a query.
CallLEAPGetAsync = (token as text, optional period as text, optional start as date, optional end as date) => 
    let
        parts = Json.Document(Base64Url.Decode(Text.Split(Extension.CurrentCredential()[access_token], "."){1})),
        firmId = parts[firmId],
        countryCode = parts[countryCode],
        environment = parts[environment],
        url = Text.Combine({ReturnBaseUrl(countryCode, environment),ReturnUri(token), GetDatePath(token, period, start, end)}),
        bearerToken = Extension.CurrentCredential()[access_token],
        tokenResponse = Web.Contents(url, [
            Headers = [
                #"Authorization" = Text.Combine({"bearer", bearerToken}, " "),
                #"Content-type" = "application/json",
                #"Accept" = "application/json",
                #"x-api-key" = GetRegionKey(countryCode, environment)
            ],
            ManualStatusHandling = {400} 
        ]),
        body = Json.Document(tokenResponse),
        id = Record.Field(body, "AsyncRequestId"), 
        asyncUrl = Text.Combine({url,"?asyncRequestId=",id}),
        result = if id = null or id = "null" then body else Json.Document(GetReportAsync(asyncUrl))
    in
        result;
   
// Explicitly handles requests to /getasyncrequest which retrieves the final data from the reporting endpoints. Contains retry logic and handling for 202 codes.
GetReportAsync = (url) => 
    let waitForResult = Value.WaitFor(
        (iteration) => 
            let
                parts = Json.Document(Base64Url.Decode(Text.Split(Extension.CurrentCredential()[access_token], "."){1})),
                firmId = parts[firmId],
                countryCode = parts[countryCode],
                environment = parts[environment],
                bearerToken = Extension.CurrentCredential()[access_token],
                result =  Web.Contents(url, [
                Headers = [
                    #"Authorization" = Text.Combine({"bearer", bearerToken}, " "),
                    #"Content-type" = "application/json",
                    #"Accept" = "application/json",
                    #"x-api-key" = GetRegionKey(countryCode, environment)
                    ],
                    ManualStatusHandling = {202, 303, 201, 400},
                    IsRetry = iteration > 0
                ]), 
                buffered = Binary.Buffer(result),
                status = Value.Metadata(result)[Response.Status],
                actualResult = if status = 202 then null 
                               else if status = 400 then "{""AsyncRequestId"":null,""MatterCriticalDates"":[]}"
                               else buffered
            in
                actualResult,
        (iteration) => #duration(0, 0, 0, Number.Power(10, iteration)),15)
    in
        waitForResult;


// Returns the resource path based on the 'Token' which is passed through the connector
ReturnUri = (variant) => 
    let
        url = if variant = "Matters" then "/api/v3/matters" 
        else if variant = "Balances" then "/api/v1/reporting/matterbalances"
        else if variant = "ArchivedBalances" then "/api/v1/reporting/archivedmatterbalances"
        else if variant = "AgeingBalances" then "/api/v1/reporting/matterfinancialswithageing"
        else if variant = "Firm" then "/api/v1/firms/"
        else if variant = "FirmReportingGroups" then "/api/v1/reporting/firmreportinggroups"
        else if variant = "FeeSummary" then "/api/v1/reporting/stafftimeandfeeactivitysummary"
        else if variant = "InvoicedStaff" then "/api/v1/reporting/staffinvoicedfunds"
        else if variant = "OfficeInvoices" then "/api/v1/reporting/officeinvoices"
        else if variant = "OfficeReceipts" then "/api/v1/reporting/officereceipts"
        else if variant = "AgedWIP" then "/api/v1/reporting/agedwip"
        else if variant = "WIPByMatterFee" then "/api/v1/reporting/agedwipbymatterandfeedetail"
        else if variant = "WIPByMatter" then "/api/v1/reporting/agedwipbymatter"
        else if variant = "AgedDisbursements" then "/api/v1/reporting/ageddisbursements"
        else if variant = "AgedDebtors" then "/api/v1/reporting/ageddebtors"
        else if variant = "StaffInvoicedFunds" then "/api/v1/reporting/staffinvoicedfunds"
        else if variant = "StaffReceiptedFunds" then "/api/v1/reporting/staffreceiptedfunds"
        else if variant = "CriticalDates" then "/api/v1/reporting/matterscriticaldates"
        else if variant = "StaffBudgets" then "/api/v1/reporting/staffbudgets" 
        else if variant = "TimeAndFees" then "/api/v1/reporting/timeandfeelisting"
        else if variant = "DisbursementListing" then "/api/v1/reporting/disbursementlisting"
        else if variant = "ControlledMoneyAccountList" then "/api/v1/reporting/controlledmoneylistofaccounts"
        else if variant = "Cards" then "/api/v2/cards"
        else if variant = "TrustInitialisationData" then "/api/v1/trustreceipt/initialisationdata"
        else if variant = "TrustBankRegister" then "/api/v1/reporting/trustbankregister"
        else if variant = "TrustAudit" then "/api/v1/reporting/trustaudit"
        else if variant = "MattersOpened" then "/api/v1/reporting/mattersopened"
        else if variant = "WeeklyTime" then "/api/v1/reporting/weeklytimeandfeebystaff"
        else if variant = "WeeklyHour" then "/api/v1/reporting/weeklytimeandfeerecordedbystaff"
        else if variant = "MattersDueSettlement" then "/api/v1/reporting/mattersdueforsettlement"
        else if variant = "ControlledMoneyControl" then "/api/v1/reporting/controlledmoneycontrolaccount"
        else if variant = "InvoiceAdjustments" then "/api/v1/reporting/invoiceadjustments"
        else if variant = "FeeContributionsRecovery" then  "/api/v1/reporting/feecontributionandrecoveries"
        else if variant = "InactiveMatters" then "/api/v1/reporting/inactivematters"
        else if variant = "Accounts" then "/api/v1/accounts"
        else if variant = "Mapping" then "/api/v1/accounts"
        else if variant = "UserType" then "/api/v1/users/"
        else if variant = "PowerBIOptions" then "/api/staff-features/powerbi"
        else if variant = "TaskCodesFees" then "/api/v2/taskcodes/fees"
        else if variant = "TaskCodesCostRecovery" then "/api/v2/taskcodes/costrecovery"
        else null
    in
        url;

//
// Function to retrieve data from LEAP with any necessary transformations
//

GetMatters = () =>
let
    Source = LEAP.Feed("Matters"),
    matterList = Source[matterList],
    #"Converted to Table" = Table.FromList(matterList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"rowVersion", "matterId", "fileNumber", "firstDescription", "secondDescription", "customDescription", "matterTypeName", "matterTypeId", "matterStatus", "isCurrent", "state", "responsibleStaffId", "creditStaffId", "actingStaffId", "assistingStaffId", "isArchived", "deleted", "version", "instructionDate", "billingMode", "archiveDate", "isMatterAccessible"}, {"rowVersion", "matterId", "fileNumber", "firstDescription", "secondDescription", "customDescription", "matterTypeName", "matterTypeId", "matterStatus", "isCurrent", "state", "responsibleStaffId", "creditStaffId", "actingStaffId", "assistingStaffId", "isArchived", "deleted", "version", "instructionDate", "billingMode", "archiveDate", "isMatterAccessible"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"instructionDate", type datetimezone}, {"archiveDate", type datetimezone}})
in
    #"Changed Type";

// Return firm result => GetStaff and GetBranches to process result to two separate tables.
GetFirm = () =>
    let
        Source = LEAP.Feed("Firm"),
        result = Source
    in
        result;

GetStaff = () =>
    let
        Source = LEAP.Feed("Firm"),
        staff = Source[staff],
        #"Converted to Table" = Table.FromList(staff, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"__id", "userId", "branch", "firstName", "lastName", "middleName", "initials", "fullName", "legalFullName", "qualifications", "title", "phone", "fax", "email", "immigLicense", "certificates", "extension", "mobile", "firmReference", "rate1", "rate2", "rate3", "rate4", "rate5", "rate6", "status"}, {"__id", "userId", "branch", "firstName", "lastName", "middleName", "initials", "fullName", "legalFullName", "qualifications", "title", "phone", "fax", "email", "immigLicense", "certificates", "extension", "mobile", "firmReference", "rate1", "rate2", "rate3", "rate4", "rate5", "rate6", "status"})
    in
        #"Expanded Column1";


GetMattersEnriched = () =>
let
    // Get Matters data
    Source = LEAP.Feed("Matters"),
    matterList = Source[matterList],
    ConvertedToTable = Table.FromList(matterList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ExpandedMatter = Table.ExpandRecordColumn(ConvertedToTable, "Column1", {"rowVersion", "matterId", "fileNumber", "firstDescription", "secondDescription", "customDescription", "matterTypeName", "matterTypeId", "matterStatus", "isCurrent", "state", "responsibleStaffId", "creditStaffId", "actingStaffId", "assistingStaffId", "isArchived", "deleted", "version", "instructionDate", "billingMode", "archiveDate", "isMatterAccessible"}, {"rowVersion", "matterId", "fileNumber", "firstDescription", "secondDescription", "customDescription", "matterTypeName", "matterTypeId", "matterStatus", "isCurrent", "state", "responsibleStaffId", "creditStaffId", "actingStaffId", "assistingStaffId", "isArchived", "deleted", "version", "instructionDate", "billingMode", "archiveDate", "isMatterAccessible"}),
    ChangedType = Table.TransformColumnTypes(ExpandedMatter, {{"instructionDate", type datetimezone}, {"archiveDate", type datetimezone}}),
    
    // Get Staff data
    StaffSource = LEAP.Feed("Firm"),
    staff = StaffSource[staff],
    ConvertedToTableStaff = Table.FromList(staff, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ExpandedStaff = Table.ExpandRecordColumn(ConvertedToTableStaff, "Column1", {"__id", "fullName"}, {"__id", "fullName"}),

    // Merge with Staff table to get responsibleStaff full name
    MergeResponsibleStaff = Table.NestedJoin(ChangedType, {"responsibleStaffId"}, ExpandedStaff, {"__id"}, "responsibleStaff", JoinKind.LeftOuter),
    ExpandResponsibleStaff = Table.ExpandTableColumn(MergeResponsibleStaff, "responsibleStaff", {"fullName"}, {"responsibleStaffFullName"}),

    // Merge with Staff table to get creditStaff full name
    MergeCreditStaff = Table.NestedJoin(ExpandResponsibleStaff, {"creditStaffId"}, ExpandedStaff, {"__id"}, "creditStaff", JoinKind.LeftOuter),
    ExpandCreditStaff = Table.ExpandTableColumn(MergeCreditStaff, "creditStaff", {"fullName"}, {"creditStaffFullName"}),

    // Merge with Staff table to get actingStaff full name
    MergeActingStaff = Table.NestedJoin(ExpandCreditStaff, {"actingStaffId"}, ExpandedStaff, {"__id"}, "actingStaff", JoinKind.LeftOuter),
    ExpandActingStaff = Table.ExpandTableColumn(MergeActingStaff, "actingStaff", {"fullName"}, {"actingStaffFullName"}),

    // Merge with Staff table to get assistingStaff full name
    MergeAssistingStaff = Table.NestedJoin(ExpandActingStaff, {"assistingStaffId"}, ExpandedStaff, {"__id"}, "assistingStaff", JoinKind.LeftOuter),
    ExpandAssistingStaff = Table.ExpandTableColumn(MergeAssistingStaff, "assistingStaff", {"fullName"}, {"assistingStaffFullName"})
in
    ExpandAssistingStaff;

GetBranches = () => 
let
    Source = LEAP.Contents("Firm"),
    branches = Source[branches],
    #"Converted to Table" = Table.FromList(branches, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"__className", "__id", "name", "displayName", "isMainBranch", "deleteCode", "propertyBuildingName", "unitSuiteOffice", "level", "streetNumber", "streetName", "townCity", "county", "postcode", "firmName", "phone", "emailPreferences", "regulationAuthority", "firmType", "country", "postcodeLabel", "legalAidChargeRate", "crimeOfficeAccountNumberLegalAid", "crimeScheduleNumberLegalAid", "civilOfficeAccountNumberLegalAid", "civilScheduleNumberLegalAid", "regionLegalAid", "mediationScheduleNumberLegalAid", "legalAidMatter", "icoRegistrationNumber", "ledesId", "crn", "dxNumber", "dxExchange", "poBoxNumber", "poBoxTown", "poBoxPostcode", "fax", "emailAddress", "website"}, {"__className", "__id", "name", "displayName", "isMainBranch", "deleteCode", "propertyBuildingName", "unitSuiteOffice", "level", "streetNumber", "streetName", "townCity", "county", "postcode", "firmName", "phone", "emailPreferences", "regulationAuthority", "firmType", "country", "postcodeLabel", "legalAidChargeRate", "crimeOfficeAccountNumberLegalAid", "crimeScheduleNumberLegalAid", "civilOfficeAccountNumberLegalAid", "civilScheduleNumberLegalAid", "regionLegalAid", "mediationScheduleNumberLegalAid", "legalAidMatter", "icoRegistrationNumber", "ledesId", "crn", "dxNumber", "dxExchange", "poBoxNumber", "poBoxTown", "poBoxPostcode", "fax", "emailAddress", "website"})
in
    #"Expanded Column1";

GetSubStaff = (firm) =>
    let
        staff = firm[staff],
        #"Converted to Table" = Table.FromList(staff, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"__id", "userId", "branch", "firstName", "lastName", "middleName", "initials", "fullName", "legalFullName", "qualifications", "title", "phone", "fax", "email", "immigLicense", "certificates", "extension", "mobile", "firmReference", "rate1", "rate2", "rate3", "rate4", "rate5", "rate6", "status"}, {"__id", "userId", "branch", "firstName", "lastName", "middleName", "initials", "fullName", "legalFullName", "qualifications", "title", "phone", "fax", "email", "immigLicense", "certificates", "extension", "mobile", "firmReference", "rate1", "rate2", "rate3", "rate4", "rate5", "rate6", "status"}),
        #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"rate1", type number}, {"rate2", type number}, {"rate3", type number}, {"rate4", type number}, {"rate5", type number}, {"rate6", type number}})
    in
        #"Changed Type";

GetSubBranches = (firm) => 
let
    branches = firm[branches],
    #"Converted to Table" = Table.FromList(branches, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"__className", "__id", "name", "displayName", "isMainBranch", "deleteCode", "propertyBuildingName", "unitSuiteOffice", "level", "streetNumber", "streetName", "townCity", "county", "postcode", "firmName", "phone", "emailPreferences", "regulationAuthority", "firmType", "country", "postcodeLabel", "legalAidChargeRate", "crimeOfficeAccountNumberLegalAid", "crimeScheduleNumberLegalAid", "civilOfficeAccountNumberLegalAid", "civilScheduleNumberLegalAid", "regionLegalAid", "mediationScheduleNumberLegalAid", "legalAidMatter", "icoRegistrationNumber", "ledesId", "crn", "dxNumber", "dxExchange", "poBoxNumber", "poBoxTown", "poBoxPostcode", "fax", "emailAddress", "website"}, {"__className", "__id", "name", "displayName", "isMainBranch", "deleteCode", "propertyBuildingName", "unitSuiteOffice", "level", "streetNumber", "streetName", "townCity", "county", "postcode", "firmName", "phone", "emailPreferences", "regulationAuthority", "firmType", "country", "postcodeLabel", "legalAidChargeRate", "crimeOfficeAccountNumberLegalAid", "crimeScheduleNumberLegalAid", "civilOfficeAccountNumberLegalAid", "civilScheduleNumberLegalAid", "regionLegalAid", "mediationScheduleNumberLegalAid", "legalAidMatter", "icoRegistrationNumber", "ledesId", "crn", "dxNumber", "dxExchange", "poBoxNumber", "poBoxTown", "poBoxPostcode", "fax", "emailAddress", "website"})
in
    #"Expanded Column1";

GetBalance = (isArchived) =>
let
    ColumnNames = {"MatterId", "MatterNumber", "MatterDescription", "ClientDescription", "StaffActingId", "StaffActingInitials", "StaffActingName", "StaffResponsibleId", "StaffResponsibleInitials", "StaffResponsibleName", "StaffCreditId", "StaffCreditInitials", "StaffCreditName", "MatterType", "MatterStatus", "ReportingGroupId", "ReportingGroup", "TrustBalance", "WIP_IncTax", "WIP_ExTax", "Debtors_IncTax", "Debtors_ExTax", "Unbilled_CostRecoveries_IncTax", "Unbilled_CostRecoveries_ExTax", "Unbilled_DisbJournals_IncTax", "Unbilled_DisbJournals_ExTax", "Unbilled_Payments_IncTax", "Unbilled_Payments_ExTax", "Unbilled_AnticipatedPayments_IncTax", "Unbilled_AnticipatedPayments_ExTax", "CreditBalance"},
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    Table = if isArchived then "ArchivedBalances" else "Balances",
    Source = LEAP.Feed(Table),
    ListToConvert = if Source = {} then EmptyListHandler else Source,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"MatterId", "MatterNumber", "MatterDescription", "ClientDescription", "StaffActingId", "StaffActingInitials", "StaffActingName", "StaffResponsibleId", "StaffResponsibleInitials", "StaffResponsibleName", "StaffCreditId", "StaffCreditInitials", "StaffCreditName", "MatterType", "MatterStatus", "ReportingGroupId", "ReportingGroup", "TrustBalance", "WIP_IncTax", "WIP_ExTax", "Debtors_IncTax", "Debtors_ExTax", "Unbilled_CostRecoveries_IncTax", "Unbilled_CostRecoveries_ExTax", "Unbilled_DisbJournals_IncTax", "Unbilled_DisbJournals_ExTax", "Unbilled_Payments_IncTax", "Unbilled_Payments_ExTax", "Unbilled_AnticipatedPayments_IncTax", "Unbilled_AnticipatedPayments_ExTax", "CreditBalance"}, {"MatterId", "MatterNumber", "MatterDescription", "ClientDescription", "StaffActingId", "StaffActingInitials", "StaffActingName", "StaffResponsibleId", "StaffResponsibleInitials", "StaffResponsibleName", "StaffCreditId", "StaffCreditInitials", "StaffCreditName", "MatterType", "MatterStatus", "ReportingGroupId", "ReportingGroup", "TrustBalance", "WIP_IncTax", "WIP_ExTax", "Debtors_IncTax", "Debtors_ExTax", "Unbilled_CostRecoveries_IncTax", "Unbilled_CostRecoveries_ExTax", "Unbilled_DisbJournals_IncTax", "Unbilled_DisbJournals_ExTax", "Unbilled_Payments_IncTax", "Unbilled_Payments_ExTax", "Unbilled_AnticipatedPayments_IncTax", "Unbilled_AnticipatedPayments_ExTax", "CreditBalance"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"TrustBalance", type number}, {"Unbilled_CostRecoveries_ExTax", type number}, {"Unbilled_CostRecoveries_IncTax", type number}, {"Debtors_ExTax", type number}, {"Debtors_IncTax", type number}, {"WIP_ExTax", type number}, {"WIP_IncTax", type number}, {"Unbilled_DisbJournals_IncTax", type number}, {"Unbilled_DisbJournals_ExTax", type number}, {"Unbilled_Payments_IncTax", type number}, {"Unbilled_Payments_ExTax", type number}, {"Unbilled_AnticipatedPayments_IncTax", type number}, {"Unbilled_AnticipatedPayments_ExTax", type number}, {"CreditBalance", type number}})
in
    #"Changed Type";

GetFeeSummary = (period as text) =>
let
    ColumnNames = {"MatterId", "MatterNumber", "MatterDescription", "BillingDescription", "FeeHoursQuantity", "TotalExTax", "TotalIncTax", "BillingMode", "TransactionDate", "Deleted", "DeletedDate", "WorkDoneByStaffId", "StaffName", "TaskCodeId", "TaskCode", "TaskCodeDescription"},
    Source = LEAP.Feed("FeeSummary", period),
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if Source = {} or List.IsEmpty(Source) then EmptyListHandler else Source,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"MatterId", "MatterNumber", "MatterDescription", "BillingDescription", "FeeHoursQuantity", "TotalExTax", "TotalIncTax", "BillingMode", "TransactionDate", "Deleted", "DeletedDate", "WorkDoneByStaffId", "StaffName", "TaskCodeId", "TaskCode", "TaskCodeDescription"}, {"MatterId", "MatterNumber", "MatterDescription", "BillingDescription", "FeeHoursQuantity", "TotalExTax", "TotalIncTax", "BillingMode", "TransactionDate", "Deleted", "DeletedDate", "WorkDoneByStaffId", "StaffName", "TaskCodeId", "TaskCode", "TaskCodeDescription"}),
    #"Changed Type1" = Table.TransformColumnTypes(#"Expanded Column1",{{"TransactionDate", type datetime}, {"TotalIncTax", type number}, {"TotalExTax", type number}, {"FeeHoursQuantity", type number}, {"Deleted", type logical}, {"DeletedDate", type datetime}})
in
    #"Changed Type1";

GetInvoices = (optional period as text, optional start as date, optional end as date) =>
let
    ColumnNames = {"InvoiceId", "TransactionDate", "TransactionNumber", "MatterNumber", "CardDescription", "TotalIncTax", "BalanceDue", "TotalApplied", "AdjustmentsIncTax", "FeesAmountIncTax", "FeesAmountExTax", "FeesAmountTax", "DisbAmountIncTax", "DisbAmountExTax", "DisbAmountTax", "InvoiceStatus", "MatterId", "DeletedDate", "ReversedOrReversal", "ReversedDate", "StaffActingId", "StaffActingName", "StaffActingInitials", "StaffResponsibleId", "StaffResponsibleName", "StaffResponsibleInitials", "StaffCreditId", "StaffCreditName", "StaffCreditInitials", "MatterTypeId", "MatterType"},
    Source = LEAP.Feed("OfficeInvoices", period, start, end),
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    OfficeInvoiceList =  Source[OfficeInvoices],
    ListToConvert = if OfficeInvoiceList = {} then EmptyListHandler else OfficeInvoiceList,
    #"Converted to Table1" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table1", "Column1", {"InvoiceId", "TransactionDate", "TransactionNumber", "MatterNumber", "CardDescription", "TotalIncTax", "BalanceDue", "TotalApplied", "AdjustmentsIncTax", "FeesAmountIncTax", "FeesAmountExTax", "FeesAmountTax", "DisbAmountIncTax", "DisbAmountExTax", "DisbAmountTax", "InvoiceStatus", "MatterId", "DeletedDate", "ReversedOrReversal", "ReversedDate", "StaffActingId", "StaffActingName", "StaffActingInitials", "StaffResponsibleId", "StaffResponsibleName", "StaffResponsibleInitials", "StaffCreditId", "StaffCreditName", "StaffCreditInitials", "MatterTypeId", "MatterType"}, {"InvoiceId", "TransactionDate", "TransactionNumber", "MatterNumber", "CardDescription", "TotalIncTax", "BalanceDue", "TotalApplied", "AdjustmentsIncTax", "FeesAmountIncTax", "FeesAmountExTax", "FeesAmountTax", "DisbAmountIncTax", "DisbAmountExTax", "DisbAmountTax", "InvoiceStatus", "MatterId", "DeletedDate", "ReversedOrReversal", "ReversedDate", "StaffActingId", "StaffActingName", "StaffActingInitials", "StaffResponsibleId", "StaffResponsibleName", "StaffResponsibleInitials", "StaffCreditId", "StaffCreditName", "StaffCreditInitials", "MatterTypeId", "MatterType"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"TransactionDate", type datetime}, {"TotalIncTax", type number}, {"BalanceDue", type number}, {"TotalApplied", type number}, {"AdjustmentsIncTax", type number}, {"FeesAmountIncTax", type number}, {"FeesAmountExTax", type number}, {"FeesAmountTax", type number}, {"DisbAmountTax", type number}, {"DisbAmountExTax", type number}, {"DisbAmountIncTax", type number}})
in
    #"Changed Type";

GetReceipts = (period as text,  optional start as date, optional end as date) =>
let
    ColumnNames = {"ReceiptId", "TransactionNumber", "TransactionDate", "InvoiceId", "InvoiceNumber", "BankAccountId", "BankAccount", "MatterNumber", "ReceivedFrom", "ClientName", "DebtorAddress", "PaymentTypeId", "PaymentType", "Memo", "NeedsBanking", "Amount_Tax", "Amount_ExTax", "Amount_IncTax", "ReversedOrReversal", "ReversalId", "ReversedDate", "CreatedByStaffId"},
    Source = LEAP.Feed("OfficeReceipts", period, start, end),
    OfficeReceipts = Source[OfficeReceiptsList],
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if OfficeReceipts = {} then EmptyListHandler else OfficeReceipts,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column2" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"ReceiptId", "TransactionNumber", "TransactionDate", "InvoiceId", "InvoiceNumber", "BankAccountId", "BankAccount", "MatterNumber", "ReceivedFrom", "ClientName", "DebtorAddress", "PaymentTypeId", "PaymentType", "Memo", "NeedsBanking", "Amount_Tax", "Amount_ExTax", "Amount_IncTax", "ReversedOrReversal", "ReversalId", "ReversedDate", "CreatedByStaffId"}, {"ReceiptId", "TransactionNumber", "TransactionDate", "InvoiceId", "InvoiceNumber", "BankAccountId", "BankAccount", "MatterNumber", "ReceivedFrom", "ClientName", "DebtorAddress", "PaymentTypeId", "PaymentType", "Memo", "NeedsBanking", "Amount_Tax", "Amount_ExTax", "Amount_IncTax", "ReversedOrReversal", "ReversalId", "ReversedDate", "CreatedByStaffId"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column2",{{"TransactionDate", type datetime}, {"NeedsBanking", type logical}, {"Amount_Tax", type number}, {"Amount_ExTax", type number}, {"Amount_IncTax", type number}, {"ReversedOrReversal", type logical}, {"ReversedDate", type datetime}})
in
    #"Changed Type";

GetDisbursements = () =>
let
    ColumnNames =  { "MatterId", "MatterNumber", "MatterType", "MatterDescription", "ClientName", "StaffActingId", "StaffActing", "StaffResponsibleId", "StaffResponsible", "StaffCreditId", "StaffCredit", "ReportingGroupId", "ReportingGroup", "Disbursements" },
    Source = LEAP.Feed("AgedDisbursements"),
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if Source = {} then EmptyListHandler else Source,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Value" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"MatterId", "MatterNumber", "MatterType", "MatterDescription", "ClientName", "StaffActingId", "StaffActing", "StaffResponsibleId", "StaffResponsible", "StaffCreditId", "StaffCredit", "ReportingGroupId", "ReportingGroup", "Disbursements"}, {"MatterId", "MatterNumber", "MatterType", "MatterDescription", "ClientName", "StaffActingId", "StaffActing", "StaffResponsibleId", "StaffResponsible", "StaffCreditId", "StaffCredit", "ReportingGroupId", "ReportingGroup", "Disbursements"}),
    #"Expanded CustomField" = Table.ExpandListColumn(#"Expanded Value", "Disbursements"),
    #"Expanded CustomField1" = Table.ExpandRecordColumn(#"Expanded CustomField", "Disbursements", {"DisbursementId", "DisbursementItemId", "DisbursementType", "TransactionDate", "TransactionNumber", "BillingDescription", "CostRecoveryTaskCode", "BillingMode", "DeletedDate", "ReversalDate", "TotalIncTax", "TotalExTax", "CurrentIncTax", "CurrentExTax", "Period1IncTax", "Period1ExTax", "Period2IncTax", "Period2ExTax", "Period3IncTax", "Period3ExTax"}, {"DisbursementId", "DisbursementItemId", "DisbursementType", "TransactionDate", "TransactionNumber", "BillingDescription", "CostRecoveryTaskCode", "BillingMode", "DeletedDate", "ReversalDate", "TotalIncTax", "TotalExTax", "CurrentIncTax", "CurrentExTax", "Period1IncTax", "Period1ExTax", "Period2IncTax", "Period2ExTax", "Period3IncTax", "Period3ExTax"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded CustomField1" ,{{"TransactionDate", type datetime}, {"TotalIncTax", type number}, {"TotalExTax", type number}, {"CurrentIncTax", type number}, {"CurrentExTax", type number}, {"Period1IncTax", type number}, {"Period1ExTax", type number}, {"Period2IncTax", type number}, {"Period2ExTax", type number}, {"Period3IncTax", type number}, {"Period3ExTax", type number}})
in
    #"Changed Type";

GetDisbursementListing = (period as text,  optional start as date, optional end as date) =>
let
    ColumnNames = {"DisbursementId", "MatterId", "DisbursementTypeId", "DisbursementType", "TransactionDate", "InvoiceNumber", "TransactionNumber", "BillingDescription", "Amount_IncTax", "Amount_ExTax", "Amount_Tax", "Billed_IncTax", "Billed_ExTax", "Billed_Tax", "Adjustment_IncTax", "Adjustment_ExTax", "Adjustment_Tax", "Reversed", "ReversalDate", "Deleted", "DeletedDate", "BillingMode", "IsBilled", "MatterNumber", "MatterTypeId", "MatterType", "StaffResponsibleId", "StaffResponsibleName", "StaffActingId", "StaffActingName", "StaffCreditId", "StaffCreditName", "ReportingGroupId", "ReportingGroup", "Client", "ClientShortDescription"},
    Source = LEAP.Feed("DisbursementListing", period, start, end),
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if Source = {} or Source = []  or Source[Disbursements] = {} then EmptyListHandler else Source[Disbursements],
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"DisbursementId", "MatterId", "DisbursementTypeId", "DisbursementType", "TransactionDate", "InvoiceNumber", "TransactionNumber", "BillingDescription", "Amount_IncTax", "Amount_ExTax", "Amount_Tax", "Billed_IncTax", "Billed_ExTax", "Billed_Tax", "Adjustment_IncTax", "Adjustment_ExTax", "Adjustment_Tax", "Reversed", "ReversalDate", "Deleted", "DeletedDate", "BillingMode", "IsBilled", "MatterNumber", "MatterTypeId", "MatterType", "StaffResponsibleId", "StaffResponsibleName", "StaffActingId", "StaffActingName", "StaffCreditId", "StaffCreditName", "ReportingGroupId", "ReportingGroup", "Client", "ClientShortDescription"}, {"DisbursementId", "MatterId", "DisbursementTypeId", "DisbursementType", "TransactionDate", "InvoiceNumber", "TransactionNumber", "BillingDescription", "Amount_IncTax", "Amount_ExTax", "Amount_Tax", "Billed_IncTax", "Billed_ExTax", "Billed_Tax", "Adjustment_IncTax", "Adjustment_ExTax", "Adjustment_Tax", "Reversed", "ReversalDate", "Deleted", "DeletedDate", "BillingMode", "IsBilled", "MatterNumber", "MatterTypeId", "MatterType", "StaffResponsibleId", "StaffResponsibleName", "StaffActingId", "StaffActingName", "StaffCreditId", "StaffCreditName", "ReportingGroupId", "ReportingGroup", "Client", "ClientShortDescription"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"TransactionDate", type datetime}, {"Amount_IncTax", type number}, {"Amount_ExTax", type number}, {"Amount_Tax", type number}, {"Billed_IncTax", type number}, {"Billed_ExTax", type number}, {"Billed_Tax", type number}, {"Adjustment_IncTax", type number}, {"Adjustment_Tax", type number}, {"Adjustment_ExTax", type number}, {"ReversalDate", type datetime}, {"DeletedDate", type datetime}, {"Deleted", type logical}, {"IsBilled", type logical}})
in
    #"Changed Type";

GetDebtors = () =>
let
    ColumnNames = {"MatterId", "MatterNumber", "DebtorCardId", "DebtorName", "DebtorShortName", "DebtorPhoneNumber", "CardId", "CardDescription", "CardFirstDescription", "ClientPhoneNumber", "MatterDescription", "Memo", "StaffResponsibleId", "StaffResponsibleName", "StaffActingId", "StaffActingName", "StaffCreditId", "StaffCreditName", "StaffAssistingId", "StaffAssistingName", "MatterTypeId", "MatterType", "ReportingGroupId", "ReportingGroup", "DebtorNote", "Invoices", "MatterCreditBalance"},
    Source = LEAP.Feed("AgedDebtors"),
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if Source = {} then EmptyListHandler else Source,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Value" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"MatterId", "MatterNumber", "DebtorCardId", "DebtorName", "DebtorShortName", "DebtorPhoneNumber", "CardId", "CardDescription", "CardFirstDescription", "ClientPhoneNumber", "MatterDescription", "Memo", "StaffResponsibleId", "StaffResponsibleName", "StaffActingId", "StaffActingName", "StaffCreditId", "StaffCreditName", "StaffAssistingId", "StaffAssistingName", "MatterTypeId", "MatterType", "ReportingGroupId", "ReportingGroup", "DebtorNote", "Invoices", "MatterCreditBalance"}, {"MatterId", "MatterNumber", "DebtorCardId", "DebtorName", "DebtorShortName", "DebtorPhoneNumber", "CardId", "CardDescription", "CardFirstDescription", "ClientPhoneNumber", "MatterDescription", "Memo", "StaffResponsibleId", "StaffResponsibleName", "StaffActingId", "StaffActingName", "StaffCreditId", "StaffCreditName", "StaffAssistingId", "StaffAssistingName", "MatterTypeId", "MatterType", "ReportingGroupId", "ReportingGroup", "DebtorNote", "Invoices", "MatterCreditBalance"}),
    #"Expanded CustomField" = Table.ExpandListColumn(#"Expanded Value", "Invoices"),
    #"Expanded CustomField1" = Table.ExpandRecordColumn(#"Expanded CustomField", "Invoices", {"InvoiceId", "TransactionNumber", "TransactionDate", "InvoiceStatus", "InvoiceStatusDescription", "BalanceDue", "TotalIncTax", "TotalExTax", "TotalTax", "CurrentBalanceDue", "Period1BalanceDue", "Period2BalanceDue", "Period3BalanceDue", "DeletedDate", "ReversedDate"}, {"InvoiceId", "TransactionNumber", "TransactionDate", "InvoiceStatus", "InvoiceStatusDescription", "BalanceDue", "TotalIncTax", "TotalExTax", "TotalTax", "CurrentBalanceDue", "Period1BalanceDue", "Period2BalanceDue", "Period3BalanceDue", "DeletedDate", "ReversedDate"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded CustomField1",{{"TransactionDate", type datetime}, {"Period3BalanceDue", type number}, {"Period2BalanceDue", type number}, {"Period1BalanceDue", type number}, {"CurrentBalanceDue", type number}, {"TotalTax", type number}, {"TotalExTax", type number}, {"TotalIncTax", type number}, {"BalanceDue", type number}})
in
    #"Changed Type";

GetWIP = () =>
let
    ColumnNames = {"FeeId", "MatterId", "MatterNumber", "MatterDescription", "ClientCardId", "ClientDescription", "StaffActingId", "StaffActing", "StaffResponsibleId", "StaffResponsible", "StaffBilledById", "StaffBilledBy", "StaffCreditId", "StaffCredit", "StaffAssistingId", "StaffAssisting", "MatterTypeId", "MatterType", "MatterStatus", "ReportingGroupId", "ReportingGroup", "TransactionDate", "TransactionNumber", "TotalIncTax", "TotalExTax", "DeletedDate", "Deleted", "BillingDescription", "BillingMode", "InvoiceStatus", "CurrentIncTax", "CurrentExTax", "Period1IncTax", "Period1ExTax", "Period2IncTax", "Period2ExTax", "Period3IncTax", "Period3ExTax"},
    Source = LEAP.Feed("AgedWIP"),
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if Source = {} then EmptyListHandler else Source,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"FeeId", "MatterId", "MatterNumber", "MatterDescription", "ClientCardId", "ClientDescription", "StaffActingId", "StaffActing", "StaffResponsibleId", "StaffResponsible", "StaffBilledById", "StaffBilledBy", "StaffCreditId", "StaffCredit", "StaffAssistingId", "StaffAssisting", "MatterTypeId", "MatterType", "MatterStatus", "ReportingGroupId", "ReportingGroup", "TransactionDate", "TransactionNumber", "TotalIncTax", "TotalExTax", "DeletedDate", "Deleted", "BillingDescription", "BillingMode", "InvoiceStatus", "CurrentIncTax", "CurrentExTax", "Period1IncTax", "Period1ExTax", "Period2IncTax", "Period2ExTax", "Period3IncTax", "Period3ExTax"}, {"FeeId", "MatterId", "MatterNumber", "MatterDescription", "ClientCardId", "ClientDescription", "StaffActingId", "StaffActing", "StaffResponsibleId", "StaffResponsible", "StaffBilledById", "StaffBilledBy", "StaffCreditId", "StaffCredit", "StaffAssistingId", "StaffAssisting", "MatterTypeId", "MatterType", "MatterStatus", "ReportingGroupId", "ReportingGroup", "TransactionDate", "TransactionNumber", "TotalIncTax", "TotalExTax", "DeletedDate", "Deleted", "BillingDescription", "BillingMode", "InvoiceStatus", "CurrentIncTax", "CurrentExTax", "Period1IncTax", "Period1ExTax", "Period2IncTax", "Period2ExTax", "Period3IncTax", "Period3ExTax"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"TotalIncTax", type number}, {"TotalExTax", type number}, {"CurrentIncTax", type number}, {"CurrentExTax", type number}, {"Period1IncTax", type number}, {"Period1ExTax", type number}, {"Period2IncTax", type number}, {"Period2ExTax", type number}, {"Period3IncTax", type number}, {"Period3ExTax", type number}, {"TransactionDate", type datetime}})
in
    #"Changed Type";

GetStaffInvoicedFunds = (period as text, optional start as date, optional end as date) =>
let
    ColumnNames = {"MatterId", "MatterNumber", "StaffId", "StaffName", "InvoiceId", "InvoiceStatus", "InvoiceStatusDescription", "TransactionNumber", "TransactionDate", "InvoiceItemId", "BillingDescription", "ContributionIncTax", "ContributionExTax", "FeeAmountExTax", "FeeAmountIncTax", "AdjustmentExTax", "AdjustmentIncTax", "TotalExTax", "TotalIncTax", "MonthYear"},
    Source = LEAP.Feed("StaffInvoicedFunds", period, start, end),
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if Source = {} then EmptyListHandler else Source,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"MatterId", "MatterNumber", "StaffId", "StaffName", "InvoiceId", "InvoiceStatus", "InvoiceStatusDescription", "TransactionNumber", "TransactionDate", "InvoiceItemId", "BillingDescription", "ContributionIncTax", "ContributionExTax", "FeeAmountExTax", "FeeAmountIncTax", "AdjustmentExTax", "AdjustmentIncTax", "TotalExTax", "TotalIncTax", "MonthYear"}, {"MatterId", "MatterNumber", "StaffId", "StaffName", "InvoiceId", "InvoiceStatus", "InvoiceStatusDescription", "TransactionNumber", "TransactionDate", "InvoiceItemId", "BillingDescription", "ContributionIncTax", "ContributionExTax", "FeeAmountExTax", "FeeAmountIncTax", "AdjustmentExTax", "AdjustmentIncTax", "TotalExTax", "TotalIncTax", "MonthYear"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"TransactionDate", type datetime}, {"ContributionIncTax", type number}, {"ContributionExTax", type number}, {"FeeAmountExTax", type number}, {"FeeAmountIncTax", type number}, {"AdjustmentExTax", type number}, {"AdjustmentIncTax", type number}, {"TotalExTax", type number}, {"TotalIncTax", type number}, {"MonthYear", type datetime}})
in
    #"Changed Type";

GetInvoiceAdjustments = (period as text, optional start as date, optional end as date) =>
let
    ColumnNames = {"MatterId", "MatterNumber", "StaffId", "StaffName", "InvoiceId", "InvoiceStatus", "InvoiceStatusDescription", "TransactionNumber", "TransactionDate", "InvoiceItemId", "BillingDescription", "ContributionIncTax", "ContributionExTax", "FeeAmountExTax", "FeeAmountIncTax", "AdjustmentExTax", "AdjustmentIncTax", "TotalExTax", "TotalIncTax", "MonthYear"},
    Source = LEAP.Feed("InvoiceAdjustments", period, start, end),
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if Source = {} then EmptyListHandler else Source,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"AdjustmentId", "TransactionDate", "TransactionNumber", "MailToAddressee", "Memo", "AbsSeqNum", "ReversedOrReversal", "ReversedDate", "ReversalAdjustmentId", "InvoiceId", "InvoiceItemId", "TimeFeeId", "CostRecoveryId", "OfficePaymentItemId", "DisbursementJournalItemId", "AnticipatedDisbursementId", "TaxCodeId", "Amount_IncTax", "Amount_ExTax", "Amount_Tax"}, {"AdjustmentId", "TransactionDate", "TransactionNumber", "MailToAddressee", "Memo", "AbsSeqNum", "ReversedOrReversal", "ReversedDate", "ReversalAdjustmentId", "InvoiceId", "InvoiceItemId", "TimeFeeId", "CostRecoveryId", "OfficePaymentItemId", "DisbursementJournalItemId", "AnticipatedDisbursementId", "TaxCodeId", "Amount_IncTax", "Amount_ExTax", "Amount_Tax"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"TransactionDate", type datetime}, {"ReversedOrReversal", type logical}, {"ReversedDate", type datetime}, {"Amount_IncTax", type number}, {"Amount_ExTax", type number}, {"Amount_Tax", type number}})
in
    #"Changed Type";

GetStaffReceiptedFunds = (period as text, optional start as date, optional end as date) =>
let
    ColumnNames = {"ReceiptDate", "InvoiceDate", "ReceiptId", "ReceiptNumber", "InvoiceId", "InvoiceNumber", "InvoiceStatus", "InvoiceStatusDescription", "StaffId", "StaffName", "MatterFirstDescription", "MatterNumber", "Memo", "InvoiceAmountExTax", "InvoiceAmountIncTax", "FeeAmountExTax", "FeeAmountIncTax", "ReceiptAmountExtax", "ReceiptAmountIncTax", "ContributionIncTax", "ContributionExTax" , "PercentageIncTax" , "PercentageExTax" , "MonthYear"},
    Source = LEAP.Feed("StaffReceiptedFunds", period, start, end),
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if Source = {} then EmptyListHandler else Source,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"ReceiptDate", "InvoiceDate", "ReceiptId", "ReceiptNumber", "InvoiceId", "InvoiceNumber", "InvoiceStatus", "InvoiceStatusDescription", "StaffId", "StaffName", "MatterFirstDescription", "MatterNumber", "Memo", "InvoiceAmountExTax", "InvoiceAmountIncTax", "FeeAmountExTax", "FeeAmountIncTax", "ReceiptAmountExtax", "ReceiptAmountIncTax", "ContributionIncTax", "ContributionExTax" , "PercentageIncTax" , "PercentageExTax" , "MonthYear"}, {"ReceiptDate", "InvoiceDate", "ReceiptId", "ReceiptNumber", "InvoiceId", "InvoiceNumber", "InvoiceStatus", "InvoiceStatusDescription", "StaffId", "StaffName", "MatterFirstDescription", "MatterNumber", "Memo", "InvoiceAmountExTax", "InvoiceAmountIncTax", "FeeAmountExTax", "FeeAmountIncTax", "ReceiptAmountExtax", "ReceiptAmountIncTax", "ContributionIncTax", "ContributionExTax" , "PercentageIncTax" , "PercentageExTax" , "MonthYear"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"InvoiceDate", type datetime}, {"ReceiptDate", type datetime}, {"InvoiceAmountExTax", type number}, {"InvoiceAmountIncTax", type number}, {"FeeAmountExTax", type number}, {"FeeAmountIncTax", type number}, {"ReceiptAmountExtax", type number}, {"ReceiptAmountIncTax", type number}, {"ContributionIncTax", type number}, {"ContributionExTax", type number}})
in
    #"Changed Type";

GetCriticalDates = (period as text, optional start as date, optional end as date) =>
let
    ColumnNames = {"MatterId", "MatterNumber", "ClientName", "CriticalDateId", "CriticalDateName", "CriticalDate", "MatterDescription", "MatterStatus", "MatterType", "StaffResponsibleId", "StaffActingId", "StaffResponsibleInitials", "StaffActingInitials", "StaffResponsibleName", "StaffActingName"},
    Source = LEAP.Feed("CriticalDates", period, start, end),
    MatterCriticalDates = Source[MatterCriticalDates],
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if MatterCriticalDates = {} or MatterCriticalDates = null then EmptyListHandler else MatterCriticalDates,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"MatterId", "MatterNumber", "ClientName", "CriticalDateId", "CriticalDateName", "CriticalDate", "MatterDescription", "MatterStatus", "MatterType", "StaffResponsibleId", "StaffActingId", "StaffResponsibleInitials", "StaffActingInitials", "StaffResponsibleName", "StaffActingName"}, {"MatterId", "MatterNumber", "ClientName", "CriticalDateId", "CriticalDateName", "CriticalDate", "MatterDescription", "MatterStatus", "MatterType", "StaffResponsibleId", "StaffActingId", "StaffResponsibleInitials", "StaffActingInitials", "StaffResponsibleName", "StaffActingName"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"CriticalDate", type datetime}})
in
    #"Changed Type";

GetTimeAndFees = (period as text, optional start as date, optional end as date) =>
let
    ColumnNames = {"FeeId", "MatterId", "TransactionNumber", "TransactionDate", "AbsSeqNum", "Type", "BillingMode", "Status", "BillingDescription", "FeeHoursQuantity", "TaskCode", "AmountIncTax", "AmountExTax", "MatterNumber", "MatterDescription", "ClientDescription", "WorkDoneBy_StaffId", "WordDoneBy_StaffName", "WordDoneBy_StaffInitials", "InvoiceNumber", "IsDeleted"},
    Source = LEAP.Feed("TimeAndFees", period, start, end),
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if Source = {} or Source = [] then EmptyListHandler else Source,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"FeeId", "MatterId", "TransactionNumber", "TransactionDate", "AbsSeqNum", "Type", "BillingMode", "Status", "BillingDescription", "FeeHoursQuantity", "TaskCode", "AmountIncTax", "AmountExTax", "MatterNumber", "MatterDescription", "ClientDescription", "WorkDoneBy_StaffId", "WordDoneBy_StaffName", "WordDoneBy_StaffInitials", "InvoiceNumber", "IsDeleted"}, {"FeeId", "MatterId", "TransactionNumber", "TransactionDate", "AbsSeqNum", "Type", "BillingMode", "Status", "BillingDescription", "FeeHoursQuantity", "TaskCode", "AmountIncTax", "AmountExTax", "MatterNumber", "MatterDescription", "ClientDescription", "WorkDoneBy_StaffId", "WordDoneBy_StaffName", "WordDoneBy_StaffInitials", "InvoiceNumber", "IsDeleted"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"AmountExTax", type number}, {"AmountIncTax", type number}, {"TransactionDate", type datetime}, {"FeeHoursQuantity", type number}})
in
    #"Changed Type";
    
GetStaffBudgets = (period as text, optional start as date, optional end as date) =>
let
    ColumnNames = {"StaffId", "FirstName", "LastName","BudgetDetail.BudgetDate", "BudgetDetail.Hours", "BudgetDetail.Amount", "BudgetDetail.NonBillableHours", "BudgetDetail.FeesCollected"},
    Source = LEAP.Feed("StaffBudgets", period, start, end),
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    #"Converted to Table" = Table.FromList(EmptyListHandler, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", ColumnNames, ColumnNames),
    Result = if Source = {} or Source = [] then #"Expanded Column1" else ProcessStaffBudgets(Source)
in
    Result;

ProcessStaffBudgets = (source) => 
let 
    BudgetsTable = Table.FromList(source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(BudgetsTable, "Column1", {"StaffId", "FirstName", "LastName", "BudgetDetail"}, {"StaffId", "FirstName", "LastName", "BudgetDetail"}),
    #"Expanded Column1.BudgetDetail" = Table.ExpandListColumn(#"Expanded Column1", "BudgetDetail"),
    #"Expanded Column1.BudgetDetail1" = Table.ExpandRecordColumn(#"Expanded Column1.BudgetDetail", "BudgetDetail", {"BudgetDate", "Hours", "Amount", "NonBillableHours", "FeesCollected"}, {"BudgetDetail.BudgetDate", "BudgetDetail.Hours", "BudgetDetail.Amount", "BudgetDetail.NonBillableHours", "BudgetDetail.FeesCollected"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1.BudgetDetail1",{{"BudgetDetail.BudgetDate", type datetime}, {"BudgetDetail.Amount", type number}, {"BudgetDetail.FeesCollected", type number}, {"BudgetDetail.Hours", type number}})
in
    #"Changed Type";
  
GetCards = () =>
let
    ColumnNames = {"cardId", "shortName", "description", "deleted", "rowVersion", "type"},
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    Source = LEAP.Feed("Cards"),
    ListToConvert = if Source = {} or Source = [] then EmptyListHandler else Source,
    cardList = ListToConvert[cardList],
    #"Converted to Table" = Table.FromList(cardList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"cardId", "shortName", "description", "deleted", "rowVersion", "type"}, {"cardId", "shortName", "description", "deleted", "rowVersion", "type"})
in
    #"Expanded Column1";

GetTrustAudit = (period as text, optional start as date, optional end as date) =>
let
    ColumnNames = {"AuditTrailId", "ModifiedDateTime", "ActionType", "CardId", "MatterNumber", "MatterId", "FirstDescription", "SecondDescription", "CustomDescription", "MatterTypeName", "MatterTypeId", "MatterDeleteCode", "AuditClientCards", "AuditClient", "AddressName", "AddressLevel", "AddressNumber", "AddressStreet", "AddressSuburb", "AddressPostcode", "AddressState", "AddressCountry", "AddressInst", "CardDescription", "ClientDeleteCode", "OldMatterNumber", "OldFirstDescription", "OldSecondDescription", "OldCustomDescription", "OldMatterTypeName", "OldMatterTypeId", "OldMatterDeleteCode", "OldAuditClient", "OldAuditClientCards", "OldAddressName", "OldAddressLevel", "OldAddressNumber", "OldAddressStreet", "OldAddressSuburb", "OldAddressPostcode", "OldAddressState", "OldAddressCountry", "OldAddressInst", "OldCardDescription", "OldClientDeleteCode", "MatterNumberModified", "FirstDescriptionModified", "SecondDescriptionModified", "CustomDescriptionModified", "MatterTypeModified", "MatterClientsModified", "MatterDeletedOrRestored", "ClientAddressModified", "ClientCardAddedModified", "ClientDeletedOrRestored", "CardDescriptionModified", "Type", "Before", "After"},
    Source = LEAP.Feed("TrustAudit", period, start, end),
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if Source = {} or Source = [] then EmptyListHandler else Source,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"AuditTrailId", "ModifiedDateTime", "ActionType", "CardId", "MatterNumber", "MatterId", "FirstDescription", "SecondDescription", "CustomDescription", "MatterTypeName", "MatterTypeId", "MatterDeleteCode", "AuditClientCards", "AuditClient", "AddressName", "AddressLevel", "AddressNumber", "AddressStreet", "AddressSuburb", "AddressPostcode", "AddressState", "AddressCountry", "AddressInst", "CardDescription", "ClientDeleteCode", "OldMatterNumber", "OldFirstDescription", "OldSecondDescription", "OldCustomDescription", "OldMatterTypeName", "OldMatterTypeId", "OldMatterDeleteCode", "OldAuditClient", "OldAuditClientCards", "OldAddressName", "OldAddressLevel", "OldAddressNumber", "OldAddressStreet", "OldAddressSuburb", "OldAddressPostcode", "OldAddressState", "OldAddressCountry", "OldAddressInst", "OldCardDescription", "OldClientDeleteCode", "MatterNumberModified", "FirstDescriptionModified", "SecondDescriptionModified", "CustomDescriptionModified", "MatterTypeModified", "MatterClientsModified", "MatterDeletedOrRestored", "ClientAddressModified", "ClientCardAddedModified", "ClientDeletedOrRestored", "CardDescriptionModified", "Type", "Before", "After"}, {"AuditTrailId", "ModifiedDateTime", "ActionType", "CardId", "MatterNumber", "MatterId", "FirstDescription", "SecondDescription", "CustomDescription", "MatterTypeName", "MatterTypeId", "MatterDeleteCode", "AuditClientCards", "AuditClient", "AddressName", "AddressLevel", "AddressNumber", "AddressStreet", "AddressSuburb", "AddressPostcode", "AddressState", "AddressCountry", "AddressInst", "CardDescription", "ClientDeleteCode", "OldMatterNumber", "OldFirstDescription", "OldSecondDescription", "OldCustomDescription", "OldMatterTypeName", "OldMatterTypeId", "OldMatterDeleteCode", "OldAuditClient", "OldAuditClientCards", "OldAddressName", "OldAddressLevel", "OldAddressNumber", "OldAddressStreet", "OldAddressSuburb", "OldAddressPostcode", "OldAddressState", "OldAddressCountry", "OldAddressInst", "OldCardDescription", "OldClientDeleteCode", "MatterNumberModified", "FirstDescriptionModified", "SecondDescriptionModified", "CustomDescriptionModified", "MatterTypeModified", "MatterClientsModified", "MatterDeletedOrRestored", "ClientAddressModified", "ClientCardAddedModified", "ClientDeletedOrRestored", "CardDescriptionModified", "Type", "Before", "After"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"ModifiedDateTime", type datetime}, {"MatterNumberModified", type logical}, {"FirstDescriptionModified", type logical}, {"SecondDescriptionModified", type logical}, {"CustomDescriptionModified", type logical}, {"MatterTypeModified", type logical}, {"MatterClientsModified", type logical}, {"MatterDeletedOrRestored", type logical}, {"ClientAddressModified", type logical}, {"ClientCardAddedModified", type logical}, {"ClientDeletedOrRestored", type logical}, {"CardDescriptionModified", type logical}})
in
    #"Changed Type";

GetWIPByMatterFeeDetail = () => 
let
    ColumnNames = {"MatterId", "MatterNumber", "MatterDescription", "ClientCardId", "ClientDescription", "StaffActingId", "StaffActing", "StaffResponsibleId", "StaffResponsible", "MatterTypeId", "MatterType", "ReportingGroupId", "ReportingGroup", "AgedWIP"},
    Source = LEAP.Feed("WIPByMatterFee"),
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if Source = {} or Source = [] then EmptyListHandler else Source,
    #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"MatterId", "MatterNumber", "MatterDescription", "ClientCardId", "ClientDescription", "StaffActingId", "StaffActing", "StaffResponsibleId", "StaffResponsible", "MatterTypeId", "MatterType", "ReportingGroupId", "ReportingGroup", "AgedWIP"}, {"MatterId", "MatterNumber", "MatterDescription", "ClientCardId", "ClientDescription", "StaffActingId", "StaffActing", "StaffResponsibleId", "StaffResponsible", "MatterTypeId", "MatterType", "ReportingGroupId", "ReportingGroup", "AgedWIP"}),
    #"Expanded AgedWIP" = Table.ExpandListColumn(#"Expanded Column1", "AgedWIP"),
    #"Expanded AgedWIP1" = Table.ExpandRecordColumn(#"Expanded AgedWIP", "AgedWIP", {"BilledByStaffId", "StaffBilledBy", "BillingMode", "InvoiceStatus", "TotalInctax", "TotalExTax", "CurrentIncTax", "CurrentExTax", "Period1IncTax", "Period1ExTax", "Period2IncTax", "Period2ExTax", "Period3IncTax", "Period3ExTax"}, {"BilledByStaffId", "StaffBilledBy", "BillingMode", "InvoiceStatus", "TotalInctax", "TotalExTax", "CurrentIncTax", "CurrentExTax", "Period1IncTax", "Period1ExTax", "Period2IncTax", "Period2ExTax", "Period3IncTax", "Period3ExTax"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded AgedWIP1",{{"TotalInctax", type number}, {"TotalExTax", type number}, {"CurrentIncTax", type number}, {"CurrentExTax", type number}, {"Period1IncTax", type number}, {"Period1ExTax", type number}, {"Period2IncTax", type number}, {"Period2ExTax", type number}, {"Period3IncTax", type number}, {"Period3ExTax", type number}})
in
    #"Changed Type";

GetControlledMoneyAccountList = () =>
let
    ColumnNames = {"CardId", "MatterNumber", "MatterDescription", "ClientName", "ClientLastName", "AccountName", "AccountBSB", "AccountNumber", "InstituteName", "Balance", "StaffResponsibleId", "StaffActingId", "StaffResponsible", "StaffActing", "AccountBSBAndNumber"},
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    Source = LEAP.Feed("ControlledMoneyAccountList"),
    ListToConvert = if Source[AccountDetails] = {} then EmptyListHandler else Source[AccountDetails],
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"CardId", "MatterNumber", "MatterDescription", "ClientName", "ClientLastName", "AccountName", "AccountBSB", "AccountNumber", "InstituteName", "Balance", "StaffResponsibleId", "StaffActingId", "StaffResponsible", "StaffActing", "AccountBSBAndNumber"}, {"CardId", "MatterNumber", "MatterDescription", "ClientName", "ClientLastName", "AccountName", "AccountBSB", "AccountNumber", "InstituteName", "Balance", "StaffResponsibleId", "StaffActingId", "StaffResponsible", "StaffActing", "AccountBSBAndNumber"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"Balance", type number}})
in
    #"Changed Type";

GetControlledMoneyControlAccount = (period as text, optional start as date, optional end as date) =>
let
    ColumnNames = {"TransactionDate", "EntryDate", "CardId", "MatterId", "MatterNumber", "MatterDescription", "ClientName", "AccountName", "AccountBSB", "AccountNumber", "PayeePayor", "Addressee", "TransactionTypeId", "PaymentTypeId", "AuthorisedByStaffId", "AuthorisedByStaffName", "TransactionNumber", "Reason", "AmountWithdrawal", "AmountDeposit", "Balance", "AbsSeqNum", "TransactionDescription", "AccountDetails"},
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    Source = LEAP.Feed("ControlledMoneyControl"),
    ControlledMoneyAccounts = Source[ControlledMoneyAccounts],
    ListToConvert = if ControlledMoneyAccounts = {} then EmptyListHandler else ControlledMoneyAccounts,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"TransactionDate", "EntryDate", "CardId", "MatterId", "MatterNumber", "MatterDescription", "ClientName", "AccountName", "AccountBSB", "AccountNumber", "PayeePayor", "Addressee", "TransactionTypeId", "PaymentTypeId", "AuthorisedByStaffId", "AuthorisedByStaffName", "TransactionNumber", "Reason", "AmountWithdrawal", "AmountDeposit", "Balance", "AbsSeqNum", "TransactionDescription", "AccountDetails"}, {"TransactionDate", "EntryDate", "CardId", "MatterId", "MatterNumber", "MatterDescription", "ClientName", "AccountName", "AccountBSB", "AccountNumber", "PayeePayor", "Addressee", "TransactionTypeId", "PaymentTypeId", "AuthorisedByStaffId", "AuthorisedByStaffName", "TransactionNumber", "Reason", "AmountWithdrawal", "AmountDeposit", "Balance", "AbsSeqNum", "TransactionDescription", "AccountDetails"})
in
    #"Expanded Column1";

GetFirmReportingGroup = () => 
let
    ColumnNames = {"ReportingGroupId", "ReportingGroup"},
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    Source = LEAP.Feed("FirmReportingGroups"),
    ListToConvert = if Source = {} or Source = [] then EmptyListHandler else Source,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"ReportingGroupId", "ReportingGroup"}, {"ReportingGroupId", "ReportingGroup"})
in
    #"Expanded Column1";

GetMattersDueForSettlement = () =>
let
    ColumnNames = {"SettlementDate", "CoolingOffDate", "SettlementVenue", "MatterId", "MatterNumber", "ClientName", "MatterTypeName", "MatterTypeId", "BuildingName", "UnitShopLevel", "StreetNumber", "StreetName", "Suburb", "State", "Postcode", "PropertyAddress", "StaffResponsible", "StaffActing", "StaffResponsibleId", "StaffActingId", "StaffResponsibleInitials", "StaffActingInitials", "ExchangeDate", "ContractDate"},
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    Source = LEAP.Feed("MattersDueSettlement"),
    ListToConvert = if Source = {} or Source = [] then EmptyListHandler else Source,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"SettlementDate", "CoolingOffDate", "SettlementVenue", "MatterId", "MatterNumber", "ClientName", "MatterTypeName", "MatterTypeId", "BuildingName", "UnitShopLevel", "StreetNumber", "StreetName", "Suburb", "State", "Postcode", "PropertyAddress", "StaffResponsible", "StaffActing", "StaffResponsibleId", "StaffActingId", "StaffResponsibleInitials", "StaffActingInitials", "ExchangeDate", "ContractDate"}, {"SettlementDate", "CoolingOffDate", "SettlementVenue", "MatterId", "MatterNumber", "ClientName", "MatterTypeName", "MatterTypeId", "BuildingName", "UnitShopLevel", "StreetNumber", "StreetName", "Suburb", "State", "Postcode", "PropertyAddress", "StaffResponsible", "StaffActing", "StaffResponsibleId", "StaffActingId", "StaffResponsibleInitials", "StaffActingInitials", "ExchangeDate", "ContractDate"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"SettlementDate", type datetime}, {"CoolingOffDate", type datetime}, {"ExchangeDate", type datetime}, {"ContractDate", type datetime}})
in
    #"Changed Type";

GetMattersOpened = (period as text) =>
let
    ColumnNames = {"MatterId", "MatterNumber", "ClientNameLong", "ClientName", "MatterStatus", "MatterTypeId", "MatterTypeName", "InstructionDate", "ReportingGroupId", "ReportingGroup", "StaffResponsibleId", "StaffActingId", "StaffAssistingId", "StaffCreditId", "StaffResponsible", "StaffActing", "StaffAssisting", "StaffCredit", "FeeEstimate", "CardId", "CardAddress", "CardIds", "CardsDescription", "CostsEstimate"},
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    Source = LEAP.Feed("MattersOpened", period),
    ListToConvert = if Source = {} or Source = [] then EmptyListHandler else Source,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"MatterId", "MatterNumber", "ClientNameLong", "ClientName", "MatterStatus", "MatterTypeId", "MatterTypeName", "InstructionDate", "ReportingGroupId", "ReportingGroup", "StaffResponsibleId", "StaffActingId", "StaffAssistingId", "StaffCreditId", "StaffResponsible", "StaffActing", "StaffAssisting", "StaffCredit", "FeeEstimate", "CardId", "CardAddress", "CardIds", "CardsDescription", "CostsEstimate", "AccidentDates"}, {"MatterId", "MatterNumber", "ClientNameLong", "ClientName", "MatterStatus", "MatterTypeId", "MatterTypeName", "InstructionDate", "ReportingGroupId", "ReportingGroup", "StaffResponsibleId", "StaffActingId", "StaffAssistingId", "StaffCreditId", "StaffResponsible", "StaffActing", "StaffAssisting", "StaffCredit", "FeeEstimate", "CardId", "CardAddress", "CardIds", "CardsDescription", "CostsEstimate", "AccidentDates"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"InstructionDate", type datetime}, {"CostsEstimate", type number}, {"FeeEstimate", type number}}),
    #"Removed Columns" = Table.RemoveColumns(#"Changed Type",{"AccidentDates"}),
    #"Changed Type1" = Table.TransformColumnTypes(#"Removed Columns",{{"InstructionDate", type date}})
in
    #"Changed Type1";

GetTrustInitialisationData = () =>
let
    ColumnNames = {"BankRecStatementDate", "BankAccountGUID", "AccountName", "AccountNumber", "BSB", "NameFileAs", "AccountUsage", "Deleted", "RowVersion", "Drawer", "ChequeSVGLayoutGUID", "ChequeLayoutId", "ChequeMarginV", "ChequeMarginH", "ChequeNumber", "ReceiptNumber", "BankDepositNumber", "JournalNumber", "EFTNumber", "BankRecStatementBalance", "BankCurrentDate", "RapidPayVerificationStatus"},
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    Source = LEAP.Feed("TrustInitialisationData"),
    BankAccounts = Source[BankAccounts],
    ListToConvert = if BankAccounts = {} or BankAccounts = [] then EmptyListHandler else BankAccounts,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"BankRecStatementDate", "BankAccountGUID", "AccountName", "AccountNumber", "BSB", "NameFileAs", "AccountUsage", "Deleted", "RowVersion", "Drawer", "ChequeSVGLayoutGUID", "ChequeLayoutId", "ChequeMarginV", "ChequeMarginH", "ChequeNumber", "ReceiptNumber", "BankDepositNumber", "JournalNumber", "EFTNumber", "BankRecStatementBalance", "BankCurrentDate", "RapidPayVerificationStatus"}, {"BankRecStatementDate", "BankAccountGUID", "AccountName", "AccountNumber", "BSB", "NameFileAs", "AccountUsage", "Deleted", "RowVersion", "Drawer", "ChequeSVGLayoutGUID", "ChequeLayoutId", "ChequeMarginV", "ChequeMarginH", "ChequeNumber", "ReceiptNumber", "BankDepositNumber", "JournalNumber", "EFTNumber", "BankRecStatementBalance", "BankCurrentDate", "RapidPayVerificationStatus"})
in
    #"Expanded Column1";

GetTrustBankRegister = (period as text, optional start as date, optional end as date, optional accountId as text) => 
let
    ColumnNames = {"TransactionGuid", "TransactionDate", "EntryDate", "TransactionNumber", "TransactionNumberPrefixed", "TransactionDetails", "PayeePayor", "Withdrawal", "Deposit", "Balance", "TransactionType", "PaymentTypeId", "PaymentTypeName", "Reason", "ReversalGuid", "AbsSeqNum", "Reconciled", "ReconciledDate", "MatterNumber"},
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    Source = LEAP.Feed("TrustBankRegister", period, start, end, accountId),
    BankRegisterItems = Source[BankRegisterItems],
    ListToConvert = if BankRegisterItems = {} or BankRegisterItems = [] then EmptyListHandler else BankRegisterItems,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"TransactionGuid", "TransactionDate", "EntryDate", "TransactionNumber", "TransactionNumberPrefixed", "TransactionDetails", "PayeePayor", "Withdrawal", "Deposit", "Balance", "TransactionType", "PaymentTypeId", "PaymentTypeName", "Reason", "ReversalGuid", "AbsSeqNum", "Reconciled", "ReconciledDate", "MatterNumber"}, {"TransactionGuid", "TransactionDate", "EntryDate", "TransactionNumber", "TransactionNumberPrefixed", "TransactionDetails", "PayeePayor", "Withdrawal", "Deposit", "Balance", "TransactionType", "PaymentTypeId", "PaymentTypeName", "Reason", "ReversalGuid", "AbsSeqNum", "Reconciled", "ReconciledDate", "MatterNumber"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"TransactionDate", type datetime}, {"EntryDate", type datetime}, {"Withdrawal", type number}, {"Deposit", type number}, {"Balance", type number}, {"Reconciled", type logical}})
in
    #"Changed Type";

GetBillableByStaff = (list) => 
let
    ColumnNames = {"StaffId", "StaffName", "Monday_IncTax", "Tuesday_IncTax", "Wednesday_IncTax", "Thursday_IncTax", "Friday_IncTax", "Saturday_IncTax", "Sunday_IncTax", "Monday_ExTax", "Tuesday_ExTax", "Wednesday_ExTax", "Thursday_ExTax", "Friday_ExTax", "Saturday_ExTax", "Sunday_ExTax", "Total_IncTax", "Total_ExTax"},
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if list = {} or list = [] then EmptyListHandler else list,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"StaffId", "StaffName", "Monday_IncTax", "Tuesday_IncTax", "Wednesday_IncTax", "Thursday_IncTax", "Friday_IncTax", "Saturday_IncTax", "Sunday_IncTax", "Monday_ExTax", "Tuesday_ExTax", "Wednesday_ExTax", "Thursday_ExTax", "Friday_ExTax", "Saturday_ExTax", "Sunday_ExTax", "Total_IncTax", "Total_ExTax"}, {"StaffId", "StaffName", "Monday_IncTax", "Tuesday_IncTax", "Wednesday_IncTax", "Thursday_IncTax", "Friday_IncTax", "Saturday_IncTax", "Sunday_IncTax", "Monday_ExTax", "Tuesday_ExTax", "Wednesday_ExTax", "Thursday_ExTax", "Friday_ExTax", "Saturday_ExTax", "Sunday_ExTax", "Total_IncTax", "Total_ExTax"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"Monday_IncTax", type number}, {"Tuesday_IncTax", type number}, {"Wednesday_IncTax", type number}, {"Thursday_IncTax", type number}, {"Friday_IncTax", type number}, {"Saturday_IncTax", type number}, {"Sunday_IncTax", type number}, {"Monday_ExTax", type number}, {"Tuesday_ExTax", type number}, {"Wednesday_ExTax", type number}, {"Thursday_ExTax", type number}, {"Friday_ExTax", type number}, {"Saturday_ExTax", type number}, {"Sunday_ExTax", type number}, {"Total_IncTax", type number}, {"Total_ExTax", type number}})
in
    #"Changed Type";

GetBillableHoursByStaff = (list) => 
let
    ColumnNames = {"StaffId", "StaffName", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday", "Total"},
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if list = {} or list = [] then EmptyListHandler else list,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"StaffId", "StaffName", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday", "Total"}, {"StaffId", "StaffName", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday", "Total"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"Monday", type number}, {"Tuesday", type number}, {"Wednesday", type number}, {"Thursday", type number}, {"Friday", type number}, {"Saturday", type number}, {"Sunday", type number}, {"Total", type number}})
in
    #"Changed Type";

GetTimeAndFeeFinancialsByStaff = (list) => 
let
    ColumnNames = {"StaffId", "StaffName", "Billable_MTD_IncTax", "Billable_MTD_ExTax", "Billable_FYTD_IncTax", "Billable_FYTD_ExTax", "NonBillable_MTD_Inctax", "NonBillable_MTD_ExTax", "NonBillable_FYTD_IncTax", "NonBillable_FYTD_ExTax"},
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if list = {} or list = [] then EmptyListHandler else list,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"StaffId", "StaffName", "Billable_MTD_IncTax", "Billable_MTD_ExTax", "Billable_FYTD_IncTax", "Billable_FYTD_ExTax", "NonBillable_MTD_Inctax", "NonBillable_MTD_ExTax", "NonBillable_FYTD_IncTax", "NonBillable_FYTD_ExTax"}, {"StaffId", "StaffName", "Billable_MTD_IncTax", "Billable_MTD_ExTax", "Billable_FYTD_IncTax", "Billable_FYTD_ExTax", "NonBillable_MTD_Inctax", "NonBillable_MTD_ExTax", "NonBillable_FYTD_IncTax", "NonBillable_FYTD_ExTax"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"Billable_MTD_IncTax", type number}, {"Billable_MTD_ExTax", type number}, {"Billable_FYTD_IncTax", type number}, {"Billable_FYTD_ExTax", type number}, {"NonBillable_MTD_ExTax", type number}, {"NonBillable_MTD_Inctax", type number}, {"NonBillable_FYTD_IncTax", type number}, {"NonBillable_FYTD_ExTax", type number}})
in
    #"Changed Type";

GetTimeAndFeeHoursByStaff = (list) => 
let
    ColumnNames = {"StaffId", "StaffName", "Billable_MTD", "Billable_FYTD", "NonBillable_MTD", "NonBillable_FYTD"},
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if list = {} or list = [] then EmptyListHandler else list,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"StaffId", "StaffName", "Billable_MTD", "Billable_FYTD", "NonBillable_MTD", "NonBillable_FYTD"}, {"StaffId", "StaffName", "Billable_MTD", "Billable_FYTD", "NonBillable_MTD", "NonBillable_FYTD"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"Billable_MTD", type number}, {"Billable_FYTD", type number}, {"NonBillable_MTD", type number}, {"NonBillable_FYTD", type number}})
in
    #"Changed Type";

GetWeeklyTimeAndFeeByStaff = () =>
let
    Source = LEAP.Feed("WeeklyTime")
in
    Source;

GetWeeklyTimeAndFeeHoursByStaff = () =>
let
    Source = LEAP.Feed("WeeklyHour")
in
    Source;

GetFeeContributionsAndRecovery = (period as text, optional start as date, optional end as date) =>
let
    ColumnNames = {"MatterId", "MatterNumber", "ClientName", "StaffResponsibleId", "StaffResponsible", "StaffActingId", "StaffActing", "StaffAssistingId", "StaffAssisting", "StaffCreditId", "StaffCredit", "StaffId", "StaffName", "ReportingGroupId", "ReportingGroup", "MatterTypeId", "MatterType", "FeeRecordedExTax", "FeeRecordedIncTax", "FeeNonBillableExTax", "FeeNonBillableIncTax", "BilledExTax", "BilledIncTax", "InvoiceExTax", "InvoiceIncTax", "AdjustmentExTax", "AdjustmentIncTax", "ReceiptedExTax", "ReceiptedIncTax", "LastFeeDate", "LastInvoiceDate", "LastReceiptDate"},
    Source = LEAP.Feed("FeeContributionsRecovery", period, start, end),
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if Source = {} or Source = [] then EmptyListHandler else Source,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"MatterId", "MatterNumber", "ClientName", "StaffResponsibleId", "StaffResponsible", "StaffActingId", "StaffActing", "StaffAssistingId", "StaffAssisting", "StaffCreditId", "StaffCredit", "StaffId", "StaffName", "ReportingGroupId", "ReportingGroup", "MatterTypeId", "MatterType", "FeeRecordedExTax", "FeeRecordedIncTax", "FeeNonBillableExTax", "FeeNonBillableIncTax", "BilledExTax", "BilledIncTax", "InvoiceExTax", "InvoiceIncTax", "AdjustmentExTax", "AdjustmentIncTax", "ReceiptedExTax", "ReceiptedIncTax", "LastFeeDate", "LastInvoiceDate", "LastReceiptDate"}, {"MatterId", "MatterNumber", "ClientName", "StaffResponsibleId", "StaffResponsible", "StaffActingId", "StaffActing", "StaffAssistingId", "StaffAssisting", "StaffCreditId", "StaffCredit", "StaffId", "StaffName", "ReportingGroupId", "ReportingGroup", "MatterTypeId", "MatterType", "FeeRecordedExTax", "FeeRecordedIncTax", "FeeNonBillableExTax", "FeeNonBillableIncTax", "BilledExTax", "BilledIncTax", "InvoiceExTax", "InvoiceIncTax", "AdjustmentExTax", "AdjustmentIncTax", "ReceiptedExTax", "ReceiptedIncTax", "LastFeeDate", "LastInvoiceDate", "LastReceiptDate"}),
    #"Change Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"FeeRecordedExTax", type number}, {"FeeRecordedIncTax", type number}, {"FeeNonBillableExTax", type number}, {"FeeNonBillableIncTax", type number}, {"BilledExTax", type number}, {"BilledIncTax", type number}, {"InvoiceExTax", type number}, {"InvoiceIncTax", type number}, {"AdjustmentExTax", type number}, {"AdjustmentIncTax", type number}, {"ReceiptedExTax", type number}, {"ReceiptedIncTax", type number}})
in
     #"Change Type";

GetInactiveMatters = () => 
let
    ColumnNames = {"MatterId", "ClientName", "MatterTypeId", "MatterType", "MatterStatus", "MatterNumber", "StaffResponsibleId", "StaffResponsibleInitials", "StaffResponsibleName", "StaffActingId", "StaffActingInitials", "StaffActingName", "DocumentModifiedDate", "MatterModifiedDate", "TimeandFeeModifiedDate", "ReportingGroupId", "ReportingGroup"},
    Source = LEAP.Feed("InactiveMatters"),
    InactiveMattersList = Source[InactiveMattersList],
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if InactiveMattersList = {} or InactiveMattersList = [] then EmptyListHandler else InactiveMattersList,
    #"Converted to Table" = Table.FromList(InactiveMattersList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"MatterId", "ClientName", "MatterTypeId", "MatterType", "MatterStatus", "MatterNumber", "StaffResponsibleId", "StaffResponsibleInitials", "StaffResponsibleName", "StaffActingId", "StaffActingInitials", "StaffActingName", "DocumentModifiedDate", "MatterModifiedDate", "TimeandFeeModifiedDate", "ReportingGroupId", "ReportingGroup"}, {"MatterId", "ClientName", "MatterTypeId", "MatterType", "MatterStatus", "MatterNumber", "StaffResponsibleId", "StaffResponsibleInitials", "StaffResponsibleName", "StaffActingId", "StaffActingInitials", "StaffActingName", "DocumentModifiedDate", "MatterModifiedDate", "TimeandFeeModifiedDate", "ReportingGroupId", "ReportingGroup"}),
    #"Conversion" = Table.TransformColumns(#"Expanded Column1",{{"DocumentModifiedDate", DateTimeZone.FromText}}),
     #"Changed Type" = Table.TransformColumnTypes(#"Conversion",{{"TimeandFeeModifiedDate", type datetime}, {"MatterModifiedDate", type datetime}, {"DocumentModifiedDate", type datetimezone}})
in
    #"Changed Type";

GetAccounts = () =>
let
    Source = LEAP.Feed("Accounts"),
    #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"BankAccount", "BankAccountSequences"}, {"BankAccount", "BankAccountSequences"}),
    #"Expanded BankAccount" = Table.ExpandRecordColumn(#"Expanded Column1", "BankAccount", {"BankAccountId", "AccountName", "AccountNumber", "AccountBSB", "AccountUsage", "GLAccountCode", "CountryCode", "StateCode", "ChequeLayoutID", "ChequeMarginH", "ChequeMarginV", "ChequeSVGLayoutId", "Deleted", "Archived", "InvestMatterId", "CreatedByStaffId", "CreatedDTS", "ModifiedByStaffId", "ModifiedDTS", "AccountClosed", "DateOpened", "InstituteName", "NameFileAs", "ExternalCodeUniqie", "ImportedFrom", "Description", "PMOpeningBalance", "PMOpeningBalanceUnknown", "ExternalURL", "ExternalJSON", "IsMaqAccount", "Drawer", "IPBankAccountNumber", "ProductControlID", "RPBankFeedsEnabled", "RPEnabled", "RPVerificationStatus", "RowVersion"}, {"BankAccountId", "AccountName", "AccountNumber", "AccountBSB", "AccountUsage", "GLAccountCode", "CountryCode", "StateCode", "ChequeLayoutID", "ChequeMarginH", "ChequeMarginV", "ChequeSVGLayoutId", "Deleted", "Archived", "InvestMatterId", "CreatedByStaffId", "CreatedDTS", "ModifiedByStaffId", "ModifiedDTS", "AccountClosed", "DateOpened", "InstituteName", "NameFileAs", "ExternalCodeUniqie", "ImportedFrom", "Description", "PMOpeningBalance", "PMOpeningBalanceUnknown", "ExternalURL", "ExternalJSON", "IsMaqAccount", "Drawer", "IPBankAccountNumber", "ProductControlID", "RPBankFeedsEnabled", "RPEnabled", "RPVerificationStatus", "RowVersion"})
in
    #"Expanded BankAccount";

GetTaskCodesFees = () =>
let
    ColumnNames = {"TaskCodeId", "TaxCodeId", "NameFileAs", "BillingDescription", "GroupOnInvoice", "Deleted", "AmountRate", "IncTax", "RateId", "Timed", "CalculationMode", "CalculationScript", "RowVersion", "BillingMode"}, 
    Source = LEAP.Feed("TaskCodesFees"),
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if Source = {} or Source = [] then EmptyListHandler else Source,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", ColumnNames,ColumnNames)
    
in
    #"Expanded Column1";

GetTaskCodesCostRecovery = () =>
let
    ColumnNames = {"TaskCodeId", "PurchaseSupplierCardId", "TaxCodeId", "PurchaseMode", "Deleted", "NameFileAs", "BillingDescription", "IncTax", "AmountEach", "GroupOnInvoice", "RowVersion"},
    Source = LEAP.Feed("TaskCodesCostRecovery"),
    EmptyListHandler = { Record.FromList ( List.Repeat ( { "" }, List.Count ( ColumnNames ) ), ColumnNames ) },
    ListToConvert = if Source = {} or Source = [] then EmptyListHandler else Source,
    #"Converted to Table" = Table.FromList(ListToConvert, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", ColumnNames,ColumnNames)
    
in
    #"Expanded Column1";

GetBillingModeTable = () =>
let
    billingModes = {
        [BillingMode = 0, BillingModeDescription = "Billable - Next Invoice"],
        [BillingMode = 1, BillingModeDescription = "Billable - Later Invoice"],
        [BillingMode = -1, BillingModeDescription = "Not Billable / Written Off"]
    },
    billingModeTable = Table.FromRecords(billingModes)
in
    billingModeTable;

GetInvoiceStatusTable = () =>
let
    InvoiceStatuses = {
        [InvoiceStatus = 0, InvoiceStatusDescription = "Draft - Unapproved"],
        [InvoiceStatus = 1, InvoiceStatusDescription = "Draft - Approved"],
        [InvoiceStatus = 3, InvoiceStatusDescription = "Final"]
    },
    invoiceStatusesTable = Table.FromRecords(InvoiceStatuses)
in
    invoiceStatusesTable;

// Return request body containing date ranges for POST requests
GetQueryString = (variant, optional period as text, optional start as date, optional end as date, optional accountId as text) => 
    let 
        Current = Date.ToText(DateTime.Date(DateTime.LocalNow()), "yyyy-MM-ddThh:MM:ss.sssZ"),
        LastWeek = Date.ToText(Date.AddWeeks(DateTime.Date(DateTime.LocalNow()), -1), "yyyy-MM-ddThh:MM:ss.sssZ"),
        LastMonth = Date.ToText(Date.AddMonths(DateTime.Date(DateTime.LocalNow()), -1), "yyyy-MM-ddThh:MM:ss.sssZ"),
        LastThreeMonths = Date.ToText(Date.AddMonths(DateTime.Date(DateTime.LocalNow()), -3), "yyyy-MM-ddThh:MM:ss.sssZ"),
        NextThreeMonths = Date.ToText(Date.AddMonths(DateTime.Date(DateTime.LocalNow()), 3), "yyyy-MM-ddThh:MM:ss.sssZ"),
        LastYear = Date.ToText(Date.AddYears(DateTime.Date(DateTime.LocalNow()), -1), "yyyy-MM-ddThh:MM:ss.sssZ"),
        CurrentFY = Date.ToText(Date.AddYears(DateTime.Date(DateTime.LocalNow()), -1), "yyyy-MM-ddThh:MM:ss.sssZ"),
        PreviousStartCY = Date.ToText(Date.StartOfYear(Date.AddYears(DateTime.Date(DateTime.LocalNow()), -1)), "yyyy-MM-ddThh:MM:ss.sssZ"),
        PreviousEndCY = Date.ToText(Date.EndOfYear(Date.AddYears(DateTime.Date(DateTime.LocalNow()), -1)), "yyyy-MM-ddThh:MM:ss.sssZ"),
        CurrentStartCY = Date.ToText(Date.StartOfYear(DateTime.Date(DateTime.LocalNow())), "yyyy-MM-ddThh:MM:ss.sssZ"),
        CurrentEndCY = Date.ToText(Date.EndOfYear(DateTime.Date(DateTime.LocalNow())), "yyyy-MM-ddThh:MM:ss.sssZ"),
        CurrentMonthStart = Date.ToText(Date.StartOfMonth(DateTime.Date(DateTime.LocalNow())), "yyyy-MM-ddThh:MM:ss.sssZ"),
        LastMonthStart = Date.ToText(Date.StartOfMonth(Date.AddMonths(DateTime.Date(DateTime.LocalNow()), -1)), "yyyy-MM-ddThh:MM:ss.sssZ"),
        CurrentMonthEnd = Date.ToText(Date.EndOfMonth(DateTime.Date(DateTime.LocalNow())), "yyyy-MM-ddThh:MM:ss.sssZ"),
        StartOfWeek = Date.ToText(DateTime.Date(Date.StartOfWeek(DateTime.LocalNow(), Day.Monday)), "yyyy-MM-ddThh:MM:ss.sssZ"),
        FromDate = if period = "M" then LastThreeMonths
                   else if period = "CM" then CurrentMonthStart
                   else if period = "PM" then LastMonthStart
                   else if period = "W" then LastWeek
                   else if period = "Y" then LastYear
                   else if period = "PY" then PreviousStartCY
                   else if period = "CY" then CurrentStartCY
                   else if period = "FM" then Current
                   else if start <> null then Date.ToText(start, "yyyy-MM-dd")
                   else if variant = "CriticalDates" then LastMonth
                   else LastThreeMonths,
        ToDate =   if end <> null then Date.ToText(end, "yyyy-MM-dd")
                   else if period = "PY" then PreviousEndCY
                   else if period = "CY" then CurrentEndCY
                   else if period = "CM" then CurrentMonthEnd
                   else if variant = "StaffBudgets" or variant = "CriticalDates" or variant = "MattersDueSettlement" then NextThreeMonths
                   else Current,
        AtDateValue = if variant = "WeeklyTime" or variant = "WeeklyHour" then StartOfWeek else Current,
        To = Json.FromValue([AtDate = AtDateValue]),
        DateRange = Json.FromValue([DateRange = [To = ToDate, From = FromDate]]),
        BankDateRange = Json.FromValue([BankAccountId = accountId, DateRange = [To = ToDate, From = FromDate]]),
        result = if variant = "TrustBankRegister" then BankDateRange
                 else if variant = "WIPByMatterFee" or variant = "AgeingBalances" or variant = "AgedWIP" or variant = "WIPByMatter" or variant = "AgedDisbursements" 
                 or variant = "InactiveMatters" or variant = "AgedDebtors" or variant = "" or variant = "ControlledMoneyAccountList" or variant = "Balances" or variant = "ArchivedBalances" or variant = "WeeklyTime"  or variant = "WeeklyHour"  then To 
                 else DateRange
    in
        result;

// Return portion of url that requires date parameters in the path
GetDatePath = (path as text, period as text, optional start as date, optional end as date) => 
    let
        Current = Date.ToText(DateTime.Date(DateTime.LocalNow()), "yyyy-MM-dd"),
        LastThreeMonths = Date.ToText(Date.AddMonths(DateTime.Date(DateTime.LocalNow()), -3), "yyyy-MM-dd"),
        FutureMonth = Date.ToText(Date.AddMonths(DateTime.Date(DateTime.LocalNow()), 1), "yyyy-MM-dd"),
        LastYear = Date.ToText(Date.AddYears(DateTime.Date(DateTime.LocalNow()), -1), "yyyy-MM-dd"),
        CurrentFY = Date.ToText(Date.AddYears(DateTime.Date(DateTime.LocalNow()), -1), "yyyy-MM-dd"),
        StartDate = if period = "M" then LastThreeMonths
                   else if period = "FM" then Current
                   else if period = "Y" then LastYear
                   else if start <> null then Date.ToText(start, "yyyy-MM-dd")
                   else LastThreeMonths,
        EndDate = if period = "F" then ""
                  else if end <> null then Date.ToText(end, "yyyy-MM-dd")
                  else Current,
        Path = if path = "CriticalDates" then Text.Combine({"/", StartDate , "/", FutureMonth})
               else ""
    in
        Path;

// Returns the baseUrl according to the countryCode claims data in the access_token
ReturnBaseUrl = (countryCode, environment) =>
    let
        baseUrl = if countryCode = 0 and environment = "liveb" then "https://au-liveb-api.leap.services" 
            else if countryCode = 0 or countryCode = 5 then "https://au-api.leap.services"
            else if countryCode = 3 then "https://ca-api.leap.services"
            else if countryCode = 1 or countryCode = 4 then "https://uk-api.leap.services"
            else if countryCode = 2 then "httpS://us-api.leap.services"
            else ""
    in
        baseUrl;

// Returns the options baseUrl according to the countryCode claims data in the access_token
ReturnOptionsUrl = (countryCode, environment) =>
    let
        baseUrl = if countryCode = 0 and environment = "liveb" then au_liveb_options_url
            else if countryCode = 0 or countryCode = 5 then au_options_url
            else if countryCode = 3 then ca_options_url
            else if countryCode = 1 or countryCode = 4 then uk_options_url
            else if countryCode = 2 then us_options_url
            else ""
    in
        baseUrl;

// Return localized 'Office' Section Name (per reporting section)
// US: Trust/Operating Account/Management - AU: Trust/Office/Management - CA: Trust/General Account/Management -NZ: Trust/Office/Management -UK: Client Funds/Office/Management
GetOfficeAlias = (countryCode) => 
    let
        name = if countryCode = 2 then "Operating Account"
        else if countryCode = 3 then "General Account"
        else "Office"
    in
        name;

// Return localized 'Trust' Name
GetLocalTrustName = (countryCode) =>  
    let
        name = if countryCode = 1 then "Client"
            else "Trust"
    in
        name;

// Return localized 'Controlled Money' Name
GetLocalControlledMoneyName = (countryCode) =>
    let
        name = if countryCode = 0 then "Controlled Money"
             else if countryCode = 2 or countryCode = 3 then "Separate Interest Bearing"
             else if countryCode = 1 or countryCode = 4 then "Separate Designated Client"
             else if countryCode = 5 then "Interest Bearing Deposit"
             else "Controlled Money"
    in
        name;

// Return localized 'Cost Recovery' Name //AU/NZ/IE/UK?: "Cost Recovery" US: "Expense Recovery"
GetLocalCostRecoveryName = (countryCode) =>
    let
        name = if countryCode = 2 or countryCode = 3 then "Expense Recovery"
             else "Cost Recovery"
    in
        name;


// Return localized 'Settlement' Name
GetLocalSettlementName = (countryCode) =>
    let
        key = if countryCode = 2 or countryCode = 3 then "Closing"
             else if countryCode = 1 or countryCode = 4 then "Completion"
             else "Settlement"
    in
        key;

// Return localized 'Debtors' Name
GetLocalDebtorsName = (countryCode) =>
    let
        key = if countryCode = 2 or countryCode = 3 then "Accounts Receivables"
              else "Aged Debtors"
    in
        key;

// Return localized 'Disbursements' Name
GetLocalDisbursementName = (countryCode) =>
    let
        key = if countryCode = 2 then "Expenses"
              else "Disbursements"
    in
        key;

// Return countryCode claims from access_token
GetRegionFromToken = (token) =>
    let
        parts = Json.Document(Base64Url.Decode(Text.Split(token, "."){1})),
        region = parts[countryCode]
    in
        region;

// Custom Date Range function type to provide additional context to user when using the function in Power BI
CustomDateRangeType = type function (
    endpoint as (type text meta [
        Documentation.FieldCaption = "LEAP: Endpoint",
        Documentation.FieldDescription = "Specifies the endpoint from LEAP to query.",
        Documentation.AllowedValues = {"OfficeInvoices", "OfficeReceipts", "StaffInvoicedFunds", "StaffReceiptedFunds", "CriticalDates", "TimeAndFees", "StaffBudgets", "DisbursementListing", "MattersOpened", "InvoiceAdjustments", "MattersDueSettlement"}
    ]),
    optional start as (type date meta [
        Documentation.FieldCaption = "Start Date",
        Documentation.FieldDescription = "Starting date parameter to query LEAP."
    ]),
    optional end as (type date meta [
        Documentation.FieldCaption = "End Date",
        Documentation.FieldDescription = "End date parameter to query LEAP."
    ]))
    as table meta [
        Documentation.Name = "LEAP: Custom Date Range",
        Documentation.LongDescription = "This function will allow you to retrieve data from the available endpoints in the dropdown list with a date range that you have specified.",
        Documentation.Examples = {[
            Description = "Returns a list of items according to the provided date range.",
            Code = "CDR(""OfficeInvoices"", #date(2021, 1, 1), #date(2022, 4, 1))"
        ]}
    ];

// Implementation of Custom Date Range function and underlying initialising call to LEAP.Feed
CustomDateRangeImpl = (endpoint as text, optional start as date, optional end as date) as table =>
    let
        table = ExecuteSubNav(endpoint, "", start, end)
    in
        table;

// Helper function to create navigation tables
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

// To prevent invalid parameters error when navigation table renders the Custom Date Range function
Table.ToDelayedNavigationTable = (
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

// Helper function to allow for Web.Content calls to be retried.
Value.WaitFor = (producer as function, interval as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, null},
            (state) => state{0} <> null and (count = null or state{0} < count),
            (state) => if state{1} <> null then {null, state{1}} else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), interval(state{0}))},
            (state) => state{1})
    in
        List.Last(list);

// Generate S256 Encoded code_verifier
S256.Encode = (s) => Binary.ToText(Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(s, TextEncoding.Ascii)), BinaryEncoding.Base64);

// Function to Decode
Base64Url.Decode = (s) => Binary.FromText(Text.Replace(Text.Replace(s, "-", "+"), "_", "/") & {"", "", "==", "="}{Number.Mod(Text.Length(s), 4)}, BinaryEncoding.Base64);

// *********************** IMPORTING OTHER MODULES ***********************

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
Diagnostics.LogValue = Diagnostics[LogValue];
Diagnostics.LogFailure = Diagnostics[LogFailure];