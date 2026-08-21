# ASHA Triage - Diagnosis Keyword Classifications

> Reference of every symptom keyword the NLP model matches, grouped by clinical class and language,
> followed by the WHO IMCI classification rules that turn those keywords into a triage decision.
> Auto-generated from `asha_extractor.py` + `imci_rules_engine.py`. Terms are Latin transliterations
> so they match speech-to-text output regardless of script.

## 1. Symptom keyword classes (by language)

Each clinical class is detected when **any** term for that class appears in the transcript.

### Fever

- **English** (`en`): fever, garam body, garam hai, high temperature, temperature
- **Hindi / Hinglish** (`hi`): bukar, bukhar, garam, jwar, taap
- **Urdu** (`ur`): bukar, bukhar, taap
- **Tamil** (`ta`): jvaram, kaaychal, veppam
- **Telugu** (`te`): jvaram, jwaram, veyivaram
- **Bengali** (`bn`): jara, jor, jwor
- **Marathi** (`mr`): jwara, taap, tapan
- **Kannada** (`kn`): bisilu, jvar, jvara
- **Malayalam** (`ml`): jwaram, pani, panni
- **Gujarati** (`gu`): juar, taav, tav
- **Punjabi** (`pa`): bukar, bukhar, taap
- **Odia** (`or`): jara, jwara

### Chest Indrawing

- **English** (`en`): chest drawing, chest indrawing, chest retraction, retractions, stridor, wheeze
- **Hindi / Hinglish** (`hi`): chhati dhabna, chhati dhasna, chhati phoolna, saans lene me dikkat, saans lene mein dikkat
- **Urdu** (`ur`): chhati dhasna, chhati phoolna, saans mein dikkat
- **Tamil** (`ta`): edai ullizhuthal, marbu ullizhuthal
- **Telugu** (`te`): chaati lopala, chaati padipovadam, eddala posagipovadam
- **Bengali** (`bn`): buk dhonba, buk doba, buka dubano
- **Marathi** (`mr`): chhati bugne, chhati dhasne, shwas ghetana anantar
- **Kannada** (`kn`): ede olagade, ede olage, shareera olagade
- **Malayalam** (`ml`): nench ullilekk, nenchu ullilekku, uravil olichu
- **Gujarati** (`gu`): chaati dobavu, chhati dobi, shwas ma rai dikkt
- **Punjabi** (`pa`): chhati dabna, chhati dhasna, saah vich dushwari
- **Odia** (`or`): chhati dhasiba, chhati duba, shwas re kasht

### Diarrhea

- **English** (`en`): diarrhea, loose motion, loose stools, watery stool
- **Hindi / Hinglish** (`hi`): dast, dast lagna, paani jaisa dast, pakhana
- **Urdu** (`ur`): dast, dast lagna, pakhana
- **Tamil** (`ta`): kozhuppokku, peenipokku, vayitruppokku
- **Telugu** (`te`): neeru poka, virechanalu
- **Bengali** (`bn`): atisar, oshodh, ponod
- **Marathi** (`mr`): atisar, dhakya, jhalya
- **Kannada** (`kn`): atisara, bhedi, neeru mala
- **Malayalam** (`ml`): athisaaram, jaladhosham, vayarupokku
- **Gujarati** (`gu`): dhava, dule dast, jhada
- **Punjabi** (`pa`): dast, dhava, hoya
- **Odia** (`or`): atisar, jhada, soda

### Vomiting

- **English** (`en`): puking, throwing up, vomit, vomiting
- **Hindi / Hinglish** (`hi`): ulti, ulti aa rahi hai
- **Urdu** (`ur`): qaee, ulti, ulti aa rahi hai
- **Tamil** (`ta`): okkam, vaanthi, vizhuppu
- **Telugu** (`te`): vaanti, vanti, venti
- **Bengali** (`bn`): boma, bombi, bomni
- **Marathi** (`mr`): kadhi, odata, ulti
- **Kannada** (`kn`): bombi, vaanti, vamathu
- **Malayalam** (`ml`): chardhi, ozhippu, vaanthi
- **Gujarati** (`gu`): ol, olkhi, olo
- **Punjabi** (`pa`): kai, olna, ulti
- **Odia** (`or`): baanta, bankhi, banta

### Vomiting Everything

- **English** (`en`): cannot keep anything down, everything comes back up, throwing up everything, vomiting everything
- **Hindi / Hinglish** (`hi`): kha nahi raha, kuch nahi kha raha, sab kuch ulti, sab ulti, ulti ho rahi hai sab
- **Urdu** (`ur`): kha nahi raha, sab kuch ulti, sab ulti
- **Tamil** (`ta`): ellam vaanthi, onnum vizha mateengra, sapdura edukkala
- **Telugu** (`te`): anthaa vaanti, anthaa venti, emi thinagalenu
- **Bengali** (`bn`): kichu khete pare na, sab bombi, sob bombi
- **Marathi** (`mr`): khancha yet nahi, sagla ulti, saglya goshti ulti
- **Kannada** (`kn`): ella vamathu, elli vaanti, ennu thinabardu
- **Malayalam** (`ml`): ellam chardhi, ellam vaanthi, onnuthinum kazhikkilla
- **Gujarati** (`gu`): badhu ol, bau ol, kai shakay nathi
- **Punjabi** (`pa`): kujh nahi kha sakda, sab kujh ulti, sab ulti
- **Odia** (`or`): kichhi khaiparheni, sabu bankhi, sabu banta

### Convulsions

- **English** (`en`): convulsions, fit, fits, seizure, spasms
- **Hindi / Hinglish** (`hi`): aenthang, dardane, jhatke, mirgi
- **Urdu** (`ur`): dore, jhatke, mirgi
- **Tamil** (`ta`): pidippu, pittam, potu, valippu
- **Telugu** (`te`): mirigi, mokkala, piduvatamu, spasam
- **Bengali** (`bn`): aekare, khichuni, mrigi
- **Marathi** (`mr`): akadi, daura, mirgi
- **Kannada** (`kn`): mirugi, mooka, selete
- **Malayalam** (`ml`): mirugam, pidippu, pittam
- **Gujarati** (`gu`): dhara, khenchan, mirgi
- **Punjabi** (`pa`): daure, jhatke, mirgi
- **Odia** (`or`): aakade, baat, mrigi

### Lethargy

- **English** (`en`): lethargic, lethargy, not waking, unconscious, unresponsive, weak and dull
- **Hindi / Hinglish** (`hi`): behoosh, hosh nahi, jaag nahi raha, sota rehta hai, susti
- **Urdu** (`ur`): behoosh, hosh nahi, sota rehta hai
- **Tamil** (`ta`): ezhumbamattu, mayakkam, sella unarchi, unarchi
- **Telugu** (`te`): chetana levu, ezharu ledu, mookam
- **Bengali** (`bn`): behosh, jagena, ochchhonna, songhopto
- **Marathi** (`mr`): behosh, behoshi, jagatch nahi, sust
- **Kannada** (`kn`): bedhuda, chelivillada, jadate, jagalla
- **Malayalam** (`ml`): bodharahithyam, ezhunilkkilla, manasilla, unarcha
- **Gujarati** (`gu`): behosh, benaan, jaagta nathi
- **Punjabi** (`pa`): behosh, hosh nahi, jag nahi raha, sust
- **Odia** (`or`): behosi, besudh, chetanahin, jagena

## 2. Multilingual number words (used when ASR emits words instead of digits)

- **1**: ek, okati, ondu, onnu
- **2**: do, randu, rendu, yeradu
- **3**: moodu, moondru, moonnu, mooru, teen
- **4**: char, naalku, naalu, naalugu
- **5**: aidu, anchu, anju, panch
- **6**: aaru, cheh
- **7**: eduru, elu, ezhu, saat
- **8**: aath, entu, ettu
- **9**: nau, ombattu, onbadhu, tommidi
- **10**: das, hattu, padi, pathu

## 3. Multilingual age / duration unit words

- **Months:** maadam, maadham, maas, maasam, maheen, mahina, mahine, masalu, masam, matha, matham, month, months, tingal
- **Days:** day, days, din, dina, divas, divasam, divasangal, naal, naalu, roju
- **Years:** bachhar, barsh, saal, samvatsaram, varsh, varsha, varush, varusham, year, years, yr, yrs

## 4. WHO IMCI classification logic (keyword -> triage)

Applied after keyword extraction, using age (months) and respiratory rate (RR):

| Condition (keywords / vitals) | Triage | Diagnosis | Urgency |
| --- | --- | --- | --- |
| Convulsions OR Lethargy (any) | **RED** | SEVERE PNEUMONIA / VERY SEVERE DISEASE | URGENT HOSPITAL REFERRAL |
| Chest indrawing AND age < 2 months | **RED** | SEVERE PNEUMONIA / VERY SEVERE DISEASE | URGENT HOSPITAL REFERRAL |
| Chest indrawing OR Fast breathing (RR>=60 if <2m, >=50 if 2-11m, >=40 if >=12m) | **YELLOW** | PNEUMONIA (Fast Breathing) | REFER TO PHC WITHIN 24 HOURS |
| Diarrhea symptom present | **YELLOW** (fever_days>7) / **GREEN** | DIARRHEA / GASTROENTERITIS | PHC CLINIC VISIT (persistent) / HOME CARE WITH ORS |
| Fever symptom present, fever_days > 7 | **YELLOW** | FEVER - POSSIBLE MALARIA / TYPHOID | REFER TO PHC FOR BLOOD TEST |
| Fever symptom present, fever_days <= 7 | **GREEN** | FEVER - MILD ACUTE FEBRILE ILLNESS | HOME CARE |
| No danger signs, no fever/diarrhea | **GREEN** | NO PNEUMONIA / MILD ILLNESS | HOME CARE |

## 5. Detected language codes

- `en` = English
- `hi` = Hindi / Hinglish
- `ur` = Urdu
- `ta` = Tamil
- `te` = Telugu
- `bn` = Bengali
- `mr` = Marathi
- `kn` = Kannada
- `ml` = Malayalam
- `gu` = Gujarati
- `pa` = Punjabi
- `or` = Odia
