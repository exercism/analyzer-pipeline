module Pipeline::Build
  class BuildImage
    include Mandate

    attr_accessor :target_sha

    initialize_with :build_tag, :image_slug, :repo, :img

    def call
      repo.fetch!
      checkout
      build
      @target_sha
    end

    def checkout
      target_sha = repo.checkout(build_tag)
      @target_sha = "sha-#{target_sha}"
    end

    def build
      Dir.chdir(repo.workdir) do
        img.reset_hub_login
        img.build(local_tag)
      end
    end

    def local_tag
      "#{image_slug}:#{target_sha}"
    end
  end
end
