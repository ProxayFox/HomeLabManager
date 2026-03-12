module HomeLabManager
  module CLI
    private record CommandOptions,
      path : String,
      selection : HostSelection,
      approve : Bool,
      execute : Bool,
      resume_from : String?,
      json : Bool

    private def parse_command_options(args : Array(String), allow_approve : Bool = false, allow_execute : Bool = false, allow_resume_from : Bool = false, allow_json : Bool = false) : CommandOptions
      path = nil
      tags = [] of String
      groups = [] of String
      approve = false
      execute = false
      resume_from = nil
      json = false
      index = 0

      while index < args.size
        argument = args[index]

        if argument.starts_with?("--")
          index, resume_from, approve, execute, json = handle_command_flag(
            args,
            index,
            tags,
            groups,
            allow_approve,
            allow_execute,
            allow_resume_from,
            allow_json,
            approve,
            execute,
            resume_from,
            json,
          )
        else
          if path
            raise InventoryError.new(["unexpected argument: #{argument}"])
          end

          path = argument
          index += 1
        end
      end

      CommandOptions.new(path || DEFAULT_INVENTORY_PATH, HostSelection.new(tags, groups), approve, execute, resume_from, json)
    end

    private def handle_command_flag(
      args : Array(String),
      index : Int32,
      tags : Array(String),
      groups : Array(String),
      allow_approve : Bool,
      allow_execute : Bool,
      allow_resume_from : Bool,
      allow_json : Bool,
      approve : Bool,
      execute : Bool,
      resume_from : String?,
      json : Bool,
    ) : Tuple(Int32, String?, Bool, Bool, Bool)
      argument = args[index]

      case argument
      when "--tag"
        value = require_option_value(args, index, argument)
        tags << value
        {index + 2, resume_from, approve, execute, json}
      when "--group"
        value = require_option_value(args, index, argument)
        groups << value
        {index + 2, resume_from, approve, execute, json}
      when "--approve"
        raise InventoryError.new(["--approve is not supported for this command"]) unless allow_approve

        {index + 1, resume_from, true, execute, json}
      when "--execute"
        raise InventoryError.new(["--execute is not supported for this command"]) unless allow_execute

        {index + 1, resume_from, approve, true, json}
      when "--resume-from"
        raise InventoryError.new(["--resume-from is not supported for this command"]) unless allow_resume_from

        value = require_option_value(args, index, argument)
        {index + 2, value, approve, execute, json}
      when "--json"
        raise InventoryError.new(["--json is not supported for this command"]) unless allow_json

        {index + 1, resume_from, approve, execute, true}
      else
        raise InventoryError.new(["unknown option: #{argument}"])
      end
    end

    private def require_option_value(args : Array(String), index : Int32, argument : String) : String
      value = args[index + 1]?
      raise InventoryError.new(["missing value for #{argument}"]) unless value

      value
    end

    private def parse_resume_from_option(options : CommandOptions) : UpdateStepKind?
      return nil unless value = options.resume_from

      Updates.parse_resume_from(value)
    end
  end
end
