#!/usr/bin/env ruby
# frozen_string_literal: true

require 'time'
require 'csv'
require 'json'
require 'yaml'
require 'optparse'
require 'optparse/time'
require 'ostruct'

options = {
  output: :raw,
  days: 30,
  ignore: %w[sonar-project.properties repolinter.json release_files.json license_policy.yml LICENSE]
}

opt_parser = OptionParser.new do |opt|
  opt.banner = "Usage: #{File.basename(__FILE__)} [options]"
  opt.separator  ""
  opt.separator  "Options:"

  opt.on('-o', '--output FORMAT', 'Output format (raw, json, csv, yaml)') do |format|
    options[:output] = case format
                       when /^j/
                         :json
                       when /^c/
                         :csv
                       when /^y/
                         :yaml
                       else
                         :raw
                       end
  end

  opt.on('-d', '--days X', 'Minimum age in days (default: 30)') do |x|
    options[:days] = x.to_i
  end

  opt.on('-i', '--ignore PATH', 'Path to file with list of filenames to ignore') do |path|
    file = File.expand_path(path)
    if File.exist?(file)
      options[:ignore].concat(IO.read(file).strip.split(/\n/).map(&:strip))
    else
      raise StandardError, "Ignore file #{path} doesn't exist"
    end
  end
end

opt_parser.parse!(ARGV)

now = Time.now
past = now - (options[:days] * 24 * 60 * 60)
old_files = []

warn "Files older than #{options[:days]} days, oldest last"

files = `git ls-tree -r --name-only HEAD`.strip.split(/\n/)
files.each do |file|
  next if file =~ /^\.git/ || options[:ignore].include?(file)

  date = `git log -1 --format="%ad" -- "#{file}"`
  t = Time.parse date
  old_files << [t, file] if t < past
end

output = []

old_files.sort_by { |file| file[0] }.reverse.each do |file|
  days = ((Time.now - file[0]) / 24 / 60 / 60).round
  output << ["#{days} days", file[0].strftime('%Y-%m-%d'), file[1]]
end

def clean_array(input)
  h = {}
  input.each do |file|
    if h.key?(file[0])
      h[file[0]] << file[1]
    else
      h[file[0]] = [file[1]]
    end
  end

  h
end

case options[:output]
when :csv
  csv_string = CSV.generate do |csv|
    csv << ['Age', 'Last modified', 'File Path']
    output.each { |file| csv << file }
  end
  puts csv_string
when :json
  json = clean_array(output)
  puts json.to_json
when :yaml
  yaml = clean_array(output)
  puts YAML.dump(yaml)
else
  output.each { |file| puts "#{file[0]} #{file[2]}"}
end
