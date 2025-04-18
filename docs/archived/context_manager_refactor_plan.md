# Refactoring Plan: Extract ContextManager from Repl

This document outlines the plan to extract conversation context management logic from `lib/ollama_repl/repl.rb` into a new `OllamaRepl::ContextManager` class.

**Goal:** Improve separation of concerns by isolating conversation history management into a dedicated class.

**Approach:** Create a new `ContextManager` class that encapsulates the current `@messages` array and provides methods for adding, accessing, and clearing messages.

## Current State

* In `Repl`:
  * `@messages` array is initialized in `initialize`
  * `add_message(role, content)` adds messages to the history
  * Messages are accessed directly by `handle_llm_input` for API calls
  
* In `CommandHandler` (extracted previously):
  * Accesses `@repl.messages` directly for displaying and clearing context

## Planned Changes

1. **Create New File:**
   * Create `lib/ollama_repl/context_manager.rb`.

2. **Define `OllamaRepl::ContextManager` Class:**
   * **`initialize`**: Set up empty messages array.
   * **`add(role, content)`**: Add a new message with the given role and content.
   * **`all`**: Return all messages.
   * **`empty?`**: Check if there are no messages.
   * **`size`/`length`**: Return the number of messages.
   * **`clear`**: Clear all messages.
   * **`for_api`**: Return messages in the format needed for API calls.

3. **Modify `lib/ollama_repl/repl.rb`:**
   * **Require New File:** Add `require_relative 'context_manager'`.
   * **Replace `@messages`:** In `initialize`, use `@context_manager = ContextManager.new`.
   * **Update Access Methods:**
     * Replace direct `@messages` access with `@context_manager` method calls.
     * Replace `add_message` with `@context_manager.add`.
     * In `handle_llm_input`, use `@context_manager.for_api` for API calls.
   * **Expose `context_manager`:** Add `attr_reader :context_manager`.

4. **Modify `lib/ollama_repl/command_handler.rb`:**
   * **Update `initialize`:** Accept `context_manager` instead of relying on `@repl.messages`.
   * **Update `Repl#initialize`:** Pass `@context_manager` to the `CommandHandler` constructor.
   * **Modify Methods:**
     * Update `display_context` to use `@context_manager.all`, `@context_manager.empty?`, etc.
     * Update `clear_context` to use `@context_manager.clear`.
     * Update any other methods that currently access `@repl.messages`.

## Next Steps After Implementation

* Test the REPL to ensure conversation context is correctly maintained.
* Verify all commands that interact with the context (especially `/context` and `/clear`) work correctly.
* Consider future refactoring steps.