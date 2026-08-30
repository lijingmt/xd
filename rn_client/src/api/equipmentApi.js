/**
 * 装备面板 API（GET /api/equipment_panel?txd=）。
 * 返回 {slots, equipped:{slot:...}, candidates:{slot:[...]}, slot_order:[...]}。
 */
import { buildTxdUrl } from './mudApi.js';

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
    throw new Error((data && data.error) || `HTTP ${response.status}`);
  }
  return data || {};
}

export async function fetchEquipmentPanel(apiBase, txd, fetchImpl) {
  return getJson(
    buildTxdUrl(apiBase, '/api/equipment_panel', txd), fetchImpl);
}

/** 装备属性键 → 中文标签（顺序即显示顺序）。 */
export const ATTR_LABELS = {
  attack: '攻击', attack_limit: '攻击上限', attack_add: '攻击加成',
  hitte: '命中', doub: '会心', defend: '防御', dodge: '闪避',
  recive: '减伤', str: '臂力', dex: '身法', think: '悟性',
  life: '气血', mofa: '法力', all: '全属性',
};

export const ATTR_ORDER = Object.keys(ATTR_LABELS);

/**
 * 候选装备 vs 已穿戴 的逐属性差值行：
 * [{key,label,delta,candValue}]，只保留任一侧非零的属性。
 * 未穿戴时 delta = 候选值本身（全部是增益）。
 */
export function attrRows(candidate, equipped) {
  const cand = candidate || {};
  const equip = equipped || {};
  const hasEquip = !!equipped;
  return ATTR_ORDER
    .filter(key => (cand[key] || 0) !== 0 || (equip[key] || 0) !== 0)
    .map(key => ({
      key,
      label: ATTR_LABELS[key] || key,
      candValue: cand[key] || 0,
      delta: hasEquip
        ? (cand[key] || 0) - (equip[key] || 0)
        : (cand[key] || 0),
    }));
}

/** 总差值：>0 提升 / <0 下降 / 0 持平（粗略提示，逐项见行）。 */
export function attrTotalDelta(rows) {
  return (rows || []).reduce((sum, row) => sum + (row.delta || 0), 0);
}

/**
 * 纸娃娃布局模型：保留 slot_order 全部槽位（含空槽），
 * 附完整候选列表与玩家信息，供 EquipmentPanel 人物换装视图使用。
 */
export function panelModel(panelData) {
  const data = panelData || {};
  const slots = data.slots || {};
  const equipped = data.equipped || {};
  const candidates = data.candidates || {};
  const order = data.slot_order || Object.keys(slots);
  const normalizeItem = (item, slot) => item ? ({
    id: item.id || `${slot}-${item.name || ''}`,
    name: item.name_cn || item.name || '',
    slot,
    itemType: item.item_type || '',
    image: item.image_url || '',
    imageFallback: item.image_fallback || '',
    levelReq: item.level_requirement || 0,
    rareLevel: item.rare_level || 0,
    actionCmd: item.action_cmd || '',
    actionLabel: item.action_label || '',
    attrs: item.attrs || {},
  }) : null;
  return {
    player: data.player || null,
    slotOrder: order,
    slotMeta: slots,
    slots: order.map(slot => ({
      slot,
      label: (slots[slot] || {}).label || slot,
      icon: (slots[slot] || {}).icon || '装',
      image: (slots[slot] || {}).image || '',
      equipped: normalizeItem(equipped[slot], slot),
      candidates: (candidates[slot] || []).map(
        item => normalizeItem(item, slot)),
    })),
  };
}

/** 归一化槽位数据为渲染友好的卡片列表。 */
export function panelCards(panelData) {
  const data = panelData || {};
  const slots = data.slots || {};
  const equipped = data.equipped || {};
  const candidates = data.candidates || {};
  const order = data.slot_order || Object.keys(slots);
  return order.map(slot => {
    const meta = slots[slot] || {};
    const item = equipped[slot] || null;
    const alts = (candidates[slot] || []).slice(0, 4);
    return {
      slot,
      label: meta.label || slot,
      icon: meta.icon || '?',
      image: item ? item.image_url : meta.image,
      name: item ? item.name_cn : null,
      rareLevel: item ? item.rare_level : 0,
      levelReq: item ? item.level_requirement : 0,
      actionLabel: item ? item.action_label : '',
      actionCmd: item ? item.action_cmd : '',
      alternates: alts.map(alt => ({
        name: alt.name_cn,
        rareLevel: alt.rare_level,
        actionLabel: alt.action_label,
        actionCmd: alt.action_cmd,
      })),
    };
  }).filter(card => card.name || card.alternates.length > 0);
}
