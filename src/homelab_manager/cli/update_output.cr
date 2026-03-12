module HomeLabManager
  module CLI
    private def print_update_plans(plans : Array(UpdatePlan), io : IO) : Nil
      io.puts "Update plan: #{plans.size} host(s)"

      plans.each do |plan|
        io.puts "- #{plan.host.name}"
        io.puts "  approval_state: #{plan.approval_state.to_s.downcase}"
        io.puts "  approval_required: #{plan.approval_required?}"

        plan.steps.each do |step|
          status = step.enabled? ? "ready" : "blocked"
          io.puts "  step: #{step.label} [#{status}]"
          io.puts "    command: #{step.command}"
          if reason = step.reason
            io.puts "    reason: #{reason}"
          end
        end
      end
    end

    private def print_update_runs(title : String, runs : Array(UpdateRun), io : IO) : Nil
      io.puts "#{title}: #{runs.size} host(s)"

      runs.each do |run|
        io.puts "- #{run.host.name}"
        io.puts "  overall_status: #{run.overall_status}"
        io.puts "  approval_state: #{run.approval_state.to_s.downcase}"
        io.puts "  reboot_required: #{run.reboot_required}" unless run.reboot_required.nil?

        run.step_results.each do |result|
          io.puts "  action: #{result.action} [#{result.status.to_s.downcase}]"
          io.puts "    summary: #{result.summary}"
          if exit_code = result.exit_code
            io.puts "    exit_code: #{exit_code}"
          end
        end
      end

      succeeded_count = runs.count(&.successful?)
      partial_count = runs.count(&.partially_failed?)
      failed_count = runs.size - succeeded_count - partial_count
      io.puts "Summary: #{succeeded_count} succeeded, #{partial_count} partial, #{failed_count} failed"
    end

    private def print_update_plans_json(plans : Array(UpdatePlan), io : IO, recovery_entries : Hash(String, Updates::RecoveryStateEntry) = {} of String => Updates::RecoveryStateEntry) : Nil
      JSON.build(io) do |json|
        json.object do
          json.field "type", "update-plan"
          json.field "hosts" do
            json.array do
              plans.each do |plan|
                json.object do
                  json.field "host", plan.host.name
                  json.field "resume_context" do
                    print_resume_context_json(json, recovery_entries[plan.host.name]?)
                  end
                  json.field "approval_state", plan.approval_state.to_s.downcase
                  json.field "approval_required", plan.approval_required?
                  json.field "steps" do
                    json.array do
                      plan.steps.each do |step|
                        json.object do
                          json.field "kind", step.kind.to_s.underscore
                          json.field "label", step.label
                          json.field "command", step.command
                          json.field "mutating", step.mutating?
                          json.field "enabled", step.enabled?
                          json.field "reason", step.reason
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
      io.puts
    end

    private def print_update_runs_json(mode : String, runs : Array(UpdateRun), io : IO, recovery_entries : Hash(String, Updates::RecoveryStateEntry) = {} of String => Updates::RecoveryStateEntry) : Nil
      JSON.build(io) do |json|
        json.object do
          json.field "type", "update-#{mode}"
          json.field "summary" do
            json.object do
              json.field "succeeded", runs.count(&.successful?)
              json.field "partial", runs.count(&.partially_failed?)
              json.field "failed", runs.size - runs.count(&.successful?) - runs.count(&.partially_failed?)
            end
          end
          json.field "hosts" do
            json.array do
              runs.each do |run|
                json.object do
                  json.field "host", run.host.name
                  json.field "resume_context" do
                    print_resume_context_json(json, recovery_entries[run.host.name]?)
                  end
                  json.field "overall_status", run.overall_status
                  json.field "approval_state", run.approval_state.to_s.downcase
                  json.field "reboot_required", run.reboot_required
                  json.field "steps" do
                    json.array do
                      run.step_results.each do |result|
                        json.object do
                          json.field "action", result.action
                          json.field "status", result.status.to_s.downcase
                          json.field "approval_state", result.approval_state.to_s.downcase
                          json.field "exit_code", result.exit_code
                          json.field "summary", result.summary
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
      io.puts
    end

    private def print_resume_context_json(json : JSON::Builder, entry : Updates::RecoveryStateEntry?) : Nil
      if entry
        json.object do
          json.field "source", "persisted"
          json.field "resume_from", entry.failed_action
          json.field "updated_at", entry.updated_at
          json.field "summary", entry.summary
          json.field "overall_status", entry.overall_status
          json.field "reboot_required", entry.reboot_required
        end
      else
        json.null
      end
    end
  end
end
