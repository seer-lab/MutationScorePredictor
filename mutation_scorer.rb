require 'csv'

mutation_operators = Hash.new(0)

killed_classes = Hash.new(0)
total_class_mutations = Hash.new(0)

killed_methods = Hash.new(0)
total_method_mutations = Hash.new(0)

if ARGV[0] == nil
  raise "ERROR: No project name"
else
  project_name = ARGV[0]
end

if ARGV[1] == nil
  raise "ERROR: No file specified"
else
  file = ARGV[1]
end

# row[1] = killed | row[19] = mutation | row[20] = class | row[21] = method
CSV.foreach(file, :col_sep => ';') do |row|
  
  # Skip the first row of field names
  if row[1] == "KILLED"
    next
  end

  # Track mutation operators
  mutation_operators[row[19]] += 1

  # Track classes and killed classes
  total_class_mutations[row[20]] += 1
  if row[1] == 'true'
    killed_classes[row[20]] += 1
  end

  # Track methods and killed methods
  total_method_mutations[row[20] + "." + row[21]] += 1
  if row[1] == 'true'
    killed_methods[row[20] + "." + row[21]] += 1
  end
end

content = "NAME;KILLED;TOTAL;SCORE"
killed_classes.each { |name, killed| 
  content << "\n#{name};#{killed};#{total_class_mutations[name]};" + 
       (killed.to_f / total_class_mutations[name].to_f * 100).to_s
}
file = File.open("#{project_name}_class_mutation.score", 'w')
file.write(content)
file.close

content = "NAME;KILLED;TOTAL;SCORE"
killed_methods.each { |name, killed| 
  content << "\n#{name};#{killed};#{total_method_mutations[name]};" + 
       (killed.to_f / total_method_mutations[name].to_f * 100).to_s
}
file = File.open("#{project_name}_method_mutation.score", 'w')
file.write(content)
file.close

content = "OPERATOR;TOTAL"
mutation_operators.each { |operator, count| 
  content << "\n#{operator};#{count}"
}
file = File.open("#{project_name}_mutation.operators", 'w')
file.write(content)
file.close
