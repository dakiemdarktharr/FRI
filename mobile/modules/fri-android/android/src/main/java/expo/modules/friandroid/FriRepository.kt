package expo.modules.friandroid

import android.appwidget.AppWidgetManager
import android.content.Context
import androidx.room.withTransaction
import org.json.JSONArray
import org.json.JSONObject
import java.time.*
import java.util.UUID

class FriRepository(private val context:Context) {
  val db=FriDatabase.get(context);val dao=db.dao()
  suspend fun initialize(){val n=System.currentTimeMillis();dao.seed(FriCalendar("personal","Personal","#087F8C",n,n),FriCalendar("work","Work","#172B3A",n,n))}
  suspend fun saveEvent(o:JSONObject):FriEvent {
    initialize();val id=o.optString("id").ifBlank{UUID.randomUUID().toString()};val old=dao.event(id);val title=o.optString("title").trim();require(title.isNotBlank()&&title.length<=300){"Add a title of up to 300 characters."}
    val calendar=o.optString("calendarId","personal");require(dao.calendars().any{it.id==calendar}){"Choose an available calendar."}
    val zone=o.optString("zone",ZoneId.systemDefault().id);ZoneId.of(zone)
    val allDay=o.optBoolean("allDay");var start=0L;var end=0L;var sd="";var ed=""
    if(allDay){sd=LocalDate.parse(o.getString("startDate")).toString();ed=LocalDate.parse(o.getString("endDate")).toString();require(ed>sd){"The end date must be after the start date."}}
    else {start=if(o.has("startLocal"))CalendarLogic.localInstant(o.getString("startLocal"),zone)else o.getLong("startUtc");end=if(o.has("endLocal"))CalendarLogic.localInstant(o.getString("endLocal"),zone)else o.getLong("endUtc");require(end>start){"The end must be after the start."}}
    val now=System.currentTimeMillis();val event=FriEvent(id,calendar,title,allDay,start,end,zone,sd,ed,o.optString("location").take(1000),o.optString("notes").take(10000),old?.done?:o.optBoolean("done",false),old?.createdAt?:now,now)
    dao.save(event);WidgetRefreshCoordinator.request(context);return event
  }
  suspend fun deleteEvent(id:String){dao.deleteEvent(id);WidgetRefreshCoordinator.request(context)}
  suspend fun complete(id:String){dao.completeEvent(id,System.currentTimeMillis());WidgetRefreshCoordinator.request(context)}
  suspend fun savePreset(id:String?,name:String,template:String,settings:WidgetSettings):WidgetPreset {
    require(template in WidgetTemplates.names);require(name.trim().isNotEmpty()){"Name your saved preset."};settings.validate();val n=System.currentTimeMillis();val old=id?.let{dao.preset(it)};val p=WidgetPreset(old?.id?:UUID.randomUUID().toString(),name.trim().take(100),template,settings.json(),(old?.version?:0)+1,old?.createdAt?:n,n);dao.save(p);return p
  }
  suspend fun installed():Map<Int,String> {
    val manager=AppWidgetManager.getInstance(context)
    return WidgetTemplates.names.flatMap{t->manager.getAppWidgetIds(WidgetTemplates.component(context,t)).map{it to t}}.toMap()
  }
  suspend fun reconcile():Map<Int,String> {
    initialize();val actual=installed();val now=System.currentTimeMillis()
    for(i in dao.instances()){
      if(i.appWidgetId !in actual && now-i.updatedAt>120_000)dao.deleteInstance(i.appWidgetId)
      else if(i.appWidgetId in actual && i.state=="provisional" && now-i.updatedAt>120_000)dao.deleteInstance(i.appWidgetId) // interrupted install never silently becomes confirmed
    }
    for(p in dao.pins())if(p.state=="pin_requested" && now-p.createdAt>120_000)dao.save(p.copy(state="unconfirmed",updatedAt=now))
    dao.prunePins(now-30L*24*60*60*1000);WidgetRefreshCoordinator.schedule(context,actual.isNotEmpty());return actual
  }
  suspend fun saveInstance(id:Int,template:String,settings:WidgetSettings,presetId:String?=null,session:String?=null,state:String="confirmed"):WidgetInstance {
    val actual=AppWidgetManager.getInstance(context).getAppWidgetInfo(id)?.provider
    require(actual==WidgetTemplates.component(context,template)){"This widget is no longer available. Add it again from your home screen."};settings.validate()
    return db.withTransaction{val old=dao.instance(id);val n=System.currentTimeMillis();WidgetInstance(id,template,presetId,settings.json(),(old?.version?:0)+1,session,state,old?.createdAt?:n,n).also{dao.save(it)}}
  }
  suspend fun confirmPin(token:String,id:Int):Boolean=db.withTransaction {
    val request=dao.pin(token)?:return@withTransaction false
    if(request.state=="confirmed")return@withTransaction request.confirmedId==id
    if(request.state !in listOf("pin_requested","unconfirmed"))return@withTransaction false
    if(id==AppWidgetManager.INVALID_APPWIDGET_ID || AppWidgetManager.getInstance(context).getAppWidgetInfo(id)?.provider!=WidgetTemplates.component(context,request.template))return@withTransaction false
    val old=dao.instance(id);if(old!=null)return@withTransaction false
    val n=System.currentTimeMillis();dao.save(WidgetInstance(id,request.template,request.presetId,request.settings,createdAt=n,updatedAt=n));dao.save(request.copy(state="confirmed",confirmedId=id,updatedAt=n));true
  }
  suspend fun snapshot(day:String):JSONObject {
    val installed=reconcile();val z=ZoneId.systemDefault();val selected=LocalDate.parse(day);val all=dao.events()
    return JSONObject().put("today",LocalDate.now(z).toString()).put("zone",z.id).put("events",JSONArray(all.map{it.json()})).put("agenda",JSONArray(CalendarLogic.agenda(all,selected,z).map{it.json()})).put("calendars",JSONArray(dao.calendars().map{JSONObject().put("id",it.id).put("name",it.name).put("color",it.color)}))
      .put("presets",JSONArray(dao.presets().map{JSONObject().put("id",it.id).put("name",it.name).put("template",it.template).put("settings",JSONObject(it.settings))}))
      .put("instances",JSONArray(installed.map{(id,t)->val c=dao.instance(id);JSONObject().put("id",id).put("template",t).put("configured",c?.state=="confirmed").put("settings",c?.let{JSONObject(it.settings)}?:JSONObject.NULL)}))
      .put("requests",JSONArray(dao.pins().take(12).map{JSONObject().put("token",it.token).put("state",it.state).put("template",it.template)}))
      .put("preferences",JSONObject().apply{dao.preferences().forEach{put(it.key,it.value)}})
  }
}
fun FriEvent.json()=JSONObject().put("id",id).put("calendarId",calendarId).put("title",title).put("allDay",allDay).put("startUtc",startUtc).put("endUtc",endUtc).put("zone",zone).put("startDate",startDate).put("endDate",endDate).put("location",location).put("notes",notes).put("done",done).put("createdAt",createdAt).put("updatedAt",updatedAt)
