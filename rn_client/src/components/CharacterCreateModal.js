import React, { useMemo, useState } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, FlatList,
  StyleSheet, Modal, ScrollView,
} from 'react-native';
import { useGameStore } from '../store/useGameStore.js';
import {
  RACES, professionsForRace, avatarChoicesFor,
} from '../data/characterOptions.js';

export default function CharacterCreateModal({ visible, onClose }) {
  const {
    accountUnlocks, busy, error, createCharacter, accountCharacters,
    characterLimit,
  } = useGameStore();
  const [raceId, setRaceId] = useState('');
  const [professionId, setProfessionId] = useState('');
  const [sex, setSex] = useState('male');
  const [name, setName] = useState('');
  const [avatarId, setAvatarId] = useState('');

  const professions = useMemo(
    () => professionsForRace(raceId, accountUnlocks, 'eternal'),
    [raceId, accountUnlocks]);
  const avatars = useMemo(
    () => avatarChoicesFor(raceId, professionId, sex),
    [raceId, professionId, sex]);

  const slotsFull = characterLimit > 0 &&
    accountCharacters.length >= characterLimit;
  const canSubmit = !!raceId && !!professionId && !!avatarId &&
    name.trim().length > 0 && !busy && !slotsFull;

  const reset = () => {
    setRaceId(''); setProfessionId(''); setAvatarId('');
    setName(''); setSex('male');
  };

  const submit = async () => {
    const ok = await createCharacter({
      realm_type: 'eternal', race_id: raceId,
      profession_id: professionId, name_cn: name.trim(),
      sex, avatar_id: avatarId,
    });
    if (ok) { reset(); onClose(); }
  };

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose}>
      <ScrollView style={styles.screen} contentContainerStyle={styles.container}>
        <View style={styles.headRow}>
          <Text style={styles.title}>创建新角色</Text>
          <TouchableOpacity onPress={onClose}>
            <Text style={styles.close}>返回</Text>
          </TouchableOpacity>
        </View>

        {slotsFull && <Text style={styles.error}>角色栏位已满（{characterLimit}）</Text>}

        <Text style={styles.label}>种族</Text>
        <View style={styles.chipRow}>
          {RACES.map(race => (
            <TouchableOpacity key={race.id}
              style={[styles.chip, raceId === race.id && styles.chipActive]}
              onPress={() => { setRaceId(race.id); setProfessionId(''); setAvatarId(''); }}>
              <Text style={[styles.chipText,
                raceId === race.id && styles.chipTextActive]}>{race.name}</Text>
            </TouchableOpacity>
          ))}
        </View>

        {!!raceId && (
          <>
            <Text style={styles.label}>职业</Text>
            {professions.map(profession => (
              <TouchableOpacity key={profession.profession_id}
                style={[styles.profCard,
                  professionId === profession.profession_id &&
                  styles.profCardActive]}
                onPress={() => { setProfessionId(profession.profession_id); setAvatarId(''); }}>
                <Text style={styles.profName}>
                  {profession.icon} {profession.name}
                </Text>
                <Text style={styles.profDesc}>{profession.desc}</Text>
              </TouchableOpacity>
            ))}
          </>
        )}

        <Text style={styles.label}>性别</Text>
        <View style={styles.chipRow}>
          {['male', 'female'].map(value => (
            <TouchableOpacity key={value}
              style={[styles.chip, sex === value && styles.chipActive]}
              onPress={() => { setSex(value); setAvatarId(''); }}>
              <Text style={[styles.chipText,
                sex === value && styles.chipTextActive]}>
                {value === 'male' ? '男' : '女'}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        <Text style={styles.label}>名字</Text>
        <TextInput
          style={styles.nameInput}
          value={name}
          onChangeText={setName}
          maxLength={12}
          placeholder="2-12个字符"
          placeholderTextColor="#6a5a6a"
        />

        {!!avatars.length && (
          <>
            <Text style={styles.label}>头像</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false}
              contentContainerStyle={styles.chipRow}>
              {avatars.map(avatar => (
                <TouchableOpacity key={avatar}
                  style={[styles.chip,
                    avatarId === avatar && styles.chipActive]}
                  onPress={() => setAvatarId(avatar)}>
                  <Text style={[styles.chipText,
                    avatarId === avatar && styles.chipTextActive]}>
                    {avatar}
                  </Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
          </>
        )}

        {!!error && <Text style={styles.error}>{error}</Text>}

        <TouchableOpacity
          style={[styles.createButton, !canSubmit && { opacity: 0.5 }]}
          disabled={!canSubmit}
          onPress={submit}>
          <Text style={styles.createText}>
            {busy ? '创建中…' : '创建并进入'}
          </Text>
        </TouchableOpacity>
      </ScrollView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#0d0b0e' },
  container: { padding: 20, paddingTop: 64 },
  headRow: {
    flexDirection: 'row', justifyContent: 'space-between',
    alignItems: 'center', marginBottom: 8,
  },
  title: { color: '#f0e6d2', fontSize: 20, fontWeight: '700' },
  close: { color: '#a89aa8', fontSize: 14 },
  label: { color: '#a89aa8', fontSize: 12, marginTop: 14, marginBottom: 6 },
  chipRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  chip: {
    paddingHorizontal: 14, paddingVertical: 7, borderRadius: 999,
    borderWidth: 1, borderColor: '#3a2f46', backgroundColor: '#1a141c',
  },
  chipActive: { borderColor: '#d4af37', backgroundColor: '#2d2410' },
  chipText: { color: '#a89aa8', fontSize: 13 },
  chipTextActive: { color: '#ffd700' },
  profCard: {
    backgroundColor: '#1a141c', borderRadius: 10, padding: 12,
    borderWidth: 1, borderColor: '#3a2f46', marginBottom: 8,
  },
  profCardActive: { borderColor: '#d4af37' },
  profName: { color: '#f0e6d2', fontSize: 15, fontWeight: '600' },
  profDesc: { color: '#8a7a8a', fontSize: 11, marginTop: 4 },
  nameInput: {
    backgroundColor: '#1a141c', borderRadius: 10, paddingHorizontal: 14,
    paddingVertical: 10, color: '#f0e6d2', fontSize: 15,
    borderWidth: 1, borderColor: '#2e2430',
  },
  error: { color: '#ff6b8a', fontSize: 12, marginTop: 10 },
  createButton: {
    marginTop: 22, borderRadius: 999, paddingVertical: 13,
    backgroundColor: '#2d5243', borderWidth: 1, borderColor: '#7ad08a',
    alignItems: 'center',
  },
  createText: { color: '#e8f2ec', fontSize: 16, fontWeight: '600' },
});
