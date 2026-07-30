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

// 构建步骤
log('开始构建...', 'blue');

// 1. 复制HTML
log('\n1. HTML:', 'yellow');
copyFile(path.join(__dirname, 'index.html'), path.join(distDir, 'index.html'), processHTML);

// 2. 复制并处理CSS
log('\n2. CSS:', 'yellow');
fs.mkdirSync(path.join(distDir, 'css'), { recursive: true });
copyFile(path.join(__dirname, 'css', 'app.css'), path.join(distDir, 'css', 'app.css'));
copyFile(path.join(__dirname, 'css', 'realm.css'), path.join(distDir, 'css', 'realm.css'));

// 3. 复制JS
log('\n3. JS:', 'yellow');
fs.mkdirSync(path.join(distDir, 'js'), { recursive: true });
copyFile(path.join(__dirname, 'js', 'app.js'), path.join(distDir, 'js', 'app.js'));

// 4. 复制锁定版本的Vue运行库和许可证
log('\n4. Vendored runtime:', 'yellow');
fs.mkdirSync(path.join(distDir, 'vendor'), { recursive: true });
copyFile(
  path.join(__dirname, 'node_modules', 'vue', 'dist', 'vue.global.prod.js'),
  path.join(distDir, 'vendor', 'vue.global.prod.js')
);
copyFile(
  path.join(__dirname, 'node_modules', 'vue', 'LICENSE'),
  path.join(distDir, 'vendor', 'VUE_LICENSE.txt')
);

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
  'manifest.json',
  'favicon.ico',
  path.join('css', 'app.css'),
  path.join('css', 'realm.css'),
  path.join('js', 'app.js'),
  path.join('vendor', 'vue.global.prod.js'),
  path.join('vendor', 'VUE_LICENSE.txt')
];
for (const relativePath of legacyFiles) {
  const sourcePath = path.join(distDir, relativePath);
  const destinationPath = path.join(legacyDistDir, relativePath);
  fs.mkdirSync(path.dirname(destinationPath), { recursive: true });
  fs.copyFileSync(sourcePath, destinationPath);
}
log('✓ vue_source/dist', 'green');

// 完成
log('\n✓ 构建完成!', 'green');
log(`输出目录: ${distDir}`, 'blue');
