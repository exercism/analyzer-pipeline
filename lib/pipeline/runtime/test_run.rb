module Pipeline::Runtime
  class TestRun < ContainerRun

    def args
      ["bin/run.sh", exercise_slug, "/mnt/exercism-iteration/", "/mnt/exercism-iteration/"]
    end

    def result
      raw_results = File.read("#{iteration_folder}/results.json")
      JSON.parse(raw_results)
    end

    def working_directory
      "/opt/test-runner"
    end

  end
end
