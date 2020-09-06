require "json"
File.open(ARGV[0],"a") do |f|
  f.puts ARGV[1..-1].to_json
end
