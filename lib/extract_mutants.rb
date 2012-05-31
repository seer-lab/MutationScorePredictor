require 'csv'

class ExtractMutants

  attr_accessor :project, :analyze_file, :tests_file

  def initialize(project, analyze_file, tests_file)
    @project = project
    @analyze_file = analyze_file
    @tests_file = tests_file
  end


  def acquire_tests_touched

    tests_touched = Hash.new

    # Extract data for the tests touched
    CSV.foreach(@tests_file, :col_sep => ',') do |row|

      # Skip the first row of field names
      if row[0] == "MUTANT_ID"
        next
      end

      tests_touched[row[0]] = row[1]
    end
    return tests_touched
  end


  def add_units(tests_touched)

    # Extract data for the tests touched
    CSV.foreach(@analyze_file, :col_sep => ',') do |row|

      # Skip the first row of field names
      if row[0] == "ID"
        next
      end

      # Create mutant
      MutantData.first_or_create(
        :project => @project,
        :class_name => row[20],
        :method_name => row[20] + "." + row[21],
        :line_number => row[22],

        :mutant_id => row[0],
        :killed => row[1],
        :type => row[19],
        :methods_modified_all => row[7],
        :tests_touched => tests_touched[row[0]]
      )
      puts "[DEBUG] Added mutation with id #{row[0]}"
    end
  end


  def process
    tests_touched = acquire_tests_touched
    add_units(tests_touched)
  end
end
