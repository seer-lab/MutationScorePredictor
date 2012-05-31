class ClassMetricAccumulator

 attr_accessor :project

  def initialize(project)
    @project = project
  end

  def divide(value1, value2)
    if value2 == 0
      return 0
    else
      return value1.to_f / value2.to_f
    end
  end

  def accumulate_metrics

    # For all classes
    ClassData.all(:project => @project) do |class_item|

      # Acquire avg metrics of matching methods
      number_of_methods = MethodData.count(:project => @project, :class_name => class_item.class_name)

      if number_of_methods != 0

        puts "[LOG] Accumulating Metrics - #{class_item.class_name}"

        # Acquire sum metrics of matching methods
        class_item.update(
          :smloc => MethodData.sum(:mloc, :conditions => {:project => @project, :class_name => class_item.class_name}),
          :snbd => MethodData.sum(:nbd, :conditions => {:project => @project, :class_name => class_item.class_name}),
          :svg => MethodData.sum(:vg, :conditions => {:project => @project, :class_name => class_item.class_name}),
          :spar => MethodData.sum(:par, :conditions => {:project => @project, :class_name => class_item.class_name}),
        )

        # Acquire avg metrics of matching methods
        class_item.update(
          :amloc => divide(class_item.smloc, number_of_methods),
          :anbd => divide(class_item.snbd, number_of_methods),
          :avg => divide(class_item.svg, number_of_methods),
          :apar => divide(class_item.spar, number_of_methods),
        )

      end
    end
  end

  def process

    # Perform the accumulation of method metrics into the class metrics
    accumulate_metrics

    puts "[LOG] Number of classes=#{ClassData.all(:project => @project, :usable => true).count}"
    puts "[LOG] Removing items that are not valid (no valid methods in class) (occurs!=3)"
    ClassData.all(:project => @project, :usable => true, :occurs.not => 3).update(:usable => false)
    puts "[LOG] Number of classes=#{ClassData.all(:project => @project, :usable => true).count}"

  end
end
