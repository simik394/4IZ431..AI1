
## 2026-02-12: PRUNE_HUMAN Beam Search Missing

**Problem**: `PRUNE_HUMAN` enum value was defined but never checked in `minimax_with_tree` or `minimax`. The beam search K=2 logic only existed in the benchmark function.

**Lesson**: When adding enum values, verify they're checked in ALL relevant code paths (not just one function). The enum + comment described the intent, but neither minimax variant had an `if pruning == PRUNE_HUMAN` branch.

**Fix**: Added PRUNE_HUMAN handling to both minimax functions: loss-of-piece + retreat + beam K=2. Human tree dropped from 901 → 39 nodes.

**Also**: Always clear Quarto's `_freeze/` cache when modifying included Julia source files — Quarto won't re-execute cells unless the cache is stale or deleted.
