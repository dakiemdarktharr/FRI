package expo.modules.friandroid

import java.time.*

/** Shared by Room consumers, widgets and tests. End dates/times are exclusive. */
object CalendarLogic {
  fun dayBounds(day: LocalDate, zone: ZoneId): Pair<Long,Long> =
    day.atStartOfDay(zone).toInstant().toEpochMilli() to day.plusDays(1).atStartOfDay(zone).toInstant().toEpochMilli()
  fun overlaps(start: Long,end: Long,day: LocalDate,zone: ZoneId): Boolean {
    val (a,b)=dayBounds(day,zone);return start<b && end>a
  }
  fun localInstant(local: String,zone: String): Long {
    val d=LocalDateTime.parse(local);val z=ZoneId.of(zone);val offsets=z.rules.getValidOffsets(d)
    require(offsets.isNotEmpty()) { "That time does not exist because the clocks change. Choose another time." }
    // During a repeated hour use the first occurrence; UI preserves absolute values on unrelated edits.
    return d.toInstant(offsets.first()).toEpochMilli()
  }
  fun agenda(events: List<FriEvent>,day: LocalDate,zone: ZoneId): List<FriEvent> = events.filter {
    if(it.allDay) it.startDate<=day.toString() && it.endDate>day.toString()
    else overlaps(it.startUtc,it.endUtc,day,zone)
  }.sortedWith(compareBy<FriEvent>{!it.allDay}.thenBy{it.startUtc}.thenBy{it.id})
  fun next(events: List<FriEvent>,now: Long): FriEvent? {
    val timed=events.filter{!it.allDay && !it.done && it.endUtc>now}
    return timed.filter{it.startUtc<=now}.minWithOrNull(compareBy<FriEvent>{it.startUtc}.thenBy{it.id})
      ?:timed.filter{it.startUtc>now}.minWithOrNull(compareBy<FriEvent>{it.startUtc}.thenBy{it.id})
  }
}
