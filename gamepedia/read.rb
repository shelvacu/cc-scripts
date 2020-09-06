require "nokogiri"
require "pp"

doc = Nokogiri::HTML(File.read(ARGV[0]))

# attrs:
# I: Has different ID as an inventory item
# D: Use the item's Damage field to define its durability
# S: Requires additional data from Data array
# B: Data from Damage
# N: Data from NBT
# E: Data from Entity

puts "["
doc.css("table").each do |tbl|
  next if tbl.attributes["class"] and tbl.attributes["class"].value == "msgbox"
  tbl.css("tr").each do |row|
    next unless row.at_css("th") == nil
    oneth = nil
    oneth_str = ""
    if oneth = row.at_css("td:nth-of-type(1) span")
      coords = /background-position:([-+]?\d+)px ([-+]?\d+)px/.match(row.at_css("td:nth-of-type(1) span").attributes["style"].value)
      #puts "#{coords[1]} #{coords[2]}"
      coords = [coords[1], coords[2]].map(&:to_i)
      if coords[0] % 16 != 0 || coords[1] % 16 != 0
        raise
      end
      #pp oneth
      coords = /background-position:([-+]?\d+)px ([-+]?\d+)px/.match(row.at_css("td:nth-of-type(1) span").attributes["style"].value)
      #puts "#{coords[1]} #{coords[2]}"
      coords = [coords[1], coords[2]].map(&:to_i)
      if coords[0] % 16 != 0 || coords[1] % 16 != 0
        raise
      end
      oneth_str = coords#"#{(-coords[0])/16}x#{(-coords[1])/16}"
    elsif oneth = row.at_css("td:nth-of-type(1) a")
      href = oneth.attributes["href"].value
      if ARGV[1] == "dl"
        system("ruby", "../get_img_url.rb", href)
      end
      oneth_str = URI.decode(URI.parse(href).path.split(":").last)
    else
      next
    end

    dec = row.at_css("td:nth-of-type(2)").text.strip.to_i
    hex = row.at_css("td:nth-of-type(3)").text.strip
    namespaced_id = row.at_css("td:nth-of-type(4)").text.strip
    link_n_stuff = row.at_css("td:nth-of-type(5)")
    a = link_n_stuff.at_css("a")
    attrs = []
    if sup = link_n_stuff.at_css("sup")
      attrs = sup.text.strip.split(/\s+/)
    end
    #puts "#{oneth_str}, #{dec}, #{namespaced_id}, #{attrs.join(":")}"
    puts "  " + [oneth_str, dec, "minecraft:" + namespaced_id, attrs].inspect + ","
  end
end
puts "]"
