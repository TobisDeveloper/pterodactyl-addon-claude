---
name: blueprint-extension-dev
description: >
  This skill should be used when the user asks to "create a Blueprint extension",
  "make a Pterodactyl extension/addon", "build a Blueprint addon", mentions
  "conf.yml", "Components.yml", "Console.yml", "blueprint -build", "blueprint -init",
  "blueprint -export", ".blueprint file", or asks anything about developing,
  debugging, packaging, or modifying extensions for the Blueprint framework
  (blueprint.zip) on the Pterodactyl panel.
metadata:
  version: "1.0.0"
  blueprint-docs-snapshot: "BlueprintFramework/web @ June 2026 (latest release: beta-2026-05)"
---

# Blueprint Extension Development (Pterodactyl)

Develop extensions for the Blueprint framework — the extension/modding framework for the Pterodactyl game server panel. Blueprint extensions are NOT Minecraft plugins, NOT Pterodactyl eggs, and NOT standalone panel modifications.

## ⛔ Anti-hallucination rules (NON-NEGOTIABLE)

Blueprint is a niche framework with sparse training-data coverage. Inventing APIs is the #1 failure mode. Follow these rules strictly:

1. **The bundled docs in `references/` are the source of truth.** They are a verbatim copy of the official documentation (github.com/BlueprintFramework/web). ALWAYS read the relevant reference file BEFORE writing any Blueprint config, controller, component, or script.
2. **If a `conf.yml` option is not listed in `references/configs/confyml.md`, it does not exist.** This is the Blueprint maintainers' own rule. The same applies to `Components.yml` placement areas, `Console.yml` options, placeholders, flags, script environment variables, and `BlueprintExtensionLibrary` methods — never invent any of these. Verify each one against the matching reference file before using it.
3. **Never guess method names.** All extension-library methods (`dbGet`, `dbSet`, etc.) must be confirmed in `references/lib/extension-library-methods.md` before use.
4. **When the bundled docs don't cover something**, fetch the live docs instead of guessing:
   - `https://raw.githubusercontent.com/BlueprintFramework/web/main/apps/frontend/content/docs/<category>/<page>.md`
   - or browse real open-source extensions on GitHub (search: `topic:blueprint-extension` or org `BlueprintFramework`).
   If neither resolves it, tell the user plainly that the capability is not documented and propose a documented alternative (e.g., an extension script) — do NOT fabricate an API.
5. **Pterodactyl internals**: when calling into Pterodactyl's own code (models, services, repositories), verify against the actual source at `https://raw.githubusercontent.com/pterodactyl/panel/1.0-develop/<path>` rather than memory. Pterodactyl is Laravel 10 / PHP; its frontend is React + TypeScript.
6. State clearly when something is unverified. Never present guessed Blueprint behavior as fact.

## Verified technology stack

| Layer | Technology | File types |
|---|---|---|
| Extension manifest & configs | YAML | `conf.yml`, `Components.yml`, `Console.yml` |
| Backend (controllers, routes, console) | PHP (Laravel — Pterodactyl is a Laravel app) | `.php` |
| Admin panel UI | Laravel Blade templates | `view.blade.php`, optional CSS |
| Client dashboard UI | React + TypeScript (Pterodactyl's frontend stack; Tailwind/twin.macro styling) | `.tsx` |
| Database | Laravel migrations (MySQL/MariaDB) | `.php` migrations |
| Install/update/remove hooks | Bash | `install.sh`, `update.sh`, `remove.sh`, `export.sh` |

Do not use other languages. Client components are TypeScript React (`.tsx`), not Vue, not plain JS injected via script tags (CSS/JS injection binds exist but components are the proper mechanism).

## Architecture: separating UI from backend

Enforce this separation in every extension:

```
┌─ ADMIN SIDE ──────────────────────────────┐  ┌─ CLIENT SIDE ─────────────────────────────┐
│ view.blade.php (admin.view)               │  │ React .tsx components (dashboard.         │
│ rendered by admin controller              │  │ components, wired via Components.yml)     │
│ (admin.controller, optional)              │  │                                           │
└───────────────┬───────────────────────────┘  └───────────────┬───────────────────────────┘
                │ PHP form posts / Blade                        │ HTTP fetch (axios/http) ONLY
                ▼                                               ▼
┌─ BACKEND (PHP / Laravel) ────────────────────────────────────────────────────────────────┐
│ Controllers in requests.app dir (namespace {appcontext}, replaced at install time)       │
│ Routes bound in conf.yml requests.routers:                                               │
│   application → /api/application/extensions/{identifier}   (Application API key auth)    │
│   client      → /api/client/extensions/{identifier}        (Client API key / session)    │
│   web         → /extensions/{identifier}                    (NO auth — public!)          │
│ Settings storage: $blueprint->dbGet()/dbSet() • Custom tables: database.migrations       │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

Hard rules for the boundary:
- React components NEVER contain secrets, API tokens, or credentials, and NEVER call external third-party APIs directly. All external calls go through a backend route (usually a `client` router endpoint). This is official Blueprint guidance.
- Client-area features that need per-user/per-server auth use `requests.routers.client` routes — these inherit Pterodactyl's client authentication.
- `web` routes are unauthenticated; never expose sensitive data or mutations there.
- Backend controllers live in the `requests.app` directory. ⚠️ **Never use the `{appcontext}` placeholder in PHP namespaces or `use` statements**, even though the official docs suggest it: Blueprint substitutes it with a double-quoted `sed` expression, so the backslashes in `Pterodactyl\BlueprintFramework\Extensions\{identifier}` are eaten by sed (`\E` is even parsed as sed's end-of-case-conversion escape), yielding the unloadable namespace `PterodactylBlueprintFrameworkxtensions...`. The class then can't be autoloaded and every extension API route 500s (verified against the beta-2026-05 install script). Write the namespace literally instead: `namespace Pterodactyl\BlueprintFramework\Extensions\<identifier>;` in `requests.app` files and the matching literal `use` in router files, with the file named after the class (PSR-4). Admin controllers are unaffected: they use the literal `namespace Pterodactyl\Http\Controllers\Admin\Extensions\{identifier};` with class `{identifier}ExtensionController`.
- Routes in router files are plain Laravel `Route::` definitions, written relative to the auto-added prefix.

## Standard extension layout

```
myextension/
├── conf.yml                      # manifest — REQUIRED (read references/configs/confyml.md first)
├── admin/
│   ├── view.blade.php            # admin.view (REQUIRED bind)
│   └── controller.php            # admin.controller (optional)
├── app/                          # requests.app — backend controllers
│   └── MyController.php
├── routers/
│   ├── client.php                # requests.routers.client
│   └── web.php                   # requests.routers.web
├── components/                   # dashboard.components — client React UI
│   ├── Components.yml
│   └── sections/MyPage.tsx
├── migrations/                   # database.migrations
├── console/                      # data.console
│   ├── Console.yml
│   └── mycommand.php
├── data/                         # data.directory — private storage + install.sh etc.
└── public/                       # data.public — publicly served files
```

Only create directories the extension actually needs; every path used must be bound in `conf.yml`.

## conf.yml essentials (verify full details in references/configs/confyml.md)

- `info.name`, `info.identifier`, `info.description`, `info.version`, `info.target` are required.
- `identifier` is lowercase `a-z` only, unique, effectively unchangeable later.
- `info.target` is the Blueprint release the extension is built against (e.g. `beta-2026-05` as of June 2026 — confirm the user's installed version with `blueprint -version` rather than assuming).
- `admin.view` is required for every extension.
- The full reference template (the complete set of options that exist) is at the bottom of `references/configs/confyml.md`.

## Development workflow

1. **Understand the goal** — what panel area does the feature live in (admin page, client server tab, account page, console command, API)?
2. **Read the relevant references** for every mechanism you'll touch (see map below).
3. **Scaffold** — base new extensions on the official templates in `examples/` (01-barebones → 02-admin-configuration → 03-react-components → 04-console-commands). Or, on a live panel with developer mode: `blueprint -init` creates a dev extension in `.blueprint/dev/` under the Pterodactyl root (usually `/var/www/pterodactyl`).
4. **Build & test** on the panel: `blueprint -build` applies the dev extension. React component changes require the build step (Blueprint compiles the panel frontend; Node.js ≥ v22 required as of beta-2026-05).
5. **Package**: `blueprint -export` produces the distributable `{identifier}.blueprint` file; admins install it with `blueprint -install <file>`. See `references/guides/packaging.md` and `references/cli/blueprint-cli-commands.md`.
6. **Validate before delivering** (checklist below).

## Reference map — read before coding

| Task | Read first |
|---|---|
| Any `conf.yml` work | `references/configs/confyml.md` |
| Client UI / React pages & components | `references/configs/componentsyml.md` + `examples/03-react-components/` |
| Custom routes / extension APIs | `references/concepts/routing.md` |
| Admin page UI | `references/guides/adminpage.md` |
| Admin controller / settings forms | `references/guides/admincontroller.md`, `references/guides/adminconfiguration.md` |
| Storing settings (`dbGet`/`dbSet`), alerts, checking other extensions | `references/lib/extension-library-methods.md` |
| Custom DB tables | `references/guides/migrations.md` |
| Artisan/console commands & scheduling | `references/configs/consoleyml.md` |
| install/update/remove scripts, env vars | `references/concepts/scripts.md` |
| `{identifier}`, `{root}` etc. placeholders | `references/concepts/placeholders.md` |
| Extension flags | `references/concepts/flags.md` |
| Where Blueprint puts files on the panel | `references/concepts/filesystem.md` |
| Dashboard wrapper (inject into client layout) | `references/guides/dashboardwrapper.md` |
| CLI commands | `references/cli/blueprint-cli-commands.md` |
| Dev environment in Docker | `references/guides/docker.md` |

## Pre-delivery validation checklist

Run through this before presenting any extension code:

- [ ] Every `conf.yml` key exists in the reference template in `references/configs/confyml.md`.
- [ ] Every bound path in `conf.yml` corresponds to a file/directory that was actually created.
- [ ] `identifier` is lowercase a-z only and used consistently (namespaces, routes, Console.yml signatures).
- [ ] Admin controllers use the documented namespace/class pattern; `requests.app` controllers use `{appcontext}`.
- [ ] Component paths in `Components.yml` are relative, without file extensions, and every placement area used exists in `references/configs/componentsyml.md`.
- [ ] No secrets/tokens in any `.tsx` file; no direct external API calls from React.
- [ ] Routes are relative (no hardcoded `/extensions/...` prefixes inside router files).
- [ ] Migrations follow Laravel conventions; table names are prefixed with the identifier to avoid conflicts.
- [ ] `install.sh`/`remove.sh` (if any) are reversible — `remove.sh` cleans up everything `install.sh` changed. Blueprint extensions must uninstall cleanly.
- [ ] YAML is valid (Blueprint's parser fails silently on bad quoting — lint it yourself).
- [ ] Every Blueprint API used was verified in `references/` or live docs this session — zero guessed APIs.
