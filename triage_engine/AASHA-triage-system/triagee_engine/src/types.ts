/**
 * Triage Engine — Type Definitions
 *
 * WHO IMCI / India's IMNCI deterministic triage types.
 * These types mirror the shared JSON schema agreed upon with
 * the full team (Person A → D) and serve as the contract
 * between the rules engine and the rest of the application.
 */

// ─── Core Enums ──────────────────────────────────────────────

/** Triage urgency flag. RED > YELLOW > GREEN. */
export type Flag = "red" | "yellow" | "green";

/** Skin-pinch recoil speed — IMNCI dehydration assessment. */
export type SkinPinch = "immediate" | "slow" | "very_slow";

/** Ability to drink — IMNCI dehydration assessment. */
export type Drinking = "normal" | "eager_thirsty" | "poor_or_unable";

/** Sync status for offline-first architecture. */
export type SyncStatus = "pending" | "synced" | "failed";

// ─── Input Interfaces ────────────────────────────────────────

export interface Patient {
  age_months: number;
}

export interface Vitals {
  resp_rate_bpm?: number;
  temp_c?: number;
  pulse_bpm?: number;
}

export interface Symptoms {
  // Pneumonia
  cough_or_difficulty_breathing?: boolean;
  chest_indrawing?: boolean;
  stridor_calm_child?: boolean;

  // Diarrhoea
  diarrhoea?: boolean;
  diarrhoea_days?: number;
  blood_in_stool?: boolean;
  restless_irritable?: boolean;
  sunken_eyes?: boolean;
  skin_pinch?: SkinPinch;
  drinking?: Drinking;

  // Fever
  fever_days?: number;
  stiff_neck?: boolean;

  // General danger signs
  not_able_to_drink_or_breastfeed?: boolean;
  vomits_everything?: boolean;
  convulsions?: boolean;
  lethargic_or_unconscious?: boolean;
}

export interface TriageInput {
  patient: Patient;
  vitals: Vitals;
  symptoms: Symptoms;
}

// ─── Output Interfaces ───────────────────────────────────────

export interface ConditionResult {
  name: string;
  classification: string;
  flag: Flag;
  reasonTrace: string[];
}

export interface TriageResult {
  flag: Flag;
  conditions: ConditionResult[];
  rule_trace: string[];
  override_reason: string | null;
}

export interface TriageOutput {
  visit_history_id: string;
  patient: Patient;
  vitals: Vitals;
  symptoms: Symptoms;
  triage_result: TriageResult & { referral_note: string };
  sync: {
    sync_status: SyncStatus;
    sms_outbox: boolean;
  };
}
