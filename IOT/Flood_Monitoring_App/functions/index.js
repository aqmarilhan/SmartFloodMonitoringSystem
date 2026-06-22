const {onValueUpdated} = require("firebase-functions/v2/database");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendFloodStatusNotification = onValueUpdated(
  {
    ref: "/FloodMonitoring/flood_status",
    region: "asia-southeast1",
  },
  async (event) => {
    const beforeStatus = event.data.before.val();
    const currentStatus = event.data.after.val();

    if (beforeStatus === currentStatus) {
      return null;
    }

    if (currentStatus !== "WARNING" && currentStatus !== "DANGEROUS") {
      return null;
    }

    const title =
      currentStatus === "DANGEROUS"
        ? "🚨 Flood Alert"
        : "⚠️ Flood Warning";

    const body =
      currentStatus === "DANGEROUS"
        ? "Dangerous flood level detected! Move vehicle immediately."
        : "Water level is increasing. Stay alert.";

    await admin.messaging().send({
      topic: "flood_alerts",
      notification: {
        title: title,
        body: body,
      },
      data: {
        flood_status: currentStatus,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "flood_alerts",
        },
      },
    });

    return null;
  }
);