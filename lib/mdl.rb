require 'mdl/cli'
require 'mdl/config'
require 'mdl/doc'
require 'mdl/kramdown_parser'
require 'mdl/ruleset'
require 'mdl/style'
require 'mdl/version'

require 'kramdown'

module MarkdownLint
  def self.run
    cli = MarkdownLint::CLI.new
    cli.run
    rules = RuleSet.load_default
    style = Style.load(Config[:style], rules)
    # Rule option filter
    rules.select! {|r| Config[:rules].include?(r) } if Config[:rules]
    # Tag option filter
    rules.select! {|r, v| not (v.tags & Config[:tags]).empty? } if Config[:tags]

    if Config[:list_rules]
      puts "Enabled rules:"
        rules.each do |id, rule|
          if Config[:verbose]
            puts "#{id} (#{rule.tags.join(', ')}) - #{rule.description}"
          else
            puts "#{id} - #{rule.description}"
          end
        end
      exit 0
    end

    # Recurse into directories
    cli.cli_arguments.each_with_index do |filename, i|
      if Dir.exist?(filename)
        pattern = "#{filename}/**/*.md" # This works for both Dir and ls-files
        if Config[:git_recurse]
          Dir.chdir(filename) do
            cli.cli_arguments[i] = %x(git ls-files '*.md').split("\n")
          end
        else
          cli.cli_arguments[i] = Dir["#{filename}/**/*.md"]
        end
      end
    end
    cli.cli_arguments.flatten!

    status = 0
    cli.cli_arguments.each do |filename|
      puts "Checking #{filename}..." if Config[:verbose]
      doc = Doc.new_from_file(filename)
      filename = '(stdin)' if filename == "-"
      if Config[:show_kramdown_warnings]
        status = 2 if not doc.parsed.warnings.empty?
        doc.parsed.warnings.each do |w|
          puts "#{filename}: Kramdown Warning: #{w}"
        end
      end
      rules.sort.each do |id, rule|
        puts "Processing rule #{id}" if Config[:verbose]
        error_lines = rule.check.call(doc)
        next if error_lines.nil? or error_lines.empty?
        status = 1
        error_lines.each do |line|
          puts "#{filename}:#{line}: #{id} #{rule.description}"
        end
      end
    end
    exit status
  end
end
