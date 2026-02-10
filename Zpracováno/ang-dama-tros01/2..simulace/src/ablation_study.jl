#!/usr/bin/env julia
# ==============================================================================
# ABLAČNÍ STUDIE PRO CHECKERS AI
# ==============================================================================
#
# Tento skript provádí sérii experimentů pro vyhodnocení přínosu jednotlivých
# komponent hodnotící funkce a strategií prořezávání.
#
# POUŽITÍ:
#   julia ablation_study.jl
#

# Načtení herního enginu a heuristik
include("testvaluefunc.jl")

using Dates

# ==============================================================================
# DEFINICE EXPERIMENTŮ
# ==============================================================================

struct Experiment
    name::String
    config::HeuristicConfig
    pruning::PruningStrategy
    description::String
end

function get_experiments()
    experiments = Experiment[]

    # 1. BASELINE (Plná konfigurace + LossOfPiece Pruning)
    push!(experiments, Experiment(
        "Baseline",
        DEFAULT_CONFIG,
        PRUNE_LOSS_OF_PIECE,
        "Plná heuristika + LossOfPiece pruning"
    ))

    # 2. PRUNING STRATEGIES
    push!(experiments, Experiment(
        "Pruning_None",
        DEFAULT_CONFIG,
        PRUNE_NONE,
        "Plná heuristika + ŽŽádné pruning"
    ))

    push!(experiments, Experiment(
        "Pruning_Retreat",
        DEFAULT_CONFIG,
        PRUNE_RETREAT,
        "Plná heuristika + Retreat pruning (agresivní)"
    ))

    # 3. COMPONENT ABLATIONS (Vždy s LossOfPiece pruning)
    # Odstraňujeme jednu komponentu po druhé z plné konfigurace

    # Bez Materialu (kontrola)
    push!(experiments, Experiment(
        "No_Material",
        HeuristicConfig(use_material=false),
        PRUNE_LOSS_OF_PIECE,
        "Bez materiálu (jen poziční)"
    ))

    # Bez Cornering (vytlačení z centra)
    push!(experiments, Experiment(
        "No_Cornering",
        HeuristicConfig(use_cornering=false),
        PRUNE_LOSS_OF_PIECE,
        "Bez vytlačování z centra"
    ))

    # Bez Coordination (vzdálenost králů + squeeze)
    push!(experiments, Experiment(
        "No_Coordination",
        HeuristicConfig(use_coordination=false),
        PRUNE_LOSS_OF_PIECE,
        "Bez koordinace králů"
    ))

    # Bez Mobility
    push!(experiments, Experiment(
        "No_Mobility",
        HeuristicConfig(use_mobility=false),
        PRUNE_LOSS_OF_PIECE,
        "Bez mobility (soupeřových tahů)"
    ))

    # Bez Retreat Penalty (ale s LossOfPiece pruningem)
    push!(experiments, Experiment(
        "No_RetreatPenalty",
        HeuristicConfig(use_retreat=false),
        PRUNE_LOSS_OF_PIECE,
        "Bez penalizace za ústup"
    ))

    # Bez Net Formation
    push!(experiments, Experiment(
        "No_Net",
        HeuristicConfig(use_net=false),
        PRUNE_LOSS_OF_PIECE,
        "Bez diagonální sítě (Net Formation)"
    ))

    # Bez Attack (přímé sousedství)
    push!(experiments, Experiment(
        "No_Attack",
        HeuristicConfig(use_attack=false),
        PRUNE_LOSS_OF_PIECE,
        "Bez bonusu za přímý útok"
    ))

    # Bez Corner Control
    push!(experiments, Experiment(
        "No_CornerControl",
        HeuristicConfig(use_ctrl=false),
        PRUNE_LOSS_OF_PIECE,
        "Bez kontroly dvojitého rohu"
    ))

    return experiments
end

# ==============================================================================
# SPUŠTĚNÍ JEDNOHO EXPERIMENTU
# ==============================================================================

function run_experiment(exp::Experiment; search_depth::Int=6, max_turns::Int=40)
    println("\n🔬 Spouštím experiment: $(exp.name)")
    println("   Popis: $(exp.description)")

    board = create_assignment_board() # 2 W kings vs 1 R king

    total_nodes = 0
    turns = 0
    winner = "DRAW"

    # Reset stromu pro počítání uzlů
    global tree_enabled = true
    reset_tree()

    # Historie pozic pro detekci remízy opakováním
    position_history = Dict{UInt64,Int}()

    for t in 1:max_turns
        # BÍLÝ (MAX)
        # Detekce opakování před tahem bílého
        board_hash_w = hash(board, hash(true)) # true = white on turn
        position_history[board_hash_w] = get(position_history, board_hash_w, 0) + 1
        if position_history[board_hash_w] >= 3
            winner = "DRAW (Repetition)"
            break
        end

        # Používáme minimax_with_tree pro sběr statistik (počet uzlů)
        # Ale neukládáme soubory
        reset_tree()
        score, move, _ = minimax_with_tree(
            board, search_depth, -Inf, Inf, true, 0, "ROOT";
            config=exp.config, pruning=exp.pruning
        )
        nodes_this_turn = length(tree_nodes)
        total_nodes += nodes_this_turn

        if move === nothing
            winner = "RED" # Bílý nemá tahy
            break
        end

        board = make_move(board, move)
        turns += 1

        # Kontrola výhry Bílého (Červený nemá kameny)
        stats = board_stats(board)
        if stats.red_pieces + stats.red_kings == 0
            winner = "WHITE"
            break
        end

        # ČERVENÝ (MIN) - Hraje optimálně proti dané konfiguraci?
        # Pro spravedlivé srovnání by měl červený hrát vždy stejně (silně/standardně).
        # Zde červený používá stejnou konfiguraci jako bílý (self-play).
        # To je OK pro "optimální hru", ale pokud by červený hrál jinak,
        # výsledky by byly jiné.
        # V zadání je "AI vs AI" nebo "Solver". Předpokládáme self-play.

        reset_tree()

        # Detekce opakování před tahem červeného
        board_hash_r = hash(board, hash(false)) # false = red on turn
        position_history[board_hash_r] = get(position_history, board_hash_r, 0) + 1
        if position_history[board_hash_r] >= 3
            winner = "DRAW (Repetition)"
            break
        end

        score_r, move_r, _ = minimax_with_tree(
            board, search_depth, -Inf, Inf, false, 0, "ROOT";
            config=exp.config, pruning=exp.pruning
        )
        total_nodes += length(tree_nodes)

        if move_r === nothing
            winner = "WHITE" # Červený nemá tahy
            break
        end

        board = make_move(board, move_r)
        # Červený tah se do "turns to win" pro bílého obvykle nepočítá jako celý tah,
        # ale zde počítáme půltahy nebo celé tahy?
        # turns += 1 # Pokud chceme počítat půltahy

        # Kontrola výhry Červeného (Bílý nemá kameny)
        stats = board_stats(board)
        if stats.white_pieces + stats.white_kings == 0
            winner = "RED"
            break
        end
    end

    println("   Výsledek: $winner v $turns (půl)tazích. Uzlů: $total_nodes")
    return (winner, turns, total_nodes)
end

# ==============================================================================
# HLAVNÍ FUNKCE
# ==============================================================================

function main()
    experiments = get_experiments()
    results = []

    println("================================================================")
    println("SPUŠTĚNÍ ABLAČNÍCH STUDIÍ ($(length(experiments)) experimentů)")
    println("================================================================")

    timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
    output_file = "ablation_results_$timestamp.csv"

    # Hlavička CSV
    csv_header = "Experiment,Winner,Turns,Nodes,Description"
    write(output_file, csv_header * "\n")

    println(csv_header)

    for exp in experiments
        res = run_experiment(exp)
        winner, turns, nodes = res

        # Uložit do CSV
        line = "$(exp.name),$winner,$turns,$nodes,\"$(exp.description)\""
        open(output_file, "a") do f
            println(f, line)
        end

        push!(results, (exp, res))
    end

    println("\n================================================================")
    println("VÝSLEDKY ULOŽENY DO: $output_file")
    println("================================================================")

    # Generovat Markdown tabulku pro report
    md_file = "ablation_summary_$timestamp.md"
    open(md_file, "w") do f
        println(f, "# Výsledky Ablačních Studií\n")
        println(f, "| Experiment | Výsledek | Tahy | Uzly (celkem) | Popis |")
        println(f, "|---|---|---|---|---|")
        for (exp, res) in results
            winner, turns, nodes = res
            println(f, "| $(exp.name) | **$winner** | $turns | $nodes | $(exp.description) |")
        end
    end
    println("Markdown report: $md_file")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
