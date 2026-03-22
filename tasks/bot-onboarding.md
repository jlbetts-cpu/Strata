# Bot Onboarding Prompt

Copy-paste this to each Claude bot at the start of a session:

---

**Paste this:**

> We reorganized the task files. Here's the new structure:
>
> - `tasks/active.md` — **Read this first.** Shows what's in progress and what's next. When you start a task, mark it `[-]`. When done, mark `[x]` and move the entry to `history.md`.
> - `tasks/history.md` — Completed work, organized by category (Added/Changed/Fixed/Removed). Append-only — add your completed work here when you finish.
> - `tasks/coordination.md` — Bot assignments and shared file ownership. **Check this before editing any shared file** (MainAppView, GridConstants, models, etc).
> - `tasks/backlog.md` — Future ideas and tech debt. Low priority, just a parking lot.
>
> The old `tasks/todo.md` has been deleted and split across these files.
>
> **Your workflow each session:**
> 1. Read `tasks/active.md` to see what to work on
> 2. Read `tasks/coordination.md` if you need to touch shared files
> 3. When done, move completed items from `active.md` to `history.md`
> 4. Keep `active.md` under 30 lines — move future ideas to `backlog.md`
