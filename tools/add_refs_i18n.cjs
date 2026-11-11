// 给 22 条参考资料补英文：{zh: 原文, tw: 原文, en: 译}
// 原文多为繁体引文，tw 保持原样（面板里会标注「原文」）。
const fs = require("fs");

const EN = {
	H1: "Centre for Health Protection, \u201cKey points on a balanced vegetarian diet\u201d: \u201cvegetarian is not automatically healthy\u201d; \u201cplant foods do supply protein, but of lower quality than meat and dairy\u201d; \u201cno plant food has been shown to provide B12 safely and effectively\u2026 vegans should take B12-fortified products\u201d; \u201cvegetarians are especially prone to iron deficiency\u2026 eat vitamin-C rich foods to help absorption\u201d; calcium sources include \u201cfirm tofu, calcium-fortified soy milk and dark green vegetables\u201d. [Text verified]",
	H2: "Same page: \u201cuse steaming, braising, stewing or blanching instead of frying\u201d; \u201csoy products (tofu, bean curd sticks, dried tofu)\u2026 to lift the savoury taste\u201d. [Text verified]",
	H3: "AFCD, \u201cAbout Fisheries\u201d: \u201cthe government\u2019s fisheries policy aims to conserve local fishery resources and promote sustainable development, so that local consumers have a stable supply of fresh fish\u201d; also the \u201cAccredited Fish Farm Scheme\u201d. [Search snippet verified]",
	H4: "Poore & Nemecek (2018), Science 360:987\u2013992, via Our World in Data: kgCO\u2082eq per kg, data year 2010; supports the direction \u201cwhite meat and pulses sit below ruminant red meat\u201d. TODO(verify): per-item values not read, so no kg figures are quoted.",
	E1: "EDB curriculum pages list \u201cTechnology and Living (S4\u2013S6)\u201d and \u201cHealth Management and Social Care\u201d guides. TODO(verify): exact strand names to be checked in the PDF.",
	R1: "IPCC AR6 WGIII Ch5: demand-side strategies could cut emissions by 40\u201370% by 2050 (high confidence). [Verified]",
	R2: "Same chapter: the largest Avoid is long-haul aviation, the largest Shift is plant-based diets, the largest Improve is building efficiency. [Verified]",
	R3: "Same chapter: car-free travel plus electrification is on the order of 2 tCO\u2082eq per person per year. [Verified; converted to a relative scale]",
	R4: "Same chapter: decent living standards and well-being are achievable on low-demand pathways. [Verified]",
	R5: "Same chapter: sharing and the circular economy contribute modestly; the gain is claimed on \u201climited evidence\u201d. [Verified]",
	R6: "Same chapter\u2019s high-potential actions include adjusting air-conditioning set points, shifting to public transport and cutting appliance use. [Verified]",
	R7: "Rebound effect: money saved is spent elsewhere and offsets part of the reduction. TODO(verify): source text and percentage not obtained.",
	R8: "Wynes & Nicholas (2017), Environ. Res. Lett. 12:074024: textbooks favour low-impact actions that do not match the high-impact ones. TODO(verify).",
	R9: "Critiques of the personal-carbon-footprint frame, and the replies. TODO(verify): neither side read in full, so advocacy is scored as a probability.",
	F1: "Fabric life cycle (fibre, wash temperature, number of wears, microfibres). TODO(verify): no primary data obtained; fabric items give direction only and are marked C.",
	D1: "Design parameter: a 0\u2013100 relative scale; direction comes from the sources, magnitude is a teaching mapping \u2014 not emission factors, nutrient values or HKD.",
	D2: "Design parameter: the width of a fuzzy range shows how far the outcome depends on conditions (origin, transport, certification, household habits).",
	D3: "Design parameter: taste/acceptance falling below a threshold triggers \u201ceating out\u201d \u2014 a plan the family will not keep does not last.",
	D4: "Design parameter: rebound coefficient.",
	D5: "Design parameter: advocacy is scored as a probability, not a fixed number of points.",
	D6: "Design parameter: delayed settlement, to stage a cost that was invisible when the choice was made.",
	D7: "Design parameter: every number is withheld \u2014 no reading is shown while choosing, and all of it is explained on settlement day.",
};

const game = JSON.parse(fs.readFileSync("godot/data/game.json", "utf8"));
const refs = game.refs || game.REF || {};
const dictPath = "data/game-i18n.json";
const rows = JSON.parse(fs.readFileSync(dictPath, "utf8"));

let added = 0, updated = 0;
for (const code of Object.keys(EN)) {
	const zh = String(refs[code] || "");
	if (!zh) { console.log("MISSING ref", code); continue; }
	const hit = rows.find((r) => r.zh === zh);
	if (hit) { hit.tw = zh; hit.en = EN[code]; updated++; }
	else { rows.push({ zh, tw: zh, en: EN[code] }); added++; }
}
fs.writeFileSync(dictPath, JSON.stringify(rows, null, 1), "utf8");
console.log("added", added, "updated", updated, "total", rows.length);
