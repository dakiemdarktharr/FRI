package expo.modules.friandroid

import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test

class MeetingShareTest {
 @Test fun shareTokensAreSingleUseAndBounded(){
   val token=MeetingShareInbox.put("Mai 7h tối cà phê không?")
   assertThrows(IllegalArgumentException::class.java){MeetingShareInbox.take("wrong")}
   assertTrue(MeetingShareInbox.take(token).getString("text").contains("cà phê"))
   assertThrows(IllegalStateException::class.java){MeetingShareInbox.take(token)}
   assertThrows(IllegalArgumentException::class.java){MeetingShareInbox.put("x".repeat(12001))}
   assertThrows(IllegalArgumentException::class.java){MeetingShareInbox.put(" ")}
 }
 @Test fun bundledVietnameseOcrWorksWithoutDownload(){
   val instrument=InstrumentationRegistry.getInstrumentation()
   val bytes=instrument.context.assets.open("meeting-accepted.png").use{it.readBytes()}
   val text=MeetingImageReader.readBytes(instrument.targetContext,bytes)
   assertTrue(text,text.contains("19:00"));assertTrue(text,text.lowercase().contains("họp"))
   assertThrows(IllegalArgumentException::class.java){MeetingImageReader.readBytes(instrument.targetContext,byteArrayOf(1,2,3))}
 }
}
