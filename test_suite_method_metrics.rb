require 'csv'
require 'nokogiri'

class TestSuiteMethodMetrics

  attr_reader = :project, :run

  def initialize(project, run)
    @project = project
    @run = run
  end

  def calculate_avg(value1, value2)
    if value2 == 0
      return 0
    else
      return value1.to_f / value2.to_f
    end
  end

  def add_test_metrics

    # For a method get a list of metrics from each test's methods
    MethodData.all(:project => @project, :run => @run, :tests_touched.not => "").each do |method|

      puts "[LOG] Adding Test Metrics - #{method.method_name}"

      # Check if method has coverage
      if method.ltot == 0 && method.btot == 0
        puts "No coverage for method " + method.method_name
        next
      end

      sum_tmloc = 0
      sum_tnbd = 0
      sum_tvg = 0
      sum_tpar = 0
      number_of_tests = 0

      # Extract the sum metrics of the tests for this method
      method.tests_touched.split(" ").each do |test|
        test_method = MethodData.first(:project => @project, :run => @run, :method_name => test)
        sum_tmloc += test_method.mloc
        sum_tnbd += test_method.nbd
        sum_tvg += test_method.vg
        sum_tpar += test_method.par
        number_of_tests += 1
      end

      # Calculate the averages for the test metrics and update the method
      method.update(
        :occurs => method.occurs + 1,
        :not => number_of_tests,
        :stmloc => sum_tmloc,
        :stnbd => sum_tnbd,
        :stvg => sum_tvg,
        :stpar => sum_tpar,
        :atmloc => calculate_avg(sum_tmloc, number_of_tests),
        :atnbd => calculate_avg(sum_tnbd, number_of_tests),
        :atvg => calculate_avg(sum_tvg, number_of_tests),
        :atpar => calculate_avg(sum_tpar, number_of_tests)
      )

    end
  end

  def extract_line_block_coverage

    # TODO Reuse coverage values of identical tests

    c = 1
    # For each method, find the coverage of the tests
    MethodData.all(:project => @project, :run => @run, :usable => true, :tests_touched.not => "").each do |method|

      # Parse the XML coverage file
      puts "[LOG] Extracting coverage data from ./data/coverage#{c}.xml"
      doc = Nokogiri::XML(File.open("./data/coverage#{c}.xml"))

      doc.xpath("//package//class//method").each do |method_node|

        method_name = method_node.attr("name")

        class_node = method_node.parent
        class_name = class_node.attr("name")

        package_node = class_node.parent
        package_name = package_node.attr("name")

        unit_name = "#{package_name}.#{class_name}.#{method_name.rpartition("(").first.strip}"

        # Acquire coverage only if the method of the coverage filei
        if unit_name == method.method_name
          method_node.children.each do |coverage_node|

            if coverage_node.attr("type") != nil and
              coverage_node.attr("value") != nil
              type = coverage_node.attr("type").scan(/(line|block)/)[0][0]
              values = coverage_node.attr("value").scan(/(\.?\d+\.?\d*)/)
              covered = values[1][0].to_f
              total = values[2][0].to_f

              if type == "line"
                method.update(
                  :lcov => covered,
                  :ltot => total,
                  :lscor => covered/total * 100
                )
              else
                method.update(
                  :bcov => covered,
                  :btot => total,
                  :bscor => covered/total * 100
                )
              end
            end
          end
        end
      end
      c += 1
    end
  end

  # Only to be called after the coverage files are generated from the rakefile
  def process

    # Acquire the method coverage
    extract_line_block_coverage

    # Acquire the test metrics
    add_test_metrics

    puts "[LOG] Number of methods=#{MethodData.all(:project => @project, :run => @run, :usable => true).count}"
    puts "[LOG] Removing items that are not valid (no covered tests/no mutation score) (occurs!=3)"
    MethodData.all(:project => @project, :run => @run, :usable => true, :occurs.not => 3).update(:usable => false)
    puts "[LOG] Number of methods=#{MethodData.all(:project => @project, :run => @run, :usable => true).count}"

  end

end
