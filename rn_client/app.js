import React, { useEffect, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import { View, Text } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { useGameStore } from './src/store/useGameStore.js';
import LoginScreen from './src/components/LoginScreen.js';
import CharacterScreen from './src/components/CharacterScreen.js';
import GameScreen from './src/components/GameScreen.js';
import ErrorBoundary from './src/components/ErrorBoundary.js';

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
    <SafeAreaProvider>
      <SafeAreaView style={{ flex: 1, backgroundColor: '#0d0b0e' }} edges={['top', 'bottom', 'left', 'right']}>
        <StatusBar style="light" />
        {!ready ? (
          <View style={{
            flex: 1, alignItems: 'center', justifyContent: 'center', gap: 10,
          }}>
            <View style={{
              width: 56, height: 56, borderRadius: 16,
              borderWidth: 1, borderColor: '#d4af37',
              backgroundColor: '#5a1a2a', alignItems: 'center',
              justifyContent: 'center',
              shadowColor: '#ff4d6d', shadowOpacity: 0.5,
              shadowRadius: 14, elevation: 8,
            }}>
              <Text style={{ color: '#ffd9d9', fontSize: 28, fontWeight: '700' }}>仙</Text>
            </View>
            <Text style={{ color: '#8a7a8a', fontSize: 15 }}>仙道wapmud · 载入中…</Text>
          </View>
        ) : (txd ? <GameScreen />
          : (accountToken ? <CharacterScreen /> : <LoginScreen />))}
      </SafeAreaView>
    </SafeAreaProvider>
  );
}

export function AppWithBoundary() {
  return (
    <ErrorBoundary>
      <App />
    </ErrorBoundary>
  );
}

