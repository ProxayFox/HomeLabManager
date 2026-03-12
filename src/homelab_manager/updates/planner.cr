module HomeLabManager
  module Updates
    extend self

    def build_plans(
      inventory : InventoryFile,
      hosts : Array(Host),
      approved : Bool,
      resume_from : UpdateStepKind? = nil,
      resume_points : Hash(String, UpdateStepKind)? = nil,
    ) : Array(UpdatePlan)
      hosts.map do |host|
        build_plan(host, inventory.defaults, approved, resume_from || resume_points.try(&.[host.name]?))
      end
    end

    def build_plan(host : Host, defaults : InventoryDefaults, approved : Bool, resume_from : UpdateStepKind? = nil) : UpdatePlan
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

      steps = apply_resume_from(steps, resume_from) if resume_from

      UpdatePlan.new(host, approval_state, approval_required, steps)
    end

    def parse_resume_from(value : String) : UpdateStepKind
      case value
      when "update_refresh_package_index", "refresh-package-index"
        UpdateStepKind::RefreshPackageIndex
      when "update_preview_upgrades", "preview-upgrades"
        UpdateStepKind::PreviewUpgrades
      when "update_apply_upgrades", "apply-upgrades"
        UpdateStepKind::ApplyUpgrades
      when "update_check_reboot_required", "check-reboot-required"
        UpdateStepKind::CheckRebootRequired
      else
        raise InventoryError.new(["unknown value for --resume-from: #{value}"])
      end
    end

    private def apply_resume_from(steps : Array(UpdateStep), resume_from : UpdateStepKind) : Array(UpdateStep)
      reached_resume_point = false

      steps.map do |step|
        if reached_resume_point
          step
        elsif step.kind == resume_from
          reached_resume_point = true
          step
        else
          UpdateStep.new(
            step.kind,
            step.label,
            step.command,
            step.mutating?,
            enabled: false,
            reason: "skipped before resume point",
          )
        end
      end
    end
  end
end
