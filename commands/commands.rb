# rubocop:disable Metrics/ModuleLength
require 'httparty'
require 'json'
require_relative '../ui/ui'
require_relative './training'
# Everything in this module will become private methods for Dispatch classes
# and will exist in a shared namespace.
module Commands
  include Training

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

  def entity_and_no_intents?(entity)
    @nlu.entities(@message.text).include?(entity) && intents_absent?
  end

  # We route all input to this method
  def nlu_handle_input
    # Wit processing will take a while, so we want to show activity
    @message.mark_seen
    @message.typing_on
    return if acted_on_non_questions?
    # Non-questions ruled out, we can
    # save a question to correct later, if needed
    @user.session[:needs_correction] = @message.text
    # Act on a type of question
    act_on_question_types
    # We're done replying
    @message.typing_off
  end

  def acted_on_non_questions?
    any_method_returned_true? do
      next if react_to_greeting # break out of the block and deliver value
      next if react_to_thanks
      next if react_to_negative_sentiment
      next if react_to_positive_sentiment
      next if react_to_neutral_sentiment
      next if avoid_personal_questions
      true # we need this to return a boolean from the block anyway
    end
  end

  # Fancy helper. Kind of mindfuck.
  def any_method_returned_true?
    # will return true if one of block methods returns true
    # when called with "next if"
    true unless yield # AAAAAAAA!
  end

  def react_to_greeting
    return false unless entity_and_no_intents?(:greetings)
    say "Hello! Uncertain about something? Hard to choose? I can help you with that! :) " \
        'Ask me any yes/no question or the one that implies multiple choice.'
    sleep(0.5)
    say "Examples:\n\nShould I stay or should I go?\nWill I get a raise this year?\nHeads or tails?"
    sleep(0.5)
    say "You can also correct me whenever you want. Try typing 'wrong' after I messed up."
    true
  end

  def react_to_thanks
    return false unless entity_and_no_intents?(:thanks)
    say "You're welcome!"
    true
  end

  def react_to_negative_sentiment
    return false unless sentiment('negative') && intents_absent?
    say "Feels like you're unhappy with me. Sorry about that!"
    if @user.session.key?(:needs_correction)
      sleep(1)
      say 'Do you want to correct me so next time I do better?',
        quick_replies: UI::QuickReplies.build('Yes', 'No')
      next_command :agree_to_correct
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
    say 'We are not talking about me, sorry.'
    true
  end

  # Reacting on different question types
  def act_on_question_types
    case question_type
    when 'yes_no_question' then handle_yes_no_question
    when 'or_question' then handle_or_question
    else
      handle_not_a_question
    end
  end

  # HANDLERS FOR QUESTIONS TYPES

  def handle_yes_no_question
    answer = %w[Yes No].sample
    @user.session[:last_answer] = answer
    say answer
  end

  def handle_or_question
    choice = @nlu.entity_values(@message.text, :option).sample
    answer = pos_pick_answer(choice)
    @user.session[:last_answer] = answer
    say answer
  end

  def handle_not_a_question
    # No known question types detected.
    # Store unrecognized input in a session, start training scenario.
    @user.session[:needs_correction] = @message.text
    attempts_count = increment_attempts
    # loop over possible answers
    phrase = pick_not_question_prompt(attempts_count)
    say phrase, quick_replies: was_it_a_question_replies
    next_command :handle_was_it_a_question
  end

  def increment_attempts
    sesh = @user.session
    sesh.key?(:invalid_questions_count) ? sesh[:invalid_questions_count] += 1 :
                                          sesh[:invalid_questions_count] = 0
    sesh[:invalid_questions_count]
  end

  def pick_not_question_prompt(attempts)
    correct_me = "Please, correct me if I was wrong. Was it a valid question after all?"
    prompts = [
      'That does not seem like a valid question to me. ' \
      'Remember, I can only answer questions that can be answered ' \
      "'yes' or 'no' or that contain multiple choice. " + correct_me,
      'Sorry, I did not recognize that one as a valid question either. ' + correct_me,
      'I hate to say it agan, but I can only answer two types of questions: ' \
      "those that contain multiple choice or those that can be answered " \
      "'yes' or 'no'. " + correct_me,
      "May be it will be easier with an example:\n" \
      "Good question: 'Should I order Indian or Chinese?'\n" \
      "Bad question: 'What's the meaning of life?' " + correct_me
    ]
    prompts[attempts % prompts.size]
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
    random = ['You should',
              "If I were you, I'd",
              'You better', 'Certainly',
              'Probably', 'Definitely',
              'I advise you to',
              'I urge you to'].sample
    random + " " + string
  end

  def complement_non_verbs(string)
    random = ['Go with',
              "I'd pick",
              'Settle on',
              'Definitely',
              'Probably',
              'Absolutely'].sample
    random + " " + string
  end

end
