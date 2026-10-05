#!/usr/bin/env python3
# audio_id.py — identify an unknown audio signal and tell you WHICH decoder to use.
# Encodes the lesson from "Back to Nothing": one constant carrier = PSK (fldigi),
# two shifting tones = FSK (minimodem), image-like warble = SSTV (qsstv).
# Works on .wav or headerless raw PCM. Saves a spectrogram PNG.
# Usage:
#   python3 audio_id.py file.wav
#   python3 audio_id.py raw.bin --raw --rate 44100 --bits 8   # 8-bit unsigned mono
#   python3 audio_id.py raw.bin --raw --rate 44100 --bits 16  # 16-bit signed LE mono
import sys, argparse, wave
import numpy as np

def load(path, raw, rate, bits):
    if not raw and path.lower().endswith(".wav"):
        w=wave.open(path,"rb"); rate=w.getframerate(); sw=w.getsampwidth(); ch=w.getnchannels()
        d=w.readframes(w.getnframes())
        x=np.frombuffer(d, dtype={1:np.uint8,2:"<i2",4:"<i4"}[sw]).astype(np.float64)
        if ch>1: x=x[::ch]
        if sw==1: x-=128
        return x, rate
    dt = np.uint8 if bits==8 else "<i2"
    x=np.frombuffer(open(path,"rb").read(), dtype=dt).astype(np.float64)
    if bits==8: x-=128
    return x, rate

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("file"); ap.add_argument("--raw",action="store_true")
    ap.add_argument("--rate",type=int,default=44100); ap.add_argument("--bits",type=int,default=8,choices=[8,16])
    ap.add_argument("--png",default="spectrogram.png")
    a=ap.parse_args()
    x,rate=load(a.file,a.raw,a.rate,a.bits); x-=x.mean()
    dur=len(x)/rate
    print(f"[*] {len(x)} samples @ {rate} Hz  (~{dur:.1f}s)")

    # average spectrum over the loudest ~3s window
    seg=x[:min(len(x),rate*3)]
    nfft=4096; hop=1024; win=np.hanning(nfft)
    cols=max(1,1+(len(seg)-nfft)//hop)
    S=np.zeros((nfft//2+1,cols))
    for i in range(cols):
        S[:,i]=np.abs(np.fft.rfft(seg[i*hop:i*hop+nfft]*win))
    fr=np.fft.rfftfreq(nfft,1/rate)
    avg=S.mean(1)
    # "persistent carrier" = a frequency bin loud across most time slices
    persist=(S > S.max()*0.25).mean(1)        # fraction of time each bin is hot
    band=(fr>150)&(fr<rate*0.45)
    carriers=[]
    pk=persist.copy(); pk[~band]=0
    for _ in range(4):
        i=int(np.argmax(pk))
        if pk[i]<0.6: break
        carriers.append((fr[i],pk[i]))
        pk[max(0,i-20):i+20]=0                # suppress neighbourhood
    try:
        import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
        full=x[:min(len(x),rate*8)]
        c2=max(1,1+(len(full)-nfft)//hop); SS=np.zeros((nfft//2+1,c2))
        for i in range(c2): SS[:,i]=np.abs(np.fft.rfft(full[i*hop:i*hop+nfft]*win))
        SS=20*np.log10(SS+1e-9); vmin,vmax=np.percentile(SS,[60,99.8])
        plt.figure(figsize=(20,6)); plt.imshow(SS,origin="lower",aspect="auto",cmap="magma",
            vmin=vmin,vmax=vmax,extent=[0,len(full)/rate,0,rate/2])
        plt.ylim(0,min(5000,rate/2)); plt.xlabel("s"); plt.ylabel("Hz")
        plt.tight_layout(); plt.savefig(a.png,dpi=90); plt.close()
        print(f"[*] spectrogram -> {a.png}")
    except Exception as e:
        print("[i] matplotlib not available, skipping PNG:",e)

    print("\n[*] persistent carriers (freq Hz, %-of-time-present):")
    for f,p in carriers: print(f"      {f:8.1f} Hz   {p*100:4.0f}%")

    print("\n=== VERDICT ===")
    strong=[c for c in carriers if c[1]>0.8]
    if len(strong)==1:
        print(" ONE constant carrier -> PHASE-SHIFT KEYING (or on/off/MFSK).")
        print("   Decode with fldigi: Op Mode -> PSK -> BPSK31, click the carrier.")
        print("   If garbage, try RTTY, then MFSK16. (minimodem will NOT work — it's FSK-only.)")
    elif len(strong)==2:
        d=abs(strong[0][0]-strong[1][0])
        print(f" TWO tones (shift ~{d:.0f} Hz) -> FREQUENCY-SHIFT KEYING.")
        print(f"   minimodem --rx -M {int(max(strong)[0])} -S {int(min(strong)[0])} -f file.wav 1200")
        print("   sweep baud 300/1200/45.45(rtty); or let fldigi auto-detect RTTY.")
    elif len(carriers)>=3:
        print(" MANY tones / staircase -> MFSK or SSTV (image).")
        print("   Try fldigi MFSK16/Olivia; if it sounds like warbling image -> qsstv (SSTV).")
    else:
        print(" No dominant carrier. Likely real audio/music or noise.")
        print("   Look in the spectrogram for painted TEXT; try Sonic Visualiser; or it's")
        print("   a cover for stego (check LSB of samples) rather than a transmission.")

if __name__=="__main__": main()
