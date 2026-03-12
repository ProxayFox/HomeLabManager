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
    getter reboot_required : Bool?

    def initialize(
      @host : Host,
      @approval_state : ApprovalState,
      @step_results : Array(ExecutionResult),
      @reboot_required : Bool? = nil,
    )
    end

    def successful? : Bool
      step_results.none? { |result| result.status == OperationStatus::Failed }
    end

    def partially_failed? : Bool
      step_results.any? { |result| result.status == OperationStatus::Failed } &&
        step_results.any? { |result| result.status == OperationStatus::Succeeded || result.status == OperationStatus::Skipped }
    end

    def overall_status : String
      return "partial" if partially_failed?
      return "failed" unless successful?

      "succeeded"
    end
  end

  module Updates
    extend self

    def build_plans(inventory : InventoryFile, hosts : Array(Host), approved : Bool, resume_from : UpdateStepKind? = nil) : Array(UpdatePlan)
      hosts.map do |host|
        build_plan(host, inventory.defaults, approved, resume_from)
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

      if resume_from
        steps = apply_resume_from(steps, resume_from)
      end

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

    def dry_run(plans : Array(UpdatePlan), transport : Transport, audit_logger : Audit::Logger = Audit::NullLogger.new, timeout_seconds : Int32 = Transport::DEFAULT_COMMAND_TIMEOUT_SECONDS) : Array(UpdateRun)
      run_plans(plans, transport, audit_logger, timeout_seconds, execute_mutating: false)
    end

    def execute(plans : Array(UpdatePlan), transport : Transport, audit_logger : Audit::Logger = Audit::NullLogger.new, timeout_seconds : Int32 = Transport::DEFAULT_COMMAND_TIMEOUT_SECONDS) : Array(UpdateRun)
      run_plans(plans, transport, audit_logger, timeout_seconds, execute_mutating: true)
    end

    def successful?(runs : Array(UpdateRun)) : Bool
      runs.all?(&.successful?)
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

    private def run_plans(plans : Array(UpdatePlan), transport : Transport, audit_logger : Audit::Logger, timeout_seconds : Int32, execute_mutating : Bool) : Array(UpdateRun)
      plans.map do |plan|
        step_results = [] of ExecutionResult
        reboot_required = nil.as(Bool?)
        halted = false

        plan.steps.each do |step|
          result, reboot_required, halted = execute_step(
            plan,
            step,
            transport,
            timeout_seconds,
            execute_mutating,
            halted,
            reboot_required,
          )

          step_results << result
          audit_logger.log(result, plan.host, step.label, step.command)
        end

        UpdateRun.new(plan.host, plan.approval_state, step_results, reboot_required)
      end
    end

    private def execute_step(
      plan : UpdatePlan,
      step : UpdateStep,
      transport : Transport,
      timeout_seconds : Int32,
      execute_mutating : Bool,
      halted : Bool,
      reboot_required : Bool?,
    ) : Tuple(ExecutionResult, Bool?, Bool)
      if halted
        return {
          skipped_result(plan, step, "skipped after previous step failure"),
          reboot_required,
          true,
        }
      end

      if step.mutating? && !execute_mutating
        summary = if reason = step.reason
                    "skipped in dry-run mode; #{reason}"
                  else
                    "skipped in dry-run mode; mutating steps are not executed"
                  end

        return {
          skipped_result(plan, step, summary),
          reboot_required,
          false,
        }
      end

      unless step.enabled?
        return {
          skipped_result(plan, step, step.reason || "step disabled"),
          reboot_required,
          false,
        }
      end

      result = transport.run_command(plan.host, action_name(step.kind), step.command, timeout_seconds)
      normalized_result, next_reboot_required = normalize_result(plan, step, result, reboot_required)

      {
        normalized_result,
        next_reboot_required,
        normalized_result.status == OperationStatus::Failed,
      }
    end

    private def skipped_result(plan : UpdatePlan, step : UpdateStep, summary : String, exit_code : Int32? = nil) : ExecutionResult
      ExecutionResult.new(
        plan.host.name,
        action_name(step.kind),
        OperationStatus::Skipped,
        approval_state: plan.approval_state,
        exit_code: exit_code,
        summary: summary,
      )
    end

    private def normalize_result(plan : UpdatePlan, step : UpdateStep, result : ExecutionResult, reboot_required : Bool?) : Tuple(ExecutionResult, Bool?)
      return {result_with_approval(plan, result), reboot_required} unless step.kind == UpdateStepKind::CheckRebootRequired

      case result.exit_code
      when 0
        {
          ExecutionResult.new(
            result.host_name,
            result.action,
            OperationStatus::Succeeded,
            approval_state: plan.approval_state,
            exit_code: result.exit_code,
            summary: "reboot required",
          ),
          true,
        }
      when 1
        {
          ExecutionResult.new(
            result.host_name,
            result.action,
            OperationStatus::Succeeded,
            approval_state: plan.approval_state,
            exit_code: result.exit_code,
            summary: "reboot not required",
          ),
          false,
        }
      else
        {result_with_approval(plan, result), reboot_required}
      end
    end

    private def result_with_approval(plan : UpdatePlan, result : ExecutionResult) : ExecutionResult
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
