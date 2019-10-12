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
import sets

type FrameHeader* = object
  length: uint32
  magic: uint16
  chunkCountOld: uint16
  duration: uint16
  # !skip 2 bytes
  chunkCount: uint32

type ChunkType = enum
  ## On-disk chunk identifier
  ## Also used in the Chunk type
  UnknownChunk = 0x0000
  OldPaletteChunk = 0x0004 # Not supported yet
  OldPaletteChunk2 = 0x0011 # Not supported yet
  LayerChunk = 0x2004
  CelChunk = 0x2005 # Not supported yet
  CelExtraChunk = 0x2006 # Not supported yet
  ColorProfileChunk = 0x2007 # Not supported yet
  MaskChunk = 0x2016 # Not supported
  PathChunk = 0x2017 # Not supported
  TagsChunk = 0x2018 # Not supported yet
  PaletteChunk = 0x2019 # Not supported yet
  UserDataChunk = 0x2020 # Ignored on import
  SliceChunk = 0x2022

type ChunkHeader* = object
  size: uint32
  chunkType: ChunkType
  # !chunk data follows

type LayerFlags* {.pure.} = enum
  Visible
  Editable
  LockMovement
  Background
  PreferLinkedCels
  DisplayCollapsed
  ReferenceLayer

type LayerType* {.pure.} = enum
  Unknown
  Normal
  Group

type LayerBlendMode* {.pure.} = enum
  Unknown
  Normal
  Multiply
  Screen
  Overlay
  Darken
  Lighten
  ColorDodge
  ColorBurn
  HardLight
  SoftLight
  Difference
  Exclusion
  Hue
  Saturation
  Color
  Luminosity
  Addition
  Subtract
  Divide

type Layer = object
  flags: HashSet[LayerFlags]
  layerType: LayerType
  layerChildLevel: int
  blendMode: LayerBlendMode
  opacity: float
  name: string

type Chunk = ref object
  case kind: ChunkType
  of LayerChunk: layer: Layer
  else: nil

type Frame = object
    layers: seq[Layer]

converter toLayerFlags(flags: uint16): HashSet[LayerFlags] =
  ## Converts a bitfield to a set of LayerFlags
  result.init()
  if (flags and 1) != 0:
    result.incl(LayerFlags.Visible)
  if (flags and 2) != 0:
    result.incl(LayerFlags.Editable)
  if (flags and 4) != 0:
    result.incl(LayerFlags.LockMovement)
  if (flags and 8) != 0:
    result.incl(LayerFlags.Background)
  if (flags and 16) != 0:
    result.incl(LayerFlags.PreferLinkedCels)
  if (flags and 32) != 0:
    result.incl(LayerFlags.DisplayCollapsed)
  if (flags and 64) != 0:
    result.incl(LayerFlags.ReferenceLayer)

converter toLayerType(layerType: uint16): LayerType =
  case layerType:
    of 0: LayerType.Normal
    of 1: LayerType.Group
    else: LayerType.Unknown

converter toBlendMode(blendMode: uint16): LayerBlendMode =
  case blendMode:
    of 0: LayerBlendMode.Normal
    of 1: LayerBlendMode.Multiply
    of 2: LayerBlendMode.Screen
    of 3: LayerBlendMode.Overlay
    of 4: LayerBlendMode.Darken
    of 5: LayerBlendMode.Lighten
    of 6: LayerBlendMode.ColorDodge
    of 7: LayerBlendMode.ColorBurn
    of 8: LayerBlendMode.HardLight
    of 9: LayerBlendMode.SoftLight
    of 10: LayerBlendMode.Difference
    of 11: LayerBlendMode.Exclusion
    of 12: LayerBlendMode.Hue
    of 13: LayerBlendMode.Saturation
    of 14: LayerBlendMode.Color
    of 15: LayerBlendMode.Luminosity
    of 16: LayerBlendMode.Addition
    of 17: LayerBlendMode.Subtract
    of 18: LayerBlendMode.Divide
    else: LayerBlendMode.Unknown

proc readChunk(stream: FileStream): Chunk =
  ## Read a single chunk from the stream
  var chunkHeader: ChunkHeader
  chunkHeader.size = stream.readUint32() - 6
  chunkHeader.chunkType = cast[ChunkType](stream.readUint16())
  result = Chunk(kind: chunkHeader.chunkType)

  case chunkHeader.chunkType:
    of LayerChunk:
      result.layer.flags = stream.readUint16()
      result.layer.layerType = stream.readUint16()
      result.layer.layerChildLevel = cast[int](stream.readUint16())
      discard stream.readUint16() # Default layer width in px
      discard stream.readUint16() # Default layer height in px
      result.layer.blendMode = stream.readUint16()
      result.layer.opacity =  stream.readUint8().float / 255.0f
      for i in 0..2:
        discard stream.readUint8()
      result.layer.name = stream.readStr(cast[int](stream.readUint16()))
    else:
      # Skip chunk
      echo("Skipping " & $chunkHeader.size)
      stream.setPosition(stream.getPosition() + cast[int](chunkHeader.size))

proc readFrame*(stream: FileStream): Frame =
  var hdr: FrameHeader
  hdr.length = stream.readUint32()
  hdr.magic = stream.readUint16()
  hdr.chunkCountOld = stream.readUint16()
  hdr.duration = stream.readUint16()
  discard stream.readUint16()
  hdr.chunkCount = stream.readUint32()

  let chunkCount =
    case hdr.chunkCount
    of 0: cast[uint32](hdr.chunkCountOld)
    else: hdr.chunkCount
  
  for chunkIdx in 0..chunkCount-1:
    let chunk = readChunk(stream)
    case chunk.kind:
      of LayerChunk:
        result.layers.add(chunk.layer)
      else:
        echo("Unknown chunk")
    