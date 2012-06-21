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

desc "Grid search on the testing data set"
task :grid_search_testing, [:type] => [:sqlite3] do |t, args|
  type = args[:type]
  run = 10
  lower_bound = 0.001
  cost_limit = 1000
  gamma_limit = 1000
  step_multiplier = 10
  sort_symbol = "f1"

  best = Hash.new(Hash.new(0))
  run.times do |i|

    puts "[LOG] Creating #{type} .libsvm file for projects_one"
    selected_indexes = MetricLibsvmSynthesizer.new(@evaluation_projects_one, @home).process(type)
    mv("#{@home}/data/evaluation_projects_#{type}.libsvm", "#{@home}/data/evaluation_projects_one_#{type}.libsvm")

    puts "[LOG] Creating #{type}.libsvm file for projects_two"
    if @evaluation_projects_one.sort == @evaluation_projects_two.sort
      puts "[LOG] Projects one and two are the same, going to exclude vectors from project one for project two"
      MetricLibsvmSynthesizer.new(@evaluation_projects_two, @home, true).process(type, selected_indexes)
    else
      MetricLibsvmSynthesizer.new(@evaluation_projects_two, @home, true).process(type)
    end
    mv("#{@home}/data/evaluation_projects_#{type}.libsvm", "#{@home}/data/evaluation_projects_two_#{type}.libsvm")

    Dir.chdir("#{@libsvm}") do

      # Scale training and test set using same scale values
      `./svm-scale -s scale_values.txt #{@home}/data/evaluation_projects_one_#{type}.libsvm > ./evaluation_projects_one_#{type}.libsvm.scale`
      `./svm-scale -r scale_values.txt #{@home}/data/evaluation_projects_two_#{type}.libsvm > ./evaluation_projects_two_#{type}.libsvm.scale`

      # Grid Search
      ranking = []
      cost = lower_bound
      gamma = lower_bound
      while cost <= cost_limit && gamma <= gamma_limit do

        # Train using training set
        `./svm-train -c #{cost} -g #{gamma} ./evaluation_projects_one_#{type}.libsvm.scale ./evaluation_projects_one_#{type}.libsvm.model`

        # Predict using test set
        output = `./svm-predict ./evaluation_projects_two_#{type}.libsvm.scale ./evaluation_projects_one_#{type}.libsvm.model ./evaluation_projects_two_#{type}.libsvm.predict`
        mv("#{@home}/#{@libsvm}/evaluation_projects_two_#{type}.libsvm.predict", "#{@home}/data/evaluation_projects_two_#{type}.predict")

        construct_prediction_csv(type)

        results = result_summary("#{@home}/data/evaluation_projects_two_#{type}_prediction.csv")
        f1 = results[0].inject(0){|sum,a| sum + a[:f1].to_s.to_f}

        # Identify and store parameters and measures
        accuracy = output.scan(/Accuracy = ([\d]*.[\d]*)/)[0][0].to_f
        ranking << {:cost => cost,
                    :gamma => gamma,
                    :accuracy => accuracy,
                    :f1 => f1
                   }

        # Move to the next iteration for the grid search based on the bounds
        if cost > (cost_limit / step_multiplier) && gamma <= (gamma_limit / step_multiplier)
          cost = lower_bound
          gamma = gamma * step_multiplier
        else
          cost = cost * step_multiplier
        end
      end

      # Sort the values and increment the measures with the seen values
      sorted_ranking = ranking.sort_by{|a|a[sort_symbol.to_sym]}.reverse!
      sorted_ranking.size.times do |i|
        values = best[{:cost => sorted_ranking[i][:cost], :gamma => sorted_ranking[i][:gamma]}].dup
        values[:f1] += sorted_ranking[i][:f1]
        values[:accuracy] += sorted_ranking[i][:accuracy]
        values[:rank] += i
        best[{:cost => sorted_ranking[i][:cost], :gamma => sorted_ranking[i][:gamma]}] = values
      end
    end
  end

  # Sort by rank and output
  puts "[LOG] Best Parameter and Measures - Sorted by Rank(#{sort_symbol})"
  sorted_best = best.sort_by{|k,v| v[:rank]}
  sorted_best.each do |k,v|
    puts "Rank:%-6d Accuracy:%6f F1:%6f c:%f g:%f" % [v[:rank], v[:accuracy]/run, v[:f1]/run, k[:cost], k[:gamma]]
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
