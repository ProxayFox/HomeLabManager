require "./spec_helper"

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

  it "can resume a plan from a later step" do
    inventory = HomeLabManager::Inventory.parse <<-YAML
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML

    plan = HomeLabManager::Updates.build_plans(
      inventory,
      inventory.hosts,
      true,
      HomeLabManager::UpdateStepKind::ApplyUpgrades,
    ).first

    plan.steps[0].enabled?.should be_false
    plan.steps[0].reason.should eq("skipped before resume point")
    plan.steps[2].enabled?.should be_true
  end

  it "parses supported resume aliases" do
    HomeLabManager::Updates.parse_resume_from("refresh-package-index").should eq(HomeLabManager::UpdateStepKind::RefreshPackageIndex)
    HomeLabManager::Updates.parse_resume_from("update_apply_upgrades").should eq(HomeLabManager::UpdateStepKind::ApplyUpgrades)
    HomeLabManager::Updates.parse_resume_from("check-reboot-required").should eq(HomeLabManager::UpdateStepKind::CheckRebootRequired)
  end

  it "rejects unknown resume aliases" do
    expect_raises(HomeLabManager::InventoryError, /unknown value for --resume-from/) do
      HomeLabManager::Updates.parse_resume_from("bogus-step")
    end
  end
end
