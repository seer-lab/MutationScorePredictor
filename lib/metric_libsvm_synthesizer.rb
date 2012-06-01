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
    bounds.each do |bound|
      sections << data_set.all(:mutation_score_of_covered_mutants.gte => bound[0], :mutation_score_of_covered_mutants.lte => bound[1])
      min_size = sections.last.count if min_size == 0 || sections.last.count < min_size
    end

    content = ""
    section_count = 0
    sections.each do |section|

      puts "[LOG] #{section.count} items in [#{bounds[section_count][0]}-#{bounds[section_count][1]}]"
      section_count += 1

      section.sample(min_size, random: @@evaluation_seed).each do |item|
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
    method_bounds << [0.0, 0.70]
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
    file = File.open("#{@home}/data/evaluation_projects_#{type}_distribution.csv", 'w')
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
