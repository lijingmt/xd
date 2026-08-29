/**
 * 多角色并行挂机的纯函数层（可注入 TestUnit）。
 * 会话结构 sessions: { [charId]: {
 *   txd, lines, status, inBattle, autofighting,
 *   lastPollAt, pollInflight, failCount, afkBusy } }
 * 服务端 autofight tick 会为每个挂机角色保活虚拟连接，
 * 后台轮询只为刷新快照，不承担保活职责。
 */

export const PARALLEL_CHARACTER_LIMIT = 20;
/** 后台角色快照轮询间隔（毫秒）。 */
export const BACKGROUND_POLL_INTERVAL_MS = 25000;
/** 同一时刻最多并发的前后台轮询请求数。 */
export const BACKGROUND_POLL_CONCURRENCY = 2;

export function canOpenMoreSessions(sessionCount, limit) {
  const cap = limit > 0 ? limit : PARALLEL_CHARACTER_LIMIT;
  return sessionCount < cap;
}

/** 按下标错开轮询时刻，避免20个后台角色同一秒齐发请求。 */
export function sessionJitterMs(index) {
  return (index % 10) * 700 + ((index * 137) % 500);
}

/**
 * 挑出本轮应轮询的后台角色（不含 activeId）。
 * 依据：已到间隔(含抖动) && 无在途请求 && 并发额度未满。
 */
export function pickDueBackgroundSessions(
  sessions, activeId, now, opts) {
  const interval = (opts && opts.intervalMs) || BACKGROUND_POLL_INTERVAL_MS;
  const maxInflight = (opts && opts.maxInflight) != null
    ? opts.maxInflight : BACKGROUND_POLL_CONCURRENCY;
  const due = [];
  let inflight = 0;
  for (const id of Object.keys(sessions || {})) {
    if (sessions[id] && sessions[id].pollInflight) inflight += 1;
  }
  if (inflight >= maxInflight) return due;
  let index = 0;
  for (const id of Object.keys(sessions || {})) {
    if (id === activeId) continue;
    const session = sessions[id];
    index += 1;
    if (!session || !session.txd) continue;
    if (session.pollInflight) continue;
    const nextDue = (session.lastPollAt || 0) +
      interval + sessionJitterMs(index);
    if (now >= nextDue) {
      due.push(id);
      if (due.length + inflight >= maxInflight) break;
    }
  }
  return due;
}

/**
 * 用 flushview 的 refresh 快照更新会话（原地返回新对象）。
 * player 归一化沿用 pollGameView 的规则（pet_assist 0 → null）。
 */
export function mergeSessionSnapshot(session, refresh) {
  const next = { ...session };
  const data = refresh || {};
  if (data.player && typeof data.player === 'object') {
    const player = { ...data.player };
    if (player.pet_assist !== null &&
        typeof player.pet_assist !== 'object') {
      player.pet_assist = null;
    }
    next.status = player;
    next.autofighting = !!player.autofight;
  }
  if (typeof data.in_battle !== 'undefined') {
    next.inBattle = !!data.in_battle;
  }
  next.lastPollAt = Date.now();
  next.failCount = 0;
  return next;
}

/** 连续失败达到阈值后需要静默重选会话（401恢复）。 */
export function shouldRecoverSession(session, failLimit) {
  return !!session && (session.failCount || 0) >= (failLimit || 2);
}

/** 仪表盘展示用摘要：等级/血量/挂机状态。 */
export function sessionSummary(session, card) {
  const status = (session && session.status) || null;
  const hp = status ? Math.max(0,
    Math.round((Number(status.hp) || 0) /
      Math.max(1, Number(status.hp_max) || 1) * 100)) : null;
  return {
    online: !!(session && session.txd),
    autofighting: !!(session && session.autofighting),
    inBattle: !!(session && session.inBattle),
    hpPercent: hp,
    level: status ? Number(status.level) || 0 :
      (card ? Number(card.level) || 0 : 0),
  };
}
