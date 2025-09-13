module InputValidation
  extend ActiveSupport::Concern

  # 文字数制限の定数
  MAX_EMPLOYEE_ID_LENGTH = 50
  MAX_PASSWORD_LENGTH = 128
  MAX_STRING_LENGTH = 255

  # 日付形式の正規表現
  DATE_REGEX = /\A\d{4}-\d{2}-\d{2}\z/
  
  # 時間形式の正規表現
  TIME_REGEX = /\A([01]?[0-9]|2[0-3]):[0-5][0-9]\z/

  # 再利用可能なバリデーション関数
  
  def validate_date_format(date_string, redirect_path)
    return true if date_string.blank?
    
    unless date_string.match?(DATE_REGEX)
      flash[:error] = '日付の形式が正しくありません'
      redirect_to redirect_path
      return false
    end
    
    begin
      Date.parse(date_string)
    rescue ArgumentError
      flash[:error] = '無効な日付です'
      redirect_to redirect_path
      return false
    end
    
    true
  end

  def validate_time_format(time_string, redirect_path)
    return true if time_string.blank?
    
    unless time_string.match?(TIME_REGEX)
      flash[:error] = '時間の形式が正しくありません'
      redirect_to redirect_path
      return false
    end
    
    true
  end

  def validate_required_params(params, required_fields, redirect_path)
    missing_fields = required_fields.select { |field| params[field].blank? }
    
    unless missing_fields.empty?
      flash[:error] = 'すべての項目を入力してください。'
      redirect_to redirect_path
      return false
    end
    
    true
  end

  def validate_password_length(password, redirect_path)
    if password.blank?
      flash[:error] = 'パスワードを入力してください'
      redirect_to redirect_path
      return false
    end
    
    if password.length < 8
      flash[:error] = 'パスワードは8文字以上で入力してください'
      redirect_to redirect_path
      return false
    end
    
    if password.length > MAX_PASSWORD_LENGTH
      flash[:error] = 'パスワードが長すぎます'
      redirect_to redirect_path
      return false
    end
    
    true
  end

  def validate_employee_id_format(employee_id, redirect_path)
    if employee_id.blank?
      flash[:error] = '従業員IDを入力してください'
      redirect_to redirect_path
      return false
    end
    
    if employee_id.length > MAX_EMPLOYEE_ID_LENGTH
      flash[:error] = '従業員IDが長すぎます'
      redirect_to redirect_path
      return false
    end
    
    true
  end

  def contains_sql_injection?(input)
    return false if input.blank?
    
    sql_keywords = [
      'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'CREATE', 'ALTER',
      'UNION', 'EXEC', 'EXECUTE', 'SCRIPT', '--', '/*', '*/', ';'
    ]
    
    sql_keywords.any? { |keyword| input.upcase.include?(keyword) }
  end

  def contains_xss?(input)
    return false if input.blank?
    
    xss_patterns = [
      /<script/i, /javascript:/i, /on\w+\s*=/i, /<iframe/i,
      /<object/i, /<embed/i, /<link/i, /<meta/i
    ]
    
    xss_patterns.any? { |pattern| input.match?(pattern) }
  end

  private

  def validate_input_parameters
    case action_name
    when 'login'
      return validate_login_parameters
    when 'setup_initial_password', 'reset_password'
      return validate_password_parameters
    when 'create'
      return validate_create_parameters
    when 'update'
      return validate_update_parameters
    end
    true
  end

  def validate_login_parameters
    employee_id = params[:employee_id]
    password = params[:password]

    # 従業員IDの検証
    if employee_id.blank?
      flash[:alert] = '従業員IDを入力してください'
      redirect_to auth_login_path
      return false
    end

    if employee_id.length > MAX_EMPLOYEE_ID_LENGTH
      flash[:alert] = '従業員IDが長すぎます'
      redirect_to auth_login_path
      return false
    end

    # パスワードの検証
    if password.blank?
      flash[:alert] = 'パスワードを入力してください'
      redirect_to auth_login_path
      return false
    end

    if password.length > MAX_PASSWORD_LENGTH
      flash[:alert] = 'パスワードが長すぎます'
      redirect_to auth_login_path
      return false
    end

    # SQLインジェクション対策
    if contains_sql_injection?(employee_id) || contains_sql_injection?(password)
      flash[:alert] = '無効な文字が含まれています'
      redirect_to auth_login_path
      return false
    end

    true
  end

  def validate_password_parameters
    password = params[:password] || params[:new_password]
    confirm_password = params[:confirm_password]

    if password.blank?
      flash[:alert] = 'パスワードを入力してください'
      render_password_error
      return
    end

    if password.length > MAX_PASSWORD_LENGTH
      flash[:alert] = 'パスワードが長すぎます'
      render_password_error
      return
    end

    if confirm_password && password != confirm_password
      flash[:alert] = 'パスワードが一致しません'
      render_password_error
      return
    end

    # SQLインジェクション対策
    if contains_sql_injection?(password) || (confirm_password && contains_sql_injection?(confirm_password))
      flash[:alert] = '無効な文字が含まれています'
      render_password_error
      return
    end
  end

  def validate_create_parameters
    case controller_name
    when 'shift_exchanges'
      validate_shift_exchange_parameters
    when 'shift_additions'
      validate_shift_addition_parameters
    end
  end

  def validate_shift_exchange_parameters
    applicant_id = params[:applicant_id]
    shift_date = params[:shift_date]
    start_time = params[:start_time]
    end_time = params[:end_time]
    approver_ids = params[:approver_ids]

    # 必須項目の検証
    if applicant_id.blank? || shift_date.blank? || start_time.blank? || end_time.blank?
      flash[:error] = 'すべての項目を入力してください'
      redirect_to new_shift_exchange_path
      return
    end

    if approver_ids.blank?
      flash[:error] = '交代を依頼する相手を選択してください'
      redirect_to new_shift_exchange_path
      return
    end

    # 文字数制限の検証
    if applicant_id.length > MAX_EMPLOYEE_ID_LENGTH
      flash[:error] = '従業員IDが長すぎます'
      redirect_to new_shift_exchange_path
      return
    end

    # 日付形式の検証
    unless shift_date.match?(DATE_REGEX)
      flash[:error] = '日付の形式が正しくありません'
      redirect_to new_shift_exchange_path
      return
    end

    # 時間形式の検証
    unless start_time.match?(TIME_REGEX)
      flash[:error] = '開始時間の形式が正しくありません'
      redirect_to new_shift_exchange_path
      return
    end

    unless end_time.match?(TIME_REGEX)
      flash[:error] = '終了時間の形式が正しくありません'
      redirect_to new_shift_exchange_path
      return
    end

    # SQLインジェクション対策
    if contains_sql_injection?(applicant_id) || contains_sql_injection?(shift_date) ||
       contains_sql_injection?(start_time) || contains_sql_injection?(end_time)
      flash[:error] = '無効な文字が含まれています'
      redirect_to new_shift_exchange_path
      return
    end

    # XSS対策
    if contains_xss?(applicant_id) || contains_xss?(shift_date) ||
       contains_xss?(start_time) || contains_xss?(end_time)
      flash[:error] = '無効な文字が含まれています'
      redirect_to new_shift_exchange_path
      return
    end
  end

  def validate_shift_addition_parameters
    employee_id = params[:employee_id]
    shift_date = params[:shift_date]
    start_time = params[:start_time]
    end_time = params[:end_time]

    # 必須項目の検証
    if employee_id.blank? || shift_date.blank? || start_time.blank? || end_time.blank?
      flash[:error] = 'すべての項目を入力してください'
      redirect_to new_shift_addition_path
      return
    end

    # 文字数制限の検証
    if employee_id.length > MAX_EMPLOYEE_ID_LENGTH
      flash[:error] = '従業員IDが長すぎます'
      redirect_to new_shift_addition_path
      return
    end

    # 日付形式の検証
    unless shift_date.match?(DATE_REGEX)
      flash[:error] = '日付の形式が正しくありません'
      redirect_to new_shift_addition_path
      return
    end

    # 時間形式の検証
    unless start_time.match?(TIME_REGEX)
      flash[:error] = '開始時間の形式が正しくありません'
      redirect_to new_shift_addition_path
      return
    end

    unless end_time.match?(TIME_REGEX)
      flash[:error] = '終了時間の形式が正しくありません'
      redirect_to new_shift_addition_path
      return
    end

    # SQLインジェクション対策
    if contains_sql_injection?(employee_id) || contains_sql_injection?(shift_date) ||
       contains_sql_injection?(start_time) || contains_sql_injection?(end_time)
      flash[:error] = '無効な文字が含まれています'
      redirect_to new_shift_addition_path
      return
    end

    # XSS対策
    if contains_xss?(employee_id) || contains_xss?(shift_date) ||
       contains_xss?(start_time) || contains_xss?(end_time)
      flash[:error] = '無効な文字が含まれています'
      redirect_to new_shift_addition_path
      return
    end
  end

  def validate_update_parameters
    # 更新時のパラメータ検証
    # 必要に応じて実装
  end

  def contains_sql_injection?(input)
    return false if input.blank?
    
    # SQLインジェクション攻撃のパターンを検出
    sql_patterns = [
      /('|(\\')|(;)|(\-\-)|(\/\*)|(\*\/)|(\|)|(\*)|(%)|(\+)|(\=)|(\<)|(\>)|(\[)|(\])|(\{)|(\})|(\()|(\))|(\^)|(\$)|(\?)|(\!)|(\~)|(\`)|(\@)|(\#)|(\&)|(\\)|(\|)|(\:)|(\;)|(\")|(\')|(\x00)|(\x1a)|(\x0d)|(\x0a)|(\x09)|(\x08)|(\x07)|(\x1b)|(\x0c)|(\x0b)|(\x0e)|(\x0f)|(\x10)|(\x11)|(\x12)|(\x13)|(\x14)|(\x15)|(\x16)|(\x17)|(\x18)|(\x19)|(\x1c)|(\x1d)|(\x1e)|(\x1f))/i,
      /(union|select|insert|update|delete|drop|create|alter|exec|execute|script|javascript|vbscript|onload|onerror|onclick|onmouseover|onfocus|onblur|onchange|onsubmit|onreset|onselect|onkeydown|onkeyup|onkeypress|onmousedown|onmouseup|onmousemove|onmouseout|onmouseover|onmouseenter|onmouseleave|ondblclick|oncontextmenu|onwheel|ontouchstart|ontouchend|ontouchmove|ontouchcancel|ongesturestart|ongesturechange|ongestureend|onabort|onafterprint|onbeforeprint|onbeforeunload|onerror|onhashchange|onload|onmessage|onoffline|ononline|onpagehide|onpageshow|onpopstate|onresize|onstorage|onunload)/i
    ]
    
    sql_patterns.any? { |pattern| input.match?(pattern) }
  end

  def contains_xss?(input)
    return false if input.blank?
    
    # XSS攻撃のパターンを検出
    xss_patterns = [
      /<script[^>]*>.*?<\/script>/i,
      /<iframe[^>]*>.*?<\/iframe>/i,
      /<object[^>]*>.*?<\/object>/i,
      /<embed[^>]*>.*?<\/embed>/i,
      /<applet[^>]*>.*?<\/applet>/i,
      /<meta[^>]*>/i,
      /<link[^>]*>/i,
      /<style[^>]*>.*?<\/style>/i,
      /javascript:/i,
      /vbscript:/i,
      /onload\s*=/i,
      /onerror\s*=/i,
      /onclick\s*=/i,
      /onmouseover\s*=/i,
      /onfocus\s*=/i,
      /onblur\s*=/i,
      /onchange\s*=/i,
      /onsubmit\s*=/i,
      /onreset\s*=/i,
      /onselect\s*=/i,
      /onkeydown\s*=/i,
      /onkeyup\s*=/i,
      /onkeypress\s*=/i,
      /onmousedown\s*=/i,
      /onmouseup\s*=/i,
      /onmousemove\s*=/i,
      /onmouseout\s*=/i,
      /onmouseover\s*=/i,
      /onmouseenter\s*=/i,
      /onmouseleave\s*=/i,
      /ondblclick\s*=/i,
      /oncontextmenu\s*=/i,
      /onwheel\s*=/i,
      /ontouchstart\s*=/i,
      /ontouchend\s*=/i,
      /ontouchmove\s*=/i,
      /ontouchcancel\s*=/i,
      /ongesturestart\s*=/i,
      /ongesturechange\s*=/i,
      /ongestureend\s*=/i,
      /onabort\s*=/i,
      /onafterprint\s*=/i,
      /onbeforeprint\s*=/i,
      /onbeforeunload\s*=/i,
      /onerror\s*=/i,
      /onhashchange\s*=/i,
      /onload\s*=/i,
      /onmessage\s*=/i,
      /onoffline\s*=/i,
      /ononline\s*=/i,
      /onpagehide\s*=/i,
      /onpageshow\s*=/i,
      /onpopstate\s*=/i,
      /onresize\s*=/i,
      /onstorage\s*=/i,
      /onunload\s*=/i
    ]
    
    xss_patterns.any? { |pattern| input.match?(pattern) }
  end

  def render_login_error
    case controller_name
    when 'auth'
      render :login, status: :unprocessable_content
    else
      redirect_to auth_login_path
    end
  end

  def render_password_error
    case action_name
    when 'setup_initial_password'
      render :setup_initial_password
    when 'reset_password'
      render :reset_password
    when 'password_change'
      render :password_change
    else
      redirect_to auth_login_path
    end
  end
end
