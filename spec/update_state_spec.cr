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
end
