module HomeLabManager
  enum UpdateStepKind
    RefreshPackageIndex
    PreviewUpgrades
    ApplyUpgrades
    CheckRebootRequired
  end

  struct UpdateStep
    getter kind : UpdateStepKind
    getter label : String
    getter command : String
    getter? mutating : Bool
    getter? enabled : Bool
    getter reason : String?

    def initialize(
      @kind : UpdateStepKind,
      @label : String,
      @command : String,
      @mutating : Bool,
      @enabled : Bool = true,
      @reason : String? = nil,
    )
    end
  end

  struct UpdatePlan
    getter host : Host
    getter approval_state : ApprovalState
    getter? approval_required : Bool
    getter steps : Array(UpdateStep)

    def initialize(
      @host : Host,
      @approval_state : ApprovalState,
      @approval_required : Bool,
      @steps : Array(UpdateStep),
    )
    end
  end

  struct UpdateRun
    getter host : Host
    getter approval_state : ApprovalState
    getter step_results : Array(ExecutionResult)
    getter reboot_required : Bool?

    def initialize(
      @host : Host,
      @approval_state : ApprovalState,
      @step_results : Array(ExecutionResult),
      @reboot_required : Bool? = nil,
    )
    end

    def successful? : Bool
      step_results.none? { |result| result.status == OperationStatus::Failed }
    end

    def partially_failed? : Bool
      step_results.any? { |result| result.status == OperationStatus::Failed } &&
        step_results.any? { |result| result.status == OperationStatus::Succeeded || result.status == OperationStatus::Skipped }
    end

    def overall_status : String
      return "partial" if partially_failed?
      return "failed" unless successful?

      "succeeded"
    end
  end

  module Updates
    extend self
  end
end
