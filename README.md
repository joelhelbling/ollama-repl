# OllamaRepl

A unique terminal-based REPL for interacting with Ollama language models --and Ruby-- without a browser!

## 🌟 Overview

OllamaRepl provides a seamless terminal interface for working with Ollama-hosted language models. What makes it special is the integration of three powerful modes - LLM chat, Ruby execution, and Shell commands - all while maintaining a unified conversation context. This creates a truly integrated development experience where you can discuss code with an LLM, implement it in Ruby, and test it with shell commands - all without leaving your terminal or losing conversation context!

## ✨ Key Features

- **Browser-free LLM interaction** - Chat with language models directly in your terminal
- **Three integrated modes with persistent context**:
  - 🤖 **LLM mode** - Chat with Ollama-hosted language models
  - 💎 **Ruby mode** - Execute Ruby code with results captured in conversation context
  - 🐚 **Shell mode** - Run shell commands with output added to conversation context
- **File content integration** - Add any file's contents to your conversation context, making it perfect for getting help with existing code
- **Model switching** - Easily swap between different Ollama models without restarting
- **Rich error handling** - Clear feedback for API and execution errors

## 📋 Prerequisites

- Ruby 2.7 or higher
- [Ollama](https://ollama.ai/) running with at least one model pulled
- Basic familiarity with terminal/command line

## 🚀 Installation

### From RubyGems

```bash
gem install ollama_repl
```

### From Source

```bash
git clone https://github.com/yourusername/ollama_repl.git
cd ollama_repl
bundle install
rake install
```

## ⚙️ Configuration

OllamaRepl uses environment variables for configuration, which can be set in a `.env` file:

1. Create a `.env` file in your project directory:

```bash
cp .env.example .env
```

2. Edit the `.env` file:

```
OLLAMA_HOST=http://localhost:11434
OLLAMA_MODEL=gemma3:27b  # Replace with your preferred model
```

### Required environment variables:

- `OLLAMA_HOST`: URL of your Ollama API (default: `http://localhost:11434`)
- `OLLAMA_MODEL`: Default model to use (required)

### Optional variables:

- `DEBUG`: Set to `true` to enable debug logging

## 🎮 Usage

Start the REPL by running:

```bash
ollama-repl
```

### Working with Modes

OllamaRepl starts in LLM mode. You can switch between modes or perform one-off actions:

#### Switching modes:
- `/llm` - Switch to LLM chat mode
- `/ruby` - Switch to Ruby execution mode  
- `/shell` - Switch to Shell execution mode

#### One-off actions (without changing your current mode):
- `/llm {prompt}` - Send a single prompt to the LLM
- `/ruby {code}` - Execute a single Ruby snippet
- `/shell {command}` - Execute a single shell command

### Example Workflow

Here's how you can use the integrated modes for a seamless development experience:

1. **Chat with the LLM about a coding problem**:
   ```
   🤖 ❯ How do I implement a binary search in Ruby?
   ```

2. **Implement the suggested code in Ruby mode**:
   ```
   🤖 ❯ /ruby
   
   Switched to Ruby mode.
   
   💎 ❯ def binary_search(array, target)
     low = 0
     high = array.length - 1
     
     while low <= high
       mid = (low + high) / 2
       return mid if array[mid] == target
       
       if array[mid] < target
         low = mid + 1
       else
         high = mid - 1
       end
     end
     
     return nil
   end
   
   sorted_array = [1, 3, 5, 7, 9, 11, 13, 15]
   puts binary_search(sorted_array, 7)
   ```

3. **Save the implementation to a file and include it in your context**:
   ```
   💎 ❯ /shell
   
   Switched to Shell mode.
   
   🐚 ❯ echo 'def binary_search(array, target)
     low = 0
     high = array.length - 1
     
     while low <= high
       mid = (low + high) / 2
       return mid if array[mid] == target
       
       if array[mid] < target
         low = mid + 1
       else
         high = mid - 1
       end
     end
     
     return nil
   end' > binary_search.rb
   
   🐚 ❯ /file binary_search.rb
   ```

4. **Return to LLM mode for further discussion**:
   ```
   🐚 ❯ /llm
   
   Switched to LLM mode.
   
   🤖 ❯ How can I make this binary search implementation more efficient?
   ```

## 📖 Available Commands

| Command | Description |
|---------|-------------|
| `/llm` | Switch to LLM interaction mode |
| `/ruby` | Switch to Ruby execution mode |
| `/shell` | Switch to Shell execution mode |
| `/llm {prompt}` | Execute a one-off LLM prompt |
| `/ruby {code}` | Execute a one-off Ruby code snippet |
| `/shell {command}` | Execute a one-off shell command |
| `/file {path}` | Add file content to the conversation context |
| `/model` | List available Ollama models |
| `/model {name}` | Switch to the specified Ollama model |
| `/context` | Display the current conversation context |
| `/clear` | Clear the conversation context |
| `/help` | Show the help message |
| `/exit`, `/quit` | Exit the REPL |

## 🗺️ Roadmap

This thing is _arguably useful as entertainment_, but really not ready for prime time yet.  Here are some things that need to be done:

### short term goals
- Run subsequent ruby commands in the same process (e.g. the way `irb` or `pry` do).  Currently each `/ruby` snippet runs in a new process with no knowledge of entities created in prior snippets.
- List loaded files in a status above each input prompt so you know what you're dealing with.  Those files are in the LLM context, sure, but users need context too.
- While we're at it, how about displaying the number of tokens in the context (chat history)?
- format the LLM's markdown in something nice for a terminal.  Too many asterisks just isn't a great experience
- format Ruby code to look good.  C'mon, we've had this since we stopped coding in notepad.exe!
- choose a better name.  I'm not gonna say this name was _vibe coded_, but, ok, yeah, it an AI made up this name.  Finally, we found one thing they're not good at.

### longer term goals
- Better context management.  It's all about the tokens, y'all.  Too many of 'em flying around.  Currently the `ContextManager` is _really_ simplistic (it just endlessly appends each message, no summarizing or editing), but, hey, it's an empty vessel, ready to be inhabited by something smarter.
- Better prompting!  As in, like, _any_ prompting!  Currently it's 100% BYO prompt, with no pre-prompt to shape and direct this unique experience.  Getting this right will pretty much make or break this thing.
- MCP all the things!  Because it would be cool, and also, it's currently the right thing to do.  Should be pluggable somehow, so that we'll never really be able to know all the amazing stuff folks are doing with this thing.

I know what you're wondering.  _"What about Deepseek/Claude/Gemini/Sam Altman?"_  Well, no.  If we make this work with awesome AIs, will we ever bother to make it work great with Ollama models?  It's bad enough burning through API $$$ just to _make_ this thing.  Opensource is the future.  C'mon, you feel it too, don't you?

## 🛠️ Contributing

If you're still reading, then I'm getting excited because...Contributions are welcome! Here's how you can help improve OllamaRepl:

### Development Setup

1. Fork and clone the repository:
   ```bash
   git clone https://github.com/yourusername/ollama_repl.git
   cd ollama_repl
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

3. Run the tests:
   ```bash
   bundle exec rspec
   ```

### Development Workflow

1. Create a feature branch:
   ```bash
   git checkout -b feature/amazing-feature
   ```

2. Make your changes and add tests for new functionality

3. Ensure all tests pass:
   ```bash
   bundle exec rspec
   ```

4. Submit a pull request with a clear description of the changes

## 📄 License

This project is licensed under the MIT License.