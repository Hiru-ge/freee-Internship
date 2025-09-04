/** 
 * デモ事業所(アカウント)を作成とアクセストークンの取得を各自事前におこなってください
 * https://app.secure.freee.co.jp/developers/start_guides/new_user
 * プランの指定は不要です
 * メールタイトル: [freee API] 開発用テスト事業所の作成完了のお知らせ
 * メール認証後、アクセストークン、事業所IDを下の変数にセットしてください
 * 　　※本来アクセストークンは情報漏洩を防ぐために厳格に管理すべきものですが、
 * 　　　今回は課題用のデモ事業所にアクセスするためのものであるためにセキュリティを意識せずに利用します。
 * 　　※アクセストークンには有効期限があります。課題の簡略化のためトークンの更新を行っていません。
 * 　　　有効期限が切れた場合には再度メールからアクセストークン取得ページを開いてアクセストークンを更新してください
 * 
 * またApps Scriptから外部のAPIをcallするために以下の設定をしておいてください
 *   - https://script.google.com/home/usersettings
 */
var accessToken = 'MpeflNrNGLTHEunHirdgeg6CCn6tIC4d5WTa0gj3sK8'
var companyId =  12127317
var SHIFT_SHEET_NAME = "シフト表";
var SHIFT_MANAGEMENT_SHEET_NAME = "シフト交代管理";
var AUTH_SETTINGS_SHEET_NAME = "認証設定";
var VERIFICATION_CODES_SHEET_NAME = "認証コード管理";

var COL_NUM_EMPID = 1
var COL_NUM_MEMO = 2

/**
 * API request optionの共通化
 */
function getRequestOptions(method, payload) {
  return {
    'method' : method || 'get',
    'muteHttpExceptions' : true,
    "contentType": "application/json",
    'headers' : {
      'accept': 'application/json',
      'Authorization': 'Bearer ' + accessToken
    },
    'payload' : payload
  }
}

/**
 * APIレスポンスからデータを抽出するヘルパー関数
 * @param {object} response - UrlFetchApp.fetchのレスポンス
 * @param {string} dataKey - レスポンスから取得するデータのキー（例: 'employees', 'time_clocks'）
 * @param {string} errorContext - エラー時のコンテキスト文字列
 * @returns {object|null} 抽出されたデータ、エラーの場合はnull
 */
function extractApiData(response, dataKey, errorContext) {
  var responseJson = JSON.parse(response.getContentText());
  
  if (response.getResponseCode() != 200) {
    console.error('APIエラー:', responseJson.message || '不明なエラー');
    console.error('レスポンスコード:', response.getResponseCode());
    console.error('レスポンス内容:', responseJson);
    return null;
  }
  
  // レスポンスが配列の場合はそのまま使用、オブジェクトの場合は指定されたキーのプロパティを取得
  var data = Array.isArray(responseJson) ? responseJson : responseJson[dataKey];
  
  if (!data) {
    console.error(errorContext + 'が取得できませんでした:', responseJson);
    return null;
  }
  
  return data;
}

/**
 * 日時を日本語形式でフォーマットするヘルパー関数
 * @param {Date} dateObj - フォーマット対象のDateオブジェクト
 * @returns {string} フォーマットされた日時文字列
 */
function formatDateTimeJapanese(dateObj) {
  return dateObj.getFullYear() + '年' 
    + (dateObj.getMonth() + 1) + '月' 
    + dateObj.getDate() + '日 ' 
    + dateObj.getHours() + '時' 
    + dateObj.getMinutes() + '分';
}

/**
 * シフト時間文字列をパースするヘルパー関数
 * @param {string} timeString - シフト時間文字列（例: "18-20"）
 * @returns {object|null} {startHour: 18, endHour: 20} または null
 */
function parseShiftTime(timeString) {
  if (!timeString || typeof timeString !== 'string') {
    return null;
  }
  
  var parts = timeString.split('-');
  if (parts.length !== 2) {
    return null;
  }
  
  var startHour = parseInt(parts[0], 10);
  var endHour = parseInt(parts[1], 10);
  
  if (isNaN(startHour) || isNaN(endHour)) {
    return null;
  }
  
  return {
    startHour: startHour,
    endHour: endHour
  };
}

/**
 * シフト時間の重複チェックを行うヘルパー関数
 * @param {object} existingShift - 既存のシフト情報 {startHour: 18, endHour: 20}
 * @param {number} requestStartHour - リクエスト開始時刻
 * @param {number} requestEndHour - リクエスト終了時刻
 * @returns {boolean} 重複している場合はtrue
 */
function isShiftOverlapping(existingShift, requestStartHour, requestEndHour) {
  if (!existingShift) {
    return false;
  }
  
  return (existingShift.startHour < requestEndHour) && (existingShift.endHour > requestStartHour);
}

/**
 * ページを開いた時に最初に呼ばれるルートメソッド
 */
function doGet(e) {
  var page = e.parameter.page;

  // ログイン画面のルーティング
  if (page === 'login') {
    return HtmlService.createTemplateFromFile("view_login")
      .evaluate().setTitle("ログイン - 勤怠管理システム");
  }
  
  // 初回パスワード設定画面のルーティング
  if (page === 'initial_password') {
    return HtmlService.createTemplateFromFile("view_initial_password")
      .evaluate().setTitle("初回パスワード設定 - 勤怠管理システム");
  }

  // マイページトップのルーティング
  if (page === 'my_page') {
    if (!isAuthenticated()) {
      return HtmlService.createTemplateFromFile("view_login")
        .evaluate().setTitle("ログイン - 勤怠管理システム");
    }
    return HtmlService.createTemplateFromFile("view_my_page")
      .evaluate().setTitle("マイページ - 勤怠管理システム");
  }

  // シフトページのルーティング
  if (page === 'shift_page') {
    if (!isAuthenticated()) {
      return HtmlService.createTemplateFromFile("view_login")
        .evaluate().setTitle("ログイン - 勤怠管理システム");
    }
    return HtmlService.createTemplateFromFile("view_shift_page")
      .evaluate().setTitle("シフトページ - 勤怠管理システム");
  }

  // 認証が必要なページかどうかをチェック
  var requiresAuth = ['approval', 'request_form', 'add_form', 'password_change'];
  var isAuthRequired = requiresAuth.includes(page) || (!page && !e.parameter.empId);
  
  // 認証が必要なページで未認証の場合はログイン画面にリダイレクト
  if (isAuthRequired && !isAuthenticated()) {
    return HtmlService.createTemplateFromFile("view_login")
      .evaluate().setTitle("ログイン - 勤怠管理システム");
  }

  if (page === 'approval') {
    var template = HtmlService.createTemplateFromFile("view_shift_approval");
    return template.evaluate().setTitle("リクエスト一覧");
  } else if (page === 'request_form') {
    var template = HtmlService.createTemplateFromFile("view_shift_request_form");
    template.applicantId = e.parameter.applicantId;
    template.date = e.parameter.date;
    template.start = e.parameter.start;
    template.end = e.parameter.end;
    return template.evaluate().setTitle("シフト交代リクエスト");
  } else if (page === 'add_form') {
    // シフト追加依頼画面はオーナーのみアクセス可能
    if (!isCurrentUserOwner()) {
      return HtmlService.createTemplateFromFile("view_login")
        .evaluate().setTitle("ログイン - 勤怠管理システム");
    }
    return HtmlService.createTemplateFromFile("view_shift_add_form")
      .evaluate().setTitle("シフト追加リクエスト");
  } else if (page === 'password_change') {
    return HtmlService.createTemplateFromFile("view_password_change")
      .evaluate().setTitle("パスワード変更");
  } else {
    var selectedEmpId = e.parameter.empId;
    console.log('doGet - empIdパラメータ:', selectedEmpId);
    console.log('doGet - 全パラメータ:', e.parameter);
    
    if (selectedEmpId) { 
      console.log('従業員ID指定でマイページトップにリダイレクト - 従業員ID:', selectedEmpId);
      PropertiesService.getUserProperties().setProperty('selectedEmpId', selectedEmpId.toString());
      return HtmlService.createTemplateFromFile("view_my_page")
          .evaluate().setTitle("マイページ - 勤怠管理システム");
    } else { 
      console.log('ログイン画面を表示');
      return HtmlService.createTemplateFromFile("view_login")
          .evaluate().setTitle("ログイン - 勤怠管理システム");
    }
  }
}

/**
 * このアプリのURLを返す
 */
function getAppUrl() {
  return ScriptApp.getService().getUrl();
}

/**
 * freee public apiから事業所情報を取得して事業所名を返却する
 * https://developer.freee.co.jp/docs/accounting/reference#/Companies/get_company
 */
function getCompanyName() {
  var requestUrl = 'https://api.freee.co.jp//api/1/companies/' + companyId.toString()
  var response = UrlFetchApp.fetch(requestUrl, getRequestOptions())
  var responseJson = JSON.parse(response.getContentText())
  if (response.getResponseCode() != 200) {
    console.error(responseJson.message)
    return responseJson.message
  }
  var companyName = responseJson.company.display_name
  return companyName
}

/**
 * 従業員一覧
 * https://developer.freee.co.jp/docs/hr/reference#/%E5%BE%93%E6%A5%AD%E5%93%A1/get_company_employees
 */
function getEmployees() {
  var requestUrl = 'https://api.freee.co.jp/hr/api/v1/companies/'
    + companyId.toString() 
    + '/employees?limit=50&with_no_payroll_calculation=true'
  var response = UrlFetchApp.fetch(requestUrl, getRequestOptions())
  
  var employees = extractApiData(response, 'employees', '従業員データ');
  if (!employees) {
    return [];
  }

  // IDでソートする処理
  employees.sort(function(a, b) {
    return a.id - b.id;
  });

  return employees;
}

/**
 * 従業員情報の取得
 * ※ デバッグするときにはselectedEmpIdを存在するIDで書き換えてください
 */
function getEmployee() {
  var selectedEmpId = PropertiesService.getUserProperties().getProperty('selectedEmpId')
  
  if (!selectedEmpId) {
    console.error('従業員IDが設定されていません');
    return null;
  }
  
  var requestUrl = 'https://api.freee.co.jp/hr/api/v1/employees/'
    + selectedEmpId.toString()
    + '?company_id=' + companyId.toString()
    + '&year=2022&month=9'  // ※ 年月を指定しているので注意
  var response = UrlFetchApp.fetch(requestUrl, getRequestOptions())
  
  var employees = extractApiData(response, 'employee', '従業員データ');
  if (!employees) {
    console.error('従業員データの取得に失敗しました');
    return null;
  }
  
  // レスポンスが配列の場合は最初の要素、オブジェクトの場合はemployeeプロパティを取得
  var employee = Array.isArray(employees) ? employees[0] : employees;
  
  // 従業員データの構造を確認
  console.log('取得した従業員データ:', employee);
  
  return employee;
}

/**
 * 勤怠情報の取得
 * 今月における今日までの勤怠情報が取得される
 */
function getTimeClocks() {
  var selectedEmpId = PropertiesService.getUserProperties().getProperty('selectedEmpId')
  var requestUrl = 'https://api.freee.co.jp/hr/api/v1/employees/'
    + selectedEmpId.toString()
    + '/time_clocks?company_id=' + companyId.toString()
  var response = UrlFetchApp.fetch(requestUrl, getRequestOptions())
  
  var timeClocks = extractApiData(response, 'time_clocks', '勤怠データ');
  if (!timeClocks) {
    return [];
  }

  // 画面表示用にデータを加工する
  var formatedRecords = []
  for (var i = 0; i <= timeClocks.length - 1; i++) {
    // [i]番目の勤怠情報
    var timeClock = timeClocks[i]
    // 打刻種別を取り出す
    var type = timeClock['type']
    // 打刻時刻を取り出す
    var datetime = timeClock['datetime']
    // 打刻時刻をDateオブジェクトに変換
    var dateObj = new Date(datetime)
    // 見やすい日時にフォーマット
    var dateStr = formatDateTimeJapanese(dateObj)

    // 打刻種別をわかりやすい単語に変換
    var typeName = ''
    switch (type) {
      case 'clock_in':
        typeName = '出勤'
        break
      case 'break_begin':
        typeName = '休憩開始'
        break
      case 'break_end':
        typeName = '休憩終了'
        break
      case 'clock_out':
        typeName = '退勤'
        break;
    }
    // formatedRecordsの配列に追加する
    formatedRecords.push({
      'date': dateStr,
      'type': typeName
    })
  }
  return formatedRecords
}

/**
 * 過去半年分の勤怠履歴を一括取得する
 * @param {string|number} employeeId - 従業員ID
 * @returns {string} 月別に整理された勤怠履歴のJSON文字列
 */
function getTimeClocksHistory(employeeId) {
  try {
    console.log('getTimeClocksHistory開始 - 従業員ID:', employeeId);
    
    var now = new Date();
    var sixMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 6, 1);
    
    // 6ヶ月前の日付を文字列にフォーマット
    var fromDate = sixMonthsAgo.getFullYear() + '-' 
      + String(sixMonthsAgo.getMonth() + 1).padStart(2, '0') + '-' 
      + String(sixMonthsAgo.getDate()).padStart(2, '0');
    
    // 現在の日付を文字列にフォーマット
    var toDate = now.getFullYear() + '-' 
      + String(now.getMonth() + 1).padStart(2, '0') + '-' 
      + String(now.getDate()).padStart(2, '0');
    
    console.log('取得期間:', fromDate, '〜', toDate);
    
    var requestUrl = 'https://api.freee.co.jp/hr/api/v1/employees/'
      + employeeId.toString()
      + '/time_clocks?company_id=' + companyId.toString()
      + '&from_date=' + fromDate
      + '&to_date=' + toDate;
    
    console.log('APIリクエストURL:', requestUrl);
    
    var response = UrlFetchApp.fetch(requestUrl, getRequestOptions());
    console.log('APIレスポンスコード:', response.getResponseCode());
    console.log('APIレスポンス内容:', response.getContentText());
    
    var timeClocks = extractApiData(response, 'time_clocks', '勤怠履歴データ');
    console.log('抽出された勤怠データ:', timeClocks);
    
    if (!timeClocks) {
      console.log('勤怠データが取得できませんでした');
      return JSON.stringify({});
    }
    
    // 月別に勤怠履歴を整理
    var monthlyHistory = {};
    
    for (var i = 0; i < timeClocks.length; i++) {
      var timeClock = timeClocks[i];
      var datetime = timeClock['datetime'];
      var dateObj = new Date(datetime);
      
      // 年月のキーを作成（例: "2025-01"）
      var yearMonth = dateObj.getFullYear() + '-' + String(dateObj.getMonth() + 1).padStart(2, '0');
      
      if (!monthlyHistory[yearMonth]) {
        monthlyHistory[yearMonth] = [];
      }
      
      // 打刻種別をわかりやすい単語に変換
      var typeName = '';
      switch (timeClock['type']) {
        case 'clock_in':
          typeName = '出勤';
          break;
        case 'break_begin':
          typeName = '休憩開始';
          break;
        case 'break_end':
          typeName = '休憩終了';
          break;
        case 'clock_out':
          typeName = '退勤';
          break;
      }
      
      monthlyHistory[yearMonth].push({
        'date': formatDateTimeJapanese(dateObj),
        'type': typeName,
        'datetime': datetime,
        'rawType': timeClock['type']
      });
    }
    
    // 各月のデータを日付順でソート
    for (var month in monthlyHistory) {
      monthlyHistory[month].sort(function(a, b) {
        return new Date(a.datetime) - new Date(b.datetime);
      });
    }
    
    return JSON.stringify(monthlyHistory);
    
  } catch (error) {
    console.error('勤怠履歴取得中にエラーが発生しました:', error.message);
    return JSON.stringify({});
  }
}

/**
 * 指定された月の勤怠履歴を取得する
 * @param {string|number} employeeId - 従業員ID
 * @param {string} yearMonth - 年月（例: "2025-01"）
 * @returns {string} 指定月の勤怠履歴のJSON文字列
 */
function getTimeClocksForMonth(employeeId, yearMonth) {
  try {
    console.log('getTimeClocksForMonth開始 - 従業員ID:', employeeId, '年月:', yearMonth);
    
    var historyJson = getTimeClocksHistory(employeeId);
    console.log('勤怠履歴JSON取得結果:', historyJson);
    
    var monthlyHistory = JSON.parse(historyJson);
    console.log('パース後の月別履歴:', monthlyHistory);
    
    if (monthlyHistory[yearMonth]) {
      console.log('指定月のデータが見つかりました:', monthlyHistory[yearMonth]);
      return JSON.stringify(monthlyHistory[yearMonth]);
    } else {
      console.log('指定月のデータが見つかりませんでした:', yearMonth);
      return JSON.stringify([]);
    }
  } catch (error) {
    console.error('月別勤怠履歴取得中にエラーが発生しました:', error.message);
    return JSON.stringify([]);
  }
}

/**
 * 利用可能な月の一覧を取得する
 * @param {string|number} employeeId - 従業員ID
 * @returns {string} 利用可能な月の一覧のJSON文字列
 */
function getAvailableMonths(employeeId) {
  try {
    var historyJson = getTimeClocksHistory(employeeId);
    var monthlyHistory = JSON.parse(historyJson);
    
    var availableMonths = [];
    for (var yearMonth in monthlyHistory) {
      if (monthlyHistory[yearMonth].length > 0) {
        availableMonths.push({
          yearMonth: yearMonth,
          displayName: formatYearMonth(yearMonth),
          recordCount: monthlyHistory[yearMonth].length
        });
      }
    }
    
    // 年月順でソート（新しい順）
    availableMonths.sort(function(a, b) {
      return b.yearMonth.localeCompare(a.yearMonth);
    });
    
    return JSON.stringify(availableMonths);
  } catch (error) {
    console.error('利用可能月一覧取得中にエラーが発生しました:', error.message);
    return JSON.stringify([]);
  }
}

/**
 * 年月文字列を表示用にフォーマットする
 * @param {string} yearMonth - 年月（例: "2025-01"）
 * @returns {string} フォーマットされた年月（例: "2025年1月"）
 */
function formatYearMonth(yearMonth) {
  var parts = yearMonth.split('-');
  if (parts.length === 2) {
    var year = parts[0];
    var month = parseInt(parts[1], 10);
    return year + '年' + month + '月';
  }
  return yearMonth;
}

/**
 * 勤怠情報登録
 */
function postWorkRecord(form) {
  // ※デバッグするには以下の変数を直接書き換える必要があります
  var selectedEmpId = PropertiesService.getUserProperties().getProperty('selectedEmpId')
  // inputタグのnameで取得
  var targetDate = form.target_date
  var targetTime = form.target_time
  var targetType = form.target_type

  var requestPayload = {
      'company_id': companyId,
      'type': targetType,
      'date': 'string',
      'datetime': targetDate + ' ' + targetTime
  }
  var requestUrl = 'https://api.freee.co.jp/hr/api/v1/employees/'
    + selectedEmpId.toString()
    + '/time_clocks'
  var requestOptions = getRequestOptions('post', JSON.stringify(requestPayload))
  var response = UrlFetchApp.fetch(requestUrl, requestOptions)
  var responseJson = JSON.parse(response.getContentText())
  var responseCode = response.getResponseCode()
  if (responseCode != 201) {
    console.error(responseJson)
    return responseJson.message
  }
  return '登録しました'
}


/**
 * 「シフト表」シートから当月のシフト情報をすべて取得し、整形して返す。
 * @returns {object} 整形されたシフト情報オブジェクト。
 * 例: { year: 2025, month: 8, shifts: { '101': { name: 'テスト太郎', shifts: {'1': '18-20', ...}}, ... } }
 */
/**
 * 【JSON文字列化対応版】「シフト表」シートから当月のシフト情報をすべて取得し、整形して返す。
 */
function getShifts() {
  try {
    var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHIFT_SHEET_NAME);
    if (!sheet || sheet.getLastRow() < 3) {
      var now = new Date();
      var emptyResult = { year: now.getFullYear(), month: now.getMonth() + 1, shifts: {} };
      return JSON.stringify(emptyResult); // 空のデータもJSON文字列で返す
    }

    var dateCellValue = sheet.getRange("A1").getValue();
    if (!(dateCellValue instanceof Date)) {
      console.error("A1セルの値が日付形式ではありません。");
      return null;
    }
    
    var year = dateCellValue.getFullYear();
    var month = dateCellValue.getMonth() + 1;
    
    var allData = sheet.getRange(1, 1, sheet.getLastRow(), sheet.getLastColumn()).getValues();
    var dateHeader = allData[1];
    var employeeDataRows = allData.slice(2);

    var shifts = {};
    employeeDataRows.forEach(function(row) {
      var employeeId = row[0];
      var employeeName = row[1];
      if (!employeeId || !employeeName) return;

      shifts[String(employeeId)] = {
        name: employeeName,
        shifts: {}
      };
      
      for (var i = 2; i < dateHeader.length; i++) {
        var date = dateHeader[i];
        var shiftTime = row[i];
        if (date && shiftTime) {
          shifts[String(employeeId)].shifts[String(date)] = shiftTime;
        }
      }
    });

    var result = {
      year: year,
      month: month,
      shifts: shifts
    };

    // オブジェクトをJSON文字列に変換してから返す
    return JSON.stringify(result);

  } catch (e) {
    console.error("getShifts関数で予期せぬエラーが発生しました: " + e.message + " スタック: " + e.stack);
    return null;
  }
}


/**
 * 「シフト表」シートで、指定された従業員IDが記載されている行番号を返す。
 * @param {string | number} employeeId - 検索する従業員のID。
 * @returns {number|null} 見つかった場合は行番号（1から始まる）、見つからない場合はnull。
 */
function findRowByEmployeeId(employeeId) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHIFT_SHEET_NAME);
  var lastRow = sheet.getLastRow();
  // 【変更点】A列（従業員IDカラム）のデータをすべて取得
  var ids = sheet.getRange("A3:A" + lastRow).getValues();

  for (var i = 0; i < ids.length; i++) {
    if (String(ids[i][0]) === String(employeeId)) {
      return i + 3; 
    }
  }
  return null;
}

/**
 * 全従業員リストの中から、指定したIDの従業員オブジェクトを探して返す。
 * @param {string | number} employeeId - 検索する従業員のID。
 * @param {object[]} employees - 全従業員の情報が含まれる配列。
 * @returns {object | null} 見つかった従業員オブジェクト。見つからない場合はnull。
 */
function findEmployeeById(employeeId, employees) {
  if (!employees) return null;
  return employees.find(function(emp) {
    return String(emp.id) === String(employeeId);
  });
}

/**
 * 「シフト表」シートで、指定された日付が記載されている列番号を返す。
 * @param {number | string} date - 検索する日付（例: 5）。
 * @returns {number|null} 見つかった場合は列番号（1から始まる）、見つからない場合はnull。
 */
function findDateColumn(date) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHIFT_SHEET_NAME);
  var lastCol = sheet.getLastColumn();
  // 【変更点】C2セルから日付が始まると想定
  var dates = sheet.getRange(2, 3, 1, lastCol - 2).getValues()[0];

  for (var i = 0; i < dates.length; i++) {
    if (String(dates[i]) === String(date)) {
      // C列がインデックス0なので、+3する
      return i + 3;
    }
  }
  return null; // 見つからなかった場合
}


/**
 * 指定した従業員・日付のシフト情報を更新する。
 * @param {string | number} employeeId - 対象の従業員ID。
 * @param {number | string} date - 対象の日付。
 * @param {string} timeString - セットするシフト時間（例: "18-20"）。
 */
function updateShift(employeeId, date, timeString) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHIFT_SHEET_NAME);
  // 【変更点】findRowByEmployeeId を使用
  var targetRow = findRowByEmployeeId(employeeId); 
  var targetCol = findDateColumn(date);

  if (targetRow && targetCol) {
    sheet.getRange(targetRow, targetCol).setValue(timeString);
    console.log("ID:" + employeeId + "の従業員の" + date + "日のシフトを「" + timeString + "」に更新しました。");
  } else {
    console.error("更新対象のセルが見つかりませんでした。従業員ID: " + employeeId + ", 日付: " + date);
  }
}

/**
 * 指定した従業員・日付のシフト情報を削除（クリア）する。
 * @param {string | number} employeeId - 対象の従業員ID。
 * @param {number | string} date - 対象の日付。
 */
function deleteShift(employeeId, date) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHIFT_SHEET_NAME);
  // 【変更点】findRowByEmployeeId を使用
  var targetRow = findRowByEmployeeId(employeeId);
  var targetCol = findDateColumn(date);

  if (targetRow && targetCol) {
    sheet.getRange(targetRow, targetCol).clearContent();
    console.log("ID:" + employeeId + "の従業員の" + date + "日のシフトを削除しました。");
  } else {
    console.error("削除対象のセルが見つかりませんでした。従業員ID: " + employeeId + ", 日付: " + date);
  }
}


/**
 * 【メール機能Revert版】新しいシフト交代リクエストを作成する。
 * 交代依頼相手のスケジュールをチェックし、重複している人を除外する。
 * @param {string} applicantId - 申請者の従業員ID。
 * @param {string} targetStartStr - 交代対象シフトの開始日時 (文字列)。
 * @param {string} targetEndStr - 交代対象シフトの終了日時 (文字列)。
 * @param {string[]} approverIds - 交代を依頼する相手（承認者候補）の従業員IDの配列。
 * @returns {string | null} 生成された申請ID。失敗した場合はnull。
 */
function createShiftChangeRequest(applicantId, targetStartStr, targetEndStr, approverIds) {
  var targetStart = new Date(targetStartStr);
  var targetEnd = new Date(targetEndStr);

  var allShiftsJson = getShifts();
  if (!allShiftsJson) {
    throw new Error("シフト表のデータを取得できませんでした。");
  }
  var allShifts = JSON.parse(allShiftsJson);
  
  // ★★★ メール送信のために、全従業員リストを取得 ★★★
  var allEmployees = getEmployees();
  if (!allEmployees) {
    throw new Error("従業員情報を取得できませんでした。");
  }
  
  var requestDay = targetStart.getDate();
  var requestStartHour = targetStart.getHours();
  var requestEndHour = targetEnd.getHours();

  var validApproverIds = approverIds.filter(function(approverId) {
    if (!allShifts.shifts.hasOwnProperty(approverId)) {
      return true;
    }
    var employeeShiftInfo = allShifts.shifts[approverId];
    if (!employeeShiftInfo.shifts || !employeeShiftInfo.shifts[requestDay]) {
      return true;
    }
    var existingShift = employeeShiftInfo.shifts[requestDay];
    var parsedExistingShift = parseShiftTime(existingShift);
    if (!parsedExistingShift) {
      return true;
    }
    var isOverlapping = isShiftOverlapping(parsedExistingShift, requestStartHour, requestEndHour);
    return !isOverlapping;
  });

  if (validApproverIds.length === 0) {
    throw new Error("選択した相手は全員、その時間に既にシフトが入っています。");
  }

  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHIFT_MANAGEMENT_SHEET_NAME);
  if (!sheet) { return null; }

  var requestId = Utilities.getUuid();
  validApproverIds.forEach(function(approverId) {
    var newRowData = [ requestId, applicantId, approverId, targetStart, targetEnd, '申請中' ];
    sheet.appendRow(newRowData);
  });
  
  // --- ▼▼▼ ここからメール送信処理 ▼▼▼ ---
  var applicantInfo = findEmployeeById(applicantId, allEmployees);
  var applicantName = applicantInfo ? applicantInfo.display_name : 'ID: ' + applicantId;

  var timeString = Utilities.formatDate(targetStart, "JST", "M月d日 H:mm") + "～" + Utilities.formatDate(targetEnd, "JST", "H:mm");
  
  validApproverIds.forEach(function(approverId) {
    var approverInfo = findEmployeeById(approverId, allEmployees);
    // ★★★ approverInfo.email を直接参照するように修正 ★★★
    if (approverInfo && approverInfo.email) {
      var recipientEmail = approverInfo.email;
      var subject = "【シフト交代のお願い】" + applicantName + "さんより";
      var body = approverInfo.display_name + "様\n\n" +
                 applicantName + "さんから、シフト交代のリクエストが届いています。\n\n" +
                 "■対象日時\n" + timeString + "\n\n" +
                 "以下のリンクから、リクエスト一覧を確認・承認できます。\n" +
                 getAppUrl() + "?page=approval";
      
      MailApp.sendEmail(recipientEmail, subject, body);
    }
  });
  // --- ▲▲▲ メール送信処理ここまで ▲▲▲ ---

  console.log("申請者ID: " + applicantId + " がシフト交代リクエストを作成し、" + validApproverIds.length + "件の通知を送信しました。");
  return requestId;
}

/**
 * 【新規】シフト追加リクエストを承認する。
 * @param {string} requestId - 承認するリクエストの申請ID。
 * @param {string} approverId - 承認した従業員のID。
 */
function approveShiftAddition(requestId, approverId) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("シフト追加");
  if (!sheet) return;

  var allData = sheet.getDataRange().getValues();
  var targetRequestInfo = {};

  for (var i = 1; i < allData.length; i++) {
    if (allData[i][0] === requestId) {
      targetRequestInfo = {
        rowNum: i + 1,
        start: new Date(allData[i][2]),
        end: new Date(allData[i][3])
      };
      break;
    }
  }

  if (targetRequestInfo.rowNum) {
    var date = targetRequestInfo.start.getDate();
    var timeString = Utilities.formatDate(targetRequestInfo.start, "JST", "H") + "-" + Utilities.formatDate(targetRequestInfo.end, "JST", "H");
    updateShift(approverId, date, timeString);
    sheet.getRange(targetRequestInfo.rowNum, 5).setValue('承認済み');
    
    var allEmployees = getEmployees();
    var approverInfo = findEmployeeById(approverId, allEmployees);
    
    // "店長 太郎" という名前でオーナーの情報を探す
    var ownerInfo = allEmployees.find(function(emp) {
      return emp.display_name === '店長 太郎';
    });

    if (approverInfo && ownerInfo && ownerInfo.email) {
      var timeStringFormatted = Utilities.formatDate(targetRequestInfo.start, "JST", "M月d日 H:mm") + "～" + Utilities.formatDate(targetRequestInfo.end, "JST", "H:mm");
      var subject = "【承認】" + approverInfo.display_name + "さんがシフト追加を承認しました";
      var body = "オーナー様\n\n" +
                 "あなたが" + approverInfo.display_name + "さんに依頼したシフト追加が承認されました。\n\n" +
                 "■対象日時\n" + timeStringFormatted + "\n\n" +
                 "シフト表が更新されました。";
      MailApp.sendEmail(ownerInfo.email, subject, body);
    }
    
    console.log("シフト追加リクエスト " + requestId + " が承認されました。");
  }
}


/**
 * 【新規】シフト追加リクエストを否認する。
 * @param {string} requestId - 否認するリクエストの申請ID。
 * @param {string} denierId - 否認した従業員のID。
 */
function denyShiftAddition(requestId, denierId) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("シフト追加");
  if (!sheet) return;

  var allData = sheet.getDataRange().getValues();
  for (var i = 1; i < allData.length; i++) {
    if (allData[i][0] === requestId && String(allData[i][1]) === String(denierId)) {
      sheet.getRange(i + 1, 5).setValue('否認済み');

      var allEmployees = getEmployees();
      var denierInfo = findEmployeeById(denierId, allEmployees);
      
      // "店長 太郎" という名前でオーナーの情報を探す
      var ownerInfo = allEmployees.find(function(emp) {
        return emp.display_name === '店長 太郎';
      });

      if (denierInfo && ownerInfo && ownerInfo.email) {
        var subject = "【否認】" + denierInfo.display_name + "さんがシフト追加を否認しました";
        var body = "オーナー様\n\n" +
                   "あなたが" + denierInfo.display_name + "さんに依頼したシフト追加は、否認されました。";
        MailApp.sendEmail(ownerInfo.email, subject, body);
      }

      console.log("シフト追加リクエスト " + requestId + " が否認されました。");
      return;
    }
  }
}


/**
 * 【新規】指定した従業員宛の「シフト交代」と「シフト追加」の両方の申請中リクエストを取得する。
 * @param {string} employeeId - ログインしている従業員のID。
 * @returns {string} 結合されたリクエスト情報のJSON文字列。
 */
function getPendingRequestsForUser(employeeId) {
  // 1. シフト交代リクエストを取得
  var changeRequests = getPendingChangeRequestsFor(employeeId);
  
  // 2. シフト追加リクエストを取得
  var additionRequests = getPendingAdditionRequestsFor(employeeId);

  // 3. 両方のリクエストを結合し、JSON文字列として返す
  var allRequests = changeRequests.concat(additionRequests);
  return JSON.stringify(allRequests);
}

// --- 既存の getPendingRequestsFor を、以下の2つの関数に分割・改名 ---

/**
 * 【改名】指定した従業員宛の「申請中」の【シフト交代】リクエストを取得する。
 */
function getPendingChangeRequestsFor(employeeId) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHIFT_MANAGEMENT_SHEET_NAME);
  if (!sheet) { return []; }

  var allData = sheet.getDataRange().getValues();
  var requestRows = allData.slice(1); 
  var pendingRequests = [];

  requestRows.forEach(function(row) {
    if (String(row[2]).trim() === String(employeeId).trim() && String(row[5]).trim() === '申請中') {
      pendingRequests.push({
        type: 'change',
        requestId:   row[0],
        applicantId: row[1],
        start:       row[3].toISOString(),
        end:         row[4].toISOString()
      });
    }
  });
  return pendingRequests;
}

/**
 * 【新規】指定した従業員宛の「申請中」の【シフト追加】リクエストを取得する。
 */
function getPendingAdditionRequestsFor(employeeId) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("シフト追加");
  if (!sheet) { return []; }

  var allData = sheet.getDataRange().getValues();
  var requestRows = allData.slice(1);
  var pendingRequests = [];

  requestRows.forEach(function(row) {
    if (String(row[1]).trim() === String(employeeId).trim() && String(row[4]).trim() === '申請中') {
      pendingRequests.push({
        type: 'addition', // ★リクエスト種別を追加
        requestId:   row[0],
        applicantId: 'オーナー', // 申請者はオーナー
        start:       row[2].toISOString(),
        end:         row[3].toISOString()
      });
    }
  });
  return pendingRequests;
}


/**
 * シフト交代リクエストを承認する。
 * 1. シフト表を更新（申請者のシフトを削除し、承認者のシフトを追加）
 * 2. 交代管理シートのステータスを更新（承認者は「承認」、他は「締切」）
 * @param {string} requestId - 承認するリクエストの申請ID。
 * @param {string} approverId - 承認した従業員のID。
 */
function approveShiftChange(requestId, approverId) {
  var mgmtSheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHIFT_MANAGEMENT_SHEET_NAME);
  if (!mgmtSheet) return;

  var allData = mgmtSheet.getDataRange().getValues();
  var requestsToUpdate = [];
  var targetRequestInfo = {};

  // 1. まず、今回のrequestIdに該当するすべての行を探し、情報を集める
  for (var i = 1; i < allData.length; i++) { // 1行目はヘッダーなのでi=1から
    var currentRow = allData[i];
    if (currentRow[0] === requestId) { // 申請IDが一致
      requestsToUpdate.push({
        rowNum: i + 1, // 行番号
        approverId: currentRow[2] // その行の承認者ID
      });
      // 申請者やシフト日時の情報はどの行も同じなので、最初に見つけた行から取得しておく
      if (!targetRequestInfo.applicantId) {
        targetRequestInfo = {
          applicantId: currentRow[1],
          start: new Date(currentRow[3]),
          end: new Date(currentRow[4])
        };
      }
    }
  }

  // 2. シフト表を実際に更新する
  if (targetRequestInfo.applicantId) {
    var date = targetRequestInfo.start.getDate(); // 日付（例: 20）
    // 時間のフォーマット (例: "18-22")
    var timeString = Utilities.formatDate(targetRequestInfo.start, "JST", "H") + "-" + Utilities.formatDate(targetRequestInfo.end, "JST", "H");
    
    // 元の申請者のシフトを削除
    deleteShift(targetRequestInfo.applicantId, date); // ※事前に作成した関数
    // 承認者のシフトを追加
    updateShift(approverId, date, timeString);       // ※事前に作成した関数
  } else {
    console.error("承認エラー: 対象のリクエスト情報が見つかりません。requestId: " + requestId);
    return;
  }

  // 3. 交代管理シートのステータスを一行ずつ更新する
  requestsToUpdate.forEach(function(req) {
    var newStatus = "";
    if (String(req.approverId) === String(approverId)) {
      newStatus = '承認済み'; // 承認した本人の行
    } else {
      newStatus = '締切'; // 募集が終了した他の人の行
    }
    mgmtSheet.getRange(req.rowNum, 6).setValue(newStatus); // F列（ステータス列）を更新
  });

  // 4. メール通知をする
  var allEmployees = getEmployees();
  var applicantInfo = findEmployeeById(targetRequestInfo.applicantId, allEmployees);
  var approverInfo = findEmployeeById(approverId, allEmployees);

  if (applicantInfo && applicantInfo.email && approverInfo) {
    var recipientEmail = applicantInfo.email;
    var approverName = approverInfo.display_name;
    var timeStringFormatted = Utilities.formatDate(targetRequestInfo.start, "JST", "M月d日 H:mm") + "～" + Utilities.formatDate(targetRequestInfo.end, "JST", "H:mm");

    var subject = "【承認】シフト交代リクエストが承認されました";
    var body = applicantInfo.display_name + "様\n\n" +
               "あなたのシフト交代リクエストが、" + approverName + "さんによって承認されました。\n\n" +
               "■対象日時\n" + timeStringFormatted + "\n\n" +
               "シフト表が更新されましたので、ご確認ください。";
    
    MailApp.sendEmail(recipientEmail, subject, body);
  }
  
  console.log("リクエスト " + requestId + " は " + approverId + " さんによって承認されました。");
}

/**
 * シフト交代リクエストを否認する。
 * @param {string} requestId - 否認するリクエストの申請ID。
 * @param {string} denierId - 否認した従業員のID。
 * ★ 全員に否認された場合にのみ、申請者に通知メールを送信する。
 */
function denyShiftChange(requestId, denierId) {
  var mgmtSheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHIFT_MANAGEMENT_SHEET_NAME);
  if (!mgmtSheet) return;

  var allData = mgmtSheet.getDataRange().getValues();
  var applicantId = null; // 申請者のIDを格納する変数
  var allRequestsForTheSameId = []; // 同じ申請IDを持つすべてのリクエスト行を格納する配列

  // 1. 該当するリクエストのステータスを「否認済み」に更新しつつ、関連リクエストをすべて集める
  for (var i = 1; i < allData.length; i++) {
    var rowRequestId = allData[i][0];
    if (rowRequestId === requestId) {
      // 関連リクエストとして、行の情報を保存（行番号、ステータス）
      allRequestsForTheSameId.push({
        rowNum: i + 1,
        status: allData[i][5] // F列: ステータス
      });
      
      // 申請者IDを取得（どの行でも同じはず）
      if (!applicantId) {
        applicantId = allData[i][1];
      }

      // 今回否認した本人の行のステータスを更新
      var rowApproverId = allData[i][2];
      if (String(rowApproverId) === String(denierId)) {
        mgmtSheet.getRange(i + 1, 6).setValue('否認済み');
        // 更新後のステータスを配列にも反映
        allRequestsForTheSameId[allRequestsForTheSameId.length - 1].status = '否認済み';
      }
    }
  }

  // 2. 関連リクエストがすべて「否認済み」かチェック
  var allDenied = allRequestsForTheSameId.every(function(req) {
    return req.status === '否認済み';
  });

  // 3. 全員に否認されていた場合のみ、メールを送信する
  if (allDenied && applicantId) {
    var allEmployees = getEmployees();
    var applicantInfo = findEmployeeById(applicantId, allEmployees);

    if (applicantInfo && applicantInfo.email) {
      var recipientEmail = applicantInfo.email;
      var subject = "【シフト交代失敗】シフト交代リクエストが成立しませんでした";
      var body = applicantInfo.display_name + "様\n\n" +
                 "残念ながら、あなたが申請したシフト交代リクエストは、依頼した全員が対応できなかったため、成立しませんでした。\n" +
                 "お手数ですが、再度リクエストを出すか、シフトの調整をお願いします。";
      
      MailApp.sendEmail(recipientEmail, subject, body);
      console.log("リクエスト " + requestId + " が全員に否認されたため、申請者に通知しました。");
    }
  }
  
  console.log("リクエスト " + requestId + " は " + denierId + " さんによって否認されました。");
}

/**
 * 全従業員の打刻忘れをチェックし、該当者に通知メールを送信する。
 * この関数をトリガーで定期的に実行する。
 */
function checkForgottenClockIns() {
  console.log("打刻忘れチェック処理を開始します。");
  
  // --- 1. 必要な情報を取得 ---
  var now = new Date();
  var allShiftsJson = getShifts();
  if (!allShiftsJson) {
    console.error("シフト情報が取得できなかったため、打刻忘れチェックを中止します。");
    return;
  }
  var allShifts = JSON.parse(allShiftsJson);
  var allEmployees = getEmployees();
  if (!allEmployees) {
    console.error("従業員情報が取得できなかったため、打刻忘れチェックを中止します。");
    return;
  }

  var today = now.getDate(); // 今日の日付 (例: 5)
  var currentHour = now.getHours(); // 現在の時 (例: 18)

  // --- 2. 全従業員をループしてチェック ---
  allEmployees.forEach(function(employee) {
    var employeeId = employee.id;
    var employeeShiftData = allShifts.shifts[employeeId];

    // 今日のシフト情報を取得
    if (!employeeShiftData || !employeeShiftData.shifts || !employeeShiftData.shifts[today]) {
      return; // 今日のシフトがなければ、この従業員はチェック対象外
    }
    
    var shiftTime = employeeShiftData.shifts[today]; // 例: "18-23"
    var parsedShift = parseShiftTime(shiftTime);
    if (!parsedShift) {
      return; // シフト時間の形式が不正な場合はスキップ
    }
    var shiftStartHour = parsedShift.startHour;

    // --- 3. 打刻忘れの条件判定 ---
    // (条件1) シフト開始時刻を過ぎているか？ (例: 現在18時以降で、シフト開始が18時)
    // (条件2) まだ処理が実行されていないか？ (18:05と18:10にチェックしないよう、1時間分の猶予を持たせる)
    if (currentHour >= shiftStartHour && currentHour < shiftStartHour + 1) {
      
      // freee APIから今日の出勤打刻記録を取得
      var timeClocks = getTimeClocksFor(employeeId, now);
      var hasClockInToday = timeClocks.some(function(record) {
        return record.type === 'clock_in';
      });

      // (条件3) 今日の出勤打刻がまだない場合
      if (!hasClockInToday) {
        // --- 4. 通知メールの送信 ---
        if (employee.email) {
          var subject = "【勤怠アラート】出勤打刻がされていません";
          var body = employee.display_name + "様\n\n" +
                     "本日のシフトの出勤打刻がまだ記録されていません。\n" +
                     "打刻忘れの場合は、速やかに打刻をお願いします。\n\n" +
                     "対象シフト: " + shiftTime;
          MailApp.sendEmail(employee.email, subject, body);
          console.log(employee.display_name + "さんに打刻忘れ通知を送信しました。");
        }
      }
    }
  });
  
  console.log("打刻忘れチェック処理を終了します。");
}

/**
 * オーナーからの新しいシフト追加リクエストを作成し、「シフト追加」シートに記録する。
 * @param {string} approverId - シフト追加を依頼された従業員のID。
 * @param {string} targetStartStr - 対象シフトの開始日時 (文字列)。
 * @param {string} targetEndStr - 対象シフトの終了日時 (文字列)。
 * @returns {string | null} 生成された申請ID。失敗した場合はnull。
 */
function createShiftAdditionRequest(approverId, targetStartStr, targetEndStr) {
  var targetStart = new Date(targetStartStr);
  var targetEnd = new Date(targetEndStr);

  // --- 依頼相手のスケジュール重複チェック ---
  var allShiftsJson = getShifts();
  if (!allShiftsJson) {
    throw new Error("シフト表のデータを取得できませんでした。");
  }
  var allShifts = JSON.parse(allShiftsJson);
  
  var requestDay = targetStart.getDate();
  var requestStartHour = targetStart.getHours();
  var requestEndHour = targetEnd.getHours();
  
  if (allShifts.shifts.hasOwnProperty(approverId)) {
    var employeeShiftInfo = allShifts.shifts[approverId];
    if (employeeShiftInfo.shifts && employeeShiftInfo.shifts[requestDay]) {
      var existingShift = employeeShiftInfo.shifts[requestDay];
      var parsedExistingShift = parseShiftTime(existingShift);
      if (parsedExistingShift && isShiftOverlapping(parsedExistingShift, requestStartHour, requestEndHour)) {
        throw new Error(employeeShiftInfo.name + "さんは、その時間に既に別のシフトが入っています。");
      }
    }
  }

  // --- スプレッドシートへの記録 ---
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("シフト追加"); // 新しいシート名
  if (!sheet) { 
    throw new Error("「シフト追加」シートが見つかりません。");
  }

  var requestId = Utilities.getUuid();
  var newRowData = [ 
    requestId, 
    approverId, 
    targetStart, 
    targetEnd, 
    '申請中' 
  ];
  sheet.appendRow(newRowData);
  
  // --- 従業員への通知メール送信 ---
  var allEmployees = getEmployees();
  var approverInfo = findEmployeeById(approverId, allEmployees);
  if (approverInfo && approverInfo.email) {
    var timeString = Utilities.formatDate(targetStart, "JST", "M月d日 H:mm") + "～" + Utilities.formatDate(targetEnd, "JST", "H:mm");
    var subject = "【シフト追加のお願い】";
    var body = approverInfo.display_name + "様\n\n" +
               "オーナーより、新しいシフトの追加依頼が届いています。\n\n" +
               "■対象日時\n" + timeString + "\n\n" +
               "以下のリンクから、リクエスト一覧を確認・承認できます。\n" +
               getAppUrl() + "?page=approval"; // 既存の承認画面を流用
    MailApp.sendEmail(approverInfo.email, subject, body);
  }
  
  console.log(approverInfo.display_name + "さんへシフト追加リクエストを作成しました。");
  return requestId;
}





/**
 * 特定の従業員の、指定された日付の勤怠記録を取得するヘルパー関数
 * @param {string | number} employeeId - 対象の従業員ID
 * @param {Date} dateObj - 対象の日付
 * @returns {object[]} 勤怠記録の配列
 */
function getTimeClocksFor(employeeId, dateObj) {
  var y = dateObj.getFullYear();
  var m = dateObj.getMonth() + 1;
  var d = dateObj.getDate();
  // 月と日を2桁にフォーマット（例: 8 → "08", 5 → "05"）
  var mStr = m < 10 ? '0' + m : String(m);
  var dStr = d < 10 ? '0' + d : String(d);
  var dateStr = y + '-' + mStr + '-' + dStr;

  var requestUrl = 'https://api.freee.co.jp/hr/api/v1/employees/' +
                   String(employeeId) +
                   '/time_clocks?company_id=' + companyId +
                   '&from_date=' + dateStr + '&to_date=' + dateStr;
                   
  var response = UrlFetchApp.fetch(requestUrl, getRequestOptions());
  
  var timeClocks = extractApiData(response, null, "勤怠情報");
  if (!timeClocks) {
    return [];
  }
  return timeClocks;
}

/**
 * 時間帯別時給の設定
 * 各時間帯の開始時刻、終了時刻、時給レートを定義
 */
var TIME_ZONE_WAGE_RATES = {
  normal: { start: 9, end: 18, rate: 1000, name: '通常時給' },      // 9:00-18:00
  evening: { start: 18, end: 22, rate: 1200, name: '夜間手当' },    // 18:00-22:00
  night: { start: 22, end: 9, rate: 1500, name: '深夜手当' }        // 22:00-9:00
};

/**
 * 従業員の基本時給を取得する
 * @param {string|number} employeeId - 従業員ID
 * @returns {number} 基本時給（円）
 */
function getHourlyWage(employeeId) {
  try {
    // freee APIから基本時給を取得
    var requestUrl = 'https://api.freee.co.jp/hr/api/v1/employees/' 
      + employeeId.toString() 
      + '/basic_pay_rule?company_id=' + companyId.toString()
      + '&year=' + new Date().getFullYear() 
      + '&month=' + (new Date().getMonth() + 1);
    
    var response = UrlFetchApp.fetch(requestUrl, getRequestOptions());
    var responseJson = JSON.parse(response.getContentText());
    
    if (response.getResponseCode() === 200 && responseJson.employee_basic_pay_rule) {
      var payAmount = responseJson.employee_basic_pay_rule.pay_amount;
      if (payAmount && payAmount > 0) {
        return payAmount;
      }
    }
    
    // API取得に失敗した場合はデフォルト値を返す
    console.error('基本時給の取得に失敗しました。従業員ID:', employeeId, 'レスポンス:', responseJson);
    return 1000; // デフォルト時給1000円
    
  } catch (error) {
    // エラー時はデフォルト値を返す
    console.error('基本時給取得中にエラーが発生しました:', error.message);
    return 1000; // デフォルト時給1000円
  }
}

/**
 * 時間帯別時給レートを取得する
 * @returns {object} 時間帯別時給設定
 */
function getTimeZoneWageRates() {
  return TIME_ZONE_WAGE_RATES;
}

/**
 * 指定された時間がどの時間帯に属するかを判定する
 * @param {number} hour - 時間（0-23）
 * @returns {string} 時間帯のキー（'normal', 'evening', 'night'）
 */
function getTimeZone(hour) {
  if (hour >= 9 && hour < 18) {
    return 'normal';
  } else if (hour >= 18 && hour < 22) {
    return 'evening';
  } else {
    return 'night';
  }
}

/**
 * シフト時間から時間帯別の勤務時間を計算する
 * @param {string} shiftTime - シフト時間文字列（例: "18-22"）
 * @returns {object} 時間帯別勤務時間 {normal: 0, evening: 4, night: 0}
 */
function calculateWorkHoursByTimeZone(shiftTime) {
  var parsedShift = parseShiftTime(shiftTime);
  if (!parsedShift) {
    return { normal: 0, evening: 0, night: 0 };
  }

  var startHour = parsedShift.startHour;
  var endHour = parsedShift.endHour;
  var timeZoneHours = { normal: 0, evening: 0, night: 0 };

  // 開始時刻から終了時刻まで1時間ずつチェック
  for (var hour = startHour; hour < endHour; hour++) {
    var timeZone = getTimeZone(hour);
    timeZoneHours[timeZone]++;
  }

  return timeZoneHours;
}

/**
 * 指定された従業員の月間勤務時間を時間帯別に計算する
 * @param {string|number} employeeId - 従業員ID
 * @param {number} month - 月（1-12）
 * @param {number} year - 年
 * @returns {object} 時間帯別月間勤務時間 {normal: 0, evening: 0, night: 0}
 */
function calculateMonthlyWorkHours(employeeId, month, year) {
  var allShiftsJson = getShifts();
  if (!allShiftsJson) {
    return { normal: 0, evening: 0, night: 0 };
  }

  var allShifts = JSON.parse(allShiftsJson);
  var employeeShifts = allShifts.shifts[employeeId];
  
  if (!employeeShifts || !employeeShifts.shifts) {
    return { normal: 0, evening: 0, night: 0 };
  }

  var monthlyHours = { normal: 0, evening: 0, night: 0 };

  // 指定された年月のシフトを集計
  for (var day in employeeShifts.shifts) {
    var shiftTime = employeeShifts.shifts[day];
    if (shiftTime) {
      var dayHours = calculateWorkHoursByTimeZone(shiftTime);
      monthlyHours.normal += dayHours.normal;
      monthlyHours.evening += dayHours.evening;
      monthlyHours.night += dayHours.night;
    }
  }

  return monthlyHours;
}

/**
 * 従業員の月給を計算する
 * @param {string|number} employeeId - 従業員ID
 * @param {number} month - 月（1-12）
 * @param {number} year - 年
 * @returns {object} 給与情報 {total: 0, breakdown: {}, workHours: {}}
 */
function calculateMonthlyWage(employeeId, month, year) {
  try {
    var baseHourlyWage = getHourlyWage(employeeId);
    var timeZoneRates = getTimeZoneWageRates();
    var monthlyWorkHours = calculateMonthlyWorkHours(employeeId, month, year);

    var breakdown = {};
    var total = 0;

    // 時間帯別給与を計算
    for (var timeZone in monthlyWorkHours) {
      var hours = monthlyWorkHours[timeZone];
      var rate = timeZoneRates[timeZone].rate;
      var wage = hours * rate;
      
      breakdown[timeZone] = {
        hours: hours,
        rate: rate,
        wage: wage,
        name: timeZoneRates[timeZone].name
      };
      
      total += wage;
    }

    var result = {
      total: total,
      breakdown: breakdown,
      workHours: monthlyWorkHours
    };
    
    return result;
    
  } catch (error) {
    // エラー時はデフォルト値を返す
    return {
      total: 0,
      breakdown: {},
      workHours: { normal: 0, evening: 0, night: 0 }
    };
  }
}

/**
 * 全従業員の給与状況を一括取得する
 * @param {number} month - 月（1-12）
 * @param {number} year - 年
 * @returns {string} 全従業員の給与情報のJSON文字列
 */
function getAllEmployeesWages(month, year) {
  var employees = getEmployees();
  if (!employees) {
    return JSON.stringify([]);
  }

  var allWages = [];
  
  employees.forEach(function(employee) {
    var wageInfo = calculateMonthlyWage(employee.id, month, year);
    
    allWages.push({
      employeeId: employee.id,
      employeeName: employee.display_name,
      wage: wageInfo.total,
      breakdown: wageInfo.breakdown,
      workHours: wageInfo.workHours,
      target: 1030000, // 103万円
      percentage: (wageInfo.total / 1030000) * 100
    });
  });

  return JSON.stringify(allWages);
}

/**
 * 指定された従業員の給与状況を取得する
 * @param {string|number} employeeId - 従業員ID
 * @param {number} month - 月（1-12）
 * @param {number} year - 年
 * @returns {string} 従業員の給与情報のJSON文字列
 */
function getEmployeeWageInfo(employeeId, month, year) {
  try {
    // 従業員情報を取得
    var employees = getEmployees();
    if (!employees || employees.length === 0) {
      return JSON.stringify({
        error: '従業員情報が取得できません',
        employeeId: employeeId
      });
    }
    
    var employee = findEmployeeById(employeeId, employees);
    if (!employee) {
      return JSON.stringify({
        error: '指定された従業員IDが見つかりません',
        employeeId: employeeId
      });
    }
    
    // 給与計算を実行
    var wageInfo = calculateMonthlyWage(employeeId, month, year);
    
    var result = {
      employeeId: employeeId,
      employeeName: employee.display_name,
      wage: wageInfo.total,
      breakdown: wageInfo.breakdown,
      workHours: wageInfo.workHours,
      target: 1030000, // 103万円
      percentage: (wageInfo.total / 1030000) * 100,
      isOverLimit: wageInfo.total >= 1030000,
      remaining: Math.max(0, 1030000 - wageInfo.total)
    };
    
    return JSON.stringify(result);
    
  } catch (error) {
    return JSON.stringify({
      error: '給与計算中にエラーが発生しました: ' + error.message,
      employeeId: employeeId
      });
  }
}

/**
 * 現在選択されている従業員IDを取得する
 * @returns {string|null} 選択されている従業員ID、設定されていない場合はnull
 */
function getSelectedEmployeeId() {
  console.log('getSelectedEmployeeId開始');
  var selectedEmpId = PropertiesService.getUserProperties().getProperty('selectedEmpId');
  console.log('PropertiesServiceから取得した従業員ID:', selectedEmpId);
  return selectedEmpId;
}

/**
 * 従業員IDを設定する
 * @param {string} employeeId - 設定する従業員ID
 */
function setSelectedEmployeeId(employeeId) {
  PropertiesService.getUserProperties().setProperty('selectedEmpId', employeeId);
  console.log('従業員IDを設定しました:', employeeId);
}


/**
 * 認証設定シートから従業員の認証情報を取得する
 * @param {string} employeeId - 従業員ID
 * @returns {object|null} 認証情報オブジェクト、見つからない場合はnull
 */
function getAuthInfo(employeeId) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(AUTH_SETTINGS_SHEET_NAME);
  if (!sheet) {
    console.log('認証設定シートが見つかりません');
    return null;
  }
  
  var data = sheet.getDataRange().getValues();
  console.log('getAuthInfo: 検索対象の従業員ID =', employeeId, '(型:', typeof employeeId, ')');
  console.log('getAuthInfo: シートデータ行数 =', data.length);
  
  // ヘッダー行をスキップして検索
  for (var i = 1; i < data.length; i++) {
    var storedEmployeeId = data[i][0];
    console.log('getAuthInfo: 行' + i + 'の従業員ID =', storedEmployeeId, '(型:', typeof storedEmployeeId, ')');
    
    // 型を気にしない比較に変更
    if (storedEmployeeId == employeeId) {
      console.log('getAuthInfo: 従業員ID一致！パスワード =', data[i][1] ? '設定済み' : '未設定');
      return {
        employeeId: data[i][0],
        hashedPassword: data[i][1],
        passwordLastUpdated: data[i][2],
        lastLogin: data[i][3]
      };
    }
  }
  
  console.log('getAuthInfo: 従業員IDが見つかりませんでした');
  return null;
}

/**
 * 認証設定シートに従業員の認証情報を保存・更新する
 * @param {string} employeeId - 従業員ID
 * @param {string} hashedPassword - ハッシュ化されたパスワード
 * @param {boolean} isLogin - ログイン処理かどうか（trueの場合は最終ログイン日時も更新）
 */
function saveAuthInfo(employeeId, hashedPassword, isLogin) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(AUTH_SETTINGS_SHEET_NAME);
  if (!sheet) {
    console.log('認証設定シートが見つかりません。');
    return;
  }
  
  var data = sheet.getDataRange().getValues();
  var currentTime = new Date();
  
  // 既存の行を検索
  var existingRowIndex = -1;
  for (var i = 1; i < data.length; i++) {
    if (data[i][0] === employeeId) {
      existingRowIndex = i + 1; // 1ベースの行番号に変換
      break;
    }
  }
  
  if (existingRowIndex > 0) {
    // 既存の行を更新
    sheet.getRange(existingRowIndex, 2).setValue(hashedPassword); // ハッシュ化パスワード
    sheet.getRange(existingRowIndex, 3).setValue(currentTime); // パスワード最終更新日時
    
    if (isLogin) {
      sheet.getRange(existingRowIndex, 4).setValue(currentTime); // 最終ログイン日時
    }
    
    console.log('従業員ID ' + employeeId + ' の認証情報を更新しました');
  } else {
    // 新しい行を追加
    var newRowData = [
      employeeId,
      hashedPassword,
      currentTime,
      isLogin ? currentTime : null
    ];
    sheet.appendRow(newRowData);
    console.log('従業員ID ' + employeeId + ' の認証情報を新規作成しました');
  }
}

/**
 * 現在の従業員の認証情報を取得する（認証設定画面用）
 * @returns {object|null} 認証情報オブジェクト、見つからない場合はnull
 */
function getCurrentAuthInfo() {
  var selectedEmpId = getSelectedEmployeeId();
  if (!selectedEmpId) {
    console.log('選択された従業員IDがありません');
    return null;
  }
  
  return getAuthInfo(selectedEmpId);
}

/**
 * パスワードを変更する
 * @param {string} currentPassword - 現在のパスワード
 * @param {string} newPassword - 新しいパスワード
 * @returns {object} 結果オブジェクト {success: boolean, message: string}
 */
function changePassword(currentPassword, newPassword) {
  try {
    var selectedEmpId = getSelectedEmployeeId();
    if (!selectedEmpId) {
      return {success: false, message: '従業員IDが設定されていません'};
    }
    
    var authInfo = getAuthInfo(selectedEmpId);
    if (!authInfo) {
      return {success: false, message: '認証情報が見つかりません'};
    }
    
    // 現在のパスワードを検証（簡易的なハッシュ比較）
    var currentHashed = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, currentPassword, Utilities.Charset.UTF_8);
    var currentHashedStr = Utilities.base64Encode(currentHashed);
    
    if (currentHashedStr !== authInfo.hashedPassword) {
      return {success: false, message: '現在のパスワードが正しくありません'};
    }
    
    // 新しいパスワードをハッシュ化して保存
    var newHashed = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, newPassword, Utilities.Charset.UTF_8);
    var newHashedStr = Utilities.base64Encode(newHashed);
    
    saveAuthInfo(selectedEmpId, newHashedStr, false);
    
    return {success: true, message: 'パスワードが正常に変更されました'};
  } catch (error) {
    console.error('パスワード変更エラー:', error);
    return {success: false, message: 'パスワードの変更中にエラーが発生しました'};
  }
}

/**
 * 初回パスワードを設定する
 * @param {string} employeeId - 従業員ID
 * @param {string} password - 設定するパスワード
 * @returns {object} 結果オブジェクト {success: boolean, message: string}
 */
function setInitialPassword(employeeId, password) {
  try {
    if (!employeeId) {
      return {success: false, message: '従業員IDが指定されていません'};
    }
    
    // パスワードをハッシュ化して保存
    var hashed = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, password, Utilities.Charset.UTF_8);
    var hashedStr = Utilities.base64Encode(hashed);
    
    saveAuthInfo(employeeId, hashedStr, false);
    
    return {success: true, message: 'パスワードが正常に設定されました'};
  } catch (error) {
    console.error('初回パスワード設定エラー:', error);
    return {success: false, message: 'パスワードの設定中にエラーが発生しました'};
  }
}

/**
 * ログイン処理
 * @param {string} employeeId - 従業員ID
 * @param {string} password - パスワード
 * @returns {object} 結果オブジェクト {success: boolean, message: string, isFirstLogin: boolean}
 */
function login(employeeId, password) {
  try {
    console.log('login: 従業員ID =', employeeId, '(型:', typeof employeeId, ')');
    
    // 認証情報を取得
    var authInfo = getAuthInfo(employeeId);
    console.log('login: 認証情報 =', authInfo);
    
    if (!authInfo || !authInfo.hashedPassword) {
      console.log('login: パスワードが設定されていません');
      // パスワードが設定されていない場合は初回パスワード設定画面に誘導
      return {success: false, message: 'パスワードが設定されていません。初回パスワード設定を行ってください。', needsPasswordSetup: true};
    }
    
    // パスワードを検証
    var inputHashed = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, password, Utilities.Charset.UTF_8);
    var inputHashedStr = Utilities.base64Encode(inputHashed);
    
    if (inputHashedStr !== authInfo.hashedPassword) {
      return {success: false, message: 'パスワードが正しくありません'};
    }
    
    // ログイン成功 - セッション情報を保存
    PropertiesService.getUserProperties().setProperty('selectedEmpId', employeeId);
    PropertiesService.getUserProperties().setProperty('isAuthenticated', 'true');
    
    // 最終ログイン日時を更新
    saveAuthInfo(employeeId, authInfo.hashedPassword, true);
    
    console.log('ログイン成功: 従業員ID ' + employeeId);
    return {success: true, message: 'ログインしました'};
  } catch (error) {
    console.error('ログインエラー:', error);
    return {success: false, message: 'ログイン中にエラーが発生しました'};
  }
}

/**
 * 認証状態をチェックする
 * @returns {boolean} 認証済みかどうか
 */
function isAuthenticated() {
  var isAuth = PropertiesService.getUserProperties().getProperty('isAuthenticated');
  var selectedEmpId = PropertiesService.getUserProperties().getProperty('selectedEmpId');
  
  return isAuth === 'true' && selectedEmpId !== null;
}

/**
 * 認証コード管理シートを初期化する
 */
function initializeVerificationCodesSheet() {
  var spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = spreadsheet.getSheetByName(VERIFICATION_CODES_SHEET_NAME);
  
  if (!sheet) {
    sheet = spreadsheet.insertSheet(VERIFICATION_CODES_SHEET_NAME);
    console.log('認証コード管理シートを新規作成しました');
  }
  
  // ヘッダー行を設定
  var headerRange = sheet.getRange(1, 1, 1, 4);
  var existingHeaders = headerRange.getValues()[0];
  
  if (!existingHeaders[0] || existingHeaders[0] !== '従業員ID') {
    var headers = ['従業員ID', '認証コード', '送信日時', '有効期限'];
    headerRange.setValues([headers]);
    
    // ヘッダー行のスタイル設定
    headerRange.setFontWeight('bold');
    headerRange.setBackground('#f0f0f0');
    
    console.log('認証コード管理シートのヘッダーを設定しました');
  }
  
  return sheet;
}

/**
 * 認証コードを送信する
 * @param {string} employeeId - 従業員ID
 * @returns {object} 結果オブジェクト {success: boolean, message: string}
 */
function sendVerificationCode(employeeId) {
  try {
    // 従業員情報を取得
    var employees = getEmployees();
    var employee = findEmployeeById(employeeId, employees);
    
    if (!employee || !employee.email) {
      return {success: false, message: '従業員のメールアドレスが見つかりません'};
    }
    
    // 6桁の認証コードを生成
    var verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
    
    // 認証コード管理シートを初期化
    var sheet = initializeVerificationCodesSheet();
    
    // 既存の認証コードを削除
    var data = sheet.getDataRange().getValues();
    for (var i = data.length - 1; i >= 1; i--) {
      if (data[i][0] == employeeId) { // 型を気にしない比較に変更
        sheet.deleteRow(i + 1);
        console.log('既存の認証コードを削除: 行' + (i + 1));
      }
    }
    
    // 新しい認証コードを保存
    var currentTime = new Date();
    var expirationTime = new Date(currentTime.getTime() + 10 * 60 * 1000); // 10分後
    
    var newRowData = [
      employeeId.toString(), // 文字列に統一
      verificationCode,
      currentTime,
      expirationTime
    ];
    sheet.appendRow(newRowData);
    
    console.log('認証コードを保存しました: 従業員ID=' + employeeId + ', コード=' + verificationCode);
    
    // メール送信
    var subject = "【勤怠管理システム】初回パスワード設定の認証コード";
    var body = employee.display_name + "様\n\n" +
               "勤怠管理システムの初回パスワード設定の認証コードをお送りします。\n\n" +
               "認証コード: " + verificationCode + "\n\n" +
               "この認証コードは10分間有効です。\n" +
               "認証コードを入力してパスワード設定を完了してください。\n\n" +
               "※このメールに心当たりがない場合は、無視してください。";
    
    MailApp.sendEmail(employee.email, subject, body);
    
    console.log('認証コードを送信しました: 従業員ID ' + employeeId);
    return {success: true, message: '認証コードを送信しました'};
  } catch (error) {
    console.error('認証コード送信エラー:', error);
    return {success: false, message: '認証コードの送信に失敗しました'};
  }
}

/**
 * 認証コードを検証する
 * @param {string} employeeId - 従業員ID
 * @param {string} inputCode - 入力された認証コード
 * @returns {object} 結果オブジェクト {success: boolean, message: string}
 */
function verifyCode(employeeId, inputCode) {
  try {
    var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(VERIFICATION_CODES_SHEET_NAME);
    if (!sheet) {
      console.log('認証コード管理シートが見つかりません');
      return {success: false, message: '認証コードが見つかりません'};
    }
    
    var data = sheet.getDataRange().getValues();
    var currentTime = new Date();
    
    console.log('認証コード検証開始: 従業員ID=' + employeeId + ', 入力コード=' + inputCode);
    console.log('シートデータ行数:', data.length);
    
    // 最新の認証コードを探す（最後に見つかった有効なもの）
    var latestValidCode = null;
    var latestValidIndex = -1;
    
    for (var i = 1; i < data.length; i++) {
      var storedEmployeeId = data[i][0];
      var storedCode = data[i][1];
      var expirationTime = new Date(data[i][3]);
      
      console.log('行' + i + ': 従業員ID=' + storedEmployeeId + ', コード=' + storedCode + ', 期限=' + expirationTime);
      
      // 従業員IDの比較（文字列と数値の両方に対応）
      if (storedEmployeeId == employeeId) {
        console.log('従業員ID一致: ' + storedEmployeeId + ' == ' + employeeId);
        
        // 有効期限チェック
        if (currentTime > expirationTime) {
          console.log('期限切れの認証コードを削除: 行' + (i + 1));
          sheet.deleteRow(i + 1);
          continue;
        }
        
        // 最新の有効な認証コードを記録
        latestValidCode = storedCode;
        latestValidIndex = i;
      }
    }
    
    if (latestValidCode === null) {
      console.log('有効な認証コードが見つかりません');
      return {success: false, message: '認証コードが見つかりません'};
    }
    
    console.log('最新の有効な認証コード: ' + latestValidCode);
    
    // 認証コードチェック
    if (latestValidCode == inputCode) {
      // 認証成功 - 認証コードは削除せずに保持（パスワード設定完了まで）
      console.log('認証コード検証成功: 従業員ID ' + employeeId);
      return {success: true, message: '認証が完了しました'};
    } else {
      console.log('認証コード不一致: 期待値=' + latestValidCode + ', 入力値=' + inputCode);
      return {success: false, message: '認証コードが正しくありません'};
    }
  } catch (error) {
    console.error('認証コード検証エラー:', error);
    return {success: false, message: '認証に失敗しました'};
  }
}

/**
 * 認証コードを削除する
 * @param {string} employeeId - 従業員ID
 */
function deleteVerificationCode(employeeId) {
  try {
    var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(VERIFICATION_CODES_SHEET_NAME);
    if (!sheet) {
      console.log('認証コード管理シートが見つかりません');
      return;
    }
    
    var data = sheet.getDataRange().getValues();
    
    // 該当する認証コードを削除
    for (var i = data.length - 1; i >= 1; i--) {
      if (data[i][0] == employeeId) {
        sheet.deleteRow(i + 1);
        console.log('認証コードを削除しました: 従業員ID ' + employeeId + ', 行' + (i + 1));
      }
    }
  } catch (error) {
    console.error('認証コード削除エラー:', error);
  }
}

/**
 * 認証付きで初回パスワードを設定する
 * @param {string} employeeId - 従業員ID
 * @param {string} password - 設定するパスワード
 * @param {string} verificationCode - 認証コード
 * @returns {object} 結果オブジェクト {success: boolean, message: string}
 */
function setInitialPasswordWithVerification(employeeId, password, verificationCode) {
  try {
    // 認証コードを再検証
    var verificationResult = verifyCode(employeeId, verificationCode);
    if (!verificationResult.success) {
      return verificationResult;
    }
    
    // パスワードをハッシュ化して保存
    var hashed = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, password, Utilities.Charset.UTF_8);
    var hashedStr = Utilities.base64Encode(hashed);
    
    saveAuthInfo(employeeId, hashedStr, false);
    
    // パスワード設定成功後、認証コードを削除
    deleteVerificationCode(employeeId);
    
    console.log('認証付き初回パスワード設定完了: 従業員ID ' + employeeId);
    return {success: true, message: 'パスワードが正常に設定されました'};
  } catch (error) {
    console.error('認証付き初回パスワード設定エラー:', error);
    return {success: false, message: 'パスワードの設定中にエラーが発生しました'};
  }
}

/**
 * ログアウト処理
 * @returns {object} 結果オブジェクト {success: boolean, message: string}
 */
function logout() {
  try {
    // セッション情報をクリア
    PropertiesService.getUserProperties().deleteProperty('selectedEmpId');
    PropertiesService.getUserProperties().deleteProperty('isAuthenticated');
    
    console.log('ログアウト処理が完了しました');
    return {success: true, message: 'ログアウトしました'};
  } catch (error) {
    console.error('ログアウトエラー:', error);
    return {success: false, message: 'ログアウト中にエラーが発生しました'};
  }
}

/**
 * 指定された従業員がオーナー権限を持つかどうかを判定する
 * @param {string} employeeId - 従業員ID
 * @returns {boolean} オーナー権限を持つかどうか
 */
function isOwner(employeeId) {
  try {
    var employees = getEmployees();
    if (!employees || employees.length === 0) {
      console.log('isOwner: 従業員情報が取得できません');
      return false;
    }
    
    var employee = employees.find(function(emp) {
      return emp.id == employeeId;
    });
    
    if (!employee) {
      console.log('isOwner: 従業員が見つかりません: ' + employeeId);
      return false;
    }
    
    var isOwnerResult = employee.display_name === '店長 太郎';
    console.log('isOwner: 従業員ID=' + employeeId + ', 名前=' + employee.display_name + ', オーナー=' + isOwnerResult);
    return isOwnerResult;
  } catch (error) {
    console.error('isOwner: エラーが発生しました:', error);
    return false;
  }
}

/**
 * 現在ログインしているユーザーがオーナー権限を持つかどうかを判定する
 * @returns {boolean} オーナー権限を持つかどうか
 */
function isCurrentUserOwner() {
  try {
    var selectedEmpId = PropertiesService.getUserProperties().getProperty('selectedEmpId');
    if (!selectedEmpId) {
      console.log('isCurrentUserOwner: ログインしていません');
      return false;
    }
    
    return isOwner(selectedEmpId);
  } catch (error) {
    console.error('isCurrentUserOwner: エラーが発生しました:', error);
    return false;
  }
}

/**
 * 現在選択されている従業員IDを取得する
 * @returns {string|null} 従業員ID
 */
function getSelectedEmployeeId() {
  try {
    var selectedEmpId = PropertiesService.getUserProperties().getProperty('selectedEmpId');
    console.log('getSelectedEmployeeId: ' + selectedEmpId);
    return selectedEmpId;
  } catch (error) {
    console.error('getSelectedEmployeeId: エラーが発生しました:', error);
    return null;
  }
}

/**
 * 従業員の給与情報を取得する
 * @param {string} employeeId - 従業員ID
 * @returns {object} 給与情報 {wage: number, target: number, percentage: number}
 */
function getWageInfo(employeeId) {
  try {
    var now = new Date();
    var currentMonth = now.getMonth() + 1;
    var currentYear = now.getFullYear();
    
    console.log('getWageInfo: 従業員ID=' + employeeId + ', 月=' + currentMonth + ', 年=' + currentYear);
    
    // 既存のgetEmployeeWageInfo関数を使用
    var wageDataJson = getEmployeeWageInfo(employeeId, currentMonth, currentYear);
    var wageData = JSON.parse(wageDataJson);
    
    if (wageData.error) {
      console.error('getWageInfo: エラー:', wageData.error);
      return {wage: 0, target: 1030000, percentage: 0};
    }
    
    console.log('getWageInfo: 給与データ取得成功:', wageData);
    return {
      wage: wageData.wage,
      target: wageData.target,
      percentage: wageData.percentage
    };
  } catch (error) {
    console.error('getWageInfo: エラーが発生しました:', error);
    return {wage: 0, target: 1030000, percentage: 0};
  }
}

/**
 * 出勤打刻を行う
 * @param {string} employeeId - 従業員ID
 * @returns {object} 結果 {success: boolean, message: string}
 */
function clockIn(employeeId) {
  try {
    console.log('clockIn: 従業員ID=' + employeeId);
    
    // 現在の日時を取得
    var now = new Date();
    var dateStr = now.getFullYear() + '-' + 
                 String(now.getMonth() + 1).padStart(2, '0') + '-' + 
                 String(now.getDate()).padStart(2, '0');
    var timeStr = String(now.getHours()).padStart(2, '0') + ':' + 
                 String(now.getMinutes()).padStart(2, '0');
    
    // フォームオブジェクトを作成
    var form = {
      target_date: dateStr,
      target_time: timeStr,
      target_type: 'clock_in'
    };
    
    // 既存のpostWorkRecord関数を使用
    var result = postWorkRecord(form);
    
    if (result === '登録しました') {
      return {
        success: true,
        message: '出勤打刻が完了しました'
      };
    } else {
      return {
        success: false,
        message: result || '出勤打刻に失敗しました'
      };
    }
  } catch (error) {
    console.error('clockIn: エラーが発生しました:', error);
    return {
      success: false,
      message: '出勤打刻中にエラーが発生しました'
    };
  }
}

/**
 * 退勤打刻を行う
 * @param {string} employeeId - 従業員ID
 * @returns {object} 結果 {success: boolean, message: string}
 */
function clockOut(employeeId) {
  try {
    console.log('clockOut: 従業員ID=' + employeeId);
    
    // 現在の日時を取得
    var now = new Date();
    var dateStr = now.getFullYear() + '-' + 
                 String(now.getMonth() + 1).padStart(2, '0') + '-' + 
                 String(now.getDate()).padStart(2, '0');
    var timeStr = String(now.getHours()).padStart(2, '0') + ':' + 
                 String(now.getMinutes()).padStart(2, '0');
    
    // フォームオブジェクトを作成
    var form = {
      target_date: dateStr,
      target_time: timeStr,
      target_type: 'clock_out'
    };
    
    // 既存のpostWorkRecord関数を使用
    var result = postWorkRecord(form);
    
    if (result === '登録しました') {
      return {
        success: true,
        message: '退勤打刻が完了しました'
      };
    } else {
      return {
        success: false,
        message: result || '退勤打刻に失敗しました'
      };
    }
  } catch (error) {
    console.error('clockOut: エラーが発生しました:', error);
    return {
      success: false,
      message: '退勤打刻中にエラーが発生しました'
    };
  }
}

/**
 * 従業員の打刻状態を取得する
 * @param {string} employeeId - 従業員ID
 * @returns {object} 打刻状態 {canClockIn: boolean, canClockOut: boolean, message: string}
 */
function getClockStatus(employeeId) {
  try {
    console.log('getClockStatus: 従業員ID=' + employeeId);
    
    // 今日の勤怠記録を取得
    var today = new Date();
    var timeClocks = getTimeClocksFor(employeeId, today);
    
    var hasClockIn = false;
    var hasClockOut = false;
    
    // 今日の打刻記録をチェック
    for (var i = 0; i < timeClocks.length; i++) {
      var record = timeClocks[i];
      if (record.type === 'clock_in') {
        hasClockIn = true;
      } else if (record.type === 'clock_out') {
        hasClockOut = true;
      }
    }
    
    var canClockIn = !hasClockIn;
    var canClockOut = hasClockIn && !hasClockOut;
    
    var message = '';
    if (canClockIn) {
      message = '出勤打刻が可能です';
    } else if (canClockOut) {
      message = '退勤打刻が可能です';
    } else if (hasClockIn && hasClockOut) {
      message = '本日の打刻は完了しています';
    } else {
      message = '打刻状態を確認中です';
    }
    
    return {
      canClockIn: canClockIn,
      canClockOut: canClockOut,
      message: message
    };
  } catch (error) {
    console.error('getClockStatus: エラーが発生しました:', error);
    return {
      canClockIn: false,
      canClockOut: false,
      message: 'エラーが発生しました'
    };
  }
}

