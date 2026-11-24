# Job location & pricing-mode decisions

## GPS-only location is an open question, not a settled decision
PR #14 added the ability to save a job location from GPS alone, writing a
synthesized `"Pinned location (<suburb>)"` string into the `address` field
when no street address was typed. This was flagged during code review as
conflicting with "design for the worker's worst day" (worker gets no real
door/landmark detail) and left as a review comment rather than fixed,
because it's unclear whether GPS-only addresses are an intentional product
allowance (useful given the offline-first / low-end-device / small-data-
bundle constraints that favor non-form input) or an oversight. Whoever
picks this up next should decide explicitly: either keep requiring a real
street address, or add a distinct "GPS only, no address" representation
instead of a fabricated address string. See bug-log entry
`Frontend_and_UI/MARITCHO-2026-11-24-location-sheet-fabricates-address-for-gps-only-saves.md`.

## Job repository save() trades correctness for simplicity
`SqlAlchemyJobRepository.save()` persists a full-entity overwrite with no
optimistic-locking/version check — meaning whichever use case calls
`save()` last wins, even with a stale in-memory copy of fields it never
touched. This is fine as long as job mutations stay effectively
single-writer per job in practice, but breaks down the moment two
in-flight requests load/save the same job concurrently (e.g. a buyer's
PATCH racing a worker's booking flow). Left open as an architectural
decision (full-entity diff/merge vs. a version column) rather than patched
ad hoc — see bug-log entry
`Backend_and_API/MARITCHO-2026-11-24-job-save-overwrites-without-optimistic-lock.md`.
