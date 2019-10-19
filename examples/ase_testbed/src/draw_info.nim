# === Copyright (c) 2019-2020 easimer.net. All rights reserved. ===

import vector

type sprite_id* = distinct uint32

type draw_info* = object
    position*: vec4
    rotation*: float32
    sprite*: sprite_id
    width*: float32
    height*: float32

proc drawAt*(dis: var seq[draw_info], sprite: sprite_id, position: vec4, width: float32 = 1, height: float32 = 1, rotation: float32 = 0) =
    dis.add(draw_info(
        position: position,
        rotation: rotation,
        sprite: sprite,
        width: width,
        height: height
        )
    )