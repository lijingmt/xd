/**
 * 登录过的账号本地保存（一键登录）：
 * 保存 {userid, password, partition, apiBase, t}，最多 8 个，新登录置顶。
 * 密码仅存本设备（AsyncStorage），可随时删除条目。
 * 存储后端可注入（TestUnit 用内存 Map，运行时用 AsyncStorage）。
 */

const KEY = 'xiand.saved_accounts';
const MAX_ACCOUNTS = 8;

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

function validEntry(entry) {
  return entry && typeof entry.userid === 'string' && entry.userid &&
    typeof entry.password === 'string' && entry.password;
}

export async function loadSavedAccounts() {
  try {
    const storage = await backend();
    const raw = await storage.getItem(KEY);
    const list = raw ? JSON.parse(raw) : [];
    return Array.isArray(list) ? list.filter(validEntry) : [];
  } catch (e) {
    return [];
  }
}

export async function addSavedAccount(entry) {
  if (!validEntry(entry)) return [];
  try {
    const storage = await backend();
    const list = await loadSavedAccounts();
    const next = [{
      userid: entry.userid,
      password: entry.password,
      partition: String(entry.partition || ''),
      apiBase: String(entry.apiBase || ''),
      t: Date.now(),
    }, ...list.filter(item => item.userid !== entry.userid)]
      .slice(0, MAX_ACCOUNTS);
    await storage.setItem(KEY, JSON.stringify(next));
    return next;
  } catch (e) {
    return [];
  }
}

export async function removeSavedAccount(userid) {
  try {
    const storage = await backend();
    const list = await loadSavedAccounts();
    const next = list.filter(item => item.userid !== userid);
    await storage.setItem(KEY, JSON.stringify(next));
    return next;
  } catch (e) {
    return [];
  }
}
