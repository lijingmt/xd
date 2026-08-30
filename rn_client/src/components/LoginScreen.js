import React, { useEffect, useRef, useState } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, StyleSheet,
  ScrollView, ActivityIndicator,
} from 'react-native';
import { useGameStore } from '../store/useGameStore.js';
import * as api from '../api/mudApi.js';
import { WAN_API_BASE, LAN_API_BASE } from '../api/mudApi.js';
import { validateRegisterForm } from '../utils/registerForm.js';
import {
  loadSavedAccounts, removeSavedAccount,
} from '../utils/savedAccounts.js';

export default function LoginScreen() {
  const {
    partitions, loadPartitions, login, busy, error, apiBase, setApiBase,
  } = useGameStore();
  const [partition, setPartition] = useState('');
  const [userid, setUserid] = useState('');
  const [password, setPassword] = useState('');
  const [mode, setMode] = useState('login'); /* login|register */
  const [confirm, setConfirm] = useState('');
  const [regBusy, setRegBusy] = useState(false);
  const [regDone, setRegDone] = useState(false);
  const [savedAccounts, setSavedAccounts] = useState([]);
  /* 测试服彩蛋：连点Logo 5次解锁（3秒内），正式版玩家不可见。 */
  const [devUnlock, setDevUnlock] = useState(false);
  const logoTapsRef = useRef({ count: 0, first: 0 });
  const tapLogo = () => {
    const now = Date.now();
    const state = logoTapsRef.current;
    if (now - state.first > 3000) {
      state.count = 0;
      state.first = now;
    }
    state.count += 1;
    if (state.count >= 5) {
      state.count = 0;
      setDevUnlock(true);
    }
  };

  const register = async () => {
    const problem = validateRegisterForm(
      { partition, userid, password, confirm });
    if (problem) {
      useGameStore.setState({ error: problem });
      return;
    }
    setRegBusy(true);
    useGameStore.setState({ error: '' });
    try {
      const challenge = await api.fetchChallenge();
      const result = await api.registerAccount(
        `${partition}${userid.trim()}`, password, 'rnreg', challenge);
      if (!result.ok) {
        useGameStore.setState({
          error: /已存在|重复/.test(result.text)
            ? '该账号已被注册' : '注册失败，请稍后再试',
        });
      } else {
        setRegDone(true);
        useGameStore.setState({
          error: '注册成功，直接点击「进入仙道wapmud」登录',
        });
        /* 注册即转登录：账号密码已填好，一键进游。 */
        setTimeout(() => {
          setMode('login');
          setRegDone(false);
          setConfirm('');
        }, 1200);
      }
    } catch (e) {
      useGameStore.setState({ error: `注册失败: ${e.message}` });
    } finally {
      setRegBusy(false);
    }
  };

  useEffect(() => {
    loadPartitions().then(list => {
      const open = (list || []).filter(p => p.login_open !== 0);
      if (open.length && !partition) setPartition(open[0].value);
    });
    loadSavedAccounts().then(setSavedAccounts);
  }, []);

  /* 一键登录：填充分区/账号/密码（含服务器）并直接提交。 */
  const quickLogin = entry => {
    if (busy || !entry) return;
    if (entry.partition) setPartition(entry.partition);
    setUserid(String(entry.userid || '').replace(
      new RegExp(`^${entry.partition || ''}`), ''));
    setPassword(entry.password || '');
    if (entry.apiBase) setApiBase(entry.apiBase);
    const part = entry.partition || partition;
    login(part, String(entry.userid || '').replace(
      new RegExp(`^${part}`), ''), entry.password || '');
  };

  const openPartitions = (partitions || []).filter(p => p.login_open !== 0);

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.container}>
      <TouchableOpacity style={styles.brandGlow} activeOpacity={0.9}
        onPress={tapLogo} disabled={devUnlock}>
        <View style={styles.brandMark}>
          <Text style={styles.brandText}>仙</Text>
        </View>
      </TouchableOpacity>
      <Text style={styles.title}>仙道wapmud</Text>
      <Text style={styles.subtitle}>东方幻想 · 十职同行</Text>
      <Text style={styles.kicker}>原生客户端 · 挂机不占屏</Text>

      <View style={styles.card}>
        <Text style={styles.label}>服务器</Text>
        <View style={styles.serverPresetRow}>
          <TouchableOpacity
            style={[styles.presetChip,
              apiBase === WAN_API_BASE && styles.presetChipActive]}
            onPress={() => setApiBase(WAN_API_BASE)}>
            <Text style={[styles.presetText,
              apiBase === WAN_API_BASE && styles.presetTextActive]}>
              🌐 主服务器
            </Text>
          </TouchableOpacity>
          {devUnlock && (
            <TouchableOpacity
              style={[styles.presetChip,
                apiBase === LAN_API_BASE && styles.presetChipActive]}
              onPress={() => setApiBase(LAN_API_BASE)}>
              <Text style={[styles.presetText,
                apiBase === LAN_API_BASE && styles.presetTextActive]}>
                🧪 测试
              </Text>
            </TouchableOpacity>
          )}
        </View>
        {devUnlock && (
          <TextInput
            style={styles.input}
            value={apiBase}
            onChangeText={setApiBase}
            autoCapitalize="none"
            autoCorrect={false}
            placeholder="https://… 或 http://192.168.x.x:8888"
            placeholderTextColor="#6a5a6a"
          />
        )}

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
        {mode === 'register' && (
          <>
            <Text style={styles.label}>确认密码</Text>
            <TextInput
              style={styles.input}
              value={confirm}
              onChangeText={setConfirm}
              secureTextEntry
              placeholder="再输入一次密码"
              placeholderTextColor="#6a5a6a"
            />
          </>
        )}

        {!!error && (
          <View style={styles.errorPill}>
            <Text style={styles.errorText}>{error}</Text>
          </View>
        )}

        {mode === 'login' ? (
          <TouchableOpacity
            style={[styles.loginButton,
              (busy || !partition || !userid || !password) &&
                styles.loginButtonDisabled]}
            disabled={busy || !partition || !userid || !password}
            onPress={() => login(partition, userid.trim(), password)}>
            {busy
              ? <ActivityIndicator color="#ffe3e8" size="small" />
              : <Text style={styles.loginText}>进入仙道wapmud</Text>}
          </TouchableOpacity>
        ) : (
          <TouchableOpacity
            style={[styles.loginButton,
              (regBusy || regDone) && styles.loginButtonDisabled]}
            disabled={regBusy || regDone}
            onPress={register}>
            {regBusy
              ? <ActivityIndicator color="#ffe3e8" size="small" />
              : <Text style={styles.loginText}>
                  {regDone ? '✓ 注册成功' : '注册账号'}
                </Text>}
          </TouchableOpacity>
        )}
        <TouchableOpacity
          style={styles.switchRow}
          onPress={() => {
            setMode(mode === 'login' ? 'register' : 'login');
            setRegDone(false);
            setConfirm('');
            useGameStore.setState({ error: '' });
          }}>
          <Text style={styles.switchText}>
            {mode === 'login' ? '没有账号？注册新账号 →' : '← 已有账号，直接登录'}
          </Text>
        </TouchableOpacity>
      </View>

      {mode === 'login' && savedAccounts.length > 0 && (
        <View style={styles.savedCard}>
          <Text style={styles.savedTitle}>快速登录</Text>
          {savedAccounts.map(entry => (
            <View key={entry.userid} style={styles.savedRow}>
              <TouchableOpacity style={styles.savedChip}
                activeOpacity={0.7} disabled={busy}
                onPress={() => quickLogin(entry)}>
                <View style={styles.savedAvatar}>
                  <Text style={styles.savedAvatarText}>
                    {entry.userid.slice(-1)}
                  </Text>
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={styles.savedName} numberOfLines={1}>
                    {entry.userid}
                  </Text>
                  <Text style={styles.savedMeta} numberOfLines={1}>
                    {entry.apiBase === LAN_API_BASE ? '测试服' : '主服'} · 一键进入
                  </Text>
                </View>
                <Text style={styles.savedGo}>→</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.savedRemove}
                onPress={async () => {
                  setSavedAccounts(await removeSavedAccount(entry.userid));
                }}>
                <Text style={styles.savedRemoveText}>✕</Text>
              </TouchableOpacity>
            </View>
          ))}
          <Text style={styles.savedNote}>
            账号密码只保存在本设备，✕ 可删除记录
          </Text>
        </View>
      )}

      <Text style={styles.footer}>挂机在服务器持续运行 · 关闭客户端也不停</Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#0d0b0e' },
  savedCard: {
    marginTop: 14, backgroundColor: '#14101a', borderRadius: 14,
    borderWidth: 1, borderColor: '#2e2430', padding: 12, gap: 8,
  },
  savedTitle: {
    color: '#8a7a8a', fontSize: 11, fontWeight: '700',
    letterSpacing: 1,
  },
  savedRow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  savedChip: {
    flex: 1, flexDirection: 'row', alignItems: 'center', gap: 10,
    backgroundColor: '#1a1522', borderRadius: 10,
    borderWidth: 1, borderColor: '#3a2f46', padding: 9,
  },
  savedAvatar: {
    width: 36, height: 36, borderRadius: 18, backgroundColor: '#231b10',
    borderWidth: 1, borderColor: '#8a6d2f', alignItems: 'center',
    justifyContent: 'center',
  },
  savedAvatarText: { color: '#d4af37', fontSize: 16, fontWeight: '700' },
  savedName: { color: '#f0e6d2', fontSize: 13, fontWeight: '600' },
  savedMeta: { color: '#6a5a6a', fontSize: 10, marginTop: 1 },
  savedGo: { color: '#d4af37', fontSize: 16 },
  savedRemove: {
    width: 30, height: 30, alignItems: 'center', justifyContent: 'center',
  },
  savedRemoveText: { color: '#6a5a6a', fontSize: 14 },
  savedNote: { color: '#5a4a5a', fontSize: 10, textAlign: 'center' },
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
  serverPresetRow: { flexDirection: 'row', gap: 8, marginBottom: 8 },
  presetChip: {
    paddingHorizontal: 14, minHeight: 32, borderRadius: 999,
    borderWidth: 1, borderColor: '#3a2f46', backgroundColor: '#1a141c',
    alignItems: 'center', justifyContent: 'center',
  },
  presetChipActive: { borderColor: '#d4af37', backgroundColor: '#2d2410' },
  presetText: { color: '#a89aa8', fontSize: 13 },
  presetTextActive: { color: '#ffd700' },
  partitionChip: {
    paddingHorizontal: 16, minHeight: 36, borderRadius: 999,
    borderWidth: 1, borderColor: '#3a2f46', backgroundColor: '#1a141c',
    alignItems: 'center', justifyContent: 'center',
  },
  partitionChipActive: { borderColor: '#d4af37', backgroundColor: '#2d2410' },
  partitionText: { color: '#a89aa8', fontSize: 14 },
  partitionTextActive: { color: '#ffd700' },
  switchRow: {
    alignItems: 'center', paddingVertical: 12, marginTop: 2,
  },
  switchText: { color: '#9ab8d8', fontSize: 13 },
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
