// 三日菜篮 · 现场答题后端（零依赖，Node 18+）
//   node live/server.mjs            → http://localhost:8787
//   node live/server.mjs 9000       → 换端口
// 房间状态全在内存里，进程退出即清空；不落盘、不联网、不发任何追踪。

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const QUIZ = JSON.parse(fs.readFileSync(path.join(ROOT, 'data', 'quiz.json'), 'utf8'));
const ITEMS = QUIZ.items;
const PER_Q = QUIZ.perQuestionSeconds || 20;
const PORT = Number(process.argv[2]) || 8787;

/** @type {Map<string, any>} */
const rooms = new Map();

/* ---------------- 工具 ---------------- */
const rid = (n = 6) => crypto.randomBytes(16).toString('base64url').slice(0, n);

function json(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

function body(req) {
  return new Promise((resolve) => {
    let s = '';
    req.on('data', (c) => {
      s += c;
      if (s.length > 1e6) req.destroy();
    });
    req.on('end', () => {
      try { resolve(JSON.parse(s || '{}')); } catch { resolve({}); }
    });
    req.on('error', () => resolve({}));
  });
}

function makePin() {
  let pin;
  do { pin = String(1000 + Math.floor(Math.random() * 9000)); } while (rooms.has(pin));
  return pin;
}

/* ---------------- 房间 ---------------- */
function newRoom() {
  const pin = makePin();
  const room = {
    pin,
    hostKey: rid(12),
    state: 'lobby',        // lobby → question → reveal → … → done
    qIndex: 0,
    deadline: 0,
    players: new Map(),    // pid → { name, joinedAt }
    answers: new Map(),    // qIndex → Map(pid → choice)
    clients: new Set(),    // { res, role, pid }
    createdAt: Date.now(),
  };
  rooms.set(pin, room);
  return room;
}

function aliveRoom(pin) {
  const r = rooms.get(String(pin || ''));
  return r || null;
}

function countsFor(room, qi) {
  const c = [0, 0, 0, 0];
  const m = room.answers.get(qi);
  if (m) for (const v of m.values()) if (v >= 0 && v < 4) c[v]++;
  return c;
}

function answeredCount(room, qi) {
  const m = room.answers.get(qi);
  return m ? m.size : 0;
}

/* ---------------- 视图（按角色裁剪） ---------------- */
function viewFor(room, role, pid) {
  const item = ITEMS[room.qIndex] || null;
  const revealing = room.state === 'reveal' || room.state === 'done';
  const base = {
    role,
    pin: room.pin,
    state: room.state,
    qIndex: room.qIndex,
    total: ITEMS.length,
    perQuestionSeconds: PER_Q,
    deadline: room.state === 'question' ? room.deadline : 0,
    serverNow: Date.now(),
    playerCount: room.players.size,
    answered: answeredCount(room, room.qIndex),
  };

  if (role === 'host') {
    base.players = [...room.players.entries()].map(([id, p]) => ({
      id, name: p.name, answered: !!(room.answers.get(room.qIndex)?.has(id)),
    }));
    base.counts = countsFor(room, room.qIndex);
    base.item = item ? { t: item.t, o: item.o, g: item.g, ref: item.ref, why: item.why, x: item.x } : null;
    if (revealing && item) base.correct = item.a;
    return base;
  }

  // 玩家：题干与选项照发，分布与答案只在揭示时下发
  base.item = item ? { t: item.t, o: item.o, g: item.g } : null;
  base.myChoice = room.answers.get(room.qIndex)?.get(pid) ?? null;
  base.hasAnswered = base.myChoice !== null;
  if (revealing && item) {
    base.correct = item.a;
    base.counts = countsFor(room, room.qIndex);
    base.why = item.why;
    base.ref = item.ref;
    base.x = item.x;
  }
  return base;
}

function send(client, payload) {
  try {
    client.res.write('data: ' + JSON.stringify(payload) + '\n\n');
  } catch { /* 掉线的连接忽略 */ }
}

function broadcast(room) {
  for (const c of room.clients) {
    send(c, viewFor(room, c.role, c.pid));
  }
}

/* ---------------- 状态推进 ---------------- */
function startRoom(room) {
  room.qIndex = 0;
  room.state = 'question';
  room.deadline = Date.now() + PER_Q * 1000;
  broadcast(room);
}

function reveal(room) {
  if (room.state !== 'question') return;
  room.state = 'reveal';
  room.deadline = 0;
  broadcast(room);
}

function nextQuestion(room) {
  if (room.state !== 'reveal') return;
  if (room.qIndex >= ITEMS.length - 1) {
    room.state = 'done';
    room.deadline = 0;
  } else {
    room.qIndex++;
    room.state = 'question';
    room.deadline = Date.now() + PER_Q * 1000;
  }
  broadcast(room);
}

// 计时器：到点自动揭示；全员答完也立刻揭示
setInterval(() => {
  const now = Date.now();
  for (const room of rooms.values()) {
    if (room.state !== 'question') continue;
    const all = room.players.size > 0 && answeredCount(room, room.qIndex) >= room.players.size;
    if (all || now >= room.deadline) reveal(room);
  }
}, 400);

// 清理：两小时没人动过的房间
setInterval(() => {
  const now = Date.now();
  for (const [pin, room] of rooms) {
    if (now - room.createdAt > 2 * 3600 * 1000 && room.clients.size === 0) rooms.delete(pin);
  }
}, 60000);

/* ---------------- 静态文件 ---------------- */
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
};

function serveFile(res, filePath) {
  fs.readFile(filePath, (err, buf) => {
    if (err) { res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }); res.end('404'); return; }
    res.writeHead(200, {
      'Content-Type': MIME[path.extname(filePath).toLowerCase()] || 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    res.end(buf);
  });
}

/* ---------------- 路由 ---------------- */
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://' + (req.headers.host || 'localhost'));
  const p = url.pathname;

  /* --- 静态 --- */
  if (req.method === 'GET') {
    if (p === '/' || p === '/host') return serveFile(res, path.join(__dirname, 'host.html'));
    if (p === '/play') return serveFile(res, path.join(__dirname, 'play.html'));
    if (p === '/review.html') return serveFile(res, path.join(ROOT, 'review.html'));
    if (p === '/game.html') return serveFile(res, path.join(ROOT, 'game.html'));
    if (p === '/quiz.json') return serveFile(res, path.join(ROOT, 'data', 'quiz.json'));
    if (/^\/[\w.-]+\.(html|js|css|png|svg|json)$/.test(p)) {
      const f = path.join(__dirname, path.basename(p));
      return serveFile(res, f);
    }
  }

  /* --- SSE --- */
  if (p === '/api/check' && req.method === 'GET') {
    const room = aliveRoom(url.searchParams.get('pin'));
    if (!room) return json(res, 404, { ok: false, error: 'no room' });
    if (url.searchParams.get('hostKey') !== room.hostKey) return json(res, 403, { ok: false, error: 'bad key' });
    return json(res, 200, { ok: true, state: room.state, qIndex: room.qIndex, playerCount: room.players.size });
  }

  if (p === '/api/stream' && req.method === 'GET') {
    const pin = url.searchParams.get('pin');
    const role = url.searchParams.get('role') === 'host' ? 'host' : 'player';
    const pid = url.searchParams.get('pid') || '';
    const hostKey = url.searchParams.get('hostKey') || '';
    const room = aliveRoom(pin);
    if (!room) { res.writeHead(404); res.end('no room'); return; }
    if (role === 'host' && hostKey !== room.hostKey) { res.writeHead(403); res.end('forbidden'); return; }

    res.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-store',
      Connection: 'keep-alive',
      'X-Accel-Buffering': 'no',
    });
    res.write(': connected\n\n');

    const client = { res, role, pid };
    room.clients.add(client);
    send(client, viewFor(room, role, pid));

    const ka = setInterval(() => { try { res.write(': ping\n\n'); } catch {} }, 15000);
    req.on('close', () => { clearInterval(ka); room.clients.delete(client); });
    return;
  }

  /* --- API --- */
  if (p.startsWith('/api/') && req.method === 'POST') {
    const b = await body(req);

    if (p === '/api/room') {
      const room = newRoom();
      return json(res, 200, { pin: room.pin, hostKey: room.hostKey, total: ITEMS.length, perQuestionSeconds: PER_Q });
    }

    if (p === '/api/join') {
      const room = aliveRoom(b.pin);
      if (!room) return json(res, 404, { error: '房间不存在' });
      if (room.state !== 'lobby') return json(res, 409, { error: '这局已经开始，等下一局' });
      const name = String(b.name || '').trim().slice(0, 12) || '同学';
      const pid = rid(10);
      // 同名追加序号，避免主持人分不清
      const taken = new Set([...room.players.values()].map((x) => x.name));
      let final = name, i = 2;
      while (taken.has(final)) final = name + '·' + i++;
      room.players.set(pid, { name: final, joinedAt: Date.now() });
      broadcast(room);
      return json(res, 200, { pid, name: final, total: ITEMS.length, perQuestionSeconds: PER_Q });
    }

    if (p === '/api/start') {
      const room = aliveRoom(b.pin);
      if (!room) return json(res, 404, { error: '房间不存在' });
      if (b.hostKey !== room.hostKey) return json(res, 403, { error: '主持人口令不对' });
      if (room.state !== 'lobby') return json(res, 409, { error: '已经开始了' });
      startRoom(room);
      return json(res, 200, { ok: true });
    }

    if (p === '/api/answer') {
      const room = aliveRoom(b.pin);
      if (!room) return json(res, 404, { error: '房间不存在' });
      if (room.state !== 'question') return json(res, 409, { error: '这一题已经收了' });
      const pid = String(b.pid || '');
      if (!room.players.has(pid)) return json(res, 403, { error: '不在这个房间' });
      const qi = room.qIndex;
      if (!room.answers.has(qi)) room.answers.set(qi, new Map());
      const m = room.answers.get(qi);
      if (m.has(pid)) return json(res, 409, { error: '已经答过了' });
      const c = Number(b.c);
      if (!(c >= 0 && c < 4)) return json(res, 400, { error: '选项不合法' });
      m.set(pid, c);
      broadcast(room);
      return json(res, 200, { ok: true, answered: m.size, playerCount: room.players.size });
    }

    if (p === '/api/reveal' || p === '/api/next') {
      const room = aliveRoom(b.pin);
      if (!room) return json(res, 404, { error: '房间不存在' });
      if (b.hostKey !== room.hostKey) return json(res, 403, { error: '主持人口令不对' });
      if (p === '/api/reveal') reveal(room); else nextQuestion(room);
      return json(res, 200, { ok: true, state: room.state, qIndex: room.qIndex });
    }

    if (p === '/api/reset') {
      const room = aliveRoom(b.pin);
      if (!room) return json(res, 404, { error: '房间不存在' });
      if (b.hostKey !== room.hostKey) return json(res, 403, { error: '主持人口令不对' });
      room.state = 'lobby'; room.qIndex = 0; room.deadline = 0;
      room.answers.clear(); room.players.clear();
      broadcast(room);
      return json(res, 200, { ok: true });
    }

    return json(res, 404, { error: 'no such api' });
  }

  res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('404');
});

server.listen(PORT, '0.0.0.0', () => {
  const ips = [];
  for (const list of Object.values(os.networkInterfaces())) {
    for (const ni of list || []) {
      if (ni.family === 'IPv4' && !ni.internal) ips.push(ni.address);
    }
  }
  console.log('');
  console.log('  三日菜篮 · 现场答题已启动');
  console.log('  主持端   http://localhost:' + PORT + '/');
  for (const ip of ips) console.log('  学生端   http://' + ip + ':' + PORT + '/play');
  console.log('  题库     ' + ITEMS.length + ' 题，每题 ' + PER_Q + ' 秒；房间只在内存里，Ctrl+C 即清空。');
  console.log('');
});
