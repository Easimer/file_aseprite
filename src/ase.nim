# file_aseprite
# Copyright (C) 2019 Daniel Meszaros <easimer@gmail.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.

import streams
import ase/common
import ase/header
import ase/frame

type AsepriteImage = object
  width*: int
  height*: int
  frames: seq[Frame]

proc loadSprite*(path: string): AsepriteImage =
  let file = open(path, fmRead)
  defer: close(file)
  let stream = newFileStream(file)
  let hdr = readHeader(stream)

  result.width = cast[int](hdr.width)
  result.height = cast[int](hdr.height)

  for frameIdx in 0 .. cast[int](hdr.frames-1):
    result.frames.add(readFrame(stream, hdr))

proc rasterizeFrame*(img: AsepriteImage, frame: int): seq[uint8] =
  result.setLen(img.width * img.height * 4)