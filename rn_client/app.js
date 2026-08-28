import React from 'react';
import { StatusBar } from 'expo-status-bar';
import { View } from 'react-native';
import { useGameStore } from './src/store/useGameStore.js';
import LoginScreen from './src/components/LoginScreen.js';
import CharacterScreen from './src/components/CharacterScreen.js';
import GameScreen from './src/components/GameScreen.js';

export default function App() {
  const txd = useGameStore(state => state.txd);
  const accountToken = useGameStore(state => state.accountToken);
  return (
    <View style={{ flex: 1, backgroundColor: '#0d0b0e' }}>
      <StatusBar style="light" />
      {txd ? <GameScreen />
        : (accountToken ? <CharacterScreen /> : <LoginScreen />)}
    </View>
  );
}
