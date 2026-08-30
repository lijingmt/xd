/**
 * 技能类型识别（Vue parseMartialArtsSkill 的原生移植）。
 * 纯函数：技能名 → 类型ID → {icon,color,glow,duration,variant,size}。
 * variant 决定 SkillEffectOverlay 的动画变体（对应网页版 CSS keyframes）。
 */

export const SKILL_TYPE_META = {
  'sword-qi':   { icon: '⚔️', color: '#FFD700', glow: '#FFEC8B', duration: 1000, variant: 'wave',   size: 56 },
  'palm':       { icon: '🖐️', color: '#FF6B4A', glow: '#FF8E6B', duration: 800,  variant: 'ripple', size: 48 },
  'finger':     { icon: '👆', color: '#DDA0DD', glow: '#E6B8E6', duration: 650,  variant: 'beam',   size: 40 },
  'fist':       { icon: '👊', color: '#4A9EFF', glow: '#7AB8FF', duration: 650,  variant: 'impact', size: 52 },
  'lightness':  { icon: '💨', color: '#87CEEB', glow: '#B0E0F5', duration: 950,  variant: 'rise',   size: 44 },
  'inner-power':{ icon: '✨', color: '#FFD700', glow: '#FFF8DC', duration: 1100, variant: 'wave',   size: 64 },
  'staff':      { icon: '🎋', color: '#8B4513', glow: '#C4956A', duration: 750,  variant: 'sweep',  size: 48 },
  'saber':      { icon: '🗡️', color: '#C0C0C0', glow: '#E8E8E8', duration: 750,  variant: 'slash',  size: 56 },
  'critical':   { icon: '💥', color: '#FF0000', glow: '#FF6B6B', duration: 800,  variant: 'burst',  size: 72 },
  'dodge':      { icon: '💫', color: '#87CEEB', glow: '#B0E0F5', duration: 550,  variant: 'shift',  size: 40 },
  'block':      { icon: '🛡️', color: '#FFD700', glow: '#FFF8DC', duration: 650,  variant: 'pulse',  size: 44 },
  'poison':     { icon: '☠️', color: '#32CD32', glow: '#7CFC7A', duration: 1300, variant: 'ripple', size: 48 },
  'heal':       { icon: '🪷', color: '#98FB98', glow: '#C1FFC1', duration: 1200, variant: 'rise',   size: 52 },
  'summon':     { icon: '🌀', color: '#4169E1', glow: '#7A9FE1', duration: 1350, variant: 'orbit',  size: 56 },
  'buff':       { icon: '🔆', color: '#FFD700', glow: '#FFF8DC', duration: 1100, variant: 'pulse',  size: 44 },
  'curse':      { icon: '🔮', color: '#9932CC', glow: '#C47BD1', duration: 1100, variant: 'orbit',  size: 44 },
  'lightning':  { icon: '⚡', color: '#FFFF00', glow: '#FFFACD', duration: 900,  variant: 'impact', size: 48 },
  'fire':       { icon: '🔥', color: '#FF4500', glow: '#FF8C69', duration: 1000, variant: 'burst',  size: 52 },
  'ice':        { icon: '❄️', color: '#00BFFF', glow: '#87CEEB', duration: 1100, variant: 'ripple', size: 46 },
  'wind':       { icon: '🌪️', color: '#98D8E8', glow: '#C1E8F0', duration: 950,  variant: 'sweep',  size: 48 },
  'spirit':     { icon: '☯️', color: '#DDA0DD', glow: '#E6B8E6', duration: 1100, variant: 'orbit',  size: 48 },
  'ancient':    { icon: '𖤓', color: '#FFD700', glow: '#E879F9', duration: 1800, variant: 'burst',  size: 64 },
  'shentaigu':  { icon: '🌑', color: '#FF2D55', glow: '#7A0D1F', duration: 2400, variant: 'moon',   size: 72 },
  'generic':    { icon: '✦', color: '#F0E6D2', glow: '#8A7A8A', duration: 900,  variant: 'cast',   size: 40 },
};

/**
 * 技能名 → 类型ID（与 Vue parseMartialArtsSkill 同一套正则，优先级从上到下）。
 */
export function parseSkillType(text) {
  const value = String(text || '');
  if (!value) return null;
  if (/神太古/.test(value)) return 'shentaigu';
  if (/【命】|碎镜千影|命火同燃/.test(value)) return 'spirit';
  if (/太古|寰极/.test(value)) return 'ancient';
  if (/灵治|灵莲铺|万灵朝生|治疗|回春|恢复/.test(value)) return 'heal';
  if (/召唤|虎灵|鹤灵|龟灵|三灵合一|三灵共鸣|唤小灵|灵契共鸣/.test(value)) return 'summon';
  if (/山河壁|玄铁盾|万山不孤|天地成壁/.test(value)) return 'block';
  if (/星壁|万象星壁/.test(value)) return 'block';
  if (/地震吼|镇魂吼/.test(value)) return 'curse';
  if (/星锁|周天静止/.test(value)) return 'curse';
  if (/星芒|曜光|星落|星河坠落/.test(value)) return 'fire';
  if (/寒辰|星雨|月引/.test(value)) return 'ice';
  if (/流星|天旋|九星连珠/.test(value)) return 'wind';
  if (/雷|电|极光|光芒万丈|玄光/.test(value)) return 'lightning';
  if (/火|炎|焰|燎|灼|太阳热线/.test(value)) return 'fire';
  if (/冰|雪|寒|霜|冻/.test(value)) return 'ice';
  if (/药雾|毒|瘴|腐蚀|流血|放血|裂伤|撕裂|灼烧/.test(value)) return 'poison';
  if (/诅咒|封印|禁锢|束缚|障目|泥沼|灵咒|缠身|重压|致残/.test(value)) return 'curse';
  if (/轻功|凌波微步|神行百变|灵玄影|幻影残像|鬼踪|飘忽不定|清风身法|九幽鬼步/.test(value)) return 'lightness';
  if (/盾|护体|结界|剑意|神威|狂化|冲动|静心|凝心|灵涌|灵风|山印|镇岩|镇越真身|万山朝拱/.test(value)) return 'buff';
  if (/风|云|瞬移/.test(value)) return 'wind';
  if (/剑气|剑芒|万剑|剑阵|剑域|神剑|剑光|御剑|剑影|破天一剑/.test(value)) return 'sword-qi';
  if (/刀|斩|刃|切割|伏击|夺命|杀戮|封喉|绝灭/.test(value)) return 'saber';
  if (/棒|棍|横扫|竹鞭/.test(value)) return 'staff';
  if (/掌|掌法/.test(value)) return 'palm';
  if (/指|指法/.test(value)) return 'finger';
  if (/拳|冲撞|猛击|重击|打击|岳击|横山击|巨岳破|岳反震|不周震击/.test(value)) return 'fist';
  if (/内力|真气|内功|神功|心法|本能|狂意/.test(value)) return 'inner-power';
  if (/【方】|灵/.test(value)) return 'spirit';
  if (/【象】|星痕|观天/.test(value)) return 'lightning';
  return 'generic';
}

export function skillMeta(typeId) {
  return SKILL_TYPE_META[typeId] || SKILL_TYPE_META.generic;
}
