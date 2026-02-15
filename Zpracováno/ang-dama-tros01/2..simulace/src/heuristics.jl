# ==============================================================================
# HODNOTÍCÍ FUNKCE (HEURISTIKY) PRO ANGLICKOU DÁMU
# ==============================================================================
#
# Tento soubor obsahuje různé hodnotící funkce, které lze použít pro AI hráče.
# Každá funkce přijímá board::Matrix{Int} a vrací celé číslo (skóre).
#
# Konvence: Kladné hodnoty = výhodné pro BÍLÉHO, záporné = výhodné pro ČERVENÉHO
#
# ==============================================================================
# 
# POUŽITÍ:
#   include("heuristics.jl")
#   # Standardní použití
#   score = perfect_endgame_heuristic(board)
#   
#   # Konfigurovatelné použití (pro ablační studie)
#   config = HeuristicConfig(use_cornering=false)
#   score = perfect_endgame_heuristic(board, config)
#
# ==============================================================================

# ------------------------------------------------------------------------------
# KONFIGURACE HEURISTIKY (PRO ABLAČNÍ STUDIE)
# ------------------------------------------------------------------------------

"""
Konfigurace pro vypínání/zapínání jednotlivých komponent heuristiky.
Vhodné pro ablační studie.
"""
struct HeuristicConfig
    use_material::Bool
    use_cornering::Bool       # Vytlačení z centra + Safety zone penalta
    use_coordination::Bool    # Vzdálenost králů + Bracketing
    use_mobility::Bool        # Počet tahů soupeře
    use_retreat::Bool         # Penalta za zbytečný ústup
    use_net::Bool             # Diagonální síť (net formation)
    use_attack::Bool          # Přímé sousedství
    use_ctrl::Bool            # Kontrola dvojitého rohu (double corner control)
    debug::Bool               # Debugovací výpis

    # Konstruktor s defaultními hodnotami (vše zapnuto)
    HeuristicConfig(;
        use_material=true,
        use_cornering=true,
        use_coordination=true,
        use_mobility=true,
        use_retreat=true,
        use_net=true,
        use_attack=true,
        use_ctrl=true,
        debug=false
    ) = new(use_material, use_cornering, use_coordination, use_mobility,
        use_retreat, use_net, use_attack, use_ctrl, debug)
end

# Defaultní konfigurace (vše zapnuto)
const DEFAULT_CONFIG = HeuristicConfig()

# ------------------------------------------------------------------------------
# KONSTANTY PRO EVALUACI
# ------------------------------------------------------------------------------

const PERFECT_WEIGHTS = Dict(
    :MATERIAL => 100.0,
    :WIN => 10000.0,
    :PRUNING => -99999.0,
    :SAFETY_RED => -600.0,
    :ACTIVE_RED => 500.0,
    :COORD => 300.0,
    :SQUEEZE => 60.0,
    :RETREAT_MAX => -1000.0,
    :RETREAT_MID => -400.0,
    :RETREAT_FAR => -600.0,
    :NET => 1200.0,
    :CROWDING => -800.0,
    :MOBILITY => 600.0
)

# ------------------------------------------------------------------------------
# HLAVNÍ HEURISTIKA - Plně vybavená s endgame logikou
# ------------------------------------------------------------------------------

"""
Hlavní hodnotící funkce s kompletní logikou:
- Materiál (pěšec=100, král=300)
- Poziční bonusy (střed, okraje, rohy)
- Endgame nahánění (Chebyshev distance)
"""
#| region: my_heuristic_start
function my_heuristic(board::Matrix{Int})
    score = 0

    # Počítadla kamenů
    white_pieces = 0
    red_pieces = 0
    white_kings = 0
    red_kings = 0

    # Pozice králů pro výpočet vzdálenosti
    white_positions = Position[]
    red_positions = Position[]

    for r in 1:8, c in 1:8
        p = board[r, c]
        if p == EMPTY
            continue
        end

        # --- A. MATERIÁL ---
        #| region: my_heuristic_material
        piece_value = is_king(p) ? 300 : 100

        if is_white(p)
            score += piece_value
            white_pieces += 1
            if is_king(p)
                white_kings += 1
                push!(white_positions, Position(r, c))
            end
        else
            score -= piece_value
            red_pieces += 1
            if is_king(p)
                red_kings += 1
                push!(red_positions, Position(r, c))
            end
        end
        #| endregion: my_heuristic_material

        #| region: my_heuristic_pos_white
        # --- B. POZICE (Board Control) ---
        if 3 <= c <= 6
            center_bonus = 5
            score += is_white(p) ? center_bonus : -center_bonus
        end
        #| endregion: my_heuristic_pos_white

        #| region: my_heuristic_edge
        # --- C. OKRAJOVÁ BEZPEČNOST PRO PĚŠCE ---
        is_on_edge = (c == 1 || c == 8)
        if !is_king(p) && is_on_edge
            edge_safety_bonus = 10
            score += is_white(p) ? edge_safety_bonus : -edge_safety_bonus
        end
        #| endregion: my_heuristic_edge

        #| region: my_heuristic_double_corner
        # --- D. DVOJITÝ ROH ---
        double_corners = [(8, 1), (8, 8), (1, 2), (1, 8)]
        if !is_king(p) && (r, c) in double_corners
            double_corner_bonus = 15
            score += is_white(p) ? double_corner_bonus : -double_corner_bonus
        end
        #| endregion: my_heuristic_double_corner

        #| region: my_heuristic_pos_king
        # --- E. POZIČNÍ LOGIKA PRO KRÁLE ---
        if is_king(p)
            is_on_edge = (r == 1 || r == 8 || c == 1 || c == 8)
            corner_positions = [(1, 2), (1, 8), (8, 1), (8, 8)]
            is_in_corner = (r, c) in corner_positions
            has_advantage = is_white(p) ? (white_kings > red_kings) : (red_kings > white_kings)

            if has_advantage
                if is_in_corner
                    score += is_white(p) ? -20 : 20
                elseif is_on_edge
                    score += is_white(p) ? -8 : 8
                end
            else
                if is_on_edge
                    score += is_white(p) ? 5 : -5
                end
            end
        end
        #| endregion: my_heuristic_pos_king
    end

    # --- F. ENDGAME - NAHÁNĚNÍ ---

    # BÍLÝ má převahu (2v1, 3v1...)
    if white_kings > red_kings && length(red_positions) > 0 && length(white_positions) > 0
        #| region: my_heuristic_endgame
        # 1. Vzdálenost mezi králi (chceme minimalizovat = Attack)
        total_distance = 0
        for wp in white_positions
            for rp in red_positions
                dist = abs(wp.r - rp.r) + abs(wp.c - rp.c)
                total_distance += dist
            end
        end
        avg_distance = total_distance / (length(white_positions) * length(red_positions))
        score += round(Int, (14 - avg_distance) * 100) # AGRESIVNÍ VÁHA (bylo 20)

        # 2. Zahnání do kouta
        for rp in red_positions
            dist_center = abs(rp.r - 4.5) + abs(rp.c - 4.5)
            score += round(Int, dist_center * 50) # AGRESIVNÍ VÁHA (bylo 15)
        end
        #| endregion: my_heuristic_endgame
    end

    # ČERVENÝ má převahu
    if red_kings > white_kings && length(white_positions) > 0 && length(red_positions) > 0
        # 1. Vzdálenost
        total_distance = 0
        for rp in red_positions
            for wp in white_positions
                dist = abs(rp.r - wp.r) + abs(rp.c - wp.c)
                total_distance += dist
            end
        end
        avg_distance = total_distance / (length(red_positions) * length(white_positions))
        score -= round(Int, (14 - avg_distance) * 100)

        # 2. Zahnání do kouta
        for wp in white_positions
            dist_center = abs(wp.r - 4.5) + abs(wp.c - 4.5)
            score -= round(Int, dist_center * 50)
        end
    end

    return score
end
#| endregion: my_heuristic_start

# ------------------------------------------------------------------------------
# JEDNODUCHÁ MATERIÁLOVÁ HEURISTIKA
# ------------------------------------------------------------------------------

"""
Jednoduchá heuristika - pouze materiál.
Pěšec = 100, Král = 300.
"""
function simple_material_heuristic(board::Matrix{Int})
    score = 0
    for r in 1:8, c in 1:8
        p = board[r, c]
        if p == EMPTY
            continue
        end
        piece_value = is_king(p) ? 300 : 100
        score += is_white(p) ? piece_value : -piece_value
    end
    return score
end

# ------------------------------------------------------------------------------
# AGRESIVNÍ HEURISTIKA - Preferuje útok
# ------------------------------------------------------------------------------

"""
Agresivní heuristika - preferuje útočné pozice.
Bonusy za postup směrem k soupeři.
"""
function aggressive_heuristic(board::Matrix{Int})
    score = simple_material_heuristic(board)

    for r in 1:8, c in 1:8
        p = board[r, c]
        if p == EMPTY
            continue
        end

        # Bonus za postup (bílý chce být na nízkých řádcích, červený na vysokých)
        if is_white(p) && !is_king(p)
            advancement = 8 - r  # čím blíže řádku 1, tím lépe
            score += advancement * 5
        elseif is_red(p) && !is_king(p)
            advancement = r - 1  # čím blíže řádku 8, tím lépe
            score -= advancement * 5
        end

        # Bonus za střed
        if 3 <= c <= 6
            score += is_white(p) ? 8 : -8
        end
    end

    return score
end

# ------------------------------------------------------------------------------
# DEFENZIVNÍ HEURISTIKA - Preferuje obranu
# ------------------------------------------------------------------------------

"""
Defenzivní heuristika - preferuje bezpečné pozice.
Bonusy za okraje a domovskou řadu.
"""
function defensive_heuristic(board::Matrix{Int})
    score = simple_material_heuristic(board)

    for r in 1:8, c in 1:8
        p = board[r, c]
        if p == EMPTY
            continue
        end

        # Bonus za domovskou řadu
        if is_white(p) && r == 8
            score += 15
        elseif is_red(p) && r == 1
            score -= 15
        end

        # Bonus za okraje
        if c == 1 || c == 8
            score += is_white(p) ? 10 : -10
        end
    end

    return score
end

# ------------------------------------------------------------------------------
# NÁHODNÁ HEURISTIKA - Pro testování
# ------------------------------------------------------------------------------

"""
Náhodná heuristika - přidává náhodný šum k materiálu.
Užitečné pro testování robustnosti.
"""
function random_heuristic(board::Matrix{Int})
    base = simple_material_heuristic(board)
    noise = rand(-50:50)
    return base + noise
end

# ------------------------------------------------------------------------------
# OPTIMAL ENDGAME HEURISTIC - Nová heuristika pro koncovku 2v1
# ------------------------------------------------------------------------------

"""
Optimalizovaná heuristika pro koncovku 2 králové vs 1 král.

STRATEGIE (z optimal-sequence.md a alphabeta-sim-tros01.qmd):
1. NIKDY neměnit do 1v1 situace
2. Vytlačit červeného z dvojitého rohu (pole 1, 5)
3. Koordinovat krále pro sevření
4. Minimalizovat mobilitu soupeře

KLÍČOVÝ PRINCIP PRO PRVNÍ TAH:
- Pozice 10 a 14 jsou výchozí (W@10, W@14, R@1)
- Optimální první tah: 14-9 (přiblížení k rohu)
- Špatný tah: 10-6 nebo 9-5 (ústup od cíle)
"""
#| region: optimal_endgame_heuristic_start
function optimal_endgame_heuristic(board::Matrix{Int})
    score = 0.0

    # Lokální konstanty (mirror from testvaluefunc.jl)
    const_KING = 100.0
    const_PAWN = 40.0
    const_EXCHANGE_PENALTY = 2000.0
    const_WIN = 10000.0

    # Počítadla
    white_pieces = 0
    red_pieces = 0
    white_kings = 0
    red_kings = 0
    white_positions = Tuple{Int,Int}[]
    red_positions = Tuple{Int,Int}[]

    for r in 1:8, c in 1:8
        p = board[r, c]
        if p == EMPTY
            continue
        end

        # --- A. MATERIÁL ---
        #| region: optimal_material
        if is_white(p)
            white_pieces += 1
            score += is_king(p) ? const_KING : 40.0  # <1>
            if is_king(p)
                white_kings += 1
                push!(white_positions, (r, c))
            end
        else
            red_pieces += 1
            score -= is_king(p) ? const_KING : 40.0  # <2>
            if is_king(p)
                red_kings += 1
            end
        end
        #| endregion: optimal_material
    end

    # --- B. ODMÍTNUTÍ VÝMĚNY (1v1 = katastrofa!) ---
    #| region: optimal_1v1
    if white_pieces == 1 && red_pieces >= 1
        score -= const_EXCHANGE_PENALTY  # <1>
    end
    #| endregion: optimal_1v1

    # --- C. ENDGAME - 2 bílí králové vs 1 červený král ---
    if white_kings >= 2 && red_kings == 1 && length(red_positions) > 0
        rp = red_positions[1]  # Pozice červeného krále

        # Převod na notaci pro snadnější debugování
        red_notation = position_to_notation(rp[1], rp[2])

        # =================================================================
        # 1. DOUBLE CORNER STRATEGY - Klíčové pole: 1, 5, 6, 2, 9
        # =================================================================
        #| region: optimal_red_pos
        if red_notation == 1 || red_notation == 5
            score += 0  # Neutrální - musíme ho vytlačit
        elseif red_notation == 6 || red_notation == 2
            score += 800.0  # Červený mimo roh = VÝBORNÉ
        elseif red_notation == 9 || red_notation == 10 || red_notation == 3
            score += 500.0
        else
            score += 300.0
        end
        #| endregion: optimal_red_pos

        # =================================================================
        # 2. POZICE BÍLÝCH KRÁLŮ - Přiblížení k cílovému prostoru
        # =================================================================
        target_center = (2.0, 2.5)  # Střed cílové oblasti

        #| region: optimal_corner_control
        for wp in white_positions
            dist_to_target = abs(wp[1] - target_center[1]) + abs(wp[2] - target_center[2])
            approach_bonus = (7.0 - dist_to_target) * 80.0
            score += approach_bonus

            wp_notation = position_to_notation(wp[1], wp[2])
            if wp_notation == 1
                score += 200.0  # Cíl! (Perfect Corner)
            elseif wp_notation == 5
                score += 500.0  # Klíčové pole před rohem (Step 5->1) - Aggressive Boost
            elseif wp_notation == 6
                score += 150.0
            elseif wp_notation == 2
                score += 100.0  # Blízko rohu (Step 6->2) - Reduced to disfavor 10-7
            elseif wp_notation == 9
                score += 150.0  # Step 14->9
            elseif wp_notation == 10
                score += 100.0
            elseif wp_notation == 14
                score += 100.0  # Step 10->14 (Waiting move, preserve score)
            end
        end
        #| endregion: optimal_corner_control

        # =================================================================
        # 3. KOORDINACE KRÁLŮ
        # =================================================================
        #| region: optimal_coordination
        if length(white_positions) >= 2
            wp1, wp2 = white_positions[1], white_positions[2]
            king_dist = abs(wp1[1] - wp2[1]) + abs(wp1[2] - wp2[2])

            if king_dist == 2
                score += 200.0
            elseif king_dist == 3
                score += 150.0
            elseif king_dist == 4
                score += 80.0
            else
                score -= (king_dist - 4) * 30.0
            end

            dist1 = abs(wp1[1] - rp[1]) + abs(wp1[2] - rp[2])
            dist2 = abs(wp2[1] - rp[1]) + abs(wp2[2] - rp[2])

            if dist1 <= 2 && dist2 <= 2
                score += 400.0
            elseif dist1 <= 3 && dist2 <= 3
                score += 250.0
            end

            min_dist = min(dist1, dist2)
            score += (8.0 - min_dist) * 40.0
        end
        #| endregion: optimal_coordination

        #| region: optimal_mobility
        # =================================================================
        # 4. MOBILITA SOUPEŘE
        # =================================================================
        try
            red_moves = get_legal_moves(board, RED)
            num_moves = length(red_moves)
            if num_moves == 0
                score += const_WIN
            elseif num_moves == 1
                score += 500.0
            elseif num_moves == 2
                score += 200.0
            end
            if num_moves > 3
                score -= (num_moves - 3) * 50.0
            end
        catch e
        end
        #| endregion: optimal_mobility

        #| region: optimal_attack
        # =================================================================
        # 5. ÚTOK - Přímé sousedství
        # =================================================================
        for wp in white_positions
            row_diff = abs(wp[1] - rp[1])
            col_diff = abs(wp[2] - rp[2])
            if row_diff == 1 && col_diff == 1
                score += 150.0
            end
        end
        #| endregion: optimal_attack
    end

    return round(score, digits=1)
end
#| endregion: optimal_endgame_heuristic_start

# ------------------------------------------------------------------------------
# PERFECT ENDGAME HEURISTIC - Přesně následuje optimální sekvenci
# ------------------------------------------------------------------------------

"""
Perfektní heuristika pro koncovku 2 králové vs 1 král.

Přesně následuje optimální sekvenci z optimal-sequence.md:
1. W 10,14 → 9,10 (tah 14→9)
2. R 1 → 5
3. W 9,10 → 9,14 (tah 10→14)
4. R 5 → 1
5. W 9,14 → 5,14 (tah 9→5)
6. R 1 → 6
7. W 5,14 → 1,14 (tah 5→1, skáče přes 6!)
8. R 6 → 2
9. W 1,14 → 1,18 (tah 14→18)
10. R 2 → 7
11. W 1,18 → 1,15 (tah 18→15)
12. R má 2 tahy, oba vedou k výhře W

Celkem: 6 bílých tahů do výhry.
"""
#| region: perfect_endgame_heuristic_start
#| region: perfect_endgame_heuristic_start
"""
Pomocná funkce: Materiál
"""
function eval_material(board::Matrix{Int}, config::HeuristicConfig)
    if !config.use_material
        return (0.0, 0, 0, Tuple{Int,Int}[], Tuple{Int,Int}[])
    end

    score = 0.0
    const_KING = 100.0

    white_kings = 0
    red_kings = 0
    white_positions = Tuple{Int,Int}[]
    red_positions = Tuple{Int,Int}[]

    for r in 1:8, c in 1:8
        p = board[r, c]
        if p == EMPTY
            continue
        end

        if is_white(p)
            score += is_king(p) ? const_KING : 40.0
            if is_king(p)
                white_kings += 1
                push!(white_positions, (r, c))
            end
        else
            score -= is_king(p) ? const_KING : 40.0
            if is_king(p)
                red_kings += 1
                push!(red_positions, (r, c))
            end
        end
    end

    return score, white_kings, red_kings, white_positions, red_positions
end

function perfect_endgame_heuristic(board::Matrix{Int}, config::HeuristicConfig=DEFAULT_CONFIG)
    score = 0.0
    const_WIN = 10000.0

    # 1. Materiál a získání pozic
    # I když je materiál vypnutý, potřebujeme pozice pro ostatní výpočty
    # Proto eval_material vrátí pozice vždy, ale skóre jen když je zapnuto
    # (upravíme logiku eval_material nebo ji zavoláme chytře)

    # Pro efektivitu a ablační studii:
    # Potřebujeme pozice VŽDY. Skóre materiálu jen když config.use_material.

    # --- A. MATERIÁL & POZICE ---
    #| region: perfect_material
    mat_score = 0.0
    const_KING = 100.0

    white_kings = 0
    red_kings = 0
    white_positions = Tuple{Int,Int}[]
    red_positions = Tuple{Int,Int}[]

    for r in 1:8, c in 1:8
        p = board[r, c]
        if p == EMPTY
            continue
        end

        if is_white(p)
            if config.use_material
                mat_score += is_king(p) ? const_KING : 40.0
            end
            if is_king(p)
                white_kings += 1
                push!(white_positions, (r, c))
            end
        else
            if config.use_material
                mat_score -= is_king(p) ? const_KING : 40.0
            end
            if is_king(p)
                red_kings += 1
                push!(red_positions, (r, c))
            end
        end
    end

    score += mat_score
    #| endregion: perfect_material

    # Vítězství / prohra
    if red_kings == 0
        return PERFECT_WEIGHTS[:WIN]
    end
    if white_kings == 0
        return -PERFECT_WEIGHTS[:WIN]
    end

    # ==========================================================================
    # PRINCIP 1: 1v1 = ZAKÁZANÝ STAV
    # Víme, že existuje zaručená výhra, tedy 1v1 = selhání strategie
    # ==========================================================================
    #| region: perfect_1v1
    if white_kings == 1 && red_kings >= 1
        return PERFECT_WEIGHTS[:PRUNING]
    end
    #| endregion: perfect_1v1

    # === HLAVNÍ LOGIKA PRO 2v1 ENDGAME ===
    if white_kings >= 2 && red_kings == 1
        rp = red_positions[1]
        red_row, red_col = rp

        # ==========================================================================
        # PRINCIP 2: VYTLAČIT ČERVENÉHO Z DVOJITÉHO ROHU (safety zone)
        # ==========================================================================
        if config.use_cornering
            double_corner_row, double_corner_col = 1, 2

            #| region: perfect_red_pos
            red_distance_from_corner = abs(red_row - double_corner_row) + abs(red_col - double_corner_col)

            # Bonus za vzdálenost od rohu (čím dále, tím lépe)
            score += red_distance_from_corner * 80.0

            # SILNÁ penalta/bonus za pozici červeného
            # Safety zone = přesně pole {1, 5, 28, 32} (dvojité rohy)
            SAFETY_FIELDS = Set([1, 5, 28, 32])
            red_notation = position_to_notation(red_row, red_col)
            red_in_safety = red_notation in SAFETY_FIELDS
            if red_in_safety
                score += PERFECT_WEIGHTS[:SAFETY_RED]  # <1>
            else
                score += PERFECT_WEIGHTS[:ACTIVE_RED]  # <2>
            end
            #| endregion: perfect_red_pos
        end

        # ==========================================================================
        # PRINCIP 3: KOORDINOVANÝ ÚTOK (SQUEEZE)
        # ==========================================================================

        if length(white_positions) >= 2
            wp1, wp2 = white_positions[1], white_positions[2]
            king_distance = abs(wp1[1] - wp2[1]) + abs(wp1[2] - wp2[2])

            # Průměrná vzdálenost k červenému (potřebná pro retreat i coord)
            dist_wp1_to_red = abs(wp1[1] - red_row) + abs(wp1[2] - red_col)
            dist_wp2_to_red = abs(wp2[1] - red_row) + abs(wp2[2] - red_col)
            avg_dist = (dist_wp1_to_red + dist_wp2_to_red) / 2.0

            if config.use_coordination
                # Optimální koordinace: vzdálenost 2-4
                #| region: perfect_coordination
                if king_distance >= 2 && king_distance <= 6
                    score += PERFECT_WEIGHTS[:COORD]  # <1>
                elseif king_distance == 1
                    score += 100.0  # Příliš blízko - méně efektivní
                elseif king_distance >= 5
                    score -= 100.0  # Příliš daleko - nekoordinovaní
                end

                # Bonus za "sevření" - oba králové blízko červenému
                # Průměrná vzdálenost k červenému (menší = lepší sevření)
                score += (6.0 - avg_dist) * PERFECT_WEIGHTS[:SQUEEZE] # <2>
                #| endregion: perfect_coordination

                # Bridge Penalty
                # Detekce situace, kdy jsou dva bílí na diagonále s mezerou uprostřed
                row_diff = abs(wp1[1] - wp2[1])
                col_diff = abs(wp1[2] - wp2[2])

                if row_diff == 2 && col_diff == 2
                    mid_r = (wp1[1] + wp2[1]) ÷ 2
                    mid_c = (wp1[2] + wp2[2]) ÷ 2

                    # Pokud je červený na středu nebo vedle něj (step <= 1)
                    # Chebyshev distance (step count)
                    dist_to_mid = max(abs(red_row - mid_r), abs(red_col - mid_c))

                    if dist_to_mid <= 1
                        score -= 600.0  # Výrazná penalta za zranitelnou formaci
                    end
                end
            end

            # ==========================================================================
            # PRINCIP 3C: PENALTA ZA ZBYTEČNÝ ÚSTUP (pseudo-terminál)
            # ==========================================================================

            if config.use_retreat
                max_dist = max(dist_wp1_to_red, dist_wp2_to_red)

                #| region: perfect_retreat
                # Pokud OBADVA králové jsou daleko od R = ústup/promarněná příležitost
                if avg_dist > 5.0
                    score += PERFECT_WEIGHTS[:RETREAT_MAX]  # <1>
                elseif avg_dist > 4.0
                    score += PERFECT_WEIGHTS[:RETREAT_MID]   # <2>
                end

                # Pokud NEJBLIŽŠÍ král je stále daleko = špatná pozice
                min_dist = min(dist_wp1_to_red, dist_wp2_to_red)
                if min_dist > 4
                    score += PERFECT_WEIGHTS[:RETREAT_FAR]   # <3>
                end
                #| endregion: perfect_retreat
            end

            # Bonus za "obklíčení" - králové na opačných stranách červeného
            if config.use_coordination
                # Rozdíl v řádcích nebo sloupcích mezi králi relativně k červenému
                row_bracket = (wp1[1] - red_row) * (wp2[1] - red_row) < 0  # Jeden nad, jeden pod
                col_bracket = (wp1[2] - red_col) * (wp2[2] - red_col) < 0  # Jeden vlevo, jeden vpravo

                if row_bracket || col_bracket
                    score += 200.0  # Červený je mezi králi
                end
            end

            # ==========================================================================
            # PRINCIP 3B: DIAGONAL NET FORMATION
            # ==========================================================================

            if config.use_net
                #| region: perfect_net
                # Zjisti, který král je kotva (blíž k rohu) a který operátor
                dist1_to_corner = abs(wp1[1] - 1) + abs(wp1[2] - 2)
                dist2_to_corner = abs(wp2[1] - 1) + abs(wp2[2] - 2)

                anchor = dist1_to_corner < dist2_to_corner ? wp1 : wp2
                operator = dist1_to_corner < dist2_to_corner ? wp2 : wp1

                # Pokud kotva je na poli 1 (row=1, col=2)
                if anchor[1] == 1 && anchor[2] == 2
                    # Operátor by měl být na diagonále směrem pryč od rohu
                    # Preferované pozice: pole 18 (row=5,col=4), 15 (row=4,col=6), 23 atd.
                    op_row, op_col = operator

                    # Vzdálenost operátora od rohu
                    op_dist_from_corner = abs(op_row - 1) +
                                          abs(op_col - 2)

                    # Bonus za operátora na diagonále pryč od rohu
                    # Pole 18 = (5,4), pole 15 = (4,6), pole 22 = (6,5) atd.
                    # Rozšířeno na row >= 3 (1200) aby nedocházelo k dropu při 15->11
                    if op_row >= 3 && op_col >= 4
                        score += PERFECT_WEIGHTS[:NET] # <1>
                    end

                    # SILNÁ penalta za operátora blízko rohu (crowding)
                    # Pole 10 = (3,4), pole 6 = (2,3) - tyto pozice jsou ŠPATNÉ
                    if op_dist_from_corner <= 3
                        score += PERFECT_WEIGHTS[:CROWDING] # <2>
                    end
                end
                #| endregion: perfect_net
            end
        end

        # ==========================================================================
        # PRINCIP 4: MOBILITA ČERVENÉHO
        # ==========================================================================

        if config.use_mobility
            #| region: perfect_mobility
            try
                red_moves = get_legal_moves(board, RED)
                num_moves = length(red_moves)

                if num_moves == 0
                    score += PERFECT_WEIGHTS[:WIN]  # <1>
                elseif num_moves == 1
                    score += PERFECT_WEIGHTS[:MOBILITY]  # <2>
                elseif num_moves == 2
                    score += 300.0  # <3>
                elseif num_moves == 3
                    score += 100.0  # <4>
                end
                # 4+ tahů = žádný bonus
            catch e
            end
            #| endregion: perfect_mobility
        end

        # ==========================================================================
        # PRINCIP 5: CORNERING - tlačit k okrajům ("KONTROLA HRY")
        # ==========================================================================

        if config.use_cornering
            #| region: perfect_cornering
            # Vzdálenost od středu desky (střed = 4.5, 4.5)
            center_row, center_col = 4.5, 4.5
            red_dist_from_center = abs(red_row - center_row) + abs(red_col - center_col)

            # Bonus za červeného daleko od středu (na okrajích)
            score += red_dist_from_center * 40.0  # <1>

            # Extra bonus za skutečný okraj
            if red_row == 1 || red_row == 8
                score += 150.0  # <2>
            end
            if red_col == 1 || red_col == 8
                score += 150.0  # <3>
            end
            #| endregion: perfect_cornering
        end

        # ==========================================================================
        # BONUS ZA PŘÍMÉ SOUSEDSTVÍ (ÚTOK)
        # TODO: předělat jednotně číslování principů
        # ==========================================================================

        if config.use_attack
            #| region: perfect_attack
            red_in_corner = (position_to_notation(red_row, red_col) in Set([1, 5, 28, 32]))

            if !red_in_corner  # Pouze když R NENÍ v bezpečí
                for wp in white_positions
                    row_diff = abs(wp[1] - red_row)
                    col_diff = abs(wp[2] - red_col)
                    if row_diff == 1 && col_diff == 1
                        score += 150.0  # Diagonálně sousedíme
                    end
                end
            end
            #| endregion: perfect_attack
        end

        # ==========================================================================
        # PRINCIP 6: KONTROLA DVOJITÉHO ROHU - KONTEXTOVĚ ZÁVISLÉ
        # ==========================================================================

        if config.use_ctrl
            #| region: perfect_corner_control
            if length(white_positions) >= 2
                wp1, wp2 = white_positions[1], white_positions[2]

                # Je některý W přímo na poli 1 (row=1, col=2)?
                white_at_corner = any(wp -> wp[1] == 1 && wp[2] == 2, white_positions)

                # Je některý W blízko rohu (distance <= 2)?
                # POUŽITÍ CHEBYSHEV DISTANCE (max)
                dist1 = max(abs(wp1[1] - 1), abs(wp1[2] - 2))
                dist2 = max(abs(wp2[1] - 1), abs(wp2[2] - 2))
                white_near_corner = (min(dist1, dist2) <= 2)

                if !white_near_corner
                    # === ŽÁDNÝ W BLÍZKO ROHU: incentivizuj přiblížení JEDNOHO ===
                    # Bonus za přiblížení k rohu (pro prvního krále)
                    # SILNÝ bonus aby dominoval nad jinými metrikami
                    closer_dist = min(dist1, dist2)
                    if closer_dist <= 3
                        score += (5 - closer_dist) * 600.0  # <1>
                    end
                else
                    # === JEDEN W BLÍZKO ROHU: druhý by měl být na diagonále ===
                    # Operátor (vzdálenější král) by měl být na pozici pro squeeze
                    farther_dist = max(dist1, dist2)
                    if config.debug
                        println("DEBUG CTRL: dist1=$dist1 dist2=$dist2 far=$farther_dist close=$(min(dist1, dist2))")
                    end

                    # FINE-TUNING: Odměna za to, že "kotva" je co nejblíž
                    # Používáme stejný vzorec jako v 'if' větvi pro kontinuitu (žádný drop)
                    closer_dist = min(dist1, dist2)
                    if closer_dist <= 3
                        score += (5 - closer_dist) * 600.0
                    end

                    if closer_dist <= 2
                        score += 200.0 # Final Nudge to break 10-7 tie
                    end

                    if closer_dist <= 1
                        score += 500.0 # Reward for Perfect Cornering (Sq 5)
                    end

                    # Bonus za dobrý spread operátora
                    # Přidáno >= 5 (700) pro preferenci širší sítě (tah 14-18)
                    if farther_dist >= 5
                        score += 700.0  # <2>
                    elseif farther_dist >= 4
                        score += 400.0  # <3>
                    elseif farther_dist >= 3
                        score += 200.0  # <4>
                    end

                    # Penalta pokud OBA jsou příliš blízko rohu (crowding)
                    # VIJIMKA: Pokud je rudy v oblasti rohu (1, 5, 6), je to chtene (Squeeze)
                    # 1=(1,2), 5=(2,1), 6=(2,3). Tzn row<=2, col<=3.
                    red_at_dc_area = (red_row <= 2 && red_col <= 3)

                    if min(dist1, dist2) <= 2 && max(dist1, dist2) <= 2 && !red_at_dc_area
                        score -= 600.0  # Crowding! (Relaxed condition from <=3 to <=2)
                    end

                    # BONUS: Pokud je rudy v rohu a my ho tam drzime (oba blizko), je to SKVELE
                    if red_at_dc_area && max(dist1, dist2) <= 2
                        score += 500.0 # Reward for successful trap
                    end
                end

                # Bonus za W přímo na poli 1 (vždy dobrý - kontroluje roh)
                if white_at_corner
                    score += 800.0
                end
            end
            #| endregion: perfect_corner_control
        end
    end

    return round(score, digits=1)
end
#| endregion: perfect_endgame_heuristic_start

# ------------------------------------------------------------------------------
# REGISTR HEURISTIK - Pro snadný výběr
# ------------------------------------------------------------------------------
# TODO: clean out the others not ever used heuristics
const HEURISTICS = Dict(
    "my_heuristic" => my_heuristic,
    "optimal_endgame" => optimal_endgame_heuristic,
    "perfect_endgame" => perfect_endgame_heuristic,
    "simple" => simple_material_heuristic,
    "aggressive" => aggressive_heuristic,
    "defensive" => defensive_heuristic,
    "random" => random_heuristic
)

"""
Vrátí heuristiku podle názvu.
Dostupné: my_heuristic, simple, aggressive, defensive, random
"""
function get_heuristic(name::String)
    if haskey(HEURISTICS, name)
        return HEURISTICS[name]
    else
        error("Neznámá heuristika: $name. Dostupné: $(keys(HEURISTICS))")
    end
end

"""
Vypíše dostupné heuristiky.
"""
function list_heuristics()
    println("Dostupné heuristiky:")
    for (name, _) in HEURISTICS
        println("  - $name")
    end
end
