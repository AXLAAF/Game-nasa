"""Separa un tema en 4 capas para la musica procedural y las exporta en OGG Vorbis.

Capas (mascaras suaves sobre la STFT; las 4 suman el original):
  perc   percusion (HPSS, parte percusiva)
  bass   parte armonica por debajo de BASS_HZ
  pads   parte armonica por encima de BASS_HZ (acordes y colchones sostenidos)
  tex    residuo entre armonico y percusivo (textura: pulsos, barridos, transitorios tonales)

Uso: python tools/split_stems.py <tema.mp3> <carpeta_salida>
Requiere numpy, librosa, soundfile y ffmpeg en el PATH.
"""
import pathlib
import subprocess
import sys
import tempfile

import librosa
import numpy as np
import soundfile as sf

SR = 44100
N_FFT = 4096
HOP = 1024
BASS_HZ = 180.0
MARGIN = 2.0  # margen > 1 deja un residuo (la capa tex) entre armonico y percusivo


def masks(y_mono: np.ndarray) -> dict:
    s = np.abs(librosa.stft(y_mono, n_fft=N_FFT, hop_length=HOP))
    h, p = librosa.decompose.hpss(s, margin=MARGIN, mask=True)
    r = np.clip(1.0 - h - p, 0.0, 1.0)
    low = (librosa.fft_frequencies(sr=SR, n_fft=N_FFT) < BASS_HZ)[:, None].astype(float)
    return {"perc": p, "bass": h * low, "pads": h * (1.0 - low), "tex": r}


def split(src: str, out_dir: str) -> dict:
    y, _ = librosa.load(src, sr=SR, mono=False)
    y = np.atleast_2d(y)
    m = masks(y.mean(axis=0))  # misma mascara en ambos canales para no mover la imagen estereo
    out = pathlib.Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stems = {}
    for name, mask in m.items():
        chans = [librosa.istft(librosa.stft(ch, n_fft=N_FFT, hop_length=HOP) * mask,
                               hop_length=HOP, length=y.shape[1]) for ch in y]
        stems[name] = np.stack(chans)
    # Autocomprobacion: la suma de capas debe reconstruir el original (error muy por debajo de la senal).
    err = np.max(np.abs(sum(stems.values()) - y))
    assert err < 1e-3, f"las capas no suman el original (error {err})"
    with tempfile.TemporaryDirectory() as tmp:
        for name, data in stems.items():
            wav = pathlib.Path(tmp) / f"{name}.wav"
            sf.write(wav, data.T, SR, subtype="FLOAT")
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "4",
                            str(out / f"{name}.ogg")], check=True)
    return {"src": src, "out": str(out), "reconstruction_error": float(err)}


if __name__ == "__main__":
    print(split(sys.argv[1], sys.argv[2]))
