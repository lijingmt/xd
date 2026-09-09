/**
 * App version check: query the server for the latest released version
 * and surface an update prompt when the installed build is older.
 * iOS App Store release is the version baseline.
 */
import { Platform } from 'react-native';
import Constants from 'expo-constants';

export async function checkAppUpdate(apiBase) {
  try {
    const platform = Platform.OS; // 'ios' | 'android'
    const currentVersion = Constants.expoConfig?.version || '';
    const versionCode = Platform.select({
      android: String(
        Constants.expoConfig?.android?.versionCode || 0),
      ios: '',
    });
    const q = new URLSearchParams({
      platform,
      currentVersion,
      ...(versionCode ? { versionCode } : {}),
    });
    const res = await fetch(`${apiBase}/api/app_version?${q}`, {
      timeout: 8000,
    });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}
