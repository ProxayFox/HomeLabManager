require "./spec_helper"

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
