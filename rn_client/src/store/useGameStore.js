import { create } from 'zustand';
import * as api from '../api/mudApi.js';
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

  setApiBase(base) {
    api.setApiBase(base);
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
    try {
      const fullUserid = `${partition}${userid}`;
      const data = await api.login(fullUserid, password);
      set({
        txd: data.txd || '',
        userid: fullUserid,
        busy: false,
        lines: data.lines || [],
      });
      return true;
    } catch (e) {
      set({ busy: false, error: e.message });
      return false;
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
    });
  },
}));
