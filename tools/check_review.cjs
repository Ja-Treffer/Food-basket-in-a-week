// 校验 review.html：题库规模、长度偏置、正确项位置、解释完整性、分层抽样、三语完整性
// 用法： node tools/check_review.cjs   （退出码 2 = 不合格）
const fs = require('fs');
const path = require('path');

const file = path.join(__dirname, '..', 'review.html');
const html = fs.readFileSync(file, 'utf8');

const TAKE = 6;
const ORDER = ['A', 'B', 'C', 'D'];
const LANGS = ['zh', 'tw', 'en'];
const bad = [];
const say = (s) => console.log(s);

/* ---------- 1. 抽出题库 ---------- */
const m = html.match(/var Q = (\[[\s\S]*?\n  \]);/);
if (!m) { console.error('❌ 没找到 Q 数组'); process.exit(1); }
const Q = new Function('return ' + m[1])();

/* ---------- 2. 抽出真实的 drawSet，而不是复制一份算法 ---------- */
function extractFn(src, name) {
  const start = src.indexOf('function ' + name + '(');
  if (start < 0) return null;
  let i = src.indexOf('{', start), depth = 0;
  for (let j = i; j < src.length; j++) {
    if (src[j] === '{') depth++;
    else if (src[j] === '}') { depth--; if (!depth) return src.slice(start, j + 1); }
  }
  return null;
}
const srcShuffle = extractFn(html, 'shuffle');
const srcDraw = extractFn(html, 'drawSet');
if (!srcShuffle || !srcDraw) { console.error('❌ 没找到 shuffle / drawSet'); process.exit(1); }

let curRnd = Math.random;
const makeDrawSet = new Function('RND', 'Q', 'ORDER', 'TAKE',
  srcShuffle + '\n' + srcDraw + '\nreturn drawSet;');
const drawSet = makeDrawSet(function () { return curRnd(); }, Q, ORDER, TAKE);

/* ---------- 3. 三语完整性 ---------- */
const isTri = (v) => Array.isArray(v) && v.length === 3 && v.every((s) => typeof s === 'string');
let langBad = 0;
Q.forEach((q, i) => {
  const miss = [];
  if (!isTri(q.t)) miss.push('t');
  q.o.forEach((o, k) => { if (!isTri(o)) miss.push('o' + k); });
  if (!isTri(q.why)) miss.push('why');
  q.x.forEach((x, k) => { if (!isTri(x)) miss.push('x' + k); });
  Q[i].o.forEach((o, k) => LANGS.forEach((lg, li) => { if (!o[li].trim()) miss.push('o' + k + '.' + lg); }));
  LANGS.forEach((lg, li) => {
    if (!q.t[li].trim()) miss.push('t.' + lg);
    if (!q.why[li].trim()) miss.push('why.' + lg);
  });
  q.x.forEach((x, k) => LANGS.forEach((lg, li) => {
    const shouldHave = (k !== q.a) && (li >= 0);
    if (shouldHave && !x[li].trim()) miss.push('x' + k + '.' + lg);
    if (k === q.a && x[li].trim()) miss.push('x' + k + '.' + lg + '(正确项应留空)');
  }));
  if (miss.length) { langBad++; say('❌ Q' + (i + 1) + ' 三语缺: ' + [...new Set(miss)].join(',')); }
});
say('三语完整性: ' + (langBad ? langBad + ' 题不合格 ❌' : '10 题 × 3 语齐全 ✓'));
if (langBad) bad.push('i18n');

/* ---------- 4. 逐题体检（长度偏置只对简体中文判定） ---------- */
const len = (s) => String(s).replace(/\s/g, '').length;
const words = (s) => String(s).trim().split(/\s+/).length;
const rows = [];
Q.forEach((q, i) => {
  const zh = q.o.map((o) => o[0]);
  const en = q.o.map((o) => o[2]);
  const tw = q.o.map((o) => o[1]);

  const L = zh.map(len);
  const max = Math.max(...L), min = Math.min(...L);
  const ratio = max / min;
  const cLen = L[q.a];
  const longestIsCorrect = cLen === max && L.filter((x) => x === max).length === 1;
  const shortestIsCorrect = cLen === min && L.filter((x) => x === min).length === 1;
  const outOfRange = L.some((x) => x < 12 || x > 22);
  const optCount = q.o.length !== 4;
  const dupZh = new Set(zh).size !== 4;
  const dupEn = new Set(en.map((s) => s.toLowerCase())).size !== 4;

  const enW = en.map(words);
  const enRatio = Math.max(...enW) / Math.min(...enW);
  const enTooShort = enW.some((x) => x < 5);

  const twDrift = tw.map((s, k) => Math.abs(len(s) - L[k]));
  const twBad = twDrift.some((d) => d > 3);

  const xOk = q.x.filter((s, k) => k !== q.a && String(s[0]).trim()).length === 3 && !String(q.x[q.a][0]).trim();

  // 衍生题考的是理由，机制本身就该长一点，长度偏置规则不适用；
  // 改判它有没有把「机制 / 口号 / 说不通」三种角色都摆进去。
  const isDerive = q.kind === 'derive';
  const tagOk = !isDerive || (
    Array.isArray(q.tag) && q.tag.length === 4 &&
    q.tag.every((t) => ['mech', 'slogan', 'wrong'].includes(t)) &&
    q.tag.filter((t) => t === 'mech').length >= 1 &&
    q.tag.includes('slogan') && ['mech', 'slogan'].includes(q.tag[q.a])
  );
  const ok = (isDerive
      ? (!optCount && !dupZh && !dupEn && xOk && tagOk)
      : (ratio <= 1.5 && !longestIsCorrect && !shortestIsCorrect && !outOfRange &&
         !optCount && !dupZh && !dupEn && !enTooShort && enRatio <= 2.2 && !twBad && xOk));
  if (!ok) bad.push('Q' + (i + 1));
  rows.push({ n: i + 1, g: q.g, a: 'ABCD'[q.a], L, ratio, cLen, isDerive, tagOk, longestIsCorrect, shortestIsCorrect,
              outOfRange, optCount, dupZh, dupEn, enRatio, enTooShort, twBad, xOk });
});

say('题库题数: ' + Q.length + (Q.length === 21 ? ' ✓（15 情景 + 6 衍生）' : ' ❌ 应为 21'));
if (Q.length !== 21) bad.push('size');

rows.forEach((r) => {
  say(
    `Q${String(r.n).padStart(2, '0')} ${r.g} 答案${r.a} 中文字数[${r.L.join(',')}] ` +
    `最长/最短=${r.ratio.toFixed(2)} 英文词比=${r.enRatio.toFixed(2)}` +
    (!r.isDerive && r.longestIsCorrect ? ' ❌正确项唯一最长' : '') +
    (!r.isDerive && r.shortestIsCorrect ? ' ❌正确项唯一最短' : '') +
    (r.isDerive ? ' [衍生]' : '') +
    (r.outOfRange && !r.isDerive ? ' ❌字数越界(12-22)' : '') +
    (!r.tagOk ? ' ❌标签不全' : '') +
    (r.optCount ? ' ❌选项数≠4' : '') +
    (r.dupZh ? ' ❌中文选项重复' : '') +
    (r.dupEn ? ' ❌英文选项重复' : '') +
    (!r.isDerive && r.enTooShort ? ' ❌英文选项过短' : '') +
    (!r.isDerive && r.enRatio > 2.2 ? ' ❌英文长度差过大' : '') +
    (!r.isDerive && r.twBad ? ' ❌繁体字数漂移' : '') +
    (!r.xOk ? ' ❌辨析缺项' : '')
  );
});

/* ---------- 5. 正确项位置分布 ---------- */
const dist = [0, 0, 0, 0];
Q.forEach((q) => dist[q.a]++);
say('\n正确项位置分布 A/B/C/D: ' + dist.join(' / ') + '  (共 ' + Q.length + ')');
if (dist.some((x) => x < 2)) { say('❌ 某一位出现少于 2 次，位置有规律'); bad.push('dist'); }

/* ---------- 6. 分组覆盖 ---------- */
const byG = {};
Q.forEach((q) => { byG[q.g] = (byG[q.g] || 0) + 1; });
say('分组题量: ' + ORDER.map((g) => g + (byG[g] || 0)).join(' '));
ORDER.forEach((g) => { if (!byG[g]) { say('❌ 缺组 ' + g); bad.push('g' + g); } });

/* ---------- 7. 分层抽样模拟 ---------- */
const N = 2000;
let simBad = 0, shape = {};
for (let t = 0; t < N; t++) {
  curRnd = Math.random;
  const set = drawSet();
  const key = set.map((i) => Q[i].g).sort().join('');
  shape[key] = (shape[key] || 0) + 1;
  const uniq = new Set(set).size === TAKE;
  const groupOk = ['A','B','C','D'].every((g) => set.some((i) => Q[i].g === g)) &&
                   set.filter((i) => Q[i].g === 'E').length === 2;
  const inRange = set.every((i) => Number.isInteger(i) && i >= 0 && i < Q.length);
  if (!uniq || !groupOk || !inRange || set.length !== TAKE) simBad++;
}
say(`\n抽样模拟 ${N} 次: 异常 ${simBad} 次` + (simBad ? ' ❌' : ` ✓（每次 ${TAKE} 题、不重复、四组齐全）`));
if (simBad) bad.push('draw');
say('抽样组型分布: ' + Object.entries(shape).map(([k, v]) => k + '×' + v).join('  ') + '（固定 = 四组各一 + 两条衍生）');

/* ---------- 8. 结构检查 ---------- */
const struct = [
  ['没有前置说明段', !/class="(lead|nores|pull)"/.test(html)],
  ['没有开放题区块', !/class="open"|开放题/.test(html)],
  ['进度按 '+TAKE+' 题显示', new RegExp('已核对 <b>0</b> / '+TAKE).test(html)],
  ['有换一套按钮', /id="drawBtn"/.test(html)],
  ['不显示答对数', !/答对\s*\d|答对</.test(html)],
  ['无外链与联网', !/https?:\/\/(?!www\.w3\.org)|fetch\(|XMLHttpRequest/.test(html)],
  ['有三语下拉', /id="lang"[\s\S]{0,200}<option value="0">[\s\S]{0,80}<option value="1">[\s\S]{0,80}<option value="2">/.test(html)],
  ['有 ?lang= 解析', /\[?&\]lang=/.test(html) || /lang=\(\[\^&\]\+\)/.test(html)],
  ['语言写入 localStorage', /cailan\.review\.lang/.test(html)],
  ['切语言重建题面', /langSel\.addEventListener\("change"/.test(html)],
];
say('');
struct.forEach(([name, ok]) => { say((ok ? '✓ ' : '❌ ') + name); if (!ok) bad.push(name); });

/* ---------- 9. 禁用词（只查中文正文，不查 CSS 与注释） ---------- */
const bans = ['数值后置', '设计参数', '元游戏', '评分', '答对', '排名', '评级', '得分', '为什么这样设计'];
const hit = bans.filter((w) => html.includes(w));
say('禁用词命中: ' + (hit.length ? hit.join(',') : '无'));
if (hit.length) bad.push('ban');

/* ---------- 结论 ---------- */
say('\n' + (bad.length ? '❌ 不合格: ' + bad.join(',') : '✓ 全部通过'));
process.exit(bad.length ? 2 : 0);
