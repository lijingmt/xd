const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const { compile } = require('@vue/compiler-dom');
const { createManifest } = require('../manifest');

const sourceDir = path.join(__dirname, '..');
const rootDir = path.join(sourceDir, '..');

function read(relativePath) {
  return fs.readFileSync(path.join(rootDir, relativePath), 'utf8');
}

const indexSource = read('vue_source/index.html');
const buildSource = read('vue_source/build.js');
const serveSource = read('vue_source/serve.js');
const rebuildSource = read('rebuild-image.sh');
const sharedBuildSource = read('scripts/build/build_vue_frontend.sh');
const licenseMemo = read('docs/frontend-open-source-license-memo.md');
const dockerSource = read('docker/Dockerfile.all');
const packageJson = JSON.parse(read('vue_source/package.json'));
const packageLock = JSON.parse(read('vue_source/package-lock.json'));
const installedVue = JSON.parse(read('vue_source/node_modules/vue/package.json'));
const manifest = createManifest('test-version');

const appTemplateStart = indexSource.indexOf('<div id="app">');
const appTemplateEnd = indexSource.indexOf('<script src="vendor/vue.global.prod.js');
assert(appTemplateStart >= 0 && appTemplateEnd > appTemplateStart);
const templateErrors = [];
compile(indexSource.slice(appTemplateStart, appTemplateEnd), {
  comments: true,
  onError(error) {
    templateErrors.push(error.message);
  }
});
assert.deepStrictEqual(templateErrors, []);

assert.strictEqual(packageJson.scripts.dev, 'node serve.js');
assert.strictEqual(packageJson.dependencies.vue, '3.5.40');
assert.strictEqual(packageLock.packages[''].dependencies.vue, '3.5.40');
assert.strictEqual(packageLock.packages['node_modules/vue'].version, '3.5.40');
assert.strictEqual(installedVue.version, '3.5.40');
const effectDependencies = {
  'canvas-confetti': '1.9.4',
  'howler': '2.2.4',
  '@formkit/auto-animate': '0.10.0',
  'driver.js': '1.8.0'
};
for (const [packageName, version] of Object.entries(effectDependencies)) {
  assert.strictEqual(packageJson.dependencies[packageName], version);
  assert.strictEqual(packageLock.packages[''].dependencies[packageName], version);
  assert.strictEqual(packageLock.packages[`node_modules/${packageName}`].version, version);
  const installedPackage = JSON.parse(read(`vue_source/node_modules/${packageName}/package.json`));
  assert.strictEqual(installedPackage.version, version);
  assert(licenseMemo.includes(packageName));
  assert(licenseMemo.includes('`' + version + '`'));
}
assert(licenseMemo.includes('ISC'));
assert(licenseMemo.includes('MIT'));
assert(licenseMemo.includes('可以免费用于 Xiand 的商业运营'));
assert(licenseMemo.includes('CANVAS_CONFETTI_LICENSE.txt'));
assert(licenseMemo.includes('DRIVER_LICENSE.txt'));
for (const removedPackage of ['http-server', 'follow-redirects', 'qs']) {
  assert(!packageJson.dependencies?.[removedPackage]);
  assert(!packageJson.devDependencies?.[removedPackage]);
  assert(!packageLock.packages[`node_modules/${removedPackage}`]);
  assert(!fs.existsSync(path.join(sourceDir, 'node_modules', removedPackage)));
}

assert(indexSource.includes('css/app.css?v=BUILD_VERSION'));
assert(indexSource.includes('css/realm.css?v=BUILD_VERSION'));
assert(indexSource.includes('js/app.js?v=BUILD_VERSION'));
assert(indexSource.includes('manifest.json'));
assert(indexSource.includes('vendor/vue.global.prod.js?v=BUILD_VERSION'));
assert(indexSource.includes('vendor/canvas-confetti.js?v=BUILD_VERSION'));
assert(indexSource.includes('vendor/howler.core.min.js?v=BUILD_VERSION'));
assert(indexSource.includes('vendor/driver.iife.js?v=BUILD_VERSION'));
assert(indexSource.includes('vendor/driver.css?v=BUILD_VERSION'));
assert(indexSource.includes("import { autoAnimate } from './vendor/auto-animate.min.js?v=BUILD_VERSION'"));
assert(!indexSource.includes('cdn.jsdelivr.net'));
assert(!indexSource.includes('unpkg.com/vue'));
assert(!indexSource.includes('user-scalable=no'));
assert(!indexSource.includes('maximum-scale=1.0'));
assert(indexSource.includes('viewport-fit=cover'));
assert(indexSource.includes('class="modal auth-modal"'));

assert(indexSource.includes('<div class="auth-form">'));
assert(indexSource.includes('@click="doLogin"'));
assert(indexSource.includes('@keyup.enter="doLogin"'));
assert(indexSource.includes('@click="doRegister"'));
assert(indexSource.includes('@keyup.enter="doRegister"'));
assert(!indexSource.includes('<form class="auth-form"'));
assert(!indexSource.includes('name="username"'));
assert(!indexSource.includes('name="password"'));


assert(indexSource.includes('autocomplete="current-password"'));
assert(indexSource.includes('aria-label="登录游戏"'));
assert(indexSource.includes('role="progressbar"'));
assert(indexSource.includes(':aria-busy="mudLoading ? \'true\' : \'false\'"'));
assert(indexSource.includes("'battle-dock-active'"));
assert(indexSource.includes("'battle-dock-collapsed'"));
assert(indexSource.includes('class="battle-dock-trigger"'));
assert(indexSource.includes('@click="toggleBattleDock"'));
assert(indexSource.includes('class="battle-skill-stage"'));
assert(indexSource.includes('class="skill-effect-label"'));
assert(indexSource.includes('@click="toggleCombatEffects"'));
assert(indexSource.includes('combatEffectsEnabled && skillAnimations.length'));
assert(indexSource.includes("battleEnemy?.name || '目标识别中'"));
assert(indexSource.includes('battlePlayerFull?.mana ?? playerStats?.mana'));
assert(indexSource.includes('battlePlayerFull?.mana_max ?? playerStats?.mana_max'));
assert(indexSource.includes('battleAoeReport.targets'));
assert(indexSource.includes('target.revived'));
assert(indexSource.includes('lingyi-revive-status'));
assert(indexSource.includes('class="battle-pet-assist-burst"'));
assert(indexSource.includes('battle-pet-companion-mini'));
assert(indexSource.includes('battle-pet-companion-full'));
assert(indexSource.includes('getPetCooldownPercent(battlePet)'));
assert(indexSource.includes('getPetCultivationLabel(battlePet)'));
assert(indexSource.includes("petAssistEffect.mode === 'pvp'"));
assert(indexSource.includes('battleEnemy?.attack !== undefined'));
assert(indexSource.includes('battleEnemy?.attackLow ?? battleEnemy?.attack ?? 0'));
assert(indexSource.includes('battleEnemyFull.attack_low ?? battleEnemyFull.attack ?? 0'));
assert(indexSource.includes('battleEnemyFull.defend || 0'));
assert(!indexSource.includes('playerStats?.neili'));
assert(!indexSource.includes('battlePlayerFull.neili'));
assert(!indexSource.includes('battlePlayerFull.spirit'));
assert(!indexSource.includes('battlePlayerFull.potential'));
assert(indexSource.includes('class="quick-primary-nav"'));
assert(indexSource.includes('class="quick-more-panel"'));
assert(indexSource.includes('data-tour="inventory"'));
assert(indexSource.includes('data-tour="skills"'));
assert(indexSource.includes('data-tour="autofight"'));
assert(indexSource.includes('data-tour="warehouse"'));
assert(indexSource.includes("sendQuickCommand('go_warehouse')"));
assert(indexSource.includes('<span>🧰</span>仓库</button>'));
assert(indexSource.includes("sendQuickCommand('pet')"));
assert(indexSource.includes('<span>🐾</span>万灵</button>'));
assert(indexSource.includes("sendQuickCommand('daily')"));
assert(indexSource.includes("playerStats?.daily_goal?.claimable"));
assert(indexSource.includes("'🎁' : '📅'"));
assert(indexSource.includes('@click="startUiTour"'));
assert(indexSource.includes('@click="toggleSoundEffects"'));
assert(indexSource.includes('ref="mudLinesList"'));
assert(indexSource.includes(':key="getMudLineKey(line, index)"'));
assert(indexSource.includes("v-show=\"!mudLoading || smoothOutputLoading\""));
assert(indexSource.includes("v-if=\"mudLoading && !smoothOutputLoading\""));
assert(!/v-show="[^"]+"[\s\S]{0,120}<div v-else/.test(indexSource));
assert(indexSource.includes('ref="newbieCompletionStage"'));
assert(indexSource.includes('class="player-avatar-shell"'));
assert(indexSource.includes(':src="playerAvatarUrl"'));
assert(indexSource.includes('@error="handlePlayerAvatarError"'));
assert(indexSource.includes("sendQuickCommand('profession_assistant')"));
assert(indexSource.includes('playerStats?.profession_assistant?.style_class'));
assert(indexSource.includes("playerStats.profession_assistant.title }} · 职业助手"));
assert(!indexSource.includes('class="profession-assistant-badge"'));
assert.strictEqual(
  (indexSource.match(/<main\b/g) || []).length,
  (indexSource.match(/<\/main>/g) || []).length
);
assert(indexSource.includes('v-if="activeNewbieCompletion"'));
assert(indexSource.includes('@click="continueNewbieGuide"'));
assert(!indexSource.includes('translate.autoDiscriminateLocalLanguage();'));
assert(!indexSource.includes('translate.changeLanguage(savedLang);'));
assert(indexSource.includes("translate.storage.set('to', savedLang)"));
assert(indexSource.includes("translate.storage.set('to', '')"));
assert(indexSource.includes("localStorage.getItem('mud_font_size') || 'small'"));
assert(indexSource.includes('id="vueFontSizeSelect"'));
assert(indexSource.includes('@change="changeFontSize($event)"'));
assert(indexSource.includes('class="level-cap-badge"'));
assert(indexSource.includes("sendQuickCommand('vip_service_list')"));
assert(!indexSource.includes("sendQuickCommand('feedback')"));
assert(indexSource.includes('v-if="teamInvite"'));
assert(indexSource.includes('respondTeamInvite(true)'));
assert(indexSource.includes('playerStats.level_can_progress'));

const appSource = read('vue_source/js/app.js');
const cssSource = read('vue_source/css/app.css');
assert(appSource.includes('pendingTeamInvite.pending'));
assert(appSource.includes("'term_ok' : 'term_refuse'"));
assert(cssSource.includes('.team-invite-modal'));
assert(cssSource.includes('.profession-style-fangshi-3'));
assert(cssSource.includes('.profession-style-zhenyue-3'));
assert(cssSource.includes('.profession-style-tianxiang-3'));
assert(cssSource.includes('.profession-style-lingyi-3'));
assert(cssSource.includes('@media (prefers-reduced-motion: reduce)'));
assert(appSource.includes('handleNewbieCompletions(data.newbie_completions || [])'));
assert(appSource.includes('showNextNewbieCompletion()'));
assert(appSource.includes('dismissNewbieCompletions()'));
assert(appSource.includes('this.dismissNewbieCompletions();'));
assert(appSource.includes('getStatPercent(current, maximum)'));
assert(appSource.includes('formatCompactNumber(value)'));
assert(appSource.includes("showUiToast(message, type = 'info', action = null)"));
assert(appSource.includes('runUiToastAction()'));
assert(appSource.includes('data.quota_exhausted'));
assert(indexSource.includes('class="ui-toast-action"'));
assert(indexSource.includes('class="pet-level-up-stage"'));
assert(indexSource.includes('@click="openPetLevelUpEffect"'));
assert(cssSource.includes('.ui-toast-action'));
assert(cssSource.includes('.pet-level-up-card'));
assert(cssSource.includes('@keyframes petLevelUpEnter'));
assert(cssSource.includes('.room-skill-manifestation-stage'));
assert(cssSource.includes('.room-pet-manifestation.battle-pet-assist-burst'));
assert(cssSource.includes('@keyframes ancient-awakening-effect'));
assert(appSource.includes('isQuickActionActive(command)'));
assert(appSource.includes('quickActionsCollapsed: true'));
assert(appSource.includes('playerAvatarFailed: false'));
assert(appSource.includes('playerAvatarUrl()'));
assert(appSource.includes('playerAvatarFallback()'));
assert(appSource.includes('handlePlayerAvatarError()'));
assert(indexSource.includes('@click="handleMudButtonClick($event, segment.cmd)"'));
assert(!indexSource.includes('@click.prevent="!htmlMode'));
assert(appSource.includes('handleMudButtonClick(event, cmd)'));
assert(appSource.includes('decodeCredentialsFromTxd(txd)'));
assert(appSource.includes('const credentials = this.decodeCredentialsFromTxd(savedTxd)'));
assert(!appSource.includes('if (!savedTxd || !savedUser)'));
assert(appSource.includes('await this.checkBattleStatus(isAutofightRefresh)'));
assert(appSource.includes("seg.label.includes('关闭自动挂机')"));
assert(appSource.includes("seg.cmd === 'autofightclose'"));
assert(appSource.includes('battleStatusLoading: false'));
assert(appSource.includes('battleDockCollapsed: false'));
assert(appSource.includes('toggleBattleDock()'));
assert(appSource.includes("localStorage.setItem('battle_dock_collapsed'"));
assert(appSource.includes("combatEffectsEnabled: localStorage.getItem('battle_effects_enabled') !== '0'"));
assert(appSource.includes('extractSkillName(text)'));
assert(appSource.includes('getSkillAnimationTarget(skillType, text = \'\')'));
assert(appSource.includes('toggleCombatEffects()'));
assert(appSource.includes('syncBattlePetAssist(petAssist)'));
assert(appSource.includes('handlePetLevelChange(previousPet, data.pet_assist)'));
assert(appSource.includes('clearPetLevelUpEffect()'));
assert(appSource.includes('lastPetAssistEventId'));
assert(appSource.includes('formatPetAssistMessage(event)'));
assert(appSource.includes('parseRoomPetManifestation(text)'));
assert(appSource.includes('showPetAssistEffect(event'));
assert(appSource.includes("'ancient': 'skill-ancient-awakening'"));
assert(appSource.includes('getPetCultivationLabel(pet = this.battlePet)'));
assert(appSource.includes("combat_mode || '') === 'pvp'"));
assert(appSource.includes('toggleSoundEffects()'));
assert(appSource.includes('createGameSoundSpriteDataUri()'));
assert(appSource.includes('triggerGameFeedback(kind'));
assert(appSource.includes('handleNarrativeEffects(lines)'));
assert(appSource.includes('initializeAutoAnimate()'));
assert(appSource.includes('shouldAnimateMudOutputCommand(command)'));
for (const petCommand of [
  'pet',
  'pet_hunt',
  'pet_duel',
  'daily',
  'daily_cultivation',
  'wanling_rift'
]) {
  assert(appSource.includes(petCommand));
}
assert(appSource.includes('startUiTour()'));
assert(appSource.includes("window.driver?.js?.driver"));
assert(appSource.includes("disableForReducedMotion: true"));
assert(appSource.includes("useWorker: true"));
assert(appSource.includes("'heal': 'skill-heal-bloom'"));
assert(appSource.includes("'summon': 'skill-summon-circle'"));
assert(appSource.includes("'lightning': 'skill-lightning-strike'"));
assert(appSource.includes("fontSize: 'small'"));
assert(appSource.includes('changeFontSize(event)'));
assert(appSource.includes('applyFontSize()'));
assert(appSource.includes("localStorage.setItem('mud_font_size', this.fontSize)"));
assert(appSource.includes('if (data.in_battle)'));
assert(appSource.includes('this.isInBattle = true'));
assert(appSource.includes('this.isInBattle = false'));
assert(appSource.includes('this.syncBattleAoeReport(data.recent_aoe_report)'));
assert(!appSource.includes("console.log('cmd:', cmd)"));
assert(!appSource.includes('[sendJsonCommand] txd:'));
assert(!appSource.includes('[sendJsonCommand] 完整URL:'));
assert(!appSource.includes('fullUrl: window.location.href'));
assert(cssSource.includes('.newbie-completion-modal'));
assert(cssSource.includes('.player-avatar-shell'));
assert(cssSource.includes('.player-avatar-image'));
assert(cssSource.includes('.player-avatar-fallback'));
assert(cssSource.includes('.level-cap-badge'));
assert(cssSource.includes('.level-cap-badge.blocked'));
assert(cssSource.includes('@keyframes newbieCompletionPop'));
assert(cssSource.includes('2026 UI/UX refresh'));
assert(cssSource.includes('padding: 24px 28px 34px'));
assert(cssSource.includes('min-height: 44px'));
assert(cssSource.includes('env(safe-area-inset-bottom, 0px)'));
assert(cssSource.includes('--quick-nav-height: 52px'));
assert(cssSource.includes('height: var(--quick-nav-height)'));
assert(cssSource.includes('padding-bottom: calc(var(--quick-nav-height)'));
assert(cssSource.includes('.game-frame-container.battle-dock-active'));
assert(cssSource.includes('.game-frame-container.battle-dock-collapsed'));
assert(cssSource.includes('.battle-panel.mini-mode.dock-collapsed'));
assert(cssSource.includes('.battle-aoe-report'));
assert(cssSource.includes('.battle-aoe-target.defeated'));
assert(cssSource.includes('.battle-aoe-target.revived'));
assert(cssSource.includes('.battle-skill-stage'));
assert(cssSource.includes('.skill-effect-container.skill-target-player'));
assert(cssSource.includes('.skill-effect-container.skill-target-enemy'));
assert(cssSource.includes('.skill-effect-label'));
assert(cssSource.includes('.skill-heal-bloom'));
assert(cssSource.includes('.skill-summon-circle'));
assert(cssSource.includes('.skill-lightning-strike'));
assert(cssSource.includes('.skill-fire-burst'));
assert(cssSource.includes('.skill-spirit-orbit'));
assert(cssSource.includes('--battle-dock-height: 138px'));
assert(cssSource.includes('.battle-pet-companion'));
assert(cssSource.includes('.battle-pet-assist-burst'));
assert(cssSource.includes('@keyframes petAssistBurst'));
assert(cssSource.includes('.log-pet .log-message'));
assert(cssSource.includes('.battle-resource-row'));
assert(cssSource.includes('.battle-meta'));
assert(cssSource.includes('.battle-panel.fullscreen-mode .combatant-vertical .stat-item'));
assert(cssSource.includes('--quick-nav-bottom-offset: 14px'));
assert(cssSource.includes('var(--quick-nav-bottom-offset) + 8px'));
assert(cssSource.includes('z-index: 1700'));
assert(cssSource.includes('--mud-font-size: 14px'));
assert(cssSource.includes(':root[data-font-size="normal"]'));
assert(cssSource.includes(':root[data-font-size="large"]'));
assert(cssSource.includes(':root[data-font-size="xlarge"]'));
assert(cssSource.includes('font-size: var(--mud-font-size)'));
assert(cssSource.includes('margin: var(--mud-control-gap-y) var(--mud-control-gap-x)'));
assert(!cssSource.includes('padding-top: 82px'));
assert(cssSource.includes('@media (min-width: 1340px)'));
assert(cssSource.includes('@media (max-width: 389px)'));
assert(cssSource.includes('@media (min-width: 390px) and (max-width: 600px)'));
assert(cssSource.includes('@media (min-width: 601px) and (max-width: 1024px)'));
assert(cssSource.includes('@media (min-width: 1025px) and (pointer: fine)'));
assert(cssSource.includes('@media (prefers-reduced-motion: reduce)'));
assert(cssSource.includes('.game-celebration-canvas'));
assert(cssSource.includes('.driver-popover.xiand-driver-popover'));
assert(cssSource.includes('.ui-toast-stage'));

assert(buildSource.includes("path.join(__dirname, 'css', 'app.css')"));
assert(buildSource.includes("path.join(__dirname, 'css', 'realm.css')"));
assert(buildSource.includes("path.join(__dirname, 'js', 'app.js')"));
assert(buildSource.includes("'vue.global.prod.js'"));
assert(buildSource.includes("'VUE_LICENSE.txt'"));
assert(buildSource.includes("'canvas-confetti.js'"));
assert(buildSource.includes("'howler.core.min.js'"));
assert(buildSource.includes("'auto-animate.min.js'"));
assert(buildSource.includes("'driver.iife.js'"));
assert(buildSource.includes("'driver.css'"));
assert(buildSource.includes("path.join(__dirname, 'dist')"));
for (const vendorAsset of [
  'canvas-confetti.js',
  'howler.core.min.js',
  'auto-animate.min.js',
  'driver.iife.js',
  'driver.css'
]) {
  assert(sharedBuildSource.includes(vendorAsset));
}
assert(sharedBuildSource.includes('npm ci'));

assert(serveSource.includes("process.env.XIAND_VUE_PORT || 3000"));
assert(serveSource.includes("process.env.XIAND_HTTP_PORT || 8888"));
assert(serveSource.includes("const { createManifest } = require('./manifest')"));
assert(serveSource.includes("pathname === '/manifest.json'"));
assert(serveSource.includes("['/vendor/vue.global.prod.js', 'vue/dist/vue.global.prod.js']"));
assert(serveSource.includes("['/vendor/canvas-confetti.js', 'canvas-confetti/dist/confetti.browser.js']"));
assert(serveSource.includes("['/vendor/howler.core.min.js', 'howler/dist/howler.core.min.js']"));
assert(serveSource.includes("['/vendor/auto-animate.min.js', '@formkit/auto-animate/index.min.js']"));
assert(serveSource.includes("['/vendor/driver.iife.js', 'driver.js/dist/driver.js.iife.js']"));
assert(serveSource.includes('VENDOR_FILES.has(pathname)'));
assert(serveSource.includes("data.toString('utf8').replace(/BUILD_VERSION/g, DEV_BUILD_VERSION)"));
assert(serveSource.includes("pathname.startsWith('/includes/')"));
assert(serveSource.includes('isWithinRoot(STATIC_ROOT, filePath)'));

assert(rebuildSource.includes('scripts/build/build_vue_frontend.sh'));
assert(rebuildSource.includes('build_vue_frontend'));
assert(rebuildSource.includes('BUILD_FRONTEND_ONLY'));
const mainSource = rebuildSource.slice(rebuildSource.indexOf('main()'));
assert(mainSource.indexOf('build_vue_frontend') < mainSource.indexOf('build_image'));

assert(/^COPY\s+web\s+\/usr\/local\/tomcat\/webapps\/ROOT/m.test(dockerSource));
assert.strictEqual(manifest.id, './');
assert.strictEqual(manifest.start_url, './');
assert.strictEqual(manifest.scope, './');
assert.strictEqual(manifest.icons[0].src, 'favicon.ico');

const inlineScripts = Array.from(indexSource.matchAll(/<script>([\s\S]*?)<\/script>/g));
const translateBootstrap = inlineScripts
  .map(match => match[1])
  .find(script => script.includes('Restored language without reload'));
assert(translateBootstrap, 'translation bootstrap script should exist');

function runTranslationBootstrap(userLanguage, storedTarget) {
  const values = new Map();
  if (userLanguage) values.set('userLanguage', userLanguage);
  if (storedTarget) values.set('to', storedTarget);
  let reloadCalls = 0;
  let autoDetectCalls = 0;
  let executeCalls = 0;
  const vueInstance = { selectedLanguage: '' };
  const translate = {
    to: storedTarget || '',
    service: { use() {} },
    language: { setLocal() {} },
    storage: {
      get(key) {
        return values.get(key) || '';
      },
      set(key, value) {
        values.set(key, value);
      }
    },
    execute() {
      executeCalls += 1;
    },
    changeLanguage() {
      reloadCalls += 1;
    },
    autoDiscriminateLocalLanguage() {
      autoDetectCalls += 1;
    }
  };
  vm.runInNewContext(translateBootstrap, {
    console: { log() {}, error() {} },
    document: {
      querySelector() {
        return null;
      },
      getElementById() {
        return null;
      }
    },
    localStorage: {
      getItem(key) {
        return values.get(key) || null;
      },
      setItem(key, value) {
        values.set(key, value);
      }
    },
    translate,
    window: {
      vueInstance,
      addEventListener() {}
    }
  });
  return {
    autoDetectCalls,
    executeCalls,
    reloadCalls,
    selectedLanguage: vueInstance.selectedLanguage,
    storedLanguage: values.get('userLanguage'),
    storedTarget: values.get('to'),
    target: translate.to
  };
}

const restoredEnglish = runTranslationBootstrap('english', 'english');
assert.deepStrictEqual(restoredEnglish, {
  autoDetectCalls: 0,
  executeCalls: 1,
  reloadCalls: 0,
  selectedLanguage: 'english',
  storedLanguage: 'english',
  storedTarget: 'english',
  target: 'english'
});

const firstMobileVisit = runTranslationBootstrap(null, 'english');
assert.deepStrictEqual(firstMobileVisit, {
  autoDetectCalls: 0,
  executeCalls: 1,
  reloadCalls: 0,
  selectedLanguage: 'chinese_simplified',
  storedLanguage: 'chinese_simplified',
  storedTarget: '',
  target: ''
});

console.log('✓ Vue build pipeline contract passed');
