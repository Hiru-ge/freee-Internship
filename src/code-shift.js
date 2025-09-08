/**
 * シフト管理システム
 * シフト表操作、シフト交代、シフト追加を担当
 */

function isShiftOverlapping(existingShift, requestStartHour, requestEndHour) {
  if (!existingShift) {
    return false;
  }
  
  return (existingShift.startHour < requestEndHour) && (existingShift.endHour > requestStartHour);
}

function getShifts() {
  try {
    var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHIFT_SHEET_NAME);
    if (!sheet || sheet.getLastRow() < 3) {
      var now = new Date();
      var emptyResult = { year: now.getFullYear(), month: now.getMonth() + 1, shifts: {} };
      return JSON.stringify(emptyResult);
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
      
      for (var colIndex = 2; colIndex < dateHeader.length; colIndex++) {
        var date = dateHeader[colIndex];
        var shiftTime = row[colIndex];
        if (date && shiftTime) {
          shifts[String(employeeId)].shifts[String(date)] = shiftTime;
        }
      }
    });

    var shiftData = {
      year: year,
      month: month,
      shifts: shifts
    };

    return JSON.stringify(shiftData);

  } catch (e) {
    console.error("getShifts関数で予期せぬエラーが発生しました: " + e.message + " スタック: " + e.stack);
    return null;
  }
}

function findRowByEmployeeId(employeeId) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHIFT_SHEET_NAME);
  var lastRow = sheet.getLastRow();
  var ids = sheet.getRange("A3:A" + lastRow).getValues();

  for (var rowIndex = 0; rowIndex < ids.length; rowIndex++) {
    if (String(ids[rowIndex][0]) === String(employeeId)) {
      return rowIndex + 3; 
    }
  }
  return null;
}


function findDateColumn(date) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHIFT_SHEET_NAME);
  var lastCol = sheet.getLastColumn();
  var dates = sheet.getRange(2, 3, 1, lastCol - 2).getValues()[0];

  for (var i = 0; i < dates.length; i++) {
    if (String(dates[i]) === String(date)) {
      return i + 3;
    }
  }
  return null;
}

function updateShift(employeeId, date, timeString) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHIFT_SHEET_NAME);
  var targetRow = findRowByEmployeeId(employeeId); 
  var targetCol = findDateColumn(date);

  if (targetRow && targetCol) {
    sheet.getRange(targetRow, targetCol).setValue(timeString);
  } else {
    console.error("更新対象のセルが見つかりませんでした。従業員ID: " + employeeId + ", 日付: " + date);
  }
}

function deleteShift(employeeId, date) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHIFT_SHEET_NAME);
  var targetRow = findRowByEmployeeId(employeeId);
  var targetCol = findDateColumn(date);

  if (targetRow && targetCol) {
    sheet.getRange(targetRow, targetCol).clearContent();
  } else {
    console.error("削除対象のセルが見つかりませんでした。従業員ID: " + employeeId + ", 日付: " + date);
  }
}

function createShiftChangeRequest(applicantId, targetStartStr, targetEndStr, approverIds) {
  var targetStart = new Date(targetStartStr);
  var targetEnd = new Date(targetEndStr);

  var allShiftsJson = getShifts();
  if (!allShiftsJson) {
    throw new Error("シフト表のデータを取得できませんでした。");
  }
  var allShifts = JSON.parse(allShiftsJson);
  
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
  
  // メール送信処理
  var applicantInfo = findEmployeeById(applicantId, allEmployees);
  var applicantName = applicantInfo ? applicantInfo.display_name : 'ID: ' + applicantId;

  var timeString = Utilities.formatDate(targetStart, "JST", "M月d日 H:mm") + "～" + Utilities.formatDate(targetEnd, "JST", "H:mm");
  
  validApproverIds.forEach(function(approverId) {
    var approverInfo = findEmployeeById(approverId, allEmployees);
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

  return requestId;
}

function approveShiftChange(requestId, approverId) {
  var managementSheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHIFT_MANAGEMENT_SHEET_NAME);
  if (!managementSheet) return;

  var allData = managementSheet.getDataRange().getValues();
  var requestsToUpdate = [];
  var targetRequestInfo = {};

  for (var i = 1; i < allData.length; i++) {
    var currentRow = allData[i];
    if (currentRow[0] === requestId) {
      requestsToUpdate.push({
        rowNum: i + 1,
        approverId: currentRow[2]
      });
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
    var date = targetRequestInfo.start.getDate();
    var timeString = Utilities.formatDate(targetRequestInfo.start, "JST", "H") + "-" + Utilities.formatDate(targetRequestInfo.end, "JST", "H");
    
    deleteShift(targetRequestInfo.applicantId, date);
    updateShift(approverId, date, timeString);
  } else {
    console.error("承認エラー: 対象のリクエスト情報が見つかりません。requestId: " + requestId);
    return;
  }

  // 3. 交代管理シートのステータスを一行ずつ更新する
  requestsToUpdate.forEach(function(req) {
    var newStatus = "";
    if (String(req.approverId) === String(approverId)) {
      newStatus = '承認済み';
    } else {
      newStatus = '締切';
    }
    managementSheet.getRange(req.rowNum, 6).setValue(newStatus);
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
  
}

function denyShiftChange(requestId, denierId) {
  var managementSheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHIFT_MANAGEMENT_SHEET_NAME);
  if (!managementSheet) return;

  var allData = managementSheet.getDataRange().getValues();
  var applicantId = null;
  var allRequestsForTheSameId = [];

  // 1. 該当するリクエストのステータスを「否認済み」に更新しつつ、関連リクエストをすべて集める
  for (var i = 1; i < allData.length; i++) {
    var rowRequestId = allData[i][0];
    if (rowRequestId === requestId) {
      allRequestsForTheSameId.push({
        rowNum: i + 1,
        status: allData[i][5]
      });
      
      if (!applicantId) {
        applicantId = allData[i][1];
      }

      var rowApproverId = allData[i][2];
      if (String(rowApproverId) === String(denierId)) {
        managementSheet.getRange(i + 1, 6).setValue('否認済み');
        allRequestsForTheSameId[allRequestsForTheSameId.length - 1].status = '否認済み';
      }
    }
  }

  var allDenied = allRequestsForTheSameId.every(function(req) {
    return req.status === '否認済み';
  });

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
    }
  }
  
}

function createShiftAdditionRequest(approverId, targetStartStr, targetEndStr) {
  var targetStart = new Date(targetStartStr);
  var targetEnd = new Date(targetEndStr);

  // 依頼相手のスケジュール重複チェック
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

  // スプレッドシートへの記録
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("シフト追加");
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
  
  // 従業員への通知メール送信
  var allEmployees = getEmployees();
  var approverInfo = findEmployeeById(approverId, allEmployees);
  if (approverInfo && approverInfo.email) {
    var timeString = Utilities.formatDate(targetStart, "JST", "M月d日 H:mm") + "～" + Utilities.formatDate(targetEnd, "JST", "H:mm");
    var subject = "【シフト追加のお願い】";
    var body = approverInfo.display_name + "様\n\n" +
               "オーナーより、新しいシフトの追加依頼が届いています。\n\n" +
               "■対象日時\n" + timeString + "\n\n" +
               "以下のリンクから、リクエスト一覧を確認・承認できます。\n" +
               getAppUrl() + "?page=approval";
    MailApp.sendEmail(approverInfo.email, subject, body);
  }
  
  return requestId;
}

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
    
  }
}

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

      return;
    }
  }
}

function getPendingRequestsForUser(employeeId) {
  var changeRequests = getPendingChangeRequestsFor(employeeId);
  var additionRequests = getPendingAdditionRequestsFor(employeeId);
  var allRequests = changeRequests.concat(additionRequests);
  return JSON.stringify(allRequests);
}

/**
 * 指定した従業員宛の「申請中」の【シフト交代】リクエストを取得する。
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
 * 指定した従業員宛の「申請中」の【シフト追加】リクエストを取得する。
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
        type: 'addition',
        requestId:   row[0],
        applicantId: 'オーナー',
        start:       row[2].toISOString(),
        end:         row[3].toISOString()
      });
    }
  });
  return pendingRequests;
}
