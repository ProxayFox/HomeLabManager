module HomeLabManager
  module CLI
    extend self

    DEFAULT_INVENTORY_PATH          = "config/inventory.yml"
    DEFAULT_CONNECT_TIMEOUT_SECONDS = Transport::DEFAULT_CONNECT_TIMEOUT_SECONDS

    private record CommandOptions,
      path : String,
      selection : HostSelection,
      approve : Bool,
      execute : Bool

    def run(args : Array(String), stdout : IO = STDOUT, stderr : IO = STDERR, transport : Transport = SshTransport.new, audit_logger : Audit::Logger = Audit::FileLogger.new) : Int32
      return print_help(stdout) if args.empty?

      case args[0]
      when "help", "--help", "-h"
        print_help(stdout)
      when "inventory"
        run_inventory(args[1..], stdout, stderr)
      when "hosts"
        run_hosts(args[1..], stdout, stderr, transport)
      when "updates"
        run_updates(args[1..], stdout, stderr, transport, audit_logger)
      else
        stderr.puts "Unknown command: #{args[0]}"
        stderr.puts
        print_help(stderr, 1)
      end
    end

    private def print_help(io : IO, exit_code : Int32 = 0) : Int32
      io.puts "HomeLabManager"
      io.puts
      io.puts "Usage:"
      io.puts "  homelab_manager inventory validate [inventory.yml]"
      io.puts "  homelab_manager inventory list [inventory.yml] [--tag TAG] [--group GROUP]"
      io.puts "  homelab_manager hosts check [inventory.yml] [--tag TAG] [--group GROUP]"
      io.puts "  homelab_manager updates plan [inventory.yml] [--tag TAG] [--group GROUP] [--approve]"
      io.puts "  homelab_manager updates dry-run [inventory.yml] [--tag TAG] [--group GROUP] [--approve]"
      io.puts "  homelab_manager updates run [inventory.yml] [--tag TAG] [--group GROUP] [--approve] --execute"
      io.puts
      io.puts "Commands:"
      io.puts "  inventory validate   Validate the inventory file before any remote action"
      io.puts "                       Defaults to #{DEFAULT_INVENTORY_PATH}"
      io.puts "  inventory list       List the hosts defined in the inventory file"
      io.puts "                       Defaults to #{DEFAULT_INVENTORY_PATH}"
      io.puts "                       Supports repeated --tag and --group filters"
      io.puts "  hosts check          Probe SSH connectivity for each host"
      io.puts "                       Defaults to #{DEFAULT_INVENTORY_PATH}"
      io.puts "                       Supports repeated --tag and --group filters"
      io.puts "  updates plan         Build a dry-run-first update plan without executing it"
      io.puts "                       Supports repeated --tag and --group filters and optional --approve"
      io.puts "  updates dry-run      Execute only non-mutating update steps and write audit logs"
      io.puts "                       Supports repeated --tag and --group filters and optional --approve"
      io.puts "  updates run          Execute the full update workflow, including approved mutating steps"
      io.puts "                       Requires --execute and supports repeated --tag/--group filters plus optional --approve"
      exit_code
    end

    private def run_inventory(args : Array(String), stdout : IO, stderr : IO) : Int32
      subcommand = args[0]?

      unless subcommand
        stderr.puts "Missing inventory subcommand"
        stderr.puts "Expected one of: validate, list"
        return 1
      end

      options = parse_command_options(args[1..])
      inventory = Inventory.load(options.path)

      case subcommand
      when "validate"
        stdout.puts "Inventory valid: #{inventory.hosts.size} host(s) loaded from #{options.path}"
        0
      when "list"
        hosts = Inventory.select_hosts(inventory, options.selection)
        return print_empty_selection(stderr, options.selection) if hosts.empty?

        print_inventory_list(inventory, hosts, stdout)
        0
      else
        stderr.puts "Unknown inventory subcommand: #{subcommand}"
        stderr.puts "Expected one of: validate, list"
        1
      end
    rescue ex : InventoryError
      print_inventory_errors(stderr, ex)
      1
    end

    private def run_hosts(args : Array(String), stdout : IO, stderr : IO, transport : Transport) : Int32
      subcommand = args[0]?

      unless subcommand
        stderr.puts "Missing hosts subcommand"
        stderr.puts "Expected: check"
        return 1
      end

      options = parse_command_options(args[1..])

      case subcommand
      when "check"
        inventory = Inventory.load(options.path)
        hosts = Inventory.select_hosts(inventory, options.selection)
        return print_empty_selection(stderr, options.selection) if hosts.empty?

        results = Connectivity.check(InventoryFile.new(inventory.defaults, hosts), transport, DEFAULT_CONNECT_TIMEOUT_SECONDS)
        print_host_check_results(results, stdout)
        Connectivity.succeeded?(results) ? 0 : 1
      else
        stderr.puts "Unknown hosts subcommand: #{subcommand}"
        stderr.puts "Expected: check"
        1
      end
    rescue ex : InventoryError
      print_inventory_errors(stderr, ex)
      1
    end

    private def run_updates(args : Array(String), stdout : IO, stderr : IO, transport : Transport, audit_logger : Audit::Logger) : Int32
      subcommand = args[0]?

      unless subcommand
        stderr.puts "Missing updates subcommand"
        stderr.puts "Expected: plan"
        return 1
      end

      options = parse_command_options(args[1..], allow_approve: true, allow_execute: true)
      handle_updates_subcommand(subcommand, options, stdout, stderr, transport, audit_logger)
    rescue ex : InventoryError
      print_inventory_errors(stderr, ex)
      1
    end

    private def handle_updates_subcommand(
      subcommand : String,
      options : CommandOptions,
      stdout : IO,
      stderr : IO,
      transport : Transport,
      audit_logger : Audit::Logger,
    ) : Int32
      case subcommand
      when "plan"
        run_updates_plan(options, stdout, stderr)
      when "dry-run"
        run_updates_dry_run(options, stdout, stderr, transport, audit_logger)
      when "run"
        run_updates_execute(options, stdout, stderr, transport, audit_logger)
      else
        stderr.puts "Unknown updates subcommand: #{subcommand}"
        stderr.puts "Expected: plan, dry-run, run"
        1
      end
    end

    private def load_selected_hosts(options : CommandOptions, stderr : IO) : Tuple(InventoryFile, Array(Host))?
      inventory = Inventory.load(options.path)
      hosts = Inventory.select_hosts(inventory, options.selection)
      return nil if hosts.empty? && print_empty_selection(stderr, options.selection) == 1

      {inventory, hosts}
    end

    private def run_updates_plan(options : CommandOptions, stdout : IO, stderr : IO) : Int32
      loaded = load_selected_hosts(options, stderr)
      return 1 unless loaded

      inventory, hosts = loaded
      plans = Updates.build_plans(inventory, hosts, options.approve)
      print_update_plans(plans, stdout)
      0
    end

    private def run_updates_dry_run(options : CommandOptions, stdout : IO, stderr : IO, transport : Transport, audit_logger : Audit::Logger) : Int32
      loaded = load_selected_hosts(options, stderr)
      return 1 unless loaded

      inventory, hosts = loaded
      plans = Updates.build_plans(inventory, hosts, options.approve)
      runs = Updates.dry_run(plans, transport, audit_logger)
      print_update_runs("Update dry-run", runs, stdout)
      stdout.puts "Audit log: #{Audit::DEFAULT_LOG_PATH}" if audit_logger.is_a?(Audit::FileLogger)
      Updates.successful?(runs) ? 0 : 1
    end

    private def run_updates_execute(options : CommandOptions, stdout : IO, stderr : IO, transport : Transport, audit_logger : Audit::Logger) : Int32
      unless options.execute
        stderr.puts "Refusing to run mutating updates without --execute"
        stderr.puts "Use updates plan or updates dry-run first, then rerun with --execute when ready"
        return 1
      end

      loaded = load_selected_hosts(options, stderr)
      return 1 unless loaded

      inventory, hosts = loaded
      plans = Updates.build_plans(inventory, hosts, options.approve)
      runs = Updates.execute(plans, transport, audit_logger)
      print_update_runs("Update run", runs, stdout)
      stdout.puts "Audit log: #{Audit::DEFAULT_LOG_PATH}" if audit_logger.is_a?(Audit::FileLogger)
      Updates.successful?(runs) ? 0 : 1
    end

    private def print_inventory_list(inventory : InventoryFile, hosts : Array(Host), io : IO) : Nil
      io.puts "Hosts: #{hosts.size}"

      hosts.each do |host|
        update_policy = host.effective_update(inventory.defaults)
        tags = host.tags.empty? ? "-" : host.tags.join(",")
        groups = host.groups.empty? ? "-" : host.groups.join(",")

        io.puts "- #{host.name}"
        io.puts "  address: #{host.address}:#{host.port}"
        io.puts "  ssh_user: #{host.ssh_user}"
        io.puts "  tags: #{tags}"
        io.puts "  groups: #{groups}"
        io.puts "  update.refresh_package_index: #{update_policy.refresh_package_index?}"
        io.puts "  update.preview_upgrades: #{update_policy.preview_upgrades?}"
        io.puts "  update.require_manual_approval: #{update_policy.require_manual_approval?}"
        io.puts "  update.allow_reboot: #{update_policy.allow_reboot?}"
      end
    end

    private def print_host_check_results(results : Array(ExecutionResult), io : IO) : Nil
      io.puts "Connectivity check: #{results.size} host(s)"

      results.each do |result|
        io.puts "- #{result.host_name}: #{result.status.to_s.downcase}"
        io.puts "  summary: #{result.summary}"
        if exit_code = result.exit_code
          io.puts "  exit_code: #{exit_code}"
        end
      end

      succeeded_count = results.count { |result| result.status == OperationStatus::Succeeded }
      failed_count = results.count { |result| result.status == OperationStatus::Failed }
      io.puts "Summary: #{succeeded_count} succeeded, #{failed_count} failed"
    end

    private def print_update_plans(plans : Array(UpdatePlan), io : IO) : Nil
      io.puts "Update plan: #{plans.size} host(s)"

      plans.each do |plan|
        io.puts "- #{plan.host.name}"
        io.puts "  approval_state: #{plan.approval_state.to_s.downcase}"
        io.puts "  approval_required: #{plan.approval_required?}"

        plan.steps.each do |step|
          status = step.enabled? ? "ready" : "blocked"
          io.puts "  step: #{step.label} [#{status}]"
          io.puts "    command: #{step.command}"
          if reason = step.reason
            io.puts "    reason: #{reason}"
          end
        end
      end
    end

    private def print_update_runs(title : String, runs : Array(UpdateRun), io : IO) : Nil
      io.puts "#{title}: #{runs.size} host(s)"

      runs.each do |run|
        io.puts "- #{run.host.name}"
        io.puts "  overall_status: #{run.overall_status}"
        io.puts "  approval_state: #{run.approval_state.to_s.downcase}"
        io.puts "  reboot_required: #{run.reboot_required}" unless run.reboot_required.nil?

        run.step_results.each do |result|
          io.puts "  action: #{result.action} [#{result.status.to_s.downcase}]"
          io.puts "    summary: #{result.summary}"
          if exit_code = result.exit_code
            io.puts "    exit_code: #{exit_code}"
          end
        end
      end

      succeeded_count = runs.count(&.successful?)
      partial_count = runs.count(&.partially_failed?)
      failed_count = runs.size - succeeded_count - partial_count
      io.puts "Summary: #{succeeded_count} succeeded, #{partial_count} partial, #{failed_count} failed"
    end

    private def parse_command_options(args : Array(String), allow_approve : Bool = false, allow_execute : Bool = false) : CommandOptions
      path = nil
      tags = [] of String
      groups = [] of String
      approve = false
      execute = false
      index = 0

      while index < args.size
        argument = args[index]

        case argument
        when "--tag"
          value = args[index + 1]?
          raise InventoryError.new(["missing value for --tag"]) unless value

          tags << value
          index += 2
        when "--group"
          value = args[index + 1]?
          raise InventoryError.new(["missing value for --group"]) unless value

          groups << value
          index += 2
        when "--approve"
          raise InventoryError.new(["--approve is not supported for this command"]) unless allow_approve

          approve = true
          index += 1
        when "--execute"
          raise InventoryError.new(["--execute is not supported for this command"]) unless allow_execute

          execute = true
          index += 1
        else
          if argument.starts_with?("--")
            raise InventoryError.new(["unknown option: #{argument}"])
          end

          if path
            raise InventoryError.new(["unexpected argument: #{argument}"])
          end

          path = argument
          index += 1
        end
      end

      CommandOptions.new(path || DEFAULT_INVENTORY_PATH, HostSelection.new(tags, groups), approve, execute)
    end

    private def print_empty_selection(stderr : IO, selection : HostSelection) : Int32
      stderr.puts "No hosts matched the requested filters"
      stderr.puts "Tags: #{selection.tags.join(",")}" unless selection.tags.empty?
      stderr.puts "Groups: #{selection.groups.join(",")}" unless selection.groups.empty?
      1
    end

    private def print_inventory_errors(stderr : IO, error : InventoryError) : Nil
      stderr.puts "Inventory validation failed:"
      error.errors.each do |entry|
        stderr.puts "- #{entry}"
      end
    end
  end
end
