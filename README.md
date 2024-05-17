<img src="images/ollama_icon.png" width="256px"/>

# Ollama Alfred Workflow

Dehydrated Ollama Command Line Interface interface to manage local LLMs.  
<a href="https://github.com/zeitlings/alfred-ollama/releases/latest"><img src="https://img.shields.io/badge/download-v1.0.0-informational"></a>


## Usage

Access Ollama with the keyword (default: `ollama`) or define a keyboard shortcut.

<img src="images/preview1.png" width="564px"/>

- <kbd>⌘</kbd><kbd>↩</kbd> to start or quit Ollama .

### Local Models

<img src="images/preview2.png" width="564px"/>

- <kbd>↩</kbd> to open the model page.
- <kbd>⇧</kbd> to quicklook preview the model page.
- <kbd>⌘</kbd><kbd>C</kbd> to copy the model name.
- <kbd>⌘</kbd><kbd>↩</kbd> to remove the model.

### Loaded Models

<img src="images/preview3.png" width="564px"/>

- <kbd>⌘</kbd><kbd>↩</kbd> to unload the model.

### New Models

<img src="images/preview4.png" width="564px"/>

Type to match models based on your query.  
- <kbd>↩</kbd> to open the model page.
- <kbd>⇧</kbd> to quicklook preview the model page.
- <kbd>⌘</kbd><kbd>L</kbd> to view the unabridged model description as large type.
- <kbd>⌘</kbd><kbd>C</kbd> to copy the model name.
- <kbd>⌘</kbd><kbd>↩</kbd> to pull `model:latest` from registry.
- <kbd>⌥</kbd><kbd>↩</kbd> to inspect available versions of the model.

### Model Versions

<img src="images/preview5.png" width="564px"/>

Type to match versions based on your query.  
- <kbd>↩</kbd> to open the model page.
- <kbd>⇧</kbd> to quicklook preview the model page.
- <kbd>⌘</kbd><kbd>C</kbd> to copy the model name.
- <kbd>⌘</kbd><kbd>↩</kbd> to pull `model:version` from registry.

### Pulling Models

<img src="images/preview6.png" width="564px"/>

- <kbd>⌘</kbd><kbd>↩</kbd> to cancel the download.


---

## Dependencies

1. [Ollama macOS app](https://ollama.com/download)
2. Xcode Command Line Tools (recommended)
* `xcode-select --install`

---


__Links:__  
* [ollama.com](https://ollama.com)
* [Ollama Github FAQ](https://github.com/ollama/ollama/blob/main/docs/faq.md)
* [Akazwz's ollama-models](https://github.com/akazwz/ollama-models)
