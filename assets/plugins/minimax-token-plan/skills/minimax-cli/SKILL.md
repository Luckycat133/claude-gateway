---
name: minimax-cli
description: Use MiniMax Token Plan for image, video, speech, music, text, quota, or MiniMax web-search tasks through the official mmx CLI.
allowed-tools: Bash
---

# MiniMax Token Plan CLI

Use the official `mmx-cli` package for MiniMax generation and account tasks.
The current crouter session already supplies `MINIMAX_API_KEY` and
`MINIMAX_REGION=cn`; never run `mmx auth login`, persist the key, or print it.

Run the CLI without a global install:

```bash
npx -y mmx-cli@1.0.19 <command> --quiet --non-interactive
```

Before an unfamiliar operation, inspect the exact current command shape with
`npx -y mmx-cli@1.0.19 <command> --help`. Prefer explicit output paths inside
the user's current project. Ask before overwriting an existing artifact.
