require "./spec_helper"

describe "project file length" do
  it "keeps Crystal project files at or below 800 lines" do
    offenders = (Dir.glob("src/**/*.cr") + Dir.glob("spec/**/*.cr")).sort.compact_map do |path|
      line_count = File.read_lines(path).size
      next if line_count <= 800
      "#{path} (#{line_count} lines)"
    end

    raise "Expected all Crystal project files to be at or below 800 lines:\n#{offenders.join("\n")}" unless offenders.empty?
  end
end
