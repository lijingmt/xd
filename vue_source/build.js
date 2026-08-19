#!/usr/bin/env node
/**
 * Vue前端构建脚本
 *
 * 功能：
 * 1. 编译/复制文件到 web/web_vue/ 和 vue_source/dist/ 目录
 * 2. 生成版本号
 *
 * 源码位置：vue_source/ (当前目录)
 * 输出位置：web/web_vue/
 */

const fs = require('fs');
const path = require('path');
const { createManifest } = require('./manifest');
const { writeWorldMap } = require('../scripts/build/generate_world_map');

// 颜色输出
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m'
};

function log(msg, color = 'reset') {
  console.log(`${colors[color]}${msg}${colors.reset}`);
}

// 输出目录: web/web_vue/
const distDir = path.join(__dirname, '..', 'web', 'web_vue');
const legacyDistDir = path.join(__dirname, 'dist');
if (!fs.existsSync(distDir)) {
  fs.mkdirSync(distDir, { recursive: true });
}

// 版本号
const version = `v${Date.now()}`;
log(`构建版本: ${version}`, 'blue');

// 复制文件
function copyFile(src, dest, transform = null) {
  const content = fs.readFileSync(src, 'utf8');
  const processed = transform ? transform(content) : content;
  fs.writeFileSync(dest, processed);
  log(`✓ ${path.basename(src)}`, 'green');
}

// 处理HTML - 注入版本号
function processHTML(content) {
  return content.replace(/\?v=BUILD_VERSION/g, `?v=${version}`);
}

// PC入口与手机版共用同一份Vue模板，只注入桌面标识和隔离样式。
// 这样业务功能不会分叉，index.html也不会加载任何PC专属CSS。
function processPcHTML(content) {
  return processHTML(content
    .replace('<html lang="zh-CN">', '<html lang="zh-CN" data-client-layout="pc">')
    .replace('<title>仙道</title>', '<title>仙道 · 桌面版</title>')
    .replace(
      '<link rel="stylesheet" href="css/realm.css?v=BUILD_VERSION">',
      '<link rel="stylesheet" href="css/realm.css?v=BUILD_VERSION">\n    <link rel="stylesheet" href="css/pc.css?v=BUILD_VERSION">'
    ));
}

// 构建步骤
log('开始构建...', 'blue');

// 1. 复制HTML
log('\n1. HTML:', 'yellow');
copyFile(path.join(__dirname, 'index.html'), path.join(distDir, 'index.html'), processHTML);
copyFile(path.join(__dirname, 'index.html'), path.join(distDir, 'pc.html'), processPcHTML);

// 2. 复制并处理CSS
log('\n2. CSS:', 'yellow');
fs.mkdirSync(path.join(distDir, 'css'), { recursive: true });
copyFile(path.join(__dirname, 'css', 'app.css'), path.join(distDir, 'css', 'app.css'));
copyFile(path.join(__dirname, 'css', 'realm.css'), path.join(distDir, 'css', 'realm.css'));
copyFile(path.join(__dirname, 'css', 'pc.css'), path.join(distDir, 'css', 'pc.css'));

// 3. 复制JS
log('\n3. JS:', 'yellow');
fs.mkdirSync(path.join(distDir, 'js'), { recursive: true });
copyFile(path.join(__dirname, 'js', 'app.js'), path.join(distDir, 'js', 'app.js'));

// 3.1 从真实房间源码生成完整世界拓扑。客户端只读取房间名称、区域、
// 地貌、坐标和连接关系；移动仍必须使用当前房间返回的隐藏命令。
log('\n3.1 World map graph:', 'yellow');
const worldMapSource = path.join(__dirname, 'data', 'world-map.json');
const worldMap = writeWorldMap(
  path.join(__dirname, '..', 'gamelib', 'd'),
  worldMapSource
);
fs.mkdirSync(path.join(distDir, 'data'), { recursive: true });
fs.copyFileSync(worldMapSource, path.join(distDir, 'data', 'world-map.json'));
log(`✓ ${worldMap.roomCount} rooms / ${worldMap.edgeCount} links / ${worldMap.regionCount} regions`, 'green');

// 4. 复制锁定版本的浏览器运行库和许可证（生产环境不依赖公共CDN）
log('\n4. Vendored runtime:', 'yellow');
fs.mkdirSync(path.join(distDir, 'vendor'), { recursive: true });
const vendorFiles = [
  ['vue/dist/vue.global.prod.js', 'vue.global.prod.js'],
  ['vue/LICENSE', 'VUE_LICENSE.txt'],
  ['canvas-confetti/dist/confetti.browser.js', 'canvas-confetti.js'],
  ['canvas-confetti/LICENSE', 'CANVAS_CONFETTI_LICENSE.txt'],
  ['howler/dist/howler.core.min.js', 'howler.core.min.js'],
  ['howler/LICENSE.md', 'HOWLER_LICENSE.txt'],
  ['@formkit/auto-animate/index.min.js', 'auto-animate.min.js'],
  ['@formkit/auto-animate/LICENSE', 'AUTO_ANIMATE_LICENSE.txt'],
  ['driver.js/dist/driver.js.iife.js', 'driver.iife.js'],
  ['driver.js/dist/driver.css', 'driver.css'],
  ['driver.js/license', 'DRIVER_LICENSE.txt']
];
for (const [sourcePath, outputName] of vendorFiles) {
  copyFile(
    path.join(__dirname, 'node_modules', sourcePath),
    path.join(distDir, 'vendor', outputName)
  );
}

// 5. 复制favicon
log('\n5. Favicon:', 'yellow');
const faviconSrc = path.join(__dirname, 'favicon.ico');
const faviconDest = path.join(distDir, 'favicon.ico');
if (!fs.existsSync(faviconSrc)) {
  throw new Error(`favicon source not found: ${faviconSrc}`);
}
fs.copyFileSync(faviconSrc, faviconDest);
log('✓ favicon.ico', 'green');

// 6. 生成manifest.json (PWA支持)
log('\n6. Manifest:', 'yellow');
const manifest = createManifest(version);
fs.writeFileSync(
  path.join(distDir, 'manifest.json'),
  JSON.stringify(manifest, null, 2) + '\n'
);
log('✓ manifest.json', 'green');

// 7. 同步历史 dist 入口，避免旧部署脚本继续发布过期资源
log('\n7. Legacy dist:', 'yellow');
const legacyFiles = [
  'index.html',
  'pc.html',
  'manifest.json',
  'favicon.ico',
  path.join('css', 'app.css'),
  path.join('css', 'realm.css'),
  path.join('css', 'pc.css'),
  path.join('js', 'app.js'),
  path.join('data', 'world-map.json'),
  path.join('vendor', 'vue.global.prod.js'),
  path.join('vendor', 'VUE_LICENSE.txt'),
  path.join('vendor', 'canvas-confetti.js'),
  path.join('vendor', 'CANVAS_CONFETTI_LICENSE.txt'),
  path.join('vendor', 'howler.core.min.js'),
  path.join('vendor', 'HOWLER_LICENSE.txt'),
  path.join('vendor', 'auto-animate.min.js'),
  path.join('vendor', 'AUTO_ANIMATE_LICENSE.txt'),
  path.join('vendor', 'driver.iife.js'),
  path.join('vendor', 'driver.css'),
  path.join('vendor', 'DRIVER_LICENSE.txt')
];
for (const relativePath of legacyFiles) {
  const sourcePath = path.join(distDir, relativePath);
  const destinationPath = path.join(legacyDistDir, relativePath);
  fs.mkdirSync(path.dirname(destinationPath), { recursive: true });
  fs.copyFileSync(sourcePath, destinationPath);
}
log('✓ vue_source/dist', 'green');

// 8. 同步S1九卷母版与81张独立章节插画到本地Tomcat的 web/images。
// Docker仍从同一份根目录 images/ 打包；这里保证非Docker本地环境与
// 生产镜像看到完全相同的静态资源。
log('\n8. Illusion story artwork:', 'yellow');
const storySourceDir = path.join(__dirname, '..', 'images', 'illusion_s1', 'story');
const storyOutputDir = path.join(__dirname, '..', 'web', 'images', 'illusion_s1', 'story');
const storyChapterSourceDir = path.join(storySourceDir, 'chapters');
const storyChapterOutputDir = path.join(storyOutputDir, 'chapters');
const storyFiles = fs.existsSync(storySourceDir)
  ? fs.readdirSync(storySourceDir).filter((name) => /^volume_0[1-9]\.png$/.test(name)).sort()
  : [];
if (storyFiles.length !== 9) {
  throw new Error(`expected exactly 9 S1 story atlases, found ${storyFiles.length}`);
}
fs.mkdirSync(storyOutputDir, { recursive: true });
for (const filename of storyFiles) {
  const sourcePath = path.join(storySourceDir, filename);
  const destinationPath = path.join(storyOutputDir, filename);
  if (fs.statSync(sourcePath).size < 1024 * 1024) {
    throw new Error(`story atlas is unexpectedly small: ${sourcePath}`);
  }
  fs.copyFileSync(sourcePath, destinationPath);
	log(`✓ ${filename}`, 'green');
}
const storyChapterFiles = fs.existsSync(storyChapterSourceDir)
  ? fs.readdirSync(storyChapterSourceDir).filter((name) => /^chapter_0(?:[0-7][0-9]|8[01])\.png$/.test(name)).sort()
  : [];
if (storyChapterFiles.length !== 81) {
  throw new Error(`expected exactly 81 S1 chapter illustrations, found ${storyChapterFiles.length}`);
}
fs.mkdirSync(storyChapterOutputDir, { recursive: true });
for (let chapter = 1; chapter <= 81; chapter += 1) {
  const filename = `chapter_${String(chapter).padStart(3, '0')}.png`;
  if (storyChapterFiles[chapter - 1] !== filename) {
    throw new Error(`missing sequential S1 chapter illustration: ${filename}`);
  }
  const sourcePath = path.join(storyChapterSourceDir, filename);
  const destinationPath = path.join(storyChapterOutputDir, filename);
  if (fs.statSync(sourcePath).size < 200 * 1024) {
    throw new Error(`chapter illustration is unexpectedly small: ${sourcePath}`);
  }
  fs.copyFileSync(sourcePath, destinationPath);
}
log('✓ chapter_001.png ... chapter_081.png', 'green');

// 9. 同步PC实时地图首张原创场景。它与S1剧情图一样从根目录
// images/ 进入Docker，同时复制到本地Tomcat的 web/images/。
log('\n9. Visual map artwork:', 'yellow');
const visualMapSource = path.join(
  __dirname, '..', 'images', 'visual_map', 'red-cloud-terrace-v1.webp'
);
const visualMapOutput = path.join(
  __dirname, '..', 'web', 'images', 'visual_map', 'red-cloud-terrace-v1.webp'
);
if (!fs.existsSync(visualMapSource)) {
  throw new Error(`visual map source not found: ${visualMapSource}`);
}
const visualMapSize = fs.statSync(visualMapSource).size;
if (visualMapSize < 100 * 1024 || visualMapSize > 700 * 1024) {
  throw new Error(`visual map source is not web-sized: ${visualMapSize} bytes`);
}
fs.mkdirSync(path.dirname(visualMapOutput), { recursive: true });
fs.copyFileSync(visualMapSource, visualMapOutput);
log('✓ red-cloud-terrace-v1.webp', 'green');

const terrainAtlasSource = path.join(
  __dirname, '..', 'images', 'visual_map', 'world-terrain-atlas-v1.webp'
);
const terrainAtlasOutput = path.join(
  __dirname, '..', 'web', 'images', 'visual_map', 'world-terrain-atlas-v1.webp'
);
if (!fs.existsSync(terrainAtlasSource)) {
  throw new Error(`terrain atlas source not found: ${terrainAtlasSource}`);
}
const terrainAtlasSize = fs.statSync(terrainAtlasSource).size;
if (terrainAtlasSize < 200 * 1024 || terrainAtlasSize > 900 * 1024) {
  throw new Error(`terrain atlas is not web-sized: ${terrainAtlasSize} bytes`);
}
fs.copyFileSync(terrainAtlasSource, terrainAtlasOutput);
log('✓ world-terrain-atlas-v1.webp', 'green');

// 完成
log('\n✓ 构建完成!', 'green');
log(`输出目录: ${distDir}`, 'blue');
