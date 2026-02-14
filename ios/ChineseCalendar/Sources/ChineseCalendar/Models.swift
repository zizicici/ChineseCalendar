import Foundation

public enum CalendarBranch: Sendable, Equatable, Hashable {
    case modern
    case ancient
    case splitRegion(RegionCalendar)
}

public enum RegionCalendar: String, Sendable, Hashable, CaseIterable {
    case shu
    case wu
    case laterQin
    case northernLiang
    case weiZhouSui
    case weiQi
    case liaoJinYuan
    case southernMing
}

public struct GregorianDate: Hashable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
}

public struct GregorianMonth: Hashable, Sendable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }
}

public struct LunarDate: Hashable, Sendable {
    public let month: Int
    public let day: Int
    public let isLeapMonth: Bool

    public init(month: Int, day: Int, isLeapMonth: Bool) {
        self.month = month
        self.day = day
        self.isLeapMonth = isLeapMonth
    }
}

public struct EraName: Hashable, Sendable {
    public let dynasty: String
    public let sovereignTitle: String?
    public let eraName: String?
    public let reignTitle: String
    public let regnalYear: Int
    public let periodLabel: String?
    public let rawText: String?
    public let displayText: String?

    public init(
        dynasty: String,
        reignTitle: String,
        regnalYear: Int = 0,
        displayText: String? = nil,
        sovereignTitle: String? = nil,
        eraName: String? = nil,
        periodLabel: String? = nil,
        rawText: String? = nil
    ) {
        self.dynasty = dynasty
        self.sovereignTitle = sovereignTitle
        self.eraName = eraName
        self.reignTitle = reignTitle
        self.regnalYear = regnalYear
        self.periodLabel = periodLabel
        self.rawText = rawText
        self.displayText = displayText
    }
}

public struct EraCatalogItem: Hashable, Sendable {
    public let eraName: String
    public let sovereignTitle: String?
    public let periodLabel: String?
    public let firstYear: Int
    public let lastYear: Int
    public let branches: [CalendarBranch]

    public init(
        eraName: String,
        sovereignTitle: String?,
        periodLabel: String?,
        firstYear: Int,
        lastYear: Int,
        branches: [CalendarBranch]
    ) {
        self.eraName = eraName
        self.sovereignTitle = sovereignTitle
        self.periodLabel = periodLabel
        self.firstYear = firstYear
        self.lastYear = lastYear
        self.branches = branches
    }
}

public struct SovereignCatalogItem: Hashable, Sendable {
    public let sovereignTitle: String?
    public let firstYear: Int
    public let lastYear: Int
    public let branches: [CalendarBranch]
    public let eras: [EraCatalogItem]

    public init(
        sovereignTitle: String?,
        firstYear: Int,
        lastYear: Int,
        branches: [CalendarBranch],
        eras: [EraCatalogItem]
    ) {
        self.sovereignTitle = sovereignTitle
        self.firstYear = firstYear
        self.lastYear = lastYear
        self.branches = branches
        self.eras = eras
    }
}

public struct DynastyCatalogItem: Hashable, Sendable {
    public let dynasty: String
    public let firstYear: Int
    public let lastYear: Int
    public let branches: [CalendarBranch]
    public let sovereigns: [SovereignCatalogItem]
    public let eras: [EraCatalogItem]

    public init(
        dynasty: String,
        firstYear: Int,
        lastYear: Int,
        branches: [CalendarBranch],
        sovereigns: [SovereignCatalogItem],
        eras: [EraCatalogItem]
    ) {
        self.dynasty = dynasty
        self.firstYear = firstYear
        self.lastYear = lastYear
        self.branches = branches
        self.sovereigns = sovereigns
        self.eras = eras
    }
}

public struct SolarTermEvent: Hashable, Sendable {
    public let index: Int
    public let name: String
    public let occursAt: GregorianDate

    public init(index: Int, name: String, occursAt: GregorianDate) {
        self.index = index
        self.name = name
        self.occursAt = occursAt
    }
}

public struct CalendarDay: Hashable, Sendable {
    public let gregorian: GregorianDate
    public let lunar: LunarDate?
    public let solarTerm: SolarTermEvent?
    public let eraNames: [EraName]

    public init(gregorian: GregorianDate, lunar: LunarDate?, solarTerm: SolarTermEvent?, eraNames: [EraName]) {
        self.gregorian = gregorian
        self.lunar = lunar
        self.solarTerm = solarTerm
        self.eraNames = eraNames
    }
}

public struct BranchedCalendarDay: Hashable, Sendable {
    public let branch: CalendarBranch
    public let day: CalendarDay

    public init(branch: CalendarBranch, day: CalendarDay) {
        self.branch = branch
        self.day = day
    }
}

public struct LunisolarMonth: Sendable {
    public let gregorianYear: Int
    public let gregorianMonth: Int
    public let branch: CalendarBranch
    public let days: [CalendarDay]

    public init(gregorianYear: Int, gregorianMonth: Int, branch: CalendarBranch, days: [CalendarDay]) {
        self.gregorianYear = gregorianYear
        self.gregorianMonth = gregorianMonth
        self.branch = branch
        self.days = days
    }
}

public struct LunisolarYear: Sendable {
    public let gregorianYear: Int
    public let branch: CalendarBranch
    public let days: [CalendarDay]

    public init(gregorianYear: Int, branch: CalendarBranch, days: [CalendarDay]) {
        self.gregorianYear = gregorianYear
        self.branch = branch
        self.days = days
    }
}

public enum CalendarQuery: Sendable {
    case day(year: Int, month: Int, day: Int)
    case month(year: Int, month: Int)
    case year(year: Int)
}

public enum CalendarQueryResult: Sendable {
    case days([BranchedCalendarDay])
    case months([LunisolarMonth])
    case years([LunisolarYear])
}

public struct CalendarRequest: Sendable {
    public let gregorianYear: Int
    public let branch: CalendarBranch?

    public init(
        gregorianYear: Int,
        branch: CalendarBranch? = nil
    ) {
        self.gregorianYear = gregorianYear
        self.branch = branch
    }
}

public struct SunMoonYearCompressedData: Sendable {
    public let year: Int
    public let compressedMoonPhases: [Int]
    public let compressedSolarTerms: [Int]

    public init(year: Int, compressedMoonPhases: [Int], compressedSolarTerms: [Int]) {
        self.year = year
        self.compressedMoonPhases = compressedMoonPhases
        self.compressedSolarTerms = compressedSolarTerms
    }
}

public struct SunMoonOffset: Sendable {
    public let solar: Int
    public let lunar: Int

    public init(solar: Int, lunar: Int) {
        self.solar = solar
        self.lunar = lunar
    }
}

public struct AstronomicalContext: Sendable {
    public let year: Int
    public let moonPhasesJD: [Double]
    public let solarTermsJD: [Double]

    public init(year: Int, moonPhasesJD: [Double], solarTermsJD: [Double]) {
        self.year = year
        self.moonPhasesJD = moonPhasesJD
        self.solarTermsJD = solarTermsJD
    }
}

public struct RawCalendarDay: Sendable {
    public let gregorian: GregorianDate
    public let lunar: LunarDate?

    public init(gregorian: GregorianDate, lunar: LunarDate?) {
        self.gregorian = gregorian
        self.lunar = lunar
    }
}

public struct RawCalendarYear: Sendable {
    public let gregorianYear: Int
    public let branch: CalendarBranch
    public let days: [RawCalendarDay]

    public init(gregorianYear: Int, branch: CalendarBranch, days: [RawCalendarDay]) {
        self.gregorianYear = gregorianYear
        self.branch = branch
        self.days = days
    }
}

public typealias ChineseCalendarMonth = LunisolarMonth
public typealias ChineseCalendarYear = LunisolarYear
public typealias ChineseCalendarDayByBranch = BranchedCalendarDay
