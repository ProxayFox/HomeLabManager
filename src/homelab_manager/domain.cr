module HomeLabManager
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
