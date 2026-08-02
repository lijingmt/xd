const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

let componentOptions = null;
const sessionValues = new Map();
const sandbox = {
  Vue: {
    createApp(options) {
      componentOptions = options;
      return { mount() {} };
    }
  },
  window: {
    crypto: {},
    location: { protocol: 'https:', hostname: 'game.example.com' },
    matchMedia() { return { matches: false }; }
  },
  document: { documentElement: { setAttribute() {} } },
  localStorage: { getItem() { return null; }, setItem() {} },
  sessionStorage: {
    getItem(key) { return sessionValues.get(key) || null; },
    setItem(key, value) { sessionValues.set(key, value); },
    removeItem(key) { sessionValues.delete(key); }
  },
  console,
  TextEncoder,
  URLSearchParams,
  btoa(value) { return Buffer.from(value, 'binary').toString('base64'); },
  setTimeout,
  clearTimeout,
  setInterval() { return 1; },
  clearInterval() {},
  fetch: async () => ({ ok: true, json: async () => ({}) })
};

const appSource = fs.readFileSync(
  path.join(__dirname, '..', 'js', 'app.js'), 'utf8'
);
const indexSource = fs.readFileSync(
  path.join(__dirname, '..', 'index.html'), 'utf8'
);
const cssSource = fs.readFileSync(
  path.join(__dirname, '..', 'css', 'app.css'), 'utf8'
);
vm.runInNewContext(appSource, sandbox, { filename: 'app.js' });

assert(componentOptions, 'Vue component should register');
const client = Object.assign(componentOptions.data(), componentOptions.methods);

assert.strictEqual(client.professionOptions.length, 10);
assert.deepStrictEqual(
  [...new Set(client.professionOptions.map(option => option.profession_id))].length,
  10
);
assert(client.professionOptions.some(option => option.profession_id === 'fangshi'));
assert(client.professionOptions.some(option => option.profession_id === 'lingyi'));

client.applyAccountData({
  token: 'a'.repeat(64),
  account_id: 'xd01legacy',
  limit: 10,
  characters: [{ id: 'xd01legacy', profession_id: 'jianxian' }]
});
assert.strictEqual(client.accountId, 'xd01legacy');
assert.strictEqual(client.accountCharacters.length, 1);
assert.strictEqual(sessionValues.get('mud_account_token'), 'a'.repeat(64));
assert.strictEqual(sessionValues.get('mud_account_id'), 'xd01legacy');

client.chooseNewProfession(
  client.professionOptions.find(option => option.profession_id === 'jianxian')
);
assert(client.characterError.includes('已经拥有'));
client.chooseNewProfession(
  client.professionOptions.find(option => option.profession_id === 'fangshi')
);
assert.strictEqual(client.characterForm.race_id, 'third');
assert.strictEqual(client.characterForm.profession_id, 'fangshi');

client.clearAccountSession();
assert.strictEqual(client.accountToken, '');
assert.strictEqual(sessionValues.has('mud_account_token'), false);

assert(indexSource.includes('v-if="showCharacterSelect"'));
assert(indexSource.includes('@click="openCharacterCenter"'));
assert(indexSource.includes('@click="createAccountCharacter"'));
assert(indexSource.includes('!showRegister && !showCharacterSelect'));
assert(cssSource.includes('.character-modal'));
assert(cssSource.includes('.profession-choice-grid'));
assert(appSource.includes("'/api/account/login'"));
assert(appSource.includes("postAccountApi('/api/account/characters'"));
assert(!appSource.includes("'/api/account/characters?'"));
assert(appSource.includes("'/api/account/characters/select'"));
assert(appSource.includes('error.status === 404 || error.status === 501'));

console.log('account character frontend tests passed');
