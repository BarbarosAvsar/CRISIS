package berlin.aia.crisis

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.lifecycle.ViewModelProvider
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

/** Runs inside the actual native activity on an emulator or connected device. */
class NativeFlowTest {
 @get:Rule val compose = createAndroidComposeRule<MainActivity>()

 @Test fun cycleEntrySurvivesActivityRecreationAndTabNavigation() {
  compose.onNodeWithText("Zyklen",useUnmergedTree=true).performClick()
  compose.onNodeWithTag("cycle-year").performScrollTo().performTextReplacement("2032")
  compose.onNodeWithText("2032: Niedrige Preise (Modell)").assertExists()
  compose.activityRule.scenario.recreate()
  compose.onNodeWithTag("cycle-year").assertTextContains("2032")
  compose.onNodeWithText("Übersicht",useUnmergedTree=true).performClick()
  compose.onNodeWithText("Zyklen",useUnmergedTree=true).performClick()
  compose.onNodeWithTag("cycle-year").assertTextContains("2032")
 }

 @Test fun comparisonShowsUsefulEmptySelectionAndYearErrors() {
  compose.onNodeWithText("Vergleich",useUnmergedTree=true).performClick()
  compose.onNodeWithTag("asset-gold").performScrollTo().performClick()
  compose.onNodeWithTag("asset-silver").performScrollTo().performClick()
  compose.onNodeWithText("Mindestens ein Asset auswählen.").performScrollTo().assertIsDisplayed()
  compose.onNodeWithTag("asset-gold").performScrollTo().performClick()
  compose.onNodeWithTag("compare-from").performScrollTo().performTextReplacement("")
  compose.onNodeWithText("Bitte ein gültiges Startjahr eingeben.").performScrollTo().assertIsDisplayed()
 }

 @Test fun documentSearchSurvivesRecreation() {
  compose.onNodeWithText("Wissen",useUnmergedTree=true).performClick()
  compose.onNodeWithTag("document-search").performTextReplacement("unfindablexyz")
  compose.onNodeWithText("Keine passenden Dokumente gefunden.").assertExists()
  compose.activityRule.scenario.recreate()
  compose.onNodeWithTag("document-search").assertTextContains("unfindablexyz")
  compose.onNodeWithText("Keine passenden Dokumente gefunden.").assertExists()
 }

 @Test fun genuineSnapshotPersistsAndRejectedImportKeepsData() {
  val model=ViewModelProvider(compose.activity)[CrisisModel::class.java]
  compose.onNodeWithText("Mehr",useUnmergedTree=true).performClick()
  compose.onNodeWithText("Echte historische Daten laden").performScrollTo().performClick()
  compose.waitUntil(10_000) { !model.busy }
  compose.runOnIdle { assertEquals("import",model.data.kind) }
  val before=model.data
  compose.runOnIdle { model.load("{\"invalid\":true}") }
  compose.waitUntil(10_000) { !model.busy }
  compose.runOnIdle { assertEquals(before,model.data) }
  compose.activityRule.scenario.recreate()
  val restored=ViewModelProvider(compose.activity)[CrisisModel::class.java]
  compose.runOnIdle { assertEquals(before,restored.data) }
  compose.runOnIdle { restored.reset() }
  compose.waitUntil(10_000) { !restored.busy }
 }
}
