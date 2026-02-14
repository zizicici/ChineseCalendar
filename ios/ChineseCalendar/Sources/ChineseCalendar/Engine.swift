import Foundation

public struct LunisolarEngine {
    public let branchSelector: BranchSelecting
    public let sunMoonProvider: SunMoonDataProviding
    public let decompressor: SunMoonDecompressing
    public let modernCalculator: ModernYearComputing?
    public let ancientCalculator: AncientYearComputing?
    public let splitCalculator: SplitRegionYearComputing?
    public let solarTermResolver: SolarTermResolving
    public let eraResolver: EraResolving
    public let assembler: YearAssembling

    public init(
        branchSelector: BranchSelecting,
        sunMoonProvider: SunMoonDataProviding,
        decompressor: SunMoonDecompressing,
        modernCalculator: ModernYearComputing?,
        ancientCalculator: AncientYearComputing?,
        splitCalculator: SplitRegionYearComputing?,
        solarTermResolver: SolarTermResolving,
        eraResolver: EraResolving,
        assembler: YearAssembling
    ) {
        self.branchSelector = branchSelector
        self.sunMoonProvider = sunMoonProvider
        self.decompressor = decompressor
        self.modernCalculator = modernCalculator
        self.ancientCalculator = ancientCalculator
        self.splitCalculator = splitCalculator
        self.solarTermResolver = solarTermResolver
        self.eraResolver = eraResolver
        self.assembler = assembler
    }

    public func computeYear(_ request: CalendarRequest) throws -> LunisolarYear {
        let year = request.gregorianYear

        // 1) Route to modern / ancient / split-region logic.
        let branch = request.branch ?? branchSelector.resolveBranch(forGregorianYear: year)

        // 2) Pull compressed sun/moon rows for this year and validate range.
        let supported = sunMoonProvider.supportedYearRange()
        guard supported.contains(year) else { throw LunisolarError.unsupportedYear(year) }
        guard let compressed = sunMoonProvider.compressedData(forYear: year) else {
            throw LunisolarError.missingCompressedSunMoonData(year)
        }

        // 3) Decompress astronomical events (new moons + 24 terms).
        let offset = sunMoonProvider.decompressionOffset()
        let moonPhases = try decompressor.decompressMoonPhases(
            year: year,
            compressed: compressed.compressedMoonPhases,
            offset: offset.lunar
        )
        let solarTerms = try decompressor.decompressSolarTerms(
            year: year,
            compressed: compressed.compressedSolarTerms,
            offset: offset.solar
        )

        let astronomy = AstronomicalContext(year: year, moonPhasesJD: moonPhases, solarTermsJD: solarTerms)

        // 4) Compute raw lunar months/days with branch-specific algorithm.
        let rawYear: RawCalendarYear
        switch branch {
        case .modern:
            guard let modernCalculator else { throw LunisolarError.missingCalculator(branch) }
            rawYear = try modernCalculator.computeYear(request: request, astronomy: astronomy)
        case .ancient:
            guard let ancientCalculator else { throw LunisolarError.missingCalculator(branch) }
            rawYear = try ancientCalculator.computeYear(request: request, astronomy: astronomy)
        case .splitRegion:
            guard let splitCalculator else { throw LunisolarError.missingCalculator(branch) }
            rawYear = try splitCalculator.computeYear(request: request, branch: branch, astronomy: astronomy)
        }

        // 5) Resolve 24 solar terms and historical era labels.
        let termEvents = try solarTermResolver.resolveSolarTerms(for: request, from: astronomy, branch: branch)
        var eraNamesByDate: [GregorianDate: [EraName]] = [:]
        for day in rawYear.days {
            eraNamesByDate[day.gregorian] = try eraResolver.resolveEraNames(
                forGregorianDate: day.gregorian,
                branch: branch
            )
        }

        // 6) Assemble final day model for iOS UI/API usage.
        return try assembler.assemble(rawYear: rawYear, solarTerms: termEvents, eraNamesByDate: eraNamesByDate)
    }
}
