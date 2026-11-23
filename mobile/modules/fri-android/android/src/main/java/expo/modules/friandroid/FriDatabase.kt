package expo.modules.friandroid

import android.content.Context
import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Entity(tableName="calendars")
data class FriCalendar(@PrimaryKey val id:String,val name:String,val color:String,val createdAt:Long,val updatedAt:Long)
@Entity(tableName="events",indices=[Index("calendarId"),Index("startUtc"),Index("startDate")],foreignKeys=[ForeignKey(entity=FriCalendar::class,parentColumns=["id"],childColumns=["calendarId"],onDelete=ForeignKey.RESTRICT)])
data class FriEvent(@PrimaryKey val id:String,val calendarId:String,val title:String,val allDay:Boolean=false,val startUtc:Long=0,val endUtc:Long=0,val zone:String="UTC",val startDate:String="",val endDate:String="",val location:String="",val notes:String="",val done:Boolean=false,val createdAt:Long,val updatedAt:Long)
@Entity(tableName="presets")
data class WidgetPreset(@PrimaryKey val id:String,val name:String,val template:String,val settings:String,val version:Int=1,val createdAt:Long,val updatedAt:Long)
@Entity(tableName="instances")
data class WidgetInstance(@PrimaryKey val appWidgetId:Int,val template:String,val presetId:String?=null,val settings:String,val version:Int=1,val session:String?=null,val state:String="confirmed",val createdAt:Long,val updatedAt:Long)
@Entity(tableName="pending_pins")
data class PendingPin(@PrimaryKey val token:String,val template:String,val presetId:String?=null,val settings:String,val state:String="pin_requested",val confirmedId:Int?=null,val createdAt:Long,val updatedAt:Long)
@Entity(tableName="preferences")
data class Preference(@PrimaryKey val key:String,val value:String)

@Dao interface FriDao {
  @Query("SELECT * FROM calendars ORDER BY id") suspend fun calendars():List<FriCalendar>
  @Insert(onConflict=OnConflictStrategy.IGNORE) suspend fun seed(vararg calendars:FriCalendar)
  @Query("SELECT * FROM events ORDER BY startUtc,id") suspend fun events():List<FriEvent>
  @Query("SELECT * FROM events ORDER BY startUtc,id") fun observeEvents():Flow<List<FriEvent>>
  @Query("SELECT * FROM events WHERE id=:id") suspend fun event(id:String):FriEvent?
  @Upsert suspend fun save(event:FriEvent)
  @Query("DELETE FROM events WHERE id=:id") suspend fun deleteEvent(id:String)
  @Query("UPDATE events SET done=1,updatedAt=:updatedAt WHERE id=:id") suspend fun completeEvent(id:String,updatedAt:Long)
  @Query("SELECT * FROM presets ORDER BY updatedAt DESC") suspend fun presets():List<WidgetPreset>
  @Query("SELECT * FROM presets WHERE id=:id") suspend fun preset(id:String):WidgetPreset?
  @Upsert suspend fun save(preset:WidgetPreset)
  @Query("DELETE FROM presets WHERE id=:id") suspend fun deletePreset(id:String)
  @Query("SELECT * FROM instances") suspend fun instances():List<WidgetInstance>
  @Query("SELECT * FROM instances WHERE appWidgetId=:id") suspend fun instance(id:Int):WidgetInstance?
  @Query("SELECT * FROM instances WHERE appWidgetId=:id") fun observeInstance(id:Int):Flow<WidgetInstance?>
  @Upsert suspend fun save(instance:WidgetInstance)
  @Query("DELETE FROM instances WHERE appWidgetId=:id") suspend fun deleteInstance(id:Int)
  @Query("DELETE FROM instances WHERE session=:session AND state='provisional'") suspend fun rollback(session:String)
  @Query("SELECT * FROM pending_pins ORDER BY createdAt DESC") suspend fun pins():List<PendingPin>
  @Query("SELECT * FROM pending_pins WHERE token=:token") suspend fun pin(token:String):PendingPin?
  @Upsert suspend fun save(pin:PendingPin)
  @Query("DELETE FROM pending_pins WHERE createdAt<:before") suspend fun prunePins(before:Long)
  @Query("SELECT * FROM preferences") suspend fun preferences():List<Preference>
  @Upsert suspend fun save(preference:Preference)
}
@Database(entities=[FriCalendar::class,FriEvent::class,WidgetPreset::class,WidgetInstance::class,PendingPin::class,Preference::class],version=1,exportSchema=true)
abstract class FriDatabase:RoomDatabase(){
  abstract fun dao():FriDao
  companion object {
    @Volatile private var instance:FriDatabase?=null
    fun get(context:Context):FriDatabase=instance?:synchronized(this){instance?:Room.databaseBuilder(context.applicationContext,FriDatabase::class.java,"fri.db").build().also{instance=it}}
  }
}
