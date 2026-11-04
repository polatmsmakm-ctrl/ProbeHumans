'use strict';
// Little Alien — race server.
// Everyone plays their own run at the same time; this server only relays live
// scores (score + distance) between the players of a room and decides the ranking.

const http = require('http');
const { WebSocketServer } = require('ws');

const PORT = parseInt(process.env.PORT || '8787', 10);
const MAX_PLAYERS = 8;
const MAX_ROOMS = 50;
const MAX_CLIENTS = 100;
const START_DELAY = 3;                 // seconds of "3-2-1" before everyone starts
const BOARD_MS = 250;                  // how often the live board is sent
const MAX_RACE_MS = 20 * 60 * 1000;    // a race never lasts longer than this
const MAX_MSGS_PER_SEC = 40;

const rooms = new Map();
let nextId = 1;

const server = http.createServer((req, res) => {
  // open http://<address>:8787 in Safari to check the server is reachable
  console.log(new Date().toLocaleTimeString() + '  browser check from ' + req.socket.remoteAddress);
  res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('Little Alien race server is running. Rooms: ' + rooms.size + '\n');
});

const wss = new WebSocketServer({ server, maxPayload: 1024 });

function cleanRoom(s) {
  return String(s || '').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 10);
}

function cleanName(s) {
  const n = String(s || '').replace(/[\u0000-\u001f]/g, '').trim().slice(0, 14);
  return n || 'Player';
}

function toInt(v) {
  const n = Number(v);
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(Math.floor(n), 1e9));
}

function send(ws, obj) {
  if (ws.readyState === 1) ws.send(JSON.stringify(obj));
}

function fail(ws, msg) {
  send(ws, { t: 'error', msg });
  ws.close(1008, msg.slice(0, 100));
}

function publicPlayer(p) {
  return { id: p.id, name: p.name, score: p.score, distance: p.distance, alive: p.alive, done: p.done };
}

function broadcast(room, obj) {
  const text = JSON.stringify(obj);
  for (const p of room.players.values()) {
    if (p.ws.readyState === 1) p.ws.send(text);
  }
}

function sendLobby(room) {
  broadcast(room, {
    t: 'lobby',
    hostId: room.hostId,
    players: [...room.players.values()].map(publicPlayer),
  });
}

function rank(list) {
  return list.slice().sort((a, b) => (b.score - a.score) || (b.distance - a.distance));
}

function stopTimers(room) {
  if (room.boardTimer) clearInterval(room.boardTimer);
  if (room.limitTimer) clearTimeout(room.limitTimer);
  room.boardTimer = null;
  room.limitTimer = null;
}

function finishRace(room) {
  stopTimers(room);
  if (room.phase !== 'racing') return;
  room.phase = 'lobby';
  const results = rank([...room.players.values()].map(publicPlayer));
  broadcast(room, { t: 'results', players: results });
  for (const p of room.players.values()) {
    p.score = 0; p.distance = 0; p.alive = true; p.done = false;
  }
  sendLobby(room);
}

function startRace(room) {
  room.phase = 'racing';
  for (const p of room.players.values()) {
    p.score = 0; p.distance = 0; p.alive = true; p.done = false;
  }
  room.dirty = true;
  broadcast(room, { t: 'go', delay: START_DELAY });
  room.boardTimer = setInterval(() => {
    if (!room.dirty) return;
    room.dirty = false;
    broadcast(room, { t: 'board', players: [...room.players.values()].map(publicPlayer) });
  }, BOARD_MS);
  room.limitTimer = setTimeout(() => finishRace(room), MAX_RACE_MS);
}

function allDone(room) {
  for (const p of room.players.values()) if (!p.done) return false;
  return true;
}

function handleJoin(ws, msg) {
  if (ws.player) return;
  const code = cleanRoom(msg.room);
  if (!code) return fail(ws, 'Room name is empty');
  let room = rooms.get(code);
  if (!room) {
    if (rooms.size >= MAX_ROOMS) return fail(ws, 'Server is full');
    room = { code, players: new Map(), hostId: null, phase: 'lobby', dirty: false, boardTimer: null, limitTimer: null };
    rooms.set(code, room);
  }
  if (room.phase !== 'lobby') return fail(ws, 'Race already started, try again soon');
  if (room.players.size >= MAX_PLAYERS) return fail(ws, 'Room is full');
  const id = 'p' + (nextId++);
  const player = { id, ws, room, name: cleanName(msg.name), score: 0, distance: 0, alive: true, done: false };
  room.players.set(id, player);
  if (!room.hostId) room.hostId = id;
  ws.player = player;
  clearTimeout(ws.joinTimer);
  send(ws, { t: 'joined', id, host: room.hostId === id, room: code });
  console.log(new Date().toLocaleTimeString() + '  ' + player.name + ' joined room ' + code + ' (' + room.players.size + ' in room)');
  sendLobby(room);
}

function handleStart(ws) {
  const p = ws.player;
  if (!p) return;
  const room = p.room;
  if (room.hostId !== p.id || room.phase !== 'lobby') return;
  if (room.players.size < 2) return send(ws, { t: 'error', msg: 'Need at least 2 players' });
  startRace(room);
}

function handleState(ws, msg) {
  const p = ws.player;
  if (!p || p.room.phase !== 'racing' || p.done) return;
  p.score = Math.max(p.score, toInt(msg.score));
  p.distance = Math.max(p.distance, toInt(msg.distance));
  p.alive = msg.alive !== false;
  p.room.dirty = true;
}

function handleDone(ws, msg) {
  const p = ws.player;
  if (!p || p.room.phase !== 'racing' || p.done) return;
  p.score = Math.max(p.score, toInt(msg.score));
  p.distance = Math.max(p.distance, toInt(msg.distance));
  p.alive = false;
  p.done = true;
  p.room.dirty = true;
  if (allDone(p.room)) finishRace(p.room);
}

function leave(ws) {
  clearTimeout(ws.joinTimer);
  const p = ws.player;
  if (!p) return;
  ws.player = null;
  const room = p.room;
  room.players.delete(p.id);
  if (room.players.size === 0) {
    stopTimers(room);
    rooms.delete(room.code);
    return;
  }
  if (room.hostId === p.id) room.hostId = room.players.keys().next().value;
  if (room.phase === 'racing') {
    room.dirty = true;
    if (allDone(room)) { finishRace(room); return; }
  }
  sendLobby(room);
}

wss.on('connection', (ws, req) => {
  if (wss.clients.size > MAX_CLIENTS) { ws.close(1013, 'busy'); return; }
  console.log(new Date().toLocaleTimeString() + '  player connected from ' + req.socket.remoteAddress);
  ws.isAlive = true;
  ws.player = null;
  ws.msgCount = 0;
  ws.joinTimer = setTimeout(() => { if (!ws.player) ws.close(1008, 'join timeout'); }, 10000);
  ws.on('pong', () => { ws.isAlive = true; });
  ws.on('error', () => {});
  ws.on('close', () => leave(ws));
  ws.on('message', (data) => {
    ws.msgCount++;
    if (ws.msgCount > MAX_MSGS_PER_SEC) return;
    let msg;
    try { msg = JSON.parse(data.toString()); } catch (e) { return; }
    if (!msg || typeof msg.t !== 'string') return;
    switch (msg.t) {
      case 'join': handleJoin(ws, msg); break;
      case 'start': handleStart(ws); break;
      case 'state': handleState(ws, msg); break;
      case 'done': handleDone(ws, msg); break;
      default: break;
    }
  });
});

// per-second rate-limit reset + dead connection cleanup
setInterval(() => { for (const ws of wss.clients) ws.msgCount = 0; }, 1000);
setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) { ws.terminate(); continue; }
    ws.isAlive = false;
    ws.ping();
  }
}, 15000);

server.listen(PORT, '0.0.0.0', () => {
  console.log('Little Alien race server listening on port ' + PORT);
});
