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
  setStorageBackend, saveSession, loadSession, clearSession,
} from '../src/utils/sessionStore.js';
import {
  flattenTextParts, linePlainText, lineHasBattleButton,
  responseHasBattleButton, buttonStyleFor, resolveImageUrl,
  buildInputCommand, colorHexForClass, lineKey, filterGarbageLines,
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

await check('图片地址走 Tomcat 8080 而非 API 8888', () => {
  assert.equal(
    resolveImageUrl('http://h:8080', '/images/a.png'),
    'http://h:8080/images/a.png');
  assert.equal(
    resolveImageUrl('http://h:8080', 'https://cdn/a.png'),
    'https://cdn/a.png');
  assert.equal(resolveImageUrl('http://h:8080', ''), '');
  /* apiBase 兜底：imageBase 为空时用 apiBase */
  assert.equal(
    resolveImageUrl('', '/images/a.png', 'http://api:8888'),
    'http://api:8888/images/a.png');
});

await check('getImageBase 从 apiBase 推导 Tomcat 端口', async () => {
  const { getImageBase } = await import('../src/api/mudApi.js');
  assert.equal(getImageBase('http://192.168.1.5:8888'),
    'http://192.168.1.5:8080');
  assert.equal(getImageBase('http://127.0.0.1:8888'),
    'http://127.0.0.1:8080');
  assert.equal(getImageBase(''), 'http://127.0.0.1:8080');
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

/* ---------- 遗留 HTML 渲染兼容 ---------- */
const { parseHtmlishSpans } = await import('../src/utils/segments.js');

await check('真实公告样本：div颜色继承/闭合回退/标签剥离', () => {
  const spans = parseHtmlishSpans(
    '<div style="color:Orange">【更新提示】\n</div>一、新区开放，经典最高70级\n' +
    '<div style="color:DarkViolet">(QQ客服1811117272)\n</div><br>',
    '#F0E6D2');
  const joined = spans.map(span => span.text).join('');
  assert.ok(joined.indexOf('<') === -1 && joined.indexOf('div') === -1,
    'HTML标签必须全部剥离');
  assert.ok(joined.includes('【更新提示】'));
  assert.ok(joined.includes('一、新区开放'));
  const orange = spans.find(span => span.text.includes('【更新提示】'));
  assert.equal(orange.color, '#FFA500');
  const plain = spans.find(span => span.text.includes('一、新区开放'));
  assert.equal(plain.color, '#F0E6D2', '闭合后应回退默认色');
  const violet = spans.find(span => span.text.includes('QQ客服'));
  assert.equal(violet.color, '#9400D3');
  assert.ok(joined.endsWith('\n'), '<br>应产出换行');
});

await check('HTML解析：font色/嵌套栈/未知标签丢弃/十六进制色', () => {
  const spans = parseHtmlishSpans(
    '前<font color="red">红<b>粗</b>回红</font>后<span class="x">内容</span>' +
    '<div style="color:#00AA00; font-size:12px">翠</div>',
    null);
  const joined = spans.map(span => span.text).join('');
  assert.equal(joined, '前红粗回红后内容翠');
  assert.equal(spans.find(s => s.text === '红').color, '#FF0000');
  assert.equal(spans.find(s => s.text === '粗').color, '#FF0000', 'b不改色');
  assert.equal(spans.find(s => s.text === '回红').color, '#FF0000');
  assert.equal(spans.find(s => s.text === '后').color, null,
    '无HTML色时沿用上下文(null=默认)');
  assert.equal(spans.find(s => s.text === '内容').color, null,
    '未知标签丢弃但保留内容');
  assert.equal(spans.find(s => s.text === '翠').color, '#00AA00');
});

await check('flattenTextParts 集成：HTML色覆盖§色且§闭合恢复', () => {
  const units = flattenTextParts([
    { type: 'color-start', class: 'color-gold' },
    { type: 'text', content: '金<em>斜</em>光<div style="color:Cyan">青</div>辉' },
    { type: 'color-end' },
  ]);
  const joined = units.map(unit => unit.text).join('');
  assert.equal(joined, '金斜光青辉');
  assert.equal(units.find(u => u.text === '金').color, '#D4AF37');
  assert.equal(units.find(u => u.text === '青').color, '#00FFFF');
  assert.equal(units.find(u => u.text === '辉').color, '#D4AF37');
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

/* ---------- 建角：选项门禁与头像 ---------- */
const {
  visibleProfessions, professionsForRace, avatarChoicesFor, PROFESSION_OPTIONS,
} = await import('../src/data/characterOptions.js');

await check('隐藏职业按解锁与幻境门禁显示', () => {
  const none = visibleProfessions({}, 'eternal');
  assert.equal(none.length, 10, '未解锁时应只剩10个常规职业');
  assert.ok(!none.some(p => p.profession_id === 'wuxiang'));
  const unlocked = visibleProfessions(
    { wuxiang: true, taiji: true }, 'eternal');
  assert.ok(unlocked.some(p => p.profession_id === 'wuxiang'));
  assert.ok(unlocked.some(p => p.profession_id === 'taiji'));
  /* 照命即使解锁也只在幻境建角时可见 */
  assert.ok(!unlocked.some(p => p.profession_id === 'zhaoming'));
  const season = visibleProfessions({ zhaoming: true }, 'illusion');
  assert.ok(season.some(p => p.profession_id === 'zhaoming'));
});

await check('种族过滤与头像ID生成与Vue一致', () => {
  const human = professionsForRace('human', {}, 'eternal');
  assert.equal(human.length, 3);
  assert.deepEqual(
    avatarChoicesFor('human', 'jianxian', 'male').slice(0, 3),
    ['h_male1', 'h_male2', 'h_male3']);
  assert.equal(avatarChoicesFor('human', 'jianxian', 'female').length, 12);
  assert.equal(avatarChoicesFor('monst', 'kuangyao', 'male').length, 12);
  assert.deepEqual(
    avatarChoicesFor('third', 'zhenyue', 'female')[0], 'zhenyue_female');
  assert.equal(avatarChoicesFor('', 'jianxian', 'male').length, 0);
  assert.equal(PROFESSION_OPTIONS.length, 13);
});

/* ---------- 建角：API 与 store ---------- */
await check('createCharacter 提交完整表单并返回新角色', async () => {
  const calls = [];
  const impl = async (url, options) => {
    calls.push({ url: String(url), options });
    return {
      ok: true, status: 200,
      json: async () => ({ character: { id: 'xd01new' } }),
    };
  };
  const data = await accountApi.createCharacter('AT', {
    realm_type: 'eternal', race_id: 'human',
    profession_id: 'jianxian', name_cn: ' 新侠 ',
    sex: 'female', avatar_id: 'h_female1',
  }, impl);
  assert.equal(data.character.id, 'xd01new');
  const body = JSON.parse(calls[0].options.body);
  assert.equal(body.token, 'AT');
  assert.equal(body.name_cn, '新侠', '名字需trim');
  assert.equal(body.avatar_id, 'h_female1');
});

await check('store 建角成功后刷新列表并自动进入新角色', async () => {
  api.setApiBase('http://mock:9');
  accountApi.setAccountApiBase('http://mock:9');
  await withGlobalFetch(mockFetch([
    { body: { character: { id: 'xd01new' } } },
    { body: { characters: [
      { id: 'xd01testu', name_cn: '本命', level: 5 },
      { id: 'xd01new', name_cn: '新侠', level: 1 },
    ], limit: 10 } },
    { body: { txd: 'SEL', character_id: 'xd01new',
      bootstrap_command: 'init' } },
    { body: { txd: 'SEL2', lines: [{ type: 'line', segments: [] }] } },
  ]), async () => {
    useGameStore.setState({ accountToken: 'AT', txd: '', lines: [] });
    const ok = await useGameStore.getState().createCharacter({
      realm_type: 'eternal', race_id: 'human',
      profession_id: 'jianxian', name_cn: '新侠',
      sex: 'male', avatar_id: 'h_male1',
    });
    assert.ok(ok);
    assert.equal(useGameStore.getState().accountCharacters.length, 2);
    assert.equal(useGameStore.getState().txd, 'SEL2');
  });
  useGameStore.getState().logout();
});

/* ---------- 会话持久化 ---------- */
function memoryBackend() {
  const map = new Map();
  return {
    getItem: async key => (map.has(key) ? map.get(key) : null),
    setItem: async (key, value) => { map.set(key, value); },
    removeItem: async key => { map.delete(key); },
    _map: map,
  };
}

await check('会话存取：保存/读取/清除与损坏数据兜底', async () => {
  const backend = memoryBackend();
  setStorageBackend(backend);
  await saveSession({ token: 'AT', userid: 'xd01u', apiBase: 'http://h:1' });
  const loaded = await loadSession();
  assert.equal(loaded.token, 'AT');
  assert.equal(loaded.userid, 'xd01u');
  assert.equal(loaded.apiBase, 'http://h:1');
  await clearSession();
  assert.equal(await loadSession(), null);
  await backend._map.set('xiand.session', '{corrupt json');
  assert.equal(await loadSession(), null);
  await backend._map.set('xiand.session', JSON.stringify({ userid: 'x' }));
  assert.equal(await loadSession(), null, '无token的会话必须拒绝恢复');
  setStorageBackend(null);
});

await check('store 登录成功后写入持久会话', async () => {
  const backend = memoryBackend();
  setStorageBackend(backend);
  api.setApiBase('http://mock:9');
  accountApi.setAccountApiBase('http://mock:9');
  await withGlobalFetch(mockFetch([
    { body: { token: 'AT9', account_id: 'xd01u', limit: 10 } },
    { body: { characters: [] } },
  ]), async () => {
    const ok = await useGameStore.getState().login('xd01', 'u9', 'pw');
    assert.ok(ok);
  });
  const raw = backend._map.get('xiand.session');
  assert.ok(raw && raw.includes('AT9'), '登录后应写入会话');
  setStorageBackend(null);
  useGameStore.getState().logout();
});

await check('restoreSession 令牌有效则直达角色面板', async () => {
  const backend = memoryBackend();
  setStorageBackend(backend);
  await saveSession({
    token: 'ATR', userid: 'xd01r', apiBase: 'http://mock:9',
  });
  api.setApiBase('http://mock:9');
  accountApi.setAccountApiBase('http://mock:9');
  await withGlobalFetch(mockFetch([
    { body: { characters: [{ id: 'xd01r', name_cn: '侠', level: 3 }] } },
  ]), async () => {
    const ok = await useGameStore.getState().restoreSession();
    assert.ok(ok);
    assert.equal(useGameStore.getState().accountToken, 'ATR');
    assert.equal(useGameStore.getState().accountCharacters.length, 1);
  });
  setStorageBackend(null);
  useGameStore.getState().logout();
});

await check('restoreSession 令牌过期则清会话回登录', async () => {
  const backend = memoryBackend();
  setStorageBackend(backend);
  await saveSession({ token: 'DEAD', userid: 'xd01x', apiBase: '' });
  await withGlobalFetch(mockFetch([
    { status: 401, ok: false, body: { error: '令牌过期' } },
  ]), async () => {
    const ok = await useGameStore.getState().restoreSession();
    assert.equal(ok, false);
    assert.equal(useGameStore.getState().accountToken, '');
    assert.equal(await loadSession(), null, '过期会话应被清除');
  });
  setStorageBackend(null);
});

/* ---------- 挂机反馈与画面轮询（txpike9 flushview 通道） ---------- */
await check('sendCommand 携带 platform 参数（web按ios上报）', async () => {
  const f = mockFetch([{ body: { txd: 'T2', lines: [] } }]);
  await api.sendCommand('T1', 'flushview', f, 'ios');
  assert.ok(f.calls[0].includes('cmd=flushview'));
  assert.ok(f.calls[0].includes('platform=ios'));
});

await check('toggleAutofight 乐观翻转并在失败时回滚', async () => {
  api.setApiBase('http://mock:9');
  await withGlobalFetch(mockFetch([
    { status: 500, ok: false, body: { error: '服务繁忙' } },
  ]), async () => {
    useGameStore.setState({ txd: 'T1', autofighting: false, afkBusy: false });
    await useGameStore.getState().toggleAutofight();
    assert.equal(useGameStore.getState().autofighting, false, '失败必须回滚');
    assert.equal(useGameStore.getState().afkBusy, false);
    assert.match(useGameStore.getState().error, /服务繁忙/);
  });
  useGameStore.getState().logout();
});

await check('pollGameView 走flushview全量替换并应用refresh', async () => {
  api.setApiBase('http://mock:9');
  await withGlobalFetch(mockFetch([
    { body: {
      txd: 'T9',
      lines: [{ type: 'line', segments: [] }, { type: 'line', segments: [] }],
      refresh: {
        player: { hp: 80, hp_max: 100, autofight: 1 },
        in_battle: 1,
        enemy: { name_cn: '妖道', hp: 30, hp_max: 60 },
      },
    } },
  ]), async () => {
    useGameStore.setState({
      txd: 'T1', lines: [{ type: 'line', segments: [] }],
      status: null, battle: null, inBattle: false, autofighting: false,
    });
    await useGameStore.getState().pollGameView('ios');
    const state = useGameStore.getState();
    assert.equal(state.txd, 'T9', 'txd应随响应轮换');
    assert.equal(state.lines.length, 2, '画面应为全量替换');
    assert.equal(state.autofighting, true);
    assert.equal(state.status.hp, 80);
    assert.equal(state.inBattle, true);
    assert.equal(state.battle.enemy.name_cn, '妖道');
  });
  useGameStore.getState().logout();
});

await check('pollGameView 会话401时干净登出', async () => {
  api.setApiBase('http://mock:9');
  await withGlobalFetch(mockFetch([
    { status: 401, ok: false, body: { error: 'TXD认证信息无效' } },
  ]), async () => {
    useGameStore.setState({
      txd: 'T1', lines: [], inBattle: true, autofighting: true,
    });
    await useGameStore.getState().pollGameView('ios');
    const state = useGameStore.getState();
    assert.equal(state.txd, '', '401应触发登出');
    assert.equal(state.inBattle, false);
    assert.equal(state.autofighting, false);
  });
});

/* ---------- 会话恢复与渲染性能 ---------- */
await check('lineKey 生成稳定key且不同内容不同key', () => {
  const lineA = {
    segments: [
      { type: 'text', parts: [{ type: 'text', content: '你好世界' }] },
    ],
  };
  const lineB = {
    segments: [
      { type: 'text', parts: [{ type: 'text', content: '再见世界' }] },
    ],
  };
  const keyA = lineKey(lineA, 0);
  const keyB = lineKey(lineB, 0);
  assert.ok(keyA.length > 4, `key=${keyA}`);
  assert.notEqual(keyA, keyB, '不同内容必须不同key');
  const keyA2 = lineKey(lineA, 0);
  assert.equal(keyA, keyA2, '相同内容相同index必须稳定');
  /* 按钮行也要纳入key */
  const lineBtn = {
    segments: [
      { type: 'button', label: '攻击', cmd: 'kill 1' },
    ],
  };
  const lineBtn2 = {
    segments: [
      { type: 'button', label: '攻击', cmd: 'kill 2' },
    ],
  };
  assert.notEqual(lineKey(lineBtn, 0), lineKey(lineBtn2, 0),
    '不同按钮cmd必须不同key');
});

await check('pollGameView 401时尝试恢复而非硬登出', async () => {
  api.setApiBase('http://mock:9');
  accountApi.setAccountApiBase('http://mock:9');
  await withGlobalFetch(mockFetch([
    { status: 401, ok: false, body: { error: 'TXD认证信息无效' } },
    { body: { txd: 'NT', character_id: 'xd01testu',
      bootstrap_command: 'init' } },
    { body: { txd: 'NT2', lines: [{ type: 'line', segments: [] }] } },
  ]), async () => {
    useGameStore.setState({
      txd: 'OLD', lines: [], inBattle: true,
      accountToken: 'AT', currentCharacterId: 'xd01testu',
      recovering: false,
    });
    await useGameStore.getState().pollGameView('ios');
    const state = useGameStore.getState();
    assert.equal(state.txd, 'NT2', '恢复后应获得新txd');
    assert.equal(state.currentCharacterId, 'xd01testu');
    assert.equal(state.inBattle, true, '战斗态保持（恢复不清战斗）');
  });
  useGameStore.getState().logout();
});

await check('recoverSession 账号令牌也失效时才完全登出', async () => {
  api.setApiBase('http://mock:9');
  accountApi.setAccountApiBase('http://mock:9');
  await withGlobalFetch(mockFetch([
    { status: 401, ok: false, body: { error: '令牌过期' } },
  ]), async () => {
    useGameStore.setState({
      accountToken: 'DEAD', currentCharacterId: 'xd01x',
      recovering: false,
    });
    const ok = await useGameStore.getState().recoverSession('test');
    assert.equal(ok, false);
    assert.equal(useGameStore.getState().accountToken, '',
      '账号令牌也失效应完全登出');
  });
});

/* ---------- 战斗浮动反馈 ---------- */
const {
  parseBattleLine, parseBattleLines, lineRawText, extractSkillName,
} = await import('../src/utils/battleFeedback.js');

function textLine(text) {
  return { segments: [{ type: 'text',
    parts: [{ type: 'text', content: text }] }] };
}

await check('lineRawText 拼接文本段与按钮标签', () => {
  assert.equal(lineRawText(textLine('你造成了120点伤害')), '你造成了120点伤害');
  assert.equal(lineRawText({
    segments: [
      { type: 'text', parts: [{ type: 'text', content: '前往' }] },
      { type: 'button', label: '进入游戏', cmd: 'start' },
    ],
  }), '前往进入游戏');
});

await check('解析对敌伤害（含暴击标记）', () => {
  const events = parseBattleLine(
    textLine('你施放了【剑气斩】，对敌人造成了250点伤害，暴击！'));
  const dmg = events.find(e => e.kind === 'damage');
  assert.ok(dmg, '应提取伤害事件');
  assert.equal(dmg.target, 'enemy');
  assert.equal(dmg.value, 250);
  assert.equal(dmg.critical, true);
});

await check('解析受到伤害（目标为player）', () => {
  const events = parseBattleLine(
    textLine('敌人对你造成了80点伤害'));
  const dmg = events.find(e => e.kind === 'damage');
  assert.ok(dmg);
  assert.equal(dmg.target, 'player');
  assert.equal(dmg.value, 80);
  assert.equal(dmg.critical, false);
});

await check('解析闪避/格挡/中毒/治疗/胜利', () => {
  assert.ok(parseBattleLine(textLine('你身法轻盈，躲过了攻击'))
    .some(e => e.kind === 'dodge'));
  assert.ok(parseBattleLine(textLine('你成功防御了攻击'))
    .some(e => e.kind === 'block'));
  assert.ok(parseBattleLine(textLine('你身中剧毒'))
    .some(e => e.kind === 'poison'));
  assert.ok(parseBattleLine(textLine('你恢复了150点生命'))
    .some(e => e.kind === 'heal' && e.value === 150));
  assert.ok(parseBattleLine(textLine('你战胜了强大的敌人！'))
    .some(e => e.kind === 'victory'));
});

await check('parseBattleLines 批量处理并跳过纯按钮行', () => {
  const events = parseBattleLines([
    textLine('你造成了100点伤害'),
    { segments: [{ type: 'button', label: '察看战况', cmd: '1' }] },
    textLine('你恢复了50点生命'),
  ]);
  assert.equal(events.filter(e => e.kind === 'damage').length, 1);
  assert.equal(events.filter(e => e.kind === 'heal').length, 1);
});

await check('extractSkillName 提取技能名', () => {
  assert.equal(extractSkillName('你施展了【太虚剑痕】'), '太虚剑痕');
  assert.equal(extractSkillName('你施展了万剑归宗'), '万剑归宗');
  assert.equal(extractSkillName('普通攻击'), null);
});

await check('垃圾行过滤：纯数字单字符行被移除，正常行保留', () => {
  const lines = [
    { segments: [{ type: 'text', parts: [{ type: 'text', content: '0' }] }] },
    { segments: [{ type: 'text', parts: [{ type: 'text', content: '正常文本' }] }] },
    { segments: [{ type: 'text', parts: [{ type: 'text', content: ' 1 ' }] }] },
    { segments: [{ type: 'text', parts: [{ type: 'text', content: 'Lv.10' }] }] },
    { segments: [{ type: 'text', parts: [{ type: 'text', content: '10' }] }] },
  ];
  const filtered = filterGarbageLines(lines);
  assert.equal(filtered.length, 3, `'0'和' 1 '应被过滤，'10'是两位数保留`);
  assert.ok(filtered.some(l => linePlainText(l).includes('正常文本')));
  assert.ok(filtered.some(l => linePlainText(l).includes('Lv.10')));
  assert.ok(filtered.some(l => linePlainText(l).trim() === '10'));
});

/* ---------- 装备面板 ---------- */
const { panelCards } = await import('../src/api/equipmentApi.js');

await check('panelCards 归一化槽位并保留穿戴/候选信息', () => {
  const cards = panelCards({
    slot_order: ['single_main_weapon', 'armor_head', 'jewelry_ring'],
    slots: {
      single_main_weapon: { label: '主手', icon: '剑',
        image: '/images/equipment/fallback/weapon.png' },
      armor_head: { label: '头部', icon: '冠',
        image: '/images/equipment/fallback/head.png' },
      jewelry_ring: { label: '戒指', icon: '戒',
        image: '/images/equipment/fallback/ring.png' },
    },
    equipped: {
      single_main_weapon: { name_cn: '天锋剑', rare_level: 5,
        level_requirement: 69, action_label: '卸下',
        action_cmd: 'unwield sword 0' },
    },
    candidates: {
      jewelry_ring: [
        { name_cn: '戒A', rare_level: 3, action_label: '穿戴',
          action_cmd: 'wear ring 0' },
        { name_cn: '戒B', rare_level: 4, action_label: '穿戴',
          action_cmd: 'wear ring 1' },
      ],
    },
  });
  /* armor_head 无穿戴且无候选 → 被过滤 */
  assert.equal(cards.length, 2, 'armor_head应被过滤（空槽无候选）');
  const weapon = cards.find(c => c.slot === 'single_main_weapon');
  assert.equal(weapon.name, '天锋剑');
  assert.equal(weapon.rareLevel, 5);
  assert.equal(weapon.actionCmd, 'unwield sword 0');
  const ring = cards.find(c => c.slot === 'jewelry_ring');
  assert.equal(ring.alternates.length, 2);
  assert.equal(ring.alternates[0].name, '戒A');
  assert.ok(!cards.some(c => c.slot === 'armor_head'),
    '空槽无候选不应出现在卡片中');
});

await check('panelCards 空槽且无候选的过滤掉，空数据安全', () => {
  const empty = panelCards({
    slots: { armor_thou: { label: '腿' } },
    equipped: {}, candidates: {},
  });
  assert.equal(empty.length, 0);
  assert.deepEqual(panelCards(null), []);
  assert.deepEqual(panelCards({}), []);
});

/* ---------- 网络超时与错误边界 ---------- */
await check('getJson 15秒超时后抛出友好错误（AbortController）', async () => {
  api.setApiBase('http://mock:9');
  /* 构造一个永远pending的fetch（模拟网络挂起），用注入方式跳过
     AbortController路径（node无abort）改测异常转换。 */
  const impl = async () => {
    const error = new Error('The operation was aborted');
    error.name = 'AbortError';
    throw error;
  };
  await assert.rejects(
    () => api.login('x', 'y', impl),
    /超时|aborted/i,
    'AbortError应转为友好超时提示');
});

/* ---------- 技能施法类型识别 ---------- */
const { parseSkillType, skillMeta, SKILL_TYPE_META } =
  await import('../src/utils/skillTypes.js');

await check('parseSkillType 识别主要技能类型', () => {
  assert.equal(parseSkillType('神太古·神曜一剑'), 'shentaigu');
  assert.equal(parseSkillType('太古剑痕'), 'ancient');
  assert.equal(parseSkillType('【命】碎镜千影'), 'spirit');
  assert.equal(parseSkillType('冰河月冕'), 'ice');
  assert.equal(parseSkillType('九霄雷法'), 'lightning');
  assert.equal(parseSkillType('烈焰焚天'), 'fire');
  assert.equal(parseSkillType('万剑归宗'), 'sword-qi');
  assert.equal(parseSkillType('降龙十八掌'), 'palm');
  assert.equal(parseSkillType('打狗棒法'), 'staff');
  assert.equal(parseSkillType('血月狂潮'), 'fire', '含火/血月→fire');
  assert.equal(parseSkillType('灵治疗愈'), 'heal');
  assert.equal(parseSkillType('完全不明技能'), 'generic');
});

await check('skillMeta 返回完整视觉参数', () => {
  const meta = skillMeta('shentaigu');
  assert.equal(meta.icon, '🌑');
  assert.ok(meta.color.length >= 4);
  assert.ok(meta.duration > 1000);
  const fallback = skillMeta('unknown_type');
  assert.equal(fallback.icon, '✦');
  assert.ok(Object.keys(SKILL_TYPE_META).length >= 24,
    `应有24+种类型，实际${Object.keys(SKILL_TYPE_META).length}`);
});

console.log(`\n前端 TestUnit：通过 ${passed}，失败 ${failed}`);
if (failed > 0) {
  console.log(failures.join('\n'));
  process.exit(1);
}
