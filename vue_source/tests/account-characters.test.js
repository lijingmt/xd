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
    location: { protocol: 'https:', hostname: 'game.example.com' },
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

assert.strictEqual(client.professionOptions.length, 10);
assert.deepStrictEqual(
  [...new Set(client.professionOptions.map(option => option.profession_id))].length,
  10
);
assert(client.professionOptions.some(option => option.profession_id === 'fangshi'));
assert(client.professionOptions.some(option => option.profession_id === 'lingyi'));

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
assert.strictEqual(sessionValues.get('mud_account_token'), 'a'.repeat(64));
assert.strictEqual(sessionValues.get('mud_account_id'), 'xd01legacy');

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
assert.strictEqual(sessionValues.has('mud_account_token'), false);

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
assert(!appSource.includes("sessionStorage.getItem('mud_txd') || this.txd"));

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
  assert.strictEqual(sessionValues.get('mud_txd'), firstTxd);
  assert.strictEqual(client.showLogin, false);

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

  console.log('account character frontend tests passed');
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
