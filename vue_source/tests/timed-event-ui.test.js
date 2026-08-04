const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const app = fs.readFileSync(path.join(root, 'js/app.js'), 'utf8');
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const css = fs.readFileSync(path.join(root, 'css/app.css'), 'utf8');

const checks = [
    ['状态轮询接收限时活动', app.includes('syncTimedEventInvite(data.timed_event)')],
    ['每人物每场会话去重', app.includes('timed_event_seen:${character}:${invite?.popup_id')],
    ['集结弹窗提供规则和进入动作', html.includes('timed-event-invite-title') &&
        html.includes('@click="enterTimedEvent"') && html.includes('@click="openTimedEventDetails"')],
    ['更多菜单保留限时玩法入口', html.includes("sendQuickCommand('timed_event')")],
    ['弹窗适配动态视口和减少动画偏好', css.includes('max-height: calc(100dvh - 28px)') &&
        css.includes('@media (prefers-reduced-motion: reduce)')],
    ['公平提示明确不售卖战斗优势', html.includes('VIP 不增加属性、奖励倍率或每日次数')]
];

let failed = 0;
for (const [name, ok] of checks) {
    if (ok) {
        console.log(`✓ ${name}`);
    } else {
        failed++;
        console.error(`✗ ${name}`);
    }
}

if (failed) process.exit(1);
console.log(`限时玩法UI测试完成：${checks.length}项通过`);
