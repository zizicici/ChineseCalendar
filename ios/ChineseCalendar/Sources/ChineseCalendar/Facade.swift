import Foundation

public protocol ChineseCalendarService {
    func query(_ query: CalendarQuery) throws -> CalendarQueryResult
    func day(_ year: Int, _ month: Int, _ day: Int) throws -> [BranchedCalendarDay]
    func day(_ year: Int, _ month: Int, _ day: Int, branch: CalendarBranch) throws -> CalendarDay
    func month(_ year: Int, _ month: Int) throws -> [LunisolarMonth]
    func month(_ year: Int, _ month: Int, branch: CalendarBranch) throws -> LunisolarMonth
    func year(_ gregorianYear: Int) throws -> [LunisolarYear]
    func year(_ gregorianYear: Int, branch: CalendarBranch) throws -> LunisolarYear
    func dynasties() throws -> [DynastyCatalogItem]
    func dynasties(branch: CalendarBranch?) throws -> [DynastyCatalogItem]
    func dynasty(_ dynasty: String, branch: CalendarBranch?) throws -> DynastyCatalogItem?
}

public typealias LunisolarService = ChineseCalendarService

public struct DefaultChineseCalendarService: ChineseCalendarService {
    private let engine: LunisolarEngine

    public init(engine: LunisolarEngine = ChineseCalendarFactory.makeEngine()) {
        self.engine = engine
    }

    public func query(_ query: CalendarQuery) throws -> CalendarQueryResult {
        switch query {
        case let .day(year, month, day):
            return .days(try self.day(year, month, day))
        case let .month(year, month):
            return .months(try self.month(year, month))
        case let .year(year):
            return .years(try self.year(year))
        }
    }

    private func resolvedBranches(for year: Int) -> [CalendarBranch] {
        let candidates = engine.branchSelector.resolveBranches(forGregorianYear: year)
        if candidates.isEmpty {
            return [engine.branchSelector.resolveBranch(forGregorianYear: year)]
        }
        return candidates
    }

    public func day(
        _ year: Int,
        _ month: Int,
        _ day: Int
    ) throws -> [BranchedCalendarDay] {
        try resolvedBranches(for: year).map { branch in
            BranchedCalendarDay(
                branch: branch,
                day: try self.day(year, month, day, branch: branch)
            )
        }
    }

    public func day(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        branch: CalendarBranch
    ) throws -> CalendarDay {
        guard (1...12).contains(month) else {
            throw LunisolarError.invalidGregorianMonth(month)
        }
        let computedYear = try self.year(year, branch: branch)
        guard let match = computedYear.days.first(where: { $0.gregorian.month == month && $0.gregorian.day == day }) else {
            throw LunisolarError.invalidGregorianDay(year: year, month: month, day: day)
        }
        return match
    }

    public func month(
        _ year: Int,
        _ month: Int
    ) throws -> [LunisolarMonth] {
        try resolvedBranches(for: year).map { branch in
            try self.month(year, month, branch: branch)
        }
    }

    public func month(
        _ year: Int,
        _ month: Int,
        branch: CalendarBranch
    ) throws -> LunisolarMonth {
        guard (1...12).contains(month) else {
            throw LunisolarError.invalidGregorianMonth(month)
        }
        let computedYear = try self.year(year, branch: branch)
        let days = computedYear.days.filter { $0.gregorian.month == month }
        return LunisolarMonth(
            gregorianYear: year,
            gregorianMonth: month,
            branch: computedYear.branch,
            days: days
        )
    }

    public func year(_ gregorianYear: Int) throws -> [LunisolarYear] {
        try resolvedBranches(for: gregorianYear).map { branch in
            try self.year(gregorianYear, branch: branch)
        }
    }

    public func year(
        _ gregorianYear: Int,
        branch: CalendarBranch
    ) throws -> LunisolarYear {
        let request = CalendarRequest(gregorianYear: gregorianYear, branch: branch)
        return try engine.computeYear(request)
    }

    public func dynasties() throws -> [DynastyCatalogItem] {
        try dynasties(branch: nil)
    }

    public func dynasties(
        branch: CalendarBranch?
    ) throws -> [DynastyCatalogItem] {
        guard let resolver = engine.eraResolver as? EraCatalogResolving else {
            throw LunisolarError.notImplemented("Era catalog API is not available in current resolver")
        }
        return try resolver.resolveDynastyCatalog(branch: branch)
    }

    public func dynasty(
        _ dynasty: String,
        branch: CalendarBranch? = nil
    ) throws -> DynastyCatalogItem? {
        try dynasties(branch: branch).first { $0.dynasty == dynasty }
    }
}

public typealias DefaultLunisolarService = DefaultChineseCalendarService
