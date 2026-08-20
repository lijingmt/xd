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
    history: { replaceState() {} },
    confirm() { return true; },
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

assert.strictEqual(client.professionOptions.length, 13);
assert.deepStrictEqual(
  [...new Set(client.professionOptions.map(option => option.profession_id))].length,
  13
);
assert(client.professionOptions.some(option => option.profession_id === 'fangshi'));
assert(client.professionOptions.some(option => option.profession_id === 'lingyi'));
assert(client.professionOptions.some(option => option.profession_id === 'wuxiang'));
assert(client.professionOptions.some(option => option.profession_id === 'taiji'));
assert(client.professionOptions.some(option => option.profession_id === 'zhaoming'));
assert.strictEqual(client.wuxiangUnlocked, false);
assert.strictEqual(client.taijiUnlocked, false);
assert.strictEqual(client.zhaomingUnlocked, false);
assert.strictEqual(client.s1HiddenProfession.completed_count, 0);
assert(!componentOptions.computed.visibleProfessionOptions.call(client)
  .some(option => option.profession_id === 'zhaoming'));

client.applyAccountData({
  token: 'a'.repeat(64),
  account_id: 'xd01legacy',
  limit: 10,
  shared_recharge_available: 1,
  shared_recharge_balance: 12345,
  illusion_entitled: 1,
  illusion_character_slots: 1,
  illusion_multi_character_unlocked: 0,
  illusion_expansion_spent_suiyu: 0,
  zhaoming_unlocked: 1,
  s1_hidden_profession: {
    unlocked: true,
    completed_count: 5,
    required_count: 5,
    required_level: 120,
    message: '已满足照命创建条件。'
  },
  illusion_realm: {
    ok: true,
    illusion_id: 'S1',
    display_name: '新月幻境·S1',
    phase: 'active',
    phase_name: '进行中',
    creation_open: true
  },
  characters: [{
    id: 'xd01legacy', profession_id: 'jianxian', realm_type: 'illusion',
    illusion_id: 'S1', illusion_state: 'active'
  }]
});
assert.strictEqual(client.accountId, 'xd01legacy');
assert.strictEqual(client.accountCharacters.length, 1);
assert.strictEqual(client.accountSharedRechargeAvailable, true);
assert.strictEqual(client.accountSharedRechargeBalance, 12345);
assert.strictEqual(client.illusionEntitled, true);
assert.strictEqual(client.illusionRealmStatus.illusion_id, 'S1');
assert.strictEqual(client.illusionRealmStatus.creation_open, true);
assert.strictEqual(client.illusionCharacterSlots, 1);
assert.strictEqual(client.illusionMultiCharacterUnlocked, false);
assert.strictEqual(client.illusionExpansionSpentSuiyu, 0);
assert.strictEqual(client.zhaomingUnlocked, true);
assert.strictEqual(client.s1HiddenProfession.completed_count, 5);
assert(!componentOptions.computed.visibleProfessionOptions.call(client)
  .some(option => option.profession_id === 'zhaoming'));
client.characterForm.realm_type = 'illusion';
assert(componentOptions.computed.visibleProfessionOptions.call(client)
  .some(option => option.profession_id === 'zhaoming'));
client.zhaomingUnlocked = false;
assert(!componentOptions.computed.visibleProfessionOptions.call(client)
  .some(option => option.profession_id === 'zhaoming'));
client.zhaomingUnlocked = true;
client.currentIllusionCharacterCount =
  componentOptions.computed.currentIllusionCharacterCount.call(client);
assert.strictEqual(client.currentIllusionCharacterCount, 1);
assert.strictEqual(
  componentOptions.computed.illusionCharacterCapacityReached.call(client),
  true
);
// sessionStorage 不再用于会话存储
// 使用 window.name 替代

client.chooseNewProfession(
  client.professionOptions.find(option => option.profession_id === 'jianxian')
);
assert.strictEqual(client.characterError, '');
assert.strictEqual(client.characterForm.race_id, 'human');
assert.strictEqual(client.characterForm.profession_id, 'jianxian');
assert.strictEqual(client.characterForm.sex, 'male');
assert.strictEqual(client.avatarChoicesFor('human', 'jianxian', 'male').length, 11);
assert.strictEqual(client.avatarChoicesFor('human', 'jianxian', 'female').length, 12);
client.characterForm.name_cn = '已命名人物';
client.characterForm.avatar_id = 'h_male3';
client.chooseNewProfession(
  client.professionOptions.find(option => option.profession_id === 'fangshi')
);
assert.strictEqual(client.characterForm.race_id, 'third');
assert.strictEqual(client.characterForm.profession_id, 'fangshi');
assert.strictEqual(client.characterForm.name_cn, '已命名人物');
assert.strictEqual(client.characterForm.avatar_id, 'h_male3');
assert.strictEqual(client.avatarChoicesFor('third', 'zhenyue', 'male')[0], 'zhenyue_male');
assert.strictEqual(client.avatarChoicesFor('monst', 'kuangyao', 'female').length, 11);
client.chooseCharacterSex('female');
assert.strictEqual(client.characterForm.sex, 'female');
assert.strictEqual(client.characterForm.avatar_id, 'h_female3');
client.chooseNewProfession(
  client.professionOptions.find(option => option.profession_id === 'kuangyao')
);
assert.strictEqual(client.characterForm.name_cn, '已命名人物');
assert.strictEqual(client.characterForm.avatar_id, 'm_female1');

client.currentCharacterId = 'xd01legacy';
client.maybePromptCharacterProfile({
  profile_complete: false,
  profile_needs_name: true,
  profile_needs_sex: false,
  profile_needs_avatar: true,
  name_cn: '无名剑客',
  sex: 'male',
  race_id: 'human',
  profession_id: 'jianxian',
  avatar_id: '',
  profile_avatar_choices: ['h_male1', 'h_male2']
});
assert.strictEqual(client.characterProfileOpen, true);
assert.strictEqual(client.characterProfileForm.name_cn, '');
assert.strictEqual(client.characterProfileForm.sex, 'male');
client.skipCharacterProfile();
assert.strictEqual(client.characterProfileOpen, false);
assert.strictEqual(client.characterProfileDismissedFor, 'xd01legacy');

client.clearAccountSession();
assert.strictEqual(client.accountToken, '');
assert.strictEqual(client.accountSharedRechargeBalance, 0);
assert.strictEqual(client.accountSharedRechargeAvailable, true);
// sessionStorage 不再清除（自动浏览器共享修复）；只验证 Vue 状态被清空
// assert.strictEqual(sessionValues.has('mud_account_token'), false);

assert(indexSource.includes('v-if="showCharacterSelect"'));
assert(indexSource.includes('@click="openCharacterCenter"'));
assert(indexSource.includes('@click="createAccountCharacter"'));
assert(indexSource.includes('v-model.trim="characterForm.name_cn"'));
assert(indexSource.includes('v-for="avatar in characterAvatarOptions"'));
assert(indexSource.includes('v-if="characterProfileOpen"'));
assert(indexSource.includes('@click="skipCharacterProfile"'));
assert(indexSource.includes('!showRegister && !showCharacterSelect'));
assert(indexSource.includes('注册账号共享充值余额'));
assert(indexSource.includes('人物赠送玉石仍各自独立'));
assert(indexSource.includes('同职业可重复创建'));
assert(indexSource.includes("characterForm.realm_type === 'illusion'"));
assert(indexSource.includes('新月幻境·S1'));
assert(indexSource.includes('期满原档案回归'));
assert(indexSource.includes('@click="activateIllusionEntitlement"'));
assert(indexSource.includes("'赛季资格（人物栏位另付费）'"));
assert(indexSource.includes('登记本身不扣费'));
assert(indexSource.includes('创建首个及后续每个人物都需购买100碎玉栏位'));
assert(!indexSource.includes('请先进入现有人物，从“幻境区”免费激活'));
assert(indexSource.includes('直接付费扩充后继续创建'));
assert(indexSource.includes('碎玉增加1格'));
assert(indexSource.includes('碎玉一次购买5格'));
assert(indexSource.includes('btn btn-secondary illusion-expansion-all-btn'));
assert(indexSource.includes("@click=\"expandIllusionCapacity('one')\""));
assert(indexSource.includes("@click=\"expandIllusionCapacity('all')\""));
assert(indexSource.includes('不会消费任何人物背包玉石'));
assert(indexSource.includes('本期不开放家园'));
assert(!indexSource.includes(':disabled="accountCharacters.some(character => character.profession_id === option.profession_id)"'));
assert(cssSource.includes('.character-modal'));
assert(cssSource.includes('.character-wallet'));
assert(cssSource.includes('.profession-choice-grid'));
assert(cssSource.includes('.character-avatar-grid'));
assert(cssSource.includes('.character-profile-modal'));
assert(cssSource.includes('.character-card.illusion'));
assert(cssSource.includes('.character-realm-choice'));
assert(cssSource.includes('.btn.illusion-expansion-all-btn'));
assert(cssSource.includes('background: linear-gradient(135deg, #6d28d9, #4c1d95)'));
assert(cssSource.includes('color: #fff'));
assert(appSource.includes("'/api/account/login'"));
assert(appSource.includes("postAccountApi('/api/account/characters'"));
assert(appSource.includes("'/api/account/illusion/activate'"));
assert(appSource.includes("'/api/account/illusion/expand'"));
assert(appSource.includes('realm_type: this.characterForm.realm_type'));
assert(!appSource.includes("'/api/account/characters?'"));
assert(appSource.includes("'/api/account/characters/select'"));
assert(appSource.includes("this.apiBase + '/api/profile'"));
assert(appSource.includes('maybePromptCharacterProfile(data)'));
assert(appSource.includes('error.status === 404 || error.status === 501'));
assert(appSource.includes('characterSessionEpoch'));
assert(appSource.includes('invalidateCharacterSessionRequests'));
assert(appSource.includes('handleForcedCharacterLogout'));
assert(appSource.includes('response.status === 409 && data.forced_logout'));
// sessionStorage 不再用于 txd 恢复

(async () => {
	const activationClient = Object.assign(
		componentOptions.data(), componentOptions.methods
	);
	activationClient.accountToken = '9'.repeat(64);
	activationClient.characterCreateOpen = true;
	activationClient.characterForm.name_cn = '保留姓名';
	activationClient.characterForm.avatar_id = 'h_male2';
	activationClient.illusionRealmStatus = {
		ok: true,
		illusion_id: 'S1',
		creation_open: true,
		entitlement_cost_suiyu: 0
	};
	let activationBody = null;
	activationClient.postAccountApi = async (path, body) => {
		assert.strictEqual(path, '/api/account/illusion/activate');
		activationBody = body;
		return {
			account_id: 'xd01activation',
			illusion_entitled: 1,
			illusion_character_slots: 0,
			illusion_realm: {
				ok: true,
				illusion_id: 'S1',
				creation_open: true,
				entitlement_cost_suiyu: 0
			},
			characters: [],
			activation: { message: '账号已登记S1赛季资格。' }
		};
	};
	await activationClient.activateIllusionEntitlement();
	// component methods execute inside a VM context; compare scalar fields so
	// the assertion does not depend on cross-realm object prototypes.
	assert.strictEqual(Object.keys(activationBody).length, 1);
	assert.strictEqual(activationBody.token, '9'.repeat(64));
	assert.strictEqual(activationClient.illusionEntitled, true);
	assert.strictEqual(activationClient.characterForm.realm_type, 'illusion');
	assert.strictEqual(activationClient.characterForm.name_cn, '保留姓名');
	assert.strictEqual(activationClient.characterForm.avatar_id, 'h_male2');
	assert(activationClient.illusionActivationMessage.includes('S1赛季资格'));
	assert.strictEqual(activationClient.illusionActivating, false);

	const paidActivationClient = Object.assign(
		componentOptions.data(), componentOptions.methods
	);
	paidActivationClient.accountToken = '8'.repeat(64);
	paidActivationClient.illusionRealmStatus = {
		ok: true,
		entitlement_cost_suiyu: 10
	};
	let paidActivationCalled = false;
	paidActivationClient.postAccountApi = async () => {
		paidActivationCalled = true;
	};
	await paidActivationClient.activateIllusionEntitlement();
	assert.strictEqual(paidActivationCalled, false);
	assert(paidActivationClient.characterError.includes('不能在人物中心直接登记'));

	const expansionClient = Object.assign(
		componentOptions.data(), componentOptions.methods
	);
	expansionClient.accountToken = '7'.repeat(64);
	expansionClient.accountId = 'xd01expansion';
	expansionClient.illusionEntitled = true;
	expansionClient.accountSharedRechargeAvailable = true;
	expansionClient.accountSharedRechargeBalance = 500;
	expansionClient.illusionCharacterSlots = 1;
	expansionClient.illusionExpansionSpentSuiyu = 0;
	expansionClient.illusionRealmStatus = {
		ok: true,
		illusion_id: 'S1',
		creation_open: true,
		extra_character_slot_cost_suiyu: 100,
		multi_character_unlock_cost_suiyu: 500
	};
	expansionClient.illusionExpansionSingleCost = 100;
	expansionClient.illusionExpansionRemainingCost = 500;
	expansionClient.illusionCharacterCapacityReached = false;
	let expansionPath = '';
	let expansionBody = null;
	expansionClient.postAccountApi = async (path, body) => {
		expansionPath = path;
		expansionBody = body;
		return {
			account_id: 'xd01expansion',
			shared_recharge_available: 1,
			shared_recharge_balance: 400,
			illusion_entitled: 1,
			illusion_character_slots: 2,
			illusion_multi_character_unlocked: 0,
			illusion_expansion_spent_suiyu: 100,
			illusion_realm: expansionClient.illusionRealmStatus,
			characters: [{
				id: 'xd01expansion', realm_type: 'illusion', illusion_id: 'S1'
			}],
			expansion: { message: '已增加1个本期幻境人物栏位。' }
		};
	};
	await expansionClient.expandIllusionCapacity('one');
	assert.strictEqual(expansionPath, '/api/account/illusion/expand');
	assert.strictEqual(expansionBody.token, '7'.repeat(64));
	assert.strictEqual(expansionBody.option, 'one');
	assert(/^[0-9a-f]{64}$/.test(expansionBody.request_id));
	assert.strictEqual(expansionClient.accountSharedRechargeBalance, 400);
	assert.strictEqual(expansionClient.illusionCharacterSlots, 2);
	assert.strictEqual(expansionClient.characterForm.realm_type, 'illusion');
	assert(expansionClient.illusionExpansionMessage.includes('增加1个'));
	assert.strictEqual(expansionClient.illusionExpansionPendingRequest, null);
	assert.strictEqual(expansionClient.illusionExpanding, false);

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

  // 角色直达书签：一次点击必须先同步打开新标签，再从服务端签发只绑定
  // 所选人物的长期随机凭证。凭证放fragment，禁止TXD/密码进入URL。
  client.accountId = 'xd01abc';
  client.accountToken = 'd'.repeat(64);
  client.currentCharacterId = 'xd01firsthero';
  client.txd = firstTxd;
  sandbox.window.location.href =
    'https://game.example.com/xd/vue/?mode=html&txd=legacy-secret&token=unknown-secret&ref=wrong#old-secret';
  // 测试环境没有真实 DOM/clipboard，stub 掉通知和剪贴板写
  client.showNotification = () => {};
  let copiedUrl = '';
  sandbox.navigator = {
    platform: 'MacIntel',
    clipboard: {
      writeText: async (text) => { copiedUrl = text; }
    }
  };
  let openedUrl = '';
  let openedTarget = '';
  let openCount = 0;
  const popup = {
    opener: {},
    location: { replace: (url) => { openedUrl = url; } }
  };
  sandbox.window.open = (url, target) => {
    assert.strictEqual(url, 'about:blank');
    openedTarget = target;
    openCount += 1;
    popup.opener = {};
    return popup;
  };
  let issuedBookmark = '1'.repeat(64);
  client.postAccountApi = async (path, body) => {
    assert.strictEqual(path, '/api/account/bookmark/create');
    assert.strictEqual(body.token, 'd'.repeat(64));
    assert(body.character_id);
    return { bookmark_token: issuedBookmark };
  };
  // 当前在线 A，存并打开 B 的书签：新标签与复制文本必须是同一个
  // 跨浏览器永久入口，而不是当前账号的12小时会话。
  await client.copyCharacterBookmarkUrl('xd01abcc2a8f31e20');
  const bookmarkUrl = new URL(copiedUrl, 'https://game.example.com');
  assert.strictEqual(bookmarkUrl.searchParams.get('userid'), 'xd01abc');
  assert.strictEqual(bookmarkUrl.searchParams.get('char'), 'xd01abcc2a8f31e20');
  assert.strictEqual(bookmarkUrl.searchParams.get('txd'), null,
    '复制其他角色书签时不应附上当前角色的 txd');
  assert.strictEqual(bookmarkUrl.searchParams.get('token'), null);
  assert.strictEqual(bookmarkUrl.searchParams.get('ref'), null);
  assert.strictEqual(bookmarkUrl.searchParams.get('mode'), 'html',
    '自动浏览器的HTML兼容模式必须保留');
  assert.strictEqual(
    new URLSearchParams(bookmarkUrl.hash.slice(1)).get('character_bookmark'),
    issuedBookmark
  );
  assert.strictEqual(
    new URLSearchParams(bookmarkUrl.hash.slice(1)).get('account_session'),
    null,
    '长期书签不能退化为重启即失效的账号内存会话'
  );
  assert.strictEqual(openedTarget, '_blank');
  assert.strictEqual(popup.opener, null,
    '导航前必须切断 opener，避免新标签反向控制原页面');
  let newTabUrl = new URL(openedUrl, 'https://game.example.com');
  assert.strictEqual(newTabUrl.searchParams.get('userid'), 'xd01abc');
  assert.strictEqual(newTabUrl.searchParams.get('char'), 'xd01abcc2a8f31e20');
  assert.strictEqual(newTabUrl.searchParams.get('txd'), null);
  assert.strictEqual(
    new URLSearchParams(newTabUrl.hash.slice(1)).get('character_bookmark'),
    issuedBookmark
  );

  // 当前在线 A，复制 A 的书签也不得把可还原密码的旧 txd 放进去。
  issuedBookmark = '2'.repeat(64);
  await client.copyCharacterBookmarkUrl('xd01firsthero');
  const selfBookmarkUrl = new URL(copiedUrl, 'https://game.example.com');
  assert.strictEqual(selfBookmarkUrl.searchParams.get('userid'), 'xd01abc');
  assert.strictEqual(selfBookmarkUrl.searchParams.get('char'), 'xd01firsthero');
  assert.strictEqual(selfBookmarkUrl.searchParams.get('txd'), null,
    '复制当前角色书签也不得泄露可还原密码的 txd');
  assert.strictEqual(openCount, 2, '每次点击书签按钮都应同步打开一个新标签');
  assert.strictEqual(
    new URLSearchParams(selfBookmarkUrl.hash.slice(1)).get('character_bookmark'),
    issuedBookmark
  );

  // 复制到完全没有账号session的浏览器后，长期凭证应直接换取绑定人物
  // 的TXD并进入游戏，且不能被本地缓存的另一个角色覆盖。
  const persistentClient = Object.assign(componentOptions.data(), componentOptions.methods);
  persistentClient.characterBookmarkToken = '3'.repeat(64);
  persistentClient.preselectedUserid = 'xd01LSQ';
  persistentClient.preselectedCharacterId = 'xd01LSQ_wuxiang';
  persistentClient.apiBase = '';
  persistentClient.showNotification = () => {};
  let persistentOpenBody = null;
  persistentClient.postAccountApi = async (path, body) => {
    assert.strictEqual(path, '/api/account/bookmark/open');
    persistentOpenBody = body;
    return {
      account_id: 'xd01LSQ',
      character_id: 'xd01LSQ_wuxiang',
      txd: 'bookmark-direct-txd',
      bootstrap_command: 'init'
    };
  };
  persistentClient.completeCharacterLogin = async (txd, characterId) => {
    assert.strictEqual(txd, 'bookmark-direct-txd');
    persistentClient.currentCharacterId = characterId;
    return true;
  };
  assert.strictEqual(await persistentClient.resumePersistentCharacterBookmark(), true);
  assert.strictEqual(persistentOpenBody.userid, 'xd01LSQ');
  assert.strictEqual(persistentOpenBody.character_id, 'xd01LSQ_wuxiang');
  assert.strictEqual(persistentOpenBody.bookmark_token, '3'.repeat(64));
  assert.strictEqual(persistentClient.accountToken, '',
    '人物书签不应升级为可读取账号其他人物的账号会话');

  // 书签登录框通常输入短账号；必须与链接里的完整大小写账号匹配并
  // 登录后直接进入指定职业。
  const bookmarkClient = Object.assign(componentOptions.data(), componentOptions.methods);
  bookmarkClient.loginForm = {
    partition: 'xd01', userid: 'LSQ', password: 'CasePass88'
  };
  bookmarkClient.preselectedUserid = 'xd01LSQ';
  bookmarkClient.preselectedCharacterId = 'xd01LSQ_wuxiang';
  let loginUserid = '';
  let selectedBookmarkCharacter = '';
  bookmarkClient.postAccountApi = async (path, body) => {
    assert.strictEqual(path, '/api/account/login');
    loginUserid = body.userid;
    return {
      token: 'e'.repeat(64),
      account_id: 'xd01LSQ',
      characters: [{ id: 'xd01LSQ_wuxiang', available: 1 }]
    };
  };
  bookmarkClient.selectAccountCharacter = async character => {
    selectedBookmarkCharacter = character.id;
  };
  await bookmarkClient.doLogin();
  assert.strictEqual(loginUserid, 'xd01LSQ');
  assert.strictEqual(selectedBookmarkCharacter, 'xd01LSQ_wuxiang');

  const handoffClient = Object.assign(componentOptions.data(), componentOptions.methods);
  handoffClient.accountToken = 'f'.repeat(64);
  handoffClient.preselectedUserid = 'xd01LSQ';
  handoffClient.preselectedCharacterId = 'xd01LSQ_wuxiang';
  handoffClient.postAccountApi = async (path, body) => {
    assert.strictEqual(path, '/api/account/characters');
    assert.strictEqual(body.token, 'f'.repeat(64));
    return {
      account_id: 'xd01LSQ',
      characters: [{ id: 'xd01LSQ_wuxiang', available: 1 }]
    };
  };
  handoffClient.selectAccountCharacter = async character => {
    handoffClient.currentCharacterId = character.id;
  };
  assert.strictEqual(await handoffClient.resumeCharacterBookmarkHandoff(), true);
  assert.strictEqual(handoffClient.currentCharacterId, 'xd01LSQ_wuxiang');

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
  assert(appSource.includes('const bookmarkMatch = bookmarkAccountMatched'),
    'app.js 应在 doLogin 中实现书签角色匹配逻辑');

  // 静态契约：UI 和源码必须包含书签相关结构和逻辑
  assert(indexSource.includes('character-card-wrap'),
    'index.html 应使用 character-card-wrap 包裹卡片以承载复制书签按钮');
  assert(indexSource.includes('character-bookmark-btn'),
    'index.html 应在每个角色卡片上提供复制书签按钮');
  assert(indexSource.includes('copyCharacterBookmarkUrl(character.id)'),
    'index.html 应把复制按钮绑定到 copyCharacterBookmarkUrl');
  assert(indexSource.includes('存书签并在新标签打开本角色'),
    'index.html 应把存书签与新标签直达合并为一个清晰入口');
  assert(indexSource.includes('revokeCharacterBookmarks(character.id)'),
    'index.html 应提供可见的逐人物书签撤销入口');
  assert(cssSource.includes('.character-bookmark-btn'),
    'app.css 应为复制书签按钮提供样式');
  assert(appSource.includes('resumeCharacterBookmarkHandoff'),
    'app.js 应支持新标签安全接续账号会话');
  assert(appSource.includes('resumePersistentCharacterBookmark'),
    'app.js 应支持无登录态浏览器使用长期人物书签直接进入');

  console.log('account character frontend tests passed');
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
