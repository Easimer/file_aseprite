# === Copyright (c) 2019-2020 easimer.net. All rights reserved. ===

import math
import vector

## A module implementing a 4x4 floating-point matrix.

type matrix4* = array[16, float32]
    ## A 4x4 floating point matrix.

proc `*`*(lhs: matrix4, rhs: vec4): vec4 =
    ## Calculates the product of a matrix and a vector.
    result.x = 0
    result.y = 0
    result.z = 0
    result.w = 0
    for col in 0..3:
        result.x += lhs[col * 4 + 0] * rhs[col]
        result.y += lhs[col * 4 + 1] * rhs[col]
        result.z += lhs[col * 4 + 2] * rhs[col]
        result.w += lhs[col * 4 + 3] * rhs[col]

proc `*`*(lhs: matrix4, rhs: matrix4): matrix4 =
    ## Calculates the product of two matrices.
    for row in 0..3:
        for col in 0..3:
            result[col * 4 + row] = 0
            for i in 0..3:
                result[col * 4 + row] += lhs[i * 4 + row] * rhs[col * 4 + i]
    
proc identity(): matrix4 =
    ## Creates an identity matrix.
    result[0] = 1
    result[5] = 1
    result[10] = 1
    result[15] = 1

proc translate*(v: vec4): matrix4 =
    ## Creates a transformation matrix translating a point from origin to `v`.
    result = identity()
    result[12] = v[0]
    result[13] = v[1]
    result[14] = v[2]

proc scale*(x: float, y: float, z: float): matrix4 =
    ## Creates a transformation matrix scaling across by the X-axis by `x`,
    ## the Y-axis by `y` and the Z-axis by `z`.
    result[0] = x
    result[5] = y
    result[10] = z
    result[15] = 1

proc scale*(v: vec4): matrix4 =
    ## Creates a transformation matrix scaling across by the X-axis by `v.x`,
    ## the Y-axis by `v.y` and the Z-axis by `v.z`.
    scale(v.x, v.y, v.z)

proc value_ptr*(mat: matrix4): array[16, float32] =
    ## Returns the underlying column-major array of the matrix.
    cast[array[16, float32]](mat)

proc rotateZ*(theta: float32): matrix4 =
    ## Creates a transformation matrix rotating around the Z-axis by
    ## `theta` radians.
    result = identity()
    result[0] = cos(theta)
    result[1] = sin(theta)
    result[4] = -sin(theta)
    result[5] = cos(theta)