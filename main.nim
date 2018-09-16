import sdl2 except init, quit
import sdl2/[mixer, ttf], random, sequtils, times, math
import /chess, /data, /util

{.warning[ProveField]: off.}
when not defined(js):
  {.link: "res/icon.res".}

proc setPokemon(game: Game, pm: PokemonKind) =
  let data = pokemonData[pm]
  assert game.state.kind == gsPokemon
  game.state.pokemonRand = initRand(game.numTicks.int64)
  game.state.pokemonTexture = loadTexture(game, data.image)
  game.state.pokemon = Pokemon(kind: pm)
  game.state.pokemonText = newPokemonText(data.text[0], 60)
  game.setMusic(data.cry)
  game.playMusic()

proc initiateDdr(game: Game, pok: Pokemon) =
  game.state.pokemonText = defaultText
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
  game.lastUpdateTick = game.numTicks
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
    game.state.pokemonTextbox = game.loadTexture(textboxImage)
    game.setPokemon(low(PokemonKind))
  of gsk2d:
    game.state.playerMovement = @[]
    game.state.playerTexture = game.loadTexture("res/sonic.png")
    game.state.background2d = game.loadTexture("res/sonicbg.png")
    game.setMusic("res/sonic.mp3")
    game.loopMusic()
  of gskCredits:
    game.state.creditsTexture = game.loadTexture("res/credits.png")
    game.state.creditsSpeed = 1
    game.setMusic("res/credits.mp3")
    game.loopMusic()
    discard

proc moveBlack(game: Game, board: var chess.Board) =
  var allMoves: seq[(uint8, uint8)] = @[]
  for x, y, sq in board.pieces:
    if sq.side == Black:
      for mx, my in board.moves(x, y):
        allMoves.add((chessIndex(x, y).uint8, chessIndex(mx, my).uint8))
  let (mo, mn) = rand(game.state.pokemonRand, allMoves)
  BaseBoard(board)[mn] = BaseBoard(board)[mo]
  BaseBoard(board)[mo] = (NoPiece, NoSide)

proc progress(game: Game) =
  case game.state.kind
  of gsMenu:
    game.state.dialog.destroy()
    game.update(gsIntro)
  of gsIntro:
    game.state.dialog.destroy()
    game.update(gsPokemon)
  of gsPokemon:
    game.state.pokemonText.destroy()
    let pok = game.state.pokemon
    case pok.kind
    of Yourmurderguy, `Ethereal God`:
      if pok.ddrCount == 0:
        pok.ddrSpeed = 5 # you keep the speed if you initiate again
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
        pok.sudokuTexture.destroy()
        pok.sudokuCharacterTexture.destroy()
        setPokemon(game, succ(pok.kind))
    of Roy:
      if pok.challengerTexture.isNil:
        pok.challengerTexture = game.loadTexture("res/challenger.png")
        game.setMusic("res/challenger.mp3")
        game.loopMusic()
      else:
        pok.challengerTexture.destroy()
        setPokemon(game, succ(pok.kind))
    of Morty:
      if pok.chessPieceTexture.isNil:
        game.state.pokemonText = defaultText
        pok.chessBoard.init()
        pok.chessPieceTexture = loadTexture(game, "res/diamond.png")
        pok.chessBackground = loadTexture(game, "res/m.png")
        game.setMusic("res/chess.mp3")
        game.loopMusic()
      else:
        pok.chessPieceTexture.destroy()
        pok.chessBackground.destroy()
        game.update(gs2d)
  of gs2d:
    game.state.background2d.destroy()
    game.state.playerTexture.destroy()
    game.update(gsEnding)
  of gsEnding:
    if game.numTicks - game.lastUpdateTick >= 60:
      game.state.dialog.destroy()
      game.update(gsCredits)
  of gsCredits:
    game.state.creditsTexture.destroy()
    game.update(gsDone)
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
    for arr in pok.ddrArrows:
      arr.arrow.destroy()
      arr.hitbox.destroy()
    pok.ddrArrows = @[]
    for sfx in pok.ddrSoundEffects:
      sfx.freeChunk()
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
      if game.state.pokemonText.real.len == 0:
        case code
        of SDL_SCANCODE_S:
          pok.ddrScore += 666
        of SDL_SCANCODE_B:
          pok.ddrArrows.delete(rand(game.state.pokemonRand, pok.ddrArrows.high))
        of SDL_SCANCODE_A:
          let d = rand(game.state.pokemonRand, ddrData(pok.kind))
          let x = (d.key, game.loadTexture(d.hitboxImage), game.loadTexture(d.arrowImage), newSeq[int]())
          pok.ddrArrows.add(x)
        of SDL_SCANCODE_R:
          initiateDdr(game, pok)
        of SDL_SCANCODE_D:
          game.update(gsIntro)
          return
        of SDL_SCANCODE_M:
          game.update(gsMenu)
          return
        of SDL_SCANCODE_L:
          pok.ddrSpeed = pok.ddrSpeed div 2
        of SDL_SCANCODE_P:
          dec pok.ddrCount
        of SDL_SCANCODE_O:
          pok.ddrSpeed = pok.ddrSpeed * 2
        else: discard
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
  of gsk2d:
    if (getModState().cint and KMOD_CTRL) != 0:
      for pm, k in playerMovementKeys:
        if k == code:
          for p in game.state.playerMovement.mitems:
            if p.kind == pm:
              p.accel += 4.0
          break
    elif (getModState().cint and KMOD_SHIFT) != 0:
      for pm, k in playerMovementKeys:
        if k == code:
          for p in game.state.playerMovement.mitems:
            if p.kind == pm:
              p.speed += 4.0
          break
    else:
      case code
      of SDL_SCANCODE_UP:
        game.state.playerMovement.add((pmUp, 13.35, -2.4))
      of SDL_SCANCODE_LEFT:
        game.state.playerMovement.add((pmLeft, 6.7, 7.3))
      of SDL_SCANCODE_RIGHT:
        game.state.playerMovement.add((pmRight, 2.2, 0.45))
      of SDL_SCANCODE_Y:
        game.state.playerMovement.add((pmRotate, 3.5, 18.3))
      of SDL_SCANCODE_H:
        game.state.playerMovement.add((pmRotateBackward, 3.5, 18.3))
      of SDL_SCANCODE_T:
        game.state.playerFlip = game.state.playerFlip xor SDL_FLIP_HORIZONTAL
      of SDL_SCANCODE_U:
        game.state.playerFlip = game.state.playerFlip xor SDL_FLIP_VERTICAL
      else: discard
  of gskCredits:
    var h: cint
    game.state.creditsTexture.queryTexture(nil, nil, nil, addr h)
    if h - game.state.creditsPosition == 720:
      game.progress()
    else:
      case code
      of SDL_SCANCODE_O:
        game.state.creditsSpeed *= 2
      of SDL_SCANCODE_L:
        game.state.creditsSpeed = game.state.creditsSpeed div 2
      else: discard
  else: discard

proc mouse(game: Game, x, y: cint) =
  case stateKinds[game.state.kind]
  of gskDialog:
    game.progress()
  of gskPokemon:
    let winsz = game.window.getSize()
    let pok = game.state.pokemon
    case pok.kind
    of Yourmurderguy:
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
    of Morty:
      for px, py, square in pok.chessBoard.pieces:
        if (x.cint, y.cint) in chessSquare(winsz, px, py):
          let ind = chessIndex(px, py).uint8
          if square.side == White:
            when false:
              pok.chessAvailable = {}
            pok.chessSelected = ind
            for mx, my in pok.chessBoard.moves(px, py):
              pok.chessAvailable.incl(chessIndex(mx, my).uint8)
            break
          elif ind in pok.chessAvailable:
            pok.chessAvailable = {}
            if BaseBoard(pok.chessBoard)[ind].piece == King:
              game.progress()
              return
            BaseBoard(pok.chessBoard)[ind] = BaseBoard(pok.chessBoard)[pok.chessSelected]
            BaseBoard(pok.chessBoard)[pok.chessSelected] = (NoPiece, NoSide)
            moveBlack(game, pok.chessBoard)
            break
    else: discard
    if (pok.kind == Roy and not pok.challengerTexture.isNil) or
      (y >= winsz[1] div 2 and
      game.state.pokemonText.real.len != 0 and
      (game.state.pokemonText.isRendered or modsHeldDown)):
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
    of KeyUp:
      let sc = event.key.keysym.scancode
      if stateKinds[game.state.kind] == gsk2d:
        var
          i = 0
          hig = game.state.playerMovement.len
        while i < hig:
          if playerMovementKeys[game.state.playerMovement[i].kind] == sc:
            game.state.playerMovement.del(i)
            dec hig
          else:
            inc i
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
        let d = uint32(game.state.pokemonText.delay.float * rand(game.state.pokemonRand, 2.0))
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
            inc pok.ddrArrows[hi].values[i], pok.ddrSpeed
      if pok.ddrArrows.len != 0 and rand(game.state.pokemonRand, 40) == 15:
        let index = rand(game.state.pokemonRand, pok.ddrArrows.high)
        pok.ddrArrows[index].values.add(0)
      block:
        var hig = len(pok.ddrIndicators)
        var i = 0
        while i < hig:
          inc pok.ddrIndicators[i][1]
          if pok.ddrIndicators[i][1] >= 100:
            pok.ddrIndicators.del(i)
            dec hig
          else:
            inc i
    else: discard
  of gsk2d:
    var
      i = 0
      hig = game.state.playerMovement.len
    while i < hig:
      template p: untyped = game.state.playerMovement[i]
      case p.kind
      of pmUp:
        game.state.playerPosition.y += round(p.speed).cint
      of pmRight:
        game.state.playerPosition.x += round(p.speed).cint
      of pmLeft:
        game.state.playerPosition.x -= round(p.speed).cint
      of pmRotate:
        game.state.playerAngle += p.speed
      of pmRotateBackward:
        game.state.playerAngle -= p.speed
      game.state.playerTotalMovement += p.speed.int
      if game.state.playerTotalMovement >= 3133:
        game.progress()
        break
      else:
        if game.state.playerPosition.x notin 0..<1080 or
          game.state.playerPosition.y notin 0..<720:
          game.state.playerPosition = (
            clamp(game.state.playerPosition[0], 0, 1079),
            clamp(game.state.playerPosition[1], 0, 719))
          game.state.playerMovement.del(i)
          dec hig
          continue
        p.speed += p.accel
        inc i
  of gskCredits:
    var h: cint
    game.state.creditsTexture.queryTexture(nil, nil, nil, addr h)
    if game.state.creditsPosition < h - 720:
      game.state.creditsPosition = min(
        game.state.creditsPosition + game.state.creditsSpeed,
        h - 720)
  else: discard
  inc game.numTicks

proc render(game: Game) =
  let wsz = game.window.getSize()
  let (ww, wh) = wsz
  case stateKinds[game.state.kind]
  of gskNoOp: discard
  of gskDialog:
    game.draw(game.state.dialog,
      dest = rect(0, 0, ww, wh))
  of gskPokemon:
    let (aww, awh) = (ww div 2, wh div 2)
    let pok = game.state.pokemon
    if pok.kind == Roy and not pok.challengerTexture.isNil:
      game.draw(pok.challengerTexture, rect(0, 0, ww, wh))
      return
    game.draw(game.state.pokemonTexture, rect(aww, 0, aww, awh))
    game.draw(game.state.pokemonTextbox, rect(0, awh, ww, awh))
    let text = game.state.pokemonText
    if text.rendered.len != 0:
      var rec = rect((50 * ww) div 1080, (50 * wh) div 720 + awh, 0, 0)
      for r in text.rendered:
        r.queryTexture(nil, nil, addr rec.w, addr rec.h)
        rec.w = (rec.w * ww) div 1080
        rec.h = (rec.h * wh) div 720
        if rec.w + rec.x >= ww:
          rec.x = 50 * ww div 1080
          rec.y += rec.h
        game.draw(r, rec)
        rec.x += rec.w
    case pok.kind
    of Yourmurderguy, `Ethereal God`:
      for hi, hiarr in pok.ddrArrows:
        game.draw(hiarr.hitbox, hitbox(pok, hi, wsz))
        for i, arr in hiarr.values:
          game.draw(hiarr.arrow, arrow(pok, hi, i, wsz))
      for val in pok.ddrIndicators:
        let r = game.renderText(val[0], color(216, 20, 145 + val[1], 255))
        game.draw(r, ddrIndicator(wsz, val[1]))
        r.destroy()
    of Troll:
      if not pok.sudokuTexture.isNil:
        var sud = sudoku(pok, wsz)
        game.draw(pok.sudokuTexture, sud)
        if not pok.sudokuCharacterTexture.isNil:
          game.draw(pok.sudokuCharacterTexture, sud)
    of Roy:
      discard
    of Morty:
      for x, y, square in pok.chessBoard.pieces:
        var sq = chessSquare(wsz, x, y)
        if uint8(chessIndex(x, y)) in pok.chessAvailable:
          discard pok.chessBackground.setTextureColorMod(255, 255, 0)
        else:
          let m = uint8(x + y) and 1
          discard pok.chessBackground.setTextureColorMod(m * 189, m * 108 + 147, 150)
        game.draw(pok.chessBackground, sq)
        if square.piece != NoPiece:
          let s = (2u8 - uint8(square.side)) * 255
          discard pok.chessPieceTexture.setTextureColorMod(255, s, s)
          #  quit "Could not set piece texture color mode" & $getError()
          game.draw(pok.chessPieceTexture, sq)
  of gsk2d:
    let pos = game.state.playerPosition
    let player = game.state.playerTexture
    game.draw(game.state.background2d,
      dest = rect(0, 0, ww, wh))
    var playerRect: Rect
    player.queryTexture(nil, nil, addr playerRect.w, addr playerRect.h)
    playerRect.w = (playerRect.w * 1080) div ww
    playerRect.h = (playerRect.h * 720) div wh
    playerRect.x = (pos.x * 1080) div ww
    playerRect.y = ((720 - pos.y) * 720) div wh - playerRect.h
    game.renderer.copyEx(player, nil, addr playerRect, game.state.playerAngle, nil, game.state.playerFlip)
  of gskCredits:
    let credit = game.state.creditsTexture
    let pos = game.state.creditsPosition
    var
      src = rect(0, pos, 1080, 720)
      dest = rect(0, 0, ww, wh)
    game.draw(credit, src, dest)
  else: discard

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

  withSurface loadBMP("res/icon.bmp"):
    game.window.setIcon(it)

  discard openAudio(0, 0, 2, 4096)
  game.update(gsMenu)

  var lastFrameTime = cpuTime()

  while game.state.kind != gsDone:
    game.listen()
    if cpuTime() - lastFrameTime >= (1 / 60):
      game.tick()
      game.renderer.clear()
      game.render()
      game.renderer.present()
      lastFrameTime = cpuTime()

  game.stopMusic()
  closeAudio()
  game.font.close()
  ttfQuit()
  game.window.destroy()
  game.renderer.destroy()

when isMainModule: main()