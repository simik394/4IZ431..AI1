# Quarto Obsidian Pipeline - User Guide

This project uses a customized rendering pipeline that allows you to use Obsidian-style syntax while generating professional Quarto PDFs with working cross-references.

## Rendering

**Use the wrapper script to render your documents:**

```bash
python3 /home/sim/.config/quarto/shared/scripts/quarto-obsidian-render.py your-file.qmd --to pdf
```

Or in Neovim: **`<leader>or`** (Obsidian Render)

This script automatically:
1. Transforms Obsidian wikilinks to standard Markdown
2. Resolves image paths for LaTeX compatibility
3. Swaps `.canvas` extensions to `.png`
4. Exports Excalidraw frames to `.quarto/frames/`
5. Generates PDF output to the `out/` directory
6. **Never modifies your source files**

---

## Markdown Basics for PDF

### Line Breaks & Spacing

| What you want | Syntax | Notes |
|---------------|--------|-------|
| New paragraph | Empty line between text | Standard markdown |
| Line break (same paragraph) | Two spaces at end of line | Or use `\` at EOL |
| Hard line break | `\newline` or `\\` | LaTeX command |
| Page break | `{{<pagebreak>}}` | Quarto shortcode |
| Vertical space | `\vspace{1cm}` | Raw LaTeX |
| Non-breaking space | `\ ` (backslash space) | Prevents line break |

### Text Formatting

| Effect | Syntax |
|--------|--------|
| **Bold** | `**text**` |
| *Italic* | `*text*` |
| ~~Strikethrough~~ | `~~text~~` |
| `Code` | `` `code` `` |
| Subscript | `H~2~O` → H₂O |
| Superscript | `x^2^` → x² |
| Small caps | `[text]{.smallcaps}` |

### Special Characters

| Character | Syntax |
|-----------|--------|
| Em dash — | `---` |
| En dash – | `--` |
| Ellipsis … | `...` |
| Non-breaking hyphen | `‑` (Unicode U+2011) |
| Escape special chars | `\*`, `\_`, `\#`, etc. |

### Horizontal Rules

```markdown
---
```

Or with custom width in LaTeX:
```markdown
`\noindent\rule{\textwidth}{0.4pt}`{=latex}
```

---


## Cross-References (Complete Guide)

Quarto uses **prefixes** to identify different element types. Each prefix enables automatic numbering and linking.

### All Cross-Reference Prefixes

| Prefix | Element Type | Example ID | Reference |
|--------|--------------|------------|-----------|
| `fig-` | Figures/Images | `{#fig-plot}` | `@fig-plot` |
| `tbl-` | Tables | `{#tbl-data}` | `@tbl-data` |
| `eq-` | Equations | `{#eq-formula}` | `@eq-formula` |
| `lst-` | Code Listings | `{#lst-code}` | `@lst-code` |
| `sec-` | Sections | `{#sec-intro}` | `@sec-intro` |
| `thm-` | Theorems | `{#thm-main}` | `@thm-main` |
| `lem-` | Lemmas | `{#lem-helper}` | `@lem-helper` |
| `def-` | Definitions | `{#def-term}` | `@def-term` |
| `exm-` | Examples | `{#exm-case}` | `@exm-case` |

### Reference Styles

| Syntax | Output in PDF | When to Use |
|--------|---------------|-------------|
| `@fig-plot` | "Figure 1" | In a sentence: "See @fig-plot" |
| `[@fig-plot]` | "(Figure 1)" | Parenthetical note |
| `-@fig-plot` | "1" | Just the number |

> **Tip**: Avoid underscores in IDs (use `fig-my-plot` not `fig_my_plot`) — they can break LaTeX rendering.

---

## 1. Images & Figures

### Basic Image (no reference)
```markdown
![[my-image.png]]
```
**Result**: Just displays the image.

### Image with Caption
```markdown
![[my-image.png|This is my caption]]
```
**Result**: Image with caption underneath.

### Figure with Cross-Reference (MOST COMMON)
```markdown
![[game-tree.png|The minimax game tree]]{#fig-game-tree}

As shown in @fig-game-tree, the algorithm explores all branches.
```
**Result**: "Figure 1: The minimax game tree" + clickable reference in text.

### Image with Size Control
```markdown
![[diagram.png|My diagram]]{#fig-diagram width="50%"}
```

### Force Position (prevent floating)
```markdown
![[chart.png|Results chart]]{#fig-chart fig-pos="H"}
```
**Result**: Image stays exactly where you put it (doesn't float to top/bottom of page).

### Excalidraw Drawings

The renderer **automatically exports** Excalidraw frames to PNG during rendering:

```markdown
![[my-drawing.excalidraw.md#^frame=01|Step 1 diagram]]{#fig-step1}

As shown in @fig-step1, the first step involves...
```

**How it works:**

1. The renderer detects `#^frame=XX`, `#^group=XX`, or `#^area=XX` in the embed
2. It parses the Excalidraw JSON and finds the frame by name
3. If the frame overlays an embedded image, it **auto-crops** that region
4. The cropped PNG is saved as `{drawing-name}-{type}-{id}.png`

**Requirements:**
- `pip install lzstring Pillow` (for parsing and cropping)
- Excalidraw frames must overlay an embedded image (most common use case)

| Embed Syntax | Auto-Generated PNG |
|--------------|-------------------|
| `![[drawing.excalidraw.md#^frame=01]]` | `drawing-frame-01.png` |
| `![[drawing.excalidraw.md#^group=abc]]` | `drawing-group-abc.png` |

**Console output during render:**
```
  → Exporting Excalidraw frame: frame=01 → Drawing-frame-01.png
  ✓ Created: Drawing-frame-01.png
```

> **Note**: Frame exports are cached. Re-export only happens if the `.excalidraw.md` file is newer than the PNG.

---

## 2. Tables

### Basic Table (no reference)
```markdown
| Column A | Column B |
|----------|----------|
| Value 1  | Value 2  |
```

### Table with Alignment
```markdown
| Left     | Center   | Right    |
|:---------|:--------:|---------:|
| text     | text     | 123.45   |
```
- `:---` = left align
- `:--:` = center 
- `---:` = right align

### Table with Cross-Reference ⭐
```markdown
| Algorithm | Complexity |
|-----------|------------|
| Minimax   | O(b^d)     |
| A-B Prune | O(b^(d/2)) |

: Algorithm comparison {#tbl-algorithms}

See @tbl-algorithms for the complexity analysis.
```
**Result**: "Table 1: Algorithm comparison" + reference works.

> **Important**: The caption line (starting with `:`) must come IMMEDIATELY after the table with NO blank lines!

---

## 3. Math Equations

### Inline Math
```markdown
The value is $x^2 + y^2 = r^2$ which represents a circle.
```
**Result**: Math rendered inline with text.

### Display Math (centered, no number)
```markdown
$$
E = mc^2
$$
```

### Numbered Equation with Reference ⭐
```markdown
The main formula is:

$$
\alpha \cdot \beta = \gamma
$$ {#eq-main}

We can see from @eq-main that...
```
**Result**: Equation gets number (1), and `@eq-main` becomes "Equation 1".

### Multiple Aligned Equations
```markdown
$$
\begin{aligned}
x &= a + b \\
y &= c + d
\end{aligned}
$$ {#eq-system}
```

---

## 4. Code Blocks

### Basic Code (no reference)
````markdown
```python
def hello():
    print("Hello, world!")
```
````

### Code with Line Numbers
````markdown
```{python}
#| code-line-numbers: true

def minimax(node, depth):
    if depth == 0:
        return evaluate(node)
```
````

### Code Listing with Cross-Reference ⭐
````markdown
```{.python #lst-minimax}
def minimax(node, depth, is_max):
    if depth == 0:
        return evaluate(node)
    if is_max:
        return max(minimax(c, depth-1, False) for c in node.children)
    return min(minimax(c, depth-1, True) for c in node.children)
```

The algorithm in @lst-minimax shows the recursive structure.
````
**Result**: Code block becomes "Listing 1", reference works.

### Code with Caption
````markdown
```{.julia #lst-eval lst-cap="Evaluation function"}
function evaluate(board)
    return count_pieces(board)
end
```
````

---

## 5. Sections

### Section with Cross-Reference
```markdown
## Introduction {#sec-intro}

Some content here...

## Methods {#sec-methods}

As discussed in @sec-intro, we now present the methods.
```
**Result**: `@sec-intro` becomes "Section 1" (or whatever number).

---

## 6. Callouts / Admonitions

### Basic Callouts
```markdown
::: {.callout-note}
This is a note with helpful information.
:::

::: {.callout-warning}
Be careful about this!
:::

::: {.callout-tip}
Here's a useful tip.
:::
```

### Callout with Custom Title
```markdown
::: {.callout-important}
## Don't Forget!
This is critically important information.
:::
```

### Collapsible Callout
```markdown
::: {.callout-tip collapse="true"}
## Click to expand
Hidden content here.
:::
```

**Callout types**: `note` (blue), `tip` (green), `warning` (orange), `caution` (red), `important` (purple)

> **Note**: Obsidian's `> [!NOTE]` syntax does NOT work in Quarto PDFs. Use `:::` blocks.

---

## 7. Citations & Bibliography

### Step 1: Create `references.bib`
```bibtex
@article{smith2020,
  author = {John Smith},
  title = {Minimax Algorithms},
  journal = {AI Journal},
  year = {2020}
}
```

### Step 2: Add to YAML
```yaml
---
bibliography: references.bib
---
```

### Step 3: Cite in Text
```markdown
The minimax algorithm was introduced by @smith2020.
According to recent research [@smith2020], the method is efficient.
Smith's work [-@smith2020] is foundational.
```

**Result**:
- `@smith2020` → "Smith (2020)"
- `[@smith2020]` → "(Smith 2020)"
- `[-@smith2020]` → "(2020)" (no author name)

---

## 8. Footnotes

```markdown
This algorithm has important properties[^1] that we discuss later[^2].

[^1]: The first property is...
[^2]: The second property relates to complexity.
```

**Result**: Superscript numbers with footnotes at page/document bottom.

---

## 9. Lists

### Ordered List
```markdown
1. First step
2. Second step
   a. Sub-step A
   b. Sub-step B
3. Third step
```

### Unordered List
```markdown
- Main point
  - Sub-point
  - Another sub-point
- Second main point
```

### Task List
```markdown
- [x] Implement minimax
- [x] Add alpha-beta pruning
- [ ] Optimize evaluation function
```

---

## 10. Page Breaks

```markdown
Content on first page...

{{< pagebreak >}}

Content on new page...
```

---

## 11. Figure Layouts

### Two Images Side-by-Side
```markdown
::: {layout-ncol=2}
![[image1.png|Caption A]]{#fig-a}

![[image2.png|Caption B]]{#fig-b}
:::

See @fig-a and @fig-b for comparison.
```

### Panel of Figures with Overall Caption
```markdown
::: {#fig-panel layout-ncol=2}
![[before.png|Before]]{#fig-before}

![[after.png|After]]{#fig-after}

Comparison of before and after processing
:::

@fig-panel shows both states. Specifically, @fig-before shows the initial state.
```

### Custom Grid Layout
```markdown
::: {layout="[[1,1], [2]]"}
![[small1.png]]

![[small2.png]]

![[wide.png]]
:::
```
**Result**: Two small images on top, one wide image below.

---

## 12. Block Quotes

```markdown
> "The minimax algorithm is fundamental to game AI."
>
> — John von Neumann
```

---

## 13. Mermaid Diagrams

### Flowchart
````markdown
```{mermaid}
flowchart TD
    A[Start] --> B{Is it terminal?}
    B -->|Yes| C[Return value]
    B -->|No| D[Recurse]
    D --> A
```
````

### Diagram with Caption and Reference
````markdown
```{mermaid}
%%| label: fig-flowchart
%%| fig-cap: "Algorithm flowchart"

flowchart LR
    A --> B --> C
```
````

Reference with: `See @fig-flowchart.`

---

## 14. Theorems and Definitions

### Definition
```markdown
::: {#def-minimax}
## Minimax Algorithm
The **minimax algorithm** is a decision rule for minimizing the possible loss
in a worst-case scenario.
:::

As stated in @def-minimax, the algorithm...
```

### Theorem with Proof
```markdown
::: {#thm-optimality}
## Optimality Theorem
Minimax with alpha-beta pruning produces the same result as pure minimax.
:::

::: {.proof}
By induction on the depth of the game tree...
:::

According to @thm-optimality, we can prune safely.
```

---

## 15. Document Styling (YAML Frontmatter)

### Minimal Example
```yaml
---
title: "My Document"
author: "Your Name"
format: pdf
---
```

### Full Featured Example
```yaml
---
title: "Complete Analysis of Minimax"
author: "Your Name"
date: today
format:
  pdf:
    # Structure
    toc: true                    # Table of contents
    toc-depth: 2                 # TOC shows h1 and h2
    number-sections: true        # Section numbering
    
    # Page Layout
    papersize: a4
    geometry:
      - margin=25mm
    
    # Typography
    fontsize: 11pt
    linestretch: 1.15            # Line spacing
    
    # Links
    colorlinks: true
    linkcolor: navy
    
    # Figures
    fig-pos: "H"                 # Keep figures in place
    fig-width: 5                 # Default width (inches)
    
    # Code
    highlight-style: github
    code-line-numbers: true
---
```

### Available Highlight Styles
`github`, `pygments`, `tango`, `espresso`, `zenburn`, `kate`, `breezedark`, `nord`

---

## 16. Canvas Files

Obsidian `.canvas` files are **automatically detected** during rendering.

### Manual Export (Recommended)
1. Open the canvas in Obsidian
2. Click menu (⋮) → Export as image → PNG
3. Save in same folder as the `.canvas` file

### Usage
```markdown
![[my-diagram.canvas|Diagram caption]]{#fig-diagram}
```
**Result**: The `.png` file (same name) is embedded.

---

## 17. Neovim Previews

When using the `v` alias in **WezTerm**, images in `.qmd` and `.md` files render directly in the buffer.
- **Zooming**: Use `Ctrl` + `Shift` + `+` / `-` to scale the terminal view.

---

## Quick Reference Card

| Element | Create | Reference |
|---------|--------|-----------|
| Figure | `![[img.png\|Cap]]{#fig-x}` | `@fig-x` |
| Table | `{#tbl-x}` after `:` caption | `@tbl-x` |
| Equation | `$$ ... $$ {#eq-x}` | `@eq-x` |
| Code | `` ```{.py #lst-x}`` | `@lst-x` |
| Section | `## Title {#sec-x}` | `@sec-x` |
| Definition | `::: {#def-x}` | `@def-x` |
| Theorem | `::: {#thm-x}` | `@thm-x` |
