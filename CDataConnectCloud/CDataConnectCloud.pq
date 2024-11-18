[Version = "3.0.0"]
section CDataConnectCloud;

// Data Source Kind description
CDataConnectCloud = [
    TestConnection = (dataSourcePath) => {"CDataConnectCloud.ContentsV2"},
    Authentication = [
        OAuth = [
            StartLogin = OAuth.StartLogin,
            FinishLogin = OAuth.FinishLogin,
            Refresh = OAuth.Refresh,
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
CDataConnectCloud.Publish = [
    Category = "Online Services",
    ButtonText = {Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp")},
    LearnMoreUrl = "https://www.cdata.com/connect/cloud/",
    SourceImage = CDataConnectCloud.Icons,
    SourceTypeImage = CDataConnectCloud.Icons
];
CDataConnectCloud.Icons = [
    Icon16 = {
        Extension.Contents("CDataConnectCloud48.png"),
        Extension.Contents("CDataConnectCloud48.png"),
        Extension.Contents("CDataConnectCloud48.png"),
        Extension.Contents("CDataConnectCloud48.png")
    },
    Icon32 = {
        Extension.Contents("CDataConnectCloud48.png"),
        Extension.Contents("CDataConnectCloud48.png"),
        Extension.Contents("CDataConnectCloud48.png"),
        Extension.Contents("CDataConnectCloud48.png")
    }
];
[
    DataSource.Kind = "CDataConnectCloud",
    Publish = "CDataConnectCloud.Publish"
]
shared CDataConnectCloud.ContentsV2 = Value.ReplaceType(CDataConnectCloudServiceV2.NavImpl, CDataConnectCloud.NavImplType);
[
    DataSource.Kind = "CDataConnectCloud"
]
shared CDataConnectCloud.Contents = Value.ReplaceType(CDataConnectCloudService.NavImpl, CDataConnectCloud.NavImplType);

CDataConnectCloud.NavImplType = type function (
    optional options as (
        type [
            optional Query = (
                type text meta [
                    Documentation.FieldCaption = Extension.LoadString("OptionsQueryFieldCaption"),
                    Documentation.DefaultValue = "",
                    Documentation.SampleValues = {Extension.LoadString("OptionsQueryFieldSample")},
                    Documentation.FieldDescription = ""
                ]
            )
        ] meta [
            Documentation.FieldCaption = Extension.LoadString("OptionsFieldCaption")
        ]
    )
) as table meta [
    Documentation.Name = "CData Connect Cloud",
    Documentation.LongDescription = "Returns a table with relevant data from the connected data source in CData Connect Cloud."
];

// Load utility functions
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name), asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

OAuth = Extension.LoadFunction("OAuth.pqm");
OAuth.StartLogin = OAuth[StartLogin];
OAuth.FinishLogin = OAuth[FinishLogin];
OAuth.Refresh = OAuth[Refresh];

CDataConnectCloudServiceV2 = Extension.LoadFunction("CDataConnectCloudServiceV2.pqm");
CDataConnectCloudServiceV2.NavImpl = CDataConnectCloudServiceV2[NavImpl];

CDataConnectCloudService = Extension.LoadFunction("CDataConnectCloudService.pqm");
CDataConnectCloudService.NavImpl = CDataConnectCloudService[NavImpl];