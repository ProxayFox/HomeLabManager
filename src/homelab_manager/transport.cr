module HomeLabManager
  abstract class Transport
    DEFAULT_CONNECT_TIMEOUT_SECONDS = 5

    abstract def probe(host : Host, timeout_seconds : Int32 = DEFAULT_CONNECT_TIMEOUT_SECONDS) : ExecutionResult
  end

  class SshTransport < Transport
    private SUCCESS_SUMMARY = "ssh connectivity ok"

    def probe(host : Host, timeout_seconds : Int32 = DEFAULT_CONNECT_TIMEOUT_SECONDS) : ExecutionResult
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      status = Process.run(
        "ssh",
        args: ssh_args(host, timeout_seconds),
        output: stdout,
        error: stderr,
      )

      summary = build_summary(stdout.to_s, stderr.to_s, status.success?)

      ExecutionResult.new(
        host.name,
        "connectivity_check",
        status.success? ? OperationStatus::Succeeded : OperationStatus::Failed,
        exit_code: status.exit_code,
        summary: summary,
      )
    rescue ex
      ExecutionResult.new(
        host.name,
        "connectivity_check",
        OperationStatus::Failed,
        summary: "ssh probe failed: #{ex.message}",
      )
    end

    private def ssh_args(host : Host, timeout_seconds : Int32) : Array(String)
      [
        "-o", "BatchMode=yes",
        "-o", "NumberOfPasswordPrompts=0",
        "-o", "StrictHostKeyChecking=ask",
        "-o", "ConnectTimeout=#{timeout_seconds}",
        "-p", host.port.to_s,
        "#{host.ssh_user}@#{host.address}",
        "true",
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
