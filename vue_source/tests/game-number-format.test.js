const assert = require('assert');
const fs = require('fs');
const path = require('path');

const formatter = require('../../web/includes/game-number-format.js');
const root = path.resolve(__dirname, '../..');

assert.strictEqual(formatter.formatNumber(9999), '9,999');
assert.strictEqual(formatter.formatNumber(10000), '1万');
assert.strictEqual(formatter.formatNumber(12345), '1.23万');
assert.strictEqual(formatter.formatNumber(124000), '12.4万');
assert.strictEqual(formatter.formatNumber(1000000), '100万');
assert.strictEqual(formatter.formatNumber(3898800), '390万');
assert.strictEqual(formatter.formatNumber(2100000000), '21亿');
assert.strictEqual(formatter.formatNumber(99999999), '1亿');
assert.strictEqual(formatter.formatNumber(5858319000000), '5.86万亿');
assert.strictEqual(formatter.formatNumber(1e16), '1京');
assert.strictEqual(formatter.formatNumber(1e20), '1垓');
assert.strictEqual(formatter.formatNumber(1e24), '1秭');
assert.strictEqual(formatter.formatNumber(1e28), '1穰');
assert.strictEqual(formatter.formatNumber(-124000), '-12.4万');
assert.strictEqual(formatter.formatNumber(124000, { compact: false }), '124,000');
assert.strictEqual(formatter.formatExactNumber('12345678901234567890'), '12,345,678,901,234,567,890');
assert(!formatter.UNITS.some(unit => unit.label === '兆'), '不使用有地区歧义的“兆”');

const battleText = formatter.formatText('伤害123456点，经验2100000000');
assert(battleText.includes('12.3万'));
assert(battleText.includes('21亿'));
assert(battleText.includes('精确值：123,456'));
assert(battleText.includes('精确值：2,100,000,000'));

assert.strictEqual(formatter.formatText('QQ:1811117272'), 'QQ:1811117272');
assert.strictEqual(formatter.formatText('账号：123456789'), '账号：123456789');
assert.strictEqual(formatter.formatText('订单号 20260808123456'), '订单号 20260808123456');
assert.strictEqual(formatter.formatText('日期 20260808'), '日期 20260808');
assert.strictEqual(formatter.formatText('Lv.10000'), 'Lv.10000');
assert.strictEqual(formatter.formatText('10000级'), '10000级');
assert.strictEqual(formatter.formatText('坐标：12345,67890'), '坐标：12345,67890');
assert.strictEqual(formatter.formatText('已有12.4万经验'), '已有12.4万经验');
assert.strictEqual(formatter.formatText('编号：00123456'), '编号：00123456');
assert.strictEqual(formatter.formatText('CMD:DYNAMIC_INVITE_LINK:12345678'), 'CMD:DYNAMIC_INVITE_LINK:12345678');
assert.strictEqual(
    formatter.formatText('https://example.com/pay/123456789'),
    'https://example.com/pay/123456789'
);
assert(formatter.formatText('小还丹x10000').includes('小还丹x<span'));
assert(formatter.formatText('小还丹x10000').includes('1万'));
assert.strictEqual(
    formatter.formatText('伤害123456点', { compact: false }),
    '伤害123456点'
);
const escapedText = formatter.formatText('<img src=x onerror=alert(1)>伤害123456点', {
    allowHtml: false
});
assert(escapedText.startsWith('&lt;img src=x onerror=alert(1)&gt;'));
assert(escapedText.includes('12.3万'));
assert.strictEqual(
    formatter.formatText('<a href="/cmd?value=123456">获得123456银两</a>'),
    '<a href="/cmd?value=123456">获得<span class="game-number-compact" title="精确值：123,456" aria-label="精确值 123,456">12.3万</span>银两</a>'
);

const indexSource = fs.readFileSync(path.join(root, 'vue_source/index.html'), 'utf8');
const appSource = fs.readFileSync(path.join(root, 'vue_source/js/app.js'), 'utf8');
const legacyFilters = [
    'lowlib/system/filter/html5.pike',
    'lowlib/system/filter/html6.pike',
    'lowlib/system/filter/html6_dark.pike',
    'lowlib/system/filter/html6 copy.pike'
];

assert(indexSource.includes('../includes/game-number-format.js?v=BUILD_VERSION'));
assert(indexSource.includes('data-auto-format="false"'));
assert(indexSource.includes('v-html="renderGameText(segment.label, true)"'));
assert(appSource.includes('formatGameNumber(value, options = {})'));
assert(appSource.includes('renderGameText(value, allowHtml = false)'));
legacyFilters.forEach(relativePath => {
    const source = fs.readFileSync(path.join(root, relativePath), 'utf8');
    assert(source.includes('includes/game-number-format.js'), `${relativePath} 未接入统一数值格式器`);
});

console.log('game-number-format tests passed');
