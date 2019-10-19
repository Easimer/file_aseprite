# === Copyright (c) 2019-2020 easimer.net. All rights reserved. ===

import sdl2

type window* = object
    window: WindowPtr
    renderer: RendererPtr
    glctx: GlContextPtr

proc openWindow*(width: int, height: int): window =
    result.window = createWindow("file_aseprite testbed", 100, 100, 640, 480, SDL_WINDOW_SHOWN or SDL_WINDOW_OPENGL)
    result.renderer = createRenderer(result.window, -1, Renderer_Accelerated or Renderer_PresentVsync)

    discard glSetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3)
    discard glSetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3)
    discard glSetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE)
    discard glSetAttribute(SDL_GL_DEPTH_SIZE, 24)
    discard glSetAttribute(SDL_GL_DOUBLEBUFFER, 1)
    discard glSetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 1)
    discard glSetAttribute(SDL_GL_MULTISAMPLESAMPLES, 4)

    result.glctx = glCreateContext(result.window)
    discard glSetSwapInterval(-1)
    discard setRelativeMouseMode(True32)

proc closeWindow*(wnd: window) =
    if wnd.glctx != nil:
        glDeleteContext(wnd.glctx)
    if wnd.renderer != nil:
        destroy wnd.renderer
    if wnd.window != nil:
        destroy wnd.window

proc swapWindow*(wnd: window) =
    glSwapWindow(wnd.window)

proc processEvents*(wnd: window, callback: proc(released: bool, kv: int)): bool =
    result = false
    var ev = sdl2.defaultEvent
    if pollEvent(ev):
        case ev.kind:
            of QuitEvent:
                result = true
            of KeyDown:
                callback(false, ev.key().keysym.sym)
            of KeyUp:
                callback(true, ev.key().keysym.sym)
            else: discard nil