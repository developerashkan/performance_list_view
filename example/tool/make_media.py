"""Builds the hero GIF from the capture test's frames.

Run from example/ after:
    flutter test test/screenshots_test.dart --dart-define=CAPTURE=true
"""
import glob
import os

from PIL import Image

OUT = os.path.join('..', 'assets', 'screenshots')


def gif():
    files = sorted(glob.glob(os.path.join('build', 'frames', 'f*.png')))
    w = 360
    frames = []
    for f in files:
        im = Image.open(f).convert('RGB')
        frames.append(im.resize((w, round(im.height * w / im.width)), Image.LANCZOS))
    # One shared palette for every frame: no flicker between frames.
    picks = frames[:: max(1, len(frames) // 6)][:6]
    strip = Image.new('RGB', (w, frames[0].height * len(picks)))
    for i, f in enumerate(picks):
        strip.paste(f, (0, i * frames[0].height))
    palette = strip.quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    q = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
    durations = [83] * len(q)
    durations[-1] = 1600  # hold the finished answer
    path = os.path.join(OUT, 'hero.gif')
    q[0].save(path, save_all=True, append_images=q[1:], duration=durations, loop=0, optimize=True, disposal=1)
    print('gif', len(q), 'frames', os.path.getsize(path) // 1024, 'KB')


if __name__ == '__main__':
    gif()
    for f in sorted(glob.glob(os.path.join(OUT, '*.*'))):
        print(f, os.path.getsize(f) // 1024, 'KB')
