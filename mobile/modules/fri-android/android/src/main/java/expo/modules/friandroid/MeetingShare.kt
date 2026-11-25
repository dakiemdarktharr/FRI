package expo.modules.friandroid

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import com.googlecode.tesseract.android.TessBaseAPI
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID
import org.json.JSONObject

/** One bounded, short-lived handoff. Raw shares never enter Room, URLs or logs. */
object MeetingShareInbox {
  private var pending:Triple<String,String,Long>?=null
  @Synchronized fun put(text:String):String {
    require(text.isNotBlank() && text.length<=12000){"Share a shorter invitation (up to 12,000 characters)."}
    val token=UUID.randomUUID().toString();pending=Triple(token,text,System.currentTimeMillis());return token
  }
  @Synchronized fun take(token:String):JSONObject {
    val item=pending?:error("Share expired.")
    require(item.first==token){"Share expired."}
    pending=null
    require(System.currentTimeMillis()-item.third<=600000){"Share expired."}
    return JSONObject().put("text",item.second)
  }
}

object MeetingImageReader {
  private const val MAX_BYTES=12*1024*1024
  @Synchronized fun read(context:Context,uri:Uri):String {
    require(uri.scheme=="content" && uri.authority?.startsWith(context.packageName)!=true){"Share an image from Photos or your chat app."}
    val bytes=context.contentResolver.openInputStream(uri)?.use { input->
      val out=ByteArrayOutputStream();val buffer=ByteArray(16384);var size=0
      while(true){val n=input.read(buffer);if(n<0)break;size+=n;require(size<=MAX_BYTES){"Use an image smaller than 12 MB."};out.write(buffer,0,n)}
      out.toByteArray()
    }?:error("The source app did not grant access to this image. Share it again.")
    return readBytes(context,bytes)
  }
  internal fun readBytes(context:Context,bytes:ByteArray):String {
    require(bytes.size<=MAX_BYTES){"Use an image smaller than 12 MB."}
    val bounds=BitmapFactory.Options().apply{inJustDecodeBounds=true}
    BitmapFactory.decodeByteArray(bytes,0,bytes.size,bounds)
    require(bounds.outWidth in 1..30000 && bounds.outHeight in 1..30000){"This image format cannot be read. Use PNG or JPEG."}
    var sample=1;while(maxOf(bounds.outWidth,bounds.outHeight)/sample>2048)sample*=2
    var bitmap=BitmapFactory.decodeByteArray(bytes,0,bytes.size,BitmapFactory.Options().apply{inSampleSize=sample;inPreferredConfig=Bitmap.Config.ARGB_8888})?:error("Cannot decode this image.")
    val orientation=runCatching{ExifInterface(ByteArrayInputStream(bytes)).getAttributeInt(ExifInterface.TAG_ORIENTATION,1)}.getOrDefault(1)
    val transform=Matrix().apply{when(orientation){2->setScale(-1f,1f);3->setRotate(180f);4->setScale(1f,-1f);5->{setRotate(90f);postScale(-1f,1f)};6->setRotate(90f);7->{setRotate(-90f);postScale(-1f,1f)};8->setRotate(-90f)}}
    if(!transform.isIdentity){val rotated=Bitmap.createBitmap(bitmap,0,0,bitmap.width,bitmap.height,transform,true);if(rotated!==bitmap)bitmap.recycle();bitmap=rotated}
    val engine=TessBaseAPI()
    try {
      val root=File(context.noBackupFilesDir,"meeting-ocr");val model=File(root,"tessdata/vie.traineddata")
      if(!model.exists()){
        model.parentFile!!.mkdirs();val temp=File(model.parentFile,"vie.pending")
        context.assets.open("meeting/vie.traineddata").use{input->temp.outputStream().use{input.copyTo(it)}}
        check(temp.renameTo(model)){"Cannot prepare the offline reader."}
      }
      check(engine.init(root.absolutePath,"vie",TessBaseAPI.OEM_LSTM_ONLY)){"Cannot start the offline reader."}
      engine.pageSegMode=TessBaseAPI.PageSegMode.PSM_SPARSE_TEXT
      engine.setImage(bitmap)
      val text=engine.utF8Text?.trim().orEmpty()
      require(text.isNotBlank()){"No readable text found. Try a clearer crop or share the text instead."}
      require(text.length<=12000){"Crop the image to the invitation and share it again."}
      return text
    } finally {engine.recycle();bitmap.recycle()}
  }
}
