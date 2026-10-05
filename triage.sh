#!/usr/bin/env bash
# triage.sh — first-pass recon for any CTF file. Runs the whole forensics
# opening in one shot so you don't retype it every challenge.
# Usage:  ./triage.sh <file>
set -u
f="${1:-}"; [ -z "$f" ] && { echo "usage: $0 <file>"; exit 1; }
[ -f "$f" ] || { echo "no such file: $f"; exit 1; }
bar(){ printf '\n=== %s ===\n' "$1"; }
have(){ command -v "$1" >/dev/null 2>&1; }

bar "FILE TYPE";      file "$f"
bar "SIZE";           sz=$(stat -c%s "$f"); echo "$sz bytes"

bar "HEAD (hex)";     head -c 64 "$f" | od -An -tx1z | tr -s ' '

# appended-data check: does real content end before the file does?
bar "FOOTER / APPENDED-DATA CHECK"
case "$(file -b "$f")" in
  *JPEG*) end=$(grep -aboF $'\xff\xd9' "$f" | tail -1 | cut -d: -f1)
          [ -n "$end" ] && echo "JPEG EOI (FF D9) at $((end+2)); file is $sz -> $([ $((end+2)) -lt "$sz" ] && echo "EXTRA $(($sz-end-2)) bytes appended (!)" || echo "clean")";;
  *PNG*)  end=$(grep -aboF 'IEND' "$f" | tail -1 | cut -d: -f1)
          [ -n "$end" ] && echo "PNG IEND at $end; file is $sz -> $([ $((end+8)) -lt "$sz" ] && echo "EXTRA $(($sz-end-8)) bytes appended (!)" || echo "clean")";;
  *) echo "(no footer rule for this type — if size looks big, check binwalk below)";;
esac

bar "STRINGS -> flag-ish"
strings -n 6 "$f" | grep -aiE 'flag|rowdy|ctf|\{[^}]{2,}\}' | head -40
echo "(also try: strings -e l / -e b for UTF-16)"

if have exiftool; then bar "EXIFTOOL"; exiftool "$f" | grep -viE '^(ExifTool|File (Permissions|Inode|Modification|Access))'; fi
if have binwalk;  then bar "BINWALK";  binwalk "$f" | head -40; fi

bar "ENTROPY HINT"
python3 - "$f" <<'PY' 2>/dev/null || echo "(python3 not available)"
import sys,math,collections
b=open(sys.argv[1],'rb').read(200000)
c=collections.Counter(b); n=len(b) or 1
H=-sum(v/n*math.log2(v/n) for v in c.values())
print(f"first-200k entropy {H:.2f}/8  -> {'high (encrypted/compressed)' if H>7.5 else 'low/mixed (text/structured/stego carrier)'}")
PY

bar "NEXT MOVES"
cat <<'TIP'
 archive magic (PK / 7z / Rar!)   -> extract; if encrypted -> crackprep.sh
 image, lossless (PNG/BMP)        -> zsteg -a  (LSB stego)
 image, JPEG + passphrase hint    -> steghide extract -sf f -p PASS
 image, JPEG no passphrase        -> stegseek f rockyou.txt
 audio (wav/raw)                  -> audio_id.py  (PSK vs FSK vs SSTV)
 appended bytes after footer      -> unzip f  /  binwalk -e f
 one-stop web triage              -> aperisolve.com
TIP
