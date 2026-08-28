/**
 * 前端 TestUnit —— 仙道原生客户端离线单元测试。
 * 零依赖（node 自带 assert），任何前端修改都必须保持本套全绿：
 *   cd rn_client && npm test
 * 在线冒烟另见 smoke_live.mjs（需要本地游戏服 8888）。
 */
import assert from 'node:assert/strict';
import * as api from '../src/api/mudApi.js';
import * as accountApi from '../src/api/accountApi.js';
import {
  flattenTextParts, linePlainText, lineHasBattleButton,
  responseHasBattleButton, buttonStyleFor, resolveImageUrl,
  buildInputCommand, colorHexForClass,
} from '../src/utils/segments.js';
import { useGameStore } from '../src/store/useGameStore.js';

let passed = 0;
let failed = 0;
const failures = [];

async function check(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`  ok  ${name}`);
  } catch (e) {
    failed++;
    failures.push(`${name}: ${e.message}`);
    console.log(`  FAIL ${name}: ${e.message}`);
  }
}

function mockFetch(responses) {
  const calls = [];
  const impl = async url => {
    calls.push(String(url));
    const hit = responses.shift();
    if (!hit) throw new Error(`unexpected fetch: ${url}`);
    if (hit.throw) throw new Error(hit.throw);
    return {
      ok: hit.ok !== false,
      status: hit.status || 200,
      json: async () => hit.body,
    };
  };
  impl.calls = calls;
  return impl;
}

async function withGlobalFetch(impl, fn) {
  const original = globalThis.fetch;
  globalThis.fetch = impl;
  try {
    return await fn();
  } finally {
    globalThis.fetch = original;
  }
}

/* ---------- URL 构造 ---------- */
await check('登录 URL 携带完整 userid/密码/init 且全量编码', () => {
  const url = api.buildJsonUrl('http://h:1', {
    userid: 'xd01 张三', password: 'p&w=1', cmd: 'init',
  });
  assert.ok(url.startsWith('http://h:1/api/json?'));
  assert.ok(url.includes('userid=xd01%20%E5%BC%A0%E4%B8%89'));
  assert.ok(url.includes('password=p%26w%3D1'));
  assert.ok(url.includes('cmd=init'));
});

await check('txd URL 追加附加参数并编码', () => {
  const url = api.buildTxdUrl('http://h:1/', '/api/autofight', 'tx d1', {
    action: 'toggle',
  });
  assert.equal(url, 'http://h:1/api/autofight?txd=tx%20d1&action=toggle');
});

await check('apiBase 默认指向本地 8888，setApiBase 去尾斜杠', () => {
  api.setApiBase('');
  assert.equal(api.getApiBase(), 'http://127.0.0.1:8888');
  api.setApiBase('https://xd.example.com//');
  assert.equal(api.getApiBase(), 'https://xd.example.com');
  api.setApiBase('');
});

/* ---------- API 层（注入 mock fetch） ---------- */
await check('login 走 init 并返回 txd/lines', async () => {
  api.setApiBase('http://mock:9');
  const f = mockFetch([{
    body: { txd: 'T1', lines: [{ type: 'line', segments: [] }] },
  }]);
  const data = await api.login('xd01u', 'p', f);
  assert.equal(data.txd, 'T1');
  assert.equal(f.calls.length, 1);
  assert.ok(f.calls[0].includes('userid=xd01u'));
  assert.ok(f.calls[0].includes('cmd=init'));
});

await check('sendCommand 复用当前 txd 并接受轮换', async () => {
  const f = mockFetch([{ body: { txd: 'T2', lines: [] } }]);
  const data = await api.sendCommand('T1', 'look', f);
  assert.equal(data.txd, 'T2');
  assert.ok(f.calls[0].includes('txd=T1'));
  assert.ok(f.calls[0].includes('cmd=look'));
});

await check('autofight 以 POST 表单提交 txd/action', async () => {
  const calls = [];
  const f = async (url, options) => {
    calls.push({ url: String(url), options });
    return { ok: true, status: 200, json: async () => ({ ok: 1 }) };
  };
  await api.setAutofight('T9', 'toggle', f);
  assert.ok(calls[0].url.endsWith('/api/autofight'));
  assert.equal(calls[0].options.method, 'POST');
  assert.equal(calls[0].options.body, 'txd=T9&action=toggle');
});

await check('注册走 /api/html 免认证通道并编码命令', async () => {
  const calls = [];
  const impl = async url => {
    calls.push(String(url));
    return { ok: true, status: 200, text: async () => '注册成功 密码已生成' };
  };
  const result = await api.registerAccount('xd01u9', 'pw', 'sess1', 'CH1', impl);
  assert.equal(result.ok, true);
  assert.ok(calls[0].includes('/api/html?cmd=login_regnew%20gamelib%20'));
  assert.ok(calls[0].includes('xd01u9%20pw%20sess1%20CH1'));
});

await check('服务端 error 字段转换为异常', async () => {
  const f = mockFetch([{
    status: 401, ok: false, body: { error: '用户名或密码错误' },
  }]);
  await assert.rejects(() => api.login('x', 'y', f), /用户名或密码错误/);
});

/* ---------- 渲染纯工具 ---------- */
await check('颜色类映射到十六进制且兜底中性色', () => {
  assert.equal(colorHexForClass('color-red-bold'), '#FF0000');
  assert.equal(colorHexForClass('color-gold'), '#D4AF37');
  assert.equal(colorHexForClass('unknown'), '#F0E6D2');
  assert.equal(colorHexForClass(''), '#F0E6D2');
});

await check('flattenTextParts 处理颜色开闭嵌套', () => {
  const units = flattenTextParts([
    { type: 'text', content: '你获得' },
    { type: 'color-start', class: 'color-gold' },
    { type: 'text', content: '神曜一剑' },
    { type: 'color-end' },
    { type: 'text', content: '！' },
  ]);
  assert.equal(units.length, 3);
  assert.equal(units[0].color, '#F0E6D2');
  assert.equal(units[1].color, '#D4AF37');
  assert.equal(units[2].color, '#F0E6D2');
});

await check('linePlainText 把按钮压成 [标签]', () => {
  const text = linePlainText({
    segments: [
      { type: 'text', parts: [{ type: 'text', content: '前往' }] },
      { type: 'button', label: '进入游戏', cmd: 'start third' },
    ],
  });
  assert.equal(text, '前往[进入游戏]');
});

await check('战斗判定识别“察看战况”按钮', () => {
  const battleLine = {
    segments: [{ type: 'button', label: '察看战况', cmd: '1' }],
  };
  assert.ok(lineHasBattleButton(battleLine));
  assert.ok(responseHasBattleButton([battleLine]));
  assert.equal(responseHasBattleButton([]), false);
});

await check('按钮样式归一化覆盖三类服务端 class', () => {
  assert.equal(buttonStyleFor({ class: 'btn btn-outline-info' }).border, '#8a6d2f');
  assert.equal(buttonStyleFor({ class: 'btn-success' }).bg, '#2d5243');
  assert.equal(buttonStyleFor({ class: 'btn-danger' }).border, '#ff4d6d');
  assert.equal(buttonStyleFor({}).bg, '#3a2f46');
});

await check('图片地址相对路径补 apiBase', () => {
  assert.equal(
    resolveImageUrl('http://h:1/', '/images/a.png'),
    'http://h:1/images/a.png');
  assert.equal(
    resolveImageUrl('http://h:1', 'https://cdn/a.png'),
    'https://cdn/a.png');
  assert.equal(resolveImageUrl('http://h:1', ''), '');
});

await check('cmd-input 命令拼接（有值/空值/无cmd）', () => {
  assert.equal(buildInputCommand({ cmd: 'say' }, '你好'), 'say 你好');
  assert.equal(buildInputCommand({ cmd: 'look' }, '  '), 'look');
  assert.equal(buildInputCommand({}, 'x'), '');
});

/* ---------- 多角色账号 API ---------- */
await check('accountLogin 以 JSON POST 提交且令牌只在请求体', async () => {
  const calls = [];
  const impl = async (url, options) => {
    calls.push({ url: String(url), options });
    return {
      ok: true, status: 200,
      json: async () => ({
        token: 'AT', account_id: 'xd01u', characters: [], limit: 10,
      }),
    };
  };
  accountApi.setAccountApiBase('http://mock:9');
  const data = await accountApi.accountLogin('xd01u', 'pw', impl);
  assert.equal(data.token, 'AT');
  assert.ok(calls[0].url.endsWith('/api/account/login'));
  assert.equal(calls[0].options.method, 'POST');
  assert.equal(calls[0].options.body, '{"userid":"xd01u","password":"pw"}');
  assert.ok(calls[0].url.indexOf('AT') === -1, '令牌不得进 URL');
});

await check('selectCharacter 返回 txd 与 bootstrap 命令', async () => {
  const calls = [];
  const impl = async (url, options) => {
    calls.push({ url: String(url), options });
    return {
      ok: true, status: 200,
      json: async () => ({
        txd: 'NT', character_id: 'xd01u', bootstrap_command: 'init',
      }),
    };
  };
  const data = await accountApi.selectCharacter('AT', 'xd01u', impl);
  assert.equal(data.txd, 'NT');
  assert.equal(calls[0].options.body,
    '{"token":"AT","character_id":"xd01u"}');
});

await check('characterCard 归一化服务端字段', () => {
  const card = accountApi.characterCard({
    id: 'xd01hero', name_cn: '李逍遥', profession_name: '剑仙',
    race_name: '人族', level: '120', realm_type: 'illusion',
    illusion_id: 'S1', is_default: 1,
  });
  assert.equal(card.name, '李逍遥');
  assert.equal(card.level, 120);
  assert.equal(card.realmType, 'illusion');
  assert.equal(card.isDefault, true);
  const empty = accountApi.characterCard(null);
  assert.equal(empty.name, '未命名');
  assert.equal(empty.realmType, 'eternal');
});

/* ---------- Store（zustand 单例 + 注入全局 fetch） ---------- */
await check('store 账号登录进入角色选择（不直接落 txd）', async () => {
  api.setApiBase('http://mock:9');
  accountApi.setAccountApiBase('http://mock:9');
  await withGlobalFetch(mockFetch([
    { body: { token: 'AT', account_id: 'xd01testu', limit: 10 } },
    { body: { characters: [{ id: 'xd01testu', name_cn: '本命',
      profession_name: '剑仙', level: 5, realm_type: 'eternal' }] } },
  ]), async () => {
    const ok = await useGameStore.getState().login('xd01', 'testu', 'pw');
    assert.ok(ok);
    assert.equal(useGameStore.getState().accountToken, 'AT');
    assert.equal(useGameStore.getState().txd, '');
    assert.equal(useGameStore.getState().accountCharacters.length, 1);
    assert.equal(useGameStore.getState().accountCharacters[0].name, '本命');
    assert.equal(useGameStore.getState().userid, 'xd01testu');
  });
  useGameStore.getState().logout();
});

await check('store 账号服务失败时回退单人物直登', async () => {
  api.setApiBase('http://mock:9');
  accountApi.setAccountApiBase('http://mock:9');
  await withGlobalFetch(mockFetch([
    { status: 500, ok: false, body: { error: '账号服务异常' } },
    { body: { txd: 'ST1', lines: [{ type: 'line', segments: [] }] } },
  ]), async () => {
    const ok = await useGameStore.getState().login('xd01', 'testu', 'pw');
    assert.ok(ok);
    assert.equal(useGameStore.getState().txd, 'ST1');
    assert.equal(useGameStore.getState().accountToken, '');
  });
  useGameStore.getState().logout();
});

await check('store 选择角色用 bootstrap 命令进入游戏', async () => {
  api.setApiBase('http://mock:9');
  accountApi.setAccountApiBase('http://mock:9');
  await withGlobalFetch(mockFetch([
    { body: { txd: 'NT', character_id: 'xd01testu',
      bootstrap_command: 'init' } },
    { body: { txd: 'NT2', lines: [{ type: 'line', segments: [] }] } },
  ]), async () => {
    useGameStore.setState({ accountToken: 'AT', txd: '', lines: [] });
    await useGameStore.getState().pickCharacter('xd01testu');
    assert.equal(useGameStore.getState().txd, 'NT2');
    assert.equal(useGameStore.getState().lines.length, 1);
  });
  useGameStore.getState().logout();
});

await check('store 登录失败保留错误且不落 txd', async () => {
  api.setApiBase('http://mock:9');
  accountApi.setAccountApiBase('http://mock:9');
  await withGlobalFetch(mockFetch([
    { status: 401, ok: false, body: { error: '用户不存在' } },
    { status: 401, ok: false, body: { error: '用户不存在' } },
  ]), async () => {
    const ok = await useGameStore.getState().login('xd01', 'ghost', 'pw');
    assert.equal(ok, false);
    assert.match(useGameStore.getState().error, /用户不存在/);
    assert.equal(useGameStore.getState().txd, '');
  });
  useGameStore.getState().logout();
});

await check('store 命令出现战斗按钮则进入战斗态并追加行', async () => {
  await withGlobalFetch(mockFetch([{
    body: {
      txd: 'ST2',
      lines: [{
        type: 'line',
        segments: [{ type: 'button', label: '察看战况', cmd: '1' }],
      }],
    },
  }]), async () => {
    useGameStore.setState({ txd: 'ST1', lines: [], inBattle: false });
    await useGameStore.getState().command('kill 1');
    assert.equal(useGameStore.getState().inBattle, true);
    assert.equal(useGameStore.getState().lines.length, 1);
  });
  useGameStore.getState().logout();
});

await check('store appendLines 截断到 400 行上限', () => {
  const big = [];
  for (let i = 0; i < 500; i++) {
    big.push({ type: 'line', segments: [] });
  }
  useGameStore.setState({ lines: [] });
  useGameStore.getState().appendLines(big);
  assert.ok(useGameStore.getState().lines.length <= 400);
  useGameStore.getState().logout();
});

console.log(`\n前端 TestUnit：通过 ${passed}，失败 ${failed}`);
if (failed > 0) {
  console.log(failures.join('\n'));
  process.exit(1);
}
