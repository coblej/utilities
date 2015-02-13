colls = ActiveFedora::SolrService.query("#{DulHydra::IndexFields::ACTIVE_FEDORA_MODEL}:Collection", rows: 999999)
colls.each do |coll|
	puts "Oops! Collection #{coll["id"]} has an admin_policy relationship" unless coll["#{DulHydra::IndexFields::IS_GOVERNED_BY}"].empty?
end 