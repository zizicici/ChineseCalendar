#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const repoRoot = path.resolve(__dirname, "..", "..", "..");
const srcRoot = path.join(repoRoot, "src");
const outPath = path.join(__dirname, "..", "Sources", "ChineseCalendar", "Resources", "year_data.default.json");

const files = [
  "utilities.js",
  "decompressSunMoonData.js",
  "ancientCalendars.js",
  "split.js",
  "eras.js",
  "calendarData.js",
  "eclipse_linksM722-2202.js",
  "calendar.js"
];

const context = { console, Math };
vm.createContext(context);
for (const file of files) {
  const code = fs.readFileSync(path.join(srcRoot, file), "utf8");
  vm.runInContext(code, context, { filename: file });
}

function liForYear(year) {
    if (year < -479) return "Chunqiu";
    if (year < -220) return "Zhou";
    if (year === -220) return "Zhuanxu";
    return null;
}

const splitRegionConfigs = [
  { jsonKey: "shu", jsRegion: "Shu", isActive: (year) => year >= 221 && year <= 263 },
  { jsonKey: "wu", jsRegion: "Wu", isActive: (year) => year >= 222 && year <= 279 },
  { jsonKey: "laterQin", jsRegion: "LaterQin", isActive: (year) => year >= 384 && year <= 417 },
  { jsonKey: "northernLiang", jsRegion: "NorthernLiang", isActive: (year) => year >= 412 && year <= 439 },
  { jsonKey: "weiZhouSui", jsRegion: "WeiZhouSui", isActive: (year) => year >= 398 && year <= 590 },
  { jsonKey: "weiQi", jsRegion: "WeiQi", isActive: (year) => year >= 534 && year <= 577 },
  { jsonKey: "liaoJinYuan", jsRegion: "LiaoJinYuan", isActive: (year) => year >= 947 && year <= 1279 },
  { jsonKey: "southernMing", jsRegion: "SouthernMing", isActive: (year) => year >= 1645 && year <= 1683 }
];

const startYear = -721;
const endYear = 2200;
const years = [];

for (let year = startYear; year <= endYear; year++) {
  const li = liForYear(year);
  const langVars = { region: "default", li_ancient: li };
  const out = context.calDataYear(year, langVars);

  const era = context.eraName(year, "default", li);

  const solarMinutes = out.solar.map((v) => Math.round(v * 1440));
  const regionVariants = {};

  for (const config of splitRegionConfigs) {
    if (!config.isActive(year)) {
      continue;
    }
    const regionOut = context.calDataYear(year, { region: config.jsRegion, li_ancient: li });
    regionVariants[config.jsonKey] = {
      cD: regionOut.cmonthDate,
      cN: regionOut.cmonthNum,
      sM: regionOut.solar.map((v) => Math.round(v * 1440)),
      era: context.eraName(year, config.jsRegion, li)
    };
  }

  years.push({
    y: year,
    cD: out.cmonthDate,
    cN: out.cmonthNum,
    sM: solarMinutes,
    era,
    ...(Object.keys(regionVariants).length ? { r: regionVariants } : {})
  });
}

const payload = {
  meta: {
    source: "ChineseCalendar JS project",
    startYear,
    endYear,
    generatedAtUTC: new Date().toISOString()
  },
  years
};

fs.writeFileSync(outPath, JSON.stringify(payload));
console.log(`Wrote ${outPath} (${years.length} years)`);
