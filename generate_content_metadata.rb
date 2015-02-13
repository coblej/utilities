require 'optparse'

DEFAULT_SORT = "#{Ddr::IndexFields::IDENTIFIER} ASC"
METS_NAMESPACE = "http://www.loc.gov/METS/"
METS_SHELL = <<-EOS
  <mets xmlns="#{METS_NAMESPACE}" xmlns:xlink="http://www.w3.org/1999/xlink">
    <fileSec />
    <structMap />
  </mets>
EOS

options = { sort: DEFAULT_SORT }
OptionParser.new do |opts|
  opts.on '-p', '--pid ITEM_PID', 'Item PID' do |p|
    options[:pid] = p
  end
  opts.on '-s', '--sort SORT', 'Sort statement' do |s|
    options[:sort] = s
  end
end.parse!

item = Item.find(options[:pid])

comps = item.children(response_format: :solr, sort: options[:sort])

identifiers = {}
media = {}
thumbnails = []
comps.each do |c|
  doc = SolrDocument.new(c)
  puts "#{doc.id} #{doc.content_type}"
  identifiers[doc.id] = doc.identifier
  media[doc.content_type] ||= []
  media[doc.content_type] << doc.id
  thumbnails << doc.id if doc.has_thumbnail?
end

mets = Nokogiri::XML(METS_SHELL)
fileSecNodeSet = mets.xpath("//mets:fileSec", "mets" => METS_NAMESPACE)
fileSecNode = fileSecNodeSet.first
media.keys.each do |m|
  use = case m
  when "image/tiff"
    "image/master"
  when "application/pdf"
    "pdf/reference"
  end
  fileGrpNode = Nokogiri::XML::Node.new("fileGrp", mets)
  fileGrpNode['USE'] = use
  fileSecNode.add_child(fileGrpNode)
  seq = 0
  media[m].each do |obj_id|
    seq += 1
    fileNode = Nokogiri::XML::Node.new("file", mets)
    fileNode['ID'] = "#{identifiers[obj_id]}-#{use.split('/').last}"
    fileNode['GROUPID'] = identifiers[obj_id]
    fileNode['SEQ'] = seq
    fileGrpNode.add_child(fileNode)
    fLocatNode = Nokogiri::XML::Node.new("FLocat", mets)
    fLocatNode['LOCTYPE'] = "OTHER"
    fLocatNode['OTHERLOCTYPE'] = "Fedora3 Datastream"
    fLocatNode['xlink:href'] = "#{obj_id}/content"
    fileNode.add_child(fLocatNode)
  end
end

puts mets.to_xml
