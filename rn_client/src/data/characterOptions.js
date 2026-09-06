/**
 * 建角选项与门禁（与 Vue 端同源数据，纯函数供 TestUnit 覆盖）。
 */

export const RACES = [
  { id: 'human', name: '人类' },
  { id: 'monst', name: '妖魔' },
  { id: 'third', name: '中立' },
];

export const PROFESSION_OPTIONS = [
  { race_id: 'human', profession_id: 'jianxian', name: '剑仙', icon: '⚔️', desc: '重甲长剑，正面强攻' },
  { race_id: 'human', profession_id: 'yushi', name: '羽士', icon: '🌩️', desc: '元素法术，远程爆发' },
  { race_id: 'human', profession_id: 'zhuxian', name: '诛仙', icon: '🗡️', desc: '灵动剑术，迅捷连击' },
  { race_id: 'monst', profession_id: 'kuangyao', name: '狂妖', icon: '🩸', desc: '狂暴近战，持续撕裂' },
  { race_id: 'monst', profession_id: 'wuyao', name: '巫妖', icon: '☠️', desc: '毒术诅咒，法系压制' },
  { race_id: 'monst', profession_id: 'yinggui', name: '影鬼', icon: '🌑', desc: '潜影刺杀，高速闪避' },
  { race_id: 'third', profession_id: 'fangshi', name: '方士', icon: '🐯', desc: '三灵召唤，攻守治疗' },
  { race_id: 'third', profession_id: 'zhenyue', name: '镇越', icon: '🛡️', desc: '团队坦克，守御承伤' },
  { race_id: 'third', profession_id: 'tianxiang', name: '天象', icon: '🌠', desc: '星痕法术，元素爆发' },
  { race_id: 'third', profession_id: 'lingyi', name: '灵医', icon: '🌿', desc: '群体治疗，净化复生' },
  { race_id: 'third', profession_id: 'wuxiang', name: '无相', icon: '🔆', desc: '【隐藏】全职业补位；十职业均达120级后解锁', hidden: 'wuxiang' },
  { race_id: 'third', profession_id: 'taiji', name: '太极', icon: '☯️', desc: '【最高隐藏】生死轮转；十职与无相均达200级后解锁', hidden: 'taiji' },
  { race_id: 'third', profession_id: 'zhaoming', name: '照命', icon: '🌙', desc: '【S1隐藏】同账号5个不同赛季职业完成81章并达120级', hidden: 'zhaoming' },
  { race_id: 'third', profession_id: 'wuji', name: '无极', icon: '💠', desc: '【终极隐藏】照命300级+1万碎玉；三系成长胜太极三成', hidden: 'wuji' },
  { race_id: 'third', profession_id: 'wuxin', name: '无心', icon: '🦋', desc: '【账号终极】无极通关全难度+2万碎玉；心法85%、对怪双倍伤害；300级解锁全账号400级', hidden: 'wuxin' },
];

/**
 * 可见职业：无相/太极未解锁隐藏；照命需解锁且幻境建角。
 * unlocks: {wuxiang,taiji,zhaoming}；realmType: 'eternal'|'illusion'。
 */
export function visibleProfessions(unlocks, realmType) {
  const flags = unlocks || {};
  return PROFESSION_OPTIONS.filter(option => {
    if (option.hidden === 'wuxiang' && !flags.wuxiang) return false;
    if (option.hidden === 'taiji' && !flags.taiji) return false;
    if (option.hidden === 'zhaoming' &&
        (!flags.zhaoming || realmType !== 'illusion')) return false;
    if (option.hidden === 'wuji' && !flags.wuji_entitled) return false;
    if (option.hidden === 'wuxin' &&
        !(flags.wuxin_entitled && flags.wuxin_difficulty_ready))
      return false;
    return true;
  });
}

export function professionsForRace(raceId, unlocks, realmType) {
  return visibleProfessions(unlocks, realmType)
    .filter(option => option.race_id === raceId);
}

/** 头像ID生成，与 Vue avatarChoicesFor 完全一致。 */
export function avatarChoicesFor(raceId, professionId, sex) {
  if (!raceId || !professionId ||
      (sex !== 'male' && sex !== 'female')) return [];
  const choices = [];
  if (raceId === 'human' || raceId === 'third') {
    if (raceId === 'third' &&
        ['zhenyue', 'tianxiang', 'lingyi', 'wuxiang', 'taiji',
         'wuji', 'wuxin']
          .includes(professionId)) {
      choices.push(`${professionId}_${sex}`);
    }
    const count = sex === 'male' ? 11 : 12;
    for (let index = 1; index <= count; index += 1) {
      choices.push(`h_${sex}${index}`);
    }
  } else if (raceId === 'monst') {
    const count = sex === 'male' ? 12 : 11;
    for (let index = 1; index <= count; index += 1) {
      choices.push(`m_${sex}${index}`);
    }
  }
  return choices;
}
