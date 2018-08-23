import sdl2, sdl2/[mixer, ttf], sdl2/image as sdlimage, /chess, /util

type
  PokemonKind* = enum
    Yourmurderguy, Troll, Roy, `Ethereal God`, Morty

  GameState* = enum
    gsNone, gsDone, gsMenu, gsIntro, gsPokemon, gsOperation

  GameStateKind* = enum
    gskNoOp, gskDialog, gskPokemon, gskOperation

type
  DdrData* = tuple[key: Scancode, hitboxImage, arrowImage: string]

  PokemonData* = object
    image*, cry*: cstring
    text*: seq[string]

  GameStateData* = object
    case kind*: GameStateKind
    of gskNoOp: discard
    of gskDialog:
      dialogImage*, dialogMusic*: cstring
      dialogColor*: Color
    of gskPokemon:
      discard
      # i tried putting an array here for all the individual pokemon data
      # but it kept hanging the compiler so i tried a seq
      # at which point the compiler said the seq was nil even though it was in the initializer
      # so i changed it to a ref object and it gave a SIGSEGV
      # so i made it a separate const
      # UPDATE: THEN i tried putting in a string but it gives an empty string instead of what i set it to.
    of gskOperation:
      discard

const
  stateData*: array[low(GameState)..high(GameState), GameStateData] = [
    GameStateData(kind: gskNoOp), GameStateData(kind: gskNoOp),
    GameStateData(kind: gskDialog, dialogImage: "res/menu.png",
      dialogMusic: "res/menu.mp3", dialogColor: color(221, 247, 255, 255)),
    GameStateData(kind: gskDialog, dialogImage: "res/intro.png",
      dialogMusic: "res/intro.mp3", dialogColor: color(255, 255, 255, 255)),
    GameStateData(kind: gskPokemon),
    GameStateData(kind: gskOperation)]

  textboxImage*: cstring = "res/textbox.png"
  sudokuImage*: cstring = "res/sudoku.png"
  ddrYourmurderguyData*: seq[DdrData] = @[
    (SDL_SCANCODE_UP, "res/ddr/up_hitbox.png", "res/ddr/up_arrow.png"),
    (SDL_SCANCODE_DOWN, "res/ddr/down_hitbox.png", "res/ddr/down_arrow.png"),
    (SDL_SCANCODE_LEFT, "res/ddr/left_hitbox.png", "res/ddr/left_arrow.png"),
    (SDL_SCANCODE_RIGHT, "res/ddr/right_hitbox.png", "res/ddr/right_arrow.png"),
    (SDL_SCANCODE_SPACE, "res/ddr/space_hitbox.png", "res/ddr/space_arrow.png")]
  ddrEtherealGodData*: seq[DdrData] = @[
    (SDL_SCANCODE_UP, "res/ddr/up_hitbox.png", "res/ddr/up_arrow.png"),
    (SDL_SCANCODE_DOWN, "res/ddr/down_hitbox.png", "res/ddr/down_arrow.png"),
    (SDL_SCANCODE_LEFT, "res/ddr/left_hitbox.png", "res/ddr/left_arrow.png"),
    (SDL_SCANCODE_RIGHT, "res/ddr/right_hitbox.png", "res/ddr/right_arrow.png")]

  # if you think this should be in state data read above
  pokemonData*: array[low(PokemonKind)..high(PokemonKind), PokemonData] = [
    PokemonData(image: "res/pokemon/yourmurderguy.png", cry: "res/pokemon/yourmurderguy.mp3",
      text: @["Yourmurderguy joins the battle!", "Your score was $1. Terrible job a!"]),
    PokemonData(image: "res/pokemon/troll.png", cry: "res/pokemon/troll.mp3",
      text: @["Troll challenges you to a mental duel....", "Fill in this one box sudoku by typing a key!.....",
        "What? what's that? what did you type in? its a number? are you not brainy? No more",
        "NO!!!!! MY POWERRRRRRRRR!!!!!!! DUDE!!!!!"]),
    PokemonData(image: "res/pokemon/roy.png", cry: "res/pokemon/roy.mp3",
      text: @["its Roy", "you killed Roy", "Roy watches anime!", "Roy use Portmanteau"]),
    PokemonData(image: "res/pokemon/ethereal god.png", cry: "res/pokemon/ethereal god.mp3",
      text: @["Ethereal God challenges to battle! DGGKPfpt", "Your score was $1! Thank you!"]),
    PokemonData(image: "res/pokemon/morty.png", cry: "res/pokemon/morty.mp3",
      text: @["Morty is Chess."])]

const
  stateKinds* = block:
    var result: array[low(GameState)..high(GameState), GameStateKind]
    for i, data in stateData: result[i] = data.kind
    result
  kindStates* = block:
    var result: array[low(GameStateKind)..high(GameStateKind), set[GameState]]
    for i, data in stateKinds:
      result[data].incl(i)
    result

type
  PokemonText* = object
    rendered*: seq[TexturePtr]
    real*: string
    counter*, delay*: uint32

  Pokemon* = ref object
    case kind*: PokemonKind
    of Yourmurderguy, `Ethereal God`:
      ddrArrows*: seq[tuple[key: Scancode, hitbox: TexturePtr, arrows: seq[tuple[texture: TexturePtr, value: int]]]]
      ddrScore*, ddrCount*: int
    of Troll:
      sudokuTexture*: TexturePtr
      sudokuCharacterTexture*: TexturePtr
    of Roy:
      ourHealth*, royHealth*: int
    of Morty:
      chessBoard*: chess.Board
      chessPieceTextures*: array[Pawn..King, (TexturePtr, TexturePtr)]

  State* = ref object
    case kind*: GameState
    of kindStates[gskNoOp]: discard
    of kindStates[gskDialog]:
      dialog*: TexturePtr
    of gsPokemon:
      pokemon*: Pokemon
      pokemonTexture*, pokemonTextbox*: TexturePtr
      pokemonText*: PokemonText
    of gsOperation:
      discard
    else: discard

  Game* = ref object
    window*: WindowPtr
    renderer*: RendererPtr
    currentAudio*: MusicPtr
    font*: FontPtr
    state*: State

const
  colorBlack* = color(0, 0, 0, 255)
  colorWhite* = color(255, 255, 255, 255)
  defaultText* = PokemonText(real: "", rendered: @[])

#[var
  doneStateVal {.threadvar.}: State
  noneStateVal {.threadvar.}: State

template doneState*: State =
  bind doneStateVal
  if unlikely(doneStateVal.isNil):
    doneStateVal = State(kind: gsDone)
  doneStateVal

template noneState*: State =
  bind noneStateVal
  if unlikely(noneStateVal.isNil):
    doneStateVal = State(kind: gsDone)
  noneStateVal]#

defaultVar doneState, State(kind: gsDone)

proc newPokemonText*(text: string, delay: uint32 = 0): PokemonText =
  PokemonText(real: text, rendered: newSeqOfCap[TexturePtr](text.len), delay: delay)

proc `/`*(a, b: Point): Point =
  (a[0] div b[0], a[1] div b[1])

proc hitbox*(pok: Pokemon, i: int, windowSize: Point): Rect =
  let tex = pok.ddrArrows[i].hitbox
  var w, h: cint
  tex.queryTexture(nil, nil, addr w, addr h)
  let
    startX: cint = cint((5 + i * w) * 1080) div windowSize[0]
    startY: cint = cint(5 * 720) div windowSize[1]
  result = rect(startX, startY, (w * 1080) div windowSize[0], (h * 720) div windowSize[1])

proc arrow*(pok: Pokemon, hi, i: int, windowSize: Point): Rect =
  let arr = pok.ddrArrows[hi]
  let it = arr.arrows[i]
  var w, h: cint
  it.texture.queryTexture(nil, nil, addr w, addr h)
  let
    startX: cint = cint((5 + hi * w) * 1080) div windowSize[0]
    startY: cint = cint((715 - it.value) * 720) div windowSize[1]
  result = rect(startX, startY, (w * 1080) div windowSize[0], (h * 720) div windowSize[1])

proc sudoku*(pok: Pokemon, windowSize: Point): Rect =
  var w, h: cint
  pok.sudokuTexture.queryTexture(nil, nil, addr w, addr h)
  let
    startX: cint = cint((540 - (w div 2)) * 1080) div windowSize[0]
    startY: cint = cint((360 - (h div 2)) * 720) div windowSize[1]
  result = rect(startX, startY, (w * 1080) div windowSize[0], (h * 720) div windowSize[1])

proc loadTexture*(game: Game, image: cstring): TexturePtr =
  withSurface sdlimage.load(image):
    if unlikely(it.isNil):
      quit "Couldn't load texture " & $image & ", error: " & $getError()
    result = createTextureFromSurface(game.renderer, it)

proc setAudio*(game: Game, file: cstring) =
  if not game.currentAudio.isNil:
    discard haltMusic()
    freeMusic(game.currentAudio)
  game.currentAudio = loadMus(file)
  if unlikely(game.currentAudio.isNil):
    quit "Couldn't load audio " & $file & ", error: " & $getError()

template loopAudio*(game: Game) =
  discard playMusic(game.currentAudio, -1)

template playAudio*(game: Game, loops = 1) =
  discard playMusic(game.currentAudio, loops)

proc draw*(game: Game, texture: TexturePtr, src, dest: Rect) =
  var
    src = src
    dest = dest
  game.renderer.copy(texture, addr src, addr dest)

proc draw*(game: Game, texture: TexturePtr, dest: Rect) =
  var w, h: cint
  texture.queryTexture(nil, nil, addr w, addr h)
  var
    src = rect(0, 0, w, h)
    dest = dest
  game.renderer.copy(texture, addr src, addr dest)

proc draw*(game: Game, texture: TexturePtr, x, y: cint) =
  var w, h: cint
  texture.queryTexture(nil, nil, addr w, addr h)
  var
    src = rect(0, 0, w, h)
    dest = rect(x, y, w, h)
  game.renderer.copy(texture, addr src, addr dest)

proc renderText*[T: char | cstring](game: Game, text: T,
                                    font: FontPtr,
                                    color = colorBlack): TexturePtr =
  let surface =
    when T is char:
      renderGlyphSolid(font, text.uint16, color)
    else:
      renderTextSolid(font, text, color)
  withSurface surface:
    result = createTextureFromSurface(game.renderer, it)

template renderText*[T](game: Game, text: T, color = colorBlack): TexturePtr =
  renderText(game, text, game.font, color)