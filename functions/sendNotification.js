import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

export const sendNotification = onCall(async (request) => {
  const {receivingUserIds, message, sharedItem} = request.data;

  logger.info(`📤 sendNotification called with ${receivingUserIds.length} recipients`);
  logger.info(`📦 Shared item data:`, sharedItem);

  // Input validation
  if (!receivingUserIds || !Array.isArray(receivingUserIds) || receivingUserIds.length === 0) {
    throw new Error("Invalid receivingUserIds");
  }

  // Prepare document references
  const userDocRefs = receivingUserIds.map((id) => db.collection("users").doc(id));

  try {
    // Batch fetch all user docs at once
    const userDocs = await db.getAll(...userDocRefs);

    const messages = [];
    const failedTokens = [];
    const batch = db.batch(); // Create a batch for Firestore updates

    userDocs.forEach((docSnapshot, index) => {
      const userId = receivingUserIds[index];
      const userData = docSnapshot.data();
      const token = userData?.fcmToken;

      if (!token) {
        logger.warn(`❌ No FCM token for user ${userId} (${userData?.fullName || userData?.email})`);
        failedTokens.push(userId);
        return;
      }

      logger.info(`✅ Found FCM token for user ${userId}: ${token.substring(0, 20)}...`);

      // Add push notification message with enhanced data
      messages.push({
        token,
        android: {
          priority: "high",
          notification: {
            title: "🔔 Shared Alarm!",
            body: message,
            channelId: "alarm_updates",
            sound: "default",
            autoCancel: true,
          },
          data: {
            silent: "false",
            type: "sharedAlarm",
            message,
            sharedItemId: sharedItem?.id || "",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          headers: {
            "apns-priority": "10",
            "apns-push-type": "alert",
          },
          payload: {
            aps: {
              alert: {
                title: "🔔 Shared Alarm!",
                body: message,
              },
              sound: "default",
              badge: 1,
            },
            sharedItemId: sharedItem?.id || "",
            type: "sharedAlarm",
          },
        },
        notification: {
          title: "🔔 Shared Alarm!",
          body: message,
        },
        data: {
          silent: "false",
          type: "sharedAlarm",
          message,
          sharedItemId: sharedItem?.id || "",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      });

      // Add shared item to user's receivedItems array if sharedItem is provided
      if (sharedItem && docSnapshot.exists) {
        logger.info(`📦 Adding shared item to user ${userId}: ${userData?.fullName || userData?.email}`);
        const userDocRef = db.collection("users").doc(userId);
        const currentReceivedItems = userData?.receivedItems || [];
        
        // Add timestamp to shared item
        const itemWithTimestamp = {
          ...sharedItem,
          receivedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        
        // Add the new shared item to the array
        const updatedReceivedItems = [...currentReceivedItems, itemWithTimestamp];
        
        batch.update(userDocRef, {
          receivedItems: updatedReceivedItems,
          lastNotificationAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        logger.info(`✅ Queued receivedItems update for user ${userId}`);
      }
    });

    // Execute Firestore batch update first
    if (sharedItem) {
      logger.info(`🔄 Committing Firestore batch updates...`);
      await batch.commit();
      logger.info(`✅ Firestore batch updates completed`);
    }

    // Send push notifications with retry mechanism
    if (messages.length === 0) {
      logger.warn(`❌ No valid FCM tokens found. Failed users: ${failedTokens.join(", ")}`);
      return {
        success: false, 
        message: "No valid FCM tokens found",
        failedTokens,
        totalRequested: receivingUserIds.length,
      };
    }
    
    logger.info(`📱 Sending ${messages.length} push notifications...`);
    const response = await admin.messaging().sendEach(messages);
    
    // Check for failed sends and log them
    const failedSends = [];
    response.responses.forEach((resp, index) => {
      if (!resp.success) {
        logger.error(`❌ Failed to send to ${receivingUserIds[index]}: ${resp.error?.message}`);
        failedSends.push({
          userId: receivingUserIds[index],
          error: resp.error?.message,
        });
      }
    });

    logger.info(`✅ Push notifications completed. Success: ${response.successCount}, Failed: ${response.failureCount}`);
    
    return {
      success: response.successCount > 0,
      successCount: response.successCount,
      failureCount: response.failureCount,
      failedSends,
      failedTokens,
      totalRequested: receivingUserIds.length,
      responses: response.responses,
    };
  } catch (error) {
    logger.error("❌ Error in sendNotification function", error);
    throw new Error(`Failed to send notifications: ${error.message}`);
  }
});