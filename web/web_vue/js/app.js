/**
 * Vue游戏客户端 - iframe模式 (显示原始HTML)
 */
const { createApp } = Vue;
const markClientRaw = typeof Vue.markRaw === 'function'
    ? Vue.markRaw
    : value => value;

// SHA-256 哈希函数（支持安全和非安全上下文）
async function sha256(message) {
    // 优先使用 SubtleCrypto API (更快的原生实现)
    if (window.crypto && window.crypto.subtle) {
        try {
            const encoder = new TextEncoder();
            const data = encoder.encode(message);
            const hashBuffer = await crypto.subtle.digest('SHA-256', data);
            const hashArray = Array.from(new Uint8Array(hashBuffer));
            return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
        } catch (e) {
            // Fall through to JS implementation
        }
    }

    // Fallback: 简单的 JS SHA-256 实现（用于非安全上下文如 HTTP）
    return sha256Fallback(message);
}

// SHA-256 fallback 纯 JS 实现
function sha256Fallback(str) {
    const K = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ae, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ];

    function rightRotate(n, x) {
        return ((x >>> n) | (x << (32 - n))) >>> 0;
    }

    // 转换字符串为字节数组
    const msgBuffer = new TextEncoder().encode(str);
    const msgLen = msgBuffer.length;

    // 计算填充后的长度: 必须是64字节的倍数
    // 1字节0x80 + (n字节0填充) + 8字节长度
    const lenInBits = msgLen * 8;
    // 找到需要填充的位置: (msgLen + 1 + 8) <= 64的倍数 - 8
    const paddingLen = (64 - ((msgLen + 1 + 8) % 64)) % 64;
    const totalLen = msgLen + 1 + paddingLen + 8;

    // 创建完整消息缓冲区
    const buffer = new Uint8Array(totalLen);
    buffer.set(msgBuffer, 0);
    buffer[msgLen] = 0x80;  // 添加1位后跟7个0

    // 添加64位大端序长度到最后8字节
    for (let i = 0; i < 8; i++) {
        buffer[totalLen - 8 + i] = (lenInBits >>> (56 - i * 8)) & 0xff;
    }

    // 初始化哈希值
    let h0 = 0x6a09e667, h1 = 0xbb67ae85, h2 = 0x3c6ef372, h3 = 0xa54ff53a;
    let h4 = 0x510e527f, h5 = 0x9b05688c, h6 = 0x1f83d9ab, h7 = 0x5be0cd19;

    // 处理消息 (64字节/16个32位字 为一块)
    const dataView = new DataView(buffer.buffer);

    for (let i = 0; i < totalLen; i += 64) {
        // 读取16个32位字(大端序)
        const w = new Uint32Array(64);
        for (let j = 0; j < 16; j++) {
            w[j] = dataView.getUint32(i + j * 4, false);
        }
        for (let j = 16; j < 64; j++) {
            const s0 = rightRotate(7, w[j - 15]) ^ rightRotate(18, w[j - 15]) ^ (w[j - 15] >>> 3);
            const s1 = rightRotate(17, w[j - 2]) ^ rightRotate(19, w[j - 2]) ^ (w[j - 2] >>> 10);
            w[j] = (w[j - 16] + s0 + w[j - 7] + s1) >>> 0;
        }

        let a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;
        for (let j = 0; j < 64; j++) {
            const S1 = rightRotate(6, e) ^ rightRotate(11, e) ^ rightRotate(25, e);
            const ch = (e & f) ^ (~e & g);
            const temp1 = (h + S1 + ch + K[j] + w[j]) >>> 0;
            const S0 = rightRotate(2, a) ^ rightRotate(13, a) ^ rightRotate(22, a);
            const maj = (a & b) ^ (a & c) ^ (b & c);
            const temp2 = (S0 + maj) >>> 0;
            h = g; g = f; f = e; e = (d + temp1) >>> 0;
            d = c; c = b; b = a; a = (temp1 + temp2) >>> 0;
        }
        h0 = (h0 + a) >>> 0; h1 = (h1 + b) >>> 0; h2 = (h2 + c) >>> 0; h3 = (h3 + d) >>> 0;
        h4 = (h4 + e) >>> 0; h5 = (h5 + f) >>> 0; h6 = (h6 + g) >>> 0; h7 = (h7 + h) >>> 0;
    }

    // 转换为十六进制
    const hex = (n) => n.toString(16).padStart(8, '0');
    return hex(h0) + hex(h1) + hex(h2) + hex(h3) + hex(h4) + hex(h5) + hex(h6) + hex(h7);
}

/**
 * 生成一段很小的本地 WAV 音效精灵。避免引入远程音频资源，同时让
 * Howler 统一处理手机浏览器解锁、并发播放和静音状态。
 */
function createGameSoundSpriteDataUri() {
    const sampleRate = 16000;
    const totalMs = 2700;
    const samples = new Float32Array(Math.ceil(sampleRate * totalMs / 1000));
    const notes = [
        // 点击确认
        { start: 0, duration: 110, frequency: 660, volume: 0.18 },
        // 任务完成
        { start: 190, duration: 170, frequency: 523.25, volume: 0.2 },
        { start: 370, duration: 190, frequency: 783.99, volume: 0.2 },
        // 升级/突破
        { start: 690, duration: 180, frequency: 440, volume: 0.2 },
        { start: 850, duration: 180, frequency: 659.25, volume: 0.21 },
        { start: 1010, duration: 220, frequency: 880, volume: 0.18 },
        // 稀有掉落
        { start: 1290, duration: 260, frequency: 987.77, volume: 0.16 },
        { start: 1480, duration: 270, frequency: 1318.51, volume: 0.17 },
        { start: 1690, duration: 250, frequency: 1567.98, volume: 0.14 },
        // 战斗胜利
        { start: 1990, duration: 250, frequency: 392, volume: 0.19 },
        { start: 2180, duration: 250, frequency: 523.25, volume: 0.19 },
        { start: 2370, duration: 280, frequency: 783.99, volume: 0.18 }
    ];

    for (const note of notes) {
        const startSample = Math.floor(note.start * sampleRate / 1000);
        const sampleCount = Math.floor(note.duration * sampleRate / 1000);
        for (let offset = 0; offset < sampleCount; offset++) {
            const index = startSample + offset;
            if (index >= samples.length) break;
            const progress = offset / Math.max(1, sampleCount - 1);
            const attack = Math.min(1, progress / 0.08);
            const release = Math.min(1, (1 - progress) / 0.28);
            const envelope = attack * release;
            const time = offset / sampleRate;
            const fundamental = Math.sin(2 * Math.PI * note.frequency * time);
            const harmonic = Math.sin(4 * Math.PI * note.frequency * time) * 0.2;
            samples[index] += (fundamental + harmonic) * note.volume * envelope;
        }
    }

    const wav = new ArrayBuffer(44 + samples.length * 2);
    const view = new DataView(wav);
    const writeAscii = (offset, value) => {
        for (let i = 0; i < value.length; i++) {
            view.setUint8(offset + i, value.charCodeAt(i));
        }
    };
    writeAscii(0, 'RIFF');
    view.setUint32(4, 36 + samples.length * 2, true);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    view.setUint32(16, 16, true);
    view.setUint16(20, 1, true);
    view.setUint16(22, 1, true);
    view.setUint32(24, sampleRate, true);
    view.setUint32(28, sampleRate * 2, true);
    view.setUint16(32, 2, true);
    view.setUint16(34, 16, true);
    writeAscii(36, 'data');
    view.setUint32(40, samples.length * 2, true);
    for (let i = 0; i < samples.length; i++) {
        const value = Math.max(-1, Math.min(1, samples[i]));
        view.setInt16(44 + i * 2, Math.round(value * 32767), true);
    }

    const bytes = new Uint8Array(wav);
    let binary = '';
    const chunkSize = 0x8000;
    for (let offset = 0; offset < bytes.length; offset += chunkSize) {
        binary += String.fromCharCode(...bytes.subarray(offset, offset + chunkSize));
    }
    return 'data:audio/wav;base64,' + btoa(binary);
}

createApp({
    data() {
        return {
            showLogin: true,
            headerMenuOpen: false,
            showRegister: false,
            showCharacterSelect: false,
            characterSelectCanCancel: false,
            characterCreateOpen: false,
            characterLoading: false,
            characterCreating: false,
            characterError: '',
            accountToken: '',
            accountId: '',
            currentCharacterId: '',
            // 跨浏览器直达书签使用URL fragment里的独立随机凭证。它只
            // 授权一个指定人物，不暴露账号密码，也不能打开其他人物。
            characterBookmarkToken: '',
            preselectedUserid: '',
            preselectedCharacterId: '',
            // 每次选角/退出都会递增。旧人物尚未返回的挂机与轮询响应
            // 只能完成自己的网络请求，不能再覆盖新人物的会话和界面。
            characterSessionEpoch: 0,
            accountCharacters: [],
            accountCharacterLimit: 10,
            accountSharedRechargeBalance: 0,
            accountSharedRechargeAvailable: true,
			illusionEntitled: false,
			illusionRealmStatus: {
				ok: false,
				illusion_id: 'S1',
				display_name: '新月幻境·S1',
				phase: 'disabled',
				phase_name: '不可用',
				creation_open: false,
				entitlement_open: false,
				entitlement_cost_suiyu: 0
			},
            wuxiangUnlocked: false,
            taijiUnlocked: false,
            characterForm: {
				realm_type: 'eternal',
                race_id: '',
                profession_id: '',
                name_cn: '',
                sex: 'male',
                avatar_id: ''
            },
            characterProfileOpen: false,
            characterProfileBusy: false,
            characterProfileError: '',
            characterProfileDismissedFor: '',
            characterProfileForm: {
                name_cn: '',
                sex: 'male',
                avatar_id: '',
                race_id: '',
                profession_id: '',
                needs_name: false,
                needs_sex: false,
                needs_avatar: false
            },
            professionOptions: [
                { race_id: 'human', profession_id: 'jianxian', name: '剑仙', race: '人类', icon: '⚔️', desc: '重甲长剑，正面强攻' },
                { race_id: 'human', profession_id: 'yushi', name: '羽士', race: '人类', icon: '🌩️', desc: '元素法术，远程爆发' },
                { race_id: 'human', profession_id: 'zhuxian', name: '诛仙', race: '人类', icon: '🗡️', desc: '灵动剑术，迅捷连击' },
                { race_id: 'monst', profession_id: 'kuangyao', name: '狂妖', race: '妖魔', icon: '🩸', desc: '狂暴近战，持续撕裂' },
                { race_id: 'monst', profession_id: 'wuyao', name: '巫妖', race: '妖魔', icon: '☠️', desc: '毒术诅咒，法系压制' },
                { race_id: 'monst', profession_id: 'yinggui', name: '影鬼', race: '妖魔', icon: '🌑', desc: '潜影刺杀，高速闪避' },
                { race_id: 'third', profession_id: 'fangshi', name: '方士', race: '中立', icon: '🐯', desc: '三灵召唤，攻守治疗' },
                { race_id: 'third', profession_id: 'zhenyue', name: '镇越', race: '中立', icon: '🛡️', desc: '团队坦克，守御承伤' },
                { race_id: 'third', profession_id: 'tianxiang', name: '天象', race: '中立', icon: '🌠', desc: '星痕法术，元素爆发' },
                { race_id: 'third', profession_id: 'lingyi', name: '灵医', race: '中立', icon: '🌿', desc: '群体治疗，净化复生' },
                { race_id: 'third', profession_id: 'wuxiang', name: '无相', race: '中立', icon: '🔆', desc: '【隐藏】全职业补位；10职业均达120级，或共享账号累计捐赠3000元解锁' },
                { race_id: 'third', profession_id: 'taiji', name: '太极', race: '中立', icon: '☯️', desc: '【最高隐藏】生死轮转；10职+无相均达200级，或共享账号累计捐赠10000元解锁' }
            ],
            isLoggingIn: false,
            isRegistering: false,
            loginPasswordVisible: false,
            registerPasswordVisible: false,
            loginError: '',
            registerError: '',
            registerSuccess: false,
            registerSuccessAccount: '',
            registerReturnTimer: null,
            registerTouched: {
                userid: false,
                password: false,
                passwordConfirm: false,
                captcha: false,
                referral: false
            },
            loginForm: {
                partition: '',
                userid: '',
                password: ''
            },
            registerForm: {
                partition: '',
                userid: '',
                password: '',
                passwordConfirm: '',
                captcha: '',
                referral: ''
            },
            captchaCode: '',
            partitions: [],  // 将从API动态加载
            partitionsLoading: true,
            txd: '',
            apiBase: '',
            gameFrameUrl: '',
            frameLoading: true,
            showCommandInput: false,
            commandInput: '',
            showChatInput: false,
            chatInput: '',
            showChatRoom: false,  // 是否显示聊天室视图
            chatMessages: [],  // 聊天消息列表
            chatChannel: 'pub_channel',  // 当前聊天频道
            chatPollingInterval: null,  // 聊天轮询定时器
            theme: 'classic',  // classic or dark，默认经典模式
            fontSize: 'small',  // 游戏内容字号，默认使用紧凑的小字号
            playerStats: null,  // 玩家状态信息
            playerAvatarFailed: false,  // 当前头像加载失败时显示文字回退
            showEquipmentPanel: false,
            equipmentPanelLoading: false,
            equipmentPanelError: '',
            equipmentPanel: null,
            equipmentSelectedSlot: 'armor_head',
            equipmentActionBusy: '',
            statsInterval: null,  // 状态更新定时器
            autofightInterval: null,  // 挂机画面只读同步定时器
            autofightTickInFlight: false,  // 防止慢请求造成画面同步重叠
            autofightViewSequence: 0,  // 服务端挂机画面版本，防止重复渲染
            autofightViewGeneration: '',  // 服务端重启后允许序号从头同步
            lastCommand: 'look',  // 上一次执行的命令，默认是look
            pendingRequests: {},  // 正在进行的异步请求
            useAsyncMode: false,  // 是否使用异步模式（同步更快，无轮询开销）
            // JSON模式 (vue-ui-3: 无iframe，Vue直接渲染)
            useJsonMode: true,  // 使用JSON模式代替iframe
            htmlMode: false,  // HTML模式：按钮使用href链接（兼容自动浏览器）
            mudLines: [],  // MUD输出行数组
            mudLoading: false,  // MUD加载中状态
            smoothOutputLoading: false,  // 列表页保留旧内容以便AutoAnimate平滑过渡
            slowLoadingTip: false,  // 慢速加载提示（超过3秒显示）
            loadingTimer: null,  // 加载计时器
            // 战斗系统
            isInBattle: false,  // 是否处于战斗状态
            battleMiniMode: true,  // 迷你模式：只显示HP条
            battleFullscreen: false,  // 全屏模式：遮住整个页面
            battleDockCollapsed: false,  // 收起为屏幕边缘的小按钮，不遮挡正文
            headerCollapsed: false,  // 折叠头部状态栏
            battleShowLog: false,  // 显示战斗日志
            battleLog: [],  // 战斗日志条目
            battleAnimations: [],  // 当前显示的战斗动画
            battleEnemy: null,  // 当前敌人信息 {name, hp, hpMax, level, profe, race, attackLow, attackHigh, defend}
            battleEnemyFull: null,  // 敌人完整状态（从API获取）
            battlePlayerFull: null,  // 玩家完整状态（从API获取）
            battleAoeReport: null,  // 最近一次服务端群攻战果（最后目标死亡后保留10秒）
            battleAoeReportTimer: null,
            battlePet: null,  // 当前协战宠物的轻量陪伴状态
            // 战斗数值跳动反馈：'up' / 'down' / ''，600ms 后自动清空
            playerHpFlash: '',
            playerManaFlash: '',
            enemyHpFlash: '',
            _playerHpFlashTimer: null,
            _playerManaFlashTimer: null,
            _enemyHpFlashTimer: null,
            petAssistEffect: null,  // 最近一次宠物协战视觉事件
            petAssistEffectTimer: null,
            lastPetAssistEventId: '',  // 服务端事件ID去重，防止每秒轮询重复播放
            petAssistEventHistory: {},  // 跨人物切换短期去重，避免旧事件重新入场
            petLevelUpEffect: null,  // 同一只随行宠物等级提高时的合并成长提示
            petLevelUpEffectTimer: null,
            battleStatusInterval: null,  // 战斗状态轮询定时器
            battleStatusLoading: false,  // 防止挂机刷新和战斗轮询请求重叠
            skillAnimations: [],  // 技能动画列表
            roomSkillEventHistory: {},  // 服务端同房施法事件ID去重
            combatEffectsEnabled: localStorage.getItem('battle_effects_enabled') !== '0',
            soundEffectsEnabled: localStorage.getItem('game_sound_enabled') === '1',
            soundPlayer: null,
            soundLastPlayedAt: {},
            confettiInstance: null,
            confettiCanvas: null,
            confettiShapeCache: {},
            effectLastTriggeredAt: {},
            effectSignatures: {},
            outputAutoAnimateController: null,
            toastAutoAnimateController: null,
            completionAutoAnimateController: null,
            autoAnimateReadyHandler: null,
            outputAutoAnimateTimer: null,
            uiTour: null,
            uiTourRestoreQuickActions: null,
            // 招式系统
            showPerformsList: false,  // 显示招式列表
            performsData: null,  // 招式数据
            performsLoading: false,  // 招式加载中
            // 快捷菜单
            quickActionsCollapsed: true,  // 更多功能默认收起，保留五项高频导航
            // 邀请系统
            refCode: '',  // 推荐人邀请码（从URL参数ref获取）
            inviteModalOpen: false,  // 显示邀请弹窗
            inviteLink: '',  // 邀请链接
            inviteCode: '',  // 邀请码
            qrCodeUrl: '',  // 二维码URL
            // 新手任务完成弹窗
            activeNewbieCompletion: null,
            newbieCompletionQueue: [],
            // 全局轻提示
            uiToast: null,
            uiToastTimer: null,
            // 组队邀请由状态轮询送达，兼容没有持续socket输出的网页连接
            teamInvite: null,
            teamInviteBusy: false,
            // 每日限时玩法在集结期只弹出一次；服务端状态仍可从“更多”随时进入。
            timedEventInvite: null,
            timedEventInviteBusy: false,
            // 语言选择
            selectedLanguage: localStorage.getItem('userLanguage') || 'chinese_simplified',  // 当前选择的语言
            compactGameNumbers: localStorage.getItem('compact_game_numbers') !== '0',
            isInitializing: true  // 初始化标志，防止初始化时触发changeLanguage
        };
    },

    watch: {
        // 监听 mudLines 变化，更新后重新翻译并滚动到顶部
        mudLines() {
            this.$nextTick(() => {
                this.reapplyTranslation();
                // 每次更新后滚动到顶部
                const container = document.querySelector('.mud-output-container');
                if (container) {
                    container.scrollTop = 0;
                    // 根据行数动态调整高度
                    this.adjustContainerHeight();
                }
            });
        },
        // 战斗数值跳动反馈：HP/MP 变化时短暂染色 + 触发扣血红闪
        'battlePlayerFull.hp'(newVal, oldVal) { this.flashBattleStat('playerHp', newVal, oldVal); },
        'playerStats.hp'(newVal, oldVal) { this.flashBattleStat('playerHp', newVal, oldVal); },
        'battlePlayerFull.mana'(newVal, oldVal) { this.flashBattleStat('playerMana', newVal, oldVal); },
        'playerStats.mana'(newVal, oldVal) { this.flashBattleStat('playerMana', newVal, oldVal); },
        'battleEnemy.hp'(newVal, oldVal) { this.flashBattleStat('enemyHp', newVal, oldVal); }
    },

    methods: {
        getStatPercent(current, maximum) {
            const value = Number(current);
            const max = Number(maximum);
            if (!Number.isFinite(value) || !Number.isFinite(max) || max <= 0) {
                return 0;
            }
            return Math.min(100, Math.max(0, value / max * 100));
        },

        formatGameNumber(value, options = {}) {
            const settings = {
                ...options,
                compact: this.compactGameNumbers
            };
            if (typeof GameNumberFormat !== 'undefined') {
                return GameNumberFormat.formatNumber(value, settings);
            }
            const number = Number(value);
            return Number.isFinite(number) ? number.toLocaleString('zh-CN') : '0';
        },

        formatExactGameNumber(value) {
            if (typeof GameNumberFormat !== 'undefined') {
                return GameNumberFormat.formatExactNumber(value);
            }
            const number = Number(value);
            return Number.isFinite(number) ? number.toLocaleString('zh-CN') : '0';
        },

        renderGameText(value, allowHtml = false) {
            if (value === null || value === undefined) return '';
            if (typeof GameNumberFormat !== 'undefined') {
                return GameNumberFormat.formatText(value, {
                    compact: this.compactGameNumbers,
                    allowHtml: allowHtml
                });
            }
            const text = String(value);
            if (allowHtml) return text;
            return text
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;')
                .replace(/'/g, '&#39;');
        },

        toggleCompactGameNumbers() {
            this.compactGameNumbers = !this.compactGameNumbers;
            if (typeof GameNumberFormat !== 'undefined') {
                GameNumberFormat.setCompactEnabled(this.compactGameNumbers);
            } else {
                localStorage.setItem('compact_game_numbers', this.compactGameNumbers ? '1' : '0');
            }
            if (!this.useJsonMode) this.refreshFrame();
        },

        // 保留旧方法名，历史组件也统一走 GameNumberFormat。
        formatCompactNumber(value) {
            return this.formatGameNumber(value);
        },

        // 迷你战斗小窗限制小数位，单位与全局规则保持一致。
        formatMiniNumber(value) {
            return this.formatGameNumber(value, { maxFractionDigits: 0 });
        },

        // HP/MP 变化时短暂染色，扣血/扣蓝触发 .damage-taken 红闪。
        // key 为 'playerHp' / 'playerMana' / 'enemyHp'，对应 data 字段 + 定时器。
        flashBattleStat(key, newVal, oldVal) {
            const next = Number(newVal);
            const prev = Number(oldVal);
            if (!Number.isFinite(next) || !Number.isFinite(prev)) return;
            if (next === prev) return;
            const stateField = key + 'Flash';
            const timerField = '_' + key + 'FlashTimer';
            this[stateField] = next < prev ? 'down' : 'up';
            if (this[timerField]) clearTimeout(this[timerField]);
            this[timerField] = setTimeout(() => {
                this[stateField] = '';
            }, 650);
        },

        formatAutofightTime(value) {
            const seconds = Math.max(0, Number(value) || 0);
            const hours = Math.floor(seconds / 3600);
            const minutes = Math.floor((seconds % 3600) / 60);
            if (hours > 0) {
                return `${hours}时${minutes}分`;
            }
            return `${minutes}分`;
        },

        showUiToast(message, type = 'info', action = null) {
            if (!message) {
                return;
            }
            if (this.uiToastTimer) {
                clearTimeout(this.uiToastTimer);
            }
            this.uiToast = {
                message,
                type,
                actionLabel: action?.label || '',
                actionCommand: action?.command || '',
                actionCallback: typeof action?.callback === 'function'
                    ? action.callback
                    : null
            };
            this.uiToastTimer = setTimeout(() => {
                this.uiToast = null;
                this.uiToastTimer = null;
            }, action ? 9000 : 4500);
        },

        runUiToastAction() {
            const command = this.uiToast?.actionCommand || '';
            const callback = this.uiToast?.actionCallback;
            this.clearUiToast();
            if (typeof callback === 'function') {
                callback();
            } else if (command) {
                this.sendQuickCommand(command);
            }
        },

        clearUiToast() {
            if (this.uiToastTimer) {
                clearTimeout(this.uiToastTimer);
                this.uiToastTimer = null;
            }
            this.uiToast = null;
        },

        clearPetLevelUpEffect() {
            if (this.petLevelUpEffectTimer) {
                clearTimeout(this.petLevelUpEffectTimer);
                this.petLevelUpEffectTimer = null;
            }
            this.petLevelUpEffect = null;
        },

        handlePetLevelChange(previousPet, currentPet) {
            if (!previousPet || !currentPet ||
                Number(previousPet.active || 0) !== 1 ||
                Number(currentPet.active || 0) !== 1 ||
                String(previousPet.pet_id || '') === '' ||
                String(previousPet.pet_id || '') !== String(currentPet.pet_id || '')) {
                return false;
            }
            const fromLevel = Number(previousPet.level);
            const toLevel = Number(currentPet.level);
            if (!Number.isFinite(fromLevel) || !Number.isFinite(toLevel) ||
                toLevel <= fromLevel) {
                return false;
            }
            const name = String(currentPet.name || '灵宠');
            const icon = String(currentPet.icon || '🐾');
            const personal = String(currentPet.system || '') === 'personal';
            const systemName = personal ? '本命灵伴' : '灵宠';
            const systemCommand = personal ? 'spirit_companion' : 'pet';
            const levelsGained = toLevel - fromLevel;
            const message = `${name} ${fromLevel}级 → ${toLevel}级${levelsGained > 1 ? `，连升${levelsGained}级` : ''}`;
            const signature = `pet:${currentPet.pet_id}:${fromLevel}->${toLevel}`;
            this.triggerGameFeedback('petLevel', signature, 800);
            this.clearPetLevelUpEffect();
            if (!this.combatEffectsEnabled || this.prefersReducedMotion()) {
                this.showUiToast(`${systemName}成长：${message}`, 'info', {
                    label: personal ? '查看本命灵伴' : '查看万灵谱',
                    command: systemCommand
                });
                return true;
            }
            this.petLevelUpEffect = {
                id: signature,
                name,
                icon,
                fromLevel,
                toLevel,
                levelsGained,
                command: personal
                    ? `spirit_companion detail ${currentPet.pet_id}`
                    : (currentPet.species
                        ? `pet detail ${currentPet.species}`
                        : systemCommand)
            };
            this.petLevelUpEffectTimer = setTimeout(() => {
                this.petLevelUpEffect = null;
                this.petLevelUpEffectTimer = null;
            }, 3800);
            return true;
        },

        openPetLevelUpEffect() {
            const command = this.petLevelUpEffect?.command || 'pet';
            this.clearPetLevelUpEffect();
            this.sendQuickCommand(command);
        },

        prefersReducedMotion() {
            return typeof window.matchMedia === 'function' &&
                window.matchMedia('(prefers-reduced-motion: reduce)').matches;
        },

        getMudLineText(line) {
            if (!line || !Array.isArray(line.segments)) {
                return line?.type || '';
            }
            return line.segments.map(segment => {
                if (segment.type === 'text' && Array.isArray(segment.parts)) {
                    return segment.parts.map(part => part.content || '').join('');
                }
                return segment.label || segment.alt || segment.cmd || '';
            }).join('').trim();
        },

        getMudLineKey(line, index) {
            const segmentIdentity = Array.isArray(line?.segments)
                ? line.segments.map(segment =>
                    `${segment.type || ''}:${segment.cmd || ''}:${segment.name || ''}`
                ).join('|')
                : '';
            return `${index}:${line?.type || ''}:${this.getMudLineText(line).slice(0, 120)}:${segmentIdentity}`;
        },

        shouldAnimateMudOutputCommand(command) {
            const value = String(command || '').trim().toLowerCase();
            return /^(inventory|mytasks|myskills|storage|store|cangku|newbie_guide|profession_assistant|pet|pet_hunt|pet_duel|daily|daily_cultivation|wanling_rift)(?:\s|$)/.test(value);
        },

        initializeAutoAnimate() {
            const autoAnimate = window.XiandAutoAnimate;
            if (typeof autoAnimate !== 'function' || !this.$refs) {
                return;
            }
            const bindController = (current, element, options, initiallyEnabled) => {
                if (!element) return current;
                if (current?.parent === element) {
                    return current;
                }
                current?.destroy?.();
                const controller = markClientRaw(autoAnimate(element, options));
                if (!initiallyEnabled) controller.disable();
                return controller;
            };

            this.outputAutoAnimateController = bindController(
                this.outputAutoAnimateController,
                this.$refs.mudLinesList,
                { duration: 180, easing: 'ease-out' },
                false
            );
            this.toastAutoAnimateController = bindController(
                this.toastAutoAnimateController,
                this.$refs.uiToastStage,
                { duration: 170, easing: 'ease-out' },
                this.combatEffectsEnabled
            );
            this.completionAutoAnimateController = bindController(
                this.completionAutoAnimateController,
                this.$refs.newbieCompletionStage,
                { duration: 220, easing: 'ease-in-out' },
                this.combatEffectsEnabled
            );
        },

        scheduleAutoAnimateInitialization() {
            if (typeof this.$nextTick === 'function') {
                this.$nextTick(() => this.initializeAutoAnimate());
            } else {
                setTimeout(() => this.initializeAutoAnimate(), 0);
            }
        },

        prepareMudOutputAnimation(command) {
            const controller = this.outputAutoAnimateController;
            if (!controller) return;
            if (this.outputAutoAnimateTimer) {
                clearTimeout(this.outputAutoAnimateTimer);
                this.outputAutoAnimateTimer = null;
            }
            if (!this.combatEffectsEnabled ||
                !this.shouldAnimateMudOutputCommand(command)) {
                controller.disable();
                return;
            }
            controller.enable();
            this.outputAutoAnimateTimer = setTimeout(() => {
                controller.disable();
                this.outputAutoAnimateTimer = null;
            }, 650);
        },

        destroyAutoAnimate() {
            for (const controller of [
                this.outputAutoAnimateController,
                this.toastAutoAnimateController,
                this.completionAutoAnimateController
            ]) {
                controller?.destroy?.();
            }
            this.outputAutoAnimateController = null;
            this.toastAutoAnimateController = null;
            this.completionAutoAnimateController = null;
            if (this.outputAutoAnimateTimer) {
                clearTimeout(this.outputAutoAnimateTimer);
                this.outputAutoAnimateTimer = null;
            }
        },

        initializeSoundPlayer() {
            if (this.soundPlayer || typeof window.Howl !== 'function') {
                return this.soundPlayer;
            }
            try {
                this.soundPlayer = markClientRaw(new window.Howl({
                    src: [createGameSoundSpriteDataUri()],
                    format: ['wav'],
                    preload: true,
                    volume: 0.72,
                    sprite: {
                        ui: [0, 140],
                        quest: [180, 430],
                        level: [680, 590],
                        rare: [1280, 670],
                        victory: [1980, 680]
                    }
                }));
            } catch (error) {
                console.warn('[游戏音效] 初始化失败:', error);
                this.soundPlayer = null;
            }
            return this.soundPlayer;
        },

        playGameSound(name, minInterval = 250) {
            if (!this.soundEffectsEnabled) return false;
            const now = Date.now();
            const previous = Number(this.soundLastPlayedAt[name] || 0);
            if (now - previous < minInterval) return false;
            const player = this.initializeSoundPlayer();
            if (!player) return false;
            try {
                player.play(name);
                this.soundLastPlayedAt[name] = now;
                return true;
            } catch (error) {
                console.warn('[游戏音效] 播放失败:', error);
                return false;
            }
        },

        toggleSoundEffects() {
            this.soundEffectsEnabled = !this.soundEffectsEnabled;
            localStorage.setItem(
                'game_sound_enabled',
                this.soundEffectsEnabled ? '1' : '0'
            );
            if (this.soundEffectsEnabled) {
                this.playGameSound('ui', 0);
                this.showUiToast('游戏音效已开启，可随时在菜单中关闭', 'info');
            } else {
                this.soundPlayer?.stop?.();
                this.showUiToast('游戏音效已关闭', 'info');
            }
        },

        ensureConfettiInstance() {
            if (this.confettiInstance || typeof window.confetti !== 'function' ||
                typeof document.createElement !== 'function') {
                return this.confettiInstance;
            }
            try {
                const canvas = document.createElement('canvas');
                canvas.className = 'game-celebration-canvas';
                canvas.setAttribute('aria-hidden', 'true');
                document.body.appendChild(canvas);
                this.confettiCanvas = canvas;
                this.confettiInstance = markClientRaw(window.confetti.create(canvas, {
                    resize: true,
                    useWorker: true,
                    disableForReducedMotion: true
                }));
            } catch (error) {
                console.warn('[庆典特效] Canvas初始化失败，使用兼容模式:', error);
                this.confettiInstance = markClientRaw(options => window.confetti({
                    ...options,
                    disableForReducedMotion: true
                }));
            }
            return this.confettiInstance;
        },

        getCelebrationPalette() {
            const profession = String(this.playerStats?.profe || '');
            if (profession.includes('方士')) {
                return ['#60e6d2', '#78a8ff', '#c991ff', '#f4e8ff'];
            }
            if (profession.includes('镇越')) {
                return ['#f1c66d', '#d99045', '#8f6a45', '#fff1b5'];
            }
            if (profession.includes('天象')) {
                return ['#80b7ff', '#9b8cff', '#67d8ff', '#f0edff'];
            }
            if (profession.includes('灵医')) {
                return ['#70e6b3', '#a7f3d0', '#d6b56c', '#effff7'];
            }
            return ['#f4c95d', '#ef8354', '#6fb1ff', '#fff4cf'];
        },

        getCelebrationShapes(kind) {
            if (this.confettiShapeCache[kind]) {
                return this.confettiShapeCache[kind];
            }
            const shapes = [];
            try {
                if (kind === 'rare' && typeof window.confetti?.shapeFromText === 'function') {
                    const profession = String(this.playerStats?.profe || '');
                    const glyph = profession.includes('方士')
                        ? '符'
                        : (profession.includes('镇越') ? '岳' : '✦');
                    shapes.push(window.confetti.shapeFromText({ text: glyph, scalar: 1.4 }));
                    shapes.push('star');
                } else if (kind === 'level' || kind === 'petLevel' ||
                           kind === 'tutorialComplete') {
                    shapes.push('star', 'circle');
                }
            } catch (error) {
                console.warn('[庆典特效] 自定义粒子不可用:', error);
            }
            this.confettiShapeCache[kind] = shapes;
            return shapes;
        },

        shouldTriggerGameFeedback(kind, signature = '', minInterval = 0) {
            const now = Date.now();
            const lastTriggered = Number(this.effectLastTriggeredAt[kind] || 0);
            if (now - lastTriggered < minInterval) return false;
            const cacheKey = signature ? `${kind}:${signature.slice(0, 160)}` : '';
            if (cacheKey && now - Number(this.effectSignatures[cacheKey] || 0) < 90000) {
                return false;
            }
            this.effectLastTriggeredAt[kind] = now;
            if (cacheKey) this.effectSignatures[cacheKey] = now;
            for (const [key, timestamp] of Object.entries(this.effectSignatures)) {
                if (now - Number(timestamp) > 120000) delete this.effectSignatures[key];
            }
            return true;
        },

        triggerGameFeedback(kind, signature = '', requestedInterval = null) {
            const intervals = {
                quest: 1500,
                tutorialComplete: 3000,
                level: 3000,
                petLevel: 800,
                rare: 1500,
                victory: 10000
            };
            const minInterval = requestedInterval === null
                ? (intervals[kind] || 0)
                : requestedInterval;
            if (!this.shouldTriggerGameFeedback(kind, signature, minInterval)) {
                return false;
            }

            const soundName = kind === 'tutorialComplete'
                ? 'quest'
                : (kind === 'petLevel' ? 'level' : kind);
            this.playGameSound(soundName, minInterval);
            if (!this.combatEffectsEnabled || this.prefersReducedMotion()) {
                return true;
            }
            const fire = this.ensureConfettiInstance();
            if (!fire) return true;

            const colors = this.getCelebrationPalette();
            const shapes = this.getCelebrationShapes(kind);
            const base = {
                colors,
                origin: { x: 0.5, y: 0.66 },
                disableForReducedMotion: true,
                ...(shapes.length ? { shapes } : {})
            };
            try {
                if (kind === 'rare') {
                    fire({ ...base, particleCount: 72, spread: 82, startVelocity: 42, scalar: 1.05 });
                    fire({ ...base, particleCount: 45, angle: 60, spread: 55, origin: { x: 0.08, y: 0.72 } });
                    fire({ ...base, particleCount: 45, angle: 120, spread: 55, origin: { x: 0.92, y: 0.72 } });
                } else if (kind === 'level' || kind === 'petLevel' ||
                           kind === 'tutorialComplete') {
                    fire({ ...base, particleCount: 92, spread: 100, startVelocity: 38, scalar: 0.95 });
                } else if (kind === 'victory') {
                    fire({ ...base, particleCount: 28, spread: 58, startVelocity: 28, ticks: 130, scalar: 0.72 });
                } else {
                    fire({ ...base, particleCount: 38, spread: 64, startVelocity: 28, ticks: 150, scalar: 0.78 });
                }
            } catch (error) {
                console.warn('[庆典特效] 播放失败:', error);
            }
            return true;
        },

        handleNarrativeEffects(lines) {
            if (!Array.isArray(lines)) return;
            for (const line of lines) {
                const text = this.getMudLineText(line);
                if (!text) continue;
                const rareReward = /(?:获得|拾取|掉落|爆出|发现).{0,24}(?:隐藏技能|大神技能|神级技能|绝世秘籍|稀有技能书|隐藏技能书)/.test(text);
                const questComplete = /(?:(?:恭喜你|你已|成功).{0,12}(?:完成|达成).{0,12}(?:任务|试炼|成就)|(?:任务|试炼).{0,12}(?:已完成|完成[！!]))/.test(text);
                if (rareReward) {
                    this.triggerGameFeedback('rare', text);
                } else if (questComplete) {
                    this.triggerGameFeedback('quest', text);
                }
            }
        },

        promptUiTourOnce() {
            if (localStorage.getItem('ui_tour_completed_v1') === '1' ||
                localStorage.getItem('ui_tour_prompted_v1') === '1') {
                return;
            }
            localStorage.setItem('ui_tour_prompted_v1', '1');
            this.showUiToast('第一次使用新版界面？用一分钟认识人物、任务、技能和挂机入口。', 'info', {
                label: '开始引导',
                callback: () => this.startUiTour()
            });
        },

        startUiTour() {
            this.headerMenuOpen = false;
            const driverFactory = window.driver?.js?.driver;
            if (typeof driverFactory !== 'function') {
                this.showUiToast('界面引导资源尚未就绪，请刷新后重试', 'error');
                return;
            }
            this.stopUiTour();
            this.uiTourRestoreQuickActions = this.quickActionsCollapsed;
            this.quickActionsCollapsed = false;
            localStorage.setItem('quickActionsCollapsed', '0');

            this.$nextTick(() => {
                const professionName = this.playerStats?.profe || '当前职业';
                const candidates = [
                    {
                        element: '[data-tour="player-avatar"]',
                        popover: {
                            title: `${professionName}人物入口`,
                            description: '点击头像可以打开职业助手或人物状态，职业成长外观也会显示在这里。',
                            side: 'bottom', align: 'start'
                        }
                    },
                    {
                        element: '[data-tour="player-stats"]',
                        popover: {
                            title: '生命、法力与精力',
                            description: '挂机前重点检查生命与法力；数值会持续更新，无需手动刷新。',
                            side: 'bottom', align: 'start'
                        }
                    },
                    {
                        element: '[data-tour="level-progress"]',
                        popover: {
                            title: '等级与突破',
                            description: '这里显示升级进度、当前上限以及VIP突破条件。',
                            side: 'bottom', align: 'center'
                        }
                    },
                    {
                        element: '[data-tour="game-output"]',
                        popover: {
                            title: '江湖主界面',
                            description: '地图、NPC、任务和装备操作都会出现在这里；蓝绿色文字按钮可以直接点击。',
                            side: 'top', align: 'center'
                        }
                    },
                    {
                        element: '[data-tour="scene"]',
                        popover: {
                            title: '返回当前场景',
                            description: '走迷路或查看完功能后，点击“场景”即可重新查看当前位置。',
                            side: 'top', align: 'center'
                        }
                    },
                    {
                        element: '[data-tour="inventory"]',
                        popover: {
                            title: '物品与装备',
                            description: '查看背包、穿戴装备、使用药品，以及整理挂机获得的物品。',
                            side: 'top', align: 'center'
                        }
                    },
                    {
                        element: '[data-tour="skills"]',
                        popover: {
                            title: '技能成长',
                            description: '购买技能书后从这里查看并学习；不同职业会显示各自技能路线。',
                            side: 'top', align: 'center'
                        }
                    },
                    {
                        element: '[data-tour="quests"]',
                        popover: {
                            title: '任务追踪',
                            description: '查看当前可接与进行中的任务，并使用任务引导快速前往目标。',
                            side: 'top', align: 'center'
                        }
                    },
                    {
                        element: '[data-tour="autofight"]',
                        popover: {
                            title: '智能挂机',
                            description: '自动寻路、匹配怪物、休息和吃药；首次开启前请先准备红蓝药。',
                            side: 'top', align: 'center'
                        }
                    },
                    {
                        element: '[data-tour="profession-assistant"]',
                        popover: {
                            title: `${professionName}职业助手`,
                            description: '新职业会在这里提供专属成长建议、装备辅助与特色玩法入口。',
                            side: 'bottom', align: 'start'
                        }
                    }
                ];
                const steps = candidates.filter(step => document.querySelector(step.element));
                if (steps.length === 0) {
                    this.restoreUiTourLayout();
                    this.showUiToast('当前页面没有可引导的游戏控件', 'error');
                    return;
                }

                const tour = markClientRaw(driverFactory({
                    steps,
                    showProgress: true,
                    progressText: '第 {{current}} / {{total}} 步',
                    nextBtnText: '下一步',
                    prevBtnText: '上一步',
                    doneBtnText: '完成',
                    allowClose: true,
                    smoothScroll: true,
                    animate: !this.prefersReducedMotion(),
                    stagePadding: 7,
                    stageRadius: 12,
                    popoverClass: 'xiand-driver-popover',
                    onDestroyed: () => {
                        localStorage.setItem('ui_tour_completed_v1', '1');
                        this.uiTour = null;
                        this.restoreUiTourLayout();
                    }
                }));
                this.uiTour = tour;
                this.playGameSound('ui', 0);
                tour.drive();
            });
        },

        restoreUiTourLayout() {
            if (this.uiTourRestoreQuickActions === null) return;
            this.quickActionsCollapsed = this.uiTourRestoreQuickActions;
            localStorage.setItem(
                'quickActionsCollapsed',
                this.quickActionsCollapsed ? '1' : '0'
            );
            this.uiTourRestoreQuickActions = null;
        },

        stopUiTour() {
            const tour = this.uiTour;
            if (tour?.isActive?.()) {
                tour.destroy();
            } else {
                this.uiTour = null;
                this.restoreUiTourLayout();
            }
        },

        async respondTeamInvite(accepted) {
            if (!this.teamInvite || this.teamInviteBusy) {
                return;
            }
            const inviter = this.teamInvite.from;
            this.teamInviteBusy = true;
            try {
                await this.sendJsonCommand(
                    `${accepted ? 'term_ok' : 'term_refuse'} ${inviter}`
                );
            } finally {
                this.teamInvite = null;
                this.teamInviteBusy = false;
                await this.fetchPlayerStats();
            }
        },

        timedEventSeenKey(invite) {
            const character = this.currentCharacterId || this.txd || 'guest';
            return `timed_event_seen:${character}:${invite?.popup_id || ''}`;
        },

        markTimedEventInviteSeen(invite = this.timedEventInvite) {
            if (!invite?.popup_id) return;
            try {
                sessionStorage.setItem(this.timedEventSeenKey(invite), '1');
            } catch (e) {
                // 禁用会话存储的隐私浏览器仍可正常参加，只是不持久记忆关闭状态。
            }
        },

        syncTimedEventInvite(status) {
            if (!status || status.phase !== 'signup' || status.joined ||
                !status.eligible || !status.popup_id) {
                if (!this.timedEventInviteBusy) this.timedEventInvite = null;
                return;
            }
            let seen = false;
            try {
                seen = sessionStorage.getItem(this.timedEventSeenKey(status)) === '1';
            } catch (e) {
                seen = false;
            }
            if (!seen) {
                const isNewInvite = this.timedEventInvite?.popup_id !== status.popup_id;
                this.timedEventInvite = { ...this.timedEventInvite, ...status };
                if (isNewInvite) this.playGameSound('rare', 180);
            }
        },

        formatTimedEventRemaining(seconds) {
            const safeSeconds = Math.max(0, Number(seconds) || 0);
            const minutes = Math.floor(safeSeconds / 60);
            const remainder = Math.floor(safeSeconds % 60);
            return `${String(minutes).padStart(2, '0')}:${String(remainder).padStart(2, '0')}`;
        },

        closeTimedEventInvite() {
            this.markTimedEventInviteSeen();
            this.timedEventInvite = null;
        },

        openTimedEventDetails() {
            this.markTimedEventInviteSeen();
            this.timedEventInvite = null;
            this.sendQuickCommand('timed_event');
        },

        enterTimedEvent() {
            if (!this.timedEventInvite || this.timedEventInviteBusy) return;
            const invite = this.timedEventInvite;
            this.timedEventInviteBusy = true;
            this.markTimedEventInviteSeen(invite);
            this.timedEventInvite = null;
            this.sendQuickCommand(invite.command || `timed_event join ${invite.event_id}`);
            window.setTimeout(() => {
                this.timedEventInviteBusy = false;
                this.fetchPlayerStats();
            }, 800);
        },

        isQuickActionActive(command) {
            return this.lastCommand === command ||
                this.lastCommand.startsWith(command + ' ');
        },

        // 重新应用翻译（用于 mudLines 更新后）
        reapplyTranslation() {
            const savedLang = localStorage.getItem('userLanguage');
            if (savedLang && savedLang !== 'chinese_simplified' && typeof translate !== 'undefined') {
                // 用户选择了非简体中文语言，重新翻译新内容
                translate.execute();
            }
        },

        detectApiBase() {
            const hostname = window.location.hostname;
            const protocol = window.location.protocol;
            // API端口 - 容器启动时会被sed替换为实际端口
            const apiPort = '8888';

            // localhost 始终使用配置的端口
            if (hostname === 'localhost' || hostname === '127.0.0.1') {
                return protocol + '//localhost:' + apiPort;
            }

            // HTTPS 时使用不带端口的地址（由反向代理转发）
            // HTTP 时使用配置的端口
            if (protocol === 'https:') {
                return protocol + '//' + hostname;
            }
            return protocol + '//' + hostname + ':' + apiPort;
        },

        // 生成验证码
        refreshCaptcha() {
            const chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
            let code = '';
            for (let i = 0; i < 4; i++) {
                code += chars.charAt(Math.floor(Math.random() * chars.length));
            }
            this.captchaCode = code;
        },

        // 打开注册页面
        openRegister() {
            this.showLogin = false;
            this.showRegister = true;
            this.registerPasswordVisible = false;
            this.registerError = '';
            this.registerSuccess = false;
            this.registerSuccessAccount = '';
            this.resetRegisterTouched();
        },

        resetRegisterTouched() {
            this.registerTouched = {
                userid: false,
                password: false,
                passwordConfirm: false,
                captcha: false,
                referral: false
            };
        },

        markRegisterFieldTouched(field) {
            if (!Object.prototype.hasOwnProperty.call(this.registerTouched, field)) return;
            this.registerTouched[field] = true;
            if (this.registerError) this.registerError = '';
        },

        registrationFieldError(field) {
            const form = this.registerForm || {};
            const value = String(form[field] || '');

            if (field === 'userid') {
                if (!value) return '请输入账号';
                if (value.length < 2) return '至少输入2个字符';
                if (value.length > 12) return '最多输入12个字符';
                if (!/^[a-zA-Z0-9]+$/.test(value)) return '仅支持英文字母和数字';
                return '';
            }
            if (field === 'password') {
                if (!value) return '请输入密码';
                if (value.length < 2) return '至少输入2个字符';
                if (value.length > 12) return '最多输入12个字符';
                if (!/^[a-zA-Z0-9]+$/.test(value)) return '仅支持英文字母和数字';
                return '';
            }
            if (field === 'passwordConfirm') {
                if (!value) return '请再次输入密码';
                if (value !== String(form.password || '')) return '两次输入的密码不一致';
                return '';
            }
            if (field === 'captcha') {
                if (!value) return '请输入右侧验证码';
                if (value.length !== 4) return '验证码为4个字符';
                if (value.toLowerCase() !== String(this.captchaCode || '').toLowerCase())
                    return '验证码不正确，点击右侧可换一张';
                return '';
            }
            if (field === 'referral') {
                if (!value) return '';
                return this.normalizeReferralCode(value)
                    ? ''
                    : '邀请码格式不正确，请检查或留空';
            }
            return '';
        },

        registrationFieldClass(field) {
            const value = String(this.registerForm?.[field] || '');
            if (!value && !this.registerTouched?.[field]) return '';
            return this.registrationFieldError(field) ? 'field-invalid' : 'field-valid';
        },

        registrationPasswordStrength() {
            const password = String(this.registerForm?.password || '');
            if (!password || this.registrationFieldError('password')) return 0;
            let score = password.length >= 6 ? 1 : 0;
            if (/[a-z]/.test(password) && /[A-Z]/.test(password)) score += 1;
            if (/[a-zA-Z]/.test(password) && /[0-9]/.test(password)) score += 1;
            return Math.max(1, Math.min(3, score));
        },

        registrationPasswordStrengthLabel() {
            return ['未填写', '可用', '良好', '较强'][this.registrationPasswordStrength()];
        },

        registrationFirstError() {
            if (!this.registerForm.partition) return '请选择可注册的分区';
            const fields = ['userid', 'password', 'passwordConfirm', 'referral', 'captcha'];
            for (const field of fields) {
                const error = this.registrationFieldError(field);
                if (error) return error;
            }
            return '';
        },

        normalizeReferralCode(value) {
            const normalized = String(value || '').trim();
            return /^[a-zA-Z0-9]{2,64}$/.test(normalized) ? normalized : '';
        },

        buildReferralLink(value) {
            const code = this.normalizeReferralCode(value);
            if (!code) return '';
            const url = new URL(window.location.href);
            url.search = '';
            url.hash = '';
            url.searchParams.set('register', '1');
            url.searchParams.set('ref', code);
            return url.toString();
        },

        applyReferralLanding(value) {
            const code = this.normalizeReferralCode(value);
            if (!code) return false;
            this.refCode = code;
            this.registerForm.referral = code;
            this.showLogin = false;
            this.showRegister = true;
            return true;
        },

        clearReferralLanding() {
            this.refCode = '';
            this.registerForm.referral = '';
            try {
                localStorage.removeItem('ref_code');
                const url = new URL(window.location.href);
                url.searchParams.delete('ref');
                url.searchParams.delete('register');
                window.history.replaceState({}, '', url.toString());
            } catch (e) {
                // 无痕模式/旧内置浏览器不支持时不影响注册。
            }
        },

        // 关闭注册页面
        closeRegister() {
            if (this.registerReturnTimer) {
                clearTimeout(this.registerReturnTimer);
                this.registerReturnTimer = null;
            }
            this.showRegister = false;
            this.showLogin = true;
            this.registerPasswordVisible = false;
            this.registerSuccess = false;
            this.registerSuccessAccount = '';
            this.registerError = '';
        },

        returnToLoginAfterRegistration() {
            if (this.registerReturnTimer) {
                clearTimeout(this.registerReturnTimer);
                this.registerReturnTimer = null;
            }
            this.showRegister = false;
            this.showLogin = true;
            this.registerSuccess = false;
            this.loginForm.partition = this.registerForm.partition;
            this.loginForm.userid = this.registerForm.userid;
            this.loginForm.password = this.registerForm.password;
        },

        getPartitionSortValue(partition) {
            const configuredSort = Number(partition?.sort);
            if (Number.isFinite(configuredSort)) return configuredSort;
            const match = String(partition?.value || '').match(/(\d+)$/);
            return match ? Number(match[1]) : 0;
        },

        // 无论后端版本如何，都保证新区（最大 sort/区号）排在最前。
        sortPartitionsNewestFirst(partitions) {
            if (!Array.isArray(partitions)) return [];
            return partitions.slice().sort((left, right) => {
                const sortDifference = this.getPartitionSortValue(right) -
                    this.getPartitionSortValue(left);
                if (sortDifference !== 0) return sortDifference;
                return String(right?.value || '').localeCompare(
                    String(left?.value || '')
                );
            });
        },

        applyLoadedPartitions(partitions) {
            this.partitions = this.sortPartitionsNewestFirst(partitions);
            if (this.partitions.length === 0) return;
            const savedPartition = this.loginForm.partition || '';
            const loginPartitions = this.partitions.filter(
                partition => partition.login_open !== 0
            );
            const registrationPartitions = this.partitions.filter(
                partition => partition.registration_open !== 0
            );
            const savedExists = loginPartitions.some(
                partition => partition.value === savedPartition
            );
            const firstLoginPartition = (
                loginPartitions[0] || this.partitions[0]
            ).value;
            const firstRegistrationPartition = (
                registrationPartitions[0] || this.partitions[0]
            ).value;
            this.loginForm.partition = savedExists ? savedPartition :
                firstLoginPartition;
            const registerExists = registrationPartitions.some(
                partition => partition.value === this.registerForm.partition
            );
            if (!registerExists)
                this.registerForm.partition = firstRegistrationPartition;
        },

        // 从API加载分区列表
        async loadPartitions() {
            try {
                const response = await fetch(`${this.apiBase}/api/partitions`);
                if (!response.ok) {
                    console.error('加载分区列表失败:', response.status);
                    // 使用默认分区列表
                    this.applyLoadedPartitions(this.getDefaultPartitions());
                    return;
                }
                const data = await response.json();
                this.applyLoadedPartitions(data.partitions || []);
                console.log('已加载分区列表:', this.partitions);
            } catch (e) {
                console.error('加载分区列表异常:', e);
                // 使用默认分区列表
                this.applyLoadedPartitions(this.getDefaultPartitions());
            } finally {
                this.partitionsLoading = false;
            }
        },

        // 默认分区列表（API失败时使用）
        getDefaultPartitions() {
            return [
                {
                    value: 'xd03', label: '仙道三区', sort: 3,
                    login_open: 1, registration_open: 1
                },
                {
                    value: 'xd02', label: '仙道二区', sort: 2,
                    login_open: 1, registration_open: 1
                },
                {
                    value: 'xd01', label: '仙道一区', sort: 1,
                    login_open: 1, registration_open: 1
                }
            ];
        },

        // 生成游戏iframe URL
        getGameFrameUrl() {
            if (!this.txd) return '';
            return `${this.apiBase}/api/html?txd=${encodeURIComponent(this.txd)}&cmd=look`;
        },

        // 生成传统API链接（HTML模式使用）
        getDirectUrl(cmd) {
            if (!this.txd) return '#';
            return `${this.apiBase}/api/html?txd=${encodeURIComponent(this.txd)}&cmd=${encodeURIComponent(cmd)}`;
        },

        // 普通模式由Vue处理；HTML模式保留真实href供自动浏览器直接导航
        handleMudButtonClick(event, cmd) {
            if (this.htmlMode) {
                return;
            }
            if (event) {
                event.preventDefault();
            }
            this.sendJsonCommand(cmd);
        },

        // 注册功能
        async doRegister() {
            // 前端即时校验只改善体验；后端仍会按相同规则再次校验。
            Object.keys(this.registerTouched).forEach((field) => {
                this.registerTouched[field] = true;
            });
            const validationError = this.registrationFirstError();
            if (validationError) {
                this.registerError = validationError;
                if (this.registrationFieldError('captcha')) {
                    this.registerForm.captcha = '';
                    this.refreshCaptcha();
                }
                return;
            }
            const referralCode = this.registerForm.referral
                ? this.normalizeReferralCode(this.registerForm.referral)
                : '';

            this.isRegistering = true;
            this.registerError = '';
            this.registerSuccess = false;

            try {
                const fullUserid = this.registerForm.partition + this.registerForm.userid;
                // 生成一个随机的session ID作为验证码
                const sessionId = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);

                // 获取challenge用于密码哈希
                const challengeResp = await fetch(this.apiBase + '/api/challenge');
                if (!challengeResp.ok) {
                    this.registerError = '获取安全挑战失败';
                    return;
                }
                const challengeData = await challengeResp.json();
                const challenge = challengeData.challenge;

                // 注册时发送明文密码（与老用户保持一致，以便老界面登录）
                // 登录时才使用 challenge 哈希验证
                const plainPassword = this.registerForm.password;

                // 发送注册命令: login_regnew gamelib fullUserid plainPassword sessionId challenge
                // 注意：注册不需要txd，直接发送cmd参数
                const cmd = `login_regnew gamelib ${fullUserid} ${plainPassword} ${sessionId} ${challenge}`;
                let url = this.apiBase + '/api/html?cmd=' + encodeURIComponent(cmd);

                // 如果有推荐码，添加到URL参数
                if (referralCode) {
                    url += '&ref=' + encodeURIComponent(referralCode);
                    console.log('使用推荐码:', referralCode);
                }

                const response = await fetch(url, {
                    method: 'GET'
                });

                console.log('response.status:', response.status);
                console.log('response.ok:', response.ok);

                const text = await response.text();

                // 检查注册结果
                if (text.includes('邀请码') || text.includes('邀请关系') ||
                    text.includes('同一注册网络')) {
                    const message = text.match(/<div>error2,([^<]+)<\/div>/)?.[1];
                    this.registerError = message || '邀请链接无效，请向好友重新获取';
                } else if (text.includes('error1') || text.includes('已经有人使用')) {
                    this.registerError = '该账号已存在，请修改后重试';
                } else if (text.includes('error2') || text.includes('登录错误')) {
                    this.registerError = '注册失败，请稍后重试';
                } else {
                    // 注册成功 - 响应格式: username,password
                    this.registerSuccess = true;
                    this.registerSuccessAccount = fullUserid;
                    this.registerError = '';
                    this.clearReferralLanding();
                    // 延迟后返回登录页面
                    this.registerReturnTimer = setTimeout(() => {
                        this.returnToLoginAfterRegistration();
                    }, 2200);
                }
            } catch (e) {
                console.error('注册请求失败:', e);
                console.error('错误名称:', e.name);
                console.error('错误消息:', e.message);
                this.registerError = '连接失败: ' + e.message;
            } finally {
                this.isRegistering = false;
            }
        },

        persistAccountSession() {
            // 自动浏览器中所有存储（sessionStorage/localStorage/window.name）都跨标签共享。
            // 唯一可靠的标签隔离机制是 URL 中的 ?txd=xxx 参数。
            // 不在存储中持久化会话数据，完全依赖 URL + Vue 内存状态。
        },

        // 兼容旧调用：全部空操作，不再使用任何存储做会话持久化
        getTabId() { return 'xiand_tab_nostore'; },
        saveTabSession() {},
        loadTabSession() { return null; },
        clearTabSession() {},

        clearAccountSession() {
            // 不清除 sessionStorage：自动浏览器共享 sessionStorage，清除会影响其他标签页。
            this.clearTabSession();
            this.accountToken = '';
            this.accountId = '';
            this.accountCharacters = [];
            this.accountCharacterLimit = 10;
            this.accountSharedRechargeBalance = 0;
            this.accountSharedRechargeAvailable = true;
			this.illusionEntitled = false;
			this.illusionRealmStatus = {
				ok: false, illusion_id: 'S1', display_name: '新月幻境·S1',
				phase: 'disabled', phase_name: '不可用', creation_open: false,
				entitlement_open: false, entitlement_cost_suiyu: 0
			};
            this.characterCreateOpen = false;
            this.characterError = '';
        },

        invalidateCharacterSessionRequests() {
            this.characterSessionEpoch += 1;
            this.autofightTickInFlight = false;
            this.autofightViewSequence = 0;
            this.autofightViewGeneration = '';
            this.battleStatusLoading = false;
            this.mudLoading = false;
            this.smoothOutputLoading = false;
            this.slowLoadingTip = false;
            this.showEquipmentPanel = false;
            this.equipmentPanel = null;
            this.equipmentPanelError = '';
            this.equipmentActionBusy = '';
            this.characterProfileOpen = false;
            this.characterProfileBusy = false;
            this.characterProfileError = '';
            this.characterProfileDismissedFor = '';
            if (this.loadingTimer) {
                clearTimeout(this.loadingTimer);
                this.loadingTimer = null;
            }
            this.resetPetBattleVisualState();
            this.roomSkillEventHistory = {};
            this.clearPetLevelUpEffect();
            return this.characterSessionEpoch;
        },

        handleForcedCharacterLogout(data = {}) {
            const message = data.error ||
                '当前人物已因账号在线上限安全退出，请从人物中心重新选择。';
            this.invalidateCharacterSessionRequests();
            this.stopStatsUpdate();
            this.stopBattleStatusPolling();
            this.stopChatPolling();
            if (this.autofightInterval) {
                clearInterval(this.autofightInterval);
                this.autofightInterval = null;
            }
            this.clearTabSession();

            this.txd = '';
            this.currentCharacterId = '';
            this.playerStats = null;
            this.mudLines = [];
            this.isInBattle = false;
            this.battleEnemy = null;
            this.battleEnemyFull = null;
            this.battlePlayerFull = null;
            this.clearBattleAoeReport();
            this.battleAnimations = [];
            this.skillAnimations = [];
            this.showChatRoom = false;
            this.characterLoading = false;
            this.characterSelectCanCancel = false;
            this.showRegister = false;
            this.showCharacterSelect = Boolean(this.accountToken);
            this.showLogin = !this.accountToken;
            this.characterError = message;
            if (!this.accountToken) this.loginError = message;
            this.showUiToast(message, 'warning');
            return true;
        },

        isCharacterSessionCurrent(epoch) {
            return epoch === this.characterSessionEpoch;
        },

        applyAccountData(data) {
            this.accountId = data.account_id || this.accountId;
            this.accountCharacters = Array.isArray(data.characters) ? data.characters : [];
            this.accountCharacterLimit = Number(data.limit || 10);
            this.accountSharedRechargeBalance = Math.max(
                0, Number(data.shared_recharge_balance || 0)
            );
            this.accountSharedRechargeAvailable =
                data.shared_recharge_available !== 0;
			this.illusionEntitled = !!data.illusion_entitled;
			if (data.illusion_realm && typeof data.illusion_realm === 'object') {
				this.illusionRealmStatus = Object.assign({},
					this.illusionRealmStatus, data.illusion_realm);
			}
            this.wuxiangUnlocked = !!data.wuxiang_unlocked;
            this.taijiUnlocked = !!data.taiji_unlocked;
            if (data.token) {
                this.accountToken = data.token;
            }
            this.persistAccountSession();
        },

        async postAccountApi(path, body) {
            const response = await fetch(this.apiBase + path, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(body || {})
            });
            let data = {};
            try {
                data = await response.json();
            } catch (error) {
                data = {};
            }
            if (!response.ok || data.error) {
                const apiError = new Error(data.error || ('HTTP ' + response.status));
                apiError.status = response.status;
                throw apiError;
            }
            return data;
        },

        async completeCharacterLogin(
            txd, characterId, command = 'init', prefetchedData = null,
            expectedEpoch = this.characterSessionEpoch
        ) {
            let data = prefetchedData;
            if (!data) {
                const params = new URLSearchParams({ txd, cmd: command });
                const response = await fetch(this.apiBase + '/api/json?' + params.toString());
                data = await response.json().catch(() => ({}));
                if (!this.isCharacterSessionCurrent(expectedEpoch)) return false;
                if (response.status === 409 && data.forced_logout) {
                    this.handleForcedCharacterLogout(data);
                    return false;
                }
                if (!response.ok || data.error) {
                    throw new Error(data.error || ('人物登录失败: HTTP ' + response.status));
                }
            }
            if (!this.isCharacterSessionCurrent(expectedEpoch)) return false;
            const credentials = this.decodeCredentialsFromTxd(txd);
            if (data.userid && credentials &&
                data.userid !== credentials.userid) {
                throw new Error('人物会话响应不匹配，请重新选择人物');
            }
            this.txd = data.txd || txd;
            this.currentCharacterId = characterId;
            this.saveTabSession();



            this.saveGameBaseUrl();
            this.updateUrlWithTxd();
            this.mudLines = data.lines || [];
            this.handleNewbieCompletions(data.newbie_completions || []);
            this.showLogin = false;
            this.showRegister = false;
            this.showCharacterSelect = false;
            this.characterCreateOpen = false;
            this.characterError = '';
            this.scheduleAutoAnimateInitialization();
            this.startStatsUpdate();
            return true;
        },

        async selectAccountCharacter(character) {
            if (!character || !character.id || !this.accountToken || this.characterLoading) {
                return;
            }
            this.characterLoading = true;
            this.characterError = '';
            const expectedEpoch = this.invalidateCharacterSessionRequests();
            if (this.autofightInterval) {
                clearInterval(this.autofightInterval);
                this.autofightInterval = null;
            }
            try {
                const selected = await this.postAccountApi('/api/account/characters/select', {
                    token: this.accountToken,
                    character_id: character.id
                });
                this.playerStats = null;
                await this.completeCharacterLogin(
                    selected.txd,
                    selected.character_id,
                    selected.bootstrap_command || 'init',
                    null,
                    expectedEpoch
                );
            } catch (error) {
                if (!this.isCharacterSessionCurrent(expectedEpoch)) return;
                this.characterError = error.message || '进入人物失败';
                if (error.status === 401) {
                    this.clearAccountSession();
                    this.showCharacterSelect = false;
                    this.showLogin = true;
                    this.loginError = '账号会话已过期，请重新登录';
                }
            } finally {
                if (this.isCharacterSessionCurrent(expectedEpoch))
                    this.characterLoading = false;
            }
        },

        async refreshAccountCharacters() {
            if (!this.accountToken) return false;
            this.characterLoading = true;
            this.characterError = '';
            try {
                // 令牌只放请求体，避免出现在URL、代理访问日志或历史记录中。
                const data = await this.postAccountApi('/api/account/characters', {
                    token: this.accountToken
                });
                this.applyAccountData(data);
                return true;
            } catch (error) {
                this.characterError = error.message;
                if (error.status === 401) this.clearAccountSession();
                return false;
            } finally {
                this.characterLoading = false;
            }
        },

        openCharacterCreator() {
            if (this.accountCharacters.length >= this.accountCharacterLimit) {
                this.characterError = `人物档案已达到${this.accountCharacterLimit}个上限`;
                return;
            }
            this.characterForm.race_id = '';
			this.characterForm.realm_type = 'eternal';
            this.characterForm.profession_id = '';
            this.characterForm.name_cn = '';
            this.characterForm.sex = 'male';
            this.characterForm.avatar_id = '';
            this.characterError = '';
            this.characterCreateOpen = true;
        },

        chooseNewProfession(option) {
            this.characterForm.race_id = option.race_id;
            this.characterForm.profession_id = option.profession_id;
            this.characterForm.avatar_id = '';
            this.characterError = '';
        },

        chooseCharacterSex(sex, profileMode = false) {
            if (sex !== 'male' && sex !== 'female') return;
            const form = profileMode ? this.characterProfileForm : this.characterForm;
            if (profileMode && !form.needs_sex && form.sex !== sex) return;
            if (form.sex !== sex) {
                form.sex = sex;
                form.avatar_id = '';
            }
        },

        avatarChoicesFor(raceId, professionId, sex) {
            if (!raceId || !professionId || !['male', 'female'].includes(sex)) {
                return [];
            }
            const choices = [];
            if (raceId === 'human' || raceId === 'third') {
                if (raceId === 'third' &&
                    ['zhenyue', 'tianxiang', 'lingyi', 'wuxiang', 'taiji'].includes(professionId)) {
                    choices.push(`${professionId}_${sex}`);
                }
                const count = sex === 'male' ? 11 : 12;
                for (let index = 1; index <= count; index += 1) {
                    choices.push(`h_${sex}${index}`);
                }
            } else if (raceId === 'monst') {
                const count = sex === 'male' ? 12 : 11;
                for (let index = 1; index <= count; index += 1) {
                    choices.push(`m_${sex}${index}`);
                }
            }
            return choices;
        },

        async createAccountCharacter() {
            if (this.characterCreating) return;
            if (!this.characterForm.profession_id) {
                this.characterError = '请先选择一个职业';
                return;
            }
            if (!String(this.characterForm.name_cn || '').trim()) {
                this.characterError = '请先为人物取一个姓名';
                return;
            }
            if (!this.characterForm.sex || !this.characterForm.avatar_id) {
                this.characterError = '请选择人物性别和头像';
                return;
            }
            this.characterCreating = true;
            this.characterError = '';
            try {
                const created = await this.postAccountApi('/api/account/characters/create', {
                    token: this.accountToken,
				realm_type: this.characterForm.realm_type,
                    race_id: this.characterForm.race_id,
                    profession_id: this.characterForm.profession_id,
                    name_cn: String(this.characterForm.name_cn).trim(),
                    sex: this.characterForm.sex,
                    avatar_id: this.characterForm.avatar_id
                });
                await this.refreshAccountCharacters();
                const newId = created.character && created.character.id;
                const character = this.accountCharacters.find(one => one.id === newId);
                this.characterCreateOpen = false;
                if (character) await this.selectAccountCharacter(character);
            } catch (error) {
                this.characterError = error.message || '创建人物失败';
                if (error.status === 401) {
                    this.clearAccountSession();
                    this.showCharacterSelect = false;
                    this.showLogin = true;
                }
            } finally {
                this.characterCreating = false;
            }
        },

        maybePromptCharacterProfile(data) {
            if (!data || data.profile_complete ||
                (!data.profile_needs_name && !data.profile_needs_sex &&
                 !data.profile_needs_avatar)) {
                this.characterProfileOpen = false;
                return;
            }
            const characterId = this.currentCharacterId ||
                (this.decodeCredentialsFromTxd(this.txd) || {}).userid || '';
            if (!characterId || this.characterProfileDismissedFor === characterId ||
                this.characterProfileOpen) return;
            const choices = Array.isArray(data.profile_avatar_choices)
                ? data.profile_avatar_choices : [];
            this.characterProfileForm.name_cn = data.profile_needs_name
                ? '' : String(data.name_cn || '');
            this.characterProfileForm.sex = ['male', 'female'].includes(data.sex)
                ? data.sex : 'male';
            this.characterProfileForm.avatar_id = data.profile_needs_avatar
                ? '' : String(data.avatar_id || '');
            this.characterProfileForm.race_id = String(data.race_id || '');
            this.characterProfileForm.profession_id = String(data.profession_id || '');
            this.characterProfileForm.needs_name = !!data.profile_needs_name;
            this.characterProfileForm.needs_sex = !!data.profile_needs_sex;
            this.characterProfileForm.needs_avatar = !!data.profile_needs_avatar;
            if (data.profile_needs_avatar && choices.length === 1) {
                this.characterProfileForm.avatar_id = choices[0];
            }
            this.characterProfileError = '';
            this.characterProfileOpen = true;
        },

        skipCharacterProfile() {
            this.characterProfileDismissedFor = this.currentCharacterId ||
                (this.decodeCredentialsFromTxd(this.txd) || {}).userid || '';
            this.characterProfileOpen = false;
            this.characterProfileError = '';
        },

        async submitCharacterProfile() {
            if (this.characterProfileBusy || !this.txd) return;
            const form = this.characterProfileForm;
            if (form.needs_name && !String(form.name_cn || '').trim()) {
                this.characterProfileError = '请为人物取一个姓名，或选择暂时跳过';
                return;
            }
            if (!form.sex || !form.avatar_id) {
                this.characterProfileError = '请选择人物性别和头像，或选择暂时跳过';
                return;
            }
            this.characterProfileBusy = true;
            this.characterProfileError = '';
            try {
                const response = await fetch(this.apiBase + '/api/profile', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        txd: this.txd,
                        name_cn: String(form.name_cn || '').trim(),
                        sex: form.sex,
                        avatar_id: form.avatar_id
                    })
                });
                const data = await response.json().catch(() => ({}));
                if (!response.ok || data.error) {
                    const error = new Error(data.error || '人物资料保存失败');
                    error.status = response.status;
                    throw error;
                }
                this.characterProfileDismissedFor = this.currentCharacterId || '';
                this.characterProfileOpen = false;
                this.showUiToast(data.message || '人物姓名与头像已保存', 'info');
                await this.fetchPlayerStats();
                if (this.accountToken) await this.refreshAccountCharacters();
            } catch (error) {
                this.characterProfileError = error.message || '人物资料保存失败';
            } finally {
                this.characterProfileBusy = false;
            }
        },

        async authenticateAccountFromCurrentTxd() {
            const credentials = this.decodeCredentialsFromTxd(this.txd);
            if (!credentials) return false;
            try {
                const data = await this.postAccountApi('/api/account/login', {
                    userid: credentials.userid,
                    password: credentials.password
                });
                this.applyAccountData(data);
                return true;
            } catch (error) {
                return false;
            }
        },

        async openCharacterCenter() {
            this.headerMenuOpen = false;
            this.characterSelectCanCancel = Boolean(this.txd);
            this.characterError = '';
            if (!this.accountToken) {
                const authenticated = await this.authenticateAccountFromCurrentTxd();
                if (!authenticated) {
                    this.showUiToast('请退出后使用注册账号密码登录，再管理人物档案', 'warning');
                    return;
                }
            }
            let loaded = await this.refreshAccountCharacters();
            // sessionStorage 中的12小时令牌可能已过期；当前人物TXD仍有效时，
            // 同一次点击自动重新认证，不让玩家看见一次“无反应”。
            if (!loaded && !this.accountToken && this.txd) {
                const authenticated = await this.authenticateAccountFromCurrentTxd();
                if (authenticated) loaded = await this.refreshAccountCharacters();
            }
            if (!loaded) {
                this.showUiToast(this.characterError || '人物档案暂时不可用', 'error');
                return;
            }
            this.stopStatsUpdate();
            this.stopBattleStatusPolling();
            this.stopChatPolling();
            if (this.autofightInterval) {
                clearInterval(this.autofightInterval);
                this.autofightInterval = null;
            }
            this.showLogin = false;
            this.showRegister = false;
            this.showCharacterSelect = true;
        },

        cancelCharacterCenter() {
            if (!this.characterSelectCanCancel || !this.txd) return;
            this.showCharacterSelect = false;
            this.characterCreateOpen = false;
            this.characterError = '';
            this.startStatsUpdate();
            if (this.isInBattle) this.startBattleStatusPolling();
            if (this.playerStats?.autofight) this.checkAutofight();
        },

        async doLegacyLogin(fullUserid, password) {
            const params = new URLSearchParams({
                userid: fullUserid,
                password,
                cmd: 'init'
            });
            const response = await fetch(this.apiBase + '/api/json?' + params.toString());
            const data = await response.json().catch(() => ({}));
            if (!response.ok || data.error) {
                throw new Error(data.error || '用户名或密码错误');
            }
            await this.completeCharacterLogin(
                data.txd || this.encodeTxd(fullUserid, password),
                fullUserid,
                'init',
                data
            );
        },

        async doLogin() {
            // 书签直达：若 URL 带 ?userid=xxx 且用户没手动改过表单的 userid，
            // 用 URL 的完整账号 ID 跳过分区下拉拼接。
            // 用户在表单里输了 userid 就以表单为准（允许覆盖书签账号）。
            const userInput = (this.loginForm.userid || '').trim();
            const partitionedUserid = userInput
                ? (this.loginForm.partition + userInput) : '';
            // 书签保存的是完整且区分大小写的账号 ID，登录框通常只输入
            // 去掉分区后的短账号。两者都匹配时必须使用书签原值，不能
            // lower-case，也不能因为格式不同而放弃自动选角。
            const bookmarkAccountMatched = !!this.preselectedUserid &&
                (!userInput || userInput === this.preselectedUserid ||
                    partitionedUserid === this.preselectedUserid);
            const fullUserid = bookmarkAccountMatched
                ? this.preselectedUserid
                : partitionedUserid;
            if (!fullUserid || !this.loginForm.password) {
                this.loginError = !fullUserid ? '请输入账号和密码' : '请输入密码';
                return;
            }
            this.isLoggingIn = true;
            this.loginError = '';
            try {
                let accountData;
                try {
                    accountData = await this.postAccountApi('/api/account/login', {
                        userid: fullUserid,
                        password: this.loginForm.password
                    });
                } catch (error) {
                    // 滚动部署到旧后端时保持原Vue直登协议可用。
                    if (error.status === 404 || error.status === 501) {
                        await this.doLegacyLogin(fullUserid, this.loginForm.password);
                        return;
                    }
                    throw error;
                }
                this.applyAccountData(accountData);
                this.showLogin = false;
                this.showRegister = false;
                // 书签直达：登录成功后若 preselectedCharacterId 在角色列表里，
                // 跳过选角界面直接进入该角色。找不到则降级到原有流程。
                const bookmarkMatch = bookmarkAccountMatched &&
                    this.preselectedCharacterId
                    ? this.accountCharacters.find(c => c.id === this.preselectedCharacterId)
                    : null;
                if (bookmarkMatch) {
                    this.characterSelectCanCancel = false;
                    this.showCharacterSelect = true;
                    await this.selectAccountCharacter(bookmarkMatch);
                } else if (this.accountCharacters.length === 1) {
                    // 先保留选角遮罩；若物理档案临时不可用，错误仍有可见承载页，
                    // 成功进入后 completeCharacterLogin 会自动关闭。
                    this.characterSelectCanCancel = false;
                    this.showCharacterSelect = true;
                    await this.selectAccountCharacter(this.accountCharacters[0]);
                } else {
                    this.characterSelectCanCancel = false;
                    this.showCharacterSelect = true;
                }
            } catch (error) {
                this.loginError = error.message || '登录失败';
                this.showLogin = true;
            } finally {
                this.isLoggingIn = false;
            }
        },

        encodeTxd(userid, password) {
            let uid = '';
            let pid = '';
            for (let i = 0; i < userid.length; i++) {
                let code = userid.charCodeAt(i);
                if (Math.floor(i / 2) === 0) {
                    uid += (code === 121) ? '%7B' : String.fromCharCode(code + 2);
                } else {
                    uid += (code === 122) ? '%7B' : String.fromCharCode(code + 1);
                }
            }
            for (let i = 0; i < password.length; i++) {
                let code = password.charCodeAt(i);
                if (Math.floor(i / 2) === 0) {
                    pid += (code === 122) ? '%7B' : String.fromCharCode(code + 1);
                } else {
                    if (code === 121) {
                        pid += '%7B';
                    } else if (code === 122) {
                        pid += '%7C';
                    } else {
                        pid += String.fromCharCode(code + 2);
                    }
                }
            }
            return uid + '~' + pid;
        },

        // 更新URL以包含txd参数（便于书签/分享）
        // 同时持久化 char 参数：txd 过期后用户重新登录仍能自动选回该角色。
        updateUrlWithTxd() {
            if (!this.txd) return;

            // 从长期人物书签进入时，地址栏必须始终保持可再次收藏、复制
            // 和跨浏览器打开的书签URL。绝不把可还原密码的TXD混进链接。
            if (this.characterBookmarkToken && this.preselectedUserid &&
                this.currentCharacterId) {
                const bookmarkUrl = this.buildAccountCharacterBookmarkUrl(
                    this.currentCharacterId, this.characterBookmarkToken
                );
                window.history.replaceState({}, '', bookmarkUrl.toString());
                return;
            }
            const url = new URL(window.location.href);
            url.searchParams.set('txd', this.txd);
            if (this.currentCharacterId) {
                url.searchParams.set('char', this.currentCharacterId);
            }
            // 书签直达：若有 preselectedUserid 也持久化，使刷新后书签账号不丢
            if (this.preselectedUserid) {
                url.searchParams.set('userid', this.preselectedUserid);
            }

            const newUrl = url.toString();

            // 使用replaceState更新URL而不刷新页面
            window.history.replaceState({}, '', newUrl);
        },

        // 复制书签URL到剪贴板
        async copyBookmarkUrl() {
            try {
                // 确保URL包含当前的txd
                this.updateUrlWithTxd();

                const url = window.location.href;
                await navigator.clipboard.writeText(url);

                // 显示提示消息
                this.showNotification('登录链接已复制，可跨设备使用');
            } catch (err) {
                // 降级方案：使用传统方法
                const url = window.location.href;
                const textArea = document.createElement('textarea');
                textArea.value = url;
                textArea.style.position = 'fixed';
                textArea.style.opacity = '0';
                document.body.appendChild(textArea);
                textArea.select();
                try {
                    document.execCommand('copy');
                    this.showNotification('登录链接已复制，可跨设备使用');
                } catch (e) {
                    this.showNotification('复制失败，请手动复制URL');
                }
                document.body.removeChild(textArea);
            }
        },

        buildAccountCharacterBookmarkUrl(characterId, bookmarkToken = '') {
            const url = new URL(window.location.href);
            // 长期人物入口使用参数白名单。只保留自动浏览器需要的
            // mode=html；历史URL中的任何未知参数都不能被当成凭证复制。
            const htmlMode = url.searchParams.get('mode') === 'html';
            url.search = '';
            url.hash = '';
            if (htmlMode) url.searchParams.set('mode', 'html');
            url.searchParams.set('userid', this.accountId);
            url.searchParams.set('char', characterId);
            if (/^[0-9a-f]{64}$/.test(bookmarkToken)) {
                const bookmark = new URLSearchParams({
                    character_bookmark: bookmarkToken
                });
                url.hash = bookmark.toString();
            }
            return url;
        },

        bookmarkShortcutLabel() {
            const platform = String(navigator.platform || '').toLowerCase();
            return platform.includes('mac') ? '⌘D' : 'Ctrl+D';
        },

        // 签发一个只绑定所选人物的长期凭证，复制后可在其他浏览器直接
        // 打开。先同步创建空白标签，避免await后被浏览器当成弹窗拦截。
        async copyCharacterBookmarkUrl(characterId) {
            if (!characterId || !this.accountId || !this.accountToken) {
                this.showNotification('角色信息缺失，无法复制书签');
                return;
            }
            const opened = window.open('about:blank', '_blank');
            if (opened) opened.opener = null;
            let issued;
            try {
                issued = await this.postAccountApi(
                    '/api/account/bookmark/create', {
                        token: this.accountToken,
                        character_id: characterId
                    }
                );
            } catch (error) {
                if (opened && typeof opened.close === 'function') opened.close();
                this.showNotification(error.message || '直达书签创建失败，请重试');
                return;
            }
            const bookmarkToken = issued.bookmark_token || '';
            if (!/^[0-9a-f]{64}$/.test(bookmarkToken)) {
                if (opened && typeof opened.close === 'function') opened.close();
                this.showNotification('服务器没有返回有效书签，请重试');
                return;
            }
            const bookmarkUrl = this.buildAccountCharacterBookmarkUrl(
                characterId, bookmarkToken
            ).toString();
            let openedOk = false;
            if (opened) {
                try {
                    opened.location.replace(bookmarkUrl);
                    openedOk = true;
                } catch (error) {
                    if (typeof opened.close === 'function') opened.close();
                }
            }
            let copied = false;
            try {
                await navigator.clipboard.writeText(bookmarkUrl);
                copied = true;
            } catch (err) {
                const textArea = document.createElement('textarea');
                textArea.value = bookmarkUrl;
                textArea.style.position = 'fixed';
                textArea.style.opacity = '0';
                document.body.appendChild(textArea);
                textArea.select();
                try {
                    document.execCommand('copy');
                    copied = true;
                } catch (e) {
                    copied = false;
                }
                document.body.removeChild(textArea);
            }
            if (copied && openedOk)
                this.showNotification('跨浏览器直达书签已复制；新标签打开后按' +
                    this.bookmarkShortcutLabel() + '收藏');
            else if (copied)
                this.showNotification('书签已复制；浏览器拦截了新标签，请允许弹窗');
            else if (openedOk)
                this.showNotification('新标签已打开；复制失败，请手动保存地址');
            else
                this.showNotification('复制和新标签均被浏览器阻止，请检查权限');
        },

        async resumeCharacterBookmarkHandoff() {
            if (!this.accountToken || !this.preselectedCharacterId) return false;
            this.showLogin = false;
            this.showCharacterSelect = true;
            this.characterLoading = true;
            this.characterError = '';
            try {
                const accountData = await this.postAccountApi(
                    '/api/account/characters', { token: this.accountToken }
                );
                this.applyAccountData(accountData);
                if (this.preselectedUserid &&
                    this.accountId !== this.preselectedUserid) {
                    throw new Error('书签账号与当前会话不匹配，请重新登录');
                }
                const character = this.accountCharacters.find(
                    one => one.id === this.preselectedCharacterId
                );
                if (!character)
                    throw new Error('书签对应的人物不存在或暂不可用');
                this.characterLoading = false;
                await this.selectAccountCharacter(character);
                return this.currentCharacterId === character.id;
            } catch (error) {
                this.characterLoading = false;
                this.clearAccountSession();
                this.showCharacterSelect = false;
                this.showLogin = true;
                this.loginError = error.message || '书签会话已过期，请重新登录';
                return false;
            }
        },

        async resumePersistentCharacterBookmark() {
            if (!this.characterBookmarkToken || !this.preselectedUserid ||
                !this.preselectedCharacterId) return false;
            this.showLogin = false;
            this.showCharacterSelect = false;
            this.characterLoading = true;
            this.loginError = '';
            const expectedEpoch = this.invalidateCharacterSessionRequests();
            try {
                const selected = await this.postAccountApi(
                    '/api/account/bookmark/open', {
                        userid: this.preselectedUserid,
                        character_id: this.preselectedCharacterId,
                        bookmark_token: this.characterBookmarkToken
                    }
                );
                if (selected.account_id !== this.preselectedUserid ||
                    selected.character_id !== this.preselectedCharacterId)
                    throw new Error('直达书签返回的人物不匹配');
                this.accountId = selected.account_id;
                await this.completeCharacterLogin(
                    selected.txd,
                    selected.character_id,
                    selected.bootstrap_command || 'init',
                    null,
                    expectedEpoch
                );
                const entered = this.currentCharacterId === selected.character_id;
                if (entered)
                    this.showNotification('已通过直达书签进入；按' +
                        this.bookmarkShortcutLabel() + '可收藏当前角色', 6000);
                return entered;
            } catch (error) {
                if (!this.isCharacterSessionCurrent(expectedEpoch)) return false;
                this.characterBookmarkToken = '';
                const cleanUrl = new URL(window.location.href);
                cleanUrl.hash = '';
                window.history.replaceState({}, '', cleanUrl.toString());
                this.showLogin = true;
                this.loginError = error.message || '直达书签无效，请重新登录';
                return false;
            } finally {
                if (this.isCharacterSessionCurrent(expectedEpoch))
                    this.characterLoading = false;
            }
        },

        async revokeCharacterBookmarks(characterId) {
            if (!characterId || !this.accountToken || this.characterLoading)
                return;
            if (!window.confirm('撤销后，该人物以前保存和分享的直达书签都会失效。确定继续吗？'))
                return;
            this.characterLoading = true;
            try {
                const result = await this.postAccountApi(
                    '/api/account/bookmark/revoke', {
                        token: this.accountToken,
                        character_id: characterId
                    }
                );
                this.showNotification(result.message || '直达书签已撤销');
            } catch (error) {
                this.showNotification(error.message || '撤销失败，请重试');
            } finally {
                this.characterLoading = false;
            }
        },

        // 显示通知消息
        showNotification(message, duration = 2000) {
            // 移除已存在的通知
            const existing = document.querySelector('.copy-notification');
            if (existing) {
                existing.remove();
            }

            const notification = document.createElement('div');
            notification.className = 'copy-notification';
            notification.textContent = message;
            notification.style.cssText = `
                position: fixed;
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
                background: rgba(0, 0, 0, 0.8);
                color: white;
                padding: 16px 24px;
                border-radius: 8px;
                z-index: 10000;
                animation: fadeIn 0.3s ease;
            `;
            document.body.appendChild(notification);

            setTimeout(() => {
                notification.style.animation = 'fadeOut 0.3s ease';
                setTimeout(() => notification.remove(), 300);
            }, duration);
        },

        // iframe加载完成
        onFrameLoad() {
            this.frameLoading = false;
        },

        // 刷新iframe
        refreshFrame() {
            if (this.useJsonMode) {
                // JSON模式: 重新执行最后命令或look
                this.sendJsonCommand(this.lastCommand || 'look');
            } else {
                // iframe模式: 强制刷新iframe
                this.frameLoading = true;
                const iframe = this.$refs.gameFrame;
                if (iframe) {
                    iframe.src = iframe.src;
                }
            }
        },

        // 显示命令输入框
        showCommandModal() {
            this.showCommandInput = true;
            this.$nextTick(() => {
                if (this.$refs.commandInputRef) {
                    this.$refs.commandInputRef.focus();
                }
            });
        },

        async openEquipmentPanel() {
            this.showEquipmentPanel = true;
            await this.fetchEquipmentPanel();
        },

        closeEquipmentPanel() {
            this.showEquipmentPanel = false;
            this.equipmentActionBusy = '';
        },

        cleanEquipmentName(value) {
            return String(value || '')
                .replace(/§[0-9a-zA-Z]/g, '')
                .replace(/\s+/g, ' ')
                .trim();
        },

        getEquipmentCandidates(slot) {
            const candidates = this.equipmentPanel?.candidates?.[slot];
            if (!Array.isArray(candidates)) return [];
            return candidates.filter(item => item && !item.equipped);
        },

        equipmentRarityClass(item) {
            const value = Math.max(0, Math.min(7,
                Number(item?.rare_level || 0)));
            return 'equipment-rarity-' + value;
        },

        equipmentLevelClass(item) {
            const level = Math.max(0, Number(item?.level_requirement || 0));
            if (level >= 200) return 'equipment-level-7';
            if (level >= 160) return 'equipment-level-6';
            if (level >= 100) return 'equipment-level-5';
            if (level >= 80) return 'equipment-level-4';
            if (level >= 60) return 'equipment-level-3';
            if (level >= 40) return 'equipment-level-2';
            if (level >= 20) return 'equipment-level-1';
            return 'equipment-level-0';
        },

        progressionAuraTier(level) {
            const parsed = Number(level);
            const value = Math.max(1, Number.isFinite(parsed) ? parsed : 1);
            if (value >= 250) return 7;
            if (value >= 200) return 6;
            if (value >= 160) return 5;
            if (value >= 120) return 4;
            if (value >= 90) return 3;
            if (value >= 60) return 2;
            if (value >= 30) return 1;
            return 0;
        },

        petLevelAuraClass(pet) {
            if (!pet || Number(pet.active || 0) !== 1) {
                return 'pet-level-aura-0';
            }
            return 'pet-level-aura-' + this.progressionAuraTier(pet.level);
        },

        petRarityAuraClass(pet) {
            if (!pet || Number(pet.active || 0) !== 1) {
                return 'pet-rarity-aura-0';
            }
            const finiteNumber = (value) => {
                const parsed = Number(value);
                return Number.isFinite(parsed) ? parsed : 0;
            };
            const explicitRarity = finiteNumber(
                pet.visual_rarity ?? pet.rare_level ?? pet.rarity ?? 0
            );
            const starRarity = Math.max(0, finiteNumber(pet.star) - 1);
            const evolutionRarity = Math.max(0,
                finiteNumber(pet.evolution) * 2);
            const rarity = Math.max(0, Math.min(7,
                Math.max(explicitRarity, starRarity, evolutionRarity)));
            return 'pet-rarity-aura-' + rarity;
        },

        monsterLevelAuraClass(enemy) {
            if (!enemy || !enemy.is_npc) return 'monster-level-aura-0';
            return 'monster-level-aura-' +
                this.progressionAuraTier(enemy.level);
        },

        getEquipmentImageUrl(item, slot) {
            const imagePath = item?.image_url ||
                this.equipmentPanel?.slots?.[slot]?.image ||
                '/images/equipment/fallback/decorate_tool.png';
            return this.getImageUrl(imagePath);
        },

        async fetchEquipmentPanel() {
            if (!this.txd) return;
            const requestEpoch = this.characterSessionEpoch;
            const requestTxd = this.txd;
            this.equipmentPanelLoading = true;
            this.equipmentPanelError = '';
            try {
                const response = await fetch(
                    `${this.apiBase}/api/equipment_panel?txd=${encodeURIComponent(requestTxd)}`
                );
                if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                let data = {};
                try {
                    data = await response.json();
                } catch (error) {
                    data = {};
                }
                if (!response.ok || data.error) {
                    throw new Error(data.error || `HTTP ${response.status}`);
                }
                this.equipmentPanel = data;
                const selectedExists = data.slots?.[this.equipmentSelectedSlot];
                if (!selectedExists) {
                    const equippedSlots = Object.keys(data.equipped || {});
                    this.equipmentSelectedSlot = equippedSlots[0] ||
                        data.slot_order?.[0] || 'armor_head';
                }
            } catch (error) {
                if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                this.equipmentPanelError = error.message || '装备栏读取失败';
            } finally {
                if (this.isCharacterSessionCurrent(requestEpoch)) {
                    this.equipmentPanelLoading = false;
                }
            }
        },

        async runEquipmentAction(item) {
            if (!item?.action_cmd || this.equipmentActionBusy) return;
            this.equipmentActionBusy = item.id;
            const wasEquipped = !!item.equipped;
            try {
                await this.sendJsonCommand(item.action_cmd);
                await Promise.all([
                    this.fetchEquipmentPanel(),
                    this.fetchPlayerStats()
                ]);
                const refreshed = Object.values(
                    this.equipmentPanel?.candidates || {}
                ).flat().find(candidate => candidate?.id === item.id);
                const changed = wasEquipped ? !refreshed?.equipped :
                    !!refreshed?.equipped;
                this.showUiToast(changed ?
                    `${this.cleanEquipmentName(item.name_cn)}已${wasEquipped ? '卸下' : '穿戴'}` :
                    '换装未生效，请查看游戏提示确认等级、职业或属性条件',
                    changed ? 'info' : 'error');
            } finally {
                this.equipmentActionBusy = '';
            }
        },

        // 显示聊天输入框 - 改为打开聊天室视图
        showChatModal() {
            this.showChatRoom = true;
            // 先执行游戏内的打开聊天命令，设置roomchatid
            this.sendQuickCommand('ui_select_room open');
            // 延迟启动轮询，等待命令执行
            setTimeout(() => {
                this.startChatPolling();
                this.loadChatMessages();
            }, 300);
            // 聚焦输入框
            this.$nextTick(() => {
                if (this.$refs.chatInputRef) {
                    this.$refs.chatInputRef.focus();
                }
            });
        },

        // 关闭聊天室
        closeChatRoom() {
            this.showChatRoom = false;
            this.stopChatPolling();
        },

        // 开始轮询聊天消息
        startChatPolling() {
            // 清除已有定时器
            this.stopChatPolling();
            // 每2秒轮询一次
            this.chatPollingInterval = setInterval(() => {
                this.loadChatMessages();
            }, 2000);
        },

        // 停止轮询聊天消息
        stopChatPolling() {
            if (this.chatPollingInterval) {
                clearInterval(this.chatPollingInterval);
                this.chatPollingInterval = null;
            }
        },

        // ========== 邀请系统相关方法 ==========

        // 保存游戏基础URL到后端（登录时自动调用）
        async saveGameBaseUrl() {
            if (!this.txd) return;

            const baseUrl = window.location.protocol + '//' + window.location.host;
            const requestEpoch = this.characterSessionEpoch;
            const requestTxd = this.txd;

            try {
                const params = new URLSearchParams({
                    txd: requestTxd,
                    url: baseUrl
                });

                const response = await fetch(this.apiBase + '/api/invite/seturl?' + params.toString(), {
                    method: 'POST'
                });

                if (response.ok &&
                    this.isCharacterSessionCurrent(requestEpoch)) {
                    console.log('游戏基础URL已保存:', baseUrl);
                }
            } catch (e) {
                console.warn('保存游戏URL失败:', e);
            }
        },

        // 显示邀请弹窗
        openInviteModal() {
            // 获取完整的用户名（分区+账号）
            let username = this.accountId || this.playerStats?.userid || '';
            if (this.txd) {
                // 兼容新 token（冒号）与旧书签（userid~password）两种格式。
                const tokenUserid = this.txd.split(/[~:]/)[0];
                if (!username && tokenUserid) {
                    username = tokenUserid;
                }
            }

            // 如果没有txd，尝试从登录表单获取
            if (!username && this.loginForm.partition && this.loginForm.userid) {
                username = this.loginForm.partition + this.loginForm.userid;
            }

            // 生成邀请链接 - 使用当前页面路径
            this.inviteCode = username;
            this.inviteLink = this.buildReferralLink(username);
            console.log('邀请链接生成:', {
                username: username,
                inviteCode: this.inviteCode,
                inviteLink: this.inviteLink,
                baseUrl: window.location.origin + window.location.pathname
            });

            // 生成二维码URL
            this.qrCodeUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=' + encodeURIComponent(this.inviteLink);

            this.inviteModalOpen = true;
        },

        // 关闭邀请弹窗
        closeInviteModal() {
            this.inviteModalOpen = false;
        },

        // 复制邀请码
        copyInviteCode() {
            const code = this.inviteCode;
            if (!code) {
                alert('请先登录');
                return;
            }
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(code).then(() => {
                    alert('邀请码已复制！');
                }).catch(() => {
                    this.fallbackCopy(code);
                });
            } else {
                this.fallbackCopy(code);
            }
        },

        // 复制邀请链接
        copyInviteLink() {
            if (!this.inviteLink) {
                alert('请先登录');
                return;
            }
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(this.inviteLink).then(() => {
                    alert('邀请链接已复制！');
                }).catch(() => {
                    this.fallbackCopy(this.inviteLink);
                });
            } else {
                this.fallbackCopy(this.inviteLink);
            }
        },

        // 备用复制方法（使用textarea）
        fallbackCopy(text) {
            const textarea = document.createElement('textarea');
            textarea.value = text;
            textarea.style.position = 'fixed';
            textarea.style.opacity = '0';
            document.body.appendChild(textarea);
            textarea.select();
            try {
                document.execCommand('copy');
                alert('已复制！');
            } catch (e) {
                alert('复制失败，请手动复制');
            }
            document.body.removeChild(textarea);
        },

        // 查看邀请统计（调用游戏内命令）
        viewInviteStats() {
            this.closeInviteModal();
            this.sendQuickCommand('invite stats');
        },

        // 加载聊天消息
        async loadChatMessages() {
            // 只在聊天室打开时才加载
            if (!this.txd || !this.showChatRoom) return;
            const requestEpoch = this.characterSessionEpoch;
            const requestTxd = this.txd;

            try {
                const url = `${this.apiBase}/api/chat/messages?txd=${encodeURIComponent(requestTxd)}&channel=${encodeURIComponent(this.chatChannel)}`;
                const response = await fetch(url);
                if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                if (response.ok) {
                    const data = await response.json();
                    if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                    if (data.messages) {
                        // 更新消息列表
                        this.chatMessages = data.messages;
                        // 滚动到底部
                        this.$nextTick(() => {
                            this.scrollChatToBottom();
                        });
                    }
                }
            } catch (e) {
                console.error('加载聊天消息失败:', e);
            }
        },

        // 滚动聊天到底部
        scrollChatToBottom() {
            const container = this.$refs.chatMessagesContainer;
            if (container) {
                container.scrollTop = container.scrollHeight;
            }
        },

        // 发送聊天消息
        async sendChat() {
            const msg = this.chatInput.trim();
            if (!msg) return;
            const requestEpoch = this.characterSessionEpoch;
            const requestTxd = this.txd;
            if (!requestTxd) return;

            // 通过API发送消息
            try {
                const response = await fetch(`${this.apiBase}/api/chat/send`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    body: new URLSearchParams({
                        txd: requestTxd,
                        channel: this.chatChannel,
                        message: msg
                    })
                });

                if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                if (response.ok) {
                    this.chatInput = '';
                    // 立即刷新消息
                    this.loadChatMessages();
                } else {
                    console.error('发送消息失败');
                }
            } catch (e) {
                console.error('发送消息失败:', e);
            }
        },

        // 发送命令
        sendCommand() {
            const cmd = this.commandInput.trim();
            if (!cmd) return;

            // JSON模式优先
            if (this.useJsonMode) {
                this.lastCommand = cmd;
                this.sendJsonCommand(cmd);
                this.commandInput = '';
                this.showCommandInput = false;
            } else if (this.useAsyncMode) {
                this.sendCommandAsync();
            } else {
                // 同步模式（原有方式）
                const url = `${this.apiBase}/api/html?txd=${encodeURIComponent(this.txd)}&cmd=${encodeURIComponent(cmd)}`;
                const iframe = this.$refs.gameFrame;
                if (iframe) {
                    this.frameLoading = true;
                    iframe.src = url;
                }

                this.commandInput = '';
                this.showCommandInput = false;
            }
        },

        // 发送聊天消息 - 使用ui_chat命令
        sendChat() {
            const msg = this.chatInput.trim();
            if (!msg) return;

            // 使用 ui_chat 命令发送消息
            const cmd = 'ui_chat ' + msg;

            if (this.useJsonMode) {
                // JSON模式: 直接调用 sendJsonCommand
                this.sendJsonCommand(cmd);
            } else {
                // iframe模式: 更新iframe src
                const url = `${this.apiBase}/api/html?txd=${encodeURIComponent(this.txd)}&cmd=${encodeURIComponent(cmd)}`;
                const iframe = this.$refs.gameFrame;
                if (iframe) {
                    this.frameLoading = true;
                    iframe.src = url;
                }
            }

            this.chatInput = '';
            this.showChatInput = false;
        },

        // 快捷命令
        sendQuickCommand(cmd) {
            if (!this.quickActionsCollapsed) {
                this.quickActionsCollapsed = true;
                localStorage.setItem('quickActionsCollapsed', '1');
            }
            // 点击快捷按钮时立即滚动到顶部
            window.scrollTo({ top: 0, behavior: 'smooth' });
            const mudContainer = document.querySelector('.mud-output-container');
            if (mudContainer) {
                mudContainer.scrollTop = 0;
            }

            // 记录最后执行的命令
            this.lastCommand = cmd;

            // JSON模式 (vue-ui-3): 直接渲染，无iframe
            if (this.useJsonMode) {
                this.sendJsonCommand(cmd);
            } else if (this.useAsyncMode) {
                // 异步iframe模式
                this.sendQuickCommandAsync(cmd);
            } else {
                // 同步iframe模式（原有方式）
                const url = `${this.apiBase}/api/html?txd=${encodeURIComponent(this.txd)}&cmd=${encodeURIComponent(cmd)}`;
                const iframe = this.$refs.gameFrame;
                if (iframe) {
                    this.frameLoading = true;
                    iframe.src = url;
                }
            }
        },

        // JSON模式: 发送命令并获取结构化数据
        async sendJsonCommand(cmd, isRetry = false) {
            const requestEpoch = this.characterSessionEpoch;
            const requestTxd = this.txd;
            if (!requestTxd) return;
            const isAutofightRefresh = cmd === 'flushview' &&
                this.playerStats && this.playerStats.autofight;
            const useSmoothOutputTransition = !isAutofightRefresh &&
                this.combatEffectsEnabled &&
                this.shouldAnimateMudOutputCommand(cmd);
            // 拦截复制邀请链接命令 - 直接在前端处理，不发送到服务器
            if (cmd && cmd.startsWith('copy_invite_url:')) {
                const url = cmd.substring('copy_invite_url:'.length);
                await this.copyToClipboard(decodeURIComponent(url), '邀请链接');
                return;  // 不发送到服务器
            }
            if (cmd && !isAutofightRefresh) {
                this.lastCommand = cmd;
            }
            if (!isAutofightRefresh) {
                this.clearUiToast();
            }

            // 滚动到顶部（同时滚动window和MUD容器）
            if (!isAutofightRefresh) {
                window.scrollTo({ top: 0, behavior: 'smooth' });
                const mudContainer = document.querySelector('.mud-output-container');
                if (mudContainer) {
                    mudContainer.scrollTop = 0;
                }
            }

            // 清除之前的计时器
            if (!isAutofightRefresh && this.loadingTimer) {
                clearTimeout(this.loadingTimer);
            }

            if (!isAutofightRefresh) {
                this.mudLoading = true;
                this.smoothOutputLoading = useSmoothOutputTransition;
                this.slowLoadingTip = false;
            }

            // 3秒后显示慢速加载提示
            if (!isAutofightRefresh) {
                this.loadingTimer = setTimeout(() => {
                    if (this.isCharacterSessionCurrent(requestEpoch) &&
                        this.mudLoading) {
                        this.slowLoadingTip = true;
                    }
                }, 3000);
            }
            try {
                const url = `${this.apiBase}/api/json?txd=${encodeURIComponent(requestTxd)}&cmd=${encodeURIComponent(cmd)}`;

                const response = await fetch(url);
                if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                console.log('[sendJsonCommand] 响应状态:', response.status);

                const data = await response.json().catch(() => ({}));
                if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                if (response.status === 409 && data.forced_logout) {
                    this.handleForcedCharacterLogout(data);
                    return;
                }
                if (!response.ok) {
                    // 401 表示未授权（会话已过期），尝试重新登录并重试命令
                    if (response.status === 401 && !isRetry) {
                        console.log('[会话过期] 尝试重新登录并重试命令...');
                        await this.relogin(requestTxd, requestEpoch);
                        if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                        // 重新登录成功后重试原始命令
                        if (!this.showLogin) {
                            return this.sendJsonCommand(cmd, true);
                        }
                    }
                    throw new Error(data.error || `HTTP ${response.status}`);
                }

                if (data.error) {
                    console.error('命令执行错误:', data.error);
                    // 如果是认证错误，尝试重新登录并重试命令
                    if ((data.error.includes('认证') || data.error.includes('登录') || data.error.includes('未登录')) && !isRetry) {
                        console.log('[会话过期] 尝试重新登录并重试命令...');
                        await this.relogin(requestTxd, requestEpoch);
                        if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                        // 重新登录成功后重试原始命令
                        if (!this.showLogin) {
                            return this.sendJsonCommand(cmd, true);
                        }
                    }
                    this.showUiToast(data.error || '命令执行失败，请稍后重试', 'error');
                    return;
                }
                const requestCredentials = this.decodeCredentialsFromTxd(requestTxd);
                if (data.userid && requestCredentials &&
                    data.userid !== requestCredentials.userid) {
                    throw new Error('人物会话响应不匹配');
                }
                // 更新txd（可能已变化）
                if (data.txd) {
                    this.txd = data.txd;
                    this.saveTabSession();
                }
                // 保存userid到sessionStorage（用于URL登录后保存用户信息）
                if (data.userid && !(this.loadTabSession()||{}).userid) {
                    const partitionMatch = data.userid.match(/^([a-z]+\d+)/);
                    if (partitionMatch) {
                        const partition = partitionMatch[1];
                        const userid = data.userid.substring(partition.length);


                        this.loginForm.partition = partition;
                        this.loginForm.userid = userid;
                        console.log('[sendJsonCommand] 已保存用户信息到sessionStorage:', partition, userid);
                    }
                }
                // 更新MUD输出；只在背包/任务/技能等列表页启用平滑重排。
                this.prepareMudOutputAnimation(cmd);
                this.mudLines = data.lines || [];
                console.log('[sendJsonCommand] mudLines数量:', this.mudLines.length);
                this.handleNewbieCompletions(data.newbie_completions || []);
                this.handleNarrativeEffects(data.lines || []);

                // 处理复制指令（从后端返回的copy字段）
                if (data.copy && data.copy.data) {
                    const copyData = data.copy;
                    const label = copyData.type === 'code' ? '邀请码' : '邀请链接';
                    await this.copyToClipboard(copyData.data, label);
                }

                // 挂机响应已携带同一 Backend 时刻的战斗快照，不再紧接着
                // 追加一次 /api/battle_status；普通命令仍按原流程检测。
                if (isAutofightRefresh && data.refresh) {
                    this.applyBattleStatusData(data.refresh, true);
                } else {
                    await this.checkBattleStatus(isAutofightRefresh);
                }
                // 解析战斗动作并生成动画
                this.parseBattleActions(data.lines || []);

                // 检测并处理复制命令（从lines中检测，兼容旧方式）
                this.handleCopyCommands(data.lines || []);

                // 处理邀请链接占位符 - 动态生成URL
                this.processInviteLinkPlaceholder();
            } catch (e) {
                if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                console.error('JSON命令执行失败:', e);
                // 网络错误也尝试重新登录并重试
                if ((e.message.includes('401') || e.message.includes('Unauthorized')) && !isRetry) {
                    console.log('[会话过期] 尝试重新登录并重试命令...');
                    await this.relogin(requestTxd, requestEpoch);
                    if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                    // 重新登录成功后重试原始命令
                    if (!this.showLogin) {
                        return this.sendJsonCommand(cmd, true);
                    }
                }
                this.showUiToast('连接暂时中断，请检查网络后重试', 'error');
            } finally {
                if (!isAutofightRefresh &&
                    this.isCharacterSessionCurrent(requestEpoch)) {
                    this.mudLoading = false;
                    this.smoothOutputLoading = false;
                    this.slowLoadingTip = false;
                    if (this.loadingTimer) {
                        clearTimeout(this.loadingTimer);
                        this.loadingTimer = null;
                    }
                }
            }
        },

        handleNewbieCompletions(completions) {
            if (!Array.isArray(completions) || completions.length === 0) {
                return;
            }
            const validCompletions = completions.filter(item =>
                item && (item.code === 2 || item.code === 4) &&
                Number.isFinite(Number(item.step))
            );
            if (validCompletions.length === 0) {
                return;
            }
            this.newbieCompletionQueue.push(...validCompletions);
            this.showNextNewbieCompletion();
        },

        showNextNewbieCompletion() {
            if (this.activeNewbieCompletion ||
                this.newbieCompletionQueue.length === 0) {
                return;
            }
            this.activeNewbieCompletion = this.newbieCompletionQueue.shift();
            if (this.activeNewbieCompletion?.code === 2) {
                const kind = this.activeNewbieCompletion.complete
                    ? 'tutorialComplete'
                    : 'quest';
                const signature = [
                    this.activeNewbieCompletion.step,
                    this.activeNewbieCompletion.title,
                    this.activeNewbieCompletion.reward
                ].join(':');
                this.triggerGameFeedback(kind, signature);
            }
        },

        dismissNewbieCompletions() {
            this.activeNewbieCompletion = null;
            this.newbieCompletionQueue = [];
        },

        continueNewbieGuide() {
            const completion = this.activeNewbieCompletion;
            if (!completion) {
                return;
            }
            this.activeNewbieCompletion = null;
            if (this.newbieCompletionQueue.length > 0) {
                this.$nextTick(() => this.showNextNewbieCompletion());
                return;
            }
            const command = completion.code === 4
                ? 'inventory'
                : (completion.next_action_command || 'newbie_guide');
            if (command) {
                this.sendJsonCommand(command);
            }
        },

        getNewbieCompletionPrimaryLabel() {
            if (!this.activeNewbieCompletion) {
                return '继续';
            }
            if (this.newbieCompletionQueue.length > 0) {
                return '查看下一项完成结果';
            }
            if (this.activeNewbieCompletion.code === 4) {
                return '整理背包';
            }
            return this.activeNewbieCompletion.next_action_label ||
                (this.activeNewbieCompletion.complete
                    ? '查看职业成长路线'
                    : '开始下一步');
        },

        // JSON模式: 获取按钮样式类名
        getButtonClass(label) {
            if (label.includes('东→') || label.includes('西←') ||
                label.includes('南↓') || label.includes('北↑')) {
                return 'btn btn-outline-success btn-sm';
            } else if (label.includes('杀戮') || label.includes('商城') ||
                       label.includes('锻造')) {
                return 'btn btn-outline-warning btn-sm';
            } else if (label.includes('吃药')) {
                return 'btn btn-outline-purple btn-sm';
            }
            return 'btn btn-outline-info btn-sm';
        },

		// 装备名称常携带服务端稀有度色码。只标记装备相关命令，
		// 避免为了修复浅黄底黄字而改变商城、活动等其他金色按钮。
		isEquipmentButtonCommand(command) {
			const name = String(command || '').trim().split(/\s+/)[0];
			return [
				'inv', 'inv_other', 'equipment', 'wear', 'wield',
				'unwear', 'unwield', 'auto_equip', 'convert_equip_detail'
			].includes(name);
		},

        // JSON模式: 获取颜色样式类名
        getColorClass(colorCode) {
            const colorMap = {
                0x30: 'color-black',
                0x31: 'color-red-bold',
                0x32: 'color-green-bold',
                0x33: 'color-blue-bold',
                0x34: 'color-cyan-bold',
                0x35: 'color-purple-bold',
                0x36: 'color-orange-bold',
                0x37: 'color-gray',
                0x38: 'color-dark-gray',
                0x39: 'color-light-gray',
                0x67: 'color-gold'
            };
            return colorMap[colorCode] || '';
        },

        // JSON模式: 渲染文本部分（处理颜色和图片）
        renderTextParts(parts) {
            if (!parts) return '';
            let html = '';
            let inSpan = false;

            for (const part of parts) {
                if (part.type === 'color-start') {
                    if (inSpan) html += '</span>';
                    html += `<span class="${part.class}">`;
                    inSpan = true;
                } else if (part.type === 'color-end') {
                    if (inSpan) {
                        html += '</span>';
                        inSpan = false;
                    }
                } else if (part.type === 'text') {
                    // 先统一缩写展示数值，再解析 [imgurl picture:...] 图片。
                    html += this.parseInlineImages(this.renderGameText(part.content, true));
                }
            }
            if (inSpan) html += '</span>';
            return html;
        },

        // 解析文本中的内联图片 [imgurl picture:/images/...]
        parseInlineImages(text) {
            if (!text) return '';
            // 匹配 [imgurl picture:路径] 格式
            return text.replace(/\[imgurl\s+picture:([^\]]+)\]/g, (match, imagePath) => {
                // 构建完整图片URL
                const imageUrl = this.getImageUrl(imagePath);
                return `<img src="${imageUrl}" class="mud-inline-image" alt="图片" onerror="this.style.display='none'">`;
            });
        },

        // 获取图片的完整URL
        getImageUrl(imagePath) {
            // imagePath 格式: /images/user/0_100.gif 或 /xd/images/...
            // 使用与当前页面相同的协议和主机名
            const protocol = window.location.protocol;
            const hostname = window.location.hostname;
            // HTTPS 时使用主域名，HTTP 时使用带端口的地址
            // 注意：图片在Tomcat下(8080端口)，不是Pike HTTP API(8888端口)
            let baseUrl;
            if (protocol === 'https:') {
                baseUrl = protocol + '//' + hostname;
            } else {
                // 内网访问，需要判断是localhost还是其他
                if (hostname === 'localhost' || hostname === '127.0.0.1') {
                    baseUrl = protocol + '//localhost:8080';
                } else {
                    baseUrl = protocol + '//' + hostname + ':8080';
                }
            }
            return baseUrl + imagePath;
        },

        handlePlayerAvatarError() {
            this.playerAvatarFailed = true;
        },

        // 解析聊天消息中的链接 [label:command argument]
        parseChatLinks(text) {
            if (!text) return '';
            // 匹配 [label:command argument] 格式
            // command 后面可能有空格和参数
            const source = String(text);
            const pattern = /\[([^\]]+?):([^\]]+?)\s+([^\]]+)\]/g;
            let html = '';
            let lastIndex = 0;
            let match;
            while ((match = pattern.exec(source)) !== null) {
                html += this.renderGameText(source.slice(lastIndex, match.index));
                const commandValue = `${match[2]} ${match[3]}`
                    .replace(/&/g, '&amp;')
                    .replace(/"/g, '&quot;')
                    .replace(/</g, '&lt;')
                    .replace(/>/g, '&gt;');
                html += `<span class="chat-link" data-command="${commandValue}" onclick="handleChatLinkClick(this)">${this.renderGameText(match[1])}</span>`;
                lastIndex = match.index + match[0].length;
            }
            html += this.renderGameText(source.slice(lastIndex));
            return html;
        },

        // JSON模式: 提交输入框
        submitInput(name, event) {
            let inputValue = '';
            // 如果是输入框的回车事件
            if (event.target && event.target.tagName === 'INPUT') {
                inputValue = event.target.value || '';
            } else {
                // 如果是确定按钮的点击事件，通过ref获取输入框的值
                const refName = 'input-' + name;
                const inputRef = this.$refs[refName];
                if (inputRef && inputRef.length) {
                    inputValue = inputRef[0].value || '';
                } else if (inputRef) {
                    inputValue = inputRef.value || '';
                }
            }
            const cmd = `${name} ${inputValue}`;
            this.sendJsonCommand(cmd);
        },

        // JSON模式: 提交命令输入框
        submitCmdInput(cmdName, event) {
            let inputValue = '';
            if (event.target && event.target.tagName === 'INPUT') {
                inputValue = event.target.value || '';
            } else {
                // 找到同组的输入框
                const input = event.target.parentElement.querySelector('input');
                inputValue = input ? input.value : '';
            }
            const cmd = `${cmdName} ${inputValue}`;
            this.sendJsonCommand(cmd);
        },

        submitCmdSelect(cmdName, event) {
            const value = event?.target?.value || '';
            if (!value) return;
            event.target.value = '';
            this.sendJsonCommand(`${cmdName} ${value}`);
        },

        // JSON模式: 提交表单（多个输入框共用一个提交按钮）
        submitForm(formSegment) {
            const inputs = formSegment.inputs || [];
            const cmd = formSegment.cmd;

            // 收集所有输入框的值
            let cmdWithArgs = cmd;
            for (const input of inputs) {
                const refName = 'input-' + input.name;
                const inputRef = this.$refs[refName];
                let value = '';
                if (inputRef && inputRef.length) {
                    value = inputRef[0].value || '';
                } else if (inputRef) {
                    value = inputRef.value || '';
                }
                // 将输入值追加到命令中，格式：cmd mb=xxx bp=yyy rp=zzz
                cmdWithArgs += ` ${input.name}=${value}`;
            }

            this.sendJsonCommand(cmdWithArgs);
        },

        // 退出登录
        doLogout() {
            this.invalidateCharacterSessionRequests();
            const accountToken = this.accountToken;
            if (accountToken) {
                this.postAccountApi('/api/account/logout', { token: accountToken })
                    .catch(() => {});
            }
            this.clearTabSession();



            this.clearAccountSession();
            this.txd = '';
            this.currentCharacterId = '';
            this.characterLoading = false;
            this.gameFrameUrl = '';
            this.playerStats = null;
            this.playerAvatarFailed = false;
            this.petAssistEventHistory = {};
            this.roomSkillEventHistory = {};
            this.loginPasswordVisible = false;
            this.clearUiToast();
            this.dismissNewbieCompletions();
            this.stopStatsUpdate();
            // 清理自动战斗定时器
            if (this.autofightInterval) {
                clearInterval(this.autofightInterval);
                this.autofightInterval = null;
            }
            this.autofightTickInFlight = false;
            this.isInBattle = false;
            this.battleEnemy = null;
            this.battleEnemyFull = null;
            this.battlePlayerFull = null;
            this.clearBattleAoeReport();
            this.battleAnimations = [];
            this.skillAnimations = [];
            this.battleStatusLoading = false;
            this.stopBattleStatusPolling();
            // 清理聊天轮询定时器
            this.stopChatPolling();
            this.showCharacterSelect = false;
            this.characterSelectCanCancel = false;
            this.showLogin = true;
        },

        // 自动重新登录（当会话过期时）
        async relogin(
            expectedTxd = this.txd || (this.loadTabSession()||{}).txd,
            expectedEpoch = this.characterSessionEpoch
        ) {
            let savedPartition = (this.loadTabSession()||{}).partition || '';
            let savedUser = (this.loadTabSession()||{}).userid || '';
            const savedTxd = expectedTxd;
            const credentials = this.decodeCredentialsFromTxd(savedTxd);
            let fullUserid = '';
            let password = '';

            if (credentials) {
                fullUserid = credentials.userid;
                password = credentials.password;
                const useridMatch = fullUserid.match(/^([a-z]+\d+)(.+)$/i);
                if (useridMatch) {
                    savedPartition = useridMatch[1];
                    savedUser = useridMatch[2];
                }
            } else if (savedPartition && savedUser) {
                fullUserid = savedPartition + savedUser;
                password = this.decodePasswordFromTxd(savedTxd);
            }

            if (!savedTxd || !fullUserid || !password) {
                // 没有保存的登录信息，显示登录界面
                if (this.isCharacterSessionCurrent(expectedEpoch))
                    this.showLogin = true;
                return false;
            }

            try {
                // 使用明文密码（不再使用challenge哈希）
                const plainPassword = password;

                // 发送登录请求
                const params = new URLSearchParams({
                    userid: fullUserid,
                    password: plainPassword,
                    cmd: 'init'
                });

                const response = await fetch(this.apiBase + '/api/json?' + params.toString());
                if (!this.isCharacterSessionCurrent(expectedEpoch)) return false;
                const data = await response.json().catch(() => ({}));
                if (!this.isCharacterSessionCurrent(expectedEpoch)) return false;
                if (response.status === 409 && data.forced_logout) {
                    this.handleForcedCharacterLogout(data);
                    return false;
                }
                if (!response.ok) {
                    throw new Error(data.error ||
                        ('登录失败: HTTP ' + response.status));
                }
                if (data.error) {
                    throw new Error(data.error);
                }
                if (data.userid && data.userid !== fullUserid) {
                    throw new Error('人物会话响应不匹配');
                }

                // 重新登录成功
                this.txd = data.txd || this.encodeTxd(fullUserid, password);
                this.saveTabSession();



                // 更新 MUD 输出
                this.mudLines = data.lines || [];
                this.handleNewbieCompletions(
                    data.newbie_completions || []
                );
                this.showLogin = false;
                this.scheduleAutoAnimateInitialization();

                console.log('[重新登录] 成功');
                return true;
            } catch (e) {
                if (!this.isCharacterSessionCurrent(expectedEpoch)) return false;
                console.error('[重新登录] 失败:', e);
                // 重新登录失败，显示登录界面
                this.dismissNewbieCompletions();
                this.showLogin = true;
                this.loginForm.partition = savedPartition;
                this.loginForm.userid = savedUser;
                return false;
            }
        },

        // 从 txd 解码账号和密码（encodeTxd 的逆操作）
        decodeCredentialsFromTxd(txd) {
            try {
                if (!txd) return null;
                const parts = txd.split('~');
                if (parts.length !== 2) return null;

                const encodedUserid = parts[0]
                    .replace(/%7B/gi, '{')
                    .replace(/%7C/gi, '|');
                const encodedPassword = parts[1]
                    .replace(/%7B/gi, '{')
                    .replace(/%7C/gi, '|');
                let userid = '';
                let password = '';

                for (let i = 0; i < encodedUserid.length; i++) {
                    const code = encodedUserid.charCodeAt(i);
                    if (Math.floor(i / 2) === 0) {
                        userid += String.fromCharCode(code - 2);
                    } else {
                        userid += String.fromCharCode(code - 1);
                    }
                }

                for (let i = 0; i < encodedPassword.length; i++) {
                    const code = encodedPassword.charCodeAt(i);
                    if (Math.floor(i / 2) === 0) {
                        password += String.fromCharCode(code - 1);
                    } else {
                        password += String.fromCharCode(code - 2);
                    }
                }

                return { userid, password };
            } catch (e) {
                console.error('解码登录信息失败:', e);
                return null;
            }
        },

        // 保留旧调用接口
        decodePasswordFromTxd(txd) {
            const credentials = this.decodeCredentialsFromTxd(txd);
            return credentials ? credentials.password : null;
        },

        // 返回界面选择
        goToSelection() {
            if (confirm('返回界面选择？')) {
                this.clearTabSession();
    
    
                localStorage.removeItem('mud_ui_choice');
                localStorage.removeItem('mud_ui_choice_time');
                window.location.href = '../pc.jsp?ui=back';
            }
        },

        // 切换头部菜单
        toggleHeaderMenu() {
            this.headerMenuOpen = !this.headerMenuOpen;
            // 如果菜单打开了，且当前不是简体中文，需要重新翻译菜单
            if (this.headerMenuOpen && typeof translate !== 'undefined') {
                this.$nextTick(() => {
                    const currentLang = translate.language.getCurrent();
                    if (currentLang !== 'chinese_simplified') {
                        translate.execute();
                    }
                });
            }
        },

        // 切换主题
        toggleTheme() {
            // 三种主题循环：classic → dark → light → classic
            if (this.theme === 'classic') {
                this.theme = 'dark';
            } else if (this.theme === 'dark') {
                this.theme = 'light';
            } else {
                this.theme = 'classic';
            }
            localStorage.setItem('mud_theme', this.theme);
            this.applyTheme();
            // 刷新iframe以应用新主题
            if (this.txd && this.gameFrameUrl) {
                this.refreshFrame();
            }
        },

        // 应用主题到body
        applyTheme() {
            document.body.setAttribute('data-theme', this.theme);
        },

        // 调整游戏内容字号并持久保存
        changeFontSize(event) {
            const requestedSize = event && event.target
                ? event.target.value
                : this.fontSize;
            this.fontSize = requestedSize;
            this.applyFontSize();
            localStorage.setItem('mud_font_size', this.fontSize);
            const labels = {
                small: '小',
                normal: '标准',
                large: '大',
                xlarge: '特大'
            };
            this.showUiToast(`游戏字号已调整为${labels[this.fontSize]}`, 'info');
        },

        // 应用字号；异常或旧版本残留值统一回退到新的小字号默认值
        applyFontSize() {
            const supportedSizes = ['small', 'normal', 'large', 'xlarge'];
            if (!supportedSizes.includes(this.fontSize)) {
                this.fontSize = 'small';
            }
            document.documentElement.setAttribute('data-font-size', this.fontSize);
        },

        // 获取玩家状态
        applyPlayerStatsData(data) {
            if (!data || data.error) return;
            const wasAutofight = this.playerStats && this.playerStats.autofight;
            const previousAvatar = this.playerStats && this.playerStats.avatar;
            const previousPet = this.playerStats && this.playerStats.pet_assist;
            const previousLevel = Number(this.playerStats?.level);
            this.handlePetLevelChange(previousPet, data.pet_assist);
            this.syncRoomSkillManifestations(data.room_skill_events);
            this.playerStats = data;
            this.maybePromptCharacterProfile(data);
            this.syncTimedEventInvite(data.timed_event);
            this.syncBattleAoeReport(data.recent_aoe_report);
            const currentLevel = Number(data.level);
            if (Number.isFinite(previousLevel) &&
                Number.isFinite(currentLevel) && currentLevel > previousLevel) {
                this.triggerGameFeedback(
                    'level', `${previousLevel}->${currentLevel}`
                );
                this.showUiToast(
                    currentLevel > 120
                        ? `破境成功，人物提升至 ${currentLevel} 级！`
                        : `升级成功，人物提升至 ${currentLevel} 级！`,
                    'info'
                );
            }
            this.scheduleAutoAnimateInitialization();
            this.promptUiTourOnce();
            const pendingTeamInvite = data.team_invite;
            if (!this.teamInviteBusy && pendingTeamInvite &&
                pendingTeamInvite.pending) {
                this.teamInvite = pendingTeamInvite;
            } else if (!this.teamInviteBusy &&
                       (!pendingTeamInvite || !pendingTeamInvite.pending)) {
                this.teamInvite = null;
            }
            if (previousAvatar !== data.avatar) {
                this.playerAvatarFailed = false;
            }
            const isAutofight = this.playerStats && this.playerStats.autofight;
            if (wasAutofight && !isAutofight) {
                this.checkAutofight();
            } else if (!wasAutofight && isAutofight) {
                this.checkAutofight();
            }
        },

        async fetchPlayerStats() {
            if (!this.txd) return;
            const requestEpoch = this.characterSessionEpoch;
            const requestTxd = this.txd;

            try {
                const response = await fetch(`${this.apiBase}/api/status?txd=${encodeURIComponent(requestTxd)}`);
                if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                const data = await response.json().catch(() => ({}));
                if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                if (response.status === 409 && data.forced_logout) {
                    this.handleForcedCharacterLogout(data);
                    return;
                }
                if (response.ok) {
                    this.applyPlayerStatsData(data);
                }
            } catch (e) {
                console.error('获取玩家状态失败:', e);
                // 网络错误时，不清除 autofight 定时器，保持当前状态
            }
        },

        // 开始定时更新玩家状态
        startStatsUpdate() {
            this.stopStatsUpdate();
            this.fetchPlayerStats();
            // 挂机画面已携带完整人物状态，避免同一玩家再发重复/status。
            this.statsInterval = setInterval(() => {
                if (!this.playerStats?.autofight) {
                    this.fetchPlayerStats();
                }
            }, 2000);
        },

        // 停止定时更新
        stopStatsUpdate() {
            if (this.statsInterval) {
                clearInterval(this.statsInterval);
                this.statsInterval = null;
            }
        },

        // 切换自动战斗
        async toggleAutofight() {
            if (!this.txd) return;
            const requestEpoch = this.characterSessionEpoch;
            const requestTxd = this.txd;

            try {
                const response = await fetch(`${this.apiBase}/api/autofight`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded',
                    },
                    body: new URLSearchParams({
                        txd: requestTxd,
                        action: 'toggle'
                    })
                });

                if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                if (response.ok) {
                    const data = await response.json();
                    if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                    // 刷新状态
                    await this.fetchPlayerStats();
                    // 显示提示
                    const quotaAction = data.quota_exhausted ? {
                        label: data.upgrade_label ||
                            (data.can_upgrade_vip ? '提高VIP' : '查看权益'),
                        command: data.upgrade_command ||
                            (data.can_upgrade_vip ? 'vip_service_list' : 'autofight vip')
                    } : null;
                    this.showUiToast(
                        data.message || '自动挂机状态已切换',
                        data.autofight ? 'success' : 'info',
                        quotaAction
                    );
                } else {
                    const data = await response.json().catch(() => ({}));
                    this.showUiToast(data.error || '切换自动挂机失败', 'error');
                }
            } catch (e) {
                console.error('切换自动战斗失败:', e);
                this.showUiToast('切换自动挂机失败: ' + e.message, 'error');
            }
        },

        async runAutofightTick() {
            // 服务端统一推进原有 flushview；浏览器只拉取画面快照。
            // 标签隐藏/最小化只暂停渲染，不会暂停挂机。
            if (!this.txd || this.showLogin || this.showCharacterSelect ||
                this.autofightTickInFlight) return;
            if (typeof document !== 'undefined' && document.hidden) return;
            if (this.useJsonMode && this.mudLoading) return;
            const requestEpoch = this.characterSessionEpoch;
            const requestTxd = this.txd;
            this.autofightTickInFlight = true;
            try {
                const params = new URLSearchParams({
                    txd: requestTxd,
                    after: String(this.autofightViewSequence || 0),
                    generation: this.autofightViewGeneration || ''
                });
                const response = await fetch(
                    `${this.apiBase}/api/autofight_view?${params.toString()}`
                );
                if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                const data = await response.json().catch(() => ({}));
                if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                if (response.status === 409 && data.forced_logout) {
                    this.handleForcedCharacterLogout(data);
                    return;
                }
                if (!response.ok || data.error) return;
                if (data.refresh) {
                    if (data.refresh.player) {
                        this.applyPlayerStatsData(data.refresh.player);
                    }
                    this.applyBattleStatusData(data.refresh, true);
                }
                const generation = String(data.generation || '');
                if (data.unchanged) {
                    if (generation &&
                        generation !== this.autofightViewGeneration) {
                        this.autofightViewGeneration = generation;
                        this.autofightViewSequence = 0;
                    }
                    return;
                }
                const requestCredentials = this.decodeCredentialsFromTxd(requestTxd);
                if (data.userid && requestCredentials &&
                    data.userid !== requestCredentials.userid) return;
                const sequence = Number(data.sequence || 0);
                if (!Number.isFinite(sequence) || !generation ||
                    (generation === this.autofightViewGeneration &&
                    sequence <= this.autofightViewSequence)) return;
                this.autofightViewGeneration = generation;
                this.autofightViewSequence = sequence;
                const lines = Array.isArray(data.lines) ? data.lines : [];
                this.prepareMudOutputAnimation('flushview');
                this.mudLines = lines;
                this.handleNarrativeEffects(lines);
                this.parseBattleActions(lines);
                this.handleCopyCommands(lines);
                this.processInviteLinkPlaceholder();
            } catch (e) {
                if (this.isCharacterSessionCurrent(requestEpoch))
                    console.error('[挂机画面] 同步失败:', e);
            } finally {
                if (this.isCharacterSessionCurrent(requestEpoch))
                    this.autofightTickInFlight = false;
            }
        },

        // 检查并启动/停止自动战斗
        checkAutofight() {
            if (this.playerStats && this.playerStats.autofight) {
                // 服务端推进战斗；前台每秒同步一次只读画面。
                this.stopBattleStatusPolling();
                if (!this.autofightInterval) {
                    this.autofightInterval = setInterval(() => {
                        this.runAutofightTick();
                    }, 1000);
                    this.runAutofightTick();
                }
            } else {
                // 关闭自动战斗
                if (this.autofightInterval) {
                    clearInterval(this.autofightInterval);
                    this.autofightInterval = null;
                }
                this.autofightTickInFlight = false;
                // 挂机关闭后若仍在战斗，恢复普通战斗状态轮询。
                if (this.isInBattle && !this.battleStatusInterval) {
                    this.startBattleStatusPolling();
                }
            }
        },

        // ====================================================================
        // 异步命令执行 (使用请求队列，防止并发导致状态不一致)
        // ====================================================================

        /**
         * 异步发送命令（使用队列模式）
         * 优点：同一用户的请求串行执行，防止并发导致状态不一致
         * @param {string} cmd 要执行的命令
         * @param {number} timeout 超时时间(ms)，默认5000
         * @param {boolean} isRetry 是否为重试（防止无限循环）
         * @returns {Promise<string>} 返回HTML结果
         */
        async sendAsyncCommand(cmd, timeout = 5000, isRetry = false) {
            if (!this.txd) {
                throw new Error('未登录');
            }
            const requestEpoch = this.characterSessionEpoch;
            const requestTxd = this.txd;

            try {
                // 1. 发送异步请求
                const asyncResp = await fetch(`${this.apiBase}/api/async`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    body: new URLSearchParams({
                        txd: requestTxd,
                        cmd: cmd
                    })
                });
                if (!this.isCharacterSessionCurrent(requestEpoch))
                    throw new Error('人物会话已切换');

                if (!asyncResp.ok) {
                    // 401 会话过期，尝试重新登录并重试
                    if (asyncResp.status === 401 && !isRetry) {
                        console.log('[Async] 会话过期，尝试重新登录并重试...');
                        await this.relogin(requestTxd, requestEpoch);
                        if (!this.isCharacterSessionCurrent(requestEpoch))
                            throw new Error('人物会话已切换');
                        if (!this.showLogin) {
                            return this.sendAsyncCommand(cmd, timeout, true);
                        }
                    }
                    throw new Error(`API错误: ${asyncResp.status}`);
                }

                const asyncData = await asyncResp.json();
                if (!this.isCharacterSessionCurrent(requestEpoch))
                    throw new Error('人物会话已切换');

                if (asyncData.error) {
                    // 认证错误，尝试重新登录并重试
                    if ((asyncData.error.includes('认证') || asyncData.error.includes('登录') || asyncData.error.includes('未登录')) && !isRetry) {
                        console.log('[Async] 会话过期，尝试重新登录并重试...');
                        await this.relogin(requestTxd, requestEpoch);
                        if (!this.isCharacterSessionCurrent(requestEpoch))
                            throw new Error('人物会话已切换');
                        if (!this.showLogin) {
                            return this.sendAsyncCommand(cmd, timeout, true);
                        }
                    }
                    throw new Error(asyncData.error);
                }

                const requestId = asyncData.request_id;
                if (!requestId) {
                    throw new Error('未获得request_id');
                }

                console.log(`[Async] 命令已入队，队列位置: ${asyncData.queue_position}`);

                // 2. 轮询结果
                const startTime = Date.now();
                while (Date.now() - startTime < timeout) {
                    await new Promise(resolve => setTimeout(resolve, 100)); // 100ms轮询间隔
                    if (!this.isCharacterSessionCurrent(requestEpoch))
                        throw new Error('人物会话已切换');

                    const resultResp = await fetch(`${this.apiBase}/api/result?request_id=${encodeURIComponent(requestId)}&txd=${encodeURIComponent(requestTxd)}`);
                    if (!this.isCharacterSessionCurrent(requestEpoch))
                        throw new Error('人物会话已切换');

                    if (!resultResp.ok) {
                        // 401 会话过期，尝试重新登录并重试
                        if (resultResp.status === 401 && !isRetry) {
                            console.log('[Async] 会话过期，尝试重新登录并重试...');
                            await this.relogin(requestTxd, requestEpoch);
                            if (!this.isCharacterSessionCurrent(requestEpoch))
                                throw new Error('人物会话已切换');
                            if (!this.showLogin) {
                                return this.sendAsyncCommand(cmd, timeout, true);
                            }
                        }
                        throw new Error(`Result API错误: ${resultResp.status}`);
                    }

                    const contentType = resultResp.headers.get('content-type');
                    if (contentType && contentType.includes('application/json')) {
                        // JSON响应 - 还在处理中
                        const resultData = await resultResp.json();
                        if (resultData.status === 'pending') {
                            continue; // 继续轮询
                        }
                        if (resultData.error) {
                            // 认证错误，尝试重新登录并重试
                            if ((resultData.error.includes('认证') || resultData.error.includes('登录') || resultData.error.includes('未登录')) && !isRetry) {
                                console.log('[Async] 会话过期，尝试重新登录并重试...');
                                await this.relogin(requestTxd, requestEpoch);
                                if (!this.isCharacterSessionCurrent(requestEpoch))
                                    throw new Error('人物会话已切换');
                                if (!this.showLogin) {
                                    return this.sendAsyncCommand(cmd, timeout, true);
                                }
                            }
                            throw new Error(resultData.error);
                        }
                    } else if (contentType && contentType.includes('text/html')) {
                        // HTML响应 - 完成
                        const html = await resultResp.text();
                        console.log(`[Async] 命令完成，耗时: ${Date.now() - startTime}ms`);
                        return html;
                    }
                }

                throw new Error('请求超时');

            } catch (e) {
                console.error(`[Async] 命令失败: ${cmd}`, e);
                throw e;
            }
        },

        /**
         * 使用异步模式发送快捷命令
         * 相比直接更新iframe.src，这种方式不会导致页面闪烁
         */
        async sendQuickCommandAsync(cmd) {
            this.lastCommand = cmd;
            this.frameLoading = true;

            try {
                const html = await this.sendAsyncCommand(cmd);
                // 更新iframe内容
                const iframe = this.$refs.gameFrame;
                if (iframe && iframe.contentWindow) {
                    iframe.contentWindow.document.open();
                    iframe.contentWindow.document.write(html);
                    iframe.contentWindow.document.close();
                }
            } catch (e) {
                console.error('异步命令执行失败:', e);
                // 降级到同步模式
                const url = `${this.apiBase}/api/html?txd=${encodeURIComponent(this.txd)}&cmd=${encodeURIComponent(cmd)}`;
                const iframe = this.$refs.gameFrame;
                if (iframe) {
                    iframe.src = url;
                }
            } finally {
                this.frameLoading = false;
            }
        },

        /**
         * 使用异步模式发送命令输入
         */
        async sendCommandAsync() {
            const cmd = this.commandInput.trim();
            if (!cmd) return;

            this.lastCommand = cmd;
            this.commandInput = '';
            this.showCommandInput = false;
            this.frameLoading = true;

            try {
                const html = await this.sendAsyncCommand(cmd);
                // 更新iframe内容
                const iframe = this.$refs.gameFrame;
                if (iframe && iframe.contentWindow) {
                    iframe.contentWindow.document.open();
                    iframe.contentWindow.document.write(html);
                    iframe.contentWindow.document.close();
                }
            } catch (e) {
                console.error('异步命令执行失败:', e);
                // 降级到同步模式
                const url = `${this.apiBase}/api/html?txd=${encodeURIComponent(this.txd)}&cmd=${encodeURIComponent(cmd)}`;
                const iframe = this.$refs.gameFrame;
                if (iframe) {
                    iframe.src = url;
                }
            } finally {
                this.frameLoading = false;
            }
        },

        // ==================== 战斗系统方法 ====================

        /**
         * 检测是否处于战斗状态
         * 文本按钮只负责触发查询，最终状态以 /api/battle_status 为准。
         * 自动挂机的 flushview 即使没有旧式战斗按钮，也必须主动查询。
         */
        async checkBattleStatus(forceApiCheck = false) {
            const hasBattleSignal = this.mudLines.some(line =>
                line.segments && line.segments.some(seg =>
                    seg.type === 'button' && (
                        seg.label === '察看战况' ||
                        seg.label.includes('关闭自动战斗') ||
                        seg.label.includes('关闭自动挂机') ||
                        seg.cmd === 'autofightclose'
                    )
                )
            );

            if (forceApiCheck || hasBattleSignal || this.isInBattle) {
                await this.fetchBattleStatus();
            }
        },

        /**
         * 启动战斗状态轮询
         */
        startBattleStatusPolling() {
            this.stopBattleStatusPolling();
            // 每1秒轮询一次战斗状态
            this.battleStatusInterval = setInterval(() => {
                this.fetchBattleStatus();
            }, 1000);
        },

        /**
         * 停止战斗状态轮询
         */
        stopBattleStatusPolling() {
            if (this.battleStatusInterval) {
                clearInterval(this.battleStatusInterval);
                this.battleStatusInterval = null;
            }
        },

        clearBattleAoeReport() {
            if (this.battleAoeReportTimer) {
                clearTimeout(this.battleAoeReportTimer);
                this.battleAoeReportTimer = null;
            }
            this.battleAoeReport = null;
        },

        syncBattleAoeReport(report) {
            const targets = Array.isArray(report?.targets) ? report.targets : [];
            const remaining = Math.max(0, Number(report?.remaining || 0));
            if (!targets.length || remaining <= 0) {
                this.clearBattleAoeReport();
                return;
            }
            if (this.battleAoeReportTimer) {
                clearTimeout(this.battleAoeReportTimer);
            }
            this.battleAoeReport = {
                skill: report.skill || '',
                skillName: report.skill_name || '群体技能',
                targets: targets.map(target => ({
                    name: target.name_cn || target.name || '未知目标',
                    hp: Number(target.hp || 0),
                    hpMax: Number(target.hp_max || 0),
                    damage: Number(target.damage || 0),
                    hit: Number(target.hit || 0) === 1,
                    defeated: Number(target.defeated || 0) === 1,
                    revived: Number(target.revived || 0) === 1
                }))
            };
            this.battleAoeReportTimer = setTimeout(() => {
                this.battleAoeReport = null;
                this.battleAoeReportTimer = null;
            }, Math.ceil(remaining * 1000));
        },

        clearPetAssistEffect(clearEventId = false) {
            if (this.petAssistEffectTimer) {
                clearTimeout(this.petAssistEffectTimer);
                this.petAssistEffectTimer = null;
            }
            this.petAssistEffect = null;
            if (clearEventId) this.lastPetAssistEventId = '';
        },

        resetPetBattleVisualState() {
            this.clearPetAssistEffect(true);
            this.battlePet = null;
        },

        getPetFamilyClass(family) {
            const familyMap = {
                '火': 'fire', '水': 'water', '木': 'wood', '土': 'earth',
                '金': 'metal', '雷': 'lightning', '风': 'wind',
                '灵': 'spirit', '异': 'mystic'
            };
            return familyMap[String(family || '')] || 'spirit';
        },

        getPetAssistAnimationType(event) {
            const effectType = String(event?.type || '');
            if (effectType === 'heal' || effectType === 'revive') return 'heal';
            if (effectType === 'mofa') return 'spirit';
            const familyMap = {
                '火': 'fire', '水': 'ice', '木': 'heal', '土': 'block',
                '金': 'saber', '雷': 'lightning', '风': 'wind',
                '灵': 'spirit', '异': 'curse'
            };
            return familyMap[String(event?.family || '')] || 'generic';
        },

        getPetCooldownPercent(pet = this.battlePet) {
            const cooldown = Math.max(1, Number(pet?.cooldown || 0));
            const remaining = Math.max(0, Math.min(
                cooldown, Number(pet?.cooldown_remaining || 0)
            ));
            return Math.round(((cooldown - remaining) / cooldown) * 100);
        },

        getPetAssistStatus(pet = this.battlePet) {
            if (!pet?.active) return '未随行';
            const revive = pet.owner_revive || null;
            const reviveStatus = Number(revive?.enabled || 0) === 1 ?
                (Number(revive?.remaining || 0) > 0 ?
                    '回生羽可用' : '回生羽今日已用') : '';
            const withRevive = status => reviveStatus ?
                `${reviveStatus} · ${status}` : status;
            const waitingResource = String(pet.waiting_resource || '');
            if (waitingResource === 'life') {
                return withRevive('治疗灵技已就绪 · 等待生命缺口');
            }
            if (waitingResource === 'mofa') {
                return withRevive('灵息技能已就绪 · 等待法力缺口');
            }
            if (String(pet.combat_mode || '') === 'pvp') {
                const required = Math.max(1, Number(
                    pet.pvp_charge_required || pet.cooldown || 1
                ));
                const charge = Math.max(0, Math.min(
                    required, Number(pet.pvp_charge || 0)
                ));
                const maxUses = Math.max(1, Number(pet.pvp_uses_max || 2));
                const uses = Math.max(0, Math.min(
                    maxUses, Number(pet.pvp_uses || 0)
                ));
                if (uses >= maxUses) {
                    return withRevive(`本场御灵已尽 ${uses}/${maxUses}`);
                }
                return withRevive(`御灵充能 ${charge}/${required} · 本场 ${uses}/${maxUses}`);
            }
            const remaining = Math.max(0, Math.ceil(
                Number(pet.cooldown_remaining || 0)
            ));
            const role = String(pet.role || '');
            const roleStatus = {
                '守护': ['守护蓄势', '守护就绪'],
                '疗愈': ['疗愈蓄势', '疗愈就绪'],
                '灵息': ['凝聚灵息', '灵息就绪'],
                '强攻': ['攻势蓄力', '强攻就绪'],
                '迅捷': ['伺机协战', '迅捷就绪']
            }[role] || ['协战蓄势', '协战就绪'];
            return withRevive(remaining > 0 ?
                `${roleStatus[0]} ${remaining}秒` : roleStatus[1]);
        },

        getPetCultivationLabel(pet = this.battlePet) {
            if (!pet?.active) return '';
            const level = Math.max(1, Number(pet.level || 1));
            if (String(pet.system || '') === 'personal') {
                return `Lv.${level} · 本命契约`;
            }
            const star = Math.max(1, Number(pet.star || 1));
            const evolution = String(pet.evolution_name || '初生体');
            return `Lv.${level} · ${star}星${evolution}`;
        },

        getPetSlotTitle(slot) {
            if (!slot) return '';
            const personal = String(slot.system || '') === 'personal';
            const systemName = personal ? '本命灵伴' : '共享宠物';
            const destination = personal ? '本命灵伴界面' : '山海万灵谱';
            if (Number(slot.active || 0) !== 1) {
                return `${systemName}尚未契约，点击打开${destination}`;
            }
            const state = Number(slot.battle_active || 0) === 1 ?
                '当前出战' : '收藏待命';
            return `${systemName}·${slot.name} · ${this.getPetCultivationLabel(slot)} · ${state}，点击打开${destination}`;
        },

        getPetActualEffectMark(event) {
            const type = String(event?.type || '');
            if (type === 'revive') return '生';
            if (type === 'heal') return '愈';
            if (type === 'mofa') return '灵';
            if (type === 'damage') return '破';
            return '契';
        },

        getPetActualEffectDescription(event) {
            const type = String(event?.type || '');
            const amount = Math.max(0, Number(event?.amount || 0));
            const secondaryAmount = Math.max(0, Number(
                event?.secondary_amount || event?.restored || 0
            ));
            const secondaryType = String(event?.secondary_type || '');
            const amountText = this.formatGameNumber(amount);
            if (type === 'revive') {
                const mofaAmount = Math.max(0, Number(event?.mofa_amount || 0));
                return `回生已生效：生命 +${amountText} · 法力 +${this.formatGameNumber(mofaAmount)}`;
            }
            if (type === 'damage') {
                let text = `${String(event?.mode || '') === 'pvp' ? '御灵' : '协战'}伤害 -${amountText}`;
                if (secondaryAmount > 0) {
                    text += secondaryType === 'mofa' ?
                        ` · 同时法力 +${this.formatGameNumber(secondaryAmount)}` :
                        ` · 同时生命 +${this.formatGameNumber(secondaryAmount)}`;
                }
                const resonanceBonus = Math.max(0, Number(
                    event?.shared_resonance_bonus || 0
                ));
                if (resonanceBonus > 0) text += ` · 共享共鸣 +${resonanceBonus}%`;
                return text;
            }
            if (type === 'mofa') return `灵息回复已生效：法力 +${amountText}`;
            if (type === 'heal') return `守护治疗已生效：生命 +${amountText}`;
            return amount > 0 ? `灵宠效果已生效：+${amountText}` : '灵宠显化，等待生效条件';
        },

        formatPetAssistMessage(event) {
            const petName = String(event?.name || '灵宠');
            const skillName = String(event?.skill || '协战');
            const amount = Math.max(0, Number(event?.amount || 0));
            const type = String(event?.type || '');
            const observer = Boolean(event?.observer);
            const ownerPrefix = observer && event?.owner_name ?
                `${String(event.owner_name)}的` : '';
            const recipient = observer ? '主人' : '你';
            const prefix = String(event?.mode || '') === 'pvp' ?
                '【御灵交锋】' : '';
            const runes = Array.isArray(event?.runes) ?
                event.runes.filter(rune => String(rune || '').trim()) : [];
            const runeTrigger = Number(event?.rune_set_triggered || 0) === 1 &&
                runes.length === 3 ?
                `；${String(event?.rune_mode || '当前')}灵纹共鸣：${runes.join('·')}` +
                (event?.rune_effect ? `（${String(event.rune_effect)}）` : '') : '';
            if (type === 'revive') {
                const mofaAmount = Math.max(0, Number(event?.mofa_amount || 0));
                return `${prefix}${ownerPrefix}${event?.icon || '🐾'} ${petName}施展「${skillName}」，令主人死里回生，恢复${this.formatGameNumber(amount)}点生命与${this.formatGameNumber(mofaAmount)}点法力${runeTrigger}`;
            }
            if (amount <= 0) {
                return `${prefix}${ownerPrefix}${event?.icon || '🐾'} ${petName}施展「${skillName}」，守护在${recipient}身旁${runeTrigger}`;
            }
            if (type === 'damage') {
                const targetName = String(event?.target_name || '敌人');
                const secondaryAmount = Math.max(0, Number(
                    event?.secondary_amount || event?.restored || 0
                ));
                const secondary = secondaryAmount > 0 ?
                    (String(event?.secondary_type || '') === 'mofa' ?
                        `，同时恢复${this.formatGameNumber(secondaryAmount)}点法力` :
                        `，同时恢复${this.formatGameNumber(secondaryAmount)}点生命`) : '';
                return `${prefix}${ownerPrefix}${event?.icon || '🐾'} ${petName}施展「${skillName}」，对${targetName}造成${this.formatGameNumber(amount)}点${prefix ? '御灵' : '协战'}伤害${secondary}${runeTrigger}`;
            }
            if (type === 'mofa') {
                return `${prefix}${ownerPrefix}${event?.icon || '🐾'} ${petName}施展「${skillName}」，为${recipient}恢复${this.formatGameNumber(amount)}点法力${runeTrigger}`;
            }
            return `${prefix}${ownerPrefix}${event?.icon || '🐾'} ${petName}施展「${skillName}」，为${recipient}恢复${this.formatGameNumber(amount)}点生命${runeTrigger}`;
        },

        showPetAssistEffect(event, eventId = '', addToBattleLog = true) {
            const resolvedId = String(eventId || event?.id ||
                `room-pet-${Date.now()}-${Math.random()}`);
            if (!event || this.petAssistEventHistory[resolvedId]) return;
            const seenAt = Date.now();
            this.lastPetAssistEventId = resolvedId;
            this.petAssistEventHistory[resolvedId] = seenAt;
            for (const [seenId, timestamp] of Object.entries(
                this.petAssistEventHistory
            )) {
                if (seenAt - Number(timestamp) > 120000) {
                    delete this.petAssistEventHistory[seenId];
                }
            }

            const effect = {
                ...event,
                id: resolvedId,
                amount: Math.max(0, Number(event.amount || 0)),
                visualType: this.getPetAssistAnimationType(event),
                familyClass: this.getPetFamilyClass(event.family)
            };
            if (addToBattleLog) {
                this.addBattleLog('pet', this.formatPetAssistMessage(effect));
            }
            if (!this.combatEffectsEnabled) return;
            this.clearPetAssistEffect(false);
            this.petAssistEffect = effect;
            this.addSkillAnimation(
                effect.visualType,
                `${effect.name || '灵宠'}·${effect.skill || '协战'}`,
                effect.observer ? 'room' : (effect.type === 'damage' ? 'enemy' : 'player')
            );
            if (effect.amount > 0 && !effect.observer) {
                this.addBattleAnimation(
                    effect.type === 'damage' ? 'damage' : 'heal',
                    effect.type === 'damage' ? 'enemy' : 'player',
                    effect.amount
                );
                const secondaryAmount = Math.max(0, Number(
                    effect.secondary_amount || effect.restored || 0
                ));
                if (secondaryAmount > 0) {
                    this.addBattleAnimation(
                        'heal', 'player', secondaryAmount
                    );
                }
            }
            this.playGameSound('ui', 2200);
            this.petAssistEffectTimer = setTimeout(() => {
                this.petAssistEffect = null;
                this.petAssistEffectTimer = null;
            }, Number(effect.rune_set_triggered || 0) === 1 ||
                effect.type === 'revive' ? 3000 : 2400);
        },

        parseRoomPetManifestation(text) {
            const source = String(text || '').trim();
            const match = source.match(
                /^【灵宠显化】(.{1,24})的(.+?)施展「([^」]+)」(.+?)[。！!]?$/
            );
            if (!match) return null;
            const token = Array.from(String(match[2] || '🐾灵宠'));
            let icon = token.shift() || '🐾';
            if (token[0] === '\uFE0F') {
                icon += token.shift();
            }
            const detail = String(match[4] || '');
            const damage = detail.match(/对(.+?)造成(\d+)点(?:御灵|协战)伤害/);
            const mofa = detail.match(/恢复(\d+)点法力/);
            const life = detail.match(/恢复(\d+)点生命/);
            let type = 'guard';
            let amount = 0;
            if (damage) {
                type = 'damage';
                amount = Number(damage[2] || 0);
            } else if (/死亡前/.test(detail)) {
                type = 'revive';
                amount = Number(life?.[1] || 0);
            } else if (mofa) {
                type = 'mofa';
                amount = Number(mofa[1] || 0);
            } else if (life) {
                type = 'heal';
                amount = Number(life[1] || 0);
            }
            return {
                observer: true,
                owner_name: match[1],
                icon,
                name: token.join('') || '灵宠',
                skill: match[3],
                mode: /御灵/.test(detail) ? 'pvp' : 'pve',
                type,
                amount,
                mofa_amount: type === 'revive' ? Number(mofa?.[1] || 0) : 0,
                target_name: damage?.[1] || match[1],
                family: ''
            };
        },

        syncBattlePetAssist(petAssist) {
            if (!petAssist || Number(petAssist.active || 0) !== 1) {
                this.battlePet = null;
                this.clearPetAssistEffect(false);
                return;
            }
            this.battlePet = {
                ...petAssist,
                active: true,
                cooldown: Math.max(1, Number(petAssist.cooldown || 30)),
                cooldown_remaining: Math.max(
                    0, Number(petAssist.cooldown_remaining || 0)
                )
            };

            const event = petAssist.recent_event;
            const eventId = String(event?.id || '');
            if (!eventId || eventId === this.lastPetAssistEventId ||
                this.petAssistEventHistory[eventId]) return;
            this.showPetAssistEffect(event, eventId, true);
        },

        applyBattleStatusData(data, fromAutofightRefresh = false) {
            if (!data) return;
            this.syncRoomSkillManifestations(data.player?.room_skill_events);
            this.syncBattleAoeReport(data.player?.recent_aoe_report);

            if (data.in_battle) {
                if (!this.isInBattle) {
                    console.log('[战斗] 进入战斗状态');
                    this.isInBattle = true;
                    this.battleLog = [];
                    if (!fromAutofightRefresh) {
                        this.startBattleStatusPolling();
                    }
                } else if (fromAutofightRefresh && this.battleStatusInterval) {
                    this.stopBattleStatusPolling();
                }

                if (data.player) {
                    this.battlePlayerFull = data.player;
                }
                this.syncBattlePetAssist(data.player?.pet_assist);

                if (data.enemy) {
                    this.battleEnemyFull = data.enemy;
                    this.battleEnemy = {
                        name: data.enemy.name_cn || data.enemy.name,
                        hp: data.enemy.hp,
                        hpMax: data.enemy.hp_max,
                        is_npc: data.enemy.is_npc,
                        level: data.enemy.level,
                        profe: data.enemy.profe,
                        race: data.enemy.race,
                        attack: data.enemy.attack,
                        attackLow: data.enemy.attack_low,
                        attackHigh: data.enemy.attack_high,
                        defend: data.enemy.defend
                    };
                } else {
                    this.battleEnemyFull = null;
                }
            } else if (this.isInBattle) {
                console.log('[战斗] 离开战斗状态');
                this.isInBattle = false;
                this.battleEnemy = null;
                this.battleEnemyFull = null;
                this.battlePlayerFull = this.battleAoeReport && data.player
                    ? data.player
                    : null;
                this.battleAnimations = [];
                this.skillAnimations = [];
                this.battlePet = null;
                this.clearPetAssistEffect(false);
                this.stopBattleStatusPolling();
            }
        },

        /**
         * 获取战斗状态（敌我双方）
         */
        async fetchBattleStatus() {
            if (!this.txd || this.battleStatusLoading) {
                return;
            }
            if (typeof document !== 'undefined' && document.hidden) {
                return;
            }

            const requestEpoch = this.characterSessionEpoch;
            const requestTxd = this.txd;
            this.battleStatusLoading = true;
            try {
                const response = await fetch(`${this.apiBase}/api/battle_status?txd=${encodeURIComponent(requestTxd)}`);
                if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                if (!response.ok) return;

                const data = await response.json();
                if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                this.applyBattleStatusData(data, false);
            } catch (e) {
                if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                console.error('[战斗] 获取战斗状态失败:', e);
            } finally {
                if (this.isCharacterSessionCurrent(requestEpoch))
                    this.battleStatusLoading = false;
            }
        },

        /**
         * 解析战斗信息（敌人名称、HP等）
         */
        parseBattleInfo() {
            // 从 mudLines 中查找战斗相关的信息
            // 常见格式: "你对XXX发动攻击" 或 "XXX正在攻击你"
            for (const line of this.mudLines) {
                if (!line.segments) continue;
                const lineText = line.segments.map(s => {
                    if (s.type === 'text') {
                        return s.parts ? s.parts.map(p => p.content || '').join('') : '';
                    }
                    return '';
                }).join('');

                // 解析敌人名称
                const enemyMatch = lineText.match(/对(.{2,6})发动攻击|(.{2,6})正在攻击|(.{2,6})对你造成|战胜了(.{2,6})/);
                if (enemyMatch) {
                    const enemyName = enemyMatch[1] || enemyMatch[2] || enemyMatch[3] || enemyMatch[4];
                    if (enemyName && !enemyName.includes('你') && !enemyName.includes('自动')) {
                        if (!this.battleEnemy || this.battleEnemy.name !== enemyName) {
                            this.battleEnemy = { name: enemyName, hp: null, hpMax: null };
                        }
                        break;
                    }
                }
            }
        },

        /**
         * 检测并处理复制命令
         * @param {Array} lines - MUD输出行
         */
        handleCopyCommands(lines) {
            for (const line of lines) {
                if (!line.segments) continue;

                // 构建完整文本行
                const lineText = line.segments.map(s => {
                    if (s.type === 'text') {
                        return s.parts ? s.parts.map(p => p.content || '').join('') : '';
                    }
                    return s.label || '';
                }).join('');

                // 检测复制命令
                if (lineText.startsWith('COPY_CODE:')) {
                    const code = lineText.substring(10).trim();
                    this.copyToClipboard(code, '邀请码');
                } else if (lineText.startsWith('COPY_LINK:')) {
                    const link = lineText.substring(10).trim();
                    this.copyToClipboard(link, '邀请链接');
                }
            }
        },

        /**
         * 处理邀请链接占位符 - 动态生成URL
         * 检测 CMD:DYNAMIC_INVITE_LINK:invite_code 格式
         */
        processInviteLinkPlaceholder() {
            const baseUrl = window.location.origin + window.location.pathname;
            let inviteCode = null;
            let insertIndex = -1;

            console.log('[邀请链接] 开始处理, mudLines数量:', this.mudLines.length);

            // 先找到要替换的行索引
            for (let i = 0; i < this.mudLines.length; i++) {
                const line = this.mudLines[i];
                if (!line.segments) continue;

                // 构建完整文本行来检测命令
                let lineText = '';
                for (const segment of line.segments) {
                    if (segment.type === 'text' && segment.parts) {
                        for (const part of segment.parts) {
                            if (part.content) lineText += part.content;
                        }
                    } else if (segment.type === 'button') {
                        lineText += segment.label || '';
                    }
                }

                // 打印前几行用于调试
                if (i < 5) {
                    console.log('[邀请链接] 行', i, '文本:', lineText);
                }

                // 检测 DYNAMIC_INVITE_LINK 命令
                const match = lineText.match(/CMD:DYNAMIC_INVITE_LINK:(\S+)/);
                if (match) {
                    inviteCode = match[1];
                    insertIndex = i;
                    console.log('[邀请链接] 找到匹配行:', i, '邀请码:', inviteCode);
                    break;
                }
            }

            // 如果找到了，进行替换
            if (inviteCode && insertIndex >= 0) {
                const inviteUrl = this.buildReferralLink(inviteCode);
                const newLine = {
                    type: 'line',  // 必须有 type 属性
                    segments: [
                        {
                            type: 'button',
                            label: '[复制邀请链接]',
                            cmd: 'copy_invite_url:' + inviteUrl,
                            class: 'btn btn-outline-info btn-sm'
                        }
                    ]
                };

                // 使用 splice 触发 Vue 响应式更新（删除1个，插入1个）
                this.mudLines.splice(insertIndex, 1, newLine);

                console.log('[邀请链接] 动态生成:', inviteUrl);
                console.log('[邀请链接] 新行结构:', JSON.stringify(newLine));
                // copy_invite_url命令的处理已在sendJsonCommand中完成
            } else {
                console.log('[邀请链接] 未找到邀请码, inviteCode:', inviteCode, 'insertIndex:', insertIndex);
            }
        },

        /**
         * 复制到剪贴板并显示提示
         * @param {string} text - 要复制的文本
         * @param {string} label - 提示标签
         */
        async copyToClipboard(text, label = '内容') {
            try {
                await navigator.clipboard.writeText(text);
                // 显示成功提示
                this.showCopySuccess(`${label}已复制`);
            } catch (err) {
                console.error('复制失败:', err);
                // 降级方案：使用传统方法
                const textArea = document.createElement('textarea');
                textArea.value = text;
                textArea.style.position = 'fixed';
                textArea.style.opacity = '0';
                document.body.appendChild(textArea);
                textArea.select();
                try {
                    document.execCommand('copy');
                    this.showCopySuccess(`${label}已复制`);
                } catch (e) {
                    this.showCopySuccess('复制失败，请手动复制');
                }
                document.body.removeChild(textArea);
            }
        },

        /**
         * 显示复制成功提示
         * @param {string} message - 提示消息
         */
        showCopySuccess(message) {
            // 创建临时提示元素
            const toast = document.createElement('div');
            toast.textContent = message;
            toast.style.cssText = `
                position: fixed;
                top: 80px;
                left: 50%;
                transform: translateX(-50%);
                background: rgba(0, 0, 0, 0.85);
                color: #4CAF50;
                padding: 16px 32px;
                border-radius: 8px;
                z-index: 10000;
                box-shadow: 0 4px 16px rgba(0,0,0,0.3);
                font-size: 16px;
                font-weight: bold;
                transition: opacity 0.3s ease;
                opacity: 0;
            `;
            document.body.appendChild(toast);

            // 触发重排以启用过渡动画
            requestAnimationFrame(() => {
                toast.style.opacity = '1';
            });

            console.log('[复制成功]', message);

            // 2秒后淡出并移除
            setTimeout(() => {
                toast.style.opacity = '0';
                setTimeout(() => toast.remove(), 300);
            }, 2000);
        },

        /**
         * 解析战斗动作并生成动画
         * @param {Array} newLines - 新的MUD输出行
         */
        parseBattleActions(newLines) {
            for (const line of newLines) {
                if (!line.segments) continue;

                // 构建完整文本行（包含文本段和按钮标签）
                const lineText = line.segments.map(s => {
                    if (s.type === 'text') {
                        return s.parts ? s.parts.map(p => p.content || '').join('') : '';
                    }
                    return s.label || '';
                }).join('');

                // 跳过空行
                if (!lineText || lineText.trim().length === 0) continue;

                // 跳过纯按钮行（如"察看战况"）
                const isButtonOnly = line.segments.length === 1 && line.segments[0].type === 'button';
                if (isButtonOnly) continue;

                const roomPetEvent = this.parseRoomPetManifestation(lineText);
                if (roomPetEvent) {
                    this.showPetAssistEffect(roomPetEvent, '', this.isInBattle);
                    continue;
                }

                // 把玩家自己战斗中的文本记录到日志；旁观事件只驱动轻量动画。
                const trimmedText = lineText.trim();
                if (this.isInBattle && trimmedText.length > 0 &&
                    trimmedText.length < 200) {
                    this.addBattleLog('info', trimmedText);
                }

                // 只有明确的施法文本才触发技能动画，避免状态栏中的“内力”等
                // 普通文字被误判；同时显示真实技能名。
                const skillName = this.extractSkillName(lineText);
                if (skillName) {
                    const skillType = /太古|寰极/.test(lineText) ? 'ancient' :
                        (this.parseMartialArtsSkill(skillName) || 'generic');
                    const skillTarget = this.getSkillAnimationTarget(skillType, lineText);
                    this.addSkillAnimation(skillType, skillName, skillTarget);
                }

                // 丹药服用触发 buff 光效（挂机自动嗑药、手动吃丹药都触发）。
                // 必须放在 isInBattle 早退之前，否则脱战挂机时不会播放。
                const danyaoEatMatch = lineText.match(/你(?:食用|阅读)了([^。。\n]+?)(?:[。\n]|$)/);
                if (danyaoEatMatch && danyaoEatMatch[1]) {
                    this.addSkillAnimation('buff', danyaoEatMatch[1].trim(), 'player');
                }

                if (!this.isInBattle) continue;

                // 解析特殊战斗状态
                if (lineText.match(/躲过.*攻击|闪避.*招式|身法.*避开/)) {
                    this.addSkillAnimation('dodge', '闪避', 'player');
                }
                if (lineText.match(/格挡.*攻击|招架.*招式|成功.*防御/)) {
                    this.addSkillAnimation('block', '格挡', 'player');
                }
                if (lineText.match(/身中剧毒|毒发.*伤|中毒.*发作/)) {
                    this.addSkillAnimation('poison', '持续伤害', 'player');
                }

                // 解析伤害数字用于动画
                const damageToEnemyMatch = lineText.match(/(\d+)点.*?伤害/);
                if (damageToEnemyMatch && lineText.includes('你')) {
                    const damage = parseInt(damageToEnemyMatch[1] || 0);
                    if (damage > 0) {
                        const isPlayerAttacking = lineText.includes('你造成') || /你.*?对/.test(lineText);
                        const criticalMatch = lineText.match(/暴击|致命|会心一击/);
                        if (isPlayerAttacking) {
                            this.addBattleAnimation('damage', 'enemy', damage, criticalMatch);
                            if (criticalMatch) {
                                this.addSkillAnimation('critical', '会心一击', 'enemy');
                            }
                        } else {
                            this.addBattleAnimation('damage', 'player', damage, criticalMatch);
                        }
                    }
                }

                // 战斗胜利
                if (lineText.match(/战斗胜利|战胜了|击败|获胜/)) {
                    this.addBattleAnimation('victory', null, null);
                    this.triggerGameFeedback('victory', '', 10000);
                }

                // 解析敌人状态（HP显示）
                const hpMatch = lineText.match(/(.{2,6})[：:]\s*(\d+)\/(\d+)/);
                if (hpMatch) {
                    const name = hpMatch[1].trim();
                    const hp = parseInt(hpMatch[2]);
                    const hpMax = parseInt(hpMatch[3]);
                    if (!name.includes('你') && name.length >= 2 && name.length <= 6) {
                        this.battleEnemy = { name, hp, hpMax };
                    }
                }
            }
        },

        formatSkillAnimationName(name) {
            const value = String(name || '').trim();
            const tagOnly = value.match(/^【([^】]+)】$/);
            return (tagOnly ? tagOnly[1] : value.replace(/^【[^】]+】/, ''))
                .replace(/[（(](?:等级)?\d+级?.*$/, '')
                .trim()
                .slice(0, 14);
        },

        /** 从“施展／施放／召唤”战斗文案中提取真实技能名。 */
        extractSkillName(text) {
            const source = String(text || '');
            if (/无法施放|不能施放|未能施放|尚未达到.*无法使用|还需要.*冷却|法术公共冷却/.test(source)) {
                return '';
            }
            const patterns = [
                /(?:施展了?|施放了?|使出了?|发动了?)「([^」]+)」/,
                /(?:施展了?|施放了?|使出了?|发动了?|祭起了?)(【[^】]+】(?:[^（(，,。！!\n]+)?|[\u3400-\u9fff·]{2,18})(?=[（(，,。！!\s])/,
                /召唤出了?(【[^】]+】(?:[^（(，,。！!\n]+)?|[\u3400-\u9fff·]{2,18})(?=[（(，,。！!\s])/
            ];
            for (const pattern of patterns) {
                const match = source.match(pattern);
                if (match && match[1]) {
                    return this.formatSkillAnimationName(match[1]);
                }
            }
            if (source.includes('三灵合一')) return '三灵合一';
            if (source.includes('三灵共鸣')) return '三灵共鸣';
            if (source.includes('灵契共鸣')) return '灵契共鸣';
            return '';
        },

        /**
         * 按技能名识别视觉类型，覆盖全部职业、方士灵术、镇越守势和天象星术。
         * @param {string} text - 技能名、技能ID或战斗文本
         * @returns {string|null} 技能类型
         */
        parseMartialArtsSkill(text) {
            const value = String(text || '');
            if (!value) return null;

            if (/太古|寰极/.test(value)) return 'ancient';

            if (/灵治|灵莲铺|万灵朝生|治疗|回春|恢复/.test(value)) return 'heal';
            if (/召唤|虎灵|鹤灵|龟灵|三灵合一|三灵共鸣|唤小灵|灵契共鸣/.test(value)) return 'summon';
			if (/山河壁|玄铁盾|万山不孤|天地成壁/.test(value)) return 'block';
			if (/星壁|万象星壁/.test(value)) return 'block';
			if (/地震吼|镇魂吼/.test(value)) return 'curse';
			if (/星锁|周天静止/.test(value)) return 'curse';
			if (/星芒|曜光|星落|星河坠落/.test(value)) return 'fire';
			if (/寒辰|星雨|月引/.test(value)) return 'ice';
			if (/流星|天旋|九星连珠/.test(value)) return 'wind';
            if (/雷|电|极光|光芒万丈|玄光/.test(value)) return 'lightning';
            if (/火|炎|焰|燎|灼|太阳热线/.test(value)) return 'fire';
            if (/冰|雪|寒|霜|冻/.test(value)) return 'ice';
            if (/药雾|毒|瘴|腐蚀|流血|放血|裂伤|撕裂|灼烧/.test(value)) return 'poison';
            if (/诅咒|封印|禁锢|束缚|障目|泥沼|灵咒|缠身|重压|致残/.test(value)) return 'curse';
            if (/轻功|凌波微步|神行百变|灵玄影|幻影残像|鬼踪|飘忽不定|清风身法|九幽鬼步/.test(value)) return 'lightness';
            if (/盾|护体|结界|剑意|神威|狂化|冲动|静心|凝心|灵涌|灵风|山印|镇岩|镇越真身|万山朝拱/.test(value)) return 'buff';
            if (/风|云|瞬移/.test(value)) return 'wind';
            if (/剑气|剑芒|万剑|剑阵|剑域|神剑|剑光|御剑|剑影|破天一剑/.test(value)) return 'sword-qi';
            if (/刀|斩|刃|切割|伏击|夺命|杀戮|封喉|绝灭/.test(value)) return 'saber';
            if (/棒|棍|横扫|竹鞭/.test(value)) return 'staff';
            if (/掌|掌法/.test(value)) return 'palm';
            if (/指|指法/.test(value)) return 'finger';
            if (/拳|冲撞|猛击|重击|打击|岳击|横山击|巨岳破|岳反震|不周震击/.test(value)) return 'fist';
            if (/内力|真气|内功|神功|心法|本能|狂意/.test(value)) return 'inner-power';
			if (/【方】|灵/.test(value)) return 'spirit';
			if (/【象】|星痕|观天/.test(value)) return 'lightning';
            return null;
        },

        getSkillAnimationTarget(skillType, text = '') {
            const value = String(text || '');
            if (/【战技显化】|【灵宠显化】/.test(value)) return 'room';
            const playerCast = /你(?:紧握.*?)?(?:施展|施放|使出|发动|祭起|召唤)/.test(value);
            const affectsPlayer = /对你|为你恢复|你的这次攻击/.test(value);
            const selfTypes = ['heal', 'summon', 'buff', 'inner-power', 'lightness', 'dodge', 'block'];
            if (selfTypes.includes(skillType)) {
                return playerCast || affectsPlayer ? 'player' : 'enemy';
            }
            return affectsPlayer && !value.includes('你对') ? 'player' : 'enemy';
        },

        /**
         * 消费房间所属 Worker 产生的短生命施法事件。/status、
         * battle_status 和挂机快照可能返回同一事件，只按服务端 ID
         * 播放一次；人物会话切换时由上层清空记录。
         */
        syncRoomSkillManifestations(events) {
            if (!Array.isArray(events) || events.length === 0) return;
            if (!this.roomSkillEventHistory) this.roomSkillEventHistory = {};
            const seenAt = Date.now();
            for (const [eventId, timestamp] of Object.entries(
                this.roomSkillEventHistory
            )) {
                if (seenAt - Number(timestamp) > 120000) {
                    delete this.roomSkillEventHistory[eventId];
                }
            }
            const ordered = [...events].sort((left, right) =>
                Number(left?.event_at || 0) - Number(right?.event_at || 0)
            );
            for (const event of ordered) {
                const eventId = String(event?.id || '');
                if (!eventId || this.roomSkillEventHistory[eventId]) continue;
                this.roomSkillEventHistory[eventId] = seenAt;
                const skillName = this.formatSkillAnimationName(
                    event?.skill_name || '战技显化'
                );
                const skillType = this.parseMartialArtsSkill(skillName) ||
                    'generic';
                this.addSkillAnimation(skillType, skillName, 'room');
            }
        },

        /** 添加技能动画；同一技能短时间去重并最多保留三个并行动画。 */
        addSkillAnimation(skillType, skillName = '', target = 'enemy') {
            if (!this.combatEffectsEnabled) return;
            if (!this.skillAnimations) this.skillAnimations = [];

            const createdAt = Date.now();
            const name = this.formatSkillAnimationName(skillName);
            const duplicate = this.skillAnimations.some(effect =>
                effect.type === skillType && effect.name === name &&
                effect.target === target && createdAt - (effect.createdAt || 0) < 1200
            );
            if (duplicate) return;

            const id = 'skill-' + createdAt + '-' + Math.random();
            this.skillAnimations = this.skillAnimations
                .filter(effect => createdAt - (effect.createdAt || createdAt) < 2500)
                .slice(-2);
            this.skillAnimations.push({ id, type: skillType, name, target, createdAt });

            const duration = {
                'sword-qi': 1000, 'palm': 800, 'finger': 650, 'fist': 650,
                'lightness': 950, 'inner-power': 1100, 'staff': 750,
                'saber': 750, 'critical': 800, 'dodge': 550, 'block': 650,
                'poison': 1300, 'heal': 1200, 'summon': 1350, 'buff': 1100,
                'curse': 1100, 'lightning': 900, 'fire': 1000, 'ice': 1100,
                'wind': 950, 'spirit': 1100, 'ancient': 1800, 'generic': 900
            }[skillType] || 900;

            setTimeout(() => {
                this.skillAnimations = this.skillAnimations.filter(effect => effect.id !== id);
            }, duration);
        },

        getSkillAnimationClass(skillType) {
            const classMap = {
                'sword-qi': 'skill-sword-qi', 'palm': 'skill-palm-wave',
                'finger': 'skill-finger-strike', 'fist': 'skill-fist-strike',
                'lightness': 'skill-lightness', 'inner-power': 'skill-inner-power',
                'staff': 'skill-staff-sweep', 'saber': 'skill-saber-slash',
                'critical': 'skill-critical-blow', 'dodge': 'skill-dodge',
                'block': 'skill-block', 'poison': 'skill-poison',
                'heal': 'skill-heal-bloom', 'summon': 'skill-summon-circle',
                'buff': 'skill-buff-aura', 'curse': 'skill-curse-seal',
                'lightning': 'skill-lightning-strike', 'fire': 'skill-fire-burst',
                'ice': 'skill-ice-crystal', 'wind': 'skill-wind-sweep',
                'spirit': 'skill-spirit-orbit', 'ancient': 'skill-ancient-awakening',
                'generic': 'skill-generic-cast'
            };
            return classMap[skillType] || 'skill-generic-cast';
        },

        getSkillIcon(skillType) {
            const iconMap = {
                'sword-qi': '⚔️', 'palm': '🖐️', 'finger': '👆', 'fist': '👊',
                'lightness': '💨', 'inner-power': '✨', 'staff': '🎋',
                'saber': '🗡️', 'critical': '💥', 'dodge': '💫', 'block': '🛡️',
                'poison': '☠️', 'heal': '🪷', 'summon': '🌀', 'buff': '🔆',
                'curse': '🔮', 'lightning': '⚡', 'fire': '🔥', 'ice': '❄️',
                'wind': '🌪️', 'spirit': '☯️', 'ancient': '𖤓',
                'generic': '✦'
            };
            return iconMap[skillType] || '✦';
        },

        getSkillIconClass(skillType) {
            const classMap = {
                'sword-qi': 'sword-qi-icon', 'palm': 'palm-wave-icon',
                'finger': 'finger-strike-icon', 'fist': 'fist-strike-icon',
                'lightness': 'lightness-icon', 'inner-power': 'inner-power-icon',
                'staff': 'staff-sweep-icon', 'saber': 'saber-slash-icon',
                'critical': 'critical-blow-icon', 'dodge': 'dodge-icon',
                'block': 'block-icon', 'poison': 'poison-icon',
                'heal': 'heal-bloom-icon', 'summon': 'summon-circle-icon',
                'buff': 'buff-aura-icon', 'curse': 'curse-seal-icon',
                'lightning': 'lightning-strike-icon', 'fire': 'fire-burst-icon',
                'ice': 'ice-crystal-icon', 'wind': 'wind-sweep-icon',
                'spirit': 'spirit-orbit-icon', 'ancient': 'ancient-awakening-icon',
                'generic': 'generic-cast-icon'
            };
            return classMap[skillType] || 'generic-cast-icon';
        },

        /**
         * 添加战斗动画
         * @param {string} type - 动画类型: damage, heal, victory
         * @param {string} target - 目标: player, enemy
         * @param {number} value - 数值
         * @param {boolean} isCritical - 是否暴击
         */
        addBattleAnimation(type, target, value, isCritical = false) {
            const id = Date.now() + Math.random();
            const animation = { id, type, target, value, isCritical };
            this.battleAnimations.push(animation);

            // 自动移除动画
            setTimeout(() => {
                this.battleAnimations = this.battleAnimations.filter(a => a.id !== id);
            }, 2000);
        },

        /**
         * 添加战斗日志
         * @param {string} type - 日志类型
         * @param {string} message - 消息
         */
        addBattleLog(type, message) {
            const timestamp = new Date().toLocaleTimeString('zh-CN', { hour12: false });
            this.battleLog.unshift({ type, message, timestamp });
            // 只保留最近50条
            if (this.battleLog.length > 50) {
                this.battleLog = this.battleLog.slice(0, 50);
            }
        },

        /**
         * 切换迷你模式
         */
        toggleBattleMiniMode() {
            this.battleMiniMode = !this.battleMiniMode;
            localStorage.setItem('battle_mini_mode', this.battleMiniMode ? '1' : '0');
        },

        /**
         * 切换全屏模式
         */
        toggleBattleFullscreen() {
            this.battleFullscreen = !this.battleFullscreen;
            // 全屏时自动展开战斗日志
            if (this.battleFullscreen) {
                this.battleShowLog = true;
            }
        },

        /**
         * 收起或展开停靠式战斗状态栏
         */
        toggleBattleDock() {
            this.battleDockCollapsed = !this.battleDockCollapsed;
            localStorage.setItem('battle_dock_collapsed', this.battleDockCollapsed ? '1' : '0');
        },

        toggleHeaderCollapsed() {
            this.headerCollapsed = !this.headerCollapsed;
            localStorage.setItem('header_collapsed', this.headerCollapsed ? '1' : '0');
        },

        /**
         * 切换战斗日志显示
         */
        toggleBattleLog() {
            this.battleShowLog = !this.battleShowLog;
        },

        toggleCombatEffects() {
            this.combatEffectsEnabled = !this.combatEffectsEnabled;
            localStorage.setItem('battle_effects_enabled', this.combatEffectsEnabled ? '1' : '0');
            if (!this.combatEffectsEnabled) {
                this.skillAnimations = [];
                this.clearPetAssistEffect(false);
                this.clearPetLevelUpEffect();
                this.confettiInstance?.reset?.();
                this.outputAutoAnimateController?.disable?.();
                this.toastAutoAnimateController?.disable?.();
                this.completionAutoAnimateController?.disable?.();
            } else {
                this.toastAutoAnimateController?.enable?.();
                this.completionAutoAnimateController?.enable?.();
            }
            this.showUiToast(
                `视觉特效已${this.combatEffectsEnabled ? '开启' : '关闭'}`,
                'info'
            );
        },

        /**
         * 清空战斗日志
         */
        clearBattleLog() {
            this.battleLog = [];
        },

        /**
         * 切换快捷菜单显示/隐藏
         */
        toggleQuickActions() {
            this.quickActionsCollapsed = !this.quickActionsCollapsed;
            localStorage.setItem('quickActionsCollapsed', this.quickActionsCollapsed ? '1' : '0');
        },

        /**
         * 根据内容行数动态调整容器高度
         */
        adjustContainerHeight() {
            const container = document.querySelector('.mud-output-container');
            if (!container) return;
            // 高度交给响应式CSS和真实内容决定，避免短页面被压缩成几像素。
            container.style.minHeight = '';
            container.style.maxHeight = 'none';
        },

        /**
         * 打开招式列表
         */
        async openPerformsList() {
            this.performsLoading = true;
            this.showPerformsList = true;
            const requestEpoch = this.characterSessionEpoch;

            try {
                const txd = this.txd;
                if (!txd) {
                    alert('请先登录');
                    this.showPerformsList = false;
                    return;
                }

                const response = await fetch(`${this.apiBase}/api/performs?txd=${encodeURIComponent(txd)}`);
                const data = await response.json();
                if (!this.isCharacterSessionCurrent(requestEpoch)) return;

                if (data.error) {
                    console.error('获取招式列表失败:', data.error);
                    this.performsData = {
                        performs: [],
                        skill_name_cn: '错误',
                        message: data.error
                    };
                } else {
                    this.performsData = data;
                }
            } catch (e) {
                if (!this.isCharacterSessionCurrent(requestEpoch)) return;
                console.error('获取招式列表失败:', e);
                this.performsData = {
                    performs: [],
                    skill_name_cn: '错误',
                    message: '网络错误'
                };
            } finally {
                if (this.isCharacterSessionCurrent(requestEpoch))
                    this.performsLoading = false;
            }
        },

        /**
         * 关闭招式列表
         */
        closePerformsList() {
            this.showPerformsList = false;
            this.performsData = null;
        },

        /**
         * 选择招式并执行
         */
        async selectPerform(perform) {
            if (!perform.available) {
                alert(`该招式需要武功等级达到 ${perform.level_req} 级`);
                return;
            }
            if (!perform.enough_neili) {
                alert(`内力不足！需要 ${perform.neili_cost} 点内力`);
                return;
            }

            const skillLabel = perform.name_cn || perform.id || '技能';
            const skillType = this.parseMartialArtsSkill(
                `${skillLabel} ${perform.id || ''}`
            ) || 'generic';
            const skillTarget = this.getSkillAnimationTarget(
                skillType,
                `你施放${skillLabel}`
            );
            this.addSkillAnimation(skillType, skillLabel, skillTarget);

            // 发送 use_perform 命令（xiand使用use_perform而非perform）
            await this.sendJsonCommand(`use_perform ${perform.id}`);

            // 关闭招式列表，但保持全屏战斗窗口
            this.closePerformsList();
        },

        /**
         * 检查是否有针对特定目标的伤害动画
         */
        hasDamageAnimation(target) {
            return this.battleAnimations.some(anim =>
                anim.target === target && anim.type === 'damage'
            );
        },

        /**
         * 获取动画的CSS类名
         */
        getAnimationClass(anim) {
            let classes = [];
            if (anim.type === 'damage') {
                classes.push('damage-animation');
                if (anim.target === 'player') classes.push('damage-to-player');
                else classes.push('damage-to-enemy');
            } else if (anim.type === 'heal') {
                classes.push('heal-animation');
            } else if (anim.type === 'victory') {
                classes.push('victory-animation');
            }
            if (anim.isCritical) {
                classes.push('critical-animation');
            }
            return classes.join(' ');
        },

        // 语言切换处理
        changeLanguage(event) {
            // 初始化期间不处理，防止无限循环
            if (this.isInitializing) {
                console.log('[Vue] Skipping changeLanguage during initialization');
                return;
            }

            const lang = event.target.value;
            console.log('[Vue] changeLanguage called with:', lang);

            // 保存到localStorage
            localStorage.setItem('userLanguage', lang);

            // 调用translate.js的changeLanguage
            if (typeof translate !== 'undefined' && translate.changeLanguage) {
                translate.changeLanguage(lang);
            }

            // 同步到iframe（如果使用iframe模式）
            const iframe = document.querySelector('.game-frame');
            if (iframe && iframe.contentWindow) {
                iframe.contentWindow.postMessage({type: 'changeLanguage', lang: lang}, '*');
            }

            // 关闭菜单
            this.headerMenuOpen = false;
        }
    },

    computed: {
        hasRecentAoeReport() {
            return Array.isArray(this.battleAoeReport?.targets) &&
                this.battleAoeReport.targets.length > 0;
        },

        visibleProfessionOptions() {
            // 无相/太极未解锁时分别隐藏对应入口，避免玩家点击后才看到具体缺口。
            return this.professionOptions.filter((option) => {
                if (option.profession_id === 'wuxiang' && !this.wuxiangUnlocked) {
                    return false;
                }
                if (option.profession_id === 'taiji' && !this.taijiUnlocked) {
                    return false;
                }
                return true;
            });
        },

        characterAvatarOptions() {
            return this.avatarChoicesFor(
                this.characterForm.race_id,
                this.characterForm.profession_id,
                this.characterForm.sex
            );
        },

        profileAvatarOptions() {
            return this.avatarChoicesFor(
                this.characterProfileForm.race_id,
                this.characterProfileForm.profession_id,
                this.characterProfileForm.sex
            );
        },

        headerPet() {
            const pet = this.playerStats?.pet_assist;
            if (!pet || Number(pet.active || 0) !== 1) {
                return null;
            }
            return pet;
        },

        headerPetSlots() {
            const slots = this.playerStats?.pet_slots;
            if (slots?.shared && slots?.personal) {
                return [slots.shared, slots.personal].map((slot, index) => ({
                    ...slot,
                    system: slot.system || (index === 0 ? 'shared' : 'personal'),
                    command: slot.command || (index === 0 ? 'pet' : 'spirit_companion')
                }));
            }
            const legacy = this.playerStats?.pet_assist;
            if (!legacy || Number(legacy.active || 0) !== 1) {
                return null;
            }
            return [{ ...legacy, system: 'shared', command: 'pet', battle_active: 1 }];
        },

        playerAvatarUrl() {
            if (!this.playerStats || !this.playerStats.avatar) {
                return '';
            }
            return this.getImageUrl(this.playerStats.avatar);
        },

        playerAvatarFallback() {
            const displayName = this.playerStats && this.playerStats.name_cn
                ? this.playerStats.name_cn
                : this.loginForm.userid;
            return displayName ? String(displayName).trim().charAt(0) : '仙';
        },

        playerLevelAuraClass() {
            return 'level-aura-' + this.progressionAuraTier(
                this.playerStats?.level
            );
        },

        // 将区号转换为可读格式 (tx01 -> 1区, tx02 -> 2区, etc.)
        areaName() {
            const partition = this.loginForm.partition || '';
            // 匹配 tx后跟数字的格式
            const match = partition.match(/^tx(\d+)/);
            if (match) {
                const areaNum = parseInt(match[1], 10);
                return areaNum + '区';
            }
            // 如果不是标准格式，返回原值
            return partition;
        }
    },

    beforeUnmount() {
        if (this.registerReturnTimer) {
            clearTimeout(this.registerReturnTimer);
            this.registerReturnTimer = null;
        }
        if (this.backgroundHeartbeatTimer) {
            clearTimeout(this.backgroundHeartbeatTimer);
            this.backgroundHeartbeatTimer = null;
        }
        this.clearBattleAoeReport();
        this.resetPetBattleVisualState();
        this.clearPetLevelUpEffect();
        this.petAssistEventHistory = {};
        this.stopUiTour();
        this.destroyAutoAnimate();
        if (this.autoAnimateReadyHandler) {
            window.removeEventListener(
                'xiand:auto-animate-ready',
                this.autoAnimateReadyHandler
            );
            this.autoAnimateReadyHandler = null;
        }
        this.confettiInstance?.reset?.();
        this.confettiInstance = null;
        this.confettiCanvas?.remove?.();
        this.confettiCanvas = null;
        this.soundPlayer?.unload?.();
        this.soundPlayer = null;
        if (window.vueInstance === this) {
            window.vueInstance = null;
        }
    },

    mounted() {
        // 保存实例到全局以便HTML中的onclick调用
        window.vueInstance = this;

        // AutoAnimate 以ES模块加载；兼容模块先后顺序和登录后才出现的游戏DOM。
        this.autoAnimateReadyHandler = () => this.scheduleAutoAnimateInitialization();
        window.addEventListener(
            'xiand:auto-animate-ready',
            this.autoAnimateReadyHandler
        );
        this.scheduleAutoAnimateInitialization();

        // 初始化完成后，重置语言切换标志，防止初始化时触发无限循环
        this.$nextTick(() => {
            this.isInitializing = false;
        });

        this.apiBase = this.detectApiBase();
        const modeText = this.useJsonMode ? 'JSON模式 (无iframe)' : 'iframe模式';
        console.log(`Vue游戏客户端已启动 (${modeText})`);

        // 从URL参数读取推荐码和txd
        const urlParams = new URLSearchParams(window.location.search);
        const refParam = urlParams.get('ref');
        const txdParam = urlParams.get('txd');
        const useridParam = urlParams.get('userid');
        const charParam = urlParams.get('char');
        // Fragment 不会进入HTTP访问日志。短期账号会话读取后立刻清除；
        // 长期人物书签则保留在地址栏，方便跨浏览器复制和浏览器收藏。
        const bookmarkFragment = new URLSearchParams(
            window.location.hash ? window.location.hash.slice(1) : ''
        );
        const accountHandoff = bookmarkFragment.get('account_session') || '';
        const characterBookmark =
            bookmarkFragment.get('character_bookmark') || '';
        if (/^[0-9a-f]{64}$/.test(characterBookmark)) {
            this.characterBookmarkToken = characterBookmark;
        } else if (/^[0-9a-f]{64}$/.test(accountHandoff)) {
            this.accountToken = accountHandoff;
            const cleanUrl = new URL(window.location.href);
            cleanUrl.hash = '';
            window.history.replaceState({}, '', cleanUrl.toString());
        } else if (window.location.hash) {
            const cleanUrl = new URL(window.location.href);
            cleanUrl.hash = '';
            window.history.replaceState({}, '', cleanUrl.toString());
        }

        // 检测HTML模式（兼容自动浏览器）
        const modeParam = urlParams.get('mode');
        if (modeParam === 'html') {
            this.htmlMode = true;
            console.log('HTML模式已启用：按钮使用href链接');
        }
        if (refParam) {
            if (this.applyReferralLanding(refParam))
                console.log('已从好友专属链接打开注册:', this.refCode);
            else {
                this.showLogin = false;
                this.showRegister = true;
                this.registerError = '好友邀请链接无效，请向邀请人重新获取';
            }
        } else {
            console.log('未检测到推荐码参数');
        }

        // 角色直达书签：?userid=xd01abc&char=xxx
        // 长期有效，跨会话可用；txd 失效后用户重新输密码即可自动选回这个角色。
        // 这里只存id，不预填表单：登录表单的分区+账号拼接由 doLogin 用 preselectedUserid 覆盖。
        if (useridParam) {
            this.preselectedUserid = useridParam;
            console.log('检测到书签账号:', useridParam);
        }
        if (charParam) {
            this.preselectedCharacterId = charParam;
            console.log('检测到书签角色:', charParam);
        }

        // 保存URL中的txd（优先级最高）
        // 其次从 window.name 恢复（自动浏览器中 window.name 按标签页隔离，
        // 而 sessionStorage 会被多个标签页共享）
        // 最后从 sessionStorage 恢复（标准浏览器兼容）
        let savedTxd = null;
        let txdFromUrl = false;
        let txdFromWindowName = false;
        if (txdParam) {
            savedTxd = txdParam;
            txdFromUrl = true;
            console.log('检测到URL中的txd参数，将用于自动登录');
        } else {
            // 优先从 window.name 恢复（自动浏览器友好）
            const tabData = this.loadTabSession();
            if (tabData && tabData.txd) {
                savedTxd = tabData.txd;
                txdFromWindowName = true;
                // 同时恢复账号会话
                this.accountToken = tabData.accountToken || '';
                this.accountId = tabData.accountId || '';
                this.currentCharacterId = tabData.characterId || '';
                this.loginForm.partition = tabData.partition || 'tx01';
                this.loginForm.userid = tabData.userid || '';
                console.log('[mounted] 从 window.name 恢复会话（自动浏览器兼容）');
            } else {
                // 不从 sessionStorage 恢复 txd：自动浏览器中 sessionStorage 被多标签共享，
                // 可能拿到另一个标签页的 txd 导致"变成第一个账号"。
                // 只靠 URL 参数和 window.name 两个按标签隔离的机制。
            }
        }

        // 从localStorage恢复主题设置
        const savedTheme = localStorage.getItem('mud_theme');
        if (savedTheme) {
            this.theme = savedTheme;
        }
        this.applyTheme();

        // 恢复游戏字号；新玩家默认使用更紧凑的 14px。
        this.fontSize = localStorage.getItem('mud_font_size') || 'small';
        this.applyFontSize();

        // 恢复战斗迷你模式设置
        const savedMiniMode = localStorage.getItem('battle_mini_mode');
        if (savedMiniMode === '0') {
            this.battleMiniMode = false;
        } else {
            this.battleMiniMode = true;  // 默认迷你模式
        }

        // 恢复战斗状态栏折叠设置；展开时采用不遮挡正文的停靠布局
        this.battleDockCollapsed = localStorage.getItem('battle_dock_collapsed') === '1';
        // 小屏自动折叠头部
        this.headerCollapsed = localStorage.getItem('header_collapsed') === '1' ||
            (window.innerWidth < 480 && !localStorage.getItem('header_collapsed'));

        // 恢复快捷菜单折叠状态
        const savedQuickActionsCollapsed = localStorage.getItem('quickActionsCollapsed');
        this.quickActionsCollapsed = savedQuickActionsCollapsed !== '0';

        console.log('API地址:', this.apiBase);

        // 生成验证码
        this.refreshCaptcha();

        // 加载分区列表
        this.loadPartitions();

        // 页面可见性监听：后台标签恢复时立即刷新
        document.addEventListener('visibilitychange', () => {
            if (document.visibilityState === 'visible') {
                console.log('[页面恢复] 刷新状态');
                if (!this.showCharacterSelect && this.txd) {
                    this.fetchPlayerStats();
                    if (this.playerStats && this.playerStats.autofight) {
                        // 重启前台的只读画面同步定时器。
                        this.checkAutofight();
                    }
                    // 无论挂机此刻是否已在后台结束，都拉取一次最后画面和
                    // 同刻战斗快照，避免恢复前台后仍停在旧场景。
                    this.runAutofightTick();
                }
            } else if (document.visibilityState === 'hidden') {
                // 只暂停只读画面同步；服务端全局调度器继续挂机。
                if (this.autofightInterval) {
                    clearInterval(this.autofightInterval);
                    this.autofightInterval = null;
                }
            }
        });

        // 后台保活心跳：即使标签在后台也每 25 秒发一个轻量请求，
        // 防止服务端虚拟连接被 cleanup_idle_connections 清理。
        // 用 setTimeout 链而非 setInterval，避免后台节流积压。
        this.backgroundHeartbeat = () => {
            if (this.txd) {
                const url = this.apiBase + '/api/ping?txd=' +
                    encodeURIComponent(this.txd);
                // sendBeacon 在后台也能可靠发送（浏览器 API 设计如此）
                if (navigator.sendBeacon) {
                    navigator.sendBeacon(url);
                } else {
                    fetch(url, { keepalive: true }).catch(() => {});
                }
            }
            this.backgroundHeartbeatTimer = setTimeout(
                this.backgroundHeartbeat, 25000);
        };
        this.backgroundHeartbeatTimer = setTimeout(
            this.backgroundHeartbeat, 25000);

        // 点击外部关闭菜单
        document.addEventListener('click', (e) => {
            const headerMenu = document.querySelector('.header-menu-container');
            if (headerMenu && !headerMenu.contains(e.target)) {
                this.headerMenuOpen = false;
            }
        });

        // 如果不是从 window.name 恢复的，才从 sessionStorage 恢复账号信息
        if (!txdFromWindowName) {
            // 自动浏览器中 sessionStorage 被共享，不从这里恢复账号会话。
            // 只从 sessionStorage 恢复非敏感的 UI 偏好（分区/用户名仅用于预填登录框）。
            const tabData2 = this.loadTabSession() || {};
            const savedPartition = tabData2.partition || '';
            const savedUser = tabData2.userid || '';
            this.loginForm.partition = savedPartition || this.loginForm.partition;
            this.loginForm.userid = savedUser || this.loginForm.userid;
        }

        const savedPartition = this.loginForm.partition;
        const savedUser = this.loginForm.userid;

        // 自动登录条件：有txd且（来自URL 或 window.name 或 有保存的用户信息）
        if (this.characterBookmarkToken && this.preselectedUserid &&
            this.preselectedCharacterId) {
            // 长期书签显式指定的人物优先于本标签任何历史TXD，避免打开B
            // 的书签却先恢复A并把A的标签挤下线。
            this.resumePersistentCharacterBookmark();
        } else if (savedTxd && (txdFromUrl || txdFromWindowName || savedUser)) {
            // 有保存的登录信息或URL中有txd，自动恢复
            this.txd = savedTxd;
            this.loginForm.partition = savedPartition || 'tx01';
            this.loginForm.userid = savedUser || '';  // URL模式可能没有用户名

            console.log('apiBase=', this.apiBase);

            // 如果txd来自URL，保存到sessionStorage以便后续使用
            if (txdFromUrl) {
                this.saveTabSession();
                if (savedPartition) {
    
                }
                console.log('[mounted] URL中的txd已保存到sessionStorage');
            }

            // 自动登录时也保存域名
            this.saveGameBaseUrl();

            // 更新URL以包含txd参数（便于书签/分享）
            console.log('[mounted] 自动登录成功，准备更新URL');
            this.updateUrlWithTxd();

            if (this.useJsonMode) {
                // JSON模式: 加载初始MUD输出
                this.showLogin = false;
                this.scheduleAutoAnimateInitialization();
                this.sendJsonCommand('init');
            } else {
                // iframe模式: 设置iframe URL
                this.gameFrameUrl = this.getGameFrameUrl();
                console.log('gameFrameUrl=', this.gameFrameUrl);
                this.showLogin = false;
            }

            // 开始更新玩家状态
            this.startStatsUpdate();
        } else {
            // 无保存的登录信息，恢复表单
            if (savedPartition) {
                this.loginForm.partition = savedPartition;
            }
            if (savedUser) {
                this.loginForm.userid = savedUser;
            }
            if (this.accountToken && this.preselectedCharacterId)
                this.resumeCharacterBookmarkHandoff();
        }
    }
}).mount('#app');

// 全局聊天链接点击处理器
window.handleChatLinkClick = function(element) {
    const command = element.getAttribute('data-command');
    if (command && window.vueInstance) {
        // 关闭聊天室
        window.vueInstance.closeChatRoom();
        // 在主界面执行命令显示装备
        window.vueInstance.sendQuickCommand(command);
    }
};
