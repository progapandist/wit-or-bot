require 'httparty'
require 'json'
require_relative '../ui/ui'
# Everything in this module will become private methods for Dispatch classes
# and will exist in a shared namespace.
module Commands

  # TODO: Let user train an app. Create WitTrainer class?

  def question_type(value)
    ent_values = @nlu.entity_values(@message.text, :intent)
    !ent_values.empty? && ent_values.include?(value)
  end

  def sentiment(value)
    ent_values = @nlu.entity_values(@message.text, :sentiment)
    !ent_values.empty? && ent_values.include?(value)
  end

  def intents_present?
    @nlu.entity_values(@message.text, :intent).empty?
  end

  def nlu_handle_questions
    @message.typing_on
    
    if @nlu.entities(@message.text).include?(:greetings)
      say "Hello! I can make decisions for you. Ask me a question"
      return
    end

    # TODO: Why do we check for the presence of intents again?
    if sentiment('negative') && intents_present?
      say "I'm sorry you feel this way :( I try to learn!"
      return
    end

    if sentiment('positive') && intents_present?
      say "I appreciate your feedback!"
      return
    end

    if question_type('yes_no_question')
      say %w[Yes No].sample
    elsif question_type('or_question')
      handle_definite_or
    elsif question_type('what_question')
      puts "what question"
      handle_what_question
    elsif question_type('when_question')
      puts "when question"
      handle_when_question

    # TODO: implement

    elsif question_type('where_question')
      puts "where question"
    elsif question_type('who_question')
      puts "who question"
    else
      say "Doesn't look like a question to me"
    end
    @message.typing_off
  end

  def handle_what_question
    @message.typing_on
    say "What are the options? Use 'or' to separate them"
    @message.typing_off
  end

  def handle_when_question
    @message.typing_on
    say "When do you think? Use 'or' to separate them"
    @message.typing_off
  end

  def handle_definite_or
    @message.typing_on
    choice = @nlu.entity_values(@message.text, :option).sample
    say pos_pick_answer(choice)
    @message.typing_off
  end

  # TODO: REMOVE? handle_definite_or will do?
  def handle_possible_or
    if question_type('or_question')
      @message.typing_on
      choice = @nlu.entity_values(@message.text, :option).sample
      say choice
      @message.typing_off
    else
      say "doesn't look like an OR question to me, try again?"
    end
  end


  def pos_pick_answer(string)
    tagger = Rubotnik::Tagger.new
    # array of 2-elements arrays. second element is a Brill tag
    p tagged = tagger.tag(string)
    case tagged.first.last
    # CD stands for digits
    when /NN*/, /JJ*/, /DT/, /CD/
      complement_non_verbs(string)
    when /VB*/
      complement_verbs(string)
    else
      string
    end
  end

  def complement_verbs(string)
    random = ["You should", "If I were you, I'd", "You better", "Certainly", "Probably", "Definitely", "I advice you to", "I urge you to"].sample
    random + " " + string
  end

  def complement_non_verbs(string)
    random = ["Go with", "I'd pick", "Settle on", "Definitely", "Probably", "Absolutely"].sample
    random + " " + string
  end

end
