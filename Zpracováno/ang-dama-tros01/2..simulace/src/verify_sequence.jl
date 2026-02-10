include("testvaluefunc.jl")

function run_verification()
    mkpath("out/verification")
    open("out/verification/verification_log.txt", "w") do f
        function log_both(msg)
            println(msg)
            println(f, msg)
        end

        log_both("--- VERIFYING OPTIMAL SEQUENCE FROM START ---")
        board = create_assignment_board()
        log_both("Initial Board:")
        # print_board usually prints to stdout. We might need to capture it or just skip board printing in log for now, or just log moves.
        # let's just log moves for the report.
        # The original print_board(board, show_notation=true) is removed as per instruction.

        log_both("\n--- RUNNING SIMULATION (Depth 6) ---")
        turn = 1
        max_turns = 15
        while turn <= max_turns
            # White
            legal_moves_w = get_legal_moves(board, WHITE)
            best_sc = -Inf
            best_mv = nothing

            log_both("\nTurn $turn White Options:")

            # Sort moves for deterministic output
            sort!(legal_moves_w, by=m -> (m.from.r, m.from.c, m.to.r, m.to.c))

            for m in legal_moves_w
                if m === nothing
                    continue
                end
                try
                    nb = make_move(board, m)
                    # Using depth 5 (Total Horizon 6)
                    sc, _ = minimax(nb, 5, -Inf, Inf, false; config=DEFAULT_CONFIG)

                    log_both("  $(format_move(m)): $sc")

                    if sc > best_sc
                        best_sc = sc
                        best_mv = m
                    elseif sc == best_sc
                        # Collision!
                        log_both("  [WARNING] Tie for best score with $(format_move(best_mv))!")
                    end
                catch e
                    log_both("  Error evaluating $(format_move(m)): $e")
                end
            end

            if best_mv === nothing
                log_both("Red Wins")
                break
            end

            log_both("Selected: $(format_move(best_mv)) (Score: $best_sc)")
            board = make_move(board, best_mv)
            if length(get_legal_moves(board, RED)) == 0
                log_both("White Wins")
                break
            end

            # Red (Standard Minimax response)
            sc_r, mv_r = minimax(board, 6, -Inf, Inf, false; config=DEFAULT_CONFIG)
            if mv_r === nothing
                log_both("White Wins")
                break
            end
            log_both("Turn $turn Red:   $(format_move(mv_r)) (Score: $sc_r)")
            board = make_move(board, mv_r)
            if length(get_legal_moves(board, WHITE)) == 0
                log_both("Red Wins")
                break
            end


            turn += 1
        end
    end
end

run_verification()
