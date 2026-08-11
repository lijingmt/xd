const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

let componentOptions = null;
const sessionValues = new Map();
const sandbox = {
  Vue: {
    createApp(options) {
      componentOptions = options;
      return { mount() {} };
    }
  },
  window: {
    crypto: {},
    location: { protocol: 'https:', hostname: 'game.example.com', href: 'https://game.example.com/' },
    matchMedia() { return { matches: false }; }
  },
  document: { documentElement: { setAttribute() {} } },
  localStorage: { getItem() { return null; }, setItem() {} },
  sessionStorage: {
    getItem(key) { return sessionValues.get(key) || null; },
    setItem(key, value) { sessionValues.set(key, value); },
    removeItem(key) { sessionValues.delete(key); }
  },
  console,
  TextEncoder,
  URLSearchParams,
  URL,
  btoa(value) { return Buffer.from(value, 'binary').toString('base64'); },
  setTimeout,
  clearTimeout,
  setInterval() { return 1; },
  clearInterval() {},
  fetch: async () => ({ ok: true, json: async () => ({}) })
};

const appSource = fs.readFileSync(
  path.join(__dirname, '..', 'js', 'app.js'), 'utf8'
);
const indexSource = fs.readFileSync(
  path.join(__dirname, '..', 'index.html'), 'utf8'
);
const cssSource = fs.readFileSync(
  path.join(__dirname, '..', 'css', 'app.css'), 'utf8'
);
vm.runInNewContext(appSource, sandbox, { filename: 'app.js' });

assert(componentOptions, 'Vue component should register');
const client = Object.assign(componentOptions.data(), componentOptions.methods);

assert.strictEqual(client.professionOptions.length, 12);
assert.deepStrictEqual(
  [...new Set(client.professionOptions.map(option => option.profession_id))].length,
  12
);
assert(client.professionOptions.some(option => option.profession_id === 'fangshi'));
assert(client.professionOptions.some(option => option.profession_id === 'lingyi'));
assert(client.professionOptions.some(option => option.profession_id === 'wuxiang'));
assert(client.professionOptions.some(option => option.profession_id === 'taiji'));
assert.strictEqual(client.wuxiangUnlocked, false);
assert.strictEqual(client.taijiUnlocked, false);

client.applyAccountData({
  token: 'a'.repeat(64),
  account_id: 'xd01legacy',
  limit: 10,
  shared_recharge_available: 1,
  shared_recharge_balance: 12345,
  characters: [{ id: 'xd01legacy', profession_id: 'jianxian' }]
});
assert.strictEqual(client.accountId, 'xd01legacy');
assert.strictEqual(client.accountCharacters.length, 1);
assert.strictEqual(client.accountSharedRechargeAvailable, true);
assert.strictEqual(client.accountSharedRechargeBalance, 12345);
// sessionStorage 不再用于会话存储
// 使用 window.name 替代

client.chooseNewProfession(
  client.professionOptions.find(option => option.profession_id === 'jianxian')
);
assert.strictEqual(client.characterError, '');
assert.strictEqual(client.characterForm.race_id, 'human');
assert.strictEqual(client.characterForm.profession_id, 'jianxian');
client.chooseNewProfession(
  client.professionOptions.find(option => option.profession_id === 'fangshi')
);
assert.strictEqual(client.characterForm.race_id, 'third');
assert.strictEqual(client.characterForm.profession_id, 'fangshi');

client.clearAccountSession();
assert.strictEqual(client.accountToken, '');
assert.strictEqual(client.accountSharedRechargeBalance, 0);
assert.strictEqual(client.accountSharedRechargeAvailable, true);
// sessionStorage 不再清除（自动浏览器共享修复）；只验证 Vue 状态被清空
// assert.strictEqual(sessionValues.has('mud_account_token'), false);

assert(indexSource.includes('v-if="showCharacterSelect"'));
assert(indexSource.includes('@click="openCharacterCenter"'));
assert(indexSource.includes('@click="createAccountCharacter"'));
assert(indexSource.includes('!showRegister && !showCharacterSelect'));
assert(indexSource.includes('注册账号共享充值余额'));
assert(indexSource.includes('人物赠送玉石仍各自独立'));
assert(indexSource.includes('同职业可重复创建'));
assert(!indexSource.includes(':disabled="accountCharacters.some(character => character.profession_id === option.profession_id)"'));
assert(cssSource.includes('.character-modal'));
assert(cssSource.includes('.character-wallet'));
assert(cssSource.includes('.profession-choice-grid'));
assert(appSource.includes("'/api/account/login'"));
assert(appSource.includes("postAccountApi('/api/account/characters'"));
assert(!appSource.includes("'/api/account/characters?'"));
assert(appSource.includes("'/api/account/characters/select'"));
assert(appSource.includes('error.status === 404 || error.status === 501'));
assert(appSource.includes('characterSessionEpoch'));
assert(appSource.includes('invalidateCharacterSessionRequests'));
assert(appSource.includes('handleForcedCharacterLogout'));
assert(appSource.includes('response.status === 409 && data.forced_logout'));
// sessionStorage 不再用于 txd 恢复

(async () => {
  const firstTxd = client.encodeTxd('xd01firsthero', 'test88');
  const secondTxd = client.encodeTxd('xd01secondhero', 'test88');
  client.txd = firstTxd;
  client.currentCharacterId = 'xd01firsthero';
  client.playerStats = { autofight: true };
  client.mudLines = [{ marker: 'first-before-switch' }];

  let resolveOldAutofight = null;
  sandbox.fetch = () => new Promise(resolve => {
    resolveOldAutofight = resolve;
  });
  const oldAutofightRequest = client.sendJsonCommand('flushview');
  while (!resolveOldAutofight) await Promise.resolve();

  client.invalidateCharacterSessionRequests();
  client.txd = secondTxd;
  client.currentCharacterId = 'xd01secondhero';
  client.mudLines = [{ marker: 'second-after-switch' }];
  sessionValues.set('mud_txd', secondTxd);
  resolveOldAutofight({
    ok: true,
    status: 200,
    json: async () => ({
      userid: 'xd01firsthero',
      txd: firstTxd,
      lines: [{ marker: 'stale-first-response' }]
    })
  });
  await oldAutofightRequest;
  assert.strictEqual(client.txd, secondTxd);
  assert.strictEqual(client.currentCharacterId, 'xd01secondhero');
  assert.strictEqual(client.mudLines[0].marker, 'second-after-switch');

  // 自动重登必须使用发起失败请求时捕获的人物TXD；浏览器缓存即使已
  // 切到另一个职业，也不能把旧命令重放给新人物。
  client.txd = firstTxd;
  client.currentCharacterId = 'xd01firsthero';
  client.showLogin = false;
  const reloginEpoch = client.characterSessionEpoch;
  sessionValues.set('mud_txd', secondTxd);
  let reloginUrl = '';
  sandbox.fetch = async url => {
    reloginUrl = String(url);
    return {
      ok: true,
      status: 200,
      json: async () => ({
        userid: 'xd01firsthero', txd: firstTxd, lines: []
      })
    };
  };
  const relogged = await client.relogin(firstTxd, reloginEpoch);
  const reloginParams = new URL(reloginUrl, 'https://game.example.com').searchParams;
  assert.strictEqual(relogged, true);
  assert.strictEqual(reloginParams.get('userid'), 'xd01firsthero');
  assert.strictEqual(client.txd, firstTxd);
  
  assert.strictEqual(client.showLogin, false);

  // 历史人物ID可含大写字母。请求必须保留精确大小写，
  // 后端若返回另一个大小写变体，前端必须拒绝以防串档。
  const mixedCaseUserid = 'xd01LSQ2026';
  const mixedCaseTxd = client.encodeTxd(mixedCaseUserid, 'CasePass88');
  let mixedCaseUrl = '';
  client.invalidateCharacterSessionRequests();
  client.txd = mixedCaseTxd;
  client.currentCharacterId = mixedCaseUserid;
  client.showLogin = false;
  const mixedCaseEpoch = client.characterSessionEpoch;
  sandbox.fetch = async url => {
    mixedCaseUrl = String(url);
    return {
      ok: true,
      status: 200,
      json: async () => ({
        userid: mixedCaseUserid.toLowerCase(),
        txd: client.encodeTxd(mixedCaseUserid.toLowerCase(), 'CasePass88'),
        lines: []
      })
    };
  };
  const mixedCaseRelogged = await client.relogin(mixedCaseTxd, mixedCaseEpoch);
  const mixedCaseParams = new URL(
    mixedCaseUrl, 'https://game.example.com'
  ).searchParams;
  assert.strictEqual(mixedCaseParams.get('userid'), mixedCaseUserid);
  assert.strictEqual(mixedCaseRelogged, false);
  assert.strictEqual(client.showLogin, true);
  assert.strictEqual(client.txd, mixedCaseTxd);

  // 创建后职业初始化若由后端返回500，必须留在选角页并允许重试，
  // 不能把错误文字当成正常MUD页面覆盖当前人物会话。
  client.accountToken = 'c'.repeat(64);
  client.characterLoading = false;
  client.characterError = '';
  client.showCharacterSelect = true;
  client.currentCharacterId = 'xd01firsthero';
  client.postAccountApi = async path => {
    assert.strictEqual(path, '/api/account/characters/select');
    return {
      txd: secondTxd,
      character_id: 'xd01secondhero',
      bootstrap_command: 'choice_profe third/fangshi'
    };
  };
  sandbox.fetch = async () => ({
    ok: false,
    status: 500,
    json: async () => ({ error: '游戏命令执行失败，请重试' })
  });
  await client.selectAccountCharacter({ id: 'xd01secondhero' });
  assert.strictEqual(client.showCharacterSelect, true);
  assert.strictEqual(client.currentCharacterId, 'xd01firsthero');
  assert(client.characterError.includes('请重试'));

  // 达到账号同时在线上限后，被清退标签页必须停在人物中心，不能
  // flushview自动重登并继续清退同账号下另一个正在玩的职业。
  client.accountToken = 'd'.repeat(64);
  client.txd = firstTxd;
  client.currentCharacterId = 'xd01firsthero';
  client.playerStats = { autofight: true };
  client.statsInterval = 11;
  client.autofightInterval = 12;
  client.battleStatusInterval = 13;
  client.chatPollingInterval = 14;
  client.showLogin = false;
  client.showCharacterSelect = false;
  sessionValues.set('mud_txd', firstTxd);
  sessionValues.set('mud_character_id', 'xd01firsthero');
  let forcedLogoutRequests = 0;
  sandbox.fetch = async () => {
    forcedLogoutRequests += 1;
    return {
      ok: false,
      status: 409,
      json: async () => ({
        error: '同账号在线人物已达到上限，当前人物已安全退出，请重新选择人物。',
        forced_logout: 1,
        reason: 'online_limit_reached',
        online_limit: 5
      })
    };
  };
  await client.sendJsonCommand('flushview');
  assert.strictEqual(forcedLogoutRequests, 1);
  assert.strictEqual(client.txd, '');
  assert.strictEqual(client.currentCharacterId, '');
  assert.strictEqual(client.accountToken, 'd'.repeat(64));
  assert.strictEqual(client.showCharacterSelect, true);
  assert.strictEqual(client.showLogin, false);
  assert.strictEqual(client.statsInterval, null);
  assert.strictEqual(client.autofightInterval, null);
  assert.strictEqual(client.battleStatusInterval, null);
  assert.strictEqual(client.chatPollingInterval, null);
  // sessionStorage 不再清除（自动浏览器共享修复）；只验证 Vue 状态和定时器被清空
  assert.strictEqual(client.txd, '');
  assert(client.characterError.includes('重新选择人物'));

  // 角色直达书签：copyCharacterBookmarkUrl 应生成 ?userid=&char= 格式的 URL，
  // 仅当当前在线角色就是目标角色时才附上 txd（避免把 A 角色的 txd 误塞到 B 角色的书签里）。
  client.accountId = 'xd01abc';
  client.currentCharacterId = 'xd01firsthero';
  client.txd = firstTxd;
  // 测试环境没有真实 DOM/clipboard，stub 掉通知和剪贴板写
  client.showNotification = () => {};
  let copiedUrl = '';
  sandbox.navigator = {
    clipboard: {
      writeText: async (text) => { copiedUrl = text; }
    }
  };
  // 当前在线 A，复制 B 的书签：不应带 txd
  await client.copyCharacterBookmarkUrl('xd01abcc2a8f31e20');
  const bookmarkUrl = new URL(copiedUrl, 'https://game.example.com');
  assert.strictEqual(bookmarkUrl.searchParams.get('userid'), 'xd01abc');
  assert.strictEqual(bookmarkUrl.searchParams.get('char'), 'xd01abcc2a8f31e20');
  assert.strictEqual(bookmarkUrl.searchParams.get('txd'), null,
    '复制其他角色书签时不应附上当前角色的 txd');
  // 当前在线 A，复制 A 的书签：应附上 txd（同角色 txd 可立即进入）
  await client.copyCharacterBookmarkUrl('xd01firsthero');
  const selfBookmarkUrl = new URL(copiedUrl, 'https://game.example.com');
  assert.strictEqual(selfBookmarkUrl.searchParams.get('userid'), 'xd01abc');
  assert.strictEqual(selfBookmarkUrl.searchParams.get('char'), 'xd01firsthero');
  assert.strictEqual(selfBookmarkUrl.searchParams.get('txd'), firstTxd,
    '复制当前角色书签应附上 txd 以支持立即进入');

  let openedUrl = '';
  let openedTarget = '';
  const popup = {
    opener: {},
    location: { replace: (url) => { openedUrl = url; } }
  };
  sandbox.window.open = (url, target) => {
    assert.strictEqual(url, 'about:blank');
    openedTarget = target;
    return popup;
  };
  client.openAccountCharacterInNewTab('xd01abcc2a8f31e20');
  assert.strictEqual(openedTarget, '_blank');
  assert.strictEqual(popup.opener, null,
    '导航前必须切断 opener，避免新标签反向控制原页面');
  const newTabUrl = new URL(openedUrl, 'https://game.example.com');
  assert.strictEqual(newTabUrl.searchParams.get('userid'), 'xd01abc');
  assert.strictEqual(newTabUrl.searchParams.get('char'), 'xd01abcc2a8f31e20');
  assert.strictEqual(newTabUrl.searchParams.get('txd'), null,
    '新标签不得携带当前角色 txd，否则会把原标签挤下线');

  // doLogin 书签逻辑的静态契约：源码必须包含 preselectedUserid 优先级判断和 char 匹配。
  // 完整端到端流程（account/login + characters/select + completeCharacterLogin）依赖
  // 现有 selectAccountCharacter 测试覆盖，这里只验证新逻辑的源码存在性。
  assert(appSource.includes('preselectedUserid'),
    'app.js 应包含 preselectedUserid 状态字段');
  assert(appSource.includes('preselectedCharacterId'),
    'app.js 应包含 preselectedCharacterId 状态字段');
  assert(appSource.includes("urlParams.get('userid')"),
    'app.js 应从 URL 读取 userid 参数');
  assert(appSource.includes("urlParams.get('char')"),
    'app.js 应从 URL 读取 char 参数');
  assert(appSource.includes('const bookmarkMatch = (!userInput || userInput === this.preselectedUserid)'),
    'app.js 应在 doLogin 中实现书签角色匹配逻辑');

  // 静态契约：UI 和源码必须包含书签相关结构和逻辑
  assert(indexSource.includes('character-card-wrap'),
    'index.html 应使用 character-card-wrap 包裹卡片以承载复制书签按钮');
  assert(indexSource.includes('character-bookmark-btn'),
    'index.html 应在每个角色卡片上提供复制书签按钮');
  assert(indexSource.includes('copyCharacterBookmarkUrl(character.id)'),
    'index.html 应把复制按钮绑定到 copyCharacterBookmarkUrl');
  assert(indexSource.includes('openAccountCharacterInNewTab(character.id)'),
    'index.html 应提供不会重复当前人物登录的新标签入口');
  assert(cssSource.includes('.character-bookmark-btn'),
    'app.css 应为复制书签按钮提供样式');
  assert(cssSource.includes('.character-new-tab-btn'),
    'app.css 应为新标签人物入口提供样式');

  console.log('account character frontend tests passed');
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
