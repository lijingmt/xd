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
assert.strictEqual(client.equipmentLevelClass({ level_requirement: 160 }), 'equipment-level-6');
assert.strictEqual(client.equipmentLevelClass({ level_requirement: 200 }), 'equipment-level-7');

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

assert.strictEqual(client.petLevelAuraClass(null), 'pet-level-aura-0');
assert.strictEqual(
    client.petLevelAuraClass({ active: 1, level: 120 }),
    'pet-level-aura-4'
);
assert.strictEqual(
    client.petRarityAuraClass({ active: 1, level: 120, star: 5, evolution: 1 }),
    'pet-rarity-aura-4'
);
assert.strictEqual(
    client.petRarityAuraClass({ active: 1, star: 2, evolution: 4 }),
    'pet-rarity-aura-7'
);
assert.strictEqual(
    client.monsterLevelAuraClass({ is_npc: 1, level: 200 }),
    'monster-level-aura-6'
);
assert.strictEqual(
    client.monsterLevelAuraClass({ is_npc: 0, level: 250 }),
    'monster-level-aura-0'
);
assert.strictEqual(
    client.petRarityAuraClass({ active: 1, rarity: 'damaged' }),
    'pet-rarity-aura-0'
);
assert.strictEqual(
    client.monsterLevelAuraClass({ is_npc: 1, level: 'damaged' }),
    'monster-level-aura-0'
);

assert(htmlSource.includes('playerLevelAuraClass'));
assert(!htmlSource.includes('playerLevelAuraClass()'));
assert(htmlSource.includes('equipmentLevelClass(item)'));
assert(htmlSource.includes('getEquipmentImageUrl(item, equipmentSelectedSlot)'));
assert(htmlSource.includes('v-if="equipmentPanel.equipped[slot]"'));
assert(htmlSource.includes('<span v-else aria-hidden="true">'));
assert(htmlSource.includes('equipment-panel-avatar'));
assert(htmlSource.includes('petLevelAuraClass(slot)'));
assert(htmlSource.includes('petRarityAuraClass(battlePet)'));
assert(htmlSource.includes('monsterLevelAuraClass(battleEnemy)'));
assert(cssSource.includes('.equipment-rarity-7'));
assert(cssSource.includes('.equipment-level-7 .equipment-item-art'));
assert(cssSource.includes('.player-avatar-shell.level-aura-7'));
assert(cssSource.includes('.pet-level-aura-7'));
assert(cssSource.includes('.pet-rarity-aura-7'));
assert(cssSource.includes('.monster-level-aura-7'));
assert(cssSource.includes('@keyframes equipment-high-level-breathe'));
assert(cssSource.includes('@keyframes pet-avatar-aura-orbit'));
assert(cssSource.includes('@keyframes monster-avatar-aura-pulse'));

console.log('人物、宠物、装备与高等级怪物统一成长光环测试通过');
