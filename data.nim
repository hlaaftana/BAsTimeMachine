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
      pokemon*: array[low(Pokemon)..high(Pokemon), tuple[image, cry: string]]

const
  stateData*: array[low(GameState)..high(GameState), GameStateData] = [
    GameStateData(kind: gskNoOp), GameStateData(kind: gskNoOp),
    GameStateData(kind: gskDialog, dialogImage: "res/menu.png",
      dialogMusic: "res/menu.mp3", dialogColor: color(221, 247, 255, 255)),
    GameStateData(kind: gskDialog, dialogImage: "res/intro.png",
      dialogMusic: "res/intro.mp3", dialogColor: color(255, 255, 255, 255)),
    GameStateData(kind: gskPokemon, pokemon: [
      ("res/pokemon/yourmurderguy.png", "res/pokemon/yourmurderguy.mp3"),
      ("res/pokemon/troll.png", "res/pokemon/troll.mp3"),
      ("res/pokemon/roy.png", "res/pokemon/roy.mp3"),
      ("res/pokemon/ethereal god.png", "res/pokemon/ethereal god.mp3"),
      ("res/pokemon/morty.png", "res/pokemon/morty.mp3")])]

const
  stateKinds*: array[low(GameState)..high(GameState), GameStateKind] = block:
    var result: array[low(GameState)..high(GameState), GameStateKind]
    for i, data in stateData: result[i] = data.kind
    result
  kindStates*: array[low(GameStateKind)..high(GameStateKind), set[GameState]] = block:
    var result: array[low(GameStateKind)..high(GameStateKind), set[GameState]]
    for i, data in stateKinds:
      result[data].incl(i)
    result

type
  SizedTexture* = tuple[w, h: cint, texture: TexturePtr]

  State* = object
    case kind*: GameState
    of kindStates[gskNoOp]: discard
    of kindStates[gskDialog]:
      dialog*: SizedTexture
    of gsPokemon:
      currentPokemon*: Pokemon

  Game* = ref object
    window*: WindowPtr
    renderer*: RendererPtr
    currentAudio*: MusicPtr
    state*: State

let
  doneState* = State(kind: gsDone)
  noneState* = State(kind: gsNone)

converter toTexture*(sized: SizedTexture): TexturePtr = sized.texture