import 'dart:math';

class ExtractedFields {
  final int? ageMonths;
  final int? respiratoryRate;
  final double? temperatureF;
  final int feverDays;
  final int diarrhoeaDays;
  final List<String> symptoms;
  final bool hasChestIndrawing;
  final bool hasConvulsions;
  final bool hasVomiting;
  final bool hasVomitingEverything;
  final bool hasLethargy;
  final bool hasBloodInStool;
  final bool hasSunkenEyes;
  final bool hasUnableToDrink;
  final bool hasStiffNeck;
  final bool hasEarPain;
  final bool hasMastoidSwelling;
  final bool hasRestlessIrritable;

  ExtractedFields({
    this.ageMonths,
    this.respiratoryRate,
    this.temperatureF,
    this.feverDays = 0,
    this.diarrhoeaDays = 0,
    required this.symptoms,
    this.hasChestIndrawing = false,
    this.hasConvulsions = false,
    this.hasVomiting = false,
    this.hasVomitingEverything = false,
    this.hasLethargy = false,
    this.hasBloodInStool = false,
    this.hasSunkenEyes = false,
    this.hasUnableToDrink = false,
    this.hasStiffNeck = false,
    this.hasEarPain = false,
    this.hasMastoidSwelling = false,
    this.hasRestlessIrritable = false,
  });
}

class AshaNlpResult {
  final String rawTranscript;
  final ExtractedFields extractedFields;
  final double extractionConfidence;

  AshaNlpResult({
    required this.rawTranscript,
    required this.extractedFields,
    required this.extractionConfidence,
  });
}

class AshaNlpExtractor {
  /// Comprehensive 13-Language Multilingual Thesaurus (Auto-synced with SYMPTOM_KEYWORDS.md)
  static const Map<String, List<String>> thesaurus = {
    'fever': [
      'bukhar', 'bukar', 'taap', 'fever', 'garam body', 'garam hai', 'high temperature',
      'jwaram', 'kaaychal', 'veppam', 'jwar', 'jora', 'jor', 'jwor', 'jwara',
      'bisilu', 'pani', 'panni', 'juar', 'taav', 'tav', 'उष्णता', 'ताप', 'बुखार',
    ],
    'cough': [
      'cough', 'coughing', 'khansee', 'khansi', 'कांसी', 'कहसी', 'کھانس',
      'irumal', 'இருமல்', 'kaburulu', 'dakkulu', 'కబురులు', 'దక్కులు',
      'কাশি', 'kashi', 'कास', 'kasa', 'ಕಾಸು', 'kast', 'കഞ്ഞി', 'kanji',
      'કાસ', 'kas', 'ਖਾਂਸੀ', 'khansi', 'କାଶିଶୀଳ', 'kash',
    ],
    'breathing': [
      'breathing problem', 'difficulty breathing', 'shortness of breath',
      'saans lene mein dikkat', 'saans lene me dikkat', 'सांस लेने में दिक्कत',
      'سانس لینے میں دشواری', 'muchchi vali', 'மூச்சு வலி',
      'swasa takkuva', 'శ్వాస తక్కువ', 'shwas kosto', 'শ্বাস কষ্ট',
      'shwas ghetana tras', 'श्वास घेण्यास त्रास', 'usirata dusk', 'ಉಸಿರಾಟ ದುಃಖ',
      'shwasam kashtam', 'ശ്വാസം കഷ്ടം', 'shwas levama taklif', 'શ્વાસ લેવામાં તકલીફ',
      'sah lain vich aukshai', 'ਸਾਹ ਲੈਣ ਵਿੱਚ ਔਖਿਆਈ', 'shwas nebara kosta', 'ଶ୍ୱାସ ନେବାରେ କଷ୍ଟ',
    ],
    'chest_indrawing': [
      'chest indrawing', 'chest drawing', 'chest retraction', 'stridor', 'wheeze', 'retractions',
      'chhati dhasna', 'chhati phoolna', 'saans lene me dikkat', 'saans lene mein dikkat', 'chhati dhabna',
      'छाती धंसना', 'छाती धसना', 'सांस लेने में दिक्कत',
      'چھاتی دھنسنا', 'سانس لینے میں دشواری',
      'marbu ullizhuthal', 'edai ullizhuthal', 'மார்பு உள்ளிழுத்தல்', 'மார்பு உள்ளிழுப்பு',
      'chaati padipovadam', 'chaati lopala', 'eddala posagipovadam', 'ఛాతి పడిపోవడం', 'ఛాతి లోపలికి',
      'buk doba', 'buk dhonba', 'buka dubano', 'বুক ডোবা', 'বুক ডুবে যাওয়া',
      'chhati dhasne', 'chhati bugne', 'shwas ghetana anantar', 'छाती दाबणे', 'छाती दुसने',
      'ede olagade', 'ede olage', 'shareera olagade', 'ಎದೆ ಒಳಗಡೆ', 'ಎದೆ ಒಳಕ್ಕೆ',
      'nenchu ullilekku', 'nench ullilekk', 'uravil olichu', 'നെഞ്ച് ഉള്ളിലേക്ക്', 'നെഞ്ച് ഉള്ളിലേക്ക് വലിയുന്നു',
      'chaati dobavu', 'chhati dobi', 'shwas ma rai dikkt', 'છાતી ડૂબવું', 'છાતી દબાવું',
      'chhati dabna', 'chhati dhasna', 'saah vich dushwari', 'ਛਾਤੀ ਡੁੱਬਣਾ', 'ਸਾਹ ਵਿਚ ਔਖਿਆਈ',
      'chhati duba', 'chhati dhasiba', 'shwas re kasht', 'ଛାତି ଡୁବା', 'ଛାତି ଡସିବା',
    ],
    'diarrhea': [
      'diarrhea', 'loose motion', 'loose stools', 'watery stool',
      'dast', 'pakhana', 'dast lagna', 'paani jaisa dast', 'दस्त', 'दस्त लगना', 'पतले दस्त',
      'دست', 'دست لگنا',
      'vayitruppokku', 'peenipokku', 'kozhuppokku', 'வயிற்றுப்போக்கு', 'பேதி',
      'virechanalu', 'neeru poka', 'విరేచనాలు', 'విరేచనలు',
      'atisar', 'oshodh', 'ponod', 'ডায়রিয়া', 'আতিসার', 'পাতলা পায়খানা',
      'अतिसार', 'जुलाब',
      'ಭೇದಿ', 'ವಿರೇಚನೆ',
      'അതിസാരം', 'വയറ്റിലെ പോക്ക്',
      'ઝાડા', 'દસ્ત',
      'ਦਸਤ', 'ਹੋਇਆ',
      'ଅତିସାର', 'ଝାଡ଼ା',
    ],
    'vomiting': [
      'vomiting', 'vomit', 'throwing up', 'puking',
      'ulti', 'ulti aa rahi hai', 'उल्टी', 'उल्टी आना',
      'الٹی', 'قے',
      'vaanthi', 'okkam', 'vizhuppu', 'வாந்தி', 'ஒலிப்பு',
      'vaanti', 'venti', 'vanti', 'వాంతి', 'వాంతులు',
      'bombi', 'boma', 'bomni', 'বমি', 'বমি আসা',
      'उलटी', 'ओकार',
      'ವಾಂತಿ', 'ಬಂದಿ',
      'ഛർദ്ദി', 'വാന്തി',
      'ઓળ', 'ઓળ આવવી',
      'ਉਲਟੀ', 'ਕੈ',
      'ବାନ୍ତ', 'ବାନ୍ତ ଆସିବା',
    ],
    'vomiting_everything': [
      'vomiting everything', 'throwing up everything', 'cannot keep anything down', 'everything comes back up',
      'sab ulti', 'sab kuch ulti', 'kha nahi raha', 'kuch nahi kha raha', 'ulti ho rahi hai sab',
      'सब उल्टी', 'सब कुछ उल्टी', 'कुछ खा नहीं रहा',
      'سب الٹی', 'کچھ کھا نہیں رہا',
      'ellam vaanthi', 'sapdura edukkala', 'onnum vizha mateengra', 'எல்லாம் வாந்தி', 'சாப்பிட ஏதும் வாந்தி',
      'anthaa vaanti', 'emi thinagalenu', 'anthaa venti', 'అంతా వాంతులు', 'తిన్నదంతా వాంతి',
      'sob bombi', 'kichu khete pare na', 'sab bombi', 'সব বমি', 'কিছু খেতে পারে না',
      'सगळं उलटी', 'काही खायला येत नाही',
      'ಎಲ್ಲ ವಾಂತಿ', 'ಏನೂ ತಿನ್ನಲಿಲ್ಲ',
      'എല്ലാം ഛർദ്ദി', 'ഒന്നും കഴിക്കില്ല',
      'બધુ ઓળ', 'કાંઈ ખાઈ શકતું નથી',
      'ਬੱਧ ਉਲਟੀ', 'ਕੁਝ ਨਹੀਂ ਖਾ ਸਕਦਾ',
      'ସବୁ ବାନ୍ତ', 'କିଛି ଖାଇପାରିବେ ନାହିଁ',
    ],
    'convulsions': [
      'convulsions', 'seizure', 'fit', 'fits', 'spasms',
      'jhatke', 'mirgi', 'aenthang', 'dardane', 'झटके', 'मिरगी', 'दौरे',
      'جھٹکے', 'مرگی',
      'valippu', 'pidippu', 'potu', 'pittam', 'வலிப்பு', 'பிடிப்பு',
      'mirigi', 'piduvatamu', 'mokkala', 'spasam', 'మిరిగి', 'పిటువాత',
      'khichuni', 'mrigi', 'aekare', 'খিঞ্চুনি', 'মৃগী',
      'आकडी', 'मिरगी',
      'selete', 'mirugi', 'mooka', 'ಸೆಳೆತ', 'ಮಿರುಗು',
      'pidippu', 'mirugam', 'pittam', 'പിടിപ്പ്', 'മിറുഗം',
      'ખેંચાણ', 'મિર્ગી',
      'ਦੌਰੇ', 'ਮਿਰਗੀ',
      'ବାତ', 'ମୃଗୀ',
    ],
    'lethargy': [
      'lethargy', 'unresponsive', 'lethargic', 'unconscious', 'not waking', 'weak and dull',
      'behoosh', 'sota rehta hai', 'susti', 'hosh nahi', 'jaag nahi raha',
      'बेहोश', 'सोता रहता है', 'सुस्ती', 'होश नहीं',
      'بے ہوش', 'ہوش نہیں',
      'mayakkam', 'unarchi', 'ezhumbamattu', 'sella unarchi', 'மயக்கம்', 'விழிப்பற்ற',
      'chetana levu', 'mookam', 'ezharu ledu', 'చేతన లేదు', 'మూకం',
      'ochchhonna', 'behosh', 'songhopto', 'jagena', 'অচেতন', 'বেহুঁশ',
      'बेहोश', 'सुस्त',
      'bedhuda', 'jadate', 'chelivillada', 'jagalla', 'ಮಡತೆ', 'ಜಡತೆ',
      'bodharahithyam', 'unarcha', 'ezhunilkkilla', 'manasilla', 'ബോധരാഹിത്യം', 'അവസ്ഥ മനസ്സില്ല',
      'બેભાન', 'બેહોશ',
      'ਬੇਹੋਸ਼', 'ਸੁਸਤ',
      'ବେସୁଧ', 'ଅଚେତન',
    ],
    'blood_in_stool': [
      'blood in stool', 'bloody stool', 'bloody diarrhea', 'red in poop',
      'pakhane mein khoon', 'latrine mein khoon', 'खून वाले दस्त', 'मल में खून',
      'پاخانے میں خون', 'خونی دست',
      'malam il rathiram', 'malatthil iral', 'மலத்தில் இரத்தம்',
      'malamu lo netturu', 'మలంలో నెత్తురు',
      'pajkhana te rakter', 'পায়খানায় রক্ত',
      'pottamadhe rakt', 'पोटमाडे रक्त',
      'male alli raktha', 'ಮಲದಲ್ಲಿ ರಕ್ತ',
      'malam il rathiram', 'മലത്തിൽ രക്തം',
      'latrin ma lahu', 'ઝાડામાં લોહી',
      'pakhane wich lahu', 'ਪਖਾਨੇ ਵਿੱਚ ਲਹੂ',
      'motaru re rakta', 'ମଳରେ ରକ୍ତ',
    ],
    'sunken_eyes': [
      'sunken eyes', 'eyes sunken', 'eyes hollow', 'deep set eyes',
      'aankhein dhansi', 'dhansi aankhein', 'aankhein andar', 'आँखें धंसी', 'आँखें अंदर',
      'آنکھیں دھنسی', 'گہری آنکھیں',
      'vizhi ulle poyiruku', 'kannin kulippu', 'கண் உள்ளே',
      'kannu lodaki potundi', 'కన్ను లోడికి',
      'chokh dhone gache', 'চোখ ডুবে গেছে',
      'dolya dhaslya', 'डोळे धासल्या',
      'kannu olagade', 'ಕಣ್ಣು ಒಳಗಡೆ',
      'kannu ullilekku', 'കണ്ണ് ഉള്ളിലേക്ക്',
      'aankhein dhasi', 'આંખ ઊતરી',
      'aakhaan dhansi', 'ਅੱਖਾਂ ਡੁੱਬੀ',
      'aakhi dhana', 'ଆଖି ଧସା',
    ],
    'unable_to_drink': [
      'cannot drink', 'not drinking', 'refuses to drink', 'unable to drink', 'not able to drink', 'not breastfeeding', 'not feeding',
      'pi nahi raha', 'pi nahi sakta', 'kuch pi nahi raha', 'doodh nahi pi raha', 'पी नहीं रहा', 'पीने में तकलीफ',
      'پی نہیں رہا', 'پینے میں دشواری',
      'kudikka mudiyala', 'kudikka mateengra', 'குடிக்க முடியல',
      'tagalenu', 'taga ledu', 'తాగలేడు',
      'khete parchche na', 'খেতে পারছে না',
      'pieu nahi shakat', 'पिऊ शकत नाही',
      'kudiyodakke aagalla', 'ಕುಡಿಯೊದಕ್ಕೆ ಆಗಲ್ಲ',
      'kudikkan patilla', 'കുടിക്കാൻ പറ്റുന്നില്ല',
      'pi saktu nathi', 'પી શકતો નથી',
      'pi nahi sakda', 'ਪੀ ਨਹੀਂ ਸਕਦਾ',
      'piba para nahi', 'ପିବ ପାରୁ ନାହିଁ',
    ],
    'stiff_neck': [
      'stiff neck', 'neck stiff', 'neck rigidity', 'rigid neck', 'cannot bend neck',
      'gardan akad', 'gardan seedhi', 'gardan nahi jhukti', 'गर्दन अकड़', 'गर्दन सीधी',
      'گردن اکڑ', 'گردن نہیں جھکتی',
      'kuzhal kaduppam', 'kanjam thadam', 'கழுத்து இறுக்கம்',
      'meda akkadam', 'మెడ అక్కడం',
      'gharer ghad shakata', 'ঘাড় শক্ত',
      'maneki akhad', 'मान अकडणे',
      'kothlu gatthu', 'ಕೊರಳು ಗಟ್ಟಿ',
      'kazhuth kakkal', 'കഴുത്ത് കക്കൽ',
      'gadan akad', 'ગળાનો ઉલ્ઝન',
      'gardan akak', 'ਗਰਦਨ ਅਕੜ',
      'gala bhota', 'ଗଳା ଭୋଟା',
    ],
    'ear_pain': [
      'ear pain', 'ear ache', 'ear discharge', 'discharge from ear', 'pus from ear', 'ear hurts',
      'kaan mein dard', 'kaan dard', 'kaan se mawad', 'कान दर्द', 'कान में दर्द',
      'کان میں درد', 'کان سے مواد',
      'sevidu vali', 'kan vali', 'செவிடு வலி',
      'chevi noppi', 'chevinundi draavamu', 'చెవి నొప్పి',
      'kan e byatha', 'কানে ব্যথা',
      'kana dukane', 'कान दुखणे',
      'kivi novu', 'ಕಿವಿ ನೋವು',
      'chevi novu', 'ചെവി വേദന',
      'kan ma dard', 'કાન માં દર્દ',
      'kann vich dard', 'ਕੰਨ ਵਿੱਚ ਦਰਦ',
      'kaan re byatha', 'କାନ ବ୍ୟଥା',
    ],
    'mastoid_swelling': [
      'mastoid swelling', 'swelling behind ear', 'bone behind ear swollen', 'ear bone swelling',
      'kaan ke peeche sujan', 'kaan ke peeche gaanth', 'कान के पीछे सूजन', 'कान पीछे गांठ',
      'کان کے پیچھے سوجن',
      'kan pakkam vaippu', 'kan parikku pirakke', 'கான் பக்கம் வைப்பு',
      'chevi venaka vuppu', 'చెవి వెనక వుప్పు',
      'kan er pechone fulay', 'কানের পেছনে ফুলে',
      'kanava maghe sujan', 'कानामागे सूज',
      'kivi hinde ootu', 'ಕಿವಿ ಹಿಂದೆ ಊತ',
      'chevi pirakku nerippu', 'ചെവി പിറകിൽ നീർ',
      'kan pachi sujan', 'કાન પાછળ સૂઝ',
      'kann picho sujan', 'ਕੰਨ ਪਿੱਛੇ ਸੋਜ',
      'kaan pachha fulia', 'କାନ ପଛ ଫୁଲ',
    ],
    'restless_irritable': [
      'restless', 'irritable', 'fussy', 'crying a lot', "won't settle", 'unsettled',
      'bechaini', 'chidchida', 'rota rehta', 'बेचैनी', 'चिड़चिड़ा',
      'بے چینی', 'چڑچڑا',
      'alaichiyal', 'kavalai', 'அலைச்சல்',
      'notarigaa', 'notu pigilinchu', 'నొటరిగా',
      'chanchalo', 'karatar kanna', 'চঞ্চল',
      'bechaini', 'khidkhida', 'बेचैनी',
      'chanchalathe', 'ganda', 'ಚಂಚಲತೆ',
      'athashantam', 'thamasham', 'അസ്വസ്ഥ',
      'bechaini', 'tadaphu', 'બેચૈની',
      'becheni', 'chirchira', 'ਬੇਚੈਨੀ',
      'bechaeni', 'khitkhita', 'ବ୍ୟଗ୍ରତା',
    ],
  };

  /// Multilingual Spoken Word to Number Parser
  static int? _parseWordToNumber(String word) {
    final clean = word.trim().toLowerCase();
    final numMap = {
      'ek': 1, 'okati': 1, 'ondu': 1, 'onnu': 1, 'one': 1,
      'do': 2, 'randu': 2, 'rendu': 2, 'yeradu': 2, 'two': 2,
      'teen': 3, 'tin': 3, 'moodu': 3, 'moondru': 3, 'moonnu': 3, 'mooru': 3, 'three': 3,
      'char': 4, 'naalku': 4, 'naalu': 4, 'naalugu': 4, 'four': 4,
      'panch': 5, 'paanch': 5, 'aidu': 5, 'anchu': 5, 'anju': 5, 'five': 5,
      'cheh': 6, 'aaru': 6, 'six': 6,
      'saat': 7, 'eduru': 7, 'elu': 7, 'ezhu': 7, 'seven': 7,
      'aath': 8, 'aathh': 8, 'entu': 8, 'ettu': 8, 'eight': 8,
      'nau': 9, 'ombattu': 9, 'onbadhu': 9, 'tommidi': 9, 'nine': 9,
      'das': 10, 'hattu': 10, 'padi': 10, 'pathu': 10, 'ten': 10,
      'pandrah': 15, 'fifteen': 15,
      'bees': 20, 'beez': 20, 'twenty': 20,
      'chalis': 40, 'forty': 40,
      'pachaas': 50, 'fifty': 50,
      'saath': 60, 'sixty': 60,
    };
    return numMap[clean];
  }

  /// Parses raw ASHA audio transcripts into structured IMCI clinical entities
  static AshaNlpResult parseTranscript(String transcript) {
    if (transcript.isEmpty) {
      return AshaNlpResult(
        rawTranscript: '',
        extractedFields: ExtractedFields(symptoms: []),
        extractionConfidence: 0.0,
      );
    }

    final textLower = transcript.toLowerCase();

    // 1. AGE EXTRACTION
    int? ageMonths;
    final monthReg = RegExp(
      r'(\d+|\b(?:ek|do|teen|char|panch|cheh|saat|aath|nau|das|pandrah|bees)\b)\s*(-|\s)?\s*(mahine|mahina|month|months|m|महिने|महिना|maadam|maas|masam|tingal)\b',
      caseSensitive: false,
    );
    final monthMatch = monthReg.firstMatch(textLower);

    if (monthMatch != null) {
      final valStr = monthMatch.group(1) ?? '';
      ageMonths = int.tryParse(valStr) ?? _parseWordToNumber(valStr);
    } else {
      final yearReg = RegExp(
        r'(\d+(?:\.\d+)?|\b(?:ek|do|teen|char|panch)\b)\s*(-|\s)?\s*(saal|year|years|yr|yrs|साल|वर्ष|varsh|varsha)\b',
        caseSensitive: false,
      );
      final yearMatch = yearReg.firstMatch(textLower);
      if (yearMatch != null) {
        final valStr = yearMatch.group(1) ?? '';
        final yrs = double.tryParse(valStr) ?? (_parseWordToNumber(valStr)?.toDouble());
        if (yrs != null) {
          ageMonths = (yrs * 12).round();
        }
      }
    }

    // 2. RESPIRATORY RATE EXTRACTION
    int? respiratoryRate;
    final rrPatterns = [
      RegExp(r'(\d+|\b(?:chalis|pachaas|saath)\b)\s*(?:saans\s*rate|saans/min|saans\s*per\s*min|breaths\s*per\s*minute|breaths/min|\/min|श्वास/मि)'),
      RegExp(r'(?:rr|respiratory\s*rate|rate|saans|श्वास)\s*(?:of|is|:)?\s*(\d+)'),
      RegExp(r'(\d+)\s*(?:saans|breaths|श्वास)\b'),
    ];

    for (final pat in rrPatterns) {
      final match = pat.firstMatch(textLower);
      if (match != null) {
        final valStr = match.group(1) ?? match.group(2);
        if (valStr != null) {
          respiratoryRate = int.tryParse(valStr) ?? _parseWordToNumber(valStr);
          if (respiratoryRate != null) break;
        }
      }
    }

    // 3. TEMPERATURE EXTRACTION
    double? temperatureF;
    final tempReg = RegExp(r'(\d{2,3}(?:\.\d)?)\s*(?:°f|f|fahrenheit|degree|डिग्री)?');
    final tempMatch = tempReg.firstMatch(textLower);
    if (tempMatch != null) {
      final tVal = double.tryParse(tempMatch.group(1) ?? '');
      if (tVal != null && tVal >= 95.0 && tVal <= 108.0) {
        temperatureF = tVal;
      }
    }

    // 4. SYMPTOM MATCHING VIA THESAURUS
    final List<String> detectedSymptoms = [];

    thesaurus.forEach((symptomKey, terms) {
      for (final term in terms) {
        if (textLower.contains(term.toLowerCase())) {
          detectedSymptoms.add(symptomKey);
          break;
        }
      }
    });

    final bool hasFever = detectedSymptoms.contains('fever');
    final bool hasChestIndrawing = detectedSymptoms.contains('chest_indrawing');
    final bool hasConvulsions = detectedSymptoms.contains('convulsions');
    final bool hasVomiting =
        detectedSymptoms.contains('vomiting') || detectedSymptoms.contains('vomiting_everything');
    final bool hasVomitingEverything = detectedSymptoms.contains('vomiting_everything');
    final bool hasLethargy = detectedSymptoms.contains('lethargy');
    final bool hasBloodInStool = detectedSymptoms.contains('blood_in_stool');
    final bool hasSunkenEyes = detectedSymptoms.contains('sunken_eyes');
    final bool hasUnableToDrink = detectedSymptoms.contains('unable_to_drink');
    final bool hasStiffNeck = detectedSymptoms.contains('stiff_neck');
    final bool hasEarPain = detectedSymptoms.contains('ear_pain');
    final bool hasMastoidSwelling = detectedSymptoms.contains('mastoid_swelling');
    final bool hasRestlessIrritable = detectedSymptoms.contains('restless_irritable');

    // 5. FEVER DURATION EXTRACTION
    int feverDays = 0;
    if (hasFever || textLower.contains('din') || textLower.contains('day') || textLower.contains('दिवस') || textLower.contains('roju') || textLower.contains('naal')) {
      final feverDayReg1 = RegExp(r'(\d+|\b(?:ek|do|teen|char|panch|cheh|saat)\b)\s*(?:din|day|days|दिवस|roju|naal)\s*(?:se)?(?:\s*(?:bukhar|fever|ताप))?');
      final feverDayReg2 = RegExp(r'(?:bukhar|fever|ताप)\s*(?:for|se)?\s*(\d+|\b(?:ek|do|teen|char|panch)\b)\s*(?:din|day|days|दिवस|roju|naal)');

      var fMatch = feverDayReg1.firstMatch(textLower);
      fMatch ??= feverDayReg2.firstMatch(textLower);

      if (fMatch != null) {
        final valStr = fMatch.group(1) ?? '';
        feverDays = int.tryParse(valStr) ?? _parseWordToNumber(valStr) ?? 0;
      }
    }

    // 5b. DIARRHOEA DURATION EXTRACTION
    int diarrhoeaDays = 0;
    if (detectedSymptoms.contains('diarrhea') || textLower.contains('dast') || textLower.contains('diarrhea')) {
      final diaDayReg1 = RegExp(r'(?:dast|diarrhea|loose motion|pakhana|atisar)\s*(?:se|for)?\s*(\d+|\b(?:ek|do|teen|char|panch|cheh|saat)\b)\s*(?:din|day|days|दिवस|roju|naal)');
      final diaDayReg2 = RegExp(r'(\d+|\b(?:ek|do|teen|char|panch|cheh|saat)\b)\s*(?:din|day|days|दिवस|roju|naal)\s*(?:se)?(?:\s*(?:dast|diarrhea|loose motion))?');

      var dMatch = diaDayReg1.firstMatch(textLower);
      dMatch ??= diaDayReg2.firstMatch(textLower);

      if (dMatch != null) {
        final valStr = dMatch.group(1) ?? '';
        diarrhoeaDays = int.tryParse(valStr) ?? _parseWordToNumber(valStr) ?? 0;
      }
    }

    // 6. CONFIDENCE SCORE CALCULATION
    int filledSlots = 0;
    if (ageMonths != null) filledSlots += 1;
    if (respiratoryRate != null) filledSlots += 1;
    if (feverDays > 0 || diarrhoeaDays > 0) filledSlots += 1;
    if (detectedSymptoms.isNotEmpty) {
      filledSlots += 2;
    } else {
      filledSlots += 1;
    }

    final double confidence = double.parse((min(1.0, filledSlots / 5.0)).toStringAsFixed(2));

    return AshaNlpResult(
      rawTranscript: transcript,
      extractedFields: ExtractedFields(
        ageMonths: ageMonths,
        respiratoryRate: respiratoryRate,
        temperatureF: temperatureF,
        feverDays: feverDays,
        diarrhoeaDays: diarrhoeaDays,
        symptoms: detectedSymptoms,
        hasChestIndrawing: hasChestIndrawing,
        hasConvulsions: hasConvulsions,
        hasVomiting: hasVomiting,
        hasVomitingEverything: hasVomitingEverything,
        hasLethargy: hasLethargy,
        hasBloodInStool: hasBloodInStool,
        hasSunkenEyes: hasSunkenEyes,
        hasUnableToDrink: hasUnableToDrink,
        hasStiffNeck: hasStiffNeck,
        hasEarPain: hasEarPain,
        hasMastoidSwelling: hasMastoidSwelling,
        hasRestlessIrritable: hasRestlessIrritable,
      ),
      extractionConfidence: confidence,
    );
  }
}
