import React, { useState, useRef, useCallback, useMemo, useEffect } from 'react';
import {
  View, Text, Modal, TouchableOpacity, StyleSheet,
  TextInput, Dimensions, Alert, ActivityIndicator, ScrollView,
} from 'react-native';
import Svg, { Circle, Line, Text as SvgText, G } from 'react-native-svg';
import { useGameStore } from '../store/useGameStore.js';
import { getApiBase } from '../api/mudApi.js';

const { width: SCREEN_W, height: SCREEN_H } = Dimensions.get('window');

/**
 * 世界地图（RN 客户端版，与 Vue 网页版同源数据）：
 * - 数据：GET {apiBase}/api/world_map（2681 房间 / 76 区域完整拓扑）
 * - 交互：iOS/Android 原生 ScrollView 捏合缩放+拖动；房间点 Svg onPress
 * - LOD：onScroll 跟踪 zoomScale——缩小只画区域标记，放大画连线与房名
 * - 搜索全部房间；点房间/区域 → fly_to_room 飞行（与 Vue 相同命令）
 */

const K0 = 0.1;          // 世界坐标 → 内容坐标
const PAD = 600;         // 内容四周留白，避免边缘房间贴边

const BIOME_COLORS = {
  snow: '#9fc7e8', forest: '#5a9e6f', mountain: '#a08a6a', plain: '#8faa58',
  water: '#5a8ad0', desert: '#d0a85a', fire: '#d06a5a', swamp: '#6a8a5a',
  city: '#c8b98a', dark: '#7a6a8a', default: '#8a8aa0',
};

function biomeColor(biome) {
  return BIOME_COLORS[biome] || BIOME_COLORS.default;
}

export default function WorldMapScreen({ visible, onClose }) {
  const { command, status, lines } = useGameStore();
  const [graph, setGraph] = useState(null);
  const [loadError, setLoadError] = useState('');
  const [searchText, setSearchText] = useState('');
  const [selected, setSelected] = useState(null);
  const [regionOpen, setRegionOpen] = useState(null);
  const [zoom, setZoom] = useState(0);
  const scrollRef = useRef(null);

  /* ---------- 数据加载 ---------- */
  useEffect(() => {
    if (!visible || graph || loadError) return;
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch(getApiBase() + '/api/world_map');
        if (!res.ok) throw new Error('HTTP ' + res.status);
        const data = await res.json();
        if (!data || data.schema !== 1 || !Array.isArray(data.nodes) ||
            data.nodes.length < 1000) {
          throw new Error('world graph incomplete');
        }
        if (cancelled) return;
        data.nodeIndex = new Map(data.nodes.map(n => [n.id, n]));
        data.nameIndex = new Map();
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (const n of data.nodes) {
          if (!data.nameIndex.has(n.name)) data.nameIndex.set(n.name, n);
          if (n.x < minX) minX = n.x;
          if (n.y < minY) minY = n.y;
          if (n.x > maxX) maxX = n.x;
          if (n.y > maxY) maxY = n.y;
        }
        data.worldBounds = { minX, minY, maxX, maxY };
        data.contentW = (maxX - minX) * K0 + PAD * 2;
        data.contentH = (maxY - minY) * K0 + PAD * 2;
        /* 内容坐标系平移：世界原点 → (PAD, PAD)。 */
        for (const n of data.nodes) {
          n.cx = (n.x - minX) * K0 + PAD;
          n.cy = (n.y - minY) * K0 + PAD;
        }
        const regions = new Map();
        for (const n of data.nodes) {
          if (!regions.has(n.region)) {
            regions.set(n.region, { id: n.region, count: 0, sx: 0, sy: 0,
              level: n.level || 0 });
          }
          const r = regions.get(n.region);
          r.count += 1; r.sx += n.cx; r.sy += n.cy;
          if ((n.level || 0) > r.level) r.level = n.level || 0;
        }
        data.regionList = [...regions.values()].map(r => ({
          ...r, x: r.sx / r.count, y: r.sy / r.count,
        }));
        setGraph(data);
      } catch (e) {
        if (!cancelled) setLoadError('世界地图加载失败：' + (e.message || e));
      }
    })();
    return () => { cancelled = true; };
  }, [visible, graph, loadError]);

  /* 初始定位到当前房间并放大到房间点清晰可见的档位（zoom≈2）；
   * 捏合缩小可回到整图区域总览。 */
  useEffect(() => {
    if (!visible || !graph || zoom) return;
    const cur = findCurrentNode(graph, lines);
    if (!cur || !scrollRef.current) return;
    const rect = {
      x: cur.cx - SCREEN_W / 2, y: cur.cy - (SCREEN_H - 220) / 2,
      width: SCREEN_W * 2, height: (SCREEN_H - 220) * 2,
    };
    setTimeout(() => {
      try {
        const responder = scrollRef.current.getScrollResponder
          ? scrollRef.current.getScrollResponder() : scrollRef.current;
        if (responder && responder.scrollResponderZoomTo) {
          responder.scrollResponderZoomTo(rect);
        } else {
          scrollRef.current.scrollTo({
            x: rect.x, y: rect.y, animated: false,
          });
        }
      } catch (e) { /* 布局未就绪时忽略 */ }
    }, 160);
  }, [visible, graph, zoom, lines]);

  const minZoom = useMemo(() => {
    if (!graph) return 0.2;
    return Math.min(SCREEN_W / graph.contentW,
      (SCREEN_H - 180) / graph.contentH);
  }, [graph]);

  /* 视口状态（含偏移），按粗档位更新避免每帧重渲。 */
  const [viewport, setViewport] = useState({ x: 0, y: 0, z: 0 });

  /* ---------- LOD：按捏合缩放档位渲染 ---------- */
  const lod = useMemo(() => ({
    regionMode: zoom < 1.1,
    showEdges: zoom >= 1.8,
    showLabels: zoom >= 3.2,
  }), [zoom]);

  /* 视口裁剪：只渲染视野内（含边距）的房间与连线，控制元素数。
   * 房间点任何缩放档位都渲染（半径按缩放反向补偿=屏幕恒定大小），
   * 否则默认整图视图只剩区域圆（玩家反馈"看不到地图内部"）。 */
  const visibleNodes = useMemo(() => {
    if (!graph) return [];
    const m = 220;
    const vw = SCREEN_W / Math.max(zoom, 0.05) + m * 2;
    const vh = (SCREEN_H - 220) / Math.max(zoom, 0.05) + m * 2;
    const vx = viewport.x - m, vy = viewport.y - m;
    const out = [];
    for (const n of graph.nodes) {
      if (n.cx >= vx && n.cx <= vx + vw && n.cy >= vy && n.cy <= vy + vh) {
        out.push(n);
        if (out.length >= 1200) break;
      }
    }
    return out;
  }, [graph, zoom, viewport]);

  /* 内容半径按当前缩放反向补偿：屏幕上恒定约5px。 */
  const nodeR = 5 / Math.max(zoom || minZoom, 0.12);

  const visibleEdges = useMemo(() => {
    if (!graph || !lod.showEdges) return [];
    const ids = new Set(visibleNodes.map(n => n.id));
    const out = [];
    for (const e of graph.edges) {
      if (ids.has(e.from) && ids.has(e.to)) {
        out.push(e);
        if (out.length >= 500) break;
      }
    }
    return out;
  }, [graph, visibleNodes, lod.showEdges]);

  /* 当前房间：从最近的行里精确匹配房间名。 */
  const currentNode = useMemo(() =>
    findCurrentNode(graph, lines), [graph, lines]);

  /* ---------- 搜索 ---------- */
  const searchResults = useMemo(() => {
    if (!graph || !searchText.trim()) return [];
    const q = searchText.trim().toLowerCase();
    const out = [];
    for (const n of graph.nodes) {
      if ((n.name || '').toLowerCase().includes(q)) {
        out.push(n);
        if (out.length >= 30) break;
      }
    }
    return out;
  }, [graph, searchText]);

  const focusNode = n => {
    if (!n) return;
    setSelected(n);
    setSearchText('');
    if (scrollRef.current && zoom < 3) {
      try {
        scrollRef.current.scrollTo({
          x: n.cx * 3 - SCREEN_W / 2,
          y: n.cy * 3 - (SCREEN_H - 200) / 2,
          animated: true,
        });
      } catch (e) { /* 忽略 */ }
    }
  };

  const fly = n => {
    if (!n) return;
    Alert.alert(
      '飞行确认',
      `飞到「${n.name}」？将按距离收取银两费用。`,
      [
        { text: '取消', style: 'cancel' },
        {
          text: '飞行',
          onPress: () => { command(`fly_to_room ${n.id}`); onClose(); },
        },
      ],
    );
  };

  /* 区域房间菜单：限30行+搜索提示，避免长列表显得乱。 */
  const regionRooms = useMemo(() => {
    if (!graph || !regionOpen) return [];
    return graph.nodes
      .filter(n => n.region === regionOpen)
      .sort((a, b) => (b.level || 0) - (a.level || 0))
      .slice(0, 30);
  }, [graph, regionOpen]);

  if (!visible) return null;

  const content = graph ? (
    <ScrollView
      ref={scrollRef}
      style={{ flex: 1, backgroundColor: '#0d0b0e' }}
      contentContainerStyle={{
        width: graph.contentW, height: graph.contentH,
      }}
      minimumZoomScale={minZoom}
      maximumZoomScale={12}
      showsHorizontalScrollIndicator={false}
      showsVerticalScrollIndicator={false}
      onScroll={e => {
        const z = e.nativeEvent.zoomScale || minZoom;
        const bucket = Math.round(z * 4) / 4;
        const ox = Math.round((e.nativeEvent.contentOffset
          ? e.nativeEvent.contentOffset.x : 0) / 40) * 40;
        const oy = Math.round((e.nativeEvent.contentOffset
          ? e.nativeEvent.contentOffset.y : 0) / 40) * 40;
        setZoom(prev => (prev === bucket ? prev : bucket));
        setViewport(prev => (prev.x === ox && prev.y === oy && prev.z === bucket
          ? prev : { x: ox, y: oy, z: bucket }));
      }}
      scrollEventThrottle={120}
    >
      <Svg width={graph.contentW} height={graph.contentH}>
        <G>
          {lod.regionMode && graph.regionList.map(r => (
            <G key={'rg-' + r.id}
              onPress={() => { setSelected(null); setRegionOpen(r.id); }}>
              <Circle
                cx={r.x} cy={r.y}
                r={Math.max(20, Math.sqrt(r.count) * 14)}
                fill="#2d3a5a" stroke="#5a7aba" strokeWidth={2}
                opacity={0.85}
              />
              <SvgText
                x={r.x}
                y={r.y - Math.max(20, Math.sqrt(r.count) * 14) - 6}
                fontSize={30} fill="#9ab8d8" textAnchor="middle">
                {r.name}
              </SvgText>
            </G>
          ))}
          {lod.showEdges && visibleEdges.map((e, i) => {
            const a = graph.nodeIndex.get(e.from);
            const b = graph.nodeIndex.get(e.to);
            if (!a || !b) return null;
            return (
              <Line key={'e' + i}
                x1={a.cx} y1={a.cy} x2={b.cx} y2={b.cy}
                stroke="#3a3a52" strokeWidth={1} opacity={0.6}
              />
            );
          })}
          {visibleNodes.map(n => {
            const isCur = currentNode && currentNode.id === n.id;
            const isSel = selected && selected.id === n.id;
            return (
              <G key={n.id} onPress={() => {
                setRegionOpen(null);
                setSelected(n);
              }}>
                <Circle
                  cx={n.cx} cy={n.cy}
                  r={isCur ? nodeR * 1.6 : isSel ? nodeR * 1.4 : nodeR}
                  fill={isCur ? '#ffd700' : biomeColor(n.biome)}
                  stroke={isSel ? '#ff4d6d' : isCur ? '#fff0b0' : 'none'}
                  strokeWidth={2}
                />
                {lod.showLabels && (isCur || zoom >= 5) && (
                  <SvgText
                    x={n.cx} y={n.cy - nodeR - 4}
                    fontSize={11 / Math.max(zoom, 0.2)}
                    textAnchor="middle"
                    fill={isCur ? '#ffd700' : '#a89aa8'}>
                    {n.name}
                  </SvgText>
                )}
              </G>
            );
          })}
        </G>
      </Svg>
    </ScrollView>
  ) : null;

  return (
    <Modal visible animationType="slide" transparent={false}>
      <View style={styles.screen}>
        {/* 顶栏：关闭 + 搜索 */}
        <View style={styles.topBar}>
          <TouchableOpacity style={styles.closeBtn} onPress={onClose}>
            <Text style={styles.closeText}>✕</Text>
          </TouchableOpacity>
          <TextInput
            style={styles.searchInput}
            value={searchText}
            onChangeText={setSearchText}
            placeholder="搜索房间名…"
            placeholderTextColor="#6a5a6a"
            autoCapitalize="none"
            autoCorrect={false}
          />
          {currentNode && (
            <View style={styles.hereChip}>
              <Text style={styles.hereText} numberOfLines={1}>
                📍{currentNode.name}
              </Text>
            </View>
          )}
        </View>

        {/* 地图主体：原生捏合缩放 + 拖动 */}
        <View style={styles.mapArea}>
          {!graph ? (
            <View style={styles.centerBox}>
              {loadError ? (
                <>
                  <Text style={styles.errText}>{loadError}</Text>
                  <TouchableOpacity onPress={() => { setLoadError(''); setGraph(null); }}>
                    <Text style={styles.retryText}>重试</Text>
                  </TouchableOpacity>
                </>
              ) : (
                <>
                  <ActivityIndicator color="#d4af37" />
                  <Text style={styles.loadingText}>正在加载世界地图…</Text>
                </>
              )}
            </View>
          ) : content}
        </View>

        {/* 区域房间菜单：点区域圆弹出，行内直接飞行 */}
        {graph && regionOpen && (
          <View style={styles.resultPanel}>
            <View style={styles.regionHeader}>
              <Text style={styles.regionTitle}>🗺 {regionOpen}</Text>
              <TouchableOpacity onPress={() => setRegionOpen(null)}
                style={styles.regionClose}>
                <Text style={styles.selCloseText}>✕</Text>
              </TouchableOpacity>
            </View>
            <Text style={styles.regionHint}>
              按等级显示前30个房间；找具体房间请用顶部搜索
            </Text>
            <View style={{ maxHeight: 260 }}>
              {regionRooms.map(n => (
                <TouchableOpacity key={n.id} style={styles.resultRow}
                  onPress={() => fly(n)}>
                  <Text style={styles.resultName} numberOfLines={1}>{n.name}</Text>
                  <Text style={styles.flyRowHint}>
                    {n.level ? 'Lv.' + n.level : ''} › 飞行
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
          </View>
        )}

        {/* 搜索结果浮层 */}
        {graph && searchText.trim() !== '' && (
          <View style={styles.resultPanel}>
            {searchResults.length === 0 ? (
              <Text style={styles.resultEmpty}>没有匹配的房间</Text>
            ) : searchResults.map(n => (
              <TouchableOpacity key={n.id} style={styles.resultRow}
                onPress={() => focusNode(n)}>
                <Text style={styles.resultName} numberOfLines={1}>{n.name}</Text>
                <Text style={styles.resultMeta}>
                  {n.level ? 'Lv.' + n.level : ''} · {n.region}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        )}

        {/* 选中房间操作条 */}
        {graph && selected && (
          <View style={styles.selectBar}>
            <View style={{ flex: 1 }}>
              <Text style={styles.selectName} numberOfLines={1}>
                {selected.name}
              </Text>
              <Text style={styles.selectMeta}>
                {selected.level ? 'Lv.' + selected.level + ' · ' : ''}
                {selected.region}
                {currentNode && currentNode.id === selected.id ? ' · 当前位置' : ''}
              </Text>
            </View>
            <TouchableOpacity style={styles.flyBtn}
              onPress={() => fly(selected)}>
              <Text style={styles.flyText}>🕊 飞行</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.selClose}
              onPress={() => setSelected(null)}>
              <Text style={styles.selCloseText}>✕</Text>
            </TouchableOpacity>
          </View>
        )}
      </View>
    </Modal>
  );
}

function findCurrentNode(graph, lines) {
  if (!graph) return null;
  for (let i = (lines || []).length - 1;
       i >= 0 && i >= (lines || []).length - 120; i--) {
    const line = (lines || [])[i];
    const text = typeof line === 'string' ? line.trim()
      : (line && line.text ? String(line.text).trim() : '');
    if (text && graph.nameIndex.has(text)) return graph.nameIndex.get(text);
  }
  return null;
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#0d0b0e' },
  topBar: {
    flexDirection: 'row', alignItems: 'center', gap: 8,
    paddingTop: 52, paddingHorizontal: 12, paddingBottom: 8,
    backgroundColor: '#14101a', borderBottomWidth: 1, borderBottomColor: '#2e2430',
  },
  closeBtn: {
    width: 34, height: 34, borderRadius: 17, backgroundColor: '#3d1018',
    borderWidth: 1, borderColor: '#ff4d6d', alignItems: 'center',
    justifyContent: 'center',
  },
  closeText: { color: '#ff9aa8', fontSize: 15, fontWeight: '700' },
  searchInput: {
    flex: 1, backgroundColor: '#1c1620', borderRadius: 10,
    paddingHorizontal: 12, minHeight: 36, color: '#f0e6d2', fontSize: 14,
    borderWidth: 1, borderColor: '#2e2430',
  },
  hereChip: {
    maxWidth: 120, backgroundColor: '#231b10', borderRadius: 999,
    borderWidth: 1, borderColor: '#8a6d2f', paddingHorizontal: 8,
    paddingVertical: 4,
  },
  hereText: { color: '#ffd700', fontSize: 11 },
  mapArea: { flex: 1 },
  centerBox: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 10 },
  loadingText: { color: '#a89aa8', fontSize: 13 },
  errText: { color: '#ff9aa8', fontSize: 13, textAlign: 'center', paddingHorizontal: 30 },
  retryText: { color: '#9ab8d8', fontSize: 13, marginTop: 8 },
  resultPanel: {
    position: 'absolute', top: 98, left: 12, right: 12,
    backgroundColor: '#14101aee', borderRadius: 12,
    borderWidth: 1, borderColor: '#3a2f46', maxHeight: 320,
    paddingHorizontal: 6, paddingVertical: 4, zIndex: 20,
  },
  resultRow: {
    paddingVertical: 8, paddingHorizontal: 8,
    borderBottomWidth: 1, borderBottomColor: '#241c2c',
    flexDirection: 'row', justifyContent: 'space-between', gap: 8,
  },
  resultName: { color: '#f0e6d2', fontSize: 13, flexShrink: 1 },
  resultMeta: { color: '#6a5a6a', fontSize: 11 },
  resultEmpty: { color: '#6a5a6a', fontSize: 12, padding: 10, textAlign: 'center' },
  regionHeader: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: 8, paddingVertical: 6,
    borderBottomWidth: 1, borderBottomColor: '#3a2f46',
  },
  regionTitle: { color: '#ffd700', fontSize: 13, fontWeight: '700' },
  regionClose: { padding: 4 },
  regionHint: { color: '#6a5a6a', fontSize: 10, paddingHorizontal: 10,
    paddingVertical: 4 },
  flyRowHint: { color: '#9ab8d8', fontSize: 11 },
  selectBar: {
    flexDirection: 'row', alignItems: 'center', gap: 10,
    backgroundColor: '#14101a', borderTopWidth: 1, borderTopColor: '#8a6d2f',
    paddingHorizontal: 14, paddingVertical: 10,
  },
  selectName: { color: '#f0e6d2', fontSize: 14, fontWeight: '700' },
  selectMeta: { color: '#6a5a6a', fontSize: 11, marginTop: 1 },
  flyBtn: {
    backgroundColor: '#2d2410', borderRadius: 999, borderWidth: 1,
    borderColor: '#d4af37', paddingHorizontal: 14, minHeight: 34,
    alignItems: 'center', justifyContent: 'center',
  },
  flyText: { color: '#ffd700', fontSize: 13, fontWeight: '700' },
  selClose: { padding: 6 },
  selCloseText: { color: '#6a5a6a', fontSize: 14 },
});
