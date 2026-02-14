const functions = require('firebase-functions');
const admin = require('firebase-admin');
const moment = require('moment');

admin.initializeApp();

/**
 * Triggered when a new payment is recorded.
 * Instantly reactivates the member status.
 */
exports.onPaymentCreated = functions.firestore
    .document('payments/{paymentId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();

        if (data.status === 'success') {
            const userId = data.userId;
            const currentMonth = moment().format('YYYY-MM');

            await admin.firestore().collection('users').doc(userId).update({
                status: 'active',
                lastPaymentMonth: currentMonth
            });

            console.log(`User ${userId} reactivated for ${currentMonth}`);

            // Notify admins about the payment
            await notifyAdminsAboutPayment(userId, data.amount);
        }
    });

/**
 * Scheduled task to send fee reminders.
 * Runs twice daily at 9 AM and 6 PM IST.
 */
exports.automatedFeeRemindersDay = functions.pubsub
    .schedule('0 9 * * *')
    .timeZone('Asia/Kolkata')
    .onRun(async (context) => {
        await sendFeeReminders('DAILY_MORNING');
        return null;
    });

exports.automatedFeeRemindersEvening = functions.pubsub
    .schedule('0 18 * * *')
    .timeZone('Asia/Kolkata')
    .onRun(async (context) => {
        await sendFeeReminders('DAILY_EVENING');
        return null;
    });

/**
 * Scheduled task to check membership status.
 * Runs on the 5th of every month at midnight.
 * Deactivates users who haven't paid for the current month.
 */
exports.monthlyMembershipGuard = functions.pubsub
    .schedule('0 0 10 * *')
    .timeZone('Asia/Kolkata')
    .onRun(async (context) => {
        const currentMonth = moment().format('YYYY-MM');
        const usersRef = admin.firestore().collection('users');

        // Query members whose lastPaymentMonth is NOT the current month
        const snapshot = await usersRef
            .where('role', '==', 'member')
            .get();

        const batch = admin.firestore().batch();
        let deactivationCount = 0;

        snapshot.forEach(doc => {
            const userData = doc.data();
            if (userData.lastPaymentMonth !== currentMonth) {
                batch.update(doc.ref, { status: 'inactive' });
                deactivationCount++;
            }
        });

        if (deactivationCount > 0) {
            await batch.commit();
        }

        console.log(`Auto-deactivated ${deactivationCount} members for ${currentMonth}`);
        return null;
    });

/**
 * Scheduled task to send fee reminders.
 * Runs on the 1st of every month at 10 AM IST.
 */
exports.sendFeeRemindersFirstDay = functions.pubsub
    .schedule('0 10 1 * *')
    .timeZone('Asia/Kolkata')
    .onRun(async (context) => {
        await sendFeeReminders('NEW_MONTH');
        return null;
    });

/**
 * Scheduled task to send overdue fee reminders.
 * Runs on the 5th of every month at 10 AM IST.
 */
exports.sendFeeRemindersOverdue = functions.pubsub
    .schedule('0 10 10 * *')
    .timeZone('Asia/Kolkata')
    .onRun(async (context) => {
        await sendFeeReminders('OVERDUE');
        return null;
    });

/**
 * Helper function to send fee reminders to unpaid members.
 */
async function sendFeeReminders(reminderType) {
    const currentMonth = moment().format('YYYY-MM');
    const currentMonthFormatted = moment().format('MMMM YYYY');

    // Get all members who haven't paid for current month
    const usersRef = admin.firestore().collection('users');
    const snapshot = await usersRef
        .where('role', '==', 'member')
        .get();

    const unpaidMembers = [];
    snapshot.forEach(doc => {
        const userData = doc.data();
        if (userData.lastPaymentMonth !== currentMonth && userData.fcmToken) {
            unpaidMembers.push({
                uid: doc.id,
                name: userData.name,
                fcmToken: userData.fcmToken,
            });
        }
    });

    if (unpaidMembers.length === 0) {
        console.log('No unpaid members to notify');
        return;
    }

    // Prepare notification content
    const dayOfMonth = moment().date();
    const isOverdue = dayOfMonth > 10;

    let title, body;
    const tamilMonth = getTamilMonth(moment().month());

    if (isOverdue) {
        title = '⚠️ சந்தா செலுத்த காலதாமதம் | Overdue Notice';
        body = `${tamilMonth} மாதத்திற்கான உங்கள் ₹100 சந்தாவை இன்னும் செலுத்தவில்லை. தயவுசெய்து விரைந்து செலுத்தவும்.\n\n` +
            `Your monthly fee for ${currentMonthFormatted} is overdue. Please pay ₹100 immediately to maintain your active status.`;
    } else if (dayOfMonth === 1) {
        title = '💰 புதிய மாத சந்தா | New Month Fee';
        body = `${tamilMonth} மாதம் தொடங்கிவிட்டது! இந்த மாதத்திற்கான ₹100 சந்தாவை 10-ம் தேதிக்குள் செலுத்தவும்.\n\n` +
            `A new month has begun! Please pay your monthly fee of ₹100 for ${currentMonthFormatted} by the 10th.`;
    } else {
        title = '🔔 சந்தா நினைவூட்டல் | Fee Reminder';
        body = `${tamilMonth} மாதத்திற்கான உங்கள் ₹100 சந்தாவை 10-ம் தேதிக்குள் செலுத்த நினைவூட்டுகிறோம்.\n\n` +
            `Reminder to pay your monthly fee of ₹100 for ${currentMonthFormatted} by the 10th.`;
    }

    // Send notifications
    const tokens = unpaidMembers.map(m => m.fcmToken);

    try {
        const response = await admin.messaging().sendEachForMulticast({
            tokens: tokens,
            notification: {
                title: title,
                body: body,
            },
            data: {
                type: 'FEE_REMINDER',
                month: currentMonth,
                reminderType: reminderType,
                isOverdue: String(isOverdue),
            },
            android: {
                priority: 'high',
                notification: {
                    channelId: 'fee_reminders',
                    priority: 'high',
                },
            },
        });

        console.log(`Sent ${response.successCount} reminders, ${response.failureCount} failed`);

        // Log to Firestore for admin visibility
        await admin.firestore().collection('notifications_log').add({
            type: 'FEE_REMINDER',
            reminderType: reminderType,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            totalRecipients: tokens.length,
            successCount: response.successCount,
            failureCount: response.failureCount,
        });

    } catch (error) {
        console.error('Error sending notifications:', error);
    }
}

/**
 * Helper function to notify admins about a new payment.
 */
async function notifyAdminsAboutPayment(userId, amount) {
    try {
        // Get user details
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        const userData = userDoc.data();

        // Get all admin FCM tokens
        const adminsSnapshot = await admin.firestore().collection('users')
            .where('role', '==', 'admin')
            .get();

        const adminTokens = [];
        adminsSnapshot.forEach(doc => {
            const adminData = doc.data();
            if (adminData.fcmToken) {
                adminTokens.push(adminData.fcmToken);
            }
        });

        if (adminTokens.length === 0) {
            console.log('No admin tokens to notify');
            return;
        }

        await admin.messaging().sendEachForMulticast({
            tokens: adminTokens,
            notification: {
                title: '💵 New Payment Received',
                body: `${userData.name || 'A member'} paid ₹${amount} for membership fee.`,
            },
            data: {
                type: 'PAYMENT_RECEIVED',
                userId: userId,
                amount: String(amount),
            },
        });

        console.log(`Notified ${adminTokens.length} admins about payment from ${userId}`);
    } catch (error) {
        console.error('Error notifying admins:', error);
    }
}

/**
 * Creates a new member account in Firebase Authentication.
 * Only callable by authenticated admins (security to be handled by admin role check).
 */
exports.createMember = functions.https.onCall(async (data, context) => {
    // Basic security check: user must be authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Only authenticated admins can create members.');
    }

    const { email, password, name, phone, membershipId } = data;

    try {
        // Create user in Firebase Auth
        const userRecord = await admin.auth().createUser({
            email: email,
            password: password,
            displayName: name,
        });

        // Add user data to Firestore
        await admin.firestore().collection('users').doc(userRecord.uid).set({
            uid: userRecord.uid,
            name: name,
            email: email,
            phone: phone,
            role: 'member',
            membershipId: membershipId,
            joinDate: admin.firestore.FieldValue.serverTimestamp(),
            status: 'active',
            totalPaid: 0,
        });

        console.log(`Successfully created new member: ${userRecord.uid}`);
        return { success: true, uid: userRecord.uid };
    } catch (error) {
        console.error('Error creating member:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});

/**
 * Manual trigger to send fee reminders (callable by admin).
 */
exports.triggerFeeReminders = functions.https.onCall(async (data, context) => {
    // Basic security check: user must be authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Only authenticated users can trigger reminders.');
    }

    const reminderType = data.reminderType || 'MANUAL';
    await sendFeeReminders(reminderType);

    return { success: true, message: 'Fee reminders sent successfully' };
});

/**
 * Triggered when a document is added to 'notification_triggers'.
 * Used for sending manual notifications to specific users.
 */
exports.onNotificationTrigger = functions.firestore
    .document('notification_triggers/{triggerId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const { userId, fcmToken, type } = data;

        if (!fcmToken) {
            console.error(`No FCM token for notification trigger ${snap.id}`);
            return;
        }

        const title = '🔔 Important Notification';
        let body = 'You have a new message from Neethiyaithedi.';

        if (type === 'MANUAL_REMINDER') {
            const currentMonthFormatted = moment().format('MMMM YYYY');
            body = `This is a reminder to pay your monthly fee for ${currentMonthFormatted}. Please visit the dashboard.`;
        }

        try {
            await admin.messaging().send({
                token: fcmToken,
                notification: {
                    title: title,
                    body: body,
                },
                data: {
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                    type: type,
                },
                android: {
                    notification: {
                        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
                    },
                },
                webpush: {
                    fcmOptions: {
                        link: 'https://neethiyaithedi-a2640.web.app',
                    },
                },
            });
            console.log(`Notification sent to user ${userId} via trigger ${snap.id}`);
        } catch (error) {
            console.error('Error sending triggered notification:', error);
        }
    });

/**
 * Helper function to get Tamil month name.
 */
function getTamilMonth(monthIndex) {
    const tamilMonths = [
        'ஜனவரி', 'பிப்ரவரி', 'மார்ச்', 'ஏப்ரல்', 'மே', 'ஜூன்',
        'ஜூலை', 'ஆகஸ்ட்', 'செப்டம்பர்', 'அக்டோபர்', 'நவம்பர்', 'டிசம்பர்'
    ];
    return tamilMonths[monthIndex];
}

