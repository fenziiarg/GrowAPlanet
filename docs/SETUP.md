# Setup — Phase 3

Verified on Windows on 2026-10-12 from the repository root.
Git author is configured locally; use your own author name and email.
The existing repository and owner-confirmed isolated experience are reused. Inspect the origin with `git remote -v`.

## Versions

| Tool | Verified version | Pin |
|---|---|---|
| Git | 2.56.0.windows.2 | Host installation |
| Rokit | 1.2.0 | Host bootstrap |
| Rojo | 7.7.1 | rokit.toml; Studio plugin 7.7.1 |
| Wally | 0.3.2 | rokit.toml |
| StyLua | 2.6.0 | rokit.toml |
| Selene | 0.32.0 | rokit.toml |
| luau-lsp | 1.70.1 | rokit.toml |
| Lune | 0.10.5 | rokit.toml; available, not needed for Studio assertions |
| Blender | 5.2.2 LTS | Host installation |
| TestEZ | 0.4.1 | wally.toml + wally.lock |
| ProfileStore | upstream 1.0.3 | commit 45c9847cbcf1fc260369c50eb335aba7c35aecdd |

All tools were already installed; no global installation or global Git configuration was changed.
On this machine Rokit resolves the pinned cached tools. On a new host, install free Rokit and run
`rokit install` yourself (it writes its user tool cache), then `./scripts/bootstrap.ps1`.
Bootstrap keeps Wally's cache inside `.tools/wally` and verifies the downloaded Roblox type definitions by SHA-256.
ProfileStore is vendored from MadStudio's official repository, rather than relying on a third-party Wally fork.

## Verification and synchronization

`./scripts/check.ps1` checks authored Luau formatting, lint and strict types, builds release and development
places, checks release isolation, and verifies ProfileStore's hash. Third-party source is not reformatted.
luau-lsp's CLI may emit a nonfatal file-watcher registration warning.

`./scripts/serve.ps1 -Development` serves only localhost:34872. Connect the Rojo plugin in the approved place.
Both mappings restrict servePlaceIds to 94365962623582 and do not manage Workspace.
The development map adds TestEZ, unit specs, a Studio-only runner and server-only debug tools. Play prints
`[GrowAPlanet:Phase3] TESTS_PASS` followed by the test counts when all assertions pass.
The release mapping contains neither TestEZ nor the pipeline runner. Never publish a development build.
Disconnect before switching projects. Studio source edits are not a replacement for repo edits.
If another Rojo server occupies the port, use `./scripts/serve.ps1 -Development -Port 34873`
and connect to that port. A new port can require an owner-approved Studio plugin permission prompt.
Phase 1 testing used port 34873. Phase 3 used the owner's development server on 34872.
Build isolation is checked on clean generated places. Switching a connection on an existing place can
retain unmanaged objects; do not publish a development Studio session as the release artifact.

## Blender

Run each command in a separate process from the repo:

```powershell
blender --background --factory-startup --python assets/scripts/build_pipeline_cube.py
blender --background --factory-startup --python assets/scripts/verify_pipeline_cube.py
```

The first writes the original .blend and FBX; the second reopens the blend and independently reimports FBX.
Studio's 3D importer accepted the FBX. Default conversion produced a 200-stud cube from 2 Blender units:
apply a 0.01 scale in import settings for future exports, then inspect dimensions. The test instance was
calibrated in Studio to 2 studs. This is a pipeline fixture, not production planet art.
Upload was unchecked in the importer, but Studio returned a real rbxassetid; ownership/persistence of that
ID has not been independently verified. Do not use it as a production asset. See the manifest.

## Connections and limits

Studio MCP: read/Edit execution, play/stop, server inspection and console output tested.
Rojo: real filesystem-to-Studio sync and execution tested. Blender MCP: connected scene inspection;
safe asset generation uses fresh background Blender processes instead of touching the interactive scene.
GitHub: repository access verified; push status recorded in the phase report/chat.
No physical mobile devices tested. Device simulator availability is not a UI/device acceptance test.
Phase 1 requires real Studio API access to play. The initial test found it disabled and confirmed the
safe load-failure kick. The owner controls that setting; see the Phase 1 report for later acceptance results.
ProfileStore performs an API probe and saves only to the separate Studio namespace during these tests.
See ENGINE.md for the schema, namespace, precision limits and test commands.
