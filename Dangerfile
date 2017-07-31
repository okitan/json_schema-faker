# Warn when there is a big PR
require "git_diff_parser"

begin
  tag_for_focus = `bundle exec ruby -r rspec -r ./spec/spec_helper -e "print RSpec.configuration.filter_run.merge(RSpec.configuration.filter_run_when_matching).keys.join(',')"`.split(",").map {|item| "\\:#{item}" }
rescue
  tag_for_focus = []
end

regexp = Regexp.new([ "fit", "fcontext", *tag_for_focus ].map {|item| "\\s+#{item}\\s+" }.join("|"))

diff = GitDiffParser.parse(github.pr_diff)

diff.each do |diff_per_file|
  next if diff_per_file.file.end_with?("_spec.rb")

  diff_per_file.changed_lines.each do |line|
    if line.content =~ regexp
      warn "#{line.content} includes #{regexp}"
    end
  end
end
