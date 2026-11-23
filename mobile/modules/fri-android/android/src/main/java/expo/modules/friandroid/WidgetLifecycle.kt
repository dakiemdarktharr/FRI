package expo.modules.friandroid

import android.app.Activity
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.*
import android.net.Uri
import android.os.Build
import androidx.work.*
import kotlinx.coroutines.*
import java.util.UUID
import java.util.concurrent.TimeUnit

object WidgetTemplates {
  val names=listOf("today_agenda","next_event")
  fun component(context:Context,template:String):ComponentName {
    require(template in names)
    return ComponentName(context,if(template=="today_agenda")TodayAgendaWidgetReceiver::class.java else NextEventWidgetReceiver::class.java)
  }
  fun template(context:Context,id:Int):String? {val p=AppWidgetManager.getInstance(context).getAppWidgetInfo(id)?.provider;return names.firstOrNull{component(context,it)==p}}
  fun widget(template:String)=if(template=="today_agenda")TodayAgendaWidget()else NextEventWidget()
}
object WidgetPinCoordinator {
  suspend fun request(activity:Activity,template:String,settings:WidgetSettings,presetId:String?):String {
    val manager=AppWidgetManager.getInstance(activity);val repository=FriRepository(activity);repository.initialize()
    val token=UUID.randomUUID().toString();val now=System.currentTimeMillis();val supported=Build.VERSION.SDK_INT>=26&&manager.isRequestPinAppWidgetSupported
    repository.dao.save(PendingPin(token,template,presetId,settings.json(),if(supported)"pin_requested" else "unsupported",createdAt=now,updatedAt=now))
    if(!supported)return "unsupported"
    val intent=Intent(activity,WidgetPinSuccessReceiver::class.java).setAction("com.fri.PIN_CONFIRMED").setData(Uri.parse("fri-pin://request/$token")).putExtra("token",token)
    val flags=PendingIntent.FLAG_ONE_SHOT or if(Build.VERSION.SDK_INT>=31)PendingIntent.FLAG_MUTABLE else 0
    val callback=PendingIntent.getBroadcast(activity,0,intent,flags)
    val accepted=withContext(Dispatchers.Main){manager.requestPinAppWidget(WidgetTemplates.component(activity,template),null,callback)}
    if(!accepted)repository.dao.save(repository.dao.pin(token)!!.copy(state="unsupported",updatedAt=System.currentTimeMillis()))
    return if(accepted)"pin_requested"else "unsupported"
  }
}
class WidgetPinSuccessReceiver:BroadcastReceiver(){
  override fun onReceive(context:Context,intent:Intent){
    if(intent.action!="com.fri.PIN_CONFIRMED")return
    val token=intent.getStringExtra("token")?:return
    if(intent.data!=Uri.parse("fri-pin://request/$token"))return
    val id=intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,AppWidgetManager.INVALID_APPWIDGET_ID)
    val pending=goAsync();CoroutineScope(Dispatchers.IO).launch{try{if(FriRepository(context).confirmPin(token,id))WidgetRefreshCoordinator.request(context)}finally{pending.finish()}}
  }
}
object WidgetRefreshCoordinator {
  fun request(context:Context){WorkManager.getInstance(context).enqueueUniqueWork("fri-refresh",ExistingWorkPolicy.REPLACE,OneTimeWorkRequestBuilder<WidgetRefreshWorker>().setInitialDelay(300,TimeUnit.MILLISECONDS).build())}
  fun schedule(context:Context,hasWidgets:Boolean){val w=WorkManager.getInstance(context);if(hasWidgets)w.enqueueUniquePeriodicWork("fri-periodic",ExistingPeriodicWorkPolicy.KEEP,PeriodicWorkRequestBuilder<WidgetRefreshWorker>(15,TimeUnit.MINUTES).build())else w.cancelUniqueWork("fri-periodic")}
  suspend fun render(context:Context,id:Int,template:String){val gid=androidx.glance.appwidget.GlanceAppWidgetManager(context).getGlanceIdBy(id);WidgetTemplates.widget(template).update(context,gid)}
}
class WidgetRefreshWorker(context:Context,parameters:WorkerParameters):CoroutineWorker(context,parameters){
  override suspend fun doWork():Result=try{val r=FriRepository(applicationContext);val ids=r.reconcile();for((id,t)in ids)WidgetRefreshCoordinator.render(applicationContext,id,t);Result.success()}catch(e:Exception){if(runAttemptCount<3)Result.retry()else Result.failure()}
}
class WidgetTimeReceiver:BroadcastReceiver(){override fun onReceive(context:Context,intent:Intent){if(intent.action in listOf(Intent.ACTION_DATE_CHANGED,Intent.ACTION_TIME_CHANGED,Intent.ACTION_TIMEZONE_CHANGED,Intent.ACTION_BOOT_COMPLETED,Intent.ACTION_MY_PACKAGE_REPLACED))WidgetRefreshCoordinator.request(context)}}
