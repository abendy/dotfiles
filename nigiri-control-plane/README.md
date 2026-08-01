# Nigiri Control Plane

**Status: planning.** No production code exists yet; nothing here changes
machine state. This directory is the architecture and product plan for a
native macOS menu-bar application on the MacBook Pro that observes the health,
services, connectivity, and events of `nigiri-san` (the headless Mac mini),
backed by a resident agent on the Mini.

The first release is read-only observation. Remote actions, Codex approval
handoff, and remediation are designed-for but explicitly not built.

## Layout

| Path | What it is |
| --- | --- |
| [docs/product-brief.md](docs/product-brief.md) | why this exists, who it serves, what v1 does |
| [docs/system-architecture.md](docs/system-architecture.md) | components, processes, module layout, self-observability |
| [docs/connectivity-and-recovery.md](docs/connectivity-and-recovery.md) | paths A–D, connection manager, recovery boundaries, power |
| [docs/failure-mode-matrix.md](docs/failure-mode-matrix.md) | scenario-by-scenario detection/degradation/recovery |
| [docs/security-threat-model.md](docs/security-threat-model.md) | threats, authentication, authorization tiers, privilege budget |
| [docs/protocol-and-data-model.md](docs/protocol-and-data-model.md) | versioned protocol, schemas, example messages, storage DDL |
| [docs/initial-feature-set.md](docs/initial-feature-set.md) | v1 collectors, menu-bar UI, service checks — each with its operational question |
| [docs/observability-and-alerting.md](docs/observability-and-alerting.md) | alert engine, lifecycle, self-monitoring |
| [docs/deployment-and-updates.md](docs/deployment-and-updates.md) | install, pairing, signing, upgrade, rollback, removal |
| [docs/testing-strategy.md](docs/testing-strategy.md) | test plan and the faultlab harness |
| [docs/progressive-rollout.md](docs/progressive-rollout.md) | phases 0–4 with exit criteria; later-phase provisions |
| [docs/open-questions.md](docs/open-questions.md) | unresolved decisions, several needing user input |
| [docs/decisions/](docs/decisions/) | ADRs 0001–0011 (own sequence, scoped to this subproject) |
| [spikes/README.md](spikes/README.md) | dated validation log; experimental evidence, never production code |

## Naming

- Working name: **Nigiri Control Plane** (no prior name in the repo).
- Mini agent binary: `nigirid`. Local admin CLI: `nigirictl`.
- MBP menu-bar app: **Nigiri Control** (`nigiri-control`).
- Bundle-ID prefix `com.abendy.nigiri-control-plane.*`, following
  `com.abendy.disk-prune` precedent.

## Relationship to the dotfiles repo

Planning lives here because this repo is where machine truth lives
(CLAUDE.md's doc contract, `mac-mini-setup.md`, the disk-prune precedent for
Swift subprojects). Whether implementation stays in-repo or extracts to a
dedicated repository at Phase 1 is an open question
([docs/open-questions.md](docs/open-questions.md) Q1).
