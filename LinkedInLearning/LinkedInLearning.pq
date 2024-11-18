[Version = "1.0.10"]
section LinkedInLearning;

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
get_token = (client_id, client_secret) => 
    let 
        authorization_key = "Basic " & Binary.ToText(Text.ToBinary(client_id & ":" & client_secret),0),
        response = Web.Contents("https://www.linkedin.com", [
            RelativePath = "oauth/v2/accessToken"
            ,Headers = [
                #"Authorization"=authorization_key
                ,#"Content-Type"="application/x-www-form-urlencoded;charset=UTF-8"
                ,Referer="urn:li:partner:li_power_bi"
                ]
            ,Content = Text.ToBinary("grant_type=client_credentials")]),
        json_response = Json.Document(response),
        token = json_response[access_token]
    in
        token;
get_total_pages_learning_assets = (token, relative_path, parameters) =>
    let
        response = try Json.Document(
            Web.Contents("https://api.linkedin.com", [
                RelativePath = relative_path,
                Query = parameters,
                Headers=[Authorization="Bearer " & token
                    , Referer="urn:li:partner:li_power_bi"
                    ]])) otherwise null,
        paging = try response[paging] otherwise null,
        total_pages = try paging[total] otherwise 0
    in 
        total_pages;
get_learning_urls = (parameters, count) =>
    let
        value1 = if Value.Is(count, type number) then Number.ToText(count) else count,
        add_parameter = Record.AddField(parameters, "start", value1)
    in
        add_parameter;
get_initial_table_learning_assets = (relative_path, parameters, end, country_language) =>
    let
        start = 0,
        diff = 100,
        number_list = List.Generate(() => start, each _ <= end, each _ +diff),
        number_table = Table.FromList(number_list, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        renamed_column = Table.RenameColumns(number_table,{{"Column1", "count"}}),
        result = Table.AddColumn(renamed_column, "country_language", each country_language),
        add_page_index = Table.AddColumn(result, "parameters", each get_learning_urls(parameters,[count]))
    in
        add_page_index;
get_page_data = (token, relative_path, parameters) =>
    let
        response = try Json.Document(
            Web.Contents("https://api.linkedin.com", [
                RelativePath = relative_path,
                Query = parameters,
                Headers=[Authorization="Bearer " & token
                    , Referer="urn:li:partner:li_power_bi"
                    ]])) otherwise null
    in
        response;
get_learning_assets = (client_id, client_secret) =>
    let 
        token = get_token(client_id, client_secret),
        de_p = [q="localeAndType", assetType="COURSE",sourceLocale.language="de",sourceLocale.country="DE",count="100",includeRetired="false"],
        en_p = [q="localeAndType", assetType="COURSE",sourceLocale.language="en",sourceLocale.country="US",count="100",includeRetired="false"],
        es_p = [q="localeAndType", assetType="COURSE",sourceLocale.language="es",sourceLocale.country="ES",count="100",includeRetired="false"],
        fr_p = [q="localeAndType", assetType="COURSE",sourceLocale.language="fr",sourceLocale.country="FR",count="100",includeRetired="false"],
        id_p = [q="localeAndType", assetType="COURSE",sourceLocale.language="id",sourceLocale.country="ID",count="100",includeRetired="false"],
        it_p = [q="localeAndType", assetType="COURSE",sourceLocale.language="it",sourceLocale.country="IT",count="100",includeRetired="false"],
        jp_p = [q="localeAndType", assetType="COURSE",sourceLocale.language="ja",sourceLocale.country="JP",count="100",includeRetired="false"],
        ko_p = [q="localeAndType", assetType="COURSE",sourceLocale.language="ko",sourceLocale.country="KR",count="100",includeRetired="false"],
        pl_p = [q="localeAndType", assetType="COURSE",sourceLocale.language="pl",sourceLocale.country="PL",count="100",includeRetired="false"],
        pt_p = [q="localeAndType", assetType="COURSE",sourceLocale.language="pt",sourceLocale.country="BR",count="100",includeRetired="false"],
        tr_p = [q="localeAndType", assetType="COURSE",sourceLocale.language="tr",sourceLocale.country="TR",count="100",includeRetired="false"],
        zh_p = [q="localeAndType", assetType="COURSE",sourceLocale.language="zh",sourceLocale.country="CN",count="100",includeRetired="false"],
        total_de = get_total_pages_learning_assets(token,"v2/learningAssets",de_p),
        total_en = get_total_pages_learning_assets(token,"v2/learningAssets",en_p),
        total_es = get_total_pages_learning_assets(token,"v2/learningAssets",es_p),
        total_fr = get_total_pages_learning_assets(token,"v2/learningAssets",fr_p),
        total_id = get_total_pages_learning_assets(token,"v2/learningAssets",id_p), 
        total_it = get_total_pages_learning_assets(token,"v2/learningAssets",it_p),
        total_jp = get_total_pages_learning_assets(token,"v2/learningAssets",jp_p),
        total_ko = get_total_pages_learning_assets(token,"v2/learningAssets",ko_p),
        total_pl = get_total_pages_learning_assets(token,"v2/learningAssets",pl_p),
        total_pt = get_total_pages_learning_assets(token,"v2/learningAssets",pt_p),
        total_tr = get_total_pages_learning_assets(token,"v2/learningAssets",tr_p),
        total_zh = get_total_pages_learning_assets(token,"v2/learningAssets",zh_p),
        pages_de = get_initial_table_learning_assets("v2/learningAssets",de_p,total_de,"de"),
        pages_en = get_initial_table_learning_assets("v2/learningAssets",en_p,total_en,"en"),
        pages_es = get_initial_table_learning_assets("v2/learningAssets",es_p,total_es,"es"),
        pages_fr = get_initial_table_learning_assets("v2/learningAssets",fr_p,total_fr,"fr"),
        pages_id = get_initial_table_learning_assets("v2/learningAssets",id_p,total_id,"id"),
        pages_it = get_initial_table_learning_assets("v2/learningAssets",it_p,total_it,"it"),
        pages_jp = get_initial_table_learning_assets("v2/learningAssets",jp_p,total_jp,"jp"),
        pages_ko = get_initial_table_learning_assets("v2/learningAssets",ko_p,total_ko,"ko"),
        pages_pl = get_initial_table_learning_assets("v2/learningAssets",pl_p,total_pl,"pl"),
        pages_pt = get_initial_table_learning_assets("v2/learningAssets",pt_p,total_pt,"pt"),
        pages_tr = get_initial_table_learning_assets("v2/learningAssets",tr_p,total_tr,"tr"),
        pages_zh = get_initial_table_learning_assets("v2/learningAssets",zh_p,total_zh,"zh"),
        all_api_calls = Table.Combine({pages_de,pages_en,pages_es,pages_fr,pages_id,pages_it,pages_jp,pages_ko,pages_pl,pages_pt,pages_tr,pages_zh}),
        add_page_data = Table.AddColumn(all_api_calls, "page_data", each get_page_data(token,"v2/learningAssets",[parameters])),
        t1 = Table.ExpandRecordColumn(add_page_data, "page_data", {"paging", "elements"}, {"page_data.paging", "page_data.elements"}),
        t2 = Table.ExpandListColumn(t1, "page_data.elements"),
        t3 = Table.ExpandRecordColumn(t2, "page_data.elements", {"urn", "details", "title", "type", "contents"}, {"urn", "details", "title", "type", "contents"}),
        t4 = Table.ExpandRecordColumn(t3, "title", {"value"}, {"title.value"}),
        t5 = Table.ExpandRecordColumn(t4, "details", {"images", "descriptionIncludingHtml", "lastUpdatedAt", "publishedAt", "level", "discoverableBy", "description", "shortDescription", "availability", "availableLocales", "relationships", "classifications", "urls", "shortDescriptionIncludingHtml", "contributors", "timeToComplete"}, {"images", "descriptionIncludingHtml", "lastUpdatedAt", "publishedAt", "level", "discoverableBy", "description", "shortDescription", "availability", "availableLocales", "relationships", "classifications", "urls", "shortDescriptionIncludingHtml", "contributors", "timeToComplete"}),
        t6 = Table.ExpandRecordColumn(t5, "images", {"primary"}, {"images.primary"}),
        t7 = Table.ExpandRecordColumn(t6, "description", {"value"}, {"description.value"}),
        t8 = Table.ExpandRecordColumn(t7, "shortDescription", {"value"}, {"shortDescription.value"}),
        t9 = Table.ExpandListColumn(t8, "classifications"),
        t10 = Table.ExpandRecordColumn(t9, "classifications", {"associatedClassification"}, {"associatedClassification"}),
        t11 = Table.ExpandRecordColumn(t10, "associatedClassification", {"name", "type"}, {"associatedClassification.name", "associatedClassification.type"}),
        t12 = Table.ExpandRecordColumn(t11, "associatedClassification.name", {"value"}, {"associatedClassification.name.value"}),
        t13 = Table.ExpandRecordColumn(t12, "urls", {"webLaunch", "aiccLaunch", "ssoLaunch"}, {"urls.webLaunch", "urls.aiccLaunch", "urls.ssoLaunch"}),
        t14 = Table.ExpandRecordColumn(t13, "timeToComplete", {"duration", "unit"}, {"timeToComplete.duration", "timeToComplete.unit"}),
        add_dt = if Table.HasColumns(t14, "lastUpdatedAt") then Table.AddColumn(t14, "lastUpdatedAtDT", each try #datetime(1970,1,1,0,0,0)+#duration(0,0,0,[lastUpdatedAt]/1000) otherwise null) else t14,
        add_dt1 = if Table.HasColumns(add_dt, "publishedAt") then Table.AddColumn(add_dt, "publishedAtDT", each try #datetime(1970,1,1,0,0,0)+#duration(0,0,0,[publishedAt]/1000) otherwise null) else add_dt
    in
        add_dt1;
get_total_pages_reports = (token as text, initial_epoch as text, relative_path as text, parameters) =>
    let
        p_w_start = Record.AddField(parameters, "startedAt", initial_epoch & "000"),
        response = try Json.Document(
            Web.Contents("https://api.linkedin.com", [
                RelativePath = relative_path,
                Query = p_w_start,
                Headers=[Authorization="Bearer " & token
                    ,Referer="urn:li:partner:li_power_bi"
                    ]])) otherwise null,
        paging = try response[paging] otherwise null,
        total_pages = try paging[total] otherwise 0
    in 
        total_pages;
make_number_list = (start as number, end as number) =>
    let
        counter = 1000
        ,num_list = List.Generate(() => start, each _ < end, each _ +counter)
    in
        num_list;
get_initial_table = (token as text, start_date as datetime, end_date as datetime, relative_path as text, parameters) =>
    let 
        /*calculate 2 week intervals using epoch starting from start date*/
        start_epoch = Int32.From(Duration.TotalSeconds(start_date - #datetime(1970,1,1,0,0,0))),
        end_epoch0 = Int32.From(Duration.TotalSeconds(Date.AddWeeks(end_date,-1) - #datetime(1970,1,1,0,0,0))),
        end_epoch1 = Int32.From(Duration.TotalSeconds(end_date - #datetime(1970,1,1,0,0,0))), //Int32.From(Duration.TotalSeconds(DateTime.From(DateTimeZone.UtcNow()) - #datetime(1970,1,1,0,0,0))),
        diff = (end_epoch1 - end_epoch0) * 2,
        /*make it into a list from start date to current date*/
        epoch_list = List.Generate(() => start_epoch, each _ <= end_epoch0, each _ +diff),
        epoch_table = Table.FromList(epoch_list, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        renamed_column = Table.RenameColumns(epoch_table,{{"Column1", "epoch_week"}}),
        add_column = Table.AddColumn(renamed_column, "week", each #datetime(1970,1,1,0,0,0)+#duration(0,0,0,[epoch_week])),
        change_type = Table.TransformColumnTypes(add_column,{{"epoch_week", type text}}),
        /*get the total pages per API call and add it to the list*/
        add_column1 = Table.AddColumn(change_type,"parameters", each parameters),
        add_column2 = Table.AddColumn(add_column1,"total_pages_week", each get_total_pages_reports(token, [epoch_week], relative_path, [parameters])),
        add_column3 = Table.TransformColumnTypes(add_column2,{{"total_pages_week", type number}}),
        /*add one row for every page in the API in increments of 1000*/
        add_page_index = Table.AddColumn(add_column2, "page_index", each make_number_list(0, [total_pages_week])),
        initial_table = Table.ExpandListColumn(add_page_index, "page_index")
    in 
        initial_table;
get_single_url = (epoch_week, page_index, parameters) =>
    let
        epoch_week_txt = if Value.Is(epoch_week, type number) then Number.ToText(epoch_week) & "000" else epoch_week & "000",
        page_index_txt = if Value.Is(page_index, type number) then Number.ToText(page_index) else page_index,
        p_w_count = Record.AddField(parameters, "count", "1000"), 
        p_w_startedAt = Record.AddField(p_w_count, "startedAt", epoch_week_txt), 
        p_w_start = Record.AddField(p_w_startedAt, "start", page_index_txt)
    in
        p_w_start;
get_data = (start_date as datetime, end_date as datetime, client_id, client_secret, parameters, report_name as text) =>
    let
        token = get_token(client_id, client_secret),
        initial_table = get_initial_table(token, start_date, end_date, "v2/learningActivityReports", parameters),
        add_start = Table.AddColumn(initial_table,"param_w_start", each(get_single_url([epoch_week],[page_index],[parameters]))),
        page_data = Table.AddColumn(add_start,"page_data", each(get_page_data(token, "v2/learningActivityReports", [param_w_start])))
    in
        page_data;
filter_account_popular_courses_report = (data) =>
    let
        t1 = Table.ExpandRecordColumn(data, "page_data", {"paging", "elements"}, {"page_data.paging", "page_data.elements"}),
        t2 = Table.ExpandListColumn(t1, "page_data.elements"),
        t3 = Table.ExpandRecordColumn(t2, "page_data.elements", {"latestDataAt", "learnerDetails", "activities", "contentDetails"}, {"latestDataAt", "learnerDetails", "activities", "contentDetails"}),
        t4 = Table.ExpandListColumn(t3, "activities"),
        t5 = Table.ExpandRecordColumn(t4, "activities", {"engagementType", "assetType", "engagementMetricQualifier", "engagementValue"}, {"engagementType", "assetType", "engagementMetricQualifier", "engagementValue"}),
        t6 = Table.ExpandRecordColumn(t5, "contentDetails", {"contentProviderName", "name", "contentUrn", "locale"}, {"contentProviderName", "contentDetails.name", "contentUrn", "locale"}),
        t7 = Table.ExpandRecordColumn(t6, "locale", {"country", "language"}, {"country", "language"}),
        t8 = Table.ExpandRecordColumn(t7, "learnerDetails", {"entity"}, {"entity"}),
        t9 = Table.ExpandRecordColumn(t8, "entity", {"accountUrn"}, {"accountUrn"})
    in
        t9;
filter_account_popular_custom_content_report = (data) =>
    let
        t1 = Table.ExpandRecordColumn(data, "page_data", {"paging", "elements"}, {"page_data.paging", "page_data.elements"}),
        t2 = Table.ExpandListColumn(t1, "page_data.elements"),
        t3 = Table.ExpandRecordColumn(t2, "page_data.elements", {"latestDataAt", "learnerDetails", "activities", "contentDetails"}, {"latestDataAt", "learnerDetails", "activities", "contentDetails"}),
        t4 = Table.ExpandListColumn(t3, "activities"),
        t5 = Table.ExpandRecordColumn(t4, "activities", {"engagementType", "assetType", "engagementMetricQualifier", "engagementValue"}, {"engagementType", "assetType", "engagementMetricQualifier", "engagementValue"}),
        t6 = Table.ExpandRecordColumn(t5, "contentDetails", {"contentProviderName", "name", "contentUrn", "locale"}, {"contentProviderName", "contentDetails.name", "contentUrn", "locale"}),
        t7 = Table.ExpandRecordColumn(t6, "locale", {"country", "language"}, {"country", "language"}),
        t8 = Table.ExpandRecordColumn(t7, "learnerDetails", {"entity"}, {"entity"}),
        t9 = Table.ExpandRecordColumn(t8, "entity", {"accountUrn"}, {"accountUrn"})
    in
        t9;
filter_account_total_activity_summary_report = (data) =>
    let
        t1 = Table.ExpandRecordColumn(data, "page_data", {"paging", "elements"}, {"page_data.paging", "page_data.elements"}),
        t2 = Table.ExpandListColumn(t1, "page_data.elements"),
        t3 = Table.ExpandRecordColumn(t2, "page_data.elements", {"latestDataAt", "learnerDetails", "activities"}, {"latestDataAt", "learnerDetails", "activities"}),
        t4 = Table.ExpandRecordColumn(t3, "learnerDetails", {"entity"}, {"entity"}),
        t5 = Table.ExpandRecordColumn(t4, "entity", {"accountUrn"}, {"accountUrn"}),
        t6 = Table.ExpandListColumn(t5, "activities"),
        t7 = Table.ExpandRecordColumn(t6, "activities", {"engagementType", "lastEngagedAt", "firstEngagedAt", "engagementMetricQualifier", "engagementValue"}, {"engagementType", "lastEngagedAt", "firstEngagedAt", "engagementMetricQualifier", "engagementValue"})
    in
        t7;
filter_content_summary_report = (data) =>
    let 
        t1 = Table.ExpandRecordColumn(data, "page_data", {"paging", "elements"}, {"page_data.paging", "page_data.elements"}),
        t2 = Table.ExpandListColumn(t1, "page_data.elements"),
        t3 = Table.ExpandRecordColumn(t2, "page_data.elements", {"latestDataAt", "learnerDetails", "activities", "contentDetails"}, {"latestDataAt", "learnerDetails", "activities", "contentDetails"}),
        t4 = Table.ExpandRecordColumn(t3, "learnerDetails", {"entity"}, {"entity"}),
        t5 = Table.ExpandRecordColumn(t4, "entity", {"accountUrn"}, {"accountUrn"}),
        t6 = Table.ExpandListColumn(t5, "activities"),
        t7 = Table.ExpandRecordColumn(t6, "activities", {"engagementType", "assetType", "engagementMetricQualifier", "engagementValue"}, {"engagementType", "assetType", "engagementMetricQualifier", "engagementValue"}),
        t8 = Table.ExpandRecordColumn(t7, "contentDetails", {"contentProviderName", "name", "contentUrn", "locale"}, {"contentProviderName", "contentDetails.name", "contentUrn", "locale"}),
        t9 = Table.ExpandRecordColumn(t8, "locale", {"country", "language"}, {"country", "language"})
    in 
        t9;
filter_learner_activity_summary_report = (data) =>
    let 
        t1 = Table.ExpandRecordColumn(data, "page_data", {"paging", "elements"}, {"page_data.paging", "page_data.elements"}),
        t2 = Table.ExpandListColumn(t1, "page_data.elements"),
        t3 = Table.ExpandRecordColumn(t2, "page_data.elements", {"latestDataAt", "learnerDetails", "activities"}, {"latestDataAt", "learnerDetails", "activities"}),
        t4 = Table.ExpandRecordColumn(t3, "learnerDetails", {"name", "enterpriseGroups", "entity", "email", "customAttributes", "uniqueUserId"}, {"name", "enterpriseGroups", "entity", "email", "customAttributes", "uniqueUserId"}),
        t5 = Table.ExpandRecordColumn(t4, "entity", {"profileUrn"}, {"profileUrn"}),
        t6 = Table.ExpandListColumn(t5, "activities"),
        t7 = Table.ExpandRecordColumn(t6, "activities", {"engagementType", "engagementMetricQualifier", "engagementValue", "assetType"}, {"engagementType", "engagementMetricQualifier", "engagementValue", "assetType"})
    in
        t7;
filter_learner_course_activity_detail_report = (data) =>
    let
        t1 = Table.ExpandRecordColumn(data, "page_data", {"paging", "elements"}, {"paging", "elements"}),
        t2 = Table.ExpandListColumn(t1, "elements"),
        t3 = Table.ExpandRecordColumn(t2, "elements", {"latestDataAt", "learnerDetails", "activities", "contentDetails"}, {"latestDataAt", "learnerDetails", "activities", "contentDetails"}),
        t4 = Table.ExpandRecordColumn(t3, "learnerDetails", {"name", "enterpriseGroups", "entity", "email", "customAttributes", "uniqueUserId"}, {"learnerDetails.name", "learnerDetails.enterpriseGroups", "learnerDetails.entity", "learnerDetails.email", "learnerDetails.customAttributes", "learnerDetails.uniqueUserId"}),
        t5 = Table.ExpandRecordColumn(t4, "learnerDetails.entity", {"profileUrn"}, {"learnerDetails.entity.profileUrn"}),
        t6 = Table.ExpandListColumn(t5, "activities"),
        t7 = Table.ExpandRecordColumn(t6, "activities", {"engagementType", "lastEngagedAt", "firstEngagedAt", "assetType", "engagementMetricQualifier", "engagementValue"}, {"engagementType", "lastEngagedAt", "firstEngagedAt", "assetType", "engagementMetricQualifier", "engagementValue"}),
        t8 = Table.ExpandRecordColumn(t7, "contentDetails", {"contentProviderName", "name", "contentUrn", "locale"}, {"contentProviderName", "name", "contentUrn", "locale"}),
        t9 = Table.ExpandRecordColumn(t8, "locale", {"country", "language"}, {"country", "language"})
    in
        t9;
filter_learner_custom_content_activity_detail_report = (data) =>
    let
        t1= Table.ExpandRecordColumn(data, "page_data", {"paging", "elements"}, {"paging", "elements"}),
        t2 = Table.ExpandListColumn(t1, "elements"),
        t3 = Table.ExpandRecordColumn(t2, "elements", {"latestDataAt", "learnerDetails", "activities", "contentDetails"}, {"latestDataAt", "learnerDetails", "activities", "contentDetails"}),
        t4 = Table.ExpandRecordColumn(t3, "contentDetails", {"contentProviderName", "name", "contentUrn", "locale"}, {"contentProviderName", "name", "contentUrn", "locale"}),
        t5 = Table.ExpandRecordColumn(t4, "locale", {"country", "language"}, {"country", "language"})
    in
        t5;
filter_organization_summary_report = (data) =>
    let 
        t1 = Table.ExpandRecordColumn(data, "page_data", {"paging", "elements"}, {"paging", "elements"}),
        t2 = Table.ExpandListColumn(t1, "elements"),
        t3 = Table.ExpandRecordColumn(t2, "elements", {"latestDataAt", "learnerDetails", "activities"}, {"latestDataAt", "learnerDetails", "activities"}),
        t4 = Table.ExpandRecordColumn(t3, "learnerDetails", {"entity"}, {"entity"}),
        t5 = Table.ExpandRecordColumn(t4, "entity", {"accountUrn"}, {"accountUrn"}),
        t6 = Table.ExpandListColumn(t5, "activities"),
        t7 = Table.ExpandRecordColumn(t6, "activities", {"engagementType", "lastEngagedAt", "firstEngagedAt", "engagementMetricQualifier", "engagementValue"}, {"engagementType", "lastEngagedAt", "firstEngagedAt", "engagementMetricQualifier", "engagementValue"})
    in
        t7;
filter_learner_summary_report = (data) => 
    let
        t1 = Table.ExpandRecordColumn(data, "page_data", {"paging", "elements"}, {"page_data.paging", "page_data.elements"}),
        t2 = Table.ExpandListColumn(t1, "page_data.elements"),
        t3 = Table.ExpandRecordColumn(t2, "page_data.elements", {"latestDataAt", "learnerDetails", "activities"}, {"latestDataAt", "learnerDetails", "activities"}),
        t4 = Table.ExpandRecordColumn(t3, "learnerDetails", {"name", "enterpriseGroups", "entity", "email", "customAttributes", "uniqueUserId"}, {"name", "enterpriseGroups", "entity", "email", "customAttributes", "uniqueUserId"}),
        t5 = Table.ExpandRecordColumn(t4, "entity", {"profileUrn"}, {"profileUrn"}),
        t6 = Table.ExpandListColumn(t5, "activities"),
        t7 = Table.ExpandRecordColumn(t6, "activities", {"engagementType", "engagementMetricQualifier", "engagementValue", "assetType"}, {"engagementType", "engagementMetricQualifier", "engagementValue", "assetType"})
    in 
        t7;
filter_learner_detail_report = (data) =>
    let
        t1 = Table.ExpandRecordColumn(data, "page_data", {"paging", "elements"}, {"paging", "elements"}),
        t2 = Table.ExpandListColumn(t1, "elements"),
        t3 = Table.ExpandRecordColumn(t2, "elements", {"latestDataAt", "learnerDetails", "activities", "contentDetails"}, {"latestDataAt", "learnerDetails", "activities", "contentDetails"}),
        t4 = Table.ExpandRecordColumn(t3, "learnerDetails", {"name", "enterpriseGroups", "entity", "email", "customAttributes", "uniqueUserId"}, {"name", "enterpriseGroups", "entity", "email", "customAttributes", "uniqueUserId"}),
        t5 = Table.ExpandRecordColumn(t4, "entity", {"profileUrn"}, {"profileUrn"}),
        t6 = Table.ExpandListColumn(t5, "activities"),
        t7 = Table.ExpandRecordColumn(t6, "activities", {"engagementType", "lastEngagedAt", "firstEngagedAt", "assetType", "engagementMetricQualifier", "engagementValue"}, {"engagementType", "lastEngagedAt", "firstEngagedAt", "assetType", "engagementMetricQualifier", "engagementValue"}),
        t8 = Table.ExpandRecordColumn(t7, "contentDetails", {"contentProviderName", "name", "contentUrn", "locale"}, {"contentProviderName", "name.1", "contentUrn", "locale"}),
        t9 = Table.ExpandRecordColumn(t8, "locale", {"language", "country"}, {"language", "country"}),
        t10 = Table.RenameColumns(t9,{{"name.1", "contentName"}})
    in
        t10;
filter_reports = (data, report_name) =>
    let
        result = if report_name = "Organization Summary Report" then filter_organization_summary_report(data) else
                    if report_name = "Learner Summary Report" then filter_learner_summary_report(data) else        
                        if report_name = "Learner Detail Report" then filter_learner_detail_report(data) else
                            if report_name = "Learner Detail Report Video" then filter_learner_detail_report(data) else
                                if report_name = "Content Summary Report" then filter_content_summary_report(data) else
                                    if report_name = "Account Popular Courses Report" then filter_account_popular_courses_report(data) else
                                        if report_name = "Learner Activity Summary Report" then filter_learner_activity_summary_report(data) else
                                            if report_name = "Learner Course Activity Detail Report" then filter_learner_course_activity_detail_report(data) else
                                                if report_name = "Account Total Activity Summary Report" then filter_account_total_activity_summary_report(data) else
                                                    if report_name = "Learner Custom Content Activity Detail Report" then filter_learner_custom_content_activity_detail_report(data) else
                                                        if report_name = "Account Popular Custom Content Report" then filter_account_popular_custom_content_report(data) else [],
        add_dt = if Table.HasColumns(result, "latestDataAt") then Table.AddColumn(result, "latestDataAtDT", each try #datetime(1970,1,1,0,0,0)+#duration(0,0,0,[latestDataAt]/1000) otherwise null) else result,
        add_dt1 = if Table.HasColumns(add_dt, "lastEngagedAt") then Table.AddColumn(add_dt, "lastEngagedAtDT", each try #datetime(1970,1,1,0,0,0)+#duration(0,0,0,[lastEngagedAt]/1000) otherwise null) else add_dt,
        add_dt2 = if Table.HasColumns(add_dt1, "firstEngagedAt") then Table.AddColumn(add_dt1, "firstEngagedAtDT", each try #datetime(1970,1,1,0,0,0)+#duration(0,0,0,[firstEngagedAt]/1000) otherwise null) else add_dt1
    in
        add_dt2;
get_report = (start_date as datetime, end_date as datetime, client_id, client_secret, report_name as text) =>
    let
        params = if report_name = "Organization Summary Report" then [q="criteria", timeOffset.unit="DAY", timeOffset.duration="14", aggregationCriteria.primary="ACCOUNT"] else
                    if report_name = "Learner Summary Report" then [q="criteria", timeOffset.unit="DAY", timeOffset.duration="14", aggregationCriteria.primary="INDIVIDUAL", sortBy.engagementMetricType="DAYS_ACTIVE", contentSource="LINKEDIN_LEARNING"] else        
                        if report_name = "Learner Detail Report" then [aggregationCriteria.primary="INDIVIDUAL", aggregationCriteria.secondary="CONTENT", q="criteria", contentSource="ALL_SOURCES", assetType="COURSE", timeOffset.duration="14", timeOffset.unit="DAY"] else
                            if report_name = "Learner Detail Report Video" then [aggregationCriteria.primary="INDIVIDUAL", aggregationCriteria.secondary="CONTENT", q="criteria", contentSource="ALL_SOURCES", assetType="VIDEO", timeOffset.duration="14", timeOffset.unit="DAY"] else
                                if report_name = "Content Summary Report" then [aggregationCriteria.primary="CONTENT", q="criteria", contentSource="ORGANIZATION", timeOffset.unit="DAY", timeOffset.duration="14", sortBy.engagementMetricType="COMPLETIONS"] else
                                    if report_name = "Account Popular Courses Report" then [q="criteria", contentSource="EXTERNAL", timeOffset.unit="DAY", aggregationCriteria.primary="CONTENT", assetType="COURSE", sortBy.engagementMetricQualifier="TOTAL", timeOffset.duration="14", sortBy.engagementMetricType="SECONDS_VIEWED"] else
                                        if report_name = "Learner Activity Summary Report" then [q="criteria", timeOffset.duration="14", aggregationCriteria.primary="INDIVIDUAL", timeOffset.unit="DAY", sortBy.engagementMetricType="DAYS_ACTIVE"] else
                                            if report_name = "Learner Course Activity Detail Report" then [aggregationCriteria.primary="INDIVIDUAL", aggregationCriteria.secondary="CONTENT", q="criteria", contentSource="EXTERNAL", assetType="COURSE", timeOffset.duration="14", timeOffset.unit="DAY"] else
                                                if report_name = "Account Total Activity Summary Report" then [q="criteria", timeOffset.unit="DAY", timeOffset.duration="14", aggregationCriteria.primary="ACCOUNT"] else
                                                    if report_name = "Learner Custom Content Activity Detail Report" then [aggregationCriteria.secondary="CONTENT", q="criteria", contentSource="INTERNAL", timeOffset.unit="DAY", timeOffset.duration="14", aggregationCriteria.primary="INDIVIDUAL", sortBy.engagementMetricType="MARKED_AS_DONE"] else
                                                        if report_name = "Account Popular Custom Content Report" then [aggregationCriteria.primary="CONTENT", q="criteria", contentSource="INTERNAL", timeOffset.unit="DAY", timeOffset.duration="14", sortBy.engagementMetricType="COMPLETIONS"] else [],
        data = get_data(start_date, end_date, client_id, client_secret, params, report_name), 
        result = filter_reports(data, report_name)
    in
        result;
[DataSource.Kind="LinkedInLearning", Publish="LinkedInLearning.Publish"]
shared LinkedInLearning.Contents = (optional start_date as datetime, optional end_date as datetime/*, optional client_id, optional client_secret*/) =>
    let
        sd = if Value.Is(start_date, type datetime) then start_date else Date.AddYears(DateTime.From(DateTimeZone.UtcNow()),-1),
        ed = if Value.Is(end_date, type datetime) then end_date else DateTime.From(DateTimeZone.UtcNow()),
        credentials = Extension.CurrentCredential(),
        ci = /*if client_id = null then*/ credentials[Username] /*else client_id*/, 
        cs = /*if client_secret = null then*/ credentials[Password] /*else client_secret*/,
        objects = #table(
                    {"Name","Key","Data","ItemKind","ItemName","IsLeaf"}
                        ,{
                            {"Organization Summary Report","Organization Summary Report",get_report(sd, ed, ci, cs, "Organization Summary Report"),"Table","Table",true},
                            {"Learner Summary Report","Learner Summary Report",get_report(sd, ed, ci, cs, "Learner Summary Report"),"Table","Table",true},
                            {"Learner Detail Report","Learner Detail Report",get_report(sd, ed, ci, cs, "Learner Detail Report"),"Table","Table",true},
                            {"Learner Detail Report Video","Learner Detail Report Video",get_report(sd, ed, ci, cs, "Learner Detail Report Video"),"Table","Table",true},
                            {"Content Summary Report","Content Summary Report",get_report(sd, ed, ci, cs, "Content Summary Report"),"Table","Table",true},
                            {"Account Popular Courses Report","Account Popular Courses Report",get_report(sd, ed, ci, cs,"Account Popular Courses Report"),"Table","Table",true},
                            {"Learner Activity Summary Report","Learner Activity Summary Report",get_report(sd, ed, ci, cs,"Learner Activity Summary Report"),"Table","Table",true},
                            {"Learner Course Activity Detail Report","Learner Course Activity Detail Report",get_report(sd, ed, ci, cs,"Learner Course Activity Detail Report"),"Table","Table",true},
                            {"Account Total Activity Summary Report","Account Total Activity Summary Report",get_report(sd, ed, ci, cs,"Account Total Activity Summary Report"),"Table","Table",true},
                            {"Learner Custom Content Activity Detail Report","Learner Custom Content Activity Detail Report",get_report(sd, ed, ci, cs,"Learner Custom Content Activity Detail Report"),"Table","Table",true},
                            {"Account Popular Custom Content Report","Account Popular Custom Content Report",get_report(sd, ed, ci, cs,"Account Popular Custom Content Report"),"Table","Table",true},
                            {"Learning Assets","Learning Assets",/*get_total_pages_learning_assets(token,"v2/learningAssets",en_p)*/ get_learning_assets(ci, cs),"Table","Table",true}               
                        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in 
        NavTable; 

// Data Source Kind description
LinkedInLearning = [
    TestConnection = (dataSourcePath) => { "LinkedInLearning.Contents" },
    Authentication = [
        // Key = [],
        UsernamePassword = [ UsernameLabel = "Client ID", PasswordLabel = "Client Secret", Label = "LinkedIn Learning"]
        // Windows = [],
        //Anonymous = []
    ], Label = "LinkedIn Learning"
];

// Data Source UI publishing description
LinkedInLearning.Publish = [
    Category = "Online Services",
    ButtonText = { "LinkedIn Learning", "LinkedIn Learning" },
    LearnMoreUrl = "https://www.linkedin.com/",
    SourceImage = LinkedInLearning.Icons,
    SourceTypeImage = LinkedInLearning.Icons
];

LinkedInLearning.Icons = [
    Icon16 = { Extension.Contents("LinkedInLearning16.png"), Extension.Contents("LinkedInLearning20.png"), Extension.Contents("LinkedInLearning24.png"), Extension.Contents("LinkedInLearning32.png") },
    Icon32 = { Extension.Contents("LinkedInLearning32.png"), Extension.Contents("LinkedInLearning40.png"), Extension.Contents("LinkedInLearning48.png"), Extension.Contents("LinkedInLearning64.png") }
];
