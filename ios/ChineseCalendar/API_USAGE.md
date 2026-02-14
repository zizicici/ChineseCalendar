# ChineseCalendar API 使用说明

本文说明 `ChineseCalendar` iOS/Swift Package 的主要 API 用法。

## 1. 初始化

```swift
import ChineseCalendar

let service = DefaultChineseCalendarService()
```

## 2. 查询入口

### 2.1 查某一天

```swift
let days = try service.day(2024, 2, 10)
```

返回 `[BranchedCalendarDay]`。每条结果包含：

- `branch`：该条结果对应的分支
- `day`：`CalendarDay`

`CalendarDay` 主要字段：

- `gregorian`：公历日期
- `lunar`：农历（月、日、闰月）
- `solarTerm`：若当天是节气，则有值
- `eraNames`：当天对应历史年号信息（可多条）

### 2.2 查某个月

```swift
let months = try service.month(2024, 2)
```

返回 `[LunisolarMonth]`。每个元素包含：

- `gregorianYear`
- `gregorianMonth`
- `branch`
- `days`（该月所有 `CalendarDay`）

### 2.3 查某一年

```swift
let years = try service.year(2024)
```

返回 `[LunisolarYear]`。每个元素包含：

- `gregorianYear`
- `branch`
- `days`（全年所有 `CalendarDay`）

### 2.4 使用 `query` 枚举

```swift
let result = try service.query(.day(year: 2024, month: 2, day: 10))

switch result {
case .days(let days):
    print(days.count)
case .months(let months):
    print(months.count)
case .years(let years):
    print(years.count)
}
```

说明：`query` 不带 `branch` 参数，返回该年份下所有可用分支的结果。

## 3. 输出说明

当前输出统一为繁体文本（多语言参数已移除）。

## 4. 指定历法分支与并行口径

默认不传 `branch` 时，会返回该年份的所有可用分支结果。

```swift
let wuDay = try service.day(238, 1, 1, branch: .splitRegion(.wu))
let southernMingYear = try service.year(1660, branch: .splitRegion(.southernMing))
```

说明：`branch` 重载返回单分支结果，方便你在并行口径里只取某一支。

`CalendarBranch`：

- `.modern`
- `.ancient`
- `.splitRegion(RegionCalendar)`

`RegionCalendar` 可选值：

- `.shu`
- `.wu`
- `.laterQin`
- `.northernLiang`
- `.weiZhouSui`
- `.weiQi`
- `.liaoJinYuan`
- `.southernMing`

## 5. 分裂时期并行口径覆盖范围

当前预计算数据中，按下列年份区间提供并行口径：

- `shu`: 221...263
- `wu`: 222...279
- `laterQin`: 384...417
- `northernLiang`: 412...439
- `weiZhouSui`: 398...590
- `weiQi`: 534...577
- `liaoJinYuan`: 947...1279
- `southernMing`: 1645...1683

如果某年不支持你指定的 `branch`，会抛出：

- `LunisolarError.unsupportedBranchForYear(year:branch:)`

## 6. 年号字段读取

每个 `CalendarDay` 的 `eraNames` 是 `[EraName]`，常用字段：

- `dynasty`：朝代
- `sovereignTitle`：君主号（如“清高宗”）
- `eraName`：年号（如“乾隆”）
- `regnalYear`：纪年数字（如 `44`）
- `reignTitle`：展示用主名称
- `periodLabel`：附加标签（如原数据中的分段标签）
- `rawText` / `displayText`：原始文本

示例：

```swift
let day = try service.day(1779, 1, 1, branch: .modern)
if let era = day.eraNames.first {
    print(era.sovereignTitle ?? "") // 清高宗
    print(era.eraName ?? "")        // 乾隆
    print(era.regnalYear)           // 44
}
```

## 7. 错误处理

常见错误：

- `unsupportedYear(Int)`
- `unsupportedBranchForYear(year:branch:)`
- `invalidGregorianMonth(Int)`
- `invalidGregorianDay(year:month:day:)`

建议统一用 `do/catch`：

```swift
do {
    let days = try service.day(2024, 2, 30)
    print(days.count)
} catch let error as LunisolarError {
    print("Calendar error: \\(error)")
} catch {
    print("Unknown error: \\(error)")
}
```

## 8. 朝代目录 API（朝代 -> 君主 -> 年号）

如果你要做“浏览历史资料”而不是按日期查某一天，可直接用目录接口：

```swift
let dynasties = try service.dynasties()
```

返回 `[DynastyCatalogItem]`，每个朝代对象包含：

- `dynasty`
- `firstYear` / `lastYear`
- `branches`
- `sovereigns`（每个君主下有 `eras`）
- `eras`（该朝代下聚合的全部年号）

只看某个并行口径（例如吴）：

```swift
let wuCatalog = try service.dynasties(
    branch: .splitRegion(.wu)
)
```

查某个朝代：

```swift
let qing = try service.dynasty(
    "清",
    branch: nil
)
```
