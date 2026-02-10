# Lessons Learned — Verification 2026-02-10

## 1. English draughts vs International draughts
- **Backward pawn capture**: In English draughts, pawns can ONLY jump forward. Backward jumps are a rule of International draughts (10×10 board). The code had a comment incorrectly claiming backward jumps are allowed in English draughts.
- **Promotion during jump**: In English draughts, when a pawn reaches the crown row during a multi-jump, it is promoted AND the turn ends immediately. No further jumps are allowed in that turn. This differs from some other variants.

## 2. Code-report synchronization
- Heuristic code had 5 components (~3000 points of scoring impact) that were completely undocumented in the formal equations. This created a false impression that only 7 components existed.
- Safety zone defined differently in code (rectangular area) vs equations (exact fields). Always define game constants as exact field sets, not geometric approximations.

## 3. Context-dependent bug impact
- Both engine bugs are irrelevant for king-only endgames (the specific test scenario), but would produce illegal moves in midgame positions with pawns. Always verify the scope of bugs before panicking.

## 4. Julia syntax
- `const` cannot be used inside functions in Julia. Use regular variables or define constants at module scope.

## 5. Value Function Tuning via Ablation
- **Surprising discoveries**: Ablation studies are crucial. We found that the complex "Net Formation" heuristic, designed for 2v1 endgames, was actually causing the AI to draw (by preventing simple direct attacks) instead of winning. Removing it led to a win in 9 moves.
- **Component interaction**: Individual components might be "logical" in isolation but counter-productive when combined with others (e.g., Cornering vs Net).
- **Pruning savings**: Simple "LossOfPiece" pruning (pseudo-terminal state) saved ~9% of search nodes without affecting decision quality (Baseline vs Pruning_None).

## 6. Simulation Scripting
- **Global scope in `include()`**: When including a script that uses global variables (like `tree_enabled` in `testvaluefunc.jl`), setting them in a local scope (inside a function in another script) defines a *new local* variable, shadowing the global one. Always use `global variable = value` to modify the included script's state.

## 7. Diagnosis of "Optimal" Strategy Failure
- **Looping vs Winning**: The baseline strategy (with Net Formation) was superior in static evaluation but failed in practice because it created a "local optimum" trap. The AI preferred to oscillate between two high-scoring states rather than make a "lower scoring" move required to progress the game.
- **Repetition Detection**: The original simulation (`run_assignment_simulation`) masked this by detecting the 3-fold repetition and declaring a Draw. The initial ablation script lacked this check, running until the move limit.
- **Fix**: Disabling the component that caused the high-score trap (`No_Net`) allowed the AI to find the true winning path. This highlights the danger of over-engineered heuristics without dynamic verification.

# Lesson Learned: Minimax Alpha-Beta Analysis

## Analýza logů (Strom prohledávání)
1.  **Navigace v logu**: Soubory `strom_kompletni.txt` mohou být extrémně dlouhé (tisíce řádků).
    -   Pro nalezení konkrétní větvě (např. tah `14-9`) je efektivní použít `grep -n` pro získání čísla řádku a následně číst relevantní blok.
    -   Příklad: `grep -n "^  ├─ 14-9 (MIN)" strom_kompletni.txt`

2.  **Interpretace [α cut-off] a [β cut-off]**:
    -   V `testvaluefunc.jl` je logika ořezávání implementována takto:
        -   **[α cut-off]**: Nastává v uzlu hráče MIN, když hodnota podstromu je menší nebo rovna Alpha (kterou drží MAX předek). Znamená to, že MAX by tuto větev nikdy nevybral, protože má lepší alternativu.
        -   **[β cut-off]**: Nastává v uzlu hráče MAX, když hodnota podstromu je větší nebo rovna Beta (kterou drží MIN předek). Znamená to, že MIN by tuto větev nikdy "nepustil" k realizaci.

3.  **Heuristika (Skóre)**:
    -   Hodnoty skóre kolem 1700 v této implementaci reflektují kombinaci materiálu (král = 300) a velkých pozičních bonusů (vzdálenost králů, sevření = až 1000 bodů).
    -   Skóre 99999 / -99999 indikuje terminální stav (výhra/prohra).

## Spouštění simulace
-   Skript `testvaluefunc.jl` lze spustit s parametrem `save_trees=true` pro generování podrobných logů.
-   Výstupy se ukládají do adresáře `simulation_outputs/run_<timestamp>`.

## Quarto Code Embedding
- **Issue:** The `quarto-ext/include-code-files` extension (v1.0.0 via `quarto add`) expects `# start snippet name` markers and `snippet="name"` attribute, which conflicts with the standard `#| region: name` syntax used in Quarto cells.
- **Solution:** Patched `_extensions/quarto-ext/include-code-files/include-code-files.lua` to support both `snippet` and `region` attributes, and added regex support for `#| region: name` / `#| endregion: name` markers.
- **Key Takeaway:** Always check the specific syntax requirements of Quarto extensions as they may differ from core Quarto features. When in doubt, checking the `.lua` filter source code is the most reliable way to debug.

## Quarto Project Structure
- **Output Directory Preference:** All PDF outputs should target the `out/pdfs/` directory (e.g., `project.output-dir: out/pdfs` in `_quarto.yml`) for consistency and to keep the root directory clean.
- **Path Resolution in Staging:** When using wrapper scripts to render from a staging location (to handle Obsidian syntax), care must be taken with relative paths (e.g., `include()`). Rendering from a temporary file within the project root (`.__temp_filename.qmd`) is safer than moving files to a subdirectory, as it preserves relative path resolution for included code files.