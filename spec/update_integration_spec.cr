require "./spec_helper"

if ENV["HOMELAB_MANAGER_ENABLE_INTEGRATION_SPECS"]? == "1"
  describe "HomeLabManager integration updates" do
    it "runs updates plan and dry-run against a safe integration inventory" do
      inventory_path = ENV["HOMELAB_MANAGER_INTEGRATION_INVENTORY"]? || raise "HOMELAB_MANAGER_INTEGRATION_INVENTORY is required when integration specs are enabled"
      inventory = HomeLabManager::Inventory.load(inventory_path)
      transport = HomeLabManager::SshTransport.new

      plans = HomeLabManager::Updates.build_plans(inventory, inventory.hosts, false)
      plans.should_not be_empty

      runs = HomeLabManager::Updates.dry_run(
        plans,
        transport,
        HomeLabManager::Audit::NullLogger.new,
      )

      runs.size.should eq(plans.size)
      runs.each do |run|
        run.step_results.should_not be_empty
      end
    end
  end
end
