class MetricLibsvmSynthesizer

  attr_accessor :projects, :home

  def initialize(projects, home)
    @projects = projects
    @home = home
  end

  def make_libsvm(data_set, bounds)

    # Split up data into sections
    sections = []
    min_size = 0
    method_sections = []
    bound_counter = 1
    bounds.each do |bound|

      # Inclusive lower range and exclusive upper range - inclusive on both on last range
      if bound_counter == bounds.size
        sections << data_set.all(:mutation_score_of_covered_mutants.gte => bound[0], :mutation_score_of_covered_mutants.lte => bound[1])
      else
        sections << data_set.all(:mutation_score_of_covered_mutants.gte => bound[0], :mutation_score_of_covered_mutants.lt => bound[1])
      end
      bound_counter += 1

      min_size = sections.last.count if min_size == 0 || sections.last.count < min_size
    end

    content = ""
    section_count = 0
    sections.each do |section|

      # Print section ranges with inclusive/exclusive bounds
      if section_count == sections.size - 1
        puts "[LOG] #{section.count} items in [#{bounds[section_count][0]}-#{bounds[section_count][1]}]"
      else
        puts "[LOG] #{section.count} items in [#{bounds[section_count][0]}-#{bounds[section_count][1]})"
      end
      section_count += 1

      if @@evaluation_under_sample
        puts "[LOG] Undersampling section to #{min_size} items"
        section = section.sample(min_size, random: @@evaluation_seed)
      end

      section.each do |item|
        content += section_count.to_s + " "

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
    end
    return content
  end

  def process

    class_data = ClassData.all(:project => @projects, :usable => true, :order => [:mutation_score_of_covered_mutants.asc])
    method_data = MethodData.all(:project => @projects, :usable => true, :order => [:mutation_score_of_covered_mutants.asc])

    # Use bound values
    class_bounds = []
    class_bounds << [0.00, 0.70]
    class_bounds << [0.70, 0.90]
    class_bounds << [0.90, 1.00]
    method_bounds = []
    method_bounds << [0.00, 0.70]
    method_bounds << [0.70, 0.90]
    method_bounds << [0.90, 1.00]

    # Create file contents with appropriate categories
    puts "[LOG] Making class .libsvm"
    class_libsvm = make_libsvm(class_data, class_bounds)
    puts "[LOG] Making method .libsvm"
    method_libsvm = make_libsvm(method_data, method_bounds)

    # Write out .libsvm files
    file = File.open("#{@home}/data/evaluation_projects_class.libsvm", 'w')
    file.write(class_libsvm)
    file.close

    file = File.open("#{@home}/data/evaluation_projects_method.libsvm", 'w')
    file.write(method_libsvm)
    file.close
  end

  def statistics
    class_data = ClassData.all(:project => @projects, :usable => true, :order => [:mutation_score_of_covered_mutants.asc])
    method_data = MethodData.all(:project => @projects, :usable => true, :order => [:mutation_score_of_covered_mutants.asc])

    # Calculate the distribution
    puts "[LOG] Calculating mutation score distributions and statistic summary"
    data = distribution_percentage("class", class_data, "mutation_score_of_covered_mutants")
    summary_statistics("class", data, "mutation_score_of_covered_mutants")
    data = distribution_percentage("method", method_data, "mutation_score_of_covered_mutants")
    summary_statistics("method", data, "mutation_score_of_covered_mutants")

    puts "[LOG] Calculating covered mutant distributions and statistic summary"
    data = distribution_whole_number("class", class_data, "covered_mutants")
    summary_statistics("class", data, "covered_mutants")
    data = distribution_whole_number("method", method_data, "covered_mutants")
    summary_statistics("method", data, "covered_mutants")

    # Calculate the correlation matrix
    puts "[LOG] Calculating correlation matrix"
    correlation("class", class_data)
    correlation("method", method_data)

    puts "[LOG] Data can be found in the #{@home}/data/ directory"
  end

  def distribution_percentage(type, data_set, attribute)
    raw_data = []
    low = 0.00
    high = 0.01

    # Collect raw data
    100.times do |i|

      # Inclusive lower range and exclusive upper range - inclusive on both on last range
      if i == 99
        raw_data << data_set.count(attribute.to_sym.gte => low, attribute.to_sym.lte => high)
      else
        raw_data << data_set.count(attribute.to_sym.gte => low, attribute.to_sym.lt => high)
      end

      low += 0.01
      high += 0.01
    end

    # Arrange data for distribution output
    distribution_range = []
    100.times do |i|
      distribution_range << (i.to_s + " " + raw_data[i].to_s)
    end

    # Write out distribution csv file
    file = File.open("#{@home}/data/#{type}_#{attribute}_distribution.txt", 'w')
    file.write(distribution_range.join("\n"))
    file.close

    return raw_data
  end

  def distribution_whole_number(type, data_set, attribute)
    raw_data = []
    min = data_set.min(attribute.to_sym, :conditions => [ 'usable = ?', true])
    max = data_set.max(attribute.to_sym, :conditions => [ 'usable = ?', true]) + 1
    low = min
    high = low + 1

    # Collect raw data
    (max-min).times do |i|

      value = min + i
      # Inclusive lower range and exclusive upper range - inclusive on both on last range
      if i == high
        raw_data << data_set.count(attribute.to_sym.gte => low, attribute.to_sym.lte => high)
      else
        raw_data << data_set.count(attribute.to_sym.gte => low, attribute.to_sym.lt => high)
      end

      low += 1
      high += 1
    end

    # Arrange data for distribution output
    distribution_range = []
    (max-min).times do |i|
      distribution_range << ((i+1).to_s + " " + raw_data[i].to_s)
    end

    # Write out distribution csv file
    file = File.open("#{@home}/data/#{type}_#{attribute}_distribution.txt", 'w')
    file.write(distribution_range.join("\n"))
    file.close

    return raw_data
  end

  def summary_statistics(type, data_set, attribute)
    content = []
    percentiles = [25,50,75]  # Must be in ascending order
    percentile_indexes = calculate_percentiles(percentiles, data_set)

    (percentiles.size).times do |i|
      content << "#{percentiles[i]}-percentile-index: #{percentile_indexes[i]}"
    end

    scale_data = data_set.to_scale
    content << "count: #{scale_data.size}"
    content << "min: #{scale_data.min}"
    content << "max: #{scale_data.max}"
    content << "sum: #{scale_data.sum}"

    # Write out summary statistics file
    file = File.open("#{@home}/data/#{type}_#{attribute}_statistics_summary.txt", 'w')
    file.write(content.join("\n"))
    file.close
  end

  def calculate_percentiles(percentiles, raw_data)
    sum = raw_data.inject(:+)
    count = raw_data.count
    total = 0
    percentile_indexes = []
    current_percentile = 0

    count.times do |i|
      total += raw_data[i]

      while total >= percentiles[current_percentile]*0.01*sum
        percentile_indexes << i
        current_percentile += 1
        break if percentiles[current_percentile] == nil
      end

      break if percentiles[current_percentile] == nil
    end

    return percentile_indexes
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
    file = File.open("#{@home}/data/evaluation_projects_#{type}_correlation.txt", 'w')
    file.write(Statsample::Analysis.to_text)
    file.close
  end

  def ignore_field(field)
    if field == "id" || field == "project" || field == "run" || field == "class_name" ||
      field == "method_name" || field == "occurs" || field == "usable" ||
      field == "created_at" || field == "updated_at" || field == "tests_touched" ||

      # Mutation Testing
      field == "killed_mutants" ||
      # field == "covered_mutants" ||
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
      field == "lcov" ||
      field == "ltot" ||
      field == "lscor" ||
      # field == "bcov" ||
      # field == "btot" ||
      field == "bscor" ||

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
