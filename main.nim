import sdl2, sdl2/mixer
import /data, /util

proc update(game: Game, newState: GameState) =
  game.state = State(kind: newState)
  let data = stateData[newState]
  case data.kind
  of gskNoOp: discard
  of gskDialog:
    game.renderer.setDrawColor(data.dialogColor)
    game.state.dialog = game.loadTexture(data.dialogImage)
    game.audio = data.dialogMusic
    game.loopAudio()
  of gskPokemon:
    game.state.currentPokemon = low(Pokemon)

proc key(game: Game, code: Scancode) =
  case game.state.kind
  of gsMenu:
    if not bool(getModState() and (KMOD_CTRL or KMOD_SHIFT or KMOD_ALT)): 
      game.update(gsIntro)
  of gsIntro:
    if not bool(getModState() and (KMOD_CTRL or KMOD_SHIFT or KMOD_ALT)): 
      game.update(gsPokemon)
  else: discard

proc listen(game: Game) =
  var event = defaultEvent
  while event.pollEvent():
    case event.kind
    of QuitEvent:
      game.state = doneState
    of KeyDown:
      key(game, event.key.keysym.scancode)
    else: discard

proc render(game: Game) =
  game.renderer.clear()
  case stateKinds[game.state.kind]
  of gskNoOp: discard
  of gskDialog:
    let (w, h, texture) = game.state.dialog
    let (ww, wh) = game.window.getSize()
    game.draw(texture,
      src = rect(0, 0, w, h),
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

  while game.state.kind != gsDone:
    game.listen()
    game.render()

  if not game.currentAudio.isNil:
    freeMusic(game.currentAudio)
    closeAudio()
  game.window.destroy()
  game.renderer.destroy()

when isMainModule: main()