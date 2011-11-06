require 'csv'
require 'trollop'

class FilterSplitLibsvm

  def initialize
    @opts = Trollop::options do
      opt :libsvm_file, "libsvm file", :type => String
      opt :percent_training, "percent to use for trainning (i.e., 0.80)", :type => :float, :default => 0.80
      opt :training_libsvm_file, "target training libsvm file", :type => String
      opt :testing_libsvm_file, "target testing libsvm file", :type => String
      opt :strip_features, "what features to strip (i.e., 1 4 6)", :type => :ints
    end
    Trollop::die :libsvm_file, "must specify libsvm file" if @opts[:libsvm_file] == nil
    Trollop::die :training_libsvm_file, "must specify training libsvm file" if @opts[:training_libsvm_file] == nil
    Trollop::die :testing_libsvm_file, "must specify testing libsvm file" if @opts[:testing_libsvm_file] == nil
  end

  def process()
    line_count = 1
    exclude_features = @opts[:strip_features]
    new_libsvm = ""

    # Strip out specified features and count the number of lines
    CSV.foreach(@opts[:libsvm_file], :col_sep => ' ') do |row|

      current_index = 1  # The current feature index we are on
      index_offset = 0  # The offset for stripped out features
      feature_set = row[0]  # The construction of the new feature set

      # Exclude the features we want to ignore (while adjusting indexes)
      row[1..-1].each do |feature|  

        if exclude_features != nil
          if !exclude_features.include?(current_index)
            feature.sub!(/\d+:/, "#{current_index - index_offset}:")
          else
            index_offset += 1
          end
        end
        feature_set << " #{feature.to_s}"
        current_index += 1
      end

      new_libsvm << "#{feature_set}\n"
      line_count += 1
    end

    # Create number of rows to take as random x%
    percentage = (line_count* @opts[:percent_training]).to_i
    random = []
    while true do
      if random.length == percentage
        break
      end
      random_line = 1+Random.rand(line_count)
      if !random.include?(random_line)
        random << random_line
      end
    end

    # Split up the libsvm based on the random lines to use for training
    line_count = 1
    training_content = ""
    testing_content = ""
    CSV.parse(new_libsvm) do |row|
      if random.include?(line_count)
        training_content << "#{row[0]}\n"
      else
        testing_content << "#{row[0]}\n"
      end
      line_count += 1
    end

    # Write to training file
    if File.exists?(@opts[:training_libsvm_file])
      puts "[LOG] Appending to training file: #{@opts[:training_libsvm_file]}"
    else
      puts "[LOG] Creating new training file: #{@opts[:training_libsvm_file]}"
    end
    file = File.open(@opts[:training_libsvm_file], 'a')
    file.write(training_content)
    file.close

    # Write to training file
    if File.exists?(@opts[:testing_libsvm_file])
      puts "[LOG] Appending to testing file: #{@opts[:testing_libsvm_file]}"
    else
      puts "[LOG] Creating new testing file: #{@opts[:testing_libsvm_file]}"
    end
    file = File.open(@opts[:testing_libsvm_file], 'a')
    file.write(testing_content)
    file.close
  end
end

# If this is the main file, run the process
if __FILE__ == $PROGRAM_NAME
  application = FilterSplitLibsvm.new
  application.process
end
