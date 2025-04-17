#!/bin/zsh --no-rcs

SCHEME="${workflow_scheme:-http}"
HOST="${workflow_host:-localhost}"
PORT="${workflow_port:-11434}"

model_json="${alfred_workflow_cache:-/tmp/alfred_ollama}/models.json"
installed_models=""
loaded_models=""
ollama_version=""
is_ollama_running=false

update_models() {
    if ! curl -s https://ollama-models.zwz.workers.dev/ >"$model_json"; then
        echo "Error downloading models" >&2
        exit 1
    fi
}

poke_ollama() {
    curl -s "$SCHEME://${HOST}:${PORT}/api/version" >/dev/null 2>&1
    echo $?
}

[[ $(poke_ollama) -eq 0 ]] && is_ollama_running=true
[[ -d ${alfred_workflow_cache} ]] || /bin/mkdir -p "${alfred_workflow_cache}"
[[ -f ${model_json} ]] || update_models

# E.g., 2024-05-14 15:54:36 +0000
readonly modified_date=$(mdls -name kMDItemContentModificationDate -raw "$model_json")
readonly modified_seconds=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$modified_date" "+%s")
readonly current_seconds=$(date "+%s")
readonly one_day_in_seconds=$((60 * 60 * 24))

if [ $((current_seconds - modified_seconds)) -gt $one_day_in_seconds ]; then
    # The file is older than one day and considered stale.
    # Replace the file containing the models with an updated version.
    # Until there is an official list, we get the them
    # courtesy of <https://github.com/akazwz/ollama-models>.
    update_models
fi

if $is_ollama_running; then
    installed_models="$(ollama list)"
    loaded_models="$(ollama ps)"
    ollama_version="$(ollama -v)"
fi

readonly args=("$1" "$model_json" $is_ollama_running "$installed_models" "$loaded_models" "$ollama_version")

if [[ -f "${HOME}${DEV}" ]]; then
    "${HOME}${DEV}" "${args[@]}"
else
    # Feel free to build the binary from source.
    # See <https://github.com/zeitlings/alfred-ollama>
    xattr -d com.apple.quarantine ./src/AlfredOllama >/dev/null 2>&1
    ./src/AlfredOllama "${args[@]}"
fi
