require "./spec_helper"

describe HomeLabManager::CLI do
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
      stdout.to_s.should contain("\"resume_context\":null")
      stderr.to_s.should eq("")
    end
  end

  it "renders persisted recovery context in update plan json" do
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

      exit_code = HomeLabManager::CLI.run(["updates", "plan", inventory_path, "--approve", "--json"], stdout, stderr)

      exit_code.should eq(0)
      stdout.to_s.should contain("\"resume_context\":{\"source\":\"persisted\"")
      stdout.to_s.should contain("\"resume_from\":\"update_apply_upgrades\"")
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
      stdout.to_s.should contain("\"resume_context\":null")
      stdout.to_s.should contain("\"overall_status\":\"succeeded\"")
      stdout.to_s.should contain("\"action\":\"update_apply_upgrades\"")
      stderr.to_s.should eq("")
    end
  end

  it "renders persisted recovery context in update run json" do
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
      transport = FakeTransport.new(
        command_results: {
          "atlas|update_apply_upgrades" => HomeLabManager::ExecutionResult.new(
            "atlas", "update_apply_upgrades", HomeLabManager::OperationStatus::Succeeded, exit_code: 0, summary: "packages upgraded"),
          "atlas|update_check_reboot_required" => HomeLabManager::ExecutionResult.new(
            "atlas", "update_check_reboot_required", HomeLabManager::OperationStatus::Failed, exit_code: 1, summary: "flag absent"),
        },
      )

      exit_code = HomeLabManager::CLI.run(
        ["updates", "run", inventory_path, "--approve", "--execute", "--json"],
        stdout,
        stderr,
        transport,
        HomeLabManager::Audit::NullLogger.new,
      )

      exit_code.should eq(0)
      stdout.to_s.should contain("\"type\":\"update-run\"")
      stdout.to_s.should contain("\"resume_context\":{\"source\":\"persisted\"")
      stdout.to_s.should contain("\"resume_from\":\"update_apply_upgrades\"")
      stderr.to_s.should eq("")
    end
  end
end
