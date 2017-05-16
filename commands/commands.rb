# rubocop:disable Metrics/ModuleLength
require 'httparty'
require 'json'
require_relative '../ui/ui'
# Everything in this module will become private methods for Dispatch classes
# and will exist in a shared namespace.
module Commands

  def question_type(value)
    ent_values = @nlu.entity_values(@message.text, :intent)
    !ent_values.empty? && ent_values.include?(value)
  end

  def sentiment(value)
    ent_values = @nlu.entity_values(@message.text, :sentiment)
    !ent_values.empty? && ent_values.include?(value)
  end

  def intents_absent?
    @nlu.entity_values(@message.text, :intent).empty?
  end

  def nlu_handle_questions
    # Wit processing will take a while, so we want to show activity
    @message.mark_seen
    @message.typing_on
    # We are being greeted
    if @nlu.entities(@message.text).include?(:greetings)
      say "Hello! I can make decisions for you. Ask me a question"
      return
    end
    # We are being thanked
    if @nlu.entities(@message.text).include?(:thanks)
      say "You're welcome!"
      return
    end
    # Gauge sentiment
    # Make sure intents are otherwise absent in a phrase
    if sentiment('negative') && intents_absent?
      say "I'm sorry, I'm still learning. Did I get your last phrase wrong?",
          quick_replies: possible_error_replies
      say "The phrase was: #{@user.session[:original_text]}"
      next_command :start_correction
      return
    end

    if sentiment('positive') && intents_absent?
      say "Thanks for being nice to me!"
      return
    end

    # Non-question ruled out, we can
    # save a question to correct later, if needed
    @user.session[:original_text] = @message.text

    # Reacting on different question types
    if question_type('yes_no_question')
      say %w[Yes No].sample
    elsif question_type('or_question')
      handle_or_question
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

    else # No question types detected
      # store unrecognized input in a session
      @user.session[:original_text] = @message.text
      say "Was that a question?",
      quick_replies: UI::QuickReplies.build(%w[Yes YES], %w[No NO])
      next_command :handle_was_it_a_question
    end
    @message.typing_off
  end

  # Handlers for question types

  def handle_what_question
    say "What are the options? Use 'or' to separate them"
  end

  def handle_when_question
    say "When do you think? Use 'or' to separate them"
  end

  def handle_or_question
    choice = @nlu.entity_values(@message.text, :option).sample
    say pos_pick_answer(choice)
  end

  # Compose the reply based on POS of the choice
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
    random = ["You should",
              "If I were you, I'd",
              "You better", "Certainly",
              "Probably", "Definitely",
              "I advise you to",
              "I urge you to"].sample
    random + " " + string
  end

  def complement_non_verbs(string)
    random = ["Go with",
              "I'd pick",
              "Settle on",
              "Definitely",
              "Probably",
              "Absolutely"].sample
    random + " " + string
  end

  # USER TRAINING

  def possible_error_replies
    replies = [
      ['Wrong question type', 'WRONG_TYPE'],
      ['Wrong choices', 'WRONG_CHOICES']
    ]
    UI::QuickReplies.build(*replies)
  end

  def  question_types_replies
    replies = [
      ['Multiple choice', 'OR_QUESTION'],
      ['Yes/No question', 'YES_NO_QUESTION'],
    ]
    UI::QuickReplies.build(*replies)
  end

  def start_correction
    if @message.quick_reply == 'WRONG_TYPE'
      ask_correct_question_types
    elsif @message.quick_reply == 'WRONG_CHOICES'
      trait = Rubotnik::WitUnderstander.build_trait_entity(:intent, 'or_question')
      ask_correct_entities(trait)
    else
      say "Sorry! I can only learn if you correct me"
      stop_thread
    end
  end

  def handle_was_it_a_question
    if @message.quick_reply == 'NO'
      say "I wish I could tell you a joke, but I don't know how to do it yet. Ask me a question!"
      stop_thread
    else
      ask_correct_question_type
    end
  end

  def ask_correct_question_type
    say 'What type of question?', quick_replies: question_types_replies
    next_command :correct_question_type
  end

  def correct_question_type
    # retrieve original text from User
    original_text = @user.session[:original_text]

    # Guard for when we don't have quick replies
    unless @message.quick_reply
      say 'You did not give me a chance to learn, but thanks for cooperation anyway!'
      stop_thread
      return
    end

    question = @message.quick_reply.downcase
    trait = Rubotnik::WitUnderstander.build_trait_entity(:intent, question)

    # TODO: Answer "yes" or "no" right away
    # It's not an OR question, so we don't have to ask for entities
    if question == 'yes_no_question'
      @nlu.train(original_text, trait_entity: trait)
      say "Thank you for cooperation! I just got a bit smarter"
      say "By the way, the answer to your last question: #{%w[yes no].sample}"
      stop_thread
      return
    end

    # Ask for correct entities if it was an OR question
    ask_correct_entities(trait)
  end

  def ask_correct_entities(correct_trait)
    say "What were the choices? Separate them by 'or' or a comma. \
    Use exact wording, please. Otherwise I won't learn on my mistakes :("
    @user.session[:trait] = correct_trait
    next_command :correct_entities
  end

  # TODO: make sure it won't break if user does not follow
  # 'or' or 'comma' format
  def correct_entities(*args)
    original_text = @user.session[:original_text]
    trait = @user.session[:trait]
    choices = Rubotnik::WitUnderstander.build_word_entities(original_text,
                                                            @message.text,
                                                            :option)
    @nlu.train(original_text, trait_entity: trait, word_entities: choices)
    say "Thank you for cooperation! I just got a bit smarter"
    say "By the way, the answer to your last question: #{choices.map {|h| h["value"]}.sample}"
    stop_thread
  end

end
