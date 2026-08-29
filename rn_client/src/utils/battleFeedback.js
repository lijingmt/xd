/**
 * 战斗文案解析 → 浮动数字/状态标记/技能名（纯函数，供 TestUnit 覆盖）。
 * 与 Vue parseBattleActions 同一套正则逻辑。
 */

/** 一行的裸文本（含按钮标签）。 */
export function lineRawText(line) {
  return ((line && line.segments) || [])
    .map(segment => {
      if (!segment) return '';
      if (segment.type === 'text') {
        return ((segment.parts) || [])
          .map(part => part.content || '')
          .join('');
      }
      return segment.label || '';
    })
    .join('');
}

/**
 * 解析一行战斗文本，返回事件列表：
 * {kind:'damage', target:'player'|'enemy', value, critical}
 * {kind:'dodge'|'block'|'poison', target:'player'}
 * {kind:'victory'}
 * {kind:'heal', target:'player', value}
 * {kind:'skill', name, type}
 */
export function parseBattleLine(line) {
  const events = [];
  const text = lineRawText(line);
  if (!text || !text.trim()) return events;

  /* 纯按钮行跳过 */
  const segments = (line && line.segments) || [];
  if (segments.length === 1 && segments[0] &&
      segments[0].type === 'button') return events;

  /* 丹药服用 → buff 动画 */
  const danyao = text.match(/你(?:食用|阅读)了([^。。\n]+?)(?:[。\n]|$)/);
  if (danyao && danyao[1]) {
    events.push({ kind: 'skill', name: danyao[1].trim(), type: 'buff' });
  }

  /* 闪避/格挡/中毒 */
  if (/躲过.*攻击|闪避.*招式|身法.*避开/.test(text)) {
    events.push({ kind: 'dodge', target: 'player' });
  }
  if (/格挡.*攻击|招架.*招式|成功.*防御/.test(text)) {
    events.push({ kind: 'block', target: 'player' });
  }
  if (/身中剧毒|毒发.*伤|中毒.*发作/.test(text)) {
    events.push({ kind: 'poison', target: 'player' });
  }

  /* 伤害数字：先判断是否"你造成了"（玩家攻击），否则"对你造成"（受伤） */
  const dmg = text.match(/(\d+)点.*?伤害/);
  if (dmg && (text.includes('你造成') || text.includes('对你造成') ||
    text.includes('对你'))) {
    const value = parseInt(dmg[1], 10) || 0;
    if (value > 0) {
      const isPlayerAttacking = text.includes('你造成') ||
        (text.includes('你') && text.includes('对') &&
         !text.includes('对你'));
      const critical = /暴击|致命|会心一击/.test(text);
      events.push({
        kind: 'damage',
        target: isPlayerAttacking ? 'enemy' : 'player',
        value, critical,
      });
    }
  }

  /* 治疗 */
  const heal = text.match(/恢复(?:了)?(\d+)点/);
  if (heal && parseInt(heal[1], 10) > 0) {
    events.push({
      kind: 'heal', target: 'player',
      value: parseInt(heal[1], 10),
    });
  }

  /* 胜利 */
  if (/战斗胜利|战胜了|击败|获胜/.test(text)) {
    events.push({ kind: 'victory' });
  }

  return events;
}

/** 批量解析多行。 */
export function parseBattleLines(lines) {
  const all = [];
  for (const line of lines || []) {
    all.push(...parseBattleLine(line));
  }
  return all;
}

/** 从战斗文案中提取技能名（Vue extractSkillName 简化版）。 */
export function extractSkillName(text) {
  const match = text.match(/[【「]([^」】]+)[」】]/);
  if (match) return match[1];
  const cast = text.match(/施展了([^【「]{2,8})/);
  return cast ? cast[1].trim() : null;
}
