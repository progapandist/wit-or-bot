module Training
  # USER-AIDED TRAINING
  def was_it_a_question_replies
    UI::QuickReplies.build(
     ['Yes', 'VALID_QUESTION'],
     ['No', 'NOT_VALID_QUESTION'],
     ['It was a statement', 'NOT_A_QUESTION']
   )
  end

  def possible_error_replies
    replies = [
      ['Wrong question type', 'WRONG_TYPE'],
      ['Wrong choices', 'WRONG_CHOICES'],
      ['Nevermind', 'ALL_OK']
    ]
    UI::QuickReplies.build(*replies)
  end

  def  question_types_replies
    replies = [
      ['Multiple choice', 'OR_QUESTION'],
      ['Yes/No question', 'YES_NO_QUESTION'],
      ['Nevermind', 'NOT_A_QUESTION'],
    ]
    UI::QuickReplies.build(*replies)
  end

  def agree_to_correct
    if @message.quick_reply == 'YES' || @message.text =~ /yes/i
      say "Here's what we are correcting: \n\nYou: \"#{@user.session[:needs_correction]}\" \nMe: \"#{@user.session[:last_answer]}\" \n\nWhat did I get wrong?",
        quick_replies: possible_error_replies
      next_command :start_correction
    else
      say "Nervermind. Let's do it later!"
      stop_thread
    end
  end

  def start_correction
    if @message.quick_reply == 'WRONG_TYPE'
      ask_correct_question_type
    elsif @message.quick_reply == 'WRONG_CHOICES'
      trt = Rubotnik::WitUnderstander.build_trait_entity(:intent, 'or_question')
      @user.session[:correct_trait] = trt
      ask_correct_entities
    elsif @message.quick_reply == 'ALL_OK'
      say 'No problem.'
      stop_thread
    else
      say 'Sorry! I can only learn if you correct me'
      stop_thread
    end
  end

  def handle_was_it_a_question
    if @message.quick_reply == 'NOT_A_QUESTION'
      say "Noted. Let's try again ;) " \
          'Ask me a question!'
      # That was not a question, so we mark sentiment as neutral
      trait = Rubotnik::WitUnderstander.build_trait_entity(:sentiment, 'neutral')
      @nlu.train(@user.session[:needs_correction], trait_entity: trait)
      stop_thread
    elsif @message.quick_reply == 'NOT_VALID_QUESTION'
      say "All right then. Give me a good one!"
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

    if @message.quick_reply == "NOT_A_QUESTION"
      say 'Fine, noted!'
      stop_thread
      return
    end

    question = @message.quick_reply.downcase
    trait = Rubotnik::WitUnderstander.build_trait_entity(:intent, question)

    # It's not an OR question, so we don't have to ask for entities
    if question != 'or_question'
      @nlu.train(original_text, trait_entity: trait)
      say 'Thank you for cooperation! I just got a bit smarter'

      if question == 'yes_no_question'
        say "By the way, answering your last question: #{%w[yes no].sample}"
      end
      stop_thread
      return
    end

    # Ask for correct entities if it was an OR question
    @user.session[:correct_trait] = trait
    ask_correct_entities
  end

  def ask_correct_entities
    say "What were the choices? Separate them by commas. " \
        "Use exact wording, please. Otherwise I won't learn on my mistakes :(",
        quick_replies: UI::QuickReplies.build(['Forget about it', 'STOP_CORRECTION'])
    next_command :correct_entities
  end

  def correct_entities
    if @message.quick_reply == 'STOP_CORRECTION'
      say "Ok, next time then!"
      stop_thread
      return
    end

    original_text = @user.session[:needs_correction]
    trait = @user.session[:correct_trait]
    #  See if user respected the format
    choices = @message.text.split(', ')
    # TODO: that's fucked up. Rewrite!

    entities = Rubotnik::WitUnderstander.build_word_entities(original_text,
                                                            choices,
                                                            :option)
    @nlu.train(original_text,
              trait_entity: trait,
              word_entities: entities) if entities

    say 'Thank you for cooperation! I just got a bit smarter'
    say 'By the way, answering your ' \
    "last question: #{entities.map {|h| h["value"]}.sample}"

    stop_thread
  end
end
