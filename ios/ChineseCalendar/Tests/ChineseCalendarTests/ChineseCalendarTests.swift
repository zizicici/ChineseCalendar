import XCTest
@testable import ChineseCalendar

final class ChineseCalendarTests: XCTestCase {
    func testYearQueryReturnsData() throws {
        let service = DefaultChineseCalendarService()
        let results = try service.year(2024)
        let result = try XCTUnwrap(results.first)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(result.gregorianYear, 2024)
        XCTAssertEqual(result.branch, .modern)
        XCTAssertEqual(result.days.count, 366)
    }

    func testDayAndMonthQuery() throws {
        let service = DefaultChineseCalendarService()

        let dayResults = try service.day(2024, 2, 29)
        let day = try XCTUnwrap(dayResults.first(where: { $0.branch == .modern })?.day)
        XCTAssertEqual(dayResults.count, 1)
        XCTAssertEqual(day.gregorian.year, 2024)
        XCTAssertEqual(day.gregorian.month, 2)
        XCTAssertEqual(day.gregorian.day, 29)
        XCTAssertEqual(day.lunar?.month, 1)
        XCTAssertEqual(day.lunar?.day, 20)

        let monthResults = try service.month(2024, 2)
        let month = try XCTUnwrap(monthResults.first(where: { $0.branch == .modern }))
        XCTAssertEqual(monthResults.count, 1)
        XCTAssertEqual(month.gregorianYear, 2024)
        XCTAssertEqual(month.gregorianMonth, 2)
        XCTAssertEqual(month.days.count, 29)
    }

    func testQueryEnum() throws {
        let service = DefaultChineseCalendarService()
        let result = try service.query(.day(year: 2024, month: 1, day: 1))

        switch result {
        case let .days(days):
            let day = try XCTUnwrap(days.first(where: { $0.branch == .modern })?.day)
            XCTAssertEqual(day.gregorian.month, 1)
            XCTAssertEqual(day.gregorian.day, 1)
        default:
            XCTFail("Expected days result")
        }
    }

    func testHistoricalEra() throws {
        let service = DefaultChineseCalendarService()
        let day = try service.day(-300, 1, 1, branch: .modern)
        let era = try XCTUnwrap(day.eraNames.first)

        XCTAssertFalse(era.dynasty.isEmpty)
    }

    func testEraIsSplitIntoOwnerEraAndYear() throws {
        let service = DefaultChineseCalendarService()
        let day = try service.day(1779, 1, 1, branch: .modern)
        let era = try XCTUnwrap(day.eraNames.first)

        XCTAssertEqual(era.sovereignTitle, "清高宗")
        XCTAssertEqual(era.eraName, "乾隆")
        XCTAssertEqual(era.regnalYear, 44)
        XCTAssertEqual(era.reignTitle, "乾隆")
        XCTAssertEqual(era.dynasty, "清")
    }

    func testSplitRegionBranchCanBeQueriedFromPrecomputedData() throws {
        let service = DefaultChineseCalendarService()

        let defaultResults = try service.day(238, 1, 1)
        let defaultDay = try XCTUnwrap(defaultResults.first(where: { $0.branch == .modern })?.day)
        XCTAssertEqual(defaultResults.count, 3)
        XCTAssertTrue(defaultResults.contains(where: { $0.branch == .splitRegion(.shu) }))
        XCTAssertTrue(defaultResults.contains(where: { $0.branch == .splitRegion(.wu) }))

        let wuDay = try service.day(
            238,
            1,
            1,
            branch: .splitRegion(.wu)
        )

        XCTAssertEqual(defaultDay.eraNames.first?.dynasty, "魏")
        XCTAssertEqual(wuDay.eraNames.first?.dynasty, "吳")
        XCTAssertNotEqual(defaultDay.lunar?.month, wuDay.lunar?.month)

        let allYears = try service.year(238)
        XCTAssertEqual(allYears.count, 3)
        XCTAssertTrue(allYears.contains(where: { $0.branch == .modern }))
        XCTAssertTrue(allYears.contains(where: { $0.branch == .splitRegion(.shu) }))
        XCTAssertTrue(allYears.contains(where: { $0.branch == .splitRegion(.wu) }))

        let wuYear = try service.year(238, branch: .splitRegion(.wu))
        XCTAssertEqual(wuYear.branch, .splitRegion(.wu))
    }

    func testInvalidMonthThrows() {
        let service = DefaultChineseCalendarService()
        XCTAssertThrowsError(try service.month(2024, 13)) { error in
            XCTAssertEqual(error as? LunisolarError, .invalidGregorianMonth(13))
        }
    }

    func testUnsupportedYearThrows() {
        let service = DefaultChineseCalendarService()
        XCTAssertThrowsError(try service.year(3000)) { error in
            XCTAssertEqual(error as? LunisolarError, .unsupportedYear(3000))
        }
    }

    func testUnsupportedSplitBranchForYearThrows() {
        let service = DefaultChineseCalendarService()
        XCTAssertThrowsError(
            try service.year(2024, branch: .splitRegion(.wu))
        ) { error in
            XCTAssertEqual(
                error as? LunisolarError,
                .unsupportedBranchForYear(year: 2024, branch: .splitRegion(.wu))
            )
        }
    }

    func testDynastyCatalogIncludesSovereignAndEra() throws {
        let service = DefaultChineseCalendarService()
        let dynasties = try service.dynasties()

        let qing = try XCTUnwrap(dynasties.first(where: { $0.dynasty == "清" }))
        let qianlongSovereign = try XCTUnwrap(
            qing.sovereigns.first(where: { $0.sovereignTitle == "清高宗" })
        )
        XCTAssertTrue(qianlongSovereign.eras.contains(where: { $0.eraName == "乾隆" }))
    }

    func testDynastyCatalogSupportsBranchFilter() throws {
        let service = DefaultChineseCalendarService()
        let laterQin = try service.dynasty(
            "後秦",
            branch: .splitRegion(.laterQin)
        )

        let dynasty = try XCTUnwrap(laterQin)
        XCTAssertEqual(dynasty.dynasty, "後秦")
        XCTAssertFalse(dynasty.sovereigns.isEmpty)
    }
}
