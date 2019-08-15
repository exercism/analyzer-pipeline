class Pipeline::ValidateBuild
  include Mandate

  initialize_with :build_tag, :fixtures_folder

  def call
    unpack
    check_environment_is_invokable
    check_environment_invariants
    check_sample_solutions
  end

  def unpack
    container_driver.prepare_workdir
    container_driver.unpack_image(build_tag)
  end

  def check_environment_is_invokable
    Pipeline::Validation::CheckInvokable.(container_driver)
  end

  def check_environment_invariants
    Pipeline::Validation::CheckEnvironmentInvariants.(container_driver)
  end

  def check_sample_solutions
    Pipeline::Validation::CheckFixtures.(container_driver, fixtures_folder)
  end

  memoize
  def workdir
    "/tmp/analyzer-scratch/#{SecureRandom.uuid}"
  end

  memoize
  def container_driver
    img = Pipeline::Util::ImgWrapper.new
    runc = Pipeline::Util::RuncWrapper.new
    configurator = Pipeline::Util::RuncConfigurator.new
    configurator.seed_from_env
    Pipeline::Util::ContainerDriver.new(runc, img, configurator, workdir)
  end

end
