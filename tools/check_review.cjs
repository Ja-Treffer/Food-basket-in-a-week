// 校验 review.html（纯衍生题·计分版）
//   node tools/check_review.cjs     退出码 0 = 全绿；2 = 有问题
// 不校验长度偏置：衍生题的正确项本来就是「说出机制」的长句，长短不构成暗示。
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const file = path.join(__dirname, '..', 'review.html');
const html = fs.readFileSync(file, 'utf8');

const bad = [];
const say = (s) => console.log(s);

/* ---------- 1. 取出题库 ---------- */
const src = html.match(/var Q = (\[[\s\S]*?\n  \]);/);
if (!src) {
  console.log('❌ 找不到 var Q = [...]');
  process.exit(2);
}
const Q = vm.runInNewContext('(' + src[1] + ')');
const TAKE = Number((html.match(/var TAKE = (\d+);/) || [])[1] || 0);

say('题库：' + Q.length + ' 题　每次抽：' + TAKE + ' 题');

/* ---------- 2. 逐题体检 ---------- */
const len = (s) => String(s).replace(/\s/g, '').length;
let shapeBad = 0, tagBad = 0, slotBad = 0;

Q.forEach((q) => {
  const four = q.o.length === 4;
  const tri = q.t.length === 3 && q.why.length === 3 &&
              q.o.every((o) => o.length === 3) &&
              q.x.every((x) => x.length === 3);
  const dupZh = new Set(q.o.map((o) => o[0])).size === 4;
  const dupEn = new Set(q.o.map((o) => o[2].toLowerCase())).size === 4;

  const tags = Array.isArray(q.tag) ? q.tag : [];
  const tagOk = tags.length === 4 &&
    tags.every((t) => ['mech', 'slogan', 'wrong'].includes(t)) &&
    tags.filter((t) => t === 'mech').length >= 1 &&
    tags.includes('slogan') &&
    ['mech', 'slogan'].includes(tags[q.a]);

  const slotOk = q.x.filter((x, k) => k !== q.a && String(x[0]).trim()).length === 3 &&
                 !String(q.x[q.a][0]).trim();

  if (!four || !tri || !dupZh || !dupEn) shapeBad++;
  if (!tagOk) tagBad++;
  if (!slotOk) slotBad++;
});

say('结构：选项数 / 三语 / 去重　' + (shapeBad ? '❌ ' + shapeBad + ' 题' : '✓'));
if (shapeBad) bad.push('shape');
say('标签：机制 / 口号 / 说不通　' + (tagBad ? '❌ ' + tagBad + ' 题' : '✓'));
if (tagBad) bad.push('tag');
say('辨析：三条错项各有说明、答案项留空　' + (slotBad ? '❌ ' + slotBad + ' 题' : '✓'));
if (slotBad) bad.push('slot');

/* ---------- 3. 答案位置分布 ---------- */
const dist = [0, 0, 0, 0];
Q.forEach((q) => dist[q.a]++);
say('\n答案位置 A/B/C/D：' + dist.join(' / '));
if (dist.some((x) => x < 2)) { say('❌ 某一位少于 2 次，答案位置有规律'); bad.push('dist'); }

/* ---------- 4. 抽样模拟 ---------- */
const shuffle = (a) => {
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
};
let simBad = 0;
for (let t = 0; t < 2000; t++) {
  const idx = shuffle(Q.map((_, i) => i)).slice(0, TAKE);
  if (idx.length !== TAKE || new Set(idx).size !== TAKE) simBad++;
}
say(`抽样模拟 2000 次：异常 ${simBad} 次` + (simBad ? ' ❌' : ' ✓'));
if (simBad) bad.push('draw');

/* ---------- 5. 结构 ---------- */
const struct = [
  ['没有前置说明段', !/class="(lead|nores|pull)"/.test(html)],
  ['进度按 ' + TAKE + ' 题显示', new RegExp('已核对 <b>0</b> / ' + TAKE).test(html)],
  ['显示答对题数', /score:\[/.test(html)],
  ['有换一套按钮', /id="drawBtn"/.test(html)],
  ['有计分判定语', /okMsg:\[/.test(html) && /badMsg:\[/.test(html)],
  ['无外链与联网', !/https?:\/\/(?!www\.w3\.org)|fetch\(|XMLHttpRequest/.test(html)],
  ['有三语下拉', /id="lang"[\s\S]{0,200}<option value="0">/.test(html)],
  ['有 ?lang= 解析', /lang=/.test(html)],
  ['语言写入 localStorage', /cailan\.review\.lang/.test(html)],
  ['切语言重建题面', /langSel\.addEventListener\("change"/.test(html)],
];
say('');
struct.forEach(([name, ok]) => { say((ok ? '✓ ' : '❌ ') + name); if (!ok) bad.push(name); });

/* ---------- 6. 禁用词：判优措辞不许回来 ---------- */
const bans = ['数值后置', '设计参数', '元游戏', '排名', '评级', '最准确', '最稳', '为什么这样设计'];
const hit = bans.filter((w) => html.includes(w));
say('\n禁用词命中：' + (hit.length ? hit.join(',') : '无'));
if (hit.length) bad.push('ban');

/* ---------- 结论 ---------- */
say('\n' + (bad.length ? '❌ 不合格：' + bad.join(',') : '✓ 全部通过'));
process.exit(bad.length ? 2 : 0);
