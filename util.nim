import sdl2, sdl2/ttf

template defaultVar*(name, value): untyped {.dirty.} = 
  var `name val` {.threadvar, gensym.}: type(value)
  template `name`*: type(value) =
    if `name val`.isNil:
      `name val` = value
    `name val`

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

template modsHeldDown*: bool =
  (getModState().cint and (
    KMOD_LCTRL.cint or KMOD_RCTRL.cint or
    KMOD_LSHIFT.cint or KMOD_RSHIFT.cint or
    KMOD_LALT.cint or KMOD_RALT.cint)) != 0

template rgb*(x: int32): Color =
  cast[Color]((x shl 8) or 0xFF)

template rgba*(x: int32): Color =
  cast[Color](x)