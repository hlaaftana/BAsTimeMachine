import sdl2, sdl2/mixer, /chess

type
  PokemonKind* = enum
    Yourmurderguy, Troll, Roy, `Ethereal God`, Morty

  GameState* = enum
    gsNone, gsDone, gsMenu, gsIntro, gsPokemon

  GameStateKind* = enum
    gskNoOp, gskDialog, gskPokemon

type
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

const
  stateData*: array[low(GameState)..high(GameState), GameStateData] = [
    GameStateData(kind: gskNoOp), GameStateData(kind: gskNoOp),
    GameStateData(kind: gskDialog, dialogImage: "res/menu.png",
      dialogMusic: "res/menu.mp3", dialogColor: color(221, 247, 255, 255)),
    GameStateData(kind: gskDialog, dialogImage: "res/intro.png",
      dialogMusic: "res/intro.mp3", dialogColor: color(255, 255, 255, 255)),
    GameStateData(kind: gskPokemon)]

  textboxImage*: cstring = "res/textbox.png"

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
    delay*: int

  Pokemon* = object
    case kind*: PokemonKind
    of Yourmurderguy, `Ethereal God`:
      ddrArrows*: seq[tuple[hitbox: TexturePtr, arrows: seq[tuple[texture: TexturePtr, value: int]]]]
      ddrScore*, ddrCount*: int
    of Troll:
      sudokuTexture*: TexturePtr
      sudokuCharacterTexture*: TexturePtr
    of Roy:
      ourHealth*, royHealth*: int
    of Morty:
      chessBoard*: chess.Board
      chessPieceTextures*: array[Pawn..King, (TexturePtr, TexturePtr)]

  State* = object
    case kind*: GameState
    of kindStates[gskNoOp]: discard
    of kindStates[gskDialog]:
      dialog*: TexturePtr
    of gsPokemon:
      pokemon*: Pokemon
      pokemonTexture*, pokemonTextbox*: TexturePtr
      pokemonText*: PokemonText
    else: discard

  Game* = ref object
    window*: WindowPtr
    renderer*: RendererPtr
    currentAudio*: MusicPtr
    state*: State

let
  doneState* = State(kind: gsDone)
  noneState* = State(kind: gsNone)

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