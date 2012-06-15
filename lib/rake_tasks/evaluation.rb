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

      puts "[LOG] Best Class Configuration = -c #{class_values[0]} -g #{class_values[1]}"
      puts "[LOG] Class Accuracy = #{class_values[2]}%"
      puts result_summary("../../data/evaluation_projects_class_prediction.csv")
      puts "-----"
      puts "[LOG] Method Accuracy = #{method_values[2]}%"
      puts "[LOG] Best Method Configuration = -c #{method_values[0]} -g #{method_values[1]}"
      puts result_summary("../../data/evaluation_projects_method_prediction.csv")

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
  make_predictions("class")
  puts "-----"
  make_predictions("method")
end

def make_predictions(type)
  Dir.chdir("#{@libsvm}") do
    Dir.chdir("tools") do

      puts "[LOG] Finding best parameters for projects_one, then predicting on projects_two"
      output = `#{@python} easy.py ./../../data/evaluation_projects_one_#{type}.libsvm ./../../data/evaluation_projects_two_#{type}.libsvm`

      mv("#{@home}/#{@libsvm}/tools/evaluation_projects_two_#{type}.libsvm.predict", "#{@home}/data/evaluation_projects_two_#{type}.predict")


      actual = []
      CSV.foreach("#{@home}/data/evaluation_projects_two_#{type}.libsvm", :col_sep => ' ') do |row|
        actual << row[0]
      end

      predicted = []
      CSV.foreach("#{@home}/data/evaluation_projects_two_#{type}.predict") do |row|
        predicted << row[0]
      end

      content = "ACTUAL,PREDICTED"
      actual.size.times do |i|
        content += "\n#{actual[i.to_i]},#{predicted[i.to_i]}"
      end

      file = File.open("../../data/evaluation_projects_two_#{type}_prediction.csv", 'w')
      file.write(content)
      file.close

      puts "#{type.capitalize} Prediction " + output.scan(/(Accuracy = .*$)/)[0][0]
      puts result_summary("../../data/evaluation_projects_two_#{type}_prediction.csv")
    end
  end
end

def result_summary(prediction_file)
  # Read in predictions into hash/matrix
  matrix = Hash.new(0)
  count = 0
  categories = SortedSet.new
  CSV.foreach(prediction_file, :col_sep => ',') do |row|

    # Skip the first row of field names
    if row[0] == "ACTUAL"
      next
    end

    matrix[[row[0].to_i, row[1].to_i]] += 1

    categories.add(row[0].to_i)
    categories.add(row[1].to_i)

    count += 1
  end

  # Make pretty print confusion matrix
  output = " " * 6
  categories.each do |i|
    output += "P%-6d" % i
  end
  output += "\n"

  categories.each do |i|
    output += "A%-4d" % i
    categories.each do |j|
      output += "% -7d" % matrix[[i,j]]
    end
    output += "\n"
  end

  # Format result headings
  output += "\n" + " " * 6
  output += "%-13s" % "TPR"
  output += "%-13s" % "FPR"
  output += "%-13s" % "Accuracy"
  output += "%-13s" % "Recall"
  output += "%-13s" % "Precision"
  output += "%-13s" % "Specificity"
  output += "%-13s\n" % "F-1 Score"

  # Compute/store results for each category
  categories.each do |i|

    tp = matrix[[i,i]]
    tn = 0
    fp = 0
    fn = 0

    categories.each do |j|
      next if i == j
      fp += matrix[[j,i]]
      fn += matrix[[i,j]]
      tn += matrix[[j,j]]
    end

    tpr = tp/(tp+fn).to_f
    fpr = fp/(fp+tn).to_f
    acc = (tp+tn)/count.to_f
    precision = tp/(tp+fp).to_f
    recall = tp/(tp+fn).to_f
    specificity = tn/(tn+fp).to_f
    f1 = 2*((recall*precision)/(recall+precision))

    output += "A%-5d" % i
    output += "%-13f" % tpr
    output += "%-13f" % fpr
    output += "%-13f" % acc
    output += "%-13f" % recall
    output += "%-13f" % precision
    output += "%-13f" % specificity
    output += "%-13f\n" % f1
  end
  return output
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
