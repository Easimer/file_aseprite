# === Copyright (c) 2019-2020 easimer.net. All rights reserved. ===

import math

## A module implementing a floating-point 4D vector.

type vec4* = object
    ## 4D vector type.
    x*: float32
    y*: float32
    z*: float32
    w*: float32

proc initVec*(x: float32, y: float32, z: float32, w: float32): vec4 =
    ## Creates the vector (`x`, `y`, `z`, `w`).
    result.x = x
    result.y = y
    result.z = z
    result.w = w

proc `[]`*(lhs: vec4, rhs: int): float32 =
    ## Access the `rhs` th component of the vector.
    ## Returns zero when the index is out-of-bounds.
    case rhs:
        of 0: result = lhs.x
        of 1: result = lhs.y
        of 2: result = lhs.z
        of 3: result = lhs.w
        else: result = 0

proc `[]=`*(lhs: var vec4, idx: int, rhs: float32) =
    ## Assign a value to the `idx` th component of the vector.
    ## Does nothing when the index is out-of-bounds.
    case idx:
        of 0:
            lhs.x = rhs
        of 1:
            lhs.y = rhs
        of 2:
            lhs.z = rhs
        of 3:
            lhs.w = rhs
        else: discard nil

proc zeroCheck*(v: var vec4) =
    ## Checks if any of the four components are near zero and sets
    ## those value to zero.
    for i in 0..3:
        if abs(v[i]) < 0.01:
            v[i] = 0

proc dot(lhs: vec4, rhs: vec4): float32 =
    ## Calculates the dot product of two vectors.
    result = lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z + lhs.w * rhs.w

proc len_sq*(v: vec4): float32 =
    ## Calculates the square of the vector's length.
    result = dot(v, v)

proc len*(v: vec4): float32 =
    ## Calculates the vector's length.
    result = sqrt(len_sq(v))

proc `+`*(lhs: vec4, rhs: vec4): vec4 =
    ## Produces the sum of two vectors.
    for i in 0..3:
        result[i] = lhs[i] + rhs[i]

proc `-`*(lhs: vec4, rhs: vec4): vec4 =
    ## Produces the difference of two vectors.
    for i in 0..3:
        result[i] = lhs[i] - rhs[i]

proc `*`*(lhs: float32, rhs: vec4): vec4 =
    ## Returns the the vector in which `rhs`'s components are multiplied
    ## by scalar `lhs`.
    for i in 0..3:
        result[i] = lhs * rhs[i]

proc `*`*(lhs: vec4, rhs: float32): vec4 =
    ## Returns the the vector in which `lhs`'s components are multiplied
    ## by scalar `rhs`.
    result = rhs * lhs

proc `/`*(lhs: vec4, rhs: float32): vec4 =
    ## Returns the the vector in which `lhs`'s components are multiplied
    ## by scalar 1/`rhs`.
    for i in 0..3:
        result[i] = lhs[i] / rhs

proc `+=`*(lhs: var vec4, rhs: vec4) =
    ## Adds the vector `rhs` to `lhs`.
    for i in 0..3:
        lhs[i] = lhs[i] + rhs[i]

proc `-=`*(lhs: var vec4, rhs: vec4) =
    ## Subtracts the vector `rhs` from `lhs`.
    for i in 0..3:
        lhs[i] = lhs[i] - rhs[i]

proc `*=`*(lhs: var vec4, rhs: float32) =
    ## Multiplies the vector `lhs` by `rhs` component-wise.
    for i in 0..3:
        lhs[i] = rhs * lhs[i]

proc `-`*(v: vec4): vec4 =
    ## Negates the vector.
    for i in 0..3:
        result[i] = -v[i]