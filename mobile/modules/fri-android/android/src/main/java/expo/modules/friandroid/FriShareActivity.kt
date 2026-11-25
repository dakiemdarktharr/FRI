package expo.modules.friandroid

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.*

class FriShareActivity:ComponentActivity(){
  override fun onCreate(saved:Bundle?){
    super.onCreate(saved)
    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    var error by mutableStateOf<String?>(null)
    var dark by mutableStateOf(resources.configuration.uiMode and 0x30==0x20)
    setContent{
      val palette=if(dark)darkColorScheme(primary=Color(0xFF64D4D0),background=Color(0xFF111D27),surface=Color(0xFF1C2D3B),onBackground=Color(0xFFEAF2F6),onSurface=Color(0xFFEAF2F6))else lightColorScheme(primary=Color(0xFF087F8C),background=Color(0xFFF4F7FA),surface=Color.White,onBackground=Color(0xFF172B3A),onSurface=Color(0xFF172B3A))
      MaterialTheme(colorScheme=palette,typography=FriTypography){Surface(Modifier.fillMaxSize(),color=palette.background){Column(Modifier.systemBarsPadding().padding(24.dp),verticalArrangement=Arrangement.spacedBy(20.dp)){
        Text("Calendar assistant",style=MaterialTheme.typography.headlineLarge)
        Card(shape=RoundedCornerShape(20.dp),colors=CardDefaults.cardColors(containerColor=palette.surface)){Column(Modifier.padding(22.dp),verticalArrangement=Arrangement.spacedBy(16.dp)){
          if(error==null){CircularProgressIndicator();Text("Reading on your device…",style=MaterialTheme.typography.titleMedium)}
          else {Text("Let’s try another way.",style=MaterialTheme.typography.titleMedium);Text(error!!)}
        }}
        OutlinedButton(onClick={finish()},modifier=Modifier.fillMaxWidth().heightIn(min=48.dp),shape=RoundedCornerShape(18.dp)){Text(if(error==null)"Cancel" else "Back")}
      }}}
    }
    lifecycleScope.launch{
      try{
        val theme=withContext(Dispatchers.IO){FriRepository(applicationContext).dao.preferences().firstOrNull{it.key=="theme"}?.value}
        if(theme=="dark"||theme=="light")dark=theme=="dark"
        require(intent.action==Intent.ACTION_SEND){"Use Share → Fri from a chat or image."}
        val type=intent.type.orEmpty()
        val text=withContext(Dispatchers.IO){when{
          type=="text/plain"->intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.also{require(it.length<=12000){"Share a shorter invitation."}}?:error("No text was shared.")
          type.startsWith("image/")-> {
            @Suppress("DEPRECATION") val uri=intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?:error("No image was shared.")
            MeetingImageReader.read(applicationContext,uri)
          }
          else->error("Share text, a PNG or a JPEG image.")
        }}
        ensureActive()
        val token=MeetingShareInbox.put(text)
        val launch=packageManager.getLaunchIntentForPackage(packageName)?:error("Cannot open Fri.")
        launch.action=Intent.ACTION_VIEW;launch.data=Uri.parse("fri://assistant?share=$token")
        launch.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        startActivity(launch);finish()
      }catch(e:CancellationException){throw e}catch(e:Exception){error=e.message?:"Cannot read this share. Try sharing its text instead."}
    }
  }
}
