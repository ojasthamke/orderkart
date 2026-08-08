/// Marathi Item Name Translation & Bilingual Helper
/// Provides Marathi translations and bilingual display formatting for vegetables, fruits, and groceries.
library;

class MarathiItemHelper {
  MarathiItemHelper._();

  static const Map<String, String> _dictionary = {
    // ── Leafy Vegetables (पालेभाज्या) ──────────────────────────
    'palak': 'पालक',
    'spinach': 'पालक',
    'methi': 'मेथी',
    'fenugreek': 'मेथी',
    'kothimbir': 'कोथिंबीर',
    'coriander': 'कोथिंबीर',
    'dhaniya': 'कोथिंबीर',
    'shepu': 'शेपू',
    'dill': 'शेपू',
    'dill leaves': 'शेपू',
    'pudina': 'पुदिना',
    'mint': 'पुदिना',
    'kadi patta': 'कढीपत्ता',
    'curry leaves': 'कढीपत्ता',
    'curry patta': 'कढीपत्ता',
    'laal maath': 'लाल माठ',
    'red amaranth': 'लाल माठ',
    'rajgira': 'राजगिरा भाजी',
    'chuka': 'चुका',
    'sorrel': 'चुका',
    'chaulai': 'चवळी भाजी',
    'alu chi pane': 'अळूची पाने',
    'taro leaves': 'अळूची पाने',
    'colocasia leaves': 'अळूची पाने',
    'kanda paat': 'कांद्याची पात',
    'spring onion': 'कांद्याची पात',

    // ── Daily Vegetables (रोजच्या भाज्या) ────────────────────────
    'tamatar': 'टोमॅटो',
    'tomato': 'टोमॅटो',
    'tomatoes': 'टोमॅटो',
    'kanda': 'कांदा',
    'onion': 'कांदा',
    'onions': 'कांदा',
    'pyaj': 'कांदा',
    'batata': 'बटाटा',
    'potato': 'बटाटा',
    'potatoes': 'बटाटा',
    'aloo': 'बटाटा',
    'bhendi': 'भेंडी',
    'lady finger': 'भेंडी',
    'ladyfinger': 'भेंडी',
    'okra': 'भेंडी',
    'bhindi': 'भेंडी',
    'vangi': 'वांगी',
    'baingan': 'वांगी',
    'brinjal': 'वांगी',
    'eggplant': 'वांगी',
    'kobi': 'कोबी',
    'patta gobi': 'कोबी',
    'cabbage': 'कोबी',
    'flower': 'फ्लॉवर',
    'phool gobi': 'फ्लॉवर',
    'cauliflower': 'फ्लॉवर',
    'karle': 'कारले',
    'karela': 'कारले',
    'bitter gourd': 'कारले',
    'dudhi': 'दुधी भोपळा',
    'lauki': 'दुधी भोपळा',
    'bottle gourd': 'दुधी भोपळा',
    'dudhi bhopla': 'दुधी भोपळा',
    'bhopla': 'लाल भोपळा',
    'kaddu': 'लाल भोपळा',
    'red pumpkin': 'लाल भोपळा',
    'pumpkin': 'लाल भोपळा',
    'dodka': 'दोडका',
    'turai': 'दोडका',
    'ridge gourd': 'दोडका',
    'ghosale': 'घोसाळे',
    'sponge gourd': 'घोसाळे',
    'gilke': 'गिलके / घोसाळे',
    'padwal': 'पडवळ',
    'snake gourd': 'पडवळ',
    'tondli': 'तोंडली',
    'kundru': 'तोंडली',
    'ivy gourd': 'तोंडली',
    'kakdi': 'काकडी',
    'kheera': 'काकडी',
    'cucumber': 'काकडी',
    'gajar': 'गाजर',
    'carrot': 'गाजर',
    'carrots': 'गाजर',
    'mula': 'मुळा',
    'mooli': 'मुळा',
    'radish': 'मुळा',
    'beet': 'बीट',
    'beetroot': 'बीट',
    'shimla mirchi': 'ढोबळी मिरची',
    'capsicum': 'ढोबळी मिरची',
    'bell pepper': 'ढोबळी मिरची',
    'dhobli mirchi': 'ढोबळी मिरची',
    'mirchi': 'हिरवी मिरची',
    'green chilli': 'हिरवी मिरची',
    'chilli': 'हिरवी मिरची',
    'hari mirch': 'हिरवी मिरची',
    'lasun': 'लसूण',
    'garlic': 'लसूण',
    'lehsun': 'लसूण',
    'ale': 'आले',
    'adrak': 'आले / अद्रक',
    'ginger': 'आले / अद्रक',
    'limbu': 'लिंबू',
    'lemon': 'लिंबू',
    'nimbu': 'लिंबू',
    'shevga': 'शेवगा शेंग',
    'drumstick': 'शेवगा शेंग',
    'drumsticks': 'शेवगा शेंग',
    'chenga': 'चवळी शेंग',
    'chavri': 'चवळी शेंग',
    'chawli': 'चवळी शेंग',
    'chawli beans': 'चवळी शेंग',
    'french beans': 'फरसबी',
    'farasbi': 'फरसबी',
    'beans': 'शेंगा / फरसबी',
    'gawar': 'गवार',
    'guar': 'गवार',
    'cluster beans': 'गवार',
    'vatana': 'मटार / हिरवा वाटाणा',
    'matar': 'मटार',
    'green peas': 'मटार / वाटाणा',
    'peas': 'मटार',
    'suran': 'सुरण',
    'yam': 'सुरण',
    'elephant yam': 'सुरण',
    'arbi': 'अळकुडी / अळू कंद',
    'kachalu': 'अळू कंद',
    'sweet potato': 'रताळे',
    'ratale': 'रताळे',
    'shakarkand': 'रताळे',
    'makka': 'मका',
    'corn': 'मका',
    'sweet corn': 'स्वीट कॉर्न',
    'bhutta': 'मक्याचे कणीस',

    // ── Fruits (फळे) ──────────────────────────────────────────
    'kela': 'केळी',
    'banana': 'केळी',
    'bananas': 'केळी',
    'safarchand': 'सफरचंद',
    'apple': 'सफरचंद',
    'apples': 'सफरचंद',
    'santara': 'संत्री',
    'orange': 'संत्री',
    'oranges': 'संत्री',
    'mosambi': 'मोसंबी',
    'sweet lime': 'मोसंबी',
    'draksha': 'द्राक्षे',
    'grapes': 'द्राक्षे',
    'angoor': 'द्राक्षे',
    'kalingad': 'कलिंगड',
    'tarbuj': 'कलिंगड',
    'watermelon': 'कलिंगड',
    'kharbuj': 'खरबूज',
    'muskmelon': 'खरबूज',
    'ananas': 'अननस',
    'pineapple': 'अननस',
    'papai': 'पपई',
    'papaya': 'पपई',
    'peru': 'पेरू',
    'amrood': 'पेरू',
    'guava': 'पेरू',
    'chiku': 'चीकू',
    'chikoo': 'चीकू',
    'sapodilla': 'चीकू',
    'dalimb': 'डाळिंब',
    'anar': 'डाळिंब',
    'pomegranate': 'डाळिंब',
    'amba': 'आंबा',
    'aam': 'आंबा',
    'mango': 'आंबा',
    'sitaphal': 'सीताफळ',
    'custard apple': 'सीताफळ',
    'anjoor': 'अंजीर',
    'anjeer': 'अंजीर',
    'fig': 'अंजीर',
    'bor': 'बोर',
    'ber': 'बोर',
    'jujube': 'बोर',
    'naral': 'नारळ',
    'coconut': 'नारळ',
    'shahale': 'शहाळे / ओला नारळ',
    'tender coconut': 'शहाळे',

    // ── Groceries & Staples (किराणा व धान्य) ─────────────────────
    'doodh': 'ताजे दूध',
    'milk': 'ताजे दूध',
    'dahi': 'दही',
    'curd': 'दही',
    'taak': 'ताक',
    'buttermilk': 'ताक',
    'paneer': 'पनीर',
    'ghee': 'शुद्ध तूप',
    'tel': 'खाद्यतेल',
    'oil': 'खाद्यतेल',
    'cooking oil': 'खाद्यतेल',
    'gool': 'गूळ',
    'jaggery': 'गूळ',
    'sugar': 'साखर',
    'shakkar': 'साखर',
    'sakhar': 'साखर',
    'meeth': 'मीठ',
    'salt': 'मीठ',
    'namak': 'मीठ',
    'halad': 'हळद',
    'turmeric': 'हळद',
    'haldi': 'हळद',
    'hing': 'हिंग',
    'asafoetida': 'हिंग',
    'jeere': 'जिरे',
    'cumin': 'जिरे',
    'jeera': 'जिरे',
    'mohari': 'मोहरी',
    'mustard': 'मोहरी',
    'rai': 'मोहरी',
    'dhane': 'धने',
    'dhaniya seeds': 'धने',
    'gahu': 'गहू',
    'wheat': 'गहू',
    'atta': 'गव्हाचे पीठ',
    'wheat flour': 'गव्हाचे पीठ',
    'tandul': 'तांदूळ',
    'rice': 'तांदूळ',
    'chawal': 'तांदूळ',
    'jowar': 'ज्वारी',
    'jwari': 'ज्वारी',
    'bajra': 'बाजरी',
    'bajri': 'बाजरी',
    'besan': 'बेसन / चण्याचे पीठ',
    'pohe': 'पोहे',
    'poha': 'पोहे',
    'rava': 'रवा / सुजी',
    'sooji': 'रवा',
    'suji': 'रवा',
    'toor dal': 'तूर डाळ',
    'tur dal': 'तूर डाळ',
    'moong dal': 'मूग डाळ',
    'urad dal': 'उडीद डाळ',
    'chana dal': 'चना डाळ',
    'masoor dal': 'मसूर डाळ',
    'harbhara': 'हरभरा',
    'chana': 'हरभरा / चणे',
    'kabuli chana': 'काबुली चणे / छोले',
    'chole': 'छोले',
    'rajma': 'राजमा',
    'makhana': 'मखाना',
    'bread': 'ब्रेड',
    'ande': 'अंडी',
    'eggs': 'अंडी',
    'egg': 'अंडी',
    'chaha': 'चहा पावडर',
    'tea': 'चहा पावडर',
    'coffee': 'कॉफी',
  };

  /// Check if text contains Devanagari characters
  static bool hasDevanagari(String text) {
    return RegExp(r'[\u0900-\u097F]').hasMatch(text);
  }

  /// Get Marathi name translation for an item name if known
  static String? lookupMarathiName(String itemName) {
    if (itemName.trim().isEmpty) return null;

    // Normalize for lookup: lowercase, remove brackets & punctuation
    final normalized = itemName.toLowerCase().trim();
    
    // Direct match
    if (_dictionary.containsKey(normalized)) {
      return _dictionary[normalized];
    }

    // Try without parentheses content, e.g. "Chenga (Chavri)" -> "chenga"
    final cleanNoBracket = normalized.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    if (_dictionary.containsKey(cleanNoBracket)) {
      return _dictionary[cleanNoBracket];
    }

    // Try individual words / parts
    final parts = normalized.split(RegExp(r'[\s\(/,\-\)]+')).where((s) => s.isNotEmpty);
    for (final part in parts) {
      if (_dictionary.containsKey(part)) {
        return _dictionary[part];
      }
    }

    return null;
  }

  /// Returns a clean, aesthetically formatted bilingual item name
  /// Examples:
  /// - "Chenga (Chavri)" -> "Chenga (चवळी शेंग)"
  /// - "Methi"           -> "Methi (मेथी)"
  /// - "Tamatar"         -> "Tamatar (टोमॅटो)"
  /// - "कांदा"           -> "कांदा (Onion)"
  /// - "Tomato (टोमॅटो)" -> "Tomato (टोमॅटो)" (already bilingual)
  static String formatBilingual(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return trimmed;

    // If it already contains Devanagari script in it
    if (hasDevanagari(trimmed)) {
      // Check if it already has English + Marathi or just Marathi
      final hasEnglish = RegExp(r'[a-zA-Z]').hasMatch(trimmed);
      if (hasEnglish) {
        return trimmed; // Already bilingual
      }
      // Only Marathi -> find if we have an English reverse mapping or leave clean
      return trimmed;
    }

    // It's in English/Latin script -> lookup Marathi equivalent
    final marathi = lookupMarathiName(trimmed);
    if (marathi != null && marathi.isNotEmpty) {
      // If the name already has bracketed alias, like "Chenga (Chavri)"
      if (trimmed.contains('(')) {
        return '$trimmed / $marathi';
      }
      return '$trimmed ($marathi)';
    }

    return trimmed;
  }
}
