class ClassMetricAccumulator

  attr_reader = :method_libsvm_file, :method_labels_file, :class_libsvm_file,
                :class_labels_file

  def initialize(method_libsvm_file, method_labels_file, class_libsvm_file, 
                 class_labels_file)
    @method_libsvm_file = method_libsvm_file
    @method_labels_file = method_labels_file
    @class_libsvm_file = class_libsvm_file
    @class_labels_file = class_labels_file
  end

  def get_lines(content)
    lines = []

    # Split content into lines while ignoring comments
    content.split(/\r?\n|\r/).each do |line|
      if line[0] != "#"
        lines << line
      end
    end

    return lines
  end

  def form_updated_metrics(metrics, class_metrics, class_name)

    # If hash key exists update it, otherwise add it
    values = []
    if class_metrics.has_key?(class_name)
      values = class_metrics[class_name]
      
      # Add new sum and avg metrics (avg is calculated afterwards)
      for i in (0..4) do
        values[i*2] += metrics[i][0].to_f 
        values[(i*2)+1] += metrics[i][0].to_f
      end

      # Add reminding values
      for i in (5..18) do
        values[i+5] += metrics[i][0].to_f
      end
    else

      # Create new sum and avg metrics (avg is calculated afterwards)
      for i in (0..4) do
        values << metrics[i][0].to_f
        values << metrics[i][0].to_f 
      end

      # Add reminding values
      for i in (5..18) do
        values << metrics[i][0].to_f
      end
    end
    return values
  end

  def calculate_avg_and_coverage(class_metrics, class_libsvm, class_counter)

    # Calculate each class' avg metrics and coverage scores
    for key, metrics in class_metrics do

      # For only the avg metrics
      for i in (0..17)

        # Only odd index are avg metrics
        if i % 2 != 0 
          metrics[i] = metrics[i] / class_counter[key]
        end
      end

      # For the coverage metrics
      metrics[20] = metrics[18] / metrics[19]
      metrics[23] = metrics[21] / metrics[22]
    end
  end

  def create_new_libsvm_label(class_labels, class_libsvm, class_metrics)
    # Form the new_class_labels and new_class_libsvm files
    index = 0
    new_class_libsvm = ""
    new_class_labels = ""

    for label in class_labels do
      if class_metrics.has_key?(label)

        # Form and add the new metric string for this label
        added_metrics = class_libsvm[index] + " "
        for i in (0..23) do
          added_metrics += "#{11+i}:#{class_metrics[label][i]} "
        end
        new_class_libsvm += added_metrics.strip + "\n"

        # Track the corresponding label
        new_class_labels += label.strip + "\n"
      end
    index += 1
    end

    return new_class_libsvm, new_class_labels
  end

  def accumulate_metrics(method_libsvm, method_labels, class_libsvm,
                         class_labels)

    index = 0
    regex = /:(\d+[\.\d]*)/  # Finds the values in a libsvm file
    class_metrics = Hash.new  # class => array of metrics
    class_counter = Hash.new  # class => number of encounters

    # Iterate over method metrics and accumulate metrics for classes
    for label in method_labels do
      
      # Acquire the class name
      class_name = label[0..label.rindex(".")-1]

      # Increment the counter for this class
      if class_counter.has_key?(class_name)
        class_counter[class_name] += 1
      else
        class_counter[class_name] = 1
      end

      # Acquire the metrics for this label
      metrics = method_libsvm[index].scan(regex)
      
      # Find the new values for the current class
      values = form_updated_metrics(metrics, class_metrics, class_name)
      class_metrics[class_name] = values

      index += 1
    end

    # Calculate the average and coverage metrics for the class
    calculate_avg_and_coverage(class_metrics, class_libsvm, class_counter)

    return create_new_libsvm_label(class_labels, class_libsvm, class_metrics)
  end

  def process

    # Acquire the lines of the file content
    method_libsvm = get_lines(File.read(@method_libsvm_file))
    method_labels = get_lines(File.read(@method_labels_file))
    class_libsvm = get_lines(File.read(@class_libsvm_file))
    class_labels = get_lines(File.read(@class_labels_file))

    # Perform the accumulation of method metrics into the class metrics
    new_class_libsvm, new_class_labels = accumulate_metrics(method_libsvm, 
                                                            method_labels,
                                                            class_libsvm,
                                                            class_labels)

    # Add comments about the new metrics in the labels file
    new_class_labels += "# ['SMLOC', 'AMLOC', 'SNBD', 'ANBD', 'SVG', 'AVG', "\
                        "'SPAR', 'APAR', 'SNOT', 'ANOT', 'STMLOC', 'ATMLOC',"\
                        " 'STNBD', 'ATNBD', 'STVG', 'ATVG', 'STPAR', 'ATPAR',"\
                        " 'LCOV', 'LTOT', 'LSCOR', 'BCOV', 'BTOT', 'BSCOR'] \n"
    new_class_labels += "# Matches line-to-line with the corresponding "\
                        " metrics file (no labels extension)"

    file = File.open("#{@class_libsvm_file}_new", 'w')
    file.write(new_class_libsvm)
    file.close

    file = File.open("#{@class_labels_file}_new", 'w')
    file.write(new_class_labels)
    file.close
  end
end
