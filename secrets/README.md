# secrets/

**A password manager is the source of truth for credentials** as of 2026-09-05 (HL-34).
This directory is not.

Everything here is gitignored except this file. The old `credentials.md` was
deleted on 2026-09-05 (HL-55).

## Guardrails

`.githooks/pre-commit` refuses any commit that stages a file under `secrets/`, or
that contains something shaped like a private key or a password assignment. It's
active because the repo sets:

```bash
git config core.hooksPath .githooks
```

That setting is local to your clone — a fresh clone must re-run it. See the note
in the root [README](../README.md).

## Why not keep values here

Plaintext on disk is protected only by your Mac's login and FileVault. It does
not survive a stolen unlocked laptop, a careless backup of your home directory,
or a screen share — and this repo's own history shows how easily a credential
reaches a place you did not intend.

A password manager fixes all of that, which is why HL-34 moved everything to
the password manager. What is still worth keeping locally is an **index**: which credentials
exist and where they are used, with the values themselves in the password manager. That
stays useful during a rebuild without being a liability.

## Convention

If a local index is ever kept here, make it a table of *what exists and where
it's used* — never the values, which stay in the password manager.
