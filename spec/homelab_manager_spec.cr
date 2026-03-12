require "./spec_helper"

def with_temp_inventory(contents : String, &)
  path = File.tempname("homelab-manager", ".yml")
  File.write(path, contents)

  begin
    yield path
  ensure
    File.delete(path) if File.exists?(path)
  end
end

describe HomeLabManager do
  it "exposes the project version" do
    HomeLabManager::VERSION.should eq("0.1.0")
  end
end

describe HomeLabManager::Inventory do
  it "parses a valid inventory and applies default update policy" do
    inventory = HomeLabManager::Inventory.parse <<-YAML
      defaults:
        update:
          allow_reboot: false
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
          tags: [core]
        - name: backup
          address: backup.internal
          ssh_user: admin
          port: 2222
          groups: [storage]
          update:
            allow_reboot: true
    YAML

    inventory.hosts.size.should eq(2)
    inventory.hosts[0].effective_update(inventory.defaults).allow_reboot?.should be_false
    inventory.hosts[1].effective_update(inventory.defaults).allow_reboot?.should be_true
  end

  it "rejects duplicate host names and blank required fields" do
    expect_raises(HomeLabManager::InventoryError) do
      HomeLabManager::Inventory.parse <<-YAML
        hosts:
          - name: atlas
            address: 192.168.1.10
            ssh_user: ubuntu
          - name: atlas
            address: ""
            ssh_user: ""
      YAML
    end
  end

  it "rejects malformed inventory before remote work begins" do
    error = expect_raises(HomeLabManager::InventoryError) do
      HomeLabManager::Inventory.parse <<-YAML
        hosts:
          - name: atlas
            address: 192.168.1.10
      YAML
    end

    error.errors.first.should contain("ssh_user")
  end
end

describe HomeLabManager::CLI do
  it "validates an inventory file from the CLI" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      exit_code = HomeLabManager::CLI.run(["inventory", "validate", path], stdout, stderr)

      exit_code.should eq(0)
      stdout.to_s.should contain("Inventory valid: 1 host(s)")
      stderr.to_s.should eq("")
    end
  end

  it "lists inventory hosts from the CLI" do
    with_temp_inventory <<-YAML do |path|
      defaults:
        update:
          allow_reboot: false
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
          tags: [core]
          groups: [lab]
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      exit_code = HomeLabManager::CLI.run(["inventory", "list", path], stdout, stderr)

      exit_code.should eq(0)
      stdout.to_s.should contain("- atlas")
      stdout.to_s.should contain("update.allow_reboot: false")
      stderr.to_s.should eq("")
    end
  end

  it "reports validation failures with a non-zero exit code" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: ""
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      exit_code = HomeLabManager::CLI.run(["inventory", "validate", path], stdout, stderr)

      exit_code.should eq(1)
      stderr.to_s.should contain("Inventory validation failed:")
      stderr.to_s.should contain("hosts[0].name must not be blank")
    end
  end
end
