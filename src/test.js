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
 * Test Case: シフト追加リクエスト機能のテスト
 */
function test_createShiftAdditionRequest() {
  console.log("【テスト実行】シフト追加リクエスト (createShiftAdditionRequest)");

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
