/**
 * 内购 API：客户端购买由 react-native-iap 完成（可注入，供TestUnit），
 * 收据校验入账走服务端 /api/iap_verify（Apple验签 + 账号钱包幂等）。
 */

/* 售价以 App Store Connect 档位为准（美区账号，USD 结算）；
 * 客户端展示用 StoreKit 返回的本地化价格，入账按产品名固定碎玉数。 */
export const IAP_PRODUCTS = [
  {
    sku: 'com.wapmud.xiandao.1000suiyu',
    label: '1000碎玉',
    desc: '账号共享充值余额，全角色通用',
  },
  {
    sku: 'com.wapmud.xiandao.3000suiyu',
    label: '3000碎玉',
    desc: '账号共享充值余额，全角色通用',
  },
  {
    sku: 'com.wapmud.xiandao.10000suiyu',
    label: '10000碎玉',
    desc: '账号共享充值余额，全角色通用',
  },
];

/** 提取购买凭据（iOS）：优先 transaction 上的 receipt/transactionId。 */
export function extractAppleReceipt(purchase) {
  if (!purchase) return null;
  const receipt =
    purchase.transactionReceipt || purchase.receipt ||
    (purchase.transaction && purchase.transaction.receipt) || '';
  const transactionId =
    purchase.transactionId ||
    (purchase.transaction && purchase.transaction.id) ||
    (purchase.originalTransactionIdIOS) || '';
  const productId =
    purchase.productId ||
    (purchase.transaction && purchase.transaction.productId) || '';
  if (!receipt || !transactionId || !productId) return null;
  return { receipt: String(receipt), transactionId: String(transactionId),
    productId: String(productId) };
}

/**
 * 收集购买凭据（v15+ OpenIAP 兼容）：新版购买对象没有内嵌
 * transactionReceipt，改用 getReceiptDataIOS 拉整份App收据
 * （服务端按 transaction_id 在收据的 in_app 列表中精确匹配）。
 */
export async function collectAppleCredentials(purchase, iap) {
  if (!purchase) return null;
  const productId = String(purchase.productId ||
    (purchase.transaction && purchase.transaction.productId) || '');
  const transactionId = String(purchase.transactionId ||
    (purchase.transaction && purchase.transaction.id) || '');
  let receipt = purchase.transactionReceipt || purchase.receipt ||
    (purchase.transaction && purchase.transaction.receipt) || '';
  if (!receipt && iap && typeof iap.getReceiptDataIOS === 'function') {
    try {
      receipt = await iap.getReceiptDataIOS();
    } catch (e) {
      receipt = '';
    }
    if (!receipt &&
        typeof iap.requestReceiptRefreshIOS === 'function') {
      try {
        await iap.requestReceiptRefreshIOS();
        receipt = await iap.getReceiptDataIOS();
      } catch (e) {
        receipt = '';
      }
    }
  }
  if (!receipt || !transactionId || !productId) return null;
  return {
    receipt: String(receipt),
    transactionId,
    productId,
  };
}

export async function verifyIapPurchase(apiBase, txd, credentials,
    fetchImpl) {
  const fetchFn = fetchImpl || fetch;
  const response = await fetchFn(`${apiBase}/api/iap_verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      txd,
      receipt: credentials.receipt,
      product_id: credentials.productId,
      transaction_id: credentials.transactionId,
    }),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error((data && data.error) || `HTTP ${response.status}`);
  }
  return data;
}

/**
 * 充值控制器（纯函数层，iap模块注入；null时安全降级）。
 * 购买结果由 purchaseUpdatedListener 回调交回调用方验证入账。
 */
export function createRechargeController(iap) {
  return {
    async fetchProducts() {
      if (!iap) return [];
      await iap.initConnection();
      /* v15+ 方法名为 fetchProducts；旧版为 getProducts，双兜底。 */
      const fetcher = iap.fetchProducts || iap.getProducts;
      if (typeof fetcher !== 'function') {
        throw new Error('内购模块不支持产品查询');
      }
      const result = await fetcher({
        skus: IAP_PRODUCTS.map(product => product.sku),
        type: 'inapp',
      });
      /* 新版可能返回 {products:[...]}; 旧版直接返回数组。 */
      if (Array.isArray(result)) return result;
      if (result && Array.isArray(result.products)) {
        return result.products;
      }
      return [];
    },
    async purchase(sku) {
      if (!iap) throw new Error('当前环境不支持内购');
      await iap.requestPurchase({
        request: { apple: { sku } },
        type: 'in-app',
      });
    },
    async finish(purchase) {
      if (iap && iap.finishTransaction && purchase) {
        await iap.finishTransaction({ purchase, isConsumable: true })
          .catch(() => {});
      }
    },
    async close() {
      if (iap && iap.endConnection) {
        await iap.endConnection().catch(() => {});
      }
    },
  };
}
