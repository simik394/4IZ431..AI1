# ==============================================================================
# KONFIGURACE DESEK PRO ANGLICKOU DÁMU
# ==============================================================================
#
# Tento soubor obsahuje různé počáteční konfigurace desky.
# Každá funkce vrací Matrix{Int} s rozměry 8x8.
#
# POUŽITÍ:
#   include("boards.jl")
#   board = get_board("assignment")
#
# ==============================================================================

# ------------------------------------------------------------------------------
# STANDARDNÍ POČÁTEČNÍ POZICE
# ------------------------------------------------------------------------------

"""
Standardní počáteční pozice anglické dámy.
Červení nahoře (řádky 1-3), Bílí dole (řádky 6-8).
"""
function create_standard_board()
    board = zeros(Int, 8, 8)
    # Červení (nahoře)
    for r in 1:3, c in 1:8
        if (r + c) % 2 == 1
            board[r, c] = RED
        end
    end
    # Bílí (dole)
    for r in 6:8, c in 1:8
        if (r + c) % 2 == 1
            board[r, c] = WHITE
        end
    end
    return board
end

# ------------------------------------------------------------------------------
# ZADÁNÍ ÚLOHY - Koncovka
# ------------------------------------------------------------------------------

"""
ZADÁNÍ ÚLOHY:
- Bílý: 2 králové na pozicích 10 a 14
- Červený: 1 král na pozici 1
- Bílý je na tahu
"""
function create_assignment_board()
    board = zeros(Int, 8, 8)

    # Červený král na pozici 1
    pos1 = notation_to_position(1)
    board[pos1.r, pos1.c] = RED_KING

    # Bílý král na pozici 10
    pos10 = notation_to_position(10)
    board[pos10.r, pos10.c] = WHITE_KING

    # Bílý král na pozici 14
    pos14 = notation_to_position(14)
    board[pos14.r, pos14.c] = WHITE_KING

    return board
end

# ------------------------------------------------------------------------------
# PŘÍKLADY KONCOVEK
# ------------------------------------------------------------------------------

"""
Koncovka 2v2 - dva králové na každé straně.
"""
function create_endgame_2v2()
    board = zeros(Int, 8, 8)

    # Bílí králové
    pos = notation_to_position(18)
    board[pos.r, pos.c] = WHITE_KING
    pos = notation_to_position(22)
    board[pos.r, pos.c] = WHITE_KING

    # Červení králové
    pos = notation_to_position(3)
    board[pos.r, pos.c] = RED_KING
    pos = notation_to_position(7)
    board[pos.r, pos.c] = RED_KING

    return board
end

"""
Koncovka 3v1 - přesila bílého.
"""
function create_endgame_3v1()
    board = zeros(Int, 8, 8)

    # Bílí králové
    for n in [14, 18, 22]
        pos = notation_to_position(n)
        board[pos.r, pos.c] = WHITE_KING
    end

    # Červený král
    pos = notation_to_position(5)
    board[pos.r, pos.c] = RED_KING

    return board
end

"""
Střední hra - po několika tazích.
"""
function create_midgame()
    board = zeros(Int, 8, 8)

    # Bílí pěšci
    for n in [21, 22, 25, 26, 29, 30]
        pos = notation_to_position(n)
        board[pos.r, pos.c] = WHITE
    end

    # Červení pěšci
    for n in [1, 2, 5, 6, 9, 10]
        pos = notation_to_position(n)
        board[pos.r, pos.c] = RED
    end

    return board
end

# ------------------------------------------------------------------------------
# VLASTNÍ KONFIGURACE
# ------------------------------------------------------------------------------

"""
Prázdná deska pro vlastní nastavení.
"""
function create_empty_board()
    return zeros(Int, 8, 8)
end

"""
Vytvoří desku z popisu pozic.

Příklad:
  create_board_from_pieces(
      white_pieces = [21, 22],
      white_kings = [14],
      red_pieces = [5, 6],
      red_kings = [1]
  )
"""
function create_board_from_pieces(;
    white_pieces::Vector{Int}=Int[],
    white_kings::Vector{Int}=Int[],
    red_pieces::Vector{Int}=Int[],
    red_kings::Vector{Int}=Int[]
)
    board = zeros(Int, 8, 8)

    for n in white_pieces
        pos = notation_to_position(n)
        board[pos.r, pos.c] = WHITE
    end

    for n in white_kings
        pos = notation_to_position(n)
        board[pos.r, pos.c] = WHITE_KING
    end

    for n in red_pieces
        pos = notation_to_position(n)
        board[pos.r, pos.c] = RED
    end

    for n in red_kings
        pos = notation_to_position(n)
        board[pos.r, pos.c] = RED_KING
    end

    return board
end

# ------------------------------------------------------------------------------
# REGISTR DESEK
# ------------------------------------------------------------------------------

const BOARDS = Dict(
    "standard" => create_standard_board,
    "assignment" => create_assignment_board,
    "endgame_2v2" => create_endgame_2v2,
    "endgame_3v1" => create_endgame_3v1,
    "midgame" => create_midgame,
    "empty" => create_empty_board
)

"""
Vrátí desku podle názvu.
Dostupné: standard, assignment, endgame_2v2, endgame_3v1, midgame, empty
"""
function get_board(name::String)
    if haskey(BOARDS, name)
        return BOARDS[name]()
    else
        error("Neznámá deska: $name. Dostupné: $(keys(BOARDS))")
    end
end

"""
Vypíše dostupné konfigurace desek.
"""
function list_boards()
    println("Dostupné konfigurace desek:")
    for (name, _) in BOARDS
        println("  - $name")
    end
end
