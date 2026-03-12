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

def with_temp_working_directory(&)
  path = File.tempname("homelab-manager-dir")
  File.delete(path) if File.exists?(path)
  Dir.mkdir(path)

  previous = Dir.current

  begin
    Dir.cd(path)
    yield path
  ensure
    Dir.cd(previous)
    Dir.glob(File.join(path, "**", "*")).sort.reverse_each do |entry|
      if File.directory?(entry)
        Dir.delete(entry)
      else
        File.delete(entry)
      end
    end
    Dir.delete(path) if Dir.exists?(path)
  end
end

class FakeTransport < HomeLabManager::Transport
  def initialize(@results : Hash(String, HomeLabManager::ExecutionResult))
  end

  def probe(host : HomeLabManager::Host, timeout_seconds : Int32 = DEFAULT_CONNECT_TIMEOUT_SECONDS) : HomeLabManager::ExecutionResult
    @results[host.name]? || HomeLabManager::ExecutionResult.new(
      host.name,
      "connectivity_check",
      HomeLabManager::OperationStatus::Failed,
      exit_code: 255,
      summary: "missing fake result for #{host.name}",
    )
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

  it "filters hosts by tag and group selection" do
    inventory = HomeLabManager::Inventory.parse <<-YAML
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
          tags: [core, updates]
          groups: [lab]
        - name: backup
          address: backup.internal
          ssh_user: admin
          tags: [storage]
          groups: [backup]
        - name: edge
          address: edge.internal
          ssh_user: ubuntu
          tags: [updates]
          groups: [lab]
    YAML

    selected = HomeLabManager::Inventory.select_hosts(
      inventory,
      HomeLabManager::HostSelection.new(["updates"], ["lab"]),
    )

    selected.map(&.name).should eq(["atlas", "edge"])
  end
end

describe HomeLabManager::Updates do
  it "builds a pending update plan when manual approval is required" do
    inventory = HomeLabManager::Inventory.parse <<-YAML
      defaults:
        update:
          require_manual_approval: true
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML

    plan = HomeLabManager::Updates.build_plans(inventory, inventory.hosts, false).first

    plan.approval_state.should eq(HomeLabManager::ApprovalState::Pending)
    plan.steps.find!(&.mutating?).enabled?.should be_false
  end

  it "builds an approved update plan when approval is given" do
    inventory = HomeLabManager::Inventory.parse <<-YAML
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
          update:
            require_manual_approval: true
    YAML

    plan = HomeLabManager::Updates.build_plans(inventory, inventory.hosts, true).first

    plan.approval_state.should eq(HomeLabManager::ApprovalState::Approved)
    plan.steps.find!(&.mutating?).enabled?.should be_true
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

  it "checks host connectivity through the transport boundary" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
        - name: backup
          address: backup.internal
          ssh_user: admin
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      transport = FakeTransport.new(
        {
          "atlas" => HomeLabManager::ExecutionResult.new(
            "atlas",
            "connectivity_check",
            HomeLabManager::OperationStatus::Succeeded,
            exit_code: 0,
            summary: "ssh connectivity ok",
          ),
          "backup" => HomeLabManager::ExecutionResult.new(
            "backup",
            "connectivity_check",
            HomeLabManager::OperationStatus::Failed,
            exit_code: 255,
            summary: "connection refused",
          ),
        },
      )

      exit_code = HomeLabManager::CLI.run(["hosts", "check", path], stdout, stderr, transport)

      exit_code.should eq(1)
      stdout.to_s.should contain("- atlas: succeeded")
      stdout.to_s.should contain("- backup: failed")
      stdout.to_s.should contain("Summary: 1 succeeded, 1 failed")
      stderr.to_s.should eq("")
    end
  end

  it "uses the default inventory path for host checks" do
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
      transport = FakeTransport.new(
        {
          "atlas" => HomeLabManager::ExecutionResult.new(
            "atlas",
            "connectivity_check",
            HomeLabManager::OperationStatus::Succeeded,
            exit_code: 0,
            summary: "ssh connectivity ok",
          ),
        },
      )

      exit_code = HomeLabManager::CLI.run(["hosts", "check"], stdout, stderr, transport)

      exit_code.should eq(0)
      stdout.to_s.should contain("Connectivity check: 1 host(s)")
      stdout.to_s.should contain("Summary: 1 succeeded, 0 failed")
      stderr.to_s.should eq("")
    end
  end

  it "filters host checks by group" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
          groups: [lab]
        - name: backup
          address: backup.internal
          ssh_user: admin
          groups: [backup]
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      transport = FakeTransport.new(
        {
          "atlas" => HomeLabManager::ExecutionResult.new(
            "atlas",
            "connectivity_check",
            HomeLabManager::OperationStatus::Succeeded,
            exit_code: 0,
            summary: "ssh connectivity ok",
          ),
        },
      )

      exit_code = HomeLabManager::CLI.run(["hosts", "check", path, "--group", "lab"], stdout, stderr, transport)

      exit_code.should eq(0)
      stdout.to_s.should contain("- atlas: succeeded")
      stdout.to_s.should_not contain("backup")
      stderr.to_s.should eq("")
    end
  end

  it "prints an approval-gated update plan" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
          tags: [updates]
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      exit_code = HomeLabManager::CLI.run(["updates", "plan", path, "--tag", "updates"], stdout, stderr)

      exit_code.should eq(0)
      stdout.to_s.should contain("approval_state: pending")
      stdout.to_s.should contain("step: apply upgrades [blocked]")
      stdout.to_s.should contain("manual approval required")
      stderr.to_s.should eq("")
    end
  end

  it "marks the update plan approved when --approve is provided" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      exit_code = HomeLabManager::CLI.run(["updates", "plan", path, "--approve"], stdout, stderr)

      exit_code.should eq(0)
      stdout.to_s.should contain("approval_state: approved")
      stdout.to_s.should contain("step: apply upgrades [ready]")
      stderr.to_s.should eq("")
    end
  end
end
