import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, FlatList, Modal,
  StyleSheet, KeyboardAvoidingView, Platform,
} from 'react-native';
import { useGameStore } from '../store/useGameStore.js';
import { sendCommand } from '../api/mudApi.js';

/* 聊天室（对齐 Vue showChatRoom）：三频道轮询 + 服务端聊天API。
 * 打开时向游戏发 ui_select_room open 激活房间频道上下文（直接走
 * HTTP，不清空主画面feed），每2秒拉一次消息。 */
const CHANNELS = [
  { id: 'pub_channel', label: '公共' },
  { id: 'sales_channel', label: '交易' },
  { id: 'term_channel', label: '组队' },
];

export default function ChatRoomModal({ visible, onClose }) {
  const txd = useGameStore(s => s.txd);
  const apiBase = useGameStore(s => s.apiBase);
  const [channel, setChannel] = useState('pub_channel');
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);
  const listRef = useRef(null);
  const pollRef = useRef(null);
  const txdRef = useRef('');

  useEffect(() => { txdRef.current = txd || ''; }, [txd]);

  const load = useCallback(async () => {
    const currentTxd = txdRef.current;
    if (!currentTxd) return;
    try {
      const res = await fetch(
        `${apiBase}/api/chat/messages?txd=${encodeURIComponent(currentTxd)}` +
        `&channel=${encodeURIComponent(channel)}`);
      if (!res.ok) return;
      const data = await res.json();
      if (Array.isArray(data.messages) && data.messages.length) {
        setMessages(data.messages.slice(-80));
        requestAnimationFrame(() =>
          listRef.current && listRef.current.scrollToEnd &&
          listRef.current.scrollToEnd({ animated: false }));
      }
    } catch (e) { /* 网络抖动，下轮重试 */ }
  }, [apiBase, channel]);

  useEffect(() => {
    if (!visible) return undefined;
    setMessages([]);
    /* 激活服务端房间聊天上下文；回包可能轮换txd，必须回写store。 */
    const platform = Platform.OS === 'web' ? 'ios' : Platform.OS;
    sendCommand(txdRef.current, 'ui_select_room open', undefined, platform)
      .then(data => {
        if (data && data.txd && data.txd !== txdRef.current) {
          txdRef.current = data.txd;
          useGameStore.setState({ txd: data.txd });
        }
      }).catch(() => {});
    load();
    pollRef.current = setInterval(load, 2000);
    return () => clearInterval(pollRef.current);
  }, [visible, load]);

  const send = async () => {
    const message = input.trim();
    if (!message || sending) return;
    setSending(true);
    try {
      const res = await fetch(`${apiBase}/api/chat/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `txd=${encodeURIComponent(txdRef.current)}` +
          `&channel=${encodeURIComponent(channel)}` +
          `&message=${encodeURIComponent(message)}`,
      });
      if (res.ok) {
        setInput('');
        load();
      }
    } catch (e) { /* 失败保留输入，玩家可重发 */ } finally {
      setSending(false);
    }
  };

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose}>
      <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <View style={styles.header}>
          <Text style={styles.title}>💬 聊天室</Text>
          <TouchableOpacity onPress={onClose} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}>
            <Text style={styles.close}>✕ 收起</Text>
          </TouchableOpacity>
        </View>
        <View style={styles.channelRow}>
          {CHANNELS.map(ch => (
            <TouchableOpacity key={ch.id}
              style={[styles.channelChip, channel === ch.id && styles.channelChipOn]}
              onPress={() => setChannel(ch.id)}>
              <Text style={[styles.channelText,
                channel === ch.id && styles.channelTextOn]}>
                {ch.label}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
        <FlatList
          ref={listRef}
          style={styles.list}
          data={messages}
          keyExtractor={(item, index) => `chat-${index}`}
          ListEmptyComponent={
            <Text style={styles.empty}>暂无消息，说点什么吧～</Text>
          }
          renderItem={({ item }) => (
            <Text style={styles.message}>{String(item)}</Text>
          )}
        />
        <View style={styles.inputRow}>
          <TextInput
            style={styles.input}
            value={input}
            onChangeText={setInput}
            placeholder={`向${(CHANNELS.find(c => c.id === channel) || {}).label || ''}频道发言…`}
            placeholderTextColor="#6a5a6a"
            returnKeyType="send"
            onSubmitEditing={send}
          />
          <TouchableOpacity style={[styles.sendBtn, sending && { opacity: 0.5 }]}
            disabled={sending} onPress={send}>
            <Text style={styles.sendText}>{sending ? '…' : '发送'}</Text>
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#0d0b0e', paddingTop: 48 },
  header: {
    flexDirection: 'row', alignItems: 'center',
    justifyContent: 'space-between', paddingHorizontal: 16, paddingVertical: 10,
    borderBottomWidth: 1, borderBottomColor: '#2e2430',
  },
  title: { color: '#ffd700', fontSize: 17, fontWeight: '800' },
  close: { color: '#a89aa8', fontSize: 14 },
  channelRow: {
    flexDirection: 'row', gap: 8, paddingHorizontal: 12, paddingVertical: 8,
  },
  channelChip: {
    paddingHorizontal: 14, paddingVertical: 5, borderRadius: 999,
    borderWidth: 1, borderColor: '#3a2f46', backgroundColor: '#1a141c',
  },
  channelChipOn: { borderColor: '#d4af37', backgroundColor: '#2d2410' },
  channelText: { color: '#c8b8c8', fontSize: 12 },
  channelTextOn: { color: '#ffd700', fontSize: 12, fontWeight: '700' },
  list: { flex: 1, paddingHorizontal: 14 },
  empty: { color: '#6a5a6a', textAlign: 'center', paddingTop: 60, fontSize: 13 },
  message: { color: '#d8ccb8', fontSize: 13, lineHeight: 21, paddingVertical: 3 },
  inputRow: {
    flexDirection: 'row', gap: 8, padding: 10,
    borderTopWidth: 1, borderTopColor: '#2e2430',
  },
  input: {
    flex: 1, borderWidth: 1, borderColor: '#3a2f46', borderRadius: 10,
    backgroundColor: '#14101a', color: '#e8dcc8', fontSize: 14,
    paddingHorizontal: 12, paddingVertical: 8,
  },
  sendBtn: {
    borderRadius: 10, borderWidth: 1, borderColor: '#d4af37',
    backgroundColor: '#2d2410', paddingHorizontal: 18,
    alignItems: 'center', justifyContent: 'center',
  },
  sendText: { color: '#ffd700', fontSize: 14, fontWeight: '700' },
});
