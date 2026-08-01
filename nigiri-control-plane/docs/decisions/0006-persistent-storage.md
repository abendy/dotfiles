# ADR 0006 — Persistent storage: SQLite (WAL) via GRDB on both machines

- **Status:** proposed
- **Date:** 2026-08-01

## Context

The Mini needs a durable journal (replay after disconnection, bounded
growth, corruption survival); the MBP needs an offline-capable mirror.
Sequence numbers, boot sessions, and idempotent replay are protocol-level
requirements that storage must anchor.

## Decision drivers

Crash safety on power loss (no-UPS reality today — L2); single-writer
simplicity; monotonic AUTOINCREMENT for `seq`; migrations; inspectability
(`sqlite3` CLI on any recovery shell); zero server processes.

## Considered alternatives

- **Append-only JSONL + index** — simple writes, but retention compaction,
  crash-consistent truncation, and query-for-replay all become hand-rolled;
  corruption detection is DIY. Rejected: reinvents the WAL badly.
- **Raw sqlite3 C API** — no dependency, but migrations/typed rows/pool
  boilerplate by hand; GRDB is mature, focused, and already the de-facto
  Swift standard. Dependency accepted (pinned).
- **Core Data** — object-graph machinery and schema opacity for what is
  fundamentally rows-and-queries; poor fit for a daemon.
- **LMDB/RocksDB-class** — wrong shape (no SQL for ad-hoc incident
  queries), heavier ops knowledge for one maintainer.

## Decision

SQLite in WAL mode through GRDB on both sides; schemas per protocol doc §8;
journal actor as sole writer; `quick_check` at open; corruption → move-
aside + fresh epoch + alert (observation never stops for storage);
retention caps (500 MB/30 d agent; 7 d client) enforced in the writer;
migration ladder tested both directions per the rollback policy
(forward-only-compatible migrations).

## Consequences

Replay/idempotency get database-grade guarantees (AUTOINCREMENT seq,
INSERT OR IGNORE mirror); incident forensics is a `sqlite3` session away;
WAL checkpointing needs monitoring (self-metric: last-write latency +
checkpoint stats); two DB files to back up… deliberately *not* backed up —
they're evidence, not treasure; the moved-aside corruption files are the
only archival gesture.

## Security implications

DB files uid-501-owned 0600; no secrets stored (keys live elsewhere);
tamper story per threat T13 (client mirror is the independent record;
hash-chaining parked).

## Validation required

kill -9/power-cut consistency loop in CI (storage tests); epoch-rotation
drill; cap-enforcement property tests; GRDB pin review.

## Revisit conditions

Multi-node or high-frequency metrics outgrow row-per-sample (columnar
sidecar or downsampling-first schema then); GRDB maintenance falters
(fallback: raw sqlite3 shim behind the same store protocol).
