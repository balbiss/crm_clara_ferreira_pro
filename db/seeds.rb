# Clear existing data
Message.destroy_all
Conversation.destroy_all
Contact.destroy_all
User.destroy_all
Account.destroy_all

# Create Account
account = Account.create!(name: 'Clara Ferreira Acessórios')

# Create User
# ATENÇÃO: troque essa senha antes de rodar em qualquer ambiente compartilhado.
user = User.create!(
  account: account,
  email: 'admin@claraferreira.example.com',
  password: 'MudeEstaSenha123!',
  password_confirmation: 'MudeEstaSenha123!',
  first_name: 'Clara',
  last_name: 'Ferreira',
  role: :admin
)

# Create Contacts (dado fictício de exemplo — revendedoras reais virão via sync com o Jueri)
contact1 = Contact.create!(
  account: account,
  name: 'Amanda Rocha',
  email: 'amanda@example.com',
  phone: '+55 31 99812-4471'
)

contact2 = Contact.create!(
  account: account,
  name: 'Patrícia Mendes',
  email: 'patricia@example.com',
  phone: '+55 19 99440-2218'
)

# Create Conversations
conv1 = Conversation.create!(
  account: account,
  contact: contact1,
  user: user,
  status: :open,
  source: 'whatsapp',
  unread_count: 2
)

conv2 = Conversation.create!(
  account: account,
  contact: contact2,
  user: user,
  status: :open,
  source: 'whatsapp',
  unread_count: 0
)

# Create Messages
Message.create!(
  account: account,
  conversation: conv1,
  sender_type: 'Contact',
  sender_id: contact1.id,
  text: 'Oi, boa noite!',
  status: :read,
  created_at: 1.hour.ago
)

Message.create!(
  account: account,
  conversation: conv1,
  sender_type: 'User',
  sender_id: user.id,
  text: 'Boa noite Amanda, como posso ajudar?',
  status: :read,
  created_at: 55.minutes.ago
)

Message.create!(
  account: account,
  conversation: conv2,
  sender_type: 'Contact',
  sender_id: contact2.id,
  text: 'Pode me enviar o catálogo atualizado?',
  status: :read,
  created_at: 1.day.ago
)

puts "Database seeded successfully!"
