# === Copyright (c) 2019-2020 easimer.net. All rights reserved. ===

import draw_info
import gl
import sdl2
import winmgr
import vector
import matrix
import stb_image/read as stbi
import ase
import strutils
import tables

type ShaderProgram = object
    shader_vertex: GLshaderID
    shader_fragment: GLshaderID
    program: GLprogramID

type
    SpriteLayerKind {.pure.} = enum
        Image
        Group

    SpriteLayer = ref object
        visible: bool
        name: string
        case kind: SpriteLayerKind
        of SpriteLayerKind.Image:
            textureID: GLtexture
        of SpriteLayerKind.Group:
            group: seq[SpriteLayer]

type SpriteFrame = ref object
    rootGroup: SpriteLayer
    duration: int
    layerNameCache: Table[string, SpriteLayer]

type Sprite = object
    frames: seq[SpriteFrame]
    currentFrame: int

type
    SpriteInstanceState = object
        visible: bool
    
    SpriteInstance = ref object
        baseSprite: int
        currentFrame: int
        currentTime: int
        layerStates: Table[string, SpriteInstanceState]

type Gfx* = ref object
    wnd: window
    quad: GLVAO
    shaderSprite: ShaderProgram
    sprites: seq[Sprite]
    spriteFilenames: Table[string, int]
    spriteInstances: seq[SpriteInstance]
    mat_view: matrix4

proc debugCallback(source: GLenum, msgtype: GLenum, id: GLuint, severity: GLenum, length: GLsizei, message: cstring, userParam: pointer) {.cdecl.} =
    echo "OpenGL: " & $message

proc destroy(shader: ShaderProgram) =
    gl.deleteProgram(shader.program)
    # Shaders constituing this program are automatically freed by the driver

proc loadShaderProgramFromFile(path_vertex: string, path_fragment: string): ShaderProgram =
    var file_vertex, file_fragment: File
    defer: file_vertex.close()
    defer: file_fragment.close()
    if file_vertex.open(path_vertex) and file_fragment.open(path_fragment):
        result.shader_vertex = gl.createShader(GL_VERTEX_SHADER)
        result.shader_fragment = gl.createShader(GL_FRAGMENT_SHADER)
        let src_vertex = cast[string](file_vertex.readAll())
        let src_fragment = cast[string](file_fragment.readAll())
        let csrc_vertex : cstring = src_vertex
        let csrc_fragment : cstring = src_fragment
        let pcsrc_vtx : ptr cstring = csrc_vertex.unsafeAddr
        let pcsrc_frag : ptr cstring = csrc_fragment.unsafeAddr
        result.shader_vertex.shaderSource(1, pcsrc_vtx, nil)
        result.shader_fragment.shaderSource(1, pcsrc_frag, nil)
        result.shader_vertex.compileShader()
        result.shader_fragment.compileShader()
        result.program = gl.createProgram()
        result.program.attachShader(result.shader_vertex)
        result.program.attachShader(result.shader_fragment)
        result.program.linkProgram()

        var status : array[1, GLint]
        result.program.getProgram(GL_LINK_STATUS, status)
        assert(status[0] > 0)
    else:
        echo "Failed to load shaders " & path_vertex & " and/or " & path_fragment
    
proc useProgram(p: ShaderProgram) =
    gl.useProgram(p.program)

proc createQuad(): GLVAO =
    var vertices: array[18, GLfloat] = [
        -0.5f, -0.5f, 0.0f,
        0.5f, -0.5f, 0.0f,
        -0.5f,  0.5f, 0.0f,
        -0.5f,  0.5f, 0.0f,
        0.5f,  0.5f, 0.0f,
        0.5f,  -0.5f, 0.0f,
    ]

    var uv: array[12, GLfloat] = [
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
        1.0f, 1.0f,
    ]

    var buffers: array[2, GLVBO]
    var arrays: array[1, GLVAO]

    gl.genVertexArrays(1, addr arrays)
    gl.bindVertexArray(arrays[0])

    gl.genBuffers(2, addr buffers)

    gl.bindBuffer(GL_ARRAY_BUFFER, buffers[0])
    gl.bufferData(GL_ARRAY_BUFFER, cast[GLintptr](sizeof(vertices)), addr(vertices), GL_STATIC_DRAW)
    gl.vertexAttribPointer(0, 3, GL_EFLOAT, GL_FALSE, cast[GLsizei](3 * sizeof(GLfloat)), nil)
    gl.enableVertexAttribArray(0)

    gl.bindBuffer(GL_ARRAY_BUFFER, buffers[1])
    gl.bufferData(GL_ARRAY_BUFFER, cast[GLintptr](sizeof(uv)), addr(uv), GL_STATIC_DRAW)
    gl.vertexAttribPointer(1, 2, GL_EFLOAT, GL_FALSE, cast[GLsizei](2 * sizeof(GLfloat)), nil)
    gl.enableVertexAttribArray(1)
    
    arrays[0]

var gGfx*: Gfx

proc init*(g: var Gfx) =
    new(g)
    g.wnd = openWindow(640, 480)
    gl.load_functions(glGetProcAddress)
    gl.enable(GL_DEBUG_OUTPUT)
    gl.debugMessageCallback(debugCallback, nil)
    gl.clearColor(0.392, 0.584, 0.929, 1.0)
    gl.viewport(0, 0, 640, 480)
    gl.enable(GL_BLEND)
    gl.blendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

    g.quad = createQuad()
    g.shaderSprite = loadShaderProgramFromFile("core/shaders/sprite.vrtx.glsl", "core/shaders/sprite.frag.glsl")

    g.mat_view = translate(initVec(0, 0, 0, 0))

    gGfx = g
    

proc destroy*(g: var Gfx) =
    destroy(g.shaderSprite)
    closeWindow(g.wnd)

proc clear*(g: var Gfx) =
    gl.clear(GL_COLOR_BUFFER_BIT)

proc flip*(g: var Gfx) =
    swapWindow(g.wnd)

proc update*(g: var Gfx, callback: proc(released: bool, kv: int)): bool =
    processEvents(g.wnd, callback)

proc move_camera*(g: var Gfx, pos: vec4) =
    g.mat_view = translate(-pos)

proc isLayerVisibleInInstance(spriteInstance: SpriteInstance, layer: SpriteLayer): bool =
    assert layer != nil
    ## Determines whether a layer in a sprite instance is visible or not.
    if layer.name in spriteInstance.layerStates:
        spriteInstance.layerStates[layer.name].visible
    else:
        # Fallback to what the .aseprite file says about the layer
        layer.visible

proc findLayerInGroup(group: SpriteLayer, name: string): SpriteLayer =
    assert group.kind == SpriteLayerKind.Group
    for layer in group.group:
        if layer.name == name:
            return layer
        else:
            case layer.kind:
                of SpriteLayerKind.Image: discard nil
                of SpriteLayerKind.Group:
                    let res = findLayerInGroup(layer, name)
                    if res != nil: return res
                

proc findLayerByName(sprite: Sprite, name: string): SpriteLayer =
    if not (name in sprite.frames[sprite.currentFrame].layerNameCache):
        result = findLayerInGroup(sprite.frames[sprite.currentFrame].rootGroup, name)
        if result != nil:
            sprite.frames[sprite.currentFrame].layerNameCache[name] = result
        else:
            raise newException(IndexError, "Couldn't find layer '$1'!" % (name))
    else:
        result = sprite.frames[sprite.currentFrame].layerNameCache[name]
        

proc drawGroup(spriteInstance: SpriteInstance, g: SpriteLayer) =
    ## Draw a layer-group hierarchy recursively
    assert g.kind == SpriteLayerKind.Group

    for layer in g.group:
        if isLayerVisibleInInstance(spriteInstance, layer):
            case layer.kind:
                of SpriteLayerKind.Group:
                    drawGroup(spriteInstance, layer)
                of SpriteLayerKind.Image:
                    gl.bindTexture(GL_TEXTURE_2D, layer.textureID)
                    gl.drawArrays(GL_TRIANGLES, 0, 6)

proc draw*(g: var Gfx, diseq: seq[draw_info]) =
    gl.bindVertexArray(g.quad)
    g.shaderSprite.useProgram()
    let mvp_location = g.shaderSprite.program.getUniformLocation("matMVP")
    for di in diseq:
        let mat_world = translate(di.position) * scale(di.width, di.height, 1)
        gl.uniformMatrix4fv(mvp_location, 1, GL_FALSE, value_ptr(g.mat_view * mat_world))
        let spriteInstance = g.spriteInstances[cast[uint32](di.sprite)]
        let sprite = g.sprites[spriteInstance.baseSprite]
        let spriteFrame = sprite.frames[spriteInstance.currentFrame]
        if isLayerVisibleInInstance(spriteInstance, spriteFrame.rootGroup):
            drawGroup(spriteInstance, spriteFrame.rootGroup)

proc uploadTexture(width: int, height: int, data: var seq[uint8]): GLtexture =
    gl.genTextures(1, addr result)
    gl.bindTexture(GL_TEXTURE_2D, result)
    gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
    gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)
    gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)

    gl.texImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, addr data[0])
    gl.generateMipmap(GL_TEXTURE_2D)

proc createLayerGroup(img: AsepriteImage, frameIndex: int, layerIndex: int, name: string, visible: bool, currentLevel: int = 0): SpriteLayer =
    let lastLayer = img.numberOfLayers()
    let width = img.width
    let height = img.height

    result = SpriteLayer(kind: SpriteLayerKind.Group)
    result.visible = visible
    result.name = name

    var layerIndex = layerIndex
    var layerLevel = img.getLayerLevel(layerIndex)

    while layerIndex < lastLayer and layerLevel >= currentLevel:
        layerLevel = img.getLayerLevel(layerIndex)
        let isGroup = img.isLayerGroup(layerIndex)
        let layerName = img.layerName(layerIndex)
        let isVisible = img.isLayerVisible(layerIndex)

        if layerLevel == currentLevel:
            if isGroup:
                result.group.add(createLayerGroup(img, frameIndex, layerIndex + 1, layerName, isVisible, currentLevel + 1))
            else:
                var data = img.rasterizeLayer(frameIndex, layerIndex)
                result.group.add(SpriteLayer(
                    kind: SpriteLayerKind.Image,
                    name: layerName,
                    textureID: uploadTexture(width, height, data),
                    visible: isVisible
                ))

        layerIndex += 1

proc loadNewSprite*(g: var Gfx, path: string): int =
    var
        s: Sprite

    if path.endsWith(".aseprite"):
        let img = ase.loadSprite(path)
        let width = img.width
        let height = img.height
        for fidx in 0 .. img.numberOfFrames() - 1:
            var frame: SpriteFrame
            var layerIndex = 0
            new(frame)
            frame.duration = img.getFrameDuration(fidx)
            frame.rootGroup = createLayerGroup(img, fidx, layerIndex, "<root>", true)
            s.frames.add(frame)
    else:
        # Non aseprite-image: 1 frame with 1 layer only
        var
            width, height, channels: int
            data: seq[uint8]
        data = stbi.load(path, width, height, channels, stbi.RGBA)
        
        var layer = SpriteLayer(
            kind: SpriteLayerKind.Image,
            name: "<layer>",
            textureID: uploadTexture(width, height, data),
            visible: true
        )
        var frame: SpriteFrame
        new(frame)
        frame.rootGroup = SpriteLayer(kind: SpriteLayerKind.Group, visible: true)
        frame.rootGroup.group.add(layer)
        s.frames.add(frame)
    
    result = len(g.sprites)
    g.spriteFilenames[path] = result
    g.sprites.add(s)

proc load_sprite*(g: var Gfx, path: string): sprite_id =
    var spriteIdx: int
    if not (path in g.spriteFilenames):
        echo("Loading " & path)
        spriteIdx = g.loadNewSprite(path)
    else:
        spriteIdx = g.spriteFilenames[path]
    
    result = cast[sprite_id](len(g.spriteInstances))
    
    var inst: SpriteInstance
    new(inst)
    inst = SpriteInstance(
        baseSprite: spriteIdx,
    )
    g.spriteInstances.add(inst)

proc getLayerVisible*(g: var Gfx, sprite: sprite_id, name: string): bool =
    var instance = g.spriteInstances[sprite.uint32]
    isLayerVisibleInInstance(instance, findLayerByName(g.sprites[instance.baseSprite], name))

proc setLayerVisible*(g: var Gfx, sprite: sprite_id, name: string, visible: bool) =
    var instance = g.spriteInstances[sprite.uint32]
    if name in instance.layerStates:
        instance.layerStates[name].visible = visible
    else:
        instance.layerStates[name] = SpriteInstanceState(
            visible: visible
        )
    assert getLayerVisible(g, sprite, name) == visible

proc stepAnimation*(g: var Gfx, sprite: sprite_id, deltaTime: float): bool =
    ## Returns true if the animation has started over.
    var instance = g.spriteInstances[sprite.uint32]
    instance.currentTime += int(deltaTime * 1000)
    let sprite = g.sprites[instance.baseSprite]
    result = false

    while instance.currentTime >= sprite.frames[instance.currentFrame].duration:
        instance.currentFrame += 1
        
        if instance.currentFrame >= len(sprite.frames):
            result = true
            instance.currentFrame = 0

        instance.currentTime -= sprite.frames[instance.currentFrame].duration
        if instance.currentTime < 0:
            instance.currentTime = 0
        
