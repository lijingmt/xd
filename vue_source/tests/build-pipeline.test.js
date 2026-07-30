const assert = require('assert');
const fs = require('fs');
const path = require('path');
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
assert(indexSource.includes('@submit.prevent="doLogin"'));
assert(indexSource.includes('autocomplete="current-password"'));
assert(indexSource.includes('role="progressbar"'));
assert(indexSource.includes(':aria-busy="mudLoading ? \'true\' : \'false\'"'));
assert(indexSource.includes('class="quick-primary-nav"'));
assert(indexSource.includes('class="quick-more-panel"'));
assert.strictEqual(
  (indexSource.match(/<main\b/g) || []).length,
  (indexSource.match(/<\/main>/g) || []).length
);
assert(indexSource.includes('v-if="activeNewbieCompletion"'));
assert(indexSource.includes('@click="continueNewbieGuide"'));

const appSource = read('vue_source/js/app.js');
const cssSource = read('vue_source/css/app.css');
assert(appSource.includes('handleNewbieCompletions(data.newbie_completions || [])'));
assert(appSource.includes('showNextNewbieCompletion()'));
assert(appSource.includes('dismissNewbieCompletions()'));
assert(appSource.includes('this.dismissNewbieCompletions();'));
assert(appSource.includes('getStatPercent(current, maximum)'));
assert(appSource.includes('formatCompactNumber(value)'));
assert(appSource.includes('showUiToast(message, type = \'info\')'));
assert(appSource.includes('isQuickActionActive(command)'));
assert(appSource.includes('quickActionsCollapsed: true'));
assert(!appSource.includes("console.log('cmd:', cmd)"));
assert(!appSource.includes('[sendJsonCommand] txd:'));
assert(!appSource.includes('[sendJsonCommand] 完整URL:'));
assert(!appSource.includes('fullUrl: window.location.href'));
assert(cssSource.includes('.newbie-completion-modal'));
assert(cssSource.includes('@keyframes newbieCompletionPop'));
assert(cssSource.includes('2026 UI/UX refresh'));
assert(cssSource.includes('padding: 24px 28px 34px'));
assert(cssSource.includes('min-height: 44px'));
assert(cssSource.includes('env(safe-area-inset-bottom, 0px)'));
assert(cssSource.includes('--quick-nav-height: 52px'));
assert(cssSource.includes('height: var(--quick-nav-height)'));
assert(cssSource.includes('padding-bottom: calc(var(--quick-nav-height)'));
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

console.log('✓ Vue build pipeline contract passed');
