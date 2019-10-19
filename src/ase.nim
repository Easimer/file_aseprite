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
  layers: seq[Layer]
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
    let pFrame = readFrame(stream, hdr)
    for layer in pFrame.layers:
      result.layers.add(layer)
    var frame: Frame
    frame.duration = pFrame.duration
    for cel in pFrame.cels:
      frame.cels.add(cel)
    result.frames.add(frame)

proc numberOfFrames*(img: AsepriteImage): int =
  len(img.frames)

proc numberOfLayers*(img: AsepriteImage): int =
  len(img.layers)

proc layerName*(img: AsepriteImage, layer: int): string =
  img.layers[layer].name

proc isLayerGroup*(img: AsepriteImage, layer: int): bool =
  img.layers[layer].layerType == LayerType.Group

proc getLayerLevel*(img: AsepriteImage, layer: int): int =
  img.layers[layer].layerChildLevel

proc isLayerVisible*(img: AsepriteImage, layer: int): bool =
  img.layers[layer].visible

proc getFrameDuration*(img: AsepriteImage, frame: int): int =
  ## Returns the duration of a frame in milliseconds.
  img.frames[frame].duration

proc rasterizeLayerRGBA*(img: AsepriteImage, frame: int, layerIndex: int): seq[uint8] =
  if frame >= 0 and frame < len(img.frames):
    let pixSize = (img.depth div 8)
    result.setLen(img.width * img.height * pixSize)
    let frame = img.frames[frame]
    if layerIndex >= 0 and layerIndex < len(img.layers):
      for cel in frame.cels:
        if cel.layerIndex == layerIndex:
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
              if cel.details.pixelData[offCel + 3] != 0:
                result[offBuffer + 3] = cast[uint8](img.layers[layerIndex].opacity)
    else:
      raise newException(IndexError, "Layer index is out of bounds!")
  else:
    raise newException(IndexError, "Frame index is out of bounds!")

proc rasterizeLayerGreyscale*(img: AsepriteImage, frame: int, layerIndex: int): seq[uint8] =
  if frame >= 0 and frame < len(img.frames):
    let pixSize = 2
    let outPixSize = 4
    result.setLen(img.width * img.height * outPixSize)
    let frame = img.frames[frame]
    if layerIndex >= 0 and layerIndex < len(img.layers):
      for cel in frame.cels:
        if cel.layerIndex == layerIndex:
          let imgHeight = img.height
          let imgWidth = img.width
          let celHeight = cel.details.height
          let celWidth = cel.details.width

          for y in 0 .. celHeight - 1:
            for x in 0 .. celWidth - 1:
              let offY = cel.positionY + y
              let offX = cel.positionX + x
              let offBuffer = (offY * img.width + offX) * outPixSize
              let offCel = (y * celWidth + x) * pixSize
              for b in 0..3:
                result[offBuffer + b] = cel.details.pixelData[offCel + 0]
              if cel.details.pixelData[offCel + 1] != 0:
                result[offBuffer + 3] = cast[uint8](img.layers[layerIndex].opacity)
    else:
      raise newException(IndexError, "Layer index is out of bounds!")
  else:
    raise newException(IndexError, "Frame index is out of bounds!")

proc rasterizeLayer*(img: AsepriteImage, frame: int, layerIndex: int): seq[uint8] =
  case img.depth:
    of 32: rasterizeLayerRGBA(img, frame, layerIndex)
    of 16: rasterizeLayerGreyscale(img, frame, layerIndex)
    else: raise newException(RangeError, "Pixel depth of " & $img.depth & " is not supported!")