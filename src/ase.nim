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
  depth*: int
  frames: seq[Frame]

proc loadSprite*(path: string): AsepriteImage =
  let file = open(path, fmRead)
  defer: close(file)
  let stream = newFileStream(file)
  let hdr = readHeader(stream)

  result.width = cast[int](hdr.width)
  result.height = cast[int](hdr.height)
  result.depth = cast[int](hdr.depth)

  for frameIdx in 0 .. cast[int](hdr.frames-1):
    result.frames.add(readFrame(stream, hdr))

proc alphaBlendOver(dst: var seq[uint8], src: seq[uint8], offDst: int, offSrc: int) =
  let
    aR = src[offSrc + 0].float / 255.0
    aG = src[offSrc + 1].float / 255.0
    aB = src[offSrc + 2].float / 255.0
    aA = src[offSrc + 3].float / 255.0
    bR = dst[offDst + 0].float / 255.0
    bG = dst[offDst + 1].float / 255.0
    bB = dst[offDst + 2].float / 255.0
    bA = dst[offDst + 3].float / 255.0
    
  let denom = 1 / (aA + bA * (1 - aA))

  let
    outR = (aR + bR * (1 - aA)) * denom
    outG = (aG + bG * (1 - aA)) * denom
    outB = (aB + bB * (1 - aA)) * denom
    outA = (aA + bA * (1 - aA)) * denom
  
  dst[offDst + 0] = cast[uint8](outR * 128)
  dst[offDst + 1] = cast[uint8](outG * 128)
  dst[offDst + 2] = cast[uint8](outB * 128)
  dst[offDst + 3] = cast[uint8](outA * 128)

proc numberOfFrames*(img: AsepriteImage): int = len(img.frames)
proc numberOfLayers*(img: AsepriteImage, frame: int): int = len(img.frames[frame].layers)

proc blendAlphas[T, U](a: T, b: U): uint8 =
  var A: float = cast[float](a) / 255.0
  var B: float = cast[float](a) / 255.0

  result = cast[uint8](((A + B) / 2) * 255.0)

proc rasterizeLayer*(img: AsepriteImage, frame: int, layerIndex: int): seq[uint8] =
  if frame >= 0 and frame < len(img.frames):
    let pixSize = (img.depth div 8)
    result.setLen(img.width * img.height * pixSize)
    let frame = img.frames[frame]
    if layerIndex >= 0 and layerIndex < len(frame.layers):
      let layer = frame.layers[layerIndex]
      if layer.visible:
        echo(len(layer.cels))
        for cel in layer.cels:
          let imgHeight = img.height
          let imgWidth = img.width
          let celHeight = cel.details.height
          let celWidth = cel.details.width
          
          echo((len(cel.details.pixelData), celWidth * celHeight * pixSize))

          for y in 0 .. celHeight - 1:
            for x in 0 .. celWidth - 1:
              let offY = cel.positionY + y
              let offX = cel.positionX + x
              let offBuffer = (offY * img.width + offX) * pixSize
              let offCel = (y * celWidth + x) * pixSize
              #alphaBlendOver(result, cel.details.pixelData, offBuffer, offCel)
              for b in 0..2:
                result[offBuffer + b] = cel.details.pixelData[offCel + b]
              result[offBuffer + 3] = blendAlphas(cel.details.pixelData[offCel + 3], layer.opacity)
      else:
        echo("layer is invisible")
    else:
      raise newException(IndexError, "Layer index is out of bounds!")
  else:
    raise newException(IndexError, "Frame index is out of bounds!")