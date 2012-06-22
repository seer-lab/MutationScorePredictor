class MetricLibsvmSynthesizer

  attr_accessor :projects, :home

  def initialize(projects, home, predict=false)
    @projects = projects
    @home = home
    @predict = predict
  end

  def make_libsvm(data_set, type, bounds, indexes=nil)
    # Split up data into sections
    sections = []
    min_size = 0
    divisor = 1
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

    min_size = min_size / divisor
    used_count = 0
    total_count = 0
    content = ""
    section_count = 0
    selected_indexes = []
    sections.each do |section|

      new_section = []
      # Print section ranges with inclusive/exclusive bounds
      if section_count == sections.size - 1
        puts "[LOG] Found #{section.count} items in [#{bounds[section_count][0]}-#{bounds[section_count][1]}]"
      else
        puts "[LOG] Found #{section.count} items in [#{bounds[section_count][0]}-#{bounds[section_count][1]})"
      end

      if !@predict
        # Undersample using a unique random set of indexes
        puts "[LOG] Undersampling section to #{min_size} items"
        selected_indexes[section_count] = (0..section.size-1).to_a.sort{ @@evaluation_seed.rand() - 0.5 }[0..min_size-1]
        selected_indexes[section_count].each do |i|
          new_section << section[i]
        end
      elsif indexes != nil
        # Exclude the used indexes from the predicted set
        section.size.times do |i|
          new_section << section[i] if !indexes[section_count].include?(i)
        end
        puts "[LOG] Using #{new_section.size} items, which excludes previously used items"
      else
        # Use complete section
        puts "[LOG] Using all #{section.size} items"
        new_section = section
      end

      # Keep track of the number of items used from this data set
      used_count += new_section.size
      total_count += section.size

      # Format the .libsvm file using selected items
      new_section.each do |item|
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
      section_count += 1
    end

    # Write out .libsvm files
    file = File.open("#{@home}/data/evaluation_projects_#{type}.libsvm", 'w')
    file.write(content)
    file.close

    puts "[LOG] .libsvm file uses #{used_count}/#{total_count} (#{used_count*100/total_count.to_f}\%) of the available data"
    return selected_indexes
  end

  def process(type, indexes=nil)
    if type == "class"
      data_set = ClassData.all(:project => @projects, :usable => true, :order => [:mutation_score_of_covered_mutants.asc])
    elsif type == "method"
      data_set = MethodData.all(:project => @projects, :usable => true, :order => [:mutation_score_of_covered_mutants.asc])
    else
      puts "[ERROR] Type was not {class||method}"
      return 0
    end

    # Use bound values
    bounds = []
    bounds << [0.00, 0.70]
    bounds << [0.70, 0.90]
    bounds << [0.90, 1.00]

    # Create file contents with appropriate categories
    puts "[LOG] Making #{type} .libsvm"
    indexes = make_libsvm(data_set, type, bounds, indexes)

    return indexes
  end

  def statistics(type)
    if type == "class"
      data_set = ClassData.all(:project => @projects, :usable => true, :order => [:mutation_score_of_covered_mutants.asc])
    elsif type == "method"
      data_set = MethodData.all(:project => @projects, :usable => true, :order => [:mutation_score_of_covered_mutants.asc])
    else
      puts "[ERROR] Type was not {class||method}"
      return 0
    end

    # Calculate the distribution
    puts "[LOG] Calculating mutation score distributions and statistic summary"
    data = distribution_percentage(type, data_set, "mutation_score_of_covered_mutants")
    summary_statistics(type, data, "mutation_score_of_covered_mutants")

    puts "[LOG] Calculating covered mutant distributions and statistic summary"
    data = distribution_whole_number(type, data_set, "covered_mutants")
    summary_statistics(type, data, "covered_mutants")

    # Calculate the correlation matrix
    puts "[LOG] Calculating correlation matrix"
    correlation(type, data_set)
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
      # field == "total_replace_constant" ||
      field == "killed_negate_jump" ||
      # field == "total_negate_jump" ||
      field == "killed_arithmetic_replace" ||
      # field == "total_arithmetic_replace" ||
      field == "killed_remove_call" ||
      # field == "total_remove_call" ||
      field == "killed_replace_variable" ||
      # field == "total_replace_variable" ||
      field == "killed_absolute_value" ||
      # field == "total_absolute_value" ||
      field == "killed_unary_operator" ||
      # field == "total_unary_operator" ||
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
