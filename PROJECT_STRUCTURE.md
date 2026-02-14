# ChineseCalendar 项目结构梳理

## 1. 项目定位

这是一个以静态站点为核心的历法项目，用于公历/农历转换、月相与节气查询、历法规则说明和历史历法研究页面展示。  
仓库采用“`src` 源文件 + 根目录构建产物”的组织方式。

说明：本次梳理**按要求未读取** `src/sunMoonData.js` 文件内容。

## 2. 顶层目录结构

```text
ChineseCalendar/
|- src/                  # 源码目录（HTML/CSS/JS/图片/文档）
|  |- docs/              # 源 PDF 文档
|  |- *.html             # 页面源文件（英文/繁中/简中）
|  |- *.js               # 业务逻辑与数据脚本
|  |- *.css              # 样式源文件
|  |- *.png/*.jpg        # 图片资源
|  `- protect_this_dir.txt
|- docs/                 # 构建后的文档目录（与 src/docs 对应）
|- build.js              # 构建脚本
|- build_config.json     # 局部构建配置
|- package.json          # npm 脚本与依赖
|- README.md             # 项目说明
|- LICENSE
|- *_c.js                # 组合压缩后的核心 JS 产物
|- *_min.css             # 压缩 CSS 产物
`- 大量 *.html/*.png/*.jpg  # 可直接部署的静态页面与资源
```

## 3. 构建体系

核心入口：

- `npm run build` -> `node build.js all`
- `npm run part` -> `node build.js`（按 `build_config.json` 的布尔开关局部构建）
- `npm run clean` -> `node build.js clean`

`build.js` 主要职责：

- 复制文档与图片资源（可按配置选择）
- 压缩 CSS：生成 `calendar_min.css`、`calendar_chinese_min.css`
- 压缩公共头脚本：生成 `header_min.js`
- 合并并压缩核心 JS：
- `index_c.js`（`header + utilities + calendar + calendarData + eclipse_linksM722-2202 + decompressSunMoonData + ancientCalendars + eras + split`）
- `table_c.js`（`header + utilities + calendarData + ancientCalendars + eras + split + table`）
- `sunMoon_c.js`（`header + decompressSunMoonData + sunMoon + sunMoonData + eclipse_linksM3502-3503 + utilities`）
- `Julian_c.js`（`header + Julian`）
- 对 HTML 做替换和压缩：
- 入口页类文件会注入对应 `*_c.js`
- 其他页面会将 `calendar*.css` 换成 `*_min.css`，并将 `header.js` 换成 `header_min.js`
- 通过 `protect_this_dir.txt` 防止把输出目录误指向源码目录

## 4. `src` 核心脚本分层

公共层：

- `src/header.js`：站点菜单、语言切换、页脚
- `src/utilities.js`：儒略日、历法基础工具函数

主功能页：

- `src/calendar.js`：年历主页面逻辑（`index*.html`）
- `src/table.js`：朔闰表和分时期表格逻辑（`table*.html` / `table_period*.html`）
- `src/sunMoon.js`：月相与二十四节气页面（`sunMoon*.html`）
- `src/Julian.js`：儒略日与干支日期计算器（`Julian*.html`）

历法扩展与历史数据支持：

- `src/ancientCalendars.js`：先秦与早期历法处理
- `src/split.js`：分裂时期（三国、南北朝、宋辽金元、明清交替）历法切换与修正
- `src/eras.js`：年号/纪年名称
- `src/calendarData.js`：-721 到 2200 区间核心历法数据
- `src/decompressSunMoonData.js`：月相/节气压缩数据解码与 Delta T 相关函数
- `src/eclipse_linksM722-2202.js`、`src/eclipse_linksM3502-3503.js`：食象链接数据
- `src/simpleQuiz.js`：历法测验页面脚本

## 5. 页面组织方式

页面命名采用三语并行：

- 英文主文件：如 `index.html`
- 繁体中文：如 `index_chinese.html`
- 简体中文：如 `index_simp.html`

主要页面簇：

- 转换与查询：`index*`、`table*`、`table_period*`、`sunMoon*`、`Julian*`
- 历法基础说明：`solarTerms*`、`sexagenary*`、`rules*`
- 计算与方法：`computation*`、`examples*`、`rules_demysterified*`
- 历史专题：`chunqiu*`、`guliuli*`、`QinHanCalendars*`、`MingCalendar*`、`ThreeKingdoms_calendars*`、`NorthSouth_calendars*` 等
- 其它：`faq*`、`others*`、`simpleQuiz*`、`era_names*`

## 6. 源文件与产物关系

该仓库同时保留源码与构建产物：

- `src/`：开发与维护入口（建议在这里修改）
- 根目录：压缩后可发布文件（可直接用于静态部署）

因此你会看到许多同名页面和资源在 `src/` 与根目录同时存在，这是当前项目的设计结果，不是重复误提交。

