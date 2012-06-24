def ignore_field(field)
  if field == "id" || field == "project" || field == "run" || field == "class_name" ||
    field == "method_name" || field == "occurs" || field == "usable" ||
    field == "created_at" || field == "updated_at" || field == "tests_touched" ||

    # Mutation Testing
    field == "killed_mutants" ||
    field == "covered_mutants" ||
    field == "generated_mutants" ||
    field == "mutation_score_of_covered_mutants" ||
    field == "mutation_score_of_generated_mutants" ||

    # Mutation Operators
    field == "killed_no_mutation" ||
    field == "total_no_mutation" ||
    field == "killed_replace_constant" ||
    field == "total_replace_constant" ||
    field == "killed_negate_jump" ||
    field == "total_negate_jump" ||
    field == "killed_arithmetic_replace" ||
    field == "total_arithmetic_replace" ||
    field == "killed_remove_call" ||
    field == "total_remove_call" ||
    field == "killed_replace_variable" ||
    field == "total_replace_variable" ||
    field == "killed_absolute_value" ||
    field == "total_absolute_value" ||
    field == "killed_unary_operator" ||
    field == "total_unary_operator" ||
    field == "killed_replace_thread_call" ||
    field == "total_replace_thread_call" ||
    field == "killed_monitor_remove" ||
    field == "total_monitor_remove" ||

    # Class Metrics
    # field == "norm" ||
    # field == "nof" ||
    # field == "nsc" ||
    # field == "nom" ||
    # field == "dit" ||
    # field == "lcom" ||
    # field == "nsm" ||
    # field == "six" ||
    # field == "wmc" ||
    # field == "nsf" ||

    # Method Metrics
    # field == "mloc" ||
    # field == "nbd" ||
    # field == "vg" ||
    # field == "par" ||

    # Coverage
    field == "lcov" ||
    field == "ltot" ||
    field == "lscor" ||
    field == "bcov" ||
    field == "btot" ||
    field == "bscor" ||
    field == "not" ||

    # Accumulated Test Unit Metrics
    field == "stmloc" ||
    field == "atmloc" ||
    field == "stnbd" ||
    field == "atnbd" ||
    field == "stvg" ||
    field == "atvg" ||
    field == "stpar" ||
    field == "atpar" ||

    # Accumulated Code Unit Metrics
    field == "smloc" ||
    field == "amloc" ||
    field == "snbd" ||
    field == "anbd" ||
    field == "svg" ||
    field == "avg" ||
    field == "spar" ||
    field == "apar" ||

    field == "."
    return true
  else
    return false
  end
end
