///**** The Azure Cost Management connector allows PowerBI users to create flexible reports and get actionable insights into their Azure
///**** billing and usage data ***/
[Version = "1.0.41"]
section AzureCostManagement;

/// Note: constants declarations starts here
redirectUri = "https://preview.powerbi.com/views/oauthredirect.html";
authorization_extension = "common/oauth2/authorize";
discoverTenantsUri = "/providers/Microsoft.Consumption/tenants?api-Version=2018-10-01";
providerBillingAccount = "providers/Microsoft.Billing/billingAccounts/";
/// client Id for first party AAD. This ID we are using for PowerBI authentication flow.
client_id = "a672d62c-fc7b-4e81-a576-e60dc46e951d";
/// Note: this is a default billingAccountId for lower environment. This code will get deleted in Prod.
defaultBillingAccountId = "00000000-0000-0000-0000-000000000000";
billingAccountIndex = 3;
billingProfileIndex = 5;
reportStatusPullingInterval = #duration(0, 0, 0, 1);
apiCallTimeout = #duration(0, 0, 5, 0);
defaultMonthNumber = "3";
/// post report parameters
postReport_reportType = "Details";
postReport_format = "PagedCsv";
culture = "en-US";
defaultRowCount = "100000";
contentPackApiPrefix = "";
postReport_pageSize = 5000;
postReport_normalized = true;

// All the supported version by this connector for various apis
billingRpTransactionsApiVersion = "2019-10-01-preview";
supportedAPIVersion = "2019-05-01";
latestApiVersion = "2019-10-01";
novApiVersion = "2019-11-01";
budgetApiVersion = "2021-10-01";
priceSheetApiVersion = "2022-06-01";

/// Note: to get client type
client_type =  "PowerBIConnector2.0";
///Note: billing profile scope
billingProfileScope = "billingProfile";
///Note: billing account scope
billingAccountScope = "billingAccount";
///Note: enrollment number scope
enrollmentScope = "enrollment";
///Note: application type legacy
appTypeLegacy = "legacy";
///Note: application type modern
appTypeModern = "modern";
/// GTM Pricesheet api (apiVersion=2022-04-01 onwards) needs a new extra RP scope information in the url and this is a helper for it
costmanagementProviderUriPart = "/providers/Microsoft.CostManagement";


//baseUri = "https://management.azure.com/";
GetBaseUri=() as text =>
    let
       baseUri = Uri.Combine(Environment.FeatureSwitch("AzureResourceManagerUri", "https://management.azure.com/"), "/")
    in
       baseUri;

/// billingAccountUri = "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/"
GetBillingAccountUri = () as text =>
    let
        billingAccountUri = GetBaseUri() & contentPackApiPrefix & providerBillingAccount
    in
        billingAccountUri;

//tenantDiscoveryUri = "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/";
GetTenantDiscoveryUri=() as text =>
    let
        tenantDiscoveryUri = Uri.Combine(Environment.FeatureSwitch("AzureResourceManagerUri", "https://management.azure.com/"), "/"),
        endpointUri = Uri.Combine(tenantDiscoveryUri, "providers/Microsoft.Billing/billingAccounts/")
    in
        endpointUri;

//resourceUri = "https://management.core.windows.net/";
GetResourceUri= () as text =>
    let
        resourceUri = Uri.Combine(Environment.FeatureSwitch("AzureResourceManagerAadResource", "https://management.core.windows.net/"), "/")
    in
        resourceUri;

//authorizationUri = "https://login.windows.net/";
GetAuthorizationUri= () as text =>
    let
        authorizationUri = Uri.Combine(Environment.FeatureSwitch("AzureActiveDirectoryUri", "https://login.microsoftonline.com/"), "/"),
        endpointUri =   Uri.Combine(authorizationUri, authorization_extension)
    in
        endpointUri;


[DataSource.Kind = "AzureCostManagement"]
shared AzureCostManagement.Contents = Value.ReplaceType(AzureCostManagement.ContentsInternal, AzureCostManagement.ContentsType);

[DataSource.Kind = "AzureCostManagement", Publish = "AzureCostManagement.Publish"]
shared AzureCostManagement.Tables = Value.ReplaceType(AzureCostManagement.TablesInternal, AzureCostManagement.TablesType);

/// Note: AzureCostManagement publish section
AzureCostManagement.Publish = [
    Category = "Azure",
    ButtonText = {Extension.LoadString("AzureCostManagement"), Extension.LoadString("AzureCostManagement")},
    SourceImage = AzureCostManagement.Icons,
    SourceTypeImage = AzureCostManagement.Icons
];

/// Note: AzureCostManagement publish Icons
AzureCostManagement.Icons = [
     Icon16 = {Extension.Contents("16.png"), Extension.Contents("20.png"), Extension.Contents("24.png"), Extension.Contents("32.png")},
     Icon32 = {Extension.Contents("32.png"), Extension.Contents("40.png"), Extension.Contents("48.png"), Extension.Contents("64.png")}
];

/// Note: Request header containing appType value as "legacy"
legacyRequestHeader = [
    #"x-ms-client-request-id" = GetClientActivityId(),
    #"Content-Type" = "application/json; charset=utf-8",
    FromExtension = "true",
    ClientType = client_type,
    AppType = appTypeLegacy,
    ClientVersion = "1.0",              // we only support V 1.0
    PagedStreamingEnabled = "true"
];

/// Note: Request header containing appType value as "modern"
modernRequestHeader = [
    #"x-ms-client-request-id" = GetClientActivityId(),
    #"Content-Type" = "application/json; charset=utf-8",
    FromExtension = "true",
    ClientType = client_type,
    AppType = appTypeModern,
    ClientVersion = "1.0",              // we only support V 1.0
    PagedStreamingEnabled = "true"
];

/// Note: Authentication handling
AzureCostManagement = [
    Type = "Custom",
    MakeResourcePath = (scope, scopeValue) => scope & ";" & scopeValue,
    ParseResourcePath = (resource) => Text.Split(resource, ";"),
    TestConnection = (resource) =>
        let
            split = Text.Split(resource, ";"),
            scope = split{0},
            scopeValue = split{1}
        in
            if (List.Count(split) <> 2)
                then error "Unexpected data source path value."
            else
                { "AzureCostManagement.Tables", scope, scopeValue, 1, [apiType = "balancesummary", connectionType = "Test"] },

    Authentication = [
        Aad = [
            AuthorizationUri = GetAuthorizationUri(),
            Resource = GetResourceUri(),
            DefaultClientApplication = [
                ClientId = client_id,
                ClientSecret = "",
                CallbackUrl =  redirectUri
            ]
        ]
    ],
    Label = Extension.LoadString("AzureCostManagement")
];

GetWebContents = (url as text, optional apptype as text, optional isRetry as logical, optional contentParameter) =>
 Extension.InvokeWithCredentials(
        (datasource) => if (datasource[DataSource.Kind] = "AzureBlobs") then [ AuthenticationKind = "Anonymous" ] else Extension.CurrentCredential(),
        () =>
        let
            // Manual Status handling error codes should match the result condition so that delayed retry can happen on the mentioned error codes.
            waitForResult = Value.WaitFor(
                (iteration) =>
            let
                header = if apptype = appTypeLegacy then legacyRequestHeader else modernRequestHeader,
                response = Web.Contents(url, [IsRetry = (isRetry = true or iteration > 0), Timeout = apiCallTimeout, Content = contentParameter, Headers = header, ManualStatusHandling = {500, 502, 503, 504}]),
                status = Value.Metadata(response)[Response.Status],
                result = if status = 500 or status = 502 or status = 503 or status = 504 then null else response
            in
                result,
                (iteration) => #duration(0, 0, (2 * iteration), 0), 2)
        in
            waitForResult
 );

/// Note: For Power BI Content Pack
AzureCostManagement.ContentsInternal = (scope as text, scopeValue as text, numberOfMonths as number, optional parameters as record) =>
    let
        /// Note: this scope is taken from connector resource path.
        billingProfileId = if scope = "Billing Profile Id" then Text.From(scopeValue) else "",
        enrollmentNumber = if scope = "Enrollment Number" then Text.From(scopeValue) else "",
        apiVersion = if parameters <> null and Record.HasFields(parameters, "apiVersion") then parameters[apiVersion] else "",
        lookBackPeriod = if parameters <> null and Record.HasFields(parameters, "lookBackPeriod") then parameters[lookBackPeriod] else 30,
        dateParameters = GetDateParameters(parameters, numberOfMonths),
        apiType = if parameters <> null and Record.HasFields(parameters, "apiType") then parameters[apiType] else "Charges",

        result = if billingProfileId <> "" then
                    ContentsInternalOnGTMScope(billingProfileId, apiVersion, lookBackPeriod, dateParameters, apiType, parameters)
                else
                    ContentsInternalOnEnrollmentScope(enrollmentNumber, apiVersion, lookBackPeriod, dateParameters, apiType, parameters)
    in
        result meta [version = "4.0"];

/// Note: For content pack scenario by GTM scope
ContentsInternalOnGTMScope = (billingProfileId as text, apiVersion as text, lookBackPeriod as number, dateParameters as record, apiType as text, optional parameters as record) =>
    let
        scope = billingProfileScope,
        requiredFieldMsg = if(billingProfileId = null) then "Required Field: " & Extension.LoadString("BillingProfileIdRequired") else "",
        connectionType = if parameters <> null and Record.HasFields(parameters, "connectionType") then parameters[connectionType] else "Prod",

        ///Note: to get tenant and billing profile.
        tenantObj = GetInfoByProfileId(billingProfileId),
        billingAccountId = try tenantObj[billingAccountId] otherwise null,
        errorMsgTenants = if(billingAccountId = null or billingAccountId = "") then "Billing AccountId Discover : " & Extension.LoadString("TenantDiscoveryFailure") & contentPackApiPrefix & billingProfileId else "",

        Diagnostics.LogValue = ("billingProfileId: " & billingProfileId &  "apiVersion: "&apiVersion &"billingAccountId: " & billingAccountId & "ConnectionType: " & connectionType),

        errorMsg = requiredFieldMsg & contentPackApiPrefix & errorMsgTenants,

        result = if(errorMsg <> "") then errorMsg  else
            let
                table = if apiType = "gettenants" then GetInfoByProfileId(billingProfileId)
                     else if apiType = "budgets" then GetBudgets(billingAccountId, apiVersion, scope, connectionType, billingProfileId)
                     else if apiType = "pricesheets" then GetPriceSheet(billingAccountId, apiVersion, scope, dateParameters, billingProfileId)
                     else if apiType = "usagedetails" then GetUsageDetails(billingAccountId, apiVersion, scope, dateParameters, billingProfileId, false)
                     else if apiType = "usagedetailsamortized" then GetUsageDetails(billingAccountId, apiVersion, scope, dateParameters, billingProfileId, true)
                     else if apiType = "richarges" then GetRICharges(billingAccountId, apiVersion, scope, dateParameters, billingProfileId)

                     else if apiType = "rirecommendationssingle" then GetRecommendationsSingle(billingAccountId, apiVersion, lookBackPeriod, scope, billingProfileId)
                     else if apiType = "rirecommendationsshared" then GetRecommendationsShared(billingAccountId, apiVersion, lookBackPeriod, scope, billingProfileId)

                     else if apiType = "riusagedetails" then GetRIUsage(billingAccountId, apiVersion, scope, dateParameters, billingProfileId)
                     else if apiType = "riusagesummary" then GetRIUsageSummary(billingAccountId, apiVersion, scope, dateParameters, billingProfileId)
                     else if apiType = "balancesummary" then GetCredits(billingAccountId, apiVersion, scope, billingProfileId)

                     else if apiType = "billingevents" then GetEvents(billingAccountId, apiVersion, dateParameters, billingProfileId)
                     else if apiType = "creditlots" then GetLots(billingAccountId, apiVersion, billingProfileId)
                     else if apiType = "charges" then GetCharges(billingAccountId, billingProfileId, apiVersion, dateParameters)

                     else error Extension.LoadString("UnknownAPIType")
            in
                 table
    in
        result;

/// Note: For content pack scenario by Enrollment scope
ContentsInternalOnEnrollmentScope = (enrollmentNumber as text, apiVersion as text, lookBackPeriod as number, dateParameters as record, apiType as text, optional parameters as record) =>
    let
        scope = enrollmentScope,
        errorMsg = if(enrollmentNumber = "") then "Required Field: " & Extension.LoadString("EnrollmentNumberRequired") else "",
        connectionType = if parameters <> null and Record.HasFields(parameters, "connectionType") then parameters[connectionType] else "Prod",

        Diagnostics.LogValue = ("Enrollment Number : "&enrollmentNumber &  "apiVersion: "&apiVersion & "ConnectionType: " & connectionType),

        result = if(errorMsg <> "") then errorMsg  else
            let
                table = if apiType = "budgets" then GetBudgets(enrollmentNumber, apiVersion, scope, connectionType)
                     else if apiType = "pricesheets" then GetPriceSheet(enrollmentNumber, apiVersion, scope, dateParameters)
                     else if apiType = "usagedetails" then GetUsageDetails(enrollmentNumber, apiVersion, scope, dateParameters,"", false)
                     else if apiType = "usagedetailsamortized" then GetUsageDetails(enrollmentNumber, apiVersion, scope, dateParameters, "", true)
                     else if apiType = "richarges" then GetRICharges(enrollmentNumber, apiVersion, scope, dateParameters)
                     else if apiType = "rirecommendationssingle" then GetRecommendationsSingle(enrollmentNumber, apiVersion, lookBackPeriod, scope)
                     else if apiType = "rirecommendationsshared" then GetRecommendationsShared(enrollmentNumber, apiVersion, lookBackPeriod, scope)
                     else if apiType = "riusagedetails" then GetRIUsage(enrollmentNumber, apiVersion, scope, dateParameters)
                     else if apiType = "riusagesummary" then GetRIUsageSummary(enrollmentNumber, apiVersion, scope, dateParameters)
                     else if apiType = "balancesummary" then  GetCredits(enrollmentNumber, apiVersion, scope)
                     else error Extension.LoadString("UnknownAPIType")
            in
                 table
    in
        result;

/// Note: For Desktop scenario
AzureCostManagement.TablesInternal = (scope as text, scopeValue as text, numberOfMonths as number, optional parameters as record) =>
    let
        billingProfileId = if scope = "Billing Profile Id" or scope = "Manually Input Scope" then Text.From(scopeValue) else "",
        enrollmentNumber = if scope = "Enrollment Number" then Text.From(scopeValue) else "",
        customScope = if scope = "Manually Input Scope" then true else false,
        apiVersion = if parameters <> null and Record.HasFields(parameters, "apiVersion") then parameters[apiVersion] else "",
        lookBackPeriod =  if parameters <> null and Record.HasFields(parameters, "lookBackPeriod") then parameters[lookBackPeriod] else 30,
        startDate = if parameters <> null and Record.HasFields(parameters, "startDate") then parameters[startDate] else "",
        endDate = if parameters <> null and Record.HasFields(parameters, "endDate") then parameters[endDate] else "",
        startDateParameter = if startDate = "" or startDate = null then "" else startDate, // To handle start date if customer passes empty or null
        endDateParameter = if endDate = "" or endDate = null then "" else endDate,         //  To handle start date if customer passes empty or null
        validateDateInputs = if numberOfMonths > 0 and (startDateParameter <> "" or   endDateParameter <> "") then error(Extension.LoadString("InvalidDateAndMonthParametrs"))
                             else if numberOfMonths = 0 and (startDateParameter = "" or endDateParameter = "") then error(Extension.LoadString("EmptyDateParametrs"))
                             else "ValidDates",
        dateParameters = if validateDateInputs <>"ValidDates" then ""
                         else if numberOfMonths=0 then GetDatesFromParameters(startDate,endDate)
                         else GetDateParameters(parameters, numberOfMonths),
        apiType = if parameters <> null and Record.HasFields(parameters, "apiType") then parameters[apiType] else "Charges",

        result = if validateDateInputs<>"ValidDates" then validateDateInputs
                 else if customScope or billingProfileId <> ""  then
                    TablesInternalOnGTMScope(billingProfileId, customScope, apiVersion, lookBackPeriod, dateParameters, apiType, parameters)
                 else
                    TablesInternalOnEnrollmentScope(enrollmentNumber, apiVersion, lookBackPeriod, dateParameters, apiType, parameters)
    in
       result;


// Pass the PowerBI service ActivityId to correlate the requests in the CIPEvents
GetClientActivityId = () =>
    let
        activityId = Diagnostics.ActivityId()
    in
        if (activityId <> null) then activityId else Text.NewGuid();


CheckIsValidBillingScopeIdentifier = (scopeIdentifier as text) =>
    let
        pattern = "/" & providerBillingAccount,
        isValid =
            if Text.StartsWith(scopeIdentifier, pattern) then
                let
                    end = Text.AfterDelimiter(scopeIdentifier, "/", billingAccountIndex),
                    delimiterIndex = 0,
                    isValidBillingAccountOrBillingProfile =
                        if not Text.Contains(end, "/") or  Text.BetweenDelimiters(end, "/", "/", delimiterIndex, delimiterIndex) = "billingProfiles" then
                            true
                        else
                            false
                in
                    isValidBillingAccountOrBillingProfile
            else
                false
    in isValid;

/// Note: To parse the billing account from the scope identifier
GetBillingAccountForBABPScope = (scopeIdentifier as text) =>
    // str = /providers/Microsoft.Billing/billingAccounts/{billingAccountId}/billingProfiles/{billingProfileId}
    let
        billingAccountSubstring = Text.AfterDelimiter(scopeIdentifier, "/", billingAccountIndex),
        result = if Text.Contains(billingAccountSubstring, "billingProfiles") then Text.BeforeDelimiter(billingAccountSubstring, "/") else billingAccountSubstring
    in
        result;

/// Note: To parse the billing profile from the scope identifier
GetBillingProfileForBABPScope = (scopeIdentifier as text) =>
    let
        result = Text.AfterDelimiter(scopeIdentifier, "/", billingProfileIndex)
    in
        result;

TablesInternalOnGTMScope = (billingScopeIdentifier as text, isCustomScope as logical, apiVersion as text, lookBackPeriod as number, dateParameters as record, apiType as text, optional parameters as record) =>
let
        requiredFieldMsg = if(billingScopeIdentifier = null) then "Required Field: " & Extension.LoadString("BillingProfileIdRequired") else "",
        scope = if (Text.Contains(billingScopeIdentifier, "billingProfiles") or isCustomScope = false) then billingProfileScope else billingAccountScope,
        connectionType = if parameters <> null and Record.HasFields(parameters, "connectionType") then parameters[connectionType] else "Prod",

        ///Note: to get tenant and billing profile.
        ///We are enabling backwards compatibility for the user to allow flexibility in being able to pass in either the billingprofile id or the scope identifier.
        ///We are also planning to support more scopes in the future
        billingAccountWithOrgId =
            if(isCustomScope) then
                let
                    billingAccountWithOrgId =
                        if CheckIsValidBillingScopeIdentifier(billingScopeIdentifier)
                            then GetBillingAccountForBABPScope(billingScopeIdentifier)
                        else
                            error Error.Record("Invalid scope identifier entered. A valid scope identifier takes the form '/providers/Microsoft.Billing/billingAccounts/{billingAccountId}/billingProfiles/{billingProfileId}'. Scope entered: " & billingScopeIdentifier)
                in
                    billingAccountWithOrgId
            else
                let
                    tenantObj = GetInfoByProfileId(billingScopeIdentifier),
                    billingAccountWithOrgId = try tenantObj[billingAccountId] & ":" & tenantObj[organizationId] otherwise null
                in
                    billingAccountWithOrgId,

        billingProfileid = if(isCustomScope) then
                                let
                                    result =
                                        if Text.Contains(billingScopeIdentifier, "billingProfiles") then
                                            GetBillingProfileForBABPScope(billingScopeIdentifier)
                                        else "" /// Note: to leave the billing profile blank when the scope entered is for the billing account
                                in
                                    result
                           else billingScopeIdentifier,

        ///Note: billingAccountId is for ANR's team as they are using an older version of the api
        billingAccountId = Text.BeforeDelimiter(billingAccountWithOrgId, ":"),

        errorMsgTenants = if(billingAccountWithOrgId = null or billingAccountWithOrgId = "") then "Billing AccountId Discover : " & Extension.LoadString("TenantDiscoveryFailure") & contentPackApiPrefix & billingScopeIdentifier & "BP: " & billingAccountWithOrgId else "",

        errorMsg = requiredFieldMsg & contentPackApiPrefix & errorMsgTenants,

        navTableSource = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"Budgets", "budgets", GetBudgets(billingAccountWithOrgId, apiVersion, scope, connectionType, billingProfileid), "Table", "Table", true},
                {"Pricesheets", "pricesheets", GetPriceSheet(billingAccountWithOrgId, apiVersion, scope, dateParameters, billingProfileid), "Table", "Table", true},
                {"Usage details","usagedetails", GetUsageDetails(billingAccountWithOrgId, apiVersion, scope, dateParameters, billingProfileid, false), "Table", "Table", true},
                {"Usage details amortized","usagedetailsamortized", GetUsageDetails(billingAccountWithOrgId, apiVersion, scope, dateParameters, billingProfileid, true), "Table", "Table", true},
                {"RI charges", "richarges", GetRICharges(billingAccountWithOrgId, apiVersion, scope, dateParameters, billingProfileid), "Table", "Table", true},
                {"RI transactions", "ritransactions", GetRITransactions(billingAccountWithOrgId, apiVersion, scope, dateParameters, billingProfileid), "Table", "Table", true},
                {"RI recommendations (single)", "rirecommendationssingle", GetRecommendationsSingle(billingAccountWithOrgId, apiVersion, lookBackPeriod, scope, billingProfileid), "Table", "Table", true},
                {"RI recommendations (shared)", "rirecommendationsshared", GetRecommendationsShared(billingAccountWithOrgId, apiVersion, lookBackPeriod, scope, billingProfileid), "Table", "Table", true},
                {"RI usage details","riusagedetails", GetRIUsage(billingAccountWithOrgId, apiVersion, scope, dateParameters, billingProfileid), "Table", "Table", true},
                {"RI usage summary","riusagesummary", GetRIUsageSummary(billingAccountWithOrgId, apiVersion, scope, dateParameters, billingProfileid), "Table", "Table", true},
                {"Balance summary","balancesummary", GetCredits(billingAccountWithOrgId, apiVersion, scope, billingProfileid), "Table", "Table", true},
                {"Billing events", "billingevents", GetEvents(billingAccountWithOrgId, apiVersion, dateParameters, billingProfileid), "Table", "Table", true},
                {"Credit lots", "creditlots", GetLots(billingAccountWithOrgId, apiVersion, billingProfileid), "Table", "Table", true},
                {"Charges", "charges", GetCharges(billingAccountWithOrgId, billingProfileid, apiVersion, dateParameters), "Table", "Table", true}
            }),

        result = if (errorMsg <> "") then errorMsg else (Table.ToNavigationTable(navTableSource, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf"))
in
        result;

TablesInternalOnEnrollmentScope = (enrollmentNumber as text, apiVersion as text, lookBackPeriod as number, dateParameters as record, apiType as text, optional parameters as record) =>
let
     scope = enrollmentScope,
     errorMsg = if(enrollmentNumber = "") then "Required Field: " & Extension.LoadString("EnrollmentNumberRequired") else "",
     connectionType = if parameters <> null and Record.HasFields(parameters, "connectionType") then parameters[connectionType] else "Prod",

     navTableSource = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"Budgets", "budgets", GetBudgets(enrollmentNumber, apiVersion, scope,connectionType), "Table", "Table", true},
                {"Pricesheets", "pricesheets", GetPriceSheet(enrollmentNumber, apiVersion, scope, dateParameters), "Table", "Table", true},
                {"Usage details","usagedetails", GetUsageDetails(enrollmentNumber, apiVersion, scope, dateParameters,"", false), "Table", "Table", true},
                {"Usage details amortized", "usagedetailsamortized", GetUsageDetails(enrollmentNumber, apiVersion, scope, dateParameters, "", true), "Table", "Table", true},
                {"RI charges", "richarges", GetRICharges(enrollmentNumber, apiVersion, scope, dateParameters), "Table", "Table", true},
                {"RI transactions", "ritransactions", GetRITransactions(enrollmentNumber, apiVersion, scope, dateParameters), "Table", "Table", true},
                {"RI recommendations (single)", "rirecommendationssingle", GetRecommendationsSingle(enrollmentNumber, apiVersion, lookBackPeriod, scope), "Table", "Table", true},
                {"RI recommendations (shared)", "rirecommendationsshared", GetRecommendationsShared(enrollmentNumber, apiVersion, lookBackPeriod, scope), "Table", "Table", true},
                {"RI usage details","riusagedetails", GetRIUsage(enrollmentNumber, apiVersion, scope, dateParameters), "Table", "Table", true},
                {"RI usage summary","riusagesummary", GetRIUsageSummary(enrollmentNumber, apiVersion, scope, dateParameters), "Table", "Table", true},
                {"Balance summary","balancesummary", GetCredits(enrollmentNumber, apiVersion, scope), "Table", "Table", true}
             }),
        result = if (errorMsg <> "") then errorMsg else (Table.ToNavigationTable(navTableSource, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf"))
in
    result;


/// Note: to get Budget url
GetBudgetURL = (billingAccountId as text, optional apiVersion as text, optional scope as text, optional billingprofileId as text) =>
let
    apiVersion = if(apiVersion <> "") then apiVersion else budgetApiVersion,

    result = if scope = "billingAccount" then
                GetBillingAccountUri() & billingAccountId & "/providers/Microsoft.Consumption/budgets?api-version=" & apiVersion
            else if scope = "billingProfile" then
                GetBillingAccountUri() & billingAccountId & "/billingProfiles/" & billingprofileId & "/providers/Microsoft.Consumption/budgets?api-version=" & apiVersion
            else
                GetBillingAccountUri() & billingAccountId & "/providers/Microsoft.Consumption/budgets?api-version=" & apiVersion
in
    result;

/// Note: to get Summary url
GetChargesURL = (billingAccountId as text, billingProfileId as text, apiVersion as text, optional dateParameters as record) =>
let
    finalDateParameters = if dateParameters <> null then dateParameters
             else GetDatesForLastNMonth(1),

    query = "&startDate=" & finalDateParameters[startTime] & "&endDate=" & finalDateParameters[endTime],

    apiVersion = if(apiVersion <> "") then apiVersion else latestApiVersion,

    result = GetBillingAccountUri() & billingAccountId & "/billingProfiles/" & billingProfileId & "/providers/Microsoft.Consumption/charges?api-version=" & apiVersion & query
in
    result;

/// Note: post Price sheet url
PostPriceSheetUrl = (billingAccountId as text, optional scope as text, optional dateParameters as record, optional billingProfileId as text) =>
    let
         finalDateParameters = if dateParameters <> null then dateParameters
            else GetDatesForLastNMonth(1),

         query = "&startDate=" & finalDateParameters[startTime] & "&endDate=" & finalDateParameters[endTime],

         result =  if scope = "billingAccount" then
                      GetBillingAccountUri() & billingAccountId & "/pricesheet/default/download?api-version=" & priceSheetApiVersion & query
                   //GTM BillingProfile scope calls into apiVersion 2022-04-01 which is under the new CostManagement RP
                   //hence extra uri part is added in below url
                   else if scope = "billingProfile" then
                      GetBillingAccountUri() & billingAccountId &"/billingProfiles/" & billingProfileId & costmanagementProviderUriPart & "/pricesheets/default/download?api-version=" & priceSheetApiVersion & "&format=csv"
                   else
                        let
                            result = GetBillingAccountUri() & billingAccountId & "/providers/Microsoft.Consumption/pricesheets/download?api-version=" & priceSheetApiVersion &"&ln=en" & query
                        in
                            result
    in
         result;

/// Note: post Usage detail url
PostUsageDetailUrl = (billingAccountId as text, optional apiVersion as text, optional scope as text, optional dateParameters as record, optional billingProfileId as text, optional isAmortized as logical) =>
    let
        apiVersion = if(apiVersion <> "") then apiVersion else novApiVersion,

        finalDateParameters = if dateParameters <> null then dateParameters
            else GetDatesForLastNMonth(1),
        gtmQueryDate = "&startDate=" & finalDateParameters[startTime] & "&endDate=" & finalDateParameters[endTime],

        usageDetailsUrl =  if scope = "billingAccount" then
                    let
                        result = GetBillingAccountUri() & billingAccountId & "/providers/Microsoft.Consumption/usageDetails/download?api-version=" & apiVersion &  gtmQueryDate
                    in
                        result
                  else if scope = "billingProfile" then
                    let
                        result =  GetBaseUri() & providerBillingAccount & billingAccountId &"/billingProfiles/" & billingProfileId & "/providers/Microsoft.Consumption/usageDetails/download?api-version=" & novApiVersion & gtmQueryDate
                    in
                        result
                  else
                    let
                        queryDate = "&$filter=properties/usageStart+ge+'" & finalDateParameters[startTime] & "'+and+properties/usageStart+le+'" & finalDateParameters[endTime] & "'",
                        result = GetBaseUri() & providerBillingAccount & billingAccountId & "/providers/Microsoft.Consumption/usageDetails/download?api-version="& apiVersion & queryDate
                    in
                        result,
        result = if isAmortized = true then usageDetailsUrl & "&metric=AmortizedCost" else usageDetailsUrl
    in
        result;

/// Note: to get credit url
GetCreditsURL = (billingAccountId as text, apiVersion as text, optional scope as text, optional billingProfileId as text) =>
    let
        apiVersion = if(apiVersion <> "") then apiVersion else latestApiVersion,

        result =  if scope = "billingAccount" then
                     GetBillingAccountUri() & billingAccountId & "/providers/Microsoft.Consumption/credits/balanceSummary?api-version=" & apiVersion
                  else if scope = "billingProfile" then
                     GetBillingAccountUri() & billingAccountId &"/billingProfiles/" & billingProfileId & "/providers/Microsoft.Consumption/credits/balanceSummary?api-version=" & apiVersion
                  else
                     GetBillingAccountUri() & billingAccountId & "/providers/microsoft.consumption/balances?api-version=" & apiVersion
    in
        result;

/// Note: to get credit url
GetEventsURL = (billingAccountId as text, apiVersion as text, optional dateParameters as record, optional billingProfileId as text) =>
    let
        finalDateParameters = if dateParameters <> null then dateParameters
            else GetDatesForLastNMonth(1),

        apiVersion = if(apiVersion <> "") then apiVersion else latestApiVersion,

        query = "&startDate=" & finalDateParameters[startTime] & "&endDate=" & finalDateParameters[endTime],

        result = GetBillingAccountUri() & billingAccountId &"/billingProfiles/" & billingProfileId & "/providers/Microsoft.Consumption/events?api-version=" & apiVersion & query
    in
        result;

/// Note: to get Notes url
GetLotsURL = (billingAccountId as text, apiVersion as text, billingProfileId as text) =>
    let
        apiVersion = if(apiVersion <> "") then apiVersion else latestApiVersion,
        result = GetBillingAccountUri() & billingAccountId &"/billingProfiles/" & billingProfileId & "/providers/Microsoft.Consumption/lots?api-version=" & apiVersion
    in
        result;

/// Note: to get RICharges url (Transaction)
GetRIChargesURL = (billingAccountId as text, apiVersion as text, optional scope as text, optional dateParameters as record, optional billingProfileId as text) =>
    let
        finalDateParameters = if dateParameters <> null then dateParameters
            else GetDatesForLastNMonth(1),
        apiVersion = if(apiVersion <> "") then apiVersion else supportedAPIVersion,

        result = if scope = "billingAccount" then
                    let
                        queryFilter = "properties/eventDate+ge+" & finalDateParameters[startTime] & "+AND+properties/eventDate+le+" & finalDateParameters[endTime],
                        result = GetBillingAccountUri() & billingAccountId &"/providers/Microsoft.Consumption/reservationTransactions?$filter=" & queryFilter & "&api-version=" & latestApiVersion
                    in
                        result
                else if scope = "billingProfile" then
                    let
                        querydate = "&periodStartDate=" & finalDateParameters[startTime] & "&periodEndDate=" & finalDateParameters[endTime],
                        queryFilter = "&$filter=properties/kind%20eq%20'Reservation'",
                        result = GetBillingAccountUri() & billingAccountId &"/billingProfiles/"& billingProfileId &"/transactions?api-version=" & billingRpTransactionsApiVersion & querydate & queryFilter
                    in
                        result
                 else
                     let
                        queryFilter = "&$filter=properties/EventDate+ge+" & finalDateParameters[startTime] & "+AND+properties/EventDate+le+" & finalDateParameters[endTime],
                        result = GetBillingAccountUri() & billingAccountId &"/providers/Microsoft.Consumption/reservationTransactions?api-version=" & apiVersion & queryFilter
                     in
                         result
    in
        result;


GetRITransactionsURL = (billingAccountId as text, apiVersion as text, optional scope as text, optional dateParameters as record, optional billingProfileId as text) =>
let
   finalDateParameters = if dateParameters <> null then dateParameters
        else GetDatesForLastNMonth(1),

   apiVersion = if(apiVersion <> "") then apiVersion else latestApiVersion,

   queryFilter = "?$filter=properties/eventDate+ge+" & finalDateParameters[startTime] & "+AND+properties/eventDate+le+" & finalDateParameters[endTime],

   result = if scope = "billingProfile" then
                GetBillingAccountUri() & billingAccountId & "/billingProfiles/" & billingProfileId & "/providers/Microsoft.Consumption/reservationTransactions" & queryFilter & "&api-version=" & apiVersion
            else
                GetBillingAccountUri() & billingAccountId & "/providers/Microsoft.Consumption/reservationTransactions" & queryFilter & "&api-version=" & apiVersion
in
    result;

/// Note: to get RecommendationsSingle URL
GetRecommendationsSingleURL = (billingAccountId as text, apiVersion as text, lookBackPeriod as number, optional scope as text, optional billingProfileId as text) =>
    let
         lookBackTimeSlot = "Last" & Number.ToText(lookBackPeriod) & "Days",
         apiVersion = if(apiVersion <> "") then apiVersion else latestApiVersion,

         result = if scope = "billingAccount" then
                    let
                        result = GetBillingAccountUri() & billingAccountId & "/providers/Microsoft.Consumption/reservationRecommendations?$filter=properties/scope+eq+'Single'+AND+properties/lookBackPeriod+eq+'"& lookBackTimeSlot &"' &api-version=" & apiVersion
                    in
                        result
                else if scope = "billingProfile" then
                    let
                        result = GetBillingAccountUri() & billingAccountId &"/billingProfiles/"& billingProfileId &"/providers/Microsoft.Consumption/reservationRecommendations?$filter=properties/scope+eq+'Single'+AND+properties/lookBackPeriod+eq+'"& lookBackTimeSlot &"' &api-version=" & apiVersion
                    in
                        result
                 else
                    let
                        result = GetBillingAccountUri() & billingAccountId &"/providers/Microsoft.Consumption/reservationRecommendations?$filter=properties/scope+eq+'Single'+AND+properties/lookBackPeriod+eq+'"& lookBackTimeSlot &"' &api-version="& apiVersion
                    in
                result
    in
         result;

/// Note: to get RecommendationsShared URL
GetRecommendationsSharedURL = (billingAccountId as text, apiVersion as text, lookBackPeriod as number, optional scope as text,optional billingProfileId as text) =>
    let
        lookBackTimeSlot = "Last" & Number.ToText(lookBackPeriod) & "Days",
        apiVersion = if(apiVersion <> "") then apiVersion else latestApiVersion,

        result = if scope = "billingAccount" then
                    let
                        result = GetBillingAccountUri() & billingAccountId & "/providers/Microsoft.Consumption/reservationRecommendations?$filter=properties/scope+eq+'Shared'+AND+properties/lookBackPeriod+eq+'"& lookBackTimeSlot &"' &api-version=" & apiVersion
                    in
                        result
                else if scope = "billingProfile" then
                    let
                        result = GetBillingAccountUri() & billingAccountId &"/billingProfiles/"& billingProfileId &"/providers/Microsoft.Consumption/reservationRecommendations?$filter=properties/scope+eq+'Shared'+AND+properties/lookBackPeriod+eq+'"& lookBackTimeSlot &"' &api-version=" & apiVersion
                    in
                        result
                else
                    let
                        result = GetBillingAccountUri() & billingAccountId &"/providers/Microsoft.Consumption/reservationRecommendations?$filter=properties/scope+eq+'Shared'+AND+properties/lookBackPeriod+eq+'"& lookBackTimeSlot &"'&api-version="& apiVersion
                    in
                        result
     in
        result;

/// Note: to get RIUsage URL
GetRIUsageURL = (billingAccountId as text, apiVersion as text, optional scope as text, optional dateParameters as record, optional billingProfileId as text) =>
   let
       finalDateParameters = if dateParameters <> null then dateParameters
            else GetDatesForLastNMonth(1),
       querydate = "&startDate=" & finalDateParameters[startTime] & "&endDate=" & finalDateParameters[endTime],
       result = if scope = "billingAccount" then
                    let
                        result = GetBillingAccountUri() & billingAccountId & "/providers/Microsoft.CostManagement/generateReservationDetailsReport?api-version=" & novApiVersion & querydate
                    in
                        result
                else if scope = "billingProfile" then
                    let
                        result = GetBillingAccountUri() & billingAccountId &"/billingProfiles/"& billingProfileId &"/providers/Microsoft.CostManagement/generateReservationDetailsReport?api-version=" & novApiVersion & querydate
                    in
                        result
                else
                    let
                        result = GetBillingAccountUri() & billingAccountId & "/providers/Microsoft.CostManagement/generateReservationDetailsReport?api-version=" & novApiVersion  & querydate
                    in
                        result
   in
        result;

/// Note: to get budget details
GetBudgets = (billingAccountId as text,
apiVersion as text,
optional scope as text,
optional connectionType as text,
optional billingProfileId as text) =>

let
    url = GetBudgetURL(billingAccountId, apiVersion, scope, billingProfileId),
    appType = if billingProfileId <> null or scope = "billingAccount" then appTypeModern else appTypeLegacy,
    schema = GetSchemaForEntity("apiProperty"),

    jsonContent = GetPage(url, schema, appType),

    result = if(jsonContent <> null and (not Table.IsEmpty(jsonContent)))
             then try CreateBudgetData(jsonContent) otherwise handleError(jsonContent)
             else CreateEmptyBudgetData()

in
    result;

/// Note: to create empty Budget dataset
CreateEmptyBudgetData = () =>
let
    result = Table.FromList(
        {},
        Record.FieldValues,
        apiColumns_Budgets)
in
   result;

/// Note: To create Budget data
CreateBudgetData = (optional budgetRecord as table) =>
let
    tempTable1 = Table.ExpandRecordColumn(budgetRecord,"properties",{"timePeriod","timeGrain","amount","currentSpend","category","notifications","filter","forecastSpend"}),
    tempTable2 = Table.RenameColumns(tempTable1, {{"amount","budgetAmount"}}),
    tempTable3 = Table.ExpandRecordColumn(tempTable2,"timePeriod",{"startDate","endDate"}),
    tempTable4 = Table.ExpandRecordColumn(tempTable3,"currentSpend",{"amount","unit"}),
    tempTable5 = Table.RenameColumns(tempTable4,{{"amount","currentSpendAmount"},{"unit","currentSpendUnit"}}),
    tempTable6 = if (Table.HasColumns(tempTable5, "forecastSpend"))
        then Table.ExpandRecordColumn(tempTable5,"forecastSpend",{"amount","unit"})
        else
            let
                withAmount = Table.AddColumn(tempTable5, "amount", each 0.0),
                withUnit = Table.AddColumn(withAmount, "unit", each "")
            in
            withUnit,
    source = Table.RenameColumns(tempTable6,{{"amount","forecastAmount"},{"unit","forecastUnit"}}),

    /// creating a final budget results to be printed
    result = Table.TransformColumnTypes(
        source,
        {
            {"startDate", type datetime},
            {"endDate", type datetime},
            {"budgetAmount", type number},
            {"currentSpendAmount", type number},
            {"forecastAmount", type number}
        },
        culture)
in
    result;

/// Note: to get summary details.
GetCharges = (billingAccountId as text, billingProfileId as text, apiVersion as text, optional dateParameters as record) =>
let
    /// to get summary url.
    url = GetChargesURL(billingAccountId, billingProfileId, apiVersion, dateParameters),
    schema = GetSchemaForEntity("apiProperty"),
    jsonContent = GetAllPagesByNextLink(url, schema, appTypeModern),

    result = if(jsonContent <> null and Table.RowCount(jsonContent) > 0) then try CreateChargesData(jsonContent) otherwise handleError(jsonContent)
    else CreateEmptyChargesData()
in
    result;

/// Note: to create empty charges dataset
CreateEmptyChargesData = () =>
let
    result = Table.FromList(
        {},
        Record.FieldValues,
        apiColumns_Charges)
in
    Table.TransformColumnTypes(
        result,
        {
           {"isInvoiced", type logical},
           {"usageStart", type datetime},
           {"usageEnd", type datetime},
           {"azureCharges", type number},
           {"chargesBilledSeparately", type number},
           {"marketPlaceCharges", type number}
        },
        culture);

/// Note: To create summary data
CreateChargesData = (optional summaryRecord as table) =>
let
    tempTable1 = Table.ExpandRecordColumn(summaryRecord,"properties",{"isInvoiced", "billingPeriodId","usageStart","usageEnd","azureCharges","chargesBilledSeparately", "marketplaceCharges", "billingAccountId", "billingProfileId", "invoiceSectionId"}),
    tempTable2 = Table.ExpandRecordColumn(tempTable1,"azureCharges",{"currency","value"}),
    tempTable3 = Table.RenameColumns(tempTable2, {{"currency","azureChargesCurrency"},{"value","azureCharges"}}),
    tempTable4 = Table.ExpandRecordColumn(tempTable3,"chargesBilledSeparately",{"currency","value"}),
    tempTable5 = Table.RenameColumns(tempTable4, {{"currency","chargesBilledSeparatelyCurrency"},{"value","chargesBilledSeparately"}}),
    tempTable6 = Table.ExpandRecordColumn(tempTable5,"marketplaceCharges",{"currency","value"}),

    ///source table
    source = Table.RenameColumns(tempTable6, {{"currency","marketPlaceChargesCurrency"},{"value","marketPlaceCharges"}}),

    /// creating a final Summary results to be printed
    result = Table.TransformColumnTypes(
        source,
        {
            {"isInvoiced", type logical},
            {"usageStart", type datetime},
            {"usageEnd", type datetime},
            {"azureCharges", type number},
            {"chargesBilledSeparately", type number},
            {"marketPlaceCharges", type number}
        },
        culture)
in
    result;

/// Note: to get price sheet details
GetPriceSheet = (billingAccountId as text, optional apiVersion as text, optional scope as text, optional dateParameters as record, optional billingProfileId as text) =>
let
    appType = if ((billingProfileId <> "" and billingProfileId <> null) or scope = "billingAccount") then appTypeModern else appTypeLegacy,

    // pricesheet api GTM should use latest api version (2022-xx-xx) while EA should use the older version (2019-xx-xx) because api team does
    // not support EA customers on newer version yet.
    apiVersion = if(apiVersion <> "") then apiVersion else
        if(appType = appTypeModern and scope = "billingProfile") then "2022-04-01-preview" else "2019-10-01-preview", //"2018-11-01-preview" - previous version
    disableArchive = if(appType = appTypeModern and scope = "billingProfile") then true else false,
    postPriceSheetUrl = PostPriceSheetUrl(billingAccountId, scope, dateParameters, billingProfileId),

    rawContent = if appType = appTypeModern then
                     QueueData(billingAccountId, apiVersion, postPriceSheetUrl, billingProfileId, appType, disableArchive)
                 else
                     QueueDataEx(postPriceSheetUrl, appType),

    asJson = try Json.Document(rawContent, 1252) otherwise null,
    body = if asJson is action then null else asJson meta Value.Metadata(rawContent),

    metadata = Value.Metadata(rawContent),
    headers = metadata[Headers],
    locationUri = headers[Location],
    statusUri = headers[#"Azure-AsyncOperation"],
    result = try DownloadPSData(locationUri, statusUri, appType) otherwise CreateEmptyPriceSheetData()
in
    result;

GetPriceSheetDataByBillingProfileV2 = (rawUrls as list) =>
let
    ConvertToTable = Table.FromList(rawUrls, Splitter.SplitByNothing(), {"rawUrls"}, null, ExtraValues.Error),
    InvokeCustomFunction = Table.AddColumn(ConvertToTable, "CsvData", each ReadCSVDataFromBlob([rawUrls])),
    RemoveColumns = Table.RemoveColumns(InvokeCustomFunction,{"rawUrls"}),
    ExpandColumns = Table.ExpandTableColumn(RemoveColumns, "CsvData", tableColumns_Pricesheet),

    /// creating a final Summary results to be printed
    result = Table.TransformColumnTypes(
             ExpandColumns,
             {
                 {"basePrice", type number},
                 {"unitPrice", type number},
                 {"effectiveStartDate", type datetime},
                 {"effectiveEndDate", type datetime},
                 {"tierMinimumUnits", type number}
             },
             culture)
in
    result;

/// Note: to get PriceSheet Data details on Billing profile scope
GetPriceSheetDataByBillingProfile = (usageDetailCsvUrl as text) =>
let
    record = GetPriceSheetDataTable(Blob.Contents(usageDetailCsvUrl)),
    source = Table.FromRecords(record),

    //Bring source and target columns together as rows in a table
    destinationTable = Table.FromRows({apiColumns_Pricesheet, tableColumns_Pricesheet}),

    //Create a list of rename pairs
    RenameList = Table.ToColumns(destinationTable),

    //Call to Table.RenameColumns
    tempTableFinal = Table.RenameColumns(source, RenameList, MissingField.Ignore),

    /// creating a final Summary results to be printed
    result = Table.TransformColumnTypes(
        tempTableFinal,
        {
            {"basePrice", type number},
            {"unitPrice", type number},
            {"effectiveStartDate", type datetime},
            {"effectiveEndDate", type datetime},
            {"tierMinimumUnits", type number}
        },
        culture)
in
    result;

/// Note: to get PriceSheet Data details on Enrollment scope
GetPriceSheetDataByEnrollment = (CsvUrl as text) =>
let
    priceSheetData = ReadCSVDataSkipRows(Blob.Contents(CsvUrl),2),
    table4 = if Table.HasColumns(priceSheetData, "Meter ID") then priceSheetData else Table.AddColumn(priceSheetData, "Meter ID", each ""),
    table5 = if Table.HasColumns(table4, "Meter name") then table4 else Table.AddColumn(table4, "Meter name", each ""),
    table6 = if Table.HasColumns(table5, "Meter category") then table5 else Table.AddColumn(table5, "Meter category", each ""),
    table7 = if Table.HasColumns(table6, "Meter sub-category") then table6 else Table.AddColumn(table6, "Meter sub-category", each ""),
    table8 = if Table.HasColumns(table7, "Meter region") then table7 else Table.AddColumn(table7, "Meter region", each ""),
    table9 = if Table.HasColumns(table8, "Unit") then table8 else Table.AddColumn(table8, "Unit", each ""),
    table10 = if Table.HasColumns(table9, "Unit of measure") then table9 else Table.AddColumn(table9, "Unit of measure", each ""),
    table11 = if Table.HasColumns(table10, "Part number") then table10 else Table.AddColumn(table10, "Part number", each ""),
    table12 = if Table.HasColumns(table11, "Unit price") then table11 else Table.AddColumn(table11, "Unit price", each ""),
    table13 = if Table.HasColumns(table12, "Currency code") then table12 else Table.AddColumn(table12, "Currency code", each ""),
    table14 = if Table.HasColumns(table13, "Included quantity") then table13 else Table.AddColumn(table13, "Included quantity", each ""),
    table15 = if Table.HasColumns(table14, "Offer Id") then table14 else Table.AddColumn(table14, "Offer Id", each ""),
    table16 = if Table.HasColumns(table15, "Term") then table15 else Table.AddColumn(table15, "Term", each ""),
    source = if Table.HasColumns(table16, "Price type") then table16 else Table.AddColumn(table16, "Price type", each ""),

    /// creating a final Summary results to be printed
    result = Table.TransformColumnTypes(
        source,
        {
            {"Included quantity", type number},
            {"Unit price", type number}
        },
        culture)
in
    result;

/// Note: to get PriceSheet DataTable.
GetPriceSheetDataTable = (csvString) as list =>
    let
        result = try Json.Document(csvString) otherwise Extension.LoadString("PriceSheetFailed") &  csvString
    in
        result;

/// Note: to down load the price sheet data from blob.
DownloadPSData = (locationUri as text, statusUri as text, optional appType as text) =>
    let
        data = GetDataWithPolling(locationUri, statusUri, appType),
        statusText = if (data <> null) then ParseReportStatus(statusUri, appType) else null
    in
         if (statusText = "3" or statusText = "completed") then
         (
            let
                //latest apiVersion has properties under publishedEntity object so try that if it fails then it is outside of it
                result = try data[publishedEntity][properties] otherwise data[properties]
            in(
                if (appType = appTypeModern and result[rawUrls] <> null) then GetPriceSheetDataByBillingProfileV2(result[rawUrls])  /// Poll operation completed for billing profile scope
                else if (appType = appTypeModern and result[downloadUrl] <> null) then GetPriceSheetDataByBillingProfile(result[downloadUrl])
                else if (appType = appTypeLegacy and result[downloadUrl] <> null) then GetPriceSheetDataByEnrollment(result[downloadUrl]) /// Poll operation completed for enrollment scope
                else CreateEmptyPriceSheetData())
        )
        else if (statusText = "5" or statusText = "nodatafound") then CreateEmptyPriceSheetData() // NoDataFound
        else error Extension.LoadString("PriceSheetFailed") & locationUri;

/// Note: to create an empty price sheet.
CreateEmptyPriceSheetData = () =>
    let
        result = Table.FromList(
            {},
            Record.FieldValues,
                tableColumns_Pricesheet
            )
    in
        Table.TransformColumnTypes(
        result,
        {
            {"basePrice", type number},
            {"unitPrice", type number},
            {"effectiveStartDate", type datetime},
            {"effectiveEndDate", type datetime},
            {"tierMinimumUnits", type number}
        },
        culture);

/// Note: Get usage details
GetUsageDetails = (billingAccountId as text, optional apiVersion as text, optional scope as text, optional dateParameters as record, optional billingProfileId as text, optional isAmortized as logical) =>
let
        apiVersion = if(apiVersion <> "") then apiVersion else novApiVersion,

         postUsageDetailUrl = PostUsageDetailUrl(billingAccountId, apiVersion, scope, dateParameters, billingProfileId, isAmortized),
         finalDateParameters = if dateParameters <> null and Record.HasFields(dateParameters, "startTime") and Record.HasFields(dateParameters, "endTime") then dateParameters
              else GetDatesForLastNMonth(1),

         appType = if ((billingProfileId <> "" and billingProfileId <> null) or scope = "billingAccount") then  appTypeModern else appTypeLegacy,

         rawContent = QueueDataEx(postUsageDetailUrl, appType),

         asJson = try Json.Document(rawContent, 1252) otherwise null,
         body = if asJson is action then null else asJson meta Value.Metadata(rawContent),

         metadata = Value.Metadata(rawContent),
        headers = metadata[Headers],

        responseStatus = metadata[Headers][Response.Status],
        locationUri = metadata[Headers][Location],
        statusUri = metadata[Headers][#"Azure-AsyncOperation"],
        result = try DownLoadUsageDetailsData(locationUri, statusUri, appType) otherwise handleError(body)
 in
    result;

/// Note: to post the content and get download url.
QueueDataEx = (url as text, optional appType as text, optional isPostCall as logical) =>
    let
        response = if(isPostCall <> null and isPostCall = true)
                    then GetWebContents(url, appType, null, Text.ToBinary("POST"))
                    else GetWebContents(url, appType)
    in
        response;

/// Note: to down load the usage details data from blob.
DownLoadUsageDetailsData = (locationUri as text, statusUri as text, optional appType as text) =>
    let
        data = GetDataWithPollingEx(locationUri, statusUri, appType),
        statusText = if (data <> null) then ParseReportStatus(statusUri, appType)
                else null
    in
         if (statusText = "3" or Text.Lower(statusText) = "completed") then
            (let
                result = data[properties]
            in(
               if (result[downloadUrl] <> null and appType = appTypeModern) then GetUsageDetailsByBillingProfile(result[downloadUrl])  /// Poll operation completed for billing profile scope
               else if (result[downloadUrl] <> null and appType = appTypeLegacy) then GetUsageDetailsByEnrollment(result[downloadUrl]) /// Poll operation completed for enrollment scope
               else CreateEmptyUsageDetailsData(appType))
               )

         else if (statusText = "5" or statusText = "nodatafound") then CreateEmptyUsageDetailsData() // NoDataFound
         else error Extension.LoadString("UsageDetailsFailed") & locationUri;

/// Note: to get usagedetails by billing profile
GetUsageDetailsByBillingProfile = (usageDetailCsvUrl as text) =>
let
    usageDetailsRecord = ReadCSVData(Blob.Contents(usageDetailCsvUrl)),

    table4 = if Table.HasColumns(usageDetailsRecord, "invoiceId") then usageDetailsRecord else Table.AddColumn(usageDetailsRecord, "invoiceId", each ""),
    table5 = if Table.HasColumns(table4, "previousInvoiceId") then table4 else Table.AddColumn(table4, "previousInvoiceId", each ""),
    table6 = if Table.HasColumns(table5, "billingAccountId") then table5 else Table.AddColumn(table5, "billingAccountId", each ""),
    table7 = if Table.HasColumns(table6, "billingAccountName") then table6 else Table.AddColumn(table6, "billingAccountName", each ""),
    table8 = if Table.HasColumns(table7, "billingProfileId") then table7 else Table.AddColumn(table7, "billingProfileId", each ""),
    table9 = if Table.HasColumns(table8, "billingProfileName") then table8 else Table.AddColumn(table8, "billingProfileName", each ""),
    table10 = if Table.HasColumns(table9, "invoiceSectionId") then table9 else Table.AddColumn(table9, "invoiceSectionId", each ""),
    table11 = if Table.HasColumns(table10, "invoiceSectionName") then table10 else Table.AddColumn(table10, "invoiceSectionName", each ""),
    table12 = if Table.HasColumns(table11, "costCenter") then table11 else Table.AddColumn(table11, "costCenter", each ""),
    table13 = if Table.HasColumns(table12, "billingPeriodStartDate") then table12 else Table.AddColumn(table12, "billingPeriodStartDate", each ""),
    table14 = if Table.HasColumns(table13, "billingPeriodEndDate") then table13 else Table.AddColumn(table13, "billingPeriodEndDate", each ""),
    table15 = if Table.HasColumns(table14, "servicePeriodStartDate") then table14 else Table.AddColumn(table14, "servicePeriodStartDate", each ""),
    table16 = if Table.HasColumns(table15, "servicePeriodEndDate") then table15 else Table.AddColumn(table15, "servicePeriodEndDate", each ""),
    table17 = if Table.HasColumns(table16, "date") then table16 else Table.AddColumn(table16, "date", each ""),
    table18 = if Table.HasColumns(table17, "serviceFamily") then table17 else Table.AddColumn(table17, "serviceFamily", each ""),
    table19 = if Table.HasColumns(table18, "productOrderId") then table18 else Table.AddColumn(table18, "productOrderId", each ""),
    table20 = if Table.HasColumns(table19, "productOrderName") then table19 else Table.AddColumn(table19, "productOrderName", each ""),
    table21 = if Table.HasColumns(table20, "consumedService") then table20 else Table.AddColumn(table20, "consumedService", each ""),
    table22 = if Table.HasColumns(table21, "meterId") then table21 else Table.AddColumn(table21, "meterId", each ""),
    table23 = if Table.HasColumns(table22, "meterName") then table22 else Table.AddColumn(table22, "meterName", each ""),
    table24 = if Table.HasColumns(table23, "meterCategory") then table23 else Table.AddColumn(table23, "meterCategory", each ""),
    table25 = if Table.HasColumns(table24, "meterSubCategory") then table24 else Table.AddColumn(table24, "meterSubCategory", each ""),
    table26 = if Table.HasColumns(table25, "meterRegion") then table25 else Table.AddColumn(table25, "meterRegion", each ""),
    table27 = if Table.HasColumns(table26, "productId") then table26 else Table.AddColumn(table26, "productId", each ""),
    table28 = if Table.HasColumns(table27, "product") then table27 else Table.AddColumn(table27, "product", each ""),
    table29 = if Table.HasColumns(table28, "subscriptionId") then table28 else Table.AddColumn(table28, "subscriptionId", each ""),
    table30 = if Table.HasColumns(table29, "subscriptionName") then table29 else Table.AddColumn(table29, "subscriptionName", each ""),
    table31 = if Table.HasColumns(table30, "publisherType") then table30 else Table.AddColumn(table30, "publisherType", each ""),
    table32 = if Table.HasColumns(table31, "publisherName") then table31 else Table.AddColumn(table31, "publisherName", each ""),
    table33 = if Table.HasColumns(table32, "resourceGroupName") then table32 else Table.AddColumn(table32, "resourceGroupName", each ""),
    table34 = if Table.HasColumns(table33, "resourceId") then table33 else Table.AddColumn(table33, "resourceId", each ""),
    table35 = if Table.HasColumns(table34, "resourceLocation") then table34 else Table.AddColumn(table34, "resourceLocation", each ""),
    table36 = if Table.HasColumns(table35, "location") then table35 else Table.AddColumn(table35, "location", each ""),
    table37 = if Table.HasColumns(table36, "effectivePrice") then table36 else Table.AddColumn(table36, "effectivePrice", each ""),
    table38 = if Table.HasColumns(table37, "quantity") then table37 else Table.AddColumn(table37, "quantity", each ""),
    table39 = if Table.HasColumns(table38, "unitOfMeasure") then table38 else Table.AddColumn(table38, "unitOfMeasure", each ""),
    table40 = if Table.HasColumns(table39, "chargeType") then table39 else Table.AddColumn(table39, "chargeType", each ""),
    table41 = if Table.HasColumns(table40, "pricingCurrency") then table40 else Table.AddColumn(table40, "pricingCurrency", each ""),
    table42 = if Table.HasColumns(table41, "billingCurrency") then table41 else Table.AddColumn(table41, "billingCurrency", each ""),
    table43 = if Table.HasColumns(table42, "costInBillingCurrency") then table42 else Table.AddColumn(table42, "costInBillingCurrency", each ""),
    table44 = if Table.HasColumns(table43, "costInPricingCurrency") then table43 else Table.AddColumn(table43, "costInBillingCurrency", each ""),
    table45 = if Table.HasColumns(table44, "exchangeRatePricingToBilling") then table44 else Table.AddColumn(table44, "exchangeRatePricingToBilling", each ""),
    table46 = if Table.HasColumns(table45, "exchangeRateDate") then table45 else Table.AddColumn(table45, "exchangeRateDate", each ""),
    table47 = if Table.HasColumns(table46, "isAzureCreditEligible") then table46 else Table.AddColumn(table46, "isAzureCreditEligible", each ""),
    table48 = if Table.HasColumns(table47, "serviceInfo1") then table47 else Table.AddColumn(table47, "serviceInfo1", each ""),
    table49 = if Table.HasColumns(table48, "serviceInfo2") then table48 else Table.AddColumn(table48, "serviceInfo2", each ""),
    table50 = if Table.HasColumns(table49, "additionalInfo") then table49 else Table.AddColumn(table49, "additionalInfo", each ""),
    source = if Table.HasColumns(table50, "Tags") then table50 else Table.AddColumn(table50, "Tags", each ""),
    result = Table.TransformColumnTypes(
            source,
            {
                {"billingPeriodStartDate", type datetime},
                {"billingPeriodEndDate", type datetime},
                {"servicePeriodStartDate", type datetime},
                {"servicePeriodEndDate", type datetime},
                {"effectivePrice", type number},
                {"exchangeRateDate", type datetime},
                {"quantity", type number},
                {"date", type datetime},
                {"costInBillingCurrency", type number},
                {"costInPricingCurrency", type number},
                {"exchangeRatePricingToBilling", type number}
            },
            culture)

in
    result;

/// Note: to get usage details by enrollment number
GetUsageDetailsByEnrollment = (usageDetailCsvUrl as text) =>
let
    usageDetailsRecord = ReadCSVData(Blob.Contents(usageDetailCsvUrl)),

    table1 = if Table.HasColumns(usageDetailsRecord, "BillingAccountId") then usageDetailsRecord else Table.AddColumn(usageDetailsRecord, "BillingAccountId", each ""),
    table2 = if Table.HasColumns(table1, "BillingAccountName") then table1 else Table.AddColumn(table1, "BillingAccountName", each ""),
    table3 = if Table.HasColumns(table2, "BillingPeriodStartDate") then table2 else Table.AddColumn(table2, "BillingPeriodStartDate", each ""),
    table4 = if Table.HasColumns(table3, "BillingPeriodEndDate") then table3 else Table.AddColumn(table3, "BillingPeriodEndDate", each ""),
    table5 = if Table.HasColumns(table4, "BillingProfileId") then table4 else Table.AddColumn(table4, "BillingProfileId", each ""),
    table6 = if Table.HasColumns(table5, "BillingProfileName") then table5 else Table.AddColumn(table5, "BillingProfileName", each ""),
    table7 = if Table.HasColumns(table6, "AccountOwnerId") then table6 else Table.AddColumn(table6, "AccountOwnerId", each ""),
    table8 = if Table.HasColumns(table7, "AccountName") then table7 else Table.AddColumn(table7, "AccountName", each ""),
    table9 = if Table.HasColumns(table8, "SubscriptionId") then table8 else Table.AddColumn(table8, "SubscriptionId", each ""),
    table10 = if Table.HasColumns(table9, "SubscriptionName") then table9 else Table.AddColumn(table9, "SubscriptionName", each ""),
    table11 = if Table.HasColumns(table10, "Date") then table10 else Table.AddColumn(table10, "Date", each ""),
    table12 = if Table.HasColumns(table11, "Product") then table11 else Table.AddColumn(table11, "Product", each ""),
    table13 = if Table.HasColumns(table12, "PartNumber") then table12 else Table.AddColumn(table12, "PartNumber", each ""),
    table14 = if Table.HasColumns(table13, "MeterId") then table13 else Table.AddColumn(table13, "MeterId", each ""),
    table15 = if Table.HasColumns(table14, "ServiceFamily") then table14 else Table.AddColumn(table14, "ServiceFamily", each ""),
    table16 = if Table.HasColumns(table15, "MeterCategory") then table15 else Table.AddColumn(table15, "MeterCategory", each ""),
    table17 = if Table.HasColumns(table16, "MeterSubCategory") then table16 else Table.AddColumn(table16, "MeterSubCategory", each ""),
    table18 = if Table.HasColumns(table17, "MeterRegion") then table17 else Table.AddColumn(table17, "MeterRegion", each ""),
    table19 = if Table.HasColumns(table18, "MeterName") then table18 else Table.AddColumn(table18, "MeterName", each ""),
    table20 = if Table.HasColumns(table19, "Quantity") then table19 else Table.AddColumn(table19, "Quantity", each ""),
    table21 = if Table.HasColumns(table20, "EffectivePrice") then table20 else Table.AddColumn(table20, "EffectivePrice", each ""),
    table22 = if Table.HasColumns(table21, "Cost") then table21 else Table.AddColumn(table21, "Cost", each ""),
    table23 = if Table.HasColumns(table22, "UnitPrice") then table22 else Table.AddColumn(table22, "UnitPrice", each ""),
    table24 = if Table.HasColumns(table23, "BillingCurrency") then table23 else Table.AddColumn(table23, "BillingCurrency", each ""),
    table25 = if Table.HasColumns(table24, "ResourceLocation") then table24 else Table.AddColumn(table24, "ResourceLocation", each ""),
    table26 = if Table.HasColumns(table25, "AvailabilityZone") then table25 else Table.AddColumn(table25, "AvailabilityZone", each ""),
    table27 = if Table.HasColumns(table26, "ConsumedService") then table26 else Table.AddColumn(table26, "ConsumedService", each ""),
    table28 = if Table.HasColumns(table27, "ResourceId") then table27 else Table.AddColumn(table27, "ResourceId", each ""),
    table29 = if Table.HasColumns(table28, "ResourceName") then table28 else Table.AddColumn(table28, "ResourceName", each ""),
    table30 = if Table.HasColumns(table29, "ServiceInfo1") then table29 else Table.AddColumn(table29, "ServiceInfo1", each ""),
    table31 = if Table.HasColumns(table30, "ServiceInfo2") then table30 else Table.AddColumn(table30, "ServiceInfo2", each ""),
    table32 = if Table.HasColumns(table31, "AdditionalInfo") then table31 else Table.AddColumn(table31, "AdditionalInfo", each ""),
    table33 = if Table.HasColumns(table32, "Tags") then table32 else Table.AddColumn(table32, "Tags", each ""),
    table34 = if Table.HasColumns(table33, "InvoiceSectionId") then table33 else Table.AddColumn(table33, "InvoiceSectionId", each ""),
    table35 = if Table.HasColumns(table34, "InvoiceSection") then table34 else Table.AddColumn(table34, "InvoiceSection", each ""),
    table36 = if Table.HasColumns(table35, "CostCenter") then table35 else Table.AddColumn(table35, "CostCenter", each ""),
    table37 = if Table.HasColumns(table36, "UnitOfMeasure") then table36 else Table.AddColumn(table36, "UnitOfMeasure", each ""),
    table38 = if Table.HasColumns(table37, "ResourceGroup") then table37 else Table.AddColumn(table37, "ResourceGroup", each ""),
    table39 = if Table.HasColumns(table38, "ReservationId") then table38 else Table.AddColumn(table38, "ReservationId", each ""),
    table40 = if Table.HasColumns(table39, "ReservationName") then table39 else Table.AddColumn(table39, "ReservationName", each ""),
    table41 = if Table.HasColumns(table40, "ProductOrderId") then table40 else Table.AddColumn(table40, "ProductOrderId", each ""),
    table42 = if Table.HasColumns(table41, "ProductOrderName") then table41 else Table.AddColumn(table41, "ProductOrderName", each ""),
    table43 = if Table.HasColumns(table42, "IsAzureCreditEligible") then table42 else Table.AddColumn(table42, "IsAzureCreditEligible", each ""),
    table44 = if Table.HasColumns(table43, "PublisherName") then table43 else Table.AddColumn(table43, "PublisherName", each ""),
    table45 = if Table.HasColumns(table44, "OfferId") then table44 else Table.AddColumn(table44, "OfferId", each ""),
    table46 = if Table.HasColumns(table45, "Term") then table45 else Table.AddColumn(table45, "Term", each ""),
    table47 = if Table.HasColumns(table46, "PublisherName") then table46 else Table.AddColumn(table46, "PublisherName", each ""),
    table48 = if Table.HasColumns(table47, "ChargeType") then table47 else Table.AddColumn(table47, "ChargeType", each ""),
    table49 = if Table.HasColumns(table48, "Frequency") then table48 else Table.AddColumn(table48, "Frequency", each ""),
    source = if Table.HasColumns(table49, "PublisherType") then table49 else Table.AddColumn(table49, "PublisherType", each ""),
    result = Table.TransformColumnTypes(
            source,
            {
                {"BillingPeriodStartDate", type datetime},
                {"BillingPeriodEndDate", type datetime},
                {"Date", type datetime},
                {"EffectivePrice", type number},
                {"Quantity", type number},
                {"Cost", type number},
                {"UnitPrice", type number}
            },
            culture)

in
    result;

ReadCSVDataFromBlob = (url as text) =>
let
    Source = Csv.Document(Blob.Contents(url),[Delimiter = ",", Encoding = 1252, QuoteStyle = QuoteStyle.None]),
    Promote = Table.PromoteHeaders(Source)
in
    Promote;

/// Note: to get Usage details DataTable.
ReadCSVData = (csvString) as table =>
let
    data = Csv.Document(csvString, [Delimiter = ",", Encoding = 1252, QuoteStyle = QuoteStyle.None])
in
    Table.PromoteHeaders(data);


/// Note: to get Usage details DataTable.
ReadCSVDataSkipRows = (csvString, optional skipRows as number) as table =>
let
   source = Csv.Document(csvString,[Delimiter=",", Columns=14, Encoding=1252, QuoteStyle=QuoteStyle.None]),
   result = Table.Skip(source,skipRows)
in
    Table.PromoteHeaders(result);

/// Note: empty Usage details columns
CreateEmptyUsageDetailsData = () =>
let
    result = Table.FromList(
        {},
        Record.FieldValues,
        apiColumns_UsageDetailsByBillingProfile
        )
in
   Table.TransformColumnTypes(
            result,
            {
                {"billingPeriodStartDate", type datetime},
                {"billingPeriodEndDate", type datetime},
                {"servicePeriodStartDate", type datetime},
                {"servicePeriodEndDate", type datetime},
                {"effectivePrice", type number},
                {"exchangeRateDate", type datetime},
                {"quantity", type number},
                {"date", type datetime},
                {"costInBillingCurrency", type number},
                {"costInPricingCurrency", type number},
                {"exchangeRatePricingToBilling", type number}
            },
            culture);

/// Note: to get Credits
GetCredits = (billingAccountId as text, apiVersion as text, optional scope as text, optional billingProfileId as text) =>
let
    /// to get credit url.
    url = GetCreditsURL(billingAccountId, apiVersion, scope, billingProfileId),
    appType = if (billingProfileId <> null or scope = "billingAccount") then appTypeModern else appTypeLegacy,
    rawContent = GetWebContents(url, appType),
    asJson = try Json.Document(rawContent, 1252) otherwise null,
    jsonContent = if asJson is action then null else asJson meta Value.Metadata(rawContent),

    result = if scope = "billingProfile" then
                if jsonContent <> null then try CreateCreditScoreByBillingProfile(jsonContent) otherwise handleError() else CreateEmptyCreditScoreByBillingProfile()
             else
                if jsonContent <> null then try CreateCreditScoreByEnrollmentNumber(jsonContent) otherwise handleError() else CreateEmptyCreditScoreByEnrollmentNumber()
in
    result;

/// Note: to create empty score dataset on billing profile
CreateEmptyCreditScoreByBillingProfile = () =>
let
    result = Table.FromList(
        {},
        Record.FieldValues,
        apiColumns_Credits)
in
   Table.TransformColumnTypes(
        result,
        {
            {"estimatedBalance", type number},
            {"currentBalance", type number},
            {"expiredCredit", type number},
            {"pendingCreditAdjustments", type number},
            {"pendingEligibleCharges", type number}
        },
        culture);

/// Note: To create credit score data on billing profile
CreateCreditScoreByBillingProfile = (optional creditsRecord as record) =>
let
    source = Table.FromRecords(
    {
          [   id = creditsRecord[id],
              name = creditsRecord[name],
              type=creditsRecord[type],
              estimatedBalanceCurrency = try creditsRecord[properties][balanceSummary][estimatedBalance][currency] otherwise "",
              estimatedBalance = try creditsRecord[properties][balanceSummary][estimatedBalance][value] otherwise null,

              currentBalanceCurrency = try creditsRecord[properties][balanceSummary][currentBalance][currency] otherwise "",
              currentBalance = try creditsRecord[properties][balanceSummary][currentBalance][value] otherwise null,

              expiredCrediteCurrency = try creditsRecord[properties][expiredCredit][currency] otherwise "",
              expiredCredit = try creditsRecord[properties][expiredCredit][value] otherwise null,

              pendingCreditAdjustmentsCurrency = try creditsRecord[properties][pendingCreditAdjustments][currency] otherwise "",
              pendingCreditAdjustments = try creditsRecord[properties][pendingCreditAdjustments][value] otherwise null,

              pendingEligibleChargesCurrency = try creditsRecord[properties][pendingEligibleCharges][currency] otherwise "",
              pendingEligibleCharges = try creditsRecord[properties][pendingEligibleCharges][value] otherwise null
          ]
    }),

    /// creating a final Summary results to be printed
    result = Table.TransformColumnTypes(
        source,
        {
            {"estimatedBalance", type number},
            {"currentBalance", type number},
            {"expiredCredit", type number},
            {"pendingCreditAdjustments", type number},
            {"pendingEligibleCharges", type number}
        },
        culture)
in
     result;

/// Note: to create empty score dataset on enrollment Number
CreateCreditScoreByEnrollmentNumber = (optional creditsRecord as record) =>
let
    source = Table.FromRecords(
    {
          [   id = creditsRecord[id],
              name = creditsRecord[name],
              type=creditsRecord[type],
              currency = try creditsRecord[properties][currency] otherwise "",
              beginningBalance = try creditsRecord[properties][beginningBalance] otherwise null,
              endingBalance = try creditsRecord[properties][endingBalance] otherwise null,
              newPurchases = try creditsRecord[properties][newPurchases] otherwise null,
              adjustments = try creditsRecord[properties][adjustments] otherwise null,
              utilized = try creditsRecord[properties][utilized] otherwise null,
              serviceOverage = try creditsRecord[properties][serviceOverage] otherwise null,
              chargesBilledSeparately = try creditsRecord[properties][chargesBilledSeparately] otherwise null,
              totalOverage = try creditsRecord[properties][totalOverage] otherwise null,
              totalUsage = try creditsRecord[properties][totalUsage] otherwise null,
              azureMarketplaceServiceCharges = try creditsRecord[properties][azureMarketplaceServiceCharges] otherwise null,
              billingFrequency = try creditsRecord[properties][billingFrequency] otherwise "",
              priceHidden = try creditsRecord[properties][priceHidden] otherwise null,
              newPurchasesDetails = try creditsRecord[properties][newPurchasesDetails] otherwise null,
              adjustmentDetails = try creditsRecord[properties][adjustmentDetails] otherwise null
          ]
    }),
     /// creating a final Summary results to be printed
    result = Table.TransformColumnTypes(
        source,
        {
            {"beginningBalance", type number},
            {"endingBalance", type number},
            {"newPurchases", type number},
            {"adjustments", type number},
            {"utilized", type number},
            {"serviceOverage", type number},
            {"chargesBilledSeparately", type number},
            {"totalOverage", type number},
            {"totalUsage", type number},
            {"azureMarketplaceServiceCharges", type number}
        },
        culture)
in
    result;

/// Note: to create empty credit score dataset by enrollment Number
CreateEmptyCreditScoreByEnrollmentNumber = () =>
let
    result = Table.FromList(
        {},
        Record.FieldValues,
        apiColumns_CreditsByEnrollmentNumber)
in
   Table.TransformColumnTypes(
        result,
        {
            {"beginningBalance", type number},
            {"endingBalance", type number},
            {"newPurchases", type number},
            {"adjustments", type number},
            {"utilized", type number},
            {"serviceOverage", type number},
            {"chargesBilledSeparately", type number},
            {"totalOverage", type number},
            {"totalUsage", type number},
            {"azureMarketplaceServiceCharges", type number}
        },
        culture);

/// Note: to get Events
GetEvents = (billingAccountId as text, apiVersion as text, optional dateParameters as record, optional billingProfileId as text) =>
let
    /// to get events url.
    url = GetEventsURL(billingAccountId, apiVersion, dateParameters, billingProfileId),
    schema = GetSchemaForEntity("apiProperty"),
    appType = if billingProfileId <> null then appTypeModern else appTypeLegacy,
    jsonContent = GetAllPagesByNextLink(url, schema, appType),

    result = if(jsonContent <> null and Table.RowCount(jsonContent) > 0) then try CreateEventsData(jsonContent) otherwise handleError(jsonContent)
    else CreateEmptyEventsData()

in
    result;

/// Note: to create empty Events dataset
CreateEmptyEventsData = () =>
let
    result = Table.FromList(
        {},
        Record.FieldValues,
        apiColumns_Events)
in
   Table.TransformColumnTypes(
        result,
        {
           {"newCredit", type number},
           {"adjustments", type number},
           {"creditExpired", type number},
           {"charges", type number},
           {"closedBalance", type number}
        },
        culture);

/// Note: To create Events data
CreateEventsData = (optional eventsRecord as table) =>
let
    tempTable1 = Table.ExpandRecordColumn(eventsRecord,"properties",{"transactionDate","description","eventType","invoiceNumber","newCredit","adjustments","creditExpired","charges","closedBalance"}),

    tempTable2 = Table.ExpandRecordColumn(tempTable1,"newCredit",{"currency","value"}),
    tempTable3 = Table.RenameColumns(tempTable2, {{"currency","newCreditCurrency"},{"value","newCredit"}}),

    tempTable4 = Table.ExpandRecordColumn(tempTable3,"adjustments",{"currency","value"}),
    tempTable5 = Table.RenameColumns(tempTable4, {{"currency","adjustmentsCurrency"},{"value","adjustments"}}),

    tempTable6 = Table.ExpandRecordColumn(tempTable5,"creditExpired",{"currency","value"}),
    tempTable7 = Table.RenameColumns(tempTable6, {{"currency","creditExpiredCurrency"},{"value","creditExpired"}}),

    tempTable8 = Table.ExpandRecordColumn(tempTable7,"charges",{"currency","value"}),
    tempTable9 = Table.RenameColumns(tempTable8, {{"currency","chargesCurrency"},{"value","charges"}}),

    tempTable10 = Table.ExpandRecordColumn(tempTable9,"closedBalance",{"currency","value"}),
    source = Table.RenameColumns(tempTable10, {{"currency","closedBalanceCurrency"},{"value","closedBalance"}}),

    /// creating a final Summary results to be printed
    result = Table.TransformColumnTypes(
        source,
        {
            {"newCredit", type number},
            {"adjustments", type number},
            {"creditExpired", type number},
            {"charges", type number},
            {"closedBalance", type number}
        },
        culture)
in
    result;

/// Note: to get Lots
GetLots = (billingAccountId as text, apiVersion as text, billingProfileId as text) =>
let
    /// to get events url.
    url = GetLotsURL(billingAccountId, apiVersion, billingProfileId),
    appType = if billingProfileId <> null then appTypeModern else appTypeLegacy,
    schema = GetSchemaForEntity("apiProperty"),
    jsonContent = GetAllPagesByNextLink(url, schema, appType),

    result = if(jsonContent <> null and Table.RowCount(jsonContent) > 0) then try CreateLotsData(jsonContent) otherwise handleError(jsonContent)
    else CreateEmptyLotsData()

in
    result;

/// Note: to create empty lots dataset
CreateEmptyLotsData = () =>
let
    result = Table.FromList(
        {},
        Record.FieldValues,
        apiColumns_Lots)
in
   Table.TransformColumnTypes(
        result,
        {
            {"originalAmount", type number},
            {"closedBalance", type number},
            {"startDate", type datetime},
            {"expirationDate", type datetime}
        },
        culture);

/// Note: To create Lots data
CreateLotsData = (optional lotsRecord as table) =>
let
    tempTable1 = Table.ExpandRecordColumn(lotsRecord,"properties",{"source","startDate","expirationDate","poNumber","originalAmount","closedBalance"}),

    tempTable2 = Table.ExpandRecordColumn(tempTable1,"originalAmount",{"currency","value"}),
    tempTable3 = Table.RenameColumns(tempTable2, {{"currency","originalAmountCurrency"},{"value","originalAmount"}}),

    tempTable4 = Table.ExpandRecordColumn(tempTable3,"closedBalance",{"currency","value"}),
    source = Table.RenameColumns(tempTable4, {{"currency","closedBalanceCurrency"},{"value","closedBalance"}}),

    /// creating a final Summary results to be printed
    result = Table.TransformColumnTypes(
        source,
        {
            {"originalAmount", type number},
            {"closedBalance", type number},
            {"startDate", type datetime},
            {"expirationDate", type datetime}
        },
        culture)
in
    result;

/// Note: to get RI Charges details.
GetRICharges = (billingAccountId as text, apiVersion as text, optional scope as text, optional dateParameters as record, optional billingProfileId as text) =>
let
    /// to get RI Charges URL.
    url = GetRIChargesURL(billingAccountId, apiVersion, scope, dateParameters, billingProfileId),
    schema = GetSchemaForEntity("apiProperty"),
    appType = if (billingProfileId <> null or scope = "billingAccount") then appTypeModern else appTypeLegacy,
    jsonContent = GetAllPagesByNextLink(url, schema, appType),

    result = if scope = "billingProfile" then
                if(jsonContent <> null and Table.RowCount(jsonContent) > 0) then try CreateRIChargesByBillingProfile(jsonContent) otherwise handleError(jsonContent)
                    else CreateEmptyRIChargesByBillingProfile()
            else
                if(jsonContent <> null and Table.RowCount(jsonContent) > 0) then try CreateRIChargesByEnrollmentNumber(jsonContent) otherwise handleError(jsonContent)
                    else CreateEmptyRIChargesByEnrollmentNumber()
in
    result;

/// Note: to get RI Transactions
GetRITransactions = (billingAccountId as text, apiVersion as text, optional scope as text, optional dateParameters as record, optional billingProfileId as text) =>
let
    /// to get RI Transactions URL.
    url = GetRITransactionsURL(billingAccountId, apiVersion, scope, dateParameters, billingProfileId),
    schema = GetSchemaForEntity("ritransactionapiProperty"),
    appType = if (billingProfileId <> null or scope = "billingAccount") then appTypeModern else appTypeLegacy,
    jsonContent = GetAllPagesByNextLink(url, schema, appType),

    result = if scope = "billingProfile" then
                if(jsonContent <> null and Table.RowCount(jsonContent) > 0) then try CreateRITransactionsByBillingProfile(jsonContent) otherwise handleError(jsonContent)
                    else CreateEmptyRITransactionsByBillingProfile()
             else
                if(jsonContent <> null and Table.RowCount(jsonContent) > 0) then try CreateRITransactionsByEnrollmentNumber(jsonContent) otherwise handleError(jsonContent)
                    else CreateEmptyRITransactionsByEnrollment()
in
    result;

/// Note: to create empty RICharges dataset by billing Profile
CreateEmptyRIChargesByBillingProfile = () =>
let
    result = Table.FromList(
        {},
        Record.FieldValues,
        apiColumns_RIChargesByBillingProfile)
in
   Table.TransformColumnTypes(
        result,
        {
            {"transactionDate", type datetime},
            {"transactionAmount", type number},
            {"quantity", type number}
        },
        culture);

/// Note: To create RICharges dataset by billing Profile
CreateRIChargesByBillingProfile = (optional riChargesRecord as table) =>
let
    tempTable1 = Table.ExpandRecordColumn(riChargesRecord,"properties",{"orderId","orderName","quantity","subscriptionId","kind","date","invoice","productDescription","transactionType",
    "transactionAmount","invoiceSectionId","billingProfileId"}),

    tempTable2 = Table.RenameColumns(tempTable1, {"date","transactionDate"}),

    tempTable3 = Table.ExpandRecordColumn(tempTable2,"transactionAmount",{"currency","value"}),
    source = Table.RenameColumns(tempTable3, {{"currency","transactionAmountCurrency"},{"value","transactionAmount"}}),

    /// creating a final Summary results to be printed
    result = Table.TransformColumnTypes(
        source,
        {
            {"transactionDate", type datetime},
            {"transactionAmount", type number},
            {"quantity", type number}
        },
        culture)
in
    result;

/// Note: to create empty RICharges dataset by enrollment Number
CreateEmptyRIChargesByEnrollmentNumber = () =>
let
    result = Table.FromList(
        {},
        Record.FieldValues,
        apiColumns_RIChargesByEnrollment)
in
   Table.TransformColumnTypes(
        result,
        {
            {"eventDate", type datetime},
            {"amount", type number},
            {"quantity", type number}
        },
        culture);

/// Note: To create RICharges dataset by enrollment Number
CreateRIChargesByEnrollmentNumber = (optional riChargesRecord as table) =>
let
    source = Table.ExpandRecordColumn(riChargesRecord,"properties",{"amount","currency","description","eventDate","eventType","quantity","reservationOrderId","reservationOrderName"}),

    /// creating a final Summary results to be printed
    result = Table.TransformColumnTypes(
        source,
        {
            {"eventDate", type datetime},
            {"amount", type number},
            {"quantity", type number}
        },
        culture)
in
    result;

/// Note: to create empty RITransactions dataset by billing profile
CreateEmptyRITransactionsByBillingProfile = () =>
let
    result = Table.FromList(
        {},
        Record.FieldValues,
        apiColumns_RITransactionsByBillingProfile)

in
    Table.TransformColumnTypes(
    result,
    {},
    culture);

CreateRITransactionsByBillingProfile = (optional riTransactionsRecord as table) =>
let
    tempTable1 = Table.ExpandRecordColumn(riTransactionsRecord, "properties", apiColumns_RITransactionsByBillingProfile),
    result = Table.TransformColumnTypes(tempTable1, {"quantity", type number})
in
    result;

CreateEmptyRITransactionsByEnrollment = () =>
let
    result = Table.FromList(
        {},
        Record.FieldValues,
        apiColumns_RITransactionsByEnrollment)
in
    Table.TransformColumnTypes(
    result,
    {},
    culture);

CreateRITransactionsByEnrollmentNumber = (optional riTransactionRecord as table) =>
let
    tempTable1 = Table.ExpandRecordColumn(riTransactionRecord, "properties", apiColumns_RITransactionsByEnrollment),
    tempTable2 = Table.RenameColumns(tempTable1, {"currency", "transactionAmountCurrency"}),

    result = Table.TransformColumnTypes(tempTable2, {"quantity", type number})
in
    result;

/// Note: to get Recommendations Single.
GetRecommendationsSingle = (billingAccountId as text, apiVersion as text, lookBackPeriod as number, optional scope as text, optional billingProfileId as text) =>
let
     /// to get recommendations Single URL.
    url = GetRecommendationsSingleURL(billingAccountId, apiVersion, lookBackPeriod, scope, billingProfileId),
    schema = GetSchemaForEntity("apiProperty"),
    appType = if (billingProfileId <> null or scope = "billingAccount") then appTypeModern else appTypeLegacy,
    jsonContent = GetAllPagesByNextLink(url, schema, appType),

    result = if scope = "billingProfile" then
                  if(jsonContent <> null and Table.RowCount(jsonContent) > 0)  then
                        try CreateRecommendationsSingleByBillingProfile(jsonContent) otherwise handleError(jsonContent)
                  else
                        CreateEmptyRecommendationsSingleByBillingProfile()
            else
                  if(jsonContent <> null and Table.RowCount(jsonContent) > 0) then
                        try CreateRecommendationsSingleByEnrollment(jsonContent) otherwise handleError(jsonContent)
                  else
                        CreateEmptyRecommendationsSingleByEnrollment()
in
    result;

/// Note: to create empty RecommendationsSingle by billingProfile
CreateEmptyRecommendationsSingleByBillingProfile = () =>
let
    result = Table.FromList(
        {},
        Record.FieldValues,
        apiColumns_RecommendationSingle)
in
    Table.TransformColumnTypes(
        result,
        {
            {"recommendedQuantity", type number},
            {"costWithNoReservedInstances", type number},
            {"totalCostWithReservedInstances", type number},
            {"netSavings", type number},
            {"firstUsageDate", type datetime}
        },
        culture);

/// Note: To create RecommendationsSingle By BillingProfile
CreateRecommendationsSingleByBillingProfile = (optional recommendationsSingleRecord as table) =>
let
    tempTable1 = Table.ExpandRecordColumn(recommendationsSingleRecord,"properties",{"subscriptionId","meterId","term","recommendedQuantity","firstUsageDate", "scope", "lookBackPeriod","costWithNoReservedInstances",
      "totalCostWithReservedInstances","netSavings", "instanceFlexibilityGroup", "instanceFlexibilityRatio", "location", "resourceType", "skuName", "skuProperties"}),
    tempTable2 = Table.ExpandRecordColumn(tempTable1,"costWithNoReservedInstances",{"currency","value"}),
    tempTable3 = Table.RenameColumns(tempTable2, {{"currency","costWithNoReservedInstancesCurrency"},{"value","costWithNoReservedInstances"}}),

    tempTable4 = Table.ExpandRecordColumn(tempTable3,"totalCostWithReservedInstances",{"currency","value"}),
    tempTable5 = Table.RenameColumns(tempTable4, {{"currency","totalCostWithReservedInstancesCurrency"},{"value","totalCostWithReservedInstances"}}),

    tempTable6 = Table.ExpandRecordColumn(tempTable5,"netSavings",{"currency","value"}),
    source = Table.RenameColumns(tempTable6, {{"currency","netSavingsCurrency"},{"value","netSavings"}}),

    /// creating a final Summary results to be printed
    result = Table.TransformColumnTypes(
        source,
        {
            {"recommendedQuantity", type number},
            {"costWithNoReservedInstances", type number},
            {"totalCostWithReservedInstances", type number},
            {"netSavings", type number},
            {"firstUsageDate", type datetime}
        },
        culture)
in
    result;

/// Note: to create Recommendations Single by Enrollment Number
CreateRecommendationsSingleByEnrollment= (optional recommendationsSingleRecord as table) =>
let
    source = Table.ExpandRecordColumn(recommendationsSingleRecord,"properties",{"meterId","term", "costWithNoReservedInstances", "recommendedQuantity","totalCostWithReservedInstances","netSavings",
    "firstUsageDate", "scope", "lookBackPeriod", "instanceFlexibilityRatio", "instanceFlexibilityGroup", "normalizedSize", "recommendedQuantityNormalized","skuProperties"}),

    /// creating a final Summary results to be printed
    result = Table.TransformColumnTypes(
        source,
        {
            {"costWithNoReservedInstances", type number},
            {"recommendedQuantity", type number},
            {"totalCostWithReservedInstances", type number},
            {"netSavings", type number},
            {"firstUsageDate", type datetime}
        },
        culture)
in
    result;

/// Note: to create empty Recommendations Single by Enrollment Number
CreateEmptyRecommendationsSingleByEnrollment = () =>
let
    result = Table.FromList(
        {},
        Record.FieldValues,
        apiColumns_RecommendationSingleByEnrollment)
in
    Table.TransformColumnTypes(
        result,
        {
            {"costWithNoReservedInstances", type number},
            {"recommendedQuantity", type number},
            {"totalCostWithReservedInstances", type number},
            {"netSavings", type number},
            {"firstUsageDate", type datetime}
        },
        culture);

/// Note: to get Recommendations Shared.
GetRecommendationsShared = (billingAccountId as text, apiVersion as text, lookBackPeriod as number, optional scope as text, optional billingProfileId as text) =>
let
    /// to get recommendations Shared URL.
    url = GetRecommendationsSharedURL(billingAccountId, apiVersion, lookBackPeriod, scope, billingProfileId),
    schema = GetSchemaForEntity("apiProperty"),
    appType = if (billingProfileId <> null or scope = "billingAccount") then appTypeModern else appTypeLegacy,
    jsonContent = GetAllPagesByNextLink(url, schema, appType),

    result = if scope = "billingProfile" then
                if(jsonContent <> null and Table.RowCount(jsonContent) > 0) then
                    try CreateRecommendationsSharedByBillingProfile(jsonContent) otherwise handleError(jsonContent)
                else
                    CreateEmptyRecommendationsSharedByBillingProfile()
        else
                if(jsonContent <> null and Table.RowCount(jsonContent) > 0) then
                    try CreateRecommendationsSharedByEnrollment(jsonContent) otherwise handleError(jsonContent)
                else
                    CreateEmptyRecommendationsSharedByEnrollment()

in
    result;

/// Note: to create empty RecommendationsShared dataset
CreateEmptyRecommendationsSharedByBillingProfile = () =>
let
    result = Table.FromList(
        {},
        Record.FieldValues,
        apiColumns_RecommendationShared)
in
    Table.TransformColumnTypes(
        result,
        {
            {"recommendedQuantity", type number},
            {"costWithNoReservedInstances", type number},
            {"totalCostWithReservedInstances", type number},
            {"netSavings", type number},
            {"firstUsageDate", type datetime}
        },
        culture);

/// Note: To create RecommendationsShared data
CreateRecommendationsSharedByBillingProfile = (optional recommendationsSharedRecord as table) =>
let
    tempTable1 = Table.ExpandRecordColumn(recommendationsSharedRecord,"properties",{"meterId","term","recommendedQuantity","firstUsageDate","scope","lookBackPeriod","costWithNoReservedInstances",
    "totalCostWithReservedInstances","netSavings", "instanceFlexibilityGroup", "instanceFlexibilityRatio", "location", "normalizedSize", "resourceType", "skuName", "skuProperties"
    }),

    tempTable2 = Table.ExpandRecordColumn(tempTable1,"costWithNoReservedInstances",{"currency","value"}),
    tempTable3 = Table.RenameColumns(tempTable2, {{"currency","costWithNoReservedInstancesCurrency"},{"value","costWithNoReservedInstances"}}),

    tempTable4 = Table.ExpandRecordColumn(tempTable3,"totalCostWithReservedInstances",{"currency","value"}),
    tempTable5 = Table.RenameColumns(tempTable4, {{"currency","totalCostWithReservedInstancesCurrency"},{"value","totalCostWithReservedInstances"}}),

    tempTable6 = Table.ExpandRecordColumn(tempTable5,"netSavings",{"currency","value"}),
    source = Table.RenameColumns(tempTable6, {{"currency","netSavingsCurrency"},{"value","netSavings"}}),

    /// creating a final Summary results to be printed
    result = Table.TransformColumnTypes(
        source,
        {
            {"recommendedQuantity", type number},
            {"costWithNoReservedInstances", type number},
            {"totalCostWithReservedInstances", type number},
            {"netSavings", type number},
            {"firstUsageDate", type datetime}
        },
        culture)
in
    result;

/// Note: to create empty RecommendationsShared dataset
CreateEmptyRecommendationsSharedByEnrollment = () =>
let
    result = Table.FromList(
        {},
        Record.FieldValues,
        apiColumns_RecommendationSharedByEnrollment)
in
    Table.TransformColumnTypes(
        result,
        {
            {"costWithNoReservedInstances", type number},
            {"recommendedQuantity", type number},
            {"totalCostWithReservedInstances", type number},
            {"netSavings", type number},
            {"firstUsageDate", type datetime}
        },
        culture);

/// Note: To create RecommendationsShared data
CreateRecommendationsSharedByEnrollment = (optional recommendationsSharedRecord as table) =>
let
    source = Table.ExpandRecordColumn(recommendationsSharedRecord,"properties",{"meterId","term","costWithNoReservedInstances","recommendedQuantity","totalCostWithReservedInstances","netSavings","firstUsageDate",
    "scope","lookBackPeriod","instanceFlexibilityRatio","instanceFlexibilityGroup","normalizedSize","recommendedQuantityNormalized","skuProperties"}),

    /// creating a final Summary results to be printed
    result = Table.TransformColumnTypes(
        source,
        {
            {"costWithNoReservedInstances", type number},
            {"recommendedQuantity", type number},
            {"totalCostWithReservedInstances", type number},
            {"netSavings", type number},
            {"firstUsageDate", type datetime}
        },
        culture)
in
    result;

/// Note: to get RIUsage details.
GetRIUsage = (billingAccountId as text, apiVersion as text, optional scope as text, optional dateParameters as record, optional billingProfileId as text) =>
let
    /// to get RI Usage URL.
    url = GetRIUsageURL(billingAccountId, apiVersion, scope, dateParameters, billingProfileId),
    appType = if billingProfileId <> null then appTypeModern else appTypeLegacy,
    rawContent = QueueDataEx(url, appType, true),
    metaData = Value.Metadata(rawContent),
    locationUri = if Record.HasFields(metaData[Headers], {"Location"})
                    then metaData[Headers][Location]
                  else
                    null,
    data = if locationUri <> null then
                Value.WaitFor(
                    (i) =>
                        let
                            data = GetDataWithPollingExRIUsage(locationUri, appType),
                            response = if data <> null
                                           then data
                                       else null
                        in
                            response,
                    (i) => #duration(0, 0, 0, i*0.5),
                    3) // download call will be retried three times
            else [status="failed"],
      result =
            if data <> null then
                if Text.Lower(data[status]) = "completed" then
                    (let result = data[properties]
                        in (
                            if(appType = appTypeModern) then
                                if (result[reportUrl] <> null) then GetAsyncRIUsageDetailsByBillingProfile(result[reportUrl])
                                else CreateEmptyAsyncRIUsageDetailsByBillingProfile()
                            else
                                if (result[reportUrl] <> null) then GetAsyncRIUsageDetailsByEnrollment(result[reportUrl])
                                else CreateEmptyAsyncRIUsageDetailsByEnrollment())
                    )
                else // status = "failed" or locationUri not found
                    Error.Record("RI Usage Details failed - Could not retrieve Web.Contents",
                                 "Status: Failed",
                                 "OperationResults: " & Text.AfterDelimiter(locationUri, "reservationDetailsOperationResults/"))
            else // status = "running"
                Error.Record("RI Usage Details timeout - Could not retrieve polling URL",
                             "Status: Running",
                             "OperationResults: " & Text.AfterDelimiter(locationUri, "reservationDetailsOperationResults/"))
    in
        result;

/// Note: to create empty RIUsage dataset
CreateEmptyAsyncRIUsageDetailsByBillingProfile = () =>
    let
        result = Table.FromList(
            {},
            Record.FieldValues,
            apiColumns_RIUsage)
    in
       Table.TransformColumnTypes(
        result,
            {
                {"totalReservedQuantity", type number},
                {"usageDate", type datetime}
            },
        culture);

/// Note: To create RIUsage data
GetAsyncRIUsageDetailsByBillingProfile = (optional riUsageRecord as text) =>
let
    riUsageDataRecord = ReadCSVData(Blob.Contents(riUsageRecord)),

    /// creating a final Summary results to be printed
    renamedTable = Table.RenameColumns(
        riUsageDataRecord,
        {
            {"InstanceId", "name"},
            {"InstanceFlexibilityRatio", "instanceFlexibilityRatio"},
            {"InstanceFlexibilityGroup", "instanceFlexibilityGroup"},
            {"Kind", "type"},
            {"ReservationId", "reservationId"},
            {"ReservationOrderId", "reservationOrderId"},
            {"ReservedHours", "reservedHours"},
            {"SkuName", "skuName"},
            {"TotalReservedQuantity", "totalReservedQuantity"},
            {"UsageDate", "usageDate"},
            {"UsedHours", "usedHours"}
        }
    ),
    result = Table.TransformColumnTypes(
        renamedTable,
        {
            {"totalReservedQuantity", type number},
            {"usageDate", type datetime}
        },
    culture)
in
    result;

/// Note: To create RIUsage details data
GetAsyncRIUsageDetailsByEnrollment = (optional riUsageDetailsRecord as text) =>
let
    riUsageDetailsDataRecord = ReadCSVData(Blob.Contents(riUsageDetailsRecord)),

    /// creating a final Summary results to be printed
    renamedTable = Table.RenameColumns(
        riUsageDetailsDataRecord,
        {
            {"InstanceId", "name"},
            {"InstanceFlexibilityRatio", "instanceFlexibilityRatio"},
            {"InstanceFlexibilityGroup", "instanceFlexibilityGroup"},
            {"Kind", "type"},
            {"ReservationId", "reservationId"},
            {"ReservationOrderId", "reservationOrderId"},
            {"ReservedHours", "reservedHours"},
            {"SkuName", "skuName"},
            {"TotalReservedQuantity", "totalReservedQuantity"},
            {"UsageDate", "usageDate"},
            {"UsedHours", "usedHours"}
        }
    ),
    result = Table.TransformColumnTypes(
        renamedTable,
        {
            {"totalReservedQuantity", type number},
            {"usageDate", type datetime},
            {"reservedHours", type number},
            {"usedHours", type number}
        },
        culture)
in
    result;

/// Note: to create empty RIUsage dataset
CreateEmptyAsyncRIUsageDetailsByEnrollment = () =>
    let
        result = Table.FromList(
            {},
            Record.FieldValues,
            apiColumns_RIUsageDetails)
    in
       Table.TransformColumnTypes(
        result,
        {
            {"totalReservedQuantity", type number},
            {"usageDate", type datetime},
            {"reservedHours", type number},
            {"usedHours", type number}
        },
        culture);

/// Note: to get RIUsage details.
GetRIUsageSummary = (billingAccountId as text, apiVersion as text, optional scope as text, optional dateParameters as record, optional billingProfileId as text) =>
let
    /// to get RI Usage URL.
    url = GetRIUsageSummaryURL(billingAccountId, apiVersion, scope, dateParameters, billingProfileId),
    schema = GetSchemaForEntity("apiProperty"),
    appType = if (billingProfileId <> null or scope = "billingAccount") then appTypeModern else appTypeLegacy,
    jsonContent = GetAllPagesByNextLink(url, schema, appType),

    result = if scope = "billingProfile" then
                if(jsonContent <> null and Table.RowCount(jsonContent) > 0) then try CreateRIUsageSummaryByBillingProfile(jsonContent) otherwise handleError(jsonContent) else CreateEmptyRIUsageSummaryByBillingProfile()
             else
                if(jsonContent <> null and Table.RowCount(jsonContent) > 0) then try CreateRIUsageSummaryByEnrollment(jsonContent) otherwise handleError(jsonContent) else CreateEmptyRIUsageSummaryByEnrollment()
in
    result;

/// Note: to get RIUsage summary URL
GetRIUsageSummaryURL = (billingAccountId as text, apiVersion as text, optional scope as text, optional dateParameters as record, optional billingProfileId as text) =>
let
    finalDateParameters = if dateParameters <> null then dateParameters
        else GetDatesForLastNMonth(1),

    apiVersion = if(apiVersion <> "") then apiVersion else latestApiVersion,
    result = if scope = "billingAccount" then
                let
                    query = "?grain=daily&startDate=" & finalDateParameters[startTime] & "&endDate=" & finalDateParameters[endTime],
                    result = GetBillingAccountUri() & billingAccountId & "/providers/Microsoft.Consumption/reservationsummaries?" & query & "&api-version=" & apiVersion
                in
                    result
            else if scope = "billingProfile" then
                let
                    query = "?grain=daily&startDate=" & finalDateParameters[startTime] & "&endDate=" & finalDateParameters[endTime],
                    result = GetBillingAccountUri() & billingAccountId &"/billingProfiles/"& billingProfileId &"/providers/Microsoft.Consumption/reservationsummaries?" & query & "&api-version=" & apiVersion
                in
                    result
            else
                let
                     query = "&grain=daily&$filter=properties/UsageDate+ge+" & finalDateParameters[startTime] & "+AND+properties/UsageDate+le+" & finalDateParameters[endTime],
                     result = GetBillingAccountUri() & billingAccountId & "/providers/Microsoft.Consumption/reservationsummaries?api-version=" & apiVersion  & query
                in
                    result
in
    result;

/// Note: to create empty RIUsage dataset
CreateEmptyRIUsageSummaryByBillingProfile = () =>
    let
        result = Table.FromList(
            {},
            Record.FieldValues,
            apiColumns_RIUsageSummary)
    in
       Table.TransformColumnTypes(
        result,
        {
            {"usageDate", type datetime}
        },
        culture);

/// Note: To create RIUsage data
CreateRIUsageSummaryByBillingProfile = (optional riUsageRecord as table) =>
let
    source = Table.ExpandRecordColumn(riUsageRecord,"properties",{"reservationOrderId","reservationId","usageDate","skuName","avgUtilizationPercentage","minUtilizationPercentage","maxUtilizationPercentage","reservedHours","usedHours"}),

    /// creating a final Summary results to be printed
    result = Table.TransformColumnTypes(
        source,
        {
            {"reservedHours", type number},
            {"usedHours", type number},
            {"usageDate", type datetime}
        },
        culture)
in
    result;

/// Note: to create empty RIUsage dataset
CreateEmptyRIUsageSummaryByEnrollment = () =>
    let
        result = Table.FromList(
            {},
            Record.FieldValues,
            apiColumns_RIUsageSummary)
    in
       Table.TransformColumnTypes(
        result,
        {
            {"reservedHours", type number},
            {"usedHours", type number},
            {"usageDate", type datetime}
        },
        culture);

/// Note: To create RIUsage data
CreateRIUsageSummaryByEnrollment = (optional riUsageRecord as table) =>
let
    source = Table.ExpandRecordColumn(riUsageRecord,"properties",{"reservationOrderId","reservationId","usageDate","skuName","avgUtilizationPercentage","minUtilizationPercentage","maxUtilizationPercentage","reservedHours","usedHours"}),

    /// creating a final Summary results to be printed
    result = Table.TransformColumnTypes(
        source,
        {
            {"reservedHours", type number},
            {"usedHours", type number},
            {"usageDate", type datetime}
        },
        culture)
in
    result;

GetDatesForLastNMonth = (numberOfMonth as number) =>
    let
        endTimeParameter = Date.ToText(Date.From(DateTime.LocalNow()), "yyyy-MM-dd"),
        tempDate = Date.AddMonths(Date.From(DateTime.LocalNow()), (-1) * numberOfMonth),
        startTimeParameter = Date.ToText(Date.StartOfMonth(tempDate), "yyyy-MM-dd"),
        result = [startTime = startTimeParameter, endTime = endTimeParameter]
    in
        if (numberOfMonth > 36) or (numberOfMonth < 1) then error Extension.LoadString("NumberOfMonthOutOfRange")
             else result;

GetDatesFromParameters = (startDate ,endDate ) =>
    let
        differenceInDays = Duration.TotalDays(endDate-startDate), // Calculating number of days
        startDateParameter =  Date.ToText(startDate, "yyyy-MM-dd"),
        endDateParameter = Date.ToText(endDate, "yyyy-MM-dd"),
        result = [startTime = startDateParameter, endTime = endDateParameter]
    in
        if (differenceInDays > 31) then  error(Extension.LoadString("DateRangeMoreThan31Days"))
        else if (differenceInDays < 0)  then error(Extension.LoadString("StartDateGreaterThanEndDate"))
        else  result;

IsNoStatementAvailableError = (content as binary) =>
    let
        result = (Value.Metadata(content)[Response.Status] = 400) and (Text.Contains(Json.Document(content, 1252)[error][message], "No Statements available"))
    in
        result;

/// Note: to discover tenants and billing account Id.
GetInfoByProfileId = (billingProfileId as text) =>
let
    query = defaultBillingAccountId & "/billingProfiles/" & billingProfileId & discoverTenantsUri,
    uri = GetTenantDiscoveryUri() & contentPackApiPrefix & query,
    content = GetWebContents(uri, appTypeModern),

    asJson = try Json.Document(content, 1252) otherwise null,
    tenantInfo = if asJson is action then null else asJson meta Value.Metadata(content),

    result = try tenantInfo[properties] otherwise null

in
    result;

/// Note: to post the content and get download url.
QueueData = (billingAccount as text, apiVersion as text, url as text, optional billingProfile as text, optional appType as text, optional disableArchive as logical) =>
let
    payload = if(appType = appTypeModern and disableArchive = true) then
    [
        reportType = postReport_reportType,
        client = client_type,
        pageSize = postReport_pageSize,
        format = postReport_format,
        normalized = postReport_normalized,
        disableArchive = true // new header for the pricesheet api to disable the zip archive and return raw csv urls
    ]
    else
    [
        reportType = postReport_reportType,
        client = client_type,
        pageSize = postReport_pageSize,
        format = postReport_format,
        normalized = postReport_normalized
    ],

    content = Json.FromValue(payload),
    result = GetWebContents(url, appType, false, content)
in
    result;

/// Note: This function is the same as the one below, using locationUri in place of statusUri
GetDataWithPollingExRIUsage = (locationUri as text, optional appType as text) =>
    Value.WaitFor(
        (i) =>
            let
                rawContent = GetWebContents(locationUri, appType, true),
                asJson = try Json.Document(rawContent, 1252) otherwise null,
                data = if asJson is action then null else asJson meta Value.Metadata(rawContent),
                statusText = Text.Lower(data[status]),
                result = if statusText = "pending"
                            then null
                         else if statusText = "running"
                            then null
                         else data // "completed" or "failed"
            in
                result,

            (i) => #duration(0, 0, 0, i * 0.5), 100);

/// Note: Function is exponentially weighted, and has a maximum refresh count of 40
GetDataWithPollingEx = (locationUri as text, statusUri as text, optional appType as text) =>
    Value.WaitFor(
        (i) =>
            let
                rawContent = GetWebContents(locationUri, appType, true),
                asJson = try Json.Document(rawContent, 1252) otherwise null,
                data = if asJson is action then null else asJson meta Value.Metadata(rawContent),

                statusText = ParseReportStatus(statusUri, appType),
                result = if (statusText = "0" or statusText = "none" or // None
                             statusText = "1" or statusText = "queued" or // Queued
                             statusText = "2" or statusText = "inprogress" or // InProgress
                             statusText = "3" or statusText = "processing" or // processing
                             statusText = "6" or statusText = "readytodownload") // ReadyToDownload
                     then null
                     else data
            in
                result,

        (i) => #duration(0, 0, 0, i * 1), 100);

/// Note: Function is exponentially weighted, and has a maximum refresh count of 40
GetDataWithPolling = (url as text, statusUri as text, optional appType as text) =>
    Value.WaitFor(
        (i) =>
            let
                rawContent = GetWebContents(url, appType, true),
                asJson = try Json.Document(rawContent, 1252) otherwise null,
                jsonContent = if asJson is action then null else asJson meta Value.Metadata(rawContent),

                statusText = ParseReportStatus(statusUri, appType),
                result = if (statusText = "0" or statusText = "none" or // None
                             statusText = "1" or statusText = "queued" or // Queued
                             statusText = "2" or statusText = "inprogress" or // InProgress
                             statusText = "3" or statusText = "processing" or // processing
                             statusText = "6" or statusText = "readytodownload") // ReadyToDownload
                     then null
                     else jsonContent
            in
                result,
        (i) => #duration(0, 0, 0, i * 0.5),
        100);

/// Note: parse Report status.
ParseReportStatus = (url as text, optional appType as text) =>
    let

        rawContent = GetWebContents(url, appType, true, null),
        asJson = try Json.Document(rawContent, 1252) otherwise null,
        jsonContent = if asJson is action then null else asJson meta Value.Metadata(rawContent),

        result = if (jsonContent <> null) then Text.Lower(jsonContent[status]) else null
    in
        result;

/// Note: to populate and create an error table.
PopulateError = (optional errorText as text) =>
    let
        result = if(errorText <> "") then Table.FromRecords({[ErrorDesc = errorText]}) else
        Table.FromRecords({[ErrorDesc = Extension.LoadString("ReportGenerationFailed")]})
    in
        result;

Value.WaitFor = (producer as function, interval as function, optional count as number) as any =>
let
list = List.Generate(
    () => {0, null},
    (state) => state{0} <> null and (count = null or state{0} < count),
    (state) =>
        if state{1} <> null then {null, state{1}}
                else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), interval(state{0}))},
    (state) => state{1})
in
List.Last(list);

Blob.Contents = (url as text) =>
    let
        parts = Uri.Parts(url),
        fixedUri = Uri.FromParts(parts & [Query = []])
    in
        Blob.Contents.Internal(fixedUri, Uri.BuildQueryString(parts[Query]));

Blob.Contents.Internal = (url as text, token as text) =>
     Extension.InvokeWithCredentials(
         (datasource) => [ AuthenticationKind = "SAS", Token = token],
         () => AzureStorage.BlobContents(url));

Uri.FromParts = (parts) =>
    let
        port = if (parts[Scheme] = "https" and parts[Port] = 443) or (parts[Scheme] = "http" and parts[Port] = 80) then ""
             else ":" & Text.From(parts[Port]),
        div1 = if Record.FieldCount(parts[Query]) > 0 then "?"
             else "",
        div2 = if Text.Length(parts[Fragment]) > 0 then "#"
             else "",
        uri = Text.Combine(
            {parts[Scheme], "://", parts[Host], port, parts[Path], div1, Uri.BuildQueryString(parts[Query]), div2, parts[Fragment]})
    in
        uri;

Table.ToNavigationTable = (table as table, keyColumns as list, nameColumn as text, dataColumn as text, itemKindColumn as text, itemNameColumn as text, isLeafColumn as text) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta [
            NavigationTable.NameColumn = nameColumn,
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn,
            Preview.DelayColumn = itemNameColumn,
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

ConvertMonthKey = (monthkey as text) =>
    let
        date = Date.FromText(monthkey & "01")
    in
        Date.ToText(date, "yyyy-MM");

GetDateParameters = (parameters as record, numberOfMonths as number) =>
    let
        result = if parameters = null then null
             else if (Record.HasFields(parameters, "numberOfMonth") and (Record.HasFields(parameters, "startBillingDataWindow") or Record.HasFields(parameters, "endBillingDataWindow"))) then error Extension.LoadString("InvalidParameter")
             else if Record.HasFields(parameters, "numberOfMonth") then GetDatesForLastNMonth(parameters[numberOfMonths])
             else if Record.HasFields(parameters, "startBillingDataWindow") and Record.HasFields(parameters, "endBillingDataWindow") then CalculateDatesFromParameters(parameters)
             else if Record.HasFields(parameters, "startBillingDataWindow") or Record.HasFields(parameters, "endBillingDataWindow") then error Extension.LoadString("InvalidParameter")
             else if numberOfMonths <> null and numberOfMonths > 0 then GetDatesForLastNMonth(numberOfMonths)
             else  GetDatesForLastNMonth(Number.FromText(defaultMonthNumber))
    in
        result;

CalculateDatesFromParameters = (parameters as record) =>
    let
        result = [
            startTime = GetDateFromBillingDataWindow(parameters[startBillingDataWindow], false),
            endTime = GetDateFromBillingDataWindow(parameters[endBillingDataWindow], true)
        ]
    in
        if result[endTime] >= result[startTime] then result
             else error Extension.LoadString("InvalidTimeWindow");

GetDateFromBillingDataWindow = (billingDataWindow as text, isEnd as logical) =>
    let
        monthToAdd = Number.FromText(billingDataWindow),
        tempDate = Date.AddMonths(Date.From(DateTime.LocalNow()), monthToAdd)
    in
        if not isEnd then Date.ToText(Date.StartOfMonth(tempDate), "yyyy-MM-dd")
             else if monthToAdd = 0 then Date.ToText(tempDate, "yyyy-MM-dd")
             else Date.ToText(Date.AddDays(Date.StartOfMonth(tempDate), - 1), "yyyy-MM-dd");

AzureCostManagement.ContentsType =
    let
        scope = (type text) meta [
             Documentation.FieldCaption = Extension.LoadString("lbl_Choose_Scope"),
             Documentation.FieldDescription = Extension.LoadString("lbl_Choose_Scope"),
             Documentation.AllowedValues = { "Billing Profile Id", "Enrollment Number" },
             Documentation.SampleValues = {Extension.LoadString("Parameter_Choose_Scope")}
        ],
        scopeValue = (type text) meta [
             Documentation.FieldCaption = Extension.LoadString("lbl_BillingProfile_EnrollmentNumber"),
             Documentation.FieldDescription = Extension.LoadString("lbl_BillingProfile_EnrollmentNumber"),
             Documentation.SampleValues = {Extension.LoadString("Parameter_Scope_Value")}
        ],
        numberOfMonths = (type number) meta [
             Documentation.FieldCaption = Extension.LoadString("lbl_NumberOfMonths"),
             Documentation.FieldDescription = Extension.LoadString("lbl_NumberOfMonths"),
             Documentation.SampleValues = {Extension.LoadString("Parameter_Months")}
        ],
        parameters = (type record) meta [
            Documentation.FieldCaption = Extension.LoadString("Parameter_Parameter_FieldCaption"),
            Documentation.SampleValues = {Extension.LoadString("Parameter_Parameter_SampleValues")},
            Documentation.FieldDescription = Extension.LoadString("Parameter_Parameter_FieldDescription")
        ],
        t = type function (scope as scope, scopeValue as scopeValue, numberOfMonths as numberOfMonths, optional parameters as parameters) as table
    in
        t meta [
            Documentation.Description = Extension.LoadString("Function_Contents_Description"),
            Documentation.DisplayName = "Contents",
            Documentation.Caption = "AzureCostManagement.Contents",
            Documentation.Name = "AzureCostManagement.Contents",
            Documentation.LongDescription = Extension.LoadString("Function_Contents_Description"),
            Documentation.Examples = {
                [
                    Description = Extension.LoadString("CodeSample_1_Description"),
                    Code = Extension.LoadString("CodeSample_1_Code"),
                    Result = Extension.LoadString("CodeSample_1_Result")
                ],
                [
                    Description = Extension.LoadString("CodeSample_2_Description"),
                    Code = Extension.LoadString("CodeSample_2_Code"),
                    Result = Extension.LoadString("CodeSample_2_Result")
                ],
                [
                    Description = Extension.LoadString("CodeSample_3_Description"),
                    Code = Extension.LoadString("CodeSample_3_Code"),
                    Result = Extension.LoadString("CodeSample_3_Result")
                ]
            }
        ];

AzureCostManagement.TablesType =
    let
        scope = (type text) meta [
             Documentation.FieldCaption = Extension.LoadString("lbl_Choose_Scope"),
             Documentation.FieldDescription = Extension.LoadString("lblChooseScopeHelp"),
             Documentation.AllowedValues = {"Billing Profile Id", "Enrollment Number", "Manually Input Scope" },
             Documentation.SampleValues = {Extension.LoadString("Parameter_Choose_Scope")}
        ],
        scopeValue = (type text) meta [
             Documentation.FieldCaption = Extension.LoadString("Parameter_CustomScope"),
             Documentation.FieldDescription = Extension.LoadString("ParameterCustomScopeHelp"),
             Documentation.SampleValues = {Extension.LoadString("Parameter_CustomScope_Description")}
        ],
        numberOfMonths = (type number) meta [
             Documentation.FieldCaption = Extension.LoadString("lbl_NumberOfMonths"),
             Documentation.FieldDescription = Extension.LoadString("lblNumberOfMonthsHelp"),
              Documentation.SampleValues = {Extension.LoadString("Parameter_Months")}
        ],
        parameters = (type nullable [
                optional startDate = (type date meta [
                    Documentation.FieldCaption = Extension.LoadString("lbl_Start_Date"),
                    Documentation.FieldDescription = Extension.LoadString("lblStartDateHelp"),
                    Documentation.SampleValues = {Extension.LoadString("Parameter_StartDate")}
                ]),
               optional endDate = (type date meta [
                    Documentation.FieldCaption = Extension.LoadString("lbl_End_Date"),
                   Documentation.FieldDescription = Extension.LoadString("lblEndDateHelp"),
                   Documentation.SampleValues = {Extension.LoadString("Parameter_EndDate")}
                ])
            ] meta [
                Documentation.FieldCaption = Extension.LoadString("AdvancedOptionsLabel")
            ]),

        t = type function (scope as scope, scopeValue as scopeValue, numberOfMonths as numberOfMonths, optional options as parameters) as table
    in
        t meta [
            Documentation.Caption = Extension.LoadString("AzureCostManagement"),
            Documentation.Description = Extension.LoadString("AzureCostManagement"),
            Documentation.DisplayName = Extension.LoadString("AzureCostManagement"),
            Documentation.LongDescription = Extension.LoadString("AzureCostManagement"),
            Documentation.Name = Extension.LoadString("AzureCostManagement")
        ];
GetSchemaForEntity = (entity as text) as type =>
    try
        SchemaTable{[Entity=entity]}[Type]
    otherwise
        let
            message = Text.Format("Couldn't find entity: '#{0}'", {entity})
        in
            Diagnostics.Trace(TraceLevel.Error, message, () => error message, true);
//
// Read all pages of data.
// After every page, we check the "NextLink" record on the metadata of the previous request.
// Table.GenerateByPage will keep asking for more pages until we return null.
GetAllPagesByNextLink = (url as text, optional schema as type, optional appType as text) as nullable table =>
    Table.GenerateByPage((previous) =>
        let
            // if previous is null, then this is our first page of data
            nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
            // if NextLink was set to null by the previous call, we know we have no more data
            page = if (nextLink <> null and nextLink <> "") then GetPage(nextLink, schema, appType) else null

        in
            page
    );

GetPage = (url as text, optional schema as type, optional appType as text) as table =>
    let
        rawContent = GetWebContents(url, appType),
        asJson = try Json.Document(rawContent, 1252) otherwise null,
        body = if asJson is action then null else asJson meta Value.Metadata(rawContent),

        nextLink = GetNextLink(body),

        // Error Handling while navigation.
        result = if body = null
                    then error Error.Record("Response body is null; Status code: " & Text.From(Value.Metadata(rawContent)[Response.Status]?) & "Request ID: " & Text.From(Value.Metadata(rawContent)[Headers]?[#"x-ms-request-id"]?))
                 else if (Record.HasFields(body, {"error"})) then
                    error Error.Record(body[error][code]?, body[error][message]?, body)
                 else
                    body[value],

        // If we have no schema, use Table.FromRecords() instead
        // (and hope that our results all have the same fields).
        // If we have a schema, expand the record using its field names
         data =
            if (schema = null) then
                Diagnostics.LogFailure(
                    "Error converting response body. Are the records uniform?",
                    () => Table.FromRecords(result)
                )
            else
                let
                    // convert the list of records into a table (single column of records)
                    asTable = Table.FromList(result, Splitter.SplitByNothing(), {"Column1"}),
                    fields = Record.FieldNames(Type.RecordFields(Type.TableRow(schema))),
                    expanded = Table.ExpandRecordColumn(asTable, "Column1", fields)
                in
                    expanded
    in
        data meta [NextLink = nextLink];

// In this implementation, 'response' will be the parsed body of the response after the call to Json.Document.
// We look for the 'nextLink' field and simply return null if it doesn't exist.
GetNextLink = (response) as nullable text => Record.FieldOrDefault(response, "nextLink");

handleError = (body as record)=>
    let
        errorDesc = if (Record.HasFields(body, {"error"})) then
                    body[error][message]
                else
                    Extension.LoadString("ReportGenerationFailed")
    in
        PopulateError(errorDesc);



Value.ToText = (value, optional depth) =>

    /// Diagnostics-related functions are generic should be pulled into a separate module
    let
        nextDepth = if depth = null then 3
             else depth - 1,
        result = if depth = 0 then "..."
             else if value is null then "<null>"
             else if value is function then "<function>"
             else if value is table then "#table({" & Text.Combine(Table.ColumnNames(value), ",") & "},{" & Text.Combine(List.Transform(Table.ToRows(Table.FirstN(value, 2)), each @Value.ToText(_, nextDepth)), "},#(cr)#(lf){") & "})"
             else if value is list then "{" & Text.Combine(List.Transform(List.FirstN(value, 10), each @Value.ToText(_, nextDepth)), ",") & "}"
             else if value is record then "[" & Text.Combine(
                List.Transform(Record.FieldNames(value), each _ & "=" & @Value.ToText(Record.Field(value, _), nextDepth)),
                ",") & "]"
             else Text.From(value)
    in
        try result otherwise "<error>";


Value.IfNull = (a, b) =>
    if a <> null then a
         else b;

/// Note: Entities declaration
/// budget columns api columns
apiColumns_Budgets = {
    "name",
    "type",
    "eTag",
    "timePeriod",
    "startDate",
    "endDate",
    "timeGrain",
    "budgetAmount",
    "currentSpendAmount",
    "currentSpendUnit",
    "category",
    "notifications",
    "filter",
    "forecastAmount",
    "forecastUnit"
};


/// Note: charges columns api columns
apiColumns_Charges = {
    "name",
    "type",
    "eTag",
    "isInvoiced",
    "billingPeriodId",
    "usageStart",
    "usageEnd",
    "billingAccountId",
    "billingProfileId",
    "invoiceSectionId",
    "azureChargesCurrency",
    "azureCharges",
    "chargesBilledSeparatelyCurrency",
    "chargesBilledSeparately",
    "marketPlaceChargesCurrency",
    "marketPlaceCharges"
};

/// Note: Credits api columns
apiColumns_Credits = {
    "id",
    "name",
    "type",
    "estimatedBalanceCurrency",
    "estimatedBalance",
    "currentBalanceCurrency",
    "currentBalance",
    "expiredCreditCurrency",
    "expiredCredit",
    "pendingCreditAdjustmentsCurrency",
    "pendingCreditAdjustments",
    "pendingEligibleChargesCurrency",
    "pendingEligibleCharges"
};

apiColumns_CreditsByEnrollmentNumber = {
    "id",
    "name",
    "type",
    "adjustmentDetails",
    "adjustments",
    "azureMarketplaceServiceCharges",
    "beginningBalance",
    "billingFrequency",
    "marketplaceCharges",
    "chargesBilledSeparately",
    "currency",
    "endingBalance",
    "newPurchases",
    "newPurchasesDetails",
    "priceHidden",
    "serviceOverage",
    "totalOverage",
    "totalUsage",
    "utilized"
};

/// Note: Events api columns
apiColumns_Events = {
    "type",
    "name",
    "newCreditCurrency",
    "newCredit",
    "transactionDate",
    "description",
    "eventType",
    "invoiceNumber",
    "adjustmentsCurrency",
    "adjustments",
    "creditExpiredCurrency",
    "creditExpired",
    "chargesCurrency",
    "charges",
    "closedBalanceCurrency",
    "closedBalance"
};

/// Note: Lots api columns
apiColumns_Lots = {
    "type",
    "name",
    "source",
    "startDate",
    "expirationDate",
    "poNumber",
    "originalAmountCurrency",
    "originalAmount",
    "closedBalanceCurrency",
    "closedBalance"
};

/// Note: RI Charges api columns
apiColumns_RIChargesByBillingProfile = {
    "type",
    "name",
    "orderId",
    "orderName",
    "quantity",
    "subscriptionId",
    "kind",
    "transactionDate",
    "invoice",
    "productDescription",
    "transactionType",
    "transactionAmountCurrency",
    "transactionAmount",
    "invoiceSectionId",
    "billingProfileId"
};

/// Note: RI Charges api columns
apiColumns_RIChargesByEnrollment = {
    "amount",
    "currency",
    "description",
    "eventDate",
    "eventType",
    "quantity",
    "reservationOrderId",
    "reservationOrderName"
};

/// Note: RI Transactions api columns by Billing Profile
apiColumns_RITransactionsByBillingProfile = {
    "amount",
    "armSkuName",
    "currency",
    "description",
    "eventDate",
    "eventType",
    "invoice",
    "invoiceId",
    "invoiceSectionId",
    "invoiceSectionName",
    "quantity",
    "region",
    "term",
    "reservationOrderId",
    "reservationOrderName",
    "billingProfileId",
    "billingProfileName",
    "purchasingSubscriptionGuid",
    "purchasingSubscriptionName",
    "billingFrequency"
};

/// Note: RI Transactions api columns by Enrollment
apiColumns_RITransactionsByEnrollment = {
    "amount",
    "armSkuName",
    "currency",
    "departmentName",
    "eventDate",
    "description",
    "eventType",
    "quantity",
    "region",
    "reservationOrderId",
    "reservationOrderName",
    "term",
    "purchasingEnrollment",
    "purchasingSubscriptionGuid",
    "purchasingSubscriptionName",
    "accountName",
    "accountOwnerEmail",
    "costCenter",
    "currentEnrollment",
    "billingFrequency"
};

/// Note: Price sheet api columns
apiColumns_Pricesheet = {
    "BasePrice",
    "BillingAccountId",
    "BillingAccountName",
    "BillingCurrency",
    "BillingGroupId",
    "EffectiveEndDate",
    "EffectiveStartDate",
    "MeterCategory",
    "MeterId",
    "MeterName",
    "MeterRegion",
    "MeterSubCategory",
    "MeterType",
    "PricingCurrency",
    "Product",
    "ProductId",
    "ProductOrderId",
    "ProductOrderName",
    "ServiceFamily",
    "SkuId",
    "TierMinimumUnits",
    "UnitOfMeasure",
    "UnitPrice",
    "Term",
    "PriceType"
};

/// Note: Price sheet target columns
tableColumns_Pricesheet = {
    "basePrice",
    "billingAccountId",
    "billingAccountName",
    "billingCurrency",
    "billingGroupId",
    "effectiveEndDate",
    "effectiveStartDate",
    "meterCategory",
    "meterId",
    "meterName",
    "meterRegion",
    "meterSubCategory",
    "meterType",
    "pricingCurrency",
    "product",
    "productId",
    "productOrderId",
    "productOrderName",
    "serviceFamily",
    "skuId",
    "tierMinimumUnits",
    "unitOfMeasure",
    "unitPrice",
    "term",
    "priceType"
};

/// Note: Usage Details api columns
apiColumns_UsageDetailsByBillingProfile = {
    "invoiceId",
    "previousInvoiceId",
    "billingAccountId",
    "billingAccountName",
    "billingProfileId",
    "billingProfileName",
    "invoiceSectionId",
    "invoiceSectionName",
    "costCenter",
    "billingPeriodStartDate",
    "billingPeriodEndDate",
    "servicePeriodStartDate",
    "servicePeriodEndDate",
    "date",
    "serviceFamily",
    "productOrderId",
    "productOrderName",
    "consumedService",
    "meterId",
    "meterName",
    "meterCategory",
    "meterSubCategory",
    "meterRegion",
    "productId",
    "product",
    "subscriptionId",
    "subscriptionName",
    "publisherType",
    "publisherName",
    "resourceGroupName",
    "resourceId",
    "resourceLocation",
    "location",
    "effectivePrice",
    "quantity",
    "unitOfMeasure",
    "chargeType",
    "pricingCurrency",
    "billingCurrency",
    "costInBillingCurrency",
    "costInPricingCurrency",
    "exchangeRatePricingToBilling",
    "exchangeRateDate",
    "isAzureCreditEligible",
    "serviceInfo1",
    "serviceInfo2",
    "additionalInfo",
    "tags"
};

/// Note: Recommendation Single api columns by Billing Profile
apiColumns_RecommendationSingle = {
    "name",
    "type",
    "subscriptionId",
    "meterId",
    "term",
    "recommendedQuantity",
    "firstUsageDate",
    "scope",
    "lookBackPeriod",
    "costWithNoReservedInstancesCurrency",
    "costWithNoReservedInstances",
    "totalCostWithReservedInstancesCurrency",
    "totalCostWithReservedInstances",
    "netSavingsCurrency",
    "netSavings",
    "instanceFlexibilityGroup",
    "instanceFlexibilityRatio",
    "location",
    "resourceType",
    "skuName",
    "skuProperties"
};

/// Note: Recommendation Single api columns by Enrollment
apiColumns_RecommendationSingleByEnrollment = {
    "meterId",
    "term",
    "costWithNoReservedInstances",
    "recommendedQuantity",
    "totalCostWithReservedInstances",
    "netSavings",
    "firstUsageDate",
    "scope",
    "lookBackPeriod",
    "instanceFlexibilityRatio",
    "instanceFlexibilityGroup",
    "normalizedSize",
    "recommendedQuantityNormalized",
    "skuProperties"
};

/// Note: Recommendation Shared api columns by billing profile
apiColumns_RecommendationShared = {
    "name",
    "type",
    "meterId",
    "term",
    "recommendedQuantity",
    "firstUsageDate",
    "scope",
    "lookBackPeriod",
    "costWithNoReservedInstancesCurrency",
    "costWithNoReservedInstances",
    "totalCostWithReservedInstancesCurrency",
    "totalCostWithReservedInstances",
    "netSavingsCurrency",
    "netSavings",
    "instanceFlexibilityGroup",
    "instanceFlexibilityRatio",
    "location",
    "normalizedSize",
    "resourceType",
    "skuName",
    "skuProperties"
};

/// Note: Recommendation Shared api columns by enrollment Number
apiColumns_RecommendationSharedByEnrollment = {
    "meterId",
    "term",
    "costWithNoReservedInstances",
    "recommendedQuantity",
    "totalCostWithReservedInstances",
    "netSavings",
    "firstUsageDate",
    "scope",
    "lookBackPeriod",
    "instanceFlexibilityRatio",
    "instanceFlexibilityGroup",
    "normalizedSize",
    "recommendedQuantityNormalized",
    "skuProperties"
};

/// Note: RIUsage api columns
apiColumns_RIUsage = {
    "name",
    "type",
    "reservationOrderId",
    "reservationId",
    "usageDate",
    "skuName",
    "instanceId",
    "totalReservedQuantity",
    "reservedHours",
    "usedHours"
};

/// Note: RIUsage Summary api columns
apiColumns_RIUsageSummary = {
"reservationOrderId",
"reservationId",
"usageDate",
"skuName",
"avgUtilizationPercentage",
"minUtilizationPercentage",
"maxUtilizationPercentage",
"reservedHours",
"usedHours"
};

/// Note: balance Summary api columns
apiColumns_BalanceSummary = {
"currency",
"beginningBalance",
"endingBalance",
"newPurchases",
"adjustments",
"utilized",
"serviceOverage",
"chargesBilledSeparately",
"totalOverage",
"totalUsage",
"azureMarketplaceServiceCharges",
"billingFrequency",
"priceHidden",
"newPurchasesDetails",
"adjustmentDetails"
};

apiColumns_BillingPeriods = {
"billingPeriodStartDate",
"billingPeriodEndDate",
"priceHidden"
};

apiColumns_RIUsageDetails= {
    "name",
    "type",
    "reservationOrderId",
    "reservationId",
    "usageDate",
    "skuName",
    "instanceId",
    "totalReservedQuantity",
    "reservedHours",
    "usedHours",
    "instanceFlexibilityGroup",
    "instanceFlexibilityRatio"
};

RITransactionPropertyType = type table [
id = text,
name = text,
type = text,
tags = text,
properties = text
];

/// Note: Entities declaration
APIPropertyType = type table [
name = text,
type = text,
eTag = text,
properties = text
];

SchemaTable = #table({"Entity", "Type"}, {
    {"apiProperty", APIPropertyType },
    {"ritransactionapiProperty", RITransactionPropertyType }
});

//Load common library functions
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Table.ChangeType = Extension.LoadFunction("Table.ChangeType.pqm");
Table.GenerateByPage = Extension.LoadFunction("Table.GenerateByPage.pqm");

//Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = Diagnostics[LogValue];
Diagnostics.LogFailure = Diagnostics[LogFailure];
Diagnostics.WrapHandlers = Diagnostics[WrapHandlers];