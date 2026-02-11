
include("boards.jl")
include("heuristics.jl")

println("DEBUG HEURISITC SCORING")
println("W_CORNER_CONTROL = $W_CORNER_CONTROL")

# Setup Turn 5 Board
# Red @ 1. White @ 9, 14.
board = create_empty_board()
board[1, 2] = RED_KING  # 1
board[3, 2] = WHITE_KING # 9
board[4, 3] = WHITE_KING # 14

println("\n--- INITIAL STATE (Turn 5) ---")
println("Score: $(my_heuristic(board))")

# Move 9-5
# W@9 -> 5
b_9_5 = copy(board)
b_9_5[3, 2] = EMPTY
b_9_5[2, 1] = WHITE_KING
println("\n--- AFTER 9-5 ---")
s_9_5 = my_heuristic(b_9_5)
println("Score 9-5: $s_9_5")

# Move 14-10
# W@14 -> 10
b_14_10 = copy(board)
b_14_10[4, 3] = EMPTY
b_14_10[3, 4] = WHITE_KING
println("\n--- AFTER 14-10 ---")
s_14_10 = my_heuristic(b_14_10)
println("Score 14-10: $s_14_10")

# Move Red 1-5 (After 14-10)
# R@1 -> 5
b_1_5 = copy(b_14_10)
b_1_5[1, 2] = EMPTY
b_1_5[2, 1] = RED_KING
println("\n--- RED 1-5 (After 14-10) ---")
s_1_5 = my_heuristic(b_1_5)
println("Score 1-5: $s_1_5")
