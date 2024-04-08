# frozen_string_literal: true

require_relative "invoicer/version"
require 'date'
require 'chronic'
require 'pry'

module Invoicer
  class Error < StandardError; end
  # Your code goes here...

  def self.run
    if ARGV.empty? || !ARGV[0].match?(/^-we|--week-ending/)
      puts "Usage: invoicer -we <date>"
      exit
    end
    Runner.new.run
  end

  class Runner
    def initialize
      @date = Chronic.parse ARGV[1]
      @data = []
      @total_hours = 0
    end

    def run
      load_data
      generate_table
      io.close unless io == $stdout
    end

    def io
      if ARGV.include? '-f'
        filename = @date.strftime('%Y-%m-%d') + "-timesheet-#{total_hours}h.adoc"
        @io ||= File.open("/Users/richardconroy/emenu/timesheets/ready/"+filename, 'w')
      else
        @io ||= $stdout
      end
    end

    def load_data
      puts "Argument Date: #{@date}"
      6.downto(0) do |i|
        puts
        current_date = @date.to_date - i
        filename = "/Users/richardconroy/emenu/updates/#{current_date.strftime('%Y-%m')}/#{current_date.strftime('%d-%A').downcase}.md"
        if File.exist?(filename)
          puts "#{filename} exists"
          content = File.read(filename)
          @data << { date: current_date.strftime('%Y-%m-%d %A'), content: content }
        else
          puts "#{filename} does not exist"
        end
      end
    end

    def parse_activities(content)
      activities = []
      content.scan(/Hours worked: ([\d:]+).*\nAchievements\n(.+)/m) do |hours, achievements|
        decimal_rounded_hours = parse_hours_worked(hours)
        activities << {
          hours: hours,
          decimal_hours: decimal_rounded_hours,
          achievements: achievements.strip.split("\n").map {|a| a.gsub('* ', '') }
        }
        # @total_hours += decimal_rounded_hours
      end
      activities
    end

    def parse_hours_worked(colon_seperated_hours_mins_seconds)
      hours, minutes, seconds = colon_seperated_hours_mins_seconds.split(':').map(&:to_i)
      rounded_minutes = ((minutes / 60.0) * 4.0).round / 4.0
      hours + rounded_minutes
    end

    def total_hours
      return_hours = 0
      @data.each do |entry|
        activity = parse_activities(entry[:content]).first
        return_hours += activity[:decimal_hours]
      end
      return_hours
    end

    def generate_table
      format_asciidoc
    end

    def format_asciidoc
      io.puts '[width="100%",cols="2,1,6",frame="none"]'
      io.puts '|==='
      io.puts '| Timesheet for EMenuNow'
      io.puts '| Richard Conroy'
      io.puts '| Address: 19 Fairways, Little Island, County Cork, T45 PH34, Republic of Ireland'
      io.puts '|==='
      io.puts '[cols="4,2,9"]'
      io.puts '|==='
      io.puts '| Date Ending | Hours | Activities'
      @data.each do |entry|
        # binding.pry
        activity = parse_activities(entry[:content]).first
        io.puts "| #{entry[:date]} | #{activity[:decimal_hours]} | #{activity[:achievements].shift}"
        activity[:achievements].unshift.each do |line_item|
          io.puts "|  |  | #{line_item}"
        end
      end
      io.puts '|==='
      io.puts '|==='

      io.puts "| Total hours: #{total_hours}"
      io.puts '| Hourly Rate: 25 UKP'
      io.puts "| Total Pay: #{total_hours * 25.0} UKP"
      io.puts '|==='

    end
  end
end

Invoicer.run
