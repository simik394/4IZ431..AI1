#!/usr/bin/env julia
# ==============================================================================
# SIMULÁTOR ANGLICKÉ DÁMY - SPOUŠTĚCÍ SKRIPT
# ==============================================================================
#
# POUŽITÍ:
#   julia simulate.jl [OPTIONS]
#
# PŘÍKLADY:
#   julia simulate.jl                                    # Výchozí nastavení
#   julia simulate.jl --board=assignment --depth=6
#   julia simulate.jl --white=aggressive --red=defensive
#   julia simulate.jl --board=endgame_2v2 --turns=5
#   julia simulate.jl --list                             # Zobrazí dostupné možnosti
#
# OPTIONS:
#   --board=NAME       Počáteční konfigurace desky (default: assignment)
#   --white=NAME       Heuristika pro bílého (default: my_heuristic)
#   --red=NAME         Heuristika pro červeného (default: my_heuristic)
#   --depth=N          Hloubka prohledávání (default: 6)
#   --turns=N          Počet tahů k simulaci (default: 2)
#   --no-trees         Neukládat prohledávací stromy
#   --list             Zobrazit dostupné heuristiky a desky
#   --help             Zobrazit nápovědu
#
# ==============================================================================

# Načti hlavní simulaci
include("testvaluefunc.jl")

# ------------------------------------------------------------------------------
# PARSOVÁNÍ ARGUMENTŮ
# ------------------------------------------------------------------------------

function parse_args()
    config = Dict(
        "board" => "assignment",
        "white_heuristic" => "my_heuristic",
        "red_heuristic" => "my_heuristic",
        "depth" => 6,
        "turns" => 2,
        "save_trees" => true,
        "output_dir" => joinpath("out", "simulation_outputs"),
        "list" => false,
        "help" => false
    )

    for arg in ARGS
        if startswith(arg, "--board=")
            config["board"] = String(split(arg, "=")[2])
        elseif startswith(arg, "--white=")
            config["white_heuristic"] = String(split(arg, "=")[2])
        elseif startswith(arg, "--red=")
            config["red_heuristic"] = String(split(arg, "=")[2])
        elseif startswith(arg, "--depth=")
            config["depth"] = parse(Int, split(arg, "=")[2])
        elseif startswith(arg, "--turns=")
            config["turns"] = parse(Int, split(arg, "=")[2])
        elseif startswith(arg, "--output-dir=")
            config["output_dir"] = String(split(arg, "=")[2])
        elseif arg == "--no-trees"
            config["save_trees"] = false
        elseif arg == "--list"
            config["list"] = true
        elseif arg == "--help" || arg == "-h"
            config["help"] = true
        end
    end

    return config
end

function show_help()
    println("""
    SIMULÁTOR ANGLICKÉ DÁMY
    =======================

    Použití: julia simulate.jl [OPTIONS]

    Možnosti:
      --board=NAME       Počáteční konfigurace desky
      --white=NAME       Heuristika pro bílého hráče
      --red=NAME         Heuristika pro červeného hráče
      --depth=N          Hloubka prohledávání (default: 6)
      --turns=N          Počet tahů k simulaci (default: 2)
      --output-dir=DIR   Adresář pro výstupy (default: out/simulation_outputs)
      --no-trees         Neukládat prohledávací stromy
      --list             Zobrazit dostupné možnosti
      --help             Zobrazit tuto nápovědu

    Příklady:
      julia simulate.jl --board=assignment --depth=6
      julia simulate.jl --white=aggressive --red=defensive
      julia simulate.jl --board=endgame_2v2 --turns=5
    """)
end

function show_list()
    println("="^60)
    list_heuristics()
    println()
    list_boards()
    println("="^60)
end

# ------------------------------------------------------------------------------
# HLAVNÍ FUNKCE
# ------------------------------------------------------------------------------

function main()
    config = parse_args()

    if config["help"]
        show_help()
        return
    end

    if config["list"]
        show_list()
        return
    end

    println("\n" * "="^70)
    println("KONFIGURACE SIMULACE")
    println("="^70)
    println("  Deska:           $(config["board"])")
    println("  Heuristika BÍLÝ: $(config["white_heuristic"])")
    println("  Heuristika ČERV: $(config["red_heuristic"])")
    println("  Hloubka:         $(config["depth"])")
    println("  Tahů:            $(config["turns"])")
    println("  Ukládat stromy:  $(config["save_trees"])")
    println("  Výstupní adr.:   $(config["output_dir"])")
    println("="^70)

    # Spusť simulaci
    run_configurable_simulation(
        board_name=config["board"],
        white_heuristic_name=config["white_heuristic"],
        red_heuristic_name=config["red_heuristic"],
        search_depth=config["depth"],
        num_turns=config["turns"],
        save_trees=config["save_trees"],
        output_basedir=config["output_dir"]
    )
end

# Spusť hlavní funkci
main()
