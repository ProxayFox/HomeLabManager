module HomeLabManager
  enum UpdateStepKind
    RefreshPackageIndex
    PreviewUpgrades
    ApplyUpgrades
    CheckRebootRequired
  end

  struct UpdateStep
    getter kind : UpdateStepKind
    getter label : String
    getter command : String
    getter? mutating : Bool
    getter? enabled : Bool
    getter reason : String?

    def initialize(
      @kind : UpdateStepKind,
      @label : String,
      @command : String,
      @mutating : Bool,
      @enabled : Bool = true,
      @reason : String? = nil,
    )
    end
  end

  struct UpdatePlan
    getter host : Host
    getter approval_state : ApprovalState
    getter? approval_required : Bool
    getter steps : Array(UpdateStep)

    def initialize(
      @host : Host,
      @approval_state : ApprovalState,
      @approval_required : Bool,
      @steps : Array(UpdateStep),
    )
    end
  end

  module Updates
    extend self

    def build_plans(inventory : InventoryFile, hosts : Array(Host), approved : Bool) : Array(UpdatePlan)
      hosts.map do |host|
        build_plan(host, inventory.defaults, approved)
      end
    end

    def build_plan(host : Host, defaults : InventoryDefaults, approved : Bool) : UpdatePlan
      policy = host.effective_update(defaults)
      approval_required = policy.require_manual_approval?
      approval_state = approved || !approval_required ? ApprovalState::Approved : ApprovalState::Pending
      steps = [] of UpdateStep

      if policy.refresh_package_index?
        steps << UpdateStep.new(
          UpdateStepKind::RefreshPackageIndex,
          "refresh package index",
          "sudo apt-get update",
          false,
        )
      end

      if policy.preview_upgrades?
        steps << UpdateStep.new(
          UpdateStepKind::PreviewUpgrades,
          "preview upgrades",
          "sudo apt-get -s upgrade",
          false,
        )
      end

      apply_enabled = approved || !approval_required
      steps << UpdateStep.new(
        UpdateStepKind::ApplyUpgrades,
        "apply upgrades",
        "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y",
        true,
        enabled: apply_enabled,
        reason: apply_enabled ? nil : "manual approval required; rerun with --approve to mark this step approved",
      )

      steps << UpdateStep.new(
        UpdateStepKind::CheckRebootRequired,
        "check reboot-required flag",
        "test -f /var/run/reboot-required",
        false,
      )

      UpdatePlan.new(host, approval_state, approval_required, steps)
    end
  end
end
