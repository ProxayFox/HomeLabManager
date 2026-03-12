module HomeLabManager
  module CLI
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

    private def print_inventory_validation_json(path : String, inventory : InventoryFile, io : IO) : Nil
      JSON.build(io) do |json|
        json.object do
          json.field "type", "inventory-validation"
          json.field "path", path
          json.field "valid", true
          json.field "host_count", inventory.hosts.size
        end
      end
      io.puts
    end

    private def print_inventory_list_json(path : String, inventory : InventoryFile, hosts : Array(Host), selection : HostSelection, io : IO) : Nil
      JSON.build(io) do |json|
        json.object do
          json.field "type", "inventory-list"
          json.field "path", path
          json.field "selection" do
            json.object do
              json.field "tags" do
                json.array do
                  selection.tags.each do |tag|
                    json.string(tag)
                  end
                end
              end
              json.field "groups" do
                json.array do
                  selection.groups.each do |group|
                    json.string(group)
                  end
                end
              end
            end
          end
          json.field "defaults" do
            json.object do
              json.field "update" do
                print_update_policy_json(json, inventory.defaults.update)
              end
            end
          end
          json.field "hosts" do
            json.array do
              hosts.each do |host|
                json.object do
                  json.field "name", host.name
                  json.field "address", host.address
                  json.field "port", host.port
                  json.field "ssh_user", host.ssh_user
                  json.field "tags" do
                    json.array do
                      host.tags.each do |tag|
                        json.string(tag)
                      end
                    end
                  end
                  json.field "groups" do
                    json.array do
                      host.groups.each do |group|
                        json.string(group)
                      end
                    end
                  end
                  json.field "update" do
                    print_update_policy_json(json, host.effective_update(inventory.defaults))
                  end
                end
              end
            end
          end
        end
      end
      io.puts
    end

    private def print_update_policy_json(json : JSON::Builder, policy : UpdatePolicy) : Nil
      json.object do
        json.field "refresh_package_index", policy.refresh_package_index?
        json.field "preview_upgrades", policy.preview_upgrades?
        json.field "require_manual_approval", policy.require_manual_approval?
        json.field "allow_reboot", policy.allow_reboot?
      end
    end
  end
end
