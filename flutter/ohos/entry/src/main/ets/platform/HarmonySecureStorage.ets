import {
  FlutterPlugin, FlutterPluginBinding, MethodCall, MethodCallHandler,
  MethodChannel, MethodResult
} from '@ohos/flutter_ohos';
import { asset } from '@kit.AssetStoreKit';
import { preferences } from '@kit.ArkData';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';

interface StoredValue {
  key: string;
  value: string;
}

/** ASSET protects the AES key; preferences contain only authenticated ciphertext. */
export default class HarmonySecureStorage implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private data: preferences.Preferences | null = null;
  private secretKey: cryptoFramework.SymKey | null = null;
  private pending: Promise<void> = Promise.resolve();
  private readonly keyAlias: string = 'chengxin_youyou.secure_storage.aes.v1';
  private readonly base64: util.Base64Helper = new util.Base64Helper();

  getUniqueClassName(): string {
    return 'chengxin_youyou.HarmonySecureStorage';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.data = preferences.getPreferencesSync(binding.getApplicationContext(), {
      name: 'chengxin_secure_storage_v1'
    });
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'chengxin_youyou/secure_storage');
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
    this.secretKey = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    // Serialize initialization, writes and prefix deletion so logout cannot race
    // an earlier write and leave credentials behind. Failure does not break the queue.
    this.pending = this.pending.then(async (): Promise<void> => {
      const args = call.args as Map<string, string>;
      const key = args.get('key') ?? '';
      if (this.data === null) throw new Error('Storage is unavailable');
      switch (call.method) {
        case 'read': {
          const alias = await this.storageAlias(key);
          const stored = await this.readValue(alias);
          if (stored !== null && stored.key !== key) throw new Error('Storage key mismatch');
          result.success(stored?.value ?? null);
          break;
        }
        case 'write': {
          const alias = await this.storageAlias(key);
          const value = args.get('value');
          if (value === undefined) throw new Error('Missing value');
          const stored: StoredValue = { key, value };
          const encrypted = await this.encrypt(alias, JSON.stringify(stored));
          await this.data.put(alias, encrypted);
          await this.data.flush();
          result.success(null);
          break;
        }
        case 'delete': {
          await this.data.delete(await this.storageAlias(key));
          await this.data.flush();
          result.success(null);
          break;
        }
        case 'deleteByPrefix': {
          const prefix = args.get('prefix');
          if (prefix === undefined || prefix.length === 0) throw new Error('Missing prefix');
          const aliases = Object.keys(this.data.getAllSync());
          // Decrypt before mutating, so an unreadable item cannot cause partial deletion.
          const matching: string[] = [];
          for (const alias of aliases) {
            const stored = await this.readValue(alias);
            if (stored !== null && stored.key.startsWith(prefix)) matching.push(alias);
          }
          for (const alias of matching) await this.data.delete(alias);
          await this.data.flush();
          result.success(null);
          break;
        }
        default:
          result.notImplemented();
      }
    }).catch((error: BusinessError): void => {
      // Do not include keys, credentials or native error details in channel output.
      result.error('secure_storage_failed', '无法访问鸿蒙安全存储，请解锁设备后重试。', error.code ?? null);
    });
  }

  private toBytes(value: string): Uint8Array {
    return new util.TextEncoder().encodeInto(value);
  }

  private fromBytes(value: Uint8Array): string {
    return util.TextDecoder.create('utf-8', { ignoreBOM: true })
      .decodeToString(value, { stream: false });
  }

  private async storageAlias(key: string): Promise<string> {
    if (key.length === 0) throw new Error('Missing key');
    const digest = cryptoFramework.createMd('SHA256');
    await digest.update({ data: this.toBytes(key) });
    return 'v1_' + this.base64.encodeToStringSync((await digest.digest()).data);
  }

  private async getKey(): Promise<cryptoFramework.SymKey> {
    if (this.secretKey !== null) return this.secretKey;
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.toBytes(this.keyAlias));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    const generator = cryptoFramework.createSymKeyGenerator('AES256');
    let matches: Array<asset.AssetMap> = [];
    try {
      matches = await asset.query(query);
    } catch (error) {
      const failure = error as BusinessError;
      if (failure.code !== 24000002) throw error;
    }
    if (matches.length > 0) {
      this.secretKey = generator.convertKeySync({
        data: matches[0].get(asset.Tag.SECRET) as Uint8Array
      });
      return this.secretKey;
    }
    // Never replace a lost key while ciphertext exists: surface the failure.
    if (this.data === null || Object.keys(this.data.getAllSync()).length > 0) {
      throw new Error('Encryption key is missing');
    }
    const key = generator.generateSymKeySync();
    const attributes: asset.AssetMap = new Map();
    attributes.set(asset.Tag.ALIAS, this.toBytes(this.keyAlias));
    attributes.set(asset.Tag.SECRET, key.getEncoded().data);
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
    // Default ASSET policy: no synchronization, deleted with the application.
    await asset.add(attributes);
    this.secretKey = key;
    return key;
  }

  private params(alias: string, iv: Uint8Array, tag: Uint8Array): cryptoFramework.GcmParamsSpec {
    return {
      algName: 'GcmParamsSpec',
      iv: { data: iv },
      aad: { data: this.toBytes(alias) },
      authTag: { data: tag }
    };
  }

  private async encrypt(alias: string, value: string): Promise<string> {
    const key = await this.getKey();
    const iv = cryptoFramework.createRandom().generateRandomSync(12).data;
    const cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
    cipher.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, key,
      this.params(alias, iv, new Uint8Array(16)));
    const encrypted = cipher.updateSync({ data: this.toBytes(value) }).data;
    const tag = cipher.doFinalSync(null).data;
    const payload = new Uint8Array(tag.length + iv.length + encrypted.length);
    payload.set(tag, 0);
    payload.set(iv, tag.length);
    payload.set(encrypted, tag.length + iv.length);
    return this.base64.encodeToStringSync(payload);
  }

  private async readValue(alias: string): Promise<StoredValue | null> {
    if (this.data === null) throw new Error('Storage is unavailable');
    if (!this.data.hasSync(alias)) return null;
    const payload = this.base64.decodeSync(this.data.getSync(alias, '') as string);
    if (payload.length <= 28) throw new Error('Invalid ciphertext');
    const cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
    cipher.initSync(cryptoFramework.CryptoMode.DECRYPT_MODE, await this.getKey(),
      this.params(alias, payload.slice(16, 28), payload.slice(0, 16)));
    const plaintext = cipher.updateSync({ data: payload.slice(28) }).data;
    cipher.doFinalSync(null); // GCM authentication must succeed before exposing plaintext.
    return JSON.parse(this.fromBytes(plaintext)) as StoredValue;
  }
}
