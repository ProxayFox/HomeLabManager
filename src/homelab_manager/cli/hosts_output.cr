module HomeLabManager
  module CLI
    private def print_host_check_results(results : Array(ExecutionResult), io : IO) : Nil
      io.puts "Connectivity check: #{results.size} host(s)"

      results.each do |result|
        io.puts "- #{result.host_name}: #{result.status.to_s.downcase}"
        io.puts "  summary: #{result.summary}"
        if exit_code = result.exit_code
          io.puts "  exit_code: #{exit_code}"
        end
      end

      succeeded_count = results.count { |result| result.status == OperationStatus::Succeeded }
      failed_count = results.count { |result| result.status == OperationStatus::Failed }
      io.puts "Summary: #{succeeded_count} succeeded, #{failed_count} failed"
    end

    private def print_host_check_results_json(path : String, results : Array(ExecutionResult), selection : HostSelection, io : IO) : Nil
      JSON.build(io) do |json|
        json.object do
          json.field "type", "connectivity-check"
          json.field "path", path
          json.field "selection" do
            json.object do
              json.field "tags" do
                json.array do
                  selection.tags.each do |tag|
                    json.string(tag)
                  end
                end
              end
              json.field "groups" do
                json.array do
                  selection.groups.each do |group|
                    json.string(group)
                  end
                end
              end
            end
          end
          json.field "summary" do
            json.object do
              json.field "succeeded", results.count { |result| result.status == OperationStatus::Succeeded }
              json.field "failed", results.count { |result| result.status == OperationStatus::Failed }
            end
          end
          json.field "hosts" do
            json.array do
              results.each do |result|
                json.object do
                  json.field "host", result.host_name
                  json.field "status", result.status.to_s.downcase
                  json.field "exit_code", result.exit_code
                  json.field "summary", result.summary
                end
              end
            end
          end
        end
      end
      io.puts
    end
  end
end
