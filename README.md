# security-toolkit

Reusable CTF / security-testing tooling. Scripts are written for WSL / Linux.

> **Disclaimer:** Educational security tooling for CTF and authorized testing.
> Use only on systems you own or have explicit permission to test.

## Contents
| File | What it does | When |
|---|---|---|
| `CTF-cheatsheet.md` | greppable command recipes by category | open it first |
| `triage.sh` | one-shot file recon (type/footer/strings/exif/binwalk/entropy) | every forensics file |
| `crackprep.sh` | archive/doc -> clean hashcat hash + exact command | any password-protected file |
| `audio_id.py` | identifies PSK vs FSK vs SSTV, saves spectrogram, names the decoder | any mystery audio |

For the Erlang distribution-protocol RCE client (`erl_pwn.py`) and the TCP↔WSS
tunnel (`rowdy_tunnel.py`), see
[rowdyhacks-2026-writeup](https://github.com/jacobcampos15-beep/rowdyhacks-2026-writeup/tree/main/scripts)
— they're exploit-specific, so they live with that writeup.

## Setup (once)
```bash
chmod +x triage.sh crackprep.sh
sudo apt install -y binwalk exiftool steghide john p7zip-full
pip install numpy matplotlib --break-system-packages   # for audio_id.py
# stegseek / zsteg are separate installs if you want them
```

## Typical flow
1. `./triage.sh <file>` — read the verdict + suggested next moves.
2. Branch by type using the cheat-sheet.
3. Keep a per-challenge note (obstacle + exact command + the *why*) — that's what
   makes a technique stick.

## Notes
- Started from RowdyHacks 2026 (first CTF, finished 20th); grown since.
- These cover the *repeatable* 80%: recon, cracking prep, audio ID. Web / pwn /
  crypto exploits are too situational to pre-write — recognize the pattern and
  build on the spot (the cheat-sheet has the staples).
