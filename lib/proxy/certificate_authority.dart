import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Self-signed CA certificate generator and leaf certificate signer for MITM.
/// Uses RSA 2048 + SHA256 for compatibility with Android trust store.
class CertificateAuthority {
  late AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _caKeyPair;
  AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>? _sharedLeafKeyPair;
  final Map<String, SecurityContext> _hostContextCache = {};
  late Uint8List _caCertDer;
  late String _caCertPem;
  late String _caKeyPem;
  String _storePath = '';

  bool _ready = false;
  bool get ready => _ready;
  String get caCertPem => _caCertPem;
  Uint8List get caCertBytes => Uint8List.fromList(utf8.encode(_caCertPem));

  /// Initialize CA. Loads from disk or generates new.
  Future<void> init(String storagePath) async {
    _storePath = storagePath;
    final certFile = File('$storagePath/ca_cert.pem');
    final keyFile = File('$storagePath/ca_key.pem');
    final certDerFile = File('$storagePath/ca_cert.der');

    if (await certFile.exists() && await keyFile.exists() && await certDerFile.exists()) {
      _caCertPem = await certFile.readAsString();
      _caKeyPem = await keyFile.readAsString();
      _caCertDer = await certDerFile.readAsBytes();
      _caKeyPair = _loadKeyFromPem(_caKeyPem);
      _sharedLeafKeyPair = _generateRSAKeyPair(bitLength: 2048);
      _hostContextCache.clear();
      _ready = true;
    } else {
      await regenerate();
    }
  }

  /// Generate new CA key pair and self-signed certificate.
  Future<void> regenerate() async {
    _caKeyPair = _generateRSAKeyPair();
    _sharedLeafKeyPair = _generateRSAKeyPair(bitLength: 2048);
    _hostContextCache.clear();

    final now = DateTime.now();
    final notBefore = now.subtract(const Duration(days: 1));
    final notAfter = now.add(const Duration(days: 3650)); // 10 years

    _caCertDer = _buildCACertDer(
      _caKeyPair.publicKey,
      _caKeyPair.privateKey,
      notBefore,
      notAfter,
    );

    _caCertPem = _derToPem(_caCertDer, 'CERTIFICATE');
    _caKeyPem = _privateKeyToPem(_caKeyPair.privateKey);

    if (_storePath.isNotEmpty) {
      final dir = Directory(_storePath);
      if (!await dir.exists()) await dir.create(recursive: true);
      await File('$_storePath/ca_cert.pem').writeAsString(_caCertPem);
      await File('$_storePath/ca_key.pem').writeAsString(_caKeyPem);
      await File('$_storePath/ca_cert.der').writeAsBytes(_caCertDer);
    }

    _ready = true;
  }

  /// Generate a leaf certificate for a specific hostname, signed by our CA.
  /// Uses a shared leaf key pair & LRU-style host cache for maximum speed and 0 lag.
  SecurityContext createContextForHost(String host) {
    final cached = _hostContextCache[host];
    if (cached != null) return cached;

    _sharedLeafKeyPair ??= _generateRSAKeyPair(bitLength: 2048);

    final now = DateTime.now();
    final notBefore = now.subtract(const Duration(days: 1));
    final notAfter = now.add(const Duration(days: 365));

    final leafCertDer = _buildLeafCertDer(
      _sharedLeafKeyPair!.publicKey,
      _caKeyPair.privateKey,
      host,
      notBefore,
      notAfter,
    );

    final leafCertPem = _derToPem(leafCertDer, 'CERTIFICATE');
    final leafKeyPem = _privateKeyToPem(_sharedLeafKeyPair!.privateKey);

    // Build cert chain: leaf + CA
    final chain = '$leafCertPem\n$_caCertPem';

    final ctx = SecurityContext(withTrustedRoots: false);
    ctx.useCertificateChainBytes(utf8.encode(chain));
    ctx.usePrivateKeyBytes(utf8.encode(leafKeyPem));

    // Keep cache bounded to 256 hosts to prevent memory leaks
    if (_hostContextCache.length > 256) {
      _hostContextCache.remove(_hostContextCache.keys.first);
    }
    _hostContextCache[host] = ctx;
    return ctx;
  }

  // ─── RSA Key Generation ─────────────────────────────────────

  AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _generateRSAKeyPair({
    int bitLength = 2048,
  }) {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), bitLength, 64),
        secureRandom,
      ));

    final pair = keyGen.generateKeyPair();
    return AsymmetricKeyPair(
      pair.publicKey as RSAPublicKey,
      pair.privateKey as RSAPrivateKey,
    );
  }

  // ─── DER Encoding Helpers ───────────────────────────────────

  Uint8List _derLength(int length) {
    if (length < 0x80) return Uint8List.fromList([length]);
    final bytes = <int>[];
    var v = length;
    while (v > 0) {
      bytes.insert(0, v & 0xFF);
      v >>= 8;
    }
    return Uint8List.fromList([0x80 | bytes.length, ...bytes]);
  }

  Uint8List _derTag(int tag, Uint8List content) {
    return Uint8List.fromList([tag, ..._derLength(content.length), ...content]);
  }

  Uint8List _derSequence(List<Uint8List> items) {
    final content = items.expand((e) => e).toList();
    return _derTag(0x30, Uint8List.fromList(content));
  }

  Uint8List _derSet(List<Uint8List> items) {
    final content = items.expand((e) => e).toList();
    return _derTag(0x31, Uint8List.fromList(content));
  }

  Uint8List _derInteger(BigInt value) {
    var bytes = _bigIntToBytes(value);
    if (bytes.isNotEmpty && bytes[0] & 0x80 != 0) {
      bytes = Uint8List.fromList([0, ...bytes]);
    }
    return _derTag(0x02, Uint8List.fromList(bytes));
  }

  Uint8List _derOID(List<int> oid) {
    final encoded = <int>[];
    encoded.add(oid[0] * 40 + oid[1]);
    for (var i = 2; i < oid.length; i++) {
      var v = oid[i];
      if (v < 0x80) {
        encoded.add(v);
      } else {
        final parts = <int>[];
        parts.add(v & 0x7F);
        v >>= 7;
        while (v > 0) {
          parts.add(0x80 | (v & 0x7F));
          v >>= 7;
        }
        encoded.addAll(parts.reversed);
      }
    }
    return _derTag(0x06, Uint8List.fromList(encoded));
  }

  Uint8List _derUtf8String(String s) {
    return _derTag(0x0C, Uint8List.fromList(utf8.encode(s)));
  }

  Uint8List _derPrintableString(String s) {
    return _derTag(0x13, Uint8List.fromList(utf8.encode(s)));
  }

  Uint8List _derUtcTime(DateTime dt) {
    final utc = dt.toUtc();
    final s = '${_pad2(utc.year % 100)}${_pad2(utc.month)}${_pad2(utc.day)}'
        '${_pad2(utc.hour)}${_pad2(utc.minute)}${_pad2(utc.second)}Z';
    return _derTag(0x17, Uint8List.fromList(utf8.encode(s)));
  }

  Uint8List _derBitString(Uint8List data) {
    return _derTag(0x03, Uint8List.fromList([0, ...data]));
  }

  Uint8List _derOctetString(Uint8List data) {
    return _derTag(0x04, data);
  }

  Uint8List _derExplicit(int tag, Uint8List content) {
    return _derTag(0xA0 | tag, content);
  }

  Uint8List _derNull() => Uint8List.fromList([0x05, 0x00]);

  Uint8List _derBoolean(bool value) {
    return _derTag(0x01, Uint8List.fromList([value ? 0xFF : 0x00]));
  }

  String _pad2(int v) => v.toString().padLeft(2, '0');

  Uint8List _bigIntToBytes(BigInt value) {
    if (value == BigInt.zero) return Uint8List.fromList([0]);
    final hex = value.toRadixString(16);
    final padded = hex.length.isOdd ? '0$hex' : hex;
    final bytes = <int>[];
    for (var i = 0; i < padded.length; i += 2) {
      bytes.add(int.parse(padded.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  // ─── Subject/Issuer Name ────────────────────────────────────

  Uint8List _buildName({String? cn, String? o, String? ou}) {
    final rdns = <Uint8List>[];
    if (cn != null) {
      rdns.add(_derSet([
        _derSequence([_derOID([2, 5, 4, 3]), _derUtf8String(cn)])
      ]));
    }
    if (o != null) {
      rdns.add(_derSet([
        _derSequence([_derOID([2, 5, 4, 10]), _derUtf8String(o)])
      ]));
    }
    if (ou != null) {
      rdns.add(_derSet([
        _derSequence([_derOID([2, 5, 4, 11]), _derUtf8String(ou)])
      ]));
    }
    return _derSequence(rdns);
  }

  // ─── Public Key Info ────────────────────────────────────────

  Uint8List _buildSubjectPublicKeyInfo(RSAPublicKey pub) {
    final rsaPubKey = _derSequence([
      _derInteger(pub.modulus!),
      _derInteger(pub.publicExponent!),
    ]);

    return _derSequence([
      _derSequence([
        _derOID([1, 2, 840, 113549, 1, 1, 1]), // rsaEncryption
        _derNull(),
      ]),
      _derBitString(rsaPubKey),
    ]);
  }

  // ─── Sign with RSA-SHA256 ───────────────────────────────────

  Uint8List _signData(Uint8List data, RSAPrivateKey privateKey) {
    final signer = Signer('SHA-256/RSA');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final sig = signer.generateSignature(data) as RSASignature;
    return sig.bytes;
  }

  // ─── Build CA Certificate ──────────────────────────────────

  Uint8List _buildCACertDer(
    RSAPublicKey pub,
    RSAPrivateKey priv,
    DateTime notBefore,
    DateTime notAfter,
  ) {
    final serialNumber = _derInteger(
      BigInt.from(Random.secure().nextInt(0x7FFFFFFF)),
    );

    final signatureAlg = _derSequence([
      _derOID([1, 2, 840, 113549, 1, 1, 11]), // sha256WithRSAEncryption
      _derNull(),
    ]);

    final issuer = _buildName(
      cn: 'VersSuite CA',
      o: 'VersSuite',
      ou: 'Proxy',
    );

    final validity = _derSequence([
      _derUtcTime(notBefore),
      _derUtcTime(notAfter),
    ]);

    final subject = issuer; // Self-signed: subject == issuer

    final pubKeyInfo = _buildSubjectPublicKeyInfo(pub);

    // Extensions: Basic Constraints (CA:TRUE), Key Usage (keyCertSign, cRLSign)
    final basicConstraints = _derSequence([
      _derOID([2, 5, 29, 19]), // basicConstraints
      _derBoolean(true), // critical
      _derOctetString(_derSequence([
        _derBoolean(true), // cA = TRUE
      ])),
    ]);

    final keyUsage = _derSequence([
      _derOID([2, 5, 29, 15]), // keyUsage
      _derBoolean(true), // critical
      _derOctetString(_derBitString(
        Uint8List.fromList([0x06]), // keyCertSign + cRLSign
      )),
    ]);

    final extensions = _derExplicit(3, _derSequence([
      basicConstraints,
      keyUsage,
    ]));

    final tbs = _derSequence([
      _derExplicit(0, _derInteger(BigInt.from(2))), // version v3
      serialNumber,
      signatureAlg,
      issuer,
      validity,
      subject,
      pubKeyInfo,
      extensions,
    ]);

    final signature = _signData(tbs, priv);

    return _derSequence([
      tbs,
      signatureAlg,
      _derBitString(Uint8List.fromList(signature)),
    ]);
  }

  // ─── Build Leaf Certificate ─────────────────────────────────

  Uint8List _buildLeafCertDer(
    RSAPublicKey leafPub,
    RSAPrivateKey caPriv,
    String hostname,
    DateTime notBefore,
    DateTime notAfter,
  ) {
    final serialNumber = _derInteger(
      BigInt.from(Random.secure().nextInt(0x7FFFFFFF)),
    );

    final signatureAlg = _derSequence([
      _derOID([1, 2, 840, 113549, 1, 1, 11]),
      _derNull(),
    ]);

    final issuer = _buildName(
      cn: 'VersSuite CA',
      o: 'VersSuite',
      ou: 'Proxy',
    );

    final validity = _derSequence([
      _derUtcTime(notBefore),
      _derUtcTime(notAfter),
    ]);

    final subject = _buildName(cn: hostname);

    final pubKeyInfo = _buildSubjectPublicKeyInfo(leafPub);

    // SAN extension
    final dnsName = _derTag(0x82, Uint8List.fromList(utf8.encode(hostname)));
    final san = _derSequence([
      _derOID([2, 5, 29, 17]), // subjectAltName
      _derOctetString(_derSequence([dnsName])),
    ]);

    // Basic Constraints (CA:FALSE)
    final basicConstraints = _derSequence([
      _derOID([2, 5, 29, 19]),
      _derBoolean(true),
      _derOctetString(_derSequence([])),
    ]);

    // Key Usage: digitalSignature, keyEncipherment
    final keyUsage = _derSequence([
      _derOID([2, 5, 29, 15]),
      _derBoolean(true),
      _derOctetString(_derBitString(
        Uint8List.fromList([0xA0]),
      )),
    ]);

    // Extended Key Usage: serverAuth
    final extKeyUsage = _derSequence([
      _derOID([2, 5, 29, 37]),
      _derOctetString(_derSequence([
        _derOID([1, 3, 6, 1, 5, 5, 7, 3, 1]), // serverAuth
      ])),
    ]);

    final extensions = _derExplicit(3, _derSequence([
      basicConstraints,
      keyUsage,
      extKeyUsage,
      san,
    ]));

    final tbs = _derSequence([
      _derExplicit(0, _derInteger(BigInt.from(2))),
      serialNumber,
      signatureAlg,
      issuer,
      validity,
      subject,
      pubKeyInfo,
      extensions,
    ]);

    final signature = _signData(tbs, caPriv);

    return _derSequence([
      tbs,
      signatureAlg,
      _derBitString(Uint8List.fromList(signature)),
    ]);
  }

  // ─── PEM Encoding ──────────────────────────────────────────

  String _derToPem(Uint8List der, String label) {
    final b64 = base64Encode(der);
    final lines = <String>[];
    lines.add('-----BEGIN $label-----');
    for (var i = 0; i < b64.length; i += 64) {
      lines.add(b64.substring(i, i + 64 > b64.length ? b64.length : i + 64));
    }
    lines.add('-----END $label-----');
    return lines.join('\n');
  }

  String _privateKeyToPem(RSAPrivateKey key) {
    // PKCS#1 RSAPrivateKey
    final der = _derSequence([
      _derInteger(BigInt.zero), // version
      _derInteger(key.modulus!),
      _derInteger(key.publicExponent!),
      _derInteger(key.privateExponent!),
      _derInteger(key.p!),
      _derInteger(key.q!),
      _derInteger(key.privateExponent! % (key.p! - BigInt.one)), // d mod (p-1)
      _derInteger(key.privateExponent! % (key.q! - BigInt.one)), // d mod (q-1)
      _derInteger(key.q!.modInverse(key.p!)), // q^-1 mod p
    ]);
    return _derToPem(der, 'RSA PRIVATE KEY');
  }

  AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _loadKeyFromPem(String pem) {
    // Extract DER from PEM
    final lines = pem.split('\n')
        .where((l) => !l.startsWith('-----'))
        .join('');
    final der = base64Decode(lines);

    // Parse PKCS#1 RSAPrivateKey (simplified)
    // We just regenerate a new key pair as fallback
    // For production, you'd parse the DER properly
    try {
      final parsed = _parseDerSequence(der);
      if (parsed.length >= 9) {
        final n = _parseDerInteger(parsed[1]);
        final e = _parseDerInteger(parsed[2]);
        final d = _parseDerInteger(parsed[3]);
        final p = _parseDerInteger(parsed[4]);
        final q = _parseDerInteger(parsed[5]);

        final pub = RSAPublicKey(n, e);
        final priv = RSAPrivateKey(n, d, p, q);
        return AsymmetricKeyPair(pub, priv);
      }
    } catch (_) {}

    return _generateRSAKeyPair();
  }

  List<Uint8List> _parseDerSequence(Uint8List data) {
    final items = <Uint8List>[];
    if (data.isEmpty || data[0] != 0x30) return items;

    int offset = 1;
    int length;
    if (data[offset] & 0x80 == 0) {
      length = data[offset];
      offset++;
    } else {
      final numBytes = data[offset] & 0x7F;
      offset++;
      length = 0;
      for (var i = 0; i < numBytes; i++) {
        length = (length << 8) | data[offset + i];
      }
      offset += numBytes;
    }

    final end = offset + length;
    while (offset < end && offset < data.length) {
      final tag = data[offset];
      offset++;

      int itemLen;
      if (data[offset] & 0x80 == 0) {
        itemLen = data[offset];
        offset++;
      } else {
        final numBytes = data[offset] & 0x7F;
        offset++;
        itemLen = 0;
        for (var i = 0; i < numBytes; i++) {
          itemLen = (itemLen << 8) | data[offset + i];
        }
        offset += numBytes;
      }

      items.add(Uint8List.fromList(
        [tag, ..._derLength(itemLen), ...data.sublist(offset, offset + itemLen)]
      ));
      offset += itemLen;
    }

    return items;
  }

  BigInt _parseDerInteger(Uint8List data) {
    if (data.isEmpty || data[0] != 0x02) return BigInt.zero;
    int offset = 1;
    int length;
    if (data[offset] & 0x80 == 0) {
      length = data[offset];
      offset++;
    } else {
      final numBytes = data[offset] & 0x7F;
      offset++;
      length = 0;
      for (var i = 0; i < numBytes; i++) {
        length = (length << 8) | data[offset + i];
      }
      offset += numBytes;
    }
    final bytes = data.sublist(offset, offset + length);
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return BigInt.parse(hex, radix: 16);
  }
}
