module HomeLabManager
  module CLI
    extend self

    def run(args : Array(String), stdout : IO = STDOUT, stderr : IO = STDERR) : Int32
      return print_help(stdout) if args.empty?

      case args[0]
      when "help", "--help", "-h"
        print_help(stdout)
      when "inventory"
        run_inventory(args[1..], stdout, stderr)
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
      io.puts "  homelab_manager inventory validate <inventory.yml>"
      io.puts "  homelab_manager inventory list <inventory.yml>"
      io.puts
      io.puts "Commands:"
      io.puts "  inventory validate   Validate the inventory file before any remote action"
      io.puts "  inventory list       List the hosts defined in the inventory file"
      exit_code
    end

    private def run_inventory(args : Array(String), stdout : IO, stderr : IO) : Int32
      subcommand = args[0]?
      path = args[1]?

      unless subcommand
        stderr.puts "Missing inventory subcommand"
        stderr.puts "Expected one of: validate, list"
        return 1
      end

      unless path
        stderr.puts "Missing inventory file path"
        stderr.puts "Usage: homelab_manager inventory #{subcommand} <inventory.yml>"
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
        io.puts "  update.refresh_package_index: #{update_policy.refresh_package_index}"
        io.puts "  update.preview_upgrades: #{update_policy.preview_upgrades}"
        io.puts "  update.require_manual_approval: #{update_policy.require_manual_approval}"
        io.puts "  update.allow_reboot: #{update_policy.allow_reboot}"
      end
    end
  end
end