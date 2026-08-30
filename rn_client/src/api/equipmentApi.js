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
