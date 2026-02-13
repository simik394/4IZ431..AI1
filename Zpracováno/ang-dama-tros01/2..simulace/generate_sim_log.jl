
# Script to generate pruběh_simulace.txt for documentation
# Simulates a standard game (2 kings vs 1 king, close proximity) to generate stats.

include("src/heuristics.jl")
include("src/testvaluefunc.jl")

using Dates

# Setup Standard Board (W@10,14 R@1)
function setup_standard_board()
    board = zeros(Int, 8, 8)
    p10 = notation_to_position(10)
    board[p10.r, p10.c] = WHITE_KING
    p14 = notation_to_position(14)
    board[p14.r, p14.c] = WHITE_KING
    p1 = notation_to_position(1)
    board[p1.r, p1.c] = RED_KING
    return board
end

function run_logging_sim()
    board = setup_standard_board()
    depth = 6

    # Open file for writing
    open("pruběh_simulace.txt", "w") do io
        println(io, "Simulace: 2 bílí králové vs 1 červený král")
        println(io, "Bílý: 2 králové na pozicích 10, 14")
        println(io, "Červený: 1 král na pozici 1")
        println(io, "Hloubka prohledávání: $depth")
        println(io, "Strategie: Lazy (PRUNE_RETREAT)")
        println(io, "-"^40)

        current_board = copy(board)
        turn = 0
        max_turns = 20 # Limit to prevent infinite loops if any

        while turn < max_turns
            turn += 1

            # --- WHITE TURN ---
            p_white = 1
            moves_w = get_legal_moves(current_board, p_white)
            if isempty(moves_w)
                println(io, "Hra končí: Bílý nemá tahy.")
                break
            end

            # Run AlphaBeta with logging data structure (we need to inspect returned nodes)
            # We use alphabeta_ordered_bench but need to modify it or interpret its output
            # Actually, let's use global tree_nodes from run_alphabeta_stats logic if possible, 
            # or just use the bench function and log the result.

            best_score = -Inf
            best_move = nothing
            total_nodes = 0

            # Search best move for White
            score, move, nodes = alphabeta_ordered_bench(current_board, depth, -Inf, Inf, true, 2) # 2 = Lazy

            println(io, "Tah $turn.0: BÍLÝ (MAX)")
            println(io, "Nejlepší tah: $(move_to_string(move))")
            println(io, "Očekávané skóre: $score")
            println(io, "Počet uzlů ve stromu: $nodes")

            current_board = make_move(current_board, move)
            eval = perfect_endgame_heuristic(current_board)
            println(io, "Pozice: $(board_to_notation(current_board))")
            println(io, "Hodnocení: $eval")
            println(io, "─"^40)

            if score >= 99999
                println(io, "VÍTĚZSTVÍ BÍLÝHO DETEKOVÁNO")
                break
            end

            # --- RED TURN ---
            p_red = -1
            moves_r = get_legal_moves(current_board, p_red)
            if isempty(moves_r)
                println(io, "Hra končí: Červený nemá tahy (BÍLÝ VYHRÁL).")
                break
            end

            # Search best move for Red (Minimizing)
            score_r, move_r, nodes_r = alphabeta_ordered_bench(current_board, depth, -Inf, Inf, false, 2)

            println(io, "Tah $turn.5: ČERVENÝ (MIN)")
            println(io, "Nejlepší tah: $(move_to_string(move_r))")
            println(io, "Očekávané skóre: $score_r")
            println(io, "Počet uzlů ve stromu: $nodes_r")

            current_board = make_move(current_board, move_r)
            eval_r = perfect_endgame_heuristic(current_board)
            println(io, "Pozice: $(board_to_notation(current_board))")
            println(io, "Hodnocení: $eval_r")
            println(io, "─"^40)

            if score_r <= -99999
                println(io, "PROHRA ČERVENÉHO DETEKOVÁNA")
                break
            end
        end
        println(io, "Simulace dokončena.")
        if turn < max_turns
            println(io, "BÍLÝ VYHRÁL")
        end
    end
end

# Helper to format board positions
function board_to_notation(board)
    whites = []
    reds = []
    for r in 1:8, c in 1:8
        if board[r, c] == WHITE || board[r, c] == WHITE_KING
            push!(whites, position_to_notation(Position(r, c)))
        elseif board[r, c] == RED || board[r, c] == RED_KING
            push!(reds, position_to_notation(Position(r, c)))
        end
    end
    return "W: $(join(whites, ",")) R: $(join(reds, ","))"
end

run_logging_sim()
