package expo.modules.friandroid
import org.junit.Assert.*
import org.junit.Test
import java.time.*
class CalendarLogicTest {
 private fun event(id:String,start:String,end:String,allDay:Boolean=false,done:Boolean=false)=FriEvent(id,"personal",id,allDay,if(allDay)0 else Instant.parse(start).toEpochMilli(),if(allDay)0 else Instant.parse(end).toEpochMilli(),"UTC",if(allDay)start else "",if(allDay)end else "","","",done,1,1)
 @Test fun dstDaysHaveCorrectBounds(){val zone=ZoneId.of("America/New_York");val spring=CalendarLogic.dayBounds(LocalDate.parse("2026-03-08"),zone);val fall=CalendarLogic.dayBounds(LocalDate.parse("2026-11-01"),zone);assertEquals(23*3600000L,spring.second-spring.first);assertEquals(25*3600000L,fall.second-fall.first)}
 @Test fun overlapIncludesCrossMidnightButNotTouchingBoundaries(){val day=LocalDate.parse("2026-11-23");val z=ZoneId.of("UTC");val events=listOf(event("overnight","2026-11-22T23:00:00Z","2026-11-23T01:00:00Z"),event("ended","2026-11-22T22:00:00Z","2026-11-23T00:00:00Z"),event("next","2026-11-24T00:00:00Z","2026-11-24T01:00:00Z"));assertEquals(listOf("overnight"),CalendarLogic.agenda(events,day,z).map{it.id})}
 @Test fun allDayUsesLocalExclusiveDates(){val e=event("holiday","2026-11-22","2026-11-24",true);for(zone in listOf("UTC","Pacific/Auckland","America/Los_Angeles")){assertEquals(1,CalendarLogic.agenda(listOf(e),LocalDate.parse("2026-11-23"),ZoneId.of(zone)).size);assertTrue(CalendarLogic.agenda(listOf(e),LocalDate.parse("2026-11-24"),ZoneId.of(zone)).isEmpty())}}
 @Test fun nextPrioritizesOngoingAndIgnoresDoneAndAllDay(){val now=Instant.parse("2026-11-23T10:00:00Z").toEpochMilli();val e=listOf(event("future","2026-11-23T11:00:00Z","2026-11-23T12:00:00Z"),event("ongoing","2026-11-23T09:00:00Z","2026-11-23T10:30:00Z"),event("done","2026-11-23T08:00:00Z","2026-11-23T12:00:00Z",done=true),event("all","2026-11-23","2026-11-24",true));assertEquals("ongoing",CalendarLogic.next(e,now)?.id);assertEquals("future",CalendarLogic.next(e.filter{it.id!="ongoing"},now)?.id)}
 @Test(expected=IllegalArgumentException::class) fun daylightGapIsRejected(){CalendarLogic.localInstant("2026-03-08T02:30","America/New_York")}
 @Test fun repeatedHourHasDeterministicFirstOccurrence(){assertEquals(Instant.parse("2026-11-01T05:30:00Z").toEpochMilli(),CalendarLogic.localInstant("2026-11-01T01:30","America/New_York"))}
 @Test fun filtersAndSettingsRoundTrip(){val e=event("e","2026-11-23T09:00:00Z","2026-11-23T10:00:00Z");assertFalse(WidgetSettings(filter="selected").accepts(e));val s=WidgetSettings(filter="selected",calendarIds=listOf("personal"),privacy="busy",theme="dark",hourFormat="24h");assertTrue(s.accepts(e));assertEquals(s,WidgetSettings.parse(s.json()))}
}
