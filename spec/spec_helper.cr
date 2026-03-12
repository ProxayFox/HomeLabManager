require "spec"
require "../src/homelab_manager/app"

def with_temp_inventory(contents : String, &)
  path = File.tempname("homelab-manager", ".yml")
  File.write(path, contents)

  begin
    yield path
  ensure
    File.delete(path) if File.exists?(path)
  end
end

def with_temp_working_directory(&)
  path = File.tempname("homelab-manager-dir")
  File.delete(path) if File.exists?(path)
  Dir.mkdir(path)

  previous = Dir.current

  begin
    Dir.cd(path)
    yield path
  ensure
    Dir.cd(previous)
    Dir.glob(File.join(path, "**", "*")).sort.reverse_each do |entry|
      if File.directory?(entry)
        Dir.delete(entry)
      else
        File.delete(entry)
      end
    end
    Dir.delete(path) if Dir.exists?(path)
  end
end

class FakeTransport < HomeLabManager::Transport
  def initialize(
    @probe_results : Hash(String, HomeLabManager::ExecutionResult) = {} of String => HomeLabManager::ExecutionResult,
    @command_results : Hash(String, HomeLabManager::ExecutionResult) = {} of String => HomeLabManager::ExecutionResult,
  )
  end

  def probe(host : HomeLabManager::Host, timeout_seconds : Int32 = DEFAULT_CONNECT_TIMEOUT_SECONDS) : HomeLabManager::ExecutionResult
    @probe_results[host.name]? || HomeLabManager::ExecutionResult.new(
      host.name,
      "connectivity_check",
      HomeLabManager::OperationStatus::Failed,
      exit_code: 255,
      summary: "missing fake result for #{host.name}",
    )
  end

  def run_command(host : HomeLabManager::Host, action : String, command : String, timeout_seconds : Int32 = DEFAULT_COMMAND_TIMEOUT_SECONDS) : HomeLabManager::ExecutionResult
    @command_results["#{host.name}|#{action}"]? || HomeLabManager::ExecutionResult.new(
      host.name,
      action,
      HomeLabManager::OperationStatus::Failed,
      exit_code: 127,
      summary: "missing fake command result for #{host.name} #{action}",
    )
  end
end
