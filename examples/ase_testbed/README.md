# ase testbed
A program used to test/demonstrate the capabilities of the library. See gfx.nim
on how a sprite might be loaded.

In this example the frames are stored in a sequence (Sprite.frames). The layer
hierarchy is stored in the rootGroup variable (SpriteFrame.rootGroup) of every
frame. Every layer either contains image data or not (layer groups). A normal
layer stores a handle to the OpenGL texture storing it's image data.

The layer hierarchy is built up by the createLayerGroup procedure. It uses the
rasterizeLayer procedure in the library to create a seq[uint8] containing the
pixel data which it then uploads to the GPU.

The sprites are drawn layer by layer, by iterating over every layer. Only
visible layers are drawn. Layers may be marked invisible in the aseprite file or
by the game code (setLayerVisible). An invisible layer group is skipped
entirely.
