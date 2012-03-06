require 'csv'

class MutationScorer

  attr_reader = :project, :run, :class_file, :method_file

  def initialize(project, run, class_file, method_file)
    @project = project
    @run = run
    @class_file = class_file
    @method_file = method_file
  end

  def process

    # Extract data for the classes
    CSV.foreach(@class_file, :col_sep => ',') do |row|

    # Skip the first row of field names
      if row[0] == "CLASS_NAME"
        next
      end

      puts "[LOG] Adding Mutation Score - #{row[0]}"

      # Acquire class data
      class_item = ClassData.first_or_create(
        :project => @project,
        :run => @run,
        :class_name => row[0]
      )

      class_item.update(
        :occurs => class_item.occurs + 1,
        :killed_mutants => row[1],
        :covered_mutants => row[2],
        :generated_mutants => row[3],
        :mutation_score_of_covered_mutants => row[4],
        :mutation_score_of_generated_mutants => row[5],
        :killed_no_mutation => row[6],
        :total_no_mutation => row[7],
        :killed_replace_constant => row[8],
        :total_replace_constant => row[9],
        :killed_negate_jump => row[10],
        :total_negate_jump => row[11],
        :killed_arithmetic_replace => row[12],
        :total_arithmetic_replace => row[13],
        :killed_remove_call => row[14],
        :total_remove_call => row[15],
        :killed_replace_variable => row[16],
        :total_replace_variable => row[17],
        :killed_absolute_value => row[18],
        :total_absolute_value => row[19],
        :killed_unary_operator => row[20],
        :total_unary_operator => row[21],
        :killed_replace_thread_call => row[22],
        :total_replace_thread_call => row[23],
        :killed_monitor_remove => row[24],
        :total_monitor_remove => row[25],
        :tests_touched => row[26]
      )
    end

    # Extract data for the methods
    CSV.foreach(@method_file, :col_sep => ',') do |row|

      # Skip the first row of field names
      if row[0] == "CLASS_NAME"
        next
      end

      puts "[LOG] Adding Mutation Score - #{row[1].rpartition("(").first}"

      # Acquire method data
      method_item = MethodData.first_or_create(
        :project => @project,
        :run => @run,
        :class_name => row[0],
        :method_name => row[1].rpartition('(').first
      )

      # Update method data with values
      method_item.update(
        :occurs => method_item.occurs + 1,
        :killed_mutants => row[2],
        :covered_mutants => row[3],
        :generated_mutants => row[4],
        :mutation_score_of_covered_mutants => row[5],
        :mutation_score_of_generated_mutants => row[6],
        :killed_no_mutation => row[7],
        :total_no_mutation => row[8],
        :killed_replace_constant => row[9],
        :total_replace_constant => row[10],
        :killed_negate_jump => row[11],
        :total_negate_jump => row[12],
        :killed_arithmetic_replace => row[13],
        :total_arithmetic_replace => row[14],
        :killed_remove_call => row[15],
        :total_remove_call => row[16],
        :killed_replace_variable => row[17],
        :total_replace_variable => row[18],
        :killed_absolute_value => row[19],
        :total_absolute_value => row[20],
        :killed_unary_operator => row[21],
        :total_unary_operator => row[22],
        :killed_replace_thread_call => row[23],
        :total_replace_thread_call => row[24],
        :killed_monitor_remove => row[25],
        :total_monitor_remove => row[26],
        :tests_touched => row[27]
      )
    end

    puts "[LOG] Number of methods=#{MethodData.all(:project => @project, :run => @run, :usable => true).count}"
    puts "[LOG] Number of classes=#{ClassData.all(:project => @project, :run => @run, :usable => true).count}"
    puts "[LOG] Removing items that were duplicated (occurs>1)"
    MethodData.all(:project => @project, :run => @run, :usable => true, :occurs.gt => 1).update(:usable => false)
    ClassData.all(:project => @project, :run => @run, :usable => true, :occurs.gt => 1).update(:usable => false)
    puts "[LOG] Number of methods=#{MethodData.all(:project => @project, :run => @run, :usable => true).count}"
    puts "[LOG] Number of classes=#{ClassData.all(:project => @project, :run => @run, :usable => true).count}"

  end
end
