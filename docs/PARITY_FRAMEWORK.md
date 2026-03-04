# Parity framework (GD ↔ Rust) for incremental migration

This repository now has a reusable parity pipeline so domains can be added one by one
without changing CI wiring.

## What is already in place

- CI workflow: `.github/workflows/parity_checks.yml`
- Shared parity runner: `tools/parity/run_all.py`
- Check registry/manifest: `tools/parity/manifest.json`

Current checks in the manifest:
1. `suspension/tools/check_suspension_core_parity.py`
2. `suspension/tools/check_suspension_type_axle_response_parity.py`
3. `rust/tire_core` golden tests via `cargo test`

## How to add next modules (wheels/engine/tires extras)

1. Add a deterministic checker script in the module (`<module>/tools/check_*_parity.py`).
2. Add/expand golden vectors under `<module>/shared/*_golden_v*.json`.
3. Register the command in `tools/parity/manifest.json`.
4. Verify with:

```bash
python3 tools/parity/run_all.py
```

No CI workflow edits should be needed for additional checks.

## Why this helps now

Even before full Godot integration tests are practical, this catches formula drift early and
keeps Godot and Rust numerically aligned during migration.
