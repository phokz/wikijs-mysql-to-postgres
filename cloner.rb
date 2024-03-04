#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  gem 'pg', '~> 1.5.5'
  gem 'mysql2', '~> 0.5.6'
  gem 'tsort', '~> 0.1.1'
  gem 'yaml'
end

class Hash
  include TSort
  alias tsort_each_node each_key
  def tsort_each_child(node, &block)
    self[node].each(&block)
  end
end

def table_list(pg)
  list_constraints = File.read('list_constraints.sql')
  list_all_tables = "select table_name from information_schema.tables where table_schema = 'public'"

  h = {}
  pg.exec(list_all_tables) do |result|
    result.each do |row|
      h[row['table_name']] = []
    end
  end

  pg.exec(list_constraints) do |result|
    result.each do |row|
      foreign = row['foreign_table']
      primary = row['primary_table']
      next if foreign == primary

      h[primary] = [] if h[primary].nil?
      h[primary] << foreign
    end
  end

  h.tsort.reverse
end

def copy_table(mysql, pg, table)
  results = mysql.query("SELECT * FROM `#{table}`")

  warn table

  field_list = results.fields.map { |f| "\"#{f}\"" }.join(', ')

  encoded_field_indexes = []
  values_def = []

  results.field_types.each_with_index do |field_type, i|
    if field_type == 'longblob'
      suffix = '::bytea'
      encoded_field_indexes << i
    else
      suffix = ''
    end
    values_def << "$#{i + 1}#{suffix}"
  end

  value_list = values_def.join(', ')
  i = 0
  results.each(as: :array) do |row|
    encoded_field_indexes.each do |i|
      row[i] = pg.escape_bytea(row[i])
    end

    warn i
    i += 1
    pg.exec_params("insert into \"#{table}\"(#{field_list}) values(#{value_list})", row)
  end
end

def truncate_all_tables(pg)
  list_all_tables = "select table_name from information_schema.tables where table_schema = 'public'"

  tables = nil
  pg.exec(list_all_tables) do |result|
    tables = result.map do |row|
      "\"#{row['table_name']}\""
    end
  end

  sql = "truncate table #{tables.join(', ')}"
  puts sql
  pg.exec(sql)
end

def post_run_configuration_hint(pgconfig)
  puts '-' * 40
  puts 'You may now reconfigure your wiki to run with postgresql:'
  puts "cd /var/www/wiki \#or the space where wiki lives"
  puts 'cp config.yml ~/wiki.config.yml.backup'
  puts 'editor config.yml'
  puts ' and paste following'
  puts 'db:'
  puts '  type: postgres'
  puts '  port: 5432'
  puts "  host: #{pgconfig['host']}"
  puts "  user: #{pgconfig['user']}"
  puts "  pass: #{pgconfig['password']}"
  puts "  db: #{pgconfig['dbname']}"
  puts "  ssl: #{begin
    pgconfig['ssl']
  rescue StandardError
    'false'
  end}"
  puts
  puts 'Run systemctl restart wiki and then check https://wiki.yourdomian.com/a/system'
end

# Main

config_filename = "#{File.basename($PROGRAM_NAME, File.extname($PROGRAM_NAME))}.yml"
unless File.exist?(config_filename)
  warn 'Please copy provided example config and edit to suit your needs'
  warn "cp #{config_filename}.example #{config_filename} && editor #{config_filename}"
  warn "Then run #{$PROGRAM_NAME} again"
  exit 1
end

config = Psych.safe_load(File.read(config_filename))

mysql = Mysql2::Client.new(config['source_mysql'])
pg = PG.connect(config['destination_postgresql'])

if ARGV.shift == '--truncate'
  truncate_all_tables(pg)
  exit 2 if ARGV.shift == '--and-die'
end

config['queries']['source'].each do |query|
  mysql.query(query)
end

table_list(pg).each do |table|
  copy_table(mysql, pg, table)
end

config['queries']['destination'].each do |query|
  pg.exec(query)
end

post_run_configuration_hint(config['destination_postgresql'])
