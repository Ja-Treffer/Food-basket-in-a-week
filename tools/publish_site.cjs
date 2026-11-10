// 部署两个 HTML 到 GitHub Pages：
//   site/index.html        入口页（两个链接）
//   site/html_demo/        game.html    → 模拟器
//   site/html_review/      review.html  → 轻考核
//
//   node tools/publish_site.cjs
//
// 生成物直接是站点目录，改完模板跑一次就好。

const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const site = path.join(root, "site");

function copy(src, dest) {
	const s = path.join(root, src);
	if (!fs.existsSync(s)) throw new Error("缺文件：" + src);
	fs.mkdirSync(path.dirname(dest), { recursive: true });
	fs.copyFileSync(s, dest);
	const kb = Math.round(fs.statSync(dest).size / 1024);
	console.log(`  ${src} → ${path.relative(root, dest)}  ${kb} KB`);
}

const index = `<!doctype html>
<html lang="zh-Hans">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>一周菜篮 · One-Week Basket</title>
<style>
  :root{ --bg:#f5f3ed; --paper:#fffefb; --ink:#23221e; --soft:#6b6559; --line:#d9d4c8; }
  *{ box-sizing:border-box }
  body{ margin:0; background:var(--bg); color:var(--ink); padding:56px 20px 80px;
        font-family:-apple-system,"Segoe UI","Microsoft YaHei","PingFang SC","Noto Sans SC",Arial,sans-serif;
        font-size:16px; line-height:1.65 }
  main{ max-width:640px; margin:0 auto }
  h1{ font-size:26px; letter-spacing:.04em; margin:0 0 6px }
  p.sub{ color:var(--soft); margin:0 0 32px; font-size:14px }
  a.card{ display:block; background:var(--paper); border:1px solid var(--line); border-radius:8px;
          padding:20px 22px; margin:0 0 14px; color:inherit; text-decoration:none; transition:.15s }
  a.card:hover{ border-color:#b3ac93; transform:translateY(-1px) }
  a.card b{ display:block; font-size:17px; margin-bottom:4px }
  a.card span{ color:var(--soft); font-size:14px }
  footer{ margin-top:36px; color:var(--soft); font-size:13px; line-height:1.9 }
  code{ background:#ece8dd; padding:1px 5px; border-radius:4px; font-size:12.5px }
</style>
</head>
<body>
<main>
  <h1>一周菜篮 · One-Week Basket</h1>
  <p class="sub">香港家政 / 科技与生活课堂 · 七日情景模拟器</p>

  <a class="card" href="./html_demo/">
    <b>玩模拟器</b>
    <span>七天，每天两件事；选的时候看不到数字，结算日才结账并逐笔解释。</span>
  </a>

  <a class="card" href="./html_review/">
    <b>做轻考核</b>
    <span>随机 6 题，每题 30 秒，约 3 分钟；当场给机制解释与依据编号。</span>
  </a>

  <footer>
    两个页面都是单文件、零依赖、不联网。<br>
    固定随机：<code>?seed=2026</code>　语言：<code>?lang=zh|tw|en</code><br>
    源码与文档在 <a href="https://github.com/Ja-Treffer/Food-basket-in-a-week">GitHub</a>。
  </footer>
</main>
</body>
</html>
`;

fs.mkdirSync(site, { recursive: true });
console.log("发布站点：");
copy("game.html", path.join(site, "html_demo", "index.html"));
copy("review.html", path.join(site, "html_review", "index.html"));
fs.writeFileSync(path.join(site, "index.html"), index, "utf8");
// 关掉 Jekyll：纯静态，别让构建去解析大 HTML
fs.writeFileSync(path.join(site, ".nojekyll"), "", "utf8");
console.log("  → site/index.html  （入口页）");
console.log("完成。提交 site/ 后 GitHub Pages 会自动更新。");
