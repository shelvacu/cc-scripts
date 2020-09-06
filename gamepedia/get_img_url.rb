require "nokogiri"
require "open-uri"

uri = URI.join("https://minecraft.gamepedia.com/",ARGV[0])
fn = URI.decode(uri.path.split(":").last)
if File.exist?(fn)
  exit 0
end
doc = Nokogiri::HTML(open(uri))

a = doc.at_css("#file a")
img_url = URI.join(uri, a.attributes["href"].value)
if fn != (other_fn = URI.decode(img_url.path.split("/").last))
  STDERR.puts "fn mismatch #{fn.inspect} vs #{other_fn.inspect}"
  exit 1
end
if system("wget", "-O", fn, img_url.to_s)
  exit 0
else
  exit 1
end
