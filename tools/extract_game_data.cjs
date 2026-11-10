/* 从 src/game.template.html 抽出 CFG / REF / TASKS / LONG / EVENTS，写成 godot/data/game.json。
   用法：node tools/extract_game_data.cjs
   单一事实来源仍是模板：改任务先改模板，再跑这个脚本。 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.join(__dirname, '..');
const SRC = path.join(ROOT, 'src', 'game.template.html');
const OUT = path.join(ROOT, 'godot', 'data', 'game.json');

const html = fs.readFileSync(SRC, 'utf8');

/* 找出 `var NAME=` 到下一个顶层 `;` 之间的源码。 */
function grab(name) {
  const tag = 'var ' + name + '=';
  const at = html.indexOf(tag);
  if (at < 0) throw new Error('找不到 ' + tag);
  let i = at + tag.length;
  let depth = 0, inStr = null, esc = false;
  for (; i < html.length; i++) {
    const ch = html[i];
    if (inStr) {
      if (esc) { esc = false; continue; }
      if (ch === '\\') { esc = true; continue; }
      if (ch === inStr) inStr = null;
      continue;
    }
    if (ch === '"' || ch === "'" || ch === '`') { inStr = ch; continue; }
    if (ch === '{' || ch === '[' || ch === '(') depth++;
    else if (ch === '}' || ch === ']' || ch === ')') depth--;
    else if (ch === ';' && depth === 0) break;
  }
  return html.slice(at + tag.length, i);
}

const sandbox = { Math, JSON };
vm.createContext(sandbox);

function evalSrc(src, names) {
  // 这几个字面量互相引用（TASKS 里用 o() 构造选项），所以整段一起求值
  const code = src.join('\n') + '\n;' + names.map(n => `out.${n}=${n};`).join('');
  const wrapped = `var out={};\n${code}\nreturn out;`;
  return vm.runInContext('(function(){' + wrapped + '})()', sandbox);
}

const parts = ['CFG', 'REF', 'TASKS', 'LONG', 'EVENTS'].map(name => 'var ' + name + '=' + grab(name) + ';');
/* 模板里 o() 是全局小工具（用来造选项对象），单独抽出来一起求值 */
let helper = '';
const oAt = html.indexOf('function o(');
if (oAt >= 0) {
  let i = oAt, depth = 0;
  for (; i < html.length; i++) {
    if (html[i] === '{') depth++;
    else if (html[i] === '}') { depth--; if (depth === 0) { i++; break; } }
  }
  helper = html.slice(oAt, i);
}

const got = evalSrc([helper].concat(parts), ['CFG', 'REF', 'TASKS', 'LONG', 'EVENTS']);

const out = {
  v: 2,
  cfg: got.CFG,
  refs: got.REF,
  tasks: got.TASKS,
  long: got.LONG,
  events: got.EVENTS,
};

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(out, null, 1), 'utf8');

const steps = out.tasks.reduce((n, t) => n + (t.steps || []).length, 0);
console.log(`[extract] tasks=${out.tasks.length} long=${out.long.length} events=${out.events.length} refs=${Object.keys(out.refs).length} steps=${steps} days=${out.cfg.days}`);
console.log('[extract] → ' + OUT);
