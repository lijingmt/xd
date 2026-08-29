import { create } from 'zustand';
import * as api from '../api/mudApi.js';
import * as accountApi from '../api/accountApi.js';
import { responseHasBattleButton } from '../utils/segments.js';
import { saveSession, loadSession, clearSession } from '../utils/sessionStore.js';

const MAX_LINES = 400;

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

  setApiBase(base) {
    api.setApiBase(base);
    accountApi.setAccountApiBase(api.getApiBase());
    set({ apiBase: api.getApiBase() });
    /* 服务器地址随会话持久化，手机端换网络后免重填。 */
    const { accountToken, userid } = get();
    if (accountToken) {
      saveSession({ token: accountToken, userid, apiBase: api.getApiBase() })
        .catch(() => {});
    }
  },

  async restoreSession() {
    const saved = await loadSession();
    if (!saved) return false;
    if (saved.apiBase) get().setApiBase(saved.apiBase);
    set({ accountToken: saved.token, userid: saved.userid });
    try {
      await get().refreshAccountCharacters();
      return true;
    } catch (e) {
      /* 令牌过期：清会话回登录页。 */
      await clearSession().catch(() => {});
      set({ accountToken: '', userid: '', accountCharacters: [] });
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

  async pickCharacter(characterId) {
    const { accountToken } = get();
    if (!accountToken || !characterId) return;
    set({ busy: true, error: '' });
    try {
      const selected = await accountApi.selectCharacter(
        accountToken, characterId);
      const bootstrap = selected.bootstrap_command || 'init';
      const data = await api.sendCommand(selected.txd, bootstrap);
      set({
        txd: data.txd || selected.txd,
        busy: false,
        lines: data.lines || [],
        currentCharacterId: characterId,
      });
    } catch (e) {
      set({ busy: false, error: e.message });
    }
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
      const data = await api.sendCommand(txd, cmd);
      set({
        txd: data.txd || txd,
        busy: false,
        lines: (data.lines || []).slice(-MAX_LINES),
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
      if (data && typeof data.autofight !== 'undefined') {
        set({ autofighting: !!data.autofight });
      }
      /* 立即拉一帧挂机画面，让战斗输出马上出现在屏幕上。 */
      await get().pollGameView('ios');
    } catch (e) {
      set({ autofighting: previous, error: e.message });
    } finally {
      set({ afkBusy: false });
    }
  },

  /** 挂机画面轮询（txpike9 同款 flushview 命令通道，全量快照替换）。 */
  async pollGameView(platform) {
    const { txd, recovering } = get();
    if (!txd || recovering) return;
    try {
      const data = await api.sendCommand(txd, 'flushview', undefined, platform);
      set({ txd: data.txd || txd });
      const lines = Array.isArray(data.lines) ? data.lines : null;
      if (lines) set({ lines: lines.slice(-MAX_LINES) });
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
    });
  },
}));
