import React, { useEffect, useState, useCallback } from 'react';
import {
  View, Text, FlatList, TouchableOpacity, StyleSheet,
  RefreshControl, Modal, ActivityIndicator,
} from 'react-native';
import { useGameStore } from '../store/useGameStore.js';
import { getImageBase } from '../api/mudApi.js';
import {
  fetchEquipmentPanel, panelCards,
} from '../api/equipmentApi.js';
import { SmartImage } from './GameSmartImage.js';

const RARE_COLORS = {
  0: '#8a7a8a', 1: '#a89aa8', 2: '#5a8a6a',
  3: '#3a6ac2', 4: '#8a3ac2', 5: '#d4af37', 6: '#ff4d6d', 7: '#FFD700',
};

function rareColor(level) {
  return RARE_COLORS[level] || RARE_COLORS[0];
}

export default function EquipmentPanel({ visible, onClose }) {
  const { txd, apiBase, command } = useGameStore();
  const [loading, setLoading] = useState(false);
  const [cards, setCards] = useState([]);
  const [error, setError] = useState('');
  const imageBase = getImageBase(apiBase);

  const load = useCallback(async () => {
    if (!txd) return;
    setLoading(true);
    setError('');
    try {
      const data = await fetchEquipmentPanel(apiBase, txd);
      setCards(panelCards(data));
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [txd, apiBase]);

  useEffect(() => {
    if (visible) load();
  }, [visible]);

  const equip = cmd => {
    if (!cmd) return;
    command(cmd);
    setTimeout(load, 600);
  };

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose}>
      <View style={styles.screen}>
        <View style={styles.header}>
          <View>
            <Text style={styles.eyebrow}>装备管理</Text>
            <Text style={styles.title}>已穿戴 & 候选装备</Text>
          </View>
          <TouchableOpacity onPress={load} style={styles.refreshBtn}>
            <Text style={styles.refreshText}>↻ 刷新</Text>
          </TouchableOpacity>
          <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
            <Text style={styles.closeText}>✕ 返回游戏</Text>
          </TouchableOpacity>
        </View>

        {loading && cards.length === 0 && (
          <View style={styles.centerWrap}>
            <ActivityIndicator size="large" color="#d4af37" />
          </View>
        )}

        {!!error && (
          <View style={styles.errorPill}>
            <Text style={styles.errorText}>{error}</Text>
          </View>
        )}

        <FlatList
          style={{ flex: 1 }}
          contentContainerStyle={{ padding: 14, gap: 10 }}
          data={cards}
          keyExtractor={item => item.slot}
          refreshControl={
            <RefreshControl refreshing={loading} onRefresh={load}
              tintColor="#a89aa8" />
          }
          renderItem={({ item }) => (
            <View style={styles.card}>
              <View style={styles.cardTop}>
                <SmartImage
                  uri={item.image ? `${imageBase}${item.image}` : ''}
                  style={styles.itemImage}
                />
                <View style={{ flex: 1 }}>
                  <View style={styles.nameRow}>
                    <Text style={styles.slotIcon}>{item.icon}</Text>
                    <Text style={styles.slotLabel}>{item.label}</Text>
                    {item.rareLevel > 0 && (
                      <View style={[styles.rareBadge,
                        { borderColor: rareColor(item.rareLevel) }]}>
                        <Text style={[styles.rareText,
                          { color: rareColor(item.rareLevel) }]}>
                          +{item.rareLevel}
                        </Text>
                      </View>
                    )}
                  </View>
                  {item.name ? (
                    <Text style={[styles.itemName,
                      { color: rareColor(item.rareLevel) }]}
                      numberOfLines={1}>
                      {item.name}
                      {item.levelReq > 0
                        ? ` (Lv.${item.levelReq})` : ''}
                    </Text>
                  ) : (
                    <Text style={styles.emptySlot}>空槽位</Text>
                  )}
                </View>
                {item.actionCmd && (
                  <TouchableOpacity
                    style={styles.actionBtn}
                    onPress={() => equip(item.actionCmd)}>
                    <Text style={styles.actionText}>
                      {item.actionLabel}
                    </Text>
                  </TouchableOpacity>
                )}
              </View>

              {item.alternates.length > 0 && (
                <View style={styles.altRow}>
                  <Text style={styles.altLabel}>候选:</Text>
                  {item.alternates.map((alt, index) => (
                    <TouchableOpacity key={index}
                      style={[styles.altChip,
                        { borderColor: rareColor(alt.rareLevel) }]}
                      onPress={() => equip(alt.actionCmd)}>
                      <Text style={[styles.altText,
                        { color: rareColor(alt.rareLevel) }]}
                        numberOfLines={1}>
                        {alt.name}
                      </Text>
                    </TouchableOpacity>
                  ))}
                </View>
              )}
            </View>
          )}
          ListEmptyComponent={
            !loading ? (
              <Text style={styles.empty}>暂无装备数据</Text>
            ) : null
          }
        />
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#0d0b0e', paddingTop: 54 },
  header: {
    flexDirection: 'row', alignItems: 'center', gap: 8,
    paddingHorizontal: 16, paddingVertical: 10,
    borderBottomWidth: 1, borderBottomColor: '#2e2430',
    backgroundColor: '#14101a',
  },
  eyebrow: { color: '#8a7a8a', fontSize: 11 },
  title: { color: '#f0e6d2', fontSize: 17, fontWeight: '700' },
  refreshBtn: {
    paddingHorizontal: 10, paddingVertical: 5, borderRadius: 8,
    borderWidth: 1, borderColor: '#3a2f46',
  },
  refreshText: { color: '#a89aa8', fontSize: 12 },
  closeBtn: {
    paddingHorizontal: 10, paddingVertical: 5, borderRadius: 8,
    borderWidth: 1, borderColor: '#5a3a46',
  },
  closeText: { color: '#c8a8b8', fontSize: 12 },
  centerWrap: {
    flex: 1, alignItems: 'center', justifyContent: 'center',
  },
  errorPill: {
    margin: 12, backgroundColor: '#3d1018', borderRadius: 8,
    borderWidth: 1, borderColor: '#ff4d6d', paddingHorizontal: 12,
    paddingVertical: 8,
  },
  errorText: { color: '#ff9aa8', fontSize: 13 },
  card: {
    backgroundColor: '#17131c', borderRadius: 12,
    borderWidth: 1, borderColor: '#3a2f46', padding: 10,
  },
  cardTop: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  itemImage: {
    width: 44, height: 44, borderRadius: 8,
    borderWidth: 1, borderColor: '#8a6d2f',
  },
  nameRow: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  slotIcon: { color: '#d4af37', fontSize: 13 },
  slotLabel: { color: '#a89aa8', fontSize: 11 },
  rareBadge: {
    borderWidth: 1, borderRadius: 4,
    paddingHorizontal: 4, paddingVertical: 1,
  },
  rareText: { fontSize: 9, fontWeight: '700' },
  itemName: { fontSize: 13, fontWeight: '600', marginTop: 3 },
  emptySlot: { color: '#5a4a5a', fontSize: 12, marginTop: 3 },
  actionBtn: {
    paddingHorizontal: 12, paddingVertical: 6, borderRadius: 8,
    backgroundColor: '#2d2410', borderWidth: 1, borderColor: '#8a6d2f',
  },
  actionText: { color: '#ffd700', fontSize: 12 },
  altRow: {
    flexDirection: 'row', flexWrap: 'wrap', alignItems: 'center',
    gap: 6, marginTop: 8, paddingTop: 8,
    borderTopWidth: 1, borderTopColor: '#2e2430',
  },
  altLabel: { color: '#6a5a6a', fontSize: 10 },
  altChip: {
    borderWidth: 1, borderRadius: 6, paddingHorizontal: 8,
    paddingVertical: 3, maxWidth: 140,
  },
  altText: { fontSize: 11 },
  empty: { color: '#6a5a6a', textAlign: 'center', paddingTop: 60 },
});
