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
        :tests_touched => row[6]
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
        :tests_touched => row[7]
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
