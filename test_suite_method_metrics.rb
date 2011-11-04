require 'csv'
require 'nokogiri'

class MethodCoverage
  attr_accessor :package_name, :source_name, :class_name, :method_name,
                :line_covered, :line_total, :block_covered, :block_total

  def unit_name()
    return "#{@package_name}.#{class_name}.#{method_name}"
  end
end

class TestSuiteMethodMetrics

  attr_reader = :project_location, :labels_file, :libsvm_file

  def initialize(project_location, labels_file, libsvm_file)
    @project_location = project_location
    @labels_file = labels_file
    @libsvm_file = libsvm_file
  end

  def acquire_tests_for_mutants(log)
    mutation_count = 1
    mutation_id = nil
    tests_for_mutants = Hash.new  # mutation_id => [test1,test2,...]
    tests = []  # Set of tests for a mutant_id

    log.each_line do |line|

      if line.include?("-  Applying #{mutation_count}th mutation with id")
        tests = []
        regex = /Applying \d+th mutation with id (\d+). Running (\d+) test/
        mutation_id = line.scan(regex)[0][0].to_s
        mutation_count += 1
      elsif line.include?("Running test:")
        test = line.scan(/Running test:\s+([\w|\.|$|#]*)/)[0][0].to_s
        tests << test
      elsif line.include?("-  Disabling mutation:")
        # Save this mutation_id and tests, then reset the tests
        tests_for_mutants[mutation_id] = tests.sort
        tests = []
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
        tests_for_methods[method] = tests_for_all_mutants[mutation_id].uniq
      else
        new_array = tests_for_methods[method] +
                      tests_for_all_mutants[mutation_id]
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
    if metric.size == 0
      return 0
    else
      return get_sum(metric).to_f / metric.size
    end
  end

  def add_test_metrics(tests_for_methods, line_mapping, labels, libsvm,
                       method_coverage)
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
        if line_mapping[test] == nil || libsvm[line_mapping[test]] == nil
          # An abstract test method was encountered 
          puts "[WARNING] Ignoring encountered abstract test case #{test}"
        else
          # Extract metrics for the libsvm line
          regex = /1:(\d+) 2:(\d+) 3:(\d+) 4:(\d+)/
          metrics = libsvm[line_mapping[test]].scan(regex)
          id_MLOC << metrics[0][0].to_i
          id_NBD << metrics[0][1].to_i
          id_VG << metrics[0][2].to_i
          id_PAR << metrics[0][3].to_i
        end
      end

      if method_coverage[method] == nil
        puts "No coverage for method " + method
      else
        line_score = method_coverage[method].line_covered /
                     method_coverage[method].line_total * 100
        block_score = method_coverage[method].block_covered /
                     method_coverage[method].block_total * 100
        # Construct new features
        features = "5:#{tests.size}" \
                   " 6:#{get_sum(id_MLOC)} 7:#{get_avg(id_MLOC)}" \
                   " 8:#{get_sum(id_NBD)} 9:#{get_avg(id_NBD)}" \
                   " 10:#{get_sum(id_VG)} 11:#{get_avg(id_VG)}" \
                   " 12:#{get_sum(id_PAR)} 13:#{get_avg(id_PAR)}" \
                   " 14:#{method_coverage[method].line_covered}" \
                   " 15:#{method_coverage[method].line_total}" \
                   " 16:#{line_score}" \
                   " 17:#{method_coverage[method].block_covered}" \
                   " 18:#{method_coverage[method].block_total}" \
                   " 19:#{block_score}"

        # Append new feature to libsvm line for the method
        if line_mapping[method] == nil
          # Test methods are not found due to the overloading naming convention
          puts "[WARNING] Ignoring overloaded/anonymous method #{method}"
        else
          # Add features to new libsvm file, and the method to the labels file
          new_labels += "#{method}\n"
          new_libsvm += "#{libsvm[line_mapping[method]]} #{features}\n"
        end
      end
    end
    return new_labels, new_libsvm
  end

  def extract_line_block_coverage(tests_for_methods)
    method_coverage = Hash.new
    c = 1
    # For each method, find the coverage of the tests
    tests_for_methods.each do |method,tests|

      # Parse the XML coverage file
      puts "[LOG] Extracting coverage data from ./data/coverage#{c}.xml"
      doc = Nokogiri::XML(File.open("./data/coverage#{c}.xml"))

      doc.xpath("//package//srcfile//class//method").each do |method_node|

        method_name = method_node.attr("name")

        class_node = method_node.parent
        class_name = class_node.attr("name")
        
        srcfile_node = class_node.parent
        srcfile_name = srcfile_node.attr("name")

        package_node = srcfile_node.parent
        package_name = package_node.attr("name")

        coverage = MethodCoverage.new
        coverage.package_name = package_name
        coverage.source_name = srcfile_name
        coverage.class_name = class_name
        coverage.method_name = method_name.scan(/(\w+)/)[0][0]

        # Acquire coverage only if the method of the coverage file
        if coverage.unit_name == method
          method_node.children.each do |coverage_node|
            
            if coverage_node.attr("type") != nil and
                coverage_node.attr("value") != nil
              type = coverage_node.attr("type").scan(/(line|block)/)[0][0]
              values = coverage_node.attr("value").scan(/(\.?\d+\.?\d*)/)
              covered = values[1][0].to_f
              total = values[2][0].to_f

              if type == "line"
                coverage.line_covered = covered
                coverage.line_total = total
              else
                coverage.block_covered = covered
                coverage.block_total = total
              end
            end

          method_coverage[method] = coverage
          end
        end
      end
      c += 1
    end
    return method_coverage
  end

  # Only to be called after the coverage files are generated from the rakefile
  def process(tests_for_methods)

    # Acquire the method => MethodCoverage
    method_coverage = extract_line_block_coverage(tests_for_methods)

    # Acquire the label and libsvm content in an array of lines
    labels = File.read(@labels_file).split(/\r?\n|\r/)
    libsvm = File.read(@libsvm_file).split(/\r?\n|\r/)

    # Acquire line mapping of the labels
    line_mapping = get_line_mapping(labels)

    # Apply test metrics to the original libsvm, adjusting the labels as well
    new_labels, new_libsvm = add_test_metrics(tests_for_methods, line_mapping,
                                              labels, libsvm, method_coverage)

    # Add comments about the new metrics in the labels file
    new_labels += "# ['MLOC', 'NBD', 'VG', 'PAR', 'NOT', 'STMLOC', 'ATMLOC'," \
                  " 'STNBD', 'ATNBD', 'STVG', 'ATVG', 'STPAR', 'ATPAR', " \
                  " 'LCOV', 'LTOT', 'LSCOR', 'BCOV', 'BTOT', 'BSCOR']\n"
    new_labels += "# Matches line-to-line with the corresponding metrics " \
                  "file (no labels extension)"

    # Write changes
    puts "[LOG] Writing new libsvm and labels file with new data from tests"
    file = File.open("#{@labels_file}_new", 'w')
    file.write(new_labels)
    file.close

    file = File.open("#{@libsvm_file}_new", 'w')
    file.write(new_libsvm)
    file.close
  end
end
