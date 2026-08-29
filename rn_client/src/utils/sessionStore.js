/**
 * 会话持久化：只保存账号令牌/账号名/服务器地址，绝不存密码。
 * 令牌服务端约12小时过期，过期后自动回到登录页。
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
  await storage.setItem(SESSION_KEY, JSON.stringify({
    token: String(session.token || ''),
    userid: String(session.userid || ''),
    apiBase: String(session.apiBase || ''),
  }));
}

export async function loadSession() {
  const storage = await backend();
  const raw = await storage.getItem(SESSION_KEY);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object' ||
        !String(parsed.token || '').length) return null;
    return {
      token: String(parsed.token),
      userid: String(parsed.userid || ''),
      apiBase: String(parsed.apiBase || ''),
    };
  } catch (e) {
    return null;
  }
}

export async function clearSession() {
  const storage = await backend();
  await storage.removeItem(SESSION_KEY);
}
