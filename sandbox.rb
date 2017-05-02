require_relative 'rubotnik/wit_understander'
require_relative 'rubotnik/tagger'

understander = Rubotnik::WitUnderstander.new("ZI243GVZYMZFWGIFMGI4PNUNLGVFLFUZ")

# If first word TO — don't do anything
# If first word is NN* — add a generic verb like "go with"
# If first word is VB* — add modal like "should" or "you better"

question = "thanks"

p understander.full_response(question)

# answer = understander.entity_values(question, :option).sample

def pos_pick_answer(string)
  tagger = Rubotnik::Tagger.new
  p tagged = tagger.tag(string) # array of 2-elements arrays
  case tagged.first.last
  when /TO/, /RB/
    string
  when /NN*/, /JJ*/, /DT/
    complement_non_verbs(string)
  when /VB*/
    complement_verbs(string)
  end
end

def complement_verbs(string)
  random = ["You should", "If I were you, I'd", "You better", "Certainly", "Probably", "Definitely", "Absolutely"].sample
  random + " " + string
end

def complement_non_verbs(string)
  random = ["Go with", "I'd pick", "Settle on", "Definitely", "Probably", "Absolutely", "I avice you to", "I urge you to"].sample
  random + " " + string
end

# p pos_pick_answer(answer)
