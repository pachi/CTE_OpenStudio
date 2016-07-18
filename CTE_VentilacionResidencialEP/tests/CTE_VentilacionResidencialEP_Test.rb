require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'

require_relative "../measure.rb"


class CTE_VentilacionResidencialEP_Test < MiniTest::Unit::TestCase

  def test_VentilacionResidencialEP

    measure = CTE_VentilacionResidencialEP.new
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/cubitoygarajenhideal.idf")
    workspace = OpenStudio::Workspace.load(path)
    if workspace.empty?
      runner.registerError("Cannot load #{ path }")
      return false
    end
    workspace = workspace.get

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    #assert_equal(1, arguments.size)
    #assert_equal("space_name", arguments[0].name)

    # # populate argument with specified hash value if specified
    # arguments.each do |arg|
    #   temp_arg_var = arg.clone
    #   if args_hash[arg.name]
    #     assert(temp_arg_var.setValue(args_hash[arg.name]))
    #   end
    #   argument_map[arg.name] = temp_arg_var
    # end

    measure.run(workspace, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")

    # save the workspace to output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_output.idf")
    workspace.save(output_file_path, true)

  end


end