require 'puppet/application'
require 'puppet/faces'

class Puppet::Application::Faces < Puppet::Application

  should_parse_config
  run_mode :agent

  option("--debug", "-d") do |arg|
    Puppet::Util::Log.level = :debug
  end

  option("--verbose", "-v") do
    Puppet::Util::Log.level = :info
  end

  def list(*arguments)
    if arguments.empty?
      arguments = %w{terminuses actions}
    end
    if faces.empty?
      print "There are no Puppet Faces to list.\n"
      # FIXME JJM Should the list of faces be empty in the base case?
      # Q: Do I need to install some faces for this to work?
      print "# FIXME: Suggested next action (Install some Faces?).\n"
    end
    faces.each do |name|
      str = "#{name}:\n"
      if arguments.include?("terminuses")
        begin
          terms = terminus_classes(name.to_sym)
          str << "\tTerminuses: #{terms.join(", ")}\n"
        rescue => detail
          puts detail.backtrace if Puppet[:trace]
          $stderr.puts "Could not load terminuses for #{name}: #{detail}"
        end
      end

      if arguments.include?("actions")
        begin
          actions = actions(name.to_sym)
          str << "\tActions: #{actions.join(", ")}\n"
        rescue => detail
          puts detail.backtrace if Puppet[:trace]
          $stderr.puts "Could not load actions for #{name}: #{detail}"
        end
      end

      print str
    end
  end

  attr_accessor :verb, :name, :arguments

  def main
    # Call the method associated with the provided action (e.g., 'find').
    send(verb, *arguments)
  end

  def setup
    Puppet::Util::Log.newdestination :console

    load_applications # Call this to load all of the apps

    @verb, @arguments = command_line.args
    @arguments ||= []

    validate
  end

  def validate
    unless verb
      raise "You must specify 'find', 'search', 'save', or 'destroy' as a verb; 'save' probably does not work right now"
    end

    unless respond_to?(verb)
      raise "Command '#{verb}' not found for 'faces'"
    end
  end

  def faces
    Puppet::Faces.faces
  end

  def terminus_classes(indirection)
    Puppet::Indirector::Terminus.terminus_classes(indirection).collect { |t| t.to_s }.sort
  end

  def actions(indirection)
    return [] unless faces = Puppet::Faces[indirection, '0.0.1']
    faces.load_actions
    return faces.actions.sort { |a, b| a.to_s <=> b.to_s }
  end

  def load_applications
    command_line.available_subcommands.each do |app|
      command_line.require_application app
    end
  end
end

