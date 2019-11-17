module Pipeline::Build
  class RepresenterBuild < ContainerBuild

    def image_name
      suffix = "-dev" unless ENV["env"] == "production"
      "#{track_slug}-representer#{suffix}"
    end

    def validate
      # No validation implemented for this yet
      # Pipeline::Validation::ValidateBuild.(image_tag, "fixtures/#{track_slug}")
    end

  end
end
