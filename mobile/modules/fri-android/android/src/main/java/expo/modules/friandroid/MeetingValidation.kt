package expo.modules.friandroid

import java.time.Instant
import java.time.ZoneId

object MeetingValidation {
  fun validate(event:FriEvent,existing:List<FriEvent>,now:Long){
    if(event.allDay){
      val today=Instant.ofEpochMilli(now).atZone(ZoneId.of(event.zone)).toLocalDate().toString()
      require(event.startDate>=today){"This date has passed. Choose a future date."}
      require(existing.none{it.allDay && it.title==event.title && it.startDate==event.startDate}){"This plan is already in your calendar."}
    }else{
      require(event.startUtc>=now){"This time has passed. Choose a future time."}
      require(existing.none{!it.allDay && it.title==event.title && it.startUtc==event.startUtc}){"This plan is already in your calendar."}
      require(existing.none{!it.allDay && !it.done && it.startUtc<event.endUtc && it.endUtc>event.startUtc}){"This overlaps another plan. Choose a free time; your existing plans stay unchanged."}
    }
  }
}
