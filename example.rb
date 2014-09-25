DELIM = "\n" + "-"*40 + "\n"

# Adds Duke terms XML namespace to doc if missing
def add_ns(doc)
  unless doc.namespaces.include? "xmlns:#{DulHydra::Metadata::DukeTerms::NAMESPACE_PREFIX}"
    doc.root.add_namespace(DulHydra::Metadata::DukeTerms::NAMESPACE_PREFIX, 
                           DulHydra::Metadata::DukeTerms::XMLNS)
  end
  doc
end

# Write descMetadata version history to string
def version_history(obj)
  hist = obj.descMetadata.versions.collect do |version|
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
The descMetadata inline datastream for this object was purged and re-added as a managed datastream in order to add the Duke terms XML namespace declaration to the root element of the content document. The original content version history is preserved below.
#{DELIM}
#{history}
  EOS
end

def purge_desc_metadata(obj)
  cmd = "curl -u %{user}:%{password} -X DELETE %{url}/objects/%{pid}/datastreams/descMetadata"
  if system(cmd % ActiveFedora.config.credentials.merge(pid: obj.pid))
    puts "Purged #{obj.pid}/descMetadata datastream"
  else
    raise "Purge of #{obj.pid}/descMetadata datastream failed"
  end
end

ActiveFedora::Base.find_each({}, {cast: true}) do |obj|
  next unless obj.datastreams.include?("descMetadata") && obj.descMetadata.is_a?(DulHydra::Datastreams::DescriptiveMetadataDatastream)
  if obj.descMetadata.inline?
      # Save the current content
      doc = obj.descMetadata.ng_xml
      # Save the version history
      history = version_history(obj)
      # Purge the datastream
      purge_desc_metadata(obj)
      # Add managed datastream with Duke terms namespace
      obj = ActiveFedora::Base.find(obj.pid)
      obj.descMetadata.ng_xml = add_ns(doc)
      unless obj.valid?
        puts "WARNING -- #{obj.pid} does not validate! Saving anyway ..."
      end
      obj.save(validate: false)
      puts "Added #{obj.pid}/descMetadata datastream"
      UpdateEvent.create(pid: obj.pid, 
                         summary: "descMetadata datastream purged and re-added",
                         detail: event_detail(history))
  else # managed datastream
      obj.descMetadata.ng_xml = add_ns(obj.descMetadata.ng_xml)
      if obj.descMetadata.content_changed?
        unless obj.valid?
          puts "WARNING -- #{obj.pid} does not validate! Saving anyway ..."
        end
        obj.save(validate: false)
        puts "Added Duke terms XML namespace to #{obj.pid}/descMetadata"
        UpdateEvent.create(pid: obj.pid, 
                           summary: "Duke terms XML namespace added to descriptive metadata")

      end
  end
end
