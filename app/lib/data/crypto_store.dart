import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class CryptoStore {
  CryptoStore({this.iterations = 150000});

  final int iterations;

  Future<Uint8List> encrypt(
    Uint8List plain,
    String passphrase,
  ) async {
    final Pbkdf2 kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final Uint8List salt = _randomBytes(16);
    final SecretKey secretKey = await kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );

    final AesGcm algorithm = AesGcm.with256bits();
    final Uint8List nonce = _randomBytes(12);
    final SecretBox box = await algorithm.encrypt(
      plain,
      secretKey: secretKey,
      nonce: nonce,
    );

    final BytesBuilder builder = BytesBuilder();
    builder.addByte(1); // version marker
    builder.add(salt);
    builder.add(nonce);
    builder.add(box.cipherText);
    builder.add(box.mac.bytes);
    return builder.toBytes();
  }

  Future<Uint8List> decrypt(
    Uint8List cipher,
    String passphrase,
  ) async {
    if (cipher.length < 1 + 16 + 12 + 16) {
      throw const FormatException('密文格式错误。');
    }

    final int version = cipher[0];
    if (version != 1) {
      throw const FormatException('不支持的密文版本。');
    }

    final Uint8List salt = Uint8List.sublistView(cipher, 1, 17);
    final Uint8List nonce = Uint8List.sublistView(cipher, 17, 29);
    final Uint8List macBytes =
        Uint8List.sublistView(cipher, cipher.length - 16);
    final Uint8List cipherText =
        Uint8List.sublistView(cipher, 29, cipher.length - 16);

    final Pbkdf2 kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final SecretKey secretKey = await kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );

    final AesGcm algorithm = AesGcm.with256bits();
    final SecretBox box = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    return Uint8List.fromList(
      await algorithm.decrypt(
        box,
        secretKey: secretKey,
      ),
    );
  }
}

Uint8List _randomBytes(int length) {
  final Random random = Random.secure();
  final Uint8List bytes = Uint8List(length);
  for (int i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}
