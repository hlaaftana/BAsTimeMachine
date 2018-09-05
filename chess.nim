const
  width* = 8
  height* = 11

type
  Piece* = enum
    NoPiece, Pawn, Rook, Knight, Bishop, Queen, King

  Side* = enum
    NoSide, White, Black

  Square* = tuple[piece: Piece, side: Side]

  BaseBoard* = array[width * height, Square]
  Board* = distinct BaseBoard

template chessIndex*(x, y: int): int = x * height + y

proc `[]`*(board: Board, x, y: int): Square =
  BaseBoard(board)[chessIndex(x, y)]

proc `[]`*(board: var Board, x, y: int): var Square =
  BaseBoard(board)[chessIndex(x, y)]

proc `[]=`*(board: var Board, x, y: int, val: Square) =
  BaseBoard(board)[chessIndex(x, y)] = val

proc init*(chess: var Board) =
  chess[0, 0] = (Rook, Black)
  chess[1, 0] = (Bishop, White)
  chess[2, 0] = (Bishop, Black)
  chess[4, 0] = (Queen, Black)
  chess[5, 0] = (Rook, Black)
  chess[6, 0] = (King, Black)
  chess[7, 0] = (Pawn, Black)
  chess[7, 10] = (Rook, White)
  chess[6, 10] = (Bishop, White)
  chess[5, 10] = (Bishop, White)
  chess[4, 10] = (Pawn, White)
  chess[3, 10] = (Queen, White)
  chess[2, 10] = (Rook, White)
  chess[1, 10] = (King, White)
  chess[0, 10] = (Pawn, White)
  for i in 0..<width:
    {.unroll.}
    chess[i, 1] = (Knight, Black)
    chess[i, 9] = (Knight, White)
  chess[5, 8] = (Queen, White)

proc move*(chess: var Board, x, y, nx, ny: int): Square =
  let old = addr chess[x, y]
  let replacing = chess[nx, ny]
  chess[nx, ny] = old[]
  old[] = (NoPiece, NoSide)
  result = replacing 

iterator pieces*(chess: Board): tuple[x, y: int, square: Square] =
  for i, it in BaseBoard(chess):
    yield (i div height, i mod height, it)

iterator moves*(chess: Board, x, y: int): tuple[x, y: int] =
  template check(a, b; ap: static[bool] = true, bp: static[bool] = true): untyped =
    if (ap or likely(a in 0..<width)) and
      (bp or likely(b in 0..<height)) and
      chess[a, b][1] != side:
        yield (a, b)

  template checkAndBreak(a, b; ap: static[bool] = true, bp: static[bool] = true): untyped =
    if (ap or likely(a in 0..<width)) and
      (bp or likely(b in 0..<height)):
      if chess[a, b][1] != side:
        yield (a, b)
      else: break

  let (piece, side) = chess[x, y]
  # NoPiece, Pawn, Rook, Knight, Bishop, Queen, King
  case piece
  of NoPiece:
    discard
  of Pawn:
    let ny = y + (ord(side) * 2 - 3)
    check(x, ny, bp = false)
  of Rook:
    for ny in 0..<height:
      {.unroll.}
      checkAndBreak(x, ny)
    for nx in 0..<width:
      {.unroll.}
      checkAndBreak(nx, y)
  of Knight:
    check(x + 2, y + 1, false, false)
    check(x + 2, y - 1, false, false)
    check(x - 2, y + 1, false, false)
    check(x - 2, y - 1, false, false)
    check(x + 1, y + 2, false, false)
    check(x + 1, y - 2, false, false)
    check(x - 1, y + 2, false, false)
    check(x - 1, y - 2, false, false)
  of Bishop:
    for i in max(y - x, 0)..min(x + y, width):
      {.unroll.}
      checkAndBreak(i, x + y - i, false, false)
    for i in max(x - y, 0)..min(x + height - y, width):
      {.unroll.}
      checkAndBreak(i, y - x + i, false, false)
  of Queen:
    for ny in 0..<height:
      {.unroll.}
      checkAndBreak(x, ny)
    for nx in 0..<width:
      {.unroll.}
      checkAndBreak(nx, y)
    for i in max(y - x, 0)..min(x + y, width):
      {.unroll.}
      checkAndBreak(i, x + y - i, false, false)
    for i in max(x - y, 0)..min(x + height - y, width):
      {.unroll.}
      checkAndBreak(i, y - x + i, false, false)
  of King:
    check(x + 1, y + 1, false, false)
    check(x + 1, y, ap = false)
    check(x + 1, y - 1, false, false)
    check(x, y + 1, bp = false)
    check(x, y - 1, bp = false)
    check(x - 1, y + 1, false, false)
    check(x - 1, y, ap = false)
    check(x - 1, y - 1, false, false)

when isMainModule:
  var board: Board
  board.init()

  for x, y, square in board.pieces:
    echo square
    for m in board.moves(x, y):
      echo m
      discard board.move(x, y, m.x, m.y)

  var f: File
  discard f.open("chess.txt", fmReadWrite)
  for i in 0..<height:
    for j in 0..<width:
      let s = board[j, i]
      const oh: array[White..Black, array[Pawn..King, string]] = [
        ["\u2659", "\u2656", "\u2658", "\u2657", "\u2655", "\u2654"],
        ["\u265f", "\u265c", "\u265e", "\u265d", "\u265b", "\u265a"]]
      f.write(if s.side == NoSide: " " else: oh[s.side][s.piece])
    f.write("\n")
  f.close()