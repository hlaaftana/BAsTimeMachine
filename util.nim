import sdl2, sdl2/[mixer, ttf], sdl2/image as sdlimage
import /data

template tap*(val, body): untyped =
  var it {.inject.} = val
  body
  it

template assertBool*(a): untyped =
  let x = a
  assert x

template withSurface*(surf, body): untyped {.dirty.} =
  let it = surf
  body
  freeSurface(it)

proc loadTexture*(game: Game, image: cstring): TexturePtr =
  withSurface sdlimage.load(image):
    if unlikely(it.isNil):
      quit "Give me back my " & $image
    result = createTextureFromSurface(game.renderer, it)

proc setAudio*(game: Game, file: cstring) =
  if not game.currentAudio.isNil:
    discard haltMusic()
    freeMusic(game.currentAudio)
  game.currentAudio = loadMus(file)
  if unlikely(game.currentAudio.isNil):
    quit "Give me back my " & $file

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

proc font*(name: cstring, size: cint): FontPtr =
  const win = defined(windows)
  when win:
    result = openFont(cstring(r"C:\Windows\Fonts\" & $name), size)
  if not win or result.isNil:
    result = openFont(name, size)
  if unlikely(result.isNil):
    quit("Can't find font " & $name)