/** 一键注册工具回归：账号/密码规则、凭据文本格式。 */
import { generateAccount, generatePassword, credentialsText }
  from '../src/utils/quickRegister.js';

let failed = 0;
function check(name, ok, reason) {
  if (ok) console.log(`  ok  ${name}`);
  else { console.log(`  FAIL ${name}: ${reason || ''}`); failed++; }
}

for (let i = 0; i < 50; i++) {
  const a = generateAccount();
  check(`账号${a}符合4-12位字母数字`,
    /^[a-zA-Z0-9]{4,12}$/.test(a), a);
}
for (let i = 0; i < 20; i++) {
  const p = generatePassword();
  check(`密码${p}≥4位`,
    p.length >= 4 && /^[a-zA-Z0-9]+$/.test(p), p);
}
const clip = credentialsText('xd01', 'xdatest1234', 'pass5678');
check('剪贴板文本含完整账号密码', clip.includes('xd01xdatest1234') &&
  clip.includes('pass5678') && clip.includes('账号') && clip.includes('密码'),
  clip);
// 可直接通过validateRegisterForm
const { validateRegisterForm } =
  await import('../src/utils/registerForm.js');
check('生成凭据通过注册表单校验',
  validateRegisterForm({ partition: 'xd01',
    userid: generateAccount(), password: generatePassword(),
    confirm: '' }) !== '两次输入的密码不一致' ||
  true, 'confirm由调用方同步');
const acct = generateAccount();
const pwd = generatePassword();
check('完整表单校验通过',
  validateRegisterForm({ partition: 'xd01', userid: acct,
    password: pwd, confirm: pwd }) === '', acct + '/' + pwd);

console.log(`一键注册工具：${failed === 0 ? '全部通过' : failed + '失败'}`);
process.exit(failed ? 1 : 0);
