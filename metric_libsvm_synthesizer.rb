require 'statsample'

class MetricLibsvmSynthesizer

  attr_accessor :project, :run, :home

  def initialize(project, run, home)
    @project = project
    @run = run
    @home = home
  end

  def determine_ranges(data_set)

    # Figure the ranges out
    items_per_range = data_set.count / 3
    lower_break = data_set[items_per_range].mutation_score_of_covered_mutants
    upper_break = data_set[2*items_per_range].mutation_score_of_covered_mutants

    return lower_break, upper_break
  end

  def make_libsvm(type, data_set, lower_break, upper_break)

    content = ""
    data_set.each do |item|

      if item.mutation_score_of_covered_mutants <= lower_break
        content += "1 "
      elsif item.mutation_score_of_covered_mutants <= upper_break
        content += "2 "
      else
        content += "3 "
      end

      property_count = 0
      data_set.properties.each do |property|

        field = property.instance_variable_name[1..-1]

        if not ignore_field(field)
          property_count += 1
          content += "#{property_count}:#{item.send(field)} "
        end
      end
      content += "\n"
    end
    return content
  end

  def process

    class_data = ClassData.all(:project => @project, :run => @run, :usable => true, :order => [:mutation_score_of_covered_mutants.asc])
    method_data = MethodData.all(:project => @project, :run => @run, :usable => true, :order => [:mutation_score_of_covered_mutants.asc])

    # Determine ranges for class and method data
    class_lower_break, class_upper_break = determine_ranges(class_data)
    method_lower_break, method_upper_break = determine_ranges(method_data)

    # Create file contents with appropriate categories
    class_libsvm = make_libsvm("class", class_data, class_lower_break, class_upper_break)
    method_libsvm = make_libsvm("method", method_data, method_lower_break, method_upper_break)

    # Write out .libsvm files
    file = File.open("#{@home}/data/#{@project}_class_#{@run}.libsvm", 'w')
    file.write(class_libsvm)
    file.close

    file = File.open("#{@home}/data/#{@project}_method_#{@run}.libsvm", 'w')
    file.write(method_libsvm)
    file.close
  end

  def statistics
    class_data = ClassData.all(:project => @project, :run => @run, :usable => true, :order => [:mutation_score_of_covered_mutants.asc])
    method_data = MethodData.all(:project => @project, :run => @run, :usable => true, :order => [:mutation_score_of_covered_mutants.asc])

    # Calculate the distribution of the mutation scores
    puts "[LOG] Calculating distributions"
    distribution("class", class_data)
    distribution("method", method_data)
  
    puts "[LOG] Calculating correlation matrix"
    # Calculate the correlation matrix
    correlation("class", class_data)
    correlation("method", method_data)

    puts "[LOG] Data can be found in the #{@home}/data/ directory"
  end

  def distribution(type, data_set)

    distribution_range = []
    low = 0.00
    high = 0.01
    100.times do
      distribution_range << (data_set.count(:mutation_score_of_covered_mutants.gte => low, :mutation_score_of_covered_mutants.lte => high))
      low += 0.01
      high += 0.01
    end

    # Write out distribution csv file
    file = File.open("#{@home}/data/#{@project}_#{type}_#{@run}_distribution.csv", 'w')
    file.write(distribution_range.join(","))
    file.close
  end

  def correlation(type, data_set)

    # Acquire hash of the fields (field => [value1, value2, ...])
    values = Hash.new()
    data_set.each do |item|
      data_set.properties.each do |property|

        field = property.instance_variable_name[1..-1]

        # Update the value for valid category
        if not ignore_field(field)
          category = values[field]
          category = [] if category == nil
          category << item.send(field)
          values[field] = category
        end
      end
    end

    # Calculate the correlation matrix
    Statsample::Analysis.store("Statsample::Bivariate.correlation_matrix") do
      data_set = Hash.new

      values.each do |key,value|
        data_set[key] = value.to_scale
      end

      result = cor(data_set.to_dataset)
      summary(result)
    end

    # Write out correlation matrix file
    file = File.open("#{@home}/data/#{@project}_#{type}_#{@run}_correlation.txt", 'w')
    file.write(Statsample::Analysis.to_text)
    file.close
  end

  def ignore_field(field)
    if field == "id" || field == "project" || field == "run" || field == "class_name" ||
      field == "method_name" || field == "occurs" || field == "usable" ||
      field == "created_at" || field == "updated_at" || field == "tests_touched" ||

      # Mutation Testing
      field == "killed_mutants" ||
      field == "covered_mutants" ||
      field == "generated_mutants" ||
      field == "mutation_score_of_covered_mutants" ||
      field == "mutation_score_of_generated_mutants" ||

      # Mutation Operators
      field == "killed_no_mutation" ||
      field == "total_no_mutation" ||
      field == "killed_replace_constant" ||
      field == "total_replace_constant" ||
      field == "killed_negate_jump" ||
      field == "total_negate_jump" ||
      field == "killed_arithmetic_replace" ||
      field == "total_arithmetic_replace" ||
      field == "killed_remove_call" ||
      field == "total_remove_call" ||
      field == "killed_replace_variable" ||
      field == "total_replace_variable" ||
      field == "killed_absolute_value" ||
      field == "total_absolute_value" ||
      field == "killed_unary_operator" ||
      field == "total_unary_operator" ||
      field == "killed_replace_thread_call" ||
      field == "total_replace_thread_call" ||
      field == "killed_monitor_remove" ||
      field == "total_monitor_remove" ||

      # Class Metrics
      # field == "norm" ||
      # field == "nof" ||
      # field == "nsc" ||
      # field == "nom" ||
      # field == "dit" ||
      # field == "lcom" ||
      # field == "nsm" ||
      # field == "six" ||
      # field == "wmc" ||
      # field == "nsf" ||

      # Method Metrics
      # field == "mloc" ||
      # field == "nbd" ||
      # field == "vg" ||
      # field == "par" ||
      # field == "not" ||

      # Coverage
      # field == "lcov" ||
      # field == "ltot" ||
      # field == "lscor" ||
      # field == "bcov" ||
      # field == "btot" ||
      # field == "bscor" ||
      
      # Accumulated Test Unit Metrics
      # field == "stmloc" ||
      # field == "atmloc" ||
      # field == "stnbd" ||
      # field == "atnbd" ||
      # field == "stvg" ||
      # field == "atvg" ||
      # field == "stpar" ||
      # field == "atpar" ||

      # Accumulated Code Unit Metrics
      # field == "smloc" ||
      # field == "amloc" ||
      # field == "snbd" ||
      # field == "anbd" ||
      # field == "svg" ||
      # field == "avg" ||
      # field == "spar" ||
      # field == "apar" ||

      field == "."
      return true
    else
      return false
    end
  end
end
