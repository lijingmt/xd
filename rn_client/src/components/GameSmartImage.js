import React, { useState } from 'react';
import { View, Text, Image } from 'react-native';

/** 图片加载：失败时显示占位方块而非空白。可复用组件。 */
export function SmartImage({ uri, style }) {
  const [failed, setFailed] = useState(false);
  if (failed || !uri) {
    return (
      <View style={[style, {
        backgroundColor: '#1a141c', borderWidth: 1, borderColor: '#3a2f46',
        alignItems: 'center', justifyContent: 'center',
      }]}>
        <Text style={{ fontSize: style && style.width > 40 ? 24 : 16,
          color: '#6a5a6a' }}>🖼</Text>
      </View>
    );
  }
  return (
    <Image source={{ uri }} style={style} resizeMode="contain"
      onError={() => setFailed(true)} />
  );
}
