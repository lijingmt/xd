import React, { useEffect, useRef, useState } from 'react';
import { useWindowDimensions } from 'react-native';
import {
  View, Text, FlatList, TouchableOpacity, Modal,
  Image, ScrollView, StyleSheet, KeyboardAvoidingView, Platform,
  ActivityIndicator, AppState, RefreshControl, Pressable, Animated,
  TextInput, Alert,
} from 'react-native';
import {
  lineKey,
} from '../utils/segments.js';
import { parseBattleLines, extractSkillName, skillAnimationTarget } from '../utils/battleFeedback.js';
import {
  createStatsTracker, applyEvents, formatStats,
} from '../utils/battleStats.js';
import { parseSkillType, skillMeta } from '../utils/skillTypes.js';
import { groupDigits, suiyuTime, clearSuiyuLog } from '../utils/suiyuLog.js';
import { useTheme } from '../utils/ThemeContext.js';
import { Vibration } from 'react-native';
import { toast } from './Toast.js';
import { APP_THEMES } from '../utils/appThemes.js';
import WorldMapScreen from './WorldMapScreen.js';
import { getImageBase } from '../api/mudApi.js';
import { useGameStore, setRuntimePlatform } from '../store/useGameStore.js';
import { PROFESSION_OPTIONS } from '../data/characterOptions.js';
import {
  loadUiSettings, saveUiSettings, FONT_SCALE_OPTIONS, fontScaleFor,
  DEFAULT_UI_SETTINGS,
} from '../utils/uiSettings.js';
import { sessionSummary } from '../utils/parallelAfk.js';
import * as accountApi from '../api/accountApi.js';
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
  { icon: '♻️', label: '挂机设置', cmd: 'autofight' },
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

/* 头像脉冲：轻微缩放循环暗示可点击（点头像→换装面板）。 */
function AvatarPressable({ onPress, children }) {
  const scale = useRef(new Animated.Value(1)).current;
  useEffect(() => {
    const anim = Animated.loop(Animated.sequence([
      Animated.timing(scale, {
        toValue: 1.07, duration: 520, useNativeDriver: true,
      }),
      Animated.timing(scale, {
        toValue: 1, duration: 520, useNativeDriver: true,
      }),
      Animated.delay(1900),
    ]));
    anim.start();
    return () => anim.stop();
  }, [scale]);
  return (
    <Animated.View style={{
      transform: [{ scale }],
      shadowColor: '#d4af37', shadowOpacity: 0.5,
      shadowRadius: 10, elevation: 6,
    }}>
      <TouchableOpacity activeOpacity={0.7} onPress={onPress}>
        {children}
      </TouchableOpacity>
    </Animated.View>
  );
}

/* 扣玉/入账浮动提示：−150 上浮消散 + 算式 1,500 − 150 = 1,350。 */
function SuiyuDeltaFx({ fx }) {
  const rise = useRef(new Animated.Value(0)).current;
  const opacity = useRef(new Animated.Value(0)).current;
  const gain = fx.delta > 0;
  const color = gain ? '#5ad47a' : '#ff5a6a';
  useEffect(() => {
    Animated.parallel([
      Animated.sequence([
        Animated.timing(opacity, {
          toValue: 1, duration: 120, useNativeDriver: true,
        }),
        Animated.timing(opacity, {
          toValue: 0, duration: 1600, useNativeDriver: true,
        }),
      ]),
      Animated.timing(rise, {
        toValue: gain ? -18 : -34, duration: 1600,
        useNativeDriver: true,
      }),
    ]).start();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return (
    <View style={styles.suiyuFxBox} pointerEvents="none">
      <Animated.Text style={[styles.suiyuFxDelta,
        { color, opacity, transform: [{ translateY: rise }] }]}>
        {gain ? '+' : '−'}{groupDigits(Math.abs(fx.delta))}
      </Animated.Text>
      <Animated.Text style={[styles.suiyuFxEq, { opacity }]}>
        {groupDigits(fx.from)} {gain ? '+' : '−'} {groupDigits(Math.abs(fx.delta))} = {groupDigits(fx.to)}
      </Animated.Text>
    </View>
  );
}

/* 消费记录弹窗：本设备观察到的碎玉扣减流水（时间/项目/数额）。 */
function SuivLogModal({ visible, onClose }) {
  const suiyuLog = useGameStore(state => state.suiyuLog);
  const userid = useGameStore(state => state.userid);
  const entries = suiyuLog || [];
  const clearLog = () => {
    Alert.alert('清空消费记录', '确定删除本设备的所有消费记录吗？', [
      { text: '取消', style: 'cancel' },
      {
        text: '清空', style: 'destructive',
        onPress: () => {
          useGameStore.setState({ suiyuLog: [] });
          clearSuiyuLog(userid);
        },
      },
    ]);
  };
  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose}>
      <View style={styles.suiyuLogScreen}>
        <View style={styles.suiyuLogHeader}>
          <View style={{ flex: 1 }}>
            <Text style={styles.suiyuLogEyebrow}>账号碎玉消费流水</Text>
            <Text style={styles.suiyuLogTitle}>🧾 消费记录</Text>
          </View>
          <TouchableOpacity onPress={clearLog} style={styles.suiyuLogBtn}>
            <Text style={styles.suiyuLogBtnText}>清空</Text>
          </TouchableOpacity>
          <TouchableOpacity onPress={onClose} style={styles.suiyuLogBtnClose}>
            <Text style={styles.suiyuLogBtnText}>✕ 返回</Text>
          </TouchableOpacity>
        </View>
        <FlatList
          style={{ flex: 1 }}
          contentContainerStyle={{ padding: 14, gap: 8 }}
          data={entries}
          keyExtractor={item => `${item.t}-${item.amount}`}
          ListEmptyComponent={
            <Text style={styles.suiyuLogEmpty}>
              还没有消费记录。{'\n'}购买道具、兑换服务扣碎玉时会自动记在这里。
            </Text>
          }
          renderItem={({ item }) => (
            <View style={styles.suiyuLogRow}>
              <View style={styles.suiyuLogTimeCol}>
                <Text style={styles.suiyuLogTime}>
                  {suiyuTime(item.t)}
                </Text>
                <Text style={styles.suiyuLogBalance}>
                  余额 {groupDigits(item.after)}
                </Text>
              </View>
              <Text style={styles.suiyuLogLabel} numberOfLines={2}>
                {item.label}
              </Text>
              <Text style={styles.suiyuLogAmount}>
                −{groupDigits(item.amount)}
              </Text>
            </View>
          )}
        />
        <Text style={styles.suiyuLogNote}>
          仅记录本设备观察到的碎玉扣减；充值与其他设备的消费不一定在此列。
        </Text>
      </View>
    </Modal>
  );
}

/* 删除账号确认弹窗：输入账号ID+密码双确认，服务端归档全部人物。 */
function DeleteAccountModal({ visible, onClose }) {
  const accountToken = useGameStore(state => state.accountToken);
  const userid = useGameStore(state => state.userid);
  const logout = useGameStore(state => state.logout);
  const [accountId, setAccountId] = useState('');
  const [password, setPassword] = useState('');
  const [phase, setPhase] = useState('input'); /* input|busy|done|error */
  const [message, setMessage] = useState('');

  const submit = async () => {
    if (accountId.trim() !== userid) {
      setPhase('error');
      setMessage('输入的账号ID与当前登录账号不一致');
      return;
    }
    setPhase('busy');
    setMessage('');
    try {
      await accountApi.deleteAccount(accountToken, password,
        accountId.trim(), accountApi.newDeleteRequestId());
      setPhase('done');
      setMessage('账号已删除，全部人物数据已安全归档');
    } catch (e) {
      setPhase('error');
      setMessage(e.message || '删除失败，请稍后再试');
    }
  };

  return (
    <Modal visible={visible} transparent animationType="fade"
      onRequestClose={onClose}>
      <Pressable style={styles.menuOverlay} onPress={onClose}>
        <View style={styles.deletePanel}
          onStartShouldSetResponder={() => true}>
          <Text style={styles.deleteTitle}>🗑️ 删除账号</Text>
          <Text style={styles.deleteWarning}>
            将永久删除账号「{userid}」及其全部人物，所有数据归档后不可
            恢复。为防误删，请输入账号ID与密码确认。
          </Text>
          {phase === 'done' ? (
            <>
              <Text style={styles.deleteDone}>✓ {message}</Text>
              <TouchableOpacity style={styles.deleteButton}
                onPress={logout}>
                <Text style={styles.deleteButtonText}>完成</Text>
              </TouchableOpacity>
            </>
          ) : (
            <>
              <TextInput
                style={styles.deleteInput}
                value={accountId}
                onChangeText={setAccountId}
                autoCapitalize="none" autoCorrect={false}
                placeholder={`输入账号ID：${userid}`}
                placeholderTextColor="#6a5a6a"
              />
              <TextInput
                style={styles.deleteInput}
                value={password}
                onChangeText={setPassword}
                secureTextEntry
                placeholder="输入账号密码"
                placeholderTextColor="#6a5a6a"
              />
              {phase === 'error' && !!message && (
                <Text style={styles.deleteError}>{message}</Text>
              )}
              <TouchableOpacity
                style={[styles.deleteButton,
                  (phase === 'busy' || !accountId || !password) &&
                    styles.deleteButtonDisabled]}
                disabled={phase === 'busy' || !accountId || !password}
                onPress={submit}>
                {phase === 'busy'
                  ? <ActivityIndicator size="small" color="#ffe3e8" />
                  : <Text style={styles.deleteButtonText}>
                      永久删除账号
                    </Text>}
              </TouchableOpacity>
              <TouchableOpacity style={styles.deleteCancel}
                onPress={onClose}>
                <Text style={styles.deleteCancelText}>取消</Text>
              </TouchableOpacity>
            </>
          )}
        </View>
      </Pressable>
    </Modal>
  );
}

export default function GameScreen() {
  const store = useGameStore();
  const { theme, themeId, setThemeId } = useTheme();
  const { width: screenW } = useWindowDimensions();
  const isTablet = screenW >= 768;
  const contentMaxW = isTablet ? 720 : 0;
  const listRef = useRef(null);
  const [inputValues, setInputValues] = useState({});
  const [moreOpen, setMoreOpen] = useState(false);
  const [equipOpen, setEquipOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [rechargeOpen, setRechargeOpen] = useState(false);
  const [suiyuLogOpen, setSuiyuLogOpen] = useState(false);
  const [worldMapOpen, setWorldMapOpen] = useState(false);
  const [showOnboarding, setShowOnboarding] = useState(false);
  const [charListOpen, setCharListOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [uiSettings, setUiSettings] = useState(DEFAULT_UI_SETTINGS);
  const [activeTab, setActiveTab] = useState('');
  const [floaters, setFloaters] = useState([]);
  const [skillEffects, setSkillEffects] = useState([]);
  /* 扣玉动画：header 碎玉数字滚动 + −Y 浮动 + 算式提示。 */
  const [suiyuFx, setSuiyuFx] = useState(null);
  const [suiyuShown, setSuiyuShown] = useState(null);
  const prevSuiyuRef = useRef(null);
  const suiyuValue = store.status
    && typeof store.status.account_suiyu === 'number'
    ? store.status.account_suiyu : null;
  useEffect(() => {
    if (suiyuValue === null) return;
    const prev = prevSuiyuRef.current;
    prevSuiyuRef.current = suiyuValue;
    if (prev === null || prev === suiyuValue) {
      setSuiyuShown(suiyuValue);
      return;
    }
    setSuiyuFx({ id: Date.now(), from: prev, to: suiyuValue,
      delta: suiyuValue - prev });
    /* 数字滚动：8 步缓动从旧值减到新值。 */
    let step = 0;
    const total = 8;
    const timer = setInterval(() => {
      step += 1;
      const t = step / total;
      const eased = 1 - Math.pow(1 - t, 2);
      setSuiyuShown(Math.round(prev + (suiyuValue - prev) * eased));
      if (step >= total) clearInterval(timer);
    }, 70);
    const clear = setTimeout(() => setSuiyuFx(null), 1900);
    return () => { clearInterval(timer); clearTimeout(clear); };
  }, [suiyuValue]);
  /* 切换角色/退出登录：重置基线，不播跨角色动画。 */
  useEffect(() => {
    prevSuiyuRef.current = null;
    setSuiyuShown(null);
    setSuiyuFx(null);
  }, [store.txd]);
  const [statsSummary, setStatsSummary] = useState(null);
  const statsRef = useRef(createStatsTracker());
  const lastPollRef = useRef(0);
  const lastStatusRef = useRef(0);
  /* 用户主动导航后的阅读保护期：期间不拉挂机画面，防止子菜单被
   * 服务端autofight视图盖掉（挂机在服务端继续跑，不受影响）。 */
  const lastUserNavRef = useRef(0);
  const lastBattleProbeRef = useRef(0);
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

  /* 挂机开启的瞬间清掉阅读保护期：玩家点挂机就是想立刻看战斗，
   * 不能被15秒菜单保护挡住画面轮询。 */
  const wasAfkRef = useRef(false);
  /* 新手引导：首次进入游戏时显示（AsyncStorage 持久化标记） */
  useEffect(() => {
    if (store.txd) {
      import('../utils/themeStorage.js').then(({ injectableStorage }) => {
        injectableStorage().then(st =>
          st.getItem('xiand.onboarding_done')).then(done => {
            if (!done) {
              setShowOnboarding(true);
              injectableStorage().then(st =>
                st.setItem('xiand.onboarding_done', '1'));
            }
          });
      }).catch(() => {});
    }
  }, [store.txd]);

  useEffect(() => {
    if (store.autofighting && !wasAfkRef.current) {
      lastUserNavRef.current = 0;
      lastPollRef.current = 0;
    }
    wasAfkRef.current = store.autofighting;
  }, [store.autofighting]);

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
      if (reading) {
        /* 阅读保护期：只刷数值，绝不触碰画面。 */
        if (now - lastStatusRef.current < 5000) return;
        lastStatusRef.current = now;
        state.refreshStatus();
        return;
      }
      if (afk) {
        /* 挂机中：3s拉一帧挂机画面（服务端autofight视图）。 */
        if (now - lastPollRef.current < 3000) return;
        lastPollRef.current = now;
        state.pollGameView(platform);
        return;
      }
      if (fighting) {
        /* 疑似战斗：先battle_status探针（不动画面），服务端确认
         * in_battle才拉画面——防止残留inBattle标志时每秒把
         * 房间视图盖到玩家正看的菜单上。 */
        if (now - lastBattleProbeRef.current < 1000) return;
        lastBattleProbeRef.current = now;
        state.refreshBattle().then(() => {
          if (useGameStore.getState().inBattle) {
            lastPollRef.current = Date.now();
            useGameStore.getState().pollGameView(platform);
          }
        });
        return;
      }
      /* 空闲：只刷新状态数值（不触碰画面行）。 */
      if (now - lastStatusRef.current < 10000) return;
      lastStatusRef.current = now;
      state.refreshStatus();
    }, 1000);
    const appStateSub = AppState.addEventListener('change', nextState => {
      if (nextState === 'active') {
        lastPollRef.current = 0;
        lastStatusRef.current = 0;
        const state = useGameStore.getState();
        if (afkRef.current) {
          state.pollGameView(platform);
        } else if (inBattleRef.current) {
          state.refreshBattle().then(() => {
            if (useGameStore.getState().inBattle) {
              state.pollGameView(platform);
            }
          });
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
    /* 累积战斗统计 */
    applyEvents(statsRef.current, events);
    const summary = formatStats(statsRef.current);
    if (summary) setStatsSummary(summary);
    if (!effectsRef.current) return;
    const timers = [];
    if (events.length > 0) {
      const batch = events.slice(0, 6).map((event, index) => ({
        ...event,
        id: `float-${Date.now()}-${index}`,
      }));
      setFloaters(prev => [...prev, ...batch].slice(-8));
      timers.push(setTimeout(() => {
        setFloaters(prev => prev.filter(f =>
          !batch.some(b => b.id === f.id)));
      }, eventDuration(batch[0])));
    }

    /* 技能动画队列：1200ms 内同类型+同名+同目标去重（与网页版一致）。 */
    const pendingSkills = [];
    const seenSkill = (type, name, target) => pendingSkills.some(s =>
      s.type === type && s.name === name && s.target === target);

    /* 闪避/格挡/中毒：玩家身上的状态特效（叠加浮动数字之外）。 */
    const STATE_FX = { dodge: '闪避', block: '格挡', poison: '持续伤害' };
    for (const event of events) {
      if (STATE_FX[event.kind] &&
        !seenSkill(event.kind, STATE_FX[event.kind], 'player')) {
        pendingSkills.push({
          id: `skill-${Date.now()}-st-${event.kind}-${Math.random()}`,
          type: event.kind, name: STATE_FX[event.kind], target: 'player',
        });
      }
      /* 暴击伤害：对目标追加强化爆炸特效。 */
      if (event.kind === 'damage' && event.critical && event.value > 0 &&
        !seenSkill('critical', '会心一击', event.target)) {
        pendingSkills.push({
          id: `skill-${Date.now()}-crit-${Math.random()}`,
          type: 'critical', name: '会心一击', target: event.target,
        });
      }
    }

    /* 技能施法动画：从新行提取技能名→类型→目标位置→视觉特效 */
    for (const line of newLines.slice(0, 5)) {
      const text = ((line && line.segments) || [])
        .map(s => s.type === 'text'
          ? ((s.parts) || []).map(p => p.content || '').join('')
          : '').join('');
      const name = extractSkillName(text);
      if (name) {
        const type = parseSkillType(text) || parseSkillType(name) || 'generic';
        const target = skillAnimationTarget(type, text);
        if (!seenSkill(type, name, target)) {
          pendingSkills.push({
            id: `skill-${Date.now()}-${Math.random()}`,
            name, type, target,
          });
        }
        break; /* 每帧最多一个施法特效 */
      }
    }

    /* 丹药服用 → buff 光效（挂机自动嗑药也触发）。 */
    for (const line of newLines.slice(0, 5)) {
      const text = ((line && line.segments) || [])
        .map(s => s.type === 'text'
          ? ((s.parts) || []).map(p => p.content || '').join('')
          : '').join('');
      const eat = text.match(/你(?:食用|阅读)了([^。。\n]+?)(?:[。\n]|$)/);
      if (eat && eat[1] && !seenSkill('buff', eat[1].trim(), 'player')) {
        pendingSkills.push({
          id: `skill-${Date.now()}-buff-${Math.random()}`,
          type: 'buff', name: eat[1].trim(), target: 'player',
        });
        break;
      }
    }

    if (pendingSkills.length > 0) {
      setSkillEffects(prev => [...prev, ...pendingSkills].slice(-3));
      for (const skill of pendingSkills) {
        timers.push(setTimeout(() => {
          setSkillEffects(prev =>
            prev.filter(e => e.id !== skill.id));
        }, skillMeta(skill.type).duration + 150));
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
    Vibration.vibrate(10); /* 轻微触觉反馈 */
    setMoreOpen(false);
    lastUserNavRef.current = Date.now();
    store.command(cmd.trim());
    /* 操作反馈：让玩家知道命令已发送 */
    const cmdStr = cmd.trim();
    if (/^wield |^wear /.test(cmdStr)) toast('正在穿戴装备…');
    else if (/^unwield |^unwear /.test(cmdStr)) toast('正在卸下装备…');
    else if (/^auto_equip/.test(cmdStr)) toast('智能穿装中…');
    else if (/^fly_to_room/.test(cmdStr)) toast('飞行中…');
    else if (/^term_invite_room/.test(cmdStr)) toast('正在邀请全房玩家…');
    else if (/^book_cleanup confirm/.test(cmdStr)) toast('正在清理书卷…');
  };

  /* 危险操作二次确认 */
  const sendDangerous = (cmd, confirmMsg) => {
    Alert.alert('确认操作', confirmMsg, [
      { text: '取消', style: 'cancel' },
      { text: '确认', style: 'destructive', onPress: () => send(cmd) },
    ]);
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
    <View style={isTablet ? styles.tabletContent : styles.screen}>

      {/* ===== 并行角色tab条：屏幕最顶部，账号中心模式即常驻 ===== */}
      {((store.accountToken && sessionEntries.length > 0) ||
        (sessionEntries.length > 1) ||
        ((store.accountCharacters || []).length > 1)) && (
        <>
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
            <Pressable style={styles.charChipExpand}
              onPress={() => setCharListOpen(!charListOpen)}>
              <Text style={styles.charChipExpandText}>
                {charListOpen ? '▾' : '▴'}
              </Text>
            </Pressable>
          </ScrollView>
        </View>
        {charListOpen && (
          <View style={styles.charListPanel}>
            <ScrollView horizontal showsHorizontalScrollIndicator={false}
              contentContainerStyle={{ gap: 6, paddingHorizontal: 12,
                paddingVertical: 6 }}>
              {sessionEntries.map(entry => (
                <Pressable
                  key={entry.id}
                  style={[
                    styles.charChip,
                    entry.active && styles.charChipActive,
                  ]}
                  onPress={() => {
                    setCharListOpen(false);
                    if (!entry.active) {
                      if (entry.hasSession) store.switchCharacter(entry.id);
                      else store.pickCharacter(entry.id);
                    }
                  }}>
                  <Text style={[styles.charChipName,
                    entry.active && styles.charChipNameActive]}
                    numberOfLines={1}>
                    {entry.summary.inBattle ? '⚔ ' : ''}
                    {entry.name}
                  </Text>
                  <Text style={[styles.charChipMeta,
                    entry.active && styles.charChipNameActive]}>
                    {entry.hasSession ? 'Lv.'+(entry.summary.level||'?') : '多开'}
                  </Text>
                </Pressable>
              ))}
            </ScrollView>
          </View>
        )}
        </>
      
      )}

      {/* ===== 离线横幅 ===== */}
      {!store.networkOnline && (
        <View style={styles.offlineBanner}>
          <Text style={styles.offlineText}>
            ⚠ 网络已断开，正在重连…
          </Text>
        </View>
      )}

      {/* ===== 新手引导（首次使用） ===== */}
      {showOnboarding && (
        <TouchableOpacity
          style={styles.onboardingOverlay}
          activeOpacity={1}
          onPress={() => setShowOnboarding(false)}>
          <View style={styles.onboardingCard}>
            <Text style={styles.onboardingTitle}>🧭 快速上手指南</Text>
            <Text style={styles.onboardingItem}>1️⃣ 点击左上角头像 → 查看装备和属性</Text>
            <Text style={styles.onboardingItem}>2️⃣ 点击 🗺️ 按钮 → 打开世界地图飞行</Text>
            <Text style={styles.onboardingItem}>3️⃣ 点击 ▶ 挂机 → 自动打怪无需操作</Text>
            <Text style={styles.onboardingItem}>4️⃣ 点击 ☰ 菜单 → 消费记录/主题/设置</Text>
            <Text style={styles.onboardingHint}>点击任意位置关闭</Text>
          </View>
        </TouchableOpacity>
      )}

      {/* ===== 顶栏：复刻 Vue game-header ===== */}
      <View style={styles.header}>
        <View style={styles.infoRow}>
          <AvatarPressable
            onPress={() => {
              lastUserNavRef.current = Date.now();
              setEquipOpen(true);
            }}>
            {avatarUrl ? (
              <SmartImage uri={avatarUrl} style={styles.headerAvatar} />
            ) : (
              <View style={styles.headerAvatarPlaceholder}>
                <Text style={styles.headerAvatarText}>
                  {(status.name_cn || '仙')[0]}
                </Text>
              </View>
            )}
          </AvatarPressable>
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
            {typeof status.heart_bonus_think === 'number' &&
             status.heart_bonus_think > 0 && (
              <View style={styles.heartChip}>
                <Text style={styles.heartChipText}>
                  ✨心法+{fmt(status.heart_bonus_think)}
                </Text>
              </View>
            )}
            {typeof status.account_suiyu === 'number' && (
              <View style={styles.suiyuChipWrap}>
                {Platform.OS === 'ios' ? (
                  <TouchableOpacity style={styles.suiyuChip}
                    activeOpacity={0.6}
                    onPress={() => {
                      lastUserNavRef.current = Date.now();
                      setRechargeOpen(true);
                    }}>
                    <Text style={styles.suiyuText} numberOfLines={1}>
                      💎{fmt(typeof suiyuShown === 'number'
                        ? suiyuShown : status.account_suiyu)}
                      <Text style={styles.suiyuPlus}> ＋</Text>
                    </Text>
                  </TouchableOpacity>
                ) : (
                  <View style={styles.suiyuChip}>
                    <Text style={styles.suiyuText} numberOfLines={1}>
                      💎{fmt(typeof suiyuShown === 'number'
                        ? suiyuShown : status.account_suiyu)}
                    </Text>
                  </View>
                )}
                {!!suiyuFx && suiyuFx.delta !== 0 && (
                  <SuiyuDeltaFx fx={suiyuFx} />
                )}
              </View>
            )}
          </View>
          <TouchableOpacity
            style={styles.mapButton}
            activeOpacity={0.7}
            onPress={() => {
              lastUserNavRef.current = Date.now();
              setWorldMapOpen(true);
            }}>
            <Text style={styles.mapButtonText}>🗺️</Text>
          </TouchableOpacity>
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
              fontScale: fontScaleFor(uiSettings.fontSize) * (isTablet ? 1.25 : 1),
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

      {/* ===== 世界地图 ===== */}
      <WorldMapScreen
        visible={worldMapOpen}
        onClose={() => setWorldMapOpen(false)}
      />

      {/* ===== 消费记录 ===== */}
      <SuivLogModal
        visible={suiyuLogOpen}
        onClose={() => setSuiyuLogOpen(false)}
      />

      {/* ===== 删除账号确认（Apple 5.1.1(v)） ===== */}
      <DeleteAccountModal
        visible={deleteOpen}
        onClose={() => setDeleteOpen(false)}
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
            <MenuRow icon="🗺️" label="世界地图 / 飞行"
              onPress={() => {
                setMenuOpen(false);
                setWorldMapOpen(true);
              }} />
            <MenuRow icon="🤝" label="邀请好友 / 查看奖励"
              onPress={() => {
                setMenuOpen(false);
                send('invite');
              }} />
            {typeof status.account_suiyu === 'number' && (
              <View style={styles.menuRow}>
                <Text style={styles.menuRowIcon}>💎</Text>
                <Text style={styles.menuRowLabel}>
                  碎玉余额：{groupDigits(status.account_suiyu)}
                </Text>
              </View>
            )}
            <MenuRow icon="🧾" label="消费记录"
              onPress={() => {
                setMenuOpen(false);
                setSuiyuLogOpen(true);
              }} />
            {Platform.OS === 'ios' && (
              <MenuRow icon="💎" label="碎玉充值（内购）"
                onPress={() => {
                  setMenuOpen(false);
                  setRechargeOpen(true);
                }} />
            )}
            <View style={styles.themeRow}>
              <Text style={styles.menuRowIcon}>🎨</Text>
              <Text style={styles.menuRowLabel}>主题颜色</Text>
            </View>
            <View style={styles.themeChips}>
              {Object.values(APP_THEMES).map(t => (
                <TouchableOpacity
                  key={t.id}
                  style={[
                    styles.themeChip,
                    themeId === t.id && styles.themeChipActive,
                  ]}
                  onPress={() => setThemeId(t.id)}>
                  <Text style={[
                    styles.themeChipText,
                    themeId === t.id && styles.themeChipTextActive,
                  ]}>
                    {t.icon} {t.label}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
            <View style={styles.menuDivider} />
            <MenuRow icon="👥" label="多开角色 / 切换职业"
              onPress={() => {
                setMenuOpen(false);
                store.backToDashboard();
              }} />
            <MenuRow icon="🗑️" label="删除账号"
              onPress={() => {
                setMenuOpen(false);
                setDeleteOpen(true);
              }} />
            <MenuRow icon="🚪" label="退出登录" danger
              onPress={() => {
                setMenuOpen(false);
                store.logout();
              }} />
          </View>
        </Pressable>
      </Modal>
    </View>
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
  tabletContent: {
    flex: 1, maxWidth: 720, alignSelf: 'center', width: '100%',
  },
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
  heartChip: {
    backgroundColor: '#102018', borderWidth: 1, borderColor: '#3a7a5a',
    borderRadius: 5, paddingHorizontal: 6, paddingVertical: 1,
  },
  heartChipText: { color: '#7ad0a0', fontSize: 10, fontWeight: '700' },
  suiyuChip: {
    backgroundColor: '#10201a', borderWidth: 1, borderColor: '#3a7a5a',
    borderRadius: 5, paddingHorizontal: 6, paddingVertical: 1,
  },
  suiyuChipWrap: { position: 'relative' },
  suiyuFxBox: { position: 'absolute', top: 22, left: 0, zIndex: 60 },
  suiyuFxDelta: {
    fontSize: 15, fontWeight: '800',
    textShadowColor: '#000', textShadowRadius: 3,
  },
  suiyuFxEq: {
    fontSize: 10, color: '#c8b8a0', marginTop: 1,
    backgroundColor: 'rgba(13,11,14,0.78)',
    paddingHorizontal: 5, paddingVertical: 1, borderRadius: 4,
    overflow: 'hidden',
  },
  suiyuText: { color: '#7ad0a0', fontSize: 11, fontWeight: '700' },
  suiyuPlus: { color: '#d4af37', fontSize: 10, fontWeight: '800' },
  suiyuLogScreen: { flex: 1, backgroundColor: '#0d0b0e', paddingTop: 54 },
  suiyuLogHeader: {
    flexDirection: 'row', alignItems: 'center', gap: 8,
    paddingHorizontal: 16, paddingVertical: 10,
    borderBottomWidth: 1, borderBottomColor: '#2e2430',
    backgroundColor: '#14101a',
  },
  suiyuLogEyebrow: { color: '#8a7a8a', fontSize: 10 },
  suiyuLogTitle: { color: '#f0e6d2', fontSize: 17, fontWeight: '700' },
  suiyuLogBtn: {
    paddingHorizontal: 10, paddingVertical: 5, borderRadius: 8,
    borderWidth: 1, borderColor: '#5a3a46',
  },
  suiyuLogBtnClose: {
    paddingHorizontal: 10, paddingVertical: 5, borderRadius: 8,
    borderWidth: 1, borderColor: '#3a2f46',
  },
  suiyuLogBtnText: { color: '#c8a8b8', fontSize: 12 },
  suiyuLogEmpty: {
    color: '#6a5a6a', textAlign: 'center', paddingTop: 80,
    fontSize: 13, lineHeight: 22,
  },
  suiyuLogRow: {
    flexDirection: 'row', alignItems: 'center', gap: 10,
    backgroundColor: '#17131c', borderRadius: 10,
    borderWidth: 1, borderColor: '#2c2338', padding: 10,
  },
  suiyuLogTimeCol: { width: 92 },
  suiyuLogTime: { color: '#8a7a8a', fontSize: 11 },
  suiyuLogBalance: { color: '#5a4a5a', fontSize: 10, marginTop: 2 },
  suiyuLogLabel: {
    color: '#e0d6c2', fontSize: 13, fontWeight: '600', flex: 1,
  },
  suiyuLogAmount: {
    color: '#ff5a6a', fontSize: 14, fontWeight: '800',
  },
  suiyuLogNote: {
    color: '#5a4a5a', fontSize: 10, textAlign: 'center',
    paddingVertical: 8,
  },
  mapButton: {
    paddingHorizontal: 11, minHeight: 30, borderRadius: 999,
    borderWidth: 1, borderColor: '#5a7a8a',
    alignItems: 'center', justifyContent: 'center',
    backgroundColor: '#102028',
  },
  mapButtonText: { fontSize: 16 },
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
  charChipExpand: {
    paddingHorizontal: 8, paddingVertical: 4, marginLeft: 2,
  },
  charChipExpandText: { color: '#a89aa8', fontSize: 14, fontWeight: '700' },
  charListPanel: {
    backgroundColor: '#14101a', borderBottomWidth: 1,
    borderBottomColor: '#2e2430',
  },
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
  themeRow: {
    flexDirection: 'row', alignItems: 'center', gap: 10,
    paddingHorizontal: 12, paddingVertical: 8,
  },
  themeChips: {
    flexDirection: 'row', flexWrap: 'wrap', gap: 6,
    paddingHorizontal: 12, paddingBottom: 8,
  },
  themeChip: {
    paddingHorizontal: 14, paddingVertical: 7, borderRadius: 999,
    borderWidth: 1, borderColor: '#3a2f46', backgroundColor: '#1a1522',
  },
  themeChipActive: {
    borderColor: '#d4af37', backgroundColor: '#231b10',
  },
  themeChipText: { color: '#a89aa8', fontSize: 12 },
  themeChipTextActive: { color: '#ffd700', fontSize: 12, fontWeight: '700' },
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
  deletePanel: {
    marginTop: 120, marginHorizontal: 28, borderRadius: 14,
    backgroundColor: '#17131c', borderWidth: 1, borderColor: '#5a1a2a',
    padding: 18, gap: 12,
  },
  deleteTitle: { color: '#ff9aa8', fontSize: 17, fontWeight: '700',
    textAlign: 'center' },
  deleteWarning: { color: '#a89aa8', fontSize: 12, lineHeight: 18 },
  deleteInput: {
    backgroundColor: '#1a141c', borderRadius: 10, borderWidth: 1,
    borderColor: '#3a2f46', paddingHorizontal: 12, paddingVertical: 10,
    color: '#f0e6d2', fontSize: 14, minHeight: 42,
  },
  deleteButton: {
    borderRadius: 10, borderWidth: 1, borderColor: '#ff4d6d',
    backgroundColor: '#3d1018', paddingVertical: 12,
    alignItems: 'center',
  },
  deleteButtonDisabled: { opacity: 0.5 },
  deleteButtonText: { color: '#ffe3e8', fontSize: 14, fontWeight: '600' },
  deleteCancel: { alignItems: 'center', paddingVertical: 6 },
  deleteCancelText: { color: '#8a7a8a', fontSize: 13 },
  deleteDone: { color: '#9ad0a0', fontSize: 14, textAlign: 'center',
    lineHeight: 20 },
  deleteError: { color: '#ff9aa8', fontSize: 12 },
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
