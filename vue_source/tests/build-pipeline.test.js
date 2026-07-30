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
const rebuildSource = read('rebuild-image.sh');
const dockerSource = read('docker/Dockerfile.all');
const manifest = createManifest('test-version');

assert(indexSource.includes('css/app.css?v=BUILD_VERSION'));
assert(indexSource.includes('css/realm.css?v=BUILD_VERSION'));
assert(indexSource.includes('js/app.js?v=BUILD_VERSION'));
assert(indexSource.includes('manifest.json'));
assert(indexSource.includes('vendor/vue.global.prod.js?v=BUILD_VERSION'));
assert(!indexSource.includes('unpkg.com/vue'));
assert(indexSource.includes('v-if="activeNewbieCompletion"'));
assert(indexSource.includes('@click="continueNewbieGuide"'));

const appSource = read('vue_source/js/app.js');
const cssSource = read('vue_source/css/app.css');
assert(appSource.includes('handleNewbieCompletions(data.newbie_completions || [])'));
assert(appSource.includes('showNextNewbieCompletion()'));
assert(appSource.includes('dismissNewbieCompletions()'));
assert(appSource.includes('this.dismissNewbieCompletions();'));
assert(cssSource.includes('.newbie-completion-modal'));
assert(cssSource.includes('@keyframes newbieCompletionPop'));

assert(buildSource.includes("path.join(__dirname, 'css', 'app.css')"));
assert(buildSource.includes("path.join(__dirname, 'css', 'realm.css')"));
assert(buildSource.includes("path.join(__dirname, 'js', 'app.js')"));
assert(buildSource.includes("'vue.global.prod.js'"));
assert(buildSource.includes("'VUE_LICENSE.txt'"));
assert(buildSource.includes("path.join(__dirname, 'dist')"));

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
