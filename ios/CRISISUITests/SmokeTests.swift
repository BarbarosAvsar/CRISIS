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
  XCTAssertTrue(app.staticTexts["Erkennen, was 90% übersehen."].waitForExistence(timeout: 10))
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
}
