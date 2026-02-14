import Foundation

public protocol BranchSelecting {
    func resolveBranch(forGregorianYear year: Int) -> CalendarBranch
    func resolveBranches(forGregorianYear year: Int) -> [CalendarBranch]
}

public extension BranchSelecting {
    func resolveBranches(forGregorianYear year: Int) -> [CalendarBranch] {
        [resolveBranch(forGregorianYear: year)]
    }
}

public protocol SunMoonDataProviding {
    func supportedYearRange() -> ClosedRange<Int>
    func decompressionOffset() -> SunMoonOffset
    func compressedData(forYear year: Int) -> SunMoonYearCompressedData?
}

public protocol SunMoonDecompressing {
    func decompressMoonPhases(year: Int, compressed: [Int], offset: Int) throws -> [Double]
    func decompressSolarTerms(year: Int, compressed: [Int], offset: Int) throws -> [Double]
}

public protocol ModernYearComputing {
    func computeYear(request: CalendarRequest, astronomy: AstronomicalContext) throws -> RawCalendarYear
}

public protocol AncientYearComputing {
    func computeYear(request: CalendarRequest, astronomy: AstronomicalContext) throws -> RawCalendarYear
}

public protocol SplitRegionYearComputing {
    func computeYear(request: CalendarRequest, branch: CalendarBranch, astronomy: AstronomicalContext) throws -> RawCalendarYear
}

public protocol SolarTermResolving {
    func resolveSolarTerms(
        for request: CalendarRequest,
        from astronomy: AstronomicalContext,
        branch: CalendarBranch
    ) throws -> [SolarTermEvent]
}

public protocol EraResolving {
    func resolveEraNames(
        forGregorianDate date: GregorianDate,
        branch: CalendarBranch
    ) throws -> [EraName]
}

public protocol EraCatalogResolving {
    func resolveDynastyCatalog(
        branch: CalendarBranch?
    ) throws -> [DynastyCatalogItem]
}

public protocol YearAssembling {
    func assemble(
        rawYear: RawCalendarYear,
        solarTerms: [SolarTermEvent],
        eraNamesByDate: [GregorianDate: [EraName]]
    ) throws -> LunisolarYear
}
