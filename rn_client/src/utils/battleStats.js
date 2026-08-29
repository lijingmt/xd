/**
 * 战斗统计聚合器（纯函数，可注入TestUnit）。
 * 从 battleFeedback 事件流中累积伤害/治疗/DPS统计。
 */

export function createStatsTracker() {
  return {
    damageDealt: 0,
    damageTaken: 0,
    healing: 0,
    crits: 0,
    dodges: 0,
    kills: 0,
    startTime: 0,
    endTime: 0,
  };
}

/** 累积一个事件到统计中（原地修改stats）。 */
export function applyEvent(stats, event) {
  if (!event || !stats) return stats;
  switch (event.kind) {
    case 'damage':
      if (event.target === 'enemy') {
        stats.damageDealt += event.value || 0;
        if (event.critical) stats.crits += 1;
      } else {
        stats.damageTaken += event.value || 0;
      }
      if (!stats.startTime) stats.startTime = Date.now();
      stats.endTime = Date.now();
      break;
    case 'heal':
      stats.healing += event.value || 0;
      break;
    case 'dodge':
      stats.dodges += 1;
      break;
    case 'victory':
      stats.kills += 1;
      break;
  }
  return stats;
}

/** 批量累积。 */
export function applyEvents(stats, events) {
  for (const event of events || []) applyEvent(stats, event);
  return stats;
}

/** 计算DPS（秒）。 */
export function computeDps(stats) {
  if (!stats || !stats.damageDealt || !stats.startTime) return 0;
  const seconds = Math.max(1, (stats.endTime - stats.startTime) / 1000);
  return Math.round(stats.damageDealt / seconds);
}

/** 重置（新一場战斗）。 */
export function resetStats(stats) {
  return createStatsTracker();
}

/** 格式化为显示文本。 */
export function formatStats(stats) {
  if (!stats || !stats.damageDealt && !stats.damageTaken) return null;
  return {
    dps: computeDps(stats),
    dealt: stats.damageDealt,
    taken: stats.damageTaken,
    healed: stats.healing,
    crits: stats.crits,
    kills: stats.kills,
    duration: stats.endTime > stats.startTime
      ? Math.round((stats.endTime - stats.startTime) / 1000) : 0,
  };
}
