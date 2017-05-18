# rubocop:disable Metrics/ModuleLength
require 'httparty'
require 'json'
require_relative '../ui/ui'
# Everything in this module will become private methods for Dispatch classes
# and will exist in a shared namespace.
module Commands

  def question_type
    @nlu.entity_values(@message.text, :intent).first
  end

  def sentiment(value)
    ent_values = @nlu.entity_values(@message.text, :sentiment)
    !ent_values.empty? && ent_values.include?(value)
  end

  def intents_absent?
    @nlu.entity_values(@message.text, :intent).empty?
  end

  # TODO: Break up into smaller methods
  def nlu_handle_input
    # Wit processing will take a while, so we want to show activity
    @message.mark_seen
    @message.typing_on

    # We need '&& return' to exit from the caller
    # if greeting/thanks/bare sentiment detected
    react_to_greeting && return # Are we being greeted?
    react_to_thanks && return # Are we being thanked?
    # Gauge sentiment. Make sure intents are otherwise absent in a phrase
    react_to_negative_sentiment && return
    react_to_positive_sentiment && return # Is the sentiment positive?
    react_to_neutral_sentiment && return # Is the sentiment neutral?
    avoid_personal_questions && return # Make sure user does not pry

    # Non-questions ruled out, we can
    # save a question to correct later, if needed
    @user.session[:needs_correction] = @message.text

    # Act on a type of question
    unless act_on_question_types
      # No known question types detected.
      # Store unrecognized input in a session, start training scenario.
      @user.session[:needs_correction] = @message.text
      say "Was that a question?", quick_replies: UI::QuickReplies.build(
        %w[Yes YES], %w[No NO], %w[Nevermind NEVERMIND]
      )
      next_command :handle_was_it_a_question
    end

    # We're done replying
    @message.typing_off
  end

  # TODO: separate method for inclusion/abscence check
  def react_to_greeting
    return false unless @nlu.entities(@message.text).include?(:greetings) && intents_absent?
    say "Hello! I can make decisions for you. Ask me a question"
    true
  end

  def react_to_thanks
    return false unless @nlu.entities(@message.text).include?(:thanks) && intents_absent?
    say "You're welcome!"
    true
  end

  def react_to_negative_sentiment
    return false unless sentiment('negative') && intents_absent?
    say "I'm sorry, I'm still learning!"
    if @user.session.key?(:needs_correction)
      say "Did I get your last phrase wrong? " \
          "If I remember correctly, the phrase was: " \
          "#{@user.session[:needs_correction]}",
          quick_replies: possible_error_replies
      next_command :start_correction
    end
    true
  end

  def react_to_positive_sentiment
    return false unless sentiment('positive') && intents_absent?
    say "😎 Let's do another one!"
    true
  end

  def react_to_neutral_sentiment
    return false unless sentiment('neutral') && intents_absent?
    say "Cool. Let's do another one."
    true
  end

  def avoid_personal_questions
    return false unless @message.text =~ /\byou[a-zA-Z']{,3}\b/i
    say "We are not talking about me, sorry."
    true
  end

  # Reacting on different question types
  def act_on_question_types
    case question_type
    when 'yes_no_question' then say %w[Yes No].sample
    when 'or_question' then handle_or_question
    when 'what_question' then handle_what_question
    when 'when_question' then handle_when_question
    when 'where_question' then puts handle_where_question
    when 'who_question' then puts handle_who_question
    else
      return false
    end
  end

  # HANDLERS FOR QUESTIONS TYPES

  def handle_what_question
    say "What are the options? Use 'or' to separate them"
  end

  def handle_when_question
    say "When do you think? Use 'or' to separate options"
  end

  def handle_where_question
    say "Where do you think? Use 'or' to separate options"
  end

  def handle_who_question
    say "Who do you think? Use 'or' to separate options"
  end

  def handle_or_question
    choice = @nlu.entity_values(@message.text, :option).sample
    say pos_pick_answer(choice)
  end

  # POS-ENABLED REACTIONS

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

  # USER-AIDED TRAINING

  def possible_error_replies
    replies = [
      ['Wrong question type', 'WRONG_TYPE'],
      ['Wrong choices', 'WRONG_CHOICES'],
      ["Nevermind", 'ALL_OK']
    ]
    UI::QuickReplies.build(*replies)
  end

  def  question_types_replies
    replies = [
      ['Multiple choice', 'OR_QUESTION'],
      ['Yes/No question', 'YES_NO_QUESTION'],
      ['Who question', 'WHO_QUESTION'],
      ['When question', 'WHEN_QUESTION'],
      ['Where question', 'WHERE_QUESTION']
    ]
    UI::QuickReplies.build(*replies)
  end

  def start_correction
    if @message.quick_reply == 'WRONG_TYPE'
      ask_correct_question_type
    elsif @message.quick_reply == 'WRONG_CHOICES'
      trt = Rubotnik::WitUnderstander.build_trait_entity(:intent, 'or_question')
      ask_correct_entities(trt)
    elsif @message.quick_reply == 'ALL_OK'
      say "No problem."
      stop_thread
    else
      say "Sorry! I can only learn if you correct me"
      stop_thread
    end
  end

  def handle_was_it_a_question
    if @message.quick_reply == 'NO'
      say "I wish I could tell you a joke, but I don't know how to do it yet. " \
          "Ask me a question!"
      # That was not a question, so we mark sentiment as neutral
      trait = Rubotnik::WitUnderstander.build_trait_entity(:sentiment, 'neutral')
      @nlu.train(@user.session[:needs_correction], trait_entity: trait)
      stop_thread
    elsif @message.quick_reply == 'NEVERMIND'
      say "All right then. I'll ignore it"
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
    # retrieve original text from user's session
    original_text = @user.session[:needs_correction]

    # Guard for when we don't have quick replies
    unless @message.quick_reply
      say 'You did not give me a chance to learn, ' \
          'but thanks for cooperation anyway!'
      stop_thread
      return
    end

    question = @message.quick_reply.downcase
    trait = Rubotnik::WitUnderstander.build_trait_entity(:intent, question)

    # It's not an OR question, so we don't have to ask for entities
    if question != 'or_question'
      @nlu.train(original_text, trait_entity: trait)
      say "Thank you for cooperation! I just got a bit smarter"

      if question == 'yes_no_question'
        say "By the way, answering your last question: #{%w[yes no].sample}"
      end
      stop_thread
      return
    end

    # Ask for correct entities if it was an OR question
    ask_correct_entities(trait)
  end

  def ask_correct_entities(correct_trait)
    say "What were the choices? Separate them by 'or' or a comma. " \
        "Use exact wording, please. Otherwise I won't learn on my mistakes :("
    @user.session[:trait] = correct_trait
    next_command :correct_entities
  end

  def correct_entities(*args)
    original_text = @user.session[:needs_correction]
    trait = @user.session[:trait]
    #  See if user respected the format
    input = @message.text
    if input =~ /\w+(, | or )/
     choices = Rubotnik::WitUnderstander.build_word_entities(original_text,
                                                             input,
                                                             :option)
      @nlu.train(original_text, trait_entity: trait, word_entities: choices)
      say "Thank you for cooperation! I just got a bit smarter"
      say "By the way, answering your " \
          "last question: #{choices.map {|h| h["value"]}.sample}"
    else
      say "Too bad, I can only learn if you use commas " \
          "or 'or's to separate options. Try again later!"
    end
    stop_thread
  end

end
