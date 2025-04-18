# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands
- Install: `bundle install`
- Run tests: `bundle exec rake spec` or `bundle exec rspec`
- Run single test: `bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER`
- Lint: `bundle exec standardrb`

## Code Style
- Follow Standard Ruby formatting guidelines
- Use frozen_string_literal at top of files
- Class names: PascalCase
- Methods/variables: snake_case
- Constants: SCREAMING_SNAKE_CASE
- Namespacing: OllamaRepl module

## Structure
- Define custom errors as classes extending StandardError
- Use `let`, `context`, and `describe` blocks in RSpec tests
- Order requires: stdlib first, gems second, internal requires last
- Follow single responsibility principle
- Use WebMock for HTTP mocking in tests