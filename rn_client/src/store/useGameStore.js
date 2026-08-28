import { create } from 'zustand';
import * as api from '../api/mudApi.js';
import * as accountApi from '../api/accountApi.js';
import { responseHasBattleButton } from '../utils/segments.js';

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

  setApiBase(base) {
    api.setApiBase(base);
    accountApi.setAccountApiBase(api.getApiBase());
    set({ apiBase: api.getApiBase() });
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
          accountId: account.account_id || fullUserid,
          accountCharacters: (characters.characters ||
            account.characters || []).map(accountApi.characterCard),
          characterLimit: Number(characters.limit || account.limit || 0),
          userid: fullUserid,
          busy: false,
        });
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

  async refreshAccountCharacters() {
    const { accountToken } = get();
    if (!accountToken) return;
    try {
      const data = await accountApi.fetchCharacters(accountToken);
      set({
        accountCharacters: (data.characters || [])
          .map(accountApi.characterCard),
        characterLimit: Number(data.limit || 0),
      });
    } catch (e) {
      set({ error: e.message });
    }
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
    const { txd } = get();
    if (!txd) return;
    try {
      const data = await api.setAutofight(txd, 'toggle');
      if (data && typeof data.autofight !== 'undefined') {
        set({ autofighting: !!data.autofight });
      } else {
        await get().refreshStatus();
      }
    } catch (e) {
      set({ error: e.message });
    }
  },

  logout() {
    set({
      txd: '', userid: '', lines: [], status: null,
      battle: null, inBattle: false, autofighting: false, error: '',
      accountToken: '', accountId: '', accountCharacters: [],
      characterLimit: 0,
    });
  },
}));
