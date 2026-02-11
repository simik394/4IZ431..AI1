include("../src/testvaluefunc.jl")
using Dates

function run_benchmark()
    println("="^80)
    println("BENCHMARK FOR TESTS.MD TABLE")
    println("="^80)

    # Use Assignment Board at Depth 6 as the standard benchmark
    board = get_board("assignment")
    depth = 6

    println("Board: Assignment")
    println("Depth: $depth")
    println("-"^80)
    println(rpad("Configuration", 20) * " | " * rpad("Time (s)", 10) * " | " * rpad("Nodes", 10))
    println("-"^80)

    # 1. BRUTE FORCE (Pure Minimax)
    global node_counter = 0
    Main.node_counter = 0
    t_start = now()
    # Pure minimax doesn't support pruning config, inherently no pruning
    minimax_pure(board, depth, true, "")
    t_pure = (now() - t_start).value / 1000.0
    nodes_pure = Main.node_counter
    println(rpad("Brute Force", 20) * " | " * rpad(round(t_pure, digits=4), 10) * " | " * rpad(nodes_pure, 10))

    # 2. CLEVER (Alpha-Beta, No Pruning, No Move Ordering?)
    # Default get_legal_moves does heuristic ordering? No.
    # We use PRUNE_NONE.
    Main.node_counter = 0
    restore_tree = Main.tree_enabled
    Main.tree_enabled = false

    t_start = now()
    minimax_with_tree(board, depth, -Inf, Inf, true, 0, ""; pruning=PRUNE_NONE)
    t_clever = (now() - t_start).value / 1000.0
    # Note: node_counter in minimax_with_tree only counts if tree_enabled=true usually.
    # But wait, we disabled tree logging in compare_algos.jl to speed up.
    # If we want to count nodes, we must ensure node_counter is incremented OR trust time.
    # Using Time is safer for now.
    println(rpad("Clever (AB)", 20) * " | " * rpad(round(t_clever, digits=4), 10) * " | " * rpad("N/A", 10))

    # 3. GENIOUS (Alpha-Beta + Ordering)
    # We don't have explicit Move Ordering flag in minimax_with_tree yet.
    # It just iterates `moves = get_legal_moves`.
    # To implement "Genious", we need to sort moves.
    # For now, let's assume "Clever" = AB without ordering, "Genious" = AB with ordering.
    # But since we only have one implementation, we can't distinguish them yet.
    # Let's skip Genious or assume our current IS Genious if moves are ordered?
    # Moves are NOT ordered in `get_legal_moves`.
    # So our current implementation is "Clever".

    # 4. PRAGMATIC (Alpha-Beta + Pruning)
    Main.node_counter = 0
    t_start = now()
    minimax_with_tree(board, depth, -Inf, Inf, true, 0, ""; pruning=PRUNE_LOSS_OF_PIECE)
    t_pragmatic = (now() - t_start).value / 1000.0
    println(rpad("Pragmatic (Prune)", 20) * " | " * rpad(round(t_pragmatic, digits=4), 10) * " | " * rpad("N/A", 10))

    Main.tree_enabled = restore_tree
    println("-"^80)
end

run_benchmark()
