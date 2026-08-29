import React, { useEffect, useRef, useState } from 'react';
import {
  View, Text, FlatList, TextInput, TouchableOpacity, Modal,
  Image, StyleSheet, KeyboardAvoidingView, Platform,
  ActivityIndicator, AppState,
} from 'react-native';
import { useGameStore } from '../store/useGameStore.js';
import {
  flattenTextParts, buttonStyleFor, resolveImageUrl, buildInputCommand,
  lineKey,
} from '../utils/segments.js';
import { PROFESSION_OPTIONS } from '../data/characterOptions.js';

/* 与 Vue quick-actions 同一份功能表（命令直发）。 */
const QUICK_TOOLS = [
  { icon: '📅', label: '每日修行', cmd: 'daily' },
  { icon: '🗺️', label: '地图', cmd: 'map_display' },
  { icon: '📜', label: '任务', cmd: 'mytasks' },
  { icon: '🌙', label: '幻境任务', cmd: 'illusion_realm' },
  { icon: '🔥', label: '挑战难度', cmd: 'personal_difficulty' },
  { icon: '👥', label: '队伍', cmd: 'my_term' },
  { icon: '🐾', label: '共享宠物', cmd: 'pet' },
  { icon: '🧰', label: '仓库', cmd: 'go_warehouse' },
  { icon: '💎', label: '玉石', cmd: 'yushi_change' },
  { icon: '🏰', label: '帮派', cmd: 'my_bang' },
  { icon: '🌊', label: '江湖', cmd: 'my_games' },
  { icon: '🌀', label: '传送', cmd: 'userlist' },
  { icon: '⚙️', label: '设置', cmd: 'game_detail' },
  { icon: '👑', label: '会员', cmd: 'vip_service_list' },
];

const MAIN_TABS = [
  { icon: '⌂', label: '场景', cmd: 'look' },
  { icon: '♡', label: '状态', cmd: 'myhp' },
  { icon: '▣', label: '物品', cmd: 'inventory' },
  { icon: '◇', label: '技能', cmd: 'myskills' },
];

const PLATFORM_TAG = Platform.OS === 'web' ? 'ios' : Platform.OS;

function professionName(professionId) {
  const hit = PROFESSION_OPTIONS.find(option =>
    option.profession_id === professionId);
  return hit ? hit.name : (professionId || '');
}

function percent(value, max) {
  return Math.max(0, Math.min(100,
    ((Number(value) || 0) / Math.max(1, Number(max) || 1)) * 100));
}

export default function GameScreen() {
  const store = useGameStore();
  const listRef = useRef(null);
  const [draft, setDraft] = useState('');
  const [inputValues, setInputValues] = useState({});
  const [moreOpen, setMoreOpen] = useState(false);
  const [activeTab, setActiveTab] = useState('');
  const lastPollRef = useRef(0);
  const inBattleRef = useRef(false);
  inBattleRef.current = store.inBattle;

  /* txpike9 同款轮询策略：1s 心跳节流——战斗中1s一帧，平时3s一帧；
   * AppState 回前台立即补一帧（iOS 切换后不卡死）。 */
  useEffect(() => {
    const platform = Platform.OS === 'web' ? 'ios' : Platform.OS;
    const timer = setInterval(() => {
      const now = Date.now();
      const delay = inBattleRef.current ? 1000 : 3000;
      if (now - lastPollRef.current < delay) return;
      lastPollRef.current = now;
      useGameStore.getState().pollGameView(platform);
    }, 1000);
    const appStateSub = AppState.addEventListener('change', nextState => {
      if (nextState === 'active') {
        lastPollRef.current = 0;
        useGameStore.getState().pollGameView(platform);
      }
    });
    return () => {
      clearInterval(timer);
      appStateSub.remove();
    };
  }, []);

  /* 智能滚动：只在用户已在底部附近时才跟随新行（阅读历史不被打断）。 */
  const nearBottomRef = useRef(true);
  const handleScroll = event => {
    const { contentOffset, contentSize, layoutMeasurement } =
      event.nativeEvent;
    const distanceFromEnd =
      contentSize.height - layoutMeasurement.height - contentOffset.y;
    nearBottomRef.current = distanceFromEnd < 80;
  };

  useEffect(() => {
    if (listRef.current && nearBottomRef.current) {
      setTimeout(() => listRef.current.scrollToEnd({ animated: false }), 50);
    }
  }, [store.lines.length]);

  const send = cmd => {
    if (!cmd) return;
    setDraft('');
    setMoreOpen(false);
    store.command(cmd.trim());
  };

  const sendTab = tab => {
    setActiveTab(tab.cmd);
    lastPollRef.current = 0;
    send(tab.cmd);
  };

  const status = store.status || {};
  const enemy = (store.battle && store.battle.enemy) || null;
  const enemyPercent = enemy ? percent(enemy.hp, enemy.hp_max) : 0;
  const expPercent = percent(status.exp, status.exp_need);

  return (
    <KeyboardAvoidingView
      style={styles.screen}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={0}>
      {/* ===== 顶栏：复刻 Vue game-header ===== */}
      <View style={styles.header}>
        <View style={styles.infoRow}>
          <View style={{ flex: 1, flexDirection: 'row', alignItems: 'center', gap: 6 }}>
            <Text style={styles.nameCn} numberOfLines={1}>
              {status.name_cn || store.userid || '仙道'}
            </Text>
            <View style={styles.levelChip}>
              <Text style={styles.levelChipText}>Lv.{status.level || '?'}</Text>
            </View>
            {!!status.profession_id && (
              <View style={styles.profChip}>
                <Text style={styles.profChipText}>
                  {professionName(status.profession_id)}
                </Text>
              </View>
            )}
          </View>
          <TouchableOpacity
            style={[styles.afkButton,
              store.autofighting && styles.afkButtonOn]}
            disabled={store.afkBusy}
            onPress={() => store.toggleAutofight()}>
            {store.afkBusy
              ? <ActivityIndicator size="small" color="#c8e8c8" />
              : <Text style={styles.afkText}>
                  {store.autofighting ? '◎ 挂机中' : '▶ 挂机'}
                </Text>}
          </TouchableOpacity>
          <TouchableOpacity
            style={styles.logoutButton} onPress={() => store.logout()}>
            <Text style={styles.logoutText}>退出</Text>
          </TouchableOpacity>
        </View>

        {/* 三条属性条：生命/法力/精力 */}
        <View style={styles.statRows}>
          <StatBar label="生命" value={status.hp} max={status.hp_max}
            fill="#c23a4a" />
          <StatBar label="法力" value={status.mana} max={status.mana_max}
            fill="#3a6ac2" />
          <StatBar label="精力" value={status.energy} max={100}
            fill="#3f8a53" />
        </View>

        {/* 经验条：Lv.N === Lv.N+1 / 已封顶 */}
        <View style={styles.expRow}>
          <Text style={styles.expLevel}>Lv.{status.level || '?'}</Text>
          <View style={styles.expTrack}>
            <View style={[styles.expFill, { width: `${expPercent}%` }]} />
          </View>
          <Text style={styles.expLevel}>
            {status.level_can_progress === false || !status.level_can_progress && status.exp_need
              ? '已封顶' : `Lv.${(status.level || 0) + 1}`}
          </Text>
        </View>
      </View>

      {/* ===== 战斗卡片 ===== */}
      {store.inBattle && enemy && (
        <View style={styles.battleCard}>
          <View style={styles.battleBadgeRow}>
            <Text style={styles.battleBadge}>⚔ 战斗中</Text>
            {store.autofighting && (
              <Text style={styles.battleAutoTag}>挂机自动战斗</Text>
            )}
          </View>
          <View style={styles.enemyRow}>
            <Text style={styles.enemyName} numberOfLines={1}>
              {enemy.name_cn || '敌人'}
            </Text>
            <Text style={styles.enemyHp}>
              {enemy.hp}/{enemy.hp_max} · {Math.round(enemyPercent)}%
            </Text>
          </View>
          <View style={styles.enemyTrack}>
            <View style={[styles.enemyFill, { width: `${enemyPercent}%` }]} />
          </View>
        </View>
      )}

      {!!store.error && <Text style={styles.error}>{store.error}</Text>}

      <FlatList
        ref={listRef}
        style={styles.feed}
        data={store.lines}
        keyExtractor={lineKey}
        onScroll={handleScroll}
        scrollEventThrottle={100}
        renderItem={({ item }) => (
          <View style={styles.line}>
            {renderSegments(item, {
              send, inputValues, setInputValues, apiBase: store.apiBase,
            })}
          </View>
        )}
      />

      <View style={styles.commandBar}>
        <TextInput
          style={styles.commandInput}
          value={draft}
          onChangeText={setDraft}
          onSubmitEditing={() => send(draft)}
          returnKeyType="send"
          placeholder="输入命令或对话…"
          placeholderTextColor="#6a5a6a"
        />
        <TouchableOpacity style={styles.sendButton} onPress={() => send(draft)}>
          <Text style={styles.sendText}>发送</Text>
        </TouchableOpacity>
      </View>

      {/* ===== 底部五Tab：复刻 Vue quick-nav ===== */}
      <View style={styles.tabBar}>
        {MAIN_TABS.map(tab => (
          <TouchableOpacity key={tab.cmd} style={styles.tabButton}
            onPress={() => sendTab(tab)}>
            <Text style={[styles.tabIcon,
              activeTab === tab.cmd && styles.tabIconActive]}>
              {tab.icon}
            </Text>
            <Text style={[styles.tabLabel,
              activeTab === tab.cmd && styles.tabLabelActive]}>
              {tab.label}
            </Text>
          </TouchableOpacity>
        ))}
        <TouchableOpacity style={styles.tabButton}
          onPress={() => setMoreOpen(true)}>
          <Text style={[styles.tabIcon,
            moreOpen && styles.tabIconActive]}>•••</Text>
          <Text style={[styles.tabLabel,
            moreOpen && styles.tabLabelActive]}>更多</Text>
        </TouchableOpacity>
      </View>

      {/* ===== 更多功能面板 ===== */}
      <Modal visible={moreOpen} animationType="slide"
        onRequestClose={() => setMoreOpen(false)}>
        <View style={styles.moreScreen}>
          <View style={styles.moreHeader}>
            <View>
              <Text style={styles.moreEyebrow}>常用功能</Text>
              <Text style={styles.moreTitle}>探索与成长</Text>
            </View>
            <TouchableOpacity onPress={() => setMoreOpen(false)}>
              <Text style={styles.moreClose}>✕ 收起</Text>
            </TouchableOpacity>
          </View>
          <FlatList
            style={{ flex: 1 }}
            contentContainerStyle={{ padding: 16, gap: 10 }}
            data={QUICK_TOOLS}
            keyExtractor={item => item.cmd}
            numColumns={3}
            renderItem={({ item }) => (
              <TouchableOpacity style={styles.toolBtn} onPress={() => send(item.cmd)}>
                <Text style={styles.toolIcon}>{item.icon}</Text>
                <Text style={styles.toolLabel}>{item.label}</Text>
              </TouchableOpacity>
            )}
          />
        </View>
      </Modal>
    </KeyboardAvoidingView>
  );
}

function StatBar({ label, value, max, fill }) {
  return (
    <View style={styles.statRow}>
      <Text style={styles.statLabel}>{label}</Text>
      <View style={styles.statTrack}>
        <View style={[styles.statFill, { width: `${percent(value, max)}%`, backgroundColor: fill }]} />
      </View>
      <Text style={styles.statValue}>{formatNumber(value)}/{formatNumber(max)}</Text>
    </View>
  );
}

function formatNumber(value) {
  const num = Number(value) || 0;
  if (num >= 100000000) return `${(num / 100000000).toFixed(1)}亿`;
  if (num >= 10000) return `${(num / 10000).toFixed(1)}万`;
  return String(num);
}

function renderSegments(line, ctx) {
  const segments = (line && line.segments) || [];
  return segments.map((segment, index) => {
    if (!segment || !segment.type) return null;
    if (segment.type === 'text') {
      const units = flattenTextParts(segment.parts);
      return (
        <Text key={index} style={styles.text}>
          {units.map((unit, unitIndex) => (
            <Text
              key={unitIndex}
              style={{ color: unit.color, fontWeight: unit.bold ? '700' : '400' }}>
              {unit.text}
            </Text>
          ))}
        </Text>
      );
    }
    if (segment.type === 'button') {
      const style = buttonStyleFor(segment);
      return (
        <TouchableOpacity
          key={index}
          style={[styles.button, {
            backgroundColor: style.bg, borderColor: style.border,
          }]}
          onPress={() => ctx.send(segment.cmd)}>
          <Text style={[styles.buttonText, { color: style.color }]}>
            {segment.label}
          </Text>
        </TouchableOpacity>
      );
    }
    if (segment.type === 'cmd-input' || segment.type === 'input') {
      const key = `input-${index}`;
      const value = ctx.inputValues[key] ??
        String(segment.default || '');
      return (
        <TextInput
          key={index}
          style={styles.inlineInput}
          value={value}
          onChangeText={text =>
            ctx.setInputValues({ ...ctx.inputValues, [key]: text })}
          onSubmitEditing={() => {
            const cmd = buildInputCommand(segment, value);
            if (cmd) ctx.send(cmd);
          }}
          placeholder={segment.name || '输入'}
          placeholderTextColor="#6a5a6a"
          returnKeyType="send"
        />
      );
    }
    if (segment.type === 'image') {
      const uri = resolveImageUrl(ctx.apiBase, segment.src);
      if (!uri) return null;
      return (
        <Image key={index} source={{ uri }}
          style={styles.image} resizeMode="contain" />
      );
    }
    return null;
  });
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#0d0b0e' },
  header: {
    backgroundColor: '#14101a', paddingHorizontal: 12, paddingTop: 10,
    paddingBottom: 8, gap: 6,
    borderBottomWidth: 1, borderBottomColor: '#2e2430',
  },
  infoRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  nameCn: { color: '#f0e6d2', fontSize: 16, fontWeight: '700', flexShrink: 1 },
  levelChip: {
    backgroundColor: '#2d2410', borderWidth: 1, borderColor: '#8a6d2f',
    borderRadius: 5, paddingHorizontal: 6, paddingVertical: 1,
  },
  levelChipText: { color: '#ffd700', fontSize: 11, fontWeight: '700' },
  profChip: {
    backgroundColor: '#1a2430', borderWidth: 1, borderColor: '#3a5a8a',
    borderRadius: 5, paddingHorizontal: 6, paddingVertical: 1,
  },
  profChipText: { color: '#9ab8d8', fontSize: 11 },
  afkButton: {
    paddingHorizontal: 11, minHeight: 30, borderRadius: 999,
    borderWidth: 1, borderColor: '#6a8a5a',
    alignItems: 'center', justifyContent: 'center',
  },
  afkButtonOn: { backgroundColor: '#2d5243', borderColor: '#7ad08a' },
  afkText: { color: '#c8e8c8', fontSize: 12 },
  logoutButton: {
    paddingHorizontal: 10, minHeight: 30, borderRadius: 999,
    borderWidth: 1, borderColor: '#5a3a46',
    alignItems: 'center', justifyContent: 'center',
  },
  logoutText: { color: '#c8a8b8', fontSize: 12 },
  statRows: { gap: 4 },
  statRow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  statLabel: { color: '#a89aa8', fontSize: 11, width: 26 },
  statTrack: {
    flex: 1, height: 8, borderRadius: 4,
    backgroundColor: '#241a28', overflow: 'hidden',
  },
  statFill: { height: 8, borderRadius: 4 },
  statValue: { color: '#8a9aa8', fontSize: 10, minWidth: 72, textAlign: 'right' },
  expRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  expLevel: { color: '#ffd700', fontSize: 11, fontWeight: '700' },
  expTrack: {
    flex: 1, height: 6, borderRadius: 3,
    backgroundColor: '#241a28', overflow: 'hidden',
  },
  expFill: { height: 6, borderRadius: 3, backgroundColor: '#d4af37' },
  battleCard: {
    marginHorizontal: 10, marginTop: 8, borderRadius: 12,
    borderWidth: 1, borderColor: '#8a3548', backgroundColor: '#1c1016',
    padding: 10, gap: 6,
    shadowColor: '#c23a4a', shadowOpacity: 0.3,
    shadowRadius: 8, elevation: 4,
  },
  battleBadgeRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  battleBadge: { color: '#ff9aa8', fontSize: 12, fontWeight: '700', letterSpacing: 2 },
  battleAutoTag: {
    color: '#9ad0a0', fontSize: 10,
    borderWidth: 1, borderColor: '#3f6a4a', borderRadius: 5,
    paddingHorizontal: 6, paddingVertical: 1, overflow: 'hidden',
  },
  enemyRow: {
    flexDirection: 'row', alignItems: 'center',
    justifyContent: 'space-between', gap: 10,
  },
  enemyName: { flexShrink: 1, color: '#ffb3c0', fontSize: 15, fontWeight: '700' },
  enemyHp: { color: '#c8a8b8', fontSize: 12 },
  enemyTrack: {
    height: 12, borderRadius: 6, backgroundColor: '#2a1a20', overflow: 'hidden',
  },
  enemyFill: { height: 12, borderRadius: 6, backgroundColor: '#c23a4a' },
  error: { color: '#ff6b8a', fontSize: 12, paddingHorizontal: 12, paddingTop: 6 },
  feed: { flex: 1, paddingHorizontal: 10 },
  line: {
    paddingVertical: 4, flexDirection: 'row', flexWrap: 'wrap',
    alignItems: 'center', gap: 5,
  },
  text: { color: '#f0e6d2', fontSize: 15, lineHeight: 22, flexShrink: 1 },
  button: {
    paddingHorizontal: 11, minHeight: 32, borderRadius: 9,
    borderWidth: 1, marginVertical: 3,
    alignItems: 'center', justifyContent: 'center',
  },
  buttonText: { fontSize: 14 },
  inlineInput: {
    backgroundColor: '#1a141c', borderRadius: 8, paddingHorizontal: 10,
    paddingVertical: 6, color: '#f0e6d2', fontSize: 14,
    borderWidth: 1, borderColor: '#3a2f46', minWidth: 130, minHeight: 34,
  },
  image: { width: 76, height: 76, borderRadius: 10, marginVertical: 4 },
  commandBar: {
    flexDirection: 'row', gap: 8, padding: 8,
    borderTopWidth: 1, borderTopColor: '#2e2430', backgroundColor: '#14101a',
  },
  commandInput: {
    flex: 1, backgroundColor: '#1a141c', borderRadius: 11,
    paddingHorizontal: 13, paddingVertical: 9, minHeight: 42,
    color: '#f0e6d2', fontSize: 15,
    borderWidth: 1, borderColor: '#2e2430',
  },
  sendButton: {
    paddingHorizontal: 20, borderRadius: 11, backgroundColor: '#3a2f46',
    alignItems: 'center', justifyContent: 'center',
  },
  sendText: { color: '#f0e6d2', fontSize: 15, fontWeight: '600' },
  tabBar: {
    flexDirection: 'row', backgroundColor: '#14101a',
    borderTopWidth: 1, borderTopColor: '#2e2430', paddingBottom: 2,
  },
  tabButton: {
    flex: 1, alignItems: 'center', paddingVertical: 6, gap: 1,
  },
  tabIcon: { color: '#8a7a8a', fontSize: 18 },
  tabIconActive: { color: '#ffd700' },
  tabLabel: { color: '#8a7a8a', fontSize: 11 },
  tabLabelActive: { color: '#ffd700', fontWeight: '600' },
  moreScreen: {
    flex: 1, backgroundColor: '#0d0b0e', paddingTop: 54,
  },
  moreHeader: {
    flexDirection: 'row', justifyContent: 'space-between',
    alignItems: 'center', paddingHorizontal: 18, paddingBottom: 12,
    borderBottomWidth: 1, borderBottomColor: '#2e2430',
  },
  moreEyebrow: { color: '#8a7a8a', fontSize: 11 },
  moreTitle: { color: '#f0e6d2', fontSize: 18, fontWeight: '700' },
  moreClose: { color: '#a89aa8', fontSize: 14 },
  toolBtn: {
    flex: 1 / 3, backgroundColor: '#1a141c', borderRadius: 12,
    borderWidth: 1, borderColor: '#3a2f46', paddingVertical: 14,
    alignItems: 'center', gap: 6, margin: 4,
  },
  toolIcon: { fontSize: 26 },
  toolLabel: { color: '#c8b8c8', fontSize: 13 },
});
