require 'csv'
require 'set'

class CoverageMutationScorer

  attr_accessor :project, :run, :operators, :code_units_mutation_data, :method_ocurrence

  def initialize(project, run, operators)
    @project = project
    @run = run
    @operators = operators
    @code_units_mutation_data = Hash.new
    @method_ocurrence = Hash.new
  end

  class CodeUnitMutationData

    attr_accessor :class_name,
                  :method_name,
                  :killed_mutants,
                  :covered_mutants,
                  :killed_no_mutation,
                  :total_no_mutation,
                  :killed_replace_constant,
                  :total_replace_constant,
                  :killed_negate_jump,
                  :total_negate_jump,
                  :killed_arithmetic_replace,
                  :total_arithmetic_replace,
                  :killed_remove_call,
                  :total_remove_call,
                  :killed_replace_variable,
                  :total_replace_variable,
                  :killed_absolute_value,
                  :total_absolute_value,
                  :killed_unary_operator,
                  :total_unary_operator,
                  :killed_replace_thread_call,
                  :total_replace_thread_call,
                  :killed_monitor_remove,
                  :total_monitor_remove,
                  :tests_touched

    def initialize(class_name, method_name)
      @tests_touched = Set.new
      @class_name = class_name
      @method_name = method_name
      @killed_mutants = 0
      @covered_mutants = 0
      @killed_no_mutation = 0
      @total_no_mutation = 0
      @killed_replace_constant = 0
      @total_replace_constant = 0
      @killed_negate_jump = 0
      @total_negate_jump = 0
      @killed_arithmetic_replace = 0
      @total_arithmetic_replace = 0
      @killed_remove_call = 0
      @total_remove_call = 0
      @killed_replace_variable = 0
      @total_replace_variable = 0
      @killed_absolute_value = 0
      @total_absolute_value = 0
      @killed_unary_operator = 0
      @total_unary_operator = 0
      @killed_replace_thread_call = 0
      @total_replace_thread_call = 0
      @killed_monitor_remove = 0
      @total_monitor_remove = 0
    end
  end

  def process

    # Make list of method names that are overloaded
    mutants = MutantData.all(:project => @project, :run => @run)

    # Find the number of occurences for each method (excluding params)
    mutants.all(:fields => [:method_name], :unique => true).each do |mutant|
      short_method_name = mutant.method_name.rpartition('(').first
      value = @method_ocurrence[short_method_name]
      if value == nil
        @method_ocurrence[short_method_name] = 1
      else
        @method_ocurrence[short_method_name] = value + 1
      end
    end

    # Collect class/method data from mutants
    collect_class_method_data(mutants)

    # Add collected data to database
    add_code_unit_data

    puts "[LOG] Updating :occurs => 1"
    MethodData.all(:project => @project, :run => @run, :usable => true).update(:occurs => 1)
    ClassData.all(:project => @project, :run => @run, :usable => true).update(:occurs => 1)

    puts "[LOG] Number of methods=#{MethodData.all(:project => @project, :run => @run, :usable => true).count}"
    puts "[LOG] Number of classes=#{ClassData.all(:project => @project, :run => @run, :usable => true).count}"
  end

  def collect_class_method_data(mutants)
    mutants.each do |mutant|

      short_method_name = mutant.method_name.rpartition('(').first

      # Skip mutants that are part of an overloaded method
      if @method_ocurrence[short_method_name] > 1
        next
      end

      # Only proceed with valid mutants
      if not ignore_mutant(mutant)

        # Acquire the code unit's mutation data
        method_unit = @code_units_mutation_data[short_method_name]
        class_unit = @code_units_mutation_data[mutant.class_name]
        if method_unit == nil
          method_unit = CodeUnitMutationData.new(mutant.class_name, short_method_name)
          @code_units_mutation_data[short_method_name] = method_unit
        end
        if class_unit == nil
          class_unit = CodeUnitMutationData.new(mutant.class_name, nil)
          @code_units_mutation_data[mutant.class_name] = class_unit
        end

        # Add new data to code unit
        method_unit.covered_mutants += 1
        class_unit.covered_mutants += 1
        method_unit.killed_mutants += 1 if mutant.killed
        class_unit.killed_mutants += 1 if mutant.killed

        # Add the mutant type information (kill and total)
        handle_type(mutant, method_unit, class_unit)

        # Add tests touched
        mutant.tests_touched.split(" ").each do |test|
          method_unit.tests_touched.add(test)
          class_unit.tests_touched.add(test)
        end
      end
    end
  end

  def handle_type(mutant, method_unit, class_unit)
    if mutant.type == "NO_MUTATION"
      method_unit.total_no_mutation += 1
      method_unit.killed_no_mutation += 1 if mutant.killed
      class_unit.total_no_mutation += 1
      class_unit.killed_no_mutation += 1 if mutant.killed
    elsif mutant.type == "REPLACE_CONSTANT"
      method_unit.total_no_mutation += 1
      method_unit.killed_no_mutation += 1 if mutant.killed
      class_unit.total_no_mutation += 1
      class_unit.killed_no_mutation += 1 if mutant.killed
    elsif mutant.type == "NEGATE_JUMP"
      method_unit.total_negate_jump += 1
      method_unit.killed_negate_jump += 1 if mutant.killed
      class_unit.total_negate_jump += 1
      class_unit.killed_negate_jump += 1 if mutant.killed
    elsif mutant.type == "ARITHMETIC_REPLACE"
      method_unit.total_arithmetic_replace += 1
      method_unit.killed_arithmetic_replace += 1 if mutant.killed
      class_unit.total_arithmetic_replace += 1
      class_unit.killed_arithmetic_replace += 1 if mutant.killed
    elsif mutant.type == "REMOVE_CALL"
      method_unit.total_remove_call += 1
      method_unit.killed_remove_call += 1 if mutant.killed
      class_unit.total_remove_call += 1
      class_unit.killed_remove_call += 1 if mutant.killed
    elsif mutant.type == "REPLACE_VARIABLE"
      method_unit.total_replace_variable += 1
      method_unit.killed_replace_variable += 1 if mutant.killed
      class_unit.total_replace_variable += 1
      class_unit.killed_replace_variable += 1 if mutant.killed
    elsif mutant.type == "ABSOLUTE_VALUE"
      method_unit.total_absolute_value += 1
      method_unit.killed_absolute_value += 1 if mutant.killed
      class_unit.total_absolute_value += 1
      class_unit.killed_absolute_value += 1 if mutant.killed
    elsif mutant.type == "UNARY_OPERATOR"
      method_unit.total_unary_operator += 1
      method_unit.killed_unary_operator += 1 if mutant.killed
      class_unit.total_unary_operator += 1
      class_unit.killed_unary_operator += 1 if mutant.killed
    elsif mutant.type == "REPLACE_THREAD_CALL"
      method_unit.total_replace_thread_call += 1
      method_unit.killed_replace_thread_call += 1 if mutant.killed
      class_unit.total_replace_thread_call += 1
      class_unit.killed_replace_thread_call += 1 if mutant.killed
    elsif mutant.type == "MONITOR_REMOVE"
      method_unit.total_monitor_remove += 1
      method_unit.killed_monitor_remove += 1 if mutant.killed
      class_unit.total_monitor_remove += 1
      class_unit.killed_monitor_remove += 1 if mutant.killed
    end
  end

  def ignore_mutant(mutant)

    # TODO Add bit about filtering based on threshold for modifications (equivalent)


    # Filter base on the enabled mutation types
    if @operators[mutant.type]
      return false
    else
      return true
    end
  end

  def add_code_unit_data
    @code_units_mutation_data.each do |name, unit|

      # Calculate mutation score
      if unit.killed_mutants > unit.covered_mutants
        mutation_score_of_covered_mutants = 1.to_f
      else
        mutation_score_of_covered_mutants = unit.killed_mutants.to_f / unit.covered_mutants.to_f
      end

      if unit.method_name == nil
        puts "[LOG] Adding Class Mutation Score - #{unit.class_name}"

        # Acquire class data
        class_item = ClassData.first_or_create(
          :project => @project,
          :run => @run,
          :class_name => unit.class_name
        )

        class_item.update(
          :killed_mutants => unit.killed_mutants,
          :covered_mutants => unit.covered_mutants,
          :mutation_score_of_covered_mutants => mutation_score_of_covered_mutants,
          :killed_no_mutation => unit.killed_no_mutation,
          :total_no_mutation => unit.total_no_mutation,
          :killed_replace_constant => unit.killed_replace_constant,
          :total_replace_constant => unit.total_replace_constant,
          :killed_negate_jump => unit.killed_negate_jump,
          :total_negate_jump => unit.total_negate_jump,
          :killed_arithmetic_replace => unit.killed_arithmetic_replace,
          :total_arithmetic_replace => unit.total_arithmetic_replace,
          :killed_remove_call => unit.killed_remove_call,
          :total_remove_call => unit.total_remove_call,
          :killed_replace_variable => unit.killed_replace_variable,
          :total_replace_variable => unit.total_replace_variable,
          :killed_absolute_value => unit.killed_absolute_value,
          :total_absolute_value => unit.total_absolute_value,
          :killed_unary_operator => unit.killed_unary_operator,
          :total_unary_operator => unit.total_unary_operator,
          :killed_replace_thread_call => unit.killed_replace_thread_call,
          :total_replace_thread_call => unit.total_replace_thread_call,
          :killed_monitor_remove => unit.killed_monitor_remove,
          :total_monitor_remove => unit.total_monitor_remove,
          :tests_touched => unit.tests_touched.to_a.join(" ")
        )

      else
        puts "[LOG] Adding Method Mutation Score - #{unit.method_name}"

        # Acquire method data
        method_item = MethodData.first_or_create(
          :project => @project,
          :run => @run,
          :class_name => unit.class_name,
          :method_name => unit.method_name
        )

        method_item.update(
          :killed_mutants => unit.killed_mutants,
          :covered_mutants => unit.covered_mutants,
          :mutation_score_of_covered_mutants => mutation_score_of_covered_mutants,
          :killed_no_mutation => unit.killed_no_mutation,
          :total_no_mutation => unit.total_no_mutation,
          :killed_replace_constant => unit.killed_replace_constant,
          :total_replace_constant => unit.total_replace_constant,
          :killed_negate_jump => unit.killed_negate_jump,
          :total_negate_jump => unit.total_negate_jump,
          :killed_arithmetic_replace => unit.killed_arithmetic_replace,
          :total_arithmetic_replace => unit.total_arithmetic_replace,
          :killed_remove_call => unit.killed_remove_call,
          :total_remove_call => unit.total_remove_call,
          :killed_replace_variable => unit.killed_replace_variable,
          :total_replace_variable => unit.total_replace_variable,
          :killed_absolute_value => unit.killed_absolute_value,
          :total_absolute_value => unit.total_absolute_value,
          :killed_unary_operator => unit.killed_unary_operator,
          :total_unary_operator => unit.total_unary_operator,
          :killed_replace_thread_call => unit.killed_replace_thread_call,
          :total_replace_thread_call => unit.total_replace_thread_call,
          :killed_monitor_remove => unit.killed_monitor_remove,
          :total_monitor_remove => unit.total_monitor_remove,
          :tests_touched => unit.tests_touched.to_a.join(" ")
        )
      end
    end
  end
end
