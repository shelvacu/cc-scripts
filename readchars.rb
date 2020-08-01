cc_to_u = {}
u_to_cc = {}
while line = gets
  next if line[0] == "#"
  i, rest = line.split(":")
  i = i.to_i
  rest.strip!
  hex, rest = rest.split(" ")
  u = hex[2..-1].to_i(16)
  if cc_to_u.include? i
    puts "duplicate cc #{i}"
  end
  if u_to_cc.include? u
    puts "duplicate unicode #{u}"
  end
  cc_to_u[i] = u
  u_to_cc[u] = i
end
(0..255).each do |cc|
  if not cc_to_u.include? cc
    if u_to_cc.include? cc
      puts "auto duplicate #{cc}"
    end
    cc_to_u[cc] = cc
    u_to_cc[cc] = cc
  end
end

puts "unicodeToCC = {"
puts u_to_cc.map{|k,v|
  "  [#{k}] = #{v}"
}.join(",\n")
puts "}"

puts "ccToUnicode = {"
puts cc_to_u.map{|k,v|
  "  [#{k}] = #{v}"
}.join(",\n")
puts "}"

#require "pp"
#pp cc_to_u
#pp u_to_cc

