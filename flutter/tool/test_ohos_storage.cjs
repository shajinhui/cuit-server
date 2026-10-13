// Runtime simulation of ArkTS storage using Node crypto; this does not replace DevEco compilation.
// Requires the existing TypeScript dependency from apps/web (pnpm install).
const assert = require('node:assert/strict');
const fs = require('node:fs');
const crypto = require('node:crypto');
const vm = require('node:vm');
const path = require('node:path');
const ts = require(path.resolve(__dirname, '../../apps/web/node_modules/typescript'));
const source = fs.readFileSync(path.resolve(__dirname, '../ohos/entry/src/main/ets/platform/HarmonySecureStorage.ets'), 'utf8');
const compiled = ts.transpileModule(source, {compilerOptions: {target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS}, reportDiagnostics: true});
assert.equal(compiled.diagnostics.length, 0);
const data = new Map();
const assets = new Map();
let keyAdds = 0;
const prefs = {getAllSync: () => Object.fromEntries(data), hasSync: k => data.has(k), getSync: (k, fallback) => data.get(k) ?? fallback, put: async (k,v) => data.set(k,v), delete: async k => data.delete(k), flush: async () => {}};
const key = bytes => ({getEncoded: () => ({data: new Uint8Array(bytes)}), bytes: Buffer.from(bytes)});
const kits = {
  '@ohos/flutter_ohos': {MethodChannel: class {setMethodCallHandler(handler) {this.handler = handler;}}},
  '@kit.AssetStoreKit': {asset: {
    Tag: {ALIAS: 1, SECRET: 2, RETURN_TYPE: 3, ACCESSIBILITY: 4}, ReturnType: {ALL: 1}, Accessibility: {DEVICE_FIRST_UNLOCKED: 0},
    query: async q => {const found = assets.get(Buffer.from(q.get(1)).toString()); if (!found) throw Object.assign(new Error('missing'), {code: 24000002}); return [found];},
    add: async attrs => {keyAdds++; assets.set(Buffer.from(attrs.get(1)).toString(), new Map(attrs));}
  }},
  '@kit.ArkData': {preferences: {getPreferencesSync: () => prefs}},
  '@kit.ArkTS': {util: {
    TextEncoder: class {encodeInto(s) {return new TextEncoder().encode(s);}}, TextDecoder: {create: () => ({decodeToString: bytes => new TextDecoder().decode(bytes)})},
    Base64Helper: class {encodeToStringSync(b) {return Buffer.from(b).toString('base64');} decodeSync(s) {return new Uint8Array(Buffer.from(s, 'base64'));}}
  }},
  '@kit.CryptoArchitectureKit': {cryptoFramework: {
    CryptoMode: {ENCRYPT_MODE: 1, DECRYPT_MODE: 2},
    createMd: () => {const h = crypto.createHash('sha256'); return {update: async b => h.update(b.data), digest: async () => ({data: new Uint8Array(h.digest())})};},
    createSymKeyGenerator: () => ({generateSymKeySync: () => key(crypto.randomBytes(32)), convertKeySync: b => key(b.data)}),
    createRandom: () => ({generateRandomSync: n => ({data: new Uint8Array(crypto.randomBytes(n))})}),
    createCipher: () => {
      let c, encrypt;
      return {initSync: (mode, k, p) => {encrypt = mode === 1; c = encrypt ? crypto.createCipheriv('aes-256-gcm', k.bytes, p.iv.data) : crypto.createDecipheriv('aes-256-gcm', k.bytes, p.iv.data); c.setAAD(p.aad.data); if (!encrypt) c.setAuthTag(p.authTag.data);}, updateSync: b => ({data: new Uint8Array(c.update(b.data))}), doFinalSync: () => {c.final(); return {data: new Uint8Array(encrypt ? c.getAuthTag() : [])};}};
    }
  }}
};
const moduleValue = {exports: {}};
vm.runInNewContext(compiled.outputText, {module: moduleValue, exports: moduleValue.exports, require: name => {assert.ok(kits[name], name); return kits[name];}, Uint8Array, TextEncoder, TextDecoder, Map, Promise, Error});
const Store = moduleValue.exports.default;
function create() {const s = new Store(); s.onAttachedToEngine({getApplicationContext: () => ({}), getBinaryMessenger: () => ({})}); return s;}
function call(s, method, args) {return new Promise((resolve, reject) => s.onMethodCall({method, args: new Map(Object.entries(args))}, {success: resolve, error: (code, message, details) => reject(Object.assign(new Error(message), {code, details})), notImplemented: () => reject(new Error('not implemented'))}));}
(async () => {
  const s = create();
  assert.equal(await call(s, 'read', {key: 'missing'}), null);
  const largeValue = '中文头像与 Cookie'.repeat(1000);
  await Promise.all([call(s, 'write', {key: 'account:1:token', value: largeValue}), call(s, 'write', {key: 'account:10:token', value: 'retain'})]);
  assert.equal(keyAdds, 1, 'first writes must share one persisted key');
  assert.equal(await call(s, 'read', {key: 'account:1:token'}), largeValue);
  assert.ok([...data.keys()].every(k => !k.includes('account')), 'keys must be hashed');
  assert.ok([...data.values()].every(v => !v.includes('中文') && !v.includes('retain')), 'values must be ciphertext');
  const restarted = create();
  assert.equal(await call(restarted, 'read', {key: 'account:1:token'}), largeValue, 'cold restart decrypts with ASSET key');
  await call(restarted, 'deleteByPrefix', {prefix: 'account:1:'});
  assert.equal(await call(restarted, 'read', {key: 'account:1:token'}), null);
  assert.equal(await call(restarted, 'read', {key: 'account:10:token'}), 'retain', 'logout keeps other accounts');
  const alias = [...data.keys()][0];
  const original = data.get(alias);
  const tampered = Buffer.from(original, 'base64'); tampered[0] ^= 1; data.set(alias, tampered.toString('base64'));
  await assert.rejects(call(restarted, 'read', {key: 'account:10:token'}), {code: 'secure_storage_failed'}, 'tampering must never return plaintext');
  data.set(alias, original);
  assert.equal(await call(restarted, 'read', {key: 'account:10:token'}), 'retain', 'failure must not break queue');
  await call(restarted, 'write', {key: 'second', value: 'second'});
  const secondAlias = [...data.keys()].find(k => k !== alias);
  const secondCiphertext = data.get(secondAlias); data.set(alias, secondCiphertext);
  await assert.rejects(call(restarted, 'read', {key: 'account:10:token'}), {code: 'secure_storage_failed'}, 'AAD prevents ciphertext swapping');
  data.set(alias, original);
  assets.clear();
  const lostKey = create();
  await assert.rejects(call(lostKey, 'write', {key: 'third', value: 'third'}), {code: 'secure_storage_failed'}, 'lost key must not be regenerated over ciphertext');
  assert.equal(keyAdds, 1);
  assert.equal(data.size, 2);
  console.log('Native storage runtime simulation passed: cold restart, >1KB Unicode, concurrent initialization, account isolation, authenticated ciphertext, failure recovery, missing-key preservation. DevEco compilation still required.');
})().catch(e => {console.error(e); process.exitCode = 1;});
