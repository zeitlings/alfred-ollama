#!/bin/zsh --no-rcs 

installed_models=""
loaded_models=""
model_json="${alfred_workflow_cache}/models.json"
now_running=false

[[ -z $(lsof -nP -i4TCP:${port}) ]] || now_running=true
[[ -d ${alfred_workflow_cache} ]] || /bin/mkdir "${alfred_workflow_cache}"
[[ -f ${model_json} ]] || curl -s https://ollama-models.zwz.workers.dev/ > "$model_json"

# E.g., 2024-05-14 15:54:36 +0000
modified_date=$(mdls -name kMDItemContentModificationDate -raw "$model_json") 
modified_seconds=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$modified_date" "+%s")
current_seconds=$(date "+%s")
one_day_in_seconds=$((60 * 60 * 24))

if [ $((current_seconds - modified_seconds)) -gt $one_day_in_seconds ]; then
    # The file is older than one day and considered stale. 
    # Replace the file containing the models with an updated version.
    # Until there is an official list, we get the them
    # courtesy of <https://github.com/akazwz/ollama-models>.
    curl -s https://ollama-models.zwz.workers.dev/ > "$model_json"
fi

if $now_running; then 
    installed_models="$(ollama list)"
    loaded_models="$(ollama ps)"
fi

if [[ "$(which swiftc)" =~ "not" ]]; then
    swift -enable-bare-slash-regex ./ollama.swift "$1" "$model_json" $now_running "$installed_models" "$loaded_models" # crawl
else
    [[ -f ./Ollama ]] || $(swiftc -O -enable-bare-slash-regex ./Ollama.swift) # compile
    ./Ollama "$1" "$model_json" $now_running "$installed_models" "$loaded_models"
fi
