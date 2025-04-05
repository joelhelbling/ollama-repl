# frozen_string_literal: true

require_relative "command"
require "pathname"

module OllamaRepl
  module Commands
    class FileCommand < Command
      def initialize(repl, io_service)
        @repl = repl
        @io_service = io_service
      end

      def execute(args, context)
        unless args && !args.empty?
          @io_service.display("Usage: /file {file_path}")
          return
        end

        file_path = File.expand_path(args)
        unless File.exist?(file_path)
          @io_service.display_error("File not found: #{file_path}")
          return
        end

        unless File.readable?(file_path)
          @io_service.display_error("Cannot read file (permission denied): #{file_path}")
          return
        end

        begin
          content = File.read(file_path)
          extension = File.extname(file_path).downcase
          lang = OllamaRepl::Repl::FILE_TYPE_MAP[extension] || "" # Get lang identifier or empty string

          formatted_content = "System Message: File Content (#{File.basename(file_path)})\n"
          formatted_content += "```#{lang}\n"
          formatted_content += content
          formatted_content += "\n```"

          @repl.add_message("system", formatted_content)
          @io_service.display("Added content from #{File.basename(file_path)} to context.")
        rescue => e
          @io_service.display_error("Error reading file #{file_path}: #{e.message}")
        end
      end
    end
  end
end
