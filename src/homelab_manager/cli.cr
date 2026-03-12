module HomeLabManager
  module CLI
    extend self

    DEFAULT_INVENTORY_PATH          = "config/inventory.yml"
    DEFAULT_CONNECT_TIMEOUT_SECONDS = Transport::DEFAULT_CONNECT_TIMEOUT_SECONDS
    DEFAULT_UPDATE_STATE_PATH       = Updates::DEFAULT_STATE_PATH

    private record CommandOptions,
      path : String,
      selection : HostSelection,
      approve : Bool,
      execute : Bool,
      resume_from : String?,
      json : Bool

    def run(
      args : Array(String),
      stdout : IO = STDOUT,
      stderr : IO = STDERR,
      transport : Transport = SshTransport.new,
      audit_logger : Audit::Logger = Audit::FileLogger.new,
      state_store : Updates::StateStore = Updates::StateStore.new,
    ) : Int32
      return print_help(stdout) if args.empty?

      json = json_requested?(args)

      case args[0]
      when "help", "--help", "-h"
        print_help(stdout)
      when "inventory"
        run_inventory(args[1..], stdout, stderr)
      when "hosts"
        run_hosts(args[1..], stdout, stderr, transport)
      when "updates"
        run_updates(args[1..], stdout, stderr, transport, audit_logger, state_store)
      else
        print_error(stderr, ["unknown command: #{args[0]}"], json, "usage")
        return 1 if json

        stderr.puts
        print_help(stderr, 1)
      end
    end

    private def print_help(io : IO, exit_code : Int32 = 0) : Int32
      io.puts "HomeLabManager"
      io.puts
      io.puts "Usage:"
      io.puts "  homelab_manager inventory validate [inventory.yml]"
      io.puts "  homelab_manager inventory list [inventory.yml] [--tag TAG] [--group GROUP] [--json]"
      io.puts "  homelab_manager hosts check [inventory.yml] [--tag TAG] [--group GROUP] [--json]"
      io.puts "  homelab_manager updates plan [inventory.yml] [--tag TAG] [--group GROUP] [--approve] [--json]"
      io.puts "  homelab_manager updates dry-run [inventory.yml] [--tag TAG] [--group GROUP] [--approve]"
      io.puts "  homelab_manager updates run [inventory.yml] [--tag TAG] [--group GROUP] [--approve] [--resume-from ACTION] --execute"
      io.puts
      io.puts "Commands:"
      io.puts "  inventory validate   Validate the inventory file before any remote action"
      io.puts "                       Defaults to #{DEFAULT_INVENTORY_PATH} and supports optional --json"
      io.puts "  inventory list       List the hosts defined in the inventory file"
      io.puts "                       Defaults to #{DEFAULT_INVENTORY_PATH}"
      io.puts "                       Supports repeated --tag and --group filters plus optional --json"
      io.puts "  hosts check          Probe SSH connectivity for each host"
      io.puts "                       Defaults to #{DEFAULT_INVENTORY_PATH}"
      io.puts "                       Supports repeated --tag and --group filters plus optional --json"
      io.puts "  updates plan         Build a dry-run-first update plan without executing it"
      io.puts "                       Supports repeated --tag and --group filters, optional --approve, and optional --json"
      io.puts "  updates dry-run      Execute only non-mutating update steps and write audit logs"
      io.puts "                       Supports repeated --tag and --group filters, optional --approve, and optional --json"
      io.puts "  updates run          Execute the full update workflow, including approved mutating steps"
      io.puts "                       Requires --execute and supports repeated --tag/--group filters, optional --approve, --resume-from ACTION, and --json"
      io.puts "                       Uses persisted recovery state from #{DEFAULT_UPDATE_STATE_PATH} when --resume-from is not provided"
      exit_code
    end

    private def run_inventory(args : Array(String), stdout : IO, stderr : IO) : Int32
      subcommand = args[0]?
      json = json_requested?(args)

      unless subcommand
        print_error(stderr, ["missing inventory subcommand", "expected one of: validate, list"], json, "usage", command: "inventory")
        return 1
      end

      options = parse_command_options(args[1..], allow_json: true)
      inventory = Inventory.load(options.path)

      case subcommand
      when "validate"
        if options.json
          print_inventory_validation_json(options.path, inventory, stdout)
        else
          stdout.puts "Inventory valid: #{inventory.hosts.size} host(s) loaded from #{options.path}"
        end
        0
      when "list"
        hosts = Inventory.select_hosts(inventory, options.selection)
        return print_empty_selection(stderr, options.selection, options.json, "inventory", subcommand) if hosts.empty?

        if options.json
          print_inventory_list_json(options.path, inventory, hosts, options.selection, stdout)
        else
          print_inventory_list(inventory, hosts, stdout)
        end
        0
      else
        print_error(stderr, ["unknown inventory subcommand: #{subcommand}", "expected one of: validate, list"], options.json, "usage", command: "inventory", subcommand: subcommand)
        1
      end
    rescue ex : InventoryError
      print_inventory_errors(stderr, ex, json_requested?(args), command: "inventory", subcommand: subcommand)
      1
    end

    private def run_hosts(args : Array(String), stdout : IO, stderr : IO, transport : Transport) : Int32
      subcommand = args[0]?
      json = json_requested?(args)

      unless subcommand
        print_error(stderr, ["missing hosts subcommand", "expected: check"], json, "usage", command: "hosts")
        return 1
      end

      options = parse_command_options(args[1..], allow_json: true)

      case subcommand
      when "check"
        inventory = Inventory.load(options.path)
        hosts = Inventory.select_hosts(inventory, options.selection)
        return print_empty_selection(stderr, options.selection, options.json, "hosts", subcommand) if hosts.empty?

        results = Connectivity.check(InventoryFile.new(inventory.defaults, hosts), transport, DEFAULT_CONNECT_TIMEOUT_SECONDS)
        if options.json
          print_host_check_results_json(options.path, results, options.selection, stdout)
        else
          print_host_check_results(results, stdout)
        end
        Connectivity.succeeded?(results) ? 0 : 1
      else
        print_error(stderr, ["unknown hosts subcommand: #{subcommand}", "expected: check"], options.json, "usage", command: "hosts", subcommand: subcommand)
        1
      end
    rescue ex : InventoryError
      print_inventory_errors(stderr, ex, json_requested?(args), command: "hosts", subcommand: subcommand)
      1
    end

    private def run_updates(args : Array(String), stdout : IO, stderr : IO, transport : Transport, audit_logger : Audit::Logger, state_store : Updates::StateStore) : Int32
      subcommand = args[0]?
      json = json_requested?(args)

      unless subcommand
        print_error(stderr, ["missing updates subcommand", "expected: plan, dry-run, run"], json, "usage", command: "updates")
        return 1
      end

      options = parse_command_options(args[1..], allow_approve: true, allow_execute: true, allow_resume_from: true, allow_json: true)
      handle_updates_subcommand(subcommand, options, stdout, stderr, transport, audit_logger, state_store)
    rescue ex : InventoryError
      print_inventory_errors(stderr, ex, json_requested?(args), command: "updates", subcommand: subcommand)
      1
    end

    private def handle_updates_subcommand(
      subcommand : String,
      options : CommandOptions,
      stdout : IO,
      stderr : IO,
      transport : Transport,
      audit_logger : Audit::Logger,
      state_store : Updates::StateStore,
    ) : Int32
      case subcommand
      when "plan"
        run_updates_plan(options, stdout, stderr, state_store)
      when "dry-run"
        run_updates_dry_run(options, stdout, stderr, transport, audit_logger, state_store)
      when "run"
        run_updates_execute(options, stdout, stderr, transport, audit_logger, state_store)
      else
        print_error(stderr, ["unknown updates subcommand: #{subcommand}", "expected: plan, dry-run, run"], options.json, "usage", command: "updates", subcommand: subcommand)
        1
      end
    end

    private def load_selected_hosts(options : CommandOptions, stderr : IO) : Tuple(InventoryFile, Array(Host))?
      inventory = Inventory.load(options.path)
      hosts = Inventory.select_hosts(inventory, options.selection)
      return nil if hosts.empty? && print_empty_selection(stderr, options.selection, options.json, "updates") == 1

      {inventory, hosts}
    end

    private def run_updates_plan(options : CommandOptions, stdout : IO, stderr : IO, state_store : Updates::StateStore) : Int32
      loaded = load_selected_hosts(options, stderr)
      return 1 unless loaded

      inventory, hosts = loaded
      recovery_entries = persisted_recovery_entries(options, hosts, state_store)
      plans = resolve_update_plans(options, inventory, hosts, state_store)
      if options.json
        print_update_plans_json(plans, stdout, recovery_entries)
      else
        print_update_plans(plans, stdout)
      end
      0
    end

    private def run_updates_dry_run(options : CommandOptions, stdout : IO, stderr : IO, transport : Transport, audit_logger : Audit::Logger, state_store : Updates::StateStore) : Int32
      loaded = load_selected_hosts(options, stderr)
      return 1 unless loaded

      inventory, hosts = loaded
      recovery_entries = persisted_recovery_entries(options, hosts, state_store)
      plans = resolve_update_plans(options, inventory, hosts, state_store)
      runs = Updates.dry_run(plans, transport, audit_logger)
      if options.json
        print_update_runs_json("dry-run", runs, stdout, recovery_entries)
      else
        print_update_runs("Update dry-run", runs, stdout)
      end
      stdout.puts "Audit log: #{Audit::DEFAULT_LOG_PATH}" if audit_logger.is_a?(Audit::FileLogger)
      Updates.successful?(runs) ? 0 : 1
    end

    private def run_updates_execute(options : CommandOptions, stdout : IO, stderr : IO, transport : Transport, audit_logger : Audit::Logger, state_store : Updates::StateStore) : Int32
      unless options.execute
        print_error(
          stderr,
          [
            "Refusing to run mutating updates without --execute",
            "Use updates plan or updates dry-run first, then rerun with --execute when ready",
          ],
          options.json,
          "execution-guard",
          command: "updates",
          subcommand: "run",
        )
        return 1
      end

      loaded = load_selected_hosts(options, stderr)
      return 1 unless loaded

      inventory, hosts = loaded
      recovery_entries = persisted_recovery_entries(options, hosts, state_store)
      plans = resolve_update_plans(options, inventory, hosts, state_store)
      runs = Updates.execute(plans, transport, audit_logger)
      if options.json
        print_update_runs_json("run", runs, stdout, recovery_entries)
      else
        print_update_runs("Update run", runs, stdout)
      end
      state_store.record_runs(runs)
      stdout.puts "Audit log: #{Audit::DEFAULT_LOG_PATH}" if audit_logger.is_a?(Audit::FileLogger)
      Updates.successful?(runs) ? 0 : 1
    end

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

    private def resolve_update_plans(
      options : CommandOptions,
      inventory : InventoryFile,
      hosts : Array(Host),
      state_store : Updates::StateStore,
    ) : Array(UpdatePlan)
      if resume_from = parse_resume_from_option(options)
        Updates.build_plans(inventory, hosts, options.approve, resume_from)
      else
        Updates.build_plans(inventory, hosts, options.approve, resume_points: state_store.resume_points(hosts))
      end
    end

    private def persisted_recovery_entries(
      options : CommandOptions,
      hosts : Array(Host),
      state_store : Updates::StateStore,
    ) : Hash(String, Updates::RecoveryStateEntry)
      return {} of String => Updates::RecoveryStateEntry if options.resume_from

      state_store.recovery_entries(hosts)
    end

    private def print_empty_selection(stderr : IO, selection : HostSelection, json : Bool = false, command : String? = nil, subcommand : String? = nil) : Int32
      errors = ["no hosts matched the requested filters"] of String
      errors << "tags: #{selection.tags.join(",")}" unless selection.tags.empty?
      errors << "groups: #{selection.groups.join(",")}" unless selection.groups.empty?
      print_error(stderr, errors, json, "selection", command: command, subcommand: subcommand)
      1
    end

    private def print_inventory_errors(stderr : IO, error : InventoryError, json : Bool = false, command : String? = nil, subcommand : String? = nil) : Nil
      print_error(stderr, error.errors, json, "inventory-validation", command: command, subcommand: subcommand, heading: "Inventory validation failed:")
    end
  end
end
