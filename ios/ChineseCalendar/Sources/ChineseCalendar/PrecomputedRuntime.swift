import Foundation

private struct YearDataPayload: Decodable {
    struct Meta: Decodable {
        let startYear: Int
        let endYear: Int
    }

    struct CalendarEntry: Decodable {
        let cD: [Int]
        let cN: [Int]
        let sM: [Int]
        let era: String
    }

    struct YearEntry: Decodable {
        let y: Int
        let cD: [Int]
        let cN: [Int]
        let sM: [Int]
        let era: String
        let r: [String: CalendarEntry]?
    }

    let meta: Meta
    let years: [YearEntry]
}

struct PrecomputedEraEntry {
    let dynasty: String
    let sovereignTitle: String
    let eraName: String
    let regnalYear: Int?
    let periodLabel: String?
    let rawText: String
}

struct PrecomputedYearRecord {
    let year: Int
    let defaultCalendar: PrecomputedCalendarRecord
    let regionCalendars: [RegionCalendar: PrecomputedCalendarRecord]
}

struct PrecomputedCalendarRecord {
    let monthStarts: [Int]
    let monthNumbers: [Int]
    let solarMinutes: [Int]
    let era: String
    let eraEntries: [PrecomputedEraEntry]
}

final class PrecomputedYearStore {
    static let shared = PrecomputedYearStore()

    let supportedRange: ClosedRange<Int>
    private let records: [Int: PrecomputedYearRecord]

    private init() {
        do {
            let url = Bundle.module.url(forResource: "year_data.default", withExtension: "json")
            guard let url else {
                fatalError("Missing year_data.default.json resource")
            }
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(YearDataPayload.self, from: data)

            supportedRange = payload.meta.startYear...payload.meta.endYear
            records = Dictionary(uniqueKeysWithValues: payload.years.map { entry in
                let defaultCalendar = PrecomputedCalendarRecord(
                    monthStarts: entry.cD,
                    monthNumbers: entry.cN,
                    solarMinutes: entry.sM,
                    era: entry.era,
                    eraEntries: parseEraEntries(from: entry.era)
                )

                let regionCalendars = (entry.r ?? [:]).reduce(into: [RegionCalendar: PrecomputedCalendarRecord]()) { partial, pair in
                    guard let region = RegionCalendar(rawValue: pair.key) else { return }
                    partial[region] = PrecomputedCalendarRecord(
                        monthStarts: pair.value.cD,
                        monthNumbers: pair.value.cN,
                        solarMinutes: pair.value.sM,
                        era: pair.value.era,
                        eraEntries: parseEraEntries(from: pair.value.era)
                    )
                }

                return (
                    entry.y,
                    PrecomputedYearRecord(
                        year: entry.y,
                        defaultCalendar: defaultCalendar,
                        regionCalendars: regionCalendars
                    )
                )
            })
        } catch {
            fatalError("Failed to load precomputed calendar data: \(error)")
        }
    }

    func record(for year: Int) -> PrecomputedYearRecord? {
        records[year]
    }

    func calendar(for year: Int, branch: CalendarBranch) -> PrecomputedCalendarRecord? {
        guard let record = records[year] else {
            return nil
        }
        switch branch {
        case .modern, .ancient:
            return record.defaultCalendar
        case let .splitRegion(region):
            return record.regionCalendars[region]
        }
    }

    func years() -> [Int] {
        records.keys.sorted()
    }

    func availableBranches(for year: Int) -> [CalendarBranch] {
        guard let record = records[year] else {
            return []
        }
        var branches: [CalendarBranch] = [.modern]
        for region in RegionCalendar.allCases where record.regionCalendars[region] != nil {
            branches.append(.splitRegion(region))
        }
        return branches
    }
}

private enum GregorianMath {
    static func daysInYear(_ year: Int) -> Int {
        var days = (year == 1582 ? 355 : 365) + (abs(year) % 4 == 0 ? 1 : 0)
        if year > 1582 {
            days += (year % 100 == 0 ? -1 : 0) + (year % 400 == 0 ? 1 : 0)
        }
        return days
    }

    static func monthStartOffsets(_ year: Int) -> [Int] {
        let leap = daysInYear(year) == 366 ? 1 : 0
        if year == 1582 {
            return [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 294, 324, 355]
        }
        return [
            0,
            31,
            59 + leap,
            90 + leap,
            120 + leap,
            151 + leap,
            181 + leap,
            212 + leap,
            243 + leap,
            273 + leap,
            304 + leap,
            334 + leap,
            365 + leap
        ]
    }

    static func validDays(inYear year: Int, month: Int) -> [Int]? {
        guard (1...12).contains(month) else { return nil }
        if year == 1582, month == 10 {
            return Array(1...4) + Array(15...31)
        }
        let offsets = monthStartOffsets(year)
        let length = offsets[month] - offsets[month - 1]
        return Array(1...length)
    }

    static func dayOfYear(year: Int, month: Int, day: Int) -> Int? {
        guard let validDays = validDays(inYear: year, month: month), validDays.contains(day) else {
            return nil
        }

        let offsets = monthStartOffsets(year)
        if year == 1582, month == 10 {
            if day <= 4 {
                return offsets[month - 1] + day
            }
            return offsets[month - 1] + (day - 10)
        }
        return offsets[month - 1] + day
    }

    static func dateFromDayOfYear(year: Int, dayOfYear: Int) -> GregorianDate? {
        guard dayOfYear >= 1, dayOfYear <= daysInYear(year) else {
            return nil
        }

        let offsets = monthStartOffsets(year)
        var month = 1
        var day = dayOfYear
        for i in 1..<offsets.count {
            if dayOfYear <= offsets[i] {
                month = i
                day = dayOfYear - offsets[i - 1]
                break
            }
        }

        if year == 1582, month == 10, day >= 5 {
            day += 10
        }

        return GregorianDate(year: year, month: month, day: day)
    }
}

private func lunarDate(for dayOfYear: Int, in record: PrecomputedCalendarRecord) -> LunarDate? {
    for i in 0..<record.monthStarts.count {
        let start = record.monthStarts[i]
        let end = (i + 1 < record.monthStarts.count) ? record.monthStarts[i + 1] : Int.max
        if dayOfYear >= start, dayOfYear < end {
            let monthNumber = record.monthNumbers[i]
            return LunarDate(
                month: abs(monthNumber),
                day: dayOfYear - start + 1,
                isLeapMonth: monthNumber < 0
            )
        }
    }
    return nil
}

private func normalizedEraText(_ text: String) -> String {
    text
        .replacingOccurrences(of: "(", with: "")
        .replacingOccurrences(of: ")", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private let knownDynasties: [String] = [
    "南北朝", "南明", "後梁", "后梁", "後唐", "后唐", "後晉", "后晋", "後漢", "后汉", "後周", "后周",
    "北魏", "東魏", "东魏", "西魏", "北齊", "北齐", "北周", "北涼", "北凉", "後秦", "后秦",
    "東晉", "东晋", "西晉", "西晋", "東漢", "东汉", "西漢", "西汉",
    "遼", "辽", "金", "元", "明", "清", "宋", "齊", "齐", "梁", "陳", "陈",
    "隋", "唐", "晉", "晋", "魏", "蜀", "吳", "吴", "漢", "汉", "秦", "周", "魯", "鲁", "新"
]
    .sorted { $0.count > $1.count }

private let ownerMarkers: Set<Character> = ["帝", "王", "公", "侯", "后", "後", "主", "君", "皇", "宗", "祖"]

private let chineseDigits: [Character: Int] = [
    "零": 0, "〇": 0, "一": 1, "二": 2, "三": 3, "四": 4,
    "五": 5, "六": 6, "七": 7, "八": 8, "九": 9, "两": 2, "兩": 2
]

private let chineseUnits: [Character: Int] = ["十": 10, "百": 100, "千": 1000]

private func parseRegnalYear(_ token: String) -> Int? {
    if token.isEmpty { return nil }
    if token == "元" { return 1 }
    if let value = Int(token) { return value }

    let hasUnit = token.contains { chineseUnits[$0] != nil }
    if !hasUnit {
        var out = 0
        for char in token {
            guard let digit = chineseDigits[char] else { return nil }
            out = out * 10 + digit
        }
        return out
    }

    var total = 0
    var current = 0
    for char in token {
        if let digit = chineseDigits[char] {
            current = digit
            continue
        }
        if let unit = chineseUnits[char] {
            if current == 0 { current = 1 }
            total += current * unit
            current = 0
            continue
        }
        return nil
    }
    return total + current
}

private func splitOwnerAndEra(from core: String) -> (owner: String, eraName: String) {
    guard !core.isEmpty else { return ("", "") }

    if let index = core.lastIndex(where: { ownerMarkers.contains($0) }), index < core.index(before: core.endIndex) {
        let owner = String(core[...index])
        let era = String(core[core.index(after: index)...])
        return (owner, era)
    }

    if let dynasty = knownDynasties.first(where: { core.hasPrefix($0) && core.count > $0.count }) {
        let owner = dynasty
        let era = String(core.dropFirst(dynasty.count))
        return (owner, era)
    }

    return ("", core)
}

private func extractDynasty(from owner: String, fallback: String) -> String {
    if let dynasty = knownDynasties.first(where: { owner.hasPrefix($0) }) {
        return dynasty
    }
    return fallback
}

private func parseEraEntries(from sourceText: String) -> [PrecomputedEraEntry] {
    let normalized = normalizedEraText(sourceText)
    guard !normalized.isEmpty else { return [] }

    let segments = normalized
        .split(separator: "/")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    let yearPattern = try! NSRegularExpression(pattern: "(元|[〇零一二三四五六七八九十百千两兩0-9]+)年$")
    let labelPattern = try! NSRegularExpression(pattern: "^\\[([^\\]]+)\\](.+)$")

    var result: [PrecomputedEraEntry] = []
    var lastOwner = ""
    var lastDynasty = ""

    for segment in segments {
        var raw = segment
        var periodLabel: String?

        let rawRange = NSRange(location: 0, length: (raw as NSString).length)
        if let match = labelPattern.firstMatch(in: raw, range: rawRange), match.numberOfRanges == 3 {
            let rawNSString = raw as NSString
            periodLabel = rawNSString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            raw = rawNSString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let rawNSString = raw as NSString
        var regnalYear: Int?
        var core = raw
        let parsedRange = NSRange(location: 0, length: rawNSString.length)
        if let yearMatch = yearPattern.firstMatch(in: raw, range: parsedRange), yearMatch.numberOfRanges >= 2 {
            let yearToken = rawNSString.substring(with: yearMatch.range(at: 1))
            regnalYear = parseRegnalYear(yearToken)
            core = rawNSString.substring(to: yearMatch.range.location).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var (owner, eraName) = splitOwnerAndEra(from: core)
        if owner.isEmpty {
            owner = lastOwner
        }
        let dynasty = extractDynasty(from: owner, fallback: lastDynasty)

        if !owner.isEmpty {
            lastOwner = owner
        }
        if !dynasty.isEmpty {
            lastDynasty = dynasty
        }

        result.append(
            PrecomputedEraEntry(
                dynasty: dynasty,
                sovereignTitle: owner,
                eraName: eraName,
                regnalYear: regnalYear,
                periodLabel: periodLabel,
                rawText: segment
            )
        )
    }

    return result
}

private extension PrecomputedCalendarRecord {
    func eraSource() -> (text: String, entries: [PrecomputedEraEntry]) {
        return (era, eraEntries)
    }
}

public struct PrecomputedBranchSelector: BranchSelecting {
    public init() {}

    public func resolveBranch(forGregorianYear year: Int) -> CalendarBranch {
        resolveBranches(forGregorianYear: year).first ?? .modern
    }

    public func resolveBranches(forGregorianYear year: Int) -> [CalendarBranch] {
        var branches: [CalendarBranch] = [.modern]

        if (221...263).contains(year) {
            branches.append(.splitRegion(.shu))
        }
        if (222...279).contains(year) {
            branches.append(.splitRegion(.wu))
        }
        if (384...417).contains(year) {
            branches.append(.splitRegion(.laterQin))
        }
        if (412...439).contains(year) {
            branches.append(.splitRegion(.northernLiang))
        }
        if (398...590).contains(year) {
            branches.append(.splitRegion(.weiZhouSui))
        }
        if (534...577).contains(year) {
            branches.append(.splitRegion(.weiQi))
        }
        if (947...1279).contains(year) {
            branches.append(.splitRegion(.liaoJinYuan))
        }
        if (1645...1683).contains(year) {
            branches.append(.splitRegion(.southernMing))
        }

        return branches
    }
}

public struct PrecomputedSunMoonProvider: SunMoonDataProviding {
    private let store: PrecomputedYearStore

    init(store: PrecomputedYearStore) {
        self.store = store
    }

    public func supportedYearRange() -> ClosedRange<Int> {
        store.supportedRange
    }

    public func decompressionOffset() -> SunMoonOffset {
        SunMoonOffset(solar: 5, lunar: 5)
    }

    public func compressedData(forYear year: Int) -> SunMoonYearCompressedData? {
        guard store.record(for: year) != nil else { return nil }
        return SunMoonYearCompressedData(year: year, compressedMoonPhases: [], compressedSolarTerms: [])
    }
}

public struct NoopSunMoonDecompressor: SunMoonDecompressing {
    public init() {}

    public func decompressMoonPhases(year: Int, compressed: [Int], offset: Int) throws -> [Double] {
        _ = (year, compressed, offset)
        return []
    }

    public func decompressSolarTerms(year: Int, compressed: [Int], offset: Int) throws -> [Double] {
        _ = (year, compressed, offset)
        return []
    }
}

public struct PrecomputedYearCalculator: ModernYearComputing, AncientYearComputing, SplitRegionYearComputing {
    private let store: PrecomputedYearStore

    init(store: PrecomputedYearStore) {
        self.store = store
    }

    public func computeYear(request: CalendarRequest, astronomy: AstronomicalContext) throws -> RawCalendarYear {
        let branch: CalendarBranch
        switch request.branch {
        case .splitRegion:
            branch = .modern
        case .none:
            branch = .modern
        case let .some(value):
            branch = value
        }
        return try computeYear(request: request, astronomy: astronomy, branch: branch)
    }

    public func computeYear(
        request: CalendarRequest,
        branch: CalendarBranch,
        astronomy: AstronomicalContext
    ) throws -> RawCalendarYear {
        try computeYear(request: request, astronomy: astronomy, branch: branch)
    }

    private func computeYear(
        request: CalendarRequest,
        astronomy: AstronomicalContext,
        branch: CalendarBranch
    ) throws -> RawCalendarYear {
        _ = astronomy
        guard let calendar = store.calendar(for: request.gregorianYear, branch: branch) else {
            if store.record(for: request.gregorianYear) == nil {
                throw LunisolarError.unsupportedYear(request.gregorianYear)
            }
            throw LunisolarError.unsupportedBranchForYear(year: request.gregorianYear, branch: branch)
        }

        var days: [RawCalendarDay] = []
        days.reserveCapacity(GregorianMath.daysInYear(request.gregorianYear))

        for month in 1...12 {
            guard let validDays = GregorianMath.validDays(inYear: request.gregorianYear, month: month) else {
                continue
            }
            for day in validDays {
                guard
                    let dayOfYear = GregorianMath.dayOfYear(year: request.gregorianYear, month: month, day: day),
                    let lunar = lunarDate(for: dayOfYear, in: calendar)
                else {
                    continue
                }
                days.append(
                    RawCalendarDay(
                        gregorian: GregorianDate(year: request.gregorianYear, month: month, day: day),
                        lunar: lunar
                    )
                )
            }
        }

        return RawCalendarYear(gregorianYear: request.gregorianYear, branch: branch, days: days)
    }
}

public struct PrecomputedSolarTermResolver: SolarTermResolving {
    private let store: PrecomputedYearStore

    private static let namesTraditional = [
        "小寒", "大寒", "立春", "雨水", "驚蟄", "春分", "清明", "穀雨",
        "立夏", "小滿", "芒種", "夏至", "小暑", "大暑", "立秋", "處暑",
        "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"
    ]

    init(store: PrecomputedYearStore) {
        self.store = store
    }

    public func resolveSolarTerms(
        for request: CalendarRequest,
        from astronomy: AstronomicalContext,
        branch: CalendarBranch
    ) throws -> [SolarTermEvent] {
        _ = astronomy
        guard let record = store.calendar(for: request.gregorianYear, branch: branch) else {
            if store.record(for: request.gregorianYear) == nil {
                return []
            }
            throw LunisolarError.unsupportedBranchForYear(year: request.gregorianYear, branch: branch)
        }

        guard !record.solarMinutes.isEmpty else {
            return []
        }

        var events: [SolarTermEvent] = []
        for (index, minute) in record.solarMinutes.enumerated() {
            guard index < Self.namesTraditional.count else { break }
            let dayOfYear = Int(floor(Double(minute) / 1440.0))
            guard let date = GregorianMath.dateFromDayOfYear(year: request.gregorianYear, dayOfYear: dayOfYear) else {
                continue
            }
            events.append(SolarTermEvent(index: index, name: Self.namesTraditional[index], occursAt: date))
        }
        return events
    }
}

public struct PrecomputedEraResolver: EraResolving, EraCatalogResolving {
    private struct EraAccumulator {
        let eraName: String
        let sovereignTitle: String?
        let periodLabel: String?
        var firstYear: Int
        var lastYear: Int
        var branches: Set<CalendarBranch>

        mutating func absorb(year: Int, branch: CalendarBranch) {
            if year < firstYear { firstYear = year }
            if year > lastYear { lastYear = year }
            branches.insert(branch)
        }
    }

    private struct SovereignAccumulator {
        let sovereignTitle: String?
        var firstYear: Int
        var lastYear: Int
        var branches: Set<CalendarBranch>
        var eras: [String: EraAccumulator]

        mutating func absorb(year: Int, branch: CalendarBranch, era: PrecomputedEraEntry) {
            if year < firstYear { firstYear = year }
            if year > lastYear { lastYear = year }
            branches.insert(branch)

            let eraName = era.eraName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !eraName.isEmpty else { return }
            let periodLabel = era.periodLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = "\(eraName)|\(periodLabel ?? "")"
            if var existing = eras[key] {
                existing.absorb(year: year, branch: branch)
                eras[key] = existing
            } else {
                eras[key] = EraAccumulator(
                    eraName: eraName,
                    sovereignTitle: sovereignTitle,
                    periodLabel: periodLabel,
                    firstYear: year,
                    lastYear: year,
                    branches: [branch]
                )
            }
        }
    }

    private struct DynastyAccumulator {
        let dynasty: String
        var firstYear: Int
        var lastYear: Int
        var branches: Set<CalendarBranch>
        var sovereigns: [String: SovereignAccumulator]
        var eras: [String: EraAccumulator]

        mutating func absorb(year: Int, branch: CalendarBranch, era: PrecomputedEraEntry) {
            if year < firstYear { firstYear = year }
            if year > lastYear { lastYear = year }
            branches.insert(branch)

            let sovereign = era.sovereignTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let sovereignTitle = sovereign.isEmpty ? nil : sovereign
            let sovereignKey = sovereignTitle ?? "__unknown__"
            if var existing = sovereigns[sovereignKey] {
                existing.absorb(year: year, branch: branch, era: era)
                sovereigns[sovereignKey] = existing
            } else {
                var created = SovereignAccumulator(
                    sovereignTitle: sovereignTitle,
                    firstYear: year,
                    lastYear: year,
                    branches: [branch],
                    eras: [:]
                )
                created.absorb(year: year, branch: branch, era: era)
                sovereigns[sovereignKey] = created
            }

            let eraName = era.eraName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !eraName.isEmpty else { return }
            let periodLabel = era.periodLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
            let eraKey = "\(sovereignKey)|\(eraName)|\(periodLabel ?? "")"
            if var existingEra = eras[eraKey] {
                existingEra.absorb(year: year, branch: branch)
                eras[eraKey] = existingEra
            } else {
                eras[eraKey] = EraAccumulator(
                    eraName: eraName,
                    sovereignTitle: sovereignTitle,
                    periodLabel: periodLabel,
                    firstYear: year,
                    lastYear: year,
                    branches: [branch]
                )
            }
        }
    }

    private let store: PrecomputedYearStore

    init(store: PrecomputedYearStore) {
        self.store = store
    }

    private func branchSortKey(_ branch: CalendarBranch) -> Int {
        switch branch {
        case .modern:
            return 0
        case .ancient:
            return 1
        case let .splitRegion(region):
            return 10 + (RegionCalendar.allCases.firstIndex(of: region) ?? 999)
        }
    }

    private func sortBranches(_ branches: Set<CalendarBranch>) -> [CalendarBranch] {
        branches.sorted { lhs, rhs in
            let l = branchSortKey(lhs)
            let r = branchSortKey(rhs)
            if l != r { return l < r }
            return String(describing: lhs) < String(describing: rhs)
        }
    }

    public func resolveEraNames(
        forGregorianDate date: GregorianDate,
        branch: CalendarBranch
    ) throws -> [EraName] {
        guard let record = store.calendar(for: date.year, branch: branch) else {
            if store.record(for: date.year) == nil {
                return []
            }
            throw LunisolarError.unsupportedBranchForYear(year: date.year, branch: branch)
        }

        let source = record.eraSource()
        if source.text.isEmpty, source.entries.isEmpty {
            return []
        }

        let normalized = normalizedEraText(source.text)
        let entries = source.entries.isEmpty ? parseEraEntries(from: source.text) : source.entries
        if entries.isEmpty {
            return [
                EraName(
                    dynasty: "",
                    reignTitle: normalized,
                    regnalYear: 0,
                    displayText: normalized.isEmpty ? nil : normalized,
                    sovereignTitle: nil,
                    eraName: nil,
                    periodLabel: nil,
                    rawText: normalized.isEmpty ? nil : normalized
                )
            ]
        }

        return entries.map { entry in
            let reignTitle = entry.eraName.isEmpty ? (entry.sovereignTitle.isEmpty ? entry.rawText : entry.sovereignTitle) : entry.eraName
            return EraName(
                dynasty: entry.dynasty,
                reignTitle: reignTitle,
                regnalYear: entry.regnalYear ?? 0,
                displayText: entry.rawText,
                sovereignTitle: entry.sovereignTitle.isEmpty ? nil : entry.sovereignTitle,
                eraName: entry.eraName.isEmpty ? nil : entry.eraName,
                periodLabel: entry.periodLabel,
                rawText: entry.rawText
            )
        }
    }

    public func resolveDynastyCatalog(
        branch: CalendarBranch?
    ) throws -> [DynastyCatalogItem] {
        var dynasties: [String: DynastyAccumulator] = [:]

        for year in store.years() {
            let branches = branch.map { [$0] } ?? store.availableBranches(for: year)
            for selectedBranch in branches {
                guard let calendar = store.calendar(for: year, branch: selectedBranch) else {
                    continue
                }
                let source = calendar.eraSource()
                let entries = source.entries.isEmpty ? parseEraEntries(from: source.text) : source.entries
                for entry in entries {
                    let dynasty = entry.dynasty.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !dynasty.isEmpty else { continue }
                    if var existing = dynasties[dynasty] {
                        existing.absorb(year: year, branch: selectedBranch, era: entry)
                        dynasties[dynasty] = existing
                    } else {
                        var created = DynastyAccumulator(
                            dynasty: dynasty,
                            firstYear: year,
                            lastYear: year,
                            branches: [selectedBranch],
                            sovereigns: [:],
                            eras: [:]
                        )
                        created.absorb(year: year, branch: selectedBranch, era: entry)
                        dynasties[dynasty] = created
                    }
                }
            }
        }

        return dynasties.values.map { dynasty in
            let eraItems = dynasty.eras.values.map { era in
                EraCatalogItem(
                    eraName: era.eraName,
                    sovereignTitle: era.sovereignTitle,
                    periodLabel: era.periodLabel,
                    firstYear: era.firstYear,
                    lastYear: era.lastYear,
                    branches: sortBranches(era.branches)
                )
            }
                .sorted { lhs, rhs in
                    if lhs.firstYear != rhs.firstYear { return lhs.firstYear < rhs.firstYear }
                    if lhs.eraName != rhs.eraName { return lhs.eraName < rhs.eraName }
                    return (lhs.sovereignTitle ?? "") < (rhs.sovereignTitle ?? "")
                }

            let sovereignItems = dynasty.sovereigns.values.map { sovereign in
                let sovereignEras = sovereign.eras.values.map { era in
                    EraCatalogItem(
                        eraName: era.eraName,
                        sovereignTitle: era.sovereignTitle,
                        periodLabel: era.periodLabel,
                        firstYear: era.firstYear,
                        lastYear: era.lastYear,
                        branches: sortBranches(era.branches)
                    )
                }
                    .sorted { lhs, rhs in
                        if lhs.firstYear != rhs.firstYear { return lhs.firstYear < rhs.firstYear }
                        return lhs.eraName < rhs.eraName
                    }

                return SovereignCatalogItem(
                    sovereignTitle: sovereign.sovereignTitle,
                    firstYear: sovereign.firstYear,
                    lastYear: sovereign.lastYear,
                    branches: sortBranches(sovereign.branches),
                    eras: sovereignEras
                )
            }
                .sorted { lhs, rhs in
                    if lhs.firstYear != rhs.firstYear { return lhs.firstYear < rhs.firstYear }
                    return (lhs.sovereignTitle ?? "") < (rhs.sovereignTitle ?? "")
                }

            return DynastyCatalogItem(
                dynasty: dynasty.dynasty,
                firstYear: dynasty.firstYear,
                lastYear: dynasty.lastYear,
                branches: sortBranches(dynasty.branches),
                sovereigns: sovereignItems,
                eras: eraItems
            )
        }
            .sorted { lhs, rhs in
                if lhs.firstYear != rhs.firstYear { return lhs.firstYear < rhs.firstYear }
                return lhs.dynasty < rhs.dynasty
            }
    }
}

public struct DefaultYearAssembler: YearAssembling {
    public init() {}

    public func assemble(
        rawYear: RawCalendarYear,
        solarTerms: [SolarTermEvent],
        eraNamesByDate: [GregorianDate: [EraName]]
    ) throws -> LunisolarYear {
        let solarTermMap = Dictionary(uniqueKeysWithValues: solarTerms.map { ($0.occursAt, $0) })
        let days = rawYear.days.map { day in
            CalendarDay(
                gregorian: day.gregorian,
                lunar: day.lunar,
                solarTerm: solarTermMap[day.gregorian],
                eraNames: eraNamesByDate[day.gregorian] ?? []
            )
        }
        return LunisolarYear(gregorianYear: rawYear.gregorianYear, branch: rawYear.branch, days: days)
    }
}

public enum ChineseCalendarFactory {
    public static func makeEngine() -> LunisolarEngine {
        let store = PrecomputedYearStore.shared
        let yearCalculator = PrecomputedYearCalculator(store: store)
        return LunisolarEngine(
            branchSelector: PrecomputedBranchSelector(),
            sunMoonProvider: PrecomputedSunMoonProvider(store: store),
            decompressor: NoopSunMoonDecompressor(),
            modernCalculator: yearCalculator,
            ancientCalculator: yearCalculator,
            splitCalculator: yearCalculator,
            solarTermResolver: PrecomputedSolarTermResolver(store: store),
            eraResolver: PrecomputedEraResolver(store: store),
            assembler: DefaultYearAssembler()
        )
    }
}

public enum LunisolarFactory {
    public static func makeSkeletonEngine() -> LunisolarEngine {
        ChineseCalendarFactory.makeEngine()
    }
}
