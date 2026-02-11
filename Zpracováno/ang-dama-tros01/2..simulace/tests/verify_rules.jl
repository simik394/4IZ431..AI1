using Test

# Include the game logic
# We need to suppress the output of the included file if it runs anything
# But testvaluefunc.jl seems to only define functions/structs, so it should be fine.
include("../src/testvaluefunc.jl")

@testset "English Draughts Rules Verification" begin

    @testset "Coordinate Conversion" begin
        # Test corners and specific positions
        # 1 -> (1, 2)
        p1 = notation_to_position(1)
        @test p1.r == 1 && p1.c == 2
        @test position_to_notation(1, 2) == 1

        # 4 -> (1, 8)
        p4 = notation_to_position(4)
        @test p4.r == 1 && p4.c == 8
        @test position_to_notation(1, 8) == 4

        # 5 -> (2, 1)
        p5 = notation_to_position(5)
        @test p5.r == 2 && p5.c == 1
        @test position_to_notation(2, 1) == 5

        # 32 -> (8, 7)
        p32 = notation_to_position(32)
        @test p32.r == 8 && p32.c == 7
        @test position_to_notation(8, 7) == 32
    end

    @testset "Move Generation - Basic" begin
        # Standard starting board
        board = create_standard_board()

        # Red (top) moves first usually in checkers, but here we can test both
        # Red moves down (increasing row index)
        # White moves up (decreasing row index)

        # Test Red moves from start
        # Red pieces are at 9, 10, 11, 12 (row 3)
        # 9 (3,2) -> 13 (4,1), 14 (4,3)
        moves_red = get_legal_moves(board, RED)
        # Should be 7 possible moves for Red at start:
        # 9->13, 9->14
        # 10->14, 10->15
        # 11->15, 11->16
        # 12->16 (12 cannot go to 32/edge? No, 12 is at 3,8. Can go to 16 at 4,7. Cannot go to "right".)

        @test length(moves_red) == 7

        # Test White moves (if it were white's turn)
        # White pieces at 21, 22, 23, 24
        moves_white = get_legal_moves(board, WHITE)
        @test length(moves_white) == 7
    end

    @testset "Mandatory Jumping" begin
        # Setup specific board for jump
        board = create_empty_board()

        # White at 18 (5, 4)
        pos18 = notation_to_position(18)
        board[pos18.r, pos18.c] = WHITE

        # Red at 14 (4, 3) - optimal target
        pos14 = notation_to_position(14)
        board[pos14.r, pos14.c] = RED

        # Should jump to 9 (3, 2)
        moves = get_legal_moves(board, WHITE)

        @test length(moves) == 1
        @test moves[1].is_jump == true
        @test moves[1].to.r == 3 && moves[1].to.c == 2 # Position 9

        # Add another non-jumping option to ensure it's filtered out
        # White at 30 (8, 3)
        pos30 = notation_to_position(30)
        board[pos30.r, pos30.c] = WHITE

        moves = get_legal_moves(board, WHITE)
        # Still should be only 1 move (the jump), because jumping is forced
        @test length(moves) == 1
        @test moves[1].from.r == pos18.r && moves[1].from.c == pos18.c
    end

    @testset "Multi-hop Captures" begin
        board = create_empty_board()

        # White at 27 (7, 6)
        pos27 = notation_to_position(27)
        board[pos27.r, pos27.c] = WHITE

        # Red at 23 (6, 5) and 14 (4, 3)
        # Path: 27 -> Jump 23 -> Land 18 -> Jump 14 -> Land 9
        pos23 = notation_to_position(23)
        board[pos23.r, pos23.c] = RED
        pos14 = notation_to_position(14)
        board[pos14.r, pos14.c] = RED

        moves = get_legal_moves(board, WHITE)

        @test length(moves) == 1
        move = moves[1]
        @test move.is_jump == true
        # Final destination should be 9
        dest_pos = notation_to_position(9)
        @test move.to.r == dest_pos.r && move.to.c == dest_pos.c
        # Should have captured 2 pieces
        @test length(move.captured) == 2
    end

    @testset "King Promotion Stops Turn" begin
        # Rule: If a pawn reaches the king row during a capture sequence, 
        # it becomes a king and the turn ENDS immediately, even if it could capture more.

        # Correct Test Setup for King Promotion:
        # White at 11 (3, 6).
        # Red at 7 (2, 5).
        # Red at 6 (2, 3).
        # Move: 11 jumps 7 to land on 2 (1, 4) -> PROMOTION.
        # IF it didn't stop, 2 is now King.
        # King at 2(1,4) could jump Red at 6(2,3) to land on 9(3,2).
        # This requires the rule to STOP at 2.

        board = create_empty_board()
        pos11 = notation_to_position(11)
        board[pos11.r, pos11.c] = WHITE

        pos7 = notation_to_position(7)
        board[pos7.r, pos7.c] = RED

        pos6 = notation_to_position(6)
        # Let's place Red at 5(2,1).
        # And ensure the board boundaries allow the jump? No (3,0) is off board.

        # Maybe piece at 12 (3,8)?
        # Let's say we land on 2 (1,4).
        # Jump 11(3,6) over 7(2,5) to 2(1,4).
        # Now at 2(1,4).
        # Potential continuation: Jump over 6(2,3)? To 9(3,2)?
        # 2(1,4) -> 6(2,3) -> 9(3,2)?
        # (1,4) -> (2,3) -> (3,2). Vector (+1, -1). 
        # (1,4) + (1,-1) = (2,3).
        # (2,3) + (1,-1) = (3,2).
        # Yes! 2->6->9 is a valid backward jump if it were a king.

        # So: White at 11. Red at 7. LANDS on 2. 
        # Red at 6. (Target 9 must be empty).

        pos9 = notation_to_position(9)
        board[pos9.r, pos9.c] = RED # Potential Victim 2 (if jump continued)

        # Expected: Jump 10->1. Become King. STOP.
        # If it didn't stop, it might try to jump 1->9 taking 5 (if it became king instantly and could continue).
        # English rules: turn ends.

        moves = get_legal_moves(board, WHITE)

        println("DEBUG: Generated moves for King Promotion test:")
        for (i, m) in enumerate(moves)
            println("  $i: From $(m.from.r),$(m.from.c) To $(m.to.r),$(m.to.c) Jump=$(m.is_jump) Caught=$(length(m.captured))")
        end

        @test length(moves) == 1
        move = moves[1]

        # Land on 2 (King row)
        dest_pos = notation_to_position(2)
        @test move.to.r == dest_pos.r && move.to.c == dest_pos.c
        @test length(move.captured) == 1 # Only one capture
    end

    @testset "King Movement and Backward Jumps" begin
        board = create_empty_board()

        # White King at 14 (4, 3)
        pos14 = notation_to_position(14)
        board[pos14.r, pos14.c] = WHITE_KING

        # Red Piece at 18 (5, 4) - behind
        pos18 = notation_to_position(18)
        board[pos18.r, pos18.c] = RED

        # Should be able to jump backwards to 23 (6, 5)
        moves = get_legal_moves(board, WHITE)

        @test length(moves) == 1
        @test moves[1].is_jump == true
        dest_pos = notation_to_position(23)
        @test moves[1].to.r == dest_pos.r && moves[1].to.c == dest_pos.c
    end

end
