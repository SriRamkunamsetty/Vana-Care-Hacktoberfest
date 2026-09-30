/// UI strings. English is the source; Telugu and Hindi override the keys the
/// prototype translated (everything else falls back to English).
const Map<String, String> _en = {
  'home': 'Home', 'explore': 'Explore', 'ai': 'AI', 'library': 'Library', 'profile': 'Profile',
  'greet': 'Good morning', 'offlineAi': 'Offline · AI ready', 'emMode': 'Emergency Mode',
  'emSub': 'Bleeding, burns, breathing and more', 'askPh': "Ask Vana what's happening…", 'quick': 'Quick help',
  'firstAid': 'First aid', 'firstAidSub': '9 guides', 'vision': 'Vision assistant', 'visionSub': 'Scan an injury',
  'forest': 'Forest Mode', 'forestSub': 'Trail and map', 'survival': 'Survival toolkit', 'survivalSub': 'Compass and tools',
  'elev': 'Elevation', 'daylight': 'Daylight left', 'battery': 'Battery', 'tripOn': 'TRIP IN PROGRESS',
  'tripOff': 'NO TRIP RECORDING', 'elapsed': 'Elapsed', 'distance': 'Distance', 'record': 'Record trail',
  'checkin': 'Trip check-in', 'checkinSub': 'Sends your position to your first contact when you tap check-in.',
  'snapshot': 'Saved forecast', 'map': 'Offline map', 'lost': "I'm lost", 'returnStart': 'Return to start',
  'pathNote': 'Shows the path you recorded. It is not a verified trail and does not guarantee safe passage.',
  'lastPos': 'LAST KNOWN POSITION', 'call112': 'Call 112', 'sharePos': 'Share position', 'lostCheck': 'Lost checklist',
  'onDevice': 'on-device', 'openGuide': 'Open full guide', 'aiNote': 'AI guidance. Not a diagnosis.',
  'describe': 'Describe the situation…', 'searchLib': 'Search offline guides', 'medicalId': 'Medical ID',
  'onDeviceOnly': 'stored on this phone', 'contacts': 'Emergency contacts', 'language': 'Language',
  'appearance': 'Appearance', 'privacy': 'Privacy', 'packs': 'Offline packs', 'emPick': 'Choose what is happening',
  'voice': 'Voice assistant', 'report': 'Emergency report', 'source': 'Protocol v1.2 · WHO Basic Emergency Care',
  'getHelp': 'Get help if:', 'send': 'Send to Vana', 'frame': 'Place the injury in the frame',
  'analysing': 'Analysing on this phone…', 'seen': 'WHAT GEMMA CAN SEE', 'uncertain': 'Uncertain.',
  'visNote': 'Image quality is limited and this is not a diagnosis. Follow the steps and call for help if it gets worse.',
  'retake': 'Retake', 'openSteps': 'Open first-aid steps',
  'reportTitle': 'EMERGENCY REPORT · SAVED ON PHONE',
  'reportNote': 'Stored locally. It has not reached a rescuer until you share it over a working connection.',
  'cancel': 'Cancel beacon', 'dark': 'Dark', 'light': 'Light', 'system': 'System', 'listening': 'Listening…',
  'tapMic': 'Tap the microphone and speak',
};

const Map<String, Map<String, String>> _lang = {
  'te': {
    'home': 'హోమ్', 'explore': 'అన్వేషణ', 'library': 'లైబ్రరీ', 'profile': 'ప్రొఫైల్', 'greet': 'శుభోదయం',
    'offlineAi': 'ఆఫ్‌లైన్ · AI సిద్ధం', 'emMode': 'అత్యవసర మోడ్', 'emSub': 'రక్తస్రావం, కాలిన గాయాలు, శ్వాస సమస్యలు',
    'askPh': 'ఏం జరుగుతోందో వానాకు చెప్పండి…', 'quick': 'త్వరిత సహాయం', 'firstAid': 'ప్రథమ చికిత్స',
    'vision': 'విజన్ సహాయకుడు', 'visionSub': 'గాయాన్ని స్కాన్ చేయండి', 'forest': 'అటవీ మోడ్', 'forestSub': 'ట్రయిల్ & మ్యాప్',
    'survival': 'మనుగడ సాధనాలు', 'survivalSub': 'దిక్సూచి & పరికరాలు', 'elev': 'ఎత్తు', 'daylight': 'పగటి వెలుగు',
    'battery': 'బ్యాటరీ', 'tripOn': 'ప్రయాణం కొనసాగుతోంది', 'elapsed': 'గడిచిన సమయం', 'distance': 'దూరం',
    'record': 'ట్రయిల్ రికార్డ్ చేయండి', 'checkin': 'ట్రిప్ చెక్-ఇన్', 'map': 'ఆఫ్‌లైన్ మ్యాప్', 'lost': 'నేను తప్పిపోయాను',
    'returnStart': 'ప్రారంభానికి తిరిగి వెళ్లండి', 'lastPos': 'చివరి తెలిసిన స్థానం', 'call112': '112కు కాల్ చేయండి',
    'sharePos': 'స్థానం పంపండి', 'lostCheck': 'తప్పిపోయినప్పుడు చెక్‌లిస్ట్', 'describe': 'పరిస్థితిని వివరించండి…',
    'searchLib': 'ఆఫ్‌లైన్ గైడ్‌లను వెతకండి', 'medicalId': 'వైద్య ID', 'contacts': 'అత్యవసర సంప్రదింపులు', 'language': 'భాష',
    'appearance': 'రూపం', 'privacy': 'గోప్యత', 'packs': 'ఆఫ్‌లైన్ ప్యాక్‌లు', 'emPick': 'ఏం జరుగుతోందో ఎంచుకోండి',
    'voice': 'వాయిస్ సహాయకుడు', 'report': 'అత్యవసర నివేదిక', 'send': 'వానాకు పంపండి', 'dark': 'డార్క్', 'light': 'లైట్',
    'listening': 'వింటోంది…', 'tapMic': 'మైక్రోఫోన్ నొక్కి మాట్లాడండి',
  },
  'hi': {
    'home': 'होम', 'explore': 'एक्सप्लोर', 'library': 'लाइब्रेरी', 'profile': 'प्रोफ़ाइल', 'greet': 'सुप्रभात',
    'offlineAi': 'ऑफ़लाइन · AI तैयार', 'emMode': 'आपातकालीन मोड', 'emSub': 'रक्तस्राव, जलन, सांस की समस्या और अन्य',
    'askPh': 'वाना को बताएँ क्या हो रहा है…', 'quick': 'त्वरित सहायता', 'firstAid': 'प्राथमिक उपचार',
    'vision': 'विज़न सहायक', 'visionSub': 'चोट स्कैन करें', 'forest': 'वन मोड', 'forestSub': 'ट्रेल और मैप',
    'survival': 'सर्वाइवल टूलकिट', 'survivalSub': 'कम्पास और उपकरण', 'elev': 'ऊँचाई', 'daylight': 'दिन की रोशनी',
    'battery': 'बैटरी', 'tripOn': 'यात्रा जारी है', 'elapsed': 'बीता समय', 'distance': 'दूरी', 'record': 'ट्रेल रिकॉर्ड करें',
    'checkin': 'ट्रिप चेक-इन', 'map': 'ऑफ़लाइन मैप', 'lost': 'मैं खो गया हूँ', 'returnStart': 'शुरुआत पर लौटें',
    'lastPos': 'अंतिम ज्ञात स्थान', 'call112': '112 पर कॉल करें', 'sharePos': 'स्थान साझा करें',
    'lostCheck': 'खोने पर चेकलिस्ट', 'describe': 'स्थिति बताएँ…', 'searchLib': 'ऑफ़लाइन गाइड खोजें', 'medicalId': 'मेडिकल ID',
    'contacts': 'आपातकालीन संपर्क', 'language': 'भाषा', 'appearance': 'रूप', 'privacy': 'गोपनीयता', 'packs': 'ऑफ़लाइन पैक',
    'emPick': 'चुनें क्या हो रहा है', 'voice': 'वॉइस सहायक', 'report': 'आपातकालीन रिपोर्ट', 'send': 'वाना को भेजें',
    'dark': 'डार्क', 'light': 'लाइट', 'listening': 'सुन रहा है…', 'tapMic': 'माइक दबाएँ और बोलें',
  },
};

/// Sample phrase shown by the (simulated) voice assistant in each language.
const Map<String, String> voiceSamples = {
  'en': 'I fell and my ankle hurts a lot',
  'te': 'నేను పడిపోయాను, నా చీలమండ చాలా నొప్పిగా ఉంది',
  'hi': 'मैं गिर गया और मेरा टखना बहुत दर्द कर रहा है',
};

class Strings {
  final String lang;
  const Strings(this.lang);
  String operator [](String k) => _lang[lang]?[k] ?? _en[k] ?? k;
}
