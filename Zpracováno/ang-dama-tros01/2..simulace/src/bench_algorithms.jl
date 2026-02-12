include("testvaluefunc.jl")
include("heuristics.jl")
using Dates

# 1. Setup specific board state (10, 14 vs 1)
function setup_benchmark_board()
    board = zeros(Int, 8, 8)
    p10 = notation_to_position(10)
    p14 = notation_to_position(14)
    board[p10.r, p10.c] = WHITE_KING
    board[p14.r, p14.c] = WHITE_KING

    p1 = notation_to_position(1)
    board[p1.r, p1.c] = RED_KING
    return board
end

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
function minimax_smart(board, depth, is_maximizing)
    if depth == 0
        return Float64(perfect_endgame_heuristic(board)), nothing, 1
    end

    player = is_maximizing ? 1 : -1
    moves = get_legal_moves(board, player)

    if isempty(moves)
        return is_maximizing ? -99999.0 : 99999.0, nothing, 1
    end

    move_scores = Tuple{Move,Float64}[]
    for m in moves
        tmp_board = make_move(board, m)
        score = Float64(perfect_endgame_heuristic(tmp_board))
        push!(move_scores, (m, score))
    end

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

# Fake Enum for this script context
const PRUNE_NONE = 0
const PRUNE_LOSS_OF_PIECE = 1
const PRUNE_RETREAT = 2
const PRUNE_HUMAN = 3

# C, D, E, F variants use alphabeta_ordered

function alphabeta_ordered(board, depth, alpha, beta, is_max, pruning_strat)
    # 1. Pruning checks (Pseudo-terminal)
    if pruning_strat == PRUNE_LOSS_OF_PIECE || pruning_strat == PRUNE_RETREAT || pruning_strat == PRUNE_HUMAN
        player_pieces = count(x -> x == WHITE || x == WHITE_KING, board)
        if player_pieces < 2
            return -99999.0, nothing, 1
        end
    end

    if (pruning_strat == PRUNE_RETREAT || pruning_strat == PRUNE_HUMAN) && !is_max
        w_kings = [Position(r, c) for r in 1:8, c in 1:8 if board[r, c] == WHITE_KING]
        r_kings = [Position(r, c) for r in 1:8, c in 1:8 if board[r, c] == RED_KING]

        if length(w_kings) >= 2 && length(r_kings) == 1
            wk1, wk2 = w_kings[1], w_kings[2]
            rk = r_kings[1]
            dist = (max(abs(wk1.r - rk.r), abs(wk1.c - rk.c)) + max(abs(wk2.r - rk.r), abs(wk2.c - rk.c))) / 2.0

            if dist > 4.5
                return -9000.0, nothing, 1
            end
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
    sort!(move_scores, by=x -> x[2], rev=is_max)

    sorted_moves = [x[1] for x in move_scores]

    # HUMAN / FORWARD PRUNING Logic
    if pruning_strat == PRUNE_HUMAN
        # Only consider top K moves. For manual simulation, K=2 is reasonable.
        # "I'll try this one, and maybe this one. The rest look bad."
        k = 2
        if length(sorted_moves) > k
            sorted_moves = sorted_moves[1:k]
        end
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

function run_clever(board, depth)
    start_time = time()
    val, move, nodes = alphabeta_ordered(board, depth, -Inf, Inf, true, PRUNE_NONE)
    duration = time() - start_time
    return duration, nodes
end

function run_pragmatic(board, depth)
    start_time = time()
    val, move, nodes = alphabeta_ordered(board, depth, -Inf, Inf, true, PRUNE_LOSS_OF_PIECE)
    duration = time() - start_time
    return duration, nodes
end

function run_lazy(board, depth)
    start_time = time()
    val, move, nodes = alphabeta_ordered(board, depth, -Inf, Inf, true, PRUNE_RETREAT)
    duration = time() - start_time
    return duration, nodes
end

function run_human(board, depth)
    start_time = time()
    val, move, nodes = alphabeta_ordered(board, depth, -Inf, Inf, true, PRUNE_HUMAN)
    duration = time() - start_time
    return duration, nodes
end

function main()
    board = setup_benchmark_board()
    depth = 6

    println("Running benchmarks for 10,14 vs 1 at depth $depth...")

    t_bf, n_bf = run_brute_force(board, depth)
    println("Brute Force: $(round(t_bf, digits=4))s, $n_bf nodes")

    t_smart, n_smart = run_smart(board, depth)
    println("Smart: $(round(t_smart, digits=4))s, $n_smart nodes")

    t_clever, n_clever = run_clever(board, depth)
    println("Clever: $(round(t_clever, digits=4))s, $n_clever nodes")

    t_prag, n_prag = run_pragmatic(board, depth)
    println("Pragmatic: $(round(t_prag, digits=4))s, $n_prag nodes")

    t_lazy, n_lazy = run_lazy(board, depth)
    println("Lazy: $(round(t_lazy, digits=4))s, $n_lazy nodes")

    t_human, n_human = run_human(board, depth)
    println("Human: $(round(t_human, digits=4))s, $n_human nodes")

    println("\n--- RESULTS FOR TESTS.MD ---")
    println("| brute-force | |  |  | | | $(round(t_bf, digits=3)) | $n_bf |")
    println("| smart | X  |  |  | | | $(round(t_smart, digits=3)) | $n_smart |")
    println("| clever (AB) | X | X |  | | | $(round(t_clever, digits=3)) | $n_clever |")
    println("| pragmatic (AB+Prune) | X | X | X | | | $(round(t_prag, digits=3)) | $n_prag |")
    println("| lazy (Pressure) | X | X | X | X | | $(round(t_lazy, digits=3)) | $n_lazy |")
    println("| human (Beam=2) | X | X | X | X | X | $(round(t_human, digits=3)) | $n_human |")
end

main()
