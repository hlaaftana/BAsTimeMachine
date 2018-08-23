import sdl2, sdl2/ttf

template defaultVar*(name, value): untyped {.dirty.} = 
  var `name val` {.threadvar, gensym.}: type(value)
  template `name`*: type(value) =
    if `name val`.isNil:
      `name val` = value
    `name val`

template tap*(val, body): untyped =
  var it {.inject.} = val
  body
  it

template assertBool*(a): untyped =
  let x = a
  assert x

template withSurface*(surf: SurfacePtr, body: untyped): untyped {.dirty.} =
  let it = surf
  if unlikely(it.isNil):
    quit "Surface was nil, error: " & $getError()
  body
  freeSurface(it)

proc font*(name: cstring, size: cint): FontPtr =
  const win = defined(windows)
  when win:
    result = openFont(cstring(r"C:\Windows\Fonts\" & $name), size)
  if not win or result.isNil:
    result = openFont(cstring("res/" & $name), size)
  if unlikely(result.isNil):
    quit("Can't find font " & $name & ", error: " & $getError())

proc toCstring*(c: char): cstring =
  var res = [c, '\0']
  result = cast[cstring](addr res)