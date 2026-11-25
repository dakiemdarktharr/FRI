package expo.modules.friandroid

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import expo.modules.kotlin.functions.Coroutine
import android.content.Intent
import android.appwidget.AppWidgetManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.time.LocalDate

class FriAndroidModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("FriAndroid")
    Events("onChange")
    AsyncFunction("call") Coroutine { operation:String, raw:String ->
      try {
        val context=appContext.reactContext?:error("Fri is not ready.");val repo=FriRepository(context);val p=JSONObject(raw)
        val result=withContext(Dispatchers.IO){
          repo.initialize()
          when(operation){
            "takeMeetingShare"->MeetingShareInbox.take(p.getString("token"))
            "snapshot"->repo.snapshot(p.optString("day",LocalDate.now().toString()))
            "saveEvent"->repo.saveEvent(p).json()
            "saveMeetingEvent"->repo.saveEvent(p,true).json()
            "deleteEvent"->{repo.deleteEvent(p.getString("id"));JSONObject()}
            "complete"->{repo.complete(p.getString("id"));JSONObject()}
            "deletePreset"->{repo.dao.deletePreset(p.getString("id"));JSONObject()}
            "preferences"->{for(key in listOf("theme","hourFormat")){if(p.has(key)){val v=p.getString(key);require(v in if(key=="theme")listOf("system","light","dark")else listOf("system","12h","24h"));repo.dao.save(Preference(key,v))}};JSONObject()}
            "editor"->{withContext(Dispatchers.Main){val a=appContext.currentActivity?:error("Open Fri to configure a widget.");a.startActivity(Intent(a,FriWidgetEditorActivity::class.java).apply{putExtra("template",p.optString("template","today_agenda"));if(p.has("id"))putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,p.getInt("id"));if(p.has("presetId"))putExtra("presetId",p.getString("presetId"))})};JSONObject()}
            else->error("Unknown operation.")
          }
        }
        if(operation !in listOf("snapshot","editor","takeMeetingShare"))sendEvent("onChange",mapOf("operation" to operation))
        JSONObject().put("ok",true).put("data",result).toString()
      }catch(e:Exception){JSONObject().put("ok",false).put("error",e.message?:"Something went wrong.").toString()}
    }
  }
}
