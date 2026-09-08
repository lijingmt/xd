import React, { useEffect, useRef, useState } from 'react';
import {
  View, Text, Image, StyleSheet, Animated, Easing,
} from 'react-native';
import { SmartImage } from './GameSmartImage.js';

/**
 * Vue battle-mini 的原生复刻：左侧玩家(含宠物) VS 右侧敌人。
 * 血条宽度用 Animated 平滑过渡；低血量闪烁红光。
 */
/* 战斗面板主题色：夜晚保持原有暗色；白天模式使用浅色卡片，
 * 避免整体亮色界面里嵌一块黑色。 */
const BATTLE_THEMES = {
  night: {
    sceneBg: '#1a0e14', sceneBorder: '#3a1a28',
    avatarBorder: '#8a6d2f', avatarFallbackBg: '#2d2410',
    avatarFallbackText: '#ffd700', monsterBg: '#3d1018',
    monsterBorder: '#8a3548', name: '#f0e6d2', enemyName: '#ffb3c0',
    level: '#a89aa8', petRowBg: '#1a2018', petBorder: '#3a5a3a',
    petName: '#9ad0a0', petSkill: '#6a9a70', petCdTrack: '#0d1a10',
    resLabel: '#8a7a8a', resTrack: '#241a28', resText: '#8a9aa8',
    meta: '#6a5a6a', power: '#8a6a6a',
  },
  day: {
    sceneBg: '#ffffff', sceneBorder: '#d4c8b0',
    avatarBorder: '#8a6d2f', avatarFallbackBg: '#e8e0d0',
    avatarFallbackText: '#5a4010', monsterBg: '#f5e0e4',
    monsterBorder: '#c4405a', name: '#2a2015', enemyName: '#c4405a',
    level: '#6a5a4a', petRowBg: '#f0ebe3', petBorder: '#b0c8a0',
    petName: '#2d8a4a', petSkill: '#5a7a4a', petCdTrack: '#e0d8c8',
    resLabel: '#6a5a4a', resTrack: '#e8e0d0', resText: '#4a3a2a',
    meta: '#6a5a4a', power: '#7a5a4a',
  },
  gold: {
    sceneBg: '#20180c', sceneBorder: '#3d3018',
    avatarBorder: '#b89630', avatarFallbackBg: '#322818',
    avatarFallbackText: '#ffd700', monsterBg: '#322018',
    monsterBorder: '#c08040', name: '#f5e8c8', enemyName: '#ffb87a',
    level: '#c0a878', petRowBg: '#282012', petBorder: '#5a6830',
    petName: '#b0c878', petSkill: '#8a9a50', petCdTrack: '#1a1408',
    resLabel: '#c0a878', resTrack: '#322818', resText: '#c0b080',
    meta: '#8a7050', power: '#c0a060',
  },
};

export default function BattleScene({ player, enemy, pet, imageBase, theme }) {
  const t = BATTLE_THEMES[theme] || BATTLE_THEMES.night;
  const playerHp = useRef(new Animated.Value(0)).current;
  const enemyHp = useRef(new Animated.Value(0)).current;
  const [playerFlash, setPlayerFlash] = useState('');
  const [enemyFlash, setEnemyFlash] = useState('');
  const prevHpRef = useRef({ player: 0, enemy: 0 });

  useEffect(() => {
    const pPct = percent(player.hp, player.hp_max);
    const ePct = percent(enemy.hp, enemy.hp_max);
    /* 变化方向闪色 */
    if (prevHpRef.current.player > pPct) setPlayerFlash('down');
    else if (prevHpRef.current.player < pPct && pPct > 0) setPlayerFlash('up');
    if (prevHpRef.current.enemy > ePct) setEnemyFlash('down');
    else if (prevHpRef.current.enemy < ePct && ePct > 0) setEnemyFlash('up');
    prevHpRef.current = { player: pPct, enemy: ePct };
    const timer = setTimeout(() => {
      setPlayerFlash(''); setEnemyFlash('');
    }, 600);
    Animated.parallel([
      Animated.timing(playerHp, {
        toValue: pPct, duration: 400,
        easing: Easing.out(Easing.cubic), useNativeDriver: false,
      }),
      Animated.timing(enemyHp, {
        toValue: ePct, duration: 400,
        easing: Easing.out(Easing.cubic), useNativeDriver: false,
      }),
    ]).start();
    return () => clearTimeout(timer);
  }, [player.hp, player.hp_max, enemy.hp, enemy.hp_max]);

  const playerLow = percent(player.hp, player.hp_max) < 30;
  const avatarUrl = player.avatar
    ? `${imageBase}${player.avatar}` : '';

  return (
    <View style={[styles.scene, {
      backgroundColor: t.sceneBg, borderBottomColor: t.sceneBorder,
    }]}>
      {/* ===== 玩家侧 ===== */}
      <View style={styles.side}>
        <View style={styles.identity}>
          {avatarUrl ? (
            <SmartImage uri={avatarUrl}
              style={[styles.avatar, { borderColor: t.avatarBorder }]} />
          ) : (
            <View style={[styles.avatar, styles.avatarFallback,
              { borderColor: t.avatarBorder,
                backgroundColor: t.avatarFallbackBg }]}>
              <Text style={[styles.avatarFallbackText,
                { color: t.avatarFallbackText }]}>
                {(player.name_cn || '仙')[0]}
              </Text>
            </View>
          )}
          <View style={{ flex: 1 }}>
            <Text style={[styles.nameText, { color: t.name }]}
              numberOfLines={1}>
              {player.name_cn || '我'}
            </Text>
            <Text style={[styles.levelText, { color: t.level }]}>
              Lv.{player.level || '?'}</Text>
          </View>
        </View>

        {/* 宠物 */}
        {!!pet && typeof pet === 'object' && (
          <View style={[styles.petRow, {
            backgroundColor: t.petRowBg, borderColor: t.petBorder }]}>
            <Text style={styles.petIcon}>{pet.icon || '🐾'}</Text>
            <View style={{ flex: 1 }}>
              <Text style={[styles.petName, { color: t.petName }]}
                numberOfLines={1}>
                {pet.name || pet.name_cn || '灵宠'}
              </Text>
              {!!pet.skill && (
                <Text style={[styles.petSkill, { color: t.petSkill }]}
                  numberOfLines={1}>
                  {pet.skill}
                </Text>
              )}
            </View>
            {typeof pet.cooldown_remaining === 'number' && (
              <View style={[styles.petCdTrack,
                { backgroundColor: t.petCdTrack }]}>
                <View style={[styles.petCdFill, {
                  width: `${Math.max(0, Math.min(100,
                    (1 - pet.cooldown_remaining /
                      Math.max(1, pet.cooldown_max || 1)) * 100))}%`,
                }]} />
              </View>
            )}
          </View>
        )}

        <ResourceBar label="生命" animated={playerHp} flash={playerFlash}
          color="#3f8a53" low={playerLow} t={t}
          text={`${fmt(player.hp)}/${fmt(player.hp_max)}`} />
        <ResourceBar label="法力"
          animated={null} flash=""
          color="#3a6ac2" t={t}
          text={`${fmt(player.mana)}/${fmt(player.mana_max)}`}
          pct={percent(player.mana, player.mana_max)} />

        <View style={styles.metaRow}>
          <Text style={[styles.metaText, { color: t.meta }]}>
            {player.profession_name || player.profession_id || ''}
          </Text>
          {!!player.race && (
            <Text style={[styles.metaText, { color: t.meta }]}>{player.race}</Text>
          )}
        </View>
      </View>

      {/* ===== VS ===== */}
      <View style={styles.vsWrap}>
        <Text style={styles.vsIcon}>⚔️</Text>
      </View>

      {/* ===== 敌人侧 ===== */}
      <View style={styles.side}>
        <View style={styles.identity}>
          <View style={[styles.avatar, styles.monsterAvatar,
            { backgroundColor: t.monsterBg,
              borderColor: t.monsterBorder }]}>
            <Text style={styles.monsterIcon}>👹</Text>
          </View>
          <View style={{ flex: 1 }}>
            <Text style={[styles.nameText, { color: t.enemyName }]}
              numberOfLines={1}>
              {enemy.name_cn || enemy.name || '目标识别中'}
            </Text>
            {enemy.level !== undefined && enemy.level !== null && (
              <Text style={[styles.levelText, { color: t.level }]}>
                Lv.{enemy.level}</Text>
            )}
          </View>
        </View>

        <ResourceBar label="生命" animated={enemyHp} flash={enemyFlash}
          color="#c23a4a" t={t}
          text={`${fmt(enemy.hp)}/${fmt(enemy.hp_max)}`} />

        <View style={styles.metaRow}>
          <Text style={[styles.metaText, { color: t.meta }]}>{enemy.profe || '怪物'}</Text>
          {!!enemy.race && (
            <Text style={[styles.metaText, { color: t.meta }]}>{enemy.race}</Text>)}
        </View>
        {(enemy.attack !== undefined || enemy.defend !== undefined) && (
          <View style={styles.metaRow}>
            <Text style={[styles.powerText, { color: t.power }]}>
              攻 {fmt(enemy.attackLow ?? enemy.attack ?? 0)}
              {enemy.attackHigh !== undefined &&
                enemy.attackHigh !== enemy.attackLow
                ? `-${fmt(enemy.attackHigh)}` : ''}
            </Text>
            <Text style={[styles.powerText, { color: t.power }]}>
              防 {fmt(enemy.defend ?? 0)}
            </Text>
          </View>
        )}
      </View>
    </View>
  );
}

function ResourceBar({ label, animated, flash, color, low, text, pct, t }) {
  const width = animated
    ? animated.interpolate({ inputRange: [0, 100], outputRange: ['0%', '100%'] })
    : `${pct || 0}%`;
  return (
    <View style={styles.resRow}>
      <Text style={[styles.resLabel, { color: t.resLabel }]}>{label}</Text>
      <View style={[styles.resTrack, { backgroundColor: t.resTrack },
        flash === 'down' && styles.resFlashDown,
        flash === 'up' && styles.resFlashUp,
        low && styles.resLow]}>
        <Animated.View style={[styles.resFill, { width }, { backgroundColor: color }]} />
      </View>
      <Text style={[styles.resText, { color: t.resText },
        flash === 'down' && styles.resTextFlashDown,
        flash === 'up' && styles.resTextFlashUp]}>{text}</Text>
    </View>
  );
}

function percent(value, max) {
  return Math.max(0, Math.min(100,
    ((Number(value) || 0) / Math.max(1, Number(max) || 1)) * 100));
}

function fmt(value) {
  const num = Number(value) || 0;
  if (num >= 100000000) return `${(num / 100000000).toFixed(1)}亿`;
  if (num >= 10000) return `${(num / 10000).toFixed(1)}万`;
  return String(num);
}

const styles = StyleSheet.create({
  scene: {
    flexDirection: 'row', alignItems: 'stretch',
    backgroundColor: '#1a0e14', borderBottomWidth: 1,
    borderBottomColor: '#3a1a28', paddingHorizontal: 8, paddingVertical: 8,
    gap: 4,
  },
  side: { flex: 1, gap: 4 },
  identity: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  avatar: {
    width: 34, height: 34, borderRadius: 8,
    borderWidth: 1, borderColor: '#8a6d2f',
  },
  avatarFallback: {
    backgroundColor: '#2d2410', alignItems: 'center', justifyContent: 'center',
  },
  avatarFallbackText: { color: '#ffd700', fontSize: 15, fontWeight: '700' },
  monsterAvatar: {
    backgroundColor: '#3d1018', borderColor: '#8a3548',
    alignItems: 'center', justifyContent: 'center',
  },
  monsterIcon: { fontSize: 18 },
  nameText: { color: '#f0e6d2', fontSize: 13, fontWeight: '700' },
  enemyName: { color: '#ffb3c0' },
  levelText: { color: '#a89aa8', fontSize: 10, marginTop: 1 },
  petRow: {
    flexDirection: 'row', alignItems: 'center', gap: 5,
    backgroundColor: '#1a2018', borderRadius: 6,
    borderWidth: 1, borderColor: '#3a5a3a', paddingHorizontal: 6,
    paddingVertical: 3,
  },
  petIcon: { fontSize: 16 },
  petName: { color: '#9ad0a0', fontSize: 10, fontWeight: '600' },
  petSkill: { color: '#6a9a70', fontSize: 9 },
  petCdTrack: {
    width: 36, height: 5, borderRadius: 3,
    backgroundColor: '#0d1a10', overflow: 'hidden',
  },
  petCdFill: { height: 5, borderRadius: 3, backgroundColor: '#5aaa60' },
  resRow: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  resLabel: { color: '#8a7a8a', fontSize: 9, width: 20 },
  resTrack: {
    flex: 1, height: 10, borderRadius: 5,
    backgroundColor: '#241a28', overflow: 'hidden',
  },
  resFill: { height: 10, borderRadius: 5 },
  resFlashDown: { borderColor: '#ff4444', borderWidth: 1 },
  resFlashUp: { borderColor: '#7ad08a', borderWidth: 1 },
  resLow: {
    borderColor: '#ff2222', borderWidth: 1,
    shadowColor: '#ff0000', shadowOpacity: 0.8,
    shadowRadius: 4, elevation: 3,
  },
  resText: { color: '#8a9aa8', fontSize: 9, minWidth: 56, textAlign: 'right' },
  resTextFlashDown: { color: '#ff6b6b' },
  resTextFlashUp: { color: '#7ad08a' },
  metaRow: { flexDirection: 'row', gap: 6 },
  metaText: { color: '#6a5a6a', fontSize: 9 },
  powerText: { color: '#8a6a6a', fontSize: 9 },
  vsWrap: {
    alignItems: 'center', justifyContent: 'center',
    paddingHorizontal: 2,
  },
  vsIcon: { fontSize: 22 },
});
