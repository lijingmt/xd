import React, { createContext, useContext, useEffect, useState } from 'react';
import { useColorScheme } from 'react-native';
import {
  APP_THEMES, getTheme, loadThemePreference, saveThemePreference,
} from './appThemes.js';

const ThemeCtx = createContext({
  theme: APP_THEMES.night,
  themeId: 'night',
  setThemeId: () => {},
});

export function ThemeProvider({ children }) {
  const [themeId, setThemeIdState] = useState('night');
  const systemScheme = useColorScheme();

  useEffect(() => {
    loadThemePreference().then(saved => {
      /* 首次安装跟随系统；用户手动选过后用保存值 */
      if (saved !== 'night') {
        setThemeIdState(saved);
      } else if (systemScheme === 'light') {
        setThemeIdState('day');
      }
    });
  }, []);

  const setThemeId = id => {
    const normalized = APP_THEMES[id] ? id : 'night';
    setThemeIdState(normalized);
    saveThemePreference(normalized);
  };

  const theme = getTheme(themeId);
  return (
    <ThemeCtx.Provider value={{ theme, themeId, setThemeId }}>
      {children}
    </ThemeCtx.Provider>
  );
}

export function useTheme() {
  return useContext(ThemeCtx);
}
