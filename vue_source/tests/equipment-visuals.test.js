const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

let componentOptions = null;
const sandbox = {
    Vue: {
        createApp(options) {
            componentOptions = options;
            return { mount() {} };
        }
    },
    window: {
        crypto: {},
        location: {
            protocol: 'http:', hostname: 'localhost',
            host: 'localhost:8080', origin: 'http://localhost:8080',
            pathname: '/xd/vue/', href: 'http://localhost:8080/xd/vue/'
        },
        history: { replaceState() {} },
        matchMedia() { return { matches: false }; },
        addEventListener() {}, removeEventListener() {}
    },
    document: { documentElement: { setAttribute() {} } },
    localStorage: {
        getItem() { return null; }, setItem() {}, removeItem() {}
    },
    sessionStorage: {
        getItem() { return null; }, setItem() {}, removeItem() {}
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

const root = path.resolve(__dirname, '..');
const appSource = fs.readFileSync(path.join(root, 'js/app.js'), 'utf8');
const htmlSource = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const cssSource = fs.readFileSync(path.join(root, 'css/app.css'), 'utf8');
vm.runInNewContext(appSource, sandbox, { filename: 'app.js' });
assert(componentOptions, 'Vue component should register');
const client = Object.assign(componentOptions.data(), componentOptions.methods);

assert.strictEqual(client.equipmentRarityClass({ rare_level: 0 }), 'equipment-rarity-0');
assert.strictEqual(client.equipmentRarityClass({ rare_level: 5 }), 'equipment-rarity-5');
assert.strictEqual(client.equipmentRarityClass({ rare_level: 99 }), 'equipment-rarity-7');
assert.strictEqual(client.equipmentLevelClass({ level_requirement: 19 }), 'equipment-level-0');
assert.strictEqual(client.equipmentLevelClass({ level_requirement: 60 }), 'equipment-level-3');
assert.strictEqual(client.equipmentLevelClass({ level_requirement: 100 }), 'equipment-level-5');

client.equipmentPanel = {
    slots: {
        armor_head: { image: '/images/equipment/fallback/armor_head.png' }
    }
};
assert.strictEqual(
    client.getEquipmentImageUrl({}, 'armor_head'),
    'http://localhost:8080/images/equipment/fallback/armor_head.png'
);

const expectedAuras = [
    [1, 'level-aura-0'], [30, 'level-aura-1'], [60, 'level-aura-2'],
    [90, 'level-aura-3'], [120, 'level-aura-4'], [160, 'level-aura-5'],
    [200, 'level-aura-6'], [250, 'level-aura-7']
];
for (const [level, expected] of expectedAuras) {
    client.playerStats = { level };
    assert.strictEqual(
        componentOptions.computed.playerLevelAuraClass.call(client),
        expected
    );
}

assert(htmlSource.includes('playerLevelAuraClass()'));
assert(htmlSource.includes('equipmentLevelClass(item)'));
assert(htmlSource.includes('getEquipmentImageUrl(item, equipmentSelectedSlot)'));
assert(htmlSource.includes('v-if="equipmentPanel.equipped[slot]"'));
assert(htmlSource.includes('<span v-else aria-hidden="true">'));
assert(cssSource.includes('.equipment-rarity-7'));
assert(cssSource.includes('.equipment-level-5 .equipment-item-art'));
assert(cssSource.includes('.player-avatar-shell.level-aura-7'));
assert(cssSource.includes('@keyframes equipment-high-level-breathe'));

console.log('装备图片、等级/稀缺度光效与人物等级头像光环测试通过');
