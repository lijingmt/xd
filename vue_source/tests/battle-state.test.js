const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

let componentOptions = null;
let nextBattleState = {
  in_battle: true,
  player: {
    name_cn: '测试方士', hp: 90, hp_max: 100,
    mana: 70, mana_max: 80, level: 9, profe: '镇越', race: '中立',
    autofight: 1,
    guard: 1200, guard_time: 10, guard_active: 1,
    star_marks: 2, star_marks_max: 3,
    medicine_pacts: 2, medicine_pacts_max: 3,
    lingyi_revive: {
      mastered: 8, maximum: 2, used: 1, remaining: 1, unlocked: 1
    },
    recent_aoe_report: {
      skill: 'yaowutianluo', skill_name: '【医】药雾天罗', remaining: 10,
      targets: [
        { name: 'wolf', name_cn: '妖狼', damage: 1234, hit: 1, defeated: 1, revived: 0 },
        { name: 'healer', name_cn: '敌方灵医', damage: 888, hit: 1, defeated: 0, revived: 1 }
      ]
    },
    pet_assist: {
      active: 1, pet_id: 'pet-001', species: 'dangkang',
      name: '当康', icon: '🐗', family: '土', role: '守护',
      skill: '丰穰守心', cooldown: 30, cooldown_remaining: 18,
      level: 60, star: 10, bond: 5, evolution: 3,
      evolution_name: '真形·圆满', power: 18600,
      growth_percent: 222, pvp_growth_percent: 124,
      combat_mode: 'pve', pvp_charge: 0, pvp_charge_required: 5,
      pvp_uses: 0, pvp_uses_max: 2,
      recent_event: {
        id: 'pet-event-001', event_at: 100, name: '当康', icon: '🐗',
        family: '土', role: '守护', skill: '丰穰守心', type: 'heal',
        mode: 'pve', amount: 456, target_name: '测试方士', cooldown: 30,
        level: 60, star: 10, evolution_name: '真形·圆满', power: 18600
      }
    }
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
    name: '',
    location: { protocol: 'https:', hostname: 'game.example.com' },
    matchMedia() {
      return { matches: false };
    }
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
  btoa(value) {
    return Buffer.from(value, 'binary').toString('base64');
  },
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
assert(source.includes('无论挂机此刻是否已在后台结束'));
vm.runInNewContext(source, sandbox, { filename: 'app.js' });

assert(componentOptions, 'Vue component should be registered');
const indexSource = fs.readFileSync(
  path.join(__dirname, '..', 'index.html'),
  'utf8'
);
assert(indexSource.includes('十职同行'));
assert(indexSource.includes('星痕 {{ battlePlayerFull?.star_marks'));
assert(indexSource.includes('药契 {{ battlePlayerFull?.medicine_pacts'));
assert(indexSource.includes('battleAoeReport.targets'));
assert(indexSource.includes("target.revived ? '复苏'"));
assert(indexSource.includes('lingyi-revive-status'));
assert(indexSource.includes('battle-pet-companion-mini'));
assert(indexSource.includes('battle-pet-companion-full'));
assert(indexSource.includes('battle-pet-assist-burst'));
assert(indexSource.includes('getPetCultivationLabel(battlePet)'));
assert(indexSource.includes("petAssistEffect.mode === 'pvp'"));
assert(indexSource.includes('v-if="headerPet"'));
assert(indexSource.includes('class="header-pet-companion"'));
assert(indexSource.includes("@click=\"sendQuickCommand('pet')\""));
assert(indexSource.includes('@click="openEquipmentPanel"'));
assert(indexSource.includes('equipment-human-silhouette'));
assert(indexSource.includes('getEquipmentCandidates(equipmentSelectedSlot)'));
assert(indexSource.includes("playerStats.profe === '天象' ? '✦'"));
assert(indexSource.includes("playerStats.profe === '灵医' ? '✚'"));
assert(indexSource.includes('class="pet-level-up-stage"'));
assert(indexSource.includes('@click="openPetLevelUpEffect"'));
const soundDataUri = sandbox.createGameSoundSpriteDataUri();
assert(soundDataUri.startsWith('data:audio/wav;base64,'));
const soundBytes = Buffer.from(soundDataUri.split(',')[1], 'base64');
assert.strictEqual(soundBytes.subarray(0, 4).toString('ascii'), 'RIFF');
assert.strictEqual(soundBytes.subarray(8, 12).toString('ascii'), 'WAVE');
assert(soundBytes.length > 80000 && soundBytes.length < 100000);

const client = Object.assign(componentOptions.data(), componentOptions.methods);
client.txd = 'test-token';
client.apiBase = 'http://localhost:8888';
client.mudLines = [{
  segments: [{ type: 'button', label: '关闭自动挂机', cmd: 'autofightclose' }]
}];

const newestFirstPartitions = client.sortPartitionsNewestFirst([
  { value: 'xd01', label: '仙道一区', sort: 1, login_open: 1, registration_open: 1 },
  { value: 'xd03', label: '仙道三区', sort: 3, login_open: 1, registration_open: 1 },
  { value: 'xd04', label: '仙道四区', sort: 4, login_open: 0, registration_open: 0 },
  { value: 'xd02', label: '仙道二区', sort: 2, login_open: 1, registration_open: 1 }
]);
assert.deepStrictEqual(
  newestFirstPartitions.map(partition => partition.value),
  ['xd04', 'xd03', 'xd02', 'xd01']
);
sessionValues.clear();
client.applyLoadedPartitions(newestFirstPartitions);
assert.strictEqual(client.loginForm.partition, 'xd03');
assert.strictEqual(client.registerForm.partition, 'xd03');
client.loginForm.partition = 'xd02';
client.applyLoadedPartitions(newestFirstPartitions);
assert.strictEqual(client.loginForm.partition, 'xd02');
sessionValues.clear();

client.playerStats = {
  avatar: '/images/h_male2.gif', name_cn: '测试方士',
  pet_assist: {
    active: 1, name: '当康', icon: '🐗', family: '土',
    level: 60, star: 10, evolution_name: '真形·圆满'
  }
};
const headerPet = componentOptions.computed.headerPet.call(client);
assert.strictEqual(headerPet.name, '当康');
assert.strictEqual(client.getPetCultivationLabel(headerPet), 'Lv.60 · 10星真形·圆满');
client.playerStats.pet_assist = { active: 0 };
assert.strictEqual(componentOptions.computed.headerPet.call(client), null);
client.playerStats.pet_assist = headerPet;
const petLevelFeedback = [];
client.triggerGameFeedback = (kind, signature, interval) => {
  petLevelFeedback.push({ kind, signature, interval });
  return true;
};
assert.strictEqual(client.handlePetLevelChange({
  active: 1, pet_id: 'pet-growth-1', species: 'dangkang',
  name: '当康', icon: '🐗', level: 18
}, {
  active: 1, pet_id: 'pet-growth-1', species: 'dangkang',
  name: '当康', icon: '🐗', level: 21
}), true);
assert.strictEqual(client.petLevelUpEffect.name, '当康');
assert.strictEqual(client.petLevelUpEffect.fromLevel, 18);
assert.strictEqual(client.petLevelUpEffect.toLevel, 21);
assert.strictEqual(client.petLevelUpEffect.levelsGained, 3);
assert.strictEqual(client.petLevelUpEffect.command, 'pet detail dangkang');
assert.strictEqual(petLevelFeedback[0].kind, 'petLevel');
assert.strictEqual(petLevelFeedback[0].interval, 800);
assert.strictEqual(client.handlePetLevelChange({
  active: 1, pet_id: 'pet-growth-1', level: 21
}, {
  active: 1, pet_id: 'pet-growth-1', level: 21
}), false);
assert.strictEqual(client.handlePetLevelChange({
  active: 1, pet_id: 'pet-growth-1', level: 21
}, {
  active: 1, pet_id: 'pet-growth-2', level: 22
}), false);
client.clearPetLevelUpEffect();
assert.strictEqual(client.petLevelUpEffect, null);
assert.strictEqual(client.showEquipmentPanel, false);
assert.strictEqual(client.cleanEquipmentName('§g【优良】法杖§r'), '【优良】法杖');
client.equipmentPanel = {
  candidates: {
    armor_head: [
      { id: 'helm#0', equipped: true },
      { id: 'helm#1', equipped: false }
    ]
  }
};
assert.deepStrictEqual(
  client.getEquipmentCandidates('armor_head').map(item => item.id),
  ['helm#1']
);
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
assert.strictEqual(client.soundEffectsEnabled, false);
assert.strictEqual(client.shouldAnimateMudOutputCommand('inventory'), true);
assert.strictEqual(client.shouldAnimateMudOutputCommand('mytasks active'), true);
assert.strictEqual(client.shouldAnimateMudOutputCommand('flushview'), false);
const inventoryLine = {
  type: 'line',
  segments: [{ type: 'text', parts: [{ content: '小还丹 x1' }] }]
};
assert.notStrictEqual(
  client.getMudLineKey(inventoryLine, 0),
  client.getMudLineKey({
    ...inventoryLine,
    segments: [{ type: 'text', parts: [{ content: '小还丹 x2' }] }]
  }, 0)
);
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
  client.txd = autoLoginTxd;
  client.showLogin = true;
  sandbox.fetch = async url => {
    requestedLoginUrl = url;
    return {
      ok: true,
      json: async () => ({ txd: autoLoginTxd, lines: [] })
    };
  };
  await client.relogin(autoLoginTxd, client.characterSessionEpoch);
  const restoredParams = new URL(requestedLoginUrl).searchParams;
  assert.strictEqual(restoredParams.get('userid'), 'xd01autolog');
  assert.strictEqual(restoredParams.get('password'), 'yz12zy');
  
  
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
  assert.strictEqual(client.parseMartialArtsSkill('【越】山河壁'), 'block');
  assert.strictEqual(client.parseMartialArtsSkill('【越】地震吼'), 'curse');
  assert.strictEqual(client.parseMartialArtsSkill('【神】万山朝拱'), 'buff');
  assert.strictEqual(client.parseMartialArtsSkill('【神】不周震击'), 'fist');
  assert.strictEqual(client.parseMartialArtsSkill('【神】天地成壁'), 'block');
  assert.strictEqual(client.parseMartialArtsSkill('【象】星落'), 'fire');
  assert.strictEqual(client.parseMartialArtsSkill('【象】寒辰'), 'ice');
  assert.strictEqual(client.parseMartialArtsSkill('【象】九星连珠'), 'wind');
  assert.strictEqual(client.parseMartialArtsSkill('【神】万象星壁'), 'block');
  assert.strictEqual(client.parseMartialArtsSkill('【象】星锁'), 'curse');
  assert.strictEqual(client.parseMartialArtsSkill('【医】药雾天罗'), 'poison');
  assert.strictEqual(client.parseMartialArtsSkill('【神】六合回春'), 'heal');
  assert.strictEqual(client.getSkillAnimationTarget('block', '你施放了【越】山河壁。'), 'player');
  assert.strictEqual(client.extractSkillName('你召唤出了虎灵！'), '虎灵');
  assert.strictEqual(client.extractSkillName('你的仙力不够，无法施放【方】灵百雷(等级1)。'), '');
  assert.strictEqual(client.extractSkillName('该技能还需要8秒冷却时间,无法使用。'), '');
  assert.strictEqual(client.getSkillAnimationTarget('wind', '你施展御风剑气，对妖狼造成伤害'), 'enemy');

  client.isInBattle = false;
  client.skillAnimations = [];
  client.parseBattleActions([{
    segments: [{
      type: 'text',
      parts: [{ content: '【战技显化】太虚真人施放「【太古·7】鸿蒙一剑」（等级1），目标为妖狼，战技气息扩散开来。' }]
    }]
  }]);
  assert.strictEqual(client.skillAnimations.length, 1);
  assert.strictEqual(client.skillAnimations[0].type, 'ancient');
  assert.strictEqual(client.skillAnimations[0].name, '鸿蒙一剑');
  assert.strictEqual(client.skillAnimations[0].target, 'room');
  const roomPet = client.parseRoomPetManifestation(
    '【灵宠显化】太虚真人的🐗当康施展「丰穰守心」，对妖狼造成321点协战伤害。'
  );
  assert.strictEqual(roomPet.owner_name, '太虚真人');
  assert.strictEqual(roomPet.name, '当康');
  assert.strictEqual(roomPet.type, 'damage');
  assert.strictEqual(roomPet.amount, 321);
  assert(client.formatPetAssistMessage(roomPet).includes('太虚真人的🐗 当康'));
  const roomRevive = client.parseRoomPetManifestation(
    '【灵宠显化】太虚真人的🕊️鸾鸟施展「回生羽」，在死亡前为主人恢复1500点生命，并恢复600点法力。'
  );
  assert.strictEqual(roomRevive.type, 'revive');
  assert.strictEqual(roomRevive.icon, '🕊️');
  assert.strictEqual(roomRevive.name, '鸾鸟');
  assert.strictEqual(roomRevive.mofa_amount, 600);
  client.parseBattleActions([{
    segments: [{
      type: 'text',
      parts: [{ content: '【灵宠显化】太虚真人的🐗当康施展「丰穰守心」，对妖狼造成321点协战伤害。' }]
    }]
  }]);
  assert.strictEqual(client.petAssistEffect.observer, true);
  assert.strictEqual(client.petAssistEffect.name, '当康');
  assert.strictEqual(client.petAssistEffect.visualType, 'generic');
  client.isInBattle = true;

  client.toggleCombatEffects();
  assert.strictEqual(client.combatEffectsEnabled, false);
  assert.strictEqual(localValues.get('battle_effects_enabled'), '0');
  assert.strictEqual(client.skillAnimations.length, 0);
  client.addSkillAnimation('summon', '虎灵召唤', 'player');
  assert.strictEqual(client.skillAnimations.length, 0);
  client.toggleCombatEffects();
  assert.strictEqual(client.combatEffectsEnabled, true);
  assert.strictEqual(localValues.get('battle_effects_enabled'), '1');

  const playedSounds = [];
  client.initializeSoundPlayer = () => ({
    play(name) {
      playedSounds.push(name);
    },
    stop() {}
  });
  client.toggleSoundEffects();
  assert.strictEqual(client.soundEffectsEnabled, true);
  assert.strictEqual(localValues.get('game_sound_enabled'), '1');
  assert.deepStrictEqual(playedSounds, ['ui']);
  client.toggleSoundEffects();
  assert.strictEqual(client.soundEffectsEnabled, false);
  assert.strictEqual(localValues.get('game_sound_enabled'), '0');

  const narrativeFeedback = [];
  client.triggerGameFeedback = (kind, signature) => {
    narrativeFeedback.push({ kind, signature });
    return true;
  };
  client.handleNarrativeEffects([{
    segments: [{
      type: 'text',
      parts: [{ content: '你击败妖王，获得了一本隐藏技能书！' }]
    }]
  }, {
    segments: [{
      type: 'text',
      parts: [{ content: '恭喜你成功完成灵息试炼任务！' }]
    }]
  }, {
    segments: [{
      type: 'text',
      parts: [{ content: '任务完成后可以回来领取奖励。' }]
    }]
  }]);
  assert.deepStrictEqual(
    narrativeFeedback.map(item => item.kind),
    ['rare', 'quest']
  );

  client.activeNewbieCompletion = null;
  client.newbieCompletionQueue = [];
  client.handleNewbieCompletions([{
    code: 2,
    step: 3,
    total: 8,
    title: '穿戴第一件装备',
    reward: '小还丹',
    complete: false
  }]);
  assert.strictEqual(client.activeNewbieCompletion.title, '穿戴第一件装备');
  assert.strictEqual(narrativeFeedback.at(-1).kind, 'quest');

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

  client.showLogin = false;
  client.showCharacterSelect = false;
  client.useJsonMode = true;
  client.mudLoading = false;
  client.playerStats = { autofight: 1 };
  sentCommand = '';
  client.sendJsonCommand = async command => {
    sentCommand = command;
  };
  let autofightViewFetches = 0;
  sandbox.fetch = async url => {
    autofightViewFetches += 1;
    assert(String(url).includes('/api/autofight_view?'));
    return {
      ok: true,
      status: 200,
      json: async () => ({
        generation: 'test-generation',
        sequence: 1,
        active: 1,
        lines: [],
        refresh: nextBattleState
      })
    };
  };
  await client.runAutofightTick();
  assert.strictEqual(sentCommand, '');
  assert.strictEqual(autofightViewFetches, 1);
  assert.strictEqual(client.autofightViewGeneration, 'test-generation');
  assert.strictEqual(client.autofightViewSequence, 1);
  assert.strictEqual(client.isInBattle, true);
  assert.strictEqual(client.battleStatusInterval, null);
  assert.strictEqual(client.autofightTickInFlight, false);

  sandbox.document.hidden = true;
  await client.runAutofightTick();
  assert.strictEqual(autofightViewFetches, 1);
  sandbox.document.hidden = false;

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
  assert.strictEqual(client.battlePlayerFull.guard, 1200);
  assert.strictEqual(client.battlePlayerFull.guard_time, 10);
  assert.strictEqual(client.battlePlayerFull.guard_active, 1);
  assert.strictEqual(client.battlePlayerFull.lingyi_revive.remaining, 1);
  assert.strictEqual(client.battleAoeReport.skill, 'yaowutianluo');
  assert.strictEqual(client.battleAoeReport.targets.length, 2);
  assert.strictEqual(client.battleAoeReport.targets[0].defeated, true);
  assert.strictEqual(client.battleAoeReport.targets[1].revived, true);
  assert.strictEqual(client.battlePet.name, '当康');
  assert.strictEqual(client.battlePet.star, 10);
  assert.strictEqual(client.battlePet.power, 18600);
  assert.strictEqual(
    client.getPetCultivationLabel(client.battlePet),
    'Lv.60 · 10星真形·圆满'
  );
  assert.strictEqual(client.getPetAssistStatus(client.battlePet), '守护蓄势 18秒');
  assert.strictEqual(client.getPetCooldownPercent(client.battlePet), 40);
  assert.strictEqual(client.petAssistEffect.id, 'pet-event-001');
  assert.strictEqual(client.petAssistEffect.visualType, 'heal');
  assert.strictEqual(client.lastPetAssistEventId, 'pet-event-001');
  assert(client.battleLog[0].message.includes('当康'));
  assert(client.battleLog[0].message.includes('恢复456点生命'));
  const petLogCount = client.battleLog.length;
  await client.fetchBattleStatus();
  assert.strictEqual(client.battleLog.length, petLogCount);
  client.resetPetBattleVisualState();
  client.syncBattlePetAssist(nextBattleState.player.pet_assist);
  assert.strictEqual(client.battlePet.name, '当康');
  assert.strictEqual(client.petAssistEffect, null);
  assert.strictEqual(client.battleLog.length, petLogCount);
  assert(client.formatPetAssistMessage({
    name: '当康', icon: '🐗', skill: '丰穰守心', type: 'heal', amount: 0
  }).includes('守护在你身旁'));
  assert.strictEqual(client.getPetAssistStatus({
    active: true, combat_mode: 'pvp', pvp_charge: 3,
    pvp_charge_required: 5, pvp_uses: 1, pvp_uses_max: 2
  }), '御灵充能 3/5 · 本场 1/2');
  assert.strictEqual(client.getPetAssistStatus({
    active: true, combat_mode: 'pvp', pvp_charge: 0,
    pvp_charge_required: 5, pvp_uses: 2, pvp_uses_max: 2
  }), '本场御灵已尽 2/2');
  assert.strictEqual(client.getPetAssistStatus({
    active: true, role: '灵息', cooldown_remaining: 8
  }), '凝聚灵息 8秒');
  assert.strictEqual(client.getPetAssistStatus({
    active: true, role: '疗愈', cooldown_remaining: 0
  }), '疗愈就绪');
  assert.strictEqual(client.getPetAssistStatus({
    active: true, role: '强攻', cooldown_remaining: 6
  }), '攻势蓄力 6秒');
  assert.strictEqual(client.getPetAssistStatus({
    active: true, role: '疗愈', cooldown_remaining: 0,
    owner_revive: { enabled: 1, remaining: 1 }
  }), '回生羽可用 · 疗愈就绪');
  assert(client.formatPetAssistMessage({
    name: '鸾鸟', icon: '🕊️', skill: '回生羽', type: 'revive',
    amount: 1500, mofa_amount: 600
  }).includes('死里回生'));
  assert.strictEqual(client.getPetAssistAnimationType({ type: 'revive' }), 'heal');
  assert(client.formatPetAssistMessage({
    name: '毕方', icon: '🔥', skill: '独足炎翎', type: 'damage',
    mode: 'pvp', amount: 496, target_name: '对手'
  }).includes('【御灵交锋】'));
  assert.strictEqual(
    componentOptions.computed.hasRecentAoeReport.call(client),
    true
  );
  assert.strictEqual(client.battleStatusInterval, null);
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
    player: {
      name: '测试方士', hp: 85, hp_max: 100,
      recent_aoe_report: {
        skill: 'yaowutianluo', skill_name: '【医】药雾天罗', remaining: 8,
        targets: [
          { name: 'wolf', name_cn: '妖狼', damage: 1234, hit: 1, defeated: 1 }
        ]
      }
    }
  };
  await client.fetchBattleStatus();
  assert.strictEqual(client.isInBattle, false);
  assert.strictEqual(client.battleEnemy, null);
  assert.strictEqual(client.battleStatusInterval, null);
  assert.strictEqual(client.battleStatusLoading, false);
  assert.strictEqual(client.battlePlayerFull.name, '测试方士');
  assert.strictEqual(client.battleAoeReport.targets[0].name, '妖狼');
  assert.strictEqual(
    componentOptions.computed.hasRecentAoeReport.call(client),
    true
  );
  client.clearBattleAoeReport();
  assert.strictEqual(
    componentOptions.computed.hasRecentAoeReport.call(client),
    false
  );

  console.log('✓ Autofight battle panel state transitions passed');
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
