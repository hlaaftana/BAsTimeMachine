import sdl2, sdl2/image as sdlimage, sdl2/mixer
import /data

template tap*(val, body): untyped =
  var it {.inject.} = val
  body
  it

template assertBool*(b, a): untyped =
  let it {.inject.} = a
  assert b

template assertBool*(a): untyped =
  let x = a
  assert x

template withSurface*(surf, body): untyped =
  let it {.inject.} = surf
  body
  freeSurface(it)

proc loadTexture*(game: Game, image: string): SizedTexture =
  withSurface sdlimage.load(image):
    if it.isNil:
      quit "Give me back my " & image
    result.w = it.w
    result.h = it.h
    result.texture = createTextureFromSurface(game.renderer, it)

proc `audio=`*(game: Game, file: string) =
  if not game.currentAudio.isNil:
    discard haltMusic()
    freeMusic(game.currentAudio)
  game.currentAudio = loadMus(file)
  if game.currentAudio.isNil:
    quit "Give me back my " & file

template loopAudio*(game: Game) =
  discard playMusic(game.currentAudio, -1)

proc draw*(game: Game, texture: TexturePtr, src, dest: Rect) =
  game.renderer.copy(texture, unsafeAddr src, unsafeAddr dest)