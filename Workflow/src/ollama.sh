#!/bin/zsh --no-rcs

installed_models=""
loaded_models=""
ollama_version=""
model_json="${alfred_workflow_cache}/models.json"
is_ollama_running=false

update_models() {
    if ! curl -s https://ollama-models.zwz.workers.dev/ >"$model_json"; then
        echo "Error downloading models" >&2
        exit 1
    fi
}

[[ -z $(lsof -nP -i4TCP:${workflow_port}) ]] || is_ollama_running=true
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

xattr -d com.apple.quarantine ./src/Ollama >/dev/null 2>&1
./src/Ollama "${args[@]}"
#"${HOME}${DEV}" "${args[@]}"
