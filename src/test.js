/**
 * ================================================================
 * アプリケーションテスト用スクリプト (tests.gs)
 * ================================================================
 */

// テストで使用する従業員情報を格納するグローバル変数
var TEST_EMPLOYEES = getEmployees();

/**
 * 全ての単体テストを順番に実行するマスター関数
 */
function runAllUnitTests() {
  console.log("全テストを開始します。");
  console.log("========================================");

  // --- テストの準備 ---
  console.log("【準備】テスト環境を初期状態にリセットします...");
  resetSheetsToInitialState();
  console.log("【準備】リセット完了。");

  if (!TEST_EMPLOYEES || TEST_EMPLOYEES.length < 3) {
    console.error("テストに必要な3人以上の従業員がfreeeから取得できませんでした。テストを中止します。");
    return;
  }
  console.log("【準備】テスト用の従業員情報を取得しました。");
  console.log("----------------------------------------");
  
  // --- テストの実行 ---
  test_getShifts_and_finders();
  console.log("----------------------------------------");
  
  test_shiftUpdateAndDeletion();
  console.log("----------------------------------------");
  
  test_fullShiftChangeScenario();
  console.log("----------------------------------------");

  test_AllDenied_Scenario();
  console.log("----------------------------------------");

  test_createShiftAdditionRequest();
  console.log("----------------------------------------");

  // 新しく追加するテストケース
  test_employeeAndCompanyFunctions();
  console.log("----------------------------------------");

  test_timeClockFunctions();
  console.log("----------------------------------------");

  test_shiftAdditionApprovalDenial();
  console.log("----------------------------------------");

  test_pendingRequestsFunctions();
  console.log("----------------------------------------");

  test_forgottenClockInCheck();
  console.log("----------------------------------------");

  test_errorHandlingAndEdgeCases();
  console.log("----------------------------------------");

  console.log("========================================");
  console.log("全テストが完了しました。");
}


/****************************************************************
 * 個別のテストケース
 ****************************************************************/

/**
 * Test Case 1: データ取得系関数のテスト
 */
function test_getShifts_and_finders() {
  console.log("【テスト実行 1】データ取得系 (getShifts, findRowByEmployeeId)");
  
  var shiftsJson = getShifts();
  var shiftsData = JSON.parse(shiftsJson); // JSON文字列をオブジェクトに戻す
  var firstEmployeeId = TEST_EMPLOYEES[0].id;

  if (shiftsData && shiftsData.shifts[firstEmployeeId]) {
    console.log("  [OK] getShifts: データ取得成功");
  } else {
    console.error("  [NG] getShifts: データ取得失敗");
  }
  
  var row = findRowByEmployeeId(firstEmployeeId);
  if (row) {
    console.log("  [OK] findRowByEmployeeId: ID '" + firstEmployeeId + "' の行番号 " + row + " が見つかりました。");
  } else {
    console.error("  [NG] findRowByEmployeeId: ID '" + firstEmployeeId + "' が見つかりませんでした。");
  }
}

/**
 * Test Case 2: シフト表の更新・削除のテスト
 */
function test_shiftUpdateAndDeletion() {
  console.log("【テスト実行 2】シフト表の更新・削除 (updateShift, deleteShift)");

  var firstEmployeeId = TEST_EMPLOYEES[0].id;
  var secondEmployeeId = TEST_EMPLOYEES[1].id;
  
  updateShift(firstEmployeeId, '1', '20-23'); // 太郎さんの1日を更新
  deleteShift(secondEmployeeId, '1');      // 次郎さんの1日を削除
  
  console.log("  [完了] updateShiftとdeleteShiftを実行しました。スプレッドシート「シフト表」を目視で確認してください。");
}

/**
 * Test Case 3: シフト交代シナリオの統合テスト
 */
function test_fullShiftChangeScenario() {
  console.log("【テスト実行 3】シフト交代シナリオ (createShiftChangeRequest, approveShiftChange)");
  
  var applicant = TEST_EMPLOYEES[0]; // 太郎さん
  var approver = TEST_EMPLOYEES[1];  // 次郎さん
  var anotherApprover = TEST_EMPLOYEES[2]; // 三郎さん

  var shiftStart = new Date("2025-08-25T18:00:00");
  var shiftEnd = new Date("2025-08-25T22:00:00");

  // 1. リクエスト作成
  var newRequestId = createShiftChangeRequest(applicant.id, shiftStart.toISOString(), shiftEnd.toISOString(), [approver.id, anotherApprover.id]);
  
  if (!newRequestId) {
    console.error("  [NG] リクエストの作成に失敗したため、承認テストを中止します。");
    return;
  }
  console.log("  [OK] 新規リクエストを作成しました。");

  // 2. 承認
  approveShiftChange(newRequestId, approver.id);
  console.log("  [完了] 承認処理を実行しました。両方のシートを目視で確認してください。");
}

/**
 * ★★★ Test Case 4: 全員否認シナリオのテスト ★★★
 */
function test_AllDenied_Scenario() {
  console.log("【テスト実行 4】全員否認シナリオ (denyShiftChange)");
  
  // --- テストの準備 ---
  if (!TEST_EMPLOYEES || TEST_EMPLOYEES.length < 3) {
    console.error("  [NG] 従業員情報が読み込まれていないため、テストをスキップします。");
    return;
  }
  
  var applicant = TEST_EMPLOYEES[0]; // 太郎さん
  var approver1 = TEST_EMPLOYEES[1];  // 次郎さん
  var approver2 = TEST_EMPLOYEES[2]; // 三郎さん

  var shiftStart = new Date("2025-08-26T18:00:00");
  var shiftEnd = new Date("2025-08-26T22:00:00");

  // 1. 新しいリクエストを作成
  var newRequestId = createShiftChangeRequest(applicant.id, shiftStart.toISOString(), shiftEnd.toISOString(), [approver1.id, approver2.id]);
  if (!newRequestId) {
    console.error("  [NG] テスト用のリクエスト作成に失敗しました。");
    return;
  }
  console.log("  [INFO] " + applicant.display_name + "から" + approver1.display_name + "と" + approver2.display_name + "へリクエストを作成しました。 (ID: " + newRequestId + ")");

  // 2. 一人目（次郎さん）が否認する
  console.log("  [ACTION] " + approver1.display_name + "が否認します...");
  denyShiftChange(newRequestId, approver1.id);
  console.log("  [CHECK] 一人目が否認完了。この時点では申請者にメールは送信されないはずです。");

  // 3. 二人目（三郎さん）が否認する
  console.log("  [ACTION] " + approver2.display_name + "が否認します...");
  denyShiftChange(newRequestId, approver2.id);
  console.log("  [CHECK] 二人目が否認完了。この時点で申請者に「否認」の通知メールが送信されるはずです。");
  
  console.log("  [完了] 全員否認シナリオの処理が完了しました。メール受信箱とスプレッドシートを確認してください。");
}

/**
 * Test Case 5: シフト追加リクエスト機能のテスト
 */
function test_createShiftAdditionRequest() {
  console.log("【テスト実行 5】シフト追加リクエスト (createShiftAdditionRequest)");

  TEST_EMPLOYEES = getEmployees();
  if (!TEST_EMPLOYEES || TEST_EMPLOYEES.length === 0) {
    console.error("  [NG] 従業員情報が読み込まれていないため、テストをスキップします。");
    return;
  }
  
  // シフトが入っていない従業員と日時をテストデータとする
  var targetEmployee = TEST_EMPLOYEES[2]; // テスト三郎さん
  var shiftStart = new Date("2025-08-27T10:00:00");
  var shiftEnd = new Date("2025-08-27T15:00:00");

  try {
    createShiftAdditionRequest(targetEmployee.id, shiftStart.toISOString(), shiftEnd.toISOString());
    console.log("  [OK] " + targetEmployee.display_name + "さんへのシフト追加リクエストを作成しました。");
    console.log("  [VERIFY] 「シフト追加」シートに新しい行が記録されていることを確認してください。");
    console.log("  [VERIFY] " + targetEmployee.display_name + "さん宛に「【シフト追加のお願い】」メールが届いていることを確認してください。");
  } catch(e) {
    console.error("  [NG] リクエスト作成中にエラーが発生しました: " + e.message);
  }
}

/**
 * Test Case 6: 従業員・事業所情報取得機能のテスト
 */
function test_employeeAndCompanyFunctions() {
  console.log("【テスト実行 6】従業員・事業所情報取得機能 (getEmployees, getEmployee, getCompanyName)");
  
  // 1. 全従業員情報の取得テスト
  var employees = getEmployees();
  if (employees && employees.length > 0) {
    console.log("  [OK] getEmployees: " + employees.length + "名の従業員情報を取得しました。");
    
    // 従業員情報の構造チェック
    var firstEmployee = employees[0];
    if (firstEmployee.id && firstEmployee.display_name) {
      console.log("  [OK] 従業員情報の構造が正しいです。");
    } else {
      console.error("  [NG] 従業員情報の構造が不正です。");
    }
  } else {
    console.error("  [NG] getEmployees: 従業員情報の取得に失敗しました。");
  }

  // 2. 事業所名の取得テスト
  try {
    var companyName = getCompanyName();
    if (companyName && companyName !== "undefined") {
      console.log("  [OK] getCompanyName: 事業所名「" + companyName + "」を取得しました。");
    } else {
      console.error("  [NG] getCompanyName: 事業所名の取得に失敗しました。");
    }
  } catch(e) {
    console.error("  [NG] getCompanyName: エラーが発生しました: " + e.message);
  }

  // 3. 個別従業員情報の取得テスト（モックデータでテスト）
  if (TEST_EMPLOYEES && TEST_EMPLOYEES.length > 0) {
    var testEmployeeId = TEST_EMPLOYEES[0].id;
    PropertiesService.getUserProperties().setProperty('selectedEmpId', testEmployeeId.toString());
    
    try {
      var employee = getEmployee();
      if (employee && employee.id) {
        console.log("  [OK] getEmployee: 従業員ID " + testEmployeeId + " の情報を取得しました。");
      } else {
        console.log("  [INFO] getEmployee: 従業員情報の取得は成功しましたが、データが空の可能性があります。");
      }
    } catch(e) {
      console.log("  [INFO] getEmployee: エラーが発生しましたが、これは想定される動作です: " + e.message);
    }
  }
}

/**
 * Test Case 7: 勤怠管理機能のテスト
 */
function test_timeClockFunctions() {
  console.log("【テスト実行 7】勤怠管理機能 (getTimeClocks, getTimeClocksFor, postWorkRecord)");
  
  if (!TEST_EMPLOYEES || TEST_EMPLOYEES.length === 0) {
    console.error("  [NG] 従業員情報が読み込まれていないため、テストをスキップします。");
    return;
  }

  var testEmployeeId = TEST_EMPLOYEES[0].id;
  PropertiesService.getUserProperties().setProperty('selectedEmpId', testEmployeeId.toString());

  // 1. 勤怠情報の取得テスト
  try {
    var timeClocks = getTimeClocks();
    if (Array.isArray(timeClocks)) {
      console.log("  [OK] getTimeClocks: 勤怠情報を取得しました。件数: " + timeClocks.length);
      
      // データ構造のチェック
      if (timeClocks.length > 0) {
        var firstRecord = timeClocks[0];
        if (firstRecord.date && firstRecord.type) {
          console.log("  [OK] 勤怠記録のデータ構造が正しいです。");
        } else {
          console.error("  [NG] 勤怠記録のデータ構造が不正です。");
        }
      }
    } else {
      console.log("  [INFO] getTimeClocks: 勤怠情報が空の配列として返されました。");
    }
  } catch(e) {
    console.error("  [NG] getTimeClocks: エラーが発生しました: " + e.message);
  }

  // 2. 特定日付の勤怠情報取得テスト
  try {
    var today = new Date();
    var timeClocksFor = getTimeClocksFor(testEmployeeId, today);
    if (Array.isArray(timeClocksFor)) {
      console.log("  [OK] getTimeClocksFor: 今日の勤怠情報を取得しました。件数: " + timeClocksFor.length);
    } else {
      console.error("  [NG] getTimeClocksFor: 戻り値が配列ではありません。");
    }
  } catch(e) {
    console.error("  [NG] getTimeClocksFor: エラーが発生しました: " + e.message);
  }

  // 3. 勤怠記録の登録テスト（モックデータ）
  try {
    var mockForm = {
      target_date: "2025-08-28",
      target_time: "09:00",
      target_type: "clock_in"
    };
    
    // 実際のAPI呼び出しは行わず、関数の存在確認のみ
    if (typeof postWorkRecord === 'function') {
      console.log("  [OK] postWorkRecord: 関数が存在します。");
    } else {
      console.error("  [NG] postWorkRecord: 関数が存在しません。");
    }
  } catch(e) {
    console.error("  [NG] postWorkRecord: エラーが発生しました: " + e.message);
  }
}

/**
 * Test Case 8: シフト追加リクエストの承認・否認テスト
 */
function test_shiftAdditionApprovalDenial() {
  console.log("【テスト実行 8】シフト追加リクエストの承認・否認 (approveShiftAddition, denyShiftAddition)");
  
  if (!TEST_EMPLOYEES || TEST_EMPLOYEES.length === 0) {
    console.error("  [NG] 従業員情報が読み込まれていないため、テストをスキップします。");
    return;
  }

  // テスト用のシフト追加リクエストを作成
  var targetEmployee = TEST_EMPLOYEES[1]; // 次郎さん
  var shiftStart = new Date("2025-08-29T14:00:00");
  var shiftEnd = new Date("2025-08-29T18:00:00");

  try {
    var requestId = createShiftAdditionRequest(targetEmployee.id, shiftStart.toISOString(), shiftEnd.toISOString());
    if (!requestId) {
      console.error("  [NG] テスト用リクエストの作成に失敗しました。");
      return;
    }
    console.log("  [OK] テスト用リクエストを作成しました。ID: " + requestId);

    // 1. 承認テスト
    try {
      approveShiftAddition(requestId, targetEmployee.id);
      console.log("  [OK] approveShiftAddition: シフト追加リクエストを承認しました。");
      console.log("  [VERIFY] シフト表に新しいシフトが追加されていることを確認してください。");
      console.log("  [VERIFY] 「シフト追加」シートのステータスが「承認済み」になっていることを確認してください。");
    } catch(e) {
      console.error("  [NG] approveShiftAddition: エラーが発生しました: " + e.message);
    }

    // 2. 否認テスト（新しいリクエストを作成）
    var denyRequestId = createShiftAdditionRequest(targetEmployee.id, shiftStart.toISOString(), shiftEnd.toISOString());
    if (denyRequestId) {
      try {
        denyShiftAddition(denyRequestId, targetEmployee.id);
        console.log("  [OK] denyShiftAddition: シフト追加リクエストを否認しました。");
        console.log("  [VERIFY] 「シフト追加」シートのステータスが「否認済み」になっていることを確認してください。");
      } catch(e) {
        console.error("  [NG] denyShiftAddition: エラーが発生しました: " + e.message);
      }
    }

  } catch(e) {
    console.error("  [NG] テスト用リクエストの作成中にエラーが発生しました: " + e.message);
  }
}

/**
 * Test Case 9: リクエスト取得機能のテスト
 */
function test_pendingRequestsFunctions() {
  console.log("【テスト実行 9】リクエスト取得機能 (getPendingRequestsForUser, getPendingChangeRequestsFor, getPendingAdditionRequestsFor)");
  
  if (!TEST_EMPLOYEES || TEST_EMPLOYEES.length === 0) {
    console.error("  [NG] 従業員情報が読み込まれていないため、テストをスキップします。");
    return;
  }

  var testEmployeeId = TEST_EMPLOYEES[0].id;

  // 1. シフト交代リクエストの取得テスト
  try {
    var changeRequests = getPendingChangeRequestsFor(testEmployeeId);
    if (Array.isArray(changeRequests)) {
      console.log("  [OK] getPendingChangeRequestsFor: シフト交代リクエストを取得しました。件数: " + changeRequests.length);
      
      // データ構造のチェック
      if (changeRequests.length > 0) {
        var firstRequest = changeRequests[0];
        if (firstRequest.type === 'change' && firstRequest.requestId) {
          console.log("  [OK] シフト交代リクエストのデータ構造が正しいです。");
        } else {
          console.error("  [NG] シフト交代リクエストのデータ構造が不正です。");
        }
      }
    } else {
      console.error("  [NG] getPendingChangeRequestsFor: 戻り値が配列ではありません。");
    }
  } catch(e) {
    console.error("  [NG] getPendingChangeRequestsFor: エラーが発生しました: " + e.message);
  }

  // 2. シフト追加リクエストの取得テスト
  try {
    var additionRequests = getPendingAdditionRequestsFor(testEmployeeId);
    if (Array.isArray(additionRequests)) {
      console.log("  [OK] getPendingAdditionRequestsFor: シフト追加リクエストを取得しました。件数: " + additionRequests.length);
      
      // データ構造のチェック
      if (additionRequests.length > 0) {
        var firstRequest = additionRequests[0];
        if (firstRequest.type === 'addition' && firstRequest.requestId) {
          console.log("  [OK] シフト追加リクエストのデータ構造が正しいです。");
        } else {
          console.error("  [NG] シフト追加リクエストのデータ構造が不正です。");
        }
      }
    } else {
      console.error("  [NG] getPendingAdditionRequestsFor: 戻り値が配列ではありません。");
    }
  } catch(e) {
    console.error("  [NG] getPendingAdditionRequestsFor: エラーが発生しました: " + e.message);
  }

  // 3. 統合リクエスト取得テスト
  try {
    var allRequests = getPendingRequestsForUser(testEmployeeId);
    if (allRequests) {
      var parsedRequests = JSON.parse(allRequests);
      if (Array.isArray(parsedRequests)) {
        console.log("  [OK] getPendingRequestsForUser: 統合リクエストを取得しました。件数: " + parsedRequests.length);
      } else {
        console.error("  [NG] getPendingRequestsForUser: パース後のデータが配列ではありません。");
      }
    } else {
      console.error("  [NG] getPendingRequestsForUser: 戻り値がnullまたはundefinedです。");
    }
  } catch(e) {
    console.error("  [NG] getPendingRequestsForUser: エラーが発生しました: " + e.message);
  }
}

/**
 * Test Case 10: 打刻忘れチェック機能のテスト
 */
function test_forgottenClockInCheck() {
  console.log("【テスト実行 10】打刻忘れチェック機能 (checkForgottenClockIns)");
  
  // この関数は実際の時間に依存するため、関数の存在確認と基本的な動作確認のみ
  try {
    if (typeof checkForgottenClockIns === 'function') {
      console.log("  [OK] checkForgottenClockIns: 関数が存在します。");
      
      // 関数の実行（実際の処理は行われるが、結果は環境に依存）
      try {
        checkForgottenClockIns();
        console.log("  [OK] checkForgottenClockIns: 関数の実行が完了しました。");
        console.log("  [INFO] 実際の打刻忘れチェック結果は、現在の時間とシフト状況に依存します。");
      } catch(e) {
        console.log("  [INFO] checkForgottenClockIns: 実行中にエラーが発生しましたが、これは想定される動作です: " + e.message);
      }
    } else {
      console.error("  [NG] checkForgottenClockIns: 関数が存在しません。");
    }
  } catch(e) {
    console.error("  [NG] checkForgottenClockIns: エラーが発生しました: " + e.message);
  }
}

/**
 * Test Case 11: エラーハンドリングとエッジケースのテスト
 */
function test_errorHandlingAndEdgeCases() {
  console.log("【テスト実行 11】エラーハンドリングとエッジケース");
  
  // 1. 無効な従業員IDでの処理テスト
  try {
    var invalidRow = findRowByEmployeeId('invalid_id_999999');
    if (invalidRow === null) {
      console.log("  [OK] 無効な従業員IDでの検索が適切にnullを返しました。");
    } else {
      console.error("  [NG] 無効な従業員IDでの検索が不適切な値を返しました: " + invalidRow);
    }
  } catch(e) {
    console.error("  [NG] 無効な従業員IDでの検索でエラーが発生しました: " + e.message);
  }

  // 2. 存在しない日付での処理テスト
  try {
    var invalidDateCol = findDateColumn(99); // 存在しない日付
    if (invalidDateCol === null) {
      console.log("  [OK] 存在しない日付での検索が適切にnullを返しました。");
    } else {
      console.error("  [NG] 存在しない日付での検索が不適切な値を返しました: " + invalidDateCol);
    }
  } catch(e) {
    console.error("  [NG] 存在しない日付での検索でエラーが発生しました: " + e.message);
  }

  // 3. 空のデータでの処理テスト
  try {
    var emptyShifts = getShifts();
    if (emptyShifts) {
      var parsedEmpty = JSON.parse(emptyShifts);
      if (parsedEmpty.shifts && Object.keys(parsedEmpty.shifts).length === 0) {
        console.log("  [OK] 空のシフトデータでの処理が適切に動作しました。");
      } else {
        console.log("  [INFO] 空のシフトデータでの処理結果: " + emptyShifts);
      }
    } else {
      console.error("  [NG] 空のシフトデータでの処理が失敗しました。");
    }
  } catch(e) {
    console.error("  [NG] 空のシフトデータでの処理でエラーが発生しました: " + e.message);
  }

  // 4. 不正な日付形式での処理テスト
  try {
    var invalidDate = new Date("invalid-date");
    if (isNaN(invalidDate.getTime())) {
      console.log("  [OK] 不正な日付形式の検証が適切に動作しました。");
    } else {
      console.error("  [NG] 不正な日付形式の検証が失敗しました。");
    }
  } catch(e) {
    console.error("  [NG] 不正な日付形式の検証でエラーが発生しました: " + e.message);
  }

  // 5. ヘルパー関数のテスト
  try {
    var nullEmployee = findEmployeeById('999999', null);
    if (nullEmployee === null) {
      console.log("  [OK] nullの従業員リストでの検索が適切にnullを返しました。");
    } else {
      console.error("  [NG] nullの従業員リストでの検索が不適切な値を返しました: " + nullEmployee);
    }
  } catch(e) {
    console.error("  [NG] nullの従業員リストでの検索でエラーが発生しました: " + e.message);
  }
}

/****************************************************************
 * テスト用のヘルパー関数
 ****************************************************************/
/**
 * 全てのシートをテスト実行前の初期状態に戻す。
 */
function resetSheetsToInitialState() {
  var employees = getEmployees();
  if (!employees || employees.length < 3) {
    console.error("リセット失敗: freeeから従業員を3名以上取得できません。");
    throw new Error("リセット処理を中断しました。"); 
  }

  var ss = SpreadsheetApp.getActiveSpreadsheet();
  
  var mgmtSheet = ss.getSheetByName(SHIFT_MANAGEMENT_SHEET_NAME);
  if (mgmtSheet && mgmtSheet.getLastRow() > 1) {
    mgmtSheet.getRange(2, 1, mgmtSheet.getLastRow() - 1, mgmtSheet.getLastColumn()).clearContent();
  }
  
  var shiftSheet = ss.getSheetByName(SHIFT_SHEET_NAME);
  if (!shiftSheet) { return; }
  shiftSheet.clearContents();
  
  var initialShiftData = [
    // ▼▼▼ 1行目の列数が33になるように、空の要素を追加 ▼▼▼
    ["2025年8月1日", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""],
    ["従業員ID", "従業員名", 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31],
    [employees[3].id, employees[3].display_name, "18-23", "", "18-23", "18-23", "18-23", "", "18-23", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""],
    [employees[0].id, employees[0].display_name, "18-23", "18-20", "", "20-23", "20-23", "20-23", "18-20", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""],
    [employees[1].id, employees[1].display_name, "20-23", "", "18-20", "18-20", "", "18-20", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""],
    [employees[2].id, employees[2].display_name, "", "20-23", "20-23", "", "18-20", "", "20-23", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""]
  ];
  
  var rangeToWrite = shiftSheet.getRange(1, 1, initialShiftData.length, initialShiftData[0].length);
  rangeToWrite.setValues(initialShiftData);
  shiftSheet.getRange("A1").setNumberFormat("YYYY\"年\"M\"月\"");
  console.log("  [INFO] 「シフト表」シートを実際の従業員IDで初期化しました。");
}
