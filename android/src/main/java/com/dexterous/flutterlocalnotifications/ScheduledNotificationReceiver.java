package com.dexterous.flutterlocalnotifications;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

import androidx.annotation.NonNull;

import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingClient;
import com.google.android.gms.location.GeofencingEvent;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;

import io.flutter.Log;

/**
 * Created by michaelbui on 24/3/18.
 */

public class ScheduledNotificationReceiver extends BroadcastReceiver {


    @Override
    public void onReceive(final Context context, Intent intent) {
        Log.d("NOTIFICATIONS", "Intent was received");
        String notificationDetailsJson = intent.getStringExtra(FlutterLocalNotificationsPlugin.NOTIFICATION_DETAILS);
        boolean repeat = intent.getBooleanExtra(FlutterLocalNotificationsPlugin.REPEAT, false);
        if (FlutterLocalNotificationsPlugin.REMIND_AT_LOCATION.equals(intent.getAction())) {
            // notification is a geofence notification
            GeofencingEvent event = GeofencingEvent.fromIntent(intent);
            if (event.hasError()) {
                Log.d("GEOFENCE", "ERROR: " + event.getErrorCode());
            }
            List<Geofence> triggeredGeofences = event.getTriggeringGeofences();
            ArrayList<String> toRemove = new ArrayList<>();
            for (Geofence geofence : triggeredGeofences) {
                toRemove.add(geofence.getRequestId());
            }
            GeofencingClient client = LocationServices.getGeofencingClient(context);
            client.removeGeofences(toRemove).addOnSuccessListener(new OnSuccessListener<Void>() {
                @Override
                public void onSuccess(Void aVoid) {
                    Log.d("GEOFENCE", "Geofence was removed");
                }
            }).addOnFailureListener(new OnFailureListener() {
                @Override
                public void onFailure(@NonNull Exception e) {
                    Log.d("GEOFENCE", "Error removing geofence");
                    Log.d("GEOFENCE", e.getMessage());
                }
            });
        }

        Gson gson = FlutterLocalNotificationsPlugin.buildGson();
        Type type = new TypeToken<NotificationDetails>() {
        }.getType();
        NotificationDetails notificationDetails  = gson.fromJson(notificationDetailsJson, type);
        FlutterLocalNotificationsPlugin.showNotification(context, notificationDetails);
        if (repeat) {
            return;
        }
        FlutterLocalNotificationsPlugin.removeNotificationFromCache(notificationDetails.id, context);

    }

}
