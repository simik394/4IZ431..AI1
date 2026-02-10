# render_search_trees.jl
# Skript pro vylepšení a renderování prohledávacích stromů z textového výstupu.
# Parsuje strom_kompletni.txt, generuje vylepšený DOT s α/β hodnotami a renderuje do PDF.

"""
Parsuje jeden řádek textového stromu a extrahuje informace o uzlu.
Vrací NamedTuple (indent, move, score, alpha, beta, is_max, is_pruned, position)
"""
function parse_tree_line(line::String)
    # Odsazení = hloubka (počet mezer před ├─ nebo │)
    m_node = match(r"^(\s*)[├│]\s*[─ ]\s*(.+?)\s*\((\w+)\)\s*$", line)
    if m_node === nothing
        return nothing
    end
    indent = length(m_node[1])
    content = m_node[2]
    role = m_node[3]  # MAX / MIN

    is_pruned = occursin("[OŘEZÁNO]", content) || occursin("cut-off", content)
    return (indent=indent, content=content, role=role, is_pruned=is_pruned)
end

"""
Parsuje textový strom (strom_kompletni.txt) do strukturované podoby.
Vrací vektor uzlů s jejich vztahy.
"""
struct TreeNode
    id::Int
    move::String
    score::String
    alpha::String
    beta::String
    role::String      # "MAX" / "MIN"
    position::String
    is_pruned::Bool
    depth::Int
    children::Vector{Int}
end

function parse_text_tree(filepath::String; max_depth::Int=3)
    lines = readlines(filepath)
    nodes_dict = Dict{Int,TreeNode}()
    nodes_list = TreeNode[] # Zachováme pořadí pro iteraci
    # Stack pro sledování rodičů: (indent_level, node_id)
    parent_stack = Tuple{Int,Int}[]
    node_id = 0

    i = 1
    while i <= length(lines)
        line = lines[i]

        # Hledáme řádky s uzly (ty co mají ├─ nebo vedou k uzlu)
        # Formát: "  ├─ MOVE (MAX/MIN)" nebo "  ├─ ROOT (MAX/MIN)"
        m_header = match(r"^(\s*)[├└]─\s+(.+?)\s+\((MAX|MIN)\)\s*$", line)
        if m_header !== nothing
            indent = length(m_header[1])
            move = strip(m_header[2])
            role = m_header[3]

            # Následující řádek má score, α, β
            score_str = ""
            alpha_str = ""
            beta_str = ""
            pos_str = ""
            is_pruned = false

            if i + 1 <= length(lines)
                detail_line = lines[i+1]
                m_score = match(r"Score:\s*([^\s,]+)", detail_line)
                m_alpha = match(r"α=([^\s,]+)", detail_line)
                m_beta = match(r"β=([^\s,]+)", detail_line)
                m_pruned = match(r"\[OŘEZÁNO\]", detail_line)

                score_str = m_score !== nothing ? m_score[1] : ""
                alpha_str = m_alpha !== nothing ? m_alpha[1] : ""
                beta_str = m_beta !== nothing ? m_beta[1] : ""
                is_pruned = m_pruned !== nothing
            end
            if i + 2 <= length(lines)
                m_pos = match(r"Pozice:\s*(.+)", lines[i+2])
                pos_str = m_pos !== nothing ? strip(m_pos[1]) : ""
            end

            # Vypočti hloubku z odsazení (2 mezery = 1 úroveň)
            depth = div(indent, 2)

            # Limit hloubky
            if depth > max_depth
                i += 3  # přeskoč detail řádky
                continue
            end

            node_id += 1
            node = TreeNode(node_id, move, score_str, alpha_str, beta_str,
                role, pos_str, is_pruned, depth, Int[])
            nodes_dict[node_id] = node
            push!(nodes_list, node)

            # Najdi rodiče: poslední uzel s menším indent
            while !isempty(parent_stack) && parent_stack[end][1] >= indent
                pop!(parent_stack)
            end
            if !isempty(parent_stack)
                parent_id = parent_stack[end][2]
                push!(nodes_dict[parent_id].children, node_id)
            end
            push!(parent_stack, (indent, node_id))

            i += 3  # přeskoč Score a Pozice řádky
        else
            i += 1
        end
    end

    return nodes_list
end

"""
Extrahuje podstrom začínající v uzlu s `root_id`.
"""
function extract_subtree(nodes::Vector{TreeNode}, root_id::Int)
    # Vytvoříme rychlou mapu pro vyhledávání
    id_map = Dict(n.id => n for n in nodes)

    subtree_ids = Set{Int}([root_id])
    to_visit = [root_id]

    while !isempty(to_visit)
        current_id = popfirst!(to_visit)
        if haskey(id_map, current_id)
            for child_id in id_map[current_id].children
                if !(child_id in subtree_ids)
                    push!(subtree_ids, child_id)
                    push!(to_visit, child_id)
                end
            end
        end
    end

    return filter(n -> n.id in subtree_ids, nodes)
end

"""
Extrahuje pouze kořen a jeho přímé potomky (Overview).
"""
function extract_overview(nodes::Vector{TreeNode}, root_id::Int)
    id_map = Dict(n.id => n for n in nodes)
    if !haskey(id_map, root_id)
        return TreeNode[] # Pokud root neexistuje
    end
    root = id_map[root_id]

    overview_ids = Set{Int}([root_id])
    for child_id in root.children
        # Přidej jen pokud dítě skutečně existuje v kolekci (kvůli hloubce)
        if haskey(id_map, child_id)
            push!(overview_ids, child_id)
        end
    end
    return filter(n -> n.id in overview_ids, nodes)
end

"""
Formátuje číslo pro label (zkrácení Inf/-Inf, zaokrouhlení).
"""
function fmt_num(s::String)
    s = strip(s)
    s == "Inf" && return "+∞"
    s == "-Inf" && return "-∞"
    # Zkrať -99999.0 → -∞ (terminální prohra)
    if s == "-99999.0" || s == "-99999"
        return "-∞*"
    end
    if s == "99999.0" || s == "99999"
        return "+∞*"
    end
    # Odstraň .0 suffix
    s = replace(s, r"\.0$" => "")
    return s
end

"""
Generuje vylepšený DOT soubor z parsovaných uzlů.
"""
function generate_enhanced_dot(nodes::Vector{TreeNode}, title::String)
    io = IOBuffer()
    println(io, "digraph SearchTree {")
    println(io, "    rankdir=LR;")
    println(io, "    nodesep=0.2;")
    println(io, "    ranksep=0.5;")
    println(io, "    node [shape=record, fontsize=9, fontname=\"Courier\"];")
    println(io, "    edge [fontsize=8];")
    println(io, "    label=\"$title\";")
    println(io, "    labelloc=t;")
    println(io, "    labelfontsize=12;")
    println(io)

    for node in nodes
        # Barvy
        if node.is_pruned
            fillcolor = "\"#D3D3D3\""  # gray
            fontcolor = "\"#888888\""
        elseif node.role == "MAX"
            fillcolor = "\"#DCEEFB\""  # light blue
            fontcolor = "black"
        else
            fillcolor = "\"#FBDCDC\""  # light red
            fontcolor = "black"
        end

        # Label: move | score | α,β
        move_label = replace(node.move, "\"" => "\\\"")
        score_label = fmt_num(node.score)

        if node.is_pruned
            label = "{ $(move_label) | ✂ OŘEZÁNO }"
        else
            alpha_label = fmt_num(node.alpha)
            beta_label = fmt_num(node.beta)
            # Clarified label: Separate Move from Node Role (State)
            # e.g. "{ 10-6 | MIN | s=... }"
            label = "{ $(move_label) | $(node.role) | s=$(score_label) | α=$(alpha_label) β=$(beta_label) }"
        end

        println(io, "    n$(node.id) [label=\"$label\", style=filled, fillcolor=$fillcolor, fontcolor=$fontcolor];")
    end

    println(io)

    # Mapa pro rychlé vyhledávání dětí v aktuální sadě uzlů
    present_nodes = Dict(n.id => n for n in nodes)

    # Hrany
    for node in nodes
        for child_id in node.children
            if haskey(present_nodes, child_id)
                child = present_nodes[child_id]
                if child.is_pruned
                    println(io, "    n$(node.id) -> n$(child_id) [style=dashed, color=gray];")
                else
                    println(io, "    n$(node.id) -> n$(child_id);")
                end
            end
        end
    end

    println(io, "}")
    return String(take!(io))
end

"""
Hlavní funkce: parsuje textový strom, generuje DOT a renderuje do PDF (celý strom).
"""
function render_tree(run_path::String, subdir::String, title::String, output_path::String;
    max_depth::Int=3)
    txt_file = joinpath(run_path, subdir, "strom_kompletni.txt")
    if !isfile(txt_file)
        @warn "Soubor $txt_file nenalezen"
        return nothing
    end

    nodes = parse_text_tree(txt_file; max_depth=max_depth)

    if isempty(nodes)
        @warn "Žádné uzly naparsovány z $txt_file"
        return nothing
    end

    return render_custom_nodes(nodes, title, output_path)
end

"""
Nová verze renderu: Rozdělí strom na Overview a jednotlivé větve.
Vrací vektor cest k vygenerovaným PDF.
"""
function render_split_tree(run_path::String, subdir::String, title_prefix::String, output_base::String;
    max_depth::Int=3)
    txt_file = joinpath(run_path, subdir, "strom_kompletni.txt")
    if !isfile(txt_file)
        @warn "Soubor $txt_file nenalezen"
        return String[]
    end

    # Načteme s dostatečnou hloubkou pro vytvoření detailních větví
    # Pokud uživatel zadá malé max_depth (např. 3), použijeme to pro overview, 
    # ale pro větve chceme víc (např. 6 nebo 8), pokud to soubor dovolí.
    # Zde loadujeme s větším limitem, filtrování případně uděláme později?
    # Pro jednoduchost načteme s větším limitem (např. 10), overview si poradí (bere jen level 1).
    parsing_depth = max(max_depth, 8)
    all_nodes = parse_text_tree(txt_file; max_depth=parsing_depth)

    if isempty(all_nodes)
        return String[]
    end

    generated_pdfs = String[]
    root_id = 1 # Předpokládáme, že root je první uzel

    # 1. Overview (Root + Level 1)
    overview_nodes = extract_overview(all_nodes, root_id)
    ov_file = render_custom_nodes(overview_nodes, "$title_prefix (Overview)", output_base * "_overview")
    push!(generated_pdfs, ov_file)

    # 2. Větve (Pro každé dítě rootu jeden podstrom)
    root = all_nodes[root_id]

    # Seřadíme děti podle ID pro deterministické pořadí v reportu
    sorted_children = sort(root.children)

    for (i, child_id) in enumerate(sorted_children)
        child = all_nodes[child_id]

        # Extrahuje celý dostupný podstrom (který jsme načetli s parsing_depth)
        branch_nodes = extract_subtree(all_nodes, child_id)

        # Očistíme název tahu pro soubor
        move_slug = replace(child.move, r"[ \-\>]" => "_")
        branch_title = "$title_prefix - Větev: $(child.move)"
        branch_file = render_custom_nodes(branch_nodes, branch_title, output_base * "_branch_$i")
        push!(generated_pdfs, branch_file)
    end

    return generated_pdfs
end

"""
Pomocná funkce pro renderování libovolné sady uzlů.
"""
function render_custom_nodes(nodes::Vector{TreeNode}, title::String, output_path::String)
    dot_content = generate_enhanced_dot(nodes, title)
    dot_file = output_path * ".dot"
    write(dot_file, dot_content)
    pdf_file = output_path * ".pdf"
    run(`dot -Tpdf -o $pdf_file $dot_file`)
    return pdf_file
end

# Export pro použití z QMD
if abspath(PROGRAM_FILE) == @__FILE__
    # CLI mode: render_search_trees.jl <run_path> <subdir> <title> <output_path> [max_depth]
    if length(ARGS) >= 4
        max_d = length(ARGS) >= 5 ? parse(Int, ARGS[5]) : 3
        result = render_tree(ARGS[1], ARGS[2], ARGS[3], ARGS[4]; max_depth=max_d)
        if result !== nothing
            println("✅ Renderováno: $result")
        else
            println("❌ Chyba při renderování")
            exit(1)
        end
    else
        println("Použití: julia render_search_trees.jl <run_path> <subdir> <title> <output_path> [max_depth]")
    end
end
