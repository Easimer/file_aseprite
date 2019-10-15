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

type AsepriteImage* = ref object
  width*: int
  height*: int
  depth*: int
  frames: seq[Frame]

proc loadSprite*(path: string): AsepriteImage =
  new(result)
  let file = open(path, fmRead)
  defer: close(file)
  let stream = newFileStream(file)
  let hdr = readHeader(stream)

  result.width = hdr.width
  result.height = hdr.height
  result.depth = hdr.depth

  for frameIdx in 0 .. hdr.frames - 1:
    result.frames.add(readFrame(stream, hdr))

proc numberOfFrames*(img: AsepriteImage): int = len(img.frames)
proc numberOfLayers*(img: AsepriteImage, frame: int): int = len(img.frames[frame].layers)
proc layerName*(img: AsepriteImage, frame: int, layer: int): string = img.frames[frame].layers[layer].name
proc isLayerGroup*(img: AsepriteImage, frame: int, layer: int): bool = img.frames[frame].layers[layer].layerType == LayerType.Group
proc getLayerLevel*(img: AsepriteImage, frame: int, layer: int): int = img.frames[frame].layers[layer].layerChildLevel

proc rasterizeLayer*(img: AsepriteImage, frame: int, layerIndex: int): seq[uint8] =
  if frame >= 0 and frame < len(img.frames):
    let pixSize = (img.depth div 8)
    result.setLen(img.width * img.height * pixSize)
    let frame = img.frames[frame]
    if layerIndex >= 0 and layerIndex < len(frame.layers):
      let layer = frame.layers[layerIndex]
      if layer.visible:
        for cel in layer.cels:
          let imgHeight = img.height
          let imgWidth = img.width
          let celHeight = cel.details.height
          let celWidth = cel.details.width

          for y in 0 .. celHeight - 1:
            for x in 0 .. celWidth - 1:
              let offY = cel.positionY + y
              let offX = cel.positionX + x
              let offBuffer = (offY * img.width + offX) * pixSize
              let offCel = (y * celWidth + x) * pixSize
              for b in 0..3:
                result[offBuffer + b] = cel.details.pixelData[offCel + b]
              # TODO: This is fine if a layer only has one cel
              if cel.details.pixelData[offCel + 3] != 0:
                result[offBuffer + 3] = cast[uint8](layer.opacity)
    else:
      raise newException(IndexError, "Layer index is out of bounds!")
  else:
    raise newException(IndexError, "Frame index is out of bounds!")