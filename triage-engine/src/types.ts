export type Flag = "green" | "yellow" | "red";

export interface ConditionResult {
  name: string;
  classification: string;
  flag: Flag;
  reasonTrace: string[];
}

export interface PatientData {
  age_months: number;
}

export interface VitalsData {
  resp_rate_bpm?: number;
  temp_c?: number;
  pulse_bpm?: number;
}

export interface Symptoms {
  // Respiratory
  cough_or_difficulty_breathing?: boolean;
  chest_indrawing?: boolean;
  stridor_calm_child?: boolean;

  // Diarrhoea
  diarrhoea?: boolean;
  diarrhoea_days?: number;
  blood_in_stool?: boolean;
  restless_irritable?: boolean;
  sunken_eyes?: boolean;
  skin_pinch?: "immediate" | "slow" | "very_slow";
  drinking?: "normal" | "eager_thirsty" | "poor_or_unable";

  // Fever
  fever_days?: number;
  stiff_neck?: boolean;

  // General danger signs
  not_able_to_drink_or_breastfeed?: boolean;
  vomits_everything?: boolean;
  convulsions?: boolean;
  lethargic_or_unconscious?: boolean;

  // Ear problem
  ear_pain_or_discharge?: boolean;
  mastoid_swelling?: boolean;
}

export interface TriageInput {
  patient: PatientData;
  vitals: VitalsData;
  symptoms: Symptoms;
}

export interface TriageResult {
  flag: Flag;
  conditions: ConditionResult[];
  rule_trace: string[];
  override_reason: string | null;
}
