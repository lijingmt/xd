/**
 * 仙道多角色账号 API（与 Vue 端账号中心同一契约，全部 POST JSON）：
 *   /api/account/login                {userid,password} -> {token,account_id,characters,limit,...}
 *   /api/account/characters           {token}           -> 同上（刷新）
 *   /api/account/characters/select    {token,character_id} -> {txd,character_id,bootstrap_command}
 * 令牌只放请求体，不进 URL。fetch 可注入供离线测试。
 */

async function postJson(path, body, fetchImpl) {
  const doFetch = fetchImpl || fetch;
  const response = await doFetch(`${getBase()}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body || {}),
  });
  let data = null;
  try {
    data = await response.json();
  } catch (e) {
    data = null;
  }
  if (!response.ok || (data && data.error)) {
    const error = new Error((data && data.error) || `HTTP ${response.status}`);
    error.status = response.status;
    error.data = data;
    throw error;
  }
  return data || {};
}

let base = 'http://127.0.0.1:8888';

export function setAccountApiBase(value) {
  base = String(value || '').replace(/\/+$/, '') || base;
}

export function getBase() {
  return base;
}

export async function accountLogin(userid, password, fetchImpl) {
  return postJson('/api/account/login', { userid, password }, fetchImpl);
}

export async function fetchCharacters(token, fetchImpl) {
  return postJson('/api/account/characters', { token }, fetchImpl);
}

export async function selectCharacter(token, characterId, fetchImpl) {
  return postJson('/api/account/characters/select', {
    token,
    character_id: characterId,
  }, fetchImpl);
}

/**
 * 建角：form = {realm_type, race_id, profession_id, name_cn, sex, avatar_id}
 * 返回 {character:{id,...}}；失败抛服务端 error。
 */
export async function createCharacter(token, form, fetchImpl) {
  const payload = {
    token,
    realm_type: form.realm_type || 'eternal',
    race_id: form.race_id,
    profession_id: form.profession_id,
    name_cn: String(form.name_cn || '').trim(),
    sex: form.sex || 'male',
    avatar_id: form.avatar_id,
  };
  /* 隐藏职业（无极/无心）购买资格需要幂等键：同一键重复提交只扣一次费。 */
  if (form.profession_id === 'wuji' || form.profession_id === 'wuxin') {
    payload.request_id = form.request_id || generateRequestId();
  }
  return postJson('/api/account/characters/create', payload, fetchImpl);
}

function generateRequestId() {
  const chars = 'abcdef0123456789';
  let id = '';
  for (let i = 0; i < 64; i += 1) {
    id += chars[Math.floor(Math.random() * chars.length)];
  }
  return id;
}

/** 角色卡的展示归一化：把服务端字段压成仪表盘需要的最小集。 */
export function characterCard(character) {
  const source = character || {};
  return {
    id: String(source.id || ''),
    name: source.name_cn || source.id || '未命名',
    profession: source.profession_name || source.profession_id || '',
    race: source.race_name || '',
    level: Number(source.level || 0),
    realmType: source.realm_type === 'illusion' ? 'illusion' : 'eternal',
    illusionId: String(source.illusion_id || ''),
    isDefault: !!source.is_default,
    available: source.available !== 0,
    ready: !!source.ready,
  };
}

/** 整账号删除（Apple应用内删除账号要求）：三重确认由服务端校验。 */
export async function deleteAccount(token, accountPassword,
  confirmAccountId, requestId, fetchImpl) {
  const response = await postJson('/api/account/delete_account', {
    token,
    account_password: String(accountPassword || ''),
    confirm_account_id: String(confirmAccountId || ''),
    request_id: String(requestId || ''),
  }, fetchImpl);
  return response;
}

/** 生成64位hex删除请求编号（服务端幂等回执）。 */
export function newDeleteRequestId() {
  const bytes = new Uint8Array(32);
  if (typeof crypto !== 'undefined' && crypto.getRandomValues) {
    crypto.getRandomValues(bytes);
  } else {
    for (let i = 0; i < bytes.length; i++) {
      bytes[i] = Math.floor(Math.random() * 256);
    }
  }
  return Array.from(bytes,
    b => b.toString(16).padStart(2, '0')).join('');
}
