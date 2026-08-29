import React, { useEffect, useState } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, StyleSheet,
  ScrollView, ActivityIndicator,
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
      <View style={styles.brandGlow}>
        <View style={styles.brandMark}>
          <Text style={styles.brandText}>仙</Text>
        </View>
      </View>
      <Text style={styles.title}>仙 道</Text>
      <Text style={styles.subtitle}>东方幻想 · 十职同行</Text>
      <Text style={styles.kicker}>原生客户端 · 挂机不占屏</Text>

      <View style={styles.card}>
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

        {!!error && (
          <View style={styles.errorPill}>
            <Text style={styles.errorText}>{error}</Text>
          </View>
        )}

        <TouchableOpacity
          style={[styles.loginButton,
            (busy || !partition || !userid || !password) &&
              styles.loginButtonDisabled]}
          disabled={busy || !partition || !userid || !password}
          onPress={() => login(partition, userid.trim(), password)}>
          {busy
            ? <ActivityIndicator color="#ffe3e8" size="small" />
            : <Text style={styles.loginText}>进入仙道</Text>}
        </TouchableOpacity>
      </View>

      <Text style={styles.footer}>挂机在服务器持续运行 · 关闭客户端也不停</Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#0d0b0e' },
  container: { padding: 22, paddingTop: 48, paddingBottom: 36 },
  brandGlow: {
    alignSelf: 'center', borderRadius: 26,
    shadowColor: '#ff4d6d', shadowOpacity: 0.45,
    shadowRadius: 22, shadowOffset: { width: 0, height: 0 },
    elevation: 10,
  },
  brandMark: {
    width: 84, height: 84, borderRadius: 24,
    backgroundColor: '#3d1018', alignItems: 'center', justifyContent: 'center',
    borderWidth: 1.5, borderColor: '#d4af37',
  },
  brandText: {
    color: '#ffe3e8', fontSize: 42, fontWeight: '700',
    textShadowColor: '#ff4d6d', textShadowRadius: 10,
  },
  title: {
    textAlign: 'center', color: '#f0e6d2', fontSize: 34,
    fontWeight: '700', letterSpacing: 10, marginTop: 18,
  },
  subtitle: { textAlign: 'center', color: '#a89aa8', fontSize: 14, marginTop: 6 },
  kicker: {
    textAlign: 'center', color: '#d4af37', fontSize: 12,
    marginTop: 4, marginBottom: 24, letterSpacing: 2,
  },
  card: {
    backgroundColor: '#14101a', borderRadius: 18,
    borderWidth: 1, borderColor: '#2e2430', padding: 18,
  },
  label: { color: '#a89aa8', fontSize: 13, marginTop: 14, marginBottom: 7 },
  input: {
    backgroundColor: '#1c1620', borderRadius: 12, paddingHorizontal: 15,
    paddingVertical: 13, minHeight: 48, color: '#f0e6d2', fontSize: 16,
    borderWidth: 1, borderColor: '#2e2430',
  },
  partitionRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  partitionChip: {
    paddingHorizontal: 16, minHeight: 36, borderRadius: 999,
    borderWidth: 1, borderColor: '#3a2f46', backgroundColor: '#1a141c',
    alignItems: 'center', justifyContent: 'center',
  },
  partitionChipActive: { borderColor: '#d4af37', backgroundColor: '#2d2410' },
  partitionText: { color: '#a89aa8', fontSize: 14 },
  partitionTextActive: { color: '#ffd700' },
  errorPill: {
    marginTop: 14, backgroundColor: '#3d1018', borderRadius: 10,
    borderWidth: 1, borderColor: '#ff4d6d', paddingHorizontal: 12,
    paddingVertical: 9,
  },
  errorText: { color: '#ff9aa8', fontSize: 13 },
  loginButton: {
    marginTop: 20, borderRadius: 999, minHeight: 52,
    backgroundColor: '#7a0d1f', borderWidth: 1, borderColor: '#ff4d6d',
    alignItems: 'center', justifyContent: 'center',
    shadowColor: '#ff4d6d', shadowOpacity: 0.35,
    shadowRadius: 10, elevation: 6,
  },
  loginButtonDisabled: { opacity: 0.55 },
  loginText: { color: '#ffe3e8', fontSize: 17, fontWeight: '700', letterSpacing: 4 },
  footer: {
    textAlign: 'center', color: '#6a5a6a', fontSize: 12,
    marginTop: 18, letterSpacing: 1,
  },
});
