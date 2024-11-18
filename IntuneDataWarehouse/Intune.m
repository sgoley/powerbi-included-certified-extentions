// This file contains your Data Connector logic
[Version = "1.0.1"]
section Intune;

Intune.AuthUri = "https://login.microsoftonline.com/common/oauth2/authorize";

//PE
Intune.DateWarehouseUri = "https://warehouse.manage.microsoft.com/beta/";
Intune.ResourceUri = "https://warehouse.manage.microsoft.com";

// ReplaceType allows us to define a custom type that includes friendly text as well as the allowed values for maxHistoryDays turning it
// from a text box into a dropdown.
[DataSource.Kind="Intune", Publish="Intune.Publish"]
shared Intune.Contents = Value.ReplaceType(IntuneDwImpl, IntuneDwType) ;

// User friendly text and dropdown values
IntuneDwType = type function (
    maxHistoryDays as (type number meta [
        Documentation.FieldCaption = "Number of days of history to retrieve",
        Documentation.FieldDescription = "Number of days of history to retrieve. This will only apply to certain large data sets that provide daily information for your environment.",
        Documentation.AllowedValues = { 1, 2, 3, 4, 5, 6, 7, 14, 30, 60 }
        ]))
    as table meta [
        Documentation.Name = "Intune Data Warehouse",
        Documentation.LongDescription = "Intune Data Warehouse"];

IntuneDwImpl = (maxHistoryDays as number) =>
    let
        // Fall back to a default of 7 days if anything is wrong with maxHistoryDays
        _maxDays = if (Value.Is(maxHistoryDays, Int8.Type) and maxHistoryDays > 0) then maxHistoryDays else 7,
        queryString = [MaxHistoryDays=Number.ToText(_maxDays)],
        feed = OData.Feed(Intune.DateWarehouseUri, null, [Query = queryString])
    in
        feed;

// Data Source Kind description
Intune = [
    Type = "Singleton",
    MakeResourcePath = () => "Intune",
    ParseResourcePath = (resource) => { },
    // Passing 1 for MHD here. TestConnection is used by PBI service which won't persist credentials if TestConnection fails
    TestConnection = (dataSourcePath) => {"Intune.Contents", 1}, 
    Authentication = [
        Aad = [
            AuthorizationUri = Intune.AuthUri,
            Resource = Intune.ResourceUri,
            DefaultClientApplication = [
                ClientId = "a672d62c-fc7b-4e81-a576-e60dc46e951d",
                ClientSecret = "",
                CallbackUrl = "https://preview.powerbi.com/views/oauthredirect.html"
            ]
        ]
    ],    Label = "Intune Data Warehouse"
];

// Data Source UI publishing description
Intune.Publish = [
    Beta = true,
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = Intune.Icons,
    SourceTypeImage = Intune.Icons
];

Intune.Icons = [
    Icon16 = { Extension.Contents("Intune16.png"), Extension.Contents("Intune20.png"), Extension.Contents("Intune24.png"), Extension.Contents("Intune32.png") },
    Icon32 = { Extension.Contents("Intune32.png"), Extension.Contents("Intune40.png"), Extension.Contents("Intune48.png"), Extension.Contents("Intune64.png") }
];