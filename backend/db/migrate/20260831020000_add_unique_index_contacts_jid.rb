class AddUniqueIndexContactsJid < ActiveRecord::Migration[8.1]
  def change
    # Rede de segurança contra corrida: 2+ webhooks da WAHA/Baileys chegando
    # em paralelo pro mesmo chat (visto ao vivo em 2026-08-31 — 41021668880509@lid
    # gerou 2 Contacts idênticos, quase no mesmo milissegundo) faziam
    # Contact.find_by_any_phone + create! criar duplicata, porque find+create
    # não é atômico. jid é o identificador mais confiável de "mesmo chat"
    # (mais estável que phone, que depende de formatação/@lid resolvido).
    add_index :contacts, [:account_id, :jid], unique: true,
      where: "jid IS NOT NULL", name: "idx_contacts_account_jid_unique"
  end
end
