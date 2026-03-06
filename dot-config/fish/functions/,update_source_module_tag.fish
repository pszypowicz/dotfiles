function ,update_source_module_tag --description "Bulk-update source_module_tag in platform_variables.json across layers and batch git-add"
    # ── argument parsing ──────────────────────────────────────────────
    argparse \
        p/prod \
        'f/from=' \
        't/to=' \
        'n/batch=' \
        'x/exclude=+' \
        'l/layer=' \
        d/dry-run \
        h/help \
        -- $argv
    or return 1

    # ── help ──────────────────────────────────────────────────────────
    if set -q _flag_help
        echo "Usage: ,update_source_module_tag -t <new_tag> [OPTIONS]"
        echo ""
        echo "Replaces \"source_module_tag\" values in platform_variables.json"
        echo "files for the specified layer."
        echo ""
        echo "Options:"
        echo "  -t, --to       TAG   New source_module_tag value (required, e.g. v22.7.0)"
        echo "  -f, --from     TAG   Current tag to match (default: .* i.e. any version)"
        echo "  -l, --layer    LVL   Layer to target: L1, L2, L3, L4 (default: L3)"
        echo "                       L1 → L1-Projects/*/"
        echo "                       L2 → L2-*/*/{env}/cluster/"
        echo "                       L3 → L2-*/*/{env}/L3/*/"
        echo "                       L4 → L2-*/*/{env}/L4/*/* + L4-standalone/*/*/"
        echo "  -p, --prod           Target prod environments (default: nonprod)"
        echo "                       (ignored for L1)"
        echo "  -n, --batch    N     Number of modified files to git-add (default: 50)"
        echo "  -x, --exclude  PAT   Glob pattern(s) to skip (repeatable, case-insensitive)"
        echo "                       e.g. -x 'l2-shared/s42ng/nonprod2/*' -x 'l2-*/foo/*'"
        echo "  -d, --dry-run        Show what would be changed without modifying files"
        echo "  -h, --help           Show this help message"
        return 0
    end

    # ── validate required args ────────────────────────────────────────
    if not set -q _flag_to
        echo "error: --to (-t) is required (the new source_module_tag value)"
        return 1
    end
    set -l new_tag $_flag_to

    # ── defaults ──────────────────────────────────────────────────────
    # --from: regex to match in the current value; default = any (.*)
    set -l from_pattern '.*'
    if set -q _flag_from
        # Escape dots in an explicit version so they match literally
        set from_pattern (string replace -a '.' '\\.' -- $_flag_from)
    end

    # --batch: how many modified files to git-add (default 50)
    set -l batch_size 50
    if set -q _flag_batch
        set batch_size $_flag_batch
    end

    # --prod / nonprod
    set -l env_glob 'nonprod[0-9]'
    set -l env_label nonprod
    if set -q _flag_prod
        set env_glob 'prod[0-9]'
        set env_label prod
    end

    # --layer: which layer to target (default L3)
    set -l layer L3
    if set -q _flag_layer
        set layer (string upper -- $_flag_layer)
    end
    if not contains -- $layer L1 L2 L3 L4
        echo "error: invalid layer '$layer' (must be L1, L2, L3, or L4)"
        return 1
    end

    # ── build the sed pattern ─────────────────────────────────────────
    set -l sed_pattern "s|\"source_module_tag\": \"$from_pattern\"|\"source_module_tag\": \"$new_tag\"|"

    # ── find target files (based on layer) ─────────────────────────────
    set -l files
    set -l search_desc
    switch $layer
        case L1
            set files (find L1-Projects -name platform_variables.json 2>/dev/null)
            set search_desc "L1-Projects/*/platform_variables.json"
        case L2
            set files (find L2-* -path "*/$env_glob/cluster/platform_variables.json" 2>/dev/null)
            set search_desc "L2-*/*/$env_glob/cluster/platform_variables.json"
        case L3
            set files (find L2-* -path "*/$env_glob/L3/*/platform_variables.json" 2>/dev/null)
            set search_desc "L2-*/*/$env_glob/L3/*/platform_variables.json"
        case L4
            set files (find L2-* -path "*/$env_glob/L4/*/*/platform_variables.json" 2>/dev/null)
            set -a files (find L4-standalone -name platform_variables.json 2>/dev/null)
            set search_desc "L2-*/*/$env_glob/L4/*/*/ + L4-standalone/*/*/"
    end

    if test (count $files) -eq 0
        echo "No files matched pattern $search_desc"
        return 1
    end

    # ── collect matching files (capped at batch_size) ─────────────────
    # Skip files that already have the destination tag — nothing to do.
    set -l matching
    set -l total_matching 0
    set -l already_at_target 0
    set -l excluded_count 0
    for f in $files
        # ── check exclude patterns ───────────────────────────────────
        if set -q _flag_exclude
            set -l _skip false
            for pat in $_flag_exclude
                if string match -i -q -- "$pat" "$f"
                    set _skip true
                    break
                end
            end
            if test $_skip = true
                set excluded_count (math $excluded_count + 1)
                continue
            end
        end
        if grep -qE "\"source_module_tag\": \"$from_pattern\"" "$f"
            # Already at the target value — skip
            if grep -qF "\"source_module_tag\": \"$new_tag\"" "$f"
                set already_at_target (math $already_at_target + 1)
                continue
            end
            set total_matching (math $total_matching + 1)
            if test (count $matching) -lt $batch_size
                set -a matching $f
            end
        end
    end

    echo "Layer       : $layer"
    echo "Environment : $env_label"
    echo "From pattern: \"source_module_tag\": \"$from_pattern\""
    echo "To value    : \"source_module_tag\": \"$new_tag\""
    echo "Files found : "(count $files)
    echo "Excluded    : $excluded_count"
    echo "Already done: $already_at_target (skipped)"
    echo "Matching    : $total_matching"
    echo "Batch size  : $batch_size (processing "(count $matching)" file(s))"
    echo ""

    if test $total_matching -eq 0
        echo "No files contain a matching source_module_tag."
        return 0
    end

    # ── dry-run: just show what would be modified ─────────────────────
    if set -q _flag_dry_run
        echo "── dry-run: files that would be modified ──"
        for f in $matching
            echo "  $f"
        end
        if test $total_matching -gt $batch_size
            echo ""
            echo "(batch_size is $batch_size — re-run to process the remaining "(math $total_matching - $batch_size)" file(s))"
        end
        return 0
    end

    # ── perform substitution (only on batched files) ──────────────────
    for f in $matching
        sed -i '' -E "$sed_pattern" "$f"
    end

    echo "Files modified: "(count $matching)
    if test $total_matching -gt $batch_size
        echo "Remaining   : "(math $total_matching - $batch_size)" file(s) skipped (re-run to continue)"
    end

    # ── git-add the modified files ────────────────────────────────────
    git add $matching
    echo "Staged "(count $matching)" file(s) for commit."
end
