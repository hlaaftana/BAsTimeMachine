import sdl2 except init, quit
import sdl2/[mixer, ttf], random
import /chess, /data, /util

proc setPokemon(game: Game, pm: PokemonKind) =
  let data = pokemonData[pm]
  assert game.state.kind == gsPokemon
  game.state.pokemonTexture = game.loadTexture(data.image)
  game.state.pokemon = Pokemon(kind: pm)
  case pm
  of Roy:
    game.state.pokemon.ourHealth = 50
    game.state.pokemon.royHealth = 5
  of Morty:
    game.state.pokemon.chessBoard.init()
  else: discard
  game.setAudio(data.cry)
  game.playAudio()

proc update(game: Game, newState: GameState) =
  game.state = State(kind: newState)
  let data = stateData[newState]
  case data.kind
  of gskNoOp: discard
  of gskDialog:
    game.renderer.setDrawColor(data.dialogColor)
    game.state.dialog = game.loadTexture(data.dialogImage)
    game.setAudio(data.dialogMusic)
    game.loopAudio()
  of gskPokemon:
    game.state.pokemonTextbox = game.loadTexture(textboxImage)
    game.setPokemon(low(PokemonKind))

proc key(game: Game, code: Scancode) =
  case game.state.kind
  of gsMenu:
    if not bool(getModState() and (KMOD_CTRL or KMOD_SHIFT or KMOD_ALT)): 
      game.update(gsIntro)
  of gsIntro:
    if not bool(getModState() and (KMOD_CTRL or KMOD_SHIFT or KMOD_ALT)): 
      game.update(gsPokemon)
  of gsPokemon:
    if not bool(getModState() and (KMOD_CTRL or KMOD_SHIFT or KMOD_ALT)):
      if game.state.pokemon.kind == high(PokemonKind):
        game.update(gsDone)
      else:
        game.setPokemon(succ(game.state.pokemon.kind))
  else: discard

proc mouse(game: Game, x, y: cint) =
  case game.state.kind
  of gsPokemon:
    case game.state.pokemon.kind
    of Yourmurderguy, `Ethereal God`:
      
  else: discard

proc listen(game: Game) =
  var event = defaultEvent
  while event.pollEvent():
    case event.kind
    of QuitEvent:
      game.state = doneState
    of KeyDown:
      game.key(event.key.keysym.scancode)
    of MouseButtonDown:
      let ev = event.button
      if ev.button == ButtonLeft:
        game.mouse(ev.x, ev.y)
    else: discard

proc render(game: Game) =
  game.renderer.clear()
  case stateKinds[game.state.kind]
  of gskNoOp: discard
  of gskDialog:
    let (ww, wh) = game.window.getSize()
    game.draw(game.state.dialog,
      dest = rect(0, 0, ww, wh))
  of gskPokemon:
    let (ww, wh) = game.window.getSize()
    let (aww, awh) = (ww div 2, wh div 2)
    game.draw(game.state.pokemonTexture, rect(aww, 0, aww, awh))
    game.draw(game.state.pokemonTextbox, rect(0, awh, ww, awh))
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