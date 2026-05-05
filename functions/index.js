const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// function to create notification
async function createNotification({
    receiverId,
    senderId,
    type,
    title,
    message,
    relatedId,
    screen
}) {
    if (!receiverId) {
        console.log("❌ Missing receiverId");
        return;
    }

    await db.collection("notifications").add({
        receiverId,
        senderId: senderId || null,
        type,
        title,
        message,
        relatedId: relatedId || null,
        screen: screen || "home",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false
    });

    console.log("✅ Notification created:", title);
}

// order created
exports.onOrderCreated = onDocumentCreated("orders/{orderId}", async (event) => {
    const order = event.data.data();

    if (!order) return;

    const message = `${order.buyerEmail?.split("@")[0]} bought your item "${order.title}"`;

    await admin.firestore().collection("notifications").add({
        receiverId: order.sellerId,
        senderId: order.buyerId,
        type: "order",
        title: "New Purchase",
        message: message,
        relatedId: event.params.orderId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
        screen: "sellScreen"
    });
});

// order cancelled
exports.onOrderDeleted = onDocumentUpdated("orders/{orderId}", async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (!before || after) return; // deleted

    await createNotification({
        receiverId: before.sellerId,
        senderId: before.buyerId,
        type: "orderCancelled",
        title: "Order Cancelled",
        message: `Order for "${before.title}" was cancelled`,
        relatedId: event.params.orderId,
        screen: "orders"
    });
});

// create notification on message sent
exports.onMessageSent = onDocumentCreated(
    "chats/{chatId}/messages/{messageId}",
    async (event) => {

        const messageData = event.data.data();
        if (!messageData) return;

        const chatId = event.params.chatId;

        // get chat
        const chatDoc = await db.collection("chats").doc(chatId).get();

        if (!chatDoc.exists) {
            console.log("❌ Chat not found");
            return;
        }

        const chat = chatDoc.data();
        const participants = chat.participantIds || [];

        // find receiver (not sender)
        const receiverId = participants.find(
            id => id !== messageData.senderId
        );

        if (!receiverId) {
            console.log("❌ No receiver found");
            return;
        }

        // optional: get sender info
        let senderName = "Someone";

        try {
            const senderDoc = await db.collection("users")
                .doc(messageData.senderId)
                .get();

            if (senderDoc.exists) {
                senderName = senderDoc.data().email?.split("@")[0] || "Someone";
            }
        } catch (e) {
            console.log("⚠️ Could not fetch sender info");
        }

        // message preview
        const preview = messageData.text || "Sent you a message";

        await createNotification({
            receiverId: receiverId,
            senderId: messageData.senderId,
            type: "newMessage",
            title: "New Message 💬",
            message: `${senderName}: ${preview}`,
            relatedId: chatId,
            screen: "chat"
        });
    }
);

// offer created
exports.onOfferCreated = onDocumentCreated("offers/{offerId}", async (event) => {
    const offer = event.data.data();

    if (!offer) return;

    const message = `${offer.buyerEmail?.split("@")[0]} offered "${offer.price}
     "for "${offer.title}"`;

    await admin.firestore().collection("notifications").add({
        receiverId: offer.sellerId,
        senderId: offer.buyerId,
        type: "offer",
        title: "New Offer",
        message: message,
        relatedId: event.params.orderId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
        screen: "sellScreen"
    });
});


// offers updated
exports.onOfferUpdate = onDocumentUpdated("offers/{offerId}", async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (!before || !after) return;

    if (before.status === after.status) return;

    const buyerId = after.buyerId;
    const sellerId = after.sellerId;

    if (!buyerId) return console.log("❌ Missing buyerId");

    let type = "";
    let title = "";
    let message = "";

    if (after.status === "accepted" || after.status === "confirmed") {
        type = "offerAccepted";
        title = "Offer Accepted 🎉";
        message = `Your offer for "${after.title}" was accepted`;
    }
    else if (after.status === "declined") {
        type = "offerDeclined";
        title = "Offer Declined";
        message = `Your offer for "${after.title}" was declined`;
    }
    else if (after.status === "countered" || after.status.startsWith("counter")) {
        type = "counterOffer";
        title = "Counter Offer";
        message = `Seller sent a counter offer for "${after.title}"`;
    }
    else {
        return;
    }

    await createNotification({
        receiverId: buyerId,
        senderId: sellerId,
        type,
        title,
        message,
        relatedId: event.params.offerId,
        screen: "offers"
    });
});

// review created
exports.onReviewCreated = onDocumentCreated(
    "seller_ratings/{ratingId}",
    async (event) => {

        const data = event.data.data();
        if (!data) return;

        const sellerId = data.sellerId;
        const raterId = data.raterId;

        if (!sellerId) {
            console.log("❌ Missing sellerId");
            return;
        }

        // prevent self-review notification (just in case)
        if (sellerId === raterId) return;

        // optional: get rater name
        let raterName = "Someone";

        try {
            const userDoc = await db.collection("users")
                .doc(raterId)
                .get();

            if (userDoc.exists) {
                raterName = userDoc.data().email?.split("@")[0] || "Someone";
            }
        } catch (e) {
            console.log("⚠️ Could not fetch rater info");
        }

        const rating = data.rating ?? "";
        const comment = data.comment ?? "";

        // build message nicely
        let message = `${raterName} left you a review`;
        if (rating) {
            message += ` ⭐${rating}`;
        }
        if (comment) {
            message += `: "${comment}"`;
        }

        await createNotification({
            receiverId: sellerId,
            senderId: raterId,
            type: "newReview",
            title: "New Review ⭐",
            message: message,
            relatedId: event.params.ratingId,
            screen: "profile"
        });
    }
);

// send notification to phone for all types
exports.sendNotification = onDocumentCreated("notifications/{notificationId}", async (event) => {
    const notif = event.data.data();

    if (!notif) return;

    const receiverId = notif.receiverId;

    if (!receiverId) {
        console.log("❌ No receiverId");
        return;
    }

    // get user token
    const userDoc = await db.collection("users").doc(receiverId).get();

    if (!userDoc.exists) {
        console.log("❌ User not found");
        return;
    }

    const token = userDoc.data().phoneToken;

    if (!token) {
        console.log("❌ No FCM token");
        return;
    }

    try {
        await admin.messaging().send({
            token: token,
            notification: {
                title: notif.title,
                body: notif.message
            }
        });

        console.log("✅ Push notification sent");
    } catch (e) {
        console.log("❌ Push failed:", e);
    }
});