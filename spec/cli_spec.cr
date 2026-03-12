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

  it "renders connectivity checks as json" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
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

      exit_code = HomeLabManager::CLI.run(["hosts", "check", path, "--json"], stdout, stderr, transport)

      exit_code.should eq(0)
      stdout.to_s.should contain("\"type\":\"connectivity-check\"")
      stdout.to_s.should contain("\"host\":\"atlas\"")
      stdout.to_s.should contain("\"succeeded\":1")
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

  it "renders empty host selection as json" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
          groups: [lab]
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      transport = FakeTransport.new

      exit_code = HomeLabManager::CLI.run(["hosts", "check", path, "--group", "missing", "--json"], stdout, stderr, transport)

      exit_code.should eq(1)
      stdout.to_s.should eq("")
      stderr.to_s.should contain("\"category\":\"selection\"")
      stderr.to_s.should contain("\"command\":\"hosts\"")
      stderr.to_s.should contain("no hosts matched the requested filters")
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

  it "renders update plans as json" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      exit_code = HomeLabManager::CLI.run(["updates", "plan", path, "--json"], stdout, stderr)

      exit_code.should eq(0)
      stdout.to_s.should contain("\"type\":\"update-plan\"")
      stdout.to_s.should contain("\"host\":\"atlas\"")
      stderr.to_s.should eq("")
    end
  end

  it "executes an update dry-run and prints per-step results" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      transport = FakeTransport.new(
        command_results: {
          "atlas|update_refresh_package_index" => HomeLabManager::ExecutionResult.new(
            "atlas",
            "update_refresh_package_index",
            HomeLabManager::OperationStatus::Succeeded,
            exit_code: 0,
            summary: "package lists refreshed",
          ),
          "atlas|update_preview_upgrades" => HomeLabManager::ExecutionResult.new(
            "atlas",
            "update_preview_upgrades",
            HomeLabManager::OperationStatus::Succeeded,
            exit_code: 0,
            summary: "1 package can be upgraded",
          ),
          "atlas|update_check_reboot_required" => HomeLabManager::ExecutionResult.new(
            "atlas",
            "update_check_reboot_required",
            HomeLabManager::OperationStatus::Succeeded,
            exit_code: 0,
            summary: "reboot not required",
          ),
        },
      )

      exit_code = HomeLabManager::CLI.run(
        ["updates", "dry-run", path],
        stdout,
        stderr,
        transport,
        HomeLabManager::Audit::NullLogger.new,
      )

      exit_code.should eq(0)
      stdout.to_s.should contain("Update dry-run: 1 host(s)")
      stdout.to_s.should contain("overall_status: succeeded")
      stdout.to_s.should contain("action: update_refresh_package_index [succeeded]")
      stdout.to_s.should contain("action: update_apply_upgrades [skipped]")
      stdout.to_s.should contain("Summary: 1 succeeded, 0 partial, 0 failed")
      stderr.to_s.should eq("")
    end
  end

  it "requires --execute before running mutating updates" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      exit_code = HomeLabManager::CLI.run(["updates", "run", path], stdout, stderr)

      exit_code.should eq(1)
      stderr.to_s.should contain("Refusing to run mutating updates without --execute")
    end
  end

  it "renders execution guard failures as json" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      exit_code = HomeLabManager::CLI.run(["updates", "run", path, "--json"], stdout, stderr)

      exit_code.should eq(1)
      stdout.to_s.should eq("")
      stderr.to_s.should contain("\"category\":\"execution-guard\"")
      stderr.to_s.should contain("\"subcommand\":\"run\"")
      stderr.to_s.should contain("Refusing to run mutating updates without --execute")
    end
  end

  it "renders unknown commands as json" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    exit_code = HomeLabManager::CLI.run(["bogus", "--json"], stdout, stderr)

    exit_code.should eq(1)
    stdout.to_s.should eq("")
    stderr.to_s.should contain("\"category\":\"usage\"")
    stderr.to_s.should contain("unknown command: bogus")
    stderr.to_s.should_not contain("HomeLabManager")
  end

  it "supports resume-from on update execution" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      transport = FakeTransport.new(
        command_results: {
          "atlas|update_apply_upgrades" => HomeLabManager::ExecutionResult.new(
            "atlas", "update_apply_upgrades", HomeLabManager::OperationStatus::Succeeded, exit_code: 0, summary: "packages upgraded"),
          "atlas|update_check_reboot_required" => HomeLabManager::ExecutionResult.new(
            "atlas", "update_check_reboot_required", HomeLabManager::OperationStatus::Failed, exit_code: 1, summary: "flag absent"),
        },
      )

      exit_code = HomeLabManager::CLI.run(
        ["updates", "run", path, "--approve", "--resume-from", "update_apply_upgrades", "--execute"],
        stdout,
        stderr,
        transport,
        HomeLabManager::Audit::NullLogger.new,
      )

      exit_code.should eq(0)
      stdout.to_s.should contain("skipped before resume point")
      stdout.to_s.should contain("action: update_apply_upgrades [succeeded]")
      stderr.to_s.should eq("")
    end
  end

  it "uses persisted recovery state when no resume-from is provided" do
    with_temp_working_directory do |path|
      inventory_path = File.join(path, "inventory.yml")
      File.write(
        inventory_path,
        <<-YAML
          hosts:
            - name: atlas
              address: 192.168.1.10
              ssh_user: ubuntu
        YAML
      )

      state_store = HomeLabManager::Updates::StateStore.new(File.join(path, HomeLabManager::CLI::DEFAULT_UPDATE_STATE_PATH))
      state_store.record_runs([
        HomeLabManager::UpdateRun.new(
          HomeLabManager::Inventory.load(inventory_path).hosts.first,
          HomeLabManager::ApprovalState::Approved,
          [
            HomeLabManager::ExecutionResult.new(
              "atlas",
              "update_refresh_package_index",
              HomeLabManager::OperationStatus::Succeeded,
              approval_state: HomeLabManager::ApprovalState::Approved,
              exit_code: 0,
              summary: "package lists refreshed",
            ),
            HomeLabManager::ExecutionResult.new(
              "atlas",
              "update_apply_upgrades",
              HomeLabManager::OperationStatus::Failed,
              approval_state: HomeLabManager::ApprovalState::Approved,
              exit_code: 100,
              summary: "apt failed",
            ),
          ],
          false,
        ),
      ])

      stdout = IO::Memory.new
      stderr = IO::Memory.new

      exit_code = HomeLabManager::CLI.run(["updates", "plan", inventory_path, "--approve"], stdout, stderr)

      exit_code.should eq(0)
      stdout.to_s.should contain("skipped before resume point")
      stdout.to_s.should contain("step: apply upgrades [ready]")
      stderr.to_s.should eq("")
    end
  end

  it "executes approved updates and reports partial failures" do
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
        command_results: {
          "atlas|update_refresh_package_index" => HomeLabManager::ExecutionResult.new(
            "atlas", "update_refresh_package_index", HomeLabManager::OperationStatus::Succeeded, exit_code: 0, summary: "package lists refreshed"),
          "atlas|update_preview_upgrades" => HomeLabManager::ExecutionResult.new(
            "atlas", "update_preview_upgrades", HomeLabManager::OperationStatus::Succeeded, exit_code: 0, summary: "2 packages can be upgraded"),
          "atlas|update_apply_upgrades" => HomeLabManager::ExecutionResult.new(
            "atlas", "update_apply_upgrades", HomeLabManager::OperationStatus::Succeeded, exit_code: 0, summary: "packages upgraded"),
          "atlas|update_check_reboot_required" => HomeLabManager::ExecutionResult.new(
            "atlas", "update_check_reboot_required", HomeLabManager::OperationStatus::Failed, exit_code: 1, summary: "flag absent"),
          "backup|update_refresh_package_index" => HomeLabManager::ExecutionResult.new(
            "backup", "update_refresh_package_index", HomeLabManager::OperationStatus::Failed, exit_code: 100, summary: "apt failed"),
        },
      )

      exit_code = HomeLabManager::CLI.run(
        ["updates", "run", path, "--approve", "--execute"],
        stdout,
        stderr,
        transport,
        HomeLabManager::Audit::NullLogger.new,
      )

      exit_code.should eq(1)
      stdout.to_s.should contain("Update run: 2 host(s)")
      stdout.to_s.should contain("- atlas")
      stdout.to_s.should contain("reboot_required: false")
      stdout.to_s.should contain("- backup")
      stdout.to_s.should contain("overall_status: partial")
      stdout.to_s.should contain("Summary: 1 succeeded, 1 partial, 0 failed")
      stderr.to_s.should eq("")
    end
  end

  it "renders update runs as json" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      transport = FakeTransport.new(
        command_results: {
          "atlas|update_refresh_package_index" => HomeLabManager::ExecutionResult.new(
            "atlas", "update_refresh_package_index", HomeLabManager::OperationStatus::Succeeded, exit_code: 0, summary: "package lists refreshed"),
          "atlas|update_preview_upgrades" => HomeLabManager::ExecutionResult.new(
            "atlas", "update_preview_upgrades", HomeLabManager::OperationStatus::Succeeded, exit_code: 0, summary: "preview ok"),
          "atlas|update_check_reboot_required" => HomeLabManager::ExecutionResult.new(
            "atlas", "update_check_reboot_required", HomeLabManager::OperationStatus::Failed, exit_code: 1, summary: "flag absent"),
        },
      )

      exit_code = HomeLabManager::CLI.run(
        ["updates", "dry-run", path, "--json"],
        stdout,
        stderr,
        transport,
        HomeLabManager::Audit::NullLogger.new,
      )

      exit_code.should eq(0)
      stdout.to_s.should contain("\"type\":\"update-dry-run\"")
      stdout.to_s.should contain("\"overall_status\":\"succeeded\"")
      stdout.to_s.should contain("\"action\":\"update_apply_upgrades\"")
      stderr.to_s.should eq("")
    end
  end
end
