class ClassData

  include DataMapper::Resource

  property :id, Serial

  # Source Unit
  property :project, Text, :required => true
  property :run, Integer, :default => 0, :required => false  # TODO phase this out
  property :class_name, Text, :required => true
  property :occurs, Integer, :default => 0
  property :usable, Boolean, :default => true

  # Mutation Testing
  property :killed_mutants, Integer, :default => 0
  property :covered_mutants, Integer, :default => 0
  property :generated_mutants, Integer, :default => 0
  property :mutation_score_of_covered_mutants, Float, :default => 0.0
  property :mutation_score_of_generated_mutants, Float, :default => 0.0
  property :tests_touched, Text, :default => "", :length => 1000000

  # Mutation Types
  property :killed_no_mutation, Integer, :default => 0
  property :total_no_mutation, Integer, :default => 0
  property :killed_replace_constant, Integer, :default => 0
  property :total_replace_constant, Integer, :default => 0
  property :killed_negate_jump, Integer, :default => 0
  property :total_negate_jump, Integer, :default => 0
  property :killed_arithmetic_replace, Integer, :default => 0
  property :total_arithmetic_replace, Integer, :default => 0
  property :killed_remove_call, Integer, :default => 0
  property :total_remove_call, Integer, :default => 0
  property :killed_replace_variable, Integer, :default => 0
  property :total_replace_variable, Integer, :default => 0
  property :killed_absolute_value, Integer, :default => 0
  property :total_absolute_value, Integer, :default => 0
  property :killed_unary_operator, Integer, :default => 0
  property :total_unary_operator, Integer, :default => 0
  property :killed_replace_thread_call, Integer, :default => 0
  property :total_replace_thread_call, Integer, :default => 0
  property :killed_monitor_remove, Integer, :default => 0
  property :total_monitor_remove, Integer, :default => 0

  # Class Source Metrics
  property :norm, Integer, :default => 0
  property :nof, Integer, :default => 0
  property :nsc, Integer, :default => 0
  property :nom, Integer, :default => 0
  property :dit, Integer, :default => 0
  property :lcom, Integer, :default => 0
  property :nsm, Integer, :default => 0
  property :six, Integer, :default => 0
  property :wmc, Integer, :default => 0
  property :nsf, Integer, :default => 0

  # Accumulated Method Metrics
  property :smloc, Integer, :default => 0
  property :amloc, Float, :default => 0.0
  property :snbd, Integer, :default => 0
  property :anbd, Float, :default => 0.0
  property :svg, Integer, :default => 0
  property :avg, Float, :default => 0.0
  property :spar, Integer, :default => 0
  property :apar, Float, :default => 0.0

  # Accumulated Test Method Metrics
  property :stmloc, Integer, :default => 0
  property :atmloc, Float, :default => 0.0
  property :stnbd, Integer, :default => 0
  property :atnbd, Float, :default => 0.0
  property :stvg, Integer, :default => 0
  property :atvg, Float, :default => 0.0
  property :stpar, Integer, :default => 0
  property :atpar, Float, :default => 0.0

  # Source Test Metrics
  property :lcov, Integer, :default => 0
  property :ltot, Integer, :default => 0
  property :lscor, Float, :default => 0.0
  property :bcov, Integer, :default => 0
  property :btot, Integer, :default => 0
  property :bscor, Float, :default => 0.0
  property :not, Integer, :default => 0

  # Time
  property :created_at, DateTime
  property :updated_at, DateTime
end
