/**
 * Vue游戏客户端 - iframe模式 (显示原始HTML)
 */
const { createApp } = Vue;

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

createApp({
    data() {
        return {
            showLogin: true,
            headerMenuOpen: false,
            showRegister: false,
            isLoggingIn: false,
            isRegistering: false,
            loginPasswordVisible: false,
            registerPasswordVisible: false,
            loginError: '',
            registerError: '',
            registerSuccess: false,
            loginForm: {
                partition: 'tx01',
                userid: '',
                password: ''
            },
            registerForm: {
                partition: 'tx01',
                userid: '',
                password: '',
                passwordConfirm: '',
                captcha: ''
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
            statsInterval: null,  // 状态更新定时器
            autofightInterval: null,  // 自动战斗定时器
            autofightTickInFlight: false,  // 防止慢请求造成挂机指令重叠
            lastCommand: 'look',  // 上一次执行的命令，默认是look
            pendingRequests: {},  // 正在进行的异步请求
            useAsyncMode: false,  // 是否使用异步模式（同步更快，无轮询开销）
            // JSON模式 (vue-ui-3: 无iframe，Vue直接渲染)
            useJsonMode: true,  // 使用JSON模式代替iframe
            htmlMode: false,  // HTML模式：按钮使用href链接（兼容自动浏览器）
            mudLines: [],  // MUD输出行数组
            mudLoading: false,  // MUD加载中状态
            slowLoadingTip: false,  // 慢速加载提示（超过3秒显示）
            loadingTimer: null,  // 加载计时器
            // 战斗系统
            isInBattle: false,  // 是否处于战斗状态
            battleMiniMode: true,  // 迷你模式：只显示HP条
            battleFullscreen: false,  // 全屏模式：遮住整个页面
            battleDockCollapsed: false,  // 收起为屏幕边缘的小按钮，不遮挡正文
            battleShowLog: false,  // 显示战斗日志
            battleLog: [],  // 战斗日志条目
            battleAnimations: [],  // 当前显示的战斗动画
            battleEnemy: null,  // 当前敌人信息 {name, hp, hpMax, level, profe, race, attackLow, attackHigh, defend}
            battleEnemyFull: null,  // 敌人完整状态（从API获取）
            battlePlayerFull: null,  // 玩家完整状态（从API获取）
            battleStatusInterval: null,  // 战斗状态轮询定时器
            battleStatusLoading: false,  // 防止挂机刷新和战斗轮询请求重叠
            skillAnimations: [],  // 技能动画列表
            combatEffectsEnabled: localStorage.getItem('battle_effects_enabled') !== '0',
            // 招式系统
            showPerformsList: false,  // 显示招式列表
            performsData: null,  // 招式数据
            performsLoading: false,  // 招式加载中
            // 快捷菜单
            quickActionsCollapsed: true,  // 更多功能默认收起，保留五项高频导航
            // 邀请系统
            refCode: '',  // 推荐人邀请码（从URL参数ref获取）
            showInviteModal: false,  // 显示邀请弹窗
            inviteLink: '',  // 邀请链接
            inviteCode: '',  // 邀请码
            qrCodeUrl: '',  // 二维码URL
            // 新手任务完成弹窗
            activeNewbieCompletion: null,
            newbieCompletionQueue: [],
            // 全局轻提示
            uiToast: null,
            uiToastTimer: null,
            // 语言选择
            selectedLanguage: localStorage.getItem('userLanguage') || 'chinese_simplified',  // 当前选择的语言
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
        }
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

        formatCompactNumber(value) {
            const number = Number(value);
            if (!Number.isFinite(number)) {
                return '0';
            }
            const absolute = Math.abs(number);
            const units = [
                { value: 1e16, label: '京' },
                { value: 1e12, label: '万亿' },
                { value: 1e8, label: '亿' },
                { value: 1e4, label: '万' }
            ];
            const unit = units.find(item => absolute >= item.value);
            if (!unit) {
                return Math.round(number).toLocaleString('zh-CN');
            }
            const compact = number / unit.value;
            const digits = Math.abs(compact) >= 100 ? 0 :
                (Math.abs(compact) >= 10 ? 1 : 2);
            return compact.toFixed(digits).replace(/\.?0+$/, '') + unit.label;
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

        showUiToast(message, type = 'info') {
            if (!message) {
                return;
            }
            if (this.uiToastTimer) {
                clearTimeout(this.uiToastTimer);
            }
            this.uiToast = { message, type };
            this.uiToastTimer = setTimeout(() => {
                this.uiToast = null;
                this.uiToastTimer = null;
            }, 4500);
        },

        clearUiToast() {
            if (this.uiToastTimer) {
                clearTimeout(this.uiToastTimer);
                this.uiToastTimer = null;
            }
            this.uiToast = null;
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
        },

        // 关闭注册页面
        closeRegister() {
            this.showRegister = false;
            this.showLogin = true;
            this.registerPasswordVisible = false;
        },

        // 从API加载分区列表
        async loadPartitions() {
            try {
                const response = await fetch(`${this.apiBase}/api/partitions`);
                if (!response.ok) {
                    console.error('加载分区列表失败:', response.status);
                    // 使用默认分区列表
                    this.partitions = this.getDefaultPartitions();
                    return;
                }
                const data = await response.json();
                this.partitions = data.partitions || [];
                if (this.partitions.length > 0) {
                    this.loginForm.partition = this.partitions[0].value;
                    this.registerForm.partition = this.partitions[0].value;
                }
                console.log('已加载分区列表:', this.partitions);
            } catch (e) {
                console.error('加载分区列表异常:', e);
                // 使用默认分区列表
                this.partitions = this.getDefaultPartitions();
            } finally {
                this.partitionsLoading = false;
            }
        },

        // 默认分区列表（API失败时使用）
        getDefaultPartitions() {
            return [
                { value: 'tx01', label: '原1区' },
                { value: 'tx02', label: '原2区' },
                { value: 'tx03', label: '原3区' },
                { value: 'tx04', label: '原4区' },
                { value: 'tx05', label: '原5区' },
                { value: 'tx06', label: '原6区' }
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
            // 验证输入
            if (!this.registerForm.userid || !this.registerForm.password) {
                this.registerError = '账号和密码不能为空';
                return;
            }
            if (this.registerForm.userid.length < 2 || this.registerForm.password.length < 2) {
                this.registerError = '账号和密码不能少于2个字符';
                return;
            }
            if (this.registerForm.userid.length > 12 || this.registerForm.password.length > 12) {
                this.registerError = '账号和密码不能超过12个字符';
                return;
            }
            if (!/^[a-zA-Z0-9]+$/.test(this.registerForm.userid + this.registerForm.password)) {
                this.registerError = '账号和密码只能是大小写字母或数字';
                return;
            }
            if (this.registerForm.password !== this.registerForm.passwordConfirm) {
                this.registerError = '两次输入的密码不一致';
                return;
            }
            if (this.registerForm.captcha.toLowerCase() !== this.captchaCode.toLowerCase()) {
                this.registerError = '验证码错误';
                this.refreshCaptcha();
                return;
            }

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
                const refCode = this.refCode || localStorage.getItem('ref_code');
                if (refCode) {
                    url += '&ref=' + encodeURIComponent(refCode);
                    console.log('使用推荐码:', refCode);
                }

                const response = await fetch(url, {
                    method: 'GET'
                });

                console.log('response.status:', response.status);
                console.log('response.ok:', response.ok);

                const text = await response.text();
                console.log('注册响应:', text);

                // 检查注册结果
                if (text.includes('error1') || text.includes('已经有人使用')) {
                    this.registerError = '该账号已存在，请修改后重试';
                } else if (text.includes('error2') || text.includes('登录错误')) {
                    this.registerError = '注册失败，请稍后重试';
                } else {
                    // 注册成功 - 响应格式: username,password
                    this.registerSuccess = true;
                    this.registerError = '';
                    // 延迟后返回登录页面
                    setTimeout(() => {
                        this.showRegister = false;
                        this.showLogin = true;
                        this.registerSuccess = false;
                        // 填充登录表单
                        this.loginForm.partition = this.registerForm.partition;
                        this.loginForm.userid = this.registerForm.userid;
                        this.loginForm.password = this.registerForm.password;
                    }, 2000);
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

        async doLogin() {
            if (!this.loginForm.userid || !this.loginForm.password) {
                this.loginError = '请输入账号和密码';
                return;
            }
            this.isLoggingIn = true;
            this.loginError = '';
            try {
                const fullUserid = this.loginForm.partition + this.loginForm.userid;

                // 使用明文密码（不再使用challenge哈希）
                const plainPassword = this.loginForm.password;

                if (this.useJsonMode) {
                    // JSON模式: 使用 /api/json 接口登录
                    const params = new URLSearchParams({
                        userid: fullUserid,
                        password: plainPassword,
                        cmd: 'init'
                    });

                    const response = await fetch(this.apiBase + '/api/json?' + params.toString(), {
                        method: 'GET'
                    });

                    if (!response.ok) {
                        if (response.status === 401) {
                            this.loginError = '用户名或密码错误';
                        } else {
                            this.loginError = '登录失败: HTTP ' + response.status;
                        }
                        return;
                    }

                    const data = await response.json();
                    if (data.error) {
                        this.loginError = data.error || '登录失败';
                        return;
                    }

                    // 登录成功，生成 txd 用于后续请求
                    this.txd = this.encodeTxd(fullUserid, this.loginForm.password);
                    // 如果响应中有新的txd，使用它
                    if (data.txd) {
                        this.txd = data.txd;
                    }
                    sessionStorage.setItem('mud_txd', this.txd);
                    sessionStorage.setItem('mud_partition', this.loginForm.partition);
                    sessionStorage.setItem('mud_userid', this.loginForm.userid);

                    // 保存当前域名到后端
                    this.saveGameBaseUrl();

                    // 更新URL以包含txd参数（便于书签/分享）
                    this.updateUrlWithTxd();

                    // 更新MUD输出
                    this.mudLines = data.lines || [];
                    this.handleNewbieCompletions(
                        data.newbie_completions || []
                    );

                    // 隐藏登录界面
                    this.showLogin = false;

                    // 开始更新玩家状态
                    this.startStatsUpdate();
                } else {
                    // iframe模式: 使用 /api/html 接口
                    const params = new URLSearchParams({
                        userid: fullUserid,
                        password: passwordHash,
                        challenge: challenge,
                        cmd: 'look'
                    });

                    const response = await fetch(this.apiBase + '/api/html?' + params.toString(), {
                        method: 'GET'
                    });

                    if (!response.ok) {
                        if (response.status === 401) {
                            this.loginError = '用户名或密码错误';
                        } else {
                            this.loginError = '登录失败: HTTP ' + response.status;
                        }
                        return;
                    }

                    // 检查响应是否包含错误
                    const text = await response.text();
                    if (text.includes('登录错误') || text.includes('用户名不存在')) {
                        this.loginError = '用户名或密码错误';
                        return;
                    }

                    // 登录成功，生成 txd 用于后续请求
                    this.txd = this.encodeTxd(fullUserid, this.loginForm.password);
                    sessionStorage.setItem('mud_txd', this.txd);
                    sessionStorage.setItem('mud_partition', this.loginForm.partition);
                    sessionStorage.setItem('mud_userid', this.loginForm.userid);

                    // 更新URL以包含txd参数（便于书签/分享）
                    this.updateUrlWithTxd();

                    // 设置iframe URL
                    this.gameFrameUrl = this.getGameFrameUrl();
                    this.showLogin = false;

                    // 开始更新玩家状态
                    this.startStatsUpdate();
                }
            } catch (e) {
                this.loginError = '连接失败: ' + e.message;
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
        updateUrlWithTxd() {
            if (!this.txd) return;

            const url = new URL(window.location.href);
            url.searchParams.set('txd', this.txd);

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

            try {
                const params = new URLSearchParams({
                    txd: this.txd,
                    url: baseUrl
                });

                const response = await fetch(this.apiBase + '/api/invite/seturl?' + params.toString(), {
                    method: 'POST'
                });

                if (response.ok) {
                    console.log('游戏基础URL已保存:', baseUrl);
                }
            } catch (e) {
                console.warn('保存游戏URL失败:', e);
            }
        },

        // 显示邀请弹窗
        showInviteModal() {
            // 获取完整的用户名（分区+账号）
            let username = '';
            if (this.txd) {
                // 从txd解析用户名：txd格式为 "tx01userid:timestamp:hash"
                const txdParts = this.txd.split(':');
                if (txdParts[0]) {
                    username = txdParts[0];
                }
            }

            // 如果没有txd，尝试从登录表单获取
            if (!username && this.loginForm.partition && this.loginForm.userid) {
                username = this.loginForm.partition + this.loginForm.userid;
            }

            // 生成邀请链接 - 使用当前页面路径
            const baseUrl = window.location.protocol + '//' + window.location.host + window.location.pathname;
            this.inviteCode = username;
            this.inviteLink = baseUrl + '?ref=' + username;
            console.log('邀请链接生成:', {
                username: username,
                inviteCode: this.inviteCode,
                inviteLink: this.inviteLink,
                baseUrl: baseUrl
            });

            // 生成二维码URL
            this.qrCodeUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=' + encodeURIComponent(this.inviteLink);

            this.showInviteModal = true;
        },

        // 关闭邀请弹窗
        closeInviteModal() {
            this.showInviteModal = false;
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

            try {
                const url = `${this.apiBase}/api/chat/messages?txd=${encodeURIComponent(this.txd)}&channel=${encodeURIComponent(this.chatChannel)}`;
                const response = await fetch(url);
                if (response.ok) {
                    const data = await response.json();
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

            // 通过API发送消息
            try {
                const response = await fetch(`${this.apiBase}/api/chat/send`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    body: new URLSearchParams({
                        txd: this.txd,
                        channel: this.chatChannel,
                        message: msg
                    })
                });

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
            const isAutofightRefresh = cmd === 'flushview' &&
                this.playerStats && this.playerStats.autofight;
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
                this.slowLoadingTip = false;
            }

            // 3秒后显示慢速加载提示
            if (!isAutofightRefresh) {
                this.loadingTimer = setTimeout(() => {
                    if (this.mudLoading) {
                        this.slowLoadingTip = true;
                    }
                }, 3000);
            }
            try {
                const url = `${this.apiBase}/api/json?txd=${encodeURIComponent(this.txd)}&cmd=${encodeURIComponent(cmd)}`;

                const response = await fetch(url);
                console.log('[sendJsonCommand] 响应状态:', response.status);

                if (!response.ok) {
                    // 401 表示未授权（会话已过期），尝试重新登录并重试命令
                    if (response.status === 401 && !isRetry) {
                        console.log('[会话过期] 尝试重新登录并重试命令...');
                        await this.relogin();
                        // 重新登录成功后重试原始命令
                        if (!this.showLogin) {
                            return this.sendJsonCommand(cmd, true);
                        }
                    }
                    throw new Error(`HTTP ${response.status}`);
                }
                const data = await response.json();

                if (data.error) {
                    console.error('命令执行错误:', data.error);
                    // 如果是认证错误，尝试重新登录并重试命令
                    if ((data.error.includes('认证') || data.error.includes('登录') || data.error.includes('未登录')) && !isRetry) {
                        console.log('[会话过期] 尝试重新登录并重试命令...');
                        await this.relogin();
                        // 重新登录成功后重试原始命令
                        if (!this.showLogin) {
                            return this.sendJsonCommand(cmd, true);
                        }
                    }
                    this.showUiToast(data.error || '命令执行失败，请稍后重试', 'error');
                    return;
                }
                // 更新txd（可能已变化）
                if (data.txd) {
                    this.txd = data.txd;
                    sessionStorage.setItem('mud_txd', this.txd);
                }
                // 保存userid到sessionStorage（用于URL登录后保存用户信息）
                if (data.userid && !sessionStorage.getItem('mud_userid')) {
                    const partitionMatch = data.userid.match(/^([a-z]+\d+)/);
                    if (partitionMatch) {
                        const partition = partitionMatch[1];
                        const userid = data.userid.substring(partition.length);
                        sessionStorage.setItem('mud_partition', partition);
                        sessionStorage.setItem('mud_userid', userid);
                        this.loginForm.partition = partition;
                        this.loginForm.userid = userid;
                        console.log('[sendJsonCommand] 已保存用户信息到sessionStorage:', partition, userid);
                    }
                }
                // 更新MUD输出
                this.mudLines = data.lines || [];
                console.log('[sendJsonCommand] mudLines数量:', this.mudLines.length);
                this.handleNewbieCompletions(data.newbie_completions || []);

                // 处理复制指令（从后端返回的copy字段）
                if (data.copy && data.copy.data) {
                    const copyData = data.copy;
                    const label = copyData.type === 'code' ? '邀请码' : '邀请链接';
                    await this.copyToClipboard(copyData.data, label);
                }

                // 检测战斗状态。挂机刷新必须查询真实战斗状态，不能只依赖文本按钮。
                await this.checkBattleStatus(isAutofightRefresh);
                // 解析战斗动作并生成动画
                this.parseBattleActions(data.lines || []);

                // 检测并处理复制命令（从lines中检测，兼容旧方式）
                this.handleCopyCommands(data.lines || []);

                // 处理邀请链接占位符 - 动态生成URL
                this.processInviteLinkPlaceholder();
            } catch (e) {
                console.error('JSON命令执行失败:', e);
                // 网络错误也尝试重新登录并重试
                if ((e.message.includes('401') || e.message.includes('Unauthorized')) && !isRetry) {
                    console.log('[会话过期] 尝试重新登录并重试命令...');
                    await this.relogin();
                    // 重新登录成功后重试原始命令
                    if (!this.showLogin) {
                        return this.sendJsonCommand(cmd, true);
                    }
                }
                this.showUiToast('连接暂时中断，请检查网络后重试', 'error');
            } finally {
                if (!isAutofightRefresh) {
                    this.mudLoading = false;
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
                    // 解析 [imgurl picture:...] 格式为图片
                    html += this.parseInlineImages(part.content);
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
            return text.replace(/\[([^\]]+?):([^\]]+?)\s+([^\]]+)\]/g, (match, label, command, arg) => {
                // 创建可点击的链接按钮
                return `<span class="chat-link" data-command="${command} ${arg}" onclick="handleChatLinkClick(this)">${label}</span>`;
            });
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
            sessionStorage.removeItem('mud_txd');
            sessionStorage.removeItem('mud_partition');
            sessionStorage.removeItem('mud_userid');
            this.txd = '';
            this.gameFrameUrl = '';
            this.playerStats = null;
            this.playerAvatarFailed = false;
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
            this.battleAnimations = [];
            this.skillAnimations = [];
            this.battleStatusLoading = false;
            this.stopBattleStatusPolling();
            // 清理聊天轮询定时器
            this.stopChatPolling();
            this.showLogin = true;
        },

        // 自动重新登录（当会话过期时）
        async relogin() {
            let savedPartition = sessionStorage.getItem('mud_partition') || '';
            let savedUser = sessionStorage.getItem('mud_userid') || '';
            const savedTxd = sessionStorage.getItem('mud_txd');
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
                this.showLogin = true;
                return;
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

                if (!response.ok) {
                    throw new Error('登录失败: HTTP ' + response.status);
                }

                const data = await response.json();
                if (data.error) {
                    throw new Error(data.error);
                }

                // 重新登录成功
                this.txd = data.txd || this.encodeTxd(fullUserid, password);
                sessionStorage.setItem('mud_txd', this.txd);
                sessionStorage.setItem('mud_partition', savedPartition);
                sessionStorage.setItem('mud_userid', savedUser);

                // 更新 MUD 输出
                this.mudLines = data.lines || [];
                this.handleNewbieCompletions(
                    data.newbie_completions || []
                );
                this.showLogin = false;

                console.log('[重新登录] 成功');
            } catch (e) {
                console.error('[重新登录] 失败:', e);
                // 重新登录失败，显示登录界面
                this.dismissNewbieCompletions();
                this.showLogin = true;
                this.loginForm.partition = savedPartition;
                this.loginForm.userid = savedUser;
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
                sessionStorage.removeItem('mud_txd');
                sessionStorage.removeItem('mud_partition');
                sessionStorage.removeItem('mud_userid');
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
        async fetchPlayerStats() {
            if (!this.txd) return;

            try {
                const response = await fetch(`${this.apiBase}/api/status?txd=${encodeURIComponent(this.txd)}`);
                if (response.ok) {
                    const data = await response.json();
                    if (!data.error) {
                        // 记录之前的 autofight 状态
                        const wasAutofight = this.playerStats && this.playerStats.autofight;
                        const previousAvatar = this.playerStats && this.playerStats.avatar;
                        this.playerStats = data;
                        if (previousAvatar !== data.avatar) {
                            this.playerAvatarFailed = false;
                        }
                        // 检查自动战斗状态变化
                        const isAutofight = this.playerStats && this.playerStats.autofight;
                        if (wasAutofight && !isAutofight) {
                            // 明确从开启变成关闭，清除定时器
                            if (this.autofightInterval) {
                                clearInterval(this.autofightInterval);
                                this.autofightInterval = null;
                            }
                        } else if (!wasAutofight && isAutofight) {
                            // 明确从关闭变成开启，启动定时器
                            this.checkAutofight();
                        }
                        // 如果状态没变，保持当前定时器状态不变
                    }
                }
            } catch (e) {
                console.error('获取玩家状态失败:', e);
                // 网络错误时，不清除 autofight 定时器，保持当前状态
            }
        },

        // 开始定时更新玩家状态
        startStatsUpdate() {
            this.fetchPlayerStats();
            // 每2秒更新一次（后端已用Thread异步，不会阻塞）
            this.statsInterval = setInterval(() => {
                this.fetchPlayerStats();
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

            try {
                const response = await fetch(`${this.apiBase}/api/autofight`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded',
                    },
                    body: new URLSearchParams({
                        txd: this.txd,
                        action: 'toggle'
                    })
                });

                if (response.ok) {
                    const data = await response.json();
                    // 刷新状态
                    await this.fetchPlayerStats();
                    // 显示提示
                    this.showUiToast(
                        data.message || '自动挂机状态已切换',
                        data.autofight ? 'success' : 'info'
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
            if (!this.txd || this.autofightTickInFlight) {
                return;
            }
            if (this.useJsonMode && this.mudLoading) {
                return;
            }
            if (!this.useJsonMode && this.frameLoading) {
                return;
            }
            this.autofightTickInFlight = true;
            try {
                if (this.useJsonMode) {
                    await this.sendJsonCommand('flushview');
                } else {
                    const url = `${this.apiBase}/api/html?txd=${encodeURIComponent(this.txd)}&cmd=${encodeURIComponent('flushview')}`;
                    const iframe = this.$refs.gameFrame;
                    if (iframe) {
                        this.frameLoading = true;
                        iframe.src = url;
                    }
                }
            } finally {
                this.autofightTickInFlight = false;
            }
        },

        // 检查并启动/停止自动战斗
        checkAutofight() {
            if (this.playerStats && this.playerStats.autofight) {
                // 开启自动战斗 - 每秒执行 flushview 命令
                if (!this.autofightInterval) {
                    this.autofightInterval = setInterval(() => {
                        this.runAutofightTick();
                    }, 1000);  // 1秒执行一次
                    this.runAutofightTick();
                }
            } else {
                // 关闭自动战斗
                if (this.autofightInterval) {
                    clearInterval(this.autofightInterval);
                    this.autofightInterval = null;
                }
                this.autofightTickInFlight = false;
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

            try {
                // 1. 发送异步请求
                const asyncResp = await fetch(`${this.apiBase}/api/async`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    body: new URLSearchParams({
                        txd: this.txd,
                        cmd: cmd
                    })
                });

                if (!asyncResp.ok) {
                    // 401 会话过期，尝试重新登录并重试
                    if (asyncResp.status === 401 && !isRetry) {
                        console.log('[Async] 会话过期，尝试重新登录并重试...');
                        await this.relogin();
                        if (!this.showLogin) {
                            return this.sendAsyncCommand(cmd, timeout, true);
                        }
                    }
                    throw new Error(`API错误: ${asyncResp.status}`);
                }

                const asyncData = await asyncResp.json();

                if (asyncData.error) {
                    // 认证错误，尝试重新登录并重试
                    if ((asyncData.error.includes('认证') || asyncData.error.includes('登录') || asyncData.error.includes('未登录')) && !isRetry) {
                        console.log('[Async] 会话过期，尝试重新登录并重试...');
                        await this.relogin();
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

                    const resultResp = await fetch(`${this.apiBase}/api/result?request_id=${encodeURIComponent(requestId)}&txd=${encodeURIComponent(this.txd)}`);

                    if (!resultResp.ok) {
                        // 401 会话过期，尝试重新登录并重试
                        if (resultResp.status === 401 && !isRetry) {
                            console.log('[Async] 会话过期，尝试重新登录并重试...');
                            await this.relogin();
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
                                await this.relogin();
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

            this.battleStatusLoading = true;
            try {
                const response = await fetch(`${this.apiBase}/api/battle_status?txd=${encodeURIComponent(this.txd)}`);
                if (!response.ok) return;

                const data = await response.json();

                if (data.in_battle) {
                    if (!this.isInBattle) {
                        console.log('[战斗] 进入战斗状态');
                        this.isInBattle = true;
                        this.battleLog = [];
                        this.startBattleStatusPolling();
                    }

                    // 更新玩家完整状态
                    if (data.player) {
                        this.battlePlayerFull = data.player;
                    }

                    // 更新敌人状态
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
                        // 战斗建立的首个轮询可能先于敌人快照，保留文本解析或
                        // 上一次轮询确认的名称，避免小窗闪成“敌人”或空白。
                    }
                } else if (this.isInBattle) {
                    console.log('[战斗] 离开战斗状态');
                    this.isInBattle = false;
                    this.battleEnemy = null;
                    this.battleEnemyFull = null;
                    this.battlePlayerFull = null;
                    this.battleAnimations = [];
                    this.skillAnimations = [];
                    this.stopBattleStatusPolling();
                }
            } catch (e) {
                console.error('[战斗] 获取战斗状态失败:', e);
            } finally {
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
                const inviteUrl = baseUrl + '?ref=' + inviteCode;
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
            if (!this.isInBattle) return;

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

                // 把所有战斗文本记录到日志
                const trimmedText = lineText.trim();
                if (trimmedText.length > 0 && trimmedText.length < 200) {
                    this.addBattleLog('info', trimmedText);
                }

                // 只有明确的施法文本才触发技能动画，避免状态栏中的“内力”等
                // 普通文字被误判；同时显示真实技能名。
                const skillName = this.extractSkillName(lineText);
                if (skillName) {
                    const skillType = this.parseMartialArtsSkill(skillName) || 'generic';
                    const skillTarget = this.getSkillAnimationTarget(skillType, lineText);
                    this.addSkillAnimation(skillType, skillName, skillTarget);
                }

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
         * 按技能名识别视觉类型，覆盖全部职业和方士灵术。
         * @param {string} text - 技能名、技能ID或战斗文本
         * @returns {string|null} 技能类型
         */
        parseMartialArtsSkill(text) {
            const value = String(text || '');
            if (!value) return null;

            if (/灵治|灵莲铺|万灵朝生|治疗|回春|恢复/.test(value)) return 'heal';
            if (/召唤|虎灵|鹤灵|龟灵|三灵合一|三灵共鸣|唤小灵|灵契共鸣/.test(value)) return 'summon';
            if (/雷|电|极光|光芒万丈|玄光/.test(value)) return 'lightning';
            if (/火|炎|焰|燎|灼|太阳热线/.test(value)) return 'fire';
            if (/冰|雪|寒|霜|冻/.test(value)) return 'ice';
            if (/毒|瘴|腐蚀|流血|放血|裂伤|撕裂|灼烧/.test(value)) return 'poison';
            if (/诅咒|封印|禁锢|束缚|障目|泥沼|灵咒|缠身|重压|致残/.test(value)) return 'curse';
            if (/轻功|凌波微步|神行百变|灵玄影|幻影残像|鬼踪|飘忽不定|清风身法|九幽鬼步/.test(value)) return 'lightness';
            if (/盾|护体|结界|剑意|神威|狂化|冲动|静心|凝心|灵涌|灵风/.test(value)) return 'buff';
            if (/风|云|瞬移/.test(value)) return 'wind';
            if (/剑气|剑芒|万剑|剑阵|剑域|神剑|剑光|御剑|剑影|破天一剑/.test(value)) return 'sword-qi';
            if (/刀|斩|刃|切割|伏击|夺命|杀戮|封喉|绝灭/.test(value)) return 'saber';
            if (/棒|棍|横扫|竹鞭/.test(value)) return 'staff';
            if (/掌|掌法/.test(value)) return 'palm';
            if (/指|指法/.test(value)) return 'finger';
            if (/拳|冲撞|猛击|重击|打击/.test(value)) return 'fist';
            if (/内力|真气|内功|神功|心法|本能|狂意/.test(value)) return 'inner-power';
            if (/【方】|灵/.test(value)) return 'spirit';
            return null;
        },

        getSkillAnimationTarget(skillType, text = '') {
            const value = String(text || '');
            const playerCast = /你(?:紧握.*?)?(?:施展|施放|使出|发动|祭起|召唤)/.test(value);
            const affectsPlayer = /对你|为你恢复|你的这次攻击/.test(value);
            const selfTypes = ['heal', 'summon', 'buff', 'inner-power', 'lightness', 'dodge', 'block'];
            if (selfTypes.includes(skillType)) {
                return playerCast || affectsPlayer ? 'player' : 'enemy';
            }
            return affectsPlayer && !value.includes('你对') ? 'player' : 'enemy';
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
                'wind': 950, 'spirit': 1100, 'generic': 900
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
                'spirit': 'skill-spirit-orbit', 'generic': 'skill-generic-cast'
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
                'wind': '🌪️', 'spirit': '☯️', 'generic': '✦'
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
                'spirit': 'spirit-orbit-icon', 'generic': 'generic-cast-icon'
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
            }
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

            try {
                const txd = sessionStorage.getItem('mud_txd') || this.txd;
                if (!txd) {
                    alert('请先登录');
                    this.showPerformsList = false;
                    return;
                }

                const response = await fetch(`${this.apiBase}/api/performs?txd=${encodeURIComponent(txd)}`);
                const data = await response.json();

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
                console.error('获取招式列表失败:', e);
                this.performsData = {
                    performs: [],
                    skill_name_cn: '错误',
                    message: '网络错误'
                };
            } finally {
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

    mounted() {
        // 保存实例到全局以便HTML中的onclick调用
        window.vueInstance = this;

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

        // 检测HTML模式（兼容自动浏览器）
        const modeParam = urlParams.get('mode');
        if (modeParam === 'html') {
            this.htmlMode = true;
            console.log('HTML模式已启用：按钮使用href链接');
        }
        if (refParam) {
            this.refCode = refParam;
            console.log('检测到推荐码:', refParam);
            // 保存到localStorage，注册时使用
            localStorage.setItem('ref_code', refParam);
            console.log('推荐码已保存到localStorage');
        } else {
            console.log('未检测到推荐码参数');
        }

        // 保存URL中的txd（优先于sessionStorage）
        let savedTxd = null;
        let txdFromUrl = false;  // 标记txd是否来自URL
        if (txdParam) {
            savedTxd = txdParam;
            txdFromUrl = true;
            console.log('检测到URL中的txd参数，将用于自动登录');
        } else {
            // 尝试从 sessionStorage 恢复登录状态
            savedTxd = sessionStorage.getItem('mud_txd');
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

        // 恢复快捷菜单折叠状态
        const savedQuickActionsCollapsed = localStorage.getItem('quickActionsCollapsed');
        this.quickActionsCollapsed = savedQuickActionsCollapsed !== '0';

        console.log('API地址:', this.apiBase);

        // 生成验证码
        this.refreshCaptcha();

        // 加载分区列表
        this.loadPartitions();

        // 添加页面可见性监听（用于移动端后台恢复）
        document.addEventListener('visibilitychange', () => {
            if (document.visibilityState === 'visible') {
                console.log('[页面恢复] 刷新状态并检查自动战斗');
                // 页面回到前台，立即刷新状态
                this.fetchPlayerStats();
                // 如果自动战斗定时器存在，确保它继续运行
                if (this.autofightInterval && this.playerStats && this.playerStats.autofight) {
                    console.log('[自动战斗] 确认定时器运行中');
                }
            }
        });

        // 点击外部关闭菜单
        document.addEventListener('click', (e) => {
            const headerMenu = document.querySelector('.header-menu-container');
            if (headerMenu && !headerMenu.contains(e.target)) {
                this.headerMenuOpen = false;
            }
        });

        // 尝试从 sessionStorage 恢复分区和用户名（txd已经在前面处理）
        const savedPartition = sessionStorage.getItem('mud_partition');
        const savedUser = sessionStorage.getItem('mud_userid');

        // 自动登录条件：有txd且（来自URL 或 有保存的用户信息）
        if (savedTxd && (txdFromUrl || savedUser)) {
            // 有保存的登录信息或URL中有txd，自动恢复
            this.txd = savedTxd;
            this.loginForm.partition = savedPartition || 'tx01';
            this.loginForm.userid = savedUser || '';  // URL模式可能没有用户名

            console.log('apiBase=', this.apiBase);

            // 如果txd来自URL，保存到sessionStorage以便后续使用
            if (txdFromUrl) {
                sessionStorage.setItem('mud_txd', savedTxd);
                if (savedPartition) {
                    sessionStorage.setItem('mud_partition', savedPartition);
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
