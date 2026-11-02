"""Builds assets/animations/splash_logo.json: the GabayBatas tile and mark, animated.

Run: py tools/make_splash_lottie.py assets/animations/splash_logo.json

Timeline (30 fps):
  0-16   tile springs in
  6-30   shield draws from the top down both sides, then fills faintly
  26-48  post rises, base and beam open from the centre
  42-86  pans drop in; the beam swings and settles (pans hang level, like a real balance)
  56-70  gold point pops with a short sparkle; rings ripple out from the tile
  70-92  a light sweep crosses the tile
  96-156 idle loop: gentle sway, gold glow, one soft ring

The tile and ring colours are layer names "tile" and "ring*" so the app can recolour them
(ValueDelegate) and the website preview can swap them.
"""
import json
import math
import sys

FR, OP, LOOP_IN = 30, 156, 96
W = 400
C = W / 2
TILE, RAD = 200, 58          # tile 200px, corner radius like the app's 30/104
S = 2.05                     # 64-grid -> px (mark is ~65% of the tile, as in the app)
GY = 30.25                   # grid y that sits at the tile centre (optical nudge)
WHITE = [1, 1, 1, 1]
GOLD = [0.788, 0.635, 0.153, 1]
TILE_A, TILE_B = [0.184, 0.435, 0.847], [0.102, 0.298, 0.639]   # Royal Blue #2F6FD8 -> #1A4CA3
RING = [0.122, 0.357, 0.769]                                       # #1F5BC4
SOFT = (0.25, 1), (0.6, 0)
SPRING = (0.3, 1), (0.5, 0)


def st(v):
    return {"a": 0, "k": v}


def kf(frames, ease=SOFT):
    out = []
    for i, (t, v) in enumerate(frames):
        v = v if isinstance(v, list) else [v]
        k = {"t": t, "s": v}
        if i < len(frames) - 1:
            n = len(v)
            k["i"] = {"x": [ease[0][0]] * n, "y": [ease[0][1]] * n}
            k["o"] = {"x": [ease[1][0]] * n, "y": [ease[1][1]] * n}
        out.append(k)
    return {"a": 1, "k": out}


def path(verts, ins=None, outs=None, closed=False):
    n = len(verts)
    return {"ty": "sh", "ks": st({"v": verts, "i": ins or [[0, 0]] * n, "o": outs or [[0, 0]] * n, "c": closed})}


def stroke(w, color=WHITE, op=None):
    return {"ty": "st", "c": st(color), "o": op or st(100), "w": w if isinstance(w, dict) else st(w),
            "lc": 2, "lj": 2, "ml": 4}


def fill(color=WHITE, op=None):
    return {"ty": "fl", "c": st(color), "o": op or st(100), "r": 1}


def trim(s, e):
    return {"ty": "tm", "s": s, "e": e, "o": st(0), "m": 1}


def group(items, nm="g"):
    return {"ty": "gr", "nm": nm, "it": items + [{
        "ty": "tr", "p": st([0, 0]), "a": st([0, 0]), "s": st([100, 100]),
        "r": st(0), "o": st(100), "sk": st(0), "sa": st(0)}]}


_ind = [0]


def layer(name, shapes, a=(0, 0), p=(C, C), s=None, r=None, o=None, masks=None, parent=None):
    _ind[0] += 1
    L = {"ddd": 0, "ind": _ind[0], "ty": 4, "nm": name, "sr": 1, "ao": 0, "bm": 0,
         "ip": 0, "op": OP, "st": 0,
         "ks": {"a": st([a[0], a[1], 0]), "p": p if isinstance(p, dict) else st([p[0], p[1], 0]),
                "s": s or st([100, 100, 100]), "r": r or st(0), "o": o or st(100)},
         "shapes": shapes}
    if masks:
        L["hasMask"] = True
        L["masksProperties"] = masks
    if parent:
        L["parent"] = parent
    return L


def grid_to_px(x, y):
    return C + (x - 32) * S, C + (y - GY) * S


def mark_layer(name, shapes, anchor, **kw):
    """A layer drawn in 64-grid units."""
    kw.setdefault("s", st([S * 100, S * 100, 100]))
    return layer(name, shapes, a=anchor, p=grid_to_px(*anchor), **kw)


def rounded_rect(half, r):
    k = 0.5523 * r
    v = [[-half + r, -half], [half - r, -half], [half, -half + r], [half, half - r],
         [half - r, half], [-half + r, half], [-half, half - r], [-half, -half + r]]
    i = [[-k, 0], [0, 0], [0, -k], [0, 0], [k, 0], [0, 0], [0, k], [0, 0]]
    o = [[0, 0], [k, 0], [0, 0], [0, k], [0, 0], [-k, 0], [0, 0], [0, -k]]
    return {"v": v, "i": i, "o": o, "c": True}


def pan_shape(x):
    return path([[x - 4.5, 34], [x + 4.5, 34]], ins=[[3, 4], [0, 0]], outs=[[0, 0], [-3, 4]], closed=True)


# --- beam angle over time (degrees, + = clockwise) -------------------------------
BEAM = [(48, 0), (58, -9), (68, 6), (77, -3), (86, 0),
        (LOOP_IN, 0), (111, -2.5), (126, 0), (141, 2.5), (OP, 0)]


def beam_rot():
    return kf(BEAM, SOFT)


def pan_pos(side):
    """Pan hangs from the beam end: follow its height (dy = side*11*sin a), drop in first."""
    x0, y0 = grid_to_px(32 + side * 11, 25)
    frames = [(42, [x0, y0 - 8 * S, 0]), (50, [x0, y0, 0])]
    for t, ang in BEAM[1:]:
        a = math.radians(ang)
        frames.append((t, [x0 + side * 11 * (math.cos(a) - 1) * S, y0 + side * 11 * math.sin(a) * S, 0]))
    return kf(frames, SOFT)


layers = []

# sparkle rays around the gold point
rays = []
for deg in (-90, -45, -135, 0, 180):
    a = math.radians(deg)
    p1 = [32 + 5 * math.cos(a), 20 + 5 * math.sin(a)]
    p2 = [32 + 9.5 * math.cos(a), 20 + 9.5 * math.sin(a)]
    rays.append(path([p1, p2]))
layers.append(mark_layer("sparkle", [group(rays + [
    trim(kf([(58, 0), (70, 100)]), kf([(56, 0), (66, 100)])), stroke(1.5, GOLD)])], (32, 20)))

# gold point: pop, then a glow pulse in the loop
layers.append(mark_layer("point", [group([{"ty": "el", "p": st([32, 20]), "s": st([6, 6])}, fill(GOLD)])],
                         (32, 20), s=kf([(54, [0, 0, 100]), (62, [S * 140, S * 140, 100]),
                                         (70, [S * 100, S * 100, 100])], SPRING)))
layers.append(mark_layer("glow", [group([{"ty": "el", "p": st([32, 20]), "s": st([6, 6])}, fill(GOLD)])],
                         (32, 20),
                         s=kf([(LOOP_IN, [S * 100] * 2 + [100]), (126, [S * 280] * 2 + [100]),
                               (126.01, [S * 100] * 2 + [100]), (OP, [S * 280] * 2 + [100])]),
                         o=kf([(LOOP_IN, 0), (98, 45), (126, 0), (126.01, 0), (128, 45), (OP, 0)])))

# pans with their hangers (stay level, follow the beam ends)
for side, nm in ((-1, "pan L"), (1, "pan R")):
    x = 32 + side * 11
    layers.append(layer(nm, [
        group([path([[x, 25], [x - 3.5, 34]]), path([[x, 25], [x + 3.5, 34]]), stroke(2.8)]),
        group([pan_shape(x), fill()]),
    ], a=(x, 25), p=pan_pos(side), s=st([S * 100, S * 100, 100]),
        o=kf([(42, 0), (50, 100)])))

# beam opens from the centre, then swings
layers.append(mark_layer("beam", [group([
    path([[21, 25], [43, 25]]), trim(kf([(36, 50), (48, 0)]), kf([(36, 50), (48, 100)])), stroke(2.8)])],
    (32, 25), r=beam_rot()))

# post rises, base opens
layers.append(mark_layer("stand", [
    group([path([[32, 44], [32, 21]]), trim(st(0), kf([(26, 0), (40, 100)])), stroke(2.8)]),
    group([path([[25.5, 45.5], [38.5, 45.5]]), trim(kf([(26, 50), (38, 0)]), kf([(26, 50), (38, 100)])),
           stroke(2.8)]),
], (32, 32), o=kf([(25, 0), (26, 100)])))

# shield draws down both sides from the top, then a faint fill
left = path([[32, 5], [11, 12.5], [11, 30], [32, 59]],
            ins=[[0, 0], [0, 0], [0, 0], [-12, -6.5]], outs=[[0, 0], [0, 0], [0, 13.5], [0, 0]])
right = path([[32, 5], [53, 12.5], [53, 30], [32, 59]],
             ins=[[0, 0], [0, 0], [0, 0], [12, -6.5]], outs=[[0, 0], [0, 0], [0, 13.5], [0, 0]])
whole = path([[32, 5], [53, 12.5], [53, 30], [32, 59], [11, 30], [11, 12.5]],
             ins=[[0, 0], [0, 0], [0, 0], [12, -6.5], [0, 13.5], [0, 0]],
             outs=[[0, 0], [0, 0], [0, 13.5], [-12, -6.5], [0, 0], [0, 0]], closed=True)
layers.append(mark_layer("shield", [
    group([left, right, trim(st(0), kf([(6, 0), (30, 100)])), stroke(3.6)]),
    group([whole, fill(WHITE, kf([(26, 0), (40, 12)]))]),
], (32, 32), o=kf([(5, 0), (6, 100)])))

# light sweep across the tile: the band moves inside a fixed layer masked to the tile
band ={"ty": "gr", "nm": "band", "it": [
    {"ty": "rc", "p": st([0, 0]), "s": st([46, 420]), "r": st(0)},
    fill(WHITE, st(22)),
    {"ty": "tr", "p": kf([(70, [-230, 0]), (92, [230, 0])], ((0.4, 1), (0.6, 0))), "a": st([0, 0]),
     "s": st([100, 100]), "r": st(24), "o": st(100), "sk": st(0), "sa": st(0)}]}
layers.append(layer("sweep", [band], a=(0, 0), p=(C, C),
                    masks=[{"inv": False, "mode": "a", "pt": st(rounded_rect(TILE / 2, RAD)),
                            "o": st(100), "x": st(0), "nm": "tile"}]))

# the tile itself
TILE_SCALE = kf([(0, [0, 0, 100]), (10, [108, 108, 100]), (16, [100, 100, 100])], SPRING)
layers.append(layer("tile", [group([
    {"ty": "rc", "p": st([0, 0]), "s": st([TILE, TILE]), "r": st(RAD)},
    {"ty": "gf", "o": st(100), "r": 1, "bm": 0, "t": 1, "nm": "tile fill",
     "g": {"p": 2, "k": st([0] + TILE_A + [1] + TILE_B)},
     "s": st([-TILE / 2, -TILE / 2]), "e": st([TILE / 2, TILE / 2])}])],
    s=TILE_SCALE, o=kf([(0, 0), (6, 100)])))

# soft shadow (stacked faint ellipses; Lottie has no blur that works in every player)
shadow_items = [{"ty": "el", "p": st([0, 0]), "s": st([120 + 16 * i, 14 + 5 * i])} for i in range(7)]
layers.append(layer("shadow", [group([e, fill([0.05, 0.13, 0.26, 1], st(3.2))]) for e in shadow_items],
                    p=(C, C + TILE / 2 + 6), s=TILE_SCALE, o=kf([(8, 0), (16, 100)])))

# rings rippling out from the tile (behind it)
def ring(name, t0, t1):
    return layer(name, [group([
        {"ty": "rc", "p": st([0, 0]), "s": st([TILE, TILE]), "r": st(RAD)},
        stroke(kf([(t0, 4), (t1, 1)]), RING + [1])])],
        s=kf([(t0, [100, 100, 100]), (t1, [185, 185, 100])], ((0.2, 1), (0.4, 0))),
        o=kf([(t0, 0), (t0 + 2, 45), (t1, 0)]))


layers.append(ring("ring 1", 58, 92))
layers.append(ring("ring 2", 66, 100))
layers.append(ring("ring 3", 104, 146))

anim = {"v": "5.7.4", "fr": FR, "ip": 0, "op": OP, "w": W, "h": W, "nm": "GabayBatas splash",
        "ddd": 0, "assets": [], "layers": layers,
        "markers": [{"tm": 0, "cm": "intro", "dr": LOOP_IN}, {"tm": LOOP_IN, "cm": "loop", "dr": OP - LOOP_IN}]}

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(anim, f, separators=(",", ":"))
print("wrote", sys.argv[1], len(layers), "layers")
