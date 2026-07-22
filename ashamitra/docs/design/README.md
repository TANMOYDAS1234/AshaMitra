# Panel Redesign — how to use these docs with Stitch AI

Goal: redesign the **CMHO**, **BMHO** and **ANM** panels so they feel like one product with the
ASHA worker app — clean, premium, purple-on-sage-green, with real graphs, live analytics and
drill-downs — without inventing data the backend can't provide.

## The files

**Start here — CMHO**

| File | What it is |
|---|---|
| **CMHO.md** | What a CMHO **does** — every workflow and task, what triggers it, which screen, what she does next. No design content. |
| **CMHO_UI_PROMPTS.md** | The CMHO's own colour identity (deep petrol teal, distinct from the ASHA purple) + 8 Stitch prompts, one per screen. |
| **CMHO_GAP_ANALYSIS.md** | Coverage against the official 14-area role: what is built, what is pending, what should deliberately never be built here. |

**Shared + the other panels**

| File | What it is |
|---|---|
| **PANEL_DESIGN_SYSTEM.md** | The shared tokens — type, radius, shadow, spacing, the 7 non-negotiable rules, and the traps to reject. Applies to every panel. |
| **PANEL_BMHO.md** | Block officer — deltas from CMHO + 3 prompts. |
| **PANEL_ANM.md** | Sub-centre nurse — deltas + 3 prompts. |
| **PANEL_CMHO.md** | *Superseded* by `CMHO.md` + `CMHO_UI_PROMPTS.md`. Kept for its endpoint field listings, which the newer files reference rather than repeat. |

## Workflow for each screen

1. Open the panel file for the role you're designing.
2. Copy the **§6 preamble** from `PANEL_DESIGN_SYSTEM.md`.
3. Paste it into Stitch, then paste the screen prompt (A / B / C) below it.
4. When Stitch returns a design, check it against **§7** — it *will* try to add a map, "0%"
   tiles, green all-clear banners, or a blue-grey theme. Reject those.
5. Bring the visual back; the data wiring already exists (these panels are live today) — only the
   presentation changes.

## The one thing to hold onto

All three panels already work against real, deployed endpoints. These docs describe **exactly**
what those endpoints return. If a Stitch design shows a number, a chart, or a screen that isn't
backed by a field listed in the panel file, it cannot be built — it can only be faked. A faked
metric on a maternal-health dashboard is not a cosmetic problem; it is a clinical one. Design to
the data you have.
