# Perfect Endgame Heuristic - Documentation

Evaluační funkce pro koncovku **2 králové vs 1 král** v anglické dámě.

## Funkce

**Název:** `perfect_endgame_heuristic`  
**Umístění:** [heuristics.jl](heuristics.jl)  
**Přístup:** Obecné principy (bez hardcoded pozic)

## Klíčové Principy

### PRINCIP 1: Materiál
| Komponenta | Hodnota | Popis |
|------------|---------|-------|
| Bílý král | +100 | Základní hodnota |
| Červený král | -100 | Záporná hodnota |
| Výhra | +10000 | Červený nemá figurky |
| Prohra | -10000 | Bílý nemá figurky |
| 1v1 stav | -99999 | Zakázaný (garantovaná výhra existuje) |

### PRINCIP 2: Pozice Červeného
| Stav | Hodnota | Popis |
|------|---------|-------|
| Red v safety zone | -600 | Červený v bezpečí = špatně pro bílého |
| Red mimo safety zone | +500 | Červený zranitelný = dobře pro bílého |
| Vzdálenost od rohu | +80/jednotka | Čím dále od rohu, tím lépe |

> **Safety zone** = řádky 1-2, sloupce 1-3 (pole 1, 2, 5, 6, 9, 10)

### PRINCIP 3: Koordinace Bílých Králů
| Metrika | Hodnota | Popis |
|---------|---------|-------|
| Vzdálenost 2-4 | +300 | Optimální koordinace |
| Squeeze (blízkost k R) | +(6-avg)*60 | Čím blíž k červenému, tím lépe |
| Bracket (obklíčení) | +200 | Králové na opačných stranách R |

### PRINCIP 3B: Diagonální Síťová Formace
Jakmile **kotva** (jeden W) obsadí roh (pole 1), **operátor** by měl jít diagonálně pryč:

| Pozice operátora | Hodnota | Popis |
|------------------|---------|-------|
| row≥4, col≥4 | +1200 | Optimální (pole 18, 15, 22...) |
| row≥3, col≥4 | +600 | Přijatelná |
| dist≤3 od rohu | -800 | Crowding - špatně |

### PRINCIP 4: Mobilita Červeného
| Počet tahů R | Hodnota | Popis |
|--------------|---------|-------|
| 0 | +10000 | Výhra |
| 1 | +600 | Téměř výhra |
| 2 | +300 | Omezená mobilita |
| 3 | +100 | Přijatelné |

### PRINCIP 5: Cornering
| Stav | Hodnota | Popis |
|------|---------|-------|
| R na kraji (row 1/8) | +150 | Méně únikových cest |
| R na kraji (col 1/8) | +150 | Méně únikových cest |
| Vzdálenost R od středu | +40/jednotka | Čím dále od středu |

### PRINCIP 6: Kontrola Dvojitého Rohu

**Kontextově závislé** - chování závisí na tom, zda je již některý W blízko rohu:

#### Žádný W blízko rohu:
| Stav | Hodnota | Popis |
|------|---------|-------|
| closer_dist ≤ 3 | +(5-dist)*300 | Incentivizuje přiblížení prvního W |

#### Jeden W blízko rohu:
| Stav | Hodnota | Popis |
|------|---------|-------|
| farther_dist ≥ 4 | +400 | Dobrý spread operátora |
| farther_dist ≥ 3 | +200 | Přijatelný spread |
| Crowding | -600 | Oba W příliš blízko rohu |
| W přímo na poli 1 | +800 | Kontrola rohu |

## Validace

### Testováno na hloubkách:
- **Depth 5**: ✅ WHITE WINS (15 tahů)
- **Depth 6**: ✅ WHITE WINS (15 tahů)

### Konzistence:
5/5 běhů produkuje identický výsledek:

```
  1. Bílý: 14-9
  2. Červený: 1-5
  3. Bílý: 10-14
  4. Červený: 5-1
  5. Bílý: 9-5
  6. Červený: 1-6
  7. Bílý: 5-1
  8. Červený: 6-2
  9. Bílý: 14-18
 10. Červený: 2-7
 11. Bílý: 18-15
 12. Červený: 7-3
 13. Bílý: 15-11
 14. Červený: 3-7
 15. Bílý: 11x2 ← VÝHRA
```

## Technické Detaily

### Move Ordering
Tahy jsou seřazeny podle heuristické hodnoty před prohledáváním:
- **MAX** (bílý): sestupně (nejlepší první)
- **MIN** (červený): vzestupně

Výhody:
1. Lepší alpha-beta pruning (rychlejší)
2. Tiebreaking - při rovnosti minimax hodnot vítězí tah s vyšší heuristikou

### Zakázané Stavy
| Stav | Hodnota |
|------|---------|
| 1v1 (ztráta krále) | -99999 |

## Použití

```julia
include("testvaluefunc.jl")

# Spusť simulaci
run_assignment_simulation(
    search_depth=6,    # Hloubka prohledávání
    num_turns=20,      # Max počet tahů
    save_trees=false   # Ukládání stromů
)
```

## Commity

- `d87da39`: General heuristic works at depth 5 AND 6
- `f5b7447`: 1v1 is forbidden state
- `5051e40`: Initial documentation
