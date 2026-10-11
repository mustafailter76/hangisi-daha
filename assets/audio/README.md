# Hangisi Daha? game sound effects

The selected sound effects were downloaded from Mixkit on 2026-08-20, except
for the locally generated lightweight `wrong.wav`. Exact individual asset page
URLs, creator names, and original titles were not retained for the original
eight downloads, so this record intentionally does not infer or invent them.

| File | Source | Downloaded | Individual asset URL |
| --- | --- | --- | --- |
| `correct.wav` | Mixkit | 2026-08-20 | Not retained |
| `wrong.wav` | Locally generated two-tone PCM feedback | 2026-08-24 | Not applicable |
| `extension.wav` | Mixkit | 2026-08-20 | Not retained |
| `hint.wav` | Mixkit | 2026-08-20 | Not retained |
| `shield_activate.wav` | Mixkit | 2026-08-20 | Not retained |
| `shield_impact.wav` | Mixkit | 2026-08-20 | Not retained |
| `new_record.wav` | Mixkit | 2026-08-20 | Not retained |
| `critical_time.wav` | Mixkit | 2026-08-20 | Not retained |
| `game_over.wav` | Mixkit — original Task 23B `wrong.wav`, reused as terminal feedback | 2026-08-20 | Not retained |

- Format: PCM WAV, stereo, 44.1 kHz, 16-bit
- Runtime use: bundled Flutter assets; not uploaded to Supabase Storage
- `wrong.wav`: generated in-repo without an external sample; 240 ms descending
  two-tone feedback with short attack/release envelopes.
- `game_over.wav`: restored byte-for-byte from the user-selected Task 23B
  `wrong.wav` in commit `7e0be702`; the Task 34 replacement is no longer used.
- Mixkit Sound Effects Free License: https://mixkit.co/license/#sfxFree
