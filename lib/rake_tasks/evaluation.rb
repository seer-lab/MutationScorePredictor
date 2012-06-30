# Calculate statistics on the project
desc "Calculate statistics on the project (correlation, distribution, etc...)"
task :statistics => [:sqlite3] do

  # Check if there is data to update from
  if MethodData.count(:project => @evaluation_projects_one) > 0
    puts "[LOG] Calculating statistics of data set (classes)"
    MetricLibsvmSynthesizer.new(@evaluation_projects_one, @home).statistics("class")
  else
    puts "[ERROR] No data to calculate statistics on (run setup_svm)"
  end

  if MethodData.count(:project => @evaluation_projects_one) > 0
    puts "[LOG] Calculating statistics of data set (methods)"
    MetricLibsvmSynthesizer.new(@evaluation_projects_one, @home).statistics("method")
  else
    puts "[ERROR] No data to calculate statistics on (run setup_svm)"
  end

  puts "[LOG] Data can be found in the #{@home}/data/ directory"
end

# Perform cross validation of the project
desc "Perform cross validation on the project"
task :cross_validation => [:sqlite3] do
  puts "[LOG] Using project(s) #{@evaluation_projects_one}"
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

      puts "[LOG] Best #{type.capitalize} Configuration = -c #{values[0]} -g #{values[1]}"
      puts "[LOG] #{type.capitalize} Accuracy = #{values[2]}%"
      labels = construct_prediction_csv(type, true)
      puts result_summary("#{@home}/data/evaluation_projects_#{type}_prediction.csv", labels)[1]
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

task :train_predict_type_with_cost_gamma, :type, :cost, :gamma, :needs => [:sqlite3] do |t, args|
  type = args[:type] || "method"
  puts "[LOG] Using project(s) #{@evaluation_projects_one} vs project(s) #{@evaluation_projects_two}"
  puts "[LOG] Creating #{type} .libsvm file for projects_one"
  selected_indexes = MetricLibsvmSynthesizer.new(@evaluation_projects_one, @home).process(type)
  mv("#{@home}/data/evaluation_projects_#{type}.libsvm", "#{@home}/data/evaluation_projects_one_#{type}.libsvm")

  puts "[LOG] Creating #{type}.libsvm file for projects_two"
  if @only_unknowns && @evaluation_projects_one.sort == @evaluation_projects_two.sort
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

    # Train using training set
    `./svm-train -b 1 -c #{args[:cost]} -g #{args[:gamma]} ./evaluation_projects_one_#{type}.libsvm.scale ./evaluation_projects_one_#{type}.libsvm.model`

    # Predict using test set
    output = `./svm-predict -b 1 ./evaluation_projects_two_#{type}.libsvm.scale ./evaluation_projects_one_#{type}.libsvm.model ./evaluation_projects_two_#{type}.libsvm.predict`
    mv("#{@home}/#{@libsvm}/evaluation_projects_two_#{type}.libsvm.predict", "#{@home}/data/evaluation_projects_two_#{type}.predict")

    labels = construct_prediction_csv(type)

    puts results = result_summary("#{@home}/data/evaluation_projects_two_#{type}_prediction.csv", labels)[1]
  end
end

def perform_train_predict(type)
  puts "[LOG] Using project(s) #{@evaluation_projects_one} vs project(s) #{@evaluation_projects_two}"
  puts "[LOG] Creating #{type} .libsvm file for projects_one"
  selected_indexes = MetricLibsvmSynthesizer.new(@evaluation_projects_one, @home).process(type)
  mv("#{@home}/data/evaluation_projects_#{type}.libsvm", "#{@home}/data/evaluation_projects_one_#{type}.libsvm")

  puts "[LOG] Creating #{type} .libsvm file for projects_two"
  if @only_unknowns && @evaluation_projects_one.sort == @evaluation_projects_two.sort
    MetricLibsvmSynthesizer.new(@evaluation_projects_two, @home, true).process(type, selected_indexes)
  else
    MetricLibsvmSynthesizer.new(@evaluation_projects_two, @home, true).process(type)
  end
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

      if not ignore_field(field)
        property_count += 1
        puts "Attribute_#{property_count}:#{field} "
      end
    end
  end
end

desc "Grid search over all sets of all projects except one vs that one"
task :grid_search_all_vs_one, [:type] => [:sqlite3] do |t, args|
  type = args[:type] || "method"
  results = []
  best = Hash.new(Hash.new(0))

  # Perform and store grid search results for all project except one vs that one
  @projects.size.times do |i|
    tmp = Array.new(@projects)
    tmp.delete_at(i)
    @evaluation_projects_one = tmp
    @evaluation_projects_two = Array.new([@projects[i]])
    tmp = grid_search(type, @run, @sort_symbol)
    results << tmp[0]
    puts tmp[1]
  end

  # Aggregate results for {cost,gamma}
  results.each do |result|
    result.size.times do |i|
      values = best[{:cost => result[i][0][:cost], :gamma => result[i][0][:gamma]}].dup
      values[:f_score] += result[i][1][:f_score]
      values[:coarse_auroc] += result[i][1][:coarse_auroc]
      values[:accuracy] += result[i][1][:accuracy]
      values[:rank] += result[i][1][:rank]
      best[{:cost => result[i][0][:cost], :gamma => result[i][0][:gamma]}] = values
    end
  end

  # Sort by rank and output
  puts "[LOG] Overall Best Parameter and Measures - Sorted by Rank(#{@sort_symbol})"
  puts "F-score and Coarse auROC are calculated using (total_value / \# of categories)"
  puts "The divisor might not be consistent based on the availability of data in all categories"
  sorted_best = best.sort_by{|k,v| v[:rank]}
  sorted_best.each do |k,v|
    puts "Rank:%-6d Accuracy:%6f F-score:%6f CauROC:%6f c:%f g:%f" % [v[:rank], v[:accuracy]/(@projects.size*@run), v[:f_score]/(@projects.size*@run), v[:coarse_auroc]/(@projects.size*@run), k[:cost], k[:gamma]]
  end
end

desc "Grid search over all individual projects on themselves"
task :grid_search_each_self, [:type] => [:sqlite3] do |t, args|
  type = args[:type] || "method"
  results = []
  best = Hash.new(Hash.new(0))

  # Perform and store grid search results for each project on itself
  @projects.each do |project|
    @evaluation_projects_one = Array.new([project])
    @evaluation_projects_two = Array.new([project])
    tmp = grid_search(type, @run, @sort_symbol, @only_unknowns)
    results << tmp[0]
    puts tmp[1]
  end

  # Aggregate results for {cost,gamma}
  results.each do |result|
    result.size.times do |i|
      values = best[{:cost => result[i][0][:cost], :gamma => result[i][0][:gamma]}].dup
      values[:f_score] += result[i][1][:f_score]
      values[:coarse_auroc] += result[i][1][:coarse_auroc]
      values[:accuracy] += result[i][1][:accuracy]
      values[:rank] += result[i][1][:rank]
      best[{:cost => result[i][0][:cost], :gamma => result[i][0][:gamma]}] = values
    end
  end

  # Sort by rank and output
  puts "[LOG] Overall Best Parameter and Measures - Sorted by Rank(#{@sort_symbol})"
  puts "F-score and Coarse auROC are calculated using (total_value / \# of categories)"
  puts "The divisor might not be consistent based on the availability of data in all categories"
  sorted_best = best.sort_by{|k,v| v[:rank]}
  sorted_best.each do |k,v|
    puts "Rank:%-6d Accuracy:%6f F-score:%6f CauROC:%6f c:%f g:%f" % [v[:rank], v[:accuracy]/(@projects.size*@run), v[:f_score]/(@projects.size*@run), v[:coarse_auroc]/(@projects.size*@run), k[:cost], k[:gamma]]
  end
end

desc "Grid search over all projects on themselves"
task :grid_search_all_self, [:type] => [:sqlite3] do |t, args|
  type = args[:type] || "method"
  results = []
  best = Hash.new(Hash.new(0))

  # Perform and store grid search results for each project on itself
  @evaluation_projects_one = @projects
  @evaluation_projects_two = @projects
  puts grid_search(type, @run, @sort_symbol, @only_unknowns)[1]
end

desc "Grid search on the testing data set"
task :grid_search_testing, [:type] => [:sqlite3] do |t, args|
  type = args[:type] || "method"
  puts grid_search(type, @run, @sort_symbol, @only_unknowns)[1]
end

def grid_search(type, run, sort_symbol, only_unknowns=false)
  best = Hash.new(Hash.new(0))
  puts "[LOG] Using project(s) #{@evaluation_projects_one} vs project(s) #{@evaluation_projects_two}"

  run.times do |i|

    puts "[LOG] Creating #{type} .libsvm file for projects_one"
    selected_indexes = MetricLibsvmSynthesizer.new(@evaluation_projects_one, @home).process(type)
    mv("#{@home}/data/evaluation_projects_#{type}.libsvm", "#{@home}/data/evaluation_projects_one_#{type}.libsvm")

    puts "[LOG] Creating #{type}.libsvm file for projects_two"
    if only_unknowns && @evaluation_projects_one.sort == @evaluation_projects_two.sort
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
      cost = @lower_bound
      gamma = @lower_bound
      while cost <= @cost_limit && gamma <= @gamma_limit do

        # Train using training set
        `./svm-train -b 1 -c #{cost} -g #{gamma} ./evaluation_projects_one_#{type}.libsvm.scale ./evaluation_projects_one_#{type}.libsvm.model`

        # Predict using test set
        output = `./svm-predict -b 1 ./evaluation_projects_two_#{type}.libsvm.scale ./evaluation_projects_one_#{type}.libsvm.model ./evaluation_projects_two_#{type}.libsvm.predict`
        mv("#{@home}/#{@libsvm}/evaluation_projects_two_#{type}.libsvm.predict", "#{@home}/data/evaluation_projects_two_#{type}.predict")

        labels = construct_prediction_csv(type)

        results = result_summary("#{@home}/data/evaluation_projects_two_#{type}_prediction.csv", labels)

        accuracy = results[0].inject(0){|sum,a| sum + a[:accuracy].to_s.to_f}/labels.size
        f_score = results[0].inject(0){|sum,a| sum + a[:f_score].to_s.to_f}/labels.size
        coarse_auroc = results[0].inject(0){|sum,a| sum + a[:coarse_auroc].to_s.to_f}/labels.size

        # Identify and store parameters and measures
        ranking << {:cost => cost,
                    :gamma => gamma,
                    :accuracy => accuracy,
                    :f_score => f_score,
                    :coarse_auroc => coarse_auroc
                   }

        # Move to the next iteration for the grid search based on the bounds
        if cost > (@cost_limit / @step_multiplier) && gamma <= (@gamma_limit / @step_multiplier)
          cost = @lower_bound
          gamma = gamma * @step_multiplier
        else
          cost = cost * @step_multiplier
        end
      end

      # Sort the values and increment the measures with the seen values
      sorted_ranking = ranking.sort_by{|a|a[sort_symbol.to_sym]}.reverse!
      sorted_ranking.size.times do |i|
        values = best[{:cost => sorted_ranking[i][:cost], :gamma => sorted_ranking[i][:gamma]}].dup
        values[:f_score] += sorted_ranking[i][:f_score]
        values[:coarse_auroc] += sorted_ranking[i][:coarse_auroc]
        values[:accuracy] += sorted_ranking[i][:accuracy]
        values[:rank] += i
        best[{:cost => sorted_ranking[i][:cost], :gamma => sorted_ranking[i][:gamma]}] = values
      end
    end
  end

  # Sort by rank and output
  output = "[LOG] Best Parameter and Measures - Sorted by Rank(#{sort_symbol})"
  output += "\nF-score and Coarse auROC are calculated using (total_value / \# of categories)"
  output += "\nThe divisor might not be consistent based on the availability of data in all categories"
  sorted_best = best.sort_by{|k,v| v[:rank]}
  sorted_best.each do |k,v|
    output += "\nRank:%-6d Accuracy:%6f F-score:%6f CauROC:%6f c:%f g:%f" % [v[:rank], v[:accuracy]/run, v[:f_score]/run, v[:coarse_auroc]/run, k[:cost], k[:gamma]]
  end
  return [sorted_best, output]
end

def make_predictions(type)
  Dir.chdir("#{@libsvm}") do
    Dir.chdir("tools") do

      puts "[LOG] Finding best parameters for projects_one, then predicting on projects_two"
      output = `#{@python} easy.py #{@home}/data/evaluation_projects_one_#{type}.libsvm #{@home}/data/evaluation_projects_two_#{type}.libsvm`
      mv("#{@home}/#{@libsvm}/tools/evaluation_projects_two_#{type}.libsvm.predict", "#{@home}/data/evaluation_projects_two_#{type}.predict")

      labels = construct_prediction_csv(type)

      puts "#{type.capitalize} Prediction " + output.scan(/(Accuracy = .*$)/)[0][0]
      values = output.scan(/Best c=(\d+\.?\d*), g=(\d+\.?\d*) CV rate=(\d+\.?\d*)/)[0]
      puts "Best Configuration = -c #{values[0]} -g #{values[1]}"
      puts "Cross Validation Accuracy of Training Set = #{values[2]}\%"
      puts result_summary("#{@home}/data/evaluation_projects_two_#{type}_prediction.csv", labels)[1]
    end
  end
end

def construct_prediction_csv(type, cross_validation=false)
  if cross_validation
    file = "#{@home}/data/evaluation_projects_#{type}"
    actual = []
    CSV.foreach("#{file}.libsvm", :col_sep => ' ') do |row|
      actual << row[0].to_i
    end
    return actual.uniq!.sort
  else
    file = "#{@home}/data/evaluation_projects_two_#{type}"
  end

  actual = []
  CSV.foreach("#{file}.libsvm", :col_sep => ' ') do |row|
    actual << row[0]
  end

  predicted = []
  labels = []
  CSV.foreach("#{file}.predict", :col_sep => ' ') do |row|
    if row[0] == "labels"
      labels = row[1..-1].map{|i| i.to_i}
      next
    end
    predicted << row.join(",")
  end

  content = "ACTUAL,PREDICTED"
  labels.each do |i|
    content += ",#{i}_probability"
  end
  actual.size.times do |i|
    content += "\n#{actual[i.to_i]},#{predicted[i.to_i]}"
  end

  file = File.open("#{file}_prediction.csv", 'w')
  file.write(content)
  file.close

  return labels
end

def result_summary(prediction_file, labels)
  # Read in predictions into hash/matrix
  categories = labels

  matrix = Hash.new(0)
  count = 0

  CSV.foreach(prediction_file, :col_sep => ',') do |row|

    # Skip the first row of field names
    if row[0] == "ACTUAL"
      next
    end

    matrix[[row[0].to_i, row[1].to_i]] += 1
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
  output += "%-13s" % "F-score"
  output += "%-13s\n" % "Crude auROC"

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
    accuracy = (tp+tn)/count.to_f
    precision = tp/(tp+fp).to_f
    recall = tp/(tp+fn).to_f
    specificity = tn/(tn+fp).to_f
    f_score = 2*((recall*precision)/(recall+precision))
    coarse_auroc = (1+tpr-fpr)/2

    output += "A%-5d" % i
    output += "%-13f" % tpr
    output += "%-13f" % fpr
    output += "%-13f" % accuracy
    output += "%-13f" % recall
    output += "%-13f" % precision
    output += "%-13f" % specificity
    output += "%-13f" % f_score
    output += "%-13f\n" % coarse_auroc

    results << {:category => i,
                :tpr => tpr,
                :fpr => fpr,
                :accuracy => accuracy,
                :recall => recall,
                :precision => precision,
                :specificity => specificity,
                :f_score => f_score,
                :coarse_auroc => coarse_auroc
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
