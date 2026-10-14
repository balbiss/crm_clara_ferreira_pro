class AddTranscriptionToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :transcription, :text
  end
end
