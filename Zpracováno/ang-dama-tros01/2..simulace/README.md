# Simulátor Anglické Dámy (English Checkers)


Framework pro testování hodnotících funkcí (heuristik) s minimax algoritmem a alfa-beta ořezáváním.

## Požadavky

- **Julia 1.6+**
- **Graphviz** (pro vizualizaci stromů, příkaz `dot`)
  - Ubuntu/Debian: `sudo apt install graphviz`
  - macOS: `brew install graphviz`
  - Windows: Stáhnout installer z graphviz.org

## Rychlý start

```bash
# Spusť výchozí simulaci (zadání úlohy)
julia testvaluefunc.jl

# Nebo použij CLI spouštěč
julia simulate.jl --list                              # Zobraz dostupné možnosti
julia simulate.jl --board=assignment --depth=6        # Konfigurovatelné spuštění
```

## Struktura souborů

| Soubor | Popis |
|--------|-------|
| `testvaluefunc.jl` | Hlavní simulátor s herní logikou |
| `heuristics.jl` | Hodnotící funkce pro AI |
| `boards.jl` | Konfigurace desek |
| `simulate.jl` | CLI spouštěč |

## Použití CLI

```bash
julia simulate.jl [OPTIONS]

OPTIONS:
  --board=NAME       Název desky (default: assignment)
  --white=NAME       Heuristika pro bílého (default: my_heuristic)
  --red=NAME         Heuristika pro červeného (default: my_heuristic)
  --depth=N          Hloubka prohledávání (default: 6)
  --turns=N          Počet tahů (default: 2)
  --no-trees         Neukládat prohledávací stromy
  --list             Zobrazit dostupné možnosti
  --help             Nápověda
```

### Příklady

```bash
# Agresivní bílý vs defenzivní červený
julia simulate.jl --white=aggressive --red=defensive

# Koncovka 2v2 s hlubším prohledáváním
julia simulate.jl --board=endgame_2v2 --depth=8 --turns=5

# Porovnání jednoduché vs plné heuristiky
julia simulate.jl --white=my_heuristic --red=simple
```

## Dostupné heuristiky

| Název | Popis |
|-------|-------|
| `my_heuristic` | Kompletní heuristika s materiálem, pozicí a endgame logikou |
| `simple` | Pouze materiál (pěšec=100, král=300) |
| `aggressive` | Preferuje postup a útok |
| `defensive` | Preferuje bezpečné pozice |
| `random` | Materiál + náhodný šum (pro testování) |

## Dostupné desky

| Název | Popis |
|-------|-------|
| `assignment` | Zadání úlohy: W@10,14 vs R@1 |
| `standard` | Standardní počáteční pozice |
| `endgame_2v2` | Koncovka 2 králové vs 2 králové |
| `endgame_3v1` | Koncovka 3 vs 1 král |
| `midgame` | Střední hra |
| `empty` | Prázdná deska pro vlastní nastavení |

## Přidání vlastní heuristiky

1. Otevři `heuristics.jl`
2. Přidej novou funkci:

```julia
function moje_heuristika(board::Matrix{Int})
    score = 0
    # Tvoje logika...
    return score
end
```

3. Zaregistruj v `HEURISTICS`:

```julia
const HEURISTICS = Dict(
    # ... existující ...
    "moje" => moje_heuristika
)
```

4. Použij: `julia simulate.jl --white=moje`

## Přidání vlastní desky

Použij `create_board_from_pieces()` v `boards.jl`:

```julia
function create_moje_deska()
    return create_board_from_pieces(
        white_pieces = [21, 22],       # Bílí pěšci na pozicích 21, 22
        white_kings = [14],            # Bílý král na pozici 14
        red_pieces = [5, 6],           # Červení pěšci
        red_kings = [1]                # Červený král
    )
end

# Přidej do BOARDS:
const BOARDS = Dict(
    # ... existující ...
    "moje_deska" => create_moje_deska
)
```

## Notace pozic (1-32)

```
     1   2   3   4     (řádek 1 - červená strana)
   5   6   7   8
     9  10  11  12
  13  14  15  16
    17  18  19  20
  21  22  23  24
    25  26  27  28
  29  30  31  32       (řádek 8 - bílá strana)
```

## Výstupy simulace

Výstupy se ukládají do `simulation_outputs/run_YYYYMMDD_HHMMSS/`:
- `průběh_simulace.txt` - Log celé hry
- Podsložky tahů (např. `tah_1_bily/`):
  - `strom_kompletni.svg` - Vizualizace celého stromu (pokud je menší než 500 uzlů)
  - `strom_hloubka_2.svg` - Přehledový strom (hloubka 2)
  - `strom_hloubka_3.svg` - Přehledový strom (hloubka 3)
  - `vetve/*.svg` - Detailní pohled na jednotlivé větve (pro velké stromy)

Pro automatickou vizualizaci je nutný nainstalovaný Graphviz (`dot`). Pokud není nalezen, budou uloženy pouze `.dot` soubory.

## Pravidla anglické dámy

- Pěšci se pohybují diagonálně dopředu o 1 pole
- Králové se pohybují diagonálně libovolným směrem o 1 pole
- Skákání přes soupeřovy kameny je **povinné**
- Pěšec se stane králem když dosáhne poslední řady
