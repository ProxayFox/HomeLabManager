module HomeLabManager
  module CLI
    private struct ErrorPayload
      getter category : String
      getter command : String?
      getter subcommand : String?
      getter errors : Array(String)

      def initialize(
        @category : String,
        @errors : Array(String),
        @command : String? = nil,
        @subcommand : String? = nil,
      )
      end
    end

    private def json_requested?(args : Array(String)) : Bool
      args.includes?("--json")
    end

    private def print_error(
      stderr : IO,
      errors : Array(String),
      json : Bool,
      category : String,
      command : String? = nil,
      subcommand : String? = nil,
      heading : String? = nil,
    ) : Nil
      if json
        print_error_json(stderr, ErrorPayload.new(category: category, errors: errors, command: command, subcommand: subcommand))
      else
        if heading
          stderr.puts heading
          errors.each do |entry|
            stderr.puts "- #{entry}"
          end
        else
          errors.each do |entry|
            stderr.puts entry
          end
        end
      end
    end

    private def print_error_json(stderr : IO, payload : ErrorPayload) : Nil
      JSON.build(stderr) do |json|
        json.object do
          json.field "type", "error"
          json.field "category", payload.category
          json.field "command", payload.command
          json.field "subcommand", payload.subcommand
          json.field "errors" do
            json.array do
              payload.errors.each do |entry|
                json.string(entry)
              end
            end
          end
        end
      end
      stderr.puts
    end
  end
end
