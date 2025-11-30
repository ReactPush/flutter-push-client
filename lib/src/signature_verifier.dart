import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:asn1lib/asn1lib.dart';

/// Creates a deterministic payload string for signature verification
/// Must match the format used by the CLI and server
String createSigningPayload(Map<String, dynamic> update) {
  final parts = [
    'version:${update['version'] ?? ''}',
    'label:${update['label'] ?? ''}',
    'platform:${update['platform'] ?? ''}',
    'bundleUrl:${update['bundleUrl'] ?? ''}',
    'assetsUrl:${update['assetsUrl'] ?? ''}',
    'zipUrl:${update['zipUrl'] ?? ''}',
    'isMandatory:${update['isMandatory'] ?? false}',
    'description:${update['description'] ?? ''}',
  ];
  return parts.join('|');
}

/// Verifies an update signature using RSA public key
/// 
/// [publicKeyBase64] - Public key in base64 format
/// [update] - Update object with all fields
/// [signatureBase64] - Signature in base64 format
/// Returns true if signature is valid
Future<bool> verifyUpdateSignature(
  String publicKeyBase64,
  Map<String, dynamic> update,
  String signatureBase64,
) async {
  try {
    // Create payload
    final payload = createSigningPayload(update);
    final payloadBytes = utf8.encode(payload);
    final signatureBytes = base64Decode(signatureBase64);
    final publicKeyBytes = base64Decode(publicKeyBase64);

    // Parse RSA public key from DER format using asn1lib
    final asn1Parser = ASN1Parser(publicKeyBytes);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;
    
    // Extract modulus and exponent from the sequence
    final modulus = (topLevelSeq.elements[0] as ASN1Integer).intValue;
    final exponent = (topLevelSeq.elements[1] as ASN1Integer).intValue;

    // Create RSA public key
    final rsaPublicKey = pc.RSAPublicKey(
      BigInt.from(modulus),
      BigInt.from(exponent),
    );

    // Create SHA-256 hash of payload
    final hash = sha256.convert(payloadBytes).bytes;

    // Use RSAEngine for signature verification with PKCS1 padding
    final rsaEngine = pc.RSAEngine()
      ..init(false, pc.PublicKeyParameter<pc.RSAPublicKey>(rsaPublicKey));
    
    // Decrypt the signature (this gives us the padded hash)
    final decrypted = rsaEngine.process(signatureBytes);
    
    // Verify PKCS1 v1.5 padding format: 00 01 FF...FF 00 [hash]
    if (decrypted.length < hash.length + 11) {
      return false;
    }
    
    // Check padding
    if (decrypted[0] != 0x00 || decrypted[1] != 0x01) {
      return false;
    }
    
    // Find the separator (00 byte after padding)
    int separatorIndex = -1;
    for (int i = 2; i < decrypted.length - hash.length; i++) {
      if (decrypted[i] == 0x00) {
        separatorIndex = i;
        break;
      }
      if (decrypted[i] != 0xFF) {
        return false; // Invalid padding
      }
    }
    
    if (separatorIndex == -1) {
      return false;
    }
    
    // Extract and compare the hash
    final extractedHash = decrypted.sublist(separatorIndex + 1);
    if (extractedHash.length != hash.length) {
      return false;
    }
    
    // Compare hashes
    for (int i = 0; i < hash.length; i++) {
      if (extractedHash[i] != hash[i]) {
        return false;
      }
    }
    
    return true;
  } catch (error) {
    print('FlutterPush: Signature verification error: $error');
    return false;
  }
}

