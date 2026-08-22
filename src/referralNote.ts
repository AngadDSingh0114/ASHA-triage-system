/**
 * Referral Note Generator — Templated, Not Generative
 *
 * Produces a plain-language referral string for ASHA/PHC workers.
 * Uses strict string concatenation — no LLM, no free-text generation.
 *
 * Output format:
 *   "Suspected {condition} — {findings} in {age}, {danger note}. Refer to PHC {urgency}."
 */

import {
  Flag,
  TriageInput,
  TriageResult,
} from "./types";

import { FLAG_RANK } from "./engine";

/**
 * Generate a deterministic, human-readable referral note.
 *
 * @param i      - The original triage input (patient + vitals + symptoms)
 * @param result - The triage classification result from classify()
 * @returns        A plain-language referral string
 */
export function generateReferralNote(
  i: TriageInput,
  result: TriageResult
): string {
  // ── Age label ──────────────────────────────────────────────
  const ageLabel =
    i.patient.age_months < 12
      ? `${i.patient.age_months}-month-old`
      : `${Math.floor(i.patient.age_months / 12)}-year-old`;

  // ── Worst condition (by flag rank) ─────────────────────────
  const sorted = [...result.conditions].sort(
    (a, b) => FLAG_RANK[b.flag] - FLAG_RANK[a.flag]
  );
  const worst = sorted[0];
  const conditionLabel = worst
    ? worst.classification.replace(/_/g, " ").toLowerCase()
    : "danger sign(s)";

  // ── Clinical findings list ─────────────────────────────────
  const findings: string[] = [];

  if (i.vitals.resp_rate_bpm) {
    findings.push(`fast breathing (${i.vitals.resp_rate_bpm}/min)`);
  }
  if (i.symptoms.chest_indrawing) {
    findings.push("chest indrawing");
  }
  if (i.symptoms.stridor_calm_child) {
    findings.push("stridor in calm child");
  }
  if (i.symptoms.diarrhoea) {
    findings.push(
      `diarrhoea ${i.symptoms.diarrhoea_days ?? "?"} days`
    );
  }
  if (i.symptoms.blood_in_stool) {
    findings.push("blood in stool");
  }
  if (i.vitals.temp_c) {
    findings.push(`fever ${i.vitals.temp_c}°C`);
  }
  if (i.symptoms.stiff_neck) {
    findings.push("stiff neck");
  }
  if (i.symptoms.lethargic_or_unconscious) {
    findings.push("lethargic/unconscious");
  }
  if (i.symptoms.convulsions) {
    findings.push("convulsions");
  }
  if (i.symptoms.vomits_everything) {
    findings.push("vomits everything");
  }
  if (i.symptoms.not_able_to_drink_or_breastfeed) {
    findings.push("not able to drink/breastfeed");
  }

  const findingsStr =
    findings.length > 0
      ? findings.join(", ")
      : "clinical assessment pending";

  // ── Danger sign note ───────────────────────────────────────
  const dangerNote = result.rule_trace[0].includes("none present")
    ? "no danger signs"
    : "danger sign(s) present";

  // ── Urgency level ──────────────────────────────────────────
  const urgency = result.flag === "red" ? "URGENTLY" : "within 24h";

  return `Suspected ${conditionLabel} — ${findingsStr} in ${ageLabel}, ${dangerNote}. Refer to PHC ${urgency}.`;
}
