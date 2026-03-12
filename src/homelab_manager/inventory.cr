module HomeLabManager
  class InventoryError < Exception
    getter errors : Array(String)

    def initialize(@errors : Array(String))
      super(errors.join('\n'))
    end
  end

  struct UpdatePolicy
    include YAML::Serializable

    getter? refresh_package_index : Bool = true
    getter? preview_upgrades : Bool = true
    getter? require_manual_approval : Bool = true
    getter? allow_reboot : Bool = false

    def initialize(
      @refresh_package_index : Bool = true,
      @preview_upgrades : Bool = true,
      @require_manual_approval : Bool = true,
      @allow_reboot : Bool = false,
    )
    end
  end

  struct InventoryDefaults
    include YAML::Serializable

    getter update : UpdatePolicy = UpdatePolicy.new

    def initialize(@update : UpdatePolicy = UpdatePolicy.new)
    end
  end

  struct Host
    include YAML::Serializable

    getter name : String
    getter address : String
    getter ssh_user : String
    getter port : Int32 = 22
    getter tags : Array(String) = [] of String
    getter groups : Array(String) = [] of String
    getter update : UpdatePolicy? = nil

    def effective_update(defaults : InventoryDefaults) : UpdatePolicy
      update || defaults.update
    end

    def validation_errors(index : Int32) : Array(String)
      errors = [] of String

      if name.strip.empty?
        errors << "hosts[#{index}].name must not be blank"
      end

      if address.strip.empty?
        errors << "hosts[#{index}].address must not be blank"
      end

      if ssh_user.strip.empty?
        errors << "hosts[#{index}].ssh_user must not be blank"
      end

      if port < 1 || port > 65_535
        errors << "hosts[#{index}].port must be between 1 and 65535"
      end

      errors
    end
  end

  struct InventoryFile
    include YAML::Serializable

    getter defaults : InventoryDefaults = InventoryDefaults.new
    getter hosts : Array(Host) = [] of Host

    def initialize(
      @defaults : InventoryDefaults = InventoryDefaults.new,
      @hosts : Array(Host) = [] of Host,
    )
    end

    def validate! : self
      errors = [] of String

      if hosts.empty?
        errors << "hosts must contain at least one host"
      end

      names = Set(String).new

      hosts.each_with_index do |host, index|
        host.validation_errors(index).each do |error|
          errors << error
        end

        normalized_name = host.name.strip
        next if normalized_name.empty?

        if names.includes?(normalized_name)
          errors << "hosts[#{index}].name duplicates an earlier host: #{normalized_name}"
        else
          names << normalized_name
        end
      end

      raise InventoryError.new(errors) unless errors.empty?

      self
    end
  end

  module Inventory
    extend self

    def load(path : String) : InventoryFile
      content = File.read(path)
      parse(content, path)
    rescue ex : File::NotFoundError
      raise InventoryError.new(["inventory file not found: #{path}"])
    end

    def parse(content : String, source : String = "inventory") : InventoryFile
      inventory = InventoryFile.from_yaml(content)
      inventory.validate!
    rescue ex : InventoryError
      raise ex
    rescue ex : YAML::ParseException
      raise InventoryError.new(["#{source}: invalid YAML: #{ex.message}"])
    rescue ex
      raise InventoryError.new(["#{source}: #{ex.message}"])
    end

    def select_hosts(inventory : InventoryFile, selection : HostSelection) : Array(Host)
      return inventory.hosts if selection.empty?

      inventory.hosts.select do |host|
        matches_tags = selection.tags.empty? || selection.tags.any? { |tag| host.tags.includes?(tag) }
        matches_groups = selection.groups.empty? || selection.groups.any? { |group| host.groups.includes?(group) }
        matches_tags && matches_groups
      end
    end
  end
end
