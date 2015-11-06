CONTENT_BEARING_MODELS = [ 'Attachment', 'Component', 'Target' ]

def model_query(model)
  Ddr::Index::QueryBuilder.build do |query|
    query.q("#{Ddr::Index::Fields::ACTIVE_FEDORA_MODEL}:#{model}").fields("id")
  end
end

def enqueue_index_job(pid)
  Resque.enqueue(DulHydra::Jobs::UpdateIndex, pid)
end

CONTENT_BEARING_MODELS.each do |model|
  result = model_query(model).result
  puts "#{model}: #{result.count}"
  result.each_pid { |pid| enqueue_index_job(pid) }
end