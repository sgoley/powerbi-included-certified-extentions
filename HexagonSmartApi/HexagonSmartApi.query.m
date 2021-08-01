let
    //test with trailing slashes
    TestParametricFilter = () => let
        Source = HexagonSmartApi.Feed("https://samtest.spclouddave.com/SampleService/Sppid/V3/", null, null),
        SiteA = Source{1}[Data],
        ParametricFilter = Source{2}[Data],
        Plants = SiteA{[Id="Site A"]}[Plants],
        PlantA = Table.SelectRows(Plants, each [Id] = "Plant A"),
        PlantAWithParaFilter = Table.AddColumn(PlantA, "ParametricFilter", each ParametricFilter([Filters])),
        EquipmentFilter = PlantAWithParaFilter{[Id="Plant A"]}[ParametricFilter],
        EquipmentFilterFunction = EquipmentFilter{[Id="1582"]}[ExecuteParametricFilter],
        ExecuteResults = EquipmentFilterFunction("PBS", null, null, "$top=2"),
        Success = if (Table.RowCount(ExecuteResults) = 2) then
                    true
                  else
                    false
    in
        Success,

    TestSelectList = () => let
        Source = HexagonSmartApi.Feed("https://samtest.spclouddave.com/SampleService/Sppid/V3/", null, null),
        ApplySelectListFunction = Source{3}[Data],
        Sites = Source{1}[Data],
        SiteA = Sites{[Id="Site A"]},
        Plants = SiteA[Plants],
        PlantA = Table.SelectRows(Plants, each [Id] = "Plant A"),
        Pipes = PlantA{0}[Pipes],
        PipesWithSelectListColumns = ApplySelectListFunction(Pipes),
        Success = if (PipesWithSelectListColumns{0}[InsulPurposeSL] = "Type C") then
                    true
                  else
                    false
    in
        Success,

    TestTypecast = () => let
        Source = HexagonSmartApi.Feed("https://samtest.spclouddave.com/SampleService/Sppid/V3", null, null),
        Sites = Source{1}[Data],
        Plants = Sites{[Id="Site A"]}[Plants],
        PlantAItems = Plants{[Id="Plant A"]}[PlantItems],
        PlantAPipes = HexagonSmartApi.Typecast(PlantAItems, "Com.Ingr.Sppid.V3.PipeBase"),
        Success = if (PlantAPipes{0}[Status] = "Active") then
                    true
                  else
                    false
    in
        Success,

    TestUnitsOfMeasure = () => let 
        Source = HexagonSmartApi.Feed("https://samtest.spclouddave.com/SampleService/Sppid/V3", null, null),
        Sites = Source{1}[Data],
        Plants = Sites{[Id="Site A"]}[Plants],
        PlantA = Table.SelectRows(Plants, each [Id] = "Plant A"),
        Pipes = PlantA{0}[Pipes],
        ApplyUoMFunction = Source{4}[Data],
        PipesLengthFt = Table.AddColumn(Pipes, "LengthFt", each ApplyUoMFunction([LengthSiValue], "Length", "m", "ft", 2)),
        Success = if (PipesLengthFt{0}[LengthFt] >= 0) then  //sample service generates SI values.  Just check for any positive number.
                    true
                  else
                    false
    in
        Success,

   TestUnitsOfMeasureTable = () => let 
        Source = HexagonSmartApi.Feed("https://samtest.spclouddave.com/SampleService/Sppid/V3/", null, null),
        UoMReferenceData = Source{5}[Data],
        UoMLengthReferenceData = Table.SelectRows(UoMReferenceData, each ([UnitCategory] = "Length")),
        Success = if (UoMLengthReferenceData{0}[BaseUnitSymbol] = "m") then
                    true
                  else
                    false
    in
        Success,

    Query7 = () => let
        Source = HexagonSmartApi.Feed("https://samdev.ingrnet.com/SmartApi.Samples.Service/api/v1/", null, null),
        Data0 = Source{0}[Data],
        #"3C3C802D-2D04-49D9-8E33-C09A64530A9C" = Data0{[Id="3C3C802D-2D04-49D9-8E33-C09A64530A9C"]}[Plants],
        #"E63F816D-B7E7-4FC9-AE62-7E709AFF290E" = #"3C3C802D-2D04-49D9-8E33-C09A64530A9C"{[Id="E63F816D-B7E7-4FC9-AE62-7E709AFF290E"]}[Pipes],
        #"Kept First Rows" = Table.FirstN(#"E63F816D-B7E7-4FC9-AE62-7E709AFF290E",100),
        CatalogItems = HexagonSmartApi.Typecast(#"Kept First Rows","Com.Ingr.SampleApi.V1.CatalogItem")
    in
        CatalogItems,

    Query9 = () => let
        Source = HexagonSmartApi.Feed("https://samdev.ingrnet.com/SmartApi.Samples.Service/api/v1/", null, null),
        sites = Source{0}[Data],
        createParaFilterFunc = Source{1}[Data],
        plants = sites{[Id="3C3C802D-2D04-49D9-8E33-C09A64530A9C"]}[Plants],
        addFuncCol = Table.AddColumn(plants, "createPFF", each createParaFilterFunc([ParametricFilters])),
        func0 = addFuncCol[createPFF]{0}
    in
        func0,

    Query15 = () => let
        Source = HexagonSmartApi.Feed("https://s3dwebapisam.ingrnet.com/s3d/v1", null, null),
        Sites = Source{0}[Data],
        CreatePFF = Source{1}[Data],
        Plants= Sites{[Id="defwsbindatp_sdb"]}[Plants],
        Plants_DefWSBindATP = Table.SelectRows(Plants, each [Id] = "DefWSBindATP"),
        S3dFilters = Plants_DefWSBindATP{[Id="DefWSBindATP"]}[S3dFilters],
        AllWBSFilter = Table.SelectRows(S3dFilters, each [Id] = "{0000272E-0000-0000-0400-D78DEB542404}"),
        AllWBSWithExecuteFilter = CreatePFF(AllWBSFilter),
        epf = AllWBSWithExecuteFilter[ExecuteParametricFilter],
        res = epf{0}("$top=1")
    in
        res,

    TestParseHeaders = () => let 
        Source = HexagonSmartApi.Feed("https://samtest.spclouddave.com/SampleService/Sppid/V3", " X-Ingr-Test = hello , SpfSite= SiteA ", null)
    in
        Source,
  
    results = if (TestParametricFilter() = false) then
                error "TestParametricFilter failed"
              else
                if (TestSelectList() = false) then
                    error "TestSelectList failed"
                else
                    if (TestTypecast() = false) then
                        error "TestTypecast failed"
                    else
                        if (TestUnitsOfMeasure() = false) then
                            error "TestUnitsOfMeasure failed"
                        else
                            if (TestUnitsOfMeasureTable() = false) then
                                error "TestUnitsOfMeasureTable failed"
                            else
                                true,

    restest = TestParseHeaders()
in 
    results