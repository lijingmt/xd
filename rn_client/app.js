import React, { useEffect, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import { View, Text } from 'react-native';
import { useGameStore } from './src/store/useGameStore.js';
import LoginScreen from './src/components/LoginScreen.js';
import CharacterScreen from './src/components/CharacterScreen.js';
import GameScreen from './src/components/GameScreen.js';

export default function App() {
  const txd = useGameStore(state => state.txd);
  const accountToken = useGameStore(state => state.accountToken);
  const restoreSession = useGameStore(state => state.restoreSession);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let cancelled = false;
    restoreSession().finally(() => {
      if (!cancelled) setReady(true);
    });
    return () => { cancelled = true; };
  }, []);

  return (
    <View style={{ flex: 1, backgroundColor: '#0d0b0e' }}>
      <StatusBar style="light" />
      {!ready ? (
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
          <Text style={{ color: '#8a7a8a', fontSize: 16 }}>仙道 · 载入中…</Text>
        </View>
      ) : (txd ? <GameScreen />
        : (accountToken ? <CharacterScreen /> : <LoginScreen />))}
    </View>
  );
}
