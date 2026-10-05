#!/usr/bin/env bash
# crackprep.sh — turn an encrypted archive/doc into a clean hashcat hash + the
# exact command. Handles the gotchas you hit on Locked File:
#   * filenames with "!" (single-quote them yourself when calling)
#   * double-written hash files (uses >, then strips to the bare $...$ line)
#   * verifies the hash is exactly one line before you waste GPU time
# Usage:  ./crackprep.sh <file>
set -u
f="${1:-}"; [ -z "$f" ] && { echo "usage: $0 <encrypted-file>"; exit 1; }
[ -f "$f" ] || { echo "no such file: $f"; exit 1; }
out="$(basename "$f").hash"

# locate the john "*2john" helper for this type
J=/usr/share/john
pick(){ for p in "$J/$1" "$(command -v "$1" 2>/dev/null)"; do [ -x "$p" ] && { echo "$p"; return; }; done; }

t=$(file -b "$f")
case "$t" in
  *7-zip*)        tool=$(pick 7z2john.pl);        mode=11600; name="7-Zip";;
  *Zip*|*ZIP*)    tool=$(pick zip2john);          mode=13600; name="ZIP (try 17200/17210 for ZipCrypto/PKZIP)";;
  *RAR*|*Rar*)    tool=$(pick rar2john);          mode=13000; name="RAR5 (or 12500 for RAR3)";;
  *PDF*)          tool=$(pick pdf2john.pl);        mode=10500; name="PDF (mode varies 10400-10700 by version)";;
  *Microsoft*|*Composite*) tool=$(pick office2john.py); mode=9600; name="MS Office (9400/9500/9600 by version)";;
  *) echo "unrecognized type: $t"; echo "try: ls $J/*2john*"; exit 1;;
esac
[ -z "${tool:-}" ] && { echo "helper not found for $name. Install john: sudo apt install john"; exit 1; }

echo "[*] type: $name"
echo "[*] tool: $tool"
case "$tool" in *.py) python3 "$tool" "$f" ;; *) "$tool" "$f" ;; esac 2>/dev/null \
  | grep -oE '\$[a-zA-Z0-9]+\$.*' | head -1 > "$out"

if [ ! -s "$out" ]; then echo "[!] hash extraction produced nothing — wrong tool or bad file"; exit 1; fi
lines=$(wc -l < "$out")
echo "[+] wrote $out  (lines: $lines)"
echo "[+] head: $(head -c 70 "$out")..."
[ "$lines" -ne 1 ] && echo "[!] expected 1 line — inspect $out"

echo
echo "=== run on a GPU (Colab/Kaggle free T4) ==="
echo "hashcat -m $mode -a 0 $out /path/to/wordlist.txt                 # straight dict"
echo "hashcat -m $mode -a 0 $out wordlist.txt -r rules.rule            # with rules"
echo "hashcat -m $mode -a 6 $out words.txt '?d?s'                      # dict + append digit+symbol"
echo "hashcat -m $mode $out --show                                    # print cracked password"
