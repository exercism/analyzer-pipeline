module Pipeline::Validation
  class CheckFixtures
    include Mandate

    initialize_with :container_driver, :fixtures_folder

    def call
      clean_and_setup
      exercise_folders = Dir.glob("#{fixtures_folder}/*")
      exercise_folders.each do |exercise_folder|
        exercise_slug = exercise_folder.split("/").last
        Dir.glob("#{exercise_folder}/*").each do |fixture_folder|
          validate_status(exercise_slug, fixture_folder)
        end
      end
    end

    def clean_and_setup
      FileUtils.rm_rf("#{workdir}/iteration/")
    end

    def validate_status(exercise, fixture_folder)
      FileUtils.cp_r "#{fixture_folder}/iteration", "#{workdir}/iteration"

      container_driver.run_analyzer_for(exercise)

      analysis = JSON.parse(File.read("#{workdir}/iteration/analysis.json"))
      expected = JSON.parse(File.read("#{fixture_folder}/expected_analysis.json"))

      raise "Incorrect expected_status" if expected["status"].nil?
      raise "Incorrect status when validating #{fixture_folder}" if expected["status"] != analysis["status"]
      expected["comments"] ||= []
      analysis["comments"] ||= []
      raise "Incorrect comments when validating #{fixture_folder}" if expected["comments"].sort != analysis["comments"].sort
    end

    def workdir
      container_driver.workdir
    end
  end
end
