// inventory_cleanup_entry_test.mjs — 背包一键清套装入口真实环境测试
// 层1：老WAP socket协议（html6数字链接 + html5命令串）
// 层2：HTTP /api/html（Vue/APP管线）
// 账号与socket测试共用，两阶段串行执行，避免会话互踩。
import net from 'net';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const HOST = process.env.MUD_HOST || '127.0.0.1';
const PORT = parseInt(process.env.MUD_PORT || '13800', 10);
const HTTP_PORT = parseInt(process.env.MUD_HTTP_PORT || '8888', 10);
const USER = process.env.MUD_USER || 'xd01uisocket01';
const PASS = process.env.MUD_PASS || 'uisocket88';
const LOGIN_LINE = `login gamelib ${USER} ${PASS} unknown`;

let passed = 0, failed = 0;
function ok(name, cond, detail) {
  if (cond) { passed++; console.log(`  ✓ ${name}`); }
  else { failed++; console.log(`  ✗ ${name}${detail ? ' — ' + String(detail).replace(/\s+/g, ' ').slice(0, 220) : ''}`); }
}

function socketPage(cmds, filter = 'html6', timeout = 20000) {
  return new Promise((resolve) => {
    const sock = net.createConnection({ host: HOST, port: PORT });
    let buf = '';
    const timer = setTimeout(() => { sock.destroy(); resolve(buf); }, timeout);
    sock.on('connect', () => {
      sock.write([
        `set_filter ${filter} ./game.jsp 仙道wapmud`,
        LOGIN_LINE, ...cmds, 'flush_filter',
      ].join('\n') + '\n');
    });
    sock.on('data', (d) => { buf += d.toString('utf8'); });
    sock.on('close', () => { clearTimeout(timer); resolve(buf); });
    sock.on('error', (e) => { clearTimeout(timer); resolve(buf + '\n[SOCKERR]' + e.message); });
  });
}

function pageText(html) {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ');
}
function extractNumLinks(html) {
  const links = [];
  const re = /<a[^>]*href=(["'])(.*?)\1[^>]*>([\s\S]*?)<\/a>/gi;
  let m;
  while ((m = re.exec(html))) {
    const label = m[3].replace(/<[^>]+>/g, '').trim();
    const num = m[2].match(/_cmd=(\d+)/);
    if (label && num) links.push({ label, num: num[1] });
  }
  return links;
}
function extractCmdLinks(html) {
  const links = [];
  const re = /<a[^>]*href=(["'])(.*?)\1[^>]*>([\s\S]*?)<\/a>/gi;
  let m;
  while ((m = re.exec(html))) {
    const label = m[3].replace(/<[^>]+>/g, '').trim();
    const cm = m[2].match(/_cmd=([^&']*)/);
    if (label && cm) {
      const cmd = decodeURIComponent(cm[1].replace(/\+/g, ' ').replace(/&amp;/g, '&')).trim();
      if (cmd && !/^\d+$/.test(cmd)) links.push({ label, cmd });
    }
  }
  return links;
}
const looksLikeRoom = (t) =>
  /你站在|这里明显的出口/.test(t) && !t.includes('套装管理') && !t.includes('一键套装清理');

async function httpPage(cmd) {
  const url = `http://${HOST}:${HTTP_PORT}/api/html?userid=${encodeURIComponent(USER)}` +
    `&password=${encodeURIComponent(PASS)}&cmd=${encodeURIComponent(cmd)}`;
  const res = await fetch(url);
  return res.text();
}

const GAP = 3200;
async function main() {
  console.log(`=== 背包一键清套装入口测试 (${USER}) ===`);

  // ===== 层1：老WAP socket（html6数字链接） =====
  await socketPage(['autofight off']);
  await sleep(GAP);

  const inv = await socketPage(['inventory']);
  await sleep(GAP);
  const invText = pageText(inv);
  ok('[socket] inventory页渲染成功', invText.includes('装备背包') || invText.includes('随身物品'), invText.slice(0, 160));
  ok('[socket] inventory页含[一键清理重复套装]按钮', invText.includes('一键清理重复套装'), invText.slice(0, 260));

  const invLinks = extractNumLinks(inv);
  const cleanupLink = invLinks.find((l) => l.label.includes('一键清理重复套装'));
  ok('[socket] 按钮已转成数字链接', !!cleanupLink,
    JSON.stringify(invLinks.map((l) => l.label).slice(0, 10)));
  if (cleanupLink) {
    const clickPage = await socketPage([cleanupLink.num]);
    await sleep(GAP);
    const ct = pageText(clickPage);
    ok('[socket] 点击后进入清套装流程（空态或执行页）',
      ct.includes('没有可清理的重复套装件') || ct.includes('一键套装清理') || ct.includes('套装管理'),
      ct.slice(0, 180));
    ok('[socket] 点击后不退回房间描述', !looksLikeRoom(ct), ct.slice(0, 160));
  }

  // ===== 层1b：html5命令串直传变体 =====
  const inv5 = await socketPage(['inventory'], 'html5');
  await sleep(GAP);
  const cmdLinks = extractCmdLinks(inv5);
  const cleanup5 = cmdLinks.find((l) => l.cmd === 'set_equipment_cleanup sell');
  ok('[socket/html5] 链接为命令串 set_equipment_cleanup sell', !!cleanup5,
    JSON.stringify(cmdLinks.slice(0, 6)));

  // ===== 层2：HTTP /api/html（Vue/APP管线） =====
  const hInv = await httpPage('inventory');
  await sleep(1500);
  const hInvText = pageText(hInv);
  ok('[http] inventory页渲染成功', hInvText.includes('装备背包') || hInvText.includes('随身物品'), hInvText.slice(0, 160));
  ok('[http] inventory页含[一键清理重复套装]按钮', hInvText.includes('一键清理重复套装'), hInvText.slice(0, 260));
  // HTTP管线按钮href是不可变命令令牌(c_哈希)，模拟浏览器点击该href
  const hMatch = hInv.match(/<a href="([^"]*)"[^>]*>一键清理重复套装<\/a>/);
  ok('[http] 按钮href为不可变命令令牌链接', !!hMatch && /c_[0-9a-f]{20,}/.test(hMatch[1]),
    hMatch ? hMatch[1].slice(0, 120) : 'href未找到');
  if (hMatch) {
    const clickRes = await fetch(`http://${HOST}:${HTTP_PORT}${hMatch[1].replace(/&amp;/g, '&')}`);
    const clickText = pageText(await clickRes.text());
    await sleep(1500);
    ok('[http] 浏览器式点击href进入清套装流程',
      clickText.includes('没有可清理的重复套装件') || clickText.includes('一键套装清理') || clickText.includes('套装管理'),
      clickText.slice(0, 180));
    ok('[http] 点击后不退回房间描述', !looksLikeRoom(clickText), clickText.slice(0, 160));
  }

  const hSell = await httpPage('set_equipment_cleanup sell');
  await sleep(1500);
  const hSellText = pageText(hSell);
  ok('[http] 命令直达进入清套装流程',
    hSellText.includes('没有可清理的重复套装件') || hSellText.includes('一键套装清理') || hSellText.includes('套装管理'),
    hSellText.slice(0, 180));
  ok('[http] 响应不退回房间描述', !looksLikeRoom(hSellText), hSellText.slice(0, 160));

  console.log(`\n结果: ${passed} 通过, ${failed} 失败`);
  process.exit(failed > 0 ? 1 : 0);
}
main();
