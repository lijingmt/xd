import React, { useEffect, useState } from 'react';
import {
  View, Text, FlatList, TouchableOpacity,
  StyleSheet, RefreshControl,
} from 'react-native';
import { useGameStore } from '../store/useGameStore.js';
import CharacterCreateModal from './CharacterCreateModal.js';

function realmLabel(card) {
  return card.realmType === 'illusion'
    ? `幻境${card.illusionId ? '·' + card.illusionId : ''}`
    : '永恒服';
}

export default function CharacterScreen() {
  const {
    accountId, accountCharacters, characterLimit, busy, error,
    pickCharacter, refreshAccountCharacters, logout,
  } = useGameStore();
  const [createOpen, setCreateOpen] = useState(false);

  useEffect(() => {
    refreshAccountCharacters().catch(() => {});
  }, []);

  const slotsFull = characterLimit > 0 &&
    accountCharacters.length >= characterLimit;

  return (
    <View style={styles.screen}>
      <View style={styles.header}>
        <View style={{ flex: 1 }}>
          <Text style={styles.headerTitle}>选择角色</Text>
          <Text style={styles.headerSub}>
            账号 {accountId} · 角色 {accountCharacters.length}/{characterLimit || '∞'}
          </Text>
        </View>
        {!slotsFull && (
          <TouchableOpacity style={styles.addButton}
            onPress={() => setCreateOpen(true)}>
            <Text style={styles.addText}>＋ 新建</Text>
          </TouchableOpacity>
        )}
        <TouchableOpacity style={styles.exitButton} onPress={() => logout()}>
          <Text style={styles.exitText}>退出账号</Text>
        </TouchableOpacity>
      </View>

      {!!error && <Text style={styles.error}>{error}</Text>}

      <CharacterCreateModal
        visible={createOpen}
        onClose={() => setCreateOpen(false)}
      />

      <FlatList
        style={styles.list}
        contentContainerStyle={{ padding: 16, gap: 10 }}
        data={accountCharacters}
        keyExtractor={item => item.id}
        refreshControl={
          <RefreshControl
            refreshing={busy}
            onRefresh={() => refreshAccountCharacters().catch(() => {})}
            tintColor="#a89aa8"
          />
        }
        renderItem={({ item }) => (
          <TouchableOpacity
            style={[styles.card, !item.available && styles.cardDisabled]}
            disabled={busy || !item.available}
            onPress={() => pickCharacter(item.id)}>
            <View style={styles.cardTop}>
              <Text style={styles.cardName} numberOfLines={1}>
                {item.name}
              </Text>
              {item.isDefault && <Text style={styles.defaultBadge}>本命</Text>}
              <Text style={[styles.realmBadge,
                item.realmType === 'illusion'
                  ? styles.realmIllusion : styles.realmEternal]}>
                {realmLabel(item)}
              </Text>
            </View>
            <Text style={styles.cardMeta}>
              {item.profession}{item.race ? ' · ' + item.race : ''} · Lv.{item.level}
            </Text>
          </TouchableOpacity>
        )}
        ListEmptyComponent={
          !busy ? <Text style={styles.empty}>账号下暂无可用角色</Text> : null
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#0d0b0e', paddingTop: 54 },
  header: {
    flexDirection: 'row', alignItems: 'center', gap: 10,
    paddingHorizontal: 16, paddingVertical: 10,
    borderBottomWidth: 1, borderBottomColor: '#2e2430', backgroundColor: '#14101a',
  },
  headerTitle: { color: '#f0e6d2', fontSize: 17, fontWeight: '700' },
  headerSub: { color: '#8a7a8a', fontSize: 11, marginTop: 2 },
  exitButton: {
    paddingHorizontal: 12, paddingVertical: 6, borderRadius: 999,
    borderWidth: 1, borderColor: '#5a3a46',
  },
  addButton: {
    paddingHorizontal: 12, paddingVertical: 6, borderRadius: 999,
    borderWidth: 1, borderColor: '#6a8a5a',
  },
  addText: { color: '#c8e8c8', fontSize: 12 },
  exitText: { color: '#c8a8b8', fontSize: 12 },
  list: { flex: 1 },
  card: {
    backgroundColor: '#1a141c', borderRadius: 12, padding: 14,
    borderWidth: 1, borderColor: '#3a2f46',
  },
  cardDisabled: { opacity: 0.45 },
  cardTop: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  cardName: { flex: 1, color: '#f0e6d2', fontSize: 16, fontWeight: '600' },
  defaultBadge: {
    color: '#ffd700', fontSize: 10, borderWidth: 1,
    borderColor: '#8a6d2f', borderRadius: 4, paddingHorizontal: 5,
    paddingVertical: 1, overflow: 'hidden',
  },
  realmBadge: { fontSize: 10, paddingHorizontal: 6, overflow: 'hidden' },
  realmEternal: { color: '#9ab8d8' },
  realmIllusion: { color: '#d8a8e0' },
  cardMeta: { color: '#a89aa8', fontSize: 12, marginTop: 6 },
  error: { color: '#ff6b8a', fontSize: 12, paddingHorizontal: 16, paddingTop: 8 },
  empty: { color: '#8a7a8a', textAlign: 'center', marginTop: 40 },
});
