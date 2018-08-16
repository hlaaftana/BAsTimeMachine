import sdl2, sdl2/mixer

type
  Pokemon* = enum
    Yourmurderguy, Troll, Roy, `Ethereal God`, Morty

  GameState* = enum
    gsNone, gsDone, gsMenu, gsIntro, gsPokemon

  GameStateKind* = enum
    gskNoOp, gskDialog, gskPokemon

type
  GameStateData* = object
    case kind*: GameStateKind
    of gskNoOp: discard
    of gskDialog:
      dialogImage*, dialogMusic*: string
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

  textboxImage* = "res/textbox.png"

  # if you think this should be in state data read above
  pokemonData*: array[low(Pokemon)..high(Pokemon), tuple[image, cry: string]] = [
    ("res/pokemon/yourmurderguy.png", "res/pokemon/yourmurderguy.mp3"),
    ("res/pokemon/troll.png", "res/pokemon/troll.mp3"),
    ("res/pokemon/roy.png", "res/pokemon/roy.mp3"),
    ("res/pokemon/ethereal god.png", "res/pokemon/ethereal god.mp3"),
    ("res/pokemon/morty.png", "res/pokemon/morty.mp3")]

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
  State* = object
    case kind*: GameState
    of kindStates[gskNoOp]: discard
    of kindStates[gskDialog]:
      dialog*: TexturePtr
    of gsPokemon:
      currentPokemon*: Pokemon
      pokemonTexture*: TexturePtr
      pokemonTextbox*: TexturePtr
    else: discard

  Game* = ref object
    window*: WindowPtr
    renderer*: RendererPtr
    currentAudio*: MusicPtr
    state*: State

let
  doneState* = State(kind: gsDone)
  noneState* = State(kind: gsNone)