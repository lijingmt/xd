/**
 * 仙道 MUD HTTP API 层。
 * 与 vue_source 客户端同一套接口：
 *   GET /api/challenge
 *   GET /api/json?userid=<区+账号>&password=<明文>&cmd=init   -> {txd,lines,...}
 *   GET /api/json?txd=<txd>&cmd=<cmd>                          -> {txd,lines,...}
 *   GET /api/status?txd= /api/battle_status?txd=
 *   GET /api/autofight?txd=&action=toggle|on|off
 * 所有请求函数接受可注入的 fetchImpl 以便前端 TestUnit 离线测试。
 */

const DEFAULT_API_BASE = 'http://127.0.0.1:8888';

let currentApiBase = DEFAULT_API_BASE;

export function setApiBase(base) {
  currentApiBase = String(base || '').replace(/\/+$/, '') || DEFAULT_API_BASE;
}

export function getApiBase() {
  return currentApiBase;
}

/** 纯函数：构造 /api/json 登录/命令 URL（含编码）。 */
export function buildJsonUrl(base, params) {
  const query = Object.entries(params)
    .filter(([, value]) => value !== undefined && value !== null)
    .map(([key, value]) =>
      `${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`)
    .join('&');
  return `${base}/api/json?${query}`;
}

/** 纯函数：构造任意 txd 类 GET 接口 URL。 */
export function buildTxdUrl(base, path, txd, extra) {
  const root = String(base || '').replace(/\/+$/, '');
  const params = { txd, ...(extra || {}) };
  const query = Object.entries(params)
    .map(([key, value]) =>
      `${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`)
    .join('&');
  return `${root}${path}?${query}`;
}

async function getJson(url, fetchImpl) {
  const doFetch = fetchImpl || fetch;
  const response = await doFetch(url);
  let data = null;
  try {
    data = await response.json();
  } catch (e) {
    data = null;
  }
  if (!response.ok || (data && data.error)) {
    const message = (data && data.error) || `HTTP ${response.status}`;
    const error = new Error(message);
    error.status = response.status;
    error.data = data;
    throw error;
  }
  return data || {};
}

export async function fetchPartitions(fetchImpl) {
  const doFetch = fetchImpl || fetch;
  const response = await doFetch(`${getApiBase()}/api/partitions`);
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);
  return data;
}

export async function fetchChallenge(fetchImpl) {
  const data = await getJson(`${getApiBase()}/api/challenge`, fetchImpl);
  return String(data.challenge || '');
}

/**
 * 登录并执行 init。userid 为“区号+账号”完整形态（如 xd01test）。
 * 返回 {txd, lines, timestamp}。
 */
export async function login(userid, password, fetchImpl) {
  const url = buildJsonUrl(getApiBase(), {
    userid, password, cmd: 'init',
  });
  return getJson(url, fetchImpl);
}

/** 用当前 txd 执行任意游戏命令，返回新的 {txd, lines, refresh?}。
 * platform: txpike9 同款约定——web 导出按 ios 上报，原生传 os。 */
export async function sendCommand(txd, cmd, fetchImpl, platform) {
  const params = { txd, cmd };
  if (platform) params.platform = platform;
  const url = buildJsonUrl(getApiBase(), params);
  return getJson(url, fetchImpl);
}

export async function fetchStatus(txd, fetchImpl) {
  return getJson(buildTxdUrl(getApiBase(), '/api/status', txd), fetchImpl);
}

export async function fetchBattleStatus(txd, fetchImpl) {
  return getJson(
    buildTxdUrl(getApiBase(), '/api/battle_status', txd), fetchImpl);
}

/**
 * 挂机画面增量拉取：after/generation 配合服务端 sequence 去重；
 * 有新画面时返回全量 lines 快照 + refresh{player,in_battle,enemy}，
 * 无变化返回 unchanged=1（可能带 refresh）。
 */
export async function fetchAutofightView(txd, after, generation, fetchImpl) {
  return getJson(buildTxdUrl(getApiBase(), '/api/autofight_view', txd, {
    after: after || 0,
    generation: generation || '',
  }), fetchImpl);
}

export async function setAutofight(txd, action, fetchImpl) {
  const doFetch = fetchImpl || fetch;
  const response = await doFetch(`${getApiBase()}/api/autofight`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      txd, action: action || 'toggle',
    }).toString(),
  });
  let data = null;
  try {
    data = await response.json();
  } catch (e) {
    data = null;
  }
  if (!response.ok || (data && data.error)) {
    throw new Error((data && data.error) || `HTTP ${response.status}`);
  }
  return data || {};
}

/**
 * 注册：与 Vue 端同一契约，走 /api/html 免认证通道。
 * cmd = login_regnew gamelib <fullUserid> <password> <sessionId> <challenge>
 */
export async function registerAccount(fullUserid, password, sessionId,
  challenge, fetchImpl) {
  const doFetch = fetchImpl || fetch;
  const cmd = `login_regnew gamelib ${fullUserid} ${password} ` +
    `${sessionId} ${challenge}`;
  const url = `${getApiBase()}/api/html?cmd=${encodeURIComponent(cmd)}`;
  const response = await doFetch(url);
  const text = await response.text();
  const failed = !response.ok || /error2/.test(text);
  return { ok: !failed, text };
}
