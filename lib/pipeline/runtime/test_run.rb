module Pipeline::Runtime
  class TestRun < ContainerRun

    def args
      ["bin/run.sh", exercise_slug, "/mnt/exercism-iteration/", "/mnt/exercism-iteration/"]
    end

    def result
      File.read("#{iteration_folder}/results.json")
    end

    def working_directory
      "/opt/test-runner"
    end

  end
end
