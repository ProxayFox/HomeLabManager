module HomeLabManager
  module Audit
    DEFAULT_LOG_PATH        = "logs/audit.log"
    private SENSITIVE_VALUE_PATTERN = /(password|passwd|token|secret)=\S+/i
    private MAX_FIELD_LENGTH        = 200

    abstract class Logger
      abstract def log(result : ExecutionResult, host : Host, step_label : String? = nil, command : String? = nil) : Nil
    end

    class NullLogger < Logger
      def log(result : ExecutionResult, host : Host, step_label : String? = nil, command : String? = nil) : Nil
      end
    end

    class FileLogger < Logger
      getter path : String
      getter operator_name : String

      def initialize(@path : String = DEFAULT_LOG_PATH, @operator_name : String = default_operator_name)
      end

      def log(result : ExecutionResult, host : Host, step_label : String? = nil, command : String? = nil) : Nil
        directory = File.dirname(path)
        Dir.mkdir_p(directory) unless Dir.exists?(directory)

        File.open(path, "a") do |file|
          file.puts(entry_json(result, host, step_label, command))
        end
      end

      private def entry_json(result : ExecutionResult, host : Host, step_label : String?, command : String?) : String
        JSON.build do |json|
          json.object do
            json.field "timestamp", Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ")
            json.field "operator", operator_name
            json.field "host", host.name
            json.field "address", host.address
            json.field "action", result.action
            json.field "step_label", sanitize(step_label)
            json.field "status", result.status.to_s.downcase
            json.field "approval_state", result.approval_state.to_s.downcase
            json.field "exit_code", result.exit_code
            json.field "command", sanitize(command)
            json.field "summary", sanitize(result.summary)
          end
        end
      end

      private def sanitize(value : String?) : String?
        return nil unless value

        sanitized = value
          .gsub(SENSITIVE_VALUE_PATTERN, "\\1=[REDACTED]")
          .gsub(/\s+/, " ")
          .strip

        return sanitized if sanitized.bytesize <= MAX_FIELD_LENGTH

        sanitized.byte_slice(0, MAX_FIELD_LENGTH) + "..."
      end

      private def default_operator_name : String
        ENV["USER"]? || ENV["USERNAME"]? || "unknown"
      end
    end
  end
end
