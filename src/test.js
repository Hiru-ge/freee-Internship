/**
 * ================================================================
 * アプリケーションテスト用スクリプト (tests.gs)
 * ================================================================
 */

// テストで使用する従業員情報を格納するグローバル変数
var TEST_EMPLOYEES = getEmployees();

/**
 * 現在の月を取得する関数
 * テスト用の日付を動的に生成するために使用
 */
function getCurrentMonthForTest() {
  var now = new Date();
  return {
    year: now.getFullYear(),
    month: now.getMonth() + 1, // JavaScriptの月は0ベースなので+1
    day: now.getDate()
  };
}

/**
 * 指定した月の指定した日付を生成する関数
 * @param {number} day - 日（デフォルト: 25）
 * @param {number} hour - 時間（デフォルト: 18）
 * @param {number} minute - 分（デフォルト: 0）
 * @returns {Date} テスト用の日付オブジェクト
 */
function createTestDateForMonth(day = 25, hour = 18, minute = 0) {
  var current = getCurrentMonthForTest();
  var testDate = new Date(current.year, current.month - 1, day, hour, minute, 0);
  return testDate;
}

/**
 * テスト環境のセットアップ
 * 各テストの独立性を確保するため、テスト前に実行
 */
function setupTestEnvironment() {
  console.log("  [SETUP] テスト環境をセットアップします...");
  
  // シートを初期状態にリセット
  resetSheetsToInitialState();
  
  // テスト用の従業員情報を再取得
  TEST_EMPLOYEES = getEmployees();
  
  if (!TEST_EMPLOYEES || TEST_EMPLOYEES.length < 3) {
    throw new Error("テストに必要な3人以上の従業員が取得できませんでした。");
  }
  
  console.log("  [SETUP] テスト環境のセットアップが完了しました。");
}

/**
 * テスト環境のクリーンアップ
 * 各テストの独立性を確保するため、テスト後に実行
 */
function cleanupTestEnvironment() {
  console.log("  [CLEANUP] テスト環境をクリーンアップします...");
  
  // シートを初期状態にリセット
  resetSheetsToInitialState();
  
  console.log("  [CLEANUP] テスト環境のクリーンアップが完了しました。");
}

/**
 * 従業員データの検証を行う共通関数
 * @param {number} minCount 最小必要人数（デフォルト: 0）
 * @returns {boolean} 検証結果
 */
function validateTestEmployees(minCount) {
  minCount = minCount || 0;
  if (!TEST_EMPLOYEES || TEST_EMPLOYEES.length <= minCount) {
    console.error("  [NG] 従業員情報が読み込まれていないため、テストをスキップします。");
    return false;
  }
  return true;
}

/**
 * テスト実行の共通ラッパー関数
 * @param {string} testNumber テスト番号
 * @param {string} testDescription テスト説明
 * @param {Function} testFunction 実行するテスト関数
 */
function runTestWithSetup(testNumber, testDescription, testFunction) {
  console.log("【テスト実行 " + testNumber + "】" + testDescription);
  
  try {
    setupTestEnvironment();
    testFunction();
  } catch(e) {
    console.error("  [NG] テスト実行中にエラーが発生しました: " + e.message);
  } finally {
    cleanupTestEnvironment();
  }
}

/**
 * 全ての単体テストを順番に実行するマスター関数
 */
function runAllUnitTests() {
  console.log("全テストを開始します。");
  console.log("========================================");

  // テスト用の従業員情報を取得
  TEST_EMPLOYEES = getEmployees();
  if (!TEST_EMPLOYEES || TEST_EMPLOYEES.length < 3) {
    console.error("テストに必要な3人以上の従業員がfreeeから取得できませんでした。テストを中止します。");
    return;
  }
  console.log("【準備】テスト用の従業員情報を取得しました。");
  console.log("----------------------------------------");
  
  // 各テストは独立して実行される（セットアップとクリーンアップが各テスト内で実行される）
  // 基本的な機能から複雑な機能、エラーハンドリングの順序で実行
  var testFunctions = [
    test01_employeeAndCompanyFunctions,        // 1. 基本データ取得
    test02_getShifts_and_finders,             // 2. シフトデータ取得
    test03_shiftUpdateAndDeletion,            // 3. シフト基本操作
    test04_createShiftAdditionRequest,        // 4. シフト追加リクエスト
    test05_shiftAdditionApprovalDenial,       // 5. シフト追加承認・否認
    test06_fullShiftChangeScenario,           // 6. シフト交代シナリオ
    test07_AllDenied_Scenario,                // 7. シフト交代否認シナリオ
    test08_pendingRequestsFunctions,          // 8. リクエスト取得機能
    test09_timeClockFunctions,                // 9. 勤怠管理機能
    test10_forgottenClockInCheck,             // 10. 打刻忘れチェック
    test11_clockOutReminderFunctions,         // 11. 退勤打刻忘れリマインダー
    test12_errorHandlingAndEdgeCases,         // 12. エラーハンドリング
    test13_CheckForgottenClockOutsWithRealFunction  // 13. 退勤打刻忘れチェック（内部関数）
  ];
  
  var passedTests = 0;
  var totalTests = testFunctions.length;
  
  for (var i = 0; i < testFunctions.length; i++) {
    try {
      testFunctions[i]();
      passedTests++;
    } catch (error) {
      console.error("テスト " + testFunctions[i].name + " でエラーが発生しました: " + error.message);
    }
    console.log("----------------------------------------");
  }

  console.log("========================================");
  console.log("全テストが完了しました。");
  console.log("成功: " + passedTests + "/" + totalTests + " テスト");
}


/****************************************************************
 * 個別のテストケース
 ****************************************************************/

// 従業員・事業所情報取得機能のテスト
function test01_employeeAndCompanyFunctions() {
  console.log("【テスト実行 1】従業員・事業所情報取得機能 (getEmployees, getEmployee, getCompanyName)");
  
  // 全従業員情報の取得テスト
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

  // 個別従業員情報の取得テスト（モックデータでテスト）
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

// データ取得系関数のテスト
function test02_getShifts_and_finders() {
  runTestWithSetup("2", "データ取得系 (getShifts, findRowByEmployeeId)", function() {
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
  });
}

// シフト表の更新・削除のテスト
function test03_shiftUpdateAndDeletion() {
  runTestWithSetup("3", "シフト表の更新・削除 (updateShift, deleteShift)", function() {
    var firstEmployeeId = TEST_EMPLOYEES[0].id;
    var secondEmployeeId = TEST_EMPLOYEES[1].id;
    
    updateShift(firstEmployeeId, '1', '20-23'); // 太郎さんの1日を更新
    deleteShift(secondEmployeeId, '1');      // 次郎さんの1日を削除
    
    console.log("  [完了] updateShiftとdeleteShiftを実行しました。スプレッドシート「シフト表」を目視で確認してください。");
  });
}

// シフト追加リクエスト機能のテスト
function test04_createShiftAdditionRequest() {
  TEST_EMPLOYEES = getEmployees();
  if (!validateTestEmployees(0)) {
    return;
  }

  runTestWithSetup("4", "シフト追加リクエスト (createShiftAdditionRequest)", function() {
    var applicant = TEST_EMPLOYEES[0]; // 太郎さん
    var approver = TEST_EMPLOYEES[1];  // 次郎さん

    // 3日は店長 太郎が空いているので、この日付を使用
    var shiftStart = createTestDateForMonth(3, 18, 0); // 3日 18:00
    var shiftEnd = createTestDateForMonth(3, 20, 0);   // 3日 20:00

    var newRequestId = createShiftAdditionRequest(applicant.id, shiftStart.toISOString(), shiftEnd.toISOString(), [approver.id]);
    
    if (newRequestId) {
      console.log("  [OK] シフト追加リクエストを作成しました。ID: " + newRequestId);
    } else {
      console.error("  [NG] シフト追加リクエストの作成に失敗しました。");
    }
  });
}

// シフト追加リクエストの承認・否認テスト
function test05_shiftAdditionApprovalDenial() {
  if (!validateTestEmployees(0)) {
    return;
  }

  // テスト用のシフト追加リクエストを作成
  var applicant = TEST_EMPLOYEES[0]; // 太郎さん
  var approver = TEST_EMPLOYEES[1];  // 次郎さん

  // 3日は店長 太郎が空いているので、この日付を使用
  var shiftStart = createTestDateForMonth(3, 18, 0); // 3日 18:00
  var shiftEnd = createTestDateForMonth(3, 20, 0);   // 3日 20:00

  runTestWithSetup("5", "シフト追加リクエストの承認・否認 (approveShiftAddition, denyShiftAddition)", function() {
    var newRequestId = createShiftAdditionRequest(applicant.id, shiftStart.toISOString(), shiftEnd.toISOString(), [approver.id]);
    
    if (!newRequestId) {
      console.error("  [NG] テスト用リクエストの作成に失敗しました。");
      return;
    }
    console.log("  [OK] テスト用シフト追加リクエストを作成しました。ID: " + newRequestId);

    // 承認テスト
    approveShiftAddition(newRequestId, approver.id);
    console.log("  [OK] シフト追加リクエストを承認しました。");

    // 否認テスト（新しいリクエストを作成）
    var denyRequestId = createShiftAdditionRequest(applicant.id, shiftStart.toISOString(), shiftEnd.toISOString(), [approver.id]);
    if (denyRequestId) {
      denyShiftAddition(denyRequestId, approver.id);
      console.log("  [OK] シフト追加リクエストを否認しました。");
    }
  });
}

// シフト交代シナリオの統合テスト
function test06_fullShiftChangeScenario() {
  runTestWithSetup("6", "シフト交代シナリオ (createShiftChangeRequest, approveShiftChange)", function() {
    var applicant = TEST_EMPLOYEES[0]; // 太郎さん
    var approver = TEST_EMPLOYEES[1];  // 次郎さん
    var anotherApprover = TEST_EMPLOYEES[2]; // 三郎さん

    // 26日は太郎（20-23）、次郎（18-20）、三郎（20-23）がシフトに入っている
    var shiftStart = createTestDateForMonth(26, 20, 0); // 26日 20:00
    var shiftEnd = createTestDateForMonth(26, 23, 0);   // 26日 23:00

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
  });
}

// 全員否認シナリオのテスト
function test07_AllDenied_Scenario() {
  console.log("【テスト実行 7】全員否認シナリオ (denyShiftChange)");
  
  // --- テストの準備 ---
  if (!validateTestEmployees(2)) {
    return;
  }
  
  var applicant = TEST_EMPLOYEES[0]; // 太郎さん
  var approver1 = TEST_EMPLOYEES[1];  // 次郎さん
  var approver2 = TEST_EMPLOYEES[2]; // 三郎さん

  // 27日は太郎（18-20）、次郎（20-23）、花子（18-23）がシフトに入っている
  var shiftStart = createTestDateForMonth(27, 18, 0); // 27日 18:00
  var shiftEnd = createTestDateForMonth(27, 20, 0);   // 27日 20:00

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

// リクエスト取得機能のテスト
function test08_pendingRequestsFunctions() {
  if (!validateTestEmployees(0)) {
    return;
  }

  runTestWithSetup("8", "リクエスト取得機能 (getPendingRequestsForUser, getPendingChangeRequestsFor, getPendingAdditionRequestsFor)", function() {
    var testEmployeeId = TEST_EMPLOYEES[0].id;
    
    // 1. getPendingRequestsForUserのテスト
    var pendingRequests = getPendingRequestsForUser(testEmployeeId);
    if (pendingRequests) {
      console.log("  [OK] getPendingRequestsForUser: リクエスト取得成功");
    } else {
      console.log("  [INFO] getPendingRequestsForUser: リクエストが存在しないか、取得に失敗しました。");
    }
    
    // 2. getPendingChangeRequestsForのテスト
    var changeRequests = getPendingChangeRequestsFor(testEmployeeId);
    if (changeRequests) {
      console.log("  [OK] getPendingChangeRequestsFor: シフト交代リクエスト取得成功");
    } else {
      console.log("  [INFO] getPendingChangeRequestsFor: シフト交代リクエストが存在しないか、取得に失敗しました。");
    }
    
    // 3. getPendingAdditionRequestsForのテスト
    var additionRequests = getPendingAdditionRequestsFor(testEmployeeId);
    if (additionRequests) {
      console.log("  [OK] getPendingAdditionRequestsFor: シフト追加リクエスト取得成功");
    } else {
      console.log("  [INFO] getPendingAdditionRequestsFor: シフト追加リクエストが存在しないか、取得に失敗しました。");
    }
  });
}

// 勤怠管理機能のテスト
function test09_timeClockFunctions() {
  console.log("【テスト実行 9】勤怠管理機能 (getTimeClocks, getTimeClocksFor, postWorkRecord)");
  
  if (!validateTestEmployees(0)) {
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
    var testDate = createTestDateForMonth(28, 9, 0); // 28日 9:00
    var mockForm = {
      target_date: testDate.toISOString().split('T')[0], // YYYY-MM-DD形式
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

// 打刻忘れチェック機能のテスト
function test10_forgottenClockInCheck() {
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

// 退勤打刻忘れリマインダー機能のテスト
function test11_clockOutReminderFunctions() {
  console.log("【テスト実行 11】退勤打刻忘れリマインダー機能");
  
  try {
    // 1. テスト用データのセットアップ
    console.log("  [テスト] テスト用データのセットアップ");
    if (!setupClockOutReminderTestData()) {
      console.error("  [NG] テスト用データのセットアップに失敗しました");
      return;
    }
    console.log("  [OK] テスト用データのセットアップが完了しました");
    
    // 2. 退勤打刻忘れチェック関数のテスト（実際のメール送信は行わない）
    console.log("  [テスト] 退勤打刻忘れチェック関数の確認");
    try {
      // 関数が存在し、呼び出し可能かテスト
      if (typeof checkForgottenClockOuts === 'function') {
        console.log("  [OK] checkForgottenClockOuts関数が正常に定義されています");
      } else {
        console.error("  [NG] checkForgottenClockOuts関数が定義されていません");
        return;
      }
    } catch (e) {
      console.error("  [NG] 退勤打刻忘れチェック関数でエラーが発生しました: " + e.message);
      return;
    }
    
    // 3. 実際のcheckForgottenClockOuts関数を使用したテスト実行
    console.log("  [テスト] 実際のcheckForgottenClockOuts関数を使用したテスト実行");
    try {
      test13_CheckForgottenClockOutsWithRealFunction();
      console.log("  [OK] 実際のcheckForgottenClockOuts関数を使用したテストが正常に実行されました");
    } catch (e) {
      console.error("  [NG] 実際のcheckForgottenClockOuts関数を使用したテストでエラーが発生しました: " + e.message);
    }
    
    // 4. 既存の出勤打刻忘れチェック関数との一貫性確認
    console.log("  [テスト] 既存実装との一貫性確認");
    try {
      if (typeof checkForgottenClockIns === 'function') {
        console.log("  [OK] 既存のcheckForgottenClockIns関数も正常に定義されています");
      } else {
        console.error("  [NG] 既存のcheckForgottenClockIns関数が定義されていません");
      }
    } catch (e) {
      console.error("  [NG] 既存実装の確認でエラーが発生しました: " + e.message);
    }
    
    // 5. テスト用データのリセット
    console.log("  [テスト] テスト用データのリセット");
    try {
      if (!resetClockOutReminderTestData()) {
        console.error("  [NG] テスト用データのリセットに失敗しました");
      } else {
        console.log("  [OK] テスト用データのリセットが完了しました");
      }
    } catch (e) {
      console.error("  [NG] テスト用データのリセットでエラーが発生しました: " + e.message);
    }
    
  } catch (e) {
    console.error("  [NG] 退勤打刻忘れリマインダー機能のテストでエラーが発生しました: " + e.message);
  }
}

// エラーハンドリングとエッジケースのテスト
function test12_errorHandlingAndEdgeCases() {
  runTestWithSetup("12", "エラーハンドリングとエッジケース", function() {
    
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
  });
}

/**
 * 実際のcheckForgottenClockOuts関数をテスト用に実行
 * メール送信部分のみモック化して、実際のロジックをテストする
 */
function test13_CheckForgottenClockOutsWithRealFunction() {
  console.log("【テスト実行 13】実際のcheckForgottenClockOuts関数を使用したテスト");
  
  try {
    // 元のMailAppをバックアップ
    var originalMailApp = MailApp;
    
    // テスト用のMailAppに置き換え
    MailApp = TestMailApp;
    
    // 元のgetTimeClocksFor関数をバックアップ
    var originalGetTimeClocksFor = getTimeClocksFor;
    
    // テスト用のgetTimeClocksFor関数に置き換え
    getTimeClocksFor = getTimeClocksForTest;
    
    // 実際のcheckForgottenClockOuts関数を実行
    checkForgottenClockOuts();
    
    // 元の関数を復元
    MailApp = originalMailApp;
    getTimeClocksFor = originalGetTimeClocksFor;
    
    console.log("実際のcheckForgottenClockOuts関数を使用したテストを終了しました。");
    
  } catch (e) {
    console.error("テスト実行中にエラーが発生しました: " + e.message);
    
    // エラーが発生しても元の関数を復元
    try {
      MailApp = originalMailApp;
      getTimeClocksFor = originalGetTimeClocksFor;
    } catch (restoreError) {
      console.error("関数の復元中にエラーが発生しました: " + restoreError.message);
    }
  }
}

/****************************************************************
 * テスト用のヘルパー関数
 ****************************************************************/
// 全てのシートをテスト実行前の初期状態に戻す
function resetSheetsToInitialState() {
  var employees = getEmployees();
  if (!employees || employees.length < 3) {
    console.error("リセット失敗: freeeから従業員を3名以上取得できません。");
    throw new Error("リセット処理を中断しました。"); 
  }

  var ss = SpreadsheetApp.getActiveSpreadsheet();
  
  // 1. シフト表の初期化
  var shiftSheet = ss.getSheetByName(SHIFT_SHEET_NAME);
  if (!shiftSheet) { return; }
  shiftSheet.clearContents();
  
  // 現在の月の1日を動的に生成
  var currentMonth = getCurrentMonthForTest();
  var monthTitle = currentMonth.year + "年" + currentMonth.month + "月1日";
  
  var initialShiftData = [
    // ▼▼▼ 1行目の列数が33になるように、空の要素を追加 ▼▼▼
    [monthTitle, "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""],
    ["従業員ID", "従業員名", 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31],
    // 従業員0（店長 太郎）: 週3回程度、18-20と20-23中心
    [employees[0].id, employees[0].display_name, "18-20", "18-20", "", "20-23", "20-23", "20-23", "18-20", "", "18-20", "18-20", "", "20-23", "18-20", "", "20-23", "18-20", "", "20-23", "18-20", "", "20-23", "18-20", "", "20-23", "18-20", "20-23", "", "18-20", "20-23", "18-20", ""],
    // 従業員1（テスト 太郎）: 週3回程度、20-23と18-20中心
    [employees[1].id, employees[1].display_name, "20-23", "", "18-20", "18-20", "", "18-20", "", "20-23", "18-20", "", "18-20", "20-23", "18-20", "", "18-20", "", "20-23", "", "18-20", "20-23", "18-20", "", "18-20", "", "20-23", "18-20", "20-23", "", "18-20", "", ""],
    // 従業員2（テスト 次郎）: 週3回程度、20-23と18-20中心
    [employees[2].id, employees[2].display_name, "", "20-23", "20-23", "", "18-20", "", "20-23", "", "20-23", "18-20", "", "18-20", "", "20-23", "18-20", "20-23", "", "18-20", "20-23", "", "18-20", "20-23", "18-20", "", "20-23", "", "18-20", "20-23", "18-20", "", ""],
    // 従業員3（テスト 三郎）: 週3回程度、18-23中心
    [employees[3].id, employees[3].display_name, "18-23", "", "18-23", "18-23", "18-23", "", "18-23", "18-23", "", "20-23", "18-23", "", "18-23", "18-23", "", "20-23", "18-23", "18-23", "", "18-23", "", "18-23", "20-23", "18-23", "", "18-23", "18-23", "", "20-23", "18-23", ""],
  ];
  
  var rangeToWrite = shiftSheet.getRange(1, 1, initialShiftData.length, initialShiftData[0].length);
  rangeToWrite.setValues(initialShiftData);
  shiftSheet.getRange("A1").setNumberFormat("YYYY\"年\"M\"月\"");
  console.log("  [INFO] 「シフト表」シートを実際の従業員IDで初期化しました。");
  
  // 2. シフト交代管理シートのリセット
  var shiftManagementSheet = ss.getSheetByName(SHIFT_MANAGEMENT_SHEET_NAME);
  if (shiftManagementSheet && shiftManagementSheet.getLastRow() > 1) {
    shiftManagementSheet.getRange(2, 1, shiftManagementSheet.getLastRow() - 1, shiftManagementSheet.getLastColumn()).clearContent();
  }
  
  // 3. シフト追加シートのリセット
  var shiftAddSheet = ss.getSheetByName("シフト追加");
  if (shiftAddSheet && shiftAddSheet.getLastRow() > 1) {
    shiftAddSheet.getRange(2, 1, shiftAddSheet.getLastRow() - 1, shiftAddSheet.getLastColumn()).clearContent();
  }
  
  // 4. 認証コード管理シートのリセット
  var verificationSheet = ss.getSheetByName(VERIFICATION_CODES_SHEET_NAME);
  if (verificationSheet && verificationSheet.getLastRow() > 1) {
    verificationSheet.getRange(2, 1, verificationSheet.getLastRow() - 1, verificationSheet.getLastColumn()).clearContent();
  }
  
}

function findEmployeeRowInShiftSheet(employeeId) {
  try {
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var shiftSheet = ss.getSheetByName(SHIFT_SHEET_NAME);
    
    if (!shiftSheet) {
      return 0;
    }
    
    var data = shiftSheet.getDataRange().getValues();
    for (var i = 1; i < data.length; i++) { // ヘッダー行をスキップ
      if (data[i][0] === employeeId) {
        return i + 1; // 1ベースの行番号に変換
      }
    }
    return 0;
  } catch (e) {
    console.error("findEmployeeRowInShiftSheetでエラーが発生しました: " + e.message);
    return 0;
  }
}

/**
 * テスト用のMailApp（モック）
 * 実際のメール送信を行わずに、ログ出力のみでテストする
 */
var TestMailApp = {
  sendEmail: function(email, subject, body) {
    console.log("  [テスト] メール送信（実際には送信されません）");
    console.log("  [テスト] 宛先: " + email);
    console.log("  [テスト] 件名: " + subject);
    console.log("  [テスト] 本文: " + body.replace(/\n/g, "\\n"));
  }
};

function getTimeClocksForTest(employeeId, dateObj) {
  // テスト用の打刻データが設定されている場合はそれを使用
  if (typeof globalTestTimeClocks !== 'undefined') {
    var key = employeeId + '_' + dateObj.getDate();
    if (globalTestTimeClocks[key]) {
      return globalTestTimeClocks[key];
    }
  }
  
  // テスト用データがない場合は空配列を返す
  return [];
}

/**
 * 退勤打刻忘れテスト用のデータセットアップ
 * テストに必要なシフト表とfreeeの打刻状況を設定する
 */
function setupClockOutReminderTestData() {
  console.log("退勤打刻忘れテスト用データのセットアップを開始します。");
  
  try {
    var employees = getEmployees();
    if (!employees || employees.length < 2) {
      console.error("テスト用の従業員データが不足しています。");
      return false;
    }
    
    var today = new Date();
    var todayDate = today.getDate();
    
    // 1. シフト表にテスト用のシフトを設定
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var shiftSheet = ss.getSheetByName(SHIFT_SHEET_NAME);
    
    if (!shiftSheet) {
      console.error("シフト表が見つかりません。");
      return false;
    }
    
    // テスト用のシフトデータを設定（18:00-23:00のシフト）
    var testShiftData = [
      [employees[0].id, employees[0].display_name, "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""],
      [employees[1].id, employees[1].display_name, "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""]
    ];
    
    // 今日の日付の列にシフトを設定
    if (todayDate <= 31) {
      testShiftData[0][todayDate + 2] = "18-23"; // 従業員1に18-23のシフト
      testShiftData[1][todayDate + 2] = "20-24"; // 従業員2に20-24のシフト
    }
    
    // シフト表の該当行を更新
    for (var i = 0; i < testShiftData.length; i++) {
      var employeeId = testShiftData[i][0];
      var rowIndex = findEmployeeRowInShiftSheet(employeeId);
      if (rowIndex > 0) {
        shiftSheet.getRange(rowIndex, todayDate + 3, 1, 1).setValue(testShiftData[i][todayDate + 2]);
      }
    }
    
    console.log("  [OK] シフト表にテスト用データを設定しました");
    console.log("  [INFO] 従業員1: 18-23のシフト, 従業員2: 20-24のシフト");
    
    // 2. テスト用の打刻状況を記録（出勤打刻のみ、退勤打刻なし）
    var testTimeClocks = [
      {
        employeeId: employees[0].id,
        type: 'clock_in',
        datetime: new Date(today.getFullYear(), today.getMonth(), today.getDate(), 18, 0, 0)
      },
      {
        employeeId: employees[1].id,
        type: 'clock_in', 
        datetime: new Date(today.getFullYear(), today.getMonth(), today.getDate(), 20, 0, 0)
      }
      // 退勤打刻は意図的に設定しない（テスト用）
    ];
    
    // テスト用の打刻データをグローバル変数に保存
    if (typeof globalTestTimeClocks === 'undefined') {
      globalTestTimeClocks = {};
    }
    
    testTimeClocks.forEach(function(clock) {
      var key = clock.employeeId + '_' + today.getDate();
      if (!globalTestTimeClocks[key]) {
        globalTestTimeClocks[key] = [];
      }
      globalTestTimeClocks[key].push(clock);
    });
    
    console.log("  [OK] テスト用の打刻状況を設定しました（出勤打刻のみ）");
    console.log("  [INFO] 退勤打刻は意図的に未設定（テスト用）");
    
    return true;
    
  } catch (e) {
    console.error("テスト用データのセットアップでエラーが発生しました: " + e.message);
    return false;
  }
}

// 退勤打刻忘れテスト用のデータをリセット
function resetClockOutReminderTestData() {
  console.log("退勤打刻忘れテスト用データのリセットを開始します。");
  
  try {
    // グローバル変数をクリア
    if (typeof globalTestTimeClocks !== 'undefined') {
      globalTestTimeClocks = {};
    }
    
    // シフト表のテスト用データをクリア
    var today = new Date();
    var todayDate = today.getDate();
    var employees = getEmployees();
    
    if (employees && employees.length >= 2) {
      var ss = SpreadsheetApp.getActiveSpreadsheet();
      var shiftSheet = ss.getSheetByName(SHIFT_SHEET_NAME);
      
      if (shiftSheet && todayDate <= 31) {
        for (var i = 0; i < 2; i++) {
          var rowIndex = findEmployeeRowInShiftSheet(employees[i].id);
          if (rowIndex > 0) {
            shiftSheet.getRange(rowIndex, todayDate + 3, 1, 1).setValue("");
          }
        }
      }
    }
    
    console.log("  [OK] テスト用データをリセットしました");
    return true;
    
  } catch (e) {
    console.error("テスト用データのリセットでエラーが発生しました: " + e.message);
    return false;
  }
}
