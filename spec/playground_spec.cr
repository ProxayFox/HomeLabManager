require "./spec_helper"

describe Playground do
  it "exposes a version constant" do
    Playground::VERSION.should eq("0.1.0")
  end
end
