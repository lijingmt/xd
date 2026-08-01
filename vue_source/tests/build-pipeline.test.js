const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');
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
const dockerSource = read('docker/Dockerfile.all');
const manifest = createManifest('test-version');

assert(indexSource.includes('css/app.css?v=BUILD_VERSION'));
assert(indexSource.includes('css/realm.css?v=BUILD_VERSION'));
assert(indexSource.includes('js/app.js?v=BUILD_VERSION'));
assert(indexSource.includes('manifest.json'));
assert(indexSource.includes('vendor/vue.global.prod.js?v=BUILD_VERSION'));
assert(!indexSource.includes('unpkg.com/vue'));
assert(!indexSource.includes('user-scalable=no'));
assert(!indexSource.includes('maximum-scale=1.0'));
assert(indexSource.includes('viewport-fit=cover'));
assert(indexSource.includes('class="modal auth-modal"'));
assert(!indexSource.includes('@submit.prevent="doLogin"'));
assert(indexSource.includes('@click="doLogin"'));
assert.strictEqual(
  (indexSource.match(/@keyup\.enter="doLogin"/g) || []).length,
  2
);
assert(indexSource.includes('name="username"'));
assert(indexSource.includes('name="password"'));
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
assert(indexSource.includes('class="player-avatar-shell"'));
assert(indexSource.includes(':src="playerAvatarUrl"'));
assert(indexSource.includes('@error="handlePlayerAvatarError"'));
assert(indexSource.includes("sendQuickCommand('profession_assistant')"));
assert(indexSource.includes('playerStats?.profession_assistant?.style_class'));
assert(indexSource.includes('class="profession-assistant-badge"'));
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
assert(cssSource.includes('.ui-toast-action'));
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
assert(cssSource.includes('.battle-skill-stage'));
assert(cssSource.includes('.skill-effect-container.skill-target-player'));
assert(cssSource.includes('.skill-effect-container.skill-target-enemy'));
assert(cssSource.includes('.skill-effect-label'));
assert(cssSource.includes('.skill-heal-bloom'));
assert(cssSource.includes('.skill-summon-circle'));
assert(cssSource.includes('.skill-lightning-strike'));
assert(cssSource.includes('.skill-fire-burst'));
assert(cssSource.includes('.skill-spirit-orbit'));
assert(cssSource.includes('--battle-dock-height: 108px'));
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

assert(buildSource.includes("path.join(__dirname, 'css', 'app.css')"));
assert(buildSource.includes("path.join(__dirname, 'css', 'realm.css')"));
assert(buildSource.includes("path.join(__dirname, 'js', 'app.js')"));
assert(buildSource.includes("'vue.global.prod.js'"));
assert(buildSource.includes("'VUE_LICENSE.txt'"));
assert(buildSource.includes("path.join(__dirname, 'dist')"));

assert(serveSource.includes("process.env.XIAND_VUE_PORT || 3000"));
assert(serveSource.includes("process.env.XIAND_HTTP_PORT || 8888"));
assert(serveSource.includes("data.toString('utf8').replace(/BUILD_VERSION/g"));
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
