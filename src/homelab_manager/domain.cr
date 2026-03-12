module HomeLabManager
  struct HostSelection
    getter tags : Array(String)
    getter groups : Array(String)

    def initialize(@tags : Array(String) = [] of String, @groups : Array(String) = [] of String)
    end

    def empty? : Bool
      tags.empty? && groups.empty?
    end
  end

  enum ApprovalState
    Pending
    Approved
    Denied
  end

  enum OperationStatus
    Pending
    Succeeded
    Failed
    Skipped
  end

  struct ExecutionResult
    getter host_name : String
    getter action : String
    getter status : OperationStatus
    getter approval_state : ApprovalState
    getter exit_code : Int32?
    getter summary : String

    def initialize(
      @host_name : String,
      @action : String,
      @status : OperationStatus,
      @approval_state : ApprovalState = ApprovalState::Pending,
      @exit_code : Int32? = nil,
      @summary : String = "",
    )
    end
  end
end
