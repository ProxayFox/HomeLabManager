module HomeLabManager
  module Updates
    extend self

    def dry_run(plans : Array(UpdatePlan), transport : Transport, audit_logger : Audit::Logger = Audit::NullLogger.new, timeout_seconds : Int32 = Transport::DEFAULT_COMMAND_TIMEOUT_SECONDS) : Array(UpdateRun)
      run_plans(plans, transport, audit_logger, timeout_seconds, execute_mutating: false)
    end

    def execute(plans : Array(UpdatePlan), transport : Transport, audit_logger : Audit::Logger = Audit::NullLogger.new, timeout_seconds : Int32 = Transport::DEFAULT_COMMAND_TIMEOUT_SECONDS) : Array(UpdateRun)
      run_plans(plans, transport, audit_logger, timeout_seconds, execute_mutating: true)
    end

    def successful?(runs : Array(UpdateRun)) : Bool
      runs.all?(&.successful?)
    end

    def action_name(kind : UpdateStepKind) : String
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
  end
end
