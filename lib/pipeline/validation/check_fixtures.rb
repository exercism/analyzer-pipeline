module Pipeline::Validation
  class CheckFixtures
    include Mandate

    initialize_with :container_driver, :fixtures_folder

    def call
      exercise_folders = Dir.glob("#{fixtures_folder}/*")
      exercise_folders.each do |exercise_folder|
        exercise_slug = exercise_folder.split("/").last
        Dir.glob("#{exercise_folder}/*").each do |fixture_folder|
          validate_status(exercise_slug, fixture_folder)
        end
      end
    end

    def validate_status(exercise, fixture_folder)
      FileUtils.rm_rf("#{workdir}/iteration/")
      FileUtils.cp_r "#{fixture_folder}/iteration", "#{workdir}/iteration"

      container_driver.run_analyzer_for(exercise)

      analysis = JSON.parse(File.read("#{workdir}/iteration/analysis.json"))
      expected = JSON.parse(File.read("#{fixture_folder}/expected_analysis.json"))

      raise "Incorrect expected_status" if expected["status"].nil?

      if expected["status"] != analysis["status"]
        mismatch = "<#{analysis["status"]}> not <#{expected["status"]}>"
        msg = "Incorrect status (#{mismatch}) when validating #{fixture_folder}"
        err = FixtureCheckError.new(msg)
        raise err
      end
      expected["comments"] ||= []
      analysis["comments"] ||= []
      if expected["comments"].sort != analysis["comments"].sort
        msg = "Incorrect comments when validating #{fixture_folder}."
        msg += " Got: " + analysis["comments"].to_json
        raise FixtureCheckError.new(msg)
      end
    end

    def workdir
      container_driver.workdir
    end
  end
end
