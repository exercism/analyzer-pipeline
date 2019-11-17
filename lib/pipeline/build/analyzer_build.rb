module Pipeline::Build
  class AnalyzerBuild < ContainerBuild

    def image_name
      suffix = "-dev" unless ENV["env"] == "production"
      "#{track_slug}-analyzer#{suffix}"
    end

    def validate
      Pipeline::Validation::ValidateBuild.(image_tag, "fixtures/#{track_slug}")
    end

  end
end
