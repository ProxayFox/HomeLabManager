module HomeLabManager
  module CLI
    extend self

    DEFAULT_INVENTORY_PATH          = "config/inventory.yml"
    DEFAULT_CONNECT_TIMEOUT_SECONDS = Transport::DEFAULT_CONNECT_TIMEOUT_SECONDS

    def run(args : Array(String), stdout : IO = STDOUT, stderr : IO = STDERR, transport : Transport = SshTransport.new) : Int32
      return print_help(stdout) if args.empty?

      case args[0]
      when "help", "--help", "-h"
        print_help(stdout)
      when "inventory"
        run_inventory(args[1..], stdout, stderr)
      when "hosts"
        run_hosts(args[1..], stdout, stderr, transport)
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
      io.puts "  homelab_manager inventory list [inventory.yml]"
      io.puts "  homelab_manager hosts check [inventory.yml]"
      io.puts
      io.puts "Commands:"
      io.puts "  inventory validate   Validate the inventory file before any remote action"
      io.puts "                       Defaults to #{DEFAULT_INVENTORY_PATH}"
      io.puts "  inventory list       List the hosts defined in the inventory file"
      io.puts "                       Defaults to #{DEFAULT_INVENTORY_PATH}"
      io.puts "  hosts check          Probe SSH connectivity for each host"
      io.puts "                       Defaults to #{DEFAULT_INVENTORY_PATH}"
      exit_code
    end

    private def run_inventory(args : Array(String), stdout : IO, stderr : IO) : Int32
      subcommand = args[0]?
      path = args[1]? || DEFAULT_INVENTORY_PATH

      unless subcommand
        stderr.puts "Missing inventory subcommand"
        stderr.puts "Expected one of: validate, list"
        return 1
      end

      inventory = Inventory.load(path)

      case subcommand
      when "validate"
        stdout.puts "Inventory valid: #{inventory.hosts.size} host(s) loaded from #{path}"
        0
      when "list"
        print_inventory_list(inventory, stdout)
        0
      else
        stderr.puts "Unknown inventory subcommand: #{subcommand}"
        stderr.puts "Expected one of: validate, list"
        1
      end
    rescue ex : InventoryError
      stderr.puts "Inventory validation failed:"
      ex.errors.each do |error|
        stderr.puts "- #{error}"
      end
      1
    end

    private def run_hosts(args : Array(String), stdout : IO, stderr : IO, transport : Transport) : Int32
      subcommand = args[0]?
      path = args[1]? || DEFAULT_INVENTORY_PATH

      unless subcommand
        stderr.puts "Missing hosts subcommand"
        stderr.puts "Expected: check"
        return 1
      end

      case subcommand
      when "check"
        inventory = Inventory.load(path)
        results = Connectivity.check(inventory, transport, DEFAULT_CONNECT_TIMEOUT_SECONDS)
        print_host_check_results(results, stdout)
        Connectivity.succeeded?(results) ? 0 : 1
      else
        stderr.puts "Unknown hosts subcommand: #{subcommand}"
        stderr.puts "Expected: check"
        1
      end
    rescue ex : InventoryError
      stderr.puts "Inventory validation failed:"
      ex.errors.each do |error|
        stderr.puts "- #{error}"
      end
      1
    end

    private def print_inventory_list(inventory : InventoryFile, io : IO) : Nil
      io.puts "Hosts: #{inventory.hosts.size}"

      inventory.hosts.each do |host|
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
  end
end
