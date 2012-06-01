# Calculate statistics on the project
desc "Calculate statistics on the project (correlation, distribution, etc...)"
task :statistics => [:sqlite3] do

  # Check if there is data to update from
  if MethodData.count(:project => @evaluation_projects_one) > 0
    puts "[LOG] Calculating statistics of data set"
    MetricLibsvmSynthesizer.new(@evaluation_projects_one, @home).statistics
  else
    puts "[ERROR] No data to cacluate statistics on (run setup_svm)"
  end
end

# Perform cross validation of the project
desc "Perform cross validation on the project"
task :cross_validation => [:sqlite3] do

  puts "[LOG] Creating .libsvm files"
  MetricLibsvmSynthesizer.new(@evaluation_projects_one, @home).process

  make_libsvm
  Dir.chdir("#{@libsvm}") do
    Dir.chdir("tools") do

      puts "[LOG] Performing cross validation"
      class_output = `#{@python} easy.py ./../../data/evaluation_projects_class.libsvm`
      class_values = class_output.scan(/Best c=(\d+\.?\d*), g=(\d+\.?\d*) CV rate=(\d+\.?\d*)/)[0]
      method_output = `#{@python} easy.py ./../../data/evaluation_projects_method.libsvm`
      method_values = method_output.scan(/Best c=(\d+\.?\d*), g=(\d+\.?\d*) CV rate=(\d+\.?\d*)/)[0]

      puts "[LOG] Acquiring detailed results of cross validation"
      `../svm-train -v #{@cross_validation_folds} -c #{class_values[0]} -g #{class_values[1]} ./evaluation_projects_class.libsvm.scale`
      cp("./prediction_file.csv", "../../data/evaluation_projects_class_prediction.csv")
      `../svm-train -v #{@cross_validation_folds} -c #{method_values[0]} -g #{method_values[1]} ./evaluation_projects_method.libsvm.scale`
      cp("./prediction_file.csv", "../../data/evaluation_projects_method_prediction.csv")

      puts "[LOG] Class Accuracy = #{class_values[2]}%"
      puts "[LOG] Best Class Configuration = -c #{class_values[0]} -g #{class_values[1]}"

      puts "[LOG] Method Accuracy = #{method_values[2]}%"
      puts "[LOG] Best Method Configuration = -c #{method_values[0]} -g #{method_values[1]}"

    end
  end
end

# Train using projects_one and predict projects_two
desc "Train using projects_one then predict using projects_two"
task :train_predict => [:sqlite3] do

  puts "[LOG] Creating .libsvm files for projects_one"
  MetricLibsvmSynthesizer.new(@evaluation_projects_one, @home).process
  mv("#{@home}/data/evaluation_projects_class.libsvm", "#{@home}/data/evaluation_projects_one_class.libsvm")
  mv("#{@home}/data/evaluation_projects_method.libsvm", "#{@home}/data/evaluation_projects_one_method.libsvm")

  puts "[LOG] Creating .libsvm files for projects_two"
  MetricLibsvmSynthesizer.new(@evaluation_projects_two, @home).process
  mv("#{@home}/data/evaluation_projects_class.libsvm", "#{@home}/data/evaluation_projects_two_class.libsvm")
  mv("#{@home}/data/evaluation_projects_method.libsvm", "#{@home}/data/evaluation_projects_two_method.libsvm")

  make_libsvm
  Dir.chdir("#{@libsvm}") do
    Dir.chdir("tools") do

      puts "[LOG] Finding best parameters for projects_one, then predicting on projects_two"
      class_output = `#{@python} easy.py ./../../data/evaluation_projects_one_class.libsvm ./../../data/evaluation_projects_two_class.libsvm`
      method_output = `#{@python} easy.py ./../../data/evaluation_projects_one_method.libsvm ./../../data/evaluation_projects_two_method.libsvm`

      mv("#{@home}/#{@libsvm}/tools/evaluation_projects_two_class.libsvm.predict", "#{@home}/data/evaluation_projects_two_class.predict")
      mv("#{@home}/#{@libsvm}/tools/evaluation_projects_two_method.libsvm.predict", "#{@home}/data/evaluation_projects_two_method.predict")

      puts "Class Prediction " + class_output.scan(/(Accuracy = .*$)/)[0][0]
      puts "Method Prediction " + method_output.scan(/(Accuracy = .*$)/)[0][0]

    end
  end
end

def make_libsvm
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
    end
  end
end
