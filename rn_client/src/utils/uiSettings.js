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
    }));
  } catch (e) {
    /* 偏好保存失败静默。 */
  }
}
