/**
 * 認証管理システム
 * ログイン、パスワード管理、認証コード管理、権限管理を担当
 */


function getAuthInfo(employeeId) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(AUTH_SETTINGS_SHEET_NAME);
  if (!sheet) {
    return null;
  }
  
  var data = sheet.getDataRange().getValues();
  
  for (var rowIndex = 1; rowIndex < data.length; rowIndex++) {
    var storedEmployeeId = data[rowIndex][0];
    
    if (storedEmployeeId == employeeId) {
      return {
        employeeId: data[rowIndex][0],
        hashedPassword: data[rowIndex][1],
        passwordLastUpdated: data[rowIndex][2],
        lastLogin: data[rowIndex][3]
      };
    }
  }
  return null;
}

function saveAuthInfo(employeeId, hashedPassword, isLogin) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(AUTH_SETTINGS_SHEET_NAME);
  if (!sheet) {
    return;
  }
  
  var data = sheet.getDataRange().getValues();
  var currentTime = new Date();
  
  var existingRowIndex = -1;
  for (var rowIndex = 1; rowIndex < data.length; rowIndex++) {
    if (data[rowIndex][0] === employeeId) {
      existingRowIndex = rowIndex + 1;
      break;
    }
  }
  
  if (existingRowIndex > 0) {
    sheet.getRange(existingRowIndex, 2).setValue(hashedPassword);
    sheet.getRange(existingRowIndex, 3).setValue(currentTime);
    
    if (isLogin) {
      sheet.getRange(existingRowIndex, 4).setValue(currentTime);
    }
    
  } else {
    var newRowData = [
      employeeId,
      hashedPassword,
      currentTime,
      isLogin ? currentTime : null
    ];
    sheet.appendRow(newRowData);
  }
}

function getCurrentAuthInfo() {
  var selectedEmpId = getSelectedEmployeeId();
  if (!selectedEmpId) {
    return null;
  }
  
  return getAuthInfo(selectedEmpId);
}

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
    
    var currentHashed = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, currentPassword, Utilities.Charset.UTF_8);
    var currentHashedStr = Utilities.base64Encode(currentHashed);
    
    if (currentHashedStr !== authInfo.hashedPassword) {
      return {success: false, message: '現在のパスワードが正しくありません'};
    }
    
    var newHashed = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, newPassword, Utilities.Charset.UTF_8);
    var newHashedStr = Utilities.base64Encode(newHashed);
    
    saveAuthInfo(selectedEmpId, newHashedStr, false);
    
    return {success: true, message: 'パスワードが正常に変更されました'};
  } catch (error) {
    console.error('パスワード変更エラー:', error);
    return {success: false, message: 'パスワードの変更中にエラーが発生しました'};
  }
}

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

function login(employeeId, password) {
  try {
    var authInfo = getAuthInfo(employeeId);
    
    if (!authInfo || !authInfo.hashedPassword) {
      return {success: false, message: 'パスワードが設定されていません。初回パスワード設定を行ってください。', needsPasswordSetup: true};
    }
    
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
    
    return {success: true, message: 'ログインしました'};
  } catch (error) {
    console.error('ログインエラー:', error);
    return {success: false, message: 'ログイン中にエラーが発生しました'};
  }
}

function isAuthenticated() {
  var isAuth = PropertiesService.getUserProperties().getProperty('isAuthenticated');
  var selectedEmpId = PropertiesService.getUserProperties().getProperty('selectedEmpId');
  
  return isAuth === 'true' && selectedEmpId !== null;
}

function logout() {
  try {
    PropertiesService.getUserProperties().deleteProperty('selectedEmpId');
    PropertiesService.getUserProperties().deleteProperty('isAuthenticated');
    
    return {success: true, message: 'ログアウトしました'};
  } catch (error) {
    console.error('ログアウトエラー:', error);
    return {success: false, message: 'ログアウト中にエラーが発生しました'};
  }
}

function initializeVerificationCodesSheet() {
  var spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = spreadsheet.getSheetByName(VERIFICATION_CODES_SHEET_NAME);
  
  if (!sheet) {
    sheet = spreadsheet.insertSheet(VERIFICATION_CODES_SHEET_NAME);
  }
  
  var headerRange = sheet.getRange(1, 1, 1, 4);
  var existingHeaders = headerRange.getValues()[0];
  
  if (!existingHeaders[0] || existingHeaders[0] !== '従業員ID') {
    var headers = ['従業員ID', '認証コード', '送信日時', '有効期限'];
    headerRange.setValues([headers]);
    
    // ヘッダー行のスタイル設定
    headerRange.setFontWeight('bold');
    headerRange.setBackground('#f0f0f0');
    
  }
  
  return sheet;
}

function sendPasswordResetCode(employeeId) {
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
      if (data[rowIndex][0] == employeeId) {
        sheet.deleteRow(rowIndex + 1);
      }
    }
    
    // 新しい認証コードを保存
    var currentTime = new Date();
    var expirationTime = new Date(currentTime.getTime() + 10 * 60 * 1000); // 10分後
    
    var newRowData = [
      employeeId.toString(),
      verificationCode,
      currentTime,
      expirationTime
    ];
    sheet.appendRow(newRowData);
    
    
    // メール送信
    var subject = "【勤怠管理システム】パスワード再設定の認証コード";
    var body = employee.display_name + "様\n\n" +
               "勤怠管理システムのパスワード再設定の認証コードをお送りします。\n\n" +
               "認証コード: " + verificationCode + "\n\n" +
               "この認証コードは10分間有効です。\n" +
               "認証コードを入力してパスワード再設定を完了してください。\n\n" +
               "※このメールに心当たりがない場合は、無視してください。\n" +
               "※パスワードを忘れた場合の再設定手続きです。";
    
    MailApp.sendEmail(employee.email, subject, body);
    
    return {success: true, message: '認証コードを送信しました'};
  } catch (error) {
    console.error('パスワードリセット用認証コード送信エラー:', error);
    return {success: false, message: '認証コードの送信に失敗しました'};
  }
}

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
      if (data[rowIndex][0] == employeeId) { // 型を気にしない比較に変更
        sheet.deleteRow(rowIndex + 1);
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
    
    
    // メール送信
    var subject = "【勤怠管理システム】初回パスワード設定の認証コード";
    var body = employee.display_name + "様\n\n" +
               "勤怠管理システムの初回パスワード設定の認証コードをお送りします。\n\n" +
               "認証コード: " + verificationCode + "\n\n" +
               "この認証コードは10分間有効です。\n" +
               "認証コードを入力してパスワード設定を完了してください。\n\n" +
               "※このメールに心当たりがない場合は、無視してください。";
    
    MailApp.sendEmail(employee.email, subject, body);
    
    return {success: true, message: '認証コードを送信しました'};
  } catch (error) {
    console.error('認証コード送信エラー:', error);
    return {success: false, message: '認証コードの送信に失敗しました'};
  }
}

function verifyPasswordResetCode(employeeId, inputCode) {
  try {
    var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(VERIFICATION_CODES_SHEET_NAME);
    if (!sheet) {
      return {success: false, message: '認証コードが見つかりません'};
    }
    
    var data = sheet.getDataRange().getValues();
    var currentTime = new Date();
    
    
    // 最新の認証コードを探す（最後に見つかった有効なもの）
    var latestValidCode = null;
    var latestValidIndex = -1;
    
    for (var rowIndex = 1; rowIndex < data.length; rowIndex++) {
      var storedEmployeeId = data[rowIndex][0];
      var storedCode = data[rowIndex][1];
      var expirationTime = new Date(data[rowIndex][3]);
      
      
      // 従業員IDの比較（文字列と数値の両方に対応）
      if (storedEmployeeId == employeeId) {
        
        // 有効期限チェック
        if (currentTime > expirationTime) {
          sheet.deleteRow(rowIndex + 1);
          continue;
        }
        
        // 最新の有効な認証コードを記録
        latestValidCode = storedCode;
        latestValidIndex = i;
      }
    }
    
    if (latestValidCode === null) {
      return {success: false, message: '認証コードが見つかりません'};
    }
    
    
    // 認証コードチェック
    if (latestValidCode == inputCode) {
      // 認証成功 - 認証コードは削除せずに保持（パスワード再設定完了まで）
      return {success: true, message: '認証が完了しました'};
    } else {
      return {success: false, message: '認証コードが正しくありません'};
    }
  } catch (error) {
    console.error('パスワードリセット用認証コード検証エラー:', error);
    return {success: false, message: '認証に失敗しました'};
  }
}

function verifyCode(employeeId, inputCode) {
  try {
    var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(VERIFICATION_CODES_SHEET_NAME);
    if (!sheet) {
      return {success: false, message: '認証コードが見つかりません'};
    }
    
    var data = sheet.getDataRange().getValues();
    var currentTime = new Date();
    
    
    // 最新の認証コードを探す（最後に見つかった有効なもの）
    var latestValidCode = null;
    var latestValidIndex = -1;
    
    for (var rowIndex = 1; rowIndex < data.length; rowIndex++) {
      var storedEmployeeId = data[rowIndex][0];
      var storedCode = data[rowIndex][1];
      var expirationTime = new Date(data[rowIndex][3]);
      
      
      // 従業員IDの比較（文字列と数値の両方に対応）
      if (storedEmployeeId == employeeId) {
        
        // 有効期限チェック
        if (currentTime > expirationTime) {
          sheet.deleteRow(rowIndex + 1);
          continue;
        }
        
        // 最新の有効な認証コードを記録
        latestValidCode = storedCode;
        latestValidIndex = i;
      }
    }
    
    if (latestValidCode === null) {
      return {success: false, message: '認証コードが見つかりません'};
    }
    
    
    // 認証コードチェック
    if (latestValidCode == inputCode) {
      // 認証成功 - 認証コードは削除せずに保持（パスワード設定完了まで）
      return {success: true, message: '認証が完了しました'};
    } else {
      return {success: false, message: '認証コードが正しくありません'};
    }
  } catch (error) {
    console.error('認証コード検証エラー:', error);
    return {success: false, message: '認証に失敗しました'};
  }
}

function deleteVerificationCode(employeeId) {
  try {
    var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(VERIFICATION_CODES_SHEET_NAME);
    if (!sheet) {
      return;
    }
    
    var data = sheet.getDataRange().getValues();
    
    // 該当する認証コードを削除
    for (var i = data.length - 1; i >= 1; i--) {
      if (data[rowIndex][0] == employeeId) {
        sheet.deleteRow(rowIndex + 1);
      }
    }
  } catch (error) {
    console.error('認証コード削除エラー:', error);
  }
}

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
    
    return {success: true, message: 'パスワードが正常に設定されました'};
  } catch (error) {
    console.error('認証付き初回パスワード設定エラー:', error);
    return {success: false, message: 'パスワードの設定中にエラーが発生しました'};
  }
}

function resetPasswordWithVerification(employeeId, password, verificationCode) {
  try {
    // 認証コードを検証
    var verificationResult = verifyPasswordResetCode(employeeId, verificationCode);
    if (!verificationResult.success) {
      return verificationResult;
    }
    
    // パスワードをハッシュ化して保存
    var hashed = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, password, Utilities.Charset.UTF_8);
    var hashedStr = Utilities.base64Encode(hashed);
    
    saveAuthInfo(employeeId, hashedStr, false);
    
    // パスワード再設定成功後、認証コードを削除
    deleteVerificationCode(employeeId);
    
    return {success: true, message: 'パスワードが正常に再設定されました'};
  } catch (error) {
    console.error('認証付きパスワード再設定エラー:', error);
    return {success: false, message: 'パスワードの再設定中にエラーが発生しました'};
  }
}

function isOwner(employeeId) {
  try {
    var employees = getEmployees();
    if (!employees || employees.length === 0) {
      return false;
    }
    
    var employee = employees.find(function(emp) {
      return emp.id == employeeId;
    });
    
    if (!employee) {
      return false;
    }
    
    var isOwnerResult = employee.display_name === '店長 太郎';
    return isOwnerResult;
  } catch (error) {
    console.error('isOwner: エラーが発生しました:', error);
    return false;
  }
}

function isCurrentUserOwner() {
  try {
    var selectedEmpId = PropertiesService.getUserProperties().getProperty('selectedEmpId');
    if (!selectedEmpId) {
      return false;
    }
    
    return isOwner(selectedEmpId);
  } catch (error) {
    console.error('isCurrentUserOwner: エラーが発生しました:', error);
    return false;
  }
}

function getSelectedEmployeeId() {
  try {
    var selectedEmpId = PropertiesService.getUserProperties().getProperty('selectedEmpId');
    return selectedEmpId;
  } catch (error) {
    console.error('getSelectedEmployeeId: エラーが発生しました:', error);
    return null;
  }
}

function setSelectedEmployeeId(employeeId) {
  PropertiesService.getUserProperties().setProperty('selectedEmpId', employeeId);
}
