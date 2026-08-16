const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const Vue = require('vue');
const { renderToString } = require('@vue/server-renderer');

const sourceDir = path.resolve(__dirname, '..');
const indexSource = fs.readFileSync(path.join(sourceDir, 'index.html'), 'utf8');
const appSource = fs.readFileSync(path.join(sourceDir, 'js/app.js'), 'utf8');
const cssSource = fs.readFileSync(path.join(sourceDir, 'css/app.css'), 'utf8');

function extractAppTemplate(html) {
    const rootMarker = '<div id="app">';
    const rootStart = html.indexOf(rootMarker);
    const scriptsStart = html.indexOf('<script src="vendor/vue.global.prod.js');
    const rootEnd = html.lastIndexOf('</div>', scriptsStart);
    assert(rootStart >= 0, 'Vue #app root must exist');
    assert(scriptsStart > rootStart, 'local Vue runtime must load after #app');
    assert(rootEnd > rootStart, 'Vue #app root must close before runtime scripts');
    return html.slice(rootStart + rootMarker.length, rootEnd);
}

function createStorage() {
    const values = new Map();
    return {
        getItem(key) { return values.has(key) ? values.get(key) : null; },
        setItem(key, value) { values.set(key, String(value)); },
        removeItem(key) { values.delete(key); }
    };
}

function captureComponentOptions() {
    let componentOptions = null;
    const sandboxVue = Object.assign({}, Vue, {
        createApp(options) {
            componentOptions = options;
            return { mount() {} };
        }
    });
    const sandbox = {
        Vue: sandboxVue,
        window: {
            crypto: {},
            location: {
                protocol: 'http:', hostname: 'localhost',
                host: 'localhost:8080', origin: 'http://localhost:8080',
                pathname: '/xd/web_vue/index.html',
                href: 'http://localhost:8080/xd/web_vue/index.html', search: ''
            },
            history: { replaceState() {} },
            matchMedia() { return { matches: false }; },
            addEventListener() {}, removeEventListener() {}
        },
        document: {
            documentElement: { setAttribute() {} },
            querySelector() { return null; },
            addEventListener() {}, removeEventListener() {}
        },
        navigator: { sendBeacon() { return true; } },
        localStorage: createStorage(),
        sessionStorage: createStorage(),
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
    vm.runInNewContext(appSource, sandbox, { filename: 'js/app.js' });
    assert(componentOptions, 'app.js must register a Vue root component');
    return componentOptions;
}

function escapeRegExp(value) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

async function renderScenario(componentOptions, template, overrides) {
    const renderOptions = Object.assign({}, componentOptions, {
        template,
        data() {
            return Object.assign(componentOptions.data.call(this), overrides);
        }
    });
    for (const hook of [
        'beforeCreate', 'created', 'beforeMount', 'mounted',
        'beforeUnmount', 'unmounted'
    ]) {
        delete renderOptions[hook];
    }

    const warnings = [];
    const app = Vue.createSSRApp(renderOptions);
    app.config.warnHandler = (message) => warnings.push(message);
    const rendered = await renderToString(app);
    assert.deepStrictEqual(warnings, [], `Vue render warnings:\n${warnings.join('\n')}`);
    return rendered;
}

async function main() {
    const template = extractAppTemplate(indexSource);
    const componentOptions = captureComponentOptions();
    const computedNames = Object.keys(componentOptions.computed || {});

    for (const name of computedNames) {
        const calledLikeMethod = new RegExp(`\\b${escapeRegExp(name)}\\s*\\(`);
        assert(
            !calledLikeMethod.test(template),
            `computed property ${name} must be referenced as a value, not called as a method`
        );
    }

    const loginRendered = await renderScenario(componentOptions, template, {});
    assert(loginRendered.length > 1000, 'login render must produce a non-trivial page');
    assert(loginRendered.includes('auth-modal'), 'initial render must contain the login UI');
    assert(loginRendered.includes('登录游戏'), 'initial render must expose the login action');

	const illusionCreatorRendered = await renderScenario(componentOptions, template, {
		showLogin: false,
		showCharacterSelect: true,
		characterCreateOpen: true,
		accountToken: 'a'.repeat(64),
		accountSharedRechargeBalance: 500,
		accountSharedRechargeAvailable: true,
		illusionEntitled: true,
		illusionCharacterSlots: 1,
		illusionMultiCharacterUnlocked: false,
		illusionExpansionSpentSuiyu: 0,
		illusionRealmStatus: {
			ok: true, illusion_id: 'S1', display_name: '新月幻境·S1',
			phase: 'active', phase_name: '进行中', creation_open: true,
			extra_character_slot_cost_suiyu: 100,
			multi_character_unlock_cost_suiyu: 500
		},
		accountCharacters: [{
			id: 'xd01illusion', name_cn: '新月行者', level: 10,
			realm_type: 'illusion', illusion_id: 'S1',
			profession_id: 'jianxian', race_name: '人族', profession_name: '剑仙'
		}]
	});
	assert(
		illusionCreatorRendered.includes('illusion-expansion-card'),
		'full S1 creator must render the direct paid expansion card'
	);
	assert(
		illusionCreatorRendered.includes('100碎玉增加1格'),
		'creator must expose the direct single-slot purchase'
	);
	assert(
		illusionCreatorRendered.includes('补500碎玉解锁本期多人物'),
		'creator must expose the cumulative multi-character purchase'
	);
	assert(
		illusionCreatorRendered.includes('illusion-expansion-all-btn'),
		'cumulative purchase must render with its high-contrast button style hook'
	);

    const gameRendered = await renderScenario(componentOptions, template, {
        showLogin: false,
        playerStats: {
            name_cn: '测试玩家', level: 101, hp: 1000, hp_max: 1000,
            mana: 500, mana_max: 500,
            profession_assistant: { style_class: 'profession-style-fangshi' },
            pet_slots: {
                shared: {
                    active: 1, battle_active: 1, level: 120, star: 5,
                    evolution: 1, icon: '🐦', family: 'wind'
                },
                personal: {
                    active: 1, battle_active: 0, level: 60, star: 2,
                    evolution: 0, icon: '🦊', family: 'fire'
                }
            },
            autofight: 0, area: 'xd01'
        },
        isInBattle: true,
        battleEnemy: {
            name: '高阶测试首领', is_npc: 1, level: 200,
            hp: 50000, hpMax: 100000
        },
        battlePet: {
            active: 1, name: '测试灵伴', level: 120, star: 5,
            evolution: 1, icon: '🐦', family: 'wind', system: 'shared',
            cooldown_remaining: 0, cooldown_total: 10, skill: '风鸣', power: 8888
        },
        showEquipmentPanel: true,
        equipmentSelectedSlot: 'armor_head',
        equipmentPanel: {
            player: { name_cn: '测试玩家', level: 200, profession: '方士' },
            slot_order: ['armor_head'],
            slots: {
                armor_head: {
                    label: '头部', icon: '盔',
                    image: '/images/equipment/fallback/armor_head.png'
                }
            },
            equipped: {
                armor_head: {
                    id: 'test-head', name_cn: '测试仙盔', rare_level: 7,
                    level_requirement: 200,
                    image_url: '/images/equipment/fallback/armor_head.png'
                }
            },
            candidates: { armor_head: [] }
        },
        mudLines: [{
            type: 'line',
            segments: [{
                type: 'story-image',
                src: '/images/illusion_s1/story/chapters/chapter_003.png',
                alt: '新月长生劫第3章插画',
                cell: 0,
                full: 1,
                chapter: 3
            }]
        }, {
            type: 'line',
            segments: [{
                type: 'story-image',
                src: '/images/illusion_s1/story/chapters/chapter_081.png',
                alt: '新月长生劫第81章插画',
                cell: 0,
                full: 1,
                chapter: 81
            }]
        }, {
            type: 'line',
            segments: [{
                type: 'image',
                src: '/images/illusion_s1/story/chapters/chapter_009.png',
                alt: '新月长生劫第9章插画'
            }]
        }]
    });
    assert(gameRendered.length > 5000, 'game render must produce a non-trivial page');
    assert(gameRendered.includes('game-header'), 'game render must contain the player header');
    assert(gameRendered.includes('player-avatar-shell'), 'game render must contain the avatar action');
    assert(gameRendered.includes('pet-level-aura-4'), 'level-120 pet aura must render');
    assert(gameRendered.includes('pet-rarity-aura-4'), 'pet star/evolution rarity aura must render');
    assert(gameRendered.includes('monster-level-aura-6'), 'level-200 NPC aura must render');
    assert(gameRendered.includes('equipment-panel-avatar'), 'equipment panel player aura must render');
    assert(gameRendered.includes('equipment-level-7'), 'level-200 equipment aura must render');
    assert(gameRendered.includes('equipment-rarity-7'), 'rarest equipment aura must render');
    assert(gameRendered.includes('illusion-story-frame-full'), 'full chapter artwork must render in the real game output');
    assert(gameRendered.includes('background-size:cover'), 'independent chapter artwork must render without atlas cropping');
    assert(gameRendered.includes('新月长生劫第3章插画'), 'early subchapter artwork must keep its chapter-specific accessible description');
    assert(gameRendered.includes('新月长生劫第81章插画'), 'story image must keep a chapter-specific accessible description');
    assert(gameRendered.includes('chapter_009.png'), 'standard image segments must render chapter artwork for cached legacy Vue clients');
	assert(cssSource.includes('width: min(100%, 34rem, 72svh)'),
		'story artwork must be constrained by both container width and viewport height');
	assert(cssSource.includes('width: min(100%, 34rem, 72vh)'),
		'story artwork must keep a viewport-height fallback for older iOS browsers');
	assert(cssSource.includes('@supports (height: 1svh)'),
		'story artwork must keep a safe fallback while adapting phones, tablets and PC windows');

    console.log(
        `Vue真实首屏渲染测试通过：${computedNames.length}个computed属性，` +
        `登录${loginRendered.length}字节、游戏${gameRendered.length}字节SSR输出，` +
        '0条运行时警告'
    );
}

main().catch((error) => {
    console.error(error && error.stack ? error.stack : error);
    process.exit(1);
});
