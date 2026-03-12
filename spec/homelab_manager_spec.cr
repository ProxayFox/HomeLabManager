require "./spec_helper"

describe HomeLabManager do
  it "exposes the project version" do
    HomeLabManager::VERSION.should eq("0.1.0")
  end
end
