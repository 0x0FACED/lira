import 'dart:convert';
import 'package:crypto/crypto.dart';

class BrowserCheckSolver {
  static String? solve(String html) {
    // Z-Library obfuscates the check, but we can extract the base string 'c'.
    // Typically it's a 40-character hex string found in an array definition like:
    // const a0_0x2a54=['1855D4BA33F52415FEB7DEC5187E3D0E81938724','c_token=','array'];
    final RegExp arrayRegex = RegExp(r"\['([A-F0-9]{40})','c_token='");
    final match = arrayRegex.firstMatch(html);
    
    if (match == null) return null;
    
    final c = match.group(1)!;
    final n1 = int.parse(c[0], radix: 16);
    
    // The JS brute forces an integer 'i' such that sha1(c + i) has 0xb0 and 0x0b at indexes n1 and n1+1
    for (int i = 0; i < 1000000; i++) {
      final bytes = utf8.encode('$c$i');
      final digest = sha1.convert(bytes);
      final hashBytes = digest.bytes;
      
      if (hashBytes[n1] == 0xb0 && hashBytes[n1 + 1] == 0x0b) {
        return '$c$i'; // This is the value to append to 'c_token=' in cookies
      }
    }
    
    return null;
  }
}
