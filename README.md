# Grow a Planet

Roblox progression simulator. Phase 0 foundation only; no gameplay is implemented.
Read AGENTS.md, GAME_SPEC.md and PHASE_PROMPTS.md before working. Each phase requires owner approval.

## Development

From this repository, run `./scripts/bootstrap.ps1`, then `./scripts/check.ps1`.
Start `./scripts/serve.ps1 -Development` and connect Studio's Rojo plugin to localhost:34872.
Play in Studio to run the development-only pipeline assertions. Use `./scripts/serve.ps1` for the release mapping.

- `src/server`, `src/client`, `src/shared/config`: source of truth for game code.
- `vendor/ProfileStore`: pinned official server-only persistence dependency.
- `tests`: Studio-only pipeline check; excluded from release builds.
- `assets`: original editable Blender source, FBX export and reproducible scripts.
- `docs/SETUP.md`: versions, installation and verification instructions.
- `docs/UI_NOTES.md`, `docs/ASSET_MANIFEST.md`: UI decisions and provenance.
- `docs/OWNER_SETUP.md`, `docs/reports/phase-0.md`: owner actions and phase evidence.

The approved place is 94365962623582, universe 10770529946. Do not connect to another experience.
Nothing in this repository authorizes public publication or purchases.
