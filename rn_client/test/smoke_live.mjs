/**
 * 前端 TestUnit · 在线冒烟 —— 对本地游戏服做真实端到端验证。
 * 前置：./restart-local-workers.sh 起服（HTTP 8888）。
 * 运行：cd rn_client && npm run test:live
 * 会注册一个临时账号并完整走 init/look/status/autofight 链路。
 */
import assert from 'node:assert/strict';
import * as api from '../src/api/mudApi.js';

const HOST = process.env.XIAND_SMOKE_HOST || 'http://127.0.0.1:8888';
api.setApiBase(HOST);

let passed = 0;
let failed = 0;

async function check(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`  ok  ${name}`);
  } catch (e) {
    failed++;
    console.log(`  FAIL ${name}: ${e.message}`);
  }
}

async function serverUp() {
  try {
    const response = await fetch(`${HOST}/health`);
    return response.ok;
  } catch (e) {
    return false;
  }
}

if (!(await serverUp())) {
  console.log(`本地服 ${HOST} 未启动，跳过在线冒烟（离线单测不受影响）。`);
  process.exit(0);
}

/* 用户名（不含区号前缀）上限12字符：smoke+6位时间戳=11。 */
const suffix = String(Date.now()).slice(-6);
const userid = `smoke${suffix}`;
const password = `smoke${suffix}pw`;
let txd = '';

await check('分区列表包含开放中的 xd01', async () => {
  const data = await api.fetchPartitions();
  const list = Array.isArray(data.partitions) ? data.partitions :
    (Array.isArray(data) ? data : []);
  assert.ok(list.length >= 1, `partitions=${JSON.stringify(data)}`);
  assert.ok(list.some(p => p.value === 'xd01' && p.login_open !== 0),
    'xd01 未开放');
});

await check('注册临时账号成功', async () => {
  const challenge = await api.fetchChallenge();
  assert.ok(challenge.length > 0, 'challenge 为空');
  const result = await api.registerAccount(
    `xd01${userid}`, password, 'smokesess', challenge);
  assert.ok(result.ok, `注册失败: ${result.text.slice(0, 160)}`);
});

await check('init 登录拿到 txd 与场景输出', async () => {
  const data = await api.login(`xd01${userid}`, password);
  txd = data.txd || '';
  assert.ok(txd.length > 0, '未返回 txd');
  assert.ok((data.lines || []).length > 0, 'init 无输出');
});

await check('look 命令返回场景行', async () => {
  const data = await api.sendCommand(txd, 'look');
  txd = data.txd || txd;
  const text = JSON.stringify(data.lines || []);
  assert.ok(text.length > 20, 'look 无内容');
});

await check('status 轮询返回玩家数值', async () => {
  const status = await api.fetchStatus(txd);
  txd = status.txd || txd;
  assert.ok(typeof status.hp === 'number' || status.hp !== undefined,
    `status=${JSON.stringify(status).slice(0, 160)}`);
});

await check('battle_status 可轮询（新号通常脱战）', async () => {
  const battle = await api.fetchBattleStatus(txd);
  txd = battle.txd || txd;
  assert.ok(typeof battle.in_battle !== 'undefined',
    `battle=${JSON.stringify(battle).slice(0, 160)}`);
});

await check('autofight 接口应答（off 不留挂机）', async () => {
  const data = await api.setAutofight(txd, 'off');
  assert.ok(!data.error, `error=${data.error}`);
});

console.log(`\n在线冒烟：通过 ${passed}，失败 ${failed}`);
process.exit(failed > 0 ? 1 : 0);
