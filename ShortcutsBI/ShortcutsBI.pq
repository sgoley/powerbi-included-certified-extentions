[Version = "1.0.0"]
section ShortcutsBI;

//Helper function to load external files
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

//External functions
navigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");
randomStringGenerator = Extension.LoadFunction("Function.RandomStringGenerator.pqm");
timestampGenerator = Extension.LoadFunction("Function.TimestampGenerator.pqm");
oauthSignatureGenerator = Extension.LoadFunction("Function.OAuthSignatureGenerator.pqm");
getAccessCode = Extension.LoadFunction("Function.GetAccessCode.pqm");
extractCommunityID = Extension.LoadFunction("Function.ExtractCommunityID.pqm");
getData = Extension.LoadFunction("Function.GetData.pqm");

//Maximum amount of records to return for each API call
maxRows = "80000";

[DataSource.Kind="ShortcutsBI", Publish="ShortcutsBI.Publish"]
shared ShortcutsBI.Contents = ShortcutsBIImpl;

//Connector implementation
ShortcutsBIImpl = () as table =>
    let
        powerBiKey = Extension.CurrentCredential()[Key],
        delimeterCount = List.Count(Text.Split(powerBiKey,"-")),
        powerBiKeySplit = if delimeterCount > 0 then Text.Split(powerBiKey, "-") else powerBiKey,
        consumerKey = if List.Count(powerBiKeySplit) < 1 then "" else powerBiKeySplit{0},
        consumerSecret = if List.Count(powerBiKeySplit) < 2 then "" else powerBiKeySplit{1},
        accessToken = if List.Count(powerBiKeySplit) < 3 then "" else powerBiKeySplit{2},
        accessTokenSecret = if List.Count(powerBiKeySplit) < 4 then "" else powerBiKeySplit{3},

        //Generate timestamp which is used in oauth1 signature generation
        oauthTimestamp = timestampGenerator(),
        //Generate random letter/number combination which is used in oauth1 signature generation
        oauthNonce = randomStringGenerator(),
        //Oauth1 signature generator which gets used when calling the authenticate endpoint
        oauthSignature = oauthSignatureGenerator(consumerKey, consumerSecret, accessToken, accessTokenSecret, oauthNonce, oauthTimestamp),
        //Function to call the authenticate endpoint providing it with oauth1 credentials, which will return a oauth2 jwt access code
        access_code = getAccessCode(consumerKey, consumerSecret, accessToken, accessTokenSecret, oauthNonce, oauthTimestamp, oauthSignature),
        //CommunityID extracted from JWT
        communityID = extractCommunityID(access_code),

        //Get data from API using the community ID, looping through the max rows until all rows have been retrieved
        appointments = getData(access_code, communityID, maxRows, "getSiteAppointments"),
        clients = getData(access_code, communityID, maxRows, "getSiteClients"),
        employeeLevels = getData(access_code, communityID, maxRows, "getSiteEmployeeLevels"),
        employees = getData(access_code, communityID, maxRows, "getSiteEmployees"),
        occupations = getData(access_code, communityID, maxRows, "getSiteOccupations"),
        pricebooks = getData(access_code, communityID, maxRows, "getSitePriceBooks"),
        products = getData(access_code, communityID, maxRows, "getSiteProducts"),
        referralMethods = getData(access_code, communityID, maxRows, "getSiteReferralMethods"),
        rosterActivity = getData(access_code, communityID, maxRows, "getSiteRosterActivity"),
        rosters = getData(access_code, communityID, maxRows, "getSiteRosters"),
        services = getData(access_code, communityID, maxRows, "getSiteServices"),
        sites = getData(access_code, communityID, maxRows, "getSites"),
        transactions = getData(access_code, communityID, maxRows, "getSiteTransactions"),

        //Navigation table for data tables
        objects  = #table(
                {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},{
                {"CommunityID", "item1", communityID, "Record", "Record", true},
                {"Appointments", "item2", appointments, "Table", "Table", true},
                {"Clients", "item3", clients, "Table", "Table", true},
                {"EmployeeLevels", "item4", employeeLevels, "Table", "Table", true},
                {"Employees", "item5", employees, "Table", "Table", true},
                {"Occupations", "item6", occupations, "Table", "Table", true},
                {"PriceBooks", "item7", pricebooks, "Table", "Table", true},
                {"Products", "item8", products, "Table", "Table", true},
                {"ReferralMethods", "item9", referralMethods, "Table", "Table", true},
                {"RosterActivity", "item10", rosterActivity, "Table", "Table", true},
                {"Rosters", "item11", rosters, "Table", "Table", true},
                {"Services", "item12", services, "Table", "Table", true},
                {"Sites", "item13", sites, "Table", "Table", true},
                {"Transactions", "item14", transactions, "Table", "Table", true}
                }),
        tables = navigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        tables;

// Data Source Kind description
ShortcutsBI = [
    TestConnection = (dataSourcePath) => { "ShortcutsBI.Contents" },
    Authentication = [
        Key = [Label = Extension.LoadString("ConnectionKey")]
    ],
    Label =  Extension.LoadString("ButtonHelp")
];

// Data Source UI publishing description
ShortcutsBI.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    SourceImage = ShortcutsBI.Icons,
    SourceTypeImage = ShortcutsBI.Icons
];

// Icon images to be used
ShortcutsBI.Icons = [
    Icon16 = { Extension.Contents("ShortcutsLogo16x16.png"), Extension.Contents("ShortcutsLogo20x20.png"), Extension.Contents("ShortcutsLogo24x24.png"), Extension.Contents("ShortcutsLogo32x32.png") },
    Icon32 = { Extension.Contents("ShortcutsLogo32x32.png"), Extension.Contents("ShortcutsLogo40x40.png"), Extension.Contents("ShortcutsLogo48x48.png"), Extension.Contents("ShortcutsLogo64x64.png") }
];