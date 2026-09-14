/**
 * 一键注册：自动生成符合服务端规则的账号与密码（纯函数，离线TestUnit覆盖）。
 * 账号规则同 registerForm：4-12位字母数字；密码≥4位。
 * 账号前缀 xda + 8位随机小写字母数字，碰撞概率≈36^8≈2.8e12，足够一次性使用。
 */

function randomAlnum(length) {
  const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
  let out = '';
  for (let i = 0; i < length; i++)
    out += chars[Math.floor(Math.random() * chars.length)];
  return out;
}

export function generateAccount() {
  return 'xda' + randomAlnum(8);
}

export function generatePassword() {
  return randomAlnum(10);
}

/** 注册+登录凭据的剪贴板文本。 */
export function credentialsText(partition, userid, password) {
  return `账号：${partition}${userid}\n密码：${password}`;
}
