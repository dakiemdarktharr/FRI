package expo.modules.friandroid

import org.json.JSONArray
import org.json.JSONObject

data class WidgetSettings(val filter:String="all",val calendarIds:List<String> = emptyList(),val theme:String="system",val privacy:String="full",val showLocation:Boolean=true,val showAllDay:Boolean=true,val hourFormat:String="system") {
  fun json()=JSONObject().put("schema",1).put("filter",filter).put("calendarIds",JSONArray(calendarIds)).put("theme",theme).put("privacy",privacy).put("showLocation",showLocation).put("showAllDay",showAllDay).put("hourFormat",hourFormat).toString()
  fun accepts(event:FriEvent)=filter=="all" || event.calendarId in calendarIds
  fun validate(){require(filter in listOf("all","selected"));require(theme in listOf("system","light","dark"));require(privacy in listOf("full","busy"));require(hourFormat in listOf("system","12h","24h"))}
  companion object {
    fun parse(raw:String):WidgetSettings {
      val o=JSONObject(raw);require(o.optInt("schema",1)==1){"Update Fri to read this widget configuration."};val ids=o.optJSONArray("calendarIds")?:JSONArray()
      return WidgetSettings(o.optString("filter","all"),(0 until ids.length()).map{ids.getString(it)}.distinct(),o.optString("theme","system"),o.optString("privacy","full"),o.optBoolean("showLocation",true),o.optBoolean("showAllDay",true),o.optString("hourFormat","system")).also{it.validate()}
    }
  }
}
