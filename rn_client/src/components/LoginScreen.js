import React, { useEffect, useState } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, StyleSheet, ScrollView,
} from 'react-native';
import { useGameStore } from '../store/useGameStore.js';

export default function LoginScreen() {
  const {
    partitions, loadPartitions, login, busy, error, apiBase, setApiBase,
  } = useGameStore();
  const [partition, setPartition] = useState('');
  const [userid, setUserid] = useState('');
  const [password, setPassword] = useState('');

  useEffect(() => {
    loadPartitions().then(list => {
      const open = (list || []).filter(p => p.login_open !== 0);
      if (open.length && !partition) setPartition(open[0].value);
    });
  }, []);

  const openPartitions = (partitions || []).filter(p => p.login_open !== 0);

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.container}>
      <View style={styles.brandMark}><Text style={styles.brandText}>仙</Text></View>
      <Text style={styles.title}>仙道</Text>
      <Text style={styles.subtitle}>东方幻想 · 十职同行 · 原生客户端</Text>

      <Text style={styles.label}>服务器</Text>
      <TextInput
        style={styles.input}
        value={apiBase}
        onChangeText={setApiBase}
        autoCapitalize="none"
        autoCorrect={false}
        placeholder="http://127.0.0.1:8888"
        placeholderTextColor="#6a5a6a"
      />

      <Text style={styles.label}>分区</Text>
      <View style={styles.partitionRow}>
        {openPartitions.map(p => (
          <TouchableOpacity
            key={p.value}
            style={[styles.partitionChip,
              partition === p.value && styles.partitionChipActive]}
            onPress={() => setPartition(p.value)}>
            <Text style={[styles.partitionText,
              partition === p.value && styles.partitionTextActive]}>
              {p.label}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <Text style={styles.label}>账号</Text>
      <TextInput
        style={styles.input}
        value={userid}
        onChangeText={setUserid}
        autoCapitalize="none"
        autoCorrect={false}
        placeholder="输入账号"
        placeholderTextColor="#6a5a6a"
      />
      <Text style={styles.label}>密码</Text>
      <TextInput
        style={styles.input}
        value={password}
        onChangeText={setPassword}
        secureTextEntry
        placeholder="输入密码"
        placeholderTextColor="#6a5a6a"
      />

      {!!error && <Text style={styles.error}>{error}</Text>}

      <TouchableOpacity
        style={[styles.loginButton, busy && styles.loginButtonBusy]}
        disabled={busy || !partition || !userid || !password}
        onPress={() => login(partition, userid.trim(), password)}>
        <Text style={styles.loginText}>{busy ? '进入中…' : '进入仙道'}</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#0d0b0e' },
  container: { padding: 24, paddingTop: 72 },
  brandMark: {
    alignSelf: 'center', width: 72, height: 72, borderRadius: 20,
    backgroundColor: '#5a1a2a', alignItems: 'center', justifyContent: 'center',
    borderWidth: 1, borderColor: '#ff4d6d', marginBottom: 12,
  },
  brandText: { color: '#ffd9d9', fontSize: 36, fontWeight: '700' },
  title: { textAlign: 'center', color: '#f0e6d2', fontSize: 30, fontWeight: '700' },
  subtitle: { textAlign: 'center', color: '#8a7a8a', fontSize: 12, marginBottom: 28 },
  label: { color: '#a89aa8', fontSize: 12, marginTop: 12, marginBottom: 6 },
  input: {
    backgroundColor: '#1a141c', borderRadius: 10, paddingHorizontal: 14,
    paddingVertical: 10, color: '#f0e6d2', fontSize: 15,
    borderWidth: 1, borderColor: '#2e2430',
  },
  partitionRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  partitionChip: {
    paddingHorizontal: 14, paddingVertical: 7, borderRadius: 999,
    borderWidth: 1, borderColor: '#3a2f46', backgroundColor: '#1a141c',
  },
  partitionChipActive: { borderColor: '#d4af37', backgroundColor: '#2d2410' },
  partitionText: { color: '#a89aa8', fontSize: 13 },
  partitionTextActive: { color: '#ffd700' },
  error: { color: '#ff6b8a', fontSize: 12, marginTop: 12 },
  loginButton: {
    marginTop: 24, borderRadius: 999, paddingVertical: 13,
    backgroundColor: '#7a0d1f', borderWidth: 1, borderColor: '#ff4d6d',
    alignItems: 'center',
  },
  loginButtonBusy: { opacity: 0.6 },
  loginText: { color: '#ffe3e8', fontSize: 16, fontWeight: '600' },
});
