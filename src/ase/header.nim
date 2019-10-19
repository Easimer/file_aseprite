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

import common
import streams

type RawHeader = object
  fileSize*: uint32
  # 0xA5E0
  magic: uint16
  # Number of frames
  frames*: uint16
  width*: uint16
  height*: uint16
  # 8bpp = indexed, 16bpp = grayscale, 32bpp = RGBA
  depth*: uint16
  # 1 = layer opacity has valid value
  flags*: uint32
  # Milliseconds between frames, value in frame chunk
  # header overrides this
  speed*: uint16
  # !ignored2DWORDs
  paletteIndexTransparent*: uint8
  # !ignored3Bytes
  numberOfColors*: uint16
  pixelWidth*: uint8
  pixelHeight*: uint8
  gridPosX*: int16
  gridPosY*: int16
  gridWidth*: uint16
  gridHeight*: uint16
  # !padding84ZeroBytes

type Header* = object
  fileSize*: int
  # 0xA5E0
  magic: uint16
  # Number of frames
  frames*: int
  width*: int
  height*: int
  # 8bpp = indexed, 16bpp = grayscale, 32bpp = RGBA
  depth*: int
  # 1 = layer opacity has valid value
  flags: uint32
  layerOpacityValid*: bool
  # Milliseconds between frames, value in frame chunk
  # header overrides this
  speed*: int
  # !ignored2DWORDs
  paletteIndexTransparent*: int
  # !ignored3Bytes
  numberOfColors*: int
  pixelWidth*: int
  pixelHeight*: int
  gridPosX*: int
  gridPosY*: int
  gridWidth*: int
  gridHeight*: int
  # !padding84ZeroBytes

proc readHeader*(stream: Stream): Header =
  result.fileSize = cast[int](stream.readUint32())
  result.magic = stream.readUint16()

  if result.magic != 0xA5E0:
    raise newException(AsepriteError, "Not an aseprite image!")
  
  result.frames = cast[int](stream.readUint16())
  result.width = cast[int](stream.readUint16())
  result.height = cast[int](stream.readUint16())

  result.depth = cast[int](stream.readUint16())
  if not {8, 16, 32}.contains(result.depth):
    raise newException(AsepriteError, "Invalid pixel depth!")

  result.flags = stream.readUint32()
  result.layerOpacityValid = (result.flags and 1) != 0
  result.speed = cast[int](stream.readUint16())
  # Skip two DWORDs
  discard stream.readUint32()
  discard stream.readUint32()
  result.paletteIndexTransparent = cast[int](stream.readUint8())
  # Skip 3 bytes
  for i in 0..2:
    discard stream.readUint8()
  result.numberOfColors = cast[int](stream.readUint16())
  result.pixelWidth = cast[int](stream.readUint8())
  result.pixelHeight = cast[int](stream.readUint8())
  result.gridPosX = cast[int](stream.readInt16())
  result.gridPosY = cast[int](stream.readInt16())
  result.gridWidth = cast[int](stream.readUint16())
  result.gridHeight = cast[int](stream.readUint16())
  # Skip EOH padding
  stream.setPosition(128)
  