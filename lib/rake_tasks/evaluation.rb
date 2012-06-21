# Calculate statistics on the project
desc "Calculate statistics on the project (correlation, distribution, etc...)"
task :statistics => [:sqlite3] do

  # Check if there is data to update from
  if MethodData.count(:project => @evaluation_projects_one) > 0
    puts "[LOG] Calculating statistics of data set (classes)"
    MetricLibsvmSynthesizer.new(@evaluation_projects_one, @home).statistics("class")
  else
    puts "[ERROR] No data to cacluate statistics on (run setup_svm)"
  end

  if MethodData.count(:project => @evaluation_projects_one) > 0
    puts "[LOG] Calculating statistics of data set (methods)"
    MetricLibsvmSynthesizer.new(@evaluation_projects_one, @home).statistics("method")
  else
    puts "[ERROR] No data to cacluate statistics on (run setup_svm)"
  end

  puts "[LOG] Data can be found in the #{@home}/data/ directory"
end

# Perform cross validation of the project
desc "Perform cross validation on the project"
task :cross_validation => [:sqlite3] do
  make_libsvm_library
  perform_cross_validation("class")
  perform_cross_validation("method")
end

def perform_cross_validation(type)
  puts "[LOG] Creating #{type} .libsvm file"
  MetricLibsvmSynthesizer.new(@evaluation_projects_one, @home).process(type)

  Dir.chdir("#{@libsvm}") do
    Dir.chdir("tools") do

      puts "[LOG] Performing cross validation"
      output = `#{@python} easy.py #{@home}/data/evaluation_projects_#{type}.libsvm`
      values = output.scan(/Best c=(\d+\.?\d*), g=(\d+\.?\d*) CV rate=(\d+\.?\d*)/)[0]

      puts "[LOG] Acquiring detailed results of cross validation"
      `../svm-train -v #{@cross_validation_folds} -c #{values[0]} -g #{values[1]} ./evaluation_projects_#{type}.libsvm.scale`
      cp("./prediction_file.csv", "#{@home}/data/evaluation_projects_#{type}_prediction.csv")

      puts "[LOG] Best Class Configuration = -c #{values[0]} -g #{values[1]}"
      puts "[LOG] Class Accuracy = #{values[2]}%"
      puts result_summary("#{@home}/data/evaluation_projects_#{type}_prediction.csv")[1]
    end
  end
end

# Train using projects_one and predict projects_two
desc "Train using projects_one then predict using projects_two"
task :train_predict => [:sqlite3] do
  make_libsvm_library
  perform_train_predict("class")
  perform_train_predict("method")
end

def perform_train_predict(type)
  puts "[LOG] Creating #{type} .libsvm file for projects_one"
  MetricLibsvmSynthesizer.new(@evaluation_projects_one, @home).process(type)
  mv("#{@home}/data/evaluation_projects_#{type}.libsvm", "#{@home}/data/evaluation_projects_one_#{type}.libsvm")

  puts "[LOG] Creating #{type} .libsvm file for projects_two"
  MetricLibsvmSynthesizer.new(@evaluation_projects_two, @home, true).process(type)
  mv("#{@home}/data/evaluation_projects_#{type}.libsvm", "#{@home}/data/evaluation_projects_two_#{type}.libsvm")

  make_predictions(type)
end

desc "Get the ordering of the attributes"
task :attributes => [:sqlite3] do
  [ClassData, MethodData].each do |type|
    puts "[LOG] Attribute Look-up List for #{type.class}:"
    property_count = 0
    type.properties.each do |property|

      field = property.instance_variable_name[1..-1]

      if not MetricLibsvmSynthesizer.new(nil, @home).ignore_field(field)
        property_count += 1
        puts "Attribute_#{property_count}:#{field} "
      end
    end
  end
end

def make_predictions(type)
  Dir.chdir("#{@libsvm}") do
    Dir.chdir("tools") do

      puts "[LOG] Finding best parameters for projects_one, then predicting on projects_two"
      output = `#{@python} easy.py #{@home}/data/evaluation_projects_one_#{type}.libsvm #{@home}/data/evaluation_projects_two_#{type}.libsvm`
      mv("#{@home}/#{@libsvm}/tools/evaluation_projects_two_#{type}.libsvm.predict", "#{@home}/data/evaluation_projects_two_#{type}.predict")

      construct_prediction_csv(type)

      puts "#{type.capitalize} Prediction " + output.scan(/(Accuracy = .*$)/)[0][0]
      values = output.scan(/Best c=(\d+\.?\d*), g=(\d+\.?\d*) CV rate=(\d+\.?\d*)/)[0]
      puts "Best Configuration = -c #{values[0]} -g #{values[1]}"
      puts "Cross Validation Accuracy of Training Set = #{values[2]}\%"
      puts result_summary("#{@home}/data/evaluation_projects_two_#{type}_prediction.csv")[1]
    end
  end
end

def construct_prediction_csv(type)
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

  file = File.open("#{@home}/data/evaluation_projects_two_#{type}_prediction.csv", 'w')
  file.write(content)
  file.close
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
  results = []
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

    results << {:category => i,
                :tpr => tpr,
                :fpr => fpr,
                :acc => acc,
                :recall => recall,
                :precision => precision,
                :specificity => specificity,
                :f1 => f1
              }
  end
  return [results, output]
end

def make_libsvm_library
  Dir.chdir("#{@libsvm}") do
    puts "[LOG] Making libsvm library"
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
