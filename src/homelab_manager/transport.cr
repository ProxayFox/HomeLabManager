module HomeLabManager
  abstract class Transport
    DEFAULT_CONNECT_TIMEOUT_SECONDS =  5
    DEFAULT_COMMAND_TIMEOUT_SECONDS = 30

    abstract def probe(host : Host, timeout_seconds : Int32 = DEFAULT_CONNECT_TIMEOUT_SECONDS) : ExecutionResult
    abstract def run_command(host : Host, action : String, command : String, timeout_seconds : Int32 = DEFAULT_COMMAND_TIMEOUT_SECONDS) : ExecutionResult
  end

  class SshTransport < Transport
    private SUCCESS_SUMMARY = "ssh connectivity ok"

    def probe(host : Host, timeout_seconds : Int32 = DEFAULT_CONNECT_TIMEOUT_SECONDS) : ExecutionResult
      run_command(host, "connectivity_check", "true", timeout_seconds)
    end

    def run_command(host : Host, action : String, command : String, timeout_seconds : Int32 = DEFAULT_COMMAND_TIMEOUT_SECONDS) : ExecutionResult
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      status = Process.run(
        "ssh",
        args: ssh_args(host, timeout_seconds, command),
        output: stdout,
        error: stderr,
      )

      summary = build_summary(stdout.to_s, stderr.to_s, status.success?)

      ExecutionResult.new(
        host.name,
        action,
        status.success? ? OperationStatus::Succeeded : OperationStatus::Failed,
        exit_code: status.exit_code,
        summary: summary,
      )
    rescue ex
      ExecutionResult.new(
        host.name,
        action,
        OperationStatus::Failed,
        summary: "ssh command failed: #{ex.message}",
      )
    end

    private def ssh_args(host : Host, timeout_seconds : Int32, command : String) : Array(String)
      [
        "-o", "BatchMode=yes",
        "-o", "NumberOfPasswordPrompts=0",
        "-o", "StrictHostKeyChecking=ask",
        "-o", "ConnectTimeout=#{timeout_seconds}",
        "-p", host.port.to_s,
        "#{host.ssh_user}@#{host.address}",
        command,
      ]
    end

    private def build_summary(stdout : String, stderr : String, success : Bool) : String
      message = [stderr, stdout]
        .flat_map(&.lines)
        .map(&.strip)
        .reject(&.empty?)
        .first?

      return SUCCESS_SUMMARY if success && message.nil?
      return message if message

      success ? SUCCESS_SUMMARY : "ssh connectivity failed"
    end
  end
end
