class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext
  context_to_action!


  def start(*)
    respond_with :message, text: t('.content')
  end

  def help(*)
    respond_with :message, text: t('.content')
  end

  def moegirl_api(term)
    client = MediawikiApi::Client.new "https://zh.moegirl.org/api.php"
    response = client.action :parse, page: term, section: 0, uft8: 1, redirects: 1, prop: %w(text)
    puts response.data
    html_doc = Nokogiri::HTML(response.data['text']['*'])
    summary = ''
    html_doc.css('p:first-of-type').each do |p|
      summary = p.content
      break
    end
    # respond_with :message, text: summary
    img_link=''
    html_doc.css('table > tr:nth-child(1) > td > span > a > img').each do |img|
      puts img
      img_link = img['src']
      break
    end
    unless img_link.empty? and summary.empty?
      respond_with :photo, photo: img_link, caption: summary
    end


  end

  def moegirl(term)

    img_link, summary = get_moe_girl_info(term)

    if img_link.empty? or summary.empty?
      if summary.empty?
        respond_with :photo, photo: 'https://img.moegirl.org/common/1/1a/%E5%AF%BF%E5%8F%B8%E8%90%8C%E7%99%BE%E5%A8%98.png', caption: t('.missing')
      else
        respond_with :message, text: summary
      end

    else
      puts img_link.empty?, summary
      respond_with :photo, photo: img_link, caption: summary

    end
  end


  def memo(*args)
    if args.any?
      session[:memo] = args.join(' ')
      respond_with :message, text: t('.notice')
    else
      respond_with :message, text: t('.prompt')
      save_context :memo
    end
  end

  def remind_me
    to_remind = session.delete(:memo)
    reply = to_remind || t('.nothing')
    respond_with :message, text: reply
  end

  def keyboard(value = nil, *)
    if value
      respond_with :message, text: t('.selected', value: value)
    else
      save_context :keyboard
      respond_with :message, text: t('.prompt'), reply_markup: {
          keyboard: [t('.buttons')],
          resize_keyboard: true,
          one_time_keyboard: true,
          selective: true,
      }
    end
  end

  def inline_keyboard
    respond_with :message, text: t('.prompt'), reply_markup: {
        inline_keyboard: [
            [
                {text: t('.alert'), callback_data: 'alert'},
                {text: t('.no_alert'), callback_data: 'no_alert'},
            ],
            [{text: t('.repo'), url: 'https://github.com/telegram-bot-rb/telegram-bot'}],
        ],
    }
  end

  def callback_query(data)
    if data == 'alert'
      answer_callback_query t('.alert'), show_alert: true
    else
      answer_callback_query t('.no_alert')
    end
  end

  def message(message)
    respond_with :message, text: t('.content', text: message['text'])
  end

  def inline_query(query, offset)
    query = query.first(10) # it's just an example, don't use large queries.
    t_description = t('.description')
    t_content = t('.content')
    results = 5.times.map do |i|
      {
          type: :article,
          title: "#{query}-#{i}",
          id: "#{query}-#{i}",
          description: "#{t_description} #{i}",
          input_message_content: {
              message_text: "#{t_content} #{i}",
          },
      }
    end
    answer_inline_query results
  end

  # As there is no chat id in such requests, we can not respond instantly.
  # So we just save the result_id, and it's available then with `/last_chosen_inline_result`.
  def chosen_inline_result(result_id, query)
    session[:last_chosen_inline_result] = result_id
  end

  def last_chosen_inline_result
    result_id = session[:last_chosen_inline_result]
    if result_id
      respond_with :message, text: t('.selected', result_id: result_id)
    else
      respond_with :message, text: t('.prompt')
    end
  end

  def action_missing(action, *_args)
    if command?
      respond_with :message, text: t('telegram_webhooks.action_missing.command', command: action)
    else
      respond_with :message, text: t('telegram_webhooks.action_missing.feature', action: action)
    end
  end

  private

  def get_moe_girl_info(term)
    encoded_term = URI.encode term

    begin
      html_doc = Nokogiri::HTML(open("https://zh.moegirl.org/zh-hant/#{encoded_term}"))
      summary = ''
      html_doc.css('#mw-content-text > p').each do |p|
        puts p
        summary = p.content
        break
      end

      # respond_with :message, text: summary
      img_link=''
      html_doc.css('#mw-content-text > div.infotemplatebox > table > tr:nth-child(1) > td > span > a > img').each do |img|
        puts img
        img_link = img['src']
        break
      end
      if img_link.empty?
        puts 'try another way'
        html_doc.css('#mw-content-text table img').each do |img|
          puts img
          img_link = img['src']
          break
        end
      end
      return img_link, summary
    rescue OpenURI::HTTPError => e
      if e.message == '404 Not Found'
        # handle 404 error
        return '', ''
      else
        raise e
      end
    end


  end

end


