package expo.modules.friandroid

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.*
import java.util.UUID
import java.time.LocalDate
import java.time.ZoneId

/** Configuration stays native, including installation from the launcher's picker. */
class FriWidgetEditorActivity:ComponentActivity(){
  private val repo by lazy{FriRepository(applicationContext)}
  private var session=UUID.randomUUID().toString()
  private var draft=WidgetSettings();private var draftName="My widget"
  private var id=-1;private var presetId:String?=null;private var template="today_agenda"
  private var committed=false
  override fun onCreate(saved:Bundle?){
    super.onCreate(saved);setResult(RESULT_CANCELED)
    id=intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,-1);session=saved?.getString("session")?:session;presetId=intent.getStringExtra("presetId")
    template=if(id>=0)WidgetTemplates.template(this,id)?:run{finish();return}else intent.getStringExtra("template")?:"today_agenda"
    if(template !in WidgetTemplates.names){finish();return}
    lifecycleScope.launch{
      val data=withContext(Dispatchers.IO){repo.initialize();Triple(if(id>=0)repo.dao.instance(id)else null,presetId?.let{repo.dao.preset(it)},repo.dao.calendars())}
      draft=runCatching{WidgetSettings.parse(saved?.getString("settings")?:data.first?.settings?:data.second?.settings?:WidgetSettings().json())}.getOrDefault(WidgetSettings(filter="selected",privacy="busy",showLocation=false))
      draftName=saved?.getString("name")?:data.second?.name?:"My widget"
      val events=withContext(Dispatchers.IO){repo.dao.events()}
      setContent{MaterialTheme(colorScheme=lightColorScheme(primary=Color(0xFF955251),surface=Color(0xFFFAF7F2),onSurface=Color(0xFF302929))){Editor(data.third,data.first?.state=="confirmed",events)}}
    }
  }
  override fun onSaveInstanceState(out:Bundle){out.putString("session",session);out.putString("settings",draft.json());out.putString("name",draftName);super.onSaveInstanceState(out)}
  private fun cancel(){lifecycleScope.launch{withContext(Dispatchers.IO){if(!committed)repo.dao.rollback(session)};setResult(RESULT_CANCELED);finish()}}
  @Composable private fun Editor(calendars:List<FriCalendar>,editing:Boolean,events:List<FriEvent>){
    var settings by remember{mutableStateOf(draft)};var name by remember{mutableStateOf(draftName)};var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")}
    fun update(value:WidgetSettings){settings=value;draft=value}
    fun operation(block:suspend()->String){if(busy)return;busy=true;lifecycleScope.launch{try{message=block()}catch(e:Exception){message=e.message?:"Could not save. Try again."}finally{busy=false}}}
    BackHandler(enabled=!busy){cancel()}
    Surface(Modifier.fillMaxSize()){Column(Modifier.safeDrawingPadding().padding(24.dp).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(14.dp)){
      Text(if(editing)"Edit widget"else "Make it yours",style=MaterialTheme.typography.headlineMedium)
      Text(if(template=="today_agenda")"Today's agenda"else "Up next",style=MaterialTheme.typography.titleMedium)
      if(id<0)OutlinedTextField(name,{name=it;draftName=it},label={Text("Preset name")},singleLine=true,modifier=Modifier.fillMaxWidth())
      Text("Calendars",style=MaterialTheme.typography.titleMedium)
      Row{FilterChip(settings.filter=="all",{update(settings.copy(filter="all"))},label={Text("All")});Spacer(Modifier.width(8.dp));FilterChip(settings.filter=="selected",{update(settings.copy(filter="selected"))},label={Text("Choose")})}
      if(settings.filter=="selected")calendars.forEach{c->Row{Checkbox(c.id in settings.calendarIds,{update(settings.copy(calendarIds=if(it)(settings.calendarIds+c.id).distinct()else settings.calendarIds-c.id))});Text(c.name,Modifier.padding(top=12.dp))}}
      Text("Appearance",style=MaterialTheme.typography.titleMedium)
      FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp)){listOf("system","light","dark").forEach{v->FilterChip(settings.theme==v,{update(settings.copy(theme=v))},label={Text(v)})}}
      Row{Checkbox(settings.privacy=="busy",{update(settings.copy(privacy=if(it)"busy"else "full"))});Text("Hide titles and places",Modifier.padding(top=12.dp))}
      Row{Checkbox(settings.showLocation,{update(settings.copy(showLocation=it))});Text("Show location",Modifier.padding(top=12.dp))}
      Row{Checkbox(settings.showAllDay,{update(settings.copy(showAllDay=it))});Text("Show all-day plans",Modifier.padding(top=12.dp))}
      FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp)){listOf("system","12h","24h").forEach{v->FilterChip(settings.hourFormat==v,{update(settings.copy(hourFormat=v))},label={Text(v)})}}
      val filtered=events.filter{settings.accepts(it)};val zone=ZoneId.systemDefault();val now=System.currentTimeMillis()
      val preview=if(template=="next_event")CalendarLogic.next(filtered,now)else CalendarLogic.agenda(filtered,LocalDate.now(zone),zone).firstOrNull{!it.done&&(!it.allDay||settings.showAllDay)}
      val dark=settings.theme=="dark"||(settings.theme=="system"&&androidx.compose.foundation.isSystemInDarkTheme())
      Text("Preview · size is set by your launcher",style=MaterialTheme.typography.labelMedium)
      Surface(color=if(dark)Color(0xFF302929)else Color(0xFFE9E1DA),contentColor=if(dark)Color(0xFFFAF7F2)else Color(0xFF302929),shape=MaterialTheme.shapes.large){Column(Modifier.fillMaxWidth().padding(20.dp)){
        Text(if(preview==null)"Nothing planned yet."else if(settings.privacy=="busy")"Busy"else preview.title,style=MaterialTheme.typography.titleLarge,maxLines=2)
        if(preview!=null){Text(if(preview.allDay)"All day"else formatTime(this@FriWidgetEditorActivity,preview.startUtc,zone,settings.hourFormat));if(settings.showLocation&&settings.privacy=="full"&&preview.location.isNotBlank())Text(preview.location,maxLines=1)}
        Text(if(settings.filter=="all")"All calendars"else "${settings.calendarIds.size} calendars selected")
      }}
      if(message.isNotEmpty())Text(message,color=MaterialTheme.colorScheme.primary)
      if(id>=0)Button(enabled=!busy,onClick={operation{
        withContext(Dispatchers.IO){
          repo.saveInstance(id,template,settings,presetId,if(editing)null else session,if(editing)"confirmed"else "provisional")
          try{WidgetRefreshCoordinator.render(this@FriWidgetEditorActivity,id,template)}catch(e:Exception){if(!editing){repo.dao.rollback(session);throw e}else WidgetRefreshCoordinator.request(this@FriWidgetEditorActivity)}
          val instance=repo.dao.instance(id)?:error("This widget was removed.");repo.dao.save(instance.copy(state="confirmed",session=null,updatedAt=System.currentTimeMillis()))
        }
        committed=true;WidgetRefreshCoordinator.request(this@FriWidgetEditorActivity);setResult(RESULT_OK,Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,id));finish();"Saved"
      }},modifier=Modifier.fillMaxWidth()){Text(if(editing)"Save changes"else "Add widget")}
      else{
        Button(enabled=!busy,onClick={operation{
          val result=withContext(Dispatchers.IO){WidgetPinCoordinator.request(this@FriWidgetEditorActivity,template,settings,presetId)}
          if(result=="pin_requested")"Requested. Confirm placement on your home screen. Check installed widgets in Fri."else "Open your launcher's widget picker, choose Fri, then configure your widget."
        }},modifier=Modifier.fillMaxWidth()){Text("Add to home screen")}
        OutlinedButton(enabled=!busy&&name.isNotBlank(),onClick={operation{withContext(Dispatchers.IO){presetId=repo.savePreset(presetId,name,template,settings).id};"Preset saved. Existing widgets keep their own settings."}},modifier=Modifier.fillMaxWidth()){Text("Save preset")}
      }
      TextButton(enabled=!busy,onClick={cancel()},modifier=Modifier.fillMaxWidth()){Text(if(id>=0)"Cancel"else "Close")}
    }}
  }
}
