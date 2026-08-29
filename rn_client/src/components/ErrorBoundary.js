import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';

/**
 * 全局错误边界：捕获 React 渲染异常，显示友好提示而非白屏。
 * 不吞异步错误（那是 Promise catch 的事），只管渲染层崩溃。
 */
export default class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('[ErrorBoundary]', error, errorInfo);
  }

  handleReset = () => {
    this.setState({ hasError: false, error: null });
  };

  render() {
    if (!this.state.hasError) return this.props.children;
    return (
      <View style={styles.screen}>
        <Text style={styles.icon}>⚔</Text>
        <Text style={styles.title}>界面出了点问题</Text>
        <Text style={styles.desc}>
          渲染遇到了异常，游戏数据不受影响。{'\n'}
          点击重试返回游戏，或退出重新进入。
        </Text>
        {this.state.error && (
          <Text style={styles.detail} numberOfLines={3}>
            {String(this.state.error.message || this.state.error).slice(0, 200)}
          </Text>
        )}
        <TouchableOpacity style={styles.retryBtn} onPress={this.handleReset}>
          <Text style={styles.retryText}>重试</Text>
        </TouchableOpacity>
      </View>
    );
  }
}

const styles = StyleSheet.create({
  screen: {
    flex: 1, backgroundColor: '#0d0b0e',
    alignItems: 'center', justifyContent: 'center', padding: 32, gap: 12,
  },
  icon: { fontSize: 48, color: '#ff4d6d' },
  title: { color: '#f0e6d2', fontSize: 20, fontWeight: '700' },
  desc: { color: '#a89aa8', fontSize: 14, textAlign: 'center', lineHeight: 22 },
  detail: {
    color: '#6a5a6a', fontSize: 11, textAlign: 'center',
    backgroundColor: '#1a141c', borderRadius: 8, padding: 8,
    borderWidth: 1, borderColor: '#2e2430',
  },
  retryBtn: {
    marginTop: 8, paddingHorizontal: 32, paddingVertical: 12,
    borderRadius: 999, backgroundColor: '#7a0d1f',
    borderWidth: 1, borderColor: '#ff4d6d',
  },
  retryText: { color: '#ffe3e8', fontSize: 16, fontWeight: '600' },
});
