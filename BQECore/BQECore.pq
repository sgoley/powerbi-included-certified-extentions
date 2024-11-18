[Version = "7.0.0"]
section BQECore;
BaseUrl = Extension.LoadString("BaseUrl"); 
//"https://api.bqecore.com/api/";
client_id =  Extension.LoadString("ClientId");
//"SaYIZ8Cj8qGCyLQuMjdXvaBHwm8Om__h.apps.bqe.com"; 
client_secret = Extension.LoadString("ClientSecret");
//"jGzEFb6SWpAdLnani7W7jyd_9ynXDVxAd33NJEWTJZPM13Y1NOvH64Iw0K4BZnnr";
redirect_uri = Extension.LoadString("RedirectURI");
//"https://preview.powerbi.com/views/oauthredirect.html";
windowWidth = 1200;
windowHeight = 1000;

[DataSource.Kind="BQECore", Publish="BQECore.Publish"]
shared BQECore.Contents = ()=> BQENavTable(BaseUrl) as table;
// shared BQECore.Contents =  Value.ReplaceType(BQENavTable, type function (url as text) as any);



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
//            Preview.DelayColumn = itemNameColumn, 
             Preview.DelayColumn = dataColumn,
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;
BQENavTable = (url as text) as table =>
    let
        source = #table({"Name", "Data", "ItemKind", "ItemName", "IsLeaf"}, {
            { "Account", AccountsExtension.Contents, "Function", "Table", true },
            { "Activity", ActivityExtension.Contents, "Function", "Table", true },
            { "Allocation", AllocationExtension.Contents, "Function", "Table", true },
            { "Bill", BillExtension.Contents, "Function", "Table", true },
            { "BillingSchedule", BillingScheduleExtension.Contents, "Function", "Table", true },
            { "Budget", BudgetExtension.Contents, "Function", "Table", true },
            { "Check", CheckExtension.Contents, "Function", "Table", true },
            { "CrmCampaign", CrmCampaignExtension.Contents, "Function", "Table", true },
            { "CrmListsCampaignStatus", CrmListsCampaignStatusExtension.Contents, "Function", "Table", true },
            { "CrmListsCampaignType", CrmListsCampaignTypeExtension.Contents, "Function", "Table", true },
            { "Class", ClassExtension.Contents, "Function", "Table", true },
            { "Client", ClientExtension.Contents, "Function", "Table", true },
            { "CrmCommissionProfile", CrmCommissionProfileExtension.Contents, "Function", "Table", true },
            { "CrmListsCompetition", CrmListsCompetitionExtension.Contents, "Function", "Table", true },
            { "Contact", ContactExtension.Contents, "Function", "Table", true },
            { "CommunicationType", CommunicationExtension.Contents, "Function", "Table", true },
            { "CostPool", CostPoolExtension.Contents, "Function", "Table", true },
            { "CreditCard", CreditCardExtension.Contents, "Function", "Table", true },
            { "CreditMemo", CreditMemoExtension.Contents, "Function", "Table", true },
            { "Currency", CurrencyExtension.Contents, "Function", "Table", true },
            { "CustomField", CustomFieldExtension.Contents, "Function", "Table", true },
            { "Deposit", DepositExtension.Contents, "Function", "Table", true },
            { "Document", DocumentExtension.Contents, "Function", "Table", true },
            { "CrmEmailTemplate", CrmEmailTemplateExtension.Contents, "Function", "Table", true },
            { "Employee", EmployeeExtension.Contents, "Function", "Table", true },
            { "Estimate", EstimateExtension.Contents, "Function", "Table", true },
            { "Expense", ExpenseExtension.Contents, "Function", "Table", true },
            { "ExpenseEntry", ExpenseEntryExtension.Contents, "Function", "Table", true },
            { "FeeSchedule", FeeScheduleExtension.Contents, "Function", "Table", true },
            { "CrmFollowup", CrmFollowupExtension.Contents, "Function", "Table", true },
            { "CrmListsFollowupType", CrmListsFollowupTypeExtension.Contents, "Function", "Table", true },
            { "FundTransfer", FundTransferExtension.Contents, "Function", "Table", true },
            { "GeneralJournal", GeneralJournalExtension.Contents, "Function", "Table", true },
            { "Group", GroupExtension.Contents, "Function", "Table", true },
            { "CrmListsIndustry", CrmListsIndustryExtension.Contents, "Function", "Table", true },
            { "Invoice", InvoiceExtension.Contents, "Function", "Table", true },
            { "CrmLead", CrmLeadExtension.Contents, "Function", "Table", true },
            { "CrmListsLeadSource", CrmListsLeadSourceExtension.Contents, "Function", "Table", true },
            { "NoteCategory", NoteCategoryExtension.Contents, "Function", "Table", true },
            { "Note", NoteExtension.Contents, "Function", "Table", true },
            { "NoteStatus", NoteStatusExtension.Contents, "Function", "Table", true },
            { "CrmOpportunity", CrmOpportunityExtension.Contents, "Function", "Table", true },
            { "CrmListsOpportunityStage", CrmListsOpportunityStageExtension.Contents, "Function", "Table", true },
            { "CrmListsOpportunityType", CrmListsOpportunityTypeExtension.Contents, "Function", "Table", true },
            { "Payment", PaymentExtension.Contents, "Function", "Table", true },
            { "CrmListsPriority", CrmListsPriorityExtension.Contents, "Function", "Table", true },
            { "ProjectAssignmentResource", ProjectAssignmentResourceExtension.Contents, "Function", "Table", true },
            { "ProjectAssignmentActivity", ProjectAssignmentActivityExtension.Contents, "Function", "Table", true },
            { "ProjectAssignmentExpense", ProjectAssignmentExpenseExtension.Contents, "Function", "Table", true },
            { "CrmPromotion", CrmPromotionExtension.Contents, "Function", "Table", true },
            { "CrmProposal", CrmProposalExtension.Contents, "Function", "Table", true },
            { "CrmProposalTemplate", CrmProposalTemplateExtension.Contents, "Function", "Table", true },
            { "CrmProspect", CrmProspectExtension.Contents, "Function", "Table", true },
            { "Project", PRGExtension.Contents, "Function", "Table", true },
            { "PurchaseOrder", PurchaseOrderExtension.Contents, "Function", "Table", true },
            { "CrmQuote", CrmQuoteExtension.Contents, "Function", "Table", true },
            { "CrmQuoteTemplate", CrmQuoteTemplateExtension.Contents, "Function", "Table", true },
            { "CrmListsRegion", CrmListsRegionExtension.Contents, "Function", "Table", true },
            { "CrmSalesGoal", CrmSalesGoalExtension.Contents, "Function", "Table", true },
            { "CrmListsScore", CrmListsScoreExtension.Contents, "Function", "Table", true },
            { "Term", TermExtension.Contents, "Function", "Table", true },
            { "Timer", TimerExtension.Contents, "Function", "Table", true },
            {"TimeEntry",  TEExtension.Contents , "Function", "Table", true},                                           
            { "ToDo", ToDoExtension.Contents, "Function", "Table", true },
            { "Vendor", VendorExtension.Contents, "Function", "Table", true },
            { "VendorCredit", VendorCreditExtension.Contents, "Function", "Table", true },
            { "GroupDetail", GroupDetailExtension.Contents, "Function", "Table", true },
            { "Company", CompanyExtension.Contents, "Function", "Table", true },
            { "SettingTimeExpense", TESettingExtension.Contents, "Function", "Table", true }

            
        }),
        navTable = Table.ToNavigationTable(source, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;
  



/*VendorCreditExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetVendorCredit(BaseUrl,finalstring) else GetVendorCredit(BaseUrl)

in
a;*/

VendorCreditExtension.Contents = (optional Where as text, optional Expand as text) => 
GetVendorCredit(BaseUrl, BuildFilterstring(Where,Expand));

VendorExtension.Contents = (optional Where as text, optional Expand as text) =>
GetVendor(BaseUrl, BuildFilterstring(Where,Expand));

ToDoExtension.Contents = (optional Where as text, optional Expand as text) =>
GetToDo(BaseUrl, BuildFilterstring(Where,Expand));

TimerExtension.Contents = (optional Where as text, optional Expand as text) =>
GetTimer(BaseUrl, BuildFilterstring(Where,Expand));

TermExtension.Contents = (optional Where as text, optional Expand as text) =>
GetTerm(BaseUrl, BuildFilterstring(Where,Expand));

PurchaseOrderExtension.Contents = (optional Where as text, optional Expand as text) =>
GetPurchaseOrder(BaseUrl, BuildFilterstring(Where,Expand));

CrmQuoteExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmQuote(BaseUrl, BuildFilterstring(Where,Expand));

CrmQuoteTemplateExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmQuoteTemplate(BaseUrl, BuildFilterstring(Where,Expand));

CrmListsRegionExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmListsRegion(BaseUrl, BuildFilterstring(Where,Expand));

CrmSalesGoalExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmSalesGoal(BaseUrl, BuildFilterstring(Where,Expand));

CrmListsScoreExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmListsScore(BaseUrl, BuildFilterstring(Where,Expand));

ProjectAssignmentResourceExtension.Contents = (optional Where as text, optional Expand as text) =>
GetProjectAssignmentResource(BaseUrl, BuildFilterstring(Where,Expand));

ProjectAssignmentActivityExtension.Contents = (optional Where as text, optional Expand as text) =>
GetProjectAssignmentActivity(BaseUrl, BuildFilterstring(Where,Expand));

ProjectAssignmentExpenseExtension.Contents = (optional Where as text, optional Expand as text) =>
GetProjectAssignmentExpense(BaseUrl, BuildFilterstring(Where,Expand));

CrmPromotionExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmPromotion(BaseUrl, BuildFilterstring(Where,Expand));

CrmProposalExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmProposal(BaseUrl, BuildFilterstring(Where,Expand));

CrmProposalTemplateExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmProposalTemplate(BaseUrl, BuildFilterstring(Where,Expand));

CrmProspectExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmProspect(BaseUrl, BuildFilterstring(Where,Expand));

PaymentExtension.Contents = (optional Where as text, optional Expand as text) =>
GetPayment(BaseUrl, BuildFilterstring(Where,Expand));

CrmListsPriorityExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmListsPriority(BaseUrl, BuildFilterstring(Where,Expand));

NoteStatusExtension.Contents = (optional Where as text, optional Expand as text) =>
GetNoteStatus(BaseUrl, BuildFilterstring(Where,Expand));

CrmOpportunityExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmOpportunity(BaseUrl, BuildFilterstring(Where,Expand));

CrmListsOpportunityStageExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmListsOpportunityStage(BaseUrl, BuildFilterstring(Where,Expand));

CrmListsOpportunityTypeExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmListsOpportunityType(BaseUrl, BuildFilterstring(Where,Expand));

NoteExtension.Contents = (optional Where as text, optional Expand as text) =>
GetNote(BaseUrl, BuildFilterstring(Where,Expand));


NoteCategoryExtension.Contents = (optional Where as text, optional Expand as text) =>
GetNoteCategory(BaseUrl, BuildFilterstring(Where,Expand));


InvoiceExtension.Contents = (optional Where as text, optional Expand as text) =>
GetInvoice(BaseUrl, BuildFilterstring(Where,Expand));


CrmLeadExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmLead(BaseUrl, BuildFilterstring(Where,Expand));
CrmListsLeadSourceExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmListsLeadSource(BaseUrl, BuildFilterstring(Where,Expand));

GroupExtension.Contents = (optional Where as text, optional Expand as text) =>
GetGroup(BaseUrl, BuildFilterstring(Where,Expand));

GroupDetailExtension.Contents = (optional Where as text, optional Expand as text) =>
GetGroupDetail(BaseUrl, BuildFilterstring(Where,Expand));

CrmListsIndustryExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmListsIndustry(BaseUrl, BuildFilterstring(Where,Expand));


GeneralJournalExtension.Contents = (optional Where as text, optional Expand as text) =>
GetGeneralJournal(BaseUrl, BuildFilterstring(Where,Expand));


FeeScheduleExtension.Contents = (optional Where as text, optional Expand as text) =>
GetFeeSchedule(BaseUrl, BuildFilterstring(Where,Expand));

CrmFollowupExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmFollowup(BaseUrl, BuildFilterstring(Where,Expand));

CrmListsFollowupTypeExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmListsFollowupType(BaseUrl, BuildFilterstring(Where,Expand));

FundTransferExtension.Contents = (optional Where as text, optional Expand as text) =>
GetFundTransfer(BaseUrl, BuildFilterstring(Where,Expand));

ExpenseExtension.Contents = (optional Where as text, optional Expand as text) =>
GetExpense(BaseUrl, BuildFilterstring(Where,Expand));


EstimateExtension.Contents = (optional Where as text, optional Expand as text) =>
GetEstimate(BaseUrl, BuildFilterstring(Where,Expand));


EmployeeExtension.Contents = (optional Where as text, optional Expand as text) =>
GetEmployee(BaseUrl, BuildFilterstring(Where,Expand));


DocumentExtension.Contents = (optional Where as text, optional Expand as text) =>
GetDocument(BaseUrl, BuildFilterstring(Where,Expand));

CrmEmailTemplateExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmEmailTemplate(BaseUrl, BuildFilterstring(Where,Expand));

DepositExtension.Contents = (optional Where as text, optional Expand as text) =>
GetDeposit(BaseUrl, BuildFilterstring(Where,Expand));


CustomFieldExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCustomField(BaseUrl, BuildFilterstring(Where,Expand));



CurrencyExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCurrency(BaseUrl, BuildFilterstring(Where,Expand));


CreditMemoExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCreditMemo(BaseUrl, BuildFilterstring(Where,Expand));



CreditCardExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCreditCard(BaseUrl, BuildFilterstring(Where,Expand));



CostPoolExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCostPool(BaseUrl, BuildFilterstring(Where,Expand));

CommunicationExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCommunication(BaseUrl, BuildFilterstring(Where,Expand));

ClientExtension.Contents = (optional Where as text, optional Expand as text) =>
GetClient(BaseUrl, BuildFilterstring(Where,Expand));

CrmCommissionProfileExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmCommissionProfile(BaseUrl, BuildFilterstring(Where,Expand));

CrmListsCompetitionExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmListsCompetition(BaseUrl, BuildFilterstring(Where,Expand));

ContactExtension.Contents = (optional Where as text, optional Expand as text) =>
GetContact(BaseUrl, BuildFilterstring(Where,Expand));

ClassExtension.Contents = (optional Where as text, optional Expand as text) =>
GetClass(BaseUrl, BuildFilterstring(Where,Expand));

CheckExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCheck(BaseUrl, BuildFilterstring(Where,Expand));

CrmCampaignExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmCampaign(BaseUrl, BuildFilterstring(Where,Expand));

CrmListsCampaignStatusExtension.Contents = (optional Where as text, optional Expand as text) =>
GeCrmListsCampaignStatus(BaseUrl, BuildFilterstring(Where,Expand));

CrmListsCampaignTypeExtension.Contents = (optional Where as text, optional Expand as text) =>
GetCrmListsCampaignType(BaseUrl, BuildFilterstring(Where,Expand));

BudgetExtension.Contents = (optional Where as text, optional Expand as text) =>
GetBudget(BaseUrl, BuildFilterstring(Where,Expand));

BillingScheduleExtension.Contents = (optional Where as text, optional Expand as text) =>
GetBillingSchedule(BaseUrl, BuildFilterstring(Where,Expand));

BillExtension.Contents = (optional Where as text, optional Expand as text) =>
GetBill(BaseUrl, BuildFilterstring(Where,Expand));


AllocationExtension.Contents = (optional Where as text, optional Expand as text) =>
GetAllocation(BaseUrl, BuildFilterstring(Where,Expand));


ActivityExtension.Contents = (optional Where as text, optional Expand as text) =>
GetActivity(BaseUrl, BuildFilterstring(Where,Expand));


AccountsExtension.Contents =(optional Where as text, optional Expand as text) =>
GetAccounts(BaseUrl, BuildFilterstring(Where,Expand));


ExpenseEntryExtension.Contents = (optional Where as text, optional Expand as text) =>
GetExpenseEntry(BaseUrl, BuildFilterstring(Where,Expand));



PRGExtension.Contents = (optional Where as text, optional Expand as text) =>
GetProjects(BaseUrl, BuildFilterstring(Where,Expand));



TEExtension.Contents = (optional Where as text, optional Expand as text) =>
GetTime(BaseUrl, BuildFilterstring(Where,Expand));

  CompanyExtension.Contents = (optional Expand as text) =>
GetCompany(BaseUrl,BuildFilterstring(null,Expand));
 
  TESettingExtension.Contents = () =>
GetTESetting(BaseUrl);

BuildFilterstring=(optional Where as text, optional Expand as text, optional Field as text)=>
    let 
        filterstring =null,
// =if(Fields<>null) then "&Fields="&Fields else null

test = if(filterstring=null)
        then if(Where=null) then null else "&Where="&Where 
        else
        if(Where=null) then filterstring else filterstring&"&Where="&Where,
finalstring = if(test=null)
        then if(Expand=null) then null else "&Expand="&Expand 
        else
        if(Expand=null) then test else test&"&Expand="&Expand
in finalstring;

GetVendorCredit = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"vendorcredit",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"vendorcredit",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"VendorCredit"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "VendorCredit"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist  else  Table.ExpandRecordColumn(renamedColumn, "VendorCredit", {"vendorId", "vendor", "date", "reference", "amount", "accountId", "account", "balance", "memo", "lineItems", "accountSplits", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token","customFields"}, {"VendorCredit.vendorId", "VendorCredit.vendor", "VendorCredit.date", "VendorCredit.reference", "VendorCredit.amount", "VendorCredit.accountId", "VendorCredit.account", "VendorCredit.balance", "VendorCredit.memo", "VendorCredit.lineItems", "VendorCredit.accountSplits", "VendorCredit.id", "VendorCredit.createdOn", "VendorCredit.createdById", "VendorCredit.lastUpdated", "VendorCredit.lastUpdatedById", "VendorCredit.version", "VendorCredit.objectState", "VendorCredit.token","VendorCredit.customFields"})

 in 
 expandAll;
GetVendor = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"vendor",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"vendor",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Vendor"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Vendor"}}),

 expandAll =   if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Vendor", {"type", "termId", "term", "billRate", "costRate", "is1099Applicable", "taxId", "displayName", "firstName", "lastName", "middleInitial", "title", "managerId", "manager", "status", "dailyStandardHours", "weeklyStandardHours", "address", "dateHired", "memo", "overtimeCostRate", "overtimeBillRate", "department", "dateReleased", "salary", "salaryPayPeriod", "bankRouting", "bankAccount", "autoDeposit", "salutation", "compTimeHours", "compTimeFrequency", "overheadFactor", "submitTo", "defaultGroupId", "defaultGroup", "currencyId", "currency", "autoOverTime", "autoApproveTimeEntry", "autoApproveExpenseEntry", "payableAccountId", "payableAccount", "securityProfileId", "securityProfile", "company", "role", "gender", "customFields", "assignedGroups", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token","dateOfBirth","expenseAccount","expenseAccountId","utilizationTarget"}, {"Vendor.type", "Vendor.termId", "Vendor.term", "Vendor.billRate", "Vendor.costRate", "Vendor.is1099Applicable", "Vendor.taxId", "Vendor.displayName", "Vendor.firstName", "Vendor.lastName", "Vendor.middleInitial", "Vendor.title", "Vendor.managerId", "Vendor.manager", "Vendor.status", "Vendor.dailyStandardHours", "Vendor.weeklyStandardHours", "Vendor.address", "Vendor.dateHired", "Vendor.memo", "Vendor.overtimeCostRate", "Vendor.overtimeBillRate", "Vendor.department", "Vendor.dateReleased", "Vendor.salary", "Vendor.salaryPayPeriod", "Vendor.bankRouting", "Vendor.bankAccount", "Vendor.autoDeposit", "Vendor.salutation", "Vendor.compTimeHours", "Vendor.compTimeFrequency", "Vendor.overheadFactor", "Vendor.submitTo", "Vendor.defaultGroupId", "Vendor.defaultGroup", "Vendor.currencyId", "Vendor.currency", "Vendor.autoOverTime", "Vendor.autoApproveTimeEntry", "Vendor.autoApproveExpenseEntry", "Vendor.payableAccountId", "Vendor.payableAccount", "Vendor.securityProfileId", "Vendor.securityProfile", "Vendor.company", "Vendor.role", "Vendor.gender", "Vendor.customFields", "Vendor.assignedGroups", "Vendor.id", "Vendor.createdOn", "Vendor.createdById", "Vendor.lastUpdated", "Vendor.lastUpdatedById", "Vendor.version", "Vendor.objectState", "Vendor.token","Vendor.dateOfBirth","Vendor.expenseAccount","Vendor.expenseAccountId","Vendor.utilizationTarget"})

 in 
 expandAll;
GetToDo = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"todo",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"todo",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"ToDo"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "ToDo"}}),

 expandAll =   if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "ToDo", {"startDate", "endDate", "linkedEntityId", "linkedEntity", "linkedEntityType", "assignedToId", "assignedTo", "percentComplete", "priority", "status", "reminderDate", "description", "memo", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"ToDo.startDate", "ToDo.endDate", "ToDo.linkedEntityId", "ToDo.linkedEntity", "ToDo.linkedEntityType", "ToDo.assignedToId", "ToDo.assignedTo", "ToDo.percentComplete", "ToDo.priority", "ToDo.status", "ToDo.reminderDate", "ToDo.description", "ToDo.memo", "ToDo.id", "ToDo.createdOn", "ToDo.createdById", "ToDo.lastUpdated", "ToDo.lastUpdatedById", "ToDo.version", "ToDo.objectState", "ToDo.token"})

 in 
 expandAll;

GetTimer = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"timer",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"timer",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Timer"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Timer"}}),

 expandAll = if consolidatedlist{0}?=null then consolidatedlist   else  Table.ExpandRecordColumn(renamedColumn, "Timer", {"resourceId", "resource", "projectId", "project", "activityId", "activity", "status", "startTime", "stopTime", "hours", "overTime", "billable", "description", "memo", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Timer.resourceId", "Timer.resource", "Timer.projectId", "Timer.project", "Timer.activityId", "Timer.activity", "Timer.status", "Timer.startTime", "Timer.stopTime", "Timer.hours", "Timer.overTime", "Timer.billable", "Timer.description", "Timer.memo", "Timer.id", "Timer.createdOn", "Timer.createdById", "Timer.lastUpdated", "Timer.lastUpdatedById", "Timer.version", "Timer.objectState", "Timer.token"})

 in 
 expandAll;
GetTime = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"timeentry",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"timeentry",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Timeentry"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Timeentry"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Timeentry", {"date", "activityId", "activity", "projectId", "project", "resourceId", "resource", "billable", "billStatus", "description", "actualHours", "clientHours", "billRate", "costRate", "overtime", "invoiceId", "invoiceNumber", "classification", "tax1", "tax2", "tax3", "memo", "extra", "incomeAccountId", "incomeAccount", "expenseAccountId", "expenseAccount", "startInterval", "startTime", "stopInterval", "stopTime", "vendorBillId", "vendorBillNumber", "client", "classId", "class", "workflow", "customFields", "wudPercent", "flag1", "flag2", "flag3", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token","compensationTime","wudMultiplier"}, {"Timeentry.date", "Timeentry.activityId", "Timeentry.activity", "Timeentry.projectId", "Timeentry.project", "Timeentry.resourceId", "Timeentry.resource", "Timeentry.billable", "Timeentry.billStatus", "Timeentry.description", "Timeentry.actualHours", "Timeentry.clientHours", "Timeentry.billRate", "Timeentry.costRate", "Timeentry.overtime", "Timeentry.invoiceId", "Timeentry.invoiceNumber", "Timeentry.classification", "Timeentry.tax1", "Timeentry.tax2", "Timeentry.tax3", "Timeentry.memo", "Timeentry.extra", "Timeentry.incomeAccountId", "Timeentry.incomeAccount", "Timeentry.expenseAccountId", "Timeentry.expenseAccount", "Timeentry.startInterval", "Timeentry.startTime", "Timeentry.stopInterval", "Timeentry.stopTime", "Timeentry.vendorBillId", "Timeentry.vendorBillNumber", "Timeentry.client", "Timeentry.classId", "Timeentry.class", "Timeentry.workflow", "Timeentry.customFields", "Timeentry.wudPercent", "Timeentry.flag1", "Timeentry.flag2", "Timeentry.flag3", "Timeentry.id", "Timeentry.createdOn", "Timeentry.createdById", "Timeentry.lastUpdated", "Timeentry.lastUpdatedById", "Timeentry.version", "Timeentry.objectState", "Timeentry.token","Timeentry.compensationTime","Timeentry.wudMultiplier"})

 in 
 expandAll;

GetTerm = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"term",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"term",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Term"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Term"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Term", {"name", "graceDays", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Term.name", "Term.graceDays", "Term.id", "Term.createdOn", "Term.createdById", "Term.lastUpdated", "Term.lastUpdatedById", "Term.version", "Term.objectState", "Term.token"})

 in 
 expandAll;

GetPurchaseOrder = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"purchaseorder",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"purchaseorder",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"PurchaseOrder"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "PurchaseOrder"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "PurchaseOrder", {"number", "date", "dueDate", "paymentTermId", "paymentTerm", "entityId", "entity", "entityType", "isActive", "amount", "memo", "address", "vendor", "vendorId", "lineItems", "workflow", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token","customFields"}, {"PurchaseOrder.number", "PurchaseOrder.date", "PurchaseOrder.dueDate", "PurchaseOrder.paymentTermId", "PurchaseOrder.paymentTerm", "PurchaseOrder.entityId", "PurchaseOrder.entity", "PurchaseOrder.entityType", "PurchaseOrder.isActive", "PurchaseOrder.amount", "PurchaseOrder.memo", "PurchaseOrder.address", "PurchaseOrder.vendor", "PurchaseOrder.vendorId", "PurchaseOrder.lineItems", "PurchaseOrder.workflow", "PurchaseOrder.id", "PurchaseOrder.createdOn", "PurchaseOrder.createdById", "PurchaseOrder.lastUpdated", "PurchaseOrder.lastUpdatedById", "PurchaseOrder.version", "PurchaseOrder.objectState", "PurchaseOrder.token","PurchaseOrder.customFields"})

 in 
 expandAll;

GetCrmQuote = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/quote",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/quote",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmQuote"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmQuote"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmQuote", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","miscellaneousAmount","feeScheduleId","feeSchedule","name","description","status","date","totalAmount","services","expenses","workflow","prospectId","prospect","isPrimary","opportunityId","opportunity","quoteTemplateId","quoteTemplate"}, {"CrmQuote.id","CrmQuote.createdOn","CrmQuote.createdById","CrmQuote.lastUpdated","CrmQuote.lastUpdatedById","CrmQuote.version","CrmQuote.objectState","CrmQuote.token","CrmQuote.miscellaneousAmount","CrmQuote.feeScheduleId","CrmQuote.feeSchedule","CrmQuote.name","CrmQuote.description","CrmQuote.status","CrmQuote.date","CrmQuote.totalAmount","CrmQuote.services","CrmQuote.expenses","CrmQuote.workflow","CrmQuote.prospectId","CrmQuote.prospect","CrmQuote.isPrimary","CrmQuote.opportunityId","CrmQuote.opportunity","CrmQuote.quoteTemplateId","CrmQuote.quoteTemplate"})

 in 
 expandAll;

GetCrmQuoteTemplate = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/quotetemplate",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/quotetemplate",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmQuoteTemplate"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmQuoteTemplate"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmQuoteTemplate", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","miscellaneousAmount","feeScheduleId","feeSchedule","name","status","date","totalAmount","services","expenses","description"}, {"CrmQuoteTemplate.id","CrmQuoteTemplate.createdOn","CrmQuoteTemplate.createdById","CrmQuoteTemplate.lastUpdated","CrmQuoteTemplate.lastUpdatedById","CrmQuoteTemplate.version","CrmQuoteTemplate.objectState","CrmQuoteTemplate.token","CrmQuoteTemplate.miscellaneousAmount","CrmQuoteTemplate.feeScheduleId","CrmQuoteTemplate.feeSchedule","CrmQuoteTemplate.name","CrmQuoteTemplate.status","CrmQuoteTemplate.date","CrmQuoteTemplate.totalAmount","CrmQuoteTemplate.services","CrmQuoteTemplate.expenses","CrmQuoteTemplate.description"})

 in 
 expandAll;

GetCrmListsRegion = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/lists/region",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/lists/region",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmListsRegion"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmListsRegion"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmListsRegion", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","isSystem","status"}, {"CrmListsRegion.id","CrmListsRegion.createdOn","CrmListsRegion.createdById","CrmListsRegion.lastUpdated","CrmListsRegion.lastUpdatedById","CrmListsRegion.version","CrmListsRegion.objectState","CrmListsRegion.token","CrmListsRegion.name","CrmListsRegion.isSystem","CrmListsRegion.status"})

 in 
 expandAll;

GetCrmSalesGoal = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/salesgoal",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/salesgoal",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmSalesGoal"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmSalesGoal"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmSalesGoal", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","startDate","endDate","managerId","manager","amount","actualAmount","details"}, {"CrmSalesGoal.id","CrmSalesGoal.createdOn","CrmSalesGoal.createdById","CrmSalesGoal.lastUpdated","CrmSalesGoal.lastUpdatedById","CrmSalesGoal.version","CrmSalesGoal.objectState","CrmSalesGoal.token","CrmSalesGoal.name","CrmSalesGoal.startDate","CrmSalesGoal.endDate","CrmSalesGoal.managerId","CrmSalesGoal.manager","CrmSalesGoal.amount","CrmSalesGoal.actualAmount","CrmSalesGoal.details"})

 in 
 expandAll;

GetCrmListsScore = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/lists/score",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/lists/score",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmListsScore"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmListsScore"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmListsScore", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","isSystem","status","sortOrder"}, {"CrmListsScore.id","CrmListsScore.createdOn","CrmListsScore.createdById","CrmListsScore.lastUpdated","CrmListsScore.lastUpdatedById","CrmListsScore.version","CrmListsScore.objectState","CrmListsScore.token","CrmListsScore.name","CrmListsScore.isSystem","CrmListsScore.status","CrmListsScore.sortOrder"})

 in 
 expandAll;

GetProjectAssignmentResource = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"projectassignment/resource",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"projectassignment/resource",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"ProjectAssignmentResource"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "ProjectAssignmentResource"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "ProjectAssignmentResource", {"resourceId", "resource", "resourceType", "classification", "projectId", "project", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"ProjectAssignmentResource.resourceId", "ProjectAssignmentResource.resource", "ProjectAssignmentResource.resourceType", "ProjectAssignmentResource.classification", "ProjectAssignmentResource.projectId", "ProjectAssignmentResource.project", "ProjectAssignmentResource.id", "ProjectAssignmentResource.createdOn", "ProjectAssignmentResource.createdById", "ProjectAssignmentResource.lastUpdated", "ProjectAssignmentResource.lastUpdatedById", "ProjectAssignmentResource.version", "ProjectAssignmentResource.objectState", "ProjectAssignmentResource.token"})

 in 
 expandAll;

GetProjectAssignmentActivity = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"projectassignment/activity",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"projectassignment/activity",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"ProjectAssignmentActivity"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "ProjectAssignmentActivity"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "ProjectAssignmentActivity", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","projectId","project","billable","description","itemId","item","itemType"}, {"ProjectAssignmentActivity.id","ProjectAssignmentActivity.createdOn","ProjectAssignmentActivity.createdById","ProjectAssignmentActivity.lastUpdated","ProjectAssignmentActivity.lastUpdatedById","ProjectAssignmentActivity.version","ProjectAssignmentActivity.objectState","ProjectAssignmentActivity.token","ProjectAssignmentActivity.projectId","ProjectAssignmentActivity.project","ProjectAssignmentActivity.billable","ProjectAssignmentActivity.description","ProjectAssignmentActivity.itemId","ProjectAssignmentActivity.item","ProjectAssignmentActivity.itemType"})

 in 
 expandAll;

GetProjectAssignmentExpense = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"projectassignment/expense",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"projectassignment/expense",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"ProjectAssignmentExpense"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "ProjectAssignmentExpense"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "ProjectAssignmentExpense", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","projectId","project","billable","description","itemId","item","itemType"}, {"ProjectAssignmentExpense.id","ProjectAssignmentExpense.createdOn","ProjectAssignmentExpense.createdById","ProjectAssignmentExpense.lastUpdated","ProjectAssignmentExpense.lastUpdatedById","ProjectAssignmentExpense.version","ProjectAssignmentExpense.objectState","ProjectAssignmentExpense.token","ProjectAssignmentExpense.projectId","ProjectAssignmentExpense.project","ProjectAssignmentExpense.billable","ProjectAssignmentExpense.description","ProjectAssignmentExpense.itemId","ProjectAssignmentExpense.item","ProjectAssignmentExpense.itemType"})

 in 
 expandAll;

GetCrmPromotion = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/promotion",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/promotion",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmPromotion"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmPromotion"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmPromotion", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","description","code","startDate","endDate","status","applyToAllItems","minimumAmount","type","value","details"}, {"CrmPromotion.id","CrmPromotion.createdOn","CrmPromotion.createdById","CrmPromotion.lastUpdated","CrmPromotion.lastUpdatedById","CrmPromotion.version","CrmPromotion.objectState","CrmPromotion.token","CrmPromotion.name","CrmPromotion.description","CrmPromotion.code","CrmPromotion.startDate","CrmPromotion.endDate","CrmPromotion.status","CrmPromotion.applyToAllItems","CrmPromotion.minimumAmount","CrmPromotion.type","CrmPromotion.value","CrmPromotion.details"})

 in 
 expandAll;

GetCrmProposal = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/proposal",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/proposal",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmProposal"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmProposal"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmProposal", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","text","description","prospectId","prospect","opportunityId","opportunity","amount","status","date","workflow","isPrimary","quoteId","quote","templateId"}, {"CrmProposal.id","CrmProposal.createdOn","CrmProposal.createdById","CrmProposal.lastUpdated","CrmProposal.lastUpdatedById","CrmProposal.version","CrmProposal.objectState","CrmProposal.token","CrmProposal.name","CrmProposal.text","CrmProposal.description","CrmProposal.prospectId","CrmProposal.prospect","CrmProposal.opportunityId","CrmProposal.opportunity","CrmProposal.amount","CrmProposal.status","CrmProposal.date","CrmProposal.workflow","CrmProposal.isPrimary","CrmProposal.quoteId","CrmProposal.quote","CrmProposal.templateId"})

 in 
 expandAll;

GetCrmProposalTemplate = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/proposaltemplate",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/proposaltemplate",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmProposalTemplate"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmProposalTemplate"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmProposalTemplate", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","text","description","amount","status","date","prospectId","prospect","opportunityId","opportunity"}, {"CrmProposalTemplate.id","CrmProposalTemplate.createdOn","CrmProposalTemplate.createdById","CrmProposalTemplate.lastUpdated","CrmProposalTemplate.lastUpdatedById","CrmProposalTemplate.version","CrmProposalTemplate.objectState","CrmProposalTemplate.token","CrmProposalTemplate.name","CrmProposalTemplate.text","CrmProposalTemplate.description","CrmProposalTemplate.amount","CrmProposalTemplate.status","CrmProposalTemplate.date","CrmProposalTemplate.prospectId","CrmProposalTemplate.prospect","CrmProposalTemplate.opportunityId","CrmProposalTemplate.opportunity"})

 in 
 expandAll;

GetCrmProspect = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/prospect",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/prospect",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmProspect"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmProspect"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmProspect", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","company","firstName","lastName","middleInitial","status","type","assignedToId","assignedTo","referredById","referredBy","referredByType","address","memo","defaultGroupId","defaultGroup","customFields","assignedGroups","industryId","industry","staffStrength","regionId","region","sourceId","source","cost","scoreId","score","assignedDate","taxId","title","clientId","linkedEntityId","linkedEntityType","managerId","manager"}, {"CrmProspect.id","CrmProspect.createdOn","CrmProspect.createdById","CrmProspect.lastUpdated","CrmProspect.lastUpdatedById","CrmProspect.version","CrmProspect.objectState","CrmProspect.token","CrmProspect.name","CrmProspect.company","CrmProspect.firstName","CrmProspect.lastName","CrmProspect.middleInitial","CrmProspect.status","CrmProspect.type","CrmProspect.assignedToId","CrmProspect.assignedTo","CrmProspect.referredById","CrmProspect.referredBy","CrmProspect.referredByType","CrmProspect.address","CrmProspect.memo","CrmProspect.defaultGroupId","CrmProspect.defaultGroup","CrmProspect.customFields","CrmProspect.assignedGroups","CrmProspect.industryId","CrmProspect.industry","CrmProspect.staffStrength","CrmProspect.regionId","CrmProspect.region","CrmProspect.sourceId","CrmProspect.source","CrmProspect.cost","CrmProspect.scoreId","CrmProspect.score","CrmProspect.assignedDate","CrmProspect.taxId","CrmProspect.title","CrmProspect.clientId","CrmProspect.linkedEntityId","CrmProspect.linkedEntityType","CrmProspect.managerId","CrmProspect.manager"})

 in 
 expandAll;

GetPayment = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"payment",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"payment",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Payment"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Payment"}}),

 expandAll =   if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Payment", {"date", "reference", "note", "clientId", "client", "projectId", "project", "method", "amount", "lineItems", "isRetainer", "retainerType", "assetAccountId", "assetAccount", "liabilityAccountId", "liabilityAccount", "badDebtExpenseAccountId", "badDebtExpenseAccount", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token","memo","accountSplits"}, {"Payment.date", "Payment.reference", "Payment.note", "Payment.clientId", "Payment.client", "Payment.projectId", "Payment.project", "Payment.method", "Payment.amount", "Payment.lineItems", "Payment.isRetainer", "Payment.retainerType", "Payment.assetAccountId", "Payment.assetAccount", "Payment.liabilityAccountId", "Payment.liabilityAccount", "Payment.badDebtExpenseAccountId", "Payment.badDebtExpenseAccount", "Payment.id", "Payment.createdOn", "Payment.createdById", "Payment.lastUpdated", "Payment.lastUpdatedById", "Payment.version", "Payment.objectState", "Payment.token","Payment.memo","Payment.accountSplits"})

 in 
 expandAll;

GetCrmListsPriority = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/lists/priority",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/lists/priority",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmListsPriority"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmListsPriority"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmListsPriority", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","status","sortOrder"}, {"CrmListsPriority.id","CrmListsPriority.createdOn","CrmListsPriority.createdById","CrmListsPriority.lastUpdated","CrmListsPriority.lastUpdatedById","CrmListsPriority.version","CrmListsPriority.objectState","CrmListsPriority.token","CrmListsPriority.name","CrmListsPriority.status","CrmListsPriority.sortOrder"})

 in 
 expandAll;
GetNoteStatus = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"note/status",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"note/status",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"NoteStatus"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "NoteStatus"}}),

 expandAll =   if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "NoteStatus", {"name", "isActive", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"NoteStatus.name", "NoteStatus.isActive", "NoteStatus.id", "NoteStatus.createdOn", "NoteStatus.createdById", "NoteStatus.lastUpdated", "NoteStatus.lastUpdatedById", "NoteStatus.version", "NoteStatus.objectState", "NoteStatus.token"})

 in 
 expandAll;

 GetCrmOpportunity = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/opportunity",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/opportunity",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmOpportunity"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmOpportunity"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmOpportunity", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","expiresOn","name","description","typeId","type","prospectId","prospect","priorityId","priority","assignedEntityId","assignedEntity","value","probabilityPercent","forecastAmount","targetDate","stageId","stage","status","competitionId","competition","nextStep","closedOn","closedAmount","closedAmountType","defaultGroupId","defaultGroup","lossReason","customFields","assignedGroups","campaignId","campaign","promotionId","promotion"}, {"CrmOpportunity.id","CrmOpportunity.createdOn","CrmOpportunity.createdById","CrmOpportunity.lastUpdated","CrmOpportunity.lastUpdatedById","CrmOpportunity.version","CrmOpportunity.objectState","CrmOpportunity.token","CrmOpportunity.expiresOn","CrmOpportunity.name","CrmOpportunity.description","CrmOpportunity.typeId","CrmOpportunity.type","CrmOpportunity.prospectId","CrmOpportunity.prospect","CrmOpportunity.priorityId","CrmOpportunity.priority","CrmOpportunity.assignedEntityId","CrmOpportunity.assignedEntity","CrmOpportunity.value","CrmOpportunity.probabilityPercent","CrmOpportunity.forecastAmount","CrmOpportunity.targetDate","CrmOpportunity.stageId","CrmOpportunity.stage","CrmOpportunity.status","CrmOpportunity.competitionId","CrmOpportunity.competition","CrmOpportunity.nextStep","CrmOpportunity.closedOn","CrmOpportunity.closedAmount","CrmOpportunity.closedAmountType","CrmOpportunity.defaultGroupId","CrmOpportunity.defaultGroup","CrmOpportunity.lossReason","CrmOpportunity.customFields","CrmOpportunity.assignedGroups","CrmOpportunity.campaignId","CrmOpportunity.campaign","CrmOpportunity.promotionId","CrmOpportunity.promotion"})

 in 
 expandAll;

GetCrmListsOpportunityStage = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/lists/opportunitystage",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/lists/opportunitystage",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmListsOpportunityStage"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmListsOpportunityStage"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmListsOpportunityStage", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","isSystem","type","status","sortOrder"}, {"CrmListsOpportunityStage.id","CrmListsOpportunityStage.createdOn","CrmListsOpportunityStage.createdById","CrmListsOpportunityStage.lastUpdated","CrmListsOpportunityStage.lastUpdatedById","CrmListsOpportunityStage.version","CrmListsOpportunityStage.objectState","CrmListsOpportunityStage.token","CrmListsOpportunityStage.name","CrmListsOpportunityStage.isSystem","CrmListsOpportunityStage.type","CrmListsOpportunityStage.status","CrmListsOpportunityStage.sortOrder"})

 in 
 expandAll;

GetCrmListsOpportunityType = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/lists/opportunitytype",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/lists/opportunitytype",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmListsOpportunityType"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmListsOpportunityType"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmListsOpportunityType", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","status"}, {"CrmListsOpportunityType.id","CrmListsOpportunityType.createdOn","CrmListsOpportunityType.createdById","CrmListsOpportunityType.lastUpdated","CrmListsOpportunityType.lastUpdatedById","CrmListsOpportunityType.version","CrmListsOpportunityType.objectState","CrmListsOpportunityType.token","CrmListsOpportunityType.name","CrmListsOpportunityType.status"})

 in 
 expandAll;
 
GetNote = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"note",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"note",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Note"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Note"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Note", {"date", "description", "reportedById", "reportedBy", "masterEntityId", "masterEntity", "masterEntityType", "linkedEntityId", "linkedEntity", "linkedEntityType", "noteCategoryId", "noteCategory", "noteStatusId", "noteStatus", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Note.date", "Note.description", "Note.reportedById", "Note.reportedBy", "Note.masterEntityId", "Note.masterEntity", "Note.masterEntityType", "Note.linkedEntityId", "Note.linkedEntity", "Note.linkedEntityType", "Note.noteCategoryId", "Note.noteCategory", "Note.noteStatusId", "Note.noteStatus", "Note.id", "Note.createdOn", "Note.createdById", "Note.lastUpdated", "Note.lastUpdatedById", "Note.version", "Note.objectState", "Note.token"})

 in 
 expandAll;

GetNoteCategory = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"note/category",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"note/category",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"NoteCategory"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "NoteCategory"}}),

 expandAll =   if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "NoteCategory", {"name", "isActive", "isSystem", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"NoteCategory.name", "NoteCategory.isActive", "NoteCategory.isSystem", "NoteCategory.id", "NoteCategory.createdOn", "NoteCategory.createdById", "NoteCategory.lastUpdated", "NoteCategory.lastUpdatedById", "NoteCategory.version", "NoteCategory.objectState", "NoteCategory.token"})

 in 
 expandAll;

GetInvoice = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"invoice",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"invoice",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Invoice"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Invoice"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist   else  Table.ExpandRecordColumn(renamedColumn, "Invoice", {"invoiceNumber", "date", "status", "invoiceAmount", "dueDate", "isManualInvoice", "isLateFeeInvoice", "isDraft", "balance", "serviceAmount", "expenseAmount", "serviceTaxAmount", "expenseTaxAmount", "mainServiceTax", "mainExpenseTax", "fixedFee", "isJointInvoice", "invoiceDetails", "lineItems", "invoiceFrom", "invoiceTo", "messageOnInvoice", "billingContactId", "referenceNumber", "rfNumber", "purchaseOrderNumber", "workflow", "customFields", "accountSplits", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token","miscellaneousAmount","type","extendedAccountSplit"}, {"Invoice.invoiceNumber", "Invoice.date", "Invoice.status", "Invoice.invoiceAmount", "Invoice.dueDate", "Invoice.isManualInvoice", "Invoice.isLateFeeInvoice", "Invoice.isDraft", "Invoice.balance", "Invoice.serviceAmount", "Invoice.expenseAmount", "Invoice.serviceTaxAmount", "Invoice.expenseTaxAmount", "Invoice.mainServiceTax", "Invoice.mainExpenseTax", "Invoice.fixedFee", "Invoice.isJointInvoice", "Invoice.invoiceDetails", "Invoice.lineItems", "Invoice.invoiceFrom", "Invoice.invoiceTo", "Invoice.messageOnInvoice", "Invoice.billingContactId", "Invoice.referenceNumber", "Invoice.rfNumber", "Invoice.purchaseOrderNumber", "Invoice.workflow", "Invoice.customFields", "Invoice.accountSplits", "Invoice.id", "Invoice.createdOn", "Invoice.createdById", "Invoice.lastUpdated", "Invoice.lastUpdatedById", "Invoice.version", "Invoice.objectState", "Invoice.token","Invoice.miscellaneousAmount","Invoice.type","Invoice.extendedAccountSplit"})

 in 
 expandAll;

 GetCrmLead = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/lead",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/lead",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmLead"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmLead"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmLead", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","company","firstName","lastName","middleInitial","status","type","assignedToId","assignedTo","referredById","referredBy","referredByType","address","memo","defaultGroupId","defaultGroup","customFields","assignedGroups","industryId","industry","staffStrength","regionId","region","sourceId","source","cost","scoreId","score","assignedDate"}, {"CrmLead.id","CrmLead.createdOn","CrmLead.createdById","CrmLead.lastUpdated","CrmLead.lastUpdatedById","CrmLead.version","CrmLead.objectState","CrmLead.token","CrmLead.name","CrmLead.company","CrmLead.firstName","CrmLead.lastName","CrmLead.middleInitial","CrmLead.status","CrmLead.type","CrmLead.assignedToId","CrmLead.assignedTo","CrmLead.referredById","CrmLead.referredBy","CrmLead.referredByType","CrmLead.address","CrmLead.memo","CrmLead.defaultGroupId","CrmLead.defaultGroup","CrmLead.customFields","CrmLead.assignedGroups","CrmLead.industryId","CrmLead.industry","CrmLead.staffStrength","CrmLead.regionId","CrmLead.region","CrmLead.sourceId","CrmLead.source","CrmLead.cost","CrmLead.scoreId","CrmLead.score","CrmLead.assignedDate"})

 in 
 expandAll;
 GetCompany = (url as text, optional filters as text) =>
   
   let
   response=   GetDatafromSingleObject (url&"company",filters),

    // Convert the JSON object to a single-row table
     dataTable = Record.ToTable(response),

    // Expand the record into columns with "Company." prefix
    expandedTable = Table.FromRecords({[Company.Name = response[name],
                                       Company.AddressLine1 = response[addressLine1],
                                       Company.AddressLine2 = response[addressLine2],
                                       Company.City = response[city],
                                       Company.StateCode = response[stateCode],
                                       Company.Zip = response[zip],
                                       Company.Country = response[country],
                                       Company.FiscalStartDay = response[fiscalStartDay],
                                       Company.FiscalStartMonth = response[fiscalStartMonth],
                                       Company.FiscalEndDay = response[fiscalEndDay],
                                       Company.FiscalEndMonth = response[fiscalEndMonth],
                                       Company.ClosingDate = response[closingDate],
                                       Company.TaxNumber = response[taxNumber],
                                       Company.EmployerCode = response[employerCode],
                                       Company.Phone = response[phone],
                                       Company.Fax = response[fax],
                                       Company.Email = response[email],
                                       Company.Uri = response[uri],
                                       Company.Currency = response[currency],
                                       Company.CurrencyId = response[currencyId],
                                       Company.CultureCode = response[cultureCode],
                                       Company.CustomFields = response[customFields],
                                       Company.Id = response[id],
                                       Company.CreatedOn = response[createdOn],
                                       Company.CreatedById = response[createdById],
                                       Company.LastUpdated = response[lastUpdated],
                                       Company.LastUpdatedById = response[lastUpdatedById],
                                       Company.Version = response[version],
                                       Company.ObjectState = response[objectState],
                                       Company.Token = response[token]
                                      ]})

in
    expandedTable;

 GetTESetting = (url as text) =>
   
   let
   response=   GetDatafromSingleObject (url&"setting/timeexpense",null),

    // Convert the JSON object to a single-row table
     dataTable = Record.ToTable(response),

    // Expand the record into columns with "Company." prefix
    expandedTable = Table.FromRecords({[SettingTE.skipEntryEvaluation = response[skipEntryEvaluation],
                                       SettingTE.evaluateEntryBillableStatusOnValue = response[evaluateEntryBillableStatusOnValue],
                                       SettingTE.createAllocationEntryOnPtoApproval = response[createAllocationEntryOnPtoApproval],
                                       SettingTE.ptoProject = response[ptoProject],
                                       SettingTE.displayPTOProject = response[displayPTOProject],
                                       SettingTE.addEntryMemosToJournal = response[addEntryMemosToJournal],
                                       SettingTE.smallestIncrement = response[smallestIncrement],
                                       SettingTE.smallestStartStopIncrement = response[smallestStartStopIncrement],
                                       SettingTE.ignoreSaveDeleteTimeEntryOlderThan = response[ignoreSaveDeleteTimeEntryOlderThan],
                                       SettingTE.ignoreSaveDeleteTimeEntryNewerThan = response[ignoreSaveDeleteTimeEntryNewerThan],
                                       SettingTE.applySmallestIncrementBillableHoursOnly = response[applySmallestIncrementBillableHoursOnly],
                                       SettingTE.timeEntryMemoRequired = response[timeEntryMemoRequired],
                                       SettingTE.projectAutoApproveTimeEntries = response[projectAutoApproveTimeEntries],
                                       SettingTE.employeeAutoApproveTime = response[employeeAutoApproveTime],
                                       SettingTE.allowNegativeTimeEntry = response[allowNegativeTimeEntry],
                                       SettingTE.allowZeroHourTimeEntry = response[allowZeroHourTimeEntry],
                                       SettingTE.adjustStopTime = response[adjustStopTime],
                                       SettingTE.timeEntryRejectionMemoRequired = response[timeEntryRejectionMemoRequired],
                                       SettingTE.ignoreSaveDeleteExpenseEntryOlderThan = response[ignoreSaveDeleteExpenseEntryOlderThan],
                                       SettingTE.ignoreSaveDeleteExpenseEntryNewerThan = response[ignoreSaveDeleteExpenseEntryNewerThan],
                                       SettingTE.expenseEntryMemoRequired = response[expenseEntryMemoRequired],
                                       SettingTE.projectAutoApproveExpenseEntries = response[projectAutoApproveExpenseEntries],
                                       SettingTE.employeeAutoApproveExpense = response[employeeAutoApproveExpense],
                                       SettingTE.expenseEntryRejectionMemoRequired = response[expenseEntryRejectionMemoRequired]
                                      
                                      ]})

in
    expandedTable;

 GetCrmListsLeadSource = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/lists/leadsource",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/lists/leadsource",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmListsLeadSource"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmListsLeadSource"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmListsLeadSource", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","status"}, {"CrmListsLeadSource.id","CrmListsLeadSource.createdOn","CrmListsLeadSource.createdById","CrmListsLeadSource.lastUpdated","CrmListsLeadSource.lastUpdatedById","CrmListsLeadSource.version","CrmListsLeadSource.objectState","CrmListsLeadSource.token","CrmListsLeadSource.name","CrmListsLeadSource.status"})

 in 
 expandAll;

GetGroup = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"group",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"group",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Group"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Group"}}),

 expandAll = if consolidatedlist{0}?=null then consolidatedlist  else  Table.ExpandRecordColumn(renamedColumn, "Group", {"name", "description", "type", "isActive", "isSystem", "autoAddNewRecords", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Group.name", "Group.description", "Group.type", "Group.isActive", "Group.isSystem", "Group.autoAddNewRecords", "Group.id", "Group.createdOn", "Group.createdById", "Group.lastUpdated", "Group.lastUpdatedById", "Group.version", "Group.objectState", "Group.token"})

 in 
 expandAll;
 
 GetGroupDetail = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"group/detail",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"group/detail",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"GroupDetail"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "GroupDetail"}}),

 expandAll = if consolidatedlist{0}?=null then consolidatedlist  else  Table.ExpandRecordColumn(renamedColumn, "GroupDetail", {"groupId", "entityId", "entity", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"GroupDetail.groupId", "GroupDetail.entityId", "GroupDetail.entity", "GroupDetail.id", "GroupDetail.createdOn", "GroupDetail.createdById", "GroupDetail.lastUpdated", "GroupDetail.lastUpdatedById", "GroupDetail.version", "GroupDetail.objectState", "GroupDetail.token"})

 in 
 expandAll;

 GetCrmListsIndustry = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/lists/industry",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/lists/industry",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmListsIndustry"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmListsIndustry"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmListsIndustry", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","isSystem","status"}, {"CrmListsIndustry.id","CrmListsIndustry.createdOn","CrmListsIndustry.createdById","CrmListsIndustry.lastUpdated","CrmListsIndustry.lastUpdatedById","CrmListsIndustry.version","CrmListsIndustry.objectState","CrmListsIndustry.token","CrmListsIndustry.name","CrmListsIndustry.isSystem","CrmListsIndustry.status"})

 in 
 expandAll;

GetGeneralJournal = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"generaljournal",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"generaljournal",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"GeneralJournal"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "GeneralJournal"}}),

 expandAll =   if consolidatedlist{0}?=null then consolidatedlist  else  Table.ExpandRecordColumn(renamedColumn, "GeneralJournal", {"date", "referenceNumber", "amount", "type", "lineItems", "accountSplits", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token","customFields"}, {"GeneralJournal.date", "GeneralJournal.referenceNumber", "GeneralJournal.amount", "GeneralJournal.type", "GeneralJournal.lineItems", "GeneralJournal.accountSplits", "GeneralJournal.id", "GeneralJournal.createdOn", "GeneralJournal.createdById", "GeneralJournal.lastUpdated", "GeneralJournal.lastUpdatedById", "GeneralJournal.version", "GeneralJournal.objectState", "GeneralJournal.token","GeneralJournal.customFields"})

 in 
 expandAll;
GetFeeSchedule = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"feeschedule",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"feeschedule",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"FeeSchedule"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "FeeSchedule"}}),

 expandAll =   if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "FeeSchedule", {"name", "description", "status", "services", "expenses", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"FeeSchedule.name", "FeeSchedule.description", "FeeSchedule.status", "FeeSchedule.services", "FeeSchedule.expenses", "FeeSchedule.id", "FeeSchedule.createdOn", "FeeSchedule.createdById", "FeeSchedule.lastUpdated", "FeeSchedule.lastUpdatedById", "FeeSchedule.version", "FeeSchedule.objectState", "FeeSchedule.token"})

 in 
 expandAll;

 GetCrmFollowup = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/followup",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/followup",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmFollowup"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmFollowup"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmFollowup", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","date","linkedEntityId","linkedEntity","linkedEntityType","assignedToId","assignedTo","assignedToType","priority","status","reminderDate","description","memo","followUpType","followUpTypeId"}, {"CrmFollowup.id","CrmFollowup.createdOn","CrmFollowup.createdById","CrmFollowup.lastUpdated","CrmFollowup.lastUpdatedById","CrmFollowup.version","CrmFollowup.objectState","CrmFollowup.token","CrmFollowup.date","CrmFollowup.linkedEntityId","CrmFollowup.linkedEntity","CrmFollowup.linkedEntityType","CrmFollowup.assignedToId","CrmFollowup.assignedTo","CrmFollowup.assignedToType","CrmFollowup.priority","CrmFollowup.status","CrmFollowup.reminderDate","CrmFollowup.description","CrmFollowup.memo","CrmFollowup.followUpType","CrmFollowup.followUpTypeId"})

 in 
 expandAll;

 GetCrmListsFollowupType = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/lists/followuptype",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/lists/followuptype",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmListsFollowupType"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmListsFollowupType"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmListsFollowupType", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","status"}, {"CrmListsFollowupType.id","CrmListsFollowupType.createdOn","CrmListsFollowupType.createdById","CrmListsFollowupType.lastUpdated","CrmListsFollowupType.lastUpdatedById","CrmListsFollowupType.version","CrmListsFollowupType.objectState","CrmListsFollowupType.token","CrmListsFollowupType.name","CrmListsFollowupType.status"})

 in 
 expandAll;

 GetFundTransfer = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"fundtransfer",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"fundtransfer",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"FundTransfer"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "FundTransfer"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "FundTransfer", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","date","amount","sourceId","sourceAccount","destinationId","destinationAccount","memo","customFields"}, {"FundTransfer.id","FundTransfer.createdOn","FundTransfer.createdById","FundTransfer.lastUpdated","FundTransfer.lastUpdatedById","FundTransfer.version","FundTransfer.objectState","FundTransfer.token","FundTransfer.date","FundTransfer.amount","FundTransfer.sourceId","FundTransfer.sourceAccount","FundTransfer.destinationId","FundTransfer.destinationAccount","FundTransfer.memo","FundTransfer.customFields"})

 in 
 expandAll;

GetExpenseEntry = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"expenseentry",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"expenseentry",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"ExpenseEntry"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "ExpenseEntry"}}),

 expandAll = if consolidatedlist{0}?=null then consolidatedlist  else  Table.ExpandRecordColumn( renamedColumn, "ExpenseEntry", {"date", "expenseId", "expense", "projectId", "project", "resourceId", "resource", "billable", "billStatus", "description", "units", "costRate", "markup", "chargeAmount", "reimbursable", "paid", "paidDate", "purchaseTaxRate", "currencyMultiplierId", "currencyName", "foreignMultiplier", "foreignCost", "invoiceId", "invoiceNumber", "classification", "tax1", "tax2", "tax3", "memo", "extra", "incomeAccountId", "incomeAccount", "expenseAccountId", "expenseAccount", "vendorBillId", "vendorBillNumber", "client", "workflow", "customFields", "classId", "class", "flag1", "flag2", "flag3", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"ExpenseEntry.date", "ExpenseEntry.expenseId", "ExpenseEntry.expense", "ExpenseEntry.projectId", "ExpenseEntry.project", "ExpenseEntry.resourceId", "ExpenseEntry.resource", "ExpenseEntry.billable", "ExpenseEntry.billStatus", "ExpenseEntry.description", "ExpenseEntry.units", "ExpenseEntry.costRate", "ExpenseEntry.markup", "ExpenseEntry.chargeAmount", "ExpenseEntry.reimbursable", "ExpenseEntry.paid", "ExpenseEntry.paidDate", "ExpenseEntry.purchaseTaxRate", "ExpenseEntry.currencyMultiplierId", "ExpenseEntry.currencyName", "ExpenseEntry.foreignMultiplier", "ExpenseEntry.foreignCost", "ExpenseEntry.invoiceId", "ExpenseEntry.invoiceNumber", "ExpenseEntry.classification", "ExpenseEntry.tax1", "ExpenseEntry.tax2", "ExpenseEntry.tax3", "ExpenseEntry.memo", "ExpenseEntry.extra", "ExpenseEntry.incomeAccountId", "ExpenseEntry.incomeAccount", "ExpenseEntry.expenseAccountId", "ExpenseEntry.expenseAccount", "ExpenseEntry.vendorBillId", "ExpenseEntry.vendorBillNumber", "ExpenseEntry.client", "ExpenseEntry.workflow", "ExpenseEntry.customFields", "ExpenseEntry.classId", "ExpenseEntry.class", "ExpenseEntry.flag1", "ExpenseEntry.flag2", "ExpenseEntry.flag3", "ExpenseEntry.id", "ExpenseEntry.createdOn", "ExpenseEntry.createdById", "ExpenseEntry.lastUpdated", "ExpenseEntry.lastUpdatedById", "ExpenseEntry.version", "ExpenseEntry.objectState", "ExpenseEntry.token"})

 in 
 expandAll;
GetExpense = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"expense",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"expense",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Expense"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Expense"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist  else  Table.ExpandRecordColumn(renamedColumn, "Expense", {"name", "description", "billable", "code", "sub", "costRate", "markup", "tax1", "tax2", "tax3", "reimbursable", "memo", "isActive", "incomeAccountId", "expenseAccountId", "incomeAccount", "expenseAccount", "defaultGroupId", "defaultGroup", "purchaseTaxRate", "customFields", "classId", "class", "isProduct", "type", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Expense.name", "Expense.description", "Expense.billable", "Expense.code", "Expense.sub", "Expense.costRate", "Expense.markup", "Expense.tax1", "Expense.tax2", "Expense.tax3", "Expense.reimbursable", "Expense.memo", "Expense.isActive", "Expense.incomeAccountId", "Expense.expenseAccountId", "Expense.incomeAccount", "Expense.expenseAccount", "Expense.defaultGroupId", "Expense.defaultGroup", "Expense.purchaseTaxRate", "Expense.customFields", "Expense.classId", "Expense.class", "Expense.isProduct", "Expense.type", "Expense.id", "Expense.createdOn", "Expense.createdById", "Expense.lastUpdated", "Expense.lastUpdatedById", "Expense.version", "Expense.objectState", "Expense.token"})

 in 
 expandAll;
GetEstimate = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"estimate",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"estimate",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Estimate"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Estimate"}}),

 expandAll = if consolidatedlist{0}?=null then consolidatedlist  else  Table.ExpandRecordColumn(renamedColumn, "Estimate", {"services", "expenses", "name", "description", "feeScheduleId", "feeSchedule", "miscellaneousAmount", "status", "employeeId", "employee", "serviceSummary", "expenseSummary", "workflow", "customFields", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Estimate.services", "Estimate.expenses", "Estimate.name", "Estimate.description", "Estimate.feeScheduleId", "Estimate.feeSchedule", "Estimate.miscellaneousAmount", "Estimate.status", "Estimate.employeeId", "Estimate.employee", "Estimate.serviceSummary", "Estimate.expenseSummary", "Estimate.workflow", "Estimate.customFields", "Estimate.id", "Estimate.createdOn", "Estimate.createdById", "Estimate.lastUpdated", "Estimate.lastUpdatedById", "Estimate.version", "Estimate.objectState", "Estimate.token"})

 in 
 expandAll;
GetEmployee = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"employee",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"employee",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Employee"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Employee"}}),

 expandAll =   if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Employee", {"billRate", "costRate", "ssn", "displayName", "firstName", "lastName", "middleInitial", "title", "managerId", "manager", "status", "dailyStandardHours", "weeklyStandardHours", "address", "dateHired", "memo", "overtimeCostRate", "overtimeBillRate", "department", "dateReleased", "salary", "salaryPayPeriod", "bankRouting", "bankAccount", "autoDeposit", "salutation", "compTimeHours", "compTimeFrequency", "overheadFactor", "submitTo", "defaultGroupId", "defaultGroup", "currencyId", "currency", "autoOverTime", "autoApproveTimeEntry", "autoApproveExpenseEntry", "payableAccountId", "payableAccount", "securityProfileId", "securityProfile", "company", "role", "gender", "customFields", "assignedGroups", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token", "utilizationTarget", "dateOfBirth"}, {"Employee.billRate", "Employee.costRate", "Employee.ssn", "Employee.displayName", "Employee.firstName", "Employee.lastName", "Employee.middleInitial", "Employee.title", "Employee.managerId", "Employee.manager", "Employee.status", "Employee.dailyStandardHours", "Employee.weeklyStandardHours", "Employee.address", "Employee.dateHired", "Employee.memo", "Employee.overtimeCostRate", "Employee.overtimeBillRate", "Employee.department", "Employee.dateReleased", "Employee.salary", "Employee.salaryPayPeriod", "Employee.bankRouting", "Employee.bankAccount", "Employee.autoDeposit", "Employee.salutation", "Employee.compTimeHours", "Employee.compTimeFrequency", "Employee.overheadFactor", "Employee.submitTo", "Employee.defaultGroupId", "Employee.defaultGroup", "Employee.currencyId", "Employee.currency", "Employee.autoOverTime", "Employee.autoApproveTimeEntry", "Employee.autoApproveExpenseEntry", "Employee.payableAccountId", "Employee.payableAccount", "Employee.securityProfileId", "Employee.securityProfile", "Employee.company", "Employee.role", "Employee.gender", "Employee.customFields", "Employee.assignedGroups", "Employee.id", "Employee.createdOn", "Employee.createdById", "Employee.lastUpdated", "Employee.lastUpdatedById", "Employee.version", "Employee.objectState", "Employee.token", "Employee.utilizationTarget", "Employee.dateOfBirth"})

 in 
 expandAll;

GetDocument = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"document",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"document",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Document"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn=if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Document"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Document", {"date", "name", "description", "entityId", "entity", "entityType", "uri", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token","size"}, {"Document.date", "Document.name", "Document.description", "Document.entityId", "Document.entity", "Document.entityType", "Document.uri", "Document.id", "Document.createdOn", "Document.createdById", "Document.lastUpdated", "Document.lastUpdatedById", "Document.version", "Document.objectState", "Document.token","Document.size"})

 in 
 expandAll;

 GetCrmEmailTemplate = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/emailtemplate",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/emailtemplate",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmEmailTemplate"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmEmailTemplate"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmEmailTemplate", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","subject","body","name","status","description","type"}, {"CrmEmailTemplate.id","CrmEmailTemplate.createdOn","CrmEmailTemplate.createdById","CrmEmailTemplate.lastUpdated","CrmEmailTemplate.lastUpdatedById","CrmEmailTemplate.version","CrmEmailTemplate.objectState","CrmEmailTemplate.token","CrmEmailTemplate.subject","CrmEmailTemplate.body","CrmEmailTemplate.name","CrmEmailTemplate.status","CrmEmailTemplate.description","CrmEmailTemplate.type"})

 in 
 expandAll;

GetDeposit = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"deposit",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"deposit",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),
    
 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Deposit"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Deposit"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else Table.ExpandRecordColumn(renamedColumn, "Deposit", {"date", "accountId", "account", "reference", "amount", "memo", "type", "lineItems", "accountSplits", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token","customFields"}, {"Deposit.date", "Deposit.accountId", "Deposit.account", "Deposit.reference", "Deposit.amount", "Deposit.memo", "Deposit.type", "Deposit.lineItems", "Deposit.accountSplits", "Deposit.id", "Deposit.createdOn", "Deposit.createdById", "Deposit.lastUpdated", "Deposit.lastUpdatedById", "Deposit.version", "Deposit.objectState", "Deposit.token","Deposit.customFields"})



 in 
 expandAll;
GetCustomField = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"customfield",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"customfield",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CustomField"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn=if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CustomField"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CustomField", {"module", "definitionId", "description", "label", "type", "length", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"CustomField.module", "CustomField.definitionId", "CustomField.description", "CustomField.label", "CustomField.type", "CustomField.length", "CustomField.id", "CustomField.createdOn", "CustomField.createdById", "CustomField.lastUpdated", "CustomField.lastUpdatedById", "CustomField.version", "CustomField.objectState", "CustomField.token"})

 in 
 expandAll;



GetCurrency = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"currency",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"currency",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Currency"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn=if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Currency"}}),

 expandAll = if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Currency", {"multiplier", "name", "currencyCode", "cultureCode", "country", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Currency.multiplier", "Currency.name", "Currency.currencyCode", "Currency.cultureCode", "Currency.country", "Currency.id", "Currency.createdOn", "Currency.createdById", "Currency.lastUpdated", "Currency.lastUpdatedById", "Currency.version", "Currency.objectState", "Currency.token"})

 in 
 expandAll;


GetCreditMemo = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"creditmemo",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"creditmemo",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CreditMemo"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CreditMemo"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CreditMemo", {"type", "entityId", "entity", "payableAccountId", "payableAccount", "date", "amount", "referenceNumber", "memo", "lineItems", "refundLineItems", "accountSplits", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"CreditMemo.type", "CreditMemo.entityId", "CreditMemo.entity", "CreditMemo.payableAccountId", "CreditMemo.payableAccount", "CreditMemo.date", "CreditMemo.amount", "CreditMemo.referenceNumber", "CreditMemo.memo", "CreditMemo.lineItems", "CreditMemo.refundLineItems", "CreditMemo.accountSplits", "CreditMemo.id", "CreditMemo.createdOn", "CreditMemo.createdById", "CreditMemo.lastUpdated", "CreditMemo.lastUpdatedById", "CreditMemo.version", "CreditMemo.objectState", "CreditMemo.token"})

 in 
 expandAll;
GetCreditCard = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"creditcard",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"creditcard",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CreditCard"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CreditCard"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CreditCard", {"referenceNumber", "accountId", "account", "date", "amount", "entityId", "entity", "entityType", "type", "memo", "lineItems", "expenseItems", "billItems", "accountSplits", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token", "customFields"}, {"CreditCard.referenceNumber", "CreditCard.accountId", "CreditCard.account", "CreditCard.date", "CreditCard.amount", "CreditCard.entityId", "CreditCard.entity", "CreditCard.entityType", "CreditCard.type", "CreditCard.memo", "CreditCard.lineItems", "CreditCard.expenseItems", "CreditCard.billItems", "CreditCard.accountSplits", "CreditCard.id", "CreditCard.createdOn", "CreditCard.createdById", "CreditCard.lastUpdated", "CreditCard.lastUpdatedById", "CreditCard.version", "CreditCard.objectState", "CreditCard.token","CreditCard.customFields"})

 in 
 expandAll;

GetCostPool = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"costpool",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"costpool",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"costpool"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn=if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CostPool"}}),

 expandAll = if consolidatedlist{0}?=null then consolidatedlist   else  Table.ExpandRecordColumn(renamedColumn, "CostPool", {"name", "isActive", "priority", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"CostPool.name", "CostPool.isActive", "CostPool.priority", "CostPool.id", "CostPool.createdOn", "CostPool.createdById", "CostPool.lastUpdated", "CostPool.lastUpdatedById", "CostPool.version", "CostPool.objectState", "CostPool.token"})

 in 
 expandAll;

GetCommunication = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"communicationtype",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"communicationtype",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Communicationtype"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn=if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CommunicationType"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist  else  Table.ExpandRecordColumn(renamedColumn, "CommunicationType", {"name", "type", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"CommunicationType.name", "CommunicationType.type", "CommunicationType.id", "CommunicationType.createdOn", "CommunicationType.createdById", "CommunicationType.lastUpdated", "CommunicationType.lastUpdatedById", "CommunicationType.version", "CommunicationType.objectState", "CommunicationType.token"})

 in 
 expandAll;

GetClient = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"client",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"client",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Client"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Client"}}),

 expandAll =   if consolidatedlist{0}?=null then consolidatedlist else Table.ExpandRecordColumn(renamedColumn, "Client", {"name", "company", "firstName", "lastName", "middleInitial", "status", "manager", "managerId", "address", "memo", "clientSince", "mainServiceTax", "mainExpenseTax", "termId", "term", "feeScheduleId", "feeScheduleName", "currencyMultiplierId", "currencyName", "messageOnInvoice", "defaultGroupId", "defaultGroup", "customFields", "assignedGroups", "taxId", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token","type"}, {"Client.name", "Client.company", "Client.firstName", "Client.lastName", "Client.middleInitial", "Client.status", "Client.manager", "Client.managerId", "Client.address", "Client.memo", "Client.clientSince", "Client.mainServiceTax", "Client.mainExpenseTax", "Client.termId", "Client.term", "Client.feeScheduleId", "Client.feeScheduleName", "Client.currencyMultiplierId", "Client.currencyName", "Client.messageOnInvoice", "Client.defaultGroupId", "Client.defaultGroup", "Client.customFields", "Client.assignedGroups", "Client.taxId", "Client.id", "Client.createdOn", "Client.createdById", "Client.lastUpdated", "Client.lastUpdatedById", "Client.version", "Client.objectState", "Client.token","Client.type"})

 in 
 expandAll;

 GetCrmCommissionProfile = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/commissionprofile",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/commissionprofile",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmCommissionProfile"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmCommissionProfile"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmCommissionProfile", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","status","details"}, {"CrmCommissionProfile.id","CrmCommissionProfile.createdOn","CrmCommissionProfile.createdById","CrmCommissionProfile.lastUpdated","CrmCommissionProfile.lastUpdatedById","CrmCommissionProfile.version","CrmCommissionProfile.objectState","CrmCommissionProfile.token","CrmCommissionProfile.name","CrmCommissionProfile.status","CrmCommissionProfile.details"})

 in 
 expandAll;

 GetCrmListsCompetition = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/lists/competition",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/lists/competition",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmListsCompetition"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmListsCompetition"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmListsCompetition", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","isSystem","status"}, {"CrmListsCompetition.id","CrmListsCompetition.createdOn","CrmListsCompetition.createdById","CrmListsCompetition.lastUpdated","CrmListsCompetition.lastUpdatedById","CrmListsCompetition.version","CrmListsCompetition.objectState","CrmListsCompetition.token","CrmListsCompetition.name","CrmListsCompetition.isSystem","CrmListsCompetition.status"})

 in 
 expandAll;

 GetContact = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"contact",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"contact",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Contact"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Contact"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Contact", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","contactName","company","firstName","lastName","middleInitial","department","title","salutation","memo","isPrimaryContact","address","customFields","entityId","entityType"}, {"Contact.id","Contact.createdOn","Contact.createdById","Contact.lastUpdated","Contact.lastUpdatedById","Contact.version","Contact.objectState","Contact.token","Contact.contactName","Contact.company","Contact.firstName","Contact.lastName","Contact.middleInitial","Contact.department","Contact.title","Contact.salutation","Contact.memo","Contact.isPrimaryContact","Contact.address","Contact.customFields","Contact.entityId","Contact.entityType"})

 in 
 expandAll;

GetClass = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"class",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"class",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Class"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn=if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Class"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Class", {"name", "isActive", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Class.name", "Class.isActive", "Class.id", "Class.createdOn", "Class.createdById", "Class.lastUpdated", "Class.lastUpdatedById", "Class.version", "Class.objectState", "Class.token"})

 in 
 expandAll;

GetCheck = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"check",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"check",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Check"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Check"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Check", {"number", "accountId", "account", "payeeName", "date", "amount", "printStatus", "isBillPayment", "isVoid", "payeeId", "payee", "payeeType", "isEFT", "address", "memo", "lineItems", "expenseItems", "billItems", "accountSplits", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token", "customFields"}, {"Check.number", "Check.accountId", "Check.account", "Check.payeeName", "Check.date", "Check.amount", "Check.printStatus", "Check.isBillPayment", "Check.isVoid", "Check.payeeId", "Check.payee", "Check.payeeType", "Check.isEFT", "Check.address", "Check.memo", "Check.lineItems", "Check.expenseItems", "Check.billItems", "Check.accountSplits", "Check.id", "Check.createdOn", "Check.createdById", "Check.lastUpdated", "Check.lastUpdatedById", "Check.version", "Check.objectState", "Check.token","Check.customFields"})

 in 
 expandAll;

 GetCrmCampaign = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/campaign",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/campaign",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmCampaign"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmCampaign"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmCampaign", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","status","campaignTypeId","campaignType","startDate","endDate","campaignStatusId","campaignStatus","expectedResponsePercent","expectedRevenue","actualCost","budgetedCost","recipients","workflow","customFields"}, {"CrmCampaign.id","CrmCampaign.createdOn","CrmCampaign.createdById","CrmCampaign.lastUpdated","CrmCampaign.lastUpdatedById","CrmCampaign.version","CrmCampaign.objectState","CrmCampaign.token","CrmCampaign.name","CrmCampaign.status","CrmCampaign.campaignTypeId","CrmCampaign.campaignType","CrmCampaign.startDate","CrmCampaign.endDate","CrmCampaign.campaignStatusId","CrmCampaign.campaignStatus","CrmCampaign.expectedResponsePercent","CrmCampaign.expectedRevenue","CrmCampaign.actualCost","CrmCampaign.budgetedCost","CrmCampaign.recipients","CrmCampaign.workflow","CrmCampaign.customFields"})

 in 
 expandAll;

GeCrmListsCampaignStatus = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/lists/campaignstatus",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/lists/campaignstatus",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmListsCampaignStatus"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmListsCampaignStatus"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmListsCampaignStatus", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","status"}, {"CrmListsCampaignStatus.id","CrmListsCampaignStatus.createdOn","CrmListsCampaignStatus.createdById","CrmListsCampaignStatus.lastUpdated","CrmListsCampaignStatus.lastUpdatedById","CrmListsCampaignStatus.version","CrmListsCampaignStatus.objectState","CrmListsCampaignStatus.token","CrmListsCampaignStatus.name","CrmListsCampaignStatus.status"})

 in 
 expandAll;
 
 GetCrmListsCampaignType = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"crm/lists/campaigntype",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"crm/lists/campaigntype",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"CrmListsCampaignType"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "CrmListsCampaignType"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CrmListsCampaignType", {"id","createdOn","createdById","lastUpdated","lastUpdatedById","version","objectState","token","name","status"}, {"CrmListsCampaignType.id","CrmListsCampaignType.createdOn","CrmListsCampaignType.createdById","CrmListsCampaignType.lastUpdated","CrmListsCampaignType.lastUpdatedById","CrmListsCampaignType.version","CrmListsCampaignType.objectState","CrmListsCampaignType.token","CrmListsCampaignType.name","CrmListsCampaignType.status"})

 in 
 expandAll;

GetBudget = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"budget",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"budget",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Budget"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Budget"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist  else  Table.ExpandRecordColumn(renamedColumn, "Budget", {"services", "expenses", "name", "description", "feeScheduleId", "feeSchedule", "miscellaneousAmount", "status", "employeeId", "employee", "serviceSummary", "expenseSummary", "workflow", "customFields", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Budget.services", "Budget.expenses", "Budget.name", "Budget.description", "Budget.feeScheduleId", "Budget.feeSchedule", "Budget.miscellaneousAmount", "Budget.status", "Budget.employeeId", "Budget.employee", "Budget.serviceSummary", "Budget.expenseSummary", "Budget.workflow", "Budget.customFields", "Budget.id", "Budget.createdOn", "Budget.createdById", "Budget.lastUpdated", "Budget.lastUpdatedById", "Budget.version", "Budget.objectState", "Budget.token"})

 in 
 expandAll;


GetBillingSchedule = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"billingschedule",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"billingschedule",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"BillingSchedule"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "BillingSchedule"}}),

expandAll =   if consolidatedlist{0}?=null then consolidatedlist else Table.ExpandRecordColumn(renamedColumn, "BillingSchedule", {"amount", "remindOn", "retainer", "status", "netBill", "processedOn", "invoiceNumber", "invoiceId", "memo", "useMemoOnInvoice", "includeExtraServices", "includeExtraExpenses", "priority", "projectId", "project", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"BillingSchedule.amount", "BillingSchedule.remindOn", "BillingSchedule.retainer", "BillingSchedule.status", "BillingSchedule.netBill", "BillingSchedule.processedOn", "BillingSchedule.invoiceNumber", "BillingSchedule.invoiceId", "BillingSchedule.memo", "BillingSchedule.useMemoOnInvoice", "BillingSchedule.includeExtraServices", "BillingSchedule.includeExtraExpenses", "BillingSchedule.priority", "BillingSchedule.projectId", "BillingSchedule.project", "BillingSchedule.id", "BillingSchedule.createdOn", "BillingSchedule.createdById", "BillingSchedule.lastUpdated", "BillingSchedule.lastUpdatedById", "BillingSchedule.version", "BillingSchedule.objectState", "BillingSchedule.token"})

 in 
expandAll;


GetBill = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"bill",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"bill",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Bill"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Bill"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Bill", {"number", "date", "vendorId", "vendor", "memo", "dueDate", "referenceNumber", "amount", "lineItems", "expenseItems", "workflow", "accountSplits", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token","customFields","balance","paymentStatus","reimbursable","term","termId"}, {"Bill.number", "Bill.date", "Bill.vendorId", "Bill.vendor", "Bill.memo", "Bill.dueDate", "Bill.referenceNumber", "Bill.amount", "Bill.lineItems", "Bill.expenseItems", "Bill.workflow", "Bill.accountSplits", "Bill.id", "Bill.createdOn", "Bill.createdById", "Bill.lastUpdated", "Bill.lastUpdatedById", "Bill.version", "Bill.objectState", "Bill.token","Bill.customFields","Bill.balance","Bill.paymentStatus","Bill.reimbursable","Bill.term","Bill.termId"})

 in 
 expandAll;

GetAllocation = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"allocation",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"allocation",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Allocation"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn=if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Allocation"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Allocation", {"units", "startsOn", "endsOn", "description", "percentComplete", "priority", "delayByDays", "resourceId", "resourceType", "resource", "projectId", "project", "itemId", "itemType", "item", "resourceTitle", "followsAllocationId", "followsAllocation", "memo", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Allocation.units", "Allocation.startsOn", "Allocation.endsOn", "Allocation.description", "Allocation.percentComplete", "Allocation.priority", "Allocation.delayByDays", "Allocation.resourceId", "Allocation.resourceType", "Allocation.resource", "Allocation.projectId", "Allocation.project", "Allocation.itemId", "Allocation.itemType", "Allocation.item", "Allocation.resourceTitle", "Allocation.followsAllocationId", "Allocation.followsAllocation", "Allocation.memo", "Allocation.id", "Allocation.createdOn", "Allocation.createdById", "Allocation.lastUpdated", "Allocation.lastUpdatedById", "Allocation.version", "Allocation.objectState", "Allocation.token"})

 in 
 expandAll;

GetActivity = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"activity",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"activity",[page]+1,filters ) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Activity"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn=if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Activity"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else Table.ExpandRecordColumn(renamedColumn, "Activity", {"name", "description", "billable", "code", "sub", "costRate", "billRate", "tax1", "tax2", "tax3", "minimumHours", "memo", "isActive", "overTimeBillRate", "incomeAccountId", "expenseAccountId", "incomeAccount", "expenseAccount", "defaultGroupId", "defaultGroup", "extra", "customFields", "classId", "class", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Activity.name", "Activity.description", "Activity.billable", "Activity.code", "Activity.sub", "Activity.costRate", "Activity.billRate", "Activity.tax1", "Activity.tax2", "Activity.tax3", "Activity.minimumHours", "Activity.memo", "Activity.isActive", "Activity.overTimeBillRate", "Activity.incomeAccountId", "Activity.expenseAccountId", "Activity.incomeAccount", "Activity.expenseAccount", "Activity.defaultGroupId", "Activity.defaultGroup", "Activity.extra", "Activity.customFields", "Activity.classId", "Activity.class", "Activity.id", "Activity.createdOn", "Activity.createdById", "Activity.lastUpdated", "Activity.lastUpdatedById", "Activity.version", "Activity.objectState", "Activity.token"})

 in 
 expandAll;

GetAccounts = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"account",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"account",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Account"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn=if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Account"}}),

 expandAll =  if renamedColumn{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Account", {"code", "type", "name", "displayAccount", "description", "level", "rootAccountId", "isActive", "parentAccountId", "parentAccount", "openingBalance", "openingBalanceAsOf", "routingNumber", "runningBalance", "taxLine", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token","customFields"}, {"Account.code", "Account.type", "Account.name", "Account.displayAccount", "Account.description", "Account.level", "Account.rootAccountId", "Account.isActive", "Account.parentAccountId", "Account.parentAccount", "Account.openingBalance", "Account.openingBalanceAsOf", "Account.routingNumber", "Account.runningBalance", "Account.taxLine", "Account.id", "Account.createdOn", "Account.createdById", "Account.lastUpdated", "Account.lastUpdatedById", "Account.version", "Account.objectState", "Account.token","Account.customFields"})
                
           

 in 
 expandAll;

GetProjects = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"project",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"project",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Project"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Project"}}),

 expandAll = if renamedColumn{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Project", {"displayName", "name", "code", "phaseName", "type", "rootProjectId", "rootProject", "level", "contractType", "status", "hasChild", "clientId", "client", "managerId", "manager", "budgetId", "feeScheduleId", "feeScheduleName", "contractAmount", "startDate", "dueDate", "percentComplete", "parentId", "parent", "principalId", "principal", "originatorId", "originator", "invoiceTemplateId", "invoiceTemplate", "manualInvoiceTemplateId", "manualInvoiceTemplate", "jointInvoiceTemplateId", "jointInvoiceTemplate", "memo", "interestRate", "graceDays", "recurringFrequency", "recurringAmount", "mainServiceTax", "mainExpenseTax", "billingContactId", "billingContact", "phaseDescription", "address", "rules", "purchaseOrderNumber", "termId", "term", "currencyMultiplierId", "currencyName", "messageOnInvoice", "hasCustomInvoiceNumber", "invoicePrefix", "invoiceNumber", "invoiceSuffix", "retainagePercent", "retainageLimit", "fixedFee", "fixedFeePercentage", "defaultGroupId", "defaultGroup", "incomeAccountId", "incomeAccount", "expenseAccountId", "expenseAccount", "receivableAccountId", "receivableAccount", "liabilityAccountId", "liabilityAccount", "phaseOrder", "customFields", "assignedGroups", "classId", "class", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token","CompletedOn","budgetName","estimateId","estimateName","expenseContract","serviceContract"}, {"Project.displayName", "Project.name", "Project.code", "Project.phaseName", "Project.type", "Project.rootProjectId", "Project.rootProject", "Project.level", "Project.contractType", "Project.status", "Project.hasChild", "Project.clientId", "Project.client", "Project.managerId", "Project.manager", "Project.budgetId", "Project.feeScheduleId", "Project.feeScheduleName", "Project.contractAmount", "Project.startDate", "Project.dueDate", "Project.percentComplete", "Project.parentId", "Project.parent", "Project.principalId", "Project.principal", "Project.originatorId", "Project.originator", "Project.invoiceTemplateId", "Project.invoiceTemplate", "Project.manualInvoiceTemplateId", "Project.manualInvoiceTemplate", "Project.jointInvoiceTemplateId", "Project.jointInvoiceTemplate", "Project.memo", "Project.interestRate", "Project.graceDays", "Project.recurringFrequency", "Project.recurringAmount", "Project.mainServiceTax", "Project.mainExpenseTax", "Project.billingContactId", "Project.billingContact", "Project.phaseDescription", "Project.address", "Project.rules", "Project.purchaseOrderNumber", "Project.termId", "Project.term", "Project.currencyMultiplierId", "Project.currencyName", "Project.messageOnInvoice", "Project.hasCustomInvoiceNumber", "Project.invoicePrefix", "Project.invoiceNumber", "Project.invoiceSuffix", "Project.retainagePercent", "Project.retainageLimit", "Project.fixedFee", "Project.fixedFeePercentage", "Project.defaultGroupId", "Project.defaultGroup", "Project.incomeAccountId", "Project.incomeAccount", "Project.expenseAccountId", "Project.expenseAccount", "Project.receivableAccountId", "Project.receivableAccount", "Project.liabilityAccountId", "Project.liabilityAccount", "Project.phaseOrder", "Project.customFields", "Project.assignedGroups", "Project.classId", "Project.class", "Project.id", "Project.createdOn", "Project.createdById", "Project.lastUpdated", "Project.lastUpdatedById", "Project.version", "Project.objectState", "Project.token", "Project.CompletedOn","Project.budgetName","Project.estimateId","Project.estimateName","Project.expenseContract","Project.serviceContract"})

 in 
 expandAll;

     
//Handles the paging and the custom filters
GetDatafromSingleObject=(url as text , optional expandexpression as text) =>

let
     Source =  if Value.Equals(expandexpression, "") or Value.Equals(expandexpression, null)  then
             Web.Contents(url)
             else 
             Web.Contents(url&"?"&expandexpression),
   
// Web.Contents(url,[Query=[page=Number.ToText(page)&",100"]])
            
json = Json.Document(Source),

 // Check if JSON is valid
    result = if json = null then null else json
in
    result;

GetData=(url as text ,  page as number, optional expandexpression as text) =>

let
   
   Source =  if Value.Equals(expandexpression, "") or Value.Equals(expandexpression, null)  then
             Web.Contents(url&"?page=" & Number.ToText(page)&",100")
// Web.Contents(url,[Query=[page=Number.ToText(page)&",100"]])
            else
//Web.Contents(url,[Query=[page=Number.ToText(page)&",100"&expandexpression]]),

             Web.Contents(url&"?page=" & Number.ToText(page)&",100"&expandexpression),
json = Json.Document(Source),

test = if(json=null or json{0}? =null) then null else json

in
   test;



// Data Source Kind description
BQECore = [
 TestConnection = (dataSourcePath) => { "BQECore.Contents" },
Authentication = [
OAuth = [
StartLogin = StartLogin,
FinishLogin = FinishLogin,
Refresh = Refresh,
Label = "CORE Login"
]
],
Label = Extension.LoadString("DataSourceLabel")
];



StartLogin = (resourceUrl, state, display) =>
let
AuthorizeUrl = "https://api-identity.bqecore.com/idp/connect/authorize?" & Uri.BuildQueryString([
client_id = client_id,
state = state,
response_type = "code",
scope="openid offline_access profile read:core",
redirect_uri = redirect_uri])
in
[
LoginUri = AuthorizeUrl,
CallbackUri = redirect_uri,
WindowHeight = windowHeight,
WindowWidth = windowWidth,
Context = null
];

FinishLogin = (context, callbackUri, state) =>
let
parts = Uri.Parts(callbackUri)[Query],
result = if (Record.HasFields(parts, {"error", "error_description"})) then
error Error.Record(parts[error], parts[error_description], parts)
else
TokenMethod("authorization_code", parts[code])
in
result;

TokenMethod = (grantType, code) =>
let
query = [
client_id = client_id,
client_secret = client_secret,
code = code,
grant_type = if(grantType="refresh_token") then "refresh_token" else "authorization_code",
redirect_uri = redirect_uri],

queryWithCode = if (grantType = "refresh_token") then [ refresh_token = code ] else [code = code],

Response = Web.Contents("https://api-identity.bqecore.com/idp/connect/token", [
Content = Text.ToBinary(Uri.BuildQueryString(query & queryWithCode)),
Headers=[#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json"], ManualStatusHandling = {400}]),


Parts = Json.Document(Response),

Result = if (Record.HasFields(Parts, {"error", "error_description"})) then
error Error.Record(Parts[error], Parts[error_description], Parts)
else
Parts
in
Result;

Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", refresh_token);

// Data Source UI publishing description
BQECore.Publish = [
Beta = false,
Category = "Other",
ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
LearnMoreUrl = "https://corehelpcenter.bqe.com/hc/en-us/articles/360061565354-Core-Microsoft-Power-BI-integration",
SourceImage = BQECore.Icons,
SourceTypeImage =BQECore.Icons
];

BQECore.Icons = [
Icon16 = { Extension.Contents("BQECore16.png"), Extension.Contents("BQECore20.png"), Extension.Contents("BQECore24.png"), Extension.Contents("BQECore32.png") },
Icon32 = { Extension.Contents("BQECore32.png"), Extension.Contents("BQECore40.png"), Extension.Contents("BQECore48.png"), Extension.Contents("BQECore64.png") }
];

