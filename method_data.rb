class MethodData

  include DataMapper::Resource

  property :id, Serial

  # Source Unit
  property :project, Text, :required => true
  property :run, Integer, :required => true
  property :class_name, Text, :required => true
  property :method_name, Text, :required => true
  property :occurs, Integer, :default => 0
  property :usable, Boolean, :default => true

  # Mutation Testing
  property :killed_mutants, Integer, :default => 0
  property :covered_mutants, Integer, :default => 0
  property :generated_mutants, Integer, :default => 0
  property :mutation_score_of_covered_mutants, Float, :default => 0.0
  property :mutation_score_of_generated_mutants, Float, :default => 0.0
  property :tests_touched, Text, :default => "", :length => 1000000

  # Method Source Metrics
  property :mloc, Integer, :default => 0
  property :nbd, Integer, :default => 0
  property :vg, Integer, :default => 0
  property :par, Integer, :default => 0
  property :not, Integer, :default => 0

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

  # Time
  property :created_at, DateTime
  property :updated_at, DateTime
end
