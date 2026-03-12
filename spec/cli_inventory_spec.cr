require "./spec_helper"

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

  it "renders inventory validation as json" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      exit_code = HomeLabManager::CLI.run(["inventory", "validate", path, "--json"], stdout, stderr)

      exit_code.should eq(0)
      stdout.to_s.should contain("\"type\":\"inventory-validation\"")
      stdout.to_s.should contain("\"host_count\":1")
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

  it "renders inventory hosts as json" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
          tags: [core]
          groups: [lab]
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      exit_code = HomeLabManager::CLI.run(["inventory", "list", path, "--tag", "core", "--json"], stdout, stderr)

      exit_code.should eq(0)
      stdout.to_s.should contain("\"type\":\"inventory-list\"")
      stdout.to_s.should contain("\"name\":\"atlas\"")
      stdout.to_s.should contain("\"tags\":[\"core\"]")
      stderr.to_s.should eq("")
    end
  end

  it "filters listed hosts by tag" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
          tags: [core]
        - name: backup
          address: backup.internal
          ssh_user: admin
          tags: [storage]
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      exit_code = HomeLabManager::CLI.run(["inventory", "list", path, "--tag", "core"], stdout, stderr)

      exit_code.should eq(0)
      stdout.to_s.should contain("- atlas")
      stdout.to_s.should_not contain("- backup")
      stderr.to_s.should eq("")
    end
  end

  it "defaults inventory commands to config/inventory.yml" do
    with_temp_working_directory do |path|
      Dir.mkdir(File.join(path, "config"))
      File.write(
        File.join(path, HomeLabManager::CLI::DEFAULT_INVENTORY_PATH),
        <<-YAML
          hosts:
            - name: atlas
              address: 192.168.1.10
              ssh_user: ubuntu
        YAML
      )

      stdout = IO::Memory.new
      stderr = IO::Memory.new

      exit_code = HomeLabManager::CLI.run(["inventory", "validate"], stdout, stderr)

      exit_code.should eq(0)
      stdout.to_s.should contain(HomeLabManager::CLI::DEFAULT_INVENTORY_PATH)
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

  it "renders inventory validation failures as json" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: ""
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      exit_code = HomeLabManager::CLI.run(["inventory", "validate", path, "--json"], stdout, stderr)

      exit_code.should eq(1)
      stdout.to_s.should eq("")
      stderr.to_s.should contain("\"type\":\"error\"")
      stderr.to_s.should contain("\"category\":\"inventory-validation\"")
      stderr.to_s.should contain("\"command\":\"inventory\"")
      stderr.to_s.should contain("hosts[0].name must not be blank")
    end
  end
end
