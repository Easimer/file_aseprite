# === Copyright (c) 2019-2020 easimer.net. All rights reserved. ===

import sdl2
import vector
import gfx
import ase
import draw_info

var exit = false

var v: int = 0
var spriteRGBAAnim: sprite_id
var spriteGreyscaleAnim: sprite_id
var spriteIndexedAnim: sprite_id

proc sighandler() {.noconv.} =
    exit = true

proc spriteToDisplay(v: int): sprite_id =
    case v:
        of 0: spriteRGBAAnim
        of 1: spriteGreyscaleAnim
        of 2: spriteIndexedAnim
        else: spriteRGBAAnim

proc displaySprite(s: sprite_id): seq[draw_info] =
    result.drawAt(s, vec4())

proc keypressCallback(released: bool, kv: int) =
    if released:
        if kv == K_a:
            v = (v - 1) mod 3
        elif kv == K_d:
            v = (v + 1) mod 3
        else:
            echo(kv)
        echo(v)

proc main() =
    var g: Gfx

    setControlCHook(sighandler)

    g.init()

    spriteRGBAAnim = g.load_sprite("data/rgba_anim.aseprite")
    spriteGreyscaleAnim = g.load_sprite("data/gs_anim.aseprite")
    spriteIndexedAnim = g.load_sprite("data/indexed_anim.aseprite")

    var frame_start = sdl2.getPerformanceCounter()
    var frame_end = frame_start
    while not exit:
        let dt: float = float(frame_end - frame_start) / sdl2.getPerformanceFrequency().float
        frame_start = sdl2.getPerformanceCounter()
        g.clear()
        exit = g.update(keypressCallback)
        let s = spriteToDisplay(v)
        discard g.stepAnimation(s, dt)
        g.draw(displaySprite(s))
        g.flip()
        frame_end = sdl2.getPerformanceCounter()

    destroy(g)

main()
