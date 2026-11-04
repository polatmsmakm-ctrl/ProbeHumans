'use strict';
// Quick end-to-end check: starts the server, connects 3 fake players and runs a full race.
const { spawn } = require('child_process');
const path = require('path');
const WebSocket = require('ws');

const PORT = 8799;
const URL = 'ws://127.0.0.1:' + PORT;
let failed = 0;

function check(name, ok, extra) {
  console.log((ok ? 'PASS ' : 'FAIL ') + name + (ok || extra === undefined ? '' : '  -> ' + JSON.stringify(extra)));
  if (!ok) failed++;
}

function client(name, room) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(URL);
    const c = { ws, name, id: null, host: null, log: [], waiters: [] };
    ws.on('message', (d) => {
      const m = JSON.parse(d.toString());
      c.log.push(m);
      if (m.t === 'joined') { c.id = m.id; c.host = m.host; }
      c.waiters = c.waiters.filter((w) => { if (w.t === m.t && (!w.test || w.test(m))) { w.res(m); return false; } return true; });
    });
    c.next = (t, test) => new Promise((res, rej) => {
      const found = c.log.find((m) => m.t === t && (!test || test(m)));
      if (found) return res(found);
      const timer = setTimeout(() => rej(new Error(name + ' timed out waiting for ' + t)), 4000);
      c.waiters.push({ t, test, res: (m) => { clearTimeout(timer); res(m); } });
    });
    c.nextAfter = (t, afterT, test) => new Promise((res, rej) => {
      const started = Date.now();
      const tick = () => {
        const idx = c.log.map((m) => m.t).lastIndexOf(afterT);
        if (idx >= 0) {
          const f = c.log.slice(idx + 1).find((m) => m.t === t && (!test || test(m)));
          if (f) return res(f);
        }
        if (Date.now() - started > 4000) return rej(new Error(name + ' timed out waiting for ' + t + ' after ' + afterT));
        setTimeout(tick, 50);
      };
      tick();
    });
    c.send = (o) => ws.send(JSON.stringify(o));
    ws.on('open', () => { c.send({ t: 'join', room: room, name: name }); resolve(c); });
    ws.on('error', reject);
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const srv = spawn('node', [path.join(__dirname, 'server.js')], { env: Object.assign({}, process.env, { PORT: String(PORT) }), stdio: 'inherit' });
  await sleep(800);
  try {
    const a = await client('Rashid', 'test1');
    await a.next('joined');
    check('first player is host', a.host === true);

    const b = await client('Ali', 'test1');
    await b.next('joined');
    check('second player is not host', b.host === false);
    const lobby = await a.next('lobby', (m) => m.players.length === 2);
    check('host sees 2 players in lobby', lobby.players.length === 2 && lobby.hostId === a.id);

    // non-host cannot start
    b.send({ t: 'start' });
    await sleep(300);
    check('non-host start is ignored', !a.log.some((m) => m.t === 'go'));

    // late joiner cannot enter a running race
    a.send({ t: 'start' });
    const go = await a.next('go');
    check('go sent with delay', go.delay === 3);
    await b.next('go');
    const late = await client('Late', 'test1');
    const err = await late.next('error');
    check('join during a race is rejected', /already started/i.test(err.msg), err);

    // live scores
    a.send({ t: 'state', score: 500, distance: 120, alive: true });
    b.send({ t: 'state', score: 900, distance: 80, alive: true });
    const board = await a.next('board', (m) => m.players.some((p) => p.score === 900) && m.players.some((p) => p.score === 500));
    check('board shows both live scores', board.players.length === 2);

    // finish: Ali dies first, then Rashid with a better score
    b.send({ t: 'done', score: 900, distance: 80 });
    await sleep(300);
    check('race continues until everyone is done', !a.log.some((m) => m.t === 'results'));
    a.send({ t: 'done', score: 1500, distance: 200 });
    const res = await a.next('results');
    check('results are ranked by score', res.players[0].name === 'Rashid' && res.players[1].name === 'Ali', res.players);
    await b.next('results');

    // back to lobby, host leaves -> host passes on
    const lob2 = await a.nextAfter('lobby', 'results');
    check('room returns to lobby with scores reset', lob2.players.length === 2 && lob2.players.every((p) => p.score === 0), lob2);
    a.ws.close();
    const lob3 = await b.next('lobby', (m) => m.players.length === 1);
    check('host passes to the remaining player', lob3.hostId === b.id, lob3);

    // single player cannot start
    b.send({ t: 'start' });
    const e2 = await b.next('error', (m) => /2 players/.test(m.msg));
    check('cannot start alone', !!e2);

    // a player leaving mid-race ends it when the rest are done
    const c = await client('Sara', 'test1');
    await c.next('joined');
    b.send({ t: 'start' });
    await b.next('go');
    c.send({ t: 'state', score: -50, distance: 'abc', alive: true });
    c.send({ t: 'state', score: 1e30, distance: 5, alive: true });
    c.send({ t: 'done', score: 10, distance: 1 });
    b.ws.close();
    const res2 = await c.next('results');
    const sara = res2.players.find((p) => p.name === 'Sara');
    check('race ends when the last active player leaves', !!sara && res2.players.length === 1, res2);
    check('absurd scores are clamped', sara.score === 1e9 && sara.distance === 5, sara);
    c.ws.close();
  } catch (e) {
    console.log('FAIL exception: ' + e.message);
    failed++;
  }
  srv.kill();
  console.log(failed === 0 ? '\nALL CHECKS PASSED' : '\n' + failed + ' CHECK(S) FAILED');
  process.exit(failed === 0 ? 0 : 1);
}

main();
