require 'csv'

class ExtractSourceMetrics

  attr_accessor :project, :class_file, :method_file

  def initialize(project, class_file, method_file)
    @project = project
    @class_file = class_file
    @method_file = method_file
  end

  def process

    # Extract data for the classes
    CSV.foreach(@class_file, :col_sep => ',') do |row|

    # Skip the first row of field names
      if row[0] == "name"
        next
      end

      puts "[LOG] Adding Metrics - #{row[0]}"

      # Acquire class data
      class_item = ClassData.first_or_create(
        :project => @project,
        :class_name => row[0]
      )

      class_item.update(
        :occurs => class_item.occurs + 1,
        :norm => row[1],
        :nof => row[2],
        :nsc => row[3],
        :nom => row[4],
        :dit => row[5],
        :lcom => row[6],
        :nsm => row[7],
        :six => row[8],
        :wmc => row[9],
        :nsf => row[10]
      )
    end

    # Extract data for the methods
    CSV.foreach(@method_file, :col_sep => ',') do |row|

      # Skip the first row of field names
      if row[0] == "name"
        next
      end

      puts "[LOG] Adding Metrics - #{row[0].rpartition(".").first}"

      if !row[0].include?("$anonymous")

        # Acquire method data
        method_item = MethodData.first_or_create(
          :project => @project,
          :class_name => row[0].rpartition('.').first,
          :method_name => row[0]
        )

        # Update method data with values
        method_item.update(
          :occurs => method_item.occurs + 1,
          :mloc => row[1],
          :nbd => row[2],
          :vg => row[3],
          :par => row[4]
        )
      else
        puts "[LOG] Ignoring Anonymous Method"
      end
    end

    puts "[LOG] Number of methods=#{MethodData.all(:project => @project, :usable => true).count}"
    puts "[LOG] Number of classes=#{ClassData.all(:project => @project, :usable => true).count}"
    puts "[LOG] Removing items that were duplicated (occurs>2)"
    MethodData.all(:project => @project, :usable => true, :occurs.gt => 2).update(:usable => false)
    ClassData.all(:project => @project, :usable => true, :occurs.gt => 2).update(:usable => false)
    puts "[LOG] Number of methods=#{MethodData.all(:project => @project, :usable => true).count}"
    puts "[LOG] Number of classes=#{ClassData.all(:project => @project, :usable => true).count}"

  end
end
