# ASHA Triage - Keyword -> Vitals / Extracted Slots

> Shows what each matched keyword class populates in the structured output
> (the "vitals" / extracted fields), and which numeric/unit keywords produce
> `age_months` and `fever_days`. Derived from `asha_extractor.py`.

## Extracted vitals / slots produced by the model

| Field | Meaning |
| --- | --- |
| `age_months` | Child age in months (from month/year words or digits) |
| `respiratory_rate` | Breaths per minute (from RR keywords or digits) |
| `fever_days` | Duration of fever in days (from day words or digits) |
| `symptoms[]` | List of detected symptom class keys |
| `has_chest_indrawing` | True if chest-indrawing class detected |
| `has_convulsions` | True if convulsions class detected |
| `has_vomiting` | True if vomiting OR vomiting-everything detected |
| `has_vomiting_everything` | True if vomiting-everything detected |
| `has_lethargy` | True if lethargy class detected |
| `language` | Detected transcript language code |
| `extraction_confidence` | 0.0-1.0 slot-fill confidence score |

## Symptom keyword class -> extracted slot(s)

- **Fever**  ->  `symptoms[] = "fever"  (also enables fever-duration extraction)`
  - languages covered: bn, en, gu, hi, kn, ml, mr, or, pa, ta, te, ur
- **Chest Indrawing**  ->  `symptoms[] = "chest_indrawing"  ->  has_chest_indrawing = True`
  - languages covered: bn, en, gu, hi, kn, ml, mr, or, pa, ta, te, ur
- **Diarrhea**  ->  `symptoms[] = "diarrhea"`
  - languages covered: bn, en, gu, hi, kn, ml, mr, or, pa, ta, te, ur
- **Vomiting**  ->  `symptoms[] = "vomiting"  ->  has_vomiting = True`
  - languages covered: bn, en, gu, hi, kn, ml, mr, or, pa, ta, te, ur
- **Vomiting Everything**  ->  `symptoms[] = "vomiting_everything"  ->  has_vomiting = True AND has_vomiting_everything = True`
  - languages covered: bn, en, gu, hi, kn, ml, mr, or, pa, ta, te, ur
- **Convulsions**  ->  `symptoms[] = "convulsions"  ->  has_convulsions = True  (general danger sign)`
  - languages covered: bn, en, gu, hi, kn, ml, mr, or, pa, ta, te, ur
- **Lethargy**  ->  `symptoms[] = "lethargy"  ->  has_lethargy = True  (general danger sign)`
  - languages covered: bn, en, gu, hi, kn, ml, mr, or, pa, ta, te, ur

> Note: a single symptom keyword (any language) adds its class key to `symptoms[]`.
> `vomiting_everything` is the most severe vomiting signal and is also treated as a
> general danger sign at the rules-engine stage.

## Numeric vitals: how age and fever-duration are read

### Age -> `age_months`
- **Months:** digits or number-words followed by any month unit: maadam, maadham, maas, maasam, maheen, mahina, mahine, masalu, masam, matha, matham, month, months, tingal
  - e.g. `8 mahine`, `2 maasam`, `ondu maasam` -> age_months = 8 / 2 / 1
- **Years:** digits or number-words followed by any year unit: bachhar, barsh, saal, samvatsaram, varsh, varsha, varush, varusham, year, years, yr, yrs
  - e.g. `2 saal`, `oru varusham` -> age_months = 24 (years x 12)

### Fever duration -> `fever_days`
- Triggered only when a **fever** class keyword is present, using day units: day, days, din, dina, divas, divasam, divasangal, naal, naalu, roju
  - e.g. `3 din se bukhar`, `4 naal jvaram`, `4 days fever` -> fever_days = 3 / 4 / 4

### Respiratory rate -> `respiratory_rate`
- Pattern: a number followed by `saans rate` / `saans/min` / `breaths per minute` / `/min` / `saans` / `breaths`,
  or `rr` / `rate` / `saans` / `shwas` followed by a number.
  - e.g. `55 saans rate`, `RR 50`, `shwas 45` -> respiratory_rate = 55 / 50 / 45

## Language detection -> `language`

The dominant language is chosen by counting symptom-term hits per language code:
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

> If no symptom term matches, `language` defaults to `en` (English).
