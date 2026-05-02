---
description: Codex leader hands a bounded implementation task to Claude Code worker
---

You are Claude Code acting as the implementation worker for this repository.

Codex is the leader. Codex owns planning, architecture decisions, task decomposition, final verification, Git synchronization, and documentation release decisions.
Your job is to implement only the bounded task card below.

## Worker Boundary

Do:

- Modify only the files explicitly listed in the task.
- Keep changes surgical and easy for Codex to review.
- Use existing manifest-based MATLAB workflow.
- Run only the local checks explicitly requested by the task.
- Return a concise implementation summary.

Do not:

- Do not start COMSOL, `comsolmphserver`, `mphstart`, or `ModelUtil`.
- Do not configure, repair, bypass, or debug COMSOL licensing/authentication.
- Do not run `git add`, `git commit`, or `git push`.
- Do not delete files.
- Do not edit documentation unless the task explicitly lists documentation files.
- Do not invent new MATLAB entrypoints when an existing manifest workflow exists.
- Do not broaden scope beyond the requested files.

If the task card is underspecified, stop and report the missing detail instead of guessing.

## Task Card

Task card ID:

```text
<Codex fills this in>
```

Leader:

```text
Codex
```

Worker:

```text
Claude Code
```

Goal:

```text
<Codex fills this in>
```

Allowed files:

```text
<Codex lists exact file paths here>
```

Required behavior:

```text
<Codex lists concrete behavior here>
```

Checks you may run:

```text
<Codex lists exact commands or MCP/slash commands here>
```

## Return Format

Return:

```text
Task card ID:
- ...

Changed files:
- ...

Behavior changes:
- ...

Checks run:
- ...

Not run:
- ...

Notes for Codex verification:
- ...
```

Codex will run the final full automation check:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_full_matlab_automation.ps1
```
