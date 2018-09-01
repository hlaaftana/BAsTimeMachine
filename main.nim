import sdl2 except init, quit
import sdl2/[mixer, ttf], random, sequtils, times
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
  game.setMusic(data.cry)
  game.playMusic()

proc initiateDdr(game: Game, pok: Pokemon) =
  game.state.pokemonText = defaultText
  randomize()
  case pok.kind
  of Yourmurderguy:
    game.setMusic("res/ddr/yourmurderguy.mp3")
  of `Ethereal God`:
    game.setMusic("res/ddr/ethereal god.mp3")
  else: discard
  game.loopMusic()
  pok.ddrIndicators.newSeq(0)
  pok.ddrSoundEffects.newSeq(5)
  let data = ddrData(pok.kind)
  pok.ddrArrows.newSeq(data.len)
  for i, d in data:
    pok.ddrArrows[i] = (d.key, game.loadTexture(d.hitboxImage), game.loadTexture(d.arrowImage), newSeq[int]())

proc update(game: Game, newState: GameState) =
  game.state = State(kind: newState)
  let data = stateData[newState]
  case data.kind
  of gskNoOp: discard
  of gskDialog:
    game.renderer.setDrawColor(data.dialogColor)
    game.state.dialog = game.loadTexture(data.dialogImage)
    game.setMusic(data.dialogMusic)
    game.loopMusic()
  of gskPokemon:
    randomize()
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
        game.state.pokemonText = newPokemonText(p.text[1], 70)
        pok.sudokuTexture = game.loadTexture(sudokuImage)
        startTextInput()
      else:
        setPokemon(game, succ(pok.kind))
    of Roy:
      setPokemon(game, succ(pok.kind))
    else: discard
  else: discard

proc clearDdrArrow(game: Game, pok: Pokemon, hi, i: int, hy, ay: cint, windowSize: Point) =
  let score = cint(abs(hy - ay) * 720) div windowSize[1]
  template play(i, s) =
    if pok.ddrSoundEffects[i].isNil:
      pok.ddrSoundEffects[i] = loadWav(s)
    playSound(pok.ddrSoundEffects[i])
  var indicatorText: cstring
  case score
  of 0..24:
    indicatorText = "Perfect!"
    play(1, "res/ddr/perfect.wav")
  of 25..74:
    indicatorText = "Great!"
    play(2, "res/ddr/great.wav")
  of 75..130:
    indicatorText = "Good!"
    play(3, "res/ddr/good.wav")
  else:
    indicatorText = "OK!"
    play(4, "res/ddr/ok.wav")
  pok.ddrScore += score
  pok.ddrIndicators.add((indicatorText, 0.cint))
  pok.ddrArrows[hi].values.del(i)
  if pok.ddrCount >= (if pok.kind == Yourmurderguy: 41 else: 4):
    game.state.pokemonText = newPokemonText(pokemonData[pok.kind].text[1] % $pok.ddrScore)
    pok.ddrArrows = @[]
  else:
    inc pok.ddrCount

proc key(game: Game, code: Scancode) =
  case stateKinds[game.state.kind]
  of gskDialog:
    if not modsHeldDown: 
      game.progress()
  of gskPokemon:
    let pok = game.state.pokemon
    case pok.kind
    of Yourmurderguy, `Ethereal God`:
      let winsz = game.window.getSize()
      for hi, a in pok.ddrArrows:
        let hit = hitbox(pok, hi, winsz)
        if code == a.key:
          for i in countup(0, high(a.values)):
            let ah = arrow(pok, hi, i, winsz)
            let range = hit.y .. (hit.y + hit.h)
            if ah.y in range or (ah.y + ah.h) in range:
              clearDdrArrow(game, pok, hi, i, hit.y, ah.y, winsz)
              return
    of Troll:
      if not pok.sudokuTexture.isNil and pok.sudokuCharacterTexture.isNil:
        let t = getScancodeName(code)
        game.state.pokemon.sudokuCharacterTexture = game.renderText(t)
        game.state.pokemonText = newPokemonText(pokemonData[Troll].text[2 + ord(t[0] notin {'0'..'9'})])
        return
    else: discard
    if game.state.pokemonText.real.len != 0 and
      (game.state.pokemonText.isRendered or modsHeldDown):
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
            let arrows = pok.ddrArrows[hi].values
            for i in countup(0, high(arrows)):
              let arrow = arrow(pok, hi, i, winsz)
              if (x, y) in arrow:
                clearDdrArrow(game, pok, hi, i, hitbox.y, arrow.y, winsz)
                break bigger
    else: discard
    if y >= game.window.getSize[1] div 2 and
      game.state.pokemonText.real.len != 0 and
      (game.state.pokemonText.isRendered or modsHeldDown):
      game.progress()
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

proc tick(game: Game) =
  case stateKinds[game.state.kind]
  of gskPokemon:
    if game.state.pokemonText.real.len > 0:
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
    let pok = game.state.pokemon
    case pok.kind
    of Yourmurderguy, `Ethereal God`:
      for hi, hiarr in pok.ddrArrows:
        for i, arr in hiarr.values:
          var h: cint
          hiarr.arrow.queryTexture(nil, nil, nil, addr h)
          if arr >= 720 + h:
            pok.ddrArrows[hi].values.del(i)
            pok.ddrIndicators.add((cstring"Miss!", 0.cint))
            if pok.ddrSoundEffects[0].isNil:
              pok.ddrSoundEffects[0] = loadWav("res/ddr/miss.wav")
            playSound(pok.ddrSoundEffects[0])
          else:
            inc pok.ddrArrows[hi].values[i], 5
      if pok.ddrArrows.len != 0 and rand(40) == 15:
        let index = rand(pok.ddrArrows.high)
        pok.ddrArrows[index].values.add(0)
      block:
        var hig = len(pok.ddrIndicators)
        var i = 0
        while i < hig:
          inc pok.ddrIndicators[i][1]
          if pok.ddrIndicators[i][1] >= 100:
            pok.ddrIndicators.del(i)
            dec hig
          inc i
    else: discard
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
    let wsz = game.window.getSize()
    let (ww, wh) = wsz
    let (aww, awh) = (ww div 2, wh div 2)
    game.draw(game.state.pokemonTexture, rect(aww, 0, aww, awh))
    game.draw(game.state.pokemonTextbox, rect(0, awh, ww, awh))
    let text = game.state.pokemonText
    if text.rendered.len != 0:
      var
        x: cint = 50 * ww div 1080
        y: cint = (50 * wh div 720) + awh
      for r in text.rendered:
        var rw, rh: cint
        r.queryTexture(nil, nil, addr rw, addr rh)
        rw = rw * ww div 1080
        rh = rh * wh div 720
        if rw + x >= ww:
          x = 50 * ww div 1080
          y += rh
        game.draw(r, rect(x, y, rw, rh))
        x += rw
    let pok = game.state.pokemon
    case pok.kind
    of Yourmurderguy, `Ethereal God`:
      for hi, hiarr in pok.ddrArrows:
        game.draw(hiarr.hitbox, hitbox(pok, hi, wsz))
        for i, arr in hiarr.values:
          game.draw(hiarr.arrow, arrow(pok, hi, i, wsz))
      for val in pok.ddrIndicators:
        game.draw(game.renderText(val[0], color(216, 20, 145 + val[1], 255)), ddrIndicator(wsz, val[1]))
    of Troll:
      if not pok.sudokuTexture.isNil:
        game.draw(pok.sudokuTexture, sudoku(pok, wsz))
      if not pok.sudokuCharacterTexture.isNil:
        game.draw(pok.sudokuCharacterTexture, sudoku(pok, wsz))
    else: discard
  else: discard
  game.renderer.present()

proc main =
  if not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS or INIT_AUDIO):
    quit "Couldn't initialize SDL, " & $getError()
  if not ttfInit():
    quit "Couldn't initialize SDL font handling, " & $getError()

  defer: sdl2.quit()

  if not setHint("SDL_RENDER_SCALE_QUALITY", "2"):
    quit "Couldn't set SDL render scale quality, " & $getError()

  var game: Game
  new(game)
  game.window = createWindow(title = "BrokenAce's Time Machine",
    x = SDL_WINDOWPOS_CENTERED, y = SDL_WINDOWPOS_CENTERED,
    w = 1280, h = 720, flags = SDL_WINDOW_SHOWN or SDL_WINDOW_RESIZABLE)
  if game.window.isNil:
    quit "Couldn't create window, " & $getError()
  game.renderer = game.window.createRenderer(index = -1,
    flags = Renderer_Accelerated or Renderer_PresentVsync)
  if game.renderer.isNil:
    quit "Couldn't create renderer, " & $getError()
  game.font = font("Petscop Wide.ttf", 48)

  discard openAudio(0, 0, 2, 4096)
  game.update(gsMenu)

  var lastFrameTime = cpuTime()

  while game.state.kind != gsDone:
    game.listen()
    if cpuTime() - lastFrameTime >= (1 / 60):
      game.tick()
      game.render()
      lastFrameTime = cpuTime()

  if not game.currentMusic.isNil:
    freeMusic(game.currentMusic)
    closeAudio()
  game.font.close()
  ttfQuit()
  game.window.destroy()
  game.renderer.destroy()

when isMainModule: main()