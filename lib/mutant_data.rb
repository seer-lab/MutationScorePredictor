class MutantData

  include DataMapper::Resource

  property :id, Serial

  # Source Unit
  property :project, Text, :required => true
  property :run, Integer, :default => 0, :required => false  # TODO phase this out
  property :class_name, Text, :required => true
  property :method_name, Text, :required => true
  property :line_number, Integer, :required => true

  # Mutant Properties
  property :mutant_id, Integer, :required => true
  property :killed, Boolean, :required => true
  property :type, Text, :required => true
  property :methods_modified_all, Integer
  property :tests_touched, Text, :default => "", :length => 1000000, :required => true

  # Time
  property :created_at, DateTime
  property :updated_at, DateTime
end
