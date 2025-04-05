# OllamaRepl Testing Plan

## Overview

This document outlines the testing strategy for the OllamaRepl gem. The goal is to implement a comprehensive test suite that ensures the reliability, maintainability, and correctness of the codebase.

## Current Codebase Structure

The OllamaRepl gem consists of several key components:

- `ContextManager`: Manages conversation history between the user and LLM
- `Client`: Handles API communication with Ollama
- `Config`: Manages configuration via environment variables
- `CommandHandler`: Processes user commands
- `Repl`: Main REPL interface that ties everything together

## Testing Strategy

We'll implement a comprehensive test suite using RSpec, covering each component with:

1. **Unit Tests**: Testing individual classes in isolation
2. **Integration Tests**: Testing interactions between components
3. **Mocks/Stubs**: For isolating tests from external dependencies (Ollama API)

## Test Directory Structure

```
spec/
├── spec_helper.rb
├── ollama_repl_spec.rb
└── ollama_repl/
    ├── context_manager_spec.rb
    ├── client_spec.rb
    ├── config_spec.rb
    ├── command_handler_spec.rb
    └── repl_spec.rb
```

## Component-specific Test Coverage

### 1. ContextManager Tests

The most straightforward component to test:

- Test initialization creates empty message store
- Test adding messages of different roles
- Test retrieving all messages
- Test empty? method
- Test size/length methods
- Test clearing messages
- Test for_api method returns correct format

### 2. Config Tests

Testing configuration handling:

- Test default values when environment variables aren't set
- Test reading values from environment variables
- Test validation logic
- Test handling of trailing slashes in host URLs

### 3. Client Tests

Will need mocking for HTTP requests:

- Test initialization with different host/model values
- Test model management methods
- Test chat method with mocked streaming responses
- Test list_models method
- Test error handling
- Test connection validation

### 4. CommandHandler Tests

Testing command processing:

- Test command parsing and routing
- Test each command handler method
- Test error handling
- Test user confirmation flows

### 5. Repl Tests

Most complex component:

- Test initialization and component integration
- Test mode management
- Test input processing for different modes
- Test command delegation
- Mock Readline interaction
- Test output capture mechanisms

## Testing Challenges and Solutions

| Challenge | Approach |
|-----------|----------|
| **Readline Integration** | Mock the Readline module |
| **Ruby Code Execution** | Use safe test code in controlled environments |
| **Shell Command Execution** | Mock Open3 module to avoid actual execution |
| **API Streaming** | Create test helpers to simulate chunked responses |
| **Environment Variables** | Use environment-specific test setup |

## Implementation Phases

### 1. Setup Phase
- Add testing dependencies to gemspec
- Create spec_helper with common configurations
- Set up test environment

### 2. Core Components Phase
- Implement ContextManager tests (simplest)
- Implement Config tests
- Implement Client tests with mocking

### 3. Integration Phase
- Implement CommandHandler tests
- Implement Repl tests
- Create integration tests

### 4. CI/CD Phase
- Set up GitHub Actions workflow
- Configure code coverage reporting

## Setup Requirements

Add the following dependencies to the gemspec:

```ruby
spec.add_development_dependency "rspec", "~> 3.12"
spec.add_development_dependency "rake", "~> 13.0"
spec.add_development_dependency "webmock", "~> 3.18" # For mocking HTTP requests
spec.add_development_dependency "simplecov", "~> 0.22" # For code coverage
```

## Testing Implementation Approach

### RSpec Configuration

Create a `spec_helper.rb` file:

```ruby
require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

require 'ollama_repl'
require 'webmock/rspec'

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
```

### Environment Setup

Create a test environment setup helper:

```ruby
# spec/support/env_helper.rb
module EnvHelper
  def with_env(envs = {})
    original = {}
    envs.each do |key, value|
      original[key] = ENV[key]
      ENV[key] = value
    end
    yield
  ensure
    original.each do |key, value|
      ENV[key] = value
    end
  end
end
```

### Mocking Helpers

Create helpers for mocking:

```ruby
# spec/support/api_mocks.rb
module ApiMocks
  def stub_ollama_model_list(host, models = ["llama3"])
    stub_request(:get, "#{host}/api/tags")
      .to_return(
        status: 200, 
        body: { models: models.map { |m| { name: m } } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
  
  def stub_ollama_chat_streaming(host, model, response_chunks)
    stub_request(:post, "#{host}/api/chat")
      .with(
        body: hash_including(model: model, stream: true)
      )
      .to_return(
        status: 200,
        body: response_chunks.map(&:to_json).join("\n"),
        headers: { 'Content-Type' => 'application/json' }
      )
  end
end
```

## Priority Implementation Order

1. Set up testing infrastructure
2. ContextManager tests (simplest component)
3. Config tests
4. Client tests with mocking
5. CommandHandler tests
6. Repl tests
7. Integration tests

## Continuous Integration

Set up GitHub Actions workflow:

```yaml
# .github/workflows/test.yml
name: Ruby Tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        ruby-version: ['2.7', '3.0', '3.1', '3.2']

    steps:
    - uses: actions/checkout@v3
    - name: Set up Ruby ${{ matrix.ruby-version }}
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: ${{ matrix.ruby-version }}
        bundler-cache: true
    - name: Install dependencies
      run: bundle install
    - name: Run tests
      run: bundle exec rake