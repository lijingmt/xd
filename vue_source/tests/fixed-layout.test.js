/**
 * 建议9 固定排版回归：网页与客户端同口径按屏幕宽度自动选字号档。
 */
const assert = require('assert');
const fs = require('fs');
const path = require('path');

const sourceDir = path.join(__dirname, '..');
const appJs = fs.readFileSync(path.join(sourceDir, 'js', 'app.js'), 'utf8');
const html = fs.readFileSync(path.join(sourceDir, 'index.html'), 'utf8');
const packageJson = JSON.parse(
  fs.readFileSync(path.join(sourceDir, 'package.json'), 'utf8')
);

assert(
  appJs.includes('fontFixedLayout: false') &&
  appJs.includes("localStorage.getItem('mud_font_fixed') === '1'") &&
  appJs.includes("localStorage.setItem('mud_font_fixed',"),
  'fixed layout state must persist via mud_font_fixed'
);

assert(
  appJs.includes('toggleFixedLayout()') &&
  appJs.includes('handleFixedLayoutResize()') &&
  appJs.includes("window.addEventListener('resize',") &&
  appJs.includes(
    "window.removeEventListener('resize', this.handleFixedLayoutResize);"),
  'fixed layout must re-derive on resize and clean up its listener'
);

// 与客户端 fixedLayoutScale 同口径：390px 基准、四档边界。
assert(
  appJs.includes('window.innerWidth / 390') &&
  appJs.includes("ratio <= 0.92 ? 'small'") &&
  appJs.includes("ratio <= 1.05 ? 'normal'") &&
  appJs.includes("ratio <= 1.28 ? 'large'") &&
  appJs.includes("'xlarge'"),
  'fixed layout must derive the four font tiers from viewport width'
);

// 手动档位保留：固定排版只覆盖展示，切回自适应即恢复原选择。
assert(
  appJs.includes('applyFontSize()') &&
  appJs.includes("localStorage.setItem('mud_font_size', this.fontSize);"),
  'manual font choice must survive fixed-layout mode'
);

assert(
  html.includes('toggleFixedLayout') &&
  html.includes('固定（按屏幕自动适配）') &&
  html.includes('自适应（手动字号）'),
  'settings menu must expose the layout-mode toggle'
);

assert(
  packageJson.scripts.test.includes('node tests/fixed-layout.test.js'),
  'fixed layout test must run in npm test'
);

console.log('Fixed layout tests passed.');
