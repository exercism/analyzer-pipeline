module Pipeline::Build
  class AnalyzerBuild < ContainerBuild

    def image_name
      suffix = "-dev" unless ENV["env"] == "production"
      "#{track_slug}-analyzer#{suffix}"
    end
    
  end
end
