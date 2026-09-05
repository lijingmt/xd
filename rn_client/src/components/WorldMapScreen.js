import React, { useState, useRef, useCallback, useMemo, useEffect } from 'react';
import {
  View, Text, Modal, TouchableOpacity, StyleSheet,
  TextInput, Dimensions, Alert, ActivityIndicator, PanResponder,
} from 'react-native';
import Svg, { Circle, Line, Text as SvgText, G } from 'react-native-svg';
import { useGameStore } from '../store/useGameStore.js';
import { getApiBase } from '../api/mudApi.js';

const { width: SCREEN_W, height: SCREEN_H } = Dimensions.get('window');

/**
 * 世界地图（RN 客户端版，与 Vue 网页版同源数据）：
 * - 数据：GET {apiBase}/data/world-map.json（2681 房间 / 76 区域完整拓扑）
 * - 渲染：react-native-svg，单指拖动 + 双指捏合 + +/- 缩放
 * - LOD：缩小只画区域标记；中等画房间点；放大画连线与房间名
 * - 搜索全部房间；点击房间 → fly_to_room 飞行（与 Vue 相同命令）
 */

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
  const [k, setK] = useState(0);
  const [tx, setTx] = useState(0);
  const [ty, setTy] = useState(0);
  const baseRef = useRef({ baseK: 1, k: 0, tx: 0, ty: 0 });
  const gestureRef = useRef(null);

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
        const regions = new Map();
        for (const n of data.nodes) {
          if (!regions.has(n.region)) {
            regions.set(n.region, {
              id: n.region, name: n.region, count: 0,
              sx: 0, sy: 0, level: n.level || 0,
            });
          }
          const r = regions.get(n.region);
          r.count += 1; r.sx += n.x; r.sy += n.y;
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

  /* 初始视野：整图居中适配。 */
  const fitAll = useCallback(() => {
    if (!graph) return;
    const b = graph.worldBounds;
    const w = (b.maxX - b.minX) || 1;
    const h = (b.maxY - b.minY) || 1;
    const kk = Math.min(SCREEN_W / w, (SCREEN_H - 160) / h) * 0.92;
    const cx = (b.maxX + b.minX) / 2;
    const cy = (b.maxY + b.minY) / 2;
    setK(kk);
    setTx(SCREEN_W / 2 - cx * kk);
    setTy((SCREEN_H - 120) / 2 - cy * kk + 20);
  }, [graph]);

  useEffect(() => {
    if (visible && graph && !k) fitAll();
  }, [visible, graph, k, fitAll]);

  const baseK = useMemo(() => {
    if (!graph) return 1;
    const b = graph.worldBounds;
    return Math.min(SCREEN_W / ((b.maxX - b.minX) || 1),
      (SCREEN_H - 160) / ((b.maxY - b.minY) || 1)) * 0.92;
  }, [graph]);

  /* ---------- 手势：拖动 + 捏合（经 ref 读写最新视图状态） ---------- */
  const viewRef = useRef({ k: 0, tx: 0, ty: 0, baseK: 1, visible: [] });

  const dist = touches => {
    const dx = touches[0].pageX - touches[1].pageX;
    const dy = touches[0].pageY - touches[1].pageY;
    return Math.sqrt(dx * dx + dy * dy);
  };

  const handleGesture = e => {
    const g = gestureRef.current;
    if (!g) return;
    const st = viewRef.current;
    if (e.nativeEvent.numberofTouches >= 2) {
      const d = dist(e.nativeEvent.touches);
      if (g.pinchD0 > 4) {
        const nk = Math.max(st.baseK * 0.7,
          Math.min(st.baseK * 40, g.k0 * d / g.pinchD0));
        const wx = (g.pivotX - g.tx0) / g.k0;
        const wy = (g.pivotY - g.ty0) / g.k0;
        setK(nk);
        setTx(g.pivotX - wx * nk);
        setTy(g.pivotY - wy * nk);
      }
    } else {
      setTx(g.tx0 + e.nativeEvent.pageX - g.x0);
      setTy(g.ty0 + e.nativeEvent.pageY - g.y0);
    }
  };

  const panRef = useRef(null);
  if (!panRef.current) {
    panRef.current = PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder: () => true,
      onPanResponderGrant: e => {
        const nt = e.nativeEvent.numberofTouches;
        const st = viewRef.current || { k: 1, tx: 0, ty: 0 };
        gestureRef.current = {
          x0: e.nativeEvent.pageX, y0: e.nativeEvent.pageY,
          k0: st.k, tx0: st.tx, ty0: st.ty,
          moved: false,
          pinchD0: nt >= 2 && e.nativeEvent.touches
            ? dist(e.nativeEvent.touches) : 0,
          pivotX: SCREEN_W / 2, pivotY: SCREEN_H / 2,
        };
      },
      onPanResponderMove: e => {
        const g = gestureRef.current;
        if (g) {
          if (Math.abs(e.nativeEvent.pageX - g.x0) > 8 ||
              Math.abs(e.nativeEvent.pageY - g.y0) > 8) g.moved = true;
        }
        handleGesture(e);
      },
      onPanResponderRelease: e => {
        const g = gestureRef.current;
        gestureRef.current = null;
        if (!g || g.moved) return;
        /* 视作点按：命中最近的可见节点（屏幕距离 26px 内）。 */
        const st = viewRef.current || { k: 1, tx: 0, ty: 0 };
        const nodes = st.visible || [];
        const px = e.nativeEvent.pageX, py = e.nativeEvent.pageY;
        let best = null, bestD = 26 * 26;
        for (const n of nodes) {
          const sx = n.x * st.k + st.tx, sy = n.y * st.k + st.ty;
          const d = (sx - px) * (sx - px) + (sy - py) * (sy - py);
          if (d < bestD) { bestD = d; best = n; }
        }
        if (best) setSelected(best);
      },
    });
  }

  /* ---------- LOD 与视口裁剪 ---------- */
  const lod = useMemo(() => ({
    showNodes: k >= baseK * 1.6,
    showEdges: k >= baseK * 3,
    showLabels: k >= baseK * 6,
    showRegions: k < baseK * 2.4,
  }), [k, baseK]);

  const visibleNodes = useMemo(() => {
    if (!graph || !lod.showNodes) return [];
    const m = 60;
    const out = [];
    for (const n of graph.nodes) {
      const sx = n.x * k + tx, sy = n.y * k + ty;
      if (sx > -m && sx < SCREEN_W + m && sy > 60 && sy < SCREEN_H - 60) {
        out.push(n);
        if (out.length >= 900) break;
      }
    }
    return out;
  }, [graph, k, tx, ty, lod.showNodes]);

  /* 渲染期同步最新视图/裁剪结果给一次性创建的手势回调。 */
  viewRef.current = { k, tx, ty, baseK, visible: visibleNodes };

  const visibleEdges = useMemo(() => {
    if (!graph || !lod.showEdges) return [];
    const nodeSet = new Set(visibleNodes.map(n => n.id));
    const out = [];
    const m = 40;
    for (const e of graph.edges) {
      const a = graph.nodeIndex.get(e.from);
      const b = graph.nodeIndex.get(e.to);
      if (!a || !b) continue;
      if (nodeSet.has(a.id) && nodeSet.has(b.id)) {
        const ax = a.x * k + tx, ay = a.y * k + ty;
        const bx = b.x * k + tx, by = b.y * k + ty;
        if (Math.min(ax, bx) < SCREEN_W + m && Math.max(ax, bx) > -m &&
            Math.min(ay, by) < SCREEN_H + m && Math.max(ay, by) > 20 - m) {
          out.push([ax, ay, bx, by]);
          if (out.length >= 700) break;
        }
      }
    }
    return out;
  }, [graph, visibleNodes, k, tx, ty, lod.showEdges]);

  /* 当前房间：从最近的行里精确匹配房间名。 */
  const currentNode = useMemo(() => {
    if (!graph) return null;
    for (let i = (lines || []).length - 1; i >= 0 && i >= (lines || []).length - 120; i--) {
      const line = (lines || [])[i];
      const text = typeof line === 'string' ? line.trim()
        : (line && line.text ? String(line.text).trim() : '');
      if (text && graph.nameIndex.has(text)) return graph.nameIndex.get(text);
    }
    return null;
  }, [graph, lines]);

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
    setTx(SCREEN_W / 2 - n.x * k);
    setTy((SCREEN_H - 140) / 2 - n.y * k);
    setSelected(n);
    setSearchText('');
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

  const zoomBy = f => {
    const nk = Math.max(baseK * 0.7, Math.min(baseK * 40, k * f));
    const px = SCREEN_W / 2, py = SCREEN_H / 2;
    const wx = (px - tx) / k, wy = (py - ty) / k;
    setK(nk); setTx(px - wx * nk); setTy(py - wy * nk);
  };

  if (!visible) return null;

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

        {/* 搜索结果浮层 */}
        {searchText.trim() !== '' && (
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

        {/* 地图主体 */}
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
          ) : (
            <View style={{ flex: 1 }} {...panRef.current.panHandlers}>
              <Svg width={SCREEN_W} height={SCREEN_H} style={styles.svg}>
                <G>
                  {lod.showRegions && graph.regionList.map(r => (
                    <G key={'rg-' + r.id}>
                      <Circle
                        cx={r.x * k + tx} cy={r.y * k + ty}
                        r={Math.max(3, Math.sqrt(r.count) * 1.2)}
                        fill="#2d3a5a" stroke="#5a7aba" strokeWidth={1}
                        opacity={0.85}
                      />
                      <SvgText
                        x={r.x * k + tx}
                        y={r.y * k + ty - Math.max(3, Math.sqrt(r.count) * 1.2) - 3}
                        fontSize={10} fill="#9ab8d8" textAnchor="middle">
                        {r.name}
                      </SvgText>
                    </G>
                  ))}
                  {visibleEdges.map((e, i) => (
                    <Line key={'e' + i}
                      x1={e[0]} y1={e[1]} x2={e[2]} y2={e[3]}
                      stroke="#3a3a52" strokeWidth={1} opacity={0.7}
                    />
                  ))}
                  {visibleNodes.map(n => {
                    const isCur = currentNode && currentNode.id === n.id;
                    const isSel = selected && selected.id === n.id;
                    return (
                      <G key={n.id}>
                        <Circle
                          cx={n.x * k + tx} cy={n.y * k + ty}
                          r={isCur ? 6 : isSel ? 5.5 : 3.5}
                          fill={isCur ? '#ffd700' : biomeColor(n.biome)}
                          stroke={isSel ? '#ff4d6d' : isCur ? '#fff0b0' : 'none'}
                          strokeWidth={1.5}
                        />
                        {lod.showLabels && (isCur || visibleNodes.length <= 80) && (
                          <SvgText
                            x={n.x * k + tx} y={n.y * k + ty - 8}
                            fontSize={9} textAnchor="middle"
                            fill={isCur ? '#ffd700' : '#a89aa8'}>
                            {n.name}
                          </SvgText>
                        )}
                      </G>
                    );
                  })}
                </G>
              </Svg>
            </View>
          )}

          {/* 缩放控件 */}
          {graph && (
            <View style={styles.zoomControls}>
              <TouchableOpacity style={styles.zoomBtn} onPress={() => zoomBy(1.7)}>
                <Text style={styles.zoomText}>＋</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.zoomBtn} onPress={() => zoomBy(1 / 1.7)}>
                <Text style={styles.zoomText}>－</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.zoomBtn} onPress={fitAll}>
                <Text style={styles.zoomText}>⌂</Text>
              </TouchableOpacity>
            </View>
          )}
        </View>

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
  resultPanel: {
    position: 'absolute', top: 98, left: 12, right: 12,
    backgroundColor: '#14101aee', borderRadius: 12,
    borderWidth: 1, borderColor: '#3a2f46', maxHeight: 300,
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
  mapArea: { flex: 1 },
  svg: { backgroundColor: '#0d0b0e' },
  centerBox: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 10 },
  loadingText: { color: '#a89aa8', fontSize: 13 },
  errText: { color: '#ff9aa8', fontSize: 13, textAlign: 'center', paddingHorizontal: 30 },
  retryText: { color: '#9ab8d8', fontSize: 13, marginTop: 8 },
  zoomControls: {
    position: 'absolute', right: 12, bottom: 24, gap: 8,
  },
  zoomBtn: {
    width: 40, height: 40, borderRadius: 20, backgroundColor: '#14101aee',
    borderWidth: 1, borderColor: '#8a6d2f', alignItems: 'center',
    justifyContent: 'center',
  },
  zoomText: { color: '#ffd700', fontSize: 17, fontWeight: '700' },
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
