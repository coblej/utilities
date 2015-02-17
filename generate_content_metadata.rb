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
  identifiers[doc.id] = doc.identifier
  media[doc.content_type] ||= []
  media[doc.content_type] << doc.id
  thumbnails << doc.id if doc.has_thumbnail?
end

mets = Nokogiri::XML(METS_SHELL)

# content files
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

# thumbnail files
fileGrpNode = Nokogiri::XML::Node.new("fileGrp", mets)
fileGrpNode['USE'] = "image/thumbnail"
fileSecNode.add_child(fileGrpNode)
seq = 0
thumbnails.each do |obj_id|
  seq += 1
  fileNode = Nokogiri::XML::Node.new("file", mets)
  fileNode['ID'] = "#{identifiers[obj_id]}-thumbnail"
  fileNode['GROUPID'] = identifiers[obj_id]
  fileNode['SEQ'] = seq
  fileGrpNode.add_child(fileNode)
  fLocatNode = Nokogiri::XML::Node.new("FLocat", mets)
  fLocatNode['LOCTYPE'] = "OTHER"
  fLocatNode['OTHERLOCTYPE'] = "Fedora3 Datastream"
  fLocatNode['xlink:href'] = "#{obj_id}/thumbnail"
  fileNode.add_child(fLocatNode)
end

structMapNodeSet = mets.xpath("//mets:structMap", "mets" => METS_NAMESPACE)
structMapNode = structMapNodeSet.first
# create a div node with attribute TYPE="item"
div0Node = Nokogiri::XML::Node.new("div", mets)
div0Node['TYPE'] = "item"
structMapNode.add_child(div0Node)
# get all the GROUPID attributes in order by SEQ attribute in first file node with that GROUPID
# for each GROUPID, get all the matching file nodes
group_identifiers = identifiers.values
group_identifiers.sort!
group_identifiers.each do |identifier|
  group_fileNodeSet = mets.xpath("//mets:file[@GROUPID='#{identifier}']", "mets" => METS_NAMESPACE)
  divFileNode = Nokogiri::XML::Node.new("div", mets)
  divFileNode['TYPE'] = "file"
  # divFileNode['ORDER'] = 0
  divFileNode['ID'] = identifier
  div0Node.add_child(divFileNode)
  group_fileNodeSet.each do |group_fileNode|
    divFptrNode = Nokogiri::XML::Node.new("fptr", mets)
    divFptrNode['FILEID'] = group_fileNode[@ID]
    divFileNode.add_child(divFptrNode)
  end
end
# for each GROUPID, create a div with TYPE="file", ORDER=SEQ, and ID=GROUPID
# within each file div, add a fptr node for each file node, with FILEID set to the file ID

puts mets.to_xml
