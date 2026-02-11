include("../src/testvaluefunc.jl")
using Test
using Dates

println("="^80)
println("COMPARISON: PURE MINIMAX vs ALPHA-BETA")
println("="^80)

# Test cases
test_cases = [
    ("Endgame 2v2 (Depth 6)", get_board("endgame_2v2"), 6),
    ("Standard Start (Depth 4)", get_board("standard"), 4),
    ("Assignment (Depth 6)", get_board("assignment"), 6)
]

for (name, board, depth) in test_cases
    println("\nScenarios: $name")
    println("-"^40)

    # 1. PURE MINIMAX
    Main.node_counter = 0
    t_start = now()
    score_pure, move_pure = minimax_pure(board, depth, true, "")
    t_pure = now() - t_start
    nodes_pure = Main.node_counter

    println("PURE: Score=$(round(score_pure, digits=4)), Move=$(format_move(move_pure))")
    println("      Time=$(t_pure), Nodes=$nodes_pure")

    # 2. ALPHA-BETA
    # Disable tree logging for performance
    restore_tree = Main.tree_enabled
    Main.tree_enabled = false
    Main.node_counter = 0

    t_start = now()
    # minimax_with_tree returns (score, move, node_id)
    # We use PRUNE_NONE to match pure minimax logic (except alpha-beta)
    # Wait, pure minimax has NO pruning.
    # But `minimax_with_tree` has `pruning` parameter.
    # Default is PRUNE_LOSS_OF_PIECE.
    # To strictly compare Alpha-Beta optimization only, we should disable extra pruning.
    score_ab, move_ab, _ = minimax_with_tree(board, depth, -Inf, Inf, true, 0, ""; pruning=PRUNE_NONE)
    t_ab = now() - t_start
    nodes_ab = Main.node_counter # Note: this counter track tree nodes, which might be different than visited nodes if not logging
    # Actually in `minimax_with_tree`, `add_tree_node` increments counter ONLY if `tree_enabled` is true?
    # Let's check `testvaluefunc.jl`:
    # function add_tree_node(...)
    #    if !tree_enabled return 0 end
    #    node_counter += 1
    # So if tree_enabled=false, node_counter is NOT incremented.
    # We can't easily count nodes in AB without enabling tree or modifying code.
    # But we can compare Time.

    Main.tree_enabled = restore_tree

    println("A-B : Score=$(round(score_ab, digits=4)), Move=$(format_move(move_ab))")
    println("      Time=$(t_ab)")

    # VALIDATION
    if abs(score_pure - score_ab) > 0.001
        println("❌ MISMATCH! Scores differ.")
    else
        println("✅ MATCH! Scores are identical.")
    end

    if move_pure != move_ab
        # Moves might differ if scores are identical (multiple optimal moves)
        println("⚠️ Moves differ (acceptable if scores match): $(format_move(move_pure)) vs $(format_move(move_ab))")
    else
        println("✅ Moves match.")
    end

    # Calculate speedup
    ms_pure = t_pure.value
    ms_ab = t_ab.value
    if ms_ab > 0
        speedup = ms_pure / ms_ab
        println("🚀 Speedup: $(round(speedup, digits=2))x")
    end
end
