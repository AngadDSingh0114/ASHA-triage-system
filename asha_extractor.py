"""
ASHA Speech-to-Text & Symptom Extraction Layer (Person C)
Deterministic, offline, MULTILINGUAL rule-based Entity Extraction Engine.

Supports Hindi / Hinglish / English plus major Indian languages:
Tamil, Telugu, Bengali, Marathi, Kannada, Malayalam, Gujarati, Punjabi, Odia, Urdu.

The engine is a transparent, auditable thesaurus of symptom terms per language.
All terms are written in Latin transliteration so they match ASR / speech-to-text
output regardless of script. Native-speaker review is recommended before deployment.
"""

import re
from typing import Dict, Any, List, Optional


# ---------------------------------------------------------------------------
# Language registry
# ---------------------------------------------------------------------------
LANGUAGES: Dict[str, str] = {
    "en": "English",
    "hi": "Hindi / Hinglish",
    "ur": "Urdu",
    "ta": "Tamil",
    "te": "Telugu",
    "bn": "Bengali",
    "mr": "Marathi",
    "kn": "Kannada",
    "ml": "Malayalam",
    "gu": "Gujarati",
    "pa": "Punjabi",
    "or": "Odia",
}


# ---------------------------------------------------------------------------
# Symptom thesaurus (per language, Latin transliteration)
# Each symptom maps to {language_code: [terms...]}
# ---------------------------------------------------------------------------
SYMPTOM_TERMS: Dict[str, Dict[str, List[str]]] = {
        "fever": {
                "en": [
                        "fever",
                        "temperature",
                        "high temperature",
                        "garam body",
                        "garam hai"
                ],
                "hi": [
                        "bukhar",
                        "bukar",
                        "taap",
                        "jwar",
                        "garam",
                        "बुखार",
                        "तेज बुखार",
                        "ज्वर",
                        "बुखार है"
                ],
                "ur": [
                        "bukhar",
                        "bukar",
                        "taap",
                        "بخار",
                        "بخار ہے",
                        "تپ"
                ],
                "ta": [
                        "kaaychal",
                        "jvaram",
                        "veppam",
                        "காய்ச்சல்",
                        "காய்ச்சல் இருக்கு"
                ],
                "te": [
                        "jvaram",
                        "jwaram",
                        "veyivaram",
                        "జ్వరం",
                        "జ్వరం ఉంది"
                ],
                "bn": [
                        "jwor",
                        "jor",
                        "jara",
                        "জ্বর",
                        "জ্বর আছে"
                ],
                "mr": [
                        "taap",
                        "tapan",
                        "jwara",
                        "ताप",
                        "ज्वर",
                        "ताप आहे"
                ],
                "kn": [
                        "jvara",
                        "jvar",
                        "bisilu",
                        "ಜ್ವರ",
                        "ಜ್ವರ ಇದೆ"
                ],
                "ml": [
                        "panni",
                        "pani",
                        "jwaram",
                        "പനി",
                        "പനി ഉണ്ട്"
                ],
                "gu": [
                        "tav",
                        "taav",
                        "juar",
                        "તાવ",
                        "તાવ છે"
                ],
                "pa": [
                        "bukhar",
                        "bukar",
                        "taap",
                        "ਬੁਖਾਰ",
                        "ਬੁਖਾਰ ਹੈ"
                ],
                "or": [
                        "jwara",
                        "jara",
                        "ଜ୍ୱର",
                        "ଜ୍ୱର ଅଛି"
                ]
        },
        "chest_indrawing": {
                "en": [
                        "chest indrawing",
                        "chest drawing",
                        "chest retraction",
                        "stridor",
                        "wheeze",
                        "retractions"
                ],
                "hi": [
                        "chhati dhasna",
                        "chhati phoolna",
                        "saans lene me dikkat",
                        "saans lene mein dikkat",
                        "chhati dhabna",
                        "छाती धंसना",
                        "छाती धसना",
                        "सांस लेने में दिक्कत"
                ],
                "ur": [
                        "chhati dhasna",
                        "chhati phoolna",
                        "saans mein dikkat",
                        "چھاتی دھنسنا",
                        "سانس لینے میں دشواری"
                ],
                "ta": [
                        "marbu ullizhuthal",
                        "edai ullizhuthal",
                        "மார்பு உள்ளிழுத்தல்",
                        "மார்பு உள்ளிழுப்பு"
                ],
                "te": [
                        "chaati padipovadam",
                        "chaati lopala",
                        "eddala posagipovadam",
                        "ఛాతి పడిపోవడం",
                        "ఛాతి లోపలికి"
                ],
                "bn": [
                        "buk doba",
                        "buk dhonba",
                        "buka dubano",
                        "বুক ডোবা",
                        "বুক ডুবে যাওয়া"
                ],
                "mr": [
                        "chhati dhasne",
                        "chhati bugne",
                        "shwas ghetana anantar",
                        "छाती दाबणे",
                        "छाती दुसने"
                ],
                "kn": [
                        "ede olagade",
                        "ede olage",
                        "shareera olagade",
                        "ಎದೆ ಒಳಗಡೆ",
                        "ಎದೆ ಒಳಕ್ಕೆ"
                ],
                "ml": [
                        "nenchu ullilekku",
                        "nench ullilekk",
                        "uravil olichu",
                        "നെഞ്ച് ഉള്ളിലേക്ക്",
                        "നെഞ്ച് ഉള്ളിലേക്ക് വലിയുന്നു"
                ],
                "gu": [
                        "chaati dobavu",
                        "chhati dobi",
                        "shwas ma rai dikkt",
                        "છાતી ડૂબવું",
                        "છાતી દબાવું"
                ],
                "pa": [
                        "chhati dabna",
                        "chhati dhasna",
                        "saah vich dushwari",
                        "ਛਾਤੀ ਡੁੱਬਣਾ",
                        "ਸਾਹ ਵਿਚ ਔਖਿਆਈ"
                ],
                "or": [
                        "chhati duba",
                        "chhati dhasiba",
                        "shwas re kasht",
                        "ଛାତି ଡୁବା",
                        "ଛାତି ଡସିବା"
                ]
        },
        "diarrhea": {
                "en": [
                        "diarrhea",
                        "loose motion",
                        "loose stools",
                        "watery stool"
                ],
                "hi": [
                        "dast",
                        "pakhana",
                        "dast lagna",
                        "paani jaisa dast",
                        "दस्त",
                        "दस्त लगना",
                        "पतले दस्त"
                ],
                "ur": [
                        "dast",
                        "pakhana",
                        "dast lagna",
                        "دست",
                        "دست لگنا"
                ],
                "ta": [
                        "vayitruppokku",
                        "peenipokku",
                        "kozhuppokku",
                        "வயிற்றுப்போக்கு",
                        "பேதி"
                ],
                "te": [
                        "virechanalu",
                        "neeru poka",
                        "విరేచనాలు",
                        "విరేచనలు"
                ],
                "bn": [
                        "atisar",
                        "oshodh",
                        "ponod",
                        "ডায়রিয়া",
                        "আতিসার",
                        "পাতলা পায়খানা"
                ],
                "mr": [
                        "atisar",
                        "dhakya",
                        "jhalya",
                        "अतिसार",
                        "जुलाब"
                ],
                "kn": [
                        "bhedi",
                        "atisara",
                        "neeru mala",
                        "ಭೇದಿ",
                        "ವಿರೇಚನೆ"
                ],
                "ml": [
                        "athisaaram",
                        "vayarupokku",
                        "jaladhosham",
                        "അതിസാരം",
                        "വയറ്റിലെ പോക്ക്"
                ],
                "gu": [
                        "jhada",
                        "dule dast",
                        "dhava",
                        "ઝાડા",
                        "દસ્ત"
                ],
                "pa": [
                        "dast",
                        "hoya",
                        "dhava",
                        "ਦਸਤ",
                        "ਹੋਇਆ"
                ],
                "or": [
                        "jhada",
                        "atisar",
                        "soda",
                        "ଝାଡ଼ା",
                        "ଅତିସାର"
                ]
        },
        "vomiting": {
                "en": [
                        "vomiting",
                        "vomit",
                        "throwing up",
                        "puking"
                ],
                "hi": [
                        "ulti",
                        "ulti aa rahi hai",
                        "उल्टी",
                        "उल्टी आना"
                ],
                "ur": [
                        "ulti",
                        "qaee",
                        "ulti aa rahi hai",
                        "الٹی",
                        "قے"
                ],
                "ta": [
                        "vaanthi",
                        "okkam",
                        "vizhuppu",
                        "வாந்தி",
                        "ஒலிப்பு"
                ],
                "te": [
                        "vaanti",
                        "venti",
                        "vanti",
                        "వాంతి",
                        "వాంతులు"
                ],
                "bn": [
                        "bombi",
                        "boma",
                        "bomni",
                        "বমি",
                        "বমি আসা"
                ],
                "mr": [
                        "ulti",
                        "odata",
                        "kadhi",
                        "उलटी",
                        "ओकार"
                ],
                "kn": [
                        "vaanti",
                        "vamathu",
                        "bombi",
                        "ವಾಂತಿ",
                        "ಬಂದಿ"
                ],
                "ml": [
                        "chardhi",
                        "vaanthi",
                        "ozhippu",
                        "ഛർദ്ദി",
                        "വാന്തി"
                ],
                "gu": [
                        "ol",
                        "olo",
                        "olkhi",
                        "ઓળ",
                        "ઓળ આવવી"
                ],
                "pa": [
                        "ulti",
                        "olna",
                        "kai",
                        "ਉਲਟੀ",
                        "ਕੈ"
                ],
                "or": [
                        "baanta",
                        "banta",
                        "bankhi",
                        "ବାନ୍ତ",
                        "ବାନ୍ତ ଆସିବା"
                ]
        },
        "vomiting_everything": {
                "en": [
                        "vomiting everything",
                        "throwing up everything",
                        "cannot keep anything down",
                        "everything comes back up"
                ],
                "hi": [
                        "sab ulti",
                        "sab kuch ulti",
                        "kha nahi raha",
                        "kuch nahi kha raha",
                        "ulti ho rahi hai sab",
                        "सब उल्टी",
                        "सब कुछ उल्टी",
                        "कुछ खा नहीं रहा"
                ],
                "ur": [
                        "sab ulti",
                        "kha nahi raha",
                        "sab kuch ulti",
                        "سب الٹی",
                        "کچھ کھا نہیں رہا"
                ],
                "ta": [
                        "ellam vaanthi",
                        "sapdura edukkala",
                        "onnum vizha mateengra",
                        "எல்லாம் வாந்தி",
                        "சாப்பிட ஏதும் வாந்தி"
                ],
                "te": [
                        "anthaa vaanti",
                        "emi thinagalenu",
                        "anthaa venti",
                        "అంతా వాంతులు",
                        "తిన్నదంతా వాంతి"
                ],
                "bn": [
                        "sob bombi",
                        "kichu khete pare na",
                        "sab bombi",
                        "সব বমি",
                        "কিছু খেতে পারে না"
                ],
                "mr": [
                        "sagla ulti",
                        "khancha yet nahi",
                        "saglya goshti ulti",
                        "सगळं उलटी",
                        "काही खायला येत नाही"
                ],
                "kn": [
                        "elli vaanti",
                        "ennu thinabardu",
                        "ella vamathu",
                        "ಎಲ್ಲ ವಾಂತಿ",
                        "ಏನೂ ತಿನ್ನಲಿಲ್ಲ"
                ],
                "ml": [
                        "ellam chardhi",
                        "onnuthinum kazhikkilla",
                        "ellam vaanthi",
                        "എല്ലാം ഛർദ്ദി",
                        "ഒന്നും കഴിക്കില്ല"
                ],
                "gu": [
                        "badhu ol",
                        "kai shakay nathi",
                        "bau ol",
                        "બધુ ઓળ",
                        "કાંઈ ખાઈ શકતું નથી"
                ],
                "pa": [
                        "sab ulti",
                        "kujh nahi kha sakda",
                        "sab kujh ulti",
                        "ਬੱਧ ਉਲਟੀ",
                        "ਕੁਝ ਨਹੀਂ ਖਾ ਸਕਦਾ"
                ],
                "or": [
                        "sabu banta",
                        "kichhi khaiparheni",
                        "sabu bankhi",
                        "ସବୁ ବାନ୍ତ",
                        "କିଛି ଖାଇପାରିବେ ନାହିଁ"
                ]
        },
        "convulsions": {
                "en": [
                        "convulsions",
                        "seizure",
                        "fit",
                        "fits",
                        "spasms"
                ],
                "hi": [
                        "jhatke",
                        "mirgi",
                        "aenthang",
                        "dardane",
                        "झटके",
                        "मिरगी",
                        "दौरे"
                ],
                "ur": [
                        "jhatke",
                        "mirgi",
                        "dore",
                        "جھٹکے",
                        "مرگی"
                ],
                "ta": [
                        "valippu",
                        "pidippu",
                        "potu",
                        "pittam",
                        "வலிப்பு",
                        "பிடிப்பு"
                ],
                "te": [
                        "mirigi",
                        "piduvatamu",
                        "mokkala",
                        "spasam",
                        "మిరిగి",
                        "పిటువాత"
                ],
                "bn": [
                        "khichuni",
                        "mrigi",
                        "aekare",
                        "খিঞ্চুনি",
                        "মৃগী"
                ],
                "mr": [
                        "akadi",
                        "mirgi",
                        "daura",
                        "आकडी",
                        "मिरगी"
                ],
                "kn": [
                        "selete",
                        "mirugi",
                        "mooka",
                        "ಸೆಳೆತ",
                        "ಮಿರುಗು"
                ],
                "ml": [
                        "pidippu",
                        "mirugam",
                        "pittam",
                        "പിടിപ്പ്",
                        "മിറുഗം"
                ],
                "gu": [
                        "khenchan",
                        "mirgi",
                        "dhara",
                        "ખેંચાણ",
                        "મિર્ગી"
                ],
                "pa": [
                        "daure",
                        "mirgi",
                        "jhatke",
                        "ਦੌਰੇ",
                        "ਮਿਰਗੀ"
                ],
                "or": [
                        "baat",
                        "mrigi",
                        "aakade",
                        "ବାତ",
                        "ମୃଗୀ"
                ]
        },
        "lethargy": {
                "en": [
                        "lethargy",
                        "unresponsive",
                        "lethargic",
                        "unconscious",
                        "not waking",
                        "weak and dull"
                ],
                "hi": [
                        "behoosh",
                        "sota rehta hai",
                        "susti",
                        "hosh nahi",
                        "jaag nahi raha",
                        "बेहोश",
                        "सोता रहता है",
                        "सुस्ती",
                        "होश नहीं"
                ],
                "ur": [
                        "behoosh",
                        "sota rehta hai",
                        "hosh nahi",
                        "بے ہوش",
                        "ہوش نہیں"
                ],
                "ta": [
                        "mayakkam",
                        "unarchi",
                        "ezhumbamattu",
                        "sella unarchi",
                        "மயக்கம்",
                        "விழிப்பற்ற"
                ],
                "te": [
                        "chetana levu",
                        "mookam",
                        "ezharu ledu",
                        "చేతన లేదు",
                        "మూకం"
                ],
                "bn": [
                        "ochchhonna",
                        "behosh",
                        "songhopto",
                        "jagena",
                        "অচেতন",
                        "বেহুঁশ"
                ],
                "mr": [
                        "behosh",
                        "sust",
                        "jagatch nahi",
                        "behoshi",
                        "बेहोश",
                        "सुस्त"
                ],
                "kn": [
                        "bedhuda",
                        "jadate",
                        "chelivillada",
                        "jagalla",
                        "ಮಡತೆ",
                        "ಜಡತೆ"
                ],
                "ml": [
                        "bodharahithyam",
                        "unarcha",
                        "ezhunilkkilla",
                        "manasilla",
                        "ബോധരാഹിത്യം",
                        "അവസ്ഥ മനസ്സില്ല"
                ],
                "gu": [
                        "behosh",
                        "benaan",
                        "jaagta nathi",
                        "benaan",
                        "બેભાન",
                        "બેહોશ"
                ],
                "pa": [
                        "behosh",
                        "sust",
                        "jag nahi raha",
                        "hosh nahi",
                        "ਬੇਹੋਸ਼",
                        "ਸੁਸਤ"
                ],
                "or": [
                        "besudh",
                        "behosi",
                        "jagena",
                        "chetanahin",
                        "ବେସୁଧ",
                        "ଅଚେତନ"
                ]
        }
}


# Flattened thesaurus (backwards-compatible view, all languages merged)
THESAURUS: Dict[str, List[str]] = {
    s_key: [t for lang_terms in lang_map.values() for t in lang_terms]
    for s_key, lang_map in SYMPTOM_TERMS.items()
}


# ---------------------------------------------------------------------------
# Multilingual number words (falls back when ASR emits words instead of digits)
# ---------------------------------------------------------------------------
NUMBER_WORDS: Dict[str, int] = {"ek": 1, "do": 2, "teen": 3, "char": 4, "panch": 5, "cheh": 6, "saat": 7, "aath": 8, "nau": 9, "das": 10, "onnu": 1, "rendu": 2, "moondru": 3, "naalu": 4, "anju": 5, "aaru": 6, "ezhu": 7, "ettu": 8, "onbadhu": 9, "pathu": 10, "okati": 1, "moodu": 3, "naalugu": 4, "aidu": 5, "eduru": 7, "tommidi": 9, "padi": 10, "ondu": 1, "yeradu": 2, "mooru": 3, "naalku": 4, "elu": 7, "entu": 8, "ombattu": 9, "hattu": 10, "randu": 2, "moonnu": 3, "anchu": 5, "एक": 1, "दो": 2, "तीन": 3, "चार": 4, "पांच": 5, "छह": 6, "सात": 7, "आठ": 8, "नौ": 9, "दस": 10, "दोन": 2, "पाच": 5, "सहा": 6, "नऊ": 9, "दहा": 10, "એક": 1, "બે": 2, "ત્રણ": 3, "ચાર": 4, "પાંચ": 5, "છ": 6, "સાત": 7, "આઠ": 8, "નવ": 9, "દસ": 10, "ਇੱਕ": 1, "ਦੋ": 2, "ਤਿੰਨ": 3, "ਚਾਰ": 4, "ਪੰਜ": 5, "ਛੇ": 6, "ਸੱਤ": 7, "ਅੱਠ": 8, "ਨੌ": 9, "ਦਸ": 10, "ஒன்று": 1, "இரண்டு": 2, "மூன்று": 3, "நான்கு": 4, "ஐந்து": 5, "ஆறு": 6, "ஏழு": 7, "எட்டு": 8, "ஒன்பது": 9, "பத்து": 10, "ఒకటి": 1, "రెండు": 2, "మూడు": 3, "నాలుగు": 4, "ఐదు": 5, "ఆరు": 6, "ఏడు": 7, "ఎనిమిది": 8, "తొమ్మిది": 9, "పది": 10, "এক": 1, "দুই": 2, "তিন": 3, "চার": 4, "পাঁচ": 5, "ছয়": 6, "সাত": 7, "আট": 8, "নয়": 9, "দশ": 10, "ಒಂದು": 1, "ಎರಡು": 2, "ಮೂರು": 3, "ನಾಲ್ಕು": 4, "ಐದು": 5, "ಆರು": 6, "ಏಳು": 7, "ಎಂಟು": 8, "ಒಂಬತ್ತು": 9, "ಹತ್ತು": 10, "ഒന്ന്": 1, "രണ്ട്": 2, "മൂന്ന്": 3, "നാലു": 4, "അഞ്ച്": 5, "ആറ്": 6, "ഏഴ്": 7, "എട്ട്": 8, "ഒൻപത്": 9, "പത്ത്": 10, "ایک": 1, "دو": 2, "تین": 3, "چار": 4, "پانچ": 5, "چھے": 6, "سات": 7, "آٹھ": 8, "نو": 9, "دس": 10, "ଏକ": 1, "ଦୁଇ": 2, "ତିନି": 3, "ଚାରି": 4, "ପାଞ୍ଚ": 5, "ଛଅ": 6, "ସାତ": 7, "ଆଠ": 8, "ନଅ": 9, "ଦଶ": 10}


# ---------------------------------------------------------------------------
# Multilingual unit words
# ---------------------------------------------------------------------------
MONTH_WORDS: List[str] = ["maadam", "maadham", "maas", "maasam", "maheen", "mahina", "mahine", "masalu", "masam", "matha", "matham", "month", "months", "tingal", "مہینہ", "महिना", "महीने", "মাস", "ਮਹੀਨਾ", "મહિનો", "ମାସ", "மாதம்", "నెల", "మాసం", "ಮಾಸ", "മാസം"]
DAY_WORDS: List[str] = ["day", "days", "din", "dina", "divas", "divasam", "divasangal", "naal", "naalu", "roju", "دن", "दिन", "दिवस", "দিন", "ਦਿਨ", "દિવસ", "ଦିନ", "நாள்", "ரோஜு", "ದಿನ", "ദിവസം"]
YEAR_WORDS: List[str] = ["bachhar", "barsh", "saal", "samvatsaram", "varsh", "varsha", "varush", "varusham", "year", "years", "yr", "yrs", "سال", "वर्ष", "साल", "বছর", "ਬਰ�", "ਸਾਲ", "સાલ", "ବର୍ஷ", "ஆண்டு", "வருடம்", "సంవత్సరం", "ಸಂವತ్సರ", "വർஷம்"]


def _alt(words: List[str]) -> str:
    """Build a regex alternation sorted longest-first to avoid partial matches."""
    return "(?:" + "|".join(re.escape(w) for w in sorted(set(words), key=len, reverse=True)) + ")"


_MONTH_ALT = _alt(MONTH_WORDS)
_DAY_ALT = _alt(DAY_WORDS)
_YEAR_ALT = _alt(YEAR_WORDS)


def _word_to_number(text_lower: str) -> Optional[int]:
    for word, value in NUMBER_WORDS.items():
        if re.search(r"(?<!\w)" + re.escape(word) + r"(?!\w)", text_lower):
            return value
    return None


def detect_language(transcript: str) -> str:
    """
    Best-effort, transliteration-based language detection.
    Counts symptom-term hits per language and returns the dominant code.
    Falls back to 'en' when no signal is found.
    """
    text_lower = (transcript or "").lower()
    if not text_lower.strip():
        return "en"

    scores: Dict[str, int] = {code: 0 for code in LANGUAGES}
    for lang_map in SYMPTOM_TERMS.values():
        for lang, terms in lang_map.items():
            for term in terms:
                if re.search(r"\b" + re.escape(term) + r"\b", text_lower) or term in text_lower:
                    scores[lang] += 1

    best_lang = max(scores, key=lambda k: scores[k])
    if scores[best_lang] == 0:
        return "en"
    return best_lang


def parse_asha_transcript(transcript: str) -> Dict[str, Any]:
    """
    Parses raw multilingual ASHA transcriptions into structured IMCI data schema.
    """
    if not transcript or not isinstance(transcript, str):
        return {
            "raw_transcript": transcript or "",
            "language": "en",
            "extracted_fields": {
                "age_months": None,
                "respiratory_rate": None,
                "fever_days": 0,
                "symptoms": [],
                "has_chest_indrawing": False,
                "has_convulsions": False,
                "has_vomiting": False,
                "has_vomiting_everything": False,
                "has_lethargy": False,
            },
            "extraction_confidence": 0.0,
        }

    text_lower = transcript.lower()
    language = detect_language(transcript)

    # --- 1. AGE EXTRACTION (digits or number words, months or years) ---
    age_months: Optional[int] = None
    month_match = re.search(r"(\d+)\s*(?:-| )?\s*" + _MONTH_ALT + r"(?!\w)", text_lower)
    if month_match:
        age_months = int(month_match.group(1))
    else:
        year_match = re.search(r"(\d+(?:\.\d+)?)\s*(?:-| )?\s*" + _YEAR_ALT + r"(?!\w)", text_lower)
        if year_match:
            age_months = int(float(year_match.group(1)) * 12)
        else:
            wnum = _word_to_number(text_lower)
            if wnum is not None:
                if re.search(_MONTH_ALT + r"(?!\w)", text_lower):
                    age_months = wnum
                elif re.search(_YEAR_ALT + r"(?!\w)", text_lower):
                    age_months = wnum * 12

    # --- 2. RESPIRATORY RATE EXTRACTION ---
    respiratory_rate: Optional[int] = None
    rr_patterns = [
        r"(\d+)\s*(?:saans\s*rate|saans/min|saans\s*per\s*min|breaths\s*per\s*minute|breaths/min|\/min|श्वास\s*rate|सांस\s*rate)",
        r"(?:rr|respiratory\s*rate|rate|saans|shwas|uchchwasam|kaal|mozhi|सांस|श्वास|શ્વાસ|ਸਾਹ|மூச்சு|శ్వాస|শ্বাস|ಉಸಿರು|ശ്വാസം|سانس|ଶ୍ୱାस)\s*(?:of|is|:)?\s*(\d+)",
        r"(\d+)\s*(?:saans|breaths|shwas|सांस|श्वास|શ્વાસ|ਸਾਹ|மூச்சு|శ్వాస|শ্বাস|ಉಸಿರು|ശ്വాసം|سانس|ଶ୍ୱାस)(?!\w)",
    ]
    for pat in rr_patterns:
        match = re.search(pat, text_lower)
        if match:
            num_str = match.group(1) if match.group(1) else match.group(2)
            if num_str:
                respiratory_rate = int(num_str)
                break

    # --- 3. SYMPTOM MATCHING (all languages) ---
    detected_symptoms: List[str] = []
    for s_key, lang_map in SYMPTOM_TERMS.items():
        for term in (t for terms in lang_map.values() for t in terms):
            if re.search(r"\b" + re.escape(term) + r"\b", text_lower) or term in text_lower:
                detected_symptoms.append(s_key)
                break

    has_fever = "fever" in detected_symptoms
    has_chest_indrawing = "chest_indrawing" in detected_symptoms
    has_convulsions = "convulsions" in detected_symptoms
    has_vomiting = "vomiting" in detected_symptoms or "vomiting_everything" in detected_symptoms
    has_vomiting_everything = "vomiting_everything" in detected_symptoms
    has_lethargy = "lethargy" in detected_symptoms

    # --- 4. FEVER DURATION EXTRACTION ---
    fever_days: int = 0
    if has_fever or re.search(_DAY_ALT + r"\b", text_lower):
        fever_day_match = re.search(
            r"(\d+)\s*" + _DAY_ALT + r"\s*(?:se)?(?:\s*(?:bukhar|jwar|fever|jvaram|kaaychal|panni))?",
            text_lower,
        )
        if not fever_day_match:
            fever_day_match = re.search(
                r"(?:bukhar|jwar|fever|jvaram|kaaychal|panni)\s*(?:for|se)?\s*(\d+)\s*" + _DAY_ALT,
                text_lower,
            )
        if fever_day_match:
            fever_days = int(fever_day_match.group(1))

    # --- 5. CONFIDENCE CALCULATION ---
    filled_slots = 0
    if age_months is not None:
        filled_slots += 1
    if respiratory_rate is not None:
        filled_slots += 1
    if fever_days > 0:
        filled_slots += 1
    if len(detected_symptoms) > 0:
        filled_slots += 2
    else:
        filled_slots += 1

    confidence = round(min(1.0, filled_slots / 5.0), 2)

    return {
        "raw_transcript": transcript,
        "language": language,
        "extracted_fields": {
            "age_months": age_months,
            "respiratory_rate": respiratory_rate,
            "fever_days": fever_days,
            "symptoms": detected_symptoms,
            "has_chest_indrawing": has_chest_indrawing,
            "has_convulsions": has_convulsions,
            "has_vomiting": has_vomiting,
            "has_vomiting_everything": has_vomiting_everything,
            "has_lethargy": has_lethargy,
        },
        "extraction_confidence": confidence,
    }


# ---------------------------------------------------------------------------
# Localized referral note generator
# ---------------------------------------------------------------------------
_REFERRAL_TEMPLATES: Dict[str, Dict[str, str]] = {
    "YELLOW_PHC": {
        "en": "Suspected pneumonia. Refer to PHC within 24 hours.",
        "hi": "संदिग्ध निमोनिया। 24 घंटे के भीतर PHC भेजें।",
    },
    "RED_URGENT": {
        "en": "Severe illness / Danger signs present. Refer IMMEDIATELY to hospital.",
        "hi": "गंभीर बीमारी / खतरे के लक्षण मौजूद। तुरंत अस्पताल रेफर करें।",
    },
    "GREEN_HOME": {
        "en": "Mild illness. Home care advised; return if signs worsen.",
        "hi": "हल्की बीमारी। घर पर देखभाल; लक्षण बिगड़ें तो वापस आएं।",
    },
}


def generate_referral_note(extract: Dict[str, Any], triage_code: str, lang: Optional[str] = None) -> str:
    """
    Produces a human-readable clinical referral note. English clinical detail is
    always included (required by downstream systems); a localized header is
    prepended when the detected / requested language has a translation.
    """
    lang = lang or extract.get("language", "en")
    fields = extract.get("extracted_fields", {})

    template = _REFERRAL_TEMPLATES.get(triage_code, _REFERRAL_TEMPLATES["GREEN_HOME"])
    localized = template.get(lang, template["en"])

    age = fields.get("age_months")
    rr = fields.get("respiratory_rate")
    symptoms = ", ".join(fields.get("symptoms", [])) or "none"

    header = f"[Referral Note] Patient age: {age or 'N/A'} months | RR: {rr or 'N/A'} | Symptoms: {symptoms}\n"
    note = header + localized
    if lang in _REFERRAL_TEMPLATES[triage_code] and lang != "en":
        note += "\n" + template["en"]
    return note

