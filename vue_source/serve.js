#!/usr/bin/env node
/**
 * Vue开发服务器
 *
 * 功能：
 * 1. 启动HTTP服务器
 * 2. 热重载支持
 * 3. 代理API请求到Xiand HTTP端口
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { createManifest } = require('./manifest');

const PORT = Number(process.env.XIAND_VUE_PORT || 3000);
const API_PORT = Number(process.env.XIAND_HTTP_PORT || 8888);
const STATIC_ROOT = path.resolve(__dirname);
const INCLUDES_ROOT = path.resolve(__dirname, '..', 'web', 'includes');
const DEV_BUILD_VERSION = `dev-${Date.now()}`;
const VENDOR_FILES = new Map([
  ['/vendor/vue.global.prod.js', 'vue/dist/vue.global.prod.js'],
  ['/vendor/VUE_LICENSE.txt', 'vue/LICENSE'],
  ['/vendor/canvas-confetti.js', 'canvas-confetti/dist/confetti.browser.js'],
  ['/vendor/CANVAS_CONFETTI_LICENSE.txt', 'canvas-confetti/LICENSE'],
  ['/vendor/howler.core.min.js', 'howler/dist/howler.core.min.js'],
  ['/vendor/HOWLER_LICENSE.txt', 'howler/LICENSE.md'],
  ['/vendor/auto-animate.min.js', '@formkit/auto-animate/index.min.js'],
  ['/vendor/AUTO_ANIMATE_LICENSE.txt', '@formkit/auto-animate/LICENSE'],
  ['/vendor/driver.iife.js', 'driver.js/dist/driver.js.iife.js'],
  ['/vendor/driver.css', 'driver.js/dist/driver.css'],
  ['/vendor/DRIVER_LICENSE.txt', 'driver.js/license']
]);

// MIME类型
const mimeTypes = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2'
};

const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  blue: '\x1b[34m',
  yellow: '\x1b[33m'
};

function log(msg, color = 'reset') {
  console.log(`${colors[color]}${msg}${colors.reset}`);
}

function isWithinRoot(root, target) {
  return target === root || target.startsWith(root + path.sep);
}

// 创建服务器
const server = http.createServer((req, res) => {
  // 处理API代理
  if (req.url.startsWith('/api')) {
    const options = {
      hostname: 'localhost',
      port: API_PORT,
      path: req.url,
      method: req.method,
      headers: req.headers
    };

    const proxyReq = http.request(options, (proxyRes) => {
      res.writeHead(proxyRes.statusCode, proxyRes.headers);
      proxyRes.pipe(res);
    });

    proxyReq.on('error', (err) => {
      res.writeHead(502, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'API服务器未启动，请先启动游戏服务器' }));
    });

    req.pipe(proxyReq);
    return;
  }

  let pathname;
  try {
    pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  } catch (error) {
    res.writeHead(400, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('无效请求');
    return;
  }

  if (pathname === '/manifest.json') {
    const body = JSON.stringify(createManifest(DEV_BUILD_VERSION), null, 2) + '\n';
    res.writeHead(200, {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-cache'
    });
    res.end(req.method === 'HEAD' ? undefined : body);
    return;
  }

  // /includes/* 映射到网页共享资源，其余文件只允许从vue_source读取。
  let filePath;
  if (VENDOR_FILES.has(pathname)) {
    filePath = path.join(__dirname, 'node_modules', VENDOR_FILES.get(pathname));
  } else if (pathname.startsWith('/includes/')) {
    filePath = path.resolve(INCLUDES_ROOT, '.' + pathname.slice('/includes'.length));
    if (!isWithinRoot(INCLUDES_ROOT, filePath)) {
      res.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('禁止访问');
      return;
    }
  } else {
    const relativePath = pathname === '/' ? 'index.html' : '.' + pathname;
    filePath = path.resolve(STATIC_ROOT, relativePath);
    if (!isWithinRoot(STATIC_ROOT, filePath)) {
      res.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('禁止访问');
      return;
    }
  }

  const ext = path.extname(filePath);
  const contentType = mimeTypes[ext] || 'text/plain';

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/html' });
      res.end('<h1>404 - 文件未找到</h1>');
      return;
    }

    let body = data;
    // Buffer先转为字符串，再替换统一构建版本占位符。
    if (ext === '.html') {
      body = data.toString('utf8').replace(/BUILD_VERSION/g, DEV_BUILD_VERSION);
    }

    res.writeHead(200, {
      'Content-Type': contentType + (ext === '.html' || ext === '.css' ||
        ext === '.js' || ext === '.json' ? '; charset=utf-8' : ''),
      'Cache-Control': 'no-cache'
    });
    if (req.method === 'HEAD')
      res.end();
    else
      res.end(body);
  });
});

server.listen(PORT, () => {
  log(`开发服务器启动: http://localhost:${PORT}`, 'green');
  log(`API代理: http://localhost:${API_PORT}`, 'blue');
  log('\n按 Ctrl+C 停止服务器', 'yellow');
});
