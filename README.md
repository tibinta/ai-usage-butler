# AI Usage Butler

AI Usage Butler is a menu-bar app for macOS that displays Codex and Claude usage limits. It does not send prompts, chat history, files, or generated content to an AI model, and it does not make model requests or generate AI content.

## Project status

This is a personal project, maintained for the author's own use and shared as-is. There is no promised support, response time, compatibility or update schedule. Updates may be shared when useful to the author; installed copies do not update automatically. Usage pacing is guidance, not a guarantee against reaching a provider limit.

Each user supplies their own provider sign-ins. No account credentials or personal usage data are included in the source or release packages.

## Requirements

- macOS 14 or later.
- Swift 5.9 or later from Xcode or the Xcode Command Line Tools.
- Codex installed and signed in to read Codex usage. The app looks for the Codex CLI at `~/.local/bin/codex`, `/opt/homebrew/bin/codex`, or `/usr/local/bin/codex` and runs its local `app-server` command.
- Claude Code installed and signed in to read Claude usage. The first interactive connection may show a macOS Keychain access prompt for Claude Code's existing credential.

Either provider can be unavailable; the app shows that state without inventing usage values.

## Privacy

Codex usage is read from the local Codex app-server. Claude usage is fetched from Anthropic's usage endpoint using the OAuth credential already stored for Claude Code in macOS Keychain. Usage Butler reads that credential from Keychain and sends it only as authentication for the Anthropic usage check; it is not bundled with the app. The request does not include prompts or conversations. Usage results and a SHA-256 credential fingerprint are cached locally in the app's UserDefaults to reuse recent results and detect sign-in changes. No telemetry or analytics are included.

Claude's usage endpoint is not a stable public API and may change. Claude may rate-limit checks; the last successful result is marked stale after 15 minutes. Automatic refresh runs every five minutes. A successful Claude result is reused for five minutes, including on manual refresh and relaunch; Details shows when it was fetched. `./script/build_and_run.sh --diagnose` prints usage readings or errors as JSON, not the credential.

## Build and run

This repository distributes source code only. Build your own copy on a Mac:

```sh
git clone https://github.com/tibinta/ai-usage-butler.git
cd ai-usage-butler
./script/build_and_run.sh
```

Run `swift test` to run the tests. Run `./script/build_and_run.sh` to build a local app bundle in `dist/` and launch it. Builds use an ad-hoc signature by default and do not require a Developer ID certificate.

Run `./script/build_and_run.sh --package` to prepare a universal release archive for Apple Silicon and Intel Macs running macOS 14 or later. The command builds release binaries, combines the arm64 and x86_64 slices, and creates `dist/AI Usage Butler-1.0.0-universal-macOS14.zip` plus a `.sha256` checksum file. It does not launch or replace the development app. The archive is ad-hoc signed and not notarized; macOS may show a first-open security warning. Setting `CODE_SIGN_IDENTITY` signs the package with that identity and enables the hardened runtime and timestamp, but does not notarize it.

Launch at login is optional and uses macOS Service Management; changing it modifies only that OS preference. The weekly allowance is the current weekly remaining percentage minus the even-pace amount to retain at the next 07:00, with bedtime at 22:00. When a weekly window resets between 10 pm and 7 am, keep 5% for that night until reset; this is advice, not an enforced limit. Before 07:00 the wake time is today; after 07:00 it is tomorrow. Session percentages are a separate limit and cannot be directly compared with weekly percentages. The included Libre Baskerville font is distributed under its accompanying OFL license.
