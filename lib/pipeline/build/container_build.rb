module Pipeline::Build
  class ContainerBuild
    include Mandate

    attr_accessor :img, :local_tag, :image_tag, :container_repo

    initialize_with :build_tag, :track_slug, :repo, :container_repo

    def call
      puts "Setting up utilities"
      setup_utilities
      setup_remote_repo
      fetch_code
      check_tag_exists
      if already_built?
        puts "already_built"
        return {
          status: "ignored",
          message: "Already built",
          track: track_slug,
          image: image_name,
          image_tag: image_tag
        }
      end
      build
      validate
      publish
      {
        status: "built",
        message: "Successfully built",
        track: track_slug,
        image: image_name,
        image_tag: image_tag,
        git_tag: build_tag,
        logs: img.logs.inspect
      }
    end

    def fetch_code
      repo.fetch!
    end

    def setup_utilities
      @logs = Pipeline::Util::LogCollector.new
      @img = Pipeline::Util::ImgWrapper.new(@logs)
    end

    def setup_remote_repo
      container_repo.create_if_required
    end

    def check_tag_exists
      return if build_tag == "master"
      return if repo.valid_commit?(build_tag)
      raise "Build tag does not exist" unless repo.tags[build_tag]
    end

    def already_built?
      puts "Already built?"
      puts "image_name: #{image_name}"
      puts "build_tag: #{build_tag}"
      puts "current: #{@container_repo.git_shas}"
      puts "repo: #{repo}"
      current_tags = @container_repo.git_shas
      target_sha = repo.checkout(build_tag)
      puts target_sha
      current_tags.include? target_sha
    end

    def build
      @local_tag = Pipeline::Build::BuildImage.(build_tag, image_name, repo, img)
      @image_tag = "#{image_name}:#{local_tag}"
    end

    def validate
    end

    def publish
      Pipeline::Build::PublishImage.(img, container_repo, local_tag, build_tag)
    end

    def image_name
      raise "Image not implemented"
    end
  end
end
