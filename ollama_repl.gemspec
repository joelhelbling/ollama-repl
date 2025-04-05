require_relative "lib/ollama_repl/version"

Gem::Specification.new do |spec|
  spec.name          = "ollama_repl"
  spec.version       = OllamaRepl::VERSION
  spec.authors       = ["Joel Helbling"] # Placeholder
  spec.email         = ["joel@joelhelbling.com"] # Placeholder

  spec.summary       = "A terminal REPL chat interface for Ollama."
  spec.description   = "Provides a Read-Eval-Print Loop (REPL) in the terminal to interact with an Ollama API, maintaining conversation history and allowing execution of local Ruby code."
  spec.homepage      = "https://github.com/yourusername/ollama_repl" # Placeholder
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'" # Placeholder

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here." # Placeholder

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Executable file
  spec.executables << 'ollama-repl'

  # Runtime dependencies
  spec.add_dependency "dotenv", "~> 2.8"
  spec.add_dependency "faraday", "~> 2.7"
  spec.add_dependency "faraday-net_http", "~> 3.0" # Explicit adapter
  spec.add_dependency "readline", "~> 0"          # Included with Ruby, but good practice

  # Development dependencies
  spec.add_development_dependency "bundler", "~> 2.3"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "webmock", "~> 3.18" # For mocking HTTP requests
  spec.add_development_dependency "simplecov", "~> 0.22" # For code coverage
end

