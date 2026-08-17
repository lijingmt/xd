const assert = require('assert');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');

assert(
    html.includes("sendQuickCommand('illusion_realm')") &&
        html.includes('<span>🌙</span>幻境任务'),
    'Vue more menu must keep a visible one-click illusion task entry'
);

console.log('幻境任务全局入口UI测试通过：1项通过');
