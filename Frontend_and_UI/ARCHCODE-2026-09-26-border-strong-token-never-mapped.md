# `--border-strong` was defined but never mapped, so every pane divider inherited `currentColor`

**Date:** 2026-09-26
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
`src/styles.css` defined the custom property `--border-strong`, but the Tailwind v4 theme
bridge never mapped it to `--color-border-strong`. In Tailwind v4 the `@theme` block is what
turns a CSS variable into a utility: without the `--color-*` entry, `border-border-strong`
compiles to nothing at all. The class was silently absent from the stylesheet, so the eight
elements that used it fell back to inheriting `currentColor` for their border colour. The
dividers between panes therefore rendered in the foreground text colour rather than the
intended muted rule colour, and the resize handles had no boundary of their own.

## Symptoms
- Pane dividers and resize handles rendered as a hard foreground-coloured 1px line instead of
  the muted `--border-strong` rule.
- `border-border-strong` was absent from the built CSS entirely — no error, no warning.
- The defect was invisible in source review, because the class name and the variable name
  matched exactly and both were present in the file.

## Environment Details
- **Server/Host:** local dev (`npm run dev`, Vite) and `npx vite build`
- **Services Affected:** `src/styles.css` (`@theme` block)
- **Related Components:** `SplitHandle` (`split.tsx`), `ShortcutHelp`, spec/editor/telemetry
  pane shells, timeline lane rules
- **Time First Observed:** 2026-09-26, while implementing design review step 5

## Investigation Steps

### 1. Initial Diagnosis
Noticed `--border-strong` in use in `split.tsx` while adding the resize handles, and checked
whether the variable was actually reachable from Tailwind.

### 2. Root Cause Analysis
Grepped the `@theme` block for the token and compared it against every custom property the
components referenced.

```bash
# every --border-* / --color-border-* pair actually declared
grep -n 'border' src/styles.css | grep -E '^\s*[0-9]+:\s*--'

# the utility classes the components actually use
grep -rn 'border-border-strong\|bg-border-strong' src/

# confirm the utility is missing from the built stylesheet
grep -c 'border-border-strong' dist/assets/*.css
```

### 3. Key Findings
- `--border-strong: <value>` was declared, but `--color-border-strong` was not.
- Eight call sites used `border-border-strong` / `bg-border-strong` and all were affected.
- Tailwind v4 emitted no rule for the class, so there was no build-time error — the classes
  were inert, not wrong.

## Root Cause
Tailwind v4 does not derive utilities from arbitrary CSS variables. A token becomes a utility
only if it is declared in `@theme` under the `--color-*` namespace (or is registered via
`@theme inline`). A bare `--border-strong` custom property is just a variable: valid CSS,
reachable from hand-written rules, and invisible to the utility engine. The result is a class
that type-checks, reads correctly, appears in the JSX, and generates nothing — with the
element inheriting `currentColor` for that border. This is the same failure mode as a typo'd
utility, except it never warns.

## Prevention / Rule
**Guardrail:** In `scripts/verify-semantics.ts`, extract every `--<name>` custom property
referenced by a `border-*`/`bg-*`/`text-*` utility in `src/**` and assert a corresponding
`--color-<name>` entry exists inside the `@theme` block of `src/styles.css`; fail listing any
token that is referenced but unmapped.

Tailwind v4 makes this class of bug silent by design — an unmapped token generates no rule and
no warning, so nothing in the toolchain will ever catch it. The only place it can be caught is
a check that cross-references utility usage against the `@theme` namespace, which is what the
existing role-token guardrail does for colours; this extends the same idea to the border
scale.

## Solution

### Immediate Fix
Mapped the token in the `@theme` block.

```diff
  --border: oklch(var(--border));
+ --color-border-strong: oklch(var(--border-strong));
```

Verified the utility is now emitted: the built stylesheet contains
`.border-border-strong{border-color:var(--border-strong)}`.

### Long-term Fix
Add the unmapped-token guardrail described above so a `--<name>` variable can never be used
through a utility without a matching `--color-<name>` declaration.

## Prevention
- [ ] Add the referenced-but-unmapped theme token guardrail to `verify-semantics.ts`
- [x] Mapping added to `src/styles.css`
- [x] Built CSS confirmed to emit the utility
- [ ] Consider auditing the remaining tokens in `@theme` for the same namespace mismatch

## Related Issues
- `Frontend_and_UI/ARCHCODE-2026-09-26-stale-shadcn-resizable-wrapper-v4-api.md`

## References
- `src/styles.css` (`@theme`)
- Tailwind CSS v4 theme variable namespace (`--color-*`)

---

**Resolved By:** Claude (Anthropic), on behalf of the user
**Time to Resolution:** ~20 minutes
