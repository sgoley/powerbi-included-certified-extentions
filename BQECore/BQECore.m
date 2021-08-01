[Version = "1.0.0"]
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
            { "Activity", ActivityExtension.Contents, "Table", "Table", true },
            { "Allocation", AllocationExtension.Contents, "Table", "Table", true },
             { "Bill", BillExtension.Contents, "Table", "Table", true },
              { "BillingSchedule", BillingScheduleExtension.Contents, "Table", "Table", true },
               { "Budget", BudgetExtension.Contents, "Table", "Table", true },
                 { "Check", CheckExtension.Contents, "Table", "Table", true },
                   { "Class", ClassExtension.Contents, "Table", "Table", true },
                    { "Client", ClientExtension.Contents, "Table", "Table", true },
                     { "CommunicationType", CommunicationExtension.Contents, "Table", "Table", true },
                      { "CostPool", CostPoolExtension.Contents, "Table", "Table", true },
                       { "CreditCard", CreditCardExtension.Contents, "Table", "Table", true },
                         { "CreditMemo", CreditMemoExtension.Contents, "Table", "Table", true },
                          { "Currency", CurrencyExtension.Contents, "Table", "Table", true },
                           { "CustomField", CustomFieldExtension.Contents, "Table", "Table", true },
 { "Deposit", DepositExtension.Contents, "Table", "Table", true },
                             { "Document", DocumentExtension.Contents, "Table", "Table", true },
                              { "Employee", EmployeeExtension.Contents, "Table", "Table", true },
                              { "Estimate", EstimateExtension.Contents, "Table", "Table", true },
                               { "Expense", ExpenseExtension.Contents, "Table", "Table", true },
                                
                                    { "FeeSchedule", FeeScheduleExtension.Contents, "Table", "Table", true },
                                     { "GeneralJournal", GeneralJournalExtension.Contents, "Table", "Table", true },
                                      { "Group", GroupExtension.Contents, "Table", "Table", true },
                                       { "Invoice", InvoiceExtension.Contents, "Table", "Table", true },
                                        { "NoteCategory", NoteCategoryExtension.Contents, "Table", "Table", true },
                                           { "Note", NoteExtension.Contents, "Table", "Table", true },
                                            { "NoteStatus", NoteStatusExtension.Contents, "Table", "Table", true },
                                             { "Payment", PaymentExtension.Contents, "Table", "Table", true },
                                               { "ProjectAssignment", ProjectAssignmentExtension.Contents, "Table", "Table", true },
                                                 { "Project", PRGExtension.Contents, "Table", "Table", true },
                                                   { "PurchaseOrder", PurchaseOrderExtension.Contents, "Table", "Table", true },
                                                    { "Term", TermExtension.Contents, "Table", "Table", true },

                                                         { "Timer", TimerExtension.Contents, "Table", "Table", true },
                                                         {"TimeEntry",  TEExtension.Contents , "Table", "Table", true},
                                               { "ExpenseEntry", ExpenseEntryExtension.Contents, "Table", "Table", true },
//                                               
//                                                         
//                                                     
                                                       { "ToDo", ToDoExtension.Contents, "Table", "Table", true },
                                                        { "Vendor", VendorExtension.Contents, "Table", "Table", true },
                                                        { "VendorCredit", VendorCreditExtension.Contents, "Table", "Table", true }
            
        }),
        navTable = Table.ToNavigationTable(source, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;
  



VendorCreditExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetVendorCredit(BaseUrl,finalstring) else GetVendorCredit(BaseUrl)

in
a;



VendorExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetVendor(BaseUrl,finalstring) else GetVendor(BaseUrl)

in
a;

ToDoExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetToDo(BaseUrl,finalstring) else GetToDo(BaseUrl)

in
a;

TimerExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetTimer(BaseUrl,finalstring) else GetTimer(BaseUrl)

in
a;

TermExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetTerm(BaseUrl,finalstring) else  GetTerm(BaseUrl)

in
a;



PurchaseOrderExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetPurchaseOrder(BaseUrl,finalstring) else  GetPurchaseOrder(BaseUrl)

in
a;



ProjectAssignmentExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetProjectAssignment(BaseUrl,finalstring) else  GetProjectAssignment(BaseUrl)

in
a;



PaymentExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetPayment(BaseUrl,finalstring) else  GetPayment(BaseUrl)

in
a;


NoteStatusExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetNoteStatus(BaseUrl,finalstring) else  GetNoteStatus(BaseUrl)

in
a;


NoteExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetNote(BaseUrl,finalstring) else  GetNote(BaseUrl)

in
a;


NoteCategoryExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetNoteCategory(BaseUrl,finalstring) else  GetNoteCategory(BaseUrl)

in
a;


InvoiceExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetInvoice(BaseUrl,finalstring) else  GetInvoice(BaseUrl)

in
a;



GroupExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetGroup(BaseUrl,finalstring) else  GetGroup(BaseUrl)

in
a;



GeneralJournalExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetGeneralJournal(BaseUrl,finalstring) else  GetGeneralJournal(BaseUrl)

in
a;


FeeScheduleExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetFeeSchedule(BaseUrl,finalstring) else  GetFeeSchedule(BaseUrl)

in
a;


ExpenseExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetExpense(BaseUrl,finalstring) else  GetExpense(BaseUrl)

in
a;


EstimateExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetEstimate(BaseUrl,finalstring) else  GetEstimate(BaseUrl)

in
a;


EmployeeExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetEmployee(BaseUrl,finalstring) else  GetEmployee(BaseUrl)

in
a;



DocumentExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetDocument(BaseUrl,finalstring) else  GetDocument(BaseUrl)

in
a;


DepositExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetDeposit(BaseUrl,finalstring) else  GetDeposit(BaseUrl)

in
a;


CustomFieldExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetCustomField(BaseUrl,finalstring) else  GetCustomField(BaseUrl)

in
a;



CurrencyExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetCurrency(BaseUrl,finalstring) else  GetCurrency(BaseUrl)

in
a;


CreditMemoExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetCreditMemo(BaseUrl,finalstring) else  GetCreditMemo(BaseUrl)

in
a;



CreditCardExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetCreditCard(BaseUrl,finalstring) else  GetCreditCard(BaseUrl)

in
a;



CostPoolExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetCostPool(BaseUrl,finalstring) else  GetCostPool(BaseUrl)

in
a;

CommunicationExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetCommunication(BaseUrl,finalstring) else  GetCommunication(BaseUrl)

in
a;

ClientExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetClient(BaseUrl,finalstring) else  GetClient(BaseUrl)

in
a;

ClassExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetClass(BaseUrl,finalstring) else  GetClass(BaseUrl)

in
a;

CheckExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetCheck(BaseUrl,finalstring) else  GetCheck(BaseUrl)

in
a;


BudgetExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetBudget(BaseUrl,finalstring) else  GetBudget(BaseUrl)

in
a;

BillingScheduleExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetBillingSchedule(BaseUrl,finalstring) else  GetBillingSchedule(BaseUrl)

in
a;

BillExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetBill(BaseUrl,finalstring) else  GetBill(BaseUrl)

in
a;


AllocationExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetAllocation(BaseUrl,finalstring) else  GetAllocation(BaseUrl)

in
a;


ActivityExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetActivity(BaseUrl,finalstring) else  GetActivity(BaseUrl)

in
a;


AccountsExtension.Contents =(optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetAccounts(BaseUrl,finalstring) else  GetAccounts(BaseUrl)

in
a;


ExpenseEntryExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetExpenseEntry(BaseUrl,finalstring) else  GetExpenseEntry(BaseUrl)

in
a;



PRGExtension.Contents = (optional Where as text, optional Expand as text) =>
let

finalstring = BuildFilterstring(Where,Expand),

a = if(finalstring<>null) then  GetProjects(BaseUrl,finalstring) else  GetProjects(BaseUrl)

in
a;



TEExtension.Contents = (optional Where as text, optional Expand as text) =>
let

// filterstring = 
// if(Fields<>null) then "&Fields="&Fields else 
// null,
// test = if(filterstring=null)
//         then if(Where=null) then null else "&Where="&Where 
//         else
//         if(Where=null) then filterstring else filterstring&"&Where="&Where,
// finalstring = if(test=null)
//         then if(Expand=null) then null else "&Expand="&Expand 
//         else
//         if(Expand=null) then test else test&"&Expand="&Expand,

finalstring= BuildFilterstring(Where, Expand),

a = if(finalstring<>null) then  GetTime(BaseUrl,finalstring) else  GetTime(BaseUrl)

in
a;





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

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist  else  Table.ExpandRecordColumn(renamedColumn, "VendorCredit", {"vendorId", "vendor", "date", "reference", "amount", "accountId", "account", "balance", "memo", "lineItems", "accountSplits", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"VendorCredit.vendorId", "VendorCredit.vendor", "VendorCredit.date", "VendorCredit.reference", "VendorCredit.amount", "VendorCredit.accountId", "VendorCredit.account", "VendorCredit.balance", "VendorCredit.memo", "VendorCredit.lineItems", "VendorCredit.accountSplits", "VendorCredit.id", "VendorCredit.createdOn", "VendorCredit.createdById", "VendorCredit.lastUpdated", "VendorCredit.lastUpdatedById", "VendorCredit.version", "VendorCredit.objectState", "VendorCredit.token"})

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

 expandAll =   if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Vendor", {"type", "termId", "term", "billRate", "costRate", "is1099Applicable", "taxId", "displayName", "firstName", "lastName", "middleInitial", "title", "managerId", "manager", "status", "dailyStandardHours", "weeklyStandardHours", "address", "dateHired", "memo", "overtimeCostRate", "overtimeBillRate", "department", "dateReleased", "salary", "salaryPayPeriod", "bankRouting", "bankAccount", "autoDeposit", "salutation", "compTimeHours", "compTimeFrequency", "overheadFactor", "submitTo", "defaultGroupId", "defaultGroup", "currencyId", "currency", "autoOverTime", "autoApproveTimeEntry", "autoApproveExpenseEntry", "payableAccountId", "payableAccount", "securityProfileId", "securityProfile", "company", "role", "gender", "customFields", "assignedGroups", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Vendor.type", "Vendor.termId", "Vendor.term", "Vendor.billRate", "Vendor.costRate", "Vendor.is1099Applicable", "Vendor.taxId", "Vendor.displayName", "Vendor.firstName", "Vendor.lastName", "Vendor.middleInitial", "Vendor.title", "Vendor.managerId", "Vendor.manager", "Vendor.status", "Vendor.dailyStandardHours", "Vendor.weeklyStandardHours", "Vendor.address", "Vendor.dateHired", "Vendor.memo", "Vendor.overtimeCostRate", "Vendor.overtimeBillRate", "Vendor.department", "Vendor.dateReleased", "Vendor.salary", "Vendor.salaryPayPeriod", "Vendor.bankRouting", "Vendor.bankAccount", "Vendor.autoDeposit", "Vendor.salutation", "Vendor.compTimeHours", "Vendor.compTimeFrequency", "Vendor.overheadFactor", "Vendor.submitTo", "Vendor.defaultGroupId", "Vendor.defaultGroup", "Vendor.currencyId", "Vendor.currency", "Vendor.autoOverTime", "Vendor.autoApproveTimeEntry", "Vendor.autoApproveExpenseEntry", "Vendor.payableAccountId", "Vendor.payableAccount", "Vendor.securityProfileId", "Vendor.securityProfile", "Vendor.company", "Vendor.role", "Vendor.gender", "Vendor.customFields", "Vendor.assignedGroups", "Vendor.id", "Vendor.createdOn", "Vendor.createdById", "Vendor.lastUpdated", "Vendor.lastUpdatedById", "Vendor.version", "Vendor.objectState", "Vendor.token"})

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

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Timeentry", {"date", "activityId", "activity", "projectId", "project", "resourceId", "resource", "billable", "billStatus", "description", "actualHours", "clientHours", "billRate", "costRate", "overtime", "invoiceId", "invoiceNumber", "classification", "tax1", "tax2", "tax3", "memo", "extra", "incomeAccountId", "incomeAccount", "expenseAccountId", "expenseAccount", "startInterval", "startTime", "stopInterval", "stopTime", "vendorBillId", "vendorBillNumber", "client", "classId", "class", "workflow", "customFields", "wudPercent", "flag1", "flag2", "flag3", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Timeentry.date", "Timeentry.activityId", "Timeentry.activity", "Timeentry.projectId", "Timeentry.project", "Timeentry.resourceId", "Timeentry.resource", "Timeentry.billable", "Timeentry.billStatus", "Timeentry.description", "Timeentry.actualHours", "Timeentry.clientHours", "Timeentry.billRate", "Timeentry.costRate", "Timeentry.overtime", "Timeentry.invoiceId", "Timeentry.invoiceNumber", "Timeentry.classification", "Timeentry.tax1", "Timeentry.tax2", "Timeentry.tax3", "Timeentry.memo", "Timeentry.extra", "Timeentry.incomeAccountId", "Timeentry.incomeAccount", "Timeentry.expenseAccountId", "Timeentry.expenseAccount", "Timeentry.startInterval", "Timeentry.startTime", "Timeentry.stopInterval", "Timeentry.stopTime", "Timeentry.vendorBillId", "Timeentry.vendorBillNumber", "Timeentry.client", "Timeentry.classId", "Timeentry.class", "Timeentry.workflow", "Timeentry.customFields", "Timeentry.wudPercent", "Timeentry.flag1", "Timeentry.flag2", "Timeentry.flag3", "Timeentry.id", "Timeentry.createdOn", "Timeentry.createdById", "Timeentry.lastUpdated", "Timeentry.lastUpdatedById", "Timeentry.version", "Timeentry.objectState", "Timeentry.token"})

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

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"Invoice"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "Invoice"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Invoice", {"number", "date", "dueDate", "paymentTermId", "paymentTerm", "entityId", "entity", "entityType", "isActive", "amount", "memo", "address", "vendor", "vendorId", "lineItems", "workflow", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Invoice.number", "Invoice.date", "Invoice.dueDate", "Invoice.paymentTermId", "Invoice.paymentTerm", "Invoice.entityId", "Invoice.entity", "Invoice.entityType", "Invoice.isActive", "Invoice.amount", "Invoice.memo", "Invoice.address", "Invoice.vendor", "Invoice.vendorId", "Invoice.lineItems", "Invoice.workflow", "Invoice.id", "Invoice.createdOn", "Invoice.createdById", "Invoice.lastUpdated", "Invoice.lastUpdatedById", "Invoice.version", "Invoice.objectState", "Invoice.token"})

 in 
 expandAll;
GetProjectAssignment = (url as text, optional filters as text) =>
   
   let
   response=   

    List.Generate(()=>
        [Result = try GetData(url&"projectassignment/resource",1,filters) otherwise null, page=1],
        each [Result]<> null,
        each [Result = try GetData(url&"projectassignment/resource",[page]+1,filters) otherwise null, page= [page]+1],
        each [Result]),

 tableOfPages = Table.FromList(response, Splitter.SplitByNothing(), {"ProjectAssignment"}),

consolidatedlist = Table.FromList(List.Combine(response), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
renamedColumn= if consolidatedlist{0}?=null then consolidatedlist else Table.RenameColumns(consolidatedlist,{{"Column1", "ProjectAssignment"}}),

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "ProjectAssignment", {"resourceId", "resource", "resourceType", "classification", "projectId", "project", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"ProjectAssignment.resourceId", "ProjectAssignment.resource", "ProjectAssignment.resourceType", "ProjectAssignment.classification", "ProjectAssignment.projectId", "ProjectAssignment.project", "ProjectAssignment.id", "ProjectAssignment.createdOn", "ProjectAssignment.createdById", "ProjectAssignment.lastUpdated", "ProjectAssignment.lastUpdatedById", "ProjectAssignment.version", "ProjectAssignment.objectState", "ProjectAssignment.token"})

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

 expandAll =   if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Payment", {"date", "reference", "note", "clientId", "client", "projectId", "project", "method", "amount", "lineItems", "isRetainer", "retainerType", "assetAccountId", "assetAccount", "liabilityAccountId", "liabilityAccount", "badDebtExpenseAccountId", "badDebtExpenseAccount", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Payment.date", "Payment.reference", "Payment.note", "Payment.clientId", "Payment.client", "Payment.projectId", "Payment.project", "Payment.method", "Payment.amount", "Payment.lineItems", "Payment.isRetainer", "Payment.retainerType", "Payment.assetAccountId", "Payment.assetAccount", "Payment.liabilityAccountId", "Payment.liabilityAccount", "Payment.badDebtExpenseAccountId", "Payment.badDebtExpenseAccount", "Payment.id", "Payment.createdOn", "Payment.createdById", "Payment.lastUpdated", "Payment.lastUpdatedById", "Payment.version", "Payment.objectState", "Payment.token"})

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

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist   else  Table.ExpandRecordColumn(renamedColumn, "Invoice", {"invoiceNumber", "date", "status", "invoiceAmount", "dueDate", "isManualInvoice", "isLateFeeInvoice", "isDraft", "balance", "serviceAmount", "expenseAmount", "serviceTaxAmount", "expenseTaxAmount", "mainServiceTax", "mainExpenseTax", "fixedFee", "isJointInvoice", "invoiceDetails", "lineItems", "invoiceFrom", "invoiceTo", "messageOnInvoice", "billingContactId", "referenceNumber", "rfNumber", "purchaseOrderNumber", "workflow", "customFields", "accountSplits", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Invoice.invoiceNumber", "Invoice.date", "Invoice.status", "Invoice.invoiceAmount", "Invoice.dueDate", "Invoice.isManualInvoice", "Invoice.isLateFeeInvoice", "Invoice.isDraft", "Invoice.balance", "Invoice.serviceAmount", "Invoice.expenseAmount", "Invoice.serviceTaxAmount", "Invoice.expenseTaxAmount", "Invoice.mainServiceTax", "Invoice.mainExpenseTax", "Invoice.fixedFee", "Invoice.isJointInvoice", "Invoice.invoiceDetails", "Invoice.lineItems", "Invoice.invoiceFrom", "Invoice.invoiceTo", "Invoice.messageOnInvoice", "Invoice.billingContactId", "Invoice.referenceNumber", "Invoice.rfNumber", "Invoice.purchaseOrderNumber", "Invoice.workflow", "Invoice.customFields", "Invoice.accountSplits", "Invoice.id", "Invoice.createdOn", "Invoice.createdById", "Invoice.lastUpdated", "Invoice.lastUpdatedById", "Invoice.version", "Invoice.objectState", "Invoice.token"})

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

 expandAll =   if consolidatedlist{0}?=null then consolidatedlist  else  Table.ExpandRecordColumn(renamedColumn, "GeneralJournal", {"date", "referenceNumber", "amount", "type", "lineItems", "accountSplits", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"GeneralJournal.date", "GeneralJournal.referenceNumber", "GeneralJournal.amount", "GeneralJournal.type", "GeneralJournal.lineItems", "GeneralJournal.accountSplits", "GeneralJournal.id", "GeneralJournal.createdOn", "GeneralJournal.createdById", "GeneralJournal.lastUpdated", "GeneralJournal.lastUpdatedById", "GeneralJournal.version", "GeneralJournal.objectState", "GeneralJournal.token"})

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

 expandAll =   if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Employee", {"billRate", "costRate", "ssn", "displayName", "firstName", "lastName", "middleInitial", "title", "managerId", "manager", "status", "dailyStandardHours", "weeklyStandardHours", "address", "dateHired", "memo", "overtimeCostRate", "overtimeBillRate", "department", "dateReleased", "salary", "salaryPayPeriod", "bankRouting", "bankAccount", "autoDeposit", "salutation", "compTimeHours", "compTimeFrequency", "overheadFactor", "submitTo", "defaultGroupId", "defaultGroup", "currencyId", "currency", "autoOverTime", "autoApproveTimeEntry", "autoApproveExpenseEntry", "payableAccountId", "payableAccount", "securityProfileId", "securityProfile", "company", "role", "gender", "customFields", "assignedGroups", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Employee.billRate", "Employee.costRate", "Employee.ssn", "Employee.displayName", "Employee.firstName", "Employee.lastName", "Employee.middleInitial", "Employee.title", "Employee.managerId", "Employee.manager", "Employee.status", "Employee.dailyStandardHours", "Employee.weeklyStandardHours", "Employee.address", "Employee.dateHired", "Employee.memo", "Employee.overtimeCostRate", "Employee.overtimeBillRate", "Employee.department", "Employee.dateReleased", "Employee.salary", "Employee.salaryPayPeriod", "Employee.bankRouting", "Employee.bankAccount", "Employee.autoDeposit", "Employee.salutation", "Employee.compTimeHours", "Employee.compTimeFrequency", "Employee.overheadFactor", "Employee.submitTo", "Employee.defaultGroupId", "Employee.defaultGroup", "Employee.currencyId", "Employee.currency", "Employee.autoOverTime", "Employee.autoApproveTimeEntry", "Employee.autoApproveExpenseEntry", "Employee.payableAccountId", "Employee.payableAccount", "Employee.securityProfileId", "Employee.securityProfile", "Employee.company", "Employee.role", "Employee.gender", "Employee.customFields", "Employee.assignedGroups", "Employee.id", "Employee.createdOn", "Employee.createdById", "Employee.lastUpdated", "Employee.lastUpdatedById", "Employee.version", "Employee.objectState", "Employee.token"})

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

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Document", {"date", "name", "description", "entityId", "entity", "entityType", "uri", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Document.date", "Document.name", "Document.description", "Document.entityId", "Document.entity", "Document.entityType", "Document.uri", "Document.id", "Document.createdOn", "Document.createdById", "Document.lastUpdated", "Document.lastUpdatedById", "Document.version", "Document.objectState", "Document.token"})

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

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else Table.ExpandRecordColumn(renamedColumn, "Deposit", {"date", "accountId", "account", "reference", "amount", "memo", "type", "lineItems", "accountSplits", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Deposit.date", "Deposit.accountId", "Deposit.account", "Deposit.reference", "Deposit.amount", "Deposit.memo", "Deposit.type", "Deposit.lineItems", "Deposit.accountSplits", "Deposit.id", "Deposit.createdOn", "Deposit.createdById", "Deposit.lastUpdated", "Deposit.lastUpdatedById", "Deposit.version", "Deposit.objectState", "Deposit.token"})



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

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "CreditCard", {"referenceNumber", "accountId", "account", "date", "amount", "entityId", "entity", "entityType", "type", "memo", "lineItems", "expenseItems", "billItems", "accountSplits", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"CreditCard.referenceNumber", "CreditCard.accountId", "CreditCard.account", "CreditCard.date", "CreditCard.amount", "CreditCard.entityId", "CreditCard.entity", "CreditCard.entityType", "CreditCard.type", "CreditCard.memo", "CreditCard.lineItems", "CreditCard.expenseItems", "CreditCard.billItems", "CreditCard.accountSplits", "CreditCard.id", "CreditCard.createdOn", "CreditCard.createdById", "CreditCard.lastUpdated", "CreditCard.lastUpdatedById", "CreditCard.version", "CreditCard.objectState", "CreditCard.token"})

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

 expandAll =   if consolidatedlist{0}?=null then consolidatedlist else Table.ExpandRecordColumn(renamedColumn, "Client", {"name", "company", "firstName", "lastName", "middleInitial", "status", "manager", "managerId", "address", "memo", "clientSince", "mainServiceTax", "mainExpenseTax", "termId", "term", "feeScheduleId", "feeScheduleName", "currencyMultiplierId", "currencyName", "messageOnInvoice", "defaultGroupId", "defaultGroup", "customFields", "assignedGroups", "taxId", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Client.name", "Client.company", "Client.firstName", "Client.lastName", "Client.middleInitial", "Client.status", "Client.manager", "Client.managerId", "Client.address", "Client.memo", "Client.clientSince", "Client.mainServiceTax", "Client.mainExpenseTax", "Client.termId", "Client.term", "Client.feeScheduleId", "Client.feeScheduleName", "Client.currencyMultiplierId", "Client.currencyName", "Client.messageOnInvoice", "Client.defaultGroupId", "Client.defaultGroup", "Client.customFields", "Client.assignedGroups", "Client.taxId", "Client.id", "Client.createdOn", "Client.createdById", "Client.lastUpdated", "Client.lastUpdatedById", "Client.version", "Client.objectState", "Client.token"})

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

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Check", {"number", "accountId", "account", "payeeName", "date", "amount", "printStatus", "isBillPayment", "isVoid", "payeeId", "payee", "payeeType", "isEFT", "address", "memo", "lineItems", "expenseItems", "billItems", "accountSplits", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Check.number", "Check.accountId", "Check.account", "Check.payeeName", "Check.date", "Check.amount", "Check.printStatus", "Check.isBillPayment", "Check.isVoid", "Check.payeeId", "Check.payee", "Check.payeeType", "Check.isEFT", "Check.address", "Check.memo", "Check.lineItems", "Check.expenseItems", "Check.billItems", "Check.accountSplits", "Check.id", "Check.createdOn", "Check.createdById", "Check.lastUpdated", "Check.lastUpdatedById", "Check.version", "Check.objectState", "Check.token"})

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

 expandAll =  if consolidatedlist{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Bill", {"number", "date", "vendorId", "vendor", "memo", "dueDate", "referenceNumber", "amount", "lineItems", "expenseItems", "workflow", "accountSplits", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Bill.number", "Bill.date", "Bill.vendorId", "Bill.vendor", "Bill.memo", "Bill.dueDate", "Bill.referenceNumber", "Bill.amount", "Bill.lineItems", "Bill.expenseItems", "Bill.workflow", "Bill.accountSplits", "Bill.id", "Bill.createdOn", "Bill.createdById", "Bill.lastUpdated", "Bill.lastUpdatedById", "Bill.version", "Bill.objectState", "Bill.token"})

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

 expandAll =  if renamedColumn{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Account", {"code", "type", "name", "displayAccount", "description", "level", "rootAccountId", "isActive", "parentAccountId", "parentAccount", "openingBalance", "openingBalanceAsOf", "routingNumber", "runningBalance", "taxLine", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Account.code", "Account.type", "Account.name", "Account.displayAccount", "Account.description", "Account.level", "Account.rootAccountId", "Account.isActive", "Account.parentAccountId", "Account.parentAccount", "Account.openingBalance", "Account.openingBalanceAsOf", "Account.routingNumber", "Account.runningBalance", "Account.taxLine", "Account.id", "Account.createdOn", "Account.createdById", "Account.lastUpdated", "Account.lastUpdatedById", "Account.version", "Account.objectState", "Account.token"})
                
           

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

 expandAll = if renamedColumn{0}?=null then consolidatedlist else  Table.ExpandRecordColumn(renamedColumn, "Project", {"displayName", "name", "code", "phaseName", "type", "rootProjectId", "rootProject", "level", "contractType", "status", "hasChild", "clientId", "client", "managerId", "manager", "feeScheduleId", "feeScheduleName", "contractAmount", "startDate", "dueDate", "percentComplete", "parentId", "parent", "principalId", "principal", "originatorId", "originator", "invoiceTemplateId", "invoiceTemplate", "manualInvoiceTemplateId", "manualInvoiceTemplate", "jointInvoiceTemplateId", "jointInvoiceTemplate", "memo", "interestRate", "graceDays", "recurringFrequency", "recurringAmount", "mainServiceTax", "mainExpenseTax", "billingContactId", "billingContact", "phaseDescription", "address", "rules", "purchaseOrderNumber", "termId", "term", "currencyMultiplierId", "currencyName", "messageOnInvoice", "hasCustomInvoiceNumber", "invoicePrefix", "invoiceNumber", "invoiceSuffix", "retainagePercent", "retainageLimit", "fixedFee", "fixedFeePercentage", "defaultGroupId", "defaultGroup", "incomeAccountId", "incomeAccount", "expenseAccountId", "expenseAccount", "receivableAccountId", "receivableAccount", "liabilityAccountId", "liabilityAccount", "phaseOrder", "customFields", "assignedGroups", "classId", "class", "id", "createdOn", "createdById", "lastUpdated", "lastUpdatedById", "version", "objectState", "token"}, {"Project.displayName", "Project.name", "Project.code", "Project.phaseName", "Project.type", "Project.rootProjectId", "Project.rootProject", "Project.level", "Project.contractType", "Project.status", "Project.hasChild", "Project.clientId", "Project.client", "Project.managerId", "Project.manager", "Project.feeScheduleId", "Project.feeScheduleName", "Project.contractAmount", "Project.startDate", "Project.dueDate", "Project.percentComplete", "Project.parentId", "Project.parent", "Project.principalId", "Project.principal", "Project.originatorId", "Project.originator", "Project.invoiceTemplateId", "Project.invoiceTemplate", "Project.manualInvoiceTemplateId", "Project.manualInvoiceTemplate", "Project.jointInvoiceTemplateId", "Project.jointInvoiceTemplate", "Project.memo", "Project.interestRate", "Project.graceDays", "Project.recurringFrequency", "Project.recurringAmount", "Project.mainServiceTax", "Project.mainExpenseTax", "Project.billingContactId", "Project.billingContact", "Project.phaseDescription", "Project.address", "Project.rules", "Project.purchaseOrderNumber", "Project.termId", "Project.term", "Project.currencyMultiplierId", "Project.currencyName", "Project.messageOnInvoice", "Project.hasCustomInvoiceNumber", "Project.invoicePrefix", "Project.invoiceNumber", "Project.invoiceSuffix", "Project.retainagePercent", "Project.retainageLimit", "Project.fixedFee", "Project.fixedFeePercentage", "Project.defaultGroupId", "Project.defaultGroup", "Project.incomeAccountId", "Project.incomeAccount", "Project.expenseAccountId", "Project.expenseAccount", "Project.receivableAccountId", "Project.receivableAccount", "Project.liabilityAccountId", "Project.liabilityAccount", "Project.phaseOrder", "Project.customFields", "Project.assignedGroups", "Project.classId", "Project.class", "Project.id", "Project.createdOn", "Project.createdById", "Project.lastUpdated", "Project.lastUpdatedById", "Project.version", "Project.objectState", "Project.token"})

 in 
 expandAll;

     
//Handles the paging and the custom filters
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
Label = "Core Login"
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
Beta = true,
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

