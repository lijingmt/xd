const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

let componentOptions = null;
const replacedUrls = [];
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
            protocol: 'https:', hostname: 'xd.example.com',
            host: 'xd.example.com', origin: 'https://xd.example.com',
            pathname: '/xd/vue/',
            href: 'https://xd.example.com/xd/vue/?old=1#game'
        },
        history: { replaceState(_state, _title, url) { replacedUrls.push(url); } },
        matchMedia() { return { matches: false }; },
        addEventListener() {}, removeEventListener() {}
    },
    document: { documentElement: { setAttribute() {} } },
    localStorage: {
        getItem() { return null; }, setItem() {}, removeItem() {}
    },
    sessionStorage: { getItem() { return null; }, setItem() {}, removeItem() {} },
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
vm.runInNewContext(appSource, sandbox, { filename: 'app.js' });
assert(componentOptions, 'Vue component should register');
const client = Object.assign(componentOptions.data(), componentOptions.methods);

assert.strictEqual(client.normalizeReferralCode(' XD01Friend '), 'XD01Friend');
assert.strictEqual(client.normalizeReferralCode('../bad'), '');
assert.strictEqual(
    client.buildReferralLink('XD01Friend'),
    'https://xd.example.com/xd/vue/?register=1&ref=XD01Friend'
);
assert.strictEqual(client.applyReferralLanding('XD01Friend'), true);
assert.strictEqual(client.showRegister, true);
assert.strictEqual(client.showLogin, false);
assert.strictEqual(client.registerForm.referral, 'XD01Friend');
assert.strictEqual(client.refCode, 'XD01Friend');
assert.strictEqual(client.applyReferralLanding('../bad'), false);

client.clearReferralLanding();
assert.strictEqual(client.refCode, '');
assert.strictEqual(client.registerForm.referral, '');

client.registerForm.partition = 'xd01';
client.captchaCode = 'aB12';
client.registerForm.userid = 'newPlayer';
client.registerForm.password = 'Pass123';
client.registerForm.passwordConfirm = 'Pass123';
client.registerForm.captcha = 'Ab12';
client.registerForm.referral = '';
assert.strictEqual(
    client.registrationFirstError(),
    '',
    '邀请码留空时必须允许普通注册'
);
assert.strictEqual(client.registrationFieldError('referral'), '');
assert.strictEqual(client.registrationPasswordStrength(), 3);
assert.strictEqual(client.registrationFieldClass('userid'), 'field-valid');

client.registerForm.userid = '中文账号';
assert.strictEqual(client.registrationFieldError('userid'), '仅支持英文字母和数字');
client.registerForm.userid = 'newPlayer';
client.registerForm.passwordConfirm = 'different';
assert.strictEqual(client.registrationFirstError(), '两次输入的密码不一致');
client.registerForm.passwordConfirm = 'Pass123';
client.registerForm.captcha = 'nope';
assert.strictEqual(client.registrationFirstError(), '验证码不正确，点击右侧可换一张');
client.registerForm.captcha = 'Ab12';
client.registerForm.referral = '../bad';
assert.strictEqual(client.registrationFirstError(), '邀请码格式不正确，请检查或留空');
client.registerForm.referral = '';

client.inviteModalOpen = false;
client.accountId = 'xd01LSQ';
client.playerStats = { userid: 'xd01lsq' };
client.openInviteModal();
assert.strictEqual(client.inviteModalOpen, true);
assert.strictEqual(
    client.inviteLink,
    'https://xd.example.com/xd/vue/?register=1&ref=xd01LSQ'
);
assert.strictEqual(client.inviteCode, 'xd01LSQ');
client.closeInviteModal();
assert.strictEqual(client.inviteModalOpen, false);

assert(htmlSource.includes('v-model.trim="registerForm.referral"'));
assert(htmlSource.includes(':readonly="Boolean(refCode)"'));
assert(htmlSource.includes('没有邀请码可以留空'));
assert(htmlSource.includes('不使用邀请码，按普通账号注册'));
assert(htmlSource.includes('创建账号，下一步选人物'));
assert(htmlSource.includes('register-progress'));
assert(htmlSource.includes('@click="openInviteModal(); headerMenuOpen = false;"'));
assert(!appSource.includes('showInviteModal: false'));

console.log('邀请专属注册链接测试完成：自动开启、填码、链接清洗和弹窗状态通过');
