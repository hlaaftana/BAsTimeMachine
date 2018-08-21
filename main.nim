import sdl2 except init, quit
import sdl2/[mixer, ttf], random
import /chess, /data, /util

{.warning[ProveField]: off.}

proc setPokemon(game: Game, pm: PokemonKind) =
  let data = pokemonData[pm]
  assert game.state.kind == gsPokemon
  game.state.pokemonTexture = game.loadTexture(data.image)
  game.state.pokemon = Pokemon(kind: pm)
  game.state.pokemonText = newPokemonText(data.text[0])
  case pm
  of Yourmurderguy, `Ethereal God`:
    discard
  of Roy:
    game.state.pokemon.ourHealth = 50
    game.state.pokemon.royHealth = 5
  of Morty:
    game.state.pokemon.chessBoard.init()
  else: discard
  game.setAudio(data.cry)
  game.playAudio()

proc initiateDdr(game: Game, pok: Pokemon) =
  discard

proc progressText(game: Game, pok: Pokemon) =
  case pok.kind
  of Yourmurderguy, `Ethereal God`:
    if pok.ddrCount == 0:
      initiateDdr(game, pok)
    else:
      setPokemon(game, succ(pok.kind))
  of Troll:
    let p = pokemonData[pok.kind]
    if pok.sudokuTexture.isNil:
      game.state.pokemonText = newPokemonText(p.text[1])
      pok.sudokuTexture = game.loadTexture(sudokuImage)
      startTextInput()
    else:
      setPokemon(game, succ(pok.kind))
  else: discard

proc clearDdrArrow(pok: Pokemon, hi, i: int, hy, ay: cint, windowSize: Point) =
  pok.ddrScore = cint(abs(hy - ay) * 720) div windowSize[1]
  pok.ddrArrows[hi].arrows.del(i)

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
  of gskOperation:
    discard

proc key(game: Game, code: Scancode) =
  case game.state.kind
  of gsMenu:
    if not bool(getModState() and (KMOD_CTRL or KMOD_SHIFT or KMOD_ALT)): 
      game.update(gsIntro)
  of gsIntro:
    if not bool(getModState() and (KMOD_CTRL or KMOD_SHIFT or KMOD_ALT)): 
      game.update(gsPokemon)
  of gsPokemon:
    let pok = game.state.pokemon
    #[if pok.kind == Troll and not pok.sudokuTexture.isNil and pok.sudokuCharacterTexture.isNil:

    el]#if game.state.pokemonText.real.len != 0 and not bool(getModState() and (KMOD_CTRL or KMOD_SHIFT or KMOD_ALT)):
      progressText(game, pok)
  else: discard

proc mouse(game: Game, x, y: cint) =
  case game.state.kind
  of gsPokemon:
    let pok = game.state.pokemon
    if game.state.pokemonText.real.len != 0 and not bool(getModState() and (KMOD_CTRL or KMOD_SHIFT or KMOD_ALT)):
      progressText(game, pok)
      return
    case pok.kind
    of Yourmurderguy, `Ethereal God`:
      let winsz = game.window.getSize()
      block bigger:
        for hi in countup(0, high(pok.ddrArrows)):
          let hitbox = hitbox(pok, hi, winsz)
          if (x, y) in hitbox:
            let arrows = pok.ddrArrows[hi].arrows
            for i in countup(0, high(arrows)):
              let arrow = arrow(pok, hi, i, winsz)
              if (x, y) in arrow:
                clearDdrArrow(game.state.pokemon, hi, i, hitbox.y, arrow.y, winsz)
                break bigger
    else: discard
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
    let pok = game.state.pokemon
    case pok.kind
    of Yourmurderguy, `Ethereal God`:
      if game.state.pokemonText.real.len == 0:
        # ddr state
        if pok.ddrCount >= 50:
          game.state.pokemonText = newPokemonText(pokemonData[pok.kind].text[1] % $pok.ddrScore)  
    else: discard
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