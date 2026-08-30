import { create } from 'zustand';
import * as api from '../api/mudApi.js';
import * as accountApi from '../api/accountApi.js';
import { responseHasBattleButton, filterGarbageLines } from '../utils/segments.js';
import { saveSession, loadSession, clearSession } from '../utils/sessionStore.js';
import {
  canOpenMoreSessions, pickDueBackgroundSessions,
  mergeSessionSnapshot, shouldRecoverSession, PARALLEL_CHARACTER_LIMIT,
} from '../utils/parallelAfk.js';

const MAX_LINES = 400;
const BACKGROUND_SESSION_LINES = 80;

/* store 层保持零 react-native 依赖（离线 TestUnit 可加载）。
 * 运行平台由界面层启动时注入；默认 ios（与网页版一致）。 */
let runtimePlatform = 'ios';

export function setRuntimePlatform(value) {
  if (value) runtimePlatform = value;
}

function platformTag() {
  return runtimePlatform;
}

export const useGameStore = create((set, get) => ({
  apiBase: api.getApiBase(),
  partitions: [],
  txd: '',
  userid: '',
  lines: [],
  busy: false,
  error: '',
  status: null,
  battle: null,
  inBattle: false,
  autofighting: false,
  accountToken: '',
  accountId: '',
  accountCharacters: [],
  characterLimit: 0,
  accountUnlocks: { wuxiang: false, taiji: false, zhaoming: false },
  afkBusy: false,
  recovering: false,
  currentCharacterId: '',
  networkOnline: true,
  pollFailCount: 0,
  /* 多角色并行挂机：charId -> {txd,lines,status,inBattle,autofighting,
   * lastPollAt,pollInflight,failCount,afkBusy}。活动角色的画面仍是
   * 顶层 lines/status；切走时快照回 sessions，切回时恢复。 */
  sessions: {},
  parallelLimit: PARALLEL_CHARACTER_LIMIT,

  setApiBase(base) {
    api.setApiBase(base);
    accountApi.setAccountApiBase(api.getApiBase());
    set({ apiBase: api.getApiBase() });
    /* 服务器地址随会话持久化（登录前输入也记住），手机端免重填。 */
    const { accountToken, userid, currentCharacterId, sessions } = get();
    saveSession({
      token: accountToken || '',
      userid: userid || '',
      apiBase: api.getApiBase(),
      currentCharacterId: currentCharacterId || '',
      characters: Object.keys(sessions || {}).reduce((acc, id) => {
        if (sessions[id] && sessions[id].txd) acc[id] = sessions[id].txd;
        return acc;
      }, {}),
    }).catch(() => {});
  },

  persistSessions() {
    const { accountToken, userid, sessions, currentCharacterId } = get();
    if (!accountToken) return;
    const characters = {};
    for (const id of Object.keys(sessions)) {
      if (sessions[id] && sessions[id].txd) characters[id] = sessions[id].txd;
    }
    saveSession({
      token: accountToken, userid, apiBase: api.getApiBase(),
      currentCharacterId, characters,
    }).catch(() => {});
  },

  async restoreSession() {
    const saved = await loadSession();
    if (!saved) return false;
    if (saved.apiBase) get().setApiBase(saved.apiBase);
    set({ accountToken: saved.token, userid: saved.userid });
    try {
      await get().refreshAccountCharacters();
      /* 恢复并行挂机会话：txd 长期有效，角色快照进入后台轮询补齐。 */
      const sessions = {};
      for (const id of Object.keys(saved.characters || {})) {
        sessions[id] = {
          txd: saved.characters[id],
          lines: [], status: null, inBattle: false, autofighting: false,
          lastPollAt: 0, pollInflight: false, failCount: 0, afkBusy: false,
        };
      }
      set({ sessions });
      return true;
    } catch (e) {
      /* 令牌过期：清会话回登录页。 */
      await clearSession().catch(() => {});
      set({
        accountToken: '', userid: '', accountCharacters: [],
        sessions: {},
      });
      return false;
    }
  },

  async loadPartitions() {
    try {
      const data = await api.fetchPartitions();
      const list = Array.isArray(data.partitions)
        ? data.partitions
        : (Array.isArray(data) ? data : []);
      set({ partitions: list });
      return list;
    } catch (e) {
      set({ error: `分区加载失败: ${e.message}` });
      return [];
    }
  },

  appendLines(lines) {
    set(state => ({
      lines: [...state.lines, ...(lines || [])].slice(-MAX_LINES),
    }));
  },

  async login(partition, userid, password) {
    set({ busy: true, error: '' });
    const fullUserid = `${partition}${userid}`;
    try {
      /* 多角色账号中心：账号密码换取令牌+角色清单；失败则回退
         单人物直登（老账号/账号服务异常都不阻断进游）。 */
      try {
        const account = await accountApi.accountLogin(fullUserid, password);
        const characters = await accountApi.fetchCharacters(account.token);
        set({
          accountToken: account.token || '',
          userid: fullUserid,
          busy: false,
        });
        get().applyAccountData(account);
        get().applyAccountData(characters);
        if (account.token) {
          saveSession({
            token: account.token,
            userid: fullUserid,
            apiBase: api.getApiBase(),
          }).catch(() => {});
        }
        return true;
      } catch (accountError) {
        const data = await api.login(fullUserid, password);
        set({
          txd: data.txd || '',
          userid: fullUserid,
          busy: false,
          lines: data.lines || [],
        });
        return true;
      }
    } catch (e) {
      set({ busy: false, error: e.message });
      return false;
    }
  },

  applyAccountData(data) {
    if (!data || typeof data !== 'object') return;
    set({
      accountId: data.account_id || get().accountId,
      accountCharacters: Array.isArray(data.characters)
        ? data.characters.map(accountApi.characterCard)
        : get().accountCharacters,
      characterLimit: Number(data.limit || get().characterLimit || 0),
      accountUnlocks: {
        wuxiang: !!data.wuxiang_unlocked,
        taiji: !!data.taiji_unlocked,
        zhaoming: !!data.zhaoming_unlocked,
      },
    });
  },

  /** 把当前活动画面快照进 sessions（切走/回仪表盘前调用）。 */
  snapshotActiveSession() {
    const { txd, currentCharacterId, lines, status, inBattle,
      autofighting, battle, sessions } = get();
    if (!txd || !currentCharacterId) return;
    const previous = sessions[currentCharacterId] || {};
    set({
      sessions: {
        ...sessions,
        [currentCharacterId]: {
          ...previous,
          txd,
          lines: (lines || []).slice(-BACKGROUND_SESSION_LINES),
          status, inBattle, autofighting, battle,
          lastPollAt: Date.now(),
        },
      },
    });
    get().persistSessions();
  },

  async pickCharacter(characterId) {
    const { accountToken, sessions } = get();
    if (!accountToken || !characterId) return;
    if (characterId !== get().currentCharacterId) {
      if (!canOpenMoreSessions(Object.keys(sessions).length,
          get().parallelLimit) && !sessions[characterId]) {
        set({ error: `并行角色最多${get().parallelLimit}个，请先退出一部分` });
        return;
      }
      get().snapshotActiveSession();
    }
    set({ busy: true, error: '' });
    try {
      const selected = await accountApi.selectCharacter(
        accountToken, characterId);
      const bootstrap = selected.bootstrap_command || 'init';
      const data = await api.sendCommand(selected.txd, bootstrap);
      const nextTxd = data.txd || selected.txd;
      const existing = get().sessions[characterId] || {};
      set({
        txd: nextTxd,
        busy: false,
        lines: data.lines || [],
        currentCharacterId: characterId,
        sessions: {
          ...get().sessions,
          [characterId]: {
            ...existing,
            txd: nextTxd,
            lines: (data.lines || []).slice(-BACKGROUND_SESSION_LINES),
            status: null, inBattle: false, autofighting: false,
            lastPollAt: Date.now(), pollInflight: false,
            failCount: 0, afkBusy: false,
          },
        },
      });
      get().persistSessions();
    } catch (e) {
      set({ busy: false, error: e.message });
    }
  },

  /** 切换活动角色：已有会话直接换画面并立即补一帧；没有则走完整进入。 */
  async switchCharacter(characterId) {
    const { currentCharacterId, sessions } = get();
    if (!characterId || characterId === currentCharacterId) return;
    const existing = sessions[characterId];
    if (!existing || !existing.txd) {
      await get().pickCharacter(characterId);
      return;
    }
    get().snapshotActiveSession();
    set({
      currentCharacterId: characterId,
      txd: existing.txd,
      lines: existing.lines || [],
      status: existing.status || null,
      inBattle: !!existing.inBattle,
      autofighting: !!existing.autofighting,
      battle: existing.battle || null,
      busy: false, error: '',
      sessions: {
        ...get().sessions,
        [characterId]: { ...existing, lastPollAt: Date.now() },
      },
    });
    get().pollGameView(platformTag());
  },

  /** 回角色仪表盘：保留所有会话，挂机交给服务端 tick 继续跑。 */
  backToDashboard() {
    get().snapshotActiveSession();
    set({ txd: '', lines: [], status: null, battle: null,
      inBattle: false, error: '' });
  },

  /** 确保某角色有可用 txd（后台挂机开关/后台轮询前调用）。 */
  async ensureCharacterSession(characterId) {
    const { accountToken, sessions } = get();
    if (!accountToken || !characterId) return null;
    const existing = sessions[characterId];
    if (existing && existing.txd) return existing.txd;
    if (!canOpenMoreSessions(Object.keys(sessions).length,
        get().parallelLimit)) {
      throw new Error(`并行角色最多${get().parallelLimit}个，请先退出一部分`);
    }
    const selected = await accountApi.selectCharacter(
      accountToken, characterId);
    const txd = selected.txd || '';
    if (!txd) throw new Error('角色会话获取失败');
    set({
      sessions: {
        ...get().sessions,
        [characterId]: {
          ...(get().sessions[characterId] || {}),
          txd, lines: [], status: null, inBattle: false,
          autofighting: false, lastPollAt: 0, pollInflight: false,
          failCount: 0, afkBusy: false,
        },
      },
    });
    get().persistSessions();
    return txd;
  },

  /** 不切换画面，直接开关某角色的挂机（并行挂机核心入口）。 */
  async toggleCharacterAfk(characterId) {
    if (!characterId) return;
    const session = get().sessions[characterId];
    if (session && session.afkBusy) return;
    if (!session && !canOpenMoreSessions(
        Object.keys(get().sessions).length, get().parallelLimit)) {
      set({ error: `并行角色最多${get().parallelLimit}个，请先退出一部分` });
      return;
    }
    /* 只更新已存在的会话，绝不为不存在的角色创建空会话。 */
    const patchBusy = busy => set(state => {
      if (!state.sessions[characterId]) return {};
      return {
        sessions: {
          ...state.sessions,
          [characterId]: {
            ...state.sessions[characterId],
            afkBusy: busy,
          },
        },
      };
    });
    patchBusy(true);
    try {
      const txd = await get().ensureCharacterSession(characterId);
      patchBusy(true);
      const data = await api.setAutofight(txd, 'toggle');
      const autofighting = data && typeof data.autofight !== 'undefined'
        ? !!data.autofight
        : !((get().sessions[characterId] || {}).autofighting);
      set(state => ({
        sessions: {
          ...state.sessions,
          [characterId]: {
            ...(state.sessions[characterId] || {}),
            autofighting,
          },
        },
      }));
      if (characterId === get().currentCharacterId) {
        set({ autofighting });
        get().pollGameView(platformTag());
      }
    } catch (e) {
      /* 失败保留原状态；仪表盘按钮还原即可。 */
    } finally {
      patchBusy(false);
    }
  },

  /** 退出某角色的并行会话：先停挂机再退出，释放并行名额。 */
  async closeCharacterSession(characterId) {
    const { currentCharacterId, sessions } = get();
    if (!characterId || !sessions[characterId]) return;
    if (characterId === currentCharacterId) {
      get().backToDashboard();
    }
    const txd = sessions[characterId] && sessions[characterId].txd;
    const rest = { ...get().sessions };
    delete rest[characterId];
    set({ sessions: rest });
    get().persistSessions();
    if (!txd) return;
    try {
      await api.setAutofight(txd, 'off').catch(() => {});
      await api.sendCommand(txd, 'quit').catch(() => {});
    } catch (e) {
      /* 本地会话已移除；服务端按闲置规则自然回收。 */
    }
  },

  /** 后台角色快照轮询（不推进战斗，只刷新状态）。 */
  async pollBackgroundSession(characterId) {
    const session = get().sessions[characterId];
    if (!session || !session.txd || session.pollInflight) return;
    set(state => ({
      sessions: {
        ...state.sessions,
        [characterId]: { ...state.sessions[characterId],
          pollInflight: true },
      },
    }));
    try {
      const data = await api.sendCommand(
        session.txd, 'flushview', undefined, platformTag());
      /* 迟到的响应：会话已被关闭/登出，直接丢弃。 */
      if (!get().sessions[characterId]) return;
      const updated = mergeSessionSnapshot(
        get().sessions[characterId], data && data.refresh);
      const lines = Array.isArray(data && data.lines)
        ? filterGarbageLines(data.lines) : null;
      if (lines) updated.lines = lines.slice(-BACKGROUND_SESSION_LINES);
      if (data && data.txd && data.txd !== session.txd) updated.txd = data.txd;
      const refresh = (data && data.refresh) || {};
      updated.battle = refresh.in_battle && refresh.enemy
        ? { enemy: refresh.enemy, in_battle: 1 } : null;
      set(state => ({
        sessions: {
          ...state.sessions,
          [characterId]: { ...state.sessions[characterId],
            ...updated, pollInflight: false },
        },
      }));
    } catch (e) {
      const failed = get().sessions[characterId] || {};
      if (!failed) return;
      const failCount = (failed.failCount || 0) + 1;
      set(state => ({
        sessions: {
          ...state.sessions,
          [characterId]: { ...state.sessions[characterId],
            failCount, pollInflight: false },
        },
      }));
      if (shouldRecoverSession(failed) && get().accountToken) {
        /* txd 失效：静默重选，不打断玩家。 */
        try {
          await accountApi.selectCharacter(
            get().accountToken, characterId).then(selected => {
              if (selected && selected.txd) {
                set(state => ({
                  sessions: {
                    ...state.sessions,
                    [characterId]: {
                      ...state.sessions[characterId],
                      txd: selected.txd, failCount: 0,
                    },
                  },
                }));
                get().persistSessions();
              }
            });
        } catch (recoverErr) {
          /* 下轮轮询再试。 */
        }
      }
    }
  },

  /** 每帧调用：挑出到期的后台角色轮询（并发受 parallelAfk 约束）。 */
  tickBackgroundPolls() {
    const { sessions, currentCharacterId, txd } = get();
    if (!txd && Object.keys(sessions).length === 0) return;
    const due = pickDueBackgroundSessions(
      sessions, currentCharacterId, Date.now());
    for (const id of due) get().pollBackgroundSession(id);
  },


  async createCharacter(form) {
    const { accountToken } = get();
    if (!accountToken) return false;
    set({ busy: true, error: '' });
    try {
      const created = await accountApi.createCharacter(
        accountToken, form);
      const newId = created.character && created.character.id;
      await get().refreshAccountCharacters().catch(() => {});
      if (newId) {
        await get().pickCharacter(String(newId));
      }
      set({ busy: false });
      return true;
    } catch (e) {
      set({ busy: false, error: e.message });
      return false;
    }
  },

  /** 失败向上抛（restoreSession 据此判定令牌过期）；界面层自行catch。 */
  async refreshAccountCharacters() {
    const { accountToken } = get();
    if (!accountToken) return;
    const data = await accountApi.fetchCharacters(accountToken);
    get().applyAccountData(data);
  },

  /** 主命令(按钮/tab/手动输入)：清空画面→加载→填充新内容。
   *  挂机轮询(flushview)不走这里，保留增量追加。 */
  async command(cmd) {
    const { txd } = get();
    if (!txd || !cmd) return;
    set({ busy: true, error: '', lines: [] });
    try {
      const data = await api.sendCommand(txd, cmd, undefined, platformTag());
      set({
        txd: data.txd || txd,
        busy: false,
        lines: filterGarbageLines(data.lines).slice(-MAX_LINES),
        inBattle: responseHasBattleButton(data.lines)
          ? true
          : get().inBattle,
      });
    } catch (e) {
      set({ busy: false, error: e.message });
    }
  },

  async refreshStatus() {
    const { txd } = get();
    if (!txd) return;
    try {
      const status = await api.fetchStatus(txd);
      set({
        status,
        txd: status.txd || txd,
        autofighting: !!(status && status.autofight),
      });
    } catch (e) {
      /* 轮询失败静默，下一轮重试 */
    }
  },

  async refreshBattle() {
    const { txd } = get();
    if (!txd) return;
    try {
      const battle = await api.fetchBattleStatus(txd);
      set({
        battle,
        txd: battle.txd || txd,
        inBattle: !!(battle && battle.in_battle),
      });
    } catch (e) {
      /* 同上 */
    }
  },

  async toggleAutofight() {
    const { txd, afkBusy } = get();
    if (!txd || afkBusy) return;
    /* 乐观翻转：点击立刻变色换文案，失败再回滚并提示。 */
    const previous = get().autofighting;
    set({ autofighting: !previous, afkBusy: true, error: '' });
    try {
      const data = await api.setAutofight(txd, 'toggle');
      const enabled = data && typeof data.autofight !== 'undefined'
        ? !!data.autofight : !previous;
      set({ autofighting: enabled });
      /* 点按即有明确反馈：先给一句系统提示，首个挂机画面（≤3秒）
       * 到达后自然接管整屏。 */
      get().appendNotice(enabled
        ? '◎ 挂机已开启，战斗画面马上就来…'
        : '◎ 挂机已停止');
      /* 立即拉一帧挂机画面，让战斗输出马上出现在屏幕上。 */
      await get().pollGameView('ios');
    } catch (e) {
      set({ autofighting: previous, error: e.message });
    } finally {
      set({ afkBusy: false });
    }
  },

  /** 追加一条本地系统提示行（不经过服务端）。 */
  appendNotice(text) {
    set(state => ({
      lines: [...state.lines, {
        type: 'line',
        segments: [{
          type: 'text',
          parts: [{ type: 'text', content: String(text || '') }],
        }],
      }].slice(-MAX_LINES),
    }));
  },

  /** 挂机画面轮询（txpike9 同款 flushview 命令通道，全量快照替换）。 */
  async pollGameView(platform) {
    const { txd, recovering } = get();
    if (!txd || recovering) return;
    try {
      const data = await api.sendCommand(txd, 'flushview', undefined, platform);
      /* 迟到的响应：请求期间玩家已切换角色/退出，丢弃这帧，
       * 防止把旧角色的画面盖到新会话上。 */
      if (get().txd !== txd) return;
      /* 网络恢复：清失败计数，摘掉离线横幅。 */
      if (!get().networkOnline || get().pollFailCount > 0) {
        set({ networkOnline: true, pollFailCount: 0 });
      }
      set({ txd: data.txd || txd });
      const lines = Array.isArray(data.lines)
        ? filterGarbageLines(data.lines) : null;
      /* 空画面不替换屏幕：刚开挂机时首个flushview可能还没有
       * 内容（服务端首帧未生成），清屏会出现"暂无内容"闪断。 */
      if (lines && lines.length) {
        set({ lines: lines.slice(-MAX_LINES) });
      }
      const refresh = data.refresh || {};
      if (refresh.player && typeof refresh.player === 'object') {
        /* pet_assist 可能是数字0（无宠物），归一化为null防React渲染"0" */
        const player = { ...refresh.player };
        if (player.pet_assist !== null && typeof player.pet_assist !== 'object') {
          player.pet_assist = null;
        }
        set({
          status: player,
          autofighting: !!player.autofight,
        });
      }
      if (typeof refresh.in_battle !== 'undefined') {
        set({ inBattle: !!refresh.in_battle });
        if (refresh.enemy || !refresh.in_battle) {
          set({ battle: refresh.in_battle
            ? { enemy: refresh.enemy, in_battle: 1 }
            : null });
        }
      }
    } catch (e) {
      /* 连续3次轮询失败→标记离线；成功→恢复在线。 */
      const failures = get().pollFailCount + 1;
      if (failures >= 3 && get().networkOnline) {
        set({ networkOnline: false, pollFailCount: failures });
      } else {
        set({ pollFailCount: failures });
      }
      if (e && e.status === 401) {
        await get().recoverSession('flushview');
      }
      /* 其余网络抖动静默，下轮重试。 */
    }
  },

  /**
   * 游戏会话(txd)过期但账号令牌可能仍有效：尝试重选当前角色恢复，
   * 不必把玩家踢回登录页。只有账号令牌也失效时才完全登出。
   */
  async recoverSession(source) {
    const { accountToken, currentCharacterId, recovering } = get();
    if (recovering) return false;
    set({ recovering: true });
    try {
      if (accountToken && currentCharacterId) {
        const selected = await accountApi.selectCharacter(
          accountToken, currentCharacterId);
        const data = await api.sendCommand(
          selected.txd, selected.bootstrap_command || 'init');
        set({
          txd: data.txd || selected.txd,
          lines: (data.lines || []).slice(-MAX_LINES),
          error: '',
        });
        return true;
      }
      /* 无角色信息可恢复：干净登出。 */
      get().logout();
      return false;
    } catch (e) {
      if (e && e.status === 401) {
        get().logout();
      } else {
        set({ error: `会话恢复失败(${source}): ${e.message}` });
      }
      return false;
    } finally {
      set({ recovering: false });
    }
  },

  logout() {
    clearSession().catch(() => {});
    set({
      txd: '', userid: '', lines: [], status: null,
      battle: null, inBattle: false, autofighting: false, error: '',
      accountToken: '', accountId: '', accountCharacters: [],
      characterLimit: 0, currentCharacterId: '', recovering: false,
      sessions: {},
    });
  },
}));
