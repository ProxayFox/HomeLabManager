require "spec"

describe "Ameba" do
  it "passes static analysis" do
    project_root = File.expand_path("..", __DIR__)
    output = IO::Memory.new

    begin
      status = Process.run(
        "ameba",
        ["--config", ".ameba.yml"],
        output: output,
        error: output,
        chdir: project_root,
      )

      raise "Ameba failed:\n#{output}" unless status.success?
    rescue ex : File::NotFoundError
      raise "Ameba binary not found in PATH. Rebuild the devcontainer or install Ameba. #{ex.message}"
    end
  end
end
