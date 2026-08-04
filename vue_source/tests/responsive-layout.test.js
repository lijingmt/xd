const assert = require('assert');
const fs = require('fs');
const path = require('path');

const sourceDir = path.join(__dirname, '..');
const css = fs.readFileSync(path.join(sourceDir, 'css', 'app.css'), 'utf8');
const html = fs.readFileSync(path.join(sourceDir, 'index.html'), 'utf8');
const packageJson = JSON.parse(
  fs.readFileSync(path.join(sourceDir, 'package.json'), 'utf8')
);

const responsiveStart = css.indexOf('Six-tier responsive shell (2026-08)');
assert(responsiveStart >= 0, 'missing unified responsive shell');
const responsiveCss = css.slice(responsiveStart);

const tiers = [
  {
    marker: 'Viewport tier 1/6: compact phones',
    min: 0,
    max: 359,
    media: '@media (max-width: 359px)',
    shell: '--ui-shell-width: 100%',
    columns: '--ui-more-columns: 4'
  },
  {
    marker: 'Viewport tier 2/6: mainstream phones',
    min: 360,
    max: 430,
    media: '@media (min-width: 360px) and (max-width: 430px)',
    shell: '--ui-shell-width: 100%',
    columns: '--ui-more-columns: 4'
  },
  {
    marker: 'Viewport tier 3/6: large phones',
    min: 431,
    max: 767,
    media: '@media (min-width: 431px) and (max-width: 767px)',
    shell: '--ui-shell-width: min(100%, 720px)',
    columns: '--ui-more-columns: 5'
  },
  {
    marker: 'Viewport tier 4/6: tablets',
    min: 768,
    max: 1023,
    media: '@media (min-width: 768px) and (max-width: 1023px)',
    shell: '--ui-shell-width: min(calc(100% - 20px), 920px)',
    columns: '--ui-more-columns: 6'
  },
  {
    marker: 'Viewport tier 5/6: laptops',
    min: 1024,
    max: 1439,
    media: '@media (min-width: 1024px) and (max-width: 1439px)',
    shell: '--ui-shell-width: min(calc(100% - 32px), 1080px)',
    columns: '--ui-more-columns: 8'
  },
  {
    marker: 'Viewport tier 6/6: wide desktop',
    min: 1440,
    max: Infinity,
    media: '@media (min-width: 1440px)',
    shell: '--ui-shell-width: min(calc(100% - 48px), 1280px)',
    columns: '--ui-more-columns: 8'
  }
];

for (const tier of tiers) {
  const markerIndex = responsiveCss.indexOf(tier.marker);
  assert(markerIndex >= 0, `missing marker: ${tier.marker}`);
  const nextMarkerIndex = responsiveCss.indexOf('Viewport tier ', markerIndex + 1);
  const block = responsiveCss.slice(
    markerIndex,
    nextMarkerIndex >= 0 ? nextMarkerIndex : responsiveCss.length
  );
  assert(block.includes(tier.media), `missing media query: ${tier.media}`);
  assert(block.includes(tier.shell), `missing shell rule: ${tier.marker}`);
  assert(block.includes(tier.columns), `missing tool-grid rule: ${tier.marker}`);
}

assert.strictEqual(
  (responsiveCss.match(/Viewport tier [1-6]\/6:/g) || []).length,
  6,
  'responsive tier markers must remain exactly six'
);

for (let width = 280; width <= 3840; width += 1) {
  const matches = tiers.filter((tier) => width >= tier.min && width <= tier.max);
  assert.strictEqual(
    matches.length,
    1,
    `viewport ${width}px must match exactly one responsive tier`
  );
}

const representativeWidths = [320, 390, 540, 820, 1280, 1920];
assert.deepStrictEqual(
  representativeWidths.map((width) =>
    tiers.findIndex((tier) => width >= tier.min && width <= tier.max) + 1
  ),
  [1, 2, 3, 4, 5, 6],
  'representative device widths must map to tiers 1 through 6'
);

for (const invariant of [
  'width: var(--ui-shell-width)',
  'overflow-y: auto',
  'overflow: visible',
  'flex: 1 0 auto',
  'scrollbar-gutter: stable both-edges',
  'max-width: var(--ui-reading-max)',
  'overflow-wrap: anywhere',
  'grid-template-columns: repeat(var(--ui-more-columns), minmax(0, 1fr))',
  'max-height: calc(100dvh - var(--ui-header-reserve) - 12px)',
  'width: min(var(--ui-battle-max), calc(100vw - 16px))',
  'right: max(0px, calc((100vw - var(--ui-shell-width)) / 2))',
  '@media (orientation: landscape) and (max-height: 600px)'
]) {
  assert(responsiveCss.includes(invariant), `missing responsive invariant: ${invariant}`);
}

const coreResponsiveCss = responsiveCss.slice(
  0,
  responsiveCss.indexOf('Viewport tier 1/6:')
);

function getResponsiveRule(selector) {
  const start = coreResponsiveCss.indexOf(`${selector} {`);
  assert(start >= 0, `missing responsive rule: ${selector}`);
  const end = coreResponsiveCss.indexOf('}', start);
  assert(end > start, `unterminated responsive rule: ${selector}`);
  return coreResponsiveCss.slice(start, end + 1);
}

assert(
  getResponsiveRule('html').includes('overflow-y: auto'),
  'the document root must own vertical scrolling'
);
for (const selector of ['body', '#app', '.game-frame-container']) {
  assert(
    getResponsiveRule(selector).includes('overflow: visible'),
    `${selector} must not create a competing scroll container`
  );
}
assert(
  !coreResponsiveCss.includes('overflow-y: hidden'),
  'the responsive document shell must never suppress vertical scrolling'
);

assert(
  html.includes(":class=\"{ 'has-header-pet': !!headerPet }\""),
  'header must compact cleanly when the current character has no active pet'
);
assert(
  responsiveCss.includes('Compact status header v3') &&
  responsiveCss.includes('grid-template-columns: 44px 38px minmax(0, 1fr) 38px') &&
  responsiveCss.includes('@media (min-width: 360px) and (max-width: 430px)') &&
  responsiveCss.includes('@media (min-width: 431px) and (max-width: 767px)') &&
  responsiveCss.includes('@media (min-width: 768px)'),
  'compact header must adapt across the six viewport tiers'
);
assert(
  !html.includes('class="player-fullid"') &&
  !html.includes('class="profession-assistant-badge"') &&
  html.includes('class="header-level-chip"') &&
  html.includes('class="header-profession-chip"'),
  'header must keep core identity while moving verbose controls into the menu'
);

assert(
  packageJson.scripts.test.includes('node tests/responsive-layout.test.js'),
  'responsive layout test must run in npm test'
);

console.log('Responsive layout tests passed for six viewport tiers.');
