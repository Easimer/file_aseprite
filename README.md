# ase

ase is an Aseprite image importer for Nim.

## Supported features of the aseprite format:

* Loading RGBA, greyscale and indexed sprites
* Basic animation information (frame duration, etc.)

### Unsupported features:

* Slices
* ICC Color profile
* Reading palette information from very old sprites (before v1.1)
* Blend mode is ignored
* User data
* Tags
* Information relevant only to the editor are discarded
* Exporting sprites
* Chunk data deprecated/unused by Aseprite

### Supported output formats:

* Every layer separately in R8G8B8A8 pixelformat