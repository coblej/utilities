DIR_PATH = '/Users/coblej/Support/TUCASI_CIFS2/dpc-archive/Archived_NoAccess/na_BRP/pdfs'
COLL_PID = 'changeme:823'
CHECKSUM_FILE_PATH = '/Users/coblej/Support/TUCASI_CIFS2/dpc-archive/Archived_NoAccess/na_BRP/pdfs/sha256_na_BRP_pdfs_darkstorage.txt'

collection = Collection.find(COLL_PID)

user = User.find_by_username('coblej@duke.edu')

checksums = {}
File.open(CHECKSUM_FILE_PATH).each do |line|
  checksum, path = line.split
  checksums[path] = checksum
end

def checksum_for(file_path, checksums)
  file_name = File.basename(file_path)
  entry = checksums.select { |key, value| key.match(/#{file_name}/) }
  entry.values.first
end

batch = Ddr::Batch::Batch.new.tap do |b|
  b.name = "BRP PDF's Ingest"
  b.user = user
  b.save!
end

Dir.glob("#{DIR_PATH}/*.pdf") do |pdf|
  puts pdf
  local_id = File.basename(pdf, '.pdf')
  batch_object = Ddr::Batch::IngestBatchObject.new.tap do |ibo|
    ibo.batch = batch
    ibo.identifier = local_id
    ibo.model = 'Component'
    ibo.save!
  end
  Ddr::Batch::BatchObjectAttribute.new.tap do |boa|
    boa.batch_object = batch_object
    boa.operation = Ddr::Batch::BatchObjectAttribute::OPERATION_ADD
    boa.datastream = 'adminMetadata'
    boa.name = 'local_id'
    boa.value = local_id
    boa.value_type = Ddr::Batch::BatchObjectAttribute::VALUE_TYPE_STRING
    boa.save!
  end
  Ddr::Batch::BatchObjectRelationship.new.tap do |bor|
    bor.batch_object = batch_object
    bor.operation = Ddr::Batch::BatchObjectRelationship::OPERATION_ADD
    bor.name = Ddr::Batch::BatchObjectRelationship::RELATIONSHIP_ADMIN_POLICY
    bor.object = COLL_PID
    bor.object_type = Ddr::Batch::BatchObjectRelationship::OBJECT_TYPE_PID
    bor.save!
  end
  Ddr::Batch::BatchObjectRelationship.new.tap do |bor|
    bor.batch_object = batch_object
    bor.operation = Ddr::Batch::BatchObjectRelationship::OPERATION_ADD
    bor.name = Ddr::Batch::BatchObjectRelationship::RELATIONSHIP_PARENT
    bor.object = Ddr::Utils.pid_for_identifier(local_id, model: 'Item', collection: collection)
    bor.object_type = Ddr::Batch::BatchObjectRelationship::OBJECT_TYPE_PID
    bor.save!
  end
  Ddr::Batch::BatchObjectDatastream.new.tap do |bod|
    bod.batch_object = batch_object
    bod.operation = Ddr::Batch::BatchObjectDatastream::OPERATION_ADD
    bod.name = Ddr::Datastreams::CONTENT
    bod.payload = pdf
    bod.payload_type = Ddr::Batch::BatchObjectDatastream::PAYLOAD_TYPE_FILENAME
    bod.checksum = checksum_for(pdf, checksums)
    bod.checksum_type = Ddr::Datastreams::CHECKSUM_TYPE_SHA256
    bod.save!
  end
end

batch.status = Ddr::Batch::Batch::STATUS_READY

batch.save!
