import React, { useEffect, useRef } from 'react';
import { View, Text, StyleSheet, Animated, Easing } from 'react-native';
import { skillMeta } from '../utils/skillTypes.js';

/**
 * 技能施法动画层：对齐网页版 app.css 的 13 种 keyframes 变体，
 * 按 target 定位（player 左 / enemy 右 / room 中央）。
 */

function timing(value, toValue, duration, easing) {
  return Animated.timing(value, {
    toValue, duration,
    easing: easing || Easing.out(Easing.quad),
    useNativeDriver: true,
  });
}

/** 变体 → 并行动画组合。vals 为各 Animated.Value。 */
function buildVariant(variant, v, duration) {
  const d = duration;
  switch (variant) {
    case 'wave': /* 剑气/内功：金色光波，放大+旋转 */
      return Animated.parallel([
        Animated.sequence([
          timing(v.opacity, 1, d * 0.5),
          timing(v.opacity, 0, d * 0.5, Easing.in(Easing.quad)),
        ]),
        Animated.sequence([
          timing(v.scale, 1.5, d * 0.5),
          timing(v.scale, 3, d * 0.5),
        ]),
        timing(v.rotate, 1, d, Easing.linear),
        Animated.sequence([
          timing(v.ringScale, 1.6, d * 0.5),
          timing(v.ringScale, 3.4, d * 0.5),
        ]),
        timing(v.ringOpacity, 0, d * 0.7),
      ]);
    case 'ripple': /* 掌法/毒/冰：波纹扩散 */
      return Animated.parallel([
        Animated.sequence([
          timing(v.opacity, 0.95, d * 0.25),
          timing(v.opacity, 0, d * 0.75, Easing.in(Easing.quad)),
        ]),
        timing(v.scale, 2.5, d),
        timing(v.ringScale, 2.8, d),
        timing(v.ringOpacity, 0, d * 0.8),
      ]);
    case 'beam': /* 指法：紫色光束横向拉伸 */
      return Animated.parallel([
        Animated.sequence([
          timing(v.opacity, 1, d * 0.2),
          timing(v.opacity, 0, d * 0.8, Easing.in(Easing.quad)),
        ]),
        Animated.sequence([
          timing(v.scaleX, 1.5, d * 0.5),
          timing(v.scaleX, 2, d * 0.5),
        ]),
        Animated.sequence([
          timing(v.scaleY, 1.2, d * 0.5),
          timing(v.scaleY, 0.5, d * 0.5),
        ]),
      ]);
    case 'slash': /* 刀法：银色刀光，斜向劈砍 */
      return Animated.parallel([
        Animated.sequence([
          timing(v.opacity, 1, d * 0.15),
          timing(v.opacity, 0, d * 0.85, Easing.in(Easing.quad)),
        ]),
        Animated.sequence([
          timing(v.scaleX, 1.8, d * 0.5),
          timing(v.scaleX, 2.5, d * 0.5),
        ]),
        timing(v.rotate, 1, d),
      ]);
    case 'impact': /* 拳法/雷：快速冲击 */
      return Animated.parallel([
        Animated.sequence([
          timing(v.opacity, 1, d * 0.6),
          timing(v.opacity, 0, d * 0.4, Easing.in(Easing.quad)),
        ]),
        Animated.sequence([
          timing(v.scale, 1.8, d * 0.5),
          timing(v.scale, 2.5, d * 0.5),
        ]),
        Animated.sequence([
          timing(v.translateX, 6, d * 0.15),
          timing(v.translateX, 0, d * 0.2),
          timing(v.translateX, -6, d * 0.25),
          timing(v.translateX, 0, d * 0.4),
        ]),
      ]);
    case 'rise': /* 轻功/治疗：升腾消散 */
      return Animated.parallel([
        Animated.sequence([
          timing(v.opacity, 1, d * 0.2),
          timing(v.opacity, 0, d * 0.8, Easing.in(Easing.quad)),
        ]),
        timing(v.translateY, -80, d),
        Animated.sequence([
          timing(v.scale, 1.15, d * 0.3),
          timing(v.scale, 0.9, d * 0.7),
        ]),
      ]);
    case 'burst': /* 暴击/火/太古：爆炸 */
      return Animated.parallel([
        Animated.sequence([
          timing(v.opacity, 1, d * 0.3),
          timing(v.opacity, 0, d * 0.7, Easing.in(Easing.quad)),
        ]),
        Animated.sequence([
          timing(v.scale, 2, d * 0.3),
          timing(v.scale, 3, d * 0.7),
        ]),
        timing(v.ringScale, 3.4, d),
        timing(v.ringOpacity, 0, d * 0.75),
      ]);
    case 'shift': /* 闪避：左右虚影 */
      return Animated.parallel([
        timing(v.opacity, 0, d, Easing.in(Easing.quad)),
        Animated.sequence([
          timing(v.translateX, -20, 0),
          timing(v.translateX, 20, d),
        ]),
      ]);
    case 'pulse': /* 格挡/增益：脉冲光环 */
      return Animated.parallel([
        Animated.sequence([
          timing(v.opacity, 1, d * 0.3),
          timing(v.opacity, 0.75, d * 0.3),
          timing(v.opacity, 0, d * 0.4, Easing.in(Easing.quad)),
        ]),
        Animated.sequence([
          timing(v.scale, 1.2, d * 0.5),
          timing(v.scale, 1, d * 0.5),
        ]),
        timing(v.ringScale, 1.9, d),
        timing(v.ringOpacity, 0, d * 0.85),
      ]);
    case 'orbit': /* 召唤/诅咒/灵：环绕旋转 */
      return Animated.parallel([
        Animated.sequence([
          timing(v.opacity, 1, d * 0.2),
          timing(v.opacity, 0, d * 0.8, Easing.in(Easing.quad)),
        ]),
        timing(v.rotate, 1, d, Easing.linear),
        Animated.sequence([
          timing(v.scale, 1.4, d * 0.5),
          timing(v.scale, 0.8, d * 0.5),
        ]),
      ]);
    case 'sweep': /* 棒法/风：横扫 */
      return Animated.parallel([
        Animated.sequence([
          timing(v.opacity, 1, d * 0.15),
          timing(v.opacity, 0, d * 0.85, Easing.in(Easing.quad)),
        ]),
        timing(v.rotate, 1, d),
        Animated.sequence([
          timing(v.scaleX, 1.5, d * 0.5),
          timing(v.scaleX, 2, d * 0.5),
        ]),
      ]);
    case 'moon': { /* 神太古：血月双搏动后升腾 */
      const step = ms => timing(v.scale, ms.to, ms.dur);
      return Animated.parallel([
        Animated.sequence([
          timing(v.opacity, 1, d * 0.16),
          timing(v.opacity, 0, d * 0.24, Easing.in(Easing.quad)),
        ]),
        Animated.sequence([
          step({ to: 1.42, dur: d * 0.16 }),
          step({ to: 1.02, dur: d * 0.12 }),
          step({ to: 1.55, dur: d * 0.12 }),
          step({ to: 1.12, dur: d * 0.14 }),
          step({ to: 2.9, dur: d * 0.46 }),
        ]),
        Animated.sequence([
          timing(v.translateY, 0, d * 0.54),
          timing(v.translateY, -95, d * 0.46),
        ]),
      ]);
    }
    default: /* cast：通用施法 */
      return Animated.parallel([
        Animated.sequence([
          timing(v.opacity, 1, d * 0.2),
          timing(v.opacity, 0, d * 0.8, Easing.in(Easing.quad)),
        ]),
        Animated.spring(v.scale, {
          toValue: 1.3, speed: 18, bounciness: 5, useNativeDriver: true,
        }),
        timing(v.translateY, -46, d),
      ]);
  }
}

const TARGET_LEFT = { player: '22%', enemy: '78%', room: '50%' };

function SkillEffect({ effect, index }) {
  const v = {
    opacity: useRef(new Animated.Value(0)).current,
    scale: useRef(new Animated.Value(0.3)).current,
    scaleX: useRef(new Animated.Value(0.1)).current,
    scaleY: useRef(new Animated.Value(1)).current,
    rotate: useRef(new Animated.Value(0)).current,
    translateX: useRef(new Animated.Value(0)).current,
    translateY: useRef(new Animated.Value(0)).current,
    ringScale: useRef(new Animated.Value(0.6)).current,
    ringOpacity: useRef(new Animated.Value(0.7)).current,
  };
  const meta = skillMeta(effect.type);

  useEffect(() => {
    buildVariant(meta.variant, v, meta.duration).start();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const left = TARGET_LEFT[effect.target] || TARGET_LEFT.enemy;
  const top = 150 + index * 52;
  const rotateDeg = v.rotate.interpolate({
    inputRange: [0, 1], outputRange: ['0deg', '360deg'],
  });
  const slashDeg = v.rotate.interpolate({
    inputRange: [0, 1], outputRange: ['-30deg', '30deg'],
  });
  const useSlash = meta.variant === 'slash';
  const ringSize = Math.max(64, meta.size + 24);

  return (
    <Animated.View style={[
      styles.effectWrap, { top, left, opacity: v.opacity },
      { transform: [
        { translateX: v.translateX },
        { translateY: v.translateY },
        { scaleX: meta.variant === 'beam' || meta.variant === 'slash'
          || meta.variant === 'sweep' ? v.scaleX : v.scale },
        { scaleY: meta.variant === 'beam' ? v.scaleY : v.scale },
        { rotate: useSlash ? slashDeg
          : (meta.variant === 'sweep'
            ? v.rotate.interpolate({
              inputRange: [0, 1], outputRange: ['-45deg', '45deg'],
            })
            : rotateDeg) },
      ] },
    ]}>
      <Animated.View style={[styles.ring, {
        width: ringSize, height: ringSize, borderRadius: ringSize / 2,
        borderColor: meta.glow, top: -3,
        transform: [{ scale: v.ringScale }], opacity: v.ringOpacity,
      }]} />
      <View style={[styles.iconCircle, {
        borderColor: meta.color, shadowColor: meta.glow,
        width: meta.size + 18, height: meta.size + 18,
        borderRadius: (meta.size + 18) / 2,
      }]}>
        <Text style={[styles.icon, { color: meta.color, fontSize: meta.size }]}>
          {meta.icon}
        </Text>
      </View>
      {effect.name ? (
        <View style={styles.labelPill}>
          <Text style={[styles.label, { color: meta.color }]} numberOfLines={1}>
            {effect.name}
          </Text>
        </View>
      ) : null}
    </Animated.View>
  );
}

export default function SkillEffectOverlay({ effects }) {
  if (!effects || effects.length === 0) return null;
  return (
    <View style={styles.layer} pointerEvents="none">
      {effects.slice(-3).map((effect, index) => (
        <SkillEffect key={effect.id} effect={effect}
          index={index % 3} />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  layer: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 110,
  },
  effectWrap: {
    position: 'absolute', alignItems: 'center',
    marginLeft: -50, width: 100,
  },
  ring: {
    position: 'absolute', borderWidth: 2, alignSelf: 'center',
    backgroundColor: 'rgba(0,0,0,0)',
  },
  iconCircle: {
    alignItems: 'center', justifyContent: 'center',
    borderWidth: 2,
    backgroundColor: 'rgba(13,11,14,0.66)',
    shadowOpacity: 0.85, shadowRadius: 18,
    elevation: 8,
  },
  labelPill: {
    marginTop: 8, paddingHorizontal: 8, paddingVertical: 3,
    borderRadius: 999, borderWidth: 1,
    borderColor: 'rgba(255,224,153,0.5)',
    backgroundColor: 'rgba(22,14,32,0.9)',
    maxWidth: 150,
  },
  icon: {
    fontWeight: '700',
    textShadowColor: '#000', textShadowRadius: 4,
  },
  label: {
    fontSize: 12, fontWeight: '600',
    textShadowColor: '#000', textShadowRadius: 3,
  },
});
