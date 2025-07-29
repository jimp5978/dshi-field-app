#!/usr/bin/env ruby

require 'mysql2'

begin
  # Test MySQL connection with the same settings as database.yml
  client = Mysql2::Client.new(
    host: 'localhost',
    username: 'field_app_user',
    password: 'dshi2025#',
    database: 'field_app_db',
    encoding: 'utf8mb4'
  )
  
  puts "✅ MySQL connection successful!"
  
  # Test basic query
  result = client.query("SELECT COUNT(*) as count FROM information_schema.tables WHERE table_schema = 'field_app_db'")
  table_count = result.first['count']
  puts "📊 Database has #{table_count} tables"
  
  # Test specific table
  result = client.query("SELECT COUNT(*) as count FROM users")
  user_count = result.first['count']
  puts "👥 Users table has #{user_count} users"
  
  # Test assembly_items table
  result = client.query("SELECT COUNT(*) as count FROM assembly_items")
  assembly_count = result.first['count']
  puts "🔧 Assembly items table has #{assembly_count} items"
  
  puts "🎉 Rails MySQL integration ready!"
  
rescue Mysql2::Error => e
  puts "❌ MySQL connection failed: #{e.message}"
rescue => e
  puts "❌ Error: #{e.message}"
ensure
  client&.close
end