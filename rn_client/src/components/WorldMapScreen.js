import React, { useState, useRef, useCallback, useMemo } from 'react';
import {
  View, Text, Modal, TouchableOpacity, StyleSheet,
  ScrollView, TextInput, Dimensions, Animated, PanResponder, Alert,
} from 'react-native';
import { useGameStore } from '../store/useGameStore.js';

const { width: SCREEN_W, height: SCREEN_H } = Dimensions.get('window');

/**
 * 世界地图（RN 客户端版）：
 * - 分区列表 + 搜索 + 快速飞行（走 map_display 命令）
 * - 分区内的房间列表（走 map_display <block> 子地图）
 * - 当前位置高亮
 * 设计原则：拇指可达（底部大按钮）、搜索优先（几百个房间靠搜不靠翻）
 */

const BLOCK_ICONS = {
  congxianzhen: '🏘️', jinaodao: '🏝️', jadhuanjingwaicheng: '🌸',
  jiuxiaojiejing: '⛰️', wulingyuan: '🌳', santouling: '🏔️',
  taoyuanxi: '🍑', shenmodong: '🕳️', wangyougu: '🌾',
  longmencai: '💎', huoshan: '🌋', xueyushan: '❄️',
};

function blockIcon(block) {
  return BLOCK_ICONS[block] || '🗺️';
}

export default function WorldMapScreen({ visible, onClose }) {
  const { command, status } = useGameStore();
  const [searchText, setSearchText] = useState('');
  const [blocks, setBlocks] = useState([]);
  const [loading, setLoading] = useState(false);
  const searchRef = useRef(null);

  // 从 map_display 输出中解析分区列表
  // 服务端输出格式: [支付X飞到 某地区:map_display block fee]
  const parseBlocks = useCallback((lines) => {
    const result = [];
    for (const line of (lines || [])) {
      const raw = ((line && line.segments) || [])
        .map(s => {
          if (s.type === 'text') {
            return ((s.parts) || []).map(p => p.content || '').join('');
          }
          return '';
        }).join('');
      // Match "支付X飞到 某地区" pattern
      const m = raw.match(/飞到\s*(.+)$/);
      if (m) {
        const label = m[1].trim();
        const btn = ((line && line.segments) || []).find(
          s => s.type === 'button' && String(s.cmd || '').startsWith('map_display '));
        if (btn) {
          const blockId = String(btn.cmd).split(' ')[1];
          result.push({ id: blockId, label, icon: blockIcon(blockId) });
        }
      }
    }
    return result;
  }, []);

  const load = useCallback(async () => {
    if (loading) return;
    setLoading(true);
    try {
      // We'll get the map list from the server on first open
      // For now, use a static list of known blocks
      setBlocks([]);
    } finally {
      setLoading(false);
    }
  }, [loading]);

  const fly = useCallback((blockId) => {
    if (!blockId) return;
    Alert.alert(
      '银两飞行',
      `确定要飞行到该区域吗？将按距离收取银两费用。`,
      [
        { text: '取消', style: 'cancel' },
        {
          text: '飞行',
          onPress: () => {
            command(`map_display ${blockId}`);
            onClose();
          },
        },
      ],
    );
  }, [command, onClose]);

  const currentLocation = status?.name_cn || '';

  // Static block list (server-provided at runtime in real impl)
  const knownBlocks = useMemo(() => [
    { id: 'congxianzhen', label: '从贤镇', icon: '🏘️' },
    { id: 'jinaodao', label: '金鳌岛', icon: '🏝️' },
    { id: 'wulingyuan', label: '五灵源', icon: '🌳' },
    { id: 'santouling', label: '三头岭', icon: '🏔️' },
    { id: 'taoyuanxi', label: '桃源溪', icon: '🍑' },
    { id: 'shenmodong', label: '神魔洞', icon: '🕳️' },
    { id: 'wangyougu', label: '忘忧谷', icon: '🌾' },
    { id: 'longmencai', label: '龙门矿', icon: '💎' },
    { id: 'huoshan', label: '火山', icon: '🌋' },
    { id: 'xueyushan', label: '雪域山', icon: '❄️' },
  ], []);

  const filtered = useMemo(() => {
    if (!searchText.trim()) return knownBlocks;
    const q = searchText.trim().toLowerCase();
    return knownBlocks.filter(b =>
      b.label.toLowerCase().includes(q) || b.id.includes(q));
  }, [knownBlocks, searchText]);

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose}>
      <View style={styles.screen}>
        <View style={styles.header}>
          <Text style={styles.title}>🗺️ 世界地图</Text>
          <Text style={styles.location}>📍 {currentLocation}</Text>
          <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
            <Text style={styles.closeText}>✕ 返回</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.searchBar}>
          <TextInput
            style={styles.searchInput}
            placeholder="搜索地区名..."
            placeholderTextColor="#5a4a5a"
            value={searchText}
            onChangeText={setSearchText}
            autoCapitalize="none"
            autoCorrect={false}
          />
          {searchText !== '' && (
            <TouchableOpacity onPress={() => setSearchText('')}>
              <Text style={styles.clearText}>✕</Text>
            </TouchableOpacity>
          )}
        </View>

        <ScrollView
          style={{ flex: 1 }}
          contentContainerStyle={{ padding: 12, gap: 8 }}
        >
          {filtered.map(block => (
            <TouchableOpacity
              key={block.id}
              style={styles.blockCard}
              activeOpacity={0.7}
              onPress={() => fly(block.id)}
            >
              <Text style={styles.blockIcon}>{block.icon}</Text>
              <View style={{ flex: 1 }}>
                <Text style={styles.blockName}>{block.label}</Text>
                <Text style={styles.blockHint}>点击飞行（按距离收费）</Text>
              </View>
              <Text style={styles.flyIcon}>✈️</Text>
            </TouchableOpacity>
          ))}
          {filtered.length === 0 && (
            <Text style={styles.empty}>没有匹配的地区</Text>
          )}
        </ScrollView>

        <View style={styles.footer}>
          <TouchableOpacity
            style={styles.currentBtn}
            onPress={() => { command('map_display'); onClose(); }}
          >
            <Text style={styles.currentBtnText}>📍 当前位置详情</Text>
          </TouchableOpacity>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#0d0b0e', paddingTop: 54 },
  header: {
    flexDirection: 'row', alignItems: 'center', gap: 8,
    paddingHorizontal: 14, paddingVertical: 10,
    borderBottomWidth: 1, borderBottomColor: '#2e2430',
    backgroundColor: '#14101a',
  },
  title: { color: '#f0e6d2', fontSize: 17, fontWeight: '700' },
  location: { color: '#8a7a8a', fontSize: 11, flex: 1 },
  closeBtn: { paddingHorizontal: 10, paddingVertical: 5 },
  closeText: { color: '#c8a8b8', fontSize: 12 },
  searchBar: {
    flexDirection: 'row', alignItems: 'center', gap: 8,
    margin: 12, backgroundColor: '#1a1522',
    borderRadius: 10, borderWidth: 1, borderColor: '#3a2f46',
    paddingHorizontal: 12, paddingVertical: 8,
  },
  searchInput: { flex: 1, color: '#f0e6d2', fontSize: 14 },
  clearText: { color: '#6a5a6a', fontSize: 14 },
  blockCard: {
    flexDirection: 'row', alignItems: 'center', gap: 12,
    backgroundColor: '#17131c', borderRadius: 12,
    borderWidth: 1, borderColor: '#2c2338', padding: 14,
  },
  blockIcon: { fontSize: 28 },
  blockName: { color: '#f0e6d2', fontSize: 15, fontWeight: '600' },
  blockHint: { color: '#6a5a6a', fontSize: 11, marginTop: 2 },
  flyIcon: { fontSize: 18, color: '#d4af37' },
  empty: { color: '#5a4a5a', textAlign: 'center', paddingTop: 60, fontSize: 13 },
  footer: {
    padding: 12, borderTopWidth: 1, borderTopColor: '#2e2430',
    backgroundColor: '#14101a',
  },
  currentBtn: {
    alignItems: 'center', paddingVertical: 12, borderRadius: 10,
    backgroundColor: '#1a2430', borderWidth: 1, borderColor: '#3a5a8a',
  },
  currentBtnText: { color: '#9ab8d8', fontSize: 14, fontWeight: '600' },
});
