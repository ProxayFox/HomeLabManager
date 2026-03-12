require "./spec_helper"

describe HomeLabManager::Updates do
  it "executes only non-mutating dry-run steps and skips apply upgrades" do
    inventory = HomeLabManager::Inventory.parse <<-YAML
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML

    plan = HomeLabManager::Updates.build_plans(inventory, inventory.hosts, false)
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
          summary: "2 packages can be upgraded",
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

    runs = HomeLabManager::Updates.dry_run(plan, transport, HomeLabManager::Audit::NullLogger.new)
    apply_step = runs.first.step_results.find! { |result| result.action == "update_apply_upgrades" }

    runs.first.successful?.should be_true
    apply_step.status.should eq(HomeLabManager::OperationStatus::Skipped)
    apply_step.summary.should contain("dry-run mode")
  end

  it "executes approved mutating steps and reports reboot-required state" do
    inventory = HomeLabManager::Inventory.parse <<-YAML
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML

    plans = HomeLabManager::Updates.build_plans(inventory, inventory.hosts, true)
    transport = FakeTransport.new(
      command_results: {
        "atlas|update_refresh_package_index" => HomeLabManager::ExecutionResult.new(
          "atlas", "update_refresh_package_index", HomeLabManager::OperationStatus::Succeeded, exit_code: 0, summary: "package lists refreshed"),
        "atlas|update_preview_upgrades" => HomeLabManager::ExecutionResult.new(
          "atlas", "update_preview_upgrades", HomeLabManager::OperationStatus::Succeeded, exit_code: 0, summary: "2 packages can be upgraded"),
        "atlas|update_apply_upgrades" => HomeLabManager::ExecutionResult.new(
          "atlas", "update_apply_upgrades", HomeLabManager::OperationStatus::Succeeded, exit_code: 0, summary: "packages upgraded"),
        "atlas|update_check_reboot_required" => HomeLabManager::ExecutionResult.new(
          "atlas", "update_check_reboot_required", HomeLabManager::OperationStatus::Failed, exit_code: 0, summary: "flag present"),
      },
    )

    runs = HomeLabManager::Updates.execute(plans, transport, HomeLabManager::Audit::NullLogger.new)
    apply_step = runs.first.step_results.find! { |result| result.action == "update_apply_upgrades" }

    runs.first.successful?.should be_true
    runs.first.reboot_required.should eq(true)
    apply_step.status.should eq(HomeLabManager::OperationStatus::Succeeded)
  end

  it "can resume execution from apply upgrades" do
    inventory = HomeLabManager::Inventory.parse <<-YAML
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML

    plans = HomeLabManager::Updates.build_plans(
      inventory,
      inventory.hosts,
      true,
      HomeLabManager::UpdateStepKind::ApplyUpgrades,
    )
    transport = FakeTransport.new(
      command_results: {
        "atlas|update_apply_upgrades" => HomeLabManager::ExecutionResult.new(
          "atlas", "update_apply_upgrades", HomeLabManager::OperationStatus::Succeeded, exit_code: 0, summary: "packages upgraded"),
        "atlas|update_check_reboot_required" => HomeLabManager::ExecutionResult.new(
          "atlas", "update_check_reboot_required", HomeLabManager::OperationStatus::Failed, exit_code: 1, summary: "flag absent"),
      },
    )

    runs = HomeLabManager::Updates.execute(plans, transport, HomeLabManager::Audit::NullLogger.new)

    runs.first.step_results[0].status.should eq(HomeLabManager::OperationStatus::Skipped)
    runs.first.step_results[2].status.should eq(HomeLabManager::OperationStatus::Succeeded)
    runs.first.reboot_required.should eq(false)
  end

  it "skips remaining update steps after a host failure" do
    inventory = HomeLabManager::Inventory.parse <<-YAML
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML

    plans = HomeLabManager::Updates.build_plans(inventory, inventory.hosts, true)
    transport = FakeTransport.new(
      command_results: {
        "atlas|update_refresh_package_index" => HomeLabManager::ExecutionResult.new(
          "atlas", "update_refresh_package_index", HomeLabManager::OperationStatus::Failed, exit_code: 100, summary: "apt failed"),
      },
    )

    runs = HomeLabManager::Updates.execute(plans, transport, HomeLabManager::Audit::NullLogger.new)
    preview_step = runs.first.step_results.find! { |result| result.action == "update_preview_upgrades" }

    runs.first.successful?.should be_false
    runs.first.partially_failed?.should be_true
    preview_step.status.should eq(HomeLabManager::OperationStatus::Skipped)
    preview_step.summary.should contain("previous step failure")
  end

  it "runs update steps sequentially and passes the configured command timeout" do
    inventory = HomeLabManager::Inventory.parse <<-YAML
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML

    plans = HomeLabManager::Updates.build_plans(inventory, inventory.hosts, true)
    transport = FakeTransport.new(
      command_results: {
        "atlas|update_refresh_package_index" => HomeLabManager::ExecutionResult.new(
          "atlas", "update_refresh_package_index", HomeLabManager::OperationStatus::Succeeded, exit_code: 0, summary: "package lists refreshed"),
        "atlas|update_preview_upgrades" => HomeLabManager::ExecutionResult.new(
          "atlas", "update_preview_upgrades", HomeLabManager::OperationStatus::Succeeded, exit_code: 0, summary: "preview ok"),
        "atlas|update_apply_upgrades" => HomeLabManager::ExecutionResult.new(
          "atlas", "update_apply_upgrades", HomeLabManager::OperationStatus::Succeeded, exit_code: 0, summary: "packages upgraded"),
        "atlas|update_check_reboot_required" => HomeLabManager::ExecutionResult.new(
          "atlas", "update_check_reboot_required", HomeLabManager::OperationStatus::Failed, exit_code: 1, summary: "flag absent"),
      },
    )

    HomeLabManager::Updates.execute(plans, transport, HomeLabManager::Audit::NullLogger.new, timeout_seconds: 42)

    transport.command_invocations.map(&.action).should eq([
      "update_refresh_package_index",
      "update_preview_upgrades",
      "update_apply_upgrades",
      "update_check_reboot_required",
    ])
    transport.command_invocations.map(&.timeout_seconds).should eq([42, 42, 42, 42])
  end

  it "writes sanitized audit log entries for dry runs" do
    with_temp_working_directory do |path|
      inventory = HomeLabManager::Inventory.parse <<-YAML
        hosts:
          - name: atlas
            address: 192.168.1.10
            ssh_user: ubuntu
      YAML

      plans = HomeLabManager::Updates.build_plans(inventory, inventory.hosts, false)
      logger = HomeLabManager::Audit::FileLogger.new(File.join(path, "logs", "audit.log"), "tester")
      transport = FakeTransport.new(
        command_results: {
          "atlas|update_refresh_package_index" => HomeLabManager::ExecutionResult.new(
            "atlas",
            "update_refresh_package_index",
            HomeLabManager::OperationStatus::Succeeded,
            exit_code: 0,
            summary: "token=abc123 package lists refreshed",
          ),
          "atlas|update_preview_upgrades" => HomeLabManager::ExecutionResult.new(
            "atlas",
            "update_preview_upgrades",
            HomeLabManager::OperationStatus::Succeeded,
            exit_code: 0,
            summary: "preview ok",
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

      HomeLabManager::Updates.dry_run(plans, transport, logger)

      audit_log = File.read(File.join(path, "logs", "audit.log"))
      audit_log.should contain("token=[REDACTED]")
      audit_log.should_not contain("token=abc123")
      audit_log.should contain("\"operator\":\"tester\"")
    end
  end
end
