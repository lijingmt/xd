// oldui_socket_test.mjs — 仙道老WAP socket协议级模拟测试
// 协议复刻自 web/game.jsp：set_filter html5 → login gamelib user pass ip → 命令 → flush_filter
// 一页一连接，读到关闭即整页输出。
import net from 'net';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const HOST = process.env.MUD_HOST || '127.0.0.1';
const PORT = parseInt(process.env.MUD_PORT || '13800', 10);
const USER = process.env.MUD_USER || 'xd01uisocket01';
const PASS = process.env.MUD_PASS || 'uisocket88';
// 老界面实际用 html6（数字链接 _cmd=N+，经hidden数组还原）；
// html5 是命令串直传变体，作为第二过滤器兼容性检查。
const FILTER = process.env.MUD_FILTER || 'html6';
const LOGIN_LINE = `login gamelib ${USER} ${PASS} unknown`;

let passed = 0, failed = 0;
function ok(name, cond, detail) {
  if (cond) { passed++; console.log(`  ✓ ${name}`); }
  else { failed++; console.log(`  ✗ ${name}${detail ? ' — ' + String(detail).replace(/\s+/g, ' ').slice(0, 220) : ''}`); }
}

// ===== 一页 = 一个socket连接（复刻JSP代理） =====
function requestPage(cmds, { login = true, timeout = 20000 } = {}) {
  return new Promise((resolve) => {
    const sock = net.createConnection({ host: HOST, port: PORT });
    let buf = '';
    const timer = setTimeout(() => { sock.destroy(); resolve(buf); }, timeout);
    sock.on('connect', () => {
      const lines = [`set_filter ${FILTER} ./game.jsp 仙道wapmud`];
      if (login) lines.push(LOGIN_LINE);
      lines.push(...cmds, 'flush_filter');
      sock.write(lines.join('\n') + '\n');
    });
    sock.on('data', (d) => { buf += d.toString('utf8'); });
    sock.on('close', () => { clearTimeout(timer); resolve(buf); });
    sock.on('error', (e) => { clearTimeout(timer); resolve(buf + '\n[SOCKERR]' + e.message); });
  });
}

// ===== 解析工具 =====
function pageText(html) {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ');
}
// 数字链接：老界面链接形式 href='..._cmd=N+...'，点击=发N
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
// html5命令串链接：href='..._cmd=命令+'，点击=JSP解码后直发命令
function extractCmdLinks(html) {
  const links = [];
  const re = /<a[^>]*href=(["'])(.*?)\1[^>]*>([\s\S]*?)<\/a>/gi;
  let m;
  while ((m = re.exec(html))) {
    const label = m[3].replace(/<[^>]+>/g, '').trim();
    const cm = m[2].match(/_cmd=([^&']*)/);
    if (label && cm) {
      const cmd = decodeURIComponent(cm[1].replace(/\+/g, ' ')
        .replace(/&amp;/g, '&')).trim();
      if (cmd && !/^\d+$/.test(cmd)) links.push({ label, cmd });
    }
  }
  return links;
}

const GAP = 3200; // 指令频率限制间隔

async function main() {
  console.log(`=== 仙道老界面Socket测试 (${USER}@${HOST}:${PORT}, filter=${FILTER}) ===`);

  // 0) 前置：关自动战斗（挂机会移动人物，房间命令失效）
  await requestPage(['autofight off']);
  await sleep(GAP);

  // 1) 登录+look
  const look = await requestPage(['look']);
  await sleep(GAP);
  const lookText = pageText(look);
  ok('登录+look成功（页面有内容且非登录错误）',
    lookText.length > 60 && !lookText.includes('登录错误'), lookText.slice(0, 180));
  ok('look渲染为老界面HTML（含链接或卡片结构）',
    /<a\s|<div|<form/i.test(look), look.slice(0, 120));

  // 2) 命令直达：概率公示（新功能）
  const gailv = await requestPage(['gailv']);
  await sleep(GAP);
  const gailvText = pageText(gailv);
  ok('gailv概率公示页渲染', gailvText.includes('随机玩法概率公示'), gailvText.slice(0, 160));

  // 3) 命令直达：提炼页（概率公示入口）
  const refine = await requestPage(['refine']);
  await sleep(GAP);
  const refineText = pageText(refine);
  ok('refine提炼页渲染', refineText.includes('装备提炼'), refineText.slice(0, 160));
  ok('提炼页含概率公示链接', /概率公示/.test(refineText), '');

  // 4) 命令直达：仓库助手菜单（三件套入口）
  const ps = await requestPage(['personal_storage']);
  await sleep(GAP);
  const psText = pageText(ps);
  ok('仓库助手菜单渲染', psText.includes('批量仓库助手'), psText.slice(0, 160));
  ok('菜单含[清理仓库重复套装]入口', psText.includes('清理仓库重复套装'), '');
  ok('菜单含[仓库批量卖装]入口', psText.includes('仓库批量卖装'), '');

  // 5) 数字链接逐级点击：仓库菜单 → 清理仓库重复套装
  const psLinks = extractNumLinks(ps);
  ok('仓库菜单有可点数字链接', psLinks.length > 0,
    JSON.stringify(psLinks.slice(0, 3)));
  const cangkuLink = psLinks.find((l) => l.label.includes('清理仓库重复套装'));
  ok('找到[清理仓库重复套装]数字链接', !!cangkuLink,
    JSON.stringify(psLinks.map((l) => l.label).slice(0, 8)));
  if (cangkuLink) {
    const cangkuPage = await requestPage([cangkuLink.num]);
    await sleep(GAP);
    const ct = pageText(cangkuPage);
    ok('点击数字链接→仓库套装清理页', ct.includes('重复套装清理') ||
      ct.includes('没有可清理') || ct.includes('角色仓库'), ct.slice(0, 180));
  }

  // 6) 数字链接：仓库菜单 → 仓库批量卖装
  const sellLink = psLinks.find((l) => l.label.includes('仓库批量卖装'));
  ok('找到[仓库批量卖装]数字链接', !!sellLink, '');
  if (sellLink) {
    const sellPage = await requestPage([sellLink.num]);
    await sleep(GAP);
    const st = pageText(sellPage);
    ok('点击数字链接→仓库卖装页', st.includes('批量卖装') ||
      st.includes('需要VIP1'), st.slice(0, 180));
  }

  // 7) take页：全部取出按钮存在（有货时才渲染；空仓=空态）
  const takePage = await requestPage(['personal_storage take 0']);
  await sleep(GAP);
  const tt = pageText(takePage);
  ok('take页渲染（空态或按钮）',
    tt.includes('没有符合条件的可操作物品') || tt.includes('全部取出'), tt.slice(0, 180));

  // 8) 数字链接点击后不退回房间（嵌套command刷链接表回归）：
  //    点击菜单链接后的页面不应是房间描述
  if (cangkuLink) {
    const after = await requestPage([cangkuLink.num]);
    await sleep(GAP);
    const at = pageText(after);
    const looksLikeRoom = /你站在|这里明显的出口|方向/.test(at) &&
      !at.includes('重复套装清理') && !at.includes('没有可清理');
    ok('数字链接点击后不退回房间描述', !looksLikeRoom, at.slice(0, 160));
  }

  // 9) 命令频率限制不误伤正常间隔请求
  const again = await requestPage(['look']);
  await sleep(GAP);
  ok('同间隔第二次look正常', pageText(again).length > 60 &&
    !pageText(again).includes('登录错误'), pageText(again).slice(0, 140));

  // 10) html5命令串直传变体兼容（另一张老过滤器的链接是明文命令）
  const ps5raw = await new Promise((resolve) => {
    const sock = net.createConnection({ host: HOST, port: PORT });
    let buf = '';
    const timer = setTimeout(() => { sock.destroy(); resolve(buf); }, 20000);
    sock.on('connect', () => {
      sock.write([
        `set_filter html5 ./game.jsp 仙道wapmud`,
        LOGIN_LINE, 'personal_storage', 'flush_filter',
      ].join('\n') + '\n');
    });
    sock.on('data', (d) => { buf += d.toString('utf8'); });
    sock.on('close', () => { clearTimeout(timer); resolve(buf); });
    sock.on('error', () => { clearTimeout(timer); resolve(buf); });
  });
  await sleep(GAP);
  const ps5 = extractCmdLinks(ps5raw);
  ok('html5链接为命令串直传（_cmd=命令）', ps5.length > 0 &&
    ps5.some((l) => l.cmd.startsWith('personal_storage') ||
      l.cmd.startsWith('set_equipment_cleanup') ||
      l.cmd.startsWith('personal_storage_sell')),
    JSON.stringify(ps5.slice(0, 3)));
  // html5命令串直传：直接把命令作为输入行发送（JSP解码后即为命令）
  const sell5 = ps5.find((l) => l.cmd.startsWith('personal_storage_sell'));
  if (sell5) {
    const sellPage5 = await new Promise((resolve) => {
      const sock = net.createConnection({ host: HOST, port: PORT });
      let buf = '';
      const timer = setTimeout(() => { sock.destroy(); resolve(buf); }, 20000);
      sock.on('connect', () => {
        sock.write([
          `set_filter html5 ./game.jsp 仙道wapmud`,
          LOGIN_LINE, sell5.cmd, 'flush_filter',
        ].join('\n') + '\n');
      });
      sock.on('data', (d) => { buf += d.toString('utf8'); });
      sock.on('close', () => { clearTimeout(timer); resolve(buf); });
      sock.on('error', () => { clearTimeout(timer); resolve(buf); });
    });
    await sleep(GAP);
    const st5 = pageText(sellPage5);
    ok('html5命令串直传→卖装页', st5.includes('批量卖装') ||
      st5.includes('需要VIP1'), st5.slice(0, 180));
  }

  console.log(`\n结果: ${passed} 通过, ${failed} 失败`);
  process.exit(failed > 0 ? 1 : 0);
}
main();
