require 'resque'

puts "================================="
puts "Generating ptif's"
puts "================================="
colls = Collection.all
colls.each do |coll|
  puts "Collection: #{coll.pid}"
  comps = coll.components_from_solr
  comps.each do |comp|
    unless comp[Ddr::IndexFields::MULTIRES_IMAGE_FILE_PATH]
      component = ActiveFedora::Base.find(comp['id'])
      Resque.enqueue(Ddr::Managers::DerivativesManager::DerivativeJob, component.pid, :multires_image)
    end
  end
end
