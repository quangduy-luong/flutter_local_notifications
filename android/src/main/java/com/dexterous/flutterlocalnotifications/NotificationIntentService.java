package com.dexterous.flutterlocalnotifications;

import android.app.AlarmManager;
import android.app.IntentService;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.Context;

import androidx.annotation.NonNull;
import androidx.core.app.AlarmManagerCompat;
import androidx.core.app.NotificationManagerCompat;

import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingClient;
import com.google.android.gms.location.GeofencingRequest;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import java.lang.reflect.Type;

import io.flutter.Log;

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
                    // retrieve details
                    Gson gson = FlutterLocalNotificationsPlugin.buildGson();
                    Type type = new TypeToken<NotificationDetails>(){}.getType();
                    NotificationDetails details = gson.fromJson(json, type);
                    Long triggerTime = System.currentTimeMillis() + snoozeAmount;

                    // cancel the notification on tap
                    NotificationManagerCompat notificationManager = NotificationManagerCompat.from(this);
                    notificationManager.cancel(details.id);

                    // re-schedule a notification
                    AlarmManager alarmManager = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
                    Intent snoozeIntent = new Intent(this, ScheduledNotificationReceiver.class);
                    snoozeIntent.putExtra(FlutterLocalNotificationsPlugin.NOTIFICATION_DETAILS, json);
                    PendingIntent pendingIntent = PendingIntent.getBroadcast(this, details.id, snoozeIntent, PendingIntent.FLAG_UPDATE_CURRENT);
                    AlarmManagerCompat.setExact(alarmManager, AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent);
                }
            } else if (FlutterLocalNotificationsPlugin.REMIND_AT_LOCATION.equals(action)) {
                Log.d("IntentService", "location action tapped");
                String json = intent.getStringExtra(FlutterLocalNotificationsPlugin.NOTIFICATION_DETAILS);
                if (json != null) {
                    // retrieve details
                    Gson gson = FlutterLocalNotificationsPlugin.buildGson();
                    Type type = new TypeToken<NotificationDetails>(){}.getType();
                    NotificationDetails details = gson.fromJson(json, type);

                    // cancel the notification on tap
                    NotificationManagerCompat notificationManager = NotificationManagerCompat.from(this);
                    notificationManager.cancel(details.id);

                    Intent locationIntent = new Intent(this, ScheduledNotificationReceiver.class);
                    locationIntent.setAction(FlutterLocalNotificationsPlugin.REMIND_AT_LOCATION);
                    locationIntent.putExtra(FlutterLocalNotificationsPlugin.NOTIFICATION_ID, details.id);
                    locationIntent.putExtra(FlutterLocalNotificationsPlugin.PAYLOAD, details.payload);
                    locationIntent.putExtra(FlutterLocalNotificationsPlugin.NOTIFICATION_DETAILS, json);
                    PendingIntent pendingIntent = PendingIntent.getBroadcast(this, details.id, locationIntent, PendingIntent.FLAG_UPDATE_CURRENT);

                    int transition = Geofence.GEOFENCE_TRANSITION_ENTER;
                    if (details.notifyOnEntry && details.notifyOnExit) {
                        transition = Geofence.GEOFENCE_TRANSITION_ENTER | Geofence.GEOFENCE_TRANSITION_EXIT;
                    } else if (details.notifyOnExit) {
                        transition = Geofence.GEOFENCE_TRANSITION_EXIT;
                    }

                    GeofencingClient geofencingClient = LocationServices.getGeofencingClient(this);
                    Geofence.Builder builder = new Geofence.Builder();
                    builder.setRequestId(details.id.toString())
                            .setCircularRegion(details.latitude, details.longitude, 200.0f)
                            .setExpirationDuration(Geofence.NEVER_EXPIRE)
                            .setTransitionTypes(transition);
                    Geofence geofence = builder.build();

                    GeofencingRequest request = new GeofencingRequest.Builder()
                            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
                            .addGeofence(geofence)
                            .build();

                    geofencingClient.addGeofences(request, pendingIntent).addOnFailureListener(new OnFailureListener() {
                        @Override
                        public void onFailure(@NonNull Exception e) {
                            Log.d("GEOFENCE", "Geofence failed to register.");
                            Log.d("GEOFENCE", e.getMessage());
                        }
                    }).addOnSuccessListener(new OnSuccessListener<Void>() {
                        @Override
                        public void onSuccess(Void aVoid) {
                            Log.d("GEOFENCE", "Geofence successfully added.");
                        }
                    });

                    // save the notification as scheduled
                    FlutterLocalNotificationsPlugin.saveScheduledNotification(this, details);

                }
            } else {
                // Unknown intent: return
                Log.d("IntentService", "UnknownAction: " + action);
                return;
            }
        }
    }
}
