# Garante que o bucket do MinIO exista antes do primeiro upload — sem isso
# a primeira tentativa de anexar um arquivo falharia com "NoSuchBucket", e
# não temos acesso a shell no container pra rodar `mc mb` manualmente.
if ENV.fetch("ACTIVE_STORAGE_SERVICE", "local") == "minio"
  Rails.application.config.after_initialize do
    begin
      require "aws-sdk-s3"

      client = Aws::S3::Client.new(
        endpoint: ENV.fetch("MINIO_ENDPOINT", "http://clara-minio:9000"),
        access_key_id: ENV.fetch("MINIO_ACCESS_KEY", ""),
        secret_access_key: ENV.fetch("MINIO_SECRET_KEY", ""),
        region: "us-east-1",
        force_path_style: true
      )

      bucket = ENV.fetch("MINIO_BUCKET", "clara-crm")
      client.head_bucket(bucket: bucket)
    rescue Aws::S3::Errors::NotFound
      client.create_bucket(bucket: bucket)
      Rails.logger.info("[MinIO] Bucket '#{bucket}' criado.")
    rescue StandardError => e
      Rails.logger.error("[MinIO] Falha ao verificar/criar bucket: #{e.message}")
    end
  end
end
