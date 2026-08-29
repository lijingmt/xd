import React, { useEffect, useState } from 'react';
import {
  View, Text, FlatList, TouchableOpacity,
  StyleSheet, RefreshControl, ActivityIndicator,
} from 'react-native';
import { useGameStore } from '../store/useGameStore.js';
import { sessionSummary } from '../utils/parallelAfk.js';
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
    sessions, parallelLimit, toggleCharacterAfk, closeCharacterSession,
    tickBackgroundPolls,
  } = useGameStore();
  const [createOpen, setCreateOpen] = useState(false);

  useEffect(() => {
    refreshAccountCharacters().catch(() => {});
  }, []);

  /* 仪表盘期间继续刷新后台并行角色的快照（挂机由服务端tick保活）。 */
  useEffect(() => {
    const timer = setInterval(() => {
      useGameStore.getState().tickBackgroundPolls();
    }, 5000);
    return () => clearInterval(timer);
  }, []);

  const slotsFull = characterLimit > 0 &&
    accountCharacters.length >= characterLimit;
  const parallelCount = Object.keys(sessions || {}).length;

  return (
    <View style={styles.screen}>
      <View style={styles.header}>
        <View style={{ flex: 1 }}>
          <Text style={styles.headerTitle}>选择角色</Text>
          <Text style={styles.headerSub} numberOfLines={1}>
            {accountId} · {accountCharacters.length}/{characterLimit || '∞'}
            {parallelCount > 0 &&
              ` · 并行挂机 ${parallelCount}/${parallelLimit}`}
          </Text>
        </View>
        {!slotsFull && (
          <TouchableOpacity style={styles.addButton}
            onPress={() => setCreateOpen(true)}>
            <Text style={styles.addText}>＋ 新建角色</Text>
          </TouchableOpacity>
        )}
        <TouchableOpacity style={styles.exitButton} onPress={() => logout()}>
          <Text style={styles.exitText}>退出</Text>
        </TouchableOpacity>
      </View>

      {!!error && (
        <View style={styles.errorPill}>
          <Text style={styles.errorText}>{error}</Text>
        </View>
      )}

      <CharacterCreateModal
        visible={createOpen}
        onClose={() => setCreateOpen(false)}
      />

      <FlatList
        style={styles.list}
        contentContainerStyle={{ padding: 16, gap: 12, paddingBottom: 32 }}
        data={accountCharacters}
        keyExtractor={item => item.id}
        refreshControl={
          <RefreshControl
            refreshing={busy}
            onRefresh={() => refreshAccountCharacters().catch(() => {})}
            tintColor="#a89aa8"
          />
        }
        renderItem={({ item }) => {
          const session = (sessions || {})[item.id];
          const summary = sessionSummary(session, item);
          const sessionBusy = !!(session && session.afkBusy);
          return (
            <View style={[styles.card, !item.available && styles.cardDisabled]}>
              <TouchableOpacity style={styles.cardMain}
                disabled={busy || !item.available}
                onPress={() => pickCharacter(item.id)}>
                <View style={styles.accentBar} />
                <View style={{ flex: 1 }}>
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
                  <Text style={styles.cardMeta} numberOfLines={1}>
                    {item.profession}{item.race ? ' · ' + item.race : ''}
                  </Text>
                  {summary.online && (
                    <Text style={styles.liveMeta} numberOfLines={1}>
                      {summary.autofighting ? '◎ 挂机中' : '◌ 在线'}
                      {summary.inBattle ? ' · 战斗中' : ''}
                      {summary.hpPercent != null
                        ? ` · 生命${summary.hpPercent}%` : ''}
                    </Text>
                  )}
                </View>
                <View style={styles.levelPill}>
                  <Text style={styles.levelText}>
                    Lv.{summary.online ? summary.level : item.level}
                  </Text>
                </View>
              </TouchableOpacity>
              {item.available && (
                <View style={styles.cardActions}>
                  {summary.online && (
                    <TouchableOpacity style={styles.sessionClose}
                      onPress={() => closeCharacterSession(item.id)}>
                      <Text style={styles.sessionCloseText}>✕</Text>
                    </TouchableOpacity>
                  )}
                  <TouchableOpacity
                    style={[styles.afkToggle,
                      summary.autofighting && styles.afkToggleOn,
                      !summary.online && styles.afkToggleNew]}
                    disabled={sessionBusy}
                    onPress={() => toggleCharacterAfk(item.id)}>
                    {sessionBusy
                      ? <ActivityIndicator size="small" color="#c8e8c8" />
                      : <Text style={styles.afkToggleText}>
                          {summary.online
                            ? (summary.autofighting ? '停挂机' : '开挂机')
                            : '后台挂机'}
                        </Text>}
                  </TouchableOpacity>
                  <TouchableOpacity style={styles.enterButton}
                    disabled={busy}
                    onPress={() => pickCharacter(item.id)}>
                    <Text style={styles.enterText}>
                      {summary.online ? '切换' : '多开'}
                    </Text>
                  </TouchableOpacity>
                </View>
              )}
            </View>
          );
        }}
        ListEmptyComponent={
          !busy ? (
            <View style={styles.emptyWrap}>
              <Text style={styles.emptyIcon}>⛩️</Text>
              <Text style={styles.empty}>账号下暂无可用角色</Text>
              <Text style={styles.emptyHint}>点击右上「＋ 新建角色」开始修仙</Text>
            </View>
          ) : null
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#0d0b0e' },
  header: {
    flexDirection: 'row', alignItems: 'center', gap: 10,
    paddingHorizontal: 16, paddingVertical: 12,
    borderBottomWidth: 1, borderBottomColor: '#2e2430',
    backgroundColor: '#14101a',
  },
  headerTitle: { color: '#f0e6d2', fontSize: 19, fontWeight: '700' },
  headerSub: { color: '#8a7a8a', fontSize: 12, marginTop: 3 },
  addButton: {
    paddingHorizontal: 13, minHeight: 34, borderRadius: 999,
    borderWidth: 1, borderColor: '#6a8a5a', backgroundColor: '#16241c',
    alignItems: 'center', justifyContent: 'center',
  },
  addText: { color: '#9ad0a0', fontSize: 13 },
  exitButton: {
    paddingHorizontal: 12, minHeight: 34, borderRadius: 999,
    borderWidth: 1, borderColor: '#5a3a46',
    alignItems: 'center', justifyContent: 'center',
  },
  exitText: { color: '#c8a8b8', fontSize: 13 },
  list: { flex: 1 },
  card: {
    backgroundColor: '#17131c', borderRadius: 14,
    borderWidth: 1, borderColor: '#3a2f46', overflow: 'hidden',
  },
  cardDisabled: { opacity: 0.45 },
  cardMain: {
    flexDirection: 'row', alignItems: 'center',
    paddingVertical: 14, paddingRight: 14, paddingLeft: 0, gap: 12,
  },
  accentBar: {
    width: 4, alignSelf: 'stretch', borderRadius: 2,
    backgroundColor: '#d4af37', marginHorizontal: 14,
  },
  cardTop: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  cardName: { flexShrink: 1, color: '#f0e6d2', fontSize: 17, fontWeight: '600' },
  defaultBadge: {
    color: '#ffd700', fontSize: 10, borderWidth: 1,
    borderColor: '#8a6d2f', borderRadius: 5, paddingHorizontal: 6,
    paddingVertical: 2, overflow: 'hidden',
  },
  realmBadge: { fontSize: 11, paddingHorizontal: 6, overflow: 'hidden' },
  realmEternal: { color: '#9ab8d8' },
  realmIllusion: { color: '#d8a8e0' },
  cardMeta: { color: '#a89aa8', fontSize: 13, marginTop: 5 },
  liveMeta: { color: '#7ad08a', fontSize: 12, marginTop: 4 },
  levelPill: {
    backgroundColor: '#2d2410', borderRadius: 10, borderWidth: 1,
    borderColor: '#8a6d2f', paddingHorizontal: 10, paddingVertical: 6,
  },
  levelText: { color: '#ffd700', fontSize: 13, fontWeight: '700' },
  cardActions: {
    flexDirection: 'row', alignItems: 'center', gap: 8,
    paddingHorizontal: 14, paddingBottom: 12,
  },
  sessionClose: {
    width: 32, height: 32, borderRadius: 999, borderWidth: 1,
    borderColor: '#5a3a46', alignItems: 'center', justifyContent: 'center',
  },
  sessionCloseText: { color: '#c8a8b8', fontSize: 13 },
  afkToggle: {
    flex: 1, minHeight: 34, borderRadius: 10, borderWidth: 1,
    borderColor: '#6a8a5a', backgroundColor: '#16241c',
    alignItems: 'center', justifyContent: 'center',
  },
  afkToggleOn: { borderColor: '#7ad08a', backgroundColor: '#2d5243' },
  afkToggleNew: { borderColor: '#8a6d2f', backgroundColor: '#2d2410' },
  afkToggleText: { color: '#c8e8c8', fontSize: 13 },
  enterButton: {
    flex: 1, minHeight: 34, borderRadius: 10, borderWidth: 1,
    borderColor: '#d4af37', backgroundColor: '#221c10',
    alignItems: 'center', justifyContent: 'center',
  },
  enterText: { color: '#ffd700', fontSize: 13, fontWeight: '600' },
  errorPill: {
    margin: 12, backgroundColor: '#3d1018', borderRadius: 10,
    borderWidth: 1, borderColor: '#ff4d6d', paddingHorizontal: 12,
    paddingVertical: 9,
  },
  errorText: { color: '#ff9aa8', fontSize: 13 },
  emptyWrap: { alignItems: 'center', marginTop: 72, gap: 8 },
  emptyIcon: { fontSize: 44 },
  empty: { color: '#8a7a8a', fontSize: 15 },
  emptyHint: { color: '#6a5a6a', fontSize: 12 },
});
