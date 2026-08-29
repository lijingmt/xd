import React, { useEffect, useRef, useState } from 'react';
import {
  View, Text, FlatList, TouchableOpacity, Modal,
  Image, ScrollView, StyleSheet, KeyboardAvoidingView, Platform,
  ActivityIndicator, AppState, RefreshControl, Pressable, Animated,
} from 'react-native';
import {
  lineKey,
} from '../utils/segments.js';
import { parseBattleLines, extractSkillName } from '../utils/battleFeedback.js';
import {
  createStatsTracker, applyEvents, formatStats,
} from '../utils/battleStats.js';
import { parseSkillType } from '../utils/skillTypes.js';
import { getImageBase } from '../api/mudApi.js';
import { useGameStore, setRuntimePlatform } from '../store/useGameStore.js';
import { PROFESSION_OPTIONS } from '../data/characterOptions.js';
import {
  loadUiSettings, saveUiSettings, FONT_SCALE_OPTIONS, fontScaleFor,
  DEFAULT_UI_SETTINGS,
} from '../utils/uiSettings.js';
import { sessionSummary } from '../utils/parallelAfk.js';
import BattleScene from './BattleScene.js';
import { SmartImage } from './GameSmartImage.js';
import EquipmentPanel from './EquipmentPanel.js';
import SkillEffectOverlay from './SkillEffectOverlay.js';
import RechargeModal from './RechargeModal.js';
import { LineItem } from './LineItem.js';

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
  { icon: '⚙', label: '装备', cmd: '__equip_panel' },
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

/* 数值缩写（与网页版 compact 数值一致）。 */
function fmt(value) {
  const n = Number(value) || 0;
  const abs = Math.abs(n);
  if (abs >= 1e8) {
    return `${(n / 1e8).toFixed(1).replace(/\.0$/, '')}亿`;
  }
  if (abs >= 1e4) {
    return `${(n / 1e4).toFixed(1).replace(/\.0$/, '')}万`;
  }
  return String(Math.round(n));
}

/* 挂机呼吸点：挂机中的角色tab上绿色小圆点脉冲，一眼可见谁在自动挂机。 */
function AfkPulseDot({ active }) {
  const scale = useRef(new Animated.Value(1)).current;
  useEffect(() => {
    if (!active) return;
    const loop = Animated.loop(Animated.sequence([
      Animated.timing(scale, {
        toValue: 1.55, duration: 550, useNativeDriver: true,
      }),
      Animated.timing(scale, {
        toValue: 1, duration: 550, useNativeDriver: true,
      }),
    ]));
    loop.start();
    return () => loop.stop();
  }, [active, scale]);
  if (!active) return null;
  return (
    <Animated.View style={{
      width: 7, height: 7, borderRadius: 4,
      backgroundColor: '#7ad08a',
      shadowColor: '#7ad08a', shadowOpacity: 0.9,
      shadowRadius: 4, shadowOffset: { width: 0, height: 0 },
      transform: [{ scale }],
    }} />
  );
}

/* ☰ 菜单行（复刻网页版 menu-item）。 */
function MenuRow({ icon, label, onPress, danger }) {
  return (
    <TouchableOpacity style={styles.menuRow} onPress={onPress}
      activeOpacity={0.6}>
      <Text style={styles.menuRowIcon}>{icon}</Text>
      <Text style={[styles.menuRowLabel, !!danger && styles.menuRowDanger]}>
        {label}
      </Text>
    </TouchableOpacity>
  );
}

export default function GameScreen() {
  const store = useGameStore();
  const listRef = useRef(null);
  const [inputValues, setInputValues] = useState({});
  const [moreOpen, setMoreOpen] = useState(false);
  const [equipOpen, setEquipOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [rechargeOpen, setRechargeOpen] = useState(false);
  const [uiSettings, setUiSettings] = useState(DEFAULT_UI_SETTINGS);
  const [activeTab, setActiveTab] = useState('');
  const [floaters, setFloaters] = useState([]);
  const [skillEffects, setSkillEffects] = useState([]);
  const [statsSummary, setStatsSummary] = useState(null);
  const statsRef = useRef(createStatsTracker());
  const lastPollRef = useRef(0);
  const lastStatusRef = useRef(0);
  /* 用户主动导航后的阅读保护期：期间不拉挂机画面，防止子菜单被
   * 服务端autofight视图盖掉（挂机在服务端继续跑，不受影响）。 */
  const lastUserNavRef = useRef(0);
  const inBattleRef = useRef(false);
  const afkRef = useRef(false);
  inBattleRef.current = store.inBattle;
  afkRef.current = store.autofighting;

  /* 界面偏好（字号/特效）启动时恢复。 */
  useEffect(() => {
    let cancelled = false;
    loadUiSettings().then(saved => {
      if (!cancelled) setUiSettings(saved);
    });
    return () => { cancelled = true; };
  }, []);

  const updateUiSettings = patch => {
    setUiSettings(prev => {
      const next = { ...prev, ...patch };
      saveUiSettings(next);
      return next;
    });
  };

  /* txpike9 同款轮询策略：战斗中1s一帧、挂机中3s一帧；
   * 空闲浏览菜单时不做画面轮询（flushview会把当前页刷回房间视图，
   * 造成“点宠物/共享宠物被重置回地图”），只慢速拉状态数值。
   * AppState 回前台立即补一帧（iOS 切换后不卡死）。
   * 后台并行角色的快照轮询也在同一心跳里驱动（内部自带间隔/并发约束）。 */
  useEffect(() => {
    const platform = Platform.OS === 'web' ? 'ios' : Platform.OS;
    setRuntimePlatform(platform);
    const timer = setInterval(() => {
      const now = Date.now();
      useGameStore.getState().tickBackgroundPolls();
      const fighting = inBattleRef.current;
      const state = useGameStore.getState();
      const afk = !!state.autofighting;
      const reading = now - lastUserNavRef.current < 15000;
      if ((fighting || afk) && !reading) {
        const delay = fighting ? 1000 : 3000;
        if (now - lastPollRef.current < delay) return;
        lastPollRef.current = now;
        state.pollGameView(platform);
        return;
      }
      /* 空闲/阅读保护期：只刷新状态数值（不触碰画面行）。 */
      if (now - lastStatusRef.current < 5000) return;
      lastStatusRef.current = now;
      state.refreshStatus();
    }, 1000);
    const appStateSub = AppState.addEventListener('change', nextState => {
      if (nextState === 'active') {
        lastPollRef.current = 0;
        lastStatusRef.current = 0;
        const state = useGameStore.getState();
        if (inBattleRef.current || afkRef.current) {
          state.pollGameView(platform);
        } else {
          state.refreshStatus();
        }
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
      const scrollTimer = setTimeout(() => {
        if (listRef.current) {
          listRef.current.scrollToEnd({ animated: false });
        }
      }, 50);
      return () => clearTimeout(scrollTimer);
    }
  }, [store.lines.length]);

  /* 解析新行中的战斗事件，生成浮动数字/状态标记。 */
  const prevLineCountRef = useRef(0);
  const effectsRef = useRef(true);
  effectsRef.current = uiSettings.combatEffects;
  useEffect(() => {
    if (store.lines.length === prevLineCountRef.current) return;
    const newLines = store.lines.slice(Math.min(
      prevLineCountRef.current, store.lines.length));
    prevLineCountRef.current = store.lines.length;
    const events = parseBattleLines(newLines);
    if (!events.length) return;
    /* 累积战斗统计 */
    applyEvents(statsRef.current, events);
    const summary = formatStats(statsRef.current);
    if (summary) setStatsSummary(summary);
    if (!effectsRef.current) return;
    const batch = events.slice(0, 6).map((event, index) => ({
      ...event,
      id: `float-${Date.now()}-${index}`,
    }));
    setFloaters(prev => [...prev, ...batch].slice(-8));
    const timers = [setTimeout(() => {
      setFloaters(prev => prev.filter(f =>
        !batch.some(b => b.id === f.id)));
    }, eventDuration(batch[0]))];

    /* 技能施法动画：从新行提取技能名→类型→视觉特效 */
    for (const line of newLines.slice(0, 5)) {
      const text = ((line && line.segments) || [])
        .map(s => s.type === 'text'
          ? ((s.parts) || []).map(p => p.content || '').join('')
          : '').join('');
      const name = extractSkillName(text);
      if (name) {
        const type = parseSkillType(text) || parseSkillType(name) || 'generic';
        const skillEffect = {
          id: `skill-${Date.now()}-${Math.random()}`,
          name, type,
        };
        setSkillEffects(prev => [...prev, skillEffect].slice(-3));
        timers.push(setTimeout(() => {
          setSkillEffects(prev =>
            prev.filter(e => e.id !== skillEffect.id));
        }, 2000));
        break; /* 每帧最多一个技能特效 */
      }
    }
    /* 卸载时清理所有定时器，防止setState on unmounted */
    return () => timers.forEach(clearTimeout);
  }, [store.lines.length]);

  function eventDuration(event) {
    if (!event) return 900;
    if (event.kind === 'victory') return 1800;
    if (event.critical) return 1400;
    return 900;
  }

  const send = cmd => {
    if (!cmd) return;
    setMoreOpen(false);
    lastUserNavRef.current = Date.now();
    store.command(cmd.trim());
  };

  const sendTab = tab => {
    if (tab.cmd === '__equip_panel') {
      setEquipOpen(true);
      return;
    }
    setActiveTab(tab.cmd);
    lastPollRef.current = 0;
    send(tab.cmd);
  };

  const status = store.status || {};
  const imageBase = getImageBase(store.apiBase);
  const avatarUrl = status.avatar
    ? `${imageBase}${status.avatar}` : '';
  const enemy = (store.battle && store.battle.enemy) || null;
  const enemyPercent = enemy ? percent(enemy.hp, enemy.hp_max) : 0;
  const expPercent = percent(status.exp, status.exp_need);

  /* 并行角色条目：活动角色取顶层实时状态，其余取后台快照。 */
  /* 顶部tab条目：已开会话(实时快照) + 账号下未开角色(点击即多开)。 */
  const openSessionIds = Object.keys(store.sessions || {})
    .filter(id => store.sessions[id] && store.sessions[id].txd);
  const entryIds = [...openSessionIds];
  for (const card of store.accountCharacters || []) {
    const id = String(card.id);
    if (!entryIds.includes(id) && card.available !== false) {
      entryIds.push(id);
    }
  }
  const sessionEntries = entryIds
    .map(id => {
      const card = (store.accountCharacters || [])
        .find(c => String(c.id) === id);
      const isActive = id === store.currentCharacterId;
      const hasSession = openSessionIds.includes(id);
      const summary = sessionSummary(isActive
        ? {
          txd: store.txd, status: store.status,
          inBattle: store.inBattle, autofighting: store.autofighting,
        }
        : (store.sessions || {})[id], card);
      return {
        id, active: isActive, hasSession, summary,
        name: card ? card.name : id,
      };
    })
    .sort((a, b) => (a.active ? -1 : b.active ? 1 : 0));

  return (
    <KeyboardAvoidingView
      style={styles.screen}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={0}>

      {/* ===== 并行角色tab条：屏幕最顶部，账号有多角色即常驻 ===== */}
      {((sessionEntries.length > 1) ||
        ((store.accountCharacters || []).length > 1)) && (
        <View style={styles.tabStrip}>
          <ScrollView horizontal showsHorizontalScrollIndicator={false}
            contentContainerStyle={{ gap: 8, paddingHorizontal: 12,
              paddingVertical: 8 }}>
            {sessionEntries.map(entry => (
              <Pressable
                key={entry.id}
                style={[styles.charChip,
                  entry.active && styles.charChipActive,
                  !entry.active && !entry.hasSession &&
                    styles.charChipClosed]}
                onPress={() => {
                  if (entry.active) return;
                  if (entry.hasSession) store.switchCharacter(entry.id);
                  else store.pickCharacter(entry.id);
                }}>
                <AfkPulseDot active={entry.summary.autofighting} />
                <Text style={[styles.charChipName,
                  entry.active && styles.charChipNameActive]}
                  numberOfLines={1}>
                  {entry.summary.inBattle ? '⚔ ' : ''}
                  {entry.hasSession ? '' : '＋'}
                  {entry.name}
                </Text>
                <Text style={[styles.charChipMeta,
                  entry.active && styles.charChipNameActive]}>
                  {entry.hasSession
                    ? `Lv.${entry.summary.level}` +
                      (entry.summary.hpPercent != null
                        ? ` · ${entry.summary.hpPercent}%` : '')
                    : '多开'}
                </Text>
              </Pressable>
            ))}
            <Pressable style={styles.charChipAdd}
              onPress={() => store.backToDashboard()}>
              <Text style={styles.charChipAddText}>＋</Text>
            </Pressable>
          </ScrollView>
        </View>
      )}

      {/* ===== 顶栏：复刻 Vue game-header ===== */}
      <View style={styles.header}>
        <View style={styles.infoRow}>
          {avatarUrl ? (
            <SmartImage uri={avatarUrl} style={styles.headerAvatar} />
          ) : (
            <View style={styles.headerAvatarPlaceholder}>
              <Text style={styles.headerAvatarText}>
                {(status.name_cn || '仙')[0]}
              </Text>
            </View>
          )}
          {!!status.pet_assist && typeof status.pet_assist === 'object' && (
            <View style={styles.headerPetBadge}>
              <Text style={styles.headerPetIcon}>
                {status.pet_assist.icon || '🐾'}
              </Text>
            </View>
          )}
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
            {typeof status.account_suiyu === 'number' && (
              <View style={styles.suiyuChip}>
                <Text style={styles.suiyuText} numberOfLines={1}>
                  💎{fmt(status.account_suiyu)}
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
            style={styles.menuButton} onPress={() => setMenuOpen(true)}>
            <Text style={styles.menuIcon}>☰</Text>
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

        {/* 生效中的丹药/特药 buff 药丸（与 Vue active-buff-chip 同源） */}
        {Array.isArray(status.active_buffs) &&
            status.active_buffs.length > 0 && (
          <View style={styles.buffRow}>
            {status.active_buffs.map(buff => (
              <View key={buff.kind || buff.name_cn}
                style={styles.buffChip}>
                <Text style={styles.buffChipText}>
                  🔆{buff.name_cn}
                  <Text style={styles.buffChipTime}>
                    ({buff.remain_min}m)
                  </Text>
                </Text>
              </View>
            ))}
          </View>
        )}

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

      {/* ===== 离线横幅：连续轮询失败时显示 ===== */}
      {!store.networkOnline && (
        <View style={styles.offlineBanner}>
          <Text style={styles.offlineText}>⚠ 网络连接中断，正在重试…</Text>
        </View>
      )}

      {/* ===== 战斗场景：左右对峙（Vue battle-mini 复刻） ===== */}
      {!!store.inBattle && !!enemy && (
        <BattleScene
          player={status}
          enemy={enemy}
          pet={status.pet_assist || null}
          imageBase={imageBase}
        />
      )}

      {/* ===== 战斗统计条（战斗中常驻显示） ===== */}
      {!!statsSummary && (
        <View style={styles.statsBar}>
          <Text style={styles.statsItem}>
            输出 <Text style={styles.statsValue}>{fmt(statsSummary.dealt)}</Text>
          </Text>
          <Text style={styles.statsItem}>
            DPS <Text style={[styles.statsValue, styles.statsDps]}>
              {fmt(statsSummary.dps)}
            </Text>
          </Text>
          <Text style={styles.statsItem}>
            承受 <Text style={[statsSummary.taken > statsSummary.dealt
              ? styles.statsWarn : styles.statsValue]}>
              {fmt(statsSummary.taken)}
            </Text>
          </Text>
          {statsSummary.crits > 0 && (
            <Text style={styles.statsItem}>
              暴击 <Text style={styles.statsCrit}>{statsSummary.crits}</Text>
            </Text>
          )}
          {statsSummary.kills > 0 && (
            <Text style={styles.statsItem}>
              击杀 <Text style={styles.statsKill}>{statsSummary.kills}</Text>
            </Text>
          )}
        </View>
      )}

      {/* ===== 浮动战斗数字层 ===== */}
      {floaters.length > 0 && (
        <View style={styles.floaterLayer} pointerEvents="none">
          {floaters.map((floater, index) => (
            <Floater key={floater.id} event={floater} offset={index} />
          ))}
        </View>
      )}

      {/* ===== 技能施法动画层 ===== */}
      <SkillEffectOverlay effects={skillEffects} />

      {/* 加载条：任何命令执行期间显示在画面顶部 */}
      {!!store.busy && (
        <View style={styles.loadingBar}>
          <ActivityIndicator size="small" color="#d4af37" />
          <Text style={styles.loadingText}>执行中…</Text>
        </View>
      )}

      {!!store.error && <Text style={styles.error}>{store.error}</Text>}

      {/* 空态：命令清空画面后加载中给一个居中提示 */}
      {store.busy && store.lines.length === 0 && (
        <View style={styles.emptyLoadingWrap}>
          <ActivityIndicator size="large" color="#d4af37" />
          <Text style={styles.emptyLoadingText}>载入中…</Text>
        </View>
      )}

      <FlatList
        ref={listRef}
        style={styles.feed}
        data={store.lines}
        keyExtractor={lineKey}
        onScroll={handleScroll}
        scrollEventThrottle={100}
        windowSize={8}
        maxToRenderPerBatch={12}
        initialNumToRender={20}
        updateCellsBatchingPeriod={50}
        removeClippedSubviews={true}
        refreshControl={
          <RefreshControl
            refreshing={store.busy}
            onRefresh={() => {
              lastPollRef.current = 0;
              useGameStore.getState().pollGameView(
                Platform.OS === 'web' ? 'ios' : Platform.OS);
            }}
            tintColor="#d4af37"
            titleColor="#a89aa8"
          />
        }
        ListEmptyComponent={
          !store.busy && store.lines.length === 0
            ? <Text style={styles.emptyText}>暂无内容</Text>
            : null
        }
        renderItem={({ item }) => (
          <LineItem
            line={item}
            ctx={{
              send, inputValues, setInputValues, imageBase,
              busy: store.busy,
              fontScale: fontScaleFor(uiSettings.fontSize),
            }}
          />
        )}
      />

      {/* ===== 底部五Tab：复刻 Vue quick-nav =====
       * 自由命令输入栏已移除：原生端全部走按钮/页面内cmd-input表单，
       * 裸文本命令在MUD里不成立（聊天走服务端下发的输入框）。 */}
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

      {/* ===== 装备面板 ===== */}
      <EquipmentPanel
        visible={equipOpen}
        onClose={() => setEquipOpen(false)}
      />

      {/* ===== 内购充值弹窗（iOS） ===== */}
      <RechargeModal
        visible={rechargeOpen}
        onClose={() => setRechargeOpen(false)}
      />

      {/* ===== 右上角菜单：复刻网页版 ☰ 下拉 ===== */}
      <Modal visible={menuOpen} transparent animationType="fade"
        onRequestClose={() => setMenuOpen(false)}>
        <Pressable style={styles.menuOverlay}
          onPress={() => setMenuOpen(false)}>
          <View style={styles.menuPanel}
            onStartShouldSetResponder={() => true}>
            <Text style={styles.menuHeader}>
              并行挂机 {Object.keys(store.sessions || {}).length}/
              {store.parallelLimit}
            </Text>
            <MenuRow icon={uiSettings.combatEffects ? '✨' : '○'}
              label={`视觉特效：${uiSettings.combatEffects ? '开启' : '关闭'}`}
              onPress={() => updateUiSettings({
                combatEffects: !uiSettings.combatEffects,
              })} />
            <View style={styles.menuDivider} />
            <Text style={styles.menuSectionLabel}>游戏字号</Text>
            <View style={styles.menuFontRow}>
              {FONT_SCALE_OPTIONS.map(option => (
                <Pressable key={option.id}
                  style={[styles.fontOption,
                    uiSettings.fontSize === option.id &&
                      styles.fontOptionActive]}
                  onPress={() => updateUiSettings({ fontSize: option.id })}>
                  <Text style={[styles.fontOptionText,
                    uiSettings.fontSize === option.id &&
                      styles.fontOptionTextActive]}>
                    {option.label}
                  </Text>
                </Pressable>
              ))}
            </View>
            <View style={styles.menuDivider} />
            <MenuRow icon="🔃" label="刷新画面"
              onPress={() => {
                lastPollRef.current = 0;
                useGameStore.getState().pollGameView(
                  Platform.OS === 'web' ? 'ios' : Platform.OS);
                setMenuOpen(false);
              }} />
            {!!status.profession_assistant &&
                typeof status.profession_assistant === 'object' &&
                !!status.profession_assistant.supported && (
              <MenuRow icon="🧭"
                label={`${status.profession_assistant.title || '职业'} · 职业助手`}
                onPress={() => {
                  setMenuOpen(false);
                  send('profession_assistant');
                }} />
            )}
            <MenuRow icon="🤝" label="邀请好友 / 查看奖励"
              onPress={() => {
                setMenuOpen(false);
                send('invite');
              }} />
            {Platform.OS === 'ios' && (
              <MenuRow icon="💎" label="碎玉充值（内购）"
                onPress={() => {
                  setMenuOpen(false);
                  setRechargeOpen(true);
                }} />
            )}
            <View style={styles.menuDivider} />
            <MenuRow icon="👥" label="多开角色 / 切换职业"
              onPress={() => {
                setMenuOpen(false);
                store.backToDashboard();
              }} />
            <MenuRow icon="🚪" label="退出登录" danger
              onPress={() => {
                setMenuOpen(false);
                store.logout();
              }} />
          </View>
        </Pressable>
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

function Floater({ event, offset }) {
  const top = 120 + offset * 34;
  let text = '';
  let color = '#F0E6D2';
  let fontSize = 18;
  switch (event.kind) {
    case 'damage':
      if (event.target === 'enemy') {
        color = event.critical ? '#FFD700' : '#FF6B8A';
        fontSize = event.critical ? 26 : 20;
        text = `-${formatNumber(event.value)}${event.critical ? '!' : ''}`;
      } else {
        color = '#ff4444';
        text = `-${formatNumber(event.value)}`;
      }
      break;
    case 'heal':
      color = '#7ad08a';
      text = `+${formatNumber(event.value)}`;
      break;
    case 'dodge':
      color = '#87CEEB';
      text = 'MISS';
      fontSize = 16;
      break;
    case 'block':
      color = '#FFD700';
      text = 'BLOCK';
      fontSize = 16;
      break;
    case 'poison':
      color = '#90EE90';
      text = 'POISON';
      fontSize = 14;
      break;
    case 'victory':
      color = '#FFD700';
      text = '✦ VICTORY';
      fontSize = 28;
      break;
    case 'skill':
      color = '#DDA0DD';
      text = `◈ ${event.name}`;
      fontSize = 14;
      break;
    default:
      return null;
  }
  return (
    <Text style={[
      styles.floater,
      { top, color, fontSize },
      event.critical && styles.floaterCritical,
      event.kind === 'victory' && styles.floaterVictory,
    ]}>
      {text}
    </Text>
  );
}

function formatNumber(value) {
  const num = Number(value) || 0;
  if (num >= 100000000) return `${(num / 100000000).toFixed(1)}亿`;
  if (num >= 10000) return `${(num / 10000).toFixed(1)}万`;
  return String(num);
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#0d0b0e' },
  header: {
    backgroundColor: '#14101a', paddingHorizontal: 12, paddingTop: 10,
    paddingBottom: 8, gap: 6,
    borderBottomWidth: 1, borderBottomColor: '#2e2430',
  },
  infoRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  headerAvatar: {
    width: 36, height: 36, borderRadius: 8,
    borderWidth: 1, borderColor: '#8a6d2f',
  },
  headerAvatarPlaceholder: {
    width: 36, height: 36, borderRadius: 8,
    backgroundColor: '#2d2410', borderWidth: 1, borderColor: '#8a6d2f',
    alignItems: 'center', justifyContent: 'center',
  },
  headerAvatarText: { color: '#ffd700', fontSize: 16, fontWeight: '700' },
  headerPetBadge: {
    width: 24, height: 24, borderRadius: 12,
    backgroundColor: '#1a2418', borderWidth: 1, borderColor: '#3f8a53',
    alignItems: 'center', justifyContent: 'center',
  },
  headerPetIcon: { fontSize: 13 },
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
  suiyuChip: {
    backgroundColor: '#10201a', borderWidth: 1, borderColor: '#3a7a5a',
    borderRadius: 5, paddingHorizontal: 6, paddingVertical: 1,
  },
  suiyuText: { color: '#7ad0a0', fontSize: 11, fontWeight: '700' },
  afkButton: {
    paddingHorizontal: 11, minHeight: 30, borderRadius: 999,
    borderWidth: 1, borderColor: '#6a8a5a',
    alignItems: 'center', justifyContent: 'center',
  },
  afkButtonOn: { backgroundColor: '#2d5243', borderColor: '#7ad08a' },
  afkText: { color: '#c8e8c8', fontSize: 12 },
  menuButton: {
    width: 34, minHeight: 30, borderRadius: 999,
    borderWidth: 1, borderColor: '#6a5a7a', backgroundColor: '#1a141c',
    alignItems: 'center', justifyContent: 'center',
  },
  menuIcon: { color: '#f0e6d2', fontSize: 15, lineHeight: 18 },
  tabStrip: {
    borderBottomWidth: 1, borderBottomColor: '#2e2430',
    backgroundColor: '#12101a',
  },
  charChip: {
    flexDirection: 'row', alignItems: 'center', gap: 6,
    paddingHorizontal: 11, paddingVertical: 6, borderRadius: 999,
    borderWidth: 1, borderColor: '#3a2f46', backgroundColor: '#17131c',
  },
  charChipActive: {
    borderColor: '#d4af37', backgroundColor: '#2d2410',
  },
  charChipClosed: { opacity: 0.55 },
  charChipName: { color: '#c8b8c8', fontSize: 12, fontWeight: '600' },
  charChipNameActive: { color: '#ffd700' },
  charChipMeta: { color: '#8a7a8a', fontSize: 11 },
  charChipAdd: {
    width: 34, alignItems: 'center', justifyContent: 'center',
    borderRadius: 999, borderWidth: 1, borderColor: '#6a8a5a',
    backgroundColor: '#16241c',
  },
  charChipAddText: { color: '#9ad0a0', fontSize: 15 },
  menuOverlay: {
    flex: 1, backgroundColor: 'rgba(5,3,8,0.55)',
    alignItems: 'flex-end',
  },
  menuPanel: {
    marginTop: 64, marginRight: 12, width: 268, borderRadius: 14,
    backgroundColor: '#17131c', borderWidth: 1, borderColor: '#3a2f46',
    paddingVertical: 8, paddingHorizontal: 6,
    shadowColor: '#000', shadowOpacity: 0.5, shadowRadius: 16,
    elevation: 10,
  },
  menuHeader: {
    color: '#d4af37', fontSize: 12, textAlign: 'center',
    paddingVertical: 8, letterSpacing: 1,
  },
  menuDivider: {
    height: 1, backgroundColor: '#2e2430', marginVertical: 6,
    marginHorizontal: 6,
  },
  menuSectionLabel: {
    color: '#8a7a8a', fontSize: 11, paddingHorizontal: 12, marginBottom: 6,
  },
  menuFontRow: {
    flexDirection: 'row', gap: 6, paddingHorizontal: 10,
    marginBottom: 6,
  },
  fontOption: {
    flex: 1, alignItems: 'center', paddingVertical: 7, borderRadius: 8,
    borderWidth: 1, borderColor: '#3a2f46', backgroundColor: '#12101a',
  },
  fontOptionActive: { borderColor: '#d4af37', backgroundColor: '#2d2410' },
  fontOptionText: { color: '#a89aa8', fontSize: 12 },
  fontOptionTextActive: { color: '#ffd700' },
  menuRow: {
    flexDirection: 'row', alignItems: 'center', gap: 10,
    paddingHorizontal: 12, paddingVertical: 10, borderRadius: 9,
  },
  menuRowIcon: { fontSize: 15, width: 22, textAlign: 'center' },
  menuRowLabel: { color: '#f0e6d2', fontSize: 14, flex: 1 },
  menuRowDanger: { color: '#ff9aa8' },
  statRows: { gap: 4 },
  buffRow: {
    flexDirection: 'row', flexWrap: 'wrap', gap: 4, marginTop: 2,
  },
  buffChip: {
    backgroundColor: '#1a2418', borderWidth: 1, borderColor: '#3f8a53',
    borderRadius: 5, paddingHorizontal: 6, paddingVertical: 2,
  },
  buffChipText: { color: '#7ad08a', fontSize: 10 },
  buffChipTime: { color: '#5a8a6a', fontSize: 9 },
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
  imageFallback: {
    backgroundColor: '#1a141c', borderWidth: 1, borderColor: '#3a2f46',
    alignItems: 'center', justifyContent: 'center',
  },
  imageFallbackText: { fontSize: 24, color: '#6a5a6a' },
  statsBar: {
    flexDirection: 'row', flexWrap: 'wrap', alignItems: 'center',
    justifyContent: 'center', gap: 12, paddingVertical: 5,
    paddingHorizontal: 10, backgroundColor: '#14101a',
    borderBottomWidth: 1, borderBottomColor: '#2e2430',
  },
  statsItem: { color: '#8a7a8a', fontSize: 11 },
  statsValue: { color: '#f0e6d2', fontSize: 11, fontWeight: '700' },
  statsDps: { color: '#d4af37' },
  statsCrit: { color: '#FFD700', fontSize: 11, fontWeight: '700' },
  statsKill: { color: '#7ad08a', fontSize: 11, fontWeight: '700' },
  statsWarn: { color: '#ff6b6a', fontSize: 11, fontWeight: '700' },
  offlineBanner: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
    paddingVertical: 6, backgroundColor: '#3d1018',
    borderBottomWidth: 1, borderBottomColor: '#ff4d6d',
  },
  offlineText: { color: '#ff9aa8', fontSize: 12, letterSpacing: 1 },
  loadingBar: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
    gap: 8, paddingVertical: 6,
    backgroundColor: '#1a141c', borderBottomWidth: 1,
    borderBottomColor: '#8a6d2f',
  },
  loadingText: { color: '#d4af37', fontSize: 12, letterSpacing: 2 },
  emptyLoadingWrap: {
    position: 'absolute', top: '40%', left: 0, right: 0,
    alignItems: 'center', gap: 10,
  },
  emptyLoadingText: { color: '#8a7a8a', fontSize: 14 },
  emptyText: {
    color: '#6a5a6a', textAlign: 'center', paddingTop: 60, fontSize: 14,
  },
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
  floaterLayer: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 100,
    alignItems: 'center',
  },
  floater: {
    position: 'absolute',
    fontWeight: '700',
    textShadowColor: '#000',
    textShadowOffset: { width: 1, height: 1 },
    textShadowRadius: 4,
    letterSpacing: 1,
  },
  floaterCritical: {
    textShadowColor: '#FFD700',
    textShadowRadius: 12,
  },
  floaterVictory: {
    textShadowColor: '#FFD700',
    textShadowRadius: 20,
    letterSpacing: 6,
  },
});
