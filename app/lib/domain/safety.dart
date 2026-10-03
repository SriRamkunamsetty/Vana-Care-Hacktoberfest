/// Layer 2 of the blueprint's three-layer safety system: deterministic rules that run
/// before and after the language model. The model can never override these.
class SafetyRule {
  final String id;

  /// Protocol to show. Null means "no approved protocol, escalate to emergency services".
  final String? protocolId;
  final bool callEmergency;
  final List<String> keys;
  const SafetyRule(this.id, this.protocolId, this.callEmergency, this.keys);
}

class SafetyDecision {
  final List<SafetyRule> matched;
  const SafetyDecision(this.matched);
  static const none = SafetyDecision([]);

  bool get isEmergency => matched.isNotEmpty;
  SafetyRule? get primary => matched.isEmpty ? null : matched.first;
  String? get protocolId => matched.map((r) => r.protocolId).whereType<String>().firstOrNull;
  bool get callEmergency => matched.any((r) => r.callEmergency);
  List<String> get ruleIds => matched.map((r) => r.id).toList();
}

class SafetyEngine {
  const SafetyEngine();

  /// Ordered by clinical urgency: the first matching rule is the primary one.
  /// Keys are lowercase substrings. Over-triggering is deliberate: showing an
  /// emergency protocol unnecessarily is safe, missing one is not.
  static const rules = <SafetyRule>[
    SafetyRule('not_breathing', 'unconscious', true, [
      'not breathing', 'stopped breathing', "isn't breathing", 'no pulse', 'unconscious', 'unresponsive', 'passed out', 'collapsed', 'fainted', 'cardiac arrest', ' cpr',
      'सांस नहीं', 'साँस नहीं', 'सांस रुक', 'बेहोश', 'होश में नहीं', 'नब्ज़ नहीं',
      'ఊపిరి ఆడ', 'శ్వాస లేదు', 'శ్వాస ఆగ', 'స్పృహ', 'అపస్మారక',
    ]),
    SafetyRule('choking', 'choking', true, [
      'choking', 'choke', "can't breathe", 'cannot breathe', 'can not breathe', 'struggling to breathe', 'gasping', 'turning blue', 'airway',
      'दम घुट', 'गला घुट', 'सांस लेने में', 'साँस लेने में', 'सांस फूल',
      'ఊపిరి తీసుకోలే', 'గొంతులో', 'ఊపిరాడ', 'శ్వాస తీసుకోవడంలో',
    ]),
    SafetyRule('severe_bleeding', 'bleeding', true, [
      'bleeding', 'bleed', 'blood', 'deep cut', 'gash', 'stabbed', 'gunshot', 'spurting', 'hemorrhage', 'haemorrhage', 'wound',
      'खून', 'रक्त', 'घाव', 'कट गया', 'चोट',
      'రక్తం', 'రక్త స్రావం', 'గాయం', 'కోసుకు',
    ]),
    SafetyRule('venomous_bite', 'bites', true, [
      'snake', 'snakebite', 'viper', 'cobra', 'krait', 'scorpion', 'spider bite', 'bitten', ' bite', ' sting', 'swollen throat', 'anaphyla', ' tick',
      'साँप', 'सांप', 'सर्प', 'बिच्छू', 'काट', 'डंक',
      'పాము', 'తేలు', 'కాటు', 'కరిచ', 'కుట్టి',
    ]),
    SafetyRule('chest_or_stroke', null, true, [
      'chest pain', 'chest tight', 'heart attack', 'stroke', 'face drooping', 'slurred speech', 'seizure', 'convulsion', 'severe allergic', 'suicid', 'overdose', 'poison',
      'सीने में दर्द', 'छाती में दर्द', 'दिल का दौरा', 'लकवा', 'दौरा', 'ज़हर', 'जहर',
      'ఛాతీ నొప్పి', 'గుండెపోటు', 'పక్షవాతం', 'మూర్ఛ', 'విషం',
    ]),
    SafetyRule('burn', 'burns', false, [
      'burn', 'scald', 'on fire', 'caught fire', 'boiling water',
      'जल गया', 'जला ', 'झुलस', 'आग लग',
      'కాలిన', 'కాలింది', 'మంట', 'నిప్పు',
    ]),
    SafetyRule('fracture', 'fracture', false, [
      'fractur', 'broken', 'broke ', 'bone', 'sprain', 'twisted ankle', 'dislocat', 'ankle', 'cannot walk', "can't walk", 'deformed',
      'हड्डी', 'टूट', 'मोच', 'फ्रैक्चर',
      'ఎముక', 'విరిగ', 'బెణుకు', 'ఫ్రాక్చర్',
    ]),
    SafetyRule('hypothermia', 'hypothermia', false, [
      'hypotherm', 'freezing', 'shiver', 'very cold', 'frostbite', 'soaked and cold', 'cold exposure',
      'ठंड', 'कांप', 'काँप', 'पाला',
      'చలి', 'వణుకు',
    ]),
    SafetyRule('heat', 'heat', false, [
      'heat stroke', 'heatstroke', 'heat exhaustion', 'dehydrat', 'overheat', 'no sweat', 'sunstroke', 'very thirsty',
      'लू लग', 'गर्मी', 'निर्जलीकरण', 'पानी की कमी',
      'వడదెబ్బ', 'డీహైడ్రేషన్', 'దాహం', 'ఎండ',
    ]),
    SafetyRule('altitude', 'altitude', false, [
      'altitude', 'mountain sickness', 'high elevation', ' ams ',
      'ऊंचाई', 'ऊँचाई', 'पहाड़ी बीमारी',
      'ఎత్తు',
    ]),
  ];

  SafetyDecision assess(String text) {
    final l = ' ${text.toLowerCase()} ';
    final hits = [for (final r in rules) if (r.keys.any(l.contains)) r];
    return hits.isEmpty ? SafetyDecision.none : SafetyDecision(hits);
  }

  static final _dose = RegExp(
      r'\b\d+(\.\d+)?\s*(mg|mcg|µg|ml|iu|units?|tablets?|pills?|capsules?|drops?|grams?|g)\b|\b(take|give|inject|administer)\b[^.\n]{0,40}\b(tablet|pill|capsule|injection|antivenom|antibiotic|paracetamol|ibuprofen|aspirin|morphine)\b',
      caseSensitive: false);
  static final _diagnosis = RegExp(r'\b(you have|he has|she has|this is|it is|it.s|diagnosed with|diagnosis is)\b[^.\n]{0,60}\b(fracture|infection|cancer|melanoma|sepsis|gangrene|cellulitis|malignan\w*|tumou?r|dengue|malaria|diabetes)\b', caseSensitive: false);

  /// Removes sentences the model must never produce: drug doses and definite diagnoses.
  /// Returns the cleaned text and whether anything was removed.
  ({String text, bool changed}) sanitize(String modelText) {
    final parts = modelText.split(RegExp(r'(?<=[.!?\n])\s+'));
    var changed = false;
    final kept = <String>[];
    for (final s in parts) {
      if (_dose.hasMatch(s) || _diagnosis.hasMatch(s)) {
        changed = true;
        continue;
      }
      kept.add(s);
    }
    return (text: kept.join(' ').trim(), changed: changed);
  }
}
