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

proc loadSprite*(path: string): AsepriteImage =
  let file = open(path, fmRead)
  defer: close(file)
  let stream = newFileStream(file)
  let hdr = readHeader(stream)

  for frameIdx in 0 .. cast[int](hdr.frames-1):
    echo("Frame #" & $frameIdx)
    discard readFrame(stream)