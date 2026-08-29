import React, { useEffect, useRef } from 'react';
import { View, Text, StyleSheet, Animated, Easing } from 'react-native';
import { skillMeta } from '../utils/skillTypes.js';

/**
 * 技能施法动画：图标从中心放大→旋转辉光→升腾消散。
 * 与 Vue skill-effect-container 同一视觉语言。
 */
function SkillEffect({ effect, index }) {
  const scale = useRef(new Animated.Value(0.2)).current;
  const opacity = useRef(new Animated.Value(0)).current;
  const translateY = useRef(new Animated.Value(0)).current;
  const rotate = useRef(new Animated.Value(-30)).current;
  const meta = skillMeta(effect.type);

  useEffect(() => {
    Animated.parallel([
      Animated.sequence([
        Animated.timing(opacity, {
          toValue: 1, duration: 120,
          easing: Easing.out(Easing.quad), useNativeDriver: true,
        }),
        Animated.timing(opacity, {
          toValue: 0, duration: meta.duration - 120,
          easing: Easing.in(Easing.quad), useNativeDriver: true,
        }),
      ]),
      Animated.sequence([
        Animated.spring(scale, {
          toValue: 1.3, speed: 20, bounciness: 4, useNativeDriver: true,
        }),
        Animated.timing(scale, {
          toValue: 0.8, duration: meta.duration * 0.4,
          useNativeDriver: true,
        }),
      ]),
      Animated.timing(translateY, {
        toValue: -60, duration: meta.duration,
        easing: Easing.out(Easing.quad), useNativeDriver: true,
      }),
      Animated.timing(rotate, {
        toValue: 15, duration: meta.duration,
        easing: Easing.linear, useNativeDriver: true,
      }),
    ]).start();
  }, []);

  const top = 150 + index * 45;
  return (
    <Animated.View style={[
      styles.effectWrap, { top, opacity, transform: [
        { scale }, { translateY }, { rotate: rotate.interpolate({
          inputRange: [-30, 15], outputRange: ['-30deg', '15deg'],
        }) }],
      },
    ]}>
      <View style={[styles.iconCircle,
        { borderColor: meta.color, shadowColor: meta.glow }]}>
        <Text style={[styles.icon, { color: meta.color, fontSize: 32 }]}>
          {meta.icon}
        </Text>
      </View>
      {effect.name && (
        <Text style={[styles.label, { color: meta.color }]}
          numberOfLines={1}>
          {effect.name}
        </Text>
      )}
    </Animated.View>
  );
}

export default function SkillEffectOverlay({ effects }) {
  if (!effects || effects.length === 0) return null;
  return (
    <View style={styles.layer} pointerEvents="none">
      {effects.slice(0, 3).map((effect, index) => (
        <SkillEffect key={effect.id} effect={effect} index={index} />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  layer: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 110,
    alignItems: 'center',
  },
  effectWrap: {
    position: 'absolute', alignItems: 'center', gap: 6,
  },
  iconCircle: {
    width: 64, height: 64, borderRadius: 32,
    borderWidth: 2, alignItems: 'center', justifyContent: 'center',
    backgroundColor: 'rgba(13,11,14,0.7)',
    shadowOpacity: 0.8, shadowRadius: 16,
    elevation: 8,
  },
  icon: {
    fontWeight: '700',
    textShadowColor: '#000', textShadowRadius: 4,
  },
  label: {
    fontSize: 12, fontWeight: '600',
    textShadowColor: '#000', textShadowRadius: 3,
    maxWidth: 140,
  },
});
