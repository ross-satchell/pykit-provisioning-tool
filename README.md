# PyKit Explorer - Board Provisioning Tool

This tool fully provisions a **brand-new** PyKit Explorer board. It downloads
the latest PyKit Explorer content straight from GitHub and writes it to the
board's `CIRCUITPY` drive — no need to separately download this repo, and no
Python install required on your computer.

**This is a one-time setup step for a fresh board.** It overwrites `code.py`,
so don't run it on a board a student has already been coding on — it will
replace their work.

It writes the following to the root of `CIRCUITPY`, replacing anything
already there with the same name:

- Folders: `API`, `AudioFiles`, `Fonts`, `Images`, `lib`
- Files: `README.md`, `code.py`, `pykit_explorer.py`

Before running any of the scripts below, plug in the board via USB. It
should show up as a drive named `CIRCUITPY`.

---

## Windows

**Double-click `provision-board.bat`.**

A window opens, downloads the latest content, and asks you to confirm (type
`y` and press Enter) before it overwrites anything. It stays open with a
"Press Enter to close this window" prompt when it's done, so you can read
the result.

> Right-clicking `provision-board.ps1` directly and choosing "Run with
> PowerShell" usually **won't work** — most Windows installs block `.ps1`
> files from running at all unless you use the `.bat`, which explicitly
> allows this one script to run. Use `provision-board.bat`, not the `.ps1`
> directly.

**Command-line / advanced usage:**
```
powershell -ExecutionPolicy Bypass -File provision-board.ps1
powershell -ExecutionPolicy Bypass -File provision-board.ps1 -Force
powershell -ExecutionPolicy Bypass -File provision-board.ps1 -Ref v1.2.0
```

---

## macOS

**Option A — Double-click (simplest)**
1. Double-click `provision-board.command`.
2. macOS will likely block it the first time with *"cannot be opened
   because it is from an unidentified developer."* Right-click
   (Control-click) `provision-board.command` → **Open** → **Open** again in
   the dialog. You only need to do this once.
3. A Terminal window walks you through the process. Type `y` and press
   Enter to confirm.

**Option B — Terminal**
```bash
cd ~/Downloads   # or wherever you saved the files
bash provision-board.sh
```

**Option C — No download needed (fast path)**
```bash
curl -fsSL https://raw.githubusercontent.com/CoffeeTronics/PyKit-Explorer-Code-Modules/main/provision-board.sh | bash
```

---

## Linux

**Terminal:**
```bash
cd ~/Downloads   # or wherever you saved provision-board.sh
bash provision-board.sh
```

**No download needed (fast path):**
```bash
curl -fsSL https://raw.githubusercontent.com/CoffeeTronics/PyKit-Explorer-Code-Modules/main/provision-board.sh | bash
```

---

## Flags (macOS / Linux)

| Flag | What it does |
|---|---|
| `--yes` | Skip the confirmation prompt — useful when provisioning many boards back-to-back |
| `--ref <branch-or-tag>` | Provision from a specific branch or release tag instead of `main` |

```bash
bash provision-board.sh --yes
curl -fsSL https://raw.githubusercontent.com/CoffeeTronics/PyKit-Explorer-Code-Modules/main/provision-board.sh | bash -s -- --ref v1.2.0
```

## Flags (Windows)

| Flag | What it does |
|---|---|
| `-Force` | Skip the confirmation prompt |
| `-Ref <branch-or-tag>` | Provision from a specific branch or release tag instead of `main` |

---

## Troubleshooting

- **"No CIRCUITPY drive found"** — make sure the board is plugged in and
  shows up as a drive named `CIRCUITPY` before running the script.
- **macOS: "unidentified developer" warning** — see step 2 under macOS
  above. You only need to approve it once.
- **Linux/macOS: "Permission denied"** when running `./provision-board.sh`
  directly — run it as `bash provision-board.sh` instead.
- **Windows: window opens and instantly closes** — use
  `provision-board.bat`, not the `.ps1` file directly (see the Windows
  section above).
- An internet connection is required — the script downloads the latest
  content from GitHub each time it runs.
- A `PROVISION_INFO.txt` file is written to the board recording which
  commit it was provisioned from, useful for troubleshooting later.

---

## Files in this package

| File | Platform | Purpose |
|---|---|---|
| `provision-board.bat` | Windows | Double-click entry point |
| `provision-board.ps1` | Windows | The actual script (called by the `.bat`) |
| `provision-board.command` | macOS | Double-click entry point |
| `provision-board.sh` | macOS / Linux | The actual script |
