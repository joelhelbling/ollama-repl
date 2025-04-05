require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

require 'ollama_repl'
require 'webmock/rspec'

# Load support files
Dir[File.join(File.dirname(__FILE__), 'support', '**', '*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  
  # Include helper modules
  config.include EnvHelper
  config.include ApiMocks
end