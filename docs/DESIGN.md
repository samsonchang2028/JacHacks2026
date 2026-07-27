# Quorum — Design System

One font. Two weights. Nine type sizes. Everything else is a token.

If a value you need is not in this file, do not invent one — either reuse the
nearest token or change the token here and let it propagate. Ad-hoc values are
what makes an interface look machine-assembled: apparent structure with nothing
behind it.

---

## 1. Typeface

**Georgia**, with `"Times New Roman", serif` as fallback. Declared once, at
`:root` in `assets/quorum.css`. Nothing else declares a family.

```css
font-family: Georgia, "Times New Roman", serif;
```

**Georgia ships exactly two weights: 400 and 700.** There is no 500, 600, 800 or
900. Asking for them either snaps to 700 or triggers synthetic bold, which is why
`font-synthesis: none` is set — better to see the real weight than a smeared
imitation.

| Token | Value | Use |
|---|---|---|
| `--w-normal` | 400 | all body copy, headings, numerals |
| `--w-bold` | 700 | labels, emphasis, status, the one word that matters |

Headings are **not bold**. At display sizes Georgia's regular weight already has
presence; bolding it makes the page shout. Weight is for small text that must be
found quickly — labels, tags, table headers.

The single exception is the monospace stack on graph-traversal edge labels
(`.trace-edge`), because those are literal identifiers from the code:

```css
font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
```

## 2. Type scale

Nine steps. Sizes below 11px are not permitted — they were the main source of
sprawl (9px, 9.5px, 10px, 10.5px all existed and none were readable).

| Token | Size | Line height | Use |
|---|---|---|---|
| `--t-display` | `clamp(46px, 7vw, 88px)` | 1.02 | the one `h1` per page |
| `--t-h2` | `clamp(30px, 3.4vw, 44px)` | 1.1 | section headings |
| `--t-h3` | 26px | 1.15 | panel titles |
| `--t-h4` | 21px | 1.25 | card titles |
| `--t-lead` | 18px | 1.6 | section leads, intro copy |
| `--t-body` | 16px | 1.6 | default body |
| `--t-small` | 14px | 1.55 | secondary copy, table cells |
| `--t-fine` | 12px | 1.5 | captions, notes, chips |
| `--t-micro` | 11px | 1.4 | uppercase labels only, always with `--w-bold` |

**No half-pixel sizes.** `13.5px` and `14.5px` are not distinguishable from 14px
in a serif at reading size; they only make the stylesheet harder to reason about.

## 3. Color

Tokens live at `:root` in `assets/quorum.css`. Use the token, never the hex.

| Token | Hex | Use |
|---|---|---|
| `--ink` | `#173f45` | primary text, dark surfaces |
| `--ink-soft` | `#4a5c5c` | body copy |
| `--ink-faint` | `#8a7b6d` | captions, meta, disabled |
| `--cream` | `#fff8ef` | page background |
| `--card` | `#fffcf7` | raised surface |
| `--line` | `#ebdfd2` | borders, dividers |
| `--coral` | `#de5b49` | primary action, alarm, divergence |
| `--coral-deep` | `#b8402c` | coral text on light |
| `--peach` | `#f6b08e` | warm accent, gradient partner |
| `--peach-deep` | `#e7c9b5` | section dividers |
| `--teal` | `#6fb9bd` | cool accent |
| `--teal-pale` | `#eaf5f1` | cool surface tint |

**Chart colors are separate and validated.** `#de5b49` and `#0b8f80` are the only
data-mark colors. They were run through the dataviz palette validator and pass
lightness, chroma, CVD separation, normal-vision and contrast checks against the
warm card surface. An earlier teal failed (chroma 0.063 — read as gray; CVD ΔE
7.7). **If you change the card background, re-run the validator.** Do not pick
chart colors by eye.

### The warm washes

Four fixed radial gradients on `body` — peach top-left and bottom-left, teal
right. `background-attachment: fixed` so they drift under content rather than
scrolling away. Cards are translucent (`rgba(255,252,247,0.86)`) so the washes
read through. This is the Quorum signature; flat cream reads clinical.

## 4. Spacing

4px base. Eight steps. Nothing between them.

| Token | Value |
|---|---|
| `--s-1` | 4px |
| `--s-2` | 8px |
| `--s-3` | 12px |
| `--s-4` | 16px |
| `--s-5` | 24px |
| `--s-6` | 32px |
| `--s-7` | 48px |
| `--s-8` | 64px |

Grid gaps are `--s-4` (tight) or `--s-5` (default). Section padding is `--s-6`
top, `--s-8` bottom.

## 5. Radii

Five steps, down from eighteen.

| Token | Value | Use |
|---|---|---|
| `--r-sm` | 8px | swatches, small marks |
| `--r-md` | 12px | tiles, inner blocks |
| `--r-lg` | 18px | cards |
| `--r-xl` | 28px | hero, map frames |
| `--r-pill` | 999px | buttons, chips, tags, status |

## 6. Elevation

One shadow. Warm brown, never neutral gray — gray shadows on a cream page look
dirty.

```css
--shadow-warm: 0 10px 26px rgba(83, 55, 37, 0.09);
```

Coral actions carry their own colored lift: `0 10px 22px rgba(222,91,73,0.28)`.

## 7. Components

**Buttons** — `.btn` + `.btn-primary` (coral→peach gradient, cream text) or
`.btn-ghost` (transparent, `--line` border). Min height 52px, pill radius.

**Cards** — `.fail`, `.step`, `.chart`, `.feed-item` all share: translucent card
background, 1px `--line` border, `--r-lg`, `--shadow-warm`, `--s-5` padding.

**Chips and tags** — pill radius, `--t-micro`, `--w-bold`, uppercase, tinted
background with matching text color. Never color alone for meaning: a status chip
carries its word.

**Citation chips** — `.chip` cited (teal) and `.chip.gap` uncited (amber). The
gap state must look deliberate, not broken. It is a feature: a fact with no
source renders a gap rather than a guess.

## 8. Rules

1. One `h1` per page.
2. Headings are weight 400. Bold is for small text.
3. No font size below 11px. No half-pixel sizes.
4. Uppercase only at `--t-micro`, always with letter-spacing `0.08em`.
5. Never use a raw hex where a token exists.
6. Never eyeball a chart color — run `validate_palette.js`.
7. Any wide content (tables, charts, code) scrolls inside its own container; the
   page body never scrolls horizontally.

## 9. Files

| File | Owns |
|---|---|
| `assets/quorum.css` | tokens, reset, shell, nav — loaded first |
| `assets/landing.css` | landing sections, charts |
| `assets/actions.css` | map, issue panel, workup, traversal |

Tokens are defined once in `quorum.css`. The other two consume them and define
no tokens of their own.
