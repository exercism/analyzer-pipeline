module Pipeline::Runtime
  class AnalysisRun < ContainerRun

    def args
      ["bin/analyze.sh", exercise_slug, "/mnt/exercism-iteration/"]
    end

    def result
      File.read("#{iteration_folder}/analysis.json")
    end

    def working_directory
      "/opt/analyzer"
    end

  end
end
