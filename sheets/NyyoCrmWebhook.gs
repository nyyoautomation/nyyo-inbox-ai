/**
 * Nyyo inbox -> CRM kit: receives rows from the kit and adds them to a "Leads" tab of THIS spreadsheet.
 * Paste into Extensions > Apps Script of your Google Sheet, change SECRET, then Deploy > New deployment >
 * Web app (Execute as: Me, Who has access: Anyone). Full steps: INSTALL.md, Step 6. MIT licence, Nyyo Automation.
 * @OnlyCurrentDoc
 */
var SECRET = 'change-me-to-the-same-long-secret-as-in-your-env-file';
var TAB = 'Leads';

function doPost(e) {
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);  // two runs at once never write the same row twice
  try {
    var data = JSON.parse(e.postData.contents);
    if (SECRET.indexOf('change-me') === 0 || data.secret !== SECRET) return reply_({ ok: false, error: 'wrong secret' });
    var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(TAB) ||
                SpreadsheetApp.getActiveSpreadsheet().insertSheet(TAB);
    if (sheet.getLastRow() === 0) {
      sheet.appendRow(data.columns);
      sheet.setFrozenRows(1);
    }
    var ids = sheet.getLastRow() > 1 ? sheet.getRange(2, 1, sheet.getLastRow() - 1, 1).getValues() : [];
    for (var i = 0; i < ids.length; i++) {
      if (String(ids[i][0]) === String(data.row[0])) return reply_({ ok: true, duplicate: true });
    }
    sheet.appendRow(data.row);
    return reply_({ ok: true });
  } catch (err) {
    return reply_({ ok: false, error: String(err) });
  } finally {
    lock.releaseLock();
  }
}

function reply_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
