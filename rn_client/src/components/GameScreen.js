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
        <Text style={styles.topName} numberOfLines={1}>
          {status.name_cn || store.userid || '仙道'}
        </Text>
        {!!status.hp && (
          <Text style={styles.topStats}>
            HP {status.hp}/{status.hp_max}
          </Text>
        )}
        <TouchableOpacity
          style={[styles.afkButton,
            store.autofighting && styles.afkButtonOn]}
          onPress={() => store.toggleAutofight()}>
          <Text style={styles.afkText}>
            {store.autofighting ? '挂机中·停止' : '开始挂机'}
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.logoutButton} onPress={() => store.logout()}>
          <Text style={styles.logoutText}>退出</Text>
        </TouchableOpacity>
      </View>

      {store.inBattle && store.battle && store.battle.enemy && (
        <View style={styles.enemyBar}>
          <Text style={styles.enemyName} numberOfLines={1}>
            {store.battle.enemy.name_cn || '敌人'}
          </Text>
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
    flexDirection: 'row', alignItems: 'center', gap: 8,
    paddingTop: 54, paddingHorizontal: 12, paddingBottom: 8,
    backgroundColor: '#14101a', borderBottomWidth: 1, borderBottomColor: '#2e2430',
  },
  topName: { flex: 1, color: '#f0e6d2', fontSize: 15, fontWeight: '600' },
  topStats: { color: '#a89aa8', fontSize: 12 },
  afkButton: {
    paddingHorizontal: 12, paddingVertical: 6, borderRadius: 999,
    borderWidth: 1, borderColor: '#6a8a5a',
  },
  afkButtonOn: { backgroundColor: '#2d5243', borderColor: '#7ad08a' },
  afkText: { color: '#c8e8c8', fontSize: 12 },
  logoutButton: {
    paddingHorizontal: 10, paddingVertical: 6, borderRadius: 999,
    borderWidth: 1, borderColor: '#5a3a46',
  },
  logoutText: { color: '#c8a8b8', fontSize: 12 },
  enemyBar: {
    paddingHorizontal: 12, paddingVertical: 6, backgroundColor: '#1a1016',
    borderBottomWidth: 1, borderBottomColor: '#2e2430',
  },
  enemyName: { color: '#ff9aa8', fontSize: 12, marginBottom: 4 },
  hpTrack: {
    height: 8, borderRadius: 4, backgroundColor: '#2a1a20', overflow: 'hidden',
  },
  hpFill: { height: 8, borderRadius: 4 },
  feed: { flex: 1, paddingHorizontal: 10 },
  line: {
    paddingVertical: 4, flexDirection: 'row', flexWrap: 'wrap',
    alignItems: 'center', gap: 4,
  },
  text: { color: '#f0e6d2', fontSize: 14, lineHeight: 20, flexShrink: 1 },
  button: {
    paddingHorizontal: 10, paddingVertical: 5, borderRadius: 8,
    borderWidth: 1, marginVertical: 2,
  },
  buttonText: { fontSize: 13 },
  inlineInput: {
    backgroundColor: '#1a141c', borderRadius: 8, paddingHorizontal: 10,
    paddingVertical: 5, color: '#f0e6d2', fontSize: 13,
    borderWidth: 1, borderColor: '#3a2f46', minWidth: 120,
  },
  image: { width: 72, height: 72, borderRadius: 8, marginVertical: 4 },
  error: { color: '#ff6b8a', fontSize: 11, paddingHorizontal: 12 },
  commandBar: {
    flexDirection: 'row', gap: 8, padding: 10,
    borderTopWidth: 1, borderTopColor: '#2e2430', backgroundColor: '#14101a',
  },
  commandInput: {
    flex: 1, backgroundColor: '#1a141c', borderRadius: 10,
    paddingHorizontal: 12, paddingVertical: 9, color: '#f0e6d2', fontSize: 14,
    borderWidth: 1, borderColor: '#2e2430',
  },
  sendButton: {
    paddingHorizontal: 18, borderRadius: 10, backgroundColor: '#3a2f46',
    alignItems: 'center', justifyContent: 'center',
  },
  sendText: { color: '#f0e6d2', fontSize: 14 },
});
