/**
 * 前端 TestUnit · 在线冒烟 —— 对本地游戏服做真实端到端验证。
 * 前置：./restart-local-workers.sh 起服（HTTP 8888）。
 * 运行：cd rn_client && npm run test:live
 * 会注册一个临时账号并完整走 init/look/status/autofight 链路。
 */
import assert from 'node:assert/strict';
import * as api from '../src/api/mudApi.js';
import * as accountApi from '../src/api/accountApi.js';

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

/* ---- 多角色账号中心全链路 ---- */
let accountToken = '';
let firstCharacterId = '';
let lastLines = [];

await check('账号登录换取令牌', async () => {
  accountApi.setAccountApiBase(HOST);
  const data = await accountApi.accountLogin(`xd01${userid}`, password);
  accountToken = data.token || '';
  assert.ok(accountToken.length > 0, '未返回 token');
});

await check('角色列表至少包含默认人物', async () => {
  const data = await accountApi.fetchCharacters(accountToken);
  const list = data.characters || [];
  assert.ok(list.length >= 1, `characters=${JSON.stringify(list).slice(0, 160)}`);
  firstCharacterId = String(list[0].id || '');
  assert.ok(firstCharacterId.length > 0, '默认人物缺 id');
  const card = accountApi.characterCard(list[0]);
  assert.ok(card.realmType === 'eternal' || card.realmType === 'illusion');
});

await check('选择默认人物进入游戏（bootstrap→init）', async () => {
  const selected = await accountApi.selectCharacter(
    accountToken, firstCharacterId);
  const bootTxd = selected.txd || '';
  assert.ok(bootTxd.length > 0, 'select 未返回 txd');
  const data = await api.sendCommand(
    bootTxd, selected.bootstrap_command || 'init');
  txd = data.txd || bootTxd;
  lastLines = data.lines || [];
  assert.ok(lastLines.length > 0, 'bootstrap 后无输出');
});

await check('直连 /api/json 登录回退路径仍可用', async () => {
  const data = await api.login(`xd01${userid}`, password);
  assert.ok((data.txd || '').length > 0, '回退路径未返回 txd');
});

/* ---- 建角全链路 ---- */
await check('游戏内建角引导可纯按钮驱动完成（人类·剑仙）', async () => {
  let lines = lastLines;
  for (let step = 0; step < 5; step++) {
    let next = null;
    for (const line of lines) {
      for (const seg of (line.segments || [])) {
        if (!next && seg.type === 'button' &&
            !/介绍|更换|返回/.test(seg.label || '')) {
          next = seg.cmd;
        }
      }
    }
    if (!next) break;
    const data = await api.sendCommand(txd, next);
    txd = data.txd || txd;
    lines = data.lines || [];
  }
  const done = JSON.stringify(lines);
  assert.ok(/返回游戏|新手/.test(done),
    `建角引导未走完: ${done.slice(0, 160)}`);
});

await check('创建第二个角色并出现在列表中', async () => {
  const created = await accountApi.createCharacter(accountToken, {
    realm_type: 'eternal', race_id: 'human',
    profession_id: 'jianxian', name_cn: `冒烟侠${suffix}`,
    sex: 'male', avatar_id: 'h_male1',
  });
  const newId = created.character && created.character.id;
  assert.ok(newId, `建角响应异常: ${JSON.stringify(created).slice(0, 160)}`);
  const refreshed = await accountApi.fetchCharacters(accountToken);
  const list = refreshed.characters || [];
  assert.ok(list.some(one => String(one.id) === String(newId)),
    '新建角色未出现在列表');
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
