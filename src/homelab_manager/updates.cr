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

  struct UpdateRun
    getter host : Host
    getter approval_state : ApprovalState
    getter step_results : Array(ExecutionResult)

    def initialize(
      @host : Host,
      @approval_state : ApprovalState,
      @step_results : Array(ExecutionResult),
    )
    end

    def successful? : Bool
      step_results.none? { |result| result.status == OperationStatus::Failed }
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

    def dry_run(plans : Array(UpdatePlan), transport : Transport, audit_logger : Audit::Logger = Audit::NullLogger.new, timeout_seconds : Int32 = Transport::DEFAULT_COMMAND_TIMEOUT_SECONDS) : Array(UpdateRun)
      plans.map do |plan|
        step_results = plan.steps.map do |step|
          execute_dry_run_step(plan, step, transport, timeout_seconds).tap do |result|
            audit_logger.log(result, plan.host, step.label, step.command)
          end
        end

        UpdateRun.new(plan.host, plan.approval_state, step_results)
      end
    end

    def successful?(runs : Array(UpdateRun)) : Bool
      runs.all?(&.successful?)
    end

    private def execute_dry_run_step(plan : UpdatePlan, step : UpdateStep, transport : Transport, timeout_seconds : Int32) : ExecutionResult
      if step.mutating?
        summary = if reason = step.reason
                    "skipped in dry-run mode; #{reason}"
                  else
                    "skipped in dry-run mode; mutating steps are not executed"
                  end

        return ExecutionResult.new(
          plan.host.name,
          action_name(step.kind),
          OperationStatus::Skipped,
          approval_state: plan.approval_state,
          summary: summary,
        )
      end

      unless step.enabled?
        return ExecutionResult.new(
          plan.host.name,
          action_name(step.kind),
          OperationStatus::Skipped,
          approval_state: plan.approval_state,
          summary: step.reason || "step disabled",
        )
      end

      result = transport.run_command(plan.host, action_name(step.kind), step.command, timeout_seconds)
      ExecutionResult.new(
        result.host_name,
        result.action,
        result.status,
        approval_state: plan.approval_state,
        exit_code: result.exit_code,
        summary: result.summary,
      )
    end

    private def action_name(kind : UpdateStepKind) : String
      case kind
      when UpdateStepKind::RefreshPackageIndex
        "update_refresh_package_index"
      when UpdateStepKind::PreviewUpgrades
        "update_preview_upgrades"
      when UpdateStepKind::ApplyUpgrades
        "update_apply_upgrades"
      when UpdateStepKind::CheckRebootRequired
        "update_check_reboot_required"
      else
        raise "unsupported update step kind: #{kind}"
      end
    end
  end
end
