#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'yaml'
require 'pg'

# Fix PostgreSQL sequences after migration from MySQL
# MySQL auto_increment values aren't transferred to PostgreSQL sequences,
# causing "duplicate key" errors when inserting new records.

config_filename = "#{File.basename($PROGRAM_NAME, File.extname($PROGRAM_NAME))}.yml"

# Try to use cloner.yml if fix_sequences.yml doesn't exist
unless File.exist?(config_filename)
  config_filename = 'cloner.yml'
  unless File.exist?(config_filename)
    warn 'Configuration file not found!'
    warn 'Please ensure cloner.yml exists or create fix_sequences.yml'
    exit 1
  end
end

config = Psych.safe_load(File.read(config_filename))
pg = PG.connect(config['destination_postgresql'])

# Query to find all sequences and their associated tables/columns
sequences_query = <<~SQL
  SELECT
    s.sequence_name,
    t.table_name,
    c.column_name
  FROM information_schema.sequences s
  LEFT JOIN information_schema.columns c
    ON c.column_default LIKE '%' || s.sequence_name || '%'
    AND c.table_schema = s.sequence_schema
  LEFT JOIN information_schema.tables t
    ON t.table_name = c.table_name
    AND t.table_schema = c.table_schema
  WHERE s.sequence_schema = 'public'
    AND c.column_name IS NOT NULL
  ORDER BY s.sequence_name;
SQL

puts 'Fixing sequences...'
puts '-' * 60

fixed_count = 0
pg.exec(sequences_query) do |result|
  result.each do |row|
    sequence_name = row['sequence_name']
    table_name = row['table_name']
    column_name = row['column_name']

    # Get the maximum value from the table
    max_query = "SELECT COALESCE(MAX(\"#{column_name}\"), 0) AS max_val FROM \"#{table_name}\""
    max_result = pg.exec(max_query)
    max_value = max_result[0]['max_val'].to_i

    if max_value > 0
      # Set sequence to max value + 1
      setval_query = "SELECT setval('\"#{sequence_name}\"', #{max_value}, true)"
      pg.exec(setval_query)
      puts "✓ #{sequence_name.ljust(30)} → #{max_value} (table: #{table_name}.#{column_name})"
      fixed_count += 1
    else
      puts "○ #{sequence_name.ljust(30)} → 0 (table: #{table_name}.#{column_name}, no data)"
    end
  end
end

puts '-' * 60
puts "Fixed #{fixed_count} sequences"
puts
puts 'Your PostgreSQL database is now ready to accept new inserts!'
