import React, { memo, useCallback } from 'react';
import { View, Text, TextInput, TouchableOpacity, Image, StyleSheet } from 'react-native';
import {
  flattenTextParts, buttonStyleFor, resolveImageUrl, buildInputCommand,
} from '../utils/segments.js';

/**
 * 单行渲染组件（React.memo）：flushview 全量替换时，key 相同的行
 * 跳过重绘，只渲染新增/变化的行。战斗中每秒刷新的性能关键路径。
 */
export const LineItem = memo(function LineItem({ line, ctx }) {
  return (
    <View style={styles.line}>
      {renderSegments(line, ctx)}
    </View>
  );
}, (prev, next) => {
  /* 精确比较：key变了才重绘，ctx的busy/imageBase/fontScale变了也重绘。 */
  if (prev.ctx.busy !== next.ctx.busy) return false;
  if (prev.ctx.imageBase !== next.ctx.imageBase) return false;
  if (prev.ctx.inputValues !== next.ctx.inputValues) return false;
  if (prev.ctx.fontScale !== next.ctx.fontScale) return false;
  return true; /* line的key由FlatList keyExtractor保证一致性 */
});

function renderSegments(line, ctx) {
  const segments = (line && line.segments) || [];
  const fontScale = ctx.fontScale || 1;
  return segments.map((segment, index) => {
    if (!segment || !segment.type) return null;
    if (segment.type === 'text') {
      const units = flattenTextParts(segment.parts);
      return (
        <Text key={index} style={[styles.text, {
          fontSize: Math.round(15 * fontScale),
          lineHeight: Math.round(22 * fontScale),
        }]}>
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
          }, ctx.busy && { opacity: 0.5 }]}
          disabled={ctx.busy}
          activeOpacity={0.4}
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
      const uri = resolveImageUrl(ctx.imageBase, segment.src);
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
  line: {
    paddingVertical: 4, flexDirection: 'row', flexWrap: 'wrap',
    alignItems: 'center', gap: 5,
  },
  text: { color: '#F0E6D2', fontSize: 15, lineHeight: 22, flexShrink: 1 },
  button: {
    paddingHorizontal: 11, minHeight: 32, borderRadius: 9,
    borderWidth: 1, marginVertical: 3,
    alignItems: 'center', justifyContent: 'center',
  },
  buttonText: { fontSize: 14 },
  inlineInput: {
    backgroundColor: '#1a141c', borderRadius: 8, paddingHorizontal: 10,
    paddingVertical: 6, color: '#F0E6D2', fontSize: 14,
    borderWidth: 1, borderColor: '#3a2f46', minWidth: 130, minHeight: 34,
  },
  image: { width: 76, height: 76, borderRadius: 10, marginVertical: 4 },
});
