import React, { useEffect, useRef, useState } from 'react';
import { View, Text, Animated, StyleSheet, TouchableOpacity } from 'react-native';

let toastId = 0;
let showToastFn = null;

export function toast(message, type = 'info') {
  if (showToastFn) showToastFn(message, type);
}

function ToastItem({ item, onDone }) {
  const opacity = useRef(new Animated.Value(0)).current;
  const translateY = useRef(new Animated.Value(-20)).current;

  useEffect(() => {
    Animated.parallel([
      Animated.timing(opacity, {
        toValue: 1, duration: 200, useNativeDriver: true,
      }),
      Animated.timing(translateY, {
        toValue: 0, duration: 200, useNativeDriver: true,
      }),
    ]).start();
    const timer = setTimeout(() => {
      Animated.timing(opacity, {
        toValue: 0, duration: 300, useNativeDriver: true,
      }).start(() => onDone(item.id));
    }, item.duration || 2500);
    return () => clearTimeout(timer);
  }, []);

  const bgColor = item.type === 'success' ? '#10241a' :
    item.type === 'error' ? '#241016' :
    item.type === 'warn' ? '#231b10' : '#14101a';
  const borderColor = item.type === 'success' ? '#2d5a3a' :
    item.type === 'error' ? '#5a2d3a' :
    item.type === 'warn' ? '#8a6d2f' : '#3a2f46';
  const textColor = item.type === 'success' ? '#5ad47a' :
    item.type === 'error' ? '#ff5a6a' :
    item.type === 'warn' ? '#ffd700' : '#a89aa8';
  const icon = item.type === 'success' ? '✓' :
    item.type === 'error' ? '✗' :
    item.type === 'warn' ? '⚠' : 'ℹ';

  return (
    <Animated.View style={[styles.toast, {
      opacity, translateY,
      backgroundColor: bgColor, borderColor,
    }]}>
      <Text style={styles.icon}>{icon}</Text>
      <Text style={[styles.message, { color: textColor }]} numberOfLines={2}>
        {item.message}
      </Text>
    </Animated.View>
  );
}

export default function ToastHost() {
  const [toasts, setToasts] = useState([]);

  useEffect(() => {
    showToastFn = (message, type) => {
      const id = ++toastId;
      setToasts(prev => [...prev, { id, message, type }].slice(-3));
    };
    return () => { showToastFn = null; };
  }, []);

  const dismiss = id => {
    setToasts(prev => prev.filter(t => t.id !== id));
  };

  if (toasts.length === 0) return null;

  return (
    <View style={styles.container} pointerEvents="none">
      {toasts.map(t => (
        <ToastItem key={t.id} item={t} onDone={dismiss} />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute', top: 60, left: 0, right: 0,
    alignItems: 'center', zIndex: 999,
  },
  toast: {
    flexDirection: 'row', alignItems: 'center', gap: 8,
    paddingHorizontal: 16, paddingVertical: 10,
    borderRadius: 10, borderWidth: 1,
    marginBottom: 6, maxWidth: 300,
    shadowColor: '#000', shadowOpacity: 0.5,
    shadowRadius: 8, shadowOffset: { width: 0, height: 2 },
    elevation: 6,
  },
  icon: { fontSize: 14, fontWeight: '700', color: '#f0e6d2' },
  message: { fontSize: 13, flex: 1 },
});
