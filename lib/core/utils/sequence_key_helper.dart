class SequenceKeyHelper {
  SequenceKeyHelper._();

  static const String minChar = 'a';
  static const String maxChar = 'z';
  static const String defaultKey = 'm';

  /// Generates a midpoint sequence key between two sibling keys.
  static String generateBetween(String? prev, String? next) {
    final p = prev ?? '';
    final n = next ?? '';

    if (p.isEmpty && n.isEmpty) {
      return defaultKey;
    }

    if (p.isEmpty) {
      // Find a key before next
      return _getBefore(n);
    }

    if (n.isEmpty) {
      // Find a key after prev
      return _getAfter(p);
    }

    // Find midpoint between prev and next
    return _getMidpoint(p, n);
  }

  static String _getBefore(String s) {
    // Return a string lexicographically smaller than s.
    // e.g. if s is "a", return "aa" (wait, "aa" is smaller than "b", but larger than "a").
    // Wait, if s is "a", we need something smaller than "a", which is not possible in standard lowercase unless we extend the length or decrement.
    // Standard LexoRank midpoint of min and s:
    return _getMidpoint('', s);
  }

  static String _getAfter(String s) {
    // Return a string lexicographically larger than s.
    // e.g. if s is "z", return "za".
    // Midpoint of s and max ('z'):
    return _getMidpoint(s, 'z' * (s.length + 1));
  }

  static String _getMidpoint(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;
    final maxLen = len1 > len2 ? len1 : len2;

    // Pad strings with 'a' to make them equal length for midpoint calculation
    final p1 = s1.padRight(maxLen, 'a');
    final p2 = s2.padRight(maxLen, 'a');

    String result = '';
    bool differenceFound = false;

    for (int i = 0; i < maxLen; i++) {
      final code1 = p1.codeUnitAt(i);
      final code2 = p2.codeUnitAt(i);

      if (code1 == code2) {
        result += String.fromCharCode(code1);
      } else {
        differenceFound = true;
        final midCode = (code1 + code2) ~/ 2;
        if (midCode == code1) {
          // No character between code1 and code2 (e.g. 'a' and 'b').
          // Append code1 and continue to next level.
          result += String.fromCharCode(code1);
          // If we are at the end, we must append a character to break the tie
          if (i == maxLen - 1) {
            result += 'm'; // halfway character
          }
        } else {
          result += String.fromCharCode(midCode);
          break;
        }
      }
    }

    if (!differenceFound) {
      result += 'm';
    }

    return result;
  }
}
