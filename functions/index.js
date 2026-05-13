const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall } = require("firebase-functions/v2/https");
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

require('dotenv').config();

const stripe = process.env.STRIPE_KEY

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

// hide listing if there have been 5 bad reports about it
exports.checkReportThreshold = onDocumentCreated("reports/{reportId}", async (event) => {
    const { listingId } = event.data.data();

    const reports = await admin.firestore()
        .collection('reports')
        .where('listingId', '==', listingId)
        .where('status', '==', 'pending')
        .get();

    if (reports.size >= 5) {
        await admin.firestore()
            .collection('listings')
            .doc(listingId)
            .update({ 'flagged': true });
    }
});

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

exports.createPaymentIntent = onCall(async (request) => {
    if (!request.auth) {
        throw new Error("User must be authenticated to create payment intent");
    }

    const { amount, currency = "usd", type = "add_money" } = request.data;

    if (!amount || amount <= 0) {
        throw new Error("Amount must be greater than 0");
    }

    if (amount > 1000000) {
        throw new Error("Amount exceeds maximum limit ($10,000)");
    }

    const userId = request.auth.uid;
    const userEmail = request.auth.token.email;
});

/**
 * Handles Stripe webhook events (payment success, failure, etc.)
 * Configure in Stripe Dashboard → Webhooks
 * Webhook events to listen for:
 * - payment_intent.succeeded
 * - payment_intent.payment_failed
 * - charge.refunded
 */
exports.handleStripeWebhook = onRequest(async (req, res) => {
    const sig = req.headers["stripe-signature"];
    const endpointSecret = "whsec_YOUR_WEBHOOK_SECRET"; // Get from Stripe Dashboard

    let event;

    try {
        event = stripe.webhooks.constructEvent(req.rawBody, sig, endpointSecret);
    } catch (err) {
        console.error("Webhook signature verification failed:", err.message);
        return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    try {
        switch (event.type) {
            case "payment_intent.succeeded":
                await handlePaymentSuccess(event.data.object);
                break;

            case "payment_intent.payment_failed":
                await handlePaymentFailed(event.data.object);
                break;

            case "charge.refunded":
                await handleRefund(event.data.object);
                break;

            default:
                console.log(`Unhandled event type: ${event.type}`);
        }

        res.json({ received: true });
    } catch (error) {
        console.error("Error processing webhook:", error);
        res.status(500).send("Webhook processing error");
    }
});


// Handle successful payment

async function handlePaymentSuccess(paymentIntent) {
    const { id, amount, currency, metadata } = paymentIntent;
    const { userId, type } = metadata;

    try {
        // Update user's wallet balance
        const amountInDollars = amount / 100; // Convert cents to dollars

        await admin.firestore().collection("users").doc(userId).set({
            totalCash: admin.firestore.FieldValue.increment(amountInDollars),
        }, { merge: true });

        // Create transaction record
        await admin.firestore().collection("transactions").add({
            userId: userId,
            type: type === "registration_fee" ? "deposit" : "add_money",
            amount: amountInDollars,
            status: "completed",
            description: type === "registration_fee"
                ? "Registration fee - Account created"
                : "Wallet top-up",
            paymentMethod: "stripe_card",
            paymentIntentId: id,
            currency: currency,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Update user registration status if this was registration fee
        if (type === "registration_fee") {
            await admin.firestore().collection("users").doc(userId).set({
                accountType: "paid",
                verified: true,
                registrationFeeId: id,
            }, { merge: true });
        }

        console.log(`Payment processed for user ${userId}: $${amountInDollars}`);
    } catch (error) {
        console.error("Error handling payment success:", error);
        throw error;
    }
}


// Handle failed payment

async function handlePaymentFailed(paymentIntent) {
    const { id, metadata } = paymentIntent;
    const { userId } = metadata;

    try {
        // Log failed payment
        await admin.firestore().collection("transactions").add({
            userId: userId,
            type: "payment_failed",
            amount: 0,
            status: "failed",
            description: `Payment failed: ${paymentIntent.last_payment_error?.message}`,
            paymentIntentId: id,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`Payment failed for user ${userId}: ${id}`);
    } catch (error) {
        console.error("Error handling payment failure:", error);
    }
}

// handle refunds
async function handleRefund(charge) {
    const { payment_intent, amount } = charge;
    const amountInDollars = amount / 100;

    try {
        // Get transaction from payment intent ID
        const transactionSnap = await admin.firestore()
            .collection("transactions")
            .where("paymentIntentId", "==", payment_intent)
            .limit(1)
            .get();

        if (!transactionSnap.empty) {
            const docId = transactionSnap.docs[0].id;
            const { userId } = transactionSnap.docs[0].data();

            // Update transaction
            await admin.firestore().collection("transactions").doc(docId).set({
                status: "refunded",
                refundedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });

            // Deduct from user balance
            await admin.firestore().collection("users").doc(userId).set({
                totalCash: admin.firestore.FieldValue.increment(-amountInDollars),
            }, { merge: true });

            console.log(`Refund processed: ${payment_intent}, amount: $${amountInDollars}`);
        }
    } catch (error) {
        console.error("Error handling refund:", error);
    }
}


// Get transaction history for a user

exports.getTransactionHistory = onCall(async (request) => {
    if (!request.auth) {
        throw new Error("User Must be authenticated")
    }

    const { limit = 50, startAfter = null } = data;
    const userId = context.auth.uid;

    try {
        let query = admin.firestore()
            .collection("transactions")
            .where("userId", "==", userId)
            .orderBy("createdAt", "desc")
            .limit(limit);

        if (startAfter) {
            query = query.startAfter(startAfter);
        }

        const snapshot = await query.get();

        return {
            transactions: snapshot.docs.map(doc => ({
                id: doc.id,
                ...doc.data(),
                createdAt: doc.data().createdAt?.toDate?.() || null,
            })),
            lastDoc: snapshot.docs[snapshot.docs.length - 1] || null,
        };
    } catch (error) {
        console.error("Error getting transaction history:", error);
        throw new functions.https.HttpsError(
            "internal",
            "Failed to get transaction history"
        );
    }
});

// verify payment
exports.verifyPayment = onCall(async (request) => {
    if (!request.auth) {
        throw new Error("User must be authenticated")
    }

    const { paymentIntentId } = data;

    try {
        const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

        return {
            id: paymentIntent.id,
            status: paymentIntent.status,
            amount: paymentIntent.amount,
            currency: paymentIntent.currency,
            clientSecret: paymentIntent.client_secret,
        };
    } catch (error) {
        console.error("Error verifying payment:", error);
        throw new functions.https.HttpsError(
            "internal",
            "Failed to verify payment"
        );
    }
});