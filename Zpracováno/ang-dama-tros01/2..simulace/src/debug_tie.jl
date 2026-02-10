# Note: testvaluefunc.jl likely includes boards.jl.
# We include testvaluefunc.jl to get Move, Position, minimax, notation_to_position.
include("testvaluefunc.jl")
# Include heuristics explicitly if not loaded by testvaluefunc
if !isdefined(Main, :my_heuristic)
    include("heuristics.jl")
end
# Include boards explicitly if BOARDS not defined (it usually is)
if !isdefined(Main, :create_assignment_board)
    include("boards.jl")
end


function debug_tie()
    # Use create_assignment_board instead of Board()
    board = create_assignment_board() # Already sets up W@10, W@14, R@1 correctly!

    println("Initial Board:")
    print_board(board)

    # Analyze 14-9 (Optimal)
    println("\n--- 14-9 (Minimax Direct Check Depth 6) ---")
    move_14_9 = Move(Position(4, 3), Position(3, 2), false, nothing)
    b1 = make_move(board, move_14_9)
    println("After 14-9 (White):")
    print_board(b1)

    # Check score directly using minimax depth 6 (Red to move)
    println("Calling Minimax Depth 6...")
    sc, mv = minimax(b1, 6, -Inf, Inf, false; config=HeuristicConfig(debug=true))
    println("Minimax Depth 6 Score: $sc")
    if mv !== nothing
        println("Red Response: $(format_move(mv))")
    end

    # Analyze 10-7 (Suboptimal / Tied)
    println("\n--- 10-7 ---")
    move_10_7 = Move(Position(3, 4), Position(2, 5), false, nothing) # 10(3,4) -> 7(2,5)
    b2 = make_move(board, move_10_7)
    sc2, mv2 = minimax(b2, 1, -Inf, Inf, false; config=HeuristicConfig(debug=true))
    println("Minimax Depth 1 Score: $sc2")
    if mv2 !== nothing
        println("Red Response: $(format_move(mv2))")
    end
end

debug_tie()
