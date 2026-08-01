# ADR 0011 — Privilege model: unprivileged uid-501 everything; privileges are future, explicit, and per-capability

- **Status:** proposed
- **Date:** 2026-08-01

## Context

Monitoring tools rot into root-owned grab-bags one convenient permission at
a time. The brief's principle 10 forbids that trajectory; the live-state
survey (L2/L6/L7/L9) shows v1's entire collector set is reachable from
uid 501 with **zero** TCC grants — an unusually clean starting position
worth defending structurally.

## Decision drivers

Blast-radius containment (agent compromise must add nothing to uid-501
compromise); headless TCC reality (privacy prompts don't get clicked on a
machine without a screen — any TCC-needing design is operationally broken
here, not just distasteful); auditability (the privilege budget is a table
in the threat model, diffable in review); per-collector justification
discipline.

## Considered alternatives

- **Root daemon "for headroom"** — the convenience trap named by the
  brief; rejected. Nothing in v1 needs it (verified per collector), and
  headroom without a consumer is pure liability.
- **Privileged helper (SMJobBless-style) now, unused** — dormant privileged
  code is attack surface with zero offsetting value; helpers arrive *with*
  the first privileged capability, carrying their own ADR, audit events,
  and narrow verb list.
- **Full Disk Access for better diagnostics** — the only tempting v1 grant
  (user-domain DiagnosticReports); rejected — system-domain reports proved
  readable without it (L9), and the marginal reports don't justify an
  everything-readable token on a devbox holding real code and credentials.
- **Dedicated service user** — rejected for v1 (ADR 0003); becomes the
  *first* move when any privileged capability arrives.

## Decision

Every component runs as `nigiri` (agent, CLI) or the console user (client
app). Install-time sudo (plist + /usr/local placement) is the only
elevation in the system's life. TCC surface: exactly one prompt
(client notifications). Collectors carry a privilege column in
initial-feature-set.md; a collector requesting more than "none" requires:
the operational question it answers, the rejected-alternative analysis, and
a threat-model delta — in an ADR amendment, not a code review comment.
Future action tiers (T3/T4) mandate: dedicated helper or service user,
per-verb allowlists, local client confirmation, cooldowns, audit events —
specified before any privileged code exists.

## Consequences

Some observability is deliberately forgone (per-process attribution
depth, user-domain crash reports, Wi-Fi RSSI); the "reject collectors whose
value doesn't justify privilege" rule has already fired three times
(threat model §rejected) and is expected to keep firing; security review
of v1 reduces to verifying invariants 1–7 (threat model) rather than
auditing grant usage.

## Security implications

This *is* the security implication section of the whole design: the agent
adds no escalation path, no TCC token worth stealing, no root code to
exploit. The residual truth stays stated plainly: uid-501 compromise owns
the box's user domain today, with or without this project.

## Validation required

Phase 1 privilege audit (invariant checklist + `codesign -d
--entitlements` diff + TCC.db inspection showing no agent entries);
CI grep-invariants (no string-exec, no entitlement additions).

## Revisit conditions

First T3 action ships (helper + service-user ADR becomes due); Apple
gates a v1-essential interface behind TCC in a future macOS (fight it with
an alternative interface first, accept the grant only with the full
justification ritual).
