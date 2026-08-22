import { classify, generateReferralNote, TriageInput } from "./index";

const samplePatient: TriageInput = {
  patient: { age_months: 8 },
  vitals: {
    resp_rate_bpm: 58,
    temp_c: 38.6
  },
  symptoms: {
    cough_or_difficulty_breathing: true,
    chest_indrawing: false,
    stridor_calm_child: false,

    diarrhoea: false,
    diarrhoea_days: 0,
    blood_in_stool: false,
    restless_irritable: false,
    sunken_eyes: false,
    skin_pinch: "immediate",
    drinking: "normal",

    fever_days: 1,
    stiff_neck: false,

    not_able_to_drink_or_breastfeed: false,
    vomits_everything: false,
    convulsions: false,
    lethargic_or_unconscious: false,
    
    mastoid_swelling: false,
    ear_pain_or_discharge: false
  }
};

console.log("🚑 RUNNING TRIAGE ENGINE DEMO 🚑\n");
console.log("Input Patient Data:");
console.log(`- Age: ${samplePatient.patient.age_months} months`);
console.log(`- Vitals: RR ${samplePatient.vitals.resp_rate_bpm}, Temp ${samplePatient.vitals.temp_c}°C`);
console.log(`- Symptoms: Cough, Fever`);

const result = classify(samplePatient);
const note = generateReferralNote(samplePatient, result);

console.log("\n=================================");
console.log(`🚦 OVERALL FLAG: ${result.flag.toUpperCase()}`);
console.log("=================================\n");

console.log("🏥 CONDITIONS DETECTED:");
if (result.conditions.length === 0) {
  console.log("  (None)");
}
result.conditions.forEach(c => {
  console.log(`  - ${c.name.toUpperCase()}: ${c.classification} [${c.flag.toUpperCase()}]`);
});

console.log("\n🔍 RULE TRACE (Why did it make this decision?):");
result.rule_trace.forEach(trace => {
  console.log(`  > ${trace}`);
});

console.log("\n📝 GENERATED REFERRAL NOTE:");
console.log(`  "${note}"\n`);
