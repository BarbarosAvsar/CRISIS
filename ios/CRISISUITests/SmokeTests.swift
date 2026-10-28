import XCTest

final class SmokeTests: XCTestCase {
 private var app: XCUIApplication!

 override func setUpWithError() throws {
  continueAfterFailure = false
  app = XCUIApplication()
  app.launchArguments = ["--ui-testing"]
  app.launchEnvironment["CRISIS_RESET_STATE"] = "1"
  app.launch()
 }

 private func tab(_ title: String) {
  let button = app.tabBars.buttons[title]
  XCTAssertTrue(button.waitForExistence(timeout: 10))
  button.tap()
 }

 private func replace(_ field: XCUIElement, with text: String) {
  XCTAssertTrue(field.waitForExistence(timeout: 10))
  field.tap()
  let old = field.value as? String ?? ""
  field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + text)
 }

 func testOverviewAndCycleYear() {
  XCTAssertTrue(app.staticTexts["Vermögen verstehen. Handlungsfähig bleiben."].waitForExistence(timeout: 10))
  tab("Zyklen")
  replace(app.textFields["cycle-year"], with: "2032")
  app.swipeUp()
  let result = app.descendants(matching: .any)["cycle-result"].firstMatch
  XCTAssertTrue(result.waitForExistence(timeout: 10))
  XCTAssertTrue(result.label.contains("Niedrige Preise"))
 }

 func testComparisonRejectsReversedRange() {
  tab("Vergleich")
  let field = app.textFields["comparison-from"]
  for _ in 0..<5 where !field.isHittable { app.swipeUp() }
  replace(field, with: "2200")
  app.swipeUp()
  XCTAssertTrue(app.descendants(matching: .any)["comparison-error"].firstMatch.waitForExistence(timeout: 10))
 }

 func testDocumentSearchEmptyState() {
  tab("Wissen")
  replace(app.textFields["library-search"], with: "unfindable-4853")
  app.swipeUp()
  XCTAssertTrue(app.staticTexts["library-empty"].waitForExistence(timeout: 10))
 }

 func testBrandingPersistsAfterRelaunch() {
  tab("Mehr")
  replace(app.textFields["partner-name"], with: "UI Test Beratung")
  app.terminate()
  app.launchEnvironment["CRISIS_RESET_STATE"] = "0"
  app.launch()
  let label = app.staticTexts["partner-label"]
  XCTAssertTrue(label.waitForExistence(timeout: 10))
  XCTAssertEqual(label.label, "In Kooperation mit UI Test Beratung")
 }
 func testKaufkraftScenarioAndInvalidInput() {
  tab("Mehr")
  app.buttons["more-purchasing-power"].tap()
  let result = app.descendants(matching: .any)["power-scenario-result"].firstMatch
  for _ in 0..<12 where !result.isHittable { app.swipeUp() }
  XCTAssertTrue(result.waitForExistence(timeout: 10))
  XCTAssertTrue(result.label.contains("7.440,94"))
  let rate = app.textFields["scenario-rate"]
  for _ in 0..<4 where !rate.isHittable { app.swipeDown() }
  replace(rate, with: "101")
  app.swipeUp()
  XCTAssertTrue(app.descendants(matching: .any)["power-scenario-error"].firstMatch.waitForExistence(timeout: 10))
 }
 func testStructureCheckSaveRelaunchAndDelete() {
  tab("Mehr")
  app.buttons["more-structure"].tap()
  let note = app.descendants(matching: .any)["plan-note-liquidity"].firstMatch
  for _ in 0..<8 where !note.isHittable { app.swipeUp() }
  replace(note, with: "Reservezugang gemeinsam prüfen")
  let save = app.buttons["plan-save"]
  for _ in 0..<16 where !save.isHittable { app.swipeUp() }
  XCTAssertTrue(save.isHittable)
  save.tap()
  XCTAssertTrue(app.alerts["CRISIS"].waitForExistence(timeout: 10))
  app.alerts.buttons["OK"].tap()
  app.terminate()
  app.launchEnvironment["CRISIS_RESET_STATE"] = "0"
  app.launch()
  tab("Mehr")
  app.buttons["more-structure"].tap()
  let restored = app.descendants(matching: .any)["plan-note-liquidity"].firstMatch
  for _ in 0..<8 where !restored.isHittable { app.swipeUp() }
  XCTAssertEqual(restored.value as? String, "Reservezugang gemeinsam prüfen")
  let delete = app.buttons["plan-delete"]
  for _ in 0..<16 where !delete.isHittable { app.swipeUp() }
  delete.tap()
  app.buttons["Strukturcheck endgültig löschen"].tap()
  XCTAssertTrue(app.alerts["CRISIS"].waitForExistence(timeout: 10))
  app.alerts.buttons["OK"].tap()
  for _ in 0..<16 where !restored.isHittable { app.swipeDown() }
  XCTAssertNotEqual(restored.value as? String, "Reservezugang gemeinsam prüfen")
 }
}
