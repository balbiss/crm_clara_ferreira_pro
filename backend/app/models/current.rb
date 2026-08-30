# ActiveSupport::CurrentAttributes — dá pro Contact (model, sem acesso a
# controller) saber "quem" fez uma mudança sem precisar receber isso por
# parâmetro em toda chamada de update. Setado em ApplicationController;
# nulo fora do ciclo de request (jobs em background, sync do Jueri) —
# corretamente significa "mudança feita pelo sistema", não por uma pessoa.
class Current < ActiveSupport::CurrentAttributes
  attribute :user
end
