include("testvaluefunc.jl")
include("heuristics.jl")
using Dates

# 1. Setup specific board state (10, 14 vs 1)
function setup_benchmark_board()
    board = zeros(Int, 8, 8)
    # White Kings at 10, 14
    p10 = notation_to_position(10)
    p14 = notation_to_position(14)
    board[p10.r, p10.c] = WHITE_KING
    board[p14.r, p14.c] = WHITE_KING

    # Red King at 1
    p1 = notation_to_position(1)
    board[p1.r, p1.c] = RED_KING

    return board
end

# 2. Define Algorithms
# We need to wrap existing functionality to match the requested variants

# A. Brute-force: Minimax, No Pruning, No Move Ordering
# A. Brute-force: Minimax, No Pruning, No Move Ordering
function minimax_no_pruning(board::Matrix{Int}, depth::Int, is_maximizing::Bool)
    if depth == 0
        return Float64(perfect_endgame_heuristic(board)), nothing, 1
    end

    player = is_maximizing ? 1 : -1
    moves = get_legal_moves(board, player)

    if isempty(moves)
        return is_maximizing ? -99999.0 : 99999.0, nothing, 1
    end

    best_move = moves[1]
    total_nodes = 1

    if is_maximizing
        max_eval = -Inf
        for move in moves
            new_board = make_move(board, move)
            score, _, nodes = minimax_no_pruning(new_board, depth - 1, false)
            total_nodes += nodes
            if score > max_eval
                max_eval = score
                best_move = move
            end
        end
        return max_eval, best_move, total_nodes
    else
        min_eval = Inf
        for move in moves
            new_board = make_move(board, move)
            score, _, nodes = minimax_no_pruning(new_board, depth - 1, true)
            total_nodes += nodes
            if score < min_eval
                min_eval = score
                best_move = move
            end
        end
        return min_eval, best_move, total_nodes
    end
end

function run_brute_force(board, depth)
    start_time = time()
    val, move, nodes = minimax_no_pruning(board, depth, true)
    duration = time() - start_time

    return duration, nodes
end

# B. Smart: Minimax + Move Ordering (No Alpha-Beta)
# We need to implement this as it might not exist explicitly. 
# We'll adapt minimax_no_pruning to sort moves.
function minimax_smart(board, depth, is_maximizing)
    if depth == 0
        return Float64(perfect_endgame_heuristic(board)), nothing, 1
    end

    player = is_maximizing ? 1 : -1
    moves = get_legal_moves(board, player)

    if isempty(moves)
        return is_maximizing ? -99999.0 : 99999.0, nothing, 1
    end

    # MOVE ORDERING
    # Evaluate moves with heuristic to sort them
    move_scores = Tuple{Move,Float64}[]
    for m in moves
        # Quick eval: apply move and check heuristic
        tmp_board = make_move(board, m)
        # Simple heuristic eval for ordering
        score = Float64(perfect_endgame_heuristic(tmp_board))
        # If maximizing, we want highest score. If minimizing, lowest? 
        # Actually for move ordering in Minimax:
        # If I am MAX, I want to try moves that give me MAX score first? 
        # Yes, standard move ordering.
        push!(move_scores, (m, score))
    end

    # Sort: Descending for MAX, Ascending for MIN? 
    # Actually, to find best move fast, yes. But without pruning, ordering preserves node count!
    # WAIT. Pure Minimax inspects ALL nodes. Move ordering DOES NOT reduce nodes in pure Minimax.
    # It only helps if we have pruning (Alpha-Beta).
    # "Smart" without pruning = Brute Force in terms of nodes. 
    # Unless "Smart" implies some partial pruning or just optimization?
    # User asked for "Smart | X | |". X in Move Ordering column. 
    # If it's pure logic, nodes should be same as Brute Force.
    # But maybe user implies "Move Ordering" helps Alpha-Beta?
    # The table row says: "smart", "move ordering" checked, "alpha-beta" empty.
    # So it is Minimax + Ordering. Nodes will be same as Brute Force.
    # Unless there is a cut-off? No.
    # We will implement it, but expect same nodes.

    # RE-READING: "smart | X | |"
    # Maybe user expects us to implement it and see?

    sort!(move_scores, by=x -> x[2], rev=is_maximizing)
    sorted_moves = [x[1] for x in move_scores]

    best_move = sorted_moves[1]
    total_nodes = 1

    if is_maximizing
        max_eval = -Inf
        for move in sorted_moves
            new_board = make_move(board, move)
            score, _, nodes = minimax_smart(new_board, depth - 1, false)
            total_nodes += nodes
            if score > max_eval
                max_eval = score
                best_move = move
            end
        end
        return max_eval, best_move, total_nodes
    else
        min_eval = Inf
        for move in sorted_moves
            new_board = make_move(board, move)
            score, _, nodes = minimax_smart(new_board, depth - 1, true)
            total_nodes += nodes
            if score < min_eval
                min_eval = score
                best_move = move
            end
        end
        return min_eval, best_move, total_nodes
    end
end

function run_smart(board, depth)
    start_time = time()
    val, move, nodes = minimax_smart(board, depth, true)
    duration = time() - start_time
    return duration, nodes
end


# C. Clever: Alpha-Beta + Move Ordering
# This is our standard `minimax_with_tree` BUT we need to ensure pruning is standard (Alpha-Beta only),
# without the "loss of piece" pruning if that's what "Pragmatic" is.
# Checking testvaluefunc.jl `minimax_with_tree`:
# It has `pruning::PruningStrategy`. 
# PRUNE_NONE means only Alpha-Beta.
# PRUNE_LOSS_OF_PIECE means Alpha-Beta + Extra logic.
# So "Clever" = PRUNE_NONE.
function run_clever(board, depth)
    global tree_enabled = false # No viz for benchmark
    start_time = time()
    # Note: testvaluefunc's minimax_with_tree returns nodes in global counter?
    # No, it returns (score, move, node_id). 
    # We need to capture node count.
    # run_alphabeta_stats in testvaluefunc.jl does exactly this: resets `tree_nodes` and returns length.

    # We need to make sure Move Ordering is ON. 
    # `minimax_with_tree` doesn't seem to implement move ordering explicitly in the code snippet I saw!
    # I need to check `testvaluefunc.jl` again or implement a version WITH ordering.
    # The snippet of `minimax_with_tree` ended at line 800 roughly. 
    # Move ordering logic might be further down or missing.
    # LIMITATION: I can't check the file again easily inside this script creation.
    # I will assume I need to implement a "clever" wrapper that does ordering + AB.

    val, move, nodes = alphabeta_ordered(board, depth, -Inf, Inf, true, PRUNE_NONE)
    duration = time() - start_time
    return duration, nodes
end

# D. Pragmatic: Alpha-Beta + Move Ordering + 1v1 Pruning
# This is "Clever" + PRUNE_LOSS_OF_PIECE
function run_pragmatic(board, depth)
    global tree_enabled = true # We want to visualize this one!
    # Wait, benchmark shouldn't visualize. But we need to log it for Chapter 9?
    # Separate run for visualization.
    global tree_enabled = false

    start_time = time()
    val, move, nodes = alphabeta_ordered(board, depth, -Inf, Inf, true, PRUNE_LOSS_OF_PIECE)
    duration = time() - start_time
    return duration, nodes
end


# 3. Dedicated Alpha-Beta with Move Ordering Implementation
# (Since I'm not 100% sure it's in testvaluefunc.jl)
function alphabeta_ordered(board, depth, alpha, beta, is_max, pruning_strat)
    # 1. Pruning checks (Pseudo-terminal)
    if pruning_strat == PRUNE_LOSS_OF_PIECE
        player_pieces = count(x -> x == WHITE || x == WHITE_KING, board)
        if player_pieces < 2
            return -99999.0, nothing, 1
        end
    end

    if depth == 0
        return Float64(perfect_endgame_heuristic(board)), nothing, 1
    end

    player = is_max ? 1 : -1
    moves = get_legal_moves(board, player)

    if isempty(moves)
        return is_max ? -99999.0 : 99999.0, nothing, 1
    end

    # MOVE ORDERING
    move_scores = Tuple{Move,Float64}[]
    for m in moves
        tmp = make_move(board, m)
        score = Float64(perfect_endgame_heuristic(tmp))
        push!(move_scores, (m, score))
    end
    sort!(move_scores, by=x -> x[2], rev=is_max) # Descending for Max, Ascending? No, Min wants low score, so best move for Min is lowest score. 
    # Wait. Heuristic is always "White advantage". 
    # Max (White) wants High score -> Descending sort (try high first).
    # Min (Red) wants Low score -> Ascending sort (try low first).

    sorted_moves = [x[1] for x in move_scores]
    if !is_max
        reverse!(sorted_moves) # If we sorted descending, Min needs ascending (reverse)
        # Actually checking sort!: `rev=is_max`. 
        # is_max=true -> rev=true (Descending) -> Good for White.
        # is_max=false -> rev=false (Ascending) -> Good for Red.
        # So `sorted_moves` is already correct. No need to reverse.
    end

    best_move = sorted_moves[1]
    total_nodes = 1

    if is_max
        for move in sorted_moves
            new_board = make_move(board, move)
            score, _, nodes = alphabeta_ordered(new_board, depth - 1, alpha, beta, false, pruning_strat)
            total_nodes += nodes
            if score > alpha
                alpha = score
                best_move = move
            end
            if alpha >= beta
                break # Beta cutoff
            end
        end
        return alpha, best_move, total_nodes
    else
        for move in sorted_moves
            new_board = make_move(board, move)
            score, _, nodes = alphabeta_ordered(new_board, depth - 1, alpha, beta, true, pruning_strat)
            total_nodes += nodes
            if score < beta
                beta = score
                best_move = move
            end
            if beta <= alpha
                break # Alpha cutoff
            end
        end
        return beta, best_move, total_nodes
    end
end


# 4. Main Execution
function main()
    board = setup_benchmark_board()
    depth = 6 # Standard depth from paper

    println("Running benchmarks for 10,14 vs 1 at depth $depth...")

    # 1. Brute Force
    t_bf, n_bf = run_brute_force(board, depth)
    println("Brute Force: $(round(t_bf, digits=4))s, $n_bf nodes")

    # 2. Smart
    t_smart, n_smart = run_smart(board, depth)
    println("Smart: $(round(t_smart, digits=4))s, $n_smart nodes")

    # 3. Clever
    t_clever, n_clever = run_clever(board, depth)
    println("Clever: $(round(t_clever, digits=4))s, $n_clever nodes")

    # 4. Pragmatic
    t_prag, n_prag = run_pragmatic(board, depth)
    println("Pragmatic: $(round(t_prag, digits=4))s, $n_prag nodes")

    # OUTPUT formatted for replacement
    println("\n--- RESULTS FOR TESTS.MD ---")
    println("| brute-force | |  |  | $(round(t_bf, digits=3)) | $n_bf |")
    println("| smart | X  |  |  | $(round(t_smart, digits=3)) | $n_smart |")
    println("| clever (AB) | X | X |  | $(round(t_clever, digits=3)) | $n_clever |")
    println("| pragmatic (AB+Prune) | X | X | X | $(round(t_prag, digits=3)) | $n_prag |")
end

main()
