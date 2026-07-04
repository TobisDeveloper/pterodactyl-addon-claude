# Pterodactyl Blueprint Extension Developer

A Claude Code plugin for building extensions for the [Blueprint framework](https://blueprint.zip) on the Pterodactyl panel — without hallucinated APIs.

## Why this plugin exists

Blueprint is a niche framework, so AI models tend to invent configuration options and methods that don't exist. This plugin solves that by bundling a **verbatim snapshot of the official Blueprint documentation** (from `BlueprintFramework/web`, June 2026, latest release `beta-2026-05`) directly into the skill. Claude is instructed to treat these docs as ground truth, to verify every config option and API call against them, and to fetch live docs from GitHub when something isn't covered — never to guess.

## Components

- **Skill: `blueprint-extension-dev`** — triggers on any Blueprint/Pterodactyl extension work. Contains:
  - Hard anti-hallucination rules ("if it's not in the docs, it doesn't exist")
  - The verified tech stack (YAML configs, PHP/Laravel backend, Blade admin UI, React + TypeScript client UI)
  - UI/backend separation architecture with the three router types and their auth levels
  - `references/` — the complete official docs: conf.yml, Components.yml, Console.yml, routing, scripts, placeholders, flags, filesystem, extension library methods, CLI commands, and all dev guides
  - `examples/` — the four official extension templates from `BlueprintFramework/templates`
- **Agent: `blueprint-validator`** — audits an extension before export: checks every conf.yml key against the reference template, validates bound paths, namespaces, Components.yml placements, library method calls, YAML syntax, and scans React components for leaked secrets or direct external API calls.

## Usage

- "Make a Blueprint extension that adds a backup scheduler tab to servers"
- "Add an admin settings page to my extension"
- "Why does blueprint -install fail on my extension?"
- "Validate my extension before I export it" (runs the validator agent)

## Setup

No environment variables required. For building/testing extensions you need a Pterodactyl panel with Blueprint installed (Node.js ≥ v22 for the current release) — Claude will use `blueprint -build` / `blueprint -export` when working on a live panel, or produce the full extension directory otherwise.

## Updating the bundled docs

The docs snapshot can be refreshed any time by asking Claude to re-download from:
`https://github.com/BlueprintFramework/web` (path `apps/frontend/content/docs` and `guides/dev`).
