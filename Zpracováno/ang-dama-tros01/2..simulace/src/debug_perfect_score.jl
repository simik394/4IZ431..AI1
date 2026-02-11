
# Standalone Debug Script for Perfect Heuristic
const WHITE = 1
const RED = -1
const WHITE_KING = 2
const RED_KING = -2
const EMPTY = 0

is_white(p) = p > 0
is_red(p) = p < 0
is_king(p) = abs(p) == 2
is_piece(p) = p != EMPTY

function position_to_notation(r::Int, c::Int)
    if (r + c) % 2 == 0
        return 0
    end
    return (r - 1) * 4 + Int(ceil(c / 2))
end

struct HeuristicConfig
    use_material::Bool
    use_cornering::Bool
    use_coordination::Bool
    use_mobility::Bool
    use_retreat::Bool
    use_net::Bool
    use_attack::Bool
    use_ctrl::Bool
    debug::Bool
end
const DEFAULT_CONFIG = HeuristicConfig(true, true, true, true, true, true, true, true, true)

include("heuristics.jl")

println("DEBUG PERFECT HEURISTIC SCORING - OPTIMAL CONTINUATION CHECK")

function create_board(wk_pos::Vector{Int}, rk_pos::Vector{Int})
    b = zeros(Int, 8, 8)
    map_pos = Dict{Int,Tuple{Int,Int}}()
    for r in 1:8, c in 1:8
        if (r + c) % 2 != 0
            n = position_to_notation(r, c)
            map_pos[n] = (r, c)
        end
    end
    for p in wk_pos
        if haskey(map_pos, p)
            r, c = map_pos[p]
            b[r, c] = WHITE_KING
        end
    end
    for p in rk_pos
        if haskey(map_pos, p)
            r, c = map_pos[p]
            b[r, c] = RED_KING
        end
    end
    return b
end

# 1. Loop Start: W@[10, 14], R@1
b_start = create_board([10, 14], [1])
s_start = perfect_endgame_heuristic(b_start)
println("Loop Start (W@[10, 14], R@1): $s_start")

# 2. Optimal Continuation: W@[10, 6], R@1
# (After White 9-6, Red 5-1)
b_opt_cont = create_board([10, 6], [1])
s_opt_cont = perfect_endgame_heuristic(b_opt_cont)
println("Optimal Continued (W@[10, 6], R@1): $s_opt_cont")

# 3. Just for check: W@[10, 6], R@5
b_opt = create_board([10, 6], [5])
s_opt = perfect_endgame_heuristic(b_opt)
println("Optimal (W@[10, 6], R@5): $s_opt")
