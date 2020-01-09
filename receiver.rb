require "sinatra"

post "/:name" do
  request.body.rewind
  File.write(File.join("uploads",params[:name]), request.body.read)
end
