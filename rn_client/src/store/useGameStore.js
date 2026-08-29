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
  viewSequence: 0,
  viewGeneration: '',

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

  async command(cmd) {
    const { txd } = get();
    if (!txd || !cmd) return;
    set({ busy: true, error: '' });
    try {
      const data = await api.sendCommand(txd, cmd);
      set({
        txd: data.txd || txd,
        busy: false,
        inBattle: responseHasBattleButton(data.lines)
          ? true
          : get().inBattle,
      });
      get().appendLines(data.lines || []);
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
      await get().pollAutofightView();
    } catch (e) {
      set({ autofighting: previous, error: e.message });
    } finally {
      set({ afkBusy: false });
    }
  },

  /** 挂机画面增量轮询：全量快照替换（与Vue同语义）。 */
  async pollAutofightView() {
    const { txd, viewSequence, viewGeneration } = get();
    if (!txd) return;
    try {
      const data = await api.fetchAutofightView(
        txd, viewSequence, viewGeneration);
      if (typeof data.active !== 'undefined') {
        set({ autofighting: !!data.active });
      }
      if (data.refresh) {
        const refresh = data.refresh || {};
        if (refresh.player) set({ status: refresh.player });
        if (typeof refresh.in_battle !== 'undefined') {
          set({ inBattle: !!refresh.in_battle });
          if (refresh.enemy || !refresh.in_battle) {
            set({ battle: refresh.in_battle
              ? { enemy: refresh.enemy, in_battle: 1 }
              : null });
          }
        }
      }
      if (data.unchanged) {
        const gen = String(data.generation || '');
        if (gen && gen !== get().viewGeneration) {
          set({ viewGeneration: gen, viewSequence: 0 });
        }
        return;
      }
      const gen = String(data.generation || '');
      const seq = Number(data.sequence || 0);
      if (!gen || !Number.isFinite(seq)) return;
      if (gen === get().viewGeneration && seq <= get().viewSequence) return;
      const lines = Array.isArray(data.lines) ? data.lines : null;
      set({
        viewGeneration: gen,
        viewSequence: seq,
        ...(lines ? { lines: lines.slice(-MAX_LINES) } : {}),
      });
    } catch (e) {
      /* 网络抖动静默，下轮重试 */
    }
  },

  logout() {
    clearSession().catch(() => {});
    set({
      txd: '', userid: '', lines: [], status: null,
      battle: null, inBattle: false, autofighting: false, error: '',
      accountToken: '', accountId: '', accountCharacters: [],
      characterLimit: 0,
    });
  },
}));
