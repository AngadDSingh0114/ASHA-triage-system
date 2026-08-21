/**
 * Triage Engine — Public API
 *
 * WHO IMCI / India's IMNCI deterministic triage decision engine.
 * Exports the classify() function and the generateReferralNote() function
 * along with all types needed by consuming modules.
 */

// Types
export {
  Flag,
  SkinPinch,
  Drinking,
  SyncStatus,
  Patient,
  Vitals,
  Symptoms,
  TriageInput,
  ConditionResult,
  TriageResult,
  TriageOutput,
} from "./types";

// Engine
export {
  classify,
  classifyPneumonia,
  classifyDiarrhoea,
  classifyFever,
  checkGeneralDangerSigns,
  FLAG_RANK,
} from "./engine";

// Referral Note
export { generateReferralNote } from "./referralNote";
