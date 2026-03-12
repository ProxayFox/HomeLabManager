require "./spec_helper"

describe HomeLabManager::CLI do
  it "checks host connectivity through the transport boundary" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
        - name: backup
          address: backup.internal
          ssh_user: admin
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      transport = FakeTransport.new(
        {
          "atlas" => HomeLabManager::ExecutionResult.new(
            "atlas",
            "connectivity_check",
            HomeLabManager::OperationStatus::Succeeded,
            exit_code: 0,
            summary: "ssh connectivity ok",
          ),
          "backup" => HomeLabManager::ExecutionResult.new(
            "backup",
            "connectivity_check",
            HomeLabManager::OperationStatus::Failed,
            exit_code: 255,
            summary: "connection refused",
          ),
        },
      )

      exit_code = HomeLabManager::CLI.run(["hosts", "check", path], stdout, stderr, transport)

      exit_code.should eq(1)
      stdout.to_s.should contain("- atlas: succeeded")
      stdout.to_s.should contain("- backup: failed")
      stdout.to_s.should contain("Summary: 1 succeeded, 1 failed")
      stderr.to_s.should eq("")
    end
  end

  it "renders connectivity checks as json" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      transport = FakeTransport.new(
        {
          "atlas" => HomeLabManager::ExecutionResult.new(
            "atlas",
            "connectivity_check",
            HomeLabManager::OperationStatus::Succeeded,
            exit_code: 0,
            summary: "ssh connectivity ok",
          ),
        },
      )

      exit_code = HomeLabManager::CLI.run(["hosts", "check", path, "--json"], stdout, stderr, transport)

      exit_code.should eq(0)
      stdout.to_s.should contain("\"type\":\"connectivity-check\"")
      stdout.to_s.should contain("\"host\":\"atlas\"")
      stdout.to_s.should contain("\"succeeded\":1")
      stderr.to_s.should eq("")
    end
  end

  it "uses the default inventory path for host checks" do
    with_temp_working_directory do |path|
      Dir.mkdir(File.join(path, "config"))
      File.write(
        File.join(path, HomeLabManager::CLI::DEFAULT_INVENTORY_PATH),
        <<-YAML
          hosts:
            - name: atlas
              address: 192.168.1.10
              ssh_user: ubuntu
        YAML
      )

      stdout = IO::Memory.new
      stderr = IO::Memory.new
      transport = FakeTransport.new(
        {
          "atlas" => HomeLabManager::ExecutionResult.new(
            "atlas",
            "connectivity_check",
            HomeLabManager::OperationStatus::Succeeded,
            exit_code: 0,
            summary: "ssh connectivity ok",
          ),
        },
      )

      exit_code = HomeLabManager::CLI.run(["hosts", "check"], stdout, stderr, transport)

      exit_code.should eq(0)
      stdout.to_s.should contain("Connectivity check: 1 host(s)")
      stdout.to_s.should contain("Summary: 1 succeeded, 0 failed")
      stderr.to_s.should eq("")
    end
  end

  it "filters host checks by group" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
          groups: [lab]
        - name: backup
          address: backup.internal
          ssh_user: admin
          groups: [backup]
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      transport = FakeTransport.new(
        {
          "atlas" => HomeLabManager::ExecutionResult.new(
            "atlas",
            "connectivity_check",
            HomeLabManager::OperationStatus::Succeeded,
            exit_code: 0,
            summary: "ssh connectivity ok",
          ),
        },
      )

      exit_code = HomeLabManager::CLI.run(["hosts", "check", path, "--group", "lab"], stdout, stderr, transport)

      exit_code.should eq(0)
      stdout.to_s.should contain("- atlas: succeeded")
      stdout.to_s.should_not contain("backup")
      stderr.to_s.should eq("")
    end
  end

  it "renders empty host selection as json" do
    with_temp_inventory <<-YAML do |path|
      hosts:
        - name: atlas
          address: 192.168.1.10
          ssh_user: ubuntu
          groups: [lab]
    YAML
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      transport = FakeTransport.new

      exit_code = HomeLabManager::CLI.run(["hosts", "check", path, "--group", "missing", "--json"], stdout, stderr, transport)

      exit_code.should eq(1)
      stdout.to_s.should eq("")
      stderr.to_s.should contain("\"category\":\"selection\"")
      stderr.to_s.should contain("\"command\":\"hosts\"")
      stderr.to_s.should contain("no hosts matched the requested filters")
    end
  end
end
