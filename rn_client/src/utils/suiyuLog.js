/**
 * 碎玉消费记录：账号级本地流水（时间/项目/数额），
 * 存储后端可注入（TestUnit 用内存 Map，运行时用 AsyncStorage）。
 */

const KEY_PREFIX = 'xiand.suiyu_log.';
const MAX_ENTRIES = 100;

let injectedBackend = null;

/** 注入测试后端：{getItem,setItem,removeItem}（异步或同步均可）。 */
export function setStorageBackend(backend) {
  injectedBackend = backend;
}

async function backend() {
  if (injectedBackend) return injectedBackend;
  const module = await import('@react-native-async-storage/async-storage');
  return module.default;
}

export async function loadSuiyuLog(userid) {
  try {
    const storage = await backend();
    const raw = await storage.getItem(KEY_PREFIX + String(userid || ''));
    const list = raw ? JSON.parse(raw) : [];
    return Array.isArray(list) ? list : [];
  } catch (e) {
    return [];
  }
}

export async function saveSuiyuLog(userid, log) {
  try {
    const storage = await backend();
    await storage.setItem(KEY_PREFIX + String(userid || ''),
      JSON.stringify((log || []).slice(0, MAX_ENTRIES)));
  } catch (e) { /* 本地记录失败不阻断游戏 */ }
}

export async function clearSuiyuLog(userid) {
  try {
    const storage = await backend();
    await storage.removeItem(KEY_PREFIX + String(userid || ''));
  } catch (e) { /* 同上 */ }
}

/**
 * 从最近的画面行/命令里猜"买了啥"：
 * 优先匹配购买/兑换文案，其次最近的游戏命令，最后兜底"游戏内消费"。
 */
export function suiyuChangeLabel(lines, lastCmd) {
  const recent = (lines || []).slice(-20);
  for (let i = recent.length - 1; i >= 0; i--) {
    const line = recent[i];
    const text = ((line && line.segments) || [])
      .map(s => s && s.type === 'text'
        ? ((s.parts) || []).map(p => p.content || '').join('')
        : '')
      .join('');
    const buy = text.match(/(?:购买|兑换|成功开通|成功购买|买下)了?(.{1,18}?)[，。!！\s]/);
    if (buy && buy[1]) return buy[1].trim();
  }
  if (lastCmd && Date.now() - (lastCmd.t || 0) < 20000 && lastCmd.text) {
    const cmd = String(lastCmd.text);
    if (/^(yushi_|ljs_|add_|fee_|vip_)/.test(cmd)) return '游戏内兑换';
  }
  return '游戏内消费';
}

/** 千分位分组：1234567 → "1,234,567"。 */
export function groupDigits(value) {
  const n = Math.round(Number(value) || 0);
  const sign = n < 0 ? '-' : '';
  return sign + String(Math.abs(n))
    .replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

/** 记录时间格式化：MM-DD HH:mm。 */
export function suiyuTime(epoch) {
  const d = new Date(epoch);
  const pad = v => String(v).padStart(2, '0');
  return `${pad(d.getMonth() + 1)}-${pad(d.getDate())} ` +
    `${pad(d.getHours())}:${pad(d.getMinutes())}`;
}
