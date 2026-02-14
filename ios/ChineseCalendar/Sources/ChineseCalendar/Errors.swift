public enum LunisolarError: Error, Equatable {
    case unsupportedYear(Int)
    case missingCompressedSunMoonData(Int)
    case missingCalculator(CalendarBranch)
    case unsupportedBranchForYear(year: Int, branch: CalendarBranch)
    case invalidGregorianMonth(Int)
    case invalidGregorianDay(year: Int, month: Int, day: Int)
    case dayNotFound(GregorianDate)
    case assemblyFailed(String)
    case notImplemented(String)
}

public typealias ChineseCalendarError = LunisolarError
