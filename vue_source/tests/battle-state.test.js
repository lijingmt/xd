const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

let componentOptions = null;
let nextBattleState = {
  in_battle: true,
  player: {
    name_cn: '测试方士', hp: 90, hp_max: 100,
    mana: 70, mana_max: 80, level: 9, profe: '方士', race: '中立'
  },
  enemy: {
    name: 'test_enemy', name_cn: '测试怪物', hp: 40, hp_max: 50,
    is_npc: true, level: 8, profe: '野怪', race: '妖魔',
    attack: 123, attack_low: 100, attack_high: 123, defend: 45
  }
};
const sessionValues = new Map();
const localValues = new Map();
const documentAttributes = new Map();
let requestedLoginUrl = '';

const sandbox = {
  Vue: {
    createApp(options) {
      componentOptions = options;
      return { mount() {} };
    }
  },
  window: {
    crypto: {},
    location: { protocol: 'https:', hostname: 'game.example.com' }
  },
  document: {
    hidden: false,
    documentElement: {
      setAttribute(name, value) {
        documentAttributes.set(name, value);
      }
    }
  },
  localStorage: {
    getItem(key) {
      return localValues.get(key) || null;
    },
    setItem(key, value) {
      localValues.set(key, value);
    }
  },
  sessionStorage: {
    getItem(key) {
      return sessionValues.get(key) || null;
    },
    setItem(key, value) {
      sessionValues.set(key, value);
    },
    removeItem(key) {
      sessionValues.delete(key);
    }
  },
  console,
  TextEncoder,
  URLSearchParams,
  setTimeout,
  clearTimeout,
  setInterval() {
    return 1;
  },
  clearInterval() {},
  fetch: async () => ({
    ok: true,
    json: async () => nextBattleState
  })
};

const source = fs.readFileSync(
  path.join(__dirname, '..', 'js', 'app.js'),
  'utf8'
);
vm.runInNewContext(source, sandbox, { filename: 'app.js' });

assert(componentOptions, 'Vue component should be registered');

const client = Object.assign(componentOptions.data(), componentOptions.methods);
client.txd = 'test-token';
client.apiBase = 'http://localhost:8888';
client.mudLines = [{
  segments: [{ type: 'button', label: '关闭自动挂机', cmd: 'autofightclose' }]
}];

client.playerStats = { avatar: '/images/h_male2.gif', name_cn: '测试方士' };
assert.strictEqual(client.fontSize, 'small');
let fontToast = '';
client.showUiToast = message => {
  fontToast = message;
};
client.changeFontSize({ target: { value: 'large' } });
assert.strictEqual(client.fontSize, 'large');
assert.strictEqual(localValues.get('mud_font_size'), 'large');
assert.strictEqual(documentAttributes.get('data-font-size'), 'large');
assert.strictEqual(fontToast, '游戏字号已调整为大');
client.fontSize = 'unsupported';
client.applyFontSize();
assert.strictEqual(client.fontSize, 'small');
assert.strictEqual(documentAttributes.get('data-font-size'), 'small');
assert.strictEqual(client.battleDockCollapsed, false);
client.toggleBattleDock();
assert.strictEqual(client.battleDockCollapsed, true);
assert.strictEqual(localValues.get('battle_dock_collapsed'), '1');
client.toggleBattleDock();
assert.strictEqual(client.battleDockCollapsed, false);
assert.strictEqual(localValues.get('battle_dock_collapsed'), '0');
assert.strictEqual(
  componentOptions.computed.playerAvatarUrl.call(client),
  'https://game.example.com/images/h_male2.gif'
);
assert.strictEqual(
  componentOptions.computed.playerAvatarFallback.call(client),
  '测'
);
client.handlePlayerAvatarError();
assert.strictEqual(client.playerAvatarFailed, true);

(async () => {
  const autoLoginTxd = client.encodeTxd('xd01autolog', 'yz12zy');
  const decodedCredentials = client.decodeCredentialsFromTxd(autoLoginTxd);
  assert.deepStrictEqual(
    JSON.parse(JSON.stringify(decodedCredentials)),
    { userid: 'xd01autolog', password: 'yz12zy' }
  );

  sessionValues.clear();
  sessionValues.set('mud_txd', autoLoginTxd);
  client.showLogin = true;
  sandbox.fetch = async url => {
    requestedLoginUrl = url;
    return {
      ok: true,
      json: async () => ({ txd: autoLoginTxd, lines: [] })
    };
  };
  await client.relogin();
  const restoredParams = new URL(requestedLoginUrl).searchParams;
  assert.strictEqual(restoredParams.get('userid'), 'xd01autolog');
  assert.strictEqual(restoredParams.get('password'), 'yz12zy');
  assert.strictEqual(sessionValues.get('mud_partition'), 'xd01');
  assert.strictEqual(sessionValues.get('mud_userid'), 'autolog');
  assert.strictEqual(client.showLogin, false);

  let preventedClicks = 0;
  let sentCommand = '';
  client.sendJsonCommand = command => {
    sentCommand = command;
  };
  client.htmlMode = false;
  client.handleMudButtonClick({
    preventDefault() {
      preventedClicks += 1;
    }
  }, 'look');
  assert.strictEqual(preventedClicks, 1);
  assert.strictEqual(sentCommand, 'look');

  client.htmlMode = true;
  sentCommand = '';
  client.handleMudButtonClick({
    preventDefault() {
      preventedClicks += 1;
    }
  }, 'inventory');
  assert.strictEqual(preventedClicks, 1);
  assert.strictEqual(sentCommand, '');

  client.isInBattle = true;
  client.skillAnimations = [];
  client.battleAnimations = [];
  client.parseBattleActions([{
    segments: [{
      type: 'text',
      parts: [{ content: '你施放了【方】灵治(等级3)，恢复了888点生命。' }]
    }]
  }]);
  assert.strictEqual(client.skillAnimations.length, 1);
  assert.strictEqual(client.skillAnimations[0].type, 'heal');
  assert.strictEqual(client.skillAnimations[0].name, '灵治');
  assert.strictEqual(client.skillAnimations[0].target, 'player');

  client.skillAnimations = [];
  client.parseBattleActions([{
    segments: [{
      type: 'text',
      parts: [{ content: '你施放了【方】灵火烧(等级2)，对妖狼造成了666点伤害。' }]
    }]
  }]);
  assert.strictEqual(client.skillAnimations[0].type, 'fire');
  assert.strictEqual(client.skillAnimations[0].name, '灵火烧');
  assert.strictEqual(client.skillAnimations[0].target, 'enemy');
  assert.strictEqual(client.battleAnimations[0].target, 'enemy');
  assert.strictEqual(client.parseMartialArtsSkill('【神】万剑归宗'), 'sword-qi');
  assert.strictEqual(client.parseMartialArtsSkill('九幽鬼步'), 'lightness');
  assert.strictEqual(client.extractSkillName('你发动了【三灵共鸣】！'), '三灵共鸣');
  assert.strictEqual(client.parseMartialArtsSkill('三灵共鸣'), 'summon');
  assert.strictEqual(client.extractSkillName('你召唤出了虎灵！'), '虎灵');
  assert.strictEqual(client.extractSkillName('你的仙力不够，无法施放【方】灵百雷(等级1)。'), '');
  assert.strictEqual(client.extractSkillName('该技能还需要8秒冷却时间,无法使用。'), '');
  assert.strictEqual(client.getSkillAnimationTarget('wind', '你施展御风剑气，对妖狼造成伤害'), 'enemy');

  client.toggleCombatEffects();
  assert.strictEqual(client.combatEffectsEnabled, false);
  assert.strictEqual(localValues.get('battle_effects_enabled'), '0');
  assert.strictEqual(client.skillAnimations.length, 0);
  client.addSkillAnimation('summon', '虎灵召唤', 'player');
  assert.strictEqual(client.skillAnimations.length, 0);
  client.toggleCombatEffects();
  assert.strictEqual(client.combatEffectsEnabled, true);
  assert.strictEqual(localValues.get('battle_effects_enabled'), '1');

  sentCommand = '';
  client.showPerformsList = true;
  client.sendJsonCommand = async command => {
    sentCommand = command;
  };
  await client.selectPerform({
    id: 'lingbailei', name_cn: '【方】灵百雷', available: true,
    enough_neili: true, level_req: 1, neili_cost: 10
  });
  assert.strictEqual(sentCommand, 'use_perform lingbailei');
  assert.strictEqual(client.skillAnimations[0].type, 'lightning');
  assert.strictEqual(client.skillAnimations[0].name, '灵百雷');
  assert.strictEqual(client.skillAnimations[0].target, 'enemy');
  assert.strictEqual(client.showPerformsList, false);
  client.isInBattle = false;
  client.battleStatusInterval = null;

  sandbox.fetch = async () => ({
    ok: true,
    json: async () => nextBattleState
  });
  client.mudLines = [{
    segments: [{ type: 'button', label: '关闭自动挂机', cmd: 'autofightclose' }]
  }];
  await client.checkBattleStatus();
  assert.strictEqual(client.isInBattle, true);
  assert.strictEqual(client.battleEnemy.name, '测试怪物');
  assert.strictEqual(client.battleEnemy.level, 8);
  assert.strictEqual(client.battleEnemy.profe, '野怪');
  assert.strictEqual(client.battleEnemy.race, '妖魔');
  assert.strictEqual(client.battleEnemy.attack, 123);
  assert.strictEqual(client.battleEnemy.attackLow, 100);
  assert.strictEqual(client.battleEnemy.attackHigh, 123);
  assert.strictEqual(client.battleEnemy.defend, 45);
  assert.strictEqual(client.battlePlayerFull.mana, 70);
  assert.strictEqual(client.battlePlayerFull.mana_max, 80);
  assert.strictEqual(client.battleStatusInterval, 1);
  assert.strictEqual(client.battleStatusLoading, false);

  nextBattleState = {
    in_battle: true,
    player: { name_cn: '测试方士', hp: 88, hp_max: 100, mana: 65, mana_max: 80 },
    enemy: null
  };
  await client.fetchBattleStatus();
  assert.strictEqual(client.battleEnemy.name, '测试怪物');
  assert.strictEqual(client.battleEnemyFull, null);

  nextBattleState = {
    in_battle: false,
    player: { name: '测试方士', hp: 85, hp_max: 100 }
  };
  await client.fetchBattleStatus();
  assert.strictEqual(client.isInBattle, false);
  assert.strictEqual(client.battleEnemy, null);
  assert.strictEqual(client.battleStatusInterval, null);
  assert.strictEqual(client.battleStatusLoading, false);

  console.log('✓ Autofight battle panel state transitions passed');
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
