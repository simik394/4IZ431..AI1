include("testvaluefunc.jl")
using Random

# Funkce pro vytvoření náhodné 2v1 pozice
function create_random_2v1_board()
    while true
        board = zeros(Int, 8, 8)

        # Umísti červeného krále
        while true
            r, c = rand(1:8), rand(1:8)
            if (r + c) % 2 == 1
                board[r, c] = RED_KING
                break
            end
        end

        # Umísti 2 bílé krále
        placed = 0
        while placed < 2
            r, c = rand(1:8), rand(1:8)
            if (r + c) % 2 == 1 && board[r, c] == 0
                board[r, c] = WHITE_KING
                placed += 1
            end
        end
        return board
    end
end

function run_tournament(n_games::Int; depth::Int=5)
    println("================================================================")
    println("SPOUŠTÍM TURNAJ $n_games NÁHODNÝCH HER (2v1) @ DEPTH $depth")
    println("================================================================")

    wins_baseline = 0
    wins_fixed = 0

    # Pro každou hru vygenerujeme náhodnou pozici a spustíme obě verze
    for i in 1:n_games
        board = create_random_2v1_board()
        println("\n--- HRA $i ---")

        # 1. BASELINE (s Net Formation)
        res_baseline = play_game(copy(board), DEFAULT_CONFIG, depth)
        if res_baseline == "WHITE"
            wins_baseline += 1
        end

        # 2. FIXED (bez Net Formation)
        config_fixed = HeuristicConfig(use_net=false)
        res_fixed = play_game(copy(board), config_fixed, depth)
        if res_fixed == "WHITE"
            wins_fixed += 1
        end

        println("  Baseline (With Net): $res_baseline")
        println("  Fixed    (No Net):   $res_fixed")
    end

    println("\n================================================================")
    println("VÝSLEDKY TURNAJE (Depth $depth):")
    println("  Baseline (With Net): $wins_baseline / $n_games výher")
    println("  Fixed    (No Net):   $wins_fixed / $n_games výher")
    println("================================================================")
end

function play_game(board, config, depth)
    position_history = Dict{UInt64,Int}()

    for t in 1:60 # Limit 60 tahů
        # Detekce opakování
        bh = hash(board, hash(true))
        position_history[bh] = get(position_history, bh, 0) + 1
        if position_history[bh] >= 3
            return "DRAW (Repetition)"
        end

        # BÍLÝ TAH
        score_w, move_w = minimax(board, depth, -Inf, Inf, true; config=config, pruning=PRUNE_LOSS_OF_PIECE)
        if move_w === nothing
            return "RED (No moves)"
        end
        board = make_move(board, move_w)

        stats = board_stats(board)
        if stats.red_pieces + stats.red_kings == 0
            return "WHITE"
        end

        # Detekce opakování
        bh = hash(board, hash(false))
        position_history[bh] = get(position_history, bh, 0) + 1
        if position_history[bh] >= 3
            return "DRAW (Repetition)"
        end

        # ČERVENÝ TAH
        score_r, move_r = minimax(board, depth, -Inf, Inf, false; config=config, pruning=PRUNE_LOSS_OF_PIECE)
        if move_r === nothing
            return "WHITE (No moves)"
        end
        board = make_move(board, move_r)

        stats = board_stats(board)
        if stats.white_pieces + stats.white_kings == 0
            return "RED"
        end
    end

    return "DRAW (Timeout)"
end

run_tournament(10; depth=5)
