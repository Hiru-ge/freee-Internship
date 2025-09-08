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
var accessToken = 'MBXGNz_xeAFs6JLiTm2Yg1sgnIlRoYeagG9IxMRVCuw'
var companyId =  12127317
var SHIFT_SHEET_NAME = "シフト表";
var SHIFT_MANAGEMENT_SHEET_NAME = "シフト交代管理";
var AUTH_SETTINGS_SHEET_NAME = "認証設定";
var VERIFICATION_CODES_SHEET_NAME = "認証コード管理";
var MONTHLY_WAGE_TARGET = 1030000;


function createAuthenticatedPage(templateName, title) {
  if (!isAuthenticated()) {
    return createPage("view_login", "ログイン - 勤怠管理システム");
  }
  return createPage(templateName, title);
}

function createPage(templateName, title) {
  return HtmlService.createTemplateFromFile(templateName)
    .evaluate().setTitle(title);
}

function doGet(e) {
  var page = e.parameter.page;

  if (page === 'login') {
    return createPage("view_login", "ログイン - 勤怠管理システム");
  } else if (page === 'initial_password') {
    return createPage("view_initial_password", "初回パスワード設定 - 勤怠管理システム");
  } else if (page === 'forgot_password') {
    return createPage("view_forgot_password", "パスワードを忘れた場合 - 勤怠管理システム");
  } else if (page === 'my_page') {
    return createAuthenticatedPage("view_my_page", "マイページ - 勤怠管理システム");
  } else if (page === 'password_change') {
    return createAuthenticatedPage("view_password_change", "パスワード変更 - 勤怠管理システム");
  } else if (page === 'shift') {
    return createAuthenticatedPage("view_shift_page", "シフト管理 - 勤怠管理システム");
  } else if (page === 'shift_request_form') {
    return createAuthenticatedPage("view_shift_request_form", "シフト交代申請 - 勤怠管理システム");
  } else if (page === 'shift_add_form') {
    if (!isAuthenticated()) {
      return createPage("view_login", "ログイン - 勤怠管理システム");
    }
    if (!isCurrentUserOwner()) {
      return createPage("view_my_page", "マイページ - 勤怠管理システム");
    }
    return createPage("view_shift_add_form", "シフト追加 - 勤怠管理システム");
  } else if (page === 'approval') {
    return createAuthenticatedPage("view_shift_approval", "シフト承認 - 勤怠管理システム");
  }

  return createPage("view_login", "ログイン - 勤怠管理システム");
}

function getAppUrl() {
  return ScriptApp.getService().getUrl();
}

function formatYearMonth(yearMonth) {
  var dateParts = yearMonth.split('-');
  if (dateParts.length === 2) {
    var year = dateParts[0];
    var month = parseInt(dateParts[1], 10);
    return year + '年' + month + '月';
  }
  return yearMonth;
}

function formatDateTimeJapanese(dateObj) {
  return dateObj.getFullYear() + '年' 
    + (dateObj.getMonth() + 1) + '月' 
    + dateObj.getDate() + '日 ' 
    + dateObj.getHours() + '時' 
    + dateObj.getMinutes() + '分';
}

function parseShiftTime(timeString) {
  if (!timeString || typeof timeString !== 'string') {
    return null;
  }
  
  var timeParts = timeString.split('-');
  if (timeParts.length !== 2) {
    return null;
  }
  
  var startHour = parseInt(timeParts[0], 10);
  var endHour = parseInt(timeParts[1], 10);
  
  if (isNaN(startHour) || isNaN(endHour)) {
    return null;
  }
  
  return {
    startHour: startHour,
    endHour: endHour
  };
}

function findEmployeeById(employeeId, employees) {
  if (!employees) return null;
  return employees.find(function(emp) {
    return String(emp.id) === String(employeeId);
  });
}