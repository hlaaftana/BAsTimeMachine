import sdl2 except init, quit
import sdl2/[mixer, ttf], random, sequtils
import /chess, /data, /util

{.warning[ProveField]: off.}

proc setPokemon(game: Game, pm: PokemonKind) =
  let data = pokemonData[pm]
  assert game.state.kind == gsPokemon
  game.state.pokemonTexture = game.loadTexture(data.image)
  game.state.pokemon = Pokemon(kind: pm)
  game.state.pokemonText = newPokemonText(data.text[0], 60)
  case pm
  of Roy:
    game.state.pokemon.ourHealth = 50
    game.state.pokemon.royHealth = 5
  of Morty:
    game.state.pokemon.chessBoard.init()
  else: discard
  game.setAudio(data.cry)
  game.playAudio()

proc initiateDdr(game: Game, pok: Pokemon) =
  template ddrArrowSet(ddrData): untyped =
    pok.ddrArrows = newSeq[type(pok.ddrArrows[0])](ddrData.len)
    for i, d in ddrData:
      pok.ddrArrows[i] = (d.key, game.loadTexture(d.hitboxImage), newSeq[(TexturePtr, int)]())

  game.state.pokemonText = defaultText
  case pok.kind
  of Yourmurderguy:
    ddrArrowSet(ddrYourmurderguyData)
  of `Ethereal God`:
    ddrArrowSet(ddrEtherealGodData)
  else: discard

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

proc progress(game: Game) =
  case game.state.kind
  of gsMenu:
    game.update(gsIntro)
  of gsIntro:
    game.update(gsPokemon)
  of gsPokemon:
    let pok = game.state.pokemon
    case pok.kind
    of Yourmurderguy, `Ethereal God`:
      if pok.ddrCount == 0:
        initiateDdr(game, pok)
      else:
        setPokemon(game, succ(pok.kind))
    of Troll:
      let p = pokemonData[pok.kind]
      if pok.sudokuTexture.isNil:
        game.state.pokemonText = newPokemonText(p.text[1], 120)
        pok.sudokuTexture = game.loadTexture(sudokuImage)
        startTextInput()
      else:
        setPokemon(game, succ(pok.kind))
    else: discard
  else: discard

proc clearDdrArrow(game: Game, pok: Pokemon, hi, i: int, hy, ay: cint, windowSize: Point) =
  pok.ddrScore += cint(abs(hy - ay) * 720) div windowSize[1]
  pok.ddrArrows[hi].arrows.del(i)
  if pok.ddrCount >= 41:
    game.state.pokemonText = newPokemonText(pokemonData[pok.kind].text[1] % $pok.ddrScore)
  else:
    inc pok.ddrCount

proc key(game: Game, code: Scancode) =
  case stateKinds[game.state.kind]
  of gskDialog:
    if not bool(getModState() and (KMOD_CTRL or KMOD_SHIFT or KMOD_ALT)): 
      game.progress()
  of gskPokemon:
    let pok = game.state.pokemon
    case pok.kind
    of Yourmurderguy, `Ethereal God`:
      let winsz = game.window.getSize()
      for hi, a in pok.ddrArrows:
        let hity = hitbox(pok, hi, winsz).y
        if code == a.key:
          for i in countup(0, high(a.arrows)):
            let ay = arrow(pok, hi, i, winsz).y
            if ay <= hity:
              clearDdrArrow(game, pok, hi, i, hity, ay, winsz)
              return
    else: discard
    if game.state.pokemonText.real.len != 0 and not bool(getModState() and (KMOD_CTRL or KMOD_SHIFT or KMOD_ALT)):
      game.progress()
  else: discard

proc mouse(game: Game, x, y: cint) =
  case stateKinds[game.state.kind]
  of gskDialog:
    game.progress()
  of gskPokemon:
    let pok = game.state.pokemon
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
                clearDdrArrow(game, pok, hi, i, hitbox.y, arrow.y, winsz)
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
    of TextInput:
      if game.state.kind == gsPokemon and game.state.pokemon.kind == Troll:
        stopTextInput()
        withSurface renderUtf8Solid(game.font, cast[ptr cstring](addr event.text.text)[], colorBlack):
          game.state.pokemon.sudokuCharacterTexture = createTextureFromSurface(game.renderer, it)
    else: discard

proc tick(game: Game) =
  case stateKinds[game.state.kind]
  of gskPokemon:
    if game.state.pokemonText.counter <= 0:
      let d = uint32(game.state.pokemonText.delay.float * rand(2.0))
      game.state.pokemonText.counter = d
      game.state.pokemonText.delay = d
    else:
      dec game.state.pokemonText.counter
      return
    let
      real = game.state.pokemonText.real
      rendered = game.state.pokemonText.rendered
    if rendered.len < real.len:
      let texture = game.renderText(real[rendered.len])
      if texture.isNil:
        quit "Couldn't blah, error: " & $getError()
      game.state.pokemonText.rendered.add(texture)
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
      let text = game.state.pokemonText
      if text.rendered.len != 0:
        var
          x: cint = 50
          y: cint = 50 + awh
        for r in text.rendered:
          var rw, rh: cint
          r.queryTexture(nil, nil, addr rw, addr rh)
          if rw + x >= ww:
            x = 50
            y += rh
          #echo "x: ", x, ", y: ", y, ", width: ", rw, ", height: ", rh
          game.draw(r, rect(x, y, rw, rh))
          x += rw
    else: discard
  else: discard
  game.renderer.present()

proc main =
  assertBool sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS or INIT_AUDIO)
  assertBool ttfInit()

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
  game.font = font("Petscop Wide.ttf", 48)

  discard openAudio(0, 0, 2, 4096)
  game.update(gsMenu)

  while game.state.kind != gsDone:
    game.listen()
    game.tick()
    game.render()
    delay(17)

  if not game.currentAudio.isNil:
    freeMusic(game.currentAudio)
    closeAudio()
  game.font.close()
  ttfQuit()
  game.window.destroy()
  game.renderer.destroy()

when isMainModule: main()