import React, { useEffect, useRef, useState } from 'react';
import {
  View, Text, FlatList, TextInput, TouchableOpacity,
  Image, StyleSheet, KeyboardAvoidingView, Platform,
} from 'react-native';
import { useGameStore } from '../store/useGameStore.js';
import {
  flattenTextParts, buttonStyleFor, resolveImageUrl, buildInputCommand,
} from '../utils/segments.js';

export default function GameScreen() {
  const store = useGameStore();
  const listRef = useRef(null);
  const [draft, setDraft] = useState('');
  const [inputValues, setInputValues] = useState({});

  useEffect(() => {
    const statusTimer = setInterval(() => store.refreshStatus(), 5000);
    return () => clearInterval(statusTimer);
  }, []);

  useEffect(() => {
    const battleTimer = setInterval(() => {
      if (useGameStore.getState().inBattle) store.refreshBattle();
    }, 3000);
    return () => clearInterval(battleTimer);
  }, []);

  useEffect(() => {
    if (listRef.current) {
      setTimeout(() => listRef.current.scrollToEnd({ animated: false }), 50);
    }
  }, [store.lines.length]);

  const send = cmd => {
    if (!cmd) return;
    setDraft('');
    store.command(cmd.trim());
  };

  const status = store.status || {};

  return (
    <KeyboardAvoidingView
      style={styles.screen}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={0}>
      <View style={styles.topBar}>
        <View style={styles.topRow}>
          <Text style={styles.topName} numberOfLines={1}>
            {status.name_cn || store.userid || '仙道'}
          </Text>
          <TouchableOpacity
            style={styles.logoutButton} onPress={() => store.logout()}>
            <Text style={styles.logoutText}>退出</Text>
          </TouchableOpacity>
        </View>
        <View style={styles.topRow}>
          <View style={styles.hpTrackSmall}>
            <View style={[styles.hpFillSmall, {
              width: `${Math.max(0, Math.min(100,
                ((status.hp || 0) / Math.max(1, status.hp_max || 1)) * 100))}%`,
            }]} />
          </View>
          <Text style={styles.hpNumbers}>
            {(status.hp || 0)}/{status.hp_max || 0}
          </Text>
          <TouchableOpacity
            style={[styles.afkButton,
              store.autofighting && styles.afkButtonOn]}
            onPress={() => store.toggleAutofight()}>
            <Text style={styles.afkText}>
              {store.autofighting ? '◎ 挂机中·停止' : '▶ 开始挂机'}
            </Text>
          </TouchableOpacity>
        </View>
      </View>

      {store.inBattle && store.battle && store.battle.enemy && (
        <View style={styles.enemyBar}>
          <View style={styles.enemyRow}>
            <Text style={styles.enemyName} numberOfLines={1}>
              ⚔ {store.battle.enemy.name_cn || '敌人'}
            </Text>
            <Text style={styles.enemyHp}>
              {store.battle.enemy.hp}/{store.battle.enemy.hp_max}
            </Text>
          </View>
          <View style={styles.hpTrack}>
            <View style={[styles.hpFill, {
              width: `${Math.max(0, Math.min(100,
                (store.battle.enemy.hp / Math.max(1, store.battle.enemy.hp_max)) * 100))}%`,
              backgroundColor: '#c23a4a',
            }]} />
          </View>
        </View>
      )}

      <FlatList
        ref={listRef}
        style={styles.feed}
        data={store.lines}
        keyExtractor={(item, index) => String(index)}
        renderItem={({ item }) => (
          <View style={styles.line}>
            {renderSegments(item, {
              send, inputValues, setInputValues, apiBase: store.apiBase,
            })}
          </View>
        )}
      />

      {!!store.error && <Text style={styles.error}>{store.error}</Text>}

      <View style={styles.commandBar}>
        <TextInput
          style={styles.commandInput}
          value={draft}
          onChangeText={setDraft}
          onSubmitEditing={() => send(draft)}
          returnKeyType="send"
          placeholder="输入命令或对话…"
          placeholderTextColor="#6a5a6a"
        />
        <TouchableOpacity style={styles.sendButton} onPress={() => send(draft)}>
          <Text style={styles.sendText}>发送</Text>
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
}

function renderSegments(line, ctx) {
  const segments = (line && line.segments) || [];
  return segments.map((segment, index) => {
    if (!segment || !segment.type) return null;
    if (segment.type === 'text') {
      const units = flattenTextParts(segment.parts);
      return (
        <Text key={index} style={styles.text}>
          {units.map((unit, unitIndex) => (
            <Text
              key={unitIndex}
              style={{ color: unit.color, fontWeight: unit.bold ? '700' : '400' }}>
              {unit.text}
            </Text>
          ))}
        </Text>
      );
    }
    if (segment.type === 'button') {
      const style = buttonStyleFor(segment);
      return (
        <TouchableOpacity
          key={index}
          style={[styles.button, {
            backgroundColor: style.bg, borderColor: style.border,
          }]}
          onPress={() => ctx.send(segment.cmd)}>
          <Text style={[styles.buttonText, { color: style.color }]}>
            {segment.label}
          </Text>
        </TouchableOpacity>
      );
    }
    if (segment.type === 'cmd-input' || segment.type === 'input') {
      const key = `input-${index}`;
      const value = ctx.inputValues[key] ??
        String(segment.default || '');
      return (
        <TextInput
          key={index}
          style={styles.inlineInput}
          value={value}
          onChangeText={text =>
            ctx.setInputValues({ ...ctx.inputValues, [key]: text })}
          onSubmitEditing={() => {
            const cmd = buildInputCommand(segment, value);
            if (cmd) ctx.send(cmd);
          }}
          placeholder={segment.name || '输入'}
          placeholderTextColor="#6a5a6a"
          returnKeyType="send"
        />
      );
    }
    if (segment.type === 'image') {
      const uri = resolveImageUrl(ctx.apiBase, segment.src);
      if (!uri) return null;
      return (
        <Image key={index} source={{ uri }}
          style={styles.image} resizeMode="contain" />
      );
    }
    return null;
  });
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#0d0b0e' },
  topBar: {
    paddingHorizontal: 12, paddingTop: 10, paddingBottom: 8, gap: 7,
    backgroundColor: '#14101a', borderBottomWidth: 1, borderBottomColor: '#2e2430',
  },
  topRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  topName: { flex: 1, color: '#f0e6d2', fontSize: 16, fontWeight: '700' },
  hpTrackSmall: {
    flex: 1, height: 10, borderRadius: 5,
    backgroundColor: '#2a1a20', overflow: 'hidden',
  },
  hpFillSmall: {
    height: 10, borderRadius: 5,
    backgroundColor: '#3f8a53',
  },
  hpNumbers: { color: '#a89aa8', fontSize: 12, minWidth: 76, textAlign: 'right' },
  afkButton: {
    paddingHorizontal: 13, minHeight: 32, borderRadius: 999,
    borderWidth: 1, borderColor: '#6a8a5a',
    alignItems: 'center', justifyContent: 'center',
  },
  afkButtonOn: { backgroundColor: '#2d5243', borderColor: '#7ad08a' },
  afkText: { color: '#c8e8c8', fontSize: 13 },
  logoutButton: {
    paddingHorizontal: 11, minHeight: 30, borderRadius: 999,
    borderWidth: 1, borderColor: '#5a3a46',
    alignItems: 'center', justifyContent: 'center',
  },
  logoutText: { color: '#c8a8b8', fontSize: 12 },
  enemyBar: {
    paddingHorizontal: 12, paddingVertical: 8, backgroundColor: '#1a1016',
    borderBottomWidth: 1, borderBottomColor: '#2e2430',
  },
  enemyRow: {
    flexDirection: 'row', alignItems: 'center',
    justifyContent: 'space-between', marginBottom: 5,
  },
  enemyName: { flexShrink: 1, color: '#ff9aa8', fontSize: 14, fontWeight: '600' },
  enemyHp: { color: '#c8a8b8', fontSize: 12 },
  hpTrack: {
    height: 12, borderRadius: 6, backgroundColor: '#2a1a20', overflow: 'hidden',
  },
  hpFill: { height: 12, borderRadius: 6 },
  feed: { flex: 1, paddingHorizontal: 10 },
  line: {
    paddingVertical: 4, flexDirection: 'row', flexWrap: 'wrap',
    alignItems: 'center', gap: 5,
  },
  text: { color: '#f0e6d2', fontSize: 15, lineHeight: 22, flexShrink: 1 },
  button: {
    paddingHorizontal: 11, minHeight: 32, borderRadius: 9,
    borderWidth: 1, marginVertical: 3,
    alignItems: 'center', justifyContent: 'center',
  },
  buttonText: { fontSize: 14 },
  inlineInput: {
    backgroundColor: '#1a141c', borderRadius: 8, paddingHorizontal: 10,
    paddingVertical: 6, color: '#f0e6d2', fontSize: 14,
    borderWidth: 1, borderColor: '#3a2f46', minWidth: 130, minHeight: 34,
  },
  image: { width: 76, height: 76, borderRadius: 10, marginVertical: 4 },
  error: { color: '#ff6b8a', fontSize: 12, paddingHorizontal: 12 },
  commandBar: {
    flexDirection: 'row', gap: 8, padding: 10,
    borderTopWidth: 1, borderTopColor: '#2e2430', backgroundColor: '#14101a',
  },
  commandInput: {
    flex: 1, backgroundColor: '#1a141c', borderRadius: 11,
    paddingHorizontal: 13, paddingVertical: 10, minHeight: 46,
    color: '#f0e6d2', fontSize: 15,
    borderWidth: 1, borderColor: '#2e2430',
  },
  sendButton: {
    paddingHorizontal: 20, borderRadius: 11, backgroundColor: '#3a2f46',
    alignItems: 'center', justifyContent: 'center',
  },
  sendText: { color: '#f0e6d2', fontSize: 15, fontWeight: '600' },
});
