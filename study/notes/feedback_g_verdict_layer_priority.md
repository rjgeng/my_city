# Feedback: G verdict layer priority

Summary:

- Observed during Day-29 (2026-05-20) that generator-layer assertions can be wrong while field-layer data still reads as true. In particular, a G1 field assertion held until 14:54Z, but the generator's model of the cause (generator-layer) was incorrect from 12:53Z onward.

Recommendation:

- Memory entry: "generator-layer truth dominates field-layer truth for G verdicts".
- When recording a G falsification, capture both the field-observed claim and the generator-model claim; prioritize the generator-layer claim when determining corrective action and follow-ups.

Suggested contents for the memory file:

- Title: `feedback_g_verdict_layer_priority`
- Date: 2026-05-20
- Short rationale: why generator-layer insights should drive follow-ups
- Example: #2316 Day-29 case summary (timestamps + short narrative)
- Actionable guidance: how to record G events and which layer to treat as authoritative for remediation and beads

Acceptance:

- This file exists in `chatting_logs/gc-my-city/notes/` and is referenced from the Day-29 EOD close-out.
