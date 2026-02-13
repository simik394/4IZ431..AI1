# Lessons Learned: Pruning Terminology & Tree Visualization

## 1. Terminology Accuracy
- **Issue:** Labeling Alpha-Beta as `PRUNE_NONE` is confusing because Alpha-Beta *is* a pruning algorithm.
- **Fix:** Renamed `PRUNE_NONE` to `PRUNE_BASIC`.
- **Lesson:** Terminology matters. "None" implies "no optimization", but Alpha-Beta is already an optimization over Minimax. Use "Basic" or "Standard" instead.

## 2. Tree Visualization vs. Logic
- **Issue:** Users verify logic by reading tree outputs. If the output says "Pruned" but the strategy is "None", trust is lost.
- **Lesson:** Ensure the visual output (text labels) matches the internal logic variables. If a branch is cut by alpha-beta, it should be clear that it's a *standard* cutoff, not a heuristic one.

## 3. Consistency Across Files
- **Issue:** Changing an Enum in Julia code (`testvaluefunc.jl`) requires updating all references in documentation (`.qmd`) that manually print/reference those Enum values.
- **Lesson:** Grep is your friend. Always search for the old term across the entire directory before committing a rename.
