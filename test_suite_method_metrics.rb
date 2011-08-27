require 'csv'

@project_location = nil
@labels_file = nil
@libsvm_file = nil

# Directory for project
if ARGV[0] == nil
  raise "ERROR: No project directory specified"
else
  @project_location = ARGV[0]
end

# File for labels
if ARGV[1] == nil
  raise "ERROR: No labels file specified"
else
  @labels_file = ARGV[1]
end

# File for libsvm
if ARGV[2] == nil
  raise "ERROR: No libsvm file specified"
else
  @libsvm_file = ARGV[2]
end

def acquire_tests_for_mutants(log)
  mutation_count = 1
  mutation_id = nil
  tests_for_mutants = Hash.new  # mutation_id => [test1,test2,...]
  tests = []  # Set of tests for a mutant_id

  log.each_line do |line|

    if line.include?("-  Applying #{mutation_count}th mutation with id")
      tests = []
      results = line.scan(/Applying \d+th mutation with id (\d+). Running (\d+) test/)
      mutation_id = results[0][0].to_s
      mutation_count += 1
    elsif line.include?("Running test:")
      tests << line.scan(/Running test:\s+([\w|\.|$|#]*)/)[0][0].to_s
    elsif line.include?("-  Disabling mutation:")
      # Save this mutation_id and tests, then reset the tests
      tests_for_mutants[mutation_id] = tests
      tests = []
    end    

    if line.include?("-  Storing results for")
      break;
    end
  end
  return tests_for_mutants
end

def hash_ids_to_methods(mutant_hash)
  mutant_to_methods = Hash.new  # mutant_id => method

  # row[0] = id | row[19] = mutation | row[20] = class | row[21] = method
  CSV.foreach("#{@project_location}analyze.csv", :col_sep => ';') do |row|

    # Get mutant method (package.class.method) from the id
    if mutant_hash.has_key?(row[0].to_s)
      mutant_to_methods[row[0].to_s] = row[20] + "." + row[21]
    end
  end
  return mutant_to_methods
end

def get_tests_for_methods(mutation_log_directory)
  # Go through each log file and acquire the tests for mutant_ids
  tests_for_all_mutants = Hash.new 
  Dir.entries(mutation_log_directory).each do |file|
    if file.include?("output-runMutation")
      log = File.read("#{mutation_log_directory}#{file}")
      tests_for_mutants = acquire_tests_for_mutants(log)
      tests_for_all_mutants = tests_for_all_mutants.merge(tests_for_mutants)
    end
  end

  # tests_for_all_mutants (mutant_id => [tests])
  # methods (mutant_id => method)
  methods = hash_ids_to_methods(tests_for_all_mutants)

  # Find the union of tests per method
  tests_for_methods = Hash.new
  methods.each do |mutation_id, method|
    if tests_for_methods[method] == nil
      tests_for_methods[method] = tests_for_all_mutants[mutation_id]
    else
      new_array = tests_for_methods[method] + tests_for_all_mutants[mutation_id]
      tests_for_methods[method] = new_array.uniq
    end
  end
  return tests_for_methods
end

def get_line_mapping(labels)

  # Acquire the line mapping for the method and the libsvm file
  # method => line_number
  line_mapping = Hash.new()
  line_number = 1

  labels.each do |label|

    # Completed the mapping, rest are comments
    if label[0] == "#"
      break
    end

    line_mapping[label] = line_number
    line_number += 1
  end
  return line_mapping
end

def get_sum(metric)
  sum = 0
  metric.map{ |value|
    sum += value
  }
  return sum
end

def get_avg(metric)
  return get_sum(metric).to_f / metric.size 
end

def add_test_metrics(tests_for_methods, line_mapping, labels, libsvm)

  new_labels = ""
  new_libsvm = ""

  # For a method get a list of metrics from each test's methods
  tests_for_methods.each do |method,tests|
    
    # For each test in this method gather the metrics
    id_MLOC = []
    id_NBD = []
    id_VG = []
    id_PAR = []
    tests.each do |test|
      
      # Get test's method metrics from libsvm
      if line_mapping[test] == nil
        # Test methods are not found due to the overloading naming convention
        # puts "test: " + test + " not found for method" + method
      else

        # Extract metrics for the libsvm line
        metrics = libsvm[line_mapping[test]].scan(/1:(\d+) 2:(\d+) 3:(\d+) 4:(\d+)/)
        id_MLOC << metrics[0][0].to_i
        id_NBD << metrics[0][1].to_i
        id_VG << metrics[0][2].to_i
        id_PAR << metrics[0][3].to_i
      end
    end

    # Construct new features
    features = " 5:#{tests.size}" \
               " 6:#{get_sum(id_MLOC)} 7:#{get_avg(id_MLOC)}" \
               " 8:#{get_sum(id_NBD)} 9:#{get_avg(id_NBD)}" \
               " 10:#{get_sum(id_VG)} 11:#{get_avg(id_VG)}" \
               " 12:#{get_sum(id_PAR)} 13:#{get_avg(id_PAR)}"
    
    # Append new feature to libsvm line for the method
    if line_mapping[method] == nil
      # Test methods are not found due to the overloading naming convention
      #puts "test: " + test + " not found for method" + method
    else

      # Add features to new libsvm file, and the method to the labels file
      new_labels += "#{method}\n"
      new_libsvm += "#{libsvm[line_mapping[method]]} #{features}\n"
    end
  end
  return new_labels, new_libsvm
end

# Acquire the tests used for each method
tests_for_methods = get_tests_for_methods("#{@project_location}mutation-files/")

# Acquire the label and libsvm content in an array of lines
labels = File.read(@labels_file).split(/\r?\n|\r/)
libsvm = File.read(@libsvm_file).split(/\r?\n|\r/)

# Acquire line mapping of the labels
line_mapping = get_line_mapping(labels)

# Apply test suite metrics to the original libsvm, adjusting the labels as well
new_labels, new_libsvm = add_test_metrics(tests_for_methods, line_mapping, 
                                          labels, libsvm)

# Add comments about the new metrics in the labels file
new_labels += "# ['MLOC', 'NBD', 'VG', 'PAR', 'NOT', 'STMLOC', 'ATMLOC', " \
              "'STNBD', 'ATNBD', 'STVG', 'ATVG', 'STPAR', 'ATPAR']\n"
new_labels += "# Matches line-to-line with the corresponding metrics file " \
              "(no labels extension)"

# Write changes
puts "[LOG] Overwriting libsvm and labels file with new data on test metrics"
file = File.open(@labels_file, 'w')
file.write(new_labels)
file.close

file = File.open(@libsvm_file, 'w')
file.write(new_libsvm)
file.close
