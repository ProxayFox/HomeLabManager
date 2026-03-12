module HomeLabManager
  module Updates
    DEFAULT_STATE_PATH = "state/update-runs.json"

    struct RecoveryStateEntry
      include JSON::Serializable

      getter host_name : String
      getter failed_action : String
      getter updated_at : String
      getter summary : String?
      getter overall_status : String
      getter reboot_required : Bool?

      def initialize(
        @host_name : String,
        @failed_action : String,
        @updated_at : String = Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ"),
        @summary : String? = nil,
        @overall_status : String = "failed",
        @reboot_required : Bool? = nil,
      )
      end
    end

    struct RecoveryStateFile
      include JSON::Serializable

      getter version : Int32
      getter hosts : Array(RecoveryStateEntry)

      def initialize(@version : Int32 = 1, @hosts : Array(RecoveryStateEntry) = [] of RecoveryStateEntry)
      end
    end

    class StateStore
      getter path : String

      def initialize(@path : String = DEFAULT_STATE_PATH)
      end

      def resume_points(hosts : Array(Host)) : Hash(String, UpdateStepKind)
        entries = load.hosts
        points = {} of String => UpdateStepKind

        hosts.each do |host|
          next unless entry = entries.find { |candidate| candidate.host_name == host.name }

          points[host.name] = Updates.parse_resume_from(entry.failed_action)
        end

        points
      end

      def record_runs(runs : Array(UpdateRun)) : Nil
        entries = load.hosts.to_h { |entry| {entry.host_name, entry} }

        runs.each do |run|
          if failed_result = run.step_results.find { |result| result.status == OperationStatus::Failed }
            entries[run.host.name] = RecoveryStateEntry.new(
              run.host.name,
              failed_result.action,
              summary: failed_result.summary,
              overall_status: run.overall_status,
              reboot_required: run.reboot_required,
            )
          else
            entries.delete(run.host.name)
          end
        end

        sorted_entries = entries.values
        sorted_entries.sort_by!(&.host_name)
        persist(RecoveryStateFile.new(hosts: sorted_entries))
      end

      def load : RecoveryStateFile
        return RecoveryStateFile.new unless File.exists?(path)

        RecoveryStateFile.from_json(File.read(path))
      rescue ex : JSON::ParseException
        raise InventoryError.new(["update state file is invalid JSON: #{path}: #{ex.message}"])
      rescue ex : InventoryError
        raise ex
      rescue ex
        raise InventoryError.new(["unable to read update state file #{path}: #{ex.message}"])
      end

      private def persist(state : RecoveryStateFile) : Nil
        directory = File.dirname(path)
        Dir.mkdir_p(directory) unless Dir.exists?(directory)
        File.write(path, state.to_json + "\n")
      rescue ex
        raise InventoryError.new(["unable to write update state file #{path}: #{ex.message}"])
      end
    end
  end
end
