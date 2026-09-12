/**
 * 界面偏好（字号/特效开关）持久化：与 sessionStore 同款可注入后端。
 * 字号档位对应网页版 fontSize: small/normal/large/xlarge。
 */

export const FONT_SCALE_OPTIONS = [
  { id: 'small', label: '小', scale: 0.85 },
  { id: 'normal', label: '标准', scale: 1 },
  { id: 'large', label: '大', scale: 1.18 },
  { id: 'xlarge', label: '特大', scale: 1.35 },
];

export function fontScaleFor(id) {
  const hit = FONT_SCALE_OPTIONS.find(option => option.id === id);
  return hit ? hit.scale : 1;
}

/* 建议9 固定排版：按屏幕宽度一次性适配到现有字号档，
 * 换机/旋转后比例恒定，不再依赖手工选择。
 * 320px→小 390px→标准 460px→大 500px+→特大。 */
export function fixedLayoutScale(screenW) {
  const ratio = (screenW || 390) / 390;
  if (ratio <= 0.92) return 0.85;
  if (ratio <= 1.05) return 1;
  if (ratio <= 1.28) return 1.18;
  return 1.35;
}

export function resolvedFontScale(uiSettings, screenW) {
  if (uiSettings && uiSettings.fixedLayout)
    return fixedLayoutScale(screenW);
  return fontScaleFor(uiSettings ? uiSettings.fontSize : 'normal');
}

const SETTINGS_KEY = 'xiand.uiSettings';

let injectedBackend = null;

export function setSettingsBackend(backend) {
  injectedBackend = backend;
}

async function backend() {
  if (injectedBackend) return injectedBackend;
  const module = await import('@react-native-async-storage/async-storage');
  return module.default;
}

export const DEFAULT_UI_SETTINGS = {
  fontSize: 'normal',
  combatEffects: true,
  fixedLayout: false,
};

export async function loadUiSettings() {
  try {
    const storage = await backend();
    const raw = await storage.getItem(SETTINGS_KEY);
    if (!raw) return { ...DEFAULT_UI_SETTINGS };
    const parsed = JSON.parse(raw);
    return {
      fontSize: FONT_SCALE_OPTIONS.some(o => o.id === parsed.fontSize)
        ? parsed.fontSize : DEFAULT_UI_SETTINGS.fontSize,
      combatEffects: typeof parsed.combatEffects === 'boolean'
        ? parsed.combatEffects : DEFAULT_UI_SETTINGS.combatEffects,
      fixedLayout: typeof parsed.fixedLayout === 'boolean'
        ? parsed.fixedLayout : DEFAULT_UI_SETTINGS.fixedLayout,
    };
  } catch (e) {
    return { ...DEFAULT_UI_SETTINGS };
  }
}

export async function saveUiSettings(settings) {
  try {
    const storage = await backend();
    await storage.setItem(SETTINGS_KEY, JSON.stringify({
      fontSize: String((settings && settings.fontSize) ||
        DEFAULT_UI_SETTINGS.fontSize),
      combatEffects: !!(settings && settings.combatEffects),
      fixedLayout: !!(settings && settings.fixedLayout),
    }));
  } catch (e) {
    /* 偏好保存失败静默。 */
  }
}
