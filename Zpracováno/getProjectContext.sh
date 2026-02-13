#!/bin/bash

# Adresáře
BASE_DIR="/home/sim/Obsi/Prods/04-škola/Předměty/mgr3/4IZ431..AI1/Zpracováno"
OUT_DIR="/home/sim/Documents/ai1"
mkdir -p "$OUT_DIR"

# 1. Funkce pro výpočet unikátního ID stavu (commit + diff hash)
get_state_id() {
    local proj_path="$1"
    local target_commit="$2"
    
    pushd "$proj_path" > /dev/null || return 1
    
    local state_id
    if [ -n "$target_commit" ]; then
        # Pro konkrétní commit stačí jeho short hash
        state_id=$(git rev-parse --short "$target_commit")
    else
        # Pro aktuální stav: HEAD commit + hash všech lokálních změn (vč. nových souborů)
        local head=$(git rev-parse --short HEAD 2>/dev/null || echo "no-commit")
        local diff_hash=$( (git diff HEAD; git status --porcelain) 2>/dev/null | sha256sum | cut -c1-8)
        state_id="${head}_${diff_hash}"
    fi
    
    popd > /dev/null
    echo "$state_id"
}

# 2. Funkce pro určení další generace (001, 002...)
get_next_batch() {
    local last=$(ls "$OUT_DIR" 2>/dev/null | grep -E '^[0-9]{3}_' | sort | tail -n 1 | cut -c1-3)
    if [ -z "$last" ]; then
        echo "001"
    else
        local next=$((10#$last + 1))
        printf "%03d" "$next"
    fi
}

# 3. Definice projektů k monitorování
# path | prefix | commit
items=(
    "$BASE_DIR/ang-dama-tros01|dama-mix|"
    "$BASE_DIR/ang-dama-tros01|dama-mix_commit_ab1bbbf|ab1bbbf420c28be5402cda64813dc95c1e37e8e4"
    "$BASE_DIR/Pacman-multiagent-tros01|pacman-mix|"
)

pending_items=()
pending_states=()

# Analýza, co je potřeba vygenerovat
for item in "${items[@]}"; do
    path=$(echo "$item" | cut -d'|' -f1)
    prefix=$(echo "$item" | cut -d'|' -f2)
    commit=$(echo "$item" | cut -d'|' -f3)
    
    state=$(get_state_id "$path" "$commit")
    
    # Pokud už soubor s tímto ID existuje (v jakékoliv generaci), ignorujeme
    if ls "$OUT_DIR"/*"_${prefix}_${state}.md" >/dev/null 2>&1; then
        echo ">>> Beze změny: $prefix ($state)"
    else
        pending_items+=("$item")
        pending_states+=("$state")
    fi
done

# Pokud se nic nezměnilo, končíme
if [ ${#pending_items[@]} -eq 0 ]; then
    echo ">>> Vše aktuální. Žádné soubory nebyly vytvořeny."
    exit 0
fi

# Máme změny -> určíme číslo generace pro tento "set"
batch=$(get_next_batch)
echo ">>> Zjištěny změny! Vytvářím generaci $batch..."

for i in "${!pending_items[@]}"; do
    item="${pending_items[$i]}"
    state="${pending_states[$i]}"
    
    path=$(echo "$item" | cut -d'|' -f1)
    prefix=$(echo "$item" | cut -d'|' -f2)
    commit=$(echo "$item" | cut -d'|' -f3)
    
    out_file="$OUT_DIR/${batch}_${prefix}_${state}.md"
    
    echo ">>> Generuji: $out_file"
    
    if [ -n "$commit" ]; then
        tmp=$(mktemp -d)
        (cd "$path" && git archive "$commit" | tar -x -C "$tmp")
        (cd "$tmp" && repomix --style markdown --output-show-line-numbers --parsable-style -o "$out_file")
        rm -rf "$tmp"
    else
        (cd "$path" && repomix --style markdown --output-show-line-numbers --parsable-style -o "$out_file")
    fi
done

echo ">>> Hotovo. Všechny nové soubory mají společný prefix $batch."
