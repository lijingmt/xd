import { injectableStorage } from './themeStorage.js';

export const APP_THEME_KEY = 'xiand.app_theme_v1';

export const APP_THEMES = {
  night: {
    id: 'night',
    label: '夜晚',
    icon: '🌙',
    statusBarStyle: 'light-content',
    colors: {
      appBackground: '#0d0b0e',
      headerBackground: '#14101a',
      headerBorder: '#2e2430',
      surface: '#17131c',
      surfaceSoft: '#1a1522',
      surfaceStrong: '#231b10',
      text: '#f0e6d2',
      textStrong: '#fff',
      textMuted: '#a89aa8',
      textSubtle: '#6a5a6a',
      inputBackground: '#1a1522',
      inputBorder: '#3a2f46',
      inputText: '#f0e6d2',
      modalOverlay: 'rgba(0,0,0,0.7)',
      modalBackground: '#14101a',
      menuBackground: '#1a1522',
      menuBorder: '#3a2f46',
      accent: '#d4af37',
      accentDim: '#8a6d2f',
      danger: '#ff4d6d',
      success: '#5ad47a',
      info: '#5a8ac2',
      gold: '#ffd700',
      battleHp: '#ff5a6a',
      battleHpBg: '#241016',
      battleMp: '#5a8ac2',
      battleMpBg: '#102030',
      buttonPrimary: '#231b10',
      buttonPrimaryBorder: '#8a6d2f',
      buttonPrimaryText: '#ffd700',
      buttonSecondary: '#1a2430',
      buttonSecondaryBorder: '#3a5a8a',
      buttonSecondaryText: '#9ab8d8',
    },
  },
  day: {
    id: 'day',
    label: '白天',
    icon: '☀️',
    statusBarStyle: 'dark-content',
    colors: {
      appBackground: '#f5f0e8',
      headerBackground: '#faf6ef',
      headerBorder: '#d4c8b0',
      surface: '#ffffff',
      surfaceSoft: '#f0ebe3',
      surfaceStrong: '#e8e0d0',
      text: '#2a2015',
      textStrong: '#1a1208',
      textMuted: '#6a5a4a',
      textSubtle: '#8a7a6a',
      inputBackground: '#ffffff',
      inputBorder: '#c0b8a0',
      inputText: '#2a2015',
      modalOverlay: 'rgba(42,32,21,0.35)',
      modalBackground: '#faf6ef',
      menuBackground: '#f0ebe3',
      menuBorder: '#c0b8a0',
      accent: '#8a6d2f',
      accentDim: '#b8a070',
      danger: '#c4405a',
      success: '#2d8a4a',
      info: '#2a6090',
      gold: '#9a7020',
      battleHp: '#c4405a',
      battleHpBg: '#f5e0e4',
      battleMp: '#2a6090',
      battleMpBg: '#e0eaf5',
      buttonPrimary: '#f0e8d8',
      buttonPrimaryBorder: '#8a6d2f',
      buttonPrimaryText: '#5a4010',
      buttonSecondary: '#e8f0f8',
      buttonSecondaryBorder: '#5a8ac2',
      buttonSecondaryText: '#2a5080',
    },
  },
  /* 仙道特色：暗金色修仙主题 */
  gold: {
    id: 'gold',
    label: '鎏金',
    icon: '✨',
    statusBarStyle: 'light-content',
    colors: {
      appBackground: '#1a1508',
      headerBackground: '#231b10',
      headerBorder: '#3d3018',
      surface: '#20180c',
      surfaceSoft: '#282012',
      surfaceStrong: '#322818',
      text: '#f5e8c8',
      textStrong: '#fff8dc',
      textMuted: '#c0a878',
      textSubtle: '#8a7050',
      inputBackground: '#282012',
      inputBorder: '#5a4830',
      inputText: '#f5e8c8',
      modalOverlay: 'rgba(26,21,8,0.8)',
      modalBackground: '#231b10',
      menuBackground: '#282012',
      menuBorder: '#5a4830',
      accent: '#ffd700',
      accentDim: '#b89630',
      danger: '#ff6a6a',
      success: '#7ad4a0',
      info: '#7ab0d4',
      gold: '#ffd700',
      battleHp: '#ff8a6a',
      battleHpBg: '#322418',
      battleMp: '#d4b060',
      battleMpBg: '#282410',
      buttonPrimary: '#322818',
      buttonPrimaryBorder: '#b89630',
      buttonPrimaryText: '#ffd700',
      buttonSecondary: '#282412',
      buttonSecondaryBorder: '#5a6830',
      buttonSecondaryText: '#b0c878',
    },
  },
};

export function normalizeThemeId(id) {
  const v = String(id || '').trim();
  return APP_THEMES[v] ? v : 'night';
}

export function getTheme(id) {
  return APP_THEMES[normalizeThemeId(id)];
}

export async function loadThemePreference() {
  try {
    const storage = await injectableStorage();
    const saved = await storage.getItem(APP_THEME_KEY);
    return normalizeThemeId(saved);
  } catch (e) {
    return 'night';
  }
}

export async function saveThemePreference(id) {
  try {
    const storage = await injectableStorage();
    await storage.setItem(APP_THEME_KEY, normalizeThemeId(id));
  } catch (e) {
    /* 保存失败不阻断 */
  }
}
