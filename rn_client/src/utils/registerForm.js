/**
 * 注册表单校验（纯函数，离线TestUnit覆盖）。
 * 账号规则与服务端注册通道一致：4-12位字母数字，密码≥4位。
 */
export function validateRegisterForm(form) {
  const userid = String((form && form.userid) || '').trim();
  const password = String((form && form.password) || '');
  const confirm = String((form && form.confirm) || '');
  if (!form || !form.partition) return '请选择分区';
  if (userid.length < 4 || userid.length > 12)
    return '账号需4-12个字符';
  if (!/^[a-zA-Z0-9]+$/.test(userid)) return '账号只能用字母或数字';
  if (password.length < 4) return '密码至少4位';
  if (password !== confirm) return '两次输入的密码不一致';
  return '';
}
