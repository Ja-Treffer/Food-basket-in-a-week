/* 一条命令把前端数据同步给 Godot：抽 game.json + 复制词典。用法：node tools/sync_godot_data.cjs */
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const DICT_SRC = path.join(ROOT, 'data', 'game-i18n.json');
const DICT_DST = path.join(ROOT, 'godot', 'data', 'game-i18n.json');

execFileSync(process.execPath, [path.join(__dirname, 'extract_game_data.cjs')], { stdio: 'inherit' });

const raw = fs.readFileSync(DICT_SRC, 'utf8');
fs.writeFileSync(DICT_DST, raw, 'utf8');
const n = JSON.parse(raw).length;
console.log(`词典 ${n} 条 → godot/data/game-i18n.json`);
console.log('Godot 侧数据已同步；如新增了脚本，记得再跑一次 --import。');
