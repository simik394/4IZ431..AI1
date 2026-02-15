
"""
    print_tree_ascii(max_depth::Int=3; only_best::Bool=false)

Vytiskne textovou reprezentaci stromu (ASCII art) do konzole/výstupu.
Ideální pro Quarto "output: asis".
"""
function print_tree_ascii(max_display_depth::Int; only_best::Bool=false)
    global tree_nodes

    if isempty(tree_nodes)
        println("⚠️ Strom je prázdný")
        return
    end

    # Najdi kořen (předpokládáme, že po reset_tree() je první přidaný uzel kořen)
    # Alternativně: kořen má nejvyšší depth (startovní hloubka) a je první ve stromu.
    root = tree_nodes[1]

    if root === nothing
        println("⚠️ Kořen stromu nenalezen")
        return
    end

    # Rekurzivní funkce pro tisk
    function print_node(node_id::Int, prefix::String, is_last::Bool, current_display_depth::Int)
        if current_display_depth > max_display_depth
            return
        end

        # Najdi uzel
        node = nothing
        for n in tree_nodes
            if n.id == node_id
                node = n
                break
            end
        end

        if node === nothing
            return
        end

        # Tisk
        marker = is_last ? "└── " : "├── "

        # Info o uzlu
        move_str = node.move_str == "" ? "ROOT" : node.move_str
        score_str = string(round(node.score, digits=1))
        if node.score >= 9999
            score_str = "WIN"
        elseif node.score <= -9999
            score_str = "LOSS"
        end

        note = ""
        if node.is_pruned
            note = " [PRUNED]"
        elseif node.is_max
            note = " (MAX)"
        else
            note = " (MIN)"
        end

        println(prefix * marker * "**" * move_str * "**: " * score_str * note)

        # Děti
        children_ids = node.children

        # Pokud only_best, vyber jen nejlepšího potomka (Principal Variation)
        # To je složitější, protože musíme vědět, který je "best".
        # V našem logu to nemáme explicitně označené, kromě toho že minimax vrací best_move.
        # Ale children jsou uloženy v pořadí procházení.
        # U seřazeného stromu je první dítě obvykle nejlepší (pokud move ordering funguje).

        count = length(children_ids)
        for (i, child_id) in enumerate(children_ids)
            new_prefix = prefix * (is_last ? "    " : "│   ")
            is_last_child = (i == count)
            print_node(child_id, new_prefix, is_last_child, current_display_depth + 1)
        end
    end

    print_node(root.id, "", true, 1)
end
