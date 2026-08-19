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
const visualMapAsset = path.join(rootDir, 'images', 'visual_map',
    'red-cloud-terrace-v1.webp');
const terrainAtlasAsset = path.join(rootDir, 'images', 'visual_map',
    'world-terrain-atlas-v1.webp');

assert(!index.includes('href="css/pc.css'),
    'mobile index must not load isolated desktop CSS');
assert(index.includes("v-if=\"clientLayout === 'pc'\""));
assert(index.includes('class="pc-command-deck"'));
assert(index.includes('class="pc-command-grid"'));
assert(index.includes("sendQuickCommand('go_warehouse')"));
assert(index.includes('class="desktop-rpg-shell"'));
assert(index.includes('class="desktop-scene-stage"'));
assert(index.includes('class="desktop-nearby-map"'));
assert(index.includes('class="desktop-terrain-tile"'));
assert(index.includes('ref="desktopWorldCanvas"'));
assert(index.includes('moveDesktopScene(tile.exit)'));
assert(index.includes('inspectDesktopEntity(entity)'));
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
assert(app.includes('extractDesktopRoom(lines)'));
assert(app.includes('captureDesktopVisualState(lines'));
assert(app.includes('startDesktopSceneSync()'));
assert(app.includes('loadDesktopWorldGraph()'));
assert(app.includes('renderDesktopWorldMap()'));
assert(app.includes("new URL('data/world-map.json', window.location.href)"));
assert(app.includes("cmd: 'look'"));
assert(fs.existsSync(visualMapAsset), 'generated visual map asset is missing');
assert(fs.statSync(visualMapAsset).size < 700 * 1024,
    'visual map background must stay web-sized');
assert(fs.existsSync(terrainAtlasAsset), 'generated terrain atlas is missing');
assert(fs.statSync(terrainAtlasAsset).size < 900 * 1024,
    'terrain atlas must stay web-sized');

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
for (const contract of [
    '.desktop-rpg-shell', '.desktop-scene-stage', '.desktop-nearby-map',
    '.desktop-terrain-tile', '.desktop-scene-actor', '.desktop-world-map-overlay',
    'canvas.desktop-world-map-canvas', '.desktop-target-panel',
    '.desktop-scene-console'
]) {
    assert(pcCss.includes(contract), `missing visual RPG contract: ${contract}`);
}

assert(build.includes('function processPcHTML(content)'));
assert(build.includes("path.join(distDir, 'pc.html')"));
assert(build.includes("path.join(distDir, 'css', 'pc.css')"));
assert(build.includes("'red-cloud-terrace-v1.webp'"));
assert(build.includes("'world-terrain-atlas-v1.webp'"));
assert(build.includes("'world-map.json'"));
assert(serve.includes("if (pathname === '/pc.html')"));
assert(serve.includes('function createPcEntry(content)'));
assert(buildShell.includes('"pc.html"'));
assert(buildShell.includes('"css/pc.css"'));
assert(buildShell.includes('mobile index unexpectedly loads desktop CSS'));
assert(buildShell.includes('VISUAL_MAP_OUTPUT'));
assert(buildShell.includes('TERRAIN_ATLAS_OUTPUT'));
assert(buildShell.includes('WORLD_MAP_SOURCE'));

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

const methods = componentOptions.methods;
const sceneContext = {
    desktopScene: null,
    desktopSceneSelected: null,
    desktopSceneActions: [],
    desktopWorldNode: null,
    desktopWorldNodeIndex: null,
    desktopWorldNameIndex: null,
    desktopServerRoomId: '',
    clientLayout: 'pc'
};
for (const methodName of [
    'desktopPlainText', 'desktopLineText', 'parseDesktopExit',
    'extractDesktopRoom', 'extractDesktopContextActions',
    'findDesktopDirectEntityAction', 'captureDesktopVisualState',
    'normalizeDesktopRoomName', 'desktopDirectionKey',
    'resolveDesktopWorldNode', 'desktopNearbyTiles',
    'desktopTerrainCell', 'getDesktopTerrainTileStyle',
    'getDesktopNearbyTileStyle'
]) {
    sceneContext[methodName] = (...args) => methods[methodName].call(sceneContext, ...args);
}
const roomLines = [
    { type: 'line', segments: [{ type: 'text', parts: [{ content: '赤灵云台' }] }] },
    { type: 'line', segments: [
        { type: 'text', parts: [{ content: '这里有' }] },
        { type: 'image', src: '/images/bird_male.gif' },
        { type: 'button', label: '赤鳞蛟龙(200)', cmd: 'c_monster', visual_kind: 'monster' }
    ] },
    { type: 'line', segments: [
        { type: 'text', parts: [{ content: '你遇到了' }] },
        { type: 'image', src: '/images/user/hero.gif' },
        { type: 'button', label: '月下行者', cmd: 'c_player', visual_kind: 'player' }
    ] },
    { type: 'line', segments: [
        { type: 'text', parts: [{ content: '这里有' }] },
        { type: 'image', src: '/images/item/ore.gif' },
        { type: 'button', label: '赤灵矿石(20)', cmd: 'c_item', visual_kind: 'item' }
    ] },
    { type: 'line', segments: [{ type: 'text', parts: [{ content: '请选择你的行走方向：' }] }] },
    { type: 'line', segments: [
        { type: 'button', label: '西←：赤灵溪流', cmd: 'c_west' },
        { type: 'button', label: '东→：赤灵细径', cmd: 'c_east' }
    ] }
];
const room = sceneContext.extractDesktopRoom(roomLines);
assert.strictEqual(room.roomName, '赤灵云台');
assert.strictEqual(
    JSON.stringify(room.exits.map(exit => [exit.direction, exit.destination])),
    JSON.stringify([['西', '赤灵溪流'], ['东', '赤灵细径']])
);
assert.strictEqual(room.entities.length, 2);
assert.strictEqual(room.entities[0].kind, 'monster');
assert.strictEqual(room.entities[0].level, 200);
assert.strictEqual(room.entities[1].kind, 'player');
assert.strictEqual(sceneContext.captureDesktopVisualState(roomLines), true);
assert.strictEqual(sceneContext.desktopScene.roomName, '赤灵云台');

const graphNodes = [
    {
        id: 'test/cloud', name: '赤灵云台', region: 'test', biome: 'mountain',
        exits: [{ direction: 'east', target: 'test/path' }]
    },
    {
        id: 'test/path', name: '赤灵细径', region: 'test', biome: 'forest',
        exits: [{ direction: 'west', target: 'test/cloud' }]
    }
];
sceneContext.desktopWorldNodeIndex = new Map(graphNodes.map(node => [node.id, node]));
sceneContext.desktopWorldNameIndex = new Map([
    ['赤灵云台', [graphNodes[0]]], ['赤灵细径', [graphNodes[1]]]
]);
assert.strictEqual(sceneContext.resolveDesktopWorldNode(room)?.id, 'test/cloud');
sceneContext.desktopServerRoomId = 'test/path';
assert.strictEqual(sceneContext.resolveDesktopWorldNode(room)?.id, 'test/path',
    'server room id must disambiguate duplicate display names exactly');
sceneContext.desktopServerRoomId = '';
sceneContext.resolveDesktopWorldNode(room);
sceneContext.desktopScene = room;
const nearbyTiles = sceneContext.desktopNearbyTiles();
assert.strictEqual(nearbyTiles.length, 9);
assert.strictEqual(nearbyTiles.find(tile => tile.current).name, '赤灵云台');
assert.strictEqual(nearbyTiles.find(tile => tile.exit?.direction === '东').node.id, 'test/path');
assert.strictEqual(nearbyTiles.find(tile => tile.exit?.direction === '东').biome, 'forest');

const detailLines = [{ type: 'line', segments: [
    { type: 'text', parts: [{ content: '赤鳞蛟龙盘踞于此。' }] },
    { type: 'button', label: '普通战斗', cmd: 'c_kill' },
    { type: 'button', label: '快速战斗', cmd: 'c_quick' },
    { type: 'button', label: '状态', cmd: 'c_status' }
] }];
sceneContext.desktopSceneSelected = room.entities[0];
assert.strictEqual(sceneContext.captureDesktopVisualState(detailLines), false);
assert.strictEqual(
    JSON.stringify(sceneContext.desktopSceneActions.map(action => action.label)),
    JSON.stringify(['普通战斗', '快速战斗'])
);
assert.strictEqual(sceneContext.desktopScene.roomName, '赤灵云台',
    'detail pages must preserve the last authoritative room snapshot');
const listLines = [{ type: 'line', segments: [
    { type: 'button', label: '蓬莱水妖(200)', cmd: 'c_npc_1' },
    { type: 'button', label: '赤鳞蛟龙(200)', cmd: 'c_npc_2' }
] }];
assert.strictEqual(
    sceneContext.findDesktopDirectEntityAction(room.entities[0], listLines)?.cmd,
    'c_npc_2',
    'one visual click must resolve the exact target from the legacy room list'
);

console.log('Isolated PC layout tests passed.');
