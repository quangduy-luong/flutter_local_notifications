package com.dexterous.flutterlocalnotifications;

import android.app.AlarmManager;
import android.app.IntentService;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.Context;

import androidx.core.app.AlarmManagerCompat;
import androidx.core.app.NotificationManagerCompat;

import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import java.lang.reflect.Type;

/**
 * An {@link IntentService} subclass for handling asynchronous task requests in
 * a service on a separate handler thread.
 * <p>
 * TODO: Customize class - update intent actions, extra parameters and static
 * helper methods.
 */
public class NotificationIntentService extends IntentService {
    public NotificationIntentService() {
        super("NotificationIntentService");
    }

    @Override
    protected void onHandleIntent(Intent intent) {
        if (intent != null) {
            final String action = intent.getAction();
            if (FlutterLocalNotificationsPlugin.SNOOZE.equals(action)) {
                String json = intent.getStringExtra(FlutterLocalNotificationsPlugin.NOTIFICATION_DETAILS);
                Long snoozeAmount = intent.getLongExtra(FlutterLocalNotificationsPlugin.SNOOZE, 5000);
                if (json != null) {
                    Gson gson = FlutterLocalNotificationsPlugin.buildGson();
                    Type type = new TypeToken<NotificationDetails>(){}.getType();
                    NotificationDetails details = gson.fromJson(json, type);
                    Long triggerTime = System.currentTimeMillis() + snoozeAmount;

                    NotificationManagerCompat notificationManager = NotificationManagerCompat.from(this);
                    notificationManager.cancel(details.id);

                    AlarmManager alarmManager = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
                    Intent snoozeIntent = new Intent(this, ScheduledNotificationReceiver.class);
                    snoozeIntent.putExtra(FlutterLocalNotificationsPlugin.NOTIFICATION_DETAILS, json);
                    PendingIntent pendingIntent = PendingIntent.getBroadcast(this, details.id, snoozeIntent, PendingIntent.FLAG_UPDATE_CURRENT);
                    AlarmManagerCompat.setExact(alarmManager, AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent);
                }
            } else if (FlutterLocalNotificationsPlugin.REMIND_AT_LOCATION.equals(action)) {
                // TODO: handle geofence trigger
            } else {
                // Unknown intent: return
                return;
            }
        }
    }
}
