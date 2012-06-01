# Calculate statistics on the project
desc "Calculate statistics on the project (correlation, distribution, etc...)"
task :statistics => [:sqlite3] do

  # Check if there is data to update from
  if MethodData.count(:project => @project_name) > 0
    puts "[LOG] Calculating statistics of data set"
    MetricLibsvmSynthesizer.new(@project_name, @home).statistics
  else
    puts "[ERROR] No data to cacluate statistics on (run setup_svm)"
  end
end

# Perform cross validation of the project
desc "Perform cross validation on the project"
task :cross_validation => [:sqlite3] do

  puts "[LOG] Creating .libsvm files"
  MetricLibsvmSynthesizer.new(@project_name, @home).process

  Dir.chdir("#{@libsvm}") do
    puts "[LOG] Making libsvm"
    sh "make"
    Dir.chdir("tools") do
      puts "[LOG] Modifying grid.py to use #{@max_cores} cores and " \
           "#{@cross_validation_folds} folds"

      # Modify the settings to use the specified cores and folds
      file = File.open("grid.py", 'r')
      content = file.read
      file.close
      content.gsub!(/nr_local_worker = \d+/, "nr_local_worker = #{@max_cores}")
      content.gsub!(/fold = \d+/, "fold = #{@cross_validation_folds}")
      file = File.open("grid.py", 'w')
      file.write(content)
      file.close

      puts "[LOG] Performing cross validation"
      class_output = `#{@python} easy.py ./../../data/#{@project_name}_class.libsvm`
      class_values = class_output.scan(/Best c=(\d+\.?\d*), g=(\d+\.?\d*) CV rate=(\d+\.?\d*)/)[0]
      method_output = `#{@python} easy.py ./../../data/#{@project_name}_method.libsvm`
      method_values = method_output.scan(/Best c=(\d+\.?\d*), g=(\d+\.?\d*) CV rate=(\d+\.?\d*)/)[0]

      puts "[LOG] Acquiring detailed results of cross validation"
      `../svm-train -v #{@cross_validation_folds} -c #{class_values[0]} -g #{class_values[1]} ./#{@project_name}_class.libsvm.scale`
      cp("./prediction_file.csv", "../../data/#{@project_name}_class_prediction.csv")
      `../svm-train -v #{@cross_validation_folds} -c #{method_values[0]} -g #{method_values[1]} ./#{@project_name}_method.libsvm.scale`
      cp("./prediction_file.csv", "../../data/#{@project_name}_method_prediction.csv")

      puts "[LOG] Class Accuracy = #{class_values[2]}%"
      puts "[LOG] Best Class Configuration = -c #{class_values[0]} -g #{class_values[1]}"

      puts "[LOG] Method Accuracy = #{method_values[2]}%"
      puts "[LOG] Best Method Configuration = -c #{method_values[0]} -g #{method_values[1]}"

    end
  end
end
