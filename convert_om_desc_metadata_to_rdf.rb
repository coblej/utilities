DELIM = "\n" + "-"*40 + "\n"

# Write descMetadata version history to string
def version_history(af_obj)
  # need object to be an uncast ActiveFedora object
  hist = af_obj.datastreams['descMetadata'].versions.collect do |version|
    <<-EOS
dsVersionID: #{version.dsVersionID}
asOfDateTime: #{version.asOfDateTime}

#{version.content}
    EOS
  end
  hist.join(DELIM)
end

# Write an event detail note for purge and re-add
def event_detail(history)
  <<-EOS
The descMetadata datastream for this object was purged and re-added in order to convert it from an OM datastream to a RDF datastream. The previous content version history is preserved below.
#{DELIM}
#{history}
  EOS
end

# Read the current version of the contents of the descMetadata datastream using Fedora REST API
def read_desc_metadata(obj)
  cmd = "curl -s -u %{user}:%{password} -X GET %{url}/objects/%{pid}/datastreams/descMetadata/content"
  %x( #{cmd % ActiveFedora.config.credentials.merge(pid: obj.pid)} )
end

# Purge the descMetadata datastream using the Fedora REST API
def purge_desc_metadata(obj)
  cmd = "curl -u %{user}:%{password} -X DELETE %{url}/objects/%{pid}/datastreams/descMetadata"
  if system(cmd % ActiveFedora.config.credentials.merge(pid: obj.pid))
    puts "Purged #{obj.pid}/descMetadata datastream"
  else
    raise "Purge of #{obj.pid}/descMetadata datastream failed"
  end
end

# Main processing block
ActiveFedora::Base.find_each({}, {cast: false}) do |af_obj|
  # do not need object cast as a DulHydra model object at this point
  next unless af_obj.datastreams.include?("descMetadata")
  if af_obj.datastreams['descMetadata'].mimeType == "text/xml"
    doc = Nokogiri::XML(read_desc_metadata(af_obj)) { |config| config.noblanks }
    if doc.errors.empty?
      # Save the version history
      history = version_history(af_obj)
      # Purge the existing datastream
      purge_desc_metadata(af_obj)
      # Reload the object
      dh_obj = ActiveFedora::Base.find(af_obj.pid)
      # now we do need the object cast as a DulHydra model object
      # Interate through XML nodes and set corresponding terms and values in RDF version
      doc.root.children.each do |node|
        dh_obj.descMetadata.add_value(node.name, node.content)
      end
      unless dh_obj.valid?
        puts "WARNING -- #{dh_obj.pid} does not validate! Saving anyway ..."
      end
      dh_obj.save(validate: false)
      UpdateEvent.create(pid: dh_obj.pid, 
                        summary: "descMetadata datastream purged and re-added",
                        detail: event_detail(history))
    else
      puts "Unable to parse #{af_obj.pid} descMetadata as XML ... skipped"
    end
  else
      puts "#{af_obj.pid} descMetadata not type text/xml ... skipped"
  end
end