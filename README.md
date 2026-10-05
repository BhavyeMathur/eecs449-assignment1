# Daybook

**Author:** Bhavye Mathur

**UMID:** 97660744

Daybook is a private, photo-first personal planner and record of everyday life.
It pairs one lightweight daily intention with the moments that actually made up
the day: work, food, coffee chats, events, people, and ordinary details. Moments
can belong to reusable **threads** such as `Coffee chats`, `Research`, or
`Campus light`, creating stories that continue across otherwise separate days.

## Main features

- Plan one meaningful intention for any day, then complete, reopen, or remove it.
- Capture text-only or photo moments and classify them by kind.
- Reuse thread chips instead of retyping names; case-insensitive deduplication
  keeps the archive consistent.
- Browse a polished web timeline, photo calendar, and interactive thread
  gallery; open and safely delete individual moments.
- Capture from the native camera or photo library on mobile and receive one
  local 8 PM reminder each day.
- Plan, complete, review, and log from the terminal without opening a browser.
- Keep all four interfaces on one persistent Jac graph and photo store.

## How the four components fit together

| Component | Role |
| --- | --- |
| `core/journal.jac` | Server-side planning logic, graph persistence, photo storage, ownership checks, calendar aggregation, and typed public API. |
| `web/` | Full archive and planning workspace: daily story, intention control, calendar, threads, multi-photo upload, details, and deletion. |
| `mobile/` | Quick daily workflow: intention, camera/library capture, thread selection, recent moments, deletion, and reminder scheduling. |
| `cli/` | Fast terminal workflow for setting/completing intentions, logging moments, and reviewing days or threads. |

The `web`, `mobile`, and `cli` apps call the same public functions in
`core/journal.jac`. Days, intentions, moments, and threads are persistent graph
nodes reachable from the user's Jac root. Original photo bytes are stored under
`uploads/` while graph nodes retain storage metadata; both web and mobile load
photos through an ownership-checked API. `uploads/` is ignored by Git so
personal photos are never part of the submission repository.

## Why this project stands out

Daybook treats planning and memory as one coherent workflow instead of making
another generic task list. A daily intention records what the user meant to do;
the photo story records what the day became. Its four clients are not separate
demos: they share typed models, durable state, thread normalization, validation,
photo access control, and deletion behavior. The web interface supports
multi-photo drag-and-drop and a visual calendar, while the native mobile client
adds camera capture and idempotent local reminder scheduling.

## Prerequisites

- macOS, Linux, or Windows with a terminal
- Jac `0.37.14` (the version pinned in `jac.toml`)
- Node.js/npm as required by Jac's web and mobile toolchains
- Expo Go, Xcode, or Android Studio only for native mobile testing

Install Jac if needed:

```bash
curl -fsSL https://jaclang.org/install.sh | bash
```

After cloning the repository, install dependencies from its root:

```bash
cd daybook
jac install
```

If `jac` is not found after installation, add `$HOME/.local/bin` to your
`PATH` as prompted by the installer.

## Run the web app and server

From the repository root:

```bash
jac run
```

The `web` app is configured as the default. Its dependency on the pinned
`server` module starts the shared backend automatically, so the grader only
needs this one command. Open the URL printed by Jac (normally
`http://localhost:8000`). For hot reload during development, use:

```bash
jac run --dev web
```

## Run the mobile app

For a quick browser preview of the responsive mobile interface:

```bash
jac run --dev --platform web mobile
```

Camera, photo-library, and notification APIs are native-only. To exercise them,
perform the one-time Expo setup and start the native development loop:

```bash
jac setup mobile
jac run --dev mobile
```

Press `i` for an iOS simulator, `a` for Android, or scan the Expo Go QR code.
The native app asks for camera/photo-library permission only when a capture is
requested. It asks for notification permission on first launch and schedules a
single daily 8 PM reminder, reusing the existing Daybook reminder on later
launches.

## Use the CLI

Keep `jac run` running in one terminal. In a second terminal, from the same
repository root, point the CLI at the shared service:

```bash
export JAC_APP_SERVER_URL=http://localhost:8001/api/server

jac run cli -- plan "Finish the project review"
jac run cli -- log "Debugged the compiler" --kind work --thread Research --thread "Small wins"
jac run cli -- today
jac run cli -- done
jac run cli -- threads
jac run cli -- clear-plan
```

Every command also accepts `--date YYYY-MM-DD` where it is useful. `--thread`
is repeatable, avoiding a fragile comma-separated list.

## Validate the project

Run the same checks used before submission:

```bash
jac check
jac test
jac test core/journal.jac
jac build web
jac build --platform web mobile
```

The automated suite covers thread normalization, date/calendar behavior,
planning lifecycle, photo retrieval and deletion, orphan cleanup, and CLI
argument contracts. Native camera and notification behavior must additionally
be checked on an iOS or Android simulator/device because a browser cannot
validate OS-level permissions or scheduled notifications.
