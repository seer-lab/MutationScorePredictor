#Information

*Author*:    Kevin Jalbert  (kevin.j.jalbert@gmail.com)

*Copyright*: Copyright (c) 2011 Kevin Jalbert

*License*: MIT License

# Introduction

The mutation score predictor is a technique that allows one to predict the
mutation score of methods and classes within a Java project. The benefit of
predicting the mutation score is that one does not need to actually execute the
mutation testing process. Mutation testing is a costly procedure as it requires
multiple executions of the test suite. By predicting with a reasonable level
of accuracy the mutation score of methods and classes mutation scores can be
acquire with relatively low resource consumption.

# Background

Some quick background material on mutation testing and support vector machines
are supplied in the following sections.

## Mutation Testing

Mutation testing is a technique that evaluates the coverage achieved by a unit
test suite for a project. The objective of mutation testing is to identify weak
areas in the unit test suite, this is accomplished by seeding faults into the
project. A mutant is a copy of the project except for a newly introduce fault,
as a result of a single change. If a mutant is detected by the test suite then
is was killed, otherwise it was undetected. A mutation score is given at the
ending of the mutation testing process that quantifies the test suites ability
to kill mutants (given as a percent of killed mutants).

**The selected mutation testing tool is [Javalanche][8].**

## Support Vector Machine

Support vector machine is a machine learning technique that falls under the
category of  supervised learning algorithms. This technique is capable of
learning on a set of features dictate the category of a data item, essentially
it is a classifier. Supervised learning algorithms will first be trained on
known data (features and categories are known), and then are used on the test
data (only features known). The classifier will attempt to correctly classify
the unknown data given a model that was created during the training phase.

**The selected support vector machine tool is [libsvm][9].**

# Instructions

This project requires multiple languages and tools to function as intended. The
list of requirements are displayed below, as well as the method to execute this
project as intended. To aid the user in executing the method, a _Rakefile_
exists with the project to automate some of the steps.
 
## Requirements

The following list enumerates the requirements for this project. The project
was developed on Linux and uses some Linux-only features.

1. Linux/Bash/Git
3. [Ruby][1]
4. [Python][2]
5. [Java][3]
6. [Eclipse][4]
7. [Eclipse Metric Plugin][5]
8. [Ant][6]
9. [Maven][7] (Optional, only if working with a project that uses Maven)

## Method

_TODO_

  [1]: http://www.ruby-lang.org/en/ "Ruby"
  [2]: http://www.python.org/ "Python"
  [3]: http://www.java.com/ "Java"
  [4]: http://www.eclipse.org/ "Eclipse"
  [5]: http://metrics2.sourceforge.net/ "Eclipse Metrics plugin"
  [6]: http://ant.apache.org/ "Ant"
  [7]: http://maven.apache.org/ "Maven"
  [8]: http://www.st.cs.uni-saarland.de/~schuler/javalanche/ "Javalanche"
  [9]: http://www.csie.ntu.edu.tw/~cjlin/libsvm/ "libsvm"
