import React, { useEffect, useState, useCallback } from 'react';
import {
  View, Text, ScrollView, TouchableOpacity, StyleSheet,
  Modal, ActivityIndicator,
} from 'react-native';
import { useGameStore } from '../store/useGameStore.js';
import { getImageBase } from '../api/mudApi.js';
import { fetchEquipmentPanel, panelModel, attrRows, attrTotalDelta } from '../api/equipmentApi.js';
import { SmartImage } from './GameSmartImage.js';

const RARE_COLORS = {
  0: '#8a7a8a', 1: '#a89aa8', 2: '#5a8a6a',
  3: '#3a6ac2', 4: '#8a3ac2', 5: '#d4af37', 6: '#ff4d6d', 7: '#FFD700',
};

function rareColor(level) {
  return RARE_COLORS[level] || RARE_COLORS[0];
}

/** 候选 vs 已穿戴 的逐属性增减小条。 */
function AttrDiffChips({ candidate, equipped }) {
  const rows = attrRows(candidate && candidate.attrs, equipped && equipped.attrs);
  if (rows.length === 0) return null;
  return (
    <View style={styles.diffRow}>
      {rows.slice(0, 6).map(row => {
        const up = row.delta > 0;
        const flat = row.delta === 0;
        return (
          <View key={row.key} style={[styles.diffChip,
            flat && styles.diffChipFlat,
            !flat && (up ? styles.diffChipUp : styles.diffChipDown)]}>
            <Text style={[styles.diffText,
              { color: flat ? '#8a7a8a' : up ? '#5ad47a' : '#ff5a6a' }]}>
              {row.label} {up ? '+' : flat ? '' : '−'}
              {Math.abs(row.delta)}
            </Text>
          </View>
        );
      })}
    </View>
  );
}

/** 人体剪影：头/躯干/双臂/双腿（对应网页版 equipment-human-silhouette）。 */
function HumanSilhouette() {
  return (
    <View style={silStyles.figure} pointerEvents="none">
      <View style={silStyles.head} />
      <View style={silStyles.torso} />
      <View style={[silStyles.arm, silStyles.armLeft]} />
      <View style={[silStyles.arm, silStyles.armRight]} />
      <View style={[silStyles.leg, silStyles.legLeft]} />
      <View style={[silStyles.leg, silStyles.legRight]} />
      <View style={silStyles.aura} />
    </View>
  );
}

const silStyles = StyleSheet.create({
  figure: {
    width: 96, height: 210, position: 'relative',
    alignItems: 'center',
  },
  head: {
    position: 'absolute', top: 0, width: 34, height: 38,
    borderRadius: 17, backgroundColor: '#241a2e',
    borderWidth: 1, borderColor: '#3e2f4c',
  },
  torso: {
    position: 'absolute', top: 42, width: 46, height: 82,
    borderRadius: 14, backgroundColor: '#241a2e',
    borderWidth: 1, borderColor: '#3e2f4c',
  },
  arm: {
    position: 'absolute', top: 48, width: 11, height: 72,
    borderRadius: 6, backgroundColor: '#1e1628',
    borderWidth: 1, borderColor: '#352a44',
  },
  armLeft: { left: 8, transform: [{ rotate: '7deg' }] },
  armRight: { right: 8, transform: [{ rotate: '-7deg' }] },
  leg: {
    position: 'absolute', top: 126, width: 14, height: 76,
    borderRadius: 7, backgroundColor: '#1e1628',
    borderWidth: 1, borderColor: '#352a44',
  },
  legLeft: { left: 24 },
  legRight: { right: 24 },
  aura: {
    position: 'absolute', top: -8, left: -10, right: -10, bottom: -6,
    borderRadius: 60, borderWidth: 1, borderColor: 'rgba(212,175,55,0.22)',
    backgroundColor: 'rgba(212,175,55,0.04)',
  },
});

export default function EquipmentPanel({ visible, onClose }) {
  const { txd, apiBase, command, status } = useGameStore();
  const [loading, setLoading] = useState(false);
  const [model, setModel] = useState(null);
  const [selected, setSelected] = useState('');
  const [busyCmd, setBusyCmd] = useState('');
  const [smartBusy, setSmartBusy] = useState(false);
  const [error, setError] = useState('');
  const imageBase = getImageBase(apiBase);

  const load = useCallback(async () => {
    if (!txd) return;
    setLoading(true);
    setError('');
    try {
      const data = await fetchEquipmentPanel(apiBase, txd);
      const next = panelModel(data);
      setModel(next);
      setSelected(prev =>
        next.slotOrder.includes(prev) ? prev : (next.slotOrder[0] || ''));
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [txd, apiBase]);

  useEffect(() => {
    if (visible) load();
  }, [visible]);

  const act = item => {
    if (!item || !item.actionCmd || busyCmd) return;
    setBusyCmd(item.actionCmd);
    command(item.actionCmd);
    setTimeout(() => {
      setBusyCmd('');
      load();
    }, 700);
  };

  /* 一键智能穿装：补空位 + 换同槽更强的普通装备（服务端保护
   * 强化/融合/宝石/稀有装备，评分严格更高才替换）。 */
  const smartEquip = () => {
    if (smartBusy) return;
    setSmartBusy(true);
    command('auto_equip smart');
    setTimeout(() => {
      setSmartBusy(false);
      load();
    }, 1100);
  };

  const player = (model && model.player) || {};
  const slots = (model && model.slots) || [];
  const selectedSlot = slots.find(s => s.slot === selected) || null;
  const avatarUrl = status && status.avatar
    ? `${imageBase}${status.avatar}` : '';

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose}>
      <View style={styles.screen}>
        <View style={styles.header}>
          <View style={styles.avatarShell}>
            {avatarUrl ? (
              <SmartImage uri={avatarUrl} style={styles.avatar} />
            ) : (
              <Text style={styles.avatarFallback}>
                {(player.name_cn || '道').slice(0, 1)}
              </Text>
            )}
          </View>
          <View style={{ flex: 1 }}>
            <Text style={styles.eyebrow}>人物外观 · 快速换装</Text>
            <Text style={styles.title}>{player.name_cn || '我的装备'}</Text>
            {player.name ? (
              <Text style={styles.sub}>
                Lv.{player.level || '?'} · {player.profession || ''}
              </Text>
            ) : null}
          </View>
          <TouchableOpacity onPress={load} style={styles.iconBtn}>
            <Text style={styles.iconBtnText}>↻</Text>
          </TouchableOpacity>
          <TouchableOpacity onPress={onClose} style={styles.iconBtnClose}>
            <Text style={styles.iconBtnText}>✕</Text>
          </TouchableOpacity>
        </View>

        {loading && !model && (
          <View style={styles.centerWrap}>
            <ActivityIndicator size="large" color="#d4af37" />
            <Text style={styles.loadingText}>正在整理装备栏...</Text>
          </View>
        )}

        {!!error && (
          <View style={styles.errorPill}>
            <Text style={styles.errorText}>{error}</Text>
            <TouchableOpacity onPress={load} style={styles.retryBtn}>
              <Text style={styles.retryText}>重试</Text>
            </TouchableOpacity>
          </View>
        )}

        {model && (
          <ScrollView style={{ flex: 1 }}
            contentContainerStyle={{ padding: 12, paddingBottom: 40 }}>
            {/* 一键智能穿装：补空位+换更强（服务端评分与保护） */}
            <TouchableOpacity style={styles.smartBtn}
              activeOpacity={0.7} onPress={smartEquip} disabled={smartBusy}>
              <Text style={styles.smartBtnText}>
                {smartBusy ? '⚡ 智能穿装中…' : '⚡ 一键智能穿装'}
              </Text>
              <Text style={styles.smartBtnHint}>
                自动补空位 · 换更强普通装备（强化/稀有装备不动）
              </Text>
            </TouchableOpacity>

            {/* 当前选择详情：固定在网格上方，点选槽位立即可见操作 */}
            {selectedSlot && (
              <View style={styles.choicePanel}>
                <View style={styles.choiceTitleRow}>
                  <Text style={styles.choiceIcon}>{selectedSlot.icon}</Text>
                  <View>
                    <Text style={styles.choiceEyebrow}>当前选择</Text>
                    <Text style={styles.choiceTitle}>{selectedSlot.label}</Text>
                  </View>
                </View>

                {selectedSlot.equipped ? (
                  <View style={[
                    styles.currentCard,
                    { borderColor: rareColor(selectedSlot.equipped.rareLevel) },
                  ]}>
                    <SmartImage
                      uri={selectedSlot.equipped.image
                        ? `${imageBase}${selectedSlot.equipped.image}` : ''}
                      style={styles.itemArt} />
                    <View style={{ flex: 1 }}>
                      <Text style={styles.currentTag}>已穿戴</Text>
                      <Text style={[
                        styles.itemName,
                        { color: rareColor(selectedSlot.equipped.rareLevel) },
                      ]} numberOfLines={1}>
                        {selectedSlot.equipped.name}
                      </Text>
                      <Text style={styles.itemMeta}>
                        需求 Lv.{selectedSlot.equipped.levelReq}
                        {selectedSlot.equipped.rareLevel > 0
                          ? ` · 品阶 ${selectedSlot.equipped.rareLevel}` : ''}
                      </Text>
                    </View>
                    <TouchableOpacity
                      style={[styles.actionBtn, styles.actionBtnSecondary]}
                      disabled={!!busyCmd}
                      onPress={() => act(selectedSlot.equipped)}>
                      <Text style={styles.actionTextSecondary}>
                        {busyCmd === selectedSlot.equipped.actionCmd
                          ? '处理中' : '卸下'}
                      </Text>
                    </TouchableOpacity>
                  </View>
                ) : (
                  <Text style={styles.currentEmpty}>这个部位还没有装备</Text>
                )}

                <View style={styles.candidateHeading}>
                  <Text style={styles.candidateHeadingText}>背包可替换装备</Text>
                  <Text style={styles.candidateCount}>
                    {selectedSlot.candidates.length} 件
                  </Text>
                </View>
                {selectedSlot.candidates.map(item => {
                  const rows = attrRows(item.attrs,
                    selectedSlot.equipped && selectedSlot.equipped.attrs);
                  const total = attrTotalDelta(rows);
                  const badge = !selectedSlot.equipped ? null
                    : total > 0 ? 'up' : total < 0 ? 'down' : 'flat';
                  return (
                    <View key={item.id} style={[
                      styles.candidateCard,
                      { borderColor: rareColor(item.rareLevel) },
                    ]}>
                      <View style={styles.candidateTopRow}>
                        <SmartImage
                          uri={item.image ? `${imageBase}${item.image}` : ''}
                          style={styles.itemArt} />
                        <View style={{ flex: 1 }}>
                          <View style={styles.candidateNameRow}>
                            <Text style={[
                              styles.itemName,
                              { color: rareColor(item.rareLevel) },
                            ]} numberOfLines={1}>
                              {item.name}
                            </Text>
                            {badge && (
                              <View style={[
                                styles.badge,
                                badge === 'up' && styles.badgeUp,
                                badge === 'down' && styles.badgeDown,
                                badge === 'flat' && styles.badgeFlat,
                              ]}>
                                <Text style={[
                                  styles.badgeText,
                                  badge === 'up' && { color: '#5ad47a' },
                                  badge === 'down' && { color: '#ff5a6a' },
                                ]}>
                                  {badge === 'up' ? '↑ 提升' : badge === 'down' ? '↓ 下降' : '持平'}
                                </Text>
                              </View>
                            )}
                          </View>
                          <Text style={styles.itemMeta}>
                            需求 Lv.{item.levelReq} · 品阶 {item.rareLevel}
                          </Text>
                        </View>
                        <TouchableOpacity style={styles.actionBtn}
                          disabled={!!busyCmd}
                          onPress={() => act(item)}>
                          <Text style={styles.actionText}>
                            {busyCmd === item.actionCmd ? '处理中' : '穿戴'}
                          </Text>
                        </TouchableOpacity>
                      </View>
                      <AttrDiffChips candidate={item}
                        equipped={selectedSlot.equipped} />
                    </View>
                  );
                })}
                {selectedSlot.candidates.length === 0 && (
                  <Text style={styles.candidateEmpty}>
                    背包中没有这个部位的备用装备
                  </Text>
                )}

                <Text style={styles.safetyNote}>
                  等级、职业与属性由服务器校验；替换后原装备会安全回到背包。
                </Text>
              </View>
            )}

            {/* 人物剪影 + 槽位网格（紧凑三列，名称看上方详情卡） */}
            <View style={styles.figureStage}>
              <View style={styles.silhouetteWrap}>
                <HumanSilhouette />
                <Text style={styles.silhouetteHint}>点选部位换装</Text>
              </View>
              <View style={styles.slotGrid}>
                {slots.map(slot => {
                  const item = slot.equipped;
                  const isSel = slot.slot === selected;
                  return (
                    <TouchableOpacity key={slot.slot} style={[
                      styles.slotTile,
                      isSel && styles.slotTileSelected,
                      item && styles.slotTileFilled,
                    ]} onPress={() => setSelected(slot.slot)}>
                      <View style={[
                        styles.slotIconBox,
                        item && { borderColor: rareColor(item.rareLevel) },
                      ]}>
                        {item && item.image ? (
                          <SmartImage
                            uri={`${imageBase}${item.image}`}
                            style={styles.slotImage} />
                        ) : (
                          <Text style={styles.slotIconText}>{slot.icon}</Text>
                        )}
                      </View>
                      <Text style={styles.slotLabel} numberOfLines={1}>
                        {slot.label}
                      </Text>
                    </TouchableOpacity>
                  );
                })}
              </View>
            </View>
          </ScrollView>
        )}
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#0d0b0e', paddingTop: 54 },
  header: {
    flexDirection: 'row', alignItems: 'center', gap: 10,
    paddingHorizontal: 14, paddingVertical: 10,
    borderBottomWidth: 1, borderBottomColor: '#2e2430',
    backgroundColor: '#14101a',
  },
  avatarShell: {
    width: 52, height: 52, borderRadius: 26, overflow: 'hidden',
    borderWidth: 1, borderColor: '#8a6d2f',
    backgroundColor: '#1c1522', alignItems: 'center', justifyContent: 'center',
  },
  avatar: { width: 52, height: 52 },
  avatarFallback: { color: '#d4af37', fontSize: 22, fontWeight: '700' },
  eyebrow: { color: '#8a7a8a', fontSize: 10 },
  title: { color: '#f0e6d2', fontSize: 17, fontWeight: '700' },
  sub: { color: '#a89aa8', fontSize: 11, marginTop: 1 },
  iconBtn: {
    width: 34, height: 34, borderRadius: 17, alignItems: 'center',
    justifyContent: 'center', borderWidth: 1, borderColor: '#3a2f46',
  },
  iconBtnClose: {
    width: 34, height: 34, borderRadius: 17, alignItems: 'center',
    justifyContent: 'center', borderWidth: 1, borderColor: '#5a3a46',
  },
  iconBtnText: { color: '#a89aa8', fontSize: 15 },
  centerWrap: {
    flex: 1, alignItems: 'center', justifyContent: 'center', gap: 10,
  },
  loadingText: { color: '#8a7a8a', fontSize: 12 },
  errorPill: {
    margin: 12, backgroundColor: '#3d1018', borderRadius: 8,
    borderWidth: 1, borderColor: '#ff4d6d',
    paddingHorizontal: 12, paddingVertical: 8,
    flexDirection: 'row', alignItems: 'center', gap: 10,
  },
  errorText: { color: '#ff9aa8', fontSize: 13, flex: 1 },
  retryBtn: { paddingHorizontal: 10, paddingVertical: 4 },
  retryText: { color: '#ffd700', fontSize: 12 },
  figureStage: {
    flexDirection: 'row', gap: 10, alignItems: 'flex-start',
    backgroundColor: '#12101a', borderRadius: 14,
    borderWidth: 1, borderColor: '#2c2338', padding: 12,
  },
  silhouetteWrap: {
    width: 110, alignItems: 'center', paddingTop: 6, gap: 8,
  },
  silhouetteHint: { color: '#6a5a6a', fontSize: 10 },
  slotGrid: {
    flex: 1, flexDirection: 'row', flexWrap: 'wrap', gap: 6,
  },
  slotTile: {
    width: '31%', borderRadius: 8, padding: 4,
    borderWidth: 1, borderColor: '#2c2338', backgroundColor: '#17131c',
    alignItems: 'center',
  },
  slotTileSelected: {
    borderColor: '#d4af37',
    backgroundColor: '#231b10',
    shadowColor: '#d4af37', shadowOpacity: 0.4, shadowRadius: 8,
  },
  slotTileFilled: { backgroundColor: '#1a1622' },
  slotIconBox: {
    width: 34, height: 34, borderRadius: 7, borderWidth: 1,
    borderColor: '#3a2f46', alignItems: 'center', justifyContent: 'center',
    backgroundColor: '#0f0c14', overflow: 'hidden',
  },
  slotImage: { width: 32, height: 32 },
  slotIconText: { color: '#8a7a8a', fontSize: 14 },
  slotLabel: { color: '#a89aa8', fontSize: 9, marginTop: 3 },
  choicePanel: {
    marginTop: 12, backgroundColor: '#12101a', borderRadius: 14,
    borderWidth: 1, borderColor: '#2c2338', padding: 12, gap: 10,
  },
  choiceTitleRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  choiceIcon: { color: '#d4af37', fontSize: 20 },
  choiceEyebrow: { color: '#8a7a8a', fontSize: 10 },
  choiceTitle: { color: '#f0e6d2', fontSize: 15, fontWeight: '700' },
  currentCard: {
    flexDirection: 'row', alignItems: 'center', gap: 10,
    backgroundColor: '#17131c', borderRadius: 10,
    borderWidth: 1, padding: 10,
  },
  itemArt: {
    width: 44, height: 44, borderRadius: 8,
    borderWidth: 1, borderColor: '#8a6d2f',
  },
  currentTag: { color: '#5a8a6a', fontSize: 10 },
  itemName: { color: '#f0e6d2', fontSize: 13, fontWeight: '600' },
  itemMeta: { color: '#8a7a8a', fontSize: 10, marginTop: 2 },
  actionBtn: {
    paddingHorizontal: 14, paddingVertical: 7, borderRadius: 8,
    backgroundColor: '#2d2410', borderWidth: 1, borderColor: '#8a6d2f',
  },
  actionText: { color: '#ffd700', fontSize: 12 },
  actionBtnSecondary: {
    backgroundColor: '#1c1520', borderColor: '#3a2f46',
  },
  actionTextSecondary: { color: '#a89aa8', fontSize: 12 },
  currentEmpty: {
    color: '#6a5a6a', fontSize: 12, textAlign: 'center',
    paddingVertical: 10,
  },
  candidateHeading: {
    flexDirection: 'row', justifyContent: 'space-between',
    alignItems: 'center', marginTop: 2,
  },
  candidateHeadingText: { color: '#a89aa8', fontSize: 12, fontWeight: '700' },
  candidateCount: { color: '#6a5a6a', fontSize: 10 },
  candidateCard: {
    backgroundColor: '#151219', borderRadius: 10,
    borderWidth: 1, padding: 9, gap: 8,
  },
  candidateTopRow: {
    flexDirection: 'row', alignItems: 'center', gap: 10,
  },
  candidateNameRow: {
    flexDirection: 'row', alignItems: 'center', gap: 6, flex: 1,
  },
  badge: {
    borderWidth: 1, borderRadius: 5, paddingHorizontal: 5, paddingVertical: 1,
  },
  badgeUp: { borderColor: '#2d5a3a', backgroundColor: '#10241a' },
  badgeDown: { borderColor: '#5a2d3a', backgroundColor: '#241016' },
  badgeFlat: { borderColor: '#3a2f46' },
  badgeText: { fontSize: 10, fontWeight: '700', color: '#8a7a8a' },
  diffRow: {
    flexDirection: 'row', flexWrap: 'wrap', gap: 5,
  },
  diffChip: {
    borderRadius: 5, paddingHorizontal: 6, paddingVertical: 2,
    borderWidth: 1,
  },
  diffChipUp: { borderColor: '#2d5a3a', backgroundColor: '#10241a' },
  diffChipDown: { borderColor: '#5a2d3a', backgroundColor: '#241016' },
  diffChipFlat: { borderColor: '#2c2338' },
  diffText: { fontSize: 10, fontWeight: '600' },
  smartBtn: {
    borderRadius: 12, borderWidth: 1, borderColor: '#8a6d2f',
    backgroundColor: '#231b10', alignItems: 'center',
    paddingVertical: 10, marginBottom: 10, gap: 2,
  },
  smartBtnText: { color: '#ffd700', fontSize: 15, fontWeight: '800' },
  smartBtnHint: { color: '#8a7a8a', fontSize: 10 },
  candidateEmpty: {
    color: '#6a5a6a', fontSize: 11, textAlign: 'center', paddingVertical: 8,
  },
  safetyNote: {
    color: '#5a4a5a', fontSize: 10, textAlign: 'center', marginTop: 2,
  },
});
