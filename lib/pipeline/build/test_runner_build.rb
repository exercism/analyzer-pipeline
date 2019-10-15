module Pipeline::Build
  class TestRunnerBuild < ContainerBuild

    def image_name
      suffix = "-dev" unless ENV["env"] == "production"
      "#{track_slug}-test-runner#{suffix}"
    end

    def validate
      # No validation implemented for this yet
      # Pipeline::Validation::ValidateBuild.(image_tag, "fixtures/#{track_slug}")
    end

  end
end
