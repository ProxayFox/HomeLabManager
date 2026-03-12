require "./spec_helper"

describe HomeLabManager::Updates::StateStore do
  it "stores failed host runs as resume points" do
    with_temp_working_directory do |path|
      state_store = HomeLabManager::Updates::StateStore.new(File.join(path, "state", "update-runs.json"))
      host = HomeLabManager::Inventory.parse(<<-YAML).hosts.first
        hosts:
          - name: atlas
            address: 192.168.1.10
            ssh_user: ubuntu
      YAML
      run = HomeLabManager::UpdateRun.new(
        host,
        HomeLabManager::ApprovalState::Approved,
        [
          HomeLabManager::ExecutionResult.new(
            host.name,
            "update_refresh_package_index",
            HomeLabManager::OperationStatus::Succeeded,
            approval_state: HomeLabManager::ApprovalState::Approved,
            exit_code: 0,
            summary: "package lists refreshed",
          ),
          HomeLabManager::ExecutionResult.new(
            host.name,
            "update_apply_upgrades",
            HomeLabManager::OperationStatus::Failed,
            approval_state: HomeLabManager::ApprovalState::Approved,
            exit_code: 100,
            summary: "apt failed",
          ),
        ],
        false,
      )

      state_store.record_runs([run])

      state_store.resume_points([host])[host.name].should eq(HomeLabManager::UpdateStepKind::ApplyUpgrades)
      File.read(state_store.path).should contain("update_apply_upgrades")
    end
  end

  it "clears stored recovery state after a successful rerun" do
    with_temp_working_directory do |path|
      state_store = HomeLabManager::Updates::StateStore.new(File.join(path, "state", "update-runs.json"))
      host = HomeLabManager::Inventory.parse(<<-YAML).hosts.first
        hosts:
          - name: atlas
            address: 192.168.1.10
            ssh_user: ubuntu
      YAML

      state_store.record_runs([
        HomeLabManager::UpdateRun.new(
          host,
          HomeLabManager::ApprovalState::Approved,
          [
            HomeLabManager::ExecutionResult.new(
              host.name,
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

      state_store.record_runs([
        HomeLabManager::UpdateRun.new(
          host,
          HomeLabManager::ApprovalState::Approved,
          [
            HomeLabManager::ExecutionResult.new(
              host.name,
              "update_apply_upgrades",
              HomeLabManager::OperationStatus::Succeeded,
              approval_state: HomeLabManager::ApprovalState::Approved,
              exit_code: 0,
              summary: "packages upgraded",
            ),
            HomeLabManager::ExecutionResult.new(
              host.name,
              "update_check_reboot_required",
              HomeLabManager::OperationStatus::Succeeded,
              approval_state: HomeLabManager::ApprovalState::Approved,
              exit_code: 1,
              summary: "reboot not required",
            ),
          ],
          false,
        ),
      ])

      state_store.resume_points([host]).should be_empty
      state_store.load.hosts.should be_empty
    end
  end

  it "clears only the recovered host when multiple hosts have persisted state" do
    with_temp_working_directory do |path|
      state_store = HomeLabManager::Updates::StateStore.new(File.join(path, "state", "update-runs.json"))
      inventory = HomeLabManager::Inventory.parse(<<-YAML)
        hosts:
          - name: atlas
            address: 192.168.1.10
            ssh_user: ubuntu
          - name: backup
            address: 192.168.1.11
            ssh_user: ubuntu
      YAML
      atlas = inventory.hosts[0]
      backup = inventory.hosts[1]

      state_store.record_runs([
        HomeLabManager::UpdateRun.new(
          atlas,
          HomeLabManager::ApprovalState::Approved,
          [
            HomeLabManager::ExecutionResult.new(
              atlas.name,
              "update_apply_upgrades",
              HomeLabManager::OperationStatus::Failed,
              approval_state: HomeLabManager::ApprovalState::Approved,
              exit_code: 100,
              summary: "atlas failed",
            ),
          ],
          false,
        ),
        HomeLabManager::UpdateRun.new(
          backup,
          HomeLabManager::ApprovalState::Approved,
          [
            HomeLabManager::ExecutionResult.new(
              backup.name,
              "update_apply_upgrades",
              HomeLabManager::OperationStatus::Failed,
              approval_state: HomeLabManager::ApprovalState::Approved,
              exit_code: 100,
              summary: "backup failed",
            ),
          ],
          false,
        ),
      ])

      state_store.record_runs([
        HomeLabManager::UpdateRun.new(
          atlas,
          HomeLabManager::ApprovalState::Approved,
          [
            HomeLabManager::ExecutionResult.new(
              atlas.name,
              "update_apply_upgrades",
              HomeLabManager::OperationStatus::Succeeded,
              approval_state: HomeLabManager::ApprovalState::Approved,
              exit_code: 0,
              summary: "atlas recovered",
            ),
          ],
          false,
        ),
      ])

      state_store.resume_points([atlas, backup]).keys.should eq([backup.name])
      state_store.recovery_entries([atlas, backup]).keys.should eq([backup.name])
      File.read(state_store.path).should contain("backup")
      File.read(state_store.path).should_not contain("atlas failed")
    end
  end
end
