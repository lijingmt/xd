const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const sourceDir = path.resolve(__dirname, '..');
const rootDir = path.resolve(sourceDir, '..');
const read = (...parts) => fs.readFileSync(path.join(...parts), 'utf8');

const index = read(sourceDir, 'index.html');
const app = read(sourceDir, 'js', 'app.js');
const pcCss = read(sourceDir, 'css', 'pc.css');
const build = read(sourceDir, 'build.js');
const serve = read(sourceDir, 'serve.js');
const selector = read(rootDir, 'web', 'pc.jsp');
const buildShell = read(rootDir, 'scripts', 'build', 'build_vue_frontend.sh');
const packageJson = JSON.parse(read(sourceDir, 'package.json'));

assert(!index.includes('href="css/pc.css'),
    'mobile index must not load isolated desktop CSS');
assert(index.includes("v-if=\"clientLayout === 'pc'\""));
assert(index.includes('class="pc-desktop-bar"'));
for (const key of ['1', '2', '3', '4', '5', 'M', 'T', 'A']) {
    assert(index.includes(`data-pc-key="${key}"`), `missing desktop shortcut hint ${key}`);
}

assert(app.includes("/\\/pc\\.html$/.test(window.location.pathname || '')"));
assert(app.includes('handleDesktopKeydown(event)'));
assert(app.includes('target?.isContentEditable'));
assert(app.includes("['input', 'textarea', 'select'].includes(tagName)"));
assert(app.includes("window.addEventListener('keydown', this.desktopKeydownHandler)"));
assert(app.includes("window.removeEventListener('keydown', this.desktopKeydownHandler)"));
assert(app.includes('switchClientLayout(layout)'));

for (const contract of [
    ':root[data-client-layout="pc"]',
    '@media (min-width: 960px) and (pointer: fine)',
    'html[data-client-layout="pc"] .game-header',
    'html[data-client-layout="pc"] .quick-actions',
    'html[data-client-layout="pc"] .game-frame-container',
    'html[data-client-layout="pc"] .battle-panel.mini-mode',
    'html[data-client-layout="pc"] button:focus-visible',
    'content: attr(data-pc-key)',
    '@media (min-width: 1440px) and (pointer: fine)'
]) {
    assert(pcCss.includes(contract), `missing isolated PC layout contract: ${contract}`);
}
assert(!/^\s*\.game-header\s*\{/m.test(pcCss),
    'desktop rules must remain scoped and never target the mobile header globally');
assert(!/^\s*\.quick-actions\s*\{/m.test(pcCss),
    'desktop rules must remain scoped and never target mobile navigation globally');

assert(build.includes('function processPcHTML(content)'));
assert(build.includes("path.join(distDir, 'pc.html')"));
assert(build.includes("path.join(distDir, 'css', 'pc.css')"));
assert(serve.includes("if (pathname === '/pc.html')"));
assert(serve.includes('function createPcEntry(content)'));
assert(buildShell.includes('"pc.html"'));
assert(buildShell.includes('"css/pc.css"'));
assert(buildShell.includes('mobile index unexpectedly loads desktop CSS'));

assert(selector.includes("selectUI('desktop')"));
assert(selector.includes("savedUI === 'desktop'"));
assert(selector.includes("'web_vue/pc.html'"));
assert(packageJson.scripts.test.includes('node tests/desktop-layout.test.js'));

let componentOptions = null;
vm.runInNewContext(app, {
    Vue: {
        markRaw(value) { return value; },
        createApp(options) {
            componentOptions = options;
            return { mount() {} };
        }
    },
    window: { crypto: {}, handleChatLinkClick: null },
    document: {},
    localStorage: { getItem() { return null; } },
    sessionStorage: { getItem() { return null; } },
    navigator: {},
    console,
    TextEncoder,
    URL,
    URLSearchParams,
    btoa(value) { return Buffer.from(value, 'binary').toString('base64'); },
    setTimeout,
    clearTimeout,
    setInterval,
    clearInterval
}, { filename: 'app.js' });
assert(componentOptions?.methods?.handleDesktopKeydown,
    'desktop keyboard method must be registered on the real Vue component');

const commands = [];
let autofightToggles = 0;
const keyboardContext = {
    clientLayout: 'pc', txd: 'session', showLogin: false, showRegister: false,
    showCharacterSelect: false, showChatRoom: false, inviteModalOpen: false,
    showEquipmentPanel: false,
    sendQuickCommand(command) { commands.push(command); },
    toggleQuickActions() { commands.push('more'); },
    toggleAutofight() { autofightToggles += 1; }
};
function keyEvent(code, target = { tagName: 'BODY' }, extra = {}) {
    return Object.assign({
        code, target, defaultPrevented: false, repeat: false,
        ctrlKey: false, metaKey: false, altKey: false,
        preventDefault() { this.defaultPrevented = true; }
    }, extra);
}
componentOptions.methods.handleDesktopKeydown.call(keyboardContext, keyEvent('Digit1'));
componentOptions.methods.handleDesktopKeydown.call(keyboardContext, keyEvent('KeyM'));
componentOptions.methods.handleDesktopKeydown.call(keyboardContext, keyEvent('KeyT'));
componentOptions.methods.handleDesktopKeydown.call(keyboardContext, keyEvent('KeyA'));
assert.deepStrictEqual(commands, ['look', 'map_display', 'mytasks']);
assert.strictEqual(autofightToggles, 1);

componentOptions.methods.handleDesktopKeydown.call(
    keyboardContext,
    keyEvent('Digit3', { tagName: 'INPUT', isContentEditable: false })
);
componentOptions.methods.handleDesktopKeydown.call(
    keyboardContext,
    keyEvent('Digit4', { tagName: 'BODY' }, { ctrlKey: true })
);
keyboardContext.clientLayout = 'mobile';
componentOptions.methods.handleDesktopKeydown.call(keyboardContext, keyEvent('Digit2'));
assert.deepStrictEqual(commands, ['look', 'map_display', 'mytasks'],
    'typing, browser combinations and the mobile client must never trigger PC shortcuts');

console.log('Isolated PC layout tests passed.');
