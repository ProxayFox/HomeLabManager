module HomeLabManager
  module Connectivity
    extend self

    def check(inventory : InventoryFile, transport : Transport, timeout_seconds : Int32 = Transport::DEFAULT_CONNECT_TIMEOUT_SECONDS) : Array(ExecutionResult)
      inventory.hosts.map do |host|
        transport.probe(host, timeout_seconds)
      end
    end

    def succeeded?(results : Array(ExecutionResult)) : Bool
      results.all? { |result| result.status == OperationStatus::Succeeded }
    end
  end
end
