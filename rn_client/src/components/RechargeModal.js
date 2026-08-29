import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  View, Text, Modal, TouchableOpacity, StyleSheet,
  ActivityIndicator, Pressable, Platform,
} from 'react-native';
import { useGameStore } from '../store/useGameStore.js';
import { createRechargeController, collectAppleCredentials,
  verifyIapPurchase, IAP_PRODUCTS } from '../api/iapApi.js';

function productSku(product) {
  return product.id || product.productId || '';
}

function productPriceText(product) {
  return product.displayPrice || product.localizedPrice ||
    product.price || '';
}

/**
 * 内购充值弹窗（iOS）：react-native-iap 拉取产品 → 购买 →
 * 收据提交服务端 /api/iap_verify 入账账号共享钱包。
 * iap 模块仅在 iOS 原生环境加载；其余平台安全降级。
 */
let iapModuleCache = null;

function getIapModule() {
  if (Platform.OS !== 'ios') return null;
  if (!iapModuleCache) {
    const loaded = require('react-native-iap');
    iapModuleCache = loaded.default || loaded;
  }
  return iapModuleCache;
}

export default function RechargeModal({ visible, onClose }) {
  const apiBase = useGameStore(state => state.apiBase);
  const txd = useGameStore(state => state.txd);
  const [products, setProducts] = useState([]);
  const [phase, setPhase] = useState('idle'); /* idle|loading|buying|verifying|done|error */
  const [message, setMessage] = useState('');
  const [balance, setBalance] = useState(null);
  const controllerRef = useRef(null);
  const purchaseRef = useRef(null);
  const closedRef = useRef(false);

  const iap = getIapModule();
  const controller = createRechargeController(iap);

  useEffect(() => {
    if (!visible) {
      closedRef.current = false;
      return;
    }
    let mounted = true;
    setPhase('loading');
    setMessage('');
    setBalance(null);
    controller.fetchProducts()
      .then(list => {
        if (!mounted) return;
        setProducts(list);
        setPhase('idle');
      })
      .catch(e => {
        if (!mounted) return;
        setPhase('error');
        setMessage(`产品加载失败: ${e.message}`);
      });
    return () => { mounted = false; };
  }, [visible]);

  /* 购买回调：收据 → 服务端验证入账。 */
  useEffect(() => {
    if (!visible || !iap) return;
    const updateSub = iap.purchaseUpdatedListener &&
      iap.purchaseUpdatedListener(async purchase => {
        const credentials = await collectAppleCredentials(purchase, iap);
        if (!credentials || purchaseRef.current === credentials.transactionId) {
          return;
        }
        purchaseRef.current = credentials.transactionId;
        setPhase('verifying');
        setMessage('正在验证收据并入账…');
        try {
          const result = await verifyIapPurchase(apiBase, txd, credentials);
          await controller.finish(purchase);
          setBalance(result.balance);
          setPhase('done');
          setMessage(result.duplicate
            ? '本笔充值已入账（请勿重复提交）'
            : `充值成功，账号碎玉余额 ${result.balance}`);
          /* 顶栏碎玉数字立即刷新。 */
          useGameStore.getState().refreshStatus();
        } catch (e) {
          setPhase('error');
          setMessage(`入账失败: ${e.message}`);
        }
      });
    const errorSub = iap.purchaseErrorListener &&
      iap.purchaseErrorListener(error => {
        setPhase('error');
        setMessage(`购买未完成: ${(error && error.message) || '已取消'}`);
      });
    return () => {
      if (updateSub && updateSub.remove) updateSub.remove();
      if (errorSub && errorSub.remove) errorSub.remove();
    };
  }, [visible, apiBase, txd]);

  const buy = useCallback(async sku => {
    setPhase('buying');
    setMessage('');
    try {
      await controller.purchase(sku);
    } catch (e) {
      setPhase('error');
      setMessage(`发起购买失败: ${e.message}`);
    }
  }, []);

  const close = useCallback(() => {
    controller.close().catch(() => {});
    purchaseRef.current = null;
    onClose();
  }, [onClose]);

  return (
    <Modal visible={visible} transparent animationType="fade"
      onRequestClose={close}>
      <Pressable style={styles.overlay} onPress={close}>
        <View style={styles.panel}
          onStartShouldSetResponder={() => true}>
          <Text style={styles.title}>💎 碎玉充值</Text>
          <Text style={styles.subtitle}>
            账号共享余额 · 全角色通用 · 苹果内购
          </Text>

          {phase === 'loading' && (
            <View style={styles.center}>
              <ActivityIndicator color="#d4af37" />
              <Text style={styles.hint}>正在获取商品…</Text>
            </View>
          )}

          {phase !== 'loading' && products.map(product => {
            const sku = productSku(product);
            const meta = IAP_PRODUCTS.find(item => item.sku === sku);
            return (
              <TouchableOpacity key={sku}
                style={styles.productCard}
                disabled={phase === 'buying' || phase === 'verifying'}
                onPress={() => buy(sku)}>
                <View style={{ flex: 1 }}>
                  <Text style={styles.productName}>
                    {meta ? meta.label :
                      (product.displayName || product.title || '碎玉')}
                  </Text>
                  <Text style={styles.productDesc} numberOfLines={2}>
                    {meta ? meta.desc :
                      (product.description || '账号共享充值余额')}
                  </Text>
                </View>
                <View style={styles.pricePill}>
                  <Text style={styles.priceText}>
                    {productPriceText(product) || '购买'}
                  </Text>
                </View>
              </TouchableOpacity>
            );
          })}

          {phase !== 'loading' && !products.length && phase === 'error' && (
            <Text style={styles.errorText}>{message || '商品不可用'}</Text>
          )}

          {(phase === 'buying' || phase === 'verifying') && (
            <View style={styles.center}>
              <ActivityIndicator color="#d4af37" />
              <Text style={styles.hint}>
                {phase === 'buying' ? '等待苹果支付…' : message}
              </Text>
            </View>
          )}

          {phase === 'done' && (
            <View style={styles.doneBox}>
              <Text style={styles.doneText}>✓ {message}</Text>
              {balance != null && (
                <Text style={styles.balanceText}>碎玉余额：{balance}</Text>
              )}
            </View>
          )}
          {phase === 'error' && !!message && phase !== 'idle' &&
            products.length > 0 && (
            <Text style={styles.errorText}>{message}</Text>
          )}

          <TouchableOpacity style={styles.closeButton} onPress={close}>
            <Text style={styles.closeText}>
              {phase === 'done' ? '完成' : '关闭'}
            </Text>
          </TouchableOpacity>
        </View>
      </Pressable>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1, backgroundColor: 'rgba(5,3,8,0.72)',
    alignItems: 'center', justifyContent: 'center',
  },
  panel: {
    width: '86%', borderRadius: 16, backgroundColor: '#17131c',
    borderWidth: 1, borderColor: '#3a2f46', padding: 18, gap: 12,
  },
  title: { color: '#ffd700', fontSize: 19, fontWeight: '700',
    textAlign: 'center' },
  subtitle: { color: '#8a7a8a', fontSize: 12, textAlign: 'center',
    marginBottom: 4 },
  productCard: {
    flexDirection: 'row', alignItems: 'center', gap: 12,
    backgroundColor: '#12101a', borderRadius: 12, borderWidth: 1,
    borderColor: '#8a6d2f', padding: 14,
  },
  productName: { color: '#f0e6d2', fontSize: 15, fontWeight: '600' },
  productDesc: { color: '#8a7a8a', fontSize: 12, marginTop: 4 },
  pricePill: {
    backgroundColor: '#2d2410', borderRadius: 10, borderWidth: 1,
    borderColor: '#d4af37', paddingHorizontal: 14, paddingVertical: 8,
  },
  priceText: { color: '#ffd700', fontSize: 15, fontWeight: '700' },
  center: { alignItems: 'center', gap: 8, paddingVertical: 10 },
  hint: { color: '#a89aa8', fontSize: 13 },
  doneBox: {
    backgroundColor: '#16241c', borderRadius: 12, borderWidth: 1,
    borderColor: '#6a8a5a', padding: 14, gap: 6,
  },
  doneText: { color: '#9ad0a0', fontSize: 14, textAlign: 'center' },
  balanceText: { color: '#ffd700', fontSize: 13, textAlign: 'center' },
  errorText: { color: '#ff9aa8', fontSize: 12, textAlign: 'center' },
  closeButton: {
    marginTop: 4, borderRadius: 10, borderWidth: 1, borderColor: '#6a5a7a',
    paddingVertical: 11, alignItems: 'center', backgroundColor: '#12101a',
  },
  closeText: { color: '#f0e6d2', fontSize: 14 },
});
