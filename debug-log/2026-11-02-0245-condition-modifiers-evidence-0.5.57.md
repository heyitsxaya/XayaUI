# Condition modifiers: new evidence, explanation display fix (build 0.5.57, fork: main)
Logged 2026-11-02 02:45 UTC. Issue #260. Session: https://claude.ai/code/session_014bN6tVJMhXhJr5SQhrk92Q

Evidence (Xaya screenshots): Condition 1 evaluates FALSE with the buff off and TRUE with the buff on (trigger light agrees), Desaturate: on, Modify box ticked. So the condition path works; modifiers still reported not applying.
Fixed: Outcomes.lua explanation line showed "so far UNKNOWN" for a FALSE check (display only; evaluation was correct, Final was FALSE).
Not found: why merged mods do not show on screen. Re-read Engine.Step, Cues.EvaluateCue, Visual.UpdateVisualText: no defect. Hypotheses (INF, unverified): overlay layer (tex2) not desaturated by the mod; the display's own effect re-sets desaturation; the displayed texture is not the cue's frame.
Next: Xaya runs /xui mods while the condition shows TRUE and pastes the output (prints stored mods, merged mods, and frame desaturation state).
