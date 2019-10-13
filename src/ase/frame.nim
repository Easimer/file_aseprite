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

import sets
import sequtils
import streams

import miniz

import header

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

type CelType* {.pure.} = enum
  Unknown
  Raw
  Linked
  Compressed

type CelDetails* = ref object
  width*: int
  height*: int
  case kind: CelType
  of Raw:
    pixelData*: seq[uint8]
  of Linked:
    linkedWith*: int
  of Compressed: nil
  else: nil

type CelData* = object
  layerIndex: int
  positionX*: int
  positionY*: int
  opacity: int
  details*: CelDetails

type Layer* = object
  flags: HashSet[LayerFlags]
  visible*: bool
  layerType*: LayerType
  layerChildLevel: int
  blendMode*: LayerBlendMode
  opacity*: int
  name*: string
  cels*: seq[CelData]

type Chunk = ref object
  case kind: ChunkType
  of LayerChunk: layer: Layer
  of CelChunk: celData: CelData
  else: nil

type Frame* = object
    layers*: seq[Layer]

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

converter toCelType(celType: uint16): CelType =
  case celType:
    of 0: CelType.Raw
    of 1: CelType.Linked
    of 2: CelType.Compressed
    else: CelType.Unknown

proc fromString(s: string): seq[uint8] =
  for ch in s:
    result.add(cast[uint8](ch))

proc readCelDetails(stream: FileStream, hdr: Header, chunkSize: uint32): CelData =
  echo("Reading cel")
  result.layerIndex = cast[int](stream.readUint16())
  result.positionX = cast[int](stream.readInt16())
  result.positionY = cast[int](stream.readInt16())
  result.opacity =  cast[int](stream.readUint8())
  result.details = CelDetails(kind: stream.readUint16())
  for i in 0..6:
    discard stream.readUint8()
  echo($result)
  let pixelSize = cast[int](hdr.depth div 8)
  case result.details.kind:
    of CelType.Raw:
      result.details.width = cast[int](stream.readUint16())
      result.details.height = cast[int](stream.readUint16())
      let bufSize = pixelSize * result.details.width * result.details.height
      result.details.pixelData.setLen(bufSize)
      discard stream.readData(addr(result.details.pixelData[0]), bufSize)
    of CelType.Linked:
      result.details.linkedWith = cast[int](stream.readUint16())
    of CelType.Compressed:
      # Redefine as raw
      result.details = CelDetails(kind: CelType.Raw)
      result.details.width = cast[int](stream.readUint16())
      result.details.height = cast[int](stream.readUint16())
      let inflatedSize = pixelSize * result.details.width * result.details.height
      let deflatedSize = chunkSize - 20 # Header is twenty bytes long
      var compressedData = stream.readStr(cast[int](deflatedSize))
      let decompressedData = miniz.uncompress(compressedData)
      assert decompressedData.len() == inflatedSize
      result.details.pixelData = fromString(decompressedData)
      assert result.details.pixelData.len() == inflatedSize
      
    else: discard nil

proc readChunk(stream: FileStream, hdr: Header): Chunk =
  ## Read a single chunk from the stream
  var chunkHeader: ChunkHeader
  chunkHeader.size = stream.readUint32() - 6
  chunkHeader.chunkType = cast[ChunkType](stream.readUint16())
  result = Chunk(kind: chunkHeader.chunkType)
  let seekStart = stream.getPosition()

  case chunkHeader.chunkType:
    of LayerChunk:
      result.layer.flags = stream.readUint16()
      result.layer.layerType = stream.readUint16()
      result.layer.visible = result.layer.flags.contains(LayerFlags.Visible)
      result.layer.layerChildLevel = cast[int](stream.readUint16())
      discard stream.readUint16() # Default layer width in px
      discard stream.readUint16() # Default layer height in px
      result.layer.blendMode = stream.readUint16()
      result.layer.opacity =  cast[int](stream.readUint8())
      for i in 0..2:
        discard stream.readUint8()
      result.layer.name = stream.readStr(cast[int](stream.readUint16()))
    of CelChunk:
      result.celData = readCelDetails(stream, hdr, chunkHeader.size)
    else:
      # Skip chunk
      discard nil
  stream.setPosition(seekStart + cast[int](chunkHeader.size))

proc readFrame*(stream: FileStream, header: Header): Frame =
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
    var chunk = readChunk(stream, header)
    case chunk.kind:
      of LayerChunk:
        result.layers.add(chunk.layer)
      of CelChunk:
        result.layers[chunk.celData.layerIndex].cels.add(chunk.celData)
      else:
        echo("Unknown chunk " & $chunk.kind)