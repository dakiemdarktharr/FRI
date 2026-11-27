package expo.modules.friandroid

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import androidx.annotation.Keep
import androidx.compose.runtime.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.*
import androidx.glance.action.*
import androidx.glance.appwidget.*
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.layout.*
import androidx.glance.text.*
import androidx.glance.unit.ColorProvider
import kotlinx.coroutines.*
import java.time.*
import java.time.format.DateTimeFormatter

private val eventKey=ActionParameters.Key<String>("event")
abstract class FriWidget(private val template:String):GlanceAppWidget(){
 override val sizeMode=SizeMode.Exact
 override suspend fun provideGlance(context:Context,id:GlanceId){
  val repository=FriRepository(context);repository.initialize();val appId=GlanceAppWidgetManager(context).getAppWidgetId(id)
  val initialConfig=repository.dao.instance(appId);val initialEvents=repository.dao.events()
  provideContent{
   // update() does not restart an already-running Glance composition. Observe Room
   // so confirmation, edits and native Done actions appear during that session too.
   val config by remember(appId){repository.dao.observeInstance(appId)}.collectAsState(initial=initialConfig)
   val allEvents by remember{repository.dao.observeEvents()}.collectAsState(initial=initialEvents)
   val parsed=runCatching{WidgetSettings.parse(config?.settings?:WidgetSettings().json())}.getOrNull()
   val settings=parsed?:WidgetSettings(filter="selected",privacy="busy",showLocation=false)
   val events=allEvents.filter{settings.accepts(it)};val now=System.currentTimeMillis();val zone=ZoneId.systemDefault();val day=LocalDate.now(zone)
   WidgetContent(context,appId,template,config?.state=="confirmed"&&parsed!=null,settings,CalendarLogic.agenda(events,day,zone),CalendarLogic.next(events,now),day,zone,now)
  }
 }
}
class TodayAgendaWidget:FriWidget("today_agenda")
class NextEventWidget:FriWidget("next_event")
@Composable private fun WidgetContent(context:Context,id:Int,template:String,configured:Boolean,s:WidgetSettings,agenda:List<FriEvent>,next:FriEvent?,day:LocalDate,zone:ZoneId,now:Long){
 val size=LocalSize.current;val availableHeight=size.height/context.resources.configuration.fontScale.coerceAtLeast(1f);val dark=s.theme=="dark"||(s.theme=="system"&&(context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK)==Configuration.UI_MODE_NIGHT_YES)
 val ink=if(dark)Color(0xfff4f7fa)else Color(0xff172b3a);val paper=if(dark)Color(0xff222833)else Color.White;val base=if(dark)Color(0xff14181f)else Color(0xffeaf0f4)
 fun open(path:String)=actionStartActivity(Intent(Intent.ACTION_VIEW,Uri.parse("fri://$path")).setPackage(context.packageName).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP))
 fun editor()=actionStartActivity(Intent(context,FriWidgetEditorActivity::class.java).putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,id))
 Column(GlanceModifier.fillMaxSize().background(base).appWidgetBackground().cornerRadius(24.dp).padding(if(availableHeight<180.dp)6.dp else 12.dp)){
  if(!configured){if(availableHeight>=180.dp)Text("fri.",style=TextStyle(color=ColorProvider(ink),fontSize=22.sp,fontWeight=FontWeight.Bold));Spacer(GlanceModifier.height(10.dp));Button("Set up",onClick=editor());return@Column}
  if(availableHeight>=180.dp)Row(GlanceModifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically){Text(if(availableHeight>=180.dp)day.format(DateTimeFormatter.ofPattern("EEEE"))else"fri.",GlanceModifier.defaultWeight().clickable(open("?date=$day")),style=TextStyle(color=ColorProvider(ink),fontWeight=FontWeight.Bold,fontSize=16.sp),maxLines=1);Text("+",GlanceModifier.padding(8.dp).clickable(open("edit?date=$day")),style=TextStyle(color=ColorProvider(ink),fontSize=24.sp))}
  if(availableHeight>=180.dp)Text(day.format(DateTimeFormatter.ofPattern("MMMM d, yyyy")),style=TextStyle(color=ColorProvider(ink),fontSize=12.sp))
  if(availableHeight>=180.dp)Spacer(GlanceModifier.height(8.dp))
  val visible=if(template=="next_event")listOfNotNull(next)else agenda.filter{!it.done&&(!it.allDay||s.showAllDay)}
  if(visible.isEmpty())Text(if(template=="next_event")"No upcoming events. +"else if(agenda.isNotEmpty()&&agenda.all{it.done})"All done today. +"else"No plans today. +",GlanceModifier.background(paper).cornerRadius(16.dp).padding(14.dp).fillMaxWidth().clickable(open("edit?date=$day")),style=TextStyle(color=ColorProvider(ink),fontSize=16.sp),maxLines=2)
  else {
   val rows=if(template=="next_event")1 else if(availableHeight>=320.dp)2 else 1
   visible.take(rows).forEach{e->
    Column(GlanceModifier.fillMaxWidth().background(if(e==visible.first())Color(0xff087f8c)else paper).cornerRadius(16.dp).padding(if(availableHeight<180.dp)6.dp else 12.dp).clickable(open("event?id=${e.id}"))){
     val fg=if(e==visible.first())Color.White else ink
     val eventDay=if(e.allDay)day else Instant.ofEpochMilli(e.startUtc).atZone(zone).toLocalDate()
     val timePrefix=if(e.startUtc<=now&&e.endUtc>now)"Now · "else if(eventDay!=day)eventDay.format(DateTimeFormatter.ofPattern("MMM d"))+" · "else ""
     if(availableHeight>=90.dp)Text(if(e.allDay)"All day"else timePrefix+formatTime(context,e.startUtc,zone,s.hourFormat),style=TextStyle(color=ColorProvider(fg),fontSize=12.sp),maxLines=1)
     Text(if(s.privacy=="busy")"Busy"else e.title,style=TextStyle(color=ColorProvider(fg),fontWeight=FontWeight.Bold,fontSize=16.sp),maxLines=1)
     if(availableHeight>=250.dp&&s.showLocation&&s.privacy=="full"&&e.location.isNotBlank())Text(e.location,style=TextStyle(color=ColorProvider(fg),fontSize=12.sp),maxLines=1)
     if(availableHeight>=180.dp)Text("Done ✓",GlanceModifier.padding(top=8.dp).clickable(actionRunCallback<DoneCallback>(actionParametersOf(eventKey to e.id))),style=TextStyle(color=ColorProvider(fg),fontSize=13.sp))
    };Spacer(GlanceModifier.height(6.dp))
   }
  }
  if(availableHeight<180.dp&&visible.isNotEmpty())Row(GlanceModifier.fillMaxWidth()){
   Text("+ New",GlanceModifier.defaultWeight().padding(vertical=6.dp).clickable(open("edit?date=$day")),style=TextStyle(color=ColorProvider(ink),fontSize=12.sp))
   Text("Done ✓",GlanceModifier.padding(vertical=6.dp).clickable(actionRunCallback<DoneCallback>(actionParametersOf(eventKey to visible.first().id))),style=TextStyle(color=ColorProvider(ink),fontSize=12.sp))
  }
  if(template=="next_event"&&s.showAllDay&&availableHeight>=250.dp){agenda.filter{it.allDay&&!it.done}.take(1).forEach{Text("All day · "+if(s.privacy=="busy")"Busy"else it.title,GlanceModifier.padding(vertical=8.dp).clickable(open("event?id=${it.id}")),style=TextStyle(color=ColorProvider(ink),fontSize=12.sp),maxLines=1)}}
  if(availableHeight>=320.dp&&agenda.isNotEmpty()){val completed=agenda.count{it.done};Text("$completed of ${agenda.size} complete",style=TextStyle(color=ColorProvider(ink),fontSize=12.sp))}
  if(availableHeight>=230.dp)Text("View day",GlanceModifier.padding(top=5.dp).clickable(open("?date=$day")),style=TextStyle(color=ColorProvider(ink),fontSize=12.sp))
 }
}
fun formatTime(context:Context,utc:Long,zone:ZoneId,hour:String):String {val use24=hour=="24h"||(hour=="system"&&android.text.format.DateFormat.is24HourFormat(context));return Instant.ofEpochMilli(utc).atZone(zone).format(DateTimeFormatter.ofPattern(if(use24)"HH:mm"else"h:mm a"))}
// Glance creates callbacks reflectively, including in the optimized release APK.
@Keep
class DoneCallback:ActionCallback{override suspend fun onAction(context:Context,glanceId:GlanceId,parameters:ActionParameters){parameters[eventKey]?.let{FriRepository(context).complete(it)};WidgetRefreshCoordinator.request(context)}}
abstract class FriWidgetReceiver:GlanceAppWidgetReceiver(){
 override fun onEnabled(context:Context){super.onEnabled(context);WidgetRefreshCoordinator.request(context)}
 override fun onDeleted(context:Context,appWidgetIds:IntArray){super.onDeleted(context,appWidgetIds);val p=goAsync();CoroutineScope(Dispatchers.IO).launch{try{val r=FriRepository(context);appWidgetIds.forEach{r.dao.deleteInstance(it)};r.reconcile()}finally{p.finish()}}}
 override fun onRestored(context:Context,oldWidgetIds:IntArray,newWidgetIds:IntArray){super.onRestored(context,oldWidgetIds,newWidgetIds);val p=goAsync();CoroutineScope(Dispatchers.IO).launch{try{val r=FriRepository(context);oldWidgetIds.zip(newWidgetIds.toTypedArray()).forEach{(old,new)->val c=r.dao.instance(old);if(c!=null&&WidgetTemplates.template(context,new)==c.template){r.dao.save(c.copy(appWidgetId=new,session=null,state="confirmed",updatedAt=System.currentTimeMillis()));r.dao.deleteInstance(old)}};WidgetRefreshCoordinator.request(context)}finally{p.finish()}}}
}
class TodayAgendaWidgetReceiver:FriWidgetReceiver(){override val glanceAppWidget:GlanceAppWidget=TodayAgendaWidget()}
class NextEventWidgetReceiver:FriWidgetReceiver(){override val glanceAppWidget:GlanceAppWidget=NextEventWidget()}
