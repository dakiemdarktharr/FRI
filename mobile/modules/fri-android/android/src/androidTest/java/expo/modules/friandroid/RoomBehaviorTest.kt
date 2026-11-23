package expo.modules.friandroid

import androidx.room.Room
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.async
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.flow.first
import org.junit.Assert.*
import org.junit.Test

class RoomBehaviorTest {
 @Test fun widgetObserversSeeConfirmationAndCompletion()=runBlocking {
  val context=InstrumentationRegistry.getInstrumentation().targetContext
  val db=Room.inMemoryDatabaseBuilder(context,FriDatabase::class.java).build()
  try{withTimeout(5000){
   val dao=db.dao();dao.seed(FriCalendar("personal","Personal","#955251",1,1))
   val confirmed=async{dao.observeInstance(9).first{it?.state=="confirmed"}}
   dao.save(WidgetInstance(9,"today_agenda",settings=WidgetSettings().json(),session="install",state="provisional",createdAt=1,updatedAt=1))
   dao.save(dao.instance(9)!!.copy(state="confirmed",session=null))
   assertEquals("confirmed",confirmed.await()?.state)
   val completed=async{dao.observeEvents().first{events->events.any{it.id=="live"&&it.done}}}
   dao.save(FriEvent("live","personal","Live changes",createdAt=1,updatedAt=1))
   dao.completeEvent("live",2)
   assertTrue(completed.await().single().done)
  }}finally{db.close()}
 }
 @Test fun snapshotsRollbackAndCompletionAreIndependent()=runBlocking {
  val context=InstrumentationRegistry.getInstrumentation().targetContext
  val db=Room.inMemoryDatabaseBuilder(context,FriDatabase::class.java).build()
  try{
   val dao=db.dao();dao.seed(FriCalendar("personal","Personal","#955251",1,1))
   val settings=WidgetSettings(calendarIds=listOf("personal"),filter="selected").json()
   dao.save(WidgetPreset("preset","My preset","next_event",settings,createdAt=1,updatedAt=1))
   dao.save(WidgetInstance(7,"next_event","preset",settings,createdAt=1,updatedAt=1))
   dao.save(WidgetInstance(8,"today_agenda",settings=WidgetSettings(privacy="busy").json(),session="cancel-me",state="provisional",createdAt=1,updatedAt=1))
   dao.deletePreset("preset");assertEquals(settings,dao.instance(7)?.settings)
   dao.rollback("cancel-me");assertNull(dao.instance(8));assertNotNull(dao.instance(7))
   val event=FriEvent("event","personal","Keep this title",false,100,200,"UTC","","","Home","Notes",false,1,1)
   dao.save(event);dao.completeEvent("event",2)
   assertTrue(dao.event("event")!!.done);assertEquals("Keep this title",dao.event("event")!!.title)
   dao.deleteEvent("event");assertNull(dao.event("event"))
   dao.save(PendingPin("unique-token","next_event",settings=settings,createdAt=1,updatedAt=1))
   assertEquals("pin_requested",dao.pin("unique-token")?.state)
  }finally{db.close()}
 }
}
