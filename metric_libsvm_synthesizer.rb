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


    # # Figure the ranges out
    # items_per_range = data_set.count / 2
    # lower_break = data_set[items_per_range].mutation_score_of_covered_mutants
    # ap lower_break
    # upper_break = -1

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

        if field == "id" || field == "project" || field == "run" || field == "class_name" ||
          field == "method_name" || field == "occurs" || field == "usable" || field == "killed_mutants" ||
          field == "covered_mutants" || field == "generated_mutants" ||
          field == "mutation_score_of_covered_mutants" || field == "mutation_score_of_generated_mutants" ||
          field == "tests_touched" || field == "created_at" || field == "updated_at" ||

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

        else
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
end
