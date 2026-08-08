# Session credential risk recorded for follow-up

Status: recorded only; intentionally not remediated in the 2026-08-08 audit
branch pending owner review.

## Risk

The current TXD value is reversible and contains the account identifier and
stored password rather than an opaque, expiring server-side session id. It is
placed in URLs and browser state, and request/backtrace logs can therefore
capture reusable credentials. A leaked URL, browser history entry, referrer,
proxy log, screenshot, or raw production traceback may expose the account.

The repository also currently contains runtime account, wallet, pet, storage,
timed-event, and unique-user data that should be classified before it is
removed from version control. Removing a file from the current tree does not
remove it from Git history.

## Deferred remediation

1. Replace TXD with a cryptographically random, opaque session id stored only
   as a hash on the server, with expiry, rotation, logout revocation, and
   per-character/account scope.
2. Send the session in a secure cookie or authorization header, not a query
   string; keep a short rolling compatibility window for existing clients.
3. Redact `txd`, password, authorization, wallet, payment, email, phone, and
   identity fields before any log is written or copied.
4. Inventory and classify tracked runtime files, add ignore rules, stop
   tracking them without deleting live data, and rotate any exposed secrets.
5. Plan a separate, reviewed history-rewrite/secret-rotation operation if the
   owner accepts its repository-wide impact.

No TXD encoding, decoding, compatibility, or authentication behavior is
changed by this record.
