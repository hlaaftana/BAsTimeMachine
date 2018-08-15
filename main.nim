import sdl2, sdl2/image as sdlimage, sdl2/mixer

type
  GameStateKind = enum
    gsNone, gsDone, gsMenu, gsIntro

  Game = ref object
    window: WindowPtr
    renderer: RendererPtr
    currentAudio: MusicPtr
    case state: GameStateKind
    of gsNone, gsDone: discard
    of gsMenu, gsIntro:
      dialogWidth, dialogHeight: cint
      dialogTexture: TexturePtr

template assertBool(a): untyped =
  let x = a
  assert x

proc dialog(game: Game, image: string) =
  let surf = sdlimage.load(image)
  if surf.isNil: quit "Give me back my " & image
  (game.dialogWidth, game.dialogHeight) = (surf.w, surf.h)
  game.dialogTexture = createTextureFromSurface(game.renderer, surf)
  freeSurface(surf)

proc `audio=`(game: Game, file: string) =
  if not game.currentAudio.isNil:
    discard haltMusic()
    freeMusic(game.currentAudio)
  game.currentAudio = loadMus(file)
  if game.currentAudio.isNil: quit "Give me back my " & file

template loopAudio(game: Game) =
  discard playMusic(game.currentAudio, -1)

proc draw(game: Game, texture: TexturePtr, src, dest: Rect) =
  game.renderer.copy(texture, unsafeAddr src, unsafeAddr dest)

proc update(game: Game, newState: GameStateKind) =
  game.state = newState
  case newState
  of gsMenu:
    game.renderer.setDrawColor(r = 221, g = 247, b = 255)
    game.dialog("res/menu.png")
    game.audio = "res/menu.mp3"
    game.loopAudio()
  of gsIntro:
    game.renderer.setDrawColor(r = 255, g = 255, b = 255)

  else: discard

proc key(game: Game, code: Scancode) =
  case game.state
  of gsMenu:
    if not bool(getModState() and (KMOD_CTRL or KMOD_SHIFT or KMOD_ALT)): 
      game.update(gsDone) # start
  else: discard

proc listen(game: Game) =
  var event = defaultEvent
  while event.pollEvent():
    case event.kind
    of QuitEvent:
      game.state = gsDone
    of KeyDown:
      key(game, event.key.keysym.scancode)
    else: discard

proc render(game: Game) =
  game.renderer.clear()
  case game.state
  of gsMenu, gsIntro:
    let (ww, wh) = game.window.getSize()
    game.draw(game.dialogTexture,
      src = rect(0, 0, game.dialogWidth, game.dialogHeight),
      dest = rect(0, 0, ww, wh))
  else: discard
  game.renderer.present()

proc main =
  assertBool sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS or INIT_AUDIO)

  defer: sdl2.quit()

  assertBool setHint("SDL_RENDER_SCALE_QUALITY", "2")

  var game: Game
  new(game)
  game.window = createWindow(title = "BrokenAce's Time Machine",
    x = SDL_WINDOWPOS_CENTERED, y = SDL_WINDOWPOS_CENTERED,
    w = 1280, h = 720, flags = SDL_WINDOW_SHOWN or SDL_WINDOW_RESIZABLE)
  assert(not game.window.isNil)

  game.renderer = game.window.createRenderer(index = -1,
    flags = Renderer_Accelerated or Renderer_PresentVsync)
  assert(not game.renderer.isNil)

  discard openAudio(0, 0, 2, 4096)
  game.update(gsMenu)

  while game.state != gsDone:
    game.listen()
    game.render()

  if not game.currentAudio.isNil:
    mixer.freeMusic(game.currentAudio)
    closeAudio()
  game.window.destroy()
  game.renderer.destroy()

when isMainModule: main()