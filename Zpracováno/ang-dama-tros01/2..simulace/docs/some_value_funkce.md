# Dokumentace hodnotící funkce (Value Function)

## Přehled

Hodnotící funkce `my_heuristic(board)` slouží k ohodnocení herní pozice v anglické dámě. Vrací celé číslo, kde:
- **Vysoké kladné hodnoty** = výhodné pro BÍLÉHO
- **Vysoké záporné hodnoty** = výhodné pro ČERVENÉHO
- **0** = vyrovnaná pozice

## Komponenty heuristiky

### A. Materiál (základní složka)

| Typ kamene | Hodnota |
|------------|---------|
| Pěšec | 100 |
| Král (dáma) | 300 |

**Výpočet:** Bílé kameny přičítají, červené odečítají.

```julia
piece_value = is_king(p) ? 300 : 100
score += is_white(p) ? piece_value : -piece_value
```

**Příklad:** 2 bílí králové vs 1 červený král = +600 - 300 = **+300 základní skóre**

---

### B. Kontrola středu (+5 bodů)

Kameny na sloupcích 3-6 (střed desky) dostávají bonus.

```
    A  B  C  D  E  F  G  H
    1  2 [3  4  5  6] 7  8
              ↑
         bonus +5
```

**Důvod:** Střední pozice poskytují větší mobilitu a kontrolu nad deskou.

---

### C. Okrajová bezpečnost pro pěšce (+10 bodů)

Pěšec na okraji desky (sloupec A nebo H) **nemůže být přeskočen** = bezpečná pozice!

```
    A  B  C  D  E  F  G  H
   [+]              [+]
    ↑                ↑
  bezpečné       bezpečné
```

**Důvod:** Pěšec u zdi je chráněný před skoky soupeře.

---

### D. Dvojitý roh / Double Corner (+15 bodů)

Extra bonus pro pěšce v "double corner" pozicích (29, 32, 1, 4):

| Pozice | Souřadnice | Bonus |
|--------|------------|-------|
| 29 | A8 | +15 |
| 32 | H8 | +15 |
| 1 | B1 | +15 |
| 4 | H1 | +15 |

**Důvod:** Dvojité rohy jsou strategicky nejbezpečnější pozice pro pěšce.

---

### E. Rohová penalizace PRO KRÁLE (-25 bodů)

**Pouze pro krále!** Král v rohu nemá kam uniknout při nahánění.

Penalizované pozice: B1, H1, A8, H8

**Důvod:** Král potřebuje mobilitu – v rohu je v pasti.

---

### F. Okrajová penalizace PRO KRÁLE (-8 bodů)

Král na jakémkoliv okraji má omezenou mobilitu.

Když má jeden hráč **více králů** než soupeř, aktivuje se logika nahánění:

```julia
# Bílý má výhodu v králích
if white_kings > red_kings
    # Spočítej Manhattan vzdálenost mezi králi
    avg_distance = ...
    # Menší vzdálenost = vyšší skóre
    score += (14 - avg_distance) * 10
end
```

**Manhattan vzdálenost:** `|r1 - r2| + |c1 - c2|`

**Maximální bonus:** (14 - 0) × 10 = **+140 bodů** (králové vedle sebe)

---

## Celkový vzorec

```
SKÓRE = Σ(materiál) 
      + Σ(střed_bonus)
      - Σ(roh_penalizace)
      - Σ(okraj_penalizace)
      + nahánění_bonus
```

## Příklad výpočtu

**Pozice ze zadání:** W@10, W@14, R@1

| Složka | Bílý | Červený | Přínos |
|--------|------|---------|--------|
| Materiál | 2×300=600 | 1×300=300 | +300 |
| Střed (sloupec 4) | W@10, W@14 | - | +10 |
| Okraj | - | R@1 (řádek 1) | +5 |
| Nahánění | 2:1 králové | - | ~+120 |
| **Celkem** | | | **~+435** |

---

## Silné stránky

1. ✅ **Materiálová dominance** – správně preferuje více kamenů
2. ✅ **Poziční hodnocení** – rozlišuje kvalitu pozic
3. ✅ **Endgame strategie** – aktivně nahání v koncovce

## Slabé stránky

1. ⚠️ **Chybí mobilita** – nepočítá počet možných tahů
2. ⚠️ **Chybí struktura** – nehodnotí propojené kameny
3. ⚠️ **Statické váhy** – konstantní hodnoty pro všechny fáze hry

---

## Možná vylepšení

### 1. Mobilita
```julia
mobility = length(get_legal_moves(board, WHITE))
         - length(get_legal_moves(board, RED))
score += mobility * 2
```

### 2. Vzdálenost od proměny (pro pěšce)
```julia
if p == WHITE  # blíž k řádku 1 = lepší
    advancement_bonus = (8 - r) * 3
    score += advancement_bonus
end
```

### 3. Double corner trap (rohová past)
```julia
# Penalizace za červeného krále v rohu s bílými blokujícími únik
if is_trapped_in_corner(board, red_king_pos)
    score += 50
end
```

---

## Použití

```julia
# V testvaluefunc.jl
function my_heuristic(board::Matrix{Int})
    # Tvůj kód zde
    return score
end

# Spuštění simulace
julia testvaluefunc.jl
```

Výstupy se uloží do `simulation_outputs/run_TIMESTAMP/`
