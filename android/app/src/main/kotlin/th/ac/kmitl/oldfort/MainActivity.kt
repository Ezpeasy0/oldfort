package th.ac.kmitl.oldfort

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val channel = NotificationChannel(
            "chat_messages",
            "ข้อความแชท",
            NotificationManager.IMPORTANCE_HIGH,
        )
        channel.description = "แจ้งเตือนเมื่อมีข้อความใหม่ในแชทส่วนตัวและแชทกลุ่ม"
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
}
