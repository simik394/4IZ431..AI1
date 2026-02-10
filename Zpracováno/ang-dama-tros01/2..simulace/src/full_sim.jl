using Dates
include("testvaluefunc.jl")

timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
output_dir = joinpath("simulation_outputs", "run_$(timestamp)")
mkpath(output_dir)
output_file = joinpath(output_dir, "pruběh_simulace.txt") # Correct filename

# Redirect stdout to file
original_stdout = stdout
redirect_stdout(open(output_file, "w"))

println("
======================================================================
       ZADÁNÍ: KONCOVKA V ANGLICKÉ DÁMĚ
======================================================================
Bílý: 2 králové na pozicích 10 a 14
Červený: 1 král na pozici 1
Bílý je na tahu.
Hloubka prohledávání: 5 (2.5 tahu každého hráče)
======================================================================")

board = create_empty_board()
board[1, 2] = RED_KING; # R@1
board[3, 4] = WHITE_KING; # W@10
board[4, 3] = WHITE_KING; # W@14

println("\nPočáteční pozice:
  R@1 (červený král)
  W@10, W@14 (bílí králové)")

empty!(GAME_POSITION_HISTORY) # Use global history and clear it
history = GAME_POSITION_HISTORY

function check_status(board, turn, history)
    is_w = turn % 2 == 1
    p = is_w ? WHITE : -1
    moves = get_legal_moves(board, p)

    if isempty(moves)
        winner = is_w ? "RED" : "WHITE"
        println("\n🏆 WINNER: $winner")
        println("(Player $(is_w ? "WHITE" : "RED") has no moves)")
        return true
    end

    h = hash(board, hash(p))
    history[h] = get(history, h, 0) + 1
    if history[h] >= 3
        println("\n🤝 DRAW: Threefold Repetition")
        return true
    end
    return false
end

println("Start Position: R@1, W@10, W@14")
println("Running up to 100 turns...")

for t in 1:20
    if check_status(board, t, history)
        break
    end

    is_w = t % 2 == 1
    # Depth 5 for strong play
    sc, mv = minimax(board, 5, -Inf, Inf, is_w)

    player_str = is_w ? "WHITE" : "RED  "
    move_str = format_move(mv)
    println("Turn $t: $player_str plays $move_str (Score: $sc)")

    global board = make_move(board, mv)

    # Print board occasionally
    if t % 4 == 0
        println("\n--- Board after Turn $t ---")
        print_board(board)
        println("---------------------------")
    end
end

println("\n=== FINAL POSITION ===")
print_board(board)
