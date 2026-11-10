/* 把三语词典注入 game.html（幂等）。用法：node tools/patch_game_i18n.cjs */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const SRC = path.join(ROOT, 'src', 'game.template.html'); // 手改这份
const GAME = path.join(ROOT, 'game.html');                // 生成物
const DICT = path.join(ROOT, 'data', 'game-i18n.json');

const rows = JSON.parse(fs.readFileSync(DICT, 'utf8'));
const map = {};
for (const r of rows) {
  if (!r || !r.zh) continue;
  map[r.zh] = [r.zh, r.tw || r.zh, r.en || r.zh];
}
console.error('词条 ' + Object.keys(map).length + ' 条');

const block = `<!-- G18N:START -->
<script id="g18n">
(function(){
  'use strict';
  var MAP = ${JSON.stringify(map)};
  var KEY = 'cailan.game.lang';
  var LIDX = 0, REGEX = null, LOOK = null;

  function pick(){
    var m = /[?&]lang=([^&]+)/.exec(location.search);
    if (m){
      var v = decodeURIComponent(m[1]).toLowerCase();
      if (v === '0' || v === 'zh' || v === 'zh-hans' || v === 'cn') return 0;
      if (v === '1' || v === 'tw' || v === 'zh-tw' || v === 'zh-hant') return 1;
      if (v === '2' || v === 'en') return 2;
    }
    try { var s = localStorage.getItem(KEY); if (s !== null && +s >= 0 && +s <= 2) return +s; } catch(e){}
    return 0;
  }

  function esc(s){ return s.replace(/[.*+?^\${}()|[\\]\\\\]/g, '\\\\$&'); }

  function compile(target){
    var pairs = {};
    for (var zh in MAP){
      var t = MAP[zh], to = t[target] || t[0];
      for (var i = 0; i < 2; i++){                /* 只用中文与繁体当源；英文短语太短，容易误命中 */
        var from = t[i];
        if (!from || from.length < 2) continue;
        if (target === 0 && i === 0) continue;    /* 目标中文时中文源无需替换 */
        if (from === to) continue;
        pairs[from] = to;
      }
    }
    var keys = Object.keys(pairs).sort(function(a, b){ return b.length - a.length; });
    LOOK = pairs;
    REGEX = keys.length ? new RegExp(keys.map(esc).join('|'), 'g') : null;
  }

  function tr(v){
    if (LIDX === 0 && !REGEX) return v;
    if (!REGEX || v == null) return v;
    v = String(v);
    if (!/[\\u4e00-\\u9fff\\u3000-\\u303f\\uff00-\\uffef]/.test(v) && LIDX === 2) return v;
    if (!/[A-Za-z]/.test(v) && LIDX === 0) return v;
    return v.replace(REGEX, function(m){ return LOOK[m] !== undefined ? LOOK[m] : m; });
  }

  /* 拦截渲染：所有 innerHTML / textContent 赋值都过一遍词典 */
  var htmlDesc = Object.getOwnPropertyDescriptor(Element.prototype, 'innerHTML');
  var textDesc = Object.getOwnPropertyDescriptor(Node.prototype, 'textContent');
  function install(){
    if (htmlDesc && htmlDesc.set){
      Object.defineProperty(Element.prototype, 'innerHTML', {
        configurable: true, enumerable: htmlDesc.enumerable,
        get: htmlDesc.get,
        set: function(v){ htmlDesc.set.call(this, tr(v)); }
      });
    }
    if (textDesc && textDesc.set){
      Object.defineProperty(Node.prototype, 'textContent', {
        configurable: true, enumerable: textDesc.enumerable,
        get: textDesc.get,
        set: function(v){ textDesc.set.call(this, tr(v)); }
      });
    }
  }

  function walkText(node){
    for (var c = node.firstChild; c; c = c.nextSibling){
      if (c.nodeType === 3){
        var p = c.parentNode;
        if (p && (p.nodeName === 'SCRIPT' || p.nodeName === 'STYLE')) continue;
        var o = tr(c.nodeValue);
        if (o !== c.nodeValue) c.nodeValue = o;
      } else if (c.nodeType === 1){
        if (c.nodeName === 'SCRIPT' || c.nodeName === 'STYLE') continue;
        walkText(c);
      }
    }
  }

  function applyStatic(){
    walkText(document.body);
    document.documentElement.lang = ['zh-Hans','zh-Hant','en'][LIDX];
    var sel = document.getElementById('glang');
    if (sel) sel.value = String(LIDX);
    document.title = LIDX === 2 ? 'Three-Day Basket · Scenario' : (LIDX === 1 ? '三日菜籃 · 情境模擬器' : '三日菜篮 · 情景模拟器');
  }

  function setLang(v){
    LIDX = v;
    try { localStorage.setItem(KEY, String(v)); } catch(e){}
    compile(LIDX);
    applyStatic();
  }

  LIDX = pick();
  compile(LIDX);
  install();

  window.addEventListener('DOMContentLoaded', function(){
    applyStatic();
    var sel = document.getElementById('glang');
    if (sel) sel.addEventListener('change', function(){ setLang(+this.value || 0); });
  });

  window.__cailanLang = setLang;
})();
</script>
<!-- G18N:END -->
`;

let html = fs.readFileSync(SRC, 'utf8');

// 每次从模板重建：先剥掉旧的语言块，保证幂等且不带着上一版残留
html = html.replace(/<!-- G18N:START -->[\s\S]*?<!-- G18N:END -->\n?/, '');

if (!/id="glang"/.test(html)) {
  html = html.replace(
    '<span class="clock" id="clock">准备中</span>',
    '<span class="clock" id="clock">准备中</span>\n    <select id="glang" class="mini" aria-label="语言">\n      <option value="0">简体</option>\n      <option value="1">繁體</option>\n      <option value="2">EN</option>\n    </select>'
  );
}

if (/<!-- G18N:START -->[\s\S]*?<!-- G18N:END -->\n?/.test(html)) {
  html = html.replace(/<!-- G18N:START -->[\s\S]*?<!-- G18N:END -->\n?/, function(){ return block; });
} else {
  html = html.replace('<body>', function(){ return '<body>\n' + block; });
}

fs.writeFileSync(GAME, html, 'utf8');
console.error('game.html 已更新：' + html.length + ' 字符');
