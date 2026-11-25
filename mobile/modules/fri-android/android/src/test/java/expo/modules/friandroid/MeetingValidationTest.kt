package expo.modules.friandroid
import org.junit.Test
import org.junit.Assert.*
import java.time.Instant

class MeetingValidationTest {
 private val now=Instant.parse("2026-11-25T10:00:00Z").toEpochMilli()
 private fun event(start:Long=now+3600000,end:Long=start+3600000)=FriEvent("share","personal","Meeting",false,start,end,"Asia/Ho_Chi_Minh","","","","",false,now,now)
 @Test fun blocksPastDuplicateAndOverlap(){
   assertThrows(IllegalArgumentException::class.java){MeetingValidation.validate(event(now-1),emptyList(),now)}
   val proposed=event()
   assertThrows(IllegalArgumentException::class.java){MeetingValidation.validate(proposed,listOf(proposed),now)}
   assertThrows(IllegalArgumentException::class.java){MeetingValidation.validate(proposed,listOf(proposed.copy(id="fixed",title="Class")),now)}
   MeetingValidation.validate(proposed,listOf(event(proposed.endUtc)),now)
   MeetingValidation.validate(proposed,listOf(proposed.copy(title="Done",done=true)),now)
 }
 @Test fun validatesAllDayInSelectedZone(){
   val late=Instant.parse("2026-11-25T19:00:00Z").toEpochMilli()
   val item=event().copy(allDay=true,startDate="2026-11-25",endDate="2026-11-26")
   assertThrows(IllegalArgumentException::class.java){MeetingValidation.validate(item,emptyList(),late)}
   MeetingValidation.validate(item.copy(zone="America/New_York"),emptyList(),late)
 }
}
