/**
 * 会话持久化：保存账号令牌/账号名/服务器地址 + 各角色txd（并行挂机），
 * 绝不存密码。txd 由角色口令派生，角色改密前长期有效；令牌约12小时
 * 过期，过期后自动回到登录页。
 * 存储后端可注入（TestUnit 用内存 Map，运行时用 AsyncStorage）。
 */

const SESSION_KEY = 'xiand.session';

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

export async function saveSession(session) {
  const storage = await backend();
  const characters = {};
  const raw = session.characters || {};
  for (const id of Object.keys(raw)) {
    const txd = String(raw[id] || '');
    if (txd) characters[id] = txd;
  }
  await storage.setItem(SESSION_KEY, JSON.stringify({
    token: String(session.token || ''),
    userid: String(session.userid || ''),
    apiBase: String(session.apiBase || ''),
    currentCharacterId: String(session.currentCharacterId || ''),
    characters,
  }));
}

export async function loadSession() {
  const storage = await backend();
  const raw = await storage.getItem(SESSION_KEY);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') return null;
    const token = String(parsed.token || '');
    const apiBase = String(parsed.apiBase || '');
    /* 无token但记录过服务器地址：仍要恢复地址（手机端登录页免重填），
     * 只有两者皆空才算无效会话。 */
    if (!token.length && !apiBase.length) return null;
    const characters = {};
    const rawChars = parsed.characters || {};
    for (const id of Object.keys(rawChars)) {
      const txd = String(rawChars[id] || '');
      if (id && txd) characters[id] = txd;
    }
    return {
      token,
      userid: String(parsed.userid || ''),
      apiBase,
      currentCharacterId: String(parsed.currentCharacterId || ''),
      characters,
    };
  } catch (e) {
    return null;
  }
}

export async function clearSession() {
  const storage = await backend();
  await storage.removeItem(SESSION_KEY);
}
