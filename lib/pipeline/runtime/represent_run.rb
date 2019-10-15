module Pipeline::Runtime
  class RepresentRun < ContainerRun

    def args
      ["bin/generate.sh", exercise_slug, "/mnt/exercism-iteration/"]
    end

    def result
      File.read("#{iteration_folder}/representation.txt")
    end

    def working_directory
      "/opt/representer"
    end

  end
end
