require 'optparse'

DEFAULT_SORT = "#{Ddr::IndexFields::IDENTIFIER} ASC, #{Ddr::IndexFields::OBJECT_CREATE_DATE} ASC"

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

uses = {}
structure = {}
content_seq = 0
thumbnail_seq = 0

comps.each do |c|
  doc = SolrDocument.new(c)
  if doc.has_content?
    content_seq += 1
    use = case doc.content_type
    when "image/tiff"
      "image/master"
    when "application/pdf"
      "pdf/reference"
    when "application/octet-stream"
      "application/reference"
    end
    uses[use] ||= []
    uses[use] << { pid: doc.id, identifier: doc[Ddr::IndexFields::IDENTIFIER] || doc.id, seq: content_seq, datastream: 'content' }
  end
  if doc.has_thumbnail?
    thumbnail_seq += 1
    use = "image/thumbnail"
    uses[use] ||= []
    uses[use] << { pid: doc.id, identifier: doc[Ddr::IndexFields::IDENTIFIER] || doc.id, seq: thumbnail_seq, datastream: 'thumbnail' }
  end
end

METS_NAMESPACE = "http://www.loc.gov/METS/"
METS_SHELL = <<-EOS
  <mets xmlns="#{METS_NAMESPACE}" xmlns:xlink="http://www.w3.org/1999/xlink">
    <fileSec />
    <structMap />
  </mets>
EOS

mets = Nokogiri::XML(METS_SHELL) do |config|
  config.default_xml.noblanks
end

# fileSec
fileSecNode = mets.xpath("//mets:fileSec", "mets" => METS_NAMESPACE).first
uses.keys.each do |use|
  fileGrpNode = Nokogiri::XML::Node.new("fileGrp", mets)
  fileGrpNode['USE'] = use
  fileSecNode.add_child(fileGrpNode)
  uses[use].each do |file|
    # create fileSec nodes
    fileNode = Nokogiri::XML::Node.new("file", mets)
    fileNode['ID'] = "#{file[:identifier]}-#{use.split('/').last}"
    fileNode['GROUPID'] = file[:identifier]
    fileNode['SEQ'] = file[:seq]
    fileGrpNode.add_child(fileNode)
    fLocatNode = Nokogiri::XML::Node.new("FLocat", mets)
    fLocatNode['LOCTYPE'] = "OTHER"
    fLocatNode['OTHERLOCTYPE'] = "Fedora object datastream"
    fLocatNode['xlink:href'] = "#{file[:pid]}/#{file[:datastream]}"
    fileNode.add_child(fLocatNode)
    # collect data for structMap nodes
    structure[file[:identifier]] ||= []
    structure[file[:identifier]] << { fileid: fileNode['ID'] }
  end
end

# structMap
structMapNode = mets.xpath("//mets:structMap", "mets" => METS_NAMESPACE).first
itemDivNode = Nokogiri::XML::Node.new("div", mets)
itemDivNode['TYPE'] = 'item'
structMapNode.add_child(itemDivNode)
order = 0
structure.keys.sort.each do |struct_key|
  order += 1
  fileDivNode = Nokogiri::XML::Node.new("div", mets)
  fileDivNode['ID'] = struct_key
  fileDivNode['TYPE'] = 'file'
  fileDivNode['ORDER'] = order
  itemDivNode.add_child(fileDivNode)
  structure[struct_key].each do |file|
    fptrDivNode = Nokogiri::XML::Node.new("fptr", mets)
    fptrDivNode['FILEID'] = file[:fileid]
    fileDivNode.add_child(fptrDivNode)
  end
end

puts mets.to_xml
