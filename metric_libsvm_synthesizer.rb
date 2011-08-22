require 'csv'

def get_unit_scores(file)

  unit_score = Hash.new()

  # row[0]  = name | row[1] = killed | row[2] = total | row[3] = score
  CSV.foreach(file, :col_sep => ';') do |row|

    # Give unit a score
    unit_score[row[0]] = row[3]
      
  end
  return unit_score
end

def get_line_mapping(labels_content)

  line_mapping = Hash.new()
  line_number = 1

  labels_content.split(/\r?\n|\r/).each do |label|

    # Completed the mapping, rest are comments
    if label[0] == "#"
      break
    end

    line_mapping[line_number] = label
    line_number += 1
  end

  return line_mapping
end

def get_score_category(score)
  if score >= 0.00000000000000 and score <= 33.33333333333333
    return 2
  elsif score > 33.33333333333333 and score <= 66.66666666666666
    return 1
  elsif score > 66.66666666666666 and score <= 100.00000000000000  
    return 0
  end
end

def synthesize_libsvm(old_libsvm, line_mapping, unit_score, old_labels)

  line_number = 1
  new_libsvm = ""
  new_labels = ""

  # Fill in the category for each line of the libsvm
  old_libsvm.split(/\r?\n|\r/).each do |line|
    
    # Figure out the category of the unit
    mutation_score = unit_score[line_mapping[line_number]]
    if mutation_score != nil
      category = get_score_category(mutation_score.to_f)
      new_libsvm << line.sub("-1", category.to_s) + "\n"
      new_labels << line_mapping[line_number] + "\n"
    end

    line_number += 1
  end
  return new_libsvm, new_labels
end

# Handling the parameters
if ARGV[0] == nil or ARGV[1] == nil or ARGV[2] == nil
  raise "ERROR: specify as parameters: libsvm_file lables_file scores_file"
end

if not ARGV[0].include?(".libsvm")
  raise "ERROR: Wrong libsvm file specified"
end

if not ARGV[1].include?(".labels")
  raise "ERROR: Wrong labels file specified"
end

if not ARGV[2].include?(".score")
  raise "ERROR: Wrong score file specified"
end

# Acquire the files content
old_libsvm = File.read(ARGV[0])
labels = File.read(ARGV[1])

# Acquire the unit_name => score values
unit_score = get_unit_scores(ARGV[2])

# Acquire the line_number => unit name
line_mapping = get_line_mapping(labels)

# Synthesize the libsvm with the scores
new_libsvm, new_labels = synthesize_libsvm(old_libsvm, line_mapping, 
                                           unit_score, labels)

file = File.open("#{ARGV[0]}_synth", 'w')
file.write(new_libsvm)
file.close

file = File.open("#{ARGV[1]}_synth", 'w')
file.write(new_labels)
file.close
